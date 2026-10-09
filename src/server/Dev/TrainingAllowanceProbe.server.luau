--!strict
--[[
	TrainingAllowanceProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Exercises the daily training allowance reader of
	GAME_DESIGN.md section 34.12 on server start and prints a pass/fail line per
	check to the Studio Output window.

	Set ENABLED to false to silence it, or delete this file. Nothing requires it,
	it touches no player's data, it writes nothing, and it creates no remotes.

	WHY THIS NEEDS NO DATASTORE AND NO PLAYER

	TrainingAllowance is pure. It takes the three accounting records, a lift, a
	server time and an elapsed interval, and returns a PROPOSED replacement
	without writing anything. So a whole day of training, a midnight crossing and
	a reconnect are all just arithmetic with synthetic timestamps.

	`applyPlan` below is the honest stand-in for what checkpoint 5B.5 will do:
	take plan.nextState and write it into the profile. Because a plan carries an
	absolute next state rather than a delta, that really is the whole of it.

	THE INVARIANT EVERY SECTION RE-CHECKS

		cnAllowance.spentToday == EV(Squat hours) + EV(Bench hours) + EV(Deadlift hours)

	within a day, exactly. It is the one property that makes "the cap is
	account-wide" and "efficiency is per lift" co-exist, so it is asserted after
	every scenario rather than once at the end.

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
local DayKey = require(ProgressionFolder:WaitForChild("DayKey"))
local TrainingEfficiency = require(ProgressionFolder:WaitForChild("TrainingEfficiency"))
local TrainingAllowance = require(ProgressionFolder:WaitForChild("TrainingAllowance"))

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

--[[
	A UTC midnight, so every offset below is unambiguous. Asserted rather than
	assumed: 1759968000 / 86400 is exactly 20370.
]]
local DAY_START = 1759968000
local HOUR = 3600
local DAY = 86400

local function unstampedState(): TrainingAllowance.State
	return {
		cnAllowance = { spentToday = 0, dayKey = DayKey.UNSTAMPED, lastUpdatedUnix = 0 },
		techniqueAllowance = { spentToday = 0, dayKey = DayKey.UNSTAMPED, lastUpdatedUnix = 0 },
		trainingTimeToday = {
			Squat = 0,
			Bench = 0,
			Deadlift = 0,
			dayKey = DayKey.UNSTAMPED,
			lastUpdatedUnix = 0,
		},
	}
end

--[[
	What 5B.5 will do: replace the three records with the proposed ones, inside a
	single PlayerDataService.update mutator.
]]
local function applyPlan(plan: TrainingAllowance.Plan): TrainingAllowance.State
	return plan.nextState
end

--[[
	An independent copy, so a test can break one field without disturbing the
	original. Used by the basis regression in section 17.
]]
local function cloneState(state: TrainingAllowance.State): TrainingAllowance.State
	return {
		cnAllowance = {
			spentToday = state.cnAllowance.spentToday,
			dayKey = state.cnAllowance.dayKey,
			lastUpdatedUnix = state.cnAllowance.lastUpdatedUnix,
		},
		techniqueAllowance = {
			spentToday = state.techniqueAllowance.spentToday,
			dayKey = state.techniqueAllowance.dayKey,
			lastUpdatedUnix = state.techniqueAllowance.lastUpdatedUnix,
		},
		trainingTimeToday = {
			Squat = state.trainingTimeToday.Squat,
			Bench = state.trainingTimeToday.Bench,
			Deadlift = state.trainingTimeToday.Deadlift,
			dayKey = state.trainingTimeToday.dayKey,
			lastUpdatedUnix = state.trainingTimeToday.lastUpdatedUnix,
		},
	}
end

--[[
	The central invariant. Checked after every scenario.
]]
local function checkInvariant(label: string, state: TrainingAllowance.State, nowUnix: number)
	local spent = TrainingAllowance.spentToday(state.cnAllowance, nowUnix)
	local implied = TrainingAllowance.impliedSpentEV(state.trainingTimeToday, nowUnix)

	check(
		string.format("INVARIANT %s: spent EV equals the sum of EV(hours)", label),
		near(spent, implied, 1e-9),
		string.format("spent %.10f vs implied %.10f", spent, implied)
	)
end

print("=== Training allowance probe (section 34.12) ===")
print(string.format(
	"  DailyCapEV %.2f  |  DailyCapTechniqueRaw %.2f  |  BaseRate %.2f  |  F %.2f  |  K %.2f",
	TRAINING.DailyCapEV,
	TRAINING.DailyCapTechniqueRaw,
	TRAINING.BaseRate,
	TRAINING.FullRateHours,
	TRAINING.K
))
print(string.format("  day D starts at %d, key %q", DAY_START, DayKey.fromUnix(DAY_START)))
print(string.format("  day D+1 key %q", DayKey.fromUnix(DAY_START + DAY)))
print("")

--------------------------------------------------------------------------------
print("1. the test clock really is a UTC midnight")
do
	check("DAY_START divides exactly into days", DAY_START % DAY == 0, tostring(DAY_START % DAY))
	check("startOfDayUnix(DAY_START) is itself", DayKey.startOfDayUnix(DAY_START) == DAY_START)
	check("DAY_START + 86399 is still day D",
		DayKey.fromUnix(DAY_START + DAY - 1) == DayKey.fromUnix(DAY_START))
	check("DAY_START + 86400 is day D+1",
		DayKey.fromUnix(DAY_START + DAY) ~= DayKey.fromUnix(DAY_START))
end

--------------------------------------------------------------------------------
print("2. UNSTAMPED counters read as a full, unspent allowance")
do
	local state = unstampedState()
	local now = DAY_START + 12 * HOUR

	check("the CN record reads stale against today", TrainingAllowance.isStale(state.cnAllowance, now))
	check("the technique record reads stale", TrainingAllowance.isStale(state.techniqueAllowance, now))
	check("the hours record reads stale", TrainingAllowance.isStale(state.trainingTimeToday, now))

	check("spent today is 0", TrainingAllowance.spentToday(state.cnAllowance, now) == 0)
	check("the full 4.00 EV remains", near(TrainingAllowance.remainingCN(state.cnAllowance, now), 4.00),
		tostring(TrainingAllowance.remainingCN(state.cnAllowance, now)))
	check("the full 6.00 technique points remain",
		near(TrainingAllowance.remainingTechnique(state.techniqueAllowance, now), 6.00))

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		check(string.format("%s has 0 banked hours", lift),
			TrainingAllowance.hoursOnLift(state.trainingTimeToday, lift, now) == 0)
	end

	--[[
		AN UNSTAMPED RECORD IS NOT A GRANT. Reading it reports a full allowance
		because none has been spent today, which is the same answer any other
		untouched day would give.
	]]
	checkInvariant("unstamped", state, now)
end

--------------------------------------------------------------------------------
print("3. normal same-day training, in fractional steps")
do
	local state = unstampedState()
	local now = DAY_START + 12 * HOUR

	-- Thirty minutes of Squat at full rate.
	local plan = TrainingAllowance.planTraining(state, "Squat", now, 1800)

	check("30 min at full rate earns 0.50 EV", near(plan.earnedEV, 0.50), string.format("%.8f", plan.earnedEV))
	check("0.50 hours are credited", near(plan.creditedHours, 0.50), string.format("%.8f", plan.creditedHours))
	check("nothing is uncredited", near(plan.uncreditedSeconds, 0))
	check("the cap was not reached", plan.capReached == false)
	check("one day was touched", plan.daysTouched == 1)
	check("the plan reports a change", plan.changed == true)

	state = applyPlan(plan)

	check("spent is now 0.50 EV", near(state.cnAllowance.spentToday, 0.50))
	check("Squat holds 0.50 hours", near(state.trainingTimeToday.Squat, 0.50))
	check("the day key is now stamped to today", state.cnAllowance.dayKey == DayKey.fromUnix(now))
	check("the timestamp is the server time given", state.cnAllowance.lastUpdatedUnix == now)
	check("Bench and Deadlift are untouched",
		state.trainingTimeToday.Bench == 0 and state.trainingTimeToday.Deadlift == 0)
	checkInvariant("after 30 min", state, now)

	-- Another thirty minutes, still inside the full-rate window.
	local second = TrainingAllowance.planTraining(state, "Squat", now + 1800, 1800)

	check("the second 30 min also earns 0.50 EV", near(second.earnedEV, 0.50),
		string.format("%.8f", second.earnedEV))

	state = applyPlan(second)

	check("spent is now 1.00 EV", near(state.cnAllowance.spentToday, 1.00))
	check("Squat holds 1.00 hour", near(state.trainingTimeToday.Squat, 1.00))
	checkInvariant("after 1 hour", state, now + 1800)

	-- A ten-second tick: fractions must survive, not round away.
	local tiny = TrainingAllowance.planTraining(state, "Squat", now + 1810, 10)

	check("a 10 second tick earns 10/3600 EV", near(tiny.earnedEV, 10 / 3600),
		string.format("%.10f", tiny.earnedEV))
	check("and credits 10/3600 hours", near(tiny.creditedHours, 10 / 3600))
end

--------------------------------------------------------------------------------
print("4. a preview mutates nothing, and repeated reads grant nothing")
do
	local state = unstampedState()
	local now = DAY_START + 9 * HOUR

	state = applyPlan(TrainingAllowance.planTraining(state, "Squat", now, 3600))

	local snapshot = {
		cnSpent = state.cnAllowance.spentToday,
		cnDayKey = state.cnAllowance.dayKey,
		cnStamp = state.cnAllowance.lastUpdatedUnix,
		techSpent = state.techniqueAllowance.spentToday,
		techDayKey = state.techniqueAllowance.dayKey,
		squat = state.trainingTimeToday.Squat,
		bench = state.trainingTimeToday.Bench,
		deadlift = state.trainingTimeToday.Deadlift,
		hoursDayKey = state.trainingTimeToday.dayKey,
	}

	--[[
		TEN PREVIEWS, NOTHING APPLIED. Every one must return the same plan and
		leave the records byte-identical.
	]]
	local first = TrainingAllowance.planTraining(state, "Squat", now + 600, 600)
	local identical = true

	for _ = 1, 10 do
		local again = TrainingAllowance.planTraining(state, "Squat", now + 600, 600)

		if not near(again.earnedEV, first.earnedEV, 0) or not near(again.creditedHours, first.creditedHours, 0) then
			identical = false
		end
	end

	check("ten previews return an identical plan", identical)

	check("the input CN record was not modified",
		state.cnAllowance.spentToday == snapshot.cnSpent
			and state.cnAllowance.dayKey == snapshot.cnDayKey
			and state.cnAllowance.lastUpdatedUnix == snapshot.cnStamp,
		string.format("%.10f vs %.10f", state.cnAllowance.spentToday, snapshot.cnSpent))
	check("the input technique record was not modified",
		state.techniqueAllowance.spentToday == snapshot.techSpent
			and state.techniqueAllowance.dayKey == snapshot.techDayKey)
	check("the input hours record was not modified",
		state.trainingTimeToday.Squat == snapshot.squat
			and state.trainingTimeToday.Bench == snapshot.bench
			and state.trainingTimeToday.Deadlift == snapshot.deadlift
			and state.trainingTimeToday.dayKey == snapshot.hoursDayKey)

	-- And the plan's nextState is a SEPARATE table, not an alias of the input.
	first.nextState.cnAllowance.spentToday = 99

	check("the plan's nextState is not an alias of the input",
		state.cnAllowance.spentToday == snapshot.cnSpent)

	-- Repeated READS of the derived values are equally inert.
	for _ = 1, 5 do
		TrainingAllowance.remainingCN(state.cnAllowance, now)
		TrainingAllowance.remainingTechnique(state.techniqueAllowance, now)
		TrainingAllowance.hoursOnLift(state.trainingTimeToday, "Squat", now)
	end

	check("five rounds of reads changed nothing", state.cnAllowance.spentToday == snapshot.cnSpent)
	checkInvariant("after previews", state, now)
end

--------------------------------------------------------------------------------
print("5. a zero-length interval earns nothing but still normalises the day")
do
	local state = unstampedState()
	local now = DAY_START + 8 * HOUR

	local plan = TrainingAllowance.planTraining(state, "Bench", now, 0)

	check("zero elapsed earns exactly 0 EV", plan.earnedEV == 0)
	check("zero elapsed credits exactly 0 hours", plan.creditedHours == 0)
	check("one day touched", plan.daysTouched == 1)
	check("the cap was not reached", plan.capReached == false)

	--[[
		IT STILL PROPOSES THE ROLLOVER. An UNSTAMPED record becomes today's
		record holding zero, which is a no-op on the numbers and the reason no
		caller needs to special-case a new profile.
	]]
	check("it proposes stamping today's day key",
		plan.nextState.cnAllowance.dayKey == DayKey.fromUnix(now))
	check("and reports that as a change worth writing", plan.changed == true)

	local applied = applyPlan(plan)

	check("after applying, nothing was spent", applied.cnAllowance.spentToday == 0)
	check("and a second zero-length plan reports no change",
		TrainingAllowance.planTraining(applied, "Bench", now, 0).changed == false)
end

--------------------------------------------------------------------------------
print("6. switching lifts preserves each lift's own banked time")
do
	local state = unstampedState()
	local now = DAY_START + 6 * HOUR

	-- Two hours of Squat: full rate throughout.
	state = applyPlan(TrainingAllowance.planTraining(state, "Squat", now, 2 * HOUR))
	now += 2 * HOUR

	check("Squat earned 2.00 EV", near(state.cnAllowance.spentToday, 2.00))
	check("Squat holds 2.00 hours", near(state.trainingTimeToday.Squat, 2.00))

	-- SWITCH to Bench. Its own clock is at zero, so it starts at full rate.
	state = applyPlan(TrainingAllowance.planTraining(state, "Bench", now, 1 * HOUR))
	now += 1 * HOUR

	check("Bench earned a further 1.00 EV at full rate", near(state.cnAllowance.spentToday, 3.00),
		string.format("%.8f", state.cnAllowance.spentToday))
	check("Bench holds 1.00 hour", near(state.trainingTimeToday.Bench, 1.00))
	check("SWITCHING DID NOT RESET Squat's 2.00 hours", near(state.trainingTimeToday.Squat, 2.00),
		string.format("%.8f", state.trainingTimeToday.Squat))
	check("Deadlift is still untouched", state.trainingTimeToday.Deadlift == 0)
	checkInvariant("after the switch", state, now)

	--[[
		SWITCH BACK. This is the assertion that matters: Squat resumes at t = 2.00
		and is past its full-rate window, so half an hour earns 0.44629 rather
		than the 0.50 a reset clock would have paid.
	]]
	local back = TrainingAllowance.planTraining(state, "Squat", now + 1800, 1800)

	check("returning to Squat earns 0.44629, not 0.50", near(back.earnedEV, 0.4462871, 1e-6),
		string.format("%.8f", back.earnedEV))
	check("it is NOT the 0.50 a reset clock would have paid", not near(back.earnedEV, 0.50, 0.01))

	state = applyPlan(back)
	now += 1800

	check("Squat now holds 2.50 hours", near(state.trainingTimeToday.Squat, 2.50))
	check("account spend is 3.44629", near(state.cnAllowance.spentToday, 3.4462871, 1e-6),
		string.format("%.8f", state.cnAllowance.spentToday))
	checkInvariant("after switching back", state, now)
end

--------------------------------------------------------------------------------
print("7. the EV cap is ACCOUNT-WIDE: a third lift is throttled by the first two")
do
	local state = unstampedState()
	local now = DAY_START + 6 * HOUR

	state = applyPlan(TrainingAllowance.planTraining(state, "Squat", now, 2 * HOUR))
	now += 2 * HOUR
	state = applyPlan(TrainingAllowance.planTraining(state, "Bench", now, 1 * HOUR))
	now += 1 * HOUR
	state = applyPlan(TrainingAllowance.planTraining(state, "Squat", now, 1800))
	now += 1800

	local remaining = TrainingAllowance.remainingCN(state.cnAllowance, now)

	check("0.55371 EV remains for the whole account", near(remaining, 0.5537129, 1e-6),
		string.format("%.8f", remaining))

	--[[
		DEADLIFT HAS NEVER BEEN TRAINED, so its own efficiency is a full 1.0 and
		it WANTS a full 1.00 EV for an hour. It gets 0.55371, because the cap
		belongs to the account and not to the lift.
	]]
	local plan = TrainingAllowance.planTraining(state, "Deadlift", now, 1 * HOUR)

	check("a fresh Deadlift still only earns the account remainder",
		near(plan.earnedEV, 0.5537129, 1e-6), string.format("%.8f", plan.earnedEV))
	check("the cap was reached", plan.capReached == true)
	check("only the earning hours were credited", near(plan.creditedHours, 0.5537129, 1e-6),
		string.format("%.8f", plan.creditedHours))
	check("the rest of the hour is reported uncredited",
		near(plan.uncreditedSeconds, 0.4462871 * HOUR, 0.01),
		string.format("%.2f s", plan.uncreditedSeconds))

	state = applyPlan(plan)

	check("spend is exactly the 4.00 cap", near(state.cnAllowance.spentToday, 4.00, 1e-9),
		string.format("%.10f", state.cnAllowance.spentToday))
	check("nothing remains", TrainingAllowance.remainingCN(state.cnAllowance, now) == 0)
	checkInvariant("at the cap", state, now)

	-- Any further training earns nothing at all, on any lift.
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local exhausted = TrainingAllowance.planTraining(state, lift, now + HOUR, HOUR)

		check(string.format("%s earns nothing once the account cap is spent", lift),
			exhausted.earnedEV == 0 and exhausted.creditedHours == 0,
			string.format("%.10f EV", exhausted.earnedEV))
		check(string.format("%s banks no hours either", lift),
			near((exhausted.nextState.trainingTimeToday :: any)[lift] :: number,
				(state.trainingTimeToday :: any)[lift] :: number, 0))
	end
end

--------------------------------------------------------------------------------
print("8. the cap landing in the MIDDLE of an interval")
do
	--[[
		Squat at 5.00 hours has earned EV(5) = 3.832581, leaving 0.167419. A
		one-hour tick wants 0.364643, so it is cut off partway.

		THE HOURS CREDITED ARE THE EXACT INVERSE, not a proportion: 0.436564 of
		the hour, landing Squat at exactly t* = 5.436564, which is the hour at
		which one lift exhausts the whole cap. That the two agree is a real check
		on the inverse, not a coincidence.
	]]
	local state = unstampedState()
	local now = DAY_START + 3 * HOUR
	local dayKey = DayKey.fromUnix(now)

	state = {
		cnAllowance = {
			spentToday = TrainingEfficiency.cumulativeEV(5.0),
			dayKey = dayKey,
			lastUpdatedUnix = now,
		},
		techniqueAllowance = { spentToday = 0, dayKey = dayKey, lastUpdatedUnix = now },
		trainingTimeToday = {
			Squat = 5.0,
			Bench = 0,
			Deadlift = 0,
			dayKey = dayKey,
			lastUpdatedUnix = now,
		},
	}

	checkInvariant("the fixture itself", state, now)

	check("0.167419 EV remains", near(TrainingAllowance.remainingCN(state.cnAllowance, now), 0.1674189, 1e-6),
		string.format("%.8f", TrainingAllowance.remainingCN(state.cnAllowance, now)))

	local wanted = TrainingEfficiency.accrue(5.0, 1.0)

	check("an unthrottled hour would have wanted 0.364643", near(wanted, 0.3646431, 1e-6),
		string.format("%.8f", wanted))

	local plan = TrainingAllowance.planTraining(state, "Squat", now + HOUR, HOUR)

	check("only 0.167419 EV is granted", near(plan.earnedEV, 0.1674189, 1e-6),
		string.format("%.8f", plan.earnedEV))
	check("the cap was reached", plan.capReached == true)
	check("0.436564 hours are credited", near(plan.creditedHours, 0.4365637, 1e-6),
		string.format("%.8f", plan.creditedHours))
	check("0.563436 hours are reported uncredited",
		near(plan.uncreditedSeconds, 0.5634363 * HOUR, 0.01),
		string.format("%.2f s", plan.uncreditedSeconds))

	state = applyPlan(plan)

	check("Squat lands at exactly t* = 5.436564", near(state.trainingTimeToday.Squat, 5.4365637, 1e-6),
		string.format("%.8f", state.trainingTimeToday.Squat))
	check("which is TrainingEfficiency.hoursToReach(4.00)",
		near(state.trainingTimeToday.Squat, TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV), 1e-9))
	check("spend is exactly the cap", near(state.cnAllowance.spentToday, 4.00, 1e-9))
	checkInvariant("after the mid-interval cap", state, now + HOUR)
end

--------------------------------------------------------------------------------
print("9. a UTC midnight inside the interval is SPLIT, not rounded")
do
	--[[
		23:50 to 00:10. Ten minutes belong to day D and ten to day D+1.

		Crediting all twenty to one side would be wrong either way: against D it
		would be throttled by an allowance that has expired, and against D+1 it
		would silently discard the pre-midnight half.
	]]
	local state = unstampedState()
	local now = DAY_START + DAY + 600
	local startUnix = now - 1200

	check("the interval really does straddle midnight",
		DayKey.fromUnix(startUnix) ~= DayKey.fromUnix(now),
		string.format("%s -> %s", DayKey.fromUnix(startUnix), DayKey.fromUnix(now)))

	local plan = TrainingAllowance.planTraining(state, "Squat", now, 1200)

	check("two days were touched", plan.daysTouched == 2, tostring(plan.daysTouched))
	check("the TOTAL earned is 0.333333 EV, both halves", near(plan.earnedEV, 1 / 3, 1e-9),
		string.format("%.10f", plan.earnedEV))
	check("0.333333 hours were credited in total", near(plan.creditedHours, 1 / 3, 1e-9))
	check("nothing was uncredited", near(plan.uncreditedSeconds, 0, 1e-6))

	state = applyPlan(plan)

	--[[
		THE RESULTING RECORD DESCRIBES DAY D+1 ONLY. The pre-midnight half was
		earned and spent against day D, whose counters have since been rolled
		away, so today shows just the ten minutes that belong to it.
	]]
	check("the stored day is now D+1", state.cnAllowance.dayKey == DayKey.fromUnix(now),
		state.cnAllowance.dayKey)
	check("today's spend is only the post-midnight 0.166667",
		near(state.cnAllowance.spentToday, 1 / 6, 1e-9), string.format("%.10f", state.cnAllowance.spentToday))
	check("Squat's hours likewise show only 0.166667",
		near(state.trainingTimeToday.Squat, 1 / 6, 1e-9))
	check("so 3.833333 EV remains for the new day",
		near(TrainingAllowance.remainingCN(state.cnAllowance, now), 4.00 - 1 / 6, 1e-9),
		string.format("%.10f", TrainingAllowance.remainingCN(state.cnAllowance, now)))
	checkInvariant("after the midnight split", state, now)

	--[[
		AND THE PRE-MIDNIGHT HALF REALLY WAS THROTTLED BY DAY D's ALLOWANCE. With
		day D already at the cap, only the post-midnight half can earn.
	]]
	local cappedYesterday = unstampedState()
	local yesterdayKey = DayKey.fromUnix(startUnix)

	cappedYesterday.cnAllowance = {
		spentToday = TRAINING.DailyCapEV,
		dayKey = yesterdayKey,
		lastUpdatedUnix = startUnix,
	}
	cappedYesterday.trainingTimeToday = {
		Squat = TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV),
		Bench = 0,
		Deadlift = 0,
		dayKey = yesterdayKey,
		lastUpdatedUnix = startUnix,
	}

	local split = TrainingAllowance.planTraining(cappedYesterday, "Squat", now, 1200)

	check("with day D capped, only the post-midnight half earns",
		near(split.earnedEV, 1 / 6, 1e-9), string.format("%.10f", split.earnedEV))
	check("and it earns at FULL rate, because the new day reset H(t)",
		near(split.earnedEV, 600 / HOUR, 1e-9))
	check("the cap was reported reached, for the day D half", split.capReached == true)

	local after = applyPlan(split)

	check("Squat's hours reset to the post-midnight 0.166667 only",
		near(after.trainingTimeToday.Squat, 1 / 6, 1e-9),
		string.format("%.10f", after.trainingTimeToday.Squat))
	checkInvariant("after the capped-yesterday split", after, now)
