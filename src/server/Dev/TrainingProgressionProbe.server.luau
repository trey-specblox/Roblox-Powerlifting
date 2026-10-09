--!strict
--[[
	TrainingProgressionProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Exercises the training progression award of
	checkpoint 5B.5 -- ProfileOperations.applyTrainingProgression, the pure core
	behind PlayerDataService.awardTrainingProgression -- on server start, and
	prints a pass/fail line per check to the Studio Output window.

	Set ENABLED to false to silence it, or delete this file. Nothing requires it,
	it creates no remotes, and it NEVER TOUCHES A REAL PLAYER'S PROFILE.

	WHY IT CANNOT TOUCH REAL DATA

	Every profile below is a deep copy of the schema template, held in a local
	variable and thrown away. The operation under test is pure: it takes a
	profile table, a lift, a server time and an elapsed interval, and has no
	Player, no ProfileStore and no DataStore. The gateway itself is only
	inspected (section 15), never called.

	THE TWO INVARIANTS EVERY SECTION RE-CHECKS

		cnAllowance.spentToday == EV(Squat h) + EV(Bench h) + EV(Deadlift h)
		CN gained on a lift    == sum of P x BaseProgressRate x earnedEV x Hill(PP)

	The first says every EV debited advanced a lift's clock. The second, checked
	against an independent copy of the formula, says every EV debited bought
	exactly the CN it should -- and no CN arrived from anywhere else.

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
local ProgressionReferenceConfig = require(ConfigFolder:WaitForChild("ProgressionReferenceConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local DayKey = require(ProgressionFolder:WaitForChild("DayKey"))
local TrainingEfficiency = require(ProgressionFolder:WaitForChild("TrainingEfficiency"))
local TrainingAllowance = require(ProgressionFolder:WaitForChild("TrainingAllowance"))

local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerProfileSchema = require(PlayerDataFolder:WaitForChild("PlayerProfileSchema"))
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))

local TRAINING = ProgressionConfig.DailyTraining

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
	Structural equality, with NaN equal to NaN. The corrupt-data sections plant
	NaN on purpose, and "nothing changed" must still hold for them.
]]
local function deepEqual(a: any, b: any): boolean
	if typeof(a) ~= typeof(b) then
		return false
	end

	if typeof(a) == "number" and a ~= a then
		return b ~= b
	end

	if typeof(a) ~= "table" then
		return a == b
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
	return deepCopy(PlayerProfileSchema.template)
end

--[[
	A UTC midnight, so every offset below is unambiguous. 1759968000 / 86400 is
	exactly 20370.
]]
local DAY_START = 1759968000
local HOUR = 3600
local DAY = 86400

local LIVE_RATE = 0.00482389
local STARTING_CLASS = "59 kg"

--[[
	AN INDEPENDENT COPY OF THE FORMULA. Deliberately not CompetitionNumberReward:
	the point is to check the engine against the design document's arithmetic,
	not against itself.
]]
local function expectedDelta(lift: string, classLabel: string, cnBefore: number, earnedEV: number): number
	local reference = ProgressionReferenceConfig.get(lift, classLabel) :: number
	local pp = cnBefore / reference
	local hill = 1 / (1 + (pp / 0.75) ^ 5)
	return reference * LIVE_RATE * earnedEV * hill
end

--[[
	A ledger of every update a scenario made, so the second invariant can be
	checked against the sum of what each update should have paid.
]]
type Ledger = {
	data: PlayerProfileSchema.ProfileData,
	startCN: { [string]: number },
	expectedGain: { [string]: number },
	classLabel: string,
}

local function newLedger(data: PlayerProfileSchema.ProfileData?): Ledger
	local profile = data or newProfile()
	local startCN = {}
	local expectedGain = {}

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		startCN[lift] = (profile.competitionNumber :: any)[lift]
		expectedGain[lift] = 0
	end

	return {
		data = profile,
		startCN = startCN,
		expectedGain = expectedGain,
		classLabel = STARTING_CLASS,
	}
end

local function train(ledger: Ledger, lift: string, nowUnix: number, elapsedSeconds: number): ProfileOperations.TrainingResult
	local before = (ledger.data.competitionNumber :: any)[lift]
	local result = ProfileOperations.applyTrainingProgression(ledger.data, lift, nowUnix, elapsedSeconds)

	if result.earnedEV > 0 then
		ledger.expectedGain[lift] += expectedDelta(lift, ledger.classLabel, before, result.earnedEV)
	end

	return result
