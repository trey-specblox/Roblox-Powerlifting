--!strict
--[[
	CardioRhythmLeaderboard
	Server / World

	The treadmill rhythm game's two saved leaderboards (GAME_DESIGN.md §27 "The
	treadmill rhythm game", user 2026-10-27): each player's BEST SINGLE RUN,
	all-time and this week, top 10 with avatar, username and survival time, on
	the Cardio room's side walls. No rewards.

	WHERE THE TIMES COME FROM
	Only CardioRhythmService calls submit(), with a time its own clock measured
	when a runner was out. Nothing here listens to a client.

	HOW THEY ARE SAVED (the data design the user approved, 2026-10-27)
	One OrderedDataStore per board, key = the player's UserId, value = their
	best time in tenths of a second. The player's own save (PlayerDataService)
	is not touched. A time is written only if it beats the stored one
	(UpdateAsync, so two servers can never lower a best). The weekly board is a
	new store each week, named after its Monday (00:00 UTC), so it "resets"
	without deleting anything.

	STUDIO
	Studio runs never reach the live boards. With Studio's API access on, the
	boards use stores named "Studio_..."; with it off (the usual case) they live
	in memory only, the boards say "TEST BOARD", and they vanish when Play stops.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CardioRhythmConfig"))
local Settings = Config.Leaderboard

local CardioRhythmLeaderboard = {}

local DAY = 86400
local WEEK = 7 * DAY
local FIRST_MONDAY = 4 * DAY -- 1970-01-05 00:00 UTC (1 January 1970 was a Thursday)
local BOARDS = { "AllTime", "Weekly" }

export type Entry = { userId: number, ticks: number }

type Board = {
	store: string, -- the store it shows now (the weekly one changes on Monday)
	entries: { Entry },
	views: { [SurfaceGui]: View },
}

type Row = { rank: TextLabel, avatar: ImageLabel, name: TextLabel, time: TextLabel }
type View = { subtitle: TextLabel, rows: { Row } }

type Job = { userId: number, ticks: number, at: number } -- at: os.time() when the run ended (picks its week)

-- "live" (the real stores), "studio" (Studio_ stores) or "memory" (Studio without API access); nil until known.
local mode: string? = nil
local memory: { [string]: { [string]: number } } = {}
local boards: { [string]: Board } = {}
local names: { [number]: string } = {}
local queue: { Job } = {}
local busy = false
local started = false

-- ---------------------------------------------------------------- weeks and store names

-- The Monday 00:00 UTC that starts the week containing `t` (seconds since 1970).
function CardioRhythmLeaderboard.weekStart(t: number): number
	return FIRST_MONDAY + math.floor((t - FIRST_MONDAY) / WEEK) * WEEK
end

function CardioRhythmLeaderboard.storeName(board: string, t: number): string
	local base = if board == "Weekly"
		then Settings.WeeklyStorePrefix .. (os.date("!%Y-%m-%d", CardioRhythmLeaderboard.weekStart(t)) :: string)
		else Settings.AllTimeStore
	return if mode == "studio" then Settings.StudioPrefix .. base else base
end

function CardioRhythmLeaderboard.formatTime(ticks: number): string
	local tenths = math.max(0, math.floor(ticks * 10 / Settings.TicksPerSecond + 0.5))
	local seconds = tenths // 10
	return string.format("%d:%02d.%d", seconds // 60, seconds % 60, tenths % 10)
end

-- ---------------------------------------------------------------- the stores

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	local deadline = os.clock() + 30
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and os.clock() < deadline do
		task.wait(1)
	end
end

-- Keeps `ticks` as the player's best in `store` unless a better one is there. True when it is safely stored.
local function saveBest(store: string, userId: number, ticks: number): boolean
	local key = tostring(userId)
	if mode == "memory" then
		local board = memory[store] or {}
		memory[store] = board
		board[key] = math.max(board[key] or 0, ticks)
		return true
	end
	waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
	local ok, err = pcall(function()
		DataStoreService:GetOrderedDataStore(store):UpdateAsync(key, function(old: any): any
			if typeof(old) == "number" and old >= ticks then
				return nil -- not a new best: write nothing
			end
			return ticks
		end)
	end)
	if not ok then
		warn(string.format("[CardioRhythmLeaderboard] saving %d to %s failed: %s", userId, store, tostring(err)))
	end
	return ok
end

local function readTop(store: string): { Entry }?
	local entries: { Entry } = {}
	if mode == "memory" then
		for key, ticks in pairs(memory[store] or {}) do
			table.insert(entries, { userId = tonumber(key) :: number, ticks = ticks })
		end
	else
		waitForBudget(Enum.DataStoreRequestType.GetSortedAsync)
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(store):GetSortedAsync(false, Settings.TopCount):GetCurrentPage()
		end)
		if not ok then
			warn(string.format("[CardioRhythmLeaderboard] reading %s failed: %s", store, tostring(result)))
			return nil
		end
		for _, item in ipairs(result) do
			local userId = tonumber(item.key)
			if userId and typeof(item.value) == "number" then
				table.insert(entries, { userId = userId, ticks = item.value })
			end
		end
	end
	table.sort(entries, function(a, b)
		return a.ticks > b.ticks
	end)
	while #entries > Settings.TopCount do
		table.remove(entries)
	end
	return entries
end

-- In Studio, find out whether the DataStores answer (API access on) or not.
local function detectMode(): string
	if not RunService:IsStudio() then
		return "live"
	end
	local ok = pcall(function()
		DataStoreService:GetOrderedDataStore(Settings.StudioPrefix .. Settings.AllTimeStore):GetAsync("Probe")
	end)
	return if ok then "studio" else "memory"
end

-- ---------------------------------------------------------------- names

local function resolveNames(entries: { Entry })
	for _, entry in ipairs(entries) do
		if names[entry.userId] == nil then
			local ok, name = pcall(function()
				return Players:GetNameFromUserIdAsync(entry.userId)
			end)
			if ok and typeof(name) == "string" then
				names[entry.userId] = name
			end
		end
	end
end

-- ---------------------------------------------------------------- drawing the boards

local BACKGROUND = Color3.fromRGB(18, 34, 72)
local ROW_SHADE = Color3.fromRGB(28, 48, 96)
local INK = Color3.fromRGB(255, 255, 255)
local SOFT_INK = Color3.fromRGB(176, 196, 232)
local TITLE_INK = { AllTime = Color3.fromRGB(255, 206, 64), Weekly = Color3.fromRGB(96, 224, 200) }
local MEDALS = { Color3.fromRGB(255, 206, 64), Color3.fromRGB(214, 222, 232), Color3.fromRGB(232, 150, 92) }
local TITLES = { AllTime = "ALL-TIME BEST RUNS", Weekly = "THIS WEEK'S BEST RUNS" }

local function text(parent: Instance, value: string, x: number, y: number, width: number, height: number,
	weight: Enum.FontWeight, ink: Color3, align: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(width, height)
	label.Text = value
	label.TextColor3 = ink
	label.TextScaled = true
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", weight)
	label.Parent = parent
	return label
end

local function buildView(gui: SurfaceGui, board: string): View
	local frame = Instance.new("Frame")
	frame.Name = "Board"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = BACKGROUND
	frame.Parent = gui
	text(frame, TITLES[board] or board, 0.05, 0.03, 0.9, 0.1, Enum.FontWeight.Heavy, TITLE_INK[board] or INK,
		Enum.TextXAlignment.Center)
	local subtitle = text(frame, "", 0.05, 0.135, 0.9, 0.055, Enum.FontWeight.Medium, SOFT_INK, Enum.TextXAlignment.Center)
	local rows: { Row } = {}
	local top, height = 0.215, 0.074
	for index = 1, Settings.TopCount do
		local row = Instance.new("Frame")
		row.Name = "Row_" .. index
		row.Position = UDim2.fromScale(0.04, top + (index - 1) * height)
		row.Size = UDim2.fromScale(0.92, height * 0.9)
		row.BorderSizePixel = 0
		row.BackgroundColor3 = ROW_SHADE
		row.BackgroundTransparency = if index % 2 == 1 then 0 else 1
		row.Parent = frame
		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.BackgroundTransparency = 1
		avatar.Position = UDim2.fromScale(0.1, 0.05)
		avatar.Size = UDim2.fromScale(0.9, 0.9)
		avatar.SizeConstraint = Enum.SizeConstraint.RelativeYY
		avatar.Parent = row
		rows[index] = {
			rank = text(row, tostring(index), 0.01, 0.1, 0.08, 0.8, Enum.FontWeight.Heavy, MEDALS[index] or SOFT_INK,
				Enum.TextXAlignment.Center),
			avatar = avatar,
			name = text(row, "", 0.19, 0.12, 0.55, 0.76, Enum.FontWeight.SemiBold, INK),
			time = text(row, "", 0.75, 0.12, 0.23, 0.76, Enum.FontWeight.Bold, INK, Enum.TextXAlignment.Right),
		}
	end
	if mode == "memory" or mode == "studio" then
		text(frame, if mode == "memory" then "TEST BOARD (Studio, not saved)" else "TEST BOARD (Studio_ stores)",
			0.05, 0.955, 0.9, 0.035, Enum.FontWeight.Medium, Color3.fromRGB(255, 150, 120), Enum.TextXAlignment.Center)
	end
	return { subtitle = subtitle, rows = rows }
end

local function subtitleFor(board: string): string
	if board ~= "Weekly" then
		return "Each player's best single run"
	end
	local left = CardioRhythmLeaderboard.weekStart(os.time()) + WEEK - os.time()
	local days, hours = left // DAY, (left % DAY) // 3600
	local remaining = if days > 0 then string.format("%dd %dh", days, hours)
		else string.format("%dh %dm", hours, (left % 3600) // 60)
	return "Resets Monday 00:00 UTC (in " .. remaining .. ")"
end

local function render(board: string)
	local state = boards[board]
	for _, view in pairs(state.views) do
		view.subtitle.Text = subtitleFor(board)
		for index, row in ipairs(view.rows) do
			local entry = state.entries[index]
			row.avatar.Image = if entry
				then string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", entry.userId)
				else ""
			row.name.Text = if entry then names[entry.userId] or ("Player " .. entry.userId) else "-"
			row.time.Text = if entry then CardioRhythmLeaderboard.formatTime(entry.ticks) else ""
		end
	end
end

local function attach(instance: Instance)
	if not instance:IsA("SurfaceGui") or mode == nil then
		return
	end
	local gui = instance :: SurfaceGui
	local board = gui:GetAttribute("Board")
	local state = if typeof(board) == "string" then boards[board] else nil
	if state == nil or state.views[gui] then
		return
	end
	state.views[gui] = buildView(gui, board :: string)
	gui.Destroying:Connect(function()
		state.views[gui] = nil
	end)
	render(board :: string)
end

-- ---------------------------------------------------------------- keeping the boards current

-- A just-saved time goes on the board at once (the next read confirms it).
local function merge(board: string, userId: number, ticks: number)
	local entries = boards[board].entries
	for index, entry in ipairs(entries) do
		if entry.userId == userId then
			if entry.ticks >= ticks then
				return
			end
			table.remove(entries, index)
			break
		end
	end
	table.insert(entries, { userId = userId, ticks = ticks })
	table.sort(entries, function(a, b)
		return a.ticks > b.ticks
	end)
	while #entries > Settings.TopCount do
		table.remove(entries)
	end
end

local function refresh()
	for _, board in ipairs(BOARDS) do
		local state = boards[board]
		local store = CardioRhythmLeaderboard.storeName(board, os.time())
		if store ~= state.store then
			-- A new week: an empty board until the new store is read.
			state.store = store
			state.entries = {}
		end
		local entries = readTop(store)
		if entries and state.store == store then
			resolveNames(entries)
			state.entries = entries
		end
		render(board)
	end
end

local function work()
	if busy then
		return
	end
	busy = true
	while #queue > 0 do
		local job = table.remove(queue, 1) :: Job
		for _, board in ipairs(BOARDS) do
			-- Named here, not in submit(): only now is it certain whether these are Studio_ stores.
			local store = CardioRhythmLeaderboard.storeName(board, job.at)
			for try = 1, Settings.SaveRetries do
				if saveBest(store, job.userId, job.ticks) then
					if boards[board].store == store then
						merge(board, job.userId, job.ticks)
						render(board)
					end
					break
				elseif try < Settings.SaveRetries then
					task.wait(2 ^ try)
				end
			end
		end
	end
	busy = false
end

--[[
	A runner's run is over: `seconds` is the server's own measure of how long
	they survived. Saved on both boards if it is the player's best there.
]]
function CardioRhythmLeaderboard.submit(userId: number, username: string, seconds: number)
	if typeof(userId) ~= "number" or typeof(seconds) ~= "number" or seconds ~= seconds then
		return
	end
	-- Studio's test players have negative ids; real players never do.
	if userId <= 0 and not RunService:IsStudio() then
		return
	end
	if seconds < Settings.MinSecondsToSave then
		return
	end
	local ticks = math.floor(math.min(seconds, Config.MaxRoundSeconds) * Settings.TicksPerSecond)
	names[userId] = username
	table.insert(queue, { userId = userId, ticks = ticks, at = os.time() })
	if mode ~= nil then
		task.spawn(work)
	end
end

function CardioRhythmLeaderboard.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(function(player)
		names[player.UserId] = player.Name
	end)
	-- Before a live server shuts down, give the waiting saves time to finish.
	game:BindToClose(function()
		local deadline = os.clock() + 25
		while (#queue > 0 or busy) and os.clock() < deadline do
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		mode = detectMode()
		print("[CardioRhythmLeaderboard] boards: " .. (mode :: string))
		for _, board in ipairs(BOARDS) do
			boards[board] = { store = CardioRhythmLeaderboard.storeName(board, os.time()), entries = {}, views = {} }
		end
		for _, gui in ipairs(CollectionService:GetTagged(Settings.BoardTag)) do
			attach(gui)
		end
		CollectionService:GetInstanceAddedSignal(Settings.BoardTag):Connect(attach)
		task.spawn(work)
		while true do
			refresh()
			task.wait(Settings.RefreshSeconds)
		end
	end)
end

return CardioRhythmLeaderboard
