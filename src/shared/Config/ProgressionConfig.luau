--!strict
--[[
	ProgressionConfig
	Shared / Config

	The constants of the Competition Number progression system, from
	GAME_DESIGN.md section 29, plus the daily training economy of section 34.

	WHAT IS AND IS NOT USED YET

	Only the RESOURCE constants -- Competition Budget and Training Energy
	capacity and regeneration -- are consumed by anything today. They drive
	ResourceRegeneration and the persistence foundation.

	BaseProgressRate and the Hill parameters are read by CompetitionNumberReward,
	which itself has no production callers yet. No attempt, daily or AFK tick
	awards Competition Number at present.

	THE WHOLE `DailyTraining` BLOCK IS UNCONSUMED. Checkpoint 5B.2 adds the
	numbers and nothing else: there is no gym station, no accrual tick, no timer
	and no writer. Section 34.14 sequences the maths as 5B.3, the allowance
	reader as 5B.4 and the station itself as 5B.6.

	Keeping them in one file now is what stops them being re-derived, slightly
	differently, by each system that eventually needs them.

	STATUS MARKERS, per the legend in GAME_DESIGN.md section 29:

		[FINAL]        an approved mechanic or rule. Same force as [FROZEN].
		[PROVISIONAL]  an approved mechanic's unvalidated number. Same force as
		               [TUNABLE], and deliberately louder: it has never run in a
		               real game and it WILL move.

	A [FINAL] rule may carry [PROVISIONAL] numbers, and most of section 34 does.
	Each value below is marked individually; do not read a block heading as
	freezing the figures under it.
]]

local ProgressionConfig = {}

--[[
	=========================================================================
	THE CORE FORMULA (section 29.3) -- NOT YET CONSUMED BY ANY SYSTEM
	=========================================================================

		PP       = CN / ProgressionReference(lift, class)
		Hill(PP) = 1 / (1 + (PP / h)^m)
		dCN      = ProgressionReference x BaseProgressRate x EV x Hill(PP) x BudgetMultiplier
]]

--[[
	One unit-quality attempt grants this fraction of the lift's Progression
	Reference, before the soft cap. 0.4824%.

	Solved backward from the P4 pacing target: the reference engaged player
	reaches PP 60% in approximately 8 weeks.

	EXPECTED TO BE RECALIBRATED. It was derived from an ASSUMED
	success-probability curve, which is the single largest uncertainty in the
	progression model.
]]
ProgressionConfig.BaseProgressRate = 0.00482389

--[[
	THE SECTION 34.11 RECALIBRATION CANDIDATE. **[PROVISIONAL]. NOT LIVE.**

	Section 34 made training the only source of Competition Number, which removed
	the channel mix the live rate above was solved against. Re-solving against the
	single-channel model gives this number, under which the manual
	Squat-Bench-Deadlift rotation reaches 100% Record Potential Ratio in 64 to 96
	days across the seven classes.

	THE LIVE VALUE IS THE ONE ABOVE, AND IT IS DELIBERATELY UNCHANGED. Nothing
	reads this field. `CompetitionNumberReward` multiplies by
	`ProgressionConfig.BaseProgressRate`, so adopting the candidate is a
	one-character edit on the line above -- which is exactly the point of keeping
	BaseProgressRate a single constant.

	BOTH NUMBERS LIVE HERE TOGETHER ON PURPOSE. GAME_DESIGN.md states them in two
	places (sections 29.3 and 34.11) so neither can be read alone, and the same
	reasoning applies to the code: a reader who finds one of these should be
	unable to miss the other.

	Adopting it changes nothing structural. Not the formula, not the 21 frozen
	Progression References, not the Hill curve, not h or m. It is one multiplier,
	and every day count in section 34.11 scales with it.
]]
ProgressionConfig.ProposedBaseProgressRate = 0.01113418

--[[
	Hill soft-cap shape. Asymptotic: progression slows without limit and never
	reaches zero, so there is no hard strength cap at any Progression Proximity.

	m = 6 is the lever for a harsher elite grind. It only affects players past
	PP 110%, so the choice can wait for real telemetry.
]]
ProgressionConfig.Hill = {
	h = 0.75,
	m = 5,
}

