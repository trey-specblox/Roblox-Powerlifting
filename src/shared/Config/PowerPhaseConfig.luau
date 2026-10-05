--!strict
--[[
	PowerPhaseConfig
	Shared / Config

	Every balance number for the Test Your Might power phase.

	Reference: References/testyourmight.md.

	THE MECHANIC

	A circular power progress. The player's ring starts at the outer edge and contracts
	inward as power builds; decay pushes it back out. Reaching the inner success
	circle completes the phase.

		MASH -> GET READY TO HOLD -> HOLD -> MASH -> ... -> POWER SUCCESS

	Rapid repeated presses build power. Twice (or three times on a heavy attempt)
	the instruction changes to HOLD, and the player must press and keep the input
	held. Holding PRESERVES progress; it neither gains nor loses. Spam clicking
	through a hold DRAINS progress, which is the entire punishment.

	REACHING THE INNER CIRCLE IS TERMINAL

	The moment authoritative progress reaches the completion threshold the phase succeeds and
	stops. No further hold is scheduled, no outstanding hold must be completed,
	decay cannot pull the player back out, and nothing else is required. The player
	does not have to stay inside the circle or hold it.

	=========================================================================
	STATUS: PROVISIONAL. NOT FINAL BALANCE. DO NOT TREAT AS SETTLED.
	=========================================================================

	THE EQUATION THE MASH SIDE IS DERIVED FROM

		progress rate    = (powerPerInput x presses per second) - decay
		required rate = (decay + completion threshold / ACTIVE seconds) / powerPerInput

	Note ACTIVE seconds, not wall clock. Decay pauses while the input is correctly
	held, so hold time is added to the wall-clock budget rather than taken out of
	the mashing window. That is what keeps the required mashing rate at the
	approved figures:

		80% 2.75/s   90% 3.76/s   100% 5.00/s   105% 5.76/s   110% 6.24/s

	HOLDS ARE TRIGGERED BY PROGRESS, NOT BY THE CLOCK

	A hold fires when progress first crosses a fraction of the completion threshold, not at a
	fixed time. A time-based schedule could not work here: at the press ceiling the
	progress fills in about a second at an 80% attempt, so any hold placed late enough
	to be fair to a normal player would arrive after a fast player had already
	finished. Triggering on progress means every player meets every hold on the way
	in, however fast they travel, and no hold can ever arrive after the phase is
	effectively over.

	ANTI-AUTOCLICKER HONESTY

	A hold does not end on a timer. It ends when a continuous hold of the required
	length is produced. A tool that blindly keeps clicking therefore never leaves
	the hold: it bleeds power at the penalty rate and runs the clock down until the
	phase times out.

	It is NOT cheat-proof, and nothing here pretends otherwise. The client has to
	know a hold is active in order to draw the instruction, so automation that reads
	that state can issue one press and hold. Any telegraphed mechanic has this
	property, because the information must reach the screen to be playable.
]]

local Curve = require(script.Parent.Parent.Util.Curve)
local ParameterMapper = require(script.Parent.Parent.Difficulty.ParameterMapper)

local PowerPhaseConfig = {}

-- The progress's bounds. It starts empty: this is power being built, not a reserve
-- being defended, so there is no starting buffer.
PowerPhaseConfig.ProgressMax = 100
PowerPhaseConfig.StartingProgress = 0

--[[
	Presses arriving closer together than 1 / MaxInputsPerSecond are DISCARDED FOR
	SCORING, on both the client and the server.

	Fixed before any completion threshold was chosen, because it is the value that decides
	whether the mash side is humane. Every completion threshold is derived beneath it, so no
	attempt can become a speed contest past it.

	Assumed human rates, for reference when retuning:
		casual single finger       4-5 /s
		determined single finger   6-7 /s
		trained two-finger        10-14 /s
]]
PowerPhaseConfig.MaxInputsPerSecond = 10

--[[
	Fixed simulation timestep, identical on both sides. The server reconstructs the
	progress and the held intervals from the player's reported input transitions, so a
	variable frame delta would let client and server disagree about the outcome.
]]
PowerPhaseConfig.FixedTimestepSeconds = 1 / 60

