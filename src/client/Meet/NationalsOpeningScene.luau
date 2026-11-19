--!strict
--[[
	NationalsOpeningScene
	Client / Meet

	The Nationals meet's opening, as a cinematic on each lifter's own screen (GAME_DESIGN §39, user 2026-11-18: "when
	they enter the meet area ... a cinematic flying camera, of the venue. Then it pans to the announcer (a judge), talking
	to the crowd under a spotlight ... he walks back to his seat, Then the camera goes back to the lifter, and the coach
	says ..."). The server moves the real figures and plays the announcer's voice over the hall's speakers
	(NationalsScenes) and sends this screen the moments (LocalMeetRemotes.SCENE, kind "Opening"); this only runs the film
	look (MeetCinema), the camera, a few lights, the words in the bottom bar and the highlight on the lifter's rivals.

	The shots (the fwjelaa direction notes: each view shows something the last one didn't):
		Title      black, "NATIONAL CHAMPIONSHIP / CENTRAL NATIONALS", the camera already waiting at the tour's start (so the
		           far platforms have their lights when the picture comes up), fading into
		Tour       one flying move: from high over the far end of the main stand, down across the crowd and along the lit
		           platforms, settling on the spectators' floor in front of the announcer as the spotlight finds them
		Announce1  the announcer from the front, the lit platform behind: who is speaking
		Announce2  from behind them, over the shoulder: the packed stands they are speaking to
		Announce3  close, from the front and to one side: the last line
		Back       wide from the stage: the announcer walks back to the chair and sits
		Coach1     over the seated lifter's shoulder onto their coach, standing in front of them
		Rivals     the lifters they are placed against, highlighted ("there is your competition")
		Coach2     past the coach's shoulder onto the lifter's own face, for the plan
	Each lifter sees their platform's coach standing in front of THEIR seat: the coach is one figure shared by a
	platform's lifters, so this screen stands them there for these few seconds and puts them back after (drawing only).

	Display only: it decides and saves nothing. PERFORMANCE: one camera move a frame while it runs; three lights and a
	colour grade, made and removed with it; one Highlight per rival for the last few seconds.
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local NationalsConfig = require(ConfigFolder:WaitForChild("NationalsConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local MeetCinema = require(script.Parent:WaitForChild("MeetCinema"))
local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))

local NationalsOpeningScene = {}

local SETTINGS = NationalsConfig.Opening
local RENDER_NAME = "NationalsOpeningScene"
local FREEZE_ACTION = "NationalsOpeningFreeze"
-- The local player's attribute naming the shot on screen while a Nationals cinematic runs (nil otherwise).
local SHOT_ATTRIBUTE = "NationalsSceneShot"
-- A standing figure's head above the floor, when the figure itself can't be read.
local HEAD_UP = 4.9
-- The coach stands this far in front of the seated lifter.
local COACH_AHEAD = 3.6
-- Rivals further apart than this (lifters on other platforms' benches) are shown down the lifters' zone instead.
local RIVALS_WIDE = 36

type Line = { at: number, seconds: number, text: string }
type TourPoint = { eye: Vector3, look: Vector3 }
type Scene = {
	t0: number,
	tSpeak: number,
	tBack: number,
	tCoach: number,
	tEnd: number,
	tour: { TourPoint },
	announcer: Model?,
	announceAt: Vector3,
	toStands: Vector3,
	side: Vector3,
	cuts: { number },
	voiceLines: { Line },
	coach: Model?,
	coachHome: CFrame?,
	coachPlaced: boolean,
	coachLines: { Line },
	rivals: { number },
	benchFacing: Vector3,
	shot: string?,
	said: string?,
	made: { Instance },
	-- The black title card over the wait before the tour (its frame and its two lines), faded out as the tour starts.
	title: { Frame | TextLabel },
	highlights: { Instance },
	-- The world's floating tags hidden meanwhile (the callers').
	tags: { BillboardGui },
}

local scene: Scene? = nil
local started = false

local function serverNow(): number
	return Workspace:GetServerTimeNow()
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

local function headOf(model: Model?): Vector3?
	local head = model and model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else nil
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
	for _, highlight in ipairs(current.highlights) do
		highlight:Destroy()
	end
	for _, tag in ipairs(current.tags) do
		if tag.Parent then
			tag.Enabled = true
		end
	end
	-- The coach back where the server has them.
	local coach, home = current.coach, current.coachHome
	if coach and home and current.coachPlaced and coach.Parent then
		coach:PivotTo(home)
	end
	MeetCinema.says("", nil)
	MeetCinema.skipButton(nil)
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

-- A smooth curve through `points` at `u` (0..1 along all of it): Catmull-Rom.
local function along(points: { Vector3 }, u: number): Vector3
	local count = #points
	if count == 1 then
		return points[1]
	end
	local scaled = math.clamp(u, 0, 1) * (count - 1)
	local index = math.min(math.floor(scaled), count - 2)
	local t = scaled - index
	local p0 = points[math.max(index, 1)]
	local p1 = points[index + 1]
	local p2 = points[index + 2]
	local p3 = points[math.min(index + 3, count)]
	local t2, t3 = t * t, t * t * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- The lifter on their bench: where their head is, and the floor point under them.
local function lifterNow(): (Vector3?, Vector3?)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = headOf(character)
	if root == nil or not root:IsA("BasePart") or head == nil then
		return nil, nil
	end
	return head, root.Position
end

-- Stands the platform's coach in front of this lifter, facing them (on this screen only), once.
local function placeCoach(current: Scene)
	local coach = current.coach
	local _, rootAt = lifterNow()
	if current.coachPlaced or coach == nil or coach.Parent == nil or rootAt == nil then
		return
	end
	current.coachPlaced = true
	local home = coach:GetPivot()
	current.coachHome = home
	local f = current.benchFacing
	local at = Vector3.new(rootAt.X + f.X * COACH_AHEAD, home.Position.Y, rootAt.Z + f.Z * COACH_AHEAD)
	coach:PivotTo(CFrame.lookAt(at, at - f))
end

-- The rivals' characters that are here to see.
local function rivalBodies(current: Scene): { Model }
	local bodies: { Model } = {}
	for _, userId in ipairs(current.rivals) do
		local player = Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			table.insert(bodies, character)
		end
	end
	return bodies
end

local function highlightRivals(current: Scene)
	if #current.highlights > 0 then
		return
	end
	for _, body in ipairs(rivalBodies(current)) do
		local highlight = Instance.new("Highlight")
		highlight.Name = "NationalsRival"
		highlight.FillColor = UIStyle.Colours.yellow
		highlight.FillTransparency = 0.65
		highlight.OutlineColor = UIStyle.Colours.yellow
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Adornee = body
		highlight.Parent = body
		table.insert(current.highlights, highlight)
	end
end

-- (eye, look, field of view, how far the sharp subject is) for `shot` at `u` (0..1 through it).
local function frameOf(current: Scene, shot: string, u: number): (Vector3, Vector3, number, number)
	local n, c, up = current.toStands, current.side, Vector3.yAxis
	local at = current.announceAt
	local announcerHead = headOf(current.announcer) or (at + up * HEAD_UP)
	local last = current.tour[#current.tour]
	if shot == "Tour" then
		local eyes: { Vector3 } = {}
		local looks: { Vector3 } = {}
		for _, point in ipairs(current.tour) do
			table.insert(eyes, point.eye)
			table.insert(looks, point.look)
		end
		local eased = smooth(u)
		local eye = along(eyes, eased)
		-- (the last stretch looks at the announcer themself, wherever they stand)
		local look = along(looks, eased):Lerp(announcerHead - up * 0.3, smooth((eased - 0.8) / 0.2))
		return eye, look, 62 + (SETTINGS.FieldOfView - 62) * eased, (eye - look).Magnitude
	elseif shot == "Announce1" then
		-- Where the tour ended, on the spectators' floor, easing in.
		local eye = last.eye:Lerp(announcerHead, 0.16 * smooth(u))
		local look = announcerHead - up * 0.3
		return eye, look, SETTINGS.FieldOfView, (eye - look).Magnitude
	elseif shot == "Announce2" then
		-- Behind them, just above their shoulder: their back to one side of the frame, the stands they are talking to
		-- beyond. (First test: from higher up, looking up into the stands, only the top of their head was in it.)
		local eye = at - n * 5.2 + c * (2.6 - 0.6 * u) + up * 5.9
		local look = at + n * 30 + up * 7.5
		-- (the crowd is the news here: sharp, the announcer's back soft in front of it)
		return eye, look, SETTINGS.FieldOfView + 6, 34
	elseif shot == "Announce3" then
		local eye = at + n * (5.2 - 0.5 * u) - c * 3.2 + up * 4.5
		local look = announcerHead - up * 0.2
		return eye, look, SETTINGS.FieldOfView - 6, (eye - look).Magnitude
	elseif shot == "Back" then
		-- From up on the stage: the announcer walks back toward the chair and sits.
		local eye = at - n * 14 - c * 7.5 + up * 6
		local look = announcerHead - up * 0.8
		return eye, look, SETTINGS.FieldOfView, (eye - look).Magnitude
	end
	-- The lifter and their coach.
	local f = current.benchFacing
	local side = f:Cross(up)
	local head, rootAt = lifterNow()
	head = head or at
	rootAt = rootAt or at
	local coachHead = headOf(current.coach) or (rootAt :: Vector3 + f * COACH_AHEAD + up * 1.4)
	if shot == "Coach1" then
		-- Behind the seated lifter, out to one side and well above their head, looking down onto the coach. (First tests:
		-- close behind, the lifter's head filled half the frame and hid the coach; now it sits low in the frame's corner.)
		local eye = head :: Vector3 - f * (4.3 - 0.3 * u) + side * 3.6 + up * 3.1
		local look = coachHead - up * 1.0 + side * 0.5
		return eye, look, SETTINGS.FieldOfView, (eye - look).Magnitude
	elseif shot == "Rivals" then
		local bodies = rivalBodies(current)
		local centre, count = Vector3.zero, 0
		for _, body in ipairs(bodies) do
			local where = headOf(body)
			if where then
				centre += where
				count += 1
			end
		end
		if count > 0 then
			centre /= count
			local half = 0
			for _, body in ipairs(bodies) do
				local where = headOf(body)
				if where then
					half = math.max(half, math.abs((where - centre):Dot(side)), (where - centre).Magnitude * 0.6)
				end
			end
			if half * 2 <= RIVALS_WIDE then
				-- From in front of the bench and above (over the coach's head), all of them in the frame.
				local viewport = Workspace.CurrentCamera.ViewportSize
				local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 1.78
				local distance = 8
				local need = math.deg(2 * math.atan((half + 2.4) / distance / aspect))
				local eye = centre + f * distance + up * (4.4 - 0.4 * u)
				return eye, centre - up * 0.3, math.clamp(need, 38, 84), (eye - centre).Magnitude
			end
			-- Spread over other platforms' benches: from beside this lifter, down the lifters' zone toward them.
			local toward = Vector3.new(centre.X - (head :: Vector3).X, 0, centre.Z - (head :: Vector3).Z)
			toward = if toward.Magnitude > 1 then toward.Unit else side
			local eye = head :: Vector3 - toward * 5 + f * 2.5 + up * 3
			return eye, centre, 58, (eye - centre).Magnitude
		end
		shot = "Coach2"
	end
	-- Coach2: past the coach's shoulder onto the lifter's own face, from well out to the side, so the coach's head sits
	-- at the frame's edge. (First test: from just behind the coach it filled the near half of the frame.)
	local eye = coachHead + f * (1.7 - 0.3 * u) - side * 3.0 + up * 0.4
	local look = head :: Vector3 - up * 0.1 + side * 0.5
	return eye, look, SETTINGS.FieldOfView - 4, (eye - look).Magnitude
end

-- The title card's black is 3% see-through, so the hall is certainly still being drawn behind it while its light
-- settles. (A precaution only: Studio 2026-11-18, the hall came up unlit behind a solid cover AND behind this one; what
-- cured it was Camera.Focus, in `step`. The lit runs were made with this value, so it stays.)
local TITLE_SEE_THROUGH = 0.03

local function shotAt(current: Scene, now: number): (string, number)
	local function through(from: number, to: number): number
		return math.clamp((now - from) / math.max(to - from, 0.1), 0, 1)
	end
	if now < current.tSpeak then
		return "Tour", through(current.t0, current.tSpeak)
	elseif now < current.cuts[1] then
		return "Announce1", through(current.tSpeak, current.cuts[1])
	elseif now < current.cuts[2] then
		return "Announce2", through(current.cuts[1], current.cuts[2])
	elseif now < current.tBack then
		return "Announce3", through(current.cuts[2], current.tBack)
	elseif now < current.tCoach then
		return "Back", through(current.tBack, current.tCoach)
	end
	local first, second = current.coachLines[1], current.coachLines[2]
	if first and second and #current.rivals > 0 then
		-- "There is your competition": a beat on the coach, then them; back to the lifter for the plan.
		local rivalsFrom = first.at + 1.1
		if now < rivalsFrom then
			return "Coach1", through(current.tCoach, rivalsFrom)
		elseif now < second.at - 0.1 then
			return "Rivals", through(rivalsFrom, second.at - 0.1)
		end
		return "Coach2", through(second.at - 0.1, current.tEnd)
	end
	local half = (current.tCoach + current.tEnd) / 2
	if now < half then
		return "Coach1", through(current.tCoach, half)
	end
	return "Coach2", through(half, current.tEnd)
end

local function step(dt: number)
	local current = scene
	if current == nil then
		return
	end
	local now = serverNow()
	if now >= current.tEnd or Players.LocalPlayer.Character == nil then
		stop(true)
		return
	end
	local camera = Workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	-- The words in the bottom bar: the announcer's, in step with the voice; then the coach's.
	local saying: string? = nil
	for _, line in ipairs(current.voiceLines) do
		if now >= line.at and now < line.at + line.seconds then
			saying = "ANNOUNCER:  " .. line.text
		end
	end
	for _, line in ipairs(current.coachLines) do
		if now >= line.at and now < line.at + line.seconds then
			saying = "COACH:  " .. line.text
		end
	end
	if saying ~= current.said then
		current.said = saying
		MeetCinema.line(saying)
	end
	-- The coach in front of this lifter, from a moment before the camera comes back to them.
	if now >= current.tCoach - 0.6 then
		placeCoach(current)
	end
	-- The title card: black until the tour starts, then fading away (set every frame: a tween can stall on a screen
	-- that isn't drawing).
	if #current.title > 0 then
		local faded = math.clamp((now - current.t0) / SETTINGS.TitleFadeSeconds, 0, 1)
		for _, item in ipairs(current.title) do
			if item:IsA("TextLabel") then
				item.TextTransparency = faded
			else
				item.BackgroundTransparency = TITLE_SEE_THROUGH + (1 - TITLE_SEE_THROUGH) * faded
			end
		end
		if faded >= 1 then
			local card = current.title[1].Parent
			if card and card:IsA("ScreenGui") then
				card.Enabled = false
			end
			table.clear(current.title)
		end
	end
	local shot, u = shotAt(current, now)
	if shot == "Rivals" or (shot == "Coach2" and #current.rivals > 0) then
		highlightRivals(current)
	end
	local eye, look, fieldOfView, sharp = frameOf(current, shot, u)
	-- Tell the engine where this camera is looking. A scripted camera's Focus is not moved for it, so it stayed on the
	-- lifter's bench, and after the trip into the hall the engine worked out the light around the bench first and the
	-- far platforms last (Studio 2026-11-18: the tour's first 5 s unlit, on and off between runs).
	camera.Focus = CFrame.new(look)
	camera.FieldOfView = fieldOfView
	MeetCinema.focus(sharp)
	local target = CFrame.lookAt(eye, look) * MeetCinema.handheld(os.clock())
	-- Hard cuts between shots (the tour runs straight into the first shot of the announcer); within one, it rides smoothly.
	if shot ~= current.shot then
		local cut = not (current.shot == "Tour" and shot == "Announce1")
		current.shot = shot
		Players.LocalPlayer:SetAttribute(SHOT_ATTRIBUTE, shot)
		if cut then
			camera.CFrame = target
			return
		end
	end
	camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-(if shot == "Tour" then 14 else 9) * dt))
end

local function vector(value: any): Vector3?
	return if typeof(value) == "Vector3" then value else nil
end

local function linesOf(value: any): { Line }
	local lines: { Line } = {}
	if typeof(value) == "table" then
		for _, line in ipairs(value) do
			if typeof(line) == "table" and typeof(line.at) == "number" and typeof(line.seconds) == "number"
				and typeof(line.text) == "string" then
				table.insert(lines, { at = line.at, seconds = line.seconds, text = line.text })
			end
		end
	end
	return lines
end

local function begin(data: any)
	if scene then
		stop(false)
	end
	local announceAt, toStands = vector(data.announceAt), vector(data.toStands)
	local benchFacing = vector(data.benchFacing)
	if announceAt == nil or toStands == nil or benchFacing == nil or typeof(data.tour) ~= "table"
		or typeof(data.t0) ~= "number" or typeof(data.tSpeak) ~= "number" or typeof(data.tBack) ~= "number"
		or typeof(data.tCoach) ~= "number" or typeof(data.tEnd) ~= "number" or data.tEnd <= serverNow() then
		return
	end
	local tour: { TourPoint } = {}
	for _, point in ipairs(data.tour) do
		if typeof(point) == "table" and typeof(point.eye) == "Vector3" and typeof(point.look) == "Vector3" then
			table.insert(tour, { eye = point.eye, look = point.look })
		end
	end
	if #tour < 2 then
		return
	end
	local cuts: { number } = {}
	if typeof(data.announceCuts) == "table" then
		for _, cut in ipairs(data.announceCuts) do
			if typeof(cut) == "number" then
				table.insert(cuts, cut)
			end
		end
	end
	if #cuts < 2 then
		cuts = { data.tSpeak + (data.tBack - data.tSpeak) / 3, data.tSpeak + (data.tBack - data.tSpeak) * 2 / 3 }
	end
	local rivals: { number } = {}
	if typeof(data.rivals) == "table" then
		for _, userId in ipairs(data.rivals) do
			-- (never themself, but for a Studio test of one lifter, who then stands in as their own rival)
			if typeof(userId) == "number" and (userId ~= Players.LocalPlayer.UserId or data.studioSelfRival == true) then
				table.insert(rivals, userId)
			end
		end
	end
	local n = toStands.Unit
	local f = benchFacing.Unit
	local up = Vector3.yAxis

	local made: { Instance } = {}
	local function lamp(name: string, from: Vector3, to: Vector3, colour: Color3, brightness: number, range: number, angle: number)
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
	-- The lifters' zone is dark: a warm light on this lifter and the coach in front of them, a cool one on their back,
	-- and a soft one down on the bench for the rivals. Made now, long before the camera comes back here.
	local head, rootAt = lifterNow()
	if head and rootAt then
		local side = f:Cross(up)
		local between = rootAt + f * (COACH_AHEAD / 2) + up * 1.2
		local warm, cool = Color3.fromRGB(255, 222, 180), Color3.fromRGB(150, 175, 255)
		lamp("OpeningSceneKey", rootAt + f * 1.8 + side * 5 + up * 8, between, warm, 6, 22, 62)
		lamp("OpeningSceneRim", rootAt - f * 5.5 - side * 2.5 + up * 7.5, between, cool, 3.5, 20, 60)
		lamp("OpeningSceneBench", rootAt + f * 6 + up * 11, rootAt + up * 1.5, warm, 4, 30, 84)
		for _, delay in ipairs({ 0.2, 0.8 }) do
			task.delay(delay, function()
				for _, thing in ipairs(made) do
					if thing:IsA("BasePart") and thing.Parent then
						thing.CFrame = thing.CFrame * CFrame.new(0, 0, if delay < 0.5 then -0.01 else 0.01)
					end
				end
			end)
		end
	end
	-- The stands in front of the announcer, for the shot from behind them: two soft washes over the crowd, as if the
	-- house lights had come up a little for the welcome (in the dark room the crowd was only a black shape).
	local stands = announceAt + n * 44 + up * 13
	for _, sideways in ipairs({ -26, 26 }) do
		lamp("OpeningSceneCrowd", announceAt + n * 16 + n:Cross(up) * sideways * 0.5 + up * 40, stands + n:Cross(up) * sideways,
			Color3.fromRGB(255, 244, 228), 3.2, 90, 74)
	end
	-- The title card: black, the event's name in the game's yellow heading, over everything but the film's own bars.
	local card = Instance.new("ScreenGui")
	card.Name = "NationalsOpeningTitle"
	card.ResetOnSpawn = false
	card.IgnoreGuiInset = true
	card.DisplayOrder = 19
	local black = Instance.new("Frame")
	black.Name = "Black"
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = TITLE_SEE_THROUGH
	black.BorderSizePixel = 0
	black.Size = UDim2.fromScale(1, 1)
	black.Parent = card
	local small = UIStyle.text(card, "Small", UDim2.new(0.1, 0, 0.5, -64), UDim2.new(0.8, 0, 0, 28), 22, UIStyle.Colours.white,
		UIStyle.font(Enum.FontWeight.Bold), Enum.TextXAlignment.Center)
	small.Text = string.upper(NationalsConfig.EventSub)
	local big = UIStyle.text(card, "Big", UDim2.new(0.05, 0, 0.5, -34), UDim2.new(0.9, 0, 0, 76), 64, UIStyle.Colours.yellow,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	big.Text = "CENTRAL " .. NationalsConfig.EventTitle
	big.TextScaled = true
	local bigLimit = Instance.new("UITextSizeConstraint")
	bigLimit.MaxTextSize = 64
	bigLimit.Parent = big
	table.insert(made, card)
	local title: { Frame | TextLabel } = { black, small, big }
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "OpeningSceneGrade"
	grade.TintColor = Color3.fromRGB(255, 246, 238)
	grade.Contrast = 0.06
	grade.Brightness = 0.03
	grade.Parent = Lighting
	table.insert(made, grade)

	scene = { t0 = data.t0, tSpeak = data.tSpeak, tBack = data.tBack, tCoach = data.tCoach, tEnd = data.tEnd, tour = tour,
		announcer = if typeof(data.announcer) == "Instance" and data.announcer:IsA("Model") then data.announcer else nil,
		announceAt = announceAt, toStands = n, side = n:Cross(up), cuts = cuts, voiceLines = linesOf(data.voiceLines),
		coach = if typeof(data.coach) == "Instance" and data.coach:IsA("Model") then data.coach else nil,
		coachHome = nil, coachPlaced = false, coachLines = linesOf(data.coachLines), rivals = rivals, benchFacing = f,
		shot = nil, said = nil, made = made, title = title, highlights = {}, tags = {} }
	MeetCinema.open()
	-- Shown only now: MeetCinema.open hides every screen that is already up (Studio 2026-11-18: put up before it, the
	-- card was switched off with the rest and never seen).
	card.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- (The chalk stand's own camera keeps off while this runs: MeetChalkShot.)
	MeetCinema.ritualCamera = true
	-- The callers' name tags float in the world for everyone: out of the film's way meanwhile.
	for _, hall in ipairs(CollectionService:GetTagged(NationalsConfig.HallTag)) do
		for _, item in ipairs(hall:GetDescendants()) do
			if item:IsA("BillboardGui") and item.Enabled then
				item.Enabled = false
				table.insert((scene :: Scene).tags, item)
			end
		end
	end
	MeetCinema.skipButton(function()
		stop(true)
	end)
	-- They stay on their bench: no walking or jumping off it while the camera is away.
	ContextActionService:BindActionAtPriority(FREEZE_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(Enum.PlayerActions:GetEnumItems()))
	setControls(false)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(tour[1].eye, tour[1].look)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
end

function NationalsOpeningScene.start()
	if started then
		return
	end
	started = true
	local remotes = LocalMeetRemotes.waitForClient(ReplicatedStorage)
	remotes.scene.OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" and data.kind == "Opening" then
			begin(data)
		end
	end)
	-- Out of the meet: everything back.
	Players.LocalPlayer:GetAttributeChangedSignal(LocalMeetConfig.PlatformAttribute):Connect(function()
		if Players.LocalPlayer:GetAttribute(LocalMeetConfig.PlatformAttribute) == nil then
			stop(true)
		end
	end)
	--[[
		"The hall is here": a place only just walked into arrives on this screen piece by piece, and its lights show only
		once it has (Studio 2026-11-18: the platforms' spotlights came on 10 to 25 s after walking in, and the opening's
		tour flew through a black hall). Each time this player comes into the hall, wait until nothing new has arrived in
		it for HallQuietSeconds and tell the server once (LocalMeetRemotes.SCENE "HallReady"): the opening waits for it.
	]]
	local visit = 0
	local function watchHall()
		visit += 1
		local mine = visit
		if Players.LocalPlayer:GetAttribute(NationalsConfig.InHallAttribute) == nil then
			return
		end
		task.spawn(function()
			local hall = CollectionService:GetTagged(NationalsConfig.HallTag)[1]
			while hall == nil and visit == mine do
				task.wait(0.5)
				hall = CollectionService:GetTagged(NationalsConfig.HallTag)[1]
			end
			if visit ~= mine or hall == nil then
				return
			end
			local lastArrival = os.clock()
			local arriving = hall.DescendantAdded:Connect(function()
				lastArrival = os.clock()
			end)
			while visit == mine and os.clock() - lastArrival < SETTINGS.HallQuietSeconds do
				task.wait(0.25)
			end
			arriving:Disconnect()
			if visit == mine then
				remotes.scene:FireServer("HallReady")
			end
		end)
	end
	Players.LocalPlayer:GetAttributeChangedSignal(NationalsConfig.InHallAttribute):Connect(watchHall)
	watchHall()
end

return NationalsOpeningScene
