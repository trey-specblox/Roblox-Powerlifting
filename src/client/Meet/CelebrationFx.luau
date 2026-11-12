--!strict
--[[
	CelebrationFx
	Client / Meet

	The celebrations' visual effects (user 2026-11-11: "add vfx to the celebrations, Like a movement/wind affect, more
	chalk, a visible yelling affect, like a shouting visual etc."), drawn by each player's own game for everyone near:
	the server only says who started which celebration and when (CelebrationRemotes), and each celebration lists its
	effects with their moments (CelebrationConfig `fx`):

		Swoosh     wind: white trails off both hands through a fast arm move, with chalk dust shaken off them
		Jump       trails off both feet while they're in the air
		Shout      the shout made visible: rings pulsing out from the mouth with short speed lines, for as long as the
		           roar lasts (the celebrations have no voices: the user's choice)
		Dust       a ring and a puff of dust on the floor at the feet (a stomp, a landing, sitting down)
		KneeDust   a bigger one, with chalk bursting off the knees (landing on the knees)
		ChalkPuff  chalk off the hands (a clap); ChalkBurst a big cloud of it with a flash ring (the record clap)

	Built only from Roblox's own pieces (Trail, ParticleEmitter, engine textures), as the cutscene kit's VFX are
	(References: RobloxKits/CutsceneSkills): white core, the lifter always readable. It also hands the celebrating
	player's own screen to CelebrationCinema.

	Display only: it decides and saves nothing.
	PERFORMANCE: only near the camera (CULL_STUDS); a celebration's emitters and trails exist only while it plays (about
	ten small ones) and are removed after; bursts use Emit, nothing is left emitting.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CelebrationConfig = require(Shared:WaitForChild("Config"):WaitForChild("CelebrationConfig"))
local CelebrationRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("CelebrationRemotes"))

local CelebrationCinema = require(script.Parent:WaitForChild("CelebrationCinema"))

local CelebrationFx = {}

-- Further than this from the camera, no effects (nobody would see them).
local CULL_STUDS = 220
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local WHITE = Color3.fromRGB(255, 252, 240)
-- The dark "ink" behind each white shape, so it reads on a bright room as well as a dark arena (the cutscene kit's
-- rule: white core, dark ink; Studio test 2026-11-11: white alone vanished in the bright lobby).
local INK = Color3.fromRGB(28, 30, 42)
local WIND = Color3.fromRGB(176, 204, 236)
local CHALK = Color3.fromRGB(246, 246, 240)
local DUST = Color3.fromRGB(150, 138, 120)
-- How often the shout pulses (seconds), and a swoosh sheds chalk.
local SHOUT_EVERY = 0.13
local SHED_EVERY = 0.06

local function part(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function attachment(parent: BasePart, name: string, at: CFrame): Attachment
	local made = Instance.new("Attachment")
	made.Name = name
	made.CFrame = at
	made.Parent = parent
	return made
end

local function emitter(parent: Attachment, props: { [string]: any }): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Enabled = false
	made.Rate = 0
	made.LightInfluence = 0.2
	for key, value in pairs(props) do
		(made :: any)[key] = value
	end
	made.Parent = parent
	return made
end

local function fade(from: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, 1) })
end

