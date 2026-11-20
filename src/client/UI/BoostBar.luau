--!strict
--[[
	BoostBar
	Client / UI

	The gain boosts you have running, as small chips at the bottom middle of the screen (GAME_DESIGN §40.7): today the
	steak meal, "STEAK +80% TRAINING 23:41:10", counting down. When a cook finishes while you're in the game, a line
	says so, and a chip says the meal is waiting until you eat it. Nothing running and nothing waiting = nothing shown.

	Meet meals and boosters (§40.1) will add their own chips here.

	Display only: the server keeps the boosts (KitchenService, ProfileOperations, GainBoosts).

	PERFORMANCE: two labels; the text updates once a second.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local KitchenRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("KitchenRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours

local BoostBar = {}

local CHIP_HEIGHT = 34
local CHIP_WIDTH = 330

local started = false
local showView: ((any) -> ())? = nil
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
	holder.Size = UDim2.fromOffset(CHIP_WIDTH, CHIP_HEIGHT * 2 + 6)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = holder

	local function chip(name: string, order: number, accent: Color3): TextLabel
		local back = UIStyle.frame(holder, name, UDim2.fromOffset(0, 0), UDim2.fromOffset(CHIP_WIDTH, CHIP_HEIGHT), C.ink)
		back.BackgroundTransparency = 0.15
		back.LayoutOrder = order
		back.Visible = false
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 8)
		round.Parent = back
		UIStyle.stroke(back, accent, 2)
		local text = UIStyle.text(back, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), 18, accent, UIStyle.heading())
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.TextYAlignment = Enum.TextYAlignment.Center
		text.TextWrapped = false
		return text
	end
	local readyChip = chip("SteakReady", 1, C.white)
	local steakChip = chip("Steak", 2, C.yellow)

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
			steakChip.Text = string.format("STEAK %s TRAINING  %s", KitchenConfig.percentText(current.boostPercent),
				KitchenConfig.clockText(boostLeft))
			steakChip.Parent.Visible = true
		else
			steakChip.Parent.Visible = false
		end
		local cooking = steaks >= 1 and readyIn > 0
		local ready = steaks >= 1 and readyIn <= 0
		readyChip.Text = "STEAK MEAL READY: EAT IT IN THE KITCHEN"
		readyChip.Parent.Visible = ready
		if wasCooking and ready then
			Announcer.note(string.format("Your steak meal is ready! Eat it in the Kitchen for %s training gains.",
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
