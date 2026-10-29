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

local WeightClassConfig = require(ConfigFolder:WaitForChild("WeightClassConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local ResourceRegeneration = require(ProgressionFolder:WaitForChild("ResourceRegeneration"))
local DayKey = require(ProgressionFolder:WaitForChild("DayKey"))
local WeightClass = require(ProgressionFolder:WaitForChild("WeightClass"))

local PlayerProfileSchema = {}

--[[
	Bump this whenever the shape of ProfileData changes, and add a matching entry
	to the migrations table below.
]]
PlayerProfileSchema.CURRENT_VERSION = 6

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
	UNPROVEN. The stored Competition Scale of a lift nobody has ever made in an
	eligible meet, per GAME_DESIGN.md section 33.8.

	WHY A 0 SENTINEL AND NOT AN ABSENT FIELD. A DataStore stores JSON, and a
	Lua table cannot hold a nil value -- `{ Squat = nil }` IS `{}`. So "absent"
	and "never written" are indistinguishable after a save/load round trip, and
	an optional `number?` would force every reader to handle a case the storage
	layer cannot actually represent. A fixed-shape record with an explicit
	sentinel survives serialization unchanged and reconciles cleanly.

	WHY 0 IS SAFE AS A SENTINEL. Scale is a weight in kilograms that was
	actually loaded on a bar and lifted. 0 kg is not a liftable weight, so it
	can never collide with a legitimate proven value. Any Scale above 0 is a
	real achievement; exactly 0 means there is none.

	0 IS NOT A PROVEN 0 KG LIFT, AND IT IS NOT 25 KG. A new lifter has
	Competition Number 25 kg because training gave them that capability, and an
	unproven Scale because they have never competed. Those are different
	quantities and the gap between them is the normal state of an untested
	lifter, not missing data to be filled in.

	A FALLBACK IS NOT A STORED VALUE. Section 33.4 leaves open what the Scale
	challenge modifier does when no Scale exists, and 25 kg may end up being
	the number a future calculation substitutes. If it does, that substitution
	belongs to the calculation and must never be written back here. Writing it
	would fabricate a successful meet attempt that never happened.
]]
PlayerProfileSchema.UNPROVEN_SCALE = 0

--[[
	Competition Scale, added in version 4. From GAME_DESIGN.md section 33.

	The heaviest weight the lifter has SUCCESSFULLY PROVEN in an eligible meet,
	per lift, in kilograms. Competition Number is what training built; this is
	what competition confirmed. They move independently and neither caps the
	other.

	`UNPROVEN_SCALE` above means the lift has never been proven.

	Lives inside a Build (version 6). Written only by the meet: each good lift
	raises the Scale of the build for the meet's weigh-in class, through
	ProfileOperations.raiseCompetitionScale.
]]
export type CompetitionScale = {
	-- Kilograms, or UNPROVEN_SCALE. Never decreases once above 0.
	Squat: number,
	Bench: number,
	Deadlift: number,
}

--[[
	NO BEST TOTAL YET. Same reasoning as UNPROVEN_SCALE: 0 kg is not a total
	anyone can make, so it can never collide with a real one.
]]
PlayerProfileSchema.NO_TOTAL = 0

