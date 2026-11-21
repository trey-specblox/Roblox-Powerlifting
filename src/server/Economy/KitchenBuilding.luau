--!strict
--[[
	KitchenBuilding
	Server / Economy

	The Kitchen's buildings and the way in and out (GAME_DESIGN §40.7, user 2026-11-19):

		- W Chews' building (WChewsFront_02, from the user's photo References/W Chews/kitchen1.png) in the front square
		  at KitchenConfig.EntranceOrigin, with an "Enter / Kitchen" prompt at its glass doors
		- W Chews' hall (WChewsHall_01: the fancy front, the kitchen, the back room's shell) round the pan zones, to
		  floor plan 02 (user 2026-11-21), with every copy of the restaurant kit (WChewsKit_01) placed from WChewsLayout
		  (generated from art/scripts/wchews_layout.py, the same list the approved Blender pictures were made from), and a
		  "Leave / Kitchen" prompt at its glass doors
		- entering puts the lifter at the arrival spot facing the chef (tagged KitchenConfig.ArriveTag: also the
		  Teleport menu's KITCHEN stop); leaving puts them in front of the entrance house's door
		- hidden plain blocks for collision (the meshes are decor): the hall's walls, counters, cooking line, islands,
		  tables, display bay and grinder, and the building's body, terrace, steps and handrails
		- the hall's lighting (KitchenLights: blocks that keep the sun out, warm lights in the dining room, white ones
		  in the kitchen)

	Both buildings are placed from one point each, so the map design (last, user) can move them.

	PERFORMANCE: the shell (3,832 triangles) and 281 kit copies (862 parts, about 163,000 triangles if all were in view:
	21 shared meshes), all decor (no collision, no touch, small pieces cast no shadow); about 165 hidden collision blocks
	(60 for walls and big furniture, 104 for the chairs, plants, host stand and button stand).
	The building in the square: 20 parts, 2,988 triangles, 19 hidden collision blocks.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local WChewsLayout = require(Shared:WaitForChild("Config"):WaitForChild("WChewsLayout"))

local ServerFolder = script.Parent.Parent
local RoomProps = require(ServerFolder:WaitForChild("World"):WaitForChild("RoomProps"))
local KitchenLights = require(script.Parent:WaitForChild("KitchenLights"))
local StyledScreen = require(ServerFolder:WaitForChild("World"):WaitForChild("StyledScreen"))

local KitchenBuilding = {}

local MIN_SECONDS_BETWEEN_MOVES = 1.5

