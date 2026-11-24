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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CelebrationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CelebrationConfig"))
local LoadoutConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LoadoutConfig"))
local BodyweightConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("BodyweightConfig"))
local KitchenConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("KitchenConfig"))
local LuckConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LuckConfig"))
local RankConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RankConfig"))
local MeetPlacing = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meet"):WaitForChild("MeetPlacing"))
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PlayerProfileSchema = require(script.Parent.PlayerProfileSchema)
local ProfileOperations = require(script.Parent.ProfileOperations)
local GainNews = require(script.Parent.GainNews)

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

	-- A suit test the server went down during: nothing stays on loan. Its wait still counts.
	ProfileOperations.endSuitTrial(profile.Data, false)

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
	Puts on (or, with itemId nil, takes off) the gear in `slot`
	(ProfileOperations.setWorn). SERVER-ONLY: the caller (GearService) checks
	the slot and that the item belongs in it. Returns the outcome; nil with no
	active session.
]]
function PlayerDataService.setWorn(player: Player, slot: string, itemId: string?): ProfileOperations.WearOutcome?
	local data = activeData(player, "setWorn")
	if data == nil then
		return nil
	end
	local outcome: ProfileOperations.WearOutcome = ProfileOperations.setWorn(data, slot, itemId)
	if outcome == "Rejected" then
		warn(string.format("[PlayerDataService] %s: wearing %s in %s refused", player.Name, tostring(itemId), tostring(slot)))
	end
	return outcome
end

--[[
	Opens a crate: takes `price` coins and adds `piece` in one step
	(ProfileOperations.openCrate). SERVER-ONLY: the price and the roll come from the
	server (GearStatsConfig, GearStats.roll), never from a client. Returns the outcome,
	the piece's id and the balance; nil with no active session.
]]
function PlayerDataService.openCrate(player: Player, price: number, piece: any, maxPieces: number)
	: (ProfileOperations.CrateOutcome?, string?, number?)
	local data = activeData(player, "openCrate")
	if data == nil then
		return nil, nil, nil
	end
	local outcome: ProfileOperations.CrateOutcome, id, balance = ProfileOperations.openCrate(data, price, piece, maxPieces)
	if outcome == "Opened" then
		print(string.format("[PlayerDataService] %s opened a crate for %d coins: piece %s, %s %s (%s): %d left", player.Name, price,
			tostring(id), tostring(piece.rarity), tostring(piece.slot), tostring(piece.look), balance :: number))
		coinsChanged(player, -price, balance :: number, "Gear crate")
	elseif outcome == "Rejected" then
		warn(string.format("[PlayerDataService] %s: a crate for %s refused", player.Name, tostring(price)))
	end
	return outcome, id, balance
end

--[[
	THE KITCHEN (GAME_DESIGN §40.7). The cooker and the steak boost; the clock is the server's, read here. The steak
	count is checked by ProfileOperations (KitchenConfig.isSteakCount); price and times come from KitchenConfig.
]]
function PlayerDataService.getKitchen(player: Player): ProfileOperations.KitchenView?
	local data = activeData(player, "getKitchen")
	return if data then ProfileOperations.getKitchen(data, os.time()) else nil
end

-- The chef scene was watched to the end once: from now on it can be skipped (GAME_DESIGN §40.7).
function PlayerDataService.markChefSceneSeen(player: Player): boolean
	local data = activeData(player, "markChefSceneSeen")
	return data ~= nil and ProfileOperations.markChefSceneSeen(data)
end

