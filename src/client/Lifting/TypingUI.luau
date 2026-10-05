--!strict
--[[
	TypingUI
	Client / Lifting

	Draws the deadlift's typing pull and steps its simulation for display.

	A CONTINUOUS LINE OF WORDS

	One scrolling line, typed left to right:

		BRACE DRIVE PULL HIPS LOCK GRIP
		^^^^^^^^^^^^|
		done        current

	Completed characters are dimmed green. The current character keeps its normal
	size and sits in the line, marked by a highlight block and an underline cursor.
	Upcoming characters are plain, fading out further ahead so the eye is drawn
	forward without the line ending abruptly.

	The player reads ahead and types fluidly. When a word finishes the line carries
	straight into the next one with no interruption, and SPACES ARE NEVER TYPED --
	they are rendered for legibility and skipped automatically.

	This replaced a giant single-letter prompt. Reacting to one huge character at a
	time made typing feel like a reaction test rather than typing, and it capped a
	fluent player at the speed they could read one letter. The giant-token idea is
	kept for a future CONTROLLER vocabulary, where a prompt really is one button at
	a time and there is nothing to read ahead to.

	SCROLLING

	Characters are laid out at fixed cell widths in a monospaced font, so a cell's x
	position is just its index times the cell width. The strip is then slid left to
	keep the current character at a fixed anchor point, which makes the line
	effectively endless without ever reflowing it. The slide is eased so the line
	drifts rather than snapping on every keystroke.

	THE BAR

	A vertical bar from floor to lockout, driven by the one authoritative progress
	value:

		height = progress / completionThreshold     clamped to 0..1

	The bar reaching lockout IS the pass, because that same comparison is the only
	test the simulation makes. There is deliberately no second requirement behind a
	visually completed bar.

	Once the bar arrives it STOPS, for good: passing is terminal in the simulation,
	so stepping halts and nothing can drift it back down while the server's verdict
	is in flight.

	WHAT IT OWNS AND WHAT IT DOES NOT

	It runs TypingSimulation locally so the bar and the cursor move the instant a
	key lands, and it records every token press. When the local simulation concludes
	it hands those presses upward.

	It does NOT decide anything. The verdict it shows is whatever the server sent
	back after replaying those same presses against its own expected sequence.

	It does not read input either; the controller owns that and calls registerToken,
	so there is exactly one input owner.

	NOTHING HERE IS RATE-LIMITED OR DEBOUNCED. Every keystroke is recorded and
	simulated. An earlier version applied a minimum inter-key gap to mirror the
	server's, and both were discarding legitimate fast typing; see TypingPhaseConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiftingFolder = Shared:WaitForChild("Lifting")
local Simulation = require(LiftingFolder:WaitForChild("TypingSimulation"))

local TypingUI = {}

-- The challenge arrives across a remote, so it is a plain table here.
type TypingChallengeType = any

-- Bar geometry, in pixels. Presentation only.
local BAR_HEIGHT = 300
local BAR_WIDTH = 46

--[[
	Line geometry. CELL_WIDTH must suit the monospaced font below, or the cursor
	will drift away from the character it is marking.
]]
local LINE_WIDTH = 720
local LINE_HEIGHT = 64
local CELL_WIDTH = 30
local CHAR_TEXT_SIZE = 38
-- Where the current character sits inside the line, measured from the left edge.
local CURSOR_ANCHOR_X = 220
-- How quickly the strip slides toward its target. Higher is snappier.
local SCROLL_LERP = 14

local COLOR_TRACK = Color3.fromRGB(30, 33, 40)
local COLOR_BAR = Color3.fromRGB(240, 148, 64)
local COLOR_BAR_DONE = Color3.fromRGB(96, 214, 128)
local COLOR_TEXT = Color3.fromRGB(226, 232, 240)
local COLOR_DIM = Color3.fromRGB(120, 128, 140)
local COLOR_DONE = Color3.fromRGB(96, 214, 128)
local COLOR_CURRENT = Color3.fromRGB(255, 255, 255)
local COLOR_CURSOR = Color3.fromRGB(255, 196, 64)
local COLOR_WRONG = Color3.fromRGB(240, 92, 92)
local COLOR_PASS = Color3.fromRGB(96, 214, 128)
local COLOR_FAIL = Color3.fromRGB(240, 92, 92)

-- How long the red flash after a wrong key lasts. Feedback only.
local WRONG_FLASH_SECONDS = 0.18

export type Reporter = (events: { Simulation.TokenEvent }) -> ()

type Visuals = {
	gui: ScreenGui,
	barFill: Frame,
	lockoutLabel: TextLabel,
	headline: TextLabel,
	detail: TextLabel,
	readout: TextLabel,
	verdict: TextLabel,
	-- Clipping window; the strip slides inside it.
	lineWindow: Frame,
	strip: Frame,
	cursor: Frame,
	highlight: Frame,
}

local visuals: Visuals? = nil

-- Live phase state.
local connection: RBXScriptConnection? = nil
local activeChallenge: TypingChallengeType? = nil
local activeState: Simulation.State? = nil
local accumulator = 0
local phaseClock = 0
local reporter: Reporter? = nil
local finished = true

--[[
	Every token the player produced, in order, reported to the server at the end of
	the phase. Nothing is filtered: no rate limit, no debounce.
]]
local recordedEvents: { Simulation.TokenEvent } = {}
-- Tokens the live simulation has yet to consume.
local pendingEvents: { Simulation.TokenEvent } = {}

--[[
	The rendered line, one entry per CELL. A cell is either a token the player must
	type or a rendered space between words.

	Built once per challenge. The simulation only knows a flat token index, so
	`cellForToken` maps that back onto a position in the line.
]]
type Cell = {
	char: string,
	-- nil for a space, which is rendered but never typed.
	tokenIndex: number?,
	label: TextLabel,
}

local cells: { Cell } = {}
local cellForToken: { number } = {}
-- Smoothed scroll offset, so the line drifts instead of snapping.
local scrollX = 0
-- Wrong-key count last seen, to detect a new mistake and flash.
local lastWrongCount = 0
local flashUntil = 0

local function build(instructionText: string): Visuals
	local gui = Instance.new("ScreenGui")
	gui.Name = "TypingUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local headline = Instance.new("TextLabel")
	headline.Name = "Headline"
	headline.AnchorPoint = Vector2.new(0.5, 0)
	headline.Position = UDim2.new(0.5, 0, 0, 56)
	headline.Size = UDim2.fromOffset(420, 32)
	headline.BackgroundTransparency = 1
	headline.Font = Enum.Font.GothamBold
	headline.TextSize = 26
	headline.TextColor3 = COLOR_TEXT
	headline.Text = ""
	headline.Parent = gui

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.AnchorPoint = Vector2.new(0.5, 0)
	detail.Position = UDim2.new(0.5, 0, 0, 88)
	detail.Size = UDim2.fromOffset(600, 20)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 14
	detail.TextColor3 = Color3.fromRGB(176, 184, 196)
	detail.Text = ""
	detail.Parent = gui

	--[[
		The line window clips the strip, which is what makes the line scroll rather
		than overflow once it is wider than the UI.
	]]
	local lineWindow = Instance.new("Frame")
	lineWindow.Name = "LineWindow"
	lineWindow.AnchorPoint = Vector2.new(0.5, 0.5)
	lineWindow.Position = UDim2.fromScale(0.5, 0.46)
	lineWindow.Size = UDim2.fromOffset(LINE_WIDTH, LINE_HEIGHT)
	lineWindow.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
	lineWindow.BackgroundTransparency = 0.35
	lineWindow.BorderSizePixel = 0
	lineWindow.ClipsDescendants = true
	lineWindow.Parent = gui

	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0, 10)
	windowCorner.Parent = lineWindow

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.AnchorPoint = Vector2.new(0, 0.5)
	strip.Position = UDim2.new(0, 0, 0.5, 0)
	strip.Size = UDim2.new(0, 0, 1, 0)
	strip.BackgroundTransparency = 1
	strip.Parent = lineWindow

	--[[
		The highlight sits BEHIND the current character and the cursor underneath it.
		Two cues rather than one, so the current position is unmistakable without
		changing the character's size and breaking the line's rhythm.
	]]
	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.AnchorPoint = Vector2.new(0, 0.5)
	highlight.Size = UDim2.fromOffset(CELL_WIDTH, 48)
	highlight.BackgroundColor3 = COLOR_CURSOR
	highlight.BackgroundTransparency = 0.78
	highlight.BorderSizePixel = 0
	highlight.ZIndex = 1
	highlight.Parent = strip

	local highlightCorner = Instance.new("UICorner")
	highlightCorner.CornerRadius = UDim.new(0, 4)
	highlightCorner.Parent = highlight

	local cursor = Instance.new("Frame")
	cursor.Name = "Cursor"
	cursor.AnchorPoint = Vector2.new(0, 0.5)
	cursor.Size = UDim2.fromOffset(CELL_WIDTH - 6, 3)
	cursor.BackgroundColor3 = COLOR_CURSOR
	cursor.BorderSizePixel = 0
	cursor.ZIndex = 3
	cursor.Parent = strip

	-- The bar, to the left of the line.
	local barTrack = Instance.new("Frame")
	barTrack.Name = "BarTrack"
	barTrack.AnchorPoint = Vector2.new(0.5, 0.5)
	barTrack.Position = UDim2.new(0.5, -(LINE_WIDTH / 2) - 70, 0.46, 0)
	barTrack.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	barTrack.BackgroundColor3 = COLOR_TRACK
	barTrack.BorderSizePixel = 0
	barTrack.Parent = gui

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = barTrack

	--[[
		Fills from the BOTTOM upward: the anchor sits at the bottom edge so growing
		the height raises the top of the bar, which is the direction a deadlift goes.
	]]
	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.AnchorPoint = Vector2.new(0.5, 1)
	barFill.Position = UDim2.fromScale(0.5, 1)
	barFill.Size = UDim2.new(1, 0, 0, 0)
	barFill.BackgroundColor3 = COLOR_BAR
	barFill.BorderSizePixel = 0
	barFill.Parent = barTrack

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = barFill

	local lockoutLabel = Instance.new("TextLabel")
	lockoutLabel.Name = "LockoutLabel"
	lockoutLabel.AnchorPoint = Vector2.new(0.5, 1)
	lockoutLabel.Position = UDim2.new(0.5, 0, 0, -8)
	lockoutLabel.Size = UDim2.fromOffset(140, 18)
	lockoutLabel.BackgroundTransparency = 1
	lockoutLabel.Font = Enum.Font.GothamBold
	lockoutLabel.TextSize = 13
	lockoutLabel.TextColor3 = COLOR_DIM
	lockoutLabel.Text = "LOCKOUT"
	lockoutLabel.Parent = barTrack

	local floorLabel = Instance.new("TextLabel")
	floorLabel.Name = "FloorLabel"
	floorLabel.AnchorPoint = Vector2.new(0.5, 0)
	floorLabel.Position = UDim2.new(0.5, 0, 1, 8)
	floorLabel.Size = UDim2.fromOffset(140, 18)
	floorLabel.BackgroundTransparency = 1
	floorLabel.Font = Enum.Font.GothamBold
	floorLabel.TextSize = 13
	floorLabel.TextColor3 = COLOR_DIM
	floorLabel.Text = "FLOOR"
	floorLabel.Parent = barTrack

	local instruction = Instance.new("TextLabel")
	instruction.Name = "Instruction"
	instruction.AnchorPoint = Vector2.new(0.5, 0)
	instruction.Position = UDim2.fromScale(0.5, 0.62)
	instruction.Size = UDim2.fromOffset(720, 20)
	instruction.BackgroundTransparency = 1
	instruction.Font = Enum.Font.GothamMedium
	instruction.TextSize = 13
	instruction.TextColor3 = COLOR_DIM
	instruction.Text = instructionText
	instruction.Parent = gui

	local readout = Instance.new("TextLabel")
	readout.Name = "Readout"
	readout.AnchorPoint = Vector2.new(0.5, 0)
	readout.Position = UDim2.fromScale(0.5, 0.67)
	readout.Size = UDim2.fromOffset(760, 20)
	readout.BackgroundTransparency = 1
	readout.Font = Enum.Font.Code
	readout.TextSize = 13
	readout.TextColor3 = Color3.fromRGB(140, 150, 165)
	readout.Text = ""
	readout.Parent = gui

	local verdict = Instance.new("TextLabel")
	verdict.Name = "Verdict"
	verdict.AnchorPoint = Vector2.new(0.5, 0.5)
	verdict.Position = UDim2.fromScale(0.5, 0.86)
	verdict.Size = UDim2.fromOffset(760, 40)
	verdict.BackgroundTransparency = 1
	verdict.Font = Enum.Font.GothamBold
	verdict.TextSize = 28
	verdict.TextColor3 = COLOR_TEXT
	verdict.Text = ""
	verdict.Parent = gui

	return {
		gui = gui,
		barFill = barFill,
		lockoutLabel = lockoutLabel,
		headline = headline,
		detail = detail,
		readout = readout,
		verdict = verdict,
		lineWindow = lineWindow,
		strip = strip,
		cursor = cursor,
		highlight = highlight,
	}
end

--[[
	Attaches the UI. Call once.
]]
function TypingUI.mount(parent: Instance, instructionText: string)
	if visuals ~= nil then
		return
	end
	local built = build(instructionText)
	built.gui.Parent = parent
	visuals = built
end

--[[
	How full the bar is, 0 to 1. The same comparison the simulation passes on.
]]
local function completionFraction(challenge: TypingChallengeType, progress: number): number
	return math.clamp(progress / challenge.completionThreshold, 0, 1)
end

--[[
	Lays out the whole line as character cells.

	Words are separated by a rendered space cell that carries no token index, which
	is how word boundaries advance without the player ever typing a space.

	Only as many cues are laid out as could possibly be reached, because the
	challenge deliberately carries far more than a pull needs and building labels
	for all of them would be wasted work.
]]
local function layoutLine(challenge: TypingChallengeType)
	local current = visuals
	if current == nil then
		return
	end

	for _, cell in ipairs(cells) do
		cell.label:Destroy()
	end
	cells = {}
	cellForToken = {}

	local x = 0
	local tokenIndex = 0

	for cueIndex, cue in ipairs(challenge.cues) do
		if cueIndex > 1 then
			-- A rendered space. Never typed.
			local spacer = Instance.new("TextLabel")
			spacer.Name = "Space"
			spacer.AnchorPoint = Vector2.new(0, 0.5)
			spacer.Position = UDim2.new(0, x, 0.5, 0)
			spacer.Size = UDim2.fromOffset(CELL_WIDTH, 48)
			spacer.BackgroundTransparency = 1
			spacer.Font = Enum.Font.Code
			spacer.TextSize = CHAR_TEXT_SIZE
			spacer.TextColor3 = COLOR_DIM
			spacer.Text = ""
			spacer.ZIndex = 2
			spacer.Parent = current.strip
			table.insert(cells, { char = " ", tokenIndex = nil, label = spacer })
			x += CELL_WIDTH
		end

		for _, char in ipairs(cue.tokens) do
			tokenIndex += 1

			local label = Instance.new("TextLabel")
			label.Name = "C" .. tokenIndex
			label.AnchorPoint = Vector2.new(0, 0.5)
			label.Position = UDim2.new(0, x, 0.5, 0)
			label.Size = UDim2.fromOffset(CELL_WIDTH, 48)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Code
			label.TextSize = CHAR_TEXT_SIZE
			label.TextColor3 = COLOR_TEXT
			label.Text = char
			label.ZIndex = 2
			label.Parent = current.strip

			table.insert(cells, { char = char, tokenIndex = tokenIndex, label = label })
			cellForToken[tokenIndex] = #cells
			x += CELL_WIDTH
		end
	end

	current.strip.Size = UDim2.new(0, x, 1, 0)
end

local function redraw(delta: number)
	local current = visuals
	local challenge = activeChallenge
	local state = activeState
	if current == nil or challenge == nil or state == nil then
		return
	end

	local fraction = completionFraction(challenge, state.progress)
	current.barFill.Size = UDim2.new(1, 0, fraction, 0)

	local done = state.outcome == "Passed"
	current.barFill.BackgroundColor3 = if done then COLOR_BAR_DONE else COLOR_BAR
	current.lockoutLabel.TextColor3 = if done then COLOR_DONE else COLOR_DIM

	-- A new wrong key starts a brief red flash. Feedback only; nothing is withheld.
	if state.wrongTokens > lastWrongCount then
		lastWrongCount = state.wrongTokens
		flashUntil = os.clock() + WRONG_FLASH_SECONDS
	end
	local flashing = os.clock() < flashUntil

	local activeCell = cellForToken[state.expectedIndex]

	--[[
		Slide the strip so the current character sits at the anchor. Clamped at zero
		so the line never scrolls past its own start, and eased so it drifts rather
		than jumping on every keystroke.
	]]
	local targetX = 0
	if activeCell ~= nil then
		targetX = math.max((activeCell - 1) * CELL_WIDTH - CURSOR_ANCHOR_X, 0)
	end
	local alpha = math.clamp(delta * SCROLL_LERP, 0, 1)
	scrollX += (targetX - scrollX) * alpha
	current.strip.Position = UDim2.new(0, -math.floor(scrollX + 0.5), 0.5, 0)

	--[[
		Colour every cell by its position relative to the cursor. Completed green,
		current bright, upcoming fading forward.
	]]
	for index, cell in ipairs(cells) do
		if cell.tokenIndex == nil then
			-- Rendered space.
			cell.label.TextTransparency = 0.8
			continue
		end

		if done or cell.tokenIndex < state.expectedIndex then
			cell.label.TextColor3 = COLOR_DONE
			cell.label.TextTransparency = 0.5
		elseif cell.tokenIndex == state.expectedIndex then
			cell.label.TextColor3 = if flashing then COLOR_WRONG else COLOR_CURRENT
			cell.label.TextTransparency = 0
		else
			--[[
				Fade with distance so the line reads as continuing rather than stopping,
				and so the eye is pulled toward the cursor.
			]]
			local ahead = cell.tokenIndex - state.expectedIndex
			cell.label.TextColor3 = COLOR_TEXT
			cell.label.TextTransparency = math.clamp(0.15 + ahead * 0.035, 0, 0.8)
		end
		local _ = index
	end

	-- Park the highlight and cursor on the current cell.
	if activeCell ~= nil and not done then
		local cellX = (activeCell - 1) * CELL_WIDTH
		current.highlight.Visible = true
		current.cursor.Visible = true
		current.highlight.Position = UDim2.new(0, cellX, 0.5, 0)
		current.highlight.BackgroundColor3 = if flashing then COLOR_WRONG else COLOR_CURSOR
		current.cursor.Position = UDim2.new(0, cellX + 3, 0.5, 26)
		current.cursor.BackgroundColor3 = if flashing then COLOR_WRONG else COLOR_CURSOR
	else
		current.highlight.Visible = false
		current.cursor.Visible = false
	end

	--[[
		Progress as a plain percentage of completion, because that is the only thing
		the player needs: the bar already says how far there is to go.

		Everything after it is DEV ONLY and labelled so.
	]]
	local remaining = math.max(challenge.durationSeconds - state.elapsedSeconds, 0)
	current.readout.Text = string.format(
		"progress %3.0f%%      [dev]  %.1fs left   %d/%d correct   %d wrong   need %.1f/s",
		fraction * 100,
		remaining,
		state.correctTokens,
		challenge.tokensNeeded,
		state.wrongTokens,
		challenge.requiredTokensPerSecond
	)
end

local function stopStepping()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

--[[
	Records a token press. Called by the controller that owns input.

	EVERY press is recorded. No rate limit, no debounce, no dropping. The server
	applies no per-key filter either, so the two sides see the same raw list.
]]
function TypingUI.registerToken(token: string)
	if finished or activeChallenge == nil then
		return
	end

	local event: Simulation.TokenEvent = {
		time = os.clock() - phaseClock,
		token = token,
	}
	table.insert(pendingEvents, event)
	table.insert(recordedEvents, event)
end

--[[
	Runs one challenge.

	`report` is called exactly once, with every recorded token, as soon as the local
	simulation concludes. The server then replays them against its own expected
	sequence and sends back the authoritative verdict for showVerdict.
]]
function TypingUI.run(challenge: TypingChallengeType, report: Reporter)
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
	scrollX = 0
	lastWrongCount = 0
	flashUntil = 0
	phaseClock = os.clock()
	reporter = report
	finished = false

	layoutLine(challenge)

	current.headline.Text = challenge.displayName
	current.detail.Text = string.format(
		"%.1f kg  -  %.0f%%  -  difficulty %.0f  -  %d characters to lockout",
		challenge.attemptWeightKg,
		challenge.intensityPercent,
		challenge.baseDifficulty,
		challenge.tokensNeeded
	)
	current.verdict.Text = ""
	current.gui.Enabled = true
	redraw(1)

	local lastClock = os.clock()

	connection = RunService.RenderStepped:Connect(function(delta)
		local state = activeState
		if finished or state == nil then
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
		while accumulator >= dt and state.outcome == "Running" and stepsThisFrame < 10 do
			local stepEnd = state.elapsedSeconds + dt

			--[[
				Consume this step's tokens. ALL of them, in order: no gap filtering, so
				two keys 40ms apart both land exactly as the server will replay them.
			]]
			local batch: { string } = {}
			local keep: { Simulation.TokenEvent } = {}
			for _, event in ipairs(pendingEvents) do
				if event.time < stepEnd then
					table.insert(batch, event.token)
				else
					table.insert(keep, event)
				end
			end
			pendingEvents = keep

			Simulation.step(challenge, state, batch)
			accumulator -= dt
			stepsThisFrame += 1
		end

		redraw(delta)

		if state.outcome ~= "Running" then
			--[[
				Terminal. Stepping stops here, so nothing can move the bar back down
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
function TypingUI.showVerdict(verdictText: string, passed: boolean, detailLine: string?)
	local current = visuals
	if current == nil then
		return
	end

	finished = true
	stopStepping()

	current.highlight.Visible = false
	current.cursor.Visible = false

	current.verdict.TextColor3 = if passed then COLOR_PASS else COLOR_FAIL
	current.verdict.Text = verdictText

	if detailLine then
		current.readout.Text = detailLine
	end
end

--[[
	Clears the phase from the screen immediately.
]]
function TypingUI.hide()
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
	current.highlight.Visible = false
	current.cursor.Visible = false

	for _, cell in ipairs(cells) do
		cell.label:Destroy()
	end
	cells = {}
	cellForToken = {}
end

--[[
	True while a phase is on screen awaiting input.
]]
function TypingUI.isRunning(): boolean
	return not finished
end

return TypingUI
