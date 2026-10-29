--!strict
--[[
	TypingUI
	Client / Lifting

	Draws the deadlift's typing pull and steps its simulation for display.

	THE LOOK

	Built from UIStyle, the game's one look (user 2026-10-28: a wide navy panel
	with a row of square key boxes, one per letter, the current box lit up). The
	deadlift's colour is blue (UIStyle.LiftColours).

	Second pass (user 2026-10-28: "They need to be centered, Bigger, Easier to
	read"): the panel is anchored at its CENTRE in the middle of the screen
	(so UIStyle.fitToScreen shrinks it in place on short screens), the boxes are
	about 1.3x larger, and every line uses a fixed UIStyle.TextSizes size: the
	letters TextSizes.big or larger, NEXT words and the percentage
	TextSizes.heading, the attempt line and the instruction TextSizes.body, the
	LOCKOUT / FLOOR labels TextSizes.small. Nothing is smaller than that.

		 DEADLIFT · PULL //                                   <- title tag
		+------------------------------------------------------------+
		| LOCKOUT  58 kg · 90% · difficulty 45 · 30 characters  62%   |
		|  [  ]                                                       |
		|  [  ]     [B] [R] [A] [C] [E]       <- one box per key       |
		|  [##]                                                       |
		|  [##]    NEXT  DRIVE  ·  PULL  ·  HIPS                      |
		|  [##]    ------------------------------------------------   |
		|  FLOOR   instruction line                                   |
		|          [dev] readout (only with UIStyle.ShowDevReadouts)  |
		+------------------------------------------------------------+
		            [ BAR AT LOCKOUT ]        <- the server's verdict

	The testing numbers (seconds left, correct / wrong counts, the needed rate
	and the server's detail line) are only shown when UIStyle.ShowDevReadouts is
	true; the panel is shorter without them. The player's progress is the
	percentage and the bar.

	THE KEY BOXES

	The row shows the CURRENT cue (one word), one box per token:

		typed      filled in the lift's colour, white letter
		current    dark, a thick lift-coloured edge, a glow and an underline,
		           and larger (it eases up to size)
		upcoming   dark navy with a white edge, grey letter
		wrong key  the current box flashes red
		passed     every box turns white with a black letter (good = white)

	Box size shrinks to fit the word: the longest cue (10 letters, STRAIGHTEN)
	still fits in one row at 69 pixels a box; words of up to 7 letters get the
	full 92.

	Fluent typists read ahead, so the next few words sit under the row ("NEXT").
	When a word's last letter lands the row simply becomes the next word, and
	SPACES ARE NEVER TYPED -- word boundaries advance on their own.

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

	It runs TypingSimulation locally so the bar and the boxes move the instant a
	key lands, and it records every token press. When the local simulation
	concludes it hands those presses upward.

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
local TypingPhaseConfig = require(Shared:WaitForChild("Config"):WaitForChild("TypingPhaseConfig"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local TypingUI = {}

-- The challenge arrives across a remote, so it is a plain table here.
type TypingChallengeType = any

--[[
	Panel geometry, in pixels. Presentation only.

	The bar sits in a column on the left; everything else is in the content area
	to its right. The panel is anchored at its centre at PANEL_POSITION.
]]
local TEXT = UIStyle.TextSizes
local SHOW_DEV = UIStyle.ShowDevReadouts

local PANEL_POSITION = UIStyle.MinigameCentre
local PANEL_WIDTH = 940
-- The dev readout line adds a row at the bottom, only when it is shown.
local DEV_ROW_HEIGHT = 24
local PANEL_HEIGHT = 312 + (if SHOW_DEV then DEV_ROW_HEIGHT else 0)
local CONTENT_X = 130
local CONTENT_WIDTH = PANEL_WIDTH - CONTENT_X - 28

-- The bar, inside the left column.
local TRACK_X = 40
local TRACK_WIDTH = 40
local TRACK_Y = 56
local TRACK_HEIGHT = PANEL_HEIGHT - TRACK_Y - 50
-- LOCKOUT / FLOOR labels, centred on the track.
local TRACK_LABEL_WIDTH = 104

-- Lines in the content area, top to bottom.
local DETAIL_Y = 26
local PERCENT_WIDTH = 130
local NEXT_Y = 206
local RULE_Y = 250
local INSTRUCTION_Y = 260
local READOUT_Y = 292

--[[
	The key row. Boxes are as large as BOX_MAX but shrink so the longest cue still
	fits on one line: 10 letters -> (782 - 9 * 10) / 10 = 69 pixels.
]]
local ROW_Y = 64
local ROW_HEIGHT = 128
local BOX_MAX = 92
local BOX_GAP = 10
-- A letter is at least TextSizes.big, larger in larger boxes.
local LETTER_FRACTION = 0.62
-- How much larger the current box is than the others.
local CURRENT_SCALE = 1.18
-- How quickly a box eases to its size. Higher is snappier.
local BOX_LERP = 18
-- A new word's boxes start this small and ease up, so the change reads as a step.
local NEW_WORD_SCALE = 0.82
-- How many following words are shown under the row for reading ahead.
local NEXT_PREVIEW = 3

-- How long the red flash after a wrong key lasts. Feedback only.
local WRONG_FLASH_SECONDS = 0.18

export type Reporter = (events: { Simulation.TokenEvent }) -> ()

type Visuals = {
	gui: ScreenGui,
	title: TextLabel,
	detail: TextLabel,
	percent: TextLabel,
	-- The key row; boxes, the glow and the underline live in it.
	keys: Frame,
	glow: Frame,
	cursor: Frame,
	nextWords: TextLabel,
	barFill: Frame,
	lockoutLabel: TextLabel,
	readout: TextLabel,
	verdictBanner: Frame,
	verdict: TextLabel,
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
	One key box. Boxes are pooled: the row reuses them word after word and only
	grows the pool when a longer word arrives.
]]
type KeyBox = {
	frame: Frame,
	edge: UIStroke,
	letter: TextLabel,
	-- Displayed size relative to the row's box size; eased toward its target.
	scale: number,
}

local boxes: { KeyBox } = {}

--[[
	The simulation only knows a flat token index. These map it back onto the cue
	(word) it belongs to, built once per challenge.
]]
local tokenCue: { number } = {}
local cueFirstToken: { number } = {}
-- The cue the row is showing, how many boxes it uses and how big they are.
local shownCue = 0
local shownCount = 0
local boxSize = BOX_MAX
-- The lift's colour for this challenge.
local liftColour = UIStyle.LiftColours.Deadlift
--[[
	Whether the current box is marked. Cleared once the server's verdict is shown,
	as the old highlight and cursor were.
]]
local markCurrent = true
-- Wrong-key count last seen, to detect a new mistake and flash.
local lastWrongCount = 0
local flashUntil = 0

local function build(instructionText: string): Visuals
	local gui = Instance.new("ScreenGui")
	gui.Name = "TypingUI"
	UIStyle.fitToScreen(gui) -- shrink on short screens so nothing overlaps
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	--[[
		Anchored at its CENTRE, in the middle of the screen. fitToScreen shrinks a
		piece about its AnchorPoint, so a centre-anchored panel stays centred on
		short screens.
	]]
	local holder, body = UIStyle.panel(gui, "Panel", PANEL_POSITION, UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = PANEL_POSITION
	local title = UIStyle.titleTag(holder, "Tag", "", UDim2.fromOffset(-14, -26), UDim2.fromOffset(400, 48),
		UIStyle.LiftColours.Deadlift, "corner")

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = 2
	content.Parent = body

	-- The attempt line: kg, %, difficulty, characters to lockout.
	local detail = UIStyle.text(content, "Detail", UDim2.fromOffset(CONTENT_X, DETAIL_Y),
		UDim2.fromOffset(CONTENT_WIDTH - PERCENT_WIDTH - 10, 28), TEXT.body, C.muted, UIStyle.font(Enum.FontWeight.SemiBold))
	detail.TextWrapped = false
	detail.TextTruncate = Enum.TextTruncate.AtEnd

	-- Progress as a percentage, top right.
	local percent = UIStyle.text(content, "Percent", UDim2.fromOffset(CONTENT_X + CONTENT_WIDTH - PERCENT_WIDTH, DETAIL_Y - 6),
		UDim2.fromOffset(PERCENT_WIDTH, 40), TEXT.heading, liftColour, UIStyle.heading(), Enum.TextXAlignment.Right)
	percent.TextWrapped = false

	--[[
		The key row. Boxes are anchored at their centres, so the current one grows
		in place instead of pushing its neighbours.
	]]
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Position = UDim2.fromOffset(CONTENT_X, ROW_Y)
	keys.Size = UDim2.fromOffset(CONTENT_WIDTH, ROW_HEIGHT)
	keys.ZIndex = 2
	keys.Parent = content

	--[[
		The glow sits BEHIND the current box and the underline under it. Two cues
		rather than one, so the current key is unmistakable at a glance.
	]]
	local glow = UIStyle.frame(keys, "Glow", UDim2.fromOffset(0, 0), UDim2.fromOffset(BOX_MAX, BOX_MAX), liftColour)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundTransparency = 0.45
	glow.ZIndex = 1
	glow.Visible = false

	local cursor = UIStyle.frame(keys, "Cursor", UDim2.fromOffset(0, 0), UDim2.fromOffset(BOX_MAX, 5), liftColour)
	cursor.AnchorPoint = Vector2.new(0.5, 0)
	cursor.ZIndex = 3
	cursor.Visible = false

	-- The next words, for reading ahead.
	local nextHead = UIStyle.text(content, "NextHead", UDim2.fromOffset(CONTENT_X, NEXT_Y), UDim2.fromOffset(80, 32),
		TEXT.heading, C.yellow, UIStyle.heading())
	nextHead.TextWrapped = false
	nextHead.Text = "NEXT"
	local nextWords = UIStyle.text(content, "NextWords", UDim2.fromOffset(CONTENT_X + 90, NEXT_Y),
		UDim2.fromOffset(CONTENT_WIDTH - 90, 32), TEXT.heading, C.white, UIStyle.font(Enum.FontWeight.Bold, true))
	nextWords.TextWrapped = false
	nextWords.TextTruncate = Enum.TextTruncate.AtEnd

	local rule = UIStyle.frame(content, "Rule", UDim2.fromOffset(CONTENT_X, RULE_Y), UDim2.fromOffset(CONTENT_WIDTH, 1),
		C.white)
	rule.BackgroundTransparency = 0.6
	local instruction = UIStyle.text(content, "Instruction", UDim2.fromOffset(CONTENT_X, INSTRUCTION_Y),
		UDim2.fromOffset(CONTENT_WIDTH, 28), TEXT.body, C.white, UIStyle.font(Enum.FontWeight.SemiBold))
	instruction.Text = instructionText

	-- Testing numbers only; hidden unless UIStyle.ShowDevReadouts is on.
	local readout = UIStyle.text(content, "Readout", UDim2.fromOffset(CONTENT_X, READOUT_Y),
		UDim2.fromOffset(CONTENT_WIDTH, DEV_ROW_HEIGHT - 2), TEXT.small, C.muted, UIStyle.font(Enum.FontWeight.Medium))
	readout.TextWrapped = false
	readout.TextTruncate = Enum.TextTruncate.AtEnd
	readout.Visible = SHOW_DEV

	-- The bar, in the left column.
	local trackLabelX = TRACK_X + TRACK_WIDTH / 2 - TRACK_LABEL_WIDTH / 2
	local lockoutLabel = UIStyle.text(content, "LockoutLabel", UDim2.fromOffset(trackLabelX, TRACK_Y - 30),
		UDim2.fromOffset(TRACK_LABEL_WIDTH, 22), TEXT.small, C.muted, UIStyle.heading(), Enum.TextXAlignment.Center)
	lockoutLabel.TextWrapped = false
	lockoutLabel.Text = "LOCKOUT"
	local floorLabel = UIStyle.text(content, "FloorLabel", UDim2.fromOffset(trackLabelX, TRACK_Y + TRACK_HEIGHT + 10),
		UDim2.fromOffset(TRACK_LABEL_WIDTH, 22), TEXT.small, C.muted, UIStyle.heading(), Enum.TextXAlignment.Center)
	floorLabel.TextWrapped = false
	floorLabel.Text = "FLOOR"

	local barTrack = UIStyle.frame(content, "BarTrack", UDim2.fromOffset(TRACK_X, TRACK_Y),
		UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT), C.navyDeep)
	UIStyle.stroke(barTrack, C.white, 2)

	--[[
		Fills from the BOTTOM upward: the anchor sits at the bottom edge so growing
		the height raises the top of the bar, which is the direction a deadlift goes.
	]]
	local barFill = UIStyle.frame(barTrack, "BarFill", UDim2.fromScale(0.5, 1), UDim2.new(1, -6, 0, 0), liftColour)
	barFill.AnchorPoint = Vector2.new(0.5, 1)

	-- The lockout line across the top of the track.
	local notch = UIStyle.frame(barTrack, "Lockout", UDim2.new(0.5, 0, 0, -2), UDim2.new(1, 14, 0, 3), C.yellow)
	notch.AnchorPoint = Vector2.new(0.5, 0.5)

	--[[
		The verdict, a slanted slab centred under the panel: white for a pass, red
		for a fail. Anchored at its top centre, so on a short screen it shrinks
		toward its top edge and never covers the panel.
	]]
	local verdictBanner = UIStyle.frame(gui, "Verdict", UDim2.new(0.5, 0, PANEL_POSITION.Y.Scale, PANEL_HEIGHT / 2 + 30),
		UDim2.fromOffset(640, 72), C.white, -2)
	verdictBanner.AnchorPoint = Vector2.new(0.5, 0)
	verdictBanner.Position = UDim2.new(0.5, 0, PANEL_POSITION.Y.Scale, PANEL_HEIGHT / 2 + 30)
	verdictBanner.Visible = false
	UIStyle.stroke(verdictBanner, C.ink, 2)
	local verdict = UIStyle.text(verdictBanner, "Text", UDim2.fromOffset(16, 0), UDim2.new(1, -32, 1, 0), TEXT.big, C.ink,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	verdict.TextWrapped = false

	return {
		gui = gui,
		title = title,
		detail = detail,
		percent = percent,
		keys = keys,
		glow = glow,
		cursor = cursor,
		nextWords = nextWords,
		barFill = barFill,
		lockoutLabel = lockoutLabel,
		readout = readout,
		verdictBanner = verdictBanner,
		verdict = verdict,
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

-- Box `index` from the pool, made on first use.
local function getBox(keys: Frame, index: number): KeyBox
	local existing = boxes[index]
	if existing ~= nil then
		return existing
	end

	local frame = UIStyle.frame(keys, "Key" .. index, UDim2.fromOffset(0, 0), UDim2.fromOffset(BOX_MAX, BOX_MAX), C.empty)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.ZIndex = 2
	local edge = UIStyle.stroke(frame, C.white, 2)
	-- A fixed text size (set per word in showCue), so letters never shrink below TextSizes.big.
	local letter = UIStyle.text(frame, "Letter", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), TEXT.big, C.white,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	letter.TextWrapped = false
	letter.ZIndex = 3

	local box: KeyBox = { frame = frame, edge = edge, letter = letter, scale = 1 }
	boxes[index] = box
	return box
end

local function hideBoxes()
	for _, box in ipairs(boxes) do
		box.frame.Visible = false
	end
	shownCue = 0
	shownCount = 0
end

--[[
	Maps every token to its cue. Built once per challenge, because the simulation
	only knows a flat token index.
]]
local function indexCues(challenge: TypingChallengeType)
	tokenCue = {}
	cueFirstToken = {}

	local tokenIndex = 0
	for cueIndex, cue in ipairs(challenge.cues) do
		cueFirstToken[cueIndex] = tokenIndex + 1
		for _ in ipairs(cue.tokens) do
			tokenIndex += 1
			tokenCue[tokenIndex] = cueIndex
		end
	end
end

--[[
	Lays the row out for one cue: one box per token, centred, shrunk so the whole
	word fits on one line. Also fills the NEXT preview.
]]
local function showCue(challenge: TypingChallengeType, cueIndex: number)
	local current = visuals
	if current == nil then
		return
	end

	local cue = challenge.cues[cueIndex]
	local count = if cue ~= nil then #cue.tokens else 0

	boxSize = if count > 0
		then math.min(BOX_MAX, math.floor((CONTENT_WIDTH - (count - 1) * BOX_GAP) / count))
		else BOX_MAX
	local rowWidth = count * boxSize + math.max(count - 1, 0) * BOX_GAP
	local startX = (CONTENT_WIDTH - rowWidth) / 2
	local letterSize = math.max(TEXT.big, math.floor(boxSize * LETTER_FRACTION))

	for index = 1, count do
		local box = getBox(current.keys, index)
		box.frame.Visible = true
		box.frame.Position = UDim2.fromOffset(startX + (index - 1) * (boxSize + BOX_GAP) + boxSize / 2, ROW_HEIGHT / 2)
		box.letter.Text = cue.tokens[index]
		box.letter.TextSize = letterSize
		box.scale = NEW_WORD_SCALE
	end
	for index = count + 1, #boxes do
		boxes[index].frame.Visible = false
	end

	shownCue = cueIndex
	shownCount = count

	local upcoming: { string } = {}
	for offset = 1, NEXT_PREVIEW do
		local nextCue = challenge.cues[cueIndex + offset]
		if nextCue == nil then
			break
		end
		table.insert(upcoming, nextCue.label)
	end
	current.nextWords.Text = table.concat(upcoming, "   ·   ")
end

local function redraw(delta: number)
	local current = visuals
	local challenge = activeChallenge
	local state = activeState
	if current == nil or challenge == nil or state == nil then
		return
	end

	local fraction = completionFraction(challenge, state.progress)
	current.barFill.Size = UDim2.new(1, -6, fraction, 0)

	-- A completed pull turns white, like a meet's white light.
	local done = state.outcome == "Passed"
	current.barFill.BackgroundColor3 = if done then C.white else liftColour
	current.lockoutLabel.TextColor3 = if done then C.white else C.muted
	current.percent.Text = string.format("%.0f%%", fraction * 100)
	current.percent.TextColor3 = if done then C.white else liftColour

	-- A new wrong key starts a brief red flash. Feedback only; nothing is withheld.
	if state.wrongTokens > lastWrongCount then
		lastWrongCount = state.wrongTokens
		flashUntil = os.clock() + WRONG_FLASH_SECONDS
	end
	local flashing = os.clock() < flashUntil

	--[[
		Which word the row shows. Once the generated cues run out (which should not
		happen) the last word stays up, fully typed.
	]]
	local expected = state.expectedIndex
	local activeCue = tokenCue[expected]
	local cueIndex = activeCue or #challenge.cues
	if cueIndex ~= shownCue then
		showCue(challenge, cueIndex)
	end
	local firstToken = cueFirstToken[cueIndex] or 1

	local alpha = math.clamp(delta * BOX_LERP, 0, 1)
	local currentBox: KeyBox? = nil

	--[[
		Colour every box by where it sits relative to the expected token: typed in
		the lift's colour, the current one dark and lit, upcoming plain.
	]]
	for index = 1, shownCount do
		local box = boxes[index]
		local tokenIndex = firstToken + index - 1
		local isCurrent = activeCue ~= nil and tokenIndex == expected and not done and markCurrent

		if done then
			box.frame.BackgroundColor3 = C.white
			box.letter.TextColor3 = C.ink
			box.edge.Color = C.white
			box.edge.Thickness = 2
			box.edge.Transparency = 0
		elseif tokenIndex < expected then
			box.frame.BackgroundColor3 = liftColour
			box.letter.TextColor3 = C.white
			box.edge.Color = C.white
			box.edge.Thickness = 2
			box.edge.Transparency = 0.3
		elseif isCurrent then
			box.frame.BackgroundColor3 = if flashing then C.red else C.navyDeep
			box.letter.TextColor3 = C.white
			box.edge.Color = if flashing then C.red else liftColour
			box.edge.Thickness = 4
			box.edge.Transparency = 0
			currentBox = box
		else
			box.frame.BackgroundColor3 = C.empty
			box.letter.TextColor3 = C.muted
			box.edge.Color = C.white
			box.edge.Thickness = 2
			box.edge.Transparency = 0.45
		end

		local target = if isCurrent then CURRENT_SCALE else 1
		box.scale += (target - box.scale) * alpha
		local pixels = math.floor(boxSize * box.scale + 0.5)
		box.frame.Size = UDim2.fromOffset(pixels, pixels)
	end

	-- Park the glow and underline on the current box.
	if currentBox ~= nil then
		local centre = currentBox.frame.Position
		local pixels = boxSize * currentBox.scale
		local markColour = if flashing then C.red else liftColour
		current.glow.Visible = true
		current.cursor.Visible = true
		current.glow.Position = centre
		current.glow.Size = UDim2.fromOffset(pixels + 16, pixels + 16)
		current.glow.BackgroundColor3 = markColour
		current.cursor.Position = centre + UDim2.fromOffset(0, boxSize * CURRENT_SCALE / 2 + 8)
		current.cursor.Size = UDim2.fromOffset(boxSize * 0.7, 5)
		current.cursor.BackgroundColor3 = markColour
	else
		current.glow.Visible = false
		current.cursor.Visible = false
	end

	--[[
		The player's progress is the percentage (top right) and the bar. The raw
		numbers below are DEV ONLY, labelled so, and only shown when
		UIStyle.ShowDevReadouts is on.
	]]
	if SHOW_DEV then
		local remaining = math.max(challenge.durationSeconds - state.elapsedSeconds, 0)
		current.readout.Text = string.format(
			"[dev]  %.1fs left   %d/%d correct   %d wrong   need %.1f/s",
			remaining,
			state.correctTokens,
			challenge.tokensNeeded,
			state.wrongTokens,
			challenge.requiredTokensPerSecond
		)
	end
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
	lastWrongCount = 0
	flashUntil = 0
	markCurrent = true
	phaseClock = os.clock()
	reporter = report
	finished = false

	local phase = TypingPhaseConfig.Phases[challenge.phase]
	local liftName = if phase ~= nil then phase.lift else "Deadlift"
	liftColour = UIStyle.LiftColours[liftName] or C.blue
	current.glow.BackgroundColor3 = liftColour
	current.cursor.BackgroundColor3 = liftColour

	indexCues(challenge)
	hideBoxes()

	current.title.Text = string.format("%s  ·  %s", string.upper(liftName), challenge.displayName)
	current.detail.Text = string.format(
		"%.1f kg  ·  %.0f%%  ·  difficulty %.0f  ·  %d characters to lockout",
		challenge.attemptWeightKg,
		challenge.intensityPercent,
		challenge.baseDifficulty,
		challenge.tokensNeeded
	)
	current.verdict.Text = ""
	current.verdictBanner.Visible = false
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

	-- The current box stops being marked; the boxes otherwise stay as they ended.
	markCurrent = false
	redraw(1)
	current.glow.Visible = false
	current.cursor.Visible = false

	current.verdictBanner.BackgroundColor3 = if passed then C.white else C.red
	current.verdict.TextColor3 = if passed then C.ink else C.white
	current.verdict.Text = verdictText
	current.verdictBanner.Visible = verdictText ~= ""

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
	current.verdictBanner.Visible = false
	current.readout.Text = ""
	current.title.Text = ""
	current.detail.Text = ""
	current.percent.Text = ""
	current.nextWords.Text = ""
	current.glow.Visible = false
	current.cursor.Visible = false

	hideBoxes()
	tokenCue = {}
	cueFirstToken = {}
end

--[[
	True while a phase is on screen awaiting input.
]]
function TypingUI.isRunning(): boolean
	return not finished
end

return TypingUI
