--!strict
--[[
	ProfileOperations
	Server / PlayerData

	The authoritative operations that may be performed on a player's saved data.

	WHY THIS IS A SEPARATE MODULE FROM PlayerDataService

	Everything here is a pure function of a ProfileData table plus a server
	timestamp. No Player, no ProfileStore, no sessions. That is what makes the
	rules testable: PlayerDataProbe drives whole days of regeneration and every
	rejection case in a few milliseconds, against the same code the live game
	runs, with no player in the server.

	PlayerDataService is the thin layer above this that maps a Player to their
	profile, refuses when the session is not active, and nothing else.

	EXPLICIT OPERATIONS, NOT GENERIC MUTATION

	There is deliberately no setField(path, value) here. Every function below
	expresses a legitimate thing the game may do, validates its own arguments,
	and can therefore enforce an invariant that a generic path-setter could not.
	A future reward system asks to ADD Competition Number or to SPEND budget; it
	never replaces an authoritative value outright.

	SERVER ONLY, AND NO CLIENT INPUT REACHES HERE

	This module is in ServerScriptService and creates no remotes. Every caller
	passes a server clock. No function takes a timestamp from gameplay input, and
	no function should ever be given one: see the clock notes in
	ResourceRegeneration.

	WHAT IS NOT HERE YET

	No Competition Number is awarded by any gameplay system at present. The one
	sanctioned award path, applyTrainingProgression (checkpoint 5B.5), exists
	below but has no gameplay caller: the gym station that will drive it is
	checkpoint 5B.6. No budget consumption is wired to meets.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local ResourceRegeneration = require(ProgressionFolder:WaitForChild("ResourceRegeneration"))
local CompetitionBudget = require(ProgressionFolder:WaitForChild("CompetitionBudget"))
local CompetitionNumberReward = require(ProgressionFolder:WaitForChild("CompetitionNumberReward"))
local TrainingAllowance = require(ProgressionFolder:WaitForChild("TrainingAllowance"))
local WeightClass = require(ProgressionFolder:WaitForChild("WeightClass"))

local PlayerProfileSchema = require(script.Parent.PlayerProfileSchema)

local ProfileOperations = {}

type ProfileData = PlayerProfileSchema.ProfileData

--[[
	=========================================================================
	TWO RESOURCES, TWO DELIBERATELY DIFFERENT SPENDING SEMANTICS
	=========================================================================

	These must not be made to behave alike. The difference is a frozen design
	rule, not an implementation detail.

	COMPETITION BUDGET -- CONSUMPTION CANNOT FAIL ON AMOUNT.

		There is no floor and no "insufficient budget". Once the allowance is
		spent the pool goes negative and progression continues at a diminishing
		multiplier, because section 29.9 freezes that active meet progression is
		never hard-zeroed. A player at the keyboard must never be told their
		effort was worth nothing.

		consumeCompetitionBudget returns the EFFECTIVE EV earned, which falls
		toward zero without reaching it. It fails only on a malformed request:
		an unknown lift, a corrupt pool, or a non-finite or non-positive EV.

	TRAINING ENERGY -- CONSUMPTION FAILS WHEN SHORT.

		It floors at zero and is all-or-nothing. At empty, passive AFK
		Competition Number stops; there is no overflow. This is the asymmetry
		that holds the intended ratio of roughly 0.25x the reference active
		rate, and it is correct precisely BECAUSE the player is not at the
		keyboard to be discouraged.

	So: a budget call returns "here is what you earned", possibly very little.
	An energy call returns "yes" or "no".
	=========================================================================

	ON VALIDATING THE SIZE OF A COMPETITION NUMBER AWARD

	There is deliberately no maximum-delta constant here. An earlier draft
	capped a single add at 100 kg, which was an implementation judgement dressed
	as a rule: it appears nowhere in GAME_DESIGN.md, and it would have let any
	caller award 100 kg at a stroke while rejecting a legitimate larger
	weight-class translation.

	The real bound is derivable, but only by the reward engine, which alone
	knows what it is paying for:

		maximum legitimate award = ProgressionReference x BaseProgressRate
		                           x EV x Hill(PP)

	A single attempt tops out near 2.7 kg and a full meet's worth near 8.2 kg at
	the largest reference. The foundation cannot tell those apart, so it enforces
	only what is universally true -- finite, and a result that remains a positive
	weight -- and the derived bound is applied where the delta is computed.
]]

--[[
	True for a number that is safe to store and to do arithmetic with.

	Rejects NaN and both infinities. NaN is the dangerous one: it propagates
	silently through every later addition and comparison, so a single NaN write
	permanently poisons a stat.
]]
local function isFiniteNumber(value: any): boolean
	if typeof(value) ~= "number" then
		return false
	end

	-- NaN is the only value not equal to itself.
	if value ~= value then
		return false
	end

	return value ~= math.huge and value ~= -math.huge
end

ProfileOperations.isFiniteNumber = isFiniteNumber

--[[
	=========================================================================
	COMPETITION NUMBER
	=========================================================================
]]

--[[
	The player's Competition Number for one lift, in kilograms, or nil if the
	lift name is not one of the three or the stored value is unusable.
]]
function ProfileOperations.getCompetitionNumber(data: ProfileData, lift: string): number?
	if not ProgressionConfig.isLift(lift) then
		return nil
	end

	local value = (data.competitionNumber :: any)[lift]

	if not isFiniteNumber(value) then
		return nil
	end

	return value
end

--[[
	THE FOUNDATION PRIMITIVE FOR CHANGING A COMPETITION NUMBER.

	NOT A REWARD API, AND NOT EXPOSED ON PlayerDataService. Nothing in gameplay
	may reach this, because it accepts an arbitrary kilogram delta and so cannot
	by itself tell a 1.4 kg attempt reward from a 300 kg mistake.

	Two separate operations are built on top of it, each owning its own bound:

	  1. TRAINING PROGRESSION AWARD -- applyTrainingProgression, below. Takes
	     observed station seconds, never EV and never kilograms, and derives
	     both itself:

	         earnedEV = TrainingAllowance plan (H(t), clamped to the 4.00 EV cap)
	         deltaKg  = ProgressionReference x BaseProgressRate
	                    x earnedEV x Hill(PP)

	     Bounded by construction, so there is nothing for a caller to get
	     wrong. Implemented in checkpoint 5B.5.

	  2. WEIGHT-CLASS / BUILD TRANSLATION. A deliberate authoritative
	     recalculation under RP Preservation (section 29.11), whose legitimate
	     deltas are LARGE. This is precisely why no universal kilogram cap
	     belongs here: a cap sized for rewards would refuse a correct
	     translation, and one sized for translation would not constrain rewards
	     at all. Not built yet.

	The training award and the dev harness are its only callers.

	Returns whether it was applied and the resulting value. A rejection changes
	nothing, so a caller cannot half-apply a change.

	DELTA ONLY. There is no setCompetitionNumber, because an absolute setter is
	the shape a compromised or buggy caller could use to write any value at all.
	A Competition Number moves by deltas the server computed.

	Rejects:
	  - a lift that is not Squat, Bench or Deadlift
	  - a non-finite delta, which includes NaN and both infinities
	  - any delta that would drive the number to zero or below, because a
	    Competition Number of zero means "cannot lift" and the difficulty engine
	    divides by it
	  - a stored value that is already unusable, which is repaired by migration
	    rather than written over here

	It does NOT bound the magnitude. See the note above on why that bound
	belongs to the reward engine rather than here.

	A NEGATIVE DELTA IS ALLOWED. Nothing in the frozen design reduces a
	Competition Number today, but the bodyweight and weight-class translation of
	section 29.11 legitimately will, and it is better that it come through this
	validated path than around it.
]]
function ProfileOperations.applyCompetitionNumberDelta(
	data: ProfileData,
	lift: string,
	deltaKg: number
): (boolean, number?)
	if not ProgressionConfig.isLift(lift) then
		return false, nil
	end

	if not isFiniteNumber(deltaKg) then
		return false, nil
	end

	local current = (data.competitionNumber :: any)[lift]

	if not isFiniteNumber(current) then
		return false, nil
	end

	local updated = current + deltaKg

	--[[
		Re-checked after the addition. Two finite numbers can sum to infinity,
		and the result still has to be a weight the engine can divide by.
	]]
	if not isFiniteNumber(updated) or updated <= 0 then
		return false, current
	end

	(data.competitionNumber :: any)[lift] = updated

	return true, updated
end

--[[
	=========================================================================
	COMPETITION SCALE  (GAME_DESIGN.md section 33)
	=========================================================================

	Competition Scale is the heaviest weight the lifter has actually proven in an
	eligible meet. Competition Number is what training built; this is what
	competition confirmed.

	Two readers and one monotone raise live below. The raise is INTERNAL and has
	NO PRODUCTION CALLERS -- read the boundary note on it before wiring anything
	to it, because the thing it does not do is the important part.
]]

--[[
	The player's Competition Scale for one lift, in kilograms.

	Returns `PlayerProfileSchema.UNPROVEN_SCALE` (0) when the lift has never
	been proven, which is every player today. Returns nil only when the lift
	name is not one of the three or the stored value is unusable.

	A CALLER MUST NOT TREAT 0 AS A WEIGHT. It is the absence of an achievement,
	not a 0 kg lift. Use isCompetitionScaleProven to tell them apart.
]]
function ProfileOperations.getCompetitionScale(data: ProfileData, lift: string): number?
	if not ProgressionConfig.isLift(lift) then
		return nil
	end

	local value = (data.competitionScale :: any)[lift]

	if not isFiniteNumber(value) or value < 0 then
		return nil
	end

	return value
end

--[[
	Whether this lift has ever been successfully proven in an eligible meet.

	False for a brand new player, for every profile migrated from version 3, and
	whenever the stored value is unusable. A corrupt Scale reads as unproven
	rather than as an achievement, because the safe failure is to under-credit.
]]
function ProfileOperations.isCompetitionScaleProven(data: ProfileData, lift: string): boolean
	local value = ProfileOperations.getCompetitionScale(data, lift)
	return value ~= nil and value > PlayerProfileSchema.UNPROVEN_SCALE
end

--[[
	What a raise attempt did.

		"Raised"     the stored Scale increased to provenKg
		"Unchanged"  the input was valid but not heavier than what is stored
		"Rejected"   the input or the stored value was unusable; nothing written

	"Unchanged" is a SUCCESS, not a failure. A lifter who opens at 150 kg when
	they have already proven 180 kg made a perfectly legal lift that simply does
	not move their best. Collapsing that into a boolean alongside "Rejected"
	would make a routine opener indistinguishable from a malformed request, and
	a future meet handler needs to tell those apart to log one and alert on the
	other.
]]
export type ScaleRaiseOutcome = "Raised" | "Unchanged" | "Rejected"

--[[
	THE MONOTONE COMPETITION SCALE RAISE, from GAME_DESIGN.md section 33.7.

		New Scale = max(Old Scale, provenKg)

	=========================================================================
	SECURITY BOUNDARY -- READ THIS BEFORE GIVING IT A CALLER
	=========================================================================

	THIS FUNCTION DOES NOT VERIFY THAT A MEET HAPPENED. It cannot. It receives a
	kilogram number and a lift name, and it has no way to know whether that
	weight was ever on a bar, whether the attempt was judged a good lift,
	whether the meet was eligible, or which weight class the lifter was in. It
	is a low-level data transformation, NOT proof of an achievement.

	Everything it does not check is therefore the CALLER's responsibility, and
	only one kind of caller may ever exist: a future server-authoritative
	meet-result handler that has already established all of the following.

	  1. The attempt was actually taken in a meet this server was running.
	  2. The attempt was judged a GOOD LIFT. A failed attempt may never raise
	     Scale at any weight (section 33.6). `MeetTotal.bestSuccessful` is the
	     right source: it filters on result == "GoodLift" and returns the
	     heaviest, so a failure cannot reach this function through it.
	  3. The meet was ELIGIBLE under section 33.7. Solo and Official both
	     qualify; what else does is still [TBD].
	  4. THE WEIGHT CLASS MATCHES THE BUILD BEING CREDITED. See below.

	NO CLIENT, REMOTE, DEV TRIGGER OR EXISTING GAMEPLAY SYSTEM MAY REACH THIS.
	A client-supplied weight arriving here would let a player write their own
	proven strength, which is the single worst thing that could happen to this
	field. It is not exposed on PlayerDataService, so the gateway every gameplay
	system actually uses has no path to it.

	=========================================================================
	WHY IT HAS NO PRODUCTION CALLER YET, AND MUST NOT GET ONE
	=========================================================================

	Competition Scale is stored FLAT, one value per lift, because the
	Weight-Class Build Slot system does not exist (section 33.8). A flat store
	cannot express "proven in the 83 kg class", so a raise written today would
	credit the player's only build whatever class they weighed in at -- and a
	Scale proven in one class is NOT proof in another.

	That is unreachable right now because nothing calls this. It becomes
	reachable the moment a meet can. So section 33.12 step 7 is blocked on
	class-scoped build storage existing first, and this function must stay
	caller-free until then. Tested: PlayerDataProbe asserts no gameplay module
	can reach it.

	=========================================================================

	PURE AND DETERMINISTIC. No clock, no Player, no ProfileStore, no randomness.
	Same profile and same arguments always give the same result, which is what
	lets the probe drive every branch in microseconds against the real code.

	Returns (outcome, resultingScaleKg). The number is the Scale AFTER the call
	for "Raised" and "Unchanged", and nil for "Rejected" -- because a rejection
	establishes nothing, and handing back a number there invites a caller to
	treat a refused write as a value worth storing or displaying.
]]
function ProfileOperations.raiseCompetitionScale(
	data: ProfileData,
	lift: string,
	provenKg: number
): (ScaleRaiseOutcome, number?)
	if not ProgressionConfig.isLift(lift) then
		return "Rejected", nil
	end

	--[[
		A PROVEN WEIGHT MUST BE A REAL WEIGHT: finite, and strictly above zero.

		Zero is rejected rather than treated as a no-op. It is the UNPROVEN
		sentinel, and no bar is ever loaded to 0 kg, so a 0 arriving here means
		the caller has a bug -- most likely passing an absent value through.
		Saying so is more useful than silently doing nothing.

		Negatives, NaN and both infinities are rejected for the same reason.
		NaN is the dangerous one: `math.max(nan, x)` is implementation-defined
		and a NaN reaching the profile would poison every later comparison on a
		field that is supposed to only ever rise.
	]]
	if not isFiniteNumber(provenKg) or provenKg <= 0 then
		return "Rejected", nil
	end

	local current = ProfileOperations.getCompetitionScale(data, lift)

	--[[
		A CORRUPT STORED SCALE IS REFUSED, NOT REPAIRED.

		If the stored value is unusable we cannot know whether it was higher
		than provenKg, so writing would be guessing at a proven achievement.
		Repair is the migration's job, and it already does exactly this on every
		load: PlayerProfileSchema.migrations[3] replaces a malformed Scale with
		UNPROVEN. Doing it here as well would hide the corruption instead of
		letting a reload clean it up.
	]]
	if current == nil then
		return "Rejected", nil
	end

	--[[
		MONOTONE. A lower or equal weight leaves the record exactly as it was.
		Written as an explicit comparison rather than math.max so that the
		"nothing was written" case is a real branch that can be asserted,
		rather than a redundant assignment of the same number.
	]]
	if provenKg <= current then
		return "Unchanged", current
	end

	(data.competitionScale :: any)[lift] = provenKg

	return "Raised", provenKg
end

--[[
	=========================================================================
	COMPETITION BUDGET  (three pools, account-wide per lift)
	=========================================================================
]]

local BUDGET = ProgressionConfig.CompetitionBudget

--[[
	The budget pool table for one lift, or nil if the name or shape is wrong.
]]
local function budgetPool(data: ProfileData, lift: string): PlayerProfileSchema.Resource?
	if not ProgressionConfig.isLift(lift) then
		return nil
	end

	local pool = (data.competitionBudget :: any)[lift]

	if typeof(pool) ~= "table" then
		return nil
	end

	return pool
end

--[[
	One lift's Competition Budget as it stands right now, in EV units, WITHOUT
	writing anything.

	The returned value includes everything that regenerated since the pool was
	last touched, including while the player was offline. A negative result means
	the player is in harmonic overflow for that lift, and the magnitude is how
	deep.

	Named to match the frozen design's vocabulary: this is the regenerated value,
	never the stale stored one.
]]
function ProfileOperations.getRegeneratedCompetitionBudget(
	data: ProfileData,
	lift: string,
	nowUnix: number
): number?
	local pool = budgetPool(data, lift)
	if pool == nil then
		return nil
	end

	return ResourceRegeneration.current(pool, nowUnix, BUDGET.CapacityEV, BUDGET.RegenerationEVPerHour)
end

--[[
	The multiplier progression would receive on this lift right now, and the
	player-facing freshness state. Reads without writing.

	The multiplier is the INSTANTANEOUS rate. An award spans a range of overflow
	depths, so its actual scaling comes from consumeCompetitionBudget, not from
	multiplying by this.
]]
function ProfileOperations.getCompetitionBudgetState(
	data: ProfileData,
	lift: string,
	nowUnix: number
): (number?, number?, string?)
	local amount = ProfileOperations.getRegeneratedCompetitionBudget(data, lift, nowUnix)
	if amount == nil then
		return nil, nil, nil
	end

	return amount, CompetitionBudget.multiplierAt(amount), CompetitionBudget.freshness(amount)
end

--[[
	Consumes `rawEV` of progression from one lift's Competition Budget and
	returns the EFFECTIVE EV it earned.

	THIS CANNOT FAIL ON AMOUNT, unlike Training Energy. See the semantics note at
	the top of this file. The returned effective EV falls toward zero as overflow
	deepens but never reaches it, so legitimate progression always pays
	something. Failure means the REQUEST was malformed: an unknown lift, a
	corrupt pool, or a non-finite or non-positive rawEV.

	Returns (effectiveEV, remainingAmount), or nil on a malformed request.

	SPENDING ONE LIFT LEAVES THE OTHER TWO UNTOUCHED. That is the whole point of
	three pools rather than one: see the note in ProgressionConfig.

	The state advances by the RAW EV, never the effective EV, which is what makes
	overflow actually diminish. Raw EV already encodes whatever the caller
	decided the event was worth, and the effective-per-raw ratio at a given state
	does not depend on the magnitude consumed, so an award cannot be gamed by
	splitting or sizing it. Under GAME_DESIGN.md section 33.6 a failed attempt is
	worth zero raw EV, so it consumes nothing and awards nothing.

	Nothing here knows what a meet is. No meet or attempt count is read or
	stored.
]]
function ProfileOperations.consumeCompetitionBudget(
	data: ProfileData,
	lift: string,
	rawEV: number,
	nowUnix: number
): (number?, number?)
	local pool = budgetPool(data, lift)
	if pool == nil then
		return nil, nil
	end

	if not isFiniteNumber(rawEV) or rawEV <= 0 then
		--[[
			A zero or negative award is a caller bug, not a refund. Section 29.9:
			leaving a meet or disconnecting consumes exactly what was earned and
			is never given back.
		]]
		return nil, nil
	end

	local effective, remaining = CompetitionBudget.consume(pool, nowUnix, rawEV)

	return effective, remaining
end

--[[
	=========================================================================
	TRAINING ENERGY  (account-wide, passive AFK Competition Number only)
	=========================================================================

	NOTHING HERE MAY BE WIRED TO MUSCLE. Section 29.8 is explicit: Training
	Energy limits passive AFK Competition Number and never limits Muscle, which
	progresses independently and continues when this is empty.
]]

local ENERGY = ProgressionConfig.TrainingEnergy

--[[
	Training Energy in minutes as it stands right now, WITHOUT writing anything.

	Includes offline regeneration, per section 29.8.
]]
function ProfileOperations.getRegeneratedTrainingEnergy(data: ProfileData, nowUnix: number): number?
	local energy = data.trainingEnergy

	if typeof(energy) ~= "table" then
		return nil
	end

	return ResourceRegeneration.current(
		energy,
		nowUnix,
		ENERGY.CapacityMinutes,
		ENERGY.RegenerationMinutesPerHour
	)
end

--[[
	Spends `minutes` of Training Energy.

	Returns whether it was spent and what remains.

	UNLIKE THE COMPETITION BUDGET, THIS CANNOT GO BELOW ZERO. At empty, passive
	AFK Competition Number stops; there is no overflow. The asymmetry is
	deliberate and is explained in ProgressionConfig: a player at the keyboard
	must never be told their effort is worth nothing, whereas a hard allowance on
	passive gain is what holds the intended ratio.
]]
function ProfileOperations.consumeTrainingEnergy(
	data: ProfileData,
	minutes: number,
	nowUnix: number
): (boolean, number?)
	local energy = data.trainingEnergy

	if typeof(energy) ~= "table" then
		return false, nil
	end

	local spent, remaining = ResourceRegeneration.trySpend(
		energy,
		nowUnix,
		ENERGY.CapacityMinutes,
		ENERGY.RegenerationMinutesPerHour,
		minutes,
		ENERGY.MinimumMinutes
	)

	return spent, remaining
end

--[[
	=========================================================================
	GYM-STATION TRAINING PROGRESSION  (GAME_DESIGN.md section 34, checkpoint 5B.5)
	=========================================================================

	The ONLY operation that awards Competition Number. It debits the daily
	training accounting and awards the CN that debit paid for, together.

	THE COMPETITION BUDGET AND TRAINING ENERGY ARE NOT TOUCHED. Section 34.12,
	decision A: the account-wide 4.00 EV daily allowance is training's only
	throttle. The budget pools and Training Energy stay exactly as stored.
]]

--[[
	What a training update did.

		"Awarded"            EV was earned: CN rose and the accounting was written
		"NoProgress"         valid, but nothing was earned -- cap already spent,
		                     zero or negative elapsed time. CN is unchanged; the
		                     accounting is still written, so a day rollover and
		                     the audit stamp land
		"ClockWentBackward"  a stored day key is later than the interval's start.
		                     NOTHING is written, and nothing is granted
		"Rejected"           the request or the stored data was unusable.
		                     NOTHING is written. `rejectionReason` says why
]]
export type TrainingOutcome = "Awarded" | "NoProgress" | "ClockWentBackward" | "Rejected"

export type TrainingRejectionReason =
	"InvalidLift"
	| "InvalidTime"
	| "InvalidElapsed"
	| "InvalidBodyweight"
	-- No configured Progression Reference for this lift and class, 120+ included. Decision C.
	| "UnsupportedClass"
	| "InvalidCompetitionNumber"
	| "InvalidAccounting"
	| "StalePlan"
	| "InvariantViolated"
	| "AwardRefused"

export type TrainingResult = {
	outcome: TrainingOutcome,
	rejectionReason: TrainingRejectionReason?,

	lift: string,
	weightClassLabel: string?,

	-- EV the allowance granted this update. Already clamped to the daily cap.
	earnedEV: number,
	creditedHours: number,
	uncreditedSeconds: number,
	capReached: boolean,
	daysTouched: number,

	competitionNumberBefore: number?,
	competitionNumberAfter: number?,
	deltaCN: number,
	hillMultiplier: number?,
}

local TRAINING = ProgressionConfig.DailyTraining

--[[
	Tolerance for the post-plan invariant checks only. These compare sums of
	floats the plan produced; they never decide an amount.
]]
local INVARIANT_EPSILON = 1e-9

-- A result in which nothing was earned and nothing was written.
local function unchangedTrainingResult(
	lift: any,
	outcome: TrainingOutcome,
	reason: TrainingRejectionReason?
): TrainingResult
	return {
		outcome = outcome,
		rejectionReason = reason,

		lift = if typeof(lift) == "string" then lift else tostring(lift),
		weightClassLabel = nil,

		earnedEV = 0,
		creditedHours = 0,
		uncreditedSeconds = 0,
		capReached = false,
		daysTouched = 0,

		competitionNumberBefore = nil,
		competitionNumberAfter = nil,
		deltaCN = 0,
		hillMultiplier = nil,
	}
end

local function trainingRejection(lift: any, reason: TrainingRejectionReason): TrainingResult
	return unchangedTrainingResult(lift, "Rejected", reason)
end

local function isUsableAccountingNumber(value: any): boolean
	return isFiniteNumber(value) and value >= 0
end

--[[
	Every field the plan reads or writes, checked here so a corrupt record is a
	clean "InvalidAccounting" rather than an assert inside TrainingAllowance.
	migrations[4] repairs all of these on load, so failing here means something
	wrote garbage mid-session.
]]
local function isUsableAllowanceRecord(record: any): boolean
	return typeof(record) == "table"
		and isUsableAccountingNumber(record.spentToday)
		and typeof(record.dayKey) == "string"
		and isUsableAccountingNumber(record.lastUpdatedUnix)
end

local function isUsableTrainingTimeRecord(record: any): boolean
	if typeof(record) ~= "table" then
		return false
	end

	if typeof(record.dayKey) ~= "string" or not isUsableAccountingNumber(record.lastUpdatedUnix) then
		return false
	end

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		if not isUsableAccountingNumber(record[lift]) then
			return false
		end
	end

	return true
end

local function writeAllowanceInPlace(target: PlayerProfileSchema.DailyAllowance, source: TrainingAllowance.DailyAllowance)
	target.spentToday = source.spentToday
	target.dayKey = source.dayKey
	target.lastUpdatedUnix = source.lastUpdatedUnix
end

local function writeTrainingTimeInPlace(
	target: PlayerProfileSchema.TrainingTimeToday,
	source: TrainingAllowance.TrainingTimeToday
)
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		(target :: any)[lift] = (source :: any)[lift]
	end

	target.dayKey = source.dayKey
	target.lastUpdatedUnix = source.lastUpdatedUnix
end

--[[
	Applies `elapsedSeconds` of gym-station training on `lift` to a profile:
	plans the daily allowance, derives the earned EV and the Competition Number
	it buys, and writes both together.

		data            the live profile
		lift            "Squat", "Bench" or "Deadlift"
		nowUnix         SERVER time at the end of the interval
		elapsedSeconds  ACTIVE, SERVER-OBSERVED station time. Never derived from
		                lastUpdatedUnix -- a profile's stamp after a day offline
		                is a day old, and crediting it would be offline
		                progression (section 34.2). See TrainingAllowance.

	Returns a TrainingResult. Never throws on bad input or bad stored data.

	=========================================================================
	ATOMIC: ALL OF IT OR NONE OF IT
	=========================================================================

	The function runs in three phases, and nothing is written until the third.

	  1. VALIDATE. Lift, clock, elapsed time, bodyweight, weight class, the
	     incoming CN and all three accounting records. Any failure returns
	     "Rejected" with the profile untouched.

	  2. PLAN. The allowance plan and the CN award are both computed against
	     the profile AS IT IS NOW, on copies. Then the plan is checked against
	     the live records (matchesBasis) and against the reward/debit invariant.
	     Any failure returns with the profile untouched.

	  3. COMMIT. The CN delta first, through applyCompetitionNumberDelta, which
	     writes nothing when it refuses. Then the three accounting records, as
	     plain assignments into tables already validated in phase 1, which
	     cannot fail.

	NO YIELD ANYWHERE. Nothing here waits, calls a DataStore or touches an
	Instance, so from the first read to the last write no other Lua code can
	run. That is what makes the basis check meaningful: the plan cannot go
	stale between being checked and being written.

	ONE PROFILE TABLE. The debit and the award land in the same profile.Data,
	which ProfileStore saves as one unit. A crash before the next save loses
	both together; it can never keep one without the other.
]]
function ProfileOperations.applyTrainingProgression(
	data: ProfileData,
	lift: string,
	nowUnix: number,
	elapsedSeconds: number
): TrainingResult
	--------------------------------------------------------------------------
	-- PHASE 1: VALIDATE. Nothing below writes until phase 3.
	--------------------------------------------------------------------------

	if not ProgressionConfig.isLift(lift) then
		return trainingRejection(lift, "InvalidLift")
	end

	if not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return trainingRejection(lift, "InvalidTime")
	end

	--[[
		NEGATIVE ELAPSED TIME IS ALLOWED THROUGH and earns nothing: the
		allowance reader clamps it to zero, the same treatment it gives a
		backward clock step. NaN, either infinity, a non-number and anything
		over a day are refused.
	]]
	if not isFiniteNumber(elapsedSeconds) or elapsedSeconds > TrainingAllowance.MAX_ELAPSED_SECONDS then
		return trainingRejection(lift, "InvalidElapsed")
	end

	local bodyweight = (data :: any).bodyweight
	local bodyweightKg = if typeof(bodyweight) == "table" then bodyweight.currentKg else nil

	if not isFiniteNumber(bodyweightKg) or bodyweightKg <= 0 then
		return trainingRejection(lift, "InvalidBodyweight")
	end

	local weightClassLabel = WeightClass.resolve(bodyweightKg).label

	local competitionNumberBefore = ProfileOperations.getCompetitionNumber(data, lift)

	if competitionNumberBefore == nil or competitionNumberBefore <= 0 then
		return trainingRejection(lift, "InvalidCompetitionNumber")
	end

	--[[
		A ZERO-EV DRY RUN of the award, which validates the class and the CN
		exactly the way the real award will. Done BEFORE planning so that an
		unsupported class rejects the whole update -- decision C -- even on a
		tick that would have earned nothing. A class with no configured
		reference must not spend allowance it can never turn into CN.
	]]
	local _, dryRunRejection = CompetitionNumberReward.calculateTrainingAward(
		lift,
		weightClassLabel,
		competitionNumberBefore,
		0
	)

	if dryRunRejection ~= nil then
		if dryRunRejection == "InvalidCompetitionNumber" then
			return trainingRejection(lift, "InvalidCompetitionNumber")
		end

		return trainingRejection(lift, "UnsupportedClass")
	end

	if
		not isUsableAllowanceRecord(data.cnAllowance)
		or not isUsableAllowanceRecord(data.techniqueAllowance)
		or not isUsableTrainingTimeRecord(data.trainingTimeToday)
	then
		return trainingRejection(lift, "InvalidAccounting")
	end

	--------------------------------------------------------------------------
	-- PHASE 2: PLAN, against the profile as it is now. Still nothing written.
	--------------------------------------------------------------------------

	local state: TrainingAllowance.State = {
		cnAllowance = data.cnAllowance,
		techniqueAllowance = data.techniqueAllowance,
		trainingTimeToday = data.trainingTimeToday,
	}

	--[[
		planTraining is pure and never touches `state`; pcall turns any assert it
		still raises into a clean rejection. pcall does not yield.
	]]
	local planned, planOrError = pcall(TrainingAllowance.planTraining, state, lift, nowUnix, elapsedSeconds)

	if not planned then
		return trainingRejection(lift, "InvalidAccounting")
	end

	local plan: TrainingAllowance.Plan = planOrError

	if plan.clockWentBackward then
		-- Fail closed: the stored counters stand, nothing is granted or written.
		local result = unchangedTrainingResult(lift, "ClockWentBackward", nil)

		result.weightClassLabel = weightClassLabel
		result.competitionNumberBefore = competitionNumberBefore
		result.competitionNumberAfter = competitionNumberBefore

		return result
	end

	--[[
		THE STALE-PLAN GUARD. The plan was computed from these very records a
		moment ago with nothing in between, so this cannot fail today. It stays
		because it is the check that keeps holding if someone later puts a yield
		between planning and committing. A mismatch is refused, never patched.
	]]
	if not TrainingAllowance.matchesBasis(state, plan) then
		return trainingRejection(lift, "StalePlan")
	end

	--[[
		THE REWARD/DEBIT INVARIANT. The EV the CN award is paid for must be the
		EV the allowance was debited by, and the allowance must stay in bounds.
	]]
	local earnedEV = plan.earnedEV
	local nextCN = plan.nextState.cnAllowance
	local nextHours = plan.nextState.trainingTimeToday

	if not isUsableAccountingNumber(earnedEV) then
		return trainingRejection(lift, "InvariantViolated")
	end

	if not isUsableAccountingNumber(nextCN.spentToday) or nextCN.spentToday > TRAINING.DailyCapEV + INVARIANT_EPSILON then
		return trainingRejection(lift, "InvariantViolated")
	end

	local expectedSpent = if nextCN.dayKey == data.cnAllowance.dayKey
		then data.cnAllowance.spentToday + earnedEV
		else nil

	if expectedSpent ~= nil and math.abs(nextCN.spentToday - expectedSpent) > INVARIANT_EPSILON then
		-- Same day: the debit must equal the EV earned, exactly up to float noise.
		return trainingRejection(lift, "InvariantViolated")
	end

	if expectedSpent == nil and nextCN.spentToday > earnedEV + INVARIANT_EPSILON then
		-- Rolled over: today's spend can only be what this update earned after midnight.
		return trainingRejection(lift, "InvariantViolated")
	end

	for _, liftName in ipairs(ProgressionConfig.Lifts) do
		if not isUsableAccountingNumber((nextHours :: any)[liftName]) then
			return trainingRejection(lift, "InvariantViolated")
		end
	end

	local award: CompetitionNumberReward.TrainingAward? = nil

	if earnedEV > 0 then
		local calculated, _ = CompetitionNumberReward.calculateTrainingAward(
			lift,
			weightClassLabel,
			competitionNumberBefore,
			earnedEV
		)

		if calculated == nil then
			return trainingRejection(lift, "AwardRefused")
		end

		-- Positive EV must buy positive CN, or EV would be spent for nothing.
		if not (calculated.deltaCN > 0) then
			return trainingRejection(lift, "InvariantViolated")
		end

		award = calculated
	end

	--------------------------------------------------------------------------
	-- PHASE 3: COMMIT. No yields, and nothing after the CN write can fail.
	--------------------------------------------------------------------------

	local competitionNumberAfter = competitionNumberBefore

	if award ~= nil then
		-- Writes nothing when it refuses, so a refusal here leaves the profile untouched.
		local applied, value = ProfileOperations.applyCompetitionNumberDelta(data, lift, award.deltaCN)

		if not applied or value == nil then
			return trainingRejection(lift, "AwardRefused")
		end

		competitionNumberAfter = value
	end

	writeAllowanceInPlace(data.cnAllowance, plan.nextState.cnAllowance)
	writeAllowanceInPlace(data.techniqueAllowance, plan.nextState.techniqueAllowance)
	writeTrainingTimeInPlace(data.trainingTimeToday, plan.nextState.trainingTimeToday)

	return {
		outcome = if award ~= nil then "Awarded" else "NoProgress",
		rejectionReason = nil,

		lift = lift,
		weightClassLabel = weightClassLabel,

		earnedEV = earnedEV,
		creditedHours = plan.creditedHours,
		uncreditedSeconds = plan.uncreditedSeconds,
		capReached = plan.capReached,
		daysTouched = plan.daysTouched,

		competitionNumberBefore = competitionNumberBefore,
		competitionNumberAfter = competitionNumberAfter,
		deltaCN = if award ~= nil then award.deltaCN else 0,
		hillMultiplier = if award ~= nil then award.hillMultiplier else nil,
	}
end

return ProfileOperations
