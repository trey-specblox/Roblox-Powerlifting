--!strict
--[[
	PlayerDataProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Exercises the Competition Number persistence
	foundation on server start and prints a pass/fail line per check to the
	Studio Output window.

	Set ENABLED to false to silence it, or delete this file. Nothing requires it,
	it touches no real player's data, and it creates no remotes.

	WHY THIS CAN TEST ANYTHING AT ALL WITHOUT A PLAYER

	The rules live in PlayerProfileSchema (migration) and ProfileOperations
	(validation, regeneration, spending), both of which are pure functions of a
	data table plus a timestamp. So this harness builds synthetic profiles,
	passes synthetic server times, and checks the same code the live game runs.

	Driving the clock as a parameter is what makes the resource tests possible:
	a week of offline regeneration is one arithmetic call, not a week of waiting.

	WHAT IT DOES NOT PROVE

	It does not exercise ProfileStore, real DataStore round-trips, Reconcile, or
	session locking, none of which are reachable outside a running Studio
	session. See the Studio test procedure in the increment notes for those.

	=========================================================================
	OFF BY DEFAULT. SET TO true TO RUN IT.
	=========================================================================

	The foundation has been validated in Studio, so the whole suite on every Play
	is noise rather than information. Turn it on whenever persistence changes:
	the schema, a migration, ProfileOperations, ResourceRegeneration or
	MeetCnAllowance. Then turn it off again.

	THE TESTS THEMSELVES ARE NOT WEAKENED OR REMOVED by this flag, and must not
	be. The whole suite is one word away whenever the persistence layer is
	touched, which is exactly when it earns its keep.
]]

local ENABLED = false

if not ENABLED then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))
local StartingValuesConfig = require(ConfigFolder:WaitForChild("StartingValuesConfig"))

local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerProfileSchema = require(PlayerDataFolder:WaitForChild("PlayerProfileSchema"))
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local DayKey = require(ProgressionFolder:WaitForChild("DayKey"))
local MeetCnAllowance = require(ProgressionFolder:WaitForChild("MeetCnAllowance"))
local ProgressionReferenceConfig = require(ConfigFolder:WaitForChild("ProgressionReferenceConfig"))

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
	return math.abs(a - b) <= (tolerance or 0.0001)
end

--[[
	A deep copy, so a test cannot mutate the template every later test reads.
]]
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

--[[
	A brand-new profile, exactly as ProfileStore would hand one over.
]]
local function newProfile(): PlayerProfileSchema.ProfileData
	local data = deepCopy(PlayerProfileSchema.template)
	-- The template's `builds` is empty; every real load creates the starting build (schema v6).
	PlayerProfileSchema.ensureActiveBuild(data)
	return data
end

--[[
	SCHEMA VERSION 6: Competition Number and Scale live in the build of the
	current weight class (GAME_DESIGN.md 29.11). These read the active build so
	the checks below stay about the numbers, not the storage path. A missing
	build reads as an empty table, so a check FAILS rather than the probe
	erroring.
]]
local function classOf(data: any): string
	return PlayerProfileSchema.classKeyFor(data.bodyweight and data.bodyweight.currentKg) or "?"
end

local function buildOf(data: any): any
	local builds = data.builds
	local build = if typeof(builds) == "table" then builds[classOf(data)] else nil
	return if typeof(build) == "table" then build else {}
end

local function cnOf(data: any): any
	return buildOf(data).competitionNumber or {}
end

local function scaleOf(data: any): any
	return buildOf(data).competitionScale or {}
end

--[[
	A realistic version-2 save, as it looks AFTER Reconcile and BEFORE migration.

	This is the shape that matters most, and getting it wrong would make the
	migration test meaningless. Reconcile fills every key the template has, so
	`competitionNumber` arrives holding the 25 kg DEFAULTS, while the player's
	real numbers are still in the old `forecasted` table. The migration has to
	prefer the old table. If it does not, every existing lifter is reset to 25.
]]
local function reconciledV2Save(squat: number, bench: number, deadlift: number): any
	local data = newProfile() :: any

	-- What Reconcile would have put there: the template defaults.
	data.competitionNumber = {
		Squat = StartingValuesConfig.Forecasted.Squat,
		Bench = StartingValuesConfig.Forecasted.Bench,
		Deadlift = StartingValuesConfig.Forecasted.Deadlift,
	}

	-- What the player actually saved under version 2.
	data.forecasted = { Squat = squat, Bench = bench, Deadlift = deadlift }

	data.technique = {
		SquatControl = 1200,
		DepthAwareness = 800,
		StartControl = 450,
		PressPower = 2000,
		PullStrength = 300,
		Lockout = 95,
	}

	data.bodyweight = { currentKg = 81.5, targetKg = 93 }
	data.meta = { createdUnix = 1700000000, lastSessionUnix = 1700500000, sessionCount = 42 }
	data.version = 2

	return data
end

--[[
	A VERSION-3 SAVE AS IT WOULD ARRIVE FROM A REAL DATASTORE, after Reconcile.

	Version 3 is the shape that is live in production right now, so this is the
	fixture that matters most for the v4 upgrade: a player with trained
	Competition Numbers, a part-spent budget and real technique, who has never
	competed because no meet system has ever existed.

	`competitionScale` ARRIVES FROM THE TEMPLATE, NOT FROM THE SAVE. A genuine v3
	record has no such field, because it did not exist when the record was
	written. `newProfile()` below is a copy of the current template, so the field
	is present and unproven exactly as `Profile:Reconcile` would leave it -- and
	PlayerDataService runs Reconcile before migrate, so this is the real ordering.
	Nothing in this fixture writes a Scale.

	Section 27 covers the other half: what happens when the field is absent or
	malformed and Reconcile has NOT supplied it.
]]
local function reconciledV3Save(squat: number, bench: number, deadlift: number): any
	local data = newProfile() :: any

	-- What the player actually saved under version 3.
	data.competitionNumber = { Squat = squat, Bench = bench, Deadlift = deadlift }

	data.technique = {
		SquatControl = 1400,
		DepthAwareness = 900,
		StartControl = 500,
		PressPower = 2200,
		PullStrength = 350,
		Lockout = 110,
	}

	data.bodyweight = { currentKg = 81.5, targetKg = 93 }
	data.meta = { createdUnix = 1700000000, lastSessionUnix = 1700500000, sessionCount = 77 }

	-- A part-spent Squat pool, as old saves had (the field was removed in version 10).
	data.competitionBudget = {
		Squat = { amount = 3.21, lastUpdatedUnix = 1700500000 },
		Bench = { amount = 9.43, lastUpdatedUnix = 0 },
		Deadlift = { amount = 9.43, lastUpdatedUnix = 0 },
	}
	data.trainingEnergy = { amount = 45, lastUpdatedUnix = 1700500000 }

	data.version = 3

	return data
end

--[[
	A VERSION-4 SAVE AS IT WOULD ARRIVE FROM A REAL DATASTORE, after Reconcile.

	Version 4 is the shape that is live in production right now, so this is the
	fixture that matters most for the version-5 upgrade: a lifter with trained
	Competition Numbers, a part-spent budget, real technique including
	PullStrength, and -- unlike any real player today -- a PLANTED Competition
	Scale.

	THE PLANTED SCALE IS DELIBERATE AND IS NOT A CLAIM ABOUT PRODUCTION. Nothing
	writes Scale yet, so every real Scale is 0. Planting one here is the only way
	to prove the version-5 migration does not disturb it: a migration tested only
	against zeroes cannot distinguish "preserved" from "happened to already be the
	default".

	The three version-5 records ARRIVE FROM THE TEMPLATE, not from the save, which
	is what `newProfile()` gives us. A genuine v4 record has no such fields.
	PlayerDataService runs Reconcile before migrate, so this is the real ordering.
	Section 37 covers the other half: what happens when they are absent or
	malformed and Reconcile has NOT supplied them.
]]
local function reconciledV4Save(squat: number, bench: number, deadlift: number): any
	local data = newProfile() :: any

	data.competitionNumber = { Squat = squat, Bench = bench, Deadlift = deadlift }

	-- Planted, per the note above. No real profile holds these.
	data.competitionScale = { Squat = 177.5, Bench = 105.0, Deadlift = 212.5 }

	data.technique = {
		SquatControl = 1550,
		DepthAwareness = 975,
		StartControl = 525,
		PressPower = 2350,
		PullStrength = 410,
		Lockout = 128,
	}

	data.bodyweight = { currentKg = 82.4, targetKg = 93 }
	data.meta = { createdUnix = 1700000000, lastSessionUnix = 1700500000, sessionCount = 103 }

	data.competitionBudget = {
		Squat = { amount = 2.75, lastUpdatedUnix = 1700500000 },
		Bench = { amount = 9.43, lastUpdatedUnix = 0 },
		Deadlift = { amount = 9.43, lastUpdatedUnix = 0 },
	}
	data.trainingEnergy = { amount = 61, lastUpdatedUnix = 1700500000 }

	data.version = 4

	return data
end

--[[
	What ProfileStore does to a profile between sessions: serialize it, store it,
	and hand back a structurally identical table on the next load.

	A deep copy is the honest in-process stand-in. It proves a value survives
	being detached from the live table and reconstructed, which is what catches
	a field held by reference, a metatable, or a non-serializable value. It does
	NOT exercise the real DataStore, so the JSON round trip itself still has to
	be confirmed in Studio -- see the probe's closing note.
]]
local function saveAndReload(data: any): any
	return deepCopy(data)
end

local HOUR = 3600
local DAY = 86400

print("=== Player data persistence probe ===")
print(string.format(
	"schema version %d  |  meet allowance %.0f%% a day, %d days",
	PlayerProfileSchema.CURRENT_VERSION,
	ProgressionConfig.MeetCnAllowance.PercentPerDay * 100,
	ProgressionConfig.MeetCnAllowance.MaxDays
))
print("")

--------------------------------------------------------------------------------
print("1. brand-new profile defaults")
do
	local data = newProfile()

	check("version is current", data.version == PlayerProfileSchema.CURRENT_VERSION)
	check(
		"S/B/D all start at 25 kg",
		cnOf(data).Squat == 25
			and cnOf(data).Bench == 25
			and cnOf(data).Deadlift == 25
	)
	check("no legacy forecasted field in the template", (data :: any).forecasted == nil)
	check("bodyweight starts at 53 kg, maintaining", data.bodyweight.currentKg == 53 and data.bodyweight.targetKg == 53)
	check(
		"all five technique stats start at 0, and there is no PullStrength (checkpoint 9)",
		data.technique.SquatControl == 0
			and data.technique.DepthAwareness == 0
			and data.technique.StartControl == 0
			and data.technique.PressPower == 0
			and data.technique.Lockout == 0
			and (data.technique :: any).PullStrength == nil
	)
	local allowance = buildOf(data).meetAllowance
	check(
		"three meet allowances start full",
		allowance.Squat.amount == ProgressionConfig.MeetCnAllowance.MaxDays
			and allowance.Bench.amount == ProgressionConfig.MeetCnAllowance.MaxDays
			and allowance.Deadlift.amount == ProgressionConfig.MeetCnAllowance.MaxDays
	)
	check("there is no Training Energy (retired in v8)", (data :: any).trainingEnergy == nil)
	check("there is no Competition Budget (removed in v10)", (data :: any).competitionBudget == nil)
	check("resource timestamps are 0, not a server start time", allowance.Squat.lastUpdatedUnix == 0)
end

