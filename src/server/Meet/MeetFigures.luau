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
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarterGymConfig = require(Shared:WaitForChild("Config"):WaitForChild("StarterGymConfig"))

local ServerFolder = script.Parent.Parent
local WorldFolder = ServerFolder:WaitForChild("World")
local BuildParts = require(WorldFolder:WaitForChild("BuildParts"))
local RoomProps = require(WorldFolder:WaitForChild("RoomProps"))
local StyledScreen = require(WorldFolder:WaitForChild("StyledScreen"))
local LifterBodyService = require(ServerFolder:WaitForChild("Economy"):WaitForChild("LifterBodyService"))
local ClothesConfig = require(Shared:WaitForChild("Config"):WaitForChild("ClothesConfig"))
local HandShapeConfig = require(Shared:WaitForChild("Config"):WaitForChild("HandShapeConfig"))
local LifterBuild = require(Shared:WaitForChild("Economy"):WaitForChild("LifterBuild"))

local MeetFigures = {}

--[[
	A collision group that collides with NOTHING, for figures that must never be
	in anyone's way: the staff here and the Local meet's computer lifters
	(ComputerLifters). CanCollide alone is not enough: a Humanoid switches
	collision back on for its torso and limbs (the coach blocked the walk back
	to the warm-up room, 2026-11-01).
]]
MeetFigures.GhostGroup = "MeetFigures"
-- How tall the coach's clipboard is, in studs.
local CLIPBOARD_HEIGHT = 1.1

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

export type Kind = "Coach" | "Referee" | "Caller"

-- (defined further down)
local sitFigure: (figure: Model, at: Vector3, seatTop: number) -> ()

local looks = StarterGymConfig.Looks
local WHITE = Color3.fromRGB(255, 255, 255)
-- The coach's speech bubble: big enough for a whole sentence (GAME_DESIGN §37.5).
local COACH_BUBBLE = Vector2.new(320, 84)
local CALLER_BUBBLE_STUDS = Vector2.new(9, 3.2)

local OUTFITS: { [Kind]: { skin: Color3, top: Color3, trousers: Color3, tag: string } } = {
	-- Navy top, grey trousers.
	Coach = {
		skin = Color3.fromRGB(198, 140, 104),
		top = Color3.fromRGB(28, 40, 78),
		trousers = Color3.fromRGB(62, 64, 70),
		tag = "COACH",
	},
	-- The worker calling out who is up (user 2026-11-06): the game's yellow, so they are easy to find.
	Caller = {
		skin = Color3.fromRGB(226, 182, 148),
		top = Color3.fromRGB(242, 190, 30),
		trousers = Color3.fromRGB(28, 40, 78),
		tag = "CALLER",
	},
	-- A referee's white shirt and black trousers.
	Referee = {
		skin = Color3.fromRGB(160, 112, 82),
		top = Color3.fromRGB(236, 236, 232),
		trousers = Color3.fromRGB(22, 22, 26),
		tag = "REFEREE",
	},
}

-- ---------------------------------------------------------------- sitting, getting up and sitting back down

--[[
	A seated figure (the referees on their chairs): how its legs are bent and where it is, kept so it can get up and sit
	back down (the Nationals judge and announcer, GAME_DESIGN §39). `share` 1 = seated, 0 = standing just in front of
	the chair, its feet where they were while it sat.
]]
type Joint = { attachment: Attachment?, attachmentBase: CFrame?, motor: Motor6D?, motorBase: CFrame?, sign: number }
type Seated = {
	joints: { Joint },
	-- The chair's floor point under the hips, the way the figure faces, and how far ahead of the hips the feet are.
	at: Vector3,
	forward: Vector3,
	feetAhead: number,
	-- The root part's height standing, and seated.
	standY: number,
	seatY: number,
	share: number,
}
local seatedFigures: { [Model]: Seated } = {}

