--!strict
--[[
	MeetLiveScreen
	Client / Meet

	Draws a lifter's running minigame on their rack's big screen at the State meet
	(GAME_DESIGN §36.1, server: MeetLiveScreens). Each game looks like the one on
	the lifter's own screen, in the same colours, drawn big enough to read from the stands:

	  Control     the track with the bar and marker, the meter, "CONTROL 27%"
	  Power       the ring closing on its target, MASH! / HOLD!, the holds done
	  Typing      the word's letter boxes, the next words, the bar up to LOCKOUT
	  SkillCheck  the closing ring and the white band, WAIT... / NOW! / TOO LATE

	The panel covers the lifter's card above the facts strip, with their name, lift
	and weight along its top, and shows GOOD LIFT or NO LIFT at the end. Only this
	screen changes: nothing is added to anyone's own view (no-clutter rule).

	Numbers arrive about 10 times a second, so what is drawn glides to them. The
	skill check sends none: its ring moves at a fixed speed, so each screen works it
	out from when the phase started.

	Laid out in pixels on a canvas CANVAS_HEIGHT high, which a UIScale fits to the
	screen: that also scales the rings' strokes and the fixed text sizes together. A
	wider screen (the one facing the benches) just has spare room either side.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalMeetRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))
local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))

local C = UIStyle.Colours

local MeetLiveScreen = {}

local CANVAS_WIDTH = 800
local CANVAS_HEIGHT = 444
-- The share of the screen's height the panel covers: down to LifterDisplay's facts strip.
local PANEL_SHARE = 0.81
local HEADER_HEIGHT = 72
-- How fast what is drawn catches up with the numbers (per second).
local GLIDE_RATE = 14
-- Farther from the camera than this, a screen isn't redrawn between updates.
local DRAW_STUDS = 450
-- The rings on the left, in the same proportion as SkillCheckUI's (90 and 90 x 2.4), and the words on their right.
local RING_START_RADIUS = 124
local RING_TARGET_RADIUS = RING_START_RADIUS / 2.4
local RING_CENTRE_X = 170
local RING_LINE = 7
local WORDS_X = 330
local WORDS_WIDTH = 450

local HEADING = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)

export type Info = { name: string, lift: string, attemptNumber: number, weightKg: number }

type Drawer = {
	-- New numbers from the lifter.
	numbers: (a: number, b: number, c: number, d: number) -> (),
	-- Every frame while it runs.
	step: (alpha: number) -> (),
	-- The phase ended: nothing moves any more.
	freeze: () -> (),
}

export type Panel = {
	gui: Instance,
	root: Frame,
	showPhase: (info: Info, kind: string, challenge: any) -> (),
	numbers: (a: number, b: number, c: number, d: number) -> (),
	step: (dt: number) -> (),
	passed: () -> (),
	verdict: (good: boolean) -> (),
	destroy: () -> (),
}

local function frame(parent: Instance, name: string, x: number, y: number, width: number, height: number, colour: Color3): Frame
	local item = Instance.new("Frame")
	item.Name = name
	item.BorderSizePixel = 0
	item.BackgroundColor3 = colour
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.fromOffset(width, height)
	item.Parent = parent
	return item
end

local function text(parent: Instance, name: string, x: number, y: number, width: number, height: number, colour: Color3,
	font: Font, size: number, align: Enum.TextXAlignment?): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.fromOffset(width, height)
	item.TextColor3 = colour
	item.FontFace = font
	item.TextSize = size
	item.TextScaled = false
	item.TextWrapped = false
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.TextXAlignment = align or Enum.TextXAlignment.Left
	item.Text = ""
	item.Parent = parent
	return item
end

