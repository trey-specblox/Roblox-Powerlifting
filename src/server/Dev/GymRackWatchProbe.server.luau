--!strict
--[[
	GymRackWatchProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Checkpoint 6D.2a. Watches LIVE training sessions at
	one spawned rack (WATCH_STATION) during a Studio playtest and prints
	PASS/FAIL lines to the SERVER's Output. Replaces the Command Bar watcher,
	which cannot reach the server during a multi-client Local Server test.

	READ-ONLY towards the game. It requires no game module, calls no game code,
	creates no remotes and never touches a profile. It only LISTENS
	(LogService.MessageOut) to the "[TrainingStationService]" lines the training
	service already prints (TrainingStationService's VERBOSE must stay true),
	and reads the rack's sign text. Nothing requires this script.

	Its only output besides Output lines: a runtime Folder of text values,
	ReplicatedStorage.GymRackWatchProbeResults, so the Studio-only client
	display (src/client/Dev/GymRackWatchDisplay.luau) can show the results in
	every player window. Clients only read it.

	Runs ONLY when ENABLED is true AND the game is running inside Roblox Studio.
	In a live server, or with ENABLED = false, the script returns on its first
	lines: no connection, no output, no behaviour at all.

	What it checks, for sessions on WATCH_STATION:
	  CN ticks         EV earned > 0, CN never drops, each tick starts from exactly
	                   the CN the previous tick ended on (nothing lost, nothing
	                   credited twice), credited seconds within 0..30.
	  Technique ticks  every gain is positive, and each stat's new value is its
	                   previous value plus exactly that gain (within rounding).
	                   "Previous" (for CN too) is the last value logged at ANY
	                   rack, so training elsewhere is not mistaken for extra credit.
	  Release          the reason (stopped / died / character removed / left the
	                   game / ...), then that the rack sign reads "Free".
	  No double credit total credited seconds never exceed the real time held,
	                   and NO tick for that player arrives in the 15 s after the
	                   release (a tick is due every 10 s).

	=========================================================================
	OFF BY DEFAULT. SET TO true TO RUN IT; SET BACK TO false AFTERWARDS.
	=========================================================================
]]

local ENABLED = false
if not ENABLED then
	return
end

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local LogService = game:GetService("LogService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WATCH_STATION = "GymRack_01"
local PREFIX = "[TrainingStationService] "
local TAG = "[GymRackWatchProbe] "
local MAX_CREDIT = 30
local QUIET_SECONDS = 15
local CN_TOLERANCE = 0.0015 -- CN is printed with 3 decimals
local TECHNIQUE_TOLERANCE = 0.00011 -- technique raw values are printed with 4 decimals

--[[
	One watcher per server. A second copy of this script (or a re-run) replaces
	the earlier connection instead of adding another, so every line is judged once.
]]
local shared = _G :: any
if shared.GymRackWatchProbeConnection then
	shared.GymRackWatchProbeConnection:Disconnect()
	print(TAG .. "an earlier watcher was replaced")
end

type Watch = {
	station: string?,
	startedAt: number?,
	credited: number,
	ticks: number,
	lastCN: { [string]: number },
	lastStat: { [string]: number },
	releasedAt: number?,
}

local players: { [string]: Watch } = {}
local passes, fails = 0, 0
local sawTrainingService = false

--[[
	ON-SCREEN RESULTS (for multi-client tests, where player windows cannot see
	the server's Output). Every result line is ALSO written as a StringValue into
	ReplicatedStorage.GymRackWatchProbeResults, which Roblox replicates to every
	client; the Studio-only GymRackWatchDisplay client module shows it on screen.
	There is no RemoteEvent: clients have nothing to send, and anything a client
	changes in its replicated copy never reaches the server. The folder exists
	only while this probe runs, so with ENABLED = false the display stays hidden.
]]
local RESULTS_FOLDER_NAME = "GymRackWatchProbeResults"
local MAX_PUBLISHED = 150

local existingResults = ReplicatedStorage:FindFirstChild(RESULTS_FOLDER_NAME)
if existingResults then
	existingResults:Destroy()
end
local resultsFolder = Instance.new("Folder")
resultsFolder.Name = RESULTS_FOLDER_NAME
resultsFolder:SetAttribute("WatchStation", WATCH_STATION)
resultsFolder:SetAttribute("Passes", 0)
resultsFolder:SetAttribute("Fails", 0)
resultsFolder.Parent = ReplicatedStorage

local publishedCount = 0

local function publish(kind: string, message: string)
	publishedCount += 1
	local entry = Instance.new("StringValue")
	entry.Name = string.format("%05d", publishedCount)
	entry.Value = message
	entry:SetAttribute("Kind", kind)
	entry.Parent = resultsFolder

	resultsFolder:SetAttribute("Passes", passes)
	resultsFolder:SetAttribute("Fails", fails)

	local oldest = resultsFolder:FindFirstChild(string.format("%05d", publishedCount - MAX_PUBLISHED))
	if oldest then
		oldest:Destroy()
	end
end

-- An information line: server Output and the on-screen list.
local function info(message: string, isWarning: boolean?)
	if isWarning then
		warn(TAG .. message)
	else
		print(TAG .. message)
	end
	publish(if isWarning then "WARN" else "INFO", message)
end

local function report(passed: boolean, message: string)
	if passed then
		passes += 1
		print(TAG .. "PASS  " .. message)
	else
		fails += 1
		warn(TAG .. "FAIL  " .. message)
	end
	publish(if passed then "PASS" else "FAIL", message)
end

local function watchFor(name: string): Watch
	local w = players[name]
	if w == nil then
		local fresh: Watch = { credited = 0, ticks = 0, lastCN = {}, lastStat = {} }
		players[name] = fresh
		return fresh
	end
	return w
end

local function signText(): string
	local folder = Workspace:FindFirstChild("GymRacks")
	local rack = folder and folder:FindFirstChild(WATCH_STATION)
	local sign = rack and rack:FindFirstChild("TrainingStatus", true)
	local label = sign and sign:FindFirstChildWhichIsA("TextLabel")
	return if label then label.Text else "(no sign found)"
end

-- A tick line for a player who is NOT holding WATCH_STATION right now.
local function tickWhileNotHolding(name: string, w: Watch, line: string)
	if w.releasedAt ~= nil then
		report(false, string.format("%s was credited %.1f s after leaving %s: %s",
			name, os.clock() - (w.releasedAt :: number), WATCH_STATION, line))
	end
end

local function onTraining(line: string)
	sawTrainingService = true
	local now = os.clock()

	-- "<player> started <mode> <lift>[ (<primary>)] on <station>"
	local name, mode, lift, station = string.match(line, "^(%S+) started (%S+) (%S+).- on (%S+)$")
	if name and station then
		local w = watchFor(name)
		if station == WATCH_STATION then
			if w.station ~= WATCH_STATION then
				w.startedAt, w.credited, w.ticks = now, 0, 0
			end
			w.station, w.releasedAt = station, nil
			info(string.format("%s started %s %s on %s; watching ticks", name, tostring(mode), tostring(lift), station))
		else
			-- Training at another rack is not credit "after leaving" this one.
			w.station, w.releasedAt = station, nil
		end
		return
	end

	-- "<player> reserved <station>"
	local rName, rStation = string.match(line, "^(%S+) reserved (%S+)$")
	if rName and rStation then
		local w = watchFor(rName)
		if rStation == WATCH_STATION and w.station ~= WATCH_STATION then
			w.station, w.startedAt, w.credited, w.ticks, w.releasedAt = rStation, now, 0, 0, nil
		elseif rStation ~= WATCH_STATION then
			w.station, w.releasedAt = rStation, nil
		end
		return
	end

	-- "<player> <lift> technique tick: <s> s credited, <outcome>, +<raw> <stat> -> <after>, ..."
	local tName, tLift, tSeconds, tRest = string.match(line, "^(%S+) (%S+) technique tick: ([%d%.]+) s credited, (.*)$")
	if tName and tLift and tRest then
		local w = watchFor(tName)
		if w.station ~= WATCH_STATION then
			tickWhileNotHolding(tName, w, line)
			--[[
				Every award is logged, so a tick at ANY rack is a real stat change.
				Remember the new values; otherwise the next GymRack_01 tick would
				be compared with a stale value and FAIL falsely (seen 2026-10-16).
			]]
			for _, statText, afterText in string.gmatch(tRest, "%+([%d%.]+) (%S+) %-> ([%d%.]+)") do
				w.lastStat[tostring(statText)] = tonumber(afterText) or 0
			end
			return
		end
		local seconds = tonumber(tSeconds) or -1
		w.credited += seconds
		w.ticks += 1
		report(seconds > 0 and seconds <= MAX_CREDIT,
			string.format("%s technique tick %d credited %.1f s (0..%d)", tName, w.ticks, seconds, MAX_CREDIT))
		local gains = 0
		for rawText, statText, afterText in string.gmatch(tRest, "%+([%d%.]+) (%S+) %-> ([%d%.]+)") do
			gains += 1
			local stat = tostring(statText)
			local rawN, afterN = tonumber(rawText) or 0, tonumber(afterText) or 0
			local before = w.lastStat[stat]
			report(rawN > 0 and (before == nil or math.abs(afterN - (before + rawN)) <= TECHNIQUE_TOLERANCE),
				string.format("%s %s %s +%.5f -> %.4f%s", tName, tLift, stat, rawN, afterN,
					if before then string.format(" (was %.4f, so exactly this gain was added)", before) else ""))
			w.lastStat[stat] = afterN
		end
		report(gains > 0, string.format("%s technique tick %d gave at least one stat gain", tName, w.ticks))
		return
	end

	-- "<player> <lift> tick: <s> s credited, <outcome>, +<ev> EV, CN <a> -> <b>[ (cap)]"
	local cName, cLift, cSeconds, _, cEV, cBefore, cAfter =
		string.match(line, "^(%S+) (%S+) tick: ([%d%.]+) s credited, (%S+), %+([%d%.]+) EV, CN ([%d%.]+) %-> ([%d%.]+)")
	if cName and cLift then
		local w = watchFor(cName)
		if w.station ~= WATCH_STATION then
			tickWhileNotHolding(cName, w, line)
			-- Same as technique: CN earned at another rack is real, so remember it.
			w.lastCN[cLift] = tonumber(cAfter) or 0
			return
		end
		local seconds, ev = tonumber(cSeconds) or -1, tonumber(cEV) or 0
		local before, after = tonumber(cBefore) or 0, tonumber(cAfter) or 0
		w.credited += seconds
		w.ticks += 1
		report(seconds > 0 and seconds <= MAX_CREDIT,
			string.format("%s CN tick %d credited %.1f s (0..%d)", cName, w.ticks, seconds, MAX_CREDIT))
		-- CN is printed to 3 decimals, so one short tick may not visibly move it.
		report(ev > 0 and after >= before,
			string.format("%s %s CN tick %d: +%s EV, CN %s -> %s", cName, cLift, w.ticks, tostring(cEV),
				tostring(cBefore), tostring(cAfter)))
		local previous = w.lastCN[cLift]
		if previous ~= nil then
			report(math.abs(before - previous) <= CN_TOLERANCE,
				string.format("%s %s CN continues from the last tick (%.3f, last ended %.3f)", cName, cLift, before, previous))
		end
		w.lastCN[cLift] = after
		return
	end

	-- "<player> tick: <s> s measured, <mode> <lift>, <status>, nothing credited"
	local nName = string.match(line, "^(%S+) tick: [%d%.]+ s measured, .*nothing credited$")
	if nName then
		if watchFor(nName).station == WATCH_STATION then
			info(line)
		end
		return
	end

	-- "<player> left <station> (<reason>)"
	local lName, lStation, reason = string.match(line, "^(%S+) left (%S+) %((.*)%)$")
	if lName and lStation == WATCH_STATION then
		local w = watchFor(lName)
		local held = if w.startedAt then now - (w.startedAt :: number) else 0
		w.station, w.releasedAt = nil, now
		info(string.format("%s left %s, reason: %s (%d ticks, %.1f s credited, %.1f s held)",
			lName, WATCH_STATION, tostring(reason), w.ticks, w.credited, held))
		report(w.credited <= held + 1,
			string.format("%s was credited no more time than they held the rack (%.1f <= %.1f s)", lName, w.credited, held))

		task.delay(0.5, function()
			local text = signText()
			report(string.find(text, "Free", 1, true) ~= nil,
				string.format("%s sign reads Free after %s left (sign: \"%s\")", WATCH_STATION, lName,
					(string.gsub(text, "\n", " | "))))
		end)
		local releasedAt = now
		task.delay(QUIET_SECONDS, function()
			-- A later tick would already have FAILED above; this records the quiet period as a pass.
			if w.releasedAt == releasedAt then
				report(true, string.format("no credit for %s in the %d s after leaving %s", lName, QUIET_SECONDS, WATCH_STATION))
				info(string.format("totals so far: %d PASS, %d FAIL", passes, fails))
			end
		end)
	end
end

shared.GymRackWatchProbeConnection = LogService.MessageOut:Connect(function(message: string)
	if string.sub(message, 1, #PREFIX) == PREFIX then
		local line = string.sub(message, #PREFIX + 1)
		local ok, err = pcall(function()
			onTraining(line)
		end)
		if not ok then
			info("could not read a line: " .. tostring(err), true)
		end
	end
end)

-- The training service may have printed its start line before this script connected.
for _, entry in ipairs(LogService:GetLogHistory()) do
	if string.sub(entry.message, 1, #PREFIX) == PREFIX then
		sawTrainingService = true
		break
	end
end

info(string.format("ENABLED (Studio only). Watching %s. Set ENABLED back to false when finished.", WATCH_STATION))

task.delay(20, function()
	if not sawTrainingService then
		info("no [TrainingStationService] lines seen in 20 s. Is the training service running "
			.. "with VERBOSE = true? Without its lines this watcher cannot check anything.", true)
	end
end)
