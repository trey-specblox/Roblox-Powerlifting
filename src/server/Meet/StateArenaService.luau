--!strict
--[[
	StateArenaService
	Server / Meet

	The way into the State arena (GAME_DESIGN.md §36). At server start it builds the entrance building beside the gym; a player holds
	E at its doors to go in. LocalMeetService holds the arena as the last of its halls (StateArenaVenue builds it) and does the rest:
	it checks the player, moves them, runs the State meet (§36.4) and takes them back out at the EXIT.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local StateArenaConfig = require(ConfigFolder:WaitForChild("StateArenaConfig"))

local StateArenaVenue = require(script.Parent:WaitForChild("StateArenaVenue"))
local LocalMeetService = require(script.Parent:WaitForChild("LocalMeetService"))

local StateArenaService = {}

local started = false

local function setUpEntrance(instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = "Go to the State arena"
	proximity.ObjectText = "State arena"
	proximity.HoldDuration = StateArenaConfig.PromptHoldSeconds
	proximity.MaxActivationDistance = StateArenaConfig.PromptDistanceStuds
	proximity.KeyboardKeyCode = Enum.KeyCode.E
	proximity.GamepadKeyCode = Enum.KeyCode.ButtonX
	proximity.RequiresLineOfSight = false
	proximity.Parent = instance
	local point = instance
	proximity.Triggered:Connect(function(player)
		LocalMeetService.enterState(player, point)
	end)
end

function StateArenaService.start()
	if started then
		return
	end
	started = true

	for _, point in ipairs(CollectionService:GetTagged(StateArenaConfig.EntranceTag)) do
		setUpEntrance(point)
	end
	CollectionService:GetInstanceAddedSignal(StateArenaConfig.EntranceTag):Connect(setUpEntrance)

	-- Built in the background so the server's start is not held up.
	task.spawn(function()
		if StateArenaVenue.buildEntrance() == nil then
			warn("[StateArenaService] the entrance building could not be built: there is no way into the State arena")
		end
	end)
end

return StateArenaService
