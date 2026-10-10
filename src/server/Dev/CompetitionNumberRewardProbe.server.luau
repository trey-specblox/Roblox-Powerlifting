--!strict
--[[
	CompetitionNumberRewardProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Exercises the Competition Number reward engine and
	prints a pass/fail line per check.

	Separate from PlayerDataProbe on purpose: that one tests PERSISTENCE, this
	one tests PROGRESSION MATHEMATICS. They fail for different reasons and are
	worth running at different times.

	OFF BY DEFAULT. Set ENABLED to true to run it, then set it back. Turn it on
	whenever the reward engine, the Hill parameters, BaseProgressRate or the
	frozen Progression Reference table change.

	=========================================================================
	EVERY CHECK IS INDEPENDENT
	=========================================================================

	No section mutates state another section reads. The engine is pure, so there
	is no shared fixture to poison -- which is deliberate, after a shared fixture
	in PlayerDataProbe once turned one stale expectation into four reported
	failures.
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
local CompetitionNumberReward = require(ProgressionFolder:WaitForChild("CompetitionNumberReward"))
local CompetitionBudget = require(ProgressionFolder:WaitForChild("CompetitionBudget"))

local BUDGET = ProgressionConfig.CompetitionBudget
local BPR = ProgressionConfig.BaseProgressRate
local CAPPED = ProgressionReferenceConfig.CappedClassLabels
local LIFTS = ProgressionReferenceConfig.Lifts

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
	return math.abs(a - b) <= (tolerance or 1e-9)
end

--[[
	A fresh budget, for the many checks that want one.
]]
local FRESH = BUDGET.CapacityEV

print("")
print("=== Competition Number reward engine probe ===")
print(string.format(
	"  Hill h=%.2f m=%d  |  BaseProgressRate=%.8f  |  budget cap %.2f EV, K=%.3f  |  FitVersion %d",
	ProgressionConfig.Hill.h,
	ProgressionConfig.Hill.m,
	BPR,
	FRESH,
	CompetitionBudget.CurveScaleEV,
	ProgressionReferenceConfig.FIT_VERSION
))
print("")

--------------------------------------------------------------------------------
print("1. all Progression References are valid")
do
	local count = 0
	local allFinite = true
	local allPositive = true

	for _, lift in ipairs(LIFTS) do
		local previous = 0
		local ascending = true

		for _, label in ipairs(CAPPED) do
			local reference = ProgressionReferenceConfig.get(lift, label)

			if reference == nil then
				allFinite = false
			else
				count += 1
				if reference ~= reference or reference == math.huge then
					allFinite = false
				end
				if reference <= 0 then
					allPositive = false
				end
				if reference <= previous then
					ascending = false
				end
				previous = reference
			end
		end

		check(string.format("%s references strictly ascend with class", lift), ascending)
	end

	check("all 21 capped references are present", count == 21, tostring(count))
	check("all are finite", allFinite)
	check("all are above zero", allPositive)

	--[[
		Provenance must still reproduce the frozen literals. This is the
		DEV-ONLY check: it compares the table against the RECORDED FIT, never
		against live ReferenceRecordConfig, because real records may legitimately
		move without invalidating this table.
	]]
	local maxDrift = 0
	for _, lift in ipairs(LIFTS) do
		for _, label in ipairs(CAPPED) do
			local frozen = ProgressionReferenceConfig.get(lift, label) :: number
			local bodyweight = ProgressionReferenceConfig.FitBodyweights[label]
			local derived = ProgressionReferenceConfig.deriveFromProvenance(lift, bodyweight)

			if derived ~= nil then
				local drift = math.abs(derived - frozen) / frozen
				if drift > maxDrift then
					maxDrift = drift
				end
			end
		end
	end

	check(
		"frozen literals still match the recorded fit provenance",
		maxDrift < 1e-12,
		string.format("max relative drift %.3e", maxDrift)
	)

	check("FitVersion is 1", ProgressionReferenceConfig.FIT_VERSION == 1)
	check("HeadroomMultiplier is 1.005", near(ProgressionReferenceConfig.HeadroomMultiplier, 1.005))
end

--------------------------------------------------------------------------------
print("")
print("2. PP calculation")
do
	local reference = ProgressionReferenceConfig.get("Squat", "59 kg") :: number

	local atHalf = CompetitionNumberReward.progressionProximity("Squat", "59 kg", reference * 0.5)
	check("CN at half the reference is PP 0.5", atHalf ~= nil and near(atHalf :: number, 0.5), tostring(atHalf))

	local atOne = CompetitionNumberReward.progressionProximity("Squat", "59 kg", reference)
	check("CN equal to the reference is PP 1.0", atOne ~= nil and near(atOne :: number, 1.0), tostring(atOne))

	local above = CompetitionNumberReward.progressionProximity("Squat", "59 kg", reference * 1.25)
	check("PP can exceed 1.0", above ~= nil and near(above :: number, 1.25), tostring(above))

	-- The inverse, used by the matrix sections below.
	local cn = CompetitionNumberReward.competitionNumberForPP("Squat", "59 kg", 0.85)
	check(
		"competitionNumberForPP inverts PP",
		cn ~= nil and near(cn :: number, reference * 0.85),
		tostring(cn)
	)

	check(
		"PP is nil for the unlimited class",
		CompetitionNumberReward.progressionProximity("Squat", "120+ kg", 300) == nil
	)
end

--------------------------------------------------------------------------------
print("")
print("3. Hill anchors")
do
	--[[
		Hill(PP) = 1 / (1 + (PP/0.75)^5). The two exact anchors are structural:
		1 at PP 0, and exactly 0.5 at PP = h, where the two terms are equal.
	]]
	check("Hill(0) is exactly 1", near(CompetitionNumberReward.hill(0), 1.0))
	check("Hill(0.75) is exactly 0.5", near(CompetitionNumberReward.hill(0.75), 0.5))

	local anchors = {
		{ 0.20, 0.9986533386 },
		{ 0.60, 0.7531935406 },
		{ 0.75, 0.5000000000 },
		{ 0.85, 0.3484599162 },
		{ 1.00, 0.1917916338 },
		{ 1.10, 0.1284245055 },
		{ 1.25, 0.0721496437 },
		{ 1.50, 0.0303030303 },
	}

	print("      PP     | Hill(PP)")
	for _, pair in ipairs(anchors) do
		local pp = pair[1]
		local expected = pair[2]
		local actual = CompetitionNumberReward.hill(pp)

		print(string.format("      %5.2f  | %.10f", pp, actual))
		check(
			string.format("Hill(%.2f) = %.10f", pp, expected),
			near(actual, expected, 1e-9),
			string.format("%.10f", actual)
		)
	end
end

--------------------------------------------------------------------------------
print("")
print("4. Hill monotonicity")
do
	local previous = math.huge
	local monotonic = true
	local firstBreak = ""

	-- Fine sweep well past the endgame, so a local bump cannot hide.
	for step = 0, 400 do
		local pp = step * 0.01
		local h = CompetitionNumberReward.hill(pp)

		if h > previous then
			monotonic = false
			if firstBreak == "" then
				firstBreak = string.format("PP %.2f rose to %.10f", pp, h)
			end
		end
		previous = h
	end

	check("Hill is monotonically decreasing from PP 0 to PP 4", monotonic, firstBreak)
	check(
		"and strictly so across the playable band",
		CompetitionNumberReward.hill(0.20) > CompetitionNumberReward.hill(0.60)
			and CompetitionNumberReward.hill(0.60) > CompetitionNumberReward.hill(1.00)
			and CompetitionNumberReward.hill(1.00) > CompetitionNumberReward.hill(1.50)
	)
end

--------------------------------------------------------------------------------
print("")
print("5. Hill is never zero")
do
	--[[
		The frozen rule is that there is no hard strength cap: progression slows
		without limit but never stops. So Hill must stay strictly positive at
		absurd PP, not merely at playable PP.
	]]
	local extremes = { 2, 5, 10, 50, 100, 1000 }
	local allPositive = true
	local smallest = 1

	for _, pp in ipairs(extremes) do
		local h = CompetitionNumberReward.hill(pp)
		if h <= 0 or h ~= h then
			allPositive = false
		end
		if h < smallest then
			smallest = h
		end
	end

	check("Hill stays strictly above zero out to PP 1000", allPositive, string.format("smallest %.3e", smallest))
	check("and is vanishingly small there, as intended", smallest < 1e-10, string.format("%.3e", smallest))
end

--------------------------------------------------------------------------------
print("")
print("6. BaseProgressRate")
do
	check("BaseProgressRate is 0.00482389", near(BPR, 0.00482389, 1e-12), string.format("%.11f", BPR))

	--[[
		Its meaning: one unit-quality award at Hill 1 grants 0.4824% of the
		reference. Asserted against a real award rather than restated, so the
		constant and the formula cannot drift apart.
	]]
	local reference = ProgressionReferenceConfig.get("Squat", "59 kg") :: number
	local tiny = 1e-6
	local award = CompetitionNumberReward.calculate("Squat", "59 kg", reference * tiny, 1.0, FRESH)

	check(
		"at negligible PP, one EV grants reference x BaseProgressRate",
		award ~= nil and near((award :: any).deltaCN, reference * BPR, 1e-6),
		if award ~= nil then string.format("%.8f vs %.8f", (award :: any).deltaCN, reference * BPR) else "nil"
	)
end

--------------------------------------------------------------------------------
print("")
print("7. zero EV behaviour")
do
	local reference = ProgressionReferenceConfig.get("Bench", "83 kg") :: number
	local cn = reference * 0.60

	local award, reason = CompetitionNumberReward.calculate("Bench", "83 kg", cn, 0, FRESH)

	check("zero raw EV is VALID, not an error", award ~= nil, tostring(reason))

	if award ~= nil then
		local a = award :: any
		check("it yields exactly zero delta CN", a.deltaCN == 0, tostring(a.deltaCN))
		check("it yields exactly zero effective EV", a.effectiveEV == 0, tostring(a.effectiveEV))
		check("CN after equals CN before", a.competitionNumberAfter == cn)
		check(
			"and it consumes NOTHING from the budget",
			a.budgetAfter == a.budgetBefore,
			string.format("%.10f vs %.10f", a.budgetAfter, a.budgetBefore)
		)
		check("but the result still reports real PP and Hill, so it is inspectable", near(a.progressionProximity, 0.60))
	end
end

--------------------------------------------------------------------------------
print("")
print("8. invalid EV is rejected")
do
	local reference = ProgressionReferenceConfig.get("Squat", "74 kg") :: number
	local cn = reference * 0.5

	local function rejects(label: string, rawEV: number, expected: string)
		local award, reason = CompetitionNumberReward.calculate("Squat", "74 kg", cn, rawEV, FRESH)
		check(label .. " is rejected", award == nil)
		check(label .. " reports " .. expected, reason == expected, tostring(reason))
	end

	rejects("NaN raw EV", 0 / 0, "InvalidRawEV")
	rejects("+infinity raw EV", math.huge, "InvalidRawEV")
	rejects("-infinity raw EV", -math.huge, "InvalidRawEV")
	rejects("negative raw EV", -1.0, "InvalidRawEV")

	-- A negative budget amount is legitimate overflow; a non-finite one is not.
	local nanBudget, nanReason = CompetitionNumberReward.calculate("Squat", "74 kg", cn, 1.0, 0 / 0)
	check("NaN budget amount is rejected", nanBudget == nil and nanReason == "InvalidBudgetAmount", tostring(nanReason))

	local negBudget = CompetitionNumberReward.calculate("Squat", "74 kg", cn, 1.0, -9.43)
	check("a NEGATIVE budget amount is accepted, because that is overflow", negBudget ~= nil)
end

--------------------------------------------------------------------------------
print("")
print("9. invalid Competition Number is rejected")
do
	local function rejects(label: string, cn: number)
		local award, reason = CompetitionNumberReward.calculate("Deadlift", "93 kg", cn, 1.0, FRESH)
		check(label .. " is rejected", award == nil)
		check(label .. " reports InvalidCompetitionNumber", reason == "InvalidCompetitionNumber", tostring(reason))
	end

	rejects("NaN CN", 0 / 0)
	rejects("+infinity CN", math.huge)
	rejects("zero CN", 0)
	rejects("negative CN", -100)
end

--------------------------------------------------------------------------------
print("")
print("10. invalid lift is rejected")
do
	local function rejects(label: string, lift: any)
		local award, reason = CompetitionNumberReward.calculate(lift, "59 kg", 200, 1.0, FRESH)
		check(label .. " is rejected", award == nil)
		check(label .. " reports InvalidLift", reason == "InvalidLift", tostring(reason))
	end

	rejects("an unknown lift", "Curl")
	rejects("an empty lift name", "")
	rejects("the Total pseudo-lift", "Total")
end

--------------------------------------------------------------------------------
print("")
print("11. invalid class is rejected")
do
	local function rejects(label: string, class: any, expected: string)
		local award, reason = CompetitionNumberReward.calculate("Squat", class, 200, 1.0, FRESH)
		check(label .. " is rejected", award == nil)
		check(label .. " reports " .. expected, reason == expected, tostring(reason))
	end

	rejects("an unknown class", "77 kg", "InvalidClass")
	rejects("an empty class label", "", "InvalidClass")
	rejects("a class with the wrong format", "59", "InvalidClass")
	rejects("a below-minimum class", "53 kg", "InvalidClass")
end

--------------------------------------------------------------------------------
print("")
print("12-15. budget states: fresh, boundary, overflow, deep overflow")
do
	local reference = ProgressionReferenceConfig.get("Squat", "59 kg") :: number
	local cn = reference * 0.60
	local rawEV = BUDGET.UnitEV

	--[[
		Named fields rather than a mixed {string, number} array. A positional
		pair makes Luau unify the element type to whichever came first, so the
		second slot then fails to type-check.
	]]
	local states: { { label: string, amount: number } } = {
		{ label = "fresh", amount = FRESH },
		{ label = "boundary (0)", amount = 0 },
		{ label = "overflow (-9.43)", amount = -9.43 },
		{ label = "deep overflow (-47.15)", amount = -47.15 },
	}

	print("      budget before |    effEV |      dCN | budget after | vs fresh")
	local baseline = 0
	local deltas: { number } = {}
	local effectives: { number } = {}

	for index, state in ipairs(states) do
		local label = state.label
		local amount = state.amount

		local award = CompetitionNumberReward.calculate("Squat", "59 kg", cn, rawEV, amount)

		if award == nil then
			check(string.format("%s produces an award", label), false, "rejected")
		else
			local a = award :: any
			if index == 1 then
				baseline = a.deltaCN
			end
			table.insert(deltas, a.deltaCN)
			table.insert(effectives, a.effectiveEV)

			print(string.format(
				"      %13.2f | %8.6f | %8.6f | %12.3f | %6.2f%%",
				amount, a.effectiveEV, a.deltaCN, a.budgetAfter, 100 * a.deltaCN / baseline
			))

			check(string.format("%s produces an award", label), true)

			--[[
				16. RAW EV CONSUMPTION. The state must advance by the raw EV,
				never the effective EV, whatever the overflow depth.
			]]
			check(
				string.format("%s consumes exactly the RAW EV, not the effective EV", label),
				near(a.budgetAfter, amount - rawEV, 1e-9),
				string.format("%.10f, expected %.10f", a.budgetAfter, amount - rawEV)
			)

			--[[
				18. NEVER EXACTLY ZERO under finite legitimate overflow.
			]]
			check(
				string.format("%s still awards strictly above zero", label),
				a.deltaCN > 0,
				string.format("%.12f", a.deltaCN)
			)
		end
	end

	-- 17. EFFECTIVE EV REDUCTION, and the delta falling with it.
	local effDecreasing = true
	local deltaDecreasing = true
	for i = 2, #effectives do
		if effectives[i] >= effectives[i - 1] then
			effDecreasing = false
		end
		if deltas[i] >= deltas[i - 1] then
			deltaDecreasing = false
		end
	end

	check("effective EV decreases as the budget empties", effDecreasing)
	check("and delta CN decreases with it", deltaDecreasing)
	check(
		"a fresh budget passes raw EV through untouched",
		near(effectives[1], rawEV, 1e-9),
		tostring(effectives[1])
	)
	check(
		"deep overflow is heavily penalised but not zeroed",
		deltas[4] > 0 and deltas[4] < 0.2 * deltas[1],
		string.format("%.2f%% of fresh", 100 * deltas[4] / deltas[1])
	)
end

--------------------------------------------------------------------------------
print("")
print("19. split-EV path independence")
do
	local reference = ProgressionReferenceConfig.get("Deadlift", "105 kg") :: number
	local cn = reference * 0.70
	local total = 3 * BUDGET.UnitEV

	-- One lump, deliberately crossing from allowance into overflow.
	local lump = CompetitionNumberReward.calculate("Deadlift", "105 kg", cn, total, 2.0)
	local lumpEV = if lump ~= nil then (lump :: any).effectiveEV else -1

	--[[
		The same total in many pieces. CN is deliberately held CONSTANT across
		the pieces so this isolates the BUDGET path; compounding CN would change
		Hill between pieces and confuse the two effects.
	]]
	local function splitInto(pieces: number): (number, number)
		local amount = 2.0
		local sum = 0
		for _ = 1, pieces do
			local award = CompetitionNumberReward.calculate("Deadlift", "105 kg", cn, total / pieces, amount)
			if award == nil then
				return -1, amount
			end
			sum += (award :: any).effectiveEV
			amount = (award :: any).budgetAfter
		end
		return sum, amount
	end

	local twoEV, twoAmount = splitInto(2)
	local tenEV = select(1, splitInto(10))
	local hundredEV, hundredAmount = splitInto(100)

	print(string.format("      lump %.10f | 2 pieces %.10f | 10 %.10f | 100 %.10f", lumpEV, twoEV, tenEV, hundredEV))

	check("2 pieces equal one lump", near(twoEV, lumpEV, 1e-9), string.format("%.12f vs %.12f", twoEV, lumpEV))
	check("10 pieces equal one lump", near(tenEV, lumpEV, 1e-9), string.format("%.12f vs %.12f", tenEV, lumpEV))
	check("100 pieces equal one lump", near(hundredEV, lumpEV, 1e-8), string.format("%.12f vs %.12f", hundredEV, lumpEV))
	check(
		"and the final budget state matches too",
		near(hundredAmount, 2.0 - total, 1e-9) and near(twoAmount, 2.0 - total, 1e-9),
		string.format("%.10f vs %.10f", hundredAmount, 2.0 - total)
	)
end

--------------------------------------------------------------------------------
print("")
print("20. R2 INVARIANT across all 21 capped combinations")
do
	--[[
		THE CENTRAL NORMALIZATION PROPERTY.

		At identical PP, identical raw EV and identical budget state, every class
		and lift must advance by the same NORMALIZED amount:

			deltaPP = deltaCN / P

		Kilograms differ -- a 120 kg squatter gains more kg than a 59 kg bencher
		-- but progression rate does not. That is what makes weight class a
		choice about identity and records rather than about pacing.
	]]
	local targetPP = 0.60
	local rawEV = 1.0

	local minPP = math.huge
	local maxPP = -math.huge
	local count = 0
	local minLabel = ""
	local maxLabel = ""

	for _, lift in ipairs(LIFTS) do
		for _, label in ipairs(CAPPED) do
			local reference = ProgressionReferenceConfig.get(lift, label) :: number
			local cn = reference * targetPP

			local award = CompetitionNumberReward.calculate(lift, label, cn, rawEV, FRESH)

			if award == nil then
				check(string.format("%s %s produces an award", label, lift), false, "rejected")
			else
				local a = award :: any
				count += 1

				if a.deltaPP < minPP then
					minPP = a.deltaPP
					minLabel = string.format("%s %s", label, lift)
				end
				if a.deltaPP > maxPP then
					maxPP = a.deltaPP
					maxLabel = string.format("%s %s", label, lift)
				end

				-- Each one must also agree with Hill x BaseProgressRate x EV directly.
				check(
					string.format("%s %s: deltaPP = BPR x effEV x Hill", label, lift),
					near(a.deltaPP, BPR * a.effectiveEV * a.hillMultiplier, 1e-15)
				)
			end
		end
	end

	local spread = maxPP - minPP
	local relative = if minPP > 0 then spread / minPP else math.huge

	print(string.format("      combinations : %d", count))
	print(string.format("      min deltaPP  : %.17g   (%s)", minPP, minLabel))
	print(string.format("      max deltaPP  : %.17g   (%s)", maxPP, maxLabel))
	print(string.format("      rel. spread  : %.3e", relative))

	check("all 21 combinations produced an award", count == 21, tostring(count))
	check(
		"deltaPP is IDENTICAL across all 21 within floating point",
		relative < 1e-12,
		string.format("relative spread %.3e", relative)
	)

	-- And the kilograms genuinely do differ, which is the other half of R2.
	local lightest = CompetitionNumberReward.calculate(
		"Bench", "59 kg",
		(ProgressionReferenceConfig.get("Bench", "59 kg") :: number) * targetPP,
		rawEV, FRESH
	)
	local heaviest = CompetitionNumberReward.calculate(
		"Squat", "120 kg",
		(ProgressionReferenceConfig.get("Squat", "120 kg") :: number) * targetPP,
		rawEV, FRESH
	)

	check(
		"while the KILOGRAMS differ, as intended",
		lightest ~= nil and heaviest ~= nil and (heaviest :: any).deltaCN > 2 * (lightest :: any).deltaCN,
		if lightest ~= nil and heaviest ~= nil
			then string.format("%.4f kg vs %.4f kg", (lightest :: any).deltaCN, (heaviest :: any).deltaCN)
			else "nil"
	)
end

--------------------------------------------------------------------------------
print("")
print("21-22. representative 59 kg and 120 kg rewards, rawEV = 1.0, fresh budget")
do
	local combos = {
		{ "Squat", "59 kg" }, { "Bench", "59 kg" }, { "Deadlift", "59 kg" },
		{ "Squat", "120 kg" }, { "Bench", "120 kg" }, { "Deadlift", "120 kg" },
	}
	local proximities = { 0.20, 0.60, 0.85, 1.00 }

	print("      lift / class      |   PP |         P | CN before |   Hill |    dCN |  CN after")
	print("      ----------------------------------------------------------------------------------")

	local allPositive = true
	local allShrinking = true

	for _, combo in ipairs(combos) do
		local lift = combo[1] :: string
		local label = combo[2] :: string
		local previousDelta = math.huge

		for _, pp in ipairs(proximities) do
			local reference = ProgressionReferenceConfig.get(lift, label) :: number
			local cn = reference * pp
			local award = CompetitionNumberReward.calculate(lift, label, cn, 1.0, FRESH)

			if award == nil then
				allPositive = false
			else
				local a = award :: any
				print(string.format(
					"      %-8s %-8s | %3.0f%% | %9.4f | %9.4f | %.4f | %6.4f | %9.4f",
					lift, label, 100 * pp, a.progressionReference, a.competitionNumberBefore,
					a.hillMultiplier, a.deltaCN, a.competitionNumberAfter
				))

				if a.deltaCN <= 0 then
					allPositive = false
				end
				if a.deltaCN >= previousDelta then
					allShrinking = false
				end
				previousDelta = a.deltaCN
			end
		end
	end

	check("every representative award is above zero", allPositive)
	check("and each award shrinks as PP rises, within every lift/class", allShrinking)

	-- The headline comparison the matrix exists to demonstrate.
	local light = CompetitionNumberReward.calculate(
		"Bench", "59 kg", (ProgressionReferenceConfig.get("Bench", "59 kg") :: number) * 0.60, 1.0, FRESH
	)
	local heavy = CompetitionNumberReward.calculate(
		"Squat", "120 kg", (ProgressionReferenceConfig.get("Squat", "120 kg") :: number) * 0.60, 1.0, FRESH
	)

	if light ~= nil and heavy ~= nil then
		local l = light :: any
		local h = heavy :: any
		check(
			"heavier reference gains more kg at the same PP",
			h.deltaCN > l.deltaCN,
			string.format("%.4f vs %.4f kg", h.deltaCN, l.deltaCN)
		)
		check(
			"but the SAME normalized rate",
			near(h.deltaPP, l.deltaPP, 1e-15),
			string.format("%.17g vs %.17g", h.deltaPP, l.deltaPP)
		)
	end
end

--------------------------------------------------------------------------------
print("")
print("23. delta CN per unit of budget consumed is EV-magnitude independent")
do
	--[[
		THE FAILURE-CREDIT CHECKS THAT USED TO LIVE HERE ARE GONE.

		They asserted that a failed attempt was worth exactly 20% of the same
		attempt succeeded, and that a failure still awarded above zero. Both
		rules were superseded by GAME_DESIGN.md section 33.6: a failed attempt
		now yields zero EV, so there is no ratio left to assert and nothing above
		zero to award. `ProgressionConfig.FailureCredit` was removed with them.

		What remains is the part that was never about failure at all. At a fixed
		budget state, delta CN per unit of budget consumed must not depend on how
		large the EV amount is -- the engine must not pay a better rate for one
		big award than for one small one. The two magnitudes below are arbitrary;
		any two would do.
	]]
	local reference = ProgressionReferenceConfig.get("Squat", "83 kg") :: number
	local cn = reference * 0.60

	local big = CompetitionNumberReward.calculate("Squat", "83 kg", cn, 1.0, FRESH) :: any
	local small = CompetitionNumberReward.calculate("Squat", "83 kg", cn, 0.2, FRESH) :: any
	local bigRatio = big.deltaCN / (big.budgetBefore - big.budgetAfter)
	local smallRatio = small.deltaCN / (small.budgetBefore - small.budgetAfter)

	check(
		"delta CN per unit of budget consumed is the same at either magnitude",
		near(bigRatio, smallRatio, 1e-9),
		string.format("%.10f vs %.10f", bigRatio, smallRatio)
	)
end

--------------------------------------------------------------------------------
print("")
print("24. no internal Competition Number rounding")
do
	local reference = ProgressionReferenceConfig.get("Bench", "59 kg") :: number
	local cn = reference * 0.60

	-- A deliberately awkward EV, so a rounded result would be obvious.
	local award = CompetitionNumberReward.calculate("Bench", "59 kg", cn, 0.37, FRESH)

	if award == nil then
		check("the award was produced", false)
	else
		local a = award :: any

		check("delta CN carries a fractional part", a.deltaCN % 1 ~= 0, string.format("%.17g", a.deltaCN))
		check("CN after carries a fractional part", a.competitionNumberAfter % 1 ~= 0)
		check("delta CN is not a multiple of 0.5", a.deltaCN % 0.5 ~= 0)
		check("delta CN is not a multiple of 0.1", not near(a.deltaCN % 0.1, 0, 1e-12))
		check("delta CN is not a multiple of 2.5", a.deltaCN % 2.5 ~= 0)

		--[[
			An award far smaller than any display precision must still be
			carried, because AFK and daily gains are genuinely this small at
			high PP and discarding them would silently lose progression.
		]]
		local atRecord = CompetitionNumberReward.calculate("Bench", "59 kg", reference, 0.2591, FRESH)
		check(
			"a sub-0.1 kg award is preserved rather than discarded",
			atRecord ~= nil and (atRecord :: any).deltaCN > 0 and (atRecord :: any).deltaCN < 0.1,
			if atRecord ~= nil then string.format("%.17g kg", (atRecord :: any).deltaCN) else "nil"
		)
	end
end

--------------------------------------------------------------------------------
print("")
print("25. 120+ is explicitly unsupported")
do
	--[[
		No finalized 120+ reward rule exists in GAME_DESIGN.md. Its basis must be
		unbounded-but-increasingly-difficult, which is a different system from
		the capped-class allometric fit.

		What MUST NOT happen is a silent fallback. Three specific wrong answers
		are checked for.
	]]
	for _, lift in ipairs(LIFTS) do
		local award, reason = CompetitionNumberReward.calculate(lift, "120+ kg", 400, 1.0, FRESH)

		check(string.format("%s 120+ returns no award", lift), award == nil)
		check(
			string.format("%s 120+ reports UnsupportedClass, not a generic error", lift),
			reason == "UnsupportedClass",
			tostring(reason)
		)
	end

	-- It must not silently use the 120 kg reference.
	check(
		"the table has no 120+ reference at all",
		ProgressionReferenceConfig.get("Squat", "120+ kg") == nil
	)
	check(
		"120+ is not reported as a capped class",
		not ProgressionReferenceConfig.isCappedClass("120+ kg")
	)

	--[[
		And the distinction between "unsupported" and "unknown" is preserved:
		120+ is a real class we do not yet serve, while "77 kg" is not a class.
	]]
	local _, unsupported = CompetitionNumberReward.calculate("Squat", "120+ kg", 400, 1.0, FRESH)
	local _, invalid = CompetitionNumberReward.calculate("Squat", "77 kg", 400, 1.0, FRESH)
	check(
		"unsupported and invalid classes are distinguishable",
		unsupported == "UnsupportedClass" and invalid == "InvalidClass",
		string.format("%s / %s", tostring(unsupported), tostring(invalid))
	)
end

--------------------------------------------------------------------------------
print("26. section 34 daily training configuration")
do
	local DT = ProgressionConfig.DailyTraining

	--[[
		THE ONE THAT MATTERS MOST. Checkpoint 5B.2 added a SECOND progression rate
		to the config, and the only way that could go wrong is the reward engine
		picking up the wrong one. So this asserts the live value, the proposed
		value, that they differ, and -- behaviourally -- that an actual award still
		uses the live one.
	]]
	check("live BaseProgressRate is still 0.00482389", near(BPR, 0.00482389, 1e-12),
		string.format("%.11f", BPR))
	check("ProposedBaseProgressRate is 0.01113418",
		near(ProgressionConfig.ProposedBaseProgressRate, 0.01113418, 1e-12),
		string.format("%.11f", ProgressionConfig.ProposedBaseProgressRate))
	check("the proposed rate is NOT the live rate",
		ProgressionConfig.ProposedBaseProgressRate ~= BPR)

	--[[
		Behavioural, not a restatement. If anything ever reads the candidate by
		mistake, this award comes out 2.31x too large and this check fails.
	]]
	local reference = ProgressionReferenceConfig.get("Squat", "59 kg") :: number
	local award = CompetitionNumberReward.calculate("Squat", "59 kg", reference * 1e-6, 1.0, FRESH)

	check(
		"an award still uses the LIVE rate, not the candidate",
		award ~= nil and near((award :: any).deltaCN, reference * BPR, 1e-6),
		if award ~= nil
			then string.format("%.8f, candidate would give %.8f",
				(award :: any).deltaCN, reference * ProgressionConfig.ProposedBaseProgressRate)
			else "nil"
	)

	----------------------------------------------------------------------------
	-- THE APPROVED VALUES, PINNED. An accidental balancing edit fails here.
	----------------------------------------------------------------------------
	check("DailyCapEV is 4.00 [FINAL]", near(DT.DailyCapEV, 4.00), tostring(DT.DailyCapEV))
	check("BaseRate is 1.00 EV/hour", near(DT.BaseRate, 1.00), tostring(DT.BaseRate))
	check("FullRateHours is 2.00", near(DT.FullRateHours, 2.00), tostring(DT.FullRateHours))
	check("K is 2.00", near(DT.K, 2.00), tostring(DT.K))
	check("TechniqueRawPerHour is 2.00", near(DT.TechniqueRawPerHour, 2.00),
		tostring(DT.TechniqueRawPerHour))
	check("there is NO technique earning cap (5B.7): DailyCapTechniqueRaw is gone",
		(DT :: any).DailyCapTechniqueRaw == nil)
	check("TechniquePrimaryShare is 0.80 [FINAL]", near(DT.TechniquePrimaryShare, 0.80),
		tostring(DT.TechniquePrimaryShare))

	----------------------------------------------------------------------------
	--[[
		THE SECONDARY SHARE IS DERIVED, NEVER STORED, so this asserts the
		derivation rather than a second constant. 80/20 of an hour's 2.00 raw
		points is 1.60 and 0.40, and the fact that those are not integers is
		exactly why section 34.12 requires fractional storage.
	]]
	----------------------------------------------------------------------------
	local secondaryShare = 1 - DT.TechniquePrimaryShare

	check("the derived secondary share is 0.20", near(secondaryShare, 0.20),
		tostring(secondaryShare))
	check("the two shares sum to exactly one whole award",
		near(DT.TechniquePrimaryShare + secondaryShare, 1.0))
	check("an hour of technique splits 1.60 / 0.40",
		near(DT.TechniquePrimaryShare * DT.TechniqueRawPerHour, 1.60)
			and near(secondaryShare * DT.TechniqueRawPerHour, 0.40),
		string.format("%.4f / %.4f",
			DT.TechniquePrimaryShare * DT.TechniqueRawPerHour,
			secondaryShare * DT.TechniqueRawPerHour))
	check("neither share is a whole number of points, so storage must be fractional",
		DT.TechniquePrimaryShare * DT.TechniqueRawPerHour % 1 ~= 0)

	----------------------------------------------------------------------------
	--[[
		THE TWO RELATIONSHIP INVARIANTS, restated here so a failure is a readable
		line rather than a startup crash. The config asserts these on module load,
		which is the real guard; these exist so a reader of this probe can see WHAT
		is guarded and why.
	]]
	----------------------------------------------------------------------------
	check("the cap is NOT reachable inside the full-rate window, so H(t) engages",
		DT.DailyCapEV > DT.BaseRate * DT.FullRateHours,
		string.format("%.4f vs %.4f", DT.DailyCapEV, DT.BaseRate * DT.FullRateHours))
	check("the full-rate window delivers exactly half the daily cap",
		near(DT.BaseRate * DT.FullRateHours / DT.DailyCapEV, 0.50))

	----------------------------------------------------------------------------
	--[[
		SECTION 34.1 DECISION 3. The per-lift EV cap was removed because the
		account-wide cap is authoritative and a per-lift ceiling above it could
		never fire. Asserting its ABSENCE turns the decision into something a
		future edit cannot quietly undo.
	]]
	----------------------------------------------------------------------------
	check("there is NO per-lift EV cap", (DT :: any).PerLiftCapEV == nil)

	----------------------------------------------------------------------------
	--[[
		H(t) ITSELF IS NOT TESTED HERE, and must not be: checkpoint 5B.3 owns the
		maths and its tests. What this section proves is only that the PARAMETERS
		are the approved ones and that they are mutually consistent.

		For the record, the values they imply: 5.4366 hours for one lift to exhaust
		4.00 EV, 4.00 hours if the day is split so no lift exceeds FullRateHours,
		and a marginal rate of 36.8% of the opening rate by the time the cap is
		reached. 5B.3 is where those become assertions.
	]]
	----------------------------------------------------------------------------
	check("Hill is untouched by section 34", ProgressionConfig.Hill.h == 0.75
		and ProgressionConfig.Hill.m == 5)
	check("the three lifts are untouched", #ProgressionConfig.Lifts == 3)
end

--------------------------------------------------------------------------------
print("")
print(string.format("=== %d passed, %d failed ===", passed, failed))

if failed > 0 then
	warn("[CompetitionNumberRewardProbe] REWARD ENGINE HAS FAILING CHECKS. Do not wire it to gameplay.")
else
	print("[CompetitionNumberRewardProbe] set ENABLED back to false now that the run is finished.")
end
