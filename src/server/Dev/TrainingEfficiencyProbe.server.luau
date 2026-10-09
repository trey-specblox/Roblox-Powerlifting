--!strict
--[[
	TrainingEfficiencyProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Exercises the per-lift diminishing-efficiency maths of
	GAME_DESIGN.md section 34.4 on server start and prints a pass/fail line per
	check to the Studio Output window.

	Set ENABLED to false to silence it, or delete this file. Nothing requires it,
	it touches no player's data, it writes nothing, and it creates no remotes.

	WHY THIS NEEDS NO PLAYER AND NO CLOCK

	TrainingEfficiency is pure and takes HOURS as a number rather than
	timestamps, so a whole day of training is one arithmetic call. That is also
	what lets the sweeps below walk 0 to 24 hours in hundredths without waiting.

	WHAT IT PROVES, AND WHAT IT DELIBERATELY DOES NOT

	It proves the SHAPE: the published formula, the section 34.4 table, exact
	additivity, monotonicity, continuity at the full-rate boundary, and the
	analytic inverse.

	It does NOT prove anything about allowances, day keys, stations or writes.
	The 4.00 EV cap is ACCOUNT-WIDE and this module is per lift, so clamping
	against it belongs to checkpoint 5B.4 and is tested there. Section 8 below
	asserts only that this module does not apply the cap itself.

	=========================================================================
	OFF BY DEFAULT. SET TO true TO RUN IT.
	=========================================================================

	Turn it on whenever the DailyTraining constants or this curve change, then
	turn it off again. The tests are not weakened or removed by the flag.
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
local TrainingEfficiency = require(ProgressionFolder:WaitForChild("TrainingEfficiency"))

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
	return math.abs(a - b) <= (tolerance or 0.0001)
end

local H = TrainingEfficiency.efficiency
local EV = TrainingEfficiency.cumulativeEV

print("=== Training efficiency probe (section 34.4) ===")
print(string.format(
	"  BaseRate %.2f EV/h  |  FullRateHours %.2f  |  K %.2f  |  DailyCapEV %.2f",
	TRAINING.BaseRate,
	TRAINING.FullRateHours,
	TRAINING.K,
	TRAINING.DailyCapEV
))
print("")

--------------------------------------------------------------------------------
print("1. H(t) = 1 through the full-rate window")
do
	check("H(0) = 1", near(H(0), 1.0), tostring(H(0)))
	check("H(0.5) = 1", near(H(0.5), 1.0))
	check("H(1) = 1", near(H(1), 1.0))
	check("H(1.999) = 1", near(H(1.999), 1.0))

	--[[
		THE BOUNDARY ITSELF IS STILL FULL RATE. H(t) = 1 for t <= FullRateHours,
		so the two-hour mark is the last instant of full efficiency rather than
		the first instant of decay.
	]]
	check("H(2) = 1, the boundary is inclusive", near(H(TRAINING.FullRateHours), 1.0),
		tostring(H(TRAINING.FullRateHours)))

	-- And decay has begun immediately after it.
	check("H(2.001) is below 1", H(2.001) < 1.0, tostring(H(2.001)))
end

--------------------------------------------------------------------------------
print("2. the decay, and the section 34.4 figures")
do
	--[[
		H(4) = K / (K + 4 - F) = 2 / (2 + 2) = 0.5. Half rate after four hours,
		which is the figure the brief calls out.
	]]
	check("H(4) = 0.5", near(H(4), 0.5), tostring(H(4)))

	check("H(3) = 0.6667", near(H(3), 2 / 3), tostring(H(3)))
	check("H(5) = 0.4000", near(H(5), 0.4), tostring(H(5)))

	--[[
		THE MARGINAL RATE WHERE ONE LIFT EXHAUSTS THE CAP. 36.8% of the opening
		rate, which is section 34.4's argument for the harmonic shape: still
		clearly worth something, clearly not worth grinding.
	]]
	local capHours = TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV)

	check("H(t*) = 0.3679, so 36.8% of the opening rate", near(H(capHours), 1 / math.exp(1)),
		string.format("%.6f", H(capHours)))

	--[[
		THE IMPLEMENTED FORM MUST EQUAL THE PUBLISHED FORM.

		The module computes K / (K + t - F); section 34.4 publishes
		1 / (1 + (t - F) / K). They are the same curve rearranged, and this sweep
		is what stops the rearrangement silently drifting from the document.
	]]
	local worstFormGap = 0

	for step = 0, 2400 do
		local t = step / 100
		local published = 1 / (1 + math.max(0, t - TRAINING.FullRateHours) / TRAINING.K)
		local gap = math.abs(H(t) - published)

		if gap > worstFormGap then
			worstFormGap = gap
		end
	end

	check("the implemented H(t) matches section 34.4's published form across 0 to 24 h",
		worstFormGap < 1e-12, string.format("worst gap %.3e", worstFormGap))
end

--------------------------------------------------------------------------------
print("3. H(t) is nonincreasing, and never reaches zero")
do
	local violations = 0
	local worstRise = 0
	local previous = H(0)

	for step = 1, 2400 do
		local t = step / 100
		local current = H(t)

		if current > previous + 1e-12 then
			violations += 1
			local rise = current - previous
			if rise > worstRise then
				worstRise = rise
			end
		end

		previous = current
	end

	check("H(t) never rises across 0 to 24 h in 0.01 h steps", violations == 0,
		string.format("%d violations, worst rise %.3e", violations, worstRise))

	--[[
		NEVER ZERO, EVER. A thousand hours on one lift still pays something. The
		harmonic shape is what guarantees this; an exponential would underflow to
		zero and a cliff would be zero by construction.
	]]
	check("H(1000) is still above zero", H(1000) > 0, string.format("%.3e", H(1000)))
	check("H(1e6) is still above zero", H(1e6) > 0, string.format("%.3e", H(1e6)))
end

--------------------------------------------------------------------------------
print("4. EV(t) -- the required values")
do
	check("EV(0) = 0", near(EV(0), 0), tostring(EV(0)))
	check("EV(1) = 1.0000", near(EV(1), 1.0), tostring(EV(1)))
	check("EV(2) = 2.0000", near(EV(2), 2.0), tostring(EV(2)))
	check("EV(3) = 2.8109", near(EV(3), 2.8109), string.format("%.6f", EV(3)))
	check("EV(4) = 3.3863", near(EV(4), 3.3863), string.format("%.6f", EV(4)))
	check("EV(5) = 3.8326", near(EV(5), 3.8326), string.format("%.6f", EV(5)))
	check("EV(5.4366) = 4.0000", near(EV(5.4366), 4.0, 0.0002), string.format("%.6f", EV(5.4366)))

	--[[
		THE EXACT t*. 5.4366 is a rounded display value; the closed form is
		F + K(e - 1) = 2 + 2(e - 1), and EV at that point is the cap to full
		double precision.
	]]
	local exactCapHours = TRAINING.FullRateHours + TRAINING.K * (math.exp(1) - 1)

	check("the exact t* is 2 + 2(e - 1)", near(exactCapHours, 5.43656365691809, 1e-10),
		string.format("%.14f", exactCapHours))
	check("EV(t*) is the daily cap to 1e-12", near(EV(exactCapHours), TRAINING.DailyCapEV, 1e-12),
		string.format("%.14f", EV(exactCapHours)))
end

--------------------------------------------------------------------------------
print("5. the section 34.4 hour table, reproduced")
do
	--[[
		Cumulative EV, the EV earned during each hour, and the share of the daily
		cap. If the curve is ever retuned this table is what will show how the
		player experience moved.
	]]
	local expected = {
		{ hour = 1, cumulative = 1.0000, thisHour = 1.0000, share = 0.250 },
		{ hour = 2, cumulative = 2.0000, thisHour = 1.0000, share = 0.500 },
		{ hour = 3, cumulative = 2.8109, thisHour = 0.8109, share = 0.703 },
		{ hour = 4, cumulative = 3.3863, thisHour = 0.5754, share = 0.847 },
		{ hour = 5, cumulative = 3.8326, thisHour = 0.4463, share = 0.958 },
	}

	for _, row in ipairs(expected) do
		local cumulative = EV(row.hour)
		local thisHour = TrainingEfficiency.accrue(row.hour - 1, 1)
		local share = cumulative / TRAINING.DailyCapEV

		check(
			string.format("hour %d: cumulative %.4f, this hour %.4f, %.1f%% of the cap",
				row.hour, row.cumulative, row.thisHour, row.share * 100),
			near(cumulative, row.cumulative, 0.0001)
				and near(thisHour, row.thisHour, 0.0001)
				and near(share, row.share, 0.001),
			string.format("got %.4f / %.4f / %.1f%%", cumulative, thisHour, share * 100)
		)
	end

	--[[
		THE FRONT-LOADING IS THE DESIGN. Half the cap in the first two hours, and
		the last 0.44 hours worth only 4.2%. That shape is why section 34.3 needs
		no hard training-hour limit: the tail stops being worth standing for on
		its own.
	]]
	check("the first two hours deliver half the daily cap",
		near(EV(2) / TRAINING.DailyCapEV, 0.50), string.format("%.4f", EV(2) / TRAINING.DailyCapEV))
	check("four hours deliver 84.7% of the cap",
		near(EV(4) / TRAINING.DailyCapEV, 0.8466, 0.0005),
		string.format("%.4f", EV(4) / TRAINING.DailyCapEV))

	local capHours = TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV)

	check("the final stretch past hour 5 is worth only 4.2% of the cap",
		near((TRAINING.DailyCapEV - EV(5)) / TRAINING.DailyCapEV, 0.0418, 0.0005),
		string.format("%.4f over %.4f h", (TRAINING.DailyCapEV - EV(5)) / TRAINING.DailyCapEV, capHours - 5))
