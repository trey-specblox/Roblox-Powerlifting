--!strict
--[[
	EmoteService
	Server / World

	Plays emotes (EmoteConfig; user 2026-11-11: an emote wheel on B, a collection won at the celebration NPC). A client
	only asks (EmoteRemotes.PlayEmote); the server checks that the emote is theirs (PlayerDataService.ownsEmote), that
	they aren't lifting (a lift attempt, a training station), in a meet's turn or a mock meet, or held in place by one
	(an anchored body), and that they don't ask too fast. Then it plays the animation on their character, so everyone sees
	it, and tells every client (EmoteStarted) so each plays its sound locked to it. Walking or jumping ends it.

	PERFORMANCE: one animation track per playing emote, watched a few times a second until it ends.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteConfig = require(Shared:WaitForChild("Config"):WaitForChild("EmoteConfig"))
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local MockMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("MockMeetConfig"))
local EmoteRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("EmoteRemotes"))

local ServerFolder = script.Parent.Parent
local PlayerDataService = require(ServerFolder:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))

local EmoteService = {}

local MIN_SECONDS_BETWEEN = 0.6
-- Walking faster than this (studs per second, flat) ends an emote.
local CANCEL_SPEED = 3
local FADE = 0.2

local started = false
local remotes: EmoteRemotes.RemoteSet? = nil
local lastAsked: { [Player]: number } = {}
local playing: { [Player]: AnimationTrack } = {}

local function busyReason(player: Player): string?
	if player:GetAttribute(LocalMeetConfig.PlatformAttribute) ~= nil or player:GetAttribute(MockMeetConfig.SlotAttribute) ~= nil then
		return "Not during a meet."
	end
	if LiftAttemptService.isAttemptActive(player) then
		return "Not during a lift."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return "No character to emote with."
	end
	if root.Anchored or humanoid.Sit or character:GetAttribute("StationBarKg") ~= nil then
		return "Not right now."
	end
	return nil
end

local function stop(player: Player)
	local track = playing[player]
	if track then
		playing[player] = nil
		track:Stop(FADE)
		task.delay(FADE + 0.1, function()
			track:Destroy()
		end)
	end
end

local function play(player: Player, id: any): (boolean, string)
	if typeof(id) ~= "string" or EmoteConfig.byId[id] == nil then
		return false, "That isn't an emote."
	end
	local now = os.clock()
	if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN then
		return false, "One moment..."
	end
	lastAsked[player] = now
	if not PlayerDataService.ownsEmote(player, id) then
		return false, "Win it at Hype Man first."
	end
	local busy = busyReason(player)
	if busy then
		return false, busy
	end
	local emote = EmoteConfig.byId[id]
	local character = player.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return false, "No character to emote with."
	end
	stop(player)
	local animation = Instance.new("Animation")
	animation.Name = "Emote"
	animation.AnimationId = emote.animationId
	local ok, loaded = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok then
		return false, "That emote didn't load."
	end
	local track = loaded :: AnimationTrack
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play(FADE)
	playing[player] = track
	local set = remotes
	if set and emote.soundtrack then
		set.started:FireAllClients(id, Workspace:GetServerTimeNow(), character)
	end
	-- Ends with the emote, or as soon as they walk or jump.
	task.spawn(function()
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
		local endAt = os.clock() + emote.seconds
		while playing[player] == track and os.clock() < endAt do
			task.wait(0.1)
			local v = root.AssemblyLinearVelocity
			if not character.Parent or Vector3.new(v.X, 0, v.Z).Magnitude > CANCEL_SPEED or humanoid.Jump then
				break
			end
		end
		if playing[player] == track then
			stop(player)
		end
	end)
	return true, emote.name
end

function EmoteService.start()
	if started then
		return
	end
	started = true
	local set = EmoteRemotes.createOnServer(ReplicatedStorage)
	remotes = set
	set.get.OnServerInvoke = function(player: Player): { string }?
		return PlayerDataService.getEmotes(player)
	end
	set.play.OnServerInvoke = function(player: Player, id: any): (boolean, string)
		return play(player, id)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
		playing[player] = nil
	end)
end

return EmoteService
