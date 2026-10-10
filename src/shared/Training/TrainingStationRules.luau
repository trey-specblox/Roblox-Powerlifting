--!strict
--[[
	TrainingStationRules
	Shared / Training

	The decisions behind the universal gym training racks of checkpoints 5B.6
	and 5B.7 (GAME_DESIGN.md section 34.3, 34.5, 34.7 and 34.12), kept PURE so
	they can be tested without a server, a character or a real profile.

	This module holds no Instances, reads no clock and touches no DataStore. The
	caller passes in the time and a small Gateway of functions -- read whether
	CN can still be earned today, check CN eligibility, award CN, award
	technique -- and everything else is decided here. TrainingStationService
	supplies the real ones; the TrainingStationProbe supplies synthetic ones
	against a throwaway profile.

	=========================================================================
	THE SESSION
	=========================================================================

	A player who holds E at a free rack RESERVES it and gets the menu. From then
	until they leave, the session is in one of three states:

		"Selecting"        menu open, nothing started yet. Earns nothing.
		"Training"         a selection is running:
		                     CN        -> the selected lift earns CN
		                     Technique -> the selected lift's technique stats
		                                  earn raw points (80/20, or 100%
		                                  Lockout). NO CAP: it never stops on
		                                  its own, and it runs across midnight
		"StoppedAtCNCap"   CN training hit the 4.00 EV daily cap and STOPPED.
		                   The rack stays occupied; nothing is earned; the mode
		                   is NOT changed. The player must pick Technique (or,
		                   after the UTC reset, CN again) and press Start.

	Every change of selection is MANUAL. Nothing in here ever picks a lift, a
	mode or a primary stat on the player's behalf: not at the cap, not at
	midnight. Automatic CN-to-technique fallback is a FUTURE Game Pass feature
	(section 34.12) and is not implemented.

	The registry remembers, ONLY WHILE THE PLAYER IS AT THE RACK: who occupies
	which rack, the state, the selection, whether the menu is open, the
	os.clock() of the last tick and of the last selection, and the raw technique
	points earned THIS rack session (display only, never saved, forgotten on
	leaving). It never stores EV, CN, hours, allowances or technique stats.
	Those live in the profile and change ONLY through the gateway.

	=========================================================================
	THE NO-DOUBLE-COUNT RULE
	=========================================================================

	`creditSession` moves the player's last-tick clock forward to `nowClock`
	BEFORE it calls the gateway, in EVERY state. Once a stretch of seconds has
	been measured it is gone from the session, whether it was credited,
	capped or discarded, so no later tick, switch or stop can ever count it
	again -- and time spent Selecting or Stopped can never be paid later.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))