--------------------------------------------------------------------------------
print("")
print("2. old-schema migration preserves all three Competition Numbers")
do
	local data = reconciledV2Save(182.5, 117.5, 215.0)
	local finalVersion = PlayerProfileSchema.migrate(data, 2)

	check("migrated to version 11", finalVersion == 11 and data.version == 11)
	check("Squat preserved at 182.5", near(cnOf(data).Squat, 182.5), tostring(cnOf(data).Squat))
	check("Bench preserved at 117.5", near(cnOf(data).Bench, 117.5), tostring(cnOf(data).Bench))
	check("Deadlift preserved at 215.0", near(cnOf(data).Deadlift, 215.0), tostring(cnOf(data).Deadlift))
	check("legacy forecasted field removed", (data :: any).forecasted == nil)
	check("NOT reset to the 25 kg default", cnOf(data).Squat ~= 25)
end

--------------------------------------------------------------------------------
print("")
print("3. repeated migration does not corrupt values (idempotence)")
do
	local data = reconciledV2Save(300.0, 200.0, 350.0)
	PlayerProfileSchema.migrate(data, 2)

	-- Use some meet allowance so a second pass has something to destroy.
	buildOf(data).meetAllowance.Squat = { amount = 1.25, lastUpdatedUnix = 1000 * DAY }

	-- Run the step again directly, as a double-migration bug would.
	PlayerProfileSchema.migrate(data, 2)
	PlayerProfileSchema.migrate(data, 3)

	check("Squat still 300 after three passes", near(cnOf(data).Squat, 300.0), tostring(cnOf(data).Squat))
	check("Bench still 200", near(cnOf(data).Bench, 200.0))
	check("Deadlift still 350", near(cnOf(data).Deadlift, 350.0))
	check("version still 11", data.version == 11)
	check(
		"part-used meet allowance was not silently refilled",
		buildOf(data).meetAllowance.Squat.amount == 1.25,
		tostring(buildOf(data).meetAllowance.Squat.amount)
	)
end

--------------------------------------------------------------------------------
print("")
print("4. Competition Number addition persists correctly")
do
	local data = newProfile()

	local ok1 = ProfileOperations.applyCompetitionNumberDelta(data, "Squat", 1.418)
	local ok2 = ProfileOperations.applyCompetitionNumberDelta(data, "Squat", 1.069)

	check("both additions applied", ok1 and ok2)
	check(
		"Squat is 25 + 1.418 + 1.069 = 27.487",
		near(cnOf(data).Squat, 27.487),
		tostring(cnOf(data).Squat)
	)
	check("fractional progression was not rounded away", cnOf(data).Squat % 1 ~= 0)
	check("Bench untouched", cnOf(data).Bench == 25)
	check("Deadlift untouched", cnOf(data).Deadlift == 25)

	local okNeg = ProfileOperations.applyCompetitionNumberDelta(data, "Bench", -5)
	check("a negative delta is allowed (weight-class translation will need it)", okNeg)
	check("Bench is now 20", near(cnOf(data).Bench, 20.0))
end

--------------------------------------------------------------------------------
print("")
print("5. invalid Competition Number mutation is rejected")
do
	--[[
		EVERY CASE GETS ITS OWN FRESH PROFILE.

		An earlier version of this section shared one fixture across all eight
		cases, and that turned a single stale expectation into four reported
		failures: the first case mutated Squat to 50,025 kg, after which the
		"would reach zero" and "would go negative" cases were no longer operating
		on 25 kg at all, and the final "unchanged" assertion compared 49,965
		against 25.

		One root cause must report as one failure. Isolating the fixture is what
		guarantees that.
	]]
	local function rejects(label: string, lift: string, delta: number)
		local data = newProfile()
		local before = cnOf(data).Squat

		local applied = ProfileOperations.applyCompetitionNumberDelta(data, lift, delta)

		check(label .. " is rejected", not applied)
		check(
			label .. " leaves Squat untouched",
			cnOf(data).Squat == before,
			string.format("%s, expected %s", tostring(cnOf(data).Squat), tostring(before))
		)
	end

	rejects("a NaN delta", "Squat", 0 / 0)
	rejects("a +infinity delta", "Squat", math.huge)
	rejects("a -infinity delta", "Squat", -math.huge)
	rejects("an unknown lift", "Curl", 1)
	rejects("an empty lift name", "", 1)

	--[[
		A Competition Number of zero means "cannot lift", and DifficultyResolver
		divides by it, so neither of these may be allowed through. Each starts
		from a known 25 kg rather than from whatever a previous case left behind.
	]]
	rejects("a delta that would reach exactly zero", "Squat", -25)
	rejects("a delta that would go below zero", "Squat", -35)

	-- A rejected NaN must not leave a poisoned number behind.
	do
		local data = newProfile()
		ProfileOperations.applyCompetitionNumberDelta(data, "Squat", 0 / 0)
		check(
			"Squat is still a usable number after a NaN attempt",
			cnOf(data).Squat == cnOf(data).Squat
				and cnOf(data).Squat == 25
		)
	end

	-- A corrupt stored value is refused rather than written over.
	do
		local data = newProfile()
		cnOf(data).Squat = 0 / 0

		local applied = ProfileOperations.applyCompetitionNumberDelta(data, "Squat", 1.4)
		check("a corrupt stored Competition Number is refused", not applied)
		check(
			"and is left for the migration to repair, not patched here",
			cnOf(data).Squat ~= cnOf(data).Squat
		)
	end

	--[[
		A LARGE DELTA IS DELIBERATELY ACCEPTED, and this check exists to record
		that on purpose rather than leave it looking like an oversight.

		This section previously asserted "absurdly large delta rejected", which
		was stale: it was written while MAXIMUM_SINGLE_ADD_KG = 100 existed, and
		survived that constant's removal. The constant was removed because a
		universal kilogram cap is the wrong shape -- a bound sized for a reward
		(under 3 kg for one attempt) would refuse a correct weight-class
		translation, and one sized for translation would not constrain rewards.

		So the magnitude bound belongs to each calling operation, and this
		primitive is no longer reachable from PlayerDataService at all. The
		following section asserts that door is closed.
	]]
	do
		local data = newProfile()
		local applied, value = ProfileOperations.applyCompetitionNumberDelta(data, "Squat", 275.0)

		check("a translation-scale delta is permitted by the primitive", applied)
		check(
			"and applies exactly, with no clamping",
			value ~= nil and near(value :: number, 300.0),
			tostring(value)
		)
	end
end

--------------------------------------------------------------------------------
print("")
print("10. Training Energy is retired (schema version 8)")
do
	check("no consumeTrainingEnergy operation", (ProfileOperations :: any).consumeTrainingEnergy == nil)
	check("no Training Energy reader", (ProfileOperations :: any).getRegeneratedTrainingEnergy == nil)
	check("no Training Energy config", (ProgressionConfig :: any).TrainingEnergy == nil)
	check("not in the template", (PlayerProfileSchema.template :: any).trainingEnergy == nil)
end

--------------------------------------------------------------------------------
print("")
print("13. timestamps cannot be client-controlled")
do
	--[[
		This is a STRUCTURAL guarantee, so what is checked is the shape of the
		API rather than a runtime value.

		Every PlayerDataService operation reads os.time() itself and exposes no
		timestamp parameter, so there is no argument through which a caller could
		supply one. ProfileOperations takes `nowUnix` precisely so that THIS
		harness can drive it; nothing in gameplay passes anything but os.time().
	]]
	local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))

	--[[
		There is no ARBITRARY-KILOGRAM Competition Number writer on the service,
		and that absence is itself the guarantee: no caller can pass a kilogram
		delta through the service at all. The one CN writer, the 5B.5 training
		award, takes station seconds and reads the clock itself; its arity is
		checked below with the others.
	]]
	check(
		"the service exposes NO arbitrary-kilogram Competition Number writer",
		(PlayerDataService :: any).addCompetitionNumber == nil
			and (PlayerDataService :: any).applyCompetitionNumberDelta == nil
			and (PlayerDataService :: any).setCompetitionNumber == nil
	)
	check("but reading one is still available", typeof(PlayerDataService.getCompetitionNumber) == "function")

	check("awardTrainingProgression takes no timestamp", debug.info(PlayerDataService.awardTrainingProgression, "a") == 3)
	check("awardTechniqueTraining takes (player, lift, primary, seconds) -- no points, no timestamp",
		debug.info(PlayerDataService.awardTechniqueTraining, "a") == 4)
	check(
		"the service exposes NO direct technique-stat writer",
		(PlayerDataService :: any).setTechnique == nil
			and (PlayerDataService :: any).addTechnique == nil
			and (PlayerDataService :: any).applyTechniqueTraining == nil
	)

	-- And no remote exists through which a client could reach any of it.
	check("PlayerDataService exposes no RemoteEvent", (PlayerDataService :: any).Remote == nil)
	check("and no Training Energy operations (retired in v8)", (PlayerDataService :: any).consumeTrainingEnergy == nil
		and (PlayerDataService :: any).getRegeneratedTrainingEnergy == nil)
	check("and no Competition Budget operations (removed in v10)", (PlayerDataService :: any).consumeCompetitionBudget == nil
		and (PlayerDataService :: any).getRegeneratedCompetitionBudget == nil
		and (ProfileOperations :: any).consumeCompetitionBudget == nil)

	--[[
		A corrupt stored timestamp must not become a windfall. A NaN or missing
		timestamp grants nothing rather than a full refill.
	]]
	local data = newProfile()
	buildOf(data).meetAllowance.Squat = { amount = 0, lastUpdatedUnix = 0 / 0 }

	local fromNaN = MeetCnAllowance.daysAvailable(buildOf(data).meetAllowance.Squat, 1001 * DAY)
	check("a NaN stored timestamp grants nothing", near(fromNaN, 0), tostring(fromNaN))
end

--------------------------------------------------------------------------------
print("")
print("14. existing Technique and Bodyweight data survives migration")
do
	local data = reconciledV2Save(250.0, 160.0, 290.0)
	PlayerProfileSchema.migrate(data, 2)

	check("SquatControl 1200 survived", data.technique.SquatControl == 1200)
	check("DepthAwareness 800 survived", data.technique.DepthAwareness == 800)
	check("StartControl 450 survived", data.technique.StartControl == 450)
	check("PressPower 2000 survived", data.technique.PressPower == 2000)
	check("PullStrength 300 removed by the v7 step", (data.technique :: any).PullStrength == nil)
	check("Lockout 95 survived", data.technique.Lockout == 95)
	check("bodyweight 81.5 kg survived", near(data.bodyweight.currentKg, 81.5))
	check("target bodyweight 93 kg survived", near(data.bodyweight.targetKg, 93))
	check("createdUnix survived", data.meta.createdUnix == 1700000000)
	check("sessionCount 42 survived", data.meta.sessionCount == 42)
end

--------------------------------------------------------------------------------
print("")
print("bonus. a version-1 save reaches version 11 in one pass")
do
	--[[
		The long path. A v1 save predates the rename, so every step from
		migrations[1] on must run, in order; migrations[1] stays (as a repair
		only) since PullStrength was removed, or this save would be stranded.
	]]
	local data = newProfile() :: any
	data.competitionNumber = { Squat = 25, Bench = 25, Deadlift = 25 }
	data.forecasted = { Squat = 140.0, Bench = 95.0, Deadlift = 170.0 }
	data.technique = {
		SquatControl = 500,
		DepthAwareness = 400,
		StartControl = 300,
		PressPower = 600,
		Lockout = 50,
		-- No PullStrength: it did not exist at version 1.
	}
	data.version = 1

	local finalVersion = PlayerProfileSchema.migrate(data, 1)

	check("reached version 11", finalVersion == 11 and data.version == 11)
	check("Squat 140 preserved across two migrations", near(cnOf(data).Squat, 140.0), tostring(cnOf(data).Squat))
	check("Bench 95 preserved", near(cnOf(data).Bench, 95.0))
	check("Deadlift 170 preserved", near(cnOf(data).Deadlift, 170.0))
	check("no PullStrength at the end (the v1 step no longer adds it)", data.technique.PullStrength == nil)
	check("pre-existing technique untouched", data.technique.PressPower == 600)
	check("legacy forecasted removed", data.forecasted == nil)
end

