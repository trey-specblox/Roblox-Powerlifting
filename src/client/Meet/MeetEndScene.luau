--!strict
--[[
	MeetEndScene
	Client / Meet

	The camera side of THE END-OF-MEET COACH SCENE (GAME_DESIGN §40.5, user 2026-11-25; server MeetEndScene moves the
	coach): when the meet ends, your coach walks up beside you, pats your back and tells you how it went. On your screen
	only: the film look (MeetCinema: bars, other screens and bubbles hidden), ONE held two-shot of you and him from in
	front, gliding slowly in (user's cutscene notes: few shots, held, the line heard in full), his words as the subtitle,
	and SKIP. SKIP ends it here and tells the server ("MeetEndSkip": off the podium you are let go at once).

	Display only: it moves nothing but the camera (and, walking, your coach beside you). Remote: LocalMeetRemotes.SCENE
	kinds "MeetEndCoach" (start: where you stand, where he stands), "MeetEndCoachLine" (his words), "MeetEndWalk"
	(on the podium: you walk off together while he talks, a tracking shot), "MeetEndCut" (cut to the floor in front of
	the platforms, walking into the line for the podium), "MeetEndCoachEnd"; then for everyone in the hall "Ceremony",
	"CeremonyFocus", "CeremonyEnd" (MeetCeremony).
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

type Walk = { coach: Model, eye: Vector3?, started: number, seconds: number }
type Ceremony = { gold: CFrame, line: CFrame?, lifter: Model?, referee: Model?, eye: Vector3? }
type Scene = { started: number, eye0: Vector3, eye1: Vector3, look: Vector3, seconds: number, token: number, walk: Walk?,
	ceremony: Ceremony? }
local PIN_NAME = "MeetEndScenePin"
local MeetCoachLook = require(script.Parent:WaitForChild("MeetCoachLook"))

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

-- (Studio 2026-11-26: a "TITLE UNLOCKED" card slipped into the second between the coach scene and the ceremony's camera
-- and stayed over the ceremony) isPlaying holds on this long after a scene ends.
local HOLD_AFTER = 6
local holdUntil = 0

local function stop(skipped: boolean)
	local current = scene
	if current == nil then
		return
	end
	scene = nil
	holdUntil = if current.ceremony then 0 else os.clock() + HOLD_AFTER
	RunService:UnbindFromRenderStep(RENDER_NAME)
	RunService:UnbindFromRenderStep(PIN_NAME)
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
		MeetEndScene.render(camera)
	end)
end

-- One frame of whichever scene is on: the coach's two-shot, the walk to the podium or the ceremony.
function MeetEndScene.render(camera: Camera)
		local now = scene
		if now == nil then
			return
		end
		-- (Studio 2026-11-26: the meet's end hands the camera back 0.7 s in (MeetChalkShot/MeetLiftMoment restore it);
		-- the scene keeps it, or Roblox's camera and the Nationals hall's HallCameraGuard pull the shot about)
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		local t = os.clock() - now.started
		local ceremony = now.ceremony
		if ceremony then
			-- THE PODIUM CEREMONY (MeetCeremony): from the crowd's side, a little above, on whoever is being called up and
			-- the referee (the podium's middle before the first), eased.
			if t > now.seconds + 10 then
				stop(false)
				return
			end
			local crowd = ceremony.gold.LookVector
			local side = crowd:Cross(Vector3.yAxis)
			-- (before the first is called: the line waiting by the podium)
			local focus = if ceremony.line then ceremony.line.Position + Vector3.new(0, 3.2, 0)
				else ceremony.gold.Position + Vector3.new(0, -0.5, 0)
			local a = ceremony.lifter and ceremony.lifter:FindFirstChild("HumanoidRootPart")
			local b = ceremony.referee and ceremony.referee:FindFirstChild("HumanoidRootPart")
			if a and a:IsA("BasePart") then
				focus = if b and b:IsA("BasePart") then (a.Position + b.Position) / 2 else a.Position
				focus += Vector3.new(0, 1.2, 0)
			end
			local want = focus + crowd * 12 + side * 3.5 + Vector3.new(0, 2.2, 0)
			ceremony.eye = if ceremony.eye then ceremony.eye:Lerp(want, 0.08) else want
			local eye = ceremony.eye :: Vector3
			camera.CFrame = CFrame.lookAt(eye, focus) * MeetCinema.handheld(t)
			MeetCinema.focus((eye - focus).Magnitude)
			return
		end
		local walk = now.walk
		if walk then
			-- THE WALK TO THE PODIUM: one tracking shot from in front of them, a little to the coach's side, eased so the
			-- turn at the platform's front doesn't jerk.
			if os.clock() - walk.started > walk.seconds + 2 then
				stop(false)
				return
			end
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local coachRoot = walk.coach:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and coachRoot and coachRoot:IsA("BasePart") then
				-- (Studio 2026-11-25: 8.5 studs out and eased slowly, it trailed as they walked at it and cropped them at the
				-- waist: further out, higher, and it keeps up)
				local mid = (root.Position + coachRoot.Position) / 2 + Vector3.new(0, 1.8, 0)
				local ahead = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
				local right = ahead:Cross(Vector3.yAxis)
				-- (Studio 2026-11-26: straight in front, the lifter ahead of them in the line filled the shot) from in
				-- front and to the lifter's left (the coach is on their right), so whoever walks ahead is off to one side;
				-- pulled in where a wall or the barricade is in the way.
				local dir = (ahead * 0.78 - right * 0.62 + Vector3.new(0, 0.16, 0)).Unit
				local reach = SETTINGS.CameraDistance * 1.1
				local hitAt = blockedAt(mid, dir * (reach + WALL_MARGIN))
				local want = mid + dir * (if hitAt then math.max(4, hitAt - WALL_MARGIN) else reach)
				local jump = walk.eye and (walk.eye - want).Magnitude > 20
				walk.eye = if walk.eye and not jump then walk.eye:Lerp(want, 0.2) else want
				local eye = walk.eye :: Vector3
				camera.CFrame = CFrame.lookAt(eye, mid) * MeetCinema.handheld(t)
				MeetCinema.focus((eye - mid).Magnitude)
			end
			return
		end
		if t > now.seconds + 2 then
			stop(false) -- the server never said it ended: never strand the camera
			return
		end
		local u = math.clamp(t / now.seconds, 0, 1)
		u = u * u * (3 - 2 * u)
		local eye = now.eye0:Lerp(now.eye1, u)
		camera.CFrame = CFrame.lookAt(eye, now.look) * MeetCinema.handheld(t)
		MeetCinema.focus((eye - now.look).Magnitude)
end

--[[
	While walking to the podium, the coach is kept beside YOU every frame (the server walks him on a parallel way, which
	drifts round the corner): his root where his walking offset from your root says (WalkSide to your right, WalkBack
	behind, both facing your way), at his own standing height; and your chosen coach's copy with him (MeetCoachLook).
]]
local PIN_BLEND = 0.45 -- seconds from his pat stance (turned toward you) into walking beside you
local pinFrom: CFrame? = nil
local pinStarted = 0

function MeetEndScene.pinCoach(coach: Model)
	if coach:GetAttribute("WalkWithUserId") ~= Players.LocalPlayer.UserId then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local coachRoot = coach:FindFirstChild("HumanoidRootPart")
	local coachHumanoid = coach:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and coachRoot and coachRoot:IsA("BasePart") and coachHumanoid) then
		return
	end
	local side = tonumber(coach:GetAttribute("WalkSide")) or 3.6
	local back = tonumber(coach:GetAttribute("WalkBack")) or 0
	local floor = root.CFrame * CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0)
	local spot = floor * CFrame.new(side, 0, back)
	local want = spot + Vector3.new(0, coachHumanoid.HipHeight + coachRoot.Size.Y / 2, 0)
	-- (eased from where he stood for the pat, so he doesn't jump into step; not after the cut)
	if pinFrom == nil then
		pinFrom = coachRoot.CFrame
		pinStarted = os.clock()
	end
	local u = math.clamp((os.clock() - pinStarted) / PIN_BLEND, 0, 1)
	coachRoot.CFrame = if u < 1 then (pinFrom :: CFrame):Lerp(want, u * u * (3 - 2 * u)) else want
	MeetCoachLook.syncNow(coach)
end

-- Everyone in the hall: the podium ceremony's camera (bars, SKIP ends it here only), until "CeremonyEnd".
local function beginCeremony(data: any)
	if typeof(data.gold) ~= "CFrame" then
		return
	end
	stop(false)
	tokens += 1
	local current: Scene = { started = os.clock(), eye0 = Vector3.zero, eye1 = Vector3.zero, look = Vector3.zero,
		seconds = tonumber(data.seconds) or 40, token = tokens, walk = nil,
		ceremony = { gold = data.gold, line = if typeof(data.line) == "CFrame" then data.line else nil, lifter = nil,
			referee = nil, eye = nil } }
	scene = current
	MeetCinema.open()
	MeetCinema.skipButton(function()
		stop(false)
	end)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		MeetEndScene.render(camera)
	end)
end

-- True while one of these scenes is on this screen (RankMoment waits: no title cards over the ceremony).
function MeetEndScene.isPlaying(): boolean
	return scene ~= nil or os.clock() < holdUntil
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
		elseif data.kind == "MeetEndWalk" and scene and typeof(data.coach) == "Instance" and data.coach:IsA("Model") then
			-- (his line goes on while they walk: the subtitle stays)
			local current = scene :: Scene
			pinFrom = nil
			current.walk = { coach = data.coach, eye = Workspace.CurrentCamera.CFrame.Position, started = os.clock(),
				seconds = tonumber(data.seconds) or SETTINGS.MaxSeconds }
			-- (after MeetWalkView draws the walks this frame, before the camera)
			RunService:BindToRenderStep(PIN_NAME, Enum.RenderPriority.Camera.Value, function()
				MeetEndScene.pinCoach(data.coach)
			end)
		elseif data.kind == "MeetEndCut" and scene and scene.walk then
			-- A cut to the floor in front of the platforms: the camera jumps with them, the coach is already beside you.
			local walk = (scene :: Scene).walk :: Walk
			walk.eye = nil
			pinFrom = CFrame.new()
			pinStarted = -math.huge
		elseif data.kind == "MeetEndCoachEnd" then
			stop(false)
		elseif data.kind == "Ceremony" then
			beginCeremony(data)
		elseif data.kind == "CeremonyFocus" and scene and scene.ceremony then
			local c = (scene :: Scene).ceremony :: Ceremony
			c.lifter = if typeof(data.lifter) == "Instance" then data.lifter else nil
			c.referee = if typeof(data.referee) == "Instance" then data.referee else nil
		elseif data.kind == "CeremonyEnd" and scene and scene.ceremony then
			stop(false)
		end
	end)
	-- Leaving the meet mid-scene (or dying) never leaves the camera stuck.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		stop(false)
	end)
end

return MeetEndScene
