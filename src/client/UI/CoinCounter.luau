--!strict
--[[
	CoinCounter
	Client / UI

	The player's coins on screen (GAME_DESIGN.md 30.6, the money system's
	step 2), built from UIStyle:

		- a COINS badge on the left edge above the STATS tab: a coin and the
		  balance ("1,250"), counting up or down when it changes
		- a pop-up beside it for each change: "+150 COINS" and what it was
		  for, rising and fading; several in a row wait their turn

	Display only. The balance is the server's player attribute
	CoinConfig.BalanceAttribute; the pop-ups come from CoinRemotes.CHANGED.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoinConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoinConfig"))
local CoinRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("CoinRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local CoinCounter = {}

-- Above the STATS tab (StatsScreen: centred on the left edge, 44 px tall).
local BADGE_OFFSET_Y = -64
local BADGE_WIDTH, BADGE_HEIGHT = 150, 44
local COUNT_SECONDS = 0.6
local POP_RISE, POP_SECONDS, POP_GAP_SECONDS = 60, 2, 1
local GREEN = Color3.fromRGB(96, 220, 120)

local started = false

-- A round gold coin with an inner ring.
local function coin(parent: Instance, position: UDim2, size: number): Frame
	local disc = UIStyle.frame(parent, "Coin", position, UDim2.fromOffset(size, size), C.yellow)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = disc
	UIStyle.stroke(disc, Color3.fromRGB(176, 128, 10), 2)
	local inner = UIStyle.frame(disc, "Ring", UDim2.fromScale(0.22, 0.22), UDim2.fromScale(0.56, 0.56), C.yellow)
	inner.BackgroundTransparency = 1
	local innerRound = Instance.new("UICorner")
	innerRound.CornerRadius = UDim.new(0.5, 0)
	innerRound.Parent = inner
	UIStyle.stroke(inner, Color3.fromRGB(176, 128, 10), 2)
	return disc
end

function CoinCounter.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remote = CoinRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Coins"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	UIStyle.fitToScreen(gui)

	local badge = UIStyle.frame(gui, "Badge", UDim2.new(0, 0, 0.5, BADGE_OFFSET_Y), UDim2.fromOffset(BADGE_WIDTH, BADGE_HEIGHT), C.ink)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	UIStyle.stroke(badge, C.yellow, 2)
	coin(badge, UDim2.fromOffset(10, 9), 26)
	local amount = UIStyle.text(badge, "Amount", UDim2.fromOffset(44, 0), UDim2.new(1, -52, 1, 0), SIZES.body, C.white,
		UIStyle.heading())
	amount.TextWrapped = false
	amount.Text = "0"
	local name = UIStyle.text(badge, "Name", UDim2.new(0, 10, 1, 2), UDim2.fromOffset(120, 16), SIZES.small, C.muted)
	name.Text = CoinConfig.Name

	-- The pop-ups rise from beside the badge (their own holder, so they can move freely).
	local pops = Instance.new("Frame")
	pops.Name = "Pops"
	pops.BackgroundTransparency = 1
	pops.AnchorPoint = Vector2.new(0, 0.5)
	pops.Position = UDim2.new(0, BADGE_WIDTH + 12, 0.5, BADGE_OFFSET_Y)
	pops.Size = UDim2.fromOffset(280, BADGE_HEIGHT)
	pops.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The number counts to the new balance instead of jumping.
	local shown = Instance.new("NumberValue")
	shown.Value = 0
	shown.Changed:Connect(function(value)
		amount.Text = CoinConfig.format(math.floor(value + 0.5))
	end)
	local function showBalance(animate: boolean)
		local balance = player:GetAttribute(CoinConfig.BalanceAttribute)
		if typeof(balance) ~= "number" then
			return
		end
		if animate then
			TweenService:Create(shown, TweenInfo.new(COUNT_SECONDS, Enum.EasingStyle.Quad), { Value = balance }):Play()
		else
			shown.Value = balance
			amount.Text = CoinConfig.format(balance)
		end
	end
	showBalance(false)
	player:GetAttributeChangedSignal(CoinConfig.BalanceAttribute):Connect(function()
		showBalance(true)
	end)

	-- One pop-up: "+150 COINS" and the reason under it; rises and fades.
	local function pop(news: CoinRemotes.CoinChange)
		local gained = news.change >= 0
		local holder = Instance.new("Frame")
		holder.Name = "Pop"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = pops
		local top = UIStyle.text(holder, "Amount", UDim2.fromOffset(0, -4), UDim2.new(1, 0, 0, 28), SIZES.heading,
			if gained then GREEN else C.red, UIStyle.heading())
		top.TextWrapped = false
		top.Text = string.format("%s%s %s", if gained then "+" else "-", CoinConfig.format(math.abs(news.change)), CoinConfig.Name)
		local under = UIStyle.text(holder, "Reason", UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 20), SIZES.small, C.white,
			UIStyle.heading())
		under.TextWrapped = false
		under.Text = string.upper(news.reason)
		for _, label in ipairs({ top, under }) do
			local outline = Instance.new("UIStroke")
			outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			outline.Color = C.ink
			outline.Thickness = 2
			outline.Parent = label
		end
		local info = TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(holder, info, { Position = UDim2.fromOffset(0, -POP_RISE) }):Play()
		local fade = TweenInfo.new(POP_SECONDS * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, POP_SECONDS * 0.5)
		for _, label in ipairs({ top, under }) do
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(label:FindFirstChildOfClass("UIStroke") :: UIStroke, fade, { Transparency = 1 }):Play()
		end
		task.delay(POP_SECONDS + 0.1, function()
			holder:Destroy()
		end)
	end

	local queue: { CoinRemotes.CoinChange } = {}
	local busy = false
	remote.OnClientEvent:Connect(function(news: CoinRemotes.CoinChange)
		if typeof(news) ~= "table" or typeof(news.change) ~= "number" or typeof(news.reason) ~= "string" then
			return
		end
		table.insert(queue, news)
		if busy then
			return
		end
		busy = true
		while #queue > 0 do
			pop(table.remove(queue, 1) :: CoinRemotes.CoinChange)
			task.wait(POP_GAP_SECONDS)
		end
		busy = false
	end)
end

return CoinCounter
