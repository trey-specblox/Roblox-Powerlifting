--!strict
--[[
	TypingSimulation
	Shared / Lifting

	The deadlift's bar height, as a deterministic fixed-timestep simulation.

	THIS IS THE ONLY COPY OF THE RULES

	The client steps it live so the bar moves the instant a key lands. The server
	replays it from the player's reported tokens to decide the result. Both run
	this same code, so there is no second implementation to drift out of agreement.

	ONE AUTHORITATIVE VALUE

	`progress` drives the bar's height AND the pass condition. The bar reaching
	lockout IS the pass, because `progress >= completionThreshold` is the only test
	there is. No second requirement sits behind a visually completed bar.

	PER STEP

		correct token  ->  progress += progressPerToken, expected index advances
		wrong token    ->  progress -= mistakePenalty,
		                   EXPECTED INDEX DOES NOT MOVE
		every step     ->  progress -= sagPerSecond * dt

	EVERY TOKEN IS PROCESSED. There is no stall, no debounce and no rate limit
	anywhere in this phase, so a keystroke is never silently withheld.

		progress >= completionThreshold  ->  Passed        [TERMINAL]
		budget expires                   ->  FailedTimeout [TERMINAL]

	WHY A MISTAKE DOES NOT CASCADE

	The expected index stays put after a wrong token, so the player simply has to
	hit the right key. A mistake mid-cue never scrambles what follows, and no
	following keystroke is discarded. The cost is paid in progress alone.

	WHY PROGRESS REACHING ZERO IS NOT A FAILURE

	An empty bar is a bad position, not a loss, which matches the Bench's power
	phase. Keeping one failure mode means there is no second way to lose that a
	player has to discover.

	TOKENS ARE OPAQUE

	Nothing here asks whether a token is a letter. It compares the reported string
	against the expected string. That is what lets a gamepad or touch vocabulary be
	added later without touching the authoritative model.

	Nothing here reads config, the clock, or any global. It is a pure function of
	the challenge and the inputs.
]]

local TypingChallenge = require(script.Parent.TypingChallenge)

local TypingSimulation = {}

--[[
	Two terminal outcomes. Running out of the budget is the only way to lose.
]]
export type Outcome = "Running" | "Passed" | "FailedTimeout"

export type State = {
	progress: number,
	elapsedSeconds: number,
	-- Highest the bar reached, for feedback on a near miss.
	peakProgress: number,

	--[[
		Index into challenge.tokens of the token the player must produce next. Only
		a CORRECT token advances it.
	]]
	expectedIndex: number,
	correctTokens: number,
	wrongTokens: number,
	--[[
		Tokens discarded for arriving faster than the rate cap. Telemetry: a high
		count on an honest client would mean the cap is too tight.
	]]
	discardedTokens: number,

	progressLostToMistakes: number,
	progressLostToSag: number,

	outcome: Outcome,
}

--[[
	A fresh state at the start of a phase.
]]
function TypingSimulation.createState(challenge: TypingChallenge.Challenge): State
	return {
		progress = challenge.startingProgress,
		elapsedSeconds = 0,
		peakProgress = challenge.startingProgress,

		expectedIndex = 1,
		correctTokens = 0,
		wrongTokens = 0,
		discardedTokens = 0,


		progressLostToMistakes = 0,
		progressLostToSag = 0,

		outcome = "Running",
	}
end

--[[
	The token the player must produce next, or nil once the generated cues are
	exhausted.

	Exhaustion should not happen: cue generation produces well over what a pull
	needs. If it ever did, further tokens simply stop being credited and the sag
	decides the lift, which is the safest possible degradation.
]]
function TypingSimulation.expectedToken(
	challenge: TypingChallenge.Challenge,
	state: State
): string?
	return challenge.tokens[state.expectedIndex]
end

