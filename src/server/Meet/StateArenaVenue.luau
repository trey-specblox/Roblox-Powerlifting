--!strict
--[[
	StateArenaVenue
	Server / Meet

	The State Championship arena (GAME_DESIGN.md §36, the user's reference
	photos in §36.1), built once when the server starts, far from the gym
	(StateArenaConfig.Origin), and its ENTRANCE BUILDING across the plaza in
	front of the gym (the domed building with three arches, facing the gym's
	doors), whose doors take a player in. Every
	piece is StateArena_01 (art/scripts/build_state_arena_01.py): the models
	were made in the arena's own frame, so each template's pivot is where the
	piece sits in that frame and `arena * turn * pivot` puts it in place.

	The arena, in its own frame (0,0,0 = the floor's middle, Y up, the MAIN
	stand toward -Z):
		FLOOR      round, radius 80, with the grey mat; the 4 racks in a row
		           across the middle (x -45, -15, 15, 45) facing the main stand,
		           each on a platform with its screen gantry (and the CENTRAL
		           backdrop inside it) behind it and the judges' table in
		           front; a barricade line round the meet area (in front of
		           the judges, down both sides); behind the gantries the
		           WARM-UP area, rows of racks (looks only for now)
		BOWL       24 slices of seats all round: the lower tier, a walkway (where
		           a visitor arrives, on the main side, and the EXIT), the upper
		           tier, the suites, the outer wall
		ROOF       24 slices of the lattice dome, the centre cube hanging over
		           the floor, the flag, banners round the top, the name signs at
		           both ends

	Hidden solids make the stands walkable: a slope per tier per slice (through
	the middles of the rows), the walkway, the suites and the outer wall, and the
	low wall round the floor (spectators may hop it). The MEET AREA (inside the
	barricades, warm-up included) is closed by walls too high to jump over that
	only competing lifters pass (StateArenaConfig.MeetBarrierGroup). It only
	builds; StateArenaService runs the visits.

	PERFORMANCE: the bowl is one seat mesh pair repeated 24 times (about
	150,000 triangles in all); 4 rack spotlights and 8 bowl lights; only the
	dome and the stands' shell cast shadows (72 parts). The State
	meet (live screens, turns) comes later.
]]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local StateArenaConfig = require(ConfigFolder:WaitForChild("StateArenaConfig"))
local StarterGymConfig = require(ConfigFolder:WaitForChild("StarterGymConfig"))

local ServerFolder = script.Parent.Parent
local WorldFolder = ServerFolder:WaitForChild("World")
local BuildParts = require(WorldFolder:WaitForChild("BuildParts"))
local RoomProps = require(WorldFolder:WaitForChild("RoomProps"))
local MockMeetArena = require(script.Parent:WaitForChild("MockMeetArena"))
local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))

local StateArenaVenue = {}

