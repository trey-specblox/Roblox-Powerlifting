--!strict
--[[
	TypingChallenge
	Shared / Lifting

	Turns a resolved LiftDifficulty into one concrete typing pull.

	THE TOKEN ABSTRACTION

	A challenge carries a list of CUES, and each cue carries a list of TOKENS. A
	token is an opaque string identifier. On a keyboard it is a letter, "A" to "Z".
	On a gamepad it would be "BTN_A" or "DPAD_LEFT"; on touch, an on-screen button.

	The simulation and every server-side check operate on the FLATTENED token list
	and an expected index. Neither ever asks whether a token is a letter. Adding a
	platform is therefore a new vocabulary plus a new UI, not a change to the
	authoritative model -- the same reason ControlInput abstracts the mouse click.

	Only the Keyboard vocabulary is built. The others are architected for, not
	implemented.

	CUES ARE HEADROOM, NOT A SCRIPT

	Completion is by PROGRESS, never by reaching the end of the text. More cues are
	generated than the pull should need, so a player fighting the sag or recovering
	from mistakes cannot run out of characters. Running dry would produce exactly
	the "I typed everything and still failed" state this design exists to prevent.

	SERVER AUTHORITY

	Built once, on the server. The client's copy exists so it can draw the giant
	character and the cue strip; the server replays the player's reported tokens
	against its own copy of this sequence, and that result is the only one that
	counts.
]]

local TypingPhaseConfig = require(script.Parent.Parent.Config.TypingPhaseConfig)
local TypingContentConfig = require(script.Parent.Parent.Config.TypingContentConfig)
local DifficultyResolver = require(script.Parent.Parent.Difficulty.DifficultyResolver)
local ParameterMapper = require(script.Parent.Parent.Difficulty.ParameterMapper)

local TypingChallenge = {}

--[[
	Which vocabulary this challenge's tokens belong to.

	The authoritative simulation does not read this. It exists so the UI knows how
	to draw a token and so the input layer knows how to produce one.
]]
export type Vocabulary = "Keyboard" | "Gamepad" | "Touch"

--[[
	One cue: a label for the player to read, and the tokens it expands to.

	For the keyboard vocabulary the label is the word and the tokens are its
	letters. For a gamepad the label would be a prompt and the tokens a button
	sequence, which is why the two are stored separately rather than the label
	being split on demand.
]]
export type Cue = {
	label: string,
	tokens: { string },
}

export type Challenge = {
	phase: string,
	displayName: string,

	vocabulary: Vocabulary,
	-- Cues in order, for display.
	cues: { Cue },
	--[[
		The same tokens, flattened, in order. THIS is what the simulation and every
		server check read. Carried alongside the cues so neither side has to flatten
		it and risk flattening it differently.
	]]
	tokens: { string },

	-- Progress bounds and where the bar starts.
	progressMax: number,
	startingProgress: number,
	--[[
		Progress that COMPLETES the phase, and the height the bar must reach.
		Reaching it is terminal: nothing further is required.
	]]
	completionThreshold: number,

	-- Progress added per correct token.
	progressPerToken: number,
	-- Progress lost per second, continuously.
	sagPerSecond: number,
	-- Progress lost for a wrong token.
	mistakePenalty: number,

	--[[
		Wall-clock budget. A TIMEOUT, not a target: passing is terminal, so a
		competent pull finishes well inside it.
	]]
	durationSeconds: number,

	--[[
		Sizes the server payload length cap only. There is NO per-key rate limit:
		see TypingPhaseConfig for why one cannot exist here without breaking fast
		typing.
	]]
	maxAverageTokensPerSecond: number,
	fixedTimestepSeconds: number,

	--[[
		Derived and carried for the dev readout and the result log. Not read by the
		simulation.

		The sustained rate that fills the bar exactly as the budget expires, and the
		token count a flawless pull needs.
	]]
	requiredTokensPerSecond: number,
	tokensNeeded: number,

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
	Splits a cue word into keyboard tokens, one per letter.

	The ONLY place a token is tied to a letter. A gamepad vocabulary would add a
	sibling to this function and nothing else would change.
]]
local function keyboardTokens(word: string): { string }
	local tokens: { string } = {}
	for index = 1, #word do
		table.insert(tokens, string.sub(word, index, index))
	end
	return tokens
end

