--!strict
--[[
	MeetChant
	Client / Meet

	The State arena crowd's chant (GAME_DESIGN §36.4, user 2026-11-10), on this player's screen while they are inside the
	arena: while a lifter is on a third attempt, from chalking up until their lift's result (the arena model's Chant
	attribute, set by the server's StateArenaShow), the crowd's chant loop plays: one finished mix of the crowd stomping,
	stomping and clapping with the chant on every other bar (MeetSoundConfig.Chant.Mixes, made by
	art/scripts/make_chant_mix.py). LIFT OR LOSE when making it puts the lifter first (the server decides), else the lift's
	own. It fades in and out, and from one chant into another. Sound only.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MeetSoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MeetSoundConfig"))
local StateArenaLights = require(script.Parent:WaitForChild("StateArenaLights"))

local MeetChant = {}

local CONFIG = MeetSoundConfig.Chant
local ARENA_NAME = "StateArenaVenue"
local CHECK_SECONDS = 0.25

local mixes: { [string]: Sound } = {}
local playing: Sound? = nil -- the mix playing now, nil when quiet
local fades: { [Sound]: RBXScriptConnection } = {}

-- Fades a mix on Heartbeat, not a tween: a tween only moves while the screen draws (a minimised window, Studio's hidden
-- test window), and then a fade out would never finish and the chant would never stop.
local function fadeTo(sound: Sound, volume: number, seconds: number, after: (() -> ())?)
	local old = fades[sound]
	if old then
		old:Disconnect()
	end
	local from, elapsed = sound.Volume, 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local share = if seconds > 0 then math.min(1, elapsed / seconds) else 1
		sound.Volume = from + (volume - from) * share
		if share >= 1 then
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

local function fadeOut(sound: Sound)
	fadeTo(sound, 0, CONFIG.FadeOutSeconds, function()
		if playing ~= sound then
			sound:Stop()
		end
	end)
end

-- Plays the mix for what the arena chants for (nil: quiet), fading out whatever played before.
local function chantFor(key: string?)
	local mix = if key then mixes[key] else nil
	if mix == playing then
		return
	end
	local before = playing
	playing = mix
	if before then
		fadeOut(before)
	end
	if mix then
		local config = CONFIG.Mixes[key :: string]
		mix.Volume = 0
		mix.TimePosition = 0
		mix:Play()
		fadeTo(mix, config.volume, CONFIG.FadeInSeconds)
	end
end

function MeetChant.start()
	local toLoad: { Instance } = {}
	for key, config in pairs(CONFIG.Mixes) do
		if config.id ~= "" then
			local s = Instance.new("Sound")
			s.Name = "Chant_" .. key
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
	-- Loaded before it is ever needed, so the first play starts clean instead of stuttering while it downloads.
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(toLoad)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local arena = Workspace:FindFirstChild(ARENA_NAME)
			local key = arena and arena:GetAttribute("Chant")
			if typeof(key) == "string" and StateArenaLights.insideArena() then
				chantFor(key)
			else
				chantFor(nil)
			end
		end
	end)
end

return MeetChant
