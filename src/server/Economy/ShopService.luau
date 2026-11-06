--!strict
--[[
	ShopService
	Server / Economy

	The Shop (GAME_DESIGN.md §35.12): gear crates bought with coins at the Shop's
	counter. Crates are the only way to get gear (user 2026-11-06); there is nothing
	else to buy, and what a player bought before stays theirs.

		- the counter point (tagged ShopConfig.CounterTag by RoomProps) gets a
		  "Browse the shop" prompt; holding it opens the client's menu
		- GetShop answers the player's coins (read only)
		- OpenCrate opens one crate (one per item: belt, wrist wraps, singlet, knee
		  sleeves) after checking the crate, that the player is at the counter and has
		  not asked too fast; the price and the roll are the server's, and
		  PlayerDataService.openCrate takes the coins and adds the piece together
		- the gear models are copied into ReplicatedStorage for the menu's
		  previews (the templates live in ServerStorage)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local StarterGymConfig = require(ConfigFolder:WaitForChild("StarterGymConfig"))
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local EconomyFolder = Shared:WaitForChild("Economy")
local ShopRemotes = require(EconomyFolder:WaitForChild("ShopRemotes"))
local GearStats = require(EconomyFolder:WaitForChild("GearStats"))

local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))
local RoomProps = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("RoomProps"))

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
	local coins = PlayerDataService.getCoins(player)
	if coins == nil then
		return nil
	end
	return { coins = coins }
end

-- Opens one crate: the roll and the price are the server's; the client only asks.
local crateRandom = Random.new()
local function openCrate(player: Player, crateId: any): (boolean, string, ShopRemotes.ShopView?, string?, GearStats.Piece?)
	local crate = GearStats.crate(crateId)
	if crate == nil then
		return false, "The shop doesn't sell that crate.", nil, nil, nil
	end
	if not atCounter(player) then
		return false, "Come to the shop counter to open a crate.", nil, nil, nil
	end
	local piece = GearStats.roll(crateRandom, crate.slot)
	-- Studio only: the workspace attribute StudioCrateRarity forces what comes out, to see every reveal.
	local forced = if RunService:IsStudio() then Workspace:GetAttribute("StudioCrateRarity") else nil
	if GearStats.rarity(forced) then
		piece.rarity = forced
	end
	local outcome, pieceId = PlayerDataService.openCrate(player, crate.price, piece, GearStatsConfig.MaxPieces)
	local view = viewFor(player)
	if outcome == "Opened" then
		return true, GearStats.pieceName(piece) .. "!", view, pieceId, piece
	elseif outcome == "NotEnough" then
		return false, "Not enough coins yet. Earn them at official meets.", view, nil, nil
	elseif outcome == "Full" then
		return false, string.format("Your gear is full (%d pieces). Scrap some in MY GEAR first.", GearStatsConfig.MaxPieces), view, nil, nil
	end
	return false, "That crate didn't open. Try again.", view, nil, nil
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

-- Copies the crate into ReplicatedStorage once, for the menu's opening intro. Without it the menu goes straight to the reel.
local function shareCrate()
	if ReplicatedStorage:FindFirstChild(ShopRemotes.CRATE_MODEL_NAME) then
		return
	end
	local crate = RoomProps.propCopy("GearCrate", 1)
	if crate == nil then
		warn("[ShopService] no crate model: crates open straight to the reel")
		return
	end
	crate.Name = ShopRemotes.CRATE_MODEL_NAME
	crate.Parent = ReplicatedStorage
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
	task.spawn(shareCrate)
	remotes.get.OnServerInvoke = function(player: Player): ShopRemotes.ShopView?
		if tooFast(player) then
			return nil
		end
		return viewFor(player)
	end
	remotes.crate.OnServerInvoke = function(player: Player, crateId: any): (boolean, string, ShopRemotes.ShopView?, string?, GearStats.Piece?)
		if tooFast(player) then
			return false, "One moment...", nil, nil, nil
		end
		return openCrate(player, crateId)
	end
	-- Studio only: the workspace attribute StudioStartingCoins gives every joining player that many coins, to test the
	-- Shop without earning them. Studio saves nothing, and this never runs in a live game.
	if RunService:IsStudio() then
		local function giveTestCoins(player: Player)
			local amount = Workspace:GetAttribute("StudioStartingCoins")
			if typeof(amount) == "number" and amount > 0 and PlayerDataService.waitForData(player, 60) then
				PlayerDataService.addCoins(player, amount, "Studio test coins")
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(giveTestCoins, player)
		end
		Players.PlayerAdded:Connect(giveTestCoins)
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
