--!strict
--[[
	CompetitionNumberReward
	Shared / Progression

	The authoritative Competition Number reward calculation, from
	GAME_DESIGN.md section 29.

		Competition Number
		  -> Progression Proximity (PP)
		  -> Hill soft cap
		  -> raw EV
		  -> Competition Budget
		  -> effective EV
		  -> delta Competition Number

	=========================================================================
	PURE. IT CALCULATES AND NEVER MUTATES.
	=========================================================================

	calculate() takes authoritative state and returns a result. It writes
	nothing: no profile, no resource, no timestamp. The budget amount comes in
	as a number and the new amount goes out as a number.

	That separation is the point. A future server-authoritative operation can
	compute an award, inspect it, log it, and only then apply it through
	ProfileOperations -- or discard it. Nothing here can half-apply anything,
	because nothing here applies anything.

	NOTHING IN GAMEPLAY CALLS THIS YET. No attempt, meet, daily or AFK tick
	awards Competition Number. This increment proves the arithmetic.

	=========================================================================
	EVERY INPUT IS SERVER-DERIVED
	=========================================================================

	The client may never supply, and this module never accepts from a client:
	final CN, delta CN, PP, the Hill multiplier, effective EV, the budget
	amount, or a timestamp. There is no timestamp parameter at all -- budget
	regeneration is settled by the caller before the amount is handed over, on
	the server, from os.time().

	What a client legitimately influences is its raw INPUTS to a minigame, which
	the server replays to decide whether an attempt passed. The EV that follows
	is the server's conclusion, never the client's claim.

	=========================================================================
	THE FORMULA
	=========================================================================

		P    = ProgressionReference(lift, class)         frozen, FitVersion 1
		PP   = CN / P
		Hill = 1 / (1 + (PP / h)^m)                      h = 0.75, m = 5

		effectiveEV = CompetitionBudget.effectiveEV(budgetAmount, rawEV)

		deltaCN = P x BaseProgressRate x effectiveEV x Hill(PP)

	THE BUDGET EFFECT IS APPLIED EXACTLY ONCE, by converting rawEV into
	effectiveEV. There is no separate multiplier afterwards. Multiplying the
	result by the instantaneous multiplier as well would square the penalty.

	THE BUDGET IS DENOMINATED IN EV, NEVER KILOGRAMS, and its state advances by
	the RAW EV. Consuming effective EV would let a player in deep overflow
	spend almost nothing and so never sink further, flattening harmonic overflow
	into a plateau.

	PP IS COMPUTED FROM THE INCOMING CN, before the award. An attempt is scored
	against the lifter who attempted it.

	=========================================================================
	FULL PRECISION
	=========================================================================

	Nothing here rounds. Competition Number stays full floating point, because
	a single AFK hour at PP 100% is about 0.05 kg and rounding it away would
	silently discard real progression.

	Display rounding to 0.5 kg, and the 2.5 kg meet loading rule, are separate
	concerns that live at their own boundaries.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))
