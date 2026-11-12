--!strict
--[[
	CelebrationService
	Server / Meet

	Plays a celebration (CelebrationConfig) on a lifter, player or computer lifter, so everyone sees it: the animation
	once and its sounds from the lifter's body (heard by whoever is near). It tells every player it started
	(CelebrationRemotes): each player's game draws its effects (client CelebrationFx: wind trails, chalk, the shout,
	dust), and the celebrating player's screen runs its cinematic, if it has one.

	Which celebration a lifter does is decided HERE (forPlayer / forComputer): the Default for everyone for now (user
	2026-11-11); crates will hand out the others later, and forPlayer reads what the player owns and picked.

	PERFORMANCE: one animation track and a few short Sounds, made for the celebration and removed after it (the effects
	are drawn on each player's own device, client CelebrationFx).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CelebrationConfig = require(Shared:WaitForChild("Config"):WaitForChild("CelebrationConfig"))
local MeetSoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetSoundConfig"))
local CelebrationRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("CelebrationRemotes"))

local CelebrationService = {}

local FADE_IN, FADE_OUT = 0.2, 0.3

local started = false
local startedRemote: RemoteEvent? = nil
-- The track playing on each figure, so a new one replaces it.
local playing: { [Model]: AnimationTrack } = {}
-- The take each sound last played, so the next is a different one.
local lastTake: { [string]: string } = {}

function CelebrationService.start()
	if started then
		return
	end
	started = true
	startedRemote = CelebrationRemotes.createOnServer(ReplicatedStorage)
end

-- The celebration a player does after a good lift. Everyone's is the Default until crates hand out others.
function CelebrationService.forPlayer(_player: Player): string
	return CelebrationConfig.Default
end

-- A computer lifter's: the same rules as players (user 2026-11-11).
function CelebrationService.forComputer(_body: Model?): string
	return CelebrationConfig.Default
end

local function animatorOf(figure: Model): Animator?
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
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

local function playSound(figure: Model, name: string)
	local root = figure:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end
	local id, volume = CelebrationConfig.pickSound(name, lastTake[name])
	if id then
		lastTake[name] = id
	else
		local cue = MeetSoundConfig.Cues[name]
		if cue == nil then
			return
		end
		id, volume = cue.id, cue.volume
	end
	local sound = Instance.new("Sound")
	sound.Name = "Celebration_" .. name
	sound.SoundId = id :: string
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = CelebrationConfig.SoundNear
	sound.RollOffMaxDistance = CelebrationConfig.SoundFar
	sound.Parent = root
	sound:Play()
	task.delay(6, function()
		sound:Destroy()
	end)
end

--[[
	Plays celebration `id` on `figure` and returns how long to wait before the lifter walks back: its length for a
	Standing one, 0 for a Walk one (it plays over the walk). `_owner`: the player whose character it is (kept for later:
	their screen knows it by the figure). An unknown id or a figure that can't animate: nothing happens, 0.
]]
function CelebrationService.play(figure: Model?, id: string, _owner: Player?): number
	local celebration = CelebrationConfig.byId[id]
	if figure == nil or celebration == nil or not figure.Parent then
		return 0
	end
	local animator = animatorOf(figure)
	if animator == nil then
		return 0
	end
	local old = playing[figure]
	if old then
		old:Stop(0.1)
	end
	local animation = Instance.new("Animation")
	animation.Name = "Celebration"
	animation.AnimationId = celebration.animationId
	local ok, loaded = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok then
		return 0
	end
	local track = loaded :: AnimationTrack
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play(FADE_IN)
	playing[figure] = track
	local stopAt = celebration.seconds - FADE_OUT
	task.delay(math.max(0, stopAt), function()
		if playing[figure] == track then
			playing[figure] = nil
			track:Stop(FADE_OUT)
		end
	end)
	-- (A celebration's own sound track is played by each player's game, in step with the animation even if it loads late:
	-- client CelebrationFx. The body's sounds one by one only for one without a track.)
	for _, event in ipairs(if celebration.soundtrack then {} else celebration.events) do
		task.delay(event.at, function()
			if playing[figure] ~= track then
				return
			end
			local sound = event.sound
			if sound then
				playSound(figure, sound)
			end
		end)
	end
	local remote = startedRemote
	if remote then
		remote:FireAllClients(id, Workspace:GetServerTimeNow(), figure)
	end
	return if celebration.kind == "Walk" then 0 else celebration.seconds
end

-- Ends any celebration on this figure now (the lifter was called up, left...).
function CelebrationService.stop(figure: Model?)
	local track = figure and playing[figure]
	if figure and track then
		playing[figure] = nil
		track:Stop(0.15)
	end
end

return CelebrationService