end

--------------------------------------------------------------------------------
print("10. reconnect, and the new UTC day")
do
	local state = unstampedState()
	local morning = DAY_START + 8 * HOUR

	state = applyPlan(TrainingAllowance.planTraining(state, "Squat", morning, 90 * 60))

	check("1.5 hours earned 1.50 EV", near(state.cnAllowance.spentToday, 1.50))

	--[[
		A RECONNECT LATER THE SAME DAY. The counters are read back as they were
		stored, so the afternoon continues the morning rather than restarting it.
		Nothing here credits the gap: the caller supplies only observed elapsed
		time, so the hours between sessions simply never arrive.
	]]
	local afternoon = DAY_START + 16 * HOUR

	check("the same-day record is NOT stale after a gap",
		TrainingAllowance.isStale(state.cnAllowance, afternoon) == false)
	check("1.50 EV is still spent", near(TrainingAllowance.spentToday(state.cnAllowance, afternoon), 1.50))
	check("2.50 EV still remains", near(TrainingAllowance.remainingCN(state.cnAllowance, afternoon), 2.50))
	check("Squat still holds 1.50 hours",
		near(TrainingAllowance.hoursOnLift(state.trainingTimeToday, "Squat", afternoon), 1.50))

	--[[
		THE GAP ITSELF IS NOT CREDITED. Eight hours passed, but the caller reports
		a 60 second tick, so 60 seconds is what is considered. Section 34.2.
	]]
	local resumed = TrainingAllowance.planTraining(state, "Squat", afternoon, 60)

	check("an 8 hour gap credits only the 60 seconds reported",
		near(resumed.earnedEV, TrainingEfficiency.accrue(1.5, 60 / HOUR), 1e-12),
		string.format("%.10f", resumed.earnedEV))
	check("which is well under one EV", resumed.earnedEV < 0.02, string.format("%.6f", resumed.earnedEV))

	state = applyPlan(resumed)
	checkInvariant("after the reconnect", state, afternoon)

	--[[
		THE NEXT UTC DAY. Everything resets: the allowance, the technique
		allowance and all three hour counters. H(t) returns to 1.0 for every lift.
	]]
	local tomorrow = DAY_START + DAY + 9 * HOUR

	check("the record reads stale on the new day",
		TrainingAllowance.isStale(state.cnAllowance, tomorrow))
	check("spent reads 0 on the new day",
		TrainingAllowance.spentToday(state.cnAllowance, tomorrow) == 0)
	check("the full 4.00 EV is available again",
		near(TrainingAllowance.remainingCN(state.cnAllowance, tomorrow), 4.00))
	check("Squat's hours read 0 on the new day",
		TrainingAllowance.hoursOnLift(state.trainingTimeToday, "Squat", tomorrow) == 0)

	local fresh = TrainingAllowance.planTraining(state, "Squat", tomorrow, HOUR)

	check("an hour on the new day earns a full 1.00 EV again", near(fresh.earnedEV, 1.00),
		string.format("%.8f", fresh.earnedEV))

	local tomorrowState = applyPlan(fresh)

	check("the new day's spend is just that 1.00 EV",
		near(tomorrowState.cnAllowance.spentToday, 1.00))
	check("all three hour counters rolled over together",
		near(tomorrowState.trainingTimeToday.Squat, 1.00)
			and tomorrowState.trainingTimeToday.Bench == 0
			and tomorrowState.trainingTimeToday.Deadlift == 0)
	check("the hours record carries the new day key",
		tomorrowState.trainingTimeToday.dayKey == DayKey.fromUnix(tomorrow))
	checkInvariant("on the new day", tomorrowState, tomorrow)
