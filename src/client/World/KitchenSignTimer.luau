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

	Only while the restaurant's sign can be SEEN from the camera (user 2026-11-24, a phone: "the kitchens steak is finished
	ui on the gym don't know why that is there": from inside the gym the timer showed through the front glass while the
	wall hid the W Chews name under it, so it looked like a stray screen in the gym). A ray from the camera to the sign:
	anything solid in between (a wall, the gym's glass) hides it.

	PERFORMANCE: one BillboardGui, rewritten once a second; one short raycast (a few at most) a second.
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

	-- Whether the camera sees the sign: nothing but see-through parts between them (the restaurant's own building and the
	-- player's body don't count).
	local entrance = anchor:FindFirstAncestorOfClass("Model") or anchor.Parent
	local function inSight(): boolean
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return false
		end
		local from = camera.CFrame.Position
		local target = anchor.Position + Vector3.new(0, signHeight / 2, 0)
		local ignore: { Instance } = { entrance :: Instance }
		if player.Character then
			table.insert(ignore, player.Character)
		end
		for _ = 1, 6 do
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignore
			local hit = Workspace:Raycast(from, target - from, params)
			if hit == nil then
				return true
			end
			-- (an invisible part, or a light's lens, doesn't hide it: look past it)
			if hit.Instance.Transparency >= 0.9 then
				table.insert(ignore, hit.Instance)
			else
				return false
			end
		end
		return false
	end

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
			gui.Enabled = inSight()
		else
			gui.Enabled = false
		end
		task.wait(1)
	end
end

return KitchenSignTimer