--[[
	How far a client's reported timings may disagree with the server's own
	measurement of elapsed time before the attempt is rejected.
]]
PowerPhaseConfig.TimingToleranceSeconds = 1.5

--[[
	=========================================================================
	HOLDS. ALL VALUES PROVISIONAL / NOT FINAL BALANCE.
	=========================================================================

	A HOLD ENDS WHEN IT IS SATISFIED, NOT WHEN A TIMER EXPIRES.

	This is the single most important property of the mechanic, and the thing that
	makes a legitimate continuous hold impossible to fail. There is no window to
	miss and no press budget to exhaust: the hold simply waits until the input has
	been held continuously for the required duration, then returns to mashing.

	A correct hold therefore ALWAYS succeeds, no matter how late it starts or what
	the player was doing beforehand. There is no "failed hold" outcome at all.

	The cost of not holding is paid in power and in time:
		holding correctly   progress preserved, decay paused
		doing nothing       decay continues, progress slips outward
		spam clicking       decay continues AND each press costs power
]]

--[[
	Releases shorter than this do not break a hold's continuity.

	Exists for touch, where a finger can micro-lift without the player intending to
	release, and for the one-frame gaps a real mouse can produce.
]]
PowerPhaseConfig.HoldReleaseToleranceSeconds = 0.08

--[[
	Grace at the start of a hold during which presses cost nothing.

	A player mashing several times a second cannot stop instantly, so one or two
	clicks always land just after the instruction changes. Those are reaction, not
	defiance, and charging for them would punish normal play. Past this the player
	has clearly chosen to keep clicking.
]]
PowerPhaseConfig.HoldPressGraceSeconds = 0.20

--[[
	Clock budget added per hold on top of the hold itself, covering reaction time.

	NOT a deadline. A hold cannot be missed, so this only decides how generous the
	phase's overall time budget is. A sharp player who holds immediately gets the
	unused remainder back as extra mashing time.
]]
PowerPhaseConfig.HoldReactionAllowanceSeconds = 0.45

--[[
	How far a hold's trigger point may wander from its nominal fraction of the
	completion threshold, so two attempts at the same weight do not fire holds at identical
	progress.

	Kept small enough that trigger points cannot cross each other or reach the
	completion threshold itself.
]]
PowerPhaseConfig.HoldTriggerJitter = 0.06

local function linear(anchors: { Curve.Anchor }): Curve.Curve
	return {
		space = "linear",
		anchors = anchors,
	}
end

