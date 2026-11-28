--!strict
--[[
	PodiumFloatSpin
	Client / Meet

	Turns and bobs what floats over the podium lifters' heads (server PodiumFloat, user 2026-11-27): the winner's big
	trophy turns slowly and bobs; a place number ("#1" "#2" "#3") only bobs, so it stays readable. Each screen does it
	for itself from the pivot the server put in the BaseCFrame attribute, so nothing is sent per frame. Looks only.

	THE TROPHY GOES INTO THE INVENTORY (user 2026-11-28: "have it where the trophy, appears to float and go towards the
	lifters inventory button. Indicating the trophy is in their inventory. Make sure it lines up with mobile as well"):
	at the trophy's FlyAt (server time), on the winner's screen (ForUserId) it leaves the world and flies, shrinking, in
	an arc into their INVENTORY button, which pulses as it lands. During the ceremony the film look hides the HUD, so a
	copy of the button is drawn exactly where the real one is (the same button with its fit-to-screen scale, in a screen
	with the same insets: phone or computer alike), and fades once the trophy is in. On everyone else's screen the
	trophy rises and fades.

	PERFORMANCE: at most 3 at a podium, one PivotTo each a frame, only while a ceremony is on; the flight is one small
	ViewportFrame for about a second.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PodiumFloatSpin = {}

local TAG = "PodiumFloat" -- PodiumFloat.Tag on the server
local TURN_SPEED = 0.9 -- radians a second
local BOB_HEIGHT = 0.25 -- studs
local BOB_SPEED = 1.6 -- radians a second
local FLY_SECONDS = 0.95 -- the flight into the button (the server swaps in "#1" 1.1 s after FlyAt)
local FLY_START_PX, FLY_END_PX = 150, 44 -- the flying trophy's size on screen, at the start and at the button
local FADE_SECONDS = 0.8 -- others' screens: it rises this long and fades
local RISE_STUDS = 3
local GHOST_HOLD = 1.4 -- the copied button stays this long after the trophy lands, then fades

local floating: { [Instance]: number } = {} -- what floats -> when it was first seen
local flying: { [Instance]: number } = {} -- trophies leaving -> when they started (others' screens: rising)
local stepping: RBXScriptConnection? = nil

-- Hides the trophy on this screen (its parts, its sparkles and its glow).
local function hideHere(trophy: Instance, amount: number)
	for _, d in ipairs(trophy:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = amount
		elseif amount >= 1 and (d:IsA("ParticleEmitter") or d:IsA("Light")) then
			(d :: any).Enabled = false
		end
	end
end

-- The real INVENTORY button (InventoryMenu: PlayerGui.Gear.Tab), or nil.
local function inventoryButton(): (GuiObject?, ScreenGui?)
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gear = gui and gui:FindFirstChild("Gear")
	local tab = gear and gear:FindFirstChild("Tab")
	if gear and gear:IsA("ScreenGui") and tab and tab:IsA("GuiObject") then
		return tab, gear
	end
	return nil, nil
end

-- A little pulse on `button` (its own fit-to-screen UIScale, if it has one, else a scale of our own).
local function pulse(button: GuiObject)
	local scale = button:FindFirstChildOfClass("UIScale")
	local made = scale == nil
	local use: UIScale = scale or Instance.new("UIScale")
	if made then
		use.Parent = button
	end
	local base = use.Scale
	local up = TweenService:Create(use, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = base * 1.18 })
	up:Play()
	up.Completed:Once(function()
		local down = TweenService:Create(use, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = base })
		down:Play()
		if made then
			down.Completed:Once(function()
				use:Destroy()
			end)
		end
	end)
end

-- The winner's screen: the trophy flies from where it floats into the INVENTORY button.
local function flyToInventory(trophy: Model)
	local realButton, realGui = inventoryButton()
	local camera = Workspace.CurrentCamera
	local pivot = trophy:GetPivot()
	-- The screen the flight is drawn on: the same insets as the HUD, so the button's copy sits on the real one.
	local screen = Instance.new("ScreenGui")
	screen.Name = "TrophyToInventory"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 60
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if realGui then
		screen.IgnoreGuiInset = realGui.IgnoreGuiInset
		screen.ScreenInsets = realGui.ScreenInsets
	end
	screen.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	-- Where the button is: the real one when the HUD shows, else a copy of it in the same place.
	local target: GuiObject? = nil
	local ghost: GuiObject? = nil
	if realButton and realGui and realGui.Enabled and realButton.Visible then
		target = realButton
	elseif realButton then
		local copy = realButton:Clone()
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		if copy:IsA("GuiButton") then
			copy.Active = false
			copy.AutoButtonColor = false
		end
		copy.Visible = true
		copy.Parent = screen
		ghost = copy
		target = copy
	end
	-- The trophy on screen: a copy of it in a ViewportFrame.
	local view = Instance.new("ViewportFrame")
	view.Name = "Trophy"
	view.BackgroundTransparency = 1
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Size = UDim2.fromOffset(FLY_START_PX, FLY_START_PX)
	view.Ambient = Color3.fromRGB(200, 190, 160)
	view.LightColor = Color3.fromRGB(255, 240, 200)
	view.ZIndex = 10
	view.Parent = screen
	local copy = trophy:Clone()
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Attachment") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.LocalTransparencyModifier = 0
		end
	end
	CollectionService:RemoveTag(copy, TAG)
	local _, size = copy:GetBoundingBox()
	copy:PivotTo(CFrame.new())
	local centre = copy:GetBoundingBox().Position
	copy.Parent = view
	local viewCamera = Instance.new("Camera")
	local reach = math.max(size.X, size.Y, size.Z) * 1.6
	viewCamera.CFrame = CFrame.lookAt(centre + Vector3.new(0, size.Y * 0.1, reach), centre)
	viewCamera.FieldOfView = 40
	viewCamera.Parent = view
	view.CurrentCamera = viewCamera
	-- From where it floats (in this screen's own coordinates) to the button's middle, in an arc.
	local point = camera:WorldToViewportPoint(pivot.Position)
	local origin = screen.AbsolutePosition
	local from = if point.Z > 0 then Vector2.new(point.X, point.Y) - origin
		else Vector2.new(screen.AbsoluteSize.X / 2, screen.AbsoluteSize.Y * 0.3)
	hideHere(trophy, 1)
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - started) / FLY_SECONDS, 0, 1)
		local to = if target then target.AbsolutePosition + target.AbsoluteSize / 2 - origin
			else Vector2.new(60, screen.AbsoluteSize.Y / 2)
		local e = u * u * (3 - 2 * u)
		-- (an arc: up and over, then down into the button)
		local mid = (from + to) / 2 + Vector2.new(0, -math.min(160, (to - from).Magnitude * 0.35))
		local a = from:Lerp(mid, e)
		local b = mid:Lerp(to, e)
		local at = a:Lerp(b, e)
		local px = FLY_START_PX + (FLY_END_PX - FLY_START_PX) * e
		view.Position = UDim2.fromOffset(at.X, at.Y)
		view.Size = UDim2.fromOffset(px, px)
		copy:PivotTo(CFrame.Angles(0, os.clock() * 3, 0))
		if u >= 1 then
			if connection then
				connection:Disconnect()
			end
			view:Destroy()
			if target then
				pulse(target)
			end
			task.delay(if ghost then GHOST_HOLD else 0.5, function()
				if ghost then
					for _, d in ipairs({ ghost, table.unpack(ghost:GetDescendants()) }) do
						if d:IsA("GuiObject") then
							TweenService:Create(d, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
						end
						if d:IsA("TextLabel") or d:IsA("TextButton") then
							TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
						elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
							TweenService:Create(d, TweenInfo.new(0.4), { ImageTransparency = 1 }):Play()
						elseif d:IsA("UIStroke") then
							TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
						end
					end
					task.wait(0.45)
				end
				screen:Destroy()
			end)
		end
	end)
end

local function step()
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	for thing, since in pairs(floating) do
		local base = thing:GetAttribute("BaseCFrame")
		if thing.Parent == nil or typeof(base) ~= "CFrame" then
			continue
		end
		local t = now - since
		local bob = CFrame.new(0, math.sin(t * BOB_SPEED) * BOB_HEIGHT, 0)
		local flyAt = thing:GetAttribute("FlyAt")
		if thing:IsA("Model") and typeof(flyAt) == "number" and serverNow >= flyAt and flying[thing] == nil then
			flying[thing] = now
			if thing:GetAttribute("ForUserId") == Players.LocalPlayer.UserId then
				flyToInventory(thing)
			end
		end
		local leaving = flying[thing]
		if leaving and thing:GetAttribute("ForUserId") ~= Players.LocalPlayer.UserId then
			-- Someone else's: it rises and fades.
			local u = math.clamp((now - leaving) / FADE_SECONDS, 0, 1)
			hideHere(thing, if u >= 1 then 1 else u)
			bob *= CFrame.new(0, RISE_STUDS * u * u, 0)
		end
		if thing:IsA("Model") then
			thing:PivotTo(base * bob * CFrame.Angles(0, t * TURN_SPEED, 0))
		elseif thing:IsA("BasePart") then
			thing.CFrame = base * bob
		end
	end
end

local function add(thing: Instance)
	floating[thing] = os.clock()
	if stepping == nil then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

local function remove(thing: Instance)
	floating[thing] = nil
	flying[thing] = nil
	if next(floating) == nil and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

function PodiumFloatSpin.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, thing in ipairs(CollectionService:GetTagged(TAG)) do
		add(thing)
	end
end

return PodiumFloatSpin
