--!strict
--[[
	ShopService
	Server / Economy

	The Shop (GAME_DESIGN.md 30.6, the money system's step 4): cosmetic gear
	from ShopConfig bought with coins at the Shop's counter.

		- the counter point (tagged ShopConfig.CounterTag by RoomProps) gets a
		  "Browse the shop" prompt; holding it opens the client's menu
		- GetShop answers what the player owns and their coins (read only)
		- BuyItem buys one item after checking: a known item, the player is at
		  the counter, not asked too fast; the price is ShopConfig's, never the
		  client's; PlayerDataService.purchaseItem then takes the coins and
		  gives the item together (and refuses one already owned or too
		  expensive)
		- the gear models are copied into ReplicatedStorage for the menu's
		  previews (the templates live in ServerStorage)

	Owning an item changes nothing in a lift. Wearing it comes in step 5.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local StarterGymConfig = require(ConfigFolder:WaitForChild("StarterGymConfig"))
local ShopRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("ShopRemotes"))

local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))

local ShopService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.4

local started = false
local lastAsked: { [Player]: number } = {}

local function root(player: Player): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if part and part:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return part
	end
	return nil
end

-- Whether the player stands near any Shop counter point.
local function atCounter(player: Player): boolean
	local body = root(player)
	if body == nil then
		return false
	end
	for _, point in ipairs(CollectionService:GetTagged(ShopConfig.CounterTag)) do
		if point:IsA("BasePart") and (point.Position - body.Position).Magnitude <= ShopConfig.MaxBuyDistanceStuds then
			return true
		end
	end
	return false
end

local function tooFast(player: Player): boolean
	local now = os.clock()
	if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
		return true
	end
	lastAsked[player] = now
	return false
end

local function viewFor(player: Player): ShopRemotes.ShopView?
	local owned = PlayerDataService.getOwnedItems(player)
	local coins = PlayerDataService.getCoins(player)
	if owned == nil or coins == nil then
		return nil
	end
	return { owned = owned, coins = coins }
end

local function buy(player: Player, itemId: any): (boolean, string, ShopRemotes.ShopView?)
	if typeof(itemId) ~= "string" then
		return false, "Unknown item.", nil
	end
	local item = ShopConfig.find(itemId)
	if item == nil then
		return false, "That item isn't sold here.", nil
	end
	if not atCounter(player) then
		return false, "Come to the shop counter to buy.", nil
	end
	local outcome = PlayerDataService.purchaseItem(player, item.id, item.price, "Shop: " .. item.name)
	local view = viewFor(player)
	if outcome == "Bought" then
		return true, string.format("You bought the %s!", item.name), view
	elseif outcome == "AlreadyOwned" then
		return false, "You already own that.", view
	elseif outcome == "NotEnough" then
		return false, "Not enough coins yet. Earn them at official meets.", view
	end
	return false, "That purchase didn't go through. Try again.", view
end

local function setUpCounter(instance: Instance, remotes: ShopRemotes.RemoteSet)
	if not instance:IsA("BasePart") or instance:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Browse the shop"
	prompt.ObjectText = "Shop"
	prompt.HoldDuration = ShopConfig.PromptHoldSeconds
	prompt.MaxActivationDistance = ShopConfig.PromptDistanceStuds
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		if root(player) then
			remotes.open:FireClient(player)
		end
	end)
end

-- Copies the gear models into ReplicatedStorage once, for the menu's 3D previews.
local function sharePreviews()
	if ReplicatedStorage:FindFirstChild(ShopRemotes.PREVIEWS_NAME) then
		return
	end
	local templates = ServerStorage:FindFirstChild("PropTemplates")
	local gear = templates and templates:FindFirstChild(StarterGymConfig.ShopGearTemplate)
	if gear == nil then
		warn("[ShopService] no gear models: the Shop menu shows no previews")
		return
	end
	local copy = gear:Clone()
	copy.Name = ShopRemotes.PREVIEWS_NAME
	copy.Parent = ReplicatedStorage
end

function ShopService.start()
	if started then
		return
	end
	started = true
	local remotes = ShopRemotes.createOnServer(ReplicatedStorage)
	sharePreviews()
	remotes.get.OnServerInvoke = function(player: Player): ShopRemotes.ShopView?
		if tooFast(player) then
			return nil
		end
		return viewFor(player)
	end
	remotes.buy.OnServerInvoke = function(player: Player, itemId: any): (boolean, string, ShopRemotes.ShopView?)
		if tooFast(player) then
			return false, "One moment...", nil
		end
		return buy(player, itemId)
	end
	for _, point in ipairs(CollectionService:GetTagged(ShopConfig.CounterTag)) do
		setUpCounter(point, remotes)
	end
	CollectionService:GetInstanceAddedSignal(ShopConfig.CounterTag):Connect(function(point)
		setUpCounter(point, remotes)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
end

return ShopService
