--!strict
--[[
	PromptController
	Client / UI

	Draws EVERY ProximityPrompt in the game ("hold E to ...") in the game's one
	look (GAME_DESIGN "One UI style for the whole game", user 2026-10-28: the
	"E Interact" prompt in the same style). It only draws: the server still
	creates the prompts, sets their key, hold time and reach, and decides what
	a trigger does.

	Every prompt this client sees is switched to the Custom style (a local
	change only), so Roblox's default bubble never shows and this draws one
	instead: a navy tile with a white edge, a yellow key cap with the key (E,
	the gamepad button, or TAP on touch), the action in heavy italic and the
	object above it, and a yellow bar along the bottom that fills while the
	key is held. On touch the tile itself is the button: pressing it holds the
	prompt, releasing lets go.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local PromptController = {}

local TILE_WIDTH, TILE_HEIGHT = 250, 64
local started = false

-- The key shown on the cap.
local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "^Button", ""))
	end
	local name = prompt.KeyboardKeyCode.Name
	return if #name > 3 then string.upper(string.sub(name, 1, 3)) else name
end

-- Draws one shown prompt; returns the cleanup for when it hides.
local function draw(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType, screen: ScreenGui): () -> ()
	local connections: { RBXScriptConnection } = {}

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Prompt"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(TILE_WIDTH + 12, TILE_HEIGHT + 12)
	billboard.SizeOffset = Vector2.new(prompt.UIOffset.X / (TILE_WIDTH + 12), prompt.UIOffset.Y / (TILE_HEIGHT + 12))
	billboard.Active = true
	billboard.ResetOnSpawn = false
	billboard.Adornee = prompt.Parent :: Instance
	billboard.Parent = screen

	-- The tile: a yellow slab behind, the navy face in front (a button, for touch and mouse clicks).
	UIStyle.frame(billboard, "Back", UDim2.fromOffset(6, 6), UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT), C.yellow)
	local tile = Instance.new("TextButton")
	tile.Name = "Tile"
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.BorderSizePixel = 0
	tile.BackgroundColor3 = C.navy
	tile.Size = UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT)
	tile.Parent = billboard
	UIStyle.stroke(tile, C.white, 2)

	local cap = UIStyle.frame(tile, "Key", UDim2.fromOffset(10, 10), UDim2.fromOffset(44, 44), C.yellow)
	UIStyle.stroke(cap, C.ink, 2)
	local capText = UIStyle.text(cap, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), SIZES.heading, C.ink,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	capText.Text = keyText(prompt, inputType)
	if #capText.Text > 1 then
		capText.TextSize = SIZES.small
	end

	local object = UIStyle.text(tile, "Object", UDim2.fromOffset(64, 8), UDim2.new(1, -72, 0, 18), SIZES.small, C.muted)
	object.TextWrapped = false
	object.TextTruncate = Enum.TextTruncate.AtEnd
	local action = UIStyle.text(tile, "Action", UDim2.fromOffset(64, 26), UDim2.new(1, -72, 0, 28), SIZES.body, C.white,
		UIStyle.heading())
	action.TextWrapped = false
	action.TextTruncate = Enum.TextTruncate.AtEnd
	local function refreshText()
		object.Text = string.upper(prompt.ObjectText)
		action.Text = prompt.ActionText
		object.Visible = prompt.ObjectText ~= ""
		action.Position = if prompt.ObjectText ~= "" then UDim2.fromOffset(64, 26) else UDim2.fromOffset(64, 18)
	end
	refreshText()
	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(refreshText))
	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(refreshText))

	-- The hold bar along the bottom edge.
	local bar = UIStyle.frame(tile, "Hold", UDim2.new(0, 0, 1, -5), UDim2.new(0, 0, 0, 5), C.yellow)
	local tween: Tween? = nil
	local function resetBar()
		if tween then
			tween:Cancel()
			tween = nil
		end
		bar.Size = UDim2.new(0, 0, 0, 5)
	end
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		resetBar()
		if prompt.HoldDuration > 0 then
			local filling = TweenService:Create(bar, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
				{ Size = UDim2.new(1, 0, 0, 5) })
			tween = filling
			filling:Play()
		end
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(resetBar))
	table.insert(connections, prompt.Triggered:Connect(function()
		resetBar()
		tile.BackgroundColor3 = C.yellow
		task.delay(0.12, function()
			tile.BackgroundColor3 = C.navy
		end)
	end))

	-- Touch and mouse: pressing the tile holds the prompt, letting go releases it.
	table.insert(connections, tile.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end))
	table.insert(connections, tile.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end))

	return function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		if tween then
			tween:Cancel()
		end
		billboard:Destroy()
	end
end

-- Switches a prompt to the Custom style, so this file draws it instead of Roblox.
local function adopt(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
	end
end

function PromptController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local screen = Instance.new("ScreenGui")
	screen.Name = "Prompts"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	for _, instance in ipairs(Workspace:GetDescendants()) do
		adopt(instance)
	end
	Workspace.DescendantAdded:Connect(adopt)

	local cleanups: { [ProximityPrompt]: () -> () } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local old = cleanups[prompt]
		if old then
			old()
		end
		cleanups[prompt] = draw(prompt, inputType, screen)
		local hidden: RBXScriptConnection
		hidden = prompt.PromptHidden:Connect(function()
			hidden:Disconnect()
			local cleanup = cleanups[prompt]
			if cleanup then
				cleanups[prompt] = nil
				cleanup()
			end
		end)
	end)
end

return PromptController
