--!strict
--[[
	MeetSpotterAnimator
	Client / Meet

	Moves the Local meet's spotters with the lift (GAME_DESIGN §37.5, user
	2026-11-02): "spotters need to be following my character". Each frame, on
	this player's screen (visual only, like the bar in StationPoseAnimator):

	  Squat   the two side spotters stand off the bar's ends, hands hovering
	          just under the sleeves, crouching as the bar goes down and
	          following it back to the rack (or taking it on a miss). The back
	          spotter stands right behind the lifter, hands hovering behind
	          their back.
	  Bench   the side spotters the same, bending and crouching with the bar;
	          the back spotter on the rack's spotter deck behind the lifter's
	          head, hands hovering over the bar.
	  Deadlift  no spotters (the server takes them off the platform).

	Nothing touches: hands hover a gap away from the bar and the lifter, the side
	spotters stand beyond the bar's ends (outside the rack), the back spotter keeps
	clear of the lifter and stays on the deck behind the bench.

	Making way (user 2026-11-11 for celebrations; 2026-11-12: "make sure any spotters
	or loaders are not in the way of entrances or celebrations"): through a lifter's
	walk out and hype move, and while they celebrate or cheer after a good lift, all
	three walk off and watch (the rack's SpottersClearUntil, LocalMeetVenue.clearSpotters),
	then walk back: to spots out of the shots (ENTRANCE_SPOTS for the State walk-out,
	the rack's SpottersClearMode; CLEAR_SPOTS otherwise), round the rack, never
	through it, and never across the front middle where the lifter walks in.

	The server builds the spotters (MeetFigures.buildSpotter) and tags them
	MeetSpotter with: Role (Left / Right / Back), an ObjectValue SpotterRack, the
	rack's floor frame SpotterFloor, and RestAt / RestLook (rack-local) for when
	nobody is lifting. The rack's SpotterLift attribute says which lift it is set
	for. The lifter is whoever has MeetRack = that rack; their MeetBarHeld = false
	means the bar has been let go (the spotters carry it).

	A spotter is posed by turning its own joints: hips, knees and ankles bend
	(feet flat, under the hips), the waist leans, the shoulders raise the arms.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MeetSpotterAnimator = {}

local TAG = "MeetSpotter"
local COMPUTER_LIFTERS_FOLDER = "LocalMeetComputerLifters"
local MEET_LIFT_ATTRIBUTE = "MeetLift"
local MEET_RACK_VALUE = "MeetRack"
local MEET_BAR_HELD_ATTRIBUTE = "MeetBarHeld"

-- The hands' angle forward from hanging, in the world, whenever the crouch can manage it.
local ARM_ANGLE = math.rad(60)
local MAX_CROUCH = math.rad(75)
-- How far the back leans for each unit of crouch: a little for squat, more for bench ("bending their back").
local LEAN_PER_CROUCH: { [string]: number } = { Squat = 0.3, Bench = 0.6 }
-- The hands' middle at least this far past the outermost plate or collar, and never nearer the middle of the bar than
-- MIN_REACH, the end of the sleeve (which keeps the body, a little farther out, clear of the sleeve's tip).
local PLATE_GAP = 0.5
local MIN_REACH = 4.6
-- The hands' gap under the bar while the lifter has it, and once it is let go: following it back, never touching it.
local HOVER = 0.45
local CARRY = 0.35
-- The back spotter (squat): hands this far behind the lifter's hips (well below and behind their elbows, which
-- stick out behind them holding the bar), at least this far in front of its own body; and its root never closer than
-- BACK_CLEARANCE behind the lifter's root (no part of the lifter, even falling forward or deep in the squat,
-- reaches farther back than about a stud).
local BACK_GAP = 1.0
local BACK_MIN_REACH = 1.6
local BACK_CLEARANCE = 2.7
-- The bench back spotter stands upright on the rack's spotter deck (rack-local: top 0.15, z 0.75 to 1.65; the
-- back rail starts at 1.65, the bench pad ends at 0.6; the deck is barely deeper than a body, so no crouch),
-- always at DECK_Z. Its hands hover this high over the bar, toward the head by this much, and at least
-- LIFTER_CLEARANCE over every part of the lifter near them (raised hands, head, hair, hats).
local DECK_TOP = 0.16
local DECK_Z = 1.15
-- Big hats and heads reach back over the deck: the spotter then steps back to stay this far behind the lifter's
-- farthest part (from its middle), standing on the back rail (z 1.65 to 1.95, top 0.25) or the floor behind.
local DECK_FRONT = 0.75
local DECK_BACK = 1.65
local RAIL_BACK = 1.95
local RAIL_TOP = 0.26
local BEHIND_LIFTER = 0.8
local BENCH_OVER_BAR = 1.1
local BENCH_TOWARD_HEAD = 0.35
local LIFTER_CLEARANCE = 0.5
local NEAR_HANDS_STUDS = 3
-- Spotters farther than this from the camera are left as they are.
local NEAR_STUDS = 220
-- How fast a spotter catches up with where it should be (per second).
local FOLLOW_RATE = 12

-- Making way for a celebration (user 2026-11-11: "Make sure the spotters cant get in the way of the celebrations"):
-- while the rack's SpottersClearUntil (server time, LocalMeetVenue.clearSpotters) is ahead, the spotters stand off at
-- the platform's front corners, past the rack's uprights and the bar's ends, watching the lifter at the lift spot
-- (rack-local z -6.2, StationLayout exitZ). Spots are rack-local (x, z). Checked against the celebration cinematic's
-- shots (CelebrationCinema; the lifter faces +z, so its "right" side shots are at -x): none in frame near the lifter,
-- none between a camera and the lifter, nor between the lifter and the usual camera behind them. They walk there,
-- and back, round the rack (routeBetween).
local CLEAR_ATTRIBUTE = "SpottersClearUntil"
local LIFT_SPOT = Vector3.new(0, 0, -6.2)
local CLEAR_SPOTS: { [string]: { [string]: Vector2 } } = {
	-- The back spotter waits beside the walk-in line (-4.8, -4.8), close to the lift spot: out past the bar's end,
	-- beside the left spotter.
	Squat = { Left = Vector2.new(-7.2, 3.0), Right = Vector2.new(7.2, 3.0), Back = Vector2.new(-7.2, 0.6) },
	-- Off the spotter deck behind the bench, straight back and to one side (clear of the uprights and the bench).
	Bench = { Left = Vector2.new(-7.2, 3.0), Right = Vector2.new(7.2, 3.0), Back = Vector2.new(-3.8, 4.6) },
}
local STEP_RATE = 3.5
-- How long a spotter keeps the slower rate after making way or coming back.
local STEP_SECONDS = 2.5

-- Making way for the State walk-out (user 2026-11-12: "make sure any spotters or loaders are not in the way of
-- entrances"; the rack's SpottersClearMode "StateWalkOut"). Its camera (MeetLiftMoment's ritual walk shots) was
-- recorded in Studio, rack-local, for squat and bench: Follow runs along the front (z -16) looking +x; Side rides
-- 5 studs to the lifter's left (x -5) from z -5 up to z 9.8 (squat) / 6.4 (bench), looking back at them, and holds
-- there through the hype move. The bar-end spotters stood right in that path (2.2 studs from the lens). These spots
-- were searched for against all 175 recorded frames: none is in frame nearer than the lifter, even on a very wide
-- screen (2.78:1): two off the platform on the left, between the side referee's chair and the lights, and one at
-- the back right corner.
local ENTRANCE_SPOTS: { [string]: Vector2 } = {
	Left = Vector2.new(-11.0, 0.6),
	Back = Vector2.new(-11.0, 3.4),
	Right = Vector2.new(7.2, 7.0),
}
local CLEAR_MODE_ATTRIBUTE = "SpottersClearMode"
-- They walk there and back (never through the rack or the bench, measured: x -4.95..4.95, z -3.4..2.0 with the bench):
-- round the rack's box at its corners, never across the front middle where the lifter walks in.
local WALK_STUDS_PER_SECOND = 8
local RACK_HALF_X = 5.3
local RACK_MIN_Z = -3.8
local RACK_MAX_Z = 2.6
local AROUND_X = 6.0
local AROUND_FRONT_Z = -4.5
local AROUND_BACK_Z = 3.4

local started = false

-- ---------------------------------------------------------------- the rig

type Joint = { joint: Instance, attachment: Attachment?, attachmentRest: CFrame?, c0: CFrame? }
type Rig = {
	thigh: number,
	shin: number,
	arm: number,
	standHeight: number,
	-- From the root part's centre to the waist joint, and from the waist joint to the left shoulder (rest).
	rootToWaist: Vector3,
	waistToShoulder: Vector3,
	joints: { [string]: Joint },
}
type State = { rig: Rig, root: CFrame?, crouch: number, back: number, lean: number, arms: number, lift: unknown,
	aside: boolean, steppingUntil: number,
	-- Making way: the spot it is going to or waits at (rack-local), the floor's height there, and the points still to
	-- walk through (world, at standing height) on the way there or back.
	asideAt: Vector2?, asideGround: number, route: { Vector3 }? }

local states: { [Model]: State } = {}

local function attachmentPosition(model: Model, part: string, name: string): Vector3?
	local holder = model:FindFirstChild(part)
	local attachment = holder and holder:FindFirstChild(name)
	return if attachment and attachment:IsA("Attachment") then attachment.Position else nil
end

local function jointOf(model: Model, name: string): Joint?
	local joint = model:FindFirstChild(name, true)
	if joint == nil then
		return nil
	end
	if joint:IsA("AnimationConstraint") then
		local attachment = joint.Attachment0
		if attachment == nil then
			return nil
		end
		local found: Joint = { joint = joint, attachment = attachment, attachmentRest = attachment.CFrame, c0 = nil }
		return found
	elseif joint:IsA("Motor6D") then
		local found: Joint = { joint = joint, attachment = nil, attachmentRest = nil, c0 = joint.C0 }
		return found
	end
	return nil
end

-- The spotter's measurements, from its rig attachments (positions, which posing never changes), or nil.
local function rigOf(model: Model): Rig?
	local p = function(part: string, name: string): Vector3?
		return attachmentPosition(model, part, name)
	end
	local rootA, rootB = p("HumanoidRootPart", "RootRigAttachment"), p("LowerTorso", "RootRigAttachment")
	local waistA, waistB = p("LowerTorso", "WaistRigAttachment"), p("UpperTorso", "WaistRigAttachment")
	local shoulderA = p("UpperTorso", "LeftShoulderRigAttachment")
	local hipB, kneeA = p("LeftUpperLeg", "LeftHipRigAttachment"), p("LeftUpperLeg", "LeftKneeRigAttachment")
	local kneeB, ankleA = p("LeftLowerLeg", "LeftKneeRigAttachment"), p("LeftLowerLeg", "LeftAnkleRigAttachment")
	local shoulderB, elbowA = p("LeftUpperArm", "LeftShoulderRigAttachment"), p("LeftUpperArm", "LeftElbowRigAttachment")
	local elbowB, wristA = p("LeftLowerArm", "LeftElbowRigAttachment"), p("LeftLowerArm", "LeftWristRigAttachment")
	local wristB = p("LeftHand", "LeftWristRigAttachment")
	local height = model:GetAttribute("StandHeight")
	if not (rootA and rootB and waistA and waistB and shoulderA and hipB and kneeA and kneeB and ankleA and shoulderB
		and elbowA and elbowB and wristA and wristB) or typeof(height) ~= "number" then
		return nil
	end
	local joints: { [string]: Joint } = {}
	for _, name in ipairs({ "LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftAnkle", "RightAnkle", "Waist",
		"LeftShoulder", "RightShoulder" }) do
		local joint = jointOf(model, name)
		if joint then
			joints[name] = joint
		end
	end
	return {
		thigh = (kneeA - hipB).Magnitude,
		shin = (ankleA - kneeB).Magnitude,
		arm = (elbowA - shoulderB).Magnitude + (wristA - elbowB).Magnitude + wristB.Magnitude,
		standHeight = height,
		rootToWaist = rootA - rootB + waistA,
		waistToShoulder = shoulderA - waistB,
		joints = joints,
	}
end

-- Turns a joint `angle` radians about its X axis from its rest (+ swings a hanging limb forward).
local function turn(rig: Rig, name: string, angle: number)
	local joint = rig.joints[name]
	if joint == nil then
		return
	end
	local rotation = CFrame.Angles(angle, 0, 0)
	if joint.attachment and joint.attachmentRest then
		joint.attachment.CFrame = joint.attachmentRest * rotation
	elseif joint.c0 and joint.joint:IsA("Motor6D") then
		joint.joint.C0 = joint.c0 * rotation
	end
end

-- ---------------------------------------------------------------- the crouch

-- The shin's tilt that keeps the ankle under the hip for a thigh tilt of `a`.
local function shinFor(rig: Rig, a: number): number
	return math.asin(math.min(1, rig.thigh * math.sin(a) / rig.shin))
end

local function dropFor(rig: Rig, a: number): number
	return rig.thigh * (1 - math.cos(a)) + rig.shin * (1 - math.cos(shinFor(rig, a)))
end

-- The thigh tilt that lowers the hips by `drop` with the feet flat under them (bisection).
local function crouchFor(rig: Rig, drop: number): number
	local lo, hi = 0, MAX_CROUCH
	for _ = 1, 18 do
		local mid = (lo + hi) / 2
		if dropFor(rig, mid) < drop then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) / 2
end

-- The left shoulder relative to the root part's centre (spotter frame, facing -Z) for a lean of `lean`.
local function shoulderOffset(rig: Rig, lean: number): Vector3
	return rig.rootToWaist + CFrame.Angles(-lean, 0, 0) * rig.waistToShoulder
end

-- crouch: the thighs' tilt; back: the shins' (the ankles turn it back so the feet stay flat); lean: the waist's.
type Pose = { root: CFrame, crouch: number, back: number, lean: number, arms: number }

--[[
	The pose that puts the middle of the spotter's hands at `hand` (world), facing
	`facing` (horizontal), feet on the floor at `floorY`: crouch (and lean) until
	the arms reach down at ARM_ANGLE, then stand where the hands land on it.
	`minReach`: the hands at least this far in front of the root (forward).
]]
local function poseFor(rig: Rig, hand: Vector3, facing: Vector3, floorY: number, leanPerCrouch: number,
	minReach: number?): Pose
	local handY = hand.Y - floorY
	local maxDrop = dropFor(rig, MAX_CROUCH)
	local drop, crouch, lean = 0, 0, 0
	for _ = 1, 5 do
		crouch = crouchFor(rig, drop)
		lean = leanPerCrouch * crouch
		local shoulderY = rig.standHeight - drop + shoulderOffset(rig, lean).Y
		local wanted = handY + rig.arm * math.cos(ARM_ANGLE)
		drop = math.clamp(drop + shoulderY - wanted, 0, maxDrop)
	end
	crouch = crouchFor(rig, drop)
	lean = leanPerCrouch * crouch
	local shoulder = shoulderOffset(rig, lean)
	local shoulderY = rig.standHeight - drop + shoulder.Y
	local angle = math.acos(math.clamp((shoulderY - handY) / rig.arm, -0.5, 1))
	local reach = -shoulder.Z + rig.arm * math.sin(angle)
	if minReach and reach < minReach then
		-- Too close: reach out farther (the hands then hover higher than asked).
		angle = math.asin(math.clamp((minReach + shoulder.Z) / rig.arm, 0, 1))
		reach = minReach
	end
	local flat = Vector3.new(facing.X, 0, facing.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else -Vector3.zAxis
	local at = Vector3.new(hand.X, floorY + rig.standHeight - drop, hand.Z) - flat * reach
	return {
		root = CFrame.lookAt(at, at + flat),
		crouch = crouch,
		back = shinFor(rig, crouch),
		lean = lean,
		arms = angle + lean,
	}
end

-- Standing at `at`, looking at `look` (both rack-local). `lift` "Bench" puts a spot on the deck up on it; any other
-- ("Clear": making way, always on the floor) does not.
local function restPose(rig: Rig, floor: CFrame, at: Vector3, look: Vector3, lift: string): Pose
	local floorY = floor.Position.Y + (if lift == "Bench" and at.Z >= 0.75 then DECK_TOP else 0)
	local world = floor:PointToWorldSpace(at)
	local toward = floor:PointToWorldSpace(look) - world
	local flat = Vector3.new(toward.X, 0, toward.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else -Vector3.zAxis
	local root = Vector3.new(world.X, floorY + rig.standHeight, world.Z)
	return { root = CFrame.lookAt(root, root + flat), crouch = 0, back = 0, lean = 0, arms = 0 }
end

-- ---------------------------------------------------------------- the bar and the lifter

-- How far along the bar (from its middle) the spotters' hands go: under the sleeve, past the plates and collar,
-- whatever is loaded (user 2026-11-07: never touching the bar).
local function handReach(barbell: Instance, shaft: BasePart): number
	local plates = 0
	for _, part in ipairs(barbell:GetDescendants()) do
		if part:IsA("BasePart") and (string.sub(part.Name, 1, 5) == "Plate" or string.sub(part.Name, 1, 6) == "Collar") then
			local x = math.abs(shaft.CFrame:PointToObjectSpace(part.Position).X)
			plates = math.max(plates, x + part.Size.X / 2)
		end
	end
	return math.max(plates + PLATE_GAP, MIN_REACH)
end

-- Every lifter on a meet platform, by their rack.
local function liftersByRack(): { [Instance]: Model }
	local found: { [Instance]: Model } = {}
	local function add(character: Model?)
		local link = character and character:FindFirstChild(MEET_RACK_VALUE)
		if character and link and link:IsA("ObjectValue") and link.Value then
			found[link.Value] = character
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		add(player.Character)
	end
	local computers = Workspace:FindFirstChild(COMPUTER_LIFTERS_FOLDER)
	if computers then
		for _, body in ipairs(computers:GetChildren()) do
			if body:IsA("Model") then
				add(body)
			end
		end
	end
	return found
end

-- The highest point of any of `character`'s parts (accessories too) within NEAR_HANDS_STUDS across of `point`.
local function topNear(character: Model, point: Vector3): number
	local top = -math.huge
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local offset = part.Position - point
			if Vector2.new(offset.X, offset.Z).Magnitude < NEAR_HANDS_STUDS then
				local cf, size = part.CFrame, part.Size
				local halfUp = 0.5 * (math.abs(cf.XVector.Y) * size.X + math.abs(cf.YVector.Y) * size.Y
					+ math.abs(cf.ZVector.Y) * size.Z)
				top = math.max(top, part.Position.Y + halfUp)
			end
		end
	end
	return top
end

-- How far toward the rack's back (rack-local +z) any of `character`'s parts reaches.
local function farthestAlong(character: Model, floor: CFrame): number
	local far = -math.huge
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local half = part.Size / 2
			for _, corner in ipairs({ Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1),
				Vector3.new(1, -1, -1), Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1),
				Vector3.new(-1, -1, -1) }) do
				far = math.max(far, floor:PointToObjectSpace(part.CFrame:PointToWorldSpace(half * corner)).Z)
			end
		end
	end
	return far
end

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(v.X, 0, v.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else fallback
end

-- True when the segment a-b (rack-local x, z) passes through the rack's box.
local function crossesRack(a: Vector2, b: Vector2): boolean
	local t0, t1 = 0, 1
	local d = b - a
	for _, edge in ipairs({
		{ -d.X, a.X + RACK_HALF_X }, { d.X, RACK_HALF_X - a.X }, { -d.Y, a.Y - RACK_MIN_Z }, { d.Y, RACK_MAX_Z - a.Y },
	}) do
		local p, q = edge[1], edge[2]
		if math.abs(p) < 1e-9 then
			if q <= 0 then
				return false
			end
		else
			local t = q / p
			if p < 0 then
				t0 = math.max(t0, t)
			else
				t1 = math.min(t1, t)
			end
			if t0 >= t1 then
				return false
			end
		end
	end
	return true
end

local function insideRack(point: Vector2): boolean
	return math.abs(point.X) < RACK_HALF_X and point.Y > RACK_MIN_Z and point.Y < RACK_MAX_Z
end

-- The way from `a` to `b` (rack-local x, z), as the points to walk through after `a`: straight when nothing is in
-- the way, else round the rack's corners (the shortest way that never crosses the front middle, where the lifter
-- walks in). A point on the rack itself (the bench's spotter deck) is left or reached straight from behind it.
local function routeBetween(a: Vector2, b: Vector2): { Vector2 }
	local out: { Vector2 } = {}
	local from = a
	if insideRack(a) then
		from = Vector2.new(a.X, AROUND_BACK_Z)
		table.insert(out, from)
	end
	local to = if insideRack(b) then Vector2.new(b.X, AROUND_BACK_Z) else b
	local nodes = { from, to, Vector2.new(-AROUND_X, AROUND_FRONT_Z), Vector2.new(AROUND_X, AROUND_FRONT_Z),
		Vector2.new(-AROUND_X, AROUND_BACK_Z), Vector2.new(AROUND_X, AROUND_BACK_Z) }
	local function allowed(p: Vector2, q: Vector2): boolean
		if crossesRack(p, q) then
			return false
		end
		-- Not across the lifter's way in, in front of the rack.
		return not ((p.X < -0.01 and q.X > 0.01 or p.X > 0.01 and q.X < -0.01) and math.min(p.Y, q.Y) < RACK_MIN_Z)
	end
	-- Shortest path over these six points (Dijkstra, tiny).
	local dist, previous, done = { [1] = 0 }, {}, {}
	for _ = 1, #nodes do
		local best, bestDist = nil, math.huge
		for index = 1, #nodes do
			if not done[index] and dist[index] and dist[index] < bestDist then
				best, bestDist = index, dist[index]
			end
		end
		if best == nil or best == 2 then
			break
		end
		done[best] = true
		for index = 1, #nodes do
			if not done[index] and allowed(nodes[best], nodes[index]) then
				local through = bestDist + (nodes[index] - nodes[best]).Magnitude
				if dist[index] == nil or through < dist[index] then
					dist[index] = through
					previous[index] = best
				end
			end
		end
	end
	local path: { Vector2 } = {}
	local at: number? = if dist[2] then 2 else nil
	while at and at ~= 1 do
		table.insert(path, 1, nodes[at])
		at = previous[at]
	end
	if #path == 0 then
		-- (No way round: straight there.)
		table.insert(path, to)
	end
	for _, point in ipairs(path) do
		table.insert(out, point)
	end
	if to ~= b then
		table.insert(out, b)
	end
	return out
end

-- The floor's height under a rack-local point (the platform, or the arena floor just off it).
local function groundAt(floor: CFrame, point: Vector2): number
	local params = RaycastParams.new()
	local skip: { Instance } = CollectionService:GetTagged(TAG)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	local computers = Workspace:FindFirstChild(COMPUTER_LIFTERS_FOLDER)
	if computers then
		table.insert(skip, computers)
	end
	params.FilterDescendantsInstances = skip
	params.FilterType = Enum.RaycastFilterType.Exclude
	local top = floor:PointToWorldSpace(Vector3.new(point.X, 4, point.Y))
	local hit = Workspace:Raycast(top, Vector3.new(0, -12, 0), params)
	return if hit then hit.Position.Y else floor.Position.Y
end

-- Where `spotter` waits while making way for a lifter's entrance or celebration (rack-local x, z), or nil when it isn't:
-- the State walk-out's spots (ENTRANCE_SPOTS), else the celebration's (CLEAR_SPOTS).
local function asideSpot(spotter: Model): Vector2?
	local link = spotter:FindFirstChild("SpotterRack")
	local rack = if link and link:IsA("ObjectValue") then link.Value else nil
	local role = spotter:GetAttribute("Role")
	if rack == nil or typeof(role) ~= "string" then
		return nil
	end
	local clearUntil = rack:GetAttribute(CLEAR_ATTRIBUTE)
	local lift = rack:GetAttribute("SpotterLift")
	if typeof(clearUntil) ~= "number" or Workspace:GetServerTimeNow() >= clearUntil or typeof(lift) ~= "string"
		or CLEAR_SPOTS[lift] == nil then
		return nil
	end
	if rack:GetAttribute(CLEAR_MODE_ATTRIBUTE) == "StateWalkOut" then
		return ENTRANCE_SPOTS[role]
	end
	return CLEAR_SPOTS[lift][role]
end

-- Where `spotter` should be now, or nil to leave it.
local function targetPose(spotter: Model, rig: Rig, lifters: { [Instance]: Model }): Pose?
	local link = spotter:FindFirstChild("SpotterRack")
	local rack = if link and link:IsA("ObjectValue") then link.Value else nil
	local floor = spotter:GetAttribute("SpotterFloor")
	local role = spotter:GetAttribute("Role")
	if rack == nil or typeof(floor) ~= "CFrame" or typeof(role) ~= "string" then
		return nil
	end
	local lift = rack:GetAttribute("SpotterLift")
	if lift ~= "Squat" and lift ~= "Bench" then
		return nil
	end
	local barbell = rack:FindFirstChild("Barbell")
	local shaft = barbell and barbell:FindFirstChild("Bar_Shaft")
	if barbell == nil or shaft == nil or not shaft:IsA("BasePart") then
		return nil
	end
	local found = lifters[rack]
	local lifter: Model? = if found and found:GetAttribute(MEET_LIFT_ATTRIBUTE) == lift then found else nil
	local gap = if lifter and lifter:GetAttribute(MEET_BAR_HELD_ATTRIBUTE) == false then CARRY else HOVER
	local floorY = floor.Position.Y
	local lean = LEAN_PER_CROUCH[lift] or 0.3

	if role == "Left" or role == "Right" then
		-- Off the bar's end, hands under the sleeve, wherever the bar is (on the lifter, or in the J-cups).
		local side = if role == "Left" then -1 else 1
		local along = flatUnit(floor.XVector, Vector3.xAxis)
		local hand = shaft.Position + along * side * handReach(barbell, shaft) - Vector3.yAxis * gap
		return poseFor(rig, hand, -along * side, floorY, lean)
	end

	local restAt, restLook = spotter:GetAttribute("RestAt"), spotter:GetAttribute("RestLook")
	if lift == "Squat" then
		local hips = if lifter then lifter:FindFirstChild("LowerTorso") else nil
		local root = if lifter then lifter:FindFirstChild("HumanoidRootPart") else nil
		if hips and hips:IsA("BasePart") and root and root:IsA("BasePart") then
			-- Right behind the lifter, hands hovering behind their hips.
			local look = flatUnit(root.CFrame.LookVector, flatUnit(floor.ZVector, Vector3.zAxis))
			local hand = hips.Position - look * (hips.Size.Z / 2 + BACK_GAP)
			local pose = poseFor(rig, hand, look, floorY, lean, BACK_MIN_REACH)
			local behind = (root.Position - pose.root.Position):Dot(look)
			if behind < BACK_CLEARANCE then
				pose.root = pose.root - look * (BACK_CLEARANCE - behind)
			end
			return pose
		end
		if typeof(restAt) == "Vector3" and typeof(restLook) == "Vector3" then
			return restPose(rig, floor, restAt, restLook, lift)
		end
		return nil
	end

	-- Bench: upright on the spotter deck behind the head, hands hovering over the bar and clear over the lifter.
	local towardHead = flatUnit(floor.ZVector, Vector3.zAxis)
	local hand = shaft.Position + Vector3.yAxis * BENCH_OVER_BAR + towardHead * BENCH_TOWARD_HEAD
	if lifter then
		hand = Vector3.new(hand.X, math.max(hand.Y, topNear(lifter, hand) + LIFTER_CLEARANCE), hand.Z)
	end
	local z = if lifter then math.max(DECK_Z, farthestAlong(lifter, floor) + BEHIND_LIFTER) else DECK_Z
	-- What its feet (about a stud deep) stand on: the back rail if they reach it, the deck, or the floor behind.
	local standOn = if z + 0.5 > DECK_BACK and z - 0.5 < RAIL_BACK then RAIL_TOP
		elseif z - 0.5 >= DECK_FRONT - 0.1 and z + 0.5 <= DECK_BACK then DECK_TOP
		else 0
	local at = floor:PointToWorldSpace(Vector3.new(0, rig.standHeight + standOn, z))
	local shoulderY = at.Y + shoulderOffset(rig, 0).Y
	return {
		root = CFrame.lookAt(at, at - towardHead),
		crouch = 0,
		back = 0,
		lean = 0,
		arms = math.acos(math.clamp((shoulderY - hand.Y) / rig.arm, -0.5, 1)),
	}
end

-- ---------------------------------------------------------------- each frame

local function apply(state: State, model: Model)
	local rig = state.rig
	for _, side in ipairs({ "Left", "Right" }) do
		turn(rig, side .. "Hip", state.crouch)
		turn(rig, side .. "Knee", -(state.crouch + state.back))
		turn(rig, side .. "Ankle", state.back)
		turn(rig, side .. "Shoulder", state.arms)
	end
	turn(rig, "Waist", -state.lean)
	if state.root then
		model:PivotTo(state.root)
	end
end

-- The points to walk through from `from` to the rack-local `to` (world, at standing height over the floor there), or nil
-- when it has no place yet (it is put straight there).
local function walkRoute(floor: CFrame, rig: Rig, from: CFrame?, to: Vector2): { Vector3 }?
	if from == nil then
		return nil
	end
	local start = floor:PointToObjectSpace(from.Position)
	local points = {}
	for _, point in ipairs(routeBetween(Vector2.new(start.X, start.Z), to)) do
		local world = floor:PointToWorldSpace(Vector3.new(point.X, 0, point.Y))
		table.insert(points, Vector3.new(world.X, groundAt(floor, point) + rig.standHeight, world.Z))
	end
	return points
end

-- One frame of walking the route: a steady pace, facing the way it goes, standing straight.
local function walkOn(state: State, model: Model, dt: number)
	local route = state.route :: { Vector3 }
	local root = state.root :: CFrame
	local position = root.Position
	local left = WALK_STUDS_PER_SECOND * dt
	while left > 0 and #route > 0 do
		local toNext = route[1] - position
		local distance = toNext.Magnitude
		if distance <= left then
			position = route[1]
			left -= distance
			table.remove(route, 1)
		else
			position += toNext.Unit * left
			left = 0
		end
	end
	local heading = if #route > 0 then flatUnit(route[1] - position, root.LookVector) else flatUnit(root.LookVector, -Vector3.zAxis)
	state.root = CFrame.lookAt(position, position + heading)
	local relax = 1 - math.exp(-FOLLOW_RATE * dt)
	state.crouch -= state.crouch * relax
	state.back -= state.back * relax
	state.lean -= state.lean * relax
	state.arms -= state.arms * relax
	apply(state, model)
	if #route == 0 then
		state.route = nil
		-- (Then it turns and settles at the slower step.)
		state.steppingUntil = os.clock() + STEP_SECONDS
		state.aside = state.asideAt ~= nil
	end
end

local function update(dt: number)
	local spotters = CollectionService:GetTagged(TAG)
	if #spotters == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local lifters = liftersByRack()
	local follow = 1 - math.exp(-FOLLOW_RATE * dt)
	for _, instance in ipairs(spotters) do
		if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
			continue
		end
		local model = instance
		if eye and (model:GetPivot().Position - eye).Magnitude > NEAR_STUDS then
			continue
		end
		local state = states[model]
		if state == nil then
			local rig = rigOf(model)
			if rig == nil then
				continue
			end
			state = { rig = rig, root = nil, crouch = 0, back = 0, lean = 0, arms = 0, lift = nil, aside = false,
				steppingUntil = 0, asideAt = nil, asideGround = 0, route = nil }
			states[model] = state
			model.Destroying:Connect(function()
				states[model] = nil
			end)
		end
		assert(state)
		-- Set for another lift: straight to the new place. Gliding there would take it through the bar and its plates.
		local rackLink = model:FindFirstChild("SpotterRack")
		local rackNow = if rackLink and rackLink:IsA("ObjectValue") then rackLink.Value else nil
		local liftNow = if rackNow then rackNow:GetAttribute("SpotterLift") else nil
		if state.lift ~= liftNow then
			state.lift = liftNow
			state.root = nil
			state.route = nil
			state.asideAt = nil
		end
		local floor = model:GetAttribute("SpotterFloor")
		if typeof(floor) ~= "CFrame" then
			continue
		end
		-- Making way (an entrance or a celebration): walk off to the spot, round the rack; and back once it's over.
		local spot = asideSpot(model)
		if spot and state.asideAt ~= spot then
			state.asideAt = spot
			state.asideGround = groundAt(floor, spot)
			state.route = walkRoute(floor, state.rig, state.root, spot)
		elseif spot == nil and state.asideAt ~= nil then
			state.asideAt = nil
			local home = targetPose(model, state.rig, lifters)
			local homeAt = if home then floor:PointToObjectSpace(home.root.Position) else nil
			state.route = if homeAt then walkRoute(floor, state.rig, state.root, Vector2.new(homeAt.X, homeAt.Z)) else nil
		end
		if state.route and state.root then
			walkOn(state, model, dt)
			continue
		end
		local cleared: Pose? = nil
		if spot then
			-- Waiting there, watching the lift spot.
			local at = floor:PointToWorldSpace(Vector3.new(spot.X, 0, spot.Y))
			local stand = Vector3.new(at.X, state.asideGround + state.rig.standHeight, at.Z)
			local toward = flatUnit(floor:PointToWorldSpace(LIFT_SPOT) - stand, -floor.ZVector)
			cleared = { root = CFrame.lookAt(stand, stand + toward), crouch = 0, back = 0, lean = 0, arms = 0 }
		end
		local target = cleared or targetPose(model, state.rig, lifters)
		if target == nil then
			continue
		end
		-- Just back from making way, or turning to watch: a slower step, not the bar-following snap.
		local aside = cleared ~= nil
		if aside ~= state.aside then
			state.aside = aside
			state.steppingUntil = os.clock() + STEP_SECONDS
		end
		local k = if state.root == nil then 1
			elseif os.clock() < state.steppingUntil then 1 - math.exp(-STEP_RATE * dt)
			else follow
		local root = if state.root then state.root:Lerp(target.root, k) else target.root
		local rise = target.root.Position.Y - root.Position.Y
		-- The back spotter stepping up (onto the rack's back rail) does it at once: catching up from below would
		-- sink its feet into the rail.
		state.root = if rise > 0 and model:GetAttribute("Role") == "Back" then root + Vector3.new(0, rise, 0) else root
		state.crouch += (target.crouch - state.crouch) * k
		state.back += (target.back - state.back) * k
		state.lean += (target.lean - state.lean) * k
		state.arms += (target.arms - state.arms) * k
		apply(state, model)
	end
end

function MeetSpotterAnimator.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		if instance:IsA("Model") then
			states[instance] = nil
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return MeetSpotterAnimator
