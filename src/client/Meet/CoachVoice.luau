--!strict
--[[
	CoachVoice
	Client / Meet

	THE COACHES SPEAK (user 2026-11-24: "Give every coach a voice ... Like if a coach says something like 'you got this'
	make it where he has a voice for that. Make sure it's within context"). Every coach line is an ElevenLabs take in
	that coach's own fixed voice (art/sounds/coach_voices.json; ids in CoachVoiceConfig, made by
	art/scripts/make_coach_voice_config.py). This plays them, on this player's screen only:

	  - at a meet: the coach's speech bubble on this player's own screen (the CoachTag moved into their PlayerGui,
	    LocalMeetVenue.staffFor): whenever its words change to a line with a take, it is said in the voice of the coach
	    this player chose (CoachingRemotes.GET: Squatavious, Benchamin, Sumo, or the Gym Owner);
	  - in their Mock Meet room (Workspace.MockMeetRooms, the room whose Owner is this player): the room coach's bubble
	    the same way; during a coach's trial the room says whose (the room's "CoachVoice" attribute, MockMeetService),
	    so that coach's own voice is heard;
	  - in the gym's talk screen (CoachDialogue): CoachVoice.say with the line's key.

	A line with no take (a changing one, like "You need 140 kg to win the meet.") stays text only. One coach line at a
	time: a new one cuts off the one before. The same words again within REPEAT_SECONDS (the coach walking round and
	saying them again) are not said twice.

	Audio only: it decides nothing.
	PERFORMANCE: one Sound, reused; a text-change listener on your own coach's bubble.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoachVoiceConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoachVoiceConfig"))
local CoachingConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoachingConfig"))
local CoachingRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("CoachingRemotes"))

local CoachVoice = {}

local REPEAT_SECONDS = 20
local ROOMS_FOLDER = "MockMeetRooms"
local ROOM_VOICE_ATTRIBUTE = "CoachVoice"

local started = false
local sound: Sound? = nil
local queue: { string } = {}
local playing = 0
local lastText, lastAt = "", -math.huge
local active: string = CoachingConfig.OwnerId
-- Bubbles already listened to (weak: they go with their figure).
local heard: { [TextLabel]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Voices whose takes are loaded (or loading).
local preloaded: { [string]: boolean } = {}

-- Loads `voice`'s takes ahead (a few seconds each), so its first line isn't late. Only the voices in use: your own
-- coach at meets, the coach you talk to in the gym.
local function preload(voice: string)
	local lines = CoachVoiceConfig.Lines[voice]
	if lines == nil or preloaded[voice] then
		return
	end
	preloaded[voice] = true
	task.spawn(function()
		-- (as Sounds: a bare id string is fetched as an image, and fails as "Asset type does not match", Studio
		-- 2026-11-24)
		local toLoad = {}
		for _, line in pairs(lines) do
			if line.id ~= "" then
				local s = Instance.new("Sound")
				s.SoundId = line.id
				table.insert(toLoad, s)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(toLoad)
		end)
		for _, s in ipairs(toLoad) do
			s:Destroy()
		end
	end)
end
CoachVoice.preload = preload

-- The take for `voice`'s line `key` (Squat / Bench / Deadlift / Owner), or nil.
local function idFor(voice: string, key: string): string?
	local lines = CoachVoiceConfig.Lines[voice]
	local line = lines and lines[key]
	return if line and line.id ~= "" then line.id else nil
end

-- The key of `voice`'s line that says exactly `text`, or nil.
local function keyForText(voice: string, text: string): string?
	local byText = CoachVoiceConfig.ByText[voice]
	return byText and byText[text]
end

local function playNext(mine: number)
	if mine ~= playing or sound == nil then
		return
	end
	local id = table.remove(queue, 1)
	if id == nil then
		return
	end
	local s = sound :: Sound
	s:Stop()
	s.SoundId = id
	s.TimePosition = 0
	s:Play()
	task.spawn(function()
		-- (waits for the take to load, then for it to end; a new line meanwhile ends this one)
		local t0 = os.clock()
		while mine == playing and not s.IsLoaded and os.clock() - t0 < 5 do
			task.wait(0.05)
		end
		if mine ~= playing then
			return
		end
		if not s.IsPlaying then
			s:Play()
		end
		s.Ended:Wait()
		playNext(mine)
	end)
end

local function playIds(ids: { string })
	if sound == nil or #ids == 0 then
		return
	end
	playing += 1
	queue = table.clone(ids)
	playNext(playing)
