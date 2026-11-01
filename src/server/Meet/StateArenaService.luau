--!strict
--[[
	StateArenaService
	Server / Meet

	Visits to the State arena (GAME_DESIGN.md §36). At server start it builds
	the entrance building beside the gym and the arena (StateArenaVenue). A
	player holds E at the entrance's doors to go in, arriving on the main
	stand's walkway, and at the EXIT to go back to where they came from. Anyone
	may visit and look round; the State meet itself (§36.4) comes later.

	The server decides every move: the prompt only asks, and a player must be
	standing at the doors, alive, not lifting, not on a machine, and not in the
	Local meet venue or a Mock Meet room. A visitor who ends up far from the
	arena some other way (the TELEPORT menu, a reset) is simply let go.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local StateArenaConfig = require(ConfigFolder:WaitForChild("StateArenaConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))

local ServerFolder = script.Parent.Parent
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))
local StateArenaVenue = require(script.Parent:WaitForChild("StateArenaVenue"))

local StateArenaService = {}

local BUSY_ATTRIBUTES = { "CardioMachine", "StationPose" }
local MOCK_MEET_ATTRIBUTE = "MockMeetSlot"
local MAX_TRIGGER_DISTANCE = StateArenaConfig.PromptDistanceStuds + 4
local STREAM_TIMEOUT_SECONDS = 5
local CHECK_SECONDS = 2

type Body = { character: Model, root: BasePart, humanoid: Humanoid }
type Visit = { character: Model, returnTo: CFrame, connections: { RBXScriptConnection } }

local started = false
local venue: StateArenaVenue.Venue? = nil
local visits: { [Player]: Visit } = {}
local entering: { [Player]: boolean } = {}

local function log(message: string, ...: any)
	print("[StateArenaService] " .. string.format(message, ...))
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

-- Ends `player`'s visit; with `sendBack`, moves them to where they came in from.
local function leave(player: Player, sendBack: boolean)
	local visit = visits[player]
	if visit == nil then
		return
	end
	visits[player] = nil
	for _, connection in ipairs(visit.connections) do
		connection:Disconnect()
	end
	if player.Parent then
		player:SetAttribute(StateArenaConfig.VenueAttribute, nil)
	end
	local body = bodyOf(player)
	if sendBack and body and body.character == visit.character and body.humanoid.Health > 0 then
		pcall(function()
			player:RequestStreamAroundAsync(visit.returnTo.Position, STREAM_TIMEOUT_SECONDS)
		end)
		if player.Parent and body.character.Parent and body.humanoid.Health > 0 then
			body.character:PivotTo(visit.returnTo)
		end
	end
	log("%s left the arena", player.Name)
end

-- Through the doors at `point`: moves `player` into the arena if everything allows it.
local function enter(player: Player, point: BasePart)
	local v = venue
	if v == nil or visits[player] or entering[player] then
		return
	end
	if player:GetAttribute(LocalMeetConfig.VenueAttribute) ~= nil or player:GetAttribute(MOCK_MEET_ATTRIBUTE) ~= nil then
		return
	end
	local body = bodyOf(player)
	if body == nil or body.humanoid.Health <= 0 or body.root.Anchored then
		return
	end
	for _, attribute in ipairs(BUSY_ATTRIBUTES) do
		if body.character:GetAttribute(attribute) ~= nil then
			return
		end
	end
	if (body.root.Position - point.Position).Magnitude > MAX_TRIGGER_DISTANCE + body.root.Size.Y then
		return
	end
	if LiftAttemptService.isAttemptActive(player) then
		return
	end
	entering[player] = true
	local returnTo = body.root.CFrame
	local arrival = v.arrival * CFrame.new(0, standingHeight(body), 0)
	pcall(function()
		player:RequestStreamAroundAsync(arrival.Position, STREAM_TIMEOUT_SECONDS)
	end)
	entering[player] = nil
	local nowBody = bodyOf(player)
	if player.Parent == nil or nowBody == nil or nowBody.character ~= body.character or nowBody.humanoid.Health <= 0 then
		return
	end
	local visit: Visit = { character = body.character, returnTo = returnTo, connections = {} }
	visits[player] = visit
	body.character:PivotTo(arrival)
	player:SetAttribute(StateArenaConfig.VenueAttribute, true)
	table.insert(visit.connections, body.humanoid.Died:Connect(function()
		leave(player, false)
	end))
	table.insert(visit.connections, body.character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			leave(player, false)
		end
	end))
	log("%s entered the arena", player.Name)
end

local function prompt(parent: BasePart, action: string, object: string, onTriggered: (Player) -> ())
	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = action
	proximity.ObjectText = object
	proximity.HoldDuration = StateArenaConfig.PromptHoldSeconds
	proximity.MaxActivationDistance = StateArenaConfig.PromptDistanceStuds
	proximity.KeyboardKeyCode = Enum.KeyCode.E
	proximity.GamepadKeyCode = Enum.KeyCode.ButtonX
	proximity.RequiresLineOfSight = false
	proximity.Parent = parent
	proximity.Triggered:Connect(onTriggered)
end

local function setUpEntrance(instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local point = instance
	prompt(point, "Go to the State arena", "State arena", function(player)
		enter(player, point)
	end)
end

function StateArenaService.start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player)
		leave(player, false)
		entering[player] = nil
	end)
	for _, point in ipairs(CollectionService:GetTagged(StateArenaConfig.EntranceTag)) do
		setUpEntrance(point)
	end
	CollectionService:GetInstanceAddedSignal(StateArenaConfig.EntranceTag):Connect(setUpEntrance)

	-- Built in the background so the server's start is not held up.
	task.spawn(function()
		if StateArenaVenue.buildEntrance() == nil then
			warn("[StateArenaService] the entrance building could not be built: there is no way into the State arena")
		end
		local built, problem = StateArenaVenue.build()
		if built == nil then
			warn("[StateArenaService] the arena could not be built: " .. tostring(problem))
			return
		end
		venue = built
		prompt(built.exitPoint, "Back to the gym", "Exit", function(player)
			if visits[player] then
				leave(player, true)
			end
		end)
		log("arena ready: %d racks", #built.liftSpots)

		-- Let go of visitors who left some other way (the TELEPORT menu, a reset that kept the character).
		while true do
			task.wait(CHECK_SECONDS)
			for player in pairs(visits) do
				local body = bodyOf(player)
				if body == nil or (body.root.Position - built.frame.Position).Magnitude > StateArenaConfig.LeftAfterStuds then
					leave(player, false)
				end
			end
		end
	end)
end

return StateArenaService
