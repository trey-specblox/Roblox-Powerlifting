--!strict
--[[
	PowerSimulation
	Shared / Lifting

	The power progress and the holds, as a deterministic fixed-timestep state machine.

	THIS IS THE ONLY COPY OF THE RULES

	The client steps it live to draw a responsive circle. The server replays it from
	the player's reported input transitions to decide the result. Both run this same
	code, so there is no second implementation to drift out of agreement.

	THE STATE MACHINE

		Mash         --power crosses a trigger-->  HoldWarning
		HoldWarning  --telegraph elapses-------->  Hold
		Hold         --required hold produced--->  Mash

		Mash or HoldWarning  --progress reaches completion-->  Passed  [TERMINAL]
		any                  --budget exhausted--------->  FailedTimeout [TERMINAL]

	WHAT EACH STATE DOES

	Mash and HoldWarning behave identically for the progress: presses pay, decay runs.
	The warning is a visual state only, so a player can keep building right up to
	the hold rather than being penalised for the warning existing.

	Hold is where the mechanic lives:
		input held        nothing happens; progress preserved, decay paused
		input not held    decay continues; progress slips outward
		presses           each one costs power, past a short grace

	A HOLD CANNOT BE FAILED

	It has no deadline and no press budget. It ends when the input has been held
	continuously for requiredHoldSeconds, and until then it simply persists. A
	legitimate continuous hold therefore ALWAYS satisfies it, however late it starts
	and whatever the player was doing beforehand. There is no FailedHold outcome.

	That is also what defeats a blind clicker: it never produces a continuous hold,
	so it never leaves the state, and it bleeds power until the budget runs out.

	PASSING IS TERMINAL

	The instant progress reaches the completion threshold the phase is over and the state machine
	stops. No outstanding hold is required, no further hold is triggered, and decay
	cannot pull the player back out. Holds are interruptions on the way in, not a
	checklist to complete afterwards.

	Nothing here reads config, the clock, or any global. It is a pure function of
	the challenge and the inputs.
]]

local PowerChallenge = require(script.Parent.PowerChallenge)

local PowerSimulation = {}

--[[
	Two terminal outcomes. A hold cannot be failed, so running out of budget is the
	only way to lose the phase.
]]
export type Outcome = "Running" | "Passed" | "FailedTimeout"

--[[
	What the player is being asked to do right now.

	"Mash"        click as fast as possible
	"HoldWarning" amber warning; mashing still pays, holding may begin
	"Hold"        keep the input held

	The UI reads this so the player never has to guess.
]]
export type PhaseState = "Mash" | "HoldWarning" | "Hold"

export type State = {
	progress: number,
	elapsedSeconds: number,
	-- Presses credited while mashing was permitted.
	inputsApplied: number,
	-- Highest the progress reached, for feedback on a near miss.
	peakProgress: number,
	-- Wall clock minus time spent inside a hold.
	activeElapsedSeconds: number,

	phaseState: PhaseState,
	-- Index into challenge.holdTriggers of the next trigger being watched.
	nextTriggerIndex: number,
	holdsTriggered: number,
	holdsCompleted: number,
	-- When the current HoldWarning ends, in elapsed seconds.
	warningEndsAt: number,
	-- Elapsed time until which presses during the current hold are free.
	pressGraceUntil: number,

	-- Input reconstruction.
	isHeld: boolean,
	-- Length of the current continuous held run, with short releases stitched.
	heldRunSeconds: number,
	-- Time since the input was released, for the stitch tolerance.
	sinceReleaseSeconds: number,

	-- Telemetry.
	pressesDuringHold: number,
	powerLostToHoldPresses: number,
	powerLostToHoldDecay: number,

	outcome: Outcome,
}

--[[
	A fresh state at the start of a phase.
]]
function PowerSimulation.createState(challenge: PowerChallenge.Challenge): State
	return {
		progress = challenge.startingProgress,
		elapsedSeconds = 0,
		inputsApplied = 0,
		peakProgress = challenge.startingProgress,
		activeElapsedSeconds = 0,

		phaseState = "Mash",
		nextTriggerIndex = 1,
		holdsTriggered = 0,
		holdsCompleted = 0,
		warningEndsAt = 0,
		pressGraceUntil = 0,

		isHeld = false,
		heldRunSeconds = 0,
		-- Starts large so a press at time zero begins a fresh run rather than
		-- stitching onto a release that never happened.
		sinceReleaseSeconds = math.huge,

		pressesDuringHold = 0,
		powerLostToHoldPresses = 0,
		powerLostToHoldDecay = 0,

		outcome = "Running",
	}
end

