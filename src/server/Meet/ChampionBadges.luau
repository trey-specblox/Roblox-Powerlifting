--!strict
--[[
	ChampionBadges
	Server / Meet

	Two kinds of badge for winning meets (user 2026-11-16, GAME_DESIGN §36.4):

	1. THE NUMBERED STATE CHAMPION BADGE (MeetLevelConfig.ChampionBadge). Only the State meet's winner earns one:
	   "#1001 STATE CHAMPION · NOV 2026", one per season. LocalMeetService gives the badge in the winner's meet save
	   (ProfileOperations.addStateChampionBadge, number 0 = on its way) and then asks here for its number (numberPending).
	   The number comes from ONE counter for the whole game, kept in a DataStore and raised with IncrementAsync, which
	   Roblox runs one at a time across every server, so two winners can never get the same number.
	   If the counter can't be reached, the badge keeps 0 and is numbered later: on a retry a minute on while the player
	   stays, or when they next join. A number taken but not saved (the player left at that moment) is simply skipped,
	   so the count can have a gap but never a repeat.
	   Studio counts on its own key (StudioCounterKey), and with no DataStore access at all (API services off) it counts
	   in memory for that test only.

	2. ROBLOX PROFILE BADGES for winning a Local, Regional or State meet (MeetLevelConfig.WinnerBadgeIds; 0 = not made
	   yet: nothing is given). Given by awardWin after a win that counts, and on joining for wins the player already has
	   (from their saved wins and titles), so nobody who won before the badges existed misses out.

	SERVER ONLY. No remotes: a client can't ask for a badge or a number. Every number comes from the counter here.
]]

local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MeetLevelConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MeetLevelConfig"))
local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))

local ChampionBadges = {}

local SETTINGS = MeetLevelConfig.ChampionBadge
-- Tries at the counter before giving up for now, and the wait between them (seconds).
local COUNTER_TRIES = 3
local COUNTER_RETRY_SECONDS = 2
-- While a badge still has no number, try again this often while the player stays (seconds), at most this many times.
local LATER_RETRY_SECONDS = 60
local LATER_RETRY_LIMIT = 10

local started = false
local counterStore: DataStore? = nil
-- Studio with no DataStore access: a count for this test only.
local memoryCount: number? = nil
-- Players whose badges are being numbered right now, so two calls never take two numbers for one badge.
local numbering: { [Player]: boolean } = {}
local retrying: { [Player]: boolean } = {}

local function log(message: string, ...: any)
	print("[ChampionBadges] " .. string.format(message, ...))
end

-- The next number from the game-wide counter, or nil when it can't be reached now. Yields.
local function nextNumber(): number?
	local key = if RunService:IsStudio() then SETTINGS.StudioCounterKey else SETTINGS.CounterKey
	if memoryCount then
		memoryCount += 1
		return memoryCount
	end
	local lastProblem = ""
	for try = 1, COUNTER_TRIES do
		local ok, result = pcall(function()
			if counterStore == nil then
				counterStore = DataStoreService:GetDataStore(SETTINGS.CounterStore)
			end
			local count = (counterStore :: DataStore):IncrementAsync(key, 1)
			return count
		end)
		if ok and typeof(result) == "number" and result >= 1 and result == math.floor(result) then
			return result
		end
		lastProblem = tostring(result)
		if try < COUNTER_TRIES then
			task.wait(COUNTER_RETRY_SECONDS)
		end
	end
	if RunService:IsStudio() then
		-- No DataStore in this Studio test (API services off): count in memory so the badge can still be tried out.
		warn("[ChampionBadges] no DataStore in this Studio test, counting in memory (" .. lastProblem .. ")")
		memoryCount = 1
		return memoryCount
	end
	warn("[ChampionBadges] the State Champion counter could not be reached: " .. lastProblem)
	return nil
end

