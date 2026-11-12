--!strict
--[[
	EmoteWheel
	Client / UI

	The emote wheel (EmoteConfig; user 2026-11-11: "Emote wheel on a key", 8 gym emotes, collected), and the pages for
	everything else you collect (LoadoutConfig; user 2026-11-12: "In the "emotes" section, add a Arrow, and a indicator
	that tells users that they can switch between emotes, Entrances, celebrations etc. And they can collect them. Give the
	user 3 slots ... 1st attempt celebration, 2nd attempt celebration 3rd attempt. Do the same for walk outs").

	B (or the EMOTES tab on the left edge, for phones) opens it, styled like the spin screen (the user's UI kit: chunky
	gradient fills, a shine, outlined Fredoka text, UIShadow glows):

		page chips   EMOTES · WALK-OUTS · CELEBRATIONS · FAILS across the top, the open one gold (click one to go there),
		             and under them the hint: switch pages with the arrows, collect them all at Hype Man
		arrows       big gold < and > either side of the wheel, gently pulsing so they're noticed
		EMOTES       the ring of eight round buttons: the ones you have in their rarity's colour, the others dark and
		             locked ("win it at Hype Man"). Pick one and your character does it for everyone; walking ends it.
		the others   three slot circles over the hub, 1ST / 2ND / 3RD ATTEMPT, each showing what is in it; under the hub
		             your collection (the ones you have lit, the rest dark and locked, how many you have in the hub).
		             Click a slot, then one you have: it goes in that slot. WATCH shows them all (CelebrationViewer).

	It only asks: the server checks the emote is yours (EmoteRemotes.PlayEmote) and that you own what goes in a slot
	(CelebrationRemotes SetLoadoutSlot). It also plays every emote's sound, locked to the animation, for whoever does one
	nearby (client CelebrationFx). Sounds: a tick on every page or slot click, a drop when a slot is filled.
	PERFORMANCE: nothing runs while the wheel is closed but one key listener; the arrows' pulse runs only while open.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local EmoteConfig = require(ConfigFolder:WaitForChild("EmoteConfig"))
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local LoadoutConfig = require(ConfigFolder:WaitForChild("LoadoutConfig"))
local EmoteRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("EmoteRemotes"))
local CelebrationRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("CelebrationRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local MenuKeys = require(script.Parent:WaitForChild("MenuKeys"))
local CelebrationViewer = require(script.Parent:WaitForChild("CelebrationViewer"))
local CelebrationFx = require(script.Parent.Parent:WaitForChild("Meet"):WaitForChild("CelebrationFx"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local EmoteWheel = {}

-- Under the GEAR tab (each tab sits 72 px under the one above).
local TAB_OFFSET_Y = 216
local RADIUS = 170
local SLOT = 118
local HUB = 150
-- The collection under the hub: round cells, five a row, two rows showing (it scrolls).
local CELL = 100
local CELL_GAP = 10
local GRID_COLUMNS = 5
local GRID_TOP = HUB / 2 + 22
local GRID_HEIGHT = 2 * CELL + CELL_GAP + 6
-- The arrows, either side of the wheel.
local ARROW = 72
local ARROW_X = RADIUS + SLOT / 2 + 66
-- The page chips and the hint over the wheel.
local CHIP_Y = -(RADIUS + SLOT / 2 + 74)
local HINT_Y = -(RADIUS + SLOT / 2 + 40)
-- Everything the wheel draws, chips to collection, so it can shrink to fit a small screen (its pop-in UIScale is the
-- one Roblox uses, so UIStyle.fitToScreen's can't do it).
local CONTENT_WIDTH = 690
local CONTENT_HEIGHT = 660
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(12, 12, 16)
local FREE_COLOUR = Color3.fromRGB(150, 196, 255)
local GOLD_TOP = Color3.fromRGB(255, 226, 92)
local GOLD_BOTTOM = Color3.fromRGB(232, 150, 20)
local LOCKED_TOP = Color3.fromRGB(64, 70, 86)
local LOCKED_BOTTOM = Color3.fromRGB(30, 33, 44)
local BAD = Color3.fromRGB(255, 120, 120)
local TITLE_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

type SlotButton = { button: TextButton, fill: UIGradient, label: TextLabel, sub: TextLabel, badge: Frame,
	badgeFill: UIGradient, ring: UIStroke, glow: UIShadow, pop: UIScale }
type Cell = { button: TextButton, fill: UIGradient, label: TextLabel, sub: TextLabel, item: LoadoutConfig.Item }

local started = false
local remotes: EmoteRemotes.RemoteSet? = nil
local spinRemotes: CelebrationRemotes.SpinRemotes? = nil
local wheel: Frame? = nil
local hubTitle: TextLabel? = nil
local hubText: TextLabel? = nil
local emotePage: Frame? = nil
local loadoutPage: Frame? = nil
local grid: ScrollingFrame? = nil
local chips: { [string]: { fill: UIGradient, label: TextLabel } } = {}
local arrowPulses: { Tween } = {}
local sounds: { [string]: Sound } = {}
local emoteSlots: { [string]: { fill: UIGradient, label: TextLabel, lock: TextLabel, button: TextButton } } = {}
local slotButtons: { SlotButton } = {}
local cells: { Cell } = {}
local owned: { [string]: boolean } = {}
-- What the server last said they own and have in their slots (LoadoutConfig.Kinds), and the page and slot open.
local ownedLoadout: { [string]: { [string]: boolean } } = {}
local slotIds: { [string]: { string } } = {}
local page = "Emote"
local selectedSlot = 1
local asking = false

for _, kind in ipairs(LoadoutConfig.Kinds) do
	ownedLoadout[kind] = { [LoadoutConfig.defaultOf(kind)] = true }
	local default = LoadoutConfig.defaultOf(kind)
	slotIds[kind] = { default, default, default }
end

local function rarityColour(rarity: string): Color3
	for _, entry in ipairs(GearStatsConfig.Rarities) do
		if entry.id == rarity then
			return entry.colour
		end
	end
	return FREE_COLOUR
end

local function itemOf(kind: string, id: string): LoadoutConfig.Item?
	for _, item in ipairs(LoadoutConfig.items(kind)) do
		if item.id == id then
			return item
		end
	end
	return nil
end

local function play(name: string)
	local sound = sounds[name]
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

local function outlined(parent: Instance, name: string, text: string, size: number, position: UDim2, frameSize: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = frameSize
	label.FontFace = TITLE_FONT
	label.TextSize = size
	label.TextColor3 = WHITE
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = INK
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return label
end

local function round(target: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = target
end

-- A round, chunky button in the kit's style: a gradient fill, a thick dark outline and a soft shine over the top half.
local function roundButton(parent: Instance, name: string, size: number, position: UDim2): (TextButton, UIGradient, UIStroke)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = WHITE
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	round(button)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = INK
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Parent = button
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = WHITE
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(0.12, 0.06)
	shine.Size = UDim2.fromScale(0.76, 0.42)
	shine.Parent = button
	round(shine)
	local shineFade = Instance.new("UIGradient")
	shineFade.Rotation = 90
	shineFade.Transparency = NumberSequence.new(0.55, 1)
	shineFade.Parent = shine
	return button, fill, stroke
end

-- Grows a little under the pointer.
local function hoverPop(button: GuiObject, onEnter: (() -> ())?): UIScale
	local pop = Instance.new("UIScale")
	pop.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(pop, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
		if onEnter then
			onEnter()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(pop, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	return pop
end

local function lit(fill: UIGradient, colour: Color3)
	fill.Color = ColorSequence.new(colour:Lerp(WHITE, 0.35), colour:Lerp(INK, 0.15))
end

local function setHub(text: string, colour: Color3?)
	local label = hubText
	if label then
		label.Text = text
		label.TextColor3 = colour or WHITE
	end
end

local function countOwned(kind: string): (number, number)
	local have, total = 0, 0
	for _, item in ipairs(LoadoutConfig.items(kind)) do
		total += 1
		if ownedLoadout[kind][item.id] then
			have += 1
		end
	end
	return have, total
end

-- What the hub says on a slot page when nothing is pointed at.
local function hubForPage()
	if page == "Emote" then
		local have = 0
		for _, emote in ipairs(EmoteConfig.List) do
			if owned[emote.id] then
				have += 1
			end
		end
		setHub(string.format("%d / %d collected\nPick one", have, #EmoteConfig.List))
		return
	end
	local have, total = countOwned(page)
	local item = itemOf(page, slotIds[page][selectedSlot])
	setHub(string.format("%d / %d collected\n%s:\n%s", have, total, LoadoutConfig.SlotNames[selectedSlot],
		if item then item.name else "?"))
end

-- Lights the emotes you have, darkens the others.
local function refreshEmotes()
	for id, slot in pairs(emoteSlots) do
		local emote = EmoteConfig.byId[id]
		local have = owned[id] == true
		if have then
			lit(slot.fill, rarityColour(emote.rarity))
		else
			slot.fill.Color = ColorSequence.new(LOCKED_TOP, LOCKED_BOTTOM)
		end
		slot.label.TextTransparency = if have then 0 else 0.35
		slot.lock.Visible = not have
	end
end

-- Draws the three slots and the collection of the open page.
local function refreshLoadout()
	if page == "Emote" then
		return
	end
	for index, slot in ipairs(slotButtons) do
		local item = itemOf(page, slotIds[page][index])
		lit(slot.fill, rarityColour(if item then item.rarity else "Default"))
		slot.label.Text = if item then item.name else "?"
		slot.sub.Text = if item then string.upper(item.rarity) else ""
		local chosen = index == selectedSlot
		slot.badgeFill.Color = if chosen then ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
			else ColorSequence.new(Color3.fromRGB(70, 78, 96), Color3.fromRGB(34, 38, 50))
		slot.ring.Color = if chosen then GOLD_TOP else INK
		slot.ring.Thickness = if chosen then 5 else 3
		slot.glow.Enabled = chosen
	end
	-- The collection: the ones you have first, then the locked ones (each in rarity order).
	local list = grid
	if list == nil then
		return
	end
	for _, cell in ipairs(cells) do
		cell.button:Destroy()
	end
	table.clear(cells)
	local items = LoadoutConfig.items(page)
	local order = 0
	for pass = 1, 2 do
		for _, item in ipairs(items) do
			local have = ownedLoadout[page][item.id] == true
			if (pass == 1) == have then
				order += 1
				local button, fill = roundButton(list, item.id, CELL, UDim2.new())
				-- (The grid places it: no centring anchor.)
				button.AnchorPoint = Vector2.zero
				button.LayoutOrder = order
				local label = outlined(button, "Label", string.upper(item.name), 14, UDim2.fromOffset(6, 22),
					UDim2.new(1, -12, 0, 44))
				label.ZIndex = 2
				label.TextTransparency = if have then 0 else 0.35
				local sub = outlined(button, "Sub", "", 11, UDim2.new(0, 6, 1, -30), UDim2.new(1, -12, 0, 14))
				sub.ZIndex = 2
				if have then
					lit(fill, rarityColour(item.rarity))
					local inSlots = {}
					for index, id in ipairs(slotIds[page]) do
						if id == item.id then
							table.insert(inSlots, ({ "1ST", "2ND", "3RD" })[index])
						end
					end
					sub.Text = if #inSlots > 0 then "ON " .. table.concat(inSlots, " ") else ""
					sub.TextColor3 = GOLD_TOP
				else
					fill.Color = ColorSequence.new(LOCKED_TOP, LOCKED_BOTTOM)
					sub.Text = "LOCKED"
					sub.TextColor3 = Color3.fromRGB(200, 200, 210)
				end
				hoverPop(button, function()
					if have then
						setHub(string.format("%s\nput it on your\n%s", string.upper(item.name), LoadoutConfig.SlotNames[selectedSlot]),
							rarityColour(item.rarity))
					else
						setHub(string.format("%s\n%s\nwin it at Hype Man", string.upper(item.name), string.upper(item.rarity)),
							rarityColour(item.rarity))
					end
				end)
				button.MouseLeave:Connect(hubForPage)
				local kind = page
				button.Activated:Connect(function()
					task.spawn(EmoteWheel.equip, kind, item.id)
				end)
				table.insert(cells, { button = button, fill = fill, label = label, sub = sub, item = item })
			end
		end
	end
end

-- Takes the server's view of what they own and have in their slots.
local function takeView(view: any)
	if typeof(view) ~= "table" then
		return
	end
	if typeof(view.emotes) == "table" then
		table.clear(owned)
		for _, id in ipairs(view.emotes) do
			owned[id] = true
		end
	end
	for _, kind in ipairs(LoadoutConfig.Kinds) do
		local list = if typeof(view.owned) == "table" then view.owned[kind] else nil
		if typeof(list) == "table" then
			local set = { [LoadoutConfig.defaultOf(kind)] = true }
			for _, id in ipairs(list) do
				set[id] = true
			end
			ownedLoadout[kind] = set
		end
		local slots = if typeof(view.slots) == "table" then view.slots[kind] else nil
		if typeof(slots) == "table" then
			for index = 1, LoadoutConfig.Slots do
				local id = slots[index]
				slotIds[kind][index] = if typeof(id) == "string" then id else LoadoutConfig.defaultOf(kind)
			end
		end
	end
end

local function close()
	local frame = wheel
	if frame and frame.Visible then
		frame.Visible = false
	end
	for _, pulse in ipairs(arrowPulses) do
		pulse:Pause()
	end
end

-- Shows a page: the ring of emotes, or a kind's three slots and collection.
local function showPage(newPage: string)
	page = newPage
	for name, chip in pairs(chips) do
		local on = name == newPage
		chip.fill.Color = if on then ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
			else ColorSequence.new(Color3.fromRGB(70, 78, 96), Color3.fromRGB(34, 38, 50))
		chip.label.TextTransparency = if on then 0 else 0.3
	end
	if hubTitle then
		hubTitle.Text = LoadoutConfig.Titles[newPage]
	end
	if emotePage then
		emotePage.Visible = newPage == "Emote"
	end
	if loadoutPage then
		loadoutPage.Visible = newPage ~= "Emote"
	end
	if newPage == "Emote" then
		refreshEmotes()
	else
		if grid then
			grid.CanvasPosition = Vector2.zero
		end
		refreshLoadout()
	end
	hubForPage()
end

local function turnPage(step: number)
	local index = table.find(LoadoutConfig.Pages, page) or 1
	local count = #LoadoutConfig.Pages
	play("Tick")
	showPage(LoadoutConfig.Pages[(index - 1 + step) % count + 1])
end

local function playEmote(id: string)
	local set = remotes
	if set == nil or asking then
		return
	end
	if not owned[id] then
		local emote = EmoteConfig.byId[id]
		setHub(string.format("%s\nwin it at Hype Man", string.upper(emote.name)), rarityColour(emote.rarity))
		return
	end
	asking = true
	local ok, done, message = pcall(function()
		return set.play:InvokeServer(id)
	end)
	asking = false
	if ok and done then
		close()
	else
		setHub(if ok and typeof(message) == "string" then message else "Try again.", BAD)
	end
end

-- Puts one they own in the chosen slot of `kind` (the server checks they own it).
function EmoteWheel.equip(kind: string, id: string)
	local set = spinRemotes
	if set == nil or asking or kind ~= page then
		return
	end
	if not ownedLoadout[kind][id] then
		play("Tick")
		return
	end
	local slot = selectedSlot
	if slotIds[kind][slot] == id then
		hubForPage()
		return
	end
	asking = true
	local ok, done, message, view = pcall(function()
		return set.setSlot:InvokeServer(kind, slot, id)
	end)
	asking = false
	if ok and done then
		takeView(view)
		slotIds[kind][slot] = id
		play("Drop")
		if page == kind then
			refreshLoadout()
			hubForPage()
			local button = slotButtons[slot]
			if button then
				button.pop.Scale = 1.25
				TweenService:Create(button.pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end
	else
		setHub(if ok and typeof(message) == "string" then message else "Try again.", BAD)
	end
end

local function build(): (ScreenGui, Frame)
	local screen = Instance.new("ScreenGui")
	screen.Name = "EmoteWheel"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 6
	UIStyle.fitToScreen(screen)

	for name, id in pairs({ Tick = GearStatsConfig.Sounds.Tick, Drop = GearStatsConfig.Sounds.Drop }) do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Volume = if name == "Tick" then 0.5 else 0.7
		sound.Parent = screen
		sounds[name] = sound
	end

	-- The EMOTES tab on the left edge (as GEAR's).
	local tab = Instance.new("TextButton")
	tab.Name = "Tab"
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Position = UDim2.new(0, 0, 0.5, TAB_OFFSET_Y)
	tab.Size = UDim2.fromOffset(150, 44)
	tab.BackgroundColor3 = C.ink
	tab.BorderSizePixel = 0
	tab.AutoButtonColor = true
	tab.Text = ""
	tab.Parent = screen
	UIStyle.stroke(tab, C.yellow, 2)
	local tabText = UIStyle.text(tab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -40, 1, 0), SIZES.body, C.white, UIStyle.heading())
	tabText.Text = "EMOTES"
	UIStyle.cue(tab, "star", UDim2.new(1, -30, 0, 10), 24)
	local keyHint = UIStyle.text(tab, "Key", UDim2.new(0, 10, 1, 2), UDim2.fromOffset(100, 16), SIZES.small, C.muted)
	keyHint.Text = "[" .. EmoteConfig.WheelKey.Name .. "]"
	keyHint.Visible = not UIStyle.isTouchOnly()
	tab.Activated:Connect(function()
		EmoteWheel.toggle()
	end)

	-- The wheel: a hub with the pages around it.
	local frame = Instance.new("Frame")
	frame.Name = "Wheel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(2 * RADIUS + SLOT + 20, 2 * RADIUS + SLOT + 20)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = screen
	local scale = Instance.new("UIScale")
	scale.Name = "Pop"
	scale.Parent = frame

	-- The page chips: which pages there are, the open one gold (the indicator), each one clickable.
	local chipRow = Instance.new("Frame")
	chipRow.Name = "Pages"
	chipRow.AnchorPoint = Vector2.new(0.5, 0.5)
	chipRow.Position = UDim2.new(0.5, 0, 0.5, CHIP_Y)
	chipRow.Size = UDim2.fromOffset(4 * 142 + 3 * 8, 38)
	chipRow.BackgroundTransparency = 1
	chipRow.Parent = frame
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	chipLayout.Padding = UDim.new(0, 8)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chipRow
	for index, name in ipairs(LoadoutConfig.Pages) do
		local chip = Instance.new("TextButton")
		chip.Name = name
		chip.LayoutOrder = index
		chip.Size = UDim2.fromOffset(142, 38)
		chip.BackgroundColor3 = WHITE
		chip.AutoButtonColor = false
		chip.Text = ""
		chip.Parent = chipRow
		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 12)
		chipCorner.Parent = chip
		local chipStroke = Instance.new("UIStroke")
		chipStroke.Thickness = 3
		chipStroke.Color = INK
		chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		chipStroke.Parent = chip
		local chipFill = Instance.new("UIGradient")
		chipFill.Rotation = 90
		chipFill.Parent = chip
		local chipLabel = outlined(chip, "Label", LoadoutConfig.Titles[name], 16, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		hoverPop(chip)
		chip.Activated:Connect(function()
			if page ~= name then
				play("Tick")
				showPage(name)
			end
		end)
		chips[name] = { fill = chipFill, label = chipLabel }
	end
	local hint = outlined(frame, "Hint", "< >  switch pages  ·  collect them all at Hype Man", 15,
		UDim2.new(0, -60, 0.5, HINT_Y - 10), UDim2.new(1, 120, 0, 20))
	hint.TextColor3 = GOLD_TOP

	-- The arrows either side, gently pulsing while the wheel is open.
	for _, side in ipairs({ -1, 1 }) do
		local arrow, arrowFill = roundButton(frame, if side < 0 then "PreviousPage" else "NextPage", ARROW,
			UDim2.new(0.5, side * ARROW_X, 0.5, 0))
		arrowFill.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
		local glow = Instance.new("UIShadow")
		glow.Color = GOLD_TOP
		glow.BlurRadius = UDim.new(0, 24)
		glow.Transparency = 0.5
		glow.Parent = arrow
		local glyph = outlined(arrow, "Glyph", if side < 0 then "<" else ">", 44, UDim2.fromOffset(0, -2), UDim2.fromScale(1, 1))
		glyph.ZIndex = 2
		local pop = hoverPop(arrow)
		table.insert(arrowPulses, TweenService:Create(glyph, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromOffset(side * 5, -2) }))
		arrow.Activated:Connect(function()
			pop.Scale = 0.9
			TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			turnPage(side)
		end)
	end

	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(HUB, HUB)
	hub.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
	hub.BackgroundTransparency = 0.1
	hub.ZIndex = 3
	hub.Parent = frame
	round(hub)
	local hubStroke = Instance.new("UIStroke")
	hubStroke.Thickness = 3
	hubStroke.Color = INK
	hubStroke.Parent = hub
	local glow = Instance.new("UIShadow")
	glow.Color = Color3.fromRGB(250, 206, 36)
	glow.BlurRadius = UDim.new(0, 40)
	glow.Transparency = 0.55
	glow.Parent = hub
	local title = outlined(hub, "Title", "EMOTES", 22, UDim2.fromOffset(10, 18), UDim2.new(1, -20, 0, 28))
	title.TextScaled = true
	title.ZIndex = 3
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 22
	titleSize.Parent = title
	hubTitle = title
	local text = outlined(hub, "Text", "Pick one", 13, UDim2.fromOffset(12, 50), UDim2.new(1, -24, 0, 84))
	text.ZIndex = 3
	hubText = text

	-- EMOTES: the ring of eight.
	local emotes = Instance.new("Frame")
	emotes.Name = "EmotePage"
	emotes.BackgroundTransparency = 1
	emotes.Size = UDim2.fromScale(1, 1)
	emotes.Parent = frame
	emotePage = emotes
	for index, emote in ipairs(EmoteConfig.List) do
		local angle = math.rad(-90 + (index - 1) * 360 / #EmoteConfig.List)
		local button, fill = roundButton(emotes, emote.id, SLOT,
			UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS))
		local label = outlined(button, "Label", string.upper(emote.name), 17, UDim2.fromOffset(8, 28), UDim2.new(1, -16, 0, 50))
		label.ZIndex = 2
		local lock = outlined(button, "Lock", "LOCKED", 12, UDim2.new(0, 8, 1, -34), UDim2.new(1, -16, 0, 16))
		lock.ZIndex = 2
		lock.TextColor3 = Color3.fromRGB(200, 200, 210)
		hoverPop(button, function()
			setHub(string.upper(emote.name) .. (if owned[emote.id] then "" else "\nwin it at Hype Man"), rarityColour(emote.rarity))
		end)
		button.Activated:Connect(function()
			task.spawn(playEmote, emote.id)
		end)
		emoteSlots[emote.id] = { fill = fill, label = label, lock = lock, button = button }
	end

	-- WALK-OUTS / CELEBRATIONS / FAILS: three slots over the hub, the collection under it.
	local loadout = Instance.new("Frame")
	loadout.Name = "LoadoutPage"
	loadout.BackgroundTransparency = 1
	loadout.Size = UDim2.fromScale(1, 1)
	loadout.Visible = false
	loadout.Parent = frame
	loadoutPage = loadout
	for index = 1, LoadoutConfig.Slots do
		local angle = math.rad(-90 + (index - 2) * 60)
		local button, fill, ring = roundButton(loadout, "Slot" .. index, SLOT,
			UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS))
		local slotGlow = Instance.new("UIShadow")
		slotGlow.Color = GOLD_TOP
		slotGlow.BlurRadius = UDim.new(0, 30)
		slotGlow.Transparency = 0.35
		slotGlow.Enabled = false
		slotGlow.Parent = button
		local label = outlined(button, "Label", "", 16, UDim2.fromOffset(8, 30), UDim2.new(1, -16, 0, 48))
		label.ZIndex = 2
		local sub = outlined(button, "Sub", "", 11, UDim2.new(0, 8, 1, -30), UDim2.new(1, -16, 0, 14))
		sub.ZIndex = 2
		-- The attempt's badge on top of the circle.
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.5, 0, 0, 2)
		badge.Size = UDim2.fromOffset(104, 26)
		badge.BackgroundColor3 = WHITE
		badge.ZIndex = 3
		badge.Parent = button
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 9)
		badgeCorner.Parent = badge
		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Thickness = 2.5
		badgeStroke.Color = INK
		badgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		badgeStroke.Parent = badge
		local badgeFill = Instance.new("UIGradient")
		badgeFill.Rotation = 90
		badgeFill.Parent = badge
		local badgeText = outlined(badge, "Text", LoadoutConfig.SlotNames[index], 13, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		badgeText.ZIndex = 4
		local pop = hoverPop(button, function()
			local item = itemOf(page, slotIds[page][index])
			setHub(string.format("%s:\n%s\n%s", LoadoutConfig.SlotNames[index], if item then item.name else "?",
				if index == selectedSlot then "pick one below" else "click to change"), GOLD_TOP)
		end)
		button.MouseLeave:Connect(hubForPage)
		button.Activated:Connect(function()
			play("Tick")
			selectedSlot = index
			refreshLoadout()
			setHub(string.format("%s:\nnow pick one below", LoadoutConfig.SlotNames[index]), GOLD_TOP)
		end)
		slotButtons[index] = { button = button, fill = fill, label = label, sub = sub, badge = badge, badgeFill = badgeFill,
			ring = ring, glow = slotGlow, pop = pop }
	end

	local list = Instance.new("ScrollingFrame")
	list.Name = "Collection"
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.Position = UDim2.new(0.5, 0, 0.5, GRID_TOP)
	list.Size = UDim2.fromOffset(GRID_COLUMNS * CELL + (GRID_COLUMNS - 1) * CELL_GAP + 22, GRID_HEIGHT)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = GOLD_TOP
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = loadout
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.Parent = list
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL, CELL)
	layout.CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	grid = list

	-- WATCH: every one of the page's kind, played on your avatar (the spin screen's SEE ALL viewer).
	local watch = Instance.new("TextButton")
	watch.Name = "Watch"
	watch.AnchorPoint = Vector2.new(0.5, 0.5)
	watch.Position = UDim2.new(0.5, RADIUS + 46, 0.5, GRID_TOP - 30)
	watch.Size = UDim2.fromOffset(112, 34)
	watch.BackgroundColor3 = WHITE
	watch.AutoButtonColor = false
	watch.Text = ""
	watch.Parent = loadout
	local watchCorner = Instance.new("UICorner")
	watchCorner.CornerRadius = UDim.new(0, 12)
	watchCorner.Parent = watch
	local watchStroke = Instance.new("UIStroke")
	watchStroke.Thickness = 3
	watchStroke.Color = INK
	watchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	watchStroke.Parent = watch
	local watchFill = Instance.new("UIGradient")
	watchFill.Rotation = 90
	watchFill.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(40, 130, 220))
	watchFill.Parent = watch
	outlined(watch, "Label", "WATCH", 17, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	hoverPop(watch)
	watch.Activated:Connect(function()
		local kind = page
		play("Tick")
		close()
		CelebrationViewer.open(false, function()
			EmoteWheel.open(kind)
		end, kind)
	end)

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen, frame
end

function EmoteWheel.isOpen(): boolean
	local frame = wheel
	return frame ~= nil and frame.Visible
end

-- Opens the wheel on `onPage` (else the page it was left on), asking the server what is theirs.
function EmoteWheel.open(onPage: string?)
	local frame = wheel
	if frame == nil or CelebrationViewer.isOpen() then
		return
	end
	frame.Visible = true
	local pop = frame:FindFirstChild("Pop") :: UIScale
	local screenGui = frame.Parent
	local area = if screenGui and screenGui:IsA("ScreenGui") then screenGui.AbsoluteSize else Vector2.new(1920, 1080)
	local fit = math.min(1, (area.X - 16) / CONTENT_WIDTH, (area.Y - 16) / CONTENT_HEIGHT)
	pop.Scale = 0.85 * fit
	TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
	for _, pulse in ipairs(arrowPulses) do
		pulse:Play()
	end
	showPage(if onPage and table.find(LoadoutConfig.Pages, onPage) then onPage else page)
	task.spawn(function()
		local set = spinRemotes
		if set == nil then
			return
		end
		local ok, view = pcall(function()
			return set.loadout:InvokeServer()
		end)
		if ok and typeof(view) == "table" and EmoteWheel.isOpen() then
			takeView(view)
			showPage(page)
		end
	end)
end

-- Opens the wheel or closes it.
function EmoteWheel.toggle()
	if wheel == nil or remotes == nil then
		return
	end
	if EmoteWheel.isOpen() then
		close()
	else
		EmoteWheel.open()
	end
end

function EmoteWheel.start()
	if started then
		return
	end
	started = true
	remotes = EmoteRemotes.waitForClient(ReplicatedStorage)
	local set = remotes :: EmoteRemotes.RemoteSet
	for id, emote in pairs(EmoteConfig.byId) do
		owned[id] = emote.rarity == "Free"
	end
	local _, frame = build()
	wheel = frame
	-- (The spin's folder holds the slot remotes; the wheel's emote page works before it arrives.)
	task.spawn(function()
		spinRemotes = CelebrationRemotes.waitForSpinClient(ReplicatedStorage)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == EmoteConfig.WheelKey and MenuKeys.allowed(gameProcessed) then
			EmoteWheel.toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			close()
		end
	end)
	-- Every emote's sound, from whoever does it, locked to their animation; it ends when they walk off.
	set.started.OnClientEvent:Connect(function(id: any, startedAt: any, figure: any)
		local emote = if typeof(id) == "string" then EmoteConfig.byId[id] else nil
		if emote and emote.soundtrack and typeof(startedAt) == "number" and typeof(figure) == "Instance" and figure:IsA("Model") then
			CelebrationFx.playLockedSound(figure, emote.animationId, emote.soundtrack, emote.seconds, startedAt, true)
		end
	end)
end

return EmoteWheel