end

local function checkInvariants(label: string, ledger: Ledger, nowUnix: number)
	local data = ledger.data
	local spent = TrainingAllowance.spentToday(data.cnAllowance, nowUnix)
	local implied = TrainingAllowance.impliedSpentEV(data.trainingTimeToday, nowUnix)

	check(
		string.format("INVARIANT %s: spent EV equals the sum of EV(hours)", label),
		near(spent, implied, 1e-9),
		string.format("spent %.10f, implied %.10f", spent, implied)
	)
	check(
		string.format("INVARIANT %s: spent EV within the 4.00 cap", label),
		spent <= TRAINING.DailyCapEV + 1e-9,
		string.format("%.10f", spent)
	)

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local gained = (data.competitionNumber :: any)[lift] - ledger.startCN[lift]

		check(
			string.format("INVARIANT %s: %s CN gained equals the formula's total", label, lift),
			near(gained, ledger.expectedGain[lift], 1e-9),
			string.format("gained %.10f, expected %.10f", gained, ledger.expectedGain[lift])
		)
	end
end

--[[
	Everything training must NEVER touch, snapshotted so a section can prove it
	stayed byte-for-byte identical.
]]
local function untouchable(data: PlayerProfileSchema.ProfileData): any
	return deepCopy({
		version = data.version,
		competitionScale = data.competitionScale,
		technique = data.technique,
		bodyweight = data.bodyweight,
		competitionBudget = data.competitionBudget,
		trainingEnergy = data.trainingEnergy,
		meta = data.meta,
		techniqueSpent = data.techniqueAllowance.spentToday,
	})
end

print("")
print("=== Training progression probe (checkpoint 5B.5) ===")

--------------------------------------------------------------------------------
print("")
print("1. the live configuration this probe assumes")
do
	check("BaseProgressRate is the live 0.00482389", ProgressionConfig.BaseProgressRate == LIVE_RATE,
		tostring(ProgressionConfig.BaseProgressRate))
	check("the proposed rate is NOT live", ProgressionConfig.BaseProgressRate ~= ProgressionConfig.ProposedBaseProgressRate)
	check("the daily cap is 4.00 EV", TRAINING.DailyCapEV == 4.00)
	check("a new lifter's 53 kg resolves to a supported class",
		ProgressionReferenceConfig.get("Squat", STARTING_CLASS) ~= nil)
	check("PullStrength is still in the template (not removed by 5B.5)",
		(PlayerProfileSchema.template.technique :: any).PullStrength ~= nil)
end

--------------------------------------------------------------------------------
print("")
print("2. valid progression on each lift")
do
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local ledger = newLedger()
		local data = ledger.data
		local now = DAY_START + 10 * HOUR
		local cnBefore = (data.competitionNumber :: any)[lift]

		local result = train(ledger, lift, now, HOUR)

		check(string.format("%s: one hour is Awarded", lift), result.outcome == "Awarded", result.outcome)
		check(string.format("%s: earns exactly 1.00 EV", lift), near(result.earnedEV, 1.0, 1e-12),
			string.format("%.12f", result.earnedEV))
		check(string.format("%s: CN delta matches the formula at the live rate", lift),
			near(result.deltaCN, expectedDelta(lift, STARTING_CLASS, cnBefore, 1.0), 1e-12),
			string.format("%.12f", result.deltaCN))
		check(string.format("%s: CN delta is positive and fractional", lift),
			result.deltaCN > 0 and result.deltaCN ~= math.floor(result.deltaCN))
		check(string.format("%s: the stored CN moved by exactly that delta", lift),
			(data.competitionNumber :: any)[lift] == cnBefore + result.deltaCN)
		check(string.format("%s: the result reports the starting class", lift), result.weightClassLabel == STARTING_CLASS)
		check(string.format("%s: the allowance is debited 1.00", lift), near(data.cnAllowance.spentToday, 1.0, 1e-12))
		check(string.format("%s: this lift banked one hour", lift),
			near((data.trainingTimeToday :: any)[lift], 1.0, 1e-12))
		check(string.format("%s: the day key is stamped today", lift),
			data.cnAllowance.dayKey == DayKey.fromUnix(now) and data.trainingTimeToday.dayKey == DayKey.fromUnix(now))
		check(string.format("%s: the audit stamp is the server time", lift), data.cnAllowance.lastUpdatedUnix == now)

		for _, other in ipairs(ProgressionConfig.Lifts) do
			if other ~= lift then
				check(string.format("%s: %s CN untouched", lift, other),
					(data.competitionNumber :: any)[other] == ledger.startCN[other])
				check(string.format("%s: %s hours untouched", lift, other),
					(data.trainingTimeToday :: any)[other] == 0)
			end
		end

		checkInvariants(lift .. " one hour", ledger, now)
	end

	-- Fractional awards survive: a 90-second tick is 0.025 EV, not rounded away.
	local ledger = newLedger()
	local now = DAY_START + 10 * HOUR
	local result = train(ledger, "Squat", now, 90)

	check("a 90-second tick earns exactly 0.025 EV", near(result.earnedEV, 0.025, 1e-12),
		string.format("%.12f", result.earnedEV))
	check("and banks exactly 0.025 hours", near(ledger.data.trainingTimeToday.Squat, 0.025, 1e-12))
	check("and the CN award is small but non-zero", result.deltaCN > 0 and result.deltaCN < 0.1,
		string.format("%.12f", result.deltaCN))
	checkInvariants("fractional tick", ledger, now)