--[[
	A WEIGHT-CLASS BUILD, added in version 6. GAME_DESIGN.md section 29.11,
	"Weight-class builds" (user, 2026-10-28).

	The lifter's progress in ONE weight class. Competition Number and Scale
	live here together, so the profile has one answer to "which build is this".

		competitionNumber   what training built in this class
		competitionScale    the heaviest lift proven in a meet in this class
		bestTotalKg         the best Total from ONE finished meet in this class,
		                    or NO_TOTAL. Personal only: never a record, never the
		                    gym records wall, and never a sum of Scales (33.8)
]]
export type Build = {
	competitionNumber: CompetitionNumber,
	competitionScale: CompetitionScale,
	bestTotalKg: number,
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

--[[
	One account-wide daily allowance, added in version 5. From GAME_DESIGN.md
	section 34.12.

		spentToday         how much of today's allowance has been consumed
		dayKey             the UTC day that figure belongs to
		lastUpdatedUnix    the server time it was last written

	THE DAY KEY IS WHAT MAKES THIS WORK WITHOUT A LOOP. Nothing resets these at
	midnight. A reader compares the stored key against the current one and treats
	a mismatch as "a new day, nothing spent yet". That is why a server restart, a
	daily reset landing mid-session, and a player offline for a week all need the
	same single line of logic and no special cases. Section 34.5 requires the
	phase to be DERIVED from these counters for exactly this reason.

	FRACTIONAL BY DESIGN. Section 34.4's EV accrues continuously, so rounding a
	counter to an integer would silently discard part of an award. Both are
	plain numbers, which a DataStore stores as JSON numbers.

	NO CAP IS STORED HERE. The 4.00 EV daily CN cap (section 34.1, decision 2)
	is config, not profile data. Storing a cap per player would mean a later
	balance change could never reach anyone who already has a profile.

	THE TECHNIQUE ALLOWANCE IS LEGACY DATA (checkpoint 5B.7). Technique training
	has no earning cap, so nothing spends `techniqueAllowance` or reads a limit
	from it. It is kept -- not removed, renamed or migrated -- so every saved
	profile loads unchanged, and the CN plan still rolls and stamps it exactly
	as before.
]]
export type DailyAllowance = {
	spentToday: number,
	dayKey: string,
	lastUpdatedUnix: number,
}

--[[
	The three per-lift training-time accumulators, added in version 5. From
	GAME_DESIGN.md section 34.12.

	Hours of station CN training spent on each lift today. These feed the per-lift
	diminishing-efficiency function H(t) of section 34.4, and they are REQUIRED
	rather than derivable: H(t) is scoped per lift while the EV cap is scoped per
	account, so `t` cannot be recovered from either allowance above.

	UNCAPPED, DELIBERATELY. These shape efficiency; they never stop training.
	Section 34.3 is explicit that there is no hard daily training-hour limit, so
	nothing bounds them and a reader must not treat a large value as corrupt.

	SWITCHING LIFTS PRESERVES ALL THREE. Section 34.12: a player who trains Squat
	for two hours, switches to Bench, and later switches back resumes Squat at
	t = 2.00 rather than at zero. That falls out of storing the hours per lift and
	resetting only on a day change -- there is no switch handler to get wrong,
	because there is no switch handler at all.

	ONE SHARED DAY KEY, NOT THREE. The three lifts always roll over together,
	because they roll over with the calendar and not with anything per-lift. Three
	keys would permit a state the game cannot produce.

	THE LIFT NAMES SHARE A TABLE WITH `dayKey` AND `lastUpdatedUnix`, which is the
	flat shape section 34.12 specifies. It is safe because ProgressionConfig.Lifts
	is Squat, Bench and Deadlift, none of which can collide with a bookkeeping
	key. A fourth lift would have to respect the same rule.
]]
export type TrainingTimeToday = {
	Squat: number,
	Bench: number,
	Deadlift: number,
	dayKey: string,
	lastUpdatedUnix: number,
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
		ONE BUILD PER WEIGHT CLASS, added in version 6 (GAME_DESIGN.md 29.11).

		Keyed by the class label from WeightClass.resolve ("59 kg" ... "120+ kg"),
		the same keys ProgressionReferenceConfig uses. Until version 6 the
		Competition Number and Scale sat flat on the profile; migrations[5] moved
		them here, under the class the player was in, unchanged.

		THE ACTIVE BUILD IS NOT STORED. It is the class of bodyweight.currentKg,
		derived on every read (ProfileOperations.getActiveBuild), so the profile
		can never hold two answers to "which build is this".

		A meet does NOT use the active build when it writes. It credits the class
		frozen at its weigh-in (section 32.7), so a Scale proven in one class can
		never land in another.

		Builds are created on first entry to a class and kept forever, free; at
		most one per class (ensureBuild below). Nothing deletes a build.
	]]
	builds: { [string]: Build },

	technique: Technique,
	bodyweight: Bodyweight,

	--[[
		ACCOUNT-WIDE, never build-scoped, so these stay OUTSIDE the `builds`
		map above.
	]]
	competitionBudget: CompetitionBudget,
	trainingEnergy: Resource,

	--[[
		DAILY TRAINING ACCOUNTING, added in version 5. GAME_DESIGN.md section
		34.12. Five counters in three records, and all three are ACCOUNT-WIDE --
		not per build slot, not per weight class, not per station, not per
		server -- so they stay outside the `builds` map too.

		The two allowances are account-wide in the quantity they bound. The
		third record holds three PER-LIFT hour counters but is still account
		state: there is one of it per profile, sharing one day key.

		Written only by the CN training award (5B.5, driven by the 5B.6 racks).
		`techniqueAllowance` is LEGACY since 5B.7: technique has no cap, so it
		is never spent; the CN award still rolls and stamps it unchanged.
	]]
	cnAllowance: DailyAllowance,
	techniqueAllowance: DailyAllowance,
	trainingTimeToday: TrainingTimeToday,

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

	--[[
		EMPTY IN THE TEMPLATE, ON PURPOSE. ProfileStore's Reconcile fills every
		missing key of the template INTO NESTED TABLES TOO, so a template build
		under "59 kg" would be planted into every profile that lacks one -- a
		phantom 25 kg build that a later cut to 59 kg would "restore". The
		starting build is created by ensureBuild instead, which migrate() runs on
		every load, new profiles included. See newBuild for what a new lifter
		starts with.
	]]
	builds = {},

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

	--[[
		A NEW LIFTER HAS SPENT NOTHING AND TRAINED NO HOURS TODAY.

		Zero spent, zero hours, and an UNSTAMPED day key -- the same reasoning as
		the zero timestamps above. A real day key baked into the template would
		record the day the SERVER started rather than the day the player first
		trained, and every profile that server created would share it.

		UNSTAMPED IS NOT A FREE ALLOWANCE. The sentinel matches no real day, so
		the first read sees a mismatch and resets these counters to zero, which
		is already their value. A no-op, not a grant, and it is why an unstamped
		counter needs no special case in the reader.

		THE STARTING VALUES ARE NOT IN StartingValuesConfig, on purpose. That
		file holds balance decisions -- what a lifter begins with -- and "has not
		yet trained today" is not a balance number. It is the only value these
		counters could possibly start at.
	]]
	cnAllowance = {
		spentToday = 0,
		dayKey = DayKey.UNSTAMPED,
		lastUpdatedUnix = 0,
	},

	techniqueAllowance = {
		spentToday = 0,
		dayKey = DayKey.UNSTAMPED,
		lastUpdatedUnix = 0,
	},

	trainingTimeToday = {
		Squat = 0,
		Bench = 0,
		Deadlift = 0,
		dayKey = DayKey.UNSTAMPED,
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
	True once a profile's Competition Number and Scale live in builds (version
	6). The older steps that wrote the FLAT fields check this, so re-running
	them on an upgraded profile -- the double-migration bug the probe guards
	against -- cannot plant a 25 kg flat table for migrations[5] to file over
	the real build.
]]
local function hasMovedToBuilds(data: ProfileData): boolean
	local builds = (data :: any).builds
	return typeof(builds) == "table"
		and next(builds) ~= nil
		and (data :: any).competitionNumber == nil
		and (data :: any).forecasted == nil
