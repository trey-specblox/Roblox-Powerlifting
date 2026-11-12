--!strict
--[[
	CelebrationViewer
	Client / UI

	The celebrations, to click through and quick-watch (user 2026-11-11: "make sure i can click through them to inspect,
	Give me the ability to quick watch them"). Opened from the admin panel (with the admin buttons), and by every player
	from the spin screen's SEE ALL (CelebrationSpinner), to see what a spin could land on.

		on the left   a copy of your own avatar on a small lit stage, playing the chosen celebration over and over
		              (a "Walk" one over a walk, as in a meet), with its sounds; 3/4, FRONT or SIDE view; SLOW-MO
		on the right  every celebration by rarity (CelebrationConfig.List): its name, rarity, length, the real meet it
		              came from and what happens in it
		buttons       < PREV, REPLAY, NEXT >, PLAY ON ME (admin: plays it on your real character for everyone, with its
		              cinematic if it has one; AdminService "PlayCelebration" checks the account), MAKE IT MINE (admin:
		              makes it your celebration at meets, "SetCelebration"), CLOSE

	It also lists the walk-outs (EntranceConfig; user 2026-11-11: "SEE ALL for walk-outs"), opened from the spin screen's
	WALK-OUTS tab: each one walks up to the camera in its style, then does its hype move with its sound, over and over
	(no SLOW-MO and no admin buttons there).

	Display only: the copy lives on this screen's stage (CelebrationStage); nothing is saved or given here.
	PERFORMANCE: one avatar copy and two animation tracks while open; nothing when closed. (Chalk particles don't show in
	a ViewportFrame: PLAY ON ME shows them.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CelebrationConfig = require(Shared:WaitForChild("Config"):WaitForChild("CelebrationConfig"))
local EntranceConfig = require(Shared:WaitForChild("Config"):WaitForChild("EntranceConfig"))
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local StationAnimationConfig = require(Shared:WaitForChild("Config"):WaitForChild("StationAnimationConfig"))
local EmoteConfig = require(Shared:WaitForChild("Config"):WaitForChild("EmoteConfig"))
local GearStatsConfig = require(Shared:WaitForChild("Config"):WaitForChild("GearStatsConfig"))
local AdminRemotes = require(Shared:WaitForChild("Admin"):WaitForChild("AdminRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local CelebrationStage = require(script.Parent:WaitForChild("CelebrationStage"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local CelebrationViewer = {}

local PANEL_WIDTH, PANEL_HEIGHT = 1040, 660
local MARGIN = 24
local VIEW_SIZE = Vector2.new(560, 470)
local RIGHT_X = MARGIN + VIEW_SIZE.X + 22
local RIGHT_WIDTH = PANEL_WIDTH - RIGHT_X - MARGIN
-- Where the camera looks from, around the figure (it faces -Z, its right is +X), and at.
local VIEWS = {
	ThreeQuarter = Vector3.new(7.5, 4.6, -10.5),
	Front = Vector3.new(0, 3.8, -13),
	Side = Vector3.new(13, 3.6, 0),
}

type Screen = {
	gui: ScreenGui,
	title: TextLabel,
	stage: CelebrationStage.Stage,
	list: ScrollingFrame,
	rows: { [string]: TextButton },
	name: TextLabel,
	rarity: TextLabel,
	facts: TextLabel,
	about: TextLabel,
	counter: TextLabel,
	status: TextLabel,
	slow: TextButton,
	viewButtons: { [string]: TextButton },
	adminButtons: { TextButton },
}
local screen: Screen? = nil
local index = 1
-- What the list shows: "Celebration" or "Entrance" (walk-outs); where each was left.
local kind = "Celebration"
local lastIndex: { [string]: number } = { Celebration = 1, Entrance = 1, Fail = 1, Emote = 1 }
local TITLES = { Celebration = "CELEBRATIONS", Entrance = "WALK-OUTS", Fail = "FAIL STYLES", Emote = "EMOTES" }
local slowMotion = false
local view = "ThreeQuarter"
local actionRemote: RemoteFunction? = nil
-- Opened by the admin panel (with the admin buttons) or from the spin screen (without; back to it on CLOSE).
local asAdmin = false
local onClosed: (() -> ())? = nil

local function rarityColour(rarity: string): Color3
	for _, entry in ipairs(GearStatsConfig.Rarities) do
		if entry.id == rarity then
			return entry.colour
		end
	end
	return C.white
end

-- One row of the list, whichever kind: what the right side shows, and the thing itself to play.
type Item = {
	id: string,
	name: string,
	rarity: string,
	description: string,
	facts: string,
	celebration: CelebrationConfig.Celebration?,
	entrance: EntranceConfig.Entrance?,
	failStyle: string?,
	emote: EmoteConfig.Emote?,
}

-- Each list in rarity order (the config's own order within each).
local function ordered(): { [string]: { Item } }
	local lists: { [string]: { Item } } = { Celebration = {}, Entrance = {}, Fail = {}, Emote = {} }
	for _, rarity in ipairs(CelebrationConfig.RarityOrder) do
		for _, celebration in ipairs(CelebrationConfig.List) do
			if celebration.rarity == rarity then
				local kindText = if celebration.kind == "WalkLoop" then "all the way back to your spot"
					elseif celebration.kind == "Walk" then "played over the walk back" else "on the platform"
				local cinematic = if celebration.cinematic then "  ·  HAS A CINEMATIC (PLAY ON ME)" else ""
				table.insert(lists.Celebration, {
					id = celebration.id, name = celebration.name, rarity = celebration.rarity,
					description = celebration.description, celebration = celebration,
					facts = string.format("%.1f s  ·  %s  ·  from a real meet (%s)%s", celebration.seconds, kindText,
						celebration.source, cinematic),
				})
			end
		end
		for _, id in ipairs(EntranceConfig.Order) do
			local entrance = EntranceConfig.Entrances[id]
			if entrance.rarity == rarity then
				table.insert(lists.Entrance, {
					id = id, name = entrance.name, rarity = entrance.rarity, description = entrance.description,
					entrance = entrance,
					facts = string.format("The walk style at every meet  ·  then the %.1f s hype move at the bar", entrance.hypeSeconds),
				})
			end
		end
		for _, id in ipairs(StationAnimationConfig.FailStyleOrder) do
			local style = if id == "Default" then StationAnimationConfig.DefaultFailStyle else StationAnimationConfig.FailStyles[id]
			if style and style.rarity == rarity then
				table.insert(lists.Fail, {
					id = id, name = style.name, rarity = style.rarity, description = style.description, failStyle = id,
					facts = "Every missed lift at every meet  ·  shown here: the squat and the deadlift",
				})
			end
		end
		for _, emote in ipairs(EmoteConfig.List) do
			local shown = if emote.rarity == "Free" then "Default" else emote.rarity
			if shown == rarity then
				table.insert(lists.Emote, {
					id = emote.id, name = emote.name, rarity = shown, description = emote.description, emote = emote,
					facts = string.format("%.1f s  ·  on the emote wheel (B)%s", emote.seconds,
						if emote.rarity == "Free" then "  ·  everyone has it" else ""),
				})
			end
		end
	end
	return lists
end
local LISTS = ordered()
local ORDER = LISTS.Celebration

-- Plays the chosen one on the copy, again and again until another is chosen or the viewer closes.
local function playChosen()
	local current = screen
	local item = ORDER[index]
	if current == nil or item == nil then
		return
	end
	if item.failStyle then
		local fails = {}
		for _, pick in ipairs({ { "Squat", 2 }, { "Deadlift", 2 }, { "Squat", 1 }, { "Deadlift", 1 } }) do
			local fail = StationAnimationConfig.failFor(pick[1], pick[2], if item.failStyle == "Default" then nil else item.failStyle)
			if fail and fail.id ~= "" then
				table.insert(fails, { pick[1], fail })
			end
		end
		CelebrationStage.playFail(current.stage, fails)
	elseif item.emote then
		CelebrationStage.play(current.stage, item.emote :: any, if slowMotion then 0.5 else 1)
	elseif item.entrance then
		CelebrationStage.playEntrance(current.stage, item.entrance, LocalMeetConfig.ComputerLifters.WalkSpeed)
	elseif item.celebration then
		CelebrationStage.play(current.stage, item.celebration, if slowMotion then 0.5 else 1)
	end
end

local function placeCamera()
	local current = screen
	if current then
		CelebrationStage.look(current.stage, VIEWS[view])
		for name, button in pairs(current.viewButtons) do
			local chosen = name == view
			button.BackgroundColor3 = if chosen then C.yellow else C.navyDeep
			button.TextColor3 = if chosen then C.ink else C.white
		end
	end
end

local function show()
	local current = screen
	local celebration = ORDER[index]
	if current == nil or celebration == nil then
		return
	end
	local colour = rarityColour(celebration.rarity)
	current.name.Text = string.upper(celebration.name)
	current.rarity.Text = if celebration.rarity == "Default" then "DEFAULT  ·  EVERYONE'S" else string.upper(celebration.rarity)
	current.rarity.TextColor3 = colour
	current.facts.Text = celebration.facts
	current.about.Text = celebration.description
	current.counter.Text = string.format("%d / %d", index, #ORDER)
	-- Keep the chosen row in view.
	local rowTop = (index - 1) * 38
	local shown = current.list.AbsoluteWindowSize.Y
	local scroll = current.list.CanvasPosition.Y
	if rowTop < scroll or rowTop + 32 > scroll + shown then
		current.list.CanvasPosition = Vector2.new(0, math.max(0, rowTop - shown / 2 + 16))
	end
	for id, row in pairs(current.rows) do
		local chosen = id == celebration.id
		row.BackgroundColor3 = if chosen then C.navy else C.navyDeep
		local stroke = row:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if chosen then C.yellow else C.white
			stroke.Transparency = if chosen then 0 else 0.7
		end
	end
	current.status.Text = ""
	playChosen()
end

local function choose(newIndex: number)
	index = ((newIndex - 1) % #ORDER) + 1
	lastIndex[kind] = index
	show()
end

-- (Re)makes the list's rows for the current kind.
local function fillList(list: ScrollingFrame, rows: { [string]: TextButton })
	for _, row in pairs(rows) do
		row:Destroy()
	end
	table.clear(rows)
	list.CanvasSize = UDim2.fromOffset(0, #ORDER * 38)
	list.CanvasPosition = Vector2.zero
	for i, celebration in ipairs(ORDER) do
		local row = Instance.new("TextButton")
		row.Name = celebration.id
		row.Position = UDim2.fromOffset(0, (i - 1) * 38)
		row.Size = UDim2.new(1, -12, 0, 32)
		row.BackgroundColor3 = C.navyDeep
		row.BorderSizePixel = 0
		row.AutoButtonColor = true
		row.Text = ""
		row.Parent = list
		UIStyle.stroke(row, C.white, 1, 0.7)
		local chip = Instance.new("Frame")
		chip.Name = "Rarity"
		chip.Position = UDim2.fromOffset(0, 0)
		chip.Size = UDim2.new(0, 6, 1, 0)
		chip.BorderSizePixel = 0
		chip.BackgroundColor3 = rarityColour(celebration.rarity)
		chip.Parent = row
		local label = UIStyle.text(row, "Name", UDim2.fromOffset(14, 0), UDim2.new(1, -130, 1, 0), SIZES.small, C.white,
			UIStyle.font(Enum.FontWeight.Bold))
		label.Text = string.upper(celebration.name)
		label.TextYAlignment = Enum.TextYAlignment.Center
		local tag = UIStyle.text(row, "Tag", UDim2.new(1, -122, 0, 0), UDim2.new(0, 114, 1, 0), SIZES.small,
			rarityColour(celebration.rarity), UIStyle.font(Enum.FontWeight.Bold), Enum.TextXAlignment.Right)
		tag.Text = string.upper(celebration.rarity)
		tag.TextYAlignment = Enum.TextYAlignment.Center
		tag.TextWrapped = false
		row.Activated:Connect(function()
			choose(i)
		end)
		rows[celebration.id] = row
	end
end

local function build(): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "CelebrationViewer"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 25
	gui.Enabled = false
	UIStyle.fitToScreen(gui)

	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	local title = UIStyle.titleTag(holder, "Tag", "CELEBRATIONS", UDim2.fromOffset(-18, -30), UDim2.fromOffset(300, 52), nil, "star")

	-- The stage.
	local stage = CelebrationStage.new(body, UDim2.fromOffset(MARGIN, 40), UDim2.fromOffset(VIEW_SIZE.X, VIEW_SIZE.Y))

	-- Under the stage: the counter, the views, slow motion; then prev / replay / next.
	local underY = 40 + VIEW_SIZE.Y + 10
	local counter = UIStyle.text(body, "Counter", UDim2.fromOffset(MARGIN, underY), UDim2.fromOffset(90, 36), SIZES.body,
		C.muted, UIStyle.font(Enum.FontWeight.Bold))
	local viewButtons: { [string]: TextButton } = {}
	for i, entry in ipairs({ { "ThreeQuarter", "3/4" }, { "Front", "FRONT" }, { "Side", "SIDE" } }) do
		viewButtons[entry[1]] = UIStyle.button(body, "View_" .. entry[1], entry[2],
			UDim2.fromOffset(MARGIN + 96 + (i - 1) * 104, underY), UDim2.fromOffset(96, 36), "outline", function()
				view = entry[1]
				placeCamera()
			end)
	end
	local slow: TextButton
	slow = UIStyle.button(body, "Slow", "SLOW-MO: OFF", UDim2.fromOffset(MARGIN + VIEW_SIZE.X - 150, underY),
		UDim2.fromOffset(150, 36), "outline", function()
			slowMotion = not slowMotion
			slow.Text = if slowMotion then "SLOW-MO: ON" else "SLOW-MO: OFF"
			playChosen()
		end)
	local rowY = underY + 46
	local third = (VIEW_SIZE.X - 20) / 3
	UIStyle.button(body, "Prev", "< PREV", UDim2.fromOffset(MARGIN, rowY), UDim2.fromOffset(third, 46), "outline", function()
		choose(index - 1)
	end)
	UIStyle.button(body, "Replay", "REPLAY", UDim2.fromOffset(MARGIN + third + 10, rowY), UDim2.fromOffset(third, 46),
		"outline", function()
			playChosen()
		end)
	UIStyle.button(body, "Next", "NEXT >", UDim2.fromOffset(MARGIN + 2 * (third + 10), rowY), UDim2.fromOffset(third, 46),
		"outline", function()
			choose(index + 1)
		end)

	-- The right side: the list, then the chosen one.
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(RIGHT_X, 40)
	list.Size = UDim2.fromOffset(RIGHT_WIDTH, 270)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.yellow
	list.Parent = body
	local rows: { [string]: TextButton } = {}
	fillList(list, rows)

	local infoY = 40 + 270 + 14
	local name = UIStyle.text(body, "Name", UDim2.fromOffset(RIGHT_X, infoY), UDim2.fromOffset(RIGHT_WIDTH, 34),
		SIZES.heading, C.white, UIStyle.heading())
	local rarity = UIStyle.text(body, "Rarity", UDim2.fromOffset(RIGHT_X, infoY + 36), UDim2.fromOffset(RIGHT_WIDTH, 22),
		SIZES.body, C.white, UIStyle.font(Enum.FontWeight.Bold))
	local facts = UIStyle.text(body, "Facts", UDim2.fromOffset(RIGHT_X, infoY + 60), UDim2.fromOffset(RIGHT_WIDTH, 40),
		SIZES.small, C.muted)
	facts.TextWrapped = true
	local about = UIStyle.text(body, "About", UDim2.fromOffset(RIGHT_X, infoY + 102), UDim2.fromOffset(RIGHT_WIDTH, 92),
		SIZES.small, C.white)
	about.TextWrapped = true
	about.TextYAlignment = Enum.TextYAlignment.Top

	local status = UIStyle.text(body, "Status", UDim2.fromOffset(RIGHT_X, rowY - 34), UDim2.fromOffset(RIGHT_WIDTH, 28),
		SIZES.small, C.yellow)
	-- Asks the admin panel's remote; PLAY ON ME closes the viewer to watch, MAKE IT MINE just says it's done.
	local function askAdmin(action: string, closeAfter: boolean)
		local celebration = ORDER[index]
		local remote = actionRemote
		if celebration == nil or remote == nil then
			return
		end
		local ok, done, message = pcall(function()
			return remote:InvokeServer(action, celebration.id)
		end)
		if ok and done and closeAfter then
			CelebrationViewer.close()
		elseif screen then
			(screen :: Screen).status.Text = if ok and typeof(message) == "string" then message else "The server didn't answer."
		end
	end
	local half = (RIGHT_WIDTH - 150 - 10) / 2
	local playOnMe = UIStyle.button(body, "PlayOnMe", "PLAY ON ME", UDim2.fromOffset(RIGHT_X, rowY), UDim2.fromOffset(half, 46),
		"primary", function()
			askAdmin("PlayCelebration", true)
		end)
	-- (Admin: makes it their own celebration at meets, without spinning.)
	local makeMine = UIStyle.button(body, "MakeMine", "MAKE IT MINE", UDim2.fromOffset(RIGHT_X + half + 10, rowY), UDim2.fromOffset(half, 46),
		"outline", function()
			askAdmin("SetCelebration", false)
		end)
	UIStyle.button(body, "Close", "CLOSE", UDim2.new(1, -MARGIN - 140, 0, rowY), UDim2.fromOffset(140, 46), "outline",
		function()
			CelebrationViewer.close()
		end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return {
		gui = gui, title = title, stage = stage, list = list, rows = rows, name = name,
		rarity = rarity, facts = facts, about = about, counter = counter, status = status, slow = slow,
		viewButtons = viewButtons, adminButtons = { playOnMe, makeMine },
	}
end

function CelebrationViewer.isOpen(): boolean
	local current = screen
	return current ~= nil and current.gui.Enabled
end

--[[
	Opens the viewer on the first celebration (or where it was left), with a fresh copy of the player's avatar.
	`admin`: from the admin panel, with PLAY ON ME and MAKE IT MINE (the server checks the account anyway); otherwise
	(the spin screen's SEE ALL) without them. `whenClosed` runs on CLOSE (back to the spin screen). `listKind`:
	"Entrance" lists the walk-outs (the spin screen's WALK-OUTS tab); otherwise the celebrations.
]]
function CelebrationViewer.open(admin: boolean?, whenClosed: (() -> ())?, listKind: string?)
	if actionRemote == nil then
		actionRemote = AdminRemotes.waitForClient(ReplicatedStorage).action
	end
	asAdmin = admin ~= false
	onClosed = whenClosed
	local wanted = if listKind and LISTS[listKind] then listKind else "Celebration"
	local current = screen or build()
	screen = current
	if wanted ~= kind then
		kind = wanted
		ORDER = LISTS[kind]
		fillList(current.list, current.rows)
	end
	index = math.clamp(lastIndex[kind], 1, #ORDER)
	current.title.Text = TITLES[kind]
	-- (The admin buttons and SLOW-MO are for celebrations.)
	for _, button in ipairs(current.adminButtons) do
		button.Visible = asAdmin and kind == "Celebration"
	end
	current.slow.Visible = kind == "Celebration" or kind == "Emote"
	local hasFigure = CelebrationStage.setFigure(current.stage)
	current.gui.Enabled = true
	placeCamera()
	show()
	if not asAdmin then
		current.status.Text = "A spin can land on any of these but the Default."
	end
	if not hasFigure then
		current.status.Text = "No character to show yet: open it again once you've spawned."
	end
end

function CelebrationViewer.close()
	local current = screen
	if current then
		CelebrationStage.clear(current.stage)
		current.gui.Enabled = false
	end
	local after = onClosed
	onClosed = nil
	if after then
		task.spawn(after)
	end
end

return CelebrationViewer
