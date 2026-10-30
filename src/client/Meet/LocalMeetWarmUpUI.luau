--!strict
--[[
	LocalMeetWarmUpUI
	Client / Meet

	The WARM-UP card while the player stands at a warm-up rack in the Local meet
	venue (GAME_DESIGN.md §29.10, build step 3; LocalMeetWarmUp on the server).
	Bottom middle of the screen, hidden while a lift runs (the minigame has the
	screen):

		SQUAT  BENCH  DEADLIFT          which lift
		-10  -2.5   102.5 KG   +2.5  +10  the bar weight, and its % of CN
		LAST  SQUAT 102.5 KG  GOOD LIFT    or "practice only" before the first
		LIFT >>          LEAVE RACK

	The weight stays inside the meet's range (AttemptChoice.bounds) on the
	meet's step; each lift starts at the opener suggestion. It only ASKS: the
	server checks the weight again and decides the lift. Built from UIStyle.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local LocalMeetRemotes = require(MeetFolder:WaitForChild("LocalMeetRemotes"))
local AttemptChoice = require(MeetFolder:WaitForChild("AttemptChoice"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local LocalMeetWarmUpUI = {}

export type Handlers = {
	lift: (liftName: string, weightKg: number) -> (),
	leave: () -> (),
}

export type Ui = {
	gui: ScreenGui,
	draw: (state: LocalMeetRemotes.WarmUpState?) -> (),
}

local WIDTH, HEIGHT = 470, 214
local BOTTOM_GAP = 36

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

function LocalMeetWarmUpUI.build(handlers: Handlers): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "LocalMeetWarmUp"
	UIStyle.fitToScreen(gui)
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local holder, card = UIStyle.panel(gui, "Card", UDim2.new(0.5, -WIDTH / 2, 1, -HEIGHT - BOTTOM_GAP),
		UDim2.fromOffset(WIDTH, HEIGHT))
	UIStyle.titleTag(holder, "Tag", "WARM-UP", UDim2.fromOffset(-14, -24), UDim2.fromOffset(190, 40), nil, "bar")

	local state: LocalMeetRemotes.WarmUpState? = nil
	local selected = MeetConfig.LiftOrder[1]
	-- The weight chosen for each lift on this rack (kept while the player stays on it).
	local weights: { [string]: number } = {}
	local redraw: () -> ()

	local function bounds(lift: string): (number?, number?)
		local current = state
		local cn = current and current.competitionNumbers[lift]
		if current == nil or cn == nil then
			return nil, nil
		end
		return AttemptChoice.bounds(cn, current.stepKg)
	end

	local function weightFor(lift: string): number?
		local current = state
		local cn = current and current.competitionNumbers[lift]
		local minKg, maxKg = bounds(lift)
		if current == nil or cn == nil or minKg == nil or maxKg == nil then
			return nil
		end
		local kg = weights[lift]
		if kg == nil then
			kg = math.floor(cn * current.startPercent / current.stepKg + 1e-6) * current.stepKg
		end
		return math.clamp(kg :: number, minKg, maxKg)
	end

	local function nudge(stepKg: number)
		local kg = weightFor(selected)
		local minKg, maxKg = bounds(selected)
		if kg and minKg and maxKg then
			weights[selected] = math.clamp(kg + stepKg, minKg, maxKg)
			redraw()
		end
	end

	-- The lift buttons.
	local liftButtons: { [string]: TextButton } = {}
	for index, lift in ipairs(MeetConfig.LiftOrder) do
		liftButtons[lift] = UIStyle.button(card, "Lift_" .. lift, string.upper(lift),
			UDim2.fromOffset(18 + (index - 1) * 148, 24), UDim2.fromOffset(136, 34), "outline", function()
				selected = lift
				redraw()
			end)
	end

	-- The weight.
	local function stepButton(name: string, text: string, x: number, stepKg: number)
		UIStyle.button(card, name, text, UDim2.fromOffset(x, 74), UDim2.fromOffset(54, 34), "outline", function()
			local current = state
			if current then
				nudge(stepKg * current.stepKg)
			end
		end)
	end
	stepButton("Down4", "-10", 18, -4)
	stepButton("Down1", "-2.5", 76, -1)
	stepButton("Up1", "+2.5", 340, 1)
	stepButton("Up4", "+10", 398, 4)
	local weightLabel = UIStyle.label(card, "Weight", UDim2.fromOffset(136, 68), UDim2.fromOffset(198, 30), C.white,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	local percentLabel = UIStyle.label(card, "Percent", UDim2.fromOffset(136, 98), UDim2.fromOffset(198, 14), C.muted, nil,
		Enum.TextXAlignment.Center)

	-- The last result.
	local lastLabel = UIStyle.label(card, "Last", UDim2.fromOffset(18, 124), UDim2.new(1, -36, 0, 18), C.muted,
		UIStyle.heading())

	-- LIFT and LEAVE RACK.
	UIStyle.button(card, "LiftButton", "LIFT", UDim2.fromOffset(18, 154), UDim2.fromOffset(252, 42), "primary", function()
		local kg = weightFor(selected)
		local current = state
		if kg and current and not current.lifting then
			handlers.lift(selected, kg)
		end
	end)
	UIStyle.button(card, "Leave", "LEAVE RACK", UDim2.fromOffset(282, 154), UDim2.fromOffset(170, 42), "outline",
		handlers.leave)

	redraw = function()
		local current = state
		for lift, button in pairs(liftButtons) do
			local on = lift == selected
			button.BackgroundColor3 = if on then UIStyle.LiftColours[lift] or C.yellow else C.navyDeep
			button.TextColor3 = if on then C.ink else C.white
		end
		local kg = weightFor(selected)
		local cn = current and current.competitionNumbers[selected]
		if kg and cn then
			weightLabel.Text = kgText(kg) .. " KG"
			percentLabel.Text = string.format("%d%% OF YOUR %s CN (%s KG)", math.floor(kg / cn * 100 + 0.5),
				string.upper(selected), kgText(cn))
		else
			weightLabel.Text = "—"
			percentLabel.Text = "NO COMPETITION NUMBER FOR THIS LIFT YET"
		end
		local last = current and current.last
		if last then
			lastLabel.Text = string.format("LAST  %s %s KG  ·  %s", string.upper(last.lift), kgText(last.weightKg),
				if last.good then "GOOD LIFT" else "NO LIFT")
			lastLabel.TextColor3 = if last.good then C.white else C.red
		else
			lastLabel.Text = "PRACTICE ONLY  ·  NOTHING IS SAVED"
			lastLabel.TextColor3 = C.muted
		end
	end

	local ui = {} :: Ui
	ui.gui = gui
	ui.draw = function(newState: LocalMeetRemotes.WarmUpState?)
		local previousRack = state and state.rack
		state = newState
		local onRack = newState ~= nil and newState.rack ~= nil
		if not onRack or (newState and newState.rack ~= previousRack) then
			-- A new rack (or none): start each lift from its opener suggestion again.
			weights = {}
		end
		gui.Enabled = onRack and not (newState :: LocalMeetRemotes.WarmUpState).lifting
		redraw()
	end
	return ui
end

return LocalMeetWarmUpUI
