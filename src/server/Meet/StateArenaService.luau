--!strict
--[[
	StateArenaService
	Server / Meet

	The way into the State arena (GAME_DESIGN.md §36). At server start it builds the entrance building beside the gym; a player holds
	E at its doors to go in. LocalMeetService holds the arena as the last of its halls (StateArenaVenue builds it) and does the rest:
	it checks the player, moves them, runs the State meet (§36.4) and takes them back out at the EXIT.

	Also lets lifters through the meet area's walls, for anything that has them walk there themselves (setCompetitor).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local StateArenaConfig = require(ConfigFolder:WaitForChild("StateArenaConfig"))

local StateArenaVenue = require(script.Parent:WaitForChild("StateArenaVenue"))
local LocalMeetService = require(script.Parent:WaitForChild("LocalMeetService"))

local StateArenaService = {}

-- Competing lifters: the connection that keeps parts added to their character (tools, accessories) in the group.
local competitors: { [Player]: RBXScriptConnection } = {}
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

local function setGroup(character: Model, group: string)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

--[[
	Lets `player` through the meet area's walls (on) or not (off): only lifters competing in the State meet may go all round the meet
	(user 2026-11-01).
]]
function StateArenaService.setCompetitor(player: Player, on: boolean)
	local old = competitors[player]
	if old then
		old:Disconnect()
		competitors[player] = nil
	end
	local character = player.Character
	if character == nil then
		return
	end
	if on then
		local group = StateArenaConfig.CompetitorGroup
		setGroup(character, group)
		competitors[player] = character.DescendantAdded:Connect(function(part)
			if part:IsA("BasePart") then
				part.CollisionGroup = group
			end
		end)
	else
		setGroup(character, "Default")
	end
end

function StateArenaService.start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player)
		local competing = competitors[player]
		if competing then
			competing:Disconnect()
			competitors[player] = nil
		end
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
	end)
end

return StateArenaService
