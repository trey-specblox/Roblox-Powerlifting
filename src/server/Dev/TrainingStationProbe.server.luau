--!strict
--[[
	TrainingStationProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Exercises the universal training racks of checkpoint
	5B.6 -- TrainingStationRules, driven exactly the way TrainingStationService
	drives it -- on server start, and prints a pass/fail line per check to the
	Studio Output window.

	Set ENABLED to false to silence it, or delete this file. Nothing requires it,
	it creates no remotes, and it NEVER TOUCHES A REAL PLAYER'S PROFILE.

	WHY IT CANNOT TOUCH REAL DATA

	Players are plain strings, racks are plain ids, and every profile is a deep
	copy of the schema template held in a local variable. The clock is a number
	this file advances by hand. The "gateway" handed to the rules is
	ProfileOperations.applyTrainingProgression -- the pure core behind
	PlayerDataService.awardTrainingProgression -- called on that throwaway
	profile with a synthetic server time. No Player, no character, no
	ProfileStore and no DataStore is involved.

	WHAT ONLY STUDIO CAN TEST

	The real hold-E prompt, the real menu, the real distance to a real
	character, death and respawn events, and two real players. Those are the
	manual Studio steps. This probe tests every DECISION those events lead to,
	including how a menu request arriving over the remote is validated.

	=========================================================================
	OFF BY DEFAULT. SET TO true TO RUN IT.
	=========================================================================
]]

local ENABLED = false
if not ENABLED then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local DayKey = require(ProgressionFolder:WaitForChild("DayKey"))
local TrainingEfficiency = require(ProgressionFolder:WaitForChild("TrainingEfficiency"))

local TrainingFolder = Shared:WaitForChild("Training")
local TrainingStationRules = require(TrainingFolder:WaitForChild("TrainingStationRules"))

local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerProfileSchema = require(PlayerDataFolder:WaitForChild("PlayerProfileSchema"))
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))

local TRAINING = ProgressionConfig.DailyTraining
local TEMPLATE = PlayerProfileSchema.template

local passed = 0
local failed = 0

local function check(label: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(string.format("  PASS  %s", label))
	else
		failed += 1
		warn(string.format("  FAIL  %s%s", label, if detail then "  -- " .. detail else ""))
	end
end

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 0.000001)
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function newProfile(): PlayerProfileSchema.ProfileData
	return deepCopy(TEMPLATE)
end

-- A UTC midnight, the same one TrainingProgressionProbe uses.
local DAY_START = 1759968000
local HOUR = 3600

--[[
	The values the live config ships with. Repeated here, not read from
	TrainingStationConfig, so this probe tests the rules rather than the config.
]]
local TICK = 10
local MAX_CREDIT = 30
local COOLDOWN = 1
local RATE_LIMIT = 8
local RATE_WINDOW = 4

local CN_SQUAT: TrainingStationRules.Selection = { mode = "CN", lift = "Squat" }
local CN_BENCH: TrainingStationRules.Selection = { mode = "CN", lift = "Bench" }
local CN_DEADLIFT: TrainingStationRules.Selection = { mode = "CN", lift = "Deadlift" }
local TECH_SQUAT_DEPTH: TrainingStationRules.Selection = { mode = "Technique", lift = "Squat", primary = "DepthAwareness" }

--[[
	ONE SIMULATED PLAYER: a throwaway profile, a synthetic os.clock() and a
	synthetic server time that advance together, and the same two functions the
	service builds -- a CN reader and a gateway call -- pointed at them.
]]
type Sim = {
	data: PlayerProfileSchema.ProfileData,
	clock: number,
	unix: number,
	awardCalls: number,
	secondsAwarded: number,
	cnGainedReported: number,
	readCN: TrainingStationRules.CNReader,
	award: TrainingStationRules.AwardFunction,
}

local function newSim(startUnix: number): Sim
	local sim: Sim = {
		data = newProfile(),
		clock = 1000,
		unix = startUnix,
		awardCalls = 0,
		secondsAwarded = 0,
		cnGainedReported = 0,
		readCN = nil :: any,
		award = nil :: any,
	}

	sim.readCN = function()
		return TrainingStationRules.cnStatus(sim.data.cnAllowance, sim.unix)
	end

	sim.award = function(lift: string, elapsedSeconds: number)
		sim.awardCalls += 1
		sim.secondsAwarded += elapsedSeconds
		local result = ProfileOperations.applyTrainingProgression(sim.data, lift, sim.unix, elapsedSeconds)
		sim.cnGainedReported += result.deltaCN
		return result
	end

	return sim
end

local function advance(sim: Sim, seconds: number)
	sim.clock += seconds
	sim.unix += seconds
end

local function newRegistry(): TrainingStationRules.Registry
	local registry = TrainingStationRules.newRegistry()
	TrainingStationRules.registerStation(registry, "A")
	TrainingStationRules.registerStation(registry, "B")
	return registry
end

local function tick(registry: TrainingStationRules.Registry, playerKey: string, sim: Sim): TrainingStationRules.CreditReport
	return TrainingStationRules.creditSession(registry, playerKey, sim.clock, MAX_CREDIT, sim.readCN, sim.award)
end

local function choose(
	registry: TrainingStationRules.Registry,
	playerKey: string,
	selection: TrainingStationRules.Selection,
	sim: Sim
): TrainingStationRules.SelectReport
	return TrainingStationRules.selectTraining(
		registry, playerKey, selection, sim.clock, COOLDOWN, MAX_CREDIT, sim.readCN, sim.award)
end

-- Opens the menu at a rack as a player standing on it, then starts `selection`.
local function occupyAndStart(
	registry: TrainingStationRules.Registry,
	playerKey: string,
	stationId: string,
	selection: TrainingStationRules.Selection,
	sim: Sim
): TrainingStationRules.SelectReport
	TrainingStationRules.openMenu(registry, playerKey, stationId, nil, sim.clock)
	return choose(registry, playerKey, selection, sim)
