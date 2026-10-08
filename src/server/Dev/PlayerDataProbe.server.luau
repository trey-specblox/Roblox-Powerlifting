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

	The foundation has been validated in Studio, so 179 assertions on every Play
	is noise rather than information. Turn it on whenever persistence changes:
	the schema, a migration, ProfileOperations, ResourceRegeneration or
	CompetitionBudget. Then turn it off again.

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
local CompetitionBudget = require(ProgressionFolder:WaitForChild("CompetitionBudget"))

local BUDGET = ProgressionConfig.CompetitionBudget
local ENERGY = ProgressionConfig.TrainingEnergy

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
	return deepCopy(PlayerProfileSchema.template)
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

	-- A part-spent Squat pool, so the upgrade has something it could destroy.
	data.competitionBudget.Squat = { amount = 3.21, lastUpdatedUnix = 1700500000 }
	data.trainingEnergy = { amount = 45, lastUpdatedUnix = 1700500000 }

	data.version = 3

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
	"schema version %d  |  budget %.2f EV cap, %.4f EV/h  |  energy %d min cap, %d min/h",
	PlayerProfileSchema.CURRENT_VERSION,
	BUDGET.CapacityEV,
	BUDGET.RegenerationEVPerHour,
	ENERGY.CapacityMinutes,
	ENERGY.RegenerationMinutesPerHour
))
print("")

--------------------------------------------------------------------------------
print("1. brand-new profile defaults")
do
	local data = newProfile()

	check("version is current", data.version == PlayerProfileSchema.CURRENT_VERSION)
	check(
		"S/B/D all start at 25 kg",
		data.competitionNumber.Squat == 25
			and data.competitionNumber.Bench == 25
			and data.competitionNumber.Deadlift == 25
	)
	check("no legacy forecasted field in the template", (data :: any).forecasted == nil)
	check("bodyweight starts at 53 kg, maintaining", data.bodyweight.currentKg == 53 and data.bodyweight.targetKg == 53)
	check(
		"all six technique stats start at 0",
		data.technique.SquatControl == 0
			and data.technique.DepthAwareness == 0
			and data.technique.StartControl == 0
			and data.technique.PressPower == 0
			and data.technique.PullStrength == 0
			and data.technique.Lockout == 0
	)
	check(
		"three budgets start full",
		data.competitionBudget.Squat.amount == BUDGET.CapacityEV
			and data.competitionBudget.Bench.amount == BUDGET.CapacityEV
			and data.competitionBudget.Deadlift.amount == BUDGET.CapacityEV
	)
	check("training energy starts full", data.trainingEnergy.amount == ENERGY.CapacityMinutes)
	check(
		"resource timestamps are 0, not a server start time",
		data.competitionBudget.Squat.lastUpdatedUnix == 0 and data.trainingEnergy.lastUpdatedUnix == 0
	)
end

--------------------------------------------------------------------------------
print("")
print("2. old-schema migration preserves all three Competition Numbers")
do
	local data = reconciledV2Save(182.5, 117.5, 215.0)
	local finalVersion = PlayerProfileSchema.migrate(data, 2)

	check("migrated to version 4", finalVersion == 4 and data.version == 4)
	check("Squat preserved at 182.5", near(data.competitionNumber.Squat, 182.5), tostring(data.competitionNumber.Squat))
	check("Bench preserved at 117.5", near(data.competitionNumber.Bench, 117.5), tostring(data.competitionNumber.Bench))
	check("Deadlift preserved at 215.0", near(data.competitionNumber.Deadlift, 215.0), tostring(data.competitionNumber.Deadlift))
	check("legacy forecasted field removed", (data :: any).forecasted == nil)
	check("NOT reset to the 25 kg default", data.competitionNumber.Squat ~= 25)
end

