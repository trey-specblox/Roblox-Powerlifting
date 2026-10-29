--!strict
--[[
	PowerUI
	Client / Lifting

	Draws the bench's Test Your Might power phase and steps its simulation for
	display. Built from UIStyle, the game's one look (user 2026-10-28: the power
	circle becomes the coloured timing ring): the lift's coloured target with a
	white four-point star at the centre, and an outer ring in the same colour
	closing in on it as the player mashes.

	Everything is ONE centred group (user 2026-10-28: "They need to be centered,
	Bigger, Easier to read"), anchored at its own centre at 50% / 52% of the
	screen, so UIStyle.fitToScreen shrinks it in place on short screens and
	nothing drifts to one side. Top to bottom:

		ring           the target on a dark backing disc, the outer ring (6 px,
		               with a soft glow) closing in; above the target the cue
		               tag (MASH! / GET READY TO HOLD / HOLD! / POWER!) at
		               heading size, below it the hold bar during a hold
		panel          directly under the ring, centred: the BENCH // POWER tag,
		               the instruction and the attempt line (body size), then
		               "POWER 62%" (heading size) and "HOLDS 0/2" (body size)
		verdict        the server's verdict at TextSizes.big, centred under the
		               panel, as a slanted tag (good = white, fail = red, like a
		               meet's lights)

	Testing readouts (seconds left, presses, the required rate, the server's
	detail line) appear on an extra small line in the panel ONLY when
	UIStyle.ShowDevReadouts is on; players never see them.

	The ring's colour is the lift's (UIStyle.LiftColours; bench is red), read from
	the phase's `lift` in PowerPhaseConfig.

	THE RADIAL MAPPING

		fraction = progress / completion threshold          clamped to 0..1
		outer ring closing = fraction                       (UIStyle ring: 0 = wide, 1 = on the target)

	The wide start is 0% complete. The outer ring sitting on the target is 100%
	complete. That is the whole mental model, and there is nothing else for the
	player to satisfy: the ring touching the target IS the pass condition, because
	`fraction` reaches 1 exactly when `progress` reaches `completionThreshold`, which
	is the single condition the simulation tests. Decay shows as the ring slipping
	back outward.

	The target is therefore the SAME SIZE on every attempt. An earlier version
	mapped progress across a fixed 0-100 scale and drew the target at the threshold,
	which made a harder attempt show a visibly smaller circle. That was dropped
	deliberately: difficulty belongs in how hard the ring is to move, not in where
	the finish line is drawn. A 110% attempt is harder because progress per click is
	worth less against a longer climb, decay is fiercer and there are more holds, not
	because the target shrank.

	This is purely presentational. The authoritative model is a single progress
	value, there is no two-dimensional cursor, and nothing about the simulation
	changed to accommodate the ring.

	WHAT THE CUES MEAN

		Mash          ring in the lift's colour, black tag "MASH!"; the target
		              flashes on every press that counts
		HoldWarning   ring yellow, black tag with yellow edge "GET READY TO HOLD"
		Hold          ring white, yellow tag "HOLD!", the hold bar filling
		Passed        ring white, white tag "POWER!"

	WHEN THE RING REACHES THE TARGET IT STOPS, FOR GOOD

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
local PowerPhaseConfig = require(Shared:WaitForChild("Config"):WaitForChild("PowerPhaseConfig"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local PowerUI = {}

-- The challenge arrives across a remote, so it is a plain table here.
type PowerChallengeType = any

--[[
	Geometry, in pixels, at the design screen height (UIStyle.fitToScreen
	shrinks the whole group on shorter screens). Presentation only.

	TARGET_SIZE is the target's diameter (power 100), 1.4 times the old 116.
	UIStyle's ring opens to 2.6 times that (power 0), so FIELD_SIZE, the dark
	disc the ring moves on, is just over 2.6 * TARGET_SIZE.
]]
local TARGET_SIZE = 162
local FIELD_SIZE = 424
local TARGET_RADIUS = TARGET_SIZE / 2

-- The closing ring: thicker than UIStyle's default, with a soft glow either side.
local RING_THICKNESS = 6
local GLOW_WIDTH = 14

-- The cue tag above the target and the hold bar below it.
local PROMPT_HEIGHT = 50
local PROMPT_OFFSET = TARGET_RADIUS + 42 -- from the ring's centre up to the tag's centre
local HOLD_BAR_WIDTH = 260
local HOLD_BAR_HEIGHT = 20
local HOLD_BAR_OFFSET = TARGET_RADIUS + 30 -- from the ring's centre down to the bar's centre

-- The info panel under the ring. The dev line only exists when ShowDevReadouts is on.
local TEXT = UIStyle.TextSizes
local SHOW_DEV = UIStyle.ShowDevReadouts
local PANEL_WIDTH = 680
local TITLE_WIDTH = 320
local TITLE_HEIGHT = 44
local INSTRUCTION_Y = 32
local DETAIL_Y = 62
local PROGRESS_Y = 94
local DEV_Y = 134
local PANEL_HEIGHT = if SHOW_DEV then 166 else 142
local PANEL_GAP = 36 -- ring to panel; the title tag straddles the panel's top edge

-- The verdict under the panel.
local VERDICT_HEIGHT = 64
local VERDICT_GAP = 20

local GROUP_WIDTH = PANEL_WIDTH
local GROUP_HEIGHT = FIELD_SIZE + PANEL_GAP + PANEL_HEIGHT + VERDICT_GAP + VERDICT_HEIGHT
local GROUP_POSITION = UIStyle.MinigameCentre

-- Used when a phase names no lift colour.
local DEFAULT_LIFT_COLOUR = UIStyle.LiftColours.Bench

--[[
	The instruction states must be unmistakable. Each one changes the tag text, the
	tag colours and the ring's colour together rather than relying on any single cue.
]]
local TEXT_STATE_MASH = "MASH!"
local TEXT_STATE_WARNING = "GET READY TO HOLD"
local TEXT_STATE_HOLD = "HOLD!"
local TEXT_STATE_DONE = "POWER!"

export type Reporter = (events: { Simulation.InputEvent }) -> ()

type Ring = {
	holder: Frame,
	setClosing: (amount: number) -> (),
	setColour: (colour: Color3) -> (),
	flash: () -> (),
}

type Visuals = {
	gui: ScreenGui,
	target: Ring,
	-- The soft glow around the closing ring; recoloured with it.
	glowStrokes: { UIStroke },
	promptTag: Frame,
	promptStroke: UIStroke,
	promptText: TextLabel,
	holdBar: Frame,
	holdBarFill: Frame,
	titleText: TextLabel,
	detail: TextLabel,
	-- "POWER 62%   HOLDS 0/2", for players.
	readout: TextLabel,
	-- The testing line; nil unless UIStyle.ShowDevReadouts is on.
	devReadout: TextLabel?,
	verdictTag: Frame,
	verdictStroke: UIStroke,
	verdictText: TextLabel,
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

-- The running phase's lift colour, and the colour the ring was last given.
local liftColour: Color3 = DEFAULT_LIFT_COLOUR
local shownRingColour: Color3? = nil

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

local function round(target: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = target
end

--[[
	A one-line row of panel text (UIStyle.text at `textSize`), centred, drawn
	above the panel's grid. Never wraps into the row below: a line that is too
	long for the panel shrinks just enough to fit, but never below
	TextSizes.small.
]]
local function panelLine(parent: Instance, name: string, y: number, height: number, textSize: number, colour: Color3,
	font: Font?): TextLabel
	local label = UIStyle.text(parent, name, UDim2.fromOffset(18, y), UDim2.new(1, -36, 0, height), textSize, colour, font,
		Enum.TextXAlignment.Center)
	label.ZIndex = 3
	label.TextWrapped = false
	label.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = textSize
	fit.MinTextSize = math.min(textSize, TEXT.small)
	fit.Parent = label
	return label
end

--[[
	Gives the closing ring its 6 px line and a soft glow: two faint, wide strokes,
	one just outside the line and one just inside it. They are children of the
	ring's outer circle, so they close in with it exactly. Returns the glow strokes
	so setRingColour can keep them in the ring's colour.
]]
local function thickenAndGlow(target: Ring, colour: Color3): { UIStroke }
	local outer = target.holder:FindFirstChild("Outer")
	if outer == nil or not outer:IsA("GuiObject") then
		return {}
	end
	local line = outer:FindFirstChildOfClass("UIStroke")
	if line then
		line.Thickness = RING_THICKNESS
	end

	local strokes = {}
	local glows = {
		{ name = "GlowOut", inset = 0, transparency = 0.78 },
		{ name = "GlowIn", inset = GLOW_WIDTH * 2, transparency = 0.86 },
	}
	for _, spec in ipairs(glows) do
		local glow = Instance.new("Frame")
		glow.Name = spec.name
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.new(1, -spec.inset, 1, -spec.inset)
		glow.BackgroundTransparency = 1
		round(glow)
		glow.Parent = outer
		table.insert(strokes, UIStyle.stroke(glow, colour, GLOW_WIDTH, spec.transparency))
	end
	return strokes
end

local function build(instructionText: string): Visuals
	local gui = Instance.new("ScreenGui")
	gui.Name = "PowerUI"
	UIStyle.fitToScreen(gui) -- shrink on short screens so nothing overlaps
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	--[[
		The one top-level piece: ring, panel and verdict stacked in a single group,
		anchored at its centre so it stays centred however it is scaled.
	]]
	local group = Instance.new("Frame")
	group.Name = "Group"
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = GROUP_POSITION
	group.Size = UDim2.fromOffset(GROUP_WIDTH, GROUP_HEIGHT)
	group.BackgroundTransparency = 1
	group.Parent = gui

	local field = Instance.new("Frame")
	field.Name = "Field"
	field.AnchorPoint = Vector2.new(0.5, 0)
	field.Position = UDim2.fromScale(0.5, 0)
	field.Size = UDim2.fromOffset(FIELD_SIZE, FIELD_SIZE)
	field.BackgroundTransparency = 1
	field.Parent = group

	--[[
		A dark see-through disc behind the whole ring, so the lift's colour reads
		against any scene, with a faint white edge where the outer ring starts at
		power zero.
	]]
	local backing = UIStyle.frame(field, "Backing", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.navyDeep)
	backing.BackgroundTransparency = 0.55
	backing.ZIndex = 1
	round(backing)
	UIStyle.stroke(backing, C.white, 2, 0.7)

	--[[
		The target and the outer ring. The target is 100% completion and the same
		size on every attempt; the outer ring closes in on it as power builds.
	]]
	local target = UIStyle.ring(field, "Target", UDim2.fromScale(0.5, 0.5), TARGET_SIZE, DEFAULT_LIFT_COLOUR) :: any
	target.holder.ZIndex = 2
	local glowStrokes = thickenAndGlow(target :: Ring, DEFAULT_LIFT_COLOUR)

	--[[
		The cue tag, just above the target. Deliberately the boldest thing on screen:
		the player should never have to work out whether they are meant to be
		mashing or holding. It grows to fit its text.
	]]
	local promptTag = UIStyle.frame(field, "PromptTag", UDim2.new(0.5, 0, 0.5, -PROMPT_OFFSET),
		UDim2.fromOffset(0, PROMPT_HEIGHT), C.ink, -3)
	promptTag.AnchorPoint = Vector2.new(0.5, 0.5)
	promptTag.AutomaticSize = Enum.AutomaticSize.X
	promptTag.ZIndex = 4
	promptTag.Visible = false
	local promptStroke = UIStyle.stroke(promptTag, C.white, 2)
	local promptPadding = Instance.new("UIPadding")
	promptPadding.PaddingLeft = UDim.new(0, 22)
	promptPadding.PaddingRight = UDim.new(0, 22)
	promptPadding.Parent = promptTag
	local promptText = UIStyle.text(promptTag, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), TEXT.heading,
		C.white, UIStyle.heading(), Enum.TextXAlignment.Center)
	promptText.AutomaticSize = Enum.AutomaticSize.X
	promptText.TextWrapped = false
	promptText.ZIndex = 4

	--[[
		Hold progress, shown only during a hold, just below the target. Fills as the
		continuous run builds toward the required duration, so the player can see that
		holding is working and roughly when it will be done.
	]]
	local holdBar = UIStyle.frame(field, "HoldBar", UDim2.new(0.5, 0, 0.5, HOLD_BAR_OFFSET),
		UDim2.fromOffset(HOLD_BAR_WIDTH, HOLD_BAR_HEIGHT), C.navyDeep)
	holdBar.AnchorPoint = Vector2.new(0.5, 0.5)
	holdBar.ZIndex = 4
	holdBar.Visible = false
	UIStyle.stroke(holdBar, C.white, 2)

	local holdBarFill = UIStyle.frame(holdBar, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), C.yellow)
	holdBarFill.ZIndex = 4

	--[[
		The panel directly under the ring, centred: the title tag straddling its top
		edge, the instruction, the attempt line, then the progress and holds.
	]]
	local panelHolder, panel = UIStyle.panel(group, "Info", UDim2.new(0.5, -PANEL_WIDTH / 2, 0, FIELD_SIZE + PANEL_GAP),
		UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	local titleText = UIStyle.titleTag(panelHolder, "Tag", "",
		UDim2.new(0.5, -TITLE_WIDTH / 2, 0, -TITLE_HEIGHT / 2 - 4), UDim2.fromOffset(TITLE_WIDTH, TITLE_HEIGHT), nil, "chevron")

	local instruction = panelLine(panel, "Instruction", INSTRUCTION_Y, 26, TEXT.body, C.white, UIStyle.heading())
	instruction.Text = instructionText

	local detail = panelLine(panel, "Detail", DETAIL_Y, 26, TEXT.body, C.muted)

	-- "POWER 62%" at heading size, then "HOLDS 0/2" at body size (rich text, see redraw).
	local readout = panelLine(panel, "Readout", PROGRESS_Y, 34, TEXT.body, C.white, UIStyle.heading())
	readout.RichText = true
	readout.TextScaled = false -- short and fixed: keep the rich-text sizes exact

	local devReadout: TextLabel? = nil
	if SHOW_DEV then
		devReadout = panelLine(panel, "DevReadout", DEV_Y, 20, TEXT.small, C.muted, UIStyle.font(Enum.FontWeight.Medium))
	end

	--[[
		The server's verdict: a slanted tag centred under the panel, white for a pass
		and red for a fail. It grows to fit its text and is hidden while it has none.
	]]
	local verdictTag = UIStyle.frame(group, "Verdict", UDim2.new(0.5, 0, 1, -VERDICT_HEIGHT / 2),
		UDim2.fromOffset(0, VERDICT_HEIGHT), C.white, -2)
	verdictTag.AnchorPoint = Vector2.new(0.5, 0.5)
	verdictTag.AutomaticSize = Enum.AutomaticSize.X
	verdictTag.ZIndex = 10
	verdictTag.Visible = false
	local verdictStroke = UIStyle.stroke(verdictTag, C.white, 2)
	local verdictPadding = Instance.new("UIPadding")
	verdictPadding.PaddingLeft = UDim.new(0, 28)
	verdictPadding.PaddingRight = UDim.new(0, 28)
	verdictPadding.Parent = verdictTag

	local verdictText = UIStyle.text(verdictTag, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), TEXT.big, C.ink,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	verdictText.AutomaticSize = Enum.AutomaticSize.X
	verdictText.TextWrapped = false
	verdictText.ZIndex = 10

	return {
		gui = gui,
		target = target :: Ring,
		glowStrokes = glowStrokes,
		promptTag = promptTag,
		promptStroke = promptStroke,
		promptText = promptText,
		holdBar = holdBar,
		holdBarFill = holdBarFill,
		titleText = titleText,
		detail = detail,
		readout = readout,
		devReadout = devReadout,
		verdictTag = verdictTag,
		verdictStroke = verdictStroke,
		verdictText = verdictText,
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
	The radial mapping. Power 0 is the wide start, the completion threshold is the
	outer ring sitting on the target.
]]
local function completionFraction(challenge: PowerChallengeType, progress: number): number
	return math.clamp(progress / challenge.completionThreshold, 0, 1)
end

-- The lift this phase belongs to ("Bench"), from its config, or nil.
local function liftNameFor(challenge: PowerChallengeType): string?
	local phase = (PowerPhaseConfig.Phases :: any)[challenge.phase]
	if phase ~= nil and typeof(phase.lift) == "string" then
		return phase.lift
	end
	return nil
end

local function setRingColour(current: Visuals, colour: Color3)
	if shownRingColour ~= colour then
		shownRingColour = colour
		current.target.setColour(colour)
		for _, glow in ipairs(current.glowStrokes) do
			glow.Color = colour
		end
	end
end

-- Shows the cue tag with its text and colours, or hides it when `text` is empty.
local function setPrompt(current: Visuals, text: string, fill: Color3, textColour: Color3, edge: Color3)
	current.promptTag.Visible = text ~= ""
	current.promptText.Text = text
	current.promptTag.BackgroundColor3 = fill
	current.promptText.TextColor3 = textColour
	current.promptStroke.Color = edge
end

local function redraw()
	local current = visuals
	local challenge = activeChallenge
	local state = activeState
	if current == nil or challenge == nil or state == nil then
		return
	end

	current.target.setClosing(completionFraction(challenge, state.progress))

	--[[
		Every state cue moves together: tag text, tag colours and ring colour.

		During a hold the ring turns white and stops moving, which makes the paused
		decay legible rather than looking like a freeze.
	]]
	if state.outcome == "Passed" then
		-- Terminal. The ring is parked on the target and will not move again.
		setPrompt(current, TEXT_STATE_DONE, C.white, C.ink, C.white)
		setRingColour(current, C.white)
		current.holdBar.Visible = false
	elseif state.phaseState == "Hold" then
		setPrompt(current, TEXT_STATE_HOLD, C.yellow, C.ink, C.white)
		setRingColour(current, C.white)

		current.holdBar.Visible = true
		local progress = math.clamp(state.heldRunSeconds / challenge.requiredHoldSeconds, 0, 1)
		current.holdBarFill.Size = UDim2.fromScale(progress, 1)
		current.holdBarFill.BackgroundColor3 = if progress >= 1
			then C.white
			else C.yellow
	elseif state.phaseState == "HoldWarning" then
		setPrompt(current, TEXT_STATE_WARNING, C.ink, C.yellow, C.yellow)
		setRingColour(current, C.yellow)
		current.holdBar.Visible = false
	else
		setPrompt(current, TEXT_STATE_MASH, C.ink, C.white, liftColour)
		setRingColour(current, liftColour)
		current.holdBar.Visible = false
	end

	--[[
		Progress as a plain percentage of completion, because that is the only thing
		the player needs: the ring already says how far there is to go.

		This deliberately no longer reads "power X / Y". That phrasing implied a
		second stat to satisfy on top of finishing the circle, which was never true
		and read as a bug when the two appeared to disagree.

		The holds count sits beside it at body size. The raw testing numbers are
		DEV ONLY: they go on their own small line, which exists only while
		UIStyle.ShowDevReadouts is on.
	]]
	local percent = string.format("%.0f%%", completionFraction(challenge, state.progress) * 100)
	local holdCount = #challenge.holdTriggers
	current.readout.Text = if holdCount > 0
		then string.format('<font size="%d">POWER %s</font>      HOLDS %d/%d', TEXT.heading, percent,
			state.holdsCompleted, holdCount)
		else string.format('<font size="%d">POWER %s</font>', TEXT.heading, percent)

	local devReadout = current.devReadout
	if devReadout then
		local remaining = math.max(challenge.durationSeconds - state.elapsedSeconds, 0)
		devReadout.Text = string.format(
			"[dev]  %.1fs left   %d presses   need %.1f/s",
			remaining,
			state.inputsApplied,
			challenge.requiredInputsPerSecond
		)
	end
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
		The ring takes the lift's colour (bench red). The target stays the same size
		on every attempt: it is 100% completion, never a measure of difficulty.
	]]
	local liftName = liftNameFor(challenge)
	liftColour = if liftName ~= nil then UIStyle.LiftColours[liftName] or DEFAULT_LIFT_COLOUR else DEFAULT_LIFT_COLOUR
	shownRingColour = nil

	current.titleText.Text = if liftName ~= nil
		then string.format("%s // %s", string.upper(liftName), challenge.displayName)
		else challenge.displayName
	current.detail.Text = string.format(
		"%.1f kg - %.0f%% - difficulty %.0f - %d holds of %.2fs",
		challenge.attemptWeightKg,
		challenge.intensityPercent,
		challenge.baseDifficulty,
		#challenge.holdTriggers,
		challenge.requiredHoldSeconds
	)
	current.verdictText.Text = ""
	current.verdictTag.Visible = false
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

		-- Whether any press this frame paid progress, for the target's flash. Display only.
		local pressPaid = false

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

			-- Mash and the warning are the states where a press pays (PowerSimulation).
			if pressesThisStep > 0 and (state.phaseState == "Mash" or state.phaseState == "HoldWarning") then
				pressPaid = true
			end

			Simulation.step(challenge, state, pressesThisStep, liveHeld)
			accumulator -= dt
			stepsThisFrame += 1
		end

		if pressPaid then
			current.target.flash()
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

	-- Good = white, fail = red, on the ring as on the verdict.
	setPrompt(current, if passed then TEXT_STATE_DONE else "", C.white, C.ink, C.white)
	setRingColour(current, if passed then C.white else C.red)
	current.holdBar.Visible = false

	current.verdictText.Text = verdictText
	current.verdictTag.Visible = verdictText ~= ""
	current.verdictTag.BackgroundColor3 = if passed then C.white else C.red
	current.verdictText.TextColor3 = if passed then C.ink else C.white
	current.verdictStroke.Color = C.white

	-- The server's raw detail line is a testing readout: dev line only.
	local devReadout = current.devReadout
	if detailLine and devReadout then
		devReadout.Text = detailLine
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
	current.verdictText.Text = ""
	current.verdictTag.Visible = false
	current.readout.Text = ""
	local devReadout = current.devReadout
	if devReadout then
		devReadout.Text = ""
	end
	current.titleText.Text = ""
	current.detail.Text = ""
	setPrompt(current, "", C.ink, C.white, C.white)
	current.holdBar.Visible = false
end

--[[
	True while a phase is on screen awaiting input.
]]
function PowerUI.isRunning(): boolean
	return not finished
end

return PowerUI
