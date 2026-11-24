--!strict
--[[
	InventoryService
	Server / PlayerData

	The INVENTORY's items (GAME_DESIGN §42): food collected from the chef, medals and trophies. The remotes
	(InventoryRemotes): read the items, use (eat) one. Other systems that give items (KitchenService collecting food,
	meets giving medals and trophies) call InventoryService.changed so the player's screen updates.

	SECURITY: the client only asks; every item is made by the server and using one checks it is theirs
	(ProfileOperations.useItem).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"):WaitForChild("InventoryRemotes"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local InventoryService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.3
local remotes: InventoryRemotes.RemoteSet? = nil
local lastAsked: { [Player]: number } = {}

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if lastAsked[player] and now - lastAsked[player] < MIN_SECONDS_BETWEEN_ASKS then
		return true
	end
	lastAsked[player] = now
	return false
end

-- Tells the player's screen its items changed.
function InventoryService.changed(player: Player)
	if remotes then
		remotes.changed:FireClient(player, PlayerDataService.getInventory(player))
	end
end

function InventoryService.start()
	local set = InventoryRemotes.createOnServer(ReplicatedStorage)
	remotes = set
	set.get.OnServerInvoke = function(player: Player): any
		return PlayerDataService.getInventory(player)
	end
	set.use.OnServerInvoke = function(player: Player, itemId: any): any
		if tooSoon(player) then
			return { outcome = "Busy" }
		end
		if typeof(itemId) ~= "string" or #itemId > 12 then
			return { outcome = "Rejected" }
		end
		local outcome, percent, kind = PlayerDataService.useItem(player, itemId)
		return { outcome = outcome or "Rejected", percent = percent, kind = kind, view = PlayerDataService.getInventory(player),
			kitchen = PlayerDataService.getKitchen(player) }
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
end

return InventoryService