local function grow(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

-- A trail between two attachments on a part (only drawn while it moves), off until switched on.
local function trail(on: BasePart, across: Vector3, colour: Color3, lifetime: number): Trail
	local a0 = attachment(on, "FxTrail0", CFrame.new(across))
	local a1 = attachment(on, "FxTrail1", CFrame.new(-across))
	local made = Instance.new("Trail")
	made.Attachment0, made.Attachment1 = a0, a1
	made.Color = ColorSequence.new(colour)
	made.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	made.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
	made.Lifetime = lifetime
	made.MinLength = 0.03
	made.LightEmission = 0.1
	made.LightInfluence = 0.3
	made.FaceCamera = true
	made.Enabled = false
	made.Parent = on
	return made
end

type Kit = {
	hands: { BasePart },
	handTrails: { Trail },
	handChalk: { ParticleEmitter },
	footTrails: { Trail },
	shoutRings: ParticleEmitter?,
	shoutLines: ParticleEmitter?,
	shoutInk: ParticleEmitter?,
	shoutInkLines: ParticleEmitter?,
	floorRing: ParticleEmitter?,
	floorDust: ParticleEmitter?,
	floorAt: Attachment?,
	knees: { ParticleEmitter },
	burstRing: { ParticleEmitter },
	made: { Instance },
}

-- Everything a celebration's effects need, put on the figure before they start (an emitter can't Emit the moment it is
-- made), removed after.
local function prepare(figure: Model): Kit
	local kit: Kit = { hands = {}, handTrails = {}, handChalk = {}, footTrails = {}, knees = {}, burstRing = {}, made = {} }
	local function keep(item: Instance)
		table.insert(kit.made, item)
	end
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = part(figure, name)
		if hand then
			table.insert(kit.hands, hand)
			local t = trail(hand, Vector3.new(0.5, 0, 0), WIND, 0.28)
			table.insert(kit.handTrails, t)
			keep(t)
			keep(t.Attachment0 :: Attachment)
			keep(t.Attachment1 :: Attachment)
			local at = attachment(hand, "FxChalk", CFrame.new())
			keep(at)
			table.insert(kit.handChalk, emitter(at, {
				Texture = SMOKE, Color = ColorSequence.new(CHALK), Size = grow(0.35, 1.2), Transparency = fade(0.25),
				Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.3, 1.2), SpreadAngle = Vector2.new(180, 180),
				Drag = 3, RotSpeed = NumberRange.new(-40, 40), Rotation = NumberRange.new(0, 360),
			}))
			table.insert(kit.burstRing, emitter(at, {
				Texture = RING, Color = ColorSequence.new(WHITE), Size = grow(0.4, 3.2), Transparency = fade(0.25),
				Lifetime = NumberRange.new(0.3, 0.3), Speed = NumberRange.new(0, 0), LightEmission = 0.6,
				Orientation = Enum.ParticleOrientation.FacingCamera,
			}))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = part(figure, name)
		if foot then
			local t = trail(foot, Vector3.new(0.45, 0, 0), WIND, 0.24)
			table.insert(kit.footTrails, t)
			keep(t)
			keep(t.Attachment0 :: Attachment)
			keep(t.Attachment1 :: Attachment)
		end
	end
	local head = part(figure, "Head")
	if head then
		-- In front of the mouth (the head's front is -Z).
		local mouth = attachment(head, "FxShout", CFrame.new(0, -0.15, -0.7))
		keep(mouth)
		local function ring(colour: Color3, size: number, transparency: number, offset: number): ParticleEmitter
			return emitter(mouth, {
				Texture = RING, Color = ColorSequence.new(colour), Size = grow(0.7 * size, 5.6 * size),
				Transparency = fade(transparency), Lifetime = NumberRange.new(0.5, 0.5), Speed = NumberRange.new(8, 8),
				SpreadAngle = Vector2.new(0, 0), EmissionDirection = Enum.NormalId.Front,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular, ZOffset = offset, LightInfluence = 0,
			})
		end
		local function lines(colour: Color3, size: number, transparency: number, offset: number): ParticleEmitter
			return emitter(mouth, {
				Texture = SPARK, Color = ColorSequence.new(colour), Size = grow(0.42 * size, 0.16 * size),
				Transparency = fade(transparency), Squash = NumberSequence.new(3), Lifetime = NumberRange.new(0.2, 0.28),
				Speed = NumberRange.new(14, 19), SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Front,
				Orientation = Enum.ParticleOrientation.VelocityParallel, ZOffset = offset, LightInfluence = 0,
			})
		end
		kit.shoutRings = ring(WHITE, 1, 0, 0.1)
		kit.shoutInk = ring(INK, 1.08, 0.45, 0)
		kit.shoutLines = lines(WHITE, 1, 0, 0.1)
		kit.shoutInkLines = lines(INK, 1.25, 0.5, 0)
	end
	local root = part(figure, "HumanoidRootPart")
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		local floor = attachment(root, "FxFloor", CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2) + 0.08, 0))
		keep(floor)
		kit.floorAt = floor
		-- Flat on the floor: a particle moving straight up, faced across its motion, lies flat.
		kit.floorRing = emitter(floor, {
			Texture = RING, Color = ColorSequence.new(DUST), Size = grow(0.8, 6), Transparency = fade(0.05),
			Lifetime = NumberRange.new(0.45, 0.45), Speed = NumberRange.new(0.05, 0.05), SpreadAngle = Vector2.new(0, 0),
			EmissionDirection = Enum.NormalId.Top, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		})
		kit.floorDust = emitter(floor, {
			Texture = SMOKE, Color = ColorSequence.new(DUST), Size = grow(0.6, 2.2), Transparency = fade(0.3),
			Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(85, 85),
			EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -1.5, 0), Drag = 4,
			Rotation = NumberRange.new(0, 360),
		})
	end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg" }) do
		local shin = part(figure, name)
		if shin then
			-- At the knee (the top of the shin).
			local knee = attachment(shin, "FxKnee", CFrame.new(0, shin.Size.Y / 2 - 0.2, 0))
			keep(knee)
			table.insert(kit.knees, emitter(knee, {
				Texture = SMOKE, Color = ColorSequence.new(CHALK), Size = grow(0.4, 1.6), Transparency = fade(0.35),
				Lifetime = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(2, 4.5), SpreadAngle = Vector2.new(180, 60),
				Drag = 3.5, Rotation = NumberRange.new(0, 360),
			}))
		end
	end
	return kit
