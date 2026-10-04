--!strict
--[[
	ControlUI
	Client / Lifting

	Draws the control phase and steps its simulation for display.

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
local Simulation = require(LiftingFolder:WaitForChild("ControlSimulation"))

local ControlUI = {}

-- The challenge arrives across a remote, so it is a plain table here.
type ControlChallengeType = any

-- Presentation only. None of this affects the simulation.
local TRACK_WIDTH = 96
local TRACK_SCREEN_HEIGHT = 400
local MARKER_THICKNESS = 6
local METER_WIDTH = 26
local METER_GAP = 18

local COLOR_TRACK = Color3.fromRGB(32, 35, 42)
local COLOR_BAR = Color3.fromRGB(240, 244, 250)
local COLOR_MARKER_IN = Color3.fromRGB(96, 214, 128)
local COLOR_MARKER_OUT = Color3.fromRGB(240, 92, 92)
local COLOR_METER_FILL = Color3.fromRGB(64, 156, 255)
local COLOR_METER_BACK = Color3.fromRGB(26, 29, 35)
local COLOR_TEXT = Color3.fromRGB(226, 232, 240)
local COLOR_PASS = Color3.fromRGB(96, 214, 128)
local COLOR_FAIL = Color3.fromRGB(240, 92, 92)

export type Reporter = (clickTimes: { number }) -> ()

type Visuals = {
	gui: ScreenGui,
	track: Frame,
	bar: Frame,
	marker: Frame,
	meterFill: Frame,
	headline: TextLabel,
	instruction: TextLabel,
	detail: TextLabel,
	readout: TextLabel,
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
local reporter: Reporter? = nil
local finished = true

local function build(instructionText: string): Visuals
	local gui = Instance.new("ScreenGui")
	gui.Name = "ControlUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(TRACK_WIDTH + METER_GAP + METER_WIDTH, TRACK_SCREEN_HEIGHT)
	root.BackgroundTransparency = 1
	root.Parent = gui

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0, 0)
	track.Position = UDim2.fromOffset(0, 0)
	track.Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_SCREEN_HEIGHT)
	track.BackgroundColor3 = COLOR_TRACK
	track.BorderSizePixel = 0
	track.Parent = root

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 8)
	trackCorner.Parent = track

	-- The player's bar. Position and height are set per challenge.
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Size = UDim2.fromOffset(TRACK_WIDTH - 10, 80)
	bar.BackgroundColor3 = COLOR_BAR
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel = 0
	bar.ZIndex = 2
	bar.Parent = track

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = bar

	-- The success marker. Green while inside the bar, red while outside.
	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Size = UDim2.fromOffset(TRACK_WIDTH + 14, MARKER_THICKNESS)
	marker.BackgroundColor3 = COLOR_MARKER_IN
	marker.BorderSizePixel = 0
	marker.ZIndex = 4
	marker.Parent = track

	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(0, 3)
	markerCorner.Parent = marker

	-- Progress meter, filling from the bottom.
	local meterBack = Instance.new("Frame")
	meterBack.Name = "MeterBack"
	meterBack.Position = UDim2.fromOffset(TRACK_WIDTH + METER_GAP, 0)
	meterBack.Size = UDim2.fromOffset(METER_WIDTH, TRACK_SCREEN_HEIGHT)
	meterBack.BackgroundColor3 = COLOR_METER_BACK
	meterBack.BorderSizePixel = 0
	meterBack.Parent = root

	local meterBackCorner = Instance.new("UICorner")
	meterBackCorner.CornerRadius = UDim.new(0, 6)
	meterBackCorner.Parent = meterBack

	local meterFill = Instance.new("Frame")
	meterFill.Name = "MeterFill"
	meterFill.AnchorPoint = Vector2.new(0, 1)
	meterFill.Position = UDim2.fromScale(0, 1)
	meterFill.Size = UDim2.new(1, 0, 0, 0)
	meterFill.BackgroundColor3 = COLOR_METER_FILL
	meterFill.BorderSizePixel = 0
	meterFill.Parent = meterBack

	local meterFillCorner = Instance.new("UICorner")
	meterFillCorner.CornerRadius = UDim.new(0, 6)
	meterFillCorner.Parent = meterFill

	local headline = Instance.new("TextLabel")
	headline.Name = "Headline"
	headline.AnchorPoint = Vector2.new(0.5, 1)
	headline.Position = UDim2.new(0.5, 0, 0, -58)
	headline.Size = UDim2.fromOffset(320, 32)
	headline.BackgroundTransparency = 1
	headline.Font = Enum.Font.GothamBold
	headline.TextSize = 26
	headline.TextColor3 = COLOR_TEXT
	headline.Text = ""
	headline.Parent = root

	local instruction = Instance.new("TextLabel")
	instruction.Name = "Instruction"
	instruction.AnchorPoint = Vector2.new(0.5, 1)
	instruction.Position = UDim2.new(0.5, 0, 0, -36)
	instruction.Size = UDim2.fromOffset(460, 20)
	instruction.BackgroundTransparency = 1
	instruction.Font = Enum.Font.GothamMedium
	instruction.TextSize = 13
	instruction.TextColor3 = Color3.fromRGB(150, 160, 175)
	instruction.Text = instructionText
	instruction.Parent = root

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.AnchorPoint = Vector2.new(0.5, 0)
	detail.Position = UDim2.new(0.5, 0, 1, 14)
	detail.Size = UDim2.fromOffset(460, 20)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 14
	detail.TextColor3 = Color3.fromRGB(176, 184, 196)
	detail.Text = ""
	detail.Parent = root

	local readout = Instance.new("TextLabel")
	readout.Name = "Readout"
	readout.AnchorPoint = Vector2.new(0.5, 0)
	readout.Position = UDim2.new(0.5, 0, 1, 36)
	readout.Size = UDim2.fromOffset(460, 20)
	readout.BackgroundTransparency = 1
	readout.Font = Enum.Font.Code
	readout.TextSize = 13
	readout.TextColor3 = Color3.fromRGB(140, 150, 165)
	readout.Text = ""
	readout.Parent = root

	local verdict = Instance.new("TextLabel")
	verdict.Name = "Verdict"
	verdict.AnchorPoint = Vector2.new(0.5, 0.5)
	verdict.Position = UDim2.fromScale(0.5, 0.86)
	verdict.Size = UDim2.fromOffset(560, 40)
	verdict.BackgroundTransparency = 1
	verdict.Font = Enum.Font.GothamBold
	verdict.TextSize = 28
	verdict.TextColor3 = COLOR_TEXT
	verdict.Text = ""
	verdict.Parent = gui

	return {
		gui = gui,
		track = track,
		bar = bar,
		marker = marker,
		meterFill = meterFill,
		headline = headline,
		instruction = instruction,
		detail = detail,
		readout = readout,
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

	current.bar.Size = UDim2.fromOffset(TRACK_WIDTH - 10, challenge.barHeightPx * scale)
	current.bar.Position = UDim2.new(0.5, 0, 0, toScreenY(challenge, state.barPosition))

	current.marker.Position = UDim2.new(0.5, 0, 0, toScreenY(challenge, state.markerPosition))
	current.marker.BackgroundColor3 = if state.effectiveInside then COLOR_MARKER_IN else COLOR_MARKER_OUT

	local fraction = math.clamp(state.progress / challenge.maxProgress, 0, 1)
	current.meterFill.Size = UDim2.new(1, 0, fraction, 0)

	current.readout.Text = string.format(
		"progress %5.1f / 100     on target %.2fs / %.2fs     clicks %d",
		state.progress,
		state.timeInsideSeconds,
		state.elapsedSeconds,
		state.clicksApplied
	)
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
]]
function ControlUI.registerImpulse()
	if finished or activeChallenge == nil then
		return
	end
	local time = os.clock() - phaseClock
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
	reporter = report
	finished = false

	current.headline.Text = challenge.displayName
	current.detail.Text = string.format(
		"%.1f kg  -  %.0f%%  -  difficulty %.0f  -  hold %.1fs",
		challenge.attemptWeightKg,
		challenge.intensityPercent,
		challenge.baseDifficulty,
		challenge.holdDurationSeconds
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
	right and the difference is a bug worth knowing about.
]]
function ControlUI.showVerdict(verdictText: string, passed: boolean, detailLine: string?)
	local current = visuals
	if current == nil then
		return
	end

	finished = true
	stopStepping()

	current.verdict.TextColor3 = if passed then COLOR_PASS else COLOR_FAIL
	current.verdict.Text = verdictText

	if detailLine then
		current.readout.Text = detailLine
	end

	task.delay(2.5, function()
		local still = visuals
		if still ~= nil and still.verdict.Text == verdictText then
			still.gui.Enabled = false
			still.verdict.Text = ""
		end
	end)
end

--[[
	True while a phase is on screen.
]]
function ControlUI.isRunning(): boolean
	return not finished
end

return ControlUI
