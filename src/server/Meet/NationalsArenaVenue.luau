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
local StateArenaConfig = require(ConfigFolder:WaitForChild("StateArenaConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local ServerFolder = script.Parent.Parent
local WorldFolder = ServerFolder:WaitForChild("World")
local BuildParts = require(WorldFolder:WaitForChild("BuildParts"))
local RoomProps = require(WorldFolder:WaitForChild("RoomProps"))
local StyledScreen = require(WorldFolder:WaitForChild("StyledScreen"))
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local CheerConfig = require(ConfigFolder:WaitForChild("CheerConfig"))
local LifterDisplay = require(script.Parent:WaitForChild("LifterDisplay"))
local StationVisuals = require(ServerFolder:WaitForChild("Training"):WaitForChild("StationVisuals"))
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))
local MockMeetArena = require(script.Parent:WaitForChild("MockMeetArena"))
local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))
local LocalMeetWarmUp = require(script.Parent:WaitForChild("LocalMeetWarmUp"))
local MeetFigures = require(script.Parent:WaitForChild("MeetFigures"))
local StateArenaVenue = require(script.Parent:WaitForChild("StateArenaVenue"))
local LocalMeetService = require(script.Parent:WaitForChild("LocalMeetService"))

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
	NatFloor = Vector3.new(0, -5.00, -1.00),
	NatStandMain = Vector3.new(0, 32.40, 0),
	NatStandEnd = Vector3.new(0, 21.40, 0),
	NatWall = Vector3.new(0, 0.30, 0),
	NatRoofBay = Vector3.new(0, -5.00, 49.31),
	NatTruss = Vector3.new(0, -5.00, -6.40),
	NatHighBay = Vector3.new(0, 0, -1.30),
	NatDrape = Vector3.new(0, 0.70, 0),
	NatStageSet = Vector3.new(-3.23, 13.16, 0),
	NatCurtainPanel = Vector3.new(0, 0.47, 0.30),
	NatCurtainGlow = Vector3.new(0, 1.41, 0.09),
	NatCurtainGap = Vector3.new(0, 0.47, 0.30),
	NatCurtainEndL = Vector3.new(-0.50, 0.60, 0),
	NatCurtainEndR = Vector3.new(0.50, 0.60, 0),
	NatLiveScreen = Vector3.new(0, 0.27, 0),
	NatBanner = Vector3.new(0, 0.30, 0),
	NatCrowdMainA = Vector3.new(1.21, 27.54, 2.50),
	NatCrowdMainB = Vector3.new(1.18, 27.54, 2.50),
	NatCrowdEnd = Vector3.new(1.21, 18.54, 2.50),
}

