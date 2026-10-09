--!strict
--[[
	TrainingAllowance
	Shared / Progression

	The daily training allowance reader, from GAME_DESIGN.md section 34.12.

	Answers "how much may this lifter earn right now, and what would the counters
	look like afterwards" -- and answers it WITHOUT WRITING ANYTHING. Every
	function here is pure: given the same counters, the same lift, the same server
	time and the same interval, it returns the same answer, however many times it
	is called.

	=========================================================================
	PREVIEW VERSUS DEBIT -- THE DISTINCTION THIS MODULE EXISTS TO ENFORCE
	=========================================================================

	`planTraining` is a PREVIEW. It builds fresh copies of the counters, works on
	the copies, and hands back a PROPOSED replacement in `plan.nextState`. The
	tables it was given are never touched.

	Nothing is spent until a caller takes `plan.nextState` and writes it into the
	profile, which is checkpoint 5B.5's job and happens inside one
	PlayerDataService.update mutator.

	THIS IS WHY RE-READING CANNOT GRANT ANYTHING. A second preview from the same
	counters returns an identical plan rather than a second allowance, because the
	allowance only moves when the counters are replaced.

	=========================================================================
	ELAPSED TIME IS A PARAMETER, NOT DERIVED FROM lastUpdatedUnix
	=========================================================================

	This is the most important contract in the file, so it is stated before the
	code rather than after it.

	`lastUpdatedUnix` in the stored records is an AUDIT STAMP: when were these
	counters last written. It is deliberately NOT used to compute how much time to
	credit, because a profile loaded after three days offline carries a
	three-day-old stamp, and deriving the interval from it would credit three days
	of training to someone who was not there. Section 34.2 forbids offline
	progression, and the cheapest way to honour that is to make it impossible to
	express.

	So the CALLER supplies `elapsedSeconds`, and it must be time the caller
	actually observed the player connected and at the station.

	WHAT THAT REQUIRES OF CHECKPOINT 5B.6: the station measures its own tick
	interval from session-local state -- when did I last tick this player -- not
	from the profile. On a server change that measurement is lost, the next tick
	measures from the moment the player arrived, and the transfer gap credits
	nothing. Losing it is always conservative: it credits less, never more.

	THAT IS NOT A CONTRADICTION OF SECTION 34.5's "nothing lives in session
	state", and the distinction is worth being precise about. What section 34.5
	requires is that the PHASE and the ALLOWANCES be derived from persisted
	counters, so a reset, a cap crossing or a server change cannot be missed.
	"When did I last tick" is not phase and not allowance; it is a measurement,
	and the consequence of losing it is strictly in the player's disfavour.

	=========================================================================
	A UTC MIDNIGHT INSIDE THE INTERVAL IS SPLIT, NOT ROUNDED
	=========================================================================

	An interval from 23:50 to 00:10 is ten minutes of yesterday and ten minutes of
	today. Crediting all twenty to either side would be wrong in a way players
	would notice: against yesterday it would be throttled by an allowance that has
	already expired, and against today it would silently discard the pre-midnight
	half.

	So the interval is cut at every UTC midnight it contains, and each piece is
	settled against its own day -- earning against that day's remaining allowance,
	then rolling the counters over before the next piece. The pre-midnight piece
	can therefore be capped while the post-midnight piece starts from a fresh
	allowance and a fresh H(t) of 1.0.

	THE FINAL dayKey IS THE DAY OF THE LAST CREDITED PIECE, not necessarily the
	day of `nowUnix`. An interval that ends exactly at midnight describes
	yesterday, and the next read rolls it forward. `lastUpdatedUnix` is still
	stamped at `nowUnix`, because that genuinely is when the write happened.

	=========================================================================
	THE CENTRAL INVARIANT
	=========================================================================

		cnAllowance.spentToday  ==  EV(hours.Squat) + EV(hours.Bench) + EV(hours.Deadlift)

	within any single day, exactly. It holds because a lift's hour counter is only
	ever advanced by the amount that actually earned: when the account cap binds
	partway through an interval, the hours credited are the exact inverse of the
	EV allowed, so the two sides move together by construction.

	That is what makes "the cap is account-wide" and "efficiency is per lift"
	co-exist without a reconciliation step, and the probe asserts it after every
	scenario.

	=========================================================================
	A DAY KEY THAT IS IN THE FUTURE MEANS THE CLOCK WENT BACKWARD
	=========================================================================

	Rolling a day over is MONOTONE. A stored day key later than the current one
	is not a new day, it is a clock that has moved backward -- an NTP correction,
	a host reboot with a bad RTC, a misconfigured machine -- and treating it as a
	rollover would zero a spend that genuinely happened and hand out a second
	full allowance for the same day.

	So a future stored key FAILS CLOSED:

		the saved counters are preserved, never reset
		no EV is granted
		no day key is rewritten
		the plan reports `clockWentBackward` so the caller can log it

	Nothing self-heals and nothing is repaired, because there is no way to tell
	from inside this module which of the two clocks was wrong. The condition ends
	when the clock catches up to the stored day, at which point the key matches
	again and normal operation resumes by itself.

	FORWARD ROLLOVER IS UNAFFECTED. An earlier stored key is an ordinary expired
	day and still resets.

	ORDERING COMES FOR FREE FROM THE KEY FORMAT. DayKey emits zero-padded
	"YYYY-MM-DD", for which lexicographic order IS chronological order, so
	comparing two keys needs no parsing. The UNSTAMPED sentinel is an empty
	string, which sorts before every real key, so a new profile can never look
	like a future day.

	=========================================================================
	WHAT THIS MODULE CANNOT GUARANTEE -- THE 5B.5 INTEGRATION CONTRACT
	=========================================================================

	`matchesBasis` is COMPARE-AND-SET DETECTION, NOT A LOCK. This module is pure:
	it holds nothing, locks nothing, and cannot prevent another writer from moving
	the counters between the moment a plan is computed and the moment it is
	applied. It can only let the applier notice.

	ATOMICITY IS THE CALLER'S, AND IT IS ACHIEVABLE. Luau is single-threaded and
	a coroutine yields only at explicit points, so a check followed by a write
	with NO YIELD BETWEEN THEM cannot be interleaved with other Lua code.

	THE CONTRACT CHECKPOINT 5B.5 MUST HONOUR:

		1. Compute the plan.
		2. Inside ONE PlayerDataService.update mutator: call matchesBasis, and
		   only on true write all three records from plan.nextState.
		3. Between the check and the write, do not yield. No task.wait, no
		   WaitForChild, no DataStore call, no event wait, nothing that can
		   suspend the thread.
		4. On false, discard the plan and recompute from the current state.
		   Never "fix up" a stale plan.
		5. Write the Competition Number award in that SAME mutator, so the grant
		   and the debit are one profile write. Section 34.12, and the reason the
		   5B.1 notes insist a training grant is never persisted anywhere else.

	Step 3 is the part that is easy to lose later. A yield between the check and
	the write reopens exactly the hole the basis exists to close.

	=========================================================================
	SCOPE: THIS MODULE CANNOT REACH CN, TECHNIQUE STATS OR SCALE
	=========================================================================

	Its state type contains the three accounting records and nothing else, so
	there is no field through which it could modify a Competition Number, a
	technique stat or a Competition Scale even by accident. Awarding Competition
	Number is 5B.5; awarding technique points is 5B.7. Here the technique
	allowance is READ-ONLY -- remaining and rollover only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local DayKey = require(ProgressionFolder:WaitForChild("DayKey"))
local TrainingEfficiency = require(ProgressionFolder:WaitForChild("TrainingEfficiency"))

local TrainingAllowance = {}

local TRAINING = ProgressionConfig.DailyTraining

local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400

--[[
	A STRUCTURAL SANITY BOUND, NOT A BALANCE VALUE.

	No tick a station produces can legitimately cover more than a day, because the
	caller is required to pass observed-online time and a single tick spanning a
	whole day is not a measurement, it is a bug. Refusing it stops a caller
	mistake from becoming a day of free progression.

	It is NOT a tuning knob and not a limit on how long a player may train: a
	player may train all day, in as many ticks as the station takes. A tighter
	station-specific bound -- a small multiple of the tick period -- belongs in
	5B.6, which is the only layer that knows its own tick period.
]]
local MAX_ELAPSED_SECONDS = SECONDS_PER_DAY

--[[
	These two mirror PlayerProfileSchema.DailyAllowance and
	PlayerProfileSchema.TrainingTimeToday field for field.

	They are declared here rather than imported because this module lives in
	Shared and the schema lives in Server, so Shared must not require it -- the
	same reason ResourceRegeneration declares `Resource` and the schema
	re-exports it. Luau matches these structurally, so the profile's records
	satisfy these types without conversion. A later tidy-up could have the schema
	re-export these the way it already does for Resource; nothing depends on that
	happening.
]]
export type DailyAllowance = {
	spentToday: number,
	dayKey: string,
	lastUpdatedUnix: number,
}

export type TrainingTimeToday = {
	Squat: number,
	Bench: number,
	Deadlift: number,
	dayKey: string,
	lastUpdatedUnix: number,
}

--[[
	The three accounting records, and deliberately nothing else. See the scope
	note in the header.
]]
export type State = {
	cnAllowance: DailyAllowance,
	techniqueAllowance: DailyAllowance,
	trainingTimeToday: TrainingTimeToday,
}

--[[
	A FULL SNAPSHOT of everything the plan would overwrite, so a caller can prove
	the counters have not moved since it was computed.

	WHY EVERY FIELD AND NOT JUST THE SELECTED LIFT'S. `plan.nextState` replaces
	all three records WHOLESALE rather than applying a delta, so applying a stale
	plan does not merely double-spend -- it REVERTS anything another writer changed
	in between. A plan computed while Bench held 0 hours would, applied late, write
	Bench back to 0 and erase an hour someone else had just banked. The same is
	true of a technique spend made by the 5B.7 path.

	So the rule is simply: THE BASIS COVERS EVERY FIELD THE PLAN WRITES. That is
	what makes it minimal as well as robust -- there is nothing here that the plan
	does not overwrite, and nothing the plan overwrites that is missing.
]]
export type Basis = {
	cnSpentToday: number,
	cnDayKey: string,
	cnLastUpdatedUnix: number,

	techniqueSpentToday: number,
	techniqueDayKey: string,
	techniqueLastUpdatedUnix: number,

	hoursSquat: number,
	hoursBench: number,
	hoursDeadlift: number,
	hoursDayKey: string,
	hoursLastUpdatedUnix: number,
}

export type Plan = {
	-- EV actually earned, after the account cap. Never above the remaining allowance.
	earnedEV: number,
	-- Hours added to the selected lift's counter. Only the hours that earned.
	creditedHours: number,
	-- Elapsed seconds that earned nothing because the cap was already exhausted.
	uncreditedSeconds: number,
	-- True when the account cap stopped this interval short.
	capReached: boolean,
	-- How many UTC days the interval touched. 1 normally, 2 across a midnight.
	daysTouched: number,
	-- False when applying this plan would change nothing, so the write can be skipped.
	changed: boolean,
	--[[
		True when a stored day key was LATER than the day this interval starts in,
		which means the server clock moved backward. The plan is then a no-op: it
		earns nothing, resets nothing and proposes the counters unchanged. Callers
		should log it; it is an environment fault, not a player action.
	]]
	clockWentBackward: boolean,
	-- The proposed replacement records. The input is never modified.
	nextState: State,
	basis: Basis,
}

--------------------------------------------------------------------------------
-- VALIDATION
--------------------------------------------------------------------------------

local function requireFiniteNonNegative(name: string, value: any)
	assert(
		typeof(value) == "number" and value == value,
		string.format("[TrainingAllowance] %s must be a number, and not NaN", name)
	)
	assert(
		value >= 0 and value < math.huge,
		string.format("[TrainingAllowance] %s must be finite and not negative, got %s", name, tostring(value))
	)
end

--[[
	A stored counter that survived the schema's repair is a finite number of zero
	or more. Anything else means the record was not reconciled, so this refuses
	rather than guessing -- the safe failure for an allowance is to grant nothing.
]]
local function requireAllowanceRecord(name: string, record: any)
	assert(
		typeof(record) == "table",
		string.format("[TrainingAllowance] %s must be a table", name)
	)
	requireFiniteNonNegative(name .. ".spentToday", record.spentToday)
	assert(
		typeof(record.dayKey) == "string",
		string.format("[TrainingAllowance] %s.dayKey must be a string", name)
	)
end

local function requireTrainingTimeRecord(record: any)
	assert(
		typeof(record) == "table",
		"[TrainingAllowance] trainingTimeToday must be a table"
	)
	assert(
		typeof(record.dayKey) == "string",
		"[TrainingAllowance] trainingTimeToday.dayKey must be a string"
	)

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		requireFiniteNonNegative("trainingTimeToday." .. lift, (record :: any)[lift])
	end
end

--------------------------------------------------------------------------------
-- READS. All of these answer "as of nowUnix", applying the day boundary without
-- writing anything.
--------------------------------------------------------------------------------

--[[
	How a record's stored day relates to a given day key.

		"Current"  the stored day IS that day. Use the counters as they are.
		"Past"     an expired day. Roll it over and reset to zero.
		"Future"   the clock moved backward. FAIL CLOSED -- see the header.

	Lexicographic comparison is chronological because DayKey emits zero-padded
	"YYYY-MM-DD". UNSTAMPED is an empty string, which sorts before every real key,
	so a new profile reports "Past" and resets zero to zero -- which is why the
	sentinel needs no special case anywhere.

	A CORRUPT KEY THAT IS STILL A STRING sorts somewhere, and either answer is
	safe: sorting late fails closed, sorting early resets an allowance that was
	already unreadable. The schema's migration repairs non-string keys on load.
]]
export type DayStatus = "Current" | "Past" | "Future"

local function statusAgainstKey(storedDayKey: string, againstDayKey: string): DayStatus
	if storedDayKey == againstDayKey then
		return "Current"
	end

	if storedDayKey > againstDayKey then
		return "Future"
	end

	return "Past"
end

function TrainingAllowance.dayStatus(
	record: DailyAllowance | TrainingTimeToday,
	nowUnix: number
): DayStatus
	assert(typeof(record) == "table", "[TrainingAllowance] record must be a table")
	assert(
		typeof((record :: any).dayKey) == "string",
		"[TrainingAllowance] record.dayKey must be a string"
	)

	return statusAgainstKey((record :: any).dayKey, DayKey.fromUnix(nowUnix))
end

--[[
	Whether a record describes an EXPIRED day and should therefore be rolled over.

	Deliberately false for a FUTURE key. A future key is not stale data waiting to
	be reset, it is a clock fault, and resetting it is the exact harm the
	fail-closed rule exists to prevent.
]]
function TrainingAllowance.isStale(record: DailyAllowance | TrainingTimeToday, nowUnix: number): boolean
	return TrainingAllowance.dayStatus(record, nowUnix) == "Past"
end

--[[
	How much of today's allowance has been spent, which is zero once the stored
	day has ended. Reports the EFFECTIVE value rather than the stored one, so no
	caller has to remember to check staleness first.
]]
function TrainingAllowance.spentToday(record: DailyAllowance, nowUnix: number): number
	requireAllowanceRecord("record", record)

	--[[
		A PAST day is spent-nothing, because its counters have expired. A FUTURE
		day reports what is STORED, because fail-closed means preserving the saved
		counters rather than pretending they are zero.
	]]
	if TrainingAllowance.dayStatus(record, nowUnix) == "Past" then
		return 0
	end

	return record.spentToday
end

--[[
	Remaining account-wide Competition Number EV for today, in EV units.

	ACCOUNT-WIDE, NOT PER LIFT. Section 34.1 decision 2, and decision 3 removed
	the per-lift cap entirely. All three lifts draw this one number down.

	Clamped into [0, DailyCapEV]: a stored value above the cap -- which only a
	config change lowering the cap can produce -- reports zero remaining rather
	than a negative, and the player keeps whatever they already earned.
]]
function TrainingAllowance.remainingCN(cnAllowance: DailyAllowance, nowUnix: number): number
	requireAllowanceRecord("cnAllowance", cnAllowance)

	--[[
		FAIL CLOSED ON A BACKWARD CLOCK. Not `cap - spent`, which would still hand
		out whatever the stored spend left over. Nothing is earnable until the
		clock catches up to the stored day.
	]]
	if TrainingAllowance.dayStatus(cnAllowance, nowUnix) == "Future" then
		return 0
	end

	local spent = TrainingAllowance.spentToday(cnAllowance, nowUnix)
	local remaining = TRAINING.DailyCapEV - spent

	if remaining < 0 then
		return 0
	end

	return remaining
end

--[[
	Remaining account-wide AFK technique raw points for today.

	READ-ONLY IN THIS CHECKPOINT. Awarding technique is 5B.7; this exists so the
	station can tell whether the technique phase still has anything to give, and
	so the rollover is tested on the same code path as the CN allowance.
]]
function TrainingAllowance.remainingTechnique(techniqueAllowance: DailyAllowance, nowUnix: number): number
	requireAllowanceRecord("techniqueAllowance", techniqueAllowance)

	-- Same fail-closed rule as the CN allowance above.
	if TrainingAllowance.dayStatus(techniqueAllowance, nowUnix) == "Future" then
		return 0
	end

	local spent = TrainingAllowance.spentToday(techniqueAllowance, nowUnix)
	local remaining = TRAINING.DailyCapTechniqueRaw - spent

	if remaining < 0 then
		return 0
	end

	return remaining
end

--[[
	Hours of station CN training banked against one lift today, zero once the
	stored day has ended.

	THE THREE LIFTS ARE INDEPENDENT. Reading Squat says nothing about Bench, and
	the shared day key is the only thing they have in common -- they roll over
	together because they roll over with the calendar.
]]
function TrainingAllowance.hoursOnLift(
	trainingTimeToday: TrainingTimeToday,
	lift: string,
	nowUnix: number
): number
	assert(
		ProgressionConfig.isLift(lift),
		string.format("[TrainingAllowance] %s is not one of the three competition lifts", tostring(lift))
	)
	requireTrainingTimeRecord(trainingTimeToday)

	-- Past expires to zero; Future reports what is stored. See spentToday.
	if TrainingAllowance.dayStatus(trainingTimeToday, nowUnix) == "Past" then
		return 0
	end

	return (trainingTimeToday :: any)[lift]
end

--------------------------------------------------------------------------------
-- THE PLAN
--------------------------------------------------------------------------------

local function copyAllowance(record: DailyAllowance): DailyAllowance
	return {
		spentToday = record.spentToday,
		dayKey = record.dayKey,
		lastUpdatedUnix = record.lastUpdatedUnix,
	}
end

local function copyTrainingTime(record: TrainingTimeToday): TrainingTimeToday
	return {
		Squat = record.Squat,
		Bench = record.Bench,
		Deadlift = record.Deadlift,
		dayKey = record.dayKey,
		lastUpdatedUnix = record.lastUpdatedUnix,
	}
end

--[[
	Brings a working COPY onto `dayKey`, zeroing it if the stored day has ended.
	Operates on copies only; see the preview note in the header.
]]
local function rollAllowanceTo(record: DailyAllowance, dayKey: string)
	--[[
		FORWARD ONLY. Rolling to an EARLIER key would zero a later day's spend,
		which is the backward-clock harm in its subtlest form: it needs no stale
		profile, only an interval whose start the clock has moved behind the
		stored day. planTraining refuses that case outright, and this is the
		second line of defence.
	]]
	if statusAgainstKey(record.dayKey, dayKey) == "Past" then
		record.spentToday = 0
		record.dayKey = dayKey
	end
end

local function rollTrainingTimeTo(record: TrainingTimeToday, dayKey: string)
	if statusAgainstKey(record.dayKey, dayKey) == "Past" then
		for _, lift in ipairs(ProgressionConfig.Lifts) do
			(record :: any)[lift] = 0
		end
		record.dayKey = dayKey
	end
end

--[[
	Plans an interval of station training on ONE lift, without writing anything.

		state           the three accounting records, read and never modified
		lift            "Squat", "Bench" or "Deadlift"
		nowUnix         SERVER time at the END of the interval
		elapsedSeconds  observed online seconds at the station -- see the header

	Returns a Plan. `plan.nextState` is the proposed replacement; nothing is spent
	until a caller writes it.

	NEGATIVE ELAPSED TIME IS CLAMPED TO ZERO rather than refused, because a
	backward NTP step is an ordinary environmental event and not a caller bug.
	That is the same treatment ResourceRegeneration gives a backward clock, and
	the worst it can do is pause earning until the clock catches up. A negative
	starting POINT, by contrast, is corrupt data and is refused.

	WHEN THE CAP BINDS PARTWAY THROUGH, ONLY THE EARNING HOURS ARE CREDITED. The
	hours added are the exact inverse of the EV allowed, so a lift's efficiency
	clock stops precisely where its earning stopped. Standing at an exhausted
	station does not quietly consume tomorrow's full-rate window -- and that is
	also what keeps the central invariant in the header exact.
]]
function TrainingAllowance.planTraining(
	state: State,
	lift: string,
	nowUnix: number,
	elapsedSeconds: number
): Plan
	assert(
		ProgressionConfig.isLift(lift),
		string.format("[TrainingAllowance] %s is not one of the three competition lifts", tostring(lift))
	)
	assert(typeof(state) == "table", "[TrainingAllowance] state must be a table")

	requireAllowanceRecord("cnAllowance", state.cnAllowance)
	requireAllowanceRecord("techniqueAllowance", state.techniqueAllowance)
	requireTrainingTimeRecord(state.trainingTimeToday)

	requireFiniteNonNegative("nowUnix", nowUnix)

	assert(
		typeof(elapsedSeconds) == "number" and elapsedSeconds == elapsedSeconds,
		"[TrainingAllowance] elapsedSeconds must be a number, and not NaN"
	)
	assert(
		elapsedSeconds < math.huge,
		"[TrainingAllowance] elapsedSeconds must be finite"
	)
	assert(
		elapsedSeconds <= MAX_ELAPSED_SECONDS,
		string.format(
			"[TrainingAllowance] elapsedSeconds was %s, above the %d second sanity bound. A single "
				.. "tick cannot legitimately observe more than a day of training.",
			tostring(elapsedSeconds),
			MAX_ELAPSED_SECONDS
		)
	)

	-- A backward clock pauses earning; it never drains or refuses.
	local elapsed = if elapsedSeconds > 0 then elapsedSeconds else 0

	local basis: Basis = {
		cnSpentToday = state.cnAllowance.spentToday,
		cnDayKey = state.cnAllowance.dayKey,
		cnLastUpdatedUnix = state.cnAllowance.lastUpdatedUnix,

		techniqueSpentToday = state.techniqueAllowance.spentToday,
		techniqueDayKey = state.techniqueAllowance.dayKey,
		techniqueLastUpdatedUnix = state.techniqueAllowance.lastUpdatedUnix,

		hoursSquat = state.trainingTimeToday.Squat,
		hoursBench = state.trainingTimeToday.Bench,
		hoursDeadlift = state.trainingTimeToday.Deadlift,
		hoursDayKey = state.trainingTimeToday.dayKey,
		hoursLastUpdatedUnix = state.trainingTimeToday.lastUpdatedUnix,
	}

	--[[
		WORKING COPIES. Every mutation below lands on these, so an assertion
		anywhere above or a bug anywhere below cannot leave the caller's records
		half-updated. There is no partial-mutation failure mode because there is
		no mutation of the input at all.
	]]
	local nextCN = copyAllowance(state.cnAllowance)
	local nextTechnique = copyAllowance(state.techniqueAllowance)
	local nextHours = copyTrainingTime(state.trainingTimeToday)

	local startUnix = nowUnix - elapsed

	--[[
		THE BACKWARD-CLOCK GATE, and it is checked against the day the interval
		STARTS in rather than the day it ends in.

		Using the end would miss the subtler form: a stored key of D with an
		interval starting in D-1 would roll the record backward to D-1 inside the
		segment loop below, zeroing day D's spend before rolling forward again and
		handing out a fresh allowance. Checking the start catches both shapes with
		one comparison.

		An ordinary midnight span is NOT caught: an interval from D 23:50 to D+1
		00:10 starts in D, which is exactly where a correctly-stamped record
		already is.
	]]
	local startDayKeyForGate = DayKey.fromUnix(startUnix)

	local clockWentBackward = statusAgainstKey(state.cnAllowance.dayKey, startDayKeyForGate) == "Future"
		or statusAgainstKey(state.techniqueAllowance.dayKey, startDayKeyForGate) == "Future"
		or statusAgainstKey(state.trainingTimeToday.dayKey, startDayKeyForGate) == "Future"

	if clockWentBackward then
		--[[
			A FAITHFUL NO-OP. The proposed records are copies holding exactly what
			was stored, including the original timestamps, so applying this plan
			writes nothing back and `changed` is false. Nothing is reset, nothing
			is granted, and nothing is repaired.
		]]
		return {
			earnedEV = 0,
			creditedHours = 0,
			uncreditedSeconds = 0,
			capReached = false,
			daysTouched = 0,
			changed = false,
			clockWentBackward = true,
			nextState = {
				cnAllowance = nextCN,
				techniqueAllowance = nextTechnique,
				trainingTimeToday = nextHours,
			},
			basis = basis,
		}
	end

	local earnedEV = 0
	local creditedHours = 0
	local capReached = false
	local daysTouched = 0

	--[[
		THE DAY THE INTERVAL STARTS IN IS SETTLED FIRST, even when the interval is
		empty. A zero-length read on a new day therefore proposes "reset the
		counters to today", which is a no-op on the numbers and the reason an
		UNSTAMPED profile needs no special case anywhere.
	]]
	local startDayKey = DayKey.fromUnix(startUnix)

	rollAllowanceTo(nextCN, startDayKey)
	rollAllowanceTo(nextTechnique, startDayKey)
	rollTrainingTimeTo(nextHours, startDayKey)

	local cursor = startUnix

	--[[
		One iteration per UTC day the interval touches. Bounded at two by
		MAX_ELAPSED_SECONDS above; the guard is belt and braces against a future
		change to that bound.
	]]
	local guard = 0

	while cursor < nowUnix do
		guard += 1
		assert(guard <= 400, "[TrainingAllowance] day-segment loop failed to terminate")

		local dayKey = DayKey.fromUnix(cursor)
		local nextMidnight = DayKey.startOfDayUnix(cursor) + SECONDS_PER_DAY
		local segmentEnd = if nextMidnight < nowUnix then nextMidnight else nowUnix
		local segmentSeconds = segmentEnd - cursor

		-- Each piece is settled against ITS OWN day, with its own fresh allowance.
		rollAllowanceTo(nextCN, dayKey)
		rollAllowanceTo(nextTechnique, dayKey)
		rollTrainingTimeTo(nextHours, dayKey)

		local remaining = TRAINING.DailyCapEV - nextCN.spentToday

		if remaining < 0 then
			remaining = 0
		end

		local hoursBefore = (nextHours :: any)[lift] :: number
		local wantedEV = TrainingEfficiency.accrue(hoursBefore, segmentSeconds / SECONDS_PER_HOUR)

		local allowedEV = wantedEV

		if allowedEV > remaining then
			allowedEV = remaining
			capReached = true
		end

		if allowedEV > 0 then
			--[[
				THE EXACT INVERSE, not a proportion of the interval. The curve is
				not linear, so scaling the hours by allowed/wanted would credit the
				wrong amount of time whenever the cap binds mid-interval.
			]]
			local hoursCredited = TrainingEfficiency.hoursToReach(
				TrainingEfficiency.cumulativeEV(hoursBefore) + allowedEV
			) - hoursBefore

			if hoursCredited < 0 then
				-- Unreachable: the inverse is monotone. Belt and braces against float noise.
				hoursCredited = 0
			end

			;(nextHours :: any)[lift] = hoursBefore + hoursCredited
			nextCN.spentToday += allowedEV

			earnedEV += allowedEV
			creditedHours += hoursCredited
		end

		cursor = segmentEnd
		daysTouched += 1
	end

	if daysTouched == 0 then
		-- An empty interval still touches the day it sits in.
		daysTouched = 1
	end

	nextCN.lastUpdatedUnix = nowUnix
	nextTechnique.lastUpdatedUnix = nowUnix
	nextHours.lastUpdatedUnix = nowUnix

	local nextState: State = {
		cnAllowance = nextCN,
		techniqueAllowance = nextTechnique,
		trainingTimeToday = nextHours,
	}

	local uncreditedSeconds = elapsed - creditedHours * SECONDS_PER_HOUR

	if uncreditedSeconds < 0 then
		uncreditedSeconds = 0
	end

	local changed = earnedEV > 0
		or nextCN.dayKey ~= state.cnAllowance.dayKey
		or nextTechnique.dayKey ~= state.techniqueAllowance.dayKey
		or nextHours.dayKey ~= state.trainingTimeToday.dayKey
		or nextCN.spentToday ~= state.cnAllowance.spentToday
		or nextTechnique.spentToday ~= state.techniqueAllowance.spentToday
		or nextCN.lastUpdatedUnix ~= state.cnAllowance.lastUpdatedUnix

	return {
		earnedEV = earnedEV,
		creditedHours = creditedHours,
		uncreditedSeconds = uncreditedSeconds,
		capReached = capReached,
		daysTouched = daysTouched,
		changed = changed,
		clockWentBackward = false,
		nextState = nextState,
		basis = basis,
	}
end

--[[
	Whether `state` still holds exactly what `plan` was computed against.

	THE DOUBLE-SPEND GUARD, and it guards a real hole. Two training events in one
	server tick can both read the same counters and both produce a plan showing
	1.0 EV spent. Because a plan carries an ABSOLUTE next state rather than a
	delta, applying both leaves the allowance showing one spend while two
	Competition Number awards were handed out. One debit, two grants.

	So 5B.5 must check this immediately before writing, inside the same
	PlayerDataService.update mutator that performs the write, and recompute the
	plan rather than apply a stale one.

	It is cheap on purpose -- four comparisons -- because it sits on the hot path.
]]
function TrainingAllowance.matchesBasis(state: State, plan: Plan): boolean
	assert(typeof(state) == "table", "[TrainingAllowance] state must be a table")
	assert(typeof(plan) == "table" and typeof(plan.basis) == "table", "[TrainingAllowance] plan must carry a basis")

	local basis = plan.basis
	local cn = state.cnAllowance
	local technique = state.techniqueAllowance
	local hours = state.trainingTimeToday

	--[[
		EVERY FIELD THE PLAN WRITES, compared with ==. No tolerance: these are
		stored numbers being compared against copies of themselves, so an exact
		comparison is correct and a tolerance would let a real change slip past.

		It takes no `lift` argument any more. It used to check only the selected
		lift's hours, which left the other two -- and the whole technique record --
		free to be reverted by a late apply.
	]]
	return cn.spentToday == basis.cnSpentToday
		and cn.dayKey == basis.cnDayKey
		and cn.lastUpdatedUnix == basis.cnLastUpdatedUnix
		and technique.spentToday == basis.techniqueSpentToday
		and technique.dayKey == basis.techniqueDayKey
		and technique.lastUpdatedUnix == basis.techniqueLastUpdatedUnix
		and hours.Squat == basis.hoursSquat
		and hours.Bench == basis.hoursBench
		and hours.Deadlift == basis.hoursDeadlift
		and hours.dayKey == basis.hoursDayKey
		and hours.lastUpdatedUnix == basis.hoursLastUpdatedUnix
end

--[[
	The sum of EV implied by the three per-lift hour counters.

	Exposed so the invariant in the header can be checked rather than trusted:
	within a day this must equal cnAllowance.spentToday. A drift between the two
	would mean hours were credited that did not earn, or EV was spent without
	advancing a clock.
]]
function TrainingAllowance.impliedSpentEV(trainingTimeToday: TrainingTimeToday, nowUnix: number): number
	requireTrainingTimeRecord(trainingTimeToday)

	-- Past expires to zero; Future reports the stored hours. See spentToday.
	if TrainingAllowance.dayStatus(trainingTimeToday, nowUnix) == "Past" then
		return 0
	end

	local total = 0

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		total += TrainingEfficiency.cumulativeEV((trainingTimeToday :: any)[lift])
	end

	return total
end

return TrainingAllowance
