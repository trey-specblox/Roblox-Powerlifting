--!strict
--[[
	MockMeetUI
	Client / Meet

	Draws the Mock Meet on the player's screen from the server's state
	(MockMeetRemotes.MeetState); it decides nothing. MockMeetController owns it
	and wires its buttons and the weight box to the remotes. Built entirely from
	UIStyle, the game's one look. The Local meet uses the same screen with its
	own title (Options), plus a "Waiting" step, the referees' lights and a note.

		top left       the MOCK MEET tag; notices under it
		top right      LEAVE
		right          the SCORECARD panel: 3 lifts x 3 attempts, the class, the total
		bottom middle  the action panel: the weigh-in, the weight choice, LIFT,
		               the verdict, the result

	CHOOSING A WEIGHT (user 2026-10-29: "make this menu easier to read ... for
	new players"): the panel grows and shows YOUR CNs (all three, this lift's
	lit), this lift's attempts so far, the weight box (type a weight, Enter or
	CONFIRM), big lines for its % of CN, the jump from the last attempt and the
	allowed range, and QUICK PICK buttons at 90-125% of CN with their kg
	(dimmed when not allowed).

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
local MockMeetConfig = require(ConfigFolder:WaitForChild("MockMeetConfig"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local MockMeetUI = {}

export type Handlers = {
	leave: () -> (),
	-- A QUICK PICK button: choose exactly `kg`.
	set: (kg: number) -> (),
	-- The weight box's text changed; `submit` when the player pressed Enter.
	typed: (text: string, submit: boolean) -> (),
	confirm: () -> (),
	lift: () -> (),
}

-- What differs between the meets that use this screen (the Local meet passes its own).
export type Options = {
	guiName: string,
	tag: string,
	sub: string,
}

local MOCK_MEET_OPTIONS: Options = { guiName = "MockMeet", tag = "MOCK MEET", sub = "PRIVATE ROOM  ·  COACH WATCHING" }

export type Ui = {
	gui: ScreenGui,
	draw: (state: MockMeetRemotes.MeetState?, chosenKg: number?, problem: string?) -> (),
	setTimer: (secondsLeft: number?) -> (),
	notice: (text: string) -> (),
}

local ACTION_WIDTH, ACTION_TALL, ACTION_SHORT = 520, 230, 170
-- While choosing a weight the panel is bigger, so everything in it can be read at a glance.
local CHOOSE_WIDTH, CHOOSE_TALL = 660, 380
-- The QUICK PICK buttons: these shares of the lift's CN (inside the meet's 40-125%).
local QUICK_PICKS = { 0.90, 0.95, 1.00, 1.05, 1.10, 1.15, 1.20, 1.25 }
local WEIGHT_STEP_KG = MockMeetConfig.WeightStepKg
-- LIFT sits where CONFIRM was: it ignores clicks this long after it appears, so a double click cannot start the lift.
local LIFT_ARM_SECONDS = 0.8

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

-- The referees' lights as coloured dots for a RichText label ("White" or "Red" each).
local function lightDots(lights: { string }): string
	local dots = {}
	for _, light in ipairs(lights) do
		local colour = if light == "White" then C.white else C.red
		table.insert(dots, string.format('<font color="#%s">●</font>', colour:ToHex()))
	end
	return table.concat(dots, "  ")
end

function MockMeetUI.build(handlers: Handlers, options: Options?): Ui
	local look = options or MOCK_MEET_OPTIONS
	local gui = Instance.new("ScreenGui")
	gui.Name = look.guiName
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
	UIStyle.titleTag(title, "Tag", look.tag, UDim2.fromOffset(0, 0), UDim2.fromOffset(230, 44), nil, "star")
	UIStyle.label(title, "Sub", UDim2.fromOffset(16, 48), UDim2.fromOffset(200, 18), C.yellow, UIStyle.heading()).Text =
		look.sub

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
		UDim2.fromOffset(CHOOSE_WIDTH, CHOOSE_TALL))
	actionHolder.AnchorPoint = Vector2.new(0.5, 1)
	local stepTag = UIStyle.titleTag(actionHolder, "Tag", "", UDim2.fromOffset(-14, -24), UDim2.fromOffset(300, 40))
	local timer = UIStyle.frame(actionHolder, "Timer", UDim2.new(1, -92, 0, -20), UDim2.fromOffset(90, 38), C.yellow, 4)
	timer.ZIndex = 5
	local timerText = UIStyle.label(timer, "Text", UDim2.new(0, 6, 0.14, 0), UDim2.new(1, -12, 0.72, 0), C.ink,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	timerText.ZIndex = 5

	-- Choose: your CNs, this lift so far, the weight box with its lines, QUICK PICK and CONFIRM.
	local choose = Instance.new("Frame")
	choose.Name = "Choose"
	choose.BackgroundTransparency = 1
	choose.Size = UDim2.fromScale(1, 1)
	choose.Parent = action

	-- YOUR CNs: one chip per lift, the lift being chosen in its colour.
	UIStyle.sectionHead(choose, "NumbersHead", "YOUR CNs", UDim2.fromOffset(22, 28), 104, nil, "bar")
	local cnChips: { [string]: { chip: Frame, text: TextLabel } } = {}
	for index, lift in ipairs(MeetConfig.LiftOrder) do
		local chip = UIStyle.frame(choose, "CN_" .. lift, UDim2.fromOffset(170 + (index - 1) * 160, 22),
			UDim2.fromOffset(150, 32), C.navyDeep)
		UIStyle.stroke(chip, C.white, 1, 0.4)
		local text = UIStyle.label(chip, "Text", UDim2.new(0, 8, 0.16, 0), UDim2.new(1, -16, 0.68, 0), C.white,
			UIStyle.heading(), Enum.TextXAlignment.Center)
		cnChips[lift] = { chip = chip, text = text }
	end
	-- This lift's attempts so far, e.g. "THIS LIFT SO FAR   1ST 25 KG GOOD".
	local historyText = UIStyle.label(choose, "History", UDim2.fromOffset(22, 66), UDim2.new(1, -44, 0, 22), C.white,
		UIStyle.heading())
	historyText.RichText = true

	-- The weight box, left.
	UIStyle.sectionHead(choose, "Prompt", "YOUR WEIGHT", UDim2.fromOffset(22, 100), 120, nil, "dots")
	local box = Instance.new("TextBox")
	box.Name = "Weight"
	box.Position = UDim2.fromOffset(22, 126)
	box.Size = UDim2.fromOffset(220, 72)
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
	UIStyle.frame(choose, "Underline", UDim2.fromOffset(22, 198), UDim2.fromOffset(220, 3), C.yellow)
	UIStyle.label(choose, "Unit", UDim2.fromOffset(250, 150), UDim2.fromOffset(60, 40), C.yellow, UIStyle.heading()).Text = "KG"
	-- Its lines, big enough to read at a glance: the % of CN, the jump, the allowed range.
	local percentText = UIStyle.label(choose, "Percent", UDim2.fromOffset(22, 210), UDim2.fromOffset(300, 26), C.yellow,
		UIStyle.heading())
	local jumpText = UIStyle.label(choose, "Jump", UDim2.fromOffset(22, 240), UDim2.fromOffset(300, 22), C.white,
		UIStyle.heading())
	local rangeText = UIStyle.label(choose, "Range", UDim2.fromOffset(22, 266), UDim2.fromOffset(300, 22), C.muted,
		UIStyle.heading())

	-- QUICK PICK, right: a % of CN and its kg on each button.
	UIStyle.sectionHead(choose, "QuickHead", "QUICK PICK", UDim2.fromOffset(340, 100), 110, nil, "chevron")
	type Pick = { share: number, button: TextButton?, kg: number? }
	local picks: { Pick } = {}
	for index, share in ipairs(QUICK_PICKS) do
		local column = (index - 1) % 2
		local row = (index - 1) // 2
		local pick: Pick = { share = share, button = nil, kg = nil }
		pick.button = UIStyle.button(choose, "Pick_" .. index, "", UDim2.fromOffset(340 + column * 152, 128 + row * 40),
			UDim2.fromOffset(144, 34), "outline", function()
				if pick.kg then
					handlers.set(pick.kg)
				end
			end)
		table.insert(picks, pick)
	end

	local hint = UIStyle.label(choose, "Hint", UDim2.fromOffset(22, 296), UDim2.new(1, -44, 0, 18), C.muted)
	local confirm = UIStyle.button(choose, "Confirm", "CONFIRM", UDim2.new(0, 22, 1, -60), UDim2.new(1, -44, 0, 44),
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
		actionHolder.Size = if state.phase == "Choose" then UDim2.fromOffset(CHOOSE_WIDTH, CHOOSE_TALL)
			else UDim2.fromOffset(ACTION_WIDTH, if tall then ACTION_TALL else ACTION_SHORT)
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
		sub.RichText = false
		if state.phase == "Choose" then
			stepTag.Text = attemptText
			local lift = state.lift or ""
			local cn = state.competitionNumber[lift] or 0
			local kg = chosenKg
			if not box:IsFocused() then
				box.Text = if kg then kgText(kg) else ""
			end
			-- YOUR CNs.
			for chipLift, chip in pairs(cnChips) do
				local on = chipLift == lift
				local value = state.competitionNumber[chipLift]
				chip.text.Text = string.format("%s  %s", string.upper(chipLift), if value then kgText(value) .. " KG" else "—")
				chip.chip.BackgroundColor3 = if on then UIStyle.LiftColours[chipLift] or C.yellow else C.navyDeep
				chip.text.TextColor3 = if on then C.ink else C.white
			end
			-- This lift so far.
			local last: number? = nil
			local parts = {}
			for index, attempt in ipairs(state.attempts[lift] or {}) do
				local ordinal = ({ "1ST", "2ND", "3RD" })[index] or (tostring(index) .. "TH")
				local weightKg = attempt.weightKg
				if attempt.result == "Passed" or weightKg == nil then
					table.insert(parts, ordinal .. " PASSED")
				else
					local good = attempt.result == "GoodLift"
					local kgDone = weightKg :: number
					last = kgDone
					table.insert(parts, string.format('%s %s KG <font color="#%s">%s</font>', ordinal, kgText(kgDone),
						(if good then C.white else C.red):ToHex(), if good then "GOOD" else "NO LIFT"))
				end
			end
			historyText.Text = if #parts > 0 then "THIS LIFT SO FAR     " .. table.concat(parts, "     ")
				else "YOUR OPENER  ·  MOST LIFTERS OPEN AROUND 90% OF THEIR CN"
			-- The weight's lines.
			percentText.Text = if kg and cn > 0
				then string.format("%d%% OF YOUR %s CN", math.floor(kg / cn * 100 + 0.5), string.upper(lift))
				else ""
			if kg and last then
				local jump = kg - last
				jumpText.Text = if jump > 0 then string.format("+%s KG FROM LAST (%s KG)", kgText(jump), kgText(last))
					elseif jump == 0 then string.format("SAME AS LAST (%s KG)", kgText(last))
					else string.format("%s KG BELOW LAST (%s KG)", kgText(-jump), kgText(last))
			else
				jumpText.Text = ""
			end
			rangeText.Text = string.format("ALLOWED  %s – %s KG", kgText(state.minKg or 0), kgText(state.maxKg or 0))
			-- QUICK PICK: each share of CN on the meet's step; dimmed outside the allowed range.
			for _, pick in ipairs(picks) do
				local button = pick.button :: TextButton
				local pickKg = math.floor(cn * pick.share / WEIGHT_STEP_KG + 1e-6) * WEIGHT_STEP_KG
				local allowed = cn > 0 and pickKg >= (state.minKg or 0) - 1e-6 and pickKg <= (state.maxKg or math.huge) + 1e-6
				pick.kg = if allowed then pickKg else nil
				button.AutoButtonColor = allowed
				button.Text = string.format("%d%%  ·  %s KG", math.floor(pick.share * 100 + 0.5), kgText(pickKg))
				local selected = allowed and kg ~= nil and math.abs(pickKg - (kg :: number)) < 1e-6
				button.BackgroundColor3 = if selected then C.yellow else C.navyDeep
				button.TextColor3 = if selected then C.ink elseif allowed then C.white else C.muted
				button.TextTransparency = if allowed then 0 else 0.5
			end
			hint.Text = problem or "Type a weight or pick one, then press Enter or CONFIRM"
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
			-- The Local meet's referees' lights after the weight.
			sub.RichText = state.lights ~= nil
			sub.Text = kgText(state.declaredKg or 0) .. " kg" .. (if state.lights then "     " .. lightDots(state.lights) else "")
		elseif state.phase == "Waiting" then
			stepTag.Text = attemptText
			setBanner(if state.declaredKg then kgText(state.declaredKg) .. " KG DECLARED" else "PASSED", C.white, C.ink)
			sub.Text = state.note or "Waiting for the other lifters."
		elseif state.phase == "Done" then
			stepTag.Text = "MEET OVER"
			setBanner(if state.total then "TOTAL  " .. kgText(state.total) .. " KG" else "BOMBED OUT",
				if state.total then C.white else C.red, if state.total then C.ink else C.white)
			local best = state.best or {}
			local parts = {}
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				table.insert(parts, string.format("%s %s", string.upper(lift), if best[lift] then kgText(best[lift]) else "—"))
			end
			-- The server saves only a meet with a total (GAME_DESIGN 33.3b). A Local meet sends its place as the note.
			sub.Text = state.note or (table.concat(parts, "   ·   ")
				.. (if state.total then "     (proven lifts saved)" else "     (a bomb-out saves nothing)"))
		end
	end

	return ui
end

return MockMeetUI
