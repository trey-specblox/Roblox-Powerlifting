--!strict
--[[
	PlayerStatsService
	Server / PlayerData

	Answers the stats screen (StatsRemotes.GET_MY_STATS) with a READ-ONLY
	snapshot of the asking player's own stats: weight class and bodyweight,
	Competition Number and Competition Scale per lift and the best meet Total
	(all from the build of the current class), and every trainable
	technique stat as its effective value (through TechniqueCurve, the one
	curve). The snapshot never writes anything and never answers about another
	player. A player may ask at most once every MIN_SECONDS_BETWEEN_ASKS.

	The one thing the STATS screen may change is the player's own weight goal
	(StatsRemotes.SET_WEIGHT_GOAL, GAME_DESIGN §38.3), through
	PlayerDataService.setWeightGoal; never the weight itself. It also sends
	the WEIGHT_NEWS lines when training moves the weight into a new class or
	onto the goal.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))
local TrainingStationConfig = require(ConfigFolder:WaitForChild("TrainingStationConfig"))
local MeetLevelConfig = require(ConfigFolder:WaitForChild("MeetLevelConfig"))
local BodyweightConfig = require(ConfigFolder:WaitForChild("BodyweightConfig"))
local TechniqueCurve = require(Shared:WaitForChild("Difficulty"):WaitForChild("TechniqueCurve"))
local WeightClass = require(Shared:WaitForChild("Progression"):WaitForChild("WeightClass"))
local StatsRemotes = require(Shared:WaitForChild("Stats"):WaitForChild("StatsRemotes"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ProfileOperations = require(script.Parent:WaitForChild("ProfileOperations"))

local PlayerStatsService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.5
-- The most State Champion badges sent to the STATS screen (two years of monthly wins).
local MAX_BADGES = 24
local lastAsked: { [Player]: number } = {}
local MIN_SECONDS_BETWEEN_GOALS = 0.5
local lastGoal: { [Player]: number } = {}
local started = false

local function isNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function snapshotFor(player: Player): StatsRemotes.StatsSnapshot?
	local data = PlayerDataService.getData(player)
	if data == nil then
		return nil
	end
	local profile = data :: any
	local bodyweight = profile.bodyweight
	if typeof(bodyweight) ~= "table" or not isNumber(bodyweight.currentKg) or bodyweight.currentKg <= 0 then
		return nil
	end

	-- The build of the current class (schema v6): its numbers are the ones shown.
	local build = ProfileOperations.getActiveBuild(data)
	local competitionNumber: { [string]: number } = {}
	local competitionScale: { [string]: number } = {}
	local technique: { StatsRemotes.TechniqueView } = {}
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local cn = build and (build.competitionNumber :: any)[lift]
		competitionNumber[lift] = if isNumber(cn) then cn else 0
		local scale = build and (build.competitionScale :: any)[lift]
		competitionScale[lift] = if isNumber(scale) and scale >= 0 then scale else 0
		for _, stat in ipairs(ProgressionConfig.TrainableTechnique[lift] or {}) do
			local raw = profile.technique and profile.technique[stat]
			if isNumber(raw) and raw >= 0 then
				local ok, effective = pcall(TechniqueCurve.toEffective, raw)
				if ok and isNumber(effective) then
					table.insert(technique, {
						stat = stat,
						name = (TrainingStationConfig.TechniqueStatNames :: any)[stat] or stat,
						lift = lift,
						effective = effective,
					})
				end
			end
		end
	end

	-- The meet titles, best first (GAME_DESIGN §35.8).
	local titles: { string } = {}
	local owned = ProfileOperations.getTitles(data)
	for _, id in ipairs({ "StateChampion", "StateRunnerUp", "StateThird", "RegionalChampion", "RegionalRunnerUp",
		"RegionalThird" }) do
		local count = owned[id]
		if count then
			table.insert(titles, if count > 1 then string.format("%s x%d", MeetLevelConfig.Titles[id], count)
				else MeetLevelConfig.Titles[id])
		end
	end

	-- The numbered State Champion badges, newest first (GAME_DESIGN §36.4), at most MAX_BADGES of them.
	local championBadges: { StatsRemotes.ChampionBadgeView } = {}
	for _, badge in ipairs(ProfileOperations.getStateChampionBadges(data)) do
		if #championBadges >= MAX_BADGES then
			break
		end
		table.insert(championBadges, { number = badge.number, seasonLabel = MeetLevelConfig.seasonLabel(badge.season) })
	end

	local nowUnix = os.time()
	-- The ladder of the class the player is in now (points are per class, GAME_DESIGN §36.3).
	local ladder = ProfileOperations.getLadder(data, WeightClass.resolve(bodyweight.currentKg).label, nowUnix)
	-- And the road to Nationals in that class (GAME_DESIGN §36.4).
	local nationals = ProfileOperations.getNationals(data, WeightClass.resolve(bodyweight.currentKg).label, nowUnix)

	return {
		classLabel = WeightClass.resolve(bodyweight.currentKg).label,
		bodyweightKg = bodyweight.currentKg,
		targetKg = if isNumber(bodyweight.targetKg) then bodyweight.targetKg else bodyweight.currentKg,
		competitionNumber = competitionNumber,
		competitionScale = competitionScale,
		bestTotalKg = if build and isNumber(build.bestTotalKg) and build.bestTotalKg > 0 then build.bestTotalKg else 0,
		technique = technique,
		coins = ProfileOperations.getCoins(data),
		titles = titles,
		championBadges = championBadges,
		ladder = { points = ladder.points, target = ladder.target, qualified = ladder.qualified,
			seasonEndsAt = MeetLevelConfig.seasonEndsAt(nowUnix) },
		nationals = { placings = nationals.placings, target = nationals.target, qualified = nationals.qualified,
			competed = nationals.competedSeason ~= "" },
	}
end

function PlayerStatsService.start()
	if started then
		return
	end
	started = true
	local remotes = StatsRemotes.createOnServer(ReplicatedStorage)
	remotes.getMyStats.OnServerInvoke = function(player: Player): StatsRemotes.StatsSnapshot?
		local now = os.clock()
		if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
			return nil
		end
		lastAsked[player] = now
		return snapshotFor(player)
	end

	-- The weight goal (GAME_DESIGN §38.3). The client only asks; the type, the class and the spot warning are checked here
	-- and in ProfileOperations.setWeightGoal.
	remotes.setWeightGoal.OnServerInvoke = function(player: Player, goal: any, confirmed: any): StatsRemotes.WeightGoalReply
		local now = os.clock()
		if now - (lastGoal[player] or -math.huge) < MIN_SECONDS_BETWEEN_GOALS then
			return { outcome = "Rejected", message = "One moment…" }
		end
		lastGoal[player] = now
		if typeof(goal) ~= "string" or (goal ~= BodyweightConfig.Maintain and BodyweightConfig.goalKgFor(goal) == nil) then
			return { outcome = "Rejected", message = "That isn't a weight class." }
		end
		local agreed = typeof(confirmed) == "boolean" and confirmed
		local outcome, message, targetKg = PlayerDataService.setWeightGoal(player, goal, agreed)
		return { outcome = outcome, message = message, targetKg = targetKg }
	end

	-- Training moved someone's weight: a line when they enter a new class or reach their goal.
	PlayerDataService.onBodyweightChanged(function(player, change)
		if not player.Parent then
			return
		end
		if change.classAfter ~= change.classBefore then
			remotes.weightNews:FireClient(player, string.format("You weigh %.1f kg: you're a %s lifter now.", change.afterKg,
				change.classAfter))
		elseif change.afterKg == change.targetKg then
			remotes.weightNews:FireClient(player, string.format("Goal reached: %.1f kg. Holding it there.", change.afterKg))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
		lastGoal[player] = nil
	end)
end

return PlayerStatsService
