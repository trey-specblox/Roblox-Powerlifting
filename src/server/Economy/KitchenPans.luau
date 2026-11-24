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

	PERFORMANCE: 40 zones of three shared meshes (about 5,400 triangles a zone); every mesh is decor (no collision,
	touch or query), with 15 hidden plain blocks a zone for collision (the pan's wall and floor, its handle, the
	clock's post: 600 in all, anchored and never touched by scripts). The steak exists only while something is cooking.
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
local refreshToken: { [Player]: number } = {}

-- The centre (on the floor, facing -Z) of zone `index`, in rows of ZoneColumns from the hall's front left.
local function zoneCentre(index: number): CFrame
	return KitchenConfig.HallOrigin * KitchenConfig.zoneSpot(index)
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

-- A hidden anchored solid piece of a zone (the pan's meshes are decor).
local function solidPart(parent: Instance, name: string, size: Vector3, at: CFrame, cylinder: boolean?)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = if cylinder then Enum.PartType.Cylinder else Enum.PartType.Block
	part.Anchored = true
	part.Transparency = 1
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = at
	part.Parent = parent
end

--[[
	The zone's collision (user 2026-11-21: "Make furniture solid"; before this you walked through the pans). A real
	pan shape, not a lid: a ring of wall blocks round the rim and a round floor inside, so a lifter can jump in and
	stand on the pan's floor; plus the handle and the clock's post. Sizes from the pan model
	(art/scripts/build_kitchen_pan_01.py) at KitchenConfig.PanScale, sunk PanSink into the floor.
]]
local RIM_BLOCKS = 12
local function buildSolids(model: Model, centre: CFrame, pan: Model)
	local scale, sink = KitchenConfig.PanScale, KitchenConfig.PanSink
	local rimTop = 4.7 * scale - sink -- the rolled rim's top above the hall floor
	local floorTop = KitchenConfig.PanFloorHeight * scale - sink
	local outer, inner = 6.35 * scale, 5.6 * scale
	local solids = Instance.new("Folder")
	solids.Name = "Solids"
	-- The pan's floor (a cylinder lies along its X: stood up on end).
	solidPart(solids, "PanFloor", Vector3.new(floorTop + 1, 2 * inner, 2 * inner),
		centre * CFrame.new(0, (floorTop - 1) / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), true)
	-- The wall: blocks round the rim, each wide enough to meet its neighbours at the outside.
	local thick = outer - inner
	local wide = 2 * outer * math.tan(math.pi / RIM_BLOCKS)
	for k = 1, RIM_BLOCKS do
		local turn = CFrame.Angles(0, 2 * math.pi * k / RIM_BLOCKS, 0)
		solidPart(solids, "PanWall", Vector3.new(wide, rimTop, thick),
			centre * turn * CFrame.new(0, rimTop / 2, -(inner + thick / 2)))
	end
	-- The handle (its grip is 11.8 from the pan's axis in the model, the stem from 6.2), wherever the pan is turned.
	local grip = pan:FindFirstChild("GiantPan_Grip", true)
	if grip and grip:IsA("BasePart") then
		local flat = Vector3.new(grip.Position.X - centre.Position.X, 0, grip.Position.Z - centre.Position.Z)
		if flat.Magnitude > 1 then
			local from, to = 6.0 * scale, 14.4 * scale
			local middle = centre.Position + flat.Unit * (from + to) / 2 + Vector3.new(0, grip.Position.Y - centre.Position.Y - 0.4, 0)
			solidPart(solids, "PanHandle", Vector3.new(1.3 * scale, 1.5 * scale, to - from),
				CFrame.lookAt(middle, middle + flat.Unit))
		end
	end
	-- The clock's post (the clock itself is far overhead).
	local post = 13.6 * KitchenConfig.ClockScale
	solidPart(solids, "ClockPost", Vector3.new(1.2, post, 1.2),
		centre * CFrame.new(0, post / 2, KitchenConfig.ClockBehind * scale))
	solids.Parent = model
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
	-- No shadows: KitchenLights keeps the sun out of the hall and its lights cast none, so these 360 casters were
	-- drawn into the sun's shadow picture for nothing (audit 2026-11-21).
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end
	buildSolids(model, centre, pan)
	model.WorldPivot = centre
	-- The whole zone streams in at once (the clocks need the face as soon as the zone is there).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag(KitchenPans.ZoneTag)
	model.Parent = folder
	return { index = index, model = model, centre = centre, owner = nil, steak = nil }
end

-- The zone's big steak for a cook of `steaks` (none for 0). `kind` "Meal" (user 2026-11-23): while it cooks, the PILE of
-- food on the pan, no plate ("MealPile": "Plate should not be cooked with the food"); once it is ready, the plate
-- ("MeetMeal"), sized the same way. `ready`: whether the cook is done.
local function showSteak(zone: Zone, steaks: number, kind: string?, ready: boolean?)
	local mealName = if ready then "MeetMeal" else "MealPile"
	local want = if kind == "Meal" then mealName else "BigSteak"
	if steaks < 1 or (zone.steak and zone.steak:GetAttribute("Item") ~= want) then
		if zone.steak then
			zone.steak:Destroy()
			zone.steak = nil
		end
		if steaks < 1 then
			return
		end
	end
	local steak = zone.steak
	if steak == nil then
		steak = RoomProps.propCopy(want, 1)
		if steak == nil then
			return
		end
		steak.Name = if kind == "Meal" then mealName else "Steak"
		steak:SetAttribute("Item", want)
		for _, part in ipairs(steak:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CastShadow = false -- (as the pans: no sun in the hall)
			end
		end
		zone.steak = steak
	end
	local s = steak :: Model
	local length = steakModelLength
	if kind == "Meal" then
		s:ScaleTo(1)
		length = s:GetExtentsSize().X
	elseif steakModelLength <= 0 then
		s:ScaleTo(1)
		steakModelLength = s:GetExtentsSize().X
		length = steakModelLength
	end
	s:ScaleTo(KitchenConfig.steakLength(steaks) / math.max(length, 0.1))
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
	local kind = if view and view.kind == "Meal" then "Meal" else "Steak"
	zone.model:SetAttribute("Steaks", steaks)
	zone.model:SetAttribute("Kind", kind)
	zone.model:SetAttribute("ReadyAt", if view and steaks >= 1 then os.time() + view.readyIn else 0)
	-- (on the player too, for their own timer on top of the Kitchen's sign outside: KitchenSignTimer)
	player:SetAttribute("KitchenSteaks", steaks)
	player:SetAttribute("KitchenKind", kind)
	player:SetAttribute("KitchenReadyAt", if view and steaks >= 1 then os.time() + view.readyIn else 0)
	local readyIn = if view then view.readyIn else 0
	showSteak(zone, steaks, kind, readyIn <= 0)
	-- A meal still cooking swaps its pile for the plate the moment it is ready (one wait per cook: a newer refresh
	-- replaces it).
	refreshToken[player] = (refreshToken[player] or 0) + 1
	if kind == "Meal" and steaks >= 1 and readyIn > 0 then
		local mine = refreshToken[player]
		task.delay(readyIn + 0.5, function()
			if refreshToken[player] == mine and player.Parent then
				KitchenPans.refresh(player)
			end
		end)
	end
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
	refreshToken[player] = nil
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
	-- The floor's collision under the whole restaurant (hidden by KitchenBuilding once the hall's shell is there: W
	-- Chews' fancy front, kitchen and back room, plan x -287..287, y -112..339; the pans sink into it).
	local floor = Instance.new("Part")
	floor.Name = "HallFloor_Temporary"
	floor.Anchored = true
	floor.Size = Vector3.new(574, 2, 451)
	floor.CFrame = KitchenConfig.HallOrigin * KitchenConfig.planSpot(0, 113.5, -1)
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
	-- One copy of the big steak for the clients (the chef's steak picker shows it growing with the number).
	local shared = Instance.new("Folder")
	shared.Name = "KitchenModels"
	-- (and the chef scene's props: KitchenScene; and the meet meal's plate for the chef's picker: KitchenMenu)
	for _, item in ipairs({ "BigSteak", "MeetMeal", "MeatBag", "Cow", "MeatMound", "MeatPress", "MincePile", "MeatChunk",
		-- (the meet meal scene's: the hens and florets out of the dispenser, the food pile on the pan)
		"LiveChicken", "BroccoliBit", "MealPile" }) do
		local model = RoomProps.propCopy(item, 1)
		if model then
			model.Name = item
			model.Parent = shared
		end
	end
	shared.Parent = ReplicatedStorage
	for _, player in ipairs(Players:GetPlayers()) do
		assign(player)
	end
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
end

return KitchenPans
