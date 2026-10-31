--!strict
--[[
	GearMenu
	Client / UI

	MY GEAR (GAME_DESIGN.md 30.6, the money system's step 5; user 2026-10-30:
	"anywhere, from a GEAR tab"). A GEAR tab on the left edge under TELEPORT,
	or WornGearConfig.OpenKey, opens a panel with one row per slot (singlet,
	belt, knee sleeves, wrist wraps): what is worn, and a card for every owned
	item in that slot (3D preview, name, WEAR or WORN), and TAKE OFF.

	It only asks (GearRemotes) and shows the server's answer; the server
	checks ownership and dresses the character. Built from UIStyle.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local WornGearConfig = require(ConfigFolder:WaitForChild("WornGearConfig"))
local GearRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("GearRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local GearPreview = require(script.Parent:WaitForChild("GearPreview"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local GearMenu = {}

local PANEL_WIDTH, PANEL_HEIGHT = 900, 560
-- Under the TELEPORT tab (TeleportMenu sits 72 px under STATS).
local TAB_OFFSET_Y = 144
-- A row with owned items is tall enough for its cards; an empty one only for its heading and one line.
local EMPTY_ROW_HEIGHT = 70
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 150, 118, 10
local PREVIEW_HEIGHT = 62
local started = false

function GearMenu.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remotes = GearRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gear"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	UIStyle.fitToScreen(gui)

	-- The GEAR tab on the left edge.
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
	tabText.Text = "GEAR"
	UIStyle.cue(tab, "star", UDim2.new(1, -30, 0, 10), 24)
	local keyHint = UIStyle.text(tab, "Key", UDim2.new(0, 10, 1, 2), UDim2.fromOffset(100, 16), SIZES.small, C.muted)
	keyHint.Text = "[" .. WornGearConfig.OpenKey.Name .. "]"

	-- The panel.
	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	UIStyle.titleTag(holder, "Tag", "MY GEAR", UDim2.fromOffset(-18, -30), UDim2.fromOffset(240, 52), nil, "star")

	local list = Instance.new("ScrollingFrame")
	list.Name = "Slots"
	list.Position = UDim2.fromOffset(20, 34)
	list.Size = UDim2.new(1, -30, 1, -96)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.yellow
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = body

	local status = UIStyle.text(body, "Status", UDim2.new(0, 20, 1, -52), UDim2.new(1, -220, 0, 40), SIZES.body, C.muted)
	status.TextYAlignment = Enum.TextYAlignment.Center

	local view: GearRemotes.GearView? = nil
	local asking = false
	local rows: { [string]: Frame } = {}
	local strips: { [string]: ScrollingFrame } = {}
	local wornText: { [string]: TextLabel } = {}
	local takeOff: { [string]: TextButton } = {}

	local function hint(): string
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			return "Gear shows on R15 avatars only. Your choices are still saved."
		end
		if view and not view.drawn then
			return "Your choices are saved. The gear shows on you once its models are in the game."
		end
		return "Gear is for looks only. Wear one item per slot."
	end

	local refresh: () -> ()

	local function ask(slotId: string, itemId: string?)
		if asking then
			return
		end
		asking = true
		status.TextColor3, status.Text = C.muted, "Changing..."
		local ok, done, message, newView = pcall(function()
			-- false takes the slot's item off (nil would not reach the server as an argument).
			return remotes.set:InvokeServer(slotId, if itemId then itemId else false)
		end)
		asking = false
		if ok then
			status.TextColor3 = if done then C.yellow else C.red
			status.Text = if typeof(message) == "string" then message else ""
			if newView then
				view = newView
				refresh()
			end
		else
			status.TextColor3, status.Text = C.red, "That didn't go through. Try again."
		end
	end

	-- One row per slot: its heading, what is worn, TAKE OFF, and a strip of owned items.
	for _, slot in ipairs(WornGearConfig.Slots) do
		local row = Instance.new("Frame")
		row.Name = "Row_" .. slot.id
		row.BackgroundTransparency = 1
		row.Parent = list
		rows[slot.id] = row
		UIStyle.sectionHead(row, "Head", slot.label, UDim2.fromOffset(0, 2), 170, nil, "bar")
		local worn = UIStyle.text(row, "Worn", UDim2.fromOffset(210, 0), UDim2.fromOffset(420, 24), SIZES.body, C.muted)
		worn.TextYAlignment = Enum.TextYAlignment.Center
		wornText[slot.id] = worn
		takeOff[slot.id] = UIStyle.button(row, "TakeOff", "TAKE OFF", UDim2.new(1, -150, 0, -2), UDim2.fromOffset(140, 28),
			"outline", function()
				task.spawn(ask, slot.id, nil)
			end)
		local strip = Instance.new("ScrollingFrame")
		strip.Name = "Items"
		strip.Position = UDim2.fromOffset(0, 30)
		strip.Size = UDim2.new(1, 0, 0, CARD_HEIGHT + 8)
		strip.BackgroundTransparency = 1
		strip.BorderSizePixel = 0
		strip.ScrollBarThickness = 4
		strip.ScrollBarImageColor3 = C.yellow
		strip.ScrollingDirection = Enum.ScrollingDirection.X
		strip.Parent = row
		strips[slot.id] = strip
	end

	refresh = function()
		local current = view
		local owned: { [string]: boolean } = {}
		for _, itemId in ipairs(if current then current.owned else {}) do
			owned[itemId] = true
		end
		local y = 0
		for _, slot in ipairs(WornGearConfig.Slots) do
			local strip = strips[slot.id]
			for _, child in ipairs(strip:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local wornId = if current then current.wearing[slot.id] else nil
			local wornItem = if wornId then ShopConfig.find(wornId) else nil
			wornText[slot.id].Text = if wornItem then "Wearing: " .. wornItem.name else "Nothing worn"
			wornText[slot.id].TextColor3 = if wornItem then C.yellow else C.muted
			takeOff[slot.id].Visible = wornItem ~= nil
			local count = 0
			for _, item in ipairs(ShopConfig.Items) do
				if item.category == slot.category and owned[item.id] then
					local card = UIStyle.frame(strip, "Item_" .. item.id,
						UDim2.fromOffset(2 + count * (CARD_WIDTH + CARD_GAP), 2), UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT), C.navyDeep)
					UIStyle.stroke(card, if item.id == wornId then C.yellow else C.white, if item.id == wornId then 2 else 1, 0.4)
					GearPreview.build(card, item, UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, PREVIEW_HEIGHT))
					local name = UIStyle.text(card, "Name", UDim2.fromOffset(6, PREVIEW_HEIGHT + 6), UDim2.new(1, -12, 0, 20),
						SIZES.small, C.white, UIStyle.heading())
					name.Text = string.upper(item.name)
					name.TextScaled = true
					local button = Instance.new("TextButton")
					button.Name = "Wear"
					button.Position = UDim2.new(0, 6, 1, -30)
					button.Size = UDim2.new(1, -12, 0, 24)
					button.BorderSizePixel = 0
					button.FontFace = UIStyle.heading()
					button.TextSize = SIZES.small
					if item.id == wornId then
						button.Text, button.BackgroundColor3, button.TextColor3 = "WORN", C.empty, C.muted
						button.AutoButtonColor = false
					else
						button.Text, button.BackgroundColor3, button.TextColor3 = "WEAR", C.yellow, C.ink
						button.Activated:Connect(function()
							task.spawn(ask, slot.id, item.id)
						end)
					end
					button.Parent = card
					count += 1
				end
			end
			if count == 0 then
				local none = UIStyle.text(strip, "None", UDim2.fromOffset(2, 0), UDim2.fromOffset(500, 26), SIZES.body, C.muted)
				none.Text = "Nothing yet. Buy one at the Shop."
			end
			strip.CanvasSize = UDim2.fromOffset(2 + count * (CARD_WIDTH + CARD_GAP), 0)
			local height = if count > 0 then 30 + CARD_HEIGHT + 22 else EMPTY_ROW_HEIGHT
			strip.Size = UDim2.new(1, 0, 0, height - 30)
			rows[slot.id].Position = UDim2.fromOffset(4, y)
			rows[slot.id].Size = UDim2.new(1, -12, 0, height)
			y += height
		end
		list.CanvasSize = UDim2.fromOffset(0, y)
	end

	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
	end)

	local function open()
		holder.Visible = true
		status.TextColor3, status.Text = C.muted, "Loading..."
		local ok, newView = pcall(function()
			return remotes.get:InvokeServer()
		end)
		if ok and newView then
			view = newView
			refresh()
			status.Text = hint()
		else
			status.TextColor3, status.Text = C.red, "Your gear didn't load. Close and try again."
		end
	end

	local function toggle()
		if holder.Visible then
			holder.Visible = false
		else
			task.spawn(open)
		end
	end
	tab.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Not while typing in a box (chat, the meet's weight box, the deadlift typing).
		if gameProcessed or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		if input.KeyCode == WornGearConfig.OpenKey then
			toggle()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return GearMenu