--------------------------------------------------------------------------------
print("")
print("bonus. a partially corrupt v2 save keeps its good lifts")
do
	local data = reconciledV2Save(200.0, 0 / 0, 240.0) :: any
	PlayerProfileSchema.migrate(data, 2)

	check("the good Squat survived", near(cnOf(data).Squat, 200.0), tostring(cnOf(data).Squat))
	check("the good Deadlift survived", near(cnOf(data).Deadlift, 240.0))
	check("the NaN Bench fell back to the 25 kg default", cnOf(data).Bench == 25, tostring(cnOf(data).Bench))
	check("no NaN reached the profile", cnOf(data).Bench == cnOf(data).Bench)
end


--------------------------------------------------------------------------------
print("")
print("23. no meet counter is stored anywhere")
do
	local data = newProfile()

	--[[
		The data model does not count meets: the meet allowance is driven by the
		weights lifted, not by how many meets were played. No such field exists at
		the profile root or inside a meet allowance. (Local wins are a career
		count, career.localWins, not a meet counter.)
	]]
	local forbidden = {
		"meetCount", "meetsThisWeek", "meetNumber", "meets", "attemptCount",
		"attempts", "overflowMeets", "meetsPlayed", "weeklyMeets",
	}

	local rootClean = true
	local poolClean = true
	local allowance = buildOf(data).meetAllowance

	for _, name in ipairs(forbidden) do
		if (data :: any)[name] ~= nil then
			rootClean = false
		end
		for _, lift in ipairs(ProgressionConfig.Lifts) do
			if allowance[lift][name] ~= nil then
				poolClean = false
			end
		end
	end

	check("no meet or attempt counter at the profile root", rootClean)
	check("no meet or attempt counter inside any meet allowance", poolClean)

	-- An allowance holds exactly the two fields the regeneration model needs.
	local fieldCount = 0
	for _ in pairs(allowance.Squat) do
		fieldCount += 1
	end
	check("a meet allowance holds exactly 2 fields: amount and lastUpdatedUnix", fieldCount == 2, tostring(fieldCount))
	check("and they are those two", allowance.Squat.amount ~= nil and allowance.Squat.lastUpdatedUnix ~= nil)
	check("the Competition Budget is gone from a new profile", (data :: any).competitionBudget == nil)
end
--------------------------------------------------------------------------------
print("")
print("24. a new profile has proven nothing")
do
	local data = newProfile()

	check("competitionScale exists on a new profile", typeof(scaleOf(data)) == "table")

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local stored = (scaleOf(data) :: any)[lift]

		check(
			string.format("%s Scale is the UNPROVEN sentinel", lift),
			stored == PlayerProfileSchema.UNPROVEN_SCALE,
			tostring(stored)
		)
		check(
			string.format("%s reads as NOT proven", lift),
			ProfileOperations.isCompetitionScaleProven(data, lift) == false
		)
	end

	--[[
		THE WHOLE POINT OF THIS SECTION. A new lifter has a trained Competition
		Number and no proven Scale, and the two must not be confused.
	]]
	check("the UNPROVEN sentinel is 0", PlayerProfileSchema.UNPROVEN_SCALE == 0)
	check(
		"Scale is NOT seeded from the 25 kg starting Competition Number",
		scaleOf(data).Squat ~= cnOf(data).Squat
	)
	check("Competition Number is still 25 kg", near(cnOf(data).Squat, 25.0))
	check(
		"getCompetitionScale returns 0, not nil, for an unproven lift",
		ProfileOperations.getCompetitionScale(data, "Squat") == 0
	)
	check(
		"an unknown lift is rejected",
		ProfileOperations.getCompetitionScale(data, "Curl") == nil
	)
end

--------------------------------------------------------------------------------
print("")
print("25. a version-3 player migrates to UNPROVEN, not to their trained number")
do
	local data = reconciledV3Save(182.5, 117.5, 215.0)
	local finalVersion = PlayerProfileSchema.migrate(data, 3)

	check("migrated to version 11", finalVersion == 11 and data.version == 11)

	-- The rule that this whole checkpoint exists to get right.
	check("Squat Scale is UNPROVEN after migration", scaleOf(data).Squat == 0, tostring(scaleOf(data).Squat))
	check("Bench Scale is UNPROVEN after migration", scaleOf(data).Bench == 0)
	check("Deadlift Scale is UNPROVEN after migration", scaleOf(data).Deadlift == 0)
	check("Squat Scale was NOT set to the trained 182.5", scaleOf(data).Squat ~= 182.5)
	check("Bench Scale was NOT set to the trained 117.5", scaleOf(data).Bench ~= 117.5)
	check("Deadlift Scale was NOT set to the trained 215.0", scaleOf(data).Deadlift ~= 215.0)
	check("no lift reads as proven", not ProfileOperations.isCompetitionScaleProven(data, "Squat")
		and not ProfileOperations.isCompetitionScaleProven(data, "Bench")
		and not ProfileOperations.isCompetitionScaleProven(data, "Deadlift"))

	-- EVERYTHING ELSE THE PLAYER OWNED SURVIVES.
	check("trained Squat CN preserved at 182.5", near(cnOf(data).Squat, 182.5), tostring(cnOf(data).Squat))
	check("trained Bench CN preserved at 117.5", near(cnOf(data).Bench, 117.5))
	check("trained Deadlift CN preserved at 215.0", near(cnOf(data).Deadlift, 215.0))
	check("the old Competition Budget is removed (v10)", (data :: any).competitionBudget == nil)
	check("Training Energy removed by the v8 step", data.trainingEnergy == nil)
	check("technique PressPower 2200 preserved", data.technique.PressPower == 2200)
	check("technique PullStrength 350 removed by the v7 step", (data.technique :: any).PullStrength == nil)
	check("bodyweight 81.5 kg preserved", near(data.bodyweight.currentKg, 81.5))
	check("sessionCount 77 preserved", data.meta.sessionCount == 77)
	check("createdUnix preserved", data.meta.createdUnix == 1700000000)
end

--------------------------------------------------------------------------------
print("")
print("26. save and reload preserves both unproven and proven Scale")
do
	--[[
		UNPROVEN SURVIVES AS UNPROVEN. The failure this guards against is a
		sentinel that does not round-trip -- 0 becoming nil, or an absent field
		being reconstructed as something else.
	]]
	local fresh = newProfile()
	local reloadedFresh = saveAndReload(fresh)

	check("unproven Squat is still 0 after a reload", scaleOf(reloadedFresh).Squat == 0)
	check("unproven Bench is still 0", scaleOf(reloadedFresh).Bench == 0)
	check("unproven Deadlift is still 0", scaleOf(reloadedFresh).Deadlift == 0)
	check(
		"still reads as not proven after a reload",
		ProfileOperations.isCompetitionScaleProven(reloadedFresh, "Squat") == false
	)

	--[[
		A PROVEN NUMERIC SCALE SURVIVES TOO.

		Written directly onto the table, because no raise operation exists yet
		(section 33.12 step 4). This is the fixture standing in for a future
		successful meet attempt, and it is the only place in this probe that
		puts a non-zero Scale anywhere. It proves the storage carries a real
		value, which is the half of the round trip the unproven case cannot
		cover.
	]]
	local proven = newProfile() :: any
	scaleOf(proven).Squat = 172.5
	scaleOf(proven).Bench = 102.5

	local reloadedProven = saveAndReload(proven)

	check("proven Squat 172.5 survived the reload", near(scaleOf(reloadedProven).Squat, 172.5), tostring(scaleOf(reloadedProven).Squat))
	check("proven Bench 102.5 survived", near(scaleOf(reloadedProven).Bench, 102.5))
	check("the unproven Deadlift stayed unproven", scaleOf(reloadedProven).Deadlift == 0)
	check("proven Squat reads as proven", ProfileOperations.isCompetitionScaleProven(reloadedProven, "Squat"))
	check("proven Bench reads as proven", ProfileOperations.isCompetitionScaleProven(reloadedProven, "Bench"))
	check("unproven Deadlift still reads as not proven", not ProfileOperations.isCompetitionScaleProven(reloadedProven, "Deadlift"))
	check("a 2.5 kg increment is stored exactly", scaleOf(reloadedProven).Squat == 172.5)

	--[[
		AND A RE-RUN OF THE MIGRATION MUST NOT WIPE IT. The v3 to v4 step
		repairs a wrong shape and leaves a usable value alone, so a double
		migration cannot cost a player a proven lift.
	]]
	reloadedProven.version = 3
	PlayerProfileSchema.migrate(reloadedProven, 3)

	check(
		"a re-run migration left the proven 172.5 untouched",
		near(scaleOf(reloadedProven).Squat, 172.5),
		tostring(scaleOf(reloadedProven).Squat)
	)
	check("and left the unproven Deadlift at 0", scaleOf(reloadedProven).Deadlift == 0)
end

--------------------------------------------------------------------------------
print("")
print("27. a corrupt Scale repairs to UNPROVEN, never to an achievement")
do
	local data = reconciledV3Save(200.0, 130.0, 240.0) :: any

	-- Every way the field can be wrong in a real save.
	data.competitionScale = {
		Squat = 0 / 0,
		Bench = "190",
		Deadlift = -50,
	}

	PlayerProfileSchema.migrate(data, 3)

	check("a NaN Scale repaired to 0", scaleOf(data).Squat == 0, tostring(scaleOf(data).Squat))
	check("no NaN reached the profile", scaleOf(data).Squat == scaleOf(data).Squat)
	check("a string Scale repaired to 0", scaleOf(data).Bench == 0, tostring(scaleOf(data).Bench))
	check("a negative Scale repaired to 0", scaleOf(data).Deadlift == 0, tostring(scaleOf(data).Deadlift))
	check("the player's trained CN was not touched by the repair", near(cnOf(data).Squat, 200.0))

	-- A missing table is rebuilt rather than erroring the load.
	local missing = reconciledV3Save(150.0, 100.0, 180.0) :: any
	missing.competitionScale = nil
	PlayerProfileSchema.migrate(missing, 3)

	check("an absent competitionScale table was rebuilt", typeof(scaleOf(missing)) == "table")
	check("and every lift is UNPROVEN", scaleOf(missing).Squat == 0
		and scaleOf(missing).Bench == 0
		and scaleOf(missing).Deadlift == 0)

	-- A corrupt stored value must read as unproven, not as a reward.
	local corrupt = newProfile() :: any
	scaleOf(corrupt).Squat = 0 / 0
	check("a NaN Scale reads as nil, not as a number", ProfileOperations.getCompetitionScale(corrupt, "Squat") == nil)
	check("a NaN Scale does NOT read as proven", ProfileOperations.isCompetitionScaleProven(corrupt, "Squat") == false)
end

