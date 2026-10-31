--!strict
--[[
	TeleportMenu
	Client / UI

	The TELEPORT menu (user 2026-10-30: "a teleport button on the left, where
	you can tp to any place"). A TELEPORT tab on the left edge under the STATS
	tab, or OPEN_KEY, opens a panel with every place in TeleportConfig, by
	section. Pressing a place asks the server (TeleportRemotes.REQUEST); the
	server checks and moves the player, and says why not when it can't. Built
	from UIStyle. It decides nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TeleportConfig = require(Shared:WaitForChild("Config"):WaitForChild("TeleportConfig"))
local TeleportRemotes = require(Shared:WaitForChild("World"):WaitForChild("TeleportRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local TeleportMenu = {}

local OPEN_KEY = Enum.KeyCode.T
local PANEL_WIDTH, PANEL_HEIGHT = 560, 290
local COLUMNS = 2
local BUTTON_WIDTH, BUTTON_HEIGHT = 250, 50
local GAP = 10
-- Room inside the scrolling list so the buttons' edges are not clipped.
local INSET = 4
-- Under the STATS tab (StatsScreen: centred on the left edge, 44 px tall, its key hint below it).
local TAB_OFFSET_Y = 72
local started = false

function TeleportMenu.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remote = TeleportRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Teleport"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	UIStyle.fitToScreen(gui)

	-- The TELEPORT tab on the left edge.
	local tab = Instance.new("TextButton")
	tab.Name = "Tab"
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Position = UDim2.new(0, 0, 0.5, TAB_OFFSET_Y)
	tab.Size = UDim2.fromOffset(150, 44)
	tab.BackgroundColor3 = C.ink
	tab.BorderSizePixel = 0
	tab.AutoButtonColor = true
	tab.Text = ""
	tab.Parent = gui
	UIStyle.stroke(tab, C.yellow, 2)
	local tabText = UIStyle.text(tab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -40, 1, 0), SIZES.body, C.white,
		UIStyle.heading())
	tabText.Text = "TELEPORT"
	UIStyle.cue(tab, "chevron", UDim2.new(1, -30, 0, 10), 24)
	local keyHint = UIStyle.text(tab, "Key", UDim2.new(0, 10, 1, 2), UDim2.fromOffset(100, 16), SIZES.small, C.muted)
	keyHint.Text = "[" .. OPEN_KEY.Name .. "]"

	-- The panel.
	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	UIStyle.titleTag(holder, "Tag", "TELEPORT", UDim2.fromOffset(-18, -30), UDim2.fromOffset(260, 52), nil, "chevron")

	local list = Instance.new("ScrollingFrame")
	list.Name = "Places"
	list.Position = UDim2.fromOffset(20, 40)
	list.Size = UDim2.new(1, -30, 1, -100)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.yellow
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = body

	local status = UIStyle.text(body, "Status", UDim2.new(0, 20, 1, -52), UDim2.new(1, -220, 0, 40), SIZES.body, C.muted)
	status.TextYAlignment = Enum.TextYAlignment.Center

	local asking = false
	local function go(destination: TeleportConfig.Destination)
		if asking then
			return
		end
		asking = true
		status.TextColor3 = C.muted
		status.Text = "Teleporting to " .. string.lower(destination.label) .. "…"
		local ok, went, message = pcall(function()
			return remote:InvokeServer(destination.id)
		end)
		asking = false
		if ok and went then
			status.Text = ""
			holder.Visible = false
		else
			status.TextColor3 = C.red
			status.Text = if ok and typeof(message) == "string" then message else "Can't teleport right now."
		end
	end

	-- Each section: a heading, then its places in rows of COLUMNS.
	local y = INSET
	for _, group in ipairs(TeleportConfig.Groups) do
		UIStyle.sectionHead(list, "Head_" .. group, group, UDim2.fromOffset(INSET, y), 150, PANEL_WIDTH - 80, "bar")
		y += 30
		local column = 0
		for _, destination in ipairs(TeleportConfig.Destinations) do
			if destination.group == group then
				UIStyle.button(list, destination.id, destination.label,
					UDim2.fromOffset(INSET + column * (BUTTON_WIDTH + GAP), y), UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT), "outline",
					function()
						task.spawn(go, destination)
					end)
				column += 1
				if column == COLUMNS then
					column = 0
					y += BUTTON_HEIGHT + GAP
				end
			end
		end
		if column > 0 then
			y += BUTTON_HEIGHT + GAP
		end
		y += 12
	end
	list.CanvasSize = UDim2.fromOffset(0, y)

	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
	end)

	local function toggle()
		holder.Visible = not holder.Visible
		if holder.Visible then
			status.Text = ""
		end
	end
	tab.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Not while typing in a box (chat, the meet's weight box, the deadlift typing).
		if gameProcessed or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		if input.KeyCode == OPEN_KEY then
			toggle()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return TeleportMenu
