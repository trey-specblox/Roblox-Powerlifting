--!strict
--[[
	KitchenSignTimer
	Client / World

	Your own cook's time left, floating on top of the Kitchen's floating name outside (user 2026-11-21: "include if a
	player has something cooking, how much time is left on top"): "YOUR STEAKS  4:32" counting down, then "YOUR STEAKS
	ARE READY!", hidden while nothing is cooking. In the floating sign's style (the slanted dark tag with a white edge,
	words outlined dark). Each player sees only their own (it lives in their PlayerGui).

	Read from the player's own KitchenSteaks / KitchenReadyAt attributes (server time; KitchenPans writes them), so it
	works from anywhere, even while the far-away hall isn't streamed in.

	PERFORMANCE: one BillboardGui, rewritten once a second.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local KitchenSignTimer = {}

local WIDTH, HEIGHT = 30, 5.5 -- studs
local started = false

function KitchenSignTimer.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local anchor = Workspace:WaitForChild("KitchenEntrance", math.huge):WaitForChild("KitchenSignAnchor", math.huge) :: BasePart
	local sign = anchor:WaitForChild("FloatingSign", 30) :: BillboardGui?
	local signHeight = if sign then sign.Size.Y.Scale else 14

	local gui = Instance.new("BillboardGui")
	gui.Name = "KitchenSignTimer"
	gui.Adornee = anchor
	gui.Size = UDim2.fromScale(WIDTH, HEIGHT)
	gui.StudsOffsetWorldSpace = Vector3.new(0, signHeight / 2 + HEIGHT / 2 + 2.5, 0) -- (+1 touched the name in Studio)
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui.MaxDistance = 260 -- (as the sign under it)
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local slab = Instance.new("Frame")
	slab.Name = "Tag"
	slab.AnchorPoint = Vector2.new(0.5, 0.5)
	slab.Position = UDim2.fromScale(0.5, 0.5)
	slab.Size = UDim2.fromScale(0.96, 0.86)
	slab.BackgroundColor3 = C.ink
	slab.BorderSizePixel = 0
	slab.Rotation = -3
	slab.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Color = C.yellow
	edge.Thickness = 4
	edge.Parent = slab
	local label = Instance.new("TextLabel")
	label.Name = "Time"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.TextScaled = true
	label.FontFace = UIStyle.heading()
	label.TextColor3 = C.white
	label.Parent = slab
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(0, 0, 0)
	outline.Thickness = 2
	outline.Parent = label
	gui.Parent = player:WaitForChild("PlayerGui")

	while true do
		local steaks = player:GetAttribute("KitchenSteaks")
		local readyAt = player:GetAttribute("KitchenReadyAt")
		if typeof(steaks) == "number" and steaks >= 1 and typeof(readyAt) == "number" then
			local left = readyAt - Workspace:GetServerTimeNow()
			-- (a meet meal cooking: KitchenKind "Meal", user 2026-11-23)
			local what = if player:GetAttribute("KitchenKind") == "Meal" then "MEET MEAL" else "STEAKS"
			if left > 0 then
				label.Text = "YOUR " .. what .. "  " .. KitchenConfig.clockText(left)
				label.TextColor3 = C.white
			else
				label.Text = if what == "STEAKS" then "YOUR STEAKS ARE READY!" else "YOUR MEET MEAL IS READY!"
				label.TextColor3 = Color3.fromRGB(110, 230, 130)
			end
			gui.Enabled = true
		else
			gui.Enabled = false
		end
		task.wait(1)
	end
end

return KitchenSignTimer
