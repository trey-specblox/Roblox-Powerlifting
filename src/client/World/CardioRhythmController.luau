--!strict
--[[
	CardioRhythmController
	Client / World

	Shows the treadmill rhythm game (GAME_DESIGN.md §27 "The treadmill rhythm
	game") and sends this player's lane presses. It decides nothing: the
	server's CardioRhythmService judges every press, counts the misses and
	ends the run (CardioRhythmRemotes).

	  On YOUR screen, while you are a runner: four lanes with the notes falling
	  to the line, your health, the level and your time, PERFECT / GOOD / MISS;
	  the keys are the arrow keys or D F J K (controller: d-pad or X A Y B; on a
	  phone, tap the lanes). Jump still hops you off (and ends your run).
	  On the Cardio room's wall TV, for everyone: the round's countdown, the
	  same notes, the level, the time, every runner's health, then the results.
	  The beat (CardioRhythmConfig.Sounds) plays from the TV, timed from the
	  server clock, so everyone in the room hears the same beat.

	Every client builds the same notes from the round's seed (RhythmChart).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("CardioRhythmConfig"))
local RhythmChart = require(Shared:WaitForChild("World"):WaitForChild("RhythmChart"))
local CardioRhythmRemotes = require(Shared:WaitForChild("World"):WaitForChild("CardioRhythmRemotes"))

local CardioRhythmController = {}

local localPlayer = Players.LocalPlayer
local started = false
local HIT_LINE = 0.86 -- the line's height in a lane, from the top (0) to the bottom (1)
local NOTE_POOL = 48
local ACTION_PREFIX = "CardioRhythmLane"
local WHITE = Color3.fromRGB(255, 255, 255)
local PANEL_BACK = Color3.fromRGB(14, 18, 34)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local remotes: CardioRhythmRemotes.RemoteSet
local state: CardioRhythmRemotes.State = { phase = "Idle", seed = 0, startAt = 0, endsAt = 0, runners = {} }
local chart: RhythmChart.Chart = { notes = {}, beats = {} }
local chartSeed = 0
local myHits: { [number]: boolean } = {} -- notes the server judged a hit for me (hidden from my lanes)

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function elapsed(): number
	return Workspace:GetServerTimeNow() - state.startAt
end

local function myView(): CardioRhythmRemotes.RunnerView?
	for _, runner in ipairs(state.runners) do
		if runner.userId == localPlayer.UserId then
			return runner
		end
	end
	return nil
end

local function playing(): boolean
	local me = myView()
	return me ~= nil and not me.out and (state.phase == "Countdown" or state.phase == "Running")
end

-- ---------------------------------------------------------------- a note highway (screen and TV)

type Highway = {
	frame: Frame,
	receptors: { Frame },
	notes: { Frame },
	judgement: TextLabel,
	update: (self: Highway, t: number, hide: { [number]: boolean }?) -> (),
	flash: (self: Highway, lane: number, colour: Color3?) -> (),
}

local function corner(parent: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, colour: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = FONT
	l.TextScaled = true
	l.TextColor3 = colour or WHITE
	l.Text = text
	l.Parent = parent
	return l
end

local function newHighway(parent: GuiObject, showKeys: boolean): Highway
	local frame = Instance.new("Frame")
	frame.Name = "Highway"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(8, 10, 20)
	frame.BackgroundTransparency = 0.15
	frame.ClipsDescendants = true
	frame.Parent = parent
	corner(frame, 0.04)
	local lanes = Config.Lanes
	local receptors: { Frame } = {}
	for lane = 1, lanes do
		local strip = Instance.new("Frame")
		strip.Name = "Lane_" .. lane
		strip.Size = UDim2.new(1 / lanes, -4, 1, 0)
		strip.Position = UDim2.new((lane - 1) / lanes, 2, 0, 0)
		strip.BackgroundColor3 = Config.LaneColours[lane]
		strip.BackgroundTransparency = 0.9
		strip.BorderSizePixel = 0
		strip.Parent = frame
		local receptor = Instance.new("Frame")
		receptor.Name = "Receptor_" .. lane
		receptor.AnchorPoint = Vector2.new(0.5, 0.5)
		receptor.Size = UDim2.fromScale(0.7 / lanes, 0.7 / lanes)
		receptor.SizeConstraint = Enum.SizeConstraint.RelativeXX
		receptor.Position = UDim2.fromScale((lane - 0.5) / lanes, HIT_LINE)
		receptor.BackgroundColor3 = Config.LaneColours[lane]
		receptor.BackgroundTransparency = 0.75
		receptor.Parent = frame
		corner(receptor, 0.5)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Config.LaneColours[lane]
		stroke.Thickness = 3
		stroke.Parent = receptor
		if showKeys then
			label(receptor, "Key", Config.LaneLabels[lane], UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.2, 0.2))
		end
		receptors[lane] = receptor
	end
	local line = Instance.new("Frame")
	line.Name = "HitLine"
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Size = UDim2.new(1, 0, 0, 2)
	line.Position = UDim2.fromScale(0, HIT_LINE)
	line.BackgroundColor3 = WHITE
	line.BackgroundTransparency = 0.6
	line.BorderSizePixel = 0
	line.Parent = frame
	local notes: { Frame } = {}
	for k = 1, NOTE_POOL do
		local note = Instance.new("Frame")
		note.Name = "Note_" .. k
		note.AnchorPoint = Vector2.new(0.5, 0.5)
		note.Size = UDim2.fromScale(0.62 / lanes, 0.62 / lanes)
		note.SizeConstraint = Enum.SizeConstraint.RelativeXX
		note.Visible = false
		note.ZIndex = 3
		note.Parent = frame
		corner(note, 0.5)
		local shine = Instance.new("UIStroke")
		shine.Color = WHITE
		shine.Thickness = 2
		shine.Parent = note
		notes[k] = note
	end
	local judgement = label(frame, "Judgement", "", UDim2.fromScale(1, 0.08), UDim2.fromScale(0, HIT_LINE - 0.2))
	judgement.ZIndex = 4

	local highway = {} :: Highway
	highway.frame, highway.receptors, highway.notes, highway.judgement = frame, receptors, notes, judgement
	function highway.update(self: Highway, t: number, hide: { [number]: boolean }?)
		local used = 0
		local list = chart.notes
		-- From a little past the line up to the longest fall time ahead.
		local index = RhythmChart.firstFrom(list, t - 0.25)
		while index <= #list and used < NOTE_POOL do
			local note = list[index]
			local fall = Config.fallSecondsFor(note.level)
			local ahead = note.time - t
			if ahead > Config.FallSecondsStart then
				break
			end
			if ahead <= fall and not (hide and hide[note.index]) then
				used += 1
				local frameNote = self.notes[used]
				frameNote.BackgroundColor3 = Config.LaneColours[note.lane]
				frameNote.Position = UDim2.fromScale((note.lane - 0.5) / Config.Lanes, HIT_LINE - HIT_LINE * ahead / fall)
				frameNote.Visible = true
			end
			index += 1
		end
		for k = used + 1, NOTE_POOL do
			self.notes[k].Visible = false
		end
		for lane, receptor in ipairs(self.receptors) do
			receptor.BackgroundTransparency = math.min(0.75, receptor.BackgroundTransparency + 0.06)
			if receptor.BackgroundTransparency >= 0.75 then
				receptor.BackgroundColor3 = Config.LaneColours[lane]
			end
		end
	end
	function highway.flash(self: Highway, lane: number, colour: Color3?)
		local receptor = self.receptors[lane]
		if receptor then
			receptor.BackgroundTransparency = 0.05
			receptor.BackgroundColor3 = colour or Config.LaneColours[lane]
		end
	end
	return highway
end

-- ---------------------------------------------------------------- your screen

type Screen = { gui: ScreenGui, highway: Highway, status: TextLabel, healthFill: Frame, big: TextLabel }
local screen: Screen? = nil

local function sendPress(lane: number)
	local s = screen
	if s then
		s.highway:flash(lane)
	end
	if state.phase == "Running" then
		remotes.press:FireServer(lane)
	end
end

local function buildScreen(): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "CardioRhythm"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	-- In the middle of the screen (user 2026-10-26: "make the minigame pop up in the middle of the screen").
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.3, 0.72)
	panel.BackgroundTransparency = 1
	panel.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 0.72
	ratio.Parent = panel
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.Size = UDim2.fromScale(1, 0.12)
	top.BackgroundColor3 = PANEL_BACK
	top.BackgroundTransparency = 0.1
	top.Parent = panel
	corner(top, 0.2)
	local status = label(top, "Status", "", UDim2.fromScale(0.94, 0.5), UDim2.fromScale(0.03, 0.04))
	local healthBack = Instance.new("Frame")
	healthBack.Name = "Health"
	healthBack.Size = UDim2.fromScale(0.94, 0.28)
	healthBack.Position = UDim2.fromScale(0.03, 0.62)
	healthBack.BackgroundColor3 = Color3.fromRGB(50, 54, 70)
	healthBack.Parent = top
	corner(healthBack, 0.5)
	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = Color3.fromRGB(80, 214, 110)
	healthFill.Parent = healthBack
	corner(healthFill, 0.5)
	local holder = Instance.new("Frame")
	holder.Name = "Lanes"
	holder.Size = UDim2.fromScale(1, 0.86)
	holder.Position = UDim2.fromScale(0, 0.14)
	holder.BackgroundTransparency = 1
	holder.Parent = panel
	local highway = newHighway(holder, true)
	local big = label(holder, "Big", "", UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.3))
	big.ZIndex = 5
	-- Phones: tap a lane.
	for lane = 1, Config.Lanes do
		local button = Instance.new("TextButton")
		button.Name = "Tap_" .. lane
		button.Text = ""
		button.BackgroundTransparency = 1
		button.Size = UDim2.fromScale(1 / Config.Lanes, 1)
		button.Position = UDim2.fromScale((lane - 1) / Config.Lanes, 0)
		button.ZIndex = 6
		button.Visible = UserInputService.TouchEnabled
		button.Parent = holder
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				sendPress(lane)
			end
		end)
	end
	return { gui = gui, highway = highway, status = status, healthFill = healthFill, big = big }