--[[
	Advances the continuous-held-run tracker by one step.

	A release shorter than the tolerance does not break the run, which lets a
	momentary slip or a one-frame gap through without resetting the player's
	progress toward the hold.
]]
local function trackHeldRun(challenge: PowerChallenge.Challenge, state: State, isHeldNow: boolean)
	local dt = challenge.fixedTimestepSeconds

	if isHeldNow then
		if state.isHeld then
			state.heldRunSeconds += dt
		elseif state.sinceReleaseSeconds <= challenge.releaseToleranceSeconds then
			-- Stitched: the gap was too short to count as letting go.
			state.heldRunSeconds += state.sinceReleaseSeconds + dt
		else
			state.heldRunSeconds = dt
		end
		state.sinceReleaseSeconds = 0
	else
		if state.isHeld then
			-- Just released; start measuring the gap.
			state.sinceReleaseSeconds = 0
		end
		state.sinceReleaseSeconds += dt
		if state.sinceReleaseSeconds > challenge.releaseToleranceSeconds then
			state.heldRunSeconds = 0
		end
	end

	state.isHeld = isHeldNow
end

--[[
	Advances the simulation by exactly one fixed timestep.

	`pressesThisStep` is how many presses landed in this step after the scoring rate
	cap. `isHeldNow` is whether the input is down for this step.
]]
function PowerSimulation.step(
	challenge: PowerChallenge.Challenge,
	state: State,
	pressesThisStep: number,
	isHeldNow: boolean
)
	--[[
		Passing is terminal. Once the outcome is set, no hold logic, decay or mash
		processing runs for this phase ever again.
	]]
	if state.outcome ~= "Running" then
		return
	end

	local dt = challenge.fixedTimestepSeconds

	trackHeldRun(challenge, state, isHeldNow)

	if state.phaseState == "Mash" or state.phaseState == "HoldWarning" then
		--[[
			Mashing pays and decay runs. The warning is a visual state only: a player
			should be able to keep building right up to the hold rather than losing
			ground because a warning appeared.
		]]
		if pressesThisStep > 0 then
			state.progress += challenge.powerPerInput * pressesThisStep
			state.inputsApplied += pressesThisStep
		end

		state.progress = math.min(state.progress, challenge.progressMax)
		if state.progress > state.peakProgress then
			state.peakProgress = state.progress
		end

		state.progress = math.max(state.progress - challenge.decayPerSecond * dt, 0)
		state.activeElapsedSeconds += dt

		--[[
			POWER SUCCESS, checked before any trigger can fire.

			Reaching the inner circle wins outright. It is deliberately checked here,
			ahead of the trigger test below, so that crossing the completion threshold and
			crossing a trigger in the same step can resolve only one way: success. No
			hold appears once the phase is won.
		]]
		if state.progress >= challenge.completionThreshold then
			state.outcome = "Passed"
			state.elapsedSeconds += dt
			return
		end

		if state.phaseState == "Mash" then
			--[[
				PROGRESS TRIGGER. Every trigger sits strictly below the completion threshold, so
				this can only fire while the player is still building.
			]]
			local triggers = challenge.holdTriggers
			if
				state.nextTriggerIndex <= #triggers
				and state.progress >= triggers[state.nextTriggerIndex]
			then
				state.nextTriggerIndex += 1
				state.phaseState = "HoldWarning"
				state.warningEndsAt = state.elapsedSeconds + challenge.telegraphSeconds
			end
		elseif state.elapsedSeconds >= state.warningEndsAt then
			state.phaseState = "Hold"
			state.holdsTriggered += 1
			state.pressGraceUntil = state.elapsedSeconds + challenge.pressGraceSeconds
			--[[
				The hold measures a NEW continuous run from here.

				Without this reset, a player who happened to be holding through the
				warning would satisfy the hold the instant it appeared, which would make
				anticipating it a way to skip the mechanic. Resetting costs an
				anticipating player nothing but time: they are already holding, so the
				run simply rebuilds and completes.
			]]
			state.heldRunSeconds = 0
			state.sinceReleaseSeconds = math.huge
		end
	else
		--[[
			HOLD.

			Holding correctly does nothing at all: no power gained, no power lost, no
			decay. That is the whole reward, and it is why a correct hold can never go
			wrong.
		]]
		if not isHeldNow then
			-- Not holding: progress slips outward.
			local lost = math.min(challenge.decayPerSecond * dt, state.progress)
			state.progress -= lost
			state.powerLostToHoldDecay += lost
		end

		--[[
			Clicking through a hold is the one punished behaviour, past a short grace.

			The grace exists because a player mashing several times a second cannot
			stop instantly: one or two clicks always land just after the instruction
			changes, and those are reaction rather than defiance.
		]]
		if pressesThisStep > 0 and state.elapsedSeconds >= state.pressGraceUntil then
			local cost = math.min(challenge.holdPressPenalty * pressesThisStep, state.progress)
			state.progress -= cost
			state.pressesDuringHold += pressesThisStep
			state.powerLostToHoldPresses += cost
		end

		--[[
			SATISFIED. No deadline is consulted, because a hold has none: it ends when
			the required continuous hold has been produced, and persists until then.
		]]
		if state.heldRunSeconds >= challenge.requiredHoldSeconds then
			state.phaseState = "Mash"
			state.holdsCompleted += 1
			state.heldRunSeconds = 0
		end
	end

	state.elapsedSeconds += dt

	if state.elapsedSeconds >= challenge.durationSeconds then
		state.outcome = "FailedTimeout"
	end
