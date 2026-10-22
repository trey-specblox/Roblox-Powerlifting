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
	  - stage 2: the whole hall is under the roof (upward rays all hit it),
	    seen from above the whole building is the pitched roof (no flat roof
	    tops), and the skylights exist;
	  - the entrance is open, and every SpawnLocation stands in the lobby.
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

local function bounds(part: BasePart): (Vector3, Vector3)
	return part.Position - part.Size / 2, part.Position + part.Size / 2
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
	for _, name in ipairs({ "Floors", "Roofs", "Walls", "Rooms" }) do
		folders[name] = model:FindFirstChild(name)
	end
	check(folders.Floors and folders.Roofs and folders.Walls and folders.Rooms,
		"it has Floors, Roofs, Walls and Rooms")
	if not (folders.Floors and folders.Roofs and folders.Walls and folders.Rooms) then
		return
	end

	-- Solid parts.
	local partCount, loose = 0, 0
	for _, f in ipairs({ folders.Floors, folders.Roofs, folders.Walls }) do
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("BasePart") then
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

	local wallParams = OverlapParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Include
	wallParams.FilterDescendantsInstances = { folders.Walls }
	local function wallsIn(low: Vector3, high: Vector3): { string }
		local names = {}
		for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new((low + high) / 2), high - low, wallParams)) do
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

	-- Rooms: each listed once, each door open.
	local expected = {}
	for key, list in pairs(gym.Rooms) do
		for _, name in pairs(list) do
			table.insert(expected, name)
		end
	end
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

	-- Spawns: in the lobby.
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
