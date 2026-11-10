--!strict
--[[
	StateArenaShow
	Server / Meet

	The State meet's presentation (GAME_DESIGN §36.4, user 2026-11-08 after the meet videos; picks of 2026-11-10):

	THE CENTRE CUBE: its four big screens, hung over the floor and seen from every seat, follow the lifting. Up to
	four racks lift at once, so all four faces show the BIGGEST MOMENT (user's pick):
		1. a GYM RECORD ATTEMPT on the bar (the screen turns red);
		2. a record just broken: NEW GYM RECORD!, flashing gold, for a few seconds;
		3. another big moment just made (TAKES THE LEAD!, STILL IN THE MEET!...), for a few seconds;
		4. a lift's result (GOOD LIFT / NO LIFT), for a few seconds;
		5. otherwise the lifter up with the most hanging on their attempt (TO TAKE THE LEAD...);
	and among equals it swaps to the next every few seconds. With nobody up: STATE CHAMPIONSHIP.

	THE LIGHTS: for the whole meet the arena is dark, and a rack with a lifter on it is spotlit (user's pick). The
	server only marks it: the arena model's MeetLit attribute, and each rack lamp's Active attribute (tagged
	RackLightTag). Each player's StateArenaLights does the dimming, only while they are inside the arena.

	Display only: nothing here decides anything. LocalMeetService tells it what each rack's screen shows (show).
	PERFORMANCE: four SurfaceGuis redrawn only when what they show changes, one check every half second.
]]

local CollectionService = game:GetService("CollectionService")

local StyledScreen = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("StyledScreen"))

local StateArenaShow = {}

local S = StyledScreen.Colours
local HEADING = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local GREEN = Color3.fromRGB(96, 220, 120)
local GOLD = Color3.fromRGB(255, 196, 40)
local RED_DEEP = Color3.fromRGB(120, 12, 20)

-- The tag on each rack's lamp, and the attributes the clients read.
StateArenaShow.RackLightTag = "StateRackLight"
StateArenaShow.BowlLightTag = "StateBowlLight"
StateArenaShow.MeetLitAttribute = "MeetLit"
StateArenaShow.ActiveAttribute = "Active"

-- How long a moment stays the cube's first choice (seconds), and how often equals swap.
local NEW_RECORD_SECONDS = 9
local MOMENT_SECONDS = 6
local RESULT_SECONDS = 5
local SWAP_SECONDS = 6
-- (A broken record's screen flashes once a tick.)
local TICK_SECONDS = 0.5

-- What a rack's screen shows, as LocalMeetService hands it over.
export type RackView = {
	name: string,
	-- What the lifter is doing, one to three short lines (e.g. "SQUAT  ·  ATTEMPT 2", "205 KG  ·  GOOD LIFT").
	status: { string },
	mood: ("good" | "bad")?,
	recordAttempt: { title: string, detail: string }?,
	-- 1 (little) to 4 (everything) riding on the attempt, and what, in a few words.
	stakesLevel: number?,
	stakesLine: string?,
	-- A good lift's big moment ("NEW GYM RECORD!", "TAKES THE LEAD!"...), nil for none.
	moment: string?,
}

type Entry = {
	view: RackView,
	-- When the result, and when the moment, first showed (os.clock()).
	resultAt: number?,
	momentAt: number?,
	momentText: string?,
}

type Face = {
	back: Frame,
	tag: Frame,
	tagText: TextLabel,
	title: TextLabel,
	line: TextLabel,
	strip: Frame,
	stripText: TextLabel,
}

local entries: { [number]: Entry } = {}
local faces: { Face } = {}
local arenaModel: Model? = nil
local lastKey = ""
local featured: number? = nil
local featuredSince = 0
local flashOn = false
local started = false

local function frame(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3, rotation: number?): Frame
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

local function label(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3, font: Font,
	align: Enum.TextXAlignment?): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.TextColor3 = colour
	item.TextScaled = true
	item.FontFace = font
	item.TextXAlignment = align or Enum.TextXAlignment.Center
	item.Parent = parent
	return item
end

-- One screen in the game's screen style: a slanted tag, a big name, a line, and a strip. A cube face has the strip
-- along the bottom; a `wide` screen (the long signs on the side walls) has all of it in one row, the strip on the right.
local function buildFace(part: BasePart, face: Enum.NormalId, wide: boolean): Face
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Show"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	local back = frame(gui, "Back", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), S.navyDeep)
	back.ClipsDescendants = true
	for x = 0.05, 1, 0.05 do
		frame(back, "GridV", UDim2.fromScale(x, 0), UDim2.new(0, 2, 1, 0), S.grid).BackgroundTransparency = 0.85
	end
	local edge = frame(back, "Edge", UDim2.fromOffset(6, 6), UDim2.new(1, -12, 1, -12), S.navy)
	edge.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = S.white
	stroke.Thickness = 4
	stroke.Parent = edge
	local tag = if wide then frame(back, "Tag", UDim2.fromScale(0.015, 0.16), UDim2.fromScale(0.2, 0.68), S.ink, -3)
		else frame(back, "Tag", UDim2.fromScale(0.04, 0.07), UDim2.fromScale(0.52, 0.17), S.ink, -3)
	local tagStroke = Instance.new("UIStroke")
	tagStroke.Color = S.white
	tagStroke.Thickness = 3
	tagStroke.Parent = tag
	local tagText = label(tag, "Text", UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.9, 0.76), S.white, HEADING,
		Enum.TextXAlignment.Left)
	local title = if wide then label(back, "Title", UDim2.fromScale(0.235, 0.08), UDim2.fromScale(0.43, 0.56), S.white, HEADING)
		else label(back, "Title", UDim2.fromScale(0.05, 0.27), UDim2.fromScale(0.9, 0.36), S.white, HEADING)
	local line = if wide then label(back, "Line", UDim2.fromScale(0.235, 0.66), UDim2.fromScale(0.43, 0.26), S.white, BOLD)
		else label(back, "Line", UDim2.fromScale(0.08, 0.63), UDim2.fromScale(0.84, 0.13), S.white, BOLD)
	local strip = if wide then frame(back, "Strip", UDim2.fromScale(0.685, 0), UDim2.fromScale(0.315, 1), S.yellow)
		else frame(back, "Strip", UDim2.fromScale(0, 0.8), UDim2.fromScale(1, 0.2), S.yellow)
	local stripText = if wide then label(strip, "Text", UDim2.fromScale(0.06, 0.2), UDim2.fromScale(0.88, 0.6), S.ink, HEADING)
		else label(strip, "Text", UDim2.fromScale(0.05, 0.14), UDim2.fromScale(0.9, 0.72), S.ink, HEADING)
	return { back = back, tag = tag, tagText = tagText, title = title, line = line, strip = strip, stripText = stripText }
end

type Look = {
	background: Color3,
	tag: string,
	tagColour: Color3,
	title: string,
	line: string,
	strip: string,
	stripColour: Color3,
	stripInk: Color3,
}

local function draw(look: Look)
	for _, face in ipairs(faces) do
		face.back.BackgroundColor3 = look.background
		face.tag.BackgroundColor3 = look.tagColour
		face.tagText.Text = look.tag
		face.title.Text = look.title
		face.line.Text = look.line
		face.strip.BackgroundColor3 = look.stripColour
		face.stripText.Text = look.strip
		face.stripText.TextColor3 = look.stripInk
	end
end

-- How much the cube wants to show this rack now (higher first), and why.
local function priority(entry: Entry, now: number): (number, string)
	local view = entry.view
	if view.recordAttempt and view.mood == nil then
		return 100, "record"
	end
	if entry.momentText and entry.momentAt then
		local age = now - entry.momentAt
		if entry.momentText:find("RECORD") and age < NEW_RECORD_SECONDS then
			return 90, "newRecord"
		end
		if age < MOMENT_SECONDS then
			return 70, "moment"
		end
	end
	if entry.resultAt and now - entry.resultAt < RESULT_SECONDS then
		return 50, "result"
	end
	if view.mood == nil then
		return 10 * (view.stakesLevel or 1), "up"
	end
	return 1, "after"
end

local function lookFor(rack: number, entry: Entry, kind: string): Look
	local view = entry.view
	local status = table.concat(view.status, "   ·   ")
	if kind == "record" then
		local attempt = view.recordAttempt :: { title: string, detail: string }
		return { background = RED_DEEP, tag = attempt.title, tagColour = S.red, title = view.name, line = status,
			strip = attempt.detail, stripColour = S.red, stripInk = S.white }
	elseif kind == "newRecord" then
		local bright = flashOn
		return { background = if bright then Color3.fromRGB(70, 50, 0) else S.navyDeep, tag = "NEW GYM RECORD!",
			tagColour = GOLD, title = view.name, line = status, strip = "NEW GYM RECORD!",
			stripColour = if bright then GOLD else S.white, stripInk = S.ink }
	elseif kind == "moment" then
		return { background = S.navyDeep, tag = string.format("PLATFORM %d", rack), tagColour = S.ink, title = view.name,
			line = status, strip = entry.momentText or "", stripColour = GREEN, stripInk = S.ink }
	elseif kind == "result" or kind == "after" then
		local good = view.mood == "good"
		return { background = S.navyDeep, tag = string.format("PLATFORM %d", rack), tagColour = S.ink, title = view.name,
			line = status, strip = if good then "GOOD LIFT" else "NO LIFT", stripColour = if good then GREEN else S.red,
			stripInk = if good then S.ink else S.white }
	end
	return { background = S.navyDeep, tag = string.format("PLATFORM %d", rack), tagColour = S.ink, title = view.name,
		line = status, strip = view.stakesLine or "STATE CHAMPIONSHIP", stripColour = S.yellow, stripInk = S.ink }
end

local IDLE: Look = { background = S.navyDeep, tag = "CENTRAL", tagColour = S.ink, title = "STATE", line = "",
	strip = "CHAMPIONSHIP", stripColour = S.yellow, stripInk = S.ink }

local function tick()
	if #faces == 0 then
		return
	end
	local now = os.clock()
	flashOn = not flashOn
	-- The best racks now.
	local best, bestKinds = -1, {} :: { [number]: string }
	local candidates: { number } = {}
	for rack, entry in pairs(entries) do
		local score, kind = priority(entry, now)
		if score > best then
			best = score
			table.clear(candidates)
			table.clear(bestKinds)
		end
		if score == best then
			table.insert(candidates, rack)
			bestKinds[rack] = kind
		end
	end
	table.sort(candidates)
	local chosen: number? = nil
	if #candidates > 0 then
		-- Stay on the one shown while it is still among the best, until it is time to swap.
		local keep = featured and table.find(candidates, featured)
		if keep and (now - featuredSince < SWAP_SECONDS or #candidates == 1) then
			chosen = featured
		else
			local nextIndex = if keep then keep % #candidates + 1 else 1
			chosen = candidates[nextIndex]
			featured, featuredSince = chosen, now
		end
	else
		featured = nil
	end
	local look = if chosen then lookFor(chosen, entries[chosen], bestKinds[chosen]) else IDLE
	local key = table.concat({ look.tag, look.title, look.line, look.strip, tostring(look.background), tostring(look.stripColour) }, "|")
	if key ~= lastKey then
		lastKey = key
		draw(look)
	end
end

--[[
	The arena is built: the cube's screen part (one piece holding its four screens, `outward` gives each face's
	direction) and the arena model, which carries the lights' marks.
]]
function StateArenaShow.attach(cubeScreens: BasePart?, outward: { Vector3 }, model: Model)
	arenaModel = model
	if cubeScreens then
		table.clear(faces)
		for _, direction in ipairs(outward) do
			table.insert(faces, buildFace(cubeScreens, StyledScreen.faceToward(cubeScreens, direction), false))
		end
		draw(IDLE)
		lastKey = ""
	end
	if not started then
		started = true
		task.spawn(function()
			while true do
				task.wait(TICK_SECONDS)
				local ok, problem = pcall(tick)
				if not ok then
					warn("[StateArenaShow] " .. tostring(problem))
				end
			end
		end)
	end
end

-- Another screen that shows the same as the cube: the long signs on the side walls (user 2026-11-10: the cube alone is hard to
-- see from the floor), facing `outward`. After attach.
function StateArenaShow.addWideScreen(part: BasePart, outward: Vector3)
	table.insert(faces, buildFace(part, StyledScreen.faceToward(part, outward), true))
	lastKey = ""
	draw(IDLE)
end

-- The State meet started (true) or ended (false): the arena goes dark with its racks spotlit, or back to normal.
function StateArenaShow.meetOn(on: boolean)
	if arenaModel then
		arenaModel:SetAttribute(StateArenaShow.MeetLitAttribute, on)
	end
	if not on then
		table.clear(entries)
		for _, lamp in ipairs(CollectionService:GetTagged(StateArenaShow.RackLightTag)) do
			lamp:SetAttribute(StateArenaShow.ActiveAttribute, false)
		end
	end
end

-- Whether a lifter is on rack `rack` (their turn, from being called up to sitting back down): its lamp is spotlit.
function StateArenaShow.rackActive(rack: number, active: boolean)
	for _, lamp in ipairs(CollectionService:GetTagged(StateArenaShow.RackLightTag)) do
		if lamp:GetAttribute("Rack") == rack then
			lamp:SetAttribute(StateArenaShow.ActiveAttribute, active)
		end
	end
	if not active then
		-- Their result stays on the cube a little while (priority ages it out), then the rack drops off it.
		local entry = entries[rack]
		if entry then
			task.delay(RESULT_SECONDS, function()
				if entries[rack] == entry then
					entries[rack] = nil
				end
			end)
		end
	end
end

-- What rack `rack`'s screen shows now (LocalMeetService's boardFor for the lifter on it).
function StateArenaShow.show(rack: number, view: RackView)
	local now = os.clock()
	local old = entries[rack]
	local entry: Entry = { view = view, resultAt = nil, momentAt = nil, momentText = nil }
	-- The same lifter's attempt still: keep when its result and moment first showed.
	if old and old.view.name == view.name and old.view.status[1] == view.status[1] then
		entry.resultAt, entry.momentAt, entry.momentText = old.resultAt, old.momentAt, old.momentText
	end
	if view.mood and entry.resultAt == nil then
		entry.resultAt = now
	end
	if view.moment and entry.momentText ~= view.moment then
		entry.momentAt, entry.momentText = now, view.moment
	end
	entries[rack] = entry
end

return StateArenaShow