end

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

	SINCE VERSION 6 the template has no flat `competitionNumber` (it moved into
	`builds`), so Reconcile no longer creates it and the "Defensive" branch
	below is the normal path for an old save. The result is the same; the
	flat table then lives only until migrations[5] moves it into a build.

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
	-- Already in builds (version 6): the flat field is gone for good, so leave it gone.
	if not hasMovedToBuilds(data) then
		local legacy = (data :: any).forecasted

		if typeof((data :: any).competitionNumber) ~= "table" then
			--[[
				Defensive. Reconcile should always have created this. Building it
				empty lets the copy below fill it, rather than erroring and failing
				the load, which would kick the player instead of repairing them.
			]]
			(data :: any).competitionNumber = {}
		end

		for _, lift in ipairs(ProgressionConfig.Lifts) do
			local saved = if typeof(legacy) == "table" then (legacy :: any)[lift] else nil

			--[[
				Only a finite number above zero is accepted. NaN, infinity, nil, a
				string and a non-positive value all fall through to whatever
				Reconcile put there, which is the 25 kg default.
			]]
			if typeof(saved) == "number" and saved == saved and saved > 0 and saved < math.huge then
				(data :: any).competitionNumber[lift] = saved
			elseif typeof((data :: any).competitionNumber[lift]) ~= "number" then
				(data :: any).competitionNumber[lift] = StartingValuesConfig.Forecasted[lift]
			end
		end

		-- The rename is only complete once the old field is gone. See note 1 above.
		(data :: any).forecasted = nil
	end

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
	Version 3 to 4: Competition Scale arrives.

	EVERY EXISTING PLAYER MIGRATES TO UNPROVEN, WITH NO EXCEPTIONS.

	Nothing is read from the old save, because there is nothing to read. No meet
	system has ever existed, so no profile in the DataStore contains a record of
	a successful meet attempt, and there is no data from which a Scale could
	honestly be derived.

	IT MUST NOT BE SEEDED FROM COMPETITION NUMBER. A player with a 182.5 kg
	Squat CN trained that number; they never proved it under competition. Copying
	it here would fabricate a successful meet attempt, hand them a Scale they did
	not earn, and -- once the section 33.4 challenge modifier exists -- silently
	remove a mechanic from their account. GAME_DESIGN.md section 33.8 settles
	this: migrating players start unproven.

	So this step only guarantees the field exists and is well formed. Reconcile
	normally does that already from the template; doing it here too means the
	migration does not depend on Reconcile's behaviour staying the same.

	REPAIR, NEVER OVERWRITE. A value that is already a usable non-negative
	number is left exactly as found, so running this step twice cannot wipe a
	Scale that a later version legitimately set. Only a wrong shape -- a missing
	table, a string, a NaN, a negative -- is replaced with UNPROVEN.
]]
migrations[3] = function(data: ProfileData)
	-- Already in builds (version 6): there is no flat Scale to repair.
	if hasMovedToBuilds(data) and (data :: any).competitionScale == nil then
		return
	end

	if typeof((data :: any).competitionScale) ~= "table" then
		(data :: any).competitionScale = {}
	end

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local saved = (data :: any).competitionScale[lift]

		--[[
			A legitimate Scale is a finite number of 0 or more. 0 is the
			UNPROVEN sentinel and is therefore valid, which is why this accepts
			it where the Competition Number migration above requires above-zero.
		]]
		local usable = typeof(saved) == "number"
			and saved == saved
			and saved >= 0
			and saved < math.huge

		if not usable then
			(data :: any).competitionScale[lift] = PlayerProfileSchema.UNPROVEN_SCALE
		end
	end
