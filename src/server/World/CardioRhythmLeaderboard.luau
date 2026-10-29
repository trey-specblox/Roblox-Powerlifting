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

	THE LOOK (the game's one UI style, user 2026-10-28: yellow, white and dark
	navy with a faint grid). A server script cannot require the client's
	UIStyle, so the colours and font are copied into `Style` below (keep them in
	step with src/client/UI/UIStyle.luau). Each board is a navy panel with a
	faint grid, a white frame and a yellow slab peeking out behind it; a slanted
	black title tag with a white edge and two yellow slashes ("ALL-TIME //",
	"THIS WEEK //") and "BEST RUNS" beside it; the reset line in muted text;
	then one navyDeep strip with a thin white edge per place: a rank badge (1st
	gold, 2nd silver/white, 3rd bronze, the rest navy), the avatar headshot,
	the username and the time in heavy italic. Studio's "TEST BOARD" line is red.
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

--[[
	The game's one UI style (user 2026-10-28: "MAKE SURE everything that requires
	a ui has the same style"). It lives in the client's UIStyle, which a server
	script cannot require, so these values MIRROR UIStyle.Colours and
	UIStyle.font (src/client/UI/UIStyle.luau): change them together.
]]
local Style = {
	navy = Color3.fromRGB(14, 22, 54),
	navyDeep = Color3.fromRGB(7, 11, 30),
	grid = Color3.fromRGB(70, 96, 170),
	gridTransparency = 0.82,
	yellow = Color3.fromRGB(250, 206, 36),
	white = Color3.fromRGB(248, 248, 244),
	ink = Color3.fromRGB(10, 10, 12),
	muted = Color3.fromRGB(150, 160, 192),
	red = Color3.fromRGB(226, 46, 56),
	blue = Color3.fromRGB(70, 146, 255),
	family = "rbxasset://fonts/families/Montserrat.json", -- Montserrat; headings heavy italic
}
local HEADING = Font.new(Style.family, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BODY = Font.new(Style.family, Enum.FontWeight.Bold)

-- The boards' own bronze (UIStyle has none): 3rd place.
local BRONZE = Color3.fromRGB(214, 138, 72)
-- Rank badges: 1st gold, 2nd silver (white), 3rd bronze, the rest navy with white numbers.
local BADGES = {
	{ fill = Style.yellow, ink = Style.ink },
	{ fill = Style.white, ink = Style.ink },
	{ fill = BRONZE, ink = Style.ink },
}
local OTHER_BADGE = { fill = Style.navy, ink = Style.white }
local TITLES = { AllTime = "ALL-TIME", Weekly = "THIS WEEK" }

-- Pixel sizes on the wall screens (RoomProps draws them at 50 pixels per stud, so 1 pixel = 0.02 studs).
local FRAME_PX = 4 -- the panel's white frame
local INNER_PX = 2 -- the thin inner line
local TAG_EDGE_PX = 3 -- the title tag's white edge
local ROW_EDGE_PX = 2 -- each row's thin white edge
local GRID_PX = 22 -- the faint grid's spacing
local GRID_LINE_PX = 2

-- Where the panel sits on the screen, as a share of it; the yellow slab peeks out at the bottom right.
local BODY_AT, BODY_SIZE = Vector2.new(0.012, 0.012), Vector2.new(0.955, 0.945)
local SLAB_AT = Vector2.new(0.03, 0.035)

-- The screen's size in pixels (for a square grid); a guess if it cannot be worked out.
local function canvasSize(gui: SurfaceGui): Vector2
	local parent = gui.Parent
	if gui.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize then
		return gui.CanvasSize
	end
	if parent and parent:IsA("BasePart") then
		local size = (parent :: BasePart).Size
		local width, height = size.X, size.Y
		if gui.Face == Enum.NormalId.Left or gui.Face == Enum.NormalId.Right then
			width = size.Z
		elseif gui.Face == Enum.NormalId.Top or gui.Face == Enum.NormalId.Bottom then
			height = size.Z
		end
		if width > 0 and height > 0 then
			return Vector2.new(width, height) * gui.PixelsPerStud
		end
	end
	return Vector2.new(440, 360)
end

local function box(parent: Instance, name: string, x: number, y: number, width: number, height: number, colour: Color3,
	zIndex: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(width, height)
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	frame.Parent = parent
	return frame
end

local function stroke(parent: Instance, colour: Color3, thickness: number, transparency: number?)
	local edge = Instance.new("UIStroke")
	edge.Color = colour
	edge.Thickness = thickness
	edge.Transparency = transparency or 0
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = parent
end

local function text(parent: Instance, name: string, value: string, x: number, y: number, width: number, height: number,
	font: Font, ink: Color3, align: Enum.TextXAlignment, zIndex: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(width, height)
	label.Text = value
	label.TextColor3 = ink
	label.TextScaled = true
	label.TextXAlignment = align
	label.FontFace = font
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

-- The navy panel: a yellow slab behind, navy fading to navyDeep, a faint grid, a white frame and a thin inner line.
local function buildPanel(gui: SurfaceGui): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Board"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	box(holder, "Back", SLAB_AT.X, SLAB_AT.Y, BODY_SIZE.X, BODY_SIZE.Y, Style.yellow, 1)
	local body = box(holder, "Body", BODY_AT.X, BODY_AT.Y, BODY_SIZE.X, BODY_SIZE.Y, Style.navy, 2)
	stroke(body, Style.white, FRAME_PX)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Style.navy, Style.navyDeep)
	shade.Parent = body

	local grid = box(body, "Grid", 0, 0, 1, 1, Style.navy, 2)
	grid.BackgroundTransparency = 1
	grid.ClipsDescendants = true
	local canvas = canvasSize(gui)
	local stepX = GRID_PX / math.max(canvas.X * BODY_SIZE.X, GRID_PX)
	local stepY = GRID_PX / math.max(canvas.Y * BODY_SIZE.Y, GRID_PX)
	for index = 1, math.floor(1 / stepX) do
		local line = box(grid, "V", index * stepX, 0, 0, 1, Style.grid, 2)
		line.Size = UDim2.new(0, GRID_LINE_PX, 1, 0)
		line.BackgroundTransparency = Style.gridTransparency
	end
	for index = 1, math.floor(1 / stepY) do
		local line = box(grid, "H", 0, index * stepY, 1, 0, Style.grid, 2)
		line.Size = UDim2.new(1, 0, 0, GRID_LINE_PX)
		line.BackgroundTransparency = Style.gridTransparency
	end

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(9, 9)
	inner.Size = UDim2.new(1, -18, 1, -18)
	inner.ZIndex = 2
	inner.Parent = body
	stroke(inner, Style.white, INNER_PX, 0.65)
	return body
end

-- A slanted black tag with a white edge, heavy italic text and two yellow slashes: "ALL-TIME //".
local function buildTitleTag(body: Frame, title: string)
	local tag = box(body, "TitleTag", 0.04, 0.045, 0.55, 0.105, Style.ink, 5)
	tag.Rotation = -4
	stroke(tag, Style.white, TAG_EDGE_PX)
	text(tag, "Text", title, 0.05, 0.12, 0.77, 0.76, HEADING, Style.white, Enum.TextXAlignment.Left, 5)
	for index = 0, 1 do
		local slash = box(tag, "Slash_" .. index, 0.85 + index * 0.055, 0.12, 0.028, 0.76, Style.yellow, 5)
		slash.Rotation = 25
	end
end

-- One place on the board: a navyDeep strip with a thin white edge, the rank badge, avatar, name and time.
local function buildRow(body: Frame, index: number, top: number, step: number): Row
	local row = box(body, "Row_" .. index, 0.03, top + (index - 1) * step, 0.94, step * 0.86, Style.navyDeep, 3)
	stroke(row, Style.white, ROW_EDGE_PX, 0.5)

	local look = BADGES[index] or OTHER_BADGE
	local badge = box(row, "Rank", 0.012, 0.12, 0.075, 0.76, look.fill, 4)
	if BADGES[index] == nil then
		stroke(badge, Style.white, ROW_EDGE_PX, 0.4)
	end
	local rank = text(badge, "Text", tostring(index), 0.06, 0.06, 0.88, 0.88, HEADING, look.ink, Enum.TextXAlignment.Center, 4)

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Style.navy
	avatar.BackgroundTransparency = 1
	avatar.BorderSizePixel = 0
	avatar.Position = UDim2.fromScale(0.1, 0.08)
	avatar.Size = UDim2.fromScale(0.84, 0.84)
	avatar.SizeConstraint = Enum.SizeConstraint.RelativeYY
	avatar.ZIndex = 4
	avatar.Parent = row

	return {
		rank = rank,
		avatar = avatar,
		name = text(row, "Name", "", 0.175, 0.14, 0.55, 0.72, BODY, Style.white, Enum.TextXAlignment.Left, 4),
		time = text(row, "Time", "", 0.74, 0.1, 0.24, 0.8, HEADING, Style.white, Enum.TextXAlignment.Right, 4),
	}
end

local function buildView(gui: SurfaceGui, board: string): View
	local body = buildPanel(gui)
	buildTitleTag(body, TITLES[board] or string.upper(board))
	text(body, "Heading", "BEST RUNS", 0.62, 0.06, 0.34, 0.075, HEADING, Style.white, Enum.TextXAlignment.Right, 3)
	local subtitle = text(body, "Subtitle", "", 0.04, 0.18, 0.92, 0.05, BODY, Style.muted, Enum.TextXAlignment.Left, 3)
	local rows: { Row } = {}
	local top = 0.245
	local step = 0.69 / math.max(Settings.TopCount, 1)
	for index = 1, Settings.TopCount do
		rows[index] = buildRow(body, index, top, step)
	end
	if mode == "memory" or mode == "studio" then
		text(body, "TestBoard", if mode == "memory" then "TEST BOARD (Studio, not saved)" else "TEST BOARD (Studio_ stores)",
			0.04, 0.943, 0.92, 0.042, BODY, Style.red, Enum.TextXAlignment.Center, 4)
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
			row.avatar.BackgroundTransparency = if entry then 0 else 1
			row.name.Text = if entry then names[entry.userId] or ("Player " .. entry.userId) else "-"
			row.name.TextColor3 = if entry then Style.white else Style.muted
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
