--!strict
--[[
	GymRecords
	Server / Meet

	The GYM RECORD wall's records (GAME_DESIGN.md §31.6, "The gym record wall —
	first build", user 2026-10-30): per weight class the heaviest official-meet
	Squat, Bench and Deadlift, and the biggest Total (one lifter's three
	official-meet bests added up), each with its holder. One set for the whole
	game, saved.

	WHERE THE CLAIMS COME FROM
	Only an official meet calls submit() (today: LocalMeetService, after it has
	saved a good lift as the lifter's official-meet best). Nothing here listens
	to a client.

	HOW THEY ARE SAVED
	One DataStore key (GymRecordsConfig.Key) holds every class:
		{ classes = { ["83 kg"] = { Squat = { userId, kg, at }, ... } } }
	A claim is written with UpdateAsync and only when it is HEAVIER than the
	record there, so two servers can never lower a record, and on a tie the
	first lifter keeps it. The player's own save is not touched here.

	STUDIO
	Studio runs never reach the live wall. With Studio's API access on, the
	records use the "Studio_" store; with it off (the usual case) they live in
	memory only and vanish when Play stops.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Settings = require(ConfigFolder:WaitForChild("GymRecordsConfig"))
local WeightClassConfig = require(ConfigFolder:WaitForChild("WeightClassConfig"))

local GymRecords = {}

-- A record and who holds it. `at` is os.time() when it was set.
export type Holder = { userId: number, kg: number, at: number }
-- One class's records, keyed by GymRecordsConfig.Records ("Squat", "Bench", "Deadlift", "Total").
export type ClassRecords = { [string]: Holder }
-- A record a claim broke: the new weight and the holder before (nil for an empty spot).
export type Broken = { record: string, kg: number, previous: Holder? }

type Job = { userId: number, classKey: string, claims: { [string]: number }, done: (({ Broken }) -> ())? }

-- A new record must beat the old one by more than this (kg); equal keeps the first lifter.
local HEAVIER_BY = 1e-6

-- "live" (the real store), "studio" (the Studio_ store) or "memory" (Studio without API access); nil until known.
local mode: string? = nil
local memory: any = nil -- the saved value in "memory" mode
local records: { [string]: ClassRecords } = {}
local listeners: { (classKey: string) -> () } = {}
local queue: { Job } = {}
local busy = false
local started = false
local saves = 0 -- finished saves; a refresh read that overlaps one is dropped

local isClass: { [string]: boolean } = {}
for _, class in ipairs(WeightClassConfig.Classes) do
	isClass[class.label] = true
end
local isRecord: { [string]: boolean } = {}
for _, record in ipairs(Settings.Records) do
	isRecord[record] = true
end

local function isFinite(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Studio's test players have negative ids; real players never do.
local function isUserId(value: any): boolean
	return isFinite(value) and value % 1 == 0 and (value > 0 or (RunService:IsStudio() and value ~= 0))
end

-- ---------------------------------------------------------------- the saved value

-- Only well-formed records of known classes survive a read; anything else is dropped, never guessed at.
local function clean(saved: any): { [string]: ClassRecords }
	local out: { [string]: ClassRecords } = {}
	local classes = if typeof(saved) == "table" then saved.classes else nil
	if typeof(classes) ~= "table" then
		return out
	end
	for classKey, classRecords in pairs(classes) do
		if isClass[classKey] and typeof(classRecords) == "table" then
			local kept: ClassRecords = {}
			for record, holder in pairs(classRecords) do
				if isRecord[record] and typeof(holder) == "table" and isUserId(holder.userId) and isFinite(holder.kg)
					and holder.kg > 0 and isFinite(holder.at) then
					kept[record] = { userId = holder.userId, kg = holder.kg, at = holder.at }
				end
			end
			out[classKey] = kept
		end
	end
	return out
end

local function storeName(): string
	return if mode == "studio" then Settings.StudioPrefix .. Settings.Store else Settings.Store
end

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	local deadline = os.clock() + 30
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and os.clock() < deadline do
		task.wait(1)
	end
end

local function announce(classKey: string)
	for _, listener in ipairs(listeners) do
		task.spawn(listener, classKey)
	end
end

-- Takes a freshly read set of records; tells the listeners which classes changed.
local function adopt(fresh: { [string]: ClassRecords })
	local changed: { string } = {}
	for _, class in ipairs(WeightClassConfig.Classes) do
		local before, after = records[class.label] or {}, fresh[class.label] or {}
		for _, record in ipairs(Settings.Records) do
			local a, b = before[record], after[record]
			if (a == nil) ~= (b == nil) or (a and b and (a.userId ~= b.userId or a.kg ~= b.kg)) then
				table.insert(changed, class.label)
				break
			end
		end
	end
	records = fresh
	for _, classKey in ipairs(changed) do
		announce(classKey)
	end
end

--[[
	Writes one job's claims. Returns the records it broke (empty when none),
	or nil when the save failed. Heavier only, inside UpdateAsync, so the
	comparison is made against what is really saved right now.
]]
local function save(job: Job, now: number): { Broken }?
	local broken: { Broken } = {}
	local seen: { [string]: ClassRecords }? = nil
	local function transform(old: any): any
		local value = clean(old)
		broken = {}
		local classRecords = value[job.classKey] or {}
		for _, record in ipairs(Settings.Records) do
			local kg = job.claims[record]
			if kg then
				local current = classRecords[record]
				if current == nil or kg > current.kg + HEAVIER_BY then
					table.insert(broken, { record = record, kg = kg, previous = current })
					classRecords[record] = { userId = job.userId, kg = kg, at = now }
				end
			end
		end
		value[job.classKey] = classRecords
		seen = value
		if #broken == 0 then
			return nil -- nothing heavier: write nothing
		end
		return { classes = value }
	end

	if mode == "memory" then
		local written = transform(memory)
		if written then
			memory = written
		end
	else
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		local ok, err = pcall(function()
			DataStoreService:GetDataStore(storeName()):UpdateAsync(Settings.Key, transform)
		end)
		if not ok then
			warn(string.format("[GymRecords] saving %d's %s claims failed: %s", job.userId, job.classKey, tostring(err)))
			return nil
		end
	end
	if seen then
		saves += 1
		adopt(seen)
	end
	return broken
end

local function read(): { [string]: ClassRecords }?
	if mode == "memory" then
		return clean(memory)
	end
	waitForBudget(Enum.DataStoreRequestType.GetAsync)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(storeName()):GetAsync(Settings.Key)
	end)
	if not ok then
		warn("[GymRecords] reading the records failed: " .. tostring(result))
		return nil
	end
	return clean(result)
end

-- In Studio, find out whether the DataStores answer (API access on) or not.
local function detectMode(): string
	if not RunService:IsStudio() then
		return "live"
	end
	local ok = pcall(function()
		DataStoreService:GetDataStore(Settings.StudioPrefix .. Settings.Store):GetAsync("Probe")
	end)
	return if ok then "studio" else "memory"
end

local function work()
	if busy then
		return
	end
	busy = true
	while #queue > 0 do
		local job = table.remove(queue, 1) :: Job
		local broken: { Broken }? = nil
		for try = 1, Settings.SaveRetries do
			broken = save(job, os.time())
			if broken then
				break
			elseif try < Settings.SaveRetries then
				task.wait(2 ^ try)
			end
		end
		if broken == nil then
			warn(string.format("[GymRecords] gave up saving %d's %s claims", job.userId, job.classKey))
		elseif job.done then
			task.spawn(job.done, broken)
		end
	end
	busy = false
end

-- ---------------------------------------------------------------- the API

--[[
	An official meet's claim: `userId` made these weights (kg per record name,
	e.g. { Squat = 190, Total = 540 }) in `classKey`, the weigh-in class. Each
	is saved if it is heavier than the record there. `done` (optional) gets
	the records that were broken, once saved. Returns at once; the save runs
	in the background.

	THE CALLER VOUCHES FOR THE WEIGHTS: a server-run official meet that has
	judged the lift good (and for Total, the lifter's saved official-meet
	bests added up). No client may reach this.
]]
function GymRecords.submit(userId: number, classKey: string, claims: { [string]: number }, done: (({ Broken }) -> ())?)
	if not isUserId(userId) or not isClass[classKey] or typeof(claims) ~= "table" then
		warn(string.format("[GymRecords] refused a claim (%s, %s)", tostring(userId), tostring(classKey)))
		return
	end
	local kept: { [string]: number } = {}
	for record, kg in pairs(claims) do
		if isRecord[record] and isFinite(kg) and kg > 0 then
			kept[record] = kg
		end
	end
	if next(kept) == nil then
		return
	end
	table.insert(queue, { userId = userId, classKey = classKey, claims = kept, done = done })
	if mode ~= nil then
		task.spawn(work)
	end
end

-- One class's records as last read (a copy; empty when it has none, nil for an unknown class).
function GymRecords.get(classKey: string): ClassRecords?
	if not isClass[classKey] then
		return nil
	end
	local copy: ClassRecords = {}
	for record, holder in pairs(records[classKey] or {}) do
		copy[record] = table.clone(holder)
	end
	return copy
end

-- Calls `listener(classKey)` whenever a class's records change (a new record here, or one read from another server).
function GymRecords.onChanged(listener: (classKey: string) -> ())
	table.insert(listeners, listener)
end

-- "live", "studio" or "memory" once known (for the wall's test label), else nil.
function GymRecords.mode(): string?
	return mode
end

function GymRecords.start()
	if started then
		return
	end
	started = true
	-- Before a live server shuts down, give the waiting saves time to finish.
	game:BindToClose(function()
		local deadline = os.clock() + 25
		while (#queue > 0 or busy) and os.clock() < deadline do
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		mode = detectMode()
		print("[GymRecords] records: " .. (mode :: string))
		local fresh = read()
		if fresh then
			adopt(fresh)
		end
		task.spawn(work)
		while true do
			task.wait(Settings.RefreshSeconds)
			if not busy then
				local savesBefore = saves
				local again = read()
				-- A save that finished while reading already holds newer records than this read.
				if again and saves == savesBefore then
					adopt(again)
				end
			end
		end
	end)
end

return GymRecords
