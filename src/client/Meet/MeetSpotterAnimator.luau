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
-- The hands' gap under the bar while the lifter has it, and once it is let go (carried).
local HOVER = 0.35
local CARRY = 0.15
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
local BENCH_OVER_BAR = 0.75
local BENCH_TOWARD_HEAD = 0.35
local LIFTER_CLEARANCE = 0.5
local NEAR_HANDS_STUDS = 3
-- Spotters farther than this from the camera are left as they are.
local NEAR_STUDS = 220
-- How fast a spotter catches up with where it should be (per second).
local FOLLOW_RATE = 12

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
type State = { rig: Rig, root: CFrame?, crouch: number, back: number, lean: number, arms: number }

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

-- How far along the bar (from its middle) the spotters' hands go: under the sleeve, past the plates and collar.
local function handReach(barbell: Instance, shaft: BasePart): number
	local plates, sleeveEnd = 0, 0
	for _, part in ipairs(barbell:GetDescendants()) do
		if part:IsA("BasePart") then
			local x = math.abs(shaft.CFrame:PointToObjectSpace(part.Position).X)
			if part.Name == "Bar_Sleeves" then
				sleeveEnd = part.Size.X / 2
			elseif string.sub(part.Name, 1, 5) == "Plate" or string.sub(part.Name, 1, 6) == "Collar" then
				plates = math.max(plates, x + part.Size.X / 2)
			end
		end
	end
	return math.max(plates + 0.25, (plates + sleeveEnd) / 2)
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
			state = { rig = rig, root = nil, crouch = 0, back = 0, lean = 0, arms = 0 }
			states[model] = state
			model.Destroying:Connect(function()
				states[model] = nil
			end)
		end
		assert(state)
		local target = targetPose(model, state.rig, lifters)
		if target == nil then
			continue
		end
		local k = if state.root == nil then 1 else follow
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
