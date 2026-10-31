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
			print(data.bodyweight.currentKg)
		end

		-- Competition Number lives in the build of the current class:
		print(PlayerDataService.getCompetitionNumber(player, "Squat"))

	Reading returns the live table for speed, and callers must treat it as
	READ-ONLY.

	PREFER THE NAMED OPERATIONS OVER update()

		PlayerDataService.awardTrainingProgression(...)

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
	creates no RemoteEvents and no RemoteFunctions. The only client-facing path
	near it is the training rack menu (TrainingStationService): a client may
	REQUEST a training mode, lift and stat, never a value, and receives derived
	display values back. Any future replication must likewise send derived values
	for display and never accept a value from the client as truth.
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
-- Told about every coin change (onCoinsChanged): player, change (+/-), new balance, reason.
local coinListeners: { (Player, number, number, string) -> () } = {}

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

	local function cnText(lift: string): string
		local cn = ProfileOperations.getCompetitionNumber(profile.Data, lift)
		return if cn then string.format("%.1f", cn) else "?"
	end
	log(
		"loaded %s (version %d, session %d) %s build S/B/D %s/%s/%s at %.1f kg",
		player.Name,
		finalVersion,
		profile.Data.meta.sessionCount,
		ProfileOperations.getActiveClassKey(profile.Data) or "?",
		cnText("Squat"),
		cnText("Bench"),
		cnText("Deadlift"),
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

	The two training awards -- Competition Number (5B.5) and technique (5B.7) --
	are called by TrainingStationService and by nothing else. Meets write through update() with the named
	ProfileOperations raises (the Mock Meet's Scale and best Total; the Local meet's allowance settlement).
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
	The player's Competition Scale for one lift, in kilograms, from the current
	class's build: the heaviest weight they have proven in a meet, 0 when unproven.
	Read-only (the meet raises it through ProfileOperations). Returns nil when the
	data is not loaded or the lift is not one of the three.
]]
function PlayerDataService.getCompetitionScale(player: Player, lift: string): number?
	local data = activeData(player, "getCompetitionScale")
	if data == nil then
		return nil
	end

	return ProfileOperations.getCompetitionScale(data, lift)
end

--[[
	COINS (GAME_DESIGN.md 30.6). The player's coins, or nil when the data is not
	loaded.
]]
local function coinsChanged(player: Player, change: number, balance: number, reason: string)
	for _, listener in ipairs(coinListeners) do
		task.spawn(listener, player, change, balance, reason)
	end
end

--[[
	Calls `listener(player, change, balance, reason)` after every add or spend
	(change is +amount or -amount). For screens only (CoinDisplayService); a
	listener must never write data back.
]]
function PlayerDataService.onCoinsChanged(listener: (Player, number, number, string) -> ())
	table.insert(coinListeners, listener)
end

function PlayerDataService.getCoins(player: Player): number?
	local data = activeData(player, "getCoins")
	if data == nil then
		return nil
	end
	return ProfileOperations.getCoins(data)
end

--[[
	Adds `amount` coins for `reason` (a short log label, e.g. "Local meet 1st").
	SERVER-ONLY: the caller decided the amount itself (a meet payout from
	config); no client number may reach here. Returns the outcome and the new
	balance; nil when the player has no active session.
]]
function PlayerDataService.addCoins(player: Player, amount: number, reason: string): (ProfileOperations.CoinOutcome?, number?)
	local data = activeData(player, "addCoins")
	if data == nil then
		return nil, nil
	end
	local outcome: ProfileOperations.CoinOutcome, balance = ProfileOperations.addCoins(data, amount)
	if outcome == "Added" then
		print(string.format("[PlayerDataService] %s +%d coins (%s): %d", player.Name, amount, reason, balance :: number))
		coinsChanged(player, amount, balance :: number, reason)
	else
		warn(string.format("[PlayerDataService] %s: %s coins refused (%s, %s)", player.Name, tostring(amount), reason, outcome))
	end
	return outcome, balance
end

--[[
	Buys a Shop item: takes `price` coins and adds `itemId` to the inventory in
	one step (ProfileOperations.purchaseItem). SERVER-ONLY: the price comes from
	ShopConfig, never from a client; the caller (ShopService) checks the item
	is for sale. `reason` labels the log and the coin pop-up. Returns the
	outcome and the balance; nil with no active session.
]]
function PlayerDataService.purchaseItem(player: Player, itemId: string, price: number, reason: string)
	: (ProfileOperations.PurchaseOutcome?, number?)
	local data = activeData(player, "purchaseItem")
	if data == nil then
		return nil, nil
	end
	local outcome: ProfileOperations.PurchaseOutcome, balance = ProfileOperations.purchaseItem(data, itemId, price)
	if outcome == "Bought" then
		print(string.format("[PlayerDataService] %s bought %s for %d coins: %d left", player.Name, itemId, price,
			balance :: number))
		coinsChanged(player, -price, balance :: number, reason)
	elseif outcome == "Rejected" then
		warn(string.format("[PlayerDataService] %s: buying %s for %s refused", player.Name, tostring(itemId), tostring(price)))
	end
	return outcome, balance