local function edge(parent: Instance, colour: Color3, thickness: number, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = colour
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

-- A ring round (x, y): a round frame with a stroke, as SkillCheckUI draws them. Set its radii with place.
local function ring(parent: Instance, name: string, x: number, y: number, colour: Color3): (Frame, UIStroke, (inner: number, outer: number) -> ())
	local item = Instance.new("Frame")
	item.Name = name
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = UDim2.fromOffset(x, y)
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = item
	local stroke = edge(item, colour, 1)
	item.Parent = parent
	return item, stroke, function(inner: number, outer: number)
		item.Size = UDim2.fromOffset(inner * 2, inner * 2)
		stroke.Thickness = math.max(0, outer - inner)
		stroke.Enabled = outer > inner
	end
end

local function disc(parent: Instance, name: string, x: number, y: number, radius: number, colour: Color3): Frame
	local item = frame(parent, name, x - radius, y - radius, radius * 2, radius * 2, colour)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = item
	return item
end

local function liftColour(lift: string): Color3
	return UIStyle.LiftColours[lift] or C.yellow
end

-- ---------------------------------------------------------------- the four games

local function drawControl(body: Frame, height: number, lift: string, challenge: any): Drawer
	local colour = liftColour(lift)
	local trackX, trackWidth = 60, 110
	local track = frame(body, "Track", trackX, 0, trackWidth, height, C.navyDeep)
	edge(track, C.white, 2)
	local bar = frame(track, "Bar", 6, 0, trackWidth - 12, height * (challenge.barHeight or 0.3), colour)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.BackgroundTransparency = 0.3
	edge(bar, C.white, 1, 0.2)
	local marker = frame(track, "Marker", -8, 0, trackWidth + 16, 7, C.white)
	marker.AnchorPoint = Vector2.new(0, 0.5)
	marker.ZIndex = 2
	edge(marker, C.ink, 2)
	local meter = frame(body, "Meter", trackX + trackWidth + 16, 0, 36, height, C.empty)
	edge(meter, C.white, 1, 0.4)
	local fill = frame(meter, "Fill", 0, height, 36, 0, colour)
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	local reading = text(body, "Reading", 250, height * 0.26, 530, 70, C.white, HEADING, 56)
	local onBar = text(body, "OnBar", 250, height * 0.26 + 76, 530, 44, C.white, BOLD, 34)

	local wanted = { bar = 0.5, marker = 0.5, meter = 0, inside = true }
	local shown = { bar = 0.5, marker = 0.5, meter = 0 }
	return {
		numbers = function(a, b, c, d)
			wanted.bar, wanted.marker, wanted.inside, wanted.meter = a, b, c == 1, d
		end,
		step = function(alpha)
			shown.bar += (wanted.bar - shown.bar) * alpha
			shown.marker += (wanted.marker - shown.marker) * alpha
			shown.meter += (wanted.meter - shown.meter) * alpha
			-- 0 is the bottom of the track.
			bar.Position = UDim2.fromOffset(6, (1 - shown.bar) * height)
			marker.Position = UDim2.fromOffset(-8, (1 - shown.marker) * height)
			marker.BackgroundColor3 = if wanted.inside then C.white else C.red
			fill.Size = UDim2.fromOffset(36, shown.meter * height)
			reading.Text = string.format("CONTROL  %d%%", math.floor(wanted.meter * 100))
			onBar.Text = if wanted.inside then "MARKER ON THE BAR" else "MARKER OFF THE BAR"
			onBar.TextColor3 = if wanted.inside then C.white else C.red
		end,
		freeze = function() end,
	}
end

local POWER_CUES = {
	[0] = { words = "MASH!", tag = C.ink, ink = C.white },
	[1] = { words = "GET READY TO HOLD", tag = C.ink, ink = C.yellow },
	[2] = { words = "HOLD!", tag = C.yellow, ink = C.ink },
	[3] = { words = "POWER!", tag = C.white, ink = C.ink },
}

local function drawPower(body: Frame, height: number, lift: string, challenge: any): Drawer
	local colour = liftColour(lift)
	local middle = height / 2
	disc(body, "Field", RING_CENTRE_X, middle, RING_START_RADIUS + RING_LINE, C.navyDeep)
	local target = disc(body, "Target", RING_CENTRE_X, middle, RING_TARGET_RADIUS, C.navy)
	local targetEdge = edge(target, colour, RING_LINE)
	local _, closingStroke, placeClosing = ring(body, "Closing", RING_CENTRE_X, middle, colour)
	placeClosing(RING_START_RADIUS, RING_START_RADIUS + RING_LINE)

	local top = height * 0.06
	local tag = frame(body, "Cue", WORDS_X, top, WORDS_WIDTH, 62, C.ink)
	edge(tag, C.white, 2)
	local cueText = text(tag, "Text", 8, 0, WORDS_WIDTH - 16, 62, C.white, HEADING, 36, Enum.TextXAlignment.Center)
	local reading = text(body, "Reading", WORDS_X, top + 72, WORDS_WIDTH, 62, C.white, HEADING, 50)
	local holdsTotal = challenge.holds or 0
	local holds = text(body, "Holds", WORDS_X, top + 134, WORDS_WIDTH, 38, C.white, BOLD, 30)
	local holdBack = frame(body, "HoldBar", WORDS_X, top + 180, WORDS_WIDTH, 22, C.empty)
	edge(holdBack, C.white, 1, 0.4)
	local holdFill = frame(holdBack, "Fill", 0, 0, 0, 22, C.yellow)

	local wanted = { ring = 0, cue = 0, hold = 0, done = 0 }
	local shownRing = 0
	return {
		numbers = function(a, b, c, d)
			wanted.ring, wanted.cue, wanted.hold, wanted.done = a, b, c, d
		end,
		step = function(alpha)
			shownRing += (wanted.ring - shownRing) * alpha
			local radius = RING_START_RADIUS + (RING_TARGET_RADIUS - RING_START_RADIUS) * shownRing
			placeClosing(radius, radius + RING_LINE)
			local cue = POWER_CUES[wanted.cue] or POWER_CUES[0]
			cueText.Text = cue.words
			cueText.TextColor3 = cue.ink
			tag.BackgroundColor3 = cue.tag
			local ringColour = if wanted.cue == 0 then colour elseif wanted.cue == 1 then C.yellow else C.white
			closingStroke.Color = ringColour
			targetEdge.Color = ringColour
			reading.Text = string.format("POWER  %d%%", math.floor(wanted.ring * 100))
			holds.Text = if holdsTotal > 0 then string.format("HOLDS  %d/%d", wanted.done, holdsTotal) else ""
			holdBack.Visible = wanted.cue == 2
			holdFill.Size = UDim2.fromOffset(WORDS_WIDTH * wanted.hold, 22)
		end,
		freeze = function() end,
	}
end

local function drawTyping(body: Frame, height: number, lift: string, challenge: any): Drawer
	local colour = liftColour(lift)
	local cues: { any } = challenge.cues or {}
	-- Which word each letter number belongs to, and where each word starts.
	local letterWord: { number } = {}
	local wordStart: { number } = {}
	local count = 0
	for index, cue in ipairs(cues) do
		wordStart[index] = count + 1
		for _ in ipairs(cue.tokens) do
			count += 1
			letterWord[count] = index
		end
	end

	local rowWidth, rowY = 640, height * 0.14
	local rowHolder = Instance.new("Frame")
	rowHolder.Name = "Row"
	rowHolder.BackgroundTransparency = 1
	rowHolder.Position = UDim2.fromOffset(16, rowY)
	rowHolder.Size = UDim2.fromOffset(rowWidth, 100)
	rowHolder.Parent = body
	local nextWords = text(body, "Next", 16, rowY + 124, rowWidth, 44, C.muted, BOLD, 32, Enum.TextXAlignment.Center)

	-- The bar up to LOCKOUT, on the right.
	local barX = 690
	local percent = text(body, "Percent", barX - 25, 0, 110, 34, colour, HEADING, 30, Enum.TextXAlignment.Center)
	local back = frame(body, "Bar", barX, 36, 50, height - 36, C.empty)
	edge(back, C.white, 1, 0.4)
	local fill = frame(back, "Fill", 0, height - 36, 50, 0, colour)
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)

	type Box = { frame: Frame, letter: TextLabel, edge: UIStroke }
	local boxes: { Box } = {}
	local shownWord = 0
	local shownCount = 0
	local boxSize = 80

	local function showWord(index: number)
		shownWord = index
		local cue = cues[index]
		local tokens: { string } = if cue then cue.tokens else {}
		shownCount = #tokens
		boxSize = if shownCount > 0 then math.min(90, math.floor((rowWidth - (shownCount - 1) * 8) / shownCount)) else 90
		local width = shownCount * boxSize + math.max(shownCount - 1, 0) * 8
		for position = 1, math.max(shownCount, #boxes) do
			local box = boxes[position]
			if position > shownCount then
				if box then
					box.frame.Visible = false
				end
			else
				if box == nil then
					local item = frame(rowHolder, "Key" .. position, 0, 0, 80, 80, C.empty)
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0, 8)
					corner.Parent = item
					box = { frame = item, edge = edge(item, C.white, 2), letter = text(item, "Letter", 0, 0, 80, 80, C.white, HEADING, 50,
						Enum.TextXAlignment.Center) }
					boxes[position] = box
				end
				assert(box)
				box.frame.Visible = true
				box.frame.Position = UDim2.fromOffset((rowWidth - width) / 2 + (position - 1) * (boxSize + 8), 50 - boxSize / 2)
				box.frame.Size = UDim2.fromOffset(boxSize, boxSize)
				box.letter.Size = UDim2.fromOffset(boxSize, boxSize)
				box.letter.TextSize = math.floor(boxSize * 0.62)
				box.letter.Text = tokens[position]
			end
		end
		local coming: { string } = {}
		for offset = 1, 2 do
			local following = cues[index + offset]
			if following then
				table.insert(coming, following.label)
			end
		end
		nextWords.Text = table.concat(coming, "   ·   ")
	end

	local wanted = { bar = 0, letter = 1, missed = false, done = false }
	local shownBar = 0
	return {
		numbers = function(a, b, c, d)
			wanted.bar, wanted.letter, wanted.missed, wanted.done = a, b, c == 1, d == 1
		end,
		step = function(alpha)
			shownBar += (wanted.bar - shownBar) * alpha
			fill.Size = UDim2.fromOffset(50, shownBar * (height - 36))
			fill.BackgroundColor3 = if wanted.done then C.white else colour
			percent.Text = string.format("%d%%", math.floor(wanted.bar * 100))
			percent.TextColor3 = if wanted.done then C.white else colour
			local word = letterWord[wanted.letter] or #cues
			if word ~= shownWord and word > 0 then
				showWord(word)
			end
			local first = wordStart[word] or 1
			for position = 1, shownCount do
				local box = boxes[position]
				local letter = first + position - 1
				if wanted.done then
					box.frame.BackgroundColor3, box.letter.TextColor3, box.edge.Color = C.white, C.ink, C.white
					box.edge.Thickness = 2
				elseif letter < wanted.letter then
					box.frame.BackgroundColor3, box.letter.TextColor3, box.edge.Color = colour, C.white, C.white
					box.edge.Thickness = 2
				elseif letter == wanted.letter then
					box.frame.BackgroundColor3 = if wanted.missed then C.red else C.navyDeep
					box.letter.TextColor3 = C.white
					box.edge.Color = if wanted.missed then C.red else colour
					box.edge.Thickness = 5
				else
					box.frame.BackgroundColor3, box.letter.TextColor3, box.edge.Color = C.empty, C.muted, C.white
					box.edge.Thickness = 2
				end
			end
		end,
		freeze = function() end,
	}