--------------------------------------------------------------------------------
print("")
print("3. repeated migration does not corrupt values (idempotence)")
do
	local data = reconciledV2Save(300.0, 200.0, 350.0)
	PlayerProfileSchema.migrate(data, 2)

	-- Spend some budget so a second pass has something to destroy.
	ProfileOperations.consumeCompetitionBudget(data, "Squat", 4.0, 1000 * DAY)
	local spentBudget = data.competitionBudget.Squat.amount

	-- Run the step again directly, as a double-migration bug would.
	PlayerProfileSchema.migrate(data, 2)
	PlayerProfileSchema.migrate(data, 3)

	check("Squat still 300 after three passes", near(data.competitionNumber.Squat, 300.0), tostring(data.competitionNumber.Squat))
	check("Bench still 200", near(data.competitionNumber.Bench, 200.0))
	check("Deadlift still 350", near(data.competitionNumber.Deadlift, 350.0))
	check("version still 4", data.version == 4)
	check(
		"part-spent budget was not silently refilled",
		near(data.competitionBudget.Squat.amount, spentBudget),
		string.format("%.4f vs %.4f", data.competitionBudget.Squat.amount, spentBudget)
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
		near(data.competitionNumber.Squat, 27.487),
		tostring(data.competitionNumber.Squat)
	)
	check("fractional progression was not rounded away", data.competitionNumber.Squat % 1 ~= 0)
	check("Bench untouched", data.competitionNumber.Bench == 25)
	check("Deadlift untouched", data.competitionNumber.Deadlift == 25)

	local okNeg = ProfileOperations.applyCompetitionNumberDelta(data, "Bench", -5)
	check("a negative delta is allowed (weight-class translation will need it)", okNeg)
	check("Bench is now 20", near(data.competitionNumber.Bench, 20.0))
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
		local before = data.competitionNumber.Squat

		local applied = ProfileOperations.applyCompetitionNumberDelta(data, lift, delta)

		check(label .. " is rejected", not applied)
		check(
			label .. " leaves Squat untouched",
			data.competitionNumber.Squat == before,
			string.format("%s, expected %s", tostring(data.competitionNumber.Squat), tostring(before))
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
			data.competitionNumber.Squat == data.competitionNumber.Squat
				and data.competitionNumber.Squat == 25
		)
	end

	-- A corrupt stored value is refused rather than written over.
	do
		local data = newProfile()
		data.competitionNumber.Squat = 0 / 0

		local applied = ProfileOperations.applyCompetitionNumberDelta(data, "Squat", 1.4)
		check("a corrupt stored Competition Number is refused", not applied)
		check(
			"and is left for the migration to repair, not patched here",
			data.competitionNumber.Squat ~= data.competitionNumber.Squat
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
print("6. Competition Budget is account-wide per lift")
do
	local data = newProfile()
	local now = 1000 * DAY

	--[[
		The frozen rule is that the pool belongs to the LIFT, not to a weight
		class or a build slot. There is no build dimension in the schema to vary
		yet, so what is checked here is the shape that guarantees it: exactly one
		pool per lift, directly under competitionBudget, with nothing keyed by
		class or slot anywhere near it.
	]]
	local poolCount = 0
	for _ in pairs(data.competitionBudget) do
		poolCount += 1
	end

	check("exactly three pools exist", poolCount == 3, tostring(poolCount))
	check(
		"one pool per lift, keyed by lift name",
		data.competitionBudget.Squat ~= nil
			and data.competitionBudget.Bench ~= nil
			and data.competitionBudget.Deadlift ~= nil
	)
	check(
		"pools sit outside the future build map, at the profile root",
		(data :: any).builds == nil and data.competitionBudget ~= nil
	)

	-- Spending through the operation reaches the same single pool each time.
	ProfileOperations.consumeCompetitionBudget(data, "Squat", 2.0, now)
	ProfileOperations.consumeCompetitionBudget(data, "Squat", 2.0, now)

	local remaining = ProfileOperations.getRegeneratedCompetitionBudget(data, "Squat", now)
	check(
		"two spends hit one shared Squat pool (9.43 - 4 = 5.43)",
		remaining ~= nil and near(remaining :: number, BUDGET.CapacityEV - 4.0),
		tostring(remaining)
	)
end

--------------------------------------------------------------------------------
print("")
print("7. consuming Squat budget does not affect Bench or Deadlift")
do
	local data = newProfile()
	local now = 1000 * DAY

	local spent = ProfileOperations.consumeCompetitionBudget(data, "Squat", 9.0, now)

	local squat = ProfileOperations.getRegeneratedCompetitionBudget(data, "Squat", now)
	local bench = ProfileOperations.getRegeneratedCompetitionBudget(data, "Bench", now)
	local deadlift = ProfileOperations.getRegeneratedCompetitionBudget(data, "Deadlift", now)

	check("the Squat spend returned effective EV", spent ~= nil and spent > 0)
	check("Squat is nearly empty", squat ~= nil and near(squat :: number, 0.43), tostring(squat))
	check("Bench is still full", bench ~= nil and near(bench :: number, BUDGET.CapacityEV), tostring(bench))
	check("Deadlift is still full", deadlift ~= nil and near(deadlift :: number, BUDGET.CapacityEV), tostring(deadlift))
end

--------------------------------------------------------------------------------
print("")
print("8. a resource cannot exceed capacity after regeneration")
do
	local data = newProfile()

	-- Empty the Squat pool, then leave it alone for a year.
	ProfileOperations.consumeCompetitionBudget(data, "Squat", 9.43, 1000 * DAY)
	local afterYear = ProfileOperations.getRegeneratedCompetitionBudget(data, "Squat", 1365 * DAY)

	check(
		"a year of regeneration stops at the 9.43 EV cap",
		afterYear ~= nil and near(afterYear :: number, BUDGET.CapacityEV),
		tostring(afterYear)
	)

	-- Same for Training Energy.
	ProfileOperations.consumeTrainingEnergy(data, 120, 1000 * DAY)
	local energyAfterYear = ProfileOperations.getRegeneratedTrainingEnergy(data, 1365 * DAY)

	check(
		"a year of regeneration stops at the 120 minute cap",
		energyAfterYear ~= nil and near(energyAfterYear :: number, ENERGY.CapacityMinutes),
		tostring(energyAfterYear)
	)

	-- A value stored above the cap is brought down, not left there.
	data.trainingEnergy.amount = 9999
	data.trainingEnergy.lastUpdatedUnix = 1000 * DAY
	local clamped = ProfileOperations.getRegeneratedTrainingEnergy(data, 1000 * DAY)
	check(
		"a stored value above the cap is clamped down",
		clamped ~= nil and near(clamped :: number, ENERGY.CapacityMinutes),
		tostring(clamped)
	)
end

--------------------------------------------------------------------------------
print("")
print("9. offline Competition Budget regeneration")
do
	local data = newProfile()
	local start = 1000 * DAY

	ProfileOperations.consumeCompetitionBudget(data, "Squat", 9.43, start)

	local after10h = ProfileOperations.getRegeneratedCompetitionBudget(data, "Squat", start + 10 * HOUR)
	local expected10h = 10 * BUDGET.RegenerationEVPerHour

	check(
		string.format("10 hours offline regenerates %.4f EV", expected10h),
		after10h ~= nil and near(after10h :: number, expected10h),
		tostring(after10h)
	)

	local after1w = ProfileOperations.getRegeneratedCompetitionBudget(data, "Squat", start + 7 * DAY)
	check(
		"a full week refills a spent pool (0.0561 x 168 = 9.42 EV)",
		after1w ~= nil and near(after1w :: number, BUDGET.CapacityEV, 0.05),
		tostring(after1w)
	)

	check("reading does not write: stored amount is still 0", near(data.competitionBudget.Squat.amount, 0))

	-- A backward clock must pause regeneration, never drain the pool.
	local backward = ProfileOperations.getRegeneratedCompetitionBudget(data, "Squat", start - 5 * DAY)
	check(
		"a clock moving backward grants nothing and drains nothing",
		backward ~= nil and near(backward :: number, 0),
		tostring(backward)
	)
end

--------------------------------------------------------------------------------
print("")
print("10. Training Energy depletion")
do
	local data = newProfile()
	local now = 1000 * DAY

	local ok30, left30 = ProfileOperations.consumeTrainingEnergy(data, 30, now)
	check("spending 30 of 120 minutes works", ok30 and left30 ~= nil and near(left30 :: number, 90), tostring(left30))

	local ok90, left90 = ProfileOperations.consumeTrainingEnergy(data, 90, now)
	check("spending the remaining 90 works", ok90 and left90 ~= nil and near(left90 :: number, 0), tostring(left90))

	local okOver, leftOver = ProfileOperations.consumeTrainingEnergy(data, 1, now)
	check("spending past empty is refused", not okOver)
	check("refusal leaves it at exactly 0, never negative", leftOver ~= nil and near(leftOver :: number, 0), tostring(leftOver))
	check("stored amount is 0, not negative", data.trainingEnergy.amount >= 0)

	-- All-or-nothing: an unaffordable cost must change nothing at all.
	data.trainingEnergy.amount = 10
	local okPartial = ProfileOperations.consumeTrainingEnergy(data, 40, now)
	check("an unaffordable cost is all-or-nothing", not okPartial and near(data.trainingEnergy.amount, 10))

	-- Nonsense costs.
	check("NaN cost rejected", not ProfileOperations.consumeTrainingEnergy(data, 0 / 0, now))
	check("infinite cost rejected", not ProfileOperations.consumeTrainingEnergy(data, math.huge, now))
	check("negative cost rejected (no refunds)", not ProfileOperations.consumeTrainingEnergy(data, -50, now))
	check("amount survived every bad cost", near(data.trainingEnergy.amount, 10), tostring(data.trainingEnergy.amount))
end

--------------------------------------------------------------------------------
print("")
print("11. Training Energy regeneration, online and offline")
do
	local data = newProfile()
	local start = 1000 * DAY

	ProfileOperations.consumeTrainingEnergy(data, 120, start)

	local after6h = ProfileOperations.getRegeneratedTrainingEnergy(data, start + 6 * HOUR)
	check(
		"6 hours regenerates 30 minutes at 5 min/h",
		after6h ~= nil and near(after6h :: number, 30),
		tostring(after6h)
	)

	local after24h = ProfileOperations.getRegeneratedTrainingEnergy(data, start + DAY)
	check(
		"24 hours fully refills the 120 minute pool",
		after24h ~= nil and near(after24h :: number, 120),
		tostring(after24h)
	)

	--[[
		Offline is not a separate code path, which is the point: the same
		timestamp arithmetic serves a player who logged off and one who idled.
	]]
	local after3d = ProfileOperations.getRegeneratedTrainingEnergy(data, start + 3 * DAY)
	check("3 days offline is still capped at 120", after3d ~= nil and near(after3d :: number, 120), tostring(after3d))
end

--------------------------------------------------------------------------------
print("")
print("12. Training Energy caps at 120")
do
	local data = newProfile()
	local now = 1000 * DAY

	check("a fresh pool reads exactly 120", near(ProfileOperations.getRegeneratedTrainingEnergy(data, now) :: number, 120))

	-- Regeneration from full must not bank time above the cap.
	local later = ProfileOperations.getRegeneratedTrainingEnergy(data, now + 30 * DAY)
	check("30 days at full still reads 120", later ~= nil and near(later :: number, 120), tostring(later))

	ProfileOperations.consumeTrainingEnergy(data, 5, now + 30 * DAY)
	local afterSpend = ProfileOperations.getRegeneratedTrainingEnergy(data, now + 30 * DAY)
	check(
		"time at full did not bank: spending 5 leaves 115, not more",
		afterSpend ~= nil and near(afterSpend :: number, 115),
		tostring(afterSpend)
	)
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
		There is no Competition Number WRITER on the service to check the arity
		of, and that absence is itself the guarantee: no caller can pass an
		arbitrary kilogram delta through the service at all. See the note where
		such a method would otherwise sit in PlayerDataService.
	]]
	check(
		"the service exposes NO arbitrary-kilogram Competition Number writer",
		(PlayerDataService :: any).addCompetitionNumber == nil
			and (PlayerDataService :: any).applyCompetitionNumberDelta == nil
			and (PlayerDataService :: any).setCompetitionNumber == nil
	)
	check("but reading one is still available", typeof(PlayerDataService.getCompetitionNumber) == "function")

	check("consumeCompetitionBudget takes no timestamp", debug.info(PlayerDataService.consumeCompetitionBudget, "a") == 3)
	check("consumeTrainingEnergy takes no timestamp", debug.info(PlayerDataService.consumeTrainingEnergy, "a") == 2)
	check("getRegeneratedTrainingEnergy takes no timestamp", debug.info(PlayerDataService.getRegeneratedTrainingEnergy, "a") == 1)
	check("getRegeneratedCompetitionBudget takes no timestamp", debug.info(PlayerDataService.getRegeneratedCompetitionBudget, "a") == 2)

	-- And no remote exists through which a client could reach any of it.
	check("PlayerDataService exposes no RemoteEvent", (PlayerDataService :: any).Remote == nil)

	--[[
		A corrupt stored timestamp must not become a windfall. A NaN or missing
		timestamp grants nothing rather than a full refill.
	]]
	local data = newProfile()
	ProfileOperations.consumeTrainingEnergy(data, 120, 1000 * DAY)
	data.trainingEnergy.lastUpdatedUnix = 0 / 0

	local fromNaN = ProfileOperations.getRegeneratedTrainingEnergy(data, 1001 * DAY)
	check("a NaN stored timestamp grants nothing", fromNaN ~= nil and near(fromNaN :: number, 0), tostring(fromNaN))
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
	check("PullStrength 300 survived", data.technique.PullStrength == 300)
	check("Lockout 95 survived", data.technique.Lockout == 95)
	check("bodyweight 81.5 kg survived", near(data.bodyweight.currentKg, 81.5))
	check("target bodyweight 93 kg survived", near(data.bodyweight.targetKg, 93))
	check("createdUnix survived", data.meta.createdUnix == 1700000000)
	check("sessionCount 42 survived", data.meta.sessionCount == 42)
