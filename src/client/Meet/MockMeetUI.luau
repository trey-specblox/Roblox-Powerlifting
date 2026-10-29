--!strict
--[[
	MockMeetUI
	Client / Meet

	Draws the Mock Meet on the player's screen from the server's state
	(MockMeetRemotes.MeetState); it decides nothing. MockMeetController owns it
	and wires its buttons and the weight box to the remotes.

	THE LOOK (user 2026-10-28: "ugly ... clean UIs" like their two example
	screenshots): bold, angled comic-style cards in black and white with the
	gym's competition red as the one accent. Every card is a slightly tilted
	black slab with a white slab peeking out behind it, a red tag cutting across
	its top edge and heavy italic type. A good lift is WHITE and a no lift is
	RED, like a meet's lights.

		top middle     MOCK MEET title; notices under it
		top right      LEAVE
		right          the scorecard: 3 lifts x 3 attempts, the class, the total
		bottom middle  the action card: the weigh-in, the weight box (type a
		               weight, Enter or CONFIRM; -5 -2.5 +2.5 +5 nudge it),
		               LIFT!, the verdict, the result
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetConfig"))
local MockMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("MockMeetRemotes"))

local MockMeetUI = {}

local FONT = "rbxasset://fonts/families/Montserrat.json"
local INK = Color3.fromRGB(12, 12, 14)
local PAPER = Color3.fromRGB(246, 245, 240)
local RED = Color3.fromRGB(218, 36, 44)
local EMPTY = Color3.fromRGB(38, 38, 44)
local MUTED = Color3.fromRGB(150, 150, 158)

export type Handlers = {
	leave: () -> (),
	-- A nudge button: change the weight by `deltaKg`.
	step: (deltaKg: number) -> (),
	-- The weight box's text changed; `submit` when the player pressed Enter.
	typed: (text: string, submit: boolean) -> (),
	confirm: () -> (),
	lift: () -> (),
}

export type Ui = {
	gui: ScreenGui,
	draw: (state: MockMeetRemotes.MeetState?, chosenKg: number?, problem: string?) -> (),
	setTimer: (secondsLeft: number?) -> (),
	notice: (text: string) -> (),
}

local function heavy(): Font
	return Font.new(FONT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
end

local function bold(): Font
	return Font.new(FONT, Enum.FontWeight.Bold, Enum.FontStyle.Italic)
end

-- A flat, sharp-cornered slab: the building block of every card, tag and chip.
local function slab(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3, rotation: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	frame.Parent = parent
	return frame
end

local function label(parent: Instance, name: string, position: UDim2, size: UDim2, colour: Color3, font: Font,
	align: Enum.TextXAlignment?): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Text = ""
	text.TextColor3 = colour
	text.TextScaled = true
	text.FontFace = font
	text.TextXAlignment = align or Enum.TextXAlignment.Left
	text.Parent = parent
	return text
end

-- A slab that is a button: `text` in heavy italic, `ink` on `colour`.
local function slabButton(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, colour: Color3,
	ink: Color3, rotation: number?, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = colour
	button.BorderSizePixel = 0
	button.Rotation = rotation or 0
	button.AutoButtonColor = true
	button.Text = text
	button.TextColor3 = ink
	button.TextScaled = true
	button.FontFace = heavy()
	button.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = button
	button.Activated:Connect(onClick)
	return button
end

--[[
	A card: a white slab behind, offset down-right, and the black slab in front;
	both tilted by `rotation`. Returns the holder (place and size it) and the
	front slab (put the content in it).
]]
local function card(parent: Instance, name: string, rotation: number): (Frame, Frame)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	slab(holder, "Back", UDim2.fromOffset(9, 9), UDim2.fromScale(1, 1), PAPER, rotation)
	local front = slab(holder, "Front", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), INK, rotation)
	return holder, front
end

-- A red tag cutting across the top-left edge of a card.
local function tag(parent: Instance, name: string, position: UDim2, size: UDim2, rotation: number): TextLabel
	local back = slab(parent, name, position, size, RED, rotation)
	back.ZIndex = 3
	local text = label(back, "Text", UDim2.new(0, 12, 0.14, 0), UDim2.new(1, -24, 0.72, 0), PAPER, heavy())
	text.ZIndex = 3
	return text
end

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

function MockMeetUI.build(handlers: Handlers): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "MockMeet"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	-- ------------------------------------------------ title, notice, leave
	local title = slab(gui, "Title", UDim2.new(0.5, -150, 0, 14), UDim2.fromOffset(300, 46), INK, -2)
	label(title, "Text", UDim2.new(0, 16, 0.16, 0), UDim2.new(1, -110, 0.68, 0), PAPER, heavy()).Text = "MOCK MEET"
	local private = slab(title, "Private", UDim2.new(1, -104, 0, -8), UDim2.fromOffset(112, 26), RED, 5)
	label(private, "Text", UDim2.new(0, 8, 0.12, 0), UDim2.new(1, -16, 0.76, 0), PAPER, bold(),
		Enum.TextXAlignment.Center).Text = "PRIVATE ROOM"

	local noticeSlab = slab(gui, "Notice", UDim2.new(0.5, -240, 0, 72), UDim2.fromOffset(480, 34), PAPER, 1.5)
	noticeSlab.Visible = false
	local noticeText = label(noticeSlab, "Text", UDim2.new(0, 14, 0.16, 0), UDim2.new(1, -28, 0.68, 0), INK, bold(),
		Enum.TextXAlignment.Center)

	slabButton(gui, "Leave", "LEAVE",UDim2.new(1, -150, 0, 16), UDim2.fromOffset(130, 40), INK, PAPER, -3, handlers.leave)

	-- ------------------------------------------------ scorecard
	local scoreHolder, score = card(gui, "Scorecard", 2)
	scoreHolder.AnchorPoint = Vector2.new(1, 0.5)
	scoreHolder.Position = UDim2.new(1, -28, 0.46, 0)
	scoreHolder.Size = UDim2.fromOffset(312, 236)
	tag(scoreHolder, "Tag", UDim2.fromOffset(-12, -18), UDim2.fromOffset(170, 36), -4).Text = "SCORECARD"
	local classText = label(score, "Class", UDim2.fromOffset(18, 26), UDim2.new(1, -36, 0, 22), MUTED, bold())
	local chips: { [string]: { Frame } } = {}
	for row, lift in ipairs(MeetConfig.LiftOrder) do
		local y = 58 + (row - 1) * 44
		label(score, lift .. "_Name", UDim2.fromOffset(18, y + 7), UDim2.fromOffset(86, 22), PAPER, heavy()).Text =
			string.upper(lift)
		chips[lift] = {}
		for column = 1, MeetConfig.AttemptsPerLift do
			local chip = slab(score, string.format("%s_%d", lift, column), UDim2.fromOffset(110 + (column - 1) * 64, y),
				UDim2.fromOffset(58, 34), EMPTY, -6)
			local stroke = Instance.new("UIStroke")
			stroke.Name = "Current"
			stroke.Color = PAPER
			stroke.Thickness = 2
			stroke.Enabled = false
			stroke.Parent = chip
			label(chip, "Text", UDim2.new(0, 4, 0.16, 0), UDim2.new(1, -8, 0.68, 0), MUTED, heavy(), Enum.TextXAlignment.Center)
			chips[lift][column] = chip
		end
	end
	slab(score, "Rule", UDim2.new(0, 18, 1, -52), UDim2.new(1, -36, 0, 3), RED)
	local totalName = label(score, "TotalName", UDim2.new(0, 18, 1, -42), UDim2.fromOffset(120, 26), MUTED, bold())
	local totalValue = label(score, "TotalValue", UDim2.new(1, -168, 1, -46), UDim2.fromOffset(150, 34), PAPER, heavy(),
		Enum.TextXAlignment.Right)

	-- ------------------------------------------------ the action card
	local actionHolder, action = card(gui, "Action", -2)
	actionHolder.AnchorPoint = Vector2.new(0.5, 1)
	actionHolder.Position = UDim2.new(0.5, 0, 1, -30)
	actionHolder.Size = UDim2.fromOffset(500, 214)
	local stepTag = tag(actionHolder, "Tag", UDim2.fromOffset(-14, -20), UDim2.fromOffset(270, 40), -5)
	local timerSlab = slab(actionHolder, "Timer", UDim2.new(1, -78, 0, -18), UDim2.fromOffset(86, 40), PAPER, 6)
	timerSlab.ZIndex = 3
	local timerText = label(timerSlab, "Text", UDim2.new(0, 6, 0.12, 0), UDim2.new(1, -12, 0.76, 0), INK, heavy(),
		Enum.TextXAlignment.Center)
	timerText.ZIndex = 3

	-- Choose: the weight box, the nudges, the hint and CONFIRM.
	local choose = Instance.new("Frame")
	choose.Name = "Choose"
	choose.BackgroundTransparency = 1
	choose.Size = UDim2.fromScale(1, 1)
	choose.Parent = action
	label(choose, "Prompt", UDim2.fromOffset(24, 30), UDim2.fromOffset(240, 20), MUTED, bold()).Text = "TYPE YOUR WEIGHT"
	local percentText = label(choose, "Percent", UDim2.new(1, -224, 0, 30), UDim2.fromOffset(200, 20), MUTED, bold(),
		Enum.TextXAlignment.Right)
	local box = Instance.new("TextBox")
	box.Name = "Weight"
	box.Position = UDim2.fromOffset(22, 52)
	box.Size = UDim2.fromOffset(190, 66)
	box.BackgroundTransparency = 1
	box.ClearTextOnFocus = false
	box.Text = ""
	box.PlaceholderText = "0"
	box.PlaceholderColor3 = MUTED
	box.TextColor3 = PAPER
	box.TextScaled = true
	box.FontFace = heavy()
	box.TextXAlignment = Enum.TextXAlignment.Right
	box.Parent = choose
	slab(choose, "Underline", UDim2.fromOffset(22, 120), UDim2.fromOffset(190, 4), RED)
	label(choose, "Unit", UDim2.fromOffset(220, 74), UDim2.fromOffset(60, 40), RED, heavy()).Text = "KG"
	for index, delta in ipairs({ -5, 5, -2.5, 2.5 }) do
		local column = (index - 1) % 2
		local row = (index - 1) // 2
		slabButton(choose, "Nudge_" .. index, (if delta > 0 then "+" else "−") .. kgText(math.abs(delta)),
			UDim2.new(1, -196 + column * 90, 0, 54 + row * 36), UDim2.fromOffset(82, 30), PAPER, INK, -3, function()
				handlers.step(delta)
			end)
	end
	local hint = label(choose, "Hint", UDim2.fromOffset(24, 132), UDim2.new(1, -48, 0, 20), MUTED, bold())
	local confirm = slabButton(choose, "Confirm", "CONFIRM  ▶", UDim2.new(0, 22, 1, -52), UDim2.new(1, -44, 0, 40), RED,
		PAPER, 0, handlers.confirm)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if box:IsFocused() then
			handlers.typed(box.Text, false)
		end
	end)
	box.FocusLost:Connect(function(enterPressed)
		handlers.typed(box.Text, enterPressed)
	end)

	-- Everything else: a big line, a sub-line and (Ready) the LIFT button.
	local show = Instance.new("Frame")
	show.Name = "Show"
	show.BackgroundTransparency = 1
	show.Size = UDim2.fromScale(1, 1)
	show.Parent = action
	local verdictSlab = slab(show, "Verdict", UDim2.fromOffset(24, 34), UDim2.new(1, -48, 0, 74), PAPER, -3)
	local big = label(verdictSlab, "Big", UDim2.new(0, 14, 0.1, 0), UDim2.new(1, -28, 0.8, 0), INK, heavy(),
		Enum.TextXAlignment.Center)
	local sub = label(show, "Sub", UDim2.fromOffset(24, 120), UDim2.new(1, -48, 0, 24), PAPER, bold(), Enum.TextXAlignment.Center)
	--[[
		LIFT sits where CONFIRM was, so a double click on CONFIRM must not also start
		the lift: LIFT ignores clicks for LIFT_ARM_SECONDS after it appears (and
		looks faded until then).
	]]
	local LIFT_ARM_SECONDS = 0.8
	local liftArmedAt = 0
	local liftButton = slabButton(show, "Lift", "LIFT!", UDim2.new(0, 22, 1, -60), UDim2.new(1, -44, 0, 48), RED, PAPER, 0,
		function()
			if os.clock() >= liftArmedAt then
				handlers.lift()
			end
		end)

	-- ------------------------------------------------ drawing
	local noticeToken = 0
	local ui = {} :: Ui
	ui.gui = gui

	ui.notice = function(message: string)
		noticeToken += 1
		local token = noticeToken
		noticeText.Text = message
		noticeSlab.Visible = true
		task.delay(4, function()
			if noticeToken == token then
				noticeSlab.Visible = false
			end
		end)
	end

	ui.setTimer = function(secondsLeft: number?)
		timerSlab.Visible = secondsLeft ~= nil
		if secondsLeft then
			local whole = math.max(0, math.ceil(secondsLeft))
			timerText.Text = string.format("%d:%02d", whole // 60, whole % 60)
			timerSlab.BackgroundColor3 = if whole <= 10 then RED else PAPER
			timerText.TextColor3 = if whole <= 10 then PAPER else INK
		end
	end

	local function drawScorecard(state: MockMeetRemotes.MeetState, chosenKg: number?)
		classText.Text = string.format("%s CLASS  ·  %.1f KG", string.upper(state.classLabel), state.bodyweightKg)
		local subtotal = 0
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			local taken = state.attempts[lift] or {}
			local best = 0
			for column, chip in ipairs(chips[lift]) do
				local attempt = taken[column]
				local current = state.lift == lift and state.attemptNumber == column and state.phase ~= "Done"
				local text = chip:FindFirstChild("Text") :: TextLabel
				local stroke = chip:FindFirstChild("Current") :: UIStroke
				stroke.Enabled = current and attempt == nil
				if attempt and attempt.result == "Passed" then
					chip.BackgroundColor3, text.TextColor3, text.Text = EMPTY, MUTED, "PASS"
				elseif attempt then
					local good = attempt.result == "GoodLift"
					chip.BackgroundColor3 = if good then PAPER else RED
					text.TextColor3 = if good then INK else PAPER
					text.Text = kgText(attempt.weightKg)
					if good and attempt.weightKg > best then
						best = attempt.weightKg
					end
				elseif current and (state.declaredKg or chosenKg) then
					chip.BackgroundColor3, text.TextColor3 = INK, PAPER
					text.Text = kgText((state.declaredKg or chosenKg) :: number)
				else
					chip.BackgroundColor3, text.TextColor3, text.Text = EMPTY, MUTED, "—"
				end
			end
			subtotal += best
		end
		if state.phase == "Done" then
			totalName.Text = "TOTAL"
			totalValue.Text = if state.total then kgText(state.total) .. " KG" else "BOMBED OUT"
			totalValue.TextColor3 = if state.total then PAPER else RED
		else
			totalName.Text = "SUBTOTAL"
			totalValue.Text = kgText(subtotal) .. " KG"
			totalValue.TextColor3 = PAPER
		end
	end

	ui.draw = function(state: MockMeetRemotes.MeetState?, chosenKg: number?, problem: string?)
		if state == nil then
			return
		end
		drawScorecard(state, chosenKg)

		actionHolder.Visible = state.phase ~= "Lifting"
		-- Only the weight box and LIFT need the tall card.
		actionHolder.Size = UDim2.fromOffset(500, if state.phase == "Choose" or state.phase == "Ready" then 214 else 162)
		choose.Visible = state.phase == "Choose"
		show.Visible = state.phase ~= "Choose"
		if state.phase == "Ready" and not liftButton.Visible then
			liftArmedAt = os.clock() + LIFT_ARM_SECONDS
			liftButton.BackgroundTransparency = 0.55
			task.delay(LIFT_ARM_SECONDS, function()
				liftButton.BackgroundTransparency = 0
			end)
		end
		liftButton.Visible = state.phase == "Ready"
		local liftName = string.upper(state.lift or "")
		local attemptText = string.format("%s  ·  ATTEMPT %d", liftName, state.attemptNumber or 1)

		if state.phase == "Choose" then
			stepTag.Text = attemptText
			local cn = state.competitionNumber[state.lift or ""] or 0
			local kg = chosenKg
			if not box:IsFocused() then
				box.Text = if kg then kgText(kg) else ""
			end
			percentText.Text = if kg and cn > 0
				then string.format("%d%% OF YOUR CN (%s KG)", math.floor(kg / cn * 100 + 0.5), kgText(cn))
				else ""
			hint.Text = problem or string.format("Allowed: %s – %s kg.  Enter or CONFIRM to declare.",
				kgText(state.minKg or 0), kgText(state.maxKg or 0))
			hint.TextColor3 = if problem then RED else MUTED
			confirm.BackgroundTransparency = if problem or kg == nil then 0.55 else 0
		elseif state.phase == "WeighIn" then
			stepTag.Text = "WEIGH-IN"
			verdictSlab.BackgroundColor3, big.TextColor3 = PAPER, INK
			big.Text = string.format("%.1f KG", state.bodyweightKg)
			sub.Text = string.format("You lift in the %s class today.", state.classLabel)
		elseif state.phase == "Ready" then
			stepTag.Text = attemptText
			verdictSlab.BackgroundColor3, big.TextColor3 = PAPER, INK
			big.Text = "BAR LOADED  ·  " .. kgText(state.declaredKg or 0) .. " KG"
			sub.Text = "Your coach is watching. Press LIFT when you are ready."
		elseif state.phase == "Result" then
			stepTag.Text = attemptText
			local good = state.verdict == "GoodLift"
			verdictSlab.BackgroundColor3 = if good then PAPER else RED
			big.TextColor3 = if good then INK else PAPER
			big.Text = if good then "GOOD LIFT" else "NO LIFT"
			sub.Text = kgText(state.declaredKg or 0) .. " kg"
		elseif state.phase == "Done" then
			stepTag.Text = "MEET OVER"
			verdictSlab.BackgroundColor3 = if state.total then PAPER else RED
			big.TextColor3 = if state.total then INK else PAPER
			big.Text = if state.total then "TOTAL  " .. kgText(state.total) .. " KG" else "BOMBED OUT"
			local best = state.best or {}
			local parts = {}
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				table.insert(parts, string.format("%s %s", string.upper(lift), if best[lift] then kgText(best[lift]) else "—"))
			end
			sub.Text = table.concat(parts, "   ·   ") .. "     (nothing is saved yet)"
		end
	end

	return ui
end

return MockMeetUI
