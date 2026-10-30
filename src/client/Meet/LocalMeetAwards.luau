--!strict
--[[
	LocalMeetAwards
	Client / Meet

	The Local meet's awards ceremony on this player's screen (GAME_DESIGN.md
	§29.10 "Venue redesign and awards ceremony", user 2026-10-29: "when the user
	wins the meet they can have the camera pointing towards them on the podium",
	with theme songs and celebrations). When the server says it has started
	(LocalMeetRemotes.AWARDS), for everyone in the venue:
		- the camera shows the whole awards stage, glides in close on the winner,
		  then back out to the stage (LocalMeetConfig.Awards)
		- the crowd cheers and the winner's theme song plays
		- if THIS player won, their character does the winner's celebration
	The camera goes back to normal when the ceremony ends or the player leaves
	the venue. Display only: it decides and saves nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local LocalMeetAwards = {}

local SETTINGS = LocalMeetConfig.Awards
-- How high over the podium's top the shots look: about a standing winner's chest, and their face.
local CHEST_HEIGHT = 3
local FACE_HEIGHT = 4.4

-- Everything the running ceremony made, so stop() can undo it; `id` makes an older ceremony's timers do nothing.
local current: {
	id: number,
	sounds: { Sound },
	track: AnimationTrack?,
	tween: Tween?,
	leaving: RBXScriptConnection?,
}? = nil
local nextId = 0

-- A shot standing `distance` out from `target` along `facing` and `height` above it, looking at the target.
local function shot(target: Vector3, facing: Vector3, distance: number, height: number): CFrame
	local eye = target + facing * distance + Vector3.new(0, height, 0)
	return CFrame.lookAt(eye, target)
end

local function playSound(id: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = "AwardsSound"
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	return sound
end

-- Ends the ceremony on this screen: the camera back on the player, the music and celebration stopped.
function LocalMeetAwards.stop()
	local ceremony = current
	if ceremony == nil then
		return
	end
	current = nil
	if ceremony.tween then
		ceremony.tween:Cancel()
	end
	for _, sound in ipairs(ceremony.sounds) do
		sound:Destroy()
	end
	if ceremony.track then
		ceremony.track:Stop(0.3)
	end
	if ceremony.leaving then
		ceremony.leaving:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.CameraType = Enum.CameraType.Custom
end

-- Starts the ceremony on this screen (the server's LocalMeetRemotes.AWARDS).
function LocalMeetAwards.play(moment: LocalMeetRemotes.AwardsMoment)
	LocalMeetAwards.stop()
	local player = Players.LocalPlayer
	if player:GetAttribute(LocalMeetConfig.VenueAttribute) == nil then
		return
	end
	nextId += 1
	local id = nextId
	local ceremony = { id = id, sounds = {} :: { Sound }, track = nil :: AnimationTrack?, tween = nil :: Tween?,
		leaving = nil :: RBXScriptConnection? }
	current = ceremony
	local function stillRunning(): boolean
		return current ~= nil and current.id == id
	end
	-- Leaving the venue (EXIT, dying) ends it at once.
	ceremony.leaving = player:GetAttributeChangedSignal(LocalMeetConfig.VenueAttribute):Connect(function()
		if player:GetAttribute(LocalMeetConfig.VenueAttribute) == nil and stillRunning() then
			LocalMeetAwards.stop()
		end
	end)

	local camera = Workspace.CurrentCamera
	local flat = Vector3.new(moment.stageFacing.X, 0, moment.stageFacing.Z)
	local facing = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local stage = moment.stageCentre + Vector3.new(0, CHEST_HEIGHT, 0)
	local wide = shot(stage, facing, SETTINGS.WideShotDistance, 4)
	local function glide(to: CFrame, seconds: number)
		if not stillRunning() then
			return
		end
		if ceremony.tween then
			ceremony.tween:Cancel()
		end
		local tween = TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = to })
		ceremony.tween = tween
		tween:Play()
	end

	-- The opening: from further back and higher, drifting in to the wide shot of the whole stage.
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = shot(stage, facing, SETTINGS.WideShotDistance + 12, 9)
	glide(wide, SETTINGS.WideShotSeconds)

	table.insert(ceremony.sounds, playSound(SETTINGS.CrowdCheerSoundId, SETTINGS.CheerVolume))
	local themeId = moment.themeSoundId
	if themeId then
		table.insert(ceremony.sounds, playSound(themeId, SETTINGS.ThemeVolume))
	end

	-- The winner's celebration, played by the winner's own client (so everyone sees it).
	local animationId = moment.celebrationAnimationId
	if animationId and moment.winnerUserId == player.UserId then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = animationId
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Action
				track:Play(0.2)
				ceremony.track = track
			end
		end
	end

	-- The close-up on the winner's face (their head if it is here, else above the gold top), then back out.
	local spot = moment.winnerSpot
	if spot then
		task.delay(SETTINGS.WideShotSeconds, function()
			local face = spot.Position + Vector3.new(0, FACE_HEIGHT, 0)
			local winner = moment.winnerUserId and Players:GetPlayerByUserId(moment.winnerUserId)
			local head = winner and winner.Character and winner.Character:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				face = head.Position
			end
			glide(shot(face, facing, SETTINGS.CloseUpDistance, -0.6), SETTINGS.GlideSeconds)
		end)
		task.delay(SETTINGS.WideShotSeconds + SETTINGS.CloseUpSeconds, function()
			glide(wide, SETTINGS.GlideSeconds * 1.5)
		end)
	end
	task.delay(moment.seconds, function()
		if stillRunning() then
			LocalMeetAwards.stop()
		end
	end)
end

return LocalMeetAwards