end

-- The lane keys only while you are playing (they do nothing else then: you stand on the treadmill).
local bound = false
local function bindKeys(on: boolean)
	if on == bound then
		return
	end
	bound = on
	for lane, keys in ipairs(Config.LaneKeys) do
		local name = ACTION_PREFIX .. lane
		if on then
			ContextActionService:BindActionAtPriority(name, function(_, inputState)
				if inputState == Enum.UserInputState.Begin then
					sendPress(lane)
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value + 20, table.unpack(keys))
		else
			ContextActionService:UnbindAction(name)
		end
	end
end

-- ---------------------------------------------------------------- the wall TV

type Tv = { part: BasePart, gui: SurfaceGui, highway: Highway, title: TextLabel, info: TextLabel, list: Frame }
local tv: Tv? = nil

local function findTvPart(): BasePart?
	local gym = Workspace:FindFirstChild("StarterGym")
	local props = gym and gym:FindFirstChild("Props")
	local cardio = props and props:FindFirstChild("Cardio")
	local part = cardio and cardio:FindFirstChild("TV")
	return if part and part:IsA("BasePart") then part else nil
end

-- The TV's face that looks into the room.
local function roomFace(part: BasePart): Enum.NormalId
	local gym = Workspace:FindFirstChild("StarterGym")
	local rooms = gym and gym:FindFirstChild("Rooms")
	local room = rooms and rooms:FindFirstChild("Room_Cardio")
	local toward = if room and room:IsA("BasePart") then (room.Position - part.Position) * Vector3.new(1, 0, 1) else -part.CFrame.LookVector
	local best, bestDot = Enum.NormalId.Front, -math.huge
	for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
		local dot = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)):Dot(toward)
		if dot > bestDot then
			best, bestDot = face, dot
		end
	end
	return best
