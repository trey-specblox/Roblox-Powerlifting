--!strict
--[[
	StyledScreen
	Server / World

	In-world screens and signs (SurfaceGuis on parts) in the game's one UI
	style (GAME_DESIGN "One UI style for the whole game"): navy fading darker,
	a faint grid, a white frame, a slanted black tag with a white edge and a
	small mark after it, white lines with yellow markers, and a small CENTRAL
	mark. Used by RoomProps (the Cardio TV, the Mock Meet Room board) and
	MockMeetArena (the attempt board, the banners).

	The server cannot require the client's UIStyle, so the colours below
	MIRROR UIStyle.Colours and the marks mirror UIStyle's cues: change them
	together. Marks (user 2026-10-28: "Not every title needs a double line"):
	"slashes", "star", "chevron", "bar", "corner", "dots", "none".
]]

local StyledScreen = {}

StyledScreen.Colours = {
	navy = Color3.fromRGB(14, 22, 54),
	navyDeep = Color3.fromRGB(7, 11, 30),
	grid = Color3.fromRGB(70, 96, 170),
	yellow = Color3.fromRGB(250, 206, 36),
	white = Color3.fromRGB(248, 248, 244),
	ink = Color3.fromRGB(10, 10, 12),
	muted = Color3.fromRGB(150, 160, 192),
	red = Color3.fromRGB(226, 46, 56),
}
local S = StyledScreen.Colours
local FAMILY = "rbxasset://fonts/families/Montserrat.json"

export type Handle = {
	gui: SurfaceGui,
	setTag: (text: string) -> (),
	setLines: (lines: { string }) -> (),
}

-- The face of `part` that looks along `direction`, also when the part is turned (a Blender model's piece).
function StyledScreen.faceToward(part: BasePart, direction: Vector3): Enum.NormalId
	local best, bestDot = Enum.NormalId.Front, -math.huge
	for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
		local dot = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)):Dot(direction)
		if dot > bestDot then
			best, bestDot = face, dot
		end
	end
	return best
end

local function box(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3, rotation: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Position = position
	f.Size = size
	f.Rotation = rotation or 0
	f.Parent = parent
	return f
end

local function text(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3, heavy: boolean,
	align: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.TextColor3 = colour
	label.TextScaled = true
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.FontFace = if heavy
		then Font.new(FAMILY, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
		else Font.new(FAMILY, Enum.FontWeight.Bold)
	label.Parent = parent
	return label
end

-- The mark after a heading, inside `parent` (sizes as a share of `parent`), in `colour`.
function StyledScreen.mark(parent: GuiObject, kind: string?, colour: Color3?)
	local tint = colour or S.yellow
	local k = kind or "slashes"
	if k == "slashes" then
		for index = 0, 1 do
			box(parent, "Mark_Slash_" .. index, UDim2.fromScale(0.2 + index * 0.4, 0), UDim2.fromScale(0.18, 1), tint, 25)
		end
	elseif k == "star" then
		for index, rotation in ipairs({ 0, 90 }) do
			local ray = box(parent, "Mark_Star_" .. index, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.22, 1), tint, rotation)
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.SizeConstraint = Enum.SizeConstraint.RelativeYY
			local taper = Instance.new("UIGradient")
			taper.Rotation = 90
			taper.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
			})
			taper.Parent = ray
		end
	elseif k == "chevron" then
		for index = 0, 1 do
			for half, rotation in ipairs({ 45, -45 }) do
				local tip = box(parent, string.format("Mark_Chevron_%d_%d", index, half),
					UDim2.fromScale(0.25 + index * 0.45, if half == 1 then 0.32 else 0.68), UDim2.fromScale(0.42, 0.16), tint, rotation)
				tip.AnchorPoint = Vector2.new(0.5, 0.5)
			end
		end
	elseif k == "bar" then
		box(parent, "Mark_Bar", UDim2.fromScale(0, 0.38), UDim2.fromScale(0.7, 0.24), tint)
		box(parent, "Mark_BarDot", UDim2.fromScale(0.8, 0.38), UDim2.fromScale(0.2, 0.24), tint)
	elseif k == "corner" then
		box(parent, "Mark_CornerTop", UDim2.fromScale(0.1, 0), UDim2.fromScale(0.85, 0.16), tint)
		box(parent, "Mark_CornerSide", UDim2.fromScale(0.8, 0), UDim2.fromScale(0.15, 0.9), tint)
	elseif k == "dots" then
		for index, scale in ipairs({ 0.36, 0.26, 0.18 }) do
			local dot = box(parent, "Mark_Dot_" .. index, UDim2.fromScale((index - 1) * 0.36, 0.5 - scale / 2),
				UDim2.fromScale(scale, scale), tint)
			dot.SizeConstraint = Enum.SizeConstraint.RelativeYY
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = dot
		end
	end
