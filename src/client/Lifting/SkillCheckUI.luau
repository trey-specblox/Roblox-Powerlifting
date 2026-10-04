--!strict
--[[
	SkillCheckUI
	Client / Lifting

	Draws the circular skill check and reports when the player pressed.

	Everything is built in code so there are no Studio GUI assets to keep in sync
	with Rojo.

	HOW THE NEEDLE PIVOTS

	The needle is a child of a square PIVOT container that is exactly the size of
	the circle, centred on it, with AnchorPoint 0.5, 0.5. Only the container's
	Rotation changes.

	This matters. Rotating the needle frame directly makes its pivot depend on how
	Rotation and AnchorPoint interact, which is easy to get subtly wrong and reads
	as a line sweeping ACROSS the circle rather than a hand sweeping around its
	centre. Because the container's anchor point and its centre are the same point,
	and that point is the circle's centre, it pivots correctly regardless.

	The needle sits in the container's upper half, running from the centre outward,
	so 0 degrees points at 12 o'clock and increasing rotation sweeps clockwise.

	HOW THE ZONES ARE DRAWN WITHOUT IMAGES

	Roblox UI cannot draw an arc, so each zone is a row of small frames placed
	around the rim, one every few degrees. A point at angle A sits at
	(sin A, -cos A) from the centre.

	This module decides nothing about gameplay. It renders the numbers the server
	sent and reports when the key went down. The verdict comes back from the
	server.
]]

local RunService = game:GetService("RunService")

local SkillCheckUI = {}

-- Visual constants. Presentation only; no effect on difficulty or timing.
local CIRCLE_PIXELS = 300
local RING_THICKNESS = 16
-- Zones are tiled finely so their edges are precise.
local SEGMENT_STEP_DEGREES = 2
-- The track is a solid band with no edges that matter, so it can be coarser.
local TRACK_STEP_DEGREES = 4
local NEEDLE_WIDTH = 6
local TIP_SIZE = 18
local HUB_SIZE = 20

local COLOR_RING = Color3.fromRGB(48, 52, 60)
-- The one and only target. Inside it succeeds, outside it fails.
local COLOR_TARGET = Color3.fromRGB(255, 214, 92)
local COLOR_NEEDLE = Color3.fromRGB(236, 240, 246)
local COLOR_TIP = Color3.fromRGB(255, 255, 255)
local COLOR_HUB = Color3.fromRGB(24, 27, 33)
local COLOR_PASS = Color3.fromRGB(96, 214, 128)
local COLOR_FAIL = Color3.fromRGB(240, 92, 92)

export type PressReporter = (pressTimeSeconds: number?) -> ()