local ProgressionReferenceConfig = require(ConfigFolder:WaitForChild("ProgressionReferenceConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local CompetitionBudget = require(ProgressionFolder:WaitForChild("CompetitionBudget"))

local CompetitionNumberReward = {}

local HILL = ProgressionConfig.Hill

--[[
	Why a calculation was refused.

	A typed reason rather than a bare nil, so a caller can tell "this class is
	not supported by this engine" from "someone passed NaN". The first is a
	design boundary; the second is a bug.
]]
export type RejectionReason =
	"InvalidLift"
	| "InvalidClass"
	| "UnsupportedClass"
	| "MissingReference"
	| "InvalidCompetitionNumber"
	| "InvalidRawEV"
	| "InvalidBudgetAmount"

--[[
	Everything the calculation looked at and everything it concluded.

	Deliberately wide. A single delta would be impossible to debug and
	impossible to test: when a reward looks wrong, the useful question is which
	STAGE went wrong, and that needs PP, the Hill multiplier and both EV values
	side by side. Every field is a number, so the whole thing logs and compares
	cleanly.
]]
export type Award = {
	lift: string,
	weightClassLabel: string,

	-- The frozen reference, so a caller never has to look it up again.
	progressionReference: number,

	competitionNumberBefore: number,
	competitionNumberAfter: number,

	-- CN / P, before the award.
	progressionProximity: number,
	hillMultiplier: number,

	rawEV: number,
	effectiveEV: number,

	budgetBefore: number,
	budgetAfter: number,

	deltaCN: number,

	--[[
		deltaCN / P. The R2 invariant: at equal PP, equal raw EV and equal
		budget state, this is identical for every class and lift. Returned
		rather than left to callers so the invariant is cheap to assert.
	]]
	deltaPP: number,
}

--[[
	A number safe to store and to do arithmetic with: not NaN, not either
	infinity.
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

CompetitionNumberReward.isFiniteNumber = isFiniteNumber

--[[
	The Hill soft cap at a given Progression Proximity.

	Properties, all asserted by the dev probe:
	  - strictly positive for every finite PP >= 0, so progression never stops
	  - monotonically decreasing in PP
	  - exactly 1 at PP 0, and exactly 0.5 at PP = h

	Exposed because the probe and a future UI both want the curve without
	computing a whole award.
]]
function CompetitionNumberReward.hill(progressionProximity: number): number
	return 1 / (1 + (progressionProximity / HILL.h) ^ HILL.m)
end

--[[
	The Progression Proximity of a Competition Number for a lift and class, or
	nil if the combination is unsupported.
]]
function CompetitionNumberReward.progressionProximity(
	liftName: string,
	weightClassLabel: string,
	competitionNumberKg: number
): number?
	local reference = ProgressionReferenceConfig.get(liftName, weightClassLabel)

	if reference == nil or not isFiniteNumber(competitionNumberKg) then
		return nil
	end

	return competitionNumberKg / reference
end

--[[
	Calculates an award without applying it.

	Returns the Award on success, or nil plus a RejectionReason.

	ZERO RAW EV IS VALID, not an error. It yields exactly 0 delta CN and
	consumes exactly nothing, leaving the budget amount untouched. A legitimate
	attempt can genuinely be worth nothing -- anything at or below 60% relative
	intensity has an intensity factor of 0.00 -- and the caller should not have
	to special-case the commonest opener in the game. The result still carries
	the real PP, Hill and reference, so a zero award is inspectable rather than
	indistinguishable from a failure.

	REJECTS:
	  - a lift that is not Squat, Bench or Deadlift
	  - a class label that is not a string
	  - the unlimited class, distinctly, as UnsupportedClass
	  - a capped class with no reference, as MissingReference
	  - a non-finite or non-positive Competition Number: zero means "cannot
	    lift" and PP would divide by a reference into nothing meaningful
	  - a non-finite or negative raw EV
	  - a non-finite budget amount

	A NEGATIVE RAW EV IS REFUSED rather than treated as a deduction. Section
	29.9: leaving a meet or disconnecting consumes exactly what was earned and
	is never given back. There is no mechanism that takes EV away.

	A NEGATIVE BUDGET AMOUNT IS ACCEPTED, because that is harmonic overflow and
	the magnitude is its depth.
]]
function CompetitionNumberReward.calculate(
	liftName: string,
	weightClassLabel: string,
	competitionNumberKg: number,
	rawEV: number,
	budgetAmountEV: number
): (Award?, RejectionReason?)
	if not ProgressionConfig.isLift(liftName) then
		return nil, "InvalidLift"
	end

	if typeof(weightClassLabel) ~= "string" then
		return nil, "InvalidClass"
	end

	--[[
		The unlimited class gets its own reason, checked BEFORE the reference
		lookup. Both would otherwise surface as a missing reference, and the
		distinction matters: 120+ is an unbuilt system, not a data gap.

		It must never silently fall back to the 120 kg reference. A 120+ lifter
		scored against the 120 kg table would be handed a bounded ceiling, which
		is the opposite of what that class is for.
	]]
	if weightClassLabel == ProgressionReferenceConfig.UNLIMITED_CLASS_LABEL then
		return nil, "UnsupportedClass"
	end

	if not ProgressionReferenceConfig.isCappedClass(weightClassLabel) then
		return nil, "InvalidClass"
	end

	local reference = ProgressionReferenceConfig.get(liftName, weightClassLabel)
	if reference == nil or not isFiniteNumber(reference) or reference <= 0 then
		return nil, "MissingReference"
	end

	if not isFiniteNumber(competitionNumberKg) or competitionNumberKg <= 0 then
		return nil, "InvalidCompetitionNumber"
	end

	if not isFiniteNumber(rawEV) or rawEV < 0 then
		return nil, "InvalidRawEV"
	end

	if not isFiniteNumber(budgetAmountEV) then
		return nil, "InvalidBudgetAmount"
	end

	-- Scored against the lifter as they were before the award.
	local progressionProximity = competitionNumberKg / reference
	local hillMultiplier = CompetitionNumberReward.hill(progressionProximity)

	--[[
		The ONLY place the budget effect is applied. effectiveEV integrates the
		harmonic multiplier across the span consumed and returns the new amount,
		which has advanced by the RAW EV.
	]]
	local effectiveEV, budgetAfter = CompetitionBudget.effectiveEV(budgetAmountEV, rawEV)

	local deltaCN = reference * ProgressionConfig.BaseProgressRate * effectiveEV * hillMultiplier

	--[[
		Guard the product, not just the inputs. Finite factors can still
		overflow, and a NaN or infinite delta reaching a profile would poison
		that stat permanently.
	]]
	if not isFiniteNumber(deltaCN) then
		return nil, "InvalidRawEV"
	end

	return {
		lift = liftName,
		weightClassLabel = weightClassLabel,

		progressionReference = reference,

		competitionNumberBefore = competitionNumberKg,
		competitionNumberAfter = competitionNumberKg + deltaCN,

		progressionProximity = progressionProximity,
		hillMultiplier = hillMultiplier,

		rawEV = rawEV,
		effectiveEV = effectiveEV,

		budgetBefore = budgetAmountEV,
		budgetAfter = budgetAfter,

		deltaCN = deltaCN,
		deltaPP = deltaCN / reference,
	},
		nil
end

--[[
	The Competition Number a player would need for a given PP, in kilograms.

	The inverse of PP, for tooling: the probe and a future balance pass both want
	to ask "what CN is PP 85% here?" without multiplying by hand.
]]
function CompetitionNumberReward.competitionNumberForPP(
	liftName: string,
	weightClassLabel: string,
	targetPP: number
): number?
	local reference = ProgressionReferenceConfig.get(liftName, weightClassLabel)

	if reference == nil or not isFiniteNumber(targetPP) or targetPP <= 0 then
		return nil
	end

	return reference * targetPP
end

return CompetitionNumberReward
