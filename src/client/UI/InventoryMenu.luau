--!strict
--[[
	InventoryMenu
	Client / UI

	THE INVENTORY (GAME_DESIGN §42, user 2026-11-24, from a reference screenshot of another game's inventory): it replaces
	the MY GEAR menu (GearMenu, retired: nothing starts it) with one screen for everything the lifter owns. The INVENTORY
	tab sits where GEAR was (key WornGearConfig.OpenKey); the ScreenGui keeps the name "Gear" so MenuKeys hides it on a
	lifter's turn as before.

		LEFT    categories: ALL, GEAR, FOOD, TROPHIES, MISC, CLOTHES, and the GEAR: ON / OFF toggle
		MIDDLE  the items in a grid, each framed in its rarity's colour (gear) or its kind's (food, trophies), with
		        "x2" for stacks; CLOTHES shows the clothes rows (a piece, then a colour) here instead
		RIGHT   EQUIPMENT: a lifter outline with a slot for each worn piece (singlet, bench shirt, belt, wrist wraps, knee
		        sleeves); tapping a slot shows that slot's gear
		BOTTOM  the chosen item: a big preview, its name in its colour, what it does, and its buttons (WEAR / TAKE OFF /
		        SCRAP / TEST for gear, EAT for food)

	Built from the game's UI pieces (UIStyle, UIFancy, from the user's UI kit; the layout follows the user's reference,
	never its artwork). It only asks (GearRemotes, ClothesRemotes, InventoryRemotes) and shows the server's answers; the
	server checks every request.

	PERFORMANCE: one small ViewportFrame per tile (like MY GEAR's cards); tiles are rebuilt only when the items change or
	the category changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local WornGearConfig = require(ConfigFolder:WaitForChild("WornGearConfig"))
local KitchenConfig = require(ConfigFolder:WaitForChild("KitchenConfig"))
local ClothesConfig = require(ConfigFolder:WaitForChild("ClothesConfig"))
local EconomyFolder = Shared:WaitForChild("Economy")
local GearRemotes = require(EconomyFolder:WaitForChild("GearRemotes"))
local GearStats = require(EconomyFolder:WaitForChild("GearStats"))
local ClothesRemotes = require(EconomyFolder:WaitForChild("ClothesRemotes"))
local InventoryRemotes = require(EconomyFolder:WaitForChild("InventoryRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local UIFancy = require(script.Parent:WaitForChild("UIFancy"))
local MenuKeys = require(script.Parent:WaitForChild("MenuKeys"))
local GearPreview = require(script.Parent:WaitForChild("GearPreview"))
local BoostBar = require(script.Parent:WaitForChild("BoostBar"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes
local make = UIFancy.make

local InventoryMenu = {}

local PANEL_WIDTH, PANEL_HEIGHT = 1000, 620
-- Under the TELEPORT tab, where GEAR was.
local TAB_OFFSET_Y = 144
local LEFT_W = 150
local GRID_X, GRID_W, GRID_TOP, GRID_H = 172, 474, 40, 362
local TILE_W, TILE_H, TILE_GAP = 108, 124, 8
local RIGHT_X = 660
local DESC_Y = 414
local CONFIRM_SECONDS = 3
local FOOD_COLOUR = Color3.fromRGB(255, 150, 90)
local AWARD_COLOURS = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 214, 226), Color3.fromRGB(214, 138, 74) }
local CATEGORIES = { "ALL", "GEAR", "FOOD", "TROPHIES", "MISC", "CLOTHES" }

local started = false

-- One thing in the grid: a stat piece, a Shop item, or an inventory item.
type Entry = {
	key: string, -- "piece:12", "shop:belt_black", "item:3"
	category: string, -- GEAR / FOOD / TROPHIES / MISC
	slot: string?, -- gear's slot id
	name: string,
	colour: Color3,
	qty: number,
	piece: any?,
	pieceId: string?,
	shop: any?,
	item: any?,
	itemId: string?,
	rank: number, -- for sorting: best first
}

local function placeText(place: number): string
	return if place == 1 then "GOLD" elseif place == 2 then "SILVER" else "BRONZE"
end

function InventoryMenu.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local gearRemotes = GearRemotes.waitForClient(ReplicatedStorage)
	local clothesRemotes = ClothesRemotes.waitForClient(ReplicatedStorage)
	local itemRemotes = InventoryRemotes.waitForClient(ReplicatedStorage)

	local gui = make("ScreenGui", { Name = "Gear", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 })
	UIStyle.fitToScreen(gui)

	-- The INVENTORY tab on the left edge (where GEAR was).
	local tab = make("TextButton", {
		Name = "Tab", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, TAB_OFFSET_Y), Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = C.ink, BorderSizePixel = 0, AutoButtonColor = true, Text = "", Parent = gui,
	})
	UIStyle.stroke(tab, C.yellow, 2)
	local tabText = UIStyle.text(tab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -40, 1, 0), SIZES.body, C.white, UIStyle.heading())
	tabText.Text = "INVENTORY"
	tabText.TextScaled = true
	make("UITextSizeConstraint", { MaxTextSize = SIZES.body, Parent = tabText })
	UIStyle.cue(tab, "star", UDim2.new(1, -30, 0, 10), 24)
	local keyHint = UIStyle.text(tab, "Key", UDim2.new(0, 10, 1, 2), UDim2.fromOffset(100, 16), SIZES.small, C.muted)
	keyHint.Text = "[" .. WornGearConfig.OpenKey.Name .. "]"
	keyHint.Visible = not UIStyle.isTouchOnly()

	-- The panel.
	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	UIStyle.titleTag(holder, "Tag", "INVENTORY", UDim2.fromOffset(-18, -30), UDim2.fromOffset(260, 52), nil, "star")
	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
	end)

	local gearView: GearRemotes.GearView? = nil
	local clothesView: ClothesRemotes.ClothesView? = nil
	local itemsView: InventoryRemotes.InventoryView? = nil
	local category = "ALL"
	local slotFilter: string? = nil
	local selectedKey: string? = nil
	local asking = false

	------------------------------------------------------------------ LEFT: categories and the gear toggle
	local categoryButtons: { [string]: TextButton } = {}
	for index, name in ipairs(CATEGORIES) do
		local button = make("TextButton", {
			Name = "Cat_" .. name, Position = UDim2.fromOffset(16, 40 + (index - 1) * 50), Size = UDim2.fromOffset(LEFT_W - 6, 42),
			BackgroundColor3 = C.navyDeep, BorderSizePixel = 0, AutoButtonColor = true, FontFace = UIStyle.heading(), TextSize = SIZES.body,
			TextColor3 = C.white, Text = name, Parent = body,
		})
		UIStyle.stroke(button, C.white, 1, 0.5)
		categoryButtons[name] = button
	end
	local gearToggle = make("TextButton", {
		Name = "GearToggle", Position = UDim2.fromOffset(16, 40 + #CATEGORIES * 50 + 12), Size = UDim2.fromOffset(LEFT_W - 6, 36),
		BackgroundColor3 = C.navyDeep, BorderSizePixel = 0, AutoButtonColor = true, FontFace = UIStyle.heading(), TextSize = SIZES.small,
		TextColor3 = C.white, Text = "GEAR: ON", Parent = body,
	})
	UIStyle.stroke(gearToggle, C.yellow, 1, 0.3)

	------------------------------------------------------------------ MIDDLE: the grid (and the clothes rows)
	local gridHead = UIStyle.text(body, "GridHead", UDim2.fromOffset(GRID_X, 8), UDim2.fromOffset(GRID_W, 26), SIZES.body, C.white, UIStyle.heading())
	local grid = make("ScrollingFrame", {
		Name = "ItemGrid", Position = UDim2.fromOffset(GRID_X, GRID_TOP), Size = UDim2.fromOffset(GRID_W, GRID_H), BackgroundColor3 = C.navyDeep,
		BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.yellow,
		ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = body,
	})
	UIStyle.stroke(grid, C.white, 1, 0.7)
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = grid })
	make("UIGridLayout", { CellSize = UDim2.fromOffset(TILE_W, TILE_H), CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local clothesList = make("ScrollingFrame", {
		Name = "Clothes", Position = UDim2.fromOffset(GRID_X, GRID_TOP), Size = UDim2.fromOffset(PANEL_WIDTH - GRID_X - 20, GRID_H + 170),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.yellow,
		ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, Parent = body,
	})

	------------------------------------------------------------------ RIGHT: equipment
	local equip = make("Frame", { Name = "Equipment", BackgroundTransparency = 1, Position = UDim2.fromOffset(RIGHT_X, 8),
		Size = UDim2.fromOffset(PANEL_WIDTH - RIGHT_X - 20, DESC_Y - 16), Parent = body })
	local equipHead = UIStyle.text(equip, "Head", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 26), SIZES.body, C.white, UIStyle.heading())
	equipHead.Text = "EQUIPMENT"
	-- A lifter outline: head, torso, arms, legs, in a soft white line; broad like a powerlifter and as big as the space
	-- allows (user 2026-11-24: the slots sit on the body, so the body has to be big enough to hold them).
	local OUTLINE_W, OUTLINE_H = 200, 350
	local outlineLeft = (PANEL_WIDTH - RIGHT_X - 20) / 2 - OUTLINE_W / 2
	local outlineTop = 34
	local outline = make("Frame", { Name = "Outline", BackgroundTransparency = 1, Position = UDim2.fromOffset(outlineLeft, outlineTop),
		Size = UDim2.fromOffset(OUTLINE_W, OUTLINE_H), Parent = equip })
	local function limb(name: string, x: number, y: number, w: number, h: number, round: boolean?)
		local part = make("Frame", { Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.white,
			BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = outline })
		UIFancy.corner(part, UDim.new(0, if round then 999 else 12))
		UIStyle.stroke(part, C.white, 1.5, 0.55)
	end
	limb("Head", 74, 0, 52, 52, true)
	limb("Torso", 44, 58, 112, 124)
	limb("ArmL", 8, 62, 32, 124)
	limb("ArmR", 160, 62, 32, 124)
	limb("LegL", 50, 188, 46, 156)
	limb("LegR", 104, 188, 46, 156)
	-- The slots sit ON the body where each piece is worn (user 2026-11-24: "the singlet box can be on the top of the chest
	-- area, belts on the waist area, wrist wraps on the wrist area, knee sleeves on the knee area"); the bench shirt, the
	-- piece with sleeves, on the upper arm. Centres in the outline's own pixels; each label goes above or below its box
	-- so no two labels touch.
	local SLOT_SIZE = 60
	local SLOT_SPOTS: { [string]: { centre: Vector2, labelAbove: boolean } } = {
		Singlet = { centre = Vector2.new(100, 100), labelAbove = true }, -- the chest
		BenchShirt = { centre = Vector2.new(176, 104), labelAbove = false }, -- the right upper arm
		WristWraps = { centre = Vector2.new(24, 172), labelAbove = true }, -- the left wrist
		Belt = { centre = Vector2.new(100, 172), labelAbove = false }, -- the waist
		KneeSleeves = { centre = Vector2.new(100, 268), labelAbove = false }, -- the knees
	}
	local slotBoxes: { [string]: Frame } = {}
	for _, slot in ipairs(WornGearConfig.Slots) do
		local spot = SLOT_SPOTS[slot.id] or { centre = Vector2.new(100, 300), labelAbove = false }
		local centre = spot.centre
		local box = make("TextButton", { Name = "Slot_" .. slot.id,
			Position = UDim2.fromOffset(outlineLeft + centre.X - SLOT_SIZE / 2, outlineTop + centre.Y - SLOT_SIZE / 2),
			Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE), ZIndex = 3,
			BackgroundColor3 = C.navyDeep, BorderSizePixel = 0, AutoButtonColor = true, Text = "", Parent = equip })
		UIFancy.corner(box, UDim.new(0, 10))
		UIStyle.stroke(box, C.white, 1.5, 0.4)
		local label = UIStyle.text(box, "Label", UDim2.new(0, -10, if spot.labelAbove then 0 else 1, if spot.labelAbove then -16 else 2),
			UDim2.new(1, 20, 0, 14), SIZES.small, C.white, UIStyle.heading())
		label.Text = slot.label
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextScaled = true
		label.ZIndex = 4
		make("UIStroke", { Thickness = 1.5, Color = C.ink, Parent = label })
		slotBoxes[slot.id] = box :: any
		box.Activated:Connect(function()
			category, slotFilter = "GEAR", slot.id
			InventoryMenu._refreshAll()
		end)
	end

	------------------------------------------------------------------ BOTTOM: the chosen item
	local desc = make("Frame", { Name = "Description", Position = UDim2.fromOffset(GRID_X, DESC_Y), Size = UDim2.fromOffset(PANEL_WIDTH - GRID_X - 20, 166),
		BackgroundColor3 = C.navyDeep, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = body })
	UIStyle.stroke(desc, C.yellow, 1.5, 0.3)
	local descPreview = make("Frame", { Name = "Preview", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(146, 146),
		BackgroundColor3 = C.navy, BorderSizePixel = 0, Parent = desc })
	local descPreviewEdge = UIStyle.stroke(descPreview, C.white, 2, 0.4)
	local descName = UIStyle.text(desc, "Name", UDim2.fromOffset(170, 10), UDim2.fromOffset(440, 34), SIZES.heading, C.white, UIStyle.heading())
	descName.TextScaled = true
	make("UITextSizeConstraint", { MaxTextSize = SIZES.heading, Parent = descName })
	local descSub = UIStyle.text(desc, "Sub", UDim2.fromOffset(170, 46), UDim2.fromOffset(440, 22), SIZES.small, C.yellow, UIStyle.heading())
	local descBody = UIStyle.text(desc, "Body", UDim2.fromOffset(170, 70), UDim2.fromOffset(440, 54), SIZES.small, C.white)
	descBody.TextWrapped = true
	descBody.TextYAlignment = Enum.TextYAlignment.Top
	local status = UIStyle.text(desc, "Status", UDim2.fromOffset(170, 128), UDim2.fromOffset(440, 28), SIZES.small, C.muted)
	local primary = make("TextButton", { Name = "Primary", Position = UDim2.new(1, -196, 0, 10), Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = C.yellow, BorderSizePixel = 0, AutoButtonColor = true, FontFace = UIStyle.heading(), TextSize = SIZES.heading,
		TextColor3 = C.ink, Text = "", Visible = false, Parent = desc })
	UIFancy.corner(primary, UDim.new(0, 10))
	local secondary = make("TextButton", { Name = "Secondary", Position = UDim2.new(1, -196, 0, 62), Size = UDim2.fromOffset(180, 40),
		BackgroundColor3 = C.empty, BorderSizePixel = 0, AutoButtonColor = true, FontFace = UIStyle.heading(), TextSize = SIZES.body,
		TextColor3 = C.white, Text = "", Visible = false, Parent = desc })
	UIFancy.corner(secondary, UDim.new(0, 10))
	-- HOLD / PUT AWAY (GAME_DESIGN §42): any item, held out in the hand like a Roblox gear (HoldService).
	local holdButton = make("TextButton", { Name = "Hold", Position = UDim2.new(1, -196, 0, 108), Size = UDim2.fromOffset(180, 40),
		BackgroundColor3 = C.navy, BorderSizePixel = 0, AutoButtonColor = true, FontFace = UIStyle.heading(), TextSize = SIZES.body,
		TextColor3 = C.white, Text = "HOLD", Visible = false, Parent = desc })
	UIFancy.corner(holdButton, UDim.new(0, 10))
	UIStyle.stroke(holdButton, C.yellow, 1.5, 0.2)
	local holdKey: string? = nil
	local primaryAction: (() -> ())? = nil
	local secondaryAction: (() -> ())? = nil
	primary.Activated:Connect(function()
		if primaryAction then
			task.spawn(primaryAction :: () -> ())
		end
	end)
	secondary.Activated:Connect(function()
		if secondaryAction then
			task.spawn(secondaryAction :: () -> ())
		end
	end)

	------------------------------------------------------------------ previews
	-- A 3D model preview in a ViewportFrame (food, trophies), turned a little.
	local function modelPreview(parent: GuiObject, modelName: string): ViewportFrame?
		local models = ReplicatedStorage:FindFirstChild("KitchenModels")
		local source = models and models:FindFirstChild(modelName)
		local viewport = make("ViewportFrame", { Name = "Preview", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(170, 160, 150), LightColor = Color3.fromRGB(255, 245, 230), LightDirection = Vector3.new(-0.4, -1, 0.3),
			Parent = parent })
		if source == nil or not source:IsA("Model") then
			return viewport
		end
		local model = source:Clone()
		model:PivotTo(CFrame.Angles(0, math.rad(25), 0))
		model.Parent = viewport
		local size = model:GetExtentsSize()
		local reach = math.max(size.X, size.Y, size.Z)
		local camera = make("Camera", { FieldOfView = 30, Parent = viewport })
		camera.CFrame = CFrame.lookAt(Vector3.new(0, reach * 0.9, -reach * 1.7), Vector3.new(0, size.Y * 0.1, 0))
		viewport.CurrentCamera = camera
		return viewport
	end

	-- The trophy or medal the server put in ReplicatedStorage.ItemModels, in this one's metal.
	local function awardPreview(parent: GuiObject, kind: string, colour: Color3): ViewportFrame?
		local models = ReplicatedStorage:FindFirstChild("ItemModels")
		local source = models and models:FindFirstChild(kind)
		if source == nil or not source:IsA("Model") then
			return nil
		end
		local viewport = make("ViewportFrame", { Name = "Preview", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(170, 160, 150), LightColor = Color3.fromRGB(255, 245, 230), LightDirection = Vector3.new(-0.4, -1, 0.3),
			Parent = parent })
		local model = source:Clone()
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and (part.Name == "Trophy_Metal" or string.find(part.Name, "Disc") ~= nil) then
				part.Color = colour
			end
		end
		model:PivotTo(CFrame.Angles(0, math.rad(20), 0))
		model.Parent = viewport
		local size = model:GetExtentsSize()
		local reach = math.max(size.X, size.Y, size.Z)
		local camera = make("Camera", { FieldOfView = 30, Parent = viewport })
		local cf = model:GetBoundingBox()
		camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, reach * 0.25, -reach * 2.1), cf.Position)
		viewport.CurrentCamera = camera
		return viewport
	end

	local function previewFor(parent: GuiObject, entry: Entry)
		if entry.piece or entry.shop then
			local look = if entry.piece then ShopConfig.find(entry.piece.look) else entry.shop
			if look then
				GearPreview.build(parent, look, UDim2.fromOffset(2, 2), UDim2.new(1, -4, 1, -4))
			end
		elseif entry.item and entry.item.type == "Food" then
			modelPreview(parent, if entry.item.food == "Meal" then "MeetMeal" else "BigSteak")
		elseif entry.item and (entry.item.type == "Trophy" or entry.item.type == "Medal") then
			local viewport = awardPreview(parent, entry.item.type, entry.colour)
			if viewport == nil then
				local letter = UIStyle.text(parent, "Place", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), SIZES.heading, entry.colour, UIStyle.heading())
				letter.Text = string.format("%s\n%s", if entry.item.type == "Trophy" then "TROPHY" else "MEDAL", placeText(entry.item.place or 3))
				letter.TextXAlignment = Enum.TextXAlignment.Center
				letter.TextScaled = true
			end
		end
	end

	------------------------------------------------------------------ the entries
	local function entries(): { Entry }
		local list: { Entry } = {}
		local gear = gearView
		if gear then
			local owned: { [string]: boolean } = {}
			for _, id in ipairs(gear.owned) do
				owned[id] = true
			end
			for id, piece in pairs(gear.pieces) do
				local rarity = GearStats.rarity(piece.rarity)
				if rarity then
					table.insert(list, { key = "piece:" .. id, category = "GEAR", slot = piece.slot, name = GearStats.pieceName(piece),
						colour = rarity.colour, qty = 1, piece = piece, pieceId = id, rank = 1000 + GearStats.rank(piece.rarity) * 10 })
				end
			end
			for _, item in ipairs(ShopConfig.Items) do
				if owned[item.id] then
					local slotId: string? = nil
					for _, slot in ipairs(WornGearConfig.Slots) do
						if slot.category == item.category then
							slotId = slot.id
						end
					end
					table.insert(list, { key = "shop:" .. item.id, category = "GEAR", slot = slotId, name = string.upper(item.name),
						colour = C.white, qty = 1, shop = item, rank = 500 })
				end
			end
		end
		for id, item in pairs(if itemsView then itemsView.items else {}) do
			if item.type == "Food" then
				local meal = item.food == "Meal"
				table.insert(list, { key = "item:" .. id, category = "FOOD", name = string.format("%d %s", item.count or 0,
					if meal then (if item.count == 1 then "MEET MEAL" else "MEET MEALS") else (if item.count == 1 then "STEAK" else "STEAKS")), colour = FOOD_COLOUR, qty = item.qty, item = item, itemId = id,
					rank = 2000 + (item.count or 0) })
			elseif item.type == "Medal" or item.type == "Trophy" then
				local place = item.place or 3
				table.insert(list, { key = "item:" .. id, category = "TROPHIES", name = string.format("%s %s %s", string.upper(item.level or ""),
					placeText(place), string.upper(item.type)), colour = AWARD_COLOURS[place] or C.white, qty = item.qty, item = item,
					itemId = id, rank = 3000 + (4 - place) * 10 + (if item.type == "Trophy" then 100 else 0) })
			else
				table.insert(list, { key = "item:" .. id, category = "MISC", name = string.upper(item.type), colour = C.white, qty = item.qty,
					item = item, itemId = id, rank = 0 })
			end
		end
		table.sort(list, function(a, b)
			if a.rank ~= b.rank then
				return a.rank > b.rank
			end
			return a.key < b.key
		end)
		return list
	end

	local function find(key: string?): Entry?
		if key == nil then
			return nil
		end
		for _, entry in ipairs(entries()) do
			if entry.key == key then
				return entry
			end
		end
		return nil
	end

	------------------------------------------------------------------ asking the server
	local refreshAll: () -> ()

	local function say(text: string, good: boolean?)
		status.TextColor3 = if good == true then C.yellow elseif good == false then C.red else C.muted
		status.Text = text
	end

	local function askGear(remote: RemoteFunction, ...: any)
		if asking then
			return
		end
		asking = true
		say("Changing...")
		local args = table.pack(...)
		local ok, done, message, newView = pcall(function()
			return remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
		asking = false
		if ok then
			say(if typeof(message) == "string" then message else "", done == true)
			if typeof(newView) == "table" then
				gearView = newView
				refreshAll()
			end
		else
			say("That didn't go through. Try again.", false)
		end
	end

	local function askClothes(remote: RemoteFunction, ...: any)
		if asking then
			return
		end
		asking = true
		local args = table.pack(...)
		local ok, done, message, newView = pcall(function()
			return remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
		asking = false
		if ok then
			say(if typeof(message) == "string" then message else "", done == true)
			if typeof(newView) == "table" then
				clothesView = newView
				refreshAll()
			end
		end
	end

	local function eat(itemId: string)
		if asking then
			return
		end
		asking = true
		local ok, answer = pcall(function()
			return itemRemotes.use:InvokeServer(itemId)
		end)
		asking = false
		if ok and typeof(answer) == "table" then
			if typeof(answer.view) == "table" then
				itemsView = answer.view
			end
			if typeof(answer.kitchen) == "table" then
				BoostBar.show(answer.kitchen)
			end
			if answer.outcome == "Eaten" and typeof(answer.percent) == "number" then
				local left = if typeof(answer.kitchen) == "table"
					then (if answer.kind == "Meal" then answer.kitchen.mealLeft else answer.kitchen.boostLeft) else nil
				BoostBar.celebrate(string.format("%s %s FOR %s", KitchenConfig.percentText(answer.percent),
					if answer.kind == "Meal" then "MEETS" else "TRAINING", if typeof(left) == "number" then KitchenConfig.clockText(left) else ""),
					if answer.kind == "Meal" then "MEAL EATEN!" else "STEAK EATEN!")
				say("Eaten! The boost is on.", true)
			else
				say("That didn't go through. Try again.", false)
			end
			refreshAll()
		end
	end

	------------------------------------------------------------------ drawing
	local function showDescription(entry: Entry?)
		for _, child in ipairs(descPreview:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		primary.Visible, secondary.Visible = false, false
		primaryAction, secondaryAction = nil, nil
		holdButton.Visible = entry ~= nil
		holdKey = if entry then entry.key else nil
		if entry then
			local holding = player:GetAttribute("HeldItem") == entry.key
			holdButton.Text = if holding then "PUT AWAY" else "HOLD"
			holdButton.BackgroundColor3 = if holding then C.yellow else C.navy
			holdButton.TextColor3 = if holding then C.ink else C.white
		end
		if entry == nil then
			descName.Text, descSub.Text = "", ""
			descBody.Text = "Pick an item to see it here."
			descPreviewEdge.Color = C.white
			return
		end
		descPreviewEdge.Color = entry.colour
		previewFor(descPreview, entry)
		descName.Text = entry.name .. (if entry.qty > 1 then string.format("  x%d", entry.qty) else "")
		descName.TextColor3 = entry.colour
		local gear = gearView
		if entry.piece and entry.pieceId and gear then
			local piece = entry.piece
			local rarity = GearStats.rarity(piece.rarity)
			local slotLabel = ""
			for _, slot in ipairs(WornGearConfig.Slots) do
				if slot.id == piece.slot then
					slotLabel = slot.label
				end
			end
			descSub.Text = string.format("%s  ·  %s", string.upper(piece.rarity), slotLabel)
			descBody.Text = GearStats.statText(piece.rarity) .. "\n" .. GearStats.liftsText(piece.slot)
			local isWorn = gear.wearingPieces[piece.slot] == entry.pieceId
			local test = gear.suitTests[piece.rarity]
			local locked = GearStats.suit(piece.rarity) ~= nil and not (test and test.passed)
			primary.Visible = true
			if isWorn then
				primary.Text, primary.BackgroundColor3 = "WORN", C.empty
			elseif locked and test and test.waitSeconds > 0 then
				primary.Text, primary.BackgroundColor3 = GearStats.waitText(test.waitSeconds), C.empty
			elseif locked then
				primary.Text, primary.BackgroundColor3 = "TEST", C.yellow
				primaryAction = function()
					askGear(gearRemotes.startTest, entry.pieceId)
					holder.Visible = false
				end
			else
				primary.Text, primary.BackgroundColor3 = "WEAR", C.yellow
				primaryAction = function()
					askGear(gearRemotes.setPiece, entry.pieceId)
				end
			end
			if not isWorn and rarity then
				secondary.Visible = true
				secondary.Text = "SCRAP +" .. rarity.scrap
				local sureUntil = 0
				secondaryAction = function()
					if os.clock() >= sureUntil then
						sureUntil = os.clock() + CONFIRM_SECONDS
						secondary.Text = "SURE? +" .. rarity.scrap
						task.delay(CONFIRM_SECONDS + 0.05, function()
							if os.clock() >= sureUntil and secondary.Parent then
								secondary.Text = "SCRAP +" .. rarity.scrap
							end
						end)
						return
					end
					askGear(gearRemotes.scrap, entry.pieceId)
					selectedKey = nil
				end
			end
		elseif entry.shop and gear then
			local item = entry.shop
			descSub.Text = string.format("COSMETIC  ·  %s", item.category)
			descBody.Text = "Looks only. Gear from crates has stats."
			local isWorn = entry.slot ~= nil and gear.wearing[entry.slot :: string] == item.id and gear.wearingPieces[entry.slot :: string] == nil
			primary.Visible = true
			if isWorn then
				primary.Text, primary.BackgroundColor3 = "WORN", C.empty
				secondary.Visible = true
				secondary.Text = "TAKE OFF"
				secondaryAction = function()
					askGear(gearRemotes.set, entry.slot, false)
				end
			else
				primary.Text, primary.BackgroundColor3 = "WEAR", C.yellow
				primaryAction = function()
					askGear(gearRemotes.set, entry.slot, item.id)
				end
			end
		elseif entry.item and entry.item.type == "Food" and entry.itemId then
			local item = entry.item
			local meal = item.food == "Meal"
			local percent = KitchenConfig.boostPercent(item.count or 0, item.food)
			descSub.Text = string.format("%s %s  ·  %s", KitchenConfig.percentText(percent), if meal then "MEET GAINS" else "TRAINING GAINS",
				KitchenConfig.hoursText(item.hours or KitchenConfig.BoostHours))
			descBody.Text = if meal then "Eat it and every meet you finish makes you stronger while it lasts."
				else "Eat it and your training gains more strength and technique while it lasts."
			descBody.Text ..= " The same food again adds its hours (up to 24)."
			primary.Visible = true
			primary.Text, primary.BackgroundColor3 = "EAT", Color3.fromRGB(120, 230, 90)
			primaryAction = function()
				eat(entry.itemId :: string)
			end
		elseif entry.item then
			local item = entry.item
			descSub.Text = string.format("%d WON", item.qty or 1)
			descBody.Text = (if item.type == "Trophy" then "Won on the podium at a Regional, State or National meet."
				else "Won on a Local meet podium.") .. " HOLD it and everyone nearby sees how many you've won."
		end
	end

	local function paintCategories()
		for name, button in pairs(categoryButtons) do
			local on = name == category
			button.BackgroundColor3 = if on then C.yellow else C.navyDeep
			button.TextColor3 = if on then C.ink else C.white
		end
		local clothes = clothesView
		gearToggle.Text = if clothes and clothes.gearOn then "GEAR: ON" else "GEAR: OFF"
		gearToggle.BackgroundColor3 = if clothes and clothes.gearOn then C.yellow else C.navyDeep
		gearToggle.TextColor3 = if clothes and clothes.gearOn then C.ink else C.white
	end

	local function drawSlots()
		local gear = gearView
		for _, slot in ipairs(WornGearConfig.Slots) do
			local box = slotBoxes[slot.id]
			for _, child in ipairs(box:GetChildren()) do
				if child:IsA("ViewportFrame") then
					child:Destroy()
				end
			end
			local edge = box:FindFirstChildOfClass("UIStroke")
			local pieceId = gear and gear.wearingPieces[slot.id]
			local piece = gear and pieceId and gear.pieces[pieceId]
			local shopId = gear and gear.wearing[slot.id]
			local look = if piece then ShopConfig.find(piece.look) elseif shopId then ShopConfig.find(shopId) else nil
			if look then
				GearPreview.build(box, look, UDim2.fromOffset(3, 3), UDim2.new(1, -6, 1, -6))
			end
			local rarity = piece and GearStats.rarity(piece.rarity)
			if edge then
				edge.Color = if rarity then rarity.colour elseif look then C.white else C.white
				edge.Transparency = if look then 0 else 0.5
				edge.Thickness = if slotFilter == slot.id then 3 else 1.5
			end
		end
	end

	local function drawClothes()
		for _, child in ipairs(clothesList:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local current = clothesView
		if current == nil then
			return
		end
		local owned: { [string]: boolean } = {}
		for _, id in ipairs(current.owned) do
			owned[id] = true
		end
		local y = 0
		for _, kind in ipairs(ClothesConfig.Kinds) do
			local choice = current.outfit[kind]
			local row = make("Frame", { Name = "Row_" .. kind, BackgroundTransparency = 1, Position = UDim2.fromOffset(4, y),
				Size = UDim2.new(1, -12, 0, 112), Parent = clothesList })
			UIStyle.sectionHead(row, "Head", ClothesConfig.KindLabels[kind], UDim2.fromOffset(0, 2), 230, nil, "bar")
			local x = 0
			for _, item in ipairs(ClothesConfig.itemsOf(kind)) do
				if owned[item.id] then
					local on = choice ~= nil and choice.item == item.id
					local button = make("TextButton", { Name = "Item_" .. item.id, Position = UDim2.fromOffset(x, 32), Size = UDim2.fromOffset(150, 30),
						BackgroundColor3 = if on then C.yellow else C.navyDeep, BorderSizePixel = 0, FontFace = UIStyle.heading(), TextSize = SIZES.small,
						TextColor3 = if on then C.ink else C.white, Text = item.label, Parent = row })
					button.Activated:Connect(function()
						task.spawn(askClothes, clothesRemotes.set, kind, item.id, if choice then choice.colour else "Black")
					end)
					x += 158
				end
			end
			for index, colour in ipairs(ClothesConfig.Colours) do
				local swatch = make("TextButton", { Name = "Colour_" .. colour.id, Text = "", AutoButtonColor = true, BorderSizePixel = 0,
					BackgroundColor3 = colour.colour, Position = UDim2.fromOffset((index - 1) * 38 + 2, 72), Size = UDim2.fromOffset(30, 30), Parent = row })
				UIFancy.corner(swatch, UDim.new(1, 0))
				local picked = choice ~= nil and choice.colour == colour.id
				UIStyle.stroke(swatch, if picked then C.yellow else C.white, if picked then 3 else 1, if picked then 0 else 0.6)
				swatch.Activated:Connect(function()
					task.spawn(askClothes, clothesRemotes.set, kind, if choice then choice.item else ClothesConfig.Default[kind].item, colour.id)
				end)
			end
			y += 112
		end
		clothesList.CanvasSize = UDim2.fromOffset(0, y)
	end

	local function drawGrid()
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local shown = 0
		for order, entry in ipairs(entries()) do
			local fits = (category == "ALL" or entry.category == category) and (slotFilter == nil or entry.slot == slotFilter)
			if fits then
				shown += 1
				local selected = entry.key == selectedKey
				local tile = make("TextButton", { Name = entry.key, Text = "", AutoButtonColor = true, BackgroundColor3 = C.navy,
					BorderSizePixel = 0, LayoutOrder = order, Parent = grid })
				UIFancy.corner(tile, UDim.new(0, 8))
				UIStyle.stroke(tile, entry.colour, if selected then 4 else 2, 0)
				make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.navy, C.navyDeep), Parent = tile })
				local art = make("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4),
					Size = UDim2.new(1, -8, 0, TILE_H - 34), Parent = tile })
				previewFor(art, entry)
				local name = UIStyle.text(tile, "Name", UDim2.new(0, 4, 1, -28), UDim2.new(1, -8, 0, 24), SIZES.small, entry.colour, UIStyle.heading())
				name.Text = entry.name
				name.TextScaled = true
				name.TextXAlignment = Enum.TextXAlignment.Center
				if entry.qty > 1 then
					local qty = UIStyle.text(tile, "Qty", UDim2.new(1, -46, 0, 2), UDim2.fromOffset(42, 20), SIZES.small, C.white, UIStyle.heading())
					qty.Text = "x" .. entry.qty
					qty.TextXAlignment = Enum.TextXAlignment.Right
				end
				local gear = gearView
				local worn = gear ~= nil and ((entry.pieceId ~= nil and entry.slot ~= nil and gear.wearingPieces[entry.slot :: string] == entry.pieceId)
					or (entry.shop ~= nil and entry.slot ~= nil and gear.wearing[entry.slot :: string] == entry.shop.id
						and gear.wearingPieces[entry.slot :: string] == nil))
				if worn then
					local badge = UIStyle.text(tile, "Worn", UDim2.fromOffset(6, 2), UDim2.fromOffset(60, 18), SIZES.small, C.yellow, UIStyle.heading())
					badge.Text = "WORN"
				end
				tile.Activated:Connect(function()
					selectedKey = entry.key
					refreshAll()
				end)
			end
		end
		gridHead.Text = (if slotFilter then category .. " · " .. slotFilter else category) .. string.format("  (%d)", shown)
		if shown == 0 then
			local none = UIStyle.text(grid, "None", UDim2.fromOffset(0, 0), UDim2.fromOffset(GRID_W - 20, 60), SIZES.body, C.muted)
			none.Text = if category == "FOOD" then "No food yet. Cook some at W Chews, then ask the chef for it."
				elseif category == "TROPHIES" then "No medals or trophies yet. Finish top 3 at a meet."
				elseif category == "GEAR" then "No gear yet. Open a crate at the Shop."
				else "Nothing here yet."
			none.TextWrapped = true
		end
	end

	refreshAll = function()
		paintCategories()
		local clothes = category == "CLOTHES"
		grid.Visible, gridHead.Visible = not clothes, not clothes
		clothesList.Visible = clothes
		equip.Visible, desc.Visible = not clothes, not clothes
		if clothes then
			drawClothes()
			return
		end
		drawGrid()
		drawSlots()
		showDescription(find(selectedKey))
	end
	InventoryMenu._refreshAll = function()
		refreshAll()
	end

	for name, button in pairs(categoryButtons) do
		button.Activated:Connect(function()
			category, slotFilter = name, nil
			refreshAll()
		end)
	end
	gearToggle.Activated:Connect(function()
		task.spawn(askClothes, clothesRemotes.gear, not (clothesView and clothesView.gearOn))
	end)

	-- (connected down here, not next to the button: it calls `say`, which is defined after the button is made)
	holdButton.Activated:Connect(function()
		local key = holdKey
		if key == nil or asking then
			return
		end
		asking = true
		local ok, holding, message = pcall(function()
			return itemRemotes.hold:InvokeServer(key)
		end)
		asking = false
		if ok then
			say(if typeof(message) == "string" then message else "", holding == true)
			if holding == true then
				holder.Visible = false -- close the screen so the lifter sees what they hold
			end
		end
	end)

	player:GetAttributeChangedSignal("HeldItem"):Connect(function()
		if holder.Visible then
			refreshAll()
		end
	end)
	-- On their turn at a meet nothing is held (the server also puts it away during any lift).
	task.spawn(function()
		while true do
			task.wait(0.5)
			local heldKey = player:GetAttribute("HeldItem")
			if MenuKeys.isOnTurn() and typeof(heldKey) == "string" and heldKey ~= "" then
				pcall(function()
					return itemRemotes.hold:InvokeServer(false)
				end)
			end
		end
	end)

	itemRemotes.changed.OnClientEvent:Connect(function(view: any)
		if typeof(view) == "table" then
			itemsView = view
			if holder.Visible then
				refreshAll()
			end
		end
	end)

	local function open()
		holder.Visible = true
		say("Loading...")
		local okGear, newGear = pcall(function()
			return gearRemotes.get:InvokeServer()
		end)
		local okClothes, newClothes = pcall(function()
			return clothesRemotes.get:InvokeServer()
		end)
		local okItems, newItems = pcall(function()
			return itemRemotes.get:InvokeServer()
		end)
		if okGear and newGear then
			gearView = newGear
		end
		if okClothes and newClothes then
			clothesView = newClothes
		end
		if okItems and newItems then
			itemsView = newItems
		end
		say(if okGear then "" else "Your gear didn't load. Close and try again.", if okGear then nil else false)
		refreshAll()
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
		if MenuKeys.allowed(gameProcessed) and input.KeyCode == WornGearConfig.OpenKey then
			toggle()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- (set by start: redraws everything; the equipment slots call it)
InventoryMenu._refreshAll = function() end

return InventoryMenu
