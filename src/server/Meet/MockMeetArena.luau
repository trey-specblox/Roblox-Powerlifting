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
	the gym's competition rack (ComboRack_01) is towards +Z; the head judge sits
	in front of the platform and the two side judges beside it, each with a
	light stand (unlit; the meet lights them in Part 2); the attempt board is on
	the +Z wall above the platform. Black walls with the gym's red competition
	stripe, stage lights over the platform.
]]

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

local MockMeetArena = {}

local FOLDER_NAME = "MockMeetRooms"
local RACK_TEMPLATE = "ComboRack_01"
local WALL = 1 -- wall, floor and ceiling thickness
local PLATFORM_SIZE = 16
local PLATFORM_HEIGHT = 0.6
local PLATFORM_Z = 10 -- the platform's middle, towards the back

local looks = StarterGymConfig.Looks
local WHITE = Color3.fromRGB(255, 255, 255)

export type Room = {
	slot: number,
	model: Model,
	-- Where the lifter stands on arrival, on the floor, facing the platform.
	arrival: CFrame,
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

-- A dark board's text on its `face`: a red title and white lines.
local function boardText(part: BasePart, face: Enum.NormalId, title: string, lines: { string })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	frame.Parent = gui
	local function label(text: string, y: number, height: number, weight: Enum.FontWeight, colour: Color3)
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.Position = UDim2.fromScale(0.05, y)
		textLabel.Size = UDim2.fromScale(0.9, height)
		textLabel.Text = text
		textLabel.TextColor3 = colour
		textLabel.TextScaled = true
		textLabel.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", weight)
		textLabel.Parent = frame
	end
	label(title, 0.05, 0.26, Enum.FontWeight.Heavy, Color3.fromRGB(226, 52, 52))
	local share = 0.62 / #lines
	for index, line in ipairs(lines) do
		label(line, 0.34 + (index - 1) * share, share * 0.86, Enum.FontWeight.Bold, WHITE)
	end
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

	-- The competition platform: a dark base with a wooden top.
	box("Platform_Base", Vector3.new(-half - 0.3, 0, PLATFORM_Z - half - 0.3), Vector3.new(half + 0.3, PLATFORM_HEIGHT - 0.1,
		PLATFORM_Z + half + 0.3), looks.FrontCharcoal)
	box("Platform_Top", Vector3.new(-half, PLATFORM_HEIGHT - 0.1, PLATFORM_Z - half), Vector3.new(half, PLATFORM_HEIGHT,
		PLATFORM_Z + half), looks.Wood)

	-- The three judges: the head judge in front of the platform, a side judge each side.
	-- Each sits on a chair facing the platform's middle, beside a light stand.
	local judges = {
		{ name = "Left", at = Vector3.new(-half - 4, 0, PLATFORM_Z) },
		{ name = "Head", at = Vector3.new(0, 0, PLATFORM_Z - half - 5) },
		{ name = "Right", at = Vector3.new(half + 4, 0, PLATFORM_Z) },
	}
	for index, judge in ipairs(judges) do
		local at = judge.at
		local toPlatform = (Vector3.new(0, 0, PLATFORM_Z) - at).Unit
		local side = toPlatform:Cross(Vector3.yAxis)
		local seatCentre = centre + at
		BuildParts.decor(BuildParts.placed(model, "Judge" .. judge.name .. "_Seat", Vector3.new(1.8, 0.3, 1.8),
			CFrame.lookAt(seatCentre + Vector3.new(0, 1.75, 0), seatCentre + Vector3.new(0, 1.75, 0) + toPlatform), looks.Padding))
		BuildParts.decor(BuildParts.placed(model, "Judge" .. judge.name .. "_Back", Vector3.new(1.8, 2.2, 0.2),
			CFrame.lookAt(seatCentre + Vector3.new(0, 3, 0) - toPlatform * 0.8, seatCentre + Vector3.new(0, 3, 0)), looks.Padding))
		BuildParts.decor(BuildParts.placed(model, "Judge" .. judge.name .. "_Post", Vector3.new(0.25, 1.6, 0.25),
			CFrame.new(seatCentre + Vector3.new(0, 0.8, 0)), looks.SteelBeam))
		-- The light stand beside the chair: a post, a box and the lamp facing the platform.
		local stand = seatCentre + side * 1.8
		BuildParts.placed(model, "JudgeLight" .. index .. "_Post", Vector3.new(0.3, 4.2, 0.3), CFrame.new(stand + Vector3.new(0, 2.1, 0)),
			looks.SteelBeam)
		BuildParts.decor(BuildParts.placed(model, "JudgeLight" .. index .. "_Box", Vector3.new(1.4, 1.4, 0.6),
			CFrame.lookAt(stand + Vector3.new(0, 4.9, 0), stand + Vector3.new(0, 4.9, 0) + toPlatform), looks.Gadget))
		local lamp = BuildParts.decor(BuildParts.placed(model, "JudgeLight" .. index, Vector3.new(1, 1, 0.1),
			CFrame.lookAt(stand + Vector3.new(0, 4.9, 0) + toPlatform * 0.32, stand + Vector3.new(0, 4.9, 0) + toPlatform * 2),
			looks.Gadget))
		lamp:SetAttribute("Judge", judge.name)
	end

	-- The attempt board on the back wall, above the platform.
	local board = decor("AttemptBoard", Vector3.new(-14, 9, hz - 0.4), Vector3.new(14, 21, hz - 0.06), looks.Gadget)
	boardText(board, Enum.NormalId.Front, "ATTEMPT BOARD", { owner.DisplayName, "LIFT  —", "ATTEMPT  1   2   3",
		"WEIGHT  —  KG" })
	-- A banner on each side wall.
	local left = decor("Banner_Left", Vector3.new(-hx + 0.06, 8, -6), Vector3.new(-hx + 0.3, 14, 14), looks.Gadget)
	boardText(left, Enum.NormalId.Right, "CENTRAL MOCK MEET", { "Your own private meet room" })
	local right = decor("Banner_Right", Vector3.new(hx - 0.3, 8, -6), Vector3.new(hx - 0.06, 14, 14), looks.Gadget)
	boardText(right, Enum.NormalId.Left, "CENTRAL MOCK MEET", { "Squat  ·  Bench  ·  Deadlift" })

	-- A bench to wait on by the arrival spot.
	box("WaitBench_Seat", Vector3.new(-hx + 1, 1.5, -hz + 6), Vector3.new(-hx + 3, 1.8, -hz + 16), looks.Wood)
	box("WaitBench_Legs", Vector3.new(-hx + 1.2, 0, -hz + 6.4), Vector3.new(-hx + 2.8, 1.5, -hz + 15.6), looks.SteelBeam)

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
	}, nil
end

-- Removes a room built by build().
function MockMeetArena.clear(room: Room)
	room.model:Destroy()
end

return MockMeetArena