--[[
	The shared profile. PROVISIONAL.

	Resulting experience at StartControl 0:

		attempt  diff  thresh  active  decay | required | holds  hold | budget
		    80%    32      35     5.0    4.0 |   2.75/s |     2  0.65 |  7.20
		    90%    45      50     6.0    6.7 |   3.76/s |     2  0.67 |  8.24
		   100%    65      70     7.0   10.0 |   5.00/s |     2  0.70 |  9.30
		   105%    80      85     8.0   12.4 |   5.76/s |     3  0.78 | 11.68
		   110%    95      95     9.0   14.4 |   6.24/s |     3  0.85 | 12.91

	The budget is a timeout, not a target. Success is terminal, so a competent
	player finishes well before it.
]]
local defaultProfile: ParameterMapper.MinigameSpec = {
	--[[
		Progress value that completes the phase. Also the radius at which the UI draws
		the inner success circle, so a harder attempt visibly has a smaller target.

		NOTE: no fromTechnique curve, deliberately. Together with duration, this is
		what keeps the phase from becoming automatic.
	]]
	completionThreshold = {
		fromDifficulty = linear({
			{ x = 0, y = 20 },
			{ x = 20, y = 30 },
			{ x = 32, y = 35 },
			{ x = 45, y = 50 },
			{ x = 65, y = 70 },
			{ x = 80, y = 85 },
			{ x = 95, y = 95 },
			{ x = 100, y = 98 },
		}),
		minimum = 5,
		maximum = 100,
	},

	--[[
		ACTIVE mashing seconds. Hold time is added on top to produce the wall-clock
		budget, which is why the required rate below is unaffected by adding holds.
	]]
	duration = {
		fromDifficulty = linear({
			{ x = 0, y = 4.0 },
			{ x = 20, y = 4.6 },
			{ x = 32, y = 5.0 },
			{ x = 45, y = 6.0 },
			{ x = 65, y = 7.0 },
			{ x = 80, y = 8.0 },
			{ x = 95, y = 9.0 },
			{ x = 100, y = 9.3 },
		}),
		minimum = 1.5,
	},

	--[[
		Progress points lost per second while mashing is permitted, and while a hold is
		active but the input is NOT held. Paused by a correct hold.

		Decay divided by powerPerInput is the rate below which the progress falls
		instead of rising, which is what makes a heavy attempt punish hesitation.
	]]
	decay = {
		fromDifficulty = linear({
			{ x = 0, y = 2.4 },
			{ x = 20, y = 3.4 },
			{ x = 32, y = 4.0 },
			{ x = 45, y = 6.7 },
			{ x = 65, y = 10.0 },
			{ x = 80, y = 12.4 },
			{ x = 95, y = 14.4 },
			{ x = 100, y = 15.0 },
		}),
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 30, y = 0.92 },
			{ x = 55, y = 0.82 },
			{ x = 82, y = 0.70 },
			{ x = 99.5, y = 0.62 },
		}),
		minimum = 0.5,
	},

	--[[
		Progress points added by one accepted press.

		Flat across difficulty on purpose: a heavier bar does not make a press worth
		less, it makes the bar fall faster and the target further away.
	]]
	powerPerInput = {
		fromDifficulty = linear({
			{ x = 0, y = 4.0 },
			{ x = 100, y = 4.0 },
		}),
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 30, y = 1.10 },
			{ x = 55, y = 1.22 },
			{ x = 82, y = 1.35 },
			{ x = 99.5, y = 1.45 },
		}),
		minimum = 0.5,
	},

	--[[
		How many holds the phase contains. Rounded to a whole number when the
		challenge is built. Gives 2 / 2 / 2 / 3 / 3 at 80 / 90 / 100 / 105 / 110%.

		NOTE: no fromTechnique curve. If Start Control reduced the number of holds it
		would weaken the anti-automation property for exactly the players most likely
		to be chasing records.
	]]
	holdCount = {
		fromDifficulty = linear({
			{ x = 0, y = 2 },
			{ x = 65, y = 2 },
			{ x = 80, y = 3 },
			{ x = 100, y = 3 },
		}),
		minimum = 1,
	},

	--[[
		Continuous held time that satisfies a hold and returns the player to mashing.

		Also free of any technique curve: Start Control buys a longer warning and a
		cheaper mistake, not a shorter commitment.
	]]
	requiredHoldSeconds = {
		fromDifficulty = linear({
			{ x = 0, y = 0.60 },
			{ x = 65, y = 0.70 },
			{ x = 100, y = 0.88 },
		}),
		minimum = 0.3,
	},

	--[[
		Amber warning before a hold begins.

		Flat across difficulty: a heavier bar deserves more holds, not less warning.
		Start Control extends it. Mashing is still legal and still pays during the
		warning, so a player can keep building right up to the hold.
	]]
	telegraphSeconds = {
		fromDifficulty = linear({
			{ x = 0, y = 0.50 },
			{ x = 100, y = 0.50 },
		}),
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 30, y = 1.12 },
			{ x = 55, y = 1.26 },
			{ x = 82, y = 1.38 },
			{ x = 99.5, y = 1.44 },
		}),
		minimum = 0.25,
	},

	--[[
		Power lost per press while a hold is active, past the grace.

		This is the mechanic's only punishment, and it is deliberately steep enough
		that sustained clicking through a hold erases progress faster than mashing
		can rebuild it. A player who lands one stray click on the way into a hold
		pays very little; one who ignores the instruction entirely goes nowhere.

		Start Control softens it.
	]]
	holdPressPenalty = {
		fromDifficulty = linear({
			{ x = 0, y = 6.0 },
			{ x = 100, y = 6.0 },
		}),
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 30, y = 0.92 },
			{ x = 55, y = 0.82 },
			{ x = 82, y = 0.70 },
			{ x = 99.5, y = 0.62 },
		}),
		minimum = 1.0,
	},
}

