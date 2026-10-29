--!strict
--[[
	SkillCheckUI
	Client / Lifting

	Draws the timing check ("lockout" style) and reports when the player pressed.
	Used by every timing phase: SquatDepth, BenchPress and DeadliftLockout.

	Everything is built in code so there are no Studio GUI assets to keep in sync
	with Rojo. The look comes from UIStyle (GAME_DESIGN.md "One UI style for the
	whole game"): a navy panel with a slanted title tag naming the phase. Each
	lift has its own colour (user 2026-10-28: squat yellow, bench red, deadlift
	blue). After the first test the user asked for it "centered, Bigger, Easier
	to read" and said it was "really hard to visually tell when to press space",
	so this version is about making the moment to press unmistakable.

	WHAT THE PLAYER SEES

	One panel, anchored at its centre in the middle of the screen. In it a big
	dark disc holds the target:

		- a THICK WHITE BAND. That band is the whole success zone: press while the
		  closing ring is inside it. Thin black lines edge it so it reads against
		  any lift colour. (They sit just OUTSIDE the band; they are not part of
		  the zone.)
		- inside the band, the target face in the lift colour, with an inner ring
		  and a white four-point star;
		- a thick CLOSING RING in the lift colour (with a black edge and a soft
		  glow) that starts wide and closes in on the band.

	Under the disc sits a white KEY CAP showing the key to press ("SPACE"), and
	under that the attempt line (kg, % of max, difficulty).

	THE STATES (display only, decided from the SAME angle the press reports)

		WAIT      angle before the zone. The band is dimmed, the face is faint and
		          a calm "WAIT..." sits in the middle.
		NOW!      angle inside the zone. The band goes full white, the whole face
		          lights up in the lift colour and a big "NOW!" pops in the middle.
		TOO LATE  the zone has passed (this is the moment the check times out).
		          The band dims and "TOO LATE" shows in red until the server's
		          verdict arrives.
		verdict   the server's verdict replaces the key cap and the attempt line,
		          white for a good lift and red for a no lift, and the closing ring
		          takes the same colour where it stopped.

	A press freezes the ring where it was caught. If it was caught inside the
	zone, NOW! stays lit; if it was caught early, the middle goes blank. Either
	way the server's verdict decides the outcome, not this screen.

	HOW TIME MAPS TO THE RING

	The server judges by the needle angle it always has (SkillCheckGrade):

		angle at time t = needleSpeedDegPerSec * t
		success         = targetStartDeg <= angle <= targetStartDeg + targetArcDeg

	There is no visible needle, but the ring is driven by that same angle, so
	nothing about the judging changes. The ring's radius falls in a straight
	line with the angle, and reaches TARGET_RADIUS at the CENTRE of the zone:

		centreDeg = targetStartDeg + targetArcDeg / 2
		radius    = START_RADIUS + (TARGET_RADIUS - START_RADIUS) * angle / centreDeg

	Because the mapping is a straight line, the band is drawn between the two
	radii the ring has at the zone's first and last degree:

		band outer = radius at targetStartDeg
		band inner = radius at targetStartDeg + targetArcDeg

	So "ring inside the white band" on screen is exactly "inside the target" for
	the server. The band's thickness is the real window, so a harder check has a
	thinner band; it is never padded to look easier.

	There is ONE zone and no perfect tier anywhere in this system
	(SkillCheckConfig), so only one band is drawn and nothing marks a "best"
	spot inside it.

	HOW CIRCLES ARE DRAWN WITHOUT IMAGES

	A circle is a round frame with a UIStroke. A UIStroke is drawn OUTSIDE its
	frame's edge, so a ring covering radii a..b is a round frame of radius a with
	a stroke b - a thick. The band, its edges and the closing ring all go through
	placeRing, so their radii are exact.

	This module decides nothing about gameplay. It renders the numbers the server
	sent and reports when the key went down. The verdict comes back from the
	server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillCheckConfig = require(Shared:WaitForChild("Config"):WaitForChild("SkillCheckConfig"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours
local TEXT = UIStyle.TextSizes

local SkillCheckUI = {}

-- Visual constants. Presentation only; no effect on difficulty or timing.

-- Where the middle of the zone lands (1.6x the first version's 56 px).
local TARGET_RADIUS = 90
-- Where the closing ring starts.
local START_RADIUS = TARGET_RADIUS * 2.4
-- The closing ring: its line, its black edge and its soft glow, in pixels.
local CLOSING_WIDTH = 6
local CLOSING_EDGE = 2
local GLOW_WIDTH = 5
-- The dark disc behind everything: just wider than the closing ring's glow at its start.
local FIELD_RADIUS = START_RADIUS + CLOSING_WIDTH / 2 + CLOSING_EDGE + GLOW_WIDTH + 2
-- The thin black lines just outside the white band.
local BAND_EDGE = 2

-- The panel and where things sit in it (pixels from the panel's top).
local PANEL_WIDTH = 500
local PANEL_HEIGHT = 520
local RING_CENTRE_Y = FIELD_RADIUS + 4
-- The key cap sits on the bottom rim of the dark disc.
local KEYCAP_Y = RING_CENTRE_Y + FIELD_RADIUS
local KEYCAP_HEIGHT = 44
local KEYCAP_KEY_WIDTH = 180
local KEYCAP_TEXT_WIDTH = 400
local KEYCAP_DEPTH = 5
local DETAIL_Y = PANEL_HEIGHT - 20
-- The verdict takes the key cap's and attempt line's place (both are cleared then).
local VERDICT_Y = PANEL_HEIGHT - 58
local VERDICT_HEIGHT = 100

-- How each state looks.
local BAND_DIM = 0.45
local BAND_LATE = 0.6
local FACE_FAINT = 0.82
local FACE_LIT = 0.05
local GLOW_TRANSPARENCY = 0.7
local POP_SCALE = 0.4
local POP_SECONDS = 0.12
local FLASH_SECONDS = 0.15

export type PressReporter = (pressTimeSeconds: number?) -> ()

type Ring = {
	frame: Frame,
	stroke: UIStroke,
}

type Visuals = {
	gui: ScreenGui,
	-- The phase name, in the title tag.
	headline: TextLabel,
	-- The title tag itself, so its slashes can take the lift's colour.
	tag: Frame,
	-- The key cap: a holder (shown or hidden), its coloured base and its white face.
	keyCap: Frame,
	keyBase: Frame,
	keyFace: Frame,
	keyText: TextLabel,
	-- The instruction the controller passed, kept so the key cap can be rebuilt from it.
	instructionText: string,
	detail: TextLabel,
	verdict: TextLabel,
	-- The big word in the middle (WAIT... / NOW! / TOO LATE) and its pop.
	word: TextLabel,
	wordScale: UIScale,
	face: Frame,
	innerRing: UIStroke,
	band: Ring,
	bandEdgeInner: Ring,
	bandEdgeOuter: Ring,
	closing: Ring,
	closingEdge: Ring,
	glow: Ring,
}

local visuals: Visuals? = nil

--[[
	Live check state. Nil when no check is running.

	This module does NOT listen for input. LiftAttemptController owns every key and
	calls pressNow when the press belongs to a running check. Two listeners on the
	same input would make behaviour depend on connection order, where one press
	could both resolve the current check and start the next one.
]]
local activeConnection: RBXScriptConnection? = nil
local activeStartClock: number? = nil
local activeReport: PressReporter? = nil
local activeFinished = true

-- The running check's numbers, kept so a press can draw the ring where it landed.
local activeSpeed = 0
local activeCentreDeg = 1
local activeZoneStartDeg = 0
local activeZoneArcDeg = 0
local activeLiftColour: Color3 = C.yellow

-- What the screen is showing. Display only: the server judges the press.
type DisplayState = "idle" | "wait" | "now" | "late"
local displayState: DisplayState = "idle"
local nowShownClock = 0

--[[
	Which lift a phase belongs to, read from the phase's own config entry, so a new
	timing phase picks up its lift's colour with no change here.
]]
local function liftColourFor(phaseName: any): Color3
	local phase = if typeof(phaseName) == "string" then (SkillCheckConfig.Phases :: any)[phaseName] else nil
	local lift = if phase ~= nil then phase.lift else nil
	return (if typeof(lift) == "string" then UIStyle.LiftColours[lift] else nil) or C.yellow
end

local function makeRound(target: GuiObject, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0.5, 0)
	corner.Parent = target
end

-- A round frame centred in `parent`, drawn only by its stroke. Size it with placeRing.
local function makeRing(parent: Instance, name: string, colour: Color3, zIndex: number): Ring
	local f = UIStyle.frame(parent, name, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(0, 0), colour)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundTransparency = 1
	f.ZIndex = zIndex
	makeRound(f)
	return {
		frame = f,
		stroke = UIStyle.stroke(f, colour, 1),
	}
end

--[[
	Makes a ring cover exactly the radii innerRadius..outerRadius. The stroke is
	drawn outside the frame's edge, so the frame takes the inner radius and the
	stroke the difference.
]]
local function placeRing(ring: Ring, innerRadius: number, outerRadius: number)
	local inner = math.max(0, innerRadius)
	local outer = math.max(inner, outerRadius)
	ring.frame.Size = UDim2.fromOffset(inner * 2, inner * 2)
	ring.stroke.Thickness = outer - inner
	ring.stroke.Enabled = outer > inner
end

-- The closing ring's radius when the needle the server times is at `angle`.
local function radiusAtAngle(angleDeg: number, centreDeg: number): number
	local progress = if centreDeg > 0 then angleDeg / centreDeg else 1
	return START_RADIUS + (TARGET_RADIUS - START_RADIUS) * progress
end

--[[
	Which state an angle is in: the same comparison SkillCheckGrade makes (minus
	its 0.01 degree float tolerance, which no eye can see).
]]
local function stateForAngle(angleDeg: number): DisplayState
	if angleDeg < activeZoneStartDeg then
		return "wait"
	elseif angleDeg <= activeZoneStartDeg + activeZoneArcDeg then
		return "now"
	end
	return "late"
end

-- Draws the closing ring, its black edge and its glow, all centred on `radius`.
local function placeClosing(current: Visuals, radius: number)
	local half = CLOSING_WIDTH / 2
	placeRing(current.closing, radius - half, radius + half)
	placeRing(current.closingEdge, radius - half - CLOSING_EDGE, radius + half + CLOSING_EDGE)
	placeRing(
		current.glow,
		radius - half - CLOSING_EDGE - GLOW_WIDTH,
		radius + half + CLOSING_EDGE + GLOW_WIDTH
	)
end

--[[
	Places the white band on exactly bandInner..bandOuter, the black edge lines
	just outside it, and the face filling everything inside it.
]]
local function placeBand(current: Visuals, bandInner: number, bandOuter: number)
	placeRing(current.band, bandInner, bandOuter)
	placeRing(current.bandEdgeInner, bandInner - BAND_EDGE, bandInner)
	placeRing(current.bandEdgeOuter, bandOuter, bandOuter + BAND_EDGE)
	local faceRadius = math.max(0, bandInner - BAND_EDGE)
	current.face.Size = UDim2.fromOffset(faceRadius * 2, faceRadius * 2)
end

-- Paints everything that takes the lift's colour.
local function applyLiftColour(current: Visuals, colour: Color3)
	current.face.BackgroundColor3 = colour
	current.innerRing.Color = colour
	current.closing.stroke.Color = colour
	current.glow.stroke.Color = colour
	current.keyBase.BackgroundColor3 = colour
	-- The tag's mark (whatever UIStyle cue it is: its pieces are the tag's Frames).
	for _, child in ipairs(current.tag:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundColor3 = colour
		end
	end
end

--[[
	Shows the key to press. When the controller's instruction names Space, the
	cap shows just "SPACE", big; otherwise it shows the instruction as written.
]]
local function applyInstruction(current: Visuals, instructionText: string)
	current.instructionText = instructionText
	local mentionsSpace = string.find(string.upper(instructionText), "SPACE", 1, true) ~= nil
	current.keyText.Text = if mentionsSpace then "SPACE" else instructionText
	current.keyCap.Size = UDim2.fromOffset(
		if mentionsSpace then KEYCAP_KEY_WIDTH else KEYCAP_TEXT_WIDTH,
		KEYCAP_HEIGHT + KEYCAP_DEPTH
	)
	current.keyCap.Visible = instructionText ~= ""
end

--[[
	Shows one state. Display only; see the header. `force` re-applies a state
	that is already showing (used when a new check starts).
]]
local function showState(current: Visuals, state: DisplayState, force: boolean?)
	if state == displayState and not force then
		return
	end
	displayState = state
	current.wordScale.Scale = 1

	if state == "now" then
		current.band.stroke.Transparency = 0
		current.face.BackgroundTransparency = FACE_LIT
		current.word.Text = "NOW!"
		current.word.TextSize = TEXT.big
		current.word.TextColor3 = C.white
		nowShownClock = os.clock()
		current.wordScale.Scale = 1 + POP_SCALE
	elseif state == "late" then
		current.band.stroke.Transparency = BAND_LATE
		current.face.BackgroundTransparency = FACE_FAINT
		current.word.Text = "TOO LATE"
		current.word.TextSize = TEXT.big
		current.word.TextColor3 = C.red
	elseif state == "wait" then
		current.band.stroke.Transparency = BAND_DIM
		current.face.BackgroundTransparency = FACE_FAINT
		current.word.Text = "WAIT..."
		current.word.TextSize = TEXT.heading
		current.word.TextColor3 = C.muted
	else
		current.band.stroke.Transparency = BAND_DIM
		current.face.BackgroundTransparency = FACE_FAINT
		current.word.Text = ""
	end
end

-- The NOW! pop: starts large and settles to normal size in POP_SECONDS.
local function updatePop(current: Visuals)
	if displayState ~= "now" then
		return
	end
	local settled = math.clamp((os.clock() - nowShownClock) / POP_SECONDS, 0, 1)
	current.wordScale.Scale = 1 + POP_SCALE * (1 - settled)
end

local function build(instructionText: string): Visuals
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillCheckUI"
	UIStyle.fitToScreen(gui) -- shrink on short screens so nothing overlaps
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	-- One panel, anchored at its own centre, so it stays centred at any size or scale.
	local holder, body = UIStyle.panel(
		gui,
		"Panel",
		UIStyle.MinigameCentre,
		UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UIStyle.MinigameCentre

	-- The phase name ("DEPTH", "PRESS", "LOCKOUT"), set by run.
	local headline = UIStyle.titleTag(
		holder,
		"Tag",
		"",
		UDim2.fromOffset(-14, -24),
		UDim2.fromOffset(240, 44),
		nil,
		"star"
	)
	local tag = headline.Parent :: Frame

	-- The ring area. Every circle below is centred in it.
	local area = Instance.new("Frame")
	area.Name = "Ring"
	area.AnchorPoint = Vector2.new(0.5, 0.5)
	area.Position = UDim2.new(0.5, 0, 0, RING_CENTRE_Y)
	area.Size = UDim2.fromOffset(FIELD_RADIUS * 2, FIELD_RADIUS * 2)
	area.BackgroundTransparency = 1
	area.ZIndex = 2
	area.Parent = body

	-- The dark disc everything sits on, so the white band and the ring stand out.
	local field = UIStyle.frame(area, "Field", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), C.navyDeep)
	field.AnchorPoint = Vector2.new(0.5, 0.5)
	field.BackgroundTransparency = 0.08
	field.ZIndex = 1
	makeRound(field)
	UIStyle.stroke(field, C.white, 2, 0.7)

	-- The target face, filling the inside of the band. Lights up during NOW.
	local face = UIStyle.frame(area, "Face", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(0, 0), C.yellow)
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.BackgroundTransparency = FACE_FAINT
	face.ZIndex = 2
	makeRound(face)

	-- The inner ring, as in UIStyle.ring.
	local inner = makeRing(area, "InnerRing", C.yellow, 3)
	placeRing(inner, TARGET_RADIUS * 0.5 - 3, TARGET_RADIUS * 0.5)

	-- The success zone (white) and the black lines just outside it, sized per check by run.
	local bandEdgeInner = makeRing(area, "SuccessBandEdgeInner", C.ink, 3)
	local bandEdgeOuter = makeRing(area, "SuccessBandEdgeOuter", C.ink, 3)
	local band = makeRing(area, "SuccessBand", C.white, 4)
	band.stroke.Transparency = BAND_DIM

	-- The star: two thin tapered rays crossed, as in UIStyle.ring.
	for index, rotation in ipairs({ 0, 90 }) do
		local ray = UIStyle.frame(
			area,
			"Star_" .. index,
			UDim2.fromScale(0.5, 0.5),
			UDim2.fromOffset(TARGET_RADIUS * 0.14, TARGET_RADIUS * 0.6),
			C.white,
			rotation
		)
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.ZIndex = 5
		local taper = Instance.new("UIGradient")
		taper.Rotation = 90
		taper.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		taper.Parent = ray
	end

	-- The closing ring: a soft glow, a black edge so it reads over the white band, and the ring itself.
	local glow = makeRing(area, "ClosingGlow", C.yellow, 6)
	glow.stroke.Transparency = GLOW_TRANSPARENCY
	local closingEdge = makeRing(area, "ClosingEdge", C.ink, 7)
	closingEdge.stroke.Transparency = 0.1
	local closing = makeRing(area, "Closing", C.yellow, 8)

	-- The big word in the middle: WAIT... / NOW! / TOO LATE.
	local word = UIStyle.text(
		area,
		"Word",
		UDim2.fromScale(0.5, 0.5),
		UDim2.fromOffset(340, 64),
		TEXT.big,
		C.white,
		UIStyle.heading(),
		Enum.TextXAlignment.Center
	)
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.TextWrapped = false
	word.ZIndex = 10
	local wordStroke = UIStyle.stroke(word, C.ink, 3)
	wordStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local wordScale = Instance.new("UIScale")
	wordScale.Parent = word

	-- The key cap: a white key on a coloured base, sitting on the disc's bottom rim.
	local keyCap = Instance.new("Frame")
	keyCap.Name = "KeyCap"
	keyCap.AnchorPoint = Vector2.new(0.5, 0.5)
	keyCap.Position = UDim2.new(0.5, 0, 0, KEYCAP_Y)
	keyCap.Size = UDim2.fromOffset(KEYCAP_KEY_WIDTH, KEYCAP_HEIGHT + KEYCAP_DEPTH)
	keyCap.BackgroundTransparency = 1
	keyCap.ZIndex = 4
	keyCap.Parent = body
	local keyBase = UIStyle.frame(
		keyCap,
		"Base",
		UDim2.fromOffset(0, KEYCAP_DEPTH),
		UDim2.new(1, 0, 0, KEYCAP_HEIGHT),
		C.yellow
	)
	keyBase.ZIndex = 4
	makeRound(keyBase, UDim.new(0, 8))
	local keyFace = UIStyle.frame(keyCap, "Face", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, KEYCAP_HEIGHT), C.white)
	keyFace.ZIndex = 5
	makeRound(keyFace, UDim.new(0, 8))
	UIStyle.stroke(keyFace, C.ink, 2)
	local keyText = UIStyle.text(
		keyFace,
		"Key",
		UDim2.fromOffset(8, 0),
		UDim2.new(1, -16, 1, 0),
		TEXT.heading,
		C.ink,
		UIStyle.heading(),
		Enum.TextXAlignment.Center
	)
	keyText.ZIndex = 5

	-- The attempt line: kg, % of max and difficulty.
	local detail = UIStyle.text(
		body,
		"Detail",
		UDim2.new(0.5, 0, 0, DETAIL_Y),
		UDim2.fromOffset(PANEL_WIDTH - 40, 24),
		TEXT.body,
		C.white,
		UIStyle.font(Enum.FontWeight.Bold),
		Enum.TextXAlignment.Center
	)
	detail.AnchorPoint = Vector2.new(0.5, 0.5)
	detail.ZIndex = 4

	-- The server's verdict, in the key cap's place.
	local verdict = UIStyle.text(
		body,
		"Verdict",
		UDim2.new(0.5, 0, 0, VERDICT_Y),
		UDim2.fromOffset(PANEL_WIDTH - 24, VERDICT_HEIGHT),
		TEXT.big,
		C.white,
		UIStyle.heading(),
		Enum.TextXAlignment.Center
	)
	verdict.AnchorPoint = Vector2.new(0.5, 0.5)
	verdict.ZIndex = 6
	local verdictStroke = UIStyle.stroke(verdict, C.ink, 3)
	verdictStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	local built: Visuals = {
		gui = gui,
		headline = headline,
		tag = tag,
		keyCap = keyCap,
		keyBase = keyBase,
		keyFace = keyFace,
		keyText = keyText,
		instructionText = instructionText,
		detail = detail,
		verdict = verdict,
		word = word,
		wordScale = wordScale,
		face = face,
		innerRing = inner.stroke,
		band = band,
		bandEdgeInner = bandEdgeInner,
		bandEdgeOuter = bandEdgeOuter,
		closing = closing,
		closingEdge = closingEdge,
		glow = glow,
	}
	applyInstruction(built, instructionText)
	placeBand(built, TARGET_RADIUS, TARGET_RADIUS)
	placeClosing(built, START_RADIUS)
	showState(built, "idle", true)
	return built
end

--[[
	Attaches the UI to a parent (the player's PlayerGui). Call once.

	`instructionText` is supplied by the controller, because the controller owns
	the key bindings. Passing it in stops the on-screen prompt from drifting out
	of sync with the key that actually works.
]]
function SkillCheckUI.mount(parent: Instance, instructionText: string)
	if visuals ~= nil then
		return
	end
	local built = build(instructionText)
	built.gui.Parent = parent
	visuals = built
end

local function stopTracking()
	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end
	activeStartClock = nil
	activeReport = nil
end

--[[
	Ends the running check exactly once and reports the outcome upward.
]]
local function finish(pressTimeSeconds: number?)
	if activeFinished then
		return
	end
	activeFinished = true

	local report = activeReport
	stopTracking()

	if report then
		report(pressTimeSeconds)
	end
end

-- A short bright flash of the closing ring's glow: the press landed.
local function flash(current: Visuals)
	current.glow.stroke.Transparency = 0.15
	task.delay(FLASH_SECONDS, function()
		current.glow.stroke.Transparency = GLOW_TRANSPARENCY
	end)
end

--[[
	Runs one challenge.

	`report` is called exactly once, with the press time in seconds, or nil if the
	ring ran out before any press. The caller supplies the press by calling
	pressNow; this module never reads input itself.
]]
function SkillCheckUI.run(challenge: any, report: PressReporter)
	local current = visuals
	if current == nil then
		return
	end

	stopTracking()

	-- The zone's centre is where the ring reaches TARGET_RADIUS.
	local centreDeg = challenge.targetStartDeg + challenge.targetArcDeg / 2
	activeSpeed = challenge.needleSpeedDegPerSec
	activeCentreDeg = centreDeg
	activeZoneStartDeg = challenge.targetStartDeg
	activeZoneArcDeg = challenge.targetArcDeg

	-- The band covers exactly the radii the ring passes through inside the zone.
	local bandOuter = radiusAtAngle(challenge.targetStartDeg, centreDeg)
	local bandInner = radiusAtAngle(challenge.targetStartDeg + challenge.targetArcDeg, centreDeg)
	placeBand(current, bandInner, bandOuter)

	activeLiftColour = liftColourFor(challenge.phase)
	applyLiftColour(current, activeLiftColour)
	current.glow.stroke.Transparency = GLOW_TRANSPARENCY

	current.headline.Text = challenge.displayName
	current.keyCap.Visible = current.instructionText ~= ""
	current.detail.Text = string.format(
		"%.1f kg  -  %.0f%%  -  difficulty %.0f",
		challenge.attemptWeightKg,
		challenge.intensityPercent,
		challenge.baseDifficulty
	)
	current.verdict.Text = ""
	placeClosing(current, START_RADIUS)
	showState(current, stateForAngle(0), true)
	current.gui.Enabled = true

	local startClock = os.clock()
	activeStartClock = startClock
	activeReport = report
	activeFinished = false

	activeConnection = RunService.RenderStepped:Connect(function()
		if activeFinished then
			return
		end

		local elapsed = os.clock() - startClock
		-- The same angle the server grades, turned into the ring's radius and the state.
		local angle = challenge.needleSpeedDegPerSec * elapsed
		placeClosing(current, radiusAtAngle(angle, centreDeg))

		if elapsed >= challenge.timeoutSeconds then
			-- The ring passed the zone without a press.
			showState(current, "late")
			finish(nil)
			return
		end

		showState(current, stateForAngle(angle))
		updatePop(current)
	end)
end

--[[
	Registers the player's press. Called by the controller that owns input.

	The press is timed from the same clock the ring is drawn from, so what the
	player saw on screen is exactly what gets reported to the server. The ring is
	left where the press caught it, so the player can see how close it was.

	Does nothing when no check is running, so a stray press cannot resolve a check
	that has already ended.
]]
function SkillCheckUI.pressNow()
	local startClock = activeStartClock
	if activeFinished or startClock == nil then
		return
	end
	local elapsed = os.clock() - startClock

	local current = visuals
	if current ~= nil then
		local angle = activeSpeed * elapsed
		placeClosing(current, radiusAtAngle(angle, activeCentreDeg))
		showState(current, stateForAngle(angle))
		current.wordScale.Scale = 1
		if displayState == "wait" then
			-- Caught before the zone: no WAIT any more; the verdict will say.
			current.word.Text = ""
		end
		flash(current)
	end

	finish(elapsed)
end

--[[
	Shows the server's verdict under the ring, in the key cap's place.

	The outcome is binary, so there is no grade to append. A good lift is white
	and a no lift is red, like a meet's lights; the closing ring takes the same
	colour where it stopped.
]]
function SkillCheckUI.showVerdict(verdictText: string, passed: boolean)
	local current = visuals
	if current == nil then
		return
	end

	-- A verdict always ends the check, even if one were somehow still live.
	activeFinished = true
	stopTracking()

	local color = if passed then C.white else C.red

	applyInstruction(current, "")
	current.detail.Text = ""
	current.word.Text = ""
	current.wordScale.Scale = 1
	current.verdict.TextColor3 = color
	current.verdict.Text = verdictText
	current.closing.stroke.Color = color
	current.glow.stroke.Color = color

	--[[
		This does NOT schedule its own disappearance, for the same reason ControlUI
		does not: a phase UI cannot know when the next phase needs the screen. The
		controller sequencing the attempt calls hide().
	]]
end

--[[
	Clears the check from the screen immediately.
]]
function SkillCheckUI.hide()
	local current = visuals
	if current == nil then
		return
	end

	activeFinished = true
	stopTracking()

	current.gui.Enabled = false
	current.verdict.Text = ""
	current.headline.Text = ""
	current.detail.Text = ""
	placeBand(current, TARGET_RADIUS, TARGET_RADIUS)
	placeClosing(current, START_RADIUS)
	showState(current, "idle", true)
end

--[[
	Restores the instruction (the key cap), which showVerdict clears.
]]
function SkillCheckUI.setInstruction(instructionText: string)
	local current = visuals
	if current ~= nil then
		applyInstruction(current, instructionText)
	end
end

--[[
	True while a check is on screen awaiting a press.

	The controller reads this to decide whether the attempt key means "press the
	running check" or "start a new attempt".
]]
function SkillCheckUI.isRunning(): boolean
	return not activeFinished
end

return SkillCheckUI
