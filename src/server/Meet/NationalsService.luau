--!strict
--[[
	NationalsService
	Server / Meet

	NATIONALS, STEP 1: THE GATHERING (GAME_DESIGN.md §39, user 2026-11-17). Every NationalsConfig
	cycle (2 hours, on the same UTC clock in every server), every spot-holder who signed up, in any
	server, is sent into ONE Nationals server (a reserved server), where they arrive in the stand-in
	venue: the State arena dressed as NATIONALS (StateArenaVenue.dressAsNationals). The meet itself
	(per class, titles, x5 pot, the Worlds spot) is step 2 and is NOT here.

	SIGNING UP: the NATIONALS row of the MEETS list (NationalsRemotes.SIGN_UP) or the NATIONALS desk in
	the State arena's lobby. The server checks the spot: ProfileOperations.getNationals(...).qualified
	in the class the player weighs in at now (the class their spot must be in). A press takes the name
	off again. Sign-ups close SignUpClosesSeconds before the start. The list is shared by every server
	(NationalsQueue: MemoryStore live).

	THE START (gather), in every server with someone signed up:
		- one server wins the round (NationalsQueue.claim), waits a moment for late writes, reads the
		  whole list and decides: fewer than MinimumLifters (2) -> no Nationals, every sign-up carries to
		  the next one (user 2026-11-17); else it reserves the Nationals server and publishes who goes
		  (the first MaxLifters signed up) and its access code
		- every server then sends its own lifters: off any meet's list and OUT OF A MEET THEY ARE LIFTING
		  IN, which counts as withdrawing (user 2026-11-17: "Pulled out to Nationals";
		  LocalMeetService.pullOutForNationals), then the teleport (retried TeleportTries times; a lifter
		  it can't move goes on the next list)
	THE NATIONALS SERVER: a reserved server reads who it is for (NationalsQueue.serverInfo by its
	PrivateServerId), dresses the arena and brings each listed lifter into it; anyone not on the list is
	sent back. LEAVE NATIONALS teleports a lifter back to a public server. State meets don't run there.

	STUDIO cannot teleport between servers, so there it all happens in the one server: the list is
	NationalsQueue's in-server one (or MemoryStore with the workspace attribute
	StudioNationalsMemoryStore = true, Studio keys), and at "go" this server becomes the stand-in itself:
	the arena is dressed and the lifters are walked into it; LEAVE NATIONALS takes them back to the gym
	and the last one out undresses it. The reserved server and the teleports are LIVE-ONLY code.

	NOT LIVE YET (NationalsConfig.Live = false): in a live server only admins see the row (and the desk
	isn't built), test Nationals come every TestCycleSeconds and need TestMinimumLifters.

	SERVER AUTHORITY: a client only presses SIGN UP or LEAVE; who may sign up, who goes, and who may stay
	in a Nationals server are all decided here.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RobloxTeleport = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NationalsConfig = require(Shared:WaitForChild("Config"):WaitForChild("NationalsConfig"))
local NationalsRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("NationalsRemotes"))

local ServerFolder = script.Parent.Parent
local NationalsQueue = require(script.Parent:WaitForChild("NationalsQueue"))
local LocalMeetService = require(script.Parent:WaitForChild("LocalMeetService"))
local StateArenaVenue = require(script.Parent:WaitForChild("StateArenaVenue"))
local PlayerDataFolder = ServerFolder:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))
local AdminService = require(ServerFolder:WaitForChild("Admin"):WaitForChild("AdminService"))

local NationalsService = {}

local IS_STUDIO = RunService:IsStudio()
-- A live reserved server with no owner: what a Nationals server is (the game has no other reserved servers).
local IS_RESERVED = not IS_STUDIO and game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local REQUEST_GAP_SECONDS = 0.5
local ARENA_WAIT_SECONDS = 180
local ADMIT_WAIT_SECONDS = 60