-- A leg joint's turn goes on the joint's attachment on the body side (an AnimationConstraint's, or a Motor6D's on an
-- older rig), which the limb follows.
local function jointOf(joint: Instance?, sign: number): Joint?
	if joint and joint:IsA("AnimationConstraint") then
		local attachment = joint.Attachment0
		if attachment then
			return { attachment = attachment, attachmentBase = attachment.CFrame, motor = nil, motorBase = nil, sign = sign }
		end
	elseif joint and joint:IsA("Motor6D") then
		local part0 = joint.Part0
		local found = part0 and part0:FindFirstChild(joint.Name .. "RigAttachment")
		local attachment = if found and found:IsA("Attachment") then found else nil
		return { attachment = attachment, attachmentBase = if attachment then attachment.CFrame else nil, motor = joint,
			motorBase = joint.C0, sign = sign }
	end
	return nil
end

-- Poses a figure `share` of the way down onto its chair: the thighs swing forward (a quarter turn at the hips when
-- seated) and the lower legs stay hanging straight down (the knees turn back by as much), so the feet stay where they
-- are while the hips go back and down onto the seat.
local function poseSeated(figure: Model, seat: Seated, share: number)
	seat.share = share
	local angle = math.rad(90) * share
	for _, joint in ipairs(seat.joints) do
		local turn = CFrame.Angles(angle * joint.sign, 0, 0)
		if joint.motor and joint.motorBase then
			joint.motor.C0 = joint.motorBase * turn
		end
		if joint.attachment and joint.attachmentBase then
			joint.attachment.CFrame = joint.attachmentBase * turn
		end
	end
	local floor = seat.at + seat.forward * seat.feetAhead * (1 - math.sin(angle))
	local y = seat.standY - (seat.standY - seat.seatY) * (1 - math.cos(angle))
	local here = Vector3.new(floor.X, y, floor.Z)
	figure:PivotTo(CFrame.lookAt(here, here + seat.forward))
end