end

local function sessionOf(registry: TrainingStationRules.Registry, playerKey: string): any
	return TrainingStationRules.sessionOf(registry, playerKey)
end

-- Ticks until the cap stops the session. Returns the stopping report and the tick count.
local function trainToCap(
	registry: TrainingStationRules.Registry,
	playerKey: string,
	sim: Sim
): (TrainingStationRules.CreditReport?, number)
	local ticks = 0
	while ticks < 5000 do
		advance(sim, TICK)
		ticks += 1
		local report = tick(registry, playerKey, sim)
		if report.stoppedAtCap then
			return report, ticks
		end
	end
	return nil, ticks
end

-- The central invariant of TrainingAllowance: every EV debited advanced some lift's clock.
local function invariantHolds(data: PlayerProfileSchema.ProfileData): boolean
	local hours = data.trainingTimeToday
	local implied = TrainingEfficiency.cumulativeEV(hours.Squat)
		+ TrainingEfficiency.cumulativeEV(hours.Bench)
		+ TrainingEfficiency.cumulativeEV(hours.Deadlift)
	return near(data.cnAllowance.spentToday, implied, 1e-9)
end

local function techniqueUnchanged(data: PlayerProfileSchema.ProfileData): boolean
	for stat, value in pairs(TEMPLATE.technique :: any) do
		if (data.technique :: any)[stat] ~= value then
			return false
		end
	end
	return data.techniqueAllowance.spentToday == 0
end

print("=== TrainingStationProbe ===")

--------------------------------------------------------------------------------
print("-- 1. the menu is authorized only near an available rack")
--------------------------------------------------------------------------------

do
	local function facts(overrides: { [string]: any }): TrainingStationRules.PresenceFacts
		local base: { [string]: any } = {
			inGame = true,
			dataReady = true,
			hasCharacter = true,
			alive = true,
			distance = 3,
			radius = 12,
		}
		for key, value in pairs(overrides) do
			base[key] = value
		end
		return base :: any
	end

	check("standing on the platform is present", TrainingStationRules.presenceFailure(facts({})) == nil)
	check("exactly at the 12 stud radius is present",
		TrainingStationRules.presenceFailure(facts({ distance = 12 })) == nil)
	check("12.01 studs is OutOfRange",
		TrainingStationRules.presenceFailure(facts({ distance = 12.01 })) == "OutOfRange")
	check("an unknown distance is OutOfRange",
		TrainingStationRules.presenceFailure(facts({ distance = false })) == "OutOfRange")
	check("a NaN distance is OutOfRange",
		TrainingStationRules.presenceFailure(facts({ distance = 0 / 0 })) == "OutOfRange")
	check("unloaded data is DataNotReady",
		TrainingStationRules.presenceFailure(facts({ dataReady = false })) == "DataNotReady")

	local registry = newRegistry()

	local refusal, outcome = TrainingStationRules.openMenu(registry, "Alice", "A", "OutOfRange", 0)
	check("too far away: the menu is refused", refusal == "NotPresent" and outcome == nil)
	refusal = TrainingStationRules.openMenu(registry, "Alice", "A", "Dead", 0)
	check("dead: the menu is refused", refusal == "NotPresent")
	check("a refused menu reserves nothing",
		sessionOf(registry, "Alice") == nil and TrainingStationRules.occupantOf(registry, "A") == nil)

	refusal, outcome = TrainingStationRules.openMenu(registry, "Alice", "A", nil, 0)
	check("present at a free rack: the rack is reserved", refusal == nil and outcome == "Reserved")
	check("the reservation is Selecting with the menu open, nothing selected",
		sessionOf(registry, "Alice").state == "Selecting" and sessionOf(registry, "Alice").menuOpen
			and sessionOf(registry, "Alice").selection == nil)

	refusal, outcome = TrainingStationRules.openMenu(registry, "Alice", "A", nil, 5)
	check("holding E at your own rack reopens the menu", refusal == nil and outcome == "Reopened")

	local heavy = newSim(DAY_START + 10 * HOUR)
	heavy.data.bodyweight.currentKg = 130
	local rejected = heavy.award("Squat", 0)
	check("the zero-second check refuses a 120+ lifter (Rejected is fatal)",
		rejected.outcome == "Rejected" and TrainingStationRules.isFatalResult(rejected))
	check("no active data session is fatal", TrainingStationRules.isFatalResult(nil))

	local normal = newSim(DAY_START + 10 * HOUR)
	local zero = normal.award("Squat", 0)
	check("a normal lifter's zero-second check is NoProgress and earns nothing",
		zero.outcome == "NoProgress" and not TrainingStationRules.isFatalResult(zero)
			and normal.data.competitionNumber.Squat == TEMPLATE.competitionNumber.Squat)
	check("ClockWentBackward is not fatal",
		not TrainingStationRules.isFatalResult({ outcome = "ClockWentBackward" }))
end

--------------------------------------------------------------------------------
print("-- 2. one player per rack")
--------------------------------------------------------------------------------

do
	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "Alice", "A", CN_SQUAT, sim)

	local refusal = TrainingStationRules.openMenu(registry, "Bob", "A", nil, sim.clock)
	check("Bob is refused at Alice's rack", refusal == "StationOccupied")
	check("Bob gets no session and no menu", sessionOf(registry, "Bob") == nil)
	check("Bob cannot start training without an authorized menu",
		choose(registry, "Bob", CN_BENCH, sim).decision == "NotAuthorized")
	check("rack A still belongs to Alice, training Squat",
		TrainingStationRules.occupantOf(registry, "A") == "Alice" and sessionOf(registry, "Alice").selection.lift == "Squat")
	check("Bob may take the free rack B",
		TrainingStationRules.openMenu(registry, "Bob", "B", nil, sim.clock) == nil)