type Visuals = {
	gui: ScreenGui,
	circle: Frame,
	-- The rotating container. Its Rotation is the needle angle.
	pivot: Frame,
	headline: TextLabel,
	instruction: TextLabel,
	detail: TextLabel,
	verdict: TextLabel,
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
local segments: { Frame } = {}

local function radiusPixels(): number
	return CIRCLE_PIXELS / 2
end

--[[
	Distance from the centre to the middle of the ring band. The needle's tip sits
	here, so it visibly touches the coloured zone.
]]
local function ringCentreRadius(): number
	return radiusPixels() - RING_THICKNESS / 2
end

--[[
	Places one small frame on the rim at the given angle.

	`collect` receives the frame when it belongs to a single check and must be
	cleaned up afterwards. Pass nil for permanent scenery such as the track.
]]
local function addSegment(
	parent: Frame,
	angleDegrees: number,
	color: Color3,
	stepDegrees: number,
	zIndex: number,
	collect: { Frame }?
)
	local radians = math.rad(angleDegrees)
	local r = ringCentreRadius()

	local segment = Instance.new("Frame")
	-- Anchor and centre coincide, so this frame's own rotation is unambiguous.
	segment.AnchorPoint = Vector2.new(0.5, 0.5)
	segment.Position = UDim2.new(
		0.5,
		math.sin(radians) * r,
		0.5,
		-math.cos(radians) * r
	)
	segment.Rotation = angleDegrees
	-- Slight overlap so neighbouring segments read as a continuous band.
	segment.Size = UDim2.fromOffset(
		math.ceil(math.rad(stepDegrees) * r) + 2,
		RING_THICKNESS
	)
	segment.BackgroundColor3 = color
	segment.BorderSizePixel = 0
	segment.ZIndex = zIndex
	segment.Parent = parent

	if collect then
		table.insert(collect, segment)
	end
end

--[[
	Draws an arc as a band of segments.

	The track, the success zone and the perfect zone all go through here, so they
	share one radius and one thickness and therefore line up exactly. An earlier
	version drew the track with a UIStroke instead, which renders OUTSIDE the
	frame's bounds and left the coloured zones sitting visibly inside the track
	rather than on it.
]]
local function drawArc(
	parent: Frame,
	startDegrees: number,
	arcDegrees: number,
	color: Color3,
	stepDegrees: number,
	zIndex: number,
	collect: { Frame }?
)
	if arcDegrees <= 0 then
		return
	end

	local angle = startDegrees
	local finish = startDegrees + arcDegrees

	while angle < finish do
		addSegment(parent, angle, color, stepDegrees, zIndex, collect)
		angle += stepDegrees
	end
	-- Always mark the exact end so the zone's edge is truthful.
	addSegment(parent, finish, color, stepDegrees, zIndex, collect)
end

local function clearSegments()
	for _, segment in ipairs(segments) do
		segment:Destroy()
	end
	segments = {}
end

--[[
	Builds the rotating needle assembly: a pivot container holding a shaft that
	runs from the centre outward, plus a bright round tip that marks the exact
	contact point.
]]
local function buildNeedle(circle: Frame): Frame
	local pivot = Instance.new("Frame")
	pivot.Name = "NeedlePivot"
	pivot.AnchorPoint = Vector2.new(0.5, 0.5)
	pivot.Position = UDim2.fromScale(0.5, 0.5)
	pivot.Size = UDim2.fromOffset(CIRCLE_PIXELS, CIRCLE_PIXELS)
	pivot.BackgroundTransparency = 1
	pivot.ZIndex = 5
	pivot.Parent = circle

	--[[
		The shaft runs from the container's centre straight up. AnchorPoint 0.5, 1
		puts its bottom edge on the centre, and its height carries the tip out to
		the ring band.
	]]
	local shaft = Instance.new("Frame")
	shaft.Name = "Shaft"
	shaft.AnchorPoint = Vector2.new(0.5, 1)
	shaft.Position = UDim2.fromScale(0.5, 0.5)
	shaft.Size = UDim2.fromOffset(NEEDLE_WIDTH, ringCentreRadius())
	shaft.BackgroundColor3 = COLOR_NEEDLE
	shaft.BorderSizePixel = 0
	shaft.ZIndex = 5
	shaft.Parent = pivot

	local shaftCorner = Instance.new("UICorner")
	shaftCorner.CornerRadius = UDim.new(0, NEEDLE_WIDTH / 2)
	shaftCorner.Parent = shaft

	--[[
		The hit indicator. A circle rather than a triangle: it reads identically at
		every angle, where a triangle would tumble as the needle sweeps. It is
		slightly wider than the ring band, so the overlap with the coloured zone is
		unmistakable.
	]]
	local tip = Instance.new("Frame")
	tip.Name = "Tip"
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.new(0.5, 0, 0.5, -ringCentreRadius())
	tip.Size = UDim2.fromOffset(TIP_SIZE, TIP_SIZE)
	tip.BackgroundColor3 = COLOR_TIP
	tip.BorderSizePixel = 0
	tip.ZIndex = 6
	tip.Parent = pivot

	local tipCorner = Instance.new("UICorner")
	tipCorner.CornerRadius = UDim.new(0.5, 0)
	tipCorner.Parent = tip

	local tipStroke = Instance.new("UIStroke")
	tipStroke.Thickness = 2
	tipStroke.Color = Color3.fromRGB(20, 22, 28)
	tipStroke.Parent = tip

	return pivot
end

local function build(instructionText: string): Visuals
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillCheckUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.45)
	circle.Size = UDim2.fromOffset(CIRCLE_PIXELS, CIRCLE_PIXELS)
	circle.BackgroundTransparency = 1
	circle.Parent = gui

	--[[
		The empty track the needle sweeps over, drawn once and left in place. Built
		from the same segment helper as the zones so all three bands share a radius
		and a thickness, which is what makes the needle's tip land exactly on the
		coloured zone.
	]]
	drawArc(circle, 0, 360, COLOR_RING, TRACK_STEP_DEGREES, 1, nil)

	local headline = Instance.new("TextLabel")
	headline.Name = "Headline"
	headline.AnchorPoint = Vector2.new(0.5, 0.5)
	headline.Position = UDim2.fromScale(0.5, 0.31)
	headline.Size = UDim2.fromOffset(200, 32)
	headline.BackgroundTransparency = 1
	headline.Font = Enum.Font.GothamBold
	headline.TextSize = 26
	headline.TextColor3 = COLOR_NEEDLE
	headline.Text = ""
	headline.ZIndex = 3
	headline.Parent = circle

	-- Sits directly under the phase name, so the control is never a mystery.
	local instruction = Instance.new("TextLabel")
	instruction.Name = "Instruction"
	instruction.AnchorPoint = Vector2.new(0.5, 0.5)
	instruction.Position = UDim2.fromScale(0.5, 0.41)
	instruction.Size = UDim2.fromOffset(240, 18)
	instruction.BackgroundTransparency = 1
	instruction.Font = Enum.Font.GothamMedium
	instruction.TextSize = 13
	instruction.TextColor3 = Color3.fromRGB(150, 160, 175)
	instruction.Text = instructionText
	instruction.ZIndex = 3
	instruction.Parent = circle

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.AnchorPoint = Vector2.new(0.5, 0.5)
	detail.Position = UDim2.fromScale(0.5, 0.68)
	detail.Size = UDim2.fromOffset(260, 20)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 14
	detail.TextColor3 = Color3.fromRGB(176, 184, 196)
	detail.Text = ""
	detail.ZIndex = 3
	detail.Parent = circle

	local pivot = buildNeedle(circle)

	--[[
		The hub is drawn after the needle and above it, so the shaft's inner end is
		covered and the centre reads as a clean pivot point rather than a blunt
		rectangle end.
	]]
	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(HUB_SIZE, HUB_SIZE)
	hub.BackgroundColor3 = COLOR_HUB
	hub.BorderSizePixel = 0
	hub.ZIndex = 7
	hub.Parent = circle

	local hubCorner = Instance.new("UICorner")
	hubCorner.CornerRadius = UDim.new(0.5, 0)
	hubCorner.Parent = hub

	local hubStroke = Instance.new("UIStroke")
	hubStroke.Thickness = 2
	hubStroke.Color = COLOR_NEEDLE
	hubStroke.Parent = hub

	local verdict = Instance.new("TextLabel")
	verdict.Name = "Verdict"
	verdict.AnchorPoint = Vector2.new(0.5, 0.5)
	verdict.Position = UDim2.fromScale(0.5, 0.78)
	verdict.Size = UDim2.fromOffset(520, 40)
	verdict.BackgroundTransparency = 1
	verdict.Font = Enum.Font.GothamBold
	verdict.TextSize = 28
	verdict.TextColor3 = COLOR_NEEDLE
	verdict.Text = ""
	verdict.Parent = gui

	return {
		gui = gui,
		circle = circle,
		pivot = pivot,
		headline = headline,
		instruction = instruction,
		detail = detail,
		verdict = verdict,
	}
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

