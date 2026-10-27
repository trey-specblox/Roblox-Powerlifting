--!strict
--[[
	CardioMachineAnimator
	Client / World

	Makes the Cardio room's riders move (GAME_DESIGN.md §27 "The Cardio room":
	hop on a machine "for a fun running/cycling animation, no stats"). Visual
	only: the only thing it sends is CardioRemotes.HOP_OFF when YOU press Jump
	while on a machine; it changes no game state.

	The server's CardioMachineService marks a rider's character with
	"CardioMachine" = the machine's kind and the machine with "Rider" = their
	UserId. From those marks, on every client and for every rider:

	  Treadmill     YOUR client plays your character's own run animation
	                (from its Animate script), looped; Roblox shows it to
	                everyone.
	  ExerciseBike  pedalling, seated: the crank turns and the feet stay on its
	                pedals, the hands on the grips (IKControl).
	  Rower         the stroke: the seat slides, legs drive, arms pull; the
	                handle follows the hands on its chain.
	  SkiErg        double-pole pulls with a hip hinge; the handles follow the
	                hands on their cords.

	The procedural motions set the R15 joints' Motor6D.Transform after the
	animations each frame, and are timed from the server clock so every client
	shows the same stroke. R6 characters only get the treadmill run.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarterGymConfig = require(Shared:WaitForChild("Config"):WaitForChild("StarterGymConfig"))
local CardioRemotes = require(Shared:WaitForChild("World"):WaitForChild("CardioRemotes"))

local CardioMachineAnimator = {}

local MACHINE_ATTRIBUTE = "CardioMachine"
local RIDER_ATTRIBUTE = "Rider"
local FADE_SECONDS = 0.2
local HOP_OFF_COOLDOWN = 0.4

-- Tempos, in strokes (or pedal turns) per second.
local CYCLE_HZ = 1.1
local ROW_HZ = 0.45
local SKI_HZ = 0.55
local ROW_SLIDE = 1.3 -- how far the seat (and the rower) slides, in studs

local localPlayer = Players.LocalPlayer
local started = false
local TAU = 2 * math.pi

-- ---------------------------------------------------------------- poses

-- R15 joints by name, each the Motor6D inside its part.
local JOINT_PARTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
}

type Pose = { [string]: CFrame }

-- A bend about the joint's X axis, in degrees: + swings a limb forward (hip, shoulder) or folds a
-- forearm forward (elbow); a knee bends with -; the waist leans forward with -.
local function bend(degrees: number): CFrame
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

local function both(pose: Pose, joint: string, left: CFrame, right: CFrame?)
	pose["Left" .. joint] = left
	pose["Right" .. joint] = right or left
end

-- The crank's angle for pedalling, 0 .. 2 pi (a CFrame keeps angles in single precision, so the raw
-- server-clock angle would barely move). The bike's legs and hands are not posed joint by joint: they
-- reach for the pedals and the grips (see "reaching" below), so the feet stay on the pedals.
local function crankAngle(t: number): number
	return (t * CYCLE_HZ % 1) * TAU
end

-- One rowing stroke. Returns the pose and how far (along the rower's own Z) the body has slid.
local function rowPose(t: number): (Pose, number)
	local phase = t * ROW_HZ % 1
	-- 0 at the catch, 1 at the finish: a quicker drive (40%), a slower recovery.
	local s = if phase < 0.4 then (1 - math.cos(phase / 0.4 * math.pi)) / 2 else (1 + math.cos((phase - 0.4) / 0.6 * math.pi)) / 2
	local arms = math.clamp((s - 0.45) / 0.55, 0, 1)
	local pose: Pose = { Waist = bend(-25 + 45 * s) }
	both(pose, "Hip", bend(118 - 33 * s))
	both(pose, "Knee", bend(-(128 - 122 * s)))
	both(pose, "Ankle", bend(18 - 22 * s))
	both(pose, "Shoulder", bend(86 - 96 * arms))
	both(pose, "Elbow", bend(118 * arms))
	local slide = -(1 - s) * ROW_SLIDE
	pose.Root = CFrame.new(0, 0, slide)
	return pose, slide
end

-- One ski erg pull: arms from overhead down past the hips with a hip hinge.
local function skiPose(t: number): Pose
	local phase = t * SKI_HZ % 1
	local s = if phase < 0.45 then (1 - math.cos(phase / 0.45 * math.pi)) / 2 else (1 + math.cos((phase - 0.45) / 0.55 * math.pi)) / 2
	local pose: Pose = { Waist = bend(-38 * s) }
	both(pose, "Hip", bend(22 * s))
	both(pose, "Knee", bend(-30 * s))
	both(pose, "Shoulder", bend(165 - 180 * s))
	both(pose, "Elbow", bend(15 + 35 * math.sin(math.pi * s)))
	return pose
end

--[[
	A character's joints: classic Motor6Ds, or the AnimationConstraints of
	Roblox's newer avatar joints (found on the user's own avatar, 2026-10-26).
	Both take the pose through their Transform.
]]
type Joint = Motor6D | AnimationConstraint

