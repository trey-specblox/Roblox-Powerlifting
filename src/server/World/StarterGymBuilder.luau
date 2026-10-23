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
	STAGE 3:
	  Balcony the U-shaped walkway at the upper floor's level round the hall's
	          left, front and right sides, glass railing, steel columns.
	  Stairs  two glass staircases from the hall's front corners up to the
	          side balconies (upstairs is now reachable).
	STAGE 4:
	  Reception the reception desk and the gym-name wall in the lobby, and
	          the name sign outside above the entrance ("ELITE PREP GYM").
	  Doors   automatic sliding glass doors (2026-10-23) in the entrance and
	          in the lobby's opening into the hall, moved by the client's
	          AutoDoorAnimator.
	Later stages: lights.

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
	part.Reflectance = look.reflectance or 0
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

--[[
	A straight part from point `a` to point `b` (both in one vertical plane):
	`height` across the line, pointing up, and `thickness` out of the plane,
	raised `lift` above the line (negative = below it). For the stairs' sloped
	railings, handrails and stringers.
]]
local function between(parent: Instance, name: string, a: Vector3, b: Vector3, height: number, thickness: number,
	lift: number, look: StarterGymConfig.Look): BasePart
	local offset = b - a
	local length = offset.Magnitude
	local direction = offset / length
	local side = direction:Cross(Vector3.yAxis)
	side = if side.Magnitude < 1e-6 then Vector3.zAxis else side.Unit
	local up = side:Cross(direction).Unit
	if up.Y < 0 then
		up = -up
	end
	local centre = (a + b) / 2 + up * (lift + height / 2)
	return placed(parent, name, Vector3.new(length, height, thickness), CFrame.fromMatrix(centre, direction, up), look)
end