--[[
	Runs one challenge.

	`report` is called exactly once, with the press time in seconds, or nil if the
	needle ran out before any press. The caller supplies the press by calling
	pressNow; this module never reads input itself.
]]
function SkillCheckUI.run(challenge: any, report: PressReporter)
	local current = visuals
	if current == nil then
		return
	end

	stopTracking()
	clearSegments()

	-- One target zone, drawn above the track.
	drawArc(
		current.circle,
		challenge.targetStartDeg,
		challenge.targetArcDeg,
		COLOR_TARGET,
		SEGMENT_STEP_DEGREES,
		2,
		segments
	)

	current.headline.Text = challenge.displayName
	current.detail.Text = string.format(
		"%.1f kg  -  %.0f%%  -  difficulty %.0f",
		challenge.attemptWeightKg,
		challenge.intensityPercent,
		challenge.baseDifficulty
	)
	current.verdict.Text = ""
	current.pivot.Rotation = 0
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
		-- Only the pivot container rotates, so the needle sweeps around the
		-- circle's exact centre.
		current.pivot.Rotation = challenge.needleSpeedDegPerSec * elapsed

		if elapsed >= challenge.timeoutSeconds then
			-- The needle ran past the zone without a press.
			finish(nil)
		end
	end)
end

--[[
	Registers the player's press. Called by the controller that owns input.

	The press is timed from the same clock the needle is drawn from, so what the
	player saw on screen is exactly what gets reported to the server.

	Does nothing when no check is running, so a stray press cannot resolve a check
	that has already ended.
]]
function SkillCheckUI.pressNow()
	local startClock = activeStartClock
	if activeFinished or startClock == nil then
		return
	end
	finish(os.clock() - startClock)
end

--[[
	Shows the server's verdict and hides the circle.

	The outcome is binary, so there is no grade to append.
]]
function SkillCheckUI.showVerdict(verdictText: string, passed: boolean)
	local current = visuals
	if current == nil then
		return
	end

	-- A verdict always ends the check, even if one were somehow still live.
	activeFinished = true
	stopTracking()
	clearSegments()

	local color = if passed then COLOR_PASS else COLOR_FAIL

	current.headline.Text = ""
	current.instruction.Text = ""
	current.detail.Text = ""
	current.verdict.TextColor3 = color
	current.verdict.Text = verdictText

	current.pivot.Rotation = 0

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
	clearSegments()

	current.gui.Enabled = false
	current.verdict.Text = ""
	current.headline.Text = ""
	current.detail.Text = ""
	current.pivot.Rotation = 0
end

--[[
	Restores the instruction line, which showVerdict clears.
]]
function SkillCheckUI.setInstruction(instructionText: string)
	local current = visuals
	if current ~= nil then
		current.instruction.Text = instructionText
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