-- Kit pieces that get a hidden solid block where they stand: its size at scale 1 (across, height, front to back).
-- (The plant's block is its pot, not its leaves.)
local SOLID_FURNITURE: { [string]: { name: string, across: number, height: number, deep: number } } = {
	WcChair = { name = "Chair", across = 1.6, height = 3.8, deep = 1.6 },
	WcPlant = { name = "Plant", across = 1.6, height = 2.2, deep = 1.6 },
	WcHostStand = { name = "HostStand", across = 3.8, height = 4.4, deep = 2.1 },
	WcButtonPanel = { name = "ButtonPanel", across = 2.8, height = 4.1, deep = 1.9 },
}

local started = false
local lastMove: { [Player]: number } = {}
local outsideSpot: CFrame? = nil

local function collider(parent: Instance, name: string, size: Vector3, at: CFrame)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Transparency = 1
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = at
	part.Parent = parent
end

local function move(player: Player, to: CFrame)
	local now = os.clock()
	if now - (lastMove[player] or -math.huge) < MIN_SECONDS_BETWEEN_MOVES then
		return
	end
	lastMove[player] = now
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(to)
	end
end

local function prompt(parent: Instance, action: string, onTriggered: (Player) -> ())
	local made = Instance.new("ProximityPrompt")
	made.ActionText = action
	made.ObjectText = "Kitchen"
	made.KeyboardKeyCode = Enum.KeyCode.E
	made.HoldDuration = 0
	made.MaxActivationDistance = 12
	made.RequiresLineOfSight = false
	made.Triggered:Connect(onTriggered)
	made.Parent = parent
end

-- A hidden anchored point (for prompts and teleports).
local function point(parent: Instance, name: string, at: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(2, 2, 2)
	part.CFrame = at
	part.Parent = parent
	return part
end

function KitchenBuilding.start()
	if started then
		return
	end
	started = true
	local hallFolder = Workspace:WaitForChild("KitchenHall", 60)
	if hallFolder == nil then
		warn("[KitchenBuilding] no KitchenHall; no Kitchen buildings")
		return
	end
	local hall0 = KitchenConfig.HallOrigin

	-- W Chews' shell round the pan zones (the plain floor stays as the floor's collision, hidden).
	local shell = RoomProps.propCopy("WChewsHall", 1)
	if shell then
		shell.Name = "KitchenHallShell"
		shell:PivotTo(hall0 * KitchenConfig.HallShellAt)
		-- No piece of the shell casts a shadow: with these thin ceilings and walls shading the sun, parts of the floor
		-- fell into blue shade while others stayed sunlit (Studio 2026-11-21). KitchenLights' thick blocks outside the
		-- walls keep the sun out instead, and its lights light the rooms.
		for _, part in ipairs(shell:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CastShadow = false
			end
		end
		shell.Parent = hallFolder
		local floor = hallFolder:FindFirstChild("HallFloor_Temporary")
		if floor and floor:IsA("BasePart") then
			floor.Transparency = 1
		end
	else
		warn("[KitchenBuilding] W Chews' hall model didn't load; the hall has no walls to see")
	end
	-- Collision, in PLAN space (x across, y front to back; KitchenConfig.planSpot): a block from the floor up.
	local blocks = Instance.new("Folder")
	blocks.Name = "KitchenHallWalls"
	blocks.Parent = hallFolder
	local function block(name: string, x0: number, x1: number, y0: number, y1: number, height: number)
		collider(blocks, name, Vector3.new(math.abs(x1 - x0), height, math.abs(y1 - y0)),
			hall0 * KitchenConfig.planSpot((x0 + x1) / 2, (y0 + y1) / 2, height / 2))
	end
	-- The kitchen's walls (x -285..285, y -20..265), the fancy front's (x -80..80, y -110..-20) with its glass doors
	-- shut (the Leave prompt is the way out), and the back room's (x 195..285, y 267..337) with its door shut for now.
	block("KitchenLeft", -287, -285, -22, 267, 40)
	block("KitchenRight", 285, 287, -22, 267, 40)
	block("KitchenBack", -287, 287, 265, 267, 40)
	block("KitchenFrontLeft", -287, -80, -22, -20, 40)
	block("KitchenFrontRight", 80, 287, -22, -20, 40)
	block("FrontLeft", -82, -80, -112, -20, 26)
	block("FrontRight", 80, 82, -112, -20, 26)
	block("FrontGlass", -82, 82, -112, -110, 26)
	block("ColumnLeft", -51.2, -48.8, -22.2, -19.8, 14)
	block("ColumnRight", 48.8, 51.2, -22.2, -19.8, 14)
	-- The furniture you can't walk through.
	block("ServiceCounter", -48, 48, -32, -28, 4)
	block("CookingLineLeft", -272, -92, -20, -15, 7)
	block("CookingLineRight", 92, 272, -20, -15, 7)
	block("BackWallLine", -280, 215.5, 257.5, 265, 8)
	for _, y in ipairs({ 150, 190, 230 }) do
		block("Island", -29, 29, y - 5, y + 5, 6.5)
	end
	local bay, grinderAt = WChewsLayout.Bay, WChewsLayout.Grinder
	block("DisplayBay", bay.X - 13, bay.X + 13, bay.Y - 13, bay.Y + 13, 8)
	block("Grinder", grinderAt.X - 6.5, grinderAt.X + 6.5, grinderAt.Y - 13.5, grinderAt.Y + 13.5, 14)

	-- Every copy of the restaurant kit, where the layout says (its own origin at the plan point; a copy's pivot is the
	-- bottom centre of its bounds, PivotOffset from that origin).
	local kit = Instance.new("Folder")
	kit.Name = "WChewsKit"
	kit.Parent = hallFolder
	local placed = 0
	for index, placement in ipairs(WChewsLayout.Placements) do
		local item, colourway, x, y, z, turn, scale = table.unpack(placement)
		local copy = RoomProps.propCopy(item, colourway)
		local offset = WChewsLayout.PivotOffset[item]
		if copy and offset then
			copy.Name = item
			for _, part in ipairs(copy:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CastShadow = false -- (as the shell; and 862 fewer shadow casters)
				end
			end
			copy:ScaleTo(scale)
			copy:PivotTo(hall0 * KitchenConfig.planSpot(x, y, z, turn) * CFrame.new(Vector3.new(-offset.X, offset.Z, offset.Y) * scale))
			copy.Parent = kit
			placed += 1
			if item == "WcTable" then
				block("Table", x - 2.2, x + 2.2, y - 2.2, y + 2.2, 2.8)
			end
			-- The smaller furniture is solid too (user 2026-11-21: "Make furniture solid"): a block of the piece's own
			-- footprint, turned with it.
			local solid = SOLID_FURNITURE[item]
			if solid then
				collider(blocks, solid.name, Vector3.new(solid.across, solid.height, solid.deep) * scale,
					hall0 * KitchenConfig.planSpot(x, y, z + solid.height * scale / 2, turn))
			end
		end
		if index % 20 == 0 then
			task.wait()
		end
	end
	if placed < #WChewsLayout.Placements then
		warn(string.format("[KitchenBuilding] only %d of %d W Chews kit pieces placed (a model didn't load)", placed,
			#WChewsLayout.Placements))
	end

	-- The sun kept out, and the rooms' own lights (the pendants and the chandelier just placed carry theirs).
	local lights = KitchenLights.build(hallFolder, kit, hall0)

	-- Where lifters arrive: facing the chef (also the Teleport menu's KITCHEN stop).
	local arrive = point(hallFolder, "KitchenArrive", hall0 * KitchenConfig.ArriveSpot)
	arrive:AddTag(KitchenConfig.ArriveTag)

	-- The entrance building in the front square.
	local outside = Instance.new("Folder")
	outside.Name = "KitchenEntrance"
	outside.Parent = Workspace
	-- W Chews' building (WChewsFront_01, from the user's photo; user 2026-11-21: "update the shell, so it goes with the
	-- inside and reference photos", "Upload the new building"). It replaced the cream cottage (KitchenHouse).
	local house = RoomProps.propCopy("WChewsFront", 1)
	local found = house and house:FindFirstChild("WChewsFront_Door", true)
	local door: BasePart? = if found and found:IsA("BasePart") then found else nil
	-- In front of the doors, facing out (the building's front is its -Z, turned toward the gym). Without the model:
	-- a spot in front of the entrance point, so the Enter prompt still works.
	local front = KitchenConfig.EntranceOrigin.LookVector
	local away = KitchenConfig.EntranceOrigin.Position + front * 20
	local outsideAt = CFrame.lookAt(away + Vector3.new(0, 3, 0), away + front * 14 + Vector3.new(0, 3, 0))
	local enterAt = CFrame.new(away + Vector3.new(0, 3, 0))
	if house and door then
		house.Name = "WChewsFront"
		house:PivotTo(KitchenConfig.EntranceOrigin)
		-- The small and flat pieces cast no shadow (the walls and roofs do: it is a building in the sun).
		for _, name in ipairs({ "Glass", "Mullions", "Inside", "Strips", "StepLights", "Rails", "Carpet", "Brass", "Door",
			"Deck", "Furniture", "Cushions", "Pots" }) do
			local piece = house:FindFirstChild("WChewsFront_" .. name, true)
			if piece and piece:IsA("BasePart") then
				piece.CastShadow = false
			end
		end
		house.Parent = outside
		-- A point of the MODEL's own space (art/scripts/build_wchews_front_01.py: x across, y front to back with the
		-- front at -y, z up) in the world, measured from the door leaves, whose middle is the model's (0, -14.92, 6.825).
		-- A Blender point (x, y, z) lands at (-x, z, y) here, as every model's does (KitchenConfig.planSpot).
		local base = KitchenConfig.EntranceOrigin.Rotation + door.Position
		local function spot(x: number, y: number, z: number): CFrame
			return base * CFrame.new(-x, z - 6.825, y + 14.92)
		end
		-- Collision (the meshes are decor): a block from the ground up between two corners of the model's space.
		local function wall(name: string, x0: number, x1: number, y0: number, y1: number, height: number)
			collider(outside, name, Vector3.new(math.abs(x1 - x0), height, math.abs(y1 - y0)),
				spot((x0 + x1) / 2, (y0 + y1) / 2, height / 2))
		end
		wall("FrontLeftWing", -39.8, -9.6, -11, 15, 27)
		wall("FrontEntrance", -9.6, 9.6, -15, 15, 29) -- (the glass box and its doors: shut; the Enter prompt is the way in)
		wall("FrontRightWing", 9.6, 24.6, -11, 15, 27)
		wall("FrontTerraceBack", 24.6, 40, -3, 15, 18)
		wall("FrontTerrace", 25.2, 40, -15, -3, 5)
		wall("FrontPlanter", 24.8, 40.4, -17.6, -15, 2.4)
		-- The terrace's glass balustrade (a lifter can jump up there from the planter: the deck is 5 up, the handrail
		-- 7.55) and its two tables: a block from `low` to `high` above the ground.
		local function raised(name: string, x0: number, x1: number, y0: number, y1: number, low: number, high: number)
			collider(outside, name, Vector3.new(math.abs(x1 - x0), high - low, math.abs(y1 - y0)),
				spot((x0 + x1) / 2, (y0 + y1) / 2, (low + high) / 2))
		end
		raised("TerraceRailFront", 25.2, 40, -15.05, -14.75, 5, 7.6)
		raised("TerraceRailEnd", 39.75, 40.05, -15, -3.2, 5, 7.6)
		raised("TerraceRailSide", 25.15, 25.45, -15, -11, 5, 7.6)
		for _, at in ipairs({ Vector2.new(29.2, -10), Vector2.new(35.6, -7.2) }) do
			raised("TerraceTable", at.X - 1.2, at.X + 1.2, at.Y - 1.2, at.Y + 1.2, 5, 7.7)
		end
		-- The four steps (0.4 high, 2.2 deep each; the top one is the landing in front of the doors) and the handrails.
		for step = 1, 4 do
			wall("FrontStep" .. step, -21, 21, -19 - 2.2 * (5 - step), -11, 0.4 * step)
		end
		for _, x in ipairs({ -15, -7, 7, 15 }) do
			wall("FrontRail", x - 0.15, x + 0.15, -28, -18.4, 4.8)
		end
		-- Its name floats over the roof in the game's style, like the gym's and the meets' (user 2026-11-21: "i told
		-- you not to have just boring squares for signs, and to do the floating name UI thing"). The restaurant is
		-- W Chews (user 2026-11-21). Each player's own cook time floats on top of it (KitchenSignTimer, client).
		local box, size = house:GetBoundingBox()
		local sign = StyledScreen.floatAbove(outside, box.Position, box.Position.Y + size.Y / 2, "W CHEWS",
			{ "Steaks for a training boost" }, "star", 40, 16, 6, 260)
		sign.gui.Parent.Name = "KitchenSignAnchor"
		-- On the landing (1.6 up), in front of the doors.
		outsideAt = CFrame.lookAt(spot(0, -18.5, 4.6).Position, spot(0, -40, 4.6).Position)
		enterAt = spot(0, -16.5, 4.6)
	else
		warn("[KitchenBuilding] W Chews' building didn't load; the Enter prompt stands in the square without it")
	end
	outsideSpot = outsideAt
	local enter = point(outside, "KitchenDoor", enterAt)
	prompt(enter, "Enter", function(player)
		move(player, (arrive :: Part).CFrame)
	end)

	-- The hall's EXIT door: back outside the house.
	local exit = point(hallFolder, "KitchenExit", hall0 * KitchenConfig.ExitSpot)
	prompt(exit, "Leave", function(player)
		move(player, outsideAt)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastMove[player] = nil
	end)
	print(string.format("[KitchenBuilding] entrance at %s, hall shell %s, %d lights", tostring(KitchenConfig.EntranceOrigin.Position),
		tostring(shell ~= nil), lights))
end

-- In front of the entrance house's door (for anything that sends a lifter out of the Kitchen), or nil before start.
function KitchenBuilding.outside(): CFrame?
	return outsideSpot
end

return KitchenBuilding
