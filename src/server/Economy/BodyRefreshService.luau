--!strict
--[[
	BodyRefreshService
	Server / Economy

	Shows a new body as soon as the lifter's weight calls for one (GAME_DESIGN §38.3, user 2026-11-18: "Yes, make it
	live"). Training moves the weight (PlayerDataService.onBodyweightChanged); when the build the lifter should have now
	(LifterBodyService.buildFor) differs from the body their character wears, the change waits until they are FREE and
	then the character is made again where it stands: the normal spawn path (GearService) gives it the new body, its
	clothes and gear.

	FREE means none of: lifting in a meet or a Mock Meet, a lift attempt, held in place (a rack pose, a meet platform),
	seated, posed at a training rack, on a cardio machine, dead. The weight only moves while training at a rack, so in
	practice the new body shows the moment the lifter steps away from it.

	Never more than one remake per player every MIN_SECONDS_BETWEEN, and a body that still doesn't match after a remake
	(a build whose model couldn't load) is left alone until the weight changes again: never a respawn loop.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local MockMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("MockMeetConfig"))

local ServerFolder = script.Parent.Parent
local PlayerDataService = require(ServerFolder:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))
local LifterBodyService = require(script.Parent:WaitForChild("LifterBodyService"))

local BodyRefreshService = {}

local CHECK_SECONDS = 1
local MIN_SECONDS_BETWEEN = 20
-- Character attributes that mean "busy with a machine, a rack or a meet lift" (TeleportService uses the first two).
-- Not "StationBarKg": that one only picks the rep sound and is never cleared, so it would block forever.
local BUSY_ATTRIBUTES = { "CardioMachine", "StationPose", "MeetLift" }

local started = false
-- Players whose body should change: the build they should get.
local pending: { [Player]: string } = {}
local lastRemade: { [Player]: number } = {}

local function wornBuild(character: Model?): string?
	local build = character and character:GetAttribute("LifterBodyBuild")
	return if typeof(build) == "string" then build else nil
end

local function isFree(player: Player): boolean
	if player:GetAttribute(LocalMeetConfig.PlatformAttribute) ~= nil or player:GetAttribute(MockMeetConfig.SlotAttribute) ~= nil then
		return false
	end
	if LiftAttemptService.isAttemptActive(player) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return false
	end
	if root.Anchored or humanoid.Sit then
		return false
	end
	for _, attribute in ipairs(BUSY_ATTRIBUTES) do
		if character:GetAttribute(attribute) ~= nil then
			return false
		end
	end
	return true
end

-- Makes the character again where it stands (the spawn path gives it the body of its weight now).
local function remake(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local standing = root.CFrame
	lastRemade[player] = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = player.CharacterAdded:Connect(function(new)
		if connection then
			connection:Disconnect()
		end
		local newRoot = new:WaitForChild("HumanoidRootPart", 10)
		if newRoot and new.Parent then
			new:PivotTo(standing)
		end
	end)
	local ok, problem = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		if connection then
			connection:Disconnect()
		end
		warn("[BodyRefreshService] could not remake " .. player.Name .. ": " .. tostring(problem))
	end
end

local function check()
	for player, build in pairs(pending) do
		if not player.Parent then
			pending[player] = nil
			continue
		end
		local character = player.Character
		if not LifterBodyService.hasBody(character) or wornBuild(character) == build then
			-- No lifter body to swap, or it already matches (a respawn got there first).
			pending[player] = nil
			continue
		end
		if os.clock() - (lastRemade[player] or -math.huge) < MIN_SECONDS_BETWEEN or not isFree(player) then
			continue
		end
		pending[player] = nil
		remake(player)
	end
end

function BodyRefreshService.start()
	if started then
		return
	end
	started = true
	PlayerDataService.onBodyweightChanged(function(player)
		if not player.Parent or not LifterBodyService.hasBody(player.Character) then
			return
		end
		local build = LifterBodyService.buildFor(player)
		if build ~= wornBuild(player.Character) then
			pending[player] = build
		else
			pending[player] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		lastRemade[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			check()
		end
	end)
end

return BodyRefreshService