end

--------------------------------------------------------------------------------
print("6. EV(t) is continuous and strictly increasing")
do
	--[[
		CONTINUITY AT THE FULL-RATE BOUNDARY is the one place a piecewise formula
		can produce a step. At t = F the log term is ln(1) = 0, so both branches
		give BaseRate x F. A tick that straddles the boundary therefore needs no
		special case.
	]]
	local F = TRAINING.FullRateHours
	local below = EV(F - 1e-9)
	local at = EV(F)
	local above = EV(F + 1e-9)

	check("EV is continuous at the full-rate boundary", near(below, at, 1e-8) and near(at, above, 1e-8),
		string.format("%.12f / %.12f / %.12f", below, at, above))
	check("EV(F) is exactly BaseRate x FullRateHours", near(at, TRAINING.BaseRate * F, 1e-12))

	-- STRICTLY increasing: more hours is always more EV, never equal.
	local violations = 0
	local worstDrop = 0
	local previous = EV(0)

	for step = 1, 2400 do
		local t = step / 100
		local current = EV(t)

		if current <= previous then
			violations += 1
			local drop = previous - current
			if drop > worstDrop then
				worstDrop = drop
			end
		end

		previous = current
	end

	check("EV(t) strictly increases across 0 to 24 h in 0.01 h steps", violations == 0,
		string.format("%d violations, worst drop %.3e", violations, worstDrop))
