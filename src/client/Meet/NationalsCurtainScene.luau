--!strict
--[[
	NationalsCurtainScene
	Client / Meet

	The Nationals walk-out's cinematic, on the waiting lifter's own screen (GAME_DESIGN §39, user 2026-11-18: "for the
	'flow state' i was looking for more of a cinematic animation with camera angles and lighting ... the lifter can be
	waiting with the flow state animation then once the user clicks, they are seen using their arms and moving the
	curtain to enter the platform"; their reference: a performer seen from behind, facing a stage curtain under a top
	light).

	While they wait behind the curtain (the server's "Waiting" state carries `curtain`): the film look (MeetCinema: bars,
	soft background, every other screen away), the attempt and weight as the caption, "CLICK ANYWHERE TO STEP ONTO THE
	PLATFORM" in the bottom bar, a warm grade, a warm light from the split onto their face (the server's top light is over
	them, NationalsArenaVenue), and four shots in turn, each held and slowly drifting (the fwjelaa direction notes: each
	view shows something the last one didn't, all from the same side of the line from the lifter to the curtain):
		Wings    wide from behind and above, the lifter alone facing the dark curtain and its lit split (their reference)
		Profile  close beside them at head height: the rocking, the bowed head
		Face     low in front, between them and the curtain, looking up at the bowed face
		Low      on the floor behind them, past their legs to the light under the curtain: where they are going
	On the click (NationalsMeetUI sends READY) or when the server walks them out anyway (the Ready state): a hard cut to the
	STAGE SIDE, low, looking back at the curtain as their hands part it and they step through toward the camera into the
	light (the reverse is oriented by the curtain itself), for RevealSeconds; then the walk out's own camera
	(MeetLiftMoment) takes over.

	Display only: it decides and saves nothing. PERFORMANCE: one camera move a frame while it runs; one light and one
	colour grade, made and removed with it.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local NationalsConfig = require(ConfigFolder:WaitForChild("NationalsConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local MeetCinema = require(script.Parent:WaitForChild("MeetCinema"))
local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))

local NationalsCurtainScene = {}

local SETTINGS = NationalsConfig.CurtainScene
local RENDER_NAME = "NationalsCurtainScene"
local CLICK_TEXT = "CLICK ANYWHERE TO STEP ONTO THE PLATFORM"
local TAP_TEXT = "TAP ANYWHERE TO STEP ONTO THE PLATFORM"
local SHOTS = { "Wings", "Profile", "Face", "Low" }
-- A curtain's split farther than this from the lifter isn't theirs.
local SPLIT_NEAR = 14

type Scene = {
	split: Vector3,
	toStage: Vector3,
	right: Vector3,
	toCentre: Vector3,
	floorY: number,
	startedAt: number,
	shot: string?,
	revealAt: number?,
	revealEye: Vector3?,
	revealLook: Vector3?,
	made: { Instance },
}

local scene: Scene? = nil
local started = false

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

local function bodyOf(): (Model?, BasePart?)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return character, root
end

local function headOf(character: Model, root: BasePart): Vector3
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 2.2, 0)
end

-- The nearest curtain flap's split to the lifter: where it is, the stage's way, and the stage's middle.
local function findSplit(root: BasePart): (Vector3?, Vector3?, Vector3?)
	local best, bestDistance = nil, SPLIT_NEAR
	for _, flap in ipairs(CollectionService:GetTagged(NationalsConfig.CurtainFlapTag)) do
		local at = flap:GetAttribute("Split")
		if typeof(at) == "Vector3" then
			local distance = (Vector3.new(at.X, root.Position.Y, at.Z) - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = flap, distance
			end
		end
	end
	if best == nil then
		return nil, nil, nil
	end
	return best:GetAttribute("Split") :: Vector3, best:GetAttribute("TowardStage") :: Vector3,
		best:GetAttribute("StageCentre") :: Vector3?
end

local function stop(restore: boolean)
	local current = scene
	if current == nil then
		return
	end
	scene = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	for _, thing in ipairs(current.made) do
		thing:Destroy()
	end
	MeetCinema.curtainShot = false
	MeetCinema.close()
	if restore then
		local camera = Workspace.CurrentCamera
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- The waiting shots: (eye, look, field of view) for `shot` at `u` (0..1 through it).
local function waitingShot(current: Scene, shot: string, u: number, character: Model, root: BasePart): (Vector3, Vector3, number)
	local f, r, up = current.toStage, current.right, Vector3.yAxis
	local head = headOf(character, root)
	local floor = Vector3.new(root.Position.X, current.floorY, root.Position.Z)
	local split = Vector3.new(current.split.X, current.floorY, current.split.Z)
	if shot == "Wings" then
		-- Wide from behind and above, pushing in slowly: the lifter small against the tall curtain and its lit split,
		-- framed toward the backdrop's side so the curtain fills it (first test: its outer end and the stands showed).
		-- From the curtain's outer side, looking across it toward the backdrop, and no further back than the coach and
		-- the chalk stand: straight on, the frame ran past the curtain's outer end into the stands; 11 back, the coach
		-- filled half of it (Studio tests 2026-11-18). Every shot stays on this outer side of the lifter.
		local c = current.toCentre
		local eye = floor - f * (7 - 1.4 * u) - c * 2.5 + up * 5.8
		return eye, split + c * 3 + up * 4, SETTINGS.FieldOfView - 6
	elseif shot == "Profile" then
		local c = current.toCentre
		local eye = head - c * 4 - f * (0.6 - 0.7 * u) - up * 0.3
		return eye, head + f * 0.6 - up * 0.35, SETTINGS.FieldOfView
	elseif shot == "Face" then
		-- Low in front of them, the curtain behind the camera, looking up at the bowed face.
		-- (second test: 2.6 away the head filled the whole frame; now head and shoulders)
		local eye = head + f * 3.3 - up * 1.1 + r * (0.2 + 0.4 * u)
		return eye, head - up * 0.35, SETTINGS.FieldOfView
	end
	-- Low: on the floor behind them, past their legs to the light under the curtain.
	local c = current.toCentre
	local eye = floor - f * (3.5 - 0.6 * u) - c * 1.5 + up * 0.7
	return eye, split + c * 2.5 + up * 2.2, SETTINGS.FieldOfView + 6
end

local function step()
	local current = scene
	if current == nil then
		return
	end
	local character, root = bodyOf()
	if character == nil or root == nil then
		stop(true)
		return
	end
	local camera = Workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local now = os.clock()
	local eye: Vector3
	local look: Vector3
	local fieldOfView: number
	local cut = false
	local revealAt = current.revealAt
	if revealAt then
		local t = now - revealAt
		if t >= SETTINGS.RevealSeconds then
			-- The walk out's camera (MeetLiftMoment) carries on from here.
			stop(false)
			return
		end
		local from, at = current.revealEye :: Vector3, current.revealLook :: Vector3
		eye = from:Lerp(at, 0.14 * t / SETTINGS.RevealSeconds)
		look = at
		fieldOfView = SETTINGS.FieldOfView
		cut = current.shot ~= "Reveal"
		current.shot = "Reveal"
	else
		local elapsed = now - current.startedAt
		local index = math.floor(elapsed / SETTINGS.ShotSeconds)
		local shot = SHOTS[index % #SHOTS + 1]
		local u = (elapsed % SETTINGS.ShotSeconds) / SETTINGS.ShotSeconds
		eye, look, fieldOfView = waitingShot(current, shot, u, character, root)
		cut = shot ~= current.shot
		current.shot = shot
	end
	camera.FieldOfView = fieldOfView
	local target = CFrame.lookAt(eye, look) * MeetCinema.handheld(now)
	MeetCinema.focus((eye - headOf(character, root)).Magnitude)
	-- Hard cuts between shots; within one, a slow drift.
	camera.CFrame = if cut then target else camera.CFrame:Lerp(target, 0.25)
end

local function begin(state: any)
	if scene then
		return
	end
	local character, root = bodyOf()
	if character == nil or root == nil then
		return
	end
	local split, toStage, centre = findSplit(root)
	if split == nil or toStage == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local floorY = root.Position.Y - root.Size.Y / 2 - (if humanoid then humanoid.HipHeight else 2)
	local flat = Vector3.new(toStage.X, 0, toStage.Z).Unit
	local right = flat:Cross(Vector3.yAxis)
	local toCentre = right
	if centre then
		local side = (centre - split):Dot(right)
		toCentre = if side >= 0 then right else -right
	end
	local made: { Instance } = {}
	local function lamp(name: string, from: Vector3, to: Vector3, colour: Color3, brightness: number, range: number,
		angle: number)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.CFrame = CFrame.lookAt(from, to)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Color = colour
		light.Brightness = brightness
		light.Range = range
		light.Angle = angle
		light.Shadows = false
		light.Parent = part
		part.Parent = Workspace
		table.insert(made, part)
	end
	local warm = Color3.fromRGB(255, 218, 170)
	local floorAt = Vector3.new(split.X, floorY, split.Z)
	-- (First test: with only the wings' top light the whole shot was a black silhouette on a black curtain.)
	-- The key: warm, from the split onto their face, like the stage's light leaking round the cloth.
	lamp("CurtainSceneKey", floorAt + Vector3.yAxis * 6 - flat * 1.4, headOf(character, root), warm, 5, 14, 60)
	-- Two pools of light on the curtain's back, as in the user's reference (a performer before a lit stage curtain).
	for _, sideways in ipairs({ -2.6, 2.6 }) do
		local onCloth = floorAt + right * sideways + Vector3.yAxis * 4.5 - flat * 0.6
		-- (Studio tests: 7 from 12 away hardly showed on the cloth, 40 blew it out; 22 from 7 away, 26 degrees, lit the
		--  folds like the user's reference)
		lamp("CurtainScenePool", onCloth - flat * 4 + Vector3.yAxis * 6, onCloth, warm, 22, 16, 26)
	end
	-- A cool fill from behind them, so their back and shoulders read against the dark.
	lamp("CurtainSceneFill", Vector3.new(root.Position.X, floorY, root.Position.Z) - flat * 5 + Vector3.yAxis * 6,
		headOf(character, root), Color3.fromRGB(150, 175, 255), 4, 14, 70)
	-- (Studio test: lights made this frame stayed dark until something moved them; moved a hair, they light.)
	for _, delay in ipairs({ 0.1, 0.6 }) do
		task.delay(delay, function()
			for _, thing in ipairs(made) do
				if thing:IsA("BasePart") and thing.Parent then
					thing.CFrame = thing.CFrame * CFrame.new(0, 0, if delay < 0.5 then -0.01 else 0.01)
				end
			end
		end)
	end
	-- A warm grade while it runs (gentle: the hall is already a dark room).
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "CurtainSceneGrade"
	grade.TintColor = Color3.fromRGB(255, 242, 230)
	grade.Contrast = 0.08
	grade.Brightness = 0.04
	grade.Saturation = -0.05
	grade.Parent = Lighting
	table.insert(made, grade)

	scene = { split = split, toStage = flat, right = right, toCentre = toCentre, floorY = floorY, startedAt = os.clock(),
		shot = nil, revealAt = nil, revealEye = nil, revealLook = nil, made = made }
	MeetCinema.open()
	MeetCinema.curtainShot = true
	local lift = if typeof(state.lift) == "string" then string.upper(state.lift) else ""
	local attempt = if typeof(state.attemptNumber) == "number" then state.attemptNumber else 1
	MeetCinema.caption(string.format("%s  ·  ATTEMPT %d", lift, attempt),
		if typeof(state.declaredKg) == "number" then kgText(state.declaredKg) .. " KG" else "")
	MeetCinema.line(if UIStyle.isTouchOnly() then TAP_TEXT else CLICK_TEXT)
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
end

-- They step out: the cut to the stage side, the curtain parting toward the camera.
local function reveal()
	local current = scene
	if current == nil or current.revealAt then
		return
	end
	local f, up = current.toStage, Vector3.yAxis
	local split = Vector3.new(current.split.X, current.floorY, current.split.Z)
	current.revealAt = os.clock()
	-- (Ahead of them on the walkway behind the stage, just off their line: they come through the curtain, turn and walk
	-- toward the camera and past it, 3 studs to its side, to the steps at the middle of the stage's back edge. First test,
	-- straight in front, they walked right through the camera.)
	current.revealEye = split + current.toCentre * 11 + f * 6 + up * 3
	current.revealLook = split + f * 1.5 + up * 3.7
	MeetCinema.line(nil)
end

function NationalsCurtainScene.start()
	if started then
		return
	end
	started = true
	local remotes = LocalMeetRemotes.waitForClient(ReplicatedStorage)
	remotes.state.OnClientEvent:Connect(function(state: any)
		if typeof(state) ~= "table" then
			return
		end
		if state.phase == "Waiting" and typeof(state.curtain) == "table" then
			begin(state)
		elseif scene then
			if state.phase == "Ready" then
				-- (Walked out without a click: the server's wait ran out.)
				reveal()
			elseif not (scene :: Scene).revealAt then
				stop(true)
			end
		end
	end)
	-- The click or tap that sends READY (NationalsMeetUI) starts the reveal at once.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local current = scene
		if current and not current.revealAt and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA) then
			reveal()
		end
	end)
	-- Out of the meet: everything back.
	Players.LocalPlayer:GetAttributeChangedSignal(LocalMeetConfig.PlatformAttribute):Connect(function()
		if Players.LocalPlayer:GetAttribute(LocalMeetConfig.PlatformAttribute) == nil then
			stop(true)
		end
	end)
end

return NationalsCurtainScene