--[[
	Builds the cue sequence.

	Draws from the tiers available at this difficulty until there are comfortably
	more tokens than the pull needs. Cues are drawn at random, and a draw that
	repeats the previous cue is retried once so the same word rarely appears twice
	running -- enough to keep it from looking broken, without the bias a hard ban
	would introduce on a small pool.
]]
local function buildCues(
	difficulty: number,
	tokensNeeded: number,
	rng: Random
): ({ Cue }, { string })
	local pool = TypingContentConfig.wordsFor(difficulty)
	assert(#pool > 0, "[TypingChallenge] no cue words available at this difficulty")

	local target = math.max(
		math.ceil(tokensNeeded * TypingPhaseConfig.CueHeadroomMultiplier),
		1
	)

	local cues: { Cue } = {}
	local flattened: { string } = {}
	local previous: string? = nil

	while #flattened < target do
		local word = pool[rng:NextInteger(1, #pool)]
		if word == previous and #pool > 1 then
			word = pool[rng:NextInteger(1, #pool)]
		end
		previous = word

		local tokens = keyboardTokens(word)
		table.insert(cues, { label = word, tokens = tokens })
		for _, token in ipairs(tokens) do
			table.insert(flattened, token)
		end
	end

	return cues, flattened
end

--[[
	Builds a challenge.

	phaseName  a key in TypingPhaseConfig.Phases
	difficulty a resolved LiftDifficulty
	weights    the kilograms behind that difficulty, for the client's HUD
	rng        the caller's Random, so the server controls cue selection
]]
function TypingChallenge.build(
	phaseName: string,
	difficulty: DifficultyResolver.LiftDifficulty,
	weights: DisplayWeights,
	rng: Random
): Challenge
	local phase = TypingPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[TypingChallenge] unknown phase %q", phaseName))

	local profile = TypingPhaseConfig.Profiles[phase.profile]
	local resolved = ParameterMapper.resolveAll(profile, difficulty)

	local completionThreshold = math.min(
		resolved.completionThreshold,
		TypingPhaseConfig.ProgressMax
	)
	local duration = resolved.duration
	local sag = resolved.sagPerSecond
	local perToken = resolved.progressPerToken

	--[[
		The rate that fills the bar exactly as the budget expires, and the token count
		a flawless pull needs. Both are display and tuning figures; the simulation
		never reads them.
	]]
	local toClimb = completionThreshold - TypingPhaseConfig.StartingProgress
	local requiredRate = (sag + toClimb / duration) / perToken
	local tokensNeeded = math.ceil(toClimb / perToken)

	local cues, tokens = buildCues(difficulty.baseDifficulty, tokensNeeded, rng)

	return {
		phase = phaseName,
		displayName = phase.displayName,

		vocabulary = "Keyboard",
		cues = cues,
		tokens = tokens,

		progressMax = TypingPhaseConfig.ProgressMax,
		startingProgress = TypingPhaseConfig.StartingProgress,
		completionThreshold = completionThreshold,

		progressPerToken = perToken,
		sagPerSecond = sag,
		mistakePenalty = resolved.mistakePenalty,

		durationSeconds = duration,

		maxAverageTokensPerSecond = TypingPhaseConfig.MaxAverageTokensPerSecond,
		fixedTimestepSeconds = TypingPhaseConfig.FixedTimestepSeconds,

		requiredTokensPerSecond = requiredRate,
		tokensNeeded = tokensNeeded,

		attemptWeightKg = weights.attemptWeightKg,
		forecastedMaxKg = weights.forecastedMaxKg,
		intensityPercent = difficulty.intensityPercent,
		baseDifficulty = difficulty.baseDifficulty,
		classification = difficulty.classification,
	}
end

--[[
	The technique stat a phase reads, e.g. "PullStrength" for the deadlift's pull.
]]
function TypingChallenge.techniqueStatFor(phaseName: string): string
	local phase = TypingPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[TypingChallenge] unknown phase %q", phaseName))
	return phase.techniqueStat
end

--[[
	The lift whose forecasted max a phase measures against, e.g. "Deadlift".
]]
function TypingChallenge.liftFor(phaseName: string): string
	local phase = TypingPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[TypingChallenge] unknown phase %q", phaseName))
	return phase.lift
end

--[[
	Whether a name refers to a configured phase, so a client's request can be
	validated without trusting the string it sent.
]]
function TypingChallenge.isKnownPhase(phaseName: unknown): boolean
	if typeof(phaseName) ~= "string" then
		return false
	end
	return TypingPhaseConfig.Phases[phaseName :: string] ~= nil
end

--[[
	The label shown for a phase, e.g. "PULL". The attempt banner uses it so a
	transition can name the phase that is coming next, instead of the client having
	to know each lift's sequence.
]]
function TypingChallenge.displayNameFor(phaseName: string): string
	local phase = TypingPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[TypingChallenge] unknown phase %q", phaseName))
	return phase.displayName
end

--[[
	The player-facing verdict for an outcome, read from the phase's own config so
	one lift's wording cannot leak into another.

	Only two outcomes exist: a mistake cannot end the phase and an empty bar is not
	a loss, so running out of time is the single way to fail.
]]
function TypingChallenge.verdictText(phaseName: string, outcome: string): string
	local phase = TypingPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[TypingChallenge] unknown phase %q", phaseName))

	if outcome == "Passed" then
		return phase.verdicts.pass
	end

	return phase.verdicts.failTimeout
end

return TypingChallenge
