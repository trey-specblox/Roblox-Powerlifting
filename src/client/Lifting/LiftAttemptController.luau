--!strict
--[[
	LiftAttemptController
	Client / Lifting

	The single client owner of a lift attempt: it shows whichever phase the server
	presents, routes input to that phase, and displays the verdicts the server
	sends back.

	It replaced two separate phase controllers. Having one owner matters for more
	than tidiness: the old pair each listened for input independently, which made
	behaviour depend on connection order, and each could request its own phase,
	which is how the skip-a-phase bypass existed.

	WHAT IT DECIDES: nothing. It renders what it is told and reports raw inputs. The
	phase verdict and the lift verdict both arrive from the server.

	TEMPORARY TESTING lives in client/Dev. This file exposes requestAttempt, and the
	real rack interaction will eventually call it the same way the debug trigger
	does now.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiftingFolder = Shared:WaitForChild("Lifting")
local LiftAttempt = require(LiftingFolder:WaitForChild("LiftAttempt"))
local LiftingRemotes = require(LiftingFolder:WaitForChild("LiftingRemotes"))

local ControlInput = require(script.Parent.ControlInput)
local ControlUI = require(script.Parent.ControlUI)
local PowerUI = require(script.Parent.PowerUI)
local SkillCheckUI = require(script.Parent.SkillCheckUI)

local LiftAttemptController = {}

--[[
	The timing check's press key.

	Space is bound through ContextActionService only while a skill check is live, so
	it does not fight jumping the rest of the time. The control phase uses the mouse
	through ControlInput, so the two phases never contend for an input.
]]
local PRESS_KEY = Enum.KeyCode.Space
local PRESS_ACTION = "RpfLiftPhasePress"

local SKILL_CHECK_PROMPT = "PRESS SPACE IN THE ZONE"
-- The power phase wants volume, not timing, so its prompt says so plainly.
local POWER_PROMPT = "MASH TO BUILD POWER - HOLD WHEN TOLD TO HOLD"

local started = false
local remotes: LiftingRemotes.RemoteSet? = nil

-- The attempt the server last told us about.
local activeAttemptId: number? = nil
local activePhaseKind: string? = nil

--[[
	Which phase UI is currently on screen, which is NOT the same as which phase is
	accepting input: a finished phase keeps its verdict visible for a moment.

	This controller owns phase-UI visibility outright. The UIs used to hide
	themselves on their own timers, and ControlUI's 2.5 second timer outlasted the
	orchestrator's 0.75 second inter-phase transition, so the depth check appeared
	on top of a control phase that had not cleared yet. Only the thing sequencing
	the phases can know when a UI is in the way.
]]
local shownPhaseKind: string? = nil

local bannerLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil

-- Set by the dev trigger (or later, the rack) so the HUD can show context.
local lastRequestedPercent = 1.0

local function buildBanner(parent: Instance): (TextLabel, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "LiftAttemptBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 24)
	banner.Size = UDim2.fromOffset(620, 44)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 32
	banner.TextColor3 = Color3.fromRGB(236, 240, 246)
	banner.Text = ""
	banner.Parent = gui

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 68)
	status.Size = UDim2.fromOffset(620, 22)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextSize = 15
	status.TextColor3 = Color3.fromRGB(168, 176, 190)
	status.Text = ""
	status.Parent = gui

	return banner, status
end

local function setBanner(text: string, color: Color3?)
	local label = bannerLabel
	if label ~= nil then
		label.Text = text
		if color ~= nil then
			label.TextColor3 = color
		end
	end
end

local function setStatus(text: string)
	local label = statusLabel
	if label ~= nil then
		label.Text = text
	end
end

--[[
	Stops the character jumping and moving while a phase is on screen.

	A phase needs clicking or precise timing, and a stray jump or walk gets in the
	way of both.
]]
local function setJumpEnabled(enabled: boolean)
	local character = Players.LocalPlayer.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end

local function bindPressKey()
	ContextActionService:BindActionAtPriority(
		PRESS_ACTION,
		function(_actionName, state)
			if state == Enum.UserInputState.Begin then
				SkillCheckUI.pressNow()
			end
			-- Sink, so Space does not also reach the default jump binding.
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		PRESS_KEY
	)
	setJumpEnabled(false)
end

local function unbindPressKey()
	ContextActionService:UnbindAction(PRESS_ACTION)
	setJumpEnabled(true)
end

--[[
	Releases every input binding. Called whenever a phase or attempt ends, so the
	player can never be left unable to move.
]]
local function releaseInput()
	unbindPressKey()
	ControlInput.unbind()
	activePhaseKind = nil
end

--[[
	Clears whichever phase UI is on screen.

	Idempotent, so it is safe to call defensively before showing a new phase.
]]
local function hidePhaseUI()
	if shownPhaseKind == LiftAttempt.PhaseKind.Control then
		ControlUI.hide()
	elseif shownPhaseKind == LiftAttempt.PhaseKind.Power then
		PowerUI.hide()
	elseif shownPhaseKind == LiftAttempt.PhaseKind.SkillCheck then
		SkillCheckUI.hide()
	end
	shownPhaseKind = nil
end

--[[
	Asks the server for a lift attempt.

	This is the only way an attempt begins. The debug trigger calls it now; a rack
	will call it later.
]]
function LiftAttemptController.requestAttempt(liftName: string, attemptPercent: number)
	local set = remotes
	if set == nil then
		return
	end

	-- The server rejects a second attempt anyway; this avoids the pointless message.
	if activeAttemptId ~= nil then
		return
	end

	lastRequestedPercent = attemptPercent
	set.requestLiftAttempt:FireServer(liftName, attemptPercent)
end

--[[
	True while an attempt is in progress, so the dev trigger can grey itself out.
]]
function LiftAttemptController.isAttemptActive(): boolean
	return activeAttemptId ~= nil
end

local function onPresentPhase(payload: any)
	local set = remotes
	if set == nil then
		return
	end

	--[[
		Nothing from a previous phase may survive into this one. By the time the
		server presents a phase, the one before it has already been resolved and
		cleared, so this is a guarantee rather than a cleanup.
	]]
	hidePhaseUI()

	activeAttemptId = payload.attemptId
	activePhaseKind = payload.kind
	shownPhaseKind = payload.kind

	local challenge = payload.challenge

	setBanner(
		string.format("%s  %d / %d", challenge.displayName or payload.phaseName, payload.phaseIndex, payload.phaseCount),
		Color3.fromRGB(236, 240, 246)
	)
	setStatus(string.format(
		"%.1f kg  -  %.0f%% of forecasted max  -  difficulty %.0f",
		challenge.attemptWeightKg,
		challenge.intensityPercent,
		challenge.baseDifficulty
	))

	if payload.kind == LiftAttempt.PhaseKind.Control then
		ControlInput.bind(ControlUI.registerImpulse)
		setJumpEnabled(false)

		ControlUI.run(challenge, function(clickTimes)
			ControlInput.unbind()
			setJumpEnabled(true)
			set.reportPhaseInput:FireServer(payload.attemptId, LiftAttempt.PhaseKind.Control, clickTimes)
		end)
	elseif payload.kind == LiftAttempt.PhaseKind.Power then
		--[[
			The power phase reuses ControlInput, which is the project's one abstract
			impulse action. Both phases want "the player produced an input right now"
			and neither cares which device sent it, so mobile, tablet and console
			support arrives for the bench at the same time it arrives for the squat.
		]]
		--[[
			The power phase binds BOTH directions, because its hold windows need to
			know when the input went back up. The squat's control phase binds only
			presses, so its behaviour is untouched by this.
		]]
		ControlInput.bind(PowerUI.registerPress, PowerUI.registerRelease)
		setJumpEnabled(false)

		PowerUI.run(challenge, function(inputEvents)
			ControlInput.unbind()
			setJumpEnabled(true)
			set.reportPhaseInput:FireServer(payload.attemptId, LiftAttempt.PhaseKind.Power, inputEvents)
		end)
	else
		SkillCheckUI.setInstruction(SKILL_CHECK_PROMPT)
		bindPressKey()

		SkillCheckUI.run(challenge, function(pressTimeSeconds)
			unbindPressKey()
			set.reportPhaseInput:FireServer(payload.attemptId, LiftAttempt.PhaseKind.SkillCheck, pressTimeSeconds)
		end)
	end
end

local function onAnnouncePhaseResult(payload: any)
	-- Ignore anything belonging to an attempt we are not showing.
	if activeAttemptId ~= nil and payload.attemptId ~= activeAttemptId then
		return
	end

	releaseInput()

	if payload.passed and payload.hasNextPhase then
		--[[
			Another phase is coming, and the server is holding its transition beat
			right now. The finished phase's gameplay UI must be gone BEFORE that beat
			elapses, so it is cleared immediately rather than left to fade on a timer
			of its own. Its verdict moves to the banner, which is the one surface that
			persists across phases.
		]]
		hidePhaseUI()
		-- Named by the server from the next phase's config, so a bench says PRESS
		-- where a squat says DEPTH.
		setBanner(payload.nextPhaseDisplayName or "NEXT", Color3.fromRGB(255, 214, 92))
		setStatus(payload.verdict)
		return
	end

	--[[
		The attempt is ending. The phase's own verdict is more specific than the
		attempt banner's ("NO LIFT - LOST CONTROL" versus just "NO LIFT"), so it stays
		on screen and is cleared when the result hold expires.
	]]
	if payload.kind == LiftAttempt.PhaseKind.Control then
		ControlUI.showVerdict(payload.verdict, payload.passed, "server: " .. tostring(payload.detail))
	elseif payload.kind == LiftAttempt.PhaseKind.Power then
		PowerUI.showVerdict(payload.verdict, payload.passed, "server: " .. tostring(payload.detail))
	else
		SkillCheckUI.showVerdict(payload.verdict, payload.passed)
	end
end

local function onAnnounceAttemptResult(payload: any)
	releaseInput()
	activeAttemptId = nil

	local passed = payload.verdict == LiftAttempt.Verdict.GoodLift
	local color = if passed then Color3.fromRGB(96, 214, 128) else Color3.fromRGB(240, 92, 92)

	setBanner(payload.verdictText, color)
	setStatus(string.format(
		"%s  %.1f kg  (%.0f%%)%s",
		payload.liftName,
		payload.attemptWeightKg,
		payload.attemptPercent * 100,
		if payload.failedPhase then "  -  failed " .. payload.failedPhase else ""
	))

	--[[
		The hold duration comes from the server, which is also what gates when a new
		attempt may start, so the UI clears at the same moment the player is freed
		rather than on a number this file picked.
	]]
	local holdSeconds = payload.resultHoldSeconds or 2.5
	task.delay(holdSeconds, function()
		-- Only clear if nothing new has started since.
		if activeAttemptId == nil then
			hidePhaseUI()
			setBanner("")
			setStatus("")
		end
	end)
end

function LiftAttemptController.start()
	assert(not started, "[LiftAttemptController] start() must only be called once")
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	ControlUI.mount(playerGui, ControlInput.promptText())
	PowerUI.mount(playerGui, POWER_PROMPT)
	SkillCheckUI.mount(playerGui, SKILL_CHECK_PROMPT)
	bannerLabel, statusLabel = buildBanner(playerGui)

	-- SetStateEnabled applies to a Humanoid, and a respawn creates a new one.
	player.CharacterAdded:Connect(function()
		if activePhaseKind == nil then
			setJumpEnabled(true)
		end
	end)

	local set = LiftingRemotes.waitForClient(ReplicatedStorage)
	remotes = set

	set.presentPhase.OnClientEvent:Connect(onPresentPhase)
	set.announcePhaseResult.OnClientEvent:Connect(onAnnouncePhaseResult)
	set.announceAttemptResult.OnClientEvent:Connect(onAnnounceAttemptResult)

	print("[LiftAttemptController] ready")
end

return LiftAttemptController