end

--[[
	Whether a stored counter is a number this system can safely keep.

	Finite, not NaN, and not negative. Shared by both repairs below so the three
	version-5 records cannot drift apart in what they accept.

	ZERO IS VALID, and is the normal value. That is why this accepts it where the
	Competition Number repair in migrations[2] requires above-zero: a spent amount
	of 0 means "nothing used today", not "missing".
]]
local function isUsableCounter(value: any): boolean
	return typeof(value) == "number"
		and value == value
		and value >= 0
		and value < math.huge
end

--[[
	Brings one `{ spentToday, dayKey, lastUpdatedUnix }` record into shape.
]]
local function repairDailyAllowance(data: ProfileData, field: string)
	local record = (data :: any)[field]

	--[[
		THE DAY KEY IS WHAT GIVES `spentToday` ITS MEANING, so an unusable key
		resets the record as a UNIT. A spent amount with no day attached cannot be
		compared against anything, and keeping it beside an UNSTAMPED key would
		leave the profile in a state the reader never produces.

		THE COST IS ONE EXTRA DAY'S ALLOWANCE, AND THAT IS THE RIGHT DIRECTION.
		Resetting may hand a corrupted profile an allowance it already used.
		Stamping today's key instead would freeze whatever `spentToday` happened to
		hold until tomorrow, which on a corrupt 4.00 locks the player out of
		training for a day. Corruption is our bug either way, and our bug should
		not cost a player their day. It is unreachable by any player action: no
		remote, dev trigger or gameplay system can write these fields.
	]]
	if typeof(record) ~= "table" or typeof(record.dayKey) ~= "string" then
		(data :: any)[field] = {
			spentToday = 0,
			dayKey = DayKey.UNSTAMPED,
			lastUpdatedUnix = 0,
		}
		return
	end

	if not isUsableCounter(record.spentToday) then
		record.spentToday = 0
	end

	if not isUsableCounter(record.lastUpdatedUnix) then
		record.lastUpdatedUnix = 0
	end