end

local function drawSkillCheck(body: Frame, height: number, lift: string, challenge: any): Drawer
	local colour = liftColour(lift)
	local middle = height / 2
	local zoneStart: number = challenge.targetStartDeg or 0
	local zoneArc: number = challenge.targetArcDeg or 0
	local speed: number = challenge.speed or 0
	local timeout: number = challenge.timeoutSeconds or 0
	local centre = zoneStart + zoneArc / 2
	local function radiusAt(angle: number): number
		local share = if centre > 0 then angle / centre else 1
		return RING_START_RADIUS + (RING_TARGET_RADIUS - RING_START_RADIUS) * share
	end

	disc(body, "Field", RING_CENTRE_X, middle, RING_START_RADIUS + RING_LINE, C.navyDeep)
	-- The band is the real window, as on the lifter's screen: a harder check has a thinner band.
	local bandInner, bandOuter = radiusAt(zoneStart + zoneArc), radiusAt(zoneStart)
	local face = disc(body, "Face", RING_CENTRE_X, middle, math.max(1, bandInner), colour)
	local _, bandStroke, placeBand = ring(body, "Band", RING_CENTRE_X, middle, C.white)
	placeBand(bandInner, bandOuter)
	local _, closingStroke, placeClosing = ring(body, "Closing", RING_CENTRE_X, middle, colour)
	placeClosing(RING_START_RADIUS, RING_START_RADIUS + RING_LINE)

	local title = text(body, "Title", WORDS_X, height * 0.14, WORDS_WIDTH, 44, C.white, BOLD, 34)
	title.Text = string.upper(tostring(challenge.displayName or ""))
	local word = text(body, "Word", WORDS_X, height * 0.14 + 50, WORDS_WIDTH, 100, C.white, HEADING, 78)

	local started = os.clock()
	local frozen = false
	local function draw()
		local elapsed = os.clock() - started
		local angle = speed * elapsed
		placeClosing(math.max(0, radiusAt(angle)), math.max(0, radiusAt(angle)) + RING_LINE)
		if elapsed >= timeout then
			word.Text, word.TextColor3 = "TOO LATE", C.red
			bandStroke.Transparency, face.BackgroundTransparency = 0.6, 0.82
			frozen = true
		elseif angle < zoneStart then
			word.Text, word.TextColor3 = "WAIT...", C.white
			bandStroke.Transparency, face.BackgroundTransparency = 0.45, 0.82
		elseif angle <= zoneStart + zoneArc then
			word.Text, word.TextColor3 = "NOW!", colour
			bandStroke.Transparency, face.BackgroundTransparency = 0, 0.05
		else
			word.Text, word.TextColor3 = "TOO LATE", C.red
			bandStroke.Transparency, face.BackgroundTransparency = 0.6, 0.82
		end
	end
	draw()
	return {
		numbers = function() end,
		step = function()
			if not frozen then
				draw()
			end
		end,
		freeze = function()
			frozen = true
			closingStroke.Color = C.white
		end,
	}
