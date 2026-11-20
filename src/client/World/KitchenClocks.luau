--!strict
--[[
	KitchenClocks
	Client / World

	The giant clocks over the Kitchen's pans (GAME_DESIGN §40.7, user 2026-11-19: "on top of the pan is the giant clock
	letting the lifter know when its done"). Every pan zone (KitchenPans tags them) has a clock whose white face
	(PanClock_Face) shows:

		- the owner's name, so everyone can find their own pan
		- the time left, counting down; "READY!" once it's done; "EMPTY" when nothing is cooking; "FREE" with no owner

	Read from the zone's attributes (Owner, Steaks, ReadyAt in server time). Drawn on this screen only (the SurfaceGuis
	live in PlayerGui), so nothing replicates.

	PERFORMANCE: one SurfaceGui per zone; only zones within DRAW_DISTANCE of the camera update, once a second.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local KitchenClocks = {}

local ZONE_TAG = "KitchenPanZone"
local DRAW_DISTANCE = 260

local started = false

type Clock = { zone: Model, face: BasePart, name: TextLabel, time: TextLabel }

function KitchenClocks.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local holder = Instance.new("Folder")
	holder.Name = "KitchenClocks"
	holder.Parent = player:WaitForChild("PlayerGui")

	local clocks: { [Model]: Clock } = {}

	local function draw(clock: Clock)
		local zone = clock.zone
		local owner = zone:GetAttribute("Owner")
		local steaks = zone:GetAttribute("Steaks")
		local readyAt = zone:GetAttribute("ReadyAt")
		local mine = owner == player.DisplayName and owner ~= ""
		clock.name.Text = if typeof(owner) == "string" and owner ~= "" then string.upper(owner) else ""
		clock.name.TextColor3 = if mine then C.yellow else C.white
		if typeof(owner) ~= "string" or owner == "" then
			clock.time.Text = "FREE"
			clock.time.TextColor3 = C.muted
		elseif typeof(steaks) ~= "number" or steaks < 1 then
			clock.time.Text = "EMPTY"
			clock.time.TextColor3 = C.muted
		else
			local left = (if typeof(readyAt) == "number" then readyAt else 0) - Workspace:GetServerTimeNow()
			if left <= 0 then
				clock.time.Text = "READY!"
				clock.time.TextColor3 = Color3.fromRGB(96, 220, 120)
			else
				clock.time.Text = KitchenConfig.clockText(left)
				clock.time.TextColor3 = C.ink
			end
		end
	end

	local add: (Instance) -> ()
	function add(zone: Instance)
		if not zone:IsA("Model") or clocks[zone] then
			return
		end
		local face = zone:FindFirstChild("PanClock_Face", true)
		if face == nil or not face:IsA("BasePart") then
			-- The hall is far away, so its parts stream in after the zone itself: try again when the face arrives.
			if zone:GetAttribute("ClockWaiting") ~= true then
				zone:SetAttribute("ClockWaiting", true)
				local waiting: RBXScriptConnection
				waiting = zone.DescendantAdded:Connect(function(added)
					if added.Name == "PanClock_Face" then
						waiting:Disconnect()
						zone:SetAttribute("ClockWaiting", nil)
						task.defer(add, zone)
					end
				end)
			end
			return
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = zone.Name
		gui.Adornee = face
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.MaxDistance = DRAW_DISTANCE
		gui.Parent = holder
		local name = UIStyle.text(gui, "Owner", UDim2.fromScale(0.15, 0.2), UDim2.fromScale(0.7, 0.14), 40, C.white,
			UIStyle.heading())
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextStrokeColor3 = C.ink
		name.TextStrokeTransparency = 0
		local time = UIStyle.text(gui, "Time", UDim2.fromScale(0.1, 0.38), UDim2.fromScale(0.8, 0.28), 90, C.ink,
			UIStyle.heading())
		time.TextScaled = true
		time.TextXAlignment = Enum.TextXAlignment.Center
		local clock: Clock = { zone = zone, face = face, name = name, time = time }
		clocks[zone] = clock
		draw(clock)
		zone.AttributeChanged:Connect(function()
			draw(clock)
		end)
	end

	for _, zone in ipairs(CollectionService:GetTagged(ZONE_TAG)) do
		task.spawn(add, zone)
	end
	CollectionService:GetInstanceAddedSignal(ZONE_TAG):Connect(function(zone)
		task.spawn(add, zone)
	end)
	CollectionService:GetInstanceRemovedSignal(ZONE_TAG):Connect(function(zone)
		local clock = clocks[zone :: Model]
		if clock then
			clocks[zone :: Model] = nil
			local gui = holder:FindFirstChild(zone.Name)
			if gui then
				gui:Destroy()
			end
		end
	end)

	-- The countdowns, once a second, for the clocks near the camera.
	task.spawn(function()
		while true do
			task.wait(1)
			local camera = Workspace.CurrentCamera
			local at = if camera then camera.CFrame.Position else Vector3.zero
			for _, clock in pairs(clocks) do
				if clock.face.Parent and (clock.face.Position - at).Magnitude < DRAW_DISTANCE then
					draw(clock)
				end
			end
		end
	end)
end

return KitchenClocks
