--!strict
--[[
	CoinDisplayService
	Server / PlayerData

	Shows each player their coins (GAME_DESIGN.md 30.6, the money system's
	step 2). DISPLAY ONLY: it never changes coins. PlayerDataService.addCoins /
	spendCoins are the only writers and tell this service after each change.

		- the player attribute CoinConfig.BalanceAttribute ("Coins") holds the
		  balance, set when the player's data loads and after every change
		  (the client's coin counter reads it)
		- CoinRemotes.CHANGED tells that one player what changed and why (the
		  "+150 COINS" pop-up)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoinConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoinConfig"))
local CoinRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("CoinRemotes"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local ProfileOperations = require(script.Parent.ProfileOperations)

local CoinDisplayService = {}

-- How long to wait for a joining player's data before giving up on showing their balance (seconds).
local LOAD_WAIT_SECONDS = 60

local started = false

-- Shows the balance once the player's data has loaded.
local function showOnJoin(player: Player)
	local data = PlayerDataService.waitForData(player, LOAD_WAIT_SECONDS)
	if data and player.Parent then
		player:SetAttribute(CoinConfig.BalanceAttribute, ProfileOperations.getCoins(data))
	end
end

function CoinDisplayService.start()
	if started then
		return
	end
	started = true
	local remote = CoinRemotes.createOnServer(ReplicatedStorage)
	PlayerDataService.onCoinsChanged(function(player: Player, change: number, balance: number, reason: string)
		if player.Parent == nil then
			return
		end
		player:SetAttribute(CoinConfig.BalanceAttribute, balance)
		local news: CoinRemotes.CoinChange = { change = change, balance = balance, reason = reason }
		remote:FireClient(player, news)
	end)
	Players.PlayerAdded:Connect(showOnJoin)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(showOnJoin, player)
	end
end

return CoinDisplayService
