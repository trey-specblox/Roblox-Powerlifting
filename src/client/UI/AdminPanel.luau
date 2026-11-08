--!strict
--[[
	AdminPanel
	Client / UI

	The admin panel on an admin's screen (user 2026-11-06). The server says on joining whether
	this player is an admin; for anyone else nothing is built. It only asks: the server checks
	the account on every press (AdminService), so this code being on every player's device
	gives nobody anything.

		an ADMIN tab on the left edge, above MEETS, usable by touch
		MY TOOLS page (the admin's own account):
			GIVE COINS      +1,000  +10,000  +100,000
			CRATES GIVE     NORMAL ODDS, or one rarity every time
			GIVE A SUIT     each rare suit (no server-wide news)
			NEXT MEET DROPS the normal chance, or a chosen suit: a real drop at your next meet with a total
		PLAYER STATS page (user 2026-11-08: "fully control anyones stats"), any player in the server:
			< NAME >        pick the player
			a box per stat  (AdminConfig.StatFields) showing their value now: type a new one and press
			                Enter or tap away to set it; the server clamps it
			QUALIFY FOR STATE, REFILL DAILY LIMITS, and coins for them

	PERFORMANCE: nothing for other players; a few buttons for the admin.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local AdminConfig = require(ConfigFolder:WaitForChild("AdminConfig"))
local CoinConfig = require(ConfigFolder:WaitForChild("CoinConfig"))
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local AdminRemotes = require(Shared:WaitForChild("Admin"):WaitForChild("AdminRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local AdminPanel = {}

local PANEL_WIDTH, PANEL_HEIGHT = 640, 650
local MARGIN = 24
local GAP = 10
local BUTTON_HEIGHT = 50
-- Where each page's content starts, under the page buttons.
local PAGE_TOP = 104
-- The PLAYER STATS grid: a label over a box, three to a row.
local STATS_ROW_HEIGHT = 66
local LABEL_HEIGHT = 20
local BOX_HEIGHT = 38

local started = false

-- "53", "122.5".
local function numberText(value: number): string
	if math.floor(value) == value then
		return string.format("%d", value)
	end
	return string.format("%.1f", value)
end

function AdminPanel.start()
	if started then
		return
	end
	started = true
	local localPlayer = Players.LocalPlayer
	local remotes = AdminRemotes.waitForClient(ReplicatedStorage)
	local gotPanel, firstView = pcall(function()
		return remotes.get:InvokeServer()
	end)
	if not gotPanel or firstView == nil then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	UIStyle.fitToScreen(gui)

	local tab = Instance.new("TextButton")
	tab.Name = "Tab"
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Position = UDim2.new(0, 0, 0.5, AdminConfig.TabOffsetY)
	tab.Size = UDim2.fromOffset(150, 44)
	tab.BackgroundColor3 = C.ink
	tab.BorderSizePixel = 0
	tab.Text = ""
	tab.Parent = gui
	UIStyle.stroke(tab, C.red, 2)
	local tabText = UIStyle.text(tab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), SIZES.body, C.white, UIStyle.heading())
	tabText.Text = "ADMIN"

	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	UIStyle.titleTag(holder, "Tag", "ADMIN", UDim2.fromOffset(-18, -30), UDim2.fromOffset(220, 52), nil, "star")

	UIStyle.coin(body, UDim2.new(1, -236, 0, 22), 26)
	local coinsText = UIStyle.text(body, "Coins", UDim2.new(1, -202, 0, 20), UDim2.fromOffset(186, 30), SIZES.heading, C.yellow, UIStyle.heading())
	coinsText.TextWrapped = false

	local status = UIStyle.text(body, "Status", UDim2.new(0, MARGIN, 1, -46), UDim2.new(1, -2 * MARGIN, 0, 36), SIZES.body, C.muted)
	status.TextYAlignment = Enum.TextYAlignment.Center

	-- Evenly spaced pieces along a row: `count` across, the `index`th, `height` tall (a button's by default).
	local function cell(index: number, count: number, y: number, height: number?): (UDim2, UDim2)
		local share = 1 / count
		local inner = 2 * MARGIN + GAP * (count - 1)
		return UDim2.new((index - 1) * share, MARGIN + (index - 1) * (GAP - inner * share), 0, y),
			UDim2.new(share, -inner * share, 0, height or BUTTON_HEIGHT)
	end

	local function page(name: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = body
		return frame
	end
	local toolsPage = page("ToolsPage")
	local statsPage = page("StatsPage")

	local rarityButtons: { [string]: TextButton } = {}
	local dropButtons: { [string]: TextButton } = {}
	local pageButtons: { [string]: TextButton } = {}
	local NORMAL = "Normal"

	local function highlight(buttons: { [string]: TextButton }, chosen: string)
		for id, button in pairs(buttons) do
			local isChosen = id == chosen
			button.BackgroundColor3 = if isChosen then C.yellow else C.navyDeep
			button.TextColor3 = if isChosen then C.ink else C.white
		end
	end

	-- The PLAYER STATS page's state: who is chosen, everyone here, and each box with the value it shows.
	local targetUserId = localPlayer.UserId
	local playerList: { { userId: number, name: string } } = {}
	local boxes: { [string]: TextBox } = {}
	local boxLabels: { [string]: TextLabel } = {}
	local shownValues: { [string]: number } = {}
	local pickerName: TextLabel
	local summary: TextLabel

	local function applyTarget(view: AdminRemotes.AdminView)
		playerList = view.players or {}
		local target = view.target
		if target == nil then
			pickerName.Text = "PLAYER LEFT, OR THEIR SAVE HASN'T LOADED"
			summary.Text = ""
			table.clear(shownValues)
			return
		end
		targetUserId = target.userId
		pickerName.Text = string.upper(target.name) .. (if target.userId == localPlayer.UserId then "  (YOU)" else "")
		summary.Text = string.format("%s CLASS  ·  LADDER %s/%d  ·  %s  ·  %s COINS", target.classKey,
			numberText(target.values.Ladder or 0), target.ladderTarget, if target.qualified then "STATE: QUALIFIED" else "STATE: NOT YET",
			CoinConfig.format(target.coins))
		summary.TextColor3 = if target.qualified then C.yellow else C.white
		for _, field in ipairs(AdminConfig.StatFields) do
			local value = target.values[field.id] or 0
			shownValues[field.id] = value
			local box = boxes[field.id]
			if box and not box:IsFocused() then
				box.Text = numberText(value)
			end
			local label = boxLabels[field.id]
			local curved = target.effective[field.id]
			if label then
				label.Text = if curved then string.format("%s  (%d)", field.label, math.floor(curved + 0.5)) else field.label
			end
		end
	end

	local function apply(view: AdminRemotes.AdminView?)
		if view == nil then
			return
		end
		coinsText.Text = string.format("%s %s", CoinConfig.format(view.coins), CoinConfig.Name)
		highlight(rarityButtons, view.crateRarity or NORMAL)
		highlight(dropButtons, view.forcedDrop or NORMAL)
		applyTarget(view)
	end

	local busy = false
	local function ask(action: string, value: any)
		if busy then
			return
		end
		busy = true
		status.TextColor3, status.Text = C.muted, "..."
		local ok, done, message, view = pcall(function()
			return remotes.action:InvokeServer(action, value)
		end)
		busy = false
		if ok then
			status.TextColor3 = if done then C.yellow else C.red
			status.Text = if typeof(message) == "string" then message else ""
			apply(view)
		else
			status.TextColor3, status.Text = C.red, "The server didn't answer."
		end
	end

	-- Asks again for the chosen player's stats.
	local function refresh()
		local ok, view = pcall(function()
			return remotes.get:InvokeServer(targetUserId)
		end)
		if ok then
			apply(view)
		end
	end

	local function showPage(name: string)
		toolsPage.Visible = name == "Tools"
		statsPage.Visible = name == "Stats"
		highlight(pageButtons, name)
		status.Text = ""
	end
	do
		local position, size = cell(1, 2, 52, 42)
		pageButtons.Tools = UIStyle.button(body, "ToolsPageButton", "MY TOOLS", position, size, "outline", function()
			showPage("Tools")
		end)
		position, size = cell(2, 2, 52, 42)
		pageButtons.Stats = UIStyle.button(body, "StatsPageButton", "PLAYER STATS", position, size, "outline", function()
			showPage("Stats")
			refresh()
		end)
	end

	-- ------------------------------------------------------------ MY TOOLS
	local note = UIStyle.text(toolsPage, "Note", UDim2.fromOffset(MARGIN, PAGE_TOP), UDim2.new(1, -2 * MARGIN, 0, 24), SIZES.small, C.muted)
	note.Text = "Only your account can use this. It changes your own real save."

	local coinsTitle = UIStyle.text(toolsPage, "CoinsTitle", UDim2.fromOffset(MARGIN, 138), UDim2.new(1, -2 * MARGIN, 0, 28), SIZES.body, C.white, UIStyle.heading())
	coinsTitle.Text = "GIVE COINS"
	for index, coinButton in ipairs(AdminConfig.CoinButtons) do
		local position, size = cell(index, #AdminConfig.CoinButtons, 168)
		UIStyle.button(toolsPage, coinButton.id, coinButton.label, position, size, "outline", function()
			ask("Coins", coinButton.id)
		end)
	end

	local cratesTitle = UIStyle.text(toolsPage, "CratesTitle", UDim2.fromOffset(MARGIN, 224), UDim2.new(1, -2 * MARGIN, 0, 28), SIZES.body, C.white, UIStyle.heading())
	cratesTitle.Text = "YOUR CRATES GIVE"
	local choices: { string } = { NORMAL }
	for _, rarity in ipairs(GearStatsConfig.Rarities) do
		table.insert(choices, rarity.id)
	end
	for index, id in ipairs(choices) do
		-- Three to a row.
		local column = (index - 1) % 3 + 1
		local row = math.floor((index - 1) / 3)
		local position, size = cell(column, 3, 254 + row * (BUTTON_HEIGHT + GAP))
		local text = if id == NORMAL then "NORMAL ODDS" else string.upper(id)
		rarityButtons[id] = UIStyle.button(toolsPage, "Rarity_" .. id, text, position, size, "outline", function()
			ask("CrateRarity", if id == NORMAL then nil else id)
		end)
	end

	local suitsTitle = UIStyle.text(toolsPage, "SuitsTitle", UDim2.fromOffset(MARGIN, 370), UDim2.new(1, -2 * MARGIN, 0, 28), SIZES.body, C.white, UIStyle.heading())
	suitsTitle.Text = "GIVE A SUIT"
	for index, suit in ipairs(GearStatsConfig.Suits) do
		local position, size = cell(index, #GearStatsConfig.Suits, 400)
		UIStyle.button(toolsPage, "Suit_" .. suit.id, suit.name, position, size, "outline", function()
			ask("GiveSuit", suit.id)
		end)
	end

	UIStyle.button(toolsPage, "ResetTests", "RESET SUIT TESTS", UDim2.new(1, -MARGIN - 230, 0, 368), UDim2.fromOffset(230, 28), "outline", function()
		ask("ResetSuitTests", nil)
	end)

	local dropsTitle = UIStyle.text(toolsPage, "DropsTitle", UDim2.fromOffset(MARGIN, 456), UDim2.new(1, -2 * MARGIN, 0, 28), SIZES.body, C.white, UIStyle.heading())
	dropsTitle.Text = "YOUR NEXT MEET DROPS"
	local drops: { { id: string, text: string } } = { { id = NORMAL, text = "NORMAL" } }
	for _, suit in ipairs(GearStatsConfig.Suits) do
		table.insert(drops, { id = suit.id, text = suit.name })
	end
	for index, drop in ipairs(drops) do
		local position, size = cell(index, #drops, 486)
		dropButtons[drop.id] = UIStyle.button(toolsPage, "Drop_" .. drop.id, drop.text, position, size, "outline", function()
			ask("ForceDrop", if drop.id == NORMAL then nil else drop.id)
		end)
	end

	-- ------------------------------------------------------------ PLAYER STATS
	-- The picker: < NAME >, through everyone in the server.
	local function step(by: number)
		if #playerList == 0 then
			return
		end
		local at = 1
		for index, entry in ipairs(playerList) do
			if entry.userId == targetUserId then
				at = index
			end
		end
		targetUserId = playerList[(at - 1 + by) % #playerList + 1].userId
		status.Text = ""
		refresh()
	end
	UIStyle.button(statsPage, "Previous", "<", UDim2.fromOffset(MARGIN, PAGE_TOP), UDim2.fromOffset(56, 44), "outline", function()
		step(-1)
	end)
	UIStyle.button(statsPage, "Next", ">", UDim2.new(1, -MARGIN - 56, 0, PAGE_TOP), UDim2.fromOffset(56, 44), "outline", function()
		step(1)
	end)
	pickerName = UIStyle.text(statsPage, "Name", UDim2.fromOffset(MARGIN + 66, PAGE_TOP + 6), UDim2.new(1, -2 * MARGIN - 132, 0, 32),
		SIZES.heading, C.white, UIStyle.heading(), Enum.TextXAlignment.Center)
	pickerName.TextWrapped = false
	pickerName.TextScaled = true
	summary = UIStyle.text(statsPage, "Summary", UDim2.fromOffset(MARGIN, PAGE_TOP + 52), UDim2.new(1, -2 * MARGIN, 0, 24), SIZES.small,
		C.white, UIStyle.font(Enum.FontWeight.Bold), Enum.TextXAlignment.Center)

	-- The grid: rows of three, each a label over a box, with the page's buttons in the gaps.
	local gridTop = PAGE_TOP + 88
	local slot = 0
	local function nextCell(): (UDim2, UDim2, number)
		slot += 1
		local column = (slot - 1) % 3 + 1
		local y = gridTop + math.floor((slot - 1) / 3) * STATS_ROW_HEIGHT
		local position, size = cell(column, 3, y, LABEL_HEIGHT + 4 + BOX_HEIGHT)
		return position, size, y
	end
	local function statBox(field: AdminConfig.StatField)
		local position, size = nextCell()
		local frame = Instance.new("Frame")
		frame.Name = "Stat_" .. field.id
		frame.BackgroundTransparency = 1
		frame.Position = position
		frame.Size = size
		frame.Parent = statsPage
		local label = UIStyle.text(frame, "Label", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, LABEL_HEIGHT), SIZES.small, C.muted,
			UIStyle.font(Enum.FontWeight.Bold))
		label.TextWrapped = false
		label.Text = field.label
		boxLabels[field.id] = label
		local box = Instance.new("TextBox")
		box.Name = "Box"
		box.Position = UDim2.fromOffset(0, LABEL_HEIGHT + 4)
		box.Size = UDim2.new(1, 0, 0, BOX_HEIGHT)
		box.BackgroundColor3 = C.navyDeep
		box.BorderSizePixel = 0
		box.TextColor3 = C.white
		box.FontFace = UIStyle.heading()
		box.TextSize = SIZES.body
		box.ClearTextOnFocus = false
		box.Text = ""
		box.Parent = frame
		UIStyle.stroke(box, C.white, 1, 0.3)
		boxes[field.id] = box
		-- Enter, or tapping away on a phone: send it if it changed.
		box.FocusLost:Connect(function()
			local typed = tonumber(box.Text)
			local was = shownValues[field.id]
			if typed == nil or was == nil or math.abs(typed - was) < 1e-9 then
				box.Text = if was then numberText(was) else ""
				return
			end
			ask("SetStat", { userId = targetUserId, id = field.id, value = typed })
		end)
	end
	local function pageButton(name: string, text: string, onClick: () -> ())
		local position, size = nextCell()
		UIStyle.button(statsPage, name, text, position + UDim2.fromOffset(0, LABEL_HEIGHT + 4), UDim2.new(size.X.Scale, size.X.Offset, 0, BOX_HEIGHT),
			"primary", onClick)
	end
	for index, field in ipairs(AdminConfig.StatFields) do
		statBox(field)
		-- After bodyweight and ladder points: the one-tap State qualification.
		if index == 2 then
			pageButton("Qualify", "QUALIFY FOR STATE", function()
				ask("QualifyState", { userId = targetUserId })
			end)
		end
	end
	pageButton("Refill", "REFILL DAILY", function()
		ask("RefillDaily", { userId = targetUserId })
	end)
	-- Their coins, on a row of their own.
	local coinsY = gridTop + math.ceil(slot / 3) * STATS_ROW_HEIGHT + 4
	for index, coinButton in ipairs(AdminConfig.CoinButtons) do
		local position, size = cell(index, #AdminConfig.CoinButtons, coinsY, 44)
		UIStyle.button(statsPage, "GiveTo_" .. coinButton.id, coinButton.label .. " COINS", position, size, "outline", function()
			ask("GiveCoinsTo", { userId = targetUserId, id = coinButton.id })
		end)
	end

	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
	end)

	showPage("Tools")
	apply(firstView)
	tab.Activated:Connect(function()
		if holder.Visible then
			holder.Visible = false
			return
		end
		holder.Visible = true
		status.Text = ""
		refresh()
	end)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return AdminPanel
