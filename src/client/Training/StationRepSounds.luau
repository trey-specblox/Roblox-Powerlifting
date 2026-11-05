--!strict
--[[
	StationRepSounds
	Client / Training

	The bar's sound in each gym training rep (GAME_DESIGN §37.5 "Meet sounds"). Every
	lifter's rep animation (StationPoseAnimator) is watched on this screen, and when it
	passes the moment in MeetSoundConfig.TrainingReps the sound plays at the lifter, so
	it stays on the animation for your reps and everyone else's. Audio only: it sends
	nothing to the server and changes no game state.

	The server marks a posed lifter's character with StationPose (the lift) and
	StationBarKg (their Competition Number for it, which picks the deadlift's thud).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local MeetSoundConfig = require(ConfigFolder:WaitForChild("MeetSoundConfig"))
local StationAnimationConfig = require(ConfigFolder:WaitForChild("StationAnimationConfig"))
local MeetSoundController = require(script.Parent.Parent:WaitForChild("Meet"):WaitForChild("MeetSoundController"))

local StationRepSounds = {}

local POSE_ATTRIBUTE = "StationPose"
local BAR_KG_ATTRIBUTE = "StationBarKg"

-- Where each lifter's rep animation was last frame. Weak keys: a character's entry goes when the character does.
local lastTimes: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local started = false

local function repTrack(character: Model, lift: string): AnimationTrack?
	local id = StationAnimationConfig.AnimationIds[lift]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if id == nil or id == "" or animator == nil then
		return nil
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation and track.Animation.AnimationId == id then
			return track
		end
	end
	return nil
end

-- Whether the animation passed `moment` since last frame (it loops, so `now` can be behind `last`).
local function passed(last: number, now: number, moment: number): boolean
	if now >= last then
		return last < moment and moment <= now
	end
	return last < moment or moment <= now
end

local function update()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local lift = character and character:GetAttribute(POSE_ATTRIBUTE)
		if character and typeof(lift) == "string" then
			local track = repTrack(character, lift)
			local moment = MeetSoundConfig.TrainingReps.moments[lift]
			if track and moment then
				local now = track.TimePosition
				local last = lastTimes[character]
				lastTimes[character] = now
				if last and passed(last, now, moment) then
					local kg = character:GetAttribute(BAR_KG_ATTRIBUTE)
					MeetSoundController.playRep(MeetSoundConfig.repCue(lift, if typeof(kg) == "number" then kg else 0),
						character:GetPivot().Position, player == Players.LocalPlayer)
				end
			end
		elseif character then
			lastTimes[character] = nil
		end
	end
end

function StationRepSounds.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(update)
end

return StationRepSounds