--------------------------------------------------------------------------------
print("")
print("28. no GAMEPLAY path can award Competition Scale")
do
	--[[
		THE BOUNDARY CHANGED SHAPE IN STEP 4, IT DID NOT MOVE.

		raiseCompetitionScale now EXISTS on ProfileOperations, so the old
		assertion that it does not is gone. What must still hold is that nothing
		a player can reach is able to call it:

		  - PlayerDataService is the gateway every gameplay system uses, and it
		    exposes no Scale writer, so there is no path through it.
		  - ProfileOperations is required by exactly two modules: the gateway
		    and this probe. LiftAttemptService reaches only the gateway.
		  - ProfileOperations is in ServerScriptService and creates no remotes,
		    so no client can reach it at all.
	]]
	local Service = require(PlayerDataFolder:WaitForChild("PlayerDataService"))

	check(
		"the raise operation exists on ProfileOperations (step 4)",
		typeof((ProfileOperations :: any).raiseCompetitionScale) == "function"
	)
	check(
		"the SERVICE exposes no Competition Scale writer",
		(Service :: any).raiseCompetitionScale == nil
			and (Service :: any).setCompetitionScale == nil
			and (Service :: any).awardCompetitionScale == nil
	)
	check(
		"ProfileOperations exposes no blind setCompetitionScale",
		(ProfileOperations :: any).setCompetitionScale == nil
	)
	check(
		"and still exposes no Competition Number writer",
		(Service :: any).addCompetitionNumber == nil
			and (Service :: any).applyCompetitionNumberDelta == nil
	)

	--[[
		THE LIFT MINIGAMES CANNOT REACH IT. LiftAttemptService owns every lift
		attempt and all the lifting remotes, so if any gameplay path could award
		Scale it would be this one. It holds no reference to ProfileOperations
		and the gateway it does hold has no writer, so the path does not exist.
	]]
	local LiftingFolder = script.Parent.Parent:WaitForChild("Lifting")
	local LiftAttemptService = require(LiftingFolder:WaitForChild("LiftAttemptService"))

	check(
		"LiftAttemptService exposes no Scale writer of its own",
		(LiftAttemptService :: any).raiseCompetitionScale == nil
			and (LiftAttemptService :: any).awardCompetitionScale == nil
	)

	--[[
		AND NO MEET SYSTEM EXISTS TO CALL IT. MeetTotal is the only module that
		knows what a successful attempt is, and it is pure: it computes a number
		from an attempt history and writes nothing anywhere.
	]]
	local SharedMeetFolder = Shared:WaitForChild("Meet")
	local MeetTotal = require(SharedMeetFolder:WaitForChild("MeetTotal"))

	check(
		"MeetTotal is pure and holds no profile writer",
		(MeetTotal :: any).raiseCompetitionScale == nil
			and (MeetTotal :: any).applyToProfile == nil
	)

	--[[
		THE INPUT PATH THAT A FUTURE HANDLER MUST USE IS SUCCESS-ONLY.

		bestSuccessful filters on result == "GoodLift", so a failed attempt's
		weight cannot reach the raise through it however heavy it was. This is
		the structural half of the rule that failures never raise Scale.
	]]
	local history = {
		{ weightKg = 180.0, result = "GoodLift" },
		{ weightKg = 250.0, result = "NoLift" },
		{ weightKg = 190.0, result = "GoodLift" },
	}

	local best = MeetTotal.bestSuccessful(history :: any)

	check(
		"bestSuccessful returns the heaviest MADE lift, 190",
		best == 190.0,
		tostring(best)
	)
	check("and ignores the heavier FAILED 250", best ~= 250.0)

	local allFailed = {
		{ weightKg = 200.0, result = "NoLift" },
		{ weightKg = 210.0, result = "NoLift" },
	}

	check(
		"a lift with no successful attempt yields nil, not a weight",
		MeetTotal.bestSuccessful(allFailed :: any) == nil
	)
end

--------------------------------------------------------------------------------
print("")
print("29. the monotone raise: first proof, then increases")
do
	local data = newProfile()

	-- UNPROVEN to first proven weight.
	check("Squat starts unproven", scaleOf(data).Squat == 0)

	local outcome, value = ProfileOperations.raiseCompetitionScale(data, classOf(data), "Squat", 150.0)

	check("first proof returns Raised", outcome == "Raised", tostring(outcome))
	check("and returns the new Scale", value == 150.0, tostring(value))
	check("the stored Scale is 150", near(scaleOf(data).Squat, 150.0), tostring(scaleOf(data).Squat))
	check("and it now reads as proven", ProfileOperations.isCompetitionScaleProven(data, "Squat"))

	-- Raising an existing proven Scale.
	local outcome2, value2 = ProfileOperations.raiseCompetitionScale(data, classOf(data), "Squat", 172.5)

	check("a heavier proof returns Raised", outcome2 == "Raised", tostring(outcome2))
	check("and returns 172.5", value2 == 172.5, tostring(value2))
	check("the stored Scale is now 172.5", near(scaleOf(data).Squat, 172.5), tostring(scaleOf(data).Squat))

	-- A 2.5 kg increment, the smallest legal meet increase, is exact.
	local outcome3 = ProfileOperations.raiseCompetitionScale(data, classOf(data), "Squat", 175.0)
	check("a 2.5 kg increase is accepted", outcome3 == "Raised")
	check("and stored exactly", scaleOf(data).Squat == 175.0, tostring(scaleOf(data).Squat))

	-- A fractional weight is not rounded away.
	local fresh = newProfile()
	ProfileOperations.raiseCompetitionScale(fresh, classOf(fresh), "Bench", 102.3)
	check("a fractional proof is stored at full precision", near(scaleOf(fresh).Bench, 102.3), tostring(scaleOf(fresh).Bench))
end

--------------------------------------------------------------------------------
print("")
print("30. SCALE NEVER DECREASES")
do
	local data = newProfile()
	ProfileOperations.raiseCompetitionScale(data, classOf(data), "Deadlift", 220.0)

	-- A LOWER successful weight. The commonest case: a conservative opener.
	local lower, lowerValue = ProfileOperations.raiseCompetitionScale(data, classOf(data), "Deadlift", 180.0)

	check("a lower proof returns Unchanged, not Rejected", lower == "Unchanged", tostring(lower))
	check("and reports the Scale that still stands", lowerValue == 220.0, tostring(lowerValue))
	check("the stored Scale did NOT drop", near(scaleOf(data).Deadlift, 220.0), tostring(scaleOf(data).Deadlift))

	-- An EQUAL weight. Repeating a best is legal and changes nothing.
	local equal, equalValue = ProfileOperations.raiseCompetitionScale(data, classOf(data), "Deadlift", 220.0)

	check("an equal proof returns Unchanged", equal == "Unchanged", tostring(equal))
	check("and reports 220", equalValue == 220.0, tostring(equalValue))
	check("the stored Scale is still 220", near(scaleOf(data).Deadlift, 220.0))

	-- A long run of lighter lifts can never erode it.
	for _, weight in ipairs({ 100.0, 200.0, 50.0, 219.5, 1.0, 217.5 }) do
		ProfileOperations.raiseCompetitionScale(data, classOf(data), "Deadlift", weight)
	end

	check(
		"six lighter proofs left it at 220",
		near(scaleOf(data).Deadlift, 220.0),
		tostring(scaleOf(data).Deadlift)
	)

	-- IDEMPOTENCE. Repeated identical calls settle on one value.
	local repeated = newProfile()
	for _ = 1, 10 do
		ProfileOperations.raiseCompetitionScale(repeated, classOf(repeated), "Squat", 165.0)
	end
	check("ten identical calls give 165", near(scaleOf(repeated).Squat, 165.0), tostring(scaleOf(repeated).Squat))

	-- ORDER INDEPENDENCE. The max does not care what order proofs arrive in.
	local ascending = newProfile()
	for _, w in ipairs({ 120.0, 140.0, 160.0, 180.0 }) do
		ProfileOperations.raiseCompetitionScale(ascending, classOf(ascending), "Bench", w)
	end

	local descending = newProfile()
	for _, w in ipairs({ 180.0, 160.0, 140.0, 120.0 }) do
		ProfileOperations.raiseCompetitionScale(descending, classOf(descending), "Bench", w)
	end

	check(
		"ascending and descending orders agree at 180",
		near(scaleOf(ascending).Bench, 180.0)
			and near(scaleOf(descending).Bench, 180.0),
		string.format("%s vs %s", tostring(scaleOf(ascending).Bench), tostring(scaleOf(descending).Bench))
	)
end

--------------------------------------------------------------------------------
print("")
print("31. invalid input is rejected and writes nothing")
do
	local data = newProfile()
	ProfileOperations.raiseCompetitionScale(data, classOf(data), "Squat", 160.0)

	local rejects: { { label: string, lift: string, weight: any } } = {
		{ label = "an unknown lift", lift = "Curl", weight = 200.0 },
		{ label = "an empty lift name", lift = "", weight = 200.0 },
		{ label = "a zero weight (the UNPROVEN sentinel)", lift = "Squat", weight = 0 },
		{ label = "a negative weight", lift = "Squat", weight = -200.0 },
		{ label = "a NaN weight", lift = "Squat", weight = 0 / 0 },
		{ label = "a +infinity weight", lift = "Squat", weight = math.huge },
		{ label = "a -infinity weight", lift = "Squat", weight = -math.huge },
		{ label = "a string weight", lift = "Squat", weight = "500" },
		{ label = "a nil weight", lift = "Squat", weight = nil },
	}

	for _, case in ipairs(rejects) do
		local before = scaleOf(data).Squat

		local outcome, value = ProfileOperations.raiseCompetitionScale(data, classOf(data), case.lift, case.weight :: any)

		check(
			string.format("%s is Rejected", case.label),
			outcome == "Rejected",
			tostring(outcome)
		)
		check(
			string.format("%s returns no value", case.label),
			value == nil,
			tostring(value)
		)
		check(
			string.format("%s wrote nothing", case.label),
			scaleOf(data).Squat == before,
			string.format("%s, expected %s", tostring(scaleOf(data).Squat), tostring(before))
		)
	end

	check("the Scale survived every rejection at 160", near(scaleOf(data).Squat, 160.0), tostring(scaleOf(data).Squat))
	check("and no NaN reached the profile", scaleOf(data).Squat == scaleOf(data).Squat)

	--[[
		A CORRUPT STORED SCALE IS REFUSED RATHER THAN REPAIRED, because we
		cannot know whether it was higher than the incoming proof. Repair is the
		migration's job and happens on every load.
	]]
	local corrupt = newProfile() :: any
	scaleOf(corrupt).Bench = 0 / 0

	local outcome = ProfileOperations.raiseCompetitionScale(corrupt, classOf(corrupt), "Bench", 120.0)
	check("a corrupt stored Scale rejects the raise", outcome == "Rejected", tostring(outcome))
	check("and the raise did not overwrite it", scaleOf(corrupt).Bench ~= 120.0)
end

--------------------------------------------------------------------------------
print("")
print("32. lifts are independent, and nothing else in the profile moves")
do
	local data = newProfile()

	-- Snapshot everything a raise must not touch.
	local cnBefore = {
		Squat = cnOf(data).Squat,
		Bench = cnOf(data).Bench,
		Deadlift = cnOf(data).Deadlift,
	}
	local allowanceBefore = buildOf(data).meetAllowance.Squat.amount
	local techniqueBefore = data.technique.PressPower
	local bodyweightBefore = data.bodyweight.currentKg
	local versionBefore = data.version

	ProfileOperations.raiseCompetitionScale(data, classOf(data), "Squat", 190.0)

	check("Squat Scale rose to 190", near(scaleOf(data).Squat, 190.0))
	check("Bench Scale stayed unproven", scaleOf(data).Bench == 0, tostring(scaleOf(data).Bench))
	check("Deadlift Scale stayed unproven", scaleOf(data).Deadlift == 0, tostring(scaleOf(data).Deadlift))

	ProfileOperations.raiseCompetitionScale(data, classOf(data), "Bench", 110.0)
	ProfileOperations.raiseCompetitionScale(data, classOf(data), "Deadlift", 230.0)

	check("all three now hold their own value", near(scaleOf(data).Squat, 190.0)
		and near(scaleOf(data).Bench, 110.0)
		and near(scaleOf(data).Deadlift, 230.0))

	-- COMPETITION NUMBER IS UNTOUCHED. Scale is not derived from it and does not feed it.
	check("Squat CN unchanged", cnOf(data).Squat == cnBefore.Squat, tostring(cnOf(data).Squat))
	check("Bench CN unchanged", cnOf(data).Bench == cnBefore.Bench)
	check("Deadlift CN unchanged", cnOf(data).Deadlift == cnBefore.Deadlift)
	check("CN is still the 25 kg starting value", near(cnOf(data).Squat, 25.0))

	-- AND NOTHING ELSE MOVED EITHER.
	check("meet allowance untouched", buildOf(data).meetAllowance.Squat.amount == allowanceBefore)
	check("technique untouched", data.technique.PressPower == techniqueBefore)
	check("bodyweight untouched", near(data.bodyweight.currentKg, bodyweightBefore))
	check("schema version untouched", data.version == versionBefore)

	--[[
		NO TIMESTAMP IS READ OR WRITTEN. The operation is pure: it takes no
		`nowUnix` and stamps nothing, so unlike a regenerating resource it
		cannot be made to behave differently by a clock.
	]]
	check(
		"raiseCompetitionScale takes exactly four arguments (data, class, lift, kg), none a timestamp",
		debug.info(ProfileOperations.raiseCompetitionScale, "a") == 4,
		tostring(debug.info(ProfileOperations.raiseCompetitionScale, "a"))
	)
	check("no allowance timestamp was stamped", buildOf(data).meetAllowance.Squat.lastUpdatedUnix == 0)