end

--[[
	Brings the three per-lift hour counters into shape, under one shared day key.

	Same unit-reset rule as the allowances, and for the same reason: hours with no
	day attached are not data worth keeping. Resetting hours is the gentler repair
	of the two, because a lost hour count restores full H(t) efficiency rather
	than removing anything the player earned.
]]
local function repairTrainingTimeToday(data: ProfileData)
	local record = (data :: any).trainingTimeToday

	if typeof(record) ~= "table" or typeof(record.dayKey) ~= "string" then
		local fresh: any = {
			dayKey = DayKey.UNSTAMPED,
			lastUpdatedUnix = 0,
		}

		for _, lift in ipairs(ProgressionConfig.Lifts) do
			fresh[lift] = 0
		end

		(data :: any).trainingTimeToday = fresh
		return
	end

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		if not isUsableCounter((record :: any)[lift]) then
			(record :: any)[lift] = 0
		end
	end

	if not isUsableCounter(record.lastUpdatedUnix) then
		record.lastUpdatedUnix = 0
	end
end

--[[
	Version 4 to 5: the daily training allowances arrive.

	GAME_DESIGN.md section 34.12. Five counters in three records: the account-wide
	CN allowance, the account-wide technique allowance, and the three per-lift
	training-time accumulators that feed H(t).

	NOBODY IS CREDITED FOR TIME THEY DID NOT SPEND AT A STATION.

	Every migrating player arrives with zero spent, zero hours and an UNSTAMPED
	day key. That is not a grant and not a penalty -- it is the only honest
	reading of a save that predates the system. No profile in the DataStore
	records a minute of station training, because no station has ever existed, so
	there is no data from which a part-spent allowance could be derived.

	AN UNSTAMPED KEY IS NOT A FREE ALLOWANCE. The sentinel matches no real day, so
	the first read after this migration resets the counters to zero -- which is
	already their value. The player then has that day's allowance, exactly as they
	would on any later day. Nothing is backdated and nothing accrued while they
	were offline, so section 34.2's no-offline-progression rule holds by
	construction rather than by a check that could be forgotten.

	REPAIR, NEVER OVERWRITE. Same discipline as migrations[3]. A counter that is
	already usable is left exactly as found, so running this step twice cannot
	wipe a day's spending and let it be spent again.

	NOTHING IS CLAMPED TO A CAP HERE, deliberately. The 4.00 EV daily cap is a
	READER's rule (section 34.1, decision 2) and the config carrying it is
	checkpoint 5B.2. A migration that clamped would silently rewrite a player's
	spending because a balance constant moved, which is the quiet data edit the
	repair-never-overwrite rule exists to prevent.
]]
migrations[4] = function(data: ProfileData)
	repairDailyAllowance(data, "cnAllowance")
	repairDailyAllowance(data, "techniqueAllowance")
	repairTrainingTimeToday(data)
end

--[[
	=========================================================================
	WEIGHT-CLASS BUILDS (version 6, GAME_DESIGN.md 29.11)
	=========================================================================
]]

local function isUsableCompetitionNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value > 0 and value < math.huge
end

-- A finite number of 0 or more: a Scale (0 = UNPROVEN) or a best Total (0 = none).
local function isUsableProvenWeight(value: any): boolean
	return typeof(value) == "number" and value == value and value >= 0 and value < math.huge
end

--[[
	The build key for a bodyweight: the weight class label, e.g. "59 kg". Nil
	for a bodyweight that is not a usable positive number.
]]
function PlayerProfileSchema.classKeyFor(bodyweightKg: any): string?
	if not isUsableCompetitionNumber(bodyweightKg) then
		return nil
	end
	return WeightClass.resolve(bodyweightKg).label
