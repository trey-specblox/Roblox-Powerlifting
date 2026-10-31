--!strict
--[[
	UIStyle
	Client / UI

	The ONE look of every screen in the game (GAME_DESIGN.md "One UI style for
	the whole game", user 2026-10-28: "MAKE SURE everything that requires a ui
	has the same style"; picked: yellow, white and dark navy with a faint grid).
	Every screen builds from these pieces instead of making its own frames, so a
	change here changes the whole game.

	The pieces:
		panel        a dark navy panel with a faint grid, a white frame, a thin
		             inner line and a yellow slab peeking out behind it
		titleTag     a slanted black tag with a white edge and heavy italic
		             text, two yellow slashes after it (a panel's heading)
		sectionHead  a small heading inside a panel: text, yellow slashes and a
		             thin white line running on
		button       "outline" (navy, white edge), "primary" (yellow, black
		             text, slashes) or "danger" (red)
		exitButton   a black bar with a white circle and "<": LEAVE, BACK, EXIT
		ring         a target with an outer and an inner ring and a four-point
		             star in the middle, in one colour (the timing checks)
		label        text in the game's typeface

	Colours: the lifts each have one (squat yellow, bench red, deadlift blue);
	a GOOD lift is WHITE and a NO LIFT is RED, like a meet's lights.
]]

local UIStyle = {}

UIStyle.Colours = {
	navy = Color3.fromRGB(14, 22, 54),
	navyDeep = Color3.fromRGB(7, 11, 30),
	grid = Color3.fromRGB(70, 96, 170),
	yellow = Color3.fromRGB(250, 206, 36),
	white = Color3.fromRGB(248, 248, 244),
	ink = Color3.fromRGB(10, 10, 12),
	muted = Color3.fromRGB(150, 160, 192),
	red = Color3.fromRGB(226, 46, 56),
	blue = Color3.fromRGB(70, 146, 255),
	empty = Color3.fromRGB(28, 36, 70),
}
local C = UIStyle.Colours

-- Each lift's colour: its timing ring, its tags.
UIStyle.LiftColours = {
	Squat = C.yellow,
	Bench = C.red,
	Deadlift = C.blue,
} :: { [string]: Color3 }

local FAMILY = "rbxasset://fonts/families/Montserrat.json"

-- The typeface: Montserrat; headings heavy italic.
function UIStyle.font(weight: Enum.FontWeight?, italic: boolean?): Font
	return Font.new(FAMILY, weight or Enum.FontWeight.Bold, if italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
end

function UIStyle.heading(): Font
	return UIStyle.font(Enum.FontWeight.Heavy, true)
end

local function frame(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3, rotation: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.Rotation = rotation or 0
	f.Parent = parent
	return f
end
UIStyle.frame = frame

function UIStyle.label(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3?, font: Font?,
	align: Enum.TextXAlignment?): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Text = ""
	text.TextColor3 = colour or C.white
	text.TextScaled = true
	text.FontFace = font or UIStyle.font()
	text.TextXAlignment = align or Enum.TextXAlignment.Left
	text.Parent = parent
	return text
end

local function stroke(parent: Instance, colour: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end
UIStyle.stroke = stroke

-- Two short yellow slashes, as after a heading ("SCORECARD //").
local function slashes(parent: Instance, position: UDim2, height: number, colour: Color3?)
	for index = 0, 1 do
		local bar = frame(parent, "Slash_" .. index, position + UDim2.fromOffset(index * (height * 0.45), 0),
			UDim2.fromOffset(math.max(3, height * 0.22), height), colour or C.yellow, 25)
		bar.ZIndex = (parent :: any).ZIndex or 1
	end
end
UIStyle.slashes = slashes

--[[
	The small mark after a heading. User 2026-10-28: "Not every title needs a
	double line. Change it up sometimes with different cues." So headings pick
	one of these (each fits a box about 26 px wide and `height` tall, starting at
	`position`):
		"slashes"  two slanted bars //
		"star"     a four-point star
		"chevron"  two arrow tips >>
		"bar"      a thick bar and a small square
		"corner"   an L-shaped bracket in the top right
		"dots"     three dots getting smaller
		"none"     nothing
]]
export type Cue = "slashes" | "star" | "chevron" | "bar" | "corner" | "dots" | "none"

local function cue(parent: Instance, kind: Cue?, position: UDim2, height: number, colour: Color3?)
	local tint = colour or C.yellow
	local z = (parent :: any).ZIndex or 1
	local function piece(name: string, offset: Vector2, size: Vector2, rotation: number?): Frame
		local made = frame(parent, name, position + UDim2.fromOffset(offset.X, offset.Y), UDim2.fromOffset(size.X, size.Y), tint,
			rotation)
		made.ZIndex = z
		return made
	end
	local k = kind or "slashes"
	local h = height
	if k == "slashes" then
		slashes(parent, position, h, colour)
	elseif k == "star" then
		for index, rotation in ipairs({ 0, 90 }) do
			local ray = piece("Star_" .. index, Vector2.new(h * 0.5, h * 0.5), Vector2.new(h * 0.24, h), rotation)
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			local taper = Instance.new("UIGradient")
			taper.Rotation = 90
			taper.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
			})
			taper.Parent = ray
		end
	elseif k == "chevron" then
		for index = 0, 1 do
			local x = index * h * 0.5
			local upper = piece("Chevron_" .. index .. "_A", Vector2.new(x + h * 0.22, h * 0.32), Vector2.new(h * 0.5, h * 0.16), 45)
			upper.AnchorPoint = Vector2.new(0.5, 0.5)
			local lower = piece("Chevron_" .. index .. "_B", Vector2.new(x + h * 0.22, h * 0.68), Vector2.new(h * 0.5, h * 0.16), -45)
			lower.AnchorPoint = Vector2.new(0.5, 0.5)
		end
	elseif k == "bar" then
		piece("Bar", Vector2.new(0, h * 0.38), Vector2.new(h * 0.8, h * 0.24))
		piece("BarDot", Vector2.new(h * 0.95, h * 0.38), Vector2.new(h * 0.24, h * 0.24))
	elseif k == "corner" then
		piece("Corner_Top", Vector2.new(0, 0), Vector2.new(h * 0.9, h * 0.16))
		piece("Corner_Side", Vector2.new(h * 0.74, 0), Vector2.new(h * 0.16, h * 0.9))
	elseif k == "dots" then
		for index, scale in ipairs({ 0.36, 0.26, 0.18 }) do
			local d = h * scale
			local dot = piece("Dot_" .. index, Vector2.new((index - 1) * h * 0.42, (h - d) / 2), Vector2.new(d, d))
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = dot
		end
	end
end
UIStyle.cue = cue

--[[
	A panel: returns the holder (place and size it; nothing is drawn on it) and
	the body (put the content in it). The faint grid is drawn every `GRID`
	pixels over the body's size at the time it is built, so build panels at
	their final size.
]]
local GRID = 22
function UIStyle.panel(parent: Instance, name: string, position: UDim2, size: UDim2): (Frame, Frame)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Position = position
	holder.Size = size
	holder.Parent = parent
	-- The yellow slab behind, peeking out at the bottom right.
	frame(holder, "Back", UDim2.fromOffset(7, 7), UDim2.fromScale(1, 1), C.yellow)
	local body = frame(holder, "Body", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), C.navy)
	stroke(body, C.white, 2)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(C.navy, C.navyDeep)
	shade.Parent = body
	-- The faint grid.
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 1)
	grid.ClipsDescendants = true
	grid.Parent = body
	local width = if size.X.Scale == 0 then size.X.Offset else 1200
	local height = if size.Y.Scale == 0 then size.Y.Offset else 800
	for x = GRID, width, GRID do
		frame(grid, "V", UDim2.fromOffset(x, 0), UDim2.new(0, 1, 1, 0), C.grid).BackgroundTransparency = 0.82
	end
	for y = GRID, height, GRID do
		frame(grid, "H", UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 1), C.grid).BackgroundTransparency = 0.82
	end
	-- A thin inner line.
	local inner = frame(body, "Inner", UDim2.fromOffset(5, 5), UDim2.new(1, -10, 1, -10), C.white)
	inner.BackgroundTransparency = 1
	stroke(inner, C.white, 1, 0.65)
	return holder, body
