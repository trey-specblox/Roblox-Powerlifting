--!strict
--[[
	PowerUI
	Client / Lifting

	Draws the circular Test Your Might power phase and steps its simulation for
	display.

	THE RADIAL MAPPING

		fraction = progress / completion threshold          clamped to 0..1
		radius   = outerRadius - (outerRadius - innerRadius) x fraction

	The outer edge is 0% complete. The inner success circle is 100% complete. That
	is the whole mental model, and there is nothing else for the player to satisfy:
	the ring touching the inner circle IS the pass condition, because `fraction`
	reaches 1 exactly when `progress` reaches `completionThreshold`, which is the
	single condition the simulation tests.

	The inner circle is therefore the SAME SIZE on every attempt. An earlier version
	mapped progress across a fixed 0-100 scale and drew the target at the threshold,
	which made a harder attempt show a visibly smaller circle. That was dropped
	deliberately: difficulty belongs in how hard the ring is to move, not in where
	the finish line is drawn. A 110% attempt is harder because progress per click is
	worth less against a longer climb, decay is fiercer and there are more holds, not
	because the target shrank.

	This is purely presentational. The authoritative model is a single progress
	value, there is no two-dimensional cursor, and nothing about the simulation
	changed to accommodate the circle.

	Circles are square frames with a 50% UICorner, so no arc segments are needed
	here, unlike the skill check's ring.

	WHEN THE RING REACHES THE SUCCESS CIRCLE IT STOPS, FOR GOOD

	Reaching the completion threshold is terminal in the simulation, so stepping halts the
	moment it happens. The ring cannot drift back out while the player waits for the
	server's verdict, because nothing is advancing it any more.

	WHAT IT OWNS AND WHAT IT DOES NOT

	It runs PowerSimulation locally so the ring moves the instant the player
	presses, and it records every input transition. When the local simulation
	concludes it hands those transitions upward.

	It does NOT decide anything. The verdict it shows is whatever the server sent
	back after reconstructing the phase from those same transitions.

	It does not read input either; the controller owns that and calls registerPress
	and registerRelease, so there is exactly one input owner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiftingFolder = Shared:WaitForChild("Lifting")
local Simulation = require(LiftingFolder:WaitForChild("PowerSimulation"))

local PowerUI = {}

-- The challenge arrives across a remote, so it is a plain table here.
type PowerChallengeType = any

--[[
	Geometry, in pixels. Presentation only.

	OUTER_RADIUS is power 0, INNER_RADIUS is power 100. The gap between them is the
	travel the player's ring covers.
]]
local OUTER_RADIUS = 150
local INNER_RADIUS = 20
local RING_THICKNESS = 6
local SUCCESS_THICKNESS = 4

local COLOR_TRACK = Color3.fromRGB(40, 44, 52)
local COLOR_RING_LOW = Color3.fromRGB(240, 148, 64)
local COLOR_RING_HELD = Color3.fromRGB(120, 180, 255)
local COLOR_RING_DONE = Color3.fromRGB(96, 214, 128)
local COLOR_SUCCESS = Color3.fromRGB(255, 255, 255)
local COLOR_TEXT = Color3.fromRGB(226, 232, 240)
local COLOR_PASS = Color3.fromRGB(96, 214, 128)
local COLOR_FAIL = Color3.fromRGB(240, 92, 92)

--[[
	The three instruction states must be unmistakable. Each one changes the prompt
	text, the prompt colour and the ring's colour together rather than relying on
	any single cue.
]]
local COLOR_STATE_MASH = Color3.fromRGB(96, 214, 128)
local COLOR_STATE_WARNING = Color3.fromRGB(255, 196, 64)
local COLOR_STATE_HOLD = Color3.fromRGB(120, 180, 255)

local TEXT_STATE_MASH = "MASH!"
local TEXT_STATE_WARNING = "GET READY TO HOLD"
local TEXT_STATE_HOLD = "HOLD!"
local TEXT_STATE_DONE = "POWER!"

export type Reporter = (events: { Simulation.InputEvent }) -> ()

type Visuals = {
	gui: ScreenGui,
	successCircle: Frame,
	playerRing: Frame,
	playerRingStroke: UIStroke,
	headline: TextLabel,
	detail: TextLabel,
	readout: TextLabel,
	verdict: TextLabel,
	statePrompt: TextLabel,
	holdBar: Frame,
	holdBarFill: Frame,
}

local visuals: Visuals? = nil

-- Live phase state.
local connection: RBXScriptConnection? = nil
local activeChallenge: PowerChallengeType? = nil
local activeState: Simulation.State? = nil
local accumulator = 0
local phaseClock = 0
local reporter: Reporter? = nil
local finished = true

--[[
	Every transition the player produced, in order, reported to the server at the
	end of the phase. Presses are NOT rate-filtered in this list, because a press
	discarded for arriving too fast still means the input is down; the server
	applies the same distinction.
]]
local recordedEvents: { Simulation.InputEvent } = {}
-- Transitions the live simulation has yet to consume.
local pendingEvents: { Simulation.InputEvent } = {}
-- Whether the input is currently down, as the controller reports it.
local inputHeld = false

--[[
	Live stepping bookkeeping, kept here rather than on the simulation's State so
	the shared type stays exactly what the server also uses.

	`liveHeld` is the input state the stepper last saw; `lastAcceptedPress` is the
	rate-cap cursor for mash scoring, mirroring what the server applies.
]]
local liveHeld = false
local lastAcceptedPress = -math.huge

local function build(instructionText: string): Visuals
	local gui = Instance.new("ScreenGui")
	gui.Name = "PowerUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local field = Instance.new("Frame")
	field.Name = "Field"
	field.AnchorPoint = Vector2.new(0.5, 0.5)
	field.Position = UDim2.fromScale(0.5, 0.5)
	field.Size = UDim2.fromOffset(OUTER_RADIUS * 2, OUTER_RADIUS * 2)
	field.BackgroundTransparency = 1
	field.Parent = gui

	-- The static outer circle: where the ring begins at power zero.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.Size = UDim2.fromOffset(OUTER_RADIUS * 2, OUTER_RADIUS * 2)
	track.BackgroundTransparency = 1
	track.ZIndex = 1
	track.Parent = field

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0.5, 0)
	trackCorner.Parent = track

	local trackStroke = Instance.new("UIStroke")
	trackStroke.Thickness = 2
	trackStroke.Color = COLOR_TRACK
	trackStroke.Parent = track

	--[[
		The inner success circle. Sized per challenge from radius at 100% completion, so its
		size communicates the attempt's difficulty before the player presses anything.
	]]
	local successCircle = Instance.new("Frame")
	successCircle.Name = "SuccessCircle"
	successCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	successCircle.Position = UDim2.fromScale(0.5, 0.5)
	successCircle.Size = UDim2.fromOffset(INNER_RADIUS * 2, INNER_RADIUS * 2)
	successCircle.BackgroundColor3 = COLOR_SUCCESS
	successCircle.BackgroundTransparency = 0.88
	successCircle.BorderSizePixel = 0
	successCircle.ZIndex = 2
	successCircle.Parent = field

	local successCorner = Instance.new("UICorner")
	successCorner.CornerRadius = UDim.new(0.5, 0)
	successCorner.Parent = successCircle

	local successStroke = Instance.new("UIStroke")
	successStroke.Thickness = SUCCESS_THICKNESS
	successStroke.Color = COLOR_SUCCESS
	successStroke.Parent = successCircle

	-- The player's ring. Contracts inward as power builds.
	local playerRing = Instance.new("Frame")
	playerRing.Name = "PlayerRing"
	playerRing.AnchorPoint = Vector2.new(0.5, 0.5)
	playerRing.Position = UDim2.fromScale(0.5, 0.5)
	playerRing.Size = UDim2.fromOffset(OUTER_RADIUS * 2, OUTER_RADIUS * 2)
	playerRing.BackgroundTransparency = 1
	playerRing.ZIndex = 4
	playerRing.Parent = field

	local playerCorner = Instance.new("UICorner")
	playerCorner.CornerRadius = UDim.new(0.5, 0)
	playerCorner.Parent = playerRing

	local playerRingStroke = Instance.new("UIStroke")
	playerRingStroke.Thickness = RING_THICKNESS
	playerRingStroke.Color = COLOR_RING_LOW
	playerRingStroke.Parent = playerRing

	local headline = Instance.new("TextLabel")
	headline.Name = "Headline"
	headline.AnchorPoint = Vector2.new(0.5, 1)
	headline.Position = UDim2.new(0.5, 0, 0, -58)
	headline.Size = UDim2.fromOffset(360, 32)
	headline.BackgroundTransparency = 1
	headline.Font = Enum.Font.GothamBold
	headline.TextSize = 26
	headline.TextColor3 = COLOR_TEXT
	headline.Text = ""
	headline.Parent = field

	local instruction = Instance.new("TextLabel")
	instruction.Name = "Instruction"
	instruction.AnchorPoint = Vector2.new(0.5, 1)
	instruction.Position = UDim2.new(0.5, 0, 0, -36)
	instruction.Size = UDim2.fromOffset(520, 20)
	instruction.BackgroundTransparency = 1
	instruction.Font = Enum.Font.GothamMedium
	instruction.TextSize = 13
	instruction.TextColor3 = Color3.fromRGB(150, 160, 175)
	instruction.Text = instructionText
	instruction.Parent = field

	--[[
		The instruction prompt, in the middle of the circle. Deliberately the largest
		thing on screen: the player should never have to work out whether they are
		meant to be mashing or holding.
	]]
	local statePrompt = Instance.new("TextLabel")
	statePrompt.Name = "StatePrompt"
	statePrompt.AnchorPoint = Vector2.new(0.5, 0.5)
	statePrompt.Position = UDim2.fromScale(0.5, 0.5)
	statePrompt.Size = UDim2.fromOffset(360, 52)
	statePrompt.BackgroundTransparency = 1
	statePrompt.Font = Enum.Font.GothamBlack
	statePrompt.TextSize = 36
	statePrompt.TextColor3 = COLOR_STATE_MASH
	statePrompt.TextStrokeTransparency = 0.4
	statePrompt.Text = ""
	statePrompt.ZIndex = 6
	statePrompt.Parent = field

	--[[
		Hold progress, shown only during a hold. Fills as the continuous run builds
		toward the required duration, so the player can see that holding is working
		and roughly when it will be done.
	]]
	local holdBar = Instance.new("Frame")
	holdBar.Name = "HoldBar"
	holdBar.AnchorPoint = Vector2.new(0.5, 0)
	holdBar.Position = UDim2.fromScale(0.5, 0.62)
	holdBar.Size = UDim2.fromOffset(200, 10)
	holdBar.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
	holdBar.BorderSizePixel = 0
	holdBar.Visible = false
	holdBar.ZIndex = 6
	holdBar.Parent = field

	local holdCorner = Instance.new("UICorner")
	holdCorner.CornerRadius = UDim.new(0, 5)
	holdCorner.Parent = holdBar

	local holdBarFill = Instance.new("Frame")
	holdBarFill.Name = "Fill"
	holdBarFill.Size = UDim2.fromScale(0, 1)
	holdBarFill.BackgroundColor3 = COLOR_STATE_HOLD
	holdBarFill.BorderSizePixel = 0
	holdBarFill.Parent = holdBar

	local holdFillCorner = Instance.new("UICorner")
	holdFillCorner.CornerRadius = UDim.new(0, 5)
	holdFillCorner.Parent = holdBarFill

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.AnchorPoint = Vector2.new(0.5, 0)
	detail.Position = UDim2.new(0.5, 0, 1, 14)
	detail.Size = UDim2.fromOffset(520, 20)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 14
	detail.TextColor3 = Color3.fromRGB(176, 184, 196)
	detail.Text = ""
	detail.Parent = field

	local readout = Instance.new("TextLabel")
	readout.Name = "Readout"
	readout.AnchorPoint = Vector2.new(0.5, 0)
	readout.Position = UDim2.new(0.5, 0, 1, 36)
	readout.Size = UDim2.fromOffset(560, 20)
	readout.BackgroundTransparency = 1
	readout.Font = Enum.Font.Code
	readout.TextSize = 13
	readout.TextColor3 = Color3.fromRGB(140, 150, 165)
	readout.Text = ""
	readout.Parent = field

	local verdict = Instance.new("TextLabel")
	verdict.Name = "Verdict"
	verdict.AnchorPoint = Vector2.new(0.5, 0.5)
	verdict.Position = UDim2.fromScale(0.5, 0.88)
	verdict.Size = UDim2.fromOffset(620, 40)
	verdict.BackgroundTransparency = 1
	verdict.Font = Enum.Font.GothamBold
	verdict.TextSize = 28
	verdict.TextColor3 = COLOR_TEXT
	verdict.Text = ""
	verdict.Parent = gui

	return {
		gui = gui,
		successCircle = successCircle,
		playerRing = playerRing,
		playerRingStroke = playerRingStroke,
		headline = headline,
		detail = detail,
		readout = readout,
		verdict = verdict,
		statePrompt = statePrompt,
		holdBar = holdBar,
		holdBarFill = holdBarFill,
	}
end

--[[
	Attaches the UI. Call once.
]]
function PowerUI.mount(parent: Instance, instructionText: string)
	if visuals ~= nil then
		return
	end
	local built = build(instructionText)
	built.gui.Parent = parent
	visuals = built
end

--[[
	The radial mapping. Power 0 is the outer edge, power progressMax the innermost.
]]
local function completionFraction(challenge: PowerChallengeType, progress: number): number
	return math.clamp(progress / challenge.completionThreshold, 0, 1)
end

local function radiusForProgress(challenge: PowerChallengeType, progress: number): number
	return OUTER_RADIUS - (OUTER_RADIUS - INNER_RADIUS) * completionFraction(challenge, progress)
end

local function redraw()
	local current = visuals
	local challenge = activeChallenge
	local state = activeState
	if current == nil or challenge == nil or state == nil then
		return
	end

	local radius = radiusForProgress(challenge, state.progress)
	current.playerRing.Size = UDim2.fromOffset(radius * 2, radius * 2)

	--[[
		Every state cue moves together: prompt text, prompt colour and ring colour.

		During a hold the ring turns blue and stops moving, which makes the paused
		decay legible rather than looking like a freeze.
	]]
	if state.outcome == "Passed" then
		-- Terminal. The ring is parked on the success circle and will not move again.
		current.statePrompt.Text = TEXT_STATE_DONE
		current.statePrompt.TextColor3 = COLOR_RING_DONE
		current.playerRingStroke.Color = COLOR_RING_DONE
		current.holdBar.Visible = false
	elseif state.phaseState == "Hold" then
		current.statePrompt.Text = TEXT_STATE_HOLD
		current.statePrompt.TextColor3 = COLOR_STATE_HOLD
		current.playerRingStroke.Color = COLOR_RING_HELD

		current.holdBar.Visible = true
		local progress = math.clamp(state.heldRunSeconds / challenge.requiredHoldSeconds, 0, 1)
		current.holdBarFill.Size = UDim2.fromScale(progress, 1)
		current.holdBarFill.BackgroundColor3 = if progress >= 1
			then COLOR_RING_DONE
			else COLOR_STATE_HOLD
	elseif state.phaseState == "HoldWarning" then
		current.statePrompt.Text = TEXT_STATE_WARNING
		current.statePrompt.TextColor3 = COLOR_STATE_WARNING
		current.playerRingStroke.Color = COLOR_STATE_WARNING
		current.holdBar.Visible = false
	else
		current.statePrompt.Text = TEXT_STATE_MASH
		current.statePrompt.TextColor3 = COLOR_STATE_MASH
		current.playerRingStroke.Color = COLOR_RING_LOW
		current.holdBar.Visible = false
	end

	--[[
		Progress as a plain percentage of completion, because that is the only thing
		the player needs: the circle already says how far there is to go.

		This deliberately no longer reads "power X / Y". That phrasing implied a
		second stat to satisfy on top of finishing the circle, which was never true
		and read as a bug when the two appeared to disagree.

		Everything after the percentage is DEV ONLY and is labelled so. It goes when
		the phase stops being tuned.
	]]
	local remaining = math.max(challenge.durationSeconds - state.elapsedSeconds, 0)
	current.readout.Text = string.format(
		"progress %3.0f%%      [dev]  %.1fs left   %d presses   need %.1f/s   holds %d/%d",
		completionFraction(challenge, state.progress) * 100,
		remaining,
		state.inputsApplied,
		challenge.requiredInputsPerSecond,
		state.holdsCompleted,
		#challenge.holdTriggers
	)
end

local function stopStepping()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

local function recordTransition(down: boolean)
	if finished or activeChallenge == nil then
		return
	end

	--[[
		A repeat of the same direction carries no information, and the server collapses
		these too, so recording them would only desynchronise the two sides.
	]]
	if down == inputHeld then
		return
	end
	inputHeld = down

	local event: Simulation.InputEvent = {
		time = os.clock() - phaseClock,
		down = down,
	}
	table.insert(pendingEvents, event)
	table.insert(recordedEvents, event)
end

--[[
	Records a press. Called by the controller that owns input.
]]
function PowerUI.registerPress()
	recordTransition(true)
end

--[[
	Records a release. Called by the controller that owns input.

	Without this the hold mechanic cannot work at all: the server needs to know when
	the input went UP to tell a continuous hold from a burst of clicks.
]]
function PowerUI.registerRelease()
	recordTransition(false)
end

--[[
	Runs one challenge.

	`report` is called exactly once, with every recorded transition, as soon as the
	local simulation concludes. The server then replays them and sends back the
	authoritative verdict for showVerdict.
]]
function PowerUI.run(challenge: PowerChallengeType, report: Reporter)
	local current = visuals
	if current == nil then
		return
	end

	stopStepping()

	activeChallenge = challenge
	activeState = Simulation.createState(challenge)
	accumulator = 0
	recordedEvents = {}
	pendingEvents = {}
	inputHeld = false
	liveHeld = false
	lastAcceptedPress = -math.huge
	phaseClock = os.clock()
	reporter = report
	finished = false

	--[[
		The success circle is 100% completion, so it sits at INNER_RADIUS on every
		attempt. Set here rather than left at its built size so it cannot drift if the
		geometry constants change.
	]]
	current.successCircle.Size = UDim2.fromOffset(INNER_RADIUS * 2, INNER_RADIUS * 2)

	current.headline.Text = challenge.displayName
	current.detail.Text = string.format(
		"%.1f kg  -  %.0f%%  -  difficulty %.0f  -  %d holds of %.2fs",
		challenge.attemptWeightKg,
		challenge.intensityPercent,
		challenge.baseDifficulty,
		#challenge.holdTriggers,
		challenge.requiredHoldSeconds
	)
	current.verdict.Text = ""
	current.holdBar.Visible = false
	current.gui.Enabled = true
	redraw()

	local lastClock = os.clock()

	connection = RunService.RenderStepped:Connect(function()
		local state = activeState
		if finished or state == nil then
			return
		end

		local now = os.clock()
		accumulator += now - lastClock
		lastClock = now

		local dt = challenge.fixedTimestepSeconds
		local minimumGap = 1 / challenge.maxInputsPerSecond

		--[[
			Fixed-timestep accumulator, so the local simulation steps exactly as the
			server's replay will. A cap on steps per frame stops a long hitch from
			freezing the client trying to catch up.
		]]
		local stepsThisFrame = 0
		while accumulator >= dt and state.outcome == "Running" and stepsThisFrame < 10 do
			local stepEnd = state.elapsedSeconds + dt

			--[[
				Consume this step's transitions. The last one decides whether the input
				is down for the step, matching how the server replays them.

				Presses are rate-filtered for MASH scoring only; a discarded press still
				leaves the input down, which is what lets a held button register as held.
			]]
			local pressesThisStep = 0
			local keep: { Simulation.InputEvent } = {}
			for _, event in ipairs(pendingEvents) do
				if event.time < stepEnd then
					if event.down and event.time - lastAcceptedPress >= minimumGap then
						pressesThisStep += 1
						lastAcceptedPress = event.time
					end
					liveHeld = event.down
				else
					table.insert(keep, event)
				end
			end
			pendingEvents = keep

			Simulation.step(challenge, state, pressesThisStep, liveHeld)
			accumulator -= dt
			stepsThisFrame += 1
		end

		redraw()

		if state.outcome ~= "Running" then
			--[[
				Terminal. Stepping stops here, so nothing can move the ring back out
				while the server's verdict is in flight.
			]]
			finished = true
			stopStepping()
			local send = reporter
			reporter = nil
			if send then
				send(recordedEvents)
			end
		end
	end)
end

--[[
	Shows the server's verdict.

	Does NOT schedule its own disappearance: a phase UI cannot know when the next
	phase needs the screen. The controller sequencing the attempt calls hide().
]]
function PowerUI.showVerdict(verdictText: string, passed: boolean, detailLine: string?)
	local current = visuals
	if current == nil then
		return
	end

	finished = true
	stopStepping()

	current.statePrompt.Text = if passed then TEXT_STATE_DONE else ""
	current.statePrompt.TextColor3 = COLOR_RING_DONE
	current.holdBar.Visible = false
	current.verdict.TextColor3 = if passed then COLOR_PASS else COLOR_FAIL
	current.verdict.Text = verdictText

	if detailLine then
		current.readout.Text = detailLine
	end
end

--[[
	Clears the phase from the screen immediately.
]]
function PowerUI.hide()
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
	current.statePrompt.Text = ""
	current.holdBar.Visible = false
end

--[[
	True while a phase is on screen awaiting input.
]]
function PowerUI.isRunning(): boolean
	return not finished
end

return PowerUI
