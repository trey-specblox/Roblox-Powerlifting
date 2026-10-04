--!strict
--[[
	LiftAttemptService
	Server / Lifting

	Owns a complete lift attempt: its identity, its locked numbers, the order its
	phases run in, and the final verdict.

	The phase services below it each run one phase and report back. Neither knows
	about the other, and neither knows an attempt exists. This file is the only
	place that decides what happens next.

		RequestLiftAttempt
			-> validate, derive weight, LOCK everything
			-> phase 1  ... FAIL -> NO LIFT
			           ... PASS -> transition -> phase 2 ... FAIL -> NO LIFT
			                                              ... PASS -> GOOD LIFT

	WHAT MAKES A GOOD LIFT HARD TO FORGE

	A good lift is awarded in exactly one place, and only after the loop has walked
	past the end of the phase list with every phase recorded as passed. It asserts
	that before announcing, so a missing phase result cannot produce one.

	The client cannot name a phase, because no message accepts a phase name. It
	cannot skip one, because the sequence is read from config here. It cannot replay
	one, because each phase reports once and every inbound message carries an
	attemptId that must match the live attempt.

	WHAT IS LOCKED, AND WHY

	Forecasted max, percentage, weight, the technique snapshot and the modifier
	snapshot are all captured once, at creation, and never re-read. Today nothing
	can change mid-attempt. Once training, equipment and coaches exist, re-reading
	between phases would let a player improve their stats or swap gear halfway
	through a lift. Locking now means that class of exploit never opens.

	NOTHING IS PERSISTED

	A verdict is announced and logged. No PR, no progression, no technique gain, no
	currency, no record. That is deliberate for this development slice, and it is
	why several known validation gaps are safe to defer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LiftingFolder = Shared:WaitForChild("Lifting")
local DifficultyFolder = Shared:WaitForChild("Difficulty")
local ModifiersFolder = Shared:WaitForChild("Modifiers")

local LiftAttemptConfig = require(ConfigFolder:WaitForChild("LiftAttemptConfig"))
local LiftAttempt = require(LiftingFolder:WaitForChild("LiftAttempt"))
local LiftingRemotes = require(LiftingFolder:WaitForChild("LiftingRemotes"))
local ControlChallenge = require(LiftingFolder:WaitForChild("ControlChallenge"))
local SkillCheckChallenge = require(LiftingFolder:WaitForChild("SkillCheckChallenge"))
local DifficultyResolver = require(DifficultyFolder:WaitForChild("DifficultyResolver"))
local ModifierRegistry = require(ModifiersFolder:WaitForChild("ModifierRegistry"))

local PlayerDataService = require(script.Parent.Parent.PlayerData.PlayerDataService)
local SquatControlService = require(script.Parent.SquatControlService)
local SquatDepthService = require(script.Parent.SquatDepthService)

local LiftAttemptService = {}

--[[
	Which lifts this build will start. The sequence itself lives in config; this is
	the switch for what is actually playable.
]]
local ENABLED_LIFTS: { [string]: boolean } = {
	Squat = true,
}

type PhaseSpec = {
	kind: string,
	phaseName: string,
}

type Attempt = {
	attemptId: number,
	player: Player,
	liftName: string,
	lift: string,
	displayName: string,

	-- LOCKED at creation. Never re-read from the profile.
	forecastedMaxKg: number,
	attemptPercent: number,
	attemptWeightKg: number,
	techniqueSnapshot: { [string]: number },
	modifierSnapshot: any,

	phases: { PhaseSpec },
	phaseIndex: number,
	phaseResults: { [string]: LiftAttempt.PhaseResult },
	passedCount: number,

	finalVerdict: LiftAttempt.AttemptVerdict?,
	failedPhase: string?,

	startedAtClock: number,
	-- Set while a result is being held on screen, so input is ignored.
	finished: boolean,
}

local attempts: { [Player]: Attempt } = {}
local nextAttemptId = 0
local remotes: LiftingRemotes.RemoteSet? = nil
local started = false

local function log(message: string, ...: any)
	print("[LiftAttemptService] " .. string.format(message, ...))
end

--[[
	Tears down whatever the player had running, without announcing anything.
]]
local function clearAttempt(player: Player)
	SquatControlService.abandon(player)
	SquatDepthService.abandon(player)
	attempts[player] = nil
end

--[[
	Resolves the difficulty for one phase from the attempt's LOCKED values.

	Base difficulty is identical across every phase of an attempt, because it comes
	from the weight on the bar. Only the effective technique differs, because each
	phase reads a different technique stat.
]]
local function resolvePhaseDifficulty(attempt: Attempt, spec: PhaseSpec): any
	local techniqueStatName: string
	if spec.kind == LiftAttempt.PhaseKind.Control then
		techniqueStatName = ControlChallenge.techniqueStatFor(spec.phaseName)
	else
		techniqueStatName = SkillCheckChallenge.techniqueStatFor(spec.phaseName)
	end

	local techniqueStat = attempt.techniqueSnapshot[techniqueStatName] or 0

	return DifficultyResolver.resolve({
		attemptWeight = attempt.attemptWeightKg,
		forecastedMax = attempt.forecastedMaxKg,
		techniqueStat = techniqueStat,
		modifiers = attempt.modifierSnapshot,
	})
end

--[[
	Ends the attempt, announces the verdict, and holds it briefly before the player
	may start another.
]]
local function finishAttempt(attempt: Attempt, verdict: LiftAttempt.AttemptVerdict)
	local set = remotes
	if set == nil then
		return
	end

	local player = attempt.player
	attempt.finalVerdict = verdict
	attempt.finished = true

	local verdictText = if verdict == LiftAttempt.Verdict.GoodLift
		then LiftAttemptConfig.Verdicts.goodLift
		else LiftAttemptConfig.Verdicts.noLift

	log(
		"%s %s %.1f kg (%.1f%%) -> %s%s",
		player.Name,
		attempt.displayName,
		attempt.attemptWeightKg,
		attempt.attemptPercent * 100,
		verdictText,
		if attempt.failedPhase then " (failed " .. attempt.failedPhase .. ")" else ""
	)

	local payload: LiftAttempt.AttemptResultPayload = {
		attemptId = attempt.attemptId,
		liftName = attempt.liftName,
		verdict = verdict,
		verdictText = verdictText,
		attemptWeightKg = attempt.attemptWeightKg,
		forecastedMaxKg = attempt.forecastedMaxKg,
		attemptPercent = attempt.attemptPercent,
		failedPhase = attempt.failedPhase,
		resultHoldSeconds = LiftAttemptConfig.ResultHoldSeconds,
	}

	set.announceAttemptResult:FireClient(player, payload)

	--[[
		NOTHING IS WRITTEN HERE ON PURPOSE. When a good lift eventually sets a PR or
		grants progression, this is the single place it happens, and the deferred
		validation work in the phase services has to be done first.
	]]

	local attemptId = attempt.attemptId
	task.delay(LiftAttemptConfig.ResultHoldSeconds, function()
		local current = attempts[player]
		if current ~= nil and current.attemptId == attemptId then
			attempts[player] = nil
		end
	end)
end

local beginPhaseAtIndex: (attempt: Attempt) -> ()

--[[
	Records a phase's result and decides what happens next.

	Every guard here exists for a reason: a stale attempt must not advance a newer
	one, a finished attempt must not accept more results, and a phase must not be
	recorded twice.
]]
local function onPhaseComplete(attempt: Attempt, spec: PhaseSpec, result: LiftAttempt.PhaseResult)
	local set = remotes
	if set == nil then
		return
	end

	local player = attempt.player

	-- The attempt this result belongs to must still be the live one.
	local current = attempts[player]
	if current == nil or current.attemptId ~= attempt.attemptId then
		return
	end

	if attempt.finished then
		return
	end

	-- A phase reports once; a second result for the same phase is a bug upstream.
	if attempt.phaseResults[spec.phaseName] ~= nil then
		warn(string.format(
			"[LiftAttemptService] %s reported %s twice; ignoring the repeat",
			player.Name,
			spec.phaseName
		))
		return
	end

	attempt.phaseResults[spec.phaseName] = result
	if result.passed then
		attempt.passedCount += 1
	end

	local hasNextPhase = result.passed and attempt.phaseIndex < #attempt.phases

	local phasePayload: LiftAttempt.PhaseResultPayload = {
		attemptId = attempt.attemptId,
		kind = result.kind,
		phaseName = result.phaseName,
		passed = result.passed,
		verdict = result.verdict,
		detail = result.detail,
		hasNextPhase = hasNextPhase,
	}
	set.announcePhaseResult:FireClient(player, phasePayload)

	-- A failed phase ends the lift immediately. The next phase never begins.
	if not result.passed then
		attempt.failedPhase = result.phaseName
		finishAttempt(attempt, LiftAttempt.Verdict.NoLift)
		return
	end

	attempt.phaseIndex += 1

	if attempt.phaseIndex > #attempt.phases then
		--[[
			Every phase passed. The count check is belt and braces: a good lift must
			be impossible unless there is a passing result recorded for each phase.
		]]
		if attempt.passedCount ~= #attempt.phases then
			warn(string.format(
				"[LiftAttemptService] %s reached the end of %s with %d of %d phases passed; "
					.. "refusing to award a good lift",
				player.Name,
				attempt.liftName,
				attempt.passedCount,
				#attempt.phases
			))
			finishAttempt(attempt, LiftAttempt.Verdict.NoLift)
			return
		end

		finishAttempt(attempt, LiftAttempt.Verdict.GoodLift)
		return
	end

	-- A beat between phases, so the squat does not snap from one minigame to the next.
	local attemptId = attempt.attemptId
	task.delay(LiftAttemptConfig.InterPhaseTransitionSeconds, function()
		local stillCurrent = attempts[player]
		if stillCurrent ~= nil and stillCurrent.attemptId == attemptId and not stillCurrent.finished then
			beginPhaseAtIndex(stillCurrent)
		end
	end)
end

--[[
	Starts the phase at the attempt's current index.
]]
function beginPhaseAtIndex(attempt: Attempt)
	local set = remotes
	if set == nil then
		return
	end

	local player = attempt.player
	local spec = attempt.phases[attempt.phaseIndex]
	if spec == nil then
		return
	end

	local difficulty = resolvePhaseDifficulty(attempt, spec)

	local context: LiftAttempt.PhaseContext = {
		attemptId = attempt.attemptId,
		phaseName = spec.phaseName,
		kind = spec.kind :: LiftAttempt.PhaseKind,
		attemptWeightKg = attempt.attemptWeightKg,
		forecastedMaxKg = attempt.forecastedMaxKg,
	}

	local phaseIndex = attempt.phaseIndex

	local callbacks = {
		present = function(challenge: any)
			local payload: LiftAttempt.PresentPhasePayload = {
				attemptId = attempt.attemptId,
				kind = spec.kind :: LiftAttempt.PhaseKind,
				phaseName = spec.phaseName,
				phaseIndex = phaseIndex,
				phaseCount = #attempt.phases,
				challenge = challenge,
			}
			set.presentPhase:FireClient(player, payload)
		end,
		complete = function(result: LiftAttempt.PhaseResult)
			onPhaseComplete(attempt, spec, result)
		end,
	}

	local ok: boolean
	if spec.kind == LiftAttempt.PhaseKind.Control then
		ok = SquatControlService.beginPhase(player, context, difficulty, callbacks)
	else
		ok = SquatDepthService.beginPhase(player, context, difficulty, callbacks)
	end

	if not ok then
		warn(string.format(
			"[LiftAttemptService] could not start %s for %s; abandoning the attempt",
			spec.phaseName,
			player.Name
		))
		attempt.failedPhase = spec.phaseName
		finishAttempt(attempt, LiftAttempt.Verdict.NoLift)
	end
end

local function onRequestLiftAttempt(player: Player, requestedLift: unknown, requestedPercent: unknown)
	local set = remotes
	if set == nil then
		return
	end

	-- Never trust the shape of anything arriving from a client.
	if typeof(requestedLift) ~= "string" then
		return
	end

	local liftName = requestedLift :: string
	local sequence = LiftAttemptConfig.Sequences[liftName]
	if sequence == nil or not ENABLED_LIFTS[liftName] then
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
		LiftAttemptConfig.MinimumAttemptPercent,
		LiftAttemptConfig.MaximumAttemptPercent
	)

	-- Exactly one attempt per player. A second request while one is live is ignored.
	if attempts[player] ~= nil then
		return
	end

	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end

	local forecastedMax = data.forecasted[sequence.lift]
	if typeof(forecastedMax) ~= "number" or forecastedMax <= 0 then
		warn(string.format("[LiftAttemptService] %s has no usable forecasted %s", player.Name, sequence.lift))
		return
	end

	--[[
		SNAPSHOT EVERYTHING THE ATTEMPT WILL USE.

		Technique stats are copied rather than referenced, so a later write to the
		profile cannot change a lift already in progress.
	]]
	local techniqueSnapshot: { [string]: number } = {}
	for statName, value in pairs(data.technique) do
		if typeof(value) == "number" then
			techniqueSnapshot[statName] = value
		end
	end

	local modifierSnapshot = ModifierRegistry.gather({
		liftName = sequence.lift,
		phase = nil,
		profile = data,
		isTraining = false,
	})

	nextAttemptId += 1

	local attempt: Attempt = {
		attemptId = nextAttemptId,
		player = player,
		liftName = liftName,
		lift = sequence.lift,
		displayName = sequence.displayName,

		forecastedMaxKg = forecastedMax,
		attemptPercent = percent,
		attemptWeightKg = forecastedMax * percent,
		techniqueSnapshot = techniqueSnapshot,
		modifierSnapshot = modifierSnapshot,

		phases = sequence.phases,
		phaseIndex = 1,
		phaseResults = {},
		passedCount = 0,

		finalVerdict = nil,
		failedPhase = nil,

		startedAtClock = os.clock(),
		finished = false,
	}

	attempts[player] = attempt

	log(
		"%s started %s at %.1f kg (%.1f%% of %.1f kg), %d phases",
		player.Name,
		attempt.displayName,
		attempt.attemptWeightKg,
		percent * 100,
		forecastedMax,
		#attempt.phases
	)

	--[[
		Safety net for the whole attempt. The phases have their own tighter
		timeouts, so this only fires if something has genuinely gone wrong, and it
		frees the player rather than leaving them locked out.
	]]
	local attemptId = attempt.attemptId
	task.delay(LiftAttemptConfig.MaxAttemptSeconds, function()
		local current = attempts[player]
		if current ~= nil and current.attemptId == attemptId and not current.finished then
			warn(string.format("[LiftAttemptService] %s's attempt exceeded its safety bound; abandoning", player.Name))
			clearAttempt(player)
		end
	end)

	beginPhaseAtIndex(attempt)
end

--[[
	Routes a player's phase input to whichever phase is actually running.

	THIS IS THE SINGLE CHECK POINT for input belonging to the right phase. The kind
	in the message must match the phase the server is running, so control clicks
	cannot be fed to a timing check or the reverse.
]]
local function onReportPhaseInput(player: Player, attemptId: unknown, kind: unknown, payload: unknown)
	local attempt = attempts[player]
	if attempt == nil or attempt.finished then
		return
	end

	if typeof(attemptId) ~= "number" or attemptId ~= attempt.attemptId then
		return
	end

	if typeof(kind) ~= "string" then
		return
	end

	local spec = attempt.phases[attempt.phaseIndex]
	if spec == nil then
		return
	end

	if kind ~= spec.kind then
		warn(string.format(
			"[LiftAttemptService] %s sent %s input during a %s phase; ignored",
			player.Name,
			tostring(kind),
			spec.kind
		))
		return
	end

	if spec.kind == LiftAttempt.PhaseKind.Control then
		SquatControlService.submitInput(player, attempt.attemptId, payload)
	else
		SquatDepthService.submitInput(player, attempt.attemptId, payload)
	end
end

function LiftAttemptService.start()
	assert(not started, "[LiftAttemptService] start() must only be called once")
	started = true

	local set = LiftingRemotes.createOnServer(ReplicatedStorage)
	remotes = set

	set.requestLiftAttempt.OnServerEvent:Connect(onRequestLiftAttempt)
	set.reportPhaseInput.OnServerEvent:Connect(onReportPhaseInput)

	Players.PlayerRemoving:Connect(clearAttempt)

	for liftName in pairs(ENABLED_LIFTS) do
		local sequence = LiftAttemptConfig.Sequences[liftName]
		local names: { string } = {}
		for _, phase in ipairs(sequence.phases) do
			table.insert(names, phase.phaseName)
		end
		log("enabled %s: %s", liftName, table.concat(names, " -> "))
	end
end

return LiftAttemptService
