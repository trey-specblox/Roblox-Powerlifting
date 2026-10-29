--!strict
--[[
	PlayerStatsService
	Server / PlayerData

	Answers the stats screen (StatsRemotes.GET_MY_STATS) with a READ-ONLY
	snapshot of the asking player's own stats: weight class and bodyweight,
	Competition Number and Competition Scale per lift, and every trainable
	technique stat as its effective value (through TechniqueCurve, the one
	curve). It never writes anything and never answers about another player.
	A player may ask at most once every MIN_SECONDS_BETWEEN_ASKS.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))
local TrainingStationConfig = require(ConfigFolder:WaitForChild("TrainingStationConfig"))
local TechniqueCurve = require(Shared:WaitForChild("Difficulty"):WaitForChild("TechniqueCurve"))
local WeightClass = require(Shared:WaitForChild("Progression"):WaitForChild("WeightClass"))
local StatsRemotes = require(Shared:WaitForChild("Stats"):WaitForChild("StatsRemotes"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local PlayerStatsService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.5
local lastAsked: { [Player]: number } = {}
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

	local competitionNumber: { [string]: number } = {}
	local competitionScale: { [string]: number } = {}
	local technique: { StatsRemotes.TechniqueView } = {}
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local cn = profile.competitionNumber and profile.competitionNumber[lift]
		competitionNumber[lift] = if isNumber(cn) then cn else 0
		local scale = profile.competitionScale and profile.competitionScale[lift]
		competitionScale[lift] = if isNumber(scale) then scale else 0
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

	return {
		classLabel = WeightClass.resolve(bodyweight.currentKg).label,
		bodyweightKg = bodyweight.currentKg,
		targetKg = if isNumber(bodyweight.targetKg) then bodyweight.targetKg else bodyweight.currentKg,
		competitionNumber = competitionNumber,
		competitionScale = competitionScale,
		technique = technique,
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
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
end

return PlayerStatsService