end

--------------------------------------------------------------------------------
print("11. a backward clock pauses earning rather than draining it")
do
	local state = unstampedState()
	local now = DAY_START + 10 * HOUR

	state = applyPlan(TrainingAllowance.planTraining(state, "Squat", now, HOUR))

	local before = state.cnAllowance.spentToday

	-- NEGATIVE ELAPSED, from an NTP correction between ticks.
	local rollback = TrainingAllowance.planTraining(state, "Squat", now, -300)

	check("negative elapsed earns exactly 0", rollback.earnedEV == 0)
	check("negative elapsed credits exactly 0 hours", rollback.creditedHours == 0)
	check("and spends nothing", near(rollback.nextState.cnAllowance.spentToday, before, 0))
	check("and does not reduce the banked hours",
		near(rollback.nextState.trainingTimeToday.Squat, state.trainingTimeToday.Squat, 0))

	-- A `now` earlier than the last write is also harmless.
	local earlier = TrainingAllowance.planTraining(state, "Squat", now - 600, 0)

	check("a `now` before the last write earns nothing", earlier.earnedEV == 0)
	check("and leaves the same-day counters alone",
		near(earlier.nextState.cnAllowance.spentToday, before, 0))

	checkInvariant("after the rollback", state, now)
end

--------------------------------------------------------------------------------
print("12. the technique allowance: remaining and rollover, read-only")
do
	local state = unstampedState()
	local now = DAY_START + 11 * HOUR
	local dayKey = DayKey.fromUnix(now)

	check("a fresh account has the full 6.00 raw points",
		near(TrainingAllowance.remainingTechnique(state.techniqueAllowance, now), 6.00))

	--[[
		4.80 is section 34.7's 80% primary share of a full day. A fractional
		remainder must survive, which is why the schema stores these as plain
		numbers.
	]]
	state.techniqueAllowance = { spentToday = 4.80, dayKey = dayKey, lastUpdatedUnix = now }

	check("after the 4.80 primary share, 1.20 remains",
		near(TrainingAllowance.remainingTechnique(state.techniqueAllowance, now), 1.20),
		string.format("%.8f", TrainingAllowance.remainingTechnique(state.techniqueAllowance, now)))

	state.techniqueAllowance.spentToday = 6.00

	check("a fully spent technique allowance leaves 0",
		TrainingAllowance.remainingTechnique(state.techniqueAllowance, now) == 0)

	-- A stored value above the cap reports zero rather than a negative.
	state.techniqueAllowance.spentToday = 99

	check("an over-cap stored value reports 0 remaining, never negative",
		TrainingAllowance.remainingTechnique(state.techniqueAllowance, now) == 0)

	state.techniqueAllowance.spentToday = 6.00

	-- IT ROLLS OVER ON THE SAME DAY KEY AS THE OTHERS.
	local tomorrow = now + DAY

	check("the technique allowance is stale on the new day",
		TrainingAllowance.isStale(state.techniqueAllowance, tomorrow))
	check("and reads a full 6.00 again",
		near(TrainingAllowance.remainingTechnique(state.techniqueAllowance, tomorrow), 6.00))

	--[[
		A CN PLAN ROLLS THE TECHNIQUE RECORD TOO, because they share the calendar.
		It never SPENDS it: awarding technique is checkpoint 5B.7.
	]]
	local plan = TrainingAllowance.planTraining(state, "Squat", tomorrow, HOUR)

	check("a CN plan rolls the technique record onto the new day",
		plan.nextState.techniqueAllowance.dayKey == DayKey.fromUnix(tomorrow))
	check("and zeroes its spend", plan.nextState.techniqueAllowance.spentToday == 0)
	check("while never spending any of it",
		plan.nextState.techniqueAllowance.spentToday == 0
			and TrainingAllowance.remainingTechnique(plan.nextState.techniqueAllowance, tomorrow)
				== TRAINING.DailyCapTechniqueRaw)

	-- An over-cap CN allowance likewise reports zero remaining.
	local overspent = unstampedState()
	overspent.cnAllowance = { spentToday = 99, dayKey = dayKey, lastUpdatedUnix = now }

	check("an over-cap CN allowance reports 0 remaining, never negative",
		TrainingAllowance.remainingCN(overspent.cnAllowance, now) == 0)
	check("and a plan against it earns nothing",
		TrainingAllowance.planTraining(overspent, "Squat", now, HOUR).earnedEV == 0)
