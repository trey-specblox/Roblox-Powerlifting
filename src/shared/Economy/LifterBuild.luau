--!strict
--[[
	LifterBuild
	Shared / Economy

	Which cartoon body a lifter gets (GAME_DESIGN.md §38.1, approved): size from bodyweight, muscle from how close the
	active class's three Competition Numbers are to that class's Progression Reference table (PP, §29.2). Technique
	never counts. Looks only: it never changes strength.

	Six builds (ClothesConfig.Bodies; GAME_DESIGN §38.2, CHARACTER_ART_DIRECTION.md §5.3-5.4, user's pick 2026-11-13):
	two separate axes. MUSCLE from PP: Low under 0.35, Mid 0.35-0.70, High from 0.70. FAT from bodyweight over the lean
	weight that muscle level fills (Low 66, Mid 83, High 105 kg): at or under it Lean, up to 20 kg over Soft, more Heavy.

	  Muscle \ Fat | Lean     | Soft          | Heavy
	  Low          | Skinny   | SkinnyFat     | Fat
	  Mid          | Fit      | BigBuff       | Fat
	  High         | Muscular | BigBuff       | BigBuff

	A 53 kg starter is measured against the 59 kg references (its class), so starts Skinny. The thresholds are in
	BuildRules, for the user to tune; the small steps within a body (§5.5) are not built.

	The unlimited class (120+) has no reference (ProgressionReferenceConfig.get returns nil there); for LOOKS ONLY it is
	measured against the 120 kg references, never for progression.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ProgressionReferenceConfig = require(Config:WaitForChild("ProgressionReferenceConfig"))
local WeightClass = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression"):WaitForChild("WeightClass"))

local LifterBuild = {}

LifterBuild.BuildRules = {
	-- The average PP of the three lifts at which the muscle level becomes Mid, and High.
	MidFromPP = 0.35,
	HighFromPP = 0.70,
	-- The bodyweight (kg) each muscle level fills while lean; up to SoftKg over it looks Soft, more looks Heavy.
	LeanKg = { Low = 66, Mid = 83, High = 105 } :: { [string]: number },
	SoftKg = 20,
	-- What computer lifters with no numbers and the meet's spotters (an average build in §38.1) get.
	Fallback = "Skinny",
	Spotter = "Fat",
}

-- Muscle level -> fat level -> build (the table above).
LifterBuild.Table = {
	Low = { Lean = "Skinny", Soft = "SkinnyFat", Heavy = "Fat" },
	Mid = { Lean = "Fit", Soft = "BigBuff", Heavy = "Fat" },
	High = { Lean = "Muscular", Soft = "BigBuff", Heavy = "BigBuff" },
} :: { [string]: { [string]: string } }

-- Older names (the three block-skeleton bodies) -> today's build, for saves, Studio attributes and old callers.
LifterBuild.Renamed = { Heavy = "Fat" } :: { [string]: string }

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

-- The build ("Skinny", "SkinnyFat", "Fat", "Fit", "Muscular", "BigBuff") for a lifter of `bodyweightKg` with these
-- Competition Numbers.
function LifterBuild.forNumbers(bodyweightKg: number, competitionNumber: { [string]: number }): string
	local pp = LifterBuild.proximity(bodyweightKg, competitionNumber)
	if pp == nil then
		return LifterBuild.BuildRules.Fallback
	end
	local rules = LifterBuild.BuildRules
	local muscle = if pp >= rules.HighFromPP then "High" elseif pp >= rules.MidFromPP then "Mid" else "Low"
	local over = bodyweightKg - rules.LeanKg[muscle]
	local fat = if over <= 0 then "Lean" elseif over <= rules.SoftKg then "Soft" else "Heavy"
	return LifterBuild.Table[muscle][fat]
end

-- Today's name for a build name (an older one is mapped; an unknown one comes back as it is).
function LifterBuild.current(build: string): string
	return LifterBuild.Renamed[build] or build
end

return LifterBuild