end

--------------------------------------------------------------------------------
print("")
print("3. the 4.00 EV cap is shared by the whole account")
do
	local ledger = newLedger()
	local data = ledger.data
	local now = DAY_START + 8 * HOUR

	local squat = train(ledger, "Squat", now, 2 * HOUR)
	now += 2 * HOUR
	local bench = train(ledger, "Bench", now, 2 * HOUR)

	check("Squat 2 h earns 2.00", near(squat.earnedEV, 2.0, 1e-12))
	check("Bench 2 h earns 2.00", near(bench.earnedEV, 2.0, 1e-12))
	check("the account has spent exactly 4.00", near(data.cnAllowance.spentToday, 4.0, 1e-12))

	now += HOUR
	local deadliftCN = data.competitionNumber.Deadlift
	local deadlift = train(ledger, "Deadlift", now, HOUR)

	check("Deadlift, never trained today, earns NOTHING", deadlift.earnedEV == 0)
	check("its outcome is NoProgress", deadlift.outcome == "NoProgress", deadlift.outcome)
	check("it reports the cap", deadlift.capReached)
	check("its CN is exactly unchanged", data.competitionNumber.Deadlift == deadliftCN)
	check("and it reports zero delta", deadlift.deltaCN == 0)
	check("Deadlift banks no hours, so its full-rate window is intact", data.trainingTimeToday.Deadlift == 0)
	check("every second went uncredited", near(deadlift.uncreditedSeconds, HOUR, 1e-6))

	now += HOUR
	local again = train(ledger, "Squat", now, HOUR)
	check("returning to Squat earns nothing either", again.earnedEV == 0 and again.outcome == "NoProgress")

	checkInvariants("at the shared cap", ledger, now)

	-- One lift alone reaches the cap at t* = 2 + 2(e - 1), and the last tick is cut short.
	local solo = newLedger()
	local t = DAY_START + 6 * HOUR

	train(solo, "Squat", t, 5 * HOUR)
	t += 5 * HOUR
	local spentAfterFive = solo.data.cnAllowance.spentToday
	local last = train(solo, "Squat", t, HOUR)

	check("five hours on one lift leaves part of the cap", spentAfterFive < 4.0,
		string.format("%.10f", spentAfterFive))
	check("the next hour earns only what remained", near(last.earnedEV, 4.0 - spentAfterFive, 1e-9),
		string.format("%.10f", last.earnedEV))
	check("and reports the cap", last.capReached)
	check("the account lands exactly on 4.00", near(solo.data.cnAllowance.spentToday, 4.0, 1e-9))
	check("Squat's clock stops at t* = 5.4366 h, not 6",
		near(solo.data.trainingTimeToday.Squat, 2 + 2 * (math.exp(1) - 1), 1e-6),
		string.format("%.6f", solo.data.trainingTimeToday.Squat))
	checkInvariants("one lift to the cap", solo, t)