end

--------------------------------------------------------------------------------
print("33. a new profile has spent nothing and trained no hours today")
do
	local data = newProfile() :: any

	check("cnAllowance exists", typeof(data.cnAllowance) == "table")
	check("techniqueAllowance exists", typeof(data.techniqueAllowance) == "table")
	check("trainingTimeToday exists", typeof(data.trainingTimeToday) == "table")

	check("CN allowance spent is 0", data.cnAllowance.spentToday == 0, tostring(data.cnAllowance.spentToday))
	check("technique allowance spent is 0", data.techniqueAllowance.spentToday == 0)

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		check(
			string.format("%s training time is 0", lift),
			data.trainingTimeToday[lift] == 0,
			tostring(data.trainingTimeToday[lift])
		)
	end

	--[[
		UNSTAMPED, NOT TODAY. A real day key in the template would record the day
		the SERVER started, and every profile it created would share it.
	]]
	check("CN allowance day key is UNSTAMPED", data.cnAllowance.dayKey == DayKey.UNSTAMPED)
	check("technique allowance day key is UNSTAMPED", data.techniqueAllowance.dayKey == DayKey.UNSTAMPED)
	check("training time day key is UNSTAMPED", data.trainingTimeToday.dayKey == DayKey.UNSTAMPED)

	check("UNSTAMPED does not read as a real day", DayKey.isStamped(data.cnAllowance.dayKey) == false)

	check("CN allowance timestamp is 0", data.cnAllowance.lastUpdatedUnix == 0)
	check("technique allowance timestamp is 0", data.techniqueAllowance.lastUpdatedUnix == 0)
	check("training time timestamp is 0", data.trainingTimeToday.lastUpdatedUnix == 0)

	-- NO CAP IS STORED PER PLAYER. The caps are config, arriving in 5B.2.
	check("no cap is stored on the CN allowance", (data.cnAllowance :: any).cap == nil)
	check("no cap is stored on the technique allowance", (data.techniqueAllowance :: any).cap == nil)
end

--------------------------------------------------------------------------------
print("34. a version-4 player migrates to zero spent, and loses nothing")
do
	local data = reconciledV4Save(195.0, 125.0, 232.5)

	local finalVersion = PlayerProfileSchema.migrate(data, 4)

	check("migrated 4 to 11", finalVersion == 11 and data.version == 11, tostring(data.version))

	--[[
		NO OFFLINE TRAINING CREDIT. A save that predates the station cannot
		contain station time, so nothing is backdated and nothing is owed.
	]]
	check("CN allowance arrives unspent", data.cnAllowance.spentToday == 0)
	check("technique allowance arrives unspent", data.techniqueAllowance.spentToday == 0)
	check("Squat hours arrive at 0", data.trainingTimeToday.Squat == 0)
	check("Bench hours arrive at 0", data.trainingTimeToday.Bench == 0)
	check("Deadlift hours arrive at 0", data.trainingTimeToday.Deadlift == 0)
	check("day keys arrive UNSTAMPED", data.cnAllowance.dayKey == DayKey.UNSTAMPED
		and data.techniqueAllowance.dayKey == DayKey.UNSTAMPED
		and data.trainingTimeToday.dayKey == DayKey.UNSTAMPED)

	-- EVERY PRE-EXISTING FIELD SURVIVES. This is the half that can lose data.
	check("Squat CN preserved", near(cnOf(data).Squat, 195.0), tostring(cnOf(data).Squat))
	check("Bench CN preserved", near(cnOf(data).Bench, 125.0))
	check("Deadlift CN preserved", near(cnOf(data).Deadlift, 232.5))

	check("Squat Scale preserved", near(scaleOf(data).Squat, 177.5), tostring(scaleOf(data).Squat))
	check("Bench Scale preserved", near(scaleOf(data).Bench, 105.0))
	check("Deadlift Scale preserved", near(scaleOf(data).Deadlift, 212.5))

	check("SquatControl preserved", data.technique.SquatControl == 1550)
	check("DepthAwareness preserved", data.technique.DepthAwareness == 975)
	check("StartControl preserved", data.technique.StartControl == 525)
	check("PressPower preserved", data.technique.PressPower == 2350)
	check("Lockout preserved", data.technique.Lockout == 128)

	--[[
		PULLSTRENGTH IS STILL HERE, AND THAT IS CORRECT FOR THIS CHECKPOINT.
		GAME_DESIGN.md section 34.6 removes it from the DESIGN; section 34.14
		checkpoint 9 removes it from the CODE, together with the Deadlift typing
		rebase. 5B.1 must not touch it, so this asserts it survived.
	]]
	check("PullStrength removed (checkpoint 9)", (data.technique :: any).PullStrength == nil)

	check("the old Competition Budget is removed (v10)", (data :: any).competitionBudget == nil)
	check("Training Energy removed by the v8 step", data.trainingEnergy == nil)
	check("bodyweight preserved", near(data.bodyweight.currentKg, 82.4) and near(data.bodyweight.targetKg, 93))
	check("meta preserved", data.meta.sessionCount == 103 and data.meta.createdUnix == 1700000000)
end

--------------------------------------------------------------------------------
print("35. EVERY historical version gap still reaches version 11")
do
	--[[
		The rule this guards is in PlayerProfileSchema: a step must exist for every
		gap, or migrate() warns and ABANDONS the profile at its old version. A
		missing step is not a harmless omission, it strands the save -- so each
		starting version is walked the whole way here, not just the newest one.
	]]
	local oneToFive = reconciledV2Save(150.0, 95.0, 180.0)
	oneToFive.version = 1
	oneToFive.forecasted = nil
	oneToFive.technique.PullStrength = nil

	local v1 = PlayerProfileSchema.migrate(oneToFive, 1)
	check("version 1 reaches 11", v1 == 11 and oneToFive.version == 11, tostring(v1))
	check("v1 ends without PullStrength (removed in v7)", oneToFive.technique.PullStrength == nil)
	check("v1 gained the CN allowance", typeof(oneToFive.cnAllowance) == "table"
		and oneToFive.cnAllowance.spentToday == 0)
	check("v1 gained the training-time record", typeof(oneToFive.trainingTimeToday) == "table"
		and oneToFive.trainingTimeToday.Deadlift == 0)

	local twoToFive = reconciledV2Save(182.5, 117.5, 215.0)
	local v2 = PlayerProfileSchema.migrate(twoToFive, 2)
	check("version 2 reaches 11", v2 == 11 and twoToFive.version == 11, tostring(v2))
	check("v2 kept its real lifts through four steps", near(cnOf(twoToFive).Squat, 182.5))
	check("v2 gained the technique allowance", typeof(twoToFive.techniqueAllowance) == "table"
		and twoToFive.techniqueAllowance.dayKey == DayKey.UNSTAMPED)

	local threeToFive = reconciledV3Save(200.0, 130.0, 240.0)
	local v3 = PlayerProfileSchema.migrate(threeToFive, 3)
	check("version 3 reaches 11", v3 == 11 and threeToFive.version == 11, tostring(v3))
	check("v3 is still UNPROVEN, never seeded from CN", scaleOf(threeToFive).Squat == 0,
		tostring(scaleOf(threeToFive).Squat))
	check("v3 lost its old budget (removed in v10)", (threeToFive :: any).competitionBudget == nil)
	check("v3 gained all three version-5 records", typeof(threeToFive.cnAllowance) == "table"
		and typeof(threeToFive.techniqueAllowance) == "table"
		and typeof(threeToFive.trainingTimeToday) == "table")

	-- A brand new profile is already current and must skip every step.
	local fresh = newProfile() :: any
	local vNew = PlayerProfileSchema.migrate(fresh, 0)
	check("a new profile is already version 11", vNew == 11 and fresh.version == 11)

	--[[
		IDEMPOTENT. Running the step again on an already-migrated profile must not
		wipe a day's spending and let it be spent a second time.
	]]
	local spent = reconciledV4Save(210.0, 135.0, 250.0)
	PlayerProfileSchema.migrate(spent, 4)
	spent.cnAllowance = { spentToday = 2.5, dayKey = "2026-01-01", lastUpdatedUnix = 1767225600 }
	spent.trainingTimeToday.Squat = 1.75
	spent.version = 4
	PlayerProfileSchema.migrate(spent, 4)
	check("a second pass preserves spending", near(spent.cnAllowance.spentToday, 2.5),
		tostring(spent.cnAllowance.spentToday))
	check("a second pass preserves the day key", spent.cnAllowance.dayKey == "2026-01-01")
	check("a second pass preserves banked hours", near(spent.trainingTimeToday.Squat, 1.75))
end

--------------------------------------------------------------------------------
print("36. a reconnect preserves fractional counters and day keys")
do
	local data = reconciledV4Save(188.0, 120.0, 225.0)
	PlayerProfileSchema.migrate(data, 4)

	--[[
		The values a real day produces. 4.80 / 1.20 is section 34.7's 80/20 split
		of the 6.00 point allowance, and 2.8109 is section 34.4's cumulative EV at
		three hours. If any of these came back rounded, the split would be silently
		wrong and the EV curve would quantise.
	]]
	data.cnAllowance = { spentToday = 2.8109, dayKey = "2026-10-08", lastUpdatedUnix = 1760000000 }
	data.techniqueAllowance = { spentToday = 4.8, dayKey = "2026-10-08", lastUpdatedUnix = 1760000000 }
	data.trainingTimeToday = {
		Squat = 3.0,
		Bench = 1.25,
		Deadlift = 0.5,
		dayKey = "2026-10-08",
		lastUpdatedUnix = 1760000000,
	}

	local reloaded = saveAndReload(data)

	check("fractional EV survives the round trip", near(reloaded.cnAllowance.spentToday, 2.8109),
		tostring(reloaded.cnAllowance.spentToday))
	check("the 80/20 primary share survives", near(reloaded.techniqueAllowance.spentToday, 4.8))
	check("fractional hours survive", near(reloaded.trainingTimeToday.Bench, 1.25)
		and near(reloaded.trainingTimeToday.Deadlift, 0.5))
	check("day keys survive as strings", reloaded.cnAllowance.dayKey == "2026-10-08"
		and reloaded.trainingTimeToday.dayKey == "2026-10-08")
	check("timestamps survive", reloaded.cnAllowance.lastUpdatedUnix == 1760000000)

	--[[
		DETACHED, NOT SHARED. A field held by reference would make a reload alias
		the live table, and a later write would appear to travel backwards in time.
	]]
	reloaded.cnAllowance.spentToday = 4.0
	check("the reload is a separate table", near(data.cnAllowance.spentToday, 2.8109))

	-- MIGRATING AN ALREADY-CURRENT PROFILE AGAIN MUST NOT RESET A LIVE DAY.
	check("reload is still version 11", reloaded.version == 11)
end

