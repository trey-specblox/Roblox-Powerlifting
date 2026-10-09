--!strict
--[[
	TrainingEfficiency
	Shared / Progression

	Per-lift diminishing efficiency for gym-station training, from GAME_DESIGN.md
	section 34.4.

	A lift's Competition Number efficiency decays with the hours already spent on
	THAT LIFT today. The first two hours pay full rate; after that the rate falls
	harmonically and never reaches zero.

	=========================================================================
	THE TWO FUNCTIONS, AND WHY THERE ARE TWO
	=========================================================================

		H(t)    the RATE multiplier at an instant
		EV(t)   the CUMULATIVE EV earned by hour t -- the integral of the rate

	A station tick cannot use H(t) alone. Multiplying H(t) by the tick length
	would sample the rate at one instant and pretend it held for the whole tick,
	which over-pays while the curve is falling and makes the result depend on how
	often the server ticks. Two players training the same hours would earn
	different amounts because one happened to be on a busier server.

	So accrual is always a DIFFERENCE OF INTEGRALS: `accrue` returns
	EV(before + added) - EV(before). That is exact for any tick length, and it is
	why a 1-second tick and a 1-minute tick produce identical totals.

	=========================================================================
	PURE, AND IN PARTICULAR CLOCK-FREE
	=========================================================================

	No state, no clock, no I/O, no mutation. Deterministic for a given config.

	It takes HOURS, never timestamps. That separation is deliberate: DayKey owns
	"which day is it", this module owns "how much is these hours worth", and the
	caller owns reading the clock. None of the three can be made to misbehave by
	the others.

	NEGATIVE OR NON-FINITE HOURS ASSERT RATHER THAN CLAMP. Hours reaching here
	are a server-side elapsed-time calculation, so a negative value is a caller
	bug, and the safe direction for a GRANT is to refuse it. Clamping elapsed
	time to zero when a clock steps backward is the CALLER's job -- see
	ResourceRegeneration, which already does exactly that for the regenerating
	resources. PlayerDataService.update pcalls its mutator, so an assert here
	refuses one tick rather than taking down a server.

	=========================================================================
	THIS MODULE NEVER APPLIES THE DAILY CAP
	=========================================================================

	Section 34.1 decision 2 makes the 4.00 EV cap ACCOUNT-WIDE, and section 34.1
	decision 3 removed the proposed per-lift cap entirely. This module is per
	lift, so it is the wrong scope to enforce an account limit and does not try:
	`cumulativeEV` keeps rising past the cap, forever, and a caller asking for
	the EV at twenty hours gets an honest answer.

	Clamping against the account allowance belongs to checkpoint 5B.4, which owns
	the allowance reader and the only place that knows how much the OTHER two
	lifts have already spent today.

	=========================================================================
	ONE STATELESS MODULE SERVES ALL THREE LIFTS
	=========================================================================

	There is nothing per-lift in here, because the per-lift part is the ARGUMENT.
	`efficiency(3.0)` means the same thing whichever lift banked those three
	hours, and the three hour counters live in the profile (section 34.12).

	SWITCHING LIFTS THEREFORE CANNOT RESET ANYTHING. There is no state to reset
	and no switch handler to get wrong. A lifter who trains Squat for two hours,
	switches to Bench, and later returns resumes Squat at t = 2.00 because the
	caller passes 2.00 -- not because anything here remembers.

	That is also the whole of section 34.10: because H(t) is per lift while the
	cap is per account, a day split across two lifts reaches the account cap in
	4.00 hours where concentrating on one takes 5.4366. Concentrating costs time,
	never progression.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local TrainingEfficiency = {}

local TRAINING = ProgressionConfig.DailyTraining

--[[
	Rejects anything that is not a finite number of zero or more.

	Zero is always legal: it is a lift that has not been trained today, and a tick
	of zero elapsed hours.
]]
local function requireHours(name: string, hours: any)
	assert(
		typeof(hours) == "number" and hours == hours,
		string.format("[TrainingEfficiency] %s must be a number, and not NaN", name)
	)
	assert(
		hours >= 0 and hours < math.huge,
		string.format("[TrainingEfficiency] %s must be finite and not negative, got %s", name, tostring(hours))
	)
end

--[[
	H(t). The efficiency multiplier after `hoursOnLiftToday` hours on ONE lift.

	1.0 through the full-rate window, then harmonic decay:

		H(t) = 1                        for t <= FullRateHours
		H(t) = K / (K + t - F)          for t >  FullRateHours

	THE SECOND FORM IS THE SAME CURVE AS SECTION 34.4's, rearranged:

		1 / (1 + (t - F) / K)  =  1 / ((K + t - F) / K)  =  K / (K + t - F)

	Written this way it is one division instead of two and cannot divide by a
	zero K twice over. The probe asserts both forms agree across a sweep, so the
	rearrangement cannot silently drift from the published formula.

	IT NEVER REACHES ZERO. That is the point of the harmonic shape rather than an
	exponential or a cliff: a player at the keyboard is never told their time is
	worth literally nothing, while the marginal rate still falls fast enough --
	36.8% of the opening rate by the time one lift has earned the whole daily
	cap -- that grinding a single lift all day is poor value.
]]
function TrainingEfficiency.efficiency(hoursOnLiftToday: number): number
	requireHours("hoursOnLiftToday", hoursOnLiftToday)

	if hoursOnLiftToday <= TRAINING.FullRateHours then
		return 1
	end

	local K = TRAINING.K

	return K / (K + hoursOnLiftToday - TRAINING.FullRateHours)
end

--[[
	EV(t). Total EV one lift has earned by `hoursOnLiftToday`, the integral of
	BaseRate x H(t):

		EV(t) = BaseRate x t                                     for t <= F
		EV(t) = BaseRate x (F + K x ln(1 + (t - F) / K))         for t >  F

	CONTINUOUS AT THE BOUNDARY. At t = F the second form reduces to
	BaseRate x (F + K x ln(1)) = BaseRate x F, which is exactly what the first
	form gives. There is no step at the moment decay begins, so a tick that
	straddles the boundary needs no special case.

	UNBOUNDED, AND DELIBERATELY SO. It keeps rising for as long as the hours do.
	See the header: the daily cap is account-wide and is applied by the caller.
]]
function TrainingEfficiency.cumulativeEV(hoursOnLiftToday: number): number
	requireHours("hoursOnLiftToday", hoursOnLiftToday)

	local baseRate = TRAINING.BaseRate
	local fullRateHours = TRAINING.FullRateHours

	if hoursOnLiftToday <= fullRateHours then
		return baseRate * hoursOnLiftToday
	end

	local K = TRAINING.K

	return baseRate * (fullRateHours + K * math.log(1 + (hoursOnLiftToday - fullRateHours) / K))
end

--[[
	The EV a tick earns: EV(hoursBefore + hoursAdded) - EV(hoursBefore).

	THIS IS THE FUNCTION A STATION TICK SHOULD CALL, and the subtraction is the
	whole implementation on purpose. Any cleverer formulation -- sampling H(t) at
	the midpoint, averaging the endpoints -- would introduce an error that depends
	on tick length, so identical play on a busy server and a quiet one would pay
	differently.

	Being a difference of the same integral also makes it exactly additive: ten
	ticks of six minutes award the same total as one tick of an hour, to within
	floating-point noise. The probe asserts that by telescoping a hundred small
	ticks against a single large one.

	A zero-length tick returns exactly 0 rather than a rounding artefact.
]]
function TrainingEfficiency.accrue(hoursBefore: number, hoursAdded: number): number
	requireHours("hoursBefore", hoursBefore)
	requireHours("hoursAdded", hoursAdded)

	if hoursAdded == 0 then
		return 0
	end

	return TrainingEfficiency.cumulativeEV(hoursBefore + hoursAdded)
		- TrainingEfficiency.cumulativeEV(hoursBefore)
end

--[[
	The inverse of EV(t): hours ONE lift must train to reach `targetEV`.

	Analytic, not a search:

		t = targetEV / BaseRate                                  for targetEV <= BaseRate x F
		t = F + K x (e^((targetEV / BaseRate - F) / K) - 1)      otherwise

	Exposed for two reasons. It is how section 34.4's headline 5.4366 hours is
	derived rather than quoted, and a station UI will want "time remaining" --
	which must not be computed by bisecting `cumulativeEV` when a closed form
	exists.

	It answers a PER-LIFT question. Asking for the hours to reach the account cap
	gives the single-lift worst case; a day split so no lift exceeds FullRateHours
	reaches the same cap in DailyCapEV / BaseRate hours.
]]
function TrainingEfficiency.hoursToReach(targetEV: number): number
	assert(
		typeof(targetEV) == "number" and targetEV == targetEV,
		"[TrainingEfficiency] targetEV must be a number, and not NaN"
	)
	assert(
		targetEV >= 0 and targetEV < math.huge,
		string.format("[TrainingEfficiency] targetEV must be finite and not negative, got %s", tostring(targetEV))
	)

	local baseRate = TRAINING.BaseRate
	local fullRateHours = TRAINING.FullRateHours
	local fullRateEV = baseRate * fullRateHours

	if targetEV <= fullRateEV then
		return targetEV / baseRate
	end

	local K = TRAINING.K

	return fullRateHours + K * (math.exp((targetEV / baseRate - fullRateHours) / K) - 1)
end

--[[
	=========================================================================
	THE INVARIANT DEFERRED FROM CHECKPOINT 5B.2
	=========================================================================

	ProgressionConfig asserts that the daily cap is not reachable INSIDE the
	full-rate window, which keeps H(t) relevant. The opposite bound belongs here,
	because it needs the integral: the cap must also be reachable AT ALL, by a
	single lift, within a day.

	If it were not, a player could train one lift for every waking hour and still
	never exhaust the allowance, so the cap would never bind and section 34.10's
	"concentrating costs time" would become "concentrating is impossible". The
	station would appear to work and the ceiling would be unreachable.

	At the approved values one lift earns at most 6.9698 EV in 24 hours against a
	4.00 cap, reaching it at 5.4366 hours.

	Checked at module load, in the real game, every time -- the same reasoning as
	ProgressionConfig's own assertions: a probe that defaults to disabled cannot
	catch a bad constant, and the edit being guarded against is a balancing
	change.
]]
local HOURS_IN_A_DAY = 24

assert(
	TrainingEfficiency.cumulativeEV(HOURS_IN_A_DAY) >= TRAINING.DailyCapEV,
	string.format(
		"[TrainingEfficiency] one lift can earn at most %.4f EV in %d hours, which cannot reach the "
			.. "%.4f EV daily cap. The cap would never bind. Lower DailyCapEV or raise BaseRate.",
		TrainingEfficiency.cumulativeEV(HOURS_IN_A_DAY),
		HOURS_IN_A_DAY,
		TRAINING.DailyCapEV
	)
)

return TrainingEfficiency
