--!strict
--[[
	ControlUI
	Client / Lifting

	Draws the control phase and steps its simulation for display.

	THE LOOK is built from UIStyle (client/UI), the one style of every screen: a
	navy panel with a title tag ("SQUAT  CONTROL //"), the track in deep navy with
	a white edge, the player's bar in the lift's colour (squat yellow), the marker
	white while it is on the bar and red while it is off it (good = white, no
	lift = red), and the verdict on a white or red slab under the panel.

	LAYOUT (user 2026-10-28: "They need to be centered, Bigger, Easier to read"):
	one composition (the title tag, the panel and the verdict slab under it)
	anchored at its own centre at (0.5, 0.52) of the screen, so it stays centred
	when fitToScreen shrinks it. Left: the track and the progress meter. Right,
	a few big plain lines: the instruction (TextSizes.body), the meter's reading
	"CONTROL 27%" (TextSizes.heading), whether the marker is ON or OFF the bar
	(in white or red, which also teaches the colours), and the attempt line
	(kg / % / difficulty, TextSizes.body). The raw testing numbers ("progress",
	"clicks", the server's "server: ..." line) show only when
	UIStyle.ShowDevReadouts is on. The verdict is TextSizes.big.

	WHAT IT OWNS AND WHAT IT DOES NOT

	It runs ControlSimulation locally so the bar responds the instant the player
	clicks, and it records the time of every click. When the local simulation
	reaches a conclusion it hands the recorded click times upward.

	It does NOT decide anything. The verdict it eventually shows is whatever the
	server sent back after replaying those same clicks. If the two ever disagree,
	the server is right and the player sees the server's answer.

	It does not read input either; ControlInput owns that, and the controller wires
	the two together.

	COORDINATES

	The simulation works in a reference track where 0 is the bottom. Screen space
	has y increasing downward, so a position maps to an offset of
	(trackHeight - position) from the track frame's top.

	FIXED TIMESTEP

	The local simulation advances on an accumulator, never on the raw frame delta,
	so it steps exactly as the server's replay will. Drawing happens at whatever
	rate the client renders at, but the physics does not.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiftingFolder = Shared:WaitForChild("Lifting")
local ConfigFolder = Shared:WaitForChild("Config")
local Simulation = require(LiftingFolder:WaitForChild("ControlSimulation"))
local ControlPhaseConfig = require(ConfigFolder:WaitForChild("ControlPhaseConfig"))
local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

-- Must match what the server enforces when it replays the reported clicks.
local MINIMUM_CLICK_GAP = 1 / ControlPhaseConfig.MaxClicksPerSecond

local ControlUI = {}

-- The challenge arrives across a remote, so it is a plain table here.
type ControlChallengeType = any

-- Presentation only. None of this affects the simulation.
--[[
	The track's on-screen size. TRACK_SCREEN_HEIGHT is the one number the
	position maths uses (toScreenY and redraw's scale both read it), and the
	track frame is built at exactly this size, so changing it stays consistent.
]]
local TRACK_WIDTH = 130
local TRACK_SCREEN_HEIGHT = 460
-- The player's bar is this much narrower than the track (build and redraw both use BAR_WIDTH).
local BAR_WIDTH = TRACK_WIDTH - 14
local MARKER_THICKNESS = 8
local MARKER_OVERHANG = 18
local METER_WIDTH = 44
local METER_GAP = 22

-- The panel around it all: the track and the meter on the left, the words in a
-- column on the right.
local PANEL_PAD = 24
local PANEL_TOP = 24
local COLUMN_GAP = 30
local COLUMN_WIDTH = 340
local COLUMN_X = PANEL_PAD + TRACK_WIDTH + METER_GAP + METER_WIDTH + COLUMN_GAP
local PANEL_WIDTH = COLUMN_X + COLUMN_WIDTH + PANEL_PAD
local PANEL_HEIGHT = PANEL_TOP + TRACK_SCREEN_HEIGHT + PANEL_TOP

-- The title tag pokes this far above the panel; the composition includes it.
local TAG_OVERHANG = 22
local TAG_WIDTH, TAG_HEIGHT = 340, 46
local VERDICT_GAP = 14
local VERDICT_HEIGHT = 64

-- The whole composition (tag + panel + verdict), anchored at its centre here.
local COMPOSITION_WIDTH = PANEL_WIDTH
local COMPOSITION_HEIGHT = TAG_OVERHANG + PANEL_HEIGHT + VERDICT_GAP + VERDICT_HEIGHT
local COMPOSITION_CENTRE = UIStyle.MinigameCentre

local SIZES = UIStyle.TextSizes

-- The control phase is the squat's; liftColourFor picks another lift's colour if
-- a phase for one is ever added.
local COLOR_LIFT_DEFAULT = UIStyle.LiftColours.Squat
local COLOR_MARKER_IN = C.white
local COLOR_MARKER_OUT = C.red
-- GOOD = white slab with black text, NO LIFT = red slab with white text.
local COLOR_PASS_SLAB = C.white
local COLOR_PASS_TEXT = C.ink
local COLOR_FAIL_SLAB = C.red
local COLOR_FAIL_TEXT = C.white

export type Reporter = (clickTimes: { number }) -> ()

type Visuals = {
	gui: ScreenGui,
	track: Frame,
	bar: Frame,
	marker: Frame,
	meterFill: Frame,
	-- The title tag's text.
	headline: TextLabel,
	instruction: TextLabel,
	-- "CONTROL 27%": the meter's reading, big.
	progress: TextLabel,
	-- "MARKER ON THE BAR" in white / "MARKER OFF THE BAR" in red.
	onBar: TextLabel,
	-- The attempt line: kg / % / difficulty.
	detail: TextLabel,
	-- Raw testing numbers; only visible when UIStyle.ShowDevReadouts is on.
	readout: TextLabel,
	verdictSlab: Frame,
	verdict: TextLabel,
}

local visuals: Visuals? = nil

-- Live phase state.
local connection: RBXScriptConnection? = nil
local activeChallenge: ControlChallengeType? = nil
local activeState: any = nil
local accumulator = 0
local pendingClicks: { number } = {}
local recordedClicks: { number } = {}
local phaseClock = 0
-- Time of the last click the rate cap allowed through, for the check in registerImpulse.
local lastAcceptedClick = -math.huge
local reporter: Reporter? = nil
local finished = true

-- A column text block: a FIXED text size (UIStyle.text, not scaled), so it stays readable and live numbers do not flicker.
local function columnText(parent: Instance, name: string, y: number, height: number, colour: Color3, textSize: number,
	font: Font, yAlign: Enum.TextYAlignment?): TextLabel
	local text = UIStyle.text(parent, name, UDim2.fromOffset(COLUMN_X, y), UDim2.fromOffset(COLUMN_WIDTH, height), textSize,
		colour, font)
	text.TextYAlignment = yAlign or Enum.TextYAlignment.Top
	text.ZIndex = 2
	return text
end

local function build(instructionText: string): Visuals
	local gui = Instance.new("ScreenGui")
	gui.Name = "ControlUI"
	UIStyle.fitToScreen(gui) -- shrink on short screens so nothing overlaps
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	--[[
		The one top-level piece: the whole composition (title tag, panel, verdict
		slab), anchored at its own centre, so fitToScreen shrinks it about the
		screen's centre and it never drifts.
	]]
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = COMPOSITION_CENTRE
	root.Size = UDim2.fromOffset(COMPOSITION_WIDTH, COMPOSITION_HEIGHT)
	root.BackgroundTransparency = 1
	root.Parent = gui

	local holder, body = UIStyle.panel(root, "Panel", UDim2.fromOffset(0, TAG_OVERHANG),
		UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	-- Its text is set per challenge ("SQUAT  CONTROL").
	local headline = UIStyle.titleTag(holder, "Tag", "", UDim2.fromOffset(-16, -TAG_OVERHANG),
		UDim2.fromOffset(TAG_WIDTH, TAG_HEIGHT), nil, "bar")

	--[[
		The track. Exactly TRACK_WIDTH x TRACK_SCREEN_HEIGHT, and the bar and the
		marker are its children positioned from its top edge, which is what
		toScreenY assumes. Nothing reads its screen position.
	]]
	local track = UIStyle.frame(body, "Track", UDim2.fromOffset(PANEL_PAD, PANEL_TOP),
		UDim2.fromOffset(TRACK_WIDTH, TRACK_SCREEN_HEIGHT), C.navyDeep)
	track.ZIndex = 2
	UIStyle.stroke(track, C.white, 2)
	-- Faint quarter lines, decoration only.
	for quarter = 1, 3 do
		local line = UIStyle.frame(track, "Quarter_" .. quarter, UDim2.new(0, 0, quarter / 4, 0), UDim2.new(1, 0, 0, 1), C.grid)
		line.BackgroundTransparency = 0.6
	end

	-- The player's bar, in the lift's colour. Position and height are set per challenge.
	local bar = UIStyle.frame(track, "Bar", UDim2.fromOffset(0, 0), UDim2.fromOffset(BAR_WIDTH, 80), COLOR_LIFT_DEFAULT)
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.BackgroundTransparency = 0.3
	bar.ZIndex = 2
	UIStyle.stroke(bar, C.white, 1, 0.2)

	-- The success marker. White while inside the bar, red while outside.
	local marker = UIStyle.frame(track, "Marker", UDim2.fromOffset(0, 0),
		UDim2.fromOffset(TRACK_WIDTH + MARKER_OVERHANG, MARKER_THICKNESS), COLOR_MARKER_IN)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.ZIndex = 4
	UIStyle.stroke(marker, C.ink, 2)

	-- Progress meter, filling from the bottom.
	local meterBack = UIStyle.frame(body, "MeterBack", UDim2.fromOffset(PANEL_PAD + TRACK_WIDTH + METER_GAP, PANEL_TOP),
		UDim2.fromOffset(METER_WIDTH, TRACK_SCREEN_HEIGHT), C.empty)
	meterBack.ZIndex = 2
	UIStyle.stroke(meterBack, C.white, 1, 0.4)

	local meterFill = UIStyle.frame(meterBack, "MeterFill", UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, 0), COLOR_LIFT_DEFAULT)
	meterFill.AnchorPoint = Vector2.new(0, 1)
	meterFill.ZIndex = 2

	--[[
		The column: a few big, plain lines, top to bottom.
			what to do                          body, white
			CONTROL 27%  (the meter's reading)  heading, the lift's colour
			MARKER ON / OFF THE BAR             body, white or red
			testing numbers (dev only)          small, grey
			the attempt (kg / % / difficulty)   body, white, at the bottom
	]]
	local instruction = columnText(body, "Instruction", PANEL_TOP, 76, C.white, SIZES.body, UIStyle.font(Enum.FontWeight.Bold))
	instruction.Text = instructionText

	local progress = columnText(body, "Progress", PANEL_TOP + 96, 34, COLOR_LIFT_DEFAULT, SIZES.heading, UIStyle.heading())

	local onBar = columnText(body, "OnBar", PANEL_TOP + 138, 28, COLOR_MARKER_IN, SIZES.body, UIStyle.font(Enum.FontWeight.Heavy))

	local readout = columnText(body, "Readout", PANEL_TOP + 186, 150, C.muted, SIZES.small, UIStyle.font(Enum.FontWeight.Medium))
	readout.Visible = UIStyle.ShowDevReadouts

	local detail = columnText(body, "Detail", PANEL_TOP + TRACK_SCREEN_HEIGHT - 60, 60, C.white, SIZES.body,
		UIStyle.font(Enum.FontWeight.Bold), Enum.TextYAlignment.Bottom)

	-- The server's verdict, on a slab under the panel. Hidden while it has no text.
	local verdictSlab = UIStyle.frame(root, "VerdictSlab", UDim2.fromOffset(0, TAG_OVERHANG + PANEL_HEIGHT + VERDICT_GAP),
		UDim2.fromOffset(PANEL_WIDTH, VERDICT_HEIGHT), COLOR_PASS_SLAB, -2)
	verdictSlab.Visible = false
	UIStyle.stroke(verdictSlab, C.white, 2)
	-- Big (TextSizes.big); only a verdict too long for the slab's width shrinks, never below TextSizes.small.
	local verdict = UIStyle.label(verdictSlab, "Verdict", UDim2.fromOffset(16, 6), UDim2.new(1, -32, 1, -12), COLOR_PASS_TEXT,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	local verdictLimit = Instance.new("UITextSizeConstraint")
	verdictLimit.MaxTextSize = SIZES.big
	verdictLimit.MinTextSize = SIZES.small
	verdictLimit.Parent = verdict
	verdict:GetPropertyChangedSignal("Text"):Connect(function()
		verdictSlab.Visible = verdict.Text ~= ""
	end)

	return {
		gui = gui,
		track = track,
		bar = bar,
		marker = marker,
		meterFill = meterFill,
		headline = headline,
		instruction = instruction,
		progress = progress,
		onBar = onBar,
		detail = detail,
		readout = readout,
		verdictSlab = verdictSlab,
		verdict = verdict,
	}
end

--[[
	Attaches the UI. Call once.
]]
function ControlUI.mount(parent: Instance, instructionText: string)
	if visuals ~= nil then
		return
	end
	local built = build(instructionText)
	built.gui.Parent = parent
	visuals = built
end

--[[
	Converts a simulation position into an offset from the track's top edge.
]]
local function toScreenY(challenge: ControlChallengeType, position: number): number
	local scale = TRACK_SCREEN_HEIGHT / challenge.trackHeightPx
	return (challenge.trackHeightPx - position) * scale
end

local function redraw()
	local current = visuals
	local challenge = activeChallenge
	local state = activeState
	if current == nil or challenge == nil or state == nil then
		return
	end

	local scale = TRACK_SCREEN_HEIGHT / challenge.trackHeightPx

	current.bar.Size = UDim2.fromOffset(BAR_WIDTH, challenge.barHeightPx * scale)
	current.bar.Position = UDim2.new(0.5, 0, 0, toScreenY(challenge, state.barPosition))

	current.marker.Position = UDim2.new(0.5, 0, 0, toScreenY(challenge, state.markerPosition))
	current.marker.BackgroundColor3 = if state.effectiveInside then COLOR_MARKER_IN else COLOR_MARKER_OUT

	local fraction = math.clamp(state.progress / challenge.maxProgress, 0, 1)
	current.meterFill.Size = UDim2.new(1, 0, fraction, 0)

	-- The plain reading of the meter, and the marker's state in its own colour.
	current.progress.Text = string.format("CONTROL  %d%%", math.floor(fraction * 100))
	current.onBar.Text = if state.effectiveInside then "MARKER ON THE BAR" else "MARKER OFF THE BAR"
	current.onBar.TextColor3 = if state.effectiveInside then COLOR_MARKER_IN else COLOR_MARKER_OUT

	-- Testing numbers: always written (as before), shown only with UIStyle.ShowDevReadouts.
	current.readout.Text = string.format(
		"progress %5.1f / 100     on target %.2fs / %.2fs     clicks %d",
		state.progress,
		state.timeInsideSeconds,
		state.elapsedSeconds,
		state.clicksApplied
	)
end

--[[
	The lift a phase belongs to, read from the front of its phase name
	("SquatControl" -> "Squat"), or nil if it names no known lift. Presentation
	only: it picks the colour of the bar and meter and the word on the title tag.
]]
local function liftOf(challenge: ControlChallengeType): string?
	local phase = challenge.phase
	if typeof(phase) ~= "string" then
		return nil
	end
	local lift = string.match(phase, "^%u%l+")
	if lift ~= nil and (UIStyle.LiftColours[lift] :: Color3?) ~= nil then
		return lift
	end
	return nil
end

local function stopStepping()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

--[[
	Records one impulse. Called by the controller when the bound action fires.

	The time is measured against the same clock the local simulation advances on,
	so what the player saw is what gets reported.

	THE RATE CAP HERE IS NOT COSMETIC. The server discards clicks closer together
	than 1 / MaxClicksPerSecond before it replays them. If the client recorded and
	simulated clicks the server then threw away, the two would diverge: a player
	mashing could watch the local meter fill and then be told the phase failed.
	Applying the same cap at the point of recording keeps the client simulating
	exactly the input the server will accept.
]]
function ControlUI.registerImpulse()
	if finished or activeChallenge == nil then
		return
	end

	local time = os.clock() - phaseClock

	if time - lastAcceptedClick < MINIMUM_CLICK_GAP then
		return
	end
	lastAcceptedClick = time

	table.insert(pendingClicks, time)
	table.insert(recordedClicks, time)
end

--[[
	Runs one challenge.

	`report` is called exactly once, with every click time recorded, as soon as the
	local simulation concludes. The server then replays those clicks and sends back
	the authoritative verdict for showVerdict.
]]
function ControlUI.run(challenge: ControlChallengeType, report: Reporter)
	local current = visuals
	if current == nil then
		return
	end

	stopStepping()

	activeChallenge = challenge
	activeState = Simulation.createState(challenge)
	accumulator = 0
	pendingClicks = {}
	recordedClicks = {}
	phaseClock = os.clock()
	lastAcceptedClick = -math.huge
	reporter = report
	finished = false

	local lift = liftOf(challenge)
	local liftColour = if lift ~= nil then UIStyle.LiftColours[lift] else COLOR_LIFT_DEFAULT
	current.bar.BackgroundColor3 = liftColour
	current.meterFill.BackgroundColor3 = liftColour
	current.progress.TextColor3 = liftColour
	current.headline.Text = if lift ~= nil
		then string.upper(lift) .. "  " .. challenge.displayName
		else challenge.displayName
	current.detail.Text = string.format(
		"%.1f kg  -  %.0f%%  -  difficulty %.0f",
		challenge.attemptWeightKg,
		challenge.intensityPercent,
		challenge.baseDifficulty
	)
	current.verdict.Text = ""
	current.gui.Enabled = true
	redraw()

	local lastClock = os.clock()

	connection = RunService.RenderStepped:Connect(function()
		if finished then
			return
		end

		local now = os.clock()
		accumulator += now - lastClock
		lastClock = now

		local dt = challenge.fixedTimestepSeconds

		--[[
			Fixed-timestep accumulator, so the local simulation steps exactly as the
			server's replay will. A cap on steps per frame stops a long hitch from
			freezing the client trying to catch up.
		]]
		local stepsThisFrame = 0
		while accumulator >= dt and activeState.outcome == "Running" and stepsThisFrame < 10 do
			local stepEnd = (activeState.elapsedSeconds + dt)

			-- Hand this step the clicks that belong inside its window.
			local clicksThisStep = 0
			local keep: { number } = {}
			for _, time in ipairs(pendingClicks) do
				if time < stepEnd then
					clicksThisStep += 1
				else
					table.insert(keep, time)
				end
			end
			pendingClicks = keep

			Simulation.step(challenge, activeState, clicksThisStep)
			accumulator -= dt
			stepsThisFrame += 1
		end

		redraw()

		if activeState.outcome ~= "Running" then
			finished = true
			stopStepping()
			local send = reporter
			reporter = nil
			if send then
				send(recordedClicks)
			end
		end
	end)
end

--[[
	Shows the server's verdict and hides the phase.

	`detailLine` carries the server's own numbers, which is worth seeing during
	tuning: if it ever disagrees with what the local readout showed, the server is
	right and the difference is a bug worth knowing about. It goes into the
	testing readout, so it is seen only with UIStyle.ShowDevReadouts on.
]]
function ControlUI.showVerdict(verdictText: string, passed: boolean, detailLine: string?)
	local current = visuals
	if current == nil then
		return
	end

	finished = true
	stopStepping()

	current.verdictSlab.BackgroundColor3 = if passed then COLOR_PASS_SLAB else COLOR_FAIL_SLAB
	current.verdict.TextColor3 = if passed then COLOR_PASS_TEXT else COLOR_FAIL_TEXT
	current.verdict.Text = verdictText

	if detailLine then
		current.readout.Text = detailLine
	end

	--[[
		This does NOT schedule its own disappearance.

		It used to hide itself 2.5 seconds after a verdict, which collided with the
		orchestrator's 0.75 second inter-phase transition: the depth check appeared
		while this UI was still on screen. Two timers, neither aware of the other.

		Whoever is sequencing the phases knows when this UI is in the way, so it
		calls hide(). See LiftAttemptController.
	]]
end

--[[
	Clears the phase from the screen immediately.

	Called by the controller, which is the only thing that knows whether another
	phase is about to need the space.
]]
function ControlUI.hide()
	local current = visuals
	if current == nil then
		return
	end

	finished = true
	stopStepping()

	current.gui.Enabled = false
	current.verdict.Text = ""
	current.readout.Text = ""
	current.headline.Text = ""
	current.detail.Text = ""
	current.progress.Text = ""
	current.onBar.Text = ""
end

--[[
	True while a phase is on screen.
]]
function ControlUI.isRunning(): boolean
	return not finished
end

return ControlUI
