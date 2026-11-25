--!strict
--[[
	LockedStance
	Client / World

	Keeps your character standing properly while the game holds it in place.

	Meets, Mock Meets, coach's trials, gym practice and the training stations hold
	the lifter still by anchoring the HumanoidRootPart on the server (standAt in
	LocalMeetService, MockMeetService, NationalsArenaVenue, GymPractice;
	MeetLiftAnimation.begin; StationPoses). A humanoid whose root is anchored stops
	updating its state: if the hold lands while the character is in the air (a jump,
	a step off an edge, the short drop after being moved into a meet room), it stays
	in Freefall for the whole hold and the Animate script loops the fall animation,
	so the lifter hangs there kicking as if floating or running in space
	(user 2026-11-25, a Regional meet's chalk-up and a coach's trial before the bench).

	So while your root is anchored, this lands the humanoid (Landed -> Running) as
	soon as it is airborne or still showing Animate's walk, run, jump or fall: Animate
	then plays its idle under whatever lift, chalk or ritual animation the game puts on
	top. Visual only: it sends nothing to the server and changes no game state; the
	client owns its humanoid's states, so this is the side that can fix them.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LockedStance = {}

-- States that mean "in the air". An anchored humanoid can't leave them by itself.
local AIRBORNE: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Flying] = true,
}
-- Animate's moving animations (StringValues under the Animate script) that must not show while held.
local MOVING_ANIMATIONS = { "walk", "run", "jump", "fall", "swim", "swimidle", "climb" }
local CHECK_SECONDS = 0.2 -- how often a held character is looked at
local RELAND_SECONDS = 0.6 -- at most one landing per this long, so it never fights the game

local function movingIdsOf(character: Model): { [string]: boolean }
	local ids = {}
	local animate = character:FindFirstChild("Animate")
	if animate == nil then
		return ids
	end
	for _, name in ipairs(MOVING_ANIMATIONS) do
		local holder = animate:FindFirstChild(name)
		if holder then
			for _, child in ipairs(holder:GetChildren()) do
				if child:IsA("Animation") and child.AnimationId ~= "" then
					ids[child.AnimationId] = true
				end
			end
		end
	end
	return ids
end

-- True while one of Animate's own moving animations still shows. The game's own tracks (Action priority and up:
-- lifts, rituals, the treadmill run) can use the same ids and are left alone.
local function showsMoving(animator: Animator, ids: { [string]: boolean }): boolean
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local priority = track.Priority
		local ownTrack = priority == Enum.AnimationPriority.Core or priority == Enum.AnimationPriority.Idle
			or priority == Enum.AnimationPriority.Movement
		if ownTrack and track.WeightCurrent > 0.3 and track.Animation and ids[track.Animation.AnimationId] then
			return true
		end
	end
	return false
end

local function watch(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if root == nil or not root:IsA("BasePart") or humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	local animator = humanoid:WaitForChild("Animator", 10)
	local ids = movingIdsOf(character)
	local lastLanded = -math.huge
	local sinceCheck = 0

	local function check()
		if not root.Anchored or humanoid.Health <= 0 or humanoid.Sit then
			return
		end
		local now = os.clock()
		if now - lastLanded < RELAND_SECONDS then
			return
		end
		local airborne = AIRBORNE[humanoid:GetState()] == true
		local moving = animator ~= nil and animator:IsA("Animator") and showsMoving(animator, ids)
		if airborne or moving then
			lastLanded = now
			root.AssemblyLinearVelocity = Vector3.zero
			humanoid:ChangeState(Enum.HumanoidStateType.Landed)
		end
	end

	local anchoredChanged = root:GetPropertyChangedSignal("Anchored"):Connect(check)
	local beat = RunService.Heartbeat:Connect(function(dt)
		sinceCheck += dt
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			check()
		end
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			anchoredChanged:Disconnect()
			beat:Disconnect()
		end
	end)
end

function LockedStance.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		task.spawn(watch, character)
	end)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return LockedStance