local function isJoint(instance: Instance?): boolean
	return instance ~= nil and (instance:IsA("Motor6D") or instance:IsA("AnimationConstraint"))
end

local function setTransform(joint: Joint, frame: CFrame)
	(joint :: any).Transform = frame
end

local function jointsOf(character: Model): { [string]: Joint }?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local joints: { [string]: Joint } = {}
	for joint, partName in pairs(JOINT_PARTS) do
		local part = character:FindFirstChild(partName)
		local found = part and part:FindFirstChild(joint)
		if found and isJoint(found) then
			joints[joint] = found :: any
		end
	end
	return joints
end

-- ---------------------------------------------------------------- the machines' moving pieces

type MachineState = {
	-- Each moving piece's place and size when nobody is on the machine.
	rest: { [BasePart]: { cframe: CFrame, size: Vector3 } },
	-- Ski erg: which hand holds which handle ("Left" / "Right" piece -> hand part name).
	hands: { [string]: string }?,
	moved: boolean,
}

-- Ordinary (strong) table; an entry is removed when its machine is destroyed.
local machineStates: { [Model]: MachineState } = {}

local function piece(machine: Model, kind: string, name: string): BasePart?
	local found = machine:FindFirstChild(kind .. "_" .. name, true)
	return if found and found:IsA("BasePart") then found else nil
end

local function stateOf(machine: Model): MachineState
	local state = machineStates[machine]
	if state then
		return state
	end
	local newState: MachineState = { rest = {}, moved = false }
	machineStates[machine] = newState
	machine.Destroying:Connect(function()
		machineStates[machine] = nil
	end)
	return newState
end

local function remember(state: MachineState, part: BasePart?)
	if part and state.rest[part] == nil then
		state.rest[part] = { cframe = part.CFrame, size = part.Size }
	end
end

local function restore(state: MachineState)
	for part, rest in pairs(state.rest) do
		part.Size = rest.size
		part.CFrame = rest.cframe
	end
	state.hands = nil
	state.moved = false
end

--[[
	Stretches a chain or cord piece from `from` to `to`. Its length runs along whichever of its own axes is
	longest at rest (the rower's chain along Z, the ski erg's hanging cords along Y): stretching the wrong axis
	flattens a cord into a sheet (seen by the user, 2026-10-26).
]]
local function stretch(part: BasePart, rest: { cframe: CFrame, size: Vector3 }, from: Vector3, to: Vector3)
	local length = math.max((to - from).Magnitude, 0.05)
	local size = rest.size
	local aim = CFrame.lookAt((from + to) / 2, to) -- its -Z toward `to`
	if size.Y >= size.X and size.Y >= size.Z then
		part.Size = Vector3.new(size.X, length, size.Z)
		part.CFrame = aim * CFrame.Angles(-math.pi / 2, 0, 0) -- its Y toward `to`
	elseif size.X >= size.Z then
		part.Size = Vector3.new(length, size.Y, size.Z)
		part.CFrame = aim * CFrame.Angles(0, math.pi / 2, 0) -- its X toward `to`
	else
		part.Size = Vector3.new(size.X, size.Y, length)
		part.CFrame = aim
	end
end

