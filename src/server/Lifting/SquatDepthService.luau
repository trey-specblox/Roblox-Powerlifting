--!strict
--[[
	SquatDepthService
	Server / Lifting

	The Squat Depth vertical slice. One lift, one phase, server-authoritative end
	to end.

	FLOW

		client asks to attempt at a percentage
			-> server clamps the percentage
			-> server reads forecasted squat and Depth Awareness from the profile
			-> server gathers modifiers (none registered yet)
			-> server resolves difficulty
			-> server builds the challenge and KEEPS IT
			-> client renders and the player presses
			-> client reports the press time
			-> server grades against its own stored challenge
			-> server announces the verdict

	WHAT THE CLIENT CANNOT DO

	It cannot choose a weight (only a percentage, which the server clamps and
	converts using the profile it holds). It cannot see or set a difficulty. It
	cannot report a grade or a result. It cannot take two presses on one check.

	HONEST LIMIT OF THE ANTI-CHEAT

	The press time comes from the client, because only the client knows when the
	key went down. The server checks that the claimed time is consistent with its
	own measurement of how long the round trip took, which defeats the obvious
	exploit of always claiming a perfect press on a check that has long since
	expired. It does NOT defeat a cheat that reports a plausible-but-false time
	within the latency tolerance. That is an inherent limit of client-timed input
	and is not solvable by tightening this check alone.

	Nothing permanent is written by this slice, so a successful cheat currently
	buys only a console line. Before results start affecting progression, this
	needs hardening: a tighter tolerance informed by measured ping, rejecting
	players whose reported times cluster implausibly well, and rate limiting.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LiftingFolder = Shared:WaitForChild("Lifting")
local DifficultyFolder = Shared:WaitForChild("Difficulty")
local ModifiersFolder = Shared:WaitForChild("Modifiers")

local SkillCheckConfig = require(ConfigFolder:WaitForChild("SkillCheckConfig"))
local LiftingRemotes = require(LiftingFolder:WaitForChild("LiftingRemotes"))
local SkillCheckChallenge = require(LiftingFolder:WaitForChild("SkillCheckChallenge"))
local SkillCheckGrade = require(LiftingFolder:WaitForChild("SkillCheckGrade"))
local DifficultyResolver = require(DifficultyFolder:WaitForChild("DifficultyResolver"))
local ModifierRegistry = require(ModifiersFolder:WaitForChild("ModifierRegistry"))

local PlayerDataService = require(script.Parent.Parent.PlayerData.PlayerDataService)

local SquatDepthService = {}

--[[
	The phases this slice accepts. The request carries a phase name so the protocol
	does not have to change when a second phase is built, but anything not listed
	here is refused.

	Nothing lift-specific is hardcoded in this file. Which forecasted max a phase
	measures against, which technique stat eases it, which balancing profile it
	uses and how its verdicts read all come from SkillCheckConfig.Phases.

	Enabling Bench Press or Deadlift Lockout is therefore a config entry plus a
	line here, not a second copy of this service.
]]
local ENABLED_PHASES: { [string]: boolean } = {
	SquatDepth = true,
}

-- How long after a challenge expires the server waits before auto-failing it.
local TIMEOUT_GRACE_SECONDS = 0.75

type ActiveChallenge = {
	challenge: SkillCheckChallenge.Challenge,
	-- Server clock when the challenge was sent, for the consistency check.
	issuedAtClock: number,
	-- Incremented per attempt, so a late reply to an old challenge is ignored.
	token: number,
}

local active: { [Player]: ActiveChallenge } = {}
local nextToken = 0
local rng = Random.new()
local remotes: LiftingRemotes.RemoteSet? = nil
local started = false

local function log(message: string, ...: any)
	print("[SquatDepthService] " .. string.format(message, ...))
end

local function clearActive(player: Player)
	active[player] = nil
end

--[[
	Sends a verdict and clears the player's challenge. One press per check, so the
	challenge is gone before the result goes out.
]]
local function resolveAttempt(player: Player, entry: ActiveChallenge, pressTimeSeconds: number?)
	local set = remotes
	if set == nil then
		return
	end

	-- Guard against a late reply arriving after a newer attempt started.
	local current = active[player]
	if current == nil or current.token ~= entry.token then
		return
	end

	clearActive(player)

	local result = SkillCheckGrade.evaluate(entry.challenge, pressTimeSeconds)
	-- Wording comes from the challenge's own phase, never a shared default.
	local verdict = SkillCheckGrade.verdictText(result, entry.challenge.phase)

	log(
		"%s attempted %.1f kg (%.1f%%, difficulty %.1f %s) -> %s%s",
		player.Name,
		entry.challenge.attemptWeightKg,
		entry.challenge.intensityPercent,
		entry.challenge.baseDifficulty,
		entry.challenge.classification,
		verdict,
		if result.failureReason then " (" .. result.failureReason .. ")" else ""
	)

	set.announceResult:FireClient(player, {
		verdict = verdict,
		passed = result.passed,
		failureReason = result.failureReason,
		needleAngleDeg = result.needleAngleDeg,
	})
end

local function onRequestAttempt(player: Player, requestedPhase: unknown, requestedPercent: unknown)
	local set = remotes
	if set == nil then
		return
	end

	--[[
		Never trust the shape of anything arriving from a client, including the
		phase name. It is checked against the configured phases and then against
		what this build actually enables.

		NOTE FOR LATER: once lifts are started from a real interaction point, the
		server must also confirm the player is actually standing at a station for
		this phase. Accepting the client's word for WHICH lift is only acceptable
		while there is no world geometry to check against.
	]]
	if not SkillCheckChallenge.isKnownPhase(requestedPhase) then
		return
	end

	local phaseName = requestedPhase :: string
	if not ENABLED_PHASES[phaseName] then
		return
	end

	if typeof(requestedPercent) ~= "number" then
		return
	end

	local percent = requestedPercent :: number
	if percent ~= percent or percent == math.huge or percent == -math.huge then
		return
	end

	percent = math.clamp(
		percent,
		SkillCheckConfig.MinimumAttemptPercent,
		SkillCheckConfig.MaximumAttemptPercent
	)

	-- One check at a time. A second request while one is live is ignored rather
	-- than cancelling it, so spamming the key cannot farm fresh challenges.
	if active[player] ~= nil then
		return
	end

	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end

	-- Both read from the phase's config entry, so nothing lift-specific is
	-- hardcoded in this service.
	local lift = SkillCheckChallenge.liftFor(phaseName)
	local forecastedMax = data.forecasted[lift]
	local techniqueStat = data.technique[SkillCheckChallenge.techniqueStatFor(phaseName)]

	if typeof(forecastedMax) ~= "number" or forecastedMax <= 0 then
		warn(string.format("[SquatDepthService] %s has no usable forecasted %s", player.Name, lift))
		return
	end

	if typeof(techniqueStat) ~= "number" then
		warn(string.format(
			"[SquatDepthService] %s has no technique stat %q",
			player.Name,
			SkillCheckChallenge.techniqueStatFor(phaseName)
		))
		return
	end

	local attemptWeight = forecastedMax * percent

	local modifiers = ModifierRegistry.gather({
		liftName = lift,
		phase = phaseName,
		profile = data,
		isTraining = false,
	})

	local difficulty = DifficultyResolver.resolve({
		attemptWeight = attemptWeight,
		forecastedMax = forecastedMax,
		techniqueStat = techniqueStat,
		modifiers = modifiers,
	})

	local challenge = SkillCheckChallenge.build(phaseName, difficulty, {
		attemptWeightKg = attemptWeight,
		forecastedMaxKg = forecastedMax,
	}, rng)

	nextToken += 1
	local entry: ActiveChallenge = {
		challenge = challenge,
		issuedAtClock = os.clock(),
		token = nextToken,
	}
	active[player] = entry

	set.presentChallenge:FireClient(player, challenge)

	--[[
		Server-side timeout. Without this, a client that simply never replies
		would hold its challenge slot forever and block further attempts.
	]]
	task.delay(challenge.timeoutSeconds + TIMEOUT_GRACE_SECONDS, function()
		local stillActive = active[player]
		if stillActive ~= nil and stillActive.token == entry.token then
			resolveAttempt(player, entry, nil)
		end
	end)
end

local function onReportPress(player: Player, reportedTime: unknown)
	local entry = active[player]
	if entry == nil then
		return
	end

	-- A miss reported by the client is legitimate: it means the needle ran out.
	if reportedTime == nil then
		resolveAttempt(player, entry, nil)
		return
	end

	if typeof(reportedTime) ~= "number" then
		return
	end

	local pressTime = reportedTime :: number
	if pressTime ~= pressTime or pressTime == math.huge or pressTime == -math.huge then
		return
	end

	if pressTime < 0 then
		return
	end

	--[[
		Consistency check. The press must have happened before the message
		arrived, so a claimed time later than the server's own elapsed measurement
		(plus latency allowance) is impossible and is treated as a miss.
	]]
	local serverElapsed = os.clock() - entry.issuedAtClock
	if pressTime > serverElapsed + SkillCheckConfig.PressTimeToleranceSeconds then
		warn(string.format(
			"[SquatDepthService] %s reported a press at %.3fs but only %.3fs elapsed server-side; "
				.. "treating as a miss",
			player.Name,
			pressTime,
			serverElapsed
		))
		resolveAttempt(player, entry, nil)
		return
	end

	resolveAttempt(player, entry, pressTime)
end

function SquatDepthService.start()
	assert(not started, "[SquatDepthService] start() must only be called once")
	started = true

	local set = LiftingRemotes.createOnServer(ReplicatedStorage)
	remotes = set

	set.requestAttempt.OnServerEvent:Connect(onRequestAttempt)
	set.reportPress.OnServerEvent:Connect(onReportPress)

	Players.PlayerRemoving:Connect(clearActive)

	for phaseName in pairs(ENABLED_PHASES) do
		log(
			"enabled phase %s (lift %s, driven by %s)",
			phaseName,
			SkillCheckChallenge.liftFor(phaseName),
			SkillCheckChallenge.techniqueStatFor(phaseName)
		)
	end
end

return SquatDepthService
