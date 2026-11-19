--!strict
--[[
	NationalsLiftOffScene
	Client / Meet

	The lift-off's judge, as a cinematic on each tied lifter's own screen (GAME_DESIGN §39, user 2026-11-18: "both lifters
	(tied for first) are put in a cinematic where the judge walks through the curtain, to tell both lifters together that
	they must lift off"; then, after seeing it: "i see both people just get up then wait at the curtain. Make it where the
	ref comes through, looks at the two lifters, then they go to him, then he says what he has to say"). The server moves
	the real figures in the hall (NationalsScenes) and sends this screen the moments (LocalMeetRemotes.SCENE: "LiftOff"
	when it starts, "LiftOffLines" once the lifters stand in front of the judge); this only runs the film look
	(MeetCinema), the camera, a few lights, and the judge's words: in the bottom bar and aloud.

	The shots (the fwjelaa direction notes: each view shows something the last one didn't):
		Tie      the tied lifters where they sit on their bench, from in front: who this is about, the place they are tied for
		Chair    the stage's front: the head judge, up off the chair with the score sheet, sets off along the stage
		Side     ahead of the judge down the stage's side, coming toward the camera on the way to the curtain
		Through  in the lifters' zone: the curtain parts, the judge steps through, stops and looks over at the lifters
		Look     beside the judge: the lifters get up off the bench and walk over to stand in front of the judge, who turns
		         with them
		Tell     from behind and above the lifters, between their shoulders: the judge tells them (the words are the news)
		Verdict  past the judge's shoulder onto the lifters' faces, for what is at stake (their faces are the news)
	Then the film look ends, the camera goes back on the player and the server shows the pick.

	Display only: it decides and saves nothing. PERFORMANCE: one camera move a frame while it runs; six lights and a
	colour grade, made and removed with it; the judge's two lines as sounds, on this screen only.
]]

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local NationalsConfig = require(ConfigFolder:WaitForChild("NationalsConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local LocalMeetRemotes = require(MeetFolder:WaitForChild("LocalMeetRemotes"))
local MeetWalkPath = require(MeetFolder:WaitForChild("MeetWalkPath"))

local MeetCinema = require(script.Parent:WaitForChild("MeetCinema"))

local NationalsLiftOffScene = {}

local SETTINGS = NationalsConfig.LiftOffScene
local RENDER_NAME = "NationalsLiftOffScene"
local FREEZE_ACTION = "NationalsLiftOffFreeze"
-- The local player's attribute naming the shot on screen while a Nationals cinematic runs (nil otherwise).
local SHOT_ATTRIBUTE = "NationalsSceneShot"
-- The Chair shot starts this long before the judge sets off (the turn away from the chair is in it).
local CHAIR_LEAD_SECONDS = 0.3
-- The Look shot starts this long after the judge has stopped (the look itself is seen from the Through shot first).
local LOOK_AFTER_SECONDS = 0.5
-- The camera goes to the Tell shot this long before the judge's first word.
local TELL_LEAD_SECONDS = 0.35
-- A standing figure's head above the floor, when the figure itself can't be read.
local HEAD_UP = 4.9
-- If the judge's words never come (the server's scene was cut short), the film look ends this long after the judge stopped.
local GIVE_UP_SECONDS = 40

type Line = { at: number, seconds: number, who: string, text: string, voiceId: string }
type Scene = {
	t0: number,
	tWalk: number,
	tSide: number,
	tThrough: number,
	tArrive: number,
	-- Once the lifters stand in front of the judge (the "LiftOffLines" message): when the words start and all is over.
	tTell: number?,
	tEnd: number,
	judge: Model?,
	lifters: { number },
	-- How many lifters stand side by side.
	count: number,
	lines: { Line },
	chair: Vector3,
	way: { Vector3 },
	judgeAt: Vector3,
	-- Where the lifters come to stand (the floor point between them), and where they were on their bench at the start.
	centre: Vector3,
	benchAt: Vector3,
	spread: number,
	-- How far along the line from its middle the nearest gap between two lifters is (the Tell shot looks through it).
	between: number,
	toStage: Vector3,
	outer: Vector3,
	-- The judge's walk, worked out as the server does: where the judge is at any moment, whatever has loaded.
	path: MeetWalkPath.Path,
	shot: string?,
	said: number,
	made: { Instance },
	voices: { [string]: Sound },
	followLamp: BasePart?,
	-- The world's floating tags hidden meanwhile (the callers').
	tags: { BillboardGui },
}

local scene: Scene? = nil
local started = false

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function placeWord(place: number): string
	return if place == 1 then "1ST" elseif place == 2 then "2ND" else "3RD"
end

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

-- The player's own movement controls on or off (keys, thumbstick and gamepad: Roblox's control module).
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

local function stop(restore: boolean)
	local current = scene
	if current == nil then
		return
	end
	scene = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	ContextActionService:UnbindAction(FREEZE_ACTION)
	setControls(true)
	for _, thing in ipairs(current.made) do
		thing:Destroy()
	end
	for _, sound in pairs(current.voices) do
		sound:Destroy()
	end
	for _, tag in ipairs(current.tags) do
		if tag.Parent then
			tag.Enabled = true
		end
	end
	MeetCinema.says("", nil)
	MeetCinema.close()
	Players.LocalPlayer:SetAttribute(SHOT_ATTRIBUTE, nil)
	if restore then
		local camera = Workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- Where the judge's feet and head are now.
local function judgeNow(current: Scene, now: number): (Vector3, Vector3)
	local floor: Vector3
	if now <= current.tWalk then
		floor = current.chair
	else
		local frame = MeetWalkPath.at(current.path, now - current.tWalk)
		floor = frame.Position
	end
	local judge = current.judge
	local head = judge and judge:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		-- (the figure itself, once it is moving: exactly where this screen draws it)
		local root = (judge :: Model):FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and now > current.tWalk then
			floor = Vector3.new(root.Position.X, floor.Y, root.Position.Z)
		end
		return floor, head.Position
	end
	return floor, floor + Vector3.new(0, HEAD_UP, 0)
end

-- The tied lifters as this screen has them now: the point between their heads, and how far the furthest is from it.
local function liftersNow(current: Scene): (Vector3, number)
	local heads: { Vector3 } = {}
	for _, userId in ipairs(current.lifters) do
		local player = Players:GetPlayerByUserId(userId)
		local head = player and player.Character and player.Character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			table.insert(heads, head.Position)
		end
	end
	if #heads == 0 then
		return current.benchAt + Vector3.new(0, 3.6, 0), 0
	end
	local middle = Vector3.zero
	for _, at in ipairs(heads) do
		middle += at / #heads
	end
	local half = 0
	for _, at in ipairs(heads) do
		half = math.max(half, (at - middle).Magnitude)
	end
	return middle, half
end

-- The standing lifters' heads' height above the floor (the local player's own, who is one of them).
local function liftersHeadUp(current: Scene): number
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return math.clamp(head.Position.Y - current.centre.Y, 3.5, 7)
	end
	return HEAD_UP
end

-- (eye, look, field of view, how far the sharp subject is) for `shot` at `u` (0..1 through it).
local function frameOf(current: Scene, shot: string, u: number, now: number): (Vector3, Vector3, number, number)
	local f, o, up = current.toStage, current.outer, Vector3.yAxis
	local centre = current.centre
	local judgeFloor, judgeHead = judgeNow(current, now)
	local wide = current.spread
	if shot == "Tie" then
		-- In front of them where they sit (between the bench and the curtain), a little to one side, pushing in; wider
		-- when they sit far apart.
		local middle, half = liftersNow(current)
		local viewport = Workspace.CurrentCamera.ViewportSize
		local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 1.78
		local distance = 6.6
		local need = math.deg(2 * math.atan((half + 2.6) / distance / aspect))
		local eye = middle + f * (distance - 0.9 * u) + o * 1.8 + up * 0.5
		return eye, middle - up * 0.3, math.clamp(need, SETTINGS.FieldOfView, 84), (eye - middle).Magnitude
	elseif shot == "Chair" then
		-- From up on the stage, toward the hall's middle, looking back at the judge with the packed stands behind: up off
		-- the chair, the turn, and away along the front of the stage. (First tests: from the stands' side it was the
		-- judge's back against a dark stage; 4.6 away the judge's chest filled the frame.)
		local eye = current.chair - f * 8.5 - o * 4.5 + up * 4.6 + o * (1.4 * u)
		local look = judgeHead - up * 0.9
		return eye, look, SETTINGS.FieldOfView + 6, (eye - look).Magnitude
	elseif shot == "Side" then
		-- Low at the stage's back corner, out to the side: the judge comes down the stage's side toward the camera.
		local corner = current.way[3]
		local eye = corner + o * 6.5 + f * 3 + up * 1.5
		local look = judgeHead - up * 1.3
		return eye, look, SETTINGS.FieldOfView, (eye - look).Magnitude
	elseif shot == "Through" then
		-- In the lifters' zone, on the benches' side of where the judge will stop: the curtain's split, then the judge
		-- stepping through it, stopping, and looking this way, at the lifters.
		-- (just behind the lifters' line: they stand on the lane now, 1.1 further from the curtain than at first)
		local eye = centre - f * 0.1 - o * 2.8 + up * (3.7 - 0.3 * u)
		local split = current.way[#current.way]
		local arrived = math.clamp((now - current.tThrough) / math.max(current.tArrive - current.tThrough, 0.1), 0, 1)
		local look = (split + up * 3.6):Lerp(judgeHead - up * 0.4, arrived * arrived * (3 - 2 * arrived))
		return eye, look, SETTINGS.FieldOfView, (eye - judgeHead).Magnitude
	elseif shot == "Look" then
		-- Beside the judge, on the outer side: the judge in the near side of the frame, and across the zone the lifters
		-- getting up and walking over to stand in front of them. The camera stays put and turns with the walk.
		local middle = liftersNow(current)
		-- (first test: level with the judge and looking halfway, the judge's head sat across the lifters' way; now a
		-- little toward the zone and looking further their way, the judge at the frame's edge)
		local eye = current.judgeAt + o * 4.8 - f * 1.7 + up * 5.7
		local look = judgeHead:Lerp(middle, 0.68) - up * 0.2
		return eye, look, SETTINGS.FieldOfView + 6, (eye - judgeHead).Magnitude
	end
	local headUp = liftersHeadUp(current)
	if shot == "Tell" then
		-- Behind the lifters and above their heads, in line with the gap between two of them (first test: from out to the
		-- side, the nearer lifter's head sat right in front of the judge): their backs either side, the judge between.
		-- (5.2 back: the lifters stand on the lane now, and the bench row is 4.3 behind it)
		local eye = centre - f * (5.2 - 0.8 * u) + o * current.between + up * (headUp + 2.3)
		local look = judgeHead - up * 0.5
		return eye, look, SETTINGS.FieldOfView, (eye - judgeHead).Magnitude
	end
	-- Verdict: past the judge's shoulder onto the lifters' faces, from well out to the outer side, so the judge's head
	-- sits at the frame's edge and every lifter is clear of it (first test: from just behind the judge, the head filled
	-- the middle of the frame and hid a lifter).
	local eye = Vector3.new(judgeFloor.X, centre.Y, judgeFloor.Z) + f * (2.3 - 0.4 * u) + o * (wide + 3.1) + up * (headUp + 0.6)
	local look = centre + up * (headUp - 0.5)
	return eye, look, SETTINGS.FieldOfView, (eye - look).Magnitude
end

local function shotAt(current: Scene, now: number): (string, number)
	local function through(from: number, to: number): number
		return math.clamp((now - from) / math.max(to - from, 0.1), 0, 1)
	end
	local chairFrom = current.tWalk - CHAIR_LEAD_SECONDS
	local lookFrom = current.tArrive + LOOK_AFTER_SECONDS
	local tell = current.tTell
	if now < chairFrom then
		return "Tie", through(current.t0, chairFrom)
	elseif now < current.tSide then
		return "Chair", through(chairFrom, current.tSide)
	elseif now < current.tThrough then
		return "Side", through(current.tSide, current.tThrough)
	elseif now < lookFrom then
		return "Through", through(current.tThrough, lookFrom)
	elseif tell == nil or now < tell then
		return "Look", through(lookFrom, tell or (lookFrom + 6))
	end
	local secondLine = current.lines[2]
	local verdictFrom = if secondLine then secondLine.at - 0.15 else current.tEnd
	if now < verdictFrom then
		return "Tell", through(tell, verdictFrom)
	end
	return "Verdict", through(verdictFrom, current.tEnd)
end

local function step(dt: number)
	local current = scene
	if current == nil then
		return
	end
	local now = serverNow()
	if now >= current.tEnd or Players.LocalPlayer.Character == nil
		or (current.tTell == nil and now > current.tArrive + GIVE_UP_SECONDS) then
		stop(true)
		return
	end
	local camera = Workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	-- What the judge says, while each line is up: in the bottom bar, and aloud as it starts.
	local saying = 0
	for index, line in ipairs(current.lines) do
		if now >= line.at and now < line.at + line.seconds then
			saying = index
		end
	end
	if saying ~= current.said then
		current.said = saying
		local line = current.lines[saying]
		MeetCinema.says(if line then line.who else "", if line then line.text else nil)
		local voice = if line then current.voices[line.voiceId] else nil
		if voice then
			voice.TimePosition = 0
			voice:Play()
		end
	end
	-- The judge's own light, on the way round the stage (the stage's spotlight only just reaches its edges): from above
	-- and ahead of them, whichever way they face, so it is on their front.
	local lamp = current.followLamp
	if lamp then
		local floor, head = judgeNow(current, now)
		local judge = current.judge
		local root = judge and judge:FindFirstChild("HumanoidRootPart")
		local facing = if root and root:IsA("BasePart") then root.CFrame.LookVector else -current.toStage
		local ahead = Vector3.new(facing.X, 0, facing.Z)
		ahead = if ahead.Magnitude > 1e-3 then ahead.Unit else -current.toStage
		-- (from one side of straight ahead, so the white shirt keeps its shape: lit from dead ahead it was a flat white)
		local side = ahead:Cross(Vector3.yAxis)
		lamp.CFrame = CFrame.lookAt(floor + ahead * 3 + side * 3.5 + Vector3.new(0, 8, 0), head - Vector3.new(0, 1, 0))
	end
	local shot, u = shotAt(current, now)
	local eye, look, fieldOfView, sharp = frameOf(current, shot, u, now)
	camera.FieldOfView = fieldOfView
	MeetCinema.focus(sharp)
	local target = CFrame.lookAt(eye, look) * MeetCinema.handheld(os.clock())
	-- Hard cuts between shots; within one, the camera rides smoothly.
	if shot ~= current.shot then
		current.shot = shot
		-- (which shot is up: for tests, and for anything else on this screen that wants to know)
		Players.LocalPlayer:SetAttribute(SHOT_ATTRIBUTE, shot)
		camera.CFrame = target
	else
		camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-10 * dt))
	end
end

local function vector(value: any): Vector3?
	return if typeof(value) == "Vector3" then value else nil
end

local function linesOf(value: any): { Line }
	local lines: { Line } = {}
	if typeof(value) == "table" then
		for _, line in ipairs(value) do
			if typeof(line) == "table" and typeof(line.at) == "number" and typeof(line.seconds) == "number"
				and typeof(line.who) == "string" and typeof(line.text) == "string" then
				table.insert(lines, { at = line.at, seconds = line.seconds, who = line.who, text = line.text,
					voiceId = if typeof(line.voiceId) == "string" then line.voiceId else "" })
			end
		end
	end
	return lines
end

local function begin(data: any)
	if scene then
		stop(false)
	end
	local chair, judgeAt, centre = vector(data.chair), vector(data.judgeAt), vector(data.centre)
	local toStage, outer = vector(data.toStage), vector(data.outer)
	if chair == nil or judgeAt == nil or centre == nil or toStage == nil or outer == nil or typeof(data.way) ~= "table"
		or typeof(data.t0) ~= "number" or typeof(data.tWalk) ~= "number" or typeof(data.tSide) ~= "number"
		or typeof(data.tThrough) ~= "number" or typeof(data.tArrive) ~= "number" then
		return
	end
	local way: { Vector3 } = {}
	for _, point in ipairs(data.way) do
		if typeof(point) == "Vector3" then
			table.insert(way, point)
		end
	end
	if #way < 3 or data.tArrive + GIVE_UP_SECONDS <= serverNow() then
		return
	end
	local benchAt = vector(data.benchAt) or centre
	local judge = if typeof(data.judge) == "Instance" and data.judge:IsA("Model") then data.judge else nil
	-- (the chair faces the stage, from its front: the other way from the lifters' zone's "toward the stage")
	local path = MeetWalkPath.new({ from = chair, look = -toStage, points = way,
		final = CFrame.lookAt(judgeAt, judgeAt - toStage), height = 0, usualSpeed = LocalMeetConfig.ComputerLifters.WalkSpeed })

	local made: { Instance } = {}
	local function lamp(name: string, from: Vector3, to: Vector3, colour: Color3, brightness: number, range: number,
		angle: number): BasePart
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
		return part
	end
	local warm, cool = Color3.fromRGB(255, 222, 180), Color3.fromRGB(150, 175, 255)
	local up = Vector3.yAxis
	local faces = centre + up * 4.4
	-- The lifters' zone is dark. Where they come to stand: a warm key on their faces from the curtain's side, a cool
	-- light on their backs and shoulders, and a warm one on the judge's face. Where they sit at the start: a warm light
	-- on the bench. And a soft cool wash over the floor between, for the walk across.
	lamp("LiftOffSceneKey", centre + toStage * 6 + outer * 4 + up * 8.5, faces, warm, 8, 20, 60)
	lamp("LiftOffSceneRim", centre - toStage * 5.5 - outer * 2 + up * 8, faces, cool, 3.5, 18, 60)
	lamp("LiftOffSceneJudge", centre - toStage * 1.5 + outer * 4.5 + up * 8.5, judgeAt + up * 4.4, warm, 4.5, 20, 45)
	lamp("LiftOffSceneBench", benchAt + toStage * 5.5 + up * 9, benchAt + up * 2.6, warm, 6, 24, 72)
	local between = benchAt:Lerp(centre, 0.5)
	lamp("LiftOffSceneWalk", between + up * 16, between, cool, 2.4, 40, 110)
	-- (First test: at 5 the judge's white shirt was a flat white shape under the stage's own spotlight.)
	local followLamp = lamp("LiftOffSceneFollow", chair - toStage * 4 + up * 8.5, chair + up * 4, warm, 1.2, 24, 44)
	-- (Lights made this frame stay dark until something moves them: NationalsCurtainScene found it. Moved a hair.)
	for _, delay in ipairs({ 0.1, 0.6 }) do
		task.delay(delay, function()
			for _, thing in ipairs(made) do
				if thing:IsA("BasePart") and thing.Parent and thing ~= followLamp then
					thing.CFrame = thing.CFrame * CFrame.new(0, 0, if delay < 0.5 then -0.01 else 0.01)
				end
			end
		end)
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LiftOffSceneGrade"
	grade.TintColor = Color3.fromRGB(255, 244, 234)
	grade.Contrast = 0.08
	grade.Brightness = 0.04
	grade.Saturation = -0.05
	grade.Parent = Lighting
	table.insert(made, grade)

	-- The judge's lines, loaded now so each starts on its moment.
	local voices: { [string]: Sound } = {}
	if typeof(data.voices) == "table" then
		for _, id in ipairs(data.voices) do
			if typeof(id) == "string" and id ~= "" and voices[id] == nil then
				local sound = Instance.new("Sound")
				sound.Name = "LiftOffJudgeLine"
				sound.SoundId = id
				sound.Volume = SETTINGS.VoiceVolume
				sound.Parent = SoundService
				voices[id] = sound
			end
		end
		task.spawn(function()
			local list: { Instance } = {}
			for _, sound in pairs(voices) do
				table.insert(list, sound)
			end
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
		end)
	end

	local lifters: { number } = {}
	if typeof(data.lifters) == "table" then
		for _, userId in ipairs(data.lifters) do
			if typeof(userId) == "number" then
				table.insert(lifters, userId)
			end
		end
	end
	scene = { t0 = data.t0, tWalk = data.tWalk, tSide = data.tSide, tThrough = data.tThrough, tArrive = data.tArrive,
		tTell = nil, tEnd = math.huge, judge = judge, lifters = lifters,
		count = if typeof(data.count) == "number" then data.count else math.max(#lifters, 2), lines = {}, chair = chair,
		way = way, judgeAt = judgeAt, centre = centre, benchAt = benchAt,
		spread = if typeof(data.spread) == "number" then data.spread else 1.7,
		between = if typeof(data.between) == "number" then data.between else 0, toStage = toStage.Unit, outer = outer.Unit,
		path = path, shot = nil, said = 0, made = made, voices = voices, followLamp = followLamp, tags = {} }
	MeetCinema.open()
	-- (The chalk stand's own camera keeps off while this runs: MeetChalkShot.)
	MeetCinema.ritualCamera = true
	-- The callers' name tags float in the world for everyone: out of the film's way meanwhile (the lifters walk past one).
	for _, hall in ipairs(CollectionService:GetTagged(NationalsConfig.HallTag)) do
		for _, item in ipairs(hall:GetDescendants()) do
			if item:IsA("BillboardGui") and item.Enabled then
				item.Enabled = false
				table.insert((scene :: Scene).tags, item)
			end
		end
	end
	local class = if typeof(data.classLabel) == "string" then string.upper(data.classLabel) else ""
	local level = if typeof(data.totalKg) == "number" then "  ·  LEVEL ON " .. kgText(data.totalKg) .. " KG" else ""
	MeetCinema.caption(class .. level, "TIED FOR " .. placeWord(if typeof(data.place) == "number" then data.place else 1)
		.. " PLACE")
	-- They stay where they are until the server walks them over: no wandering off while the camera is away.
	ContextActionService:BindActionAtPriority(FREEZE_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(Enum.PlayerActions:GetEnumItems()))
	setControls(false)
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
end

-- The lifters stand in front of the judge: the words and when it ends.
local function tell(data: any)
	local current = scene
	if current == nil or typeof(data.tEnd) ~= "number" then
		return
	end
	local lines = linesOf(data.lines)
	current.lines = lines
	current.tEnd = data.tEnd
	current.tTell = (if lines[1] then lines[1].at else serverNow()) - TELL_LEAD_SECONDS
end

function NationalsLiftOffScene.start()
	if started then
		return
	end
	started = true
	local remotes = LocalMeetRemotes.waitForClient(ReplicatedStorage)
	remotes.scene.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if data.kind == "LiftOff" then
			begin(data)
		elseif data.kind == "LiftOffLines" then
			tell(data)
		end
	end)
	-- Out of the meet: everything back.
	Players.LocalPlayer:GetAttributeChangedSignal(LocalMeetConfig.PlatformAttribute):Connect(function()
		if Players.LocalPlayer:GetAttribute(LocalMeetConfig.PlatformAttribute) == nil then
			stop(true)
		end
	end)
end

return NationalsLiftOffScene
