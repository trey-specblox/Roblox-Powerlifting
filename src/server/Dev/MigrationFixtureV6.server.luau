--!strict
--[[
	MigrationFixtureV6
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Proves the version 5 -> 6 migration (weight-class
	builds, GAME_DESIGN.md 29.11) against the REAL DataStore, on a throwaway key.
	Since version 7 the same load also runs the 6 -> 7 step, which removes
	PullStrength (GAME_DESIGN 34.14, checkpoint 9), and since version 8 the
	7 -> 8 step, which removes Training Energy (GAME_DESIGN 29.8); it checks both.

	Three real ProfileStore sessions on one disposable key in the "PlayerData"
	store, then the key is deleted:

	  1  SEED     write a genuine version-5 record (flat Competition Number and
	              Scale, no `builds`), save and release
	  2  MIGRATE  load in production order (detectVersion BEFORE Reconcile),
	              migrate, check every rule, then raise a Scale and a best Total
	              through the real meet operations, save and release
	  3  RELOAD   load again: version 8 persisted, a re-run migrate changes
	              nothing, the "83 kg" key and the zero Scales survived JSON
	  -  CLEANUP  RemoveAsync deletes the key

	The key is NOT derived from any UserId, so no player's save is touched.
	Needs Studio API access ON (otherwise ProfileStore uses an in-memory mock
	and the test would prove nothing), and PlayerDataService switched off for
	the run (START_PLAYER_DATA_SERVICE in init.server.luau) so the tester's own
	save is not upgraded before this passes.

	OFF BY DEFAULT. Set ENABLED to true, press Play, read the Output, set it back.
]]

local ENABLED = false

if not ENABLED then
	return
end

local DataStoreService = game:GetService("DataStoreService")

local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerProfileSchema = require(PlayerDataFolder:WaitForChild("PlayerProfileSchema"))
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))
local ProfileStoreModule = require(script.Parent.Parent.Packages.ProfileStore) :: any

local STORE_NAME = "PlayerData"
local KEY = "MIGRATION_FIXTURE_V5_TO_V6_DO_NOT_USE"
local CLASS = "83 kg"

local passed = 0
local failed = 0

local function check(label: string, condition: any, detail: any?)
	if condition then
		passed += 1
		print("  PASS  " .. label)
	else
		failed += 1
		warn("  FAIL  " .. label .. (if detail ~= nil then "  -- " .. tostring(detail) else ""))
	end
end

local function countKeys(t: any): number
	local n = 0
	if typeof(t) == "table" then
		for _ in pairs(t) do
			n += 1
		end
	end
	return n
end

print("=== v5 to v6 migration fixture, REAL DataStore, disposable key ===")
print("  store : " .. STORE_NAME)
print("  key   : " .. KEY)
print("  schema: CURRENT_VERSION = " .. PlayerProfileSchema.CURRENT_VERSION)

-- Refuse to run against the mock: a round trip that never reaches a DataStore proves nothing.
local apiOk = pcall(function()
	DataStoreService:GetDataStore("__MigrationFixtureProbe"):GetAsync("x")
end)
if not apiOk then
	warn("[MigrationFixtureV6] ABORTED: Studio API access is OFF. Game Settings > Security > Enable Studio Access to API Services. No DataStore call was made.")
	return
end

local store = ProfileStoreModule.New(STORE_NAME, PlayerProfileSchema.template)

-- Starts a session, runs `body` on the profile, saves and releases, and waits until the lock is clear.
local function session(name: string, body: (any) -> ()): boolean
	local profile = store:StartSessionAsync(KEY)
	if profile == nil then
		warn("[MigrationFixtureV6] ABORTED: could not start session " .. name)
		return false
	end
	local ended = false
	profile.OnSessionEnd:Connect(function()
		ended = true
	end)
	local ok, err = pcall(body :: any, profile)
	if not ok then
		failed += 1
		warn("  FAIL  " .. name .. " errored: " .. tostring(err))
	end
	profile:EndSession()
	local deadline = os.clock() + 30
	while not ended and os.clock() < deadline do
		task.wait(0.1)
	end
	task.wait(1)
	return ok
end

print("")
print("SESSION 1. write a genuine version-5 record")
session("seed", function(profile)
	local data = profile.Data
	for key in pairs(data) do
		data[key] = nil
	end
	data.version = 5
	data.competitionNumber = { Squat = 182.5, Bench = 117.25, Deadlift = 215.0 }
	data.competitionScale = { Squat = 177.5, Bench = 0, Deadlift = 0 }
	data.technique = {
		SquatControl = 1550, DepthAwareness = 975, StartControl = 525,
		PressPower = 2350, PullStrength = 410, Lockout = 128.5,
	}
	data.bodyweight = { currentKg = 82.4, targetKg = 93 }
	data.competitionBudget = {
		Squat = { amount = 2.75, lastUpdatedUnix = 1761600000 },
		Bench = { amount = 9.43, lastUpdatedUnix = 0 },
		Deadlift = { amount = 9.43, lastUpdatedUnix = 0 },
	}
	data.trainingEnergy = { amount = 61, lastUpdatedUnix = 1761600000 }
	data.cnAllowance = { spentToday = 2.8109, dayKey = "2026-10-27", lastUpdatedUnix = 1761600000 }
	data.techniqueAllowance = { spentToday = 0, dayKey = "2026-10-27", lastUpdatedUnix = 1761600000 }
	data.trainingTimeToday = { Squat = 1.5, Bench = 0, Deadlift = 0.25, dayKey = "2026-10-27", lastUpdatedUnix = 1761600000 }
	data.meta = { createdUnix = 1700000000, lastSessionUnix = 1761600000, sessionCount = 103 }
	check("seeded a v5 record with no builds", data.builds == nil and data.version == 5)
end)

