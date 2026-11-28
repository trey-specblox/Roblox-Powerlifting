--!strict
--[[
	InventoryService
	Server / PlayerData

	The INVENTORY's items (GAME_DESIGN §42): food collected from the chef, medals and trophies. The remotes
	(InventoryRemotes): read the items, use (eat) one, hold one (HoldService). Other systems that give items (KitchenService collecting food,
	meets giving medals and trophies) call InventoryService.changed so the player's screen updates.

	SECURITY: the client only asks; every item is made by the server and using one checks it is theirs
	(ProfileOperations.useItem).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"):WaitForChild("InventoryRemotes"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local HoldService = require(script.Parent:WaitForChild("HoldService"))

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

--[[
	MEDALS AND TROPHIES (GAME_DESIGN §42, user 2026-11-24): a real meet won (computer lifters counted, as the coins count
	it; at Nationals in the class) keeps a MEDAL at a Local or Regional meet, and a MEDAL and a TROPHY at State and
	Nationals (2026-11-28), in the inventory, each with a count. LocalMeetService calls this after the meet's save;
	`lines` (the result screen's lines) gets one line. `place` nil or past 3 = nothing.
]]
function InventoryService.meetPlaced(player: Player, level: string, place: number?, lines: { string })
	-- Only the WINNER keeps one (user 2026-11-25, GAME_DESIGN §40.5 "The podium ceremony"; before: the top 3): a medal for
	-- winning a Local or Regional meet, a trophy for State and Nationals, counting "... MEETS WON". 2nd and 3rd are
	-- medalled in the ceremony but keep nothing; awards already owned stay.
	if place ~= 1 or typeof(level) ~= "string" then
		return
	end
	-- (user 2026-11-28: "1st place state should have a medal keeping count of how many times they won state"; the
	-- trophy is the bonus) the State and Nationals winner keeps the gold medal, counting those wins, AND the trophy.
	local kinds = if level == "Local" or level == "Regional" then { "Medal" } else { "Medal", "Trophy" }
	local saved: { { kind: string, qty: number } } = {}
	for _, kind in ipairs(kinds) do
		local id = PlayerDataService.addAward(player, kind, level, place)
		local view = id and PlayerDataService.getInventory(player)
		local item = view and view.items[id :: string]
		if item == nil then
			warn(string.format("[InventoryService] %s's %s %s was not saved", player.Name, level, kind))
		else
			table.insert(saved, { kind = kind, qty = item.qty })
			print(string.format("[InventoryService] %s won a %s %s (x%d)", player.Name, level, kind, item.qty))
		end
	end
	if #saved == 0 then
		return
	end
	local label = HoldService.awardLabel("Medal", level, place) -- "STATE MEETS WON"
	local things = if #saved > 1 then "medal and trophy are" elseif saved[1].kind == "Medal" then "medal is" else "trophy is"
	local count = saved[1].qty
	table.insert(lines, if count > 1
		then string.format("%s MEET WON! x%d %s (your %s in your INVENTORY)", string.upper(level), count, label, things)
		else string.format("%s MEET WON! Your %s in your INVENTORY.", string.upper(level), things))
	InventoryService.changed(player)
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
	set.hold.OnServerInvoke = function(player: Player, key: any): (boolean, string)
		if tooSoon(player) then
			return HoldService.heldKey(player) ~= nil, "One at a time."
		end
		if key ~= false and (typeof(key) ~= "string" or #key > 60) then
			return false, "That can't be held."
		end
		return HoldService.hold(player, key)
	end
	HoldService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
end

return InventoryService
