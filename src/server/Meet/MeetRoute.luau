--!strict
--[[
	MeetRoute
	Server / Meet

	WALKS THAT GO ROUND THINGS (user 2026-11-28: "Go through every cutscene and make sure coaches dont just phase through
	the banners"; and the podium walk "have the coach actually walk the lifter out, and NOT cut and teleport"). The meet's
	scripted walks (ComputerLifters.walkBody) go in straight lines between corners and pass through anything, and most of
	the venues' furniture (the CENTRAL barricades with their banners, banner stands, curtains, chalk stands, plate trees,
	judges' tables, chairs) has no collision, so players can move about freely. This finds ways round all of it with
	Roblox's pathfinding:

	  - markDecor: the furniture standing on the venues' floors (DECOR_NAMES) is made solid for pathfinding only: it is put
	    in a collision group that collides with nothing ("WalkAround"), so players and bodies still pass through exactly as
	    before, but pathfinding counts it as in the way. (Checked in Studio 2026-11-28: a PathfindingModifier on a
	    non-solid part is ignored; a solid part in a group that collides with nothing is walked round.)
	  - route(from, to, radius): the corners of a way from one floor point to another, wide enough for `radius`.
	  - reroute(from, points, final, radius): a planned walk (corners then the end) with every leg that runs into
	    something replaced by a way round it; legs that are clear (or with no way round) stay as planned.

	Server only; nothing is sent to clients. PERFORMANCE: pathfinding runs once per leg as a walk starts (a few per
	scene); the furniture is marked once, and again at most every RESCAN_SECONDS (venues build later).
]]

local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

local MeetRoute = {}

local GROUP = "WalkAround"
-- The venues' furniture that stands on the floor and that walks must go round (2026-11-28, from a Studio list of every
-- non-solid part standing on the Local hall, State arena and Nationals hall floors). Not the doorways' frames (the way
-- through them is the point), the rack gantries (walked under) or the crowd and the stands.
local DECOR_NAMES = {
	Barricade_Frame = true, MeetBanner_Rails = true, MeetBanner_Caps = true, GantryBanner_Trim = true,
	NatBanner_Rods = true, NatBanner_Cloth = true, NatStageSet_Backdrop = true, NatStageSet_Drapes = true,
	NatStageSet_Pipe = true, NatCurtainPanel_Cloth = true, NatCurtainGap_Cloth = true, NatCurtainEndL_Cloth = true,
	NatCurtainEndR_Cloth = true, NatDrape_Cloth = true, PlateTree_Frame = true, MeetChalkStand_Frame = true,
	JudgesTable_Skirt = true, JudgesTable_Legs = true, CameraTripod_Legs = true, RefChair_Frame = true,
	PlatformSign_Pole = true, Sofa_Frame = true, MeetDesk_Body = true, WaterCooler_Body = true, Bleachers_Body = true,
}
local VENUES = { "LocalMeetVenue", "StateArenaVenue", "NationalsHall" }
local RESCAN_SECONDS = 60
-- Pathfinding finds no way from a point right on the floor (Studio 2026-11-28): the ends are asked this far up.
local LIFT = 2.5
-- A bend sharper than this (cosine) is a corner worth keeping; a way this much longer than the straight leg means
-- something was in the way.
local CORNER_COS = 0.995
local DETOUR = 1.06

local lastScan = -math.huge

local function ensureGroup()
	if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
		PhysicsService:RegisterCollisionGroup(GROUP)
	end
	for _, group in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
		PhysicsService:CollisionGroupSetCollidable(GROUP, group.name, false)
	end
end

-- Makes the venues' furniture count for pathfinding (it still collides with nothing).
function MeetRoute.markDecor()
	if os.clock() - lastScan < RESCAN_SECONDS then
		return
	end
	lastScan = os.clock()
	local ok = pcall(ensureGroup)
	if not ok then
		return
	end
	for _, name in ipairs(VENUES) do
		local venue = Workspace:FindFirstChild(name)
		for _, part in ipairs(if venue then venue:GetDescendants() else {}) do
			if part:IsA("BasePart") and DECOR_NAMES[part.Name] and part.CollisionGroup ~= GROUP then
				part.CollisionGroup = GROUP
				part.CanCollide = true
			end
		end
	end
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zero
end

-- The floor under `at` (the first solid, visible, queryable thing below it), or `at` itself.
local function floorUnder(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), params)
		if hit == nil then
			return at
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local body = model and model:FindFirstChildOfClass("Humanoid")
		if body or hit.Instance.Transparency >= 0.95 or not hit.Instance.CanCollide or hit.Instance.CollisionGroup == GROUP then
			table.insert(ignore, if body then model :: Model else hit.Instance)
		else
			return hit.Position
		end
	end
	return at
end

local function corners(points: { Vector3 }): { Vector3 }
	local kept = { points[1] }
	for index = 2, #points - 1 do
		local before = flat(points[index] - kept[#kept])
		local after = flat(points[index + 1] - points[index])
		if before.Magnitude > 0 and after.Magnitude > 0 and before:Dot(after) < CORNER_COS then
			table.insert(kept, points[index])
		end
	end
	table.insert(kept, points[#points])
	return kept
end

-- The way from floor point `from` to floor point `to` for a body `radius` wide, or nil if there is none.
local function find(from: Vector3, to: Vector3, radius: number): { Vector3 }?
	local lift = Vector3.new(0, LIFT, 0)
	for _, width in ipairs({ radius, radius * 0.6 }) do
		local path = PathfindingService:CreatePath({ AgentRadius = width, AgentHeight = 5, AgentCanJump = false,
			AgentCanClimb = false, WaypointSpacing = 3 })
		local ok = pcall(function()
			path:ComputeAsync(from + lift, to + lift)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local points: { Vector3 } = {}
			for _, waypoint in ipairs(path:GetWaypoints()) do
				table.insert(points, floorUnder(waypoint.Position))
			end
			if #points >= 2 then
				points[1], points[#points] = from, to
				return corners(points)
			end
		end
	end
	return nil
end

--[[
	The corners of a way from floor point `from` to floor point `to` round the furniture and anything solid, wide enough
	for `radius` (a narrower way if that doesn't fit), ends included; straight there if there is no way at all.
]]
function MeetRoute.route(from: Vector3, to: Vector3, radius: number): { Vector3 }
	MeetRoute.markDecor()
	return find(from, to, radius) or { from, to }
end

local function length(points: { Vector3 }): number
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
	end
	return total
end

--[[
	A planned walk from floor point `from` through `points` to `final` with every leg that runs into something replaced
	by the way round it (its corners inserted); clear legs, and legs with no way round, stay as planned. Returns the new
	corner list for ComputerLifters.walkBody (the end stays `final`).
]]
function MeetRoute.reroute(from: Vector3, points: { Vector3 }, final: CFrame, radius: number): { Vector3 }
	MeetRoute.markDecor()
	local stops = table.clone(points)
	table.insert(stops, final.Position)
	local out: { Vector3 } = {}
	local last = from
	for index, stop in ipairs(stops) do
		local straight = Vector3.new(stop.X - last.X, 0, stop.Z - last.Z).Magnitude
		if straight > 2 then
			local way = find(last, stop, radius)
			if way and #way > 2 and length(way) > straight * DETOUR then
				for inner = 2, #way - 1 do
					table.insert(out, way[inner])
				end
			end
		end
		if index < #stops then
			table.insert(out, stop)
		end
		last = stop
	end
	return out
end

return MeetRoute