type SignUp = { round: number, classKey: string, signedAt: number }
-- This server as the Nationals server (or Studio's stand-in): which Nationals, who it is for (UserId -> class).
type Here = { round: number, lifters: { [string]: string }, count: number }
type Pending = { tries: number, code: string, round: number, classKey: string, signedAt: number }

local started = false
local remotes: NationalsRemotes.RemoteSet? = nil
local queue: NationalsQueue.Queue? = nil
-- THIS server's own players on the list (it alone writes their entries).
local signUps: { [Player]: SignUp } = {}
-- Being sent to Nationals right now, and the teleports still being tried.
local going: { [Player]: boolean } = {}
local pending: { [Player]: Pending } = {}
-- A few words for the moment, per player ("GATHERING LIFTERS…").
local status: { [Player]: string } = {}
local busy: { [Player]: boolean } = {}
local lastPress: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}
-- The next Nationals' start (server time), and the one whose lifters were warned.
local upcoming = 0
local calledFor = 0
-- How many signed up for `countRound` across all servers, as last read.
local globalCount: number? = nil
local countRound = 0
local nextCountAt = 0
local nextForcedPollAt = 0
local here: Here? = nil
-- The lifters who are at Nationals in this server: their class.
local atNationals: { [Player]: string } = {}

local function log(message: string, ...: any)
	print("[NationalsService] " .. string.format(message, ...))
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Not Live: an admins' test Nationals in a live server.
local function testMode(): boolean
	return not IS_STUDIO and not NationalsConfig.Live
end

local function cycleSeconds(): number
	return if IS_STUDIO then NationalsConfig.StudioCycleSeconds
		elseif NationalsConfig.Live then NationalsConfig.CycleSeconds
		else NationalsConfig.TestCycleSeconds
end

local function closesSeconds(): number
	return if IS_STUDIO then NationalsConfig.StudioSignUpClosesSeconds else NationalsConfig.SignUpClosesSeconds
end

local function minimumLifters(): number
	-- Studio: the workspace attribute StudioNationalsMinimum (a number) overrides it, to test "not enough lifters" alone.
	local forced = if IS_STUDIO then Workspace:GetAttribute("StudioNationalsMinimum") else nil
	if typeof(forced) == "number" and forced >= 1 then
		return forced
	end
	return if IS_STUDIO then NationalsConfig.StudioMinimumLifters
		elseif NationalsConfig.Live then NationalsConfig.MinimumLifters
		else NationalsConfig.TestMinimumLifters
end

-- The next start after `t`, on the same clock in every server.
local function nextStartAfter(t: number): number
	local cycle = cycleSeconds()
	return (math.floor(t / cycle) + 1) * cycle
end

-- Whether Nationals is open to this player yet (Live, Studio, or an admin or listed tester while it is tested live).
local function openTo(player: Player): boolean
	return IS_STUDIO or NationalsConfig.Live or AdminService.isAdmin(player)
		or NationalsConfig.TesterUserIds[player.UserId] == true
end

