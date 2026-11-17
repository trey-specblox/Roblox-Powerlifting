--!strict
--[[
	ChampionBadge
	Client / UI

	How the numbered State Champion badge looks (user 2026-11-16, GAME_DESIGN §36.4): a gold medal with the badge's
	game-wide number ("#1001") in the middle, its month ("NOV 2026") over it and a red "STATE CHAMPION" ribbon across
	it. Built with the UI kit's techniques (RobloxUIReferences/roblox-ui/kit, Decor.luau): a UIShadow glow, the top
	shine and the gloss streak of its glossy buttons, and turning rays behind the reveal. Display only: the numbers
	come from the server.

		ChampionBadge.medal(parent, position, size, number, seasonLabel)   the medal (STATS screen, the reveal)
		ChampionBadge.reveal(badge, winnerName, seconds)                   the awards ceremony's card for a new badge,
		                                                                   with its sound; returns a function that ends it

	PERFORMANCE: a few frames; the reveal's rays turn with one looping tween and everything is gone when it ends.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GearStatsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GearStatsConfig"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours

local ChampionBadge = {}

local GOLD_TOP = Color3.fromRGB(255, 230, 120)
local GOLD_BOTTOM = Color3.fromRGB(214, 146, 18)
local GOLD_RIM = Color3.fromRGB(150, 98, 8)
local GOLD_GLOW = Color3.fromRGB(255, 200, 60)
local RIBBON = Color3.fromRGB(214, 40, 52)
local RIBBON_DARK = Color3.fromRGB(140, 20, 30)
local INK = C.ink
-- The reveal: how big its medal is and how long its pieces take to arrive.
local REVEAL_MEDAL = 210
local REVEAL_IN_SECONDS = 0.5
local REVEAL_OUT_SECONDS = 0.45
local RAY_TURN_SECONDS = 14
-- How far below its place the card starts and ends (pixels): off the bottom of the screen.
local SLIDE_FROM = 320

local function make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function round(target: GuiObject)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = target })
end