end

--[[
	Builds the screen on `face` of `part` and returns a handle to change its tag
	and lines later (the Mock Meet's attempt board). `mark` picks the heading's
	mark. `pixelsPerStud` sets how sharp it is (40 by default).
]]
function StyledScreen.build(part: BasePart, face: Enum.NormalId, tag: string, lines: { string }, mark: string?,
	pixelsPerStud: number?): Handle
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part

	local back = box(gui, "Back", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), S.navy)
	back.ClipsDescendants = true
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(S.navy, S.navyDeep)
	shade.Parent = back
	for x = 0.05, 1, 0.05 do
		box(back, "GridV", UDim2.fromScale(x, 0), UDim2.new(0, 2, 1, 0), S.grid).BackgroundTransparency = 0.82
	end
	for y = 0.1, 1, 0.1 do
		box(back, "GridH", UDim2.fromScale(0, y), UDim2.new(1, 0, 0, 2), S.grid).BackgroundTransparency = 0.82
	end
	local frame = box(back, "Frame", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -16), S.navy)
	frame.BackgroundTransparency = 1
	local edge = Instance.new("UIStroke")
	edge.Color = S.white
	edge.Thickness = 4
	edge.Parent = frame

	local tagSlab = box(back, "Tag", UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.5, 0.2), S.ink, -4)
	local tagEdge = Instance.new("UIStroke")
	tagEdge.Color = S.white
	tagEdge.Thickness = 4
	tagEdge.Parent = tagSlab
	local tagText = text(tagSlab, "Text", UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.72, 0.76), S.white, true)
	tagText.Text = tag
	local markHolder = Instance.new("Frame")
	markHolder.Name = "Mark"
	markHolder.BackgroundTransparency = 1
	markHolder.Position = UDim2.fromScale(0.8, 0.14)
	markHolder.Size = UDim2.fromScale(0.15, 0.72)
	markHolder.Parent = tagSlab
	StyledScreen.mark(markHolder, mark)

	local linesHolder = Instance.new("Frame")
	linesHolder.Name = "Lines"
	linesHolder.BackgroundTransparency = 1
	linesHolder.Position = UDim2.fromScale(0, 0.3)
	linesHolder.Size = UDim2.fromScale(1, 0.62)
	linesHolder.Parent = back

	local centralMark = text(back, "Central", UDim2.fromScale(0.95, 0.94), UDim2.fromScale(0.22, 0.08), S.muted, true,
		Enum.TextXAlignment.Right)
	centralMark.AnchorPoint = Vector2.new(1, 1)
	centralMark.Text = "CENTRAL"

	local handle = {} :: Handle
	handle.gui = gui
	handle.setTag = function(newTag: string)
		tagText.Text = newTag
	end
	handle.setLines = function(newLines: { string })
		linesHolder:ClearAllChildren()
		local share = 1 / math.max(1, #newLines)
		for index, line in ipairs(newLines) do
			local y = (index - 1) * share
			box(linesHolder, "Marker_" .. index, UDim2.fromScale(0.07, y + share * 0.3), UDim2.fromScale(0.012, share * 0.4),
				S.yellow)
			local label = text(linesHolder, "Line_" .. index, UDim2.fromScale(0.1, y + share * 0.12),
				UDim2.fromScale(0.82, share * 0.76), S.white, false)
			label.Text = line
		end
	end
	handle.setLines(lines)
	return handle
end

return StyledScreen