end

local DRAWERS: { [string]: (Frame, number, string, any) -> Drawer } = {
	Control = drawControl,
	Power = drawPower,
	Typing = drawTyping,
	SkillCheck = drawSkillCheck,
}

-- ---------------------------------------------------------------- the panel on one screen

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

--[[
	A panel on `gui`, the rack's SurfaceGui from LifterDisplay. `screenSize`: the
	screen in pixels, its width and height.
]]
function MeetLiveScreen.buildPanel(gui: Instance, screenSize: Vector2): Panel
	-- The whole screen on the canvas: as high as it fits, and at least CANVAS_WIDTH wide.
	local fit = math.min(screenSize.Y / CANVAS_HEIGHT, screenSize.X / CANVAS_WIDTH)
	local fullWidth = screenSize.X / fit
	local aside = (fullWidth - CANVAS_WIDTH) / 2
	local panelHeight = math.floor(screenSize.Y / fit * PANEL_SHARE)
	local bodyTop = HEADER_HEIGHT + 6
	local bodyHeight = panelHeight - bodyTop - 8

	local root = frame(gui, "LivePanel", 0, 0, fullWidth, panelHeight, C.navy)
	root.ZIndex = 5
	local scale = Instance.new("UIScale")
	scale.Scale = fit
	scale.Parent = root

	local headerBack = frame(root, "HeaderBack", 0, 0, fullWidth, HEADER_HEIGHT, C.ink)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(aside, 0)
	header.Size = UDim2.fromOffset(CANVAS_WIDTH, HEADER_HEIGHT)
	header.Parent = headerBack
	local nameText = text(header, "LifterName", 16, 2, 510, 40, C.white, HEADING, 32)
	local liftText = text(header, "Lift", 16, 42, 510, 28, C.white, BOLD, 22)
	local weightText = text(header, "Weight", 530, 0, 254, HEADER_HEIGHT, C.yellow, HEADING, 46, Enum.TextXAlignment.Right)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(aside, bodyTop)
	body.Size = UDim2.fromOffset(CANVAS_WIDTH, bodyHeight)
	body.Parent = root

	local slab = frame(root, "Slab", aside + 90, bodyTop + bodyHeight / 2 - 70, CANVAS_WIDTH - 180, 140, C.white)
	slab.Rotation = -2
	slab.ZIndex = 10
	slab.Visible = false
	edge(slab, C.white, 4)
	local slabText = text(slab, "Text", 10, 0, CANVAS_WIDTH - 200, 140, C.ink, HEADING, 88, Enum.TextXAlignment.Center)
	slabText.ZIndex = 11

	local drawer: Drawer? = nil
	local running: Frame? = nil

	local function clearGame()
		if running then
			running:Destroy()
		end
		running, drawer = nil, nil
	end

	local panel = {} :: Panel
	panel.gui = gui
	panel.root = root

	function panel.showPhase(info: Info, kind: string, challenge: any)
		clearGame()
		slab.Visible = false
		nameText.Text = string.upper(info.name)
		liftText.Text = string.format("%s  ·  ATTEMPT %d", string.upper(info.lift), info.attemptNumber)
		weightText.Text = kgText(info.weightKg) .. " KG"
		local holder = Instance.new("Frame")
		holder.Name = "Game"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = body
		running = holder
		local draw = DRAWERS[kind]
		if draw then
			drawer = draw(holder, bodyHeight, info.lift, challenge)
		end
	end

	function panel.numbers(a: number, b: number, c: number, d: number)
		if drawer then
			drawer.numbers(a, b, c, d)
		end
	end

	function panel.step(dt: number)
		if drawer then
			drawer.step(1 - math.exp(-GLIDE_RATE * dt))
		end
	end

	local function showSlab(words: string, fill: Color3, ink: Color3)
		if drawer then
			drawer.freeze()
		end
		slab.BackgroundColor3 = fill
		slabText.Text = words
		slabText.TextColor3 = ink
		slab.Visible = true
	end

	function panel.passed()
		showSlab("PASSED", C.white, C.ink)
	end

	function panel.verdict(good: boolean)
		if good then
			showSlab("GOOD LIFT", C.white, C.ink)
		else
			showSlab("NO LIFT", C.red, C.white)
		end
	end

	function panel.destroy()
		root:Destroy()
	end

	return panel