local function handPosition(character: Model, name: string): Vector3?
	local hand = character:FindFirstChild(name)
	return if hand and hand:IsA("BasePart") then hand.Position else nil
end

local function moveRower(machine: Model, state: MachineState, character: Model, slide: number)
	local spec = StarterGymConfig.CardioMachines.Rower
	local pivot = machine:GetPivot()
	local seat, handle, chain = piece(machine, "Rower", "Pad"), piece(machine, "Rower", "Handle"), piece(machine, "Rower", "Chain")
	remember(state, seat)
	remember(state, handle)
	remember(state, chain)
	-- The body slides along the rider's own Z, which is the machine's LookVector.
	if seat then
		seat.CFrame = state.rest[seat].cframe + pivot.LookVector * slide
	end
	local left, right = handPosition(character, "LeftHand"), handPosition(character, "RightHand")
	if handle and left and right then
		handle.CFrame = CFrame.new((left + right) / 2) * pivot.Rotation
		if chain and spec.chainFrom then
			stretch(chain, state.rest[chain], (pivot * CFrame.new(spec.chainFrom)).Position, handle.Position)
		end
	end
end

local function moveSkiErg(machine: Model, state: MachineState, character: Model)
	local spec = StarterGymConfig.CardioMachines.SkiErg
	local pivot = machine:GetPivot()
	local pulleys = spec.pulleys or {}
	local handles = { Left = piece(machine, "SkiErg", "HandleLeft"), Right = piece(machine, "SkiErg", "HandleRight") }
	local cords = { Left = piece(machine, "SkiErg", "CordLeft"), Right = piece(machine, "SkiErg", "CordRight") }
	for _, side in ipairs({ "Left", "Right" }) do
		remember(state, handles[side])
		remember(state, cords[side])
	end
	-- Which hand holds which handle: decided once per ride, by which hand is nearer.
	if state.hands == nil then
		local leftHand = handPosition(character, "LeftHand")
		local handle = handles.Left
		if leftHand == nil or handle == nil then
			return
		end
		local rightHand = handPosition(character, "RightHand") or leftHand
		local leftNearer = (leftHand - handle.Position).Magnitude <= (rightHand - handle.Position).Magnitude
		state.hands = if leftNearer then { Left = "LeftHand", Right = "RightHand" } else { Left = "RightHand", Right = "LeftHand" }
	end
	local hands = state.hands :: { [string]: string }
	for _, side in ipairs({ "Left", "Right" }) do
		local handle, cord = handles[side], cords[side]
		local hand = handPosition(character, hands[side])
		if handle and hand then
			handle.CFrame = CFrame.new(hand) * pivot.Rotation
			-- The cord from the nearer pulley to the handle's top.
			if cord then
				local best: Vector3? = nil
				for _, offset in ipairs(pulleys) do
					local at = (pivot * CFrame.new(offset)).Position
					if best == nil or (at - handle.Position).Magnitude < (best - handle.Position).Magnitude then
						best = at
					end
				end
				if best then
					stretch(cord, state.rest[cord], best, handle.Position + pivot.UpVector * (state.rest[handle].size.Y / 2))
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- reaching (the bike)

--[[
	The bike's rider reaches with Roblox's IKControl (user 2026-10-26: the first
	joint-by-joint pedalling "is not even pedalling the right way"): each foot
	is held on its pedal and each hand on its grip, whatever the avatar's
	joints are (classic Motor6Ds or the newer AnimationConstraints). Every
	client makes these for every rider on its own screen; they are removed when
	the rider gets off.
]]
local CHAINS = {
	LeftFoot = "LeftUpperLeg",
	RightFoot = "RightUpperLeg",
	LeftHand = "LeftUpperArm",
	RightHand = "RightUpperArm",
}

type Reach = { controls: { Instance }, targets: { [string]: Attachment }, poles: { [string]: Attachment } }

-- Ordinary (strong) table; entries are removed when the rider gets off or their character goes.
local reaches: { [Model]: Reach } = {}

local function dropReach(character: Model)
	local reach = reaches[character]
	reaches[character] = nil
	if reach then
		for _, instance in ipairs(reach.controls) do
			instance:Destroy()
		end
	end