-- `kind`: "Steak" (nil) or "Meal" (meet meals, version 34); checked by ProfileOperations.
function PlayerDataService.startCook(player: Player, steaks: number, kind: string?, hours: number?)
	: (ProfileOperations.CookOutcome?, number?)
	local data = activeData(player, "startCook")
	if data == nil then
		return nil, nil
	end
	local outcome: ProfileOperations.CookOutcome, balance = ProfileOperations.startCook(data, steaks, os.time(), kind, hours)
	local what = if kind == "Meal" then "meet meals" else "steaks"
	if outcome == "Started" then
		local price = KitchenConfig.cost(steaks, kind, hours)
		print(string.format("[PlayerDataService] %s put %d %s in the cooker for %s h, %d coins: %d left", player.Name, steaks,
			what, tostring(hours or KitchenConfig.BoostHours), price, balance :: number))
		coinsChanged(player, -price, balance :: number, if kind == "Meal" then "Meet meals" else "Steaks")
	elseif outcome == "Rejected" then
		warn(string.format("[PlayerDataService] %s: cooking %s %s refused", player.Name, tostring(steaks), what))
	end
	return outcome, balance
end

-- Eats whatever is cooked (steaks or meet meals). Returns the outcome, the boost's percent and the kind.
function PlayerDataService.eatSteak(player: Player): (ProfileOperations.EatOutcome?, number?, string?)
	local data = activeData(player, "eatSteak")
	if data == nil then
		return nil, nil, nil
	end
	local outcome: ProfileOperations.EatOutcome, percent, kind = ProfileOperations.eatSteak(data, os.time())
	if outcome == "Eaten" then
		local view = ProfileOperations.getKitchen(data, os.time())
		print(string.format("[PlayerDataService] %s ate a %s: +%.1f%% %s, %.2f h left", player.Name,
			if kind == "Meal" then "meet meal" else "steak meal", percent :: number,
			if kind == "Meal" then "meet gains" else "training",
			(if kind == "Meal" then view.mealLeft else view.boostLeft) / 3600))
	end
	return outcome, percent, kind
end

--[[
	THE INVENTORY'S ITEMS (GAME_DESIGN §42): food collected from the chef, medals and trophies.
]]
function PlayerDataService.getInventory(player: Player): { items: { [string]: ProfileOperations.Item } }?
	local data = activeData(player, "getInventory")
	return if data then { items = ProfileOperations.getItems(data) } else nil
end

-- The finished cook, from the chef into the inventory. Returns the outcome and the item's id.
function PlayerDataService.collectFood(player: Player): (ProfileOperations.CollectOutcome?, string?)
	local data = activeData(player, "collectFood")
	if data == nil then
		return nil, nil
	end
	local outcome: ProfileOperations.CollectOutcome, id = ProfileOperations.collectFood(data, os.time())
	if outcome == "Collected" then
		local item = ProfileOperations.getItems(data)[id :: string]
		print(string.format("[PlayerDataService] %s collected their food: item %s (%s %s x%d, %s h)", player.Name, tostring(id),
			tostring(item and item.count), tostring(item and item.food), item and item.qty or 0, tostring(item and item.hours)))
	end
	return outcome, id
end

-- Eats one of an inventory food item. Returns the outcome, the boost's percent and the food kind.
function PlayerDataService.useItem(player: Player, id: string): (ProfileOperations.UseOutcome?, number?, string?)
	local data = activeData(player, "useItem")
	if data == nil then
		return nil, nil, nil
	end
	local outcome: ProfileOperations.UseOutcome, percent, kind = ProfileOperations.useItem(data, id, os.time())
	if outcome == "Eaten" then
		print(string.format("[PlayerDataService] %s ate item %s: +%.1f%% %s", player.Name, id, percent :: number,
			if kind == "Meal" then "meet gains" else "training"))
	end
	return outcome, percent, kind
end

-- ADMIN / MEETS: gives a medal or trophy (Stage 4). Returns its id.
function PlayerDataService.addAward(player: Player, kind: string, level: string, place: number): string?
	local data = activeData(player, "addAward")
	return if data then ProfileOperations.addAward(data, kind, level, place) else nil
end

-- LUCK (GAME_DESIGN §40.7): the cow's wheel. Each is ProfileOperations' operation on the player's active profile.
function PlayerDataService.getLuck(player: Player): ProfileOperations.LuckView?
	local data = activeData(player, "getLuck")
	return if data then ProfileOperations.getLuck(data, os.time()) else nil
