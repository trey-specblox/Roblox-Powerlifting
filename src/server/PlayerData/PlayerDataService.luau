--!strict
--[[
	PlayerDataService
	Server / PlayerData

	THE SINGLE GATEWAY TO PERSISTENT PLAYER DATA.

	Nothing else in the game may require ProfileStore. Every gameplay system that
	needs to read or change saved data goes through this module. That rule is what
	keeps data safe: session handling, migration, validation and save timing all
	live in one file instead of being re-implemented, slightly differently, by
	every system that touches a stat.

	HOW TO USE IT FROM A GAMEPLAY SYSTEM

		local data = PlayerDataService.getData(player)
		if data then
			print(data.competitionNumber.Squat)
		end

	Reading returns the live table for speed, and callers must treat it as
	READ-ONLY.

	PREFER THE NAMED OPERATIONS OVER update()

		PlayerDataService.consumeCompetitionBudget(player, "Squat", 1.886)
		PlayerDataService.consumeTrainingEnergy(player, 30)

	NOTE that the only operation here that writes a Competition Number is
	awardTrainingProgression, and it accepts station seconds, never kilograms.
	Why there is no general CN writer is explained further down.

	Each validates its own arguments, rejects NaN and infinity, enforces the
	resource's floor and cap, and regenerates a timestamped resource before
	spending from it. The rules live in ProfileOperations, which is pure and
	therefore actually tested.

	update() remains for data that has no named operation yet. It is the escape
	hatch, not the front door: a caller using it takes on every validation the
	named operations would have done. New gameplay systems should ask for an
	operation rather than reach through it.

	Both refuse when the session is not active, so a change can never be silently
	dropped into a table that is no longer being saved.

	SERVER AUTHORITY

	This module is in ServerScriptService and is unreachable from the client. It
	creates no RemoteEvents and no RemoteFunctions, so right now there is no path
	by which a client can read or write persistent data at all. When replication is
	added later, it must send derived values the client needs for display, and must
	never accept a value from the client as truth.
]]

local Players = game:GetService("Players")

local PlayerProfileSchema = require(script.Parent.PlayerProfileSchema)
local ProfileOperations = require(script.Parent.ProfileOperations)

--[[
	ProfileStore ships with Luau type annotations that the current type solver
	reports errors against (it annotates its module table and then adds methods to
	it, which Luau treats as a sealed table). Those are analysis artifacts, not
	runtime faults, and the library is deliberately left unmodified.

	Casting the require to `any` keeps that third-party type noise from leaking
	into this file, and the minimal types below restore real type checking at our
	own boundary. We type what we use rather than trusting what it declares.
]]
local ProfileStoreModule = require(script.Parent.Parent.Packages.ProfileStore) :: any

type Connection = { Disconnect: (self: Connection) -> () }

type Profile = {
	Data: PlayerProfileSchema.ProfileData,
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> Connection },
	IsActive: (self: Profile) -> boolean,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
}

type SessionParams = {
	Steal: boolean?,
	Cancel: (() -> boolean)?,
}

type Store = {
	StartSessionAsync: (self: Store, key: string, params: SessionParams?) -> Profile?,
}

local PlayerDataService = {}

--[[
	CHANGING THIS NAME ABANDONS EVERY EXISTING SAVE.

	Players would silently start over with fresh profiles while the old data sat
	unreachable under the previous name. Treat it as permanent once the game is
	live. If a wipe is ever genuinely wanted, that is the moment to change it, on
	purpose, and to say so in the commit message.
]]
local STORE_NAME = "PlayerData"

-- Profile keys are namespaced so a UserId can never collide with another key.
local KEY_PREFIX = "Player_"

-- Prints a line per load and release. Useful while testing in Studio.
local VERBOSE = true

local store: Store = ProfileStoreModule.New(STORE_NAME, PlayerProfileSchema.template)

local profiles: { [Player]: Profile } = {}
local started = false

local function log(message: string, ...: any)
	if VERBOSE then
		print("[PlayerDataService] " .. string.format(message, ...))
	end
end

local function profileKey(player: Player): string
	return KEY_PREFIX .. tostring(player.UserId)
end