end

--------------------------------------------------------------------------------
print("")
print("4. switching lifts and resuming a previous lift")
do
	local ledger = newLedger()
	local data = ledger.data
	local now = DAY_START + 7 * HOUR

	train(ledger, "Squat", now, HOUR)
	now += HOUR
	train(ledger, "Bench", now, HOUR)
	now += HOUR

	check("switching to Bench kept Squat's hour", near(data.trainingTimeToday.Squat, 1.0, 1e-12))

	local resumed = train(ledger, "Squat", now, 1.5 * HOUR)

	check("Squat resumes at t = 1.00, not 0", near(data.trainingTimeToday.Squat, 2.5, 1e-9))
	check("so it earns EV(2.5) - EV(1), past its full-rate window",
		near(resumed.earnedEV, TrainingEfficiency.cumulativeEV(2.5) - 1.0, 1e-9),
		string.format("%.10f", resumed.earnedEV))
	check("which is less than 1.5 hours at full rate", resumed.earnedEV < 1.5)
	check("Bench's banked hour is preserved", near(data.trainingTimeToday.Bench, 1.0, 1e-12))
	check("the technique allowance was not spent", data.techniqueAllowance.spentToday == 0)

	checkInvariants("after switching", ledger, now)
end

--------------------------------------------------------------------------------
print("")
print("5. repeated updates never overwrite each other")
do
	local ledger = newLedger()
	local data = ledger.data
	local now = DAY_START + 12 * HOUR

	-- Three updates in the SAME server second, on three lifts.
	train(ledger, "Squat", now, 600)
	train(ledger, "Bench", now, 600)
	train(ledger, "Deadlift", now, 600)

	local tenMinutes = 600 / HOUR

	check("Squat's ten minutes survived the Bench and Deadlift updates",
		near(data.trainingTimeToday.Squat, tenMinutes, 1e-12))
	check("Bench's survived the Deadlift update", near(data.trainingTimeToday.Bench, tenMinutes, 1e-12))
	check("Deadlift's landed", near(data.trainingTimeToday.Deadlift, tenMinutes, 1e-12))
	check("the account spend is all three together", near(data.cnAllowance.spentToday, 3 * tenMinutes, 1e-12))

	-- Sixty one-minute updates on one lift equal one sixty-minute update.
	local ticked = newLedger()
	local t = DAY_START + 12 * HOUR

	for _ = 1, 60 do
		t += 60
		train(ticked, "Bench", t, 60)
	end

	check("sixty 1-minute ticks bank exactly one hour", near(ticked.data.trainingTimeToday.Bench, 1.0, 1e-9))
	check("and spend exactly 1.00 EV", near(ticked.data.cnAllowance.spentToday, 1.0, 1e-9))
	checkInvariants("after 60 ticks", ticked, t)

	--[[
		A plan computed BEFORE another update is stale afterwards. This is the
		hole the in-operation basis check guards: the operation plans and
		commits with no gap, so it can never apply a plan like this one.
	]]
	local state = {
		cnAllowance = data.cnAllowance,
		techniqueAllowance = data.techniqueAllowance,
		trainingTimeToday = data.trainingTimeToday,
	}
	local earlyPlan = TrainingAllowance.planTraining(deepCopy(state), "Squat", now + 60, 60)

	train(ledger, "Bench", now + 60, 60)

	check("an outside plan made before the Bench update is now stale",
		TrainingAllowance.matchesBasis(state, earlyPlan) == false)
	check("and applying it would have reverted Bench",
		earlyPlan.nextState.trainingTimeToday.Bench < data.trainingTimeToday.Bench)

	checkInvariants("after repeated updates", ledger, now + 60)
end

