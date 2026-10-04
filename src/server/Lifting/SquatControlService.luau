--!strict
--[[
	SquatControlService
	Server / Lifting

	The standalone Squat Control vertical slice. Server-authoritative end to end.

	FLOW

		client asks to attempt at a percentage
			-> server clamps the percentage
			-> server reads forecasted squat and Squat Control from the profile
			-> server resolves difficulty
			-> server builds the challenge INCLUDING the whole marker path, and
			   keeps its own copy
			-> client plays, drawing a bar it simulates locally for responsiveness
			-> client reports only the times at which the player clicked
			-> server REPLAYS the phase itself from those clicks
			-> server announces its own result

	WHY REPLAY RATHER THAN TRUST

	The client never sends a progress value, a pass, or a fail. It sends a list of
	click times, which is the smallest thing it is in a position to know. The server
	runs the same deterministic simulation over its own copy of the marker path and
	reaches its own conclusion. A client that reports a tidier set of clicks than it
	really produced is still only choosing inputs, and inputs still have to actually
	beat the phase.

	This is a stronger position than the timing check is in, where a single press
	time is inherently unverifiable. Here the whole interaction has to hold up.

	WHAT IS STILL CHECKED

		- the phase must be one this build enables
		- the percentage is clamped server-side and the weight derived from the
		  profile, so the client cannot pick a weight
		- click times must be finite, in range, and within the phase's own bounds
		- clicks closer together than the configured rate cap are discarded, so an
		  auto-clicker cannot flood the report
		- the simulated elapsed time cannot exceed the wall-clock time the server
		  measured, which stops a client claiming a long phase it never played

	REMAINING LIMIT

	Click times are still produced by the client, so a sufficiently sophisticated
	cheat could synthesise a plausible winning input sequence offline. Beating the
	simulation that way is far harder than reporting a single perfect press, but it
	is not impossible. Before Control feeds permanent progression, add rate and
	pattern analysis across attempts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LiftingFolder = Shared:WaitForChild("Lifting")
local DifficultyFolder = Shared:WaitForChild("Difficulty")
local ModifiersFolder = Shared:WaitForChild("Modifiers")

local ControlPhaseConfig = require(ConfigFolder:WaitForChild("ControlPhaseConfig"))
local SkillCheckConfig = require(ConfigFolder:WaitForChild("SkillCheckConfig"))
local LiftingRemotes = require(LiftingFolder:WaitForChild("LiftingRemotes"))
local ControlChallenge = require(LiftingFolder:WaitForChild("ControlChallenge"))
local ControlSimulation = require(LiftingFolder:WaitForChild("ControlSimulation"))
local DifficultyResolver = require(DifficultyFolder:WaitForChild("DifficultyResolver"))
local ModifierRegistry = require(ModifiersFolder:WaitForChild("ModifierRegistry"))

local PlayerDataService = require(script.Parent.Parent.PlayerData.PlayerDataService)

local SquatControlService = {}

--[[
	The phases this slice accepts. Bench Bar Control exists in the design and in
	ControlPhaseConfig's documentation but is deliberately not enabled.
]]
local ENABLED_PHASES: { [string]: boolean } = {
	SquatControl = true,
}

-- How long after a phase's own bound the server waits before failing it outright.
local TIMEOUT_GRACE_SECONDS = 2.0

type ActiveChallenge = {
	challenge: ControlChallenge.Challenge,
	issuedAtClock: number,
	token: number,
}

local active: { [Player]: ActiveChallenge } = {}
local nextToken = 0
local rng = Random.new()
local remotes: LiftingRemotes.RemoteSet? = nil
local started = false

local function log(message: string, ...: any)
	print("[SquatControlService] " .. string.format(message, ...))
end

local function clearActive(player: Player)
	active[player] = nil
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
	Replays the phase, announces the server's own result, and clears the slot.
]]
local function resolveAttempt(player: Player, entry: ActiveChallenge, reportedClicks: unknown)
	local set = remotes
	if set == nil then
		return
	end

	-- Ignore a late reply that arrives after a newer attempt has begun.
	local current = active[player]
	if current == nil or current.token ~= entry.token then
		return
	end

	clearActive(player)

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

	log(
		"%s attempted %.1f kg (%.1f%%, difficulty %.1f %s) -> %s  [progress %.1f, %.2fs, on target %.2fs of %.2fs, %d clicks]",
		player.Name,
		entry.challenge.attemptWeightKg,
		entry.challenge.intensityPercent,
		entry.challenge.baseDifficulty,
		entry.challenge.classification,
		verdict,
		result.finalProgress,
		result.elapsedSeconds,
		result.timeInsideSeconds,
		result.elapsedSeconds,
		result.clicksApplied
	)

	set.announceControlResult:FireClient(player, {
		verdict = verdict,
		outcome = outcome,
		passed = outcome == "Passed",
		finalProgress = result.finalProgress,
		elapsedSeconds = result.elapsedSeconds,
		timeInsideSeconds = result.timeInsideSeconds,
		clicksApplied = result.clicksApplied,
		acceptedClicks = #clickTimes,
	})