end

--------------------------------------------------------------------------------
print("7. accrual is a difference of integrals, and exactly additive")
do
	--[[
		THE DEFINING PROPERTY. A tick must award EV(end) - EV(start), because
		sampling H(t) once and multiplying by the tick length would make the
		result depend on how often the server ticks.
	]]
	local violations = 0

	for step = 0, 40 do
		local startHours = step / 4
		local added = 0.37
		local viaAccrue = TrainingEfficiency.accrue(startHours, added)
		local viaDifference = EV(startHours + added) - EV(startHours)

		if not near(viaAccrue, viaDifference, 1e-12) then
			violations += 1
		end
	end

	check("accrue(a, b) equals EV(a + b) - EV(a) at every tested offset", violations == 0,
		string.format("%d mismatches", violations))

	--[[
		TELESCOPING. A hundred six-minute ticks must total the same as one
		five-hour tick. This is the test that would catch an implementation which
		approximated the integral per tick instead of differencing it.
	]]
	local manySmall = 0
	local hours = 0

	for _ = 1, 100 do
		manySmall += TrainingEfficiency.accrue(hours, 0.05)
		hours += 0.05
	end

	local oneLarge = TrainingEfficiency.accrue(0, 5.0)

	check("100 ticks of 0.05 h total the same as one tick of 5.00 h",
		near(manySmall, oneLarge, 1e-9), string.format("%.12f vs %.12f", manySmall, oneLarge))
	check("that total is EV(5.00)", near(manySmall, EV(5.0), 1e-9))

	-- Ticks that straddle the boundary must not be special-cased wrongly.
	check("a tick from 1.5 h to 2.5 h straddles the boundary correctly",
		near(TrainingEfficiency.accrue(1.5, 1.0), EV(2.5) - EV(1.5), 1e-12),
		string.format("%.10f", TrainingEfficiency.accrue(1.5, 1.0)))

	-- A zero-length tick is exactly zero, not a rounding artefact.
	check("a zero-length tick awards exactly 0", TrainingEfficiency.accrue(3.0, 0) == 0,
		tostring(TrainingEfficiency.accrue(3.0, 0)))
	check("a zero-length tick at zero hours awards exactly 0", TrainingEfficiency.accrue(0, 0) == 0)

	-- Accrual is always positive for a positive tick, however deep the decay.
	check("a tick at 100 h still awards something", TrainingEfficiency.accrue(100, 0.5) > 0,
		string.format("%.3e", TrainingEfficiency.accrue(100, 0.5)))