PowerPhaseConfig.Profiles = {
	Default = defaultProfile,
}

--[[
	EVERYTHING LIFT-SPECIFIC ABOUT A POWER PHASE LIVES HERE.

	Only the bench uses this mechanic. Squat uses the Fisch-style control phase and
	the deadlift will use typing, so this table has one entry and is expected to
	keep having one.
]]
PowerPhaseConfig.Phases = {
	BenchStart = {
		lift = "Bench",
		techniqueStat = "StartControl",
		profile = "Default",
		displayName = "POWER",
		--[[
			Only two outcomes exist. A hold cannot be failed, so there is no verdict
			for one; running out of time is the single way to lose the phase.
		]]
		verdicts = {
			pass = "POWER BUILT",
			--[[
				Worded as time, not as a shortfall of some "power" stat. Running out of
				the budget is the only way to lose this phase, and saying so avoids
				implying a second requirement beyond finishing the circle.
			]]
			failTimeout = "NO LIFT - OUT OF TIME",
		},
	},
}

-- Fail at startup rather than mid-lift if a balancing table is malformed.
for profileName, profile in pairs(PowerPhaseConfig.Profiles) do
	ParameterMapper.validate(profile, "PowerPhaseConfig.Profiles." .. profileName)
end

for phaseName, phase in pairs(PowerPhaseConfig.Phases) do
	assert(
		PowerPhaseConfig.Profiles[phase.profile] ~= nil,
		string.format("[PowerPhaseConfig] phase %s points at unknown profile %q", phaseName, phase.profile)
	)
	assert(
		typeof(phase.lift) == "string" and phase.lift ~= "",
		string.format("[PowerPhaseConfig] phase %s must name the lift it reads", phaseName)
	)
	assert(
		typeof(phase.techniqueStat) == "string" and phase.techniqueStat ~= "",
		string.format("[PowerPhaseConfig] phase %s must name its technique stat", phaseName)
	)
	assert(
		typeof(phase.displayName) == "string" and phase.displayName ~= "",
		string.format("[PowerPhaseConfig] phase %s must have a displayName", phaseName)
	)

	for _, key in ipairs({ "pass", "failTimeout" }) do
		assert(
			typeof(phase.verdicts) == "table" and typeof(phase.verdicts[key]) == "string",
			string.format("[PowerPhaseConfig] phase %s is missing its %q verdict wording", phaseName, key)
		)
	end
end

assert(
	PowerPhaseConfig.StartingProgress >= 0 and PowerPhaseConfig.StartingProgress < PowerPhaseConfig.ProgressMax,
	"[PowerPhaseConfig] StartingProgress must sit below ProgressMax"
)
assert(
	PowerPhaseConfig.MaxInputsPerSecond > 0,
	"[PowerPhaseConfig] MaxInputsPerSecond must be above 0"
)
assert(
	PowerPhaseConfig.HoldReleaseToleranceSeconds > 0,
	"[PowerPhaseConfig] the release tolerance must be above 0"
)
assert(
	PowerPhaseConfig.HoldPressGraceSeconds >= 0,
	"[PowerPhaseConfig] the hold press grace cannot be negative"
)
assert(
	PowerPhaseConfig.HoldTriggerJitter >= 0 and PowerPhaseConfig.HoldTriggerJitter < 0.1,
	--[[
		Trigger points sit at 1/(n+1) spacing, the closest being 0.25 apart. Jitter
		must stay well inside half that so two holds cannot cross, and well below the
		completion threshold so a hold cannot fire at the moment the phase would already succeed.
	]]
	"[PowerPhaseConfig] the trigger jitter must stay small enough that holds cannot cross or reach the completion threshold"
)

return PowerPhaseConfig
