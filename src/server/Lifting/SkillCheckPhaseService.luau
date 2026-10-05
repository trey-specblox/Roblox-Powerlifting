--!strict
--[[
	SkillCheckPhaseService
	Server / Lifting

	Runs ONE timing skill check phase, when told to. It does not own an attempt,
	does not read a player's profile, does not resolve difficulty, and owns no
	RemoteEvents.

	WHY IT WORKS THIS WAY

	It used to listen for its own request remote, which meant a client could ask for
	Squat Depth directly and skip the control phase entirely. Now
	LiftAttemptService drives it:

		beginPhase(player, context, difficulty, callbacks)
			-> builds the challenge and hands it to callbacks.present
		submitInput(player, attemptId, payload)
			-> validates, grades, and reports once through callbacks.complete

	That inversion is what makes phase order a server property. This file stays
	reusable: the same code will run Bench Press and Deadlift Lockout, because
	everything lift-specific comes from the phase's config entry.

	WHAT IT STILL OWNS

	Challenge construction, press validation, grading, its own timeout, and the
	guarantee that one phase reports exactly once.

	HONEST LIMIT OF THE VALIDATION

	The press time comes from the client, because only the client knows when the key
	went down. The server checks the claimed time against its own measurement of how
	long the round trip took, which defeats claiming a perfect press on a check that
	has long since expired. It does NOT defeat a plausible-but-false time inside the
	latency tolerance. That is inherent to client-timed input and is the weaker of
	the squat's two phases.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LiftingFolder = Shared:WaitForChild("Lifting")

local SkillCheckConfig = require(ConfigFolder:WaitForChild("SkillCheckConfig"))
local SkillCheckChallenge = require(LiftingFolder:WaitForChild("SkillCheckChallenge"))
local SkillCheckGrade = require(LiftingFolder:WaitForChild("SkillCheckGrade"))
local LiftAttempt = require(LiftingFolder:WaitForChild("LiftAttempt"))

local SkillCheckPhaseService = {}

-- How long after a check expires the server waits before failing it outright.
local TIMEOUT_GRACE_SECONDS = 0.75

export type Callbacks = {
	present: (challenge: SkillCheckChallenge.Challenge) -> (),
	complete: (result: LiftAttempt.PhaseResult) -> (),
}

type ActivePhase = {
	challenge: SkillCheckChallenge.Challenge,
	attemptId: number,
	issuedAtClock: number,
	callbacks: Callbacks,
	-- Set the moment a result is produced, so a phase can never report twice.
	reported: boolean,
}

local active: { [Player]: ActivePhase } = {}
local rng = Random.new()

local function log(message: string, ...: any)
	print("[SkillCheckPhaseService] " .. string.format(message, ...))
end

--[[
	Grades the press and reports the outcome upward exactly once.
]]
local function resolvePhase(player: Player, entry: ActivePhase, pressTimeSeconds: number?)
	if entry.reported then
		return
	end
	entry.reported = true

	if active[player] == entry then
		active[player] = nil
	end

	local result = SkillCheckGrade.evaluate(entry.challenge, pressTimeSeconds)
	-- Wording comes from the challenge's own phase, never a shared default.
	local verdict = SkillCheckGrade.verdictText(result, entry.challenge.phase)

	local detail = if result.failureReason
		then string.format("failed: %s", result.failureReason)
		else string.format("hit at %.1f deg", result.needleAngleDeg or 0)

	log("%s %s -> %s  [%s]", player.Name, entry.challenge.phase, verdict, detail)

	entry.callbacks.complete({
		phaseName = entry.challenge.phase,
		kind = LiftAttempt.PhaseKind.SkillCheck,
		passed = result.passed,
		outcome = result.failureReason or "Hit",
		verdict = verdict,
		detail = detail,
	})
end

--[[
	Starts a skill check phase for a player.

	`difficulty` arrives already resolved by the orchestrator from locked inputs, so
	this service never touches a profile and the attempt's numbers cannot drift
	between phases.
]]
function SkillCheckPhaseService.beginPhase(
	player: Player,
	context: LiftAttempt.PhaseContext,
	difficulty: any,
	callbacks: Callbacks
): boolean
	if active[player] ~= nil then
		warn(string.format("[SkillCheckPhaseService] %s already has a skill check running", player.Name))
		return false
	end

	if SkillCheckConfig.Phases[context.phaseName] == nil then
		warn(string.format("[SkillCheckPhaseService] unknown phase %q", tostring(context.phaseName)))
		return false
	end

	local challenge = SkillCheckChallenge.build(context.phaseName, difficulty, {
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
	task.delay(challenge.timeoutSeconds + TIMEOUT_GRACE_SECONDS, function()
		if active[player] == entry and not entry.reported then
			resolvePhase(player, entry, nil)
		end
	end)

	return true
end

--[[
	Accepts the player's reported press for a running skill check.

	A nil payload is legitimate: it means the needle ran out without a press.
]]
function SkillCheckPhaseService.submitInput(player: Player, attemptId: number, payload: unknown)
	local entry = active[player]
	if entry == nil then
		return
	end

	if entry.attemptId ~= attemptId then
		warn(string.format(
			"[SkillCheckPhaseService] %s submitted input for attempt %s during attempt %s; ignored",
			player.Name,
			tostring(attemptId),
			tostring(entry.attemptId)
		))
		return
	end

	if payload == nil then
		resolvePhase(player, entry, nil)
		return
	end

	if typeof(payload) ~= "number" then
		return
	end

	local pressTime = payload :: number
	if pressTime ~= pressTime or pressTime == math.huge or pressTime == -math.huge then
		return
	end

	if pressTime < 0 then
		return
	end

	--[[
		Consistency check. The press must have happened before the message arrived,
		so a claimed time later than the server's own elapsed measurement (plus a
		latency allowance) is impossible and is treated as a miss.
	]]
	local serverElapsed = os.clock() - entry.issuedAtClock
	if pressTime > serverElapsed + SkillCheckConfig.PressTimeToleranceSeconds then
		warn(string.format(
			"[SkillCheckPhaseService] %s reported a press at %.3fs but only %.3fs elapsed server-side; "
				.. "treating as a miss",
			player.Name,
			pressTime,
			serverElapsed
		))
		resolvePhase(player, entry, nil)
		return
	end

	resolvePhase(player, entry, pressTime)
end

--[[
	Drops a running phase without reporting, for a player leaving or an attempt
	being abandoned from above.
]]
function SkillCheckPhaseService.abandon(player: Player)
	local entry = active[player]
	if entry ~= nil then
		entry.reported = true
		active[player] = nil
	end
end

--[[
	True while this player has a skill check running.
]]
function SkillCheckPhaseService.isRunning(player: Player): boolean
	return active[player] ~= nil
end

return SkillCheckPhaseService
