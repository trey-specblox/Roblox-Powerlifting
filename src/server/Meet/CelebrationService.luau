--!strict
--[[
	CelebrationService
	Server / Meet

	Plays a celebration (CelebrationConfig) on a lifter, player or computer lifter, so everyone sees it: the animation
	once and its sounds from the lifter's body (heard by whoever is near). It tells every player it started
	(CelebrationRemotes): each player's game draws its effects (client CelebrationFx: wind trails, chalk, the shout,
	dust), and the celebrating player's screen runs its cinematic, if it has one.

	Which celebration a lifter does is decided HERE (forPlayer / forComputer): a player's is the one saved in their data
	(the Default until they spin at the celebration NPC, CelebrationSpinService); a computer lifter does the Default.

	PERFORMANCE: one animation track and a few short Sounds, made for the celebration and removed after it (the effects
	are drawn on each player's own device, client CelebrationFx).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CelebrationConfig = require(Shared:WaitForChild("Config"):WaitForChild("CelebrationConfig"))
local MeetSoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetSoundConfig"))
local CelebrationRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("CelebrationRemotes"))
local PlayerDataService = require(script.Parent.Parent:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))

local CelebrationService = {}

local FADE_IN, FADE_OUT = 0.2, 0.3

local started = false
local startedRemote: RemoteEvent? = nil
-- The track playing on each figure, so a new one replaces it.
local playing: { [Model]: AnimationTrack } = {}
-- The figures doing a "WalkLoop" one (until they are back: endWalk).
local looping: { [Model]: boolean } = {}
-- A looping one never runs longer than this, whatever happens to the walk.
local LOOP_LIMIT_SECONDS = 45
-- The take each sound last played, so the next is a different one.
local lastTake: { [string]: string } = {}

function CelebrationService.start()
	if started then
		return
	end
	started = true
	startedRemote = CelebrationRemotes.createOnServer(ReplicatedStorage)
	-- (And the walk-out hype moves' one, which MeetEntrance fires.)
	CelebrationRemotes.createHypeOnServer(ReplicatedStorage)
end

-- The celebration a player does after a good lift on `attempt` (1 to 3): the one in that attempt's slot (LoadoutConfig,
-- user 2026-11-12; the Default until they win others at Hype Man).
function CelebrationService.forPlayer(player: Player, attempt: number?): string
	return PlayerDataService.getCelebration(player, attempt)
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
-- `cinematic`: the celebrating player's screen runs its camera shots, if it has any (State, CelebrationConfig
-- .CinematicMeetLevels; the admin's PLAY ON ME). Otherwise just the moves, sound and effects.
function CelebrationService.play(figure: Model?, id: string, _owner: Player?, cinematic: boolean?): number
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
	local loops = celebration.kind == "WalkLoop"
	track.Looped = loops
	track:Play(FADE_IN)
	playing[figure] = track
	looping[figure] = loops or nil
	local stopAt = if loops then LOOP_LIMIT_SECONDS else celebration.seconds - FADE_OUT
	task.delay(math.max(0, stopAt), function()
		if playing[figure] == track then
			playing[figure] = nil
			looping[figure] = nil
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
		remote:FireAllClients(id, Workspace:GetServerTimeNow(), figure, cinematic == true)
	end
	return if celebration.kind == "Walk" or loops then 0 else celebration.seconds
end

-- The walk back is over: a looping ("WalkLoop") celebration on this figure ends here; any other is left alone.
function CelebrationService.endWalk(figure: Model?)
	local track = figure and playing[figure]
	if figure and track and looping[figure] then
		playing[figure] = nil
		looping[figure] = nil
		track:Stop(0.4)
	end
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
