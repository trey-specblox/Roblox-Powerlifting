--!strict
--[[
	GainDisplay
	Client / UI

	Every gain on screen (GAME_DESIGN §40.1, user 2026-11-19: "gains as a whole should be on a screen gain display.
	Any sort of gains"). Two parts, both only on this player's own screen (memory: no screen clutter):

		SESSION GAINS   a small panel on the right edge: one row per thing that grew since you joined (SQUAT, BENCH
		                SCALE, BAR PATH...), counting up with a little pop each time. Rack training adds about 0.004 kg
		                every 10 s, so small totals show three decimals and visibly move on every tick. The panel fades
		                out HIDE_AFTER seconds after the last gain and comes back with the next one.
		Floating pops   big outlined numbers in the lift's colour rising just left of the panel: training pops
		                "+0.1 kg SQUAT" each time a row passes another POP_STEP; a meet pops each full amount at once, with
		                a reward sound. (Not over the head: menus cover it.) Studio only: the workspace attribute
		                StudioGainPopSeconds slows them down for a screenshot.

	Sounds (the game's own, GearStatsConfig.Sounds): the crate's Tick, quietly, for a training pop; its Big sting for
	meet gains.

	Display only: the numbers come from GainRemotes.GAINED, sent by the server after it saved each gain.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GainRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("GainRemotes"))
local GearStatsConfig = require(Shared:WaitForChild("Config"):WaitForChild("GearStatsConfig"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local GainDisplay = {}

local PANEL_WIDTH = 260
local TITLE_HEIGHT = 30
local ROW_HEIGHT = 30
-- Room for every lift's strength and Scale plus a few technique stats.
local MAX_ROWS = 9
-- Seconds after the last gain before the panel fades out (training gains come every 10 s, so it stays while training).
local HIDE_AFTER = 20
local FADE_SECONDS = 0.6
local COUNT_SECONDS = 0.5
-- A training row pops a floating number each time its total passes another step.
local POP_STEP = 0.1
local POP_SECONDS = 1.7
local POP_RISE = 60
local POP_HEIGHT = 66
-- The gap between pops, as a share of a pop's time: long enough for the last one to rise clear of the next.
local POP_GAP_SHARE = 0.3
local GREEN = Color3.fromRGB(96, 220, 120)

local started = false

type Row = {
	frame: Frame,
	amount: TextLabel,
	scale: UIScale,
	shown: NumberValue,
	total: number,
	unit: string,
	popped: number,
	lastAt: number,
}

-- "+0.347 kg", "+2.50 kg", "+12.5 kg"; technique (no unit) "+0.84".
local function amountText(amount: number, unit: string): string
	local decimals = if amount < 1 then 3 elseif amount < 10 then 2 else 1
	local number = string.format("+%." .. decimals .. "f", amount)
	return if unit ~= "" then number .. " " .. unit else number
end

local function outline(label: TextLabel, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = C.ink
	stroke.Thickness = thickness
	stroke.Parent = label
end

local function isGain(gain: any): boolean
	return typeof(gain) == "table" and typeof(gain.stat) == "string" and typeof(gain.kind) == "string"
		and typeof(gain.label) == "string" and typeof(gain.unit) == "string" and typeof(gain.amount) == "number"
		and gain.amount == gain.amount and gain.amount > 0 and gain.amount < math.huge
end

function GainDisplay.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remote = GainRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Gains"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	UIStyle.fitToScreen(gui)

	-- The panel: a CanvasGroup so it fades as one piece.
	local panel = Instance.new("CanvasGroup")
	panel.Name = "SessionGains"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, -40)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, TITLE_HEIGHT + 8)
	panel.BackgroundColor3 = C.ink
	panel.BackgroundTransparency = 0.25
	panel.GroupTransparency = 1
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	UIStyle.stroke(panel, C.yellow, 2)
	local title = UIStyle.text(panel, "Title", UDim2.fromOffset(12, 4), UDim2.new(1, -24, 0, TITLE_HEIGHT - 4), SIZES.small,
		C.yellow, UIStyle.heading())
	title.TextWrapped = false
	title.Text = "SESSION GAINS"
	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, TITLE_HEIGHT)
	list.Size = UDim2.new(1, 0, 1, -TITLE_HEIGHT)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- The floating numbers rise in this holder, just left of the panel (its own frame, so the screen fitting scales it
	-- once and leaves each number alone).
	local pops = Instance.new("Frame")
	pops.Name = "Pops"
	pops.BackgroundTransparency = 1
	pops.AnchorPoint = Vector2.new(1, 1)
	pops.Position = UDim2.new(1, -PANEL_WIDTH - 28, 0.5, 30)
	pops.Size = UDim2.fromOffset(280, POP_HEIGHT)
	pops.Parent = gui

	-- Sounds: the crate's Tick (quiet) for training pops, its Big sting for meet gains.
	local function sound(name: string, id: string, volume: number): Sound
		local made = Instance.new("Sound")
		made.Name = name
		made.SoundId = id
		made.Volume = volume
		made.Parent = gui
		return made
	end
	local tickSound = sound("TrainingPop", GearStatsConfig.Sounds.Tick, 0.35)
	local bigSound = sound("MeetGain", GearStatsConfig.Sounds.Big, 0.6)

	gui.Parent = player:WaitForChild("PlayerGui")

	local rows: { [string]: Row } = {}
	local order = 0
	local lastGainAt = -math.huge

	local function resize()
		local count = 0
		for _ in pairs(rows) do
			count += 1
		end
		panel.Size = UDim2.fromOffset(PANEL_WIDTH, TITLE_HEIGHT + count * ROW_HEIGHT + 8)
	end

	local function showPanel()
		lastGainAt = os.clock()
		if not panel.Visible or panel.GroupTransparency > 0 then
			panel.Visible = true
			TweenService:Create(panel, TweenInfo.new(FADE_SECONDS * 0.5), { GroupTransparency = 0 }):Play()
		end
		local stamp = lastGainAt
		task.delay(HIDE_AFTER, function()
			if lastGainAt == stamp then
				local fade = TweenService:Create(panel, TweenInfo.new(FADE_SECONDS), { GroupTransparency = 1 })
				fade:Play()
				fade.Completed:Wait()
				if lastGainAt == stamp then
					panel.Visible = false
				end
			end
		end)
	end

	local function rowFor(key: string, gain: GainRemotes.Gain): Row
		local existing = rows[key]
		if existing then
			return existing
		end
		-- Full: the row that grew longest ago makes room.
		local count, oldestKey, oldestAt = 0, nil, math.huge
		for otherKey, other in pairs(rows) do
			count += 1
			if other.lastAt < oldestAt then
				oldestKey, oldestAt = otherKey, other.lastAt
			end
		end
		if count >= MAX_ROWS and oldestKey then
			rows[oldestKey].frame:Destroy()
			rows[oldestKey] = nil
		end
		order += 1
		local frame = Instance.new("Frame")
		frame.Name = "Row_" .. key
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		frame.LayoutOrder = order
		frame.Parent = list
		local scale = Instance.new("UIScale")
		scale.Parent = frame
		local bar = UIStyle.frame(frame, "Lift", UDim2.fromOffset(12, 7), UDim2.fromOffset(5, ROW_HEIGHT - 14),
			UIStyle.LiftColours[gain.lift] or C.yellow)
		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = bar
		local name = UIStyle.text(frame, "Name", UDim2.fromOffset(24, 0), UDim2.new(0.64, -24, 1, 0), SIZES.small, C.white,
			UIStyle.heading())
		name.TextWrapped = false
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = gain.label
		local amount = UIStyle.text(frame, "Amount", UDim2.new(0.64, 0, 0, 0), UDim2.new(0.36, -12, 1, 0), SIZES.small, GREEN,
			UIStyle.heading(), Enum.TextXAlignment.Right)
		amount.TextWrapped = false
		local shown = Instance.new("NumberValue")
		local row: Row = { frame = frame, amount = amount, scale = scale, shown = shown, total = 0, unit = gain.unit,
			popped = 0, lastAt = os.clock() }
		shown.Changed:Connect(function(value)
			amount.Text = amountText(value, row.unit)
		end)
		rows[key] = row
		resize()
		return row
	end

	-- A big number rising beside the panel, in the lift's colour. (Not over the head: the training menu and other
	-- screens cover it, and Roblox draws screen menus over 3D labels; tested 2026-11-19.)
	local activePops: { { holder: Frame, pushed: number } } = {}
	local function popSeconds(): number
		if RunService:IsStudio() then
			local slow = workspace:GetAttribute("StudioGainPopSeconds")
			if typeof(slow) == "number" and slow > 0 and slow < 120 then
				return slow
			end
		end
		return POP_SECONDS
	end
	local function pop(text: string, label: string, colour: Color3)
		local seconds = popSeconds()
		-- Pops still rising are pushed up out of the new one's way (the holder moves; the riser inside rises).
		for _, other in ipairs(activePops) do
			other.pushed += POP_HEIGHT
			TweenService:Create(other.holder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(1, 0, 1, -other.pushed) }):Play()
		end
		local holder = Instance.new("Frame")
		holder.Name = "GainPop"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, 0, 1, 0)
		holder.Size = UDim2.new(1, 0, 0, POP_HEIGHT)
		holder.Parent = pops
		local entry = { holder = holder, pushed = 0 }
		table.insert(activePops, entry)
		local riser = Instance.new("Frame")
		riser.Name = "Riser"
		riser.BackgroundTransparency = 1
		riser.Size = UDim2.fromScale(1, 1)
		riser.Parent = holder
		local number = UIStyle.text(riser, "Amount", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 42), 34, colour,
			UIStyle.heading(), Enum.TextXAlignment.Right)
		number.TextWrapped = false
		number.Text = text
		outline(number, 3)
		local under = UIStyle.text(riser, "Label", UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 24), 20, C.white,
			UIStyle.heading(), Enum.TextXAlignment.Right)
		under.TextWrapped = false
		under.Text = label
		outline(under, 2)
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = riser
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(riser, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(0, -POP_RISE) }):Play()
		local fade = TweenInfo.new(seconds * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, seconds * 0.55)
		for _, piece in ipairs({ number, under }) do
			TweenService:Create(piece, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(piece:FindFirstChildOfClass("UIStroke") :: UIStroke, fade, { Transparency = 1 }):Play()
		end
		task.delay(seconds + 0.1, function()
			local at = table.find(activePops, entry)
			if at then
				table.remove(activePops, at)
			end
			holder:Destroy()
		end)
	end

	-- Pops wait their turn, so a meet's several gains rise one after another.
	local queue: { () -> () } = {}
	local busy = false
	local function queuePop(show: () -> ())
		table.insert(queue, show)
		if busy then
			return
		end
		busy = true
		while #queue > 0 do
			(table.remove(queue, 1) :: () -> ())()
			task.wait(popSeconds() * POP_GAP_SHARE)
		end
		busy = false
	end

	remote.OnClientEvent:Connect(function(news: any)
		if typeof(news) ~= "table" or typeof(news.source) ~= "string" or typeof(news.gains) ~= "table" then
			return
		end
		local training = news.source == "Training"
		local anyGain = false
		for _, gain in ipairs(news.gains) do
			if not isGain(gain) then
				continue
			end
			anyGain = true
			local key = gain.kind .. ":" .. gain.stat
			local row = rowFor(key, gain)
			row.total += gain.amount
			row.lastAt = os.clock()
			TweenService:Create(row.shown, TweenInfo.new(COUNT_SECONDS, Enum.EasingStyle.Quad), { Value = row.total }):Play()
			row.scale.Scale = 1.12
			TweenService:Create(row.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			row.amount.TextColor3 = C.white
			TweenService:Create(row.amount, TweenInfo.new(0.5), { TextColor3 = GREEN }):Play()
			local colour = UIStyle.LiftColours[gain.lift] or C.yellow
			if training then
				-- Each step passed: "+0.1 kg" (several at once if a big tick passed more than one).
				local steps = math.floor(row.total / POP_STEP + 1e-9)
				if steps > row.popped then
					local passed = steps - row.popped
					row.popped = steps
					task.spawn(queuePop, function()
						pop(amountText(passed * POP_STEP, gain.unit), gain.label, colour)
						tickSound:Play()
					end)
				end
			else
				row.popped = math.floor(row.total / POP_STEP + 1e-9)
				task.spawn(queuePop, function()
					pop(amountText(gain.amount, gain.unit), gain.label, colour)
				end)
			end
		end
		if anyGain then
			showPanel()
			if not training then
				bigSound:Play()
			end
		end
	end)
end

return GainDisplay
