--!strict
--[[
	LifterDisplay
	Server / Meet

	The big screen over each Local meet platform (user 2026-10-29: "turn that
	into a display ... it'll show whoever player is on the platform, their
	username, weight class, weight, forecasted total, and any fun facts like
	records, or titles, or if they're breaking anything"). A SurfaceGui on the
	platform board's screen, in the game's style (StyledScreen's colours and
	heavy italic Montserrat):

		PLATFORM 3 (tag)
		USERNAME                                  | SQUAT · ATTEMPT 2 |
		93 KG CLASS  ·  BODYWEIGHT 91.4 KG        | 205 KG            |
		FORECAST TOTAL 650 KG                     | GOOD LIFT         |
		BEST  S 200  ·  B —  ·  D —
		[ yellow strip: fun facts, two at a time in turn, e.g. NEW BEST TOTAL! // 2x LOCAL CHAMPION ]

	A GYM RECORD ATTEMPT (user 2026-10-30: "it needs to be more visible when
	someone is going for a gym record ... maby with a bigger sign at the top
	saying GYM RECORD ATTEMPT"): a big red sign floats above the board,
	readable from anywhere in the venue (a BillboardGui, so it always faces
	the viewer), with what is being tried under it; its edge flashes. The
	facts strip turns red too.

	With nobody on the platform it says the platform is open. It only draws
	what LocalMeetService tells it (show).
]]

local Workspace = game:GetService("Workspace")

local StyledScreen = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("StyledScreen"))

local LifterDisplay = {}

local S = StyledScreen.Colours
local HEADING = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local GREEN = Color3.fromRGB(96, 220, 120)
-- The fun-facts strip: this many facts at a time, the next ones after this many seconds.
local FACTS_AT_ONCE = 2
local FACT_SECONDS = 4
-- The record attempt sign: its size and its gap above the board's top (studs), and how fast its edge flashes.
local SIGN_WIDTH, SIGN_HEIGHT = 23, 6
local SIGN_GAP = 2
local SIGN_FLASH_SECONDS = 0.5

-- What the screen shows for a lifter on the platform.
export type Card = {
	name: string,
	classLabel: string,
	bodyweightKg: number,
	forecastTotalKg: number,
	-- The best good lift so far per lift (absent = none yet).
	best: { [string]: number },
	-- What the lifter is doing now, one to three short lines (e.g. "SQUAT · ATTEMPT 2", "205 KG · GOOD LIFT").
	status: { string },
	-- "good" colours the status green, "bad" red; nil leaves it white.
	mood: ("good" | "bad")?,
	-- Titles, best marks and anything the lifter is breaking right now (shown first-come, a few at a time).
	facts: { string },
	-- Set while the lifter's declared weight would beat a record: the sign's title and the line under it
	-- (e.g. "GYM RECORD ATTEMPT", "30 KG SQUAT  ·  RECORD 25 KG").
	recordAttempt: { title: string, detail: string }?,
}

export type Handle = {
	show: (card: Card?) -> (),
}

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

local function label(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3, font: Font,
	align: Enum.TextXAlignment?): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = ""
	item.TextColor3 = colour
	item.TextScaled = true
	item.FontFace = font
	item.TextXAlignment = align or Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

local function box(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3, rotation: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = colour
	frame.Position = position
	frame.Size = size
	frame.Rotation = rotation or 0
	frame.Parent = parent
	return frame
end

local function edge(parent: Instance, colour: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

-- Builds the display on `part`'s face looking along `out`, for platform `index`.
function LifterDisplay.build(part: BasePart, out: Vector3, index: number, lifts: { string }): Handle
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LifterDisplay"
	gui.Face = StyledScreen.faceToward(part, out)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = part

	local back = box(gui, "Back", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), S.navy)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(S.navy, S.navyDeep)
	shade.Parent = back
	local inner = box(back, "Inner", UDim2.fromScale(0.012, 0.025), UDim2.fromScale(0.976, 0.95), S.white)
	inner.BackgroundTransparency = 1
	edge(inner, S.white, 3)

	-- The platform tag (slanted black with a white edge). The board's frame carries CENTRAL above it.
	local tag = box(back, "Tag", UDim2.fromScale(0.035, 0.06), UDim2.fromScale(0.27, 0.13), S.ink, -3)
	edge(tag, S.white, 3)
	label(tag, "Text", UDim2.fromScale(0.08, 0.12), UDim2.fromScale(0.84, 0.76), S.white, HEADING).Text = "PLATFORM " .. index

	local name = label(back, "LifterName", UDim2.fromScale(0.04, 0.22), UDim2.fromScale(0.56, 0.22), S.white, HEADING)
	local classLine = label(back, "Class", UDim2.fromScale(0.04, 0.46), UDim2.fromScale(0.56, 0.09), S.yellow, HEADING)
	local forecast = label(back, "Forecast", UDim2.fromScale(0.04, 0.57), UDim2.fromScale(0.56, 0.09), S.white, BOLD)
	local bests = label(back, "Best", UDim2.fromScale(0.04, 0.68), UDim2.fromScale(0.56, 0.08), S.muted, BOLD)

	-- What the lifter is doing now, in a box on the right.
	local statusBox = box(back, "Status", UDim2.fromScale(0.62, 0.08), UDim2.fromScale(0.35, 0.68), S.navyDeep)
	edge(statusBox, S.white, 2)
	local statusLines: { TextLabel } = {}
	for line = 1, 3 do
		statusLines[line] = label(statusBox, "Line" .. line, UDim2.fromScale(0.07, 0.08 + (line - 1) * 0.3),
			UDim2.fromScale(0.86, if line == 2 then 0.26 else 0.22), S.white, if line == 2 then HEADING else BOLD)
	end

	-- The fun-facts strip along the bottom.
	local strip = box(back, "Facts", UDim2.fromScale(0, 0.81), UDim2.fromScale(1, 0.19), S.yellow)
	local facts = label(strip, "Text", UDim2.fromScale(0.03, 0.14), UDim2.fromScale(0.94, 0.72), S.ink, HEADING)

	-- The record attempt sign above the board (hidden until a record attempt). Placed from the board's
	-- world-space top, a little out in front of it.
	local cf = part.CFrame
	local halfHeight = 0.5 * (math.abs(cf.XVector.Y) * part.Size.X + math.abs(cf.YVector.Y) * part.Size.Y
		+ math.abs(cf.ZVector.Y) * part.Size.Z)
	local sign = Instance.new("BillboardGui")
	sign.Name = "RecordAttemptSign"
	sign.Size = UDim2.fromScale(SIGN_WIDTH, SIGN_HEIGHT)
	sign.StudsOffsetWorldSpace = Vector3.new(0, halfHeight + SIGN_GAP + SIGN_HEIGHT / 2, 0) + out.Unit * 0.5
	sign.LightInfluence = 0
	sign.Brightness = 1.4
	sign.MaxDistance = 400
	sign.Enabled = false
	sign.Parent = part
	local slab = box(sign, "Slab", UDim2.fromScale(0.02, 0.04), UDim2.fromScale(0.96, 0.9), S.red, -2)
	local signEdge = Instance.new("UIStroke")
	signEdge.Color = S.white
	signEdge.Thickness = 4
	signEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	signEdge.Parent = slab
	local signTitle = label(slab, "Title", UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.92, 0.55), S.white, HEADING,
		Enum.TextXAlignment.Center)
	local signDetail = label(slab, "Detail", UDim2.fromScale(0.06, 0.6), UDim2.fromScale(0.88, 0.33), S.yellow, HEADING,
		Enum.TextXAlignment.Center)
	-- The edge flashes white / yellow while the sign is up (one small change every SIGN_FLASH_SECONDS).
	task.spawn(function()
		local bright = false
		while gui.Parent and part:IsDescendantOf(Workspace) do
			task.wait(SIGN_FLASH_SECONDS)
			if sign.Enabled then
				bright = not bright
				signEdge.Color = if bright then S.yellow else S.white
			end
		end
	end)

	-- The facts take turns on the strip, FACTS_AT_ONCE at a time, so each stays on one readable line.
	local factList: { string } = {}
	local factStart = 1
	local function drawFacts()
		if #factList == 0 then
			facts.Text = "LOCAL MEET  //  GOOD LUCK"
			return
		end
		local shown: { string } = {}
		for k = 0, math.min(FACTS_AT_ONCE, #factList) - 1 do
			table.insert(shown, factList[(factStart - 1 + k) % #factList + 1])
		end
		facts.Text = table.concat(shown, "  //  ")
	end
	task.spawn(function()
		while gui.Parent do
			task.wait(FACT_SECONDS)
			if #factList > FACTS_AT_ONCE then
				factStart = (factStart - 1 + FACTS_AT_ONCE) % #factList + 1
				drawFacts()
			end
		end
	end)

	local handle = {} :: Handle
	function handle.show(card: Card?)
		if card == nil then
			name.Text = "OPEN"
			classLine.Text = "SIGN UP AT THE DESK TO LIFT HERE"
			forecast.Text = ""
			bests.Text = ""
			statusBox.Visible = false
			sign.Enabled = false
			strip.BackgroundColor3, facts.TextColor3 = S.yellow, S.ink
			factList = { "LOCAL MEET", "EVERYONE LIFTS TOGETHER", "BEST SCORE WINS" }
			factStart = 1
			drawFacts()
			return
		end
		name.Text = string.upper(card.name)
		classLine.Text = string.format("%s CLASS  ·  BODYWEIGHT %s KG", card.classLabel, kgText(card.bodyweightKg))
		forecast.Text = string.format("FORECAST TOTAL  %s KG", kgText(card.forecastTotalKg))
		local parts = {}
		for _, lift in ipairs(lifts) do
			local kg = card.best[lift]
			table.insert(parts, string.format("%s %s", string.sub(lift, 1, 1), if kg then kgText(kg) else "—"))
		end
		bests.Text = "BEST  " .. table.concat(parts, "  ·  ")
		statusBox.Visible = #card.status > 0
		for line, item in ipairs(statusLines) do
			item.Text = card.status[line] or ""
			item.TextColor3 = if line == 2 and card.mood == "good" then GREEN
				elseif line == 2 and card.mood == "bad" then S.red
				else S.white
		end
		-- A record attempt: the sign above, and the strip turns red with the attempt first.
		local attempt = card.recordAttempt
		sign.Enabled = attempt ~= nil
		local list = table.clone(card.facts)
		if attempt then
			signTitle.Text = attempt.title
			signDetail.Text = attempt.detail
			strip.BackgroundColor3, facts.TextColor3 = S.red, S.white
			table.insert(list, 1, attempt.title .. "!")
		else
			strip.BackgroundColor3, facts.TextColor3 = S.yellow, S.ink
		end
		-- New facts start from the first (the newest "breaking" ones come first).
		local changed = table.concat(list, "|") ~= table.concat(factList, "|")
		factList = list
		if changed then
			factStart = 1
		end
		drawFacts()
	end
	handle.show(nil)
	return handle
end

return LifterDisplay
