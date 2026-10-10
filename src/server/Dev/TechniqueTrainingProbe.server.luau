--!strict
--[[
	TechniqueTrainingProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Exercises rack technique training, checkpoint 5B.7:
	the pure TechniqueTraining maths and ProfileOperations.applyTechniqueTraining
	-- the pure core behind PlayerDataService.awardTechniqueTraining -- and prints
	a pass/fail line per check to the Studio Output window.

	Set ENABLED to false to silence it, or delete this file. Nothing requires it,
	it creates no remotes, and it NEVER TOUCHES A REAL PLAYER'S PROFILE: every
	profile is a deep copy of the schema template held in a local variable.

	The rack side -- presence, switching, the CN stop, midnight, 120+ at a rack
	-- is TrainingStationProbe's job. This probe tests the award itself.

	=========================================================================
	OFF BY DEFAULT. SET TO true TO RUN IT.
	=========================================================================
]]

local ENABLED = false
if not ENABLED then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local TechniqueTraining = require(ProgressionFolder:WaitForChild("TechniqueTraining"))
local TrainingAllowance = require(ProgressionFolder:WaitForChild("TrainingAllowance"))

local DifficultyFolder = Shared:WaitForChild("Difficulty")
local TechniqueCurve = require(DifficultyFolder:WaitForChild("TechniqueCurve"))

local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerProfileSchema = require(PlayerDataFolder:WaitForChild("PlayerProfileSchema"))
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))

local TEMPLATE = PlayerProfileSchema.template
local HOUR = 3600
local DAY = 86400

local passed = 0
local failed = 0

local function check(label: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(string.format("  PASS  %s", label))
	else
		failed += 1
		warn(string.format("  FAIL  %s%s", label, if detail then "  -- " .. detail else ""))
	end
end

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 0.000001)
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

--[[
	Structural equality, treating NaN as equal to NaN (a corrupt value that is
	left exactly as found must compare equal to itself).
]]
local function deepEqual(a: any, b: any): boolean
	if typeof(a) ~= typeof(b) then
		return false
	end

	if typeof(a) ~= "table" then
		return a == b or (a ~= a and b ~= b)
	end

	for key, value in pairs(a) do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function newProfile(): PlayerProfileSchema.ProfileData
	return deepCopy(TEMPLATE)
end

local function raw(data: PlayerProfileSchema.ProfileData, stat: string): number
	return (data.technique :: any)[stat]
end

-- Everything EXCEPT the named technique stats, for "nothing else moved" checks.
local function withoutStats(data: PlayerProfileSchema.ProfileData, stats: { string }): any
	local copy = deepCopy(data)
	for _, stat in ipairs(stats) do
		copy.technique[stat] = nil
	end
	return copy
end

local function apply(data: PlayerProfileSchema.ProfileData, lift: any, primary: any, seconds: any)
	return ProfileOperations.applyTechniqueTraining(data, lift, primary, seconds)
end

local TRAINING = ProgressionConfig.DailyTraining

print("=== TechniqueTrainingProbe (checkpoint 5B.7) ===")

--------------------------------------------------------------------------------
print("-- 1. configuration: rate, split, pairings, no cap")
--------------------------------------------------------------------------------