--[[
	Records session bookkeeping and stamps the creation time on a first load.
]]
local function stampSession(data: PlayerProfileSchema.ProfileData)
	local now = os.time()

	if data.meta.createdUnix == 0 then
		data.meta.createdUnix = now
	end

	data.meta.lastSessionUnix = now
	data.meta.sessionCount += 1
end

local function onPlayerAdded(player: Player)
	--[[
		Cancel is checked while ProfileStore retries. Without it, a player who
		joins and immediately leaves leaves a load attempt grinding away, and in
		the worst case the session lock is taken for someone who is already gone.
	]]
	local profile = store:StartSessionAsync(profileKey(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		--[[
			Either the player left during loading, or the session could not be
			started. Kicking is correct and deliberate: letting them play with no
			profile means their progress silently evaporates, which is far worse
			than asking them to rejoin.
		]]
		log("could not start a session for %s", player.Name)
		player:Kick("Could not load your save data. Please rejoin.")
		return
	end

	-- GDPR association, so the data is discoverable under the right account.
	profile:AddUserId(player.UserId)

	--[[
		Version MUST be read before Reconcile. Reconcile fills missing keys from
		the template, and the template carries the current version, so a save that
		predates versioning would otherwise be stamped current and skip migration.
	]]
	local fromVersion = PlayerProfileSchema.detectVersion(profile.Data)

	profile:Reconcile()

	local finalVersion = PlayerProfileSchema.migrate(profile.Data, fromVersion)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		log("session ended for %s", player.Name)
		--[[
			The lock was lost, usually because the same account started a session
			on another server. Continuing to play would mean accumulating changes
			that will never be saved.
		]]
		player:Kick("Your save session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		-- They left while the profile was loading. Release the lock immediately.
		profile:EndSession()
		return
	end

	stampSession(profile.Data)
	profiles[player] = profile

	log(
		"loaded %s (version %d, session %d) S/B/D %.1f/%.1f/%.1f at %.1f kg",
		player.Name,
		finalVersion,
		profile.Data.meta.sessionCount,
		profile.Data.competitionNumber.Squat,
		profile.Data.competitionNumber.Bench,
		profile.Data.competitionNumber.Deadlift,
		profile.Data.bodyweight.currentKg
	)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		-- Saves whatever changed and releases the session lock.
		profile:EndSession()
		profiles[player] = nil
	end
end

--[[
	Starts listening for players. Call once, from the server entry point.
]]
function PlayerDataService.start()
	assert(not started, "[PlayerDataService] start() must only be called once")
	started = true

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	--[[
		Anyone who joined before this ran still needs a profile. In a live server
		this is rare, but in Studio the local player is frequently already present
		by the time scripts execute.
	]]
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	log("started")
end

--[[
	True once the player's data is loaded and its session is still active.
]]
function PlayerDataService.isReady(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile:IsActive()
end

--[[
	The player's persistent data, or nil if it is not loaded.

	TREAT THE RESULT AS READ-ONLY. Use update to change anything.
]]
function PlayerDataService.getData(player: Player): PlayerProfileSchema.ProfileData?
	local profile = profiles[player]
	if profile == nil then
		return nil
	end
	return profile.Data
end

--[[
	Waits for a player's data to load, for systems that run before it is ready.

	Returns nil if the timeout passes or the player leaves first, and callers must
	handle that rather than assuming success.
]]
function PlayerDataService.waitForData(
	player: Player,
	timeoutSeconds: number?
): PlayerProfileSchema.ProfileData?
	local timeout = timeoutSeconds or 30
	local deadline = os.clock() + timeout

	while os.clock() < deadline do
		if player.Parent ~= Players then
			return nil
		end

		local data = PlayerDataService.getData(player)
		if data ~= nil then
			return data
		end

		task.wait()
	end

	warn(string.format("[PlayerDataService] timed out waiting for %s's data", player.Name))
	return nil
end

--[[
	THE ONLY SANCTIONED WAY TO CHANGE PERSISTENT DATA.

	Runs `mutator` against the player's live data and returns whether it ran.
	Refuses when the session is not active, so a change can never be written into
	a table that is no longer being saved.

	The mutator's errors are caught, because a bug in one gameplay system must not
	take down whatever triggered the write.
]]
function PlayerDataService.update(
	player: Player,
	mutator: (PlayerProfileSchema.ProfileData) -> ()
): boolean
	local profile = profiles[player]

	if profile == nil then
		warn(string.format("[PlayerDataService] update for %s with no loaded profile", player.Name))
		return false
	end

	if not profile:IsActive() then
		warn(string.format("[PlayerDataService] update for %s whose session is not active", player.Name))
		return false
	end

	local ok, err = pcall(mutator, profile.Data)

	if not ok then
		warn(string.format("[PlayerDataService] update for %s errored: %s", player.Name, tostring(err)))
		return false
	end

	return true
end

--[[
	=========================================================================
	NAMED AUTHORITATIVE OPERATIONS
	=========================================================================

	Each of these binds a Player to their live profile, refuses when the session
	is not active, and delegates the actual rule to ProfileOperations.

	THE CLOCK IS ALWAYS os.time(), READ HERE, ON THE SERVER. No operation takes a
	timestamp as a parameter, so there is no argument through which a caller --
	let alone a client -- could supply one. That is the only reason offline
	regeneration can be trusted.

	NOTHING IN THE GAME CALLS THESE YET. No station calls the training award
	(checkpoint 5B.6 will), no meet consumes budget, and no AFK system consumes
	Training Energy. They exist
	so the systems that will do those things have one validated path.
]]

--[[
	The live profile of an active session, or nil with a warning.

	Every operation below begins here, so the "is the session still active" check
	is written once rather than five times.
]]
local function activeData(player: Player, operation: string): PlayerProfileSchema.ProfileData?
	local profile = profiles[player]

	if profile == nil then
		warn(string.format("[PlayerDataService] %s for %s with no loaded profile", operation, player.Name))
		return nil
	end

	if not profile:IsActive() then
		warn(string.format("[PlayerDataService] %s for %s whose session is not active", operation, player.Name))
		return nil
	end

	return profile.Data
end

--[[
	The player's Competition Number for one lift, in kilograms.

	Returns nil when the data is not loaded, the lift name is not one of the
	three, or the stored value is unusable.
]]
function PlayerDataService.getCompetitionNumber(player: Player, lift: string): number?
	local data = activeData(player, "getCompetitionNumber")
	if data == nil then
		return nil
	end

	return ProfileOperations.getCompetitionNumber(data, lift)
end

--[[
	THERE IS DELIBERATELY NO METHOD HERE THAT WRITES AN ARBITRARY COMPETITION
	NUMBER.

	An earlier draft exposed addCompetitionNumber(player, lift, deltaKg), which
	let any caller award an arbitrary number of kilograms. The guard against that
	was a constant, MAXIMUM_SINGLE_ADD_KG = 100, and it was wrong twice over: it
	appears nowhere in GAME_DESIGN.md, and it was simultaneously too permissive
	for a reward -- the real figure is under 3 kg for one attempt -- and too
	restrictive for a legitimate weight-class translation.

	So no kilogram writer exists. Two operations reopen the door, each owning its
	own bound:

	  1. awardTrainingProgression(player, lift, elapsedSeconds), below.
	     Takes observed station SECONDS -- never EV, never kilograms -- and
	     derives both on the server. Bounded by construction, so no caller can
	     get the magnitude wrong. Checkpoint 5B.5.

	  2. translateCompetitionNumbers(player, fromClass, toClass)
	     The authoritative RP Preservation recalculation of section 29.11, whose
	     legitimate deltas are large. Not built yet.

	Both call ProfileOperations.applyCompetitionNumberDelta, which keeps the
	validation that is universally true -- finite delta, known lift, a result
	that remains a positive weight -- and holds no magnitude opinion, because
	magnitude is the caller's to justify.
]]

--[[
	Applies `elapsedSeconds` of gym-station training on `lift`: debits the
	account's daily allowance and awards the Competition Number it paid for, in
	one synchronous write to the live profile.

	THE ONLY SOURCE OF COMPETITION NUMBER (section 34.2). SERVER-ONLY: there is
	no remote for it, and none may ever be added. The caller is the gym training
	station of checkpoint 5B.6, which does not exist yet, so NOTHING CALLS THIS
	in 5B.5.

	WHAT THE CALLER SUPPLIES, AND WHAT IT NEVER DOES
	  - `elapsedSeconds` is ACTIVE training time the server itself observed with
	    the player present at the station, since that station last ticked them.
	    It is NEVER time since `lastUpdatedUnix` -- that would credit time spent
	    offline -- and never a number a client reported.
	  - The caller never supplies EV, kilograms or a timestamp. The clock is
	    os.time(), read here; EV comes from TrainingAllowance and
	    TrainingEfficiency; kilograms from the reward formula.

	Returns the ProfileOperations.TrainingResult, or nil when the player has no
	active session. A "Rejected" or "ClockWentBackward" result wrote NOTHING.
	The Competition Budget and Training Energy are never touched (decision A).
]]
function PlayerDataService.awardTrainingProgression(
	player: Player,
	lift: string,
	elapsedSeconds: number
): ProfileOperations.TrainingResult?
	local data = activeData(player, "awardTrainingProgression")
	if data == nil then
		return nil
	end

	local result = ProfileOperations.applyTrainingProgression(data, lift, os.time(), elapsedSeconds)

	if result.outcome == "Rejected" then
		warn(string.format(
			"[PlayerDataService] training update for %s rejected: %s",
			player.Name,
			tostring(result.rejectionReason)
		))
	elseif result.outcome == "ClockWentBackward" then
		warn(string.format(
			"[PlayerDataService] training update for %s skipped: the server clock is behind the saved day",
			player.Name
		))
	end

	return result
end

--[[
	One lift's Competition Budget in EV units, including everything that
	regenerated while the player was away. Reads without writing.

	A negative result means that lift is in harmonic overflow, and the magnitude
	is how deep.
]]
function PlayerDataService.getRegeneratedCompetitionBudget(player: Player, lift: string): number?
	local data = activeData(player, "getRegeneratedCompetitionBudget")
	if data == nil then
		return nil
	end

	return ProfileOperations.getRegeneratedCompetitionBudget(data, lift, os.time())
end

--[[
	One lift's current budget amount, harmonic multiplier and freshness state
	(FRESH / WORKED / FATIGUED). Reads without writing.
]]
function PlayerDataService.getCompetitionBudgetState(
	player: Player,
	lift: string
): (number?, number?, string?)
	local data = activeData(player, "getCompetitionBudgetState")
	if data == nil then
		return nil, nil, nil
	end

	return ProfileOperations.getCompetitionBudgetState(data, lift, os.time())
end

--[[
	Consumes `rawEV` of progression from one lift's Competition Budget and
	returns the EFFECTIVE EV earned, after harmonic overflow.

	THIS DOES NOT FAIL WHEN THE BUDGET IS SPENT. Progression continues at a
	diminishing multiplier, because active meet progression is never hard-zeroed.
	A nil return means the request was malformed, not that the player was short.

	Contrast consumeTrainingEnergy below, which returns false when short.

	Spending Squat does not touch Bench or Deadlift. The three pools are separate
	and each is account-wide for its own lift.
]]
function PlayerDataService.consumeCompetitionBudget(
	player: Player,
	lift: string,
	rawEV: number
): (number?, number?)
	local data = activeData(player, "consumeCompetitionBudget")
	if data == nil then
		return nil, nil
	end

	return ProfileOperations.consumeCompetitionBudget(data, lift, rawEV, os.time())
end

--[[
	Training Energy in minutes, including offline regeneration. Reads without
	writing.
]]
function PlayerDataService.getRegeneratedTrainingEnergy(player: Player): number?
	local data = activeData(player, "getRegeneratedTrainingEnergy")
	if data == nil then
		return nil
	end

	return ProfileOperations.getRegeneratedTrainingEnergy(data, os.time())
end

--[[
	Spends `minutes` of Training Energy. Returns success and what remains.

	ALL-OR-NOTHING, AND IT DOES FAIL WHEN SHORT. Training Energy floors at zero:
	at empty, passive AFK Competition Number stops and there is no overflow. That
	is deliberately unlike the Competition Budget above, and the asymmetry is
	what holds the intended ratio of roughly 0.25x the reference active rate.

	This gates passive AFK Competition Number ONLY. It must never be made to gate
	Muscle, which progresses independently.
]]
function PlayerDataService.consumeTrainingEnergy(player: Player, minutes: number): (boolean, number?)
	local data = activeData(player, "consumeTrainingEnergy")
	if data == nil then
		return false, nil
	end

	return ProfileOperations.consumeTrainingEnergy(data, minutes, os.time())
end

return PlayerDataService
