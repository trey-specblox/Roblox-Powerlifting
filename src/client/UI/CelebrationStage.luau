--!strict
--[[
	CelebrationStage
	Client / UI

	A small lit stage inside a screen: a copy of the player's own avatar on a platform in a ViewportFrame, playing a
	celebration (CelebrationConfig) over and over with its sound track, both loaded first and started together so they
	line up. Used by the admin's celebration viewer (CelebrationViewer) and the spin screen (CelebrationSpinner).

	Display only: the copy lives in the ViewportFrame; nothing is saved or given.
	PERFORMANCE: one avatar copy and up to two animation tracks while a celebration plays; call clear() when the screen
	closes. (Chalk particles don't show in a ViewportFrame.)
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CelebrationConfig = require(Shared:WaitForChild("Config"):WaitForChild("CelebrationConfig"))
local MeetSoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetSoundConfig"))

local CelebrationStage = {}

-- Roblox's own R15 walk, for a celebration played over the walk; and its idle, between plays on the spin screen.
local WALK_ANIMATION_ID = "rbxassetid://507777826"
local IDLE_ANIMATION_ID = "rbxassetid://507766388"
-- Seconds between one play and the next.
local REPLAY_GAP = 0.9
-- Where the camera looks at (the figure faces -Z, its right is +X).
CelebrationStage.LookAt = Vector3.new(0, 2.5, 0)

export type Stage = {
	viewport: ViewportFrame,
	world: WorldModel,
	camera: Camera,
	figure: Model?,
	token: number,
	tracks: { AnimationTrack },
	sounds: { Sound },
	idle: AnimationTrack?,
}

-- Builds the stage (empty: setFigure puts the avatar on it) in `parent`. `bare`: no platform and a see-through background,
-- for a screen that draws its own backdrop behind the figure (the spin screen).
function CelebrationStage.new(parent: Instance, position: UDim2, size: UDim2, bare: boolean?): Stage
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Stage"
	viewport.Position = position
	viewport.Size = size
	-- (No UIGradient here: on a ViewportFrame it tints the 3D inside too, which made the stage murky.)
	viewport.BackgroundColor3 = Color3.fromRGB(38, 48, 88)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(205, 205, 215)
	viewport.LightColor = Color3.fromRGB(255, 252, 245)
	viewport.LightDirection = Vector3.new(-0.35, -1, 0.55)
	viewport.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local floor = Instance.new("Part")
	floor.Name = "Platform"
	floor.Anchored = true
	floor.Size = Vector3.new(12, 0.4, 12)
	floor.CFrame = CFrame.new(0, -0.2, 0)
	floor.Color = Color3.fromRGB(46, 40, 38)
	floor.Material = Enum.Material.Wood
	if bare then
		viewport.BackgroundTransparency = 1
	else
		floor.Parent = world
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 38
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return { viewport = viewport, world = world, camera = camera, figure = nil, token = 0, tracks = {}, sounds = {}, idle = nil }
end

-- Points the camera from `from` at the figure.
function CelebrationStage.look(stage: Stage, from: Vector3)
	stage.camera.CFrame = CFrame.lookAt(from, CelebrationStage.LookAt)
end

local function animatorOf(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	return animator
end

local function load(animator: Animator, id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		return nil
	end
	local loaded = track :: AnimationTrack
	loaded.Priority = priority
	loaded.Looped = looped
	return loaded
end

local lastTake: { [string]: string } = {}
local function soundFor(name: string): (string?, number)
	local id, volume = CelebrationConfig.pickSound(name, lastTake[name])
	if id then
		lastTake[name] = id
		return id, volume
	end
	local cue = MeetSoundConfig.Cues[name]
	if cue then
		return cue.id, cue.volume
	end
	return nil, 0
end

local function clearPlays(stage: Stage)
	for _, track in ipairs(stage.tracks) do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(stage.tracks)
	for _, sound in ipairs(stage.sounds) do
		sound:Destroy()
	end
	table.clear(stage.sounds)
end

-- Stops what is playing (the idle stance stays).
function CelebrationStage.stop(stage: Stage)
	stage.token += 1
	clearPlays(stage)
end

-- A fresh copy of the player's own avatar on the stage: no scripts, nothing that moves by itself, the root held still,
-- standing at ease. False when the player has no character yet.
function CelebrationStage.setFigure(stage: Stage): boolean
	CelebrationStage.stop(stage)
	if stage.figure then
		(stage.figure :: Model):Destroy()
		stage.figure = nil
		stage.idle = nil
	end
	local character = Players.LocalPlayer.Character
	if character == nil then
		return false
	end
	local was = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = was
	if copy == nil then
		return false
	end
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("BaseScript") or item:IsA("Sound") or item:IsA("ForceField") or item:IsA("BillboardGui") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	local root = copy:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		copy:Destroy()
		return false
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	copy:PivotTo(CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	copy.Parent = stage.world
	stage.figure = copy
	local animator = animatorOf(copy)
	if animator then
		local idle = load(animator, IDLE_ANIMATION_ID, Enum.AnimationPriority.Idle, true)
		if idle then
			idle:Play(0)
			stage.idle = idle
		end
	end
	return true
end

--[[
	Plays `celebration` on the figure, again and again (with a short gap) until stop() or another play; once only when
	`once`. `speed` 1 is normal, 0.5 slow motion. `volume` scales its sounds (1 when nil).
]]
function CelebrationStage.play(stage: Stage, celebration: CelebrationConfig.Celebration, speed: number, once: boolean?,
	volume: number?)
	CelebrationStage.stop(stage)
	local model = stage.figure
	if model == nil then
		return
	end
	local animator = animatorOf(model)
	if animator == nil then
		return
	end
	local loudness = volume or 1
	local mine = stage.token
	task.spawn(function()
		while stage.token == mine do
			if celebration.kind == "Walk" then
				local walk = load(animator, WALK_ANIMATION_ID, Enum.AnimationPriority.Movement, true)
				if walk then
					table.insert(stage.tracks, walk)
					walk:Play(0.1, 1, speed)
				end
			end
			local track = load(animator, celebration.animationId, Enum.AnimationPriority.Action, false)
			local soundtrack = celebration.soundtrack
			local sound: Sound? = nil
			if soundtrack then
				local made = Instance.new("Sound")
				made.SoundId = soundtrack
				made.Volume = CelebrationConfig.SoundtrackVolume * loudness
				made.PlaybackSpeed = speed
				made.Parent = SoundService
				table.insert(stage.sounds, made)
				sound = made
			end
			-- Both loaded first, then started together, so the sound lines up with the moves.
			local loading: { Instance } = {}
			if sound then
				table.insert(loading, sound)
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = celebration.animationId
			table.insert(loading, animation)
			pcall(function()
				ContentProvider:PreloadAsync(loading)
			end)
			animation:Destroy()
			if stage.token ~= mine then
				return
			end
			if track then
				table.insert(stage.tracks, track)
				track:Play(0.1, 1, speed)
			end
			if sound then
				sound:Play()
			end
			for _, event in ipairs(if soundtrack then {} else celebration.events) do
				local id, eventVolume = soundFor(event.sound or "")
				if id then
					local made = Instance.new("Sound")
					made.SoundId = id
					made.Volume = eventVolume * 0.8 * loudness
					made.PlaybackSpeed = speed
					made.Parent = SoundService
					table.insert(stage.sounds, made)
					task.delay(event.at / speed, function()
						if stage.token == mine and made.Parent then
							made:Play()
						end
					end)
				end
			end
			task.wait(celebration.seconds / speed + REPLAY_GAP)
			if stage.token ~= mine then
				return
			end
			for _, old in ipairs(stage.tracks) do
				old:Stop(0.2)
			end
			table.clear(stage.tracks)
			for _, old in ipairs(stage.sounds) do
				old:Destroy()
			end
			table.clear(stage.sounds)
			if once then
				return
			end
		end
	end)
end

-- Stops everything and takes the figure off the stage (when the screen closes).
function CelebrationStage.clear(stage: Stage)
	CelebrationStage.stop(stage)
	if stage.figure then
		(stage.figure :: Model):Destroy()
		stage.figure = nil
		stage.idle = nil
	end
end

return CelebrationStage