-- "1:59:30", or "1:30" under an hour.
local function clockText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	if whole >= 3600 then
		return string.format("%d:%02d:%02d", whole // 3600, (whole % 3600) // 60, whole % 60)
	end
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function everyText(): string
	local cycle = cycleSeconds()
	return if cycle >= 3600 then string.format("Every %g hours", cycle / 3600) else string.format("Every %d min", cycle // 60)
end

local function notify(player: Player, message: string)
	if player.Parent then
		LocalMeetService.notify(player, message)
	end
end

local function pressAllowed(player: Player): boolean
	local time = os.clock()
	if time - (lastPress[player] or 0) < NationalsConfig.ButtonCooldownSeconds then
		return false
	end
	lastPress[player] = time
	return true
end

--[[
	The player's Nationals spot in the class they weigh in at now: (class, holds it, why not). Studio: the
	workspace attribute StudioNationalsAnyone = true lets anyone in, to test without earning it.
]]
local function spotFor(player: Player): (string?, boolean, string?)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return nil, false, "YOUR DATA IS STILL LOADING"
	end
	local classKey = ProfileOperations.getActiveClassKey(data)
	if classKey == nil then
		return nil, false, "NO WEIGHT CLASS"
	end
	if IS_STUDIO and Workspace:GetAttribute("StudioNationalsAnyone") == true then
		return classKey, true, nil
	end
	local view = ProfileOperations.getNationals(data, classKey, os.time())
	if view.qualified then
		return classKey, true, nil
	end
	return classKey, false, string.format("%d / %d TOWARD NATIONALS IN %s", view.placings, view.target, string.upper(classKey))
end

-- ---------------------------------------------------------------- what the screen shows

local function viewFor(player: Player): NationalsRemotes.View
	local classKey, qualified, why = spotFor(player)
	local mine = signUps[player]
	local at = atNationals[player]
	return {
		shown = openTo(player) or at ~= nil,
		here = at ~= nil,
		nextStartAt = upcoming,
		signUpClosesAt = upcoming - closesSeconds(),
		minimumLifters = minimumLifters(),
		potMultiplier = NationalsConfig.PotMultiplier,
		qualified = qualified,
		classLabel = at or (if mine then mine.classKey else classKey),
		why = why,
		signedUp = mine ~= nil,
		signedUpCount = if countRound == upcoming then globalCount else nil,
		status = status[player],
		liftersHere = if here then (here :: Here).count else nil,
		test = testMode(),
	}
end

local function sendView(player: Player)
	if remotes and player.Parent then
		remotes.state:FireClient(player, viewFor(player))
	end
end

local function broadcast()
	for _, player in ipairs(Players:GetPlayers()) do
		sendView(player)
	end
end

-- ---------------------------------------------------------------- signing up

local function toggleSignUp(player: Player)
	if not openTo(player) or busy[player] or going[player] then
		return
	end
	if atNationals[player] or IS_RESERVED then
		notify(player, "You are at Nationals now.")
		return
	end
	local q = queue
	if q == nil then
		notify(player, "Nationals is still starting up. Try again in a moment.")
		return
	end
	local mine = signUps[player]
	if mine then
		signUps[player] = nil
		status[player] = nil
		notify(player, "You took your name off the Nationals list.")
		sendView(player)
		busy[player] = true
		q.remove(mine.round, player.UserId)
		busy[player] = nil
		nextCountAt = 0
		return
	end
	local t = now()
	if t >= upcoming - closesSeconds() then
		notify(player, string.format("Sign-ups for this Nationals are closed. They open again when it starts, in %s.",
			clockText(upcoming - t)))
		return
	end
	local classKey, qualified, why = spotFor(player)
	if classKey == nil or not qualified then
		notify(player, "Nationals is for spot holders: " .. string.lower(why or "no spot")
			.. ". 10 top-3 State placings in a weight class earn that class's spot.")
		return
	end
	local entry: SignUp = { round = upcoming, classKey = classKey, signedAt = t }
	signUps[player] = entry
	sendView(player)
	busy[player] = true
	local added = q.add(entry.round, { userId = player.UserId, name = player.Name, classKey = classKey, signedAt = t })
	busy[player] = nil
	if not added then
		if signUps[player] == entry then
			signUps[player] = nil
		end
		notify(player, "Couldn't reach the Nationals list. Try again in a moment.")
		sendView(player)
		return
	end
	notify(player, string.format("You're signed up for Nationals (%s class). It starts in %s, and you'll be taken there "
		.. "from wherever you are, even out of a meet.", classKey, clockText(entry.round - now())))
	log("%s signed up for Nationals %d (%s)", player.Name, entry.round, classKey)
	nextCountAt = 0
	sendView(player)
end

-- These players stay on the list, for the next Nationals: told `why`.
local function carryOver(players: { Player }, why: string)
	local q = queue
	for _, player in ipairs(players) do
		status[player] = nil
		going[player] = nil
		local mine = signUps[player]
		if player.Parent and mine and q then
			mine.round = upcoming
			task.spawn(q.add, upcoming, { userId = player.UserId, name = player.Name, classKey = mine.classKey,
				signedAt = mine.signedAt })
			notify(player, why .. string.format(" You're on the list for the next Nationals, in %s.", clockText(upcoming - now())))
		end
		sendView(player)
	end
	nextCountAt = 0
end

-- ---------------------------------------------------------------- the Nationals server (or Studio's stand-in)

local function waitForArena(): boolean
	local deadline = os.clock() + ARENA_WAIT_SECONDS
	while StateArenaVenue.current() == nil and os.clock() < deadline do
		task.wait(1)
	end
	return StateArenaVenue.current() ~= nil
end

-- This server is now the Nationals server for `info` (live: a reserved server; Studio: the stand-in in this one).
local function becomeNationals(info: NationalsQueue.ServerInfo)
	local count = 0
	for _ in pairs(info.lifters) do
		count += 1
	end
	here = { round = info.round, lifters = info.lifters, count = count }
	Workspace:SetAttribute(NationalsConfig.ServerAttribute, info.round)
	log("this server is Nationals %d, for %d lifters", info.round, count)
	if waitForArena() then
		StateArenaVenue.dressAsNationals(true, NationalsConfig.EventTitle, NationalsConfig.EventSub)
	else
		warn("[NationalsService] the arena wasn't built, so Nationals has no venue")
	end
end

-- Studio's stand-in is over (its last lifter left): the arena is the State arena again.
local function endStandIn()
	here = nil
	Workspace:SetAttribute(NationalsConfig.ServerAttribute, nil)
	StateArenaVenue.dressAsNationals(false, NationalsConfig.EventTitle, NationalsConfig.EventSub)
	log("Studio's Nationals stand-in is over")
	broadcast()
end

-- Back to the game: a teleport to a public server (live only).
local function sendHome(player: Player)
	local ok, problem = pcall(function()
		RobloxTeleport:TeleportAsync(game.PlaceId, { player })
	end)
	if not ok then
		notify(player, "Couldn't take you back right now. Try again in a moment.")
		warn("[NationalsService] sending " .. player.Name .. " home failed: " .. tostring(problem))
	end
end

-- A player in the Nationals server: a listed lifter is walked into the arena; anyone else is sent back.
local function admit(player: Player)
	local h = here
	if h == nil or atNationals[player] then
		return
	end
	local classKey = h.lifters[tostring(player.UserId)]
	if classKey == nil then
		if not IS_STUDIO then
			notify(player, "This server is only for the lifters at Nationals. Taking you back to the game.")
			task.wait(4)
			if player.Parent then
				sendHome(player)
			end
		end
		return
	end
	atNationals[player] = classKey
	player:SetAttribute(NationalsConfig.AtNationalsAttribute, classKey)
	sendView(player)
	local deadline = os.clock() + ADMIT_WAIT_SECONDS
	local arrived, why = false, nil :: string?
	while player.Parent and os.clock() < deadline do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and StateArenaVenue.current() then
			arrived, why = LocalMeetService.bringToStateArena(player)
			if arrived then
				break
			end
		end
		task.wait(1)
	end
	if player.Parent == nil then
		return
	end
	if not arrived then
		warn(string.format("[NationalsService] %s could not be brought into the arena: %s", player.Name, tostring(why)))
		notify(player, "Couldn't walk you into the arena: " .. (why or "try the arena's doors outside the gym") .. ".")
	else
		notify(player, string.format("Welcome to NATIONALS (%s class)! %d %s made it here. The Nationals meet itself "
			.. "comes in the next update: look round, then press LEAVE on the NATIONALS row of MEETS to go back.", classKey, h.count,
			if h.count == 1 then "lifter" else "lifters"))
	end
	log("%s is at Nationals %d (%s), in the arena: %s", player.Name, h.round, classKey, tostring(arrived))
	broadcast()
end

-- LEAVE NATIONALS: live, back to a public server; Studio, out of the stand-in to the gym.
local function leaveNationals(player: Player)
	if atNationals[player] == nil then
		return
	end
	if not IS_STUDIO then
		sendHome(player)
		return
	end
	atNationals[player] = nil
	player:SetAttribute(NationalsConfig.AtNationalsAttribute, nil)
	LocalMeetService.leaveToGym(player)
	notify(player, "You left Nationals.")
	sendView(player)
	if next(atNationals) == nil then
		endStandIn()
	end
end

-- ---------------------------------------------------------------- the start

-- Reserves the Nationals server: (access code, private server id), or nil. Studio: made-up ones (no real server).
local function reserve(round: number): (string?, string?)
	if IS_STUDIO then
		return "studio", "studio_" .. tostring(round)
	end
	local ok, code, privateId = pcall(function()
		return RobloxTeleport:ReserveServer(game.PlaceId)
	end)
	if not ok or typeof(code) ~= "string" or typeof(privateId) ~= "string" then
		warn("[NationalsService] reserving the Nationals server failed: " .. tostring(code))
		return nil, nil
	end
	return code, privateId
end

-- This server won the round: reads the list, decides and publishes. Returns the outcome, or nil when it couldn't.
local function lead(round: number): NationalsQueue.Outcome?
	local q = queue :: NationalsQueue.Queue
	task.wait(NationalsConfig.SettleSeconds)
	local entries = q.list(round, 200)
	if entries == nil then
		return nil
	end
	local outcome: NationalsQueue.Outcome
	if #entries < minimumLifters() then
		outcome = { status = "cancelled", count = #entries }
	else
		local lifters: { [string]: string } = {}
		local names: { [string]: string } = {}
		for index = 1, math.min(#entries, NationalsConfig.MaxLifters) do
			local entry = entries[index]
			lifters[tostring(entry.userId)] = entry.classKey
			names[tostring(entry.userId)] = entry.name
		end
		local code, privateId = reserve(round)
		if code == nil or privateId == nil then
			outcome = { status = "failed", count = #entries }
		else
			q.registerServer(privateId, { round = round, lifters = lifters, names = names })
			outcome = { status = "go", count = #entries, lifters = lifters, accessCode = code, privateServerId = privateId }
		end
	end
	q.publish(round, outcome)
	log("Nationals %d: %s with %d signed up (this server ran the gathering, %s list)", round, outcome.status, outcome.count, q.kind)
	return outcome
end

-- (teleportOne and retryTeleport call each other.)
local retryTeleport: (player: Player, why: string) -> ()

local function teleportOne(player: Player)
	local info = pending[player]
	if info == nil or player.Parent == nil then
		return
	end
	local options = Instance.new("TeleportOptions")
	-- (The type definitions lag behind this property, so it is set untyped.)
	;(options :: any).ReservedServerAccessCode = info.code
	options:SetTeleportData({ nationalsRound = info.round })
	local ok, problem = pcall(function()
		RobloxTeleport:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		-- (A failure after the call is reported by TeleportInitFailed, which tries again too.)
		task.defer(retryTeleport, player, tostring(problem))
	end
end

-- A teleport to Nationals failed: try again, or put the lifter on the next list.
retryTeleport = function(player: Player, why: string)
	local info = pending[player]
	if info == nil or player.Parent == nil then
		return
	end
	info.tries += 1
	if info.tries > NationalsConfig.TeleportTries then
		pending[player] = nil
		going[player] = nil
		status[player] = nil
		warn(string.format("[NationalsService] %s couldn't be sent to Nationals: %s", player.Name, why))
		signUps[player] = { round = upcoming, classKey = info.classKey, signedAt = info.signedAt }
		carryOver({ player }, "Couldn't get you to Nationals (" .. why .. ").")
		return
	end
	task.delay(NationalsConfig.TeleportRetrySeconds, teleportOne, player)
end

-- The outcome is "go": this server's lifters on it go now.
local function send(goers: { Player }, round: number, outcome: NationalsQueue.Outcome)
	for _, player in ipairs(goers) do
		going[player] = true
		status[player] = "TAKING YOU TO NATIONALS"
		sendView(player)
		notify(player, "Nationals is starting! Taking you there now.")
		-- Out of any meet they're in (user 2026-11-17), saved while their data is still here.
		LocalMeetService.pullOutForNationals(player)
	end
	if IS_STUDIO then
		-- No other server to go to: this one becomes the stand-in.
		local h = here
		if h == nil then
			becomeNationals({ round = round, lifters = outcome.lifters or {}, names = {} })
		else
			-- A second one while the stand-in still runs: its lifters join the same one.
			for userId, classKey in pairs(outcome.lifters or {}) do
				if h.lifters[userId] == nil then
					h.lifters[userId] = classKey
					h.count += 1
				end
			end
		end
		for _, player in ipairs(goers) do
			local mine = signUps[player]
			signUps[player] = nil
			going[player] = nil
			status[player] = nil
			if mine then
				task.spawn(admit, player)
			end
		end
		return
	end
	local code = outcome.accessCode :: string
	for _, player in ipairs(goers) do
		local mine = signUps[player] :: SignUp
		signUps[player] = nil
		pending[player] = { tries = 1, code = code, round = round, classKey = mine.classKey, signedAt = mine.signedAt }
	end
	local options = Instance.new("TeleportOptions")
	;(options :: any).ReservedServerAccessCode = code
	options:SetTeleportData({ nationalsRound = round })
	local ok, problem = pcall(function()
		RobloxTeleport:TeleportAsync(game.PlaceId, goers, options)
	end)
	log("sending %d lifters to Nationals %d: %s", #goers, round, if ok then "teleport started" else tostring(problem))
	if not ok then
		for _, player in ipairs(goers) do
			retryTeleport(player, tostring(problem))
		end
	end
end

-- A Nationals' start in this server: the hand-shake, then this server's lifters go or carry over.
local function gather(round: number)
	local q = queue
	if q == nil then
		return
	end
	local mine: { Player } = {}
	for player, signUp in pairs(signUps) do
		if signUp.round == round and player.Parent then
			table.insert(mine, player)
		end
	end
	if #mine == 0 then
		return
	end
	for _, player in ipairs(mine) do
		status[player] = "GATHERING LIFTERS FROM EVERY SERVER…"
		sendView(player)
	end
	local outcome: NationalsQueue.Outcome? = nil
	local deadline = os.clock() + NationalsConfig.OutcomeWaitSeconds
	while os.clock() < deadline do
		outcome = q.outcome(round)
		if outcome then
			break
		end
		if q.claim(round) then
			outcome = lead(round)
			if outcome then
				break
			end
		end
		task.wait(2)
	end
	-- Only those still here and still on this round's list.
	local present: { Player } = {}
	for _, player in ipairs(mine) do
		local signUp = signUps[player]
		if player.Parent and signUp and signUp.round == round then
			table.insert(present, player)
		end
	end
	if outcome == nil then
		carryOver(present, "Nationals couldn't gather the lifters this time (the game's servers didn't answer).")
		return
	elseif outcome.status == "cancelled" then
		carryOver(present, string.format("Not enough lifters signed up across the game (%d of %d), so there's no Nationals this time.",
			outcome.count, minimumLifters()))
		return
	elseif outcome.status ~= "go" or outcome.lifters == nil or outcome.accessCode == nil then
		carryOver(present, "The Nationals server couldn't be opened this time.")
		return
	end
	local lifters = outcome.lifters :: { [string]: string }
	local goers: { Player } = {}
	local extra: { Player } = {}
	for _, player in ipairs(present) do
		table.insert(if lifters[tostring(player.UserId)] then goers else extra, player)
	end
	if #extra > 0 then
		carryOver(extra, "This Nationals was full.")
	end
	if #goers > 0 then
		send(goers, round, outcome)
	end
end

-- How many signed up across every server, re-read now and then while someone here could sign up.
local function refreshCount()
	local q = queue
	if q == nil or IS_RESERVED then
		return
	end
	local anyone = false
	for _, player in ipairs(Players:GetPlayers()) do
		if openTo(player) and (signUps[player] ~= nil or select(2, spotFor(player))) then
			anyone = true
			break
		end
	end
	if not anyone then
		return
	end
	local round = upcoming
	local count = q.count(round)
	if count ~= nil and (count ~= globalCount or countRound ~= round) then
		globalCount, countRound = count, round
		broadcast()
	end
end

-- ---------------------------------------------------------------- START NATIONALS NOW (the admin panel)

--[[
	The next Nationals moves up to `round` (an early start, sooner than the timetable's): this server's sign-ups move to it
	(off the old round's shared list, onto the new one) and its lifters are told. After it, the timetable carries on.
]]
local function applyForced(round: number)
	local q = queue
	if q == nil or IS_RESERVED or round <= now() or round >= upcoming then
		return
	end
	local old = upcoming
	upcoming = round
	-- (The notice below is the warning: the usual 30-second one would repeat it.)
	calledFor = round
	globalCount = nil
	log("Nationals moved up from %d to %d by the admin panel", old, round)
	for player, signUp in pairs(signUps) do
		if signUp.round == old then
			signUp.round = round
			task.spawn(function()
				q.remove(old, player.UserId)
				q.add(round, { userId = player.UserId, name = player.Name, classKey = signUp.classKey, signedAt = signUp.signedAt })
			end)
			notify(player, string.format("An admin started Nationals early: it starts in %d seconds! You'll be taken there "
				.. "from wherever you are, even out of a meet.", math.ceil(round - now())))
		end
	end
	nextCountAt = 0
	broadcast()
end

-- START NATIONALS NOW: whether it starts and what to tell the admin. SERVER-ONLY: AdminService checks the admin list first.
local function adminStartNow(): (boolean, string)
	local q = queue
	if q == nil then
		return false, "Nationals is still starting up in this server."
	end
	if IS_RESERVED then
		return false, "This is a Nationals server: start it from a normal server."
	end
	local round = math.ceil(now() + NationalsConfig.ForceLeadSeconds)
	if upcoming <= round then
		return false, string.format("The next Nationals starts in %s anyway.", clockText(upcoming - now()))
	end
	if not q.setForced(round) then
		return false, "Couldn't reach the Nationals list. Try again in a moment."
	end
	applyForced(round)
	return true, string.format("Nationals starts in %d seconds for everyone signed up, in every server.", NationalsConfig.ForceLeadSeconds)
end

-- Servers with someone signed up look now and then for an early start set in another server.
local polling = false
local function pollForced()
	local q = queue
	if q == nil or polling or IS_RESERVED or next(signUps) == nil then
		return
	end
	polling = true
	local round = q.forced()
	polling = false
	if round then
		applyForced(round)
	end
end

-- ---------------------------------------------------------------- starting

local function buildDesk()
	if not (IS_STUDIO or NationalsConfig.Live) or not waitForArena() then
		return
	end
	local lines = if IS_RESERVED then { "Welcome to", "Nationals" } else { "Spot holders sign up", everyText() }
	local point = StateArenaVenue.addNationalsDesk(NationalsConfig.DeskAt, NationalsConfig.EventTitle, lines)
	if point == nil then
		warn("[NationalsService] the Nationals desk could not be built (the MEETS list still signs up)")
		return
	end
	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = "Sign up / take name off"
	proximity.ObjectText = "Nationals desk"
	proximity.HoldDuration = NationalsConfig.PromptHoldSeconds
	proximity.MaxActivationDistance = NationalsConfig.PromptDistanceStuds
	proximity.KeyboardKeyCode = Enum.KeyCode.E
	proximity.GamepadKeyCode = Enum.KeyCode.ButtonX
	proximity.RequiresLineOfSight = false
	proximity.Parent = point
	proximity.Triggered:Connect(function(player)
		if pressAllowed(player) then
			toggleSignUp(player)
		end
	end)
end

function NationalsService.start()
	if started then
		return
	end
	started = true

	local set = NationalsRemotes.createOnServer(ReplicatedStorage)
	remotes = set
	upcoming = nextStartAfter(now())
	AdminService.setNationalsStarter(adminStartNow)

	set.signUp.OnServerEvent:Connect(function(player)
		if pressAllowed(player) then
			toggleSignUp(player)
		end
	end)
	set.leave.OnServerEvent:Connect(function(player)
		if pressAllowed(player) then
			leaveNationals(player)
		end
	end)
	set.request.OnServerEvent:Connect(function(player)
		local time = os.clock()
		if time - (lastRequest[player] or 0) >= REQUEST_GAP_SECONDS then
			lastRequest[player] = time
			sendView(player)
		end
	end)
	RobloxTeleport.TeleportInitFailed:Connect(function(player, result, message)
		if pending[player] then
			retryTeleport(player, string.format("%s: %s", tostring(result), tostring(message)))
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		if here and not IS_STUDIO then
			task.spawn(admit, player)
		end
		-- Their data loads meanwhile; the view says "loading" until then.
		task.delay(6, sendView, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local mine = signUps[player]
		local q = queue
		-- Someone teleporting to Nationals isn't taken off: their round is decided already.
		if mine and q and not going[player] and not pending[player] then
			task.spawn(q.remove, mine.round, player.UserId)
		end
		signUps[player] = nil
		going[player] = nil
		pending[player] = nil
		status[player] = nil
		busy[player] = nil
		lastPress[player] = nil
		lastRequest[player] = nil
		if atNationals[player] then
			atNationals[player] = nil
			if IS_STUDIO and next(atNationals) == nil and here then
				endStandIn()
			end
		end
	end)

	task.spawn(function()
		-- MemoryStore live; Studio uses the in-server list unless StudioNationalsMemoryStore is on (Studio keys).
		local useMemoryStore = not IS_STUDIO or Workspace:GetAttribute("StudioNationalsMemoryStore") == true
		local serverId = if IS_STUDIO then "studio-" .. HttpService:GenerateGUID(false) else game.JobId
		queue = NationalsQueue.new(useMemoryStore, if IS_STUDIO then NationalsConfig.StudioPrefix else "", serverId)
		log("ready: %s list, a Nationals every %d s (Live %s, Studio %s, Nationals server %s)", (queue :: NationalsQueue.Queue).kind,
			cycleSeconds(), tostring(NationalsConfig.Live), tostring(IS_STUDIO), tostring(IS_RESERVED))

		if IS_RESERVED then
			-- Which Nationals this server is for (written by the server that reserved it, just before the teleport).
			for _ = 1, NationalsConfig.ServerInfoTries do
				local info = (queue :: NationalsQueue.Queue).serverInfo(game.PrivateServerId)
				if info then
					becomeNationals(info)
					for _, player in ipairs(Players:GetPlayers()) do
						task.spawn(admit, player)
					end
					break
				end
				task.wait(3)
			end
			if here == nil then
				log("a reserved server that isn't a Nationals server")
			end
		end
		task.spawn(buildDesk)
		broadcast()

		while true do
			if not IS_RESERVED then
				local t = now()
				if calledFor ~= upcoming and t >= upcoming - NationalsConfig.CallSeconds then
					calledFor = upcoming
					for player, signUp in pairs(signUps) do
						if signUp.round == upcoming then
							notify(player, string.format("Nationals starts in %d seconds! You'll be taken there from wherever "
								.. "you are, even out of a meet.", NationalsConfig.CallSeconds))
						end
					end
				end
				if t >= upcoming then
					local round = upcoming
					upcoming = nextStartAfter(t)
					globalCount = nil
					nextCountAt = 0
					task.spawn(gather, round)
					broadcast()
				end
				if os.clock() >= nextCountAt then
					nextCountAt = os.clock() + NationalsConfig.CountRefreshSeconds
					task.spawn(refreshCount)
				end
				if os.clock() >= nextForcedPollAt then
					nextForcedPollAt = os.clock() + NationalsConfig.ForcePollSeconds
					task.spawn(pollForced)
				end
			end
			task.wait(0.5)
		end
	end)
end

return NationalsService
