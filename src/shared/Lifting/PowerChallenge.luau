--!strict
--[[
	PowerChallenge
	Shared / Lifting

	Turns a resolved LiftDifficulty into one concrete power phase.

	HOLDS ARE TRIGGERED BY PROGRESS

	A hold does not have a start time. It has a TRIGGER: a power level that, when
	first crossed, begins the warning. The triggers sit at even fractions of the
	completion threshold, jittered slightly so two attempts at the same weight are not
	identical.

	This replaced a wall-clock schedule, which could not be made to work. At the
	press ceiling the progress fills in about a second at an 80% attempt, so a hold
	placed late enough to be fair to a normal player would land after a fast player
	had already finished the phase. Triggering on progress means every player meets
	every hold on the way in, whatever their speed, and a hold can never arrive
	after the phase is effectively over.

	Because the triggers are strictly below the completion threshold, reaching the completion threshold
	can never coincide with a new hold appearing. Progress beyond the last trigger
	is uninterrupted.

	WHAT IS RANDOMISED AND WHAT IS NOT

	Trigger POINTS are jittered every attempt. The hold COUNT is predictable from
	difficulty. Nothing else is randomised: jittering the completion threshold or the duration
	would not defeat a scripted input, because it would simply mash regardless, and
	would only add uncertainty for honest players.

	SERVER AUTHORITY

	Built once, on the server. The client's copy exists so it can draw a responsive
	circle and the warning; the server reconstructs the progress and the held intervals
	from the reported input transitions, and that result is the only one that counts.
]]

local PowerPhaseConfig = require(script.Parent.Parent.Config.PowerPhaseConfig)
local DifficultyResolver = require(script.Parent.Parent.Difficulty.DifficultyResolver)
local ParameterMapper = require(script.Parent.Parent.Difficulty.ParameterMapper)

local PowerChallenge = {}

export type Challenge = {
	phase: string,
	displayName: string,

	-- Progress bounds and where it starts.
	progressMax: number,
	startingProgress: number,
	--[[
		Progress value that COMPLETES the phase, and the radius of the UI's success
		circle. Reaching it is terminal: nothing further is required.
	]]
	completionThreshold: number,

	-- Progress points added per accepted press, while mashing is permitted.
	powerPerInput: number,
	--[[
		Progress points lost per second while mashing is permitted, and during a hold
		when the input is NOT held. A correct hold pauses it.
	]]
	decayPerSecond: number,

	--[[
		Wall-clock budget. A TIMEOUT, not a target: success is terminal, so a
		competent player finishes well before this.

		activeSeconds is the mashing time the balance is derived from. Correct holds
		pause decay, so hold time is added here rather than taken out of the mashing
		window.
	]]
	durationSeconds: number,
	activeSeconds: number,

	--[[
		Power levels that trigger a hold when first crossed, ascending. All strictly
		below the completion threshold.
	]]
	holdTriggers: { number },
	-- Continuous held time that satisfies a hold and returns the player to mashing.
	requiredHoldSeconds: number,
	-- Amber warning before a hold begins. Mashing still pays during it.
	telegraphSeconds: number,
	-- Releases shorter than this do not break a hold's continuity.
	releaseToleranceSeconds: number,
	-- Presses in the first moments of a hold that cost nothing.
	pressGraceSeconds: number,
	-- Power lost per press during a hold, past the grace.
	holdPressPenalty: number,

	-- Presses closer together than 1 / this are discarded for scoring, both sides.
	maxInputsPerSecond: number,
	fixedTimestepSeconds: number,

	--[[
		Derived and carried for display and tuning. Neither is read by the simulation.

		requiredInputsPerSecond is the sustained mashing rate that fills the circle
		exactly as the active time expires. It is shown in the dev readout and logged
		with the result, so a tuning session can compare what the attempt demanded
		against what the player actually produced.
	]]
	requiredInputsPerSecond: number,

	-- Display only.
	attemptWeightKg: number,
	forecastedMaxKg: number,
	intensityPercent: number,
	baseDifficulty: number,
	classification: string,
}

export type DisplayWeights = {
	attemptWeightKg: number,
	forecastedMaxKg: number,
}

--[[
	Chooses the power levels at which holds fire.

	For n holds the nominal points are the n even divisions of the climb: two holds
	fire around a third and two thirds of the way in, three around a quarter, a half
	and three quarters. Each is nudged by a small jitter.

	The spacing guarantees the points cannot cross: the closest nominal gap is 0.25
	of the completion threshold and the jitter is a fraction of that. The last point stays well
	below the completion threshold, so a hold cannot fire at the instant the phase would
	already have succeeded.
]]
local function buildHoldTriggers(count: number, completionThreshold: number, rng: Random): { number }
	local triggers: { number } = {}
	if count <= 0 then
		return triggers
	end

	local jitter = PowerPhaseConfig.HoldTriggerJitter

	for index = 1, count do
		local nominal = index / (count + 1)
		local fraction = nominal + rng:NextNumber(-jitter, jitter)

		--[[
			Clamped defensively. With the shipped curves the bounds are never reached,
			but a future retune must not be able to produce a trigger at zero power or
			at the completion threshold itself.
		]]
		fraction = math.clamp(fraction, 0.08, 0.92)

		table.insert(triggers, fraction * completionThreshold)
	end

	table.sort(triggers)
	return triggers
