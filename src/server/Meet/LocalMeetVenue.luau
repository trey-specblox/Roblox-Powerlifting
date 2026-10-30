--!strict
--[[
	LocalMeetVenue
	Server / Meet

	The Local meet's venue (GAME_DESIGN.md §29.10 "The Local meet", step 3, and
	"Venue redesign and awards ceremony", user 2026-10-29), built once when the
	server starts, far from the gym (LocalMeetConfig.Origin), and its ENTRANCE
	BUILDING outside the gym (MeetHall), whose doors take a player in. Every
	prop is a Blender model: LocalMeet_01 (light boxes, seating, podium, plate
	trees, entrance building), LocalMeet_02 (barricades, referee chairs,
	platform signs, the awards backdrop), MockMeet_01 (platform, boards, banner,
	desk), the gym's competition rack, sofas, planters, water cooler, light
	fittings and steel beams. The shell is plain dark walls under one PITCHED
	ceiling on steel rafters (user: no flat roofs), the ridge running front to
	back.

	The building, in its own frame (X across, Z deep from the doors at -Z to
	the far end at +Z, Y up; 0,0,0 = the floor under the hall's middle):
		LOBBY      by the doors: where a player arrives, the SIGN-UP desk right
		           at the doors, the exit; a wide opening into the meet hall and,
		           on the right, the corridor to the warm-up room
		MEET HALL  the stands against the walls (raised, low step toward the
		           middle), an open standing floor for spectators, a row of
		           metal barricades, then the 8 platforms in a row along the back
		           wall: each with a number sign on a post, three referee chairs
		           in front (head referee in the middle, furthest forward), the
		           referees' light box at its front right corner, its big
		           screen on the back wall (LifterDisplay: who is lifting
		           there) and a stage light above
		WARM-UP    behind the hall's back wall, with a doorway beside every
		           platform: 8 working racks (LocalMeetWarmUp: practice lifts), plate
		           trees, and a hangout corner with sofas
		CORRIDOR   along the hall's right side, lobby to warm-up room

	Anyone can walk in and watch. While a meet runs, each used platform gets
	three referees seated on its chairs and the lifter's coach (MeetFigures);
	the lamps light white or red after each lift (setLights). After the meet,
	showAwards(true) takes away every platform's rack, chairs and light box and
	puts up the AWARDS STAGE in their place: the 1-2-3 podium in front of the
	LOCAL CENTRAL MEET backdrop. It only builds and draws; the meet is
	LocalMeetService's job.

	PERFORMANCE: about 30 barricades share one mesh; the stands, chairs and
	signs repeat a few meshes. Lights: 8 stage lights and about 23 ceiling
	panels, as many as the old hall.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local StarterGymConfig = require(ConfigFolder:WaitForChild("StarterGymConfig"))

local ServerFolder = script.Parent.Parent
local WorldFolder = ServerFolder:WaitForChild("World")
local BuildParts = require(WorldFolder:WaitForChild("BuildParts"))
local RoomProps = require(WorldFolder:WaitForChild("RoomProps"))
local StyledScreen = require(WorldFolder:WaitForChild("StyledScreen"))
local MockMeetArena = require(script.Parent:WaitForChild("MockMeetArena"))
local MeetFigures = require(script.Parent:WaitForChild("MeetFigures"))
local LifterDisplay = require(script.Parent:WaitForChild("LifterDisplay"))

local LocalMeetVenue = {}

local MODEL_NAME = "LocalMeetVenue"
local ENTRANCE_NAME = "LocalMeetEntrance"
local WALL = 1
-- The pitched ceiling: the side walls are EAVE high, the ridge (front to back, over the building's middle) RIDGE.
local EAVE = 30
local RIDGE = 46
-- Where the walls stand (inner faces), front to back: the doors, lobby | hall, hall | warm-up, the far end.
local Z_FRONT = -96
local Z_LOBBY = -70
local Z_BACK = 40
local Z_END = 80
local CORRIDOR_W = 12
local OPENING_H = 12 -- the doorway height of the openings in the inner walls
local HALL_OPENING = 12 -- half the width of the opening from the lobby into the hall
local DOORWAY = 3 -- half the width of the doorways from the warm-up room to the platforms
-- The platforms.
local PLATFORM_SIZE = 16
local PLATFORM_HEIGHT = 0.6
local PLATFORM_Z = 26 -- the platforms' middles
local PLATFORM_FRONT = PLATFORM_Z - PLATFORM_SIZE / 2
local LIFT_SPOT_IN_FRONT = 4
local BOARD_SCALE = 0.5 -- small wall boards: MockMeet_01's attempt board at half size (14 x 6)
-- The platforms' big screens (user 2026-10-29: "make the TVs bigger and more visible"): the board at 0.8 (about
-- 22 x 9.6, nearly the platform spacing), its middle this high, clear of the doorways under it.
local DISPLAY_SCALE = 0.8
local DISPLAY_Y = 18.5
-- The barricade row between the spectators and the platforms (LocalMeet_02's Barricade is 7 wide).
local BARRIER_Z = 6
local BARRICADE_W = 7
local BARRICADE_H = 3.3
-- The referee chairs: side referees either side of the platform's front, the head referee in the middle in front.
local REF_SEATS = { Vector2.new(-6, PLATFORM_FRONT - 2.5), Vector2.new(0, PLATFORM_FRONT - 5), Vector2.new(6, PLATFORM_FRONT - 2.5) }
local CHAIR_SEAT_TOP = 1.84
-- The stands (LocalMeet_01's Bleachers: 24 wide, 12 deep, four steps of 1.5).
local SEAT_W, SEAT_D, SEAT_STEP_H, SEAT_STEPS = 24, 12, 1.5, 4
-- The warm-up room's racks, in a row along its far wall, facing the hall.
local WARMUP_RACK_Z = 66
-- The entrance building outside the gym: its front wall level with the gym's front (z = -37), beside the gym's
-- right side (the gym spans x -126..126), facing the same way as the gym's entrance.
local ENTRANCE_FRONT_Z = -37
local ENTRANCE_X = 162

local looks = StarterGymConfig.Looks
local LAMP_OFF = Color3.fromRGB(46, 48, 54)
local LAMP_WHITE = Color3.fromRGB(255, 252, 245)
local LAMP_RED = Color3.fromRGB(230, 36, 40)
local SIGN_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

export type Platform = {
	index: number,
	-- Where the lifter stands for a lift: on the platform in front of the rack, facing the spectators.
	liftSpot: CFrame,
	-- Where the lifter waits at the weigh-in: on the floor beside the platform, facing the spectators.
	waitSpot: CFrame,
	-- The big screen over the platform: who is lifting there.
	display: LifterDisplay.Handle,
	-- The referee light box's three lamps (empty when the model did not load).
	lamps: { BasePart },
	-- The three referee chairs: a point on each seat under the referee's hips, facing the platform.
	refSeats: { CFrame },
	-- Where the coach stands (on the floor at the platform's front left corner).
	coachSpot: Vector3,
	-- The rack, chairs and light box: taken away while the awards stage stands.
	gear: Folder,
	-- The referees and coach while a meet runs (cleared after it).
	staff: Folder,
	coachLine: TextLabel?,
}

export type Venue = {
	model: Model,
	-- Where a player arrives from the gym: just inside the doors, facing the hall.
	arrival: CFrame,
	-- Where a lifter goes after the meet: the spectators' floor, facing the platforms.
	lobbySpot: CFrame,
	platforms: { Platform },
	-- The invisible points carrying the sign-up and exit prompts.
	signUpPoint: BasePart,
	exitPoint: BasePart,
	scoreboard: StyledScreen.Handle?,
	-- The awards stage (podium and backdrop); in the venue only while showAwards is on.
	awards: Model,
	-- Where 1st, 2nd and 3rd stand on the podium (empty when the model did not load).
	podiumSpots: { CFrame },
	-- The warm-up room's working racks.
	warmUpRacks: { WarmUpRack },
}

-- A warm-up rack: where its lifter stands (in front of it, facing the hall) and the point carrying its prompt.
export type WarmUpRack = {
	index: number,
	liftSpot: CFrame,
	point: BasePart,
}

local venue: Venue? = nil

local function platformX(index: number): number
	return (index - (LocalMeetConfig.MaxLifters + 1) / 2) * LocalMeetConfig.PlatformSpacingStuds
end

-- The hall's half width (its left wall at -hx, its right wall at hx; the corridor beyond that).
local function halfWidth(): number
	return LocalMeetConfig.MaxLifters * LocalMeetConfig.PlatformSpacingStuds / 2 + 8
end

-- Big heavy italic writing on a sign's screen in the game's style: `title` in white, `sub` (if any) in yellow
-- under it, on deep navy.
local function writeSign(part: BasePart, out: Vector3, title: string, sub: string?, pixelsPerStud: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = StyledScreen.faceToward(part, out)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.Parent = part
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = StyledScreen.Colours.navyDeep
	back.Parent = gui
	local function label(name: string, text: string, y: number, height: number, colour: Color3)
		local item = Instance.new("TextLabel")
		item.Name = name
		item.BackgroundTransparency = 1
		item.Position = UDim2.fromScale(0.05, y)
		item.Size = UDim2.fromScale(0.9, height)
		item.Text = text
		item.TextColor3 = colour
		item.TextScaled = true
		item.FontFace = SIGN_FONT
		item.Parent = back
	end
	if sub then
		label("Title", title, 0.06, 0.62, StyledScreen.Colours.white)
		label("Sub", sub, 0.72, 0.2, StyledScreen.Colours.yellow)
	else
		label("Title", title, 0.12, 0.76, StyledScreen.Colours.white)
	end
end

-- Builds the venue once and returns it (later calls return the same one), or nil and the reason.
function LocalMeetVenue.build(): (Venue?, string?)
	if venue then
		return venue, nil
	end
	local centre = LocalMeetConfig.Origin
	local hx = halfWidth()
	local xLeft, xRight = -hx, hx + CORRIDOR_W
	local cx = (xLeft + xRight) / 2 -- under the ridge
	local span = (xRight - xLeft) / 2 + WALL -- from the ridge to a side wall's outer face
	local rise = RIDGE - EAVE

	local model = Instance.new("Model")
	model.Name = MODEL_NAME

	local function box(parent: Instance, name: string, low: Vector3, high: Vector3, look: StarterGymConfig.Look): BasePart
		return BuildParts.box(parent, name, centre + low, centre + high, look)
	end
	local function decor(name: string, low: Vector3, high: Vector3, look: StarterGymConfig.Look): BasePart
		return BuildParts.decor(box(model, name, low, high, look))
	end
	-- A solid box nobody sees: it stops players walking through a 3D prop (props are decor).
	local function hide(part: BasePart): BasePart
		part.Transparency = 1
		part.CastShadow = false
		return part
	end
	local function solid(name: string, low: Vector3, high: Vector3, parent: Instance?): BasePart
		return hide(box(parent or model, name, low, high, looks.Glass))
	end
	local function solidAt(name: string, size: Vector3, at: CFrame, parent: Instance?): BasePart
		return hide(BuildParts.placed(parent or model, name, size, at, looks.Glass))
	end
	-- A frame at a point of the building (local), facing `toward` (a direction in the building's frame).
	local function facing(at: Vector3, toward: Vector3): CFrame
		local world = centre + at
		return CFrame.lookAt(world, world + toward)
	end
	local function prop(parent: Instance, name: string, item: string, at: CFrame?, colourway: number?): Model?
		local copy = RoomProps.propCopy(item, colourway or 1)
		if copy then
			copy.Name = name
			if at then
				copy:PivotTo(at)
			end
			copy.Parent = parent
		end
		return copy
	end
	-- An invisible, non-solid point that carries a prompt, at a point of the building (local, like box()).
	local function point(name: string, at: Vector3): BasePart
		local part = box(model, name, at - Vector3.new(1, 0, 1), at + Vector3.new(1, 4, 1), looks.Glass)
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		return part
	end
	local function shine(part: BasePart, range: number, brightness: number, angle: number)
		BuildParts.surfaceLight(part, StyledScreen.faceToward(part, -Vector3.yAxis), range, brightness, angle)
	end
	-- The ceiling's height above the floor at x (the ridge over the middle, the eaves at the side walls).
	local function ceilingAt(x: number): number
		return RIDGE - math.abs(x - cx) / (span - WALL) * rise
	end
	-- MockMeet_01's board (or banner) hung on a wall at `scale`; returns its screen (a dark panel if the model is
	-- missing).
	local function hangBoard(name: string, item: string, piece: string, scale: number, wallPoint: Vector3, out: Vector3,
		screenAt: Vector3): BasePart
		local frame = prop(model, name, item)
		local screen = frame and frame:FindFirstChild(piece, true) :: BasePart?
		local part: BasePart
		if frame and screen then
			if scale ~= 1 then
				frame:ScaleTo(scale)
			end
			MockMeetArena.hangOnWall(frame, screen, centre + wallPoint, out, centre + screenAt)
			part = screen
		else
			if frame then
				frame:Destroy()
			end
			local across = out:Cross(Vector3.yAxis).Unit
			local size = across * 7 + Vector3.yAxis * 3
			local low, high = screenAt - size, screenAt + size
			part = decor(name, Vector3.new(math.min(low.X, high.X), low.Y, math.min(low.Z, high.Z)) + out * 0.06,
				Vector3.new(math.max(low.X, high.X), high.Y, math.max(low.Z, high.Z)) + out * 0.4, looks.Gadget)
		end
		return part
	end
	-- A hung board with writing in the game's style.
	local function wallBoard(name: string, item: string, piece: string, scale: number, wallPoint: Vector3, out: Vector3,
		screenAt: Vector3, title: string, lines: { string }, mark: string, pixelsPerStud: number): StyledScreen.Handle?
		local part = hangBoard(name, item, piece, scale, wallPoint, out, screenAt)
		return StyledScreen.build(part, StyledScreen.faceToward(part, out), title, lines, mark, pixelsPerStud)
	end

	-- ---------------------------------------------------------------- the shell
	box(model, "Floor", Vector3.new(xLeft - WALL, -WALL, Z_FRONT - WALL), Vector3.new(xRight + WALL, 0, Z_END + WALL),
		looks.MaxBlack)
	box(model, "Wall_Left", Vector3.new(xLeft - WALL, 0, Z_FRONT), Vector3.new(xLeft, EAVE, Z_END), looks.MaxBlack)
	box(model, "Wall_Right", Vector3.new(xRight, 0, Z_FRONT), Vector3.new(xRight + WALL, EAVE, Z_END), looks.MaxBlack)
	-- The hall's right wall, between it and the corridor, up into the sloping ceiling.
	box(model, "Wall_Corridor", Vector3.new(hx, 0, Z_LOBBY), Vector3.new(hx + WALL, ceilingAt(hx) + WALL, Z_BACK), looks.MaxBlack)

	-- A cross wall (inner face at z, `out` = the side its inner face looks at) with openings { x0, x1 } of
	-- OPENING_H, and its gable: two wedges from the eaves up to the ridge.
	local function crossWall(name: string, z: number, out: number, openings: { { number } })
		local z0, z1 = if out > 0 then z - WALL else z, if out > 0 then z else z + WALL
		local x = xLeft - WALL
		for index, gap in ipairs(openings) do
			box(model, string.format("%s_%d", name, index), Vector3.new(x, 0, z0), Vector3.new(gap[1], EAVE, z1), looks.MaxBlack)
			box(model, string.format("%s_Over%d", name, index), Vector3.new(gap[1], OPENING_H, z0), Vector3.new(gap[2], EAVE, z1),
				looks.MaxBlack)
			x = gap[2]
		end
		box(model, name .. "_End", Vector3.new(x, 0, z0), Vector3.new(xRight + WALL, EAVE, z1), looks.MaxBlack)
		for _, side in ipairs({ -1, 1 }) do
			-- A WedgePart rises toward its +Z; turned a quarter so it rises toward the ridge.
			local wedge = BuildParts.placed(model, string.format("%s_Gable%d", name, side), Vector3.new(WALL, rise, span),
				CFrame.new(centre + Vector3.new(cx + side * span / 2, EAVE + rise / 2, (z0 + z1) / 2))
					* CFrame.Angles(0, -side * math.pi / 2, 0), looks.MaxBlack, "WedgePart")
			wedge.CastShadow = false
		end
	end
	crossWall("Wall_Front", Z_FRONT, 1, {})
	crossWall("Wall_Lobby", Z_LOBBY, 1, { { -HALL_OPENING, HALL_OPENING }, { hx + WALL, xRight } })
	local doorways: { { number } } = {}
	for index = 1, LocalMeetConfig.MaxLifters - 1 do
		local x = (platformX(index) + platformX(index + 1)) / 2
		table.insert(doorways, { x - DOORWAY, x + DOORWAY })
	end
	table.insert(doorways, { hx + WALL, xRight })
	crossWall("Wall_Back", Z_BACK, -1, doorways)
	crossWall("Wall_End", Z_END, -1, {})

	-- The pitched ceiling: two slabs from the side walls up to the ridge.
	local length = math.sqrt(span * span + rise * rise)
	local tilt = math.atan2(rise, span)
	for _, side in ipairs({ -1, 1 }) do
		BuildParts.placed(model, "Ceiling_" .. (if side < 0 then "Left" else "Right"),
			Vector3.new(length + 2, WALL, Z_END - Z_FRONT + 2 * WALL + 2),
			CFrame.new(centre + Vector3.new(cx + side * span / 2, EAVE + rise / 2 + WALL / 2, (Z_FRONT + Z_END) / 2))
				* CFrame.Angles(0, 0, -side * tilt), looks.MaxBlack)
	end
	-- The gym's red competition stripe round the outer walls, and a carpet.
	decor("Stripe_Front", Vector3.new(xLeft, 2.9, Z_FRONT), Vector3.new(xRight, 3.5, Z_FRONT + 0.06), looks.PlateRed)
	decor("Stripe_End", Vector3.new(xLeft, 2.9, Z_END - 0.06), Vector3.new(xRight, 3.5, Z_END), looks.PlateRed)
	decor("Stripe_Left", Vector3.new(xLeft, 2.9, Z_FRONT), Vector3.new(xLeft + 0.06, 3.5, Z_END), looks.PlateRed)
	decor("Stripe_Right", Vector3.new(xRight - 0.06, 2.9, Z_FRONT), Vector3.new(xRight, 3.5, Z_END), looks.PlateRed)
	decor("Carpet", Vector3.new(xLeft, 0, Z_FRONT), Vector3.new(xRight, 0.04, Z_END), looks.FrontCharcoal)

	-- Steel rafters under the ceiling, the gym's I-beam stretched (Steel_01), and a ridge beam front to back.
	local function beam(name: string, from: Vector3, to: Vector3, size: number)
		local copy = RoomProps.propCopy("SteelBeam", 1, Vector3.new(size, size, (to - from).Magnitude))
		if copy then
			copy.Name = name
			local mid = centre + (from + to) / 2
			copy:PivotTo(CFrame.lookAt(mid, mid + (to - from)) * CFrame.new(0, -size / 2, 0))
			copy.Parent = model
		end
	end
	for z = Z_FRONT + 10, Z_END - 10, 24 do
		for _, x in ipairs({ xLeft, xRight }) do
			beam(string.format("Rafter_%d_%d", x, z), Vector3.new(x, EAVE - 1.2, z), Vector3.new(cx, RIDGE - 1.2, z), 1.4)
		end
	end
	beam("RidgeBeam", Vector3.new(cx, RIDGE - 1.4, Z_FRONT), Vector3.new(cx, RIDGE - 1.4, Z_END), 1.6)

	-- ---------------------------------------------------------------- the platforms
	local half = PLATFORM_SIZE / 2
	local platforms: { Platform } = {}
	for index = 1, LocalMeetConfig.MaxLifters do
		local x = platformX(index)
		if not prop(model, "Platform_" .. index, "MeetPlatform", CFrame.new(centre + Vector3.new(x, 0, PLATFORM_Z))) then
			box(model, "Platform_" .. index .. "_Top", Vector3.new(x - half, 0, PLATFORM_Z - half),
				Vector3.new(x + half, PLATFORM_HEIGHT, PLATFORM_Z + half), looks.Wood)
		end
		solid("Platform_" .. index .. "_Solid", Vector3.new(x - half - 0.3, 0, PLATFORM_Z - half - 0.3),
			Vector3.new(x + half + 0.3, PLATFORM_HEIGHT, PLATFORM_Z + half + 0.3))

		-- The gear the awards stage replaces: the rack, the referee chairs and the light box.
		local gear = Instance.new("Folder")
		gear.Name = "Gear_" .. index
		gear.Parent = model
		local placed, problem = MockMeetArena.placeRack(gear, centre + Vector3.new(x, PLATFORM_HEIGHT, PLATFORM_Z))
		if not placed then
			model:Destroy()
			return nil, problem
		end

		-- The platform's big screen on the back wall above it (MockMeet_01's attempt board, scaled up): the lifter
		-- on the platform, their numbers and fun facts (LifterDisplay).
		local screen = hangBoard("PlatformBoard_" .. index, "MeetBoard", "MeetBoard_Screen", DISPLAY_SCALE,
			Vector3.new(0, 0, Z_BACK - 0.06), -Vector3.zAxis, Vector3.new(x, DISPLAY_Y, Z_BACK))
		local display = LifterDisplay.build(screen, -Vector3.zAxis, index, MeetConfig.LiftOrder)

		-- The number sign on its post at the platform's back left corner, facing the spectators.
		local sign = prop(model, "PlatformSign_" .. index, "PlatformSign",
			facing(Vector3.new(x - half - 2.5, 0, PLATFORM_Z + 4), -Vector3.zAxis))
		local signScreen = sign and sign:FindFirstChild("PlatformSign_Screen", true) :: BasePart?
		if signScreen then
			writeSign(signScreen, -Vector3.zAxis, "PLATFORM " .. index, nil, 40)
		end

		-- The referees' light box at the platform's front right corner, facing the spectators.
		local lamps: { BasePart } = {}
		local lights = prop(gear, "RefLights_" .. index, "RefLights",
			facing(Vector3.new(x + half + 2.5, 0, PLATFORM_FRONT + 1), -Vector3.zAxis))
		if lights then
			for lamp = 1, 3 do
				local part = lights:FindFirstChild("RefLights_Lamp" .. lamp, true)
				if part and part:IsA("BasePart") then
					table.insert(lamps, part)
				end
			end
		end

		-- The three referee chairs, facing the platform; a seated referee's hips sit a little behind the seat's middle.
		local refSeats: { CFrame } = {}
		for seat, spot in ipairs(REF_SEATS) do
			prop(gear, string.format("RefChair_%d_%d", index, seat), "RefChair",
				facing(Vector3.new(x + spot.X, 0, spot.Y), Vector3.zAxis))
			local hips = centre + Vector3.new(x + spot.X, CHAIR_SEAT_TOP, spot.Y - 0.45)
			table.insert(refSeats, CFrame.lookAt(hips, hips + Vector3.zAxis))
		end

		-- One stage light over each platform, hung from the ceiling.
		local lightY = ceilingAt(x) - 2
		local lightAt = centre + Vector3.new(x, lightY - 0.425, PLATFORM_Z - 0.43)
		local can = RoomProps.fitting(model, "StageLight_" .. index, "StageLight", "Lens",
			CFrame.lookAt(lightAt, lightAt - Vector3.yAxis, Vector3.zAxis))
			or decor("StageLight_" .. index, Vector3.new(x - 1, lightY - 1, PLATFORM_Z - 1), Vector3.new(x + 1, lightY,
				PLATFORM_Z + 1), looks.GlowWhite)
		shine(can, 50, 2.6, 60)

		local staff = Instance.new("Folder")
		staff.Name = "Staff_" .. index
		staff.Parent = model
		local liftAt = centre + Vector3.new(x, PLATFORM_HEIGHT, PLATFORM_Z - LIFT_SPOT_IN_FRONT)
		local waitAt = centre + Vector3.new(x - half - 2, 0, PLATFORM_Z)
		table.insert(platforms, {
			index = index,
			liftSpot = CFrame.lookAt(liftAt, liftAt - Vector3.zAxis),
			waitSpot = CFrame.lookAt(waitAt, waitAt - Vector3.zAxis),
			display = display,
			lamps = lamps,
			refSeats = refSeats,
			coachSpot = centre + Vector3.new(x - half - 1.5, 0, PLATFORM_FRONT - 1),
			gear = gear,
			staff = staff,
			coachLine = nil,
		})
	end

	-- The barricades across the hall, banners toward the spectators, on one hidden solid wall.
	local count = math.floor(2 * hx / BARRICADE_W)
	local firstX = -(count - 1) * BARRICADE_W / 2
	for k = 0, count - 1 do
		prop(model, "Barricade_" .. (k + 1), "Barricade", facing(Vector3.new(firstX + k * BARRICADE_W, 0, BARRIER_Z), -Vector3.zAxis))
	end
	solid("Barricades_Solid", Vector3.new(-hx, 0, BARRIER_Z - 0.4), Vector3.new(hx, BARRICADE_H, BARRIER_Z + 0.4))

	-- ---------------------------------------------------------------- the stands, against the walls
	-- One section of stands, its low front step toward `toward`, on hidden solid steps.
	local stands = 0
	local function standsAt(at: Vector3, toward: Vector3)
		stands += 1
		local frame = facing(at, toward)
		prop(model, "Stands_" .. stands, "Bleachers", frame)
		local depth = SEAT_D / SEAT_STEPS
		for step = 0, SEAT_STEPS - 1 do
			local height = (step + 1) * SEAT_STEP_H
			solidAt(string.format("Stands_%d_Step%d", stands, step), Vector3.new(SEAT_W, height, SEAT_D - step * depth),
				frame * CFrame.new(0, height / 2, step * depth / 2))
		end
	end
	-- Along the lobby wall either side of the opening, facing the platforms.
	for _, x in ipairs({ -84, -60, -36, 36, 60, 84 }) do
		standsAt(Vector3.new(x, 0, Z_LOBBY + SEAT_D / 2), Vector3.zAxis)
	end
	-- Along both side walls, facing the middle.
	for _, z in ipairs({ -40, -14 }) do
		standsAt(Vector3.new(-hx + SEAT_D / 2, 0, z), Vector3.xAxis)
		standsAt(Vector3.new(hx - SEAT_D / 2, 0, z), -Vector3.xAxis)
	end

	-- The scoreboard on the left wall over the stands, facing the hall, and the venue's banner on the right wall.
	local scoreboard = wallBoard("Scoreboard", "MeetBoard", "MeetBoard_Screen", 1, Vector3.new(-hx + 0.06, 0, 0),
		Vector3.xAxis, Vector3.new(-hx, 18, -27), "LOCAL MEET", { "Sign up at the desk", "A meet every 10 minutes" }, "star", 30)
	wallBoard("Banner", "MeetBanner", "MeetBanner_Cloth", 1, Vector3.new(hx, 0, 0), -Vector3.xAxis, Vector3.new(hx, 16, -27),
		"LOCAL MEET", { "Everyone lifts together", "Best score wins" }, "dots", 30)

	-- ---------------------------------------------------------------- the lobby
	-- The sign-up desk right by the doors, facing whoever walks in: MockMeet_01's desk with its monitor.
	local deskX, deskZ = -16, Z_FRONT + 12
	local desk = prop(model, "SignUpDesk", "MeetDesk", facing(Vector3.new(deskX, 0, deskZ), -Vector3.zAxis))
	if desk then
		solid("SignUpDesk_Solid", Vector3.new(deskX - 5.25, 0, deskZ - 1.15), Vector3.new(deskX + 5.25, 3.3, deskZ + 1.15))
		local monitor = desk:FindFirstChild("MeetDesk_MonitorScreen", true) :: BasePart?
		if monitor then
			StyledScreen.build(monitor, StyledScreen.faceToward(monitor, Vector3.zAxis), "SIGN-UP",
				{ "Local meet desk", "Every 10 minutes" }, "bar", 120)
		end
	else
		box(model, "SignUpDesk", Vector3.new(deskX - 5, 0, deskZ - 1), Vector3.new(deskX + 5, 3.2, deskZ + 1), looks.FrontCharcoal)
	end
	local signUpPoint = point("SignUpPoint", Vector3.new(deskX, 0, deskZ - 4))
	wallBoard("SignUpBoard", "MeetBoard", "MeetBoard_Screen", BOARD_SCALE, Vector3.new(xLeft + 0.06, 0, 0), Vector3.xAxis,
		Vector3.new(xLeft, 9, deskZ - 2), "SIGN UP HERE", { "The desk by the doors", "Then wait in the hall" }, "bar", 30)

	-- The way out: a dark doorway in the front wall with a board over it, and the exit prompt in front of it.
	decor("ExitDoorway", Vector3.new(-5, 0, Z_FRONT), Vector3.new(5, 10, Z_FRONT + 0.08), looks.FrontCharcoal)
	wallBoard("ExitBoard", "MeetBoard", "MeetBoard_Screen", 0.35, Vector3.new(0, 0, Z_FRONT + 0.06), Vector3.zAxis,
		Vector3.new(0, 13, Z_FRONT), "EXIT", { "Back to the gym" }, "bar", 30)
	local exitPoint = point("ExitPoint", Vector3.new(0, 0, Z_FRONT + 2))
	-- Boards over the openings: into the hall, and down the corridor to the warm-up room.
	wallBoard("HallBoard", "MeetBoard", "MeetBoard_Screen", 0.35, Vector3.new(0, 0, Z_LOBBY - WALL - 0.06), -Vector3.zAxis,
		Vector3.new(0, 16, Z_LOBBY - WALL), "MEET HALL", { "Come in and watch" }, "star", 30)
	wallBoard("WarmUpBoard", "MeetBoard", "MeetBoard_Screen", 0.35, Vector3.new(0, 0, Z_LOBBY - WALL - 0.06), -Vector3.zAxis,
		Vector3.new(hx + CORRIDOR_W / 2, 16, Z_LOBBY - WALL), "WARM-UP ROOM", { "Down the corridor" }, "bar", 30)

	-- ---------------------------------------------------------------- the warm-up room
	-- A rack opposite every platform's doorway row, along the far wall, with a plate tree between each pair. Each
	-- working rack (LocalMeetWarmUp) has a spot in front of it facing the hall, like a platform's, and a point
	-- there for its prompt.
	local warmUpRacks: { WarmUpRack } = {}
	for index = 1, LocalMeetConfig.MaxLifters do
		local x = platformX(index)
		local placed = MockMeetArena.placeRack(model, centre + Vector3.new(x, 0, WARMUP_RACK_Z))
		if placed then
			local spotAt = centre + Vector3.new(x, 0, WARMUP_RACK_Z - LocalMeetConfig.WarmUp.LiftSpotInFrontStuds)
			table.insert(warmUpRacks, {
				index = #warmUpRacks + 1,
				liftSpot = CFrame.lookAt(spotAt, spotAt - Vector3.zAxis),
				point = point("WarmUpPoint_" .. index, spotAt - centre),
			})
		else
			warn("[LocalMeetVenue] warm-up rack " .. index .. " could not be built")
		end
		if index % 2 == 0 then
			local treeX = x - LocalMeetConfig.PlatformSpacingStuds / 2
			prop(model, "PlateTree_" .. index // 2, "PlateTree", facing(Vector3.new(treeX, 0, WARMUP_RACK_Z + 4), -Vector3.zAxis))
			solid("PlateTree_" .. index // 2 .. "_Solid", Vector3.new(treeX - 1.2, 0, WARMUP_RACK_Z + 2.8),
				Vector3.new(treeX + 1.2, 5, WARMUP_RACK_Z + 5.2))
		end
	end
	-- The hangout corner where the corridor comes in: two sofas facing each other, a water cooler, plants.
	local loungeX = hx + CORRIDOR_W / 2 - 4
	for k, spot in ipairs({ { z = 54, toward = Vector3.zAxis }, { z = 66, toward = -Vector3.zAxis } }) do
		prop(model, "Sofa_" .. k, "Sofa", facing(Vector3.new(loungeX, 0, spot.z), spot.toward), k)
		solid("Sofa_" .. k .. "_Solid", Vector3.new(loungeX - 3, 0, spot.z - 1.3), Vector3.new(loungeX + 3, 1.86, spot.z + 1.3))
	end
	prop(model, "WaterCooler", "WaterCooler", facing(Vector3.new(xRight - 1.2, 0, 60), -Vector3.xAxis))
	solid("WaterCooler_Solid", Vector3.new(xRight - 2.2, 0, 59), Vector3.new(xRight, 4, 61))
	for k, spot in ipairs({ Vector3.new(xRight - 2, 0, 46), Vector3.new(xRight - 2, 0, Z_END - 2), Vector3.new(hx - 6, 0, Z_END - 2) }) do
		prop(model, "Planter_" .. k, "Planter", CFrame.new(centre + spot), k)
	end
	wallBoard("WarmUpBanner", "MeetBanner", "MeetBanner_Cloth", 1, Vector3.new(0, 0, Z_END), -Vector3.zAxis,
		Vector3.new(0, 16, Z_END), "WARM-UP ROOM", { "Practise your lifts: hold E at a rack", "Nothing is saved here" }, "dots", 30)

	-- ---------------------------------------------------------------- the lights
	-- Ceiling panels: dim over the spectators and the lobby (the platforms carry the bright light), brighter in
	-- the warm-up room and the corridor.
	local function panels(zs: { number }, xs: { number }, brightness: number)
		for _, z in ipairs(zs) do
			for _, x in ipairs(xs) do
				local y = ceilingAt(x) - 0.12
				local name = string.format("CeilingLight_%d_%d", x, z)
				local panel = RoomProps.fitting(model, name, "CeilingPanel", "Diffuser", CFrame.new(centre + Vector3.new(x, y, z)),
					Vector3.new(6, 0.12, 6)) or decor(name, Vector3.new(x - 3, y - 0.2, z - 3), Vector3.new(x + 3, y, z + 3), looks.GlowWhite)
				shine(panel, 50, brightness, 110)
			end
		end
	end
	panels({ -50, -20 }, { -84, -42, 0, 42, 84 }, 1.4)
	panels({ (Z_FRONT + Z_LOBBY) / 2 }, { -80, -40, 0, 40, 80 }, 2.4)
	panels({ 50, 70 }, { -78, -26, 26, 78 }, 3)
	panels({ -40, 10 }, { hx + CORRIDOR_W / 2 }, 1.6)

	-- ---------------------------------------------------------------- the awards stage (kept out until the end)
	-- The 1-2-3 podium in front of platforms 4 and 5, the LOCAL CENTRAL MEET backdrop behind it standing on their
	-- front edges.
	local awards = Instance.new("Model")
	awards.Name = "AwardsStage"
	local backdrop = prop(awards, "AwardsBackdrop", "AwardsBackdrop",
		facing(Vector3.new(0, PLATFORM_HEIGHT, PLATFORM_FRONT + 2), -Vector3.zAxis))
	if backdrop then
		local title = backdrop:FindFirstChild("AwardsBackdrop_Title", true) :: BasePart?
		if title then
			writeSign(title, -Vector3.zAxis, "LOCAL CENTRAL MEET", "AWARDS", 30)
		end
		local lenses = backdrop:FindFirstChild("AwardsBackdrop_Lenses", true) :: BasePart?
		if lenses then
			shine(lenses, 24, 2, 80)
		end
	end
	local podiumSpots: { CFrame } = {}
	local podium = prop(awards, "AwardPodium", "AwardPodium", facing(Vector3.new(0, 0, PLATFORM_FRONT - 3.5), -Vector3.zAxis))
	if podium then
		for _, top in ipairs({ "AwardPodium_Gold", "AwardPodium_Silver", "AwardPodium_Bronze" }) do
			local part = podium:FindFirstChild(top, true)
			if part and part:IsA("BasePart") then
				local surface = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
				solid(top .. "_Solid", surface - centre - Vector3.new(2.5, surface.Y - centre.Y, 2.5),
					surface - centre + Vector3.new(2.5, 0, 2.5), awards)
				table.insert(podiumSpots, CFrame.lookAt(surface, surface - Vector3.zAxis))
			end
		end
	end

	model.PrimaryPart = model:FindFirstChild("Floor") :: BasePart
	model.Parent = Workspace

	local arrivalAt = centre + Vector3.new(6, 0, Z_FRONT + 6)
	local lobbyAt = centre + Vector3.new(0, 0, -12)
	venue = {
		model = model,
		arrival = CFrame.lookAt(arrivalAt, arrivalAt + Vector3.zAxis),
		lobbySpot = CFrame.lookAt(lobbyAt, lobbyAt + Vector3.zAxis),
		platforms = platforms,
		signUpPoint = signUpPoint,
		exitPoint = exitPoint,
		scoreboard = scoreboard,
		awards = awards,
		podiumSpots = podiumSpots,
		warmUpRacks = warmUpRacks,
	}
	return venue, nil
end

--[[
	Builds the venue's ENTRANCE BUILDING outside the gym (LocalMeet_01's MeetHall: a
	pitched gable roof and an entrance porch), on hidden solid blocks, with its sign,
	and returns the invisible point in front of its doors (tagged
	LocalMeetConfig.EntranceTag), or nil when the model did not load. Its front
	wall lines up with the gym's front.
]]
function LocalMeetVenue.buildEntrance(): BasePart?
	local existing = Workspace:FindFirstChild(ENTRANCE_NAME)
	if existing then
		return existing:FindFirstChild("DoorPoint") :: BasePart?
	end
	local hall = RoomProps.propCopy("MeetHall", 1)
	if hall == nil then
		warn("[LocalMeetVenue] the entrance building's model did not load")
		return nil
	end
	local model = Instance.new("Model")
	model.Name = ENTRANCE_NAME
	hall.Name = "MeetHall"
	hall.Parent = model
	-- Place it facing -Z like the gym, then slide it so the sign's wall sits at the gym's front line.
	hall:PivotTo(CFrame.new(ENTRANCE_X, 0, ENTRANCE_FRONT_Z))
	local sign = hall:FindFirstChild("MeetHall_SignScreen", true) :: BasePart?
	local doors = hall:FindFirstChild("MeetHall_Doors", true) :: BasePart?
	if sign == nil or doors == nil then
		model:Destroy()
		warn("[LocalMeetVenue] the entrance building's model is missing its sign or doors")
		return nil
	end
	hall:PivotTo(hall:GetPivot() + Vector3.new(0, 0, ENTRANCE_FRONT_Z - sign.Position.Z))
	local frontZ = sign.Position.Z
	local doorZ = doors.Position.Z

	-- Hidden solids: the hall (with its gable as a block up to the ridge's middle), and the porch.
	local function solid(name: string, low: Vector3, high: Vector3)
		local part = BuildParts.box(model, name, low, high, looks.Glass)
		part.Transparency = 1
		part.CastShadow = false
	end
	solid("Hall_Solid", Vector3.new(ENTRANCE_X - 20, 0, frontZ), Vector3.new(ENTRANCE_X + 20, 20, frontZ + 30))
	solid("Porch_Solid", Vector3.new(ENTRANCE_X - 9, 0, doorZ + 0.1), Vector3.new(ENTRANCE_X + 9, 9, frontZ))
	solid("Landing_Solid", Vector3.new(ENTRANCE_X - 10, 0, doorZ - 5.2), Vector3.new(ENTRANCE_X + 10, 0.3, doorZ + 0.1))

	-- The sign: big heavy italic LOCAL MEET in the game's style, readable from across the plaza.
	writeSign(sign, -Vector3.zAxis, "LOCAL MEET", "MEETS AGAINST OTHER PLAYERS  //  HOLD E AT THE DOORS", 30)

	-- The point in front of the doors that carries the "Go to the Local Meet" prompt.
	local doorPoint = BuildParts.box(model, "DoorPoint", Vector3.new(ENTRANCE_X - 1.5, 0.3, doorZ - 4),
		Vector3.new(ENTRANCE_X + 1.5, 4.3, doorZ - 1), looks.Glass)
	doorPoint.Transparency = 1
	doorPoint.CanCollide = false
	doorPoint.CanQuery = false
	doorPoint.CastShadow = false
	doorPoint:AddTag(LocalMeetConfig.EntranceTag)
	model.Parent = Workspace
	return doorPoint
end

-- The lobby spot spread out a little for lifter `index`, so lifters leaving the platforms do not stack.
function LocalMeetVenue.lobbySpotFor(v: Venue, index: number): CFrame
	return v.lobbySpot * CFrame.new(((index - 1) % 4 - 1.5) * 4, 0, -((index - 1) // 4) * 3)
end

-- Shows who is lifting on a platform on its big screen, or nil for an open platform.
function LocalMeetVenue.showLifter(platform: Platform, card: LifterDisplay.Card?)
	platform.display.show(card)
end

-- Rewrites the scoreboard.
function LocalMeetVenue.setScoreboard(v: Venue, title: string, lines: { string })
	local board = v.scoreboard
	if board then
		board.setTag(title)
		board.setLines(lines)
	end
end

-- Lights a platform's referee lamps: { "White" | "Red", ... } (three), or nil to switch them off.
function LocalMeetVenue.setLights(platform: Platform, lights: { string }?)
	for index, lamp in ipairs(platform.lamps) do
		local light = lights and lights[index]
		lamp.Material = if light then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lamp.Color = if light == "White" then LAMP_WHITE elseif light == "Red" then LAMP_RED else LAMP_OFF
	end
end

--[[
	The awards (user 2026-10-29): on, every platform's rack, referee chairs and
	light box go away (and the referees with their chairs) and the awards stage
	(podium and LOCAL CENTRAL MEET backdrop) stands in their place; off puts the
	platforms back.
]]
function LocalMeetVenue.showAwards(v: Venue, on: boolean)
	for _, platform in ipairs(v.platforms) do
		platform.gear.Parent = if on then nil else v.model
		if on then
			for _, figure in ipairs(platform.staff:GetChildren()) do
				if figure.Name == "Referee" then
					figure:Destroy()
				end
			end
		end
	end
	v.awards.Parent = if on then v.model else nil
end

-- Seats three referees on the platform's chairs and puts the lifter's coach at its front left corner.
function LocalMeetVenue.staffPlatform(platform: Platform)
	LocalMeetVenue.clearStaff(platform)
	local liftAt = platform.liftSpot.Position
	for _, seat in ipairs(platform.refSeats) do
		local hips = seat.Position
		MeetFigures.build(platform.staff, "Referee", Vector3.new(hips.X, hips.Y - CHAIR_SEAT_TOP, hips.Z), liftAt, hips.Y)
	end
	platform.coachLine = MeetFigures.build(platform.staff, "Coach", platform.coachSpot, liftAt)
end

-- Removes a platform's referees and coach.
function LocalMeetVenue.clearStaff(platform: Platform)
	platform.staff:ClearAllChildren()
	platform.coachLine = nil
end

-- What the platform's coach says; nil hides it.
function LocalMeetVenue.coachSays(platform: Platform, line: string?)
	MeetFigures.say(platform.coachLine, line)
end

return LocalMeetVenue
