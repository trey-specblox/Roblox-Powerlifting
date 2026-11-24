--!strict
--[[
	HeldCounters
	Client / UI

	THE FLOATING WIN COUNTER (GAME_DESIGN §42, user 2026-11-24: "when players win their first medals/trophies and they get
	the item in their inventory have a floating ui that counts their wins. This could be like another way for them to flex
	their items"; picked: shown while held, only to players nearby). When anyone holds a medal or trophy (a Tool with the
	server's WinCount / WinLabel / WinColour attributes, HoldService), this screen draws a small label over it:
	"x12  STATE CHAMPION", in its metal's colour.

	Small and only near (the user's no-clutter rule): a BillboardGui in this player's PlayerGui with MaxDistance, never
	through walls, gone when the item is put away. Display only.
]]

local Players = game:GetService("Players")

local UIFancy = require(script.Parent:WaitForChild("UIFancy"))
local make = UIFancy.make

local HeldCounters = {}

local NEAR_STUDS = 60
local started = false
local labels: { [Tool]: BillboardGui } = {}

local function drawFor(tool: Tool)
	local count, label = tool:GetAttribute("WinCount"), tool:GetAttribute("WinLabel")
	local handle = tool:FindFirstChild("Handle")
	if typeof(count) ~= "number" or typeof(label) ~= "string" or handle == nil or not handle:IsA("BasePart") then
		return
	end
	local colour = tool:GetAttribute("WinColour")
	local gui = labels[tool]
	if gui == nil then
		gui = make("BillboardGui", {
			Name = "WinCounter", Size = UDim2.fromOffset(220, 46), StudsOffset = Vector3.new(0, 2.2, 0), AlwaysOnTop = false,
			LightInfluence = 0, MaxDistance = NEAR_STUDS, Adornee = handle, Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
		local back = make("Frame", { Name = "Back", BackgroundColor3 = Color3.fromRGB(10, 14, 34), BackgroundTransparency = 0.25,
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.8),
			Parent = gui })
		UIFancy.corner(back, UDim.new(0, 10))
		UIFancy.outline(back, 2, if typeof(colour) == "Color3" then colour else Color3.new(1, 1, 1))
		local text = UIFancy.words(back, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20, 2,
			if typeof(colour) == "Color3" then colour else Color3.new(1, 1, 1))
		text.TextScaled = true
		make("UITextSizeConstraint", { MaxTextSize = 22, Parent = text })
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = text })
		labels[tool] = gui
	end
	local text = gui:FindFirstChild("Back") and (gui :: any).Back:FindFirstChild("Text")
	if text and text:IsA("TextLabel") then
		text.Text = string.format("x%d  %s", count, label)
	end
end

local function forget(tool: Tool)
	local gui = labels[tool]
	labels[tool] = nil
	if gui then
		gui:Destroy()
	end
end

local function watchTool(tool: Instance)
	if not tool:IsA("Tool") or labels[tool] then
		return
	end
	drawFor(tool)
	tool:GetAttributeChangedSignal("WinCount"):Connect(function()
		drawFor(tool)
	end)
	tool.AncestryChanged:Connect(function()
		if tool.Parent == nil or not tool.Parent:IsA("Model") then
			forget(tool)
		end
	end)
end

local function watchCharacter(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		watchTool(child)
	end
	character.ChildAdded:Connect(function(child)
		task.defer(watchTool, child)
	end)
end

local function watchPlayer(player: Player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

function HeldCounters.start()
	if started then
		return
	end
	started = true
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return HeldCounters
