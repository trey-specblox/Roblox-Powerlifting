--!strict
--[[
	MeetFigures
	Server / Meet

	The people standing round a meet platform: the lifter's COACH (GAME_DESIGN
	§22: what a coach does is still to be decided; for now they watch and react)
	and, at meets against other players, the three REFEREES (§29.10: official
	meets keep their referees). Used by MockMeetArena (the coach) and
	LocalMeetVenue (the coach and the referees).

	A figure is a standard Roblox figure in its role's colours with a name tag
	and a speech bubble, standing at a spot and looking at the lift. Anchored
	and not solid, so it never gets in a lifter's way. The coach holds the
	Coach front's Blender clipboard.

	And the three SPOTTERS (buildSpotter, GAME_DESIGN §37.5): no tag; on squat
	and bench they follow the bar and take it on a miss (moved on each player's
	screen by the client's MeetSpotterAnimator).

	PERFORMANCE: each figure is one R15 body (about 16 parts, no collision, no
	queries; a spotter adds 8 small covers, no shadows). The Local meet adds
	seven per lifter while a meet runs and removes them after it.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarterGymConfig = require(Shared:WaitForChild("Config"):WaitForChild("StarterGymConfig"))

local ServerFolder = script.Parent.Parent
local WorldFolder = ServerFolder:WaitForChild("World")
local BuildParts = require(WorldFolder:WaitForChild("BuildParts"))
local RoomProps = require(WorldFolder:WaitForChild("RoomProps"))
local StyledScreen = require(WorldFolder:WaitForChild("StyledScreen"))

local MeetFigures = {}

--[[
	A collision group that collides with NOTHING, for figures that must never be
	in anyone's way: the staff here and the Local meet's computer lifters
	(ComputerLifters). CanCollide alone is not enough: a Humanoid switches
	collision back on for its torso and limbs (the coach blocked the walk back
	to the warm-up room, 2026-11-01).
]]
MeetFigures.GhostGroup = "MeetFigures"
local ghostReady = false

-- Puts every part of `model` in the ghost group (registering it the first time).
function MeetFigures.makeGhost(model: Instance)
	if not ghostReady then
		ghostReady = true
		if not PhysicsService:IsCollisionGroupRegistered(MeetFigures.GhostGroup) then
			PhysicsService:RegisterCollisionGroup(MeetFigures.GhostGroup)
		end
		for _, group in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
			PhysicsService:CollisionGroupSetCollidable(MeetFigures.GhostGroup, group.name, false)
		end
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = MeetFigures.GhostGroup
		end
	end
end

export type Kind = "Coach" | "Referee"

local looks = StarterGymConfig.Looks
local WHITE = Color3.fromRGB(255, 255, 255)
-- The coach's speech bubble: big enough for a whole sentence (GAME_DESIGN §37.5).
local COACH_BUBBLE = Vector2.new(320, 84)

local OUTFITS: { [Kind]: { skin: Color3, top: Color3, trousers: Color3, tag: string } } = {
	-- Navy top, grey trousers.
	Coach = {
		skin = Color3.fromRGB(198, 140, 104),
		top = Color3.fromRGB(28, 40, 78),
		trousers = Color3.fromRGB(62, 64, 70),
		tag = "COACH",
	},
	-- A referee's white shirt and black trousers.
	Referee = {
		skin = Color3.fromRGB(160, 112, 82),
		top = Color3.fromRGB(236, 236, 232),
		trousers = Color3.fromRGB(22, 22, 26),
		tag = "REFEREE",
	},
}

--[[
	Builds a `kind` figure in `parent`, standing at `at` (on the floor) and
	looking at `watching`. With `seatTop` (the height of a chair's seat) the
	figure SITS instead: thighs forward on the seat, lower legs down, its hips
	over `at`. Returns the speech bubble's text label (MeetFigures.say shows a
	line in it), or nil when no figure could be made (a meet works without one).
]]
function MeetFigures.build(parent: Instance, kind: Kind, at: Vector3, watching: Vector3, seatTop: number?): TextLabel?
	local outfit = OUTFITS[kind]
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = outfit.skin
	description.LeftArmColor = outfit.skin
	description.RightArmColor = outfit.skin
	description.TorsoColor = outfit.top
	description.LeftLegColor = outfit.trousers
	description.RightLegColor = outfit.trousers
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or result == nil then
		warn("[MeetFigures] no " .. kind .. " figure: " .. tostring(result))
		return nil
	end
	local figure = result :: Model
	figure.Name = kind
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	local root = figure:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		figure:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, part in ipairs(figure:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	root.Anchored = true
	local height = humanoid.HipHeight + root.Size.Y / 2
	local standAt = at + Vector3.new(0, height, 0)
	figure:PivotTo(CFrame.lookAt(standAt, Vector3.new(watching.X, standAt.Y, watching.Z)))
	figure.Parent = parent

	if seatTop then
		-- Swing both thighs forward (a quarter turn at the hips) and the lower legs back down (at the knees), then
		-- lower the figure until the thighs rest on the seat. The joints are AnimationConstraints (or Motor6Ds on an
		-- older rig); either way the turn goes on the joint's attachment on the body side, which the limb follows.
		local function bend(joint: Instance?, angle: number): Attachment?
			local turn = CFrame.Angles(math.rad(angle), 0, 0)
			local attachment: Attachment? = nil
			if joint and joint:IsA("AnimationConstraint") then
				attachment = joint.Attachment0
			elseif joint and joint:IsA("Motor6D") then
				local part0 = joint.Part0
				local found = part0 and part0:FindFirstChild(joint.Name .. "RigAttachment")
				attachment = if found and found:IsA("Attachment") then found else nil
				joint.C0 = joint.C0 * turn
			end
			if attachment then
				attachment.CFrame = attachment.CFrame * turn
			end
			return attachment
		end
		local hipY: number? = nil
		local thickness = 0.5
		for _, side in ipairs({ "Left", "Right" }) do
			local hip = bend(figure:FindFirstChild(side .. "Hip", true), 90)
			bend(figure:FindFirstChild(side .. "Knee", true), -90)
			local thigh = figure:FindFirstChild(side .. "UpperLeg")
			if hip and thigh and thigh:IsA("BasePart") then
				hipY = hip.WorldPosition.Y
				thickness = math.min(thigh.Size.X, thigh.Size.Z) / 2
			end
		end
		if hipY then
			figure:PivotTo(figure:GetPivot() - Vector3.new(0, hipY - thickness - seatTop, 0))
		end
	end

	if kind == "Coach" then
		-- A clipboard held in front of the chest: the Coach front's Blender clipboard scaled to 1.4 tall, or blocks.
		local chest = root.CFrame * CFrame.new(0, 0.2, -0.9) * CFrame.Angles(math.rad(-25), 0, 0)
		local clipboard = RoomProps.propCopy("Clipboard", 1)
		if clipboard then
			clipboard.Name = "Clipboard"
			clipboard:ScaleTo(1.4 / clipboard:GetExtentsSize().Y)
			clipboard:PivotTo(chest * CFrame.new(0, -0.7, 0)) -- its pivot is its bottom middle
			for _, part in ipairs(clipboard:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanQuery = false
				end
			end
			clipboard.Parent = figure
		else
			BuildParts.decor(BuildParts.placed(figure, "Clipboard", Vector3.new(1.1, 1.4, 0.08), chest, looks.Wood))
			BuildParts.decor(BuildParts.placed(figure, "Clipboard_Paper", Vector3.new(0.9, 1.15, 0.02),
				chest * CFrame.new(0, -0.05, -0.05), looks.LaneWhite))
		end
	end

	-- Never in anyone's way, whatever its Humanoid does to collision.
	MeetFigures.makeGhost(figure)

	-- The name tag and the speech bubble over the head.
	local head = figure:FindFirstChild("Head") :: BasePart?
	local billboard = Instance.new("BillboardGui")
	billboard.Name = kind .. "Tag"
	billboard.Size = if kind == "Coach" then UDim2.fromOffset(COACH_BUBBLE.X, COACH_BUBBLE.Y + 34)
		else UDim2.fromOffset(220, 90)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 80
	billboard.Adornee = head or root
	billboard.Parent = figure
	local tag = Instance.new("TextLabel")
	tag.Name = "Name"
	tag.AnchorPoint = Vector2.new(0.5, 1)
	tag.Position = UDim2.fromScale(0.5, 1)
	tag.Size = UDim2.fromOffset(if kind == "Referee" then 110 else 90, 22)
	tag.Rotation = -4
	tag.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	tag.Text = outfit.tag
	tag.TextColor3 = WHITE
	tag.TextScaled = true
	tag.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	tag.Parent = billboard
	local tagEdge = Instance.new("UIStroke")
	tagEdge.Color = StyledScreen.Colours.white
	tagEdge.Thickness = 2
	tagEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tagEdge.Parent = tag
	-- The speech bubble in the game's style: a white slab with an ink edge, a yellow accent bar down its
	-- left side and a tail pointing at the figure.
	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.new(1, 0, 0, if kind == "Coach" then COACH_BUBBLE.Y else 56)
	bubble.Rotation = 3
	bubble.BackgroundColor3 = StyledScreen.Colours.white
	bubble.Visible = false
	bubble.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Color = StyledScreen.Colours.ink
	stroke.Thickness = 3
	stroke.Parent = bubble
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BorderSizePixel = 0
	accent.BackgroundColor3 = StyledScreen.Colours.yellow
	accent.Size = UDim2.new(0, 7, 1, 0)
	accent.Parent = bubble
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.BorderSizePixel = 0
	tail.BackgroundColor3 = StyledScreen.Colours.white
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0.5, 0, 1, 0)
	tail.Size = UDim2.fromOffset(16, 16)
	tail.Rotation = 45
	tail.ZIndex = 0
	tail.Parent = bubble
	local tailEdge = Instance.new("UIStroke")
	tailEdge.Color = StyledScreen.Colours.ink
	tailEdge.Thickness = 3
	tailEdge.Parent = tail
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromScale(0.05, 0.1)
	line.Size = UDim2.fromScale(0.9, 0.8)
	line.Text = ""
	line.TextColor3 = Color3.fromRGB(12, 12, 14)
	line.TextScaled = true
	line.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	line.Parent = bubble
	return line
end

--[[
	A SPOTTER (GAME_DESIGN §37.5, user 2026-11-02: "3 spotters bald, Central
	shirt, black shorts, black shoes"): a simple figure for now (an average
	build once the game has its own bodies). A red CENTRAL tee, black shorts,
	black shoes, bald, skin `skin`. No name tag or bubble: nothing on anyone's
	screen. Standing at `at` (on the floor), looking at `watching`; anchored and
	a ghost like the staff. Returns the figure, or nil. Each player's screen
	then moves and poses it with the bar (client MeetSpotterAnimator).
]]
local SPOTTER_TEE = Color3.fromRGB(196, 32, 38)
local SPOTTER_BLACK = Color3.fromRGB(20, 20, 22)
-- Each body part's colour: the tee's short sleeves, the shorts, the shoes; skin elsewhere.
local SPOTTER_PARTS: { [string]: Color3 } = {
	UpperTorso = SPOTTER_TEE, LowerTorso = SPOTTER_BLACK,
	LeftUpperArm = SPOTTER_TEE, RightUpperArm = SPOTTER_TEE,
	LeftUpperLeg = SPOTTER_BLACK, RightUpperLeg = SPOTTER_BLACK,
	LeftFoot = SPOTTER_BLACK, RightFoot = SPOTTER_BLACK,
}

--[[
	The default blocky body draws each whole limb from its upper part (an arm is
	one red block even with a skin-coloured forearm, Studio 2026-11-02), so the
	shins, forearms and shoes are thin covers over those parts, welded on.
]]
local SPOTTER_COVERS = { "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "LeftLowerLeg", "RightLowerLeg",
	"LeftFoot", "RightFoot" }
local COVER_GROWTH = 1.04

local function coverPart(figure: Model, part: BasePart, colour: Color3)
	local cover = Instance.new("Part")
	cover.Name = "Cover_" .. part.Name
	cover.Size = part.Size * COVER_GROWTH
	cover.CFrame = part.CFrame
	cover.Color = colour
	cover.Material = Enum.Material.SmoothPlastic
	cover.TopSurface = Enum.SurfaceType.Smooth
	cover.BottomSurface = Enum.SurfaceType.Smooth
	cover.CanCollide = false
	cover.CanQuery = false
	cover.CanTouch = false
	cover.CastShadow = false
	cover.Massless = true
	cover.Parent = figure
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = cover
	weld.Parent = cover
end

-- "CENTRAL" printed across one face of the tee.
local function printTee(torso: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Tee_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	gui.Parent = torso
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.42)
	label.Size = UDim2.fromScale(0.86, 0.26)
	label.BackgroundTransparency = 1
	label.Text = "CENTRAL"
	label.TextColor3 = WHITE
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	label.Parent = gui
end

function MeetFigures.buildSpotter(parent: Instance, skin: Color3, at: Vector3, watching: Vector3): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = SPOTTER_TEE
	description.LeftLegColor = skin
	description.RightLegColor = skin
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or result == nil then
		warn("[MeetFigures] no spotter figure: " .. tostring(result))
		return nil
	end
	local figure = result :: Model
	figure.Name = "Spotter"
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	local root = figure:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		figure:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- Part colours set directly (a BodyColors would paint the limbs one colour each again).
	local bodyColours = figure:FindFirstChildOfClass("BodyColors")
	if bodyColours then
		bodyColours:Destroy()
	end
	for _, part in ipairs(figure:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			if part ~= root then
				part.Color = SPOTTER_PARTS[part.Name] or skin
			end
		end
	end
	local torso = figure:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		printTee(torso, Enum.NormalId.Front)
		printTee(torso, Enum.NormalId.Back)
	end
	for _, name in ipairs(SPOTTER_COVERS) do
		local part = figure:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			coverPart(figure, part, SPOTTER_PARTS[name] or skin)
		end
	end
	root.Anchored = true
	figure:SetAttribute("StandHeight", humanoid.HipHeight + root.Size.Y / 2)
	figure.Parent = parent
	MeetFigures.moveSpotter(figure, at, watching)
	MeetFigures.makeGhost(figure)
	return figure
end

-- Stands a spotter at `at` (on the floor), looking at `watching`.
function MeetFigures.moveSpotter(figure: Model, at: Vector3, watching: Vector3)
	local height = figure:GetAttribute("StandHeight")
	local standAt = at + Vector3.new(0, if typeof(height) == "number" then height else 3, 0)
	figure:PivotTo(CFrame.lookAt(standAt, Vector3.new(watching.X, standAt.Y, watching.Z)))
end

-- Shows or hides the coach's clipboard (both hands are on the lifter's back when they chalk it).
function MeetFigures.showClipboard(figure: Model?, show: boolean)
	if figure == nil then
		return
	end
	-- The Blender clipboard is a model of parts; without it, two plain blocks stand in (build).
	for _, child in ipairs(figure:GetChildren()) do
		if string.sub(child.Name, 1, 9) == "Clipboard" then
			local parts: { Instance } = child:GetDescendants()
			table.insert(parts, child)
			for _, part in ipairs(parts) do
				if part:IsA("BasePart") then
					part.Transparency = if show then 0 else 1
				end
			end
		end
	end
end

-- Shows `line` in a figure's speech bubble (the label MeetFigures.build returned); nil hides it.
function MeetFigures.say(label: TextLabel?, line: string?)
	if label == nil or label.Parent == nil then
		return
	end
	label.Text = line or ""
	local bubble = label.Parent :: GuiObject
	bubble.Visible = line ~= nil
end

return MeetFigures