--[[
	THERE IS DELIBERATELY NO FAILURE CREDIT.

	`FailureCredit = 0.20` was removed per GAME_DESIGN.md section 33.6: a failed
	attempt now yields zero progression EV, zero Competition Number and no
	Competition Scale increase. Do not re-add it.
]]

--[[
	=========================================================================
	COMPETITION BUDGET (section 29.9) -- ACTIVELY USED
	=========================================================================

	THREE SEPARATE POOLS: Squat, Bench, Deadlift.

	Each pool is ACCOUNT-WIDE FOR THAT LIFT and shared across every
	weight-class build and across Solo and Official meets. A pool is NOT per
	weight class, NOT per build slot, and NOT shared between the three lifts.

	Why three pools rather than one: with a single shared pool, a squat-only
	player earns three times the squat progression of a full powerlifter per
	unit of budget, because a full 9-attempt meet spends three lifts' worth of
	allowance to advance each lift once. Per-lift pools invert that, so
	specialising becomes a trade rather than a multiplier.

	THE STORED RESOURCE IS THE BUDGET, NOT A MEET COUNT. Consumption is
	proportional to the Competition Number actually awarded. The "overflowMeets"
	figure in section 29.9 is a balancing interpretation based on roughly
	1.886 EV per lift per normal meet; it is deliberately not part of the data
	model, so nothing here depends on how many meets a player has played.
]]
ProgressionConfig.CompetitionBudget = {
	-- EV units. Equivalent to five meets at the Normal attempt strategy.
	CapacityEV = 9.43,

	-- EV units per hour. 9.43 per week, so a fully spent pool refills in a week.
	RegenerationEVPerHour = 0.0561,

	--[[
		Overflow softness, from section 29.9. Read by CompetitionBudget, which
		is the only module that touches the harmonic curve:

			M(d) = 1 / (1 + d / (OverflowK x UnitEV))

		where d is how far the pool has gone below zero, in EV.
	]]
	OverflowK = 3,

	--[[
		The EV one normal-strategy meet contributes to ONE lift. Derived in
		section 29.5 from the three attempts of a Normal meet.

		THIS IS A CURVE SCALE, NOT A COUNT. It exists so that one meet's worth
		of overflow costs what it did in the discrete model that was approved,
		and it appears in exactly one expression, the K above. Nothing divides
		by it to ask "which meet is this": the data model stores no meet counter
		and consumption is driven by actual per-lift progression EV, so a 0.4 EV
		attempt advances the state by 0.4.
	]]
	UnitEV = 1.886,

	--[[
		THERE IS DELIBERATELY NO NEGATIVE FLOOR.

		A spent pool goes negative and the magnitude is the overflow depth. An
		earlier draft clamped it at -5 x capacity as a "corruption guard", which
		was a bug: thirty meets in one week lands at exactly -47.15 EV, which
		was exactly that clamp, so the guard silently refused the busiest week
		the design explicitly treats as legitimate.

		No floor is needed, because the multiplier already makes deep overflow
		worthless and therefore self-limiting. Five years of thirty meets a week
		reaches about -12,259 EV, a multiplier of 0.00046 -- vanishing but never
		zero, and nowhere near the limits of a double.

		Corrupt values are handled where that concern belongs: finite-number
		validation on the way in, and the schema's migration repair on load.
	]]
}

--[[
	=========================================================================
	TRAINING ENERGY (section 29.8) -- ACTIVELY USED
	=========================================================================

	Limits PASSIVE AFK Competition Number only.

	IT MUST NEVER LIMIT MUSCLE. Muscle progresses independently and continues
	when Training Energy is empty. Nothing in this table may be wired to the
	Muscle system.

	Account-wide, never build-scoped.

	At zero, AFK Competition Number STOPS rather than entering overflow. That
	asymmetry with the Competition Budget is deliberate: meets are active play,
	and a player at the keyboard must never be told their effort is worth
	nothing, whereas a hard allowance on passive gain is what holds the intended
	ratio of roughly 0.25x the reference active rate.
]]
ProgressionConfig.TrainingEnergy = {
	-- Minutes. Two hours.
	CapacityMinutes = 120,

	-- Minutes per hour. A fully spent pool refills in 24 hours.
	RegenerationMinutesPerHour = 5,

	--[[
		Unlike the Competition Budget, this resource cannot go below zero.
		Spending stops at empty; there is no overflow.
	]]
	MinimumMinutes = 0,
}

