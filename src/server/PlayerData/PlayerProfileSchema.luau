--!strict
--[[
	PlayerProfileSchema
	Server / PlayerData

	Defines the SHAPE of persistent player data, and how old saves are brought
	forward when that shape changes.

	This module is pure data and pure functions. It performs no DataStore work and
	knows nothing about ProfileStore, so the schema can be reasoned about and
	migrated without touching persistence.

	WHAT IS AND IS NOT IN HERE

	Version 1 contains only fields whose values are actually decided: forecasted
	maxes, technique stats and bodyweight, all drawn from StartingValuesConfig.

	Fatigue, currency, inventory, equipment, buffs, meet progression, titles,
	cosmetics, coaches and origins are all coming, and GAME_DESIGN.md Q3 lists
	them, but their SHAPES are undefined. Guessing a shape now would mean
	migrating away from that guess later. The migration system below is what makes
	adding them safe, so each is added when its system is built.

	STORAGE RULES (enforced by validateTemplate below)

	ProfileStore saves to a DataStore as JSON, so stored values may only be
	numbers, strings, booleans, or tables of those. No Instances, no Vector3 or
	other userdata, no functions, and no arrays with gaps.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local StartingValuesConfig = require(ConfigFolder:WaitForChild("StartingValuesConfig"))
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local ResourceRegeneration = require(ProgressionFolder:WaitForChild("ResourceRegeneration"))

local PlayerProfileSchema = {}

--[[
	Bump this whenever the shape of ProfileData changes, and add a matching entry
	to the migrations table below.
]]
PlayerProfileSchema.CURRENT_VERSION = 3

--[[
	Renamed from `Forecasted` in version 3. Player-facing terminology is
	Competition Number, per GAME_DESIGN.md section 29.1.

	NOTE THE DELIBERATELY INCOMPLETE RENAME. The in-memory plumbing of the
	difficulty engine and the four phase services still says `forecastedMax` /
	`forecastedMaxKg`, in roughly forty places. Those are function parameters and
	per-attempt snapshot fields, NOT persisted data, so renaming them buys no
	data safety while touching every lifting file in the project. They are left
	for a separate, purely mechanical pass. Only the SAVED field is renamed here,
	because only the saved field needs a migration.
]]
export type CompetitionNumber = {
	-- Kilograms. These ARE the lifter's strength; there is no hidden true value.
	Squat: number,
	Bench: number,
	Deadlift: number,
}

--[[
	A continuously regenerating resource. See ResourceRegeneration for why a
	timestamp is stored rather than the resource being ticked by a loop.
]]
export type Resource = ResourceRegeneration.Resource

--[[
	The three per-lift Competition Budgets, from GAME_DESIGN.md section 29.9.

	ACCOUNT-WIDE, NOT BUILD-SCOPED. A 59 kg squat build and a 120 kg squat build
	draw from this same Squat pool, and Solo and Official meets share it too.
	Spending Squat leaves Bench and Deadlift untouched.

	`amount` may go NEGATIVE, and the magnitude is the overflow depth. That is
	what keeps the model independent of how many meets were played.
]]
export type CompetitionBudget = {
	Squat: Resource,
	Bench: Resource,
	Deadlift: Resource,
}

export type Technique = {
	-- Unbounded raw values. Always read through TechniqueCurve, never directly.
	SquatControl: number,
	DepthAwareness: number,
	StartControl: number,
	PressPower: number,
	--[[
		Added in version 2. Drives the Deadlift's first phase, the character-first
		typing pull. One stat per lift-phase: the deadlift's two phases are
		PullStrength off the floor and Lockout at the top.
	]]
	PullStrength: number,
	Lockout: number,
}

export type Bodyweight = {
	currentKg: number,
	-- What the player is eating toward. Equal to current means "maintain".
	targetKg: number,
}

export type Meta = {
	-- Unix seconds of first load. 0 in the template, stamped on first session.
	createdUnix: number,
	-- Unix seconds of the most recent session start.
	lastSessionUnix: number,
	sessionCount: number,
}

export type ProfileData = {
	version: number,

	--[[
		BUILD-SCOPED IN THE FROZEN DESIGN, FLAT FOR NOW.

		Section 29.11 makes Competition Numbers per weight-class build, and the
		Weight-Class Build Slot system is not built. This field therefore holds
		the ACTIVE build's numbers, which is every player's only build today.

		The later migration is deterministic and lossless: move this table to
		`builds[classKey].competitionNumber`, keyed by the class the player is
		already in, which WeightClass.resolve derives from bodyweight.currentKg.
		No value is invented and nothing is lost.

		A `builds` map is deliberately NOT created now. Which build is active,
		how slots are keyed, and how many a player may own are all undecided, and
		guessing that shape would mean migrating away from the guess. No
		paid-slot behaviour is implied or implemented here.
	]]
	competitionNumber: CompetitionNumber,

	technique: Technique,
	bodyweight: Bodyweight,

	--[[
		ACCOUNT-WIDE, never build-scoped, so these stay OUTSIDE the future
		`builds` map described above.
	]]
	competitionBudget: CompetitionBudget,
	trainingEnergy: Resource,

	meta: Meta,
}

--[[
	The template handed to ProfileStore.New. New profiles receive a deep copy of
	it, and Profile:Reconcile fills in any key missing from an older save.

	Starting values come from StartingValuesConfig so that the "what a new lifter
	begins with" decision stays in one place beside the rest of the balancing
	configuration, rather than being duplicated here.
]]
local template: ProfileData = {
	version = PlayerProfileSchema.CURRENT_VERSION,

	competitionNumber = {
		Squat = StartingValuesConfig.Forecasted.Squat,
		Bench = StartingValuesConfig.Forecasted.Bench,
		Deadlift = StartingValuesConfig.Forecasted.Deadlift,
	},

	--[[
		THE TEMPLATE STORES ZERO TIMESTAMPS, NOT os.time().

		Same reasoning as meta.createdUnix below: a timestamp baked into the
		template records when the SERVER started, not when the player first
		played, and every profile created by that server would share it.

		A zero timestamp means "never touched". ResourceRegeneration reads a full
		amount and returns early without consulting the clock, so a brand new
		profile is simply full. The first spend stamps a real server time.
	]]
	competitionBudget = {
		Squat = { amount = ProgressionConfig.CompetitionBudget.CapacityEV, lastUpdatedUnix = 0 },
		Bench = { amount = ProgressionConfig.CompetitionBudget.CapacityEV, lastUpdatedUnix = 0 },
		Deadlift = { amount = ProgressionConfig.CompetitionBudget.CapacityEV, lastUpdatedUnix = 0 },
	},

	trainingEnergy = {
		amount = ProgressionConfig.TrainingEnergy.CapacityMinutes,
		lastUpdatedUnix = 0,
	},

	technique = {
		SquatControl = StartingValuesConfig.Technique.SquatControl,
		DepthAwareness = StartingValuesConfig.Technique.DepthAwareness,
		StartControl = StartingValuesConfig.Technique.StartControl,
		PressPower = StartingValuesConfig.Technique.PressPower,
		PullStrength = StartingValuesConfig.Technique.PullStrength,
		Lockout = StartingValuesConfig.Technique.Lockout,
	},

	bodyweight = {
		currentKg = StartingValuesConfig.BodyweightKg,
		--[[
			Confirmed design decision: a new lifter starts at MAINTENANCE, with
			target equal to current bodyweight. They are not automatically
			bulking.

			Players change their target deliberately, later, through the
			bodyweight and nutrition system. Target bodyweight is a choice the
			player makes, never a default the game makes for them.
		]]
		targetKg = StartingValuesConfig.BodyweightKg,
	},

	meta = {
		--[[
			Deliberately 0 rather than os.time(). A timestamp baked into the
			template would record when the SERVER started, not when the player
			first played. PlayerDataService stamps this on first load.
		]]
		createdUnix = 0,
		lastSessionUnix = 0,
		sessionCount = 0,
	},
}

--[[
	Migrations from one version to the next.

		migrations[n] transforms data at version n into version n + 1.

	They run in sequence, so a profile last seen at version 1 can reach version 4
	by running 1 to 2, then 2 to 3, then 3 to 4. Each one must be safe to run on
	real saved data: read the old fields, write the new ones, remove what is dead.

	A STEP MUST EXIST FOR EVERY VERSION GAP, even one Reconcile would already
	cover. migrate() warns and abandons the profile at its old version if it finds
	no step, so a missing entry is not a harmless omission.
]]
local migrations: { [number]: (ProfileData) -> () } = {}

--[[
	Version 1 to 2: the Deadlift gained its own first-phase technique stat.

	Every pre-existing lifter receives PullStrength = 0, which is what a brand new
	lifter starts with, so nobody is advantaged or disadvantaged by having played
	before the deadlift existed. Nothing else is read, written or removed.

	Reconcile() runs BEFORE this (see PlayerDataService), so in practice it has
	already filled the field from the template. Writing it here anyway means the
	migration does not silently depend on Reconcile's behaviour staying the same,
	and the `if` keeps it from overwriting a value that is somehow already set.
]]
migrations[1] = function(data: ProfileData)
	if typeof(data.technique) ~= "table" then
		--[[
			Defensive. A v1 save always has this table, but a migration runs against
			whatever is actually in the DataStore, and crashing here would fail the
			load and kick the player rather than repairing their profile.
		]]
		data.technique = {
			SquatControl = StartingValuesConfig.Technique.SquatControl,
			DepthAwareness = StartingValuesConfig.Technique.DepthAwareness,
			StartControl = StartingValuesConfig.Technique.StartControl,
			PressPower = StartingValuesConfig.Technique.PressPower,
			PullStrength = StartingValuesConfig.Technique.PullStrength,
			Lockout = StartingValuesConfig.Technique.Lockout,
		}
		return
	end

	if typeof(data.technique.PullStrength) ~= "number" then
		data.technique.PullStrength = StartingValuesConfig.Technique.PullStrength
	end
end

--[[
	Version 2 to 3: the Competition Number progression foundation.

	TWO THINGS HAPPEN HERE, and the first is the one that can lose data.

	1. THE STORED STRENGTH FIELD IS RENAMED.

		forecasted {Squat, Bench, Deadlift}  ->  competitionNumber {...}

	Reconcile() runs BEFORE this and will have created `competitionNumber` from
	the template, which holds 25 kg for each lift. The old `forecasted` table is
	untouched by Reconcile, because the template no longer mentions it.

	So on arrival here a real v2 save looks like:

		forecasted        = { Squat = 180, Bench = 120, Deadlift = 210 }   <- REAL
		competitionNumber = { Squat = 25,  Bench = 25,  Deadlift = 25 }    <- template

	COPYING THE OLD VALUES OVER IS THEREFORE MANDATORY, NOT DEFENSIVE. Skipping
	it would reset every existing lifter to 25 kg. 25 is only ever the default
	for genuinely new lift data.

	Each lift is copied independently and only when the old value is a usable
	number, so a save with two good lifts and one corrupt field keeps the two.

	`forecasted` is then removed. It has to go: leaving it would mean two fields
	claiming to be the lifter's strength, and the next person to read the profile
	would have to guess which one won.

	2. THE NEW RESOURCES ARE STARTED FULL.

	Reconcile already copies the template's full values, so this only repairs a
	resource whose shape is wrong. Starting full rather than empty is deliberate:
	an existing player must not log in to find a new allowance they have to wait
	a week for.

	IDEMPOTENT. Running this twice is harmless. The second run finds no
	`forecasted` field, finds every `competitionNumber` already a good number,
	and changes nothing.
]]
migrations[2] = function(data: ProfileData)
	local legacy = (data :: any).forecasted

	if typeof(data.competitionNumber) ~= "table" then
		--[[
			Defensive. Reconcile should always have created this. Building it
			empty lets the copy below fill it, rather than erroring and failing
			the load, which would kick the player instead of repairing them.
		]]
		data.competitionNumber = {} :: any
	end

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local saved = if typeof(legacy) == "table" then (legacy :: any)[lift] else nil

		--[[
			Only a finite number above zero is accepted. NaN, infinity, nil, a
			string and a non-positive value all fall through to whatever
			Reconcile put there, which is the 25 kg default.
		]]
		if typeof(saved) == "number" and saved == saved and saved > 0 and saved < math.huge then
			(data.competitionNumber :: any)[lift] = saved
		elseif typeof((data.competitionNumber :: any)[lift]) ~= "number" then
			(data.competitionNumber :: any)[lift] = StartingValuesConfig.Forecasted[lift]
		end
	end

	-- The rename is only complete once the old field is gone. See note 1 above.
	(data :: any).forecasted = nil

	--[[
		Repair rather than create: Reconcile has normally done this already.
		A resource is only rebuilt when its shape is actually wrong, so a
		player's part-spent budget survives a second pass.
	]]
	if typeof(data.competitionBudget) ~= "table" then
		data.competitionBudget = {} :: any
	end

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local pool = (data.competitionBudget :: any)[lift]

		if typeof(pool) ~= "table" or typeof(pool.amount) ~= "number" or pool.amount ~= pool.amount then
			(data.competitionBudget :: any)[lift] = {
				amount = ProgressionConfig.CompetitionBudget.CapacityEV,
				lastUpdatedUnix = 0,
			}
		elseif typeof(pool.lastUpdatedUnix) ~= "number" then
			pool.lastUpdatedUnix = 0
		end
	end

	local energy = data.trainingEnergy

	if typeof(energy) ~= "table" or typeof(energy.amount) ~= "number" or energy.amount ~= energy.amount then
		data.trainingEnergy = {
			amount = ProgressionConfig.TrainingEnergy.CapacityMinutes,
			lastUpdatedUnix = 0,
		}
	elseif typeof(energy.lastUpdatedUnix) ~= "number" then
		energy.lastUpdatedUnix = 0
	end
end

--[[
	Reads the version from raw saved data.

	Returns 0 when the field is absent, and that matters a great deal. Reconcile
	fills missing keys from the template, and the template's version is the
	CURRENT version, so a save predating versioning would be stamped as current
	and silently skip every migration. Callers must therefore detect the version
	BEFORE reconciling.
]]
function PlayerProfileSchema.detectVersion(data: any): number
	if typeof(data) ~= "table" then
		return 0
	end

	local version = data.version
	if typeof(version) ~= "number" then
		return 0
	end

	return version
end

--[[
	Brings data forward to CURRENT_VERSION, returning the version it ended at.

	`fromVersion` must be the value captured before Reconcile ran.
]]
function PlayerProfileSchema.migrate(data: ProfileData, fromVersion: number): number
	-- A brand new profile is created from the template, so it is already current.
	if fromVersion == 0 and data.version == PlayerProfileSchema.CURRENT_VERSION then
		return PlayerProfileSchema.CURRENT_VERSION
	end

	local version = fromVersion

	while version < PlayerProfileSchema.CURRENT_VERSION do
		local step = migrations[version]

		if step == nil then
			warn(string.format(
				"[PlayerProfileSchema] no migration from version %d to %d. Data left at "
					.. "version %d and may be missing fields.",
				version,
				version + 1,
				version
			))
			break
		end

		step(data)
		version += 1
	end

	if version > PlayerProfileSchema.CURRENT_VERSION then
		--[[
			Saved by a NEWER server than this one. Do not rewrite it: an older
			server stamping its own version over newer data is how rollbacks and
			item loss happen. Leave it exactly as found.
		]]
		warn(string.format(
			"[PlayerProfileSchema] profile is at version %d but this server only knows %d. "
				.. "Leaving it untouched to avoid destroying newer data.",
			version,
			PlayerProfileSchema.CURRENT_VERSION
		))
		return version
	end

	data.version = version
	return version
end

--[[
	Confirms the template holds only values a DataStore can store.

	Runs once at startup. The mistake it exists to catch is someone adding a
	Vector3, an Instance or a function to the template, which would otherwise not
	fail until a real save attempt in production.
]]
local function validateTemplate(value: any, path: string)
	local valueType = typeof(value)

	if valueType == "number" then
		assert(value == value, string.format("[PlayerProfileSchema] %s is NaN", path))
		assert(
			value ~= math.huge and value ~= -math.huge,
			string.format("[PlayerProfileSchema] %s is infinite", path)
		)
		return
	end

	if valueType == "string" or valueType == "boolean" then
		return
	end

	assert(
		valueType == "table",
		string.format(
			"[PlayerProfileSchema] %s is a %s, which cannot be saved to a DataStore. Only "
				.. "numbers, strings, booleans and tables of those are allowed.",
			path,
			valueType
		)
	)

	local numericKeys = 0
	local stringKeys = 0

	for key, child in pairs(value) do
		local keyType = typeof(key)
		assert(
			keyType == "string" or keyType == "number",
			string.format("[PlayerProfileSchema] %s has a %s key, which cannot be saved", path, keyType)
		)

		if keyType == "number" then
			numericKeys += 1
		else
			stringKeys += 1
		end

		validateTemplate(child, string.format("%s.%s", path, tostring(key)))
	end

	assert(
		numericKeys == 0 or stringKeys == 0,
		string.format(
			"[PlayerProfileSchema] %s mixes numeric and string keys. Only the numeric "
				.. "entries would be saved.",
			path
		)
	)

	if numericKeys > 0 then
		assert(
			#value == numericKeys,
			string.format("[PlayerProfileSchema] %s is an array with gaps, which cannot be saved", path)
		)
	end
end

validateTemplate(template, "template")

PlayerProfileSchema.template = template

return PlayerProfileSchema
