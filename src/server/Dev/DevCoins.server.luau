--!strict
--[[
	DevCoins
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Endless coins for testing the Shop and MY GEAR in
	Studio (user, 2026-10-31: "I cant test it if i dont have the coins"):
	every player's coins are topped up to TOP_UP_TO whenever they drop below
	TOP_UP_BELOW, through PlayerDataService.addCoins like any payout.

	Studio only, and OFF BY DEFAULT: set ENABLED to true, play, then set it back.

	SAFETY: Studio and the live game use the same save store. With Studio's API
	access turned ON, coins given here would be saved to the real profile, so
	the tool checks first and does nothing if Studio can reach the data stores.
	Nothing requires this file.
]]

local ENABLED = false

local TOP_UP_BELOW = 100000
local TOP_UP_TO = 1000000

local RunService = game:GetService("RunService")
if not ENABLED or not RunService:IsStudio() then
	return
end

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CoinConfig"))
local PlayerDataService = require(script.Parent.Parent:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))

-- Studio can only save when its API access is on, and then a read of any store works.
local canSave = pcall(function()
	DataStoreService:GetDataStore("DevCoins_SaveCheck"):GetAsync("check")
end)
if canSave then
	warn("[DevCoins] NOT giving coins: Studio's API access is on, so they would be saved to your real profile. "
		.. "Turn API access off (Game Settings > Security) to use dev coins.")
	return
end

local function topUp(player: Player)
	local coins = PlayerDataService.getCoins(player)
	if coins and coins < TOP_UP_BELOW then
		PlayerDataService.addCoins(player, TOP_UP_TO - coins, "Dev coins (Studio only)")
	end
end

local function track(player: Player)
	task.spawn(function()
		if PlayerDataService.waitForData(player, 60) == nil then
			return
		end
		topUp(player)
		player:GetAttributeChangedSignal(CoinConfig.BalanceAttribute):Connect(function()
			task.defer(topUp, player)
		end)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	track(player)
end
Players.PlayerAdded:Connect(track)
print(string.format("[DevCoins] on: coins top up to %s whenever they drop below %s (Studio only, never saved)",
	CoinConfig.format(TOP_UP_TO), CoinConfig.format(TOP_UP_BELOW)))