--[[
	=========================================================================
	DAILY TRAINING ECONOMY (section 34) -- NOT YET CONSUMED BY ANY SYSTEM
	=========================================================================

	The gym training station is the ONLY source of Competition Number (section
	34.2). Meets never granted it; daily quests, login rewards and purchases do
	not either.

	TWO SCOPES, AND THEY ARE DIFFERENT ON PURPOSE:

		the EV cap          per ACCOUNT, per day
		H(t) efficiency     per LIFT, per day

	That asymmetry is the whole of section 34.10. Because a lift's efficiency
	decays with the hours spent on THAT lift while the cap counts the whole
	account, spreading a day across two lifts reaches the cap in 4.00 hours where
	concentrating on one takes 5.4366. Concentrating costs time, not progression.

	WITHIN-DAY PACING IS H(t). A lift's efficiency decays with hours already
	spent on it today:

		H(t)  = 1 / (1 + max(0, t - FullRateHours) / K)
		EV(t) = BaseRate x t                                    for t <= FullRateHours
		EV(t) = BaseRate x (F + K x ln(1 + (t - F) / K))        for t >  FullRateHours

	The harmonic form is the same shape as the Competition Budget overflow above,
	for the same reason: it never hard-zeroes, so a player at the keyboard is
	never told their time is worth literally nothing, while the marginal rate
	still falls fast enough that grinding one lift all day is poor value.

	THE MATHS DOES NOT LIVE HERE. These are the parameters only. Checkpoint 5B.3
	implements H(t) and the cumulative-EV integral as a pure, tested module, and
	it is the right place to assert single-lift reachability -- that the cap can
	actually be exhausted within 24 hours. Writing that integral here would
	duplicate it.
]]
ProgressionConfig.DailyTraining = {
	--[[
		**[FINAL]** -- section 34.1, decision 2.

		EV units, ACCOUNT-WIDE, per UTC day. The one number in section 34 that is
		final rather than provisional, because it was approved as a design
		decision rather than derived as a calibration.

		THERE IS DELIBERATELY NO PER-LIFT EV CAP. Section 34.1 decision 3 removed
		the proposed 4.20 per-lift ceiling, which could never have fired anyway:
		one lift per station and an account cap of 4.00 makes a 4.20 per-lift
		limit unreachable by construction. The assertion at the foot of this file
		enforces its absence. Do not re-add it.
	]]
	DailyCapEV = 4.00,

	--[[
		**[PROVISIONAL]** -- section 34.4. EV per hour at full efficiency.

		3.86x section 29.5's old AFK figure of 0.2591 EV/hour, and the two are not
		comparable: that rate was calibrated for a background trickle worth 15% of
		Competition Number, and this one carries 100% of it. The old figure is
		obsolete rather than retuned.

		AUTO-TRAIN RUNS AT FULL RATE. Section 34.1 decision 1: there is no AFK
		efficiency discount, not 55% and not any other figure. A discount below
		roughly 95% would make DailyCapEV UNREACHABLE, because efficiency
		multiplies this rate while the cap stays fixed -- at 55% a full day on one
		lift tops out near 2.3 EV. It would not slow the economy, it would halve
		it and turn the cap into decoration.
	]]
	BaseRate = 1.00,

	--[[
		**[PROVISIONAL]** -- section 34.4. Hours at full efficiency before H(t)
		begins to decay, per lift, per day.

		These first hours deliver HALF the daily cap, which is what makes a short
		session worth standing through and is why no hard training-hour limit is
		needed (section 34.3). Zero would be legal and would mean decay starts
		immediately.
	]]
	FullRateHours = 2.00,

	--[[
		**[PROVISIONAL]** -- section 34.4. Harmonic softness of the decay.

		Larger is gentler. At K = 2.00 the marginal rate is down to 36.8% of the
		opening rate by the time the cap is reached.
	]]
	K = 2.00,

	--[[
		**[PROVISIONAL]** -- section 34.7. Raw technique points per hour, TOTAL
		across the primary/secondary split rather than per stat.

		Earned only after the EV cap is reached, when the station switches to
		technique training (section 34.5).
	]]
	TechniqueRawPerHour = 2.00,

	--[[
		**[PROVISIONAL]** -- section 34.7. Raw technique points, ACCOUNT-WIDE, per
		UTC day. Exhausted in 3.00 hours at the rate above, after which the station
		goes idle: it does not fall back to Competition Number, overflow into
		another stat, or continue at a reduced rate.
	]]
	DailyCapTechniqueRaw = 6.00,

	--[[
		**[FINAL]** -- section 34.1, decision 4.

		The share of AFK technique progression going to the player's chosen primary
		stat. Squat and Bench each have two trainable stats; the Deadlift has only
		Lockout, so it takes 100% and this value does not apply to it.

		THE SECONDARY SHARE IS DERIVED, NOT STORED: 1 - this. Storing both would
		let them drift to 0.8 and 0.3 and silently stop summing to a whole
		allowance.

		THE SECONDARY DEVELOPING SLOWLY IS THE DECISION, NOT A SIDE EFFECT. At 20%
		of a 6.00 allowance the secondary receives 1.20 raw points a day, which on
		the log-space technique curve is a small effective gain even over a season.
		AFK technique is meant to express a clear specialisation; the secondary's
		job is to not be frozen at zero rather than to keep pace. Balanced
		technique comes from meets (section 34.8), not from the station.
	]]
	TechniquePrimaryShare = 0.80,

	--[[
		FRACTIONAL AWARDS ARE REQUIRED, NOT OPTIONAL. 80/20 of 6.00 is 4.80 and
		1.20, and EV accrues continuously, so rounding either counter to an integer
		would discard up to a fifth of the secondary's daily award. The schema
		stores both as plain numbers for this reason (section 34.12).
	]]
}