--------------------------------------------------------------------------------
print("37. the UTC day key, midnight, and corrupt training data")
do
	--[[
		1700000000 is 2023-11-14T22:13:20Z. The absolute assertion is the one that
		matters: for any observer east of UTC+01:47 the LOCAL date there is already
		the 15th, so this fails loudly if the UTC prefix is ever dropped.
	]]
	local midAfternoon = 1700000000
	check("a known timestamp maps to its UTC date", DayKey.fromUnix(midAfternoon) == "2023-11-14",
		DayKey.fromUnix(midAfternoon))

	local startOfThatDay = DayKey.startOfDayUnix(midAfternoon)
	check("start of day is a UTC midnight", startOfThatDay == 1699920000, tostring(startOfThatDay))
	check("start of day has the same key", DayKey.fromUnix(startOfThatDay) == "2023-11-14")

	-- SAME DAY, DIFFERENT HOURS: one key, so no reset happens mid-day.
	check("08:00 and 23:00 on one day share a key",
		DayKey.fromUnix(startOfThatDay + 8 * HOUR) == DayKey.fromUnix(startOfThatDay + 23 * HOUR))

	-- THE BOUNDARY ITSELF. One second apart, two different days.
	local lastSecond = startOfThatDay + DAY - 1
	local firstSecond = startOfThatDay + DAY
	check("the last second of the day is still the 14th", DayKey.fromUnix(lastSecond) == "2023-11-14",
		DayKey.fromUnix(lastSecond))
	check("the first second of the next day is the 15th", DayKey.fromUnix(firstSecond) == "2023-11-15",
		DayKey.fromUnix(firstSecond))
	check("midnight changes the key", DayKey.fromUnix(lastSecond) ~= DayKey.fromUnix(firstSecond))

	--[[
		WHAT THE 5B.4 READER WILL ACTUALLY DO. It has no reader yet, so this proves
		only the comparison it will perform: a counter stamped yesterday is
		detectably stale, and one stamped today is not.
	]]
	local stored = { spentToday = 4.0, dayKey = DayKey.fromUnix(lastSecond), lastUpdatedUnix = lastSecond }
	check("a counter stamped yesterday reads as stale", stored.dayKey ~= DayKey.fromUnix(firstSecond))
	check("a counter stamped today reads as current", stored.dayKey == DayKey.fromUnix(lastSecond - HOUR))
	check("an UNSTAMPED counter reads as stale against any real day",
		DayKey.UNSTAMPED ~= DayKey.fromUnix(firstSecond))
	check("a real key reads as stamped", DayKey.isStamped(stored.dayKey))

	--[[
		A BAD CLOCK FAILS CLOSED, LOUDLY. Any varying return for a bad input would
		hand out a fresh allowance on every read, so DayKey asserts instead.
	]]
	check("NaN is rejected", not (pcall(DayKey.fromUnix, 0 / 0)))
	check("infinity is rejected", not (pcall(DayKey.fromUnix, math.huge)))
	check("a negative time is rejected", not (pcall(DayKey.fromUnix, -1)))
	check("a string is rejected", not (pcall(DayKey.fromUnix, ("1700000000" :: any))))

	--[[
		CORRUPTION REPAIRS, AND THE RECORD IS REPAIRED AS A UNIT. A spent amount
		with no day attached cannot be compared against anything, so the schema
		discards it rather than leaving a state the reader never produces.
	]]
	local corrupt = reconciledV4Save(170.0, 110.0, 205.0)
	corrupt.cnAllowance = { spentToday = 3.5, dayKey = 12345, lastUpdatedUnix = 1700500000 }
	corrupt.techniqueAllowance = { spentToday = 0 / 0, dayKey = "2026-10-08", lastUpdatedUnix = 1700500000 }
	corrupt.trainingTimeToday = nil

	PlayerProfileSchema.migrate(corrupt, 4)

	check("a non-string day key resets its record", corrupt.cnAllowance.dayKey == DayKey.UNSTAMPED
		and corrupt.cnAllowance.spentToday == 0, tostring(corrupt.cnAllowance.spentToday))
	check("a NaN spend repairs to 0 but keeps its good day key",
		corrupt.techniqueAllowance.spentToday == 0
			and corrupt.techniqueAllowance.dayKey == "2026-10-08")
	check("a missing training-time record is rebuilt", typeof(corrupt.trainingTimeToday) == "table"
		and corrupt.trainingTimeToday.Squat == 0
		and corrupt.trainingTimeToday.dayKey == DayKey.UNSTAMPED)

	local negative = reconciledV4Save(165.0, 108.0, 200.0)
	negative.trainingTimeToday = {
		Squat = -5,
		Bench = math.huge,
		Deadlift = 2.25,
		dayKey = "2026-10-08",
		lastUpdatedUnix = -1,
	}

	PlayerProfileSchema.migrate(negative, 4)

	check("a negative hour count repairs to 0", negative.trainingTimeToday.Squat == 0)
	check("an infinite hour count repairs to 0", negative.trainingTimeToday.Bench == 0)
	check("a GOOD hour count beside them is untouched", near(negative.trainingTimeToday.Deadlift, 2.25),
		tostring(negative.trainingTimeToday.Deadlift))
	check("a negative timestamp repairs to 0", negative.trainingTimeToday.lastUpdatedUnix == 0)

	-- AND THE REPAIR TOUCHED NOTHING ELSE.
	check("repair left CN alone", near(cnOf(negative).Squat, 165.0))
	check("repair left Scale alone", near(scaleOf(negative).Squat, 177.5))
	check("repair left technique alone", negative.technique.PressPower == 2350)
	check("the old budget is removed (v10)", (negative :: any).competitionBudget == nil)
end

--[[
	A VERSION-5 SAVE AS IT WOULD ARRIVE FROM A REAL DATASTORE, after Reconcile.

	The flat Competition Number and Scale are the player's real numbers; `builds`
	is the template's EMPTY table, which is all Reconcile adds. The planted Scale
	is deliberate (no real profile holds one): a migration tested only against
	zeroes cannot tell "moved" from "happened to be the default".
]]
local function reconciledV5Save(squat: number, bench: number, deadlift: number, bodyweightKg: number): any
	local data = reconciledV4Save(squat, bench, deadlift)
	data.bodyweight = { currentKg = bodyweightKg, targetKg = bodyweightKg }
	data.builds = {}
	data.cnAllowance = { spentToday = 1.5, dayKey = "2026-10-27", lastUpdatedUnix = 1761600000 }
	data.version = 5
	return data
end

local function countBuilds(data: any): number
	local count = 0
	for _ in pairs(data.builds) do
		count += 1
	end
	return count
end

--------------------------------------------------------------------------------
print("")
print("38. a version-5 player's numbers move into ONE build, exactly")
do
	local data = reconciledV5Save(182.5, 117.5, 215.0, 82.4)
	local finalVersion = PlayerProfileSchema.migrate(data, 5)
	local build = data.builds["83 kg"]

	check("migrated to version 11", finalVersion == 11 and data.version == 11)
	check("the build is filed under the bodyweight's class, 83 kg", typeof(build) == "table")
	check("and it is the only build (no phantom 59 kg)", countBuilds(data) == 1, tostring(countBuilds(data)))
	check("Squat CN moved exactly", build and build.competitionNumber.Squat == 182.5)
	check("Bench CN moved exactly", build and build.competitionNumber.Bench == 117.5)
	check("Deadlift CN moved exactly", build and build.competitionNumber.Deadlift == 215.0)
	check("the planted Scale moved exactly", build and build.competitionScale.Squat == 177.5
		and build.competitionScale.Bench == 105.0 and build.competitionScale.Deadlift == 212.5)
	check("best Total starts at none", build and build.bestTotalKg == PlayerProfileSchema.NO_TOTAL)
	check("the flat competitionNumber is gone", data.competitionNumber == nil)
	check("the flat competitionScale is gone", data.competitionScale == nil)
	check("the readers see the moved numbers", ProfileOperations.getCompetitionNumber(data, "Squat") == 182.5
		and ProfileOperations.getCompetitionScale(data, "Squat") == 177.5)

	-- NOTHING ACCOUNT-WIDE MOVED.
	check("technique untouched", data.technique.PressPower == 2350 and data.technique.Lockout == 128)
	check("the old budget is removed (v10)", (data :: any).competitionBudget == nil)
	check("daily allowance untouched", data.cnAllowance.spentToday == 1.5 and data.cnAllowance.dayKey == "2026-10-27")
	check("bodyweight untouched", data.bodyweight.currentKg == 82.4)
	check("meta untouched", data.meta.sessionCount == 103)

	-- A real player today: 53 kg, never competed.
	local today = reconciledV5Save(31.4, 27.0, 40.2, 53)
	today.competitionScale = { Squat = 0, Bench = 0, Deadlift = 0 }
	PlayerProfileSchema.migrate(today, 5)
	local mine = today.builds["59 kg"]
	check("a 53 kg player gets a 59 kg build", typeof(mine) == "table" and countBuilds(today) == 1)
	check("with their fractional CN kept", mine and mine.competitionNumber.Squat == 31.4
		and mine.competitionNumber.Deadlift == 40.2)
	check("and still UNPROVEN", mine and mine.competitionScale.Squat == 0)
end

--------------------------------------------------------------------------------
print("")
print("39. corrupt v5 values: CN repairs to the start, Scale to UNPROVEN")
do
	local data = reconciledV5Save(150.0, 100.0, 180.0, 70)
	data.competitionNumber.Bench = 0 / 0
	data.competitionNumber.Deadlift = -5
	data.competitionScale = { Squat = 0 / 0, Bench = "190", Deadlift = 160.0 }
	PlayerProfileSchema.migrate(data, 5)
	local build = data.builds["74 kg"]

	check("the good Squat CN kept", build and build.competitionNumber.Squat == 150.0)
	check("a NaN CN became the starting value", build and build.competitionNumber.Bench == StartingValuesConfig.Forecasted.Bench)
	check("a negative CN became the starting value", build and build.competitionNumber.Deadlift == StartingValuesConfig.Forecasted.Deadlift)
	check("a NaN Scale became UNPROVEN", build and build.competitionScale.Squat == 0)
	check("a string Scale became UNPROVEN", build and build.competitionScale.Bench == 0)
	check("the good Scale kept", build and build.competitionScale.Deadlift == 160.0)

	-- An unusable bodyweight still keeps the numbers (filed under the starting class).
	local lost = reconciledV5Save(120.0, 80.0, 140.0, 70)
	lost.bodyweight.currentKg = 0 / 0
	PlayerProfileSchema.migrate(lost, 5)
	check("an unusable bodyweight files the build under 59 kg", typeof(lost.builds["59 kg"]) == "table"
		and lost.builds["59 kg"].competitionNumber.Squat == 120.0)
end

--------------------------------------------------------------------------------
print("")
print("40. running migrations again on a version-8 profile changes nothing")
do
	local data = reconciledV5Save(200.0, 140.0, 250.0, 82.4)
	PlayerProfileSchema.migrate(data, 5)
	ProfileOperations.raiseBestTotal(data, "83 kg", 575.0)

	-- The double-migration bugs these guard against: from 5, and all the way from 2.
	data.version = 5
	PlayerProfileSchema.migrate(data, 5)
	data.version = 2
	PlayerProfileSchema.migrate(data, 2)
	local build = data.builds["83 kg"]

	check("the build's CN survived", build and build.competitionNumber.Squat == 200.0, build and tostring(build.competitionNumber.Squat))
	check("the build's Scale survived", build and build.competitionScale.Squat == 177.5)
	check("the best Total survived", build and build.bestTotalKg == 575.0)
	check("no flat field was planted back", data.competitionNumber == nil and data.competitionScale == nil)
	check("still one build", countBuilds(data) == 1)
	check("back at version 11", data.version == 11)
end