end

-- The player's luck multiplier right now (1 with no luck or no loaded profile). For every roll that luck touches.
function PlayerDataService.luckMultiplier(player: Player): number
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return 1
	end
	return ProfileOperations.luckMultiplier(profile.Data, os.time())
end

function PlayerDataService.spinLuckWheel(player: Player, wedge: number, rolled: number): (ProfileOperations.SpinOutcome?, number?, boolean?)
	local data = activeData(player, "spinLuckWheel")
	if data == nil then
		return nil, nil, nil
	end
	local outcome: ProfileOperations.SpinOutcome, multiplier, free = ProfileOperations.spinLuckWheel(data, wedge, rolled, os.time())
	if outcome == "Spun" then
		print(string.format("[PlayerDataService] %s spun the luck wheel (%s): luck %sx for %d h", player.Name,
			if free then "free daily spin" else "a won spin", tostring(multiplier), LuckConfig.hoursFor(multiplier or 1)))
	end
	return outcome, multiplier, free
end

function PlayerDataService.startCowGame(player: Player): ProfileOperations.GameOutcome?
	local data = activeData(player, "startCowGame")
	return if data then ProfileOperations.startCowGame(data, os.time()) else nil
end

-- A spin for beating the cow (capped) or a bought one (never capped). Returns the spins waiting, or nil.
function PlayerDataService.addLuckSpins(player: Player, count: number, capped: boolean): number?
	local data = activeData(player, "addLuckSpins")
	return if data then ProfileOperations.addLuckSpins(data, count, capped) else nil
end

--[[
	Adds a free piece (ProfileOperations.grantPiece). SERVER-ONLY: a rare suit a meet dropped or the admin panel gave, chosen on
	the server. Returns its id; nil with no active session or a bad piece.
]]
function PlayerDataService.grantPiece(player: Player, piece: any): string?
	local data = activeData(player, "grantPiece")
	if data == nil then
		return nil
	end
	local id = ProfileOperations.grantPiece(data, piece)
	if id then
		print(string.format("[PlayerDataService] %s was given piece %s: %s (%s)", player.Name, id, tostring(piece.rarity), tostring(piece.look)))
	end
	return id
end

-- The coach's tests for rare suits (ProfileOperations). SERVER-ONLY; MockMeetService runs them, and only the server decides a result.
function PlayerDataService.getSuitTests(player: Player): { [string]: { passed: boolean?, nextTryAt: number? } }?
	local data = activeData(player, "getSuitTests")
	return if data then ProfileOperations.getSuitTests(data) else nil
end

function PlayerDataService.startSuitTrial(player: Player, suitId: string, pieceId: string, waitSeconds: number): (ProfileOperations.SuitTrialOutcome?, number?)
	local data = activeData(player, "startSuitTrial")
	if data == nil then
		return nil, nil
	end
	return ProfileOperations.startSuitTrial(data, suitId, pieceId, os.time(), waitSeconds)
end

function PlayerDataService.endSuitTrial(player: Player, passed: boolean)
	local data = activeData(player, "endSuitTrial")
	if data then
		ProfileOperations.endSuitTrial(data, passed)
		print(string.format("[PlayerDataService] %s's suit test ended: %s", player.Name, if passed then "passed" else "not passed"))
	end
end

function PlayerDataService.resetSuitTests(player: Player, isSuit: (string) -> boolean)
	local data = activeData(player, "resetSuitTests")
	if data then
		ProfileOperations.resetSuitTests(data, isSuit)
	end
end

