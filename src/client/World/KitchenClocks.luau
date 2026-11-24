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

type Clock = { zone: Model, face: BasePart, name: TextLabel, time: TextLabel, steam: ParticleEmitter?, eat: ProximityPrompt? }

-- Set by start: what eating does (KitchenMenu's remote call), given by KitchenClocks.onEat.
local eatHandler: (() -> ())? = nil

-- What pressing "Eat" on your own pan does (KitchenMenu sets it: the server eats and starts the boost).
function KitchenClocks.onEat(handler: () -> ())
	eatHandler = handler
end

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

	-- Steam over a cooking pan (more when it's ready), on this screen.
	local function steamFor(clock: Clock): ParticleEmitter?
		if clock.steam then
			return clock.steam
		end
		local body = clock.zone:FindFirstChild("GiantPan_Body", true)
		if body == nil or not body:IsA("BasePart") then
			return nil
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "KitchenSteam"
		-- (Parented first: a WorldPosition set before parenting is taken as relative to the part, miles away.)
		attachment.Parent = body
		attachment.WorldPosition = body.Position + Vector3.new(0, body.Size.Y * 0.3, 0)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(245, 245, 245))
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
		-- (Thick enough to read against a pale sky: at 0.55 and 4 a second it didn't show; Studio 2026-11-20.)
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(2, 3.5)
		emitter.Speed = NumberRange.new(4, 7)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Rate = 4
		emitter.LightInfluence = 0.3
		emitter.Enabled = false
		emitter.Parent = attachment
		-- The sizzle, looping while it cooks (heard only near the pan).
		local sizzle = Instance.new("Sound")
		sizzle.Name = "Sizzle"
		sizzle.SoundId = KitchenConfig.Sounds.Sizzle
		sizzle.Looped = true
		sizzle.Volume = 0.45
		sizzle.RollOffMode = Enum.RollOffMode.InverseTapered
		sizzle.RollOffMinDistance = 12
		sizzle.RollOffMaxDistance = 70
		sizzle.Parent = attachment
		clock.steam = emitter
		return emitter
	end

	-- The "Eat" prompt on your own pan once your steak is done (made on this screen only; the server checks the eating).
	-- RETIRED 2026-11-24 (GAME_DESIGN §42): the chef hands finished food over into the inventory, so the pan never shows
	-- the prompt any more (kept here, switched off, in case pan eating comes back).
	local PAN_EATING = false
	local function eatPromptFor(clock: Clock, show: boolean)
		if not show or not PAN_EATING then
			if clock.eat then
				clock.eat.Enabled = false
			end
			return
		end
		if clock.eat == nil then
			local body = clock.zone:FindFirstChild("GiantPan_Body", true)
			if body == nil or not body:IsA("BasePart") then
				return
			end
			-- On a point just above the pan's rim (the pan's middle is sunk below the floor, where the prompt didn't show).
			local spot = Instance.new("Attachment")
			spot.Name = "EatSpot"
			spot.Parent = body
			spot.WorldPosition = body.Position + Vector3.new(0, body.Size.Y / 2 + 1.5, 0)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "EatPrompt"
			prompt.ActionText = "Eat"
			prompt.ObjectText = "Your steak"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 26
			prompt.RequiresLineOfSight = false
			prompt.Triggered:Connect(function()
				if eatHandler then
					(eatHandler :: () -> ())()
				end
			end)
			prompt.Parent = spot
			clock.eat = prompt
		end
		(clock.eat :: ProximityPrompt).Enabled = true
	end

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
		local cooking = typeof(owner) == "string" and owner ~= "" and typeof(steaks) == "number" and steaks >= 1
		local ready = cooking and (if typeof(readyAt) == "number" then readyAt else 0) <= Workspace:GetServerTimeNow()
		local steam = if cooking then steamFor(clock) else clock.steam
		if steam then
			steam.Enabled = cooking
			steam.Rate = if ready then 26 else 12
			local sizzle = steam.Parent and steam.Parent:FindFirstChild("Sizzle")
			if sizzle and sizzle:IsA("Sound") then
				if cooking and not sizzle.IsPlaying then
					sizzle.TimePosition = math.random() * 4
					sizzle:Play()
				elseif not cooking and sizzle.IsPlaying then
					sizzle:Stop()
				end
			end
		end
		eatPromptFor(clock, mine and ready)
		if clock.eat then
			(clock.eat :: ProximityPrompt).ObjectText = if zone:GetAttribute("Kind") == "Meal" then "Your meet meal" else "Your steak"
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