end

--------------------------------------------------------------------------------
print("8. this module never applies the account-wide cap")
do
	--[[
		Section 34.1 decision 2 makes the cap ACCOUNT-WIDE, and decision 3 removed
		the per-lift cap entirely. A per-lift module is the wrong scope to enforce
		an account limit, so it must keep answering honestly past the ceiling.
		Clamping belongs to checkpoint 5B.4.
	]]
	check("EV keeps rising past the daily cap", EV(10) > TRAINING.DailyCapEV,
		string.format("%.4f vs cap %.4f", EV(10), TRAINING.DailyCapEV))
	check("EV(24) is the 24-hour single-lift maximum, 6.9698", near(EV(24), 6.9698, 0.0005),
		string.format("%.6f", EV(24)))
	check("EV(100) is larger still, with no ceiling", EV(100) > EV(24))

	--[[
		THE INVARIANT DEFERRED FROM 5B.2. The cap must be reachable at all by a
		single lift within a day, or it would never bind and section 34.10's
		"concentrating costs time" would become "concentrating is impossible".
		TrainingEfficiency asserts this at module load; this restates it as a
		readable line rather than a startup crash.
	]]
	check("the single-lift daily cap is reachable within 24 hours",
		EV(24) >= TRAINING.DailyCapEV,
		string.format("EV(24) = %.4f, cap = %.4f", EV(24), TRAINING.DailyCapEV))
	check("and it is reached well inside the day, at 5.4366 h",
		near(TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV), 5.4366, 0.0001),
		string.format("%.6f h", TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV)))
end

