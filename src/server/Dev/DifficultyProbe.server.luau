--!strict
--[[
	DifficultyProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Prints the difficulty engine's output to the Studio
	Output window on server start, so the curves can be checked by eye against
	the anchors in GAME_DESIGN.md.

	OFF BY DEFAULT. SET TO true TO RUN IT.

	The curves it prints have been checked against the anchors and the difficulty
	engine is in use by all three lifts, so 66 lines of output on every Play is
	noise rather than information. Turn it on when a curve, an anchor or the
	resolver changes, then turn it off again.

	Kept rather than deleted: re-deriving these tables by hand to check a future
	balance change would be far more work than flipping this flag. Nothing else
	requires it.
]]

local ENABLED = false

if not ENABLED then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DifficultyFolder = Shared:WaitForChild("Difficulty")
local ProgressionFolder = Shared:WaitForChild("Progression")
local DifficultyResolver = require(DifficultyFolder:WaitForChild("DifficultyResolver"))
local IntensityCurve = require(DifficultyFolder:WaitForChild("IntensityCurve"))
local TechniqueCurve = require(DifficultyFolder:WaitForChild("TechniqueCurve"))
local WeightClass = require(ProgressionFolder:WaitForChild("WeightClass"))
local RecordPercentage = require(ProgressionFolder:WaitForChild("RecordPercentage"))
local MeetFolder = Shared:WaitForChild("Meet")
local AttemptRules = require(MeetFolder:WaitForChild("AttemptRules"))
local MeetTotal = require(MeetFolder:WaitForChild("MeetTotal"))
local ConfigFolder = Shared:WaitForChild("Config")
local StartingValuesConfig = require(ConfigFolder:WaitForChild("StartingValuesConfig"))
local ModifiersFolder = Shared:WaitForChild("Modifiers")
local ModifierChannel = require(ModifiersFolder:WaitForChild("ModifierChannel"))
local ModifierSet = require(ModifiersFolder:WaitForChild("ModifierSet"))
local ModifierRegistry = require(ModifiersFolder:WaitForChild("ModifierRegistry"))

print("=== Difficulty engine probe ===")

print("")
print("Personal intensity -> base difficulty (spec anchors marked *)")
local intensityChecks = {
	{ 0.50, 10 },
	{ 0.60, 15 },
	{ 0.70, 22 },
	{ 0.80, 32 },
	{ 0.90, 45 },
	{ 0.95, 55 },
	{ 1.00, 65 },
	{ 1.025, 72 },
	{ 1.05, 80 },
	{ 1.075, 88 },
	{ 1.10, 95 },
}
for _, check in ipairs(intensityChecks) do
	local intensity, expected = check[1], check[2]
	local actual = IntensityCurve.toBaseDifficulty(intensity)
	local status = if math.abs(actual - expected) < 0.0001 then "*" else "MISMATCH"
	print(string.format(
		"  %6.1f%% -> %6.2f  (spec %d) %s  [%s]",
		intensity * 100,
		actual,
		expected,
		status,
		IntensityCurve.classify(actual)
	))
end

print("")
print("Above the forecasted max (should approach but never reach 100)")
for _, intensity in ipairs({ 1.15, 1.20, 1.30, 1.50, 2.00 }) do
	local actual = IntensityCurve.toBaseDifficulty(intensity)
	print(string.format("  %6.1f%% -> %7.3f  [%s]", intensity * 100, actual, IntensityCurve.classify(actual)))
end

print("")
print("Raw technique -> effective technique (spec anchors marked *)")
local techniqueChecks = {
	{ 0, 10 },
	{ 100, 15 },
	{ 250, 22 },
	{ 500, 30 },
	{ 1000, 40 },
	{ 2500, 55 },
	{ 5000, 70 },
	{ 10000, 82 },
	{ 25000, 92 },
	{ 100000, 98 },
}
for _, check in ipairs(techniqueChecks) do
	local raw, expected = check[1], check[2]
	local actual = TechniqueCurve.toEffective(raw)
	local status = if math.abs(actual - expected) < 0.0001 then "*" else "MISMATCH"
	print(string.format("  %9d -> %6.2f  (spec %d) %s", raw, actual, expected, status))
end

print("")
print("Far past the final technique anchor (must stay below 100)")
for _, raw in ipairs({ 250000, 1000000, 10000000 }) do
	print(string.format("  %9d -> %7.3f", raw, TechniqueCurve.toEffective(raw)))
end

print("")
print("Worked example: a 200 kg forecasted squat, attempting 200 kg")
print("(same lift, same weight, two different characters)")
for _, depthAwareness in ipairs({ 0, 500, 5000, 25000 }) do
	local resolved = DifficultyResolver.resolve({
		attemptWeight = 200,
		forecastedMax = 200,
		techniqueStat = depthAwareness,
	})
	print(string.format(
		"  Depth Awareness %6d -> difficulty %.2f [%s], effective technique %.2f",
		depthAwareness,
		resolved.baseDifficulty,
		resolved.classification,
		resolved.effectiveTechnique
	))