-- Seats a figure standing over `at` (the chair's floor point under its hips), its thighs resting on `seatTop`.
sitFigure = function(figure: Model, at: Vector3, seatTop: number)
	local pivot = figure:GetPivot()
	local forward = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z).Unit
	local joints: { Joint } = {}
	local thigh, thickness = 1.2, 0.5
	local hipDrop: number? = nil
	for _, side in ipairs({ "Left", "Right" }) do
		local hip = jointOf(figure:FindFirstChild(side .. "Hip", true), 1)
		local knee = jointOf(figure:FindFirstChild(side .. "Knee", true), -1)
		if hip then
			table.insert(joints, hip)
		end
		if knee then
			table.insert(joints, knee)
		end
		local upper = figure:FindFirstChild(side .. "UpperLeg")
		if hip and hip.attachment and upper and upper:IsA("BasePart") then
			-- (standing still: how far the hip joint is below the root, and the thigh's length down to the knee)
			hipDrop = pivot.Position.Y - hip.attachment.WorldPosition.Y
			thickness = math.min(upper.Size.X, upper.Size.Z) / 2
			if knee and knee.attachment then
				thigh = (hip.attachment.WorldPosition - knee.attachment.WorldPosition).Magnitude
			end
		end
	end
	local standY = pivot.Position.Y
	-- Seated, the hip joints are half a thigh's thickness above the seat: the thighs rest on it.
	local seatY = if hipDrop then seatTop + thickness + hipDrop else standY - thigh
	local seat: Seated = { joints = joints, at = at, forward = forward, feetAhead = thigh, standY = standY, seatY = seatY,
		share = 1 }
	seatedFigures[figure] = seat
	figure.Destroying:Once(function()
		seatedFigures[figure] = nil
	end)
	poseSeated(figure, seat, 1)
end

-- Whether the figure has a chair (it was built seated), and whether it is sitting on it now.
function MeetFigures.hasSeat(figure: Model?): boolean
	return figure ~= nil and seatedFigures[figure] ~= nil
end

function MeetFigures.isSeated(figure: Model?): boolean
	local seat = if figure then seatedFigures[figure] else nil
	return seat ~= nil and seat.share >= 1
end

-- Where a figure with a chair stands once it has got up: a floor point just in front of the chair, facing the way the
-- chair faces. A walk back to the chair ends here, before sitDown.
function MeetFigures.standSpot(figure: Model?): CFrame?
	local seat = if figure then seatedFigures[figure] else nil
	if seat == nil then
		return nil
	end
	local floor = seat.at + seat.forward * seat.feetAhead
	return CFrame.lookAt(floor, floor + seat.forward)
end

-- Eases a figure between seated and standing over `seconds` (yields). The server moves it: a short move, seen from a
-- distance or off camera.
local function easeSeat(figure: Model, to: number, seconds: number)
	local seat = seatedFigures[figure]
	if seat == nil or seat.share == to then
		return
	end
	local from = seat.share
	local startedAt = os.clock()
	while figure.Parent do
		local u = math.clamp((os.clock() - startedAt) / math.max(seconds, 0.01), 0, 1)
		poseSeated(figure, seat, from + (to - from) * (u * u * (3 - 2 * u)))
		if u >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- Gets a seated figure up off its chair, onto its feet in front of it (yields `seconds`). Nothing without a chair.
function MeetFigures.standUp(figure: Model?, seconds: number?)
	if figure and seatedFigures[figure] then
		easeSeat(figure, 0, seconds or 0.8)
	end
end

-- Sits a figure back down on its chair (yields `seconds`). It should be standing at its standSpot.
function MeetFigures.sitDown(figure: Model?, seconds: number?)
	if figure and seatedFigures[figure] then
		easeSeat(figure, 1, seconds or 0.8)
	end
end

--[[
	A clipboard carried in the left hand, gripped by its top and hanging at the figure's side, its face outward (the
	talking animation holds it up in this hand). Welded to the hand, so it follows the arm (user 2026-11-06: it used to
	float in front of the chest). The Coach front's Blender clipboard, or blocks. Nothing when it already has one.
]]
function MeetFigures.giveClipboard(figure: Model)
	if figure:FindFirstChild("Clipboard") then
		return
	end
	local hand = figure:FindFirstChild("LeftHand")
	if hand == nil or not hand:IsA("BasePart") then
		return
	end
	local held = hand.CFrame * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, math.rad(90), 0)
	local function carried(part: BasePart)
		BuildParts.decor(part)
		part.Anchored = false
		part.Massless = true
		part.CanQuery = false
		-- (never in anyone's way, like the hand that holds it: makeGhost may already have run)
		part.CollisionGroup = hand.CollisionGroup
		local weld = Instance.new("Weld")
		weld.Part0 = hand
		weld.Part1 = part
		weld.C0 = hand.CFrame:ToObjectSpace(part.CFrame)
		weld.Parent = part
	end
	local clipboard = RoomProps.propCopy("Clipboard", 1)
	if clipboard then
		clipboard.Name = "Clipboard"
		clipboard:ScaleTo(CLIPBOARD_HEIGHT / clipboard:GetExtentsSize().Y)
		clipboard:PivotTo(held * CFrame.new(0, -CLIPBOARD_HEIGHT, 0)) -- its pivot is its bottom middle
		for _, part in ipairs(clipboard:GetDescendants()) do
			if part:IsA("BasePart") then
				carried(part)
			end
		end
		clipboard.Parent = figure
	else
		local middle = held * CFrame.new(0, -CLIPBOARD_HEIGHT / 2, 0)
		carried(BuildParts.placed(figure, "Clipboard", Vector3.new(0.85, CLIPBOARD_HEIGHT, 0.08), middle, looks.Wood))
		carried(BuildParts.placed(figure, "Clipboard_Paper", Vector3.new(0.7, CLIPBOARD_HEIGHT - 0.2, 0.02),
			middle * CFrame.new(0, -0.05, -0.05), looks.LaneWhite))
	end
end

--[[
	A microphone held in the right hand (the Nationals announcer, GAME_DESIGN §39): the hand closes round its handle (the
	Grip hand shape, kept while it is held: HandShapeConfig.HeldAttributes), the head at the thumb's end, so it comes up
	to the mouth when the forearm does. Welded to the hand. Blender's AnnouncerMic (art/scripts/build_announcer_mic_01.py);
	nothing when the model did not load, and shown again when the figure already has one.
]]
local MIC_NAME = "Microphone"
-- Where the handle sits in the closed hand, in the hand's own space at hand size 1 (the middle of the fingers' curl),
-- and how far up the handle from its butt the hand holds it (studs).
local MIC_GRIP = Vector3.new(-0.2, -0.06, 0)
local MIC_HELD_AT = 0.42