end

--------------------------------------------------------------------------------
print("-- 3. one rack per player")
--------------------------------------------------------------------------------

do
	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "Alice", "A", CN_SQUAT, sim)

	check("Alice is refused at a second rack",
		TrainingStationRules.openMenu(registry, "Alice", "B", nil, sim.clock) == "AtAnotherStation")
	check("rack B stays free", TrainingStationRules.occupantOf(registry, "B") == nil)
	check("Alice is still on A", sessionOf(registry, "Alice").stationId == "A")

	TrainingStationRules.stopTraining(registry, "Alice", sim.clock, true, MAX_CREDIT, sim.readCN, sim.award)
	check("after stopping, Alice may use rack B",
		TrainingStationRules.openMenu(registry, "Alice", "B", nil, sim.clock) == nil
			and TrainingStationRules.occupantOf(registry, "A") == nil)
end

--------------------------------------------------------------------------------
print("-- 4. invalid and spoofed rack ids")
--------------------------------------------------------------------------------

do
	local registry = newRegistry()

	check("an unregistered id is UnknownStation",
		TrainingStationRules.openMenu(registry, "P", "PlaceholderStationZ", nil, 0) == "UnknownStation")
	check("an empty id is InvalidStation", TrainingStationRules.openMenu(registry, "P", "", nil, 0) == "InvalidStation")
	check("a number is InvalidStation", TrainingStationRules.openMenu(registry, "P", 42, nil, 0) == "InvalidStation")
	check("nil is InvalidStation", TrainingStationRules.openMenu(registry, "P", nil, nil, 0) == "InvalidStation")
	check("a table is InvalidStation", TrainingStationRules.openMenu(registry, "P", { "A" }, nil, 0) == "InvalidStation")
	check("none of them created a session", sessionOf(registry, "P") == nil)

	check("registering a duplicate id is refused", not TrainingStationRules.registerStation(registry, "A"))
	check("registering an empty id is refused", not TrainingStationRules.registerStation(registry, ""))

	TrainingStationRules.unregisterStation(registry, "B")
	check("a removed rack can no longer be opened",
		TrainingStationRules.openMenu(registry, "P", "B", nil, 0) == "UnknownStation")

	local request, refusal = TrainingStationRules.parseRequest("Start", { mode = "CN", lift = "Squat", stationId = "A" }, 2)
	check("a Start request naming a station id is refused", request == nil and refusal == "UnexpectedField")
end

--------------------------------------------------------------------------------
print("-- 5. invalid mode, lift or primary stat")
--------------------------------------------------------------------------------

do
	local function refusalOf(payload: any): string?
		local _, refusal = TrainingStationRules.validateSelection(payload)
		return refusal
	end

	check("mode Strength is InvalidMode", refusalOf({ mode = "Strength", lift = "Squat" }) == "InvalidMode")
	check("a missing mode is InvalidMode", refusalOf({ lift = "Squat" }) == "InvalidMode")
	check("lift Curl is InvalidLift", refusalOf({ mode = "CN", lift = "Curl" }) == "InvalidLift")
	check("lower-case squat is InvalidLift", refusalOf({ mode = "CN", lift = "squat" }) == "InvalidLift")
	check("CN with a primary stat is InvalidPrimary",
		refusalOf({ mode = "CN", lift = "Squat", primary = "DepthAwareness" }) == "InvalidPrimary")
	check("Technique with no primary is InvalidPrimary",
		refusalOf({ mode = "Technique", lift = "Squat" }) == "InvalidPrimary")
	check("a Bench stat on the Squat is InvalidPrimary",
		refusalOf({ mode = "Technique", lift = "Squat", primary = "PressPower" }) == "InvalidPrimary")
	check("PullStrength is never trainable",
		refusalOf({ mode = "Technique", lift = "Deadlift", primary = "PullStrength" }) == "InvalidPrimary")
	check("a made-up stat is InvalidPrimary",
		refusalOf({ mode = "Technique", lift = "Bench", primary = "Grip" }) == "InvalidPrimary")
	check("a string payload is MalformedRequest", refusalOf("CN Squat") == "MalformedRequest")
	check("an array payload is UnexpectedField", refusalOf({ "CN", "Squat" }) == "UnexpectedField")

	local valid = { { mode = "CN", lift = "Bench" }, { mode = "Technique", lift = "Squat", primary = "SquatControl" },
		{ mode = "Technique", lift = "Bench", primary = "StartControl" }, { mode = "Technique", lift = "Deadlift", primary = "Lockout" } }
	local allValid = true
	for _, payload in ipairs(valid) do
		if refusalOf(payload) ~= nil then
			allValid = false
		end
	end
	check("CN Bench, Squat Control, Start Control and Lockout are all accepted", allValid)

	local function shares(lift: string, primary: string): string
		local split = TrainingStationRules.techniqueSplit(lift, primary)
		if split == nil then
			return "nil"
		end
		local parts = {}
		for _, entry in ipairs(split) do
			table.insert(parts, string.format("%s=%.2f", entry.stat, entry.share))
		end
		return table.concat(parts, ",")
	end

	check("Squat primary Squat Control is 80/20 with Depth Awareness",
		shares("Squat", "SquatControl") == "SquatControl=0.80,DepthAwareness=0.20", shares("Squat", "SquatControl"))
	check("Squat primary Depth Awareness is 80/20 with Squat Control",
		shares("Squat", "DepthAwareness") == "DepthAwareness=0.80,SquatControl=0.20")
	check("Bench primary Start Control is 80/20 with Press Power",
		shares("Bench", "StartControl") == "StartControl=0.80,PressPower=0.20")
	check("Bench primary Press Power is 80/20 with Start Control",
		shares("Bench", "PressPower") == "PressPower=0.80,StartControl=0.20")
	check("Deadlift Lockout is 100%", shares("Deadlift", "Lockout") == "Lockout=1.00")
	check("Deadlift PullStrength has no split", shares("Deadlift", "PullStrength") == "nil")

	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()
	TrainingStationRules.openMenu(registry, "P", "A", nil, sim.clock)
	local bad = choose(registry, "P", { mode = "CN", lift = "Curl" } :: any, sim)
	check("selectTraining re-validates and refuses an invalid selection",
		bad.decision == "Invalid" and sessionOf(registry, "P").state == "Selecting" and sim.awardCalls == 0)