end

--------------------------------------------------------------------------------
print("13. the double-spend guard: a plan knows what it was computed against")
do
	local state = unstampedState()
	local now = DAY_START + 7 * HOUR

	state = applyPlan(TrainingAllowance.planTraining(state, "Squat", now, HOUR))
	now += HOUR

	local planA = TrainingAllowance.planTraining(state, "Squat", now + 600, 600)
	local planB = TrainingAllowance.planTraining(state, "Squat", now + 600, 600)

	check("both plans match the state they were computed from",
		TrainingAllowance.matchesBasis(state, planA)
			and TrainingAllowance.matchesBasis(state, planB))

	--[[
		APPLY A. The counters move, so B is now stale. Because a plan carries an
		ABSOLUTE next state rather than a delta, applying B on top would leave the
		allowance showing one spend while two awards were handed out -- one debit,
		two grants. 5B.5 must therefore check the basis inside the same mutator
		that performs the write.
	]]
	local afterA = applyPlan(planA)

	check("after applying A, plan A no longer matches",
		TrainingAllowance.matchesBasis(afterA, planA) == false)
	check("and plan B is detectably stale",
		TrainingAllowance.matchesBasis(afterA, planB) == false)

	-- Recomputing from the new state gives a plan that does match.
	local planC = TrainingAllowance.planTraining(afterA, "Squat", now + 1200, 600)

	check("a plan recomputed from the current state matches",
		TrainingAllowance.matchesBasis(afterA, planC))

	-- The basis is per lift, so a Bench plan is not validated by Squat's counters.
	local benchPlan = TrainingAllowance.planTraining(afterA, "Bench", now + 1200, 600)

	check("the basis records every lift's hours, not just the selected one",
		benchPlan.basis.hoursSquat == afterA.trainingTimeToday.Squat
			and benchPlan.basis.hoursBench == afterA.trainingTimeToday.Bench
			and benchPlan.basis.hoursDeadlift == afterA.trainingTimeToday.Deadlift)
	check("and the day key it was computed under",
		benchPlan.basis.cnDayKey == afterA.cnAllowance.dayKey)

	checkInvariant("after the basis checks", afterA, now + 600)
