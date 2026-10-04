--!strict
--[[
	SquatControlService
	Server / Lifting

	Runs ONE control phase, when told to. It does not own an attempt, does not read
	a player's profile, does not resolve difficulty, and owns no RemoteEvents.

	WHY IT WORKS THIS WAY

	It used to listen for its own request remote and start itself, which meant a
	client could trigger a control phase directly and nothing above it could
	sequence phases. Now LiftAttemptService drives it:

		beginPhase(player, context, difficulty, callbacks)
			-> builds the challenge and hands it to callbacks.present
		submitInput(player, payload)
			-> validates, replays, and reports once through callbacks.complete

	That inversion is what lets the orchestrator own phase order and lock an
	attempt's numbers, while this file stays reusable: the same code will run Bench
	Bar Control with no changes, because everything lift-specific comes from the
	phase's config entry.

	WHAT IT STILL OWNS

	Challenge construction, input validation, the authoritative replay, grading,
	its own timeout, and the guarantee that one phase reports exactly once.

	SERVER AUTHORITY

	The client sends the times it clicked. Nothing else. This service replays those
	clicks against its own copy of the marker path and reaches its own conclusion. A
	client that reports a tidier set of clicks than it produced is still only
	choosing inputs, and inputs still have to beat the phase.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LiftingFolder = Shared:WaitForChild("Lifting")

local ControlPhaseConfig = require(ConfigFolder:WaitForChild("ControlPhaseConfig"))
local ControlChallenge = require(LiftingFolder:WaitForChild("ControlChallenge"))
local ControlSimulation = require(LiftingFolder:WaitForChild("ControlSimulation"))
local LiftAttempt = require(LiftingFolder:WaitForChild("LiftAttempt"))

local SquatControlService = {}

-- How long after a phase's own bound the server waits before failing it outright.
local TIMEOUT_GRACE_SECONDS = 2.0

export type Callbacks = {
	present: (challenge: ControlChallenge.Challenge) -> (),
	complete: (result: LiftAttempt.PhaseResult) -> (),
}

type ActivePhase = {
	challenge: ControlChallenge.Challenge,
	attemptId: number,
	issuedAtClock: number,
	callbacks: Callbacks,
	-- Set the moment a result is produced, so a phase can never report twice.
	reported: boolean,
}

local active: { [Player]: ActivePhase } = {}
local rng = Random.new()

local function log(message: string, ...: any)
	print("[SquatControlService] " .. string.format(message, ...))
end

--[[
	Cleans a client's reported click list into something safe to simulate.

	Returns the filtered list. Anything malformed yields an empty list rather than
	an error, which simply means the player made no inputs and the phase drains.
]]
local function sanitiseClickTimes(
	reported: unknown,
	challenge: ControlChallenge.Challenge
): { number }
	if typeof(reported) ~= "table" then
		return {}
	end

	local raw = reported :: { any }
	local limit = challenge.maxPhaseSeconds + ControlPhaseConfig.TimingToleranceSeconds

	--[[
		Hard cap on list length before any other work, so an enormous payload
		cannot cost the server a long loop.
	]]
	local maxEntries = math.ceil(challenge.maxPhaseSeconds * ControlPhaseConfig.MaxClicksPerSecond) + 32

	local cleaned: { number } = {}
	for index = 1, math.min(#raw, maxEntries) do
		local value = raw[index]
		if typeof(value) == "number" then
			local time = value :: number
			-- Reject NaN and infinities before comparing.
			if time == time and time ~= math.huge and time ~= -math.huge then
				if time >= 0 and time <= limit then
					table.insert(cleaned, time)
				end
			end
		end
	end

	table.sort(cleaned)

	--[[
		Enforce the rate cap. Clicks arriving faster than a human could produce are
		dropped rather than rejected outright, because with a velocity-setting
		impulse they would have had no extra effect anyway.
	]]
	local minimumGap = 1 / ControlPhaseConfig.MaxClicksPerSecond
	local accepted: { number } = {}
	local lastAccepted = -math.huge

	for _, time in ipairs(cleaned) do
		if time - lastAccepted >= minimumGap then
			table.insert(accepted, time)
			lastAccepted = time
		end
	end

	return accepted
end

--[[
	Replays the phase and reports the outcome upward exactly once.
]]
local function resolvePhase(player: Player, entry: ActivePhase, reportedClicks: unknown)
	if entry.reported then
		return
	end
	entry.reported = true

	if active[player] == entry then
		active[player] = nil
	end

	local clickTimes = sanitiseClickTimes(reportedClicks, entry.challenge)
	local result = ControlSimulation.run(entry.challenge, clickTimes)

	--[[
		The phase cannot have taken less wall-clock time than it simulated. This is
		what stops a client immediately posting a full winning input sequence for a
		phase it never actually sat through.
	]]
	local serverElapsed = os.clock() - entry.issuedAtClock
	local outcome = result.outcome

	if result.elapsedSeconds > serverElapsed + ControlPhaseConfig.TimingToleranceSeconds then
		warn(string.format(
			"[SquatControlService] %s reported a %.2fs phase but only %.2fs elapsed server-side; failing it",
			player.Name,
			result.elapsedSeconds,
			serverElapsed
		))
		outcome = "FailedLostControl"
	end

	local verdict = ControlChallenge.verdictText(entry.challenge.phase, outcome)

	local detail = string.format(
		"progress %.1f, %.2fs, on target %.2fs, %d clicks accepted",
		result.finalProgress,
		result.elapsedSeconds,
		result.timeInsideSeconds,
		#clickTimes
	)

	log("%s %s -> %s  [%s]", player.Name, entry.challenge.phase, verdict, detail)

	entry.callbacks.complete({
		phaseName = entry.challenge.phase,
		kind = LiftAttempt.PhaseKind.Control,
		passed = outcome == "Passed",
		outcome = outcome,
		verdict = verdict,
		detail = detail,
	})
end

--[[
	Starts a control phase for a player.

	`difficulty` arrives already resolved by the orchestrator from locked inputs, so
	this service never touches a profile and the attempt's numbers cannot drift
	between phases.
]]
function SquatControlService.beginPhase(
	player: Player,
	context: LiftAttempt.PhaseContext,
	difficulty: any,
	callbacks: Callbacks
): boolean
	if active[player] ~= nil then
		warn(string.format("[SquatControlService] %s already has a control phase running", player.Name))
		return false
	end

	if ControlPhaseConfig.Phases[context.phaseName] == nil then
		warn(string.format("[SquatControlService] unknown phase %q", tostring(context.phaseName)))
		return false
	end

	local challenge = ControlChallenge.build(context.phaseName, difficulty, {
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
		Server-side backstop. A client that simply never reports would otherwise
		leave the attempt above us waiting forever.
	]]
	task.delay(challenge.maxPhaseSeconds + TIMEOUT_GRACE_SECONDS, function()
		if active[player] == entry and not entry.reported then
			resolvePhase(player, entry, nil)
		end
	end)

	return true
end

--[[
	Accepts the player's reported inputs for a running control phase.

	`attemptId` is checked so a reply belonging to a finished attempt cannot resolve
	a newer one.
]]
function SquatControlService.submitInput(player: Player, attemptId: number, payload: unknown)
	local entry = active[player]
	if entry == nil then
		return
	end

	if entry.attemptId ~= attemptId then
		warn(string.format(
			"[SquatControlService] %s submitted input for attempt %s during attempt %s; ignored",
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
function SquatControlService.abandon(player: Player)
	local entry = active[player]
	if entry ~= nil then
		entry.reported = true
		active[player] = nil
	end
end

--[[
	True while this player has a control phase running.
]]
function SquatControlService.isRunning(player: Player): boolean
	return active[player] ~= nil
end

return SquatControlService
