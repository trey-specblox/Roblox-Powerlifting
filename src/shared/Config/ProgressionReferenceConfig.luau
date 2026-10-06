--!strict
--[[
	ProgressionReferenceConfig
	Shared / Config

	THE FROZEN PROGRESSION-NORMALIZATION TABLE, VERSION 1.

	One authoritative number per capped class and lift. It is the denominator of
	Progression Proximity, which is what drives difficulty and progression:

		PP = CompetitionNumber / ProgressionReference(lift, class)

	=========================================================================
	THIS IS NOT A WORLD RECORD TABLE
	=========================================================================

	ReferenceRecordConfig holds the real/official records. Those drive PRESTIGE:
	Actual Record Proximity, record eligibility, leaderboards.

	This file holds PROGRESSION references. They drive PACING. The two are
	deliberately different quantities, and the real record sits between about
	PP 81.7% and PP 99.5% depending on class and lift -- so PP 100% is NOT the
	world record.

	=========================================================================
	THE VALUES BELOW ARE LITERALS ON PURPOSE
	=========================================================================

	They were DERIVED once, from the M2 allometric fit recorded in Provenance
	below, and then frozen. Nothing recomputes them at runtime.

	THAT IS THE WHOLE POINT. If these were derived live from
	ReferenceRecordConfig, then updating a real world record -- which will
	legitimately happen when records are broken -- would silently move every
	existing player's PP, change their Hill soft-cap position, and alter their
	progression pacing. A record being broken in the real world must not
	retroactively re-pace somebody's character.

	So: changing a real WR does NOT change these values. Changing these values
	is an explicit progression-version decision, taken deliberately, with
	FitVersion bumped and the balance consequences understood.

	=========================================================================
	WHAT IS VALIDATED AT LOAD, AND WHAT IS NOT
	=========================================================================

	validateTable below checks STRUCTURE only: every capped class present, every
	lift present, every value finite and above zero, and each lift's references
	strictly ascending with class.

	IT DOES NOT re-derive the fit and compare. That check exists, but it is
	DEV-ONLY (see deriveFromProvenance), precisely because ReferenceRecordConfig may
	legitimately change later. Production startup must never fail, and progression
	must never shift, because a real record was updated.

	=========================================================================
	120+ IS DELIBERATELY ABSENT
	=========================================================================

	The unlimited class has no upper bodyweight bound, so the allometric fit has
	no x-value to evaluate at: the formula is undefined there rather than merely
	unspecified.

	Its progression basis must be unbounded-but-increasingly-difficult, which is
	a different system, and no finalized rule for it exists in GAME_DESIGN.md.

	Three things it must NOT be, all explicitly rejected:
	  - an extrapolation of this fit
	  - the 120+ real world record used as a progression reference
	  - the C3 capped-class export formula, which is a TRANSLATION rule and not
	    a growth rule

	Callers get nil for "120+ kg" and must handle it as unsupported.
]]

local ProgressionReferenceConfig = {}

--[[
	Bump this when the table changes. A bump is a balance decision with pacing
	consequences for every existing player, not a routine edit.
]]
ProgressionReferenceConfig.FIT_VERSION = 1

--[[
	=========================================================================
	PROVENANCE OF VERSION 1
	=========================================================================

	How the literals below were produced, recorded so the table can be audited
	or reproduced without the derivation living in runtime code.

		reference = Coefficient x bodyweight ^ Exponent

	INPUTS, both from committed repository data at the time of the fit:

	  1. The real records in ReferenceRecordConfig, capped classes only.
	  2. The CLASS UPPER BOUNDS as the bodyweight x-values:
	         59, 66, 74, 83, 93, 105, 120
	     Frozen as part of this fit. The upper bound is used because it is the
	     only bodyweight the class definition actually supplies.

	PROCEDURE:

	  1. Fit the exponent by least squares on log(WR) against log(bodyweight),
	     per lift, across the seven capped classes.
	  2. Take k_raw = max(WR / bodyweight ^ Exponent) over those classes, so the
	     curve sits at or above every real record.
	  3. Coefficient = k_raw x HeadroomMultiplier.

	WHY STEP 3 EXISTS: without headroom, the binding class in each lift would
	have its real record at exactly PP 100%, putting the world record precisely
	at the reference. 0.5% keeps every record strictly below its reference, so
	the hardest three sit at PP 99.5% rather than 100%.

	A CONSEQUENCE WORTH KNOWING: because k is fitted to the MAXIMUM, exactly one
	class per lift is pinned near the reference -- 74 kg Squat, 66 kg Bench and
	83 kg Deadlift all land at PP 99.5%. Their records are therefore the hardest
	to reach. This is accepted and frozen; see GAME_DESIGN.md section 29.13.
]]
ProgressionReferenceConfig.HeadroomMultiplier = 1.005

