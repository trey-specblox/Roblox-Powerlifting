--!strict
--[[
	MeetCnAllowance
	Shared / Progression

	The meet CN allowance (GAME_DESIGN.md §33.3b, user 2026-10-29): how far
	meets against other players may raise a lift's Competition Number.

	STORED IN DAYS. Each weight-class build keeps one Resource per lift
	(ResourceRegeneration), whose amount is the days saved up: it refills
	smoothly at one day per 24 hours, offline too, and holds at most
	ProgressionConfig.MeetCnAllowance.MaxDays. What a day is worth is worked out
	when the allowance is used:

		one day = TrainingDaysPerDay x what a full day of gym training gives the lift
		        = TrainingDaysPerDay x Reference x BaseProgressRate x (DailyCapEV / 3) x Hill(PP)

	(GAME_DESIGN §37.1, user 2026-11-01: meets give about 2/3 of strength),
	where Hill is the training's own slow-down near the class's Progression
	Reference (CompetitionNumberReward.hill, section 29.3) and PP = CN /
	Progression Reference. As a share of CN that is the same with Reference =
	CN / PP. It never reaches zero. Storing days rather than kg or percent
	keeps the shrink honest: it always uses the CN of the moment.

	In a meet with only one real player (computer lifters fill the rest,
	§37.2) the caller passes SoloCostMultiplier: every raise and every miss
	costs that many times the days, so strength counts half there.

	A MEET IS SETTLED ONE LIFT AT A TIME, attempts in the order they were taken
	(settle): a GOOD lift above what is raised so far uses the allowance its
	raise costs, cut to what is left; a MISS above it uses what it would have
	cost. A bomb-out (`raises` false) raises nothing, and its misses still cost.

	The unlimited class (120+ kg) has no Progression Reference, so it has no
	allowance and meets never raise its CN, as training never does.

	Pure: the caller passes the server clock and the build's data, and writes
	through PlayerDataService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local AttemptRules = require(Shared:WaitForChild("Meet"):WaitForChild("AttemptRules"))
local ResourceRegeneration = require(script.Parent:WaitForChild("ResourceRegeneration"))
local CompetitionNumberReward = require(script.Parent:WaitForChild("CompetitionNumberReward"))

local MeetCnAllowance = {}

local CONFIG = ProgressionConfig.MeetCnAllowance
-- One day of allowance per 24 hours.
MeetCnAllowance.DaysPerHour = 1 / 24

export type Resource = ResourceRegeneration.Resource

-- What settling one lift did.
export type Outcome = {
	-- The Competition Number after the meet (never below the one it started from).
	newCnKg: number,
	-- Days of allowance the lift used.
	daysUsed: number,
	-- Days left afterwards.
	daysLeft: number,
}

local function isFinite(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- A full allowance that has never been touched (ResourceRegeneration reads a full, unstamped one as full).
function MeetCnAllowance.newFull(): Resource
	return { amount = CONFIG.MaxDays, lastUpdatedUnix = 0 }
end

-- A separate copy of an allowance (a new build copies the lighter build's), or a full one when it is unusable.
function MeetCnAllowance.copy(resource: any): Resource
	if typeof(resource) ~= "table" or not isFinite(resource.amount) or not isFinite(resource.lastUpdatedUnix) then
		return MeetCnAllowance.newFull()
	end
	return { amount = resource.amount, lastUpdatedUnix = resource.lastUpdatedUnix }
end

-- Days saved up right now, without writing anything.
function MeetCnAllowance.daysAvailable(resource: Resource, nowUnix: number): number
	return ResourceRegeneration.current(resource, nowUnix, CONFIG.MaxDays, MeetCnAllowance.DaysPerHour)
end

--[[
	What one day of allowance is worth for this lift, class and Competition
	Number, as a share of CN (0.04 = 4%), or nil when the class has no
	Progression Reference (the unlimited class) or the CN is unusable.
]]
function MeetCnAllowance.dailyShare(lift: string, classLabel: string, cnKg: number): number?
	if not isFinite(cnKg) or cnKg <= 0 then
		return nil
	end
	local proximity = CompetitionNumberReward.progressionProximity(lift, classLabel, cnKg)
	if proximity == nil or not isFinite(proximity) or proximity <= 0 then
		return nil
	end
	-- One full day of training for this lift, in kg, divided by the CN: Reference x rate x EV x Hill / CN,
	-- with Reference / CN = 1 / PP.
	local trainingEv = ProgressionConfig.DailyTraining.DailyCapEV / #ProgressionConfig.Lifts
	local trainingShare = ProgressionConfig.BaseProgressRate * trainingEv * CompetitionNumberReward.hill(proximity)
		/ proximity
	return CONFIG.TrainingDaysPerDay * trainingShare
end

-- The share of CN a meet could raise this lift by right now (days x one day's worth), or nil like dailyShare.
function MeetCnAllowance.shareAvailable(resource: Resource, nowUnix: number, lift: string, classLabel: string,
	cnKg: number): number?
	local daily = MeetCnAllowance.dailyShare(lift, classLabel, cnKg)
	if daily == nil then
		return nil
	end
	return MeetCnAllowance.daysAvailable(resource, nowUnix) * daily
end

--[[
	Settles one lift of a finished (or abandoned) meet against its allowance and
	returns the result, or nil and why nothing could be settled (then nothing is
	written). WRITES the resource (settled to `nowUnix`, then spent).

	`cnKg` is the Competition Number at the weigh-in; `history` the lift's
	attempts in order; `raises` false for a meet without a total (a bomb-out or
	leaving early), where good lifts raise nothing but misses still cost.
	`costMultiplier` (default 1) makes every raise and miss cost that many
	times the days: SoloCostMultiplier in a meet with one real player.
]]
function MeetCnAllowance.settle(resource: Resource, nowUnix: number, lift: string, classLabel: string, cnKg: number,
	history: AttemptRules.AttemptHistory, raises: boolean, costMultiplier: number?): (Outcome?, string?)
	if typeof(resource) ~= "table" then
		return nil, "no allowance"
	end
	local daily = MeetCnAllowance.dailyShare(lift, classLabel, cnKg)
	if daily == nil or daily <= 0 then
		return nil, "no allowance in this class"
	end
	local cost = if isFinite(costMultiplier) and (costMultiplier :: number) >= 1 then costMultiplier :: number else 1
	-- What one day buys here: a costlier meet buys less per day.
	daily /= cost
	local days = ResourceRegeneration.settle(resource, nowUnix, CONFIG.MaxDays, MeetCnAllowance.DaysPerHour)
	local startDays = days
	local raisedTo = cnKg
	for _, attempt in ipairs(history) do
		local weight = attempt.weightKg
		if isFinite(weight) and weight > raisedTo + 1e-6 then
			-- What going from what is raised so far to this weight costs, in days.
			local wantDays = (weight - raisedTo) / cnKg / daily
			if attempt.result == "GoodLift" then
				if raises then
					local useDays = math.min(days, wantDays)
					raisedTo += useDays * daily * cnKg
					days -= useDays
				end
			else
				days -= math.min(days, wantDays)
			end
		end
	end
	resource.amount = days
	resource.lastUpdatedUnix = nowUnix
	return { newCnKg = raisedTo, daysUsed = startDays - days, daysLeft = days }, nil
end

return MeetCnAllowance
