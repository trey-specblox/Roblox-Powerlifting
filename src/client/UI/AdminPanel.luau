--!strict
--[[
	AdminPanel
	Client / UI

	The admin panel on an admin's screen (user 2026-11-06). The server says on joining whether
	this player is an admin; for anyone else nothing is built. It only asks: the server checks
	the account on every press (AdminService), so this code being on every player's device
	gives nobody anything.

		an ADMIN tab on the left edge, above MEETS, usable by touch
		GIVE COINS      +1,000  +10,000  +100,000
		CRATES GIVE     NORMAL ODDS, or one rarity every time
		GIVE A SUIT     each rare suit (no server-wide news)
		NEXT MEET DROPS the normal chance, or a chosen suit: a real drop at your next meet with a total

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

local PANEL_WIDTH, PANEL_HEIGHT = 640, 550
local MARGIN = 24
local GAP = 10
local BUTTON_HEIGHT = 50

local started = false

function AdminPanel.start()
	if started then
		return
	end
	started = true
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

	local note = UIStyle.text(body, "Note", UDim2.fromOffset(MARGIN, 58), UDim2.new(1, -2 * MARGIN, 0, 24), SIZES.small, C.muted)
	note.Text = "Only your account can use this. It changes your real save."
	local status = UIStyle.text(body, "Status", UDim2.new(0, MARGIN, 1, -46), UDim2.new(1, -2 * MARGIN, 0, 36), SIZES.body, C.muted)
	status.TextYAlignment = Enum.TextYAlignment.Center

	-- Evenly spaced buttons along a row: `count` across, the `index`th.
	local function cell(index: number, count: number, y: number): (UDim2, UDim2)
		local share = 1 / count
		local inner = 2 * MARGIN + GAP * (count - 1)
		return UDim2.new((index - 1) * share, MARGIN + (index - 1) * (GAP - inner * share), 0, y),
			UDim2.new(share, -inner * share, 0, BUTTON_HEIGHT)
	end

	local rarityButtons: { [string]: TextButton } = {}
	local dropButtons: { [string]: TextButton } = {}
	local NORMAL = "Normal"

	local function highlight(buttons: { [string]: TextButton }, chosen: string)
		for id, button in pairs(buttons) do
			local isChosen = id == chosen
			button.BackgroundColor3 = if isChosen then C.yellow else C.navyDeep
			button.TextColor3 = if isChosen then C.ink else C.white
		end
	end

	local function apply(view: AdminRemotes.AdminView?)
		if view == nil then
			return
		end
		coinsText.Text = string.format("%s %s", CoinConfig.format(view.coins), CoinConfig.Name)
		highlight(rarityButtons, view.crateRarity or NORMAL)
		highlight(dropButtons, view.forcedDrop or NORMAL)
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

	local coinsTitle = UIStyle.text(body, "CoinsTitle", UDim2.fromOffset(MARGIN, 88), UDim2.new(1, -2 * MARGIN, 0, 28), SIZES.body, C.white, UIStyle.heading())
	coinsTitle.Text = "GIVE COINS"
	for index, coinButton in ipairs(AdminConfig.CoinButtons) do
		local position, size = cell(index, #AdminConfig.CoinButtons, 118)
		UIStyle.button(body, coinButton.id, coinButton.label, position, size, "outline", function()
			ask("Coins", coinButton.id)
		end)
	end

	local cratesTitle = UIStyle.text(body, "CratesTitle", UDim2.fromOffset(MARGIN, 174), UDim2.new(1, -2 * MARGIN, 0, 28), SIZES.body, C.white, UIStyle.heading())
	cratesTitle.Text = "YOUR CRATES GIVE"
	local choices: { string } = { NORMAL }
	for _, rarity in ipairs(GearStatsConfig.Rarities) do
		table.insert(choices, rarity.id)
	end
	for index, id in ipairs(choices) do
		-- Three to a row.
		local column = (index - 1) % 3 + 1
		local row = math.floor((index - 1) / 3)
		local position, size = cell(column, 3, 204 + row * (BUTTON_HEIGHT + GAP))
		local text = if id == NORMAL then "NORMAL ODDS" else string.upper(id)
		rarityButtons[id] = UIStyle.button(body, "Rarity_" .. id, text, position, size, "outline", function()
			ask("CrateRarity", if id == NORMAL then nil else id)
		end)
	end

	local suitsTitle = UIStyle.text(body, "SuitsTitle", UDim2.fromOffset(MARGIN, 320), UDim2.new(1, -2 * MARGIN, 0, 28), SIZES.body, C.white, UIStyle.heading())
	suitsTitle.Text = "GIVE A SUIT"
	for index, suit in ipairs(GearStatsConfig.Suits) do
		local position, size = cell(index, #GearStatsConfig.Suits, 350)
		UIStyle.button(body, "Suit_" .. suit.id, suit.name, position, size, "outline", function()
			ask("GiveSuit", suit.id)
		end)
	end

	UIStyle.button(body, "ResetTests", "RESET SUIT TESTS", UDim2.new(1, -MARGIN - 230, 0, 318), UDim2.fromOffset(230, 28), "outline", function()
		ask("ResetSuitTests", nil)
	end)

	local dropsTitle = UIStyle.text(body, "DropsTitle", UDim2.fromOffset(MARGIN, 406), UDim2.new(1, -2 * MARGIN, 0, 28), SIZES.body, C.white, UIStyle.heading())
	dropsTitle.Text = "YOUR NEXT MEET DROPS"
	local drops: { { id: string, text: string } } = { { id = NORMAL, text = "NORMAL" } }
	for _, suit in ipairs(GearStatsConfig.Suits) do
		table.insert(drops, { id = suit.id, text = suit.name })
	end
	for index, drop in ipairs(drops) do
		local position, size = cell(index, #drops, 436)
		dropButtons[drop.id] = UIStyle.button(body, "Drop_" .. drop.id, drop.text, position, size, "outline", function()
			ask("ForceDrop", if drop.id == NORMAL then nil else drop.id)
		end)
	end

	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
	end)

	apply(firstView)
	tab.Activated:Connect(function()
		if holder.Visible then
			holder.Visible = false
			return
		end
		holder.Visible = true
		status.Text = ""
		local ok, view = pcall(function()
			return remotes.get:InvokeServer()
		end)
		if ok then
			apply(view)
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return AdminPanel
