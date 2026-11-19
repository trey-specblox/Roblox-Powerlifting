--!strict
--[[
	BodyweightConfig
	Shared / Config

	Gaining and losing weight (GAME_DESIGN.md §38.3, "The design", user 2026-11-18, picked from options):

		- The lifter picks MAINTAIN or a goal weight class on the STATS screen. The goal weight is that class's limit
		  exactly (user 2026-11-19: "someone can be exactly 74kg, just cant go over"), and the bulk or cut keeps going
		  until it gets there; then the goal is MAINTAIN by itself (the saved target IS the weight they have) until they
		  pick again. The open class (120+) has no limit: a bulk to it keeps going until the lifter picks MAINTAIN, with
		  only OpenClassCeilingKg as a safety stop.
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

-- The open class (120+) is unlimited (user 2026-11-19), so a bulk to it has no class limit to stop at. This is only a
-- safety stop for a bulk left running, the same as the admin panel's highest bodyweight (AdminConfig.StatLimits).
BodyweightConfig.OpenClassCeilingKg = 200

-- A bodyweight as the player sees it: two decimals, like the class table (59.01 kg is a 66 kg lifter). The server keeps
-- the weight off the hair between a class limit and limit + 0.01 (ProfileOperations.applyBodyweightChange), so a weight
-- shown as "74.00 kg" is always a 74 kg lifter.
function BodyweightConfig.text(kg: number): string
	return string.format("%.2f kg", kg)
end

-- What the STATS screen sends for "hold the weight I have".
BodyweightConfig.Maintain = "Maintain"

-- Studio only: a workspace attribute that multiplies the speed for a test (e.g. 500). The live game ignores it.
BodyweightConfig.StudioSpeedAttribute = "StudioWeightSpeed"

-- The goal weight (kg) for a goal class: its limit (the open class: the safety stop), or nil when `classKey` isn't one.
function BodyweightConfig.goalKgFor(classKey: any): number?
	if typeof(classKey) ~= "string" then
		return nil
	end
	for _, class in ipairs(WeightClassConfig.Classes) do
		if class.label == classKey then
			local limit = class.maximumBodyweight
			return if limit then limit else BodyweightConfig.OpenClassCeilingKg
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