end

-- Says `voice`'s lines `keys` one after another (for example { "C1", "D3" }). Lines with no take are left out.
function CoachVoice.say(voice: string, keys: { string } | string)
	local list = if typeof(keys) == "string" then { keys } else keys
	local ids = {}
	for _, key in ipairs(list :: { string }) do
		local id = idFor(voice, key)
		if id then
			table.insert(ids, id)
		end
	end
	playIds(ids)
end

-- Says `text` in `voice` if that line has a take (and it wasn't just said). Returns whether it is said.
function CoachVoice.sayText(voice: string, text: string?): boolean
	if text == nil or text == "" then
		return false
	end
	local now = os.clock()
	if text == lastText and now - lastAt < REPEAT_SECONDS then
		return false
	end
	local key = keyForText(voice, text) or keyForText(CoachingConfig.OwnerId, text)
	local id = key and (idFor(voice, key) or idFor(CoachingConfig.OwnerId, key))
	if id == nil then
		return false
	end
	lastText, lastAt = text, now
	playIds({ id })
	return true
end

-- Stops the coach mid-line (a dialogue closed).
function CoachVoice.stop()
	playing += 1
	table.clear(queue)
	if sound then
		sound:Stop()
	end
end

-- The coach this player chose (asked again at each meet and room, so a coach hired since counts).
local function refreshActive()
	local remotes = CoachingRemotes.waitForClient(ReplicatedStorage)
	for _ = 1, 4 do
		local ok, view = pcall(function()
			return remotes.get:InvokeServer()
		end)
		if ok and typeof(view) == "table" and typeof(view.active) == "string" then
			active = view.active
			preload(active)
			return
		end
		task.wait(0.5)
	end
end

-- Says every new line of the bubble under `billboard` (a coach's CoachTag) in the voice `voiceOf()` gives. (A rack
-- several lifters share hands its tags on to whoever lifts, so the same tag can arrive again: listened to once.)
local function listen(billboard: BillboardGui, voiceOf: () -> string)
	local bubble = billboard:WaitForChild("Bubble", 5)
	local line = bubble and bubble:FindFirstChild("Line")
	if line == nil or not line:IsA("TextLabel") or heard[line] then
		return
	end
	local label = line :: TextLabel
	heard[label] = true
	label:GetPropertyChangedSignal("Text"):Connect(function()
		CoachVoice.sayText(voiceOf(), label.Text)
	end)
	if label.Text ~= "" then
		CoachVoice.sayText(voiceOf(), label.Text)
	end
end

local function watchRooms()
	local player = Players.LocalPlayer
	local rooms = Workspace:WaitForChild(ROOMS_FOLDER, math.huge)
	local function room(model: Instance)
		if not model:IsA("Model") or model:GetAttribute("Owner") ~= player.UserId then
			return
		end
		task.spawn(refreshActive)
		local function voiceOf(): string
			local trial = model:GetAttribute(ROOM_VOICE_ATTRIBUTE)
			return if typeof(trial) == "string" then trial else active
		end
		local function tag(d: Instance)
			if d:IsA("BillboardGui") and d.Name == "CoachTag" then
				task.spawn(listen, d, voiceOf)
			end
		end
		for _, d in ipairs(model:GetDescendants()) do
			tag(d)
		end
		model.DescendantAdded:Connect(tag)
	end
	for _, model in ipairs(rooms:GetChildren()) do
		room(model)
	end
	rooms.ChildAdded:Connect(room)
end

function CoachVoice.start()
	if started then
		return
	end
	started = true
	local group = Instance.new("SoundGroup")
	group.Name = "CoachVoices"
	group.Volume = 1
	group.Parent = SoundService
	local s = Instance.new("Sound")
	s.Name = "CoachVoice"
	s.Volume = CoachVoiceConfig.Volume
	s.SoundGroup = group
	s.Parent = SoundService
	sound = s

	-- Your own coach's bubble at a meet.
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function meetTag(child: Instance)
		if child:IsA("BillboardGui") and child.Name == "CoachTag" then
			task.spawn(function()
				refreshActive()
				listen(child, function()
					return active
				end)
			end)
		end
	end
	for _, child in ipairs(playerGui:GetChildren()) do
		meetTag(child)
	end
	playerGui.ChildAdded:Connect(meetTag)

	task.spawn(watchRooms)
end

return CoachVoice
