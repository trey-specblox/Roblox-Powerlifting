--!strict
--[[
	TrainingMenuController
	Client / Training

	TEMPORARY FUNCTIONAL INTERFACE for the training racks of checkpoints 5B.6
	and 5B.7. Plain frames and buttons built in code; final styling comes later.

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

local TrainingMenuController = {}

local COLOR_PANEL = Color3.fromRGB(28, 30, 36)
local COLOR_BUTTON = Color3.fromRGB(60, 64, 76)
local COLOR_SELECTED = Color3.fromRGB(70, 130, 200)
local COLOR_START = Color3.fromRGB(60, 150, 80)
local COLOR_STOP = Color3.fromRGB(170, 70, 60)
local COLOR_TEXT = Color3.fromRGB(240, 240, 240)
local COLOR_NOTICE = Color3.fromRGB(255, 210, 90)
local COLOR_TECHNIQUE = Color3.fromRGB(150, 220, 170)

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
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.TextColor3 = COLOR_TEXT
	label.Font = Enum.Font.Gotham
	label.TextSize = 15
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

local function makeRow(parent: Instance, height: number, order: number): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	return row
end

local function makeButton(parent: Instance, text: string, widthScale: number, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(widthScale, -6, 1, 0)
	button.BackgroundColor3 = COLOR_BUTTON
	button.TextColor3 = COLOR_TEXT
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 15
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Text = text
	button.LayoutOrder = order
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

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

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(500, 640)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = panel

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	titleLabel = makeLabel(panel, "Training Rack", 30, 1)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 22
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center

	makeLabel(panel, "Category", 18, 2)
	local categoryRow = makeRow(panel, 40, 3)
	categoryButtons.CN = makeButton(categoryRow, "Competition Number", 0.5, 1)
	categoryButtons.Technique = makeButton(categoryRow, "Technique Stats", 0.5, 2)

	for mode, button in pairs(categoryButtons) do
		button.Activated:Connect(function()
			chosenMode = mode :: TrainingStationRules.Mode
			refreshMenu()
		end)
	end

	makeLabel(panel, "Lift", 18, 4)
	local liftRow = makeRow(panel, 36, 5)
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

	primaryHeading = makeLabel(panel, "Primary technique stat", 18, 6)
	primaryRow = makeRow(panel, 36, 7)

	choiceLabel = makeLabel(panel, "", 40, 8)
	currentLabel = makeLabel(panel, "", 40, 9)
	todayLabel = makeLabel(panel, "", 36, 10)
	todayLabel.TextSize = 14

	techniqueLabel = makeLabel(panel, "", 96, 11)
	techniqueLabel.TextSize = 14
	techniqueLabel.TextColor3 = COLOR_TECHNIQUE

	noticeLabel = makeLabel(panel, "", 44, 12)
	noticeLabel.TextColor3 = COLOR_NOTICE

	local actionRow = makeRow(panel, 40, 13)
	startButton = makeButton(actionRow, "Start Training", 0.4, 1)
	startButton.BackgroundColor3 = COLOR_START
	stopButton = makeButton(actionRow, "Stop Training", 0.35, 2)
	stopButton.BackgroundColor3 = COLOR_STOP
	local closeButton = makeButton(actionRow, "Close", 0.25, 3)

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

	-- Small status line shown while the player holds a rack with the menu closed.
	statusBar = Instance.new("TextLabel")
	statusBar.Name = "TrainingStatusBar"
	statusBar.AnchorPoint = Vector2.new(0.5, 0)
	statusBar.Position = UDim2.new(0.5, 0, 0, 8)
	statusBar.Size = UDim2.fromOffset(620, 64)
	statusBar.BackgroundColor3 = COLOR_PANEL
	statusBar.BackgroundTransparency = 0.2
	statusBar.TextColor3 = COLOR_TEXT
	statusBar.Font = Enum.Font.GothamMedium
	statusBar.TextSize = 15
	statusBar.TextWrapped = true
	statusBar.Visible = false
	statusBar.Parent = gui

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
		button.BackgroundColor3 = if mode == chosenMode then COLOR_SELECTED else COLOR_BUTTON
	end
	categoryButtons.CN.Text = if state and not state.cnAvailable
		then "Competition Number\n(daily limit reached)"
		else "Competition Number"

	for lift, button in pairs(liftButtons) do
		button.BackgroundColor3 = if lift == chosenLift then COLOR_SELECTED else COLOR_BUTTON
	end

	local technique = chosenMode == "Technique"
	primaryHeading.Visible = technique
	primaryRow.Visible = technique
	for _, button in ipairs(primaryButtons) do
		button.BackgroundColor3 = if button:GetAttribute("Stat") == chosenPrimary then COLOR_SELECTED else COLOR_BUTTON
	end

	local choice = describeChoice(chosenMode, chosenLift, if technique then chosenPrimary else nil)
	choiceLabel.Text = "Your choice: " .. choice

	if state then
		titleLabel.Text = if state.stationId
			then string.format("Training Rack %s", string.sub(state.stationId, -1))
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
end

local function showNotice(notice: string?)
	noticeToken += 1
	local token = noticeToken
	noticeLabel.Text = notice or ""

	if notice then
		task.delay(NOTICE_SECONDS, function()
			if noticeToken == token then
				noticeLabel.Text = ""
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