-- The building (Blender frame: the glass front's middle at 0, the front toward -Y).
local BAY_W, BAYS, DEPTH, EAVE, COL_Y = 26, 6, 70, 22, -7
local PORCH_W, PORCH_D, PORCH_EAVE = 22, 11, 15
-- The hall (Blender frame: the floor's middle at 0; the stages face -Y, toward the main stand).
-- (v03, user 2026-11-17: "make the shell bigger"; platforms 52 apart for a wide walk-through between curtains.)
local WALL_X, WALL_Y_FRONT, WALL_Y_BACK, WALL_Z = 168, -110, 100, 50
local PANEL_W, ROOF_BAYS, SIDE_PANELS, HALL_RIDGE = 42, 8, 5, 62
local FLOOR_X, RAIL_Y, SECTION_W, MAIN_SECTIONS = 120, -42, 20, 12
local ROW_D, ROW_RISE, ROW_BASE, FRONT_WALL_D = 3, 1.6, 2.5, 0.8
local MAIN_ROWS, END_ROWS, END_SECTIONS = 18, 12, 3
local MAIN_CONCOURSE, END_CONCOURSE = 10, 6
local STAGE_W, STAGE_D, STAGE_H = 24, 18, 1.2
-- (v04, user 2026-11-18: "place the banner farther back": the backdrop 7 behind the stage's back edge, was 2.)
local BACKDROP_Y, BACKDROP_W = 25, 28
local VIDEO_Z1 = 29
-- The lifter's curtain at each stage's -X side (v04, user 2026-11-18: "extend the curtain farther"): 4 NatCurtainPanel
-- copies side by side from the backdrop's edge, their fronts BACKDROP_Y - 0.4, 1.2 deep, hanging from CURTAIN_TOP. The
-- middle two hang either side of the split the lifter pushes through (NationalsCurtains swings them on every screen).
local CURTAIN_PANEL_W, CURTAIN_PANELS, CURTAIN_TOP, CURTAIN_DEPTH = 2.5, 4, VIDEO_Z1 + 0.4, 0.93
local CURTAIN_FRONT_Y = BACKDROP_Y - 0.4
local CURTAIN_SPLIT_X = -(BACKDROP_W / 2 + 0.05 + CURTAIN_PANEL_W * CURTAIN_PANELS / 2)
-- The stage set's outer edges either side (with the pipe's uprights): the -X curtain is 10 wide, the +X drape 3.55.
local SET_LEFT_W = BACKDROP_W / 2 + 0.05 + CURTAIN_PANEL_W * CURTAIN_PANELS + 0.4
local SET_RIGHT_W = BACKDROP_W / 2 + 3.9

-- THE MEET AREA (user 2026-11-17: "barricaded all around"; spectators may walk round into the warm-up area but "cant cross
-- the white line"): the barricade line in front of the platforms and down both sides to the white line; the white line
-- behind the backdrops, which only competing lifters pass (StateArenaConfig.CompetitorGroup, set in step 2). Behind it,
-- the LIFTERS' ZONE: each platform's chalk stand, the spot behind its curtain where the lifter waits, its benches, its
-- caller and its lifting order board on the backdrop's back.
local MEET_FRONT_Y, MEET_SIDE_X, WHITE_LINE_Y = -16, 106, 41
-- The live screens (NatLiveScreen, build script v09): over the white line facing the warm-up area, and at the front in the
-- banner's band facing the stands; their bottoms this high.
local WARMUP_SCREEN_Z, FRONT_SCREEN_Y, FRONT_SCREEN_Z = 24, -26, 32
local BARRIER_HEIGHT = 60
local BARRICADE_W = 7
-- Per platform, toward its -X side (where the stage's steps are and the lifter walks out through the curtain's split):
-- the lifter waits facing the split, 3.8 behind the curtain's back (room for the cinematic's shot of their face,
-- NationalsCurtainScene), after chalking up at the stand beside it.
local WAIT_BEHIND_CURTAIN = { x = CURTAIN_SPLIT_X, y = BACKDROP_Y + 4.6 }
local CHALK_AT = { x = -(BACKDROP_W / 2 + 1.8), y = BACKDROP_Y + 6.5 }
-- The walk through (user 2026-11-18: "walking from the curtain, to behind the platform"): the split's zone side, its
-- stage side, along the walkway behind the stage (between its back edge and the backdrop) to the steps in the middle of
-- its back edge, up them, then straight in to the bar (the rack's open side faces the back).
local THROUGH_BACK_Y, THROUGH_FRONT_Y = BACKDROP_Y + 2.2, BACKDROP_Y - 2.6
local STEPS_FOOT_Y, STEPS_TOP_Y = STAGE_D + 2.6, STAGE_D - 0.2
-- The judge's way round the stage to the curtain (the lift-off's cinematic): along the stage's front at this y, behind
-- the -X side referee's chair (-11, -1.5), then down the stage's side at this x (its edge is -12).
local JUDGE_FRONT_Y, JUDGE_SIDE_X = -5.4, -15.5
-- The opening's announcer (the head referee) stands here, between the chair and the barricades, facing the stands; the
-- spotlight on the spot hangs this far toward the stands and this high.
local ANNOUNCE_Y, ANNOUNCE_LIGHT_Y, ANNOUNCE_LIGHT_Z = -11.5, -27, 38
-- ONE ROW OF 10 SEATS PER PLATFORM (40 at Nationals / 4 platforms), nobody inside anybody (user 2026-11-18: "the bench
-- ... big enough for 40 people to fit on them, without phasing through each others body"; it was 2 benches of 5 seats
-- 1.95 apart, and the slimmest body is 2.74 wide). The seats are SEAT_GAP apart: the widest body build (BigBuff, 4.31
-- hand to hand, NationalsConfig.LiftOffScene.BodyWidths) with a little air. The row is 4 MeetBench copies end to end,
-- each BENCH_SCALE as big (11 long: 44 of bench for 10 x 4.4 of lifters), from 20 on the stage's -X side to 24 on its
-- +X side, so 8 stay open between one platform's row and the next. It stands back from the chalk stand's spot and the
-- coach behind it (y 33.2 and 35.2), its back clear of the white line's wall.
local BENCH_Y, BENCH_XS, BENCH_SCALE = 39.2, { -14.5, -3.5, 7.5, 18.5 }, 1.1
local BENCH_LENGTH, BENCH_DEPTH, BENCH_SEAT_TOP = 10 * BENCH_SCALE, 2 * BENCH_SCALE, 1.8 * BENCH_SCALE
local SEATS_PER_PLATFORM, SEAT_GAP, SEAT_FIRST_X = 10, 4.4, -17.8
-- A walk to or from a seat goes by the point this far out in front of where its lifter stands up (LocalMeetVenue
-- .Platform.seatLane), 4.3 from the seat's middle: THE LANE, a line along the row at y 34.9. Measured in Studio
-- 2026-11-18: a sitting lifter reaches 2.01 in front of the seat's middle (hands and feet), a walking one is up to
-- 2.16 wide either side of their middle (they walk the lane sideways-on to the bench), so the lane is the one line
-- clear of both the sitting lifters (to y 37.2) and the chalk stand (from y 32.3) and the caller. The lift-off's
-- lifters stand on the same line (NationalsConfig.LiftOffScene.LiftersBehindStuds: the curtain's spot is at y 29.6).
local SEAT_LANE = 3.0
-- A referee chair's seat (as LocalMeetVenue).
local CHAIR_SEAT_TOP = 1.84
local CALLER_AT = { x = 6.5, y = 31 }
-- The warm-up area: rows of racks anyone may use (user 2026-11-17).
local WARMUP_ROWS, WARMUP_XS = { 52, 66, 80 }, { -81, -63, -45, -27, -9, 9, 27, 45, 63, 81 }

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
	-- The video wall's screen and its lifter display (who is lifting; the live minigame drawn over it).
	screen: BasePart?,
	display: LifterDisplay.Handle,
	-- The spot right behind the -X curtain where the lifter waits before stepping out, facing the stage side (step 2's
	-- walk-out), and where they chalk up at the stand.
	waitSpot: CFrame,
	chalkSpot: CFrame,
	-- The benches' seats (disabled until step 2 seats the waiting lifters), the caller's speech bubble, the order board.
	seats: { Seat },
	callerLine: TextLabel?,
	orderBoard: ((heading: string, lines: { string }) -> ())?,
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
	-- The porch's floating sign (NATIONALS, the event, the time to the next one).
	sign: StyledScreen.FloatingHandle?,
	-- The hall as a meet venue (the Nationals meet runs on it, LocalMeetService).
	meet: LocalMeetVenue.Venue,
}

-- The player's living character, root part and humanoid, or nils.
local function bodyOfAlive(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, root, humanoid
end

local venue: Venue? = nil
local visitors: { [Player]: { connections: { RBXScriptConnection } } } = {}
-- The hall's warm-up racks (buildHall) and the warm-up that runs them (build).
local hallWarmUpRacks: { LocalMeetVenue.WarmUpRack } = {}
local warmUp: LocalMeetWarmUp.WarmUp? = nil
local lastPress: { [Player]: number } = {}
-- The platforms whose lifter is behind the curtain or out lifting, for the crowd's chant (rack -> what it is for).
local chanting: { [number]: { lift: string, forFirst: boolean, at: number } } = {}
-- Each platform's light over the spot behind its curtain (on while a lifter waits there), and how bright it is then.
local curtainTopLights: { [number]: SpotLight? } = {}
local CURTAIN_TOP_LIGHT_BRIGHTNESS = 5

-- Off a warm-up rack (if on one), without stepping them off: the caller moves them.
local function stopWarmUp(player: Player)
	local current = warmUp
	if current then
		current.stop(player, false)
	end
end

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
	-- (The porch's sign board is left out: its words float there instead, user 2026-11-18. See build.)
	local porch = place(model, "NatPorch", at(origin, 0, 0, 0), 1, { "SignFrame", "SignScreen" })
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

local function buildHall(origin: CFrame): (Model, { Stage }, CFrame, BasePart, BasePart?, StyledScreen.Handle?, LocalMeetVenue.Venue)
	local model = Instance.new("Model")
	model.Name = "NationalsHall"
	place(model, "NatFloor", at(origin, 0, 0, 0))
	for k = 0, MAIN_SECTIONS - 1 do
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
		for k = 0, SIDE_PANELS - 1 do
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

	-- The four platforms: stage set, competition rack, plate trees, referee chairs, the spotlight and the drapes' wash; and
	-- behind each, in the lifters' zone, its chalk stand, benches, caller and lifting order board.
	local stages: { Stage } = {}
	local platforms: { LocalMeetVenue.Platform } = {}
	local white, purple = Color3.fromRGB(255, 247, 235), Color3.fromRGB(150, 80, 255)
	for i, x in ipairs(NationalsConfig.PlatformXs) do
		local set = place(model, "NatStageSet", at(origin, x, 0, 0))
		local holder = Instance.new("Folder")
		holder.Name = "Platform_" .. i
		holder.Parent = model
		-- The gear (rack, referee chairs, light box): taken away while the awards stage stands, as on every platform.
		local gear = Instance.new("Folder")
		gear.Name = "Gear_" .. i
		gear.Parent = holder
		MockMeetArena.placeRack(gear, at(origin, x, 9, STAGE_H).Position, math.pi)
		local platformRack = gear:FindFirstChild("CompetitionRack") :: Model?
		if platformRack then
			-- No rack on a meet's deadlift, so the bar lies in the platform's middle (as LocalMeetVenue.platformGear).
			platformRack:SetAttribute("DeadliftAtCentre", true)
		end
		for _, sx in ipairs({ -1, 1 }) do
			place(holder, "PlateTree", at(origin, x + sx * 10.4, 15.5, STAGE_H, 180))
		end
		-- The three referees: the head referee in front of the stage, the side referees at its front corners.
		local refSeats: { CFrame } = {}
		for _, chair in ipairs({ { dx = -11, y = -1.5, turn = 180 + 25 }, { dx = 0, y = -6, turn = 180 }, { dx = 11, y = -1.5, turn = 180 - 25 } }) do
			local copy = place(gear, "RefChair", at(origin, x + chair.dx, chair.y, 0, chair.turn))
			if copy then
				local pivot = copy:GetPivot()
				local hips = pivot.Position + Vector3.new(0, CHAIR_SEAT_TOP, 0) - pivot.LookVector * 0.45
				table.insert(refSeats, CFrame.lookAt(hips, hips + pivot.LookVector))
			end
		end
		-- The referees' light box at the stage's front right corner, facing the stands.
		local lamps: { BasePart } = {}
		local lightBox = place(gear, "RefLights", at(origin, x + STAGE_W / 2 + 2.5, 1, 0))
		if lightBox then
			for lamp = 1, 3 do
				local part = lightBox:FindFirstChild("RefLights_Lamp" .. lamp, true)
				if part and part:IsA("BasePart") then
					table.insert(lamps, part)
				end
			end
		end
		spot(model, "StageSpot_" .. i, at(origin, x, -4, 44), at(origin, x, 9, 0).Position, 9, 70, 42, white)
		for sx, cx in pairs({ [-1] = x + CURTAIN_SPLIT_X, [1] = x + (BACKDROP_W / 2 + 1.8) }) do
			spot(model, "DrapeWash_" .. i .. "_" .. sx, at(origin, cx, 13, 2), at(origin, cx, BACKDROP_Y, 22).Position, 3, 30,
				if sx < 0 then 45 else 35, purple)
		end
		-- Solid: the stage, and the backdrop with its curtains (nobody walks through them: the meet walks a lifter through
		-- the split, held still, LocalMeetService). The backdrop's solid also stops the camera (NationalsConfig.CameraBlockTag,
		-- user 2026-11-18: after a lift "your camera is seen going behind the screen").
		solid(model, "Stage_Solid_" .. i, origin, Vector3.new(x, STAGE_D / 2, STAGE_H / 2), Vector3.new(STAGE_W, STAGE_D, STAGE_H))
		local backdropSolid = solid(model, "Backdrop_Solid_" .. i, origin,
			Vector3.new(x + (SET_RIGHT_W - SET_LEFT_W) / 2, BACKDROP_Y + 0.6, VIDEO_Z1 / 2),
			Vector3.new(SET_LEFT_W + SET_RIGHT_W, 1.8, VIDEO_Z1))
		CollectionService:AddTag(backdropSolid, NationalsConfig.CameraBlockTag)

		-- The lifter's curtain: 4 panels; the middle two hang either side of the split and swing apart as someone walks
		-- through (NationalsCurtains, on every screen: each carries its hinge, the way to the split and the stage's way).
		local curtain = Instance.new("Folder")
		curtain.Name = "Curtain_" .. i
		curtain.Parent = holder
		local splitAt = at(origin, x + CURTAIN_SPLIT_X, CURTAIN_FRONT_Y + CURTAIN_DEPTH / 2, 0).Position
		for k = 0, CURTAIN_PANELS - 1 do
			local px = -(BACKDROP_W / 2 + 0.05) - CURTAIN_PANEL_W * (k + 0.5)
			local panel = place(curtain, "NatCurtainPanel", at(origin, x + px, CURTAIN_FRONT_Y, 0))
			local cloth = panel and panel:FindFirstChild("NatCurtainPanel_Cloth", true)
			local flap = k == CURTAIN_PANELS / 2 - 1 or k == CURTAIN_PANELS / 2
			if cloth and cloth:IsA("BasePart") and flap then
				-- Hung from its top edge's far corner (away from the split), in the middle of its depth.
				local away = if k < CURTAIN_PANELS / 2 then 1 else -1
				local hinge = at(origin, x + px + away * CURTAIN_PANEL_W / 2, CURTAIN_FRONT_Y + CURTAIN_DEPTH / 2, CURTAIN_TOP)
				cloth:SetAttribute("Hinge", hinge.Position)
				cloth:SetAttribute("Rest", cloth.CFrame)
				cloth:SetAttribute("Split", splitAt)
				cloth:SetAttribute("TowardStage", dirOf(origin, 0, -1, 0))
				-- (for the reveal shot from the stage side, NationalsCurtainScene)
				cloth:SetAttribute("StageCentre", at(origin, x, 9, 0).Position)
				CollectionService:AddTag(cloth, NationalsConfig.CurtainFlapTag)
			end
		end
		-- The stage's light, leaking through the split and under the hem (a lit stage behind a curtain), seen from the
		-- lifters' zone (NatCurtainGlow, made in Blender like every model); NationalsCurtains hides the split's line while
		-- the curtain is parted.
		local glowModel = place(curtain, "NatCurtainGlow", at(origin, x + CURTAIN_SPLIT_X, CURTAIN_FRONT_Y, 0))
		local splitGlow = glowModel and glowModel:FindFirstChild("NatCurtainGlow_Split", true)
		local hemGlow = glowModel and glowModel:FindFirstChild("NatCurtainGlow_Hem", true)
		for _, glow in ipairs({ splitGlow, hemGlow }) do
			-- (light only: no camera ray or touch stops at it)
			if glow and glow:IsA("BasePart") then
				glow.CanCollide = false
				glow.CanQuery = false
				glow.CanTouch = false
			end
		end
		if splitGlow and splitGlow:IsA("BasePart") then
			splitGlow:SetAttribute("Split", splitAt)
			CollectionService:AddTag(splitGlow, NationalsConfig.CurtainGlowTag)
		end
		if hemGlow and hemGlow:IsA("BasePart") then
			-- Its light on the floor and the waiting lifter's legs.
			local leak = Instance.new("SpotLight")
			leak.Face = Enum.NormalId.Top
			leak.Brightness = 1.2
			leak.Range = 9
			leak.Angle = 120
			leak.Color = Color3.fromRGB(255, 226, 180)
			leak.Shadows = false
			leak.Parent = hemGlow
		end
		-- The light over the spot behind the curtain (like a performer's top light in the wings), on while a lifter waits
		-- there (the behindCurtain hook).
		local topLight = spot(model, "CurtainTopLight_" .. i, at(origin, x + WAIT_BEHIND_CURTAIN.x, WAIT_BEHIND_CURTAIN.y + 1.5, 15),
			at(origin, x + WAIT_BEHIND_CURTAIN.x, WAIT_BEHIND_CURTAIN.y - 0.5, 0).Position, 0, 22, 40, Color3.fromRGB(255, 236, 205))
		curtainTopLights[i] = topLight:FindFirstChildOfClass("SpotLight")
		-- The video wall: who is lifting here, and their minigame live during the lift (LifterDisplay; MeetLiveScreens draws
		-- the live minigame over it on each player's device, as on a State rack's screen).
		local screen = set and set:FindFirstChild("NatStageSet_Screen", true) :: BasePart?
		local displayPart = screen or marker(holder, "VideoWallScreen", at(origin, x, BACKDROP_Y, 22), Vector3.new(25, 13, 0.2))
		-- (While nobody is on them the screens say where this is: before, the Local meet's "OPEN / SIGN UP AT THE DESK".)
		local idle: LifterDisplay.Idle = { name = "CENTRAL " .. NationalsConfig.EventTitle, line = NationalsConfig.EventSub,
			facts = { "CENTRAL " .. NationalsConfig.EventTitle, "ONE CHAMPION IN EVERY CLASS", "THE ROAD TO WORLDS" } }
		local display = LifterDisplay.build(displayPart, dirOf(origin, 0, -1, 0), i, MeetConfig.LiftOrder, nil, idle)
		-- The same on this platform's two live screens (user 2026-11-18: "a screen at the warm up area that shows the
		-- lifters live game. same thing for the front"): one high over the white line facing the warm-up area, one at the
		-- front facing the stands (NatLiveScreen; the live minigame is drawn on every one of them, MeetLiveScreens).
		for _, spot in ipairs({ { at = at(origin, x, WHITE_LINE_Y, WARMUP_SCREEN_Z, 180), out = dirOf(origin, 0, 1, 0) },
			{ at = at(origin, x, FRONT_SCREEN_Y, FRONT_SCREEN_Z), out = dirOf(origin, 0, -1, 0) } }) do
			local live = place(holder, "NatLiveScreen", spot.at)
			local livePart = live and live:FindFirstChild("NatLiveScreen_Screen", true)
			if livePart and livePart:IsA("BasePart") then
				display = LifterDisplay.together(display, LifterDisplay.build(livePart, spot.out, i, MeetConfig.LiftOrder, true,
					idle))
			end
		end

		-- The lifters' zone (as at State): the chalk stand, then the spot right behind the curtain where the lifter waits
		-- before stepping out (the Nationals walk-out, step 2), the benches facing the backdrop, the caller, the order board.
		local zone = Instance.new("Folder")
		zone.Name = "LiftersZone_" .. i
		zone.Parent = model
		place(zone, "MeetChalkStand", at(origin, x + CHALK_AT.x, CHALK_AT.y, 0, 180))
		solid(zone, "ChalkStand_Solid", origin, Vector3.new(x + CHALK_AT.x, CHALK_AT.y, 2), Vector3.new(1.6, 1.6, 4))
		local seats: { Seat } = {}
		for b, bx in ipairs(BENCH_XS) do
			local bench = place(zone, "MeetBench", at(origin, x + bx, BENCH_Y, 0))
			if bench then
				bench:ScaleTo(BENCH_SCALE)
			end
			solid(zone, "Bench_Solid_" .. b, origin, Vector3.new(x + bx, BENCH_Y, BENCH_SEAT_TOP / 2),
				Vector3.new(BENCH_LENGTH, BENCH_DEPTH, BENCH_SEAT_TOP))
		end
		-- The seats along the row, handed out from the caller's side outward (a small field sits together, by the caller).
		local seatXs: { number } = {}
		for k = 1, SEATS_PER_PLATFORM do
			table.insert(seatXs, SEAT_FIRST_X + (k - 1) * SEAT_GAP)
		end
		table.sort(seatXs, function(a: number, b: number)
			return math.abs(a - CALLER_AT.x) < math.abs(b - CALLER_AT.x)
		end)
		for _, seatX in ipairs(seatXs) do
			local sx = x + seatX
			local seat = Instance.new("Seat")
			seat.Name = "BenchSeat"
			seat.Size = Vector3.new(2, 0.2, 1.6)
			seat.CFrame = CFrame.lookAt(at(origin, sx, BENCH_Y, BENCH_SEAT_TOP - 0.1).Position,
				at(origin, sx, BENCH_Y - 1, BENCH_SEAT_TOP - 0.1).Position)
			seat.Anchored = true
			seat.CanCollide = false
			seat.CanTouch = false
			-- (Step 2 sits the waiting lifters here.)
			seat.Disabled = true
			seat.Transparency = 1
			seat.CastShadow = false
			seat.Parent = zone
			table.insert(seats, seat)
		end
		local callerLine = MeetFigures.build(zone, "Caller", at(origin, x + CALLER_AT.x, CALLER_AT.y, 0).Position,
			at(origin, x + CALLER_AT.x, BENCH_Y, 0).Position)
		local caller = zone:FindFirstChild("Caller")
		if caller then
			caller:SetAttribute("Platform", i)
		end
		-- The lifting order board on the backdrop's back, facing the benches (who is up, on deck, in the hole, ...).
		local showOrder: ((heading: string, lines: { string }) -> ())? = nil
		local board = RoomProps.propCopy("MeetBoard", 1)
		local boardScreen = board and board:FindFirstChild("MeetBoard_Screen", true)
		if board and boardScreen and boardScreen:IsA("BasePart") then
			board.Name = "LiftingOrderBoard"
			board:ScaleTo(0.6)
			local towardBenches = dirOf(origin, 0, 1, 0)
			MockMeetArena.hangOnWall(board, boardScreen, at(origin, x, BACKDROP_Y + 1.02, 0).Position, towardBenches,
				at(origin, x, BACKDROP_Y + 1.02, 9.5).Position)
			board.Parent = zone
			local written = StyledScreen.build(boardScreen, StyledScreen.faceToward(boardScreen, towardBenches), "LIFTING ORDER",
				{ "WAITING FOR THE ROUND", "", "", "", "" }, "chevron")
			showOrder = function(heading: string, lines: { string })
				written.setTag(heading)
				written.setLines(lines)
			end
		elseif board then
			board:Destroy()
		end
		-- The cheering zones (§36.4): the stands in front of this platform, as wide as it, and (once, below) the meet area.
		-- (as wide as the stage set's narrower half twice: the zones of neighbouring platforms never overlap)
		local zoneW = 2 * SET_RIGHT_W
		local standsNear, standsFar = RAIL_Y - 1, RAIL_Y - rowFront(MAIN_ROWS) - MAIN_CONCOURSE
		local cheer = marker(holder, "CheerZone_Stands", at(origin, x, (standsNear + standsFar) / 2, 20),
			Vector3.new(zoneW, 44, standsNear - standsFar))
		cheer:SetAttribute(CheerConfig.ZoneRackAttribute, i)
		CollectionService:AddTag(cheer, CheerConfig.ZoneTag)

		-- Where everything happens on a turn, in the meet's own shape (LocalMeetVenue.Platform). The lifter chalks up behind
		-- the stand, walks to the spot right behind the curtain's split (the Nationals walk-out, LocalMeetService), then
		-- pushes through it (user 2026-11-18), down beside the stage and up its steps to the bar. The walk back comes the same
		-- way, through the split.
		local facingStands = dirOf(origin, 0, -1, 0)
		local function floorSpot(bx: number, by: number, bz: number?): Vector3
			return at(origin, x + bx, by, bz or 0).Position
		end
		local chalkAt = floorSpot(CHALK_AT.x, CHALK_AT.y + 1.7)
		local curtainAt = floorSpot(WAIT_BEHIND_CURTAIN.x, WAIT_BEHIND_CURTAIN.y)
		local liftAt = floorSpot(0, 15.2, STAGE_H)
		local side = -dirOf(origin, 1, 0, 0) -- toward the stage's -X side (where the steps and the walk out are)
		-- The coach follows the lifter through the split (the curtain line is closed all the way across, v08) and watches
		-- from beside the stage's front, out past the curtain's outer end.
		local coachX = -(SET_LEFT_W + 2.4)
		local platform: LocalMeetVenue.Platform = {
			index = i,
			liftSpot = CFrame.lookAt(liftAt, liftAt + facingStands),
			waitSpot = CFrame.lookAt(chalkAt, chalkAt + facingStands),
			walkOut = { floorSpot(CURTAIN_SPLIT_X, THROUGH_BACK_Y), floorSpot(CURTAIN_SPLIT_X, THROUGH_FRONT_Y),
				floorSpot(-1.2, THROUGH_FRONT_Y), floorSpot(0, STEPS_FOOT_Y), floorSpot(0, STEPS_TOP_Y, STAGE_H) },
			styleFrom = floorSpot(CURTAIN_SPLIT_X, THROUGH_FRONT_Y),
			rack = platformRack,
			privateTags = {},
			display = display,
			lamps = lamps,
			refSeats = refSeats,
			stageLight = nil,
			-- (1.5 nearer the backdrop than at first, y 31: clear of the lifters' lane along the benches, SEAT_LANE; at
			-- y 32.5 a wide lifter walking the lane put an arm through the coach, Studio 2026-11-18.)
			coachSpot = floorSpot(-11, CHALK_AT.y - 0.5),
			coachDoorSpot = CFrame.lookAt(floorSpot(coachX, 4), floorSpot(0, 15.2)),
			coachWay = { floorSpot(CURTAIN_SPLIT_X, THROUGH_BACK_Y), floorSpot(CURTAIN_SPLIT_X, THROUGH_FRONT_Y) },
			coachBackVia = nil,
			coachFrontVia = nil,
			coachBackSpot = CFrame.lookAt(chalkAt + dirOf(origin, 0, 1, 0) * LocalMeetConfig.Chalk.CoachBehindStuds, chalkAt),
			coachFrontSpot = CFrame.lookAt(chalkAt + side * 2.5, chalkAt),
			chalkStandSpot = at(origin, x + CHALK_AT.x, CHALK_AT.y, 0, 180),
			chalkCentre = chalkAt + Vector3.new(0, 2.8, 0),
			chalkOut = side,
			gear = gear,
			gearHome = holder,
			staff = (function()
				local staff = Instance.new("Folder")
				staff.Name = "Staff"
				staff.Parent = holder
				-- The coach walks through the curtain's split too: the curtain parts for them (NationalsCurtains).
				-- So does the head referee, as the lift-off's judge (the other two never leave their chairs).
				staff.ChildAdded:Connect(function(child)
					if child:IsA("Model") and (child.Name == "Coach" or child.Name == "Referee") then
						CollectionService:AddTag(child, NationalsConfig.CurtainWalkerTag)
					end
				end)
				return staff
			end)(),
			coachLine = nil,
			headRefLine = nil,
			spotters = {},
			spotterLift = nil,
			seats = seats,
			seatLane = SEAT_LANE,
			callerLine = callerLine,
			caller = if caller and caller:IsA("Model") then caller else nil,
			orderBoard = showOrder,
			curtainSpot = CFrame.lookAt(curtainAt, curtainAt + facingStands),
			-- The head referee's way to the lifters' zone (the lift-off's judge, user 2026-11-18): from in front of the
			-- chair, behind the -X side referee's chair, down the stage's -X side to the walkway behind it, and through the
			-- curtain's split.
			judgeWay = { floorSpot(-7, JUDGE_FRONT_Y), floorSpot(JUDGE_SIDE_X, JUDGE_FRONT_Y + 0.6),
				floorSpot(JUDGE_SIDE_X, STAGE_D + 2.2), floorSpot(CURTAIN_SPLIT_X, THROUGH_FRONT_Y),
				floorSpot(CURTAIN_SPLIT_X, THROUGH_BACK_Y) },
			-- The opening's announcer (user 2026-11-18: "pans to the announcer (a judge), talking to the crowd under a
			-- spotlight"): the head referee walks round the chair to stand between it and the barricades, facing the
			-- stands, under a spotlight of their own (off until then).
			announceSpot = CFrame.lookAt(floorSpot(0, ANNOUNCE_Y), floorSpot(0, ANNOUNCE_Y - 1)),
			announceWay = { floorSpot(2.7, JUDGE_FRONT_Y - 0.2), floorSpot(2.7, ANNOUNCE_Y + 2.4) },
			announceLight = spot(model, "AnnouncerSpot_" .. i, at(origin, x, ANNOUNCE_LIGHT_Y, ANNOUNCE_LIGHT_Z),
				floorSpot(0, ANNOUNCE_Y, 3.6), 0, 60, 13, Color3.fromRGB(255, 250, 240)):FindFirstChildOfClass("SpotLight"),
		}
		table.insert(platforms, platform)
		table.insert(stages, {
			frame = at(origin, x, 0, 0),
			liftSpot = platform.liftSpot,
			screen = screen,
			display = display,
			waitSpot = platform.curtainSpot :: CFrame,
			chalkSpot = platform.waitSpot,
			seats = seats,
			callerLine = callerLine,
			orderBoard = showOrder,
		})
	end
	-- The curtain runs closing the curtain line between the stage sets and out to the side barricades (user 2026-11-18:
	-- "place a curtain that coveres these open areas"; build_nationals_arena_02.py curtain_run_spots), each with a hidden
	-- wall that also stops the camera. (The stage sets' outer edges with their uprights: -24.45 and +18.)
	local setLeft, setRight = -SET_LEFT_W, BACKDROP_W / 2 + 4
	local xs = NationalsConfig.PlatformXs
	local runs: { { item: string, from: number, to: number } } = {
		{ item = "NatCurtainEndL", from = -MEET_SIDE_X, to = xs[1] + setLeft },
		{ item = "NatCurtainEndR", from = xs[#xs] + setRight, to = MEET_SIDE_X },
	}
	for k = 1, #xs - 1 do
		table.insert(runs, { item = "NatCurtainGap", from = xs[k] + setRight, to = xs[k + 1] + setLeft })
	end
	for index, run in ipairs(runs) do
		local cx = (run.from + run.to) / 2
		place(model, run.item, at(origin, cx, CURTAIN_FRONT_Y, 0))
		local wall = solid(model, "CurtainRun_Solid_" .. index, origin, Vector3.new(cx, BACKDROP_Y + 0.6, VIDEO_Z1 / 2),
			Vector3.new(run.to - run.from, 1.8, VIDEO_Z1))
		CollectionService:AddTag(wall, NationalsConfig.CameraBlockTag)
	end

	-- The lifters' cheering zone: the meet area and the lifters' zone, where each picks the lifter they cheer for.
	local choiceZone = marker(model, "CheerZone_MeetArea", at(origin, 0, (MEET_FRONT_Y + WHITE_LINE_Y) / 2, 10),
		Vector3.new(2 * MEET_SIDE_X, 22, WHITE_LINE_Y - MEET_FRONT_Y))
	choiceZone:SetAttribute(CheerConfig.ZoneChoiceAttribute, true)
	CollectionService:AddTag(choiceZone, CheerConfig.ZoneTag)
	-- The banner's own light, and plain working lights over the warm-up area.
	spot(model, "BannerSpot", at(origin, 0, -60, 30), at(origin, 0, -26, 38).Position, 4, 60, 30, white)
	for _, x in ipairs({ -80, -40, 0, 40, 80 }) do
		local lamp = marker(model, "WarmUpLight_" .. x, at(origin, x, 64, 24))
		local light = Instance.new("PointLight")
		light.Brightness = 1.1
		light.Range = 40
		light.Color = Color3.fromRGB(255, 240, 220)
		light.Shadows = false
		light.Parent = lamp
	end

	-- The meet area's barricades (where the officials' desks stood, user 2026-11-17) and down both sides to the white line,
	-- each line with a hidden wall too high to jump; the white line's own hidden wall. All in the meet barrier's collision
	-- group: competing lifters pass (StateArenaVenue.setCompetitor, in step 2), nobody else.
	StateArenaVenue.registerCollisionGroups()
	local barriers = Instance.new("Folder")
	barriers.Name = "Barricades"
	barriers.Parent = model
	local count = 0
	local function barrierWall(name: string, centre: Vector3, size: Vector3)
		local wall = solid(barriers, name, origin, centre, size)
		wall.CollisionGroup = StateArenaConfig.MeetBarrierGroup
	end
	local function barricadeLine(from: Vector2, to: Vector2, turnDeg: number)
		local length = (to - from).Magnitude
		local n = math.ceil(length / BARRICADE_W)
		for k = 0, n - 1 do
			local p = from:Lerp(to, (k + 0.5) / n)
			count += 1
			place(barriers, "Barricade", at(origin, p.X, p.Y, 0, turnDeg))
		end
		local mid = (from + to) / 2
		barrierWall("BarricadeWall_" .. count, Vector3.new(mid.X, mid.Y, BARRIER_HEIGHT / 2),
			Vector3.new(math.abs(to.X - from.X) + 1, math.abs(to.Y - from.Y) + 1, BARRIER_HEIGHT))
	end
	barricadeLine(Vector2.new(-MEET_SIDE_X, MEET_FRONT_Y), Vector2.new(MEET_SIDE_X, MEET_FRONT_Y), 0)
	for _, s in ipairs({ -1, 1 }) do
		barricadeLine(Vector2.new(s * MEET_SIDE_X, MEET_FRONT_Y), Vector2.new(s * MEET_SIDE_X, WHITE_LINE_Y), 90 * s)
	end
	barrierWall("WhiteLineWall", Vector3.new(0, WHITE_LINE_Y, BARRIER_HEIGHT / 2), Vector3.new(2 * MEET_SIDE_X + 1, 1, BARRIER_HEIGHT))

	-- The warm-up area: rows of competition racks anyone in the hall may use (LocalMeetWarmUp, made in build).
	local warmUp = Instance.new("Folder")
	warmUp.Name = "WarmUp"
	warmUp.Parent = model
	local warmUpRacks: { LocalMeetVenue.WarmUpRack } = {}
	for _, rowY in ipairs(WARMUP_ROWS) do
		for _, rx in ipairs(WARMUP_XS) do
			local holder = Instance.new("Folder")
			holder.Name = "WarmUpRack_" .. #warmUpRacks + 1
			holder.Parent = warmUp
			local placed, problem = MockMeetArena.placeRack(holder, at(origin, rx, rowY, 0).Position)
			if not placed then
				warn("[NationalsArenaVenue] a warm-up rack was not placed: " .. tostring(problem))
				continue
			end
			local rack = holder:FindFirstChild("CompetitionRack") :: Model?
			if rack then
				StationVisuals.show(rack, nil)
			end
			local spotAt = at(origin, rx, rowY - LocalMeetConfig.WarmUp.LiftSpotInFrontStuds, 0).Position
			local point = marker(holder, "WarmUpPoint", CFrame.new(spotAt + Vector3.new(0, 2, 0)), Vector3.new(2, 4, 2))
			table.insert(warmUpRacks, {
				index = #warmUpRacks + 1,
				rack = rack,
				liftSpot = CFrame.lookAt(spotAt, spotAt + dirOf(origin, 0, -1, 0)),
				point = point,
			})
		end
	end
	for _, part in ipairs(warmUp:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end
	model:SetAttribute("WarmUpRacks", #warmUpRacks)
	hallWarmUpRacks = warmUpRacks

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
	-- The walls and the roof stop the camera too (user 2026-11-18: you shouldn't "see behind [the] building by just simply
	-- zooming out"; HallCameraGuard on each screen). The barricades' and the white line's hidden walls never do.
	for _, name in ipairs({ "WallFront_Solid", "WallBack_Solid", "WallSide_Solid", "Roof_Solid" }) do
		for _, part in ipairs(model:GetChildren()) do
			if part.Name == name then
				CollectionService:AddTag(part, NationalsConfig.CameraBlockTag)
			end
		end
	end
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
	for k = 0, MAIN_SECTIONS - 1 do
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
	-- (Twice the size it was, user 2026-11-18: "make the exit sign in the back bigger"; on a phone it is the only way out.)
	local exitSign = BuildParts.placed(model, "ExitSign", Vector3.new(13, 5.4, 0.3), at(origin, 10, concourseY - 4.6, concourseZ + 7),
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

	-- The hall as a meet venue (LocalMeetVenue.Venue), for the Nationals meet (LocalMeetService): the awards stage in the
	-- middle gap between platforms 2 and 3 with its podium in front, and the spectators' floor where lifters end up.
	-- The announcer's welcome, over the hall's speakers: one sound high over the middle of the floor, heard at much the
	-- same level everywhere in the hall (NationalsScenes plays it; made once so every screen has it loaded).
	local speakers = marker(model, "AnnouncerSpeakers", at(origin, 0, -10, 30))
	local voice = Instance.new("Sound")
	voice.Name = "AnnouncerVoice"
	voice.SoundId = NationalsConfig.WelcomeVoiceId
	voice.Volume = NationalsConfig.Opening.VoiceVolume
	voice.RollOffMode = Enum.RollOffMode.Linear
	voice.RollOffMinDistance = 220
	voice.RollOffMaxDistance = 420
	voice.Parent = speakers
	-- The opening's camera tour (NationalsScenes): from high over the far end of the main stand, down across the crowd
	-- and along the lit platforms, to a spot on the spectators' floor in front of platform `platformIndex`'s announcer.
	-- It flies between the hanging lamps' rows and under the banner.
	local function tourFor(platformIndex: number): { LocalMeetVenue.TourPoint }
		local a = NationalsConfig.PlatformXs[platformIndex] or 0
		local s = if a < 0 then -1 else 1
		local far = -s * 96
		local function point(ex: number, ey: number, ez: number, lx: number, ly: number, lz: number): LocalMeetVenue.TourPoint
			return { eye = at(origin, ex, ey, ez).Position, look = at(origin, lx, ly, lz).Position }
		end
		return {
			point(far, -84, 42, far * 0.3, 0, 6),
			point(far + (a - far) * 0.35, -66, 34, far * 0.3 + (a - far * 0.3) * 0.45, 6, 8),
			point(far + (a - far) * 0.7, -46, 24, far * 0.3 + (a - far * 0.3) * 0.8, 8, 8),
			point(a - s * 14, -31, 12, a, -6, 6),
			point(a - s * 5, -22.5, 5.2, a, ANNOUNCE_Y, 4.6),
		}
	end
	local awards, backdropTitle, podiumSpots = LocalMeetVenue.awardsStage(at(origin, 0, 6, 0).Position)
	local lobbyAt = at(origin, 0, -26, 0).Position
	local meetVenue: LocalMeetVenue.Venue = {
		model = model,
		arrival = inside,
		lobbySpot = CFrame.lookAt(lobbyAt, lobbyAt + dirOf(origin, 0, 1, 0)),
		platforms = platforms,
		signUpPoint = deskPoint or exitPoint,
		exitPoint = exitPoint,
		scoreboard = nil,
		banner = nil,
		deskScreen = nil,
		backdropTitle = backdropTitle,
		awards = awards,
		podiumSpots = podiumSpots,
		-- (Its warm-up racks run on their own warm-up, for anyone in the hall: build.)
		warmUpRacks = {},
		tour = tourFor,
		announcerVoice = voice,
	}
	LocalMeetVenue.setLevel(meetVenue, NationalsConfig.EventTitle, {}, 0)
	return model, stages, inside, exitPoint, deskPoint, deskScreen, meetVenue
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
		warn("[NationalsArenaVenue] NationalsArena_09 did not load: no Nationals building")
		return nil
	end
	probe:Destroy()
	local buildingOrigin = CFrame.new(NationalsConfig.BuildingOrigin) * CFrame.Angles(0, math.pi, 0)
	local building, outside, _ = buildBuilding(buildingOrigin)
	building.Parent = Workspace
	local hallFrame = CFrame.new(NationalsConfig.HallOrigin)
	local hall, stages, inside, exitPoint, deskPoint, deskScreen, meetVenue = buildHall(hallFrame)
	hall.Parent = Workspace
	-- The porch's sign as big floating text high over the MIDDLE of the building (user 2026-11-18: "replace them with
	-- floating text UI with the same names and timers", "make it float on top the building and make the text bigger",
	-- "put it higher and put it in the middle"): NATIONALS, NATIONAL CHAMPIONSHIP, and the time to the next one
	-- (NationalsService writes the lines).
	local _, buildingSize = building:GetBoundingBox()
	local buildingTop = building:GetBoundingBox().Position.Y + buildingSize.Y / 2
	local sign = StyledScreen.floatAbove(building, at(buildingOrigin, 0, DEPTH / 2, 0).Position, buildingTop,
		NationalsConfig.EventTitle, { "National Championship", "" }, "bar", 56, 22, 12, 1200)
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
		meet = meetVenue,
	}
	-- The meet system holds the hall as its Nationals hall: everyone inside is its visitor (sounds, standings, awards), and
	-- the Nationals meet runs on its platforms. Leaving by the meet screen's EXIT lands them outside the porch.
	LocalMeetService.setNationalsVenue(meetVenue, outside, {
		onLeft = function(player: Player)
			stopWarmUp(player)
			player:SetAttribute(NationalsConfig.InHallAttribute, nil)
		end,
		stopWarmUp = function(player: Player)
			stopWarmUp(player)
		end,
		-- The crowd's chant (the hall model's NationalsConfig.ChantAttribute, which each player's NationalsChant plays): for
		-- whoever waits behind a curtain, "forFirst" ones first, else the latest; nil when nobody is.
		chant = function(rack: number, lift: string?, forFirst: boolean?)
			chanting[rack] = if lift then { lift = lift, forFirst = forFirst == true, at = os.clock() } else nil
			local latest: { lift: string, forFirst: boolean, at: number }? = nil
			for _, entry in pairs(chanting) do
				if latest == nil or (entry.forFirst and not latest.forFirst)
					or (entry.forFirst == latest.forFirst and entry.at > latest.at) then
					latest = entry
				end
			end
			hall:SetAttribute(NationalsConfig.ChantAttribute,
				if latest == nil then nil elseif latest.forFirst then "ForTheWin" else latest.lift)
		end,
		-- Who waits behind platform `rack`'s curtain: the hall model's "BehindCurtain<rack>" attribute (name · class), for
		-- the screens and lights to follow.
		behindCurtain = function(rack: number, name: string?, classLabel: string?)
			hall:SetAttribute("BehindCurtain" .. rack, if name then name .. "  ·  " .. (classLabel or "") else nil)
			-- Their top light in the wings, while they wait (user 2026-11-18: "cinematic ... with camera angles and lighting").
			local light = curtainTopLights[rack]
			if light then
				light.Brightness = if name then CURTAIN_TOP_LIGHT_BRIGHTNESS else 0
			end
		end,
	})
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

	-- The warm-up racks, for anyone in the hall (user 2026-11-17). Its own LocalMeetWarmUp, as the gym's practice racks have
	-- (GymPractice): the same lifts, weights, minigames and animations, PRACTICE ONLY (nothing is saved).
	local set = LocalMeetRemotes.createOnServer(ReplicatedStorage)
	warmUp = LocalMeetWarmUp.new(hallWarmUpRacks, set, {
		canUse = function(player: Player): (boolean, string?)
			local character, _, humanoid = bodyOfAlive(player)
			if character == nil or humanoid == nil then
				return false, nil
			end
			if player:GetAttribute(NationalsConfig.InHallAttribute) ~= true then
				return false, "These racks are for the people in the Nationals hall."
			end
			if LiftAttemptService.isAttemptActive(player) then
				return false, "Finish your lift first."
			end
			return true, nil
		end,
		standAt = function(player: Player, spot: CFrame, anchored: boolean)
			local character, root, humanoid = bodyOfAlive(player)
			if character and root and humanoid then
				root.Anchored = anchored
				local height = if humanoid.RigType == Enum.HumanoidRigType.R6 then 3 else humanoid.HipHeight + root.Size.Y / 2
				character:PivotTo(spot * CFrame.new(0, height, 0))
			end
		end,
		release = function(player: Player)
			local _, root = bodyOfAlive(player)
			if root then
				root.Anchored = false
			end
		end,
		notify = function(player: Player, message: string)
			LocalMeetService.notify(player, message)
		end,
		prompt = function(parent: BasePart, action: string, object: string, onTriggered: (Player) -> ()): ProximityPrompt
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
			return p
		end,
		pressAllowed = function(player: Player): boolean
			local time = os.clock()
			if time - (lastPress[player] or 0) < LocalMeetConfig.ButtonCooldownSeconds then
				return false
			end
			lastPress[player] = time
			return true
		end,
	})
	-- The running minigame's progress moves the character's lift. Visual only; each warm-up answers only its own players.
	set.liftProgress.OnServerEvent:Connect(function(player: Player, fraction: unknown)
		local current = warmUp
		if current and typeof(fraction) == "number" and fraction == fraction then
			current.progress(player, math.clamp(fraction, 0, 1))
		end
	end)

	print(string.format("[NationalsArenaVenue] built: the building at %s, the hall at %s, %d platforms, %d warm-up racks",
		tostring(NationalsConfig.BuildingOrigin), tostring(NationalsConfig.HallOrigin), #stages, #hallWarmUpRacks))
	return venue
end

-- The venue once built (nil before, or when its models did not load).
function NationalsArenaVenue.current(): Venue?
	return venue
end

local bodyOf = bodyOfAlive

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
		-- A visitor of the meet system's Nationals hall: its sounds, standings, awards and the meet screen.
		LocalMeetService.visitNationals(player)
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
					stopWarmUp(player)
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
	stopWarmUp(player)
	-- Out of the meet system's Nationals hall first (a lifter in the meet withdraws).
	LocalMeetService.leaveNationalsVisit(player)
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
	stopWarmUp(player)
	lastPress[player] = nil
end)

return NationalsArenaVenue
