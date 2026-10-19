--!strict
--[[
	StationPoseAnimator
	Client / Training

	Makes the station poses move (GAME_DESIGN.md §34.12 decision 15: slow
	repeating reps). Visual only: it sends nothing to the server and changes no
	game state.

	  1. YOUR character: when the server marks it with StationPose (the lift),
	     this plays that lift's rep animation (StationAnimationConfig) looped at
	     Action priority, and stops it when the mark goes. Roblox replicates
	     animations a player plays on their own character, so everyone sees it.
	  2. EVERY lifter's bar: while a lifter's rep animation plays, the barbell of
	     their rack (StationRack) follows the midpoint of their hands, level and
	     along the rack, whenever the bar is held (StationAnimationConfig
	     BarHeldWindows); otherwise it sits at the rest spot the server published
	     (the Barbell's RestCFrame attribute). These moves are local to each
	     player's screen; the server's barbell never moves.

	A lift without a published animation ID plays nothing and leaves the bar
	where the server put it. R6 characters are skipped (the reps are R15).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StationAnimationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StationAnimationConfig"))

local StationPoseAnimator = {}

local POSE_ATTRIBUTE = "StationPose"
local RACK_ATTRIBUTE = "StationRack"
local RACKS_FOLDER = "GymRacks"
local FADE_SECONDS = 0.2

local localPlayer = Players.LocalPlayer
local started = false

-- ---------------------------------------------------------------- your own character

local animations: { [string]: Animation } = {}
local currentTrack: AnimationTrack? = nil
local currentLift: string? = nil

local function animationFor(lift: string): Animation?
	local id = StationAnimationConfig.AnimationIds[lift]
	if id == nil or id == "" then
		return nil
	end
	local cached: Animation? = animations[lift]
	if cached then
		return cached
	end
	local animation = Instance.new("Animation")
	animation.Name = "Station" .. lift
	animation.AnimationId = id
	animations[lift] = animation
	return animation
end

local function stopOwnTrack()
	local track = currentTrack
	currentTrack = nil
	currentLift = nil
	if track then
		track:Stop(FADE_SECONDS)
	end
end

local function r15Animator(character: Model): Animator?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	return humanoid:FindFirstChildOfClass("Animator")
end

local function applyOwnPose(character: Model)
	local value = character:GetAttribute(POSE_ATTRIBUTE)
	local lift: string? = if typeof(value) == "string" then value else nil
	if lift == currentLift then
		return
	end
	stopOwnTrack()
	if lift == nil then
		return
	end
	currentLift = lift
	local animator = r15Animator(character)
	local animation = animationFor(lift)
	if animator == nil or animation == nil then
		return
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(FADE_SECONDS)
	currentTrack = track
end

local function watchOwnCharacter(character: Model)
	stopOwnTrack()
	character:GetAttributeChangedSignal(POSE_ATTRIBUTE):Connect(function()
		applyOwnPose(character)
	end)
	applyOwnPose(character)
end

-- ---------------------------------------------------------------- every lifter's bar

type BarState = {
	-- Each barbell part with its place relative to Bar_Shaft (the bar's centre).
	parts: { { part: BasePart, offset: CFrame } },
	moved: boolean,
}

local bars: { [Instance]: BarState } = setmetatable({}, { __mode = "k" }) :: any

local function barStateOf(barbell: Instance): BarState?
	local state = bars[barbell]
	if state then
		return state
	end
	local shaft = barbell:FindFirstChild("Bar_Shaft")
	if shaft == nil or not shaft:IsA("BasePart") then
		return nil
	end
	-- The parts' layout around the shaft never changes, whatever the server is doing.
	local newState: BarState = { parts = {}, moved = false }
	for _, part in ipairs(barbell:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(newState.parts, { part = part, offset = shaft.CFrame:ToObjectSpace(part.CFrame) })
		end
	end
	bars[barbell] = newState
	return newState
end

local function placeBar(state: BarState, centre: CFrame)
	for _, entry in ipairs(state.parts) do
		entry.part.CFrame = centre * entry.offset
	end
end

local function restOf(barbell: Instance): CFrame?
	local rest = barbell:GetAttribute("RestCFrame")
	return if typeof(rest) == "CFrame" then rest else nil
end

-- The lifter's playing rep track, if their animation is published and playing.
local function playingRep(character: Model, lift: string): AnimationTrack?
	local id = StationAnimationConfig.AnimationIds[lift]
	local animator = r15Animator(character)
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

local function updateBars()
	local racks = Workspace:FindFirstChild(RACKS_FOLDER)
	local active: { [Instance]: boolean } = {}

	if racks then
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character == nil then
				continue
			end
			local lift = character:GetAttribute(POSE_ATTRIBUTE)
			local rackName = character:GetAttribute(RACK_ATTRIBUTE)
			if typeof(lift) ~= "string" or typeof(rackName) ~= "string" then
				continue
			end
			local rack = racks:FindFirstChild(rackName)
			local barbell = rack and rack:FindFirstChild("Barbell")
			local track = playingRep(character, lift)
			if rack == nil or not rack:IsA("Model") or barbell == nil or track == nil then
				continue
			end
			local state = barStateOf(barbell)
			if state == nil then
				continue
			end

			local leftHand = character:FindFirstChild("LeftHand")
			local rightHand = character:FindFirstChild("RightHand")
			if StationAnimationConfig.isBarHeld(lift, track.TimePosition)
				and leftHand and leftHand:IsA("BasePart") and rightHand and rightHand:IsA("BasePart") then
				local mid = (leftHand.Position + rightHand.Position) / 2
				placeBar(state, CFrame.new(mid) * rack:GetPivot().Rotation)
			else
				local rest = restOf(barbell)
				if rest then
					placeBar(state, rest)
				end
			end
			state.moved = true
			active[barbell] = true
		end
	end

	-- Bars whose lifter stopped: back to where the server rests them.
	for barbell, state in pairs(bars) do
		if state.moved and not active[barbell] then
			state.moved = false
			local rest = restOf(barbell)
			if rest then
				placeBar(state, rest)
			end
		end
	end
end

-- ---------------------------------------------------------------- start

function StationPoseAnimator.start()
	if started then
		return
	end
	started = true

	localPlayer.CharacterAdded:Connect(watchOwnCharacter)
	localPlayer.CharacterRemoving:Connect(stopOwnTrack)
	if localPlayer.Character then
		watchOwnCharacter(localPlayer.Character)
	end

	RunService.RenderStepped:Connect(updateBars)
end

return StationPoseAnimator
