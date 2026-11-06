--!strict
--[[
	MeetsTab
	Client / Meet

	The MEETS tab on the left edge (user 2026-11-06: "I should be able to sign up, go do
	something else, then be automatically teleports to compete in my meet"), above the
	coins, outside the venue. It opens the same MEETS list the venue shows, and once
	signed up it counts down to the meet. Hidden in the venue, where the list is on
	screen anyway. Asks nothing of the server itself: LocalMeetController owns it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local UIStyle = require(UIFolder:WaitForChild("UIStyle"))
local MenuKeys = require(UIFolder:WaitForChild("MenuKeys"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local MeetsTab = {}

local OPEN_KEY = Enum.KeyCode.M

export type Tab = {
	setVisible: (visible: boolean) -> (),
	-- "MEET 3  0:45" while signed up; nil for just MEETS.
	setCountdown: (text: string?) -> (),
}

function MeetsTab.build(onToggle: () -> ()): Tab
	local gui = Instance.new("ScreenGui")
	gui.Name = "MeetsTab"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	UIStyle.fitToScreen(gui)

	local tab = Instance.new("TextButton")
	tab.Name = "Tab"
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Position = UDim2.new(0, 0, 0.5, LocalMeetConfig.MeetsTabOffsetY)
	tab.Size = UDim2.fromOffset(150, 44)
	tab.BackgroundColor3 = C.ink
	tab.BorderSizePixel = 0
	tab.AutoButtonColor = true
	tab.Text = ""
	tab.Parent = gui
	UIStyle.stroke(tab, C.yellow, 2)
	local label = UIStyle.text(tab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), SIZES.body, C.white, UIStyle.heading())
	label.Text = "MEETS"
	local keyHint = UIStyle.text(tab, "Key", UDim2.new(0, 10, 1, 2), UDim2.fromOffset(100, 16), SIZES.small, C.muted)
	keyHint.Text = "[" .. OPEN_KEY.Name .. "]"
	keyHint.Visible = not UIStyle.isTouchOnly()

	tab.Activated:Connect(onToggle)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gui.Enabled and MenuKeys.allowed(gameProcessed) and input.KeyCode == OPEN_KEY then
			onToggle()
		end
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	return {
		setVisible = function(visible: boolean)
			gui.Enabled = visible
		end,
		setCountdown = function(text: string?)
			label.Text = text or "MEETS"
			label.TextColor3 = if text then C.yellow else C.white
		end,
	}
end

return MeetsTab
