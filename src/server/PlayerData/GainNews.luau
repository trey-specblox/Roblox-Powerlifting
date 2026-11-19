--!strict
--[[
	GainNews
	Server / PlayerData

	Tells ONE player what just made them stronger, for the on-screen gain display (GAME_DESIGN §40.1, user
	2026-11-19: "Any sort of gains"). DISPLAY ONLY: it never changes player data. Whoever saved a gain calls `send`
	after the save, with the amounts it really saved:

		PlayerDataService.awardTrainingProgression   Competition Number from rack training (every tick)
		PlayerDataService.awardTechniqueTraining      technique stats from technique training
		LocalMeetService (every meet level)           Competition Number raises and Competition Scale at a meet's end
		MockMeetService                               Competition Scale at a Mock Meet's end

	Requires nothing from PlayerData, so any server module can use it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GainRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("GainRemotes"))
local TrainingStationConfig = require(Shared:WaitForChild("Config"):WaitForChild("TrainingStationConfig"))
local TechniqueCurve = require(Shared:WaitForChild("Difficulty"):WaitForChild("TechniqueCurve"))

local GainNews = {}

local remote: RemoteEvent? = nil

local function isPositive(value: any): boolean
	return typeof(value) == "number" and value == value and value > 0 and value < math.huge
end

-- Makes the remote now, so a client waiting for it finds it before the first gain.
function GainNews.start()
	if remote == nil then
		remote = GainRemotes.createOnServer(ReplicatedStorage)
	end
end

-- Competition Number gained in `lift` (kg).
function GainNews.strength(lift: string, kg: number): GainRemotes.Gain
	return { kind = "Strength", stat = lift, lift = lift, label = string.upper(lift), amount = kg, unit = "kg" }
end

-- Competition Scale gained in `lift` (kg).
function GainNews.scale(lift: string, kg: number): GainRemotes.Gain
	return { kind = "Scale", stat = lift, lift = lift, label = string.upper(lift) .. " SCALE", amount = kg, unit = "kg" }
end

--[[
	A technique stat that went from `rawBefore` to `rawAfter` raw points, shown the way the STATS screen shows it:
	its effective value (TechniqueCurve). Nil when the effective value didn't move.
]]
function GainNews.technique(stat: string, lift: string, rawBefore: number, rawAfter: number): GainRemotes.Gain?
	local okBefore, before = pcall(TechniqueCurve.toEffective, math.max(rawBefore, 0))
	local okAfter, after = pcall(TechniqueCurve.toEffective, math.max(rawAfter, 0))
	if not okBefore or not okAfter or not isPositive(after - before) then
		return nil
	end
	local name = (TrainingStationConfig.TechniqueStatNames :: any)[stat] or stat
	return { kind = "Technique", stat = stat, lift = lift, label = string.upper(name), amount = after - before, unit = "" }
end

-- Sends `gains` (those above zero) from `source` to `player`. Does nothing when none are.
function GainNews.send(player: Player, source: string, gains: { GainRemotes.Gain? })
	if player.Parent == nil then
		return
	end
	local kept: { GainRemotes.Gain } = {}
	for _, gain in pairs(gains) do
		if gain and isPositive(gain.amount) then
			table.insert(kept, gain)
		end
	end
	if #kept == 0 then
		return
	end
	GainNews.start()
	local news: GainRemotes.GainNews = { source = source, gains = kept }
	(remote :: RemoteEvent):FireClient(player, news)
end

return GainNews
