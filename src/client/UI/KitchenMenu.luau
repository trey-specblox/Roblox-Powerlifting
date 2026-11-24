--!strict
--[[
	KitchenMenu
	Client / UI

	Talking to the Kitchen's chef (GAME_DESIGN §40.7, user 2026-11-19). His "Talk" prompt (KitchenService) opens the
	NPC dialogue the coaches use (CoachDialogue.converse: the panel, his portrait, typed words, answer bubbles):

		empty pan    "What are we cooking today?"  Steaks / Meet meals / Bye
		cooking      how long is left, and "Skip the wait" (the Robux skip: not sold yet)
		ready        the steak (or meal) is done: go eat it at your pan

	"Steaks" opens the STEAK PICKER, built from the UI kit, not a plain panel (user: "we cant have everything the same
	boring plain box"): turning rays and a glow in steak red, the big steak in 3D growing with the number, a big outlined
	count, a chunky slider, quick picks, the price / cooking time / boost as badges, and a glossy COOK IT! button.
	"Meet meals" (user 2026-11-23) opens the same picker for meals: the meet gain boost, double a steak's price and time,
	one cook at a time. A meal plays the chef scene's meal version (KitchenScene, kind "Meal": a live hen and two bags
	tipped into the meat bay from its steps, then the tube and the plate on the pan).

	Display only: the server checks the count and the coins and keeps the cook (KitchenService, ProfileOperations);
	the numbers shown come from the same KitchenConfig.

	PERFORMANCE: one screen, built once; while the picker is open its rays turn and the steak spins.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoinConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoinConfig"))
local GearStatsConfig = require(Shared:WaitForChild("Config"):WaitForChild("GearStatsConfig"))
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local KitchenRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("KitchenRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local UIFancy = require(script.Parent:WaitForChild("UIFancy"))
local BoostBar = require(script.Parent:WaitForChild("BoostBar"))
local CoachDialogue = require(script.Parent:WaitForChild("CoachDialogue"))
local PromptController = require(script.Parent:WaitForChild("PromptController"))
local KitchenScene = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("KitchenScene"))
local KitchenClocks = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("KitchenClocks"))

local make, corner, outline, glow, words = UIFancy.make, UIFancy.corner, UIFancy.outline, UIFancy.glow, UIFancy.words
local WHITE, INK = UIFancy.White, UIFancy.Ink

local KitchenMenu = {}

local CARD = Vector2.new(600, 730)
local STEAK_RED = Color3.fromRGB(214, 70, 46)
local YELLOW_TOP, YELLOW_BOTTOM = Color3.fromRGB(255, 226, 92), Color3.fromRGB(232, 160, 24)
local GREY_TOP, GREY_BOTTOM = Color3.fromRGB(150, 150, 156), Color3.fromRGB(92, 92, 100)
local GREEN = Color3.fromRGB(110, 236, 96)
-- The slider runs from 1 to the most a cook takes (KitchenConfig.MaxSteaksPerCook: the +150% cap) on a log scale.
local SLIDER_MAX = KitchenConfig.MaxSteaksPerCook
local QUICK_PICKS = { 10, 50, 100, KitchenConfig.MaxSteaksPerCook }
-- How long a lifter is, for "N LIFTERS LONG" (studs).
local LIFTER_LENGTH = 5.5

local started = false

-- "1 STEAK" / "250 STEAKS"; with kind "Meal": "1 MEET MEAL" / "250 MEET MEALS".
local function steaksText(steaks: number, kind: string?): string
	return string.format("%s %s%s", CoinConfig.format(steaks), if kind == "Meal" then "MEET MEAL" else "STEAK",
		if steaks == 1 then "" else "S")
end

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
	gui.DisplayOrder = 31
	gui.Enabled = false
	UIStyle.fitToScreen(gui)

	local tickSound = make("Sound", { SoundId = GearStatsConfig.Sounds.Tick, Volume = 0.35, Parent = gui })
	local bigSound = make("Sound", { SoundId = GearStatsConfig.Sounds.Big, Volume = 0.6, Parent = gui })

	------------------------------------------------------------------ the card
	local holder = make("Frame", {
		Name = "Picker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD.X, CARD.Y), BackgroundTransparency = 1, Parent = gui,
	})
	local scene = make("Frame", {
		Name = "Scene", BackgroundColor3 = Color3.fromRGB(34, 12, 10), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true, Parent = holder,
	})
	corner(scene, UDim.new(0, 18))
	outline(scene, 4)
	glow(scene, Color3.new(0, 0, 0), 30, 0.4)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(96, 30, 20), Color3.fromRGB(26, 8, 6)),
		Parent = scene,
	})
	local rays = UIFancy.rays(scene, UDim2.fromScale(0.5, 0.31), 1000, 14, STEAK_RED)
	local halo = make("Frame", {
		Name = "Halo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.31),
		Size = UDim2.fromOffset(300, 300), BackgroundColor3 = STEAK_RED, BackgroundTransparency = 0.7, BorderSizePixel = 0,
		Parent = scene,
	})
	corner(halo, UDim.new(1, 0))
	glow(halo, Color3.fromRGB(255, 140, 90), 150, 0.2)

	-- The steak, in 3D, sized by the count.
	local viewport = make("ViewportFrame", {
		Name = "Steak", BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.08), Size = UDim2.new(1, 0, 0.44, 0),
		Ambient = Color3.fromRGB(170, 150, 140), LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.4, -1, 0.3), Parent = scene,
	})
	local world = make("WorldModel", { Parent = viewport })
	local camera = make("Camera", { FieldOfView = 34, Parent = viewport })
	viewport.CurrentCamera = camera
	local steak: Model? = nil
	local steakLength = 1

	UIFancy.vignette(scene, 0.2, 0.5)
	local title = words(scene, "Title", UDim2.fromOffset(20, 14), UDim2.new(1, -90, 0, 44), 38, 3)
	title.Text = "HOW MANY STEAKS?"
	title.TextXAlignment = Enum.TextXAlignment.Left
	local lengthBadge = words(scene, "Length", UDim2.new(0, 22, 0.465, 0), UDim2.new(1, -44, 0, 26), 22, 2,
		Color3.fromRGB(255, 214, 190))

	-- The close button, top right.
	local closeButton = UIFancy.button(scene, "Close", "X", UDim2.new(1, -64, 0, 12), UDim2.fromOffset(50, 46),
		Color3.fromRGB(240, 90, 80), Color3.fromRGB(170, 36, 36), 28, function() end)

	-- The count, big and outlined.
	local countText = words(scene, "Count", UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0, 70), 64, 4)
	countText.TextColor3 = WHITE

	-- The slider: a dark track, a yellow fill and a round knob.
	local track = make("Frame", {
		Name = "Track", Position = UDim2.new(0, 96, 0.615, 0), Size = UDim2.new(1, -192, 0, 22),
		BackgroundColor3 = Color3.fromRGB(24, 10, 8), BorderSizePixel = 0, Parent = scene,
	})
	corner(track, UDim.new(1, 0))
	outline(track, 3)
	local fill = make("Frame", { Name = "Fill", Size = UDim2.fromScale(0.3, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = track })
	corner(fill, UDim.new(1, 0))
	make("UIGradient", { Color = ColorSequence.new(YELLOW_TOP, YELLOW_BOTTOM), Parent = fill })
	local knob = make("TextButton", {
		Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.3, 0.5), Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3, Parent = track,
	})
	corner(knob, UDim.new(1, 0))
	outline(knob, 3)
	glow(knob, Color3.fromRGB(255, 220, 120), 18, 0.3)
	local minus = UIFancy.button(scene, "Minus", "-", UDim2.new(0, 22, 0.615, -14), UDim2.fromOffset(56, 50),
		Color3.fromRGB(110, 110, 120), Color3.fromRGB(60, 60, 70), 34, function() end)
	local plus = UIFancy.button(scene, "Plus", "+", UDim2.new(1, -78, 0.615, -14), UDim2.fromOffset(56, 50),
		Color3.fromRGB(110, 110, 120), Color3.fromRGB(60, 60, 70), 34, function() end)

	-- Quick picks and a box to type any number.
	local picks: { TextButton } = {}
	for index, amount in ipairs(QUICK_PICKS) do
		picks[index] = (UIFancy.button(scene, "Pick" .. amount, tostring(amount), UDim2.new(0, 22 + (index - 1) * 96, 0.69, 0),
			UDim2.fromOffset(86, 40), Color3.fromRGB(255, 130, 100), Color3.fromRGB(190, 60, 40), 24, function() end))
	end
	local typeBox = make("TextBox", {
		Name = "Type", Position = UDim2.new(1, -196, 0.69, 0), Size = UDim2.fromOffset(174, 40), BackgroundColor3 = Color3.fromRGB(24, 10, 8),
		TextColor3 = WHITE, PlaceholderText = "TYPE A NUMBER", PlaceholderColor3 = Color3.fromRGB(180, 140, 130),
		FontFace = UIFancy.TitleFont, TextSize = 20, ClearTextOnFocus = true, Text = "", Parent = scene,
	})
	corner(typeBox, UDim.new(0, 12))
	outline(typeBox, 3)

	-- THE COOK TIMER (user 2026-11-23, GAME_DESIGN §41.5): how long it cooks is how long the boost lasts; longer is the
	-- better deal per hour.
	local timerLabel = words(scene, "TimerLabel", UDim2.new(0, 22, 0.765, 0), UDim2.new(1, -44, 0, 22), 18, 2,
		Color3.fromRGB(255, 214, 190), UIFancy.BodyFont)
	timerLabel.Text = "COOK TIME = HOW LONG THE BOOST LASTS"
	local hourButtons: { { button: TextButton, gradient: UIGradient, hours: number } } = {}
	local hourCount = #KitchenConfig.CookHours
	local hourWidth = math.floor((CARD.X - 44 - (hourCount - 1) * 6) / hourCount)
	for index, hours in ipairs(KitchenConfig.CookHours) do
		local button, gradient = UIFancy.button(scene, "Hours" .. index, KitchenConfig.hoursText(hours),
			UDim2.new(0, 22 + (index - 1) * (hourWidth + 6), 0.8, 0), UDim2.fromOffset(hourWidth, 40), GREY_TOP, GREY_BOTTOM, 20,
			function() end)
		table.insert(hourButtons, { button = button, gradient = gradient, hours = hours })
	end

	-- The badges: price, cooking time, boost.
	local function badge(name: string, x: number, colour: Color3): TextLabel
		local back = make("Frame", {
			Name = name, Position = UDim2.new(x, 0, 0.87, 0), Size = UDim2.new(0.3, -8, 0, 30),
			BackgroundColor3 = Color3.fromRGB(20, 8, 6), BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = scene,
		})
		corner(back, UDim.new(1, 0))
		outline(back, 2, colour)
		local label = words(back, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18, 2, colour)
		return label
	end
	local costBadge = badge("Cost", 0.035, Color3.fromRGB(255, 220, 90))
	local timeBadge = badge("Time", 0.35, WHITE)
	local boostBadge = badge("Boost", 0.665, GREEN)

	local cookButton, cookGradient, cookLabel = UIFancy.button(holder, "Cook", "COOK IT!", UDim2.new(0.5, -150, 1, -40),
		UDim2.fromOffset(300, 64), YELLOW_TOP, YELLOW_BOTTOM, 34, function() end)

	gui.Parent = player:WaitForChild("PlayerGui")

	------------------------------------------------------------------ state
	local count = 50
	local mode = "Steak" -- what the picker cooks: "Steak" or "Meal"
	local hours = KitchenConfig.BoostHours -- the cook timer: 24 hours is the best deal per hour
	local busy = false
	local open = false
	local dragging = false

	local function coins(): number
		local value = player:GetAttribute(CoinConfig.BalanceAttribute)
		return if typeof(value) == "number" then value else 0
	end

	local function sliderShare(steaks: number): number
		return math.clamp(math.log(math.max(steaks, 1)) / math.log(SLIDER_MAX), 0, 1)
	end

	local shownKind: string? = nil
	local function placeSteak()
		local model = steak
		if shownKind ~= mode and model then
			model:Destroy()
			model, steak = nil, nil
		end
		if model == nil then
			-- (the meal's plate model, "MeetMeal", is used once it is uploaded; until then the card shows no model)
			local template = ReplicatedStorage:FindFirstChild("KitchenModels")
			local source = template and template:FindFirstChild(if mode == "Meal" then "MeetMeal" else "BigSteak")
			if source and source:IsA("Model") then
				model = source:Clone()
				model:ScaleTo(1)
				steakLength = math.max(model:GetExtentsSize().X, 0.1)
				model:PivotTo(CFrame.new())
				model.Parent = world
				steak = model
				shownKind = mode
			end
		end
		if model then
			-- Shown at the size it will be in the pan, up to what fits the card: the camera backs off as it grows.
			local length = KitchenConfig.steakLength(count)
			model:ScaleTo(length / steakLength)
			local distance = 6 + length * 1.25
			camera.CFrame = CFrame.lookAt(Vector3.new(0, distance * 0.55, -distance), Vector3.new(0, length * 0.05, 0))
		end
	end

	local function draw()
		count = math.clamp(math.floor(count), 1, KitchenConfig.MaxSteaksPerCook)
		title.Text = if mode == "Meal" then "HOW MANY MEET MEALS?" else "HOW MANY STEAKS?"
		countText.Text = steaksText(count, mode)
		local share = sliderShare(count)
		fill.Size = UDim2.fromScale(share, 1)
		knob.Position = UDim2.fromScale(share, 0.5)
		local price = KitchenConfig.cost(count, mode, hours)
		costBadge.Text = string.format("%s COINS", CoinConfig.format(price))
		timeBadge.Text = "READY IN " .. KitchenConfig.hoursText(hours)
		local percent = KitchenConfig.boostPercent(count, mode)
		boostBadge.Text = string.format("%s%s · %s", KitchenConfig.percentText(percent),
			if percent >= KitchenConfig.MaxBoostPercent then " MAX" else "", KitchenConfig.hoursText(hours))
		for _, entry in ipairs(hourButtons) do
			local chosen = entry.hours == hours
			entry.gradient.Color = if chosen then ColorSequence.new(YELLOW_TOP, YELLOW_BOTTOM) else ColorSequence.new(GREY_TOP, GREY_BOTTOM)
		end
		timerLabel.Text = string.format("COOK TIME = BOOST TIME  ·  %s COINS AN HOUR", CoinConfig.format(math.floor(price / hours + 0.5)))
		if mode == "Meal" then
			lengthBadge.Text = "MORE STRENGTH FROM EVERY MEET"
		else
			local lifters = KitchenConfig.steakLength(count) / LIFTER_LENGTH
			lengthBadge.Text = if lifters < 1.15 then "ABOUT ONE LIFTER LONG"
				else string.format("ABOUT %s LIFTERS LONG", if lifters < 10 then string.format("%.1f", lifters) else tostring(math.floor(lifters)))
		end
		local enough = coins() >= price
		cookLabel.Text = if enough then "COOK IT!" else "NOT ENOUGH COINS"
		cookGradient.Color = if enough then ColorSequence.new(YELLOW_TOP, YELLOW_BOTTOM) else ColorSequence.new(GREY_TOP, GREY_BOTTOM)
		placeSteak()
	end

	local function setFromShare(share: number)
		count = math.max(1, math.floor(math.exp(math.clamp(share, 0, 1) * math.log(SLIDER_MAX)) + 0.5))
		draw()
	end

	local spin = 0
	local spinConnection: RBXScriptConnection? = nil
	local function closePicker()
		open = false
		gui.Enabled = false
		PromptController.hide("KitchenPicker", false)
		if spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end
	local function openPicker(kind: string?)
		mode = if kind == "Meal" then "Meal" else "Steak"
		open = true
		gui.Enabled = true
		PromptController.hide("KitchenPicker", true)
		draw()
		if spinConnection == nil then
			spinConnection = RunService.RenderStepped:Connect(function(dt)
				spin += dt
				rays.Rotation = (spin * 8) % 360
				local model = steak
				if model then
					model:PivotTo(CFrame.Angles(0, spin * 0.6, 0))
				end
			end)
		end
	end

	-- The slider: drag the knob or press anywhere on the track.
	local function slideTo(x: number)
		local left, width = track.AbsolutePosition.X, track.AbsoluteSize.X
		if width > 0 then
			setFromShare((x - left) / width)
		end
	end
	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			slideTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			slideTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				tickSound:Play()
			end
			dragging = false
		end
	end)
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
	for index, button in ipairs(picks) do
		button.Activated:Connect(function()
			count = QUICK_PICKS[index]
			tickSound:Play()
			draw()
		end)
	end
	for _, entry in ipairs(hourButtons) do
		entry.button.Activated:Connect(function()
			hours = entry.hours
			tickSound:Play()
			draw()
		end)
	end
	typeBox.FocusLost:Connect(function()
		local typed = tonumber((string.gsub(typeBox.Text, "[^%d]", "")))
		if typed then
			count = typed
		end
		typeBox.Text = ""
		draw()
	end)
	closeButton.Activated:Connect(closePicker)
	player:GetAttributeChangedSignal(CoinConfig.BalanceAttribute):Connect(function()
		if open then
			draw()
		end
	end)

	cookButton.Activated:Connect(function()
		if busy or coins() < KitchenConfig.cost(count, mode, hours) then
			return
		end
		busy = true
		local cooking = mode
		local ok, answer = pcall(function()
			return remotes.cook:InvokeServer(count, cooking, hours)
		end)
		busy = false
		if ok and typeof(answer) == "table" then
			if typeof(answer.view) == "table" then
				BoostBar.show(answer.view)
			end
			if answer.outcome == "Started" then
				bigSound:Play()
				closePicker()
				-- The chef scene: into the grinder, the meat mountain, onto the pan; for a meal (user 2026-11-23) up the bay's
				-- steps with a live hen and two bags. Skippable once watched to the end (user 2026-11-21: "Skip after first
				-- time"); the first full watch is saved.
				local seen = typeof(answer.view) == "table" and answer.view.sceneSeen == true
				task.spawn(function()
					local finished = KitchenScene.play(count, seen, cooking)
					if finished and not seen then
						pcall(function()
							return remotes.sceneSeen:InvokeServer()
						end)
					end
				end)
				return
			end
			cookLabel.Text = if answer.outcome == "NotEnough" then "NOT ENOUGH COINS"
				elseif answer.outcome == "Busy" then "YOUR PAN IS BUSY" else "TRY AGAIN"
		end
	end)

	------------------------------------------------------------------ the chef's conversation
	local function talk(prompt: ProximityPrompt)
		local figure = prompt:FindFirstAncestorOfClass("Model")
		local converse = CoachDialogue.converse
		if figure == nil or converse == nil or open then
			return
		end
		local view: any = nil
		local ok, fresh = pcall(function()
			return remotes.get:InvokeServer()
		end)
		if ok and typeof(fresh) == "table" then
			view = fresh
			BoostBar.show(fresh)
		end
		local wants: string? = nil -- "Steak" or "Meal": the picker to open after the talk
		converse(figure, "Chef", function(say, ask)
			local steaks = if view then view.steaks else 0
			local kind = if view and view.kind == "Meal" then "Meal" else "Steak"
			if steaks >= 1 and view.readyIn > 0 then
				say(string.format("Your %s %s on the pan. Ready in %s.", string.lower(steaksText(steaks, kind)),
					if steaks == 1 then "is" else "are", KitchenConfig.clockText(view.readyIn)))
				while true do
					local choice = ask({
						{ text = "Skip the wait", value = "Skip" },
						{ text = if kind == "Meal" then "Steaks?" else "Meet meals?", value = "Other" },
						{ text = "Bye.", value = "Bye" },
					})
					if choice == nil or choice == "Bye" then
						return
					elseif choice == "Skip" then
						say("The fast lane isn't open yet. Patience builds muscle too.")
					else
						say("One thing on the pan at a time. Come back once this is done and I'll cook it.")
					end
				end
			elseif steaks >= 1 then
				-- Done: the chef hands it over into the inventory (user 2026-11-24, GAME_DESIGN §42: "walk up to the chef and
				-- ask for their food then it appears in their Inventory").
				say(string.format("Your %s %s done!", string.lower(steaksText(steaks, kind)), if steaks == 1 then "is" else "are"))
				local choice = ask({
					{ text = "Can I have my food?", value = "Collect" },
					{ text = "Later.", value = "Bye" },
				})
				if choice == "Collect" then
					local ok, answer = pcall(function()
						return remotes.collect:InvokeServer()
					end)
					if ok and typeof(answer) == "table" and answer.outcome == "Collected" then
						if typeof(answer.view) == "table" then
							BoostBar.show(answer.view)
						end
						bigSound:Play()
						say("Here you go! It's in your INVENTORY. Eat it whenever you're ready.")
					elseif ok and typeof(answer) == "table" and answer.outcome == "Full" then
						say("Your inventory is full. Make some room and come back.")
					else
						say("Hold on, something went wrong. Ask me again.")
					end
					ask({ { text = "Thanks!", value = "Bye" } })
				end
			else
				say("What are we cooking today?")
				while true do
					local choice = ask({
						{ text = "Steaks", value = "Steaks" },
						{ text = "Meet meals", value = "Meals" },
						{ text = "Bye.", value = "Bye" },
					})
					if choice == nil or choice == "Bye" then
						return
					elseif choice == "Steaks" then
						say("How many? The more you bring, the bigger I cook it.")
						wants = "Steak"
						return
					else
						say("Chicken, rice and broccoli. Eat it and every meet makes you stronger for a day. How many?")
						wants = "Meal"
						return
					end
				end
			end
		end)
		if wants then
			openPicker(wants)
		end
	end

	-- Eating at your own pan (KitchenClocks puts the "Eat" prompt there when it's done): the boost starts, with a big pop.
	local eating = false
	KitchenClocks.onEat(function()
		if eating then
			return
		end
		eating = true
		local ok, answer = pcall(function()
			return remotes.eat:InvokeServer()
		end)
		eating = false
		if ok and typeof(answer) == "table" then
			if typeof(answer.view) == "table" then
				BoostBar.show(answer.view)
			end
			if answer.outcome == "Eaten" and typeof(answer.percent) == "number" then
				local chomp = make("Sound", { SoundId = KitchenConfig.Sounds.Eat, Volume = 0.9, Parent = gui })
				chomp:Play()
				task.delay(3, function()
					chomp:Destroy()
				end)
				bigSound:Play()
				-- The time it now runs for (the cook's hours, or more when it topped up the same boost).
				local view = answer.view
				local left = if typeof(view) == "table"
					then (if answer.kind == "Meal" then view.mealLeft else view.boostLeft) else nil
				BoostBar.celebrate(string.format("%s %s FOR %s", KitchenConfig.percentText(answer.percent),
					if answer.kind == "Meal" then "MEETS" else "TRAINING",
					if typeof(left) == "number" then KitchenConfig.clockText(left) else "24H"),
					if answer.kind == "Meal" then "MEAL EATEN!" else nil)
			end
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredBy)
		if triggeredBy == player and prompt:HasTag(KitchenConfig.PromptTag) then
			task.spawn(talk, prompt)
		end
	end)
end

return KitchenMenu