--------------------------------------------------------------------------------
print("")
print("6. UTC midnight is split between the two days")
do
	local ledger = newLedger()
	local data = ledger.data
	local today = DAY_START
	local now = today + 14 * HOUR

	-- Spend 3.90 of today's cap: 2 h of Squat (2.00) and 1.9 h of Bench (1.90).
	train(ledger, "Squat", now, 2 * HOUR)
	now += 2 * HOUR
	train(ledger, "Bench", now, 1.9 * HOUR)

	check("3.90 of today's cap is spent", near(data.cnAllowance.spentToday, 3.9, 1e-9))

	-- One hour from 23:30 to 00:30 on Squat.
	local endUnix = today + DAY + 30 * 60
	local result = train(ledger, "Squat", endUnix, HOUR)

	check("the interval touched two days", result.daysTouched == 2, tostring(result.daysTouched))
	check("it earned 0.10 before midnight and 0.50 after", near(result.earnedEV, 0.6, 1e-9),
		string.format("%.10f", result.earnedEV))
	check("the cap bound the pre-midnight half", result.capReached)
	check("the day key moved to the new day", data.cnAllowance.dayKey == DayKey.fromUnix(endUnix))
	check("today's spend is only the post-midnight 0.50", near(data.cnAllowance.spentToday, 0.5, 1e-9))
	check("Squat's clock restarted at midnight: 0.50 h", near(data.trainingTimeToday.Squat, 0.5, 1e-9))
	check("Bench's hours rolled to zero", data.trainingTimeToday.Bench == 0)
	check("the technique day key rolled too", data.techniqueAllowance.dayKey == DayKey.fromUnix(endUnix))
	check("and the CN award paid for all 0.60 EV", near(result.deltaCN,
		expectedDelta("Squat", STARTING_CLASS, result.competitionNumberBefore :: number, 0.6), 1e-12))

	checkInvariants("after midnight", ledger, endUnix)
end

--------------------------------------------------------------------------------
print("")
print("7. no progression from offline time")
do
	local ledger = newLedger()
	local data = ledger.data
	local now = DAY_START + 9 * HOUR

	train(ledger, "Squat", now, 2 * HOUR)

	-- The player leaves, and returns three days later. Their stamp is three days old.
	local later = now + 3 * DAY
	local cnBefore = data.competitionNumber.Squat

	local zero = train(ledger, "Squat", later, 0)

	check("a zero-length update after three days earns NOTHING", zero.earnedEV == 0 and zero.outcome == "NoProgress")
	check("CN is exactly unchanged", data.competitionNumber.Squat == cnBefore)
	check("the allowance rolled over to the new day", data.cnAllowance.dayKey == DayKey.fromUnix(later)
		and data.cnAllowance.spentToday == 0)
	check("Squat's hours reset with it", data.trainingTimeToday.Squat == 0)

	local minute = train(ledger, "Squat", later + 60, 60)

	check("the next minute earns ONE MINUTE, not three days", near(minute.earnedEV, 60 / HOUR, 1e-12),
		string.format("%.10f", minute.earnedEV))

	-- An ancient audit stamp changes nothing: elapsed time is the caller's observation only.
	local ancient = newLedger()
	ancient.data.cnAllowance.lastUpdatedUnix = 1
	ancient.data.trainingTimeToday.lastUpdatedUnix = 1
	local fromAncient = train(ancient, "Bench", DAY_START + HOUR, 60)

	check("a 1970 lastUpdatedUnix still credits only the 60 observed seconds",
		near(fromAncient.earnedEV, 60 / HOUR, 1e-12))
	check("there is no way to pass a past timestamp as elapsed time beyond one day",
		train(newLedger(), "Bench", DAY_START + 10 * DAY, 10 * DAY).outcome == "Rejected")

	checkInvariants("after the offline gap", ledger, later + 60)
end

--------------------------------------------------------------------------------
print("")
print("8. zero EV never awards CN")
do
	local ledger = newLedger()
	local data = ledger.data
	local now = DAY_START + 10 * HOUR
	local cnBefore = data.competitionNumber.Bench

	local zero = train(ledger, "Bench", now, 0)
	check("zero elapsed seconds: NoProgress", zero.outcome == "NoProgress")
	check("zero elapsed seconds: no CN", data.competitionNumber.Bench == cnBefore and zero.deltaCN == 0)
	check("zero elapsed seconds: no hill reported, nothing was paid", zero.hillMultiplier == nil)

	local negative = train(ledger, "Bench", now, -300)
	check("negative elapsed seconds earn nothing", negative.outcome == "NoProgress" and negative.earnedEV == 0)
	check("negative elapsed seconds: no CN", data.competitionNumber.Bench == cnBefore)
	check("negative elapsed seconds bank no hours", data.trainingTimeToday.Bench == 0)

	checkInvariants("after zero-EV updates", ledger, now)
end

