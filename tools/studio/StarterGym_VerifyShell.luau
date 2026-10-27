--[[
	StarterGym_VerifyShell  (TEMPORARY Command Bar script; version 2 building, 2026-10-21)

	READ-ONLY. Changes nothing. Checks the Starter Gym that StarterGymBuilder
	builds at server start (stage 1: floors, slabs, block roofs, walls, rooms).

	Run while PLAYING, in the Server OR the Client view.

	Checks:
	  - Workspace.StarterGym exists with Floors, Roofs, Walls and Rooms;
	    every floor, roof and wall part is anchored and solid;
	  - the ground floors' tops are at GymLayout.floorY (where the racks stand)
	    and the upper slabs' tops at the upper floor height;
	  - every configured rack, with its loaded bar and its lifting space in
	    front, lies on Floor_Hall and touches no wall;
	  - every room listed in StarterGymConfig.Rooms exists once, and its door
	    is open (no wall part in it);
	  - stage 3: the way out of every room's door is clear (no wall, railing,
	    column or stair in the 4 studs in front of it); both glass staircases
	    have every step, end level with the balcony, land on it with nothing in
	    the way, and can be stepped onto;
	  - stage 4: the gym's name is on the name wall and the outside sign; the
	    monitor's check-in screen and the reception lights exist; the desk
	    front picture (DeskFrontPieces) with no part sharing its face; the
	    back art (NameSignArt) on both name signs; no Glass material on walls
	    or windows (it hides the signs from outside); the way from
	    the entrance through the gates into the hall is clear; the spawn does
	    not overlap the reception;
	  - stage 2: the whole hall is under the roof (upward rays all hit it),
	    seen from above the whole building is the pitched roof (no flat roof
	    tops), and the skylights exist;
	  - the entrance is open, and every SpawnLocation stands in the lobby;
	  - the automatic sliding doors (2026-10-23) in the entrance and in the
	    lobby's opening into the hall: tagged, with a sensor; panels that fill
	    the opening when closed, and when open clear it, hit no wall or
	    reception part and do not run into each other;
	  - stage 5 (lighting): the Lighting service uses Future lighting, a
	    bright ambient and daytime; looking up in every room and under the
	    balcony you see a white ceiling (not tiles); every room but the lobby
	    has its light panel; the hall has all its light bars;
	  - step 6a (room furniture): every room whose furniture is built is
	    furnished, all furniture stays inside its room, and no solid piece
	    stands in front of a door (either side) or inside a wall;
	  - closed rooms (2026-10-26, GAME_DESIGN §27 "Closed rooms and the spa
	    wing"): every room facing the hall but the three shop windows and the
	    lobby shows a solid wall (rays from the hall), and has a real door; the
	    Cafe, Supplement Bar and Shop show glass; every room's swing door has
	    solid leaves that swing clear of its doorway; the Recovery & Spa wing
	    upstairs has one door from the balcony, no see-through spot, and its
	    rooms (Sauna, Recovery, Massage) off its corridor, away from the hall;
	  - the Strongman Shed (2026-10-26): its own building beside the gym, its
	    roller door open, no door into it from the gym, walled in, roofed and
	    furnished;
	  - themed room fronts (2026-10-26): each listed front is decorated, its
	    details stay along its wall within FrontDepthStuds, and nothing solid
	    stands in front of its door.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BAR_HALF_LENGTH = 4.95 -- the loaded bar reaches about 4.9 studs to each side
local TOLERANCE = 0.001

local lines = {}
local failures, passes = 0, 0

local function check(passed: boolean, label: string)
	if passed then
		passes += 1
	else
		failures += 1
	end
	table.insert(lines, (if passed then "  PASS  " else "  FAIL  ") .. label)
end

-- The lowest and highest corner of a part's box in the world, also when it is tilted.
local function bounds(part: BasePart): (Vector3, Vector3)
	local half = part.Size / 2
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, x in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
				low, high = low:Min(corner), high:Max(corner)
			end
		end
	end
	return low, high
end

local function run()
	if not RunService:IsRunning() then
		warn("[Starter Gym verify] Not run: press Play first (the gym is built when the server starts).")
		return
	end

	local config = ReplicatedStorage.Shared.Config
	local stationConfig = require(config.TrainingStationConfig)
	local layout, racks = stationConfig.GymLayout, stationConfig.GymRacks
	local gym = require(config.StarterGymConfig)
	local plan = gym.footprint(layout)

	local model = workspace:FindFirstChild("StarterGym")
	check(model ~= nil and model:IsA("Model"), "Workspace.StarterGym exists")
	if model == nil then
		return
	end
	local folders = {}
	for _, name in ipairs({ "Floors", "Roofs", "Walls", "Rooms", "Balcony", "Stairs", "Reception" }) do
		folders[name] = model:FindFirstChild(name)
	end
	local allFolders = folders.Floors and folders.Roofs and folders.Walls and folders.Rooms and folders.Balcony
		and folders.Stairs and folders.Reception
	check(allFolders ~= nil, "it has Floors, Roofs, Walls, Rooms, Balcony, Stairs and Reception")
	if not allFolders then
		return
	end

	-- Solid parts.
	local partCount, loose = 0, 0
	for _, f in ipairs({ folders.Floors, folders.Roofs, folders.Walls, folders.Balcony, folders.Stairs, folders.Reception }) do
		for _, d in ipairs(f:GetDescendants()) do
			-- The glass steps are for looks only (players walk on the stairs' ramps), and
			-- small decoration (attribute Decor: shelf items, cables, turnstile arms) is not solid on purpose.
			if d:IsA("BasePart") and not string.find(d.Name, "_Tread_", 1, true) and d:GetAttribute("Decor") ~= true then
				partCount += 1
				if not (d.Anchored and d.CanCollide) then
					loose += 1
				end
			end
		end
	end
	check(loose == 0, string.format("all %d floor, roof and wall parts anchored and solid (%d not)", partCount, loose))

	-- Floor heights.
	local wrongHeight = {}
	for _, part in ipairs(folders.Floors:GetChildren()) do
		if part:IsA("BasePart") then
			local _, high = bounds(part)
			local expected = if string.sub(part.Name, 1, 5) == "Slab_" then plan.upperFloorY else layout.floorY
			if math.abs(high.Y - expected) > TOLERANCE then
				table.insert(wrongHeight, string.format("%s at %.3f (expected %.3f)", part.Name, high.Y, expected))
			end
		end
	end
	check(#wrongHeight == 0, string.format("ground floors at Y %.2f, upper floors at Y %.2f%s", layout.floorY,
		plan.upperFloorY, if #wrongHeight > 0 then " (" .. table.concat(wrongHeight, "; ") .. ")" else ""))

	-- "Walls" here means anything a player could bump into: walls, the balcony
	-- (railings, columns) and the stairs.
	local wallParams = OverlapParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Include
	wallParams.FilterDescendantsInstances = { folders.Walls, folders.Balcony, folders.Stairs, folders.Reception }
	-- The same without the stairs' ramps: a ramp is the way ONTO its stairs, not in the way.
	local notRamps: { Instance } = { folders.Walls, folders.Balcony, folders.Reception }
	for _, part in ipairs(folders.Stairs:GetChildren()) do
		if string.sub(part.Name, -5) ~= "_Ramp" then
			table.insert(notRamps, part)
		end
	end
	local noRampParams = OverlapParams.new()
	noRampParams.FilterType = Enum.RaycastFilterType.Include
	noRampParams.FilterDescendantsInstances = notRamps
	local function wallsIn(low: Vector3, high: Vector3, params: OverlapParams?): { string }
		local names = {}
		for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new((low + high) / 2), high - low, params or wallParams)) do
			table.insert(names, part.Name)
		end
		return names
	end

	-- Racks: on the hall floor and clear of every wall.
	local hallFloor = folders.Floors:FindFirstChild("Floor_Hall") :: BasePart?
	check(hallFloor ~= nil, "Floor_Hall exists")
	if hallFloor then
		local floorLow, floorHigh = bounds(hallFloor)
		local outside, blocked = {}, {}
		for _, entry in ipairs(racks) do
			local p = entry.position
			local low = Vector3.new(p.X - BAR_HALF_LENGTH, p.Y + 0.2, p.Z - gym.RackFrontClearanceStuds)
			local high = Vector3.new(p.X + BAR_HALF_LENGTH, p.Y + 8, p.Z + gym.RackBackReachStuds)
			if low.X < floorLow.X or high.X > floorHigh.X or low.Z < floorLow.Z or high.Z > floorHigh.Z then
				table.insert(outside, entry.stationId)
			end
			local hits = wallsIn(low, high)
			if #hits > 0 then
				table.insert(blocked, entry.stationId .. " (" .. table.concat(hits, ", ") .. ")")
			end
		end
		check(#outside == 0, string.format("all %d racks with bar and lifting space on Floor_Hall%s", #racks,
			if #outside > 0 then " (outside: " .. table.concat(outside, ", ") .. ")" else ""))
		check(#blocked == 0, string.format("no rack space touches a wall%s",
			if #blocked > 0 then " (" .. table.concat(blocked, "; ") .. ")" else ""))
	end

	-- Rooms: each listed once, each doorway open (no wall part in it).
	-- A name listed twice in a block is one room across both places.
	local expected = gym.roomNames()
	local missing, doubled, shut = {}, {}, {}
	local thickness = gym.WallThicknessStuds
	local halfDoor = gym.RoomDoorWidthStuds / 2 - 0.1
	local halfHeight = gym.RoomDoorHeightStuds / 2 - 0.2
	for _, name in ipairs(expected) do
		local found = {}
		for _, child in ipairs(folders.Rooms:GetChildren()) do
			if child.Name == "Room_" .. name then
				table.insert(found, child)
			end
		end
		if #found == 0 then
			table.insert(missing, name)
		elseif #found > 1 then
			table.insert(doubled, name)
		else
			local centre = found[1]:GetAttribute("DoorCentre")
			local alongX = found[1]:GetAttribute("DoorAlongX")
			if typeof(centre) ~= "Vector3" or typeof(alongX) ~= "boolean" then
				table.insert(shut, name .. " (no door attributes)")
			else
				local half = if alongX
					then Vector3.new(halfDoor, halfHeight, thickness / 2)
					else Vector3.new(thickness / 2, halfHeight, halfDoor)
				local hits = wallsIn(centre - half, centre + half)
				if #hits > 0 then
					table.insert(shut, name .. " (" .. table.concat(hits, ", ") .. ")")
				end
			end
		end
	end
	check(#missing == 0 and #doubled == 0, string.format("all %d rooms exist once%s%s", #expected,
		if #missing > 0 then " (missing: " .. table.concat(missing, ", ") .. ")" else "",
		if #doubled > 0 then " (twice: " .. table.concat(doubled, ", ") .. ")" else ""))
	check(#shut == 0, string.format("every room's door is open%s",
		if #shut > 0 then " (blocked: " .. table.concat(shut, "; ") .. ")" else ""))

	-- Stage 3 (user: the rooms behind the staircases must stay reachable): the
	-- 4 studs in front of every door, on the hall side, are clear of walls,
	-- the balcony's railings and columns, and the stairs.
	local blockedFront = {}
	for _, room in ipairs(folders.Rooms:GetChildren()) do
		local centre = room:GetAttribute("DoorCentre")
		local alongX = room:GetAttribute("DoorAlongX")
		if typeof(centre) == "Vector3" and typeof(alongX) == "boolean" then
			-- Doors in the front block's glass face the hall (+Z); the others face the middle.
			local outward = if alongX then Vector3.zAxis else Vector3.new(math.sign(plan.centreX - centre.X), 0, 0)
			local across = if alongX then Vector3.xAxis else Vector3.zAxis
			local nearPoint = centre + outward * (thickness / 2 + 0.05)
			local farPoint = centre + outward * (thickness / 2 + 4)
			local spread = across * halfDoor + Vector3.new(0, halfHeight, 0)
			local a, b = nearPoint - spread, farPoint + spread
			local low = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
			local high = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
			local hits = wallsIn(low, high)
			if #hits > 0 then
				table.insert(blockedFront, room.Name .. " (" .. table.concat(hits, ", ") .. ")")
			end
		end
	end
	check(#blockedFront == 0, string.format("the way out of every room's door is clear%s",
		if #blockedFront > 0 then " (blocked: " .. table.concat(blockedFront, "; ") .. ")" else ""))

	-- The staircases: all steps there, the top step level with the balcony,
	-- the landing onto the balcony open, and the way onto the first step clear.
	local steps = math.round((plan.upperFloorY - plan.floorY) / gym.StairStepRiseStuds)
	local treads, topOk = 0, 0
	for _, part in ipairs(folders.Stairs:GetChildren()) do
		if part:IsA("BasePart") and string.find(part.Name, "_Tread_", 1, true) then
			treads += 1
			local _, high = bounds(part)
			if math.abs(high.Y - plan.upperFloorY) <= 0.01 then
				topOk += 1
			end
		end
	end
	check(treads == 2 * steps and topOk == 2, string.format(
		"2 staircases of %d glass steps, top steps level with the balcony (%d steps, %d level)", steps, treads, topOk))

	-- Smooth stairs (user, 2026-10-21): the steps do not collide; each staircase
	-- has one solid, invisible ramp from the floor up to the balcony's level.
	local solidTreads, ramps, goodRamps = 0, 0, 0
	for _, part in ipairs(folders.Stairs:GetChildren()) do
		if part:IsA("BasePart") then
			if string.find(part.Name, "_Tread_", 1, true) and part.CanCollide then
				solidTreads += 1
			elseif string.sub(part.Name, -5) == "_Ramp" then
				ramps += 1
				local low, high = bounds(part)
				if part.CanCollide and part.Transparency >= 1 and math.abs(high.Y - plan.upperFloorY) <= 0.05
					and low.Y <= plan.floorY then
					goodRamps += 1
				end
			end
		end
	end
	check(solidTreads == 0 and ramps == 2 and goodRamps == 2, string.format(
		"smooth stairs: steps not solid (%d solid), 2 invisible solid ramps from the floor to the balcony (%d found, %d right)",
		solidTreads, ramps, goodRamps))
	local stairZ0 = plan.hallFrontZ + gym.BalconyDepthStuds
	local stairZ1 = stairZ0 + gym.StairWidthStuds
	local innerHalf = plan.hallHalfWidth - gym.BalconyDepthStuds
	local bottomOffset = plan.hallHalfWidth - gym.StairBottomFromSideStuds
	for _, sign in ipairs({ 1, -1 }) do
		local label = if sign == 1 then "left" else "right"
		local function span(o1: number, o2: number): (number, number)
			local x1, x2 = plan.centreX + sign * o1, plan.centreX + sign * o2
			return math.min(x1, x2), math.max(x1, x2)
		end
		local landX0, landX1 = span(innerHalf - 0.6, innerHalf + 0.6)
		local landing = wallsIn(Vector3.new(landX0, plan.upperFloorY + 0.3, stairZ0 + 0.6),
			Vector3.new(landX1, plan.upperFloorY + 3, stairZ1 - 0.6))
		check(#landing == 0, string.format("%s staircase lands on the balcony with nothing in the way%s", label,
			if #landing > 0 then " (" .. table.concat(landing, ", ") .. ")" else ""))
		local footX0, footX1 = span(bottomOffset - 4, bottomOffset - 0.1)
		local foot = wallsIn(Vector3.new(footX0, layout.floorY + 0.3, stairZ0 + 0.6),
			Vector3.new(footX1, layout.floorY + 5, stairZ1 - 0.6), noRampParams)
		check(#foot == 0, string.format("the way onto the %s staircase's first step is clear%s", label,
			if #foot > 0 then " (" .. table.concat(foot, ", ") .. ")" else ""))
	end

	-- Stage 2: the hall is roofed. Rays straight up from a grid over the hall
	-- floor must all hit the roof (solid roof, skylight glass or a beam), so no
	-- part of the hall is open to the sky; the skylights must exist.
	local roofParams = RaycastParams.new()
	roofParams.FilterType = Enum.RaycastFilterType.Include
	roofParams.FilterDescendantsInstances = { folders.Roofs }
	local open, rays = 0, 0
	for i = 0, 9 do
		for j = 0, 5 do
			local x = plan.hallMinX + (i + 0.5) * (plan.hallMaxX - plan.hallMinX) / 10
			local z = plan.hallFrontZ + (j + 0.5) * (plan.hallBackZ - plan.hallFrontZ) / 6
			rays += 1
			if workspace:Raycast(Vector3.new(x, layout.floorY + 2, z), Vector3.new(0, 80, 0), roofParams) == nil then
				open += 1
			end
		end
	end
	check(open == 0, string.format("hall roofed: %d of %d upward rays hit the roof (%d open to the sky)", rays - open, rays, open))
	-- One pitched roof over EVERYTHING (user, 2026-10-21: no flat roof tops):
	-- rays straight down over the whole building must all first hit a Roof_ part.
	local topParams = RaycastParams.new()
	topParams.FilterType = Enum.RaycastFilterType.Include
	topParams.FilterDescendantsInstances = { model }
	local outerHalf = plan.outerHalfWidth
	local backZ = plan.hallBackZ
	local notRoof, downRays = {}, 0
	for i = 0, 11 do
		for j = 0, 7 do
			local x = plan.centreX - outerHalf + (i + 0.5) * (2 * outerHalf) / 12
			local z = plan.frontZ + (j + 0.5) * (backZ - plan.frontZ) / 8
			downRays += 1
			local hit = workspace:Raycast(Vector3.new(x, 150, z), Vector3.new(0, -160, 0), topParams)
			if hit == nil or string.sub(hit.Instance.Name, 1, 5) ~= "Roof_" then
				table.insert(notRoof, string.format("(%.0f, %.0f) %s", x, z, if hit then hit.Instance.Name else "nothing"))
			end
		end
	end
	check(#notRoof == 0, string.format("seen from above, all %d spots are the pitched roof%s", downRays,
		if #notRoof > 0 then " (not roof: " .. table.concat(notRoof, "; ", 1, math.min(#notRoof, 6)) .. ")" else ""))

	local skylights = 0
	for _, d in ipairs(folders.Roofs:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "_Skylight_", 1, true) then
			skylights += 1
		end
	end
	check(skylights == 2 * gym.SkylightsPerSlope, string.format("%d skylights (expected %d)", skylights,
		2 * gym.SkylightsPerSlope))

	-- The entrance, in the lobby's glass front.
	local halfEntrance = gym.EntranceWidthStuds / 2 - 0.1
	local entranceHits = wallsIn(
		Vector3.new(plan.centreX - halfEntrance, layout.floorY + 0.2, plan.frontZ - thickness),
		Vector3.new(plan.centreX + halfEntrance, layout.floorY + gym.EntranceHeightStuds - 0.2, plan.frontZ))
	check(#entranceHits == 0, string.format("entrance open (%g wide, %g high)%s", gym.EntranceWidthStuds,
		gym.EntranceHeightStuds, if #entranceHits > 0 then " (blocked by " .. table.concat(entranceHits, ", ") .. ")" else ""))

	-- The automatic sliding doors (2026-10-23), in the entrance and the hall
	-- opening. Worked out from each panel's ClosedPivot and OpenOffset, so it
	-- does not matter whether a door is open on this screen right now.
	local doorsFolder = model:FindFirstChild("Doors")
	for _, spec in ipairs({
		{ name = "EntranceDoor", width = gym.EntranceWidthStuds, panels = 2 * gym.EntranceDoorPanelsPerSide },
		{ name = "HallDoor", width = gym.LobbyOpeningWidthStuds, panels = 2 * gym.HallDoorPanelsPerSide },
	}) do
		local door = doorsFolder and doorsFolder:FindFirstChild(spec.name)
		check(door ~= nil and door:IsA("Model") and door:HasTag(gym.AutoDoorTag),
			string.format("Doors.%s exists and is tagged %s", spec.name, gym.AutoDoorTag))
		if door then
			local sensor = door:FindFirstChild("Sensor")
			check(sensor ~= nil and sensor:IsA("BasePart") and sensor.Transparency >= 1 and not sensor.CanCollide
				and sensor.Size.Z >= 2 * gym.DoorSensorReachStuds,
				spec.name .. "'s sensor is invisible, not solid, and reaches out on both sides")
			local entranceMin = plan.centreX - spec.width / 2
			local entranceMax = plan.centreX + spec.width / 2
			local panels, good, problems = 0, 0, {}
			local covered, openBoxes = {}, {}
			for _, panel in ipairs(door:GetChildren()) do
				if panel:IsA("Model") then
					panels += 1
					local closed = panel:GetAttribute("ClosedPivot")
					local offset = panel:GetAttribute("OpenOffset")
					local glass = panel.PrimaryPart
					if typeof(closed) ~= "CFrame" or typeof(offset) ~= "Vector3" or glass == nil then
						table.insert(problems, panel.Name .. ": no ClosedPivot / OpenOffset / glass")
					elseif not (glass.Anchored and glass.CanCollide) then
						table.insert(problems, panel.Name .. ": glass not anchored and solid")
					else
						-- Every part of the panel where it is when closed, and when open.
						local shift = closed.Position - panel:GetPivot().Position
						local closedLow, closedHigh = Vector3.one * math.huge, -Vector3.one * math.huge
						for _, part in ipairs(panel:GetDescendants()) do
							if part:IsA("BasePart") then
								local low, high = bounds(part)
								closedLow, closedHigh = closedLow:Min(low + shift), closedHigh:Max(high + shift)
							end
						end
						table.insert(covered, { closedLow.X, closedHigh.X })
						local openLow, openHigh = closedLow + offset, closedHigh + offset
						local inEntrance = openHigh.X > entranceMin + 0.01 and openLow.X < entranceMax - 0.01
						local hits = wallsIn(openLow, openHigh)
						-- Panels that slide over each other must be on different layers.
						local through = {}
						for _, other in ipairs(openBoxes) do
							local lo, hi = openLow:Max(other.low), openHigh:Min(other.high)
							if hi.X - lo.X > 0.01 and hi.Y - lo.Y > 0.01 and hi.Z - lo.Z > 0.01 then
								table.insert(through, other.name)
							end
						end
						table.insert(openBoxes, { name = panel.Name, low = openLow, high = openHigh })
						if inEntrance then
							table.insert(problems, panel.Name .. ": still in the opening when open")
						elseif #hits > 0 then
							table.insert(problems, panel.Name .. " hits " .. table.concat(hits, ", ") .. " when open")
						elseif #through > 0 then
							table.insert(problems, panel.Name .. " runs into " .. table.concat(through, ", ") .. " when open")
						else
							good += 1
						end
					end
				end
			end
			-- Closed, the panels together cover the opening (only a thin gap where they meet).
			table.sort(covered, function(a, b)
				return a[1] < b[1]
			end)
			local reach, gaps = entranceMin, 0
			for _, range in ipairs(covered) do
				if range[1] - reach > 0.1 then
					gaps += 1
				end
				reach = math.max(reach, range[2])
			end
			local doorsShut = #covered > 0 and gaps == 0 and reach >= entranceMax
			check(panels == spec.panels and good == spec.panels and doorsShut, string.format(
				"%s: %d sliding panels; closed they fill the %g-stud opening, open they clear it and hit nothing (%d found, %d right%s)",
				spec.name, spec.panels, spec.width, panels, good,
				if #problems > 0 then "; " .. table.concat(problems, "; ") elseif not doorsShut then "; not closed" else ""))
		end
	end

	-- Real swing doors (the sauna, 2026-10-23; double doors and the lockers'
	-- door 2026-10-25; every closed room 2026-10-26, gym.swingDoorFor): tagged,
	-- a sensor, the spec's number of solid panels hinged at their pivots;
	-- turned to their OpenPivots, they leave the middle of the door gap clear.
	local swingDoorCount, badSwingDoors = 0, {}
	for _, roomPart in ipairs(folders.Rooms:GetChildren()) do
		local roomName = string.sub(roomPart.Name, 6)
		local spec = gym.swingDoorFor(roomName)
		if spec == nil then
			continue
		end
		swingDoorCount += 1
		local door = doorsFolder and doorsFolder:FindFirstChild(roomName .. "Door")
		local panels = {}
		if door then
			for _, child in ipairs(door:GetChildren()) do
				if child:IsA("Model") then
					table.insert(panels, child)
				end
			end
		end
		local sensor = door and door:FindFirstChild("Sensor")
		local room = roomPart
		local fine, problem = false, string.format("missing door, sensor or room, or not %d panels", spec.leaves)
		if door and door:HasTag(gym.AutoDoorTag) and #panels == spec.leaves and sensor and sensor:IsA("BasePart")
			and not sensor.CanCollide and room then
			local centre, alongX = room:GetAttribute("DoorCentre"), room:GetAttribute("DoorAlongX")
			if typeof(centre) ~= "Vector3" then
				problem = "the room has no DoorCentre"
			else
				local solidPanel, blocking, noPivot = true, {}, false
				local band = if alongX then Vector3.new(1.2, 3.5, 0.5) else Vector3.new(0.5, 3.5, 1.2)
				local bandLow = centre - band + Vector3.new(0, 0.1, 0)
				local bandHigh = centre + band + Vector3.new(0, 0.1, 0)
				for _, panel in ipairs(panels) do
					local closed, openPivot = panel:GetAttribute("ClosedPivot"), panel:GetAttribute("OpenPivot")
					if typeof(closed) ~= "CFrame" or typeof(openPivot) ~= "CFrame" then
						noPivot = true
						continue
					end
					-- Every panel part where it is when open (worked out, not read from this screen).
					local pivot = panel:GetPivot()
					for _, part in ipairs(panel:GetDescendants()) do
						if part:IsA("BasePart") then
							if part:GetAttribute("Decor") ~= true and not (part.Anchored and part.CanCollide) then
								solidPanel = false
							end
							local openFrame = openPivot * pivot:ToObjectSpace(part.CFrame)
							local half = part.Size / 2
							local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
							for _, x in ipairs({ -1, 1 }) do
								for _, y in ipairs({ -1, 1 }) do
									for _, z in ipairs({ -1, 1 }) do
										local corner = openFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
										low, high = low:Min(corner), high:Max(corner)
									end
								end
							end
							if low.X < bandHigh.X and high.X > bandLow.X and low.Y < bandHigh.Y and high.Y > bandLow.Y
								and low.Z < bandHigh.Z and high.Z > bandLow.Z then
								table.insert(blocking, panel.Name .. "." .. part.Name)
							end
						end
					end
				end
				fine = not noPivot and solidPanel and #blocking == 0
				problem = if noPivot then "a panel has no ClosedPivot / OpenPivot"
					elseif not solidPanel then "panel not solid"
					else "open door still in the gap: " .. table.concat(blocking, ", ")
			end
		end
		if not fine then
			table.insert(badSwingDoors, string.format("%sDoor: %s", roomName, problem))
		end
	end
	local lockersDoor = gym.swingDoorFor("Lockers")
	check(#badSwingDoors == 0 and swingDoorCount >= 15 and lockersDoor ~= nil and gym.swingDoorFor("Sauna") ~= nil,
		string.format("%d rooms have real doors (solid leaves that swing clear of the doorway, sensor, tag)%s",
			swingDoorCount, if #badSwingDoors > 0 then " (" .. table.concat(badSwingDoors, "; ") .. ")" else ""))

	-- Closed rooms (user 2026-10-25 the lockers, 2026-10-26 every room but the
	-- shops): looking from the hall at any room's wall, beside its doorway and
	-- above it, the first wall part you meet is solid paint, except the
	-- GlassFrontRooms (and the lobby), which show glass. Rays every 2 studs,
	-- from 3 studs out in the hall (or over the balcony) toward the room.
	local wallRays = RaycastParams.new()
	wallRays.FilterType = Enum.RaycastFilterType.Include
	wallRays.FilterDescendantsInstances = { folders.Walls }
	local lobbyName = "Room_" .. gym.Rooms.FrontGround[2]
	local seeInto, notGlass, noDoor, closedCount, glassCount = {}, {}, {}, 0, 0
	for _, roomPart in ipairs(folders.Rooms:GetChildren()) do
		if not roomPart:IsA("BasePart") or roomPart.Name == lobbyName then
			continue
		end
		local roomName = string.sub(roomPart.Name, 6)
		local low, high = bounds(roomPart)
		-- Which side of the room faces the hall (its edge within 1.5 of the hall's).
		local inward: Vector3?, faceLine, alongX = nil, 0, false
		if math.abs(low.X - plan.hallMaxX) <= 1.5 and high.Z > plan.hallFrontZ then
			inward, faceLine = Vector3.xAxis, plan.hallMaxX
		elseif math.abs(high.X - plan.hallMinX) <= 1.5 and high.Z > plan.hallFrontZ then
			inward, faceLine = -Vector3.xAxis, plan.hallMinX
		elseif math.abs(high.Z - plan.hallFrontZ) <= 1.5 and low.X < plan.hallMaxX and high.X > plan.hallMinX then
			inward, faceLine, alongX = -Vector3.zAxis, plan.hallFrontZ, true
		end
		if inward == nil then
			continue
		end
		local glass = gym.GlassFrontRooms[roomName] == true
		if glass then
			glassCount += 1
		else
			closedCount += 1
			if gym.swingDoorFor(roomName) == nil then
				table.insert(noDoor, roomName)
			end
		end
		local door = roomPart:GetAttribute("DoorCentre") :: Vector3
		local from = if alongX then math.max(low.X, plan.hallMinX) else math.max(low.Z, plan.hallFrontZ)
		local to = if alongX then math.min(high.X, plan.hallMaxX) else math.min(high.Z, plan.hallBackZ)
		local doorAt = if alongX then door.X else door.Z
		local bad = 0
		local s = from + 1
		while s <= to - 1 do
			for _, height in ipairs({ 2, 6, 11 }) do
				local inDoorway = math.abs(s - doorAt) < 4.5 and height < 10
				if not inDoorway then
					local y = low.Y + height
					local origin = if alongX then Vector3.new(s, y, faceLine) else Vector3.new(faceLine, y, s)
					origin -= inward * 3
					local hit = workspace:Raycast(origin, inward * 6, wallRays)
					local opaque = hit ~= nil and hit.Instance.Transparency < 0.05
					local clear = hit ~= nil and hit.Instance.Transparency > 0.3
					if (glass and not clear) or (not glass and not opaque) then
						bad += 1
					end
				end
			end
			s += 2
		end
		if bad > 0 then
			table.insert(if glass then notGlass else seeInto, string.format("%s (%d spots)", roomName, bad))
		end
	end
	check(#seeInto == 0 and #noDoor == 0 and closedCount >= 12, string.format(
		"%d closed rooms: no seeing in from the hall, each with a real door%s%s", closedCount,
		if #seeInto > 0 then " (see-through: " .. table.concat(seeInto, ", ") .. ")" else "",
		if #noDoor > 0 then " (no door: " .. table.concat(noDoor, ", ") .. ")" else ""))
	check(#notGlass == 0 and glassCount == 3, string.format("%d shop-window rooms keep their glass fronts (expected 3)%s",
		glassCount, if #notGlass > 0 then " (not glass: " .. table.concat(notGlass, ", ") .. ")" else ""))

	-- The Recovery & Spa wing (2026-10-26): along its whole wall onto the hall,
	-- rays from the balcony find one way in (the reception's door) and nothing
	-- see-through; its rooms upstairs, away from the hall wall, their doors in
	-- the corridor wall.
	local wing = gym.SpaWing
	local reception = folders.Rooms:FindFirstChild("Room_" .. wing.reception) :: BasePart?
	if reception then
		local low = bounds(reception)
		local side = if math.abs(low.X - plan.hallMaxX) <= 1.5 then 1 else -1
		local faceLine = if side == 1 then plan.hallMaxX else plan.hallMinX
		local inward = Vector3.new(side, 0, 0)
		local openings, seeThrough, inGap = 0, 0, false
		local z = plan.hallFrontZ + 0.5
		while z <= plan.hallBackZ - 0.5 do
			local lowHit = workspace:Raycast(Vector3.new(faceLine, low.Y + 4, z) - inward * 3, inward * 6, wallRays)
			local highHit = workspace:Raycast(Vector3.new(faceLine, low.Y + 11, z) - inward * 3, inward * 6, wallRays)
			if lowHit == nil and not inGap then
				openings += 1
			end
			inGap = lowHit == nil
			if (lowHit and lowHit.Instance.Transparency > 0.05) or highHit == nil or highHit.Instance.Transparency > 0.05 then
				seeThrough += 1
			end
			z += 0.5
		end
		local wrong = {}
		for _, wingRoom in ipairs(wing.rooms) do
			local part = folders.Rooms:FindFirstChild("Room_" .. wingRoom.name) :: BasePart?
			if part == nil then
				table.insert(wrong, wingRoom.name .. " missing")
			else
				local roomLow, roomHigh = bounds(part)
				local door = part:GetAttribute("DoorCentre") :: Vector3
				local fromHall = if side == 1 then roomLow.X - plan.hallMaxX else plan.hallMinX - roomHigh.X
				if part:GetAttribute("Floor") ~= 2 or fromHall < wing.corridorWidthStuds - 0.5
					or math.abs(door.X - faceLine) < wing.corridorWidthStuds - 0.5 then
					table.insert(wrong, wingRoom.name)
				end
			end
		end
		check(openings == 1 and seeThrough == 0 and #wrong == 0, string.format(
			"the spa wing: one door from the balcony (%d found), no see-through spots (%d), %d rooms off its corridor%s",
			openings, seeThrough, #wing.rooms, if #wrong > 0 then " (wrong: " .. table.concat(wrong, ", ") .. ")" else ""))
	else
		check(false, "the spa wing's reception Room_" .. wing.reception .. " exists")
	end

	-- Themed room fronts (2026-10-26, batches 1, 2a and 2b): each is decorated;
	-- every detail stays along its own wall and within FrontDepthStuds of it
	-- (the aisles and the balcony stay clear); nothing solid stands in front of
	-- its door (the door's width and 1.5 more each side, 4 out).
	local THEMED = { "SpaReception", "MaxTesting", "Dumbbells", "Cardio", "Office", "Machines", "Physio", "Storage",
		"Classroom", "MediaRoom", "WarmUp", "Coach" }
	local frontRegions, frontDecor = model:FindFirstChild("Fronts"), model:FindFirstChild("FrontProps")
	local frontProblems, frontParts = {}, 0
	for _, name in ipairs(THEMED) do
		local region = frontRegions and frontRegions:FindFirstChild("Front_" .. name) :: BasePart?
		local decor = frontDecor and frontDecor:FindFirstChild(name)
		if region == nil or decor == nil then
			table.insert(frontProblems, name .. " not decorated")
			continue
		end
		local outward = region:GetAttribute("Outward") :: Vector3
		local door = region:GetAttribute("DoorAt") :: Vector3
		local doorHalf = (region:GetAttribute("DoorWidth") :: number) / 2
		local doorTop = region:GetAttribute("DoorTop") :: number
		local right = (-outward):Cross(Vector3.yAxis)
		local regionLow, regionHigh = bounds(region)
		local aLimitLow = math.min((regionLow - door):Dot(right), (regionHigh - door):Dot(right))
		local aLimitHigh = math.max((regionLow - door):Dot(right), (regionHigh - door):Dot(right))
		local outside, blocking = 0, 0
		for _, part in ipairs(decor:GetDescendants()) do
			if part:IsA("BasePart") then
				frontParts += 1
				local low, high = bounds(part)
				local a0, a1 = (low - door):Dot(right), (high - door):Dot(right)
				local d0, d1 = (low - door):Dot(outward), (high - door):Dot(outward)
				a0, a1, d0, d1 = math.min(a0, a1), math.max(a0, a1), math.min(d0, d1), math.max(d0, d1)
				if d1 > gym.FrontDepthStuds + 0.05 or a0 < aLimitLow - 0.05 or a1 > aLimitHigh + 0.05 then
					outside += 1
				end
				if part.CanCollide and a0 < doorHalf + 1.5 and a1 > -doorHalf - 1.5 and d0 < 4 and d1 > 0
					and low.Y < door.Y + doorTop then
					blocking += 1
				end
			end
		end
		if outside > 0 or blocking > 0 then
			table.insert(frontProblems, string.format("%s: %d too far out or past its wall, %d solid at its door", name, outside,
				blocking))
		end
	end
	check(#frontProblems == 0, string.format(
		"%d themed room fronts: details within %d studs of their walls, nothing solid at their doors (%d parts)%s",
		#THEMED, gym.FrontDepthStuds, frontParts,
		if #frontProblems > 0 then " (" .. table.concat(frontProblems, "; ") .. ")" else ""))

	-- Stage 5: lighting. The Lighting service (set by Rojo from default.project.json).
	local lighting = game:GetService("Lighting")
	local ambient = lighting.Ambient
	local readTechnology, technology = pcall(function()
		return lighting.Technology
	end)
	-- Only the Command Bar may read Technology; code run through the Studio MCP
	-- cannot, so there it is reported as INFO and the rest is still checked.
	local technologyName = if readTechnology then technology.Name else "unreadable"
	check((technologyName == "Future" or not readTechnology) and math.min(ambient.R, ambient.G, ambient.B) >= 0.3
		and lighting.ClockTime >= 8 and lighting.ClockTime <= 17, string.format(
			"Lighting: Future (%s), ambient not dark (%.2f, %.2f, %.2f), daytime (ClockTime %.1f)",
			technologyName, ambient.R, ambient.G, ambient.B, lighting.ClockTime))
	if not readTechnology then
		table.insert(lines, "  INFO  Lighting.Technology can't be read here; run this in the Command Bar to check it")
	end
	-- Looking straight up in every room you see a ceiling, not the floor tiles above;
	-- every room but the lobby has its LED panel with a light. Furniture is left
	-- out (the kitchen island stands in the middle of its room).
	local upParams = RaycastParams.new()
	upParams.FilterType = Enum.RaycastFilterType.Include
	local notProps = {}
	for _, child in ipairs(model:GetChildren()) do
		if child.Name ~= "Props" then
			table.insert(notProps, child)
		end
	end
	upParams.FilterDescendantsInstances = notProps
	local lightsFolder = model:FindFirstChild("Lights")
	local lobbyRoom = "Room_" .. gym.Rooms.FrontGround[2]
	local noCeiling, noLight = {}, {}
	for _, room in ipairs(folders.Rooms:GetChildren()) do
		if room:IsA("BasePart") then
			local bottom = room.Position.Y - room.Size.Y / 2
			local hit = workspace:Raycast(Vector3.new(room.Position.X, bottom + 2, room.Position.Z), Vector3.new(0, 30, 0), upParams)
			local seen = if hit then hit.Instance.Name else "nothing"
			if not (string.sub(seen, 1, 8) == "Ceiling_" or seen == "Lobby_Ceiling") then
				table.insert(noCeiling, room.Name .. " sees " .. seen)
			end
			if room.Name ~= lobbyRoom and not gym.OwnLightRooms[string.sub(room.Name, 6)] then
				local panel = lightsFolder and lightsFolder:FindFirstChild("RoomLight_" .. string.sub(room.Name, 6))
				if not (panel and panel:FindFirstChildOfClass("SurfaceLight")) then
					table.insert(noLight, room.Name)
				end
			end
		end
	end
	check(#noCeiling == 0, string.format("every room has a white ceiling overhead%s",
		if #noCeiling > 0 then " (" .. table.concat(noCeiling, "; ") .. ")" else ""))
	check(#noLight == 0, string.format("every room but the lobby (and the warm-lit sauna) has its ceiling light%s",
		if #noLight > 0 then " (missing: " .. table.concat(noLight, ", ") .. ")" else ""))
	-- Under the balcony: the white soffit, not the walkway's tiles.
	local underBalcony = {}
	local depthHalf = gym.BalconyDepthStuds / 2
	for i = 0, 9 do
		local x = plan.hallMinX + (i + 0.5) * (plan.hallMaxX - plan.hallMinX) / 10
		table.insert(underBalcony, Vector3.new(x, layout.floorY + 2, plan.hallFrontZ + depthHalf))
	end
	for i = 0, 5 do
		local z = plan.hallFrontZ + gym.BalconyDepthStuds + (i + 0.5) * (plan.hallBackZ - plan.hallFrontZ - gym.BalconyDepthStuds) / 6
		table.insert(underBalcony, Vector3.new(plan.hallMaxX - depthHalf, layout.floorY + 2, z))
		table.insert(underBalcony, Vector3.new(plan.hallMinX + depthHalf, layout.floorY + 2, z))
	end
	local notSoffit = {}
	for _, point in ipairs(underBalcony) do
		local hit = workspace:Raycast(point, Vector3.new(0, 30, 0), upParams)
		if hit == nil or string.sub(hit.Instance.Name, 1, 7) ~= "Soffit_" then
			table.insert(notSoffit, string.format("(%.0f, %.0f) %s", point.X, point.Z, if hit then hit.Instance.Name else "nothing"))
		end
	end
	check(#notSoffit == 0, string.format("under the balcony, all %d spots see the white ceiling%s", #underBalcony,
		if #notSoffit > 0 then " (" .. table.concat(notSoffit, "; ", 1, math.min(#notSoffit, 6)) .. ")" else ""))
	-- The hall's light bars: every segment under every beam, each with its light.
	local hallLights = 0
	if lightsFolder then
		for _, part in ipairs(lightsFolder:GetChildren()) do
			if part:IsA("BasePart") and string.match(part.Name, "^HallLight_%d+_%d+$") and part:FindFirstChildOfClass("SurfaceLight") then
				hallLights += 1
			end
		end
	end
	local expectedHall = gym.RoofBeamCount * gym.HallLightSegmentsPerRow
	check(hallLights == expectedHall, string.format("%d hall light bars with lights (%d found)", expectedHall, hallLights))

	-- Textured materials (2026-10-25): one MaterialVariant per config entry, with its uploaded maps.
	local materialService = game:GetService("MaterialService")
	local badVariants, variantCount = {}, 0
	for name, spec in pairs(gym.MaterialVariants) do
		variantCount += 1
		local variant = materialService:FindFirstChild(name)
		if not (variant and variant:IsA("MaterialVariant") and variant.BaseMaterial == spec.base
			and variant.ColorMap == spec.color and variant.NormalMap == spec.normal) then
			table.insert(badVariants, name)
		end
	end
	check(#badVariants == 0, string.format("%d textured materials in MaterialService%s", variantCount,
		if #badVariants > 0 then " (missing or wrong: " .. table.concat(badVariants, ", ") .. ")" else ""))

	-- Step 6a: furniture in every ground-floor room but the lobby, all of it
	-- inside its room, nothing solid in front of a door or inside a wall.
	local propsFolder = model:FindFirstChild("Props")
	local emptyRooms, outside, solidParts, propParts = {}, {}, {}, 0
	-- Every room whose furniture has been built (MUST_FURNISH) must be
	-- furnished; any room that has furniture is checked the same way. The new
	-- rooms (Cardio, Dumbbells, ...) stay empty until their own room batch
	-- (GAME_DESIGN §27, user 2026-10-26).
	local MUST_FURNISH = { "Lockers", "Showers", "Cafe", "StaffRoom", "Office", "Recovery", "Massage", "Physio",
		"Storage", "SupplementBar", "Shop", "Sauna", "Coach", "SpaReception" }
	for _, name in ipairs(MUST_FURNISH) do
		if folders.Rooms:FindFirstChild("Room_" .. name) == nil then
			table.insert(emptyRooms, name .. " (no room)")
		end
	end
	for _, room in ipairs(folders.Rooms:GetChildren()) do
		local name = string.sub(room.Name, 6)
		local roomProps = propsFolder and propsFolder:FindFirstChild(name)
		local mustFurnish = table.find(MUST_FURNISH, name) ~= nil
		if room:IsA("BasePart") and (mustFurnish or roomProps ~= nil) then
			local count = 0
			if roomProps then
				local roomLow, roomHigh = bounds(room)
				for _, part in ipairs(roomProps:GetDescendants()) do
					if part:IsA("BasePart") then
						count += 1
						local low, high = bounds(part)
						if low.X < roomLow.X - 0.02 or low.Y < roomLow.Y - 0.02 or low.Z < roomLow.Z - 0.02
							or high.X > roomHigh.X + 0.02 or high.Y > roomHigh.Y + 0.02 or high.Z > roomHigh.Z + 0.02 then
							table.insert(outside, name .. "." .. part.Name)
						end
						if part.CanCollide then
							table.insert(solidParts, part)
						end
					end
				end
			end
			propParts += count
			if count < 10 then
				table.insert(emptyRooms, string.format("%s (%d parts)", name, count))
			end
		end
	end
	check(#emptyRooms == 0, string.format("every room with built furniture is furnished (%d prop parts)%s", propParts,
		if #emptyRooms > 0 then "; empty: " .. table.concat(emptyRooms, ", ") else ""))
	check(#outside == 0, string.format("all room furniture stays inside its room%s",
		if #outside > 0 then " (" .. table.concat(outside, ", ", 1, math.min(#outside, 6)) .. ")" else ""))
	-- The shop's gear models (art/roblox/ShopGear_01.rbxmx): 3 mannequins, 6
	-- hanging wraps, 8 knee sleeves, 6 rolled wraps, 6 belts.
	local shopProps = propsFolder and propsFolder:FindFirstChild("Shop")
	local gearCount = 0
	if shopProps then
		for _, child in ipairs(shopProps:GetChildren()) do
			if child:IsA("Model") then
				gearCount += 1
			end
		end
	end
	check(gearCount == 29, string.format("the shop shows its 29 gear models (%d found; they come from ServerStorage.PropTemplates.%s)",
		gearCount, gym.ShopGearTemplate))
	-- In front of every door, on both sides, nothing solid from the furniture.
	local blockedDoors = {}
	if propsFolder then
		local propParams = OverlapParams.new()
		propParams.FilterType = Enum.RaycastFilterType.Include
		propParams.FilterDescendantsInstances = { propsFolder }
		for _, room in ipairs(folders.Rooms:GetChildren()) do
			local centre = room:GetAttribute("DoorCentre")
			local alongX = room:GetAttribute("DoorAlongX")
			if typeof(centre) == "Vector3" and typeof(alongX) == "boolean" then
				local half = if alongX then Vector3.new(4.5, 3.8, 7) else Vector3.new(7, 3.8, 4.5)
				local names = {}
				for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(centre + Vector3.new(0, 0.2, 0)), half * 2, propParams)) do
					if part.CanCollide then
						table.insert(names, part.Name)
					end
				end
				if #names > 0 then
					table.insert(blockedDoors, room.Name .. " (" .. table.concat(names, ", ") .. ")")
				end
			end
		end
	end
	check(#blockedDoors == 0, string.format("no solid furniture in front of any door%s",
		if #blockedDoors > 0 then " (" .. table.concat(blockedDoors, "; ") .. ")" else ""))
	local inWalls = {}
	for _, part in ipairs(solidParts) do
		local low, high = bounds(part)
		local hits = wallsIn(low + Vector3.one * 0.02, high - Vector3.one * 0.02)
		if #hits > 0 then
			table.insert(inWalls, part.Name .. " (" .. table.concat(hits, ", ") .. ")")
		end
	end
	check(#inWalls == 0, string.format("no solid furniture inside a wall (%d solid pieces)%s", #solidParts,
		if #inWalls > 0 then ": " .. table.concat(inWalls, "; ", 1, math.min(#inWalls, 6)) else ""))

	-- Stage 4: the gym's name twice (name wall, outside sign), the check-in
	-- screen, and the lights (ceiling strips, desk glow and light bar, two sign
	-- halos, two spotlights).
	-- The Strongman Shed (2026-10-26): its own building beside the gym (a gap
	-- of at least 10 to the gym's side wall, its front level with the gym's),
	-- its roller door open, walled in (rays from its middle, the front ones
	-- aimed beside the door, hit its walls), roofed, no door into it from the
	-- gym, furnished, and nothing of its furniture outside it or solid in front
	-- of its door.
	local shedFolder = model:FindFirstChild("Shed")
	local shedRegion = shedFolder and shedFolder:FindFirstChild("Shed_" .. gym.StrongmanShed.name) :: BasePart?
	if shedRegion then
		local shedLow, shedHigh = bounds(shedRegion)
		local outerX = plan.outerHalfWidth + thickness
		local apart = (shedHigh.X <= plan.centreX - outerX - 10 or shedLow.X >= plan.centreX + outerX + 10)
			and math.abs(shedLow.Z - (plan.frontZ - thickness) - thickness) < 0.05
		local door = shedRegion:GetAttribute("DoorCentre") :: Vector3
		local shedParams = OverlapParams.new()
		shedParams.FilterType = Enum.RaycastFilterType.Include
		shedParams.FilterDescendantsInstances = { shedFolder :: Instance }
		local doorBox = Vector3.new(gym.StrongmanShed.doorWidthStuds / 2 - 0.6, 4.2, 0.6)
		local inDoorway = {}
		for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(door), doorBox * 2, shedParams)) do
			if part.CanCollide then
				table.insert(inDoorway, part.Name)
			end
		end
		if doorsFolder and doorsFolder:FindFirstChild(gym.StrongmanShed.name .. "Door") then
			table.insert(inDoorway, "a door from the gym still exists")
		end
		local shedRays = RaycastParams.new()
		shedRays.FilterType = Enum.RaycastFilterType.Include
		shedRays.FilterDescendantsInstances = { shedFolder :: Instance }
		local middle = Vector3.new((shedLow.X + shedHigh.X) / 2, layout.floorY + 3, (shedLow.Z + shedHigh.Z) / 2)
		local gaps = 0
		for _, direction in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, Vector3.new(1, 0, 1).Unit,
			Vector3.new(-1, 0, 1).Unit, Vector3.new(1, 0, -1).Unit, Vector3.new(-1, 0, -1).Unit, Vector3.yAxis }) do
			local hit = workspace:Raycast(if direction == Vector3.yAxis then middle + Vector3.new(4, 0, 0) else middle,
				direction * 100, shedRays)
			if hit == nil or not hit.Instance.CanCollide then
				gaps += 1
			end
		end
		local shedProps = propsFolder and propsFolder:FindFirstChild(gym.StrongmanShed.name)
		local count, away, atDoor = 0, 0, 0
		if shedProps then
			for _, part in ipairs(shedProps:GetDescendants()) do
				if part:IsA("BasePart") then
					count += 1
					local low, high = bounds(part)
					if low.X < shedLow.X - 0.02 or high.X > shedHigh.X + 0.02 or low.Z < shedLow.Z - 0.02
						or high.Z > shedHigh.Z + 0.02 or high.Y > shedHigh.Y + 0.02 then
						away += 1
					end
					if part.CanCollide and low.X < door.X + 4.5 and high.X > door.X - 4.5 and low.Z < door.Z + 7.5 then
						atDoor += 1
					end
				end
			end
		end
		check(apart and #inDoorway == 0 and gaps == 0 and count >= 40 and away == 0 and atDoor == 0, string.format(
			"Strongman Shed: its own building beside the gym, roller door open, no door from the gym%s, walled in and roofed (%d rays out), %d furniture parts (%d outside, %d solid at its door)",
			if #inDoorway > 0 then " (blocked: " .. table.concat(inDoorway, ", ") .. ")" else "", gaps, count, away, atDoor))
	else
		check(false, "the Strongman Shed's region Shed_" .. gym.StrongmanShed.name .. " exists")
	end
	local names, rightNames = 0, 0
	for _, d in ipairs(folders.Reception:GetDescendants()) do
		if d:IsA("SurfaceGui") and d.Name == "GymName" then
			names += 1
			local label = d:FindFirstChild("Name")
			if label and label:IsA("TextLabel") and label.Text == gym.GymName then
				rightNames += 1
			end
		end
	end
	check(names == 2 and rightNames == 2, string.format("the name \"%s\" is on the name wall and the outside sign (%d of 2)",
		gym.GymName, rightNames))
	local screens, lights = 0, 0
	for _, d in ipairs(folders.Reception:GetDescendants()) do
		if d:IsA("SurfaceGui") and d.Name == "CheckInScreen" then
			screens += 1
		elseif d:IsA("Light") then
			lights += 1
		end
	end
	local expectedLights = gym.CeilingStripCount + 6
	check(screens == 1 and lights == expectedLights, string.format(
		"reception: the monitor's check-in screen (%d) and %d lights (%d found)", screens, expectedLights, lights))
	-- Uploaded pictures (StarterGymConfig.ImagePiece lists): how many of the
	-- pieces sit in `holder` as Piece_<n> with their image, and how many IDs
	-- are still empty in the config.
	local function piecesIn(holder: Instance?, pieces: { any }): (number, number)
		local right, empty = 0, 0
		for index, piece in ipairs(pieces) do
			if piece.image == "" then
				empty += 1
			else
				local image = holder and holder:FindFirstChild(string.format("Piece_%d", index))
				if image and image:IsA("ImageLabel") and image.Image == piece.image then
					right += 1
				end
			end
		end
		return right, empty
	end

	-- The desk's front, facing the customers (-X): one picture (logo and
	-- background), every uploaded piece in order.
	local deskFront = folders.Reception:FindFirstChild("Desk_Front") :: BasePart?
	local deskGui = deskFront and deskFront:FindFirstChild("DeskFront")
	local deskRight, deskEmpty = piecesIn(deskGui and deskGui:FindFirstChild("Picture"),
		gym.DeskFrontPieces)
	check(deskEmpty == 0 and deskGui ~= nil and deskGui:IsA("SurfaceGui") and deskGui.Face == Enum.NormalId.Left
		and deskRight == #gym.DeskFrontPieces, string.format(
			"the desk front picture faces the lobby (%d of %d pieces right, %d image IDs still empty in DeskFrontPieces)",
			deskRight, #gym.DeskFrontPieces, deskEmpty))
	-- No other part shares the desk front's face (that made it flicker).
	local sharing = {}
	if deskFront then
		local frontLow, frontHigh = bounds(deskFront)
		for _, part in ipairs(folders.Reception:GetChildren()) do
			if part:IsA("BasePart") and part ~= deskFront then
				local low, high = bounds(part)
				if math.abs(low.X - frontLow.X) < 0.01 and low.Z < frontHigh.Z and high.Z > frontLow.Z
					and low.Y < frontHigh.Y and high.Y > frontLow.Y then
					table.insert(sharing, part.Name)
				end
			end
		end
	end
	check(deskFront ~= nil and #sharing == 0, string.format("no other part shares the desk front's face%s",
		if #sharing > 0 then " (" .. table.concat(sharing, ", ") .. ")" else ""))

	-- The back-muscle art behind the gym's name: on the name wall, and the wide
	-- version filling the whole outside sign.
	for _, sign in ipairs({ { name = "NameWall", art = gym.NameSignArt }, { name = "FrontSign", art = gym.FrontSignArt } }) do
		local panel = folders.Reception:FindFirstChild(sign.name)
		local nameGui = panel and panel:FindFirstChild("GymName")
		local artFrame = nameGui and nameGui:FindFirstChild("Art")
		local right, empty = piecesIn(artFrame, sign.art)
		local fills = artFrame ~= nil and artFrame:IsA("GuiObject") and artFrame.Size.X.Scale > 0.99
		check(empty == 0 and right == #sign.art and fills, string.format(
			"%s's background art fills it (%d of %d pieces right, %d image IDs empty)", sign.name, right,
			#sign.art, empty))
	end

	-- Roblox hides see-through things behind the Glass material (signs too),
	-- so no wall or window uses it: the lobby's signs must show from outside.
	local glassMaterial = {}
	for _, d in ipairs(folders.Walls:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Glass then
			table.insert(glassMaterial, d.Name)
		end
	end
	check(#glassMaterial == 0, string.format("no wall or window uses the Glass material (%d do%s)", #glassMaterial,
		if #glassMaterial > 0 then ": " .. table.concat(glassMaterial, ", ", 1, math.min(#glassMaterial, 5)) else ""))
	local frontSign = folders.Reception:FindFirstChild("FrontSign") :: BasePart?
	check(frontSign ~= nil and frontSign.Position.Z < plan.frontZ - thickness,
		"the outside name sign is on the outside of the front wall")
	-- The straight way from the entrance, through the lobby, into the hall is clear (desk included).
	local halfWay = gym.EntranceWidthStuds / 2 - 0.1
	local way = wallsIn(Vector3.new(plan.centreX - halfWay, layout.floorY + 0.3, plan.frontZ + 0.1),
		Vector3.new(plan.centreX + halfWay, layout.floorY + 8, plan.hallFrontZ - thickness - 0.1))
	check(#way == 0, string.format("the way from the entrance through the lobby into the hall is clear%s",
		if #way > 0 then " (" .. table.concat(way, ", ") .. ")" else ""))

	-- Spawns: in the lobby, and not on the reception desk.
	local deskParams = OverlapParams.new()
	deskParams.FilterType = Enum.RaycastFilterType.Include
	deskParams.FilterDescendantsInstances = { folders.Reception }
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			local touching = workspace:GetPartsInPart(d, deskParams)
			check(#touching == 0, string.format("%s does not overlap the reception (%d parts)", d:GetFullName(), #touching))
		end
	end
	local lobby = folders.Rooms:FindFirstChild("Room_" .. gym.Rooms.FrontGround[2]) :: BasePart?
	local spawns = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			spawns += 1
			local inside = false
			if lobby then
				local low, high = bounds(d)
				local lobbyLow, lobbyHigh = bounds(lobby)
				inside = low.X >= lobbyLow.X and high.X <= lobbyHigh.X and low.Z >= lobbyLow.Z and high.Z <= lobbyHigh.Z
			end
			check(inside, string.format("%s at (%.1f, %.1f, %.1f) is inside the lobby", d:GetFullName(),
				d.Position.X, d.Position.Y, d.Position.Z))
		end
	end
	check(spawns > 0, string.format("%d SpawnLocation(s) found", spawns))

	table.insert(lines, string.format(
		"  INFO  hall X %.1f..%.1f, Z %.1f..%.1f | lobby Z %.1f..%.1f | %d wall parts, %d rooms",
		plan.hallMinX, plan.hallMaxX, plan.hallFrontZ, plan.hallBackZ, plan.frontZ,
		plan.hallFrontZ - thickness, #folders.Walls:GetChildren(), #folders.Rooms:GetChildren()))
end

local ok, err = pcall(run)
if not ok then
	warn("[Starter Gym verify] SCRIPT ERROR: " .. tostring(err))
elseif #lines > 0 then
	local header = if failures == 0
		then string.format("[Starter Gym verify] ALL %d CHECKS PASSED", passes)
		else string.format("[Starter Gym verify] %d CHECK(S) FAILED, %d passed", failures, passes)
	local report = header .. "\n" .. table.concat(lines, "\n")
	if failures == 0 then
		print(report)
	else
		warn(report)
	end
end