end

--------------------------------------------------------------------------------
print("-- 6. manual Squat / Bench / Deadlift switching")
--------------------------------------------------------------------------------

do
	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()
	local first = occupyAndStart(registry, "P", "A", CN_SQUAT, sim)
	check("starting CN Squat is Started", first.decision == "Started")

	for _ = 1, 60 do
		advance(sim, TICK)
		tick(registry, "P", sim)
	end

	check("10 minutes of Squat banks 600 s on Squat", near(sim.data.trainingTimeToday.Squat, 600 / HOUR, 1e-12))
	check("and nothing on Bench or Deadlift",
		sim.data.trainingTimeToday.Bench == 0 and sim.data.trainingTimeToday.Deadlift == 0)
	check("the rack never changed the lift on its own", sessionOf(registry, "P").selection.lift == "Squat")

	advance(sim, 4)
	local switch = choose(registry, "P", CN_BENCH, sim)
	check("switching to Bench is Started, previous Squat",
		switch.decision == "Started" and (switch.previous :: any).lift == "Squat")
	check("the 4 s before the switch went to the OLD lift",
		switch.credit ~= nil and (switch.credit :: any).lift == "Squat" and (switch.credit :: any).creditedSeconds == 4)
	check("Squat now holds 604 s", near(sim.data.trainingTimeToday.Squat, 604 / HOUR, 1e-12))

	advance(sim, TICK)
	tick(registry, "P", sim)
	check("the next tick goes to Bench", near(sim.data.trainingTimeToday.Bench, 10 / HOUR, 1e-12))
	check("and leaves Squat alone", near(sim.data.trainingTimeToday.Squat, 604 / HOUR, 1e-12))

	advance(sim, 2)
	choose(registry, "P", CN_DEADLIFT, sim)
	advance(sim, TICK)
	tick(registry, "P", sim)
	check("Deadlift can be selected and earns", near(sim.data.trainingTimeToday.Deadlift, 10 / HOUR, 1e-12))
	check("Bench kept its 12 s", near(sim.data.trainingTimeToday.Bench, 12 / HOUR, 1e-12))

	advance(sim, 2)
	choose(registry, "P", CN_SQUAT, sim)
	advance(sim, TICK)
	tick(registry, "P", sim)
	check("back on Squat, its hours resume from 604 s, NOT reset",
		near(sim.data.trainingTimeToday.Squat, 614 / HOUR, 1e-12))
	check("all three lifts earned CN",
		sim.data.competitionNumber.Squat > TEMPLATE.competitionNumber.Squat
			and sim.data.competitionNumber.Bench > TEMPLATE.competitionNumber.Bench
			and sim.data.competitionNumber.Deadlift > TEMPLATE.competitionNumber.Deadlift)
	check("the EV/hours invariant holds after switching", invariantHolds(sim.data))
end

--------------------------------------------------------------------------------
print("-- 7. no double credit across switches")
--------------------------------------------------------------------------------

do
	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "P", "A", CN_SQUAT, sim)

	advance(sim, TICK)
	tick(registry, "P", sim)

	local callsBefore = sim.awardCalls
	local same = choose(registry, "P", { mode = "CN", lift = "Squat" }, sim)
	check("re-confirming the running selection is Unchanged", same.decision == "Unchanged")
	check("and calls nothing", sim.awardCalls == callsBefore)

	advance(sim, 3)
	choose(registry, "P", CN_BENCH, sim)
	advance(sim, 0.5)
	callsBefore = sim.awardCalls
	local early = choose(registry, "P", CN_SQUAT, sim)
	check("a switch 0.5 s after the last is refused by the cooldown", early.decision == "Cooldown")
	check("and credits nothing and keeps Bench",
		sim.awardCalls == callsBefore and sessionOf(registry, "P").selection.lift == "Bench")

	advance(sim, 1)
	local later = choose(registry, "P", CN_SQUAT, sim)
	check("once the cooldown passes the switch is allowed", later.decision == "Started")
	check("Bench got exactly the 1.5 s it ran, including the refused moment",
		near(sim.data.trainingTimeToday.Bench, 1.5 / HOUR, 1e-12))

	-- A tick at the very instant of the switch measures nothing.
	local sameInstant = tick(registry, "P", sim)
	check("a tick at the instant of a switch measures 0 s and awards nothing",
		sameInstant.measuredSeconds == 0 and sameInstant.status == "NothingToCredit")

	local measuredTotal = 10 + 3 + 1.5
	check("every second was credited exactly once (14.5 s in total)",
		near(sim.secondsAwarded, measuredTotal, 1e-9), tostring(sim.secondsAwarded))
	local cnTotal = (sim.data.competitionNumber.Squat - TEMPLATE.competitionNumber.Squat)
		+ (sim.data.competitionNumber.Bench - TEMPLATE.competitionNumber.Bench)
	check("CN gained equals the sum of reported awards, nothing extra", near(cnTotal, sim.cnGainedReported, 1e-9))
	check("the EV/hours invariant holds", invariantHolds(sim.data))
end

--------------------------------------------------------------------------------
print("-- 8. CN STOPS at 4.00 daily EV")
--------------------------------------------------------------------------------

