--!strict
--[[
	ProgressionConfig
	Shared / Config

	The frozen constants of the Competition Number progression system, from
	GAME_DESIGN.md section 29.

	WHAT IS AND IS NOT USED YET

	Only the RESOURCE constants below -- Competition Budget and Training Energy
	capacity and regeneration -- are consumed by anything today. They drive
	ResourceRegeneration and the persistence foundation.

	BaseProgressRate and the Hill parameters are recorded here and are NOT yet
	read by any system. No attempt, daily or AFK tick awards Competition Number
	at present. They live here because section 29 froze them and because
	BaseProgressRate must be a single configurable constant: real playtest
	success rates will require recalibrating it, and it enters the reward formula
	as one multiplier so rescaling is a one-line change.

	Keeping them in one file now is what stops them being re-derived, slightly
	differently, by each system that eventually needs them.
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
	Failed attempts are worth this fraction of the same attempt succeeded.

	Sensitivity testing showed 0.30 inverts optimal play toward reckless
	high-intensity spam, so this should stay at or below 0.20.
]]
ProgressionConfig.FailureCredit = 0.20

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

return ProgressionConfig
