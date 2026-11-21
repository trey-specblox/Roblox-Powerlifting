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

	Meet meals and boosters (§40.1) will add their own chips here.

	Display only: the server keeps the boosts (KitchenService, ProfileOperations, GainBoosts).

	PERFORMANCE: two small chips (about 25 instances); the text updates once a second; the ready chip's slow pulse is
	one tween that runs only while that chip shows.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
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

local started = false
local showView: ((any) -> ())? = nil
local celebrateWith: ((string) -> ())? = nil

-- A big "STEAK EATEN!" pop in the middle of the screen with `line` under it (eating at your pan, KitchenMenu).
function BoostBar.celebrate(line: string)
	if celebrateWith then
		(celebrateWith :: (string) -> ())(line)
	end
end
local remotes: KitchenRemotes.RemoteSet? = nil

-- A fresh KitchenView from the server (KitchenMenu calls this after cooking or eating).
function BoostBar.show(view: any)
	if showView and typeof(view) == "table" then
		(showView :: (any) -> ())(view)
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
	holder.Size = UDim2.fromOffset(CHIP_WIDTH, CHIP_HEIGHT * 2 + 10)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = holder

	-- A glossy pill: a gradient fill with a dark edge and a soft glow, a shine on its top half. Returns the chip (hidden)
	-- and its fill (to put things on).
	local function pill(name: string, order: number, top: Color3, bottom: Color3, glowColour: Color3): (Frame, Frame)
		local chip = make("Frame", {
			Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(CHIP_WIDTH, CHIP_HEIGHT), LayoutOrder = order,
			Visible = false, Parent = holder,
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
	readyText.Text = "STEAK READY!  EAT IT AT W CHEWS"
	local readyScale = make("UIScale", { Parent = readyChip })
	local readyPulse = TweenService:Create(readyScale,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.05 })

	-- The boost that is running: the gain in a yellow badge, its name, the time left in a dark inset, a draining bar.
	local steakChip, steakFill = pill("Steak", 2, STEAK_TOP, STEAK_BOTTOM, Color3.fromRGB(255, 140, 90))
	local badge = make("Frame", {
		Name = "Gain", BackgroundColor3 = UIFancy.White, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, -2), Size = UDim2.fromOffset(84, 28), Parent = steakFill,
	})
	corner(badge, PILL)
	outline(badge, 2)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(YELLOW_TOP, YELLOW_BOTTOM), Parent = badge })
	local gainText = words(badge, "Text", UDim2.fromOffset(6, 2), UDim2.new(1, -12, 1, -4), 17, 2.5)
	gainText.TextWrapped = false
	gainText.TextScaled = true
	make("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 10, Parent = gainText })
	local nameText = words(steakFill, "Name", UDim2.new(0, 96, 0, -2), UDim2.new(1, -96 - 112, 1, 0), 18, 3)
	nameText.TextWrapped = false
	nameText.TextXAlignment = Enum.TextXAlignment.Left
	nameText.Text = "STEAK BOOST"
	local clock = make("Frame", {
		Name = "Clock", BackgroundColor3 = INSET, BackgroundTransparency = 0.1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, -2), Size = UDim2.fromOffset(102, 26), Parent = steakFill,
	})
	corner(clock, PILL)
	local clockText = words(clock, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18, 2, YELLOW_TOP)
	clockText.TextWrapped = false
	local track = make("Frame", {
		Name = "Left", BackgroundColor3 = INSET, BackgroundTransparency = 0.2, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -40, 0, 4), Parent = steakFill,
	})
	corner(track, PILL)
	local drain = make("Frame", {
		Name = "Fill", BackgroundColor3 = UIFancy.White, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = track,
	})
	corner(drain, PILL)
	make("UIGradient", { Color = ColorSequence.new(YELLOW_TOP, YELLOW_BOTTOM), Parent = drain })

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
		local cooking = steaks >= 1 and readyIn > 0
		local ready = steaks >= 1 and readyIn <= 0
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
			Announcer.note(string.format("Your steak meal is ready! Eat it at W Chews for %s training gains.",
				KitchenConfig.percentText(KitchenConfig.steakPercent(steaks))))
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
	celebrateWith = function(line: string)
		popToken += 1
		local mine = popToken
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
	task.spawn(function()
		while true do
			task.wait(1)
			if view then
				draw()
			end
		end
	end)
end

return BoostBar