end

-- A slanted black tag with a white edge: a panel's heading. `accent` colours its mark; `mark` picks it (Cue).
function UIStyle.titleTag(parent: Instance, name: string, text: string, position: UDim2, size: UDim2,
	accent: Color3?, mark: Cue?): TextLabel
	local tag = frame(parent, name, position, size, C.ink, -4)
	tag.ZIndex = 5
	stroke(tag, C.white, 2)
	local label = UIStyle.label(tag, "Text", UDim2.new(0, 12, 0.14, 0), UDim2.new(1, -44, 0.72, 0), C.white, UIStyle.heading())
	label.ZIndex = 5
	label.Text = text
	cue(tag, mark, UDim2.new(1, -30, 0.12, 0), size.Y.Offset * 0.76, accent)
	return label
end

-- A small heading inside a panel: text, its mark (Cue), then a thin line running to `lineTo` pixels.
function UIStyle.sectionHead(parent: Instance, name: string, text: string, position: UDim2, textWidth: number,
	lineTo: number?, mark: Cue?): TextLabel
	local label = UIStyle.label(parent, name, position, UDim2.fromOffset(textWidth, 20), C.white, UIStyle.heading())
	label.Text = text
	cue(parent, mark, position + UDim2.fromOffset(textWidth + 6, 1), 18)
	if lineTo then
		frame(parent, name .. "_Line", position + UDim2.fromOffset(textWidth + 30, 10),
			UDim2.fromOffset(math.max(0, lineTo - textWidth - 30), 2), C.white)
	end
	return label
