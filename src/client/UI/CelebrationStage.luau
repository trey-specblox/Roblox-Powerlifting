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
	-- Where the figure stands (a walk-out walks it up to here).
	home: CFrame?,
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

-- Stops what is playing (the idle stance stays) and stands the figure back on its spot.
function CelebrationStage.stop(stage: Stage)
	stage.token += 1
	clearPlays(stage)
	if stage.figure and stage.home then
		(stage.figure :: Model):PivotTo(stage.home :: CFrame)
	end
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
	stage.home = copy:GetPivot()
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
			if celebration.kind == "Walk" or celebration.kind == "WalkLoop" then
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
			for _, event in ipairs(if soundtrack then {} else (celebration.events or {})) do
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

--[[
	A walk-out (EntranceConfig entry), over and over: the figure walks toward the camera in its walk style for
	WALKOUT_STUDS (at the speed the walk is made for, so the feet keep up with the floor), stops, does its hype move with
	its sound track, then starts again. Roblox's own walk at `defaultSpeed` for one without a walk style.
]]
local WALKOUT_STUDS = 8
local HYPE_GAP = 0.8
local RunService = game:GetService("RunService")
function CelebrationStage.playEntrance(stage: Stage, entrance: any, defaultSpeed: number)
	CelebrationStage.stop(stage)
	local model = stage.figure
	if model == nil then
		return
	end
	local animator = animatorOf(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if animator == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local home = stage.home or model:GetPivot()
	local mine = stage.token
	local walkId = entrance.walkAnimationId or WALK_ANIMATION_ID
	local speed = entrance.walkSpeed or defaultSpeed
	task.spawn(function()
		while stage.token == mine do
			-- Load both moves and the sound first, so nothing starts late.
			local walk = load(animator, walkId, Enum.AnimationPriority.Movement, true)
			local hype = load(animator, entrance.hypeAnimationId, Enum.AnimationPriority.Action, false)
			local sound: Sound? = nil
			if entrance.hypeSoundtrack then
				local made = Instance.new("Sound")
				made.SoundId = entrance.hypeSoundtrack
				made.Volume = CelebrationConfig.SoundtrackVolume
				made.Parent = SoundService
				table.insert(stage.sounds, made)
				sound = made
			end
			local loading: { Instance } = {}
			for _, id in ipairs({ walkId, entrance.hypeAnimationId }) do
				local animation = Instance.new("Animation")
				animation.AnimationId = id
				table.insert(loading, animation)
			end
			if sound then
				table.insert(loading, sound)
			end
			pcall(function()
				ContentProvider:PreloadAsync(loading)
			end)
			if stage.token ~= mine then
				return
			end
			-- The walk: from WALKOUT_STUDS behind the spot up to it, easing in and out.
			local seconds = WALKOUT_STUDS / speed
			if walk then
				table.insert(stage.tracks, walk)
				walk:Play(0.2)
			end
			local started = os.clock()
			while stage.token == mine do
				local t = os.clock() - started
				local u = math.clamp(t / seconds, 0, 1)
				-- Ease the last fifth only, so the feet keep up with the floor most of the way.
				local along = if u < 0.8 then u * 0.9 / 0.8 else 0.9 + 0.1 * math.sin((u - 0.8) / 0.2 * math.pi / 2)
				model:PivotTo(home * CFrame.new(0, 0, WALKOUT_STUDS * (1 - along)))
				if walk then
					walk:AdjustSpeed(if u < 0.8 then 1 else math.max(0.35, 1 - (u - 0.8) / 0.2))
				end
				if u >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			if stage.token ~= mine then
				return
			end
			model:PivotTo(home)
			if walk then
				walk:Stop(0.25)
			end
			-- The hype move, its sound started with it.
			if hype then
				table.insert(stage.tracks, hype)
				hype:Play(0.15)
			end
			if sound then
				sound:Play()
			end
			task.wait(entrance.hypeSeconds + HYPE_GAP)
			if stage.token ~= mine then
				return
			end
			clearPlays(stage)
		end
	end)
end

--[[
	A fail style (StationAnimationConfig): the figure does its squat and deadlift fails in turn, a loaded bar
	(ReplicatedStorage.SpinPreviewBarbell, the game's barbell) in its hands until each fail's release: then the bar is
	taken away (the squat: the spotters) or set down on the floor (the deadlift). `fails`: { { lift, Fail } } in order.
	The bench fails aren't shown (there is no bench on the stage).
]]
function CelebrationStage.playFail(stage: Stage, fails: { { any } })
	CelebrationStage.stop(stage)
	local model = stage.figure
	if model == nil then
		return
	end
	local animator = animatorOf(model)
	local leftHand = model:FindFirstChild("LeftHand")
	local rightHand = model:FindFirstChild("RightHand")
	if animator == nil or leftHand == nil or rightHand == nil or not leftHand:IsA("BasePart") or not rightHand:IsA("BasePart") then
		return
	end
	local template = ReplicatedStorage:FindFirstChild("SpinPreviewBarbell")
	local mine = stage.token
	task.spawn(function()
		local index = 0
		while stage.token == mine do
			index = index % #fails + 1
			local lift, fail = fails[index][1], fails[index][2]
			local track = load(animator, fail.id, Enum.AnimationPriority.Action, false)
			local animation = Instance.new("Animation")
			animation.AnimationId = fail.id
			pcall(function()
				ContentProvider:PreloadAsync({ animation })
			end)
			if stage.token ~= mine or track == nil then
				return
			end
			local bar: Model? = nil
			if template and template:IsA("Model") then
				local made = template:Clone()
				made.Parent = stage.world
				bar = made
			end
			table.insert(stage.tracks, track)
			track:Play(0.1)
			local started = os.clock()
			local floorY = 0
			while stage.token == mine do
				local t = os.clock() - started
				if t >= fail.length then
					break
				end
				local held = bar
				if held then
					if t < fail.release then
						-- Held: across the hands, the middle between them.
						local l, r = (leftHand :: BasePart).Position, (rightHand :: BasePart).Position
						local across = r - l
						if across.Magnitude > 0.1 then
							local x = across.Unit
							local up = Vector3.yAxis - x * x:Dot(Vector3.yAxis)
							held:PivotTo(CFrame.fromMatrix((l + r) / 2, x, up.Unit))
						end
					elseif lift == "Deadlift" then
						-- Set down: the plates on the floor where it was.
						local at = held:GetPivot()
						if at.Position.Y > floorY + 1.02 then
							held:PivotTo(at - Vector3.new(0, math.min(at.Position.Y - (floorY + 1), 0.25), 0))
						end
					else
						-- The spotters take it.
						held:Destroy()
						bar = nil
					end
				end
				RunService.RenderStepped:Wait()
			end
			if bar then
				bar:Destroy()
			end
			if stage.token ~= mine then
				return
			end
			track:Stop(0.25)
			task.wait(0.9)
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