do
	local sim = newSim(DAY_START + 1 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "P", "A", CN_SQUAT, sim)

	local capTick, ticks = trainToCap(registry, "P", sim)
	local expectedHours = TrainingEfficiency.hoursToReach(TRAINING.DailyCapEV)

	check("the cap is reached in one Squat session", capTick ~= nil)
	check(string.format("after %d ticks, about %.4f h", ticks, expectedHours),
		near(ticks * TICK / HOUR, expectedHours, TICK / HOUR))
	check("spent today is exactly 4.00 EV", near(sim.data.cnAllowance.spentToday, TRAINING.DailyCapEV, 1e-9),
		tostring(sim.data.cnAllowance.spentToday))
	check("the capping tick reported the gateway's capReached",
		capTick ~= nil and (capTick :: any).result.capReached == true)
	check("the session is now StoppedAtCNCap", sessionOf(registry, "P").state == "StoppedAtCNCap")
	check("the rack is still occupied by the player", TrainingStationRules.occupantOf(registry, "A") == "P")
	check("the status reads the exact cap message",
		TrainingStationRules.statusLine(sessionOf(registry, "P")) == TrainingStationRules.CAP_REACHED_MESSAGE,
		TrainingStationRules.statusLine(sessionOf(registry, "P")))
	check("the cap message says Daily CN Limit Reached and Training Stopped",
		string.find(TrainingStationRules.CAP_REACHED_MESSAGE, "Daily CN Limit Reached", 1, true) ~= nil
			and string.find(TrainingStationRules.CAP_REACHED_MESSAGE, "Training Stopped", 1, true) ~= nil)
	check("the hint tells the player to choose Technique manually",
		string.find(TrainingStationRules.CAP_REACHED_HINT, "Technique", 1, true) ~= nil)
	check("the EV/hours invariant holds at the cap", invariantHolds(sim.data))

	local cnAtCap = sim.data.competitionNumber.Squat
	local hoursAtCap = sim.data.trainingTimeToday.Squat
	local callsAtCap = sim.awardCalls
	local last: TrainingStationRules.CreditReport? = nil

	for _ = 1, 30 do
		advance(sim, TICK)
		last = tick(registry, "P", sim)
	end

	check("ticks after the stop are NotTraining", last ~= nil and (last :: any).status == "NotTraining")
	check("and never call the gateway", sim.awardCalls == callsAtCap)
	check("no CN after the cap", sim.data.competitionNumber.Squat == cnAtCap)
	check("no hours after the cap", sim.data.trainingTimeToday.Squat == hoursAtCap)

	advance(sim, 2)
	local bench = choose(registry, "P", CN_BENCH, sim)
	check("asking for CN Bench at the cap is refused CNCapReached", bench.decision == "CNCapReached")
	check("which does not reopen the allowance",
		sim.awardCalls == callsAtCap and sim.data.cnAllowance.spentToday == TRAINING.DailyCapEV)
	check("and leaves the stopped Squat selection exactly as it was",
		sessionOf(registry, "P").state == "StoppedAtCNCap" and sessionOf(registry, "P").selection.lift == "Squat"
			and sessionOf(registry, "P").selection.mode == "CN")

	local lateSim = newSim(DAY_START + 20 * HOUR)
	lateSim.data.cnAllowance.spentToday = TRAINING.DailyCapEV
	lateSim.data.cnAllowance.dayKey = DayKey.fromUnix(lateSim.unix)
	local lateRegistry = newRegistry()
	local late = occupyAndStart(lateRegistry, "Q", "B", CN_DEADLIFT, lateSim)
	check("a player already capped today cannot START CN",
		late.decision == "CNCapReached" and sessionOf(lateRegistry, "Q").state == "Selecting" and lateSim.awardCalls == 0)
end

--------------------------------------------------------------------------------
print("-- 9. no automatic technique training for free players")
--------------------------------------------------------------------------------

do
	local sim = newSim(DAY_START + 1 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "P", "A", CN_BENCH, sim)
	trainToCap(registry, "P", sim)

	-- A full hour standing at the rack after the cap.
	local statuses: { [string]: boolean } = {}
	for _ = 1, 360 do
		advance(sim, TICK)
		statuses[tick(registry, "P", sim).status] = true
	end

	check("the mode is still CN, never switched to Technique", sessionOf(registry, "P").selection.mode == "CN")
	check("the lift is still Bench, never rotated", sessionOf(registry, "P").selection.lift == "Bench")
	check("no primary stat was chosen for the player", sessionOf(registry, "P").selection.primary == nil)
	check("no tick ever reported technique activity",
		statuses.TechniquePending == nil and statuses.Credited == nil)
	check("no technique stat moved and no technique allowance was spent", techniqueUnchanged(sim.data))
	check("Squat and Deadlift were never touched",
		sim.data.trainingTimeToday.Squat == 0 and sim.data.trainingTimeToday.Deadlift == 0)
end

--------------------------------------------------------------------------------
print("-- 10. technique is selectable but visibly earns nothing until 5B.7")
--------------------------------------------------------------------------------

