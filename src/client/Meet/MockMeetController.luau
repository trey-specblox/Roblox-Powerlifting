--!strict
--[[
	MockMeetController
	Client / Meet

	The Mock Meet on the player's screen (GAME_DESIGN.md §29.10). Part 1: while
	the server has the player in their private meet room (the player attribute
	MockMeetConfig.SlotAttribute), a title at the top and a "Leave Mock Meet"
	button at the bottom. The button only asks; the server moves the player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MockMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("MockMeetConfig"))
local MockMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("MockMeetRemotes"))

local MockMeetController = {}

local FONT = "rbxasset://fonts/families/Montserrat.json"
local started = false

local function corner(parent: Instance, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = parent
end

local function buildGui(remotes: MockMeetRemotes.RemoteSet): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "MockMeet"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Enabled = false

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 12)
	title.Size = UDim2.fromOffset(340, 40)
	title.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	title.BackgroundTransparency = 0.15
	title.Text = "MOCK MEET  ·  your private room"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.FontFace = Font.new(FONT, Enum.FontWeight.Bold)
	title.Parent = gui
	corner(title, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = title
	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.AnchorPoint = Vector2.new(0.5, 1)
	stripe.Position = UDim2.new(0.5, 0, 1, 8)
	stripe.Size = UDim2.new(1, -16, 0, 3)
	stripe.BorderSizePixel = 0
	stripe.BackgroundColor3 = Color3.fromRGB(226, 52, 52)
	stripe.Parent = title

	local leave = Instance.new("TextButton")
	leave.Name = "Leave"
	leave.AnchorPoint = Vector2.new(0.5, 1)
	leave.Position = UDim2.new(0.5, 0, 1, -24)
	leave.Size = UDim2.fromOffset(220, 46)
	leave.BackgroundColor3 = Color3.fromRGB(196, 40, 40)
	leave.AutoButtonColor = true
	leave.Text = "Leave Mock Meet"
	leave.TextColor3 = Color3.fromRGB(255, 255, 255)
	leave.TextSize = 20
	leave.FontFace = Font.new(FONT, Enum.FontWeight.Bold)
	leave.Parent = gui
	corner(leave, 10)
	leave.Activated:Connect(function()
		remotes.leave:FireServer()
	end)
	return gui
end

function MockMeetController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remotes = MockMeetRemotes.waitForClient(ReplicatedStorage)
	local gui = buildGui(remotes)
	gui.Parent = player:WaitForChild("PlayerGui")

	local function refresh()
		gui.Enabled = player:GetAttribute(MockMeetConfig.SlotAttribute) ~= nil
	end
	player:GetAttributeChangedSignal(MockMeetConfig.SlotAttribute):Connect(refresh)
	refresh()
end

return MockMeetController
