--!strict
--[[
	CelebrationSpinner
	Client / UI

	The celebration spin screen (CelebrationConfig.Spin, GAME_DESIGN §36.4; user 2026-11-11: "hold e on it, the
	celebrations screen pops up, Make it where its like a rollable thing like the video"). Opens when the player holds E
	on the celebration NPC (the server's OpenSpinner).

	Styled after the user's reference (a style reroll from a boxing game; user 2026-11-11: "Make it like my reference, the
	UI, rarity, color, description, character angle, background"), with the techniques of the user's UI kit
	(RobloxUIReferences/roblox-ui/kit: UIShadow glows, rays, vignette, button shine and gloss):

		the whole card    your own avatar, big and close, seen from a little below, doing your celebration over and over
		                  (CelebrationStage), in front of a dark backdrop lit in the rarity's colour: a soft glow behind
		                  the figure, slowly turning rays and glowing shards drifting around it
		top               CURRENT CELEBRATION:, the name huge in the rarity's colour with a thick dark outline, the
		                  rarity, and what happens in it
		bottom            YOUR COINS bar, a big glossy SPIN button (a green SKIP while the reel runs: the name, colour and
		                  glow flip through the celebrations, slowing down, and land on what the server rolled), the spin
		                  price, the odds
		corners           SEE ALL (every celebration you could land on, CelebrationViewer, then back here), close X
		                  (walking away closes it too)
		tabs              CELEBRATIONS | WALK-OUTS (user 2026-11-11: "Walk-outs at Hype Man", same rules): on WALK-OUTS
		                  the card shows your walk-out (EntranceConfig): your avatar walking up in its style, then its
		                  hype move with its sound, over and over; SPIN rerolls the walk-out you use at meets

	It only asks and shows: the server checks the coins and rolls the result (CelebrationSpinService), before the reel
	starts. Sounds: a tick on every flip, a thud on landing (a bigger hit for Epic and Legendary).
	PERFORMANCE: one avatar copy and one per-frame update for the drifting shards and rays while open; nothing while closed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local CelebrationConfig = require(ConfigFolder:WaitForChild("CelebrationConfig"))
local EntranceConfig = require(ConfigFolder:WaitForChild("EntranceConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local CoinConfig = require(ConfigFolder:WaitForChild("CoinConfig"))
local CelebrationRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("CelebrationRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local CelebrationStage = require(script.Parent:WaitForChild("CelebrationStage"))
local CelebrationViewer = require(script.Parent:WaitForChild("CelebrationViewer"))

local CelebrationSpinner = {}

local SPIN = CelebrationConfig.Spin
local W, H = 520, 740
-- The figure: seen from a little below and to its right, close enough that it fills the card from the head down.
local CAMERA_FROM = Vector3.new(3.4, 2.2, -15.5)
local CAMERA_AT = Vector3.new(0, 3.1, 0)
local CAMERA_FOV = 34
-- Walking further than this from where the screen opened closes it.
local CLOSE_DISTANCE = 16
-- The reel: this many flips, each a little longer than the last, from FIRST to LAST seconds.
local FLIPS = 22
local FIRST_FLIP, LAST_FLIP = 0.05, 0.42
local BIG_FROM = 4 -- Epic and up land with the big hit (GearStatsConfig.Rarities' order)

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(12, 12, 16)
local DEFAULT_COLOUR = Color3.fromRGB(150, 196, 255)
local GOLD_TOP, GOLD_BOTTOM = Color3.fromRGB(246, 240, 128), Color3.fromRGB(186, 190, 62)
local GREEN_TOP, GREEN_BOTTOM = Color3.fromRGB(140, 236, 120), Color3.fromRGB(54, 170, 70)
local PRICE_GREEN = Color3.fromRGB(110, 236, 96)

local TITLE_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local BODY_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)

-- Where each glowing shard drifts around (fraction of the card), its size and how fast it bobs.
local SHARDS = {
	{ 0.16, 0.30, 34, 0.9 }, { 0.84, 0.26, 40, 0.7 }, { 0.10, 0.55, 28, 1.1 }, { 0.90, 0.52, 36, 0.8 },
	{ 0.22, 0.73, 30, 1.0 }, { 0.80, 0.72, 26, 1.2 }, { 0.70, 0.40, 18, 1.4 }, { 0.30, 0.42, 16, 1.3 },
}

type Shard = { frame: Frame, x: number, y: number, speed: number, phase: number }
type Screen = {
	gui: ScreenGui,
	holder: Frame,
	scene: Frame,
	glow: Frame,
	core: Frame,
	rays: Frame,
	shards: { Shard },
	flash: Frame,
	stage: CelebrationStage.Stage,
	heading: TextLabel,
	name: TextLabel,
	nameGlow: TextLabel,
	nameGradient: UIGradient,
	nameScale: UIScale,
	rarity: TextLabel,
	about: TextLabel,
	status: TextLabel,
	coins: TextLabel,
	spinFill: UIGradient,
	spinLabel: TextLabel,
	tabs: { [string]: { fill: UIGradient, label: TextLabel } },
	seeAll: TextButton,
}

-- One thing a spin can land on, whichever kind: what the card shows.
type Item = { id: string, name: string, rarity: string, description: string }

local screen: Screen? = nil
local remotes: CelebrationRemotes.SpinRemotes? = nil
-- The tab open: "Celebration" or "Entrance" (a walk-out); what they have of each.
local kind = "Celebration"
local current: { [string]: string } = { Celebration = CelebrationConfig.Default, Entrance = EntranceConfig.DefaultId }
local coins = 0
local spinning = false
local skip = false
local reelToken = 0
local openedAt: Vector3? = nil
local sounds: { [string]: Sound } = {}
local stepper: RBXScriptConnection? = nil
local raySpeed = 6

local function rarityColour(rarity: string): Color3
	for _, entry in ipairs(GearStatsConfig.Rarities) do
		if entry.id == rarity then
			return entry.colour
		end
	end
	return DEFAULT_COLOUR
end

local function rarityRank(rarity: string): number
	for i, entry in ipairs(GearStatsConfig.Rarities) do
		if entry.id == rarity then
			return i
		end
	end
	return 0
end

-- The card's view of a celebration or a walk-out.
local function itemOf(of: string, id: string): Item?
	if of == "Entrance" then
		local entrance = EntranceConfig.get(id)
		return if entrance then { id = id, name = entrance.name, rarity = entrance.rarity, description = entrance.description }
			else nil
	end
	local celebration = CelebrationConfig.byId[id]
	return if celebration then { id = id, name = celebration.name, rarity = celebration.rarity, description = celebration.description }
		else nil
end

-- What a spin of each kind can land on (never a Default), for the reel.
local POOLS: { [string]: { Item } } = { Celebration = {}, Entrance = {} }
for _, celebration in ipairs(CelebrationConfig.List) do
	if celebration.rarity ~= "Default" then
		table.insert(POOLS.Celebration, itemOf("Celebration", celebration.id) :: Item)
	end
end
for _, id in ipairs(EntranceConfig.Order) do
	if EntranceConfig.Entrances[id].rarity ~= "Default" then
		table.insert(POOLS.Entrance, itemOf("Entrance", id) :: Item)
	end
end
local HEADINGS = { Celebration = "CELEBRATION", Entrance = "WALK-OUT" }

-- The biggest text size (up to NAME_MAX) at which a name fits on one line across the card; remembered per name.
local NAME_MAX, NAME_WIDTH = 72, W - 40
local fitted: { [string]: number } = {}
local function nameSize(text: string): number
	local known = fitted[text]
	if known then
		return known
	end
	local size = NAME_MAX
	local ok = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = TITLE_FONT
		params.Size = NAME_MAX
		params.Width = 100000
		local width = TextService:GetTextBoundsAsync(params).X
		if width > NAME_WIDTH then
			size = math.max(28, math.floor(NAME_MAX * NAME_WIDTH / width))
		end
	end)
	if ok then
		fitted[text] = size
	end
	return size
end

local function play(name: string)
	local sound = sounds[name]
	if sound then
		sound:Play()
	end
end

-- ----------------------------------------------------------------------------- building blocks (UI kit techniques)

local function make(className: string, props: { [string]: any }): any
	local made = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(made :: any)[key] = value
		end
	end
	made.Parent = props.Parent
	return made
end

local function corner(target: GuiObject, radius: UDim)
	make("UICorner", { CornerRadius = radius, Parent = target })
end

local function outline(target: GuiObject, thickness: number, colour: Color3?, transparency: number?): UIStroke
	return make("UIStroke", {
		Thickness = thickness, Color = colour or INK, Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Round, Parent = target,
	})
end

-- A soft glow around a frame (the kit's Decor.glow: a native UIShadow with no offset).
local function glowOf(target: GuiObject, colour: Color3, blur: number, transparency: number)
	make("UIShadow", {
		Name = "Glow", Color = colour, Offset = UDim2.fromOffset(0, 0), BlurRadius = UDim.new(0, blur),
		Transparency = transparency, Parent = target,
	})
end

-- Outlined text, like the reference: white (or `colour`) with a thick dark edge.
local function words(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number, font: Font,
	stroke: number, colour: Color3?): TextLabel
	local label = make("TextLabel", {
		Name = name, BackgroundTransparency = 1, Position = position, Size = size, FontFace = font, TextSize = textSize,
		TextColor3 = colour or WHITE, Text = "", TextWrapped = true, Parent = parent,
	})
	if stroke > 0 then
		outline(label, stroke)
	end
	return label
end

-- A chunky rounded button: a gradient fill with a dark edge, a soft shine on its top half and a gloss streak (the
-- kit's Decor.shine and Decor.gloss), and outlined white text. Returns the button, its fill gradient and its label.
local function chunkyButton(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, top: Color3,
	bottom: Color3, textSize: number, onClick: () -> ()): (TextButton, UIGradient, TextLabel)
	local button = make("TextButton", {
		Name = name, BackgroundTransparency = 1, Position = position, Size = size, Text = "", AutoButtonColor = false,
		Parent = parent,
	})
	local fill = make("Frame", { Name = "Fill", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = button })
	corner(fill, UDim.new(0, 14))
	outline(fill, 3)
	local gradient = make("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom), Parent = fill })
	local shine = make("Frame", {
		Name = "Shine", BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0.46, 0), Parent = fill,
	})
	corner(shine, UDim.new(0, 11))
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.45, 1), Parent = shine })
	local gloss = make("Frame", { Name = "Gloss", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = fill })
	corner(gloss, UDim.new(0, 14))
	make("UIGradient", {
		Rotation = -60,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.22, 1), NumberSequenceKeypoint.new(0.27, 0.78),
			NumberSequenceKeypoint.new(0.33, 0.78), NumberSequenceKeypoint.new(0.38, 1), NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = gloss,
	})
	local label = words(button, "Label", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), textSize, TITLE_FONT, 3)
	label.Text = text
	label.ZIndex = 3
	local scale = make("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		onClick()
	end)
	return button, gradient, label
end

-- ----------------------------------------------------------------------------- showing

-- Lights the whole card in `colour`: the backdrop, the glow, the rays, the shards and the name.
local function setTheme(s: Screen, colour: Color3, seconds: number)
	local info = TweenInfo.new(seconds)
	local dark = Color3.fromRGB(8, 10, 12):Lerp(colour, 0.16)
	TweenService:Create(s.scene, info, { BackgroundColor3 = dark }):Play()
	for _, part in ipairs({ s.glow, s.core }) do
		TweenService:Create(part, info, { BackgroundColor3 = colour }):Play()
		local glow = part:FindFirstChild("Glow") :: any
		if glow then
			glow.Color = colour
		end
	end
	for _, arm in ipairs(s.rays:GetChildren()) do
		local ray = arm:FindFirstChild("Ray")
		if ray and ray:IsA("Frame") then
			TweenService:Create(ray, info, { BackgroundColor3 = colour }):Play()
		end
	end
	for _, shard in ipairs(s.shards) do
		TweenService:Create(shard.frame, info, { BackgroundColor3 = colour:Lerp(WHITE, 0.35) }):Play()
		local glow = shard.frame:FindFirstChild("Glow") :: any
		if glow then
			glow.Color = colour
		end
	end
	s.nameGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colour:Lerp(WHITE, 0.55)), ColorSequenceKeypoint.new(0.55, colour),
		ColorSequenceKeypoint.new(1, colour:Lerp(Color3.new(0, 0, 0), 0.25)),
	})
	s.nameGlow.TextColor3 = colour
	s.rarity.TextColor3 = colour:Lerp(WHITE, 0.2)
	-- The figure is lit a little in the colour too.
	s.stage.viewport.Ambient = Color3.fromRGB(120, 124, 132):Lerp(colour, 0.3)