end
print("  Note difficulty never moves. Only effective technique does, and that is")
print("  what will open up the skill check once minigames are built.")

print("Bodyweight -> weight class (boundaries are inclusive upper bounds)")
for _, bodyweight in ipairs({ 55, 58.9, 59, 59.1, 74, 83.5, 105, 120, 120.1, 155 }) do
	local class = WeightClass.resolve(bodyweight)
	local headroom = WeightClass.headroomToNextClass(bodyweight)
	local headroomText = if headroom then string.format("%.1f kg to next class", headroom) else "top class"
	print(string.format("  %6.1f kg -> %-9s  (%s)", bodyweight, class.label, headroomText))
end

print("")
print("Record Percentage availability")
if RecordPercentage.isConfigured() then
	print("  reference records ARE configured")
else
	print("  reference records are NOT configured yet.")
	print("  Record-based progression scaling is inactive. This is expected until")
	print("  ReferenceRecordConfig is filled in. Expect one warning per lift below.")
end
local sampleClass = WeightClass.resolve(83).label
for _, liftName in ipairs({ "Squat", "Bench", "Deadlift" }) do
	local percentage = RecordPercentage.resolve(liftName, sampleClass, 250)
	if percentage then
		print(string.format("  250 kg %s in %s -> %.1f%% of record", liftName, sampleClass, percentage * 100))
	else
		print(string.format("  250 kg %s in %s -> no record configured", liftName, sampleClass))
	end
end

print("Attempt rules, using the worked example from GAME_DESIGN.md Q11")
print("  History: 180 kg GOOD, then 190 kg NO LIFT")
local squatHistory = {
	{ weightKg = 180, result = "GoodLift" },
	{ weightKg = 190, result = "NoLift" },
}
type Declaration = { weightKg: number, shouldPass: boolean, note: string }
local declarations: { Declaration } = {
	{ weightKg = 190, shouldPass = true, note = "repeat a failed weight" },
	{ weightKg = 192.5, shouldPass = true, note = "minimum legal increase" },
	{ weightKg = 185, shouldPass = false, note = "below a weight already attempted" },
	{ weightKg = 191, shouldPass = false, note = "increase smaller than 2.5 kg" },
	{ weightKg = 250, shouldPass = true, note = "a big jump is allowed" },
	{ weightKg = 0, shouldPass = false, note = "zero is not a weight" },
}
for _, case in ipairs(declarations) do
	local weight, shouldPass, note = case.weightKg, case.shouldPass, case.note
	local allowed, rejection = AttemptRules.validate(squatHistory, weight)
	local matched = if allowed == shouldPass then "*" else "UNEXPECTED"
	local detail = if rejection then rejection.code else "allowed"
	print(string.format("  %7.1f kg -> %-24s %s  (%s)", weight, detail, matched, note))
end
print(string.format("  attempts remaining: %d", AttemptRules.attemptsRemaining(squatHistory)))
print(string.format("  lowest legal next weight: %.1f kg", AttemptRules.lowestLegalNextWeight(squatHistory) or -1))

print("")
print("  After a GOOD lift the weight must increase (AllowRepeatAfterGoodLift = false)")
local madeHistory = { { weightKg = 200, result = "GoodLift" } }
local repeatAllowed, repeatRejection = AttemptRules.validate(madeHistory, 200)
print(string.format(
	"  repeating 200 kg after making it -> %s (%s)",
	if repeatAllowed then "allowed" else "rejected",
	if repeatRejection then repeatRejection.code else "none"
))

print("")
print("  Fourth attempt must always be refused")
local fullHistory = {
	{ weightKg = 180, result = "GoodLift" },
	{ weightKg = 190, result = "GoodLift" },
	{ weightKg = 200, result = "NoLift" },
}
local fourthAllowed, fourthRejection = AttemptRules.validate(fullHistory, 210)
print(string.format(
	"  declaring a 4th attempt -> %s (%s)",
	if fourthAllowed then "allowed" else "rejected",
	if fourthRejection then fourthRejection.code else "none"
))

print("")
print("Totals and bomb-out")
local completedMeet = {
	Squat = { { weightKg = 180, result = "GoodLift" }, { weightKg = 190, result = "GoodLift" } },
	Bench = { { weightKg = 120, result = "GoodLift" }, { weightKg = 125, result = "NoLift" } },
	Deadlift = { { weightKg = 220, result = "GoodLift" } },
}
local scored = MeetTotal.resolve(completedMeet)
print(string.format(
	"  best S/B/D = %.1f / %.1f / %.1f",
	scored.best.Squat or 0,
	scored.best.Bench or 0,
	scored.best.Deadlift or 0
))
print(string.format("  total = %.1f kg (expected 535.0)", scored.total or -1))

local bombedMeet = {
	Squat = { { weightKg = 180, result = "GoodLift" } },
	Bench = { { weightKg = 120, result = "NoLift" }, { weightKg = 120, result = "NoLift" } },
	Deadlift = { { weightKg = 220, result = "GoodLift" } },
}
local bombed = MeetTotal.resolve(bombedMeet)
print(string.format(
	"  missed every bench -> bombedOut = %s, total = %s, bombed lifts = %s",
	tostring(bombed.bombedOut),
	tostring(bombed.total),
	table.concat(bombed.bombedLifts, ", ")
))

