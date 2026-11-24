--!strict
--[[
	KitchenService
	Server / Economy

	Steaks and the Kitchen (GAME_DESIGN §40.7, user 2026-11-19):

		- a "Cook" prompt on every cooker spot (parts tagged KitchenConfig.CookerSpotTag, placed by the Kitchen
		  building); the client's KitchenMenu answers it
		- KitchenRemotes: the cooker and the steak boost (GET), paying for and starting a cook (COOK), eating a
		  finished meal (EAT)

	The rules live in ProfileOperations (startCook, eatSteak) through PlayerDataService; this service only checks
	what a client sent (a steak count), rate-limits it, and answers with the fresh view. The client never names a
	price, a time or a boost.

	PERFORMANCE: one prompt per cooker; no loop (cooks finish by the clock, read when asked).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local KitchenRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("KitchenRemotes"))

local PlayerDataService = require(script.Parent.Parent:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local KitchenPans = require(script.Parent:WaitForChild("KitchenPans"))

local KitchenService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.4

local started = false
local lastAsked: { [Player]: number } = {}

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
		return true
	end
	lastAsked[player] = now
	return false
end

-- The "Cook" prompt on a cooker spot.
local function addPrompt(spot: Instance)
	if not spot:IsA("BasePart") or spot:FindFirstChild("CookPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CookPrompt"
	-- (The spot is the chef, GAME_DESIGN §40.7: you talk to him to cook.)
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Chef"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	-- (He stands behind his service counter: 14 studs reaches him from the dining side, across it; user 2026-11-21:
	--  "make sure i can talk to the chef from the counter, and not have to jump over the barricade".)
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:AddTag(KitchenConfig.PromptTag)
	prompt.Parent = spot
end

function KitchenService.start()
	if started then
		return
	end
	started = true
	local set = KitchenRemotes.createOnServer(ReplicatedStorage)

	set.get.OnServerInvoke = function(player: Player): any
		if tooSoon(player) then
			return nil
		end
		return PlayerDataService.getKitchen(player)
	end

	-- The chef scene played to the end once (KitchenScene): it can be skipped from now on.
	set.sceneSeen.OnServerInvoke = function(player: Player): any
		if tooSoon(player) then
			return nil
		end
		PlayerDataService.markChefSceneSeen(player)
		return PlayerDataService.getKitchen(player)
	end

	-- `kind`: nil or "Steak" for steaks, "Meal" for meet meals (GAME_DESIGN §40.7, user 2026-11-23). `hours`: the cook
	-- timer, one of KitchenConfig.CookHours (nil = 24); the boost lasts as long (§41.5).
	set.cook.OnServerInvoke = function(player: Player, steaks: any, kind: any, hours: any): any
		if tooSoon(player) then
			return { outcome = "Busy" }
		end
		if (kind ~= nil and typeof(kind) ~= "string") or (hours ~= nil and typeof(hours) ~= "number") then
			return { outcome = "Rejected" }
		end
		local cooking = if kind == nil then "Steak" else kind
		local length = if hours == nil then KitchenConfig.BoostHours else hours
		if not KitchenConfig.isSteakCount(steaks) or not KitchenConfig.isKind(cooking) or not KitchenConfig.isCookHours(length) then
			return { outcome = "Rejected" }
		end
		local outcome, balance = PlayerDataService.startCook(player, steaks, cooking, length)
		-- The steak appears in the player's pan and the clock starts.
		KitchenPans.refresh(player)
		return { outcome = outcome or "Rejected", balance = balance, view = PlayerDataService.getKitchen(player) }
	end

	set.eat.OnServerInvoke = function(player: Player): any
		if tooSoon(player) then
			return { outcome = "NotReady" }
		end
		local outcome, percent, kind = PlayerDataService.eatSteak(player)
		KitchenPans.refresh(player)
		return { outcome = outcome or "Rejected", percent = percent, kind = kind, view = PlayerDataService.getKitchen(player) }
	end

	for _, spot in ipairs(CollectionService:GetTagged(KitchenConfig.CookerSpotTag)) do
		addPrompt(spot)
	end
	CollectionService:GetInstanceAddedSignal(KitchenConfig.CookerSpotTag):Connect(addPrompt)

	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
end

return KitchenService