--------------------------------------------------------------------------------
print("")
print("9. invalid lift, time and elapsed time are rejected with nothing written")
do
	local now = DAY_START + 10 * HOUR

	local function expectRejected(label: string, lift: any, nowUnix: any, elapsed: any, reason: string)
		local data = newProfile()
		train(newLedger(data), "Squat", now - HOUR, 600) -- a non-trivial starting state
		local before = deepCopy(data)

		local result = ProfileOperations.applyTrainingProgression(data, lift, nowUnix, elapsed)

		check(string.format("%s: Rejected", label), result.outcome == "Rejected", result.outcome)
		check(string.format("%s: reason %s", label, reason), result.rejectionReason == reason,
			tostring(result.rejectionReason))
		check(string.format("%s: profile byte-for-byte unchanged", label), deepEqual(data, before))
		check(string.format("%s: reports no EV and no CN", label), result.earnedEV == 0 and result.deltaCN == 0)
	end

	expectRejected("lowercase lift", "squat", now, 60, "InvalidLift")
	expectRejected("a technique stat as a lift", "PullStrength", now, 60, "InvalidLift")
	expectRejected("nil lift", nil, now, 60, "InvalidLift")
	expectRejected("numeric lift", 1, now, 60, "InvalidLift")

	expectRejected("NaN server time", "Squat", 0 / 0, 60, "InvalidTime")
	expectRejected("negative server time", "Squat", -1, 60, "InvalidTime")
	expectRejected("infinite server time", "Squat", math.huge, 60, "InvalidTime")

	expectRejected("NaN elapsed", "Squat", now, 0 / 0, "InvalidElapsed")
	expectRejected("infinite elapsed", "Squat", now, math.huge, "InvalidElapsed")
	expectRejected("negative infinite elapsed", "Squat", now, -math.huge, "InvalidElapsed")
	expectRejected("string elapsed", "Squat", now, "60", "InvalidElapsed")
	expectRejected("nil elapsed", "Squat", now, nil, "InvalidElapsed")
	expectRejected("elapsed over one day", "Squat", now, DAY + 1, "InvalidElapsed")

	-- Exactly one day is the bound, and is accepted.
	local data = newProfile()
	local exact = ProfileOperations.applyTrainingProgression(data, "Squat", DAY_START + 2 * DAY, DAY)
	check("exactly one day of elapsed time is accepted", exact.outcome == "Awarded", exact.outcome)
end

--------------------------------------------------------------------------------
print("")
print("10. a class with no configured references rejects the WHOLE update")
do
	local now = DAY_START + 10 * HOUR

	local function expectClassRejected(label: string, bodyweightKg: any, reason: string, prepare: ((any) -> ())?)
		local data = newProfile()
		data.bodyweight.currentKg = bodyweightKg

		if prepare then
			prepare(data)
		end

		local before = deepCopy(data)
		local result = ProfileOperations.applyTrainingProgression(data, "Deadlift", now, HOUR)

		check(string.format("%s: Rejected (%s)", label, reason),
			result.outcome == "Rejected" and result.rejectionReason == reason,
			string.format("%s / %s", result.outcome, tostring(result.rejectionReason)))
		check(string.format("%s: no CN and no allowance spent", label), deepEqual(data, before))
	end

	expectClassRejected("130 kg (120+ class)", 130, "UnsupportedClass")
	expectClassRejected("120.1 kg (120+ class)", 120.1, "UnsupportedClass")

	-- Rejected even when nothing would have been earned, so even a pending rollover is not written.
	expectClassRejected("120+ with the cap already spent yesterday", 150, "UnsupportedClass", function(data)
		data.cnAllowance = { spentToday = 4.0, dayKey = DayKey.fromUnix(now - DAY), lastUpdatedUnix = now - DAY }
	end)

	expectClassRejected("NaN bodyweight", 0 / 0, "InvalidBodyweight")
	expectClassRejected("zero bodyweight", 0, "InvalidBodyweight")
	expectClassRejected("negative bodyweight", -70, "InvalidBodyweight")
	expectClassRejected("infinite bodyweight", math.huge, "InvalidBodyweight")
	expectClassRejected("string bodyweight", "83", "InvalidBodyweight")

	-- The boundary: 120.0 kg is the capped 120 kg class and trains normally.
	local data = newProfile()
	data.bodyweight.currentKg = 120
	local boundary = ProfileOperations.applyTrainingProgression(data, "Deadlift", now, HOUR)
	check("120.0 kg is the 120 kg class and is Awarded", boundary.outcome == "Awarded"
		and boundary.weightClassLabel == "120 kg", tostring(boundary.weightClassLabel))
	check("scored against the 120 kg reference", near(boundary.deltaCN,
		expectedDelta("Deadlift", "120 kg", 25, 1.0), 1e-12))