do
	check("TechniqueRawPerHour is 2.00", TRAINING.TechniqueRawPerHour == 2.00)
	check("TechniquePrimaryShare is 0.80", TRAINING.TechniquePrimaryShare == 0.80)
	check("DailyCapTechniqueRaw no longer exists", (TRAINING :: any).DailyCapTechniqueRaw == nil)
	check("TrainingAllowance.remainingTechnique no longer exists", (TrainingAllowance :: any).remainingTechnique == nil)

	local pairs_ = ProgressionConfig.TrainableTechnique :: any
	check("Squat trains SquatControl and DepthAwareness",
		pairs_.Squat[1] == "SquatControl" and pairs_.Squat[2] == "DepthAwareness" and #pairs_.Squat == 2)
	check("Bench trains StartControl and PressPower",
		pairs_.Bench[1] == "StartControl" and pairs_.Bench[2] == "PressPower" and #pairs_.Bench == 2)
	check("Deadlift trains Lockout only", pairs_.Deadlift[1] == "Lockout" and #pairs_.Deadlift == 1)

	local pull = false
	for _, stats in pairs(pairs_) do
		if table.find(stats, "PullStrength") then
			pull = true
		end
	end
	check("PullStrength is in no pairing", not pull)

	local copy = TechniqueTraining.statsFor("Squat") :: { string }
	copy[1] = "Hacked"
	check("statsFor returns a copy that cannot edit the table", pairs_.Squat[1] == "SquatControl")
end

--------------------------------------------------------------------------------
print("-- 2. the pure maths")
--------------------------------------------------------------------------------

do
	check("one hour is 2.00 raw", TechniqueTraining.rawPointsFor(HOUR) == 2)
	check("a 10 s tick is 1/180 raw", near(TechniqueTraining.rawPointsFor(10), 2 / 360, 1e-15))
	check("zero seconds is 0", TechniqueTraining.rawPointsFor(0) == 0)
	check("negative seconds is 0", TechniqueTraining.rawPointsFor(-30) == 0)
	check("NaN is 0", TechniqueTraining.rawPointsFor(0 / 0) == 0)
	check("infinity is 0", TechniqueTraining.rawPointsFor(math.huge) == 0)
	check("a day is 48.00 raw, linear", TechniqueTraining.rawPointsFor(DAY) == 48)

	local function shares(lift: string, primary: string): string
		local parts = {}
		for _, entry in ipairs(TechniqueTraining.split(lift, primary) or {}) do
			table.insert(parts, string.format("%s=%.2f", entry.stat, entry.share))
		end
		return table.concat(parts, ",")
	end

	check("Squat Control primary: 80/20 with Depth Awareness",
		shares("Squat", "SquatControl") == "SquatControl=0.80,DepthAwareness=0.20")
	check("Depth Awareness primary: 80/20 with Squat Control",
		shares("Squat", "DepthAwareness") == "DepthAwareness=0.80,SquatControl=0.20")
	check("Start Control primary: 80/20 with Press Power",
		shares("Bench", "StartControl") == "StartControl=0.80,PressPower=0.20")
	check("Press Power primary: 80/20 with Start Control",
		shares("Bench", "PressPower") == "PressPower=0.80,StartControl=0.20")
	check("Lockout: 100%", shares("Deadlift", "Lockout") == "Lockout=1.00")

	check("PullStrength is never a valid primary", not TechniqueTraining.isValidPrimary("Deadlift", "PullStrength"))
	check("a Bench stat is not a Squat primary", not TechniqueTraining.isValidPrimary("Squat", "PressPower"))
	check("an unknown lift has no split", TechniqueTraining.split("Curl", "SquatControl") == nil)
	check("a nil primary has no split", TechniqueTraining.split("Squat", nil) == nil)

	local exact = true
	for _, total in ipairs({ 0, 1e-12, 0.0055555, 1 / 3, 2, 48, 12345.6789, 1e12 }) do
		local gains = TechniqueTraining.allocate("Bench", "PressPower", total) :: any
		if gains == nil or gains[1].raw + gains[2].raw ~= total then
			exact = false
		end
	end
	check("primary + secondary always sum to the total EXACTLY", exact)
	check("allocate refuses a negative total", TechniqueTraining.allocate("Squat", "SquatControl", -1) == nil)
	check("allocate refuses NaN", TechniqueTraining.allocate("Squat", "SquatControl", 0 / 0) == nil)

	local rates = TechniqueTraining.ratesFor("Squat", "DepthAwareness") :: any
	check("display rates: 1.60/h Depth Awareness, 0.40/h Squat Control",
		rates[1].stat == "DepthAwareness" and near(rates[1].raw, 1.6, 1e-12)
			and rates[2].stat == "SquatControl" and near(rates[2].raw, 0.4, 1e-12))
end

--------------------------------------------------------------------------------
print("-- 3. the award: correct 80/20 and 100% distributions")
--------------------------------------------------------------------------------

do
	local cases = {
		{ lift = "Squat", primary = "SquatControl", secondary = "DepthAwareness" },
		{ lift = "Squat", primary = "DepthAwareness", secondary = "SquatControl" },
		{ lift = "Bench", primary = "StartControl", secondary = "PressPower" },
		{ lift = "Bench", primary = "PressPower", secondary = "StartControl" },
	}

	for _, case in ipairs(cases) do
		local data = newProfile()
		local result = apply(data, case.lift, case.primary, HOUR)
		check(string.format("%s primary: one hour gives +1.60 %s, +0.40 %s", case.primary, case.primary, case.secondary),
			result.outcome == "Awarded" and near(raw(data, case.primary), 1.6, 1e-12)
				and near(raw(data, case.secondary), 0.4, 1e-12) and near(result.totalRaw, 2, 1e-12))
	end

	local data = newProfile()
	local result = apply(data, "Deadlift", "Lockout", HOUR)
	check("Lockout: one hour gives +2.00 Lockout", result.outcome == "Awarded" and near(raw(data, "Lockout"), 2, 1e-12))
	check("and PullStrength never moves", raw(data, "PullStrength") == TEMPLATE.technique.PullStrength)
	check("the result reports the gains primary first",
		#result.gains == 1 and result.gains[1].stat == "Lockout" and result.after.Lockout == raw(data, "Lockout"))
end

--------------------------------------------------------------------------------
print("-- 4. fractional gains over short ticks")
--------------------------------------------------------------------------------

do
	local data = newProfile()
	for _ = 1, 360 do
		apply(data, "Squat", "DepthAwareness", 10)
	end
	check("360 ticks of 10 s equal one hour: 1.60 / 0.40",
		near(raw(data, "DepthAwareness"), 1.6, 1e-9) and near(raw(data, "SquatControl"), 0.4, 1e-9),
		string.format("%.12f / %.12f", raw(data, "DepthAwareness"), raw(data, "SquatControl")))

	local tiny = newProfile()
	apply(tiny, "Bench", "StartControl", 0.25)
	check("a quarter-second still earns a fractional amount",
		raw(tiny, "StartControl") > 0 and raw(tiny, "PressPower") > 0 and raw(tiny, "StartControl") < 0.001)

	local ticks = newProfile()
	for _ = 1, 10000 do
		apply(ticks, "Deadlift", "Lockout", 7.3)
	end
	check("10,000 odd-length ticks lose nothing to rounding",
		near(raw(ticks, "Lockout"), TechniqueTraining.rawPointsFor(73000), 1e-8))
end

--------------------------------------------------------------------------------
print("-- 5. UNLIMITED raw earning")
--------------------------------------------------------------------------------

do
	local data = newProfile()
	local refused = false
	for _ = 1, 100 do
		local result = apply(data, "Squat", "SquatControl", DAY)
		if result.outcome ~= "Awarded" then
			refused = true
		end
	end
	check("100 days of continuous training are all Awarded", not refused)
	check("Squat Control reached 3,840 raw (80% of 4,800): no cap anywhere",
		near(raw(data, "SquatControl"), 3840, 1e-6), string.format("%.6f", raw(data, "SquatControl")))
	check("Depth Awareness reached 960 raw", near(raw(data, "DepthAwareness"), 960, 1e-6))
	check("the legacy technique allowance was never spent", data.techniqueAllowance.spentToday == 0)
end

--------------------------------------------------------------------------------
print("-- 6. no RAW slowdown at high stat values")
--------------------------------------------------------------------------------

do
	local function gainAt(start: number): number
		local data = newProfile();
		(data.technique :: any).PressPower = start
		apply(data, "Bench", "PressPower", HOUR)
		return raw(data, "PressPower") - start
	end

	local low = gainAt(0)
	check("at raw 0 an hour adds 1.60", near(low, 1.6, 1e-12))
	check("at raw 100,000 an hour still adds 1.60", near(gainAt(100000), 1.6, 1e-9))
	check("at raw 10,000,000 an hour still adds 1.60", near(gainAt(10000000), 1.6, 1e-6))

	-- Diminishing returns live ONLY in the read-side curve.
	local lowEffectiveGain = TechniqueCurve.toEffective(1.6) - TechniqueCurve.toEffective(0)
	local highEffectiveGain = TechniqueCurve.toEffective(100001.6) - TechniqueCurve.toEffective(100000)
	check("the SAME raw gain is worth less EFFECTIVE technique at high values (read-side curve only)",
		lowEffectiveGain > highEffectiveGain and highEffectiveGain >= 0,
		string.format("%.6f vs %.9f", lowEffectiveGain, highEffectiveGain))
	check("effective technique still never exceeds the curve's ceiling",
		TechniqueCurve.toEffective(1e12) < TechniqueCurve.ceiling())
end

--------------------------------------------------------------------------------
print("-- 7. invalid requests write nothing")
--------------------------------------------------------------------------------

do
	local function refusedCleanly(label: string, lift: any, primary: any, seconds: any, reason: string)
		local data = newProfile()
		local before = deepCopy(data)
		local result = apply(data, lift, primary, seconds)
		check(label, result.outcome == "Rejected" and result.rejectionReason == reason and deepEqual(data, before),
			tostring(result.rejectionReason))
	end

	refusedCleanly("an unknown lift is InvalidLift", "Curl", "SquatControl", 10, "InvalidLift")
	refusedCleanly("PullStrength is InvalidPrimary", "Deadlift", "PullStrength", 10, "InvalidPrimary")
	refusedCleanly("a Bench stat on the Squat is InvalidPrimary", "Squat", "StartControl", 10, "InvalidPrimary")
	refusedCleanly("a missing primary is InvalidPrimary", "Squat", nil, 10, "InvalidPrimary")
	refusedCleanly("a numeric primary is InvalidPrimary", "Bench", 5, 10, "InvalidPrimary")
	refusedCleanly("NaN seconds are InvalidElapsed", "Squat", "SquatControl", 0 / 0, "InvalidElapsed")
	refusedCleanly("infinite seconds are InvalidElapsed", "Squat", "SquatControl", math.huge, "InvalidElapsed")
	refusedCleanly("more than a day is InvalidElapsed", "Squat", "SquatControl", DAY + 1, "InvalidElapsed")
	refusedCleanly("string seconds are InvalidElapsed", "Squat", "SquatControl", "3600", "InvalidElapsed")

	local zero = newProfile()
	local zeroBefore = deepCopy(zero)
	local zeroResult = apply(zero, "Squat", "SquatControl", 0)
	check("zero seconds is NoProgress and writes nothing",
		zeroResult.outcome == "NoProgress" and deepEqual(zero, zeroBefore))

	local negative = newProfile()
	local negativeBefore = deepCopy(negative)
	local negativeResult = apply(negative, "Squat", "SquatControl", -50)
	check("negative seconds is NoProgress and writes nothing",
		negativeResult.outcome == "NoProgress" and deepEqual(negative, negativeBefore))
end

--------------------------------------------------------------------------------
print("-- 8. corrupt technique data: refused, NO partial write, never repaired")
--------------------------------------------------------------------------------

do
	local function corruptCase(label: string, corrupt: (PlayerProfileSchema.ProfileData) -> ())
		local data = newProfile();
		(data.technique :: any).SquatControl = 12.5
		corrupt(data)
		local before = deepCopy(data)
		local result = apply(data, "Squat", "DepthAwareness", HOUR)
		check(label, result.outcome == "Rejected" and result.rejectionReason == "InvalidTechnique"
			and deepEqual(data, before), tostring(result.rejectionReason))
	end

	corruptCase("a NaN secondary refuses the WHOLE award (primary untouched too)", function(data)
		(data.technique :: any).SquatControl = 0 / 0
	end)
	corruptCase("a NaN primary is refused", function(data)
		(data.technique :: any).DepthAwareness = 0 / 0
	end)
	corruptCase("a negative stat is refused", function(data)
		(data.technique :: any).DepthAwareness = -1
	end)
	corruptCase("an infinite stat is refused", function(data)
		(data.technique :: any).SquatControl = math.huge
	end)
	corruptCase("a string stat is refused", function(data)
		(data.technique :: any).SquatControl = "12"
	end)
	corruptCase("a missing stat is refused", function(data)
		(data.technique :: any).DepthAwareness = nil
	end)
	corruptCase("a missing technique table is refused", function(data)
		(data :: any).technique = nil
	end)

	local unrelated = newProfile();
	(unrelated.technique :: any).PressPower = 0 / 0
	local result = apply(unrelated, "Squat", "SquatControl", HOUR)
	check("a corrupt stat the award does NOT touch does not block it, and stays as found",
		result.outcome == "Awarded" and raw(unrelated, "PressPower") ~= raw(unrelated, "PressPower"))

	local nearMax = newProfile();
	(nearMax.technique :: any).Lockout = 1.7e308
	local maxResult = apply(nearMax, "Deadlift", "Lockout", HOUR)
	check("a stat near the largest number stays finite (no overflow to infinity)",
		maxResult.outcome == "Awarded" and raw(nearMax, "Lockout") < math.huge)
end

--------------------------------------------------------------------------------
print("-- 9. nothing else in the profile moves")
--------------------------------------------------------------------------------

do
	local data = newProfile()
	data.cnAllowance.spentToday = 2.5
	data.cnAllowance.dayKey = "2025-10-09"
	data.trainingTimeToday.Squat = 1.25
	data.techniqueAllowance.spentToday = 4.8
	data.techniqueAllowance.dayKey = "2025-10-09"

	local before = withoutStats(data, { "SquatControl", "DepthAwareness" })
	apply(data, "Squat", "SquatControl", 1800)
	local after = withoutStats(data, { "SquatControl", "DepthAwareness" })

	check("CN, CN allowance, CN hours, Scale, legacy technique allowance, PullStrength, budgets: all unchanged",
		deepEqual(before, after))
	check("the legacy record keeps its old value exactly", data.techniqueAllowance.spentToday == 4.8)
end

--------------------------------------------------------------------------------
print("-- 10. eligibility and determinism")
--------------------------------------------------------------------------------

do
	local heavy = newProfile()
	heavy.bodyweight.currentKg = 130
	local result = apply(heavy, "Bench", "StartControl", HOUR)
	check("a 120+ lifter is Awarded technique (no Progression Reference needed)",
		result.outcome == "Awarded" and near(raw(heavy, "StartControl"), 1.6, 1e-12))

	local cn = ProfileOperations.applyTrainingProgression(newProfile(), "Bench", 1759968000, 0)
	local heavyCN = (function()
		local d = newProfile()
		d.bodyweight.currentKg = 130
		return ProfileOperations.applyTrainingProgression(d, "Bench", 1759968000, 0)
	end)()
	check("while CN still refuses the 120+ class (unchanged)", cn.outcome == "NoProgress" and heavyCN.outcome == "Rejected")

	local a = newProfile()
	local b = newProfile()
	apply(a, "Squat", "DepthAwareness", 600)
	apply(b, "Squat", "DepthAwareness", 600)
	check("the award takes no clock: identical inputs give identical results, any time of day", deepEqual(a, b))
end

print(string.format("=== %d passed, %d failed ===", passed, failed))

if failed > 0 then
	warn("[TechniqueTrainingProbe] FAILURES above.")
else
	print("[TechniqueTrainingProbe] set ENABLED back to false now that the run is finished.")
end