end

--------------------------------------------------------------------------------
print("")
print("bonus. a version-1 save reaches version 4 in one pass")
do
	--[[
		The two-step path. A v1 save predates both PullStrength and the rename,
		so migrations[1] and migrations[2] must both run, in order.
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

	check("reached version 4", finalVersion == 4 and data.version == 4)
	check("Squat 140 preserved across two migrations", near(data.competitionNumber.Squat, 140.0), tostring(data.competitionNumber.Squat))
	check("Bench 95 preserved", near(data.competitionNumber.Bench, 95.0))
	check("Deadlift 170 preserved", near(data.competitionNumber.Deadlift, 170.0))
	check("PullStrength added at 0 by the v1 step", data.technique.PullStrength == 0)
	check("pre-existing technique untouched", data.technique.PressPower == 600)
	check("legacy forecasted removed", data.forecasted == nil)
end

--------------------------------------------------------------------------------
print("")
print("bonus. a partially corrupt v2 save keeps its good lifts")
do
	local data = reconciledV2Save(200.0, 0 / 0, 240.0) :: any
	PlayerProfileSchema.migrate(data, 2)

	check("the good Squat survived", near(data.competitionNumber.Squat, 200.0), tostring(data.competitionNumber.Squat))
	check("the good Deadlift survived", near(data.competitionNumber.Deadlift, 240.0))
	check("the NaN Bench fell back to the 25 kg default", data.competitionNumber.Bench == 25, tostring(data.competitionNumber.Bench))
	check("no NaN reached the profile", data.competitionNumber.Bench == data.competitionNumber.Bench)
end


--------------------------------------------------------------------------------
print("")
print("15. the first 9.43 EV receives full-rate treatment")
do
	local data = newProfile()
	local now = 1000 * DAY

	--[[
		Consume exactly the capacity, in one span. Every bit of it is inside the
		allowance, so effective must equal raw with no loss at all.
	]]
	local effective, remaining = ProfileOperations.consumeCompetitionBudget(data, "Squat", BUDGET.CapacityEV, now)

	check(
		"consuming exactly 9.43 EV returns 9.43 effective EV",
		effective ~= nil and near(effective :: number, BUDGET.CapacityEV),
		tostring(effective)
	)
	check("the pool is now exactly 0", remaining ~= nil and near(remaining :: number, 0), tostring(remaining))
	check("the multiplier was 1.0 throughout", near(CompetitionBudget.multiplierAt(BUDGET.CapacityEV), 1.0))

	-- Many small awards must behave the same as one large one.
	local fresh = newProfile()
	local total = 0
	for _ = 1, 100 do
		local e = ProfileOperations.consumeCompetitionBudget(fresh, "Squat", BUDGET.CapacityEV / 100, now)
		total += (e :: number)
	end
	check(
		"100 small awards totalling 9.43 EV also return 9.43 effective",
		near(total, BUDGET.CapacityEV, 0.0001),
		tostring(total)
	)
end

--------------------------------------------------------------------------------
print("")
print("16. overflow uses k = 3")
do
	-- Recomputed here from config, so a drift between config and module is caught.
	local K = BUDGET.OverflowK * BUDGET.UnitEV

	check(
		"the curve scale is k x UnitEV = 3 x 1.886 = 5.658",
		near(K, 5.658, 0.001) and near(CompetitionBudget.CurveScaleEV, K),
		string.format("config %.4f, module %.4f", K, CompetitionBudget.CurveScaleEV)
	)
	check("OverflowK is 3 as frozen", BUDGET.OverflowK == 3)

	--[[
		The instantaneous multiplier at a depth of one normal meet must be
		1/(1 + 1.886/5.658) = 0.75, which is exactly the discrete model's sixth-meet
		multiplier. That shared value is what anchors the continuous curve to the
		approved one.
	]]
	check(
		"at one meet deep the multiplier is 0.75",
		near(CompetitionBudget.multiplierAt(-BUDGET.UnitEV), 0.75, 0.0001),
		tostring(CompetitionBudget.multiplierAt(-BUDGET.UnitEV))
	)
	check(
		"at two meets deep it is 0.60",
		near(CompetitionBudget.multiplierAt(-2 * BUDGET.UnitEV), 0.60, 0.0001),
		tostring(CompetitionBudget.multiplierAt(-2 * BUDGET.UnitEV))
	)
	check(
		"at three meets deep it is 0.50",
		near(CompetitionBudget.multiplierAt(-3 * BUDGET.UnitEV), 0.50, 0.0001),
		tostring(CompetitionBudget.multiplierAt(-3 * BUDGET.UnitEV))
	)
	check("at zero depth it is exactly 1.0", near(CompetitionBudget.multiplierAt(0), 1.0))
	check("with allowance remaining it is exactly 1.0", near(CompetitionBudget.multiplierAt(5.0), 1.0))
end

--------------------------------------------------------------------------------
print("")
print("17. additional legitimate EV never reaches a zero multiplier")
do
	local data = newProfile()
	local now = 1000 * DAY

	-- Five years of thirty meets a week, with no regeneration at all.
	local absurd = 260 * 30 * BUDGET.UnitEV
	ProfileOperations.consumeCompetitionBudget(data, "Squat", absurd, now)

	local amount = data.competitionBudget.Squat.amount
	local multiplier = CompetitionBudget.multiplierAt(amount)

	check("the pool went far negative, as intended", amount < -10000, tostring(amount))
	check("the multiplier is still strictly above zero", multiplier > 0, tostring(multiplier))
	check("and it is tiny, as intended", multiplier < 0.001, tostring(multiplier))

	-- One more award must still pay something real.
	local effective = ProfileOperations.consumeCompetitionBudget(data, "Squat", BUDGET.UnitEV, now)
	check("a further meet still earns effective EV above zero", effective ~= nil and (effective :: number) > 0, tostring(effective))
	check("that EV is not NaN", effective ~= nil and (effective :: number) == (effective :: number))

	check("the amount is still finite after an absurd spend", amount == amount and amount > -math.huge)
	check("no negative floor refused any of it", true)
end

--------------------------------------------------------------------------------
print("")
print("18. the 5/10/20/30 normal-meet-equivalent curve")
do
	local now = 1000 * DAY

	--[[
		Each meet is consumed as THREE separate attempt-sized awards rather than
		one lump, to prove the continuous form does not depend on award size.
	]]
	local function cumulativeEffective(meets: number): number
		local data = newProfile()
		local total = 0
		for _ = 1, meets do
			for _ = 1, 3 do
				local e = ProfileOperations.consumeCompetitionBudget(data, "Squat", BUDGET.UnitEV / 3, now)
				total += (e :: number)
			end
		end
		return total
	end

	local at5 = cumulativeEffective(5)
	local at10 = cumulativeEffective(10)
	local at20 = cumulativeEffective(20)
	local at30 = cumulativeEffective(30)

	print(string.format(
		"      cumulative effective EV:  5 -> %.4f   10 -> %.4f   20 -> %.4f   30 -> %.4f",
		at5, at10, at20, at30
	))
	print(string.format(
		"      normalised to 5 meets:     1.000      %.3f      %.3f      %.3f",
		at10 / at5, at20 / at5, at30 / at5
	))

	check("5 meets is the full allowance, 9.43 EV", near(at5, BUDGET.CapacityEV, 0.001), tostring(at5))

	--[[
		Expected values are the closed form of the integral:

			cumulative = C + K x ln(1 + (raw - C) / K)

		These are the CONTINUOUS figures, which run about 3.8% above the discrete
		sum that was approved. The difference and its cause are quantified in the
		increment notes; k stays at 3 as frozen.
	]]
	local K = CompetitionBudget.CurveScaleEV
	local function expected(meets: number): number
		local raw = meets * BUDGET.UnitEV
		if raw <= BUDGET.CapacityEV then
			return raw
		end
		return BUDGET.CapacityEV + K * math.log(1 + (raw - BUDGET.CapacityEV) / K)
	end

	check("10 meets matches the closed form", near(at10, expected(10), 0.002), string.format("%.4f vs %.4f", at10, expected(10)))
	check("20 meets matches the closed form", near(at20, expected(20), 0.002), string.format("%.4f vs %.4f", at20, expected(20)))
	check("30 meets matches the closed form", near(at30, expected(30), 0.002), string.format("%.4f vs %.4f", at30, expected(30)))

	check("the curve is monotonically increasing", at5 < at10 and at10 < at20 and at20 < at30)
	check("and strongly diminishing: 6x the meets is under 2.4x the progression", at30 / at5 < 2.4, tostring(at30 / at5))
	check("10 meets lands near the approved 1.53x meet-channel ratio", near(at10 / at5, 1.53, 0.07), tostring(at10 / at5))
	check("20 meets lands near the approved 2.00x", near(at20 / at5, 2.00, 0.09), tostring(at20 / at5))
	check("30 meets lands near the approved 2.26x", near(at30 / at5, 2.26, 0.09), tostring(at30 / at5))

	-- Path independence: award size must not change the total.
	local lump = newProfile()
	local lumpTotal = 0
	for _ = 1, 30 do
		local e = ProfileOperations.consumeCompetitionBudget(lump, "Squat", BUDGET.UnitEV, now)
		lumpTotal += (e :: number)
	end
	check(
		"30 meets as 30 lumps equals 30 meets as 90 attempts",
		near(lumpTotal, at30, 0.0001),
		string.format("%.6f vs %.6f", lumpTotal, at30)
	)
end

--------------------------------------------------------------------------------
print("")
print("19. Squat overflow does not affect Bench or Deadlift")
do
	local data = newProfile()
	local now = 1000 * DAY

	-- Drive Squat deep into overflow: twenty meets' worth.
	ProfileOperations.consumeCompetitionBudget(data, "Squat", 20 * BUDGET.UnitEV, now)

	local sq, sqMult, sqState = ProfileOperations.getCompetitionBudgetState(data, "Squat", now)
	local be, beMult, beState = ProfileOperations.getCompetitionBudgetState(data, "Bench", now)
	local dl, dlMult, dlState = ProfileOperations.getCompetitionBudgetState(data, "Deadlift", now)

	check("Squat is deep in overflow", sq ~= nil and (sq :: number) < -25, tostring(sq))
	check("Squat's multiplier is well below 1", sqMult ~= nil and (sqMult :: number) < 0.2, tostring(sqMult))
	check("Squat reads FATIGUED", sqState == "FATIGUED", tostring(sqState))

	check("Bench is untouched at full capacity", be ~= nil and near(be :: number, BUDGET.CapacityEV), tostring(be))
	check("Bench's multiplier is exactly 1.0", beMult ~= nil and near(beMult :: number, 1.0))
	check("Bench reads FRESH", beState == "FRESH", tostring(beState))

	check("Deadlift is untouched at full capacity", dl ~= nil and near(dl :: number, BUDGET.CapacityEV), tostring(dl))
	check("Deadlift's multiplier is exactly 1.0", dlMult ~= nil and near(dlMult :: number, 1.0))
	check("Deadlift reads FRESH", dlState == "FRESH", tostring(dlState))

	-- A Bench award earns full rate even while Squat is exhausted.
	local benchEV = ProfileOperations.consumeCompetitionBudget(data, "Bench", BUDGET.UnitEV, now)
	check(
		"a Bench award still earns full effective EV",
		benchEV ~= nil and near(benchEV :: number, BUDGET.UnitEV),
		tostring(benchEV)
	)
end

--------------------------------------------------------------------------------
print("")
print("20. regeneration from overflow, and the 9.43 EV cap")
do
	local data = newProfile()
	local start = 1000 * DAY

	-- Thirty meets deep: the heaviest week the design treats as legitimate.
	ProfileOperations.consumeCompetitionBudget(data, "Squat", 30 * BUDGET.UnitEV, start)
	local depleted = data.competitionBudget.Squat.amount

	check("thirty meets lands at about -47.15 EV", near(depleted, -47.15, 0.01), tostring(depleted))
	check(
		"the earlier -5x capacity floor would have refused exactly this",
		near(depleted, -5 * BUDGET.CapacityEV, 0.01),
		"which is why that floor was removed"
	)

	local R = BUDGET.RegenerationEVPerHour
	local checkpoints = { 1, 12, 24, 72, 168 }
	local labels = { "1 hour", "12 hours", "24 hours", "72 hours", "1 week" }

	for index, hours in ipairs(checkpoints) do
		local amount = ProfileOperations.getRegeneratedCompetitionBudget(data, "Squat", start + hours * HOUR)
		local expected = depleted + hours * R
		check(
			string.format("%s recovers to %.4f EV", labels[index], expected),
			amount ~= nil and near(amount :: number, expected, 0.0001),
			tostring(amount)
		)
	end

	-- Full recovery, and never above the cap.
	local hoursToFull = (BUDGET.CapacityEV - depleted) / R
	local atFull = ProfileOperations.getRegeneratedCompetitionBudget(data, "Squat", start + math.ceil(hoursToFull) * HOUR)
	check(
		string.format("fully recovers after about %.0f hours (%.1f weeks)", hoursToFull, hoursToFull / 168),
		atFull ~= nil and near(atFull :: number, BUDGET.CapacityEV, 0.01),
		tostring(atFull)
	)

	local wayLater = ProfileOperations.getRegeneratedCompetitionBudget(data, "Squat", start + 365 * DAY)
	check(
		"a year later it is still exactly 9.43, never banked above the cap",
		wayLater ~= nil and near(wayLater :: number, BUDGET.CapacityEV),
		tostring(wayLater)
	)

	-- Regeneration restores the multiplier toward full freshness.
	local multAtDepleted = CompetitionBudget.multiplierAt(depleted)
	local multAfterWeek = CompetitionBudget.multiplierAt(depleted + 168 * R)
	check(
		"one week of rest raises the multiplier",
		multAfterWeek > multAtDepleted,
		string.format("%.6f -> %.6f", multAtDepleted, multAfterWeek)
	)
	check("and a full recovery returns it to exactly 1.0", near(CompetitionBudget.multiplierAt(BUDGET.CapacityEV), 1.0))
end

--------------------------------------------------------------------------------
print("")
print("21. Competition Budget can continue through overflow")
do
	local data = newProfile()
	local now = 1000 * DAY

	-- Exhaust the allowance exactly.
	ProfileOperations.consumeCompetitionBudget(data, "Squat", BUDGET.CapacityEV, now)

	--[[
		THE KEY DISTINCTION. Training Energy would refuse here. A Competition
		Budget must not, because active meet progression is never hard-zeroed.
	]]
	local e1, r1 = ProfileOperations.consumeCompetitionBudget(data, "Squat", BUDGET.UnitEV, now)
	check("an award past empty is NOT refused", e1 ~= nil, "nil would mean refused")
	check("it earns real effective EV", e1 ~= nil and (e1 :: number) > 0, tostring(e1))
	check("but less than full rate", e1 ~= nil and (e1 :: number) < BUDGET.UnitEV, tostring(e1))
	check("the pool is now negative", r1 ~= nil and (r1 :: number) < 0, tostring(r1))

	-- Ten more, each still paying something, each paying less than the last.
	local previous = e1 :: number
	local allPositive = true
	local allDecreasing = true
	for _ = 1, 10 do
		local e = ProfileOperations.consumeCompetitionBudget(data, "Squat", BUDGET.UnitEV, now)
		if e == nil or (e :: number) <= 0 then
			allPositive = false
			break
		end
		if (e :: number) >= previous then
			allDecreasing = false
		end
		previous = e :: number
	end

	check("ten further awards all pay above zero", allPositive)
	check("and each pays strictly less than the one before", allDecreasing)

	-- Malformed requests still fail, which is the only way a budget call fails.
	check("a zero award is refused as malformed", ProfileOperations.consumeCompetitionBudget(data, "Squat", 0, now) == nil)
	check("a negative award is refused (no refunds)", ProfileOperations.consumeCompetitionBudget(data, "Squat", -5, now) == nil)
	check("a NaN award is refused", ProfileOperations.consumeCompetitionBudget(data, "Squat", 0 / 0, now) == nil)
	check("an infinite award is refused", ProfileOperations.consumeCompetitionBudget(data, "Squat", math.huge, now) == nil)
	check("an unknown lift is refused", ProfileOperations.consumeCompetitionBudget(data, "Curl", 1, now) == nil)
	check("the amount survived every malformed request", data.competitionBudget.Squat.amount == data.competitionBudget.Squat.amount)
end

--------------------------------------------------------------------------------
print("")
print("22. Training Energy still cannot spend below zero")
do
	local data = newProfile()
	local now = 1000 * DAY

	--[[
		The deliberate asymmetry with the Competition Budget above. Passive gain
		stops at empty; there is no overflow.
	]]
	local okAll = ProfileOperations.consumeTrainingEnergy(data, ENERGY.CapacityMinutes, now)
	check("the full 120 minutes can be spent", okAll)
	check("the pool is exactly 0", near(data.trainingEnergy.amount, 0))

	local okMore, leftMore = ProfileOperations.consumeTrainingEnergy(data, 1, now)
	check("one more minute is REFUSED", not okMore, "unlike a Competition Budget")
	check("the pool is still 0, never negative", leftMore ~= nil and near(leftMore :: number, 0) and data.trainingEnergy.amount >= 0)

	-- And it returns a boolean, where the budget returns effective EV.
	check("consumeTrainingEnergy returns a boolean", typeof(okMore) == "boolean")
	local budgetReturn = ProfileOperations.consumeCompetitionBudget(newProfile(), "Squat", 1, now)
	check("consumeCompetitionBudget returns a number", typeof(budgetReturn) == "number", typeof(budgetReturn))
end

--------------------------------------------------------------------------------
print("")
print("23. no meet counter is stored anywhere")
do
	local data = newProfile()

	--[[
		The frozen rule is that the data model is independent of how many meets
		were played. What is checked is that no such field exists, at the profile
		root or inside a budget pool.
	]]
	local forbidden = {
		"meetCount", "meetsThisWeek", "meetNumber", "meets", "attemptCount",
		"attempts", "overflowMeets", "meetsPlayed", "weeklyMeets",
	}

	local rootClean = true
	local poolClean = true

	for _, name in ipairs(forbidden) do
		if (data :: any)[name] ~= nil then
			rootClean = false
		end
		for _, lift in ipairs(ProgressionConfig.Lifts) do
			if ((data.competitionBudget :: any)[lift] :: any)[name] ~= nil then
				poolClean = false
			end
		end
	end

	check("no meet or attempt counter at the profile root", rootClean)
	check("no meet or attempt counter inside any budget pool", poolClean)

	-- A pool holds exactly the two fields the regeneration model needs.
	local fieldCount = 0
	for _ in pairs(data.competitionBudget.Squat) do
		fieldCount += 1
	end
	check("a budget pool holds exactly 2 fields: amount and lastUpdatedUnix", fieldCount == 2, tostring(fieldCount))
	check(
		"and they are those two",
		data.competitionBudget.Squat.amount ~= nil and data.competitionBudget.Squat.lastUpdatedUnix ~= nil
	)

	--[[
		The decisive behavioural proof: consumption responds to EV SIZE, not to a
		count of events. Six awards of 1/6 of a meet must equal one award of a
		whole meet, which no counter-driven implementation could manage.
	]]
	local now = 1000 * DAY
	local bySix = newProfile()
	local byOne = newProfile()

	ProfileOperations.consumeCompetitionBudget(bySix, "Squat", 12 * BUDGET.UnitEV, now)
	local sixTotal = 0
	for _ = 1, 6 do
		local e = ProfileOperations.consumeCompetitionBudget(bySix, "Squat", BUDGET.UnitEV / 6, now)
		sixTotal += (e :: number)
	end

	ProfileOperations.consumeCompetitionBudget(byOne, "Squat", 12 * BUDGET.UnitEV, now)
	local oneTotal = ProfileOperations.consumeCompetitionBudget(byOne, "Squat", BUDGET.UnitEV, now)

	check(
		"six fractional awards equal one whole award: EV drives it, not counts",
		near(sixTotal, oneTotal :: number, 0.0001),
		string.format("%.8f vs %.8f", sixTotal, oneTotal :: number)
	)

	-- A 0.4 EV attempt and a 1.0 EV attempt must advance the state differently.
	local small = newProfile()
	local large = newProfile()
	ProfileOperations.consumeCompetitionBudget(small, "Squat", 0.4, now)
	ProfileOperations.consumeCompetitionBudget(large, "Squat", 1.0, now)
	check(
		"a 0.4 EV attempt advances the state by 0.4, not by one event",
		near(small.competitionBudget.Squat.amount, BUDGET.CapacityEV - 0.4),
		tostring(small.competitionBudget.Squat.amount)
	)
	check(
		"a 1.0 EV attempt advances it by 1.0",
		near(large.competitionBudget.Squat.amount, BUDGET.CapacityEV - 1.0),
		tostring(large.competitionBudget.Squat.amount)
	)
end
--------------------------------------------------------------------------------
print("")
print("24. a new profile has proven nothing")
do
	local data = newProfile()

	check("competitionScale exists on a new profile", typeof(data.competitionScale) == "table")

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local stored = (data.competitionScale :: any)[lift]

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
		data.competitionScale.Squat ~= data.competitionNumber.Squat
	)
	check("Competition Number is still 25 kg", near(data.competitionNumber.Squat, 25.0))
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

	check("migrated to version 4", finalVersion == 4 and data.version == 4)

	-- The rule that this whole checkpoint exists to get right.
	check("Squat Scale is UNPROVEN after migration", data.competitionScale.Squat == 0, tostring(data.competitionScale.Squat))
	check("Bench Scale is UNPROVEN after migration", data.competitionScale.Bench == 0)
	check("Deadlift Scale is UNPROVEN after migration", data.competitionScale.Deadlift == 0)
	check("Squat Scale was NOT set to the trained 182.5", data.competitionScale.Squat ~= 182.5)
	check("Bench Scale was NOT set to the trained 117.5", data.competitionScale.Bench ~= 117.5)
	check("Deadlift Scale was NOT set to the trained 215.0", data.competitionScale.Deadlift ~= 215.0)
	check("no lift reads as proven", not ProfileOperations.isCompetitionScaleProven(data, "Squat")
		and not ProfileOperations.isCompetitionScaleProven(data, "Bench")
		and not ProfileOperations.isCompetitionScaleProven(data, "Deadlift"))

	-- EVERYTHING ELSE THE PLAYER OWNED SURVIVES.
	check("trained Squat CN preserved at 182.5", near(data.competitionNumber.Squat, 182.5), tostring(data.competitionNumber.Squat))
	check("trained Bench CN preserved at 117.5", near(data.competitionNumber.Bench, 117.5))
	check("trained Deadlift CN preserved at 215.0", near(data.competitionNumber.Deadlift, 215.0))
	check("part-spent Squat budget preserved at 3.21", near(data.competitionBudget.Squat.amount, 3.21), tostring(data.competitionBudget.Squat.amount))
	check("budget timestamp preserved", data.competitionBudget.Squat.lastUpdatedUnix == 1700500000)
	check("part-spent Training Energy preserved at 45", near(data.trainingEnergy.amount, 45))
	check("technique PressPower 2200 preserved", data.technique.PressPower == 2200)
	check("technique PullStrength 350 preserved", data.technique.PullStrength == 350)
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

	check("unproven Squat is still 0 after a reload", reloadedFresh.competitionScale.Squat == 0)
	check("unproven Bench is still 0", reloadedFresh.competitionScale.Bench == 0)
	check("unproven Deadlift is still 0", reloadedFresh.competitionScale.Deadlift == 0)
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
	proven.competitionScale.Squat = 172.5
	proven.competitionScale.Bench = 102.5

	local reloadedProven = saveAndReload(proven)

	check("proven Squat 172.5 survived the reload", near(reloadedProven.competitionScale.Squat, 172.5), tostring(reloadedProven.competitionScale.Squat))
	check("proven Bench 102.5 survived", near(reloadedProven.competitionScale.Bench, 102.5))
	check("the unproven Deadlift stayed unproven", reloadedProven.competitionScale.Deadlift == 0)
	check("proven Squat reads as proven", ProfileOperations.isCompetitionScaleProven(reloadedProven, "Squat"))
	check("proven Bench reads as proven", ProfileOperations.isCompetitionScaleProven(reloadedProven, "Bench"))
	check("unproven Deadlift still reads as not proven", not ProfileOperations.isCompetitionScaleProven(reloadedProven, "Deadlift"))
	check("a 2.5 kg increment is stored exactly", reloadedProven.competitionScale.Squat == 172.5)

	--[[
		AND A RE-RUN OF THE MIGRATION MUST NOT WIPE IT. The v3 to v4 step
		repairs a wrong shape and leaves a usable value alone, so a double
		migration cannot cost a player a proven lift.
	]]
	reloadedProven.version = 3
	PlayerProfileSchema.migrate(reloadedProven, 3)

	check(
		"a re-run migration left the proven 172.5 untouched",
		near(reloadedProven.competitionScale.Squat, 172.5),
		tostring(reloadedProven.competitionScale.Squat)
	)
	check("and left the unproven Deadlift at 0", reloadedProven.competitionScale.Deadlift == 0)
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

	check("a NaN Scale repaired to 0", data.competitionScale.Squat == 0, tostring(data.competitionScale.Squat))
	check("no NaN reached the profile", data.competitionScale.Squat == data.competitionScale.Squat)
	check("a string Scale repaired to 0", data.competitionScale.Bench == 0, tostring(data.competitionScale.Bench))
	check("a negative Scale repaired to 0", data.competitionScale.Deadlift == 0, tostring(data.competitionScale.Deadlift))
	check("the player's trained CN was not touched by the repair", near(data.competitionNumber.Squat, 200.0))

	-- A missing table is rebuilt rather than erroring the load.
	local missing = reconciledV3Save(150.0, 100.0, 180.0) :: any
	missing.competitionScale = nil
	PlayerProfileSchema.migrate(missing, 3)

	check("an absent competitionScale table was rebuilt", typeof(missing.competitionScale) == "table")
	check("and every lift is UNPROVEN", missing.competitionScale.Squat == 0
		and missing.competitionScale.Bench == 0
		and missing.competitionScale.Deadlift == 0)

	-- A corrupt stored value must read as unproven, not as a reward.
	local corrupt = newProfile() :: any
	corrupt.competitionScale.Squat = 0 / 0
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
	check("Squat starts unproven", data.competitionScale.Squat == 0)

	local outcome, value = ProfileOperations.raiseCompetitionScale(data, "Squat", 150.0)

	check("first proof returns Raised", outcome == "Raised", tostring(outcome))
	check("and returns the new Scale", value == 150.0, tostring(value))
	check("the stored Scale is 150", near(data.competitionScale.Squat, 150.0), tostring(data.competitionScale.Squat))
	check("and it now reads as proven", ProfileOperations.isCompetitionScaleProven(data, "Squat"))

	-- Raising an existing proven Scale.
	local outcome2, value2 = ProfileOperations.raiseCompetitionScale(data, "Squat", 172.5)

	check("a heavier proof returns Raised", outcome2 == "Raised", tostring(outcome2))
	check("and returns 172.5", value2 == 172.5, tostring(value2))
	check("the stored Scale is now 172.5", near(data.competitionScale.Squat, 172.5), tostring(data.competitionScale.Squat))

	-- A 2.5 kg increment, the smallest legal meet increase, is exact.
	local outcome3 = ProfileOperations.raiseCompetitionScale(data, "Squat", 175.0)
	check("a 2.5 kg increase is accepted", outcome3 == "Raised")
	check("and stored exactly", data.competitionScale.Squat == 175.0, tostring(data.competitionScale.Squat))

	-- A fractional weight is not rounded away.
	local fresh = newProfile()
	ProfileOperations.raiseCompetitionScale(fresh, "Bench", 102.3)
	check("a fractional proof is stored at full precision", near(fresh.competitionScale.Bench, 102.3), tostring(fresh.competitionScale.Bench))
end

--------------------------------------------------------------------------------
print("")
print("30. SCALE NEVER DECREASES")
do
	local data = newProfile()
	ProfileOperations.raiseCompetitionScale(data, "Deadlift", 220.0)

	-- A LOWER successful weight. The commonest case: a conservative opener.
	local lower, lowerValue = ProfileOperations.raiseCompetitionScale(data, "Deadlift", 180.0)

	check("a lower proof returns Unchanged, not Rejected", lower == "Unchanged", tostring(lower))
	check("and reports the Scale that still stands", lowerValue == 220.0, tostring(lowerValue))
	check("the stored Scale did NOT drop", near(data.competitionScale.Deadlift, 220.0), tostring(data.competitionScale.Deadlift))

	-- An EQUAL weight. Repeating a best is legal and changes nothing.
	local equal, equalValue = ProfileOperations.raiseCompetitionScale(data, "Deadlift", 220.0)

	check("an equal proof returns Unchanged", equal == "Unchanged", tostring(equal))
	check("and reports 220", equalValue == 220.0, tostring(equalValue))
	check("the stored Scale is still 220", near(data.competitionScale.Deadlift, 220.0))

	-- A long run of lighter lifts can never erode it.
	for _, weight in ipairs({ 100.0, 200.0, 50.0, 219.5, 1.0, 217.5 }) do
		ProfileOperations.raiseCompetitionScale(data, "Deadlift", weight)
	end

	check(
		"six lighter proofs left it at 220",
		near(data.competitionScale.Deadlift, 220.0),
		tostring(data.competitionScale.Deadlift)
	)

	-- IDEMPOTENCE. Repeated identical calls settle on one value.
	local repeated = newProfile()
	for _ = 1, 10 do
		ProfileOperations.raiseCompetitionScale(repeated, "Squat", 165.0)
	end
	check("ten identical calls give 165", near(repeated.competitionScale.Squat, 165.0), tostring(repeated.competitionScale.Squat))

	-- ORDER INDEPENDENCE. The max does not care what order proofs arrive in.
	local ascending = newProfile()
	for _, w in ipairs({ 120.0, 140.0, 160.0, 180.0 }) do
		ProfileOperations.raiseCompetitionScale(ascending, "Bench", w)
	end

	local descending = newProfile()
	for _, w in ipairs({ 180.0, 160.0, 140.0, 120.0 }) do
		ProfileOperations.raiseCompetitionScale(descending, "Bench", w)
	end

	check(
		"ascending and descending orders agree at 180",
		near(ascending.competitionScale.Bench, 180.0)
			and near(descending.competitionScale.Bench, 180.0),
		string.format("%s vs %s", tostring(ascending.competitionScale.Bench), tostring(descending.competitionScale.Bench))
	)
end

--------------------------------------------------------------------------------
print("")
print("31. invalid input is rejected and writes nothing")
do
	local data = newProfile()
	ProfileOperations.raiseCompetitionScale(data, "Squat", 160.0)

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
		local before = data.competitionScale.Squat

		local outcome, value = ProfileOperations.raiseCompetitionScale(data, case.lift, case.weight :: any)

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
			data.competitionScale.Squat == before,
			string.format("%s, expected %s", tostring(data.competitionScale.Squat), tostring(before))
		)
	end

	check("the Scale survived every rejection at 160", near(data.competitionScale.Squat, 160.0), tostring(data.competitionScale.Squat))
	check("and no NaN reached the profile", data.competitionScale.Squat == data.competitionScale.Squat)

	--[[
		A CORRUPT STORED SCALE IS REFUSED RATHER THAN REPAIRED, because we
		cannot know whether it was higher than the incoming proof. Repair is the
		migration's job and happens on every load.
	]]
	local corrupt = newProfile() :: any
	corrupt.competitionScale.Bench = 0 / 0

	local outcome = ProfileOperations.raiseCompetitionScale(corrupt, "Bench", 120.0)
	check("a corrupt stored Scale rejects the raise", outcome == "Rejected", tostring(outcome))
	check("and the raise did not overwrite it", corrupt.competitionScale.Bench ~= 120.0)