--[[
	STAGE 3: the balcony and the two glass staircases (GAME_DESIGN §27). The
	balcony is the upper floor's level carried round the hall's left, front and
	right sides, in front of every upstairs room, with a glass railing and steel
	columns under its inner edge. Each staircase starts in the hall's front
	area, runs toward its front corner just behind the front balcony, and lands
	on the side balcony. Returns the number of steps per staircase.
]]
local function buildBalconyAndStairs(model: Model, plan: StarterGymConfig.Footprint): number
	local cfg = StarterGymConfig
	local looks = cfg.Looks
	local cx, hallHalf = plan.centreX, plan.hallHalfWidth
	local floorY, upperY, slabBottom = plan.floorY, plan.upperFloorY, plan.upperSlabBottomY
	local depth = cfg.BalconyDepthStuds
	local frontEdgeZ = plan.hallFrontZ + depth -- the front balcony's inner edge
	local innerHalf = hallHalf - depth -- the side balconies' inner edge, from the middle
	local railHeight, railThickness, hand = cfg.RailingHeightStuds, cfg.RailingThicknessStuds, cfg.HandrailSizeStuds

	local stairZ0, stairZ1 = frontEdgeZ, frontEdgeZ + cfg.StairWidthStuds
	local steps = math.round((upperY - floorY) / cfg.StairStepRiseStuds)
	local rise = (upperY - floorY) / steps
	local bottomOffset, topOffset = hallHalf - cfg.StairBottomFromSideStuds, innerHalf
	assert(topOffset > bottomOffset, "the staircase has no length: StairBottomFromSideStuds must exceed BalconyDepthStuds")
	local run = (topOffset - bottomOffset) / steps

	local balcony = Instance.new("Folder")
	balcony.Name = "Balcony"
	balcony.Parent = model
	local stairs = Instance.new("Folder")
	stairs.Name = "Stairs"
	stairs.Parent = model

	-- The walkway, level with the upper floor.
	box(balcony, "Balcony_Front", Vector3.new(cx - hallHalf, slabBottom, plan.hallFrontZ),
		Vector3.new(cx + hallHalf, upperY, frontEdgeZ), looks.RoomFloor)
	box(balcony, "Balcony_Left", Vector3.new(cx + innerHalf, slabBottom, frontEdgeZ),
		Vector3.new(cx + hallHalf, upperY, plan.hallBackZ), looks.RoomFloor)
	box(balcony, "Balcony_Right", Vector3.new(cx - hallHalf, slabBottom, frontEdgeZ),
		Vector3.new(cx - innerHalf, upperY, plan.hallBackZ), looks.RoomFloor)

	-- A straight glass railing with a steel handrail on top, along the balcony's inner edge.
	local function railing(name: string, alongX: boolean, line: number, from: number, to: number)
		if to - from < 0.01 then
			return
		end
		local half = railThickness / 2
		local glassTop = upperY + railHeight - hand
		local function corners(low: number, high: number, halfWidth: number): (Vector3, Vector3)
			if alongX then
				return Vector3.new(from, low, line - halfWidth), Vector3.new(to, high, line + halfWidth)
			end
			return Vector3.new(line - halfWidth, low, from), Vector3.new(line + halfWidth, high, to)
		end
		local glassLow, glassHigh = corners(upperY, glassTop, half)
		box(balcony, name, glassLow, glassHigh, looks.Glass)
		local railLow, railHigh = corners(glassTop, upperY + railHeight, hand / 2)
		box(balcony, name .. "_Handrail", railLow, railHigh, looks.SteelBeam)
	end
	railing("Railing_Front", true, frontEdgeZ - railThickness / 2, cx - innerHalf, cx + innerHalf)
	for _, sign in ipairs({ 1, -1 }) do
		local label = if sign == 1 then "Left" else "Right"
		-- Open where the staircase lands (stairZ0..stairZ1), closed behind it.
		railing("Railing_" .. label, false, cx + sign * (innerHalf + railThickness / 2), stairZ1, plan.hallBackZ)
	end

	-- Steel columns under the inner edge: between the side rooms' doors, and
	-- under the front upper rooms' dividers.
	local column = cfg.ColumnSizeStuds
	local sideDepth = (plan.hallBackZ - plan.hallFrontZ) / 4
	for _, sign in ipairs({ 1, -1 }) do
		local label = if sign == 1 then "Left" else "Right"
		local x = cx + sign * (innerHalf + column / 2)
		for k = 1, 3 do
			local z = plan.hallFrontZ + k * sideDepth
			box(balcony, string.format("Column_%s_%d", label, k), Vector3.new(x - column / 2, floorY, z - column / 2),
				Vector3.new(x + column / 2, slabBottom, z + column / 2), looks.SteelBeam)
		end
		local frontX = cx + sign * hallHalf / 3
		box(balcony, "Column_Front_" .. label, Vector3.new(frontX - column / 2, floorY, frontEdgeZ - column),
			Vector3.new(frontX + column / 2, slabBottom, frontEdgeZ), looks.SteelBeam)
	end

	-- The two glass staircases.
	for _, sign in ipairs({ 1, -1 }) do
		local label = if sign == 1 then "Left" else "Right"
		for index = 1, steps do
			local a, b = cx + sign * (bottomOffset + (index - 1) * run), cx + sign * (bottomOffset + index * run)
			local top = floorY + index * rise
			local tread = box(stairs, string.format("Stairs_%s_Tread_%02d", label, index),
				Vector3.new(math.min(a, b), top - cfg.TreadThicknessStuds, stairZ0),
				Vector3.new(math.max(a, b), top, stairZ1), looks.StairGlass)
			-- The steps are only for looks: a character hops up separate steps, which
			-- felt choppy (user, 2026-10-21). They walk on the ramp below instead.
			tread.CanCollide = false
		end
		-- The steps' front edges, first to last: railings follow this line.
		local firstX = cx + sign * bottomOffset
		local lastX = cx + sign * (bottomOffset + (steps - 1) * run)

		--[[
			The walking surface: an invisible ramp whose top runs through every
			step's front edge, from the floor one step before the first step up
			to the top step's front edge (level with the balcony; the top step and
			the balcony are flat from there). It is solid, so raycasts and
			spatial queries still see it (Roblox only honours CanQuery = false on
			parts that are not solid); the verify script leaves it out where a
			ramp is meant to be walked on.
		]]
		local zMiddle = (stairZ0 + stairZ1) / 2
		local ramp = between(stairs, string.format("Stairs_%s_Ramp", label),
			Vector3.new(cx + sign * (bottomOffset - run), floorY, zMiddle), Vector3.new(lastX, upperY, zMiddle),
			1, stairZ1 - stairZ0, -1, looks.StairGlass)
		ramp.Transparency = 1
		ramp.CastShadow = false
		for _, edge in ipairs({ { name = "Front", z = stairZ0 + 0.3 }, { name = "Back", z = stairZ1 - 0.3 } }) do
			local a = Vector3.new(firstX, floorY + rise, edge.z)
			local b = Vector3.new(lastX, upperY, edge.z)
			local prefix = string.format("Stairs_%s_%s", label, edge.name)
			between(stairs, prefix .. "_Railing", a, b, railHeight - hand, railThickness, 0, looks.Glass)
			between(stairs, prefix .. "_Handrail", a, b, hand, hand, railHeight - hand, looks.SteelBeam)
			-- A steel stringer under the steps' ends.
			between(stairs, prefix .. "_Stringer", Vector3.new(firstX, floorY, edge.z),
				Vector3.new(cx + sign * topOffset, upperY - cfg.TreadThicknessStuds, edge.z), 0.8, 0.4, -0.8,
				looks.SteelBeam)
		end
	end

	return steps
end

-- True when every piece of an uploaded image (StarterGymConfig.ImagePiece) has its ID.
local function piecesReady(pieces: { StarterGymConfig.ImagePiece }): boolean
	if #pieces == 0 then
		return false
	end
	for _, piece in ipairs(pieces) do
		if piece.image == "" then
			return false
		end
	end
	return true