end

export type Result = {
	outcome: Outcome,
	finalProgress: number,
	peakProgress: number,
	elapsedSeconds: number,
	activeElapsedSeconds: number,
	inputsApplied: number,
	-- Presses divided by ACTIVE time, so it is comparable with the required rate.
	averageInputsPerSecond: number,

	holdsTriggered: number,
	holdsCompleted: number,
	pressesDuringHold: number,
	powerLostToHoldPresses: number,
	powerLostToHoldDecay: number,
}

--[[
	One reported input transition. `down` true is a press, false is a release.
]]
export type InputEvent = {
	time: number,
	down: boolean,
}

--[[
	Replays a whole phase from a list of input transitions and returns the result.

	This is what the server runs to decide the outcome. `events` must be sorted
	ascending and already sanitised; the server does both before calling.

	`acceptedPressTimes` is the rate-capped subset used for MASH scoring. It is
	separate from the transition list on purpose: a press discarded for arriving too
	fast still means the input is down, so it still contributes to a held run. The
	cap limits how much mashing pays, not what the button is physically doing.
]]
function PowerSimulation.run(
	challenge: PowerChallenge.Challenge,
	events: { InputEvent },
	acceptedPressTimes: { number }
): Result
	local state = PowerSimulation.createState(challenge)
	local dt = challenge.fixedTimestepSeconds

	-- One extra step of headroom so a phase ending exactly on the bound resolves.
	local maxSteps = math.ceil(challenge.durationSeconds / dt) + 2

	local eventCursor = 1
	local pressCursor = 1
	local stepIndex = 0
	local held = false

	while state.outcome == "Running" and stepIndex < maxSteps do
		local stepEnd = (stepIndex + 1) * dt

		--[[
			Apply every transition inside this step, in order. The LAST one decides
			whether the input is down for the step, which is the best a fixed timestep
			can do and is accurate to one sixtieth of a second.
		]]
		while eventCursor <= #events and events[eventCursor].time < stepEnd do
			held = events[eventCursor].down
			eventCursor += 1
		end

		local pressesThisStep = 0
		while pressCursor <= #acceptedPressTimes and acceptedPressTimes[pressCursor] < stepEnd do
			pressesThisStep += 1
			pressCursor += 1
		end

		PowerSimulation.step(challenge, state, pressesThisStep, held)
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

	local average = 0
	if state.activeElapsedSeconds > 0 then
		average = state.inputsApplied / state.activeElapsedSeconds
	end

	return {
		outcome = state.outcome,
		finalProgress = state.progress,
		peakProgress = state.peakProgress,
		elapsedSeconds = state.elapsedSeconds,
		activeElapsedSeconds = state.activeElapsedSeconds,
		inputsApplied = state.inputsApplied,
		averageInputsPerSecond = average,

		holdsTriggered = state.holdsTriggered,
		holdsCompleted = state.holdsCompleted,
		pressesDuringHold = state.pressesDuringHold,
		powerLostToHoldPresses = state.powerLostToHoldPresses,
		powerLostToHoldDecay = state.powerLostToHoldDecay,
	}
end

--[[
	Interval regularity across a set of press times, as a coefficient of variation:
	the standard deviation of the gaps divided by their mean.

	TELEMETRY ONLY. Human mashing is jittery and lands around 20-30%; an autoclicker
	is metronomic and lands near 0%. That is a large, real difference, but this value
	must NOT be used to fail, punish or flag anyone. There is no player data yet from
	which to choose a threshold, and a fast, steady human would be the first false
	positive.

	It is computed and logged so that data exists before any decision is made.

	Returns nil when there are too few presses to say anything.
]]
function PowerSimulation.inputRegularity(pressTimes: { number }): number?
	if #pressTimes < 4 then
		return nil
	end

	local gapCount = #pressTimes - 1
	local total = 0
	for index = 2, #pressTimes do
		total += pressTimes[index] - pressTimes[index - 1]
	end

	local mean = total / gapCount
	if mean <= 0 then
		return nil
	end

	local varianceSum = 0
	for index = 2, #pressTimes do
		local gap = pressTimes[index] - pressTimes[index - 1]
		varianceSum += (gap - mean) * (gap - mean)
	end

	return math.sqrt(varianceSum / gapCount) / mean
end

return PowerSimulation