end

--------------------------------------------------------------------------------
print("14. invalid input is refused, leaving the records untouched")
do
	local state = unstampedState()
	local now = DAY_START + 5 * HOUR

	state = applyPlan(TrainingAllowance.planTraining(state, "Squat", now, HOUR))

	local before = state.cnAllowance.spentToday
	local beforeHours = state.trainingTimeToday.Squat

	check("an unknown lift is rejected",
		not (pcall(TrainingAllowance.planTraining, state, "Overhead", now, 60)))
	check("a nil lift is rejected",
		not (pcall(TrainingAllowance.planTraining, state, (nil :: any), now, 60)))
	check("NaN elapsed is rejected",
		not (pcall(TrainingAllowance.planTraining, state, "Squat", now, 0 / 0)))
	check("infinite elapsed is rejected",
		not (pcall(TrainingAllowance.planTraining, state, "Squat", now, math.huge)))
	check("a negative nowUnix is rejected",
		not (pcall(TrainingAllowance.planTraining, state, "Squat", -1, 60)))

	--[[
		THE SANITY BOUND. A single tick cannot legitimately observe more than a
		day of training, so a caller passing more is refused rather than granted
		a day of progression.
	]]
	check("elapsed above the one-day sanity bound is rejected",
		not (pcall(TrainingAllowance.planTraining, state, "Squat", now, DAY + 1)))
	check("exactly one day is accepted",
		(pcall(TrainingAllowance.planTraining, state, "Squat", now, DAY)))

	-- A corrupt record is refused rather than guessed at.
	local corrupt = unstampedState()
	corrupt.cnAllowance.spentToday = 0 / 0

	check("a NaN stored spend is rejected",
		not (pcall(TrainingAllowance.planTraining, corrupt, "Squat", now, 60)))

	local badKey = unstampedState()
	badKey.trainingTimeToday.dayKey = (12345 :: any)

	check("a non-string stored day key is rejected",
		not (pcall(TrainingAllowance.planTraining, badKey, "Squat", now, 60)))

	--[[
		NO PARTIAL MUTATION. Every refusal above happened before any write could
		occur, and the module only ever writes to its own copies anyway, so the
		caller's records are provably untouched.
	]]
	check("after every refusal the CN record is unchanged", state.cnAllowance.spentToday == before,
		string.format("%.10f vs %.10f", state.cnAllowance.spentToday, before))
	check("and the hours are unchanged", state.trainingTimeToday.Squat == beforeHours)
	checkInvariant("after the refusals", state, now)
