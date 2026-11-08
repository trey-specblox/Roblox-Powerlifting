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
	     player's screen; the server's barbell never moves. Meet lifters too
	     (GAME_DESIGN §37.5): players and computer lifters marked MeetLift with a
	     MeetRack, whose lift the server animates (MeetLiftAnimation). On a
	     meet miss the attribute MeetBarHeld says when the bar leaves the
	     hands; a let-go bar glides back to its rest (the spotters lift it).

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
-- Meet lifters (MeetLiftAnimation): the lift attribute, the rack's ObjectValue, and the computer lifters' folder.
local MEET_LIFT_ATTRIBUTE = "MeetLift"
local MEET_RACK_VALUE = "MeetRack"
local MEET_BAR_HELD_ATTRIBUTE = "MeetBarHeld"
local COMPUTER_LIFTERS_FOLDER = "LocalMeetComputerLifters"
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
	barbell: Instance,
	-- Each barbell part with its place relative to Bar_Shaft (the bar's centre), told by the server (BarOffset).
	parts: { { part: BasePart, offset: CFrame } },
	-- The server changed the plates on it (StationVisuals.loadBar): read the parts again before moving them.
	changed: boolean,
	moved: boolean,
	-- Where the bar is drawn now. A bar let go of glides back to its rest instead of jumping (a meet's spotters
	-- lifting it back to the J-cups, GAME_DESIGN §37.5).
	shown: CFrame?,
}
local BAR_OFFSET_ATTRIBUTE = "BarOffset"
-- How fast a let-go bar glides to its rest (per second; about 0.5 s to get there).
local GLIDE_RATE = 7

-- An ordinary (strong) table, not a weak one: Roblox may drop an Instance key
-- from a weak table while the barbell still exists (same fix as the server's
-- StationVisuals, 2026-10-19). The entry is removed when the barbell is destroyed.
local bars: { [Instance]: BarState } = {}

local function barStateOf(barbell: Instance): BarState?
	local state = bars[barbell]
	if state then
		return state
	end
	local shaft = barbell:FindFirstChild("Bar_Shaft")
	if shaft == nil or not shaft:IsA("BasePart") then
		return nil
	end
	local newState: BarState = { barbell = barbell, parts = {}, changed = true, moved = false }
	bars[barbell] = newState
	local function changed()
		newState.changed = true
	end
	barbell.DescendantAdded:Connect(changed)
	barbell.DescendantRemoving:Connect(changed)
	barbell.Destroying:Connect(function()
		bars[barbell] = nil
	end)
	return newState
end

local function placeBar(state: BarState, centre: CFrame)
	state.shown = centre
	if state.changed then
		state.changed = false
		table.clear(state.parts)
		for _, part in ipairs(state.barbell:GetDescendants()) do
			local offset = part:GetAttribute(BAR_OFFSET_ATTRIBUTE)
			if part:IsA("BasePart") and typeof(offset) == "CFrame" then
				table.insert(state.parts, { part = part, offset = offset })
			end
		end
	end
	for _, entry in ipairs(state.parts) do
		entry.part.CFrame = centre * entry.offset
	end
end

-- Moves a let-go bar a step of `dt` seconds toward `rest` (straight there when it is close or was never drawn).
local function glideBar(state: BarState, rest: CFrame, dt: number)
	local shown = state.shown
	if shown == nil or (shown.Position - rest.Position).Magnitude < 0.02 then
		placeBar(state, rest)
		return
	end
	placeBar(state, shown:Lerp(rest, 1 - math.exp(-GLIDE_RATE * dt)))
end

local function restOf(barbell: Instance): CFrame?
	local rest = barbell:GetAttribute("RestCFrame")
	return if typeof(rest) == "CFrame" then rest else nil
end

--[[
	Whether the lifter holds the bar now, or nil when nothing says. A meet's
	missed lift says it outright (the attribute MeetBarHeld, MeetLiftAnimation:
	held until the spotters take it or it is set down, GAME_DESIGN §37.5);
	otherwise the playing rep animation does (BarHeldWindows).
]]
local function holdingBar(character: Model, lift: string): boolean?
	local told = character:GetAttribute(MEET_BAR_HELD_ATTRIBUTE)
	if typeof(told) == "boolean" then
		return told
	end
	local id = StationAnimationConfig.AnimationIds[lift]
	local animator = r15Animator(character)
	if id == nil or id == "" or animator == nil then
		return nil
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation and track.Animation.AnimationId == id then
			return StationAnimationConfig.isBarHeld(lift, track.TimePosition)
		end
	end
	return nil
end

-- Moves `rack`'s barbell with `character`'s hands while `lift`'s animation holds the bar; otherwise rests it.
local function followHands(character: Model, rack: Instance?, lift: string, active: { [Instance]: boolean }, dt: number)
	local barbell = rack and rack:FindFirstChild("Barbell")
	local held = holdingBar(character, lift)
	if rack == nil or not rack:IsA("Model") or barbell == nil or held == nil then
		return
	end
	local state = barStateOf(barbell)
	if state == nil then
		return
	end

	local leftHand = character:FindFirstChild("LeftHand")
	local rightHand = character:FindFirstChild("RightHand")
	if held and leftHand and leftHand:IsA("BasePart") and rightHand and rightHand:IsA("BasePart") then
		local mid = (leftHand.Position + rightHand.Position) / 2
		placeBar(state, CFrame.new(mid) * rack:GetPivot().Rotation)
	else
		local rest = restOf(barbell)
		if rest then
			glideBar(state, rest, dt)
		end
	end
	state.moved = true
	active[barbell] = true
end

--[[
	A meet lifter (GAME_DESIGN §37.5, MeetLiftAnimation on the server): marked
	with the attribute MeetLift = the lift and an ObjectValue MeetRack = their
	platform's rack. Players and the Local meet's computer lifters alike.
]]
local function followMeetLifter(character: Model, active: { [Instance]: boolean }, dt: number)
	local lift = character:GetAttribute(MEET_LIFT_ATTRIBUTE)
	local rackValue = character:FindFirstChild(MEET_RACK_VALUE)
	if typeof(lift) == "string" and rackValue and rackValue:IsA("ObjectValue") then
		followHands(character, rackValue.Value, lift, active, dt)
	end
end

local function updateBars(dt: number)
	local racks = Workspace:FindFirstChild(RACKS_FOLDER)
	local active: { [Instance]: boolean } = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character == nil then
			continue
		end
		local lift = character:GetAttribute(POSE_ATTRIBUTE)
		local rackName = character:GetAttribute(RACK_ATTRIBUTE)
		if racks and typeof(lift) == "string" and typeof(rackName) == "string" then
			followHands(character, racks:FindFirstChild(rackName), lift, active, dt)
		else
			followMeetLifter(character, active, dt)
		end
	end
	local computerLifters = Workspace:FindFirstChild(COMPUTER_LIFTERS_FOLDER)
	if computerLifters then
		for _, body in ipairs(computerLifters:GetChildren()) do
			if body:IsA("Model") then
				followMeetLifter(body, active, dt)
			end
		end
	end

	-- Bars whose lifter stopped: back to where the server rests them, gliding (a meet's spotters follow it).
	for barbell, state in pairs(bars) do
		if state.moved and not active[barbell] then
			local rest = restOf(barbell)
			if rest then
				glideBar(state, rest, dt)
				state.moved = (state.shown :: CFrame).Position ~= rest.Position
			else
				state.moved = false
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
