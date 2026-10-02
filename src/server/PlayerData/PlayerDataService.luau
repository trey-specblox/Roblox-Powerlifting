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
			print(data.forecasted.Squat)
		end

		PlayerDataService.update(player, function(data)
			data.forecasted.Squat += 2.5
		end)

	Reading returns the live table for speed, and callers must treat it as
	READ-ONLY. All writes go through update, which refuses to run when the session
	is not active, so a write can never be silently dropped into a table that is no
	longer being saved.

	SERVER AUTHORITY

	This module is in ServerScriptService and is unreachable from the client. It
	creates no RemoteEvents and no RemoteFunctions, so right now there is no path
	by which a client can read or write persistent data at all. When replication is
	added later, it must send derived values the client needs for display, and must
	never accept a value from the client as truth.
]]

local Players = game:GetService("Players")

local PlayerProfileSchema = require(script.Parent.PlayerProfileSchema)

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
		profile.Data.forecasted.Squat,
		profile.Data.forecasted.Bench,
		profile.Data.forecasted.Deadlift,
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

return PlayerDataService
