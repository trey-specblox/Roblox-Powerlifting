--!strict
--[[
	TypingPhaseService
	Server / Lifting

	Runs ONE deadlift typing pull, when told to. It does not own an attempt, does
	not read a player's profile, does not resolve difficulty, and owns no
	RemoteEvents. LiftAttemptService drives it, exactly as it drives the control,
	power and skill-check phases.

		beginPhase(player, context, difficulty, callbacks)
			-> builds the challenge and hands it to callbacks.present
		submitInput(player, attemptId, payload)
			-> validates, replays the pull, reports once

	WHAT THE CLIENT SENDS, AND WHAT IT NEVER SENDS

	It sends a list of raw token presses: a timestamp and which token was pressed.
	That is all.

	It never sends progress, a correctness flag, a completion, or a verdict. The
	server generated the expected sequence, replays the tokens against its own copy
	with the same simulation the client drew, and its conclusion is the only one
	that counts. "I typed it correctly" is not a thing a client can say, and
	neither is "the bar reached lockout".

	THE EXPECTED SEQUENCE IS NEVER ECHOED BACK

	The client receives the cues so it can draw them, but it never reports what it
	believed was expected. The server compares against its own list, so a modified
	client can lie about which keys it pressed but not about which keys were right.

	VALIDATION APPLIED TO A TOKEN LIST

		- the payload must be a table, read only up to a hard length cap, so an
		  enormous list cannot cost the server a long loop
		- every entry must be a table with a finite numeric time inside the phase's
		  own window and a token string from the challenge's own vocabulary
		- unknown or malformed tokens are dropped, not credited
		- the list is sorted by time, because the simulation walks it in order
		- the attemptId must match the live attempt
		- a phase reports exactly once
		- the simulated elapsed time cannot exceed the wall-clock time the server
		  measured, which stops a client posting a full winning sequence instantly

	=========================================================================
	WHAT THIS DOES AND DOES NOT ACHIEVE
	=========================================================================

	Blind keyboard-mashing fails outright. A wrong token costs progress and starts
	a slip stall during which nothing is credited, and the bar keeps sagging
	throughout, so hammering keys at random loses ground roughly three to six times
	faster than the budget allows. See TypingPhaseConfig for the arithmetic.

	Paste provides no shortcut. The client captures discrete key events rather than
	reading a text field, so a paste produces no input at all. That is a deliberate
	architectural choice, not an incidental one, and it also sidesteps mobile
	autocorrect.

	TYPING CANNOT BE MADE AUTOMATION-PROOF, and nothing here pretends otherwise.
	The cue has to be on screen for the phase to be playable, so a script that
	reads it and types it at a humane rate is indistinguishable from a skilled
	player. The rate cap bounds an absurd burst; it does not detect a plausible one.
	Because time is not scored, a script that types fast gains nothing but a shorter
	phase.

	TELEMETRY VERSUS GAMEPLAY RULES

	Losing progress to a wrong key is a GAMEPLAY outcome: the character was on
	screen and the player hit something else.

	The interval-regularity figure logged alongside it is a statistical hint and
	nothing more. It is never a reason to fail, punish, kick or flag anyone. There
	is no player data yet from which to pick a threshold, and a steady touch-typist
	would be the first false positive.

	Before a deadlift result affects a PR, a record, currency or a meet placing,
	this needs revisiting with real data in hand.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LiftingFolder = Shared:WaitForChild("Lifting")

local TypingPhaseConfig = require(ConfigFolder:WaitForChild("TypingPhaseConfig"))
local TypingChallenge = require(LiftingFolder:WaitForChild("TypingChallenge"))
local TypingSimulation = require(LiftingFolder:WaitForChild("TypingSimulation"))
local LiftAttempt = require(LiftingFolder:WaitForChild("LiftAttempt"))

local TypingPhaseService = {}

-- How long after a phase's own budget the server waits before failing it.
local TIMEOUT_GRACE_SECONDS = 2.0

export type Callbacks = {
	present: (challenge: TypingChallenge.Challenge) -> (),
	complete: (result: LiftAttempt.PhaseResult) -> (),
}

type ActivePhase = {
	challenge: TypingChallenge.Challenge,
	attemptId: number,
	issuedAtClock: number,
	callbacks: Callbacks,
	--[[
		Every token this challenge could legitimately contain, as a set. Built once
		when the phase begins so validating a reported token is a lookup rather than
		a scan of the sequence.
	]]
	validTokens: { [string]: true },
	-- Set the moment a result is produced, so a phase can never report twice.
	reported: boolean,
}

local active: { [Player]: ActivePhase } = {}
-- Cue selection is server-generated, so the randomness lives here.
local rng = Random.new()

local function log(message: string, ...: any)
	print("[TypingPhaseService] " .. string.format(message, ...))
end

--[[
	Cleans a client's reported token list into something safe to simulate.

	Anything malformed yields an empty list rather than an error, which simply means
	the player produced no input: the bar never rises and the pull times out.
]]
local function sanitiseEvents(
	reported: unknown,
	entry: ActivePhase
): ({ TypingSimulation.TokenEvent }, number)
	if typeof(reported) ~= "table" then
		return {}, 0
	end

	local challenge = entry.challenge
	local raw = reported :: { any }
	local limit = challenge.durationSeconds + TypingPhaseConfig.TimingToleranceSeconds

	--[[
		Hard cap on list length before any other work. Sized from a rate far above
		any human typist, so it bounds memory and loop cost without being reachable
		by play. This is the ONLY size limit; there is no per-key filter.
	]]
	local maxEntries = math.ceil(limit * challenge.maxAverageTokensPerSecond) + 64

	local cleaned: { TypingSimulation.TokenEvent } = {}
	for index = 1, math.min(#raw, maxEntries) do
		local candidate = raw[index]
		if typeof(candidate) == "table" then
			--[[
				Read the SAME field names the shared TokenEvent type declares, and the
				same ones TypingUI writes. Annotated as the shared type rather than cast
				to `any`, so a future divergence between the two sides is a type error
				rather than a silent list of zero.
			]]
			local event = candidate :: TypingSimulation.TokenEvent
			local at = event.time
			local token = event.token

			if typeof(at) == "number" and typeof(token) == "string" then
				-- Reject NaN and infinities before comparing.
				if at == at and at ~= math.huge and at ~= -math.huge then
					--[[
						The token must be one this challenge's vocabulary could produce. A
						token outside it is dropped rather than scored as a mistake: it
						cannot have come from a legitimate keypress, so charging the player
						for it would be charging them for someone else's malformed packet.
					]]
					if at >= 0 and at <= limit and entry.validTokens[token] then
						table.insert(cleaned, { time = at, token = token })
					end
				end
			end
		end
	end

	table.sort(cleaned, function(a, b)
		return a.time < b.time
	end)

	--[[
		NO PER-KEY RATE FILTER. Every surviving token is replayed.

		There used to be one, discarding any token arriving less than 1/12 second
		after the previous. It broke normal play: rolled digraphs -- the LL in PULL,
		the HI in CHIN -- land around 40 to 70ms apart from roughly 50 WPM upward, so
		real keystrokes were discarded here AND in the client's own prediction, which
		made the letter visibly do nothing.

		Removing it costs no security. A token only earns progress if it matches the
		expected one, which only the server knows; a wrong token COSTS progress, so
		flooding is self-defeating; payload size is bounded by the length cap above;
		and the wall-clock check below still rejects a phase reported faster than it
		could have been played. There was nothing left for a per-key limit to do
		except penalise fast typists.

		The second return value is kept at zero so the Result type and the log line
		keep their shape. It becomes meaningful again if a future token vocabulary
		genuinely needs filtering.
	]]
	return cleaned, 0
end

--[[
	Replays the pull and reports the outcome upward exactly once.
]]
local function resolvePhase(player: Player, entry: ActivePhase, reportedEvents: unknown)
	if entry.reported then
		return
	end
	entry.reported = true

	if active[player] == entry then
		active[player] = nil
	end

	local challenge = entry.challenge
	local events, discarded = sanitiseEvents(reportedEvents, entry)
	local result = TypingSimulation.run(challenge, events, discarded)

	--[[
		The phase cannot have taken less wall-clock time than it simulated. This is
		what stops a client immediately posting a complete winning sequence for a
		pull it never actually sat through.
	]]
	local serverElapsed = os.clock() - entry.issuedAtClock
	local outcome = result.outcome

	if result.elapsedSeconds > serverElapsed + TypingPhaseConfig.TimingToleranceSeconds then
		warn(string.format(
			"[TypingPhaseService] %s reported a %.2fs pull but only %.2fs elapsed server-side; failing it",
			player.Name,
			result.elapsedSeconds,
			serverElapsed
		))
		outcome = "FailedTimeout"
	end

	local verdict = TypingChallenge.verdictText(challenge.phase, outcome)

	-- Telemetry only. See the note at the top of this file.
	local times: { number } = {}
	for _, event in ipairs(events) do
		table.insert(times, event.time)
	end
	local regularity = TypingSimulation.inputRegularity(times)
	local regularityText = if regularity
		then string.format("%.1f%%", regularity * 100)
		else "n/a"

	--[[
		Dev-facing. Progress is reported as a PERCENTAGE of completion, the same
		figure the bar shows, so a log line and the player's screen can never look
		like two different quantities.
	]]
	local percent = result.finalProgress / challenge.completionThreshold * 100
	local peakPercent = result.peakProgress / challenge.completionThreshold * 100

	local detail = string.format(
		"progress %.0f%% (peak %.0f%%), %.2fs of %.2fs budget, %d correct of %d needed at %.2f/s, "
			.. "needed %.2f/s, %d wrong (-%.0f progress), %.0f lost to sag, %d rate-discarded",
		percent,
		peakPercent,
		result.elapsedSeconds,
		challenge.durationSeconds,
		result.correctTokens,
		challenge.tokensNeeded,
		result.averageTokensPerSecond,
		challenge.requiredTokensPerSecond,
		result.wrongTokens,
		result.progressLostToMistakes,
		result.progressLostToSag,
		result.discardedTokens
	)

	log(
		"%s %s -> %s  [%s]  (input regularity %s, telemetry only)",
		player.Name,
		challenge.phase,
		verdict,
		detail,
		regularityText
	)

	entry.callbacks.complete({
		phaseName = challenge.phase,
		kind = LiftAttempt.PhaseKind.Typing,
		passed = outcome == "Passed",
		outcome = outcome,
		verdict = verdict,
		detail = detail,
	})
end

--[[
	Starts a typing pull for a player.

	`difficulty` arrives already resolved by the orchestrator from locked inputs, so
	this service never touches a profile and the attempt's numbers cannot drift
	between phases.
]]
function TypingPhaseService.beginPhase(
	player: Player,
	context: LiftAttempt.PhaseContext,
	difficulty: any,
	callbacks: Callbacks
): boolean
	if active[player] ~= nil then
		warn(string.format("[TypingPhaseService] %s already has a typing phase running", player.Name))
		return false
	end

	if TypingPhaseConfig.Phases[context.phaseName] == nil then
		warn(string.format("[TypingPhaseService] unknown phase %q", tostring(context.phaseName)))
		return false
	end

	local challenge = TypingChallenge.build(context.phaseName, difficulty, {
		attemptWeightKg = context.attemptWeightKg,
		forecastedMaxKg = context.forecastedMaxKg,
	}, rng)

	-- Every token this challenge could legitimately contain.
	local validTokens: { [string]: true } = {}
	for _, token in ipairs(challenge.tokens) do
		validTokens[token] = true
	end

	local entry: ActivePhase = {
		challenge = challenge,
		attemptId = context.attemptId,
		issuedAtClock = os.clock(),
		callbacks = callbacks,
		validTokens = validTokens,
		reported = false,
	}
	active[player] = entry

	callbacks.present(challenge)

	--[[
		Server-side backstop. A client that never reports would otherwise leave the
		attempt above us waiting forever.
	]]
	task.delay(challenge.durationSeconds + TIMEOUT_GRACE_SECONDS, function()
		if active[player] == entry and not entry.reported then
			resolvePhase(player, entry, nil)
		end
	end)

	return true
end

--[[
	Accepts the player's reported tokens for a running typing phase.

	`attemptId` is checked so a reply belonging to a finished attempt cannot resolve
	a newer one.
]]
function TypingPhaseService.submitInput(player: Player, attemptId: number, payload: unknown)
	local entry = active[player]
	if entry == nil then
		return
	end

	if entry.attemptId ~= attemptId then
		warn(string.format(
			"[TypingPhaseService] %s submitted input for attempt %s during attempt %s; ignored",
			player.Name,
			tostring(attemptId),
			tostring(entry.attemptId)
		))
		return
	end

	resolvePhase(player, entry, payload)
end

--[[
	Drops a running phase without reporting, for a player leaving or an attempt
	being abandoned from above.
]]
function TypingPhaseService.abandon(player: Player)
	local entry = active[player]
	if entry ~= nil then
		entry.reported = true
		active[player] = nil
	end
end

--[[
	True while this player has a typing phase running.
]]
function TypingPhaseService.isRunning(player: Player): boolean
	return active[player] ~= nil
end

return TypingPhaseService
