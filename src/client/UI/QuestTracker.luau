--!strict
--[[
	QuestTracker
	Client / UI

	The quests you have, on the right side of the screen (user 2026-11-19, from their reference picture: an "!" header
	with the count, each task in white with its time left in yellow under it, and a thin line between them).

		- shows a coach's quest once you asked them for it ("I need a stronger squat", CoachDialogue) or once a meet
		  moved it, until the daily reset
		- a finished quest says so for a moment, then leaves the list; nothing to show means nothing on screen
		- the timer counts down to the daily reset (the server's UTC day); at zero it asks the server again

	Phones show it in the top right corner (their player list is folded away and the jump button is bottom right);
	computers show it on the right, below where the SESSION GAINS panel (GainDisplay) can grow, clear of the player
	list in the top right.

	Display only: the server keeps the quests (QuestService, ProfileOperations).

	PERFORMANCE: a few labels; the timer text updates once a second.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearStatsConfig = require(Shared:WaitForChild("Config"):WaitForChild("GearStatsConfig"))
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig"))
local QuestRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("QuestRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours

local QuestTracker = {}

local WIDTH = 320
local HEADER_HEIGHT = 36
local ROW_HEIGHT = 80
-- A phone shows it this much bigger, so the words stay readable on a small screen.
local PHONE_SIZE = 1.3
-- Seconds a finished quest stays on the list, saying it's done.
local DONE_SECONDS = 20
local LIFT_ORDER = { "Squat", "Bench", "Deadlift" }

local started = false
local remotes: QuestRemotes.RemoteSet? = nil
-- Set by start: shows a fresh set of views from the server.
local showViews: ((any) -> ())? = nil

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

--[[
	New quest views from the server (QuestRemotes.GET or TAKE). CoachDialogue calls this after taking a quest so the
	tracker shows it at once.
]]
function QuestTracker.show(views: any)
	if showViews and typeof(views) == "table" then
		(showViews :: (any) -> ())(views)
	end
end

-- Asks the server for today's quests and shows them (tries again shortly if the server was busy).
function QuestTracker.refresh()
	local set = remotes
	if set == nil then
		return
	end
	task.spawn(function()
		for _ = 1, 8 do
			local ok, views = pcall(function()
				return set.get:InvokeServer()
			end)
			if ok and typeof(views) == "table" then
				QuestTracker.show(views)
				return
			end
			task.wait(2)
		end
	end)
end

function QuestTracker.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local set = QuestRemotes.waitForClient(ReplicatedStorage)
	remotes = set

	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestTracker"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 6
	UIStyle.fitToScreen(gui)

	local phone = UIStyle.isTouchOnly()
	local holder = Instance.new("Frame")
	holder.Name = "Quests"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = if phone then UDim2.new(1, -16, 0, 12) else UDim2.new(1, -16, 0.5, 130)
	holder.Size = UDim2.fromOffset(WIDTH, HEADER_HEIGHT)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	-- Everything sits in `box`, drawn bigger on a phone (its own UIScale; the screen fitting scales `holder`).
	local size = if phone then PHONE_SIZE else 1
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.fromOffset(WIDTH, HEADER_HEIGHT)
	box.BackgroundTransparency = 1
	box.Parent = holder
	local boxScale = Instance.new("UIScale")
	boxScale.Scale = size
	boxScale.Parent = box

	-- The header: a round "!" and CURRENT QUESTS [n].
	local mark = Instance.new("Frame")
	mark.Name = "Mark"
	mark.Position = UDim2.fromOffset(0, 4)
	mark.Size = UDim2.fromOffset(28, 28)
	mark.BackgroundColor3 = C.ink
	mark.BackgroundTransparency = 0.2
	mark.Parent = box
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = mark
	UIStyle.stroke(mark, C.white, 2)
	local bang = UIStyle.text(mark, "Bang", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 22, C.white, UIStyle.heading())
	bang.TextXAlignment = Enum.TextXAlignment.Center
	bang.TextYAlignment = Enum.TextYAlignment.Center
	bang.Text = "!"
	local title = UIStyle.text(box, "Title", UDim2.fromOffset(38, 0), UDim2.new(1, -38, 0, HEADER_HEIGHT), 24, C.white,
		UIStyle.heading())
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextWrapped = false
	title.TextStrokeColor3 = C.ink
	title.TextStrokeTransparency = 0

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
	list.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	list.BackgroundTransparency = 1
	list.Parent = box
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local addSound = Instance.new("Sound")
	addSound.Name = "QuestAdded"
	addSound.SoundId = GearStatsConfig.Sounds.Tick
	addSound.Volume = 0.4
	addSound.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")

	type Row = { frame: Frame, task: TextLabel, timer: TextLabel }
	local rows: { [string]: Row } = {}
	-- Server views, and when each finished quest finished here (it leaves the list DONE_SECONDS later).
	local current: { [string]: any } = {}
	local finishedAt: { [string]: number } = {}
	-- When today's quests reset, on this client's clock.
	local resetAt = os.clock() + 86400
	local everShown = false

	local function rowFor(lift: string, index: number): Row
		local row = rows[lift]
		if row == nil then
			local frame = Instance.new("Frame")
			frame.Name = lift
			frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			frame.BackgroundTransparency = 1
			frame.Parent = list
			local taskText = UIStyle.text(frame, "Task", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 48), 20, C.white,
				UIStyle.heading())
			taskText.TextYAlignment = Enum.TextYAlignment.Top
			taskText.TextStrokeColor3 = C.ink
			taskText.TextStrokeTransparency = 0
			local timer = UIStyle.text(frame, "Timer", UDim2.new(0, 4, 0, 52), UDim2.new(1, -8, 0, 20), 18, C.yellow,
				UIStyle.heading())
			timer.TextXAlignment = Enum.TextXAlignment.Right
			timer.TextWrapped = false
			timer.TextStrokeColor3 = C.ink
			timer.TextStrokeTransparency = 0
			local line = Instance.new("Frame")
			line.Name = "Line"
			line.AnchorPoint = Vector2.new(0, 1)
			line.Position = UDim2.new(0, 4, 1, -2)
			line.Size = UDim2.new(0.62, 0, 0, 2)
			line.BackgroundColor3 = C.white
			line.BorderSizePixel = 0
			line.Parent = frame
			row = { frame = frame, task = taskText, timer = timer }
			rows[lift] = row
		end
		row.frame.LayoutOrder = index
		return row :: Row
	end

	local function draw()
		local shown = 0
		local now = os.clock()
		for index, lift in ipairs(LIFT_ORDER) do
			local view = current[lift]
			local doneAt = finishedAt[lift]
			local active = typeof(view) == "table" and not view.done and (view.taken or (view.goodLifts or 0) > 0)
			local justDone = doneAt ~= nil and now - doneAt < DONE_SECONDS
			if active or justDone then
				shown += 1
				local row = rowFor(lift, index)
				row.frame.Visible = true
				local coach = QuestConfig.Coaches[lift]
				local plural = QuestConfig.Plural[lift] or lift
				if justDone and not active then
					row.task.Text = string.format("%s's quest done!", if coach then coach.name else lift)
					row.task.TextColor3 = C.yellow
					row.timer.Text = "--:--"
				else
					row.task.Text = string.format("Make %d good %s in a meet! (%d/%d)", view.needed, plural, view.goodLifts,
						view.needed)
					row.task.TextColor3 = C.white
					row.timer.Text = clock(resetAt - now)
				end
			elseif rows[lift] then
				rows[lift].frame.Visible = false
			end
		end
		title.Text = string.format("CURRENT QUESTS [%d]", shown)
		local height = HEADER_HEIGHT + shown * ROW_HEIGHT
		box.Size = UDim2.fromOffset(WIDTH, height)
		holder.Size = UDim2.fromOffset(WIDTH * size, height * size)
		holder.Visible = shown > 0
	end

	showViews = function(views: any)
		local added = false
		for _, lift in ipairs(LIFT_ORDER) do
			local view = views[lift]
			if typeof(view) ~= "table" then
				continue
			end
			local before = current[lift]
			local wasActive = typeof(before) == "table" and not before.done and (before.taken or (before.goodLifts or 0) > 0)
			local isActive = not view.done and (view.taken or (view.goodLifts or 0) > 0)
			if wasActive and view.done then
				finishedAt[lift] = os.clock()
			elseif isActive and not wasActive then
				added = true
			end
			if not view.done then
				finishedAt[lift] = nil
			end
			current[lift] = view
			if typeof(view.resetIn) == "number" and view.resetIn > 0 then
				resetAt = os.clock() + view.resetIn
			end
		end
		-- No sound for the quests already on the list when joining.
		if added and everShown then
			addSound:Play()
		end
		everShown = true
		draw()
	end

	-- After a meet moved a quest (QuestService.tell sends its lines; CoachDialogue shows them): fresh numbers.
	set.news.OnClientEvent:Connect(function()
		task.wait(0.6)
		QuestTracker.refresh()
	end)

	-- The quests you already had today when you join.
	QuestTracker.refresh()

	-- The timer, and the daily reset.
	task.spawn(function()
		while true do
			task.wait(1)
			if holder.Visible then
				draw()
			end
			if os.clock() >= resetAt then
				resetAt = os.clock() + 86400
				task.wait(2)
				QuestTracker.refresh()
			end
		end
	end)
end

return QuestTracker
