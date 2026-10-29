--!strict
--[[
	LocalMeetVenue
	Server / Meet

	The Local meet's TEMPORARY venue (GAME_DESIGN.md §29.10 "The Local meet —
	first build", step 1): one hall, built once when the server starts, far
	from the gym (LocalMeetConfig.Origin). Step 3 replaces it with a venue
	modelled in Blender; until then the shell is plain walls like the Mock
	Meet rooms, and every prop in it is an existing Blender model
	(MockMeet_01's platform, board, bench and desk, the gym's competition
	rack, the light fittings).

	The hall, in its own frame (X across, Z deep, Y up; 0,0,0 = the middle of
	the floor):
		-Z end   the lobby: the arrival spot, the SIGN-UP desk, the exit point,
		         rows of benches facing the platforms, the scoreboard on the
		         left wall
		+Z end   LocalMeetConfig.MaxLifters platforms in a row, side by side,
		         each with the competition rack and its own board on the back
		         wall above it (lifter, attempt, the referees' lights)

	While a meet runs, each used platform gets three referees in front of it and
	the lifter's coach at its front corner (MeetFigures); they are removed after
	the meet. It only builds and draws; the meet is LocalMeetService's job.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local StarterGymConfig = require(ConfigFolder:WaitForChild("StarterGymConfig"))

local ServerFolder = script.Parent.Parent
local WorldFolder = ServerFolder:WaitForChild("World")
local BuildParts = require(WorldFolder:WaitForChild("BuildParts"))
local RoomProps = require(WorldFolder:WaitForChild("RoomProps"))
local StyledScreen = require(WorldFolder:WaitForChild("StyledScreen"))
local MockMeetArena = require(script.Parent:WaitForChild("MockMeetArena"))
local MeetFigures = require(script.Parent:WaitForChild("MeetFigures"))

local LocalMeetVenue = {}

local MODEL_NAME = "LocalMeetVenue"
local WALL = 1
local HEIGHT = 30
local DEPTH = 84 -- Z from -42 to +42
local PLATFORM_SIZE = 16
local PLATFORM_HEIGHT = 0.6
local PLATFORM_Z = 22 -- the platforms' middles
local LIFT_SPOT_IN_FRONT = 4
local BOARD_SCALE = 0.5 -- the platform boards: MockMeet_01's attempt board at half size (14 x 6)

local looks = StarterGymConfig.Looks

export type Platform = {
	index: number,
	-- Where the lifter stands for a lift: on the platform in front of the rack, facing the lobby.
	liftSpot: CFrame,
	-- Where the lifter waits at the weigh-in: on the floor beside the platform, facing the lobby.
	waitSpot: CFrame,
	board: StyledScreen.Handle?,
	-- The referees and coach while a meet runs (cleared after it).
	staff: Folder,
	coachLine: TextLabel?,
}

export type Venue = {
	model: Model,
	-- Where a player arrives from the gym, facing the platforms.
	arrival: CFrame,
	-- Where a lifter goes after the meet: the lobby, facing the platforms.
	lobbySpot: CFrame,
	platforms: { Platform },
	-- The invisible points carrying the sign-up and exit prompts.
	signUpPoint: BasePart,
	exitPoint: BasePart,
	scoreboard: StyledScreen.Handle?,
}

local venue: Venue? = nil

local function platformX(index: number): number
	return (index - (LocalMeetConfig.MaxLifters + 1) / 2) * LocalMeetConfig.PlatformSpacingStuds
end

local function halfWidth(): number
	return LocalMeetConfig.MaxLifters * LocalMeetConfig.PlatformSpacingStuds / 2 + 8
end

-- Builds the venue once and returns it (later calls return the same one), or nil and the reason.
function LocalMeetVenue.build(): (Venue?, string?)
	if venue then
		return venue, nil
	end
	local centre = LocalMeetConfig.Origin
	local hx, hz, h = halfWidth(), DEPTH / 2, HEIGHT

	local model = Instance.new("Model")
	model.Name = MODEL_NAME

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
	local function prop(name: string, item: string): Model?
		local copy = RoomProps.propCopy(item, 1)
		if copy then
			copy.Name = name
			copy.Parent = model
		end
		return copy
	end
	-- An invisible, non-solid point that carries a prompt.
	local function point(name: string, at: Vector3): BasePart
		local part = box(name, at - Vector3.new(1, 0, 1), at + Vector3.new(1, 4, 1), looks.Glass)
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		return part
	end
	local function shine(part: BasePart, range: number, brightness: number, angle: number)
		BuildParts.surfaceLight(part, StyledScreen.faceToward(part, -Vector3.yAxis), range, brightness, angle)
	end

	-- The shell: floor, ceiling and four walls (solid, so nobody walks or falls out).
	box("Floor", Vector3.new(-hx - WALL, -WALL, -hz - WALL), Vector3.new(hx + WALL, 0, hz + WALL), looks.MaxBlack)
	box("Ceiling", Vector3.new(-hx - WALL, h, -hz - WALL), Vector3.new(hx + WALL, h + WALL, hz + WALL), looks.MaxBlack)
	box("Wall_Back", Vector3.new(-hx - WALL, 0, hz), Vector3.new(hx + WALL, h, hz + WALL), looks.MaxBlack)
	box("Wall_Front", Vector3.new(-hx - WALL, 0, -hz - WALL), Vector3.new(hx + WALL, h, -hz), looks.MaxBlack)
	box("Wall_Left", Vector3.new(-hx - WALL, 0, -hz), Vector3.new(-hx, h, hz), looks.MaxBlack)
	box("Wall_Right", Vector3.new(hx, 0, -hz), Vector3.new(hx + WALL, h, hz), looks.MaxBlack)
	-- The gym's red competition stripe round the walls, and a carpet.
	decor("Stripe_Back", Vector3.new(-hx, 2.9, hz - 0.06), Vector3.new(hx, 3.5, hz), looks.PlateRed)
	decor("Stripe_Front", Vector3.new(-hx, 2.9, -hz), Vector3.new(hx, 3.5, -hz + 0.06), looks.PlateRed)
	decor("Stripe_Left", Vector3.new(-hx, 2.9, -hz), Vector3.new(-hx + 0.06, 3.5, hz), looks.PlateRed)
	decor("Stripe_Right", Vector3.new(hx - 0.06, 2.9, -hz), Vector3.new(hx, 3.5, hz), looks.PlateRed)
	decor("Carpet", Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0.04, hz), looks.FrontCharcoal)

	-- The platforms, in a row towards the back wall.
	local half = PLATFORM_SIZE / 2
	local platforms: { Platform } = {}
	for index = 1, LocalMeetConfig.MaxLifters do
		local x = platformX(index)
		local platform = prop("Platform_" .. index, "MeetPlatform")
		if platform then
			platform:PivotTo(CFrame.new(centre + Vector3.new(x, 0, PLATFORM_Z)))
			solid("Platform_" .. index .. "_Solid", Vector3.new(x - half - 0.3, 0, PLATFORM_Z - half - 0.3),
				Vector3.new(x + half + 0.3, PLATFORM_HEIGHT, PLATFORM_Z + half + 0.3))
		else
			box("Platform_" .. index .. "_Base", Vector3.new(x - half - 0.3, 0, PLATFORM_Z - half - 0.3),
				Vector3.new(x + half + 0.3, PLATFORM_HEIGHT - 0.1, PLATFORM_Z + half + 0.3), looks.FrontCharcoal)
			box("Platform_" .. index .. "_Top", Vector3.new(x - half, PLATFORM_HEIGHT - 0.1, PLATFORM_Z - half),
				Vector3.new(x + half, PLATFORM_HEIGHT, PLATFORM_Z + half), looks.Wood)
		end
		local placed, problem = MockMeetArena.placeRack(model, centre + Vector3.new(x, PLATFORM_HEIGHT, PLATFORM_Z))
		if not placed then
			model:Destroy()
			return nil, problem
		end

		-- The platform's board on the back wall above it: MockMeet_01's attempt board at half size.
		local boardOut = -Vector3.zAxis
		local boardAt = centre + Vector3.new(x, 13, hz)
		local frame = prop("PlatformBoard_" .. index, "MeetBoard")
		local screen = frame and frame:FindFirstChild("MeetBoard_Screen", true) :: BasePart?
		local boardPart: BasePart
		if frame and screen then
			frame:ScaleTo(BOARD_SCALE)
			MockMeetArena.hangOnWall(frame, screen, centre + Vector3.new(0, 0, hz - 0.06), boardOut, boardAt)
			boardPart = screen
		else
			if frame then
				frame:Destroy()
			end
			boardPart = decor("PlatformBoard_" .. index, Vector3.new(x - 7, 10, hz - 0.4), Vector3.new(x + 7, 16, hz - 0.06),
				looks.Gadget)
		end
		local board = StyledScreen.build(boardPart, StyledScreen.faceToward(boardPart, boardOut),
			"PLATFORM " .. index, { "Free" }, "bar", 30)

		-- One stage light over each platform.
		local lightAt = centre + Vector3.new(x, h - 0.425, PLATFORM_Z - 0.43)
		local can = RoomProps.fitting(model, "StageLight_" .. index, "StageLight", "Lens",
			CFrame.lookAt(lightAt, lightAt - Vector3.yAxis, Vector3.zAxis))
			or decor("StageLight_" .. index, Vector3.new(x - 1, h - 1, PLATFORM_Z - 1), Vector3.new(x + 1, h - 0.2, PLATFORM_Z + 1),
				looks.GlowWhite)
		shine(can, 26, 2.2, 70)

		local staff = Instance.new("Folder")
		staff.Name = "Staff_" .. index
		staff.Parent = model
		local liftAt = centre + Vector3.new(x, PLATFORM_HEIGHT, PLATFORM_Z - LIFT_SPOT_IN_FRONT)
		local waitAt = centre + Vector3.new(x - half - 2, 0, PLATFORM_Z)
		table.insert(platforms, {
			index = index,
			liftSpot = CFrame.lookAt(liftAt, liftAt - Vector3.zAxis),
			waitSpot = CFrame.lookAt(waitAt, waitAt - Vector3.zAxis),
			board = board,
			staff = staff,
			coachLine = nil,
		})
	end

	-- The lobby: benches in rows facing the platforms (MockMeet_01's bench on a hidden solid block).
	local benchRows = { -10, -18 }
	for row, z in ipairs(benchRows) do
		for x = -hx + 14, hx - 14, 16 do
			local name = string.format("Bench_%d_%d", row, x)
			local at = centre + Vector3.new(x, 0, z)
			local bench = prop(name, "MeetBench")
			if bench then
				bench:PivotTo(CFrame.lookAt(at, at + Vector3.zAxis))
				solid(name .. "_Solid", Vector3.new(x - 5, 0, z - 1), Vector3.new(x + 5, 1.8, z + 1))
			else
				box(name, Vector3.new(x - 5, 1.5, z - 1), Vector3.new(x + 5, 1.8, z + 1), looks.Wood)
			end
		end
	end

	-- The sign-up desk by the front wall, facing the hall: MockMeet_01's desk with its monitor.
	local deskZ = -hz + 4
	local desk = prop("SignUpDesk", "MeetDesk")
	if desk then
		local at = centre + Vector3.new(0, 0, deskZ)
		desk:PivotTo(CFrame.lookAt(at, at + Vector3.zAxis))
		solid("SignUpDesk_Solid", Vector3.new(-5.25, 0, deskZ - 1.15), Vector3.new(5.25, 3.3, deskZ + 1.15))
		local monitor = desk:FindFirstChild("MeetDesk_MonitorScreen", true) :: BasePart?
		if monitor then
			StyledScreen.build(monitor, StyledScreen.faceToward(monitor, -Vector3.zAxis), "SIGN-UP",
				{ "Local meet desk", "Every 10 minutes" }, "bar", 120)
		end
	else
		box("SignUpDesk", Vector3.new(-5, 0, deskZ - 1), Vector3.new(5, 3.2, deskZ + 1), looks.FrontCharcoal)
	end
	local signUpPoint = point("SignUpPoint", centre + Vector3.new(0, 0, deskZ + 4))
	local exitPoint = point("ExitPoint", centre + Vector3.new(-hx + 6, 0, -hz + 4))

	-- The scoreboard on the left wall, facing the lobby, and the venue's banner on the right wall.
	local scoreboard: StyledScreen.Handle? = nil
	local boardFrame = prop("Scoreboard", "MeetBoard")
	local boardScreen = boardFrame and boardFrame:FindFirstChild("MeetBoard_Screen", true) :: BasePart?
	local scorePart: BasePart
	if boardFrame and boardScreen then
		MockMeetArena.hangOnWall(boardFrame, boardScreen, centre + Vector3.new(-hx + 0.06, 0, 0), Vector3.xAxis,
			centre + Vector3.new(-hx, 15, -14))
		scorePart = boardScreen
	else
		if boardFrame then
			boardFrame:Destroy()
		end
		scorePart = decor("Scoreboard", Vector3.new(-hx + 0.06, 9, -28), Vector3.new(-hx + 0.4, 21, 0), looks.Gadget)
	end
	scoreboard = StyledScreen.build(scorePart, StyledScreen.faceToward(scorePart, Vector3.xAxis), "LOCAL MEET",
		{ "Sign up at the desk", "A meet every 10 minutes" }, "star", 30)
	local banner = prop("Banner", "MeetBanner")
	local cloth = banner and banner:FindFirstChild("MeetBanner_Cloth", true) :: BasePart?
	if banner and cloth then
		MockMeetArena.hangOnWall(banner, cloth, centre + Vector3.new(hx, 0, 0), -Vector3.xAxis, centre + Vector3.new(hx, 11, -14))
		StyledScreen.build(cloth, StyledScreen.faceToward(cloth, -Vector3.xAxis), "LOCAL MEET",
			{ "Everyone lifts together", "Best score wins" }, "dots", 30)
	elseif banner then
		banner:Destroy()
	end

	-- Ceiling panels over the lobby (Lighting.Ambient is black, so the hall brings its own light).
	for _, z in ipairs({ -hz + 8, -hz + 22 }) do
		for x = -hx + 16, hx - 16, 32 do
			local name = string.format("CeilingLight_%d_%d", x, z)
			local panel = RoomProps.fitting(model, name, "CeilingPanel", "Diffuser", CFrame.new(centre + Vector3.new(x, h - 0.12, z)),
				Vector3.new(6, 0.12, 6)) or decor(name, Vector3.new(x - 3, h - 0.2, z - 3), Vector3.new(x + 3, h, z + 3), looks.GlowWhite)
			shine(panel, 40, 2.2, 110)
		end
	end

	model.PrimaryPart = model:FindFirstChild("Floor") :: BasePart
	model.Parent = Workspace

	local arrivalAt = centre + Vector3.new(14, 0, -hz + 6)
	local lobbyAt = centre + Vector3.new(0, 0, -30 + 0)
	venue = {
		model = model,
		arrival = CFrame.lookAt(arrivalAt, arrivalAt + Vector3.zAxis),
		lobbySpot = CFrame.lookAt(lobbyAt, lobbyAt + Vector3.zAxis),
		platforms = platforms,
		signUpPoint = signUpPoint,
		exitPoint = exitPoint,
		scoreboard = scoreboard,
	}
	return venue, nil
end

-- The lobby spot spread out a little for lifter `index`, so lifters leaving the platforms do not stack.
function LocalMeetVenue.lobbySpotFor(v: Venue, index: number): CFrame
	return v.lobbySpot * CFrame.new(((index - 1) % 4 - 1.5) * 4, 0, -((index - 1) // 4) * 3)
end

-- Rewrites a platform's board.
function LocalMeetVenue.setPlatformBoard(platform: Platform, title: string, lines: { string })
	local board = platform.board
	if board then
		board.setTag(title)
		board.setLines(lines)
	end
end

-- Rewrites the scoreboard.
function LocalMeetVenue.setScoreboard(v: Venue, title: string, lines: { string })
	local board = v.scoreboard
	if board then
		board.setTag(title)
		board.setLines(lines)
	end
end

-- Puts three referees in front of a platform and the lifter's coach at its front corner.
function LocalMeetVenue.staffPlatform(platform: Platform)
	LocalMeetVenue.clearStaff(platform)
	local liftAt = platform.liftSpot.Position
	local floorZ = liftAt.Z - (PLATFORM_SIZE / 2 - LIFT_SPOT_IN_FRONT) - 3
	for _, dx in ipairs({ -5, 0, 5 }) do
		MeetFigures.build(platform.staff, "Referee", Vector3.new(liftAt.X + dx, liftAt.Y - PLATFORM_HEIGHT, floorZ), liftAt)
	end
	platform.coachLine = MeetFigures.build(platform.staff, "Coach",
		Vector3.new(liftAt.X + PLATFORM_SIZE / 2 + 1.5, liftAt.Y - PLATFORM_HEIGHT, floorZ + 2), liftAt)
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