end

local function buildTv(part: BasePart): Tv
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CardioRhythmTV"
	gui.Adornee = part
	gui.Face = roomFace(part)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = PANEL_BACK
	back.Parent = gui
	local lanes = Instance.new("Frame")
	lanes.Name = "Lanes"
	lanes.Size = UDim2.fromScale(0.36, 0.9)
	lanes.Position = UDim2.fromScale(0.03, 0.05)
	lanes.BackgroundTransparency = 1
	lanes.Parent = back
	local highway = newHighway(lanes, false)
	local title = label(back, "Title", "RHYTHM RUN", UDim2.fromScale(0.55, 0.16), UDim2.fromScale(0.42, 0.04))
	local info = label(back, "Info", "", UDim2.fromScale(0.55, 0.12), UDim2.fromScale(0.42, 0.22),
		Color3.fromRGB(255, 196, 40))
	local list = Instance.new("Frame")
	list.Name = "Runners"
	list.Size = UDim2.fromScale(0.55, 0.58)
	list.Position = UDim2.fromScale(0.42, 0.38)
	list.BackgroundTransparency = 1
	list.Parent = back
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.03, 0)
	layout.Parent = list
	return { part = part, gui = gui, highway = highway, title = title, info = info, list = list }
end

local function showRunners(t: Tv)
	for _, child in ipairs(t.list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for k, runner in ipairs(state.runners) do
		if k > 4 then
			break
		end
		local row = Instance.new("Frame")
		row.Name = "Runner_" .. k
		row.Size = UDim2.fromScale(1, 0.22)
		row.BackgroundTransparency = 1
		row.Parent = t.list
		local text = if state.phase == "Results" or runner.out
			then string.format("%s   %s%s", runner.name, formatTime(runner.seconds), if runner.out and state.phase ~= "Results" then "  OUT" else "")
			else runner.name
		label(row, "Name", text, UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0), if runner.out then Color3.fromRGB(170, 176, 196) else WHITE)
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, 0.3)
		bar.Position = UDim2.fromScale(0, 0.62)
		bar.BackgroundColor3 = Color3.fromRGB(50, 54, 70)
		bar.Parent = row
		corner(bar, 0.5)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(runner.health / Config.StartHealth, 1)
		fill.BackgroundColor3 = Config.LaneColours[(k - 1) % Config.Lanes + 1]
		fill.Parent = bar
		corner(fill, 0.5)
	end
