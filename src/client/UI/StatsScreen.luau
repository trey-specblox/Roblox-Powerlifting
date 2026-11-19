--!strict
--[[
	StatsScreen
	Client / UI

	The PLAYER STATS screen (GAME_DESIGN "One UI style for the whole game",
	user 2026-10-28: "the last photo should be the stat visual"; opened "a key
	plus a button"). Built from UIStyle. It shows what the server answers
	(StatsRemotes.GET_MY_STATS, a read-only snapshot). The one thing it can ask
	to change is the player's weight goal (GOAL button, StatsRemotes.
	SET_WEIGHT_GOAL, GAME_DESIGN §38.3); the server decides.

	Opening: press OPEN_KEY (not while typing), or the STATS tab on the left edge
	of the screen (phones). OPEN_KEY again, BACK, or the tab closes it.

		left    the player's avatar, name, weight class, bodyweight and coins; a
		        gold medal on the avatar's corner for the newest numbered State
		        Champion badge (GAME_DESIGN §36.4), "x3" for more, and pressing it
		        lists every season's badge
		middle  COMPETITION NUMBER per lift and the total; PROVEN (Competition
		        Scale) per lift, or UNPROVEN, and the BEST TOTAL; all for the
		        build of the current weight class
		right   TECHNIQUE: a five-cornered radar of the five trainable stats
		        (effective values, the outer edge = 100) with each stat's name
		        and value at its corner; under it the STATE LADDER and the
		        NATIONALS placings (GAME_DESIGN §36.4) of the current class
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local CoinConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoinConfig"))
local StatsRemotes = require(Shared:WaitForChild("Stats"):WaitForChild("StatsRemotes"))
local BodyweightConfig = require(Shared:WaitForChild("Config"):WaitForChild("BodyweightConfig"))
local WeightClass = require(Shared:WaitForChild("Progression"):WaitForChild("WeightClass"))
local GymRecordAnnouncer = require(script.Parent.Parent:WaitForChild("Meet"):WaitForChild("GymRecordAnnouncer"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local ChampionBadge = require(script.Parent:WaitForChild("ChampionBadge"))
local MenuKeys = require(script.Parent:WaitForChild("MenuKeys"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local StatsScreen = {}

local OPEN_KEY = Enum.KeyCode.C
local PANEL_WIDTH, PANEL_HEIGHT = 940, 520
local RADAR_RADIUS = 118
local started = false

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d kg", kg) else string.format("%.1f kg", kg)
end

-- A straight line from `a` to `b` (pixels inside `parent`).
local function line(parent: Instance, name: string, a: Vector2, b: Vector2, thickness: number, colour: Color3,
	transparency: number?): Frame
	local delta = b - a
	local piece = UIStyle.frame(parent, name, UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		UDim2.fromOffset(delta.Magnitude, thickness), colour, math.deg(math.atan2(delta.Y, delta.X)))
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.BackgroundTransparency = transparency or 0
	return piece
end

local function dot(parent: Instance, name: string, at: Vector2, size: number, colour: Color3): Frame
	local piece = UIStyle.frame(parent, name, UDim2.fromOffset(at.X, at.Y), UDim2.fromOffset(size, size), colour)
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = piece
	return piece
end

-- Corner `index` of `count` at `radius` around `centre`, the first at the top, going clockwise.
local function corner(centre: Vector2, radius: number, index: number, count: number): Vector2
	local angle = math.rad(-90 + (index - 1) * 360 / count)
	return centre + Vector2.new(math.cos(angle), math.sin(angle)) * radius
end

function StatsScreen.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remotes = StatsRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Stats"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	UIStyle.fitToScreen(gui) -- shrink on short screens so nothing overlaps

	-- The STATS tab on the left edge (also the way in on a phone).
	local tab = Instance.new("TextButton")
	tab.Name = "Tab"
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Position = UDim2.new(0, 0, 0.5, 0)
	-- The same width as the coins, TELEPORT and GEAR, so the side column lines up.
	tab.Size = UDim2.fromOffset(150, 44)
	tab.BackgroundColor3 = C.ink
	tab.BorderSizePixel = 0
	tab.AutoButtonColor = true
	tab.Text = ""
	tab.Parent = gui
	UIStyle.stroke(tab, C.yellow, 2)
	local tabText = UIStyle.text(tab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -40, 1, 0), SIZES.body, C.white,
		UIStyle.heading())
	tabText.Text = "STATS"
	UIStyle.slashes(tab, UDim2.new(1, -28, 0, 9), 26)
	local keyHint = UIStyle.text(tab, "Key", UDim2.new(0, 10, 1, 2), UDim2.fromOffset(100, 16), SIZES.small, C.muted)
	keyHint.Text = "[" .. OPEN_KEY.Name .. "]"
	keyHint.Visible = not UIStyle.isTouchOnly()

	-- The panel.
	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	UIStyle.titleTag(holder, "Tag", "PLAYER STATS", UDim2.fromOffset(-18, -30), UDim2.fromOffset(300, 52), nil, "star")

	-- Left: avatar, name, class.
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Position = UDim2.fromOffset(34, 44)
	avatar.Size = UDim2.fromOffset(200, 200)
	avatar.BackgroundColor3 = C.navyDeep
	avatar.BorderSizePixel = 0
	avatar.Image = ""
	avatar.Parent = body
	UIStyle.stroke(avatar, C.white, 2)
	local nameSlab = UIStyle.frame(body, "NameSlab", UDim2.fromOffset(24, 258), UDim2.fromOffset(230, 42), C.white, -3)
	local nameText = UIStyle.text(nameSlab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), SIZES.body, C.ink,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	nameText.Text = player.DisplayName
	local classText = UIStyle.text(body, "Class", UDim2.fromOffset(24, 314), UDim2.fromOffset(230, 30), SIZES.heading,
		C.yellow, UIStyle.heading(), Enum.TextXAlignment.Center)
	local weightText = UIStyle.text(body, "Bodyweight", UDim2.fromOffset(24, 346), UDim2.fromOffset(230, 26), SIZES.body,
		C.white, nil, Enum.TextXAlignment.Center)
	-- The weight goal (GAME_DESIGN §38.3): MAINTAIN, or bulk / cut to a class; pressing it opens the goal list.
	local openGoals: () -> () = function() end
	local goalButton = UIStyle.button(body, "WeightGoal", "GOAL: MAINTAIN", UDim2.fromOffset(34, 374), UDim2.fromOffset(210, 30),
		"outline", function()
			openGoals()
		end)
	-- The coins (GAME_DESIGN 30.6), under the bodyweight.
	local coinsText = UIStyle.text(body, "Coins", UDim2.fromOffset(24, 410), UDim2.fromOffset(230, 30), SIZES.heading,
		C.yellow, UIStyle.heading(), Enum.TextXAlignment.Center)
	-- The meet titles (GAME_DESIGN §35.8), under the coins.
	local titlesText = UIStyle.text(body, "Titles", UDim2.fromOffset(24, 444), UDim2.fromOffset(230, 40), SIZES.small,
		C.white, UIStyle.heading(), Enum.TextXAlignment.Center)
	titlesText.TextWrapped = true

	-- The newest State Champion badge, pinned on the avatar's top-right corner; pressing it lists them all.
	local MEDAL_SIZE = 120
	local medalButton = Instance.new("TextButton")
	medalButton.Name = "ChampionBadge"
	medalButton.AnchorPoint = Vector2.new(0.5, 0.5)
	medalButton.Position = UDim2.fromOffset(34 + 200 - 28, 44 + 52)
	medalButton.Size = UDim2.fromOffset(MEDAL_SIZE, MEDAL_SIZE)
	medalButton.BackgroundTransparency = 1
	medalButton.Text = ""
	medalButton.ZIndex = 5
	medalButton.Visible = false
	medalButton.Parent = body
	local medalCount = UIStyle.frame(body, "BadgeCount", UDim2.fromOffset(34 + 200 + 8, 44 + 104), UDim2.fromOffset(46, 28),
		C.ink)
	medalCount.AnchorPoint = Vector2.new(0.5, 0.5)
	medalCount.ZIndex = 8
	medalCount.Visible = false
	UIStyle.stroke(medalCount, C.yellow, 2)
	local medalCountText = UIStyle.text(medalCount, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), SIZES.small, C.yellow,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	medalCountText.ZIndex = 9
	-- The list of every badge, over the avatar.
	local badgeList = UIStyle.frame(body, "BadgeList", UDim2.fromOffset(24, 30), UDim2.fromOffset(250, 270), C.navyDeep)
	badgeList.ZIndex = 10
	badgeList.Visible = false
	UIStyle.stroke(badgeList, C.yellow, 2)
	local listHead = UIStyle.text(badgeList, "Head", UDim2.fromOffset(12, 8), UDim2.new(1, -56, 0, 30), SIZES.body, C.yellow,
		UIStyle.heading())
	listHead.ZIndex = 11
	listHead.Text = "CHAMPION BADGES"
	-- Its close button (the list covers the medal that opened it).
	local listClose = Instance.new("TextButton")
	listClose.Name = "Close"
	listClose.AnchorPoint = Vector2.new(1, 0)
	listClose.Position = UDim2.new(1, -6, 0, 6)
	listClose.Size = UDim2.fromOffset(32, 32)
	listClose.BackgroundColor3 = C.ink
	listClose.BorderSizePixel = 0
	listClose.Text = "X"
	listClose.TextColor3 = C.yellow
	listClose.TextSize = SIZES.body
	listClose.FontFace = UIStyle.heading()
	listClose.ZIndex = 12
	listClose.Parent = badgeList
	UIStyle.stroke(listClose, C.yellow, 2)
	listClose.Activated:Connect(function()
		badgeList.Visible = false
	end)
	local listRows = Instance.new("ScrollingFrame")
	listRows.Name = "Rows"
	listRows.Position = UDim2.fromOffset(12, 42)
	listRows.Size = UDim2.new(1, -24, 1, -54)
	listRows.BackgroundTransparency = 1
	listRows.BorderSizePixel = 0
	listRows.ScrollBarThickness = 4
	listRows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listRows.CanvasSize = UDim2.new()
	listRows.ZIndex = 11
	listRows.Parent = badgeList
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.Padding = UDim.new(0, 4)
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Parent = listRows
	medalButton.Activated:Connect(function()
		badgeList.Visible = not badgeList.Visible
	end)
	local shownMedal: Frame? = nil
	local function drawBadges(badges: { StatsRemotes.ChampionBadgeView })
		if shownMedal then
			shownMedal:Destroy()
			shownMedal = nil
		end
		for _, row in ipairs(listRows:GetChildren()) do
			if row:IsA("TextLabel") then
				row:Destroy()
			end
		end
		local newest = badges[1]
		medalButton.Visible = newest ~= nil
		medalCount.Visible = #badges > 1
		medalCountText.Text = "x" .. tostring(#badges)
		if newest == nil then
			badgeList.Visible = false
			return
		end
		local medal = ChampionBadge.medal(medalButton, UDim2.fromScale(0.5, 0.5), MEDAL_SIZE, newest.number, newest.seasonLabel)
		for _, piece in ipairs(medal:GetDescendants()) do
			if piece:IsA("GuiObject") then
				piece.ZIndex += 5
			end
		end
		shownMedal = medal
		for index, badge in ipairs(badges) do
			local row = UIStyle.text(listRows, "Row", UDim2.new(), UDim2.new(1, -8, 0, 28), SIZES.body, C.white, UIStyle.heading())
			row.LayoutOrder = index
			row.ZIndex = 12
			row.RichText = true
			row.Text = if badge.number > 0
				then string.format('%s  <font color="#FACE24">%s</font>', badge.seasonLabel, ChampionBadge.numberText(badge.number))
				else string.format('%s  <font color="#9AA0C0">NUMBER COMING</font>', badge.seasonLabel)
		end
	end

	-- The goal list (GAME_DESIGN §38.3), over the avatar like the badge list: MAINTAIN, then every class. The server
	-- decides; a goal that leaves a class holding a Nationals/Worlds spot comes back asking to confirm.
	local refreshStats: () -> () = function() end
	local shownWeight, shownTarget = 0, 0
	local goalList = UIStyle.frame(body, "GoalList", UDim2.fromOffset(16, 16), UDim2.fromOffset(266, 470), C.navyDeep)
	goalList.ZIndex = 20
	goalList.Visible = false
	UIStyle.stroke(goalList, C.yellow, 2)
	local goalHead = UIStyle.text(goalList, "Head", UDim2.fromOffset(12, 8), UDim2.new(1, -56, 0, 30), SIZES.body, C.yellow,
		UIStyle.heading())
	goalHead.ZIndex = 21
	goalHead.Text = "WEIGHT GOAL"
	local goalClose = UIStyle.button(goalList, "Close", "X", UDim2.new(1, -40, 0, 6), UDim2.fromOffset(32, 32), "outline",
		function()
			goalList.Visible = false
		end)
	goalClose.ZIndex = 22
	local goalNote = UIStyle.text(goalList, "Note", UDim2.fromOffset(12, 362), UDim2.new(1, -24, 0, 62), SIZES.small, C.muted)
	goalNote.ZIndex = 21
	goalNote.TextWrapped = true
	local GOAL_HINT = string.format("Moves about %d kg per full day of Competition Number training at a rack. "
		.. "Your body's look updates when you respawn.", BodyweightConfig.KgPerFullTrainingDay)
	local pendingGoal: string? = nil
	local confirmButton: TextButton
	local sending = false
	local function sendGoal(goal: string, confirmed: boolean)
		if sending then
			return
		end
		sending = true
		local ok, reply = pcall(function()
			return remotes.setWeightGoal:InvokeServer(goal, confirmed)
		end)
		sending = false
		local answer = if ok and typeof(reply) == "table" then reply :: StatsRemotes.WeightGoalReply else nil
		if answer == nil then
			goalNote.Text = "Couldn't reach the server. Try again."
			goalNote.TextColor3 = C.red
			return
		end
		if answer.outcome == "NeedsConfirm" then
			pendingGoal = goal
			goalNote.Text = answer.message
			goalNote.TextColor3 = C.yellow
			confirmButton.Visible = true
			return
		end
		pendingGoal = nil
		confirmButton.Visible = false
		goalNote.Text = answer.message
		goalNote.TextColor3 = if answer.outcome == "Set" then C.white else C.red
		if answer.outcome == "Set" then
			refreshStats()
		end
	end
	confirmButton = UIStyle.button(goalList, "Confirm", "CHANGE CLASS ANYWAY", UDim2.fromOffset(12, 426),
		UDim2.new(1, -24, 0, 34), "danger", function()
			if pendingGoal then
				sendGoal(pendingGoal, true)
			end
		end)
	confirmButton.ZIndex = 22
	confirmButton.Visible = false
	local goalRows: { [string]: TextButton } = {}
	local choices = { BodyweightConfig.Maintain }
	for _, label in ipairs(BodyweightConfig.classLabels()) do
		table.insert(choices, label)
	end
	for index, goal in ipairs(choices) do
		local text = if goal == BodyweightConfig.Maintain then "MAINTAIN" else string.upper(goal) .. " CLASS"
		local row = UIStyle.button(goalList, "Goal_" .. goal, text, UDim2.fromOffset(12, 44 + (index - 1) * 35),
			UDim2.new(1, -24, 0, 31), "outline", function()
				pendingGoal = nil
				confirmButton.Visible = false
				sendGoal(goal, false)
			end)
		row.ZIndex = 22
		goalRows[goal] = row
	end
	-- Which row is the goal now: MAINTAIN when the target is the weight they have, else the class of the target.
	local function goalNow(): string
		if math.abs(shownTarget - shownWeight) < 0.05 then
			return BodyweightConfig.Maintain
		end
		return WeightClass.resolve(shownTarget).label
	end
	local function markGoals()
		local current = goalNow()
		local here = WeightClass.resolve(math.max(shownWeight, 1)).label
		for goal, row in pairs(goalRows) do
			local picked = goal == current
			row.BackgroundColor3 = if picked then C.yellow else C.navyDeep
			row.TextColor3 = if picked then C.ink else (if goal == here then C.yellow else C.white)
		end
	end
	openGoals = function()
		badgeList.Visible = false
		pendingGoal = nil
		confirmButton.Visible = false
		goalNote.Text = GOAL_HINT
		goalNote.TextColor3 = C.muted
		markGoals()
		goalList.Visible = not goalList.Visible
	end
	-- The button's words: what the body is doing now.
	local function goalText(): string
		if math.abs(shownTarget - shownWeight) < 0.05 then
			return "GOAL: MAINTAIN"
		end
		return string.format("GOAL: %s TO %.1f KG", if shownTarget > shownWeight then "BULK" else "CUT", shownTarget)
	end

	-- Middle: Competition Number and Scale.
	local middleX = 290
	UIStyle.sectionHead(body, "CNHead", "COMPETITION NUMBER", UDim2.fromOffset(middleX, 40), 236, 300, "bar")
	local cnRows: { [string]: TextLabel } = {}
	local scaleRows: { [string]: TextLabel } = {}
	for index, lift in ipairs(ProgressionConfig.Lifts) do
		local y = 74 + (index - 1) * 40
		UIStyle.frame(body, lift .. "_Mark", UDim2.fromOffset(middleX, y + 8), UDim2.fromOffset(6, 22),
			UIStyle.LiftColours[lift] or C.yellow)
		UIStyle.text(body, lift .. "_Name", UDim2.fromOffset(middleX + 16, y), UDim2.fromOffset(140, 36), SIZES.body, C.white,
			UIStyle.heading()).Text = string.upper(lift)
		cnRows[lift] = UIStyle.text(body, lift .. "_CN", UDim2.fromOffset(middleX + 150, y), UDim2.fromOffset(140, 36),
			SIZES.heading, C.white, UIStyle.heading(), Enum.TextXAlignment.Right)
	end
	UIStyle.frame(body, "TotalRule", UDim2.fromOffset(middleX, 198), UDim2.fromOffset(290, 2), C.white)
	UIStyle.text(body, "TotalName", UDim2.fromOffset(middleX, 206), UDim2.fromOffset(140, 36), SIZES.body, C.yellow,
		UIStyle.heading()).Text = "TOTAL"
	local totalText = UIStyle.text(body, "Total", UDim2.fromOffset(middleX + 150, 206), UDim2.fromOffset(140, 36),
		SIZES.heading, C.yellow, UIStyle.heading(), Enum.TextXAlignment.Right)
	UIStyle.sectionHead(body, "ScaleHead", "PROVEN IN A MEET", UDim2.fromOffset(middleX, 266), 210, 300, "dots")
	for index, lift in ipairs(ProgressionConfig.Lifts) do
		local y = 298 + (index - 1) * 36
		UIStyle.text(body, lift .. "_ScaleName", UDim2.fromOffset(middleX + 16, y), UDim2.fromOffset(140, 32), SIZES.body,
			C.muted, UIStyle.heading()).Text = string.upper(lift)
		scaleRows[lift] = UIStyle.text(body, lift .. "_Scale", UDim2.fromOffset(middleX + 150, y), UDim2.fromOffset(140, 32),
			SIZES.body, C.white, UIStyle.heading(), Enum.TextXAlignment.Right)
	end
	-- The best Total from one finished meet in this class (personal, never a record).
	local bestY = 298 + #ProgressionConfig.Lifts * 36
	UIStyle.text(body, "BestTotalName", UDim2.fromOffset(middleX + 16, bestY), UDim2.fromOffset(140, 32), SIZES.body,
		C.yellow, UIStyle.heading()).Text = "BEST TOTAL"
	local bestTotalText = UIStyle.text(body, "BestTotal", UDim2.fromOffset(middleX + 150, bestY), UDim2.fromOffset(140, 32),
		SIZES.body, C.yellow, UIStyle.heading(), Enum.TextXAlignment.Right)
	local hint = UIStyle.text(body, "Hint", UDim2.fromOffset(middleX, bestY + 38), UDim2.fromOffset(300, 50), SIZES.small,
		C.muted)
	hint.Text = "Competition Number is what training built. A lift is proven when you make it in a meet in this class."

	-- Right: the technique radar.
	UIStyle.sectionHead(body, "TechHead", "TECHNIQUE", UDim2.fromOffset(640, 40), 118, 270, "corner")
	local radar = Instance.new("Frame")
	radar.Name = "Radar"
	radar.BackgroundTransparency = 1
	radar.Position = UDim2.fromOffset(620, 70)
	radar.Size = UDim2.fromOffset(300, 300)
	radar.Parent = body
	local radarValues = Instance.new("Frame")
	radarValues.Name = "Values"
	radarValues.BackgroundTransparency = 1
	radarValues.Size = UDim2.fromScale(1, 1)
	radarValues.Parent = radar
	local radarLabels: { TextLabel } = {}
	local loading = UIStyle.text(body, "Loading", UDim2.fromOffset(620, 440), UDim2.fromOffset(300, 30), SIZES.body, C.muted,
		nil, Enum.TextXAlignment.Center)

	-- Under the radar: this season's ladder toward State in the current class (GAME_DESIGN §35.8, §36.3).
	local ladderY = 384
	UIStyle.text(body, "LadderName", UDim2.fromOffset(640, ladderY), UDim2.fromOffset(170, 28), SIZES.body, C.white,
		UIStyle.heading()).Text = "STATE LADDER"
	local ladderText = UIStyle.text(body, "Ladder", UDim2.fromOffset(740, ladderY), UDim2.fromOffset(170, 28),
		SIZES.heading, C.yellow, UIStyle.heading(), Enum.TextXAlignment.Right)
	local ladderBar = UIStyle.frame(body, "LadderBar", UDim2.fromOffset(640, ladderY + 34), UDim2.fromOffset(270, 12),
		C.navyDeep)
	UIStyle.stroke(ladderBar, C.white, 1)
	local ladderFill = UIStyle.frame(ladderBar, "Fill", UDim2.fromOffset(0, 0), UDim2.fromScale(0, 1), C.yellow)
	local ladderHint = UIStyle.text(body, "LadderHint", UDim2.fromOffset(640, ladderY + 52), UDim2.fromOffset(270, 20),
		SIZES.small, C.muted)
	-- Under it: the top-3 State placings toward Nationals in this class (GAME_DESIGN §36.4 "The Nationals spot").
	local nationalsY = ladderY + 72
	UIStyle.text(body, "NationalsName", UDim2.fromOffset(640, nationalsY), UDim2.fromOffset(170, 26), SIZES.body, C.white,
		UIStyle.heading()).Text = "NATIONALS"
	local nationalsText = UIStyle.text(body, "Nationals", UDim2.fromOffset(740, nationalsY), UDim2.fromOffset(170, 26),
		SIZES.heading, C.yellow, UIStyle.heading(), Enum.TextXAlignment.Right)
	local nationalsBar = UIStyle.frame(body, "NationalsBar", UDim2.fromOffset(640, nationalsY + 28), UDim2.fromOffset(270, 10),
		C.navyDeep)
	UIStyle.stroke(nationalsBar, C.white, 1)
	local nationalsFill = UIStyle.frame(nationalsBar, "Fill", UDim2.fromOffset(0, 0), UDim2.fromScale(0, 1), C.yellow)
	local nationalsHint = UIStyle.text(body, "NationalsHint", UDim2.fromOffset(640, nationalsY + 40), UDim2.fromOffset(270, 18),
		SIZES.small, C.muted)

	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
		badgeList.Visible = false
	end)

	-- The radar's fixed grid: pentagon rings at 25/50/75/100 and the spokes.
	local centre = Vector2.new(150, 160)
	local function drawGrid(count: number)
		for _, child in ipairs(radar:GetChildren()) do
			if child ~= radarValues then
				child:Destroy()
			end
		end
		for ring = 1, 4 do
			local radius = RADAR_RADIUS * ring / 4
			for index = 1, count do
				line(radar, "Ring", corner(centre, radius, index, count), corner(centre, radius, index % count + 1, count),
					if ring == 4 then 2 else 1, C.white, if ring == 4 then 0 else 0.7)
			end
		end
		for index = 1, count do
			line(radar, "Spoke", centre, corner(centre, RADAR_RADIUS, index, count), 1, C.white, 0.7)
		end
	end

	local function draw(snapshot: StatsRemotes.StatsSnapshot)
		classText.Text = string.upper(snapshot.classLabel) .. " CLASS"
		weightText.Text = string.format("Bodyweight %.1f kg", snapshot.bodyweightKg)
		shownWeight, shownTarget = snapshot.bodyweightKg, snapshot.targetKg
		goalButton.Text = goalText()
		if goalList.Visible then
			markGoals()
		end
		coinsText.Text = string.format("%s %s", CoinConfig.format(snapshot.coins or 0), CoinConfig.Name)
		local titles = snapshot.titles or {}
		titlesText.Text = if #titles > 0 then string.upper(table.concat(titles, "  ·  ")) else ""
		drawBadges(snapshot.championBadges or {})
		local ladder = snapshot.ladder
		if ladder then
			local daysLeft = math.max(1, math.ceil((ladder.seasonEndsAt - os.time()) / 86400))
			ladderText.Text = if ladder.qualified then "QUALIFIED" else string.format("%d / %d", ladder.points, ladder.target)
			ladderFill.Size = UDim2.fromScale(if ladder.qualified then 1 else math.clamp(ladder.points / ladder.target, 0, 1), 1)
			ladderHint.Text = string.format("%s class · season ends in %d day%s", snapshot.classLabel, daysLeft,
				if daysLeft == 1 then "" else "s")
		end
		local nationals = snapshot.nationals
		if nationals then
			nationalsText.Text = if nationals.qualified then "QUALIFIED" else string.format("%d / %d", nationals.placings,
				nationals.target)
			nationalsFill.Size = UDim2.fromScale(if nationals.qualified then 1
				else math.clamp(nationals.placings / math.max(nationals.target, 1), 0, 1), 1)
			nationalsHint.Text = if nationals.competed then "Competed · resets when the month ends"
				elseif nationals.qualified then "Kept until you compete at Nationals"
				else "Top-3 State placings · never reset"
		end
		local total = 0
		for _, lift in ipairs(ProgressionConfig.Lifts) do
			local cn = snapshot.competitionNumber[lift] or 0
			total += cn
			cnRows[lift].Text = kgText(cn)
			local scale = snapshot.competitionScale[lift] or 0
			scaleRows[lift].Text = if scale > 0 then kgText(scale) else "UNPROVEN"
			scaleRows[lift].TextColor3 = if scale > 0 then C.white else C.muted
		end
		totalText.Text = kgText(total)
		local bestTotal = snapshot.bestTotalKg or 0
		bestTotalText.Text = if bestTotal > 0 then kgText(bestTotal) else "—"
		bestTotalText.TextColor3 = if bestTotal > 0 then C.yellow else C.muted

		local stats = snapshot.technique
		local count = #stats
		drawGrid(math.max(count, 3))
		for _, child in ipairs(radarValues:GetChildren()) do
			child:Destroy()
		end
		for _, label in ipairs(radarLabels) do
			label:Destroy()
		end
		table.clear(radarLabels)
		if count < 3 then
			loading.Text = "No technique stats yet."
			return
		end
		loading.Text = ""
		local points: { Vector2 } = {}
		for index, view in ipairs(stats) do
			points[index] = corner(centre, RADAR_RADIUS * math.clamp(view.effective / 100, 0, 1), index, count)
		end
		for index, point in ipairs(points) do
			line(radarValues, "Edge", point, points[index % count + 1], 3, C.yellow)
		end
		for index, point in ipairs(points) do
			local view = stats[index]
			dot(radarValues, "Dot", point, 10, UIStyle.LiftColours[view.lift] or C.yellow)
			-- The stat's name and value just outside its corner.
			local labelAt = corner(centre, RADAR_RADIUS + 38, index, count)
			local label = UIStyle.text(radar, "Label", UDim2.fromOffset(labelAt.X, labelAt.Y), UDim2.fromOffset(150, 60),
				SIZES.small, C.white, UIStyle.heading(), Enum.TextXAlignment.Center)
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			-- Name in white, value in yellow under it (rich text keeps it one label).
			label.RichText = true
			label.Text = string.format('%s\n<font color="#FACE24">%.1f</font>', string.upper(view.name), view.effective)
			table.insert(radarLabels, label)
		end
	end

	local asking = false
	local function open()
		holder.Visible = true
		if avatar.Image == "" then
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size420x420)
				end)
				if ok then
					avatar.Image = image
				end
			end)
		end
		if asking then
			return
		end
		asking = true
		loading.Text = "Loading…"
		local ok, snapshot = pcall(function()
			return remotes.getMyStats:InvokeServer()
		end)
		asking = false
		if ok and snapshot then
			draw(snapshot :: StatsRemotes.StatsSnapshot)
		else
			loading.Text = "Stats are still loading. Try again in a moment."
		end
	end
	refreshStats = function()
		task.spawn(open)
	end
	local function toggle()
		badgeList.Visible = false
		goalList.Visible = false
		if holder.Visible then
			holder.Visible = false
		else
			task.spawn(open)
		end
	end

	tab.Activated:Connect(toggle)
	-- Training moved the weight into a new class or onto the goal (GAME_DESIGN §38.3): a line at the top of the screen,
	-- and the panel catches up if it is open.
	remotes.weightNews.OnClientEvent:Connect(function(text: any)
		if typeof(text) == "string" then
			GymRecordAnnouncer.note(text)
			if holder.Visible then
				refreshStats()
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Not while typing in a box (chat, the meet's weight box, the deadlift typing).
		if not MenuKeys.allowed(gameProcessed) then
			return
		end
		if input.KeyCode == OPEN_KEY then
			toggle()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return StatsScreen
