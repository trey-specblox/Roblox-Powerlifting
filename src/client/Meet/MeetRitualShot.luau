--!strict
--[[
	MeetRitualShot
	Client / Meet

	The coach's ritual at the chalk stand (GAME_DESIGN §36.4, user 2026-11-11; LocalMeetConfig.Ritual), on the lifter's
	own screen on every turn at State and up. From "You're up" the camera cuts, hard, through the shots of the user's
	reference video:
		Face       a profile close-up of the lifter chalking up; the attempt and weight come up below
		OverCoach  over the coach's shoulder: the lifter faces the camera while the coach talks (subtitle)
		Hands      the hands, close, on the chalk claps
		SendOff    from behind: the coach slaps their back and shouts (subtitle, text only)
	The server times the coach (LocalMeetService coachSendOff); the shots follow the server's clock from the moment it
	sent ("startedAt"), so they line up with what the coach does. At the walk out MeetLiftMoment carries on with the
	walk's shots and ends the film look (MeetCinema) at the bar.
	The first turn of a meet always plays; after that SKIP (MeetCinema) cuts straight to the plain camera.

	Display only: it decides and saves nothing.
	PERFORMANCE: while it runs, one camera move and one ray a frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local MockMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("MockMeetRemotes"))

local MeetCinema = require(script.Parent:WaitForChild("MeetCinema"))

local MeetRitualShot = {}

local SETTINGS = LocalMeetConfig.Ritual
local RENDER_NAME = "MeetRitualShot"
local ATTEMPT_WORDS = { "FIRST", "SECOND", "THIRD" }
-- A part this see-through doesn't stop the camera (hidden walls).
local CLEAR_PART = 0.95
-- A coach further than this from the lifter has not reached them yet: the over-the-shoulder shot waits for them.
local COACH_NEAR_STUDS = 7

type Run = {
	view: MockMeetRemotes.RitualView,
	chalk: MockMeetRemotes.ChalkView,
	shot: string?,
	shotStart: number,
	params: RaycastParams,
}
local run: Run? = nil
-- Turns with a ritual in this meet (the first can't be skipped), and the ritual already skipped or played.
local turnsThisMeet = 0
local doneAt: number? = nil

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

local function part(model: Model?, name: string): BasePart?
	local found = model and model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function flat(vector: Vector3): Vector3
	local level = Vector3.new(vector.X, 0, vector.Z)
	return if level.Magnitude > 0.01 then level.Unit else Vector3.new(0, 0, -1)
end

-- As far from `subject` toward `eye` as the camera can go without passing through something solid and visible.
local function clearOf(subject: Vector3, eye: Vector3, params: RaycastParams): Vector3
	local ignored = table.clone(params.FilterDescendantsInstances)
	for _ = 1, 4 do
		local hit = Workspace:Raycast(subject, eye - subject, params)
		if hit == nil then
			return eye
		end
		if hit.Instance.Transparency < CLEAR_PART then
			return hit.Position + (subject - eye).Unit * 0.4
		end
		table.insert(ignored, hit.Instance)
		params.FilterDescendantsInstances = ignored
	end
	return eye
end

-- The shot on at `elapsed` seconds into the ritual.
local function shotAt(elapsed: number): string
	local name = SETTINGS.Shots[1].name
	for _, shot in ipairs(SETTINGS.Shots) do
		if elapsed >= shot.from then
			name = shot.name
		end
	end
	return name
end

local function stopShots()
	if run == nil then
		return
	end
	run = nil
	MeetCinema.ritualCamera = false
	RunService:UnbindFromRenderStep(RENDER_NAME)
end

local function enterShot(current: Run, name: string)
	current.shot = name
	current.shotStart = os.clock()
	if name == "OverCoach" then
		MeetCinema.subtitle(current.view.coachLine)
	elseif name == "Hands" then
		MeetCinema.subtitle(nil)
	elseif name == "SendOff" then
		MeetCinema.subtitle(current.view.sendOffLine)
	end
end

local function step()
	local current = run
	if current == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	-- (Something else may have handed the camera back meanwhile: it stays this shot's.)
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local character = Players.LocalPlayer.Character
	local root = part(character, "HumanoidRootPart")
	local head = part(character, "Head")
	if root == nil or head == nil then
		return
	end
	local elapsed = Workspace:GetServerTimeNow() - current.view.startedAt
	local name = shotAt(elapsed)
	if name ~= current.shot then
		enterShot(current, name)
	end
	local ahead = flat(root.CFrame.LookVector)
	local out = flat(current.chalk.out)
	local up = Vector3.yAxis
	local headAt = head.Position
	local eye: Vector3
	local look: Vector3
	if name == "Face" then
		-- Profile, from the open side, a little ahead of the face: head and shoulders.
		eye = headAt + out * 3.6 + ahead * 0.9 - up * 0.1
		look = headAt + ahead * 0.25 - up * 0.45
	elseif name == "OverCoach" then
		local coachHead = part(current.chalk.coach, "Head")
		if coachHead and (coachHead.Position - headAt).Magnitude < COACH_NEAR_STUDS then
			-- Behind the coach's shoulder on the open side, looking past them at the lifter's face: the coach a soft
			-- edge of the frame, not half of it.
			local away = flat(coachHead.Position - headAt)
			eye = coachHead.Position + away * 1.1 + out * 1.6 + up * 0.25
		else
			-- (The coach hasn't reached the stand: from in front, three-quarters.)
			eye = headAt + ahead * 3.4 + out * 1.4 + up * 0.2
		end
		look = headAt - up * 0.15
	elseif name == "Hands" then
		local left, right = part(character, "LeftHand"), part(character, "RightHand")
		local hands = if left and right then (left.Position + right.Position) / 2 else root.Position + ahead * 0.8 + up * 0.6
		eye = hands + ahead * 2.5 + out * 1.5 + up * 0.45
		look = hands + up * 0.1
	else
		-- SendOff: side on from the open side (where nothing stands in the way), the coach at the lifter's back.
		local coachRoot = part(current.chalk.coach, "HumanoidRootPart")
		local between = if coachRoot and (coachRoot.Position - root.Position).Magnitude < COACH_NEAR_STUDS
			then (root.Position + coachRoot.Position) / 2 else root.Position - ahead * 0.9
		eye = between + out * 5.2 - ahead * 0.8 + up * 1.4
		look = between + up * 1.1
	end
	-- A slow push in through each shot, so nothing sits dead still.
	local shotTime = os.clock() - current.shotStart
	eye = eye:Lerp(look, 0.07 * math.min(1, shotTime / 2.5))
	eye = clearOf(look, eye, current.params)
	MeetCinema.focus((eye - look).Magnitude)
	camera.CFrame = CFrame.lookAt(eye, look) * MeetCinema.handheld(os.clock())
end

-- SKIP: straight to the plain camera for the rest of this turn.
local function skip()
	if run then
		doneAt = run.view.startedAt
	end
	stopShots()
	MeetCinema.close()
end

local function begin(state: MockMeetRemotes.MeetState, view: MockMeetRemotes.RitualView, chalk: MockMeetRemotes.ChalkView)
	stopShots()
	doneAt = view.startedAt
	turnsThisMeet += 1
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	if chalk.coach then
		table.insert(ignore, chalk.coach)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = false
	run = { view = view, chalk = chalk, shot = nil, shotStart = os.clock(), params = params }

	MeetCinema.open()
	MeetCinema.ritualCamera = true
	MeetCinema.walkShots = true
	MeetCinema.skipButton(if turnsThisMeet > 1 then skip else nil)
	MeetCinema.caption(string.format("%s %s", ATTEMPT_WORDS[state.attemptNumber or 1] or "", string.upper(state.lift or "")),
		kgText(state.declaredKg or 0) .. " KG")
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, step)
end

-- Every state of the meet the player is lifting in (LocalMeetController).
function MeetRitualShot.onState(state: MockMeetRemotes.MeetState)
	if state.phase == "WeighIn" then
		turnsThisMeet = 0
	end
	local view, chalk = state.ritual, state.chalk
	if state.phase == "Waiting" and view and chalk then
		-- (The same turn's state again, or a ritual already skipped: nothing new.)
		if doneAt ~= view.startedAt then
			begin(state, view, chalk)
		elseif run then
			run.chalk = chalk
		end
		return
	end
	if state.phase == "Ready" then
		-- The walk out: MeetLiftMoment takes the camera and carries the film look on to the bar.
		stopShots()
		MeetCinema.subtitle(nil)
		return
	end
	if run then
		-- Anything else (they withdrew, the meet ended): all back to normal.
		stopShots()
		MeetCinema.close()
	end
end

-- Ends it at once (the player left the meet).
function MeetRitualShot.stop()
	stopShots()
	MeetCinema.close()
end

return MeetRitualShot