end

local function reachOf(character: Model): Reach?
	local existing = reaches[character]
	if existing then
		return existing
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local reach: Reach = { controls = {}, targets = {}, poles = {} }
	for effector, chainRoot in pairs(CHAINS) do
		local endPart, rootPart = character:FindFirstChild(effector), character:FindFirstChild(chainRoot)
		if endPart == nil or rootPart == nil then
			continue
		end
		local target = Instance.new("Attachment")
		target.Name = "CardioReach_" .. effector
		target.Parent = Workspace.Terrain
		local pole = Instance.new("Attachment")
		pole.Name = "CardioPole_" .. effector
		pole.Parent = Workspace.Terrain
		local control = Instance.new("IKControl")
		control.Name = "CardioReach_" .. effector
		control.Type = Enum.IKControlType.Position
		control.ChainRoot = rootPart
		control.EndEffector = endPart
		control.Target = target
		control.Pole = pole
		control.SmoothTime = 0
		control.Parent = humanoid
		reach.targets[effector] = target
		reach.poles[effector] = pole
		table.insert(reach.controls, control)
		table.insert(reach.controls, target)
		table.insert(reach.controls, pole)
	end
	reaches[character] = reach
	return reach
end

-- The bike's moving parts and its rider's reach, at crank angle `theta`.
local function moveBike(machine: Model, state: MachineState, character: Model, theta: number)
	local pivot = machine:GetPivot()
	local crank = piece(machine, "ExerciseBike", "Crank")
	remember(state, crank)
	if crank == nil then
		return
	end
	-- Forward pedalling: the front pedal pushes down. The rider faces the machine's +Z.
	crank.CFrame = state.rest[crank].cframe * CFrame.Angles(theta, 0, 0)
	local reach = reachOf(character)
	if reach == nil then
		return
	end
	local spec = StarterGymConfig.CardioMachines.ExerciseBike
	local forward, up = -pivot.LookVector, pivot.UpVector
	-- Each foot on its pedal (just above it), the knee bending up and forward.
	for effector, offset in pairs(spec.feet or {}) do
		local target, pole = reach.targets[effector], reach.poles[effector]
		if target and pole then
			local pedal = (crank.CFrame * CFrame.new(offset)).Position
			target.WorldPosition = pedal + up * 0.15
			pole.WorldPosition = pedal + forward * 2.5 + up * 3
		end
	end
	-- Each hand on its grip.
	for effector, offset in pairs(spec.hands or {}) do
		local target, pole = reach.targets[effector], reach.poles[effector]
		if target and pole then
			local grip = (pivot * CFrame.new(offset)).Position
			local outward = pivot:VectorToWorldSpace(Vector3.new(math.sign(offset.X), 0, 0))
			target.WorldPosition = grip
			-- Elbows bend down, back and a little out.
			pole.WorldPosition = grip - forward * 1 - up * 2 + outward * 1.5
		end
	end
end

-- ---------------------------------------------------------------- every frame

type Rider = { character: Model, kind: string, machine: Model? }

local function ridersNow(): { Rider }
	local machinesByRider: { [number]: Model } = {}
	for _, instance in ipairs(CollectionService:GetTagged(StarterGymConfig.CardioMachineTag)) do
		local rider = instance:GetAttribute(RIDER_ATTRIBUTE)
		if instance:IsA("Model") and typeof(rider) == "number" then
			machinesByRider[rider] = instance
		end
	end
	local riders: { Rider } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local kind = character and character:GetAttribute(MACHINE_ATTRIBUTE)
		if character and typeof(kind) == "string" then
			table.insert(riders, { character = character, kind = kind, machine = machinesByRider[player.UserId] })
		end
	end
	return riders
end

-- Riders whose joints this client set last frame, to put them straight back when they hop off.
local posed: { [Model]: { Joint } } = {}
-- The latest rowing slide per rower (the pieces follow in PreRender).
local slides: { [Model]: number } = {}