do
	local sim = newSim(DAY_START + 1 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "P", "A", CN_SQUAT, sim)
	trainToCap(registry, "P", sim)

	advance(sim, 2)
	local technique = choose(registry, "P", TECH_SQUAT_DEPTH, sim)
	check("after the cap the player can MANUALLY select Technique", technique.decision == "Started")
	check("the session runs Technique, Squat, primary Depth Awareness",
		sessionOf(registry, "P").state == "Training" and sessionOf(registry, "P").selection.mode == "Technique"
			and sessionOf(registry, "P").selection.primary == "DepthAwareness")
	check("the status says rewards come in Step 5B.7",
		TrainingStationRules.statusLine(sessionOf(registry, "P")) == TrainingStationRules.TECHNIQUE_PENDING_MESSAGE
			and string.find(TrainingStationRules.TECHNIQUE_PENDING_MESSAGE, "5B.7", 1, true) ~= nil)

	local callsBefore = sim.awardCalls
	local cnBefore = sim.data.competitionNumber.Squat
	local report: TrainingStationRules.CreditReport? = nil
	for _ = 1, 60 do
		advance(sim, TICK)
		report = tick(registry, "P", sim)
	end

	check("technique ticks report TechniquePending", report ~= nil and (report :: any).status == "TechniquePending")
	check("and discard their time", report ~= nil and (report :: any).creditedSeconds == 0
		and (report :: any).discardedSeconds == TICK)
	check("no gateway call, no CN", sim.awardCalls == callsBefore and sim.data.competitionNumber.Squat == cnBefore)
	check("no technique points and no technique allowance in 5B.6", techniqueUnchanged(sim.data))

	local fresh = newSim(DAY_START + 10 * HOUR)
	local freshRegistry = newRegistry()
	local early = occupyAndStart(freshRegistry, "Q", "B", { mode = "Technique", lift = "Deadlift", primary = "Lockout" }, fresh)
	advance(fresh, TICK)
	tick(freshRegistry, "Q", fresh)
	check("Technique selected BEFORE the cap also earns nothing in 5B.6 (no CN either)",
		early.decision == "Started" and fresh.awardCalls == 0 and fresh.data.cnAllowance.spentToday == 0
			and techniqueUnchanged(fresh.data))
end

--------------------------------------------------------------------------------
print("-- 11. the UTC reset never overrides a manual selection")
--------------------------------------------------------------------------------

do
	local midnight = DAY_START + 24 * HOUR

	-- (a) Technique selected manually after the cap, held across midnight.
	local sim = newSim(DAY_START + 12 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "P", "A", CN_DEADLIFT, sim)
	trainToCap(registry, "P", sim)
	advance(sim, 2)
	choose(registry, "P", TECH_SQUAT_DEPTH, sim)

	local callsBefore = sim.awardCalls
	while sim.unix <= midnight + 60 do
		advance(sim, TICK)
		tick(registry, "P", sim)
	end

	check("after midnight CN is available again", sim.readCN() == "Available")
	check("but the manual Technique selection is untouched",
		sessionOf(registry, "P").selection.mode == "Technique" and sessionOf(registry, "P").selection.lift == "Squat"
			and sessionOf(registry, "P").selection.primary == "DepthAwareness")
	check("and no CN was earned behind the player's back", sim.awardCalls == callsBefore)

	-- (b) Stopped at the cap, held across midnight: stays stopped until the player acts.
	local stopped = newSim(DAY_START + 12 * HOUR)
	local stoppedRegistry = newRegistry()
	occupyAndStart(stoppedRegistry, "Q", "B", CN_BENCH, stopped)
	trainToCap(stoppedRegistry, "Q", stopped)
	local stoppedCalls = stopped.awardCalls

	while stopped.unix <= midnight + 60 do
		advance(stopped, TICK)
		tick(stoppedRegistry, "Q", stopped)
	end

	check("a session stopped at the cap stays stopped after midnight",
		sessionOf(stoppedRegistry, "Q").state == "StoppedAtCNCap" and stopped.awardCalls == stoppedCalls)
	local restart = choose(stoppedRegistry, "Q", CN_BENCH, stopped)
	check("the player can manually Start CN Bench on the new day", restart.decision == "Started")
	advance(stopped, TICK)
	tick(stoppedRegistry, "Q", stopped)
	check("it earns on the new day from zero",
		stopped.data.cnAllowance.dayKey == DayKey.fromUnix(stopped.unix)
			and near(stopped.data.trainingTimeToday.Bench, 10 / HOUR, 1e-12))
	check("time spent stopped was never paid", near(stopped.secondsAwarded, TrainingEfficiency.hoursToReach(
		TRAINING.DailyCapEV) * HOUR + 10, 2 * TICK), tostring(stopped.secondsAwarded))

	-- (c) CN training under the cap straight through midnight.
	local through = newSim(midnight - 25)
	local throughRegistry = newRegistry()
	occupyAndStart(throughRegistry, "R", "A", CN_SQUAT, through)
	for _ = 1, 5 do
		advance(through, TICK)
		tick(throughRegistry, "R", through)
	end
	check("uncapped CN carries on through midnight on the same lift",
		sessionOf(throughRegistry, "R").selection.lift == "Squat" and sessionOf(throughRegistry, "R").state == "Training")
	check("the day key moved to the new day", through.data.cnAllowance.dayKey == DayKey.fromUnix(midnight))
	check("only post-midnight time is on the new day's Squat clock",
		through.data.trainingTimeToday.Squat <= 25 / HOUR + 1e-12, tostring(through.data.trainingTimeToday.Squat * HOUR))
	check("the EV/hours invariant holds on the new day", invariantHolds(through.data))
end

--------------------------------------------------------------------------------
print("-- 12. disconnect, death, respawn and leaving range")
--------------------------------------------------------------------------------

