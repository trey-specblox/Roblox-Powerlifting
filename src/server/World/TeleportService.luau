--!strict
--[[
	TeleportService
	Server / World

	The TELEPORT menu (user 2026-10-30: "a teleport button on the left, where
	you can tp to any place"). The client only asks for a place by its id
	(TeleportRemotes.REQUEST); the server checks everything and moves the
	player itself. The places are TeleportConfig.Destinations.

	A teleport is refused while the player:
		- is dead or has no character, or is held in place (posed at a rack,
		  standing on a meet platform)
		- is in a lift attempt
		- rides a cardio machine or is posed at a training rack
		- is in their private Mock Meet room
		- lifts in the running Local meet (LEAVE first)
		- teleported less than CooldownSeconds ago
	Leaving the Local meet venue this way takes them off its sign-up list, the
	same as its EXIT.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TeleportConfig = require(Shared:WaitForChild("Config"):WaitForChild("TeleportConfig"))
local TeleportRemotes = require(Shared:WaitForChild("World"):WaitForChild("TeleportRemotes"))

local ServerFolder = script.Parent.Parent
local LocalMeetService = require(ServerFolder:WaitForChild("Meet"):WaitForChild("LocalMeetService"))
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))

local TeleportService = {}

-- Marks other systems put on a character (the same ones the Local meet's doors check).
local BUSY_ATTRIBUTES = { "CardioMachine", "StationPose" }
local MOCK_MEET_ATTRIBUTE = "MockMeetSlot"
local STREAM_TIMEOUT_SECONDS = 5
-- How far above the landing spot the floor search starts, and how far down it looks (studs).
local FLOOR_SEARCH_UP, FLOOR_SEARCH_DOWN = 6, 20

type Body = { character: Model, root: BasePart, humanoid: Humanoid }

local started = false
local lastTeleport: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}

local function bodyOf(player: Player): Body?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil
	end
	return { character = character, root = root, humanoid = humanoid }
end

-- The floor under `position` (ignoring the player), or nil.
local function floorUnder(position: Vector3, body: Body): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { body.character }
	local hit = Workspace:Raycast(position + Vector3.new(0, FLOOR_SEARCH_UP, 0), Vector3.new(0, -FLOOR_SEARCH_DOWN, 0), params)
	return if hit then hit.Position else nil
end

-- Where a gym place is: the spot on the floor and the way to face (nil when it cannot be found).
local function spotFor(destination: TeleportConfig.Destination): (Vector3?, Vector3?)
	if destination.point then
		return destination.point, destination.face or Vector3.zAxis
	end
	if destination.room then
		local gym = Workspace:FindFirstChild("StarterGym")
		local rooms = gym and gym:FindFirstChild("Rooms")
		local region = rooms and rooms:FindFirstChild("Room_" .. destination.room)
		local door = region and region:GetAttribute("DoorCentre")
		if region == nil or not region:IsA("BasePart") or typeof(door) ~= "Vector3" then
			return nil, nil
		end
		local inward = Vector3.new(region.Position.X - door.X, 0, region.Position.Z - door.Z)
		if inward.Magnitude < 0.01 then
			return door, Vector3.zAxis
		end
		inward = inward.Unit
		return door + inward * TeleportConfig.RoomInsetStuds, inward
	end
	if destination.tag then
		for _, tagged in ipairs(CollectionService:GetTagged(destination.tag)) do
			if tagged:IsA("BasePart") and tagged:IsDescendantOf(Workspace) then
				local look = tagged.CFrame.LookVector
				return tagged.Position, Vector3.new(look.X, 0, look.Z)
			end
		end
	end
	return nil, nil
end

-- Everything that stops a teleport before anything moves. Returns the reason, or nil when it may go.
local function refusal(player: Player, body: Body?): string?
	if body == nil or body.humanoid.Health <= 0 then
		return "You can't teleport right now."
	end
	if LiftAttemptService.isAttemptActive(player) then
		return "Finish your lift first."
	end
	for _, attribute in ipairs(BUSY_ATTRIBUTES) do
		if body.character:GetAttribute(attribute) ~= nil then
			return "Get off the machine first."
		end
	end
	if player:GetAttribute(MOCK_MEET_ATTRIBUTE) ~= nil then
		return "Leave the Mock Meet first."
	end
	if body.root.Anchored then
		return "You can't teleport right now."
	end
	return nil
end

local function moveTo(player: Player, body: Body, destination: TeleportConfig.Destination): (boolean, string?)
	local spot, face = spotFor(destination)
	if spot == nil then
		return false, "That place isn't open right now."
	end
	pcall(function()
		player:RequestStreamAroundAsync(spot, STREAM_TIMEOUT_SECONDS)
	end)
	local nowBody = bodyOf(player)
	if player.Parent == nil or nowBody == nil or nowBody.character ~= body.character or nowBody.humanoid.Health <= 0 then
		return false, nil
	end
	local floor = floorUnder(spot, body) or spot
	local standing = body.humanoid.HipHeight + body.root.Size.Y / 2 + 0.1
	local at = floor + Vector3.new(0, standing, 0)
	local look = if face and face.Magnitude > 0.01 then face.Unit else Vector3.zAxis
	body.root.AssemblyLinearVelocity = Vector3.zero
	body.character:PivotTo(CFrame.lookAt(at, at + look))
	return true, nil
end

local function teleport(player: Player, destinationId: any): (boolean, string?)
	if typeof(destinationId) ~= "string" then
		return false, nil
	end
	local destination = TeleportConfig.find(destinationId)
	if destination == nil then
		return false, "Unknown place."
	end
	local time = os.clock()
	if busy[player] or time - (lastTeleport[player] or -math.huge) < TeleportConfig.CooldownSeconds then
		return false, "Wait a moment before teleporting again."
	end
	local body = bodyOf(player)
	local problem = refusal(player, body)
	if problem or body == nil then
		return false, problem
	end
	busy[player] = true
	lastTeleport[player] = time
	local ok, why
	if destination.venue then
		ok, why = LocalMeetService.teleportIn(player)
	else
		-- Out of the Local meet venue first (a lifter in the running meet stays).
		ok, why = LocalMeetService.teleportOut(player)
		if ok then
			ok, why = moveTo(player, body, destination)
		end
	end
	busy[player] = nil
	if ok then
		print(string.format("[TeleportService] %s -> %s", player.Name, destination.id))
	end
	return ok, why
end

function TeleportService.start()
	if started then
		return
	end
	started = true
	local remote = TeleportRemotes.createOnServer(ReplicatedStorage)
	remote.OnServerInvoke = function(player: Player, destinationId: any)
		local ok, result, message = pcall(teleport, player, destinationId)
		if not ok then
			warn("[TeleportService] " .. tostring(result))
			busy[player] = nil
			return false, "Teleport failed. Try again."
		end
		return result, message
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
		busy[player] = nil
	end)
end

return TeleportService