end

-- ---------------------------------------------------------------- the beat

local sounds: { [string]: Sound } = {}
local beatPointer = 1
local lastCount = -1

-- The beat plays from the TV (heard around the room); your own hit, miss and countdown sounds play in your
-- ears (SoundService: not placed in the world).
local PERSONAL = { Hit = true, Miss = true, Count = true }

local function makeSounds(part: BasePart)
	for name, id in pairs(Config.Sounds) do
		if id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = "Rhythm" .. name
			sound.SoundId = id
			sound.Volume = if name == "Hat" then 0.35 elseif PERSONAL[name] then 0.5 else 0.7
			sound.RollOffMaxDistance = 70
			sound.Parent = if PERSONAL[name] then SoundService else part
			sounds[name] = sound
		end
	end
end

local function play(name: string)
	local sound = sounds[name]
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

local function playBeat(t: number)
	local beats = chart.beats
	while beatPointer <= #beats and beats[beatPointer].time <= t do
		local beat = beats[beatPointer]
		beatPointer += 1
		if t - beat.time < 0.1 then -- never a burst of old beats after a hitch
			if beat.half then
				if beat.level >= 2 then
					play("Hat")
				end
			else
				play(if beat.number % 2 == 0 then "Snare" else "Kick")
			end
		end
	end
end

-- ---------------------------------------------------------------- every frame