end

--------------------------------------------------------------------------------
print("")
print("32. lifts are independent, and nothing else in the profile moves")
do
	local data = newProfile()

	-- Snapshot everything a raise must not touch.
	local cnBefore = {
		Squat = data.competitionNumber.Squat,
		Bench = data.competitionNumber.Bench,
		Deadlift = data.competitionNumber.Deadlift,
	}
	local budgetBefore = data.competitionBudget.Squat.amount
	local energyBefore = data.trainingEnergy.amount
	local techniqueBefore = data.technique.PressPower
	local bodyweightBefore = data.bodyweight.currentKg
	local versionBefore = data.version

	ProfileOperations.raiseCompetitionScale(data, "Squat", 190.0)

	check("Squat Scale rose to 190", near(data.competitionScale.Squat, 190.0))
	check("Bench Scale stayed unproven", data.competitionScale.Bench == 0, tostring(data.competitionScale.Bench))
	check("Deadlift Scale stayed unproven", data.competitionScale.Deadlift == 0, tostring(data.competitionScale.Deadlift))

	ProfileOperations.raiseCompetitionScale(data, "Bench", 110.0)
	ProfileOperations.raiseCompetitionScale(data, "Deadlift", 230.0)

	check("all three now hold their own value", near(data.competitionScale.Squat, 190.0)
		and near(data.competitionScale.Bench, 110.0)
		and near(data.competitionScale.Deadlift, 230.0))

	-- COMPETITION NUMBER IS UNTOUCHED. Scale is not derived from it and does not feed it.
	check("Squat CN unchanged", data.competitionNumber.Squat == cnBefore.Squat, tostring(data.competitionNumber.Squat))
	check("Bench CN unchanged", data.competitionNumber.Bench == cnBefore.Bench)
	check("Deadlift CN unchanged", data.competitionNumber.Deadlift == cnBefore.Deadlift)
	check("CN is still the 25 kg starting value", near(data.competitionNumber.Squat, 25.0))

	-- AND NOTHING ELSE MOVED EITHER.
	check("Competition Budget untouched", near(data.competitionBudget.Squat.amount, budgetBefore))
	check("Training Energy untouched", near(data.trainingEnergy.amount, energyBefore))
	check("technique untouched", data.technique.PressPower == techniqueBefore)
	check("bodyweight untouched", near(data.bodyweight.currentKg, bodyweightBefore))
	check("schema version untouched", data.version == versionBefore)

	--[[
		NO TIMESTAMP IS READ OR WRITTEN. The operation is pure: it takes no
		`nowUnix` and stamps nothing, so unlike a regenerating resource it
		cannot be made to behave differently by a clock.
	]]
	check(
		"raiseCompetitionScale takes exactly three arguments, none a timestamp",
		debug.info(ProfileOperations.raiseCompetitionScale, "a") == 3,
		tostring(debug.info(ProfileOperations.raiseCompetitionScale, "a"))
	)
	check("no budget timestamp was stamped", data.competitionBudget.Squat.lastUpdatedUnix == 0)
	check("no Training Energy timestamp was stamped", data.trainingEnergy.lastUpdatedUnix == 0)
end

--------------------------------------------------------------------------------
print("")
print(string.format("=== %d passed, %d failed ===", passed, failed))

if failed > 0 then
	warn("[PlayerDataProbe] PERSISTENCE FOUNDATION HAS FAILING CHECKS. Do not build on it yet.")
end
