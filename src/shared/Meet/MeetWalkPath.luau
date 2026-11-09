--!strict
--[[
	MeetWalkPath
	Shared / Meet

	One walk at a meet (the walk out to the bar and back, a coach's walk), worked out the same way on the server and on
	every client (GAME_DESIGN §36.4, user 2026-11-08: Local and Regional walk-outs "too bland, and not smooth").

	The server used to move the body itself every frame, and clients only saw it move on every other frame or so: a
	stutter. Now the server sends the walk's few numbers once (`Spec`) and each client draws it every frame from them
	(MeetWalkView), while the server works out the same place to know where the body is.

	How it moves: it eases up to its walking speed from standing, eases from the usual walk into a slower walk style
	over the last stretch (EntranceConfig.StyleWalkStuds), and slows into the stop. It looks a little ahead along the
	route, so it turns before a corner rather than on it, and turns from where it faced at the start and into the way
	`final` faces at the end.

	Everything here is decided by time alone (no frame lengths), so the server and every client get the same answer.
]]

local MeetWalkPath = {}

export type Spec = {
	-- Where the body stood when the walk started (floor point) and the way it faced.
	from: Vector3,
	look: Vector3,
	-- The route's corners (floor points), then where it ends (a floor point facing the way to stand).
	points: { Vector3 },
	final: CFrame,
	-- The root part's height above the floor.
	height: number,
	-- Studs per second: the usual walk, and a walk style's over the last `styleStuds` (nil: no walk style).
	usualSpeed: number,
	styleSpeed: number?,
	styleStuds: number?,
}

export type Path = {
	spec: Spec,
	route: { Vector3 },
	-- Distance along the route at the start of each leg.
	starts: { number },
	total: number,
	styleFrom: number,
	-- Distance and speed every STEP seconds from the start; the last entry is the stop.
	distances: { number },
	speeds: { number },
	duration: number,
	startYaw: number,
	finalYaw: number,
}

-- Sample spacing of the speed table (seconds).
local STEP = 1 / 60
-- Studs per second gained each second when speeding up from standing, and lost easing into a slower walk style.
local SPEED_UP = 22
local EASE_DOWN = 9
-- Slowing into the stop: studs per second lost each second, and the slowest it creeps the last bit.
local STOP_DECEL = 15
local CREEP = 0.8
-- How far ahead along the route the body looks (it turns before a corner), and over how much of the start and the end
-- it turns from its first facing and into the final one.
local LOOK_AHEAD = 2.5
local START_TURN = 1.5
local FINAL_TURN = 3.0
-- A walk can't run longer than this (a broken route).
local MAX_SECONDS = 60

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function yawOf(v: Vector3): number
	return math.atan2(-v.X, -v.Z)
end

local function lookOf(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- `a` to `b` the short way round, by `u` (0..1).
local function turnBetween(a: number, b: number, u: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * u
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

function MeetWalkPath.new(spec: Spec): Path
	local route = { spec.from }
	for _, point in ipairs(spec.points) do
		table.insert(route, point)
	end
	table.insert(route, spec.final.Position)
	local starts = { 0 }
	local total = 0
	for index = 2, #route do
		total += (route[index] - route[index - 1]).Magnitude
		starts[index] = total
	end
	local styleSpeed = spec.styleSpeed
	local styleFrom = if styleSpeed and spec.styleStuds then math.max(0, total - spec.styleStuds) else math.huge

	-- The speed table: speed up from standing toward the stretch's speed, ease down into a slower style, and never
	-- faster than can still stop in the distance left.
	local distances, speeds = { 0 }, { 0 }
	local s, v, t = 0, 0, 0
	while s < total and t < MAX_SECONDS do
		local target = if s >= styleFrom and styleSpeed then styleSpeed else spec.usualSpeed
		if v < target then
			v = math.min(target, v + SPEED_UP * STEP)
		elseif v > target then
			v = math.max(target, v - EASE_DOWN * STEP)
		end
		v = math.max(math.min(v, math.sqrt(2 * STOP_DECEL * (total - s))), CREEP)
		s = math.min(total, s + v * STEP)
		t += STEP
		table.insert(distances, s)
		table.insert(speeds, v)
	end
	speeds[#speeds] = 0

	local look = flat(spec.look)
	local finalLook = flat(spec.final.LookVector)
	local first = if #route >= 2 then flat(route[2] - route[1]) else Vector3.zero
	return {
		spec = spec,
		route = route,
		starts = starts,
		total = total,
		styleFrom = styleFrom,
		distances = distances,
		speeds = speeds,
		duration = (#distances - 1) * STEP,
		startYaw = yawOf(if look.Magnitude > 1e-3 then look elseif first.Magnitude > 1e-3 then first else Vector3.new(0, 0, -1)),
		finalYaw = yawOf(if finalLook.Magnitude > 1e-3 then finalLook else Vector3.new(0, 0, -1)),
	}
end

-- The floor point `s` studs along the route.
local function pointAt(path: Path, s: number): Vector3
	local route, starts = path.route, path.starts
	if s <= 0 then
		return route[1]
	end
	for index = 2, #route do
		if s <= starts[index] then
			local length = starts[index] - starts[index - 1]
			local u = if length > 1e-6 then (s - starts[index - 1]) / length else 1
			return route[index - 1]:Lerp(route[index], u)
		end
	end
	return route[#route]
end

-- How far along and how fast at `t` seconds into the walk.
function MeetWalkPath.progress(path: Path, t: number): (number, number)
	local f = math.clamp(t, 0, path.duration) / STEP
	local i = math.floor(f)
	local n = #path.distances
	if i >= n - 1 then
		return path.total, 0
	end
	local u = f - i
	local a, b = path.distances[i + 1], path.distances[i + 2]
	local va, vb = path.speeds[i + 1], path.speeds[i + 2]
	return a + (b - a) * u, va + (vb - va) * u
end

-- Where the root part is at `t` seconds into the walk, and whether the walk is over.
function MeetWalkPath.at(path: Path, t: number): (CFrame, boolean)
	local spec = path.spec
	if t >= path.duration or path.total < 1e-3 then
		return spec.final + Vector3.new(0, spec.height, 0), true
	end
	local s = MeetWalkPath.progress(path, t)
	local here = pointAt(path, s)
	local ahead = flat(pointAt(path, math.min(path.total, s + LOOK_AHEAD)) - here)
	local yaw = if ahead.Magnitude > 1e-3 then yawOf(ahead) else path.finalYaw
	yaw = turnBetween(path.startYaw, yaw, smooth(s / START_TURN))
	yaw = turnBetween(yaw, path.finalYaw, smooth(1 - (path.total - s) / FINAL_TURN))
	return CFrame.lookAt(here, here + lookOf(yaw)) + Vector3.new(0, spec.height, 0), false
end

-- The walk's numbers as sent to clients (plain values only), and back. `fromData` returns nil for anything malformed.
function MeetWalkPath.toData(spec: Spec): { [string]: any }
	return {
		from = spec.from,
		look = spec.look,
		points = spec.points,
		final = spec.final,
		height = spec.height,
		usualSpeed = spec.usualSpeed,
		styleSpeed = spec.styleSpeed,
		styleStuds = spec.styleStuds,
	}
end

function MeetWalkPath.fromData(data: any): Spec?
	if typeof(data) ~= "table" then
		return nil
	end
	if typeof(data.from) ~= "Vector3" or typeof(data.look) ~= "Vector3" or typeof(data.final) ~= "CFrame"
		or typeof(data.height) ~= "number" or typeof(data.usualSpeed) ~= "number" or data.usualSpeed <= 0
		or typeof(data.points) ~= "table" then
		return nil
	end
	local points: { Vector3 } = {}
	for _, point in ipairs(data.points) do
		if typeof(point) ~= "Vector3" then
			return nil
		end
		table.insert(points, point)
	end
	local styleSpeed = if typeof(data.styleSpeed) == "number" and data.styleSpeed > 0 then data.styleSpeed else nil
	return {
		from = data.from,
		look = data.look,
		points = points,
		final = data.final,
		height = data.height,
		usualSpeed = data.usualSpeed,
		styleSpeed = styleSpeed,
		styleStuds = if styleSpeed and typeof(data.styleStuds) == "number" then data.styleStuds else nil,
	}
end

return MeetWalkPath