end

-- Shows one celebration's name, rarity and description at the top (during the reel too).
local function showName(celebration: Item, withAbout: boolean, themeSeconds: number)
	local s = screen
	if s == nil then
		return
	end
	local text = string.upper(celebration.name)
	local size = nameSize(text)
	s.name.TextSize, s.nameGlow.TextSize = size, size
	s.name.Text, s.nameGlow.Text = text, text
	s.rarity.Text = if celebration.rarity == "Default" then "DEFAULT" else string.upper(celebration.rarity)
	s.about.Text = if withAbout then celebration.description else ""
	setTheme(s, rarityColour(celebration.rarity), themeSeconds)
end

local function showCoins()
	local s = screen
	if s then
		s.coins.Text = string.format("YOUR %s: %s", CoinConfig.Name, CoinConfig.format(coins))
	end
end

local function setSpinButton()
	local s = screen
	if s == nil then
		return
	end
	if spinning then
		s.spinLabel.Text = "SKIP"
		s.spinFill.Color = ColorSequence.new(GREEN_TOP, GREEN_BOTTOM)
	else
		s.spinLabel.Text = "SPIN"
		s.spinFill.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
	end
end

-- Their avatar doing it: a celebration over and over, or a walk-out (walk up, then the hype move).
local function perform(s: Screen, id: string)
	if kind == "Entrance" then
		local entrance = EntranceConfig.get(id)
		if entrance then
			CelebrationStage.playEntrance(s.stage, entrance, LocalMeetConfig.ComputerLifters.WalkSpeed)
		end
	else
		local celebration = CelebrationConfig.byId[id]
		if celebration then
			CelebrationStage.play(s.stage, celebration, 1)
		end
	end