end

export type ButtonKind = "outline" | "primary" | "danger"

function UIStyle.button(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, kind: ButtonKind,
	onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = text
	button.TextScaled = true
	button.FontFace = if kind == "outline" then UIStyle.font(Enum.FontWeight.Bold) else UIStyle.heading()
	if kind == "primary" then
		button.BackgroundColor3, button.TextColor3 = C.yellow, C.ink
	elseif kind == "danger" then
		button.BackgroundColor3, button.TextColor3 = C.red, C.white
	else
		button.BackgroundColor3, button.TextColor3 = C.navyDeep, C.white
		stroke(button, C.white, 1, 0.3)
	end
	button.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.2, 0)
	padding.PaddingBottom = UDim.new(0.2, 0)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, if kind == "outline" then 10 else 34)
	padding.Parent = button
	if kind ~= "outline" then
		-- Slashes at the right end, outside the padding.
		local holder = Instance.new("Frame")
		holder.Name = "Slashes"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(1, 0.5)
		holder.Position = UDim2.new(1, 30, 0.5, 0)
		holder.Size = UDim2.fromOffset(24, size.Y.Offset * 0.6)
		holder.Parent = button
		-- Chevrons say "go" on an action button.
		cue(holder, "chevron", UDim2.fromOffset(0, 0), size.Y.Offset * 0.6, if kind == "primary" then C.ink else C.white)
	end
	button.Activated:Connect(onClick)
	return button
end

