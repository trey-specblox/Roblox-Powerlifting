--!strict
--[[
	MeetSoundController
	Client / Meet

	Plays the meets' sounds and each place's background on this player's screen
	(GAME_DESIGN §37.5 "Meet sounds"). The server says which cue happened where
	(LocalMeetRemotes.sound); the sounds themselves are in MeetSoundConfig. Audio
	only: it decides nothing.

	PERFORMANCE: each cue with an id has a small fixed set of Sounds, made once and
	reused. Cues out of earshot are skipped. Eight platforms lift at once, so crowd
	cues from other platforms are spaced out; the player's own platform always plays.
	Only the background of the place the player is in plays.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeetSoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetSoundConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local MeetSoundController = {}

-- How close (studs) a cue must be to count as the player's own platform.
local OWN_PLATFORM_STUDS = 22
-- A little variety, so repeated sounds don't sound identical.
local PITCH_SPREAD = 0.05
local BACKGROUND_CHECK_SECONDS = 0.5

type Voice = { sound: Sound, attachment: Attachment, ownPlatform: boolean }
type CueState = { voices: { Voice }, nextVoice: number, lastPlayedAt: number }
type Box = { frame: CFrame, size: Vector3 }

local cues: { [string]: CueState } = {}
-- Weak keys: a Mock Meet room's box goes when the room does.
local boxes: { [Model]: Box } = setmetatable({}, { __mode = "k" }) :: any
local lastOtherRepAt = -math.huge
local started = false

local function makeGroup(): SoundGroup
	local group = Instance.new("SoundGroup")
	group.Name = "MeetSounds"
	group.Parent = SoundService
	return group
end

local function makeCues(group: SoundGroup)
	local toLoad = {}
	for name, config in pairs(MeetSoundConfig.Cues) do
		if config.id ~= "" then
			local state: CueState = { voices = {}, nextVoice = 1, lastPlayedAt = -math.huge }
			for index = 1, config.voices do
				local attachment = Instance.new("Attachment")
				attachment.Name = "MeetSound_" .. name .. "_" .. index
				attachment.Parent = Workspace.Terrain
				local sound = Instance.new("Sound")
				sound.Name = name
				sound.SoundId = config.id
				sound.Volume = config.volume
				sound.RollOffMode = Enum.RollOffMode.InverseTapered
				sound.RollOffMinDistance = config.near
				sound.RollOffMaxDistance = config.far
				sound.SoundGroup = group
				sound.Parent = attachment
				table.insert(state.voices, { sound = sound, attachment = attachment, ownPlatform = false })
				table.insert(toLoad, sound)
			end
			cues[name] = state
		end
	end
	-- Loaded now, so the first bar drop isn't late.
	task.spawn(function()
		ContentProvider:PreloadAsync(toLoad)
	end)
end

local function listenerPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	if character then
		return character:GetPivot().Position
	end
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position
end

-- The next voice in turn. A sound from another platform never cuts off one from the player's own; if every voice is
-- busy with theirs, it isn't played at all.
local function pickVoice(state: CueState, isOwn: boolean): Voice?
	local count = #state.voices
	for step = 0, count - 1 do
		local index = (state.nextVoice + step - 1) % count + 1
		local voice = state.voices[index]
		if isOwn or not (voice.ownPlatform and voice.sound.IsPlaying) then
			state.nextVoice = index % count + 1
			return voice
		end
	end
	return nil
end

local function startVoice(state: CueState, config: MeetSoundConfig.Cue, at: Vector3, isOwn: boolean, volumeScale: number)
	local voice = pickVoice(state, isOwn)
	if voice == nil then
		return
	end
	state.lastPlayedAt = os.clock()
	voice.ownPlatform = isOwn
	voice.attachment.WorldPosition = at
	voice.sound.Volume = config.volume * volumeScale
	voice.sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * PITCH_SPREAD
	voice.sound.TimePosition = 0
	voice.sound:Play()
end

local function play(name: string, at: Vector3)
	local config = MeetSoundConfig.Cues[name]
	local state = cues[name]
	local listener = listenerPosition()
	if config == nil or state == nil or listener == nil then
		return
	end
	local distance = (at - listener).Magnitude
	if distance > config.far then
		return
	end
	local isOwn = distance <= OWN_PLATFORM_STUDS
	if not isOwn and os.clock() - state.lastPlayedAt < config.minGapSeconds then
		return
	end
	startVoice(state, config, at, isOwn, 1)
end

--[[
	A gym training rep (StationRepSounds, MeetSoundConfig.TrainingReps): quieter than a
	meet lift, since it repeats. Another lifter's is heard only from close by, and
	those are spaced out, so a full gym never turns into constant banging.
]]
function MeetSoundController.playRep(name: string, at: Vector3, isOwnLifter: boolean)
	local config = MeetSoundConfig.Cues[name]
	local state = cues[name]
	local listener = listenerPosition()
	local reps = MeetSoundConfig.TrainingReps
	if config == nil or state == nil or listener == nil then
		return
	end
	if not isOwnLifter then
		local now = os.clock()
		if (at - listener).Magnitude > reps.othersHeardStuds or now - lastOtherRepAt < reps.othersGapSeconds then
			return
		end
		lastOtherRepAt = now
	end
	startVoice(state, config, at, isOwnLifter, if isOwnLifter then reps.ownVolume else reps.othersVolume)
end

local function within(box: Box, at: Vector3): boolean
	local offset = box.frame:PointToObjectSpace(at)
	return math.abs(offset.X) <= box.size.X / 2 and math.abs(offset.Y) <= box.size.Y / 2
		and math.abs(offset.Z) <= box.size.Z / 2
end

--[[
	Measuring walks every part, and the gym has thousands, so a player inside the box
	last measured stays inside without measuring again. Outside it, the box is measured
	again: a place far away is only partly loaded on this client (or not at all), so
	its box grows as the player arrives.
]]
local function isInside(model: Model, at: Vector3): boolean
	local known = boxes[model]
	if known and within(known, at) then
		return true
	end
	local frame, size = model:GetBoundingBox()
	local box = { frame = frame, size = size }
	boxes[model] = box
	return within(box, at)
end

-- The first place in MeetSoundConfig.Backgrounds the player is inside, or nil.
local function backgroundAt(at: Vector3): MeetSoundConfig.Background?
	for _, background in ipairs(MeetSoundConfig.Backgrounds) do
		local place = Workspace:FindFirstChild(background.place)
		if place and place:IsA("Model") then
			if isInside(place, at) then
				return background
			end
		elseif place then
			for _, child in ipairs(place:GetChildren()) do
				if child:IsA("Model") and isInside(child, at) then
					return background
				end
			end
		end
	end
	return nil
end

-- The background of the place the player is in: the old one fades out as the new one fades in.
local function runBackgrounds(group: SoundGroup)
	local fade = TweenInfo.new(MeetSoundConfig.BackgroundFadeSeconds)
	-- One Sound per recording: two places can share one, each at its own volume.
	local sounds: { [string]: Sound } = {}
	local toLoad = {}
	for _, background in ipairs(MeetSoundConfig.Backgrounds) do
		if background.id ~= "" and not sounds[background.id] then
			local sound = Instance.new("Sound")
			sound.Name = "Background_" .. (#toLoad + 1)
			sound.SoundId = background.id
			sound.Looped = true
			sound.Volume = 0
			sound.SoundGroup = group
			sound.Parent = SoundService
			sounds[background.id] = sound
			table.insert(toLoad, sound)
		end
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(toLoad)
	end)

	local current: MeetSoundConfig.Background? = nil
	local tweens: { [Sound]: Tween } = {}
	local function fadeTo(sound: Sound, volume: number)
		local running = tweens[sound]
		if running then
			running:Cancel()
		end
		local going = TweenService:Create(sound, fade, { Volume = volume })
		tweens[sound] = going
		going:Play()
		if volume == 0 then
			going.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed then
					sound:Stop()
				end
			end)
		end
	end
	while true do
		task.wait(BACKGROUND_CHECK_SECONDS)
		local listener = listenerPosition()
		local nowIn = if listener then backgroundAt(listener) else nil
		if nowIn ~= current then
			local old = current and sounds[current.id]
			local new = nowIn and sounds[nowIn.id]
			current = nowIn
			if old and old ~= new then
				fadeTo(old, 0)
			end
			if new and nowIn then
				if not new.IsPlaying then
					-- From a random point, so it never starts the same way.
					new.TimePosition = math.random() * math.max(0, new.TimeLength)
					new:Play()
				end
				fadeTo(new, nowIn.volume)
			end
		end
	end
end

function MeetSoundController.start()
	if started or not RunService:IsClient() then
		return
	end
	started = true
	local group = makeGroup()
	makeCues(group)
	task.spawn(runBackgrounds, group)
	local remotes = LocalMeetRemotes.waitForClient(ReplicatedStorage)
	remotes.sound.OnClientEvent:Connect(function(name: string, at: Vector3)
		play(name, at)
	end)
end

return MeetSoundController