--[[
	Advances the simulation by exactly one fixed timestep.

	`tokensThisStep` is the tokens that landed in this step, in order, already
	filtered by the rate cap. Several can land in one step at high typing speeds.
]]
function TypingSimulation.step(
	challenge: TypingChallenge.Challenge,
	state: State,
	tokensThisStep: { string }
)
	--[[
		Passing is terminal. Once the outcome is set, no token or sag is
		processed for this phase ever again.
	]]
	if state.outcome ~= "Running" then
		return
	end

	local dt = challenge.fixedTimestepSeconds

	--[[
		EVERY TOKEN IS PROCESSED. Nothing is ever silently withheld.

		An earlier version ignored input for 0.12s after a mistake, which meant one
		fumbled key threw away the next two or three -- including correct ones -- with
		no feedback. That is what made the controls feel broken. The progress penalty
		is the entire punishment now, and it is more than sufficient: see
		TypingPhaseConfig for the arithmetic showing mashing is heavily net-negative
		without any stall at all.
	]]
	for _, token in ipairs(tokensThisStep) do
		local expected = challenge.tokens[state.expectedIndex]
		if expected ~= nil and token == expected then
			state.progress += challenge.progressPerToken
			state.expectedIndex += 1
			state.correctTokens += 1
		else
			--[[
				Wrong token. The expected index deliberately does NOT move, so the player
				has only to hit the right key and a mistake never cascades into the rest
				of the cue.
			]]
			local lost = math.min(challenge.mistakePenalty, state.progress)
			state.progress -= lost
			state.progressLostToMistakes += lost
			state.wrongTokens += 1
		end
	end

	state.progress = math.min(state.progress, challenge.progressMax)
	if state.progress > state.peakProgress then
		state.peakProgress = state.progress
	end

	-- The bar sags continuously, so hesitation costs height.
	local sag = math.min(challenge.sagPerSecond * dt, state.progress)
	state.progress -= sag
	state.progressLostToSag += sag

	--[[
		THE ONE COMPLETION CONDITION.

		Checked against the same value that drives the bar's height, so the bar
		touching lockout and the phase passing are the same event.
	]]
	if state.progress >= challenge.completionThreshold then
		state.outcome = "Passed"
		state.elapsedSeconds += dt
		return
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

	correctTokens: number,
	wrongTokens: number,
	discardedTokens: number,
	-- Correct tokens divided by elapsed time, comparable with the required rate.
	averageTokensPerSecond: number,

	progressLostToMistakes: number,
	progressLostToSag: number,
}

--[[
	One reported token press.
]]
export type TokenEvent = {
	time: number,
	token: string,
}

--[[
	Replays a whole phase from a list of token presses and returns the result.

	This is what the server runs to decide the outcome. `events` must be sorted
	ascending and already sanitised; the server does both before calling.

	`discarded` is how many the rate cap removed, carried through for the log only.
]]
function TypingSimulation.run(
	challenge: TypingChallenge.Challenge,
	events: { TokenEvent },
	discarded: number
): Result
	local state = TypingSimulation.createState(challenge)
	state.discardedTokens = discarded

	local dt = challenge.fixedTimestepSeconds
	-- One extra step of headroom so a phase ending exactly on the bound resolves.
	local maxSteps = math.ceil(challenge.durationSeconds / dt) + 2

	local cursor = 1
	local stepIndex = 0

	while state.outcome == "Running" and stepIndex < maxSteps do
		local stepEnd = (stepIndex + 1) * dt

		-- Every token inside this step, in order.
		local batch: { string } = {}
		while cursor <= #events and events[cursor].time < stepEnd do
			table.insert(batch, events[cursor].token)
			cursor += 1
		end

		TypingSimulation.step(challenge, state, batch)
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
	if state.elapsedSeconds > 0 then
		average = state.correctTokens / state.elapsedSeconds
	end

	return {
		outcome = state.outcome,
		finalProgress = state.progress,
		peakProgress = state.peakProgress,
		elapsedSeconds = state.elapsedSeconds,

		correctTokens = state.correctTokens,
		wrongTokens = state.wrongTokens,
		discardedTokens = state.discardedTokens,
		averageTokensPerSecond = average,

		progressLostToMistakes = state.progressLostToMistakes,
		progressLostToSag = state.progressLostToSag,
	}
end

--[[
	Interval regularity across a set of token times, as a coefficient of variation:
	the standard deviation of the gaps divided by their mean.

	TELEMETRY ONLY. Human typing is uneven and lands well above zero; a script is
	metronomic and lands near it. That is a real difference, but this value must NOT
	be used to fail, punish or flag anyone. There is no player data yet from which
	to choose a threshold, and a steady touch-typist would be the first false
	positive.

	It is computed and logged so that data exists before any decision is made.

	Returns nil when there are too few tokens to say anything.
]]
function TypingSimulation.inputRegularity(times: { number }): number?
	if #times < 4 then
		return nil
	end

	local gapCount = #times - 1
	local total = 0
	for index = 2, #times do
		total += times[index] - times[index - 1]
	end

	local mean = total / gapCount
	if mean <= 0 then
		return nil
	end

	local varianceSum = 0
	for index = 2, #times do
		local gap = times[index] - times[index - 1]
		varianceSum += (gap - mean) * (gap - mean)
	end

	return math.sqrt(varianceSum / gapCount) / mean
end

return TypingSimulation