ProgressionReferenceConfig.Provenance = {
	Squat = {
		Exponent = 0.67269077281080014,
		Coefficient = 18.945475535859227,
		-- Before HeadroomMultiplier was applied.
		RawCoefficient = 18.8512194386659,
	},

	Bench = {
		Exponent = 0.53706504721053849,
		Coefficient = 22.612599532213689,
		RawCoefficient = 22.500099037028548,
	},

	Deadlift = {
		Exponent = 0.41160160566320991,
		Coefficient = 62.440908240461866,
		RawCoefficient = 62.130256955683457,
	},
}

--[[
	The bodyweight x-values the fit used, frozen as part of its provenance.

	Deliberately duplicated rather than read from WeightClassConfig: these are a
	historical record of what the fit consumed, and must not drift if the class
	structure is ever changed. A mismatch is a finding for the dev check, not
	something to silently absorb.
]]
ProgressionReferenceConfig.FitBodyweights = {
	["59 kg"] = 59,
	["66 kg"] = 66,
	["74 kg"] = 74,
	["83 kg"] = 83,
	["93 kg"] = 93,
	["105 kg"] = 105,
	["120 kg"] = 120,
}

--[[
	=========================================================================
	THE AUTHORITATIVE TABLE
	=========================================================================

	Full derived double precision, deliberately unrounded. Rounding to 0.1 kg
	would move PP in the fourth significant digit for no benefit, and PP feeds a
	fifth-power curve.

	Kilograms.
]]
local references: { [string]: { [string]: number } } = {
	Squat = {
		["59 kg"] = 294.26683546116362,
		["66 kg"] = 317.31889027343254,
		["74 kg"] = 342.70499999999998,
		["83 kg"] = 370.21297509548486,
		["93 kg"] = 399.65552993061738,
		["105 kg"] = 433.65154920302803,
		["120 kg"] = 474.4075039349151,
	},

	Bench = {
		["59 kg"] = 202.02876579158061,
		["66 kg"] = 214.56749999999997,
		["74 kg"] = 228.1652563217435,
		["83 kg"] = 242.67232874568123,
		["93 kg"] = 257.9608974423578,
		["105 kg"] = 275.3344904730788,
		["120 kg"] = 295.80537797036118,
	},

	Deadlift = {
		["59 kg"] = 334.46813064191696,
		["66 kg"] = 350.26473712370154,
		["74 kg"] = 367.153767234231,
		["83 kg"] = 384.91499999999996,
		["93 kg"] = 403.36661803155874,
		["105 kg"] = 424.02745019850698,
		["120 kg"] = 447.98508066851906,
	},
}

--[[
	The capped classes this table covers, in ascending order.

	"120+ kg" is absent by design. See the header.
]]
ProgressionReferenceConfig.CappedClassLabels = {
	"59 kg",
	"66 kg",
	"74 kg",
	"83 kg",
	"93 kg",
	"105 kg",
	"120 kg",
}

ProgressionReferenceConfig.Lifts = { "Squat", "Bench", "Deadlift" }

--[[
	The unlimited class, named once so no caller has to spell it.
]]
ProgressionReferenceConfig.UNLIMITED_CLASS_LABEL = "120+ kg"

--[[
	The Progression Reference for a lift and class, in kilograms.

	Returns nil when the lift is unknown, the class is unknown, or the class is
	the unlimited one. A nil result is a legitimate answer meaning "this engine
	does not cover that", NOT an error to paper over: callers must not fall back
	to another class's reference.
]]
function ProgressionReferenceConfig.get(liftName: string, weightClassLabel: string): number?
	if typeof(liftName) ~= "string" or typeof(weightClassLabel) ~= "string" then
		return nil
	end

	local lift = references[liftName]
	if lift == nil then
		return nil
	end

	local value = lift[weightClassLabel]
	if typeof(value) ~= "number" then
		return nil
	end

	return value
