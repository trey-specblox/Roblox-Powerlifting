--!strict
--[[
	AdminService
	Server / Admin

	The admin panel's server side (user 2026-11-06: "give myself coins in the live game and
	other stuff"; testing on a phone means joining the real game). It works in the live game
	and changes REAL saves, so:

		- only the accounts in ADMIN_USER_IDS may use it, checked on every call. This list
		  is on the server, where no client can read or change it
		- a client sends which button, never a coin amount: amounts come from AdminConfig. A
		  typed stat is clamped to AdminConfig.StatLimits
		- the first page changes only the admin's own account. The PLAYER STATS page (user
		  2026-11-08: "fully control anyones stats", to playtest with an alt) changes any
		  player in the same server: their stats, State ladder, daily training and coins
		- START A MEET NOW (user 2026-11-08) starts any meet early, with whoever signed up
		- the CELEBRATIONS viewer's PLAY ON ME (user 2026-11-11) plays one on the admin's own character, so it can
		  be watched for real, cinematic and all; it changes no save
		- every use is in the server's log, with whose save it changed

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
local TechniqueCurve = require(Shared:WaitForChild("Difficulty"):WaitForChild("TechniqueCurve"))

local ServerRoot = script.Parent.Parent
local PlayerDataService = require(ServerRoot:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local ShopService = require(ServerRoot:WaitForChild("Economy"):WaitForChild("ShopService"))
local GearService = require(ServerRoot:WaitForChild("Economy"):WaitForChild("GearService"))
local ProfileOperations = require(ServerRoot:WaitForChild("PlayerData"):WaitForChild("ProfileOperations"))
local LocalMeetService = require(ServerRoot:WaitForChild("Meet"):WaitForChild("LocalMeetService"))
local CelebrationService = require(ServerRoot:WaitForChild("Meet"):WaitForChild("CelebrationService"))
local CelebrationConfig = require(Shared:WaitForChild("Config"):WaitForChild("CelebrationConfig"))

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
	-- Studio only: the test players of a multi-client test (Test > Clients and Servers) have made-up UserIds of 0 or below,
	-- so each can use the panel there (user 2026-11-10: "I cant run two clients because i dont have the admin panel"). No
	-- real account has such an id, and outside Studio this never applies.
	if RunService:IsStudio() and player.UserId <= 0 then
		return true
	end
	return ADMIN_USER_IDS[player.UserId] == true
end

-- The player in this server with this UserId, or nil. Safe with anything a client sends.
local function playerFor(userId: any): Player?
	if typeof(userId) ~= "number" or userId ~= userId then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

-- A player's stats for the PLAYER STATS page, or nil when their save hasn't loaded.
local function targetViewFor(target: Player): AdminRemotes.TargetView?
	local data = PlayerDataService.getData(target)
	local classKey = data and ProfileOperations.getActiveClassKey(data)
	local build = data and ProfileOperations.getActiveBuild(data)
	if data == nil or classKey == nil or build == nil then
		return nil
	end
	local profile = data :: any
	local values: { [string]: number } = {}
	local effective: { [string]: number } = {}
	local ladder = ProfileOperations.getLadder(data, classKey, os.time())
	for _, field in ipairs(AdminConfig.StatFields) do
		local value: any = nil
		if field.kind == "Bodyweight" then
			value = profile.bodyweight and profile.bodyweight.currentKg
		elseif field.kind == "Ladder" then
			value = ladder.points
		elseif field.kind == "CompetitionNumber" and field.lift then
			value = (build.competitionNumber :: any)[field.lift]
		elseif field.kind == "Scale" and field.lift then
			value = (build.competitionScale :: any)[field.lift]
		elseif field.kind == "Technique" and field.stat then
			value = profile.technique and profile.technique[field.stat]
			if ProfileOperations.isFiniteNumber(value) and value >= 0 then
				local ok, curved = pcall(TechniqueCurve.toEffective, value)
				if ok then
					effective[field.id] = curved
				end
			end
		end
		values[field.id] = if ProfileOperations.isFiniteNumber(value) then value else 0
	end
	return { userId = target.UserId, name = target.Name, classKey = classKey, ladderTarget = ladder.target,
		qualified = ladder.qualified, coins = ProfileOperations.getCoins(data), values = values, effective = effective }
end

local function viewFor(player: Player, targetUserId: any?): AdminRemotes.AdminView
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		table.insert(list, { userId = other.UserId, name = other.Name })
	end
	table.sort(list, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	local target = if targetUserId == nil then player else playerFor(targetUserId)
	return { coins = PlayerDataService.getCoins(player) or 0, crateRarity = ShopService.getForcedRarity(player),
		forcedDrop = GearService.getForcedDrop(player), players = list, target = if target then targetViewFor(target) else nil,
		meets = LocalMeetService.adminMeets() }
end

-- The PLAYER STATS page's target: the player in this server named by `value.userId`, or nil and why not.
local function targetOf(value: any): (Player?, string)
	local target = if typeof(value) == "table" then playerFor(value.userId) else nil
	if target == nil then
		return nil, "That player isn't in this server."
	end
	return target, ""
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
	-- Starts meet `value` (its number, the State meet last) now, with whoever has signed up.
	StartMeet = function(_player: Player, value: any): (boolean, string)
		return LocalMeetService.adminStartNow(value)
	end,
	-- PLAYER STATS: one typed stat for any player here.
	SetStat = function(_player: Player, value: any): (boolean, string)
		local target, problem = targetOf(value)
		if target == nil then
			return false, problem
		end
		local number = tonumber(value.value)
		if number == nil then
			return false, "Type a number."
		end
		local ok, message = PlayerDataService.adminSetStat(target, value.id, number)
		return ok, target.Name .. ": " .. message
	end,
	QualifyState = function(_player: Player, value: any): (boolean, string)
		local target, problem = targetOf(value)
		if target == nil then
			return false, problem
		end
		local ok, message = PlayerDataService.adminQualifyForState(target)
		return ok, target.Name .. ": " .. message
	end,
	RefillDaily = function(_player: Player, value: any): (boolean, string)
		local target, problem = targetOf(value)
		if target == nil then
			return false, problem
		end
		local ok, message = PlayerDataService.adminRefillDaily(target)
		return ok, target.Name .. ": " .. message
	end,
	-- Gives an entrance (EntranceConfig id) and puts it on: only the admin panel hands them out until crates do (§36.4).
	GiveEntrance = function(_player: Player, value: any): (boolean, string)
		local target, problem = targetOf(value)
		if target == nil then
			return false, problem
		end
		if typeof(value.id) ~= "string" then
			return false, "That isn't an entrance."
		end
		local ok, message = PlayerDataService.adminGiveEntrance(target, value.id)
		return ok, target.Name .. ": " .. message
	end,
	GiveCoinsTo = function(_player: Player, value: any): (boolean, string)
		local target, problem = targetOf(value)
		if target == nil then
			return false, problem
		end
		for _, button in ipairs(AdminConfig.CoinButtons) do
			if button.id == value.id then
				local outcome = PlayerDataService.addCoins(target, button.amount, "Admin panel")
				if outcome == "Added" then
					return true, string.format("%s: %s coins.", target.Name, button.label)
				end
				return false, target.Name .. ": no coins added (save not loaded, or at the coin limit)."
			end
		end
		return false, "That isn't a coin button."
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
	-- Plays a celebration (CelebrationConfig id) on the admin's own character, for everyone to see. Saves nothing.
	PlayCelebration = function(player: Player, value: any): (boolean, string)
		local celebration = if typeof(value) == "string" then CelebrationConfig.byId[value] else nil
		if celebration == nil then
			return false, "That isn't a celebration."
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character == nil or humanoid == nil or humanoid.Health <= 0 then
			return false, "No character to play it on."
		end
		CelebrationService.play(character, celebration.id, player)
		return true, "Playing " .. string.upper(celebration.name) .. "."
	end,
}

function AdminService.start()
	if started then
		return
	end
	started = true
	local remotes = AdminRemotes.createOnServer(ReplicatedStorage)
	remotes.get.OnServerInvoke = function(player: Player, targetUserId: any): AdminRemotes.AdminView?
		-- Everyone asks once on joining, so a refusal here isn't suspicious.
		if not isAdmin(player) then
			return nil
		end
		return viewFor(player, targetUserId)
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
		-- The PLAYER STATS page's player, so the answer shows them.
		local targetUserId = if typeof(value) == "table" then value.userId else nil
		if now - (lastAction[player] or -math.huge) < MIN_SECONDS_BETWEEN_ACTIONS then
			return false, "One moment...", viewFor(player, targetUserId)
		end
		lastAction[player] = now
		local run = if typeof(action) == "string" then actions[action] else nil
		if run == nil then
			return false, "Unknown tool.", viewFor(player, targetUserId)
		end
		local ok, message = run(player, value)
		local shown = if typeof(value) == "table"
			then string.format("user %s, %s = %s", tostring(value.userId), tostring(value.id), tostring(value.value))
			else tostring(value)
		print(string.format("[AdminService] %s used %s (%s): %s", player.Name, tostring(action), shown, message))
		return ok, message, viewFor(player, targetUserId)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		warned[player] = nil
	end)
end

return AdminService