do
	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "P", "A", CN_SQUAT, sim)

	advance(sim, TICK)
	tick(registry, "P", sim)

	-- The character dies 7 s into the next tick. The service releases with no credit.
	advance(sim, 7)
	local hoursBefore = sim.data.trainingTimeToday.Squat
	local callsBefore = sim.awardCalls

	check("death releases the rack", TrainingStationRules.release(registry, "P") == "A"
		and TrainingStationRules.occupantOf(registry, "A") == nil)
	check("the 7 s since the last tick were NOT credited",
		sim.data.trainingTimeToday.Squat == hoursBefore and sim.awardCalls == callsBefore)

	advance(sim, TICK)
	check("a tick after release finds no session", tick(registry, "P", sim).status == "NoSession")
	check("and credits nothing", sim.awardCalls == callsBefore)

	advance(sim, 60)
	local refusal, outcome = TrainingStationRules.openMenu(registry, "P", "A", nil, sim.clock)
	check("the respawned player can reserve again", refusal == nil and outcome == "Reserved")
	check("the old selection is forgotten: back to Selecting", sessionOf(registry, "P").selection == nil)
	choose(registry, "P", CN_SQUAT, sim)
	advance(sim, TICK)
	local fresh = tick(registry, "P", sim)
	check("the first tick after returning credits only 10 s, not the absent time",
		fresh.creditedSeconds == 10 and near(sim.data.trainingTimeToday.Squat, 20 / HOUR, 1e-12))

	advance(sim, 6)
	callsBefore = sim.awardCalls
	local stationId, credit = TrainingStationRules.stopTraining(registry, "P", sim.clock, false, MAX_CREDIT,
		sim.readCN, sim.award)
	check("leaving range (not present) frees the rack with no credit",
		stationId == "A" and credit == nil and sim.awardCalls == callsBefore)

	check("a disconnected player is LeftGame", TrainingStationRules.presenceFailure({
		inGame = false, dataReady = false, hasCharacter = false, alive = false, distance = nil, radius = 12,
	}) == "LeftGame")
	check("a respawning player with no character is NoCharacter", TrainingStationRules.presenceFailure({
		inGame = true, dataReady = true, hasCharacter = false, alive = false, distance = nil, radius = 12,
	}) == "NoCharacter")
	check("a dead character is Dead", TrainingStationRules.presenceFailure({
		inGame = true, dataReady = true, hasCharacter = true, alive = false, distance = 2, radius = 12,
	}) == "Dead")
	check("releasing someone with no rack is a no-op", TrainingStationRules.release(registry, "Nobody") == nil)
end

--------------------------------------------------------------------------------
print("-- 13. duplicate and overlapping server ticks")
--------------------------------------------------------------------------------

do
	local credited, discarded = TrainingStationRules.clampElapsed(10, MAX_CREDIT)
	check("a normal 10 s tick is credited in full", credited == 10 and discarded == 0)
	credited, discarded = TrainingStationRules.clampElapsed(-5, MAX_CREDIT)
	check("negative credits nothing", credited == 0 and discarded == 0)
	credited, discarded = TrainingStationRules.clampElapsed(0 / 0, MAX_CREDIT)
	check("NaN credits nothing", credited == 0 and discarded == 0)
	credited, discarded = TrainingStationRules.clampElapsed(math.huge, MAX_CREDIT)
	check("infinity credits nothing", credited == 0 and discarded == 0)
	credited, discarded = TrainingStationRules.clampElapsed(100, MAX_CREDIT)
	check("a 100 s lag spike credits 30 and discards 70", credited == 30 and discarded == 70)

	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "P", "A", CN_DEADLIFT, sim)

	advance(sim, TICK)
	local first = tick(registry, "P", sim)
	local callsAfterFirst = sim.awardCalls
	local second = tick(registry, "P", sim)
	check("the first tick credits 10 s", first.status == "Credited" and first.creditedSeconds == 10)
	check("an overlapping tick at the same moment measures 0 s", second.measuredSeconds == 0)
	check("and does not call the gateway", sim.awardCalls == callsAfterFirst)

	-- os.clock() can never run backward, but if a caller passed an older time it must not pay.
	local backward = TrainingStationRules.creditSession(registry, "P", sim.clock - 50, MAX_CREDIT, sim.readCN, sim.award)
	check("a tick with an earlier clock credits nothing", backward.creditedSeconds == 0
		and sim.awardCalls == callsAfterFirst)
	advance(sim, TICK)
	local afterBackward = tick(registry, "P", sim)
	check("and does not rewind the clock: the next tick pays only its own 10 s",
		afterBackward.creditedSeconds == TICK, tostring(afterBackward.creditedSeconds))

	advance(sim, 100)
	local lagged = tick(registry, "P", sim)
	check("a 100 s server stall credits only 30 s", lagged.creditedSeconds == 30 and lagged.discardedSeconds == 70)
	check("the EV/hours invariant holds", invariantHolds(sim.data))
end

--------------------------------------------------------------------------------
print("-- 14. remote spam and unauthorized requests")
--------------------------------------------------------------------------------

do
	local limiter = TrainingStationRules.newRateLimiter()
	local allowedCount = 0
	for _ = 1, 50 do
		if TrainingStationRules.allowRequest(limiter, "Spammer", 100, RATE_LIMIT, RATE_WINDOW) then
			allowedCount += 1
		end
	end
	check("50 requests in one instant: only 8 are allowed", allowedCount == RATE_LIMIT, tostring(allowedCount))
	check("still refused 3.9 s later",
		not TrainingStationRules.allowRequest(limiter, "Spammer", 103.9, RATE_LIMIT, RATE_WINDOW))
	check("allowed again once the window clears",
		TrainingStationRules.allowRequest(limiter, "Spammer", 104.1, RATE_LIMIT, RATE_WINDOW))
	check("another player is not affected",
		TrainingStationRules.allowRequest(limiter, "Polite", 100, RATE_LIMIT, RATE_WINDOW))
	TrainingStationRules.forgetRequester(limiter, "Spammer")
	check("a player who left is forgotten", limiter["Spammer"] == nil)

	local _, unknown = TrainingStationRules.parseRequest("GiveCN", nil, 1)
	check("an unknown action is refused", unknown == "UnknownAction")
	local _, notString = TrainingStationRules.parseRequest(42, nil, 1)
	check("a non-string action is refused", notString == "UnknownAction")
	local _, stopPayload = TrainingStationRules.parseRequest("Stop", { lift = "Squat" }, 2)
	check("Stop with a payload is refused", stopPayload == "UnexpectedField")
	local _, extraArgs = TrainingStationRules.parseRequest("Start", { mode = "CN", lift = "Squat" }, 3)
	check("Start with an extra argument is refused", extraArgs == "MalformedRequest")
	local okClose = TrainingStationRules.parseRequest("Close", nil, 1)
	check("a plain Close is accepted", okClose ~= nil and (okClose :: any).action == "Close")

	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()
	check("Start with no rack is NotAuthorized", choose(registry, "Nobody", CN_SQUAT, sim).decision == "NotAuthorized")

	occupyAndStart(registry, "P", "A", CN_SQUAT, sim)
	TrainingStationRules.closeMenu(registry, "P")
	advance(sim, 5)
	local callsBefore = sim.awardCalls
	check("Start with the menu closed is NotAuthorized",
		choose(registry, "P", CN_BENCH, sim).decision == "NotAuthorized" and sim.awardCalls == callsBefore)
	check("and leaves the running selection alone", sessionOf(registry, "P").selection.lift == "Squat")
