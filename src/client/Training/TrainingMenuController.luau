--!strict
--[[
	TrainingMenuController
	Client / Training

	The training racks' menu (checkpoints 5B.6 and 5B.7), built from UIStyle,
	the game's one look (user 2026-10-28: the rack menu as a "select your goal"
	panel): a navy grid panel titled SELECT YOUR GOAL with the rack's name,
	sections WHAT TO TRAIN // LIFT // PRIMARY STAT with outline buttons (the
	chosen one yellow), the details, START (yellow) and STOP (red), and EXIT.
	The small status strip at the top shows while the player holds a rack
	with the menu closed. Only the look changed in the restyle: every request,
	the state handling and the texts' meaning are as before.

	Technique has NO earning cap, so the menu never shows a technique "today",
	"remaining" or countdown -- only the rate, the split, the current raw and
	effective values, and what this rack session has earned. The CN daily
	allowance line stays, because CN does have a daily cap.

	It DECIDES NOTHING. The server opens the menu (after the player holds E at a
	rack it has validated), and every button press is only a request:

		Start Training  -> "Start", { mode, lift, primary? }
		Stop Training   -> "Stop"
		Close           -> "Close"

	What the menu and the status bar show comes from the server's
	TrainingMenuState messages. The choice being built up before Start is the
	only thing kept locally.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local TechniqueTraining = require(ProgressionFolder:WaitForChild("TechniqueTraining"))