end

-- Position of a class key in WeightClassConfig.Classes (1 = lightest), or nil if it is not a class.
local function classIndex(classKey: string): number?
	for index, class in ipairs(WeightClassConfig.Classes) do
		if class.label == classKey then
			return index
		end
	end
	return nil
end

--[[
	A new build. Its Competition Number is `fromCN` (copied, never shared) or
	the starting values; its Scale is UNPROVEN and it has no best Total.

	SCALE AND BEST TOTAL ALWAYS START EMPTY. Section 29.11: proof never carries
	between classes, so a new build has proven nothing.
]]
local function newBuild(fromCN: CompetitionNumber?): Build
	local competitionNumber: any = {}
	local competitionScale: any = {}

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local copied = if fromCN then (fromCN :: any)[lift] else nil
		competitionNumber[lift] = if isUsableCompetitionNumber(copied)
			then copied
			else StartingValuesConfig.Forecasted[lift]
		competitionScale[lift] = PlayerProfileSchema.UNPROVEN_SCALE
	end

	return {
		competitionNumber = competitionNumber,
		competitionScale = competitionScale,
		bestTotalKg = PlayerProfileSchema.NO_TOTAL,
	}
end

--[[
	Fills in any MISSING part of an existing build. ProfileStore's Reconcile
	cannot reach inside the `builds` map (its keys are not in the template), so
	this is that job for builds.

	ONLY MISSING FIELDS ARE FILLED, never corrupt ones. A NaN Competition
	Number or Scale is left for the operations to refuse, exactly as before
	version 6, rather than quietly replaced on every load.
]]
local function fillMissing(build: any)
	if typeof(build.competitionNumber) ~= "table" then
		build.competitionNumber = {}
	end
	if typeof(build.competitionScale) ~= "table" then
		build.competitionScale = {}
	end
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		if build.competitionNumber[lift] == nil then
			build.competitionNumber[lift] = StartingValuesConfig.Forecasted[lift]
		end
		if build.competitionScale[lift] == nil then
			build.competitionScale[lift] = PlayerProfileSchema.UNPROVEN_SCALE
		end
	end
	if build.bestTotalKg == nil then
		build.bestTotalKg = PlayerProfileSchema.NO_TOTAL
	end
end

--[[
	THE ONE PLACE A BUILD IS CREATED. Returns the build for `classKey`, creating
	it on first entry to that class, or nil when `classKey` is not a weight class.

	The rules (GAME_DESIGN.md 29.11, user 2026-10-28):
	  - A class the player has had: its build is returned exactly as saved.
	  - A class entered for the first time: the Competition Number is COPIED
	    from the closest LIGHTER build. Moving up keeps your kilograms (you skip
	    nothing); a class skipped on the way up gets what you had below it.
	  - No lighter build (unreachable today -- every lifter starts in the
	    lightest class): the starting values.
	  - Scale and best Total always start empty: proof never changes class.

	Never deletes or replaces an existing build. Pure: no clock, no Player.
	The future bodyweight system must call this for every class it crosses, so
	each crossed class keeps the numbers the lifter had while in it.
]]
function PlayerProfileSchema.ensureBuild(data: ProfileData, classKey: string): Build?
	local index = classIndex(classKey)
	if index == nil then
		return nil
	end

	if typeof(data.builds) ~= "table" then
		data.builds = {}
	end

	local existing = data.builds[classKey]
	if typeof(existing) == "table" then
		fillMissing(existing)
		return existing
	end

	local fromCN: CompetitionNumber? = nil
	for lighter = index - 1, 1, -1 do
		local below = data.builds[WeightClassConfig.Classes[lighter].label]
		if typeof(below) == "table" and typeof(below.competitionNumber) == "table" then
			fromCN = below.competitionNumber
			break
		end
	end

	local created = newBuild(fromCN)
	data.builds[classKey] = created
	return created
end

