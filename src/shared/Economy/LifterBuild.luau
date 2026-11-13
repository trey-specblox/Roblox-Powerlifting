--!strict
--[[
	LifterBuild
	Shared / Economy

	Which cartoon body a lifter gets (GAME_DESIGN.md §38.1, approved): size from bodyweight, muscle from how close the
	active class's three Competition Numbers are to that class's Progression Reference table (PP, §29.2). Technique
	never counts. Looks only: it never changes strength.

	Three builds to start (ClothesConfig.Bodies): high PP looks Muscular in any class; below that a heavy lifter looks
	Heavy (fat), a light one Skinny. A 53 kg starter is measured against the 59 kg references (its class), so starts
	Skinny. The thresholds are Claude's pick (2026-11-12), in BuildRules, for the user to tune; the per-part steady
	thickening between builds and per-lift muscle growth are proposals, not built.

	The unlimited class (120+) has no reference (ProgressionReferenceConfig.get returns nil there); for LOOKS ONLY it is
	measured against the 120 kg references, never for progression.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ProgressionReferenceConfig = require(Config:WaitForChild("ProgressionReferenceConfig"))
local WeightClass = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression"):WaitForChild("WeightClass"))

local LifterBuild = {}

LifterBuild.BuildRules = {
	-- The average PP of the three lifts at or above which a lifter looks Muscular.
	MuscularFromPP = 0.40,
	-- Below that, a lifter heavier than this (kg) looks Heavy, at or under it Skinny.
	HeavyAboveKg = 83,
	-- What computer lifters with no numbers and the meet's spotters (an average build in §38.1) get.
	Fallback = "Skinny",
	Spotter = "Heavy",
}

local LIFTS = { "Squat", "Bench", "Deadlift" }

-- The average PP of `competitionNumber` ({Squat, Bench, Deadlift} in kg) for the class of `bodyweightKg`, or nil.
function LifterBuild.proximity(bodyweightKg: number, competitionNumber: { [string]: number }): number?
	if typeof(bodyweightKg) ~= "number" or bodyweightKg ~= bodyweightKg or bodyweightKg <= 0 then
		return nil
	end
	local label = WeightClass.resolve(bodyweightKg).label
	local total, count = 0, 0
	for _, lift in ipairs(LIFTS) do
		local reference = ProgressionReferenceConfig.get(lift, label) or ProgressionReferenceConfig.get(lift, "120 kg")
		local cn = competitionNumber[lift]
		if reference and reference > 0 and typeof(cn) == "number" and cn == cn then
			total += math.clamp(cn / reference, 0, 2)
			count += 1
		end
	end
	return if count == 3 then total / count else nil
end

-- The build ("Skinny", "Heavy", "Muscular") for a lifter of `bodyweightKg` with these Competition Numbers.
function LifterBuild.forNumbers(bodyweightKg: number, competitionNumber: { [string]: number }): string
	local pp = LifterBuild.proximity(bodyweightKg, competitionNumber)
	if pp == nil then
		return LifterBuild.BuildRules.Fallback
	end
	if pp >= LifterBuild.BuildRules.MuscularFromPP then
		return "Muscular"
	end
	return if bodyweightKg > LifterBuild.BuildRules.HeavyAboveKg then "Heavy" else "Skinny"
end

return LifterBuild
