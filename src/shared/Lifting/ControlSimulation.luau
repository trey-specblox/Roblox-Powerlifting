--!strict
--[[
	ControlSimulation
	Shared / Lifting

	The physics and scoring of a control phase, as a deterministic fixed-timestep
	simulation.

	THIS IS THE ONLY COPY OF THE RULES

	The client steps it live to draw a responsive bar. The server replays it from
	the player's reported clicks to decide the result. Both run this same code, so
	there is no second implementation to drift out of agreement with the first.

	DETERMINISM

	Everything here advances in fixed steps of challenge.fixedTimestepSeconds. A
	click is attributed to the step whose window contains it, by the same rule on
	both sides. Given one challenge and one list of click times, the outcome is
	always identical, which is what lets the server be the authority while the
	client still feels immediate.

	Nothing in here reads config, the clock, or any global. It is a pure function
	of the challenge and the inputs.

	COORDINATES

	Position 0 is the bottom of the track, trackHeightPx the top. The bar's
	position is its CENTRE, and it is kept fully on the track, so its centre lives
	between barHeightPx/2 and trackHeightPx - barHeightPx/2.
]]

local ControlChallenge = require(script.Parent.ControlChallenge)

local ControlSimulation = {}

export type Outcome = "Running" | "Passed" | "FailedLostControl" | "FailedTimeout"

export type State = {
	-- Centre of the white bar, in reference pixels.
	barPosition: number,
	barVelocity: number,

	markerPosition: number,
	markerTarget: number,
	nextEventIndex: number,

	progress: number,
	elapsedSeconds: number,

	--[[
		The inside/outside state the meter is actually acting on. Separate from the
		raw geometric test because of the edge hysteresis below.
	]]
	effectiveInside: boolean,
	-- How long the raw test has disagreed with effectiveInside.
	disagreementSeconds: number,

	-- Diagnostics, useful for tuning and for the dev readout.
	timeInsideSeconds: number,
	clicksApplied: number,

	outcome: Outcome,
}

--[[
	A fresh state at the start of a phase.
]]
function ControlSimulation.createState(challenge: ControlChallenge.Challenge): State
	local half = challenge.barHeightPx / 2
	local barPosition = math.clamp(
		challenge.barStartPosition,
		half,
		challenge.trackHeightPx - half
	)

	local markerPosition = challenge.markerStartPosition

	return {
		barPosition = barPosition,
		barVelocity = 0,

		markerPosition = markerPosition,
		markerTarget = markerPosition,
		nextEventIndex = 1,

		progress = challenge.startingProgress,
		elapsedSeconds = 0,

		-- Both start centred, so the phase opens with the marker inside the bar.
		effectiveInside = math.abs(markerPosition - barPosition) <= half,
		disagreementSeconds = 0,

		timeInsideSeconds = 0,
		clicksApplied = 0,

		outcome = "Running",
	}
end

