--!strict
--[[
	KitchenPans
	Server / Economy

	The Kitchen's pan hall (GAME_DESIGN §40.7, user 2026-11-19): every player in the server gets their own pan zone
	(one per player, up to KitchenConfig.PanZones), handed out when they join and freed when they leave. A zone is the
	giant pan (KitchenPan_01 GiantPan) with the giant clock behind it (PanClock); while the player's cook is in, the pan
	holds ONE big steak (BigSteak) sized by KitchenConfig.steakLength (user: "hugee like a person size").

	Each zone model carries what the clients draw (KitchenClocks): attributes Owner (the player's name, "" when free),
	Steaks (0 = nothing cooking) and ReadyAt (server unix time). The cook itself lives in the save (ProfileOperations);
	refresh(player) re-reads it after cooking, eating and joining.

	PERFORMANCE: 40 zones of three shared meshes (about 5,400 triangles a zone); every piece is decor (no collision,
	touch or query). The steak exists only while something is cooking.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))

local ServerFolder = script.Parent.Parent
local PlayerDataService = require(ServerFolder:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local RoomProps = require(ServerFolder:WaitForChild("World"):WaitForChild("RoomProps"))

local KitchenPans = {}

-- The tag the clients look for on a zone.
KitchenPans.ZoneTag = "KitchenPanZone"

type Zone = { index: number, model: Model, centre: CFrame, owner: Player?, steak: Model? }

local started = false
local zones: { Zone } = {}
local byPlayer: { [Player]: Zone } = {}
local steakModelLength = 0

-- The centre (on the floor, facing -Z) of zone `index`, in rows of ZoneColumns from the hall's front left.
local function zoneCentre(index: number): CFrame
	local columns = KitchenConfig.ZoneColumns
	local column = (index - 1) % columns
	local row = (index - 1) // columns
	local pitch = KitchenConfig.ZonePitch
	local x = (column - (columns - 1) / 2) * pitch.X
	return KitchenConfig.HallOrigin * CFrame.new(x, 0, 30 + row * pitch.Y)
end

-- Puts the pan copy so its stand's axis is on `centre` (the pan's own pivot is off to the side: the handle).
local function placePan(pan: Model, centre: CFrame)
	pan:ScaleTo(KitchenConfig.PanScale)
	pan:PivotTo(centre)
	local stand = pan:FindFirstChild("GiantPan_Stand")
	if stand and stand:IsA("BasePart") then
		local off = centre:PointToObjectSpace(stand.Position)
		pan:PivotTo(centre * CFrame.new(-off.X, 0, -off.Z))
	end
end

local function buildZone(folder: Folder, index: number): Zone?
	local pan = RoomProps.propCopy("GiantPan", 1)
	local clock = RoomProps.propCopy("PanClock", 1)
	if pan == nil or clock == nil then
		return nil
	end
	local centre = zoneCentre(index)
	local model = Instance.new("Model")
	model.Name = string.format("PanZone_%02d", index)
	model:SetAttribute("Owner", "")
	model:SetAttribute("Steaks", 0)
	model:SetAttribute("ReadyAt", 0)
	model:SetAttribute("Zone", index)
	placePan(pan, centre * CFrame.new(0, -KitchenConfig.PanSink, 0))
	pan.Parent = model
	clock:ScaleTo(KitchenConfig.ClockScale)
	clock:PivotTo(centre * CFrame.new(0, 0, KitchenConfig.ClockBehind * KitchenConfig.PanScale))
	clock.Parent = model
	model.WorldPivot = centre
	-- The whole zone streams in at once (the clocks need the face as soon as the zone is there).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(KitchenPans.ZoneTag)
	model.Parent = folder
	return { index = index, model = model, centre = centre, owner = nil, steak = nil }
end

-- The zone's big steak for a cook of `steaks` (none for 0).
local function showSteak(zone: Zone, steaks: number)
	if steaks < 1 then
		if zone.steak then
			zone.steak:Destroy()
			zone.steak = nil
		end
		return
	end
	local steak = zone.steak
	if steak == nil then
		steak = RoomProps.propCopy("BigSteak", 1)
		if steak == nil then
			return
		end
		steak.Name = "Steak"
		zone.steak = steak
	end
	local s = steak :: Model
	if steakModelLength <= 0 then
		s:ScaleTo(1)
		steakModelLength = s:GetExtentsSize().X
	end
	s:ScaleTo(KitchenConfig.steakLength(steaks) / math.max(steakModelLength, 0.1))
	-- On the pan's floor, a little turned so it doesn't sit square.
	s:PivotTo(zone.centre * CFrame.new(0, KitchenConfig.PanFloorHeight * KitchenConfig.PanScale - KitchenConfig.PanSink, 0)
		* CFrame.Angles(0, math.rad(18), 0))
	s.Parent = zone.model
end

--[[
	Re-reads `player`'s cook and shows it on their zone: the steak, and the Steaks / ReadyAt attributes the clocks read.
	Called by KitchenService after cooking or eating, and on joining.
]]
function KitchenPans.refresh(player: Player)
	local zone = byPlayer[player]
	if zone == nil then
		return
	end
	local view = PlayerDataService.getKitchen(player)
	local steaks = if view then view.steaks else 0
	zone.model:SetAttribute("Steaks", steaks)
	zone.model:SetAttribute("ReadyAt", if view and steaks >= 1 then os.time() + view.readyIn else 0)
	showSteak(zone, steaks)
end

-- The zone `player` has, or nil.
function KitchenPans.zoneOf(player: Player): Model?
	local zone = byPlayer[player]
	return if zone then zone.model else nil
end

local function assign(player: Player)
	if byPlayer[player] then
		return
	end
	for _, zone in ipairs(zones) do
		if zone.owner == nil then
			zone.owner = player
			byPlayer[player] = zone
			zone.model:SetAttribute("Owner", player.DisplayName)
			player:SetAttribute("KitchenZone", zone.index)
			task.spawn(function()
				if PlayerDataService.waitForData(player) then
					KitchenPans.refresh(player)
				end
			end)
			return
		end
	end
	warn(string.format("[KitchenPans] no free pan zone for %s", player.Name))
end

local function release(player: Player)
	local zone = byPlayer[player]
	if zone == nil then
		return
	end
	byPlayer[player] = nil
	zone.owner = nil
	zone.model:SetAttribute("Owner", "")
	zone.model:SetAttribute("Steaks", 0)
	zone.model:SetAttribute("ReadyAt", 0)
	showSteak(zone, 0)
end

function KitchenPans.start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "KitchenHall"
	folder.Parent = Workspace
	-- TEMPORARY: a plain floor under the zones until the hall itself is modelled in Blender (the pans sink into it).
	local columns = KitchenConfig.ZoneColumns
	local rows = math.ceil(KitchenConfig.PanZones / columns)
	local pitch = KitchenConfig.ZonePitch
	local floor = Instance.new("Part")
	floor.Name = "HallFloor_Temporary"
	floor.Anchored = true
	floor.Size = Vector3.new(columns * pitch.X + 40, 2, rows * pitch.Y + 80)
	floor.CFrame = KitchenConfig.HallOrigin * CFrame.new(0, -1, 30 + (rows - 1) * pitch.Y / 2)
	floor.Color = Color3.fromRGB(196, 186, 170)
	floor.Material = Enum.Material.Concrete
	floor.Parent = folder
	for index = 1, KitchenConfig.PanZones do
		local zone = buildZone(folder, index)
		if zone == nil then
			warn("[KitchenPans] the pan models didn't load; no pan zones")
			return
		end
		table.insert(zones, zone)
		if index % 8 == 0 then
			task.wait()
		end
	end
	print(string.format("[KitchenPans] %d pan zones ready at %s", #zones, tostring(KitchenConfig.HallOrigin.Position)))
	for _, player in ipairs(Players:GetPlayers()) do
		assign(player)
	end
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
end

return KitchenPans
