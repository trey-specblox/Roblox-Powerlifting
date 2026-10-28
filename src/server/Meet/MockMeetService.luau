--!strict
--[[
	MockMeetService
	Server / Meet

	The Mock Meet's check-in and the move in and out of the private rooms
	(GAME_DESIGN.md §29.10 "The Solo meet — first build", user 2026-10-27).
	Part 1: no lifting yet, and nothing is saved, rewarded or read from player
	data.

	The check-in point in the gym's Mock Meet Room (tagged
	MockMeetConfig.CheckInTag by RoomProps) gets a "Start Mock Meet" prompt.
	When a player triggers it, the server checks that the player is alive, on
	their feet (not on a cardio machine or posed at a rack), near the desk and
	not already in a room, and that a slot is free. Then it builds the player's
	own room (MockMeetArena), streams it in around them and moves them there,
	and sets the player attribute MockMeetConfig.SlotAttribute (the client shows
	the Leave button from it).

	The player goes back to where they checked in when they press Leave
	(MockMeetRemotes.LEAVE: the server only moves the sender, out of the room
	the server put them in). Dying, respawning or leaving the game also ends it;
	in every case the room is cleared away.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MockMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("MockMeetConfig"))
local MockMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("MockMeetRemotes"))

local MockMeetArena = require(script.Parent:WaitForChild("MockMeetArena"))

local MockMeetService = {}

-- Marks other systems put on a character: a cardio rider or a lifter posed at a rack cannot check in.
local BUSY_ATTRIBUTES = { "CardioMachine", "StationPose" }
-- The farthest a player may stand from the check-in point when the prompt fires (its reach plus slack).
local MAX_TRIGGER_DISTANCE = MockMeetConfig.PromptDistanceStuds + 4
local STREAM_TIMEOUT_SECONDS = 5

type Body = { character: Model, root: BasePart, humanoid: Humanoid }

type Visit = {
	room: MockMeetArena.Room,
	character: Model,
	-- Where the player stood when they checked in; Leave puts them back there.
	returnTo: CFrame,
	connections: { RBXScriptConnection },
}

-- Who is in which room. Entries are removed on every way out, so no room is left behind.
local visits: { [Player]: Visit } = {}
local slotOwner: { [number]: Player? } = {}
-- Players between the prompt and arriving (the room streams in first), so a double trigger does nothing.
local entering: { [Player]: boolean } = {}
local lastLeave: { [Player]: number } = {}
local started = false

local function log(message: string, ...: any)
	print("[MockMeetService] " .. string.format(message, ...))
end

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

local function freeSlot(): number?
	for slot = 1, MockMeetConfig.MaxSlots do
		if slotOwner[slot] == nil then
			return slot
		end
	end
	return nil
end

--[[
	Ends a visit: clears the room, and moves the player back to where they
	checked in when `sendBack` is true and they still have the same, living
	character.
]]
local function finish(player: Player, sendBack: boolean)
	local visit = visits[player]
	if visit == nil then
		return
	end
	visits[player] = nil
	for _, connection in ipairs(visit.connections) do
		connection:Disconnect()
	end
	if slotOwner[visit.room.slot] == player then
		slotOwner[visit.room.slot] = nil
	end
	if player.Parent then
		player:SetAttribute(MockMeetConfig.SlotAttribute, nil)
	end

	local body = bodyOf(player)
	if sendBack and body and body.character == visit.character and body.humanoid.Health > 0 then
		local position = visit.returnTo.Position
		pcall(function()
			player:RequestStreamAroundAsync(position, STREAM_TIMEOUT_SECONDS)
		end)
		-- The player may have left or died while the gym streamed back in.
		if player.Parent and body.character.Parent and body.humanoid.Health > 0 then
			body.character:PivotTo(visit.returnTo)
		end
	end
	MockMeetArena.clear(visit.room)
	log("%s left mock meet room %d", player.Name, visit.room.slot)
end

--[[
	Moves `player` into their own new room if everything allows it. Called by the
	check-in prompt (also usable from a Studio test). Returns whether they went.
]]
function MockMeetService.checkIn(player: Player, point: BasePart): boolean
	if visits[player] or entering[player] then
		return false
	end
	local body = bodyOf(player)
	if body == nil or body.humanoid.Health <= 0 or body.root.Anchored then
		return false
	end
	for _, attribute in ipairs(BUSY_ATTRIBUTES) do
		if body.character:GetAttribute(attribute) ~= nil then
			return false
		end
	end
	if (body.root.Position - point.Position).Magnitude > MAX_TRIGGER_DISTANCE + body.root.Size.Y then
		return false
	end
	local slot = freeSlot()
	if slot == nil then
		warn("[MockMeetService] every mock meet room is in use")
		return false
	end

	local room, problem = MockMeetArena.build(slot, player)
	if room == nil then
		warn(string.format("[MockMeetService] could not build a room for %s: %s", player.Name, tostring(problem)))
		return false
	end
	slotOwner[slot] = player
	entering[player] = true
	local returnTo = body.root.CFrame

	local arrival = room.arrival * CFrame.new(0, standingHeight(body), 0)
	pcall(function()
		player:RequestStreamAroundAsync(arrival.Position, STREAM_TIMEOUT_SECONDS)
	end)
	entering[player] = nil

	-- Anything could have happened while the room streamed in: check again before moving them.
	local now = bodyOf(player)
	if player.Parent == nil or now == nil or now.character ~= body.character or now.humanoid.Health <= 0 then
		slotOwner[slot] = nil
		MockMeetArena.clear(room)
		return false
	end

	local visit: Visit = { room = room, character = body.character, returnTo = returnTo, connections = {} }
	visits[player] = visit
	body.character:PivotTo(arrival)
	player:SetAttribute(MockMeetConfig.SlotAttribute, slot)
	table.insert(visit.connections, body.humanoid.Died:Connect(function()
		finish(player, false)
	end))
	table.insert(visit.connections, body.character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			finish(player, false)
		end
	end))
	table.insert(visit.connections, room.model.Destroying:Connect(function()
		finish(player, false)
	end))
	log("%s entered mock meet room %d", player.Name, slot)
	return true
end

-- The "Start Mock Meet" prompt on a check-in point.
local function setUpCheckIn(instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local point = instance
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Start Mock Meet"
	prompt.ObjectText = "Check-in"
	prompt.HoldDuration = MockMeetConfig.PromptHoldSeconds
	prompt.MaxActivationDistance = MockMeetConfig.PromptDistanceStuds
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function(player)
		MockMeetService.checkIn(player, point)
	end)
end

function MockMeetService.start()
	if started then
		return
	end
	started = true

	local remotes = MockMeetRemotes.createOnServer(ReplicatedStorage)
	remotes.leave.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastLeave[player] or 0) < MockMeetConfig.LeaveCooldownSeconds then
			return
		end
		lastLeave[player] = now
		finish(player, true)
	end)

	for _, point in ipairs(CollectionService:GetTagged(MockMeetConfig.CheckInTag)) do
		setUpCheckIn(point)
	end
	CollectionService:GetInstanceAddedSignal(MockMeetConfig.CheckInTag):Connect(setUpCheckIn)

	Players.PlayerRemoving:Connect(function(player)
		finish(player, false)
		entering[player] = nil
		lastLeave[player] = nil
	end)
end

return MockMeetService