end

local function cleanUp(kit: Kit)
	for _, item in ipairs(kit.made) do
		if item:IsA("Trail") then
			item.Enabled = false
		end
	end
	-- (After the last particles have faded.)
	task.delay(1.6, function()
		for _, item in ipairs(kit.made) do
			item:Destroy()
		end
	end)
end

local function setTrails(trails: { Trail }, on: boolean)
	for _, t in ipairs(trails) do
		t.Enabled = on
	end
end

-- Repeats `step` every `every` seconds for `seconds`, while `alive()`.
local function pulse(seconds: number, every: number, alive: () -> boolean, step: () -> ())
	task.spawn(function()
		local stopAt = os.clock() + seconds
		while os.clock() < stopAt and alive() do
			step()
			task.wait(every)
		end
	end)
end

local function fire(kit: Kit, effect: CelebrationConfig.Fx, alive: () -> boolean)
	local kind, seconds = effect.kind, effect.seconds or 0.4
	if kind == "Swoosh" then
		setTrails(kit.handTrails, true)
		pulse(seconds, SHED_EVERY, alive, function()
			for _, chalk in ipairs(kit.handChalk) do
				chalk:Emit(2)
			end
		end)
		task.delay(seconds, setTrails, kit.handTrails, false)
	elseif kind == "Jump" then
		setTrails(kit.footTrails, true)
		task.delay(seconds, setTrails, kit.footTrails, false)
	elseif kind == "Shout" then
		local rings, lines = kit.shoutRings, kit.shoutLines
		pulse(seconds, SHOUT_EVERY, alive, function()
			if rings then
				rings:Emit(1)
			end
			if lines then
				lines:Emit(5)
			end
			if kit.shoutInk then
				(kit.shoutInk :: ParticleEmitter):Emit(1)
			end
			if kit.shoutInkLines then
				(kit.shoutInkLines :: ParticleEmitter):Emit(5)
			end
		end)
	elseif kind == "Dust" or kind == "KneeDust" then
		local big = kind == "KneeDust"
		if kit.floorRing then
			kit.floorRing:Emit(1)
		end
		if kit.floorDust then
			kit.floorDust:Emit(if big then 22 else 12)
		end
		if big then
			for _, knee in ipairs(kit.knees) do
				knee:Emit(12)
			end
		end
	elseif kind == "ChalkPuff" or kind == "ChalkBurst" then
		local big = kind == "ChalkBurst"
		for _, chalk in ipairs(kit.handChalk) do
			-- A puff that spreads wider than the swoosh's dust.
			chalk.Speed = if big then NumberRange.new(3, 8) else NumberRange.new(1.5, 3.5)
			chalk.Size = if big then grow(0.6, 3.2) else grow(0.35, 1.5)
			chalk:Emit(if big then 60 else 20)
		end
		if big then
			for _, ring in ipairs(kit.burstRing) do
				ring:Emit(1)
			end
		end
		task.delay(0.05, function()
			for _, chalk in ipairs(kit.handChalk) do
				chalk.Speed = NumberRange.new(0.3, 1.2)
				chalk.Size = grow(0.35, 1.2)
			end
		end)
	end
end

local running: { [Model]: number } = {}

