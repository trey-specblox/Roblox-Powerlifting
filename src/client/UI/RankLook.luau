--!strict
--[[
	RankLook
	Client / UI

	How ranks and titles look everywhere (GAME_DESIGN §41, References/Ranks and Titles Study.md): the rank emblem and
	the coloured title text, shared by the rank-up moments (RankMoment), the RANKS menu and the name tags.

	THE EMBLEM is a competition plate (the game's own symbol): its rim, face and hub in the name's MATERIAL
	(RankConfig.TierLooks: chalk, rubber, iron ... diamond, cosmic), so the order of the 12 names reads at a glance; the
	level (I to V) shows as five small pips under it, the earned ones lit. Strength God's face turns slowly through its
	colours (the only animated one). Built with the UI kit's techniques (RobloxUIReferences kit, Decor.luau: a UIShadow
	glow, the top shine and gloss streak of its glossy buttons). When RankConfig.Images has a rendered picture for the
	name, the picture replaces the drawn plate.

		RankLook.emblem(parent, name, position, size, rank) -> Frame      (rank 0 = no rank yet: a plain grey plate)
		RankLook.title(label, titleId, count)                             colours a TextLabel as that title
		RankLook.rankText(rank) -> string                                 "Bar Bender III" / "Unranked"

	PERFORMANCE: a dozen frames per emblem; one looping tween only for Strength God and Legendary titles.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RankConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RankConfig"))
local UIFancy = require(script.Parent:WaitForChild("UIFancy"))
local make = UIFancy.make

local RankLook = {}

local INK = UIFancy.Ink
local UNRANKED = { top = Color3.fromRGB(150, 152, 158), bottom = Color3.fromRGB(90, 92, 98), rim = Color3.fromRGB(56, 58, 64),
	glow = Color3.fromRGB(120, 120, 130) }

function RankLook.rankText(rank: number): string
	local entry = RankConfig.Ranks[rank]
	return if entry then entry.label else "Unranked"
end

local function round(target: GuiObject)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = target })
end

local function disc(parent: Instance, name: string, scale: number, colour: Color3, z: number): Frame
	local frame = make("Frame", {
		Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(scale, scale), BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = z, Parent = parent,
	})
	round(frame)
	return frame
end

-- A slow endless turn of a UIGradient (Strength God's face, Legendary titles), stopped when the gradient goes.
local function spin(gradient: UIGradient, seconds: number)
	local tween = TweenService:Create(gradient, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Rotation = gradient.Rotation + 360 })
	tween:Play()
	gradient.Destroying:Connect(function()
		tween:Cancel()
	end)
end