--[[
	Scraps a piece for `value` coins (ProfileOperations.scrapPiece). SERVER-ONLY: the value
	comes from GearStatsConfig. Returns the outcome and the balance; nil with no session.
]]
function PlayerDataService.scrapPiece(player: Player, pieceId: string, value: number): (ProfileOperations.ScrapOutcome?, number?)
	local data = activeData(player, "scrapPiece")
	if data == nil then
		return nil, nil
	end
	local outcome: ProfileOperations.ScrapOutcome, balance = ProfileOperations.scrapPiece(data, pieceId, value)
	if outcome == "Scrapped" then
		print(string.format("[PlayerDataService] %s scrapped piece %s for %d coins: %d", player.Name, pieceId, value, balance :: number))
		coinsChanged(player, value, balance :: number, "Scrapped gear")
	elseif outcome == "Rejected" then
		warn(string.format("[PlayerDataService] %s: scrapping %s refused", player.Name, tostring(pieceId)))
	end
	return outcome, balance
end

-- Puts a stat piece on (ProfileOperations.setWornPiece). Returns the outcome; nil with no active session.
function PlayerDataService.setWornPiece(player: Player, pieceId: string): ProfileOperations.WearOutcome?
	local data = activeData(player, "setWornPiece")
	return if data then ProfileOperations.setWornPiece(data, pieceId) else nil
end

-- The player's stat pieces (id -> piece), or nil when the data is not loaded.
function PlayerDataService.getPieces(player: Player): { [string]: any }?
	local data = activeData(player, "getPieces")
	return if data then ProfileOperations.getPieces(data) else nil
end

-- Which stat piece is worn in each slot (slot -> piece id), or nil when the data is not loaded.
function PlayerDataService.getWornPieces(player: Player): { [string]: string }?
	local data = activeData(player, "getWornPieces")
	return if data then ProfileOperations.getWornPieces(data) else nil
end

-- What the player wears (slot -> the item id whose look shows), or nil when the data is not loaded.
function PlayerDataService.getWorn(player: Player): { [string]: string }?
	local data = activeData(player, "getWorn")
	return if data then ProfileOperations.getWorn(data) else nil
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

-- Called after training moved a player's bodyweight (GAME_DESIGN §38.3): the STATS service tells them about a new class
-- or a reached goal.
local bodyweightListeners: { (Player, ProfileOperations.BodyweightChange) -> () } = {}
function PlayerDataService.onBodyweightChanged(listener: (Player, ProfileOperations.BodyweightChange) -> ())
	table.insert(bodyweightListeners, listener)
end