local function render()
	local t = elapsed()
	local level = Config.levelAt(math.max(0, t))
	local me = myView()

	local s = screen
	if s then
		local show = me ~= nil and state.phase ~= "Idle"
		s.gui.Enabled = show
		if show and me then
			-- Once you are out your lanes stop (the notes would run on with nothing to do).
			s.highway:update(if me.out or state.phase == "Results" then -math.huge else t, myHits)
			s.healthFill.Size = UDim2.fromScale(me.health / Config.StartHealth, 1)
			if state.phase == "Countdown" then
				s.big.Text = tostring(math.max(1, math.ceil(state.startAt - Workspace:GetServerTimeNow())))
				s.status.Text = "GET READY"
			elseif state.phase == "Running" and not me.out then
				s.big.Text = ""
				s.status.Text = string.format("LEVEL %d   %s", level, formatTime(t))
			else
				s.big.Text = "OUT"
				s.status.Text = string.format("You survived %s", formatTime(me.seconds))
			end
		end
	end
	bindKeys(playing())

	local screenTv = tv
	if screenTv then
		local active = state.phase ~= "Idle"
		screenTv.gui.Enabled = active
		local writing = screenTv.part:FindFirstChild("Writing")
		if writing and writing:IsA("SurfaceGui") then
			writing.Enabled = not active
		end
		if active then
			screenTv.highway:update(t, nil)
			if state.phase == "Countdown" then
				screenTv.info.Text = string.format("STARTING IN %d", math.max(1, math.ceil(state.startAt - Workspace:GetServerTimeNow())))
			elseif state.phase == "Running" then
				screenTv.info.Text = string.format("LEVEL %d   %s", level, formatTime(t))
			else
				screenTv.info.Text = "RESULTS"
			end
		end
	end

	if state.phase == "Running" then
		playBeat(t)
	elseif state.phase == "Countdown" then
		local left = math.ceil(state.startAt - Workspace:GetServerTimeNow())
		if left ~= lastCount and left >= 1 and left <= 3 then
			play("Count")
		end
		lastCount = left
	end
end

local function onState(newState: CardioRhythmRemotes.State)
	if typeof(newState) ~= "table" then
		return
	end
	if newState.seed ~= chartSeed then
		chartSeed = newState.seed
		chart = RhythmChart.generate(newState.seed)
		myHits = {}
		beatPointer = 1
	end
	state = newState
	local t = tv
	if t then
		showRunners(t)
	end
end

local function onJudged(userId: number, index: number, result: string)
	local hit = result == "Perfect" or result == "Good"
	local note = chart.notes[index]
	local t = tv
	if t and note and hit then
		t.highway:flash(note.lane)
	end
	if userId ~= localPlayer.UserId then
		return
	end
	local s = screen
	if hit then
		myHits[index] = true
		play("Hit")
	elseif result == "Miss" or result == "Stray" then
		play("Miss")
	end
	if s then
		s.highway.judgement.Text = if result == "Stray" then "MISS" else string.upper(result)
		s.highway.judgement.TextColor3 = if result == "Perfect" then Color3.fromRGB(255, 196, 40)
			elseif result == "Good" then Color3.fromRGB(80, 214, 110)
			else Color3.fromRGB(255, 112, 92)
		if note and hit then
			s.highway:flash(note.lane, WHITE)
		end
	end
end

function CardioRhythmController.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		remotes = CardioRhythmRemotes.waitForClient(ReplicatedStorage)
		remotes.state.OnClientEvent:Connect(onState)
		remotes.judged.OnClientEvent:Connect(onJudged)
		screen = buildScreen()
		-- The gym is built by the server at start-up; wait for its TV.
		local part: BasePart? = nil
		for _ = 1, 120 do
			part = findTvPart()
			if part then
				break
			end
			task.wait(1)
		end
		if part then
			tv = buildTv(part)
			makeSounds(part)
			local t = tv :: Tv
			showRunners(t)
		end
		RunService.RenderStepped:Connect(render)
	end)
end

return CardioRhythmController