-- Outlined heavy italic text that fills its box (TextScaled, up to `maxSize`).
local function words(parent: Instance, name: string, position: UDim2, size: UDim2, maxSize: number, colour: Color3,
	stroke: number): TextLabel
	local label = make("TextLabel", {
		Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = size,
		FontFace = UIStyle.heading(), TextColor3 = colour, TextScaled = true, Text = "", ZIndex = 4, Parent = parent,
	})
	make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 6, Parent = label })
	if stroke > 0 then
		make("UIStroke", { Thickness = stroke, Color = INK, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	end
	return label
end

-- "#1001", or "#?" while its number is on its way.
function ChampionBadge.numberText(number: number): string
	return if number > 0 then "#" .. tostring(number) else "#?"
end

--[[
	The medal, `size` pixels across, centred on `position` inside `parent`. Returns its holder (a transparent square
	Frame, AnchorPoint at its centre) so callers can scale or move it.
]]
function ChampionBadge.medal(parent: Instance, position: UDim2, size: number, number: number, seasonLabel: string): Frame
	local holder = make("Frame", {
		Name = "ChampionMedal", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = position,
		Size = UDim2.fromOffset(size, size), Parent = parent,
	})
	-- The rim: dark gold with an ink edge and a soft gold glow round it (the kit's Decor.glow, a UIShadow).
	local rim = make("Frame", {
		Name = "Rim", BackgroundColor3 = GOLD_RIM, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2,
		Parent = holder,
	})
	round(rim)
	make("UIStroke", { Thickness = math.max(2, size * 0.035), Color = INK, Parent = rim })
	make("UIShadow", {
		Name = "Glow", Color = GOLD_GLOW, Offset = UDim2.fromOffset(0, 0), BlurRadius = UDim.new(0, math.floor(size * 0.3)),
		Transparency = 0.35, Parent = rim,
	})
	-- The gold face, lighter at the top.
	local face = make("Frame", {
		Name = "Face", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), ZIndex = 2, Parent = rim,
	})
	round(face)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM), Parent = face })
	-- An engraved inner ring.
	local ring = make("Frame", {
		Name = "Ring", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8), ZIndex = 3, Parent = face,
	})
	round(ring)
	make("UIStroke", { Thickness = math.max(1, size * 0.02), Color = GOLD_RIM, Transparency = 0.15, Parent = ring })
	-- The kit's shine (a soft light over the top half) and gloss (a thin diagonal streak).
	local shine = make("Frame", {
		Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06), Size = UDim2.fromScale(0.78, 0.44), ZIndex = 3, Parent = face,
	})
	round(shine)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.5, 1), Parent = shine })
	local gloss = make("Frame", {
		Name = "Gloss", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3,
		Parent = face,
	})
	round(gloss)
	make("UIGradient", {
		Rotation = -60,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.24, 1), NumberSequenceKeypoint.new(0.29, 0.7),
			NumberSequenceKeypoint.new(0.34, 0.7), NumberSequenceKeypoint.new(0.39, 1), NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = gloss,
	})
	-- The month over the number, the number in the middle.
	local season = words(face, "Season", UDim2.fromScale(0.5, 0.25), UDim2.fromScale(0.56, 0.12), math.floor(size * 0.12),
		INK, 0)
	season.Text = seasonLabel
	local digits = words(face, "Number", UDim2.fromScale(0.5, 0.48), UDim2.fromScale(0.74, 0.3), math.floor(size * 0.3),
		C.white, math.max(1.5, size * 0.03))
	digits.Text = ChampionBadge.numberText(number)
	-- The red ribbon across the bottom, wider than the medal, with darker folded ends behind it.
	for side = 0, 1 do
		local tail = make("Frame", {
			Name = "RibbonEnd", BackgroundColor3 = RIBBON_DARK, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(if side == 0 then 0.0 else 1.0, 0.8), Size = UDim2.fromScale(0.22, 0.16),
			ZIndex = 4, Parent = holder,
		})
		make("UIStroke", { Thickness = math.max(1, size * 0.02), Color = INK, Parent = tail })
	end
	local ribbon = make("Frame", {
		Name = "Ribbon", BackgroundColor3 = RIBBON, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(1.04, 0.19), ZIndex = 5, Parent = holder,
	})
	make("UIStroke", { Thickness = math.max(1.5, size * 0.025), Color = INK, Parent = ribbon })
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		Parent = ribbon,
	})
	local title = words(ribbon, "Title", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.78), math.floor(size * 0.13),
		C.white, math.max(1, size * 0.015))
	title.ZIndex = 6
	title.Text = "STATE CHAMPION"
	return holder
end

