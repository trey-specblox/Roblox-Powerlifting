--!strict
--[[
	ShopMenu
	Client / UI

	The Shop's menu (GAME_DESIGN.md 30.6, the money system's step 4). Opens
	when the server says the player held E at the Shop's counter
	(ShopRemotes.OPEN). Built from UIStyle:

		SHOP (tag)                                   [coin] 1,250 COINS
		[ BELTS ] [ KNEE SLEEVES ] [ WRIST WRAPS ] [ SINGLETS ]
		cards: a 3D preview of the gear model in the item's colours, its
		name, its price, and BUY (press again to CONFIRM) or OWNED
		a status line                                            BACK

	It only asks (GetShop, BuyItem) and shows what the server answers; the
	server checks every purchase and decides the price. Walking away from the
	counter closes it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local CoinConfig = require(ConfigFolder:WaitForChild("CoinConfig"))
local ShopRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("ShopRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local GearPreview = require(script.Parent:WaitForChild("GearPreview"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local ShopMenu = {}

local PANEL_WIDTH, PANEL_HEIGHT = 940, 560
local COLUMNS = 4
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 206, 262, 12
local PREVIEW_HEIGHT = 128
local CONFIRM_SECONDS = 3
-- The menu closes when the player walks this far from where they opened it (studs).
local CLOSE_DISTANCE = 20

local started = false

type Card = {
	item: ShopConfig.Item,
	frame: Frame,
	button: TextButton,
	confirmUntil: number,
}

function ShopMenu.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ShopRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 8
	UIStyle.fitToScreen(gui)

	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	UIStyle.titleTag(holder, "Tag", "SHOP", UDim2.fromOffset(-18, -30), UDim2.fromOffset(220, 52), nil, "star")

	-- The player's coins, top right.
	UIStyle.coin(body, UDim2.new(1, -236, 0, 22), 26)
	local coinsText = UIStyle.text(body, "Coins", UDim2.new(1, -202, 0, 20), UDim2.fromOffset(186, 30), SIZES.heading, C.yellow,
		UIStyle.heading())
	coinsText.TextWrapped = false

	-- The category tabs.
	local tabs: { [string]: TextButton } = {}
	local selected = ShopConfig.Categories[1]
	local status = UIStyle.text(body, "Status", UDim2.new(0, 24, 1, -46), UDim2.new(1, -230, 0, 36), SIZES.body, C.muted)
	status.TextYAlignment = Enum.TextYAlignment.Center

	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.Position = UDim2.fromOffset(20, 116)
	list.Size = UDim2.new(1, -30, 1, -170)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.yellow
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = body

	local owned: { [string]: boolean } = {}
	local coins = 0
	local cards: { Card } = {}
	local built = false

	local function refreshCard(card: Card)
		local button = card.button
		if owned[card.item.id] then
			button.Text = "OWNED"
			button.BackgroundColor3, button.TextColor3 = C.empty, C.muted
			button.AutoButtonColor = false
		elseif os.clock() < card.confirmUntil then
			button.Text = "CONFIRM " .. CoinConfig.format(card.item.price) .. "?"
			button.BackgroundColor3, button.TextColor3 = C.white, C.ink
			button.AutoButtonColor = true
		else
			button.Text = "BUY"
			button.BackgroundColor3, button.TextColor3 = if coins >= card.item.price then C.yellow else C.empty,
				if coins >= card.item.price then C.ink else C.muted
			button.AutoButtonColor = true
		end
	end

	local function layout()
		local index = 0
		for _, card in ipairs(cards) do
			local show = card.item.category == selected
			card.frame.Visible = show
			if show then
				local column, row = index % COLUMNS, index // COLUMNS
				card.frame.Position = UDim2.fromOffset(4 + column * (CARD_WIDTH + CARD_GAP), 4 + row * (CARD_HEIGHT + CARD_GAP))
				index += 1
			end
		end
		local rows = math.max(1, math.ceil(index / COLUMNS))
		list.CanvasSize = UDim2.fromOffset(0, 8 + rows * (CARD_HEIGHT + CARD_GAP))
		list.CanvasPosition = Vector2.zero
		for name, tab in pairs(tabs) do
			local on = name == selected
			tab.BackgroundColor3, tab.TextColor3 = if on then C.yellow else C.navyDeep, if on then C.ink else C.white
		end
	end

	local function apply(view: ShopRemotes.ShopView?)
		if view == nil then
			return
		end
		table.clear(owned)
		for _, itemId in ipairs(view.owned) do
			owned[itemId] = true
		end
		coins = view.coins
		coinsText.Text = string.format("%s %s", CoinConfig.format(coins), CoinConfig.Name)
		for _, card in ipairs(cards) do
			refreshCard(card)
		end
	end

	local buying = false
	local function press(card: Card)
		if buying or owned[card.item.id] then
			return
		end
		if os.clock() >= card.confirmUntil then
			-- The first press asks to confirm; only one card waits at a time.
			for _, other in ipairs(cards) do
				other.confirmUntil = 0
				refreshCard(other)
			end
			card.confirmUntil = os.clock() + CONFIRM_SECONDS
			refreshCard(card)
			task.delay(CONFIRM_SECONDS + 0.05, function()
				refreshCard(card)
			end)
			return
		end
		card.confirmUntil = 0
		buying = true
		status.TextColor3, status.Text = C.muted, "Buying..."
		local ok, done, message, view = pcall(function()
			return remotes.buy:InvokeServer(card.item.id)
		end)
		buying = false
		if ok then
			status.TextColor3 = if done then C.yellow else C.red
			status.Text = if typeof(message) == "string" then message else ""
			apply(view)
		else
			status.TextColor3, status.Text = C.red, "The shop didn't answer. Try again."
		end
		refreshCard(card)
	end

	local function build()
		if built then
			return
		end
		built = true
		for index, category in ipairs(ShopConfig.Categories) do
			local tab = UIStyle.button(body, "Tab_" .. category, category, UDim2.fromOffset(24 + (index - 1) * 190, 66),
				UDim2.fromOffset(178, 38), "outline", function()
					selected = category
					layout()
				end)
			tabs[category] = tab
		end
		for _, item in ipairs(ShopConfig.Items) do
			local frame = UIStyle.frame(list, "Item_" .. item.id, UDim2.fromOffset(0, 0), UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
				C.navyDeep)
			UIStyle.stroke(frame, C.white, 1, 0.4)
			GearPreview.build(frame, item, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 0, PREVIEW_HEIGHT))
			local name = UIStyle.text(frame, "Name", UDim2.fromOffset(10, PREVIEW_HEIGHT + 10), UDim2.new(1, -20, 0, 44),
				SIZES.body, C.white, UIStyle.heading())
			name.Text = string.upper(item.name)
			UIStyle.coin(frame, UDim2.fromOffset(10, PREVIEW_HEIGHT + 58), 18)
			local price = UIStyle.text(frame, "Price", UDim2.fromOffset(34, PREVIEW_HEIGHT + 55), UDim2.new(1, -44, 0, 24),
				SIZES.body, C.yellow, UIStyle.heading())
			price.Text = CoinConfig.format(item.price)
			local button = Instance.new("TextButton")
			button.Name = "Buy"
			button.Position = UDim2.new(0, 10, 1, -44)
			button.Size = UDim2.new(1, -20, 0, 34)
			button.BorderSizePixel = 0
			button.FontFace = UIStyle.heading()
			button.TextSize = SIZES.body
			button.Parent = frame
			local card: Card = { item = item, frame = frame, button = button, confirmUntil = 0 }
			button.Activated:Connect(function()
				task.spawn(press, card)
			end)
			table.insert(cards, card)
		end
		layout()
	end

	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
	end)

	local openedAt: Vector3? = nil
	local function open()
		build()
		holder.Visible = true
		status.TextColor3, status.Text = C.muted, "Gear is for looks only. Press BUY, then CONFIRM."
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		openedAt = if rootPart and rootPart:IsA("BasePart") then rootPart.Position else nil
		local ok, view = pcall(function()
			return remotes.get:InvokeServer()
		end)
		if ok then
			apply(view)
		end
	end
	remotes.open.OnClientEvent:Connect(function()
		task.spawn(open)
	end)

	-- Walking away from the counter closes the menu.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if holder.Visible and openedAt then
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart == nil or not rootPart:IsA("BasePart")
					or (rootPart.Position - (openedAt :: Vector3)).Magnitude > CLOSE_DISTANCE then
					holder.Visible = false
				end
			end
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return ShopMenu
