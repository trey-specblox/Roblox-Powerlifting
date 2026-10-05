--!strict
--[[
	StartingValuesConfig
	Shared / Config

	What a brand-new lifter begins with. From GAME_DESIGN.md Group D / Q2.

	These are the first thing every player experiences, so they live in one place
	rather than being scattered through whichever system happens to create a
	profile.

	A new lifter starts at 53 kg bodyweight, which is BELOW the lightest
	competition class (59 kg). That is intentional. WeightClass.resolve places them
	in the 59 kg class, because classes are inclusive upper bounds, and no 53 kg
	competition class or reference record exists or should be invented.

	The bodyweight/nutrition system will later let players move between classes.
]]

local StartingValuesConfig = {}

-- Kilograms.
StartingValuesConfig.BodyweightKg = 53

--[[
	Forecasted maxes ARE the lifter's strength, per Q7. There is no separate
	hidden true-strength value. A new lifter squats, benches and deadlifts 25 kg,
	for a starting forecasted total of 75 kg.
]]
StartingValuesConfig.Forecasted = {
	Squat = 25,
	Bench = 25,
	Deadlift = 25,
}

--[[
	All five technique stats start at 0. This is a confirmed design decision.

	Zero means COMPLETELY UNTRAINED TECHNIQUE, not missing data. The effective
	technique curve is anchored at raw 0 and yields 10 effective technique, so an
	untrained lifter is still capable of lifting. They simply have no trained
	technique working in their favour yet.

	That makes progression legible: a new lifter begins at 25 kg of strength with 0
	trained technique, and improves both through training.
]]
StartingValuesConfig.Technique = {
	SquatControl = 0,
	DepthAwareness = 0,
	StartControl = 0,
	PressPower = 0,
	-- Added with schema version 2. Drives the Deadlift's typing pull.
	PullStrength = 0,
	Lockout = 0,
}

return StartingValuesConfig