-- LEAVE / BACK / EXIT: a black bar with the word and a white circle holding "<".
function UIStyle.exitButton(parent: Instance, name: string, text: string, position: UDim2, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = UDim2.fromOffset(170, 40)
	button.BackgroundColor3 = C.ink
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = parent
	slashes(button, UDim2.fromOffset(-20, 6), 28, C.ink)
	local label = UIStyle.label(button, "Text", UDim2.fromOffset(14, 8), UDim2.new(1, -66, 1, -16), C.white, UIStyle.heading(),
		Enum.TextXAlignment.Right)
	label.Text = text
	local circle = frame(button, "Circle", UDim2.new(1, -44, 0.5, -15), UDim2.fromOffset(30, 30), C.white)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = circle
	local arrow = UIStyle.label(circle, "Arrow", UDim2.fromScale(0.12, 0.1), UDim2.fromScale(0.76, 0.8), C.ink,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	arrow.Text = "<"
	button.Activated:Connect(onClick)
	return button
end

local function round(target: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = target
end

-- A round gold coin with an inner ring (the money system's coins, GAME_DESIGN 30.6), `size` pixels across.
local COIN_EDGE = Color3.fromRGB(176, 128, 10)
function UIStyle.coin(parent: Instance, position: UDim2, size: number): Frame
	local disc = frame(parent, "Coin", position, UDim2.fromOffset(size, size), C.yellow)
	round(disc)
	stroke(disc, COIN_EDGE, 2)
	local inner = frame(disc, "Ring", UDim2.fromScale(0.22, 0.22), UDim2.fromScale(0.56, 0.56), C.yellow)
	inner.BackgroundTransparency = 1
	round(inner)
	stroke(inner, COIN_EDGE, 2)
	return disc
end

export type Ring = {
	holder: Frame,
	-- How far the outer ring has closed in: 0 = wide open, 1 = on the target.
	setClosing: (amount: number) -> (),
	setColour: (colour: Color3) -> (),
	-- A short flash of the whole target (a press landed).
	flash: () -> (),
}

--[[
	A timing target in one colour: a soft disc, an inner ring and a white
	four-point star at the centre, and an outer ring that closes in on them
	(setClosing). `size` is the target's diameter in pixels; the outer ring
	starts at OUTER_START times that.
]]
--[[
	Readability rules (user 2026-10-28: "centered, Bigger, Easier to read"):
	text the player must read is at least TextSizes.body; headings at least
	TextSizes.heading; nothing smaller than TextSizes.small. Testing readouts
	("[dev]" lines, raw progress numbers) are hidden unless ShowDevReadouts is
	switched on here.
]]
UIStyle.TextSizes = {
	big = 44, -- a verdict, the weight, the current letter
	heading = 26,
	body = 20,
	small = 16,
}
UIStyle.ShowDevReadouts = false

-- A label with a FIXED text size (wrapping), for text that must stay readable rather than shrink to fit.
function UIStyle.text(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number, colour: Color3?,
	font: Font?, align: Enum.TextXAlignment?): TextLabel
	local label = UIStyle.label(parent, name, position, size, colour, font, align)
	label.TextScaled = false
	label.TextSize = textSize
	label.TextWrapped = true
	return label
end

--[[
	Shrinks every panel of `gui` on short screens (user 2026-10-28: "UIs overlap
	... a BIG no", then "centered, Bigger"). Screens are designed for
	DESIGN_HEIGHT pixels of height; on a shorter screen each top-level piece
	gets a UIScale of (height / DESIGN_HEIGHT), never below MIN_SCALE.

	A UIScale shrinks a piece about its AnchorPoint, so a piece placed by its
	top-left corner would drift up and left when shrunk (it did: "they need to
	be centered"). So a top-level piece placed by its top-left corner (the
	default AnchorPoint) is first re-anchored at its own centre, without moving
	it: its Position moves by half its Size. A piece with any other AnchorPoint
	keeps it. Code that moves a top-level piece after building must give it its
	own AnchorPoint (and place it by that). Pieces added later get the same,
	and a resized window updates them all.
]]
local DESIGN_HEIGHT = 860
local MIN_SCALE = 0.6

--[[
	Where every lift minigame sits: the middle of the screen, nudged down a
	little so its top stays clear of the lift banner and status line at the
	top (LiftAttemptController). Each minigame is one group anchored at its
	centre and placed here.
]]
UIStyle.MinigameCentre = UDim2.new(0.5, 0, 0.5, 40)
local FIT_SCALE_NAME = "FitToScreen"

local function anchorAtCentre(piece: GuiObject)
	-- Only pieces placed by their top-left corner: any other anchor was chosen on purpose and is kept.
	local anchor = piece.AnchorPoint
	if anchor ~= Vector2.zero then
		return
	end
	local position, size = piece.Position, piece.Size
	local dx, dy = 0.5 - anchor.X, 0.5 - anchor.Y
	piece.Position = UDim2.new(position.X.Scale + size.X.Scale * dx, position.X.Offset + size.X.Offset * dx,
		position.Y.Scale + size.Y.Scale * dy, position.Y.Offset + size.Y.Offset * dy)
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
end
function UIStyle.screenScale(): number
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else DESIGN_HEIGHT
	return math.clamp(height / DESIGN_HEIGHT, MIN_SCALE, 1)
end

function UIStyle.fitToScreen(gui: ScreenGui)
	local function apply(child: Instance)
		if not child:IsA("GuiObject") then
			return
		end
		local scale = child:FindFirstChild(FIT_SCALE_NAME) :: UIScale?
		if scale == nil then
			anchorAtCentre(child)
			local made = Instance.new("UIScale")
			made.Name = FIT_SCALE_NAME
			made.Parent = child
			scale = made
		end
		(scale :: UIScale).Scale = UIStyle.screenScale()
	end
	local function applyAll()
		for _, child in ipairs(gui:GetChildren()) do
			apply(child)
		end
	end
	applyAll()
	-- Deferred: a piece is often parented before its Position and Size are set.
	gui.ChildAdded:Connect(function(child)
		task.defer(apply, child)
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyAll)
	end
end

local OUTER_START = 2.6
function UIStyle.ring(parent: Instance, name: string, position: UDim2, size: number, colour: Color3): Ring
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local disc = frame(holder, "Disc", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), colour)
	disc.BackgroundTransparency = 0.55
	round(disc)
	local discStroke = stroke(disc, C.white, 3, 0.15)
	local inner = frame(holder, "Inner", UDim2.fromScale(0.18, 0.18), UDim2.fromScale(0.64, 0.64), colour)
	inner.BackgroundTransparency = 1
	round(inner)
	local innerStroke = stroke(inner, colour, 3)
	-- The star: two thin diamonds crossed.
	for index, rotation in ipairs({ 0, 90 }) do
		local ray = frame(holder, "Star_" .. index, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.08, 0.34), C.white, rotation)
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		local taper = Instance.new("UIGradient")
		taper.Rotation = 90
		taper.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
		})
		taper.Parent = ray
	end
	local outer = frame(holder, "Outer", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(OUTER_START, OUTER_START), colour)
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.BackgroundTransparency = 1
	round(outer)
	local outerStroke = stroke(outer, colour, 4)

	local ring = {} :: Ring
	ring.holder = holder
	ring.setClosing = function(amount: number)
		local scale = OUTER_START + (1 - OUTER_START) * math.clamp(amount, 0, 1.2)
		outer.Size = UDim2.fromScale(scale, scale)
	end
	ring.setColour = function(newColour: Color3)
		disc.BackgroundColor3 = newColour
		inner.BackgroundColor3 = newColour
		innerStroke.Color = newColour
		outer.BackgroundColor3 = newColour
		outerStroke.Color = newColour
	end
	ring.flash = function()
		discStroke.Transparency = 0
		disc.BackgroundTransparency = 0.2
		task.delay(0.15, function()
			discStroke.Transparency = 0.15
			disc.BackgroundTransparency = 0.55
		end)
	end
	return ring
end

return UIStyle
