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

local PlayerProfileSchema = {}

--[[
	Bump this whenever the shape of ProfileData changes, and add a matching entry
	to the migrations table below.
]]
PlayerProfileSchema.CURRENT_VERSION = 1

export type Forecasted = {
	-- Kilograms. These ARE the lifter's strength; there is no hidden true value.
	Squat: number,
	Bench: number,
	Deadlift: number,
}

export type Technique = {
	-- Unbounded raw values. Always read through TechniqueCurve, never directly.
	SquatControl: number,
	DepthAwareness: number,
	StartControl: number,
	PressPower: number,
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
	forecasted: Forecasted,
	technique: Technique,
	bodyweight: Bodyweight,
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

	forecasted = {
		Squat = StartingValuesConfig.Forecasted.Squat,
		Bench = StartingValuesConfig.Forecasted.Bench,
		Deadlift = StartingValuesConfig.Forecasted.Deadlift,
	},

	technique = {
		SquatControl = StartingValuesConfig.Technique.SquatControl,
		DepthAwareness = StartingValuesConfig.Technique.DepthAwareness,
		StartControl = StartingValuesConfig.Technique.StartControl,
		PressPower = StartingValuesConfig.Technique.PressPower,
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

	Empty at version 1, because there is nothing older to come from yet.
]]
local migrations: { [number]: (ProfileData) -> () } = {}

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