end

--------------------------------------------------------------------------------
print("15. a full simulated day, tick by tick")
do
	--[[
		Sixty 5-minute ticks on a rotating lift, which is 5 hours of wall clock.
		The point is that the invariant and the cap both survive many small
		applications rather than one big one.
	]]
	local state = unstampedState()
	local now = DAY_START + 4 * HOUR
	local lifts = ProgressionConfig.Lifts
	local totalEarned = 0

	for tick = 1, 60 do
		local lift = lifts[((tick - 1) % 3) + 1]
		local plan = TrainingAllowance.planTraining(state, lift, now + 300, 300)

		totalEarned += plan.earnedEV
		state = applyPlan(plan)
		now += 300
	end

	check("five hours of rotating 5-minute ticks earned the full 4.00 cap",
		near(totalEarned, TRAINING.DailyCapEV, 1e-6), string.format("%.8f", totalEarned))
	check("the stored spend is the cap", near(state.cnAllowance.spentToday, TRAINING.DailyCapEV, 1e-6))
	check("nothing remains", TrainingAllowance.remainingCN(state.cnAllowance, now) < 1e-6)
	checkInvariant("after 60 ticks", state, now)

	--[[
		AND THE HOURS ARE SPREAD ACROSS THE THREE LIFTS, none of them past its
		full-rate window, which is why the cap arrived in well under the 5.4366
		hours one lift alone would have needed.
	]]
	local banked = 0

	for _, lift in ipairs(lifts) do
		banked += (state.trainingTimeToday :: any)[lift] :: number
	end

	check("the banked hours total under 5.4366, because the day was split",
		banked < TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV),
		string.format("%.6f banked vs %.6f for one lift", banked,
			TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV)))
	check("and each lift is still inside its full-rate window",
		(state.trainingTimeToday.Squat :: number) <= TRAINING.FullRateHours
			and (state.trainingTimeToday.Bench :: number) <= TRAINING.FullRateHours
			and (state.trainingTimeToday.Deadlift :: number) <= TRAINING.FullRateHours,
		string.format("%.4f / %.4f / %.4f",
			state.trainingTimeToday.Squat, state.trainingTimeToday.Bench, state.trainingTimeToday.Deadlift))
end