end

-- ---------------------------------------------------------------- following the server

-- Each lift's panels: one per screen of its rack.
local panels: { [number]: { Panel } } = {}
local started = false

-- The screen's size in pixels, worked out from the part it is on (a screen far away may not have been drawn yet).
local function sizeOf(gui: Instance): Vector2?
	local part = gui.Parent
	if not gui:IsA("SurfaceGui") or part == nil or not part:IsA("BasePart") then
		return nil
	end
	local face, size = gui.Face, part.Size
	local studs = if face == Enum.NormalId.Front or face == Enum.NormalId.Back then Vector2.new(size.X, size.Y)
		elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then Vector2.new(size.Z, size.Y)
		else Vector2.new(size.X, size.Z)
	return studs * gui.PixelsPerStud
end

local function onEvent(event: string, id: number, first: any, second: any, third: any, fourth: any)
	local list = panels[id]
	if event == "phase" then
		local guis, info, kind, challenge = first, second, third, fourth
		if list == nil then
			list = {}
			panels[id] = list
			for _, gui in pairs(guis) do
				-- A screen that isn't loaded on this device is simply left out.
				local size = if typeof(gui) == "Instance" then sizeOf(gui) else nil
				if size then
					table.insert(list, MeetLiveScreen.buildPanel(gui, size))
				end
			end
		end
		for _, panel in ipairs(list :: { Panel }) do
			panel.showPhase(info, kind, challenge)
		end
	elseif list == nil then
		return
	elseif event == "stop" then
		for _, panel in ipairs(list) do
			panel.destroy()
		end
		panels[id] = nil
	else
		for _, panel in ipairs(list) do
			if event == "passed" then
				panel.passed()
			elseif event == "verdict" then
				panel.verdict(first)
			end
		end
	end
end

local function update(dt: number)
	if next(panels) == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for id, list in pairs(panels) do
		for index = #list, 1, -1 do
			local panel = list[index]
			local part = panel.gui.Parent
			if part == nil then
				-- The floor was cleared with this screen on it.
				panel.destroy()
				table.remove(list, index)
			elseif eye and part:IsA("BasePart") and (part.Position - eye).Magnitude <= DRAW_STUDS then
				panel.step(dt)
			end
		end
		if #list == 0 then
			panels[id] = nil
		end
	end
end

function MeetLiveScreen.start()
	if started then
		return
	end
	started = true
	assert(Players.LocalPlayer)
	local set = LocalMeetRemotes.waitForClient(ReplicatedStorage)
	set.liveEvent.OnClientEvent:Connect(onEvent)
	set.liveShow.OnClientEvent:Connect(function(id: number, a: number, b: number, c: number, d: number)
		for _, panel in ipairs(panels[id] or {}) do
			panel.numbers(a, b, c, d)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return MeetLiveScreen