--[[
	The awards ceremony's card for a new badge, low on the screen so the close-up on the winner stays clear (like a TV
	caption): the medal pops in over turning gold rays, with "STATE CHAMPION #1001", the winner's name and the month,
	and the big reveal sound. It goes by itself after `seconds`; the returned function ends it early.
]]
function ChampionBadge.reveal(badge: { number: number, seasonLabel: string, name: string }, winnerName: string,
	seconds: number): () -> ()
	local gui = make("ScreenGui", {
		Name = "ChampionBadgeReveal", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local card = make("Frame", {
		Name = "Card", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -36),
		Size = UDim2.fromOffset(760, 170), Parent = gui,
	})
	-- Everything slides in and out inside the card, so the card itself (scaled to the screen by fitToScreen) stays put.
	local group = make("Frame", {
		Name = "Slide", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, SLIDE_FROM),
		Parent = card,
	})
	-- The slab: deep navy, an ink edge, a yellow bar down its left and a soft dark glow so it reads over anything.
	local slab = make("Frame", {
		Name = "Slab", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(120, 34),
		Size = UDim2.new(1, -120, 1, -34), Parent = group,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = slab })
	make("UIStroke", { Thickness = 3, Color = INK, Parent = slab })
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.navy, C.navyDeep), Parent = slab })
	make("UIShadow", {
		Name = "Glow", Color = Color3.new(0, 0, 0), Offset = UDim2.fromOffset(0, 0), BlurRadius = UDim.new(0, 30),
		Transparency = 0.4, Parent = slab,
	})
	make("Frame", {
		Name = "Bar", BackgroundColor3 = C.yellow, BorderSizePixel = 0, Position = UDim2.fromOffset(120, 0),
		Size = UDim2.new(0, 8, 1, 0), Parent = slab,
	})
	local textLeft = 140
	local heading = make("TextLabel", {
		Name = "Heading", BackgroundTransparency = 1, Position = UDim2.fromOffset(textLeft, 8), Size = UDim2.new(1, -textLeft - 16, 0, 46),
		FontFace = UIStyle.heading(), TextSize = 40, TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("%s %s", badge.name, if badge.number > 0 then ChampionBadge.numberText(badge.number) else ""),
		Parent = slab,
	})
	make("UIStroke", { Thickness = 3, Color = INK, Parent = heading })
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD_TOP), Parent = heading })
	make("TextLabel", {
		Name = "Winner", BackgroundTransparency = 1, Position = UDim2.fromOffset(textLeft, 56), Size = UDim2.new(1, -textLeft - 16, 0, 30),
		FontFace = UIStyle.heading(), TextSize = UIStyle.TextSizes.heading, TextColor3 = C.yellow,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = string.upper(winnerName),
		Parent = slab,
	})
	make("TextLabel", {
		Name = "Season", BackgroundTransparency = 1, Position = UDim2.fromOffset(textLeft, 90), Size = UDim2.new(1, -textLeft - 16, 0, 26),
		FontFace = UIStyle.font(), TextSize = UIStyle.TextSizes.body, TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if badge.number > 0
			then string.format("%s · the %s State Champion ever", badge.seasonLabel, ChampionBadge.ordinal(badge.number))
			else string.format("%s · their number is on its way", badge.seasonLabel),
		Parent = slab,
	})

	-- The medal on the left, standing out over the slab's top, with gold rays turning slowly behind it (Decor.rays).
	local medalSpot = make("Frame", {
		Name = "MedalSpot", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(REVEAL_MEDAL / 2 + 10, 74), Size = UDim2.fromOffset(REVEAL_MEDAL, REVEAL_MEDAL), Parent = group,
	})
	local rays = make("Frame", {
		Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(2.1, 2.1), Parent = medalSpot,
	})
	for i = 1, 16 do
		local arm = make("Frame", {
			Name = "Arm", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = (360 / 16) * (i - 1), Parent = rays,
		})
		local ray = make("Frame", {
			Name = "Ray", BackgroundColor3 = GOLD_GLOW, BackgroundTransparency = 0.45, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.05, 0.5),
			Parent = arm,
		})
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.2), Parent = ray })
	end
	local medal = ChampionBadge.medal(medalSpot, UDim2.fromScale(0.5, 0.5), REVEAL_MEDAL, badge.number, badge.seasonLabel)
	local pop = make("UIScale", { Scale = 0, Parent = medal })
	local raysScale = make("UIScale", { Scale = 0, Parent = rays })

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	UIStyle.fitToScreen(gui)

	local sound = make("Sound", { Name = "ChampionBadgeSound", SoundId = GearStatsConfig.Sounds.Big, Volume = 0.9, Parent = SoundService })
	sound:Play()

	-- In: the slab slides up, the medal pops (overshooting a little), the rays open behind it and keep turning.
	TweenService:Create(group, TweenInfo.new(REVEAL_IN_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, 0) }):Play()
	TweenService:Create(pop, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(raysScale, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local turning = TweenService:Create(rays, TweenInfo.new(RAY_TURN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Rotation = 360 })
	turning:Play()

	local ended = false
	local function stop()
		if ended then
			return
		end
		ended = true
		TweenService:Create(group, TweenInfo.new(REVEAL_OUT_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(0, SLIDE_FROM) }):Play()
		TweenService:Create(pop, TweenInfo.new(REVEAL_OUT_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		TweenService:Create(raysScale, TweenInfo.new(REVEAL_OUT_SECONDS), { Scale = 0 }):Play()
		task.delay(REVEAL_OUT_SECONDS + 0.05, function()
			turning:Cancel()
			gui:Destroy()
			sound:Destroy()
		end)
	end
	task.delay(seconds, stop)
	return stop
end

-- 1 -> "1st", 2 -> "2nd", 11 -> "11th", 1001 -> "1001st".
function ChampionBadge.ordinal(number: number): string
	local lastTwo = number % 100
	local suffix = if lastTwo >= 11 and lastTwo <= 13 then "th"
		elseif number % 10 == 1 then "st"
		elseif number % 10 == 2 then "nd"
		elseif number % 10 == 3 then "rd"
		else "th"
	return tostring(number) .. suffix
end

return ChampionBadge