-- One pass over the player's waiting badges (oldest season first), saving each number at once. Returns the badges it
-- numbered, by season, and whether one is still waiting because the counter couldn't be reached. Yields.
local function numberOnce(player: Player): ({ [string]: number }, boolean)
	local given: { [string]: number } = {}
	local data = PlayerDataService.getData(player)
	if numbering[player] or data == nil then
		return given, false
	end
	local pending = ProfileOperations.pendingStateChampionSeasons(data)
	if #pending == 0 then
		return given, false
	end
	numbering[player] = true
	local missed = false
	for _, season in ipairs(pending) do
		local number = nextNumber()
		if number == nil then
			missed = true
			break
		end
		local filled = false
		local saved = PlayerDataService.update(player, function(live)
			filled = ProfileOperations.fillStateChampionNumber(live, season, number :: number)
		end)
		if saved and filled then
			given[season] = number
			log("%s is State Champion #%d (%s)", player.Name, number, season)
		else
			-- Taken but not saved (they left just now, or it was numbered elsewhere): that number is skipped.
			warn(string.format("[ChampionBadges] number %d for %s (%s) was not saved", number, player.Name, season))
		end
	end
	numbering[player] = nil
	return given, missed
end

-- Tries again every LATER_RETRY_SECONDS while the player stays and a badge still waits for its number.
local function retryLater(player: Player)
	if retrying[player] then
		return
	end
	retrying[player] = true
	task.spawn(function()
		for _ = 1, LATER_RETRY_LIMIT do
			task.wait(LATER_RETRY_SECONDS)
			if player.Parent ~= Players then
				break
			end
			local _, missed = numberOnce(player)
			if not missed then
				break
			end
		end
		retrying[player] = nil
	end)
end

--[[
	Numbers this player's badges that are still waiting and returns the ones it numbered, by season ("2026-11" -> 1001).
	Yields (the counter). If the counter can't be reached it tries again later by itself. Safe to call any time: a badge
	already numbered is never touched.
]]
function ChampionBadges.numberPending(player: Player): { [string]: number }
	local given, missed = numberOnce(player)
	if missed and player.Parent == Players then
		retryLater(player)
	end
	return given
end

-- ------------------------------------------------------------------ Roblox profile badges for winning

-- Gives the Roblox badge `badgeId` unless the player has it. Yields; safe to call again.
local function giveRobloxBadge(player: Player, badgeId: number, what: string)
	if badgeId == 0 or player.Parent ~= Players then
		return
	end
	local okHas, has = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
	end)
	if okHas and has then
		return
	end
	local ok, problem = pcall(function()
		return BadgeService:AwardBadge(player.UserId, badgeId)
	end)
	if ok then
		log("gave %s the %s badge", player.Name, what)
	else
		warn(string.format("[ChampionBadges] the %s badge for %s was not given: %s", what, player.Name, tostring(problem)))
	end
end

-- A win that counts at `level` ("Local", "Regional" or "State"): that level's Roblox badge, in the background.
function ChampionBadges.awardWin(player: Player, level: string)
	local badgeId = MeetLevelConfig.WinnerBadgeIds[level]
	if typeof(badgeId) ~= "number" or badgeId == 0 then
		return
	end
	task.spawn(giveRobloxBadge, player, badgeId, level .. " meet winner")
end

--[[
	On joining: the Roblox badges for wins the player already has. A State win shows as the State Champion title, a
	Regional win as the Regional Champion title, and a Local win as a win (career.localWins counts every level's wins)
	beyond those two.
]]
local function catchUpWins(player: Player)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	local titles = ProfileOperations.getTitles(data)
	local state = titles.StateChampion or 0
	local regional = titles.RegionalChampion or 0
	local career = (data :: any).career
	local wins = if typeof(career) == "table" and typeof(career.localWins) == "number" then career.localWins else 0
	if state >= 1 or #ProfileOperations.getStateChampionBadges(data) > 0 then
		ChampionBadges.awardWin(player, "State")
	end
	if regional >= 1 then
		ChampionBadges.awardWin(player, "Regional")
	end
	if wins - state - regional >= 1 then
		ChampionBadges.awardWin(player, "Local")
	end
end

local function onJoined(player: Player)
	if PlayerDataService.waitForData(player, 60) == nil then
		return
	end
	ChampionBadges.numberPending(player)
	catchUpWins(player)
end

function ChampionBadges.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(onJoined)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onJoined, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		numbering[player] = nil
	end)
end

return ChampionBadges