--[[
	Advances the simulation by exactly one fixed timestep.

	`clicksThisStep` is how many clicks landed inside this step's window. More than
	one has the same effect as one, because a click SETS upward velocity rather
	than adding to it, which is what makes spamming pointless.
]]
function ControlSimulation.step(
	challenge: ControlChallenge.Challenge,
	state: State,
	clicksThisStep: number
)
	if state.outcome ~= "Running" then
		return
	end

	local dt = challenge.fixedTimestepSeconds
	local half = challenge.barHeightPx / 2
	local topLimit = challenge.trackHeightPx - half

	-- Input. Setting rather than adding is the anti-spam measure.
	if clicksThisStep > 0 then
		state.barVelocity = challenge.clickImpulsePxPerSec
		state.clicksApplied += clicksThisStep
	end

	-- Gravity, then clamp so neither direction runs away.
	state.barVelocity -= challenge.gravityPxPerSec2 * dt
	state.barVelocity = math.clamp(
		state.barVelocity,
		-challenge.maxDownwardVelocityPxPerSec,
		challenge.maxUpwardVelocityPxPerSec
	)

	state.barPosition += state.barVelocity * dt

	-- Hitting either end stops the bar dead rather than letting it bounce.
	if state.barPosition < half then
		state.barPosition = half
		state.barVelocity = 0
	elseif state.barPosition > topLimit then
		state.barPosition = topLimit
		state.barVelocity = 0
	end

	--[[
		Marker retargeting. A while loop rather than an if, so a schedule denser
		than the timestep cannot fall behind.
	]]
	local events = challenge.retargetEvents
	while
		state.nextEventIndex <= #events
		and events[state.nextEventIndex].atTime <= state.elapsedSeconds
	do
		state.markerTarget = events[state.nextEventIndex].targetPosition
		state.nextEventIndex += 1
	end

	-- Marker travels toward its target at a constant speed.
	local toTarget = state.markerTarget - state.markerPosition
	local maxMove = challenge.markerSpeedPxPerSec * dt
	if math.abs(toTarget) <= maxMove then
		state.markerPosition = state.markerTarget
	else
		state.markerPosition += if toTarget > 0 then maxMove else -maxMove
	end

	--[[
		Edge hysteresis. The raw test has to disagree with the acted-on state for
		edgeHysteresisSeconds before the meter changes direction, so a marker
		sitting exactly on the boundary does not flicker every frame.
	]]
	local rawInside = math.abs(state.markerPosition - state.barPosition) <= half
	if rawInside ~= state.effectiveInside then
		state.disagreementSeconds += dt
		if state.disagreementSeconds >= challenge.edgeHysteresisSeconds then
			state.effectiveInside = rawInside
			state.disagreementSeconds = 0
		end
	else
		state.disagreementSeconds = 0
	end

	-- Progress.
	if state.effectiveInside then
		state.progress += challenge.fillRatePerSec * dt
		state.timeInsideSeconds += dt
	else
		state.progress -= challenge.drainRatePerSec * dt
	end
	state.progress = math.clamp(state.progress, 0, challenge.maxProgress)

	state.elapsedSeconds += dt

	-- Terminal conditions, checked in order of precedence.
	if state.progress >= challenge.maxProgress then
		state.outcome = "Passed"
	elseif state.progress <= 0 then
		state.outcome = "FailedLostControl"
	elseif state.elapsedSeconds >= challenge.maxPhaseSeconds then
		state.outcome = "FailedTimeout"
	end
end

export type Result = {
	outcome: Outcome,
	finalProgress: number,
	elapsedSeconds: number,
	timeInsideSeconds: number,
	clicksApplied: number,
	stepsSimulated: number,
}

--[[
	Replays a whole phase from a list of click times and returns the result.

	This is what the server runs to decide the outcome. `clickTimes` must be sorted
	ascending; the server sorts and filters before calling.
]]
function ControlSimulation.run(
	challenge: ControlChallenge.Challenge,
	clickTimes: { number }
): Result
	local state = ControlSimulation.createState(challenge)
	local dt = challenge.fixedTimestepSeconds

	-- One extra step of headroom so a phase ending exactly on the bound resolves.
	local maxSteps = math.ceil(challenge.maxPhaseSeconds / dt) + 2

	local cursor = 1
	local stepIndex = 0

	while state.outcome == "Running" and stepIndex < maxSteps do
		local stepEnd = (stepIndex + 1) * dt

		-- Count the clicks belonging to this step's window.
		local clicksThisStep = 0
		while cursor <= #clickTimes and clickTimes[cursor] < stepEnd do
			clicksThisStep += 1
			cursor += 1
		end

		ControlSimulation.step(challenge, state, clicksThisStep)
		stepIndex += 1
	end

	--[[
		Running out of steps without a terminal condition should be impossible,
		because the timeout triggers first. Treated as a timeout rather than left
		ambiguous, so a result is never "Running".
	]]
	if state.outcome == "Running" then
		state.outcome = "FailedTimeout"
	end

	return {
		outcome = state.outcome,
		finalProgress = state.progress,
		elapsedSeconds = state.elapsedSeconds,
		timeInsideSeconds = state.timeInsideSeconds,
		clicksApplied = state.clicksApplied,
		stepsSimulated = stepIndex,
	}
end

--[[
	The share of the phase the marker must spend inside the bar for the meter to
	make any net progress: drain / (fill + drain).

	The clearest single measure of how hard an attempt is, and worth showing during
	tuning.
]]
function ControlSimulation.breakEvenFraction(challenge: ControlChallenge.Challenge): number
	local total = challenge.fillRatePerSec + challenge.drainRatePerSec
	if total <= 0 then
		return 0
	end
	return challenge.drainRatePerSec / total
end

return ControlSimulation