--------------------------------------------------------------------------------
print("")
print("41. a new profile gets one starting build, through migrate")
do
	local raw = deepCopy(PlayerProfileSchema.template)
	check("the template's builds are EMPTY (no phantom for Reconcile to plant)", next(raw.builds) == nil)
	PlayerProfileSchema.migrate(raw, 0)
	local build = raw.builds["59 kg"]
	check("migrate created the 59 kg build", typeof(build) == "table" and countBuilds(raw) == 1)
	check("at the starting CN", build and build.competitionNumber.Squat == StartingValuesConfig.Forecasted.Squat)
	check("UNPROVEN", build and build.competitionScale.Bench == 0)
	check("no best Total", build and build.bestTotalKg == 0)
end

--------------------------------------------------------------------------------
print("")
print("42. class changes: first entry copies the closest lighter build, return restores")
do
	local data = newProfile() :: any
	local b59 = data.builds["59 kg"]
	b59.competitionNumber.Squat = 200.0
	b59.competitionScale.Squat = 190.0
	b59.bestTotalKg = 500.0

	-- Moving UP for the first time keeps the kilograms; proof does not travel.
	local b74 = PlayerProfileSchema.ensureBuild(data, "74 kg") :: any
	check("first entry to 74 kg copies the 59 kg CN", b74 and b74.competitionNumber.Squat == 200.0)
	check("but its Scale starts UNPROVEN", b74 and b74.competitionScale.Squat == 0)
	check("and it has no best Total", b74 and b74.bestTotalKg == 0)
	check("a copy, not the same table", b74 and b74.competitionNumber ~= b59.competitionNumber)

	-- Train the 74, then go back to 59: restored exactly.
	b74.competitionNumber.Squat = 260.0
	local back = PlayerProfileSchema.ensureBuild(data, "59 kg") :: any
	check("returning to 59 kg restores it exactly", back == b59 and back.competitionNumber.Squat == 200.0
		and back.competitionScale.Squat == 190.0 and back.bestTotalKg == 500.0)
	check("and the 74 kg build kept its 260", data.builds["74 kg"].competitionNumber.Squat == 260.0)

	-- A class skipped on the way up copies the closest LIGHTER build (59), not the 74.
	local b66 = PlayerProfileSchema.ensureBuild(data, "66 kg") :: any
	check("a skipped 66 kg copies the 59 kg kg, not the heavier 74", b66 and b66.competitionNumber.Squat == 200.0)

	check("an unknown class creates nothing", PlayerProfileSchema.ensureBuild(data, "70 kg") == nil)
	check("three builds now", countBuilds(data) == 3)

	-- No lighter build at all (unreachable today): the starting values.
	local heavyOnly = newProfile() :: any
	heavyOnly.builds = { ["93 kg"] = heavyOnly.builds["59 kg"] }
	heavyOnly.builds["93 kg"].competitionNumber.Squat = 300.0
	local b83 = PlayerProfileSchema.ensureBuild(heavyOnly, "83 kg") :: any
	check("no lighter build: the starting values", b83 and b83.competitionNumber.Squat == StartingValuesConfig.Forecasted.Squat)

	-- The active build follows bodyweight.
	data.bodyweight.currentKg = 70
	check("at 70 kg the active build is 74 kg", ProfileOperations.getActiveClassKey(data) == "74 kg"
		and ProfileOperations.getCompetitionNumber(data, "Squat") == 260.0)
end

--------------------------------------------------------------------------------
print("")
print("43. the meet raises credit ONLY the named class's build")
do
	local data = newProfile() :: any
	PlayerProfileSchema.ensureBuild(data, "66 kg")

	local outcome, value = ProfileOperations.raiseCompetitionScale(data, "66 kg", "Squat", 140.0)
	check("raising the 66 kg Squat returns Raised", outcome == "Raised" and value == 140.0)
	check("the 66 kg build holds it", data.builds["66 kg"].competitionScale.Squat == 140.0)
	check("the 59 kg build did NOT get it", data.builds["59 kg"].competitionScale.Squat == 0)

	local missing = ProfileOperations.raiseCompetitionScale(data, "83 kg", "Squat", 150.0)
	check("a class with no build is Rejected and creates nothing", missing == "Rejected" and data.builds["83 kg"] == nil)
	check("a non-class key is Rejected", ProfileOperations.raiseCompetitionScale(data, "Squat" :: any, "Squat", 150.0) == "Rejected")

	-- Best Total: monotone, real totals only.
	local first, firstValue = ProfileOperations.raiseBestTotal(data, "66 kg", 400.0)
	check("first best Total is Raised", first == "Raised" and firstValue == 400.0)
	check("a lower total is Unchanged", ProfileOperations.raiseBestTotal(data, "66 kg", 380.0) == "Unchanged"
		and data.builds["66 kg"].bestTotalKg == 400.0)
	check("a higher total is Raised", ProfileOperations.raiseBestTotal(data, "66 kg", 412.5) == "Raised"
		and data.builds["66 kg"].bestTotalKg == 412.5)
	check("0 is Rejected", ProfileOperations.raiseBestTotal(data, "66 kg", 0) == "Rejected")
	check("NaN is Rejected", ProfileOperations.raiseBestTotal(data, "66 kg", 0 / 0) == "Rejected")
	check("a missing build is Rejected", ProfileOperations.raiseBestTotal(data, "93 kg", 500) == "Rejected")
	check("the 59 kg best Total is still none", data.builds["59 kg"].bestTotalKg == 0)

	local reloaded = saveAndReload(data)
	check("builds survive a save and reload", reloaded.builds["66 kg"].bestTotalKg == 412.5
		and reloaded.builds["66 kg"].competitionScale.Squat == 140.0
		and reloaded.builds["59 kg"].competitionNumber.Squat == StartingValuesConfig.Forecasted.Squat)
end

--------------------------------------------------------------------------------
print("")
print("44. version 6 to 7 removes PullStrength and nothing else (checkpoint 9)")
do
	-- A version-6 save as it is live today: one build, and the old PullStrength field.
	local data = reconciledV5Save(182.5, 117.5, 215.0, 82.4)
	PlayerProfileSchema.migrate(data, 5)
	data.version = 6
	data.technique.PullStrength = 410
	local build = data.builds["83 kg"]

	local finalVersion = PlayerProfileSchema.migrate(data, 6)
	check("migrated 6 to 11", finalVersion == 11 and data.version == 11, tostring(data.version))
	check("PullStrength is gone", data.technique.PullStrength == nil)
	check("the five technique stats are untouched", data.technique.SquatControl == 1550
		and data.technique.DepthAwareness == 975 and data.technique.StartControl == 525
		and data.technique.PressPower == 2350 and data.technique.Lockout == 128)
	check("the build is the same build, numbers exact", data.builds["83 kg"] == build
		and build.competitionNumber.Squat == 182.5 and build.competitionScale.Deadlift == 212.5
		and build.bestTotalKg == PlayerProfileSchema.NO_TOTAL)
	check("allowance, bodyweight and meta untouched (Training Energy and the budget removed)",
		(data :: any).competitionBudget == nil and data.trainingEnergy == nil
			and data.cnAllowance.spentToday == 1.5 and data.bodyweight.currentKg == 82.4
			and data.meta.sessionCount == 103)

	-- Idempotent: again from 6, and the whole chain from 2.
	PlayerProfileSchema.migrate(data, 6)
	data.version = 2
	PlayerProfileSchema.migrate(data, 2)
	check("running it again changes nothing", data.version == 11 and data.technique.PullStrength == nil
		and data.technique.Lockout == 128 and data.builds["83 kg"].competitionNumber.Squat == 182.5)

	-- A save with no technique table at all still reaches version 11 (no crash).
	local broken = reconciledV5Save(150.0, 100.0, 180.0, 53)
	PlayerProfileSchema.migrate(broken, 5)
	broken.version = 6
	broken.technique = nil
	check("a v6 save with no technique table reaches 11", PlayerProfileSchema.migrate(broken, 6) == 11)

	local reloaded = saveAndReload(data)
	check("still no PullStrength after a save and reload", reloaded.technique.PullStrength == nil)
end

--------------------------------------------------------------------------------
print("")
print("45. version 7 to 8 removes Training Energy and nothing else")
do
	-- A version-7 save: one build, the old budget, and the old trainingEnergy field.
	local data = reconciledV5Save(182.5, 117.5, 215.0, 82.4)
	PlayerProfileSchema.migrate(data, 5)
	data.version = 7
	data.trainingEnergy = { amount = 61, lastUpdatedUnix = 1700500000 }

	local finalVersion = PlayerProfileSchema.migrate(data, 7)
	check("migrated 7 to 11", finalVersion == 11 and data.version == 11, tostring(data.version))
	check("Training Energy is gone", data.trainingEnergy == nil)
	check("the old Competition Budget is gone too (v10)", (data :: any).competitionBudget == nil)
	check("CN, Scale and technique untouched", data.builds["83 kg"].competitionNumber.Squat == 182.5
		and data.builds["83 kg"].competitionScale.Deadlift == 212.5 and data.technique.Lockout == 128)
	check("allowance, bodyweight and meta untouched", data.cnAllowance.spentToday == 1.5
		and data.bodyweight.currentKg == 82.4 and data.meta.sessionCount == 103)

	PlayerProfileSchema.migrate(data, 7)
	check("running it again changes nothing", data.version == 11 and data.trainingEnergy == nil
		and (data :: any).competitionBudget == nil)

	local reloaded = saveAndReload(data)
	check("still no Training Energy after a save and reload", reloaded.trainingEnergy == nil)
end

--------------------------------------------------------------------------------
print("")
print("46. version 8 to 9: the meet CN allowance and the career (GAME_DESIGN 33.3b)")
do
	local MAX_DAYS = ProgressionConfig.MeetCnAllowance.MaxDays

	-- A version-8 save as it is live today: one build without an allowance, no career.
	local data = reconciledV5Save(182.5, 117.5, 215.0, 82.4)
	PlayerProfileSchema.migrate(data, 5)
	data.version = 8
	data.builds["83 kg"].meetAllowance = nil
	data.career = nil
	local finalVersion = PlayerProfileSchema.migrate(data, 8)
	local build = data.builds["83 kg"]
	check("migrated 8 to 11", finalVersion == 11 and data.version == 11, tostring(data.version))
	local allFull = true
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local resource = build.meetAllowance and build.meetAllowance[lift]
		if not (resource and resource.amount == MAX_DAYS and resource.lastUpdatedUnix == 0) then
			allFull = false
		end
	end
	check("every lift's allowance starts full (3 days)", allFull)
	check("the career starts at 0 Local wins", data.career and data.career.localWins == 0)
	check("CN, Scale, best Total untouched", build.competitionNumber.Squat == 182.5
		and build.competitionScale.Deadlift == 212.5 and build.bestTotalKg == PlayerProfileSchema.NO_TOTAL)
	check("daily allowance, technique, bodyweight and meta untouched (the budget removed)",
		(data :: any).competitionBudget == nil and data.cnAllowance.spentToday == 1.5
			and data.technique.Lockout == 128 and data.bodyweight.currentKg == 82.4 and data.meta.sessionCount == 103)

	-- Idempotent: a part-spent allowance and a win survive running the step again.
	build.meetAllowance.Squat = { amount = 0.75, lastUpdatedUnix = 1761600000 }
	data.career.localWins = 4
	PlayerProfileSchema.migrate(data, 8)
	check("running it again changes nothing", data.version == 11 and build.meetAllowance.Squat.amount == 0.75
		and build.meetAllowance.Squat.lastUpdatedUnix == 1761600000 and data.career.localWins == 4)
	local reloaded = saveAndReload(data)
	check("kept after a save and reload", reloaded.builds["83 kg"].meetAllowance.Squat.amount == 0.75
		and reloaded.career.localWins == 4)

	-- A new profile.
	local fresh = newProfile()
	check("a new profile has a full allowance and no wins", buildOf(fresh).meetAllowance.Bench.amount == MAX_DAYS
		and fresh.career.localWins == 0)

	-- A new build COPIES the allowance of the lighter build it copies its kg from (user, 2026-10-29).
	local upper = PlayerProfileSchema.ensureBuild(data, "93 kg")
	check("moving up copies the used-up allowance, not a fresh one", upper ~= nil
		and upper.meetAllowance.Squat.amount == 0.75 and upper.meetAllowance.Squat.lastUpdatedUnix == 1761600000
		and upper.meetAllowance.Squat ~= build.meetAllowance.Squat and upper.meetAllowance.Bench.amount == MAX_DAYS)
