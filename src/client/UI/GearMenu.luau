--!strict
--[[
	GearMenu
	Client / UI

	MY GEAR (GAME_DESIGN.md 30.6, the money system's step 5; user 2026-10-30:
	"anywhere, from a GEAR tab"). A GEAR tab on the left edge under TELEPORT,
	or WornGearConfig.OpenKey, opens a panel with one row per slot (singlet,
	belt, knee sleeves, wrist wraps): what is worn, and a card for every owned
	item in that slot (3D preview, name, WEAR or WORN), and TAKE OFF.

	The rare suits go in these rows too: a squat or deadlift suit under SINGLET, a bench shirt in its own row, and knee wraps
	under KNEE SLEEVES.

	Gear with stats from crates (GAME_DESIGN §35.12) comes first in each row, best
	first, edged in its rarity's colour, with its stats and SCRAP (press twice). The
	status line adds up what the worn pieces give on each lift.

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
local EconomyFolder = Shared:WaitForChild("Economy")
local GearRemotes = require(EconomyFolder:WaitForChild("GearRemotes"))
local GearStats = require(EconomyFolder:WaitForChild("GearStats"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local MenuKeys = require(script.Parent:WaitForChild("MenuKeys"))
local GearPreview = require(script.Parent:WaitForChild("GearPreview"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local GearMenu = {}

local PANEL_WIDTH, PANEL_HEIGHT = 900, 560
-- Under the TELEPORT tab (TeleportMenu sits 72 px under STATS).
local TAB_OFFSET_Y = 144
-- A row with owned items is tall enough for its cards; an empty one only for its heading and one line.
local EMPTY_ROW_HEIGHT = 70
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 170, 142, 10
local PREVIEW_HEIGHT = 62
-- SCRAP's second press has to come within this long.
local CONFIRM_SECONDS = 3
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
	keyHint.Visible = not UIStyle.isTouchOnly()

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
		-- What the worn pieces give on each lift, or how to get some.
		local worn: { [string]: string } = {}
		for slot, pieceId in pairs(if view then view.wearingPieces else {}) do
			local piece = view and view.pieces[pieceId]
			if piece then
				worn[slot] = piece.rarity
			end
		end
		if next(worn) == nil then
			return "Wear one item per slot. Gear from crates at the Shop has stats."
		end
		return string.format("TECHNIQUE FROM GEAR:  SQUAT +%s  ·  BENCH +%s  ·  DEADLIFT +%s", tostring(GearStats.techniqueBonus(worn, "Squat")),
			tostring(GearStats.techniqueBonus(worn, "Bench")), tostring(GearStats.techniqueBonus(worn, "Deadlift")))
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

	-- Asks to take the coach's test for a locked suit: the server moves the player there.
	local function askTest(pieceId: string)
		if asking then
			return
		end
		asking = true
		status.TextColor3, status.Text = C.muted, "Going..."
		local ok, done, message = pcall(function()
			return remotes.startTest:InvokeServer(pieceId)
		end)
		asking = false
		if ok and done then
			holder.Visible = false
		else
			status.TextColor3 = C.red
			status.Text = if ok and typeof(message) == "string" then message else "That didn't go through. Try again."
		end
	end

	-- Puts on or scraps a stat piece (a remote answering like `set`).
	local function askPiece(remote: RemoteFunction, pieceId: string, waiting: string)
		if asking then
			return
		end
		asking = true
		status.TextColor3, status.Text = C.muted, waiting
		local ok, done, message, newView = pcall(function()
			return remote:InvokeServer(pieceId)
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
			local wornPieceId = if current then current.wearingPieces[slot.id] else nil
			local wornPiece = if current and wornPieceId then current.pieces[wornPieceId] else nil
			wornText[slot.id].Text = if wornPiece then "Wearing: " .. GearStats.pieceName(wornPiece)
				elseif wornItem then "Wearing: " .. wornItem.name
				else "Nothing worn"
			wornText[slot.id].TextColor3 = if wornItem then C.yellow else C.muted
			takeOff[slot.id].Visible = wornItem ~= nil
			local count = 0
			-- Stat pieces first, best first.
			local mine: { { id: string, piece: { slot: string, rarity: string, look: string } } } = {}
			for id, piece in pairs(if current then current.pieces else {}) do
				if piece.slot == slot.id then
					table.insert(mine, { id = id, piece = piece })
				end
			end
			table.sort(mine, function(a, b)
				local rankA, rankB = GearStats.rank(a.piece.rarity), GearStats.rank(b.piece.rarity)
				if rankA ~= rankB then
					return rankA > rankB
				end
				return (tonumber(a.id) or 0) > (tonumber(b.id) or 0)
			end)
			for _, entry in ipairs(mine) do
				local piece = entry.piece
				local rarity = GearStats.rarity(piece.rarity)
				local look = ShopConfig.find(piece.look)
				if rarity and look then
					local isWorn = entry.id == wornPieceId
					local card = UIStyle.frame(strip, "Piece_" .. entry.id,
						UDim2.fromOffset(2 + count * (CARD_WIDTH + CARD_GAP), 2), UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT), C.navyDeep)
					UIStyle.stroke(card, rarity.colour, if isWorn then 3 else 2, 0)
					GearPreview.build(card, look, UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, PREVIEW_HEIGHT))
					local name = UIStyle.text(card, "Name", UDim2.fromOffset(6, PREVIEW_HEIGHT + 6), UDim2.new(1, -12, 0, 18),
						SIZES.small, rarity.colour, UIStyle.heading())
					name.Text = GearStats.pieceName(piece)
					name.TextScaled = true
					local stats = UIStyle.text(card, "Stats", UDim2.fromOffset(6, PREVIEW_HEIGHT + 25), UDim2.new(1, -12, 0, 14),
						SIZES.small, C.white)
					stats.Text = GearStats.statText(piece.rarity)
					stats.TextScaled = true
					local wear = Instance.new("TextButton")
					wear.Name = "Wear"
					wear.Position = UDim2.new(0, 6, 1, -30)
					wear.Size = if isWorn then UDim2.new(1, -12, 0, 24) else UDim2.new(0.5, -8, 0, 24)
					wear.BorderSizePixel = 0
					wear.FontFace = UIStyle.heading()
					wear.TextSize = SIZES.small
					-- A rare suit is locked until the coach's test is passed (GAME_DESIGN §35.12).
					local test = current and current.suitTests[piece.rarity]
					local locked = GearStats.suit(piece.rarity) ~= nil and not (test and test.passed)
					if isWorn then
						wear.Text, wear.BackgroundColor3, wear.TextColor3 = "WORN", C.empty, C.muted
						wear.AutoButtonColor = false
					elseif locked and test and test.waitSeconds > 0 then
						wear.Text, wear.BackgroundColor3, wear.TextColor3 = GearStats.waitText(test.waitSeconds), C.empty, C.muted
						wear.AutoButtonColor = false
					elseif locked then
						wear.Text, wear.BackgroundColor3, wear.TextColor3 = "TEST", C.yellow, C.ink
						wear.Activated:Connect(function()
							task.spawn(askTest, entry.id)
						end)
					else
						wear.Text, wear.BackgroundColor3, wear.TextColor3 = "WEAR", C.yellow, C.ink
						wear.Activated:Connect(function()
							task.spawn(askPiece, remotes.setPiece, entry.id, "Changing...")
						end)
					end
					wear.Parent = card
					if not isWorn then
						local scrap = Instance.new("TextButton")
						scrap.Name = "Scrap"
						scrap.Position = UDim2.new(0.5, 2, 1, -30)
						scrap.Size = UDim2.new(0.5, -8, 0, 24)
						scrap.BorderSizePixel = 0
						scrap.FontFace = UIStyle.heading()
						scrap.TextSize = SIZES.small
						scrap.Text, scrap.BackgroundColor3, scrap.TextColor3 = "SCRAP", C.empty, C.white
						-- The first press asks; a piece can't be got back.
						local sureUntil = 0
						scrap.Activated:Connect(function()
							if os.clock() >= sureUntil then
								sureUntil = os.clock() + CONFIRM_SECONDS
								scrap.Text, scrap.BackgroundColor3, scrap.TextColor3 = "+" .. rarity.scrap .. "?", C.white, C.ink
								task.delay(CONFIRM_SECONDS + 0.05, function()
									if scrap.Parent and os.clock() >= sureUntil then
										scrap.Text, scrap.BackgroundColor3, scrap.TextColor3 = "SCRAP", C.empty, C.white
									end
								end)
							else
								task.spawn(askPiece, remotes.scrap, entry.id, "Scrapping...")
							end
						end)
						scrap.Parent = card
					end
					count += 1
				end
			end
			for _, item in ipairs(ShopConfig.Items) do
				if item.category == slot.category and owned[item.id] then
					local card = UIStyle.frame(strip, "Item_" .. item.id,
						UDim2.fromOffset(2 + count * (CARD_WIDTH + CARD_GAP), 2), UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT), C.navyDeep)
					local itemWorn = item.id == wornId and wornPiece == nil
					UIStyle.stroke(card, if itemWorn then C.yellow else C.white, if itemWorn then 2 else 1, 0.4)
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
					if itemWorn then
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
				none.Text = if slot.id == "BenchShirt" then "Rare: drops at official meets." else "Nothing yet. Open a crate at the Shop."
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
		if not MenuKeys.allowed(gameProcessed) then
			return
		end
		if input.KeyCode == WornGearConfig.OpenKey then
			toggle()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return GearMenu