print("")
print("SESSION 2. load, migrate, and verify every rule")
session("migrate", function(profile)
	local data = profile.Data
	local fromVersion = PlayerProfileSchema.detectVersion(data)
	check("detectVersion reads 5 BEFORE Reconcile", fromVersion == 5, fromVersion)
	check("the saved record really has no builds", data.builds == nil)
	check("the flat CN came back from the DataStore", typeof(data.competitionNumber) == "table"
		and data.competitionNumber.Bench == 117.25)

	profile:Reconcile()
	check("Reconcile added an EMPTY builds map (no phantom build)", typeof(data.builds) == "table"
		and countKeys(data.builds) == 0, countKeys(data.builds))

	local finalVersion = PlayerProfileSchema.migrate(data, fromVersion)
	local build = data.builds[CLASS]
	check("migrated to version 8", finalVersion == 8 and data.version == 8, finalVersion)
	check("one build, filed under 83 kg", typeof(build) == "table" and countKeys(data.builds) == 1, countKeys(data.builds))
	check("CN moved exactly", build and build.competitionNumber.Squat == 182.5
		and build.competitionNumber.Bench == 117.25 and build.competitionNumber.Deadlift == 215.0)
	check("Scale moved exactly", build and build.competitionScale.Squat == 177.5
		and build.competitionScale.Bench == 0 and build.competitionScale.Deadlift == 0)
	check("best Total starts at none", build and build.bestTotalKg == 0)
	check("flat fields removed", data.competitionNumber == nil and data.competitionScale == nil)
	check("technique kept, PullStrength removed", data.technique.Lockout == 128.5 and data.technique.PullStrength == nil)
	check("budget untouched", data.competitionBudget.Squat.amount == 2.75
		and data.competitionBudget.Squat.lastUpdatedUnix == 1761600000)
	check("Training Energy removed", data.trainingEnergy == nil)
	check("daily counters untouched", data.cnAllowance.spentToday == 2.8109
		and data.trainingTimeToday.Squat == 1.5 and data.trainingTimeToday.dayKey == "2026-10-27")
	check("bodyweight and meta untouched", data.bodyweight.currentKg == 82.4 and data.meta.sessionCount == 103)

	-- What a Mock Meet does, through the same operations it uses.
	local raised = ProfileOperations.raiseCompetitionScale(data, CLASS, "Bench", 120.0)
	local total = ProfileOperations.raiseBestTotal(data, CLASS, 517.5)
	check("a meet-style Scale raise is Raised", raised == "Raised", raised)
	check("a meet-style best Total raise is Raised", total == "Raised", total)
end)

print("")
print("SESSION 3. reload and confirm version 8 persisted")
session("reload", function(profile)
	local data = profile.Data
	local fromVersion = PlayerProfileSchema.detectVersion(data)
	check("detectVersion reads 8", fromVersion == 8, fromVersion)
	profile:Reconcile()
	local finalVersion = PlayerProfileSchema.migrate(data, fromVersion)
	local build = data.builds[CLASS]
	check("still version 8, nothing re-migrated", finalVersion == 8)
	check("the \"83 kg\" key survived JSON, still one build", typeof(build) == "table" and countKeys(data.builds) == 1)
	check("CN survived two round trips", build and build.competitionNumber.Squat == 182.5
		and build.competitionNumber.Bench == 117.25)
	check("the raised Bench Scale 120 survived", build and build.competitionScale.Bench == 120.0)
	check("the moved Squat Scale 177.5 survived", build and build.competitionScale.Squat == 177.5)
	check("the unproven Deadlift survived as 0, not nil", build and build.competitionScale.Deadlift == 0)
	check("the best Total 517.5 survived", build and build.bestTotalKg == 517.5)
	check("no flat field came back", data.competitionNumber == nil and data.competitionScale == nil)
	check("daily counters survived", data.cnAllowance.spentToday == 2.8109)
	check("readers see the build", ProfileOperations.getCompetitionNumber(data, "Deadlift") == 215.0
		and ProfileOperations.getCompetitionScale(data, "Bench") == 120.0)
end)

print("")
print("CLEANUP. delete the disposable key")
local removed = store:RemoveAsync(KEY)
check("disposable key deleted", removed == true, removed)

print("")
print(string.format("=== MIGRATION FIXTURE: %d passed, %d failed ===", passed, failed))
if failed == 0 then
	print("[MigrationFixtureV6] Migration verified against a real DataStore.")
else
	warn("[MigrationFixtureV6] FAILURES: do not let real saves upgrade yet.")
end
