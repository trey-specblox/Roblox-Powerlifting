--!strict
--[[
	NationalsCard
	Client / UI

	The card for a new top-3 State placing toward Nationals (user 2026-11-17, GAME_DESIGN §36.4 "The Nationals spot"),
	on the placed lifter's OWN screen only, low on the screen at the awards ceremony after the State Champion badge's
	reveal. It matches that reveal (ChampionBadge): a deep navy slab with an ink edge, a yellow bar, a UIShadow glow
	(the UI kit's techniques, RobloxUIReferences/roblox-ui/kit), and slides up from the bottom.

		"TOWARD NATIONALS"   ten pips, the earned ones gold, the new one popping in with a tick; "74 KG · 4 / 10 TOP-3
		                     STATE PLACINGS"
		"NATIONALS SPOT EARNED!"   all ten gold over turning rays, the big reveal sound; "74 KG · YOURS UNTIL YOU
		                     COMPETE AT NATIONALS"

	Display only: the numbers come from the server. PERFORMANCE: a few frames for a few seconds, then gone.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local MeetSoundConfig = require(ConfigFolder:WaitForChild("MeetSoundConfig"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours

local NationalsCard = {}

local GOLD = Color3.fromRGB(255, 206, 36)
local GOLD_GLOW = Color3.fromRGB(255, 200, 60)
local EMPTY = Color3.fromRGB(40, 46, 80)
local IN_SECONDS = 0.5
local OUT_SECONDS = 0.45
local SLIDE_FROM = 260
local PIP = 30
local PIP_GAP = 8

export type News = { classLabel: string, placings: number, target: number, earned: boolean }

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

local function playSound(id: string, volume: number): Sound
	local sound = make("Sound", { Name = "NationalsCardSound", SoundId = id, Volume = volume, Parent = SoundService })
	sound:Play()
	return sound
end

-- Shows the card for `seconds`; returns a function that ends it early. Ignores news that doesn't make sense.
function NationalsCard.show(news: News, seconds: number): () -> ()
	local target = math.clamp(math.floor(tonumber(news.target) or 10), 1, 20)
	local placings = math.clamp(math.floor(tonumber(news.placings) or 0), 0, target)
	local earned = news.earned == true
	local width = 140 + target * (PIP + PIP_GAP) + 40

	local gui = make("ScreenGui", {
		Name = "NationalsCard", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local card = make("Frame", {
		Name = "Card", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(math.max(width, 600), 132), Parent = gui,
	})
	local group = make("Frame", {
		Name = "Slide", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, SLIDE_FROM),
		Parent = card,
	})
	local slab = make("Frame", {
		Name = "Slab", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = group,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = slab })
	make("UIStroke", { Thickness = 3, Color = C.ink, Parent = slab })
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.navy, C.navyDeep), Parent = slab })
	make("UIShadow", {
		Name = "Glow", Color = if earned then GOLD_GLOW else Color3.new(0, 0, 0), Offset = UDim2.fromOffset(0, 0),
		BlurRadius = UDim.new(0, if earned then 36 else 28), Transparency = if earned then 0.35 else 0.4, Parent = slab,
	})
	make("Frame", { Name = "Bar", BackgroundColor3 = C.yellow, BorderSizePixel = 0, Size = UDim2.new(0, 8, 1, 0), Parent = slab })

	local heading = make("TextLabel", {
		Name = "Heading", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 8), Size = UDim2.new(1, -40, 0, 42),
		FontFace = UIStyle.heading(), TextSize = 36, TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left,
		Text = if earned then "NATIONALS SPOT EARNED!" else "TOWARD NATIONALS", ZIndex = 3, Parent = slab,
	})
	make("UIStroke", { Thickness = 3, Color = C.ink, Parent = heading })
	if earned then
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD), Parent = heading })
	end
	make("TextLabel", {
		Name = "Detail", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 96), Size = UDim2.new(1, -40, 0, 26),
		FontFace = UIStyle.font(), TextSize = UIStyle.TextSizes.body, TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
		Text = if earned
			then string.format("%s · yours until you compete at Nationals", string.upper(news.classLabel))
			else string.format("%s · %d / %d top-3 State placings", string.upper(news.classLabel), placings, target),
		Parent = slab,
	})

	-- The pips: one per placing needed, gold up to the count; the newest pops in last.
	local row = make("Frame", {
		Name = "Pips", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 54), Size = UDim2.new(1, -40, 0, PIP + 4),
		Parent = slab,
	})
	local newest: Frame? = nil
	for index = 1, target do
		local pip = make("Frame", {
			Name = "Pip" .. index, BackgroundColor3 = if index <= placings then GOLD else EMPTY, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, ZIndex = 3,
			Position = UDim2.fromOffset(PIP / 2 + 4 + (index - 1) * (PIP + PIP_GAP), PIP / 2 + 2),
			Size = UDim2.fromOffset(PIP * 0.72, PIP * 0.72), Parent = row,
		})
		make("UIStroke", { Thickness = 2, Color = if index <= placings then C.ink else C.white, Transparency = if index <= placings then 0 else 0.6, Parent = pip })
		if index <= placings then
			make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 236, 140), Color3.fromRGB(214, 146, 18)),
				Parent = pip })
		end
		if index == placings then
			newest = pip
		end
	end
	local pop: UIScale? = nil
	if newest then
		pop = make("UIScale", { Scale = 0, Parent = newest })
	end

	-- Earned: gold rays turning slowly behind the last pip (Decor.rays, as on the badge reveal).
	local turning: Tween? = nil
	if earned and newest then
		local rays = make("Frame", {
			Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = newest.Position,
			Size = UDim2.fromOffset(PIP * 4, PIP * 4), ZIndex = 2, Parent = row,
		})
		for i = 1, 12 do
			local arm = make("Frame", { Name = "Arm", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				Rotation = 30 * (i - 1), ZIndex = 2, Parent = rays })
			local ray = make("Frame", { Name = "Ray", BackgroundColor3 = GOLD_GLOW, BackgroundTransparency = 0.4, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.06, 0.5), ZIndex = 2,
				Parent = arm })
			make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.2), Parent = ray })
		end
		local tween = TweenService:Create(rays, TweenInfo.new(12, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
		tween:Play()
		turning = tween
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	UIStyle.fitToScreen(gui)

	local sounds: { Sound } = {}
	TweenService:Create(group, TweenInfo.new(IN_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, 0) }):Play()
	-- The new pip lands just after the card does: a tick, or the big reveal sound for the spot itself.
	task.delay(IN_SECONDS * 0.8, function()
		if pop and pop.Parent then
			TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		if gui.Parent then
			table.insert(sounds, playSound(if earned then GearStatsConfig.Sounds.Big else MeetSoundConfig.Cues.LightsGood.id,
				if earned then 0.9 else 0.6))
		end
	end)

	local ended = false
	local function stop()
		if ended then
			return
		end
		ended = true
		TweenService:Create(group, TweenInfo.new(OUT_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(0, SLIDE_FROM) }):Play()
		task.delay(OUT_SECONDS + 0.05, function()
			if turning then
				turning:Cancel()
			end
			gui:Destroy()
			for _, sound in ipairs(sounds) do
				sound:Destroy()
			end
		end)
	end
	task.delay(seconds, stop)
	return stop
end

return NationalsCard
