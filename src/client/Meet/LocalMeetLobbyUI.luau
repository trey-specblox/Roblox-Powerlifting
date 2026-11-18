--!strict
--[[
	LocalMeetLobbyUI
	Client / Meet

	The Local meet venue on the player's screen (GAME_DESIGN.md §29.10 "The
	Local meet — first build"): drawn from the server's LobbyState and
	Standings, deciding nothing. LocalMeetController owns it.

		top right    EXIT (back to the gym); hidden while lifting, where the meet
		             screen's LEAVE takes its place
		left, top    the MEETS list (user 2026-11-05): one row for each of the five
		             meets with its number, level, countdown and sign-ups, a SIGN UP
		             button and a SPECTATE button that teleports there, and how far a
		             meet could still raise each lift's CN; hidden while lifting
		             (the meet screen's title is there)
		right        the STANDINGS: place, name, class, subtotal or total, points, and the player's own row and gaps;
		             on the left in the card's place while lifting (the meet
		             screen's scorecard is on the right)

	Built from UIStyle, the game's one look (and fitToScreen, which anchors each
	panel at its centre).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetConfig"))
local NationalsConfig = require(Shared:WaitForChild("Config"):WaitForChild("NationalsConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))
local NationalsRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("NationalsRemotes"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local LocalMeetLobbyUI = {}

export type Handlers = {
	exit: () -> (),
	-- Each asks for one of the meets by its number.
	signUp: (index: number) -> (),
	spectate: (index: number) -> (),
	-- The NATIONALS row (GAME_DESIGN §39): sign up / take off, and at Nationals, LEAVE NATIONALS.
	nationalsSignUp: () -> (),
	nationalsLeave: () -> (),
}

export type Ui = {
	gui: ScreenGui,
	-- Shows the venue screen, and whether the player is lifting (which hides the card and EXIT). `listOpen`: elsewhere in
	-- the game, the MEETS tab has the list open (the list alone, no EXIT or standings).
	setMode: (inVenue: boolean, lifting: boolean, listOpen: boolean) -> (),
	setClearView: (clear: boolean) -> (),
	-- `serverNow` is workspace:GetServerTimeNow().
	drawLobby: (lobby: LocalMeetRemotes.LobbyState?, serverNow: number) -> (),
	drawStandings: (standings: LocalMeetRemotes.Standings?) -> (),
	-- The NATIONALS row under the meets, from the server's view (nil or not shown: no row).
	drawNationals: (view: NationalsRemotes.View?, serverNow: number) -> (),
}

-- Below the meet screen's notice (24..130 from the top), which also carries the venue's notices, and right
-- of the tabs on the left edge (150 wide).
local CARD_TOP = 168
local LEFT = 172
-- The standings' top in the lobby: on the right, under EXIT.
local STANDINGS_TOP_RIGHT = 110
local ROWS = 8
local ROW_HEIGHT = 30
local STANDINGS_WIDTH = 470
-- Where the first row starts (under the title tag and the column heads), and the room for the player's own line under the last.
local ROWS_TOP = 44
local FOOT_HEIGHT = 28
-- The columns, across the panel (user, 2026-11-06: place, name, weight class, total, points).
local COLUMN = {
	placeWidth = 42,
	name = 62, nameWidth = 176,
	class = 240, classWidth = 62,
	total = 304, totalWidth = 62,
	points = 370, pointsWidth = 84,
}
-- The MEETS list. A phone shrinks every screen to under half size, so its buttons are drawn a little larger to be tappable.
local ON_PHONE = UIStyle.isTouchOnly()
local LIST_SCALE = if ON_PHONE then 1.15 else 1
local LIST_WIDTH = 560 * LIST_SCALE
local LIST_TOP = 50 * LIST_SCALE
local LIST_ROW_HEIGHT = 52 * LIST_SCALE
local LIST_BUTTON_HEIGHT = 42 * LIST_SCALE
local LIST_BUTTON_WIDTH = 122 * LIST_SCALE
local LIST_GAP = 8 * LIST_SCALE
-- The five halls and the State meet.
local MEET_COUNT = 6

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

local function clockText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Nationals is hours away: "1:59:30", or "1:30" under an hour.
local function longClockText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	if whole >= 3600 then
		return string.format("%d:%02d:%02d", whole // 3600, (whole % 3600) // 60, whole % 60)
	end
	return clockText(whole)
end

local function placeText(place: number): string
	local suffix = "TH"
	if place % 100 < 11 or place % 100 > 13 then
		suffix = if place % 10 == 1 then "ST" elseif place % 10 == 2 then "ND" elseif place % 10 == 3 then "RD" else "TH"
	end
	return string.format("%d%s", place, suffix)
end

function LocalMeetLobbyUI.build(handlers: Handlers): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "LocalMeetVenue"
	UIStyle.fitToScreen(gui)
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local exit = UIStyle.exitButton(gui, "Exit", "EXIT", UDim2.new(1, -194, 0, 22), handlers.exit)

	-- ------------------------------------------------ the MEETS list
	local cardHolder, card = UIStyle.panel(gui, "Card", UDim2.fromOffset(LEFT, CARD_TOP),
		-- Room for the NATIONALS row too (fitCard shortens the card while it isn't shown).
		UDim2.fromOffset(LIST_WIDTH, LIST_TOP + (MEET_COUNT + 1) * LIST_ROW_HEIGHT + 10))
	UIStyle.titleTag(cardHolder, "Tag", "MEETS", UDim2.fromOffset(-14, -24), UDim2.fromOffset(180, 40), nil, "star")
	UIStyle.collapsible(cardHolder)
	-- How far a meet could still raise each lift's CN (the meet allowance, GAME_DESIGN 33.3b).
	local allowance = UIStyle.label(card, "Allowance", UDim2.fromOffset(18, 26 * LIST_SCALE),
		UDim2.new(1, -36, 0, 18 * LIST_SCALE), C.muted)
	type ListRow = { title: TextLabel, status: TextLabel, signUp: TextButton, spectate: TextButton }
	local listRows: { ListRow } = {}
	for index = 1, MEET_COUNT do
		local y = LIST_TOP + (index - 1) * LIST_ROW_HEIGHT
		local right = LIST_WIDTH - 14
		local textWidth = LIST_WIDTH - 2 * (LIST_BUTTON_WIDTH + LIST_GAP) - 30
		local buttonY = y + (LIST_ROW_HEIGHT - LIST_BUTTON_HEIGHT) / 2
		listRows[index] = {
			title = UIStyle.label(card, "Title_" .. index, UDim2.fromOffset(18, y + 4 * LIST_SCALE),
				UDim2.fromOffset(textWidth, 23 * LIST_SCALE), C.white, UIStyle.heading()),
			status = UIStyle.label(card, "Status_" .. index, UDim2.fromOffset(18, y + 29 * LIST_SCALE),
				UDim2.fromOffset(textWidth, 17 * LIST_SCALE), C.muted),
			signUp = UIStyle.button(card, "SignUp_" .. index, "SIGN UP",
				UDim2.fromOffset(right - 2 * LIST_BUTTON_WIDTH - LIST_GAP, buttonY),
				UDim2.fromOffset(LIST_BUTTON_WIDTH, LIST_BUTTON_HEIGHT), "primary", function()
					handlers.signUp(index)
				end),
			spectate = UIStyle.button(card, "Spectate_" .. index, "SPECTATE",
				UDim2.fromOffset(right - LIST_BUTTON_WIDTH, buttonY),
				UDim2.fromOffset(LIST_BUTTON_WIDTH, LIST_BUTTON_HEIGHT), "outline", function()
					handlers.spectate(index)
				end),
		}
	end
	-- The NATIONALS row under the meets: one button (on the right), so its words have the second button's room too.
	local nationalsY = LIST_TOP + MEET_COUNT * LIST_ROW_HEIGHT
	local nationalsTextWidth = LIST_WIDTH - (LIST_BUTTON_WIDTH + LIST_GAP) - 30
	local nationalsButtonY = nationalsY + (LIST_ROW_HEIGHT - LIST_BUTTON_HEIGHT) / 2
	-- What the button does now (sign up / take off, or leave).
	local nationalsLeaving = false
	local nationalsRow = {
		title = UIStyle.label(card, "Title_Nationals", UDim2.fromOffset(18, nationalsY + 4 * LIST_SCALE),
			UDim2.fromOffset(nationalsTextWidth, 23 * LIST_SCALE), C.yellow, UIStyle.heading()),
		status = UIStyle.label(card, "Status_Nationals", UDim2.fromOffset(18, nationalsY + 29 * LIST_SCALE),
			UDim2.fromOffset(nationalsTextWidth, 17 * LIST_SCALE), C.muted),
		button = UIStyle.button(card, "SignUp_Nationals", "SIGN UP",
			UDim2.fromOffset(LIST_WIDTH - 14 - LIST_BUTTON_WIDTH, nationalsButtonY),
			UDim2.fromOffset(LIST_BUTTON_WIDTH, LIST_BUTTON_HEIGHT), "primary", function()
				if nationalsLeaving then
					handlers.nationalsLeave()
				else
					handlers.nationalsSignUp()
				end
			end),
	}
	nationalsRow.title.Visible, nationalsRow.status.Visible, nationalsRow.button.Visible = false, false, false
	-- The card is as tall as its rows: the meets, and the NATIONALS row when it shows.
	local function fitCard(withNationals: boolean)
		local rows = MEET_COUNT + (if withNationals then 1 else 0)
		local height = UDim2.new(1, 0, 0, LIST_TOP + rows * LIST_ROW_HEIGHT + 10)
		for _, name in ipairs({ "Body", "Back" }) do
			local piece = cardHolder:FindFirstChild(name)
			if piece and piece:IsA("GuiObject") then
				piece.Size = height
			end
		end
	end
	fitCard(false)
	local nationalsShown = false

	-- ------------------------------------------------ the STANDINGS
	local standingsSize = Vector2.new(STANDINGS_WIDTH, ROWS_TOP + ROWS * ROW_HEIGHT + FOOT_HEIGHT + 8)
	local standingsHolder, standingsBody = UIStyle.panel(gui, "Standings",
		UDim2.new(1, -24 - standingsSize.X, 0, STANDINGS_TOP_RIGHT), UDim2.fromOffset(standingsSize.X, standingsSize.Y))
	local standingsTag = UIStyle.titleTag(standingsHolder, "Tag", "STANDINGS", UDim2.fromOffset(-14, -24),
		UDim2.fromOffset(260, 40), nil, "corner")
	-- On a phone it starts closed: the + opens it.
	local setStandingsOpen = UIStyle.collapsible(standingsHolder, not ON_PHONE)
	-- The box is only as tall as its rows, and the line about the player's own place.
	local function fitStandings(rowCount: number, hasYouLine: boolean)
		local height = UDim2.new(1, 0, 0, ROWS_TOP + math.max(rowCount, 1) * ROW_HEIGHT + (if hasYouLine then FOOT_HEIGHT else 0) + 8)
		for _, name in ipairs({ "Body", "Back" }) do
			local piece = standingsHolder:FindFirstChild(name)
			if piece and piece:IsA("GuiObject") then
				piece.Size = height
			end
		end
	end
	fitStandings(0, false)
	local empty = UIStyle.label(standingsBody, "Empty", UDim2.fromOffset(18, ROWS_TOP), UDim2.new(1, -36, 0, 20), C.muted)
	empty.Text = "No meet in this hall right now."
	-- The columns: place, name, weight class, total, points (user, 2026-11-06).
	local function columnHead(name: string, x: number, width: number, align: Enum.TextXAlignment?)
		local head = UIStyle.label(standingsBody, "Head_" .. name, UDim2.fromOffset(x, 26), UDim2.fromOffset(width, 14), C.muted,
			UIStyle.heading(), align)
		head.Text = name
		return head
	end
	local heads = { columnHead("CLASS", COLUMN.class, COLUMN.classWidth, Enum.TextXAlignment.Center),
		columnHead("TOTAL", COLUMN.total, COLUMN.totalWidth, Enum.TextXAlignment.Right),
		columnHead("POINTS", COLUMN.points, COLUMN.pointsWidth, Enum.TextXAlignment.Right) }
	local rows: { { back: Frame, place: TextLabel, name: TextLabel, class: TextLabel, total: TextLabel, points: TextLabel } } = {}
	for index = 1, ROWS do
		local y = ROWS_TOP + (index - 1) * ROW_HEIGHT
		-- The player's own row stands out, so they can find themselves at a glance.
		local back = UIStyle.frame(standingsBody, "RowBack_" .. index, UDim2.fromOffset(8, y - 3), UDim2.new(1, -16, 0, ROW_HEIGHT - 2),
			C.yellow)
		back.BackgroundTransparency = 0.82
		back.Visible = false
		UIStyle.stroke(back, C.yellow, 1, 0.2)
		local place = UIStyle.label(standingsBody, "Place_" .. index, UDim2.fromOffset(16, y), UDim2.fromOffset(COLUMN.placeWidth, 22), C.yellow,
			UIStyle.heading())
		local name = UIStyle.label(standingsBody, "Name_" .. index, UDim2.fromOffset(COLUMN.name, y), UDim2.fromOffset(COLUMN.nameWidth, 22), C.white,
			UIStyle.heading())
		local class = UIStyle.label(standingsBody, "Class_" .. index, UDim2.fromOffset(COLUMN.class, y + 3), UDim2.fromOffset(COLUMN.classWidth, 16),
			C.muted, nil, Enum.TextXAlignment.Center)
		local total = UIStyle.label(standingsBody, "Total_" .. index, UDim2.fromOffset(COLUMN.total, y), UDim2.fromOffset(COLUMN.totalWidth, 22), C.white,
			UIStyle.heading(), Enum.TextXAlignment.Right)
		local points = UIStyle.label(standingsBody, "Points_" .. index, UDim2.fromOffset(COLUMN.points, y), UDim2.fromOffset(COLUMN.pointsWidth, 22),
			C.white, UIStyle.heading(), Enum.TextXAlignment.Right)
		rows[index] = { back = back, place = place, name = name, class = class, total = total, points = points }
	end
	-- Where the player stands, in points, against the lifters either side of them.
	local youLine = UIStyle.label(standingsBody, "You", UDim2.fromOffset(16, ROWS_TOP), UDim2.new(1, -32, 0, 20), C.yellow, UIStyle.heading())
	youLine.Visible = false

	local ui = {} :: Ui
	ui.gui = gui

	local liftingNow = false
	local inVenueNow = false
	local clearView = false
	ui.setMode = function(inVenue: boolean, lifting: boolean, listOpen: boolean)
		gui.Enabled = inVenue or listOpen
		-- A meet starting opens the standings, on a phone too, where they start closed in the lobby (user 2026-11-06).
		if lifting and not liftingNow then
			setStandingsOpen(true)
		end
		liftingNow = lifting
		inVenueNow = inVenue
		exit.Visible = inVenue and not lifting
		cardHolder.Visible = not lifting
		standingsHolder.Visible = inVenue and not clearView
		-- In the lobby on the right (under EXIT), so short screens fit it beside the card; while lifting in the
		-- card's place on the left, as the meet screen's scorecard is on the right. fitToScreen anchors the panel
		-- at its centre, so place the centre.
		local anchor = standingsHolder.AnchorPoint
		local offsetX, offsetY = standingsSize.X * anchor.X, standingsSize.Y * anchor.Y
		standingsHolder.Position = if lifting
			then UDim2.fromOffset(LEFT + offsetX, CARD_TOP + offsetY)
			else UDim2.new(1, -24 - standingsSize.X + offsetX, 0, STANDINGS_TOP_RIGHT + offsetY)
	end

	-- The lifter's turn (MeetLiftMoment): nothing over the view until the verdict.
	ui.setClearView = function(clear: boolean)
		clearView = clear
		standingsHolder.Visible = inVenueNow and not clear
	end

	ui.drawLobby = function(lobby: LocalMeetRemotes.LobbyState?, serverNow: number)
		if lobby == nil then
			allowance.Text = "…"
			for _, row in ipairs(listRows) do
				row.title.Text, row.status.Text = "", ""
				row.signUp.Visible, row.spectate.Visible = false, false
			end
			return
		end
		local raises = {}
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			local percent = lobby.allowancePercent and lobby.allowancePercent[lift]
			table.insert(raises, string.format("%s %s", string.sub(lift, 1, 1),
				if percent then string.format("+%.1f%%", percent) else "—"))
		end
		allowance.Text = "CN RAISE LEFT  " .. table.concat(raises, "  ·  ")
		for index, row in ipairs(listRows) do
			local meet = lobby.meets[index]
			row.signUp.Visible = meet ~= nil and not liftingNow
			row.spectate.Visible = meet ~= nil and not liftingNow
			if meet == nil then
				row.title.Text, row.status.Text = "", ""
				continue
			end
			-- "MEET 3  ·  REGIONAL x2": a Local meet just says its number.
			row.title.Text = if meet.state then string.format("STATE MEET  ·  x%d", meet.potMultiplier)
				elseif meet.potMultiplier > 1
				then string.format("MEET %d  ·  %s x%d", index, string.gsub(meet.levelLabel, " MEET$", ""), meet.potMultiplier)
				else "MEET " .. index
			row.title.TextColor3 = if meet.potMultiplier > 1 then C.yellow else C.white
			local untilStart = meet.nextStartAt - serverNow
			local closesIn = meet.signUpClosesAt - serverNow
			local lifters = string.format("%d/%d", meet.signedUpCount, meet.maxLifters)
			-- A Nationals server runs no State meet (GAME_DESIGN §39; the server refuses State sign-ups there).
			if meet.state and Workspace:GetAttribute(NationalsConfig.ServerAttribute) ~= nil then
				row.status.Text = "NOT AT NATIONALS"
				row.status.TextColor3 = C.muted
				row.signUp.Visible = false
			elseif meet.notQualified and not meet.running then
				row.status.Text = "QUALIFY FIRST  ·  " .. meet.notQualified
				row.status.TextColor3 = C.muted
				row.signUp.Text = "SIGN UP"
			elseif meet.state and meet.running then
				-- The wait for the next one starts when this one finishes.
				row.status.Text = if meet.signedUp then "IN PROGRESS  ·  YOU ARE ON THE NEXT LIST" else "IN PROGRESS  ·  NEXT LIST " .. lifters
				row.status.TextColor3 = if meet.signedUp then C.yellow else C.muted
				row.signUp.Text = if meet.signedUp then "TAKE OFF" else "SIGN UP"
			elseif meet.signedUp then
				row.status.Text = (if meet.running then "IN PROGRESS  ·  YOU ARE NEXT IN " else "YOU ARE SIGNED UP  ·  STARTS IN ")
					.. clockText(untilStart)
				row.status.TextColor3 = C.yellow
				row.signUp.Text = "TAKE OFF"
			elseif meet.running then
				row.status.Text = "IN PROGRESS  ·  NEXT LIST " .. lifters
				row.status.TextColor3 = C.muted
				row.signUp.Text = "SIGN UP"
			elseif closesIn <= 0 then
				row.status.Text = "SIGN-UPS CLOSED  ·  STARTS IN " .. clockText(untilStart)
				row.status.TextColor3 = C.muted
				row.signUp.Text = "SIGN UP"
			else
				row.status.Text = string.format("STARTS IN %s  ·  %s", clockText(untilStart), lifters)
				row.status.TextColor3 = C.muted
				row.signUp.Text = "SIGN UP"
			end
			row.spectate.Text = if lobby.hereIndex == index then "YOU ARE HERE" elseif lobby.hereIndex then "SPECTATE" else "WATCH"
			row.spectate.AutoButtonColor = lobby.hereIndex ~= index
			row.spectate.TextTransparency = if lobby.hereIndex == index then 0.5 else 0
		end
	end

	-- The NATIONALS row (GAME_DESIGN §39): drawn from the server's view, deciding nothing.
	ui.drawNationals = function(view: NationalsRemotes.View?, serverNow: number)
		local shown = view ~= nil and view.shown
		if shown ~= nationalsShown then
			nationalsShown = shown
			fitCard(shown)
			nationalsRow.title.Visible, nationalsRow.status.Visible, nationalsRow.button.Visible = shown, shown, shown
		end
		if view == nil or not shown then
			return
		end
		local row = nationalsRow
		row.title.Text = string.format("NATIONALS  ·  x%d%s", view.potMultiplier, if view.test then "  ·  TEST" else "")
		row.status.TextColor3 = C.muted
		nationalsLeaving = false
		row.button.Visible = true
		local untilStart = view.nextStartAt - serverNow
		local count = if view.signedUpCount then string.format("%d SIGNED UP", view.signedUpCount) else nil
		if view.here then
			row.status.Text = string.format("YOU ARE AT NATIONALS  ·  %s  ·  %d %s", view.classLabel or "",
				view.liftersHere or 0, if view.liftersHere == 1 then "LIFTER" else "LIFTERS")
			row.status.TextColor3 = C.yellow
			row.button.Text = "LEAVE"
			nationalsLeaving = true
		elseif view.status then
			row.status.Text = view.status
			row.status.TextColor3 = C.yellow
			row.button.Visible = false
		elseif view.signedUp then
			row.status.Text = string.format("SIGNED UP (%s)  ·  STARTS IN %s%s", view.classLabel or "", longClockText(untilStart),
				if count then "  ·  " .. count else "")
			row.status.TextColor3 = C.yellow
			row.button.Text = "TAKE OFF"
		elseif not view.qualified then
			row.status.Text = "SPOT HOLDERS ONLY  ·  " .. (view.why or "")
			row.button.Text = "SIGN UP"
		elseif view.signUpClosesAt - serverNow <= 0 then
			row.status.Text = "SIGN-UPS CLOSED  ·  STARTS IN " .. longClockText(untilStart)
			row.button.Text = "SIGN UP"
		else
			row.status.Text = string.format("STARTS IN %s  ·  %s  ·  NEEDS %d", longClockText(untilStart),
				count or "ALL SERVERS", view.minimumLifters)
			row.button.Text = "SIGN UP"
		end
		row.button.Visible = row.button.Visible and not liftingNow
	end

	-- "YOU: 2ND  ·  1.25 BEHIND THEO (CPU)  ·  0.80 AHEAD OF NADIA (CPU)".
	local function youText(all: { LocalMeetRemotes.StandingRow }, index: number): string
		local mine = all[index]
		if mine.status == "Bombed" then
			return "YOU: BOMBED OUT, NO POINTS"
		elseif mine.status == "Withdrawn" then
			return "YOU: WITHDRAWN"
		end
		local points = mine.points
		if points == nil then
			return "YOU: NO POINTS YET"
		end
		local parts = { "YOU: " .. string.upper(placeText(mine.place or index)) }
		local above, below = all[index - 1], all[index + 1]
		if above and above.points then
			table.insert(parts, string.format("%.2f BEHIND %s", above.points - points, string.upper(above.name)))
		end
		if below and below.points then
			table.insert(parts, string.format("%.2f AHEAD OF %s", points - below.points, string.upper(below.name)))
		end
		return table.concat(parts, "  ·  ")
	end

	ui.drawStandings = function(standings: LocalMeetRemotes.Standings?)
		local function clearRow(row: { back: Frame, place: TextLabel, name: TextLabel, class: TextLabel, total: TextLabel, points: TextLabel })
			row.back.Visible = false
			row.place.Text, row.name.Text, row.class.Text, row.total.Text, row.points.Text = "", "", "", "", ""
		end
		if standings == nil then
			fitStandings(0, false)
			standingsTag.Text = "STANDINGS"
			empty.Visible = true
			youLine.Visible = false
			for _, head in ipairs(heads) do
				head.Visible = false
			end
			for _, row in ipairs(rows) do
				clearRow(row)
			end
			return
		end
		local heading = if standings.final then "FINAL STANDINGS" else standings.heading
		standingsTag.Text = if standings.meetIndex then string.format("MEET %d  ·  %s", standings.meetIndex, heading) else heading
		empty.Visible = #standings.rows == 0
		for _, head in ipairs(heads) do
			head.Visible = #standings.rows > 0
		end
		-- The top of the list, up to the rows there are. More lifters than that (the State meet): your own row takes the last one.
		local myIndex: number? = nil
		local me = Players.LocalPlayer.UserId
		for index, data in ipairs(standings.rows) do
			if data.userId == me then
				myIndex = index
			end
		end
		local shownRows = math.min(#standings.rows, #rows)
		for index, row in ipairs(rows) do
			local data = standings.rows[if index == shownRows and myIndex and myIndex > shownRows then myIndex else index]
			if data == nil or index > shownRows then
				clearRow(row)
				continue
			end
			local own = data.userId == me
			row.back.Visible = own
			row.place.Text = if data.place then placeText(data.place) else "—"
			row.name.Text = data.name
			row.name.TextColor3 = if own then C.yellow else C.white
			row.class.Text = data.classLabel
			row.total.Text = kgText(data.subtotalKg)
			if data.status == "Bombed" then
				row.points.Text, row.points.TextColor3 = "BOMB", C.red
			elseif data.status == "Withdrawn" then
				row.points.Text, row.points.TextColor3 = "OUT", C.muted
			elseif data.points then
				row.points.Text, row.points.TextColor3 = string.format("%.2f", data.points), if own then C.yellow else C.white
			else
				row.points.Text, row.points.TextColor3 = "—", C.muted
			end
		end
		fitStandings(shownRows, myIndex ~= nil)
		youLine.Visible = myIndex ~= nil
		if myIndex then
			youLine.Text = youText(standings.rows, myIndex)
			youLine.Position = UDim2.fromOffset(16, ROWS_TOP + shownRows * ROW_HEIGHT + 4)
		end
	end

	return ui
end

return LocalMeetLobbyUI