-- The celebration's animation playing on `figure` (it reaches each player's game a moment after it starts on the server,
-- later still the first time while it loads), or nil if it hasn't shown up within `wait` seconds.
local function trackOf(figure: Model, animationId: string, wait: number): AnimationTrack?
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return nil
	end
	local stopAt = os.clock() + wait
	repeat
		for _, track in ipairs((animator :: Animator):GetPlayingAnimationTracks()) do
			local animation = track.Animation
			if animation and animation.AnimationId == animationId and track.TimePosition > 0 then
				return track
			end
		end
		task.wait(0.03)
	until os.clock() > stopAt or figure.Parent == nil
	return nil
end

--[[
	The celebration's own sound track, from the lifter, locked to where its animation is on this player's screen (`clock`),
	not to the server's clock: the animation can start late here while it loads, and the sound must match the moves
	(Studio test 2026-11-11: following the server's clock it ran 0.2 s behind, then 0.5 s ahead, on first plays). Checked
	again once it plays and nudged back if it drifted. Removed when it ends or another celebration replaces it.
]]
local function playSoundtrack(root: BasePart, celebration: CelebrationConfig.Celebration, clock: () -> number,
	track: AnimationTrack?, alive: () -> boolean)
	local id = celebration.soundtrack
	if id == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "CelebrationSoundtrack"
	sound.SoundId = id
	sound.Volume = CelebrationConfig.SoundtrackVolume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = CelebrationConfig.SoundNear
	sound.RollOffMaxDistance = CelebrationConfig.SoundFar
	sound.Parent = root
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ sound })
		end)
		local at = clock()
		if not alive() or at >= celebration.seconds or sound.Parent == nil then
			sound:Destroy()
			return
		end
		sound.TimePosition = math.max(0, at)
		sound:Play()
		task.wait(0.4)
		if track and track.IsPlaying and math.abs(sound.TimePosition - track.TimePosition) > 0.05 then
			sound.TimePosition = track.TimePosition
		end
		while sound.Parent and sound.IsPlaying and alive() do
			task.wait(0.25)
		end
		sound:Destroy()
	end)
end

-- Draws celebration `id`'s effects on `figure`, as of `startedAt` (Workspace:GetServerTimeNow()).
function CelebrationFx.play(id: string, startedAt: number, figure: Model)
	local celebration = CelebrationConfig.byId[id]
	local root = part(figure, "HumanoidRootPart")
	if celebration == nil or root == nil or figure.Parent == nil then
		return
	end
	if (Workspace.CurrentCamera.CFrame.Position - root.Position).Magnitude > CULL_STUDS then
		return
	end
	local token = (running[figure] or 0) + 1
	running[figure] = token
	local function alive(): boolean
		return running[figure] == token and figure.Parent ~= nil
	end
	local kit = prepare(figure)
	local function stillMine(): boolean
		return (running[figure] == nil or running[figure] == token) and figure.Parent ~= nil
	end
	task.spawn(function()
		-- Everything follows the animation as this screen shows it (the server's clock only if it never shows up).
		local track = trackOf(figure, celebration.animationId, 2.5)
		local function clock(): number
			if track and track.IsPlaying then
				return track.TimePosition
			end
			return Workspace:GetServerTimeNow() - startedAt
		end
		-- (The track rings on a little past the moves: it is let finish unless another celebration takes over.)
		playSoundtrack(root, celebration, clock, track, stillMine)
		local elapsed = clock()
		for _, effect in ipairs(celebration.fx) do
			local wait = effect.at - elapsed
			if wait > -0.05 then
				task.delay(math.max(0, wait), function()
					if alive() then
						fire(kit, effect, alive)
					end
				end)
			end
		end
		task.delay(math.max(0, celebration.seconds - elapsed) + 0.3, function()
			if running[figure] == token then
				running[figure] = nil
			end
			cleanUp(kit)
		end)
	end)
end

function CelebrationFx.start()
	CelebrationCinema.start()
	local remote = CelebrationRemotes.waitForClient(ReplicatedStorage)
	remote.OnClientEvent:Connect(function(id: any, startedAt: any, figure: any)
		if typeof(id) ~= "string" or typeof(startedAt) ~= "number" or typeof(figure) ~= "Instance" or not figure:IsA("Model") then
			return
		end
		CelebrationFx.play(id, startedAt, figure)
		if figure == Players.LocalPlayer.Character then
			CelebrationCinema.play(id, startedAt)
		end
	end)
end

return CelebrationFx
