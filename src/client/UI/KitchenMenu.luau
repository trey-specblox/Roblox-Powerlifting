--!strict
--[[
	KitchenMenu
	Client / UI

	The steak cooker's menu (GAME_DESIGN §40.7, user 2026-11-19). Pressing the cooker's "Cook" prompt (KitchenService
	tags it) opens it; it shows one of three states:

		EMPTY     pick how many steaks (−/+, quick picks, or type a number): the price, the cooking time and the
		          training boost the meal will give; COOK pays and starts it
		COOKING   how far along it is and the time left; it keeps cooking while you're away, even offline
		READY     EAT starts the boost (24 hours); a warning first if it would replace a bigger boost still running

	At the bottom: the steak boost running now, if any. Display only: the server checks the count and the coins and
	sets every number (KitchenService, ProfileOperations); the numbers shown come from the same KitchenConfig.

	PERFORMANCE: one panel, built once; its timer updates once a second while open.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoinConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoinConfig"))
local GearStatsConfig = require(Shared:WaitForChild("Config"):WaitForChild("GearStatsConfig"))
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local KitchenRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("KitchenRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local BoostBar = require(script.Parent:WaitForChild("BoostBar"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local KitchenMenu = {}

local PANEL_WIDTH = 620
local PANEL_HEIGHT = 440
-- Farther than this from the cooker (studs) closes the menu.
local WALK_AWAY = 16
local QUICK_PICKS = { 1, 10, 50, 100, 250, 500 }

-- "1 STEAK" / "250 STEAKS".
local function steaksText(steaks: number): string
	return string.format("%s STEAK%s", CoinConfig.format(steaks), if steaks == 1 then "" else "S")
end

local started = false

function KitchenMenu.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = KitchenRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Kitchen"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 8
	gui.Enabled = false
	UIStyle.fitToScreen(gui)

	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	UIStyle.titleTag(holder, "Tag", "KITCHEN", UDim2.fromOffset(-18, -30), UDim2.fromOffset(240, 52), nil, "star")

	-- The player's coins, top right.
	UIStyle.coin(body, UDim2.new(1, -236, 0, 22), 26)
	local coinsText = UIStyle.text(body, "Coins", UDim2.new(1, -202, 0, 20), UDim2.fromOffset(186, 30), SIZES.heading, C.yellow,
		UIStyle.heading())
	coinsText.TextWrapped = false

	local function sound(id: string, volume: number): Sound
		local made = Instance.new("Sound")
		made.SoundId = id
		made.Volume = volume
		made.Parent = gui
		return made
	end
	local tickSound = sound(GearStatsConfig.Sounds.Tick, 0.35)
	local bigSound = sound(GearStatsConfig.Sounds.Big, 0.6)

	-- One frame per state; only one shows.
	local function page(name: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.Position = UDim2.fromOffset(0, 56)
		frame.Size = UDim2.new(1, 0, 1, -130)
		frame.Visible = false
		frame.Parent = body
		return frame
	end

	------------------------------------------------------------------ EMPTY: choose and cook
	local emptyPage = page("Empty")
	UIStyle.sectionHead(emptyPage, "Head", "HOW MANY STEAKS?", UDim2.fromOffset(24, 0), 220, PANEL_WIDTH - 48, "slashes")
	local count = 10
	local minus = UIStyle.button(emptyPage, "Minus", "−", UDim2.fromOffset(24, 34), UDim2.fromOffset(56, 56), "outline", function() end)
	local countBox = Instance.new("TextBox")
	countBox.Name = "Count"
	countBox.Position = UDim2.fromOffset(90, 34)
	countBox.Size = UDim2.fromOffset(180, 56)
	countBox.BackgroundColor3 = C.navyDeep
	countBox.BorderSizePixel = 0
	countBox.TextColor3 = C.white
	countBox.FontFace = UIStyle.heading()
	countBox.TextSize = SIZES.big
	countBox.ClearTextOnFocus = false
	countBox.Text = tostring(count)
	countBox.Parent = emptyPage
	UIStyle.stroke(countBox, C.yellow, 2)
	local plus = UIStyle.button(emptyPage, "Plus", "+", UDim2.fromOffset(280, 34), UDim2.fromOffset(56, 56), "outline", function() end)
	local quick: { TextButton } = {}
	for index, amount in ipairs(QUICK_PICKS) do
		local column = (index - 1) % 3
		local row = (index - 1) // 3
		quick[index] = UIStyle.button(emptyPage, "Pick" .. amount, tostring(amount),
			UDim2.fromOffset(356 + column * 82, 34 + row * 32), UDim2.fromOffset(74, 26), "outline", function()
				count = amount
				tickSound:Play()
			end)
	end
	local costText = UIStyle.text(emptyPage, "Cost", UDim2.fromOffset(24, 106), UDim2.fromOffset(280, 30), SIZES.heading, C.white,
		UIStyle.heading())
	local timeText = UIStyle.text(emptyPage, "Time", UDim2.fromOffset(310, 106), UDim2.fromOffset(290, 30), SIZES.heading, C.white,
		UIStyle.heading())
	local boostText = UIStyle.text(emptyPage, "Boost", UDim2.fromOffset(24, 142), UDim2.fromOffset(PANEL_WIDTH - 48, 30),
		SIZES.heading, C.yellow, UIStyle.heading())
	local hintText = UIStyle.text(emptyPage, "Hint", UDim2.fromOffset(24, 178), UDim2.fromOffset(PANEL_WIDTH - 48, 44), SIZES.small,
		C.muted)
	hintText.Text = "It keeps cooking while you train, compete or log off. Come back and eat it when it's ready."
	local cookButton: TextButton

	------------------------------------------------------------------ COOKING
	local cookingPage = page("Cooking")
	local cookingHead = UIStyle.sectionHead(cookingPage, "Head", "COOKING", UDim2.fromOffset(24, 0), 300, PANEL_WIDTH - 48, "slashes")
	local track = UIStyle.frame(cookingPage, "Track", UDim2.fromOffset(24, 44), UDim2.fromOffset(PANEL_WIDTH - 48, 30), C.empty)
	UIStyle.stroke(track, C.white, 2)
	local fill = UIStyle.frame(track, "Fill", UDim2.fromOffset(0, 0), UDim2.fromScale(0, 1), C.yellow)
	local leftText = UIStyle.text(cookingPage, "Left", UDim2.fromOffset(24, 88), UDim2.fromOffset(PANEL_WIDTH - 48, 40), SIZES.big,
		C.white, UIStyle.heading())
	local willText = UIStyle.text(cookingPage, "Will", UDim2.fromOffset(24, 136), UDim2.fromOffset(PANEL_WIDTH - 48, 30),
		SIZES.body, C.yellow, UIStyle.heading())
	local awayText = UIStyle.text(cookingPage, "Away", UDim2.fromOffset(24, 172), UDim2.fromOffset(PANEL_WIDTH - 48, 44), SIZES.small,
		C.muted)
	awayText.Text = "You can leave: it keeps cooking while you're away, even offline."

	------------------------------------------------------------------ READY
	local readyPage = page("Ready")
	local readyHead = UIStyle.sectionHead(readyPage, "Head", "READY!", UDim2.fromOffset(24, 0), 300, PANEL_WIDTH - 48, "star")
	local mealText = UIStyle.text(readyPage, "Meal", UDim2.fromOffset(24, 40), UDim2.fromOffset(PANEL_WIDTH - 48, 40),
		SIZES.heading, C.yellow, UIStyle.heading())
	local warnText = UIStyle.text(readyPage, "Warn", UDim2.fromOffset(24, 96), UDim2.fromOffset(PANEL_WIDTH - 48, 60), SIZES.body,
		C.white)
	local eatButton: TextButton

	-- The steak boost running now, at the bottom.
	local activeText = UIStyle.text(body, "Active", UDim2.new(0, 24, 1, -64), UDim2.new(1, -230, 0, 44), SIZES.body, C.muted)
	activeText.TextYAlignment = Enum.TextYAlignment.Center

	local status = UIStyle.text(body, "Status", UDim2.new(0, 24, 1, -100), UDim2.new(1, -48, 0, 28), SIZES.body, C.red)

	gui.Parent = player:WaitForChild("PlayerGui")

	-- The last answer from the server, and when it arrived on this client's clock.
	local view: KitchenRemotes.KitchenView? = nil
	local viewAt = os.clock()
	local open = false
	local busy = false
	local session = 0
	local confirmReplace = false

	local function coins(): number
		local value = player:GetAttribute(CoinConfig.BalanceAttribute)
		return if typeof(value) == "number" then value else 0
	end

	local function readyIn(): number
		return if view then math.max(0, view.readyIn - (os.clock() - viewAt)) else 0
	end
	local function boostLeft(): number
		return if view then math.max(0, view.boostLeft - (os.clock() - viewAt)) else 0
	end

	local function drawEmpty()
		count = math.clamp(math.floor(count), 1, KitchenConfig.MaxSteaksPerCook)
		if not countBox:IsFocused() then
			countBox.Text = tostring(count)
		end
		local price = KitchenConfig.cost(count)
		costText.Text = string.format("COST  %s COINS", CoinConfig.format(price))
		timeText.Text = string.format("COOKS  %s", KitchenConfig.clockText(KitchenConfig.cookSeconds(count)))
		boostText.Text = string.format("%s TRAINING GAINS FOR %d HOURS", KitchenConfig.percentText(KitchenConfig.steakPercent(count)),
			KitchenConfig.BoostHours)
		local enough = coins() >= price
		cookButton.Text = if enough then "COOK" else "NOT ENOUGH COINS"
		cookButton.AutoButtonColor = enough
		cookButton.BackgroundColor3 = if enough then C.yellow else C.empty
		cookButton.TextColor3 = if enough then C.ink else C.muted
	end

	local function draw()
		coinsText.Text = string.format("%s %s", CoinConfig.format(coins()), CoinConfig.Name)
		local current = view
		local steaks = if current then current.steaks else 0
		local left = readyIn()
		emptyPage.Visible = steaks < 1
		cookingPage.Visible = steaks >= 1 and left > 0
		readyPage.Visible = steaks >= 1 and left <= 0
		cookButton.Visible = emptyPage.Visible
		eatButton.Visible = readyPage.Visible
		if emptyPage.Visible then
			drawEmpty()
		elseif cookingPage.Visible and current then
			cookingHead.Text = "COOKING " .. steaksText(steaks)
			local total = math.max(current.cookSeconds, 1)
			fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
			leftText.Text = string.format("READY IN %s", KitchenConfig.clockText(left))
			willText.Text = string.format("EAT IT FOR %s TRAINING GAINS FOR %d HOURS",
				KitchenConfig.percentText(KitchenConfig.steakPercent(steaks)), KitchenConfig.BoostHours)
		elseif readyPage.Visible and current then
			readyHead.Text = steaksText(steaks) .. " READY!"
			local percent = KitchenConfig.steakPercent(steaks)
			mealText.Text = string.format("%s TRAINING GAINS FOR %d HOURS", KitchenConfig.percentText(percent),
				KitchenConfig.BoostHours)
			local running = current.boostPercent > 0 and boostLeft() > 0
			if running and current.boostPercent > percent + 1e-6 then
				warnText.Text = string.format("Your %s steak boost (%s left) is bigger. Eating this replaces it.",
					KitchenConfig.percentText(current.boostPercent), KitchenConfig.clockText(boostLeft()))
				warnText.TextColor3 = C.red
				eatButton.Text = if confirmReplace then "EAT ANYWAY" else "EAT"
			elseif running then
				warnText.Text = string.format("Replaces your %s steak boost and starts a fresh %d hours.",
					KitchenConfig.percentText(current.boostPercent), KitchenConfig.BoostHours)
				warnText.TextColor3 = C.white
				eatButton.Text = "EAT"
			else
				warnText.Text = "Strength and technique from training both go up while it lasts."
				warnText.TextColor3 = C.white
				eatButton.Text = "EAT"
			end
		end
		if current and current.boostPercent > 0 and boostLeft() > 0 then
			activeText.Text = string.format("ACTIVE: STEAK %s TRAINING, %s LEFT", KitchenConfig.percentText(current.boostPercent),
				KitchenConfig.clockText(boostLeft()))
			activeText.TextColor3 = C.yellow
		else
			activeText.Text = "NO STEAK BOOST RUNNING"
			activeText.TextColor3 = C.muted
		end
	end

	local function apply(fresh: any)
		if typeof(fresh) == "table" and typeof(fresh.steaks) == "number" then
			view = fresh
			viewAt = os.clock()
			BoostBar.show(fresh)
		end
	end

	local function close()
		session += 1
		open = false
		gui.Enabled = false
		confirmReplace = false
	end

	cookButton = UIStyle.button(body, "CookButton", "COOK", UDim2.new(1, -224, 1, -60), UDim2.fromOffset(200, 44), "primary",
		function()
			if busy or coins() < KitchenConfig.cost(count) then
				return
			end
			busy = true
			status.Text = ""
			local ok, answer = pcall(function()
				return remotes.cook:InvokeServer(count)
			end)
			busy = false
			if ok and typeof(answer) == "table" then
				apply(answer.view)
				if answer.outcome == "Started" then
					bigSound:Play()
				elseif answer.outcome == "NotEnough" then
					status.Text = "Not enough coins."
				elseif answer.outcome == "Busy" then
					status.Text = "The cooker is busy. Try again."
				else
					status.Text = "That didn't work. Try again."
				end
			end
			draw()
		end)
	eatButton = UIStyle.button(body, "EatButton", "EAT", UDim2.new(1, -224, 1, -60), UDim2.fromOffset(200, 44), "primary", function()
		local current = view
		if busy or current == nil then
			return
		end
		local bigger = current.boostPercent > KitchenConfig.steakPercent(current.steaks) + 1e-6 and boostLeft() > 0
		if bigger and not confirmReplace then
			confirmReplace = true
			draw()
			return
		end
		busy = true
		status.Text = ""
		local ok, answer = pcall(function()
			return remotes.eat:InvokeServer()
		end)
		busy = false
		confirmReplace = false
		if ok and typeof(answer) == "table" then
			apply(answer.view)
			if answer.outcome == "Eaten" then
				bigSound:Play()
			elseif answer.outcome ~= "Eaten" then
				status.Text = "Not ready yet."
			end
		end
		draw()
	end)
	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), close)

	minus.Activated:Connect(function()
		count -= if count > 100 then 10 else 1
		tickSound:Play()
		draw()
	end)
	plus.Activated:Connect(function()
		count += if count >= 100 then 10 else 1
		tickSound:Play()
		draw()
	end)
	for _, button in ipairs(quick) do
		button.Activated:Connect(draw)
	end
	countBox.FocusLost:Connect(function()
		local typed = tonumber((string.gsub(countBox.Text, "[^%d]", "")))
		if typed then
			count = typed
		end
		draw()
	end)

	local function openAt(prompt: ProximityPrompt)
		if open then
			return
		end
		open = true
		session += 1
		local mine = session
		status.Text = ""
		confirmReplace = false
		gui.Enabled = true
		draw()
		task.spawn(function()
			for _ = 1, 3 do
				local ok, fresh = pcall(function()
					return remotes.get:InvokeServer()
				end)
				if ok and fresh then
					apply(fresh)
					break
				end
				task.wait(0.5)
			end
			if session == mine then
				draw()
			end
		end)
		-- Walking away closes it; the timer ticks while open.
		local spot = prompt.Parent
		task.spawn(function()
			while session == mine do
				task.wait(1)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if spot and spot:IsA("BasePart") and (root == nil or (root.Position - spot.Position).Magnitude > WALK_AWAY) then
					close()
					return
				end
				if session == mine then
					draw()
				end
			end
		end)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredBy)
		if triggeredBy == player and prompt:HasTag(KitchenConfig.PromptTag) then
			openAt(prompt)
		end
	end)
	player:GetAttributeChangedSignal(CoinConfig.BalanceAttribute):Connect(function()
		if open then
			draw()
		end
	end)
end

return KitchenMenu
