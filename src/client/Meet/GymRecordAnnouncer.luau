--!strict
--[[
	GymRecordAnnouncer
	Client / Meet

	Record news for everyone in the server (GAME_DESIGN.md §31.6, "The gym
	record wall — first build"). User 2026-10-30: "on top and less visible ...
	I dont want players getting annoyed", so the news is one short line of
	outlined text at the top of the screen, no card, gone after a few seconds:

		treylicious1 set a new GYM RECORD: 190 KG SQUAT (83 kg)
		treylicious1 is going for a GYM RECORD: 200 KG SQUAT (83 kg)  [WATCH]

	GymRecordRemotes.BROKEN: a record fell (also written in the chat).
	GymRecordRemotes.ATTEMPT: a lifter declared a record weight at a meet; the
	small WATCH button asks the server to teleport the player there
	(TeleportRemotes), skipped for the lifter and for players already there.
	LocalMeetRemotes.LEVEL_NEWS: the next meet is a Regional or State meet
	(GAME_DESIGN §35.8), with a GO button to the venue (skipped for players
	already there):

		The next meet is a STATE MEET: prize pot x3, titles for the top 3. Sign up within 8:30  [GO]

	At most MAX_LINES at once (the oldest goes). While the lift banner is up
	(LiftAttemptController), the lines move below it so a lifter still sees it.
	Display only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GymRecordRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("GymRecordRemotes"))
local TeleportRemotes = require(Shared:WaitForChild("World"):WaitForChild("TeleportRemotes"))
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local GymRecordAnnouncer = {}

local TEXT_SIZE = 22
local TOP = 8
-- Under the lift banner and its status line (LiftAttemptController: they end about 110 px down).
local TOP_DURING_LIFT = 122
local MAX_LINES = 3
local RECORD_SECONDS = 7
local ATTEMPT_SECONDS = 12
local LEVEL_SECONDS = 14
local NOTE_SECONDS = 4
local FADE_SECONDS = 0.4

-- Each level's colour in a line. Only GYM records exist so far.
local LEVEL_COLOURS: { [string]: string } = { GYM = "#FACE24", NATIONAL = "#4692FF", WORLD = "#E22E38" }
local LIFT_COLOURS: { [string]: string } = { Squat = "#FACE24", Bench = "#FF6A72", Deadlift = "#6FB0FF", Total = "#FFFFFF" }

local started = false

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

local function coloured(text: string, hex: string): string
	return string.format('<font color="%s">%s</font>', hex, text)
end

local function recordText(record: string, kg: number): string
	return coloured(string.format("%s KG %s", kgText(kg), string.upper(record)), LIFT_COLOURS[record] or "#FFFFFF")
end

-- "190 KG SQUAT + 540 KG TOTAL"
local function recordsText(records: { any }): string
	local parts: { string } = {}
	for _, record in ipairs(records) do
		table.insert(parts, recordText(record.record, record.kg))
	end
	return table.concat(parts, " + ")
end

local function levelText(level: string?): string
	local name = level or "GYM"
	return coloured(name .. " RECORD", LEVEL_COLOURS[name] or LEVEL_COLOURS.GYM)
end

local function sayInChat(text: string)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local system = channels and channels:FindFirstChild("RBXSystem")
		if system and system:IsA("TextChannel") then
			system:DisplaySystemMessage(string.format('<font color="#FACE24">%s</font>', text))
		end
	end)
end

function GymRecordAnnouncer.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local brokenRemote, attemptRemote = GymRecordRemotes.waitForClient(ReplicatedStorage)
	local teleportRemote = TeleportRemotes.waitForClient(ReplicatedStorage)
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "RecordNews"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20

	local stack = Instance.new("Frame")
	stack.Name = "Lines"
	stack.AnchorPoint = Vector2.new(0.5, 0)
	stack.Position = UDim2.new(0.5, 0, 0, TOP)
	stack.Size = UDim2.new(1, -240, 0, 0)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	stack.BackgroundTransparency = 1
	stack.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = stack
	gui.Parent = playerGui

	-- Below the lift banner while it shows.
	local function followBanner()
		local bannerGui = playerGui:FindFirstChild("LiftAttemptBanner")
		local banner = bannerGui and bannerGui:FindFirstChild("Banner")
		local up = banner ~= nil and banner:IsA("GuiObject") and banner.Visible
		stack.Position = UDim2.new(0.5, 0, 0, if up then TOP_DURING_LIFT else TOP)
	end
	task.spawn(function()
		local bannerGui = playerGui:WaitForChild("LiftAttemptBanner", 30)
		local banner = bannerGui and bannerGui:WaitForChild("Banner", 5)
		if banner and banner:IsA("GuiObject") then
			banner:GetPropertyChangedSignal("Visible"):Connect(followBanner)
			followBanner()
		end
	end)

	local order = 0
	local lines: { Frame } = {}

	local function fade(line: Frame, to: number)
		for _, piece in ipairs(line:GetDescendants()) do
			if piece:IsA("TextLabel") or piece:IsA("TextButton") then
				local goal: { [string]: any } = { TextTransparency = to }
				if piece:IsA("TextButton") then
					goal.BackgroundTransparency = to
				end
				TweenService:Create(piece, TweenInfo.new(FADE_SECONDS), goal):Play()
			elseif piece:IsA("UIStroke") then
				TweenService:Create(piece, TweenInfo.new(FADE_SECONDS), { Transparency = to }):Play()
			end
		end
	end

	local function remove(line: Frame)
		local index = table.find(lines, line)
		if index then
			table.remove(lines, index)
		end
		line:Destroy()
	end

	-- One line of news (rich text), with a small WATCH button when `watch` names a place. Fades out after `seconds`.
	local function show(text: string, seconds: number, watch: string?, buttonText: string?)
		while #lines >= MAX_LINES do
			remove(lines[1])
		end
		order += 1
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.LayoutOrder = order
		line.BackgroundTransparency = 1
		line.AutomaticSize = Enum.AutomaticSize.XY
		line.Size = UDim2.fromOffset(0, 0)
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.SortOrder = Enum.SortOrder.LayoutOrder
		row.Padding = UDim.new(0, 10)
		row.Parent = line

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.fromOffset(0, 0)
		label.RichText = true
		label.FontFace = UIStyle.heading()
		label.TextSize = TEXT_SIZE
		label.TextColor3 = C.white
		label.Text = text
		label.TextTransparency = 1
		label.LayoutOrder = 1
		label.Parent = line
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		outline.Color = C.ink
		outline.Thickness = 2
		outline.Transparency = 1
		outline.Parent = label

		if watch then
			local button = Instance.new("TextButton")
			button.Name = "Watch"
			button.LayoutOrder = 2
			button.Size = UDim2.fromOffset(84, 24)
			button.BackgroundColor3 = C.yellow
			button.BackgroundTransparency = 1
			button.BorderSizePixel = 0
			button.AutoButtonColor = true
			button.FontFace = UIStyle.heading()
			button.TextSize = UIStyle.TextSizes.small
			button.TextColor3 = C.ink
			button.TextTransparency = 1
			button.Text = buttonText or "WATCH ▶"
			button.Parent = line
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = button
			local asking = false
			button.Activated:Connect(function()
				if asking then
					return
				end
				asking = true
				button.Text = "…"
				local ok, went, message = pcall(function()
					return teleportRemote:InvokeServer(watch)
				end)
				if ok and went then
					button.Visible = false
				else
					button.Text = buttonText or "WATCH ▶"
					asking = false
					if ok and typeof(message) == "string" then
						show(message, NOTE_SECONDS, nil)
					end
				end
			end)
		end

		line.Parent = stack
		table.insert(lines, line)
		fade(line, 0)
		task.delay(seconds, function()
			if line.Parent then
				fade(line, 1)
				task.wait(FADE_SECONDS)
				remove(line)
			end
		end)
	end

	brokenRemote.OnClientEvent:Connect(function(news: GymRecordRemotes.Announcement)
		if typeof(news) ~= "table" or typeof(news.records) ~= "table" or #news.records == 0 then
			return
		end
		local first = news.records[1]
		local name = coloured(news.name, "#FACE24")
		local verb = if first.previousKg == nil then "set a new"
			elseif first.own then "raised their own"
			else string.format("broke %s's", first.previousName or "?")
		show(string.format("%s %s %s: %s (%s)", name, verb, levelText(first.level), recordsText(news.records),
			news.classLabel), RECORD_SECONDS, nil)
		local plain: { string } = {}
		for _, record in ipairs(news.records) do
			table.insert(plain, string.format("%s KG %s", kgText(record.kg), string.upper(record.record)))
		end
		sayInChat(string.format("NEW %s RECORD: %s, %s (%s class)", first.level or "GYM", news.name,
			table.concat(plain, " + "), news.classLabel))
	end)

	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(LocalMeetRemotes.FOLDER_NAME, math.huge) :: Instance
		local levelRemote = folder:WaitForChild(LocalMeetRemotes.LEVEL_NEWS, math.huge) :: RemoteEvent
		levelRemote.OnClientEvent:Connect(function(news: LocalMeetRemotes.LevelNews)
			if typeof(news) ~= "table" or typeof(news.levelLabel) ~= "string" or typeof(news.signUpClosesAt) ~= "number" then
				return
			end
			local left = math.max(0, math.floor(news.signUpClosesAt - workspace:GetServerTimeNow()))
			local there = player:GetAttribute(LocalMeetConfig.VenueAttribute) ~= nil
			show(string.format("The next meet is a %s: prize pot x%d, titles for the top 3. Sign up within %d:%02d",
				coloured(news.levelLabel, "#FACE24"), news.potMultiplier or 1, left // 60, left % 60), LEVEL_SECONDS,
				if there then nil else "LocalMeet", "GO ▶")
		end)
	end)

	attemptRemote.OnClientEvent:Connect(function(news: GymRecordRemotes.AttemptNews)
		if typeof(news) ~= "table" or typeof(news.records) ~= "table" or #news.records == 0 then
			return
		end
		-- No WATCH for the lifter, or for anyone already at the meet.
		local there = news.userId == player.UserId or player:GetAttribute(LocalMeetConfig.VenueAttribute) ~= nil
		local watch = if there or typeof(news.watch) ~= "string" then nil else news.watch
		show(string.format("%s is going for a %s: %s (%s) at the %s", coloured(news.name, "#FACE24"),
			levelText(news.records[1].level), recordsText(news.records), news.classLabel, string.lower(news.where)),
			ATTEMPT_SECONDS, watch)
	end)
end

return GymRecordAnnouncer
