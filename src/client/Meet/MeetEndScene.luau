--!strict
--[[
	MeetEndScene
	Client / Meet

	The camera side of THE END-OF-MEET COACH SCENE (GAME_DESIGN §40.5, user 2026-11-25; server MeetEndScene moves the
	coach): when the meet ends, your coach walks up beside you, pats your back and tells you how it went. On your screen
	only: the film look (MeetCinema: bars, other screens and bubbles hidden), ONE held two-shot of you and him from in
	front, gliding slowly in (user's cutscene notes: few shots, held, the line heard in full), his words as the subtitle,
	and SKIP. SKIP ends it here and tells the server ("MeetEndSkip": off the podium you are let go at once).

	Display only: it moves nothing but the camera. Remote: LocalMeetRemotes.SCENE kinds "MeetEndCoach" (start: where
	you stand, where he'll stand), "MeetEndCoachLine" (his words), "MeetEndCoachEnd".
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))
local MeetCinema = require(script.Parent:WaitForChild("MeetCinema"))

local SETTINGS = LocalMeetConfig.MeetEnd
local RENDER_NAME = "MeetEndSceneCamera"
local FREEZE_ACTION = "MeetEndSceneFreeze"
local WALL_MARGIN = 0.6 -- studs kept in front of a wall between the camera and the pair

type Scene = { started: number, eye0: Vector3, eye1: Vector3, look: Vector3, seconds: number, token: number }

local MeetEndScene = {}

local started = false
local remotes: LocalMeetRemotes.RemoteSet? = nil
local scene: Scene? = nil
local tokens = 0

local function setControls(on: boolean)
	pcall(function()
		local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module and module:IsA("ModuleScript") then
			local controls = (require(module) :: any):GetControls()
			if on then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
end

local function stop(skipped: boolean)
	local current = scene
	if current == nil then
		return
	end
	scene = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	ContextActionService:UnbindAction(FREEZE_ACTION)
	setControls(true)
	MeetCinema.subtitle(nil)
	MeetCinema.skipButton(nil)
	MeetCinema.close()
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.CameraType = Enum.CameraType.Custom
	if skipped and remotes then
		remotes.scene:FireServer("MeetEndSkip")
	end
end

-- The first solid thing (not a body: people never block the shot, they ARE the shot) from `from` along `along`.
local function blockedAt(from: Vector3, along: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, along, params)
		if hit == nil then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local body = model and model:FindFirstChildOfClass("Humanoid")
		if body or hit.Instance.Transparency >= 0.95 or not hit.Instance.CanQuery then
			table.insert(ignore, if body then model :: Model else hit.Instance)
		else
			return hit.Distance
		end
	end
	return nil
end

--[[
	The camera's spot (Studio 2026-11-25: the waiting spot is right by a wall and the chalk stand, so the one fixed angle
	got pulled in until the heads were cut off, and the chalk bowl stood in front): try angles round the pair, from in
	front on the coach's side first, keep the one with the most clear room (a wall or the bowl between the camera and
	either of them rules an angle out), at most CameraDistance away.
]]
local ANGLES = { 25, 0, 50, -25, 75, -50, 105, -80, 140, -120, 180 } -- degrees from straight in front, + to the coach's side
local MIN_CLEAR = 5.5

local function chooseEye(look: Vector3, forward: Vector3, heads: { Vector3 }): Vector3
	local best: Vector3? = nil
	local bestScore = -math.huge
	for index, degrees in ipairs(ANGLES) do
		local turn = CFrame.Angles(0, -math.rad(degrees), 0) -- (+ turns toward the lifter's right: the coach's side)
		local dir = (turn:VectorToWorldSpace(forward) + Vector3.new(0, 0.12, 0)).Unit
		local want = SETTINGS.CameraDistance
		local hitAt = blockedAt(look, dir * (want + WALL_MARGIN))
		local room = if hitAt then hitAt - WALL_MARGIN else want
		local eye = look + dir * math.max(1, room)
		local seen = true
		for _, head in ipairs(heads) do
			if blockedAt(eye, head - eye) then
				seen = false
			end
		end
		local score = math.min(room, want) - index * 0.15 - (if seen then 0 else 100)
		if room < MIN_CLEAR then
			score -= 50
		end
		if score > bestScore then
			bestScore, best = score, eye
		end
	end
	return best or (look + forward * SETTINGS.CameraDistance)
end

local function begin(data: any)
	if typeof(data.lifterAt) ~= "CFrame" or typeof(data.coachAt) ~= "CFrame" then
		return
	end
	stop(false)
	tokens += 1
	local lifterAt: CFrame, coachAt: CFrame = data.lifterAt, data.coachAt
	local look = (lifterAt.Position + coachAt.Position) / 2 + Vector3.new(0, SETTINGS.CameraHeight, 0)
	local forward = Vector3.new(lifterAt.LookVector.X, 0, lifterAt.LookVector.Z).Unit
	local up = Vector3.new(0, SETTINGS.HeadHeight, 0)
	local eye0 = chooseEye(look, forward, { lifterAt.Position + up, coachAt.Position + up })
	local eye1 = look + (eye0 - look) * math.max(0.5, 1 - SETTINGS.CameraGlide / math.max(1, (eye0 - look).Magnitude))
	local current: Scene = { started = os.clock(), eye0 = eye0, eye1 = eye1, look = look,
		seconds = tonumber(data.seconds) or SETTINGS.MaxSeconds, token = tokens }
	scene = current
	MeetCinema.open()
	MeetCinema.skipButton(function()
		stop(true)
	end)
	-- You stay put while the camera is away (the server holds you there anyway).
	ContextActionService:BindActionAtPriority(FREEZE_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(Enum.PlayerActions:GetEnumItems()))
	setControls(false)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(eye0, look)
	MeetCinema.focus((eye0 - look).Magnitude)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local now = scene
		if now == nil then
			return
		end
		local t = os.clock() - now.started
		if t > now.seconds + 2 then
			stop(false) -- the server never said it ended: never strand the camera
			return
		end
		local u = math.clamp(t / now.seconds, 0, 1)
		u = u * u * (3 - 2 * u)
		local eye = now.eye0:Lerp(now.eye1, u)
		camera.CFrame = CFrame.lookAt(eye, now.look) * MeetCinema.handheld(t)
		MeetCinema.focus((eye - now.look).Magnitude)
	end)
end

function MeetEndScene.start()
	if started then
		return
	end
	started = true
	local set = LocalMeetRemotes.waitForClient(ReplicatedStorage)
	remotes = set
	set.scene.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if data.kind == "MeetEndCoach" then
			begin(data)
		elseif data.kind == "MeetEndCoachLine" and scene and typeof(data.line) == "string" then
			MeetCinema.subtitle(data.line)
		elseif data.kind == "MeetEndCoachEnd" then
			stop(false)
		end
	end)
	-- Leaving the meet mid-scene (or dying) never leaves the camera stuck.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		stop(false)
	end)
end

return MeetEndScene