end

-- The pieces side by side in `frame`, left to right, each as wide as its share
-- of the picture, so together they fill the frame as one image.
local function addImagePieces(frame: GuiObject, pieces: { StarterGymConfig.ImagePiece })
	local totalPixels = 0
	for _, piece in ipairs(pieces) do
		totalPixels += piece.widthPixels
	end
	local before = 0
	for index, piece in ipairs(pieces) do
		local image = Instance.new("ImageLabel")
		image.Name = string.format("Piece_%d", index)
		image.Position = UDim2.fromScale(before / totalPixels, 0)
		image.Size = UDim2.fromScale(piece.widthPixels / totalPixels, 1)
		image.BackgroundTransparency = 1
		image.Image = piece.image
		image.ScaleType = Enum.ScaleType.Stretch
		image.Parent = frame
		before += piece.widthPixels
	end
end

--[[
	The gym's name on one face of a sign panel: big white letters with a short
	red line under them, over the panel's background art when it has any
	(`art`, `artHeightPixels` tall: at the panel's full height, in the middle,
	as wide as its shape allows up to the panel's width; the letters then get
	a black outline to stand out from it). The sign ignores the room's light
	(LightInfluence 0), so it stays readable in the dim lobby and at night.
]]
local function nameOnPanel(panel: BasePart, face: Enum.NormalId, text: string, art: { StarterGymConfig.ImagePiece }?,
	artHeightPixels: number?)
	local cfg = StarterGymConfig
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GymName"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = panel

	local hasArt = art ~= nil and artHeightPixels ~= nil and piecesReady(art)
	if art and artHeightPixels and hasArt then
		-- The face's size in studs: Left/Right faces run along Z, Front/Back along X.
		local width = if face == Enum.NormalId.Left or face == Enum.NormalId.Right then panel.Size.Z else panel.Size.X
		local artPixels = 0
		for _, piece in ipairs(art) do
			artPixels += piece.widthPixels
		end
		local artWidth = math.min(width, panel.Size.Y * artPixels / artHeightPixels)
		local background = Instance.new("Frame")
		background.Name = "Art"
		background.AnchorPoint = Vector2.new(0.5, 0.5)
		background.Position = UDim2.fromScale(0.5, 0.5)
		background.Size = UDim2.fromScale(artWidth / width, 1)
		background.BackgroundTransparency = 1
		background.ZIndex = 1
		background.Parent = gui
		addImagePieces(background, art)
	end

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.44)
	label.Size = UDim2.fromScale(0.88, 0.5)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = cfg.SignTextColor
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	label.ZIndex = 2
	label.Parent = gui
	if hasArt then
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.fromRGB(0, 0, 0)
		outline.Thickness = 3
		outline.Parent = label
	end

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.AnchorPoint = Vector2.new(0.5, 0.5)
	accent.Position = UDim2.fromScale(0.5, 0.8)
	accent.Size = UDim2.fromScale(0.3, 0.045)
	accent.BorderSizePixel = 0
	accent.BackgroundColor3 = cfg.SignAccentColor
	accent.ZIndex = 2
	accent.Parent = gui
end

--[[
	STAGE 4: the reception and the gym's name (GAME_DESIGN §27), styled after
	the Academia 2.0 reception photo the user picked. See StarterGymConfig for
	the list. The name wall stands on the lobby's left wall (+X, your left as
	you walk in), with the desk in front of it facing the middle of the lobby.
]]

-- A light-giving face on a part (SurfaceLight), in the gym's clean white.
local function surfaceLight(part: BasePart, face: Enum.NormalId, range: number, brightness: number, angle: number)
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Range = range
	light.Brightness = brightness
	light.Angle = angle
	light.Color = StarterGymConfig.LightColor
	light.Shadows = false
	light.Parent = part
end