end

-- Shows what they have on the open tab, with their avatar doing it.
local function showCurrent()
	local s = screen
	local item = itemOf(kind, current[kind])
	if s == nil or item == nil then
		return
	end
	s.heading.Text = "CURRENT " .. HEADINGS[kind] .. ":"
	showName(item, true, 0)
	perform(s, item.id)
end

local function pop(s: Screen, size: number, seconds: number)
	s.nameScale.Scale = size
	TweenService:Create(s.nameScale, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- The reel: flips through the celebrations, slowing down, and lands on `resultId` (at once after SKIP).
local function runReel(resultId: string, refund: number)
	local s = screen
	local result = itemOf(kind, resultId)
	if s == nil or result == nil then
		spinning = false
		setSpinButton()
		return
	end
	reelToken += 1
	local mine = reelToken
	spinning, skip = true, false
	setSpinButton()
	CelebrationStage.stop(s.stage)
	s.heading.Text = "SPINNING..."
	s.status.Text = ""
	raySpeed = 40
	local pool = POOLS[kind]
	local last: Item? = nil
	for i = 1, FLIPS - 1 do
		if skip or reelToken ~= mine then
			break
		end
		local pick = pool[math.random(1, #pool)]
		if pick == last and #pool > 1 then
			pick = pool[(table.find(pool, pick) :: number) % #pool + 1]
		end
		last = pick
		showName(pick, false, 0.05)
		pop(s, 1.08, 0.12)
		play("Tick")
		local t = (i - 1) / (FLIPS - 2)
		raySpeed = 40 - 32 * t
		task.wait(FIRST_FLIP + (LAST_FLIP - FIRST_FLIP) * t ^ 2.2)
	end
	if reelToken ~= mine then
		return
	end
	-- Landed.
	spinning = false
	setSpinButton()
	current[kind] = resultId
	s.heading.Text = "NEW " .. HEADINGS[kind] .. ":"
	showName(result, true, 0)
	local rank = rarityRank(result.rarity)
	local big = rank >= BIG_FROM
	pop(s, if big then 1.4 else 1.22, if big then 0.6 else 0.35)
	play(if big then "Big" else "Drop")
	-- A flash in the rarity's colour, the glow swelling and the rays spinning fast, then settling.
	local colour = rarityColour(result.rarity)
	s.flash.BackgroundColor3 = colour:Lerp(WHITE, 0.5)
	s.flash.BackgroundTransparency = if big then 0.15 else 0.45
	TweenService:Create(s.flash, TweenInfo.new(0.5 + rank * 0.12), { BackgroundTransparency = 1 }):Play()
	s.glow.Size = UDim2.fromOffset(470, 470)
	TweenService:Create(s.glow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(340, 340) }):Play()
	raySpeed = if big then 70 else 30
	task.delay(0.6, function()
		raySpeed = 6
	end)
	if refund > 0 then
		s.status.TextColor3 = PRICE_GREEN
		s.status.Text = string.format("You already had it: +%s %s back", CoinConfig.format(refund), CoinConfig.Name)
	else
		s.status.TextColor3 = colour:Lerp(WHITE, 0.3)
		s.status.Text = if kind == "Entrance" then "Your walk-out at every meet (the hype move at State)"
			else "Your celebration after good lifts at State"
	end
	showCoins()
	perform(s, resultId)
end

local function askSpin()
	local s = screen
	local set = remotes
	if s == nil or set == nil then
		return
	end
	if spinning then
		skip = true
		return
	end
	if coins < SPIN.price then
		s.status.TextColor3 = Color3.fromRGB(255, 110, 110)
		s.status.Text = string.format("A spin is %s %s. Earn them at official meets.", CoinConfig.format(SPIN.price), CoinConfig.Name)
		return
	end
	spinning = true
	s.spinLabel.Text = "..."
	local ok, done, message, view, resultId, refund = pcall(function()
		return set.spin:InvokeServer(kind)
	end)
	if ok and typeof(view) == "table" then
		coins = view.coins
	end
	if not ok or not done or typeof(resultId) ~= "string" then
		spinning = false
		setSpinButton()
		showCoins()
		s.status.TextColor3 = Color3.fromRGB(255, 110, 110)
		s.status.Text = if ok and typeof(message) == "string" then message else "The server didn't answer. Try again."
		return
	end
	-- (The coins shown wait for the landing, so the reel doesn't give the refund away.)
	runReel(resultId, if typeof(refund) == "number" then refund else 0)
end

-- ----------------------------------------------------------------------------- the screen

local function build(): Screen
	local gui = make("ScreenGui", {
		Name = "CelebrationSpinner", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 24,
		Enabled = false,
	})
	UIStyle.fitToScreen(gui)

	for name, id in pairs({ Tick = GearStatsConfig.Sounds.Tick, Drop = GearStatsConfig.Sounds.Drop, Big = GearStatsConfig.Sounds.Big }) do
		sounds[name] = make("Sound", { Name = name, SoundId = id, Volume = if name == "Tick" then 0.5 else 0.8, Parent = gui })
	end

	-- The card: everything is drawn inside it, the figure filling it.
	local holder = make("Frame", {
		Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Parent = gui,
	})
	local scene = make("Frame", {
		Name = "Scene", BackgroundColor3 = Color3.fromRGB(10, 14, 12), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true, Parent = holder,
	})
	corner(scene, UDim.new(0, 18))
	outline(scene, 4)
	glowOf(scene, Color3.new(0, 0, 0), 30, 0.4)

	-- The backdrop: rays turning slowly behind a soft glow, all in the rarity's colour (the kit's Decor.rays / glow).
	local rays = make("Frame", {
		Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(1100, 1100), Parent = scene,
	})
	for i = 1, 14 do
		local arm = make("Frame", {
			Name = "Arm", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = (360 / 14) * (i - 1), Parent = rays,
		})
		local ray = make("Frame", {
			Name = "Ray", BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.07, 0.5), Parent = arm,
		})
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.1), Parent = ray })
	end
	local glow = make("Frame", {
		Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(340, 340), BackgroundTransparency = 0.72, BorderSizePixel = 0, Parent = scene,
	})
	corner(glow, UDim.new(1, 0))
	glowOf(glow, WHITE, 170, 0.15)
	local core = make("Frame", {
		Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(150, 150), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = scene,
	})
	corner(core, UDim.new(1, 0))
	glowOf(core, WHITE, 90, 0.1)

	-- Glowing shards drifting around the figure, some behind it, some in front.
	local shards: { Shard } = {}
	local function shard(entry: { number }, index: number, parent: Instance)
		local frame = make("Frame", {
			Name = "Shard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(entry[1], entry[2]),
			Size = UDim2.fromOffset(entry[3], entry[3] * 0.7), Rotation = 30 + index * 23, BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.12, BorderSizePixel = 0, Parent = parent,
		})
		corner(frame, UDim.new(0, 4))
		glowOf(frame, WHITE, 26, 0.05)
		table.insert(shards, { frame = frame, x = entry[1], y = entry[2], speed = entry[4], phase = index * 1.7 })
	end
	for i = 1, 4 do
		shard(SHARDS[i + 4], i + 4, scene)
	end

	-- The figure, filling the card.
	local stage = CelebrationStage.new(scene, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), true)
	stage.camera.FieldOfView = CAMERA_FOV
	stage.camera.CFrame = CFrame.lookAt(CAMERA_FROM, CAMERA_AT)
	stage.viewport.LightColor = Color3.fromRGB(255, 250, 240)
	stage.viewport.LightDirection = Vector3.new(0.45, -0.7, 0.55)
	for i = 1, 4 do
		shard(SHARDS[i], i, scene)
	end

	-- Darker at the top and bottom so the words read (the kit's Decor.vignette).
	for _, atBottom in ipairs({ false, true }) do
		local band = make("Frame", {
			Name = "Vignette", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, if atBottom then 1 else 0), Position = UDim2.fromScale(0, if atBottom then 1 else 0),
			Size = UDim2.fromScale(1, if atBottom then 0.42 else 0.36), Parent = scene,
		})
		make("UIGradient", { Rotation = if atBottom then 90 else -90, Transparency = NumberSequence.new(1, 0.2), Parent = band })
	end
	local flash = make("Frame", {
		Name = "Flash", BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		Parent = scene,
	})

	-- The top: heading, name (with a soft coloured glow behind it), rarity, description.
	local heading = words(scene, "Heading", UDim2.fromOffset(20, 16), UDim2.new(1, -40, 0, 30), 26, TITLE_FONT, 2.5)
	local nameGlow = words(scene, "NameGlow", UDim2.fromOffset(14, 44), UDim2.new(1, -28, 0, 78), 72, TITLE_FONT, 0)
	nameGlow.TextTransparency = 0.35
	outline(nameGlow, 12, WHITE, 0.82).Name = "Halo"
	local name = words(scene, "Name", UDim2.fromOffset(14, 44), UDim2.new(1, -28, 0, 78), 72, TITLE_FONT, 5)
	local nameGradient = make("UIGradient", { Rotation = 90, Parent = name })
	local nameScale = make("UIScale", { Parent = name })
	nameGlow.TextWrapped, name.TextWrapped = false, false
	local rarity = words(scene, "Rarity", UDim2.fromOffset(20, 122), UDim2.new(1, -40, 0, 26), 24, TITLE_FONT, 2.5)
	local about = words(scene, "About", UDim2.fromOffset(28, 152), UDim2.new(1, -56, 0, 72), 19, BODY_FONT, 2)
	about.TextYAlignment = Enum.TextYAlignment.Top

	-- The bottom: status, coins bar, SPIN, price, odds.
	local status = words(scene, "Status", UDim2.fromOffset(20, H - 246), UDim2.new(1, -40, 0, 28), 21, TITLE_FONT, 2.5)
	local bar = make("Frame", {
		Name = "CoinsBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, H - 210),
		Size = UDim2.fromOffset(400, 42), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = scene,
	})
	corner(bar, UDim.new(0, 10))
	outline(bar, 3)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(96, 200, 120), Color3.fromRGB(70, 140, 230)), Parent = bar })
	local barShine = make("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0.45, 0), Parent = bar })
	corner(barShine, UDim.new(0, 8))
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.6, 1), Parent = barShine })
	local coinsText = words(bar, "Coins", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 24, TITLE_FONT, 2.5)

	local _, spinFill, spinLabel = chunkyButton(scene, "Spin", "SPIN", UDim2.new(0.5, -200, 0, H - 158), UDim2.fromOffset(400, 92),
		GOLD_TOP, GOLD_BOTTOM, 60, function()
			task.spawn(askSpin)
		end)
	local price = words(scene, "Price", UDim2.fromOffset(20, H - 60), UDim2.new(1, -40, 0, 30), 26, TITLE_FONT, 2.5)
	price.RichText = true
	price.Text = string.format('SPIN PRICE: <font color="rgb(%d,%d,%d)">%s %s</font>', math.round(PRICE_GREEN.R * 255),
		math.round(PRICE_GREEN.G * 255), math.round(PRICE_GREEN.B * 255), CoinConfig.format(SPIN.price), CoinConfig.Name)
	local odds = words(scene, "Odds", UDim2.fromOffset(20, H - 28), UDim2.new(1, -40, 0, 20), 14, BODY_FONT, 1.5)
	odds.RichText = true
	local parts = {}
	for _, entry in ipairs(GearStatsConfig.Rarities) do
		local colour = entry.colour
		table.insert(parts, string.format('<font color="rgb(%d,%d,%d)">%s %d%%</font>', math.round(colour.R * 255),
			math.round(colour.G * 255), math.round(colour.B * 255), string.upper(entry.id), math.round(entry.odds * 100)))
	end
	odds.Text = table.concat(parts, "   ")

	-- The tabs, over the top edge: CELEBRATIONS | WALK-OUTS.
	local tabs = {}
	for index, entry in ipairs({ { "Celebration", "CELEBRATIONS" }, { "Entrance", "WALK-OUTS" } }) do
		local tabKind = entry[1]
		local _, fill, label = chunkyButton(holder, "Tab_" .. tabKind, entry[2],
			UDim2.new(0.5, if index == 1 then -146 else 4, 0, -22), UDim2.fromOffset(142, 40), WHITE, WHITE, 19, function()
				CelebrationSpinner.showTab(tabKind)
			end)
		tabs[tabKind] = { fill = fill, label = label }
	end

	-- The corners: SEE ALL and close.
	local seeAll = chunkyButton(holder, "SeeAll", "SEE ALL", UDim2.fromOffset(-14, -16), UDim2.fromOffset(118, 44),
		Color3.fromRGB(120, 180, 255), Color3.fromRGB(60, 100, 220), 22, function()
			if spinning then
				return
			end
			CelebrationSpinner.close()
			CelebrationViewer.open(false, function()
				CelebrationSpinner.open(true)
			end)
		end)
	chunkyButton(holder, "Close", "X", UDim2.new(1, -36, 0, -16), UDim2.fromOffset(52, 52),
		Color3.fromRGB(255, 110, 100), Color3.fromRGB(200, 40, 50), 30, function()
			CelebrationSpinner.close()
		end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- Measure every name once, so the reel never waits on it.
	task.spawn(function()
		for _, celebration in ipairs(CelebrationConfig.List) do
			nameSize(string.upper(celebration.name))
		end
	end)
	return {
		gui = gui, holder = holder, scene = scene, glow = glow, core = core, rays = rays, shards = shards, flash = flash,
		stage = stage, heading = heading, name = name, nameGlow = nameGlow, nameGradient = nameGradient, nameScale = nameScale,
		rarity = rarity, about = about, status = status, coins = coinsText, spinFill = spinFill, spinLabel = spinLabel,
		tabs = tabs, seeAll = seeAll,
	}
end

-- The rays turn and the shards drift while the screen is open.
local function startMotion(s: Screen)
	if stepper then
		return
	end
	local clock = 0
	stepper = RunService.RenderStepped:Connect(function(dt)
		clock += dt
		s.rays.Rotation = (s.rays.Rotation + dt * raySpeed) % 360
		for _, shard in ipairs(s.shards) do
			local t = clock * shard.speed + shard.phase
			shard.frame.Position = UDim2.fromScale(shard.x + math.sin(t * 0.7) * 0.015, shard.y + math.sin(t) * 0.02)
			shard.frame.Rotation += dt * 12 * shard.speed
		end
		local pulse = 0.55 + math.sin(clock * 2.2) * 0.06
		s.core.BackgroundTransparency = pulse
	end)
end

local function stopMotion()
	if stepper then
		stepper:Disconnect()
		stepper = nil
	end
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return if rootPart and rootPart:IsA("BasePart") then rootPart.Position else nil
end

-- Switches the card to celebrations or walk-outs (not while the reel runs).
local TAB_ON = { GOLD_TOP, GOLD_BOTTOM }
local TAB_OFF = { Color3.fromRGB(70, 78, 96), Color3.fromRGB(34, 38, 50) }
function CelebrationSpinner.showTab(tabKind: string)
	local s = screen
	if s == nil or spinning or POOLS[tabKind] == nil then
		return
	end
	kind = tabKind
	for name, tab in pairs(s.tabs) do
		local on = name == tabKind
		local colours = if on then TAB_ON else TAB_OFF
		tab.fill.Color = ColorSequence.new(colours[1], colours[2])
		tab.label.TextTransparency = if on then 0 else 0.25
	end
	-- (SEE ALL lists the celebrations: only on their tab.)
	s.seeAll.Visible = tabKind == "Celebration"
	s.status.TextColor3 = WHITE
	s.status.Text = string.format("Land on the one you have: %s %s back", CoinConfig.format(SPIN.duplicateRefund), CoinConfig.Name)
	showCurrent()
end

function CelebrationSpinner.isOpen(): boolean
	local s = screen
	return s ~= nil and s.gui.Enabled
end

-- Opens the screen with a fresh copy of the player's avatar doing their celebration. `back`: returning from SEE ALL
-- (where it opened stays the same, so walking away still closes it).
function CelebrationSpinner.open(back: boolean?)
	local set = remotes
	if set == nil then
		return
	end
	local s = screen or build()
	screen = s
	if not back then
		openedAt = rootPosition()
	end
	CelebrationStage.setFigure(s.stage)
	s.status.TextColor3 = WHITE
	s.status.Text = string.format("Land on the one you have: %s %s back", CoinConfig.format(SPIN.duplicateRefund), CoinConfig.Name)
	spinning = false
	raySpeed = 6
	setSpinButton()
	s.gui.Enabled = true
	startMotion(s)
	local ok, view = pcall(function()
		return set.get:InvokeServer()
	end)
	if ok and typeof(view) == "table" then
		coins = view.coins
		current.Celebration = if CelebrationConfig.byId[view.current] then view.current else CelebrationConfig.Default
		current.Entrance = if EntranceConfig.get(view.entrance) then view.entrance else EntranceConfig.DefaultId
	end
	showCoins()
	CelebrationSpinner.showTab(if back then "Celebration" else kind)
end

function CelebrationSpinner.close()
	reelToken += 1
	spinning = false
	stopMotion()
	local s = screen
	if s then
		CelebrationStage.clear(s.stage)
		s.gui.Enabled = false
	end
end

function CelebrationSpinner.start()
	remotes = CelebrationRemotes.waitForSpinClient(ReplicatedStorage)
	local set = remotes :: CelebrationRemotes.SpinRemotes
	set.open.OnClientEvent:Connect(function()
		if not CelebrationSpinner.isOpen() and not CelebrationViewer.isOpen() then
			task.spawn(CelebrationSpinner.open)
		end
	end)
	-- Walking away from the NPC closes it.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local at = rootPosition()
			if CelebrationSpinner.isOpen() and openedAt and (at == nil or (at - (openedAt :: Vector3)).Magnitude > CLOSE_DISTANCE) then
				CelebrationSpinner.close()
			end
		end
	end)
end

return CelebrationSpinner