--[[
	Sets the player's weight goal (GAME_DESIGN §38.3): BodyweightConfig.Maintain or a weight class label, already
	type-checked by the caller (PlayerStatsService, from the STATS screen's request). See ProfileOperations.setWeightGoal.
]]
function PlayerDataService.setWeightGoal(player: Player, goal: string, confirmed: boolean): (ProfileOperations.WeightGoalOutcome, string, number?)
	local data = activeData(player, "setWeightGoal")
	if data == nil then
		return "Rejected", "Your save hasn't loaded yet.", nil
	end
	return ProfileOperations.setWeightGoal(data, goal, confirmed, os.time())
end

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

	-- The gain display (GAME_DESIGN §40.1): what this award really added.
	if result.outcome == "Awarded" and result.deltaCN > 0 then
		GainNews.send(player, "Training", { GainNews.strength(lift, result.deltaCN) })
	end

	-- Gaining or losing weight toward the lifter's goal (GAME_DESIGN §38.3): only with EV this award really granted.
	if result.outcome == "Awarded" and result.earnedEV > 0 then
		local speed = 1
		if RunService:IsStudio() then
			local studio = Workspace:GetAttribute(BodyweightConfig.StudioSpeedAttribute)
			if typeof(studio) == "number" and studio > 0 and studio < math.huge then
				speed = studio
			end
		end
		local change = ProfileOperations.applyBodyweightChange(data, result.earnedEV, speed)
		if change then
			for _, listener in ipairs(bodyweightListeners) do
				task.spawn(listener, player, change)
			end
		end
	end

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

	-- The clock only decides whether a gain boost (a steak, §40.7) is still running.
	local result = ProfileOperations.applyTechniqueTraining(data, lift, primary, elapsedSeconds, os.time())

	-- The gain display (GAME_DESIGN §40.1): each stat this award raised, as its effective value moved.
	if result.outcome == "Awarded" then
		local gains = {}
		for _, gain in ipairs(result.gains) do
			local after = result.after[gain.stat]
			local shown = if typeof(after) == "number" then GainNews.technique(gain.stat, result.lift, after - gain.raw, after) else nil
			if shown then
				table.insert(gains, shown)
			end
		end
		GainNews.send(player, "Training", gains)
	end

	if result.outcome == "Rejected" then
		warn(string.format(
			"[PlayerDataService] technique update for %s rejected: %s",
			player.Name,
			tostring(result.rejectionReason)
		))
	end

	return result
end

--[[
	The admin panel's PLAYER STATS page (ProfileOperations ADMIN). SERVER-ONLY: the
	caller (AdminService) checks the admin list on every call; the clock is read here.
]]
function PlayerDataService.adminSetStat(player: Player, fieldId: string, value: number): (boolean, string)
	local data = activeData(player, "adminSetStat")
	if data == nil then
		return false, "That player's save hasn't loaded."
	end
	return ProfileOperations.adminSetStat(data, fieldId, value, os.time())
end

function PlayerDataService.adminQualifyForState(player: Player): (boolean, string)
	local data = activeData(player, "adminQualifyForState")
	if data == nil then
		return false, "That player's save hasn't loaded."
	end
	return ProfileOperations.adminQualifyForState(data, os.time())
end

function PlayerDataService.adminRefillDaily(player: Player): (boolean, string)
	local data = activeData(player, "adminRefillDaily")
	if data == nil then
		return false, "That player's save hasn't loaded."
	end
	return ProfileOperations.adminRefillDaily(data)
end

-- ADMIN PANEL: SKIP ALL COOLDOWNS on `player`'s save (ProfileOperations.adminSkipCooldowns). Returns what was skipped.
function PlayerDataService.adminSkipCooldowns(player: Player): (boolean, { string })
	local data = activeData(player, "adminSkipCooldowns")
	if data == nil then
		return false, {}
	end
	return true, ProfileOperations.adminSkipCooldowns(data, os.time())
end

--[[
	RANKS AND TITLES (GAME_DESIGN §41). The meet records the rank inside its own save (ProfileOperations.recordRankMeet in
	LocalMeetService's write); these are the rest. SERVER-ONLY callers (RankService) check every request first.
]]
function PlayerDataService.getRanks(player: Player): ProfileOperations.RankView?
	local data = activeData(player, "getRanks")
	return if data then ProfileOperations.getRanks(data, os.time()) else nil
end

-- Pays every rank reached but not yet paid (coins, free crates, the new-name luck boost). Nil with no session.
function PlayerDataService.claimRankRewards(player: Player, upTo: number?): ProfileOperations.RankRewards?
	local data = activeData(player, "claimRankRewards")
	if data == nil then
		return nil
	end
	local paid = ProfileOperations.claimRankRewards(data, os.time(), upTo)
	if paid and #paid.ranks > 0 then
		print(string.format("[PlayerDataService] %s claimed ranks %d..%d: %d coins, %d crates%s%s", player.Name, paid.ranks[1],
			paid.ranks[#paid.ranks], paid.coins, paid.crates, if paid.luckBoost then ", luck boost" else "",
			if paid.coinsRefused then " (coins refused: wallet full)" else ""))
		if paid.coins > 0 and paid.balance then
			coinsChanged(player, paid.coins, paid.balance, "Rank up")
		end
	end
	return paid
end

function PlayerDataService.openFreeCrate(player: Player, piece: any, maxPieces: number)
	: (ProfileOperations.FreeCrateOutcome?, string?, number?)
	local data = activeData(player, "openFreeCrate")
	if data == nil then
		return nil, nil, nil
	end
	local outcome: ProfileOperations.FreeCrateOutcome, id, left = ProfileOperations.useFreeCrate(data, piece, maxPieces)
	if outcome == "Opened" then
		print(string.format("[PlayerDataService] %s opened a free rank crate: piece %s, %s %s (%s): %d free left", player.Name,
			tostring(id), tostring(piece.rarity), tostring(piece.slot), tostring(piece.look), left :: number))
	end
	return outcome, id, left
end

function PlayerDataService.setTitle(player: Player, id: string): boolean
	local data = activeData(player, "setTitle")
	return if data then ProfileOperations.setTitle(data, id) else false
end

--[[
	ADMIN PANEL: RANK UP. Records a made-up meet total worth exactly the next rank's GL points at the player's bodyweight,
	through the same recordRankMeet a real meet uses (so the moment, the rewards and the tag all behave as in a meet).
	Returns the result and the points, or nil.
]]
function PlayerDataService.adminRankUp(player: Player): (ProfileOperations.RankMeetResult?, number?)
	local data = activeData(player, "adminRankUp")
	if data == nil then
		return nil, nil
	end
	local rank = ProfileOperations.getRank(data)
	local nextRank = RankConfig.Ranks[rank + 1]
	if nextRank == nil then
		return nil, nil
	end
	local bodyweight = (data :: any).bodyweight and (data :: any).bodyweight.currentKg or 80
	local points = math.max(nextRank.points, RankConfig.Ranks[2].points - 0.5) + 0.01
	local totalKg = MeetPlacing.totalForPoints(bodyweight, points)
	local result = ProfileOperations.recordRankMeet(data, {
		points = points, totalKg = totalKg, bodyweightKg = bodyweight, classLabel = "admin", bestByLift = {},
		perfect = false, clutch = false, gymRecord = false,
	}, os.time())
	return result, points
end

-- ADMIN PANEL: gives title `id` (a feat into the ranks record, a meet title into career.titles). Returns whether it was
-- new, or nil for no save / an unknown title.
function PlayerDataService.adminGiveTitle(player: Player, id: string): boolean?
	local data = activeData(player, "adminGiveTitle")
	if data == nil or RankConfig.TitleById[id] == nil then
		return nil
	end
	if RankConfig.isFeat(id) then
		local ranks = (data :: any).ranks
		if typeof(ranks) ~= "table" or typeof(ranks.feats) ~= "table" then
			return nil
		end
		if ranks.feats[id] ~= nil then
			return false
		end
		ranks.feats[id] = os.time()
		return true
	end
	return ProfileOperations.addTitle(data, id) == 1
end

-- ADMIN PANEL: RESET RANK (ProfileOperations.adminResetRank). False with no save.
function PlayerDataService.adminResetRank(player: Player): boolean
	local data = activeData(player, "adminResetRank")
	return data ~= nil and ProfileOperations.adminResetRank(data)
end

function PlayerDataService.markTitlesSeen(player: Player): boolean
	local data = activeData(player, "markTitlesSeen")
	return if data then ProfileOperations.markTitlesSeen(data, os.time()) else false
end

function PlayerDataService.adminGiveEntrance(player: Player, id: string): (boolean, string)
	local data = activeData(player, "adminGiveEntrance")
	if data == nil then
		return false, "That player's save hasn't loaded."
	end
	return ProfileOperations.adminGiveEntrance(data, id)
end

-- The entrance (walk-out) a player uses at meets on `attempt` (1 to 3, nil the 1st; EntranceConfig id); the Default
-- when their save isn't loaded.
function PlayerDataService.getEntrance(player: Player, attempt: number?): string
	local data = PlayerDataService.getData(player)
	return if data then ProfileOperations.getEntrance(data, attempt) else "Default"
end

export type LoadoutView = {
	-- Per kind ("Entrance", "Celebration", "Fail"): every one they own (the Default first) and their three slots.
	owned: { [string]: { string } },
	slots: { [string]: { string } },
	-- The emotes they can play (free ones included).
	emotes: { string },
}

-- Everything for the emote wheel's pages (LoadoutConfig); nil when their save isn't loaded. Read only.
function PlayerDataService.getLoadout(player: Player): LoadoutView?
	local data = PlayerDataService.getData(player)
	if data == nil then
		return nil
	end
	local view: LoadoutView = { owned = {}, slots = {}, emotes = ProfileOperations.getEmotes(data) }
	for _, kind in ipairs(LoadoutConfig.Kinds) do
		view.owned[kind] = ProfileOperations.getOwnedLoadout(data, kind)
		view.slots[kind] = ProfileOperations.getLoadoutSlots(data, kind)
	end
	return view
end

-- What they wear over the lifter body, every kind filled in (ProfileOperations.getOutfit), or nil before the data loads.
function PlayerDataService.getOutfit(player: Player): { [string]: { item: string, colour: string } }?
	local data = activeData(player, "getOutfit")
	return if data then ProfileOperations.getOutfit(data) else nil
end

-- Puts on one piece of clothing (ProfileOperations.setOutfitPiece checks the kind, the item, ownership and colour).
function PlayerDataService.setOutfitPiece(player: Player, kind: string, itemId: string, colourId: string): (boolean, string)
	local data = activeData(player, "setOutfitPiece")
	if data == nil then
		return false, "Your save hasn't loaded yet."
	end
	return ProfileOperations.setOutfitPiece(data, kind, itemId, colourId)
end

-- The gear toggle (true = gear on), or nil before the data loads.
function PlayerDataService.getGearOn(player: Player): boolean?
	local data = activeData(player, "getGearOn")
	return if data then ProfileOperations.getGearOn(data) else nil
end

function PlayerDataService.setGearOn(player: Player, on: boolean): boolean
	local data = activeData(player, "setGearOn")
	return data ~= nil and ProfileOperations.setGearOn(data, on)
end

-- Puts one they own in one of their attempt slots (ProfileOperations.setLoadoutSlot checks everything).
function PlayerDataService.setLoadoutSlot(player: Player, kind: string, slot: number, id: string): (boolean, string)
	local data = activeData(player, "setLoadoutSlot")
	if data == nil then
		return false, "Your save hasn't loaded yet."
	end
	return ProfileOperations.setLoadoutSlot(data, kind, slot, id)
end

--[[
	One celebration spin (ProfileOperations.spinCelebration): takes `price` coins, makes `resultId` theirs, and gives
	`refund` back when it already was. SERVER-ONLY: CelebrationSpinService chose the price, the refund and the roll.
	Returns the outcome, the balance and the coins given back; nil with no active session.
]]
function PlayerDataService.spinCelebration(player: Player, price: number, resultId: string, refund: number)
	: (ProfileOperations.SpinOutcome?, number?, number)
	local data = activeData(player, "spinCelebration")
	if data == nil then
		return nil, nil, 0
	end
	local outcome, balance, given = ProfileOperations.spinCelebration(data, price, resultId, refund)
	if outcome == "Spun" then
		print(string.format("[PlayerDataService] %s spun a celebration for %d coins: %s%s, %d left", player.Name, price,
			resultId, if given > 0 then string.format(" (already theirs: %d back)", given) else "", balance :: number))
		coinsChanged(player, given - price, balance :: number, "Celebration spin")
	elseif outcome == "Rejected" then
		warn(string.format("[PlayerDataService] %s: a celebration spin (%s, %s) refused", player.Name, tostring(price),
			tostring(resultId)))
	end
	return outcome, balance, given
end

-- One walk-out spin (ProfileOperations.spinEntrance). SERVER-ONLY: CelebrationSpinService chose everything.
function PlayerDataService.spinEntrance(player: Player, price: number, resultId: string, refund: number)
	: (ProfileOperations.SpinOutcome?, number?, number)
	local data = activeData(player, "spinEntrance")
	if data == nil then
		return nil, nil, 0
	end
	local outcome, balance, given = ProfileOperations.spinEntrance(data, price, resultId, refund)
	if outcome == "Spun" then
		print(string.format("[PlayerDataService] %s spun a walk-out for %d coins: %s%s, %d left", player.Name, price,
			resultId, if given > 0 then string.format(" (already theirs: %d back)", given) else "", balance :: number))
		coinsChanged(player, given - price, balance :: number, "Walk-out spin")
	elseif outcome == "Rejected" then
		warn(string.format("[PlayerDataService] %s: a walk-out spin (%s, %s) refused", player.Name, tostring(price),
			tostring(resultId)))
	end
	return outcome, balance, given
end

-- One fail-style or emote spin (ProfileOperations.spinFailStyle / spinEmote). SERVER-ONLY: CelebrationSpinService chose
-- everything. `what` names it in the log and the coin message.
local function spinWith(player: Player, what: string, spinOf: any, price: number, resultId: string, refund: number)
	: (ProfileOperations.SpinOutcome?, number?, number)
	local data = activeData(player, "spin " .. what)
	if data == nil then
		return nil, nil, 0
	end
	local outcome, balance, given = spinOf(data, price, resultId, refund)
	if outcome == "Spun" then
		print(string.format("[PlayerDataService] %s spun %s %s for %d coins: %s%s, %d left", player.Name,
			if what == "Emote" then "an" else "a", string.lower(what),
			price, resultId, if given > 0 then string.format(" (already theirs: %d back)", given) else "", balance :: number))
		coinsChanged(player, given - price, balance :: number, what .. " spin")
	elseif outcome == "Rejected" then
		warn(string.format("[PlayerDataService] %s: a %s spin (%s, %s) refused", player.Name, string.lower(what),
			tostring(price), tostring(resultId)))
	end
	return outcome, balance, given
end

function PlayerDataService.spinFailStyle(player: Player, price: number, resultId: string, refund: number)
	: (ProfileOperations.SpinOutcome?, number?, number)
	return spinWith(player, "Fail style", ProfileOperations.spinFailStyle, price, resultId, refund)
end

function PlayerDataService.spinEmote(player: Player, price: number, resultId: string, refund: number)
	: (ProfileOperations.SpinOutcome?, number?, number)
	return spinWith(player, "Emote", ProfileOperations.spinEmote, price, resultId, refund)
end

-- A player's fail style on `attempt` (1 to 3, nil the 1st; StationAnimationConfig.FailStyles id or "Default");
-- "Default" when their save isn't loaded.
function PlayerDataService.getFailStyle(player: Player, attempt: number?): string
	local data = PlayerDataService.getData(player)
	return if data then ProfileOperations.getFailStyle(data, attempt) else "Default"
end

-- The emotes a player can play (free ones included); just the free ones when their save isn't loaded.
function PlayerDataService.getEmotes(player: Player): { string }
	local data = PlayerDataService.getData(player)
	if data then
		return ProfileOperations.getEmotes(data)
	end
	return { "Wave", "ChalkClap" }
end

function PlayerDataService.ownsEmote(player: Player, id: string): boolean
	local data = PlayerDataService.getData(player)
	return data ~= nil and ProfileOperations.ownsEmote(data, id)
end

function PlayerDataService.adminSetCelebration(player: Player, id: string): (boolean, string)
	local data = activeData(player, "adminSetCelebration")
	if data == nil then
		return false, "That player's save hasn't loaded."
	end
	return ProfileOperations.adminSetCelebration(data, id)
end

-- The celebration a player does after a good lift on `attempt` (1 to 3, nil the 1st; CelebrationConfig id); the Default
-- when their save isn't loaded.
function PlayerDataService.getCelebration(player: Player, attempt: number?): string
	local data = PlayerDataService.getData(player)
	return if data then ProfileOperations.getCelebration(data, attempt) else CelebrationConfig.Default
end

-- (Training Energy was retired in schema version 8, GAME_DESIGN 29.8, and the Competition Budget in version 10, 29.9.)

return PlayerDataService