local TrainingFolder = Shared:WaitForChild("Training")
local TrainingRemotes = require(TrainingFolder:WaitForChild("TrainingRemotes"))
local TrainingStationRules = require(TrainingFolder:WaitForChild("TrainingStationRules"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local TrainingMenuController = {}

local PANEL_WIDTH, PANEL_HEIGHT = 660, 640 -- the height is the largest; the panel shrinks to fit (refreshMenu)
local CONTENT_PADDING = 30 + 18 -- the content's top and bottom padding
local LIST_GAP = 8

local NOTICE_SECONDS = 8

-- The choice being built before Start. Local only; the server re-validates it.
local chosenMode: TrainingStationRules.Mode = "CN"
local chosenLift: string = "Squat"
local chosenPrimary: string? = nil

local lastState: TrainingRemotes.MenuState? = nil
local wasOpen = false
local noticeToken = 0

local function statName(stat: string): string
	return TrainingStationRules.statName(stat)
end

-- From ProgressionConfig.TrainableTechnique, the one pairing table.
local function techniqueStatsFor(lift: string): { string }
	return TechniqueTraining.statsFor(lift) or {}
end

local function splitText(lift: string, primary: string): string
	local split = TrainingStationRules.techniqueSplit(lift, primary)
	if split == nil then
		return "?"
	end

	local parts: { string } = {}
	for _, entry in ipairs(split) do
		table.insert(parts, string.format("%d%% %s", math.floor(entry.share * 100 + 0.5), statName(entry.stat)))
	end
	return table.concat(parts, ", ")
end

local function describeChoice(mode: string?, lift: string?, primary: string?): string
	if mode == nil or lift == nil then
		return "Nothing"
	end

	if mode == "CN" then
		return string.format("%s \u{2014} Competition Number", lift)
	end

	if primary == nil then
		return string.format("%s \u{2014} Technique (pick a primary stat)", lift)
	end

	return string.format("%s \u{2014} Technique: %s", lift, splitText(lift, primary))
end

--------------------------------------------------------------------------------
-- BUILDING THE GUI
--------------------------------------------------------------------------------

local function makeLabel(parent: Instance, text: string, height: number, order: number): TextLabel
	local label = UIStyle.text(parent, "Label", UDim2.new(), UDim2.new(1, 0, 0, height), SIZES.body, C.white)
	label.Text = text
	label.LayoutOrder = order
	return label
end

-- A section heading: "LIFT //" with a line running on.
local function makeHeading(parent: Instance, text: string, order: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Heading"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 24)
	row.LayoutOrder = order
	row.Parent = parent
	local width = 14 * #text + 10
	UIStyle.sectionHead(row, "Text", text, UDim2.fromOffset(0, 2), width, PANEL_WIDTH - 60, "bar")
	return row
end

-- Outline button look, or the chosen one (yellow, ink text).
local function setChosen(button: TextButton, chosen: boolean)
	button.BackgroundColor3 = if chosen then C.yellow else C.navyDeep
	button.TextColor3 = if chosen then C.ink else C.white
	button.FontFace = if chosen then UIStyle.heading() else UIStyle.font(Enum.FontWeight.Bold)
	local edge = button:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = if chosen then C.yellow else C.white
		edge.Transparency = if chosen then 0 else 0.35
	end
end

local function makeRow(parent: Instance, height: number, order: number): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	return row
end

-- An outline button (UIStyle look) sized as a share of its row.
local function makeButton(parent: Instance, text: string, widthScale: number, order: number): TextButton
	local button = UIStyle.button(parent, "Button", text, UDim2.new(), UDim2.new(widthScale, -10, 1, 0), "outline", function() end)
	button.TextScaled = false
	button.TextSize = SIZES.body
	button.TextWrapped = true
	button.LayoutOrder = order
	return button
end

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local categoryButtons: { [string]: TextButton } = {}
local liftButtons: { [string]: TextButton } = {}
local primaryHeading: TextLabel
local primaryRow: Frame
local primaryButtons: { TextButton } = {}
local choiceLabel: TextLabel
local currentLabel: TextLabel
local todayLabel: TextLabel
local techniqueLabel: TextLabel
local noticeLabel: TextLabel
local startButton: TextButton
local stopButton: TextButton
local statusBar: TextLabel

local remotes: TrainingRemotes.RemoteSet? = nil

local function send(action: string, payload: any?)
	local set = remotes
	if set == nil then
		return
	end

	if payload ~= nil then
		set.menuRequest:FireServer(action, payload)
	else
		set.menuRequest:FireServer(action)
	end
end

local refreshMenu: () -> ()

local function rebuildPrimaryButtons()
	for _, button in ipairs(primaryButtons) do
		button:Destroy()
	end
	table.clear(primaryButtons)

	local stats = techniqueStatsFor(chosenLift)
	for index, stat in ipairs(stats) do
		local button = makeButton(primaryRow, statName(stat), 1 / #stats, index)
		button.Activated:Connect(function()
			chosenPrimary = stat
			refreshMenu()
		end)
		button:SetAttribute("Stat", stat)
		table.insert(primaryButtons, button)
	end
end

local function buildGui(player: Player)
	gui = Instance.new("ScreenGui")
	gui.Name = "TrainingMenu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UIStyle.fitToScreen(gui) -- shrink on short screens so nothing overlaps

	-- The panel, centred; its title tag SELECT YOUR GOAL and the rack's name; EXIT under its right corner.
	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	panel = holder
	UIStyle.titleTag(holder, "Tag", "SELECT YOUR GOAL", UDim2.fromOffset(-16, -28), UDim2.fromOffset(330, 48), nil, "chevron")
	UIStyle.exitButton(holder, "Exit", "EXIT", UDim2.new(1, -150, 1, 18), function()
		send("Close")
	end)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = body
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 30)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 26)
	padding.PaddingRight = UDim.new(0, 26)
	padding.Parent = content

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, LIST_GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content

	titleLabel = makeLabel(content, "Training Rack", 26, 1)
	titleLabel.TextColor3 = C.yellow
	titleLabel.FontFace = UIStyle.heading()
	titleLabel.TextSize = SIZES.heading

	makeHeading(content, "WHAT TO TRAIN", 2)
	local categoryRow = makeRow(content, 46, 3)
	categoryButtons.CN = makeButton(categoryRow, "Competition Number", 0.5, 1)
	categoryButtons.Technique = makeButton(categoryRow, "Technique Stats", 0.5, 2)

	for mode, button in pairs(categoryButtons) do
		button.Activated:Connect(function()
			chosenMode = mode :: TrainingStationRules.Mode
			refreshMenu()
		end)
	end

	makeHeading(content, "LIFT", 4)
	local liftRow = makeRow(content, 42, 5)
	for index, lift in ipairs(ProgressionConfig.Lifts) do
		local button = makeButton(liftRow, lift, 1 / #ProgressionConfig.Lifts, index)
		button.Activated:Connect(function()
			if chosenLift ~= lift then
				chosenLift = lift
				chosenPrimary = techniqueStatsFor(lift)[1]
				rebuildPrimaryButtons()
			end
			refreshMenu()
		end)
		liftButtons[lift] = button
	end

	primaryHeading = makeLabel(content, "PRIMARY STAT", 24, 6)
	primaryHeading.FontFace = UIStyle.heading()
	primaryRow = makeRow(content, 42, 7)

	choiceLabel = makeLabel(content, "", 28, 8)
	choiceLabel.FontFace = UIStyle.font(Enum.FontWeight.Bold)
	currentLabel = makeLabel(content, "", 28, 9)
	currentLabel.TextColor3 = C.muted
	todayLabel = makeLabel(content, "", 40, 10)
	todayLabel.TextSize = SIZES.small
	todayLabel.TextColor3 = C.muted

	techniqueLabel = makeLabel(content, "", 96, 11)
	techniqueLabel.TextSize = SIZES.small
	techniqueLabel.TextColor3 = C.white

	noticeLabel = makeLabel(content, "", 28, 12)
	noticeLabel.TextColor3 = C.yellow
	noticeLabel.Visible = false

	local actionRow = makeRow(content, 48, 13)
	startButton = UIStyle.button(actionRow, "Start", "START TRAINING", UDim2.new(), UDim2.new(0.55, -10, 1, 0), "primary",
		function() end)
	startButton.LayoutOrder = 1
	stopButton = UIStyle.button(actionRow, "Stop", "STOP", UDim2.new(), UDim2.new(0.45, -10, 1, 0), "danger", function() end)
	stopButton.LayoutOrder = 2
	-- Close is the EXIT button under the panel; this hidden one keeps the old reference working.
	local closeButton = makeButton(actionRow, "Close", 0, 3)
	closeButton.Visible = false

	startButton.Activated:Connect(function()
		if chosenMode == "CN" then
			send("Start", { mode = "CN", lift = chosenLift })
		elseif chosenPrimary ~= nil then
			send("Start", { mode = "Technique", lift = chosenLift, primary = chosenPrimary })
		end
	end)

	stopButton.Activated:Connect(function()
		send("Stop")
	end)

	closeButton.Activated:Connect(function()
		send("Close")
	end)

	-- Small status strip shown while the player holds a rack with the menu closed.
	statusBar = UIStyle.text(gui, "TrainingStatusBar", UDim2.new(0.5, 0, 0, 10), UDim2.fromOffset(680, 76), SIZES.body,
		C.white, UIStyle.font(Enum.FontWeight.Bold), Enum.TextXAlignment.Center)
	statusBar.AnchorPoint = Vector2.new(0.5, 0)
	statusBar.BackgroundTransparency = 0.1
	statusBar.BackgroundColor3 = C.navyDeep
	UIStyle.stroke(statusBar, C.yellow, 2)
	statusBar.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")

	rebuildPrimaryButtons()
end

--------------------------------------------------------------------------------
-- SHOWING STATE
--------------------------------------------------------------------------------

local function todayText(state: TrainingRemotes.MenuState): string
	local ev = if state.evToday then string.format("%.3f", state.evToday) else "?"
	local hours = state.liftHoursToday
	local liftHours = if hours and hours[chosenLift] then string.format("%.2f h", hours[chosenLift]) else "?"

	return string.format(
		"CN today: %s / %.2f EV (all lifts)  |  %s today: %s%s",
		ev,
		state.evCap,
		chosenLift,
		liftHours,
		if state.cnAvailable then "" else "\nDaily CN limit reached. CN returns at 00:00 UTC."
	)
end

local function isTrainingTechnique(state: TrainingRemotes.MenuState): boolean
	return state.sessionState == "Training" and state.mode == "Technique"
end

--[[
	The technique panel: rate, split, current raw and effective values, and this
	session's gains, for the lift being trained (or, if none, the lift chosen in
	the menu). Deliberately NO "today", "remaining" or countdown: technique has
	no earning cap. Raw values show four decimals so a 10 s tick's gain is
	visible.
]]
local function techniqueText(state: TrainingRemotes.MenuState): string
	local training = isTrainingTechnique(state)
	local lift = if training and state.lift then state.lift else chosenLift
	local primary = if training then state.primary else chosenPrimary

	local lines: { string } = {}

	table.insert(lines, string.format(
		"Technique: %.2f raw/h total, no limit%s",
		state.techniqueRawPerHour,
		if training then string.format("  \u{2014}  %s INCREASING NOW", lift) else ""
	))

	local rates: { [string]: number } = {}
	local shares: { [string]: number } = {}
	if primary ~= nil then
		for _, rate in ipairs(TechniqueTraining.ratesFor(lift, primary) or {}) do
			rates[rate.stat] = rate.raw
		end
		for _, share in ipairs(TechniqueTraining.split(lift, primary) or {}) do
			shares[share.stat] = share.share
		end
	end

	for _, stat in ipairs(techniqueStatsFor(lift)) do
		local view = state.techniqueStats[stat]
		local raw = if view then string.format("%.4f", view.raw) else "?"
		local effective = if view and view.effective then string.format("%.2f", view.effective) else "?"
		local gained = state.sessionGains[stat] or 0
		local share = shares[stat]

		table.insert(lines, string.format(
			"%s%s: raw %s (effective %s)  |  %s  |  this session +%.4f",
			statName(stat),
			if share then string.format(" %d%%", math.floor(share * 100 + 0.5)) else "",
			raw,
			effective,
			if rates[stat] then string.format("+%.2f/h", rates[stat]) else "pick a primary",
			gained
		))
	end

	return table.concat(lines, "\n")
end

-- "+0.0123 Depth Awareness, +0.0031 Squat Control this session"
local function sessionGainsText(state: TrainingRemotes.MenuState): string
	local parts: { string } = {}
	for _, stat in ipairs(techniqueStatsFor(state.lift or chosenLift)) do
		table.insert(parts, string.format("+%.4f %s", state.sessionGains[stat] or 0, statName(stat)))
	end
	return table.concat(parts, ", ") .. " this session"
end

refreshMenu = function()
	local state = lastState

	for mode, button in pairs(categoryButtons) do
		setChosen(button, mode == chosenMode)
	end
	categoryButtons.CN.Text = if state and not state.cnAvailable
		then "Competition Number\n(daily limit reached)"
		else "Competition Number"

	for lift, button in pairs(liftButtons) do
		setChosen(button, lift == chosenLift)
	end

	local technique = chosenMode == "Technique"
	primaryHeading.Visible = technique
	primaryRow.Visible = technique
	for _, button in ipairs(primaryButtons) do
		setChosen(button, button:GetAttribute("Stat") == chosenPrimary)
	end

	local choice = describeChoice(chosenMode, chosenLift, if technique then chosenPrimary else nil)
	choiceLabel.Text = "Your choice: " .. choice

	if state then
		titleLabel.Text = if state.stationId
			then TrainingStationRules.rackTitle(state.stationId)
			else "Training Rack"
		currentLabel.Text = "Current training: "
			.. (if state.sessionState == "Training"
				then describeChoice(state.mode, state.lift, state.primary)
				else state.statusLine)
		todayLabel.Text = todayText(state)
		techniqueLabel.Text = techniqueText(state)
		techniqueLabel.Visible = technique or isTrainingTechnique(state)
		stopButton.Visible = state.occupying
	end

	startButton.AutoButtonColor = not (technique and chosenPrimary == nil)
	startButton.BackgroundTransparency = if technique and chosenPrimary == nil then 0.5 else 0

	-- The panel fits what is showing (the technique rows come and go), staying centred.
	local content = panel:FindFirstChild("Content", true)
	if content then
		local height, count = CONTENT_PADDING, 0
		for _, child in ipairs(content:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				height += child.Size.Y.Offset
				count += 1
			end
		end
		panel.Size = UDim2.fromOffset(PANEL_WIDTH, height + LIST_GAP * math.max(0, count - 1))
	end
end

local function showNotice(notice: string?)
	noticeToken += 1
	local token = noticeToken
	noticeLabel.Text = notice or ""
	noticeLabel.Visible = notice ~= nil

	if notice then
		task.delay(NOTICE_SECONDS, function()
			if noticeToken == token then
				noticeLabel.Text = ""
				noticeLabel.Visible = false
				refreshMenu()
			end
		end)
	end
end

local function onState(state: TrainingRemotes.MenuState)
	lastState = state

	-- When the menu first opens, start from whatever is already running.
	if state.open and not wasOpen and state.mode and state.lift then
		chosenMode = state.mode :: TrainingStationRules.Mode
		chosenLift = state.lift
		chosenPrimary = state.primary or techniqueStatsFor(state.lift)[1]
		rebuildPrimaryButtons()
	elseif state.open and not wasOpen and chosenPrimary == nil then
		chosenPrimary = techniqueStatsFor(chosenLift)[1]
	end
	wasOpen = state.open

	panel.Visible = state.open

	statusBar.Visible = state.occupying and not state.open
	statusBar.Text = string.format(
		"%s\n%sCN today: %s / %.2f EV  \u{2014}  hold [E] at your rack for the menu",
		if state.sessionState == "Training"
			then describeChoice(state.mode, state.lift, state.primary)
			else state.statusLine,
		if isTrainingTechnique(state) then "Technique increasing: " .. sessionGainsText(state) .. "\n" else "",
		if state.evToday then string.format("%.3f", state.evToday) else "?",
		state.evCap
	)

	if state.notice then
		showNotice(state.notice)
		-- A refusal while the menu is closed (rack taken, too far away) still needs to be seen.
		if not state.open then
			statusBar.Visible = true
			statusBar.Text = state.notice
			local token = noticeToken
			task.delay(NOTICE_SECONDS, function()
				local latest = lastState
				if noticeToken == token and latest and not latest.occupying then
					statusBar.Visible = false
				end
			end)
		end
	end

	refreshMenu()
end

--------------------------------------------------------------------------------
-- START
--------------------------------------------------------------------------------

function TrainingMenuController.start()
	local player = Players.LocalPlayer
	buildGui(player)

	local set = TrainingRemotes.waitForClient(ReplicatedStorage)
	remotes = set
	set.menuState.OnClientEvent:Connect(onState)

	chosenPrimary = techniqueStatsFor(chosenLift)[1]
	refreshMenu()
end

return TrainingMenuController
