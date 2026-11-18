--!strict
--[[
	NationalsQueue
	Server / Meet

	The Nationals sign-up list SHARED BY EVERY SERVER (GAME_DESIGN.md §39, step 1), and the
	hand-shake at the start that picks ONE server to run the gathering. NationalsService owns
	the players; this module only keeps the list and the outcome.

	Two ways to keep it, the same calls for both:
		"MemoryStore"  live: Roblox MemoryStore sorted maps, which every server of the game reads
		               and writes (NationalsConfig.SignUpMapPrefix, RoundMapName)
		"Local"        Studio, or when MemoryStore can't be reached: plain tables in this server
		               (Studio has one server, so that IS every server)

	THE START, in every server that has someone signed up:
		1. claim(round)    one server wins the round (a MemoryStore UpdateAsync, which runs one at a
		                   time per key across servers). A claim that goes quiet for ClaimStaleSeconds
		                   can be taken over, so a server shutting down can't stop a Nationals.
		2. the winner reads the whole list, decides "go" (reserving the Nationals server) or
		   "cancelled" (too few), and publish()es the outcome
		3. every server reads outcome(round) and sends its own lifters

	COST (MemoryStore is free within its quota): a sign-up or take-off is one write; a server with a
	spot-holder online reads the count every CountRefreshSeconds; the start is a few reads and writes
	per taking-part server. Far below the limit (1000 + 100 per player online, per minute).
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NationalsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("NationalsConfig"))

local NationalsQueue = {}

-- One lifter on the list.
export type Entry = { userId: number, name: string, classKey: string, signedAt: number }

-- How a Nationals start ended. status "go": lifters = who goes (UserId -> class), and where. "cancelled": too few.
export type Outcome = {
	status: string,
	count: number,
	lifters: { [string]: string }?,
	accessCode: string?,
	privateServerId: string?,
}

-- What a Nationals server reads about itself.
export type ServerInfo = { round: number, lifters: { [string]: string }, names: { [string]: string } }

export type Queue = {
	kind: string,
	add: (round: number, entry: Entry) -> boolean,
	remove: (round: number, userId: number) -> boolean,
	-- Up to `max`, first signed up first; nil when it can't be read.
	list: (round: number, max: number) -> { Entry }?,
	count: (round: number) -> number?,
	-- Whether THIS server now runs the round's gathering.
	claim: (round: number) -> boolean,
	publish: (round: number, outcome: Outcome) -> boolean,
	-- The outcome once published, else nil.
	outcome: (round: number) -> Outcome?,
	registerServer: (privateServerId: string, info: ServerInfo) -> boolean,
	serverInfo: (privateServerId: string) -> ServerInfo?,
	-- START NATIONALS NOW: an early start every server picks up (its start time), and reading it back (nil = none).
	setForced: (round: number) -> boolean,
	forced: () -> number?,
}

local function warnOnce(seen: { [string]: boolean }, what: string, problem: any)
	if not seen[what] then
		seen[what] = true
		warn(string.format("[NationalsQueue] %s failed: %s", what, tostring(problem)))
	end
end

-- A usable entry read back from the store (anything else is skipped).
local function entryFrom(value: any): Entry?
	if typeof(value) ~= "table" or typeof(value.userId) ~= "number" or typeof(value.classKey) ~= "string"
		or typeof(value.signedAt) ~= "number" then
		return nil
	end
	return { userId = value.userId, name = if typeof(value.name) == "string" then value.name else "?",
		classKey = value.classKey, signedAt = value.signedAt }
end

local function claimTransform(serverId: string, nowUnix: number)
	return function(old: any): any
		if typeof(old) ~= "table" then
			return { claimer = serverId, claimedAt = nowUnix }
		end
		if old.status ~= nil then
			return nil -- decided already
		end
		if old.claimer == serverId then
			return old
		end
		if typeof(old.claimedAt) ~= "number" or nowUnix - old.claimedAt > NationalsConfig.ClaimStaleSeconds then
			return { claimer = serverId, claimedAt = nowUnix }
		end
		return nil
	end
end

--[[
	The MemoryStore list. `prefix` keeps Studio's keys apart; `serverId` names this server in a claim.
]]
local function memoryStoreQueue(prefix: string, serverId: string): Queue
	local seen: { [string]: boolean } = {}
	local rounds = MemoryStoreService:GetSortedMap(prefix .. NationalsConfig.RoundMapName)
	local maps: { [number]: MemoryStoreSortedMap } = {}
	local function mapFor(round: number): MemoryStoreSortedMap
		local known: MemoryStoreSortedMap? = maps[round]
		if known then
			return known
		end
		local map = MemoryStoreService:GetSortedMap(prefix .. NationalsConfig.SignUpMapPrefix .. tostring(round))
		maps[round] = map
		return map
	end
	local function keepFor(round: number, extra: number): number
		-- Seconds from now; MemoryStore wants a whole number of at least 1.
		return math.max(60, math.floor(round - os.time() + extra))
	end

	local queue = {} :: Queue
	queue.kind = "MemoryStore"
	queue.add = function(round, entry)
		local ok, problem = pcall(function()
			mapFor(round):SetAsync(tostring(entry.userId), entry, keepFor(round, NationalsConfig.SignUpKeepSeconds), entry.signedAt)
		end)
		if not ok then
			warnOnce(seen, "add", problem)
		end
		return ok
	end
	queue.remove = function(round, userId)
		local ok, problem = pcall(function()
			mapFor(round):RemoveAsync(tostring(userId))
		end)
		if not ok then
			warnOnce(seen, "remove", problem)
		end
		return ok
	end
	queue.list = function(round, max)
		local ok, result = pcall(function()
			return mapFor(round):GetRangeAsync(Enum.SortDirection.Ascending, math.clamp(max, 1, 200))
		end)
		if not ok or typeof(result) ~= "table" then
			warnOnce(seen, "list", result)
			return nil
		end
		local entries: { Entry } = {}
		for _, item in ipairs(result :: { any }) do
			local entry = entryFrom(item.value)
			if entry then
				table.insert(entries, entry)
			end
		end
		return entries
	end
	queue.count = function(round)
		local entries = queue.list(round, 200)
		return if entries then #entries else nil
	end
	queue.claim = function(round)
		local ok, result = pcall(function()
			return rounds:UpdateAsync(tostring(round), claimTransform(serverId, os.time()),
				keepFor(round, NationalsConfig.RoundKeepSeconds))
		end)
		if not ok then
			warnOnce(seen, "claim", result)
			return false
		end
		return typeof(result) == "table" and result.claimer == serverId and result.status == nil
	end
	queue.publish = function(round, outcome)
		local ok, problem = pcall(function()
			rounds:SetAsync(tostring(round), outcome, keepFor(round, NationalsConfig.RoundKeepSeconds))
		end)
		if not ok then
			warnOnce(seen, "publish", problem)
		end
		return ok
	end
	queue.outcome = function(round)
		local ok, value = pcall(function()
			return rounds:GetAsync(tostring(round))
		end)
		if not ok then
			warnOnce(seen, "outcome", value)
			return nil
		end
		if typeof(value) == "table" and typeof(value.status) == "string" and typeof(value.count) == "number" then
			return value :: any
		end
		return nil
	end
	queue.registerServer = function(privateServerId, info)
		local ok, problem = pcall(function()
			rounds:SetAsync("server_" .. privateServerId, info, keepFor(info.round, NationalsConfig.RoundKeepSeconds))
		end)
		if not ok then
			warnOnce(seen, "registerServer", problem)
		end
		return ok
	end
	queue.serverInfo = function(privateServerId)
		local ok, value = pcall(function()
			return rounds:GetAsync("server_" .. privateServerId)
		end)
		if not ok then
			warnOnce(seen, "serverInfo", value)
			return nil
		end
		if typeof(value) == "table" and typeof(value.round) == "number" and typeof(value.lifters) == "table" then
			return value :: any
		end
		return nil
	end
	queue.setForced = function(round)
		local ok, problem = pcall(function()
			rounds:SetAsync("forced", round, keepFor(round, 120))
		end)
		if not ok then
			warnOnce(seen, "setForced", problem)
		end
		return ok
	end
	queue.forced = function()
		local ok, value = pcall(function()
			return rounds:GetAsync("forced")
		end)
		if not ok then
			warnOnce(seen, "forced", value)
			return nil
		end
		return if typeof(value) == "number" then value else nil
	end
	return queue
end

-- The in-server list (Studio): the same calls on plain tables.
local function localQueue(serverId: string): Queue
	local lists: { [number]: { [number]: Entry } } = {}
	local rounds: { [number]: any } = {}
	local servers: { [string]: ServerInfo } = {}
	local queue = {} :: Queue
	queue.kind = "Local"
	queue.add = function(round, entry)
		lists[round] = lists[round] or {}
		lists[round][entry.userId] = table.clone(entry)
		return true
	end
	queue.remove = function(round, userId)
		if lists[round] then
			lists[round][userId] = nil
		end
		return true
	end
	queue.list = function(round, max)
		local entries: { Entry } = {}
		for _, entry in pairs(lists[round] or {}) do
			table.insert(entries, table.clone(entry))
		end
		table.sort(entries, function(a, b)
			return if a.signedAt ~= b.signedAt then a.signedAt < b.signedAt else a.userId < b.userId
		end)
		while #entries > max do
			table.remove(entries)
		end
		return entries
	end
	queue.count = function(round)
		local n = 0
		for _ in pairs(lists[round] or {}) do
			n += 1
		end
		return n
	end
	queue.claim = function(round)
		local updated = claimTransform(serverId, os.time())(rounds[round])
		if updated == nil then
			return false
		end
		rounds[round] = updated
		return updated.claimer == serverId and updated.status == nil
	end
	queue.publish = function(round, outcome)
		rounds[round] = table.clone(outcome)
		return true
	end
	queue.outcome = function(round)
		local value = rounds[round]
		return if typeof(value) == "table" and value.status ~= nil then value else nil
	end
	queue.registerServer = function(privateServerId, info)
		servers[privateServerId] = info
		return true
	end
	queue.serverInfo = function(privateServerId)
		return servers[privateServerId]
	end
	local forcedRound: number? = nil
	queue.setForced = function(round)
		forcedRound = round
		return true
	end
	queue.forced = function()
		return forcedRound
	end
	return queue
end

--[[
	The list for this server: MemoryStore when `useMemoryStore` and it answers a test read, else the in-server one.
	Yields (the test read).
]]
function NationalsQueue.new(useMemoryStore: boolean, prefix: string, serverId: string): Queue
	if useMemoryStore then
		local ok, problem = pcall(function()
			MemoryStoreService:GetSortedMap(prefix .. NationalsConfig.RoundMapName):GetAsync("probe")
		end)
		if ok then
			return memoryStoreQueue(prefix, serverId)
		end
		warn("[NationalsQueue] MemoryStore can't be reached, so Nationals only gathers lifters in THIS server: " .. tostring(problem))
	end
	return localQueue(serverId)
end

-- For tests (tools/studio): the in-server list on its own.
NationalsQueue.localQueue = localQueue

return NationalsQueue
