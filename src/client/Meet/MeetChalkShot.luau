--!strict
--[[
	MeetChalkShot
	Client / Meet

	While the lifter chooses a weight at a Local meet they stand at the chalk stand
	chalking up (GAME_DESIGN §37.5, user 2026-11-06: "a clean animation where the
	lifter is seen putting on the chalk while waiting for attempt selection"). The
	server plays the animations (MeetChalk); on the lifter's own screen, this:
		- holds the camera side-on to the lifter, the stand and the coach, with them in
		  the clear part of the screen beside the choose panel (not while the coach's
		  ritual has it, State and up: MeetRitualShot)
		- puts a puff of chalk on each clap and slap, and plays their sounds

	Display only: it decides and saves nothing.

	PERFORMANCE: each frame while choosing, one camera move and one look at the
	playing animations. Two particle emitters, emitting only on a clap or slap, on
	this player's screen only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local MockMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("MockMeetRemotes"))

local MeetCinema = require(script.Parent:WaitForChild("MeetCinema"))
local MeetLiftMoment = require(script.Parent:WaitForChild("MeetLiftMoment"))
local MeetSoundController = require(script.Parent:WaitForChild("MeetSoundController"))

local MeetChalkShot = {}

local SETTINGS = LocalMeetConfig.Chalk
local RENDER_NAME = "MeetChalkShot"
local PANEL_GUI, PANEL_NAME = "LocalMeet", "Action"

-- A moment in an animation's loop: a sound, and a puff of chalk or not.
type Moment = { at: number, sound: string, puff: boolean }
local LIFTER_MOMENTS: { Moment } = {
	{ at = SETTINGS.RubAt[1], sound = "ChalkRub", puff = false },
	{ at = SETTINGS.RubAt[2], sound = "ChalkRub", puff = false },
	{ at = SETTINGS.ClapAt[1], sound = "ChalkClap", puff = true },
	{ at = SETTINGS.ClapAt[2], sound = "ChalkClap", puff = true },
}
local COACH_MOMENTS: { Moment } = {
	{ at = SETTINGS.SlapAt[1], sound = "BackSlap", puff = true },
	{ at = SETTINGS.SlapAt[2], sound = "BackSlap", puff = true },
}

-- One figure's animation being followed: when its loop passes a moment, that moment happens.
type Follower = {
	figure: Model,
	id: string,
	moments: { Moment },
	lastTime: number,
	emitter: ParticleEmitter?,
	attachment: Attachment?,
}

type Run = { chalk: MockMeetRemotes.ChalkView, lifter: Follower?, coach: Follower? }
local run: Run? = nil

local function makeFollower(figure: Model?, id: string, moments: { Moment }, handName: string): Follower?
	if figure == nil then
		return nil
	end
	local hand = figure:FindFirstChild(handName)
	local attachment: Attachment? = nil
	local emitter: ParticleEmitter? = nil
	if hand and hand:IsA("BasePart") then
		local made = Instance.new("Attachment")
		made.Name = "ChalkPuff"
		made.Parent = hand
		attachment = made
		local puff = Instance.new("ParticleEmitter")
		puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
		puff.Color = ColorSequence.new(Color3.fromRGB(245, 245, 240))
		puff.Enabled = false
		puff.LightInfluence = 0.3
		puff.Lifetime = NumberRange.new(0.5, 0.9)
		puff.Rate = 0
		puff.Speed = NumberRange.new(1.5, 3)
		puff.SpreadAngle = Vector2.new(180, 180)
		puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.3) })
		puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		puff.Parent = made
		emitter = puff
	end
	return { figure = figure, id = id, moments = moments, lastTime = 0, emitter = emitter, attachment = attachment }
end

local function follow(follower: Follower?)
	if follower == nil or not follower.figure.Parent then
		return
	end
	local humanoid = follower.figure:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local animation = track.Animation
		if animation and animation.AnimationId == follower.id then
			local now = track.TimePosition
			local last = follower.lastTime
			follower.lastTime = now
			for _, moment in ipairs(follower.moments) do
				-- Passed since the last frame; a loop that came round passes what lies past its end, or before now.
				local passed = if now >= last then last < moment.at and moment.at <= now else moment.at > last or moment.at <= now
				if passed then
					local attachment = follower.attachment
					if attachment then
						MeetSoundController.playAt(moment.sound, attachment.WorldPosition)
					end
					if moment.puff and follower.emitter then
						follower.emitter:Emit(SETTINGS.PuffParticles)
					end
				end
			end
			return
		end
	end
end

-- How wide the clear part of the screen is, beside the docked choose panel.
local function clearWidth(viewport: Vector2): number
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local screen = gui and gui:FindFirstChild(PANEL_GUI)
	local panel = screen and screen:FindFirstChild(PANEL_NAME)
	if panel and panel:IsA("GuiObject") and panel.Visible and panel.AnchorPoint.X > 0.9 then
		return math.clamp(panel.AbsolutePosition.X, viewport.X * 0.3, viewport.X)
	end
	return viewport.X
end

local function step(dt: number)
	local current = run
	if current == nil then
		return
	end
	follow(current.lifter)
	follow(current.coach)
	-- The coach's ritual has the camera (State and up, MeetRitualShot): only the puffs and sounds here.
	if MeetCinema.ritualCamera then
		return
	end
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local shot = SETTINGS.Shot
	local out = current.chalk.out
	local right = (-out):Cross(Vector3.yAxis)
	-- Moved sideways, not turned, so the group sits in the clear part of the screen, clear of the standings on its left.
	local halfWidth = shot.Back * math.tan(math.rad(camera.FieldOfView / 2)) * viewport.X / viewport.Y
	local clearCentre = clearWidth(viewport) * shot.ClearShare / viewport.X
	local side = right * (0.5 - clearCentre) * 2 * halfWidth
	local look = current.chalk.at + side
	local eye = look + out * shot.Back + Vector3.new(0, shot.Up, 0)
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, look), 1 - math.exp(-shot.Rate * dt))
end

local function clearFollower(follower: Follower?)
	if follower and follower.attachment then
		follower.attachment:Destroy()
	end
end

-- The camera goes back on the player when `restore` (false: the lift's own shot takes it straight over).
function MeetChalkShot.stop(restore: boolean)
	local current = run
	if current == nil then
		return
	end
	run = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	clearFollower(current.lifter)
	clearFollower(current.coach)
	if restore then
		local camera = Workspace.CurrentCamera
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- Every state of the meet the player is lifting in (LocalMeetController).
function MeetChalkShot.onState(state: MockMeetRemotes.MeetState)
	local chalk = state.chalk
	if chalk == nil then
		MeetChalkShot.stop(state.phase ~= "Ready")
		return
	end
	if run then
		run.chalk = chalk
		return
	end
	-- Anything left of the last lift's camera ends now.
	MeetLiftMoment.stop(false)
	run = {
		chalk = chalk,
		lifter = makeFollower(Players.LocalPlayer.Character, SETTINGS.LifterAnimationId, LIFTER_MOMENTS, "LeftHand"),
		coach = makeFollower(chalk.coach, SETTINGS.CoachBackAnimationId, COACH_MOMENTS, "RightHand"),
	}
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
end

return MeetChalkShot
