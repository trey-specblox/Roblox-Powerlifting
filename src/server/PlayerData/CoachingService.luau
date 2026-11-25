--!strict
--[[
	CoachingService
	Server / PlayerData

	GETTING COACHED (GAME_DESIGN §40.5; the user's design 2026-11-19 to 2026-11-23, CoachingConfig has the numbers):

		- every player starts with the gym owner as their (free) basic coach
		- "Can you coach me?" -> "It's gonna cost you...": paying CoachingConfig.Price (HireCoach) starts that coach's trials
		- TRIAL 1 (StartTrial): the player's Mock Meet room, MockMeetService.startCoachTrial: 10 good lifts of the coach's lift
		  in a row at 100% of their Competition Number; one miss fails it, and a fail means paying again
		- TRIAL 2 (meetFinished, after a real meet's save): 3/3 of the coach's lift, the third at 105%+ of their Competition
		  Number, and a top-3 lift in the meet with other real players in it, or the best of the meet with only computer
		  lifters; free retries
		- then they're the player's coach and become the active coach; "Be my coach" switches (SetActive)
		- a real meet finished with a hired coach active adds one to that coach's bond (for the coach's unlocks, later)

	SECURITY: the client only asks. The price is CoachingConfig's, the lift is checked, and every trial result is judged
	here from the server's own meet and lift results.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoachingConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoachingConfig"))
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig"))
local CoachingRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("CoachingRemotes"))

local ServerFolder = script.Parent.Parent
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local CoachingService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.4
local started = false
local remotes: CoachingRemotes.RemoteSet? = nil
local lastAsked: { [Player]: number } = {}

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
		return true
	end
	lastAsked[player] = now
	return false
end

local function viewFor(player: Player): CoachingRemotes.CoachingView?
	local coaching = PlayerDataService.getCoaching(player)
	if coaching == nil then
		return nil
	end
	return { active = coaching.active, coaches = coaching.coaches, price = CoachingConfig.Price }
end

local function coachName(lift: string): string
	local coach = QuestConfig.Coaches[lift]
	return if coach then coach.name else lift .. " coach"
end

-- Lines at the top of the player's screen (display only).
local function tell(player: Player, lines: { string })
	local set = remotes
	if set and player.Parent and #lines > 0 then
		set.news:FireClient(player, lines)
	end
end

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

-- The best good lift of `lift` in an attempt history (nil = none).
local function bestOf(history: { any }?): number?
	local best: number? = nil
	for _, attempt in ipairs(history or {}) do
		if attempt.result == "GoodLift" and (best == nil or attempt.weightKg > best) then
			best = attempt.weightKg
		end
	end
	return best
end

--[[
	After a real meet's save (LocalMeetService, one call): judges trial 2 for every coach the player is on it with, and
	grows the active coach's bond. `current` is the meet (its `lifters`, each with `player`, `withdrawn`, `bodyweightKg`,
	`order`, `competitionNumber` and `lifts[lift].history`), `lifter` the player's own entry, `totalKg` their total (nil =
	no total: nothing counts), `lines` the result screen's lines (one is added per trial judged).
]]
function CoachingService.meetFinished(player: Player, current: any, lifter: any, totalKg: number?, lines: { string })
	if totalKg == nil or typeof(current) ~= "table" or typeof(lifter) ~= "table" then
		return
	end
	local coaching = PlayerDataService.getCoaching(player)
	if coaching == nil then
		return
	end
	local news: { string } = {}
	for _, lift in ipairs(CoachingConfig.Lifts) do
		if coaching.coaches[lift] and coaching.coaches[lift].stage == "trial2" then
			local history = (lifter.lifts and lifter.lifts[lift] and lifter.lifts[lift].history) or {}
			local cn = (lifter.competitionNumber or {})[lift] or 0
			local allGood = #history >= 3
			for index = 1, math.min(#history, 3) do
				if history[index].result ~= "GoodLift" then
					allGood = false
				end
			end
			local needThird = cn * CoachingConfig.Trial2.ThirdAtLeast
			local heavyEnough = #history >= 3 and history[3].weightKg >= needThird - 1e-6
			-- The lift's placing in this meet: the best good lift, ties to the lighter lifter, then the earlier entry.
			local mine = bestOf(history)
			local ahead, realOthers = 0, 0
			for _, other in ipairs(current.lifters or {}) do
				if other ~= lifter then
					if other.player ~= nil then
						realOthers += 1
					end
					local theirs = if other.withdrawn then nil else bestOf(other.lifts and other.lifts[lift] and other.lifts[lift].history)
					if mine and theirs and (theirs > mine or (theirs == mine and ((other.bodyweightKg or 0) < (lifter.bodyweightKg or 0)
						or ((other.bodyweightKg or 0) == (lifter.bodyweightKg or 0) and (other.order or 0) < (lifter.order or 0))))) then
						ahead += 1
					end
				end
			end
			local place = ahead + 1
			local placesNeeded = if realOthers > 0 then CoachingConfig.Trial2.TopPlacesWithPlayers else 1
			local placed = mine ~= nil and place <= placesNeeded
			local name = coachName(lift)
			local liftWord = string.lower(lift)
			if allGood and heavyEnough and placed and PlayerDataService.passCoachTrial2(player, lift) then
				table.insert(lines, string.format("TRIAL PASSED! %s is your coach now.", name))
				table.insert(news, string.format("TRIAL PASSED! %s is your coach now.", name))
			else
				local why = if not allGood then "you need all 3 " .. liftWord .. " attempts good"
					elseif not heavyEnough then string.format("your 3rd %s needed %s kg or more", liftWord, kgText(needThird))
					elseif realOthers > 0 then string.format("your %s placed %d (top %d needed)", liftWord, place, placesNeeded)
					else string.format("your %s placed %d (the best of the meet needed)", liftWord, place)
				table.insert(lines, string.format("%s's trial: not yet, %s.", name, why))
			end
		end
	end
	if CoachingConfig.isLift(coaching.active) then
		PlayerDataService.addCoachBond(player)
	end
	tell(player, news)
end

function CoachingService.start()
	if started then
		return
	end
	started = true
	local set = CoachingRemotes.createOnServer(ReplicatedStorage)
	remotes = set

	set.get.OnServerInvoke = function(player: Player): CoachingRemotes.CoachingView?
		if tooSoon(player) then
			return nil
		end
		return viewFor(player)
	end

	set.hire.OnServerInvoke = function(player: Player, lift: any): (string, CoachingRemotes.CoachingView?)
		if tooSoon(player) or not CoachingConfig.isLift(lift) then
			return "Rejected", nil
		end
		local outcome = PlayerDataService.hireCoach(player, lift, CoachingConfig.Price)
		return outcome or "Rejected", viewFor(player)
	end

	set.trial.OnServerInvoke = function(player: Player, lift: any): (boolean, string)
		if tooSoon(player) or not CoachingConfig.isLift(lift) then
			return false, "Not now."
		end
		local coaching = PlayerDataService.getCoaching(player)
		if coaching == nil or coaching.coaches[lift].stage ~= "trial1" then
			return false, "That trial isn't yours to take."
		end
		-- (required here, not at the top: MockMeetService requires the player data modules)
		local MockMeetService = require(ServerFolder:WaitForChild("Meet"):WaitForChild("MockMeetService") :: any)
		return MockMeetService.startCoachTrial(player, lift)
	end

	set.setActive.OnServerInvoke = function(player: Player, id: any): CoachingRemotes.CoachingView?
		if tooSoon(player) or typeof(id) ~= "string" or #id > 20 then
			return nil
		end
		PlayerDataService.setActiveCoach(player, id)
		return viewFor(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)

	-- THE COACHES' FIGURES FOR YOUR OWN SCREEN (GAME_DESIGN §40.5, user 2026-11-24: "Yes work on that"): one dressed
	-- figure of each lift coach, in his own body, kept in ReplicatedStorage (CoachingConfig.FiguresFolder, named by
	-- lift). A lifter's client copies theirs to stand in for the meet platform's coach on their screen only
	-- (MeetCoachLook). Built once at start, like the coach figure the suit cutscene copies (MockMeetService).
	-- PERFORMANCE: three figures in storage, never rendered.
	task.spawn(function()
		-- (required here: MeetFigures pulls in the body and meet modules)
		local MeetFigures = require(ServerFolder:WaitForChild("Meet"):WaitForChild("MeetFigures") :: any)
		local folder = Instance.new("Folder")
		folder.Name = CoachingConfig.FiguresFolder
		for _, lift in ipairs(CoachingConfig.Lifts) do
			local coach = QuestConfig.Coaches[lift]
			if coach then
				local _, figure = MeetFigures.build(folder, "Coach", Vector3.zero, Vector3.new(0, 0, -5), nil,
					{ top = coach.shirt, trousers = coach.trousers, tag = coach.title, build = coach.body })
				if figure then
					figure.Name = lift
				end
			end
		end
		folder.Parent = ReplicatedStorage
	end)
end

return CoachingService