end

--------------------------------------------------------------------------------
print("")
print("11. corrupt Competition Number or accounting data is rejected with nothing written")
do
	local now = DAY_START + 10 * HOUR

	local function expectCorrupt(label: string, reason: string, corrupt: (any) -> ())
		local data = newProfile() :: any
		corrupt(data)

		local before = deepCopy(data)
		local result = ProfileOperations.applyTrainingProgression(data, "Squat", now, HOUR)

		check(string.format("%s: Rejected (%s)", label, reason),
			result.outcome == "Rejected" and result.rejectionReason == reason,
			string.format("%s / %s", result.outcome, tostring(result.rejectionReason)))
		check(string.format("%s: profile unchanged", label), deepEqual(data, before))
	end

	expectCorrupt("NaN Squat CN", "InvalidCompetitionNumber", function(d) d.competitionNumber.Squat = 0 / 0 end)
	expectCorrupt("zero Squat CN", "InvalidCompetitionNumber", function(d) d.competitionNumber.Squat = 0 end)
	expectCorrupt("negative Squat CN", "InvalidCompetitionNumber", function(d) d.competitionNumber.Squat = -5 end)
	expectCorrupt("string Squat CN", "InvalidCompetitionNumber", function(d) d.competitionNumber.Squat = "25" end)

	expectCorrupt("NaN CN spend", "InvalidAccounting", function(d) d.cnAllowance.spentToday = 0 / 0 end)
	expectCorrupt("negative CN spend", "InvalidAccounting", function(d) d.cnAllowance.spentToday = -1 end)
	expectCorrupt("numeric CN day key", "InvalidAccounting", function(d) d.cnAllowance.dayKey = 20370 end)
	expectCorrupt("NaN CN audit stamp", "InvalidAccounting", function(d) d.cnAllowance.lastUpdatedUnix = 0 / 0 end)
	expectCorrupt("missing CN allowance", "InvalidAccounting", function(d) d.cnAllowance = nil end)
	expectCorrupt("string technique allowance", "InvalidAccounting", function(d) d.techniqueAllowance = "x" end)
	expectCorrupt("infinite technique spend", "InvalidAccounting", function(d)
		d.techniqueAllowance.spentToday = math.huge
	end)
	expectCorrupt("NaN Bench hours", "InvalidAccounting", function(d) d.trainingTimeToday.Bench = 0 / 0 end)
	expectCorrupt("missing Deadlift hours", "InvalidAccounting", function(d) d.trainingTimeToday.Deadlift = nil end)
	expectCorrupt("missing hours record", "InvalidAccounting", function(d) d.trainingTimeToday = nil end)

	-- A corrupt OTHER lift's CN does not block training this one.
	local data = newProfile() :: any
	data.competitionNumber.Bench = 0 / 0
	local squat = ProfileOperations.applyTrainingProgression(data, "Squat", now, HOUR)
	check("a corrupt Bench CN does not block Squat training", squat.outcome == "Awarded")
	check("and is left exactly as found, not repaired", data.competitionNumber.Bench ~= data.competitionNumber.Bench)
end

--------------------------------------------------------------------------------
print("")
print("12. a backward clock writes nothing")
do
	local ledger = newLedger()
	local data = ledger.data
	local now = DAY_START + 10 * HOUR

	train(ledger, "Squat", now, HOUR)

	-- The server clock jumps back a day.
	local before = deepCopy(data)
	local result = ProfileOperations.applyTrainingProgression(data, "Squat", now - DAY, 600)

	check("the outcome is ClockWentBackward", result.outcome == "ClockWentBackward", result.outcome)
	check("it is not a rejection reason", result.rejectionReason == nil)
	check("it earned nothing", result.earnedEV == 0 and result.deltaCN == 0)
	check("the profile is byte-for-byte unchanged", deepEqual(data, before))
	check("CN before and after are reported equal",
		result.competitionNumberBefore == result.competitionNumberAfter)

	checkInvariants("after the backward clock", ledger, now)