-- Small decoration (items on shelves and desks, cables, turnstile arms): not
-- solid, so it never snags a player, and ignored by spatial checks.
local function decor(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part:SetAttribute("Decor", true)
	return part
end

-- The check-in screen on the reception monitor (facing the receptionist).
local function checkInScreen(screen: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CheckInScreen"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 0
	gui.Parent = screen
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BorderSizePixel = 0
	background.BackgroundColor3 = Color3.fromRGB(16, 24, 40)
	background.Parent = gui
	local function line(text: string, y: number, height: number, color: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.08, y)
		label.Size = UDim2.fromScale(0.84, height)
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
		label.Parent = background
	end
	line(StarterGymConfig.GymName, 0.1, 0.16, Color3.fromRGB(255, 255, 255))
	line("Member check-in", 0.32, 0.11, Color3.fromRGB(160, 175, 200))
	line("Ready", 0.62, 0.12, Color3.fromRGB(80, 220, 120))
end

--[[
	The desk's front: one picture covering the whole face (the user's logo and
	its background, drawn by art/scripts/build_desk_front.ps1), from the
	uploaded pieces in StarterGymConfig.DeskFrontPieces. Nothing is added
	(a plain white front) until every piece's image ID is set.
]]
local function deskFront(front: BasePart, face: Enum.NormalId)
	local cfg = StarterGymConfig
	if not piecesReady(cfg.DeskFrontPieces) then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DeskFront"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 0
	gui.Parent = front

	local picture = Instance.new("Frame")
	picture.Name = "Picture"
	picture.Size = UDim2.fromScale(1, 1)
	picture.BackgroundTransparency = 1
	picture.Parent = gui
	addImagePieces(picture, cfg.DeskFrontPieces)
end

--[[
	A sign that stands off its wall with a glowing halo behind it. `out` is the
	unit direction from the wall into the room or street; `face` is the sign
	face that points that way. The panel and halo are given by their centre,
	width (along the wall) and height.
]]
local function haloSign(parent: Instance, name: string, wallPoint: Vector3, out: Vector3, alongWall: Vector3,
	width: number, height: number, face: Enum.NormalId, art: { StarterGymConfig.ImagePiece }?,
	artHeightPixels: number?): BasePart
	local cfg = StarterGymConfig
	local function slab(partName: string, fromWall: number, toWall: number, w: number, h: number,
		look: StarterGymConfig.Look): BasePart
		local a = wallPoint + out * fromWall - alongWall * (w / 2) - Vector3.new(0, h / 2, 0)
		local b = wallPoint + out * toWall + alongWall * (w / 2) + Vector3.new(0, h / 2, 0)
		local low = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
		local high = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
		return box(parent, partName, low, high, look)
	end
	local halo = slab(name .. "_Halo", 0.05, cfg.SignStandOffStuds - 0.05, width + 2 * cfg.SignHaloStuds,
		height + 2 * cfg.SignHaloStuds, cfg.Looks.GlowWhite)
	local glow = Instance.new("PointLight")
	glow.Range = 10
	glow.Brightness = 1
	glow.Color = cfg.LightColor
	glow.Shadows = false
	glow.Parent = halo
	local panel = slab(name, cfg.SignStandOffStuds, cfg.SignStandOffStuds + cfg.SignThicknessStuds, width, height,
		cfg.Looks.SignPanel)
	nameOnPanel(panel, face, cfg.GymName, art, artHeightPixels)
	return panel
end

local function buildReception(model: Model, plan: StarterGymConfig.Footprint)
	local cfg = StarterGymConfig
	local looks = cfg.Looks
	local t = cfg.WallThicknessStuds
	local cx, floorY = plan.centreX, plan.floorY
	local lobbyHalf = plan.lobbyHalfWidth
	local lobbyFrontZ, lobbyBackZ = plan.frontZ, plan.hallFrontZ - t
	local ceilingY = plan.upperSlabBottomY
	local leftWallX, rightWallX = cx + lobbyHalf - t / 2, cx - lobbyHalf + t / 2 -- the lobby walls' inner faces

	local reception = Instance.new("Folder")
	reception.Name = "Reception"
	reception.Parent = model

	-- ---------------------------------------------------------------- the desk
	local deskZ = lobbyFrontZ + cfg.DeskCentreFromFrontStuds
	local z0, z1 = deskZ - cfg.DeskLengthStuds / 2, deskZ + cfg.DeskLengthStuds / 2
	local backX = leftWallX - cfg.DeskGapToWallStuds
	local frontX = backX - cfg.DeskDepthStuds -- the side customers stand at (-X)
	local counterY, workY = floorY + cfg.DeskCounterHeightStuds, floorY + cfg.DeskWorkHeightStuds

	-- A dark plinth set back under the desk, with a glowing strip along the front: the desk seems to float.
	box(reception, "Desk_Plinth", Vector3.new(frontX + 0.5, floorY, z0 + 0.3), Vector3.new(backX - 0.2, floorY + 0.3, z1 - 0.3),
		looks.DeskPlinth)
	local baseGlow = box(reception, "Desk_BaseGlow", Vector3.new(frontX + 0.45, floorY, z0 + 0.3),
		Vector3.new(frontX + 0.6, floorY + 0.25, z1 - 0.3), looks.GlowWhite)
	surfaceLight(baseGlow, Enum.NormalId.Left, 6, 1.5, 150)
	local frontPanel = box(reception, "Desk_Front", Vector3.new(frontX, floorY + 0.3, z0), Vector3.new(frontX + 0.6, counterY, z1),
		looks.DeskBody)
	deskFront(frontPanel, Enum.NormalId.Left) -- Left = -X, the customers' side
	box(reception, "Desk_Ledge", Vector3.new(frontX - 0.15, counterY, z0), Vector3.new(frontX + 1.4, counterY + 0.2, z1),
		looks.DeskBody)
	box(reception, "Desk_Cabinet", Vector3.new(frontX + 0.6, floorY + 0.3, z0 + 0.5), Vector3.new(backX, workY - 0.2, z1 - 0.5),
		looks.DeskBody)
	box(reception, "Desk_Work", Vector3.new(frontX + 0.6, workY - 0.2, z0), Vector3.new(backX + 0.3, workY, z1), looks.DeskWork)
	-- The end panels start behind the front panel: sharing its face made the picture flicker.
	box(reception, "Desk_End_1", Vector3.new(frontX + 0.6, floorY + 0.3, z0), Vector3.new(backX, counterY, z0 + 0.5),
		looks.DeskBody)
	box(reception, "Desk_End_2", Vector3.new(frontX + 0.6, floorY + 0.3, z1 - 0.5), Vector3.new(backX, counterY, z1),
		looks.DeskBody)

	-- On the desk: a monitor and keyboard for the receptionist, a card reader on the ledge.
	local m = deskZ - 3
	decor(box(reception, "Monitor_Base", Vector3.new(backX - 1.3, workY, m - 0.4), Vector3.new(backX - 0.5, workY + 0.08, m + 0.4),
		looks.Gadget))
	decor(box(reception, "Monitor_Neck", Vector3.new(backX - 1.0, workY, m - 0.08), Vector3.new(backX - 0.85, workY + 1.0, m + 0.08),
		looks.Gadget))
	local screen = decor(box(reception, "Monitor_Screen", Vector3.new(backX - 1.15, workY + 0.8, m - 1.2),
		Vector3.new(backX - 1.0, workY + 2.2, m + 1.2), looks.Gadget))
	checkInScreen(screen, Enum.NormalId.Right) -- Right = +X, toward the receptionist
	decor(box(reception, "Keyboard", Vector3.new(backX - 0.6, workY, m - 0.9), Vector3.new(backX - 0.25, workY + 0.07, m + 0.9),
		looks.Gadget))
	local reader = deskZ + 6
	decor(box(reception, "CardReader", Vector3.new(frontX + 0.1, counterY + 0.2, reader - 0.3),
		Vector3.new(frontX + 0.6, counterY + 0.35, reader + 0.3), looks.Gadget))
	decor(box(reception, "CardReader_Screen", Vector3.new(frontX + 0.2, counterY + 0.35, reader - 0.15),
		Vector3.new(frontX + 0.5, counterY + 0.37, reader + 0.15), looks.GlowGreen))

	-- A light bar hanging over the desk on two thin cables.
	local barX = frontX + 1.8
	local barY = counterY + 5.4
	local bar = box(reception, "Desk_LightBar", Vector3.new(barX - 0.2, barY, z0 + 2), Vector3.new(barX + 0.2, barY + 0.2, z1 - 2),
		looks.GlowWhite)
	surfaceLight(bar, Enum.NormalId.Bottom, 10, 1.3, 120)
	for index, z in ipairs({ z0 + 4, z1 - 4 }) do
		decor(box(reception, string.format("Desk_LightCable_%d", index), Vector3.new(barX - 0.04, barY + 0.2, z - 0.04),
			Vector3.new(barX + 0.04, ceilingY - 0.2, z + 0.04), looks.Stainless))
	end

	-- ---------------------------------------------------------------- the name wall
	-- As long as the desk, high enough to be seen over it.
	haloSign(reception, "NameWall",
		Vector3.new(leftWallX, floorY + cfg.NameWallBottomStuds + cfg.NameWallHeightStuds / 2, deskZ),
		-Vector3.xAxis, Vector3.zAxis, cfg.DeskLengthStuds, cfg.NameWallHeightStuds, Enum.NormalId.Left, cfg.NameSignArt,
		cfg.NameSignArtHeightPixels)

	-- ---------------------------------------------------------------- the ceiling and its lights
	box(reception, "Lobby_Ceiling", Vector3.new(rightWallX, ceilingY - 0.2, lobbyFrontZ), Vector3.new(leftWallX, ceilingY, lobbyBackZ),
		looks.Ceiling)
	local stripSpacing = 2 * lobbyHalf / cfg.CeilingStripCount
	for index = 1, cfg.CeilingStripCount do
		local x = cx - lobbyHalf + (index - 0.5) * stripSpacing
		local half = cfg.CeilingStripWidthStuds / 2
		local strip = decor(box(reception, string.format("Lobby_LightStrip_%d", index),
			Vector3.new(x - half, ceilingY - 0.3, lobbyFrontZ + 2), Vector3.new(x + half, ceilingY - 0.2, lobbyBackZ - 2),
			looks.GlowWhite))
		surfaceLight(strip, Enum.NormalId.Bottom, 16, 1, 160)
	end

	-- ---------------------------------------------------------------- the entrance gates
	-- Across the lobby, in front of the hall: a free middle lane, then per side
	-- turnstiles with lanes, then a railing to the wall (on the desk's side, to
	-- the desk's front, leaving the receptionist's way behind the desk open).
	local gateZ = lobbyBackZ - cfg.GateLineFromHallStuds
	local function railing(name: string, xa: number, xb: number)
		local x0, x1 = math.min(xa, xb), math.max(xa, xb)
		local posts = math.max(1, math.ceil((x1 - x0) / 6))
		for index = 0, posts do
			local x = x0 + (x1 - x0) * index / posts
			box(reception, string.format("%s_Post_%d", name, index), Vector3.new(x - 0.15, floorY, gateZ - 0.15),
				Vector3.new(x + 0.15, floorY + 3.4, gateZ + 0.15), looks.Stainless)
		end
		box(reception, name .. "_TopRail", Vector3.new(x0, floorY + 3.2, gateZ - 0.1), Vector3.new(x1, floorY + 3.4, gateZ + 0.1),
			looks.Stainless)
		box(reception, name .. "_MidRail", Vector3.new(x0, floorY + 1.6, gateZ - 0.08), Vector3.new(x1, floorY + 1.75, gateZ + 0.08),
			looks.Stainless)
	end
	for _, sign in ipairs({ 1, -1 }) do
		local label = if sign == 1 then "Left" else "Right"
		local offset = cfg.GateFreeLaneStuds / 2
		for index = 1, cfg.TurnstilesPerSide do
			local a, b = cx + sign * offset, cx + sign * (offset + 1)
			local x0, x1 = math.min(a, b), math.max(a, b)
			local prefix = string.format("Turnstile_%s_%d", label, index)
			box(reception, prefix, Vector3.new(x0, floorY, gateZ - 0.6), Vector3.new(x1, floorY + 3.2, gateZ + 0.6),
				looks.TurnstileBody)
			box(reception, prefix .. "_Cap", Vector3.new(x0 - 0.05, floorY + 3.2, gateZ - 0.65),
				Vector3.new(x1 + 0.05, floorY + 3.35, gateZ + 0.65), looks.Stainless)
			decor(box(reception, prefix .. "_Light", Vector3.new(x0 + 0.3, floorY + 3.35, gateZ - 0.15),
				Vector3.new(x1 - 0.3, floorY + 3.42, gateZ + 0.15), looks.GlowGreen))
			-- The arm reaches across its lane; it is not solid, so the lane is always open.
			local armA, armB = cx + sign * (offset + 1), cx + sign * (offset + 1 + cfg.GateLaneStuds - 0.6)
			decor(box(reception, prefix .. "_Arm", Vector3.new(math.min(armA, armB), floorY + 2.7, gateZ - 0.07),
				Vector3.new(math.max(armA, armB), floorY + 2.85, gateZ + 0.07), looks.Stainless))
			offset += 1 + cfg.GateLaneStuds
		end
		local railEnd = if sign == 1 then frontX - 0.5 else rightWallX
		railing("GateRailing_" .. label, cx + sign * offset, railEnd)
	end

	-- ---------------------------------------------------------------- the merch wall
	-- Opposite the desk: a dark back panel, three white shelves lit from below,
	-- shakers on top, folded shirts below.
	local merchZ = deskZ
	box(reception, "Merch_Back", Vector3.new(rightWallX, floorY + 2.5, merchZ - 7), Vector3.new(rightWallX + 0.2, floorY + 9.5, merchZ + 7),
		looks.SignPanel)
	local shirtLooks = { looks.ShirtBlack, looks.ShirtWhite, looks.ShirtRed }
	for shelf, height in ipairs({ 7.5, 5.5, 3.5 }) do
		local y = floorY + height
		box(reception, string.format("Merch_Shelf_%d", shelf), Vector3.new(rightWallX + 0.2, y, merchZ - 6),
			Vector3.new(rightWallX + 1.5, y + 0.2, merchZ + 6), looks.DeskBody)
		decor(box(reception, string.format("Merch_ShelfGlow_%d", shelf), Vector3.new(rightWallX + 0.3, y - 0.06, merchZ - 5.8),
			Vector3.new(rightWallX + 1.3, y, merchZ + 5.8), looks.GlowWhite))
		for item = 0, 5 do
			local z = merchZ - 5 + item * 2
			if shelf == 1 then
				-- A cylinder runs along its X axis, so it is turned upright.
				local shaker: any = decor(placed(reception, string.format("Merch_Shaker_%d", item + 1),
					Vector3.new(0.9, 0.45, 0.45), CFrame.new(rightWallX + 0.85, y + 0.2 + 0.45, z) * CFrame.Angles(0, 0, math.pi / 2),
					if item % 2 == 0 then looks.Gadget else looks.ShirtRed))
				shaker.Shape = Enum.PartType.Cylinder
			else
				for fold = 0, 2 do
					decor(box(reception, string.format("Merch_Shirt_%d_%d_%d", shelf, item + 1, fold + 1),
						Vector3.new(rightWallX + 0.35, y + 0.2 + fold * 0.3, z - 0.7),
						Vector3.new(rightWallX + 1.35, y + 0.2 + (fold + 1) * 0.3 - 0.02, z + 0.7),
						shirtLooks[(item + fold + shelf) % 3 + 1]))
				end
			end
		end
	end

	-- ---------------------------------------------------------------- outside
	-- The name sign on the front wall above the entrance, with its halo and two spotlights.
	local outsideZ = plan.frontZ - t
	local signY = floorY + cfg.FrontSignBottomStuds + cfg.FrontSignHeightStuds / 2
	haloSign(reception, "FrontSign", Vector3.new(cx, signY, outsideZ), -Vector3.zAxis, Vector3.xAxis,
		cfg.FrontSignWidthStuds, cfg.FrontSignHeightStuds, Enum.NormalId.Front, cfg.FrontSignArt,
		cfg.FrontSignArtHeightPixels)
	for index, x in ipairs({ cx - cfg.FrontSignWidthStuds / 4, cx + cfg.FrontSignWidthStuds / 4 }) do
		local lampY = signY + cfg.FrontSignHeightStuds / 2 + 1.4
		decor(box(reception, string.format("FrontSign_LampArm_%d", index), Vector3.new(x - 0.08, lampY - 0.08, outsideZ - 2.2),
			Vector3.new(x + 0.08, lampY + 0.08, outsideZ), looks.Stainless))
		-- Tilted so its bottom face looks down and back onto the sign.
		local lamp = decor(placed(reception, string.format("FrontSign_Lamp_%d", index), Vector3.new(0.8, 0.5, 0.8),
			CFrame.new(x, lampY, outsideZ - 2.4) * CFrame.Angles(math.rad(-35), 0, 0), looks.Gadget))
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 70
		spot.Range = 14
		spot.Brightness = 2
		spot.Color = cfg.LightColor
		spot.Parent = lamp
	end
end

--[[
	The automatic sliding doors (user, 2026-10-23: like the ones in stores),
	in the entrance and in the lobby's wide opening into the hall. Glass panels
	in aluminium frames close an opening in a glass wall, on one side of it.
	When someone comes near, the client's AutoDoorAnimator slides them apart
	behind the fixed glass (each panel model by its OpenOffset from its
	ClosedPivot). The invisible Sensor part is the zone that opens them; a steel
	header with a small sensor runs above them. Here, on the server, the panels
	always stay closed (and solid).

	`face` is the Z of the glass wall's face the doors stand in front of and
	`out` (+1 or -1) the direction from that face to the doors' side. With
	`perSide` panels per side, they telescope: each panel is on its own layer,
	and when open they all stack up just past the opening's edge.
]]
local function autoDoor(parent: Instance, name: string, centreX: number, floorY: number, face: number, out: number,
	width: number, height: number, perSide: number)
	local cfg = StarterGymConfig
	local looks = cfg.Looks
	local t = cfg.WallThicknessStuds
	local frame, thickness, overlap = cfg.DoorFrameStuds, cfg.DoorPanelThicknessStuds, cfg.DoorPanelOverlapStuds
	local topY = floorY + height
	local half = width / 2
	local step = half / perSide -- how much of the opening each panel closes
	local layerStuds = thickness + 0.12 -- panel layers: 0.08 between their frames
	-- A Vector3 at `x`, `y` and `d` studs out from the wall's face.
	local function at(x: number, y: number, d: number): Vector3
		return Vector3.new(x, y, face + out * d)
	end
	-- An axis-aligned part between two such corners (in any order).
	local function part(holder: Instance, partName: string, a: Vector3, b: Vector3, look: StarterGymConfig.Look): BasePart
		return box(holder, partName, a:Min(b), a:Max(b), look)
	end

	local door = Instance.new("Model")
	door.Name = name
	-- Sent to players as a whole, so a player's screen never moves half a door.
	door.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	door.Parent = parent

	-- The header the panels hang from (as long as the panels reach when open),
	-- with the sensor's small box and lamp under the middle of its outer edge.
	local headerHalf = half + step + overlap + 0.5
	local headerDepth = 0.85 + (perSide - 1) * layerStuds
	part(door, "Header", at(centreX - headerHalf, topY, 0.05), at(centreX + headerHalf, topY + 1.2, headerDepth), looks.DoorFrame)
	decor(part(door, "SensorBox", at(centreX - 0.6, topY - 0.3, headerDepth - 0.35), at(centreX + 0.6, topY, headerDepth),
		looks.Gadget))
	decor(part(door, "SensorLamp", at(centreX - 0.12, topY - 0.34, headerDepth - 0.23),
		at(centreX + 0.12, topY - 0.3, headerDepth - 0.11), looks.GlowRed))

	-- The zone that opens the doors: the opening and a little past its sides,
	-- DoorSensorReachStuds out on both sides of the wall.
	local reach, side = cfg.DoorSensorReachStuds, cfg.DoorSensorSideStuds
	local sensor = part(door, "Sensor", at(centreX - half - side, floorY, -t - reach), at(centreX + half + side, topY, reach),
		looks.Glass)
	sensor.Transparency = 1
	sensor.CanCollide = false
	sensor.CanQuery = false
	sensor.CastShadow = false

	local y0, y1 = floorY + 0.05, topY - 0.05
	for _, sign in ipairs({ 1, -1 }) do
		local label = if sign == 1 then "Left" else "Right"
		for index = 1, perSide do
			-- Panel 1 meets the other side's in the middle; the last one reaches behind the fixed glass.
			local inner = if index == 1 then 0.03 else (index - 1) * step
			local outer = index * step + overlap
			local function xs(a: number, b: number): (number, number)
				return centreX + sign * a, centreX + sign * b
			end
			local d0 = 0.15 + (index - 1) * layerStuds
			local d1 = d0 + thickness
			local panel = Instance.new("Model")
			panel.Name = if perSide == 1 then "Panel_" .. label else string.format("Panel_%s_%d", label, index)
			panel.Parent = door
			local xa, xb = xs(inner, outer)
			-- The glass sits inside its frame; the frame is a little thicker, so no faces are shared.
			local glass = part(panel, "Glass", at(math.min(xa, xb) + 0.1, y0 + 0.1, d0), at(math.max(xa, xb) - 0.1, y1 - 0.1, d1),
				looks.Glass)
			local f0, f1 = d0 - 0.02, d1 + 0.02
			decor(part(panel, "Frame_Top", at(xa, y1 - frame, f0), at(xb, y1, f1), looks.DoorFrame))
			decor(part(panel, "Frame_Bottom", at(xa, y0, f0), at(xb, y0 + frame, f1), looks.DoorFrame))
			local ma, mb = xs(inner, inner + frame)
			decor(part(panel, "Frame_Inner", at(ma, y0, f0), at(mb, y1, f1), looks.DoorFrame))
			local sa, sb = xs(outer - frame, outer)
			decor(part(panel, "Frame_Outer", at(sa, y0, f0), at(sb, y1, f1), looks.DoorFrame))

			panel.PrimaryPart = glass
			panel:SetAttribute("ClosedPivot", panel:GetPivot())
			-- Open: slid out until its inner edge is just past the opening's edge, behind the fixed glass.
			panel:SetAttribute("OpenOffset", Vector3.new(sign * (half + 0.2 - (index - 1) * step), 0, 0))
		end
	end

	door:AddTag(cfg.AutoDoorTag)
end

local function buildDoors(model: Model, plan: StarterGymConfig.Footprint)
	local cfg = StarterGymConfig
	local doors = Instance.new("Folder")
	doors.Name = "Doors"
	doors.Parent = model
	-- The entrance: on the lobby side (+Z) of the glass front.
	autoDoor(doors, "EntranceDoor", plan.centreX, plan.floorY, plan.frontZ, 1, cfg.EntranceWidthStuds,
		cfg.EntranceHeightStuds, cfg.EntranceDoorPanelsPerSide)
	-- The wide opening into the hall: on the lobby side (-Z) of the front block's glass.
	autoDoor(doors, "HallDoor", plan.centreX, plan.floorY, plan.hallFrontZ - cfg.WallThicknessStuds, -1,
		cfg.LobbyOpeningWidthStuds, cfg.LobbyOpeningHeightStuds, cfg.HallDoorPanelsPerSide)
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
	local steps = buildBalconyAndStairs(model, plan)
	buildReception(model, plan)
	buildDoors(model, plan)

	for name, value in pairs({
		HallMin = Vector3.new(cx - hallHalf, floorY, hallFrontZ),
		HallMax = Vector3.new(cx + hallHalf, floorY, hallBackZ),
		LobbyMin = Vector3.new(cx - lobbyHalf, floorY, frontZ),
		LobbyMax = Vector3.new(cx + lobbyHalf, floorY, blockBackZ),
	}) do
		model:SetAttribute(name, value)
	end
	return string.format(
		"hall X %.1f..%.1f, Z %.1f..%.1f; building X %.1f..%.1f, Z %.1f..%.1f; %d wall parts, %d rooms, roof with %d skylights, 2 glass staircases of %d steps",
		cx - hallHalf, cx + hallHalf, hallFrontZ, hallBackZ, outerMinX, outerMaxX, frontZ - t, hallBackZ + t,
		#walls:GetChildren(), #rooms:GetChildren(), skylights, steps)
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