--[[
	The three competition lifts, in display order.

	Shared by the Competition Number and the three Competition Budgets, so a new
	lift cannot be added to one and forgotten in the other.
]]
ProgressionConfig.Lifts = { "Squat", "Bench", "Deadlift" }

--[[
	True when `name` is one of the three competition lifts.

	Exists so every validation site rejects the same set of names, rather than
	each one writing its own comparison.
]]
function ProgressionConfig.isLift(name: any): boolean
	if typeof(name) ~= "string" then
		return false
	end

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		if lift == name then
			return true
		end
	end

	return false
end

--[[
	=========================================================================
	CONFIGURATION INTEGRITY -- CHECKED AT STARTUP, NOT IN A PROBE
	=========================================================================

	These run on module load, in the real game, every time. That is deliberately
	stronger than a dev probe for this job: a probe that defaults to disabled
	cannot catch a bad constant, and the failure these guard against is a
	balancing edit, which is exactly the kind of change made in a hurry without
	turning a probe on.

	The same pattern is already used by ControlPhaseConfig and LiftAttemptConfig.
	Behavioural tests of H(t) itself belong to checkpoint 5B.3, not here.
]]

local function requirePositiveFinite(name: string, value: any)
	assert(
		typeof(value) == "number" and value == value and value > 0 and value < math.huge,
		string.format("[ProgressionConfig] %s must be a finite number above zero", name)
	)
end

requirePositiveFinite("BaseProgressRate", ProgressionConfig.BaseProgressRate)
requirePositiveFinite("ProposedBaseProgressRate", ProgressionConfig.ProposedBaseProgressRate)

local dailyTraining = ProgressionConfig.DailyTraining

