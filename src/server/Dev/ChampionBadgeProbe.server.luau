--!strict
--[[
	ChampionBadgeProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Studio only. Tries out the numbered State Champion badge (GAME_DESIGN §36.4) on the live
	server without running a whole State meet, which needs two qualified players.

	Set the workspace attribute ChampionBadgeTest (a string) during a Studio play test:
		"give"   gives the first player this month's badge the way a State win does (number on its way), then numbers
		         it from the counter, and prints the result
		"older"  also gives them a waiting badge for the month before, to check numbers go out oldest first
		"clear"  takes every badge off that player again (this dev tool only: nothing in the game removes a badge)
	It prints what it did and sets the attribute back to "".

	In Studio with API services OFF, nothing is saved and the counter counts in memory. With them ON, the badge is saved
	on your own account and uses up a Studio number (ChampionBadge.StudioCounterKey), so "clear" afterwards.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end

local Server = script.Parent.Parent
local PlayerDataService = require(Server:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local ProfileOperations = require(Server:WaitForChild("PlayerData"):WaitForChild("ProfileOperations"))
local ChampionBadges = require(Server:WaitForChild("Meet"):WaitForChild("ChampionBadges"))
local MeetLevelConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MeetLevelConfig"))

local ATTRIBUTE = "ChampionBadgeTest"

local function report(player: Player)
	local data = PlayerDataService.getData(player)
	local lines = {}
	for _, badge in ipairs(if data then ProfileOperations.getStateChampionBadges(data) else {}) do
		table.insert(lines, string.format("%s #%d", badge.season, badge.number))
	end
	print(string.format("[ChampionBadgeProbe] %s's badges: %s", player.Name, if #lines > 0 then table.concat(lines, ", ") else "none"))
end

local function run(command: string)
	local player = Players:GetPlayers()[1]
	if player == nil or PlayerDataService.getData(player) == nil then
		warn("[ChampionBadgeProbe] no player with loaded data")
		return
	end
	if command == "give" or command == "older" then
		local season = MeetLevelConfig.seasonFor(os.time())
		local seasons = { season }
		if command == "older" then
			table.insert(seasons, 1, MeetLevelConfig.previousSeason(season) :: string)
		end
		for _, which in ipairs(seasons) do
			local outcome: string = "?"
			PlayerDataService.update(player, function(data)
				outcome = ProfileOperations.addStateChampionBadge(data, which, 0)
			end)
			print(string.format("[ChampionBadgeProbe] %s: %s", which, outcome))
		end
		local started = os.clock()
		local given = ChampionBadges.numberPending(player)
		for which, number in pairs(given) do
			print(string.format("[ChampionBadgeProbe] numbered %s -> #%d (%.1f s)", which, number, os.clock() - started))
		end
		report(player)
	elseif command == "clear" then
		PlayerDataService.update(player, function(data)
			local career = (data :: any).career
			if typeof(career) == "table" then
				career.stateChampionBadges = {}
			end
		end)
		report(player)
	elseif command ~= "" then
		warn("[ChampionBadgeProbe] unknown command: " .. command)
	end
end

Workspace:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
	local command = Workspace:GetAttribute(ATTRIBUTE)
	if typeof(command) == "string" and command ~= "" then
		Workspace:SetAttribute(ATTRIBUTE, "")
		run(command)
	end
end)