end

local function onRequestControlAttempt(player: Player, requestedPhase: unknown, requestedPercent: unknown)
	local set = remotes
	if set == nil then
		return
	end

	if not ControlChallenge.isKnownPhase(requestedPhase) then
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

	--[[
		The attempt percentage bounds are shared with the timing check, because they
		describe the same decision: how much of your forecasted max you are willing
		to put on the bar.
	]]
	percent = math.clamp(
		percent,
		SkillCheckConfig.MinimumAttemptPercent,
		SkillCheckConfig.MaximumAttemptPercent
	)

	-- One phase at a time. Spamming the key cannot farm fresh challenges.
	if active[player] ~= nil then
		return
	end

	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end

	local lift = ControlChallenge.liftFor(phaseName)
	local techniqueStatName = ControlChallenge.techniqueStatFor(phaseName)
	local forecastedMax = data.forecasted[lift]
	local techniqueStat = data.technique[techniqueStatName]

	if typeof(forecastedMax) ~= "number" or forecastedMax <= 0 then
		warn(string.format("[SquatControlService] %s has no usable forecasted %s", player.Name, lift))
		return
	end

	if typeof(techniqueStat) ~= "number" then
		warn(string.format(
			"[SquatControlService] %s has no technique stat %q",
			player.Name,
			techniqueStatName
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

	local challenge = ControlChallenge.build(phaseName, difficulty, {
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

	set.presentControlChallenge:FireClient(player, challenge)

	--[[
		Server-side backstop. A client that simply never reports would otherwise
		hold its slot forever and block further attempts.
	]]
	task.delay(challenge.maxPhaseSeconds + TIMEOUT_GRACE_SECONDS, function()
		local stillActive = active[player]
		if stillActive ~= nil and stillActive.token == entry.token then
			resolveAttempt(player, entry, nil)
		end
	end)
end

local function onReportControlInput(player: Player, reportedClicks: unknown)
	local entry = active[player]
	if entry == nil then
		return
	end
	resolveAttempt(player, entry, reportedClicks)
end

function SquatControlService.start()
	assert(not started, "[SquatControlService] start() must only be called once")
	started = true

	local set = LiftingRemotes.createOnServer(ReplicatedStorage)
	remotes = set

	set.requestControlAttempt.OnServerEvent:Connect(onRequestControlAttempt)
	set.reportControlInput.OnServerEvent:Connect(onReportControlInput)

	Players.PlayerRemoving:Connect(clearActive)

	for phaseName in pairs(ENABLED_PHASES) do
		log(
			"enabled phase %s (lift %s, driven by %s)",
			phaseName,
			ControlChallenge.liftFor(phaseName),
			ControlChallenge.techniqueStatFor(phaseName)
		)
	end
end

return SquatControlService
