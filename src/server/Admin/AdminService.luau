--!strict
--[[
	AdminService
	Server / Admin

	The admin panel's server side (user 2026-11-06: "give myself coins in the live game and
	other stuff"; testing on a phone means joining the real game). It works in the live game
	and changes the admin's REAL save, so:

		- only the accounts in ADMIN_USER_IDS may use it, checked on every call. This list
		  is on the server, where no client can read or change it
		- a client sends which button, never an amount: amounts come from AdminConfig
		- it only ever changes the admin's own account, and every use is in the server's log
		- it does nothing that changes other players (a forced drop's news line is shown to them, like any drop's)

	To add a tool: a new action in `actions` here, and its buttons in client AdminPanel.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared:WaitForChild("Config"):WaitForChild("AdminConfig"))
local AdminRemotes = require(Shared:WaitForChild("Admin"):WaitForChild("AdminRemotes"))
local GearStats = require(Shared:WaitForChild("Economy"):WaitForChild("GearStats"))

local ServerRoot = script.Parent.Parent
local PlayerDataService = require(ServerRoot:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local ShopService = require(ServerRoot:WaitForChild("Economy"):WaitForChild("ShopService"))
local GearService = require(ServerRoot:WaitForChild("Economy"):WaitForChild("GearService"))

local AdminService = {}

local ADMIN_USER_IDS: { [number]: boolean } = {
	[127085964] = true, -- treylicious1
}

local MIN_SECONDS_BETWEEN_ACTIONS = 0.2

local started = false
local lastAction: { [Player]: number } = {}
local warned: { [Player]: boolean } = {}

local function isAdmin(player: Player): boolean
	-- Studio only: the workspace attribute StudioNotAdmin takes the rights away, to test being refused. It can never grant them.
	if RunService:IsStudio() and Workspace:GetAttribute("StudioNotAdmin") == true then
		return false
	end
	return ADMIN_USER_IDS[player.UserId] == true
end

local function viewFor(player: Player): AdminRemotes.AdminView
	return { coins = PlayerDataService.getCoins(player) or 0, crateRarity = ShopService.getForcedRarity(player),
		forcedDrop = GearService.getForcedDrop(player) }
end

-- Each returns whether it worked and what to tell the admin. `value` comes from a client: check it before using it.
local actions: { [string]: (Player, any) -> (boolean, string) } = {
	Coins = function(player: Player, value: any): (boolean, string)
		for _, button in ipairs(AdminConfig.CoinButtons) do
			if button.id == value then
				local outcome = PlayerDataService.addCoins(player, button.amount, "Admin panel")
				if outcome == "Added" then
					return true, button.label .. " coins."
				end
				return false, "No coins added: your save hasn't loaded, or you're at the coin limit."
			end
		end
		return false, "That isn't a coin button."
	end,
	-- A rare suit with no server-wide news, to test wearing it.
	GiveSuit = function(player: Player, value: any): (boolean, string)
		local suit = GearStats.suit(value)
		if suit == nil then
			return false, "That isn't a suit."
		end
		if GearService.giveSuit(player, suit.id, false) then
			return true, suit.name .. " added. Wear it from GEAR."
		end
		return false, "No suit added: your save hasn't loaded."
	end,
	-- Forgets the admin's own suit tests, passed or waiting, to take them again.
	ResetSuitTests = function(player: Player, _value: any): (boolean, string)
		PlayerDataService.resetSuitTests(player, function(rarity: string): boolean
			return GearStats.suit(rarity) ~= nil
		end)
		GearService.redress(player)
		return true, "Your suit tests are reset, and your suits are locked again."
	end,
	-- A real drop at the admin's next meet with a total, with the server-wide news, to test all of it.
	ForceDrop = function(player: Player, value: any): (boolean, string)
		if value == nil then
			GearService.setForcedDrop(player, nil)
			return true, "Your next meet has the normal chance."
		end
		local suit = GearStats.suit(value)
		if suit == nil then
			return false, "That isn't a suit."
		end
		GearService.setForcedDrop(player, suit.id)
		return true, "Finish a meet with a total to get the " .. suit.name .. "."
	end,
	CrateRarity = function(player: Player, value: any): (boolean, string)
		if value == nil then
			ShopService.setForcedRarity(player, nil)
			return true, "Crates roll normally."
		end
		if typeof(value) ~= "string" or GearStats.rarity(value) == nil then
			return false, "That isn't a rarity."
		end
		ShopService.setForcedRarity(player, value)
		return true, "Your crates now give " .. string.upper(value) .. ", until you turn this off or leave."
	end,
}

function AdminService.start()
	if started then
		return
	end
	started = true
	local remotes = AdminRemotes.createOnServer(ReplicatedStorage)
	remotes.get.OnServerInvoke = function(player: Player): AdminRemotes.AdminView?
		-- Everyone asks once on joining, so a refusal here isn't suspicious.
		if not isAdmin(player) then
			return nil
		end
		return viewFor(player)
	end
	remotes.action.OnServerInvoke = function(player: Player, action: any, value: any): (boolean, string, AdminRemotes.AdminView?)
		if not isAdmin(player) then
			if not warned[player] then
				warned[player] = true
				warn(string.format("[AdminService] refused %s (%d): not an admin", player.Name, player.UserId))
			end
			return false, "", nil
		end
		local now = os.clock()
		if now - (lastAction[player] or -math.huge) < MIN_SECONDS_BETWEEN_ACTIONS then
			return false, "One moment...", viewFor(player)
		end
		lastAction[player] = now
		local run = if typeof(action) == "string" then actions[action] else nil
		if run == nil then
			return false, "Unknown tool.", viewFor(player)
		end
		local ok, message = run(player, value)
		print(string.format("[AdminService] %s used %s (%s): %s", player.Name, tostring(action), tostring(value), message))
		return ok, message, viewFor(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		warned[player] = nil
	end)
end

return AdminService
