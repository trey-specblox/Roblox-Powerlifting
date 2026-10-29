--!strict
--[[
	MockMeetUI
	Client / Meet

	Draws the Mock Meet on the player's screen from the server's state
	(MockMeetRemotes.MeetState); it decides nothing. MockMeetController owns it
	and wires its buttons and the weight box to the remotes. Built entirely from
	UIStyle, the game's one look.

		top left       the MOCK MEET tag; notices under it
		top right      LEAVE
		right          the SCORECARD panel: 3 lifts x 3 attempts, the class, the total
		bottom middle  the action panel: the weigh-in, the weight box (type a
		               weight, Enter or CONFIRM; -5 -2.5 +2.5 +5 nudge it),
		               LIFT, the verdict, the result

	NO OVERLAP WITH THE LIFT (user 2026-10-28: "UIs overlap ... a BIG no"). The
	lift's minigames and their own verdict use the middle of the screen. The
	action panel hides while a lift runs AND while the lift's own verdict is
	still showing (LiftAttemptConfig.ResultHoldSeconds); only then does the
	meet's verdict appear.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local LiftAttemptConfig = require(ConfigFolder:WaitForChild("LiftAttemptConfig"))
local MockMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("MockMeetRemotes"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local MockMeetUI = {}

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

local ACTION_WIDTH, ACTION_TALL, ACTION_SHORT = 520, 230, 170
-- LIFT sits where CONFIRM was: it ignores clicks this long after it appears, so a double click cannot start the lift.
local LIFT_ARM_SECONDS = 0.8

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

function MockMeetUI.build(handlers: Handlers): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "MockMeet"
	UIStyle.fitToScreen(gui) -- shrink on short screens so nothing overlaps
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	-- ------------------------------------------------ title, notice, leave
	local title = Instance.new("Frame")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 18)
	title.Size = UDim2.fromOffset(260, 70)
	title.Parent = gui
	UIStyle.titleTag(title, "Tag", "MOCK MEET", UDim2.fromOffset(0, 0), UDim2.fromOffset(230, 44), nil, "star")
	UIStyle.label(title, "Sub", UDim2.fromOffset(16, 48), UDim2.fromOffset(200, 18), C.yellow, UIStyle.heading()).Text =
		"PRIVATE ROOM  ·  COACH WATCHING"

	local notice = UIStyle.frame(gui, "Notice", UDim2.fromOffset(24, 96), UDim2.fromOffset(420, 34), C.ink, -1)
	UIStyle.stroke(notice, C.yellow, 2)
	notice.Visible = false
	local noticeText = UIStyle.label(notice, "Text", UDim2.new(0, 12, 0.16, 0), UDim2.new(1, -24, 0.68, 0), C.white)

	UIStyle.exitButton(gui, "Leave", "LEAVE", UDim2.new(1, -194, 0, 22), handlers.leave)

	-- ------------------------------------------------ scorecard
	local scoreHolder, score = UIStyle.panel(gui, "Scorecard", UDim2.new(1, -350, 0.5, -130), UDim2.fromOffset(320, 252))
	UIStyle.titleTag(scoreHolder, "Tag", "SCORECARD", UDim2.fromOffset(-14, -24), UDim2.fromOffset(190, 38), nil, "corner")
	local classText = UIStyle.label(score, "Class", UDim2.fromOffset(18, 24), UDim2.new(1, -36, 0, 18), C.muted)
	local cells: { [string]: { TextLabel } } = {}
	for row, lift in ipairs(MeetConfig.LiftOrder) do
		local y = 54 + (row - 1) * 46
		local name = UIStyle.label(score, lift .. "_Name", UDim2.fromOffset(18, y + 8), UDim2.fromOffset(92, 20), C.white,
			UIStyle.heading())
		name.Text = string.upper(lift)
		UIStyle.frame(score, lift .. "_Mark", UDim2.fromOffset(18, y + 31), UDim2.fromOffset(24, 3),
			UIStyle.LiftColours[lift] or C.yellow)
		cells[lift] = {}
		for column = 1, MeetConfig.AttemptsPerLift do
			local cell = UIStyle.label(score, string.format("%s_%d", lift, column),
				UDim2.fromOffset(116 + (column - 1) * 64, y), UDim2.fromOffset(58, 36), C.muted, UIStyle.heading(),
				Enum.TextXAlignment.Center)
			cell.BackgroundTransparency = 0
			cell.BackgroundColor3 = C.empty
			local edge = UIStyle.stroke(cell, C.white, 1, 0.6)
			edge.Name = "Edge"
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 8)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.Parent = cell
			cells[lift][column] = cell
		end
	end
	UIStyle.frame(score, "Rule", UDim2.new(0, 18, 1, -54), UDim2.new(1, -36, 0, 2), C.white)
	local totalName = UIStyle.label(score, "TotalName", UDim2.new(0, 18, 1, -42), UDim2.fromOffset(130, 22), C.yellow,
		UIStyle.heading())
	local totalValue = UIStyle.label(score, "TotalValue", UDim2.new(1, -170, 1, -46), UDim2.fromOffset(152, 30), C.white,
		UIStyle.heading(), Enum.TextXAlignment.Right)

	-- ------------------------------------------------ the action panel
	-- Placed by its bottom middle, so it grows upward and stays centred when it changes height or shrinks.
	local actionHolder, action = UIStyle.panel(gui, "Action", UDim2.new(0.5, 0, 1, -30),
		UDim2.fromOffset(ACTION_WIDTH, ACTION_TALL))
	actionHolder.AnchorPoint = Vector2.new(0.5, 1)
	local stepTag = UIStyle.titleTag(actionHolder, "Tag", "", UDim2.fromOffset(-14, -24), UDim2.fromOffset(300, 40))
	local timer = UIStyle.frame(actionHolder, "Timer", UDim2.new(1, -92, 0, -20), UDim2.fromOffset(90, 38), C.yellow, 4)
	timer.ZIndex = 5
	local timerText = UIStyle.label(timer, "Text", UDim2.new(0, 6, 0.14, 0), UDim2.new(1, -12, 0.72, 0), C.ink,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	timerText.ZIndex = 5

	-- Choose: the weight box, the nudges, the hint and CONFIRM.
	local choose = Instance.new("Frame")
	choose.Name = "Choose"
	choose.BackgroundTransparency = 1
	choose.Size = UDim2.fromScale(1, 1)
	choose.Parent = action
	UIStyle.sectionHead(choose, "Prompt", "TYPE YOUR WEIGHT", UDim2.fromOffset(22, 26), 168, nil, "dots")
	local percentText = UIStyle.label(choose, "Percent", UDim2.new(1, -236, 0, 28), UDim2.fromOffset(214, 16), C.muted,
		nil, Enum.TextXAlignment.Right)
	local box = Instance.new("TextBox")
	box.Name = "Weight"
	box.Position = UDim2.fromOffset(22, 54)
	box.Size = UDim2.fromOffset(200, 66)
	box.BackgroundColor3 = C.navyDeep
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Text = ""
	box.PlaceholderText = "0"
	box.PlaceholderColor3 = C.muted
	box.TextColor3 = C.white
	box.TextScaled = true
	box.FontFace = UIStyle.heading()
	box.TextXAlignment = Enum.TextXAlignment.Right
	box.Parent = choose
	UIStyle.stroke(box, C.white, 1, 0.4)
	local boxPadding = Instance.new("UIPadding")
	boxPadding.PaddingTop = UDim.new(0, 8)
	boxPadding.PaddingBottom = UDim.new(0, 8)
	boxPadding.PaddingRight = UDim.new(0, 10)
	boxPadding.Parent = box
	UIStyle.frame(choose, "Underline", UDim2.fromOffset(22, 120), UDim2.fromOffset(200, 3), C.yellow)
	UIStyle.label(choose, "Unit", UDim2.fromOffset(230, 78), UDim2.fromOffset(56, 38), C.yellow, UIStyle.heading()).Text = "KG"
	for index, delta in ipairs({ -5, 5, -2.5, 2.5 }) do
		local column = (index - 1) % 2
		local row = (index - 1) // 2
		UIStyle.button(choose, "Nudge_" .. index, (if delta > 0 then "+" else "−") .. kgText(math.abs(delta)),
			UDim2.new(1, -206 + column * 96, 0, 56 + row * 36), UDim2.fromOffset(88, 30), "outline", function()
				handlers.step(delta)
			end)
	end
	local hint = UIStyle.label(choose, "Hint", UDim2.fromOffset(22, 132), UDim2.new(1, -44, 0, 18), C.muted)
	local confirm = UIStyle.button(choose, "Confirm", "CONFIRM", UDim2.new(0, 22, 1, -60), UDim2.new(1, -44, 0, 42),
		"primary", handlers.confirm)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if box:IsFocused() then
			handlers.typed(box.Text, false)
		end
	end)
	box.FocusLost:Connect(function(enterPressed)
		handlers.typed(box.Text, enterPressed)
	end)

	-- Everything else: a big banner, a line under it and (Ready) LIFT.
	local show = Instance.new("Frame")
	show.Name = "Show"
	show.BackgroundTransparency = 1
	show.Size = UDim2.fromScale(1, 1)
	show.Parent = action
	local banner = UIStyle.frame(show, "Banner", UDim2.fromOffset(22, 32), UDim2.new(1, -44, 0, 70), C.white, -2)
	local bannerText = UIStyle.label(banner, "Text", UDim2.new(0, 14, 0.12, 0), UDim2.new(1, -28, 0.76, 0), C.ink,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	local sub = UIStyle.label(show, "Sub", UDim2.fromOffset(22, 114), UDim2.new(1, -44, 0, 22), C.white, nil,
		Enum.TextXAlignment.Center)
	local liftArmedAt = 0
	local liftButton = UIStyle.button(show, "Lift", "LIFT!", UDim2.new(0, 22, 1, -66), UDim2.new(1, -44, 0, 48), "primary",
		function()
			if os.clock() >= liftArmedAt then
				handlers.lift()
			end
		end)

	-- ------------------------------------------------ drawing
	local ui = {} :: Ui
	ui.gui = gui

	local noticeToken = 0
	ui.notice = function(message: string)
		noticeToken += 1
		local token = noticeToken
		noticeText.Text = message
		notice.Visible = true
		task.delay(4, function()
			if noticeToken == token then
				notice.Visible = false
			end
		end)
	end

	ui.setTimer = function(secondsLeft: number?)
		timer.Visible = secondsLeft ~= nil
		if secondsLeft then
			local whole = math.max(0, math.ceil(secondsLeft))
			timerText.Text = string.format("%d:%02d", whole // 60, whole % 60)
			timer.BackgroundColor3 = if whole <= 10 then C.red else C.yellow
			timerText.TextColor3 = if whole <= 10 then C.white else C.ink
		end
	end

	local function drawScorecard(state: MockMeetRemotes.MeetState, chosenKg: number?)
		classText.Text = string.format("%s CLASS  ·  %.1f KG BODYWEIGHT", string.upper(state.classLabel), state.bodyweightKg)
		local subtotal = 0
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			local taken = state.attempts[lift] or {}
			local best = 0
			for column, cell in ipairs(cells[lift]) do
				local attempt = taken[column]
				local current = state.lift == lift and state.attemptNumber == column and state.phase ~= "Done"
				local edge = cell:FindFirstChild("Edge") :: UIStroke
				edge.Color = if current and attempt == nil then C.yellow else C.white
				edge.Thickness = if current and attempt == nil then 2 else 1
				edge.Transparency = if current and attempt == nil then 0 else 0.6
				if attempt and attempt.result == "Passed" then
					cell.BackgroundColor3, cell.TextColor3, cell.Text = C.empty, C.muted, "PASS"
				elseif attempt then
					local good = attempt.result == "GoodLift"
					cell.BackgroundColor3 = if good then C.white else C.red
					cell.TextColor3 = if good then C.ink else C.white
					cell.Text = kgText(attempt.weightKg)
					if good and attempt.weightKg > best then
						best = attempt.weightKg
					end
				elseif current and (state.declaredKg or chosenKg) then
					cell.BackgroundColor3, cell.TextColor3 = C.navyDeep, C.yellow
					cell.Text = kgText((state.declaredKg or chosenKg) :: number)
				else
					cell.BackgroundColor3, cell.TextColor3, cell.Text = C.empty, C.muted, "—"
				end
			end
			subtotal += best
		end
		if state.phase == "Done" then
			totalName.Text = "TOTAL"
			totalValue.Text = if state.total then kgText(state.total) .. " KG" else "BOMBED OUT"
			totalValue.TextColor3 = if state.total then C.white else C.red
		else
			totalName.Text = "SUBTOTAL"
			totalValue.Text = kgText(subtotal) .. " KG"
			totalValue.TextColor3 = C.white
		end
	end

	local function setBanner(text: string, background: Color3, ink: Color3)
		bannerText.Text = text
		banner.BackgroundColor3 = background
		bannerText.TextColor3 = ink
	end

	-- Bumped by every draw, so a delayed reveal of the action panel never shows an old phase.
	local drawToken = 0
	local lastPhase = ""
	ui.draw = function(state: MockMeetRemotes.MeetState?, chosenKg: number?, problem: string?)
		if state == nil then
			return
		end
		drawToken += 1
		local token = drawToken
		drawScorecard(state, chosenKg)

		local tall = state.phase == "Choose" or state.phase == "Ready"
		actionHolder.Size = UDim2.fromOffset(ACTION_WIDTH, if tall then ACTION_TALL else ACTION_SHORT)
		choose.Visible = state.phase == "Choose"
		show.Visible = state.phase ~= "Choose"
		if state.phase == "Ready" and lastPhase ~= "Ready" then
			liftArmedAt = os.clock() + LIFT_ARM_SECONDS
			liftButton.BackgroundTransparency = 0.55
			task.delay(LIFT_ARM_SECONDS, function()
				liftButton.BackgroundTransparency = 0
			end)
		end
		liftButton.Visible = state.phase == "Ready"

		-- Hidden while lifting, and while the lift's own verdict is still on screen.
		if state.phase == "Lifting" then
			actionHolder.Visible = false
		elseif state.phase == "Result" and lastPhase ~= "Result" then
			actionHolder.Visible = false
			task.delay(LiftAttemptConfig.ResultHoldSeconds, function()
				if drawToken == token then
					actionHolder.Visible = true
				end
			end)
		elseif state.phase ~= "Result" then
			actionHolder.Visible = true
		end
		lastPhase = state.phase

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
			hint.Text = problem or string.format("Allowed %s – %s kg  ·  Enter or CONFIRM to declare",
				kgText(state.minKg or 0), kgText(state.maxKg or 0))
			hint.TextColor3 = if problem then C.red else C.muted
			confirm.BackgroundTransparency = if problem or kg == nil then 0.5 else 0
		elseif state.phase == "WeighIn" then
			stepTag.Text = "WEIGH-IN"
			setBanner(string.format("%.1f KG", state.bodyweightKg), C.white, C.ink)
			sub.Text = string.format("You lift in the %s class today.", state.classLabel)
		elseif state.phase == "Ready" then
			stepTag.Text = attemptText
			setBanner("BAR LOADED  ·  " .. kgText(state.declaredKg or 0) .. " KG", C.white, C.ink)
			sub.Text = "Your coach is watching. Press LIFT when you are ready."
		elseif state.phase == "Result" then
			stepTag.Text = attemptText
			local good = state.verdict == "GoodLift"
			setBanner(if good then "GOOD LIFT" else "NO LIFT", if good then C.white else C.red, if good then C.ink else C.white)
			sub.Text = kgText(state.declaredKg or 0) .. " kg"
		elseif state.phase == "Done" then
			stepTag.Text = "MEET OVER"
			setBanner(if state.total then "TOTAL  " .. kgText(state.total) .. " KG" else "BOMBED OUT",
				if state.total then C.white else C.red, if state.total then C.ink else C.white)
			local best = state.best or {}
			local parts = {}
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				table.insert(parts, string.format("%s %s", string.upper(lift), if best[lift] then kgText(best[lift]) else "—"))
			end
			-- The server saves only a meet with a total (GAME_DESIGN 33.3b).
			sub.Text = table.concat(parts, "   ·   ")
				.. (if state.total then "     (proven lifts saved)" else "     (a bomb-out saves nothing)")
		end
	end

	return ui
end

return MockMeetUI
