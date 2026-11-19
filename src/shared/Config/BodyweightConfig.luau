--!strict
--[[
	BodyweightConfig
	Shared / Config

	Gaining and losing weight (GAME_DESIGN.md §38.3, "The design", user 2026-11-18, picked from options):

		- The lifter picks MAINTAIN or a goal weight class on the STATS screen. The goal weight is just under that class's
		  limit (the limit minus BelowLimitKg), or OpenClassGoalKg for the open class (120+), and the body stops there.
		- The weight moves while the lifter earns Competition Number at a training rack: KgPerFullTrainingDay for a full
		  day's training (the daily cap, ProgressionConfig.DailyTraining.DailyCapEV), i.e. KgPerEV for each EV earned. The
		  same speed up and down. Meets, technique training and practice lifts never change it.

	Shared so the STATS screen can name the goal class of a target weight the same way the server sets it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))
local WeightClassConfig = require(ConfigFolder:WaitForChild("WeightClassConfig"))

local BodyweightConfig = {}

-- How much a full day of training moves the weight (user's pick, "Fast": 2 kg; Claude had recommended 1 kg).
BodyweightConfig.KgPerFullTrainingDay = 2.0
BodyweightConfig.KgPerEV = BodyweightConfig.KgPerFullTrainingDay / ProgressionConfig.DailyTraining.DailyCapEV

-- A goal sits this far under its class's limit, so a weigh-in never lands a hair over it.
BodyweightConfig.BelowLimitKg = 0.5

-- The goal weight for the open class (no limit). Everything over 120 kg is cosmetic (GAME_DESIGN §29.11).
BodyweightConfig.OpenClassGoalKg = 125

-- What the STATS screen sends for "hold the weight I have".
BodyweightConfig.Maintain = "Maintain"

-- Studio only: a workspace attribute that multiplies the speed for a test (e.g. 500). The live game ignores it.
BodyweightConfig.StudioSpeedAttribute = "StudioWeightSpeed"

-- The goal weight (kg) for a goal class, or nil when `classKey` isn't a weight class.
function BodyweightConfig.goalKgFor(classKey: any): number?
	if typeof(classKey) ~= "string" then
		return nil
	end
	for _, class in ipairs(WeightClassConfig.Classes) do
		if class.label == classKey then
			local limit = class.maximumBodyweight
			return if limit then limit - BodyweightConfig.BelowLimitKg else BodyweightConfig.OpenClassGoalKg
		end
	end
	return nil
end

-- Every class label, lightest first (the goal list on the STATS screen).
function BodyweightConfig.classLabels(): { string }
	local labels = {}
	for _, class in ipairs(WeightClassConfig.Classes) do
		table.insert(labels, class.label)
	end
	return labels
end

assert(BodyweightConfig.KgPerEV > 0 and BodyweightConfig.KgPerEV < math.huge, "[BodyweightConfig] KgPerEV must be positive")

return BodyweightConfig