--------------------------------------------------------------------------------
print("9. hoursToReach is the exact inverse of EV")
do
	check("hoursToReach(0) = 0", near(TrainingEfficiency.hoursToReach(0), 0))
	check("hoursToReach(1.00) = 1.00 h, inside the full-rate window",
		near(TrainingEfficiency.hoursToReach(1.0), 1.0))
	check("hoursToReach(2.00) = 2.00 h, exactly the boundary",
		near(TrainingEfficiency.hoursToReach(2.0), 2.0))
	check("hoursToReach(4.00) = 5.4366 h",
		near(TrainingEfficiency.hoursToReach(4.0), 5.43656, 0.0001),
		string.format("%.6f", TrainingEfficiency.hoursToReach(4.0)))

	-- ROUND TRIP, both directions, across and past the boundary.
	local violations = 0
	local worstGap = 0

	for step = 0, 120 do
		local t = step / 10
		local round = TrainingEfficiency.hoursToReach(EV(t))
		local gap = math.abs(round - t)

		if gap > 1e-9 then
			violations += 1
		end
		if gap > worstGap then
			worstGap = gap
		end
	end

	check("hoursToReach(EV(t)) returns t for 0 to 12 h", violations == 0,
		string.format("%d violations, worst gap %.3e", violations, worstGap))

	local evViolations = 0

	for step = 0, 70 do
		local target = step / 10
		local gap = math.abs(EV(TrainingEfficiency.hoursToReach(target)) - target)

		if gap > 1e-9 then
			evViolations += 1
		end
	end

	check("EV(hoursToReach(e)) returns e for 0 to 7 EV", evViolations == 0,
		string.format("%d violations", evViolations))
end

--------------------------------------------------------------------------------
print("10. three lifts, one stateless module: switching resets nothing")
do
	--[[
		THE MODULE HAS NO PER-LIFT STATE, because the per-lift part is the
		argument. These counters stand in for the profile's trainingTimeToday
		record (section 34.12), which is what actually persists them.
	]]
	local hours = { Squat = 0, Bench = 0, Deadlift = 0 }
	local accountEV = 0

	-- Two hours of Squat at full rate.
	accountEV += TrainingEfficiency.accrue(hours.Squat, 2.0)
	hours.Squat += 2.0

	check("Squat earned 2.00 EV in its first two hours", near(accountEV, 2.0), tostring(accountEV))

	-- SWITCH to Bench. Bench has its own clock and starts at full rate.
	accountEV += TrainingEfficiency.accrue(hours.Bench, 2.0)
	hours.Bench += 2.0

	check("Bench also earned 2.00 EV, because its own clock was at zero",
		near(accountEV, 4.0), tostring(accountEV))
	check("Squat's banked hours were untouched by the switch", near(hours.Squat, 2.0))

	--[[
		SWITCH BACK. This is the assertion that matters: Squat resumes at t = 2.00,
		so its third hour is worth 0.8109 and NOT the 1.0000 it would be if the
		switch had reset its clock.
	]]
	local squatThirdHour = TrainingEfficiency.accrue(hours.Squat, 1.0)

	check("returning to Squat resumes at t = 2.00, so hour three pays 0.8109",
		near(squatThirdHour, 0.8109, 0.0001), string.format("%.6f", squatThirdHour))
	check("it is NOT the 1.0000 a reset clock would have paid",
		not near(squatThirdHour, 1.0, 0.01))

	--[[
		THE SECTION 34.10 HEADLINE, in two lines. A split day reaches the account
		cap in 4.00 hours; one lift needs 5.4366. Concentrating costs 1.44 hours
		of wall clock for identical progression.
	]]
	check("a day split across two lifts reaches the 4.00 EV cap in 4.00 hours",
		near(hours.Squat + hours.Bench, 4.0) and near(accountEV, TRAINING.DailyCapEV),
		string.format("%.2f h for %.4f EV", hours.Squat + hours.Bench, accountEV))

	local concentratedHours = TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV)

	check("one lift alone needs 5.4366 hours for the same 4.00 EV",
		near(concentratedHours, 5.4366, 0.0001), string.format("%.4f h", concentratedHours))
	check("so concentrating costs 1.4366 extra hours, and no progression",
		near(concentratedHours - 4.0, 1.4366, 0.0001),
		string.format("%.4f h", concentratedHours - 4.0))

	--[[
		A THIRD LIFT CHANGES NOTHING ABOUT THE OTHERS. Three lifts at 1.333 h each
		also reach 4.00 EV in 4.00 hours, because none of them leaves full rate.
	]]
	local third = { Squat = 0, Bench = 0, Deadlift = 0 }
	local thirdEV = 0

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		thirdEV += TrainingEfficiency.accrue(third[lift], 4 / 3)
		third[lift] += 4 / 3
	end

	check("three lifts at 1.3333 h each also reach the cap in 4.00 hours",
		near(thirdEV, TRAINING.DailyCapEV, 0.0001), string.format("%.6f", thirdEV))