local MODEL_NAME = "StateArenaVenue"
local ENTRANCE_NAME = "StateArenaEntrance"
local WEDGES = 24
local WEDGE = math.rad(15)
-- The bowl, as modelled (build_state_arena_01.py): radii from the middle, heights above the floor.
local FLOOR_R = 80
local FLOOR_WALL_R = 82
local FLOOR_WALL_TOP = 4 -- the low wall round the floor, as modelled: spectators may hop it (user 2026-11-01)
-- The slices of the floor's wall behind the warm-up area (between the meet area's side lines, toward +Z): there the
-- wall is part of the meet area's barrier, too high to jump over (StateArenaConfig.MeetBarrierHeightStuds).
local BACK_WALL_SLICES = { [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true }
-- The walking slopes run through the middles of the rows' treads: (radius, height) at each end.
local LOWER_SLOPE = { Vector2.new(82, 4.8), Vector2.new(112, 20.8) }
local UPPER_SLOPE = { Vector2.new(116, 27), Vector2.new(146, 47) }
local WALK_R0, WALK_R1, WALK_Y = 112, 116, 20
local WALK_STEP_Y = 23.5 -- a step at the walkway's back, half way up to the upper tier's first row
local SUITE_R0, SUITE_R1, SUITE_TOP = 146, 154, 56
local WALL_R0, WALL_R1, WALL_TOP = 154, 156, 80
-- The props, as in the Blender preview.
local CUBE_Y = 62
local GANTRY_BEHIND = 12
-- The meet area's barricade line (user 2026-11-01: "make sure the meet area is properly barricaded"): LocalMeet_02's
-- Barricade (7 wide, 3.3 high) in front of the judges' tables and down both sides to the floor's wall.
local BARRICADE_W = 7
local MEET_FRONT_Z = -25
local MEET_SIDE_X = 63
local MEET_SIDE_END_Z = 49 -- where the side lines meet the floor's wall
-- The warm-up area behind the gantries (user 2026-11-01: "a warm up area, with tons of racks"): rows of the gym's
-- competition rack facing the platforms, as many as fit inside the floor's round wall, and plate trees at the back.
local WARMUP_ROWS = { { z = 30, halfWidth = 60 }, { z = 44, halfWidth = 54 }, { z = 58, halfWidth = 42 } }
local WARMUP_RACK_SPACING = 12
local PLATE_TREES = { Vector3.new(-24, 0, 69), Vector3.new(-8, 0, 69), Vector3.new(8, 0, 69), Vector3.new(24, 0, 69) }
local JUDGES_IN_FRONT = 17
local PLATFORM_SIZE = 16
local PLATFORM_HEIGHT = 0.6
local BANNER_WEDGES = { 2, 4, 8, 10, 14, 16, 20, 22 }
local BANNER_R, BANNER_Y = 143, 47
local NAME_SIGN_R, NAME_SIGN_Y = 145.2, 47.5
local FLAG_AT = Vector3.new(0, 72, 42)
-- The entrance building: across the plaza in front of the gym (whose front is at z = -37), on the right, facing
-- the gym's doors. The ground (the 512-stud baseplate) ends at x and z +-256; it spans x 94..206, z -202..-90.
local GYM_FRONT_Z = -37
local ENTRANCE_GAP = 53 -- from the gym's front to the entrance building's brick front
local ENTRANCE_X = 150
local ENTRANCE_R = 55

local looks = StarterGymConfig.Looks
-- The arena's only shadow casters (see placeIn).
local SHADOW_PIECES = { DomeWedge_Shell = true, StandWedge_Concrete = true, StandWedge_Suites = true }

export type Venue = {
	model: Model,
	-- The arena's frame: the floor's middle, the main stand toward its -Z.
	frame: CFrame,
	-- Where a visitor arrives: on the walkway of the main stand, facing the floor.
	arrival: CFrame,
	-- The invisible point carrying the exit prompt.
	exitPoint: BasePart,
	-- Each rack's lifting spot (on its platform in front of the rack, facing the main stand) and its gantry screen.
	liftSpots: { CFrame },
	rackScreens: { BasePart },
}

local venue: Venue? = nil

-- Rack 1 on the left as the main stand (looking +Z) sees it, which is +X.
local function rackX(index: number): number
	return -(index - (StateArenaConfig.Racks + 1) / 2) * StateArenaConfig.RackSpacingStuds
end

-- A chord across one slice at radius r, a little wider so neighbouring solids overlap.
local function chord(r: number): number
	return 2 * r * math.sin(WEDGE / 2) * 1.04
end

-- A hidden solid: collides, never seen, casts no shadow.
local function hide(part: BasePart): BasePart
	part.Transparency = 1
	part.CastShadow = false
	return part
end

-- A copy of StateArena_01's `item` placed by `at` in the arena's `frame`, or nil when the asset did not load.
local function placeIn(frame: CFrame, parent: Instance, item: string, at: CFrame, name: string?): Model?
	local copy = RoomProps.propCopy(item, 1)
	if copy == nil then
		return nil
	end
	copy.Name = name or item
	copy:PivotTo(frame * at * copy:GetPivot())
	-- PERFORMANCE: indoors under its own lights, only the dome and the stands' shell cast shadows (they keep the
	-- sunlight out); every other piece is a shadow caster nobody would miss (the 2026-11-01 audit: 408 of them).
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") and not SHADOW_PIECES[part.Name] then
			part.CastShadow = false
		end
	end
	copy.Parent = parent
	return copy
end

-- The direction from `part` toward the arena's middle, level.
local function towardMiddle(frame: CFrame, part: BasePart): Vector3
	local d = frame.Position - part.Position
	return Vector3.new(d.X, 0, d.Z).Unit
end

-- The meet area's barrier group and the competitors' group, which do not collide with each other (once).
function StateArenaVenue.registerCollisionGroups()
	local barrier, competitor = StateArenaConfig.MeetBarrierGroup, StateArenaConfig.CompetitorGroup
	for _, group in ipairs({ barrier, competitor }) do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(barrier, competitor, false)
