--!strict
--[[
	SquatControlController
	Client / Lifting

	Debug trigger, percentage selection and HUD for the standalone Squat Control
	slice.

	CONTROLS

		C        start a Squat Control attempt
		CLICK    lift the bar, while a phase is running
		V / B    lower or raise the attempt percentage by 2.5%

	Keys were chosen to avoid the timing check entirely: that slice owns E, Space
	and Z/X, and this one must not fight it. Space is deliberately NOT used here.

	This controller is a TEMPORARY development trigger. A real squat will begin at
	a rack and run Control into Depth as one attempt; nothing here should survive
	into that version except the wiring between ControlInput and ControlUI.

	WHAT THIS SENDS

	A phase name, a percentage, and the times at which the player clicked. Never a
	weight, a difficulty, a progress value or a result. The server derives the
	weight, replays the clicks against its own copy of the marker path, and decides
	the outcome itself.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiftingFolder = Shared:WaitForChild("Lifting")
local LiftingRemotes = require(LiftingFolder:WaitForChild("LiftingRemotes"))

local ControlInput = require(script.Parent.ControlInput)
local ControlUI = require(script.Parent.ControlUI)

local SquatControlController = {}

--[[
	Which phase this controller drives. The mechanic itself is phase-agnostic;
	only this debug trigger is Squat-specific.
]]
local PHASE = "SquatControl"

local START_KEY = Enum.KeyCode.C
local DOWN_KEY = Enum.KeyCode.V
local UP_KEY = Enum.KeyCode.B

local PERCENT_STEP = 0.025
local PERCENT_MIN = 0.40
local PERCENT_MAX = 1.25

local selectedPercent = 1.00
local awaitingChallenge = false
local started = false

local hudLabel: TextLabel? = nil
local remotes: LiftingRemotes.RemoteSet? = nil

local function buildHud(parent: Instance): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "SquatControlHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Readout"
	label.AnchorPoint = Vector2.new(1, 1)
	label.Position = UDim2.new(1, -16, 1, -16)
	label.Size = UDim2.fromOffset(470, 94)
	label.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(226, 232, 240)
	label.Font = Enum.Font.Code
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 8)
	padding.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	return label
end

local function refreshHud()
	local label = hudLabel
	if label == nil then
		return
	end

	label.Text = string.format(
		"SQUAT CONTROL SLICE (standalone)\nattempt: %.1f%% of forecasted max\n[C] start    [CLICK] lift the bar\n[V] -2.5%%    [B] +2.5%%",
		selectedPercent * 100
	)
end

local function adjustPercent(delta: number)
	selectedPercent = math.clamp(selectedPercent + delta, PERCENT_MIN, PERCENT_MAX)
	refreshHud()
end

--[[
	Stops the character jumping and moving while a phase is on screen.

	The phase demands rapid clicking, and a click that also swings the camera or a
	stray WASD press that walks the player away both get in the way of judging the
	mechanic.
]]
local function setCharacterLocked(locked: boolean)
	local character = Players.LocalPlayer.Character
	if character == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not locked)
	end
end

local function requestAttempt()
	local set = remotes
	if set == nil then
		return
	end

	if awaitingChallenge or ControlUI.isRunning() then
		return
	end

	awaitingChallenge = true
	set.requestControlAttempt:FireServer(PHASE, selectedPercent)
end

local function onPresentControlChallenge(challenge: any)
	local set = remotes
	if set == nil then
		return
	end

	awaitingChallenge = false

	setCharacterLocked(true)
	ControlInput.bind(ControlUI.registerImpulse)

	ControlUI.run(challenge, function(clickTimes)
		-- Released the moment the local phase concludes; the server still has to
		-- replay these before anything is decided.
		ControlInput.unbind()
		setCharacterLocked(false)
		set.reportControlInput:FireServer(clickTimes)
	end)
end

local function onAnnounceControlResult(result: any)
	-- Safety net: never leave the player with input bound or movement locked.
	ControlInput.unbind()
	setCharacterLocked(false)

	local detail = string.format(
		"server: progress %5.1f / 100   on target %.2fs of %.2fs   clicks accepted %d",
		result.finalProgress or 0,
		result.timeInsideSeconds or 0,
		result.elapsedSeconds or 0,
		result.acceptedClicks or 0
	)

	ControlUI.showVerdict(result.verdict, result.passed, detail)
end

local function onInput(input: InputObject, processed: boolean)
	if processed then
		return
	end

	--[[
		Clicks during a phase are NOT handled here. ControlInput owns them through
		ContextActionService, so there is one owner of the impulse and no dependence
		on listener ordering.
	]]
	if input.KeyCode == START_KEY then
		requestAttempt()
	elseif input.KeyCode == DOWN_KEY then
		adjustPercent(-PERCENT_STEP)
	elseif input.KeyCode == UP_KEY then
		adjustPercent(PERCENT_STEP)
	end
end

function SquatControlController.start()
	assert(not started, "[SquatControlController] start() must only be called once")
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	ControlUI.mount(playerGui, ControlInput.promptText())
	hudLabel = buildHud(playerGui)
	refreshHud()

	-- SetStateEnabled applies to a Humanoid, and a respawn creates a new one.
	player.CharacterAdded:Connect(function()
		if not ControlUI.isRunning() then
			setCharacterLocked(false)
		end
	end)

	local set = LiftingRemotes.waitForClient(ReplicatedStorage)
	remotes = set

	set.presentControlChallenge.OnClientEvent:Connect(onPresentControlChallenge)
	set.announceControlResult.OnClientEvent:Connect(onAnnounceControlResult)

	UserInputService.InputBegan:Connect(onInput)

	print("[SquatControlController] ready - press C to start a Squat Control attempt")
end

return SquatControlController