end

--------------------------------------------------------------------------------
print("11. invalid input is refused rather than coerced")
do
	--[[
		A NEGATIVE HOUR COUNT IS A CALLER BUG, and the safe direction for a GRANT
		is to refuse it. Clamping a backward clock step to zero elapsed is the
		caller's job -- ResourceRegeneration already does exactly that for the
		regenerating resources.
	]]
	check("negative hours are rejected", not (pcall(H, -1)))
	check("NaN hours are rejected", not (pcall(H, 0 / 0)))
	check("infinite hours are rejected", not (pcall(H, math.huge)))
	check("a string is rejected", not (pcall(H, ("2" :: any))))

	check("negative hours are rejected by cumulativeEV", not (pcall(EV, -0.001)))
	check("NaN is rejected by cumulativeEV", not (pcall(EV, 0 / 0)))

	check("a negative tick length is rejected", not (pcall(TrainingEfficiency.accrue, 1.0, -0.5)))
	check("a negative starting point is rejected", not (pcall(TrainingEfficiency.accrue, -1.0, 0.5)))
	check("a negative target EV is rejected", not (pcall(TrainingEfficiency.hoursToReach, -1)))
	check("an infinite target EV is rejected", not (pcall(TrainingEfficiency.hoursToReach, math.huge)))

	-- And the legal edges are accepted.
	check("zero hours is accepted", (pcall(H, 0)))
	check("a zero tick is accepted", (pcall(TrainingEfficiency.accrue, 0, 0)))
	check("a zero target EV is accepted", (pcall(TrainingEfficiency.hoursToReach, 0)))
end

--------------------------------------------------------------------------------
print("12. the module is pure: no clock, no state, no mutation")
do
	--[[
		NO TIMESTAMP PARAMETER ANYWHERE. Unlike a regenerating resource, this
		cannot be made to behave differently by a clock, because it never sees
		one. Asserted via arity so it cannot be quietly changed.
	]]
	check("efficiency takes exactly one argument", debug.info(H, "a") == 1,
		tostring(debug.info(H, "a")))
	check("cumulativeEV takes exactly one argument", debug.info(EV, "a") == 1)
	check("accrue takes exactly two arguments", debug.info(TrainingEfficiency.accrue, "a") == 2)
	check("hoursToReach takes exactly one argument",
		debug.info(TrainingEfficiency.hoursToReach, "a") == 1)

	-- IDEMPOTENT. The same input returns the same answer, however many times.
	local first = EV(3.7)

	for _ = 1, 50 do
		EV(3.7)
		H(3.7)
		TrainingEfficiency.accrue(1, 2)
	end

	check("repeated calls return identical results", EV(3.7) == first, string.format("%.14f", EV(3.7)))

	-- IT DOES NOT TOUCH THE CONFIG IT READS.
	check("the config is unchanged after every call above",
		TRAINING.BaseRate == 1.00
			and TRAINING.FullRateHours == 2.00
			and TRAINING.K == 2.00
			and TRAINING.DailyCapEV == 4.00)
end

--------------------------------------------------------------------------------
print("")
print(string.format("=== %d passed, %d failed ===", passed, failed))

if failed > 0 then
	warn("[TrainingEfficiencyProbe] THE EFFICIENCY CURVE HAS FAILING CHECKS. Do not build on it yet.")
else
	print("[TrainingEfficiencyProbe] set ENABLED back to false now that the run is finished.")
end