end

-- Every Shop item the player owns (sorted ids), or nil when the data is not loaded.
function PlayerDataService.getOwnedItems(player: Player): { string }?
	local data = activeData(player, "getOwnedItems")
	return if data then ProfileOperations.getOwnedItems(data) else nil
end

--[[
	Spends `amount` coins for `reason` (e.g. "Shop: Red Belt"). SERVER-ONLY:
	the price comes from config, never from a client. Returns the outcome
	("Spent", "NotEnough", "Rejected") and the balance; nil with no session.
]]
function PlayerDataService.spendCoins(player: Player, amount: number, reason: string): (ProfileOperations.CoinOutcome?, number?)
	local data = activeData(player, "spendCoins")
	if data == nil then
		return nil, nil
	end
	local outcome: ProfileOperations.CoinOutcome, balance = ProfileOperations.spendCoins(data, amount)
	if outcome == "Spent" then
		print(string.format("[PlayerDataService] %s -%d coins (%s): %d", player.Name, amount, reason, balance :: number))
		coinsChanged(player, -amount, balance :: number, reason)
	elseif outcome == "Rejected" then
		warn(string.format("[PlayerDataService] %s: spending %s coins refused (%s)", player.Name, tostring(amount), reason))
	end
	return outcome, balance
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

	So no kilogram writer exists. One operation reopens the door, owning its
	own bound:

	  1. awardTrainingProgression(player, lift, elapsedSeconds), below.
	     Takes observed station SECONDS -- never EV, never kilograms -- and
	     derives both on the server. Bounded by construction, so no caller can
	     get the magnitude wrong. Checkpoint 5B.5.

	  (A class-change translation was planned here and is no longer needed:
	  each class keeps its own build, section 29.11, user 2026-10-28.)

	It calls ProfileOperations.applyCompetitionNumberDelta, which keeps the
	validation that is universally true -- finite delta, known lift, a result
	that remains a positive weight -- and holds no magnitude opinion, because
	magnitude is the caller's to justify.
]]

--[[
	Applies `elapsedSeconds` of gym-station training on `lift`: debits the
	account's daily allowance and awards the Competition Number it paid for, in
	one synchronous write to the live profile.

	THE ONLY SOURCE OF COMPETITION NUMBER (section 34.2). SERVER-ONLY: there is
	no remote for it, and none may ever be added. The ONLY caller is the gym
	training station, TrainingStationService (checkpoint 5B.6).

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
	The meet CN allowance is never touched (decision A).
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
	Applies `elapsedSeconds` of rack technique training on `lift` with `primary`
	as the primary stat: raises that lift's raw technique stats (80/20, or 100%
	Lockout) in one synchronous write to the live profile. Checkpoint 5B.7.

	THE ONLY SOURCE OF RACK TECHNIQUE POINTS. SERVER-ONLY: there is no remote
	for it, and none may ever be added. The ONLY caller is the gym training
	rack, TrainingStationService.

	WHAT THE CALLER SUPPLIES, AND WHAT IT NEVER DOES
	  - `elapsedSeconds` is ACTIVE rack time the server itself observed, the
	    same measurement the CN award receives. Never offline time, never a
	    number a client reported.
	  - The caller never supplies points. The amount comes from
	    TechniqueTraining.rawPointsFor; the split from ProgressionConfig.

	NO EARNING CAP, NO CLOCK: technique has no daily allowance (5B.7), so this
	reads no time at all. CN, every allowance record, the per-lift CN hours,
	and Competition Scale are never touched.

	Returns the ProfileOperations.TechniqueResult, or nil when the player has
	no active session. A "Rejected" result wrote NOTHING.
]]
function PlayerDataService.awardTechniqueTraining(
	player: Player,
	lift: string,
	primary: string,
	elapsedSeconds: number
): ProfileOperations.TechniqueResult?
	local data = activeData(player, "awardTechniqueTraining")
	if data == nil then
		return nil
	end

	local result = ProfileOperations.applyTechniqueTraining(data, lift, primary, elapsedSeconds)

	if result.outcome == "Rejected" then
		warn(string.format(
			"[PlayerDataService] technique update for %s rejected: %s",
			player.Name,
			tostring(result.rejectionReason)
		))
	end

	return result
end

-- (Training Energy was retired in schema version 8, GAME_DESIGN 29.8, and the Competition Budget in version 10, 29.9.)

return PlayerDataService
