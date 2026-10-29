--!strict
--[[
	LocalMeetLobbyUI
	Client / Meet

	The Local meet venue on the player's screen (GAME_DESIGN.md §29.10 "The
	Local meet — first build"): drawn from the server's LobbyState and
	Standings, deciding nothing. LocalMeetController owns it.

		top right    EXIT (back to the gym); hidden while lifting, where the meet
		             screen's LEAVE takes its place
		left, top    the LOCAL MEET card: the countdown to the next meet, the
		             sign-ups, whether you are on the list, SIGN UP; hidden while
		             lifting (the meet screen's title is there)
		right        the STANDINGS: place, name, class, subtotal or total, score;
		             on the left in the card's place while lifting (the meet
		             screen's scorecard is on the right)

	Built from UIStyle, the game's one look (and fitToScreen, which anchors each
	panel at its centre).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local LocalMeetLobbyUI = {}

export type Handlers = {
	exit: () -> (),
	signUp: () -> (),
}

export type Ui = {
	gui: ScreenGui,
	-- Shows the venue screen, and whether the player is lifting (which hides the card and EXIT).
	setMode: (inVenue: boolean, lifting: boolean) -> (),
	drawLobby: (lobby: LocalMeetRemotes.LobbyState?, secondsToStart: number?) -> (),
	drawStandings: (standings: LocalMeetRemotes.Standings?) -> (),
}

-- Below the meet screen's notice (24..130 from the top), which also carries the venue's notices, and right
-- of the STATS tab on the left edge (118 wide).
local CARD_TOP = 168
local LEFT = 140
-- The standings' top in the lobby: on the right, under EXIT.
local STANDINGS_TOP_RIGHT = 110
local ROWS = 8
local ROW_HEIGHT = 30

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

local function clockText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
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

	-- ------------------------------------------------ the LOCAL MEET card
	local cardHolder, card = UIStyle.panel(gui, "Card", UDim2.fromOffset(LEFT, CARD_TOP), UDim2.fromOffset(330, 176))
	UIStyle.titleTag(cardHolder, "Tag", "LOCAL MEET", UDim2.fromOffset(-14, -24), UDim2.fromOffset(210, 40), nil, "star")
	local countdown = UIStyle.label(card, "Countdown", UDim2.fromOffset(18, 26), UDim2.new(1, -36, 0, 34), C.white,
		UIStyle.heading())
	local signUps = UIStyle.label(card, "SignUps", UDim2.fromOffset(18, 66), UDim2.new(1, -36, 0, 18), C.muted)
	local you = UIStyle.label(card, "You", UDim2.fromOffset(18, 88), UDim2.new(1, -36, 0, 18), C.yellow, UIStyle.heading())
	local signUpButton = UIStyle.button(card, "SignUp", "SIGN UP", UDim2.new(0, 18, 1, -54), UDim2.new(1, -36, 0, 40),
		"primary", handlers.signUp)

	-- ------------------------------------------------ the STANDINGS
	local standingsSize = Vector2.new(400, 46 + ROWS * ROW_HEIGHT)
	local standingsHolder, standingsBody = UIStyle.panel(gui, "Standings",
		UDim2.new(1, -24 - standingsSize.X, 0, STANDINGS_TOP_RIGHT), UDim2.fromOffset(standingsSize.X, standingsSize.Y))
	local standingsTag = UIStyle.titleTag(standingsHolder, "Tag", "STANDINGS", UDim2.fromOffset(-14, -24),
		UDim2.fromOffset(260, 40), nil, "corner")
	local empty = UIStyle.label(standingsBody, "Empty", UDim2.fromOffset(18, 30), UDim2.new(1, -36, 0, 20), C.muted)
	empty.Text = "No meet yet. Sign up at the desk."
	local rows: { { place: TextLabel, name: TextLabel, detail: TextLabel, score: TextLabel } } = {}
	for index = 1, ROWS do
		local y = 26 + (index - 1) * ROW_HEIGHT
		local place = UIStyle.label(standingsBody, "Place_" .. index, UDim2.fromOffset(16, y), UDim2.fromOffset(46, 22), C.yellow,
			UIStyle.heading())
		local name = UIStyle.label(standingsBody, "Name_" .. index, UDim2.fromOffset(66, y), UDim2.fromOffset(130, 22), C.white,
			UIStyle.heading())
		local detail = UIStyle.label(standingsBody, "Detail_" .. index, UDim2.fromOffset(200, y + 3), UDim2.fromOffset(110, 16),
			C.muted)
		local score = UIStyle.label(standingsBody, "Score_" .. index, UDim2.fromOffset(312, y), UDim2.fromOffset(72, 22), C.white,
			UIStyle.heading(), Enum.TextXAlignment.Right)
		rows[index] = { place = place, name = name, detail = detail, score = score }
	end

	local ui = {} :: Ui
	ui.gui = gui

	local liftingNow = false
	ui.setMode = function(inVenue: boolean, lifting: boolean)
		gui.Enabled = inVenue
		liftingNow = lifting
		exit.Visible = not lifting
		cardHolder.Visible = not lifting
		-- In the lobby on the right (under EXIT), so short screens fit it beside the card; while lifting in the
		-- card's place on the left, as the meet screen's scorecard is on the right. fitToScreen anchors the panel
		-- at its centre, so place the centre.
		local anchor = standingsHolder.AnchorPoint
		local offsetX, offsetY = standingsSize.X * anchor.X, standingsSize.Y * anchor.Y
		standingsHolder.Position = if lifting
			then UDim2.fromOffset(LEFT + offsetX, CARD_TOP + offsetY)
			else UDim2.new(1, -24 - standingsSize.X + offsetX, 0, STANDINGS_TOP_RIGHT + offsetY)
	end

	ui.drawLobby = function(lobby: LocalMeetRemotes.LobbyState?, secondsToStart: number?)
		if lobby == nil or secondsToStart == nil then
			countdown.Text = "…"
			signUps.Text = ""
			you.Text = ""
			return
		end
		local closesIn = secondsToStart - (lobby.nextStartAt - lobby.signUpClosesAt)
		if lobby.meetRunning then
			countdown.Text = "MEET IN PROGRESS"
		else
			countdown.Text = "NEXT MEET  " .. clockText(secondsToStart)
		end
		signUps.Text = string.format("%d SIGNED UP  ·  NEEDS %d  ·  MAX %d", lobby.signedUpCount, lobby.minimumLifters,
			lobby.maxLifters)
		if lobby.signedUp then
			you.Text = if lobby.meetRunning then "YOU ARE ON THE LIST FOR THE NEXT MEET" else "YOU ARE SIGNED UP"
			you.TextColor3 = C.yellow
			signUpButton.Text = "TAKE MY NAME OFF"
		elseif closesIn <= 0 and not lobby.meetRunning then
			you.Text = "SIGN-UPS CLOSED  ·  OPEN AGAIN IN " .. clockText(secondsToStart)
			you.TextColor3 = C.muted
			signUpButton.Text = "SIGN UP"
		else
			you.Text = "YOU ARE NOT SIGNED UP"
			you.TextColor3 = C.muted
			signUpButton.Text = "SIGN UP"
		end
		signUpButton.Visible = not liftingNow
	end

	ui.drawStandings = function(standings: LocalMeetRemotes.Standings?)
		if standings == nil then
			standingsTag.Text = "STANDINGS"
			empty.Visible = true
			for _, row in ipairs(rows) do
				row.place.Text, row.name.Text, row.detail.Text, row.score.Text = "", "", "", ""
			end
			return
		end
		standingsTag.Text = if standings.final then "FINAL STANDINGS" else standings.heading
		empty.Visible = #standings.rows == 0
		for index, row in ipairs(rows) do
			local data = standings.rows[index]
			if data == nil then
				row.place.Text, row.name.Text, row.detail.Text, row.score.Text = "", "", "", ""
				continue
			end
			row.place.Text = if data.place then placeText(data.place) else "—"
			row.name.Text = data.name
			local parts = {}
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				table.insert(parts, if data.best[lift] then kgText(data.best[lift]) else "—")
			end
			row.detail.Text = string.format("%s  ·  %s", data.classLabel, table.concat(parts, "/"))
			if data.status == "Bombed" then
				row.score.Text, row.score.TextColor3 = "BOMB", C.red
			elseif data.status == "Withdrawn" then
				row.score.Text, row.score.TextColor3 = "OUT", C.muted
			elseif data.scorePercent then
				row.score.Text, row.score.TextColor3 = string.format("%.1f%%", data.scorePercent), C.white
			else
				row.score.Text, row.score.TextColor3 = kgText(data.subtotalKg), C.muted
			end
		end
	end

	return ui
end

return LocalMeetLobbyUI