requirePositiveFinite("DailyTraining.DailyCapEV", dailyTraining.DailyCapEV)
requirePositiveFinite("DailyTraining.BaseRate", dailyTraining.BaseRate)
requirePositiveFinite("DailyTraining.K", dailyTraining.K)
requirePositiveFinite("DailyTraining.TechniqueRawPerHour", dailyTraining.TechniqueRawPerHour)
requirePositiveFinite("DailyTraining.DailyCapTechniqueRaw", dailyTraining.DailyCapTechniqueRaw)

--[[
	Zero is legal here, unlike the values above: it means H(t) starts decaying
	immediately rather than after a full-rate window.
]]
assert(
	typeof(dailyTraining.FullRateHours) == "number"
		and dailyTraining.FullRateHours == dailyTraining.FullRateHours
		and dailyTraining.FullRateHours >= 0
		and dailyTraining.FullRateHours < math.huge,
	"[ProgressionConfig] DailyTraining.FullRateHours must be a finite number of 0 or more"
)

--[[
	THE CAP MUST NOT BE REACHABLE BEFORE H(t) EVEN ENGAGES.

	This is the live footgun in this table. If DailyCapEV were set at or below
	BaseRate x FullRateHours, the whole allowance would be earned inside the
	full-rate window, H(t) would never decay, and the section 34.10 tradeoff --
	concentrating on one lift costing extra hours -- would SILENTLY vanish. The
	station would still work, every test would still pass, and the design would
	be gone.

	At the approved values: 4.00 > 1.00 x 2.00. Two hours earns half the cap.
]]
assert(
	dailyTraining.DailyCapEV > dailyTraining.BaseRate * dailyTraining.FullRateHours,
	string.format(
		"[ProgressionConfig] DailyCapEV (%.4f) must exceed BaseRate x FullRateHours (%.4f), "
			.. "or H(t) never engages and the per-lift efficiency decay does nothing",
		dailyTraining.DailyCapEV,
		dailyTraining.BaseRate * dailyTraining.FullRateHours
	)
)

--[[
	THE TECHNIQUE ALLOWANCE MUST BE EXHAUSTIBLE WITHIN A DAY.

	Same class of bug as the one above. An allowance that took more than 24 hours
	to spend could never be reached before the daily reset zeroed it, so it would
	be decorative rather than a limit. At the approved values it takes 3.00 hours.
]]
assert(
	dailyTraining.DailyCapTechniqueRaw / dailyTraining.TechniqueRawPerHour < 24,
	string.format(
		"[ProgressionConfig] the technique allowance takes %.2f hours to exhaust, which is "
			.. "more than a day, so the daily reset would make it unreachable",
		dailyTraining.DailyCapTechniqueRaw / dailyTraining.TechniqueRawPerHour
	)
)

--[[
	A PRIMARY THAT IS NOT A MAJORITY IS NOT A PRIMARY. Above 0.5 and at most 1.0.
	1.0 is legal and means the secondary receives nothing, which is already how
	the Deadlift behaves with its single trainable stat.
]]
assert(
	typeof(dailyTraining.TechniquePrimaryShare) == "number"
		and dailyTraining.TechniquePrimaryShare > 0.5
		and dailyTraining.TechniquePrimaryShare <= 1.0,
	string.format(
		"[ProgressionConfig] TechniquePrimaryShare must be above 0.5 and at most 1.0, got %s",
		tostring(dailyTraining.TechniquePrimaryShare)
	)
)

--[[
	SECTION 34.1 DECISION 3, ENFORCED RATHER THAN MERELY DOCUMENTED.

	The proposed per-lift EV cap was removed because the account-wide cap is
	authoritative and a per-lift ceiling above it could never fire. Turning that
	decision into an assertion costs nothing and makes re-adding it a loud
	failure instead of a quiet second source of truth.
]]
assert(
	(dailyTraining :: any).PerLiftCapEV == nil,
	"[ProgressionConfig] section 34.1 decision 3 removed the per-lift EV cap: the "
		.. "account-wide DailyCapEV is authoritative. Do not re-add it."
)

return ProgressionConfig
