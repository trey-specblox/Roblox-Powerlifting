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

	No Competition Number is awarded by any gameplay system at present. There is
	no reward engine, no EV calculation, no Hill soft cap applied and no budget
	consumption wired to meets. This module is the foundation those will call,
	built so they do not each invent their own validation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local ResourceRegeneration = require(ProgressionFolder:WaitForChild("ResourceRegeneration"))
local CompetitionBudget = require(ProgressionFolder:WaitForChild("CompetitionBudget"))

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

	Two separate operations will be built on top of it, each owning its own
	bound, and neither exists yet:

	  1. NORMAL PROGRESSION AWARD. Takes effective EV, never kilograms, and
	     derives the delta itself:

	         deltaKg = ProgressionReference x BaseProgressRate
	                   x effectiveEV x Hill(PP)

	     Bounded by construction -- one attempt tops out near 2.7 kg and a full
	     meet's worth per lift near 8.2 kg at the largest reference -- so there
	     is nothing for a caller to get wrong. This needs the M2 Progression
	     Reference table, which is frozen in GAME_DESIGN.md section 29 but is not
	     yet in the codebase.

	  2. WEIGHT-CLASS / BUILD TRANSLATION. A deliberate authoritative
	     recalculation under RP Preservation (section 29.11), whose legitimate
	     deltas are LARGE. This is precisely why no universal kilogram cap
	     belongs here: a cap sized for rewards would refuse a correct
	     translation, and one sized for translation would not constrain rewards
	     at all.

	Until those exist, the only caller is the dev harness.

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

return ProfileOperations
