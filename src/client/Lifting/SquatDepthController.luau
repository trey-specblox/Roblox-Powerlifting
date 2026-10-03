--!strict
--[[
	SquatDepthController
	Client / Lifting

	Input and HUD for the Squat Depth slice.

	CONTROLS

		E        start an attempt (and also presses, if a check is running)
		SPACE    press during a running check
		Z / X    lower or raise the attempt percentage by 2.5%

	WHY SPACE NEEDS SPECIAL HANDLING

	Space is the jump key. It is therefore bound through ContextActionService at
	high priority, and ONLY while a check is on screen, so the press is consumed
	instead of launching the character. Outside a check Space jumps as normal.
	Humanoid jumping is additionally disabled for the duration, so a jump cannot
	slip through even if another binding wins the priority contest.

	E remains bound at all times and does double duty: start an attempt, or press
	a running one. Arrow keys were avoided because they drive movement.

	WHAT THIS SENDS

	Only a percentage, and a press time. It never sends a weight, a difficulty or
	a result. The server converts the percentage using the forecasted max it
	already holds, and grades the press itself. The HUD can show the attempt
	weight only because the server echoes it back in the challenge.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiftingFolder = Shared:WaitForChild("Lifting")
local LiftingRemotes = require(LiftingFolder:WaitForChild("LiftingRemotes"))

local SkillCheckUI = require(script.Parent.SkillCheckUI)

local SquatDepthController = {}

--[[
	Which phase this controller drives. The circular check itself, its rendering
	and its input handling are all phase-agnostic: only this controller is
	Squat-specific, and only because it is the slice's interaction point.
]]
local PHASE = "SquatDepth"

local ATTEMPT_KEY = Enum.KeyCode.E
local PRESS_KEY = Enum.KeyCode.Space
local DOWN_KEY = Enum.KeyCode.Z
local UP_KEY = Enum.KeyCode.X

local PRESS_ACTION = "RpfSkillCheckPress"

--[[
	The on-screen prompt. Defined here, beside the bindings it describes, and
	handed to SkillCheckUI so the two cannot drift apart.
]]
local INSTRUCTION_TEXT = "PRESS SPACE IN THE ZONE"

-- Percentage selection. Clamped again on the server, which is the authority.
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
	gui.Name = "SquatDepthHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Readout"
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0, 16, 1, -16)
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
		"SQUAT DEPTH SLICE\nattempt: %.1f%% of forecasted max\n[E] start attempt    [SPACE] press in the zone\n[Z] -2.5%%    [X] +2.5%%",
		selectedPercent * 100
	)
end

local function adjustPercent(delta: number)
	selectedPercent = math.clamp(selectedPercent + delta, PERCENT_MIN, PERCENT_MAX)
	refreshHud()
end

--[[
	Stops the character jumping while a check is on screen. Belt and braces
	alongside sinking the Space binding.
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

local function requestAttempt()
	local set = remotes
	if set == nil then
		return
	end

	-- Ignore the key while a check is on screen or one is already requested.
	if awaitingChallenge or SkillCheckUI.isRunning() then
		return
	end

	awaitingChallenge = true
	--[[
		The phase travels with the request so the protocol stays the same when
		other phases arrive. The server validates it against its own enabled list
		and derives everything else, so naming it here grants no authority.
	]]
	set.requestAttempt:FireServer(PHASE, selectedPercent)
end

local function onPresentChallenge(challenge: any)
	local set = remotes
	if set == nil then
		return
	end

	awaitingChallenge = false

	-- showVerdict clears the prompt, so put it back for this check.
	SkillCheckUI.setInstruction(INSTRUCTION_TEXT)
	bindPressKey()

	SkillCheckUI.run(challenge, function(pressTimeSeconds)
		-- Released as soon as the check resolves, so Space jumps again at once.
		unbindPressKey()
		-- nil means the needle ran out. The server treats that as a miss too.
		set.reportPress:FireServer(pressTimeSeconds)
	end)
end

local function onAnnounceResult(result: any)
	-- Safety net: if a verdict ever arrives without the report path having run,
	-- the player must not be left unable to jump.
	unbindPressKey()
	SkillCheckUI.showVerdict(result.verdict, result.passed)
end

local function onInput(input: InputObject, processed: boolean)
	if processed then
		return
	end

	--[[
		The only InputBegan listener in the lifting client, which is what makes the
		attempt key unambiguous: a press during a running check resolves THAT check
		and cannot also start the next one. Space is handled separately through
		ContextActionService because it has to out-prioritise jumping.
	]]
	if input.KeyCode == ATTEMPT_KEY then
		if SkillCheckUI.isRunning() then
			SkillCheckUI.pressNow()
		else
			requestAttempt()
		end
	elseif input.KeyCode == DOWN_KEY then
		adjustPercent(-PERCENT_STEP)
	elseif input.KeyCode == UP_KEY then
		adjustPercent(PERCENT_STEP)
	end
end

function SquatDepthController.start()
	assert(not started, "[SquatDepthController] start() must only be called once")
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	SkillCheckUI.mount(playerGui, INSTRUCTION_TEXT)
	hudLabel = buildHud(playerGui)
	refreshHud()

	--[[
		Jumping is re-enabled per character, because SetStateEnabled applies to the
		Humanoid and a respawn creates a new one. Without this, dying mid-check
		would leave the fresh character able to jump while the old binding state
		said otherwise.
	]]
	player.CharacterAdded:Connect(function()
		if not SkillCheckUI.isRunning() then
			setJumpEnabled(true)
		end
	end)

	local set = LiftingRemotes.waitForClient(ReplicatedStorage)
	remotes = set

	set.presentChallenge.OnClientEvent:Connect(onPresentChallenge)
	set.announceResult.OnClientEvent:Connect(onAnnounceResult)

	UserInputService.InputBegan:Connect(onInput)

	print("[SquatDepthController] ready - press E to attempt, SPACE to hit the zone")
end

return SquatDepthController
