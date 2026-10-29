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

	The look is built from UIStyle (GAME_DESIGN.md "One UI style for the whole
	game": yellow, white and dark navy with a faint grid):
	  Your screen: one navy panel in the middle of the screen with a "TREADMILL"
	  title tag; the level (white) and your time (yellow) at the top, a segmented
	  health bar (one segment per miss; red when low), four dark lanes with a thin
	  white edge, a yellow hit line, white note slabs edged in their lane's
	  colour, and a key cap under each lane (white key, ink letter, lane-coloured
	  base). PERFECT pops in yellow, GOOD in white, MISS in red.
	  The TV: the same panel filling the screen, the lanes on the left, a
	  "RHYTHM RUN" tag, the countdown / level / RESULTS line in yellow and one row
	  per runner (name, time, health bar or OUT).

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

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours
local TEXT = UIStyle.TextSizes

local CardioRhythmController = {}

local localPlayer = Players.LocalPlayer
local started = false
local HIT_LINE = 0.86 -- the line's height in a lane, from the top (0) to the bottom (1)
local NOTE_POOL = 48
local ACTION_PREFIX = "CardioRhythmLane"

-- How the lanes look. Presentation only: the note's height on screen is still HIT_LINE * (1 - ahead / fall).
local NOTE_WIDTH = 0.8 -- a note slab's width, as a share of its lane
local NOTE_THICKNESS = 0.3 -- a note slab's height, as a share of its width
local RECEPTOR_WIDTH = 0.92 -- the target slab on the hit line, as a share of its lane
local RECEPTOR_REST = 0.75 -- the target slab's resting transparency (a press or hit flashes it solid)
local JUDGE_POP = 0.35 -- PERFECT / GOOD / MISS starts this much bigger...
local JUDGE_POP_SECONDS = 0.12 -- ...and settles in this time
local LOW_HEALTH = 0.3 -- health bars turn red at or below this share

-- Your screen's panel, in pixels (UIStyle.fitToScreen shrinks it on short screens).
local PANEL_WIDTH = 420
local PANEL_HEIGHT = 584
local PAD = 20
local HEADER_Y = 34
local HEADER_HEIGHT = 32
local HEALTH_Y = 78
local HEALTH_HEIGHT = 18
local HEALTH_LABEL_WIDTH = 88
local LANES_Y = 110
local LANES_WIDTH = PANEL_WIDTH - PAD * 2
local LANES_HEIGHT = 400
local KEYCAP_Y = LANES_Y + LANES_HEIGHT + 10
local KEYCAP_HEIGHT = 40
local KEYCAP_DEPTH = 5
local KEYCAP_WIDTH = 0.62 -- as a share of a lane
local BIG_SIZE = math.floor(TEXT.big * 1.5) -- the countdown number and OUT

-- The wall TV, in the SurfaceGui's own pixels (40 per stud: the Cardio TV is about 520 x 248).
local TV_TAG_SIZE = UDim2.fromOffset(220, 40)
local TV_INFO_SIZE = 28
local TV_ROW_SIZE = TEXT.body
local TV_ROW_HEIGHT = 26

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

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

-- A health share's colour: white, red when low, muted once out.
local function healthColour(share: number, out: boolean): Color3
	if out then
		return C.muted
	end
	return if share <= LOW_HEALTH then C.red else C.white
end

-- ---------------------------------------------------------------- a note highway (screen and TV)

type Highway = {
	frame: Frame,
	receptors: { Frame },
	notes: { Frame },
	noteEdges: { UIStroke },
	judgement: TextLabel,
	judgeScale: UIScale,
	judgedAt: number,
	update: (self: Highway, t: number, hide: { [number]: boolean }?) -> (),
	flash: (self: Highway, lane: number, colour: Color3?) -> (),
	judge: (self: Highway, text: string, colour: Color3) -> (),
}

-- `edge` is the notes' and targets' coloured edge in pixels (thinner on the small TV).
local function newHighway(parent: GuiObject, edge: number): Highway
	local frame = Instance.new("Frame")
	frame.Name = "Highway"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true
	frame.ZIndex = 1
	frame.Parent = parent
	local lanes = Config.Lanes
	local receptors: { Frame } = {}
	for lane = 1, lanes do
		-- A dark lane with a thin white edge.
		local strip = UIStyle.frame(frame, "Lane_" .. lane, UDim2.new((lane - 1) / lanes, 3, 0, 1),
			UDim2.new(1 / lanes, -6, 1, -2), C.navyDeep)
		strip.BackgroundTransparency = 0.1
		strip.ZIndex = 1
		UIStyle.stroke(strip, C.white, 1, 0.5)
		-- The target on the hit line, in the lane's colour: flashes on a press or a hit.
		local receptor = UIStyle.frame(frame, "Receptor_" .. lane, UDim2.fromScale((lane - 0.5) / lanes, HIT_LINE),
			UDim2.fromScale(RECEPTOR_WIDTH / lanes, RECEPTOR_WIDTH * NOTE_THICKNESS / lanes), Config.LaneColours[lane])
		receptor.AnchorPoint = Vector2.new(0.5, 0.5)
		receptor.SizeConstraint = Enum.SizeConstraint.RelativeXX
		receptor.BackgroundTransparency = RECEPTOR_REST
		receptor.ZIndex = 2
		corner(receptor, UDim.new(0, 6))
		UIStyle.stroke(receptor, Config.LaneColours[lane], edge)
		receptors[lane] = receptor
	end
	-- The hit line: solid yellow over a soft yellow glow.
	local glow = UIStyle.frame(frame, "HitGlow", UDim2.fromScale(0, HIT_LINE), UDim2.new(1, 0, 0, 12), C.yellow)
	glow.AnchorPoint = Vector2.new(0, 0.5)
	glow.BackgroundTransparency = 0.8
	glow.ZIndex = 3
	local line = UIStyle.frame(frame, "HitLine", UDim2.fromScale(0, HIT_LINE), UDim2.new(1, 0, 0, 4), C.yellow)
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.ZIndex = 3
	-- The notes: bold white slabs edged in their lane's colour.
	local notes: { Frame } = {}
	local noteEdges: { UIStroke } = {}
	for k = 1, NOTE_POOL do
		local note = UIStyle.frame(frame, "Note_" .. k, UDim2.fromScale(0, 0),
			UDim2.fromScale(NOTE_WIDTH / lanes, NOTE_WIDTH * NOTE_THICKNESS / lanes), C.white)
		note.AnchorPoint = Vector2.new(0.5, 0.5)
		note.SizeConstraint = Enum.SizeConstraint.RelativeXX
		note.Visible = false
		note.ZIndex = 4
		corner(note, UDim.new(0, 5))
		notes[k] = note
		noteEdges[k] = UIStyle.stroke(note, C.white, edge)
	end
	-- PERFECT / GOOD / MISS, just above the line.
	local judgement = UIStyle.text(frame, "Judgement", UDim2.fromScale(0.5, HIT_LINE - 0.16), UDim2.new(1, 0, 0, 56),
		TEXT.big, C.white, UIStyle.heading(), Enum.TextXAlignment.Center)
	judgement.AnchorPoint = Vector2.new(0.5, 0.5)
	judgement.TextWrapped = false
	judgement.ZIndex = 6
	UIStyle.stroke(judgement, C.ink, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local judgeScale = Instance.new("UIScale")
	judgeScale.Parent = judgement

	local highway = {} :: Highway
	highway.frame, highway.receptors, highway.notes, highway.noteEdges = frame, receptors, notes, noteEdges
	highway.judgement, highway.judgeScale, highway.judgedAt = judgement, judgeScale, 0
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
				self.noteEdges[used].Color = Config.LaneColours[note.lane]
				frameNote.Position = UDim2.fromScale((note.lane - 0.5) / Config.Lanes, HIT_LINE - HIT_LINE * ahead / fall)
				frameNote.Visible = true
			end
			index += 1
		end
		for k = used + 1, NOTE_POOL do
			self.notes[k].Visible = false
		end
		for lane, receptor in ipairs(self.receptors) do
			receptor.BackgroundTransparency = math.min(RECEPTOR_REST, receptor.BackgroundTransparency + 0.06)
			if receptor.BackgroundTransparency >= RECEPTOR_REST then
				receptor.BackgroundColor3 = Config.LaneColours[lane]
			end
		end
		local settled = math.clamp((os.clock() - self.judgedAt) / JUDGE_POP_SECONDS, 0, 1)
		self.judgeScale.Scale = 1 + JUDGE_POP * (1 - settled)
	end
	function highway.flash(self: Highway, lane: number, colour: Color3?)
		local receptor = self.receptors[lane]
		if receptor then
			receptor.BackgroundTransparency = 0.05
			receptor.BackgroundColor3 = colour or Config.LaneColours[lane]
		end
	end
	function highway.judge(self: Highway, text: string, colour: Color3)
		self.judgement.Text = text
		self.judgement.TextColor3 = colour
		self.judgedAt = os.clock()
	end
	return highway
end

-- ---------------------------------------------------------------- your screen

type Screen = {
	gui: ScreenGui,
	highway: Highway,
	status: TextLabel,
	clock: TextLabel,
	healthFill: Frame,
	big: TextLabel,
}
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
	UIStyle.fitToScreen(gui) -- shrink on short screens so nothing overlaps
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	-- In the middle of the screen (user 2026-10-26: "make the minigame pop up in the middle of the screen"),
	-- anchored at its centre like every minigame (UIStyle.MinigameCentre).
	local holder, body = UIStyle.panel(gui, "Panel", UIStyle.MinigameCentre, UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UIStyle.MinigameCentre
	UIStyle.titleTag(holder, "Tag", "TREADMILL", UDim2.fromOffset(-14, -24), UDim2.fromOffset(260, 44))

	-- The level (or GET READY / YOU SURVIVED) on the left, the time on the right.
	local status = UIStyle.text(body, "Status", UDim2.fromOffset(PAD, HEADER_Y), UDim2.fromOffset(260, HEADER_HEIGHT),
		TEXT.heading, C.white, UIStyle.heading(), Enum.TextXAlignment.Left)
	status.ZIndex = 3
	local clock = UIStyle.text(body, "Clock", UDim2.fromOffset(PANEL_WIDTH - PAD - 120, HEADER_Y),
		UDim2.fromOffset(120, HEADER_HEIGHT), TEXT.heading, C.yellow, UIStyle.heading(), Enum.TextXAlignment.Right)
	clock.ZIndex = 3

	-- Health: a bar split into one segment per miss.
	local healthLabel = UIStyle.text(body, "HealthLabel", UDim2.fromOffset(PAD, HEALTH_Y - 1),
		UDim2.fromOffset(HEALTH_LABEL_WIDTH - 4, HEALTH_HEIGHT + 2), TEXT.small, C.muted, UIStyle.font(Enum.FontWeight.Bold))
	healthLabel.Text = "HEALTH"
	healthLabel.ZIndex = 3
	local healthBack = UIStyle.frame(body, "Health", UDim2.fromOffset(PAD + HEALTH_LABEL_WIDTH, HEALTH_Y),
		UDim2.fromOffset(LANES_WIDTH - HEALTH_LABEL_WIDTH, HEALTH_HEIGHT), C.empty)
	healthBack.ZIndex = 3
	UIStyle.stroke(healthBack, C.white, 1, 0.4)
	local healthFill = UIStyle.frame(healthBack, "Fill", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), C.white)
	healthFill.ZIndex = 1
	local segments = if Config.MissCost > 0 then math.floor(Config.StartHealth / Config.MissCost) else 1
	for k = 1, segments - 1 do
		local gap = UIStyle.frame(healthBack, "Gap_" .. k, UDim2.new(k / segments, -1, 0, 0), UDim2.new(0, 2, 1, 0),
			C.navyDeep)
		gap.ZIndex = 2
	end

	-- The lanes.
	local lanesHolder = Instance.new("Frame")
	lanesHolder.Name = "Lanes"
	lanesHolder.Position = UDim2.fromOffset(PAD, LANES_Y)
	lanesHolder.Size = UDim2.fromOffset(LANES_WIDTH, LANES_HEIGHT)
	lanesHolder.BackgroundTransparency = 1
	lanesHolder.ZIndex = 2
	lanesHolder.Parent = body
	local highway = newHighway(lanesHolder, 3)
	local big = UIStyle.text(lanesHolder, "Big", UDim2.fromScale(0.5, 0.4), UDim2.new(1, 0, 0, BIG_SIZE + 16), BIG_SIZE,
		C.white, UIStyle.heading(), Enum.TextXAlignment.Center)
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.TextWrapped = false
	big.ZIndex = 5
	UIStyle.stroke(big, C.ink, 4).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- A key cap under each lane: a white key with the letter, on a base in the lane's colour.
	local laneWidth = LANES_WIDTH / Config.Lanes
	for lane = 1, Config.Lanes do
		local keyCap = Instance.new("Frame")
		keyCap.Name = "Key_" .. lane
		keyCap.AnchorPoint = Vector2.new(0.5, 0)
		keyCap.Position = UDim2.fromOffset(PAD + (lane - 0.5) * laneWidth, KEYCAP_Y)
		keyCap.Size = UDim2.fromOffset(math.floor(laneWidth * KEYCAP_WIDTH), KEYCAP_HEIGHT + KEYCAP_DEPTH)
		keyCap.BackgroundTransparency = 1
		keyCap.ZIndex = 3
		keyCap.Parent = body
		local base = UIStyle.frame(keyCap, "Base", UDim2.fromOffset(0, KEYCAP_DEPTH), UDim2.new(1, 0, 0, KEYCAP_HEIGHT),
			Config.LaneColours[lane])
		base.ZIndex = 1
		corner(base, UDim.new(0, 8))
		local face = UIStyle.frame(keyCap, "Face", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, KEYCAP_HEIGHT), C.white)
		face.ZIndex = 2
		corner(face, UDim.new(0, 8))
		UIStyle.stroke(face, C.ink, 2)
		local letter = UIStyle.text(face, "Letter", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), TEXT.heading, C.ink,
			UIStyle.heading(), Enum.TextXAlignment.Center)
		letter.Text = Config.LaneLabels[lane]
		letter.ZIndex = 2
	end

	-- Phones: tap a lane (its whole column, key cap included).
	for lane = 1, Config.Lanes do
		local button = Instance.new("TextButton")
		button.Name = "Tap_" .. lane
		button.Text = ""
		button.BackgroundTransparency = 1
		button.Size = UDim2.fromOffset(laneWidth, KEYCAP_Y + KEYCAP_HEIGHT + KEYCAP_DEPTH - LANES_Y)
		button.Position = UDim2.fromOffset(PAD + (lane - 1) * laneWidth, LANES_Y)
		button.ZIndex = 10
		button.Visible = UserInputService.TouchEnabled
		button.Parent = body
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				sendPress(lane)
			end
		end)
	end
	return { gui = gui, highway = highway, status = status, clock = clock, healthFill = healthFill, big = big }
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
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local back = UIStyle.frame(gui, "Back", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), C.navyDeep)
	-- The game's panel, inset so its white frame and yellow slab stay on the screen.
	local _, body = UIStyle.panel(back, "Screen", UDim2.fromOffset(6, 6), UDim2.new(1, -16, 1, -16))
	local lanes = Instance.new("Frame")
	lanes.Name = "Lanes"
	lanes.Position = UDim2.fromOffset(12, 12)
	lanes.Size = UDim2.new(0.38, -12, 1, -24)
	lanes.BackgroundTransparency = 1
	lanes.ZIndex = 2
	lanes.Parent = body
	local highway = newHighway(lanes, 2)
	local title = UIStyle.titleTag(body, "Title", "RHYTHM RUN", UDim2.new(0.42, 0, 0, 12), TV_TAG_SIZE)
	local info = UIStyle.text(body, "Info", UDim2.new(0.42, 0, 0, 62), UDim2.new(0.56, 0, 0, 34), TV_INFO_SIZE, C.yellow,
		UIStyle.heading(), Enum.TextXAlignment.Left)
	info.TextWrapped = false
	info.ZIndex = 3
	local list = Instance.new("Frame")
	list.Name = "Runners"
	list.Position = UDim2.new(0.42, 0, 0, 104)
	list.Size = UDim2.new(0.56, 0, 1, -112)
	list.BackgroundTransparency = 1
	list.ZIndex = 3
	list.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
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
		row.LayoutOrder = k
		row.Size = UDim2.new(1, 0, 0, TV_ROW_HEIGHT)
		row.BackgroundTransparency = 1
		row.Parent = t.list
		-- The name (muted once out).
		local name = UIStyle.text(row, "Name", UDim2.fromOffset(0, 0), UDim2.fromScale(0.42, 1), TV_ROW_SIZE,
			if runner.out then C.muted else C.white, UIStyle.font(Enum.FontWeight.Bold))
		name.TextWrapped = false
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = runner.name
		-- Their time, once it counts: in the results, or as soon as they are out.
		local timeLabel = UIStyle.text(row, "Time", UDim2.fromScale(0.42, 0), UDim2.fromScale(0.23, 1), TV_ROW_SIZE,
			if state.phase == "Results" then C.yellow else C.muted, UIStyle.heading(), Enum.TextXAlignment.Right)
		timeLabel.TextWrapped = false
		timeLabel.Text = if state.phase == "Results" or runner.out then formatTime(runner.seconds) else ""
		if runner.out and state.phase ~= "Results" then
			-- Out of the round: OUT in red where the health bar was.
			local out = UIStyle.text(row, "Out", UDim2.fromScale(0.68, 0), UDim2.fromScale(0.32, 1), TV_ROW_SIZE, C.red,
				UIStyle.heading(), Enum.TextXAlignment.Left)
			out.TextWrapped = false
			out.Text = "OUT"
		else
			local share = math.clamp(runner.health / Config.StartHealth, 0, 1)
			local bar = UIStyle.frame(row, "Health", UDim2.fromScale(0.68, 0.5), UDim2.new(0.32, 0, 0, 12), C.empty)
			bar.AnchorPoint = Vector2.new(0, 0.5)
			UIStyle.stroke(bar, C.white, 1, 0.4)
			UIStyle.frame(bar, "Fill", UDim2.fromOffset(0, 0), UDim2.fromScale(share, 1), healthColour(share, runner.out))
		end
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
			local share = math.clamp(me.health / Config.StartHealth, 0, 1)
			s.healthFill.Size = UDim2.fromScale(share, 1)
			s.healthFill.BackgroundColor3 = healthColour(share, false)
			if state.phase == "Countdown" then
				s.big.Text = tostring(math.max(1, math.ceil(state.startAt - Workspace:GetServerTimeNow())))
				s.big.TextColor3 = C.yellow
				s.status.Text = "GET READY"
				s.clock.Text = ""
			elseif state.phase == "Running" and not me.out then
				s.big.Text = ""
				s.status.Text = string.format("LEVEL %d", level)
				s.clock.Text = formatTime(t)
			else
				s.big.Text = "OUT"
				s.big.TextColor3 = C.red
				s.status.Text = "YOU SURVIVED"
				s.clock.Text = formatTime(me.seconds)
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
		-- PERFECT yellow, GOOD white, MISS red.
		s.highway:judge(if result == "Stray" then "MISS" else string.upper(result),
			if result == "Perfect" then C.yellow elseif result == "Good" then C.white else C.red)
		if note and hit then
			s.highway:flash(note.lane, C.white)
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