end

--------------------------------------------------------------------------------
print("-- 15. no client-supplied CN, EV or time")
--------------------------------------------------------------------------------

do
	local spoofs: { { [string]: any } } = {
		{ mode = "CN", lift = "Squat", ev = 4 },
		{ mode = "CN", lift = "Squat", cn = 500 },
		{ mode = "CN", lift = "Squat", competitionNumber = 500 },
		{ mode = "CN", lift = "Squat", elapsedSeconds = 86400 },
		{ mode = "CN", lift = "Squat", seconds = 30 },
		{ mode = "CN", lift = "Squat", timestamp = 0 },
		{ mode = "CN", lift = "Squat", position = "0,0,0" },
		{ mode = "CN", lift = "Squat", gamePass = true },
	}

	local allRefused = true
	for _, payload in ipairs(spoofs) do
		local request, refusal = TrainingStationRules.parseRequest("Start", payload, 2)
		if request ~= nil or refusal ~= "UnexpectedField" then
			allRefused = false
		end
	end
	check("Start carrying EV, CN, seconds, a timestamp, a position or a Game Pass is refused", allRefused)

	local request = TrainingStationRules.parseRequest("Start", { mode = "Technique", lift = "Bench", primary = "PressPower" }, 2)
	local onlyKnownKeys = request ~= nil
	if request then
		for key in pairs(request :: any) do
			if key ~= "action" and key ~= "selection" then
				onlyKnownKeys = false
			end
		end
		for key in pairs(request.selection :: any) do
			if key ~= "mode" and key ~= "lift" and key ~= "primary" then
				onlyKnownKeys = false
			end
		end
	end
	check("a valid request carries only an action, mode, lift and primary", onlyKnownKeys)

	-- Seconds paid are always the SERVER's own measurement, whatever the client did.
	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()
	occupyAndStart(registry, "P", "A", CN_SQUAT, sim)
	for _ = 1, 6 do
		advance(sim, TICK)
		tick(registry, "P", sim)
	end
	check("one minute at the rack pays exactly 60 server-measured seconds", near(sim.secondsAwarded, 60, 1e-9))
end

--------------------------------------------------------------------------------
print("-- 16. cleanup when closing the menu or stopping training")
--------------------------------------------------------------------------------

do
	local sim = newSim(DAY_START + 10 * HOUR)
	local registry = newRegistry()

	TrainingStationRules.openMenu(registry, "P", "A", nil, sim.clock)
	check("Close before starting anything frees the rack",
		TrainingStationRules.closeMenu(registry, "P") == "Released"
			and TrainingStationRules.occupantOf(registry, "A") == nil and sessionOf(registry, "P") == nil)
	check("Close with no rack is NotOpen", TrainingStationRules.closeMenu(registry, "P") == "NotOpen")

	occupyAndStart(registry, "P", "A", CN_SQUAT, sim)
	check("Close while training keeps the rack and hides the menu",
		TrainingStationRules.closeMenu(registry, "P") == "Closed"
			and TrainingStationRules.occupantOf(registry, "A") == "P" and not sessionOf(registry, "P").menuOpen)
	advance(sim, TICK)
	check("training carries on with the menu closed", tick(registry, "P", sim).status == "Credited")
	local _, reopened = TrainingStationRules.openMenu(registry, "P", "A", nil, sim.clock)
	check("holding E again reopens the menu", reopened == "Reopened" and sessionOf(registry, "P").menuOpen)

	advance(sim, 4)
	local callsBefore = sim.awardCalls
	local stationId, credit = TrainingStationRules.stopTraining(registry, "P", sim.clock, true, MAX_CREDIT,
		sim.readCN, sim.award)
	check("Stop credits the last 4 s while present, then frees the rack",
		stationId == "A" and credit ~= nil and (credit :: any).creditedSeconds == 4
			and sim.awardCalls == callsBefore + 1 and TrainingStationRules.occupantOf(registry, "A") == nil)
	check("stopping again does nothing",
		({ TrainingStationRules.stopTraining(registry, "P", sim.clock, true, MAX_CREDIT, sim.readCN, sim.award) })[1] == nil)

	local capped = newSim(DAY_START + 1 * HOUR)
	local cappedRegistry = newRegistry()
	occupyAndStart(cappedRegistry, "Q", "B", CN_SQUAT, capped)
	trainToCap(cappedRegistry, "Q", capped)
	check("Close while stopped at the cap keeps the rack (the player stays unless they leave or stop)",
		TrainingStationRules.closeMenu(cappedRegistry, "Q") == "Closed"
			and TrainingStationRules.occupantOf(cappedRegistry, "B") == "Q")
	local cappedCalls = capped.awardCalls
	TrainingStationRules.stopTraining(cappedRegistry, "Q", capped.clock + 5, true, MAX_CREDIT, capped.readCN, capped.award)
	check("Stop at the cap frees the rack and pays nothing",
		TrainingStationRules.occupantOf(cappedRegistry, "B") == nil and capped.awardCalls == cappedCalls)
end

print(string.format("=== %d passed, %d failed ===", passed, failed))

if failed > 0 then
	warn("[TrainingStationProbe] FAILURES above.")
else
	print("[TrainingStationProbe] set ENABLED back to false now that the run is finished.")
end