end

--------------------------------------------------------------------------------
print("")
print("47. settling a meet against the allowance (MeetCnAllowance, 33.3b)")
do
	local NOW = 1761800000
	-- A 100 kg squat in the 83 kg class, far below the record: one day is worth about 4%.
	local function freshData(): any
		local data = reconciledV5Save(100, 100, 100, 82.4)
		PlayerProfileSchema.migrate(data, 5)
		return data
	end
	local daily = MeetCnAllowance.dailyShare("Squat", "83 kg", 100) :: number
	check("far from the record a day is worth almost 4%", daily ~= nil and daily > 0.035 and daily <= 0.04,
		tostring(daily))
	local reference = ProgressionReferenceConfig.get("Squat", "83 kg") :: number
	check("at 0.75 of the reference a day is worth 2% (training's curve)",
		near(MeetCnAllowance.dailyShare("Squat", "83 kg", reference * 0.75) :: number, 0.02))
	check("the unlimited class has no allowance", MeetCnAllowance.dailyShare("Squat", "120+ kg", 100) == nil)

	local function settle(data: any, history: any, raises: boolean): (string, number?, number)
		return ProfileOperations.settleMeetCompetitionNumber(data, "83 kg", "Squat", 100, history, raises, NOW)
	end
	local function squat(data: any): number
		return data.builds["83 kg"].competitionNumber.Squat
	end
	local function daysLeft(data: any): number
		return data.builds["83 kg"].meetAllowance.Squat.amount
	end

	local d1 = freshData()
	local outcome, cn, used = settle(d1, { { weightKg = 110, result = "GoodLift" } }, true)
	check("a good 110 kg raises CN 100 to 110", outcome == "Raised" and near(cn :: number, 110) and near(squat(d1), 110))
	check("and uses 10% worth of days", near(used, 0.1 / daily) and near(daysLeft(d1), 3 - 0.1 / daily))

	local d2 = freshData()
	settle(d2, { { weightKg = 125, result = "GoodLift" } }, true)
	check("a good 125 kg is cut to what 3 days pay for", near(squat(d2), 100 * (1 + 3 * daily)) and near(daysLeft(d2), 0))

	local d3 = freshData()
	outcome, cn, used = settle(d3, { { weightKg = 110, result = "NoLift" } }, true)
	check("a miss at 110 kg raises nothing but uses what it would have cost", outcome == "Unchanged"
		and squat(d3) == 100 and near(used, 0.1 / daily))

	local d4 = freshData()
	settle(d4, { { weightKg = 95, result = "NoLift" } }, true)
	check("a miss at or below CN costs nothing", near(daysLeft(d4), 3))

	local d5 = freshData()
	settle(d5, { { weightKg = 104, result = "GoodLift" }, { weightKg = 106, result = "NoLift" } }, false)
	check("a bomb-out raises nothing; only the miss costs (from CN, 6%)", squat(d5) == 100
		and near(daysLeft(d5), 3 - 0.06 / daily))

	local d6 = freshData()
	settle(d6, { { weightKg = 105, result = "GoodLift" }, { weightKg = 112.5, result = "NoLift" } }, true)
	check("in order: good 105 then a miss at 112.5 uses the rest", near(squat(d6), 105) and near(daysLeft(d6), 0))

	local d7 = freshData()
	d7.builds["83 kg"].meetAllowance.Squat = { amount = 0, lastUpdatedUnix = NOW }
	check("empty: a raise waits for the refill", select(1, ProfileOperations.settleMeetCompetitionNumber(d7, "83 kg",
		"Squat", 100, { { weightKg = 104, result = "GoodLift" } }, true, NOW)) == "Unchanged" and squat(d7) == 100)
	check("half a day back after 12 hours", near(MeetCnAllowance.daysAvailable(d7.builds["83 kg"].meetAllowance.Squat,
		NOW + 12 * HOUR), 0.5))
	check("never more than 3 days, however long offline",
		near(MeetCnAllowance.daysAvailable(d7.builds["83 kg"].meetAllowance.Squat, NOW + 30 * DAY), 3))
	check("the lobby's share is days x one day's worth", near(ProfileOperations.getMeetAllowanceShare(d7, "83 kg",
		"Squat", NOW + DAY) :: number, daily))

	local d8 = freshData()
	d8.builds["83 kg"].competitionNumber.Squat = 120
	outcome = settle(d8, { { weightKg = 110, result = "GoodLift" } }, true)
	check("monotone: a CN already above the result stays", outcome == "Unchanged" and squat(d8) == 120)

	local d9 = freshData()
	PlayerProfileSchema.ensureBuild(d9, "120+ kg")
	outcome = ProfileOperations.settleMeetCompetitionNumber(d9, "120+ kg", "Squat", 100,
		{ { weightKg = 110, result = "GoodLift" } }, true, NOW)
	check("the unlimited class is never raised", outcome == "Rejected" and d9.builds["120+ kg"].competitionNumber.Squat == 100)
	check("a corrupt allowance copies as full", MeetCnAllowance.copy({ amount = 0 / 0, lastUpdatedUnix = 1 }).amount == 3)

	local d10 = freshData()
	check("a Local win counts", ProfileOperations.addLocalWin(d10) == 1 and ProfileOperations.addLocalWin(d10) == 2)
	d10.career = { localWins = 0 / 0 }
	check("a corrupt career is refused", ProfileOperations.addLocalWin(d10) == nil)
end

--------------------------------------------------------------------------------
print("")
print("48. version 9 to 10 removes the Competition Budget and nothing else")
do
	-- A version-9 save as it is live today: builds with a part-used meet allowance, a win, and the old budget.
	local data = reconciledV5Save(182.5, 117.5, 215.0, 82.4)
	PlayerProfileSchema.migrate(data, 5)
	data.version = 9
	data.competitionBudget = {
		Squat = { amount = 2.75, lastUpdatedUnix = 1700500000 },
		Bench = { amount = 9.43, lastUpdatedUnix = 0 },
		Deadlift = { amount = 9.43, lastUpdatedUnix = 0 },
	}
	local build = data.builds["83 kg"]
	build.meetAllowance.Squat = { amount = 0.75, lastUpdatedUnix = 1761600000 }
	data.career.localWins = 3

	local finalVersion = PlayerProfileSchema.migrate(data, 9)
	check("migrated 9 to 11", finalVersion == 11 and data.version == 11, tostring(data.version))
	check("the Competition Budget is gone", (data :: any).competitionBudget == nil)
	check("the meet allowance and the wins are untouched", build.meetAllowance.Squat.amount == 0.75
		and build.meetAllowance.Squat.lastUpdatedUnix == 1761600000 and data.career.localWins == 3)
	check("CN, Scale, technique, daily counters, bodyweight and meta untouched",
		build.competitionNumber.Squat == 182.5 and build.competitionScale.Deadlift == 212.5
			and data.technique.Lockout == 128 and data.cnAllowance.spentToday == 1.5
			and data.bodyweight.currentKg == 82.4 and data.meta.sessionCount == 103)

	PlayerProfileSchema.migrate(data, 9)
	check("running it again changes nothing", data.version == 11 and (data :: any).competitionBudget == nil
		and build.meetAllowance.Squat.amount == 0.75)
	check("still gone after a save and reload", (saveAndReload(data) :: any).competitionBudget == nil)
end

--------------------------------------------------------------------------------
print("")
print("49. version 10 to 11 adds empty official-meet bests; the raise is monotone")
do
	-- A version-10 save as it is live today: one build with a Scale, a best Total and a part-used allowance.
	local data = reconciledV5Save(182.5, 117.5, 215.0, 82.4)
	PlayerProfileSchema.migrate(data, 5)
	local build = data.builds["83 kg"]
	build.bestTotalKg = 500.0
	build.meetAllowance.Squat = { amount = 0.75, lastUpdatedUnix = 1761600000 };
	(build :: any).officialMeetBest = nil
	data.version = 10

	local finalVersion = PlayerProfileSchema.migrate(data, 10)
	check("migrated 10 to 11", finalVersion == 11 and data.version == 11, tostring(data.version))
	check("every lift's official best starts empty", build.officialMeetBest.Squat == PlayerProfileSchema.NO_OFFICIAL_BEST
		and build.officialMeetBest.Bench == 0 and build.officialMeetBest.Deadlift == 0)
	check("CN, Scale, best Total, allowance and wins untouched", build.competitionNumber.Squat == 182.5
		and build.competitionScale.Deadlift == 212.5 and build.bestTotalKg == 500.0
		and build.meetAllowance.Squat.amount == 0.75 and data.career.localWins == 0)

	-- The raise: heavier only, never touching Scale.
	local outcome, kg = ProfileOperations.raiseOfficialMeetBest(data, "83 kg", "Squat", 190.0)
	check("a first good lift is saved", outcome == "Raised" and kg == 190.0 and build.officialMeetBest.Squat == 190.0)
	outcome, kg = ProfileOperations.raiseOfficialMeetBest(data, "83 kg", "Squat", 190.0)
	check("an equal lift changes nothing", outcome == "Unchanged" and kg == 190.0)
	outcome = ProfileOperations.raiseOfficialMeetBest(data, "83 kg", "Squat", 185.0)
	check("a lighter lift changes nothing", outcome == "Unchanged" and build.officialMeetBest.Squat == 190.0)
	check("Scale is not touched", build.competitionScale.Squat ~= 190.0)
	check("0 kg, NaN and a bad lift are refused",
		ProfileOperations.raiseOfficialMeetBest(data, "83 kg", "Squat", 0) == "Rejected"
			and ProfileOperations.raiseOfficialMeetBest(data, "83 kg", "Squat", 0 / 0) == "Rejected"
			and ProfileOperations.raiseOfficialMeetBest(data, "83 kg", "Curl", 50) == "Rejected"
			and build.officialMeetBest.Squat == 190.0)
	check("a class without a build is refused (no build created)",
		ProfileOperations.raiseOfficialMeetBest(data, "93 kg", "Squat", 200) == "Rejected" and data.builds["93 kg"] == nil)

	-- The wall's Total: only once all three lifts have a best.
	check("no wall Total with one best", ProfileOperations.getOfficialMeetBestTotal(data, "83 kg") == nil)
	ProfileOperations.raiseOfficialMeetBest(data, "83 kg", "Bench", 120.0)
	ProfileOperations.raiseOfficialMeetBest(data, "83 kg", "Deadlift", 230.0)
	check("the wall Total is the three bests added", ProfileOperations.getOfficialMeetBestTotal(data, "83 kg") == 540.0)

	PlayerProfileSchema.migrate(data, 10)
	check("running it again changes nothing", data.version == 11 and build.officialMeetBest.Squat == 190.0)
	local reloaded = saveAndReload(data)
	check("the bests survive a save and reload", reloaded.builds["83 kg"].officialMeetBest.Deadlift == 230.0)

	-- A new build (a class entered for the first time) starts with no bests.
	local moved = PlayerProfileSchema.ensureBuild(data, "93 kg")
	check("a new build has no official bests", moved ~= nil and moved.officialMeetBest.Squat == 0
		and moved.officialMeetBest.Bench == 0 and moved.officialMeetBest.Deadlift == 0)
end

--------------------------------------------------------------------------------
print("")
print(string.format("=== %d passed, %d failed ===", passed, failed))

if failed > 0 then
	warn("[PlayerDataProbe] PERSISTENCE FOUNDATION HAS FAILING CHECKS. Do not build on it yet.")
end