print("A brand new lifter (StartingValuesConfig)")
local startClass = WeightClass.resolve(StartingValuesConfig.BodyweightKg)
print(string.format(
	"  bodyweight %.0f kg -> competes in the %s class (no 53 kg class exists, by design)",
	StartingValuesConfig.BodyweightKg,
	startClass.label
))
local startingTotal = StartingValuesConfig.Forecasted.Squat
	+ StartingValuesConfig.Forecasted.Bench
	+ StartingValuesConfig.Forecasted.Deadlift
print(string.format(
	"  forecasted S/B/D = %.0f / %.0f / %.0f, total %.0f kg",
	StartingValuesConfig.Forecasted.Squat,
	StartingValuesConfig.Forecasted.Bench,
	StartingValuesConfig.Forecasted.Deadlift,
	startingTotal
))
for _, liftName in ipairs({ "Squat", "Bench", "Deadlift" }) do
	local forecast = StartingValuesConfig.Forecasted[liftName]
	local percentage = RecordPercentage.resolve(liftName, startClass.label, forecast)
	print(string.format(
		"  %-8s %.0f kg is %.1f%% of the %s reference record -> progression should be fast",
		liftName,
		forecast,
		(percentage or 0) * 100,
		startClass.label
	))
end

print("")
print("Record Percentage near the limit (the Q3 worked example, with real records)")
local eliteClass = WeightClass.resolve(83).label
for _, forecast in ipairs({ 200, 300, 338 }) do
	local percentage = RecordPercentage.resolve("Squat", eliteClass, forecast)
	print(string.format(
		"  %.0f kg squat in %s -> %.1f%% of record",
		forecast,
		eliteClass,
		(percentage or 0) * 100
	))
end
print("  Note the lift difficulty of a 100% attempt is identical in all three cases.")
print("  Only PROGRESSION slows down. That is the Q3 separation working.")

print("")
print("Modifier architecture")
print(string.format("  registered sources at startup: %d (expected 0)", #ModifierRegistry.registeredSourceNames()))

local unmodified = DifficultyResolver.resolve({
	attemptWeight = 200,
	forecastedMax = 200,
	techniqueStat = 500,
})
print(string.format(
	"  no modifiers      -> difficulty %.2f, effective technique %.2f",
	unmodified.baseDifficulty,
	unmodified.effectiveTechnique
))

-- A stand-in for equipment and height, proving the seam without inventing real
-- balance values. Registered, demonstrated, then removed.
ModifierRegistry.register("DemoEquipment", function()
	local set = ModifierSet.create()
	ModifierSet.add(set, {
		channel = ModifierChannel.EffectiveTechnique,
		operation = "Add",
		value = 10,
		source = "DemoEquipment:Belt",
	})
	return set
end)
ModifierRegistry.register("DemoHeight", function()
	local set = ModifierSet.create()
	ModifierSet.add(set, {
		channel = ModifierChannel.BaseDifficulty,
		operation = "Add",
		value = -5,
		source = "DemoHeight:Short",
	})
	return set
end)

local gathered = ModifierRegistry.gather({ liftName = "Squat", phase = "Depth" })
local modified = DifficultyResolver.resolve({
	attemptWeight = 200,
	forecastedMax = 200,
	techniqueStat = 500,
	modifiers = gathered,
})
print(string.format(
	"  with 2 sources    -> difficulty %.2f (was %.2f), effective technique %.2f (was %.2f)",
	modified.baseDifficulty,
	modified.baseDifficultyBeforeModifiers,
	modified.effectiveTechnique,
	modified.effectiveTechniqueBeforeModifiers
))
print(string.format("  difficulty sources:  %s", ModifierSet.describe(gathered, ModifierChannel.BaseDifficulty)))
print(string.format("  technique sources:   %s", ModifierSet.describe(gathered, ModifierChannel.EffectiveTechnique)))

-- The safety clamp: no amount of gear may make execution automatic.
local absurd = ModifierSet.create()
ModifierSet.add(absurd, {
	channel = ModifierChannel.EffectiveTechnique,
	operation = "Add",
	value = 9999,
	source = "DemoAbsurdGear",
})
local clamped = DifficultyResolver.resolve({
	attemptWeight = 200,
	forecastedMax = 200,
	techniqueStat = 500,
	modifiers = absurd,
})
print(string.format(
	"  +9999 technique   -> effective technique %.2f, clamped to the curve ceiling %.2f",
	clamped.effectiveTechnique,
	TechniqueCurve.ceiling()
))
print("  Forecasted Max is untouched in every case: there is no channel for it.")

ModifierRegistry.resetForTesting()
print(string.format("  registry cleaned up: %d sources remain", #ModifierRegistry.registeredSourceNames()))

print("")
print("=== Probe complete ===")