--------------------------------------------------------------------------------
print("16. a BACKWARD clock fails closed and never resets an allowance")
do
	local dayD = DAY_START + 10 * HOUR
	local dayDplus1 = DAY_START + DAY + 10 * HOUR
	local keyDplus1 = DayKey.fromUnix(dayDplus1)

	--[[
		A record legitimately stamped on day D+1 with real spending. The invariant
		holds: 2.50 EV spent is exactly EV(2.50 hours) inside the full-rate window.
	]]
	--[[
		THE SPEND MUST EQUAL EV(hours), not the hour count. 2.50 hours is PAST the
		two-hour full-rate window, so it has earned EV(2.50) = 2.446287 rather than
		2.50. Writing 2.50 here would break the central invariant in the fixture
		itself and the test would be measuring a state the game cannot produce.
	]]
	local spentOnDplus1 = TrainingEfficiency.cumulativeEV(2.50)

	local state: TrainingAllowance.State = {
		cnAllowance = { spentToday = spentOnDplus1, dayKey = keyDplus1, lastUpdatedUnix = dayDplus1 },
		techniqueAllowance = { spentToday = 4.80, dayKey = keyDplus1, lastUpdatedUnix = dayDplus1 },
		trainingTimeToday = {
			Squat = 2.50,
			Bench = 0,
			Deadlift = 0,
			dayKey = keyDplus1,
			lastUpdatedUnix = dayDplus1,
		},
	}

	checkInvariant("the day D+1 fixture", state, dayDplus1)

	----------------------------------------------------------------------------
	-- NOW THE CLOCK STEPS BACK A DAY.
	----------------------------------------------------------------------------
	check("dayStatus reports Future", TrainingAllowance.dayStatus(state.cnAllowance, dayD) == "Future",
		TrainingAllowance.dayStatus(state.cnAllowance, dayD))
	check("isStale is FALSE for a future key, so nothing wants to roll it",
		TrainingAllowance.isStale(state.cnAllowance, dayD) == false)

	check("the stored CN spend is PRESERVED, not zeroed",
		near(TrainingAllowance.spentToday(state.cnAllowance, dayD), spentOnDplus1),
		string.format("%.8f", TrainingAllowance.spentToday(state.cnAllowance, dayD)))
	check("remainingCN fails closed at 0, not at cap minus spend",
		TrainingAllowance.remainingCN(state.cnAllowance, dayD) == 0,
		string.format("%.8f", TrainingAllowance.remainingCN(state.cnAllowance, dayD)))
	check("remainingTechnique fails closed at 0",
		TrainingAllowance.remainingTechnique(state.techniqueAllowance, dayD) == 0)
	check("the stored hours are PRESERVED",
		near(TrainingAllowance.hoursOnLift(state.trainingTimeToday, "Squat", dayD), 2.50))

	local plan = TrainingAllowance.planTraining(state, "Squat", dayD, HOUR)

	check("the plan reports clockWentBackward", plan.clockWentBackward == true)
	check("it earns nothing", plan.earnedEV == 0)
	check("it credits no hours", plan.creditedHours == 0)
	check("it reports no change, so nothing would be written", plan.changed == false)
	check("it touched no days", plan.daysTouched == 0, tostring(plan.daysTouched))

	-- THE PROPOSED STATE IS A FAITHFUL NO-OP: nothing moved, not even a timestamp.
	local proposed = plan.nextState

	check("the proposed CN spend is unchanged", proposed.cnAllowance.spentToday == spentOnDplus1)
	check("the proposed CN day key is unchanged", proposed.cnAllowance.dayKey == keyDplus1)
	check("the proposed CN timestamp is unchanged", proposed.cnAllowance.lastUpdatedUnix == dayDplus1,
		tostring(proposed.cnAllowance.lastUpdatedUnix))
	check("the proposed technique record is unchanged",
		proposed.techniqueAllowance.spentToday == 4.80
			and proposed.techniqueAllowance.dayKey == keyDplus1)
	check("the proposed hours are unchanged",
		proposed.trainingTimeToday.Squat == 2.50 and proposed.trainingTimeToday.dayKey == keyDplus1)
	check("so applying it is provably a no-op", TrainingAllowance.matchesBasis(proposed, plan))
	check("and the input state was never touched", state.cnAllowance.spentToday == spentOnDplus1)

	--[[
		IT CLEARS BY ITSELF. Nothing is repaired, because nothing here can tell
		which clock was wrong. When the clock catches up to the stored day the key
		matches again and training resumes -- from the stored hours, not from zero.
	]]
	local resumed = TrainingAllowance.planTraining(state, "Squat", dayDplus1 + HOUR, HOUR)

	check("once the clock catches up, the block clears", resumed.clockWentBackward == false)
	check("and training resumes from the stored 2.50 hours, not from zero",
		near(resumed.earnedEV, TrainingEfficiency.accrue(2.50, 1.0), 1e-9),
		string.format("%.8f vs %.8f", resumed.earnedEV, TrainingEfficiency.accrue(2.50, 1.0)))
	check("which is less than a full hour's worth, because H(t) is past its window",
		resumed.earnedEV < 1.00, string.format("%.8f", resumed.earnedEV))

	----------------------------------------------------------------------------
	--[[
		THE SUBTLER FORM. The stored day is correct, but the INTERVAL starts in the
		day before it. Without the gate, the segment loop would roll the record
		backward to D-1, zeroing day D's spend, and then forward again -- handing
		out a second full allowance without any stale profile being involved.

		3.297443 hours is inv(3.00), so the fixture's invariant holds exactly.
	]]
	----------------------------------------------------------------------------
	local keyD = DayKey.fromUnix(dayD)
	local onDayD: TrainingAllowance.State = {
		cnAllowance = { spentToday = 3.00, dayKey = keyD, lastUpdatedUnix = dayD },
		techniqueAllowance = { spentToday = 0, dayKey = keyD, lastUpdatedUnix = dayD },
		trainingTimeToday = {
			Squat = TrainingEfficiency.hoursToReach(3.00),
			Bench = 0,
			Deadlift = 0,
			dayKey = keyD,
			lastUpdatedUnix = dayD,
		},
	}

	checkInvariant("the day D fixture", onDayD, dayD)

	local backwardSpan = TrainingAllowance.planTraining(onDayD, "Squat", DAY_START + 300, 600)

	check("an interval STARTING before the stored day is also refused",
		backwardSpan.clockWentBackward == true)
	check("and day D's 3.00 EV spend is not zeroed",
		backwardSpan.nextState.cnAllowance.spentToday == 3.00,
		string.format("%.8f", backwardSpan.nextState.cnAllowance.spentToday))
	check("nor are day D's banked hours",
		near(backwardSpan.nextState.trainingTimeToday.Squat,
			TrainingEfficiency.hoursToReach(3.00), 0))

	----------------------------------------------------------------------------
	-- FORWARD ROLLOVER MUST STILL WORK. This is the regression guard.
	----------------------------------------------------------------------------
	local forward = TrainingAllowance.planTraining(onDayD, "Squat", DAY_START + DAY + HOUR, HOUR)

	check("a genuine new day is NOT treated as a backward clock",
		forward.clockWentBackward == false)
	check("it rolls over and grants a full fresh hour", near(forward.earnedEV, 1.00),
		string.format("%.8f", forward.earnedEV))
	check("the hour counters reset, so Squat holds just the new hour",
		near(forward.nextState.trainingTimeToday.Squat, 1.00))
	check("and the new day key is stamped",
		forward.nextState.cnAllowance.dayKey == DayKey.fromUnix(DAY_START + DAY + HOUR))
	checkInvariant("after the forward roll", applyPlan(forward), DAY_START + DAY + HOUR)

	-- An ordinary midnight span still works too, and is not mistaken for a fault.
	local spanning = TrainingAllowance.planTraining(onDayD, "Squat", DAY_START + DAY + 600, 1200)

	check("a normal midnight-spanning interval is not blocked",
		spanning.clockWentBackward == false)
	check("and still splits across two days", spanning.daysTouched == 2,
		tostring(spanning.daysTouched))

	----------------------------------------------------------------------------
	--[[
		THE ORDERING THE WHOLE RULE RESTS ON. "YYYY-MM-DD" is zero-padded, so
		lexicographic order is chronological order and no parsing is needed. 400
		consecutive days covers month and year boundaries.
	]]
	----------------------------------------------------------------------------
	local orderingHolds = true
	local firstBreak = ""

	for i = 0, 400 do
		local a = DayKey.fromUnix(DAY_START + i * DAY)
		local b = DayKey.fromUnix(DAY_START + (i + 1) * DAY)

		if not (a < b) then
			orderingHolds = false
			if firstBreak == "" then
				firstBreak = a .. " vs " .. b
			end
		end
	end

	check("ISO day keys sort chronologically across 400 consecutive days", orderingHolds, firstBreak)
	check("UNSTAMPED sorts before every real key, so a new profile is never Future",
		DayKey.UNSTAMPED < DayKey.fromUnix(DAY_START))
	check("an UNSTAMPED record therefore reports Past, not Future",
		TrainingAllowance.dayStatus(unstampedState().cnAllowance, dayD) == "Past")