end

--------------------------------------------------------------------------------
print("")
print("13. the Competition Budget is neither spent nor consulted")
do
	local ledger = newLedger()
	local data = ledger.data
	local now = DAY_START + 6 * HOUR
	local budgetBefore = deepCopy(data.competitionBudget)
	local energyBefore = deepCopy(data.trainingEnergy)

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		train(ledger, lift, now, 1.5 * HOUR)
		now += 1.5 * HOUR
	end

	check("a full day of training leaves every budget pool unchanged", deepEqual(data.competitionBudget, budgetBefore))
	check("and Training Energy unchanged", deepEqual(data.trainingEnergy, energyBefore))

	-- A pool deep in overflow does not scale the award: training never reads it.
	local fresh = newProfile()
	local overflowed = newProfile() :: any
	overflowed.competitionBudget.Squat.amount = -50

	local freshResult = ProfileOperations.applyTrainingProgression(fresh, "Squat", DAY_START + HOUR, HOUR)
	local overflowResult = ProfileOperations.applyTrainingProgression(overflowed, "Squat", DAY_START + HOUR, HOUR)

	check("an overflowed Squat budget pays the identical CN", freshResult.deltaCN == overflowResult.deltaCN,
		string.format("%.12f vs %.12f", freshResult.deltaCN, overflowResult.deltaCN))
	check("and the overflowed pool is left at -50", overflowed.competitionBudget.Squat.amount == -50)

	checkInvariants("after a budget-free day", ledger, now)
end

--------------------------------------------------------------------------------
print("")
print("14. technique, Scale and unrelated data are never changed")
do
	local data = newProfile() :: any

	-- Non-default values everywhere, so an accidental reset would show.
	data.technique.SquatControl = 123.5
	data.technique.PullStrength = 77
	data.technique.Lockout = 9.25
	data.competitionScale.Squat = 140
	data.bodyweight.currentKg = 82.4
	data.meta.sessionCount = 17

	local ledger = newLedger(data)
	ledger.classLabel = "83 kg"

	local guarded = untouchable(data)
	local now = DAY_START + 9 * HOUR

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		train(ledger, lift, now, 1.5 * HOUR)
		now += 1.5 * HOUR
	end

	-- Two days later, with a rollover in between.
	local later = train(ledger, "Squat", now + 2 * DAY, 600)

	check("technique, Scale, bodyweight, budget, energy, meta and version are identical",
		deepEqual(untouchable(data), guarded))
	check("PullStrength survives at 77", data.technique.PullStrength == 77)
	check("Competition Scale is still 140, not raised by training", data.competitionScale.Squat == 140)
	check("the technique allowance was never spent", data.techniqueAllowance.spentToday == 0)
	check("an 82.4 kg lifter is scored in the 83 kg class", later.weightClassLabel == "83 kg",
		tostring(later.weightClassLabel))

	checkInvariants("after guarded training", ledger, now + 2 * DAY)
end

--------------------------------------------------------------------------------
print("")
print("15. the gateway surface")
do
	local Service = require(PlayerDataFolder:WaitForChild("PlayerDataService")) :: any

	check("PlayerDataService exposes awardTrainingProgression", typeof(Service.awardTrainingProgression) == "function")
	check("there is no EV-taking awardProgression", Service.awardProgression == nil)
	check("there is still no kilogram CN writer",
		Service.addCompetitionNumber == nil and Service.applyCompetitionNumberDelta == nil)
	check("there is still no Competition Scale writer",
		Service.raiseCompetitionScale == nil and Service.setCompetitionScale == nil)
	check("and the operation it wraps is on ProfileOperations",
		typeof((ProfileOperations :: any).applyTrainingProgression) == "function")
end

--------------------------------------------------------------------------------
print("")
print(string.format("=== %d passed, %d failed ===", passed, failed))

if failed > 0 then
	warn("[TrainingProgressionProbe] THE TRAINING AWARD HAS FAILING CHECKS. Do not build 5B.6 on it yet.")
else
	print("[TrainingProgressionProbe] set ENABLED back to false now that the run is finished.")
end
