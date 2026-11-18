--!strict
--[[
	NationalsChant
	Client / Meet

	The Nationals hall crowd's chant (GAME_DESIGN §39, user 2026-11-17: the lifter waits behind the curtain "until the user
	clicks", the "chants building up"), on this player's screen while they are inside the hall: while a lifter waits behind
	a curtain and until their lift's result (the hall model's NationalsConfig.ChantAttribute, set by the server's
	NationalsArenaVenue), the crowd's chant loop plays (MeetSoundConfig.NationalsChant.Mixes, one finished mix each, made by
	art/scripts/make_nationals_chant_mix.py). It BUILDS: it comes in at BuildFrom of its volume and rises to all of it over
	BuildSeconds, then holds; a change of chant crossfades at the level reached. "ForTheWin" when making it wins the lifter
	their class (the server decides). Sound only. As MeetChant (the State arena's), with the build.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local MeetSoundConfig = require(ConfigFolder:WaitForChild("MeetSoundConfig"))
local NationalsConfig = require(ConfigFolder:WaitForChild("NationalsConfig"))

local NationalsChant = {}

local CONFIG = MeetSoundConfig.NationalsChant
local HALL_NAME = "NationalsHall"
local CHECK_SECONDS = 0.25

local mixes: { [string]: Sound } = {}
local playing: Sound? = nil
local playingKey: string? = nil
-- When the chant began (any chant, carried over a change of chant): its build is measured from here.
local buildStartedAt = 0
local fades: { [Sound]: RBXScriptConnection } = {}
local started = false

-- On Heartbeat, not a tween (a tween stalls while the screen is not drawing, MeetChant): from the current volume to
-- `target()` over `seconds`, then it keeps following `target()` while the sound is the one playing (the build).
local function follow(sound: Sound, seconds: number, target: () -> number, after: (() -> ())?)
	local old = fades[sound]
	if old then
		old:Disconnect()
	end
	local from, elapsed = sound.Volume, 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local share = if seconds > 0 then math.min(1, elapsed / seconds) else 1
		local goal = target()
		sound.Volume = from + (goal - from) * share
		if share >= 1 and (playing ~= sound or goal == 0) then
			connection:Disconnect()
			if fades[sound] == connection then
				fades[sound] = nil
			end
			if after then
				after()
			end
		end
	end)
	fades[sound] = connection
end

-- How loud a chant is now: its BuildFrom share at the start of the build, all of it BuildSeconds later.
local function builtVolume(key: string): number
	local config = CONFIG.Mixes[key]
	if config == nil then
		return 0
	end
	local share = math.clamp((os.clock() - buildStartedAt) / CONFIG.BuildSeconds, 0, 1)
	return config.volume * (CONFIG.BuildFrom + (1 - CONFIG.BuildFrom) * share)
end

local function chantFor(key: string?)
	local mix = if key then mixes[key] else nil
	if mix == playing then
		return
	end
	local before = playing
	if before == nil then
		buildStartedAt = os.clock()
	end
	playing, playingKey = mix, if mix then key else nil
	if before then
		follow(before, CONFIG.FadeOutSeconds, function()
			return 0
		end, function()
			if playing ~= before then
				before:Stop()
			end
		end)
	end
	if mix and key then
		mix.Volume = 0
		mix.TimePosition = 0
		mix:Play()
		local chantKey = key
		follow(mix, CONFIG.FadeInSeconds, function()
			return builtVolume(chantKey)
		end)
	end
end

-- Whether the local player is inside the Nationals hall (the server's attribute, set at its doors).
local function inside(): boolean
	return Players.LocalPlayer:GetAttribute(NationalsConfig.InHallAttribute) == true
end

function NationalsChant.start()
	if started then
		return
	end
	started = true
	local toLoad: { Instance } = {}
	for key, config in pairs(CONFIG.Mixes) do
		if config.id ~= "" then
			local s = Instance.new("Sound")
			s.Name = "NationalsChant_" .. key
			s.SoundId = config.id
			s.Volume = 0
			s.Looped = true
			s.Parent = SoundService
			mixes[key] = s
			table.insert(toLoad, s)
		end
	end
	if next(mixes) == nil then
		return
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(toLoad)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local hall = Workspace:FindFirstChild(HALL_NAME)
			local key = hall and hall:GetAttribute(NationalsConfig.ChantAttribute)
			if typeof(key) == "string" and inside() then
				chantFor(key)
			else
				chantFor(nil)
			end
		end
	end)
end

-- (For a Studio check: which chant plays, and how loud it is now.)
function NationalsChant.state(): (string?, number)
	return playingKey, if playing then playing.Volume else 0
end

return NationalsChant
