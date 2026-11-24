--!strict
--[[
	BoostBar
	Client / UI

	The gain boosts you have running, as small chips at the bottom middle of the screen (GAME_DESIGN §40.7): today the
	steak meal, a glossy steak-red pill with the boost in a yellow badge ("+80%"), STEAK BOOST, the time left and a
	thin bar that drains over the boost's 24 hours. When a cook finishes while you're in the game, a line says so, and
	a green pill says the meal is waiting until you eat it. Nothing running and nothing waiting = nothing shown.

	The UI kit's look, as the chef's steak picker (UIFancy; user 2026-11-19: "we cant have everything the same boring
	plain box"; 2026-11-21: the chips redone): gradient fills, thick dark edges, soft glows, outlined words.

	The meet meal (user 2026-11-23) has its own chip in the meets' navy, MEET MEAL BOOST, the same way. Boosters
	(§40.1) will add their own chips here.

	Display only: the server keeps the boosts (KitchenService, ProfileOperations, GainBoosts).

	A third chip, in purple, is your LUCK from the mafia boss cow's wheel ("2x", the time left, the same draining bar):
	it shows while a multiplier is in force, by itself at the bottom RIGHT of the screen (user 2026-11-22), above the
	jump button on a touch screen.

	PERFORMANCE: three small chips (about 40 instances); the text updates once a second; the ready chip's slow pulse
	is one tween that runs only while that chip shows.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local LuckConfig = require(Shared:WaitForChild("Config"):WaitForChild("LuckConfig"))
local KitchenRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("KitchenRemotes"))

local TweenService = game:GetService("TweenService")

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local UIFancy = require(script.Parent:WaitForChild("UIFancy"))
local make, corner, outline, glow, words = UIFancy.make, UIFancy.corner, UIFancy.outline, UIFancy.glow, UIFancy.words

local BoostBar = {}

local CHIP_HEIGHT = 44
local CHIP_WIDTH = 350
local PILL = UDim.new(1, 0)
-- (the steak picker's colours: KitchenMenu)
local STEAK_TOP, STEAK_BOTTOM = Color3.fromRGB(150, 44, 30), Color3.fromRGB(58, 16, 12)
local YELLOW_TOP, YELLOW_BOTTOM = Color3.fromRGB(255, 226, 92), Color3.fromRGB(232, 160, 24)
local GREEN_TOP, GREEN_BOTTOM = Color3.fromRGB(132, 240, 110), Color3.fromRGB(38, 150, 52)
local INSET = Color3.fromRGB(24, 10, 8)
local LUCK_TOP, LUCK_BOTTOM = Color3.fromRGB(122, 70, 200), Color3.fromRGB(44, 22, 84)
local MEAL_TOP, MEAL_BOTTOM = Color3.fromRGB(46, 96, 196), Color3.fromRGB(14, 30, 84)

local started = false
local showView: ((any) -> ())? = nil
local celebrateWith: ((string, string?) -> ())? = nil

-- A big "STEAK EATEN!" pop in the middle of the screen with `line` under it (eating at your pan, KitchenMenu);
-- `headline` replaces "STEAK EATEN!" (a meet meal's "MEAL EATEN!").
function BoostBar.celebrate(line: string, headline: string?)
	if celebrateWith then
		(celebrateWith :: (string, string?) -> ())(line, headline)
	end
end
local remotes: KitchenRemotes.RemoteSet? = nil

-- A fresh KitchenView from the server (KitchenMenu calls this after cooking or eating).
function BoostBar.show(view: any)
	if showView and typeof(view) == "table" then
		(showView :: (any) -> ())(view)
	end
end

-- Keeps the luck chip as it is (true) until released (false): a spin's result must not show on the chip before the
-- wheel has stopped (LuckMenu).
local luckHeld = false
local drawLuckNow: (() -> ())? = nil
function BoostBar.holdLuck(hold: boolean)
	luckHeld = hold
	if not hold and drawLuckNow then
		(drawLuckNow :: () -> ())()
	end
end

-- Asks the server again (tries a few times while the save is still loading).
function BoostBar.refresh()
	local set = remotes
	if set == nil then
		return
	end
	task.spawn(function()
		for _ = 1, 8 do
			local ok, view = pcall(function()
				return set.get:InvokeServer()
			end)
			if ok and typeof(view) == "table" then
				BoostBar.show(view)
				return
			end
			task.wait(2)
		end
	end)
end

function BoostBar.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	remotes = KitchenRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Boosts"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 4
	UIStyle.fitToScreen(gui)

	local holder = Instance.new("Frame")
	holder.Name = "Chips"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -10)
	holder.Size = UDim2.fromOffset(CHIP_WIDTH, CHIP_HEIGHT * 3 + 20)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = holder

	-- Luck's own corner: the bottom right. On a touch screen the jump button lives there, so the chip sits above it
	-- (the button is 70 px on a phone and 120 on a tablet; the offset is in full-size pixels, scaled with the screen).
	local luckLift = 10
	if UIStyle.isTouchOnly() then
		local camera = workspace.CurrentCamera
		local short = if camera then math.min(camera.ViewportSize.X, camera.ViewportSize.Y) else 400
		luckLift = math.floor((if short < 500 then 105 else 160) / UIStyle.screenScale())
	end
	local luckHolder = Instance.new("Frame")
	luckHolder.Name = "LuckChips"
	luckHolder.AnchorPoint = Vector2.new(1, 1)
	luckHolder.Position = UDim2.new(1, -14, 1, -luckLift)
	luckHolder.Size = UDim2.fromOffset(CHIP_WIDTH, CHIP_HEIGHT)
	luckHolder.BackgroundTransparency = 1
	luckHolder.Parent = gui

	-- A glossy pill: a gradient fill with a dark edge and a soft glow, a shine on its top half. Returns the chip (hidden)
	-- and its fill (to put things on).
	local function pill(name: string, order: number, top: Color3, bottom: Color3, glowColour: Color3, into: Frame?): (Frame, Frame)
		local chip = make("Frame", {
			Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(CHIP_WIDTH, CHIP_HEIGHT), LayoutOrder = order,
			Visible = false, Parent = into or holder,
		})
		local fill = make("Frame", {
			Name = "Fill", BackgroundColor3 = UIFancy.White, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = chip,
		})
		corner(fill, PILL)
		outline(fill, 3)
		glow(fill, glowColour, 20, 0.5)
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom), Parent = fill })
		local shine = make("Frame", {
			Name = "Shine", BackgroundColor3 = UIFancy.White, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 3),
			Size = UDim2.new(1, -12, 0.45, 0), Parent = fill,
		})
		corner(shine, PILL)
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.72, 1), Parent = shine })
		return chip, fill
	end

	-- The meal waiting to be eaten: a green pill that breathes slowly.
	local readyChip, readyFill = pill("SteakReady", 1, GREEN_TOP, GREEN_BOTTOM, Color3.fromRGB(120, 255, 120))
	local readyText = words(readyFill, "Text", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 20, 3)
	readyText.TextWrapped = false
	readyText.Text = "STEAK READY!  GET IT FROM THE CHEF"
	local readyScale = make("UIScale", { Parent = readyChip })
	local readyPulse = TweenService:Create(readyScale,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.05 })

	-- A running boost: its amount in a yellow badge, its name, the time left in a dark inset, a draining bar.
	local function boostChip(name: string, order: number, top: Color3, bottom: Color3, glowColour: Color3, title: string,
		into: Frame?)
		local chip, fill = pill(name, order, top, bottom, glowColour, into)
		local badge = make("Frame", {
			Name = "Gain", BackgroundColor3 = UIFancy.White, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, -2), Size = UDim2.fromOffset(84, 28), Parent = fill,
		})
		corner(badge, PILL)
		outline(badge, 2)
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(YELLOW_TOP, YELLOW_BOTTOM), Parent = badge })
		local amount = words(badge, "Text", UDim2.fromOffset(6, 2), UDim2.new(1, -12, 1, -4), 17, 2.5)
		amount.TextWrapped = false
		amount.TextScaled = true
		make("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 10, Parent = amount })
		local nameText = words(fill, "Name", UDim2.new(0, 96, 0, -2), UDim2.new(1, -96 - 112, 1, 0), 18, 3)
		nameText.TextWrapped = false
		nameText.TextXAlignment = Enum.TextXAlignment.Left
		nameText.Text = title
		local clock = make("Frame", {
			Name = "Clock", BackgroundColor3 = INSET, BackgroundTransparency = 0.1, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, -2), Size = UDim2.fromOffset(102, 26), Parent = fill,
		})
		corner(clock, PILL)
		local time = words(clock, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18, 2, YELLOW_TOP)
		time.TextWrapped = false
		local track = make("Frame", {
			Name = "Left", BackgroundColor3 = INSET, BackgroundTransparency = 0.2, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -40, 0, 4), Parent = fill,
		})
		corner(track, PILL)
		local left = make("Frame", {
			Name = "Fill", BackgroundColor3 = UIFancy.White, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = track,
		})
		corner(left, PILL)
		make("UIGradient", { Color = ColorSequence.new(YELLOW_TOP, YELLOW_BOTTOM), Parent = left })
		return chip, amount, time, left
	end
	local steakChip, gainText, clockText, drain = boostChip("Steak", 2, STEAK_TOP, STEAK_BOTTOM, Color3.fromRGB(255, 140, 90),
		"STEAK BOOST")
	local mealChip, mealGain, mealClock, mealDrain = boostChip("MeetMeal", 3, MEAL_TOP, MEAL_BOTTOM,
		Color3.fromRGB(110, 170, 255), "MEET MEAL BOOST")
	-- Luck from the mafia boss cow's wheel (GAME_DESIGN §40.7): read from this player's attributes, which the server
	-- keeps current (LuckService).
	local luckChip, luckText, luckClock, luckDrain = boostChip("Luck", 3, LUCK_TOP, LUCK_BOTTOM, Color3.fromRGB(190, 130, 255),
		"LUCK", luckHolder)
	local function drawLuck()
		if luckHeld then
			return
		end
		local now = workspace:GetServerTimeNow()
		local luck = LuckConfig.ofPlayer(player, now)
		local endsAt = player:GetAttribute(LuckConfig.EndsAtAttribute)
		if luck ~= 1 and typeof(endsAt) == "number" then
			luckText.Text = LuckConfig.multiplierText(luck)
			luckClock.Text = KitchenConfig.clockText(endsAt - now)
			luckDrain.Size = UDim2.fromScale(math.clamp((endsAt - now) / (LuckConfig.hoursFor(luck) * 3600), 0.02, 1), 1)
			luckChip.Visible = true
		else
			luckChip.Visible = false
		end
	end
	drawLuckNow = drawLuck
	player:GetAttributeChangedSignal(LuckConfig.MultiplierAttribute):Connect(drawLuck)
	player:GetAttributeChangedSignal(LuckConfig.EndsAtAttribute):Connect(drawLuck)

	gui.Parent = player:WaitForChild("PlayerGui")

	local Announcer = require(script.Parent.Parent:WaitForChild("Meet"):WaitForChild("GymRecordAnnouncer"))

	local view: any = nil
	local viewAt = os.clock()
	-- Whether the cook was still cooking last time we looked (to say "ready" once, when it finishes).
	local wasCooking = false

	local function draw()
		local current = view
		local since = os.clock() - viewAt
		local boostLeft = if current then math.max(0, current.boostLeft - since) else 0
		local readyIn = if current then math.max(0, current.readyIn - since) else 0
		local steaks = if current then current.steaks else 0
		if current and current.boostPercent > 0 and boostLeft > 0 then
			gainText.Text = KitchenConfig.percentText(current.boostPercent)
			clockText.Text = KitchenConfig.clockText(boostLeft)
			drain.Size = UDim2.fromScale(math.clamp(boostLeft / (KitchenConfig.BoostHours * 3600), 0.02, 1), 1)
			steakChip.Visible = true
		else
			steakChip.Visible = false
		end
		local mealLeft = if current and typeof(current.mealLeft) == "number" then math.max(0, current.mealLeft - since) else 0
		if current and typeof(current.mealPercent) == "number" and current.mealPercent > 0 and mealLeft > 0 then
			mealGain.Text = KitchenConfig.percentText(current.mealPercent)
			mealClock.Text = KitchenConfig.clockText(mealLeft)
			mealDrain.Size = UDim2.fromScale(math.clamp(mealLeft / (KitchenConfig.BoostHours * 3600), 0.02, 1), 1)
			mealChip.Visible = true
		else
			mealChip.Visible = false
		end
		local meal = current ~= nil and current.kind == "Meal"
		local cooking = steaks >= 1 and readyIn > 0
		local ready = steaks >= 1 and readyIn <= 0
		readyText.Text = if meal then "MEET MEAL READY!  GET IT FROM THE CHEF" else "STEAK READY!  GET IT FROM THE CHEF"
		if ready ~= readyChip.Visible then
			readyChip.Visible = ready
			if ready then
				readyPulse:Play()
			else
				readyPulse:Cancel()
				readyScale.Scale = 1
			end
		end
		if wasCooking and ready then
			Announcer.note(string.format("Your %s is ready! Get it from the chef at W Chews for %s %s gains.",
				if meal then "meet meal" else "steak meal", KitchenConfig.percentText(KitchenConfig.boostPercent(steaks)),
				if meal then "meet" else "training"))
		end
		wasCooking = cooking
	end

	showView = function(fresh: any)
		if typeof(fresh.steaks) ~= "number" then
			return
		end
		view = fresh
		viewAt = os.clock()
		draw()
	end

	-- The eating pop (the UI kit's look: outlined words on a soft glow, popping in and fading).
	local popGui = Instance.new("ScreenGui")
	popGui.Name = "SteakEaten"
	popGui.ResetOnSpawn = false
	popGui.DisplayOrder = 33
	UIStyle.fitToScreen(popGui)
	local pop = UIFancy.make("Frame", {
		Name = "Pop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(620, 200), BackgroundTransparency = 1, Visible = false, Parent = popGui,
	})
	local halo = UIFancy.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 120),
		BackgroundColor3 = Color3.fromRGB(255, 120, 70), BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = pop,
	})
	UIFancy.corner(halo, UDim.new(1, 0))
	UIFancy.glow(halo, Color3.fromRGB(255, 150, 90), 120, 0.2)
	local headline = UIFancy.words(pop, "Headline", UDim2.fromScale(0, 0.05), UDim2.new(1, 0, 0, 90), 76, 5)
	headline.Text = "STEAK EATEN!"
	local sub = UIFancy.words(pop, "Line", UDim2.fromScale(0, 0.55), UDim2.new(1, 0, 0, 56), 44, 4, Color3.fromRGB(110, 236, 96))
	local popScale = UIFancy.make("UIScale", { Parent = pop })
	popGui.Parent = player:WaitForChild("PlayerGui")
	local popToken = 0
	celebrateWith = function(line: string, title: string?)
		popToken += 1
		local mine = popToken
		headline.Text = title or "STEAK EATEN!"
		sub.Text = line
		pop.Visible = true
		popScale.Scale = 0.3
		TweenService:Create(popScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(2.6, function()
			if popToken == mine then
				TweenService:Create(popScale, TweenInfo.new(0.3), { Scale = 0 }):Play()
				task.wait(0.32)
				if popToken == mine then
					pop.Visible = false
				end
			end
		end)
	end

	BoostBar.refresh()
	drawLuck()
	task.spawn(function()
		while true do
			task.wait(1)
			if view then
				draw()
			end
			drawLuck()
		end
	end)
end

return BoostBar