end

-- Builds the arena once and returns it (later calls return the same one), or nil and the reason.
function StateArenaVenue.build(): (Venue?, string?)
	if venue then
		return venue, nil
	end
	local probe = RoomProps.propCopy("StandWedge", 1)
	if probe == nil then
		return nil, "the StateArena_01 models did not load"
	end
	probe:Destroy()
	StateArenaVenue.registerCollisionGroups()
	local frame = CFrame.new(StateArenaConfig.Origin)
	local model = Instance.new("Model")
	model.Name = MODEL_NAME

	local function solid(name: string, size: Vector3, at: CFrame): BasePart
		return hide(BuildParts.placed(model, name, size, frame * at, looks.Glass))
	end
	local function place(parent: Instance, item: string, at: CFrame, name: string?): Model?
		return placeIn(frame, parent, item, at, name)
	end
	-- A hidden wall of the meet area: in the barrier collision group, which competing lifters pass through.
	local function meetBarrier(part: BasePart): BasePart
		part.CollisionGroup = StateArenaConfig.MeetBarrierGroup
		return part
	end

	-- ---------------------------------------------------------------- the floor
	place(model, "ArenaFloor", CFrame.identity)
	solid("Floor_Solid", Vector3.new(2 * FLOOR_WALL_R, 2, 2 * FLOOR_WALL_R), CFrame.new(0, -0.9, 0))

	-- ---------------------------------------------------------------- the bowl and the roof, slice by slice
	local function slope(name: string, turn: CFrame, from: Vector2, to: Vector2)
		local run, rise = to.X - from.X, to.Y - from.Y
		local mid = (from + to) / 2
		local tilt = math.atan2(rise, run)
		solid(name, Vector3.new(chord(to.X), 1, math.sqrt(run * run + rise * rise)),
			turn * CFrame.new(0, mid.Y, -mid.X) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, -0.5, 0))
	end
	local function ring(name: string, turn: CFrame, r0: number, r1: number, y0: number, y1: number)
		solid(name, Vector3.new(chord(r1), y1 - y0, r1 - r0), turn * CFrame.new(0, (y0 + y1) / 2, -(r0 + r1) / 2))
	end
	for k = 0, WEDGES - 1 do
		local turn = CFrame.Angles(0, k * WEDGE, 0)
		place(model, "StandWedge", turn, "Stand_" .. k)
		place(model, "DomeWedge", turn, "Dome_" .. k)
		if BACK_WALL_SLICES[k] then
			meetBarrier(solid("FloorWall_" .. k, Vector3.new(chord(FLOOR_WALL_R), StateArenaConfig.MeetBarrierHeightStuds,
				FLOOR_WALL_R - FLOOR_R), turn * CFrame.new(0, StateArenaConfig.MeetBarrierHeightStuds / 2, -(FLOOR_R + FLOOR_WALL_R) / 2)))
		else
			ring("FloorWall_" .. k, turn, FLOOR_R, FLOOR_WALL_R, 0, FLOOR_WALL_TOP)
		end
		slope("LowerTier_" .. k, turn, LOWER_SLOPE[1], LOWER_SLOPE[2])
		ring("Walkway_" .. k, turn, WALK_R0, WALK_R1, 0, WALK_Y)
		ring("WalkStep_" .. k, turn, WALK_R1 - 1.5, WALK_R1, WALK_Y, WALK_STEP_Y)
		slope("UpperTier_" .. k, turn, UPPER_SLOPE[1], UPPER_SLOPE[2])
		ring("Suites_" .. k, turn, SUITE_R0, SUITE_R1, 0, SUITE_TOP)
		ring("OuterWall_" .. k, turn, WALL_R0, WALL_R1, 0, WALL_TOP)
	end

	-- ---------------------------------------------------------------- hung from the roof
	local cube = place(model, "CentreCube", CFrame.new(0, CUBE_Y, 0))
	local cubeScreens = cube and cube:FindFirstChild("CentreCube_Screens", true) :: BasePart?
	if cubeScreens then
		for _, out in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
			LocalMeetVenue.writeSign(cubeScreens, frame:VectorToWorldSpace(out), "STATE", "CHAMPIONSHIP", 12)
		end
	end
	place(model, "ArenaFlag", CFrame.new(FLAG_AT))
	for i, k in ipairs(BANNER_WEDGES) do
		local a = k * WEDGE
		place(model, "ArenaBanner", CFrame.Angles(0, a, 0) * CFrame.new(0, BANNER_Y, -BANNER_R) * CFrame.Angles(0, math.pi, 0),
			"Banner_" .. i)
	end
	for i, a in ipairs({ math.pi / 2, 3 * math.pi / 2 }) do
		local sign = place(model, "NameSign",
			CFrame.Angles(0, a, 0) * CFrame.new(0, NAME_SIGN_Y, -NAME_SIGN_R) * CFrame.Angles(0, math.pi, 0), "NameSign_" .. i)
		local screen = sign and sign:FindFirstChild("NameSign_Screen", true) :: BasePart?
		if screen then
			LocalMeetVenue.writeSign(screen, towardMiddle(frame, screen), "STATE CHAMPIONSHIP", nil, 20)
		end
	end

	-- ---------------------------------------------------------------- the racks
	local half = PLATFORM_SIZE / 2
	local liftSpots: { CFrame } = {}
	local rackScreens: { BasePart } = {}
	for index = 1, StateArenaConfig.Racks do
		local x = rackX(index)
		-- MockMeet_01's platform was not made in the arena's frame: its pivot (the bottom centre) goes on the spot.
		local platform = RoomProps.propCopy("MeetPlatform", 1)
		if platform then
			platform.Name = "Platform_" .. index
			platform:PivotTo(frame * CFrame.new(x, 0, 0))
			platform.Parent = model
		else
			BuildParts.box(model, "Platform_" .. index .. "_Top", frame * Vector3.new(x - half, 0, -half),
				frame * Vector3.new(x + half, PLATFORM_HEIGHT, half), looks.Wood)
		end
		solid("Platform_" .. index .. "_Solid", Vector3.new(PLATFORM_SIZE + 0.6, PLATFORM_HEIGHT, PLATFORM_SIZE + 0.6),
			CFrame.new(x, PLATFORM_HEIGHT / 2, 0))
		local placed, problem = MockMeetArena.placeRack(model, frame * Vector3.new(x, PLATFORM_HEIGHT, 0))
		if not placed then
			model:Destroy()
			return nil, problem
		end
		local gantry = place(model, "RackGantry", CFrame.new(x, 0, GANTRY_BEHIND), "Gantry_" .. index)
		-- The CENTRAL backdrop inside the gantry, from under the screen to the floor.
		place(model, "GantryBanner", CFrame.new(x, 0, GANTRY_BEHIND), "GantryBanner_" .. index)
		local screen = gantry and gantry:FindFirstChild("RackGantry_Screen", true) :: BasePart?
		if screen then
			-- The State meet will draw the lifter's live minigame here; until then, the rack's number.
			LocalMeetVenue.writeSign(screen, frame:VectorToWorldSpace(-Vector3.zAxis), "RACK " .. index, "STATE CHAMPIONSHIP", 20)
			table.insert(rackScreens, screen)
		end
		place(model, "JudgesTable", CFrame.new(x, 0, -JUDGES_IN_FRONT) * CFrame.Angles(0, math.pi, 0), "Judges_" .. index)
		-- The frame's LookVector (-Z) points at the main stand.
		local spot = frame * Vector3.new(x, PLATFORM_HEIGHT, -4)
		table.insert(liftSpots, CFrame.lookAt(spot, spot + frame.LookVector))
	end

	-- ---------------------------------------------------------------- the meet area's barricades
	-- Props from other files (not made in the arena's frame): their pivot, the bottom centre, goes on the spot,
	-- facing `toward` (in the arena's frame).
	local function prop(name: string, item: string, at: Vector3, toward: Vector3): Model?
		local copy = RoomProps.propCopy(item, 1)
		if copy then
			copy.Name = name
			local world = frame * at
			copy:PivotTo(CFrame.lookAt(world, world + frame:VectorToWorldSpace(toward)))
			copy.Parent = model
		end
		return copy
	end
	local barricades = 0
	local function barricadeLine(from: Vector3, to: Vector3, out: Vector3)
		local length = (to - from).Magnitude
		local count = math.ceil(length / BARRICADE_W)
		for k = 0, count - 1 do
			barricades += 1
			prop("Barricade_" .. barricades, "Barricade", from + (to - from).Unit * (k + 0.5) * BARRICADE_W, out)
		end
		-- One hidden wall along the line, too high to jump over: only competing lifters pass (meetBarrier).
		local mid = (from + to) / 2
		local height = StateArenaConfig.MeetBarrierHeightStuds
		meetBarrier(solid("BarricadeLine_" .. barricades,
			Vector3.new(math.abs(to.X - from.X) + 1, height, math.abs(to.Z - from.Z) + 1), CFrame.new(mid.X, height / 2, mid.Z)))
	end
	barricadeLine(Vector3.new(-MEET_SIDE_X, 0, MEET_FRONT_Z), Vector3.new(MEET_SIDE_X, 0, MEET_FRONT_Z), -Vector3.zAxis)
	barricadeLine(Vector3.new(MEET_SIDE_X, 0, MEET_FRONT_Z), Vector3.new(MEET_SIDE_X, 0, MEET_SIDE_END_Z), Vector3.xAxis)
	barricadeLine(Vector3.new(-MEET_SIDE_X, 0, MEET_FRONT_Z), Vector3.new(-MEET_SIDE_X, 0, MEET_SIDE_END_Z), -Vector3.xAxis)

	-- ---------------------------------------------------------------- the warm-up area behind the gantries
	local warmUp = Instance.new("Folder")
	warmUp.Name = "WarmUp"
	warmUp.Parent = model
	local warmUpRacks = 0
	for _, row in ipairs(WARMUP_ROWS) do
		local x = -row.halfWidth
		while x <= row.halfWidth + 0.01 do
			local placed, problem = MockMeetArena.placeRack(warmUp, frame * Vector3.new(x, 0, row.z))
			if not placed then
				warn("[StateArenaVenue] a warm-up rack was not placed: " .. tostring(problem))
				break
			end
			warmUpRacks += 1
			x += WARMUP_RACK_SPACING
		end
	end
	for i, at in ipairs(PLATE_TREES) do
		prop("PlateTree_" .. i, "PlateTree", at, -Vector3.zAxis)
	end
	-- PERFORMANCE: the warm-up racks are many copies of one rack; none of them casts a shadow under the arena's lights.
	for _, part in ipairs(warmUp:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end

	-- TV cameras on the walkway between the tiers and on the floor's front corners.
	for i, a in ipairs({ -0.3, 0, 0.3 }) do
		place(model, "CameraTripod", CFrame.Angles(0, a, 0) * CFrame.new(0, WALK_Y, -114) * CFrame.Angles(0, math.pi, 0),
			"Camera_" .. i)
	end
	for i, corner in ipairs({ { x = 62, turn = 1 }, { x = -62, turn = -1 } }) do
		place(model, "CameraTripod", CFrame.new(corner.x, 0, -34) * CFrame.Angles(0, math.pi + corner.turn * 0.5, 0),
			"FloorCamera_" .. i)
	end

	-- ---------------------------------------------------------------- lights
	-- A spotlight over each rack, and a ring of soft lights over the bowl (the dome's rim lights glow too).
	local function lamp(name: string, at: Vector3): BasePart
		local part = solid(name, Vector3.new(1, 1, 1), CFrame.new(at))
		part.CanCollide = false
		part.CanQuery = false
		return part
	end
	for index = 1, StateArenaConfig.Racks do
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Range = 70
		spot.Angle = 50
		spot.Brightness = 4
		spot.Color = StarterGymConfig.LightColor
		spot.Parent = lamp("RackLight_" .. index, Vector3.new(rackX(index), 58, -2))
	end
	for i = 1, 8 do
		local a = (i - 0.5) * math.pi / 4
		local light = Instance.new("PointLight")
		light.Range = 60
		light.Brightness = 1.5
		light.Color = StarterGymConfig.LightColor
		light.Parent = lamp("BowlLight_" .. i, Vector3.new(120 * math.sin(a), 52, -120 * math.cos(a)))
	end

	-- ---------------------------------------------------------------- arriving and leaving
	-- On the main stand's walkway (slice 0: its aisle is at the other edge), facing the floor; the EXIT beside it,
	-- a sign on the upper tier's front wall over a hidden point carrying the prompt.
	local arrivalAt = frame * Vector3.new(0, WALK_Y, -(WALK_R0 + WALK_R1) / 2)
	local arrival = CFrame.lookAt(arrivalAt, arrivalAt - frame.LookVector)
	local exitSign = BuildParts.placed(model, "ExitSign", Vector3.new(6, 2.6, 0.3),
		frame * CFrame.new(6, WALK_Y + 3.4, -(WALK_R1 - 0.4)), looks.Glass)
	exitSign.Transparency = 0
	exitSign.CanCollide = false
	LocalMeetVenue.writeSign(exitSign, frame:VectorToWorldSpace(Vector3.zAxis), "EXIT", "BACK TO THE GYM", 40)
	local exitPoint = BuildParts.placed(model, "ExitPoint", Vector3.new(3, 4, 2),
		frame * CFrame.new(6, WALK_Y + 2, -(WALK_R1 - 2)), looks.Glass)
	hide(exitPoint)
	exitPoint.CanCollide = false
	exitPoint.CanQuery = false

	model.Parent = Workspace
	model:SetAttribute("WarmUpRacks", warmUpRacks)
	venue = {
		model = model,
		frame = frame,
		arrival = arrival,
		exitPoint = exitPoint,
		liftSpots = liftSpots,
		rackScreens = rackScreens,
	}
	return venue, nil
end

--[[
	Builds the arena's ENTRANCE BUILDING across the plaza in front of the gym
	(StateArena_01's ArenaEntrance: the brick base with three arches, the ribbed
	drum and the dome), facing the gym's doors, on hidden solid walls, with its
	sign, and returns the invisible point in front of its middle doors (tagged
	StateArenaConfig.EntranceTag), or nil when the model did not load.
]]
function StateArenaVenue.buildEntrance(): BasePart?
	local existing = Workspace:FindFirstChild(ENTRANCE_NAME)
	if existing then
		return existing:FindFirstChild("DoorPoint") :: BasePart?
	end
	local building = RoomProps.propCopy("ArenaEntrance", 1)
	if building == nil then
		warn("[StateArenaVenue] the entrance building's model did not load")
		return nil
	end
	local model = Instance.new("Model")
	model.Name = ENTRANCE_NAME
	building.Name = "ArenaEntrance"
	building.Parent = model
	-- The building's own frame: its middle at 0,0,0, the arches toward -Z, the brick front ENTRANCE_FRONT out.
	-- Turned to face the gym (+Z), with that front ENTRANCE_GAP from the gym's front.
	local frontLocal = ENTRANCE_R * math.cos(1.5 * WEDGE) + 0.5
	local here = CFrame.new(ENTRANCE_X, 0, GYM_FRONT_Z - ENTRANCE_GAP - frontLocal) * CFrame.Angles(0, math.pi, 0)
	building:PivotTo(here * building:GetPivot())
	local sign = building:FindFirstChild("ArenaEntrance_SignScreen", true) :: BasePart?
	if sign == nil then
		model:Destroy()
		warn("[StateArenaVenue] the entrance building's model is missing its sign")
		return nil
	end

	-- Hidden solid walls (in the building's frame): one per slice round the round part, and the flat front.
	local function solid(name: string, size: Vector3, at: CFrame)
		hide(BuildParts.placed(model, name, size, here * at, looks.Glass))
	end
	for k = 0, WEDGES - 1 do
		if k ~= 0 and k ~= 1 and k ~= WEDGES - 1 then
			solid("Wall_" .. k, Vector3.new(chord(ENTRANCE_R), 24, 3),
				CFrame.Angles(0, k * WEDGE, 0) * CFrame.new(0, 12, -(ENTRANCE_R - 1.5)))
		end
	end
	local frontHalf = ENTRANCE_R * math.sin(1.5 * WEDGE)
	solid("Front_Solid", Vector3.new(2 * frontHalf, 24, 3), CFrame.new(0, 12, -frontLocal + 1.5))

	-- The sign: big heavy italic STATE ARENA in the game's style, readable from the gym's doors.
	-- (here turns the building round, so its LookVector is the arches' outward direction, toward the gym.)
	LocalMeetVenue.writeSign(sign, here.LookVector, "STATE ARENA", "STATE CHAMPIONSHIP  //  HOLD E AT THE DOORS", 30)

	-- The point in front of the middle doors that carries the "Go to the State arena" prompt.
	local doorPoint = BuildParts.placed(model, "DoorPoint", Vector3.new(3, 4, 3), here * CFrame.new(0, 2.3, -frontLocal - 2.5),
		looks.Glass)
	hide(doorPoint)
	doorPoint.CanCollide = false
	doorPoint.CanQuery = false
	doorPoint:AddTag(StateArenaConfig.EntranceTag)
	model.Parent = Workspace
	return doorPoint
end

return StateArenaVenue