function MeetFigures.showMicrophone(figure: Model?, show: boolean)
	local mic = figure and figure:FindFirstChild(MIC_NAME)
	if figure == nil or mic == nil then
		return
	end
	for _, part in ipairs(mic:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = if show then 0 else 1
		end
	end
	figure:SetAttribute(HandShapeConfig.HeldAttributes.Right, if show then HandShapeConfig.Grip else nil)
end

function MeetFigures.giveMicrophone(figure: Model)
	if figure:FindFirstChild(MIC_NAME) then
		MeetFigures.showMicrophone(figure, true)
		return
	end
	local hand = figure:FindFirstChild("RightHand")
	local mic = if hand and hand:IsA("BasePart") then RoomProps.propCopy("AnnouncerMic", 1) else nil
	if hand == nil or not hand:IsA("BasePart") or mic == nil then
		return
	end
	mic.Name = MIC_NAME
	local size = HandShapeConfig.HandSize[LifterBuild.BuildRules.Spotter] or 1
	-- The model stands upright on its butt (its pivot): its up goes along the hand's forward (the thumb's way with the
	-- arm hanging), through the middle of the closed fingers.
	local inHand = CFrame.fromMatrix(MIC_GRIP * size, Vector3.xAxis, -Vector3.zAxis, Vector3.yAxis) * CFrame.new(0, -MIC_HELD_AT, 0)
	mic:PivotTo(hand.CFrame * inHand)
	for _, part in ipairs(mic:GetDescendants()) do
		if part:IsA("BasePart") then
			BuildParts.decor(part)
			part.Anchored = false
			part.Massless = true
			part.CanQuery = false
			part.CollisionGroup = hand.CollisionGroup
			local weld = Instance.new("Weld")
			weld.Part0 = hand
			weld.Part1 = part
			weld.C0 = hand.CFrame:ToObjectSpace(part.CFrame)
			weld.Parent = part
		end
	end
	mic.Parent = figure
	figure:SetAttribute(HandShapeConfig.HeldAttributes.Right, HandShapeConfig.Grip)
end

