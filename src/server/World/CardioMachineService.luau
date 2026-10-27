--!strict
--[[
	CardioMachineService
	Server / World

	Lets players hop on the Cardio room's machines (GAME_DESIGN.md §27 "The
	Cardio room", user 2026-10-26: "players can hop on a machine for a fun
	running/cycling animation, no stats"). Fun only: nothing is saved, nothing
	is rewarded, and no stat, progression or lifting value is read or changed.

	Every Model tagged StarterGymConfig.CardioMachineTag (RoomProps tags them,
	with the machine's item in the "Kind" attribute) gets a "Hop on" prompt at
	its spot (StarterGymConfig.CardioMachines). When a player triggers it, the
	server checks that the player is alive, is not already on a machine, is not
	posed at a training rack, stands near the machine and that the machine is
	free; then it anchors their HumanoidRootPart on the machine's spot, facing
	the machine, and marks:

	  the character  "CardioMachine" = the machine's kind ("Treadmill", ...)
	  the machine    "Rider"         = the player's UserId

	The client's CardioMachineAnimator plays the motion from those marks (every
	client, for every rider). The player is let go, back on their feet in front
	of the machine, when they press Jump (CardioRemotes.HOP_OFF: the server only
	releases the sender, from the machine the server put them on), die,
	respawn, leave the game, or when the machine is removed.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarterGymConfig = require(Shared:WaitForChild("Config"):WaitForChild("StarterGymConfig"))
local CardioRemotes = require(Shared:WaitForChild("World"):WaitForChild("CardioRemotes"))

local CardioMachineService = {}

local MACHINE_ATTRIBUTE = "CardioMachine"
local RIDER_ATTRIBUTE = "Rider"
local KIND_ATTRIBUTE = "Kind"
-- A training rack's pose mark (StationPoses): a lifter at a rack cannot hop on.
local STATION_POSE_ATTRIBUTE = "StationPose"
local PROMPT_PART = "HopOnPoint"
-- How far past the machine's front edge a player is put down when they hop off.
local EXIT_CLEARANCE = 1.8
-- The farthest a player may stand from the spot when the prompt fires (the prompt's own reach plus slack).
local MAX_TRIGGER_DISTANCE = StarterGymConfig.CardioPromptDistanceStuds + 4
local HOP_OFF_COOLDOWN = 0.25
-- How far the thighs lift the hip joints above a seat.
local SEAT_CLEARANCE = 0.3

type Ride = {
	machine: Model,
	character: Model,
	connections: { RBXScriptConnection },
}

-- Who is on which machine. Ordinary (strong) tables: a forgotten entry would
-- leave a player anchored, so entries are removed on every way out.
local rides: { [Player]: Ride } = {}
local riderOf: { [Model]: Player } = {}
local lastHopOff: { [Player]: number } = {}
local started = false

type Body = { character: Model, root: BasePart, humanoid: Humanoid }

local function bodyOf(player: Player): Body?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil
	end
	return { character = character, root = root, humanoid = humanoid }
end

-- Height of the root part's centre above the floor when the character stands.
local function standingHeight(body: Body): number
	if body.humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 3
	end
	return body.humanoid.HipHeight + body.root.Size.Y / 2
end

-- How far the root part's centre sits above the hip joints (R15: measured on the character).
local function rootAboveHips(body: Body): number
	if body.humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 1
	end
	-- The hip joint lives in the upper leg: a classic Motor6D (its C0 is the joint's place on the lower
	-- torso, its Part0) or an AnimationConstraint of Roblox's newer avatar joints (its Attachment0).
	local upperLeg = body.character:FindFirstChild("LeftUpperLeg")
	local hip = upperLeg and upperLeg:FindFirstChild("LeftHip")
	local hipY: number? = nil
	if hip and hip:IsA("Motor6D") and hip.Part0 then
		hipY = (hip.Part0.CFrame * hip.C0).Position.Y
	elseif hip and hip:IsA("AnimationConstraint") and hip.Attachment0 then
		hipY = hip.Attachment0.WorldPosition.Y
	end
	return if hipY then body.root.Position.Y - hipY else 0.6
end

local function specOf(machine: Model): StarterGymConfig.CardioMachine?
	local kind = machine:GetAttribute(KIND_ATTRIBUTE)
	return if typeof(kind) == "string" then StarterGymConfig.CardioMachines[kind] else nil
end

-- The machine's spot in the world, facing the machine's back (+Z of its pivot).
local function spotFrame(machine: Model, spec: StarterGymConfig.CardioMachine): CFrame
	return machine:GetPivot() * CFrame.new(spec.spot) * CFrame.Angles(0, math.pi, 0)
end

local function setPromptEnabled(machine: Model, enabled: boolean)
	local point = machine:FindFirstChild(PROMPT_PART)
	local prompt = point and point:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = enabled
	end
end

local function release(player: Player)
	local ride = rides[player]
	if ride == nil then
		return
	end
	rides[player] = nil
	for _, connection in ipairs(ride.connections) do
		connection:Disconnect()
	end
	local machine = ride.machine
	if riderOf[machine] == player then
		riderOf[machine] = nil
		if machine.Parent then
			machine:SetAttribute(RIDER_ATTRIBUTE, nil)
			setPromptEnabled(machine, true)
		end
	end

	local character = ride.character
	character:SetAttribute(MACHINE_ATTRIBUTE, nil)
	-- Only the character we put on the machine: after a respawn the player has a new, unmarked one.
	local body = bodyOf(player)
	if body == nil or body.character ~= character or not body.root.Anchored then
		return
	end
	local pivot = machine:GetPivot()
	local _, size = machine:GetBoundingBox()
	local exitAt = pivot.Position + pivot.LookVector * (size.Z / 2 + EXIT_CLEARANCE)
	local floorY = pivot.Position.Y
	if body.humanoid.Health > 0 then
		local position = Vector3.new(exitAt.X, floorY + standingHeight(body), exitAt.Z)
		character:PivotTo(CFrame.lookAt(position, position + pivot.LookVector))
	end
	body.root.Anchored = false
end

--[[
	Puts `player` on `machine` if everything allows it. Called by the machine's
	prompt (also usable from a Studio test).
]]
function CardioMachineService.hopOn(player: Player, machine: Model): boolean
	if rides[player] or riderOf[machine] or machine.Parent == nil then
		return false
	end
	local spec = specOf(machine)
	local body = bodyOf(player)
	if spec == nil or body == nil or body.humanoid.Health <= 0 or body.root.Anchored then
		return false
	end
	if body.character:GetAttribute(STATION_POSE_ATTRIBUTE) ~= nil then
		return false
	end
	local spot = spotFrame(machine, spec)
	if (body.root.Position - spot.Position).Magnitude > MAX_TRIGGER_DISTANCE + body.root.Size.Y then
		return false
	end

	local height = if spec.seated then rootAboveHips(body) + SEAT_CLEARANCE else standingHeight(body)
	body.root.Anchored = true
	body.character:PivotTo(spot * CFrame.new(0, height, 0))
	body.character:SetAttribute(MACHINE_ATTRIBUTE, machine:GetAttribute(KIND_ATTRIBUTE))
	machine:SetAttribute(RIDER_ATTRIBUTE, player.UserId)
	setPromptEnabled(machine, false)

	local ride: Ride = { machine = machine, character = body.character, connections = {} }
	rides[player] = ride
	riderOf[machine] = player
	table.insert(ride.connections, body.humanoid.Died:Connect(function()
		release(player)
	end))
	table.insert(ride.connections, body.character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			release(player)
		end
	end))
	table.insert(ride.connections, machine.Destroying:Connect(function()
		release(player)
	end))
	return true
end

-- The "Hop on" prompt at the machine's spot.
local function setUpMachine(instance: Instance)
	if not instance:IsA("Model") or instance:FindFirstChild(PROMPT_PART) then
		return
	end
	local machine = instance
	local spec = specOf(machine)
	if spec == nil then
		warn(string.format("[CardioMachineService] %s has no known Kind; no prompt", machine:GetFullName()))
		return
	end
	local point = Instance.new("Part")
	point.Name = PROMPT_PART
	point.Size = Vector3.one
	point.Transparency = 1
	point.Anchored = true
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point.CFrame = spotFrame(machine, spec) * CFrame.new(0, 2.5, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hop on"
	prompt.ObjectText = spec.label
	prompt.HoldDuration = StarterGymConfig.CardioPromptHoldSeconds
	prompt.MaxActivationDistance = StarterGymConfig.CardioPromptDistanceStuds
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	point.Parent = machine
	prompt.Triggered:Connect(function(player)
		CardioMachineService.hopOn(player, machine)
	end)
	machine.Destroying:Connect(function()
		local rider = riderOf[machine]
		if rider then
			release(rider)
		end
	end)
end

function CardioMachineService.start()
	if started then
		return
	end
	started = true

	local remotes = CardioRemotes.createOnServer(ReplicatedStorage)
	remotes.hopOff.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastHopOff[player] or 0) < HOP_OFF_COOLDOWN then
			return
		end
		lastHopOff[player] = now
		release(player)
	end)

	for _, machine in ipairs(CollectionService:GetTagged(StarterGymConfig.CardioMachineTag)) do
		setUpMachine(machine)
	end
	CollectionService:GetInstanceAddedSignal(StarterGymConfig.CardioMachineTag):Connect(setUpMachine)

	Players.PlayerRemoving:Connect(function(player)
		release(player)
		lastHopOff[player] = nil
	end)
end

return CardioMachineService