end

--[[
	True when this label is a capped class this table covers.

	Exists so callers can distinguish "unsupported class" from "bad input"
	without reaching into the table.
]]
function ProgressionReferenceConfig.isCappedClass(weightClassLabel: string): boolean
	if typeof(weightClassLabel) ~= "string" then
		return false
	end

	for _, label in ipairs(ProgressionReferenceConfig.CappedClassLabels) do
		if label == weightClassLabel then
			return true
		end
	end

	return false
end

--[[
	=========================================================================
	DEV-ONLY PROVENANCE CHECK
	=========================================================================

	Recomputes one reference from the stored Provenance coefficients.

	FOR TOOLING AND REGRESSION ONLY. Production never calls this, and startup
	never depends on it. It answers "do the frozen literals still match the
	recorded fit?", which is a provenance question.

	It deliberately does NOT consult ReferenceRecordConfig. Comparing against
	live records is a separate, looser question -- "have the real records moved
	since the fit?" -- whose answer may legitimately be yes without invalidating
	anything here.
]]
function ProgressionReferenceConfig.deriveFromProvenance(liftName: string, bodyweightKg: number): number?
	local fit = ProgressionReferenceConfig.Provenance[liftName]
	if fit == nil then
		return nil
	end

	if typeof(bodyweightKg) ~= "number" or bodyweightKg ~= bodyweightKg or bodyweightKg <= 0 then
		return nil
	end

	return fit.Coefficient * bodyweightKg ^ fit.Exponent
end

--[[
	=========================================================================
	STRUCTURAL VALIDATION, AT LOAD
	=========================================================================

	Structure only, for the reasons in the header. A typo that halves a
	reference would halve that class's pacing silently, so the shape is asserted
	rather than trusted.
]]
local function validateTable()
	for _, liftName in ipairs(ProgressionReferenceConfig.Lifts) do
		local lift = references[liftName]

		assert(
			typeof(lift) == "table",
			string.format("[ProgressionReferenceConfig] missing references for lift %q", liftName)
		)

		local previous = 0

		for _, label in ipairs(ProgressionReferenceConfig.CappedClassLabels) do
			local value = lift[label]

			assert(
				typeof(value) == "number",
				string.format("[ProgressionReferenceConfig] %s is missing class %q", liftName, label)
			)
			assert(
				value == value,
				string.format("[ProgressionReferenceConfig] %s %s is NaN", liftName, label)
			)
			assert(
				value ~= math.huge and value ~= -math.huge,
				string.format("[ProgressionReferenceConfig] %s %s is infinite", liftName, label)
			)
			assert(
				value > 0,
				string.format("[ProgressionReferenceConfig] %s %s must be above zero, got %f", liftName, label, value)
			)

			--[[
				STRICTLY ascending. A heavier class must always have a larger
				reference, or bulking into it would reduce headroom -- which is
				the non-monotonicity problem the M2 fit exists to solve.
			]]
			assert(
				value > previous,
				string.format(
					"[ProgressionReferenceConfig] %s references must strictly increase with class: "
						.. "%s is %f, which does not exceed the previous %f",
					liftName,
					label,
					value,
					previous
				)
			)

			previous = value
		end

		--[[
			The unlimited class must NOT be in here. If someone adds it, every
			caller that trusted nil to mean "unsupported" would silently start
			treating 120+ as a capped class.
		]]
		assert(
			lift[ProgressionReferenceConfig.UNLIMITED_CLASS_LABEL] == nil,
			string.format(
				"[ProgressionReferenceConfig] %s must not define %q. The unlimited class has no "
					.. "allometric reference and its growth rule is a separate unbuilt system.",
				liftName,
				ProgressionReferenceConfig.UNLIMITED_CLASS_LABEL
			)
		)
	end

	-- Provenance must cover every lift, so the dev check can never silently skip one.
	for _, liftName in ipairs(ProgressionReferenceConfig.Lifts) do
		local fit = ProgressionReferenceConfig.Provenance[liftName]
		assert(
			typeof(fit) == "table"
				and typeof(fit.Exponent) == "number"
				and typeof(fit.Coefficient) == "number",
			string.format("[ProgressionReferenceConfig] %s is missing fit provenance", liftName)
		)
	end
end

validateTable()

return ProgressionReferenceConfig