end

--------------------------------------------------------------------------------
print("17. the basis covers EVERY field a plan overwrites")
do
	local now = DAY_START + 7 * HOUR
	local state = unstampedState()

	state = applyPlan(TrainingAllowance.planTraining(state, "Squat", now, HOUR))
	now += HOUR
	state = applyPlan(TrainingAllowance.planTraining(state, "Deadlift", now, 1800))
	now += 1800

	local plan = TrainingAllowance.planTraining(state, "Squat", now + 600, 600)

	check("the plan matches the state it was computed from",
		TrainingAllowance.matchesBasis(state, plan))
	check("matchesBasis takes exactly two arguments, no lift",
		debug.info(TrainingAllowance.matchesBasis, "a") == 2,
		tostring(debug.info(TrainingAllowance.matchesBasis, "a")))

	local basisFields = 0

	for _ in pairs(plan.basis :: any) do
		basisFields += 1
	end

	check("the basis carries all eleven written fields", basisFields == 11, tostring(basisFields))

	----------------------------------------------------------------------------
	--[[
		ELEVEN FIELDS, EACH BROKEN IN ISOLATION. `plan.nextState` replaces all
		three records wholesale, so every one of these is a field a late apply
		would overwrite. If any of them failed to invalidate the plan, that field
		could be silently reverted.
	]]
	----------------------------------------------------------------------------
	local mutations: { { name: string, apply: (TrainingAllowance.State) -> () } } = {
		{ name = "CN spentToday", apply = function(s) s.cnAllowance.spentToday += 0.001 end },
		{ name = "CN dayKey", apply = function(s) s.cnAllowance.dayKey = "1999-01-01" end },
		{ name = "CN lastUpdatedUnix", apply = function(s) s.cnAllowance.lastUpdatedUnix += 1 end },
		{ name = "technique spentToday", apply = function(s) s.techniqueAllowance.spentToday += 0.001 end },
		{ name = "technique dayKey", apply = function(s) s.techniqueAllowance.dayKey = "1999-01-01" end },
		{ name = "technique lastUpdatedUnix", apply = function(s) s.techniqueAllowance.lastUpdatedUnix += 1 end },
		{ name = "Squat hours", apply = function(s) s.trainingTimeToday.Squat += 0.001 end },
		{ name = "Bench hours", apply = function(s) s.trainingTimeToday.Bench += 0.001 end },
		{ name = "Deadlift hours", apply = function(s) s.trainingTimeToday.Deadlift += 0.001 end },
		{ name = "hours dayKey", apply = function(s) s.trainingTimeToday.dayKey = "1999-01-01" end },
		{ name = "hours lastUpdatedUnix", apply = function(s) s.trainingTimeToday.lastUpdatedUnix += 1 end },
	}

	for _, mutation in ipairs(mutations) do
		local broken = cloneState(state)

		mutation.apply(broken)

		check(
			string.format("a change to %s invalidates the plan", mutation.name),
			TrainingAllowance.matchesBasis(broken, plan) == false
		)
	end

	----------------------------------------------------------------------------
	--[[
		THE CONCRETE HARM, which the narrower basis did not catch.

		A Squat plan computed while Bench held 0 hours would, applied late, write
		Bench BACK to 0 and erase an hour banked in between. That is not a double
		spend, it is a silent revert, and it is why the basis had to widen from four
		fields to every field the plan writes.
	]]
	----------------------------------------------------------------------------
	local squatPlan = TrainingAllowance.planTraining(state, "Squat", now + 600, 600)
	local afterBench = applyPlan(TrainingAllowance.planTraining(state, "Bench", now + 600, 600))

	check("Bench banked time that the Squat plan never saw",
		afterBench.trainingTimeToday.Bench > 0,
		string.format("%.8f", afterBench.trainingTimeToday.Bench))
	check("the Squat plan is detectably stale against it",
		TrainingAllowance.matchesBasis(afterBench, squatPlan) == false)
	check("and applying it WOULD have reverted Bench to zero",
		squatPlan.nextState.trainingTimeToday.Bench == 0,
		string.format("%.8f", squatPlan.nextState.trainingTimeToday.Bench))

	-- The same holds for a technique spend made by the future 5B.7 path.
	local techniqueTouched = cloneState(state)
	techniqueTouched.techniqueAllowance.spentToday = 4.80

	check("a technique spend also invalidates a CN plan",
		TrainingAllowance.matchesBasis(techniqueTouched, squatPlan) == false)
	check("because the plan would have reverted that too",
		squatPlan.nextState.techniqueAllowance.spentToday == 0)

	-- Recomputing from the moved state produces a plan that does match.
	local recomputed = TrainingAllowance.planTraining(afterBench, "Squat", now + 1200, 600)

	check("a plan recomputed from the current state matches again",
		TrainingAllowance.matchesBasis(afterBench, recomputed))
	check("and it preserves Bench's banked hours",
		near(recomputed.nextState.trainingTimeToday.Bench, afterBench.trainingTimeToday.Bench, 0))

	checkInvariant("after the basis regression", afterBench, now + 600)
end

--------------------------------------------------------------------------------
print("")
print(string.format("=== %d passed, %d failed ===", passed, failed))

if failed > 0 then
	warn("[TrainingAllowanceProbe] THE ALLOWANCE READER HAS FAILING CHECKS. Do not build on it yet.")
else
	print("[TrainingAllowanceProbe] set ENABLED back to false now that the run is finished.")
end
