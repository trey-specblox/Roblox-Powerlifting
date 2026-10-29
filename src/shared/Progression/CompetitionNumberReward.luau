--!strict
--[[
	CompetitionNumberReward
	Shared / Progression

	The authoritative Competition Number reward calculation, from
	GAME_DESIGN.md section 29.

		Competition Number
		  -> Progression Proximity (PP)
		  -> Hill soft cap
		  -> earned EV
		  -> delta Competition Number

	=========================================================================
	PURE. IT CALCULATES AND NEVER MUTATES.
	=========================================================================

	calculateTrainingAward() takes authoritative state and returns a result. It
	writes nothing: no profile, no resource, no timestamp. A server-authoritative
	operation (ProfileOperations.applyTrainingProgression) computes an award,
	inspects it, and only then applies it -- or discards it.

	ONE ENTRY POINT. Gym-station training, which section 34 makes the ONLY
	source of Competition Number, uses `calculateTrainingAward`. The old
	budgeted meet path (`calculate`, with the section 29.9 Competition Budget)
	was removed with the budget in schema version 10: meets never award EV
	(section 33.3), and their CN raises use the meet allowance (MeetCnAllowance).
	`hill` and `progressionProximity` are also read by MeetCnAllowance, the meet
	CN allowance.

	=========================================================================
	EVERY INPUT IS SERVER-DERIVED
	=========================================================================

	The client may never supply, and this module never accepts from a client:
	final CN, delta CN, PP, the Hill multiplier, earned EV, or a timestamp.

	What a client legitimately influences is its raw INPUTS to a minigame, which
	the server replays to decide whether an attempt passed. The EV that follows
	is the server's conclusion, never the client's claim.

	=========================================================================
	THE FORMULA
	=========================================================================

		P    = ProgressionReference(lift, class)         frozen, FitVersion 1
		PP   = CN / P
		Hill = 1 / (1 + (PP / h)^m)                      h = 0.75, m = 5

		deltaCN = P x BaseProgressRate x earnedEV x Hill(PP)

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
	The checks every award makes before any EV is considered: lift, class,
	reference and the incoming Competition Number, IN THAT ORDER.

	Returns the frozen reference on success, or nil plus a RejectionReason.
]]
local function resolveReference(
	liftName: string,
	weightClassLabel: string,
	competitionNumberKg: number
): (number?, RejectionReason?)
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

	return reference, nil
end

--[[
	A station-training award: everything the calculation looked at and
	concluded, side by side, so a wrong reward shows which STAGE went wrong.
	See calculateTrainingAward.
]]
export type TrainingAward = {
	lift: string,
	weightClassLabel: string,

	progressionReference: number,

	competitionNumberBefore: number,
	competitionNumberAfter: number,

	progressionProximity: number,
	hillMultiplier: number,

	-- The EV the daily allowance granted. Already capped; nothing scales it here.
	earnedEV: number,

	deltaCN: number,
	deltaPP: number,
}

--[[
	Calculates a GYM-STATION TRAINING award without applying it.

		deltaCN = P x BaseProgressRate x earnedEV x Hill(PP)

	GAME_DESIGN.md section 34.12, decision A of checkpoint 5B.5: the
	account-wide 4.00 EV daily allowance is the only throttle on training, so
	nothing else scales the EV here. The frozen reference, the live
	BaseProgressRate and the Hill soft cap are scored on the incoming
	Competition Number, after resolveReference's lift, class and CN checks.

	`earnedEV` IS NEVER A CALLER'S CLAIM. Its only legitimate source is a
	TrainingAllowance plan computed on the server from observed station time,
	which is what ProfileOperations.applyTrainingProgression passes in.

	ZERO EARNED EV IS VALID and yields exactly 0 delta, so a caller can validate
	that a lifter and class are scorable before any EV exists. Negative,
	NaN and infinite EV are refused as InvalidRawEV.
]]
function CompetitionNumberReward.calculateTrainingAward(
	liftName: string,
	weightClassLabel: string,
	competitionNumberKg: number,
	earnedEV: number
): (TrainingAward?, RejectionReason?)
	local resolved, rejection = resolveReference(liftName, weightClassLabel, competitionNumberKg)
	if resolved == nil then
		return nil, rejection
	end

	local reference: number = resolved

	if not isFiniteNumber(earnedEV) or earnedEV < 0 then
		return nil, "InvalidRawEV"
	end

	local progressionProximity = competitionNumberKg / reference
	local hillMultiplier = CompetitionNumberReward.hill(progressionProximity)

	local deltaCN = reference * ProgressionConfig.BaseProgressRate * earnedEV * hillMultiplier

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

		earnedEV = earnedEV,

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
