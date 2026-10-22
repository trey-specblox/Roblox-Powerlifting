--!strict
--[[
	StarterGymBuilder
	Server / World

	Builds the Starter Gym, "version 2" (GAME_DESIGN.md §27, approved
	2026-10-21), as Workspace.StarterGym at server start. Every size comes from
	StarterGymConfig.footprint (worked out from TrainingStationConfig.GymLayout);
	nothing is placed by hand.

	STAGE 1 (this file, now):
	  Floors  Floor_Hall (rubber, under the racks), Floor_Lobby, the rooms'
	          floors, the upper floor slabs (Slab_*).
	  Roofs   the room blocks' ceilings (Ceiling_*, hidden under the roof).
	          STAGE 2: ONE pitched roof over the whole building (Roof_*, with
	          Roof_*_Skylight_* glass over the hall), the gables on the outer
	          side walls (Gable_*), walls closing the hall off up to the roof
	          (HallWall_*) and the steel beams over the hall (RoofBeams).
	  Walls   outer walls (dark band + painted wall), the lobby's glass front
	          with the entrance, the glass fronts between the hall and every
	          room (one door per room, both floors), and the walls between rooms.
	  Rooms   one invisible, non-solid region part per room, "Room_<Name>",
	          with attributes Floor (1 or 2), DoorCentre and DoorAlongX, for
	          NPCs, signs and checks later.
	Later stages: the glass stairs and balcony (upstairs is not reachable yet),
	reception desk and gym-name wall, lights.

	Visual and physical only: no gameplay rule, credit or player data changes.
	FAILS CLOSED: if anything goes wrong the half-built gym is removed with a
	warning, and the racks and every other system still start. Runtime only:
	nothing is saved into the place. Call build() once; later calls do nothing.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local TrainingStationConfig = require(ConfigFolder:WaitForChild("TrainingStationConfig"))
local StarterGymConfig = require(ConfigFolder:WaitForChild("StarterGymConfig"))

local StarterGymBuilder = {}

local MODEL_NAME = "StarterGym"

type Opening = { centre: number, width: number, height: number, bottom: number }
-- "Outer": dark band at the bottom, painted above. "Paint": painted only. "Glass": glass only.
type WallKind = "Outer" | "Paint" | "Glass"

local built = false

-- An anchored, solid part of `size` at `cframe` (a Part, or a WedgePart for the gables).
local function placed(parent: Instance, name: string, size: Vector3, cframe: CFrame, look: StarterGymConfig.Look,
	className: string?): BasePart
	local part = Instance.new(className or "Part") :: BasePart
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = look.material
	part.Color = look.color
	part.Transparency = look.transparency or 0
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

-- An axis-aligned box between two corners.
local function box(parent: Instance, name: string, low: Vector3, high: Vector3, look: StarterGymConfig.Look): BasePart
	return placed(parent, name, high - low, CFrame.new((low + high) / 2), look)
end

--[[
	One straight wall from y0 to y1. `alongX` walls run from `from` to `to` in
	X on the Z line `line`; the others run in Z on the X line `line`. Openings
	are gaps from their `bottom` up to bottom + height, closed above (a lintel
	of the wall's own kind).
]]
local function wall(parent: Instance, name: string, alongX: boolean, line: number, from: number, to: number,
	y0: number, y1: number, kind: WallKind, openings: { Opening })
	local cfg = StarterGymConfig
	local half = cfg.WallThicknessStuds / 2
	local looks = cfg.Looks
	local mainLook = if kind == "Glass" then looks.Glass else looks.WallPaint
	local bandTop = y0 + cfg.WallBandHeightStuds

	local function corners(a: number, b: number, low: number, high: number): (Vector3, Vector3)
		if alongX then
			return Vector3.new(a, low, line - half), Vector3.new(b, high, line + half)
		end
		return Vector3.new(line - half, low, a), Vector3.new(line + half, high, b)
	end

	local piece = 0
	local function solid(a: number, b: number, low: number, high: number)
		if b - a <= 0.001 or high - low <= 0.001 then
			return
		end
		piece += 1
		if kind == "Outer" and low < bandTop then
			local bandLow, bandHigh = corners(a, b, low, math.min(bandTop, high))
			box(parent, string.format("%s_%d_Band", name, piece), bandLow, bandHigh, looks.WallBand)
			low = bandTop
			if high - low <= 0.001 then
				return
			end
		end
		local partLow, partHigh = corners(a, b, low, high)
		box(parent, string.format("%s_%d", name, piece), partLow, partHigh, mainLook)
	end

	table.sort(openings, function(p, q)
		return p.centre < q.centre
	end)
	local cursor = from
	for index, opening in ipairs(openings) do
		local a, b = opening.centre - opening.width / 2, opening.centre + opening.width / 2
		assert(a >= cursor - 0.001 and b <= to + 0.001, string.format("%s: opening %d does not fit in the wall", name, index))
		solid(cursor, a, y0, y1)
		-- Below the opening (an upper-floor door starts well above y0; a ground-floor
		-- door only 0.05 above it, too thin to bother with) and above it.
		if opening.bottom - y0 > 0.1 then
			solid(a, b, y0, opening.bottom)
		end
		solid(a, b, opening.bottom + opening.height, y1)
		cursor = b
	end
	solid(cursor, to, y0, y1)
end

-- An invisible region for one room, with where its door is.
local function room(parent: Instance, name: string, floorNumber: number, low: Vector3, high: Vector3,
	doorCentre: Vector3, doorAlongX: boolean)
	local part = box(parent, "Room_" .. name, low, high, StarterGymConfig.Looks.WallPaint)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part:SetAttribute("Floor", floorNumber)
	part:SetAttribute("DoorCentre", doorCentre)
	part:SetAttribute("DoorAlongX", doorAlongX)
end

--[[
	STAGE 2: ONE pitched roof over the WHOLE building (GAME_DESIGN §27: no flat
	roof tops, user 2026-10-21). The ridge runs along X over the middle of the
	building; each slope runs from its eave (the front or back outer wall's top)
	up to the ridge. A slope is described by where its eave is, the unit
	direction up the slope (`along`) and its outward normal.
]]
type Slope = { name: string, eaveY: number, eaveZ: number, along: Vector3, normal: Vector3, length: number }

-- The frame of a point in a slope: `x` along the ridge, `s` up the slope from
-- the eave, `offset` out of the slope's underside (negative = below it).
-- Its X axis runs along the ridge and its Y axis is the slope's normal.
local function slopeFrame(slope: Slope, x: number, s: number, offset: number): CFrame
	local position = Vector3.new(x, slope.eaveY, slope.eaveZ) + slope.along * s + slope.normal * offset
	return CFrame.fromMatrix(position, Vector3.xAxis, slope.normal)
end

local function buildRoof(roofs: Folder, plan: StarterGymConfig.Footprint): number
	local cfg = StarterGymConfig
	local looks = cfg.Looks
	local t = cfg.WallThicknessStuds
	local thickness = cfg.RoofThicknessStuds
	local cx, hallHalf, outerHalf = plan.centreX, plan.hallHalfWidth, plan.outerHalfWidth

	-- The eaves sit on the front and back outer walls.
	local eaveY = plan.roofY
	local frontEaveZ, backEaveZ = plan.frontZ - t, plan.hallBackZ + t
	local ridgeZ = (frontEaveZ + backEaveZ) / 2
	local run, rise = ridgeZ - frontEaveZ, cfg.RoofRiseStuds
	local ridgeY = eaveY + rise
	local length = math.sqrt(run * run + rise * rise)
	local xMin = cx - outerHalf - t - cfg.RoofOverhangStuds
	local xMax = cx + outerHalf + t + cfg.RoofOverhangStuds
	local hallMinX, hallMaxX = cx - hallHalf, cx + hallHalf

	-- How high the roof's underside is above the eaves at depth z.
	local function heightAt(z: number): number
		return rise * (1 - math.abs(z - ridgeZ) / run)
	end

	local slopes: { Slope } = {
		{ name = "Front", eaveY = eaveY, eaveZ = frontEaveZ, along = Vector3.new(0, rise, run).Unit,
			normal = Vector3.new(0, run, -rise).Unit, length = length },
		{ name = "Back", eaveY = eaveY, eaveZ = backEaveZ, along = Vector3.new(0, rise, -run).Unit,
			normal = Vector3.new(0, run, rise).Unit, length = length },
	}
	-- How far up a slope (from its eave) depth z is.
	local function slopeDistance(slope: Slope, z: number): number
		return math.abs(z - slope.eaveZ) / run * length
	end

	local skylights = 0
	local function panel(slope: Slope, name: string, x0: number, x1: number, s0: number, s1: number,
		look: StarterGymConfig.Look): BasePart
		return placed(roofs, string.format("Roof_%s_%s", slope.name, name),
			Vector3.new(x1 - x0, thickness, s1 - s0),
			slopeFrame(slope, (x0 + x1) / 2, (s0 + s1) / 2, thickness / 2), look)
	end

	for _, slope in ipairs(slopes) do
		-- The skylight band: over the hall only, the same distance from the ridge on both slopes.
		local towardEave = if slope.name == "Front" then -1 else 1
		local bandNearZ = ridgeZ + towardEave * cfg.SkylightStartFromRidgeStuds
		local bandFarZ = bandNearZ + towardEave * cfg.SkylightDepthStuds
		assert(bandFarZ > plan.hallFrontZ and bandFarZ < plan.hallBackZ,
			"the skylight band reaches past the rack hall; make SkylightDepthStuds smaller")
		local bandStart, bandEnd = slopeDistance(slope, bandFarZ), slopeDistance(slope, bandNearZ)

		panel(slope, "Lower", xMin, xMax, 0, bandStart, looks.HallRoof)
		panel(slope, "Upper", xMin, xMax, bandEnd, length, looks.HallRoof)
		-- Beside the band, over the side blocks: plain roof.
		panel(slope, "BandLeft", hallMaxX, xMax, bandStart, bandEnd, looks.HallRoof)
		panel(slope, "BandRight", xMin, hallMinX, bandStart, bandEnd, looks.HallRoof)
		-- Over the hall: gap, skylight, gap, skylight, ..., gap.
		local count, gap = cfg.SkylightsPerSlope, cfg.SkylightGapStuds
		local skylightLength = ((hallMaxX - hallMinX) - (count + 1) * gap) / count
		assert(skylightLength > 0, "the skylights do not fit along the hall")
		local x = hallMinX
		for index = 1, count do
			panel(slope, string.format("Gap_%d", index), x, x + gap, bandStart, bandEnd, looks.HallRoof)
			x += gap
			local glass = panel(slope, string.format("Skylight_%d", index), x, x + skylightLength, bandStart, bandEnd,
				looks.Skylight)
			glass.CastShadow = false -- let the sunlight through
			skylights += 1
			x += skylightLength
		end
		panel(slope, string.format("Gap_%d", count + 1), x, hallMaxX, bandStart, bandEnd, looks.HallRoof)
	end

	-- A cap along the ridge, over the seam where the two slopes meet.
	box(roofs, "Roof_RidgeCap", Vector3.new(xMin, ridgeY, ridgeZ - thickness),
		Vector3.new(xMax, ridgeY + thickness * 1.2, ridgeZ + thickness), looks.HallRoof)

	--[[
		Walls up to the roof's underside, between eave height and the roof.
		A WedgePart is full height at its back (+Z) and zero at its front; a
		piece whose high end is toward -Z is turned round.
	]]
	local function underRoof(name: string, line: number, z0: number, z1: number)
		local pieces = if z0 < ridgeZ and z1 > ridgeZ then { { z0, ridgeZ }, { ridgeZ, z1 } } else { { z0, z1 } }
		for index, piece in ipairs(pieces) do
			local za, zb = piece[1], piece[2]
			local ha, hb = heightAt(za), heightAt(zb)
			local low, high = math.min(ha, hb), math.max(ha, hb)
			local middleZ = (za + zb) / 2
			if low > 0.01 then
				box(roofs, string.format("%s_%d_Base", name, index), Vector3.new(line - t / 2, eaveY, za),
					Vector3.new(line + t / 2, eaveY + low, zb), looks.WallPaint)
			end
			local turn = if hb >= ha then CFrame.identity else CFrame.Angles(0, math.pi, 0)
			placed(roofs, string.format("%s_%d", name, index), Vector3.new(t, high - low, zb - za),
				CFrame.new(line, eaveY + low + (high - low) / 2, middleZ) * turn, looks.WallPaint, "WedgePart")
		end
	end

	-- The gables: the two outer side walls, closed up to the roof.
	underRoof("Gable_Left", cx + outerHalf + t / 2, frontEaveZ, backEaveZ)
	underRoof("Gable_Right", cx - outerHalf - t / 2, frontEaveZ, backEaveZ)
	-- Inside: close the hall off from the space under the roof over the rooms,
	-- above the side glass fronts and above the front block's glass front.
	underRoof("HallWall_Left", cx + hallHalf + t / 2, plan.hallFrontZ - t, plan.hallBackZ)
	underRoof("HallWall_Right", cx - hallHalf - t / 2, plan.hallFrontZ - t, plan.hallBackZ)
	box(roofs, "HallWall_Front", Vector3.new(hallMinX - t, eaveY, plan.hallFrontZ - t),
		Vector3.new(hallMaxX + t, eaveY + heightAt(plan.hallFrontZ), plan.hallFrontZ), looks.WallPaint)

	-- Exposed steel over the hall: per bay, a rafter under each slope (only
	-- above the hall) and a tie beam across; one ridge beam along the hall.
	local beams = Instance.new("Folder")
	beams.Name = "RoofBeams"
	beams.Parent = roofs
	local beamWidth, beamDepth = cfg.RoofBeamWidthStuds, cfg.RoofBeamDepthStuds
	local bayWidth = 2 * hallHalf / cfg.RoofBeamCount
	for index = 1, cfg.RoofBeamCount do
		local x = hallMinX + (index - 0.5) * bayWidth
		for _, slope in ipairs(slopes) do
			local hallEdgeZ = if slope.name == "Front" then plan.hallFrontZ else plan.hallBackZ
			local s0 = slopeDistance(slope, hallEdgeZ)
			placed(beams, string.format("Rafter_%s_%d", slope.name, index), Vector3.new(beamWidth, beamDepth, length - s0),
				slopeFrame(slope, x, (s0 + length) / 2, -beamDepth / 2), looks.SteelBeam)
		end
		box(beams, string.format("TieBeam_%d", index), Vector3.new(x - beamWidth / 2, eaveY - beamDepth, plan.hallFrontZ),
			Vector3.new(x + beamWidth / 2, eaveY, plan.hallBackZ), looks.SteelBeam)
	end
	box(beams, "RidgeBeam", Vector3.new(hallMinX, ridgeY - 2 * beamDepth, ridgeZ - beamWidth / 2),
		Vector3.new(hallMaxX, ridgeY - beamDepth / 2, ridgeZ + beamWidth / 2), looks.SteelBeam)

	return skylights
end

-- Builds the gym into `model` and returns a one-line summary for the Output.
local function buildGym(model: Model): string
	local cfg = StarterGymConfig
	local looks = cfg.Looks
	local plan = cfg.footprint(TrainingStationConfig.GymLayout)
	local t = cfg.WallThicknessStuds
	local cx = plan.centreX
	local hallFrontZ, hallBackZ, frontZ = plan.hallFrontZ, plan.hallBackZ, plan.frontZ
	local hallHalf, outerHalf, lobbyHalf = plan.hallHalfWidth, plan.outerHalfWidth, plan.lobbyHalfWidth
	local floorY, upperY = plan.floorY, plan.upperFloorY
	local upperSlabBottom, roofSlabBottom, roofY = plan.upperSlabBottomY, plan.roofSlabBottomY, plan.roofY
	local floorLow = floorY - cfg.FloorThicknessStuds
	local blockBackZ = hallFrontZ - t -- the front block's inside back face
	local doorWidth, doorHeight = cfg.RoomDoorWidthStuds, cfg.RoomDoorHeightStuds

	local function folder(name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		return f
	end
	local floors, roofs, walls, rooms = folder("Floors"), folder("Roofs"), folder("Walls"), folder("Rooms")

	local function door(centre: number, bottom: number): Opening
		return { centre = centre, width = doorWidth, height = doorHeight, bottom = bottom }
	end

	-- ---------------------------------------------------------------- floors and roofs
	box(floors, "Floor_Hall", Vector3.new(cx - hallHalf, floorLow, hallFrontZ), Vector3.new(cx + hallHalf, floorY, hallBackZ),
		looks.GymFloor)
	box(floors, "Floor_Lobby", Vector3.new(cx - lobbyHalf, floorLow, frontZ), Vector3.new(cx + lobbyHalf, floorY, blockBackZ),
		looks.LobbyFloor)
	box(floors, "Floor_FrontLeft", Vector3.new(cx + lobbyHalf, floorLow, frontZ), Vector3.new(cx + outerHalf, floorY, blockBackZ),
		looks.RoomFloor)
	box(floors, "Floor_FrontRight", Vector3.new(cx - outerHalf, floorLow, frontZ), Vector3.new(cx - lobbyHalf, floorY, blockBackZ),
		looks.RoomFloor)
	box(floors, "Floor_LeftBlock", Vector3.new(cx + hallHalf + t, floorLow, hallFrontZ),
		Vector3.new(cx + outerHalf, floorY, hallBackZ), looks.RoomFloor)
	box(floors, "Floor_RightBlock", Vector3.new(cx - outerHalf, floorLow, hallFrontZ),
		Vector3.new(cx - hallHalf - t, floorY, hallBackZ), looks.RoomFloor)

	-- The upper floor and the ceiling of each room block (they reach under the walls).
	-- The ceilings are hidden under the one pitched roof: no flat roof shows outside.
	local blocks = {
		{ name = "LeftBlock", low = Vector2.new(cx + hallHalf, hallFrontZ), high = Vector2.new(cx + outerHalf + t, hallBackZ) },
		{ name = "RightBlock", low = Vector2.new(cx - outerHalf - t, hallFrontZ), high = Vector2.new(cx - hallHalf, hallBackZ) },
		{ name = "FrontBlock", low = Vector2.new(cx - outerHalf - t, frontZ - t), high = Vector2.new(cx + outerHalf + t, hallFrontZ) },
	}
	for _, block in ipairs(blocks) do
		box(floors, "Slab_" .. block.name, Vector3.new(block.low.X, upperSlabBottom, block.low.Y),
			Vector3.new(block.high.X, upperY, block.high.Y), looks.RoomFloor)
		box(roofs, "Ceiling_" .. block.name, Vector3.new(block.low.X, roofSlabBottom, block.low.Y),
			Vector3.new(block.high.X, roofY, block.high.Y), looks.WallPaint)
	end

	-- ---------------------------------------------------------------- outer walls
	local outerMinX, outerMaxX = cx - outerHalf - t, cx + outerHalf + t
	local frontLine = frontZ - t / 2
	-- The front: solid on both sides of the lobby; the lobby has a glass front with the entrance.
	wall(walls, "Wall_Front_Left", true, frontLine, cx + lobbyHalf, outerMaxX, 0, roofY, "Outer", {})
	wall(walls, "Wall_Front_Right", true, frontLine, outerMinX, cx - lobbyHalf, 0, roofY, "Outer", {})
	wall(walls, "Glass_Lobby_Front", true, frontLine, cx - lobbyHalf, cx + lobbyHalf, 0, upperSlabBottom, "Glass", {
		{ centre = cx, width = cfg.EntranceWidthStuds, height = cfg.EntranceHeightStuds, bottom = floorY },
	})
	wall(walls, "Wall_Front_AboveLobby", true, frontLine, cx - lobbyHalf, cx + lobbyHalf, upperSlabBottom, roofY, "Paint", {})
	wall(walls, "Wall_Back", true, hallBackZ + t / 2, outerMinX, outerMaxX, 0, roofY, "Outer", {})
	wall(walls, "Wall_Left", false, cx + outerHalf + t / 2, frontZ, hallBackZ, 0, roofY, "Outer", {})
	wall(walls, "Wall_Right", false, cx - outerHalf - t / 2, frontZ, hallBackZ, 0, roofY, "Outer", {})

	-- ---------------------------------------------------------------- the side blocks
	local sideDepth = (hallBackZ - hallFrontZ) / 4
	local function sideBlock(sideName: string, sign: number, groundNames: { string }, upperNames: { string })
		local glassLine = cx + sign * (hallHalf + t / 2)
		local innerX, outerX = cx + sign * (hallHalf + t), cx + sign * outerHalf
		local minX, maxX = math.min(innerX, outerX), math.max(innerX, outerX)
		local groundDoors, upperDoors = {}, {}
		for index = 1, 4 do
			local z0 = hallFrontZ + (index - 1) * sideDepth
			local zc = z0 + sideDepth / 2
			table.insert(groundDoors, door(zc, floorY))
			table.insert(upperDoors, door(zc, upperY))
			room(rooms, groundNames[index], 1, Vector3.new(minX, floorY, z0), Vector3.new(maxX, upperSlabBottom, z0 + sideDepth),
				Vector3.new(glassLine, floorY + doorHeight / 2, zc), false)
			room(rooms, upperNames[index], 2, Vector3.new(minX, upperY, z0), Vector3.new(maxX, roofSlabBottom, z0 + sideDepth),
				Vector3.new(glassLine, upperY + doorHeight / 2, zc), false)
			if index < 4 then
				-- Between two rooms, both floors.
				wall(walls, string.format("Wall_%s_Divider_%d", sideName, index), true, z0 + sideDepth,
					minX, maxX, 0, roofY, "Paint", {})
			end
		end
		-- The glass front onto the hall: ground, the slab edge, upper, the roof edge.
		wall(walls, "Glass_" .. sideName .. "_Ground", false, glassLine, hallFrontZ, hallBackZ, 0, upperSlabBottom, "Glass", groundDoors)
		wall(walls, "Wall_" .. sideName .. "_SlabEdge", false, glassLine, hallFrontZ, hallBackZ, upperSlabBottom, upperY, "Paint", {})
		wall(walls, "Glass_" .. sideName .. "_Upper", false, glassLine, hallFrontZ, hallBackZ, upperY, roofSlabBottom, "Glass", upperDoors)
		wall(walls, "Wall_" .. sideName .. "_RoofEdge", false, glassLine, hallFrontZ, hallBackZ, roofSlabBottom, roofY, "Paint", {})
	end
	sideBlock("LeftBlock", 1, cfg.Rooms.LeftGround, cfg.Rooms.LeftUpper)
	sideBlock("RightBlock", -1, cfg.Rooms.RightGround, cfg.Rooms.RightUpper)

	-- ---------------------------------------------------------------- the front block
	local frontGlassLine = hallFrontZ - t / 2
	local middleZ = (frontZ + blockBackZ) / 2
	-- Ground floor, left to right as you walk in (+X to -X): lockers, lobby, cafe.
	local lockersCentre = cx + (lobbyHalf + hallHalf) / 2
	local frontGround = cfg.Rooms.FrontGround
	local groundSpans = {
		{ name = frontGround[1], x0 = cx + lobbyHalf, x1 = cx + hallHalf },
		{ name = frontGround[2], x0 = cx - lobbyHalf, x1 = cx + lobbyHalf },
		{ name = frontGround[3], x0 = cx - hallHalf, x1 = cx - lobbyHalf },
	}
	local frontGroundOpenings: { Opening } = {
		door(lockersCentre, floorY),
		{ centre = cx, width = cfg.LobbyOpeningWidthStuds, height = cfg.LobbyOpeningHeightStuds, bottom = floorY },
		door(2 * cx - lockersCentre, floorY),
	}
	-- Each room's door is in the middle of its stretch of glass (the lobby's is its wide opening).
	for _, span in ipairs(groundSpans) do
		local centre = (span.x0 + span.x1) / 2
		room(rooms, span.name, 1, Vector3.new(span.x0, floorY, frontZ), Vector3.new(span.x1, upperSlabBottom, blockBackZ),
			Vector3.new(centre, floorY + doorHeight / 2, frontGlassLine), true)
	end
	-- Upper floor: three equal rooms across the hall's width.
	local third = 2 * hallHalf / 3
	local frontUpper = cfg.Rooms.FrontUpper
	local upperOpenings: { Opening } = {}
	for index = 1, 3 do
		local x1 = cx + hallHalf - (index - 1) * third
		local x0 = x1 - third
		local centre = (x0 + x1) / 2
		table.insert(upperOpenings, door(centre, upperY))
		room(rooms, frontUpper[index], 2, Vector3.new(x0, upperY, frontZ), Vector3.new(x1, roofSlabBottom, blockBackZ),
			Vector3.new(centre, upperY + doorHeight / 2, frontGlassLine), true)
		if index < 3 then
			wall(walls, string.format("Wall_FrontUpper_Divider_%d", index), false, x0, frontZ, blockBackZ,
				upperY, roofSlabBottom, "Paint", {})
		end
	end
	-- The glass front onto the hall (it also closes the corners where the side glass meets it).
	local glassMinX, glassMaxX = cx - hallHalf - t, cx + hallHalf + t
	wall(walls, "Glass_FrontBlock_Ground", true, frontGlassLine, glassMinX, glassMaxX, 0, upperSlabBottom, "Glass", frontGroundOpenings)
	wall(walls, "Wall_FrontBlock_SlabEdge", true, frontGlassLine, glassMinX, glassMaxX, upperSlabBottom, upperY, "Paint", {})
	wall(walls, "Glass_FrontBlock_Upper", true, frontGlassLine, glassMinX, glassMaxX, upperY, roofSlabBottom, "Glass", upperOpenings)
	wall(walls, "Wall_FrontBlock_RoofEdge", true, frontGlassLine, glassMinX, glassMaxX, roofSlabBottom, roofY, "Paint", {})
	-- Behind the corner rooms: a plain wall to the side blocks' front rooms.
	wall(walls, "Wall_FrontBlock_BackLeft", true, frontGlassLine, glassMaxX, cx + outerHalf, 0, roofY, "Paint", {})
	wall(walls, "Wall_FrontBlock_BackRight", true, frontGlassLine, cx - outerHalf, glassMinX, 0, roofY, "Paint", {})
	-- The lobby's side walls (ground floor).
	wall(walls, "Wall_Lobby_Left", false, cx + lobbyHalf, frontZ, blockBackZ, 0, upperSlabBottom, "Paint", {})
	wall(walls, "Wall_Lobby_Right", false, cx - lobbyHalf, frontZ, blockBackZ, 0, upperSlabBottom, "Paint", {})

	-- The corner rooms, both floors: a door into the next front room.
	local corners = {
		{ sign = 1, ground = cfg.Rooms.CornerGround.Left, upper = cfg.Rooms.CornerUpper.Left, label = "Left" },
		{ sign = -1, ground = cfg.Rooms.CornerGround.Right, upper = cfg.Rooms.CornerUpper.Right, label = "Right" },
	}
	for _, corner in ipairs(corners) do
		local dividerX = cx + corner.sign * (hallHalf + t / 2)
		local innerX, outerX = cx + corner.sign * (hallHalf + t), cx + corner.sign * outerHalf
		local minX, maxX = math.min(innerX, outerX), math.max(innerX, outerX)
		wall(walls, "Wall_Corner" .. corner.label, false, dividerX, frontZ, blockBackZ, 0, roofY, "Paint", {
			door(middleZ - doorWidth, floorY),
			door(middleZ + doorWidth, upperY),
		})
		room(rooms, corner.ground, 1, Vector3.new(minX, floorY, frontZ), Vector3.new(maxX, upperSlabBottom, blockBackZ),
			Vector3.new(dividerX, floorY + doorHeight / 2, middleZ - doorWidth), false)
		room(rooms, corner.upper, 2, Vector3.new(minX, upperY, frontZ), Vector3.new(maxX, roofSlabBottom, blockBackZ),
			Vector3.new(dividerX, upperY + doorHeight / 2, middleZ + doorWidth), false)
	end

	local skylights = buildRoof(roofs, plan)

	for name, value in pairs({
		HallMin = Vector3.new(cx - hallHalf, floorY, hallFrontZ),
		HallMax = Vector3.new(cx + hallHalf, floorY, hallBackZ),
		LobbyMin = Vector3.new(cx - lobbyHalf, floorY, frontZ),
		LobbyMax = Vector3.new(cx + lobbyHalf, floorY, blockBackZ),
	}) do
		model:SetAttribute(name, value)
	end
	return string.format(
		"hall X %.1f..%.1f, Z %.1f..%.1f; building X %.1f..%.1f, Z %.1f..%.1f; %d wall parts, %d rooms, hall roof with %d skylights",
		cx - hallHalf, cx + hallHalf, hallFrontZ, hallBackZ, outerMinX, outerMaxX, frontZ - t, hallBackZ + t,
		#walls:GetChildren(), #rooms:GetChildren(), skylights)
end

--[[
	Builds Workspace.StarterGym. Call once from the server entry point; later
	calls (or an existing StarterGym) leave everything as it is.
]]
function StarterGymBuilder.build(): Model?
	if built then
		warn("[StarterGymBuilder] build() was called again; ignored")
		return nil
	end
	built = true

	if Workspace:FindFirstChild(MODEL_NAME) ~= nil then
		warn("[StarterGymBuilder] Workspace." .. MODEL_NAME .. " already exists; nothing built, nothing changed")
		return nil
	end
	if TrainingStationConfig.GymLayout.facingDegrees ~= 0 then
		warn("[StarterGymBuilder] the gym only fits racks at facingDegrees 0 (entrance at -Z); nothing built")
		return nil
	end

	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	-- xpcall with a traceback, so a failure says exactly which line went wrong.
	local ok, result = xpcall(buildGym, debug.traceback, model)
	if not ok then
		model:Destroy()
		warn("[StarterGymBuilder] gym NOT built: " .. tostring(result))
		return nil
	end
	-- Parented only once complete, so nobody ever sees half a gym.
	model.Parent = Workspace
	print("[StarterGymBuilder] built: " .. result)
	return model
end

return StarterGymBuilder
