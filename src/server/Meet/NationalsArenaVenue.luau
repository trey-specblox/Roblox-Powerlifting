--!strict
--[[
	NationalsArenaVenue
	Server / Meet

	THE NATIONALS ARENA (GAME_DESIGN.md §39 step 3; the user's photos, video and words in References/Nationals Arena/).
	Built once at server start, in every server (user 2026-11-17):
		THE BUILDING on the plaza, left of the gym's front, opposite the State arena's entrance, facing the gym's doors:
		  six pitched teal roof bays with white gable trusses, a glass front, the entrance porch with its sign (the game
		  writes NATIONALS and the time to the next one), the end walls and the covered walkway. Hold E at the porch's doors
		  to go in.
		THE HALL far from the gym (NationalsConfig.HallOrigin), as the State arena is: the lifters' floor, the main stand
		  and both end stands with the crowd, the walls, the roof bays and blue trusses, the back drapes, the 4 platforms'
		  stage sets (each with its competition rack, plate trees and referee chairs), the officials' table, the NATIONALS
		  banner, a warm-up area, and the NATIONALS sign-up desk on the concourse where a visitor arrives. EXIT goes back out.
		  Lit as a dark room: every platform hard-lit by its own spotlight, the drapes washed purple, a working light over
		  the warm-up area; each player's NationalsHallLights darkens the room while they are inside.

	Every piece is a copy of NationalsArena_02 (art/scripts/build_nationals_arena_02.py), placed in the build script's own
	coordinates: a Blender point (x, y, z) is the Roblox point (-x, z, y) in the building's or the hall's frame, and a
	Blender turn about Z is the same turn about Roblox's Y. Each template's pivot is the bottom centre of its bounds (the
	BOUNDS lines the build script prints), so a copy whose item frame goes at F has its pivot at F * blenderToRoblox(bottom
	centre). Collision is hidden solid blocks; every model piece is decor.

	PERFORMANCE: the building is about 4,600 triangles (every server, near the gym). The hall about 165,000, all reused
	meshes, far from the gym (streamed in only near it): the crowd and stands are most of it. 13 spotlights and 3 working
	lights in the hall, none with shadows. No model piece casts a shadow.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local NationalsConfig = require(ConfigFolder:WaitForChild("NationalsConfig"))
local StarterGymConfig = require(ConfigFolder:WaitForChild("StarterGymConfig"))

local ServerFolder = script.Parent.Parent
local WorldFolder = ServerFolder:WaitForChild("World")
local BuildParts = require(WorldFolder:WaitForChild("BuildParts"))
local RoomProps = require(WorldFolder:WaitForChild("RoomProps"))
local StyledScreen = require(WorldFolder:WaitForChild("StyledScreen"))
local MockMeetArena = require(script.Parent:WaitForChild("MockMeetArena"))
local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))

local NationalsArenaVenue = {}

local looks = StarterGymConfig.Looks
local STREAM_TIMEOUT_SECONDS = 5

-- ---------------------------------------------------------------- the build script's numbers (keep in step with it)

-- Each item's bottom centre in its own Blender frame (build_nationals_arena_02.py BOUNDS).
local BOTTOM: { [string]: Vector3 } = {
	NatBay = Vector3.new(-0.32, 30.22, 0),
	NatBayEnd = Vector3.new(0, -0.25, 0),
	NatPorch = Vector3.new(0, -6.49, 0),
	NatEndLeft = Vector3.new(-1.30, 34.55, 0),
	NatEndRight = Vector3.new(1.30, 34.55, 0),
	NatWalkway = Vector3.new(10.00, -3.00, 0),
	NatFloor = Vector3.new(0, -17.50, -1.00),
	NatStandMain = Vector3.new(0, 32.40, 0),
	NatStandEnd = Vector3.new(0, 21.40, 0),
	NatWall = Vector3.new(0, 0.30, 0),
	NatRoofBay = Vector3.new(0, -17.50, 49.33),
	NatTruss = Vector3.new(0, -17.50, -6.40),
	NatHighBay = Vector3.new(0, 0, -1.30),
	NatDrape = Vector3.new(0, 0.70, 0),
	NatStageSet = Vector3.new(0, 10.61, 0),
	NatBanner = Vector3.new(0, 0.30, 0),
	NatCrowdMainA = Vector3.new(1.21, 27.54, 2.50),
	NatCrowdMainB = Vector3.new(1.18, 27.54, 2.50),
	NatCrowdEnd = Vector3.new(1.21, 18.54, 2.50),
}

-- The building (Blender frame: the glass front's middle at 0, the front toward -Y).
local BAY_W, BAYS, DEPTH, EAVE, COL_Y = 26, 6, 70, 22, -7
local PORCH_W, PORCH_D, PORCH_EAVE = 22, 11, 15
-- The hall (Blender frame: the floor's middle at 0; the stages face -Y, toward the main stand).
local WALL_X, WALL_Y_FRONT, WALL_Y_BACK, WALL_Z = 148, -110, 75, 50
local PANEL_W, ROOF_BAYS, HALL_RIDGE = 37, 8, 62
local FLOOR_X, RAIL_Y, SECTION_W = 100, -42, 20
local ROW_D, ROW_RISE, ROW_BASE, FRONT_WALL_D = 3, 1.6, 2.5, 0.8
local MAIN_ROWS, END_ROWS, END_SECTIONS = 18, 12, 3
local MAIN_CONCOURSE, END_CONCOURSE = 10, 6
local STAGE_W, STAGE_D, STAGE_H = 24, 18, 1.2
local BACKDROP_Y, BACKDROP_W, BACKDROP_H = 20, 28, 15
local VIDEO_Z1 = 29

-- ---------------------------------------------------------------- frames

local function toRoblox(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Z, v.Y)
end

-- The Roblox CFrame of a Blender-frame spot (x, y, z) turned `turnDeg` about the vertical, inside `origin`.
local function at(origin: CFrame, x: number, y: number, z: number, turnDeg: number?): CFrame
	return origin * CFrame.new(toRoblox(Vector3.new(x, y, z))) * CFrame.Angles(0, math.rad(turnDeg or 0), 0)
end

-- A world direction from a Blender-frame direction inside `origin`.
local function dirOf(origin: CFrame, x: number, y: number, z: number): Vector3
	return origin:VectorToWorldSpace(toRoblox(Vector3.new(x, y, z)))
end

local function rowFront(k: number): number
	return FRONT_WALL_D + k * ROW_D
end

local function rowTop(k: number): number
	return ROW_BASE + k * ROW_RISE
end

-- ---------------------------------------------------------------- building helpers

local missing: { [string]: boolean } = {}

-- A copy of `item` whose item frame goes at `frame`, leaving out pieces named in `skip`. Nil when it didn't load.
local function place(parent: Instance, item: string, frame: CFrame, colourway: number?, skip: { string }?): Model?
	local copy = RoomProps.propCopy(item, colourway or 1)
	if copy == nil then
		if not missing[item] then
			missing[item] = true
			warn("[NationalsArenaVenue] the model " .. item .. " did not load")
		end
		return nil
	end
	for _, piece in ipairs(skip or {}) do
		local part = copy:FindFirstChild(item .. "_" .. piece, true)
		if part then
			part:Destroy()
		end
	end
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end
	copy:PivotTo(frame * CFrame.new(toRoblox(BOTTOM[item] or Vector3.zero)))
	copy.Parent = parent
	return copy
end

local function hide(part: BasePart): BasePart
	part.Transparency = 1
	part.CastShadow = false
	return part
end

-- A hidden solid block, `size` in Blender axes (x wide, y deep, z high), its centre at the Blender spot.
local function solid(parent: Instance, name: string, origin: CFrame, centre: Vector3, size: Vector3, turnDeg: number?): BasePart
	local s = Vector3.new(size.X, size.Z, size.Y)
	return hide(BuildParts.placed(parent, name, s, at(origin, centre.X, centre.Y, centre.Z, turnDeg), looks.Glass))
end

-- A hidden, unlit point carrying a light or a prompt.
local function marker(parent: Instance, name: string, cframe: CFrame, size: Vector3?): BasePart
	local part = BuildParts.placed(parent, name, size or Vector3.new(1, 1, 1), cframe, looks.Glass)
	hide(part)
	part.CanCollide = false
	part.CanQuery = false
	return part
end

local function spot(parent: Instance, name: string, from: CFrame, target: Vector3, brightness: number, range: number, angle: number,
	colour: Color3): BasePart
	local part = marker(parent, name, CFrame.lookAt(from.Position, target))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Brightness = brightness
	light.Range = range
	light.Angle = angle
	light.Color = colour
	light.Shadows = false
	light.Parent = part
	return part
end

-- ---------------------------------------------------------------- the venue

export type Stage = {
	-- The stage's frame: its front edge's middle on the hall floor, -Z toward the main stand (in the hall's world frame).
	frame: CFrame,
	-- Where the lifter stands at the rack, on the stage.
	liftSpot: CFrame,
	-- The video wall's screen (the game draws the lifter on it) and its handle.
	screen: BasePart?,
	display: StyledScreen.Handle?,
}

export type Venue = {
	building: Model,
	hall: Model,
	hallFrame: CFrame,
	-- In front of the porch, facing the doors (lifters arrive here in a Nationals server).
	outside: CFrame,
	-- On the main stand's concourse, facing the floor (where a visitor arrives inside).
	inside: CFrame,
	stages: { Stage },
	deskPoint: BasePart?,
	deskScreen: StyledScreen.Handle?,
	sign: StyledScreen.Handle?,
}

local venue: Venue? = nil
local visitors: { [Player]: { connections: { RBXScriptConnection } } } = {}

local function buildBuilding(origin: CFrame): (Model, CFrame, BasePart?)
	local model = Instance.new("Model")
	model.Name = "NationalsBuilding"
	local x0 = -BAY_W * BAYS / 2
	for i = 0, BAYS - 1 do
		local xc = x0 + BAY_W * (i + 0.5)
		-- The bay whose -X line is the building's middle has the porch there: no column, lamp or downpipe.
		local atPorch = math.abs(xc - BAY_W / 2) < 0.01
		place(model, "NatBay", at(origin, xc, 0, 0), 1, if atPorch then { "Column", "Lamp", "LampArm" } else nil)
	end
	place(model, "NatBayEnd", at(origin, -x0, COL_Y, 0))
	local porch = place(model, "NatPorch", at(origin, 0, 0, 0))
	place(model, "NatEndLeft", at(origin, x0, 0, 0))
	place(model, "NatEndRight", at(origin, -x0, 0, 0))
	place(model, "NatWalkway", at(origin, -x0, 0, 0))
	-- Solid: the hall's body, the porch, the columns and the walkway's posts. The building is entered by its doors' prompt.
	solid(model, "Body_Solid", origin, Vector3.new(0, DEPTH / 2, EAVE / 2), Vector3.new(BAY_W * BAYS + 3, DEPTH, EAVE))
	solid(model, "Porch_Solid", origin, Vector3.new(0, -PORCH_D / 2, PORCH_EAVE / 2), Vector3.new(PORCH_W + 2.6, PORCH_D, PORCH_EAVE))
	for i = 0, BAYS do
		local x = x0 + BAY_W * i
		if math.abs(x) > PORCH_W / 2 then
			solid(model, "Column_Solid_" .. i, origin, Vector3.new(x, COL_Y, EAVE / 2), Vector3.new(1.2, 1.2, EAVE))
		end
	end
	for _, x in ipairs({ -x0 + 1.5, -x0 + 18.5 }) do
		for _, y in ipairs({ -12, 6 }) do
			solid(model, "WalkwayPost_Solid", origin, Vector3.new(x, y, 5.6), Vector3.new(0.7, 0.7, 11.2))
		end
	end
	local outside = at(origin, 0, -PORCH_D - 13, 0, 180)
	-- The prompt's point in front of the middle doors.
	local doorPoint = marker(model, "DoorPoint", at(origin, 0, -PORCH_D - 2.5, 2.3), Vector3.new(3, 4, 3))
	doorPoint:AddTag(NationalsConfig.EntranceTag)
	model:SetAttribute("Porch", porch ~= nil)
	return model, outside, doorPoint
end

local function buildHall(origin: CFrame): (Model, { Stage }, CFrame, BasePart, BasePart?, StyledScreen.Handle?)
	local model = Instance.new("Model")
	model.Name = "NationalsHall"
	place(model, "NatFloor", at(origin, 0, 0, 0))
	for k = 0, 9 do
		local x = -FLOOR_X + SECTION_W * (k + 0.5)
		place(model, "NatStandMain", at(origin, x, RAIL_Y, 0, 180))
		place(model, if k % 2 == 0 then "NatCrowdMainA" else "NatCrowdMainB", at(origin, x, RAIL_Y, 0, 180), k % 4 + 1)
	end
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, END_SECTIONS - 1 do
			local y = -40 + SECTION_W * (k + 0.5)
			place(model, "NatStandEnd", at(origin, s * (FLOOR_X + 2), y, 0, -90 * s))
			place(model, "NatCrowdEnd", at(origin, s * (FLOOR_X + 2), y, 0, -90 * s), (k + (if s > 0 then 2 else 0)) % 4 + 1)
		end
	end
	for k = 0, ROOF_BAYS - 1 do
		local x = -WALL_X + PANEL_W * (k + 0.5)
		place(model, "NatWall", at(origin, x, WALL_Y_FRONT, 0, 180))
		place(model, "NatWall", at(origin, x, WALL_Y_BACK, 0))
		place(model, "NatRoofBay", at(origin, x, 0, 0))
		place(model, "NatDrape", at(origin, x, WALL_Y_BACK - 3, 0))
	end
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 4 do
			place(model, "NatWall", at(origin, s * WALL_X, WALL_Y_FRONT + PANEL_W * (k + 0.5), 0, -90 * s))
		end
	end
	for k = 1, ROOF_BAYS * 2 - 1 do
		local x = -WALL_X + PANEL_W / 2 * k
		local z = if k % 2 == 1 then HALL_RIDGE - 2.2 else WALL_Z - 1.2
		place(model, "NatTruss", at(origin, x, 0, z))
		for y = WALL_Y_FRONT + 18, WALL_Y_BACK - 7, 24 do
			-- None hangs between the main stand and the banner across its width (they'd sit in the line of sight).
			if not (math.abs(x) < 38 and y < -10) then
				place(model, "NatHighBay", at(origin, x, y, z - 7.5))
			end
		end
	end
	place(model, "NatBanner", at(origin, 0, -26, 34))

	-- The four platforms: stage set, competition rack, plate trees, referee chairs, the spotlight and the drapes' wash.
	local stages: { Stage } = {}
	local white, purple = Color3.fromRGB(255, 247, 235), Color3.fromRGB(150, 80, 255)
	for i, x in ipairs(NationalsConfig.PlatformXs) do
		local set = place(model, "NatStageSet", at(origin, x, 0, 0))
		local gear = Instance.new("Folder")
		gear.Name = "Platform_" .. i
		gear.Parent = model
		MockMeetArena.placeRack(gear, at(origin, x, 9, STAGE_H).Position, math.pi)
		for _, sx in ipairs({ -1, 1 }) do
			place(gear, "PlateTree", at(origin, x + sx * 10.4, 15.5, STAGE_H, 180))
		end
		place(gear, "RefChair", at(origin, x, -6, 0, 180))
		for _, sx in ipairs({ -1, 1 }) do
			place(gear, "RefChair", at(origin, x + sx * 11, -1.5, 0, 180 - sx * 25))
		end
		spot(model, "StageSpot_" .. i, at(origin, x, -4, 44), at(origin, x, 9, 0).Position, 9, 70, 42, white)
		for _, sx in ipairs({ -1, 1 }) do
			spot(model, "DrapeWash_" .. i .. "_" .. sx, at(origin, x + sx * 15.7, 10, 2),
				at(origin, x + sx * 15.7, STAGE_D, 24).Position, 3, 30, 35, purple)
		end
		-- Solid: the stage, the backdrop and its drapes (nobody walks through them).
		solid(model, "Stage_Solid_" .. i, origin, Vector3.new(x, STAGE_D / 2, STAGE_H / 2), Vector3.new(STAGE_W, STAGE_D, STAGE_H))
		solid(model, "Backdrop_Solid_" .. i, origin, Vector3.new(x, BACKDROP_Y + 0.6, VIDEO_Z1 / 2),
			Vector3.new(BACKDROP_W + 7, 1.6, VIDEO_Z1))
		local screen = set and set:FindFirstChild("NatStageSet_Screen", true) :: BasePart?
		local display: StyledScreen.Handle? = nil
		if screen then
			display = StyledScreen.build(screen, StyledScreen.faceToward(screen, dirOf(origin, 0, -1, 0)), "PLATFORM " .. i,
				{ NationalsConfig.EventTitle, "CENTRAL" }, "bar", 40)
		end
		table.insert(stages, {
			frame = at(origin, x, 0, 0),
			liftSpot = at(origin, x, 8, STAGE_H),
			screen = screen,
			display = display,
		})
	end
	-- The banner's own light, and plain working lights over the warm-up area.
	spot(model, "BannerSpot", at(origin, 0, -60, 30), at(origin, 0, -26, 38).Position, 4, 60, 30, white)
	for _, x in ipairs({ -60, 0, 60 }) do
		local lamp = marker(model, "WarmUpLight_" .. x, at(origin, x, 44, 30))
		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Range = 45
		light.Color = Color3.fromRGB(255, 240, 220)
		light.Shadows = false
		light.Parent = lamp
	end
	-- The officials' table in front of the platforms and the warm-up racks behind the backdrops.
	-- (The skirt with CENTRAL faces the main stand; the officials sit behind it facing the platforms.)
	for _, x in ipairs({ -18, 0, 18 }) do
		place(model, "JudgesTable", at(origin, x, -17, 0, 0))
	end
	local warmUp = Instance.new("Folder")
	warmUp.Name = "WarmUp"
	warmUp.Parent = model
	for _, px in ipairs(NationalsConfig.PlatformXs) do
		for _, dx in ipairs({ -6, 6 }) do
			local holder = Instance.new("Folder")
			holder.Name = "WarmUpRack"
			holder.Parent = warmUp
			MockMeetArena.placeRack(holder, at(origin, px + dx, 42, 0).Position)
		end
	end
	for _, part in ipairs(warmUp:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end

	-- Solid: the floor, the walls, the stands (a walking slope through each section's rows, its front wall and concourse).
	solid(model, "Floor_Solid", origin, Vector3.new(0, (WALL_Y_FRONT + WALL_Y_BACK) / 2, -1), Vector3.new(2 * WALL_X, WALL_Y_BACK - WALL_Y_FRONT, 2))
	solid(model, "WallFront_Solid", origin, Vector3.new(0, WALL_Y_FRONT - 1, 40), Vector3.new(2 * WALL_X + 4, 2, 80))
	solid(model, "WallBack_Solid", origin, Vector3.new(0, WALL_Y_BACK + 1, 40), Vector3.new(2 * WALL_X + 4, 2, 80))
	for _, s in ipairs({ -1, 1 }) do
		solid(model, "WallSide_Solid", origin, Vector3.new(s * (WALL_X + 1), (WALL_Y_FRONT + WALL_Y_BACK) / 2, 40),
			Vector3.new(2, WALL_Y_BACK - WALL_Y_FRONT, 80))
	end
	solid(model, "Roof_Solid", origin, Vector3.new(0, (WALL_Y_FRONT + WALL_Y_BACK) / 2, HALL_RIDGE + 2),
		Vector3.new(2 * WALL_X, WALL_Y_BACK - WALL_Y_FRONT, 2))
	local function standSolids(name: string, sectionFrame: CFrame, rows: number, concourse: number)
		-- In the section's own frame: the front wall at y 0, rows rising toward +y.
		local y0, z0 = rowFront(0), rowTop(0)
		local y1, z1 = rowFront(rows - 1) + ROW_D, rowTop(rows - 1)
		local run, rise = y1 - y0, z1 - z0
		local slope = math.sqrt(run * run + rise * rise)
		local angle = math.atan2(rise, run)
		local mid = sectionFrame * CFrame.new(toRoblox(Vector3.new(0, (y0 + y1) / 2, (z0 + z1) / 2)))
		-- Tilted about the section's own X axis (Roblox): up toward +Z (Blender +Y).
		local slab = BuildParts.placed(model, name .. "_Slope", Vector3.new(SECTION_W, 1, slope), mid * CFrame.Angles(-angle, 0, 0),
			looks.Glass)
		hide(slab)
		local wallTop = ROW_BASE + 0.6 + 3.3
		hide(BuildParts.placed(model, name .. "_Front", Vector3.new(SECTION_W, wallTop, 1),
			sectionFrame * CFrame.new(toRoblox(Vector3.new(0, 0.4, wallTop / 2))), looks.Glass))
		local top = z1 + 0.6
		hide(BuildParts.placed(model, name .. "_Concourse", Vector3.new(SECTION_W, top, concourse + ROW_D),
			sectionFrame * CFrame.new(toRoblox(Vector3.new(0, rowFront(rows) + concourse / 2 - ROW_D / 2, top / 2))), looks.Glass))
	end
	for k = 0, 9 do
		local x = -FLOOR_X + SECTION_W * (k + 0.5)
		standSolids("Main" .. k, at(origin, x, RAIL_Y, 0, 180), MAIN_ROWS, MAIN_CONCOURSE)
	end
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, END_SECTIONS - 1 do
			local y = -40 + SECTION_W * (k + 0.5)
			standSolids("End" .. s .. "_" .. k, at(origin, s * (FLOOR_X + 2), y, 0, -90 * s), END_ROWS, END_CONCOURSE)
		end
	end

	-- Arriving: on the main stand's concourse, its middle, facing the floor. EXIT beside it.
	local concourseY = RAIL_Y - rowFront(MAIN_ROWS) - MAIN_CONCOURSE / 2
	local concourseZ = rowTop(MAIN_ROWS - 1) + 0.6
	local inside = at(origin, 0, concourseY, concourseZ, 180)
	local exitPoint = marker(model, "ExitPoint", at(origin, 10, concourseY, concourseZ + 2), Vector3.new(3, 4, 3))
	local exitSign = BuildParts.placed(model, "ExitSign", Vector3.new(6, 2.6, 0.3), at(origin, 10, concourseY - 4.6, concourseZ + 6),
		looks.Glass)
	exitSign.Transparency = 0
	exitSign.CanCollide = false
	LocalMeetVenue.writeSign(exitSign, dirOf(origin, 0, 1, 0), "EXIT", "BACK OUTSIDE", 40)

	-- The NATIONALS sign-up desk on the concourse (MockMeet_01's desk, the State desk's mesh), facing the arriving visitors.
	local deskPoint: BasePart? = nil
	local deskScreen: StyledScreen.Handle? = nil
	-- Its front toward the floor, where the visitors stand (the deskPoint), its monitor toward the back wall as the State desk's.
	local desk = place(model, "MeetDesk", at(origin, -14, concourseY - 2.5, concourseZ, 180))
	if desk then
		solid(model, "Desk_Solid", origin, Vector3.new(-14, concourseY - 2.5, concourseZ + 1.65), Vector3.new(10.5, 2.3, 3.3))
		local monitor = desk:FindFirstChild("MeetDesk_MonitorScreen", true) :: BasePart?
		if monitor then
			deskScreen = StyledScreen.build(monitor, StyledScreen.faceToward(monitor, dirOf(origin, 0, -1, 0)),
				NationalsConfig.EventTitle, { "Spot holders sign up", "here" }, "bar", 120)
		end
		deskPoint = marker(model, "DeskPoint", at(origin, -14, concourseY + 1.5, concourseZ + 2), Vector3.new(2, 4, 2))
	end
	model:SetAttribute("HallCentre", origin.Position)
	model:SetAttribute("HallHalfSize", Vector3.new(WALL_X, 70, (WALL_Y_BACK - WALL_Y_FRONT) / 2))
	model:SetAttribute("HallMiddle", at(origin, 0, (WALL_Y_FRONT + WALL_Y_BACK) / 2, 0).Position)
	CollectionService:AddTag(model, NationalsConfig.HallTag)
	return model, stages, inside, exitPoint, deskPoint, deskScreen
end

--[[
	Builds the building and the hall once (later calls return the same venue), or nil when the models did not load. Yields
	(the models load). In a Nationals server the same build is the meet's venue.
]]
function NationalsArenaVenue.build(): Venue?
	if venue then
		return venue
	end
	local probe = RoomProps.propCopy("NatBay", 1)
	if probe == nil then
		warn("[NationalsArenaVenue] NationalsArena_02 did not load: no Nationals building")
		return nil
	end
	probe:Destroy()
	local buildingOrigin = CFrame.new(NationalsConfig.BuildingOrigin) * CFrame.Angles(0, math.pi, 0)
	local building, outside, _ = buildBuilding(buildingOrigin)
	building.Parent = Workspace
	local hallFrame = CFrame.new(NationalsConfig.HallOrigin)
	local hall, stages, inside, exitPoint, deskPoint, deskScreen = buildHall(hallFrame)
	hall.Parent = Workspace
	local signPart = building:FindFirstChild("NatPorch_SignScreen", true) :: BasePart?
	local sign: StyledScreen.Handle? = nil
	if signPart then
		sign = StyledScreen.build(signPart, StyledScreen.faceToward(signPart, buildingOrigin:VectorToWorldSpace(toRoblox(Vector3.new(0, -1, 0)))),
			NationalsConfig.EventTitle, { "National Championship", "" }, "bar", 30)
	end
	venue = {
		building = building,
		hall = hall,
		hallFrame = hallFrame,
		outside = outside,
		inside = inside,
		stages = stages,
		deskPoint = deskPoint,
		deskScreen = deskScreen,
		sign = sign,
	}
	-- The doors in and the EXIT out.
	local function prompt(parent: BasePart, action: string, object: string, onTriggered: (Player) -> ())
		local p = Instance.new("ProximityPrompt")
		p.ActionText = action
		p.ObjectText = object
		p.HoldDuration = NationalsConfig.PromptHoldSeconds
		p.MaxActivationDistance = NationalsConfig.PromptDistanceStuds
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.GamepadKeyCode = Enum.KeyCode.ButtonX
		p.RequiresLineOfSight = false
		p.Parent = parent
		p.Triggered:Connect(onTriggered)
	end
	local doorPoint = building:FindFirstChild("DoorPoint") :: BasePart?
	if doorPoint then
		prompt(doorPoint, "Go inside", NationalsConfig.EventTitle, function(player)
			NationalsArenaVenue.goInside(player)
		end)
	end
	prompt(exitPoint, "Back outside", "Exit", function(player)
		NationalsArenaVenue.goOutside(player)
	end)
	print(string.format("[NationalsArenaVenue] built: the building at %s, the hall at %s, %d platforms",
		tostring(NationalsConfig.BuildingOrigin), tostring(NationalsConfig.HallOrigin), #stages))
	return venue
end

-- The venue once built (nil before, or when its models did not load).
function NationalsArenaVenue.current(): Venue?
	return venue
end

local function bodyOf(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, root, humanoid
end

-- Moves the player's character to `spot` (a floor spot), streaming it in first. Returns whether they went.
local function moveTo(player: Player, spot: CFrame): boolean
	local character, root, humanoid = bodyOf(player)
	if character == nil or root == nil or humanoid == nil or root.Anchored then
		return false
	end
	pcall(function()
		player:RequestStreamAroundAsync(spot.Position, STREAM_TIMEOUT_SECONDS)
	end)
	local again, _, nowHumanoid = bodyOf(player)
	if again ~= character or nowHumanoid == nil then
		return false
	end
	local height = if humanoid.RigType == Enum.HumanoidRigType.R6 then 3 else humanoid.HipHeight + root.Size.Y / 2
	character:PivotTo(spot * CFrame.new(0, height, 0))
	return true
end

-- Into the hall, onto the concourse (the doors' prompt, or a lifter walked in at Nationals). Returns whether they went.
function NationalsArenaVenue.goInside(player: Player): boolean
	local v = venue
	if v == nil then
		return false
	end
	local went = moveTo(player, v.inside)
	if went then
		player:SetAttribute(NationalsConfig.InHallAttribute, true)
		local character = player.Character
		local old = visitors[player]
		if old then
			for _, c in ipairs(old.connections) do
				c:Disconnect()
			end
		end
		local connections = {}
		if character then
			table.insert(connections, character.AncestryChanged:Connect(function(_, parent)
				if parent == nil and player.Parent then
					player:SetAttribute(NationalsConfig.InHallAttribute, nil)
				end
			end))
		end
		visitors[player] = { connections = connections }
	end
	return went
end

-- Out in front of the porch (EXIT, or a lifter arriving at Nationals). Returns whether they went.
function NationalsArenaVenue.goOutside(player: Player): boolean
	local v = venue
	if v == nil then
		return false
	end
	local went = moveTo(player, v.outside)
	if went then
		player:SetAttribute(NationalsConfig.InHallAttribute, nil)
		local old = visitors[player]
		if old then
			for _, c in ipairs(old.connections) do
				c:Disconnect()
			end
		end
		visitors[player] = nil
	end
	return went
end

Players.PlayerRemoving:Connect(function(player)
	local old = visitors[player]
	if old then
		for _, c in ipairs(old.connections) do
			c:Disconnect()
		end
	end
	visitors[player] = nil
end)

return NationalsArenaVenue
