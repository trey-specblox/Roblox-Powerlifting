--!strict
--[[
	HoldService
	Server / PlayerData

	HOLDING AN ITEM (GAME_DESIGN §42, user 2026-11-24: "all items players have in their inventory make it where you hold it
	out like how roblox has it when someone holds out a gear"; food: "just change it to where two hands are foward holding
	the plate"). From the INVENTORY a lifter holds one thing at a time: a gear piece, a Shop item, a food
	item, a medal or a trophy. It becomes a real Roblox Tool in their hand, so the game's standard animation script holds
	it out (its "toolnone" pose); food is carried in front with both hands once the carry animation
	(Carry_FoodTray) is uploaded (HoldService.CarryAnimationId; until then it is held out like the rest).

	A medal or trophy carries its WIN COUNT on the Tool (attributes WinCount, WinLabel, WinColour) for the floating counter
	every nearby player's screen draws while it is held (client HeldCounters).

	Put away automatically during a lift (LiftAttemptService.isAttemptActive), when the item is gone (eaten, scrapped),
	and on respawn. SECURITY: the key comes from the client; the server checks the player owns it in their save.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared:WaitForChild("Config"):WaitForChild("ShopConfig"))
local MeetLevelConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetLevelConfig"))
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local ShopRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("ShopRemotes"))

local ServerRoot = script.Parent.Parent
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ProfileOperations = require(script.Parent:WaitForChild("ProfileOperations"))

local HoldService = {}

-- The two-handed carry for food (Carry_FoodTray, art/scripts/carry_animations.py; uploaded 2026-11-24 with the user's OK).
-- "" = food held out like everything else. Each player's screen puts the plate between the palms (client HeldPlates).
HoldService.CarryAnimationId = "rbxassetid://107112559176114"

-- How big a held thing is (its longest side, studs).
local HELD_SIZES = { Food = 1.7, Trophy = 1.6, Medal = 1.2, Gear = 1.3 }
local CHECK_SECONDS = 0.5
local MEDAL_COLOURWAYS = { 1, 2, 3 } -- the Medal prop's colourways: gold, silver, bronze (StarterGymConfig.PropColourways.Medal)

-- Each player's held tool and the key it was made from.
local held: { [Player]: { tool: Tool, key: string, track: AnimationTrack? } } = {}

local function lazyRequire(folder: string, name: string): any
	return require(ServerRoot:WaitForChild(folder):WaitForChild(name) :: any)
end

-- The words for a medal or trophy, over it as its win count ("x3 LOCAL MEETS WON"). Only winners get one since
-- 2026-11-25 (user: counts up the "local meets won" count); older 2nd/3rd awards keep their old words ("LOCAL SILVER
-- MEDAL", "STATE RUNNER-UP").
function HoldService.awardLabel(kind: string, level: string, place: number): string
	if place == 1 then
		local name = if level == "Nationals" then "NATIONAL" else string.upper(level)
		return name .. " MEETS WON"
	end
	if kind == "Trophy" then
		local names = { "CHAMPION", "RUNNER-UP", "3RD PLACE" }
		return string.format("%s %s", string.upper(level), names[place] or "")
	end
	local metals = { "GOLD", "SILVER", "BRONZE" }
	return string.format("%s %s MEDAL", string.upper(level), metals[place] or "")
end

-- A clean, touch-free copy of `model`, scaled so its longest side is `size`.
local function prepare(model: Model, size: number): Model
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part.CastShadow = false
		elseif part:IsA("Script") or part:IsA("LocalScript") or part:IsA("ProximityPrompt") or part:IsA("ClickDetector") then
			part:Destroy()
		end
	end
	local extent = model:GetExtentsSize()
	local longest = math.max(extent.X, extent.Y, extent.Z, 0.05)
	model:ScaleTo(model:GetScale() * size / longest)
	return model
end

-- The 3D thing to hold for a gear look (the Shop's preview model in its colours, without its mannequin stand).
local function gearModel(item: any): Model?
	local previews = ReplicatedStorage:FindFirstChild(ShopRemotes.PREVIEWS_NAME)
	local template = previews and previews:FindFirstChild(item.model)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	local kept = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local suffix = string.match(part.Name, "^" .. item.model .. "_(.+)$")
			local colour = suffix and item.colours[suffix]
			if colour then
				part.Color = colour
				kept += 1
			else
				part:Destroy()
			end
		end
	end
	if kept == 0 then
		model:Destroy()
		return nil
	end
	return model
end

-- What a key holds: the model, its kind, and (medals and trophies) its count and label. Nil when not theirs.
local function resolve(player: Player, key: string): (Model?, string?, { count: number, label: string, colour: Color3 }?)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return nil, nil, nil
	end
	local kind, id = string.match(key, "^(%a+):(.+)$")
	if kind == "item" and id then
		local item = ProfileOperations.getItems(data)[id]
		if item == nil then
			return nil, nil, nil
		end
		if item.type == "Food" then
			local models = ReplicatedStorage:FindFirstChild("KitchenModels")
			local source = models and models:FindFirstChild(if item.food == "Meal" then "MeetMeal" else "BigSteak")
			if source and source:IsA("Model") then
				-- Its REAL size (user 2026-11-24: "if a player has a 250 steak and it's huge on the pan. They should be able
				-- to hold it out and flex it. Same for meet meals"): as long as the pan showed it (KitchenPans.showSteak:
				-- KitchenConfig.steakLength of the cook's steak count, along the model's length).
				local food = prepare(source:Clone(), HELD_SIZES.Food)
				food:ScaleTo(1)
				local length = math.max(food:GetExtentsSize().X, 0.1)
				food:ScaleTo(math.max(KitchenConfig.steakLength(item.count or 1), HELD_SIZES.Food) / length)
				return food, "Food", nil
			end
		elseif (item.type == "Trophy" or item.type == "Medal") and item.level and item.place then
			local place = item.place :: number
			local model: Model? = nil
			if item.type == "Trophy" then
				model = lazyRequire("Meet", "Trophies").copy(place)
			else
				model = lazyRequire("World", "RoomProps").propCopy("Medal", MEDAL_COLOURWAYS[place] or 1)
			end
			local info = { count = item.qty, label = HoldService.awardLabel(item.type, item.level :: string, place),
				colour = MeetLevelConfig.TrophyColours[place] or Color3.new(1, 1, 1) }
			if model then
				return prepare(model, HELD_SIZES[item.type]), item.type, info
			end
		end
		return nil, nil, nil
	elseif kind == "piece" and id then
		local piece = ProfileOperations.getPieces(data)[id]
		local look = piece and ShopConfig.find(piece.look)
		local model = look and gearModel(look)
		return if model then prepare(model, HELD_SIZES.Gear) else nil, if model then "Gear" else nil, nil
	elseif kind == "shop" and id then
		local owned = ProfileOperations.getOwnedItems(data)
		if not table.find(owned, id) then
			return nil, nil, nil
		end
		local look = ShopConfig.find(id)
		local model = look and gearModel(look)
		return if model then prepare(model, HELD_SIZES.Gear) else nil, if model then "Gear" else nil, nil
	end
	return nil, nil, nil
end

-- Whether the player still owns what `key` names (cheap: reads the save, builds nothing).
local function owns(player: Player, key: string): boolean
	local data = PlayerDataService.getData(player)
	local kind, id = string.match(key, "^(%a+):(.+)$")
	if data == nil or id == nil then
		return false
	end
	if kind == "item" then
		return ProfileOperations.getItems(data)[id] ~= nil
	elseif kind == "piece" then
		return ProfileOperations.getPieces(data)[id] ~= nil
	elseif kind == "shop" then
		return table.find(ProfileOperations.getOwnedItems(data), id) ~= nil
	end
	return false
end

-- Puts away whatever the player holds.
function HoldService.putAway(player: Player)
	local current = held[player]
	held[player] = nil
	player:SetAttribute("HeldItem", "")
	if current and current.track then
		current.track:Stop(0.2)
		current.track:Destroy()
	end
	if current and current.tool.Parent then
		current.tool:Destroy()
	end
end

--[[
	Holds the item `key` ("item:3", "piece:12", "shop:belt_black"); the same key again, or false, puts it away. Returns
	whether it is held now and a line for the player.
]]
function HoldService.hold(player: Player, key: any): (boolean, string)
	local current = held[player]
	if key == false or (current and current.key == key) then
		HoldService.putAway(player)
		return false, "Put away."
	end
	if typeof(key) ~= "string" or #key > 60 then
		return false, "That can't be held."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return false, "Not right now."
	end
	local lifting = lazyRequire("Lifting", "LiftAttemptService")
	if lifting.isAttemptActive(player) then
		return false, "Not while lifting."
	end
	local model, kind, award = resolve(player, key)
	if model == nil or kind == nil then
		return false, "That can't be held yet."
	end
	HoldService.putAway(player)
	-- The Tool: an invisible handle in the grip, the model welded to it, held in front of the hand.
	local tool = Instance.new("Tool")
	tool.Name = "Held"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("HeldKey", key)
	tool:SetAttribute("HeldKind", kind)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, true
	handle.Parent = tool
	local pivot, size = model:GetBoundingBox()
	-- Upright in the fist: the hand closes round its bottom (a trophy's base), its middle a little in front. Food carried
	-- in both hands: the handle at the middle of its bottom (the client sets the grip so that sits on the palms).
	local carried = kind == "Food" and HoldService.CarryAnimationId ~= ""
	local offset = if carried then CFrame.new(0, size.Y / 2, 0) else CFrame.new(0, math.max(size.Y / 2 - 0.25, size.Y * 0.3), -0.15)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local relative = offset * pivot:ToObjectSpace(part.CFrame)
			part.CFrame = handle.CFrame * relative
			local weld = Instance.new("Weld")
			weld.Part0 = handle
			weld.Part1 = part
			weld.C0 = relative
			weld.Parent = part
		end
	end
	model.Parent = tool
	-- The grip: the handle sits in the hand with no turn, so the thing stays upright in the default hold pose (checked in
	-- Studio 2026-11-24: a -90 degree turn laid it on its side, pointing back at the lifter).
	tool.Grip = CFrame.new(0, -0.1, 0)
	if award then
		tool:SetAttribute("WinCount", award.count)
		tool:SetAttribute("WinLabel", award.label)
		tool:SetAttribute("WinColour", award.colour)
		tool.ToolTip = string.format("x%d %s", award.count, award.label)
	end
	tool.Parent = character
	-- Food: both hands forward under the plate (the user's pose, 2026-11-24), looped over the walk; it overrides the
	-- standard hold pose (Action beats the Animate script's Idle-priority "toolnone").
	local track: AnimationTrack? = nil
	if carried then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = HoldService.CarryAnimationId
			track = animator:LoadAnimation(animation)
			local playing = track :: AnimationTrack
			playing.Priority = Enum.AnimationPriority.Action
			playing.Looped = true
			playing:Play(0.25)
			tool:SetAttribute("CarryAnim", HoldService.CarryAnimationId)
		end
	end
	held[player] = { tool = tool, key = key, track = track }
	player:SetAttribute("HeldItem", key)
	return true, "Holding it."
end

-- The key held (or nil), for screens.
function HoldService.heldKey(player: Player): string?
	local current = held[player]
	return if current then current.key else nil
end

function HoldService.start()
	-- A trophy and a medal for the INVENTORY's pictures (clients colour them by place): ReplicatedStorage.ItemModels.
	task.spawn(function()
		local folder = Instance.new("Folder")
		folder.Name = "ItemModels"
		local trophy = lazyRequire("Meet", "Trophies").copy(1)
		if trophy then
			trophy.Name = "Trophy"
			trophy.Parent = folder
		end
		local medal = lazyRequire("World", "RoomProps").propCopy("Medal", 1)
		if medal then
			medal.Name = "Medal"
			medal.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end)
	Players.PlayerRemoving:Connect(function(player)
		HoldService.putAway(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			held[player] = nil
			player:SetAttribute("HeldItem", "")
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function()
			held[player] = nil
			player:SetAttribute("HeldItem", "")
		end)
	end
	-- Put away during a lift, or when the item is no longer theirs (eaten, scrapped).
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < CHECK_SECONDS then
			return
		end
		since = 0
		local lifting = lazyRequire("Lifting", "LiftAttemptService")
		for player, current in pairs(held) do
			if current.tool.Parent == nil or lifting.isAttemptActive(player) or not owns(player, current.key) then
				HoldService.putAway(player)
			elseif current.tool:GetAttribute("WinCount") ~= nil then
				-- A won medal or trophy keeps its count up to date (another win while holding it).
				local data = PlayerDataService.getData(player)
				local id = string.match(current.key, "^item:(.+)$")
				local item = data and id and ProfileOperations.getItems(data)[id]
				if item and item.qty ~= current.tool:GetAttribute("WinCount") then
					current.tool:SetAttribute("WinCount", item.qty)
				end
			end
		end
	end)
end

return HoldService
