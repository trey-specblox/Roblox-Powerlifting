--!strict
--[[
	================================================================
	TEMPORARY DEVELOPMENT CODE - DELETE THIS FILE WHEN THE RACK EXISTS
	================================================================

	SquatAttemptDebugTrigger
	Client / Dev

	Lets a complete Squat attempt be started from the keyboard, because there is no
	rack, barbell, animation or attempt-selection UI yet.

	ALL temporary testing lives here. LiftAttemptController exposes requestAttempt
	and knows nothing about these keys, so the real rack interaction will call the
	same function and this file deletes cleanly with nothing left behind.

	CONTROLS

		G    start a complete Squat attempt
		V    attempt percentage -2.5%
		B    attempt percentage +2.5%
		1    80%        2    90%        3    100%
		4    105%       5    110%

	During an attempt, the phases own their own inputs: the mouse lifts the control
	bar, and Space presses the depth check. Those are bound by the controller, not
	here.
]]

local ENABLED = true

if not ENABLED then
	return {
		start = function() end,
	}
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LiftAttemptController = require(script.Parent.Parent.Lifting.LiftAttemptController)

local SquatAttemptDebugTrigger = {}

local LIFT_NAME = "Squat"

local START_KEY = Enum.KeyCode.G
local DOWN_KEY = Enum.KeyCode.V
local UP_KEY = Enum.KeyCode.B

-- Must stay inside LiftAttemptConfig's bounds; the server clamps regardless.
local PERCENT_STEP = 0.025
local PERCENT_MIN = 0.40
local PERCENT_MAX = 1.25

local PRESETS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 0.80,
	[Enum.KeyCode.Two] = 0.90,
	[Enum.KeyCode.Three] = 1.00,
	[Enum.KeyCode.Four] = 1.05,
	[Enum.KeyCode.Five] = 1.10,
}

local selectedPercent = 1.00
local started = false
local hudLabel: TextLabel? = nil

local function buildHud(parent: Instance): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "SquatAttemptDebugHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Readout"
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0, 16, 1, -16)
	label.Size = UDim2.fromOffset(500, 112)
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
		"DEV: COMPLETE SQUAT ATTEMPT (temporary)\n"
			.. "attempt: %.1f%% of forecasted max\n"
			.. "[G] start squat    [V] -2.5%%    [B] +2.5%%\n"
			.. "[1] 80%%  [2] 90%%  [3] 100%%  [4] 105%%  [5] 110%%\n"
			.. "in phase: mouse lifts the bar, SPACE hits the depth zone",
		selectedPercent * 100
	)
end

local function setPercent(value: number)
	selectedPercent = math.clamp(value, PERCENT_MIN, PERCENT_MAX)
	refreshHud()
end

local function onInput(input: InputObject, processed: boolean)
	if processed then
		return
	end

	if input.KeyCode == START_KEY then
		LiftAttemptController.requestAttempt(LIFT_NAME, selectedPercent)
		return
	end

	--[[
		Percentage is locked for the whole attempt by the server, so changing it
		mid-attempt would be ignored anyway. Refusing it here keeps the HUD honest
		about what the current attempt is actually using.
	]]
	if LiftAttemptController.isAttemptActive() then
		return
	end

	local preset = PRESETS[input.KeyCode]
	if preset ~= nil then
		setPercent(preset)
	elseif input.KeyCode == DOWN_KEY then
		setPercent(selectedPercent - PERCENT_STEP)
	elseif input.KeyCode == UP_KEY then
		setPercent(selectedPercent + PERCENT_STEP)
	end
end

function SquatAttemptDebugTrigger.start()
	assert(not started, "[SquatAttemptDebugTrigger] start() must only be called once")
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	hudLabel = buildHud(playerGui)
	refreshHud()

	UserInputService.InputBegan:Connect(onInput)

	print("[SquatAttemptDebugTrigger] ready - press G to start a complete Squat attempt")
end

return SquatAttemptDebugTrigger