--[[
	Builds a `kind` figure in `parent`, standing at `at` (on the floor) and
	looking at `watching`. With `seatTop` (the height of a chair's seat) the
	figure SITS instead: thighs forward on the seat, lower legs down, its hips
	over `at`. Returns the speech bubble's text label (MeetFigures.say shows a
	line in it) and the figure, or nils when no figure could be made (a meet
	works without one). `look` (optional) changes the outfit's top and trousers colours and the name tag (the gym's
	quest coaches, GAME_DESIGN §40.6, each in their lift's colour).
]]
-- build: the body (ClothesConfig.Bodies; the coaches' own, QuestConfig.Coaches[lift].body); nil = the staff build.
export type Look = { top: Color3?, trousers: Color3?, tag: string?, build: string? }
--[[
	Seats a figure's name tag just above the top of the figure (its head, hair or hat), with the tag's BOTTOM edge there
	at every distance (user 2026-11-21: "fix the ui sinking inside the chef, and not staying on top of the character ...
	for every person with a name tag"). The tags are sized in pixels and were hung by their MIDDLE a fixed number of
	studs up, so from far away, where a stud is only a few pixels, the name (at the billboard's bottom) dropped onto
	the chest. Call it again after giving a figure a hat. The Caller's tag is sized in studs and is left alone.
]]
local TAG_GAP = 0.45 -- studs of air between the top of the figure and the tag
function MeetFigures.seatTag(figure: Model)
	local head = figure:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	for _, child in ipairs(figure:GetChildren()) do
		if child:IsA("BillboardGui") and string.sub(child.Name, -3) == "Tag" and child.Name ~= "CallerTag" then
			local box, size = figure:GetBoundingBox()
			local top = box.Position.Y + size.Y / 2
			child.StudsOffset = Vector3.new(0, math.max(top - head.Position.Y, head.Size.Y / 2) + TAG_GAP, 0)
			child.SizeOffset = Vector2.new(0, 0.5) -- its bottom edge sits on that point, whatever the distance
		end
	end
end

function MeetFigures.build(parent: Instance, kind: Kind, at: Vector3, watching: Vector3, seatTop: number?,
	look: Look?): (TextLabel?, Model?)
	local outfit = OUTFITS[kind]
	if look then
		outfit = table.clone(outfit)
		outfit.top = look.top or outfit.top
		outfit.trousers = look.trousers or outfit.trousers
		outfit.tag = look.tag or outfit.tag
	end
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
		return nil, nil
	end
	local figure = result :: Model
	figure.Name = kind
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	local root = figure:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		figure:Destroy()
		return nil, nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- The cartoon body (§38.1: staff get the same bodies; open hands when talking or relaxed, user 2026-11-12), in
	-- their outfit's colours: a tee, joggers, dark sneakers.
	LifterBodyService.prepareFigure(figure, (look and look.build) or LifterBuild.BuildRules.Spotter, {
		Shirt = { item = "Tee", colour = outfit.top },
		Bottom = { item = "Joggers", colour = outfit.trousers },
		Shoes = { item = "Sneakers", colour = Color3.fromRGB(34, 34, 38) },
	})
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
		-- Seated (sitFigure): thighs forward on the seat, lower legs down. Remembered, so the figure can get up and sit
		-- back down (MeetFigures.standUp / sitDown: the Nationals judge and announcer, GAME_DESIGN §39).
		sitFigure(figure, at, seatTop)
	end

	if kind ~= "Referee" then
		-- (A referee gets one only when they have something to read out: the Nationals judge's lift-off.)
		MeetFigures.giveClipboard(figure)
	end

	-- Never in anyone's way, whatever its Humanoid does to collision.
	MeetFigures.makeGhost(figure)

	-- The name tag and the speech bubble over the head.
	local head = figure:FindFirstChild("Head") :: BasePart?
	local billboard = Instance.new("BillboardGui")
	billboard.Name = kind .. "Tag"
	-- The caller's words are for everyone nearby, so they are sized in studs: they shrink with distance and never fill a screen.
	billboard.Size = if kind == "Caller" then UDim2.fromScale(CALLER_BUBBLE_STUDS.X, CALLER_BUBBLE_STUDS.Y)
		elseif kind == "Coach" then UDim2.fromOffset(COACH_BUBBLE.X, COACH_BUBBLE.Y + 34)
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
	tag.Size = if kind == "Caller" then UDim2.fromScale(0.3, 0.2) else UDim2.fromOffset(if kind == "Referee" then 110 else 90, 22)
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
	bubble.Size = if kind == "Caller" then UDim2.fromScale(1, 0.74) else UDim2.new(1, 0, 0, if kind == "Coach" then COACH_BUBBLE.Y else 56)
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
	-- The name just above the head at every distance (not sinking onto the chest from far away).
	MeetFigures.seatTag(figure)
	return line, figure
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
-- (defined further down)
local labelTee: (Model, BasePart, string) -> ()
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

--[[
	"CENTRAL" on a cartoon spotter's tee, front and back: a thin clear card just off the shirt (the tee is a curved
	mesh, so the print can't go on a part face), welded to the torso. Its distance from the chest's centre line comes
	from the build's bar clearances (ClothesConfig: chest and back plus the bar's 0.07 radius; the shirt is in them).
]]
--[[
	The Blender print (SpotterPrint_01, art/scripts/build_spotter_print_01.py): white CENTRAL letters shaped onto the
	spotters' build's tee, front and back, welded to the upper torso where they lie on the shirt (user 2026-11-20: the
	flat card below stood 0.12 - 0.27 studs off the round chest, "if my assessories were floating i would tell you").
	Built in the figure's root space for one build; false when the build differs or the model or rest pose is missing
	(the card below stands in).
]]
local PRINT_BUILD = "Fat"
-- The print's bounds centre in root space (studs: x right, y up, z back), from the build script's BOUNDS line
-- (Blender x, y, z -> root x, z, y).
local PRINT_CENTRE = Vector3.new(0, (0.881 + 1.13) / 2, (-0.702 + 0.695) / 2)
-- That build's upper torso at rest, in root space: its mesh's bounds centre (Blender, CartoonBodies_05_Rigged: 3.7497
-- up on a rig whose root is 3.0 up, 0.179 forward), the same as measured on the Kitchen chef in Studio (2026-11-20:
-- 0.7496 up, 0.179 forward).
local PRINT_TORSO_REST = CFrame.new(0, 0.7497, -0.179)

local function printOnTee(figure: Model, torso: BasePart, build: string): boolean
	if build ~= PRINT_BUILD then
		return false
	end
	local torsoRest = PRINT_TORSO_REST
	local copy = RoomProps.propCopy("SpotterPrint", 1)
	if copy == nil then
		return false
	end
	copy.Name = "SpotterPrint"
	-- In root space (the root at the origin), then each piece welded to the torso by its offset from the torso's rest
	-- place: the rig may still be coming together, so nothing is read from where the parts happen to be.
	local box = copy:GetBoundingBox()
	copy:PivotTo(CFrame.new(PRINT_CENTRE) * box:ToObjectSpace(copy:GetPivot()))
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			local offset = torsoRest:ToObjectSpace(part.CFrame)
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.CFrame = torso.CFrame * offset
			local weld = Instance.new("Weld")
			weld.Part0 = torso
			weld.Part1 = part
			weld.C0 = offset
			weld.Parent = part
		end
	end
	copy.Parent = figure
	return true
end

function labelTee(figure: Model, torso: BasePart, build: string)
	if printOnTee(figure, torso, build) then
		return
	end
	local body = ClothesConfig.Bodies[build]
	if body == nil then
		return
	end
	for _, side in ipairs({ { face = Enum.NormalId.Front, z = -(body.benchBarClear - 0.05) },
		{ face = Enum.NormalId.Back, z = body.squatBarRest - 0.05 } }) do
		local card = Instance.new("Part")
		card.Name = "TeeLabel_" .. side.face.Name
		card.Size = Vector3.new(1.0, 0.3, 0.02)
		card.Transparency = 1
		card.CanCollide = false
		card.CanQuery = false
		card.CanTouch = false
		card.CastShadow = false
		card.Massless = true
		card.CFrame = torso.CFrame * CFrame.new(0, 0.2, side.z)
		card.Parent = figure
		-- A Weld with the offset written out: a WeldConstraint keeps wherever the parts happen to be, and the figure's
		-- rig may still be coming together (labels floating off the spotters, Studio 2026-11-16).
		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = card
		weld.C0 = CFrame.new(0, 0.2, side.z)
		weld.Parent = card
		printTee(card, side.face)
		local gui = card:FindFirstChildOfClass("SurfaceGui")
		local label = gui and gui:FindFirstChildOfClass("TextLabel")
		if label then
			label.Position = UDim2.fromScale(0.5, 0.5)
			label.Size = UDim2.fromScale(1, 1)
		end
	end
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
	-- The cartoon body (§38.1: spotters an average build; with three builds, LifterBuild.BuildRules.Spotter), in the
	-- red tee, black shorts and black shoes.
	local build = LifterBuild.BuildRules.Spotter
	local cartoon = LifterBodyService.prepareFigure(figure, build, {
		Shirt = { item = "Tee", colour = SPOTTER_TEE },
		Bottom = { item = "Shorts", colour = SPOTTER_BLACK },
		Shoes = { item = "Sneakers", colour = SPOTTER_BLACK },
	})
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
			if part ~= root and not cartoon then
				part.Color = SPOTTER_PARTS[part.Name] or skin
			end
		end
	end
	local torso = figure:FindFirstChild("UpperTorso")
	if cartoon and torso and torso:IsA("BasePart") then
		labelTee(figure, torso, build)
	elseif torso and torso:IsA("BasePart") then
		printTee(torso, Enum.NormalId.Front)
		printTee(torso, Enum.NormalId.Back)
	end
	for _, name in ipairs(if cartoon then {} else SPOTTER_COVERS) do
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
