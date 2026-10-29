--!strict
--[[
	MockMeetArena
	Server / Meet

	Builds and clears the private Mock Meet rooms (GAME_DESIGN.md §29.10, user
	2026-10-27: "teleports them into their own Mock meet room. Just to make sure
	its not crowded, or there is no line"). One room per player in a meet, built
	on demand in its own slot far from the gym (MockMeetConfig.Origin, Spacing),
	and destroyed when the player leaves. It only builds and clears; who is in
	which room is MockMeetService's job.

	The room, in its own frame (X across, Z deep, Y up; 0,0,0 = the middle of
	the floor): the lifter arrives at the -Z end; the competition platform with
	the gym's competition rack (ComboRack_01) is towards +Z; the lifter's COACH
	stands at the front corner of the platform, watching (user 2026-10-28: "the
	coach will be watching ... for a mock meet we do not need refs", so there are
	no judges here); the attempt board is on the +Z wall above the platform.
	Black walls with the gym's red competition stripe, stage lights over the
	platform.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local MockMeetConfig = require(ConfigFolder:WaitForChild("MockMeetConfig"))
local StarterGymConfig = require(ConfigFolder:WaitForChild("StarterGymConfig"))

local ServerFolder = script.Parent.Parent
local BuildParts = require(ServerFolder:WaitForChild("World"):WaitForChild("BuildParts"))
local RackConfigurator = require(ServerFolder:WaitForChild("Training"):WaitForChild("RackConfigurator"))
local RoomProps = require(ServerFolder:WaitForChild("World"):WaitForChild("RoomProps"))
local StyledScreen = require(ServerFolder:WaitForChild("World"):WaitForChild("StyledScreen"))

local MockMeetArena = {}

local FOLDER_NAME = "MockMeetRooms"
local RACK_TEMPLATE = "ComboRack_01"
local WALL = 1 -- wall, floor and ceiling thickness
local PLATFORM_SIZE = 16
local PLATFORM_HEIGHT = 0.6
local PLATFORM_Z = 10 -- the platform's middle, towards the back
local LIFT_SPOT_IN_FRONT = 4 -- how far in front of the rack's centre the lifter stands

local looks = StarterGymConfig.Looks
local WHITE = Color3.fromRGB(255, 255, 255)

export type Room = {
	slot: number,
	model: Model,
	-- Where the lifter stands on arrival, on the floor, facing the platform.
	arrival: CFrame,
	-- Where the lifter stands for a lift: on the platform in front of the rack, facing the front.
	liftSpot: CFrame,
	-- The coach's speech bubble (nil if the coach could not be built).
	coachLine: TextLabel?,
}

local function slotCentre(slot: number): Vector3
	return MockMeetConfig.Origin + Vector3.new((slot - 1) * MockMeetConfig.SpacingStuds, 0, 0)
end

local function roomsFolder(): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

-- A board's screen on its face that looks along `out`, in the game's one style (StyledScreen); `mark` picks
-- its heading's mark.
local function boardText(part: BasePart, out: Vector3, title: string, lines: { string }, mark: string?)
	StyledScreen.build(part, StyledScreen.faceToward(part, out), title, lines, mark, 30)
end

--[[
	Hangs `copy` (a wall prop from RoomProps.propCopy, front toward its pivot's -Z)
	on a wall: its front looks along `out`, the back of its bounds touches the wall
	plane through `wallPoint`, and its piece `screen` is centred on `screenAt`
	along the wall.
]]
local function hangOnWall(copy: Model, screen: BasePart, wallPoint: Vector3, out: Vector3, screenAt: Vector3)
	copy:PivotTo(CFrame.lookAt(screenAt, screenAt + out))
	local box, size = copy:GetBoundingBox()
	local back = box.Position - out * size.Z / 2
	local toScreen = screenAt - screen.Position
	local alongWall = toScreen - out * toScreen:Dot(out)
	copy:PivotTo(copy:GetPivot() + alongWall + out * (wallPoint - back):Dot(out))
end
--[[
	The lifter's coach (GAME_DESIGN §22: what a coach does is still to be
	decided; for now they watch and react). A standard Roblox figure in coach
	colours (navy top, grey trousers) with a clipboard, a COACH name tag and a
	speech bubble, standing at `at` and looking at `watching`. Anchored and not
	solid, so they never get in the lifter's way. Returns the bubble's text, or
	nil when no figure could be made (the meet works without one).
]]
local COACH_COLOURS = {
	skin = Color3.fromRGB(198, 140, 104),
	top = Color3.fromRGB(28, 40, 78),
	trousers = Color3.fromRGB(62, 64, 70),
}
local function buildCoach(model: Model, at: Vector3, watching: Vector3): TextLabel?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = COACH_COLOURS.skin
	description.LeftArmColor = COACH_COLOURS.skin
	description.RightArmColor = COACH_COLOURS.skin
	description.TorsoColor = COACH_COLOURS.top
	description.LeftLegColor = COACH_COLOURS.trousers
	description.RightLegColor = COACH_COLOURS.trousers
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or result == nil then
		warn("[MockMeetArena] no coach figure: " .. tostring(result))
		return nil
	end
	local coach = result :: Model
	coach.Name = "Coach"
	local humanoid = coach:FindFirstChildOfClass("Humanoid")
	local root = coach:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		coach:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, part in ipairs(coach:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	root.Anchored = true
	local height = humanoid.HipHeight + root.Size.Y / 2
	local standAt = at + Vector3.new(0, height, 0)
	coach:PivotTo(CFrame.lookAt(standAt, Vector3.new(watching.X, standAt.Y, watching.Z)))
	coach.Parent = model

	-- A clipboard held in front of the chest.
	local chest = root.CFrame * CFrame.new(0, 0.2, -0.9) * CFrame.Angles(math.rad(-25), 0, 0)
	BuildParts.decor(BuildParts.placed(coach, "Clipboard", Vector3.new(1.1, 1.4, 0.08), chest, looks.Wood))
	BuildParts.decor(BuildParts.placed(coach, "Clipboard_Paper", Vector3.new(0.9, 1.15, 0.02),
		chest * CFrame.new(0, -0.05, -0.05), looks.LaneWhite))

	-- The name tag and the speech bubble over the head.
	local head = coach:FindFirstChild("Head") :: BasePart?
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CoachTag"
	billboard.Size = UDim2.fromOffset(220, 90)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 80
	billboard.Adornee = head or root
	billboard.Parent = coach
	local tag = Instance.new("TextLabel")
	tag.Name = "Name"
	tag.AnchorPoint = Vector2.new(0.5, 1)
	tag.Position = UDim2.fromScale(0.5, 1)
	tag.Size = UDim2.fromOffset(90, 22)
	tag.Rotation = -4
	tag.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	tag.Text = "COACH"
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
	-- left side and a tail pointing at the coach.
	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.new(1, 0, 0, 56)
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

-- The gym's competition rack on the platform, set up like a gym rack but without the
-- station tag (nobody trains here). Returns false, and the reason, if it could not be built.
local function placeRack(model: Model, centre: Vector3): (boolean, string?)
	local templates = ServerStorage:FindFirstChild("RackTemplates")
	local template = templates and templates:FindFirstChild(RACK_TEMPLATE)
	if template == nil or not template:IsA("Model") then
		return false, "ServerStorage.RackTemplates." .. RACK_TEMPLATE .. " is missing"
	end
	-- Clone() returns nil when the template's Archivable is off, despite its type.
	local rack = template:Clone() :: Model?
	if rack == nil then
		return false, RACK_TEMPLATE .. " could not be cloned"
	end
	local ok, problem = RackConfigurator.configure(rack, RACK_TEMPLATE)
	if not ok then
		rack:Destroy()
		return false, problem
	end
	rack.Name = "CompetitionRack"
	rack:SetAttribute("RackTemplate", RACK_TEMPLATE)
	local standHeight = RackConfigurator.StandPointSize.Y / 2
	rack:PivotTo(CFrame.new(centre + Vector3.new(0, PLATFORM_HEIGHT + standHeight, PLATFORM_Z)))
	rack.Parent = model
	return true, nil
end

--[[
	Builds the private room for `slot` and returns it, or nil and the reason.
	Nothing is left behind on failure.
]]
function MockMeetArena.build(slot: number, owner: Player): (Room?, string?)
	local centre = slotCentre(slot)
	local size = MockMeetConfig.RoomSize
	local hx, hz, h = size.X / 2, size.Z / 2, size.Y

	local model = Instance.new("Model")
	model.Name = "MockMeetRoom_" .. slot
	model:SetAttribute("Slot", slot)
	model:SetAttribute("Owner", owner.UserId)

	-- A box between two corners given in the room's own frame.
	local function box(name: string, low: Vector3, high: Vector3, look: StarterGymConfig.Look): BasePart
		return BuildParts.box(model, name, centre + low, centre + high, look)
	end
	local function decor(name: string, low: Vector3, high: Vector3, look: StarterGymConfig.Look): BasePart
		return BuildParts.decor(box(name, low, high, look))
	end
	-- A solid box nobody sees: it stops players walking through a 3D prop (props are decor).
	local function solid(name: string, low: Vector3, high: Vector3): BasePart
		local part = box(name, low, high, looks.Glass)
		part.Transparency = 1
		part.CastShadow = false
		return part
	end
	-- A coloured copy of the Blender prop `item` (MockMeet_01) in the room, or nil if its asset did not load
	-- (the room then builds the old blocks).
	local function prop(name: string, item: string): Model?
		local copy = RoomProps.propCopy(item, 1)
		if copy then
			copy.Name = name
			copy.Parent = model
		end
		return copy
	end

	-- The shell: floor, ceiling, four walls (solid, so nobody can walk or fall out).
	box("Floor", Vector3.new(-hx - WALL, -WALL, -hz - WALL), Vector3.new(hx + WALL, 0, hz + WALL), looks.MaxBlack)
	box("Ceiling", Vector3.new(-hx - WALL, h, -hz - WALL), Vector3.new(hx + WALL, h + WALL, hz + WALL), looks.MaxBlack)
	box("Wall_Back", Vector3.new(-hx - WALL, 0, hz), Vector3.new(hx + WALL, h, hz + WALL), looks.MaxBlack)
	box("Wall_Front", Vector3.new(-hx - WALL, 0, -hz - WALL), Vector3.new(hx + WALL, h, -hz), looks.MaxBlack)
	box("Wall_Left", Vector3.new(-hx - WALL, 0, -hz), Vector3.new(-hx, h, hz), looks.MaxBlack)
	box("Wall_Right", Vector3.new(hx, 0, -hz), Vector3.new(hx + WALL, h, hz), looks.MaxBlack)
	-- The gym's red competition stripe and white pinstripe round all four walls.
	local stripes: { { name: string, y0: number, y1: number, look: StarterGymConfig.Look } } = {
		{ name = "Red", y0 = 2.9, y1 = 3.5, look = looks.PlateRed },
		{ name = "White", y0 = 3.62, y1 = 3.72, look = looks.LaneWhite },
	}
	for _, stripe in ipairs(stripes) do
		local name, y0, y1, look = stripe.name, stripe.y0, stripe.y1, stripe.look
		decor("Stripe_" .. name .. "_Back", Vector3.new(-hx, y0, hz - 0.06), Vector3.new(hx, y1, hz), look)
		decor("Stripe_" .. name .. "_Front", Vector3.new(-hx, y0, -hz), Vector3.new(hx, y1, -hz + 0.06), look)
		decor("Stripe_" .. name .. "_Left", Vector3.new(-hx, y0, -hz), Vector3.new(-hx + 0.06, y1, hz), look)
		decor("Stripe_" .. name .. "_Right", Vector3.new(hx - 0.06, y0, -hz), Vector3.new(hx, y1, hz), look)
	end
	-- A carpet over the floor, and a red runway from the arrival spot to the platform.
	decor("Carpet", Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0.04, hz), looks.FrontCharcoal)
	local half = PLATFORM_SIZE / 2
	decor("Runway", Vector3.new(-2, 0.04, -hz + 3), Vector3.new(2, 0.08, PLATFORM_Z - half), looks.PlateRed)

	-- The competition platform: the Blender model (oak planks in the middle, rubber mats on the sides, a
	-- navy base, CENTRAL in front of the rack), its top PLATFORM_HEIGHT up, on a hidden solid block.
	local platform = prop("Platform", "MeetPlatform")
	if platform then
		platform:PivotTo(CFrame.new(centre + Vector3.new(0, 0, PLATFORM_Z)))
		solid("Platform_Solid", Vector3.new(-half - 0.3, 0, PLATFORM_Z - half - 0.3), Vector3.new(half + 0.3, PLATFORM_HEIGHT,
			PLATFORM_Z + half + 0.3))
	else
		box("Platform_Base", Vector3.new(-half - 0.3, 0, PLATFORM_Z - half - 0.3), Vector3.new(half + 0.3, PLATFORM_HEIGHT - 0.1,
			PLATFORM_Z + half + 0.3), looks.FrontCharcoal)
		box("Platform_Top", Vector3.new(-half, PLATFORM_HEIGHT - 0.1, PLATFORM_Z - half), Vector3.new(half, PLATFORM_HEIGHT,
			PLATFORM_Z + half), looks.Wood)
	end

	-- The lifter's coach, watching from the front corner of the platform (no judges in a Mock Meet).
	local liftAt = centre + Vector3.new(0, PLATFORM_HEIGHT, PLATFORM_Z - LIFT_SPOT_IN_FRONT)
	local coachLine = buildCoach(model, centre + Vector3.new(half + 3, 0, PLATFORM_Z - half + 1), liftAt)

	-- The attempt board on the back wall, above the platform: the screen (28 x 12, 9 to 21 up) in the Blender
	-- frame with its CENTRAL header. The screen piece is named "AttemptBoard" and sits in the room's model,
	-- where setBoard finds it.
	local boardOut = -Vector3.zAxis
	local boardFrame = prop("AttemptBoardFrame", "MeetBoard")
	local boardScreen = boardFrame and boardFrame:FindFirstChild("MeetBoard_Screen", true) :: BasePart?
	local board: BasePart
	if boardFrame and boardScreen then
		hangOnWall(boardFrame, boardScreen, centre + Vector3.new(0, 0, hz - 0.06), boardOut, centre + Vector3.new(0, 15, hz))
		boardScreen.Name = "AttemptBoard"
		boardScreen.Parent = model
		board = boardScreen
	else
		if boardFrame then
			boardFrame:Destroy()
		end
		board = decor("AttemptBoard", Vector3.new(-14, 9, hz - 0.4), Vector3.new(14, 21, hz - 0.06), looks.Gadget)
	end
	boardText(board, boardOut, "ATTEMPT BOARD", { owner.DisplayName, "LIFT  —", "ATTEMPT  1   2   3", "WEIGHT  —  KG" },
		"bar")
	-- A banner on each side wall (20 x 6, 8 to 14 up): the Blender banner (cloth between two rails), one
	-- mesh for both, or a flat block.
	local banners: { { side: string, x: number, title: string, lines: { string }, mark: string } } = {
		{ side = "Left", x = -hx, title = "MOCK MEET", lines = { "Your own private meet room", "Your coach is watching" },
			mark = "star" },
		{ side = "Right", x = hx, title = "THE BIG THREE", lines = { "Squat  ·  Bench  ·  Deadlift", "3 attempts each" },
			mark = "dots" },
	}
	for _, banner in ipairs(banners) do
		local out = Vector3.new(-math.sign(banner.x), 0, 0)
		local wallAt = centre + Vector3.new(banner.x, 0, 0)
		local unit = prop("Banner_" .. banner.side, "MeetBanner")
		local cloth = unit and unit:FindFirstChild("MeetBanner_Cloth", true) :: BasePart?
		local face: BasePart
		if unit and cloth then
			hangOnWall(unit, cloth, wallAt, out, centre + Vector3.new(banner.x, 11, 4))
			face = cloth
		else
			if unit then
				unit:Destroy()
			end
			local x0 = banner.x + out.X * 0.06
			local x1 = banner.x + out.X * 0.3
			face = decor("Banner_" .. banner.side, Vector3.new(math.min(x0, x1), 8, -6), Vector3.new(math.max(x0, x1), 14, 14),
				looks.Gadget)
		end
		boardText(face, out, banner.title, banner.lines, banner.mark)
	end

	-- A bench to wait on by the arrival spot, along the left wall facing into the room: the Blender bench
	-- (oak slats, yellow frame) on a hidden solid block, or blocks.
	local benchLow, benchHigh = Vector3.new(-hx + 1, 0, -hz + 6), Vector3.new(-hx + 3, 1.8, -hz + 16)
	local bench = prop("WaitBench", "MeetBench")
	if bench then
		local at = centre + Vector3.new((benchLow.X + benchHigh.X) / 2, 0, (benchLow.Z + benchHigh.Z) / 2)
		bench:PivotTo(CFrame.lookAt(at, at + Vector3.xAxis))
		solid("WaitBench_Solid", benchLow, benchHigh)
	else
		box("WaitBench_Seat", Vector3.new(-hx + 1, 1.5, -hz + 6), Vector3.new(-hx + 3, 1.8, -hz + 16), looks.Wood)
		box("WaitBench_Legs", Vector3.new(-hx + 1.2, 0, -hz + 6.4), Vector3.new(-hx + 2.8, 1.5, -hz + 15.6), looks.SteelBeam)
	end

	-- Light: stage lights over the platform, and panels over the rest of the room
	-- (Lighting.Ambient is black, so every room brings its own).
	for _, x in ipairs({ -6, 0, 6 }) do
		local can = decor("StageLight_" .. (x / 6 + 2), Vector3.new(x - 1, h - 1, PLATFORM_Z - 1), Vector3.new(x + 1, h - 0.2,
			PLATFORM_Z + 1), looks.GlowWhite)
		BuildParts.surfaceLight(can, Enum.NormalId.Bottom, 24, 2.2, 70)
	end
	for _, z in ipairs({ -hz + 8, -hz + 22, -hz + 36, -hz + 50, -hz + 64 }) do
		for _, x in ipairs({ -18, 18 }) do
			local panel = decor(string.format("CeilingLight_%d_%d", x, z), Vector3.new(x - 3, h - 0.2, z - 3),
				Vector3.new(x + 3, h, z + 3), looks.GlowWhite)
			BuildParts.surfaceLight(panel, Enum.NormalId.Bottom, 36, 2.4, 100)
		end
	end
	-- A wash of light on the back wall, so the attempt board and the platform stand out.
	local wash = decor("BoardWash", Vector3.new(-14, h - 0.6, hz - 8), Vector3.new(14, h - 0.2, hz - 6), looks.GlowWhite)
	BuildParts.surfaceLight(wash, Enum.NormalId.Bottom, 30, 1.6, 120)

	local placed, problem = placeRack(model, centre)
	if not placed then
		model:Destroy()
		return nil, problem
	end

	model.PrimaryPart = model:FindFirstChild("Floor") :: BasePart
	model.Parent = roomsFolder()

	local arrivalAt = centre + Vector3.new(0, 0, -hz + 5)
	return {
		slot = slot,
		model = model,
		arrival = CFrame.lookAt(arrivalAt, arrivalAt + Vector3.zAxis),
		liftSpot = CFrame.lookAt(liftAt, liftAt - Vector3.zAxis),
		coachLine = coachLine,
	}, nil
end

-- Removes a room built by build().
function MockMeetArena.clear(room: Room)
	room.model:Destroy()
end

-- What the coach says in the speech bubble over their head; nil hides it.
function MockMeetArena.coachSays(room: Room, line: string?)
	local label = room.coachLine
	if label == nil or label.Parent == nil then
		return
	end
	label.Text = line or ""
	local bubble = label.Parent :: GuiObject
	bubble.Visible = line ~= nil
end

-- Rewrites the attempt board: its title and lines.
function MockMeetArena.setBoard(room: Room, lines: { string })
	local board = room.model:FindFirstChild("AttemptBoard")
	if board == nil or not board:IsA("BasePart") then
		return
	end
	local old = board:FindFirstChild("Writing")
	if old then
		old:Destroy()
	end
	boardText(board, -Vector3.zAxis, "ATTEMPT BOARD", lines, "bar")
end

return MockMeetArena
