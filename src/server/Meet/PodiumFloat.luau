--!strict
--[[
	PodiumFloat
	Server / Meet

	What floats over a podium lifter's head (user 2026-11-27, after the referee handed the trophy over upside down: "if
	you are getting a trophy, lets just have it where its a big floating trophy over the head, and have it have shiny
	vfx. for normal meets, you can have it where it has a floating #1 #2 #3"; the medals stay):
	  - the winner of a State or Nationals meet: a big trophy (Trophies' uploaded model, gold), slowly turning, with
	    sparkles and a warm glow, and a burst of sparkles as it appears;
	  - everyone else in the top 3: their place, "#1" "#2" "#3", in gold, silver or bronze.
	Shown once they stand on their block (MeetCeremony; the Nationals class podiums), until the clean-up show returns.
	The turning and bobbing happen on each screen (client PodiumFloatSpin, CollectionService tag), so the server sends
	nothing per frame. Looks only: no collision, touch, query or shadow.

	PERFORMANCE: at most 3 per podium; the trophy is one 2-part model, one emitter at ~18 particles a second and one light.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local MeetLevelConfig = require(ConfigFolder:WaitForChild("MeetLevelConfig"))
local Trophies = require(script.Parent:WaitForChild("Trophies"))

local PodiumFloat = {}

-- The tag the client's PodiumFloatSpin turns and bobs (its pivot when shown is the BaseCFrame attribute).
PodiumFloat.Tag = "PodiumFloat"

local TROPHY_HEIGHT = 2.6 -- studs: big, about two heads tall
-- Studs of air between the top of the lifter (hair, hats) and what floats. (Studio 2026-11-27: 1.6 put the #1 over the
-- backdrop's title, LOCAL CENTRAL MEET, from the crowd's side; UIs never overlap.)
local GAP_OVER_HEAD = 0.8
local NUMBER_WIDTH, NUMBER_HEIGHT = 2.6, 1.8 -- studs
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
end

-- The height of the top of `lifter` (its head, hair or hat).
local function topOf(lifter: Model): number
	local box, size = lifter:GetBoundingBox()
	return box.Position.Y + size.Y / 2
end

-- The big trophy, its base GAP_OVER_HEAD over `lifter`, facing `toward` (flat). Nil without the model.
local function trophyOver(lifter: Model, toward: Vector3, folder: Instance): Model?
	local trophy = Trophies.copy(1)
	if trophy == nil then
		return nil
	end
	trophy.Name = "PodiumTrophy"
	local _, size = trophy:GetBoundingBox()
	if size.Y > 0 then
		trophy:ScaleTo(trophy:GetScale() * TROPHY_HEIGHT / size.Y)
	end
	local metal: BasePart? = nil
	for _, part in ipairs(trophy:GetDescendants()) do
		if part:IsA("BasePart") then
			quiet(part)
			if part.Name == "Trophy_Metal" then
				metal = part
				part.Reflectance = 0.3
			end
		end
	end
	local pivot, scaled = trophy:GetBoundingBox()
	local centre = Vector3.new(0, topOf(lifter) + GAP_OVER_HEAD + scaled.Y / 2, 0)
	local root = lifter:GetPivot().Position
	local at = Vector3.new(root.X, centre.Y, root.Z)
	local flat = Vector3.new(toward.X, 0, toward.Z)
	local facing = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	-- (the bounding box's middle on the spot: the model's own pivot may sit at its base)
	trophy:PivotTo(CFrame.lookAt(at, at + facing) * pivot:ToObjectSpace(trophy:GetPivot()))
	-- The shine: sparkles all round it, a warm glow, and a burst as it appears.
	local glowOn = metal or trophy.PrimaryPart
	if glowOn then
		local attachment = Instance.new("Attachment")
		attachment.Name = "Shine"
		-- (on its part first: a world position set before that is measured from the part once parented)
		attachment.Parent = glowOn
		attachment.WorldPosition = at
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Texture = SPARKLE_TEXTURE
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 236, 150), Color3.fromRGB(255, 196, 60))
		sparkles.LightEmission = 1
		sparkles.LightInfluence = 0
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		sparkles.Lifetime = NumberRange.new(0.9, 1.6)
		sparkles.Rate = 18
		sparkles.Speed = NumberRange.new(0.6, 1.8)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Rotation = NumberRange.new(0, 360)
		sparkles.RotSpeed = NumberRange.new(-90, 90)
		sparkles.Shape = Enum.ParticleEmitterShape.Sphere
		sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		sparkles.Parent = attachment
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 214, 120)
		glow.Brightness = 1.6
		glow.Range = 9
		glow.Shadows = false
		glow.Parent = attachment
		task.defer(function()
			if sparkles.Parent then
				sparkles:Emit(40)
			end
		end)
	end
	trophy:SetAttribute("BaseCFrame", trophy:GetPivot())
	CollectionService:AddTag(trophy, PodiumFloat.Tag)
	trophy.Parent = folder
	return trophy
end

-- "#1" / "#2" / "#3" over `lifter`, in its place's colour.
local function numberOver(lifter: Model, place: number, folder: Instance): BasePart
	local colour = MeetLevelConfig.TrophyColours[place] or Color3.new(1, 1, 1)
	local holder = Instance.new("Part")
	holder.Name = "PodiumPlace"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	quiet(holder)
	local root = lifter:GetPivot().Position
	holder.CFrame = CFrame.new(root.X, topOf(lifter) + GAP_OVER_HEAD + NUMBER_HEIGHT / 2, root.Z)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Place"
	billboard.Size = UDim2.fromScale(NUMBER_WIDTH, NUMBER_HEIGHT)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 140
	billboard.ResetOnSpawn = false
	billboard.Parent = holder
	local label = Instance.new("TextLabel")
	label.Name = "Number"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Rotation = -4
	label.Text = "#" .. place
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	label.Parent = billboard
	-- (the game's tag look: heavy italic with a dark edge, shining from white into the place's colour)
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(12, 12, 14)
	edge.Thickness = 3
	edge.Parent = label
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, colour), ColorSequenceKeypoint.new(1, colour:Lerp(Color3.new(0, 0, 0), 0.25)) })
	shine.Rotation = 90
	shine.Parent = label
	holder:SetAttribute("BaseCFrame", holder.CFrame)
	CollectionService:AddTag(holder, PodiumFloat.Tag)
	holder.Parent = folder
	return holder
end

--[[
	Floats the award over `lifter` (standing on its block, facing `toward`): the big trophy when `trophy` (1st at State
	or Nationals), else its place's number. Returns what to destroy afterwards (nil if nothing could be shown).
]]
function PodiumFloat.show(lifter: Model, place: number, trophy: boolean, toward: Vector3, folder: Instance): Instance?
	if lifter.Parent == nil then
		return nil
	end
	if trophy then
		local cup = trophyOver(lifter, toward, folder)
		if cup then
			return cup
		end
	end
	return numberOver(lifter, place, folder)
end

return PodiumFloat