--[[
	Makes sure the build for the player's CURRENT class exists. Run by migrate()
	on every load, which is how a brand new profile gets its starting build.

	An unusable bodyweight creates nothing: without a class there is no build to
	make, and guessing one would file the numbers under the wrong class.
]]
function PlayerProfileSchema.ensureActiveBuild(data: ProfileData): Build?
	local bodyweight = (data :: any).bodyweight
	local classKey = PlayerProfileSchema.classKeyFor(if typeof(bodyweight) == "table" then bodyweight.currentKg else nil)
	if classKey == nil then
		return nil
	end
	return PlayerProfileSchema.ensureBuild(data, classKey)
end

--[[
	Version 5 to 6: weight-class builds.

	THE FLAT COMPETITION NUMBER AND SCALE MOVE, TOGETHER, INTO ONE BUILD:

		competitionNumber {S, B, D}           ->  builds[classKey].competitionNumber
		competitionScale  {S, B, D}           ->  builds[classKey].competitionScale
		(new)                                 ->  builds[classKey].bestTotalKg = 0

	classKey is the class of the player's CURRENT bodyweight, the only build
	they have ever had (no bodyweight system has ever changed anyone's class).
	Section 33.8: no value is invented and nothing is lost.

	  - Each Competition Number is copied exactly when usable. An unusable one
	    (NaN, missing, not above 0) gets the starting value -- the same repair
	    migrations[2] applies -- because a build must hold a weight the
	    difficulty engine can divide by.
	  - Each Scale is copied exactly when usable (0 = UNPROVEN stays 0). An
	    unusable one becomes UNPROVEN: under-crediting is the safe failure.
	  - bestTotalKg starts at NO_TOTAL. No meet has ever saved a total, so
	    there is nothing to copy.

	Then both flat fields are REMOVED, so the profile has one answer to "what
	is this lifter's Competition Number".

	ANY BUILDS ALREADY PRESENT ARE REPLACED BY THE MOVED ONE. A v5 save has no
	`builds` key at all; Reconcile adds the template's empty table. Starting
	from an empty map guarantees nothing but the real numbers end up there.

	AN UNUSABLE BODYWEIGHT: the class falls back to that of the starting
	bodyweight (every player's class today) with a warning, so the numbers are
	kept rather than dropped.
]]
migrations[5] = function(data: ProfileData)
	local legacyCN = (data :: any).competitionNumber
	local legacyScale = (data :: any).competitionScale

	-- IDEMPOTENT: nothing flat left and builds already filled means it already ran. Change nothing.
	if legacyCN == nil and legacyScale == nil and hasMovedToBuilds(data) then
		return
	end

	local bodyweight = (data :: any).bodyweight
	local classKey = PlayerProfileSchema.classKeyFor(if typeof(bodyweight) == "table" then bodyweight.currentKg else nil)
	if classKey == nil then
		classKey = WeightClass.resolve(StartingValuesConfig.BodyweightKg).label
		warn(string.format(
			"[PlayerProfileSchema] v5 to v6: unusable bodyweight; filing the build under %s",
			classKey :: string
		))
	end

	local competitionNumber: any = {}
	local competitionScale: any = {}
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local cn = if typeof(legacyCN) == "table" then legacyCN[lift] else nil
		competitionNumber[lift] = if isUsableCompetitionNumber(cn) then cn else StartingValuesConfig.Forecasted[lift]

		local scale = if typeof(legacyScale) == "table" then legacyScale[lift] else nil
		competitionScale[lift] = if isUsableProvenWeight(scale) then scale else PlayerProfileSchema.UNPROVEN_SCALE
	end

	data.builds = {
		[classKey :: string] = {
			competitionNumber = competitionNumber,
			competitionScale = competitionScale,
			bestTotalKg = PlayerProfileSchema.NO_TOTAL,
		},
	}

	(data :: any).competitionNumber = nil;
	(data :: any).competitionScale = nil
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
		-- The template's `builds` is empty on purpose; this creates the starting build.
		PlayerProfileSchema.ensureActiveBuild(data)
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

	-- Only a fully current profile: a stalled migration may still hold the flat fields.
	if version == PlayerProfileSchema.CURRENT_VERSION then
		PlayerProfileSchema.ensureActiveBuild(data)
	end

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