--[[
	The rank emblem, a square `size` pixels across centred on `position`. Returns its holder.
]]
function RankLook.emblem(parent: Instance, name: string, position: UDim2, size: number, rank: number): Frame
	local entry = RankConfig.Ranks[rank]
	local tierLook: any = if entry then RankConfig.TierLooks[entry.tier] else UNRANKED
	local holder = make("Frame", {
		Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = position,
		Size = UDim2.fromOffset(size, size), Parent = parent,
	})
	local plateSize = 0.8
	local image = entry and RankConfig.Images[entry.tier]
	if image then
		make("ImageLabel", {
			Name = "Picture", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(plateSize, plateSize), Image = image, ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = holder,
		})
	else
		local plate = make("Frame", {
			Name = "Plate", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(plateSize, plateSize), Parent = holder,
		})
		-- The glow behind it, in the material's light.
		local back = disc(plate, "Glow", 0.98, tierLook.glow, 1)
		back.BackgroundTransparency = 1
		UIFancy.glow(back, tierLook.glow, math.max(8, size * 0.12), if entry and entry.tier >= 6 then 0.35 else 0.65)
		-- Rim, face, a raised ring, the hub and its hole.
		local rim = disc(plate, "Rim", 1, tierLook.rim, 2)
		UIFancy.outline(rim, math.max(2, size * 0.035))
		local face = disc(plate, "Face", 0.86, Color3.new(1, 1, 1), 3)
		local faceGradient = make("UIGradient", { Rotation = 90, Color = ColorSequence.new(tierLook.top, tierLook.bottom), Parent = face })
		if tierLook.animated then
			faceGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, tierLook.top),
				ColorSequenceKeypoint.new(0.35, Color3.fromRGB(120, 220, 255)),
				ColorSequenceKeypoint.new(0.7, tierLook.bottom),
				ColorSequenceKeypoint.new(1, tierLook.top),
			})
			spin(faceGradient, 6)
		end
		local ring = disc(plate, "Ring", 0.62, tierLook.rim, 4)
		ring.BackgroundTransparency = 1
		make("UIStroke", { Thickness = math.max(1.5, size * 0.03), Color = tierLook.rim, Transparency = 0.25, Parent = ring })
		local hub = disc(plate, "Hub", 0.34, tierLook.bottom, 5)
		UIFancy.outline(hub, math.max(1.5, size * 0.025), tierLook.rim)
		make("UIGradient", { Rotation = -90, Color = ColorSequence.new(tierLook.top, tierLook.bottom), Parent = hub })
		local hole = disc(plate, "Hole", 0.14, INK, 6)
		hole.BackgroundTransparency = 0.1
		-- The kit's shine on the top half, and its gloss streak.
		local shine = disc(plate, "Shine", 0.8, Color3.new(1, 1, 1), 7)
		shine.Position = UDim2.fromScale(0.5, 0.36)
		shine.Size = UDim2.fromScale(0.7, 0.42)
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.55, 1), Parent = shine })
		local gloss = disc(plate, "Gloss", 0.86, Color3.new(1, 1, 1), 8)
		make("UIGradient", {
			Rotation = -55,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.24, 1), NumberSequenceKeypoint.new(0.29, 0.7),
				NumberSequenceKeypoint.new(0.35, 0.7), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = gloss,
		})
	end
	-- The level: five pips under the plate, the earned ones lit in the material.
	if entry then
		local pips = make("Frame", {
			Name = "Pips", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.8, 0.12), ZIndex = 9, Parent = holder,
		})
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.03, 0), Parent = pips,
		})
		for level = 1, RankConfig.LevelsPerName do
			local lit = level <= entry.level
			local pip = make("Frame", {
				Name = "Pip" .. level, BackgroundColor3 = if lit then Color3.new(1, 1, 1) else Color3.fromRGB(30, 30, 38),
				BackgroundTransparency = if lit then 0 else 0.35,
				BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = level, ZIndex = 9, Parent = pips,
			})
			round(pip)
			UIFancy.outline(pip, math.max(1, size * 0.018), INK)
			if lit then
				make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), tierLook.glow), Parent = pip })
				UIFancy.glow(pip, tierLook.glow, math.max(4, size * 0.05), 0.4)
			end
		end
	end
	return holder
end

--[[
	Colours `label` as title `titleId` ("2x State Champion" for a repeated meet title): the tier's colour (white, blue,
	purple, gold) and, for a Legendary one, a slow light running across it. Empty text for no title.
]]
function RankLook.title(label: TextLabel, titleId: string, count: number?)
	local old = label:FindFirstChild("TitleShimmer")
	if old then
		old:Destroy()
	end
	local entry = RankConfig.TitleById[titleId]
	if entry == nil then
		label.Text = ""
		return
	end
	label.Text = if count and count > 1 then string.format("%dx %s", count, entry.name) else entry.name
	label.TextColor3 = RankConfig.TitleColours[entry.tier] or Color3.new(1, 1, 1)
	if entry.tier >= 4 then
		label.TextColor3 = Color3.new(1, 1, 1)
		local gold, light = RankConfig.TitleColours[4], Color3.fromRGB(255, 250, 210)
		local shimmer = make("UIGradient", {
			Name = "TitleShimmer",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, gold), ColorSequenceKeypoint.new(0.42, gold), ColorSequenceKeypoint.new(0.5, light),
				ColorSequenceKeypoint.new(0.58, gold), ColorSequenceKeypoint.new(1, gold),
			}),
			Offset = Vector2.new(-1, 0),
			Parent = label,
		})
		local tween = TweenService:Create(shimmer, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.8),
			{ Offset = Vector2.new(1, 0) })
		tween:Play()
		shimmer.Destroying:Connect(function()
			tween:Cancel()
		end)
	end
end

-- A gradient for a rank's NAME written in text: light enough to read on dark screens, in the material's glow.
function RankLook.nameGradient(rank: number): ColorSequence
	local entry = RankConfig.Ranks[rank]
	if entry == nil then
		return ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 192, 200))
	end
	local glow = RankConfig.TierLooks[entry.tier].glow
	return ColorSequence.new(Color3.new(1, 1, 1):Lerp(glow, 0.3), glow)
end

-- The tier's colour of a title (white for none).
function RankLook.titleColour(titleId: string): Color3
	local entry = RankConfig.TitleById[titleId]
	return if entry then RankConfig.TitleColours[entry.tier] else Color3.new(1, 1, 1)
end

return RankLook
