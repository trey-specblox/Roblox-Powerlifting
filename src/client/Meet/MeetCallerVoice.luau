--!strict
--[[
	MeetCallerVoice
	Client / Meet

	The State meet's caller says the order out loud (user 2026-11-07: whatever the lifter's name), over the arena's speakers, using
	Roblox's text to speech (AudioTextToSpeech: Roblox filters the words and makes the voice as it is asked, so any name works).

	Each screen speaks only one caller's lines: the lifter's own rack's, otherwise the nearest one within HEARING_STUDS. That is also what
	keeps within Roblox's limit on these requests: one line per turn on one rack, about 3 a minute per player. If Roblox refuses a line or
	has no voice to give, nothing is heard and the caller's speech bubble still says it.

	Display only: it decides nothing. The server sets the line on the caller (LocalMeetService callerSays).

	PERFORMANCE: one short sound at a time, only while a State meet is running near this player.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local StateArenaConfig = require(ConfigFolder:WaitForChild("StateArenaConfig"))

local MeetCallerVoice = {}

local HEARING_STUDS = 150

local started = false
-- The line being spoken, so a newer one replaces it.
local speaking: Instance? = nil

local function stopSpeaking()
	if speaking then
		speaking:Destroy()
		speaking = nil
	end
end

local function speak(text: string)
	stopSpeaking()
	local voice = Instance.new("AudioTextToSpeech")
	voice.Name = "CallerVoice"
	voice.Text = text
	voice.VoiceId = StateArenaConfig.CallerVoiceId
	voice.Speed = StateArenaConfig.CallerVoiceSpeed
	voice.Volume = StateArenaConfig.CallerVoiceVolume
	local speakers = Instance.new("AudioDeviceOutput")
	speakers.Parent = voice
	local wire = Instance.new("Wire")
	wire.SourceInstance = voice
	wire.TargetInstance = speakers
	wire.Parent = voice
	voice.Parent = SoundService
	speaking = voice
	task.spawn(function()
		local ok, status = pcall(function()
			return voice:LoadAsync()
		end)
		-- A newer line may have taken over while this one was being made.
		if speaking ~= voice then
			return
		end
		if not ok or status ~= Enum.AssetFetchStatus.Success then
			warn("[MeetCallerVoice] no voice for this line: " .. tostring(status))
			stopSpeaking()
			return
		end
		voice.Ended:Once(function()
			if speaking == voice then
				stopSpeaking()
			end
		end)
		voice:Play()
	end)
end

-- Whether this screen should hear `caller`: the lifter's own rack, otherwise the nearest caller in earshot.
local function hears(caller: Model): boolean
	local player = Players.LocalPlayer
	local myRack = player:GetAttribute(LocalMeetConfig.PlatformAttribute)
	local callers = CollectionService:GetTagged(StateArenaConfig.CallerTag)
	if myRack ~= nil then
		for _, other in ipairs(callers) do
			if other:GetAttribute("RackIndex") == myRack then
				return other == caller
			end
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local nearest: Instance? = nil
	local nearestDistance = HEARING_STUDS
	for _, other in ipairs(callers) do
		if other:IsA("Model") then
			local distance = (other:GetPivot().Position - root.Position).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = other, distance
			end
		end
	end
	return nearest == caller
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local caller = instance
	caller:GetAttributeChangedSignal(StateArenaConfig.CallerLineAttribute):Connect(function()
		local line = caller:GetAttribute(StateArenaConfig.CallerLineAttribute)
		if typeof(line) == "string" and line ~= "" and hears(caller) then
			speak(line)
		end
	end)
end

function MeetCallerVoice.start()
	if started then
		return
	end
	started = true
	for _, caller in ipairs(CollectionService:GetTagged(StateArenaConfig.CallerTag)) do
		watch(caller)
	end
	CollectionService:GetInstanceAddedSignal(StateArenaConfig.CallerTag):Connect(watch)
	-- The racks go when the meet ends, and the voice with them.
	CollectionService:GetInstanceRemovedSignal(StateArenaConfig.CallerTag):Connect(function()
		if #CollectionService:GetTagged(StateArenaConfig.CallerTag) == 0 then
			stopSpeaking()
		end
	end)
end

return MeetCallerVoice