local function applyPoses()
	local t = Workspace:GetServerTimeNow()
	local still: { [Model]: boolean } = {}
	table.clear(slides)
	for _, rider in ipairs(ridersNow()) do
		local pose: Pose? = nil
		if rider.kind == "Rower" then
			local rowing, slide = rowPose(t)
			pose = rowing
			if rider.machine then
				slides[rider.machine] = slide
			end
		elseif rider.kind == "SkiErg" then
			pose = skiPose(t)
		end
		local joints = if pose then jointsOf(rider.character) else nil
		if pose and joints then
			local set: { Joint } = {}
			for name, frame in pairs(pose) do
				local joint = joints[name]
				if joint then
					setTransform(joint, frame)
					table.insert(set, joint)
				end
			end
			posed[rider.character] = set
			still[rider.character] = true
		end
	end
	for character, joints in pairs(posed) do
		if not still[character] then
			for _, joint in ipairs(joints) do
				setTransform(joint, CFrame.identity)
			end
			posed[character] = nil
		end
	end
end

local function movePieces()
	local t = Workspace:GetServerTimeNow()
	local busy: { [Model]: boolean } = {}
	local reaching: { [Model]: boolean } = {}
	for _, rider in ipairs(ridersNow()) do
		local machine = rider.machine
		if machine == nil then
			continue
		end
		local state = stateOf(machine)
		if rider.kind == "ExerciseBike" then
			moveBike(machine, state, rider.character, crankAngle(t))
			reaching[rider.character] = true
		elseif rider.kind == "Rower" then
			moveRower(machine, state, rider.character, slides[machine] or 0)
		elseif rider.kind == "SkiErg" then
			moveSkiErg(machine, state, rider.character)
		else
			continue
		end
		state.moved = true
		busy[machine] = true
	end
	for machine, state in pairs(machineStates) do
		if state.moved and not busy[machine] then
			restore(state)
		end
	end
	for character in pairs(reaches) do
		if not reaching[character] then
			dropReach(character)
		end
	end
end

-- ---------------------------------------------------------------- your own character

local runTrack: AnimationTrack? = nil

local function stopRun()
	local track = runTrack
	runTrack = nil
	if track then
		track:Stop(FADE_SECONDS)
	end
end

-- The character's own run animation (from its Animate script), so it matches the avatar.
local function runAnimationOf(character: Model): Animation?
	local animate = character:FindFirstChild("Animate")
	local run = animate and animate:FindFirstChild("run")
	local animation = run and run:FindFirstChildOfClass("Animation")
	return animation
end

local function applyOwnRun(character: Model)
	local kind = character:GetAttribute(MACHINE_ATTRIBUTE)
	if kind ~= "Treadmill" then
		stopRun()
		return
	end
	if runTrack then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animation = runAnimationOf(character)
	if animator == nil or animation == nil then
		return
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(FADE_SECONDS)
	runTrack = track
end

local function watchOwnCharacter(character: Model)
	stopRun()
	character:GetAttributeChangedSignal(MACHINE_ATTRIBUTE):Connect(function()
		applyOwnRun(character)
	end)
	applyOwnRun(character)
end

function CardioMachineAnimator.start()
	if started then
		return
	end
	started = true

	-- The remote is created by the server at start-up; wait for it without holding up the other systems.
	task.spawn(function()
		local remotes = CardioRemotes.waitForClient(ReplicatedStorage)
		local lastHopOff = 0
		UserInputService.JumpRequest:Connect(function()
			local character = localPlayer.Character
			local now = os.clock()
			if character and character:GetAttribute(MACHINE_ATTRIBUTE) ~= nil and now - lastHopOff > HOP_OFF_COOLDOWN then
				lastHopOff = now
				remotes.hopOff:FireServer()
			end
		end)
	end)

	localPlayer.CharacterAdded:Connect(watchOwnCharacter)
	localPlayer.CharacterRemoving:Connect(stopRun)
	if localPlayer.Character then
		watchOwnCharacter(localPlayer.Character)
	end

	-- Joints after the animations have run; the machines' pieces just before drawing, from the posed hands.
	RunService.PreSimulation:Connect(applyPoses)
	RunService.PreRender:Connect(movePieces)
end

return CardioMachineAnimator