end

--[[
	Builds a challenge.

	phaseName  a key in PowerPhaseConfig.Phases
	difficulty a resolved LiftDifficulty
	weights    the kilograms behind that difficulty, for the client's HUD
	rng        the caller's Random, so the server controls trigger placement
]]
function PowerChallenge.build(
	phaseName: string,
	difficulty: DifficultyResolver.LiftDifficulty,
	weights: DisplayWeights,
	rng: Random
): Challenge
	local phase = PowerPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[PowerChallenge] unknown phase %q", phaseName))

	local profile = PowerPhaseConfig.Profiles[phase.profile]
	local resolved = ParameterMapper.resolveAll(profile, difficulty)

	local completionThreshold = math.min(resolved.completionThreshold, PowerPhaseConfig.ProgressMax)
	local activeSeconds = resolved.duration
	local decay = resolved.decay
	local powerPerInput = resolved.powerPerInput

	-- Whole holds only. The curve interpolates; the phase cannot have 2.3 of them.
	local holdCount = math.max(math.floor(resolved.holdCount + 0.5), 0)
	local requiredHold = resolved.requiredHoldSeconds

	--[[
		Hold time is ADDED to the wall-clock budget. Because a correct hold pauses
		decay, the active window stays exactly what the balance was derived from, so
		the required mashing rate is unaffected by adding holds.

		The reaction allowance is budget, not a deadline: a hold cannot be missed, so
		a player who holds immediately simply gets the remainder back as mashing time.
	]]
	local perHold = requiredHold + PowerPhaseConfig.HoldReactionAllowanceSeconds
	local duration = activeSeconds + holdCount * perHold

	--[[
		Derived from ACTIVE time, not wall clock. That is the whole point of pausing
		decay during a correct hold: the required rate is the same figure it was
		before holds existed.
	]]
	local toClimb = completionThreshold - PowerPhaseConfig.StartingProgress
	local requiredRate = (decay + toClimb / activeSeconds) / powerPerInput

	return {
		phase = phaseName,
		displayName = phase.displayName,

		progressMax = PowerPhaseConfig.ProgressMax,
		startingProgress = PowerPhaseConfig.StartingProgress,
		completionThreshold = completionThreshold,

		powerPerInput = powerPerInput,
		decayPerSecond = decay,

		durationSeconds = duration,
		activeSeconds = activeSeconds,

		holdTriggers = buildHoldTriggers(holdCount, completionThreshold, rng),
		requiredHoldSeconds = requiredHold,
		telegraphSeconds = resolved.telegraphSeconds,
		releaseToleranceSeconds = PowerPhaseConfig.HoldReleaseToleranceSeconds,
		pressGraceSeconds = PowerPhaseConfig.HoldPressGraceSeconds,
		holdPressPenalty = resolved.holdPressPenalty,

		maxInputsPerSecond = PowerPhaseConfig.MaxInputsPerSecond,
		fixedTimestepSeconds = PowerPhaseConfig.FixedTimestepSeconds,

		requiredInputsPerSecond = requiredRate,

		attemptWeightKg = weights.attemptWeightKg,
		forecastedMaxKg = weights.forecastedMaxKg,
		intensityPercent = difficulty.intensityPercent,
		baseDifficulty = difficulty.baseDifficulty,
		classification = difficulty.classification,
	}
end

--[[
	The technique stat a phase reads, e.g. "StartControl" for the bench's power
	phase.
]]
function PowerChallenge.techniqueStatFor(phaseName: string): string
	local phase = PowerPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[PowerChallenge] unknown phase %q", phaseName))
	return phase.techniqueStat
end

--[[
	The lift whose forecasted max a phase measures against, e.g. "Bench".
]]
function PowerChallenge.liftFor(phaseName: string): string
	local phase = PowerPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[PowerChallenge] unknown phase %q", phaseName))
	return phase.lift
end

--[[
	Whether a name refers to a configured phase, so a client's request can be
	validated without trusting the string it sent.
]]
function PowerChallenge.isKnownPhase(phaseName: unknown): boolean
	if typeof(phaseName) ~= "string" then
		return false
	end
	return PowerPhaseConfig.Phases[phaseName :: string] ~= nil
end

--[[
	The label shown for a phase, e.g. "POWER". The attempt banner uses it so a
	transition can name the phase that is coming next, instead of the client having
	to know each lift's sequence.
]]
function PowerChallenge.displayNameFor(phaseName: string): string
	local phase = PowerPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[PowerChallenge] unknown phase %q", phaseName))
	return phase.displayName
end

--[[
	The player-facing verdict for an outcome, read from the phase's own config so
	one lift's wording cannot leak into another.

	Only two outcomes exist: a hold cannot be failed, so running out of time is the
	single way to lose the phase.
]]
function PowerChallenge.verdictText(phaseName: string, outcome: string): string
	local phase = PowerPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[PowerChallenge] unknown phase %q", phaseName))

	if outcome == "Passed" then
		return phase.verdicts.pass
	end

	return phase.verdicts.failTimeout
end

return PowerChallenge
