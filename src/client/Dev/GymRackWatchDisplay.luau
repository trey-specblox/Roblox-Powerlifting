--!strict
--[[
	GymRackWatchDisplay
	Client / Dev

	DEV TOOL, NOT GAMEPLAY. Checkpoint 6D.2a. Shows the server-side
	GymRackWatchProbe's PASS/FAIL results in this player's window, for
	multi-client Studio tests where a player window cannot see the server's
	Output.

	DISPLAY ONLY. It reads ReplicatedStorage.GymRackWatchProbeResults, a folder
	of text values that ONLY the server writes (the probe creates it). It sends
	nothing to the server and there is no remote: a client cannot submit, change
	or delete a result for anyone else.

	It does nothing unless BOTH:
	  - the game runs in Roblox Studio, and
	  - the probe is running (its ENABLED switch is true), so the folder exists.
	With the probe off, it waits briefly for the folder, finds none and stops:
	no GUI, no connections. F8 hides or shows the panel.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GymRackWatchDisplay = {}

local RESULTS_FOLDER_NAME = "GymRackWatchProbeResults"
local WAIT_FOR_PROBE_SECONDS = 20
local TOGGLE_KEY = Enum.KeyCode.F8

local KIND_COLORS: { [string]: Color3 } = {
	PASS = Color3.fromRGB(110, 220, 120),
	FAIL = Color3.fromRGB(255, 95, 95),
	WARN = Color3.fromRGB(255, 190, 80),
	INFO = Color3.fromRGB(200, 200, 205),
}

local started = false

local function buildPanel(): (ScreenGui, TextLabel, ScrollingFrame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "GymRackWatchDisplay"
	gui.ResetOnSpawn = false -- survives the character-reset test
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -10, 0, 10)
	panel.Size = UDim2.new(0, 480, 0.6, 0)
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -12, 0, 28)
	header.Position = UDim2.new(0, 6, 0, 4)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 15
	header.TextColor3 = Color3.fromRGB(240, 240, 240)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "Rack test (dev)"
	header.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Name = "Results"
	list.Position = UDim2.new(0, 6, 0, 34)
	list.Size = UDim2.new(1, -12, 1, -40)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	return gui, header, list
end

local function show(folder: Folder)
	local player = Players.LocalPlayer
	local gui, header, list = buildPanel()
	local labels: { [Instance]: TextLabel } = {}

	local function refreshHeader()
		header.Text = string.format("Rack test (dev): %s   %d PASS   %d FAIL   [F8 hide]",
			tostring(folder:GetAttribute("WatchStation") or "?"),
			tonumber(folder:GetAttribute("Passes")) or 0,
			tonumber(folder:GetAttribute("Fails")) or 0)
	end

	local function addEntry(child: Instance)
		if not child:IsA("StringValue") or labels[child] then
			return
		end
		local kind = tostring(child:GetAttribute("Kind") or "INFO")
		local label = Instance.new("TextLabel")
		label.Name = child.Name
		label.LayoutOrder = tonumber(child.Name) or 0
		label.Size = UDim2.new(1, -8, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextSize = 13
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = KIND_COLORS[kind] or KIND_COLORS.INFO
		label.Text = string.format("%-4s %s", kind, child.Value)
		label.Parent = list
		labels[child] = label

		-- Keep the newest line in view.
		task.defer(function()
			list.CanvasPosition = Vector2.new(0, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y))
		end)
	end

	for _, child in ipairs(folder:GetChildren()) do
		addEntry(child)
	end
	folder.ChildAdded:Connect(addEntry)
	folder.ChildRemoved:Connect(function(child: Instance)
		local label = labels[child]
		if label then
			label:Destroy()
			labels[child] = nil
		end
	end)
	folder:GetAttributeChangedSignal("Passes"):Connect(refreshHeader)
	folder:GetAttributeChangedSignal("Fails"):Connect(refreshHeader)
	refreshHeader()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == TOGGLE_KEY then
			gui.Enabled = not gui.Enabled
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

--[[
	Call once from the client entry point. Returns immediately; the wait for the
	probe's folder happens in the background so nothing else is delayed.
]]
function GymRackWatchDisplay.start()
	if started or not RunService:IsStudio() then
		return
	end
	started = true

	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(RESULTS_FOLDER_NAME, WAIT_FOR_PROBE_SECONDS)
		if folder == nil or not folder:IsA("Folder") then
			return -- the probe is off: show nothing
		end
		show(folder :: Folder)
	end)
end

return GymRackWatchDisplay
