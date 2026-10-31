--!strict
--[[
	GearService
	Server / Economy

	Wearing the Shop's gear (GAME_DESIGN.md 30.6, the money system's step 5).

		- GetGear answers what the player owns and wears (read only)
		- SetWorn puts an item on in a slot, or takes it off, after checking
		  the slot, that the item belongs in it (ShopConfig category) and,
		  through PlayerDataService.setWorn, that the player owns it
		- every R15 character is dressed in what its player wears (the worn
		  models, WornGearConfig.AssetId, loaded once and fitted by
		  WornGearFit), on every spawn and after every change

	Looks only: the pieces have no mass, no collision, no touch or query, no
	shadow. R6 bodies are not dressed (the gear is fitted to R15).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local WornGearConfig = require(ConfigFolder:WaitForChild("WornGearConfig"))
local GearRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("GearRemotes"))

local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))
local WornGearFit = require(script.Parent:WaitForChild("WornGearFit"))

local GearService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.3
local APPEARANCE_WAIT_SECONDS = 10

local started = false
local lastAsked: { [Player]: number } = {}
local pieces: WornGearFit.Pieces? = nil
local loadTried = false

local function log(message: string, ...: any)
	print("[GearService] " .. string.format(message, ...))
end

-- The uploaded model's pieces (WornGearFit.fromModel), or nil when it is not uploaded or did not load.
local function loadPieces(): WornGearFit.Pieces?
	if loadTried then
		return pieces
	end
	loadTried = true
	if WornGearConfig.AssetId == 0 then
		warn("[GearService] the worn gear models are not uploaded yet (WornGearConfig.AssetId = 0): gear is saved but not drawn")
		return nil
	end
	local ok, problem = pcall(function()
		local loaded = game:GetService("InsertService"):LoadAsset(WornGearConfig.AssetId)
		local result, count = WornGearFit.fromModel(loaded)
		loaded:Destroy()
		pieces = result
		log("worn gear loaded: %d pieces", count)
	end)
	if not ok then
		warn("[GearService] the worn gear models did not load (gear is saved but not drawn): " .. tostring(problem))
		pieces = nil
	end
	return pieces
end

-- Rebuilds the character's worn gear from the save. Safe to call any time.
local function dress(player: Player)
	local character = player.Character
	local worn = PlayerDataService.getWorn(player)
	if character == nil or worn == nil then
		return
	end
	local loaded = if next(worn) then loadPieces() else nil
	local made = WornGearFit.dress(character, worn, loaded or {})
	if made > 0 then
		log("%s dressed: %d pieces", player.Name, made)
	end
end

local function viewFor(player: Player): GearRemotes.GearView?
	local owned = PlayerDataService.getOwnedItems(player)
	local wearing = PlayerDataService.getWorn(player)
	if owned == nil or wearing == nil then
		return nil
	end
	return { owned = owned, wearing = wearing, drawn = loadPieces() ~= nil }
end

local function tooFast(player: Player): boolean
	local now = os.clock()
	if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
		return true
	end
	lastAsked[player] = now
	return false
end

local function setWorn(player: Player, slotId: any, itemId: any): (boolean, string, GearRemotes.GearView?)
	local slot = if typeof(slotId) == "string" then WornGearConfig.slot(slotId) else nil
	if slot == nil then
		return false, "Unknown gear slot.", nil
	end
	if itemId == false then
		local outcome = PlayerDataService.setWorn(player, slot.id, nil)
		if outcome ~= "TakenOff" then
			return false, "That didn't go through. Try again.", viewFor(player)
		end
		dress(player)
		local name = string.gsub(string.lower(slot.label), "^%l", string.upper)
		return true, name .. " taken off.", viewFor(player)
	end
	local item = if typeof(itemId) == "string" then ShopConfig.find(itemId) else nil
	if item == nil or item.category ~= slot.category then
		return false, "That doesn't go there.", nil
	end
	local outcome = PlayerDataService.setWorn(player, slot.id, item.id)
	if outcome == "NotOwned" then
		return false, "You don't own that yet. Buy it at the Shop.", viewFor(player)
	elseif outcome ~= "Worn" then
		return false, "That didn't go through. Try again.", viewFor(player)
	end
	dress(player)
	return true, string.format("Wearing the %s.", item.name), viewFor(player)
end

-- Fits the gear again when a body part changes size (Roblox can scale an avatar a moment after it spawns).
local function refitOnResize(player: Player, character: Model)
	local pending = false
	for _, child in ipairs(character:GetChildren()) do
		local base = string.gsub(child.Name, "^Left", ""):gsub("^Right", "")
		if child:IsA("BasePart") and WornGearConfig.DefaultBody[base] then
			(child :: BasePart):GetPropertyChangedSignal("Size"):Connect(function()
				if pending then
					return
				end
				pending = true
				task.delay(0.5, function()
					pending = false
					if player.Character == character then
						dress(player)
					end
				end)
			end)
		end
	end
end

-- Dresses each new character once its player's data and avatar have loaded.
local function onCharacter(player: Player, character: Model)
	task.spawn(function()
		PlayerDataService.waitForData(player, 60)
		if not player:HasAppearanceLoaded() then
			local done = false
			local connection = player.CharacterAppearanceLoaded:Connect(function()
				done = true
			end)
			local start = os.clock()
			while not done and os.clock() - start < APPEARANCE_WAIT_SECONDS and player.Character == character do
				task.wait(0.2)
			end
			connection:Disconnect()
		end
		if player.Character == character then
			dress(player)
			refitOnResize(player, character)
		end
	end)
end

function GearService.start()
	if started then
		return
	end
	started = true
	local remotes = GearRemotes.createOnServer(ReplicatedStorage)
	remotes.get.OnServerInvoke = function(player: Player): GearRemotes.GearView?
		if tooFast(player) then
			return nil
		end
		return viewFor(player)
	end
	remotes.set.OnServerInvoke = function(player: Player, slotId: any, itemId: any): (boolean, string, GearRemotes.GearView?)
		if tooFast(player) then
			return false, "One moment...", nil
		end
		return setWorn(player, slotId, itemId)
	end
	task.spawn(loadPieces)
	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
end

return GearService