local TrainingStationConfig = require(ConfigFolder:WaitForChild("TrainingStationConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local TrainingAllowance = require(ProgressionFolder:WaitForChild("TrainingAllowance"))
local TechniqueTraining = require(ProgressionFolder:WaitForChild("TechniqueTraining"))

local TrainingStationRules = {}

export type Mode = "CN" | "Technique"

export type Selection = {
	mode: Mode,
	lift: string,
	-- The technique primary stat. Always nil for CN.
	primary: string?,
}

export type SessionState = "Selecting" | "Training" | "StoppedAtCNCap"

--[[
	Whether Competition Number can still be earned today, read from the saved
	CN allowance record:

		"Available"    allowance left
		"CapReached"   the account-wide 4.00 EV is spent until the next UTC day
		"Unavailable"  the record could not be read; nothing is credited
]]
export type CNStatus = "Available" | "CapReached" | "Unavailable"

--[[
	Remaining EV at or below this is treated as none. A float sum that lands at
	3.9999999999999996 must read as "cap reached", not as allowance that would
	ask the gateway to buy a few femto-EV of CN.
]]
local CN_EPSILON_EV = 1e-9

export type Session = {
	stationId: string,
	state: SessionState,
	selection: Selection?,
	-- True while the server has authorized this player's menu.
	menuOpen: boolean,
	-- os.clock() at the end of the last measured interval.
	lastTickClock: number,
	-- os.clock() of the last accepted selection, for the cooldown.
	lastSelectionClock: number,
	-- Raw technique points earned per stat during THIS rack session. Display only.
	techniqueGains: { [string]: number },
}

--[[
	Keyed by an opaque player key: the real Player in the game, a plain string
	in the probe. `stations` is the authoritative set of racks the SERVER
	registered; any other id is spoofed or stale.
]]
export type Registry = {
	stations: { [string]: boolean },
	occupantByStation: { [string]: any },
	sessionByPlayer: { [any]: Session },
}

export type PresenceFailure = "LeftGame" | "DataNotReady" | "NoCharacter" | "Dead" | "OutOfRange"

export type PresenceFacts = {
	inGame: boolean,
	dataReady: boolean,
	hasCharacter: boolean,
	alive: boolean,
	-- Studs from the HumanoidRootPart to the stand point, or nil if unknown.
	distance: number?,
	radius: number,
}

export type MenuRefusal =
	-- Not a string, or empty.
	"InvalidStation"
	-- A well-formed id the server never registered.
	| "UnknownStation"
	-- This player already occupies a DIFFERENT rack.
	| "AtAnotherStation"
	-- Someone else is on this rack.
	| "StationOccupied"
	-- The server could not confirm the player is standing at the rack.
	| "NotPresent"

export type RequestRefusal =
	"UnknownAction"
	| "MalformedRequest"
	-- The request carried a field the server never accepts: a station id,
	-- EV, CN, seconds, a timestamp, an entitlement...
	| "UnexpectedField"
	| "InvalidMode"
	| "InvalidLift"
	| "InvalidPrimary"

export type Request = {
	action: "Start" | "Stop" | "Close",
	selection: Selection?,
}

export type CreditStatus =
	"NoSession"
	-- Selecting, or stopped at the cap: the time is discarded.
	| "NotTraining"
	-- CN selected but the cap is reached: the session stops here.
	| "CNCapReached"
	| "CNUnavailable"
	-- The interval measured nothing to credit.
	| "NothingToCredit"
	-- The gateway was called: CN or technique, as `mode` says.
	| "Credited"

export type CreditReport = {
	status: CreditStatus,
	mode: Mode?,
	lift: string?,
	-- os.clock() seconds since the previous tick, before any clamping.
	measuredSeconds: number,
	-- Seconds handed to the gateway. Zero unless the status is "Credited".
	creditedSeconds: number,
	-- Measured seconds that were not handed to the gateway, for any reason.
	discardedSeconds: number,
	-- Whatever the gateway returned, or nil if it was not called.
	result: any,
	-- True if THIS settlement moved the session to "StoppedAtCNCap".
	stoppedAtCap: boolean,
}

export type SelectDecision =
	"NotAuthorized"
	| "Invalid"
	| "Unchanged"
	| "Cooldown"
	-- CN was requested but cannot be earned today; the session is unchanged
	-- (apart from the old interval having been settled).
	| "CNCapReached"
	| "CNUnavailable"
	-- CN was requested but the CN award refuses this player outright (for
	-- example the 120+ class, which has no Progression Reference). Nothing
	-- changed and nothing was settled; technique remains available.
	| "CNIneligible"
	| "Started"

export type SelectReport = {
	decision: SelectDecision,
	previous: Selection?,
	-- The settlement of whatever was running before. Present once the
	-- request got past validation and the cooldown.
	credit: CreditReport?,
}

export type CNReader = () -> CNStatus

--[[
	Everything the rules need from the outside world, bundled so a call site
	cannot pass the CN award where the technique award belongs.

		readCN          CN eligibility as of now, from the saved allowance
		checkCN         a ZERO-SECOND CN award: earns nothing, but returns
		                "Rejected" if this player cannot earn CN at all
		awardCN         PlayerDataService.awardTrainingProgression
		awardTechnique  PlayerDataService.awardTechniqueTraining
]]
export type Gateway = {
	readCN: CNReader,
	checkCN: (lift: string) -> any,
	awardCN: (lift: string, elapsedSeconds: number) -> any,
	awardTechnique: (lift: string, primary: string, elapsedSeconds: number) -> any,
}

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

--------------------------------------------------------------------------------
-- PLAYER-FACING TEXT
--------------------------------------------------------------------------------

TrainingStationRules.CAP_REACHED_MESSAGE = "Daily CN Limit Reached \u{2014} Training Stopped."
TrainingStationRules.CAP_REACHED_HINT =
	"Choose Technique Stats and press Start Training to keep training. CN returns at 00:00 UTC."
TrainingStationRules.CN_INELIGIBLE_MESSAGE =
	"Competition Number training isn't available for your weight class. Technique training is."
TrainingStationRules.SELECTING_MESSAGE = "Choose what to train, then press Start Training."

--------------------------------------------------------------------------------
-- PURE CALCULATIONS
--------------------------------------------------------------------------------

--[[
	Splits a measured interval into what may be credited and what is thrown away.

	Returns (credited, discarded). A negative, NaN or infinite measurement
	credits nothing. Anything over `maxSeconds` is credited only up to the cap;
	the excess is discarded, never banked for later.
]]
function TrainingStationRules.clampElapsed(rawSeconds: number, maxSeconds: number): (number, number)
	if not isFiniteNumber(rawSeconds) or rawSeconds <= 0 then
		return 0, 0
	end

	if rawSeconds > maxSeconds then
		return maxSeconds, rawSeconds - maxSeconds
	end

	return rawSeconds, 0
end

--[[
	Whether CN can be earned as of `nowUnix`, from the saved CN allowance.
	Reads only; never writes. A record from a past UTC day reads as a fresh
	allowance; one from a FUTURE day (the clock went backward) does not.
]]
function TrainingStationRules.cnStatus(cnAllowance: any, nowUnix: number): CNStatus
	local readOk, remaining = pcall(TrainingAllowance.remainingCN, cnAllowance, nowUnix)
	if not readOk or not isFiniteNumber(remaining) then
		return "Unavailable"
	end

	if remaining > CN_EPSILON_EV then
		return "Available"
	end

	return "CapReached"
end

--[[
	Why a player is NOT validly at their rack, or nil if they are.

	Checked in order, so the reason given is the most basic one that failed.
	The caller gathers the facts from the real Player and character on the
	SERVER; this only judges them, which is what lets the probe test every
	branch. A client-reported position is never one of the facts.
]]
function TrainingStationRules.presenceFailure(facts: PresenceFacts): PresenceFailure?
	if not facts.inGame then
		return "LeftGame"
	end

	if not facts.dataReady then
		return "DataNotReady"
	end

	if not facts.hasCharacter then
		return "NoCharacter"
	end

	if not facts.alive then
		return "Dead"
	end

	local distance = facts.distance
	if distance == nil or not isFiniteNumber(distance) or distance > facts.radius then
		return "OutOfRange"
	end

	return nil
end

--[[
	Whether a gateway result means the player cannot train at all right now --
	no active session, or a whole-update rejection such as an unsupported
	weight class. The rack ends the occupancy rather than retrying every tick.
	"NoProgress" and "ClockWentBackward" are NOT fatal.
]]
function TrainingStationRules.isFatalResult(result: any): boolean
	return typeof(result) ~= "table" or result.outcome == "Rejected"
end

--------------------------------------------------------------------------------
-- SELECTIONS AND REQUESTS
--------------------------------------------------------------------------------

--[[
	Whether `primary` is a technique stat this lift can train at a rack. The
	pairing table is ProgressionConfig.TrainableTechnique, through
	TechniqueTraining; PullStrength is never valid.
]]
function TrainingStationRules.isValidPrimary(lift: any, primary: any): boolean
	return TechniqueTraining.isValidPrimary(lift, primary)
end

--[[
	The technique split a selection receives, primary first: 80/20 for Squat
	and Bench, 100% Lockout for the Deadlift. nil if the combination is invalid.
]]
function TrainingStationRules.techniqueSplit(lift: string, primary: string): { TechniqueTraining.Share }?
	return TechniqueTraining.split(lift, primary)
end

local SELECTION_FIELDS = { mode = true, lift = true, primary = true }

--[[
	Turns a client's Start payload into a Selection, or says why it is refused.
	Only `mode`, `lift` and `primary` are accepted; any other field is refused
	outright rather than ignored, so a client stuffing in EV or seconds learns
	nothing and gets nothing.
]]
function TrainingStationRules.validateSelection(payload: any): (Selection?, RequestRefusal?)
	if typeof(payload) ~= "table" then
		return nil, "MalformedRequest"
	end

	for key in pairs(payload) do
		if typeof(key) ~= "string" or not SELECTION_FIELDS[key] then
			return nil, "UnexpectedField"
		end
	end

	local mode = payload.mode
	if mode ~= "CN" and mode ~= "Technique" then
		return nil, "InvalidMode"
	end

	local lift: any = payload.lift
	if not ProgressionConfig.isLift(lift) then
		return nil, "InvalidLift"
	end

	local liftName: string = lift
	local primary: any = payload.primary

	if mode == "CN" then
		if primary ~= nil then
			return nil, "InvalidPrimary"
		end
		return { mode = "CN", lift = liftName, primary = nil }, nil
	end

	if not TrainingStationRules.isValidPrimary(liftName, primary) then
		return nil, "InvalidPrimary"
	end

	local primaryName: string = primary
	return { mode = "Technique", lift = liftName, primary = primaryName }, nil
end

--[[
	Validates one menu request exactly as it arrived over the remote:
	`argumentCount` is how many values the client sent after the Player.

		Start  (payload)   payload is { mode, lift, primary? }
		Stop   ()
		Close  ()

	There is no station id: the server already knows which rack the player
	occupies. There is no time, EV or CN: the server measures those itself.
]]
function TrainingStationRules.parseRequest(action: any, payload: any, argumentCount: number): (Request?, RequestRefusal?)
	if action == "Start" then
		if argumentCount ~= 2 then
			return nil, "MalformedRequest"
		end

		local selection: Selection?, refusal: RequestRefusal? = TrainingStationRules.validateSelection(payload)
		if selection == nil then
			return nil, refusal
		end

		return { action = "Start", selection = selection }, nil
	end

	if action == "Stop" or action == "Close" then
		if argumentCount ~= 1 or payload ~= nil then
			return nil, "UnexpectedField"
		end

		return { action = action, selection = nil }, nil
	end

	return nil, "UnknownAction"
end

local function sameSelection(a: Selection?, b: Selection?): boolean
	if a == nil or b == nil then
		return a == b
	end

	return a.mode == b.mode and a.lift == b.lift and a.primary == b.primary
end

local function copySelection(selection: Selection): Selection
	return { mode = selection.mode, lift = selection.lift, primary = selection.primary }
end

--------------------------------------------------------------------------------
-- RATE LIMITING
--------------------------------------------------------------------------------

export type RateLimiter = { [any]: { number } }

function TrainingStationRules.newRateLimiter(): RateLimiter
	return {}
end

--[[
	A sliding window: true if this request is allowed (and records it), false
	if the player already made `limit` requests in the last `windowSeconds`.
	A refused request is NOT recorded, so a spammer cannot push their own
	window forward forever; they are simply ignored until it clears.
]]
function TrainingStationRules.allowRequest(
	limiter: RateLimiter,
	playerKey: any,
	nowClock: number,
	limit: number,
	windowSeconds: number
): boolean
	local stamps = limiter[playerKey]
	if stamps == nil then
		stamps = {}
		limiter[playerKey] = stamps
	end

	local kept: { number } = {}
	for _, stamp in ipairs(stamps) do
		if nowClock - stamp < windowSeconds then
			table.insert(kept, stamp)
		end
	end

	if #kept >= limit then
		limiter[playerKey] = kept
		return false
	end

	table.insert(kept, nowClock)
	limiter[playerKey] = kept
	return true
end

function TrainingStationRules.forgetRequester(limiter: RateLimiter, playerKey: any)
	limiter[playerKey] = nil
end

--------------------------------------------------------------------------------
-- THE REGISTRY
--------------------------------------------------------------------------------

function TrainingStationRules.newRegistry(): Registry
	return {
		stations = {},
		occupantByStation = {},
		sessionByPlayer = {},
	}
end

--[[
	Adds a rack to the authoritative set. Returns false for a bad or duplicate id.
]]
function TrainingStationRules.registerStation(registry: Registry, stationId: any): boolean
	if typeof(stationId) ~= "string" or stationId == "" or registry.stations[stationId] then
		return false
	end

	registry.stations[stationId] = true
	return true
end

--[[
	Removes a rack. Its occupant, if any, is NOT released here; the caller's
	next tick finds the rack missing and ends the session without credit.
]]
function TrainingStationRules.unregisterStation(registry: Registry, stationId: string)
	registry.stations[stationId] = nil
end

function TrainingStationRules.sessionOf(registry: Registry, playerKey: any): Session?
	return registry.sessionByPlayer[playerKey]
end

function TrainingStationRules.occupantOf(registry: Registry, stationId: string): any
	return registry.occupantByStation[stationId]
end

--[[
	Why this player may not open the menu at this rack, or nil if they may.
	`presence` is the server's own presence verdict. Changes nothing.
]]
function TrainingStationRules.menuRefusal(
	registry: Registry,
	playerKey: any,
	stationId: any,
	presence: PresenceFailure?
): MenuRefusal?
	if typeof(stationId) ~= "string" or stationId == "" then
		return "InvalidStation"
	end

	if not registry.stations[stationId] then
		return "UnknownStation"
	end

	local session = registry.sessionByPlayer[playerKey]
	if session ~= nil and session.stationId ~= stationId then
		return "AtAnotherStation"
	end

	local occupant = registry.occupantByStation[stationId]
	if occupant ~= nil and occupant ~= playerKey then
		return "StationOccupied"
	end

	if presence ~= nil then
		return "NotPresent"
	end

	return nil
end

--[[
	Authorizes the menu. A free rack is RESERVED for this player in the
	"Selecting" state; their own rack is simply reopened. Returns
	(refusal, nil) or (nil, "Reserved" | "Reopened").

	The interval clock of a new reservation starts NOW: no time before the
	player arrived is ever credited.
]]
function TrainingStationRules.openMenu(
	registry: Registry,
	playerKey: any,
	stationId: any,
	presence: PresenceFailure?,
	nowClock: number
): (MenuRefusal?, ("Reserved" | "Reopened")?)
	local refusal: MenuRefusal? = TrainingStationRules.menuRefusal(registry, playerKey, stationId, presence)
	if refusal ~= nil then
		return refusal, nil
	end

	local session = registry.sessionByPlayer[playerKey]
	if session ~= nil then
		session.menuOpen = true
		return nil, "Reopened"
	end

	registry.occupantByStation[stationId] = playerKey
	registry.sessionByPlayer[playerKey] = {
		stationId = stationId,
		state = "Selecting",
		selection = nil,
		menuOpen = true,
		lastTickClock = nowClock,
		lastSelectionClock = -math.huge,
		techniqueGains = {},
	}

	return nil, "Reserved"
end

--[[
	Takes the player off their rack WITHOUT crediting anything. Used for
	death, respawn, leaving range, disconnects and closing an unused menu: the
	unmeasured remainder of the current tick is simply lost, which only ever
	goes against the player.

	Returns the rack they were on, or nil if they had none.
]]
function TrainingStationRules.release(registry: Registry, playerKey: any): string?
	local session = registry.sessionByPlayer[playerKey]
	if session == nil then
		return nil
	end

	registry.sessionByPlayer[playerKey] = nil

	if registry.occupantByStation[session.stationId] == playerKey then
		registry.occupantByStation[session.stationId] = nil
	end

	return session.stationId
end

--[[
	The player closed the menu.

		"NotOpen"   they had no session; nothing happens
		"Released"  they never started anything, so the rack is freed
		"Closed"    the menu is hidden; training (or the stop at the cap)
		            carries on and the rack stays theirs
]]
function TrainingStationRules.closeMenu(registry: Registry, playerKey: any): "NotOpen" | "Released" | "Closed"
	local session = registry.sessionByPlayer[playerKey]
	if session == nil then
		return "NotOpen"
	end

	if session.state == "Selecting" then
		TrainingStationRules.release(registry, playerKey)
		return "Released"
	end

	session.menuOpen = false
	return "Closed"
end

--------------------------------------------------------------------------------
-- CREDITING
--------------------------------------------------------------------------------

--[[
	Moves the session's interval clock FORWARD to `nowClock`, never backward. A
	stale or earlier time must not rewind the clock, or the next tick would
	measure (and pay) seconds that were already measured.
]]
local function advanceClock(session: Session, nowClock: number)
	if isFiniteNumber(nowClock) and nowClock > session.lastTickClock then
		session.lastTickClock = nowClock
	end
end

local function emptyReport(status: CreditStatus): CreditReport
	return {
		status = status,
		mode = nil,
		lift = nil,
		measuredSeconds = 0,
		creditedSeconds = 0,
		discardedSeconds = 0,
		result = nil,
		stoppedAtCap = false,
	}
end

--[[
	Adds an awarded technique result to the session's "This Session" display
	counters. Display only: the profile already holds the real values.
]]
local function recordTechniqueGains(session: Session, result: any)
	if typeof(result) ~= "table" or result.outcome ~= "Awarded" or typeof(result.gains) ~= "table" then
		return
	end

	local gains: { any } = result.gains
	for _, gain in ipairs(gains) do
		if typeof(gain) == "table" and typeof(gain.stat) == "string" and isFiniteNumber(gain.raw) then
			session.techniqueGains[gain.stat] = (session.techniqueGains[gain.stat] or 0) + gain.raw
		end
	end
end

--[[
	Settles the time since the player's last tick. The caller must already
	have verified presence.

	  1. Measure the interval and MOVE THE CLOCK FORWARD FIRST, in every
	     state, so these seconds can never be counted twice.
	  2. Only a "Training" session earns. Selecting and Stopped discard the
	     time.
	  3. TECHNIQUE: the clamped interval goes to the technique award. There
	     is no cap and no day boundary, so nothing here can stop it; it runs
	     across midnight exactly as at any other time.
	  4. CN: read the CN status at the END of the interval. Reading at the
	     end is what makes a midnight work: the gateway itself splits an
	     interval that straddles 00:00 UTC and pays only the part after it.
	     If CN is capped -- before the gateway, or because this very award
	     reached the cap -- the session STOPS: state "StoppedAtCNCap". The
	     selection is left exactly as the player chose it. Nothing switches,
	     and technique is NEVER started on the player's behalf.

	Nothing in here yields, so two settlements can never interleave.
]]
function TrainingStationRules.creditSession(
	registry: Registry,
	playerKey: any,
	nowClock: number,
	maxCreditSeconds: number,
	gateway: Gateway
): CreditReport
	local session = registry.sessionByPlayer[playerKey]
	if session == nil then
		return emptyReport("NoSession")
	end

	local measured = nowClock - session.lastTickClock
	advanceClock(session, nowClock)

	local credited, discarded = TrainingStationRules.clampElapsed(measured, maxCreditSeconds)
	local selection = session.selection

	local report = emptyReport("NotTraining")
	report.measuredSeconds = if isFiniteNumber(measured) then measured else 0
	report.discardedSeconds = credited + discarded

	if session.state ~= "Training" or selection == nil then
		return report
	end

	report.mode = selection.mode
	report.lift = selection.lift

	if selection.mode == "Technique" then
		if credited <= 0 then
			report.status = "NothingToCredit"
			return report
		end

		local primary = selection.primary :: string
		report.result = gateway.awardTechnique(selection.lift, primary, credited)
		report.status = "Credited"
		report.creditedSeconds = credited
		report.discardedSeconds = discarded
		recordTechniqueGains(session, report.result)
		return report
	end

	local status = gateway.readCN()

	if status == "CapReached" then
		session.state = "StoppedAtCNCap"
		report.status = "CNCapReached"
		report.stoppedAtCap = true
		return report
	end

	if status ~= "Available" then
		report.status = "CNUnavailable"
		return report
	end

	if credited <= 0 then
		report.status = "NothingToCredit"
		return report
	end

	report.result = gateway.awardCN(selection.lift, credited)
	report.status = "Credited"
	report.creditedSeconds = credited
	report.discardedSeconds = discarded

	if gateway.readCN() == "CapReached" then
		session.state = "StoppedAtCNCap"
		report.stoppedAtCap = true
	end

	return report
end

--[[
	Starts or changes training, MANUALLY, at the player's request. The menu
	must be open (authorized by the server at a rack the player occupies).
	Technique may be chosen at any time, whatever CN allowance remains.

	Whatever was running is settled FIRST, to the OLD selection (section
	34.12: time goes to what was selected at that moment). Nothing is reset:
	per-lift hours, allowances and technique stats are account state in the
	profile.

		"NotAuthorized"  no rack, or the menu was not opened by the server
		"Invalid"        not a valid selection
		"Unchanged"      exactly this is already training; nothing happens
		"Cooldown"       too soon after the last selection; nothing happens
		"CNIneligible"   CN requested, but the CN award refuses this player
		                 outright (e.g. 120+). Nothing changes, nothing settled
		"CNCapReached"   CN requested at the cap; the selection is NOT applied
		"CNUnavailable"  CN requested while the record is unreadable
		"Started"        old interval settled, new selection running from now
]]
function TrainingStationRules.selectTraining(
	registry: Registry,
	playerKey: any,
	selection: Selection,
	nowClock: number,
	cooldownSeconds: number,
	maxCreditSeconds: number,
	gateway: Gateway
): SelectReport
	local session = registry.sessionByPlayer[playerKey]

	if session == nil or not session.menuOpen then
		return { decision = "NotAuthorized", previous = nil, credit = nil }
	end

	local previous = session.selection

	local validated = TrainingStationRules.validateSelection(selection)
	if validated == nil then
		return { decision = "Invalid", previous = previous, credit = nil }
	end

	if session.state == "Training" and sameSelection(previous, validated) then
		return { decision = "Unchanged", previous = previous, credit = nil }
	end

	if nowClock - session.lastSelectionClock < cooldownSeconds then
		return { decision = "Cooldown", previous = previous, credit = nil }
	end

	--[[
		CN ELIGIBILITY, checked BEFORE anything is settled. A zero-second CN
		award earns nothing; a "Rejected" answer means this player cannot earn
		CN at all (no Progression Reference for their class), so the request is
		refused and whatever was running carries on untouched.
	]]
	if validated.mode == "CN" and TrainingStationRules.isFatalResult(gateway.checkCN(validated.lift)) then
		return { decision = "CNIneligible", previous = previous, credit = nil }
	end

	local credit = TrainingStationRules.creditSession(registry, playerKey, nowClock, maxCreditSeconds, gateway)

	if validated.mode == "CN" then
		local status = gateway.readCN()
		if status == "CapReached" then
			return { decision = "CNCapReached", previous = previous, credit = credit }
		elseif status ~= "Available" then
			return { decision = "CNUnavailable", previous = previous, credit = credit }
		end
	end

	session.selection = copySelection(validated)
	session.state = "Training"
	advanceClock(session, nowClock)
	session.lastSelectionClock = nowClock

	return { decision = "Started", previous = previous, credit = credit }
end

--[[
	Stop Training: settles the interval so far ONLY if the player is
	genuinely still at the rack (`present`), then frees the rack. Leaving any
	other way credits nothing.

	Returns the rack that was freed (or nil) and the settlement (or nil).
]]
function TrainingStationRules.stopTraining(
	registry: Registry,
	playerKey: any,
	nowClock: number,
	present: boolean,
	maxCreditSeconds: number,
	gateway: Gateway
): (string?, CreditReport?)
	if registry.sessionByPlayer[playerKey] == nil then
		return nil, nil
	end

	local credit: CreditReport? = nil
	if present then
		credit = TrainingStationRules.creditSession(registry, playerKey, nowClock, maxCreditSeconds, gateway)
	end

	return TrainingStationRules.release(registry, playerKey), credit
end

--[[
	The menu's name for a technique stat, e.g. "Depth Awareness".
]]
function TrainingStationRules.statName(stat: string): string
	return (TrainingStationConfig.TechniqueStatNames :: any)[stat] or stat
end

--[[
	One line describing what the session is doing, for the rack sign and the
	menu. Pure, so the probe can check the exact wording players see.
]]
function TrainingStationRules.statusLine(session: Session?): string
	if session == nil then
		return "Not training"
	end

	if session.state == "Selecting" then
		return TrainingStationRules.SELECTING_MESSAGE
	end

	if session.state == "StoppedAtCNCap" then
		return TrainingStationRules.CAP_REACHED_MESSAGE
	end

	local selection = session.selection
	if selection == nil then
		return "Not training"
	end

	if selection.mode == "CN" then
		return string.format("Training %s \u{2014} Competition Number", selection.lift)
	end

	return string.format(
		"Training %s \u{2014} Technique (%s primary)",
		selection.lift,
		TrainingStationRules.statName(selection.primary or "?")
	)
end

return TrainingStationRules
