--!strict
--[[
	PowerPhaseService
	Server / Lifting

	Runs ONE Test Your Might power phase, when told to. It does not own an attempt,
	does not read a player's profile, does not resolve difficulty, and owns no
	RemoteEvents. LiftAttemptService drives it, exactly as it drives the control and
	skill-check phases.

		beginPhase(player, context, difficulty, callbacks)
			-> builds the challenge and hands it to callbacks.present
		submitInput(player, attemptId, payload)
			-> validates, reconstructs the progress and the held runs, reports once

	WHAT THE CLIENT SENDS, AND WHAT IT NEVER SENDS

	It sends a list of raw input transitions: a timestamp and whether the input went
	down or up. That is all.

	It never sends a progress value, a hold result, a penalty, a pass or a fail. The
	server reconstructs the held intervals itself with the same simulation the
	client drew, and the server's conclusion is the only one that counts. "I held it
	successfully" is not a thing a client can say, and neither is "I reached the
	inner circle".

	VALIDATION APPLIED TO A TRANSITION LIST

		- the payload must be a table, read only up to a hard length cap, so an
		  enormous list cannot cost the server a long loop
		- every entry must be a table with a finite numeric time inside the phase's
		  own window and a boolean direction
		- the list is sorted by time, because the simulation walks it in order
		- consecutive duplicates are dropped: two presses with no release between
		  them, or two releases with no press, carry no information, and a client
		  cannot manufacture hold time by repeating "down"
		- a list opening with a release is trimmed, so a hold cannot be credited to
		  an input that went down before the phase began
		- presses closer together than the rate cap are discarded FOR SCORING MASH
		  POWER, while still counting as the input being down
		- the attemptId must match the live attempt
		- a phase reports exactly once
		- the simulated elapsed time cannot exceed the wall-clock time the server
		  measured, which stops a client posting a full winning sequence instantly

	=========================================================================
	WHAT THIS DOES AND DOES NOT ACHIEVE
	=========================================================================

	A hold has no deadline: it ends only when a continuous hold of the required
	length is produced. A basic repeated-click autoclicker never produces one, so it
	never leaves the hold. It bleeds power at the penalty rate while the clock runs
	down, and the phase times out.

	That is a real improvement: a pure mash was a free pass for such a tool.

	IT IS NOT CHEAT-PROOF, and nothing here pretends otherwise. The client has to
	know a hold is active in order to draw the instruction, so automation that reads
	that state can issue a single press and hold, and look exactly like a careful
	human. A macro watching the screen does the same. Any telegraphed mechanic has
	this property, because the information must reach the screen to be playable.

	TELEMETRY VERSUS GAMEPLAY RULES

	Losing power to clicks during a hold is a GAMEPLAY outcome. The player was
	warned, kept clicking, and paid for it.

	The interval-regularity figure logged alongside it is a statistical hint and
	nothing more. It is never a reason to fail, punish, kick or flag anyone. There
	is no player data yet from which to pick a threshold, and the first false
	positive would be a genuinely fast, steady human.

	Before a bench result affects a PR, a record, currency or a meet placing, this
	needs revisiting with real data in hand.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LiftingFolder = Shared:WaitForChild("Lifting")

local PowerPhaseConfig = require(ConfigFolder:WaitForChild("PowerPhaseConfig"))
local PowerChallenge = require(LiftingFolder:WaitForChild("PowerChallenge"))
local PowerSimulation = require(LiftingFolder:WaitForChild("PowerSimulation"))
local LiftAttempt = require(LiftingFolder:WaitForChild("LiftAttempt"))

local PowerPhaseService = {}

-- How long after a phase's own budget the server waits before failing it.
local TIMEOUT_GRACE_SECONDS = 2.0

export type Callbacks = {
	present: (challenge: PowerChallenge.Challenge) -> (),
	complete: (result: LiftAttempt.PhaseResult) -> (),
}

type ActivePhase = {
	challenge: PowerChallenge.Challenge,
	attemptId: number,
	issuedAtClock: number,
	callbacks: Callbacks,
	-- Set the moment a result is produced, so a phase can never report twice.
	reported: boolean,
}

local active: { [Player]: ActivePhase } = {}
-- Hold trigger placement is server-generated, so the randomness lives here.
local rng = Random.new()

local function log(message: string, ...: any)
	print("[PowerPhaseService] " .. string.format(message, ...))
end

--[[
	Cleans a client's reported transition list into something safe to simulate.

	Anything malformed yields an empty list rather than an error, which simply means
	the player produced no inputs: the progress never rises and the phase times out.
]]
local function sanitiseEvents(
	reported: unknown,
	challenge: PowerChallenge.Challenge
): { PowerSimulation.InputEvent }
	if typeof(reported) ~= "table" then
		return {}
	end

	local raw = reported :: { any }
	local limit = challenge.durationSeconds + PowerPhaseConfig.TimingToleranceSeconds

	--[[
		Hard cap on list length before any other work. A press and a release per
		accepted input across the whole window, plus slack.
	]]
	local maxEntries = math.ceil(limit * challenge.maxInputsPerSecond * 2) + 64

	local cleaned: { PowerSimulation.InputEvent } = {}
	for index = 1, math.min(#raw, maxEntries) do
		local entry = raw[index]
		if typeof(entry) == "table" then
			--[[
				Read the SAME field names the shared InputEvent type declares, and the
				same ones PowerUI writes.

				This previously read `.t` and `.d`, short keys from an earlier draft of
				the wire format that the client never actually adopted. Every entry
				therefore failed the type test below, the list came back empty, and the
				server replayed a phase with no inputs at all while the client's own
				ring had reached the centre. The `:: any` cast is what hid it: casting
				away the type meant the checker could not see that nothing on the wire
				had a `t` field.

				Annotating the entry as the shared type instead of `any` is the actual
				guard. If the client's field names and this parser ever diverge again,
				it is now a type error rather than a silent zero.
			]]
			local candidate = entry :: PowerSimulation.InputEvent
			local at = candidate.time
			local down = candidate.down
			if typeof(at) == "number" and typeof(down) == "boolean" then
				-- Reject NaN and infinities before comparing.
				if at == at and at ~= math.huge and at ~= -math.huge then
					if at >= 0 and at <= limit then
						table.insert(cleaned, { time = at, down = down })
					end
				end
			end
		end
	end

	table.sort(cleaned, function(a, b)
		return a.time < b.time
	end)

	--[[
		Drop consecutive duplicates. Two presses with no release between them, or two
		releases with no press, describe no change. Dropping them also means a client
		cannot manufacture extra hold time or extra presses by repeating a direction.
	]]
	local collapsed: { PowerSimulation.InputEvent } = {}
	local lastDown: boolean? = nil
	for _, event in ipairs(cleaned) do
		if lastDown == nil or event.down ~= lastDown then
			table.insert(collapsed, event)
			lastDown = event.down
		end
	end

	--[[
		A list that opens with a release describes an input that went down before the
		phase began. Dropped, so a hold cannot be credited to time outside the phase.
	]]
	if #collapsed > 0 and not collapsed[1].down then
		table.remove(collapsed, 1)
	end

	return collapsed
end

--[[
	The press times that count toward MASH power, after the rate cap.

	Separate from the transition list on purpose: a press discarded for arriving too
	fast still means the input is down, so it still contributes to a held run. The
	cap limits how much mashing pays, not what the button is physically doing.
]]
local function acceptedPressTimes(
	events: { PowerSimulation.InputEvent },
	challenge: PowerChallenge.Challenge
): { number }
	local minimumGap = 1 / challenge.maxInputsPerSecond
	local accepted: { number } = {}
	local lastAccepted = -math.huge

	for _, event in ipairs(events) do
		if event.down and event.time - lastAccepted >= minimumGap then
			table.insert(accepted, event.time)
			lastAccepted = event.time
		end
	end

	return accepted
end

--[[
	Reconstructs the phase and reports the outcome upward exactly once.
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
	local events = sanitiseEvents(reportedEvents, challenge)
	local presses = acceptedPressTimes(events, challenge)
	local result = PowerSimulation.run(challenge, events, presses)

	--[[
		The phase cannot have taken less wall-clock time than it simulated. This is
		what stops a client immediately posting a complete winning sequence for a
		phase it never actually sat through.
	]]
	local serverElapsed = os.clock() - entry.issuedAtClock
	local outcome = result.outcome

	if result.elapsedSeconds > serverElapsed + PowerPhaseConfig.TimingToleranceSeconds then
		warn(string.format(
			"[PowerPhaseService] %s reported a %.2fs phase but only %.2fs elapsed server-side; failing it",
			player.Name,
			result.elapsedSeconds,
			serverElapsed
		))
		outcome = "FailedTimeout"
	end

	local verdict = PowerChallenge.verdictText(challenge.phase, outcome)

	-- Telemetry only. See the note at the top of this file.
	local regularity = PowerSimulation.inputRegularity(presses)
	local regularityText = if regularity
		then string.format("%.1f%%", regularity * 100)
		else "n/a"

	--[[
		Dev-facing. Progress is reported as a PERCENTAGE of completion, the same
		figure the circle shows, so a log line and the player's screen can never look
		like two different quantities.
	]]
	local percent = result.finalProgress / challenge.completionThreshold * 100
	local peakPercent = result.peakProgress / challenge.completionThreshold * 100

	local detail = string.format(
		"progress %.0f%% (peak %.0f%%), %.2fs active of %.2fs designed, %.2fs elapsed of %.2fs budget, "
			.. "%d presses at %.2f/s, needed %.2f/s, "
			.. "holds %d/%d completed, %d presses during holds cost %.0f progress, %.0f lost to slipping",
		percent,
		peakPercent,
		result.activeElapsedSeconds,
		challenge.activeSeconds,
		result.elapsedSeconds,
		challenge.durationSeconds,
		result.inputsApplied,
		result.averageInputsPerSecond,
		challenge.requiredInputsPerSecond,
		result.holdsCompleted,
		result.holdsTriggered,
		result.pressesDuringHold,
		result.powerLostToHoldPresses,
		result.powerLostToHoldDecay
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
		kind = LiftAttempt.PhaseKind.Power,
		passed = outcome == "Passed",
		outcome = outcome,
		verdict = verdict,
		detail = detail,
	})
end

--[[
	Starts a power phase for a player.

	`difficulty` arrives already resolved by the orchestrator from locked inputs, so
	this service never touches a profile and the attempt's numbers cannot drift
	between phases.
]]
function PowerPhaseService.beginPhase(
	player: Player,
	context: LiftAttempt.PhaseContext,
	difficulty: any,
	callbacks: Callbacks
): boolean
	if active[player] ~= nil then
		warn(string.format("[PowerPhaseService] %s already has a power phase running", player.Name))
		return false
	end

	if PowerPhaseConfig.Phases[context.phaseName] == nil then
		warn(string.format("[PowerPhaseService] unknown phase %q", tostring(context.phaseName)))
		return false
	end

	local challenge = PowerChallenge.build(context.phaseName, difficulty, {
		attemptWeightKg = context.attemptWeightKg,
		forecastedMaxKg = context.forecastedMaxKg,
	}, rng)

	local entry: ActivePhase = {
		challenge = challenge,
		attemptId = context.attemptId,
		issuedAtClock = os.clock(),
		callbacks = callbacks,
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
	Accepts the player's reported input transitions for a running power phase.

	`attemptId` is checked so a reply belonging to a finished attempt cannot resolve
	a newer one.
]]
function PowerPhaseService.submitInput(player: Player, attemptId: number, payload: unknown)
	local entry = active[player]
	if entry == nil then
		return
	end

	if entry.attemptId ~= attemptId then
		warn(string.format(
			"[PowerPhaseService] %s submitted input for attempt %s during attempt %s; ignored",
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
function PowerPhaseService.abandon(player: Player)
	local entry = active[player]
	if entry ~= nil then
		entry.reported = true
		active[player] = nil
	end
end

--[[
	True while this player has a power phase running.
]]
function PowerPhaseService.isRunning(player: Player): boolean
	return active[player] ~= nil
end

return PowerPhaseService
