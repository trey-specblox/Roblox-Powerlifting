--!strict
--[[
	TechniqueTraining
	Shared / Progression

	The pure maths of rack technique training, checkpoint 5B.7 (GAME_DESIGN.md
	section 34.6 and 34.7). No Instances, no clock, no profile: given a lift, a
	primary stat and some seconds, it says how many raw points each stat earns.

	=========================================================================
	RAW EARNING IS UNLIMITED AND LINEAR
	=========================================================================

	A rack earns ProgressionConfig.DailyTraining.TechniqueRawPerHour raw points
	per hour, forever. There is no daily, weekly, lifetime or per-lift cap, and
	the RAW rate never slows down, however high a stat already is.

	Diminishing returns are real, but they belong to READING a stat, not to
	earning it: TechniqueCurve turns raw into an effective value (10 at raw 0,
	approaching 99.5) whenever a lift uses it. Nothing in here calls that curve,
	and nothing in that curve feeds back into the earning rate.

	=========================================================================
	ONE PLACE COMPUTES THE AMOUNT
	=========================================================================

	`rawPointsFor` is the only function that turns time into points. A future,
	APPROVED training buff (ModifierChannel.TrainingEffectiveness already names
	the home for coach and food bonuses) would be applied there and nowhere
	else. None is applied today: the result is exactly rate x hours.

	=========================================================================
	THE SPLIT ALWAYS ADDS UP
	=========================================================================

	The primary gets `total x TechniquePrimaryShare`; the secondary gets
	`total - primary`, NOT `total x (1 - share)`. Subtracting makes the two
	parts sum to the total exactly, so no fraction of a point is created or
	lost to rounding, tick after tick.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local TechniqueTraining = {}

local SECONDS_PER_HOUR = 3600

export type Share = {
	stat: string,
	share: number,
}

export type Gain = {
	stat: string,
	raw: number,
}

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Raw points per hour of rack technique training, before any (future) buff.
function TechniqueTraining.baseRawPerHour(): number
	return ProgressionConfig.DailyTraining.TechniqueRawPerHour
end

--[[
	The trainable stats of a lift, primary candidates in menu order, as a COPY.
	nil for anything that is not one of the three lifts.
]]
function TechniqueTraining.statsFor(lift: any): { string }?
	if not ProgressionConfig.isLift(lift) then
		return nil
	end

	local stats = (ProgressionConfig.TrainableTechnique :: any)[lift] :: { string }
	return table.clone(stats)
end

--[[
	Whether `primary` is a stat this lift can train at a rack. PullStrength and
	any typing stat are never in the table, so they are always false.
]]
function TechniqueTraining.isValidPrimary(lift: any, primary: any): boolean
	if typeof(primary) ~= "string" then
		return false
	end

	local stats = TechniqueTraining.statsFor(lift)
	return stats ~= nil and table.find(stats, primary) ~= nil
end

--[[
	The shares a selection receives, primary first: 80/20 for Squat and Bench,
	100% Lockout for the Deadlift. nil if the combination is invalid.
]]
function TechniqueTraining.split(lift: any, primary: any): { Share }?
	if not TechniqueTraining.isValidPrimary(lift, primary) then
		return nil
	end

	local stats = TechniqueTraining.statsFor(lift) :: { string }
	if #stats == 1 then
		return { { stat = primary, share = 1 } }
	end

	local primaryShare = ProgressionConfig.DailyTraining.TechniquePrimaryShare
	local secondary = if stats[1] == primary then stats[2] else stats[1]

	return {
		{ stat = primary, share = primaryShare },
		{ stat = secondary, share = 1 - primaryShare },
	}
end

--[[
	THE ONE PLACE TIME BECOMES RAW POINTS. Total across the split.

	Zero for zero, negative, NaN or infinite input: a bad interval earns
	nothing rather than erroring. The caller (the award operation) refuses
	over-long intervals separately.
]]
function TechniqueTraining.rawPointsFor(elapsedSeconds: number): number
	if not isFiniteNumber(elapsedSeconds) or elapsedSeconds <= 0 then
		return 0
	end

	return TechniqueTraining.baseRawPerHour() * (elapsedSeconds / SECONDS_PER_HOUR)
end

--[[
	Splits `total` raw points across the selection's stats, primary first.
	The parts sum to `total` exactly. nil for an invalid selection or a total
	that is not a finite number of zero or more.
]]
function TechniqueTraining.allocate(lift: any, primary: any, total: number): { Gain }?
	if not isFiniteNumber(total) or total < 0 then
		return nil
	end

	local shares = TechniqueTraining.split(lift, primary)
	if shares == nil then
		return nil
	end

	if #shares == 1 then
		return { { stat = shares[1].stat, raw = total } }
	end

	local primaryRaw = total * shares[1].share
	return {
		{ stat = shares[1].stat, raw = primaryRaw },
		{ stat = shares[2].stat, raw = total - primaryRaw },
	}
end

--[[
	Raw points per hour for each stat of a selection, for display. nil if the
	selection is invalid.
]]
function TechniqueTraining.ratesFor(lift: any, primary: any): { Gain }?
	return TechniqueTraining.allocate(lift, primary, TechniqueTraining.baseRawPerHour())
end

return TechniqueTraining
