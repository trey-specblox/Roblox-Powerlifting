--!strict
--[[
	RankService
	Server / PlayerData

	Ranks and titles (GAME_DESIGN §41, RankConfig, References/Ranks and Titles Study.md).

		- LocalMeetService records the rank inside the meet's own save (ProfileOperations.recordRankMeet) and then calls
		  RankService.meetRecorded, which tells that lifter (RankNews, shown after the awards) and refreshes their tag
		- the remotes (RankRemotes): read, claim rewards, open a free rank crate, pick a title, clear the NEW tags
		- every player's tag data as attributes (RankIndex, TitleId, TitleCount) for the client name tags, and their
		  rank in the player list (leaderstats "Rank")
		- one chat line for the whole server only for the rare: a new name from AnnounceFromTier up, or a Legendary title

	SECURITY: the client only asks. Ranks come from server-checked meet results; rewards, rolls and titles are the
	server's; a title can only be picked if owned (ProfileOperations.setTitle).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared:WaitForChild("Config"):WaitForChild("RankConfig"))
local GearStatsConfig = require(Shared:WaitForChild("Config"):WaitForChild("GearStatsConfig"))
local RankRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("RankRemotes"))
local GearStats = require(Shared:WaitForChild("Economy"):WaitForChild("GearStats"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ProfileOperations = require(script.Parent:WaitForChild("ProfileOperations"))

local RankService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.3
-- Reaching a name from this tier up (Platform Pro, about day 16 for a daily player) is announced to the server.
local ANNOUNCE_FROM_TIER = 6
local LEGENDARY = 4

local remotes: RankRemotes.RemoteSet? = nil
local lastAsked: { [Player]: number } = {}
local crateRandom = Random.new()

local function log(message: string, ...: any)
	print("[RankService] " .. string.format(message, ...))
end

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if lastAsked[player] and now - lastAsked[player] < MIN_SECONDS_BETWEEN_ASKS then
		return true
	end
	lastAsked[player] = now
	return false
end

-- The name tag's attributes and the player list's column, from the save.
local function publish(player: Player, view: ProfileOperations.RankView?)
	local current = view or PlayerDataService.getRanks(player)
	if current == nil then
		return
	end
	player:SetAttribute("RankIndex", current.rank)
	player:SetAttribute("TitleId", current.title)
	local owned = current.titles[current.title]
	player:SetAttribute("TitleCount", if owned then owned.count else 0)
	local stats = player:FindFirstChild("leaderstats")
	if stats == nil then
		local made = Instance.new("Folder")
		made.Name = "leaderstats"
		made.Parent = player
		stats = made
	end
	assert(stats ~= nil)
	local column = stats:FindFirstChild("Rank") :: StringValue?
	if column == nil then
		local made = Instance.new("StringValue")
		made.Name = "Rank"
		made.Parent = stats
		column = made
	end
	assert(column ~= nil)
	local rank = RankConfig.Ranks[current.rank]
	column.Value = if rank then rank.label else "Unranked"
end

local function announce(line: RankRemotes.Announcement)
	if remotes then
		remotes.announce:FireAllClients(line)
	end
end

--[[
	A real meet just saved this lifter's rank (LocalMeetService, after its write). Tells them (shown after the awards),
	refreshes their tag and, for the rare, tells the server.
]]
function RankService.meetRecorded(player: Player, result: ProfileOperations.RankMeetResult, meetPoints: number?)
	local view = PlayerDataService.getRanks(player)
	publish(player, view)
	if remotes == nil or (result.rankAfter <= result.rankBefore and #result.newFeats == 0 and not result.newBest) then
		return
	end
	local before = RankConfig.Ranks[result.rankBefore]
	remotes.news:FireClient(player, {
		rankBefore = result.rankBefore,
		rankAfter = result.rankAfter,
		pointsBefore = if before then before.points else 0,
		points = meetPoints or 0,
		newBest = result.newBest,
		newFeats = result.newFeats,
		view = view,
	} :: RankRemotes.RankNews)
	-- The rare, for everyone: the highest new name reached, and each Legendary title.
	local beforeTier = if before then before.tier else 0
	local after = RankConfig.Ranks[result.rankAfter]
	if after and after.tier > beforeTier and after.tier >= ANNOUNCE_FROM_TIER then
		announce({ name = player.DisplayName, kind = "Rank", id = after.name, rank = after.index })
	end
	for _, id in ipairs(result.newFeats) do
		local entry = RankConfig.TitleById[id]
		if entry and entry.tier >= LEGENDARY then
			announce({ name = player.DisplayName, kind = "Title", id = id })
		end
	end
end

-- Refreshes the name tag, the player list and the player's own RANKS screen after an admin change to the save.
function RankService.refresh(player: Player)
	local view = PlayerDataService.getRanks(player)
	publish(player, view)
	if remotes and view then
		-- (no moment to show: rankAfter = rankBefore, nothing new; the menu and its red dot take the view)
		remotes.news:FireClient(player, { rankBefore = view.rank, rankAfter = view.rank, pointsBefore = 0, points = 0,
			newBest = false, newFeats = {}, view = view } :: RankRemotes.RankNews)
	end
end

-- A meet title (career.titles) was just earned: refresh the tag, and tell the server if it is Legendary.
function RankService.titleEarned(player: Player, id: string)
	publish(player, nil)
	local entry = RankConfig.TitleById[id]
	if entry and entry.tier >= LEGENDARY then
		announce({ name = player.DisplayName, kind = "Title", id = id })
	end
end

local function openFreeCrate(player: Player, crateId: any): any
	local crate = GearStats.crate(crateId)
	if crate == nil then
		return { ok = false, message = "That crate doesn't exist." }
	end
	local piece = GearStats.roll(crateRandom, crate, PlayerDataService.luckMultiplier(player))
	local outcome, pieceId = PlayerDataService.openFreeCrate(player, piece, GearStatsConfig.MaxPieces)
	local view = PlayerDataService.getRanks(player)
	if outcome == "Opened" then
		return { ok = true, message = GearStats.pieceName(piece) .. "!", piece = piece, pieceId = pieceId, view = view }
	elseif outcome == "NoneLeft" then
		return { ok = false, message = "No free crates left. Rank up for more!", view = view }
	elseif outcome == "Full" then
		return { ok = false, message = string.format("Your gear is full (%d pieces). Scrap some in MY GEAR first.",
			GearStatsConfig.MaxPieces), view = view }
	end
	return { ok = false, message = "That crate didn't open. Try again.", view = view }
end

function RankService.start()
	local set = RankRemotes.createOnServer(ReplicatedStorage)
	remotes = set

	set.get.OnServerInvoke = function(player: Player): any
		return PlayerDataService.getRanks(player)
	end
	set.claim.OnServerInvoke = function(player: Player, upTo: any): any
		if tooSoon(player) then
			return { paid = nil, view = PlayerDataService.getRanks(player) }
		end
		-- (nil = every rank waiting; a number = only up to that rank: the moment for that rank-up)
		local limit = if typeof(upTo) == "number" and upTo == upTo and upTo >= 1 and upTo <= RankConfig.Count
			then math.floor(upTo) else nil
		local paid = PlayerDataService.claimRankRewards(player, limit)
		local view = PlayerDataService.getRanks(player)
		if paid and #paid.ranks > 0 then
			log("%s claimed %d rank(s): %d coins, %d crates%s", player.Name, #paid.ranks, paid.coins, paid.crates,
				if paid.luckBoost then ", luck boost" else "")
		end
		return { paid = paid, view = view }
	end
	set.openFreeCrate.OnServerInvoke = function(player: Player, crateId: any): any
		if tooSoon(player) then
			return { ok = false, message = "One at a time." }
		end
		if typeof(crateId) ~= "string" or #crateId > 40 then
			return { ok = false, message = "That crate doesn't exist." }
		end
		return openFreeCrate(player, crateId)
	end
	set.setTitle.OnServerInvoke = function(player: Player, id: any): any
		if tooSoon(player) or typeof(id) ~= "string" or #id > 40 then
			return PlayerDataService.getRanks(player)
		end
		if PlayerDataService.setTitle(player, id) then
			publish(player, nil)
		end
		return PlayerDataService.getRanks(player)
	end
	set.titlesSeen.OnServerInvoke = function(player: Player): any
		if not tooSoon(player) then
			PlayerDataService.markTitlesSeen(player)
		end
		return PlayerDataService.getRanks(player)
	end

	local function joined(player: Player)
		task.spawn(function()
			if PlayerDataService.waitForData(player) then
				publish(player, nil)
			end
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in ipairs(Players:GetPlayers()) do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
	log("ready: %d ranks, %d titles", RankConfig.Count, #RankConfig.Titles)
end

return RankService
