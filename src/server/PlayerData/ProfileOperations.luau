--!strict
--[[
	ProfileOperations
	Server / PlayerData

	The authoritative operations that may be performed on a player's saved data.

	WHY THIS IS A SEPARATE MODULE FROM PlayerDataService

	Everything here is a pure function of a ProfileData table plus a server
	timestamp. No Player, no ProfileStore, no sessions. That is what makes the
	rules testable: PlayerDataProbe drives whole days of regeneration and every
	rejection case in a few milliseconds, against the same code the live game
	runs, with no player in the server.

	PlayerDataService is the thin layer above this that maps a Player to their
	profile, refuses when the session is not active, and nothing else.

	EXPLICIT OPERATIONS, NOT GENERIC MUTATION

	There is deliberately no setField(path, value) here. Every function below
	expresses a legitimate thing the game may do, validates its own arguments,
	and can therefore enforce an invariant that a generic path-setter could not.
	A reward system asks to ADD Competition Number or to SETTLE an allowance; it
	never replaces an authoritative value outright.

	SERVER ONLY, AND NO CLIENT INPUT REACHES HERE

	This module is in ServerScriptService and creates no remotes. Every caller
	passes a server clock. No function takes a timestamp from gameplay input, and
	no function should ever be given one: see the clock notes in
	ResourceRegeneration.

	THE TWO TRAINING AWARDS

	applyTrainingProgression (checkpoint 5B.5) is the only Competition Number
	award; applyTechniqueTraining (checkpoint 5B.7) is the only rack technique
	award. Their only gameplay caller is the gym training rack
	(TrainingStationService, through PlayerDataService). Meets against other
	players raise CN only through the meet allowance (settleMeetCompetitionNumber);
	the old Competition Budget is not wired to anything.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))
local CoinConfig = require(ConfigFolder:WaitForChild("CoinConfig"))
local MeetLevelConfig = require(ConfigFolder:WaitForChild("MeetLevelConfig"))
local AdminConfig = require(ConfigFolder:WaitForChild("AdminConfig"))
local EntranceConfig = require(ConfigFolder:WaitForChild("EntranceConfig"))
local CelebrationConfig = require(ConfigFolder:WaitForChild("CelebrationConfig"))
local EmoteConfig = require(ConfigFolder:WaitForChild("EmoteConfig"))
local LoadoutConfig = require(ConfigFolder:WaitForChild("LoadoutConfig"))
local ClothesConfig = require(ConfigFolder:WaitForChild("ClothesConfig"))
local BodyweightConfig = require(ConfigFolder:WaitForChild("BodyweightConfig"))
local StartingValuesConfig = require(ConfigFolder:WaitForChild("StartingValuesConfig"))
local WeightClassConfig = require(ConfigFolder:WaitForChild("WeightClassConfig"))
local QuestConfig = require(ConfigFolder:WaitForChild("QuestConfig"))
local KitchenConfig = require(ConfigFolder:WaitForChild("KitchenConfig"))
local LuckConfig = require(ConfigFolder:WaitForChild("LuckConfig"))
local RankConfig = require(ConfigFolder:WaitForChild("RankConfig"))
local CoachingConfig = require(ConfigFolder:WaitForChild("CoachingConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local CompetitionNumberReward = require(ProgressionFolder:WaitForChild("CompetitionNumberReward"))
local TrainingAllowance = require(ProgressionFolder:WaitForChild("TrainingAllowance"))
local TechniqueTraining = require(ProgressionFolder:WaitForChild("TechniqueTraining"))
local GearStats = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Economy"):WaitForChild("GearStats"))
local WeightClass = require(ProgressionFolder:WaitForChild("WeightClass"))
local MeetCnAllowance = require(ProgressionFolder:WaitForChild("MeetCnAllowance"))
local DayKey = require(ProgressionFolder:WaitForChild("DayKey"))
local GainBoosts = require(ProgressionFolder:WaitForChild("GainBoosts"))
local AttemptRules = require(Shared:WaitForChild("Meet"):WaitForChild("AttemptRules"))

local PlayerProfileSchema = require(script.Parent.PlayerProfileSchema)

local ProfileOperations = {}

type ProfileData = PlayerProfileSchema.ProfileData

--[[
	(The Competition Budget, whose consumption could never fail on amount, and
	Training Energy, the all-or-nothing resource it was once contrasted with,
	were removed in schema versions 10 and 8.)

	ON VALIDATING THE SIZE OF A COMPETITION NUMBER AWARD

	There is deliberately no maximum-delta constant here. An earlier draft
	capped a single add at 100 kg, which was an implementation judgement dressed
	as a rule: it appears nowhere in GAME_DESIGN.md, and it would have let any
	caller award 100 kg at a stroke while rejecting a legitimate larger
	weight-class translation.

	The real bound is derivable, but only by the reward engine, which alone
	knows what it is paying for:

		maximum legitimate award = ProgressionReference x BaseProgressRate
		                           x EV x Hill(PP)

	A single attempt tops out near 2.7 kg and a full meet's worth near 8.2 kg at
	the largest reference. The foundation cannot tell those apart, so it enforces
	only what is universally true -- finite, and a result that remains a positive
	weight -- and the derived bound is applied where the delta is computed.
]]

--[[
	True for a number that is safe to store and to do arithmetic with.

	Rejects NaN and both infinities. NaN is the dangerous one: it propagates
	silently through every later addition and comparison, so a single NaN write
	permanently poisons a stat.
]]
local function isFiniteNumber(value: any): boolean
	if typeof(value) ~= "number" then
		return false
	end

	-- NaN is the only value not equal to itself.
	if value ~= value then
		return false
	end

	return value ~= math.huge and value ~= -math.huge
end

ProfileOperations.isFiniteNumber = isFiniteNumber

--[[
	=========================================================================
	WEIGHT-CLASS BUILDS  (GAME_DESIGN.md 29.11, schema version 6)
	=========================================================================

	Competition Number, Competition Scale and the best Total live in one build
	per weight class. The ACTIVE build -- the one training and the stats screen
	use -- is the class of the current bodyweight, derived on every read. A
	meet credits the class frozen at its weigh-in instead, so its writes name
	the class explicitly.
]]

--[[
	The build key of the player's current class, e.g. "59 kg", or nil when the
	stored bodyweight is unusable.
]]
function ProfileOperations.getActiveClassKey(data: ProfileData): string?
	local bodyweight = (data :: any).bodyweight
	return PlayerProfileSchema.classKeyFor(if typeof(bodyweight) == "table" then bodyweight.currentKg else nil)
end

--[[
	The saved build for one class, or nil when the player has never been in it
	or its shape is wrong. READ-ONLY: never creates a build (only
	PlayerProfileSchema.ensureBuild does).
]]
function ProfileOperations.getBuild(data: ProfileData, classKey: string): PlayerProfileSchema.Build?
	local builds = (data :: any).builds
	if typeof(builds) ~= "table" or typeof(classKey) ~= "string" then
		return nil
	end
	local build = builds[classKey]
	if typeof(build) ~= "table"
		or typeof(build.competitionNumber) ~= "table"
		or typeof(build.competitionScale) ~= "table"
	then
		return nil
	end
	return build
end

-- The build of the player's current class, or nil. Every load creates it (migrate).
function ProfileOperations.getActiveBuild(data: ProfileData): PlayerProfileSchema.Build?
	local classKey = ProfileOperations.getActiveClassKey(data)
	if classKey == nil then
		return nil
	end
	return ProfileOperations.getBuild(data, classKey)
end

--[[
	=========================================================================
	COMPETITION NUMBER  (of the ACTIVE build)
	=========================================================================
]]

--[[
	The player's Competition Number for one lift in their current class, in
	kilograms, or nil if the lift name is not one of the three, there is no
	active build, or the stored value is unusable.
]]
function ProfileOperations.getCompetitionNumber(data: ProfileData, lift: string): number?
	if not ProgressionConfig.isLift(lift) then
		return nil
	end

	local build = ProfileOperations.getActiveBuild(data)
	if build == nil then
		return nil
	end

	local value = (build.competitionNumber :: any)[lift]

	if not isFiniteNumber(value) then
		return nil
	end

	return value
end

--[[
	THE FOUNDATION PRIMITIVE FOR CHANGING A COMPETITION NUMBER.

	NOT A REWARD API, AND NOT EXPOSED ON PlayerDataService. Nothing in gameplay
	may reach this, because it accepts an arbitrary kilogram delta and so cannot
	by itself tell a 1.4 kg attempt reward from a 300 kg mistake.

	Two separate operations are built on top of it, each owning its own bound:

	  1. TRAINING PROGRESSION AWARD -- applyTrainingProgression, below. Takes
	     observed station seconds, never EV and never kilograms, and derives
	     both itself:

	         earnedEV = TrainingAllowance plan (H(t), clamped to the 4.00 EV cap)
	         deltaKg  = ProgressionReference x BaseProgressRate
	                    x earnedEV x Hill(PP)

	     Bounded by construction, so there is nothing for a caller to get
	     wrong. Implemented in checkpoint 5B.5.

	  2. ~~WEIGHT-CLASS / BUILD TRANSLATION under RP Preservation.~~ Not needed
	     any more (user, 2026-10-28, section 29.11): a class change never
	     recalculates a Competition Number. Each class keeps its own build, and
	     a first-time build copies the closest lighter one
	     (PlayerProfileSchema.ensureBuild). Still, no universal kilogram cap
	     belongs here; the training award owns its bound.

	The training award and the dev harness are its only callers.

	Returns whether it was applied and the resulting value. A rejection changes
	nothing, so a caller cannot half-apply a change.

	DELTA ONLY. There is no setCompetitionNumber, because an absolute setter is
	the shape a compromised or buggy caller could use to write any value at all.
	A Competition Number moves by deltas the server computed.

	Rejects:
	  - a lift that is not Squat, Bench or Deadlift
	  - a non-finite delta, which includes NaN and both infinities
	  - any delta that would drive the number to zero or below, because a
	    Competition Number of zero means "cannot lift" and the difficulty engine
	    divides by it
	  - a stored value that is already unusable, which is repaired by migration
	    rather than written over here

	It does NOT bound the magnitude. See the note above on why that bound
	belongs to the reward engine rather than here.

	A NEGATIVE DELTA IS ALLOWED. Nothing in the frozen design reduces a
	Competition Number today, but the bodyweight and weight-class translation of
	section 29.11 legitimately will, and it is better that it come through this
	validated path than around it.
]]
function ProfileOperations.applyCompetitionNumberDelta(
	data: ProfileData,
	lift: string,
	deltaKg: number
): (boolean, number?)
	if not ProgressionConfig.isLift(lift) then
		return false, nil
	end

	if not isFiniteNumber(deltaKg) then
		return false, nil
	end

	-- The ACTIVE build: training is done in the class the lifter is in now.
	local build = ProfileOperations.getActiveBuild(data)
	if build == nil then
		return false, nil
	end

	local current = (build.competitionNumber :: any)[lift]

	if not isFiniteNumber(current) then
		return false, nil
	end

	local updated = current + deltaKg

	--[[
		Re-checked after the addition. Two finite numbers can sum to infinity,
		and the result still has to be a weight the engine can divide by.
	]]
	if not isFiniteNumber(updated) or updated <= 0 then
		return false, current
	end

	(build.competitionNumber :: any)[lift] = updated

	return true, updated
end

--[[
	=========================================================================
	COMPETITION SCALE  (GAME_DESIGN.md section 33)
	=========================================================================

	Competition Scale is the heaviest weight the lifter has actually proven in an
	eligible meet. Competition Number is what training built; this is what
	competition confirmed.

	Two readers and two monotone raises (Scale and best Total) live below. The
	raises are INTERNAL, and their only production caller is the meet
	(MockMeetService) -- read the boundary note before wiring anything else to
	them, because the thing they do not do is the important part.
]]

-- One lift's stored Scale in a build, or nil when the lift or the value is unusable.
-- A build's Competition Number for one lift, or nil when it is unusable (not a positive finite weight).
local function buildCompetitionNumber(build: PlayerProfileSchema.Build?, lift: string): number?
	if build == nil or not ProgressionConfig.isLift(lift) then
		return nil
	end
	local value = (build.competitionNumber :: any)[lift]
	if not isFiniteNumber(value) or value <= 0 then
		return nil
	end
	return value
end

local function buildScale(build: PlayerProfileSchema.Build?, lift: string): number?
	if build == nil or not ProgressionConfig.isLift(lift) then
		return nil
	end

	local value = (build.competitionScale :: any)[lift]

	if not isFiniteNumber(value) or value < 0 then
		return nil
	end

	return value
end

--[[
	The player's Competition Scale for one lift, in kilograms, in their CURRENT
	class -- or in `classKey`'s build when one is given.

	Returns `PlayerProfileSchema.UNPROVEN_SCALE` (0) when the lift has never
	been proven in that class. Returns nil when the lift name is not one of the
	three, the build does not exist, or the stored value is unusable.

	A CALLER MUST NOT TREAT 0 AS A WEIGHT. It is the absence of an achievement,
	not a 0 kg lift. Use isCompetitionScaleProven to tell them apart.
]]
function ProfileOperations.getCompetitionScale(data: ProfileData, lift: string, classKey: string?): number?
	local build = if classKey ~= nil
		then ProfileOperations.getBuild(data, classKey)
		else ProfileOperations.getActiveBuild(data)
	return buildScale(build, lift)
end

--[[
	Whether this lift has ever been successfully proven in an eligible meet.

	False for a brand new player, for every profile migrated from version 3, and
	whenever the stored value is unusable. A corrupt Scale reads as unproven
	rather than as an achievement, because the safe failure is to under-credit.
]]
function ProfileOperations.isCompetitionScaleProven(data: ProfileData, lift: string): boolean
	local value = ProfileOperations.getCompetitionScale(data, lift)
	return value ~= nil and value > PlayerProfileSchema.UNPROVEN_SCALE
end

--[[
	What a raise attempt did.

		"Raised"     the stored Scale increased to provenKg
		"Unchanged"  the input was valid but not heavier than what is stored
		"Rejected"   the input or the stored value was unusable; nothing written

	"Unchanged" is a SUCCESS, not a failure. A lifter who opens at 150 kg when
	they have already proven 180 kg made a perfectly legal lift that simply does
	not move their best. Collapsing that into a boolean alongside "Rejected"
	would make a routine opener indistinguishable from a malformed request, and
	a future meet handler needs to tell those apart to log one and alert on the
	other.
]]
export type ScaleRaiseOutcome = "Raised" | "Unchanged" | "Rejected"

--[[
	THE MONOTONE COMPETITION SCALE RAISE, from GAME_DESIGN.md section 33.7.

		New Scale = max(Old Scale, provenKg)

	=========================================================================
	SECURITY BOUNDARY -- READ THIS BEFORE GIVING IT A CALLER
	=========================================================================

	THIS FUNCTION DOES NOT VERIFY THAT A MEET HAPPENED. It cannot. It receives a
	kilogram number and a lift name, and it has no way to know whether that
	weight was ever on a bar, whether the attempt was judged a good lift,
	whether the meet was eligible, or which weight class the lifter was in. It
	is a low-level data transformation, NOT proof of an achievement.

	Everything it does not check is therefore the CALLER's responsibility, and
	only one kind of caller may ever exist: a server-authoritative meet-result
	handler (today: MockMeetService) that has already established all of the
	following.

	  1. The attempt was actually taken in a meet this server was running.
	  2. The attempt was judged a GOOD LIFT. A failed attempt may never raise
	     Scale at any weight (section 33.6). `MeetTotal.bestSuccessful` is the
	     right source: it filters on result == "GoodLift" and returns the
	     heaviest, so a failure cannot reach this function through it.
	  3. The meet was ELIGIBLE under section 33.7. Solo and Official both
	     qualify; what else does is still [TBD].
	  4. `classKey` IS THE CLASS FROZEN AT THE MEET'S WEIGH-IN (section 32.7),
	     never the bodyweight at the end of the meet. A Scale proven in one
	     class is NOT proof in another (section 29.11), and naming the class
	     here is what keeps it in its own build.
	  5. The meet ENDED WITH A TOTAL (section 33.3b, user 2026-10-29). A
	     bomb-out, or leaving before the meet is over, saves nothing.

	NO CLIENT, REMOTE, DEV TRIGGER OR NON-MEET GAMEPLAY SYSTEM MAY REACH THIS.
	A client-supplied weight arriving here would let a player write their own
	proven strength, which is the single worst thing that could happen to this
	field. It is not exposed on PlayerDataService, so the gateway every gameplay
	system actually uses has no path to it; the meet requires this module
	itself and writes through PlayerDataService.update, which refuses an
	inactive session.

	THE BUILD MUST ALREADY EXIST. A raise never creates a build: the weigh-in
	class is the class the lifter was in, whose build every load creates, so a
	missing one is a bug and is "Rejected".

	=========================================================================

	PURE AND DETERMINISTIC. No clock, no Player, no ProfileStore, no randomness.
	Same profile and same arguments always give the same result, which is what
	lets the probe drive every branch in microseconds against the real code.

	Returns (outcome, resultingScaleKg). The number is the Scale AFTER the call
	for "Raised" and "Unchanged", and nil for "Rejected" -- because a rejection
	establishes nothing, and handing back a number there invites a caller to
	treat a refused write as a value worth storing or displaying.
]]
function ProfileOperations.raiseCompetitionScale(
	data: ProfileData,
	classKey: string,
	lift: string,
	provenKg: number
): (ScaleRaiseOutcome, number?)
	if not ProgressionConfig.isLift(lift) then
		return "Rejected", nil
	end

	local build = ProfileOperations.getBuild(data, classKey)
	if build == nil then
		return "Rejected", nil
	end

	--[[
		A PROVEN WEIGHT MUST BE A REAL WEIGHT: finite, and strictly above zero.

		Zero is rejected rather than treated as a no-op. It is the UNPROVEN
		sentinel, and no bar is ever loaded to 0 kg, so a 0 arriving here means
		the caller has a bug -- most likely passing an absent value through.
		Saying so is more useful than silently doing nothing.

		Negatives, NaN and both infinities are rejected for the same reason.
		NaN is the dangerous one: `math.max(nan, x)` is implementation-defined
		and a NaN reaching the profile would poison every later comparison on a
		field that is supposed to only ever rise.
	]]
	if not isFiniteNumber(provenKg) or provenKg <= 0 then
		return "Rejected", nil
	end

	local current = buildScale(build, lift)

	--[[
		A CORRUPT STORED SCALE IS REFUSED, NOT REPAIRED.

		If the stored value is unusable we cannot know whether it was higher
		than provenKg, so writing would be guessing at a proven achievement.
		Repair is the migrations' job (migrations[3], and migrations[5] when the
		Scale moved into a build), not this write's.
	]]
	if current == nil then
		return "Rejected", nil
	end

	--[[
		MONOTONE. A lower or equal weight leaves the record exactly as it was.
		Written as an explicit comparison rather than math.max so that the
		"nothing was written" case is a real branch that can be asserted,
		rather than a redundant assignment of the same number.
	]]
	if provenKg <= current then
		return "Unchanged", current
	end

	(build.competitionScale :: any)[lift] = provenKg

	return "Raised", provenKg
end

--[[
	THE MONOTONE BEST-TOTAL RAISE (GAME_DESIGN.md 29.11, user 2026-10-28).

		New best = max(Old best, totalKg)

	Same contract and the same security boundary as raiseCompetitionScale
	above: pure, never creates a build, and its only caller is a meet-result
	handler that has established the meet happened, was FINISHED, and that
	`totalKg` is MeetTotal's total of that one meet (three best lifts of the
	same meet -- never a sum of Scales, section 33.8). `classKey` is the
	weigh-in class.

	Personal only: it is never a record and never feeds the gym records wall.
]]
function ProfileOperations.raiseBestTotal(
	data: ProfileData,
	classKey: string,
	totalKg: number
): (ScaleRaiseOutcome, number?)
	local build = ProfileOperations.getBuild(data, classKey)
	if build == nil then
		return "Rejected", nil
	end

	if not isFiniteNumber(totalKg) or totalKg <= 0 then
		return "Rejected", nil
	end

	local current = build.bestTotalKg
	if not isFiniteNumber(current) or current < 0 then
		return "Rejected", nil
	end

	if totalKg <= current then
		return "Unchanged", current
	end

	build.bestTotalKg = totalKg

	return "Raised", totalKg
end

--[[
	THE MONOTONE OFFICIAL-MEET BEST RAISE (GAME_DESIGN.md 31.6, "The gym record
	wall — first build", user 2026-10-30; schema version 11).

		New best = max(Old best, liftedKg)

	Same contract and the same security boundary as raiseCompetitionScale
	above: pure, never creates a build. Its only caller is a server-run
	OFFICIAL meet (today: LocalMeetService, when the meet rewards) that has
	established the attempt was judged a GOOD LIFT at `liftedKg` and that
	`classKey` is the weigh-in class. Unlike Scale it needs NO total: the user
	chose that any good lift at an official meet counts for the wall. Solo /
	Mock Meets never call it.
]]
function ProfileOperations.raiseOfficialMeetBest(
	data: ProfileData,
	classKey: string,
	lift: string,
	liftedKg: number
): (ScaleRaiseOutcome, number?)
	if not ProgressionConfig.isLift(lift) then
		return "Rejected", nil
	end

	local build = ProfileOperations.getBuild(data, classKey)
	local bests = build and (build :: any).officialMeetBest
	if typeof(bests) ~= "table" then
		return "Rejected", nil
	end

	if not isFiniteNumber(liftedKg) or liftedKg <= 0 then
		return "Rejected", nil
	end

	-- A corrupt stored best is refused, not repaired (as for Scale).
	local current = bests[lift]
	if not isFiniteNumber(current) or current < 0 then
		return "Rejected", nil
	end

	if liftedKg <= current then
		return "Unchanged", current
	end

	bests[lift] = liftedKg

	return "Raised", liftedKg
end

--[[
	The lifter's gym-wall Total in a class: their official-meet best Squat +
	Bench + Deadlift, even from different meets (GAME_DESIGN.md 31.6; this sum
	is for the gym wall ONLY, never a World Record or best Total). Nil until
	all three have a best, or when the data is unusable.
]]
function ProfileOperations.getOfficialMeetBestTotal(data: ProfileData, classKey: string): number?
	local build = ProfileOperations.getBuild(data, classKey)
	local bests = build and (build :: any).officialMeetBest
	if typeof(bests) ~= "table" then
		return nil
	end
	local total = 0
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		local kg = bests[lift]
		if not isFiniteNumber(kg) or kg <= 0 then
			return nil
		end
		total += kg
	end
	return total
end

--[[
	=========================================================================
	MEET CN ALLOWANCE AND CAREER  (GAME_DESIGN.md 33.3b, schema version 9)
	=========================================================================

	SECURITY BOUNDARY: the same as raiseCompetitionScale above. These cannot
	know that a meet happened; their only caller is a server-run meet against
	other players (LocalMeetService) that has established the attempts, their
	verdicts, the weigh-in class and Competition Number, and whether the meet
	had a total. No client, remote or dev trigger may reach them.
]]

-- One lift's meet allowance in a build, or nil when the build, lift or shape is wrong.
local function meetAllowanceOf(data: ProfileData, classKey: string, lift: string): PlayerProfileSchema.Resource?
	if not ProgressionConfig.isLift(lift) then
		return nil
	end
	local build = ProfileOperations.getBuild(data, classKey)
	local allowance = build and (build :: any).meetAllowance
	local resource = if typeof(allowance) == "table" then allowance[lift] else nil
	if typeof(resource) ~= "table" then
		return nil
	end
	return resource
end

--[[
	How far a meet could raise this lift's CN right now, as a share of the CN
	(0.12 = +12%), WITHOUT writing anything. Nil when the class has no
	allowance (the unlimited class) or the data is unusable. For screens.
]]
function ProfileOperations.getMeetAllowanceShare(data: ProfileData, classKey: string, lift: string,
	nowUnix: number): number?
	local resource = meetAllowanceOf(data, classKey, lift)
	local build = ProfileOperations.getBuild(data, classKey)
	local cn = build and buildCompetitionNumber(build, lift)
	if resource == nil or cn == nil then
		return nil
	end
	return MeetCnAllowance.shareAvailable(resource, nowUnix, lift, classKey, cn)
end

export type MeetCnOutcome = "Raised" | "Unchanged" | "Rejected"

--[[
	Settles one lift of a meet against other players (MeetCnAllowance.settle)
	and writes the raise. `cnAtWeighInKg` is the CN the meet used; `raises`
	false for a meet without a total, where only the misses cost.
	`costMultiplier`: see MeetCnAllowance.settle (a meet with one real player).

	Returns the outcome, the lift's CN afterwards, and the days used.
	"Raised": the CN went up. "Unchanged": settled, no raise (misses may still
	have used allowance). "Rejected": nothing written (unusable data, or a class
	with no allowance).

	MONOTONE: the CN is only ever raised, and never past what the allowance
	paid for. If training moved the CN since the weigh-in (it cannot during a
	meet), the higher of the two stays.
]]
function ProfileOperations.settleMeetCompetitionNumber(data: ProfileData, classKey: string, lift: string,
	cnAtWeighInKg: number, history: AttemptRules.AttemptHistory, raises: boolean,
	nowUnix: number, costMultiplier: number?): (MeetCnOutcome, number?, number)
	local resource = meetAllowanceOf(data, classKey, lift)
	local build = ProfileOperations.getBuild(data, classKey)
	local current = build and buildCompetitionNumber(build, lift)
	if resource == nil or build == nil or current == nil or not isFiniteNumber(cnAtWeighInKg) or cnAtWeighInKg <= 0 then
		return "Rejected", nil, 0
	end
	local outcome = MeetCnAllowance.settle(resource, nowUnix, lift, classKey, cnAtWeighInKg, history, raises,
		costMultiplier)
	if outcome == nil then
		return "Rejected", current, 0
	end
	if outcome.newCnKg > current + 1e-9 then
		-- A meet meal (GAME_DESIGN §40.7, user 2026-11-23) raises the raise itself by its percent; it uses no more of
		-- the allowance (as steaks give more strength from the same training).
		local raised = current + (outcome.newCnKg - current) * (1 + GainBoosts.meetBonus((data :: any).boosts, nowUnix))
		if not isFiniteNumber(raised) or raised < outcome.newCnKg then
			raised = outcome.newCnKg
		end
		(build.competitionNumber :: any)[lift] = raised
		return "Raised", raised, outcome.daysUsed
	end
	return "Unchanged", current, outcome.daysUsed
end

-- Counts one Local meet win (1st place in a meet against other players). Returns the new count, or nil.
function ProfileOperations.addLocalWin(data: ProfileData): number?
	local career = (data :: any).career
	if typeof(career) ~= "table" or not isFiniteNumber(career.localWins) or career.localWins < 0 then
		return nil
	end
	career.localWins += 1
	return career.localWins
end

--[[
	Adds one of a meet title (schema 15; GAME_DESIGN §35.8) and returns how
	many the lifter now has, or nil when the career is unusable or the id is
	not a short non-empty string. SECURITY BOUNDARY: the caller
	(LocalMeetService) decides the title from the meet's result and
	MeetLevelConfig on the server.
]]
function ProfileOperations.addTitle(data: ProfileData, titleId: string): number?
	local career = (data :: any).career
	local titles = if typeof(career) == "table" then career.titles else nil
	if typeof(titles) ~= "table" or typeof(titleId) ~= "string" or #titleId == 0 or #titleId > 40 then
		return nil
	end
	local count = titles[titleId]
	titles[titleId] = (if typeof(count) == "number" and count >= 1 then count else 0) + 1
	return titles[titleId]
end

-- A copy of the lifter's titles (id -> count; only usable entries).
function ProfileOperations.getTitles(data: ProfileData): { [string]: number }
	local career = (data :: any).career
	local titles = if typeof(career) == "table" then career.titles else nil
	local copy: { [string]: number } = {}
	for id, count in pairs(if typeof(titles) == "table" then titles else {}) do
		if typeof(id) == "string" and typeof(count) == "number" and count >= 1 then
			copy[id] = count
		end
	end
	return copy
end

--[[
	THE NUMBERED STATE CHAMPION BADGES (schema 26; GAME_DESIGN §36.4, MeetLevelConfig.ChampionBadge). season
	("2026-11") -> the badge's game-wide number, or 0 while its number is on its way. One per season. The number itself
	comes from the server's game-wide counter (ChampionBadges); these rules only keep the map tidy and never make one up.
]]
export type ChampionBadgeOutcome = "Added" | "AlreadyThisSeason" | "Rejected"
export type ChampionBadgeView = { season: string, number: number }

local function championBadgesOf(data: ProfileData): { [string]: number }?
	local career = (data :: any).career
	local badges = if typeof(career) == "table" then career.stateChampionBadges else nil
	return if typeof(badges) == "table" then badges else nil
end

local function isSeason(season: any): boolean
	return typeof(season) == "string" and string.match(season, "^%d%d%d%d%-%d%d$") ~= nil
end

-- A usable badge number: 0 (on its way) or a whole number from 1 up.
local function isBadgeNumber(number: any): boolean
	return isFiniteNumber(number) and number >= 0 and number == math.floor(number)
end

-- Gives the State Champion badge for `season` with `number` (0 = on its way), unless that season already has one.
function ProfileOperations.addStateChampionBadge(data: ProfileData, season: string, number: number): ChampionBadgeOutcome
	local badges = championBadgesOf(data)
	if badges == nil or not isSeason(season) or not isBadgeNumber(number) then
		return "Rejected"
	end
	if badges[season] ~= nil then
		return "AlreadyThisSeason"
	end
	badges[season] = number
	return "Added"
end

-- Fills in the number of a badge whose number was on its way (0). Never changes a number already given.
function ProfileOperations.fillStateChampionNumber(data: ProfileData, season: string, number: number): boolean
	local badges = championBadgesOf(data)
	if badges == nil or not isSeason(season) or not isBadgeNumber(number) or number < 1 or badges[season] ~= 0 then
		return false
	end
	badges[season] = number
	return true
end

-- The player's badges, newest season first (only usable entries; number 0 = on its way).
function ProfileOperations.getStateChampionBadges(data: ProfileData): { ChampionBadgeView }
	local list: { ChampionBadgeView } = {}
	for season, number in pairs(championBadgesOf(data) or {}) do
		if isSeason(season) and isBadgeNumber(number) then
			table.insert(list, { season = season, number = number })
		end
	end
	table.sort(list, function(a, b)
		return a.season > b.season
	end)
	return list
end

-- The seasons whose badge still waits for its number, oldest first (numbers go out in the order the wins came).
function ProfileOperations.pendingStateChampionSeasons(data: ProfileData): { string }
	local seasons: { string } = {}
	for season, number in pairs(championBadgesOf(data) or {}) do
		if isSeason(season) and number == 0 then
			table.insert(seasons, season)
		end
	end
	table.sort(seasons)
	return seasons
end

--[[
	LADDER POINTS (schema 16, per weight class since 17; GAME_DESIGN §35.8,
	§36.3, MeetLevelConfig.Ladder). Each class has its own ladder: points
	earned in a class count only toward State in that class. Seasons turn
	over here, when they are read: a ladder stamped with the season just
	before counts SeasonCarryShare of its points (rounded down, under the
	target) and not qualified, an older one counts 0, and addLadderPoints
	starts the new season. An unstamped ladder (season "") belongs to the
	current season, with its points (old Local wins turned into points).
	The target is FirstStateTarget until the player has qualified once
	(career.stateQualifications, version 18), then StateTarget.
]]
export type LadderView = {
	classKey: string,
	season: string,
	points: number,
	target: number,
	qualified: boolean,
}

export type LadderOutcome = "Added" | "Qualified" | "AlreadyQualified" | "Rejected"

-- The per-class ladders map, or nil when it is missing.
local function laddersOf(data: ProfileData): { [string]: PlayerProfileSchema.Ladder }?
	local career = (data :: any).career
	local ladders = if typeof(career) == "table" then career.ladders else nil
	return if typeof(ladders) == "table" then ladders else nil
end

local function isUsableLadder(ladder: any): boolean
	return typeof(ladder) == "table" and typeof(ladder.season) == "string" and typeof(ladder.qualified) == "boolean"
		and isFiniteNumber(ladder.points) and ladder.points >= 0 and ladder.points == math.floor(ladder.points)
end

-- The points the player needs to qualify for State: fewer for their first State (never qualified yet).
local function targetFor(data: ProfileData): number
	local career = (data :: any).career
	local count = if typeof(career) == "table" then career.stateQualifications else nil
	if count == 0 then
		return MeetLevelConfig.Ladder.FirstStateTarget
	end
	return MeetLevelConfig.Ladder.StateTarget
end

-- Whether a usable ladder's points belong to `season` itself (stamped with it, or not stamped yet).
local function isInSeason(ladder: any, season: string): boolean
	return ladder.season == "" or ladder.season == season
end

-- The points a usable ladder counts in `season`: its own in that season, SeasonCarryShare of them (rounded
-- down, kept under `target`) when it is stamped with the season just before, otherwise 0.
local function pointsIn(ladder: any, season: string, target: number): number
	if isInSeason(ladder, season) then
		return ladder.points
	end
	if ladder.season == MeetLevelConfig.previousSeason(season) then
		local carried = math.floor(ladder.points * MeetLevelConfig.Ladder.SeasonCarryShare)
		return math.clamp(carried, 0, math.max(target - 1, 0))
	end
	return 0
end

-- The player's ladder in `classKey` in the season holding `nowUnix` (0 points when there is none or it is
-- unusable). Read only.
function ProfileOperations.getLadder(data: ProfileData, classKey: string, nowUnix: number): LadderView
	local season = MeetLevelConfig.seasonFor(nowUnix)
	local target = targetFor(data)
	local ladders = laddersOf(data)
	local ladder: any = if ladders and typeof(classKey) == "string" then ladders[classKey] else nil
	if not isUsableLadder(ladder) then
		return { classKey = classKey, season = season, points = 0, target = target, qualified = false }
	end
	local points = pointsIn(ladder, season, target)
	-- Points at or over the target qualify even before the next add flags it (a lower first target, an old save).
	local qualified = (isInSeason(ladder, season) and ladder.qualified) or points >= target
	return { classKey = classKey, season = season, points = points, target = target, qualified = qualified }
end

--[[
	Adds ladder points earned in `classKey` at `nowUnix`, starting that
	class's ladder when it has none, and a new season first when the stored
	one is over (keeping the carried share of the season just before;
	stamping an unstamped ladder with this season, keeping its points). The
	first time a ladder reaches the target, career.stateQualifications goes
	up by 1. Returns:
		"Added"             the points count; not qualified yet
		"Qualified"         the ladder reached the target: qualified now
		"AlreadyQualified"  qualified earlier this season: nothing added
		"Rejected"          no ladders map, no build for the class, an
		                    unusable stored ladder, or not a whole number of
		                    points from 1 to 100; nothing changed
	and that class's ladder afterwards. SECURITY BOUNDARY: the caller
	(LocalMeetService) works the points out from the meet's result and
	MeetLevelConfig, and the class from the lifter's weigh-in.
]]
function ProfileOperations.addLadderPoints(data: ProfileData, classKey: string, points: number,
	nowUnix: number): (LadderOutcome, LadderView)
	local ladders = laddersOf(data)
	local safeNow = if isFiniteNumber(nowUnix) then nowUnix else 0
	if ladders == nil or typeof(classKey) ~= "string" or ProfileOperations.getBuild(data, classKey) == nil
		or not isFiniteNumber(points) or points < 1 or points > 100 or points ~= math.floor(points)
		or not isFiniteNumber(nowUnix) then
		return "Rejected", ProfileOperations.getLadder(data, classKey, safeNow)
	end
	local ladder: any = ladders[classKey]
	if ladder == nil then
		ladder = { season = "", points = 0, qualified = false }
		ladders[classKey] = ladder
	elseif not isUsableLadder(ladder) then
		return "Rejected", ProfileOperations.getLadder(data, classKey, nowUnix)
	end
	local season = MeetLevelConfig.seasonFor(nowUnix)
	local target = targetFor(data)
	if ladder.season ~= season then
		if ladder.season ~= "" then
			ladder.points = pointsIn(ladder, season, target)
			ladder.qualified = false
		end
		ladder.season = season
	end
	local outcome: LadderOutcome
	if ladder.qualified then
		outcome = "AlreadyQualified"
	else
		ladder.points += points
		ladder.qualified = ladder.points >= target
		outcome = if ladder.qualified then "Qualified" else "Added"
		local career = (data :: any).career
		if ladder.qualified then
			if isFiniteNumber(career.stateQualifications) and career.stateQualifications >= 0 then
				career.stateQualifications += 1
			else
				career.stateQualifications = 1
			end
		end
	end
	return outcome, ProfileOperations.getLadder(data, classKey, nowUnix)
end

--[[
	THE NATIONALS SPOT (schema 27; user 2026-11-17, GAME_DESIGN §36.4, MeetLevelConfig.Nationals). Per weight class:
	top-3 State placings add up (never reset by a new month) until PlacingsTarget, which earns the class's spot. The spot
	is kept until the player competes at Nationals; once the season (month) of that first Nationals meet is over, the
	class reads as 0 placings and no spot, and the next write clears it for good.
]]
export type NationalsView = {
	classKey: string,
	placings: number,
	target: number,
	qualified: boolean,
	-- The season of the first Nationals meet lifted on this spot, or "" (not competed yet).
	competedSeason: string,
}

export type NationalsOutcome = "Added" | "Qualified" | "AlreadyQualified" | "Rejected"

local function nationalsOf(data: ProfileData): { [string]: PlayerProfileSchema.NationalsSpot }?
	local career = (data :: any).career
	local spots = if typeof(career) == "table" then career.nationals else nil
	return if typeof(spots) == "table" then spots else nil
end

local function isUsableNationals(spot: any): boolean
	return typeof(spot) == "table" and typeof(spot.qualified) == "boolean" and typeof(spot.competedSeason) == "string"
		and isFiniteNumber(spot.placings) and spot.placings >= 0 and spot.placings == math.floor(spot.placings)
end

-- Whether a usable spot was used at Nationals in a season that is now over (so it resets).
local function nationalsSpent(spot: any, season: string): boolean
	return spot.competedSeason ~= "" and spot.competedSeason < season
end

-- The player's road to Nationals in `classKey` at `nowUnix` (0 placings when there is none, it is unusable, or its
-- spot was used in a season that is over). Read only.
function ProfileOperations.getNationals(data: ProfileData, classKey: string, nowUnix: number): NationalsView
	local target = MeetLevelConfig.Nationals.PlacingsTarget
	local spots = nationalsOf(data)
	local spot: any = if spots and typeof(classKey) == "string" then spots[classKey] else nil
	if not isUsableNationals(spot) or nationalsSpent(spot, MeetLevelConfig.seasonFor(nowUnix)) then
		return { classKey = classKey, placings = 0, target = target, qualified = false, competedSeason = "" }
	end
	return { classKey = classKey, placings = math.min(spot.placings, target), target = target,
		qualified = spot.qualified or spot.placings >= target, competedSeason = spot.competedSeason }
end

--[[
	Adds one top-3 State placing in `classKey` at `nowUnix` (starting the class's entry when it has none, and clearing a
	spot used in a season that is over first). The placing that reaches PlacingsTarget earns the spot. Returns:
		"Added"             counted; no spot yet
		"Qualified"         reached the target: the class's Nationals spot, now
		"AlreadyQualified"  the class already holds its spot: nothing added
		"Rejected"          no nationals map, no build for the class, or an unusable stored entry; nothing changed
	and that class's view afterwards. SECURITY BOUNDARY: the caller (LocalMeetService) decides from the State meet's
	result, its field size and MeetLevelConfig.Nationals whether the place counts, and the class from the weigh-in.
]]
function ProfileOperations.addNationalsPlacing(data: ProfileData, classKey: string, nowUnix: number)
	: (NationalsOutcome, NationalsView)
	local spots = nationalsOf(data)
	local safeNow = if isFiniteNumber(nowUnix) then nowUnix else 0
	if spots == nil or typeof(classKey) ~= "string" or ProfileOperations.getBuild(data, classKey) == nil
		or not isFiniteNumber(nowUnix) then
		return "Rejected", ProfileOperations.getNationals(data, classKey, safeNow)
	end
	local spot: any = spots[classKey]
	if spot == nil then
		spot = { placings = 0, qualified = false, competedSeason = "" }
		spots[classKey] = spot
	elseif not isUsableNationals(spot) then
		return "Rejected", ProfileOperations.getNationals(data, classKey, nowUnix)
	end
	local target = MeetLevelConfig.Nationals.PlacingsTarget
	if nationalsSpent(spot, MeetLevelConfig.seasonFor(nowUnix)) then
		spot.placings, spot.qualified, spot.competedSeason = 0, false, ""
	end
	local outcome: NationalsOutcome
	if spot.qualified or spot.placings >= target then
		spot.qualified = true
		outcome = "AlreadyQualified"
	else
		spot.placings += 1
		spot.qualified = spot.placings >= target
		outcome = if spot.qualified then "Qualified" else "Added"
	end
	return outcome, ProfileOperations.getNationals(data, classKey, nowUnix)
end

--[[
	For the Nationals meet (not built yet): the player competed at Nationals in `classKey` at `nowUnix`. Stamps the season
	of the FIRST Nationals meet on this spot; later ones that season change nothing. When that season is over the spot
	resets (getNationals, addNationalsPlacing). Returns false, changing nothing, when the class holds no spot now.
]]
function ProfileOperations.markNationalsCompeted(data: ProfileData, classKey: string, nowUnix: number): boolean
	local spots = nationalsOf(data)
	local spot: any = if spots and typeof(classKey) == "string" then spots[classKey] else nil
	if not isFiniteNumber(nowUnix) or not isUsableNationals(spot) then
		return false
	end
	local season = MeetLevelConfig.seasonFor(nowUnix)
	if nationalsSpent(spot, season) or not (spot.qualified or spot.placings >= MeetLevelConfig.Nationals.PlacingsTarget) then
		return false
	end
	spot.qualified = true
	if spot.competedSeason == "" then
		spot.competedSeason = season
	end
	return true
end

--[[
	THE WORLDS SPOT (schema 28; user 2026-11-17, GAME_DESIGN §39: "like the Nationals spot"). Per weight class: winning
	the class at Nationals earns it. It is kept until the player competes at Worlds; once the season (month) of that first
	Worlds meet is over, the class has no spot (won again at Nationals). Worlds itself is not built yet.
]]
export type WorldsView = {
	classKey: string,
	qualified: boolean,
	-- The season of the Nationals win that earned it, and of the first Worlds meet on it ("" = none yet).
	earnedSeason: string,
	competedSeason: string,
}

export type WorldsOutcome = "Earned" | "AlreadyHeld" | "Rejected"

local function worldsOf(data: ProfileData): { [string]: PlayerProfileSchema.WorldsSpot }?
	local career = (data :: any).career
	local spots = if typeof(career) == "table" then career.worlds else nil
	return if typeof(spots) == "table" then spots else nil
end

local function isSeasonText(value: any): boolean
	return typeof(value) == "string" and string.match(value, "^%d%d%d%d%-%d%d$") ~= nil
end

local function isUsableWorlds(spot: any): boolean
	return typeof(spot) == "table" and isSeasonText(spot.earnedSeason)
		and (spot.competedSeason == "" or isSeasonText(spot.competedSeason))
end

-- Whether a usable spot was used at Worlds in a season that is now over (so it is gone).
local function worldsSpent(spot: any, season: string): boolean
	return spot.competedSeason ~= "" and spot.competedSeason < season
end

-- The player's Worlds spot in `classKey` at `nowUnix` (none when there is no usable one, or it was used in a season that
-- is over). Read only.
function ProfileOperations.getWorlds(data: ProfileData, classKey: string, nowUnix: number): WorldsView
	local spots = worldsOf(data)
	local spot: any = if spots and typeof(classKey) == "string" then spots[classKey] else nil
	if not isFiniteNumber(nowUnix) or not isUsableWorlds(spot) or worldsSpent(spot, MeetLevelConfig.seasonFor(nowUnix)) then
		return { classKey = classKey, qualified = false, earnedSeason = "", competedSeason = "" }
	end
	return { classKey = classKey, qualified = true, earnedSeason = spot.earnedSeason, competedSeason = spot.competedSeason }
end

--[[
	A National Champion in `classKey` at `nowUnix`: the class's Worlds spot (a spot used in a season that is over is
	replaced). Returns:
		"Earned"       the class holds its Worlds spot now
		"AlreadyHeld"  the class already held one that is still good: nothing changed
		"Rejected"     no worlds map, no build for the class, or an unusable stored entry; nothing changed
	and that class's view afterwards. SECURITY BOUNDARY: the caller (LocalMeetService) decides from the Nationals meet's
	result that this player won the class; the class comes from the weigh-in.
]]
function ProfileOperations.addWorldsSpot(data: ProfileData, classKey: string, nowUnix: number): (WorldsOutcome, WorldsView)
	local spots = worldsOf(data)
	local safeNow = if isFiniteNumber(nowUnix) then nowUnix else 0
	if spots == nil or typeof(classKey) ~= "string" or ProfileOperations.getBuild(data, classKey) == nil
		or not isFiniteNumber(nowUnix) then
		return "Rejected", ProfileOperations.getWorlds(data, classKey, safeNow)
	end
	local season = MeetLevelConfig.seasonFor(nowUnix)
	local spot: any = spots[classKey]
	if spot ~= nil and not isUsableWorlds(spot) then
		return "Rejected", ProfileOperations.getWorlds(data, classKey, nowUnix)
	end
	if spot ~= nil and not worldsSpent(spot, season) then
		return "AlreadyHeld", ProfileOperations.getWorlds(data, classKey, nowUnix)
	end
	spots[classKey] = { earnedSeason = season, competedSeason = "" }
	return "Earned", ProfileOperations.getWorlds(data, classKey, nowUnix)
end

--[[
	For the Worlds meet (not built yet): the player competed at Worlds in `classKey` at `nowUnix`. Stamps the season of the
	FIRST Worlds meet on this spot; later ones that season change nothing. Returns false, changing nothing, when the class
	holds no spot now.
]]
function ProfileOperations.markWorldsCompeted(data: ProfileData, classKey: string, nowUnix: number): boolean
	local spots = worldsOf(data)
	local spot: any = if spots and typeof(classKey) == "string" then spots[classKey] else nil
	if not isFiniteNumber(nowUnix) or not isUsableWorlds(spot) then
		return false
	end
	local season = MeetLevelConfig.seasonFor(nowUnix)
	if worldsSpent(spot, season) then
		return false
	end
	if spot.competedSeason == "" then
		spot.competedSeason = season
	end
	return true
end

--[[
	=========================================================================
	COINS  (GAME_DESIGN.md 30.6, the money system's first build; schema 12)
	=========================================================================

	The only ways coins change: addCoins (a server-decided payout, e.g. a
	meet's prize) and spendCoins (a server-checked purchase). Both refuse
	anything that is not a whole number above 0 and within
	CoinConfig.MaxSingleChange, and a wallet whose stored values are unusable
	(the migration repairs those on load, so this is a bug guard). There is no
	setCoins: nothing replaces a balance outright.

	SECURITY BOUNDARY: these cannot know WHY coins move. Their callers are
	server systems that decided it themselves (a meet result, a Shop price
	from config); no client amount may ever reach them.
]]

export type CoinOutcome = "Added" | "Spent" | "NotEnough" | "Rejected"

local function isWholeCoins(value: any): boolean
	return isFiniteNumber(value) and value > 0 and value == math.floor(value) and value <= CoinConfig.MaxSingleChange
end

-- The wallet, or nil when it is missing or holds an unusable value.
local function walletOf(data: ProfileData): PlayerProfileSchema.Wallet?
	local wallet = (data :: any).wallet
	if typeof(wallet) ~= "table" then
		return nil
	end
	for _, field in ipairs({ "coins", "earnedTotal", "spentTotal" }) do
		local value = wallet[field]
		if not isFiniteNumber(value) or value < 0 or value ~= math.floor(value) then
			return nil
		end
	end
	return wallet
end

-- The player's coins now (0 when the wallet is unusable).
function ProfileOperations.getCoins(data: ProfileData): number
	local wallet = walletOf(data)
	return if wallet then wallet.coins else 0
end

--[[
	Adds `amount` coins. Returns "Added" and the new balance, or "Rejected"
	(a bad amount, an unusable wallet, or a balance that would pass
	CoinConfig.MaxBalance) and nil, changing nothing.
]]
function ProfileOperations.addCoins(data: ProfileData, amount: number): (CoinOutcome, number?)
	local wallet = walletOf(data)
	if wallet == nil or not isWholeCoins(amount) or wallet.coins + amount > CoinConfig.MaxBalance then
		return "Rejected", nil
	end
	wallet.coins += amount
	wallet.earnedTotal += amount
	return "Added", wallet.coins
end

--[[
	Spends `amount` coins. Returns "Spent" and the new balance; "NotEnough"
	and the unchanged balance when the player cannot afford it; or "Rejected"
	and nil for a bad amount or an unusable wallet. Never goes below 0.
]]
function ProfileOperations.spendCoins(data: ProfileData, amount: number): (CoinOutcome, number?)
	local wallet = walletOf(data)
	if wallet == nil or not isWholeCoins(amount) then
		return "Rejected", nil
	end
	if wallet.coins < amount then
		return "NotEnough", wallet.coins
	end
	wallet.coins -= amount
	wallet.spentTotal += amount
	return "Spent", wallet.coins
end

--[[
	=========================================================================
	THE SHOP INVENTORY  (GAME_DESIGN.md 30.6, the money system's step 4;
	schema 13)
	=========================================================================

	NOTHING CALLS purchaseItem IN THE GAME ANY MORE: gear is unlocked through crates only
	(user 2026-11-06, GAME_DESIGN §35.12; openCrate below). What players bought stays owned.
	It stays for the save tests in Dev. It was the ONLY way an item became owned, and took the coins
	in the same step, so a purchase can never give the item without the coins
	going or the coins going without the item. SECURITY BOUNDARY: it trusts
	its caller (ShopService) for the price, which comes from ShopConfig on the
	server, never from a client; it checks everything else itself.
]]

export type PurchaseOutcome = "Bought" | "AlreadyOwned" | "NotEnough" | "Rejected"

local MAX_ITEM_ID_LENGTH = 64

local function isItemId(value: any): boolean
	return typeof(value) == "string" and #value > 0 and #value <= MAX_ITEM_ID_LENGTH
end

-- The owned map, or nil when it is missing.
local function ownedOf(data: ProfileData): { [string]: boolean }?
	local inventory = (data :: any).inventory
	local owned = if typeof(inventory) == "table" then inventory.owned else nil
	return if typeof(owned) == "table" then owned else nil
end

function ProfileOperations.ownsItem(data: ProfileData, itemId: string): boolean
	local owned = ownedOf(data)
	return owned ~= nil and isItemId(itemId) and owned[itemId] == true
end

-- Every owned item id, sorted (for screens).
function ProfileOperations.getOwnedItems(data: ProfileData): { string }
	local list: { string } = {}
	for itemId, value in pairs(ownedOf(data) or {}) do
		if value == true and isItemId(itemId) then
			table.insert(list, itemId)
		end
	end
	table.sort(list)
	return list
end

--[[
	Buys `itemId` for `price` coins. Returns "Bought" and the new balance;
	"AlreadyOwned" or "NotEnough" and the unchanged balance; or "Rejected" and
	nil (a bad id or price, an unusable wallet or inventory). Only "Bought"
	changes anything, and it changes both the coins and the inventory.
]]
function ProfileOperations.purchaseItem(data: ProfileData, itemId: string, price: number): (PurchaseOutcome, number?)
	local wallet = walletOf(data)
	local owned = ownedOf(data)
	if wallet == nil or owned == nil or not isItemId(itemId) or not isWholeCoins(price) then
		return "Rejected", nil
	end
	if owned[itemId] == true then
		return "AlreadyOwned", wallet.coins
	end
	if wallet.coins < price then
		return "NotEnough", wallet.coins
	end
	wallet.coins -= price
	wallet.spentTotal += price
	owned[itemId] = true
	return "Bought", wallet.coins
end

--[[
	=========================================================================
	THE GEAR BEING WORN  (GAME_DESIGN.md 30.6, the money system's step 5;
	schema 14)
	=========================================================================

	setWorn is the ONLY way something is put on or taken off. It refuses an
	item the player does not own. SECURITY BOUNDARY: it trusts its caller
	(GearService) that `slot` is a real slot and the item belongs in it (both
	from WornGearConfig and ShopConfig on the server); it checks the rest.
]]

export type WearOutcome = "Worn" | "TakenOff" | "NotOwned" | "Rejected"

local MAX_SLOT_LENGTH = 32

-- The wearing map, or nil when it is missing.
local function wearingOf(data: ProfileData): { [string]: string }?
	local inventory = (data :: any).inventory
	local wearing = if typeof(inventory) == "table" then inventory.wearing else nil
	return if typeof(wearing) == "table" then wearing else nil
end

-- A copy of what is worn: slot -> the item id whose look shows (only owned items, or a worn stat piece's look).
function ProfileOperations.getWorn(data: ProfileData): { [string]: string }
	local copy: { [string]: string } = {}
	for slot, itemId in pairs(wearingOf(data) or {}) do
		if typeof(slot) == "string" and typeof(itemId) == "string" and ProfileOperations.ownsItem(data, itemId) then
			copy[slot] = itemId
		end
	end
	local inventory = (data :: any).inventory
	local pieces = if typeof(inventory) == "table" then inventory.pieces else nil
	local wearingPieces = if typeof(inventory) == "table" then inventory.wearingPieces else nil
	if typeof(pieces) == "table" and typeof(wearingPieces) == "table" then
		for slot, pieceId in pairs(wearingPieces) do
			local piece = pieces[pieceId]
			if typeof(piece) == "table" and piece.slot == slot and typeof(piece.look) == "string" then
				copy[slot] = piece.look
			end
		end
	end
	return copy
end

--[[
	Puts `itemId` on in `slot`, or takes the slot's item off when itemId is nil.
	"Worn" / "TakenOff" change the save; "NotOwned" and "Rejected" (a bad slot
	or id, a missing inventory) change nothing.
]]
function ProfileOperations.setWorn(data: ProfileData, slot: string, itemId: string?): WearOutcome
	local wearing = wearingOf(data)
	if wearing == nil or typeof(slot) ~= "string" or #slot == 0 or #slot > MAX_SLOT_LENGTH then
		return "Rejected"
	end
	-- A slot holds one thing: anything here takes a worn stat piece off.
	local inventory = (data :: any).inventory
	local wearingPieces = if typeof(inventory) == "table" then inventory.wearingPieces else nil
	if itemId == nil then
		wearing[slot] = nil
		if typeof(wearingPieces) == "table" then
			wearingPieces[slot] = nil
		end
		return "TakenOff"
	end
	if not isItemId(itemId) then
		return "Rejected"
	end
	if not ProfileOperations.ownsItem(data, itemId) then
		return "NotOwned"
	end
	wearing[slot] = itemId
	if typeof(wearingPieces) == "table" then
		wearingPieces[slot] = nil
	end
	return "Worn"
end

--[[
	=========================================================================
	GEAR WITH STATS  (GAME_DESIGN.md §35.12; schema 19)
	=========================================================================

	openCrate makes a piece and takes the coins in the same step; grantPiece makes one
	for free, for a rare suit a meet dropped or the admin panel gave. scrapPiece is the ONLY
	way one goes, and it pays in the same step.
	SECURITY BOUNDARY: they trust their caller (ShopService, GearService) for the
	price, the roll and the scrap value, all made on the server from GearStatsConfig,
	never from a client; they check everything else themselves.
]]

export type CrateOutcome = "Opened" | "NotEnough" | "Full" | "Rejected"
export type ScrapOutcome = "Scrapped" | "IsWorn" | "NotOwned" | "Rejected"

-- The pieces map, the worn map and the next number, or nil when any is unusable.
local function piecesOf(data: ProfileData): (any?, any?)
	local inventory = (data :: any).inventory
	if typeof(inventory) ~= "table" or typeof(inventory.pieces) ~= "table" or typeof(inventory.wearingPieces) ~= "table"
		or not isFiniteNumber(inventory.nextPieceId) or inventory.nextPieceId < 1 then
		return nil, nil
	end
	return inventory, inventory.pieces
end

-- A copy of the player's stat pieces: id -> piece.
function ProfileOperations.getPieces(data: ProfileData): { [string]: PlayerProfileSchema.StatPiece }
	local copy: { [string]: PlayerProfileSchema.StatPiece } = {}
	local _, pieces = piecesOf(data)
	for id, piece in pairs(pieces or {}) do
		if typeof(id) == "string" and typeof(piece) == "table" then
			copy[id] = { slot = piece.slot, rarity = piece.rarity, look = piece.look }
		end
	end
	return copy
end

-- A copy of which piece is worn in each slot: slot -> piece id.
function ProfileOperations.getWornPieces(data: ProfileData): { [string]: string }
	local copy: { [string]: string } = {}
	local inventory, pieces = piecesOf(data)
	if inventory == nil then
		return copy
	end
	for slot, pieceId in pairs(inventory.wearingPieces) do
		if typeof(slot) == "string" and typeof(pieceId) == "string" and (pieces :: any)[pieceId] then
			copy[slot] = pieceId
		end
	end
	return copy
end

--[[
	Takes `price` coins and adds `piece` as a new piece, together. Returns "Opened", the
	new piece's id and the balance; "NotEnough" or "Full" with the unchanged balance; or
	"Rejected" (an unusable wallet or inventory, a bad price or piece). Only "Opened"
	changes anything.
]]
function ProfileOperations.openCrate(data: ProfileData, price: number, piece: PlayerProfileSchema.StatPiece, maxPieces: number)
	: (CrateOutcome, string?, number?)
	local wallet = walletOf(data)
	local inventory, pieces = piecesOf(data)
	if wallet == nil or inventory == nil or not isWholeCoins(price) or typeof(piece) ~= "table"
		or not isItemId(piece.slot) or not isItemId(piece.rarity) or not isItemId(piece.look) then
		return "Rejected", nil, nil
	end
	if wallet.coins < price then
		return "NotEnough", nil, wallet.coins
	end
	local count = 0
	for _ in pairs(pieces) do
		count += 1
	end
	if count >= maxPieces then
		return "Full", nil, wallet.coins
	end
	local id = tostring(inventory.nextPieceId)
	wallet.coins -= price
	wallet.spentTotal += price
	inventory.nextPieceId += 1
	pieces[id] = { slot = piece.slot, rarity = piece.rarity, look = piece.look }
	return "Opened", id, wallet.coins
end

--[[
	Adds `piece` for free and returns its id, or nil for an unusable inventory or a bad piece. Never refused for being full: a
	rare suit is never lost. SERVER-ONLY: the caller chose the piece; no client may.
]]
function ProfileOperations.grantPiece(data: ProfileData, piece: PlayerProfileSchema.StatPiece): string?
	local inventory, pieces = piecesOf(data)
	if inventory == nil or typeof(piece) ~= "table" or not isItemId(piece.slot) or not isItemId(piece.rarity) or not isItemId(piece.look) then
		return nil
	end
	local id = tostring(inventory.nextPieceId)
	inventory.nextPieceId += 1
	pieces[id] = { slot = piece.slot, rarity = piece.rarity, look = piece.look }
	return id
end

export type SuitTrialOutcome = "Started" | "NotOwned" | "Passed" | "Waiting" | "Rejected"

-- The tests table, made if a save somehow lacks it.
local function suitTestsOf(inventory: any): { [string]: any }
	if typeof(inventory.suitTests) ~= "table" then
		inventory.suitTests = {}
	end
	return inventory.suitTests
end

-- A copy of the coach's tests: suit id -> passed, and when it can next be tried.
function ProfileOperations.getSuitTests(data: ProfileData): { [string]: { passed: boolean?, nextTryAt: number? } }
	local copy: { [string]: { passed: boolean?, nextTryAt: number? } } = {}
	local inventory = (data :: any).inventory
	if typeof(inventory) == "table" and typeof(inventory.suitTests) == "table" then
		for suitId, test in pairs(inventory.suitTests) do
			if typeof(test) == "table" then
				copy[suitId] = { passed = test.passed == true, nextTryAt = if typeof(test.nextTryAt) == "number" then test.nextTryAt else nil }
			end
		end
	end
	return copy
end

--[[
	Starts a test: puts the piece on for it, remembering what was worn, and starts the wait, so walking out can't dodge a fail.
	SERVER-ONLY: `now` and `waitSeconds` are the server's. Only "Started" changes anything.
]]
function ProfileOperations.startSuitTrial(data: ProfileData, suitId: string, pieceId: string, now: number, waitSeconds: number)
	: (SuitTrialOutcome, number?)
	local inventory, pieces = piecesOf(data)
	local wearing = wearingOf(data)
	if inventory == nil or wearing == nil or not isItemId(suitId) or not isItemId(pieceId) or inventory.suitTrial ~= nil then
		return "Rejected", nil
	end
	local piece = pieces[pieceId]
	if typeof(piece) ~= "table" or piece.rarity ~= suitId then
		return "NotOwned", nil
	end
	local tests = suitTestsOf(inventory)
	local test = tests[suitId]
	if typeof(test) == "table" and test.passed == true then
		return "Passed", nil
	end
	if typeof(test) == "table" and typeof(test.nextTryAt) == "number" and test.nextTryAt > now then
		return "Waiting", test.nextTryAt - now
	end
	tests[suitId] = { nextTryAt = now + waitSeconds }
	inventory.suitTrial = { pieceId = pieceId, slot = piece.slot, before = inventory.wearingPieces[piece.slot], beforeItem = wearing[piece.slot] }
	wearing[piece.slot] = nil
	inventory.wearingPieces[piece.slot] = pieceId
	return "Started", nil
end

--[[
	Ends a running test. Passed: the suit is unlocked for good and stays on. Otherwise what was worn goes back on. Safe with no test
	running, and run on every load, so a server going down mid-test leaves nothing on loan.
]]
function ProfileOperations.endSuitTrial(data: ProfileData, passed: boolean)
	local inventory, pieces = piecesOf(data)
	local wearing = wearingOf(data)
	local trial = if inventory then inventory.suitTrial else nil
	if inventory == nil or wearing == nil or typeof(trial) ~= "table" then
		return
	end
	inventory.suitTrial = nil
	local piece = pieces[trial.pieceId]
	if passed and typeof(piece) == "table" then
		suitTestsOf(inventory)[piece.rarity] = { passed = true }
		return
	end
	if inventory.wearingPieces[trial.slot] == trial.pieceId then
		inventory.wearingPieces[trial.slot] = nil
	end
	if typeof(trial.before) == "string" and pieces[trial.before] then
		inventory.wearingPieces[trial.slot] = trial.before
	elseif typeof(trial.beforeItem) == "string" then
		wearing[trial.slot] = trial.beforeItem
	end
end

-- Forgets every test, passed or waiting, and takes any suit off. For the admin panel, to test all of this again.
function ProfileOperations.resetSuitTests(data: ProfileData, isSuit: (string) -> boolean)
	local inventory, pieces = piecesOf(data)
	if inventory == nil then
		return
	end
	inventory.suitTests = {}
	inventory.suitTrial = nil
	local off = {}
	for slot, pieceId in pairs(inventory.wearingPieces) do
		local piece = pieces[pieceId]
		if typeof(piece) == "table" and isSuit(piece.rarity) then
			table.insert(off, slot)
		end
	end
	for _, slot in ipairs(off) do
		inventory.wearingPieces[slot] = nil
	end
end

--[[
	Removes a piece and pays `value` coins, together. A worn piece is refused, so nothing
	gets scrapped by accident. Returns the outcome and the balance; only "Scrapped"
	changes anything.
]]
function ProfileOperations.scrapPiece(data: ProfileData, pieceId: string, value: number): (ScrapOutcome, number?)
	local wallet = walletOf(data)
	local inventory, pieces = piecesOf(data)
	if wallet == nil or inventory == nil or not isItemId(pieceId) or not isWholeCoins(value)
		or wallet.coins + value > CoinConfig.MaxBalance then
		return "Rejected", nil
	end
	local piece = pieces[pieceId]
	if piece == nil then
		return "NotOwned", wallet.coins
	end
	if inventory.wearingPieces[piece.slot] == pieceId then
		return "IsWorn", wallet.coins
	end
	pieces[pieceId] = nil
	wallet.coins += value
	wallet.earnedTotal += value
	return "Scrapped", wallet.coins
end

-- Puts a piece on in its own slot, taking off whatever is there. "Worn", "NotOwned" or "Rejected".
function ProfileOperations.setWornPiece(data: ProfileData, pieceId: string): WearOutcome
	local inventory, pieces = piecesOf(data)
	local wearing = wearingOf(data)
	if inventory == nil or wearing == nil or not isItemId(pieceId) then
		return "Rejected"
	end
	local piece = pieces[pieceId]
	if piece == nil then
		return "NotOwned"
	end
	wearing[piece.slot] = nil
	inventory.wearingPieces[piece.slot] = pieceId
	return "Worn"
end

-- (TRAINING ENERGY was retired in schema version 8, GAME_DESIGN 29.8, and the COMPETITION BUDGET in version 10, 29.9.)

--[[
	=========================================================================
	GYM-STATION TRAINING PROGRESSION  (GAME_DESIGN.md section 34, checkpoint 5B.5)
	=========================================================================

	The ONLY operation that awards Competition Number. It debits the daily
	training accounting and awards the CN that debit paid for, together.

	Section 34.12, decision A: the account-wide 4.00 EV daily allowance is
	training's only throttle. The meet CN allowance is not touched: it limits
	meet raises only (section 33.3b).
]]

--[[
	What a training update did.

		"Awarded"            EV was earned: CN rose and the accounting was written
		"NoProgress"         valid, but nothing was earned -- cap already spent,
		                     zero or negative elapsed time. CN is unchanged; the
		                     accounting is still written, so a day rollover and
		                     the audit stamp land
		"ClockWentBackward"  a stored day key is later than the interval's start.
		                     NOTHING is written, and nothing is granted
		"Rejected"           the request or the stored data was unusable.
		                     NOTHING is written. `rejectionReason` says why
]]
export type TrainingOutcome = "Awarded" | "NoProgress" | "ClockWentBackward" | "Rejected"

export type TrainingRejectionReason =
	"InvalidLift"
	| "InvalidTime"
	| "InvalidElapsed"
	| "InvalidBodyweight"
	-- No configured Progression Reference for this lift and class, 120+ included. Decision C.
	| "UnsupportedClass"
	| "InvalidCompetitionNumber"
	| "InvalidAccounting"
	| "StalePlan"
	| "InvariantViolated"
	| "AwardRefused"

export type TrainingResult = {
	outcome: TrainingOutcome,
	rejectionReason: TrainingRejectionReason?,

	lift: string,
	weightClassLabel: string?,

	-- EV the allowance granted this update. Already clamped to the daily cap.
	earnedEV: number,
	creditedHours: number,
	uncreditedSeconds: number,
	capReached: boolean,
	daysTouched: number,

	competitionNumberBefore: number?,
	competitionNumberAfter: number?,
	deltaCN: number,
	hillMultiplier: number?,
}

local TRAINING = ProgressionConfig.DailyTraining

--[[
	Tolerance for the post-plan invariant checks only. These compare sums of
	floats the plan produced; they never decide an amount.
]]
local INVARIANT_EPSILON = 1e-9

-- A result in which nothing was earned and nothing was written.
local function unchangedTrainingResult(
	lift: any,
	outcome: TrainingOutcome,
	reason: TrainingRejectionReason?
): TrainingResult
	return {
		outcome = outcome,
		rejectionReason = reason,

		lift = if typeof(lift) == "string" then lift else tostring(lift),
		weightClassLabel = nil,

		earnedEV = 0,
		creditedHours = 0,
		uncreditedSeconds = 0,
		capReached = false,
		daysTouched = 0,

		competitionNumberBefore = nil,
		competitionNumberAfter = nil,
		deltaCN = 0,
		hillMultiplier = nil,
	}
end

local function trainingRejection(lift: any, reason: TrainingRejectionReason): TrainingResult
	return unchangedTrainingResult(lift, "Rejected", reason)
end

local function isUsableAccountingNumber(value: any): boolean
	return isFiniteNumber(value) and value >= 0
end

--[[
	Every field the plan reads or writes, checked here so a corrupt record is a
	clean "InvalidAccounting" rather than an assert inside TrainingAllowance.
	migrations[4] repairs all of these on load, so failing here means something
	wrote garbage mid-session.
]]
local function isUsableAllowanceRecord(record: any): boolean
	return typeof(record) == "table"
		and isUsableAccountingNumber(record.spentToday)
		and typeof(record.dayKey) == "string"
		and isUsableAccountingNumber(record.lastUpdatedUnix)
end

local function isUsableTrainingTimeRecord(record: any): boolean
	if typeof(record) ~= "table" then
		return false
	end

	if typeof(record.dayKey) ~= "string" or not isUsableAccountingNumber(record.lastUpdatedUnix) then
		return false
	end

	for _, lift in ipairs(ProgressionConfig.Lifts) do
		if not isUsableAccountingNumber(record[lift]) then
			return false
		end
	end

	return true
end

local function writeAllowanceInPlace(target: PlayerProfileSchema.DailyAllowance, source: TrainingAllowance.DailyAllowance)
	target.spentToday = source.spentToday
	target.dayKey = source.dayKey
	target.lastUpdatedUnix = source.lastUpdatedUnix
end

local function writeTrainingTimeInPlace(
	target: PlayerProfileSchema.TrainingTimeToday,
	source: TrainingAllowance.TrainingTimeToday
)
	for _, lift in ipairs(ProgressionConfig.Lifts) do
		(target :: any)[lift] = (source :: any)[lift]
	end

	target.dayKey = source.dayKey
	target.lastUpdatedUnix = source.lastUpdatedUnix
end

--[[
	Applies `elapsedSeconds` of gym-station training on `lift` to a profile:
	plans the daily allowance, derives the earned EV and the Competition Number
	it buys, and writes both together.

		data            the live profile
		lift            "Squat", "Bench" or "Deadlift"
		nowUnix         SERVER time at the end of the interval
		elapsedSeconds  ACTIVE, SERVER-OBSERVED station time. Never derived from
		                lastUpdatedUnix -- a profile's stamp after a day offline
		                is a day old, and crediting it would be offline
		                progression (section 34.2). See TrainingAllowance.

	Returns a TrainingResult. Never throws on bad input or bad stored data.

	=========================================================================
	ATOMIC: ALL OF IT OR NONE OF IT
	=========================================================================

	The function runs in three phases, and nothing is written until the third.

	  1. VALIDATE. Lift, clock, elapsed time, bodyweight, weight class, the
	     incoming CN and all three accounting records. Any failure returns
	     "Rejected" with the profile untouched.

	  2. PLAN. The allowance plan and the CN award are both computed against
	     the profile AS IT IS NOW, on copies. Then the plan is checked against
	     the live records (matchesBasis) and against the reward/debit invariant.
	     Any failure returns with the profile untouched.

	  3. COMMIT. The CN delta first, through applyCompetitionNumberDelta, which
	     writes nothing when it refuses. Then the three accounting records, as
	     plain assignments into tables already validated in phase 1, which
	     cannot fail.

	NO YIELD ANYWHERE. Nothing here waits, calls a DataStore or touches an
	Instance, so from the first read to the last write no other Lua code can
	run. That is what makes the basis check meaningful: the plan cannot go
	stale between being checked and being written.

	ONE PROFILE TABLE. The debit and the award land in the same profile.Data,
	which ProfileStore saves as one unit. A crash before the next save loses
	both together; it can never keep one without the other.
]]
function ProfileOperations.applyTrainingProgression(
	data: ProfileData,
	lift: string,
	nowUnix: number,
	elapsedSeconds: number
): TrainingResult
	--------------------------------------------------------------------------
	-- PHASE 1: VALIDATE. Nothing below writes until phase 3.
	--------------------------------------------------------------------------

	if not ProgressionConfig.isLift(lift) then
		return trainingRejection(lift, "InvalidLift")
	end

	if not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return trainingRejection(lift, "InvalidTime")
	end

	--[[
		NEGATIVE ELAPSED TIME IS ALLOWED THROUGH and earns nothing: the
		allowance reader clamps it to zero, the same treatment it gives a
		backward clock step. NaN, either infinity, a non-number and anything
		over a day are refused.
	]]
	if not isFiniteNumber(elapsedSeconds) or elapsedSeconds > TrainingAllowance.MAX_ELAPSED_SECONDS then
		return trainingRejection(lift, "InvalidElapsed")
	end

	local bodyweight = (data :: any).bodyweight
	local bodyweightKg = if typeof(bodyweight) == "table" then bodyweight.currentKg else nil

	if not isFiniteNumber(bodyweightKg) or bodyweightKg <= 0 then
		return trainingRejection(lift, "InvalidBodyweight")
	end

	local weightClassLabel = WeightClass.resolve(bodyweightKg).label

	local competitionNumberBefore = ProfileOperations.getCompetitionNumber(data, lift)

	if competitionNumberBefore == nil or competitionNumberBefore <= 0 then
		return trainingRejection(lift, "InvalidCompetitionNumber")
	end

	--[[
		A ZERO-EV DRY RUN of the award, which validates the class and the CN
		exactly the way the real award will. Done BEFORE planning so that an
		unsupported class rejects the whole update -- decision C -- even on a
		tick that would have earned nothing. A class with no configured
		reference must not spend allowance it can never turn into CN.
	]]
	local _, dryRunRejection = CompetitionNumberReward.calculateTrainingAward(
		lift,
		weightClassLabel,
		competitionNumberBefore,
		0
	)

	if dryRunRejection ~= nil then
		if dryRunRejection == "InvalidCompetitionNumber" then
			return trainingRejection(lift, "InvalidCompetitionNumber")
		end

		return trainingRejection(lift, "UnsupportedClass")
	end

	if
		not isUsableAllowanceRecord(data.cnAllowance)
		or not isUsableAllowanceRecord(data.techniqueAllowance)
		or not isUsableTrainingTimeRecord(data.trainingTimeToday)
	then
		return trainingRejection(lift, "InvalidAccounting")
	end

	--------------------------------------------------------------------------
	-- PHASE 2: PLAN, against the profile as it is now. Still nothing written.
	--------------------------------------------------------------------------

	local state: TrainingAllowance.State = {
		cnAllowance = data.cnAllowance,
		techniqueAllowance = data.techniqueAllowance,
		trainingTimeToday = data.trainingTimeToday,
	}

	--[[
		planTraining is pure and never touches `state`; pcall turns any assert it
		still raises into a clean rejection. pcall does not yield.
	]]
	local planned, planOrError = pcall(TrainingAllowance.planTraining, state, lift, nowUnix, elapsedSeconds)

	if not planned then
		return trainingRejection(lift, "InvalidAccounting")
	end

	local plan: TrainingAllowance.Plan = planOrError

	if plan.clockWentBackward then
		-- Fail closed: the stored counters stand, nothing is granted or written.
		local result = unchangedTrainingResult(lift, "ClockWentBackward", nil)

		result.weightClassLabel = weightClassLabel
		result.competitionNumberBefore = competitionNumberBefore
		result.competitionNumberAfter = competitionNumberBefore

		return result
	end

	--[[
		THE STALE-PLAN GUARD. The plan was computed from these very records a
		moment ago with nothing in between, so this cannot fail today. It stays
		because it is the check that keeps holding if someone later puts a yield
		between planning and committing. A mismatch is refused, never patched.
	]]
	if not TrainingAllowance.matchesBasis(state, plan) then
		return trainingRejection(lift, "StalePlan")
	end

	--[[
		THE REWARD/DEBIT INVARIANT. The EV the CN award is paid for must be the
		EV the allowance was debited by, and the allowance must stay in bounds.
	]]
	local earnedEV = plan.earnedEV
	local nextCN = plan.nextState.cnAllowance
	local nextHours = plan.nextState.trainingTimeToday

	if not isUsableAccountingNumber(earnedEV) then
		return trainingRejection(lift, "InvariantViolated")
	end

	if not isUsableAccountingNumber(nextCN.spentToday) or nextCN.spentToday > TRAINING.DailyCapEV + INVARIANT_EPSILON then
		return trainingRejection(lift, "InvariantViolated")
	end

	local expectedSpent = if nextCN.dayKey == data.cnAllowance.dayKey
		then data.cnAllowance.spentToday + earnedEV
		else nil

	if expectedSpent ~= nil and math.abs(nextCN.spentToday - expectedSpent) > INVARIANT_EPSILON then
		-- Same day: the debit must equal the EV earned, exactly up to float noise.
		return trainingRejection(lift, "InvariantViolated")
	end

	if expectedSpent == nil and nextCN.spentToday > earnedEV + INVARIANT_EPSILON then
		-- Rolled over: today's spend can only be what this update earned after midnight.
		return trainingRejection(lift, "InvariantViolated")
	end

	for _, liftName in ipairs(ProgressionConfig.Lifts) do
		if not isUsableAccountingNumber((nextHours :: any)[liftName]) then
			return trainingRejection(lift, "InvariantViolated")
		end
	end

	local award: CompetitionNumberReward.TrainingAward? = nil

	if earnedEV > 0 then
		--[[
			GAIN BOOSTS (GAME_DESIGN §40.7, steaks): the award is paid for the boosted EV, so the same training buys more
			strength, while the daily allowance above is debited by the plain earnedEV, so a boost never lets anyone
			train past the daily limit. The formula still shrinks the award near the world-record level.
		]]
		local boostedEV = earnedEV * (1 + GainBoosts.trainingBonus((data :: any).boosts, nowUnix))
		local calculated, _ = CompetitionNumberReward.calculateTrainingAward(
			lift,
			weightClassLabel,
			competitionNumberBefore,
			boostedEV
		)

		if calculated == nil then
			return trainingRejection(lift, "AwardRefused")
		end

		-- Positive EV must buy positive CN, or EV would be spent for nothing.
		if not (calculated.deltaCN > 0) then
			return trainingRejection(lift, "InvariantViolated")
		end

		award = calculated
	end

	--------------------------------------------------------------------------
	-- PHASE 3: COMMIT. No yields, and nothing after the CN write can fail.
	--------------------------------------------------------------------------

	local competitionNumberAfter = competitionNumberBefore

	if award ~= nil then
		-- Writes nothing when it refuses, so a refusal here leaves the profile untouched.
		local applied, value = ProfileOperations.applyCompetitionNumberDelta(data, lift, award.deltaCN)

		if not applied or value == nil then
			return trainingRejection(lift, "AwardRefused")
		end

		competitionNumberAfter = value
	end

	writeAllowanceInPlace(data.cnAllowance, plan.nextState.cnAllowance)
	writeAllowanceInPlace(data.techniqueAllowance, plan.nextState.techniqueAllowance)
	writeTrainingTimeInPlace(data.trainingTimeToday, plan.nextState.trainingTimeToday)

	return {
		outcome = if award ~= nil then "Awarded" else "NoProgress",
		rejectionReason = nil,

		lift = lift,
		weightClassLabel = weightClassLabel,

		earnedEV = earnedEV,
		creditedHours = plan.creditedHours,
		uncreditedSeconds = plan.uncreditedSeconds,
		capReached = plan.capReached,
		daysTouched = plan.daysTouched,

		competitionNumberBefore = competitionNumberBefore,
		competitionNumberAfter = competitionNumberAfter,
		deltaCN = if award ~= nil then award.deltaCN else 0,
		hillMultiplier = if award ~= nil then award.hillMultiplier else nil,
	}
end

--[[
	=========================================================================
	TECHNIQUE TRAINING -- checkpoint 5B.7
	=========================================================================

	The ONLY operation that awards rack technique points. It raises the raw
	technique stats of the selected lift -- the primary and its secondary
	together -- and NOTHING ELSE.

	UNTOUCHED, ALWAYS: Competition Number, the CN allowance, the per-lift CN
	hours, Competition Scale, the legacy `techniqueAllowance` record (5B.7
	removed the technique cap; the record is unused legacy data). (PullStrength,
	never trainable, was removed in schema version 7, section 34.6.)

	NO WEIGHT-CLASS CHECK. Technique needs no Progression Reference, so a 120+
	lifter, refused by the CN award, may train technique.

	NO CLOCK. Technique has no daily allowance and no day boundary, so an
	interval across UTC midnight is simply credited. `elapsedSeconds` is still
	the rack's own server-observed measurement, never derived from a stamp.
]]

--[[
	What a technique update did.

		"Awarded"     raw points were added to the selected stats
		"NoProgress"  valid, but the interval was zero or negative. Nothing written
		"Rejected"    the request or the stored stats were unusable. NOTHING is
		              written. `rejectionReason` says why
]]
export type TechniqueOutcome = "Awarded" | "NoProgress" | "Rejected"

export type TechniqueRejectionReason =
	"InvalidLift"
	| "InvalidPrimary"
	| "InvalidElapsed"
	-- The technique table, or one of the stats this award would raise, is missing,
	-- not a number, NaN, infinite or negative. Not repaired: refused.
	| "InvalidTechnique"
	| "InvariantViolated"

export type TechniqueResult = {
	outcome: TechniqueOutcome,
	rejectionReason: TechniqueRejectionReason?,

	lift: string,
	primary: string,

	-- Total raw points awarded across the split. 0 unless "Awarded".
	totalRaw: number,
	-- Raw points per stat, primary first. Empty unless "Awarded".
	gains: { TechniqueTraining.Gain },
	-- The raw value of each awarded stat after the write.
	after: { [string]: number },
}

local function techniqueRejection(lift: any, primary: any, reason: TechniqueRejectionReason): TechniqueResult
	return {
		outcome = "Rejected",
		rejectionReason = reason,
		lift = if typeof(lift) == "string" then lift else tostring(lift),
		primary = if typeof(primary) == "string" then primary else tostring(primary),
		totalRaw = 0,
		gains = {},
		after = {},
	}
end

--[[
	Relative tolerance for the "parts sum to the total" check. The secondary is
	computed as total - primary, so the two differ from the total only by float
	rounding; anything larger is a real defect.
]]
local TECHNIQUE_SUM_EPSILON = 1e-9

--[[
	Applies `elapsedSeconds` of rack technique training to a profile.

		data            the live profile
		lift            "Squat", "Bench" or "Deadlift"
		primary         a stat ProgressionConfig.TrainableTechnique lists for that lift
		elapsedSeconds  ACTIVE, SERVER-OBSERVED rack time

	Returns a TechniqueResult. Never throws on bad input or bad stored data.

	ATOMIC, the same three phases as applyTrainingProgression:

	  1. VALIDATE the lift, the primary, the interval and every stat this award
	     would raise. Any failure returns "Rejected" with the profile untouched.
	  2. COMPUTE the raw points and the new values on locals. Every new value
	     must be finite and not below the old one, and the parts must add up to
	     the total, or the update is refused -- nothing has been written yet,
	     so an overflow to infinity can never reach the profile.
	  3. COMMIT with plain assignments into stats already validated, which
	     cannot fail. Primary and secondary land together in the same
	     profile.Data, which ProfileStore saves as one unit.

	NO YIELD ANYWHERE.
]]
function ProfileOperations.applyTechniqueTraining(
	data: ProfileData,
	lift: string,
	primary: string,
	elapsedSeconds: number,
	nowUnix: number?
): TechniqueResult
	--------------------------------------------------------------------------
	-- PHASE 1: VALIDATE. Nothing below writes until phase 3.
	--------------------------------------------------------------------------

	if not ProgressionConfig.isLift(lift) then
		return techniqueRejection(lift, primary, "InvalidLift")
	end

	if not TechniqueTraining.isValidPrimary(lift, primary) then
		return techniqueRejection(lift, primary, "InvalidPrimary")
	end

	--[[
		Same bounds as the CN award: NaN, either infinity, a non-number and
		anything over a day are refused. A negative interval earns nothing.
	]]
	if not isFiniteNumber(elapsedSeconds) or elapsedSeconds > TrainingAllowance.MAX_ELAPSED_SECONDS then
		return techniqueRejection(lift, primary, "InvalidElapsed")
	end

	local technique = (data :: any).technique
	if typeof(technique) ~= "table" then
		return techniqueRejection(lift, primary, "InvalidTechnique")
	end

	local split = TechniqueTraining.split(lift, primary)
	if split == nil then
		return techniqueRejection(lift, primary, "InvalidPrimary")
	end

	for _, entry in ipairs(split) do
		local current = technique[entry.stat]
		if not isFiniteNumber(current) or current < 0 then
			return techniqueRejection(lift, primary, "InvalidTechnique")
		end
	end

	--------------------------------------------------------------------------
	-- PHASE 2: COMPUTE, on locals only.
	--------------------------------------------------------------------------

	-- Worn gear speeds up technique training (§35.12), and only technique: the CN award above never reads it.
	local gearSpeed = GearStats.trainingSpeed(GearStats.wornRarities((data :: any).inventory), lift)
	-- Gain boosts (§40.7, steaks) add to it (boosts add together). `nowUnix` is the server clock, only for whether a
	-- boost is still running; without it no boost applies.
	local boost = if nowUnix ~= nil then GainBoosts.trainingBonus((data :: any).boosts, nowUnix) else 0
	local totalRaw = TechniqueTraining.rawPointsFor(elapsedSeconds, gearSpeed + boost)

	if not isFiniteNumber(totalRaw) or totalRaw < 0 then
		return techniqueRejection(lift, primary, "InvariantViolated")
	end

	if totalRaw == 0 then
		return {
			outcome = "NoProgress",
			rejectionReason = nil,
			lift = lift,
			primary = primary,
			totalRaw = 0,
			gains = {},
			after = {},
		}
	end

	local gains = TechniqueTraining.allocate(lift, primary, totalRaw)
	if gains == nil then
		return techniqueRejection(lift, primary, "InvariantViolated")
	end

	local sum = 0
	local after: { [string]: number } = {}

	for _, gain in ipairs(gains) do
		if not isFiniteNumber(gain.raw) or gain.raw < 0 then
			return techniqueRejection(lift, primary, "InvariantViolated")
		end

		local before = technique[gain.stat] :: number
		local value = before + gain.raw

		-- Overflow to infinity, or a value that went down, never reaches the profile.
		if not isFiniteNumber(value) or value < before then
			return techniqueRejection(lift, primary, "InvariantViolated")
		end

		sum += gain.raw
		after[gain.stat] = value
	end

	if math.abs(sum - totalRaw) > TECHNIQUE_SUM_EPSILON * math.max(1, totalRaw) then
		return techniqueRejection(lift, primary, "InvariantViolated")
	end

	--------------------------------------------------------------------------
	-- PHASE 3: COMMIT. No yields, and nothing here can fail.
	--------------------------------------------------------------------------

	for stat, value in pairs(after) do
		technique[stat] = value
	end

	return {
		outcome = "Awarded",
		rejectionReason = nil,
		lift = lift,
		primary = primary,
		totalRaw = totalRaw,
		gains = gains,
		after = after,
	}
end

--[[
	=========================================================================
	BODYWEIGHT  (gaining and losing weight, GAME_DESIGN §38.3 "The design",
	user 2026-11-18)
	=========================================================================

	The lifter's goal is `bodyweight.targetKg` (in the save since version 1):
	MAINTAIN = the weight they have; a goal class = that class's limit exactly
	(BodyweightConfig.goalKgFor; the open class has none, only a safety stop).
	Reaching the goal makes it MAINTAIN by itself: the target then IS the
	weight they have (user 2026-11-19). `bodyweight.currentKg` moves toward it
	only through applyBodyweightChange, which only PlayerDataService's training
	award calls, with the EV the training allowance itself granted. The class
	is never stored (it is the class of currentKg, derived on every read);
	each class entered gets its build through PlayerProfileSchema.ensureBuild
	(§29.11: first entry copies the closest lighter build, a return restores).
	No yield anywhere.
]]

export type WeightGoalOutcome = "Set" | "NeedsConfirm" | "Rejected"

local function usableBodyweight(data: ProfileData): any?
	local bodyweight = (data :: any).bodyweight
	if typeof(bodyweight) ~= "table" or not isFiniteNumber(bodyweight.currentKg) or bodyweight.currentKg <= 0 then
		return nil
	end
	return bodyweight
end

--[[
	Sets the lifter's goal: BodyweightConfig.Maintain (hold the weight they have) or a weight class label. A goal that
	would take them out of the class they are in while that class holds a Nationals or Worlds spot needs `confirmed`
	(the spot stays in its class, GAME_DESIGN §38.3); without it nothing changes and "NeedsConfirm" says why. Returns
	the outcome, a line for the player, and the goal weight now saved (nil when rejected).
]]
function ProfileOperations.setWeightGoal(data: ProfileData, goal: any, confirmed: boolean, nowUnix: number)
	: (WeightGoalOutcome, string, number?)
	local bodyweight = usableBodyweight(data)
	if bodyweight == nil then
		return "Rejected", "Your bodyweight hasn't loaded yet.", nil
	end
	local current = bodyweight.currentKg
	local here = PlayerProfileSchema.classKeyFor(current)
	if goal == BodyweightConfig.Maintain then
		bodyweight.targetKg = current
		return "Set", string.format("Maintaining %s.", BodyweightConfig.text(current)), current
	end
	local goalKg = BodyweightConfig.goalKgFor(goal)
	if goalKg == nil or here == nil then
		return "Rejected", "That isn't a weight class.", nil
	end
	if goal ~= here and not confirmed and isFiniteNumber(nowUnix) then
		local held = {}
		if ProfileOperations.getNationals(data, here, nowUnix).qualified then
			table.insert(held, "Nationals")
		end
		if ProfileOperations.getWorlds(data, here, nowUnix).qualified then
			table.insert(held, "Worlds")
		end
		if #held > 0 then
			return "NeedsConfirm", string.format(
				"You hold a %s spot in the %s class. It stays there: to use it you'll have to weigh in at %s again.",
				table.concat(held, " and a "), here, here), nil
		end
	end
	-- Already at the goal (e.g. exactly 74 kg and picking 74): that is MAINTAIN.
	if math.abs(goalKg - current) < 0.005 then
		bodyweight.targetKg = current
		return "Set", string.format("You're at the %s limit already: maintaining %s.", goal :: string,
			BodyweightConfig.text(current)), current
	end
	bodyweight.targetKg = goalKg
	if goalKg > current and PlayerProfileSchema.classKeyFor(goalKg) == WeightClassConfig.Classes[#WeightClassConfig.Classes].label then
		return "Set", string.format("Bulking into the %s class as you train, until you pick MAINTAIN.", goal :: string), goalKg
	end
	local verb = if goalKg > current then "Bulking" else "Cutting"
	return "Set", string.format("%s to %s (the %s class) as you train. Then your goal is MAINTAIN.", verb,
		BodyweightConfig.text(goalKg), goal :: string), goalKg
end

export type BodyweightChange = {
	beforeKg: number,
	afterKg: number,
	targetKg: number,
	classBefore: string,
	classAfter: string,
}

--[[
	Moves the bodyweight toward the goal for `earnedEV` of Competition Number training (BodyweightConfig.KgPerEV per EV,
	times `speed`, 1 outside a Studio test), never past the goal. Returns what changed, or nil when nothing did (no EV,
	at the goal already, or no usable bodyweight). SERVER-ONLY: the only caller is PlayerDataService's training award,
	with the EV the allowance granted.
]]
function ProfileOperations.applyBodyweightChange(data: ProfileData, earnedEV: number, speed: number?): BodyweightChange?
	local bodyweight = usableBodyweight(data)
	if bodyweight == nil or not isFiniteNumber(earnedEV) or earnedEV <= 0 then
		return nil
	end
	local current = bodyweight.currentKg
	local target = bodyweight.targetKg
	if not isFiniteNumber(target) or target <= 0 then
		return nil
	end
	-- Never past the safety stop or under the starting weight (a target saved by hand, the admin panel).
	target = math.clamp(target, math.min(current, StartingValuesConfig.BodyweightKg),
		math.max(current, BodyweightConfig.OpenClassCeilingKg))
	if current == target then
		return nil
	end
	local step = earnedEV * BodyweightConfig.KgPerEV * (if isFiniteNumber(speed) and (speed :: number) > 0 then speed :: number else 1)
	local bulking = target > current
	local after = if bulking then math.min(target, current + step) else math.max(target, current - step)
	-- Never on the hair between a class limit and limit + 0.01 (e.g. 74.004): it would show as "74.00 kg" for an 83 kg
	-- lifter (user 2026-11-19, the message "74kg ... 83kg lifter"). A bulk steps on to limit + 0.01, a cut back to the
	-- limit: at most 0.01 kg.
	for _, class in ipairs(WeightClassConfig.Classes) do
		local limit = class.maximumBodyweight
		if limit and after > limit and after < limit + 0.01 then
			after = if bulking then limit + 0.01 else limit
			break
		end
	end
	after = if bulking then math.min(after, target) else math.max(after, target)
	local classBefore = PlayerProfileSchema.classKeyFor(current)
	local classAfter = PlayerProfileSchema.classKeyFor(after)
	if classBefore == nil or classAfter == nil then
		return nil
	end
	bodyweight.currentKg = after
	-- Every class passed through gets its build (§29.11), lightest first, so each copies the one below it.
	local fromIndex, toIndex = nil, nil
	for index, class in ipairs(WeightClassConfig.Classes) do
		if class.label == classBefore then
			fromIndex = index
		end
		if class.label == classAfter then
			toIndex = index
		end
	end
	if fromIndex and toIndex then
		for index = math.min(fromIndex, toIndex), math.max(fromIndex, toIndex) do
			PlayerProfileSchema.ensureBuild(data, WeightClassConfig.Classes[index].label)
		end
	end
	return { beforeKg = current, afterKg = after, targetKg = target, classBefore = classBefore, classAfter = classAfter }
end

--[[
	=========================================================================
	DAILY QUESTS  (GAME_DESIGN §40.6, user 2026-11-19)
	=========================================================================

	One quest per lift from its coach: QuestConfig.GoodLiftsNeeded good lifts of
	that lift in today's meets. A finished quest pays strength directly
	(§40.1): QuestConfig.RewardTrainingDays full training days of that lift,
	through the training formula (CompetitionNumberReward), into the build of
	the class the meet weighed in. Today is DayKey's UTC day; a stored day that
	isn't today reads (and is rewritten) as a fresh, empty set. No yield.
]]

-- `taken`: the player asked that coach for it today. `resetIn`: seconds until today's quests reset (the UTC day).
export type QuestLiftView = { goodLifts: number, needed: number, done: boolean, taken: boolean, resetIn: number }
export type QuestProgress = {
	lift: string,
	added: number,
	goodLifts: number,
	needed: number,
	-- True only for the save that finished it.
	finished: boolean,
	cnBefore: number?,
	cnAfter: number?,
}

local QUEST_LIFTS = { "Squat", "Bench", "Deadlift" }

local function usableQuests(data: ProfileData): any?
	local quests = (data :: any).dailyQuests
	if typeof(quests) ~= "table" or typeof(quests.goodLifts) ~= "table" or typeof(quests.done) ~= "table" then
		return nil
	end
	return quests
end

-- A stored day that isn't `today` becomes a fresh, empty one (writes).
local function rollQuestDay(quests: any, today: string)
	if quests.dayKey == today then
		return
	end
	quests.dayKey = today
	if typeof(quests.taken) ~= "table" then
		quests.taken = {}
	end
	for _, lift in ipairs(QUEST_LIFTS) do
		quests.goodLifts[lift] = 0
		quests.done[lift] = false
		quests.taken[lift] = false
	end
end

-- Today's quests for the STATS screen and the coach's lines. Reads only.
function ProfileOperations.getDailyQuests(data: ProfileData, nowUnix: number): { [string]: QuestLiftView }
	local quests = usableQuests(data)
	local today = if isFiniteNumber(nowUnix) and nowUnix >= 0 then DayKey.fromUnix(nowUnix) else nil
	local fresh = quests == nil or today == nil or quests.dayKey ~= today
	local taken = if not fresh and typeof(quests.taken) == "table" then quests.taken else {}
	local resetIn = if isFiniteNumber(nowUnix) and nowUnix >= 0 then 86400 - math.floor(nowUnix) % 86400 else 86400
	local view: { [string]: QuestLiftView } = {}
	for _, lift in ipairs(QUEST_LIFTS) do
		local count = if fresh then 0 else quests.goodLifts[lift]
		view[lift] = {
			goodLifts = if isFiniteNumber(count) and count >= 0 then count else 0,
			needed = QuestConfig.GoodLiftsNeeded,
			done = not fresh and quests.done[lift] == true,
			taken = taken[lift] == true,
			resetIn = resetIn,
		}
	end
	return view
end

--[[
	The player asked `lift`'s coach for today's quest: it shows on their quest tracker from now until the daily reset.
	Changes nothing else (progress counts whether or not it was taken). Returns whether `lift` is a quest lift.
]]
function ProfileOperations.takeQuest(data: ProfileData, lift: string, nowUnix: number): boolean
	local quests = usableQuests(data)
	if quests == nil or not table.find(QUEST_LIFTS, lift) or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return false
	end
	rollQuestDay(quests, DayKey.fromUnix(nowUnix))
	if typeof(quests.taken) ~= "table" then
		quests.taken = {}
	end
	quests.taken[lift] = true
	return true
end

--[[
	Adds a meet's good lifts (`goodByLift`, whole numbers per lift) to today's quests and pays every quest this
	finishes: strength into the `classKey` build (the meet's weigh-in class). SERVER-ONLY: the only caller is a meet's
	save, with good lifts the server judged. Returns one entry per lift with progress (empty when nothing counted).
	A class with no Progression Reference (120+) finishes the quest but gains no strength, as training gives none.
]]
function ProfileOperations.addQuestGoodLifts(data: ProfileData, classKey: string, goodByLift: { [string]: number },
	nowUnix: number): { QuestProgress }
	local progress: { QuestProgress } = {}
	local quests = usableQuests(data)
	if quests == nil or not isFiniteNumber(nowUnix) or nowUnix < 0 or typeof(goodByLift) ~= "table" then
		return progress
	end
	rollQuestDay(quests, DayKey.fromUnix(nowUnix))
	local build = ProfileOperations.getBuild(data, classKey)
	for _, lift in ipairs(QUEST_LIFTS) do
		local added = goodByLift[lift]
		if not isFiniteNumber(added) or added < 1 or quests.done[lift] == true then
			continue
		end
		added = math.floor(added)
		local before = if isFiniteNumber(quests.goodLifts[lift]) then quests.goodLifts[lift] else 0
		local now = math.min(before + added, QuestConfig.GoodLiftsNeeded)
		quests.goodLifts[lift] = now
		local entry: QuestProgress = { lift = lift, added = now - before, goodLifts = now,
			needed = QuestConfig.GoodLiftsNeeded, finished = false }
		if now >= QuestConfig.GoodLiftsNeeded then
			quests.done[lift] = true
			entry.finished = true
			local cn = build and (build.competitionNumber :: any)[lift]
			if isFiniteNumber(cn) and cn > 0 then
				local ev = QuestConfig.RewardTrainingDays * ProgressionConfig.DailyTraining.DailyCapEV / #QUEST_LIFTS
				local award = CompetitionNumberReward.calculateTrainingAward(lift, classKey, cn, ev)
				if award and isFiniteNumber(award.deltaCN) and award.deltaCN > 0 then
					(build :: any).competitionNumber[lift] = award.competitionNumberAfter
					entry.cnBefore = cn
					entry.cnAfter = award.competitionNumberAfter
				end
			end
		end
		table.insert(progress, entry)
	end
	return progress
end

--[[
	=========================================================================
	THE KITCHEN  (GAME_DESIGN §40.7, user 2026-11-19)
	=========================================================================

	One cooker per player. startCook pays for the steaks (or, version 34, meet
	meals: one cook at a time, so the cooker holds one kind) and starts the cook
	in one write; the cook finishes by the server clock (also while the player
	is away or offline). eatSteak empties a finished cooker into its boost:
	steaks give KitchenConfig.boostPercent on TRAINING gains, meals the same on
	MEET gains, each for BoostHours, replacing a boost of the same kind already
	running. Prices, times and the boost come from KitchenConfig, never from a
	client. No yield.
]]

export type CookOutcome = "Started" | "NotEnough" | "Busy" | "Rejected"
export type EatOutcome = "Eaten" | "NotReady" | "Empty" | "Rejected"
export type KitchenView = {
	-- The cooker: how many in it (0 = empty), what ("Steak" or "Meal"), and seconds until ready (0 = ready to eat).
	steaks: number,
	kind: string,
	readyIn: number,
	cookSeconds: number,
	-- The steak boost running now (percent 0 = none), its seconds left and the meal's size.
	boostPercent: number,
	boostLeft: number,
	boostSteaks: number,
	-- The meet meal boost running now (percent 0 = none), its seconds left and its size.
	mealPercent: number,
	mealLeft: number,
	mealCount: number,
	-- Whether they have watched the chef scene once (it can be skipped after that).
	sceneSeen: boolean,
	-- The cook's length in hours (the cook timer): how long its boost will last.
	cookHours: number,
}

-- What the cooker holds ("Meal" only when stored so; anything else reads as steaks).
local function cookKind(kitchen: any): string
	return if kitchen.kind == "Meal" then "Meal" else "Steak"
end

local function usableKitchen(data: ProfileData): (any?, any?)
	local kitchen, boosts = (data :: any).kitchen, (data :: any).boosts
	if typeof(kitchen) ~= "table" or typeof(boosts) ~= "table" or typeof(boosts.steak) ~= "table" then
		return nil, nil
	end
	for _, field in ipairs({ "steaks", "startedAt", "readyAt" }) do
		if not isFiniteNumber(kitchen[field]) or kitchen[field] < 0 then
			return nil, nil
		end
	end
	return kitchen, boosts
end

-- The cooker and the steak boost, for the Kitchen menu and the boost timer. Reads only.
function ProfileOperations.getKitchen(data: ProfileData, nowUnix: number): KitchenView
	local kitchen, boosts = usableKitchen(data)
	local view: KitchenView = { steaks = 0, kind = "Steak", readyIn = 0, cookSeconds = 0, boostPercent = 0, boostLeft = 0,
		boostSteaks = 0, mealPercent = 0, mealLeft = 0, mealCount = 0, sceneSeen = false, cookHours = 0 }
	if kitchen == nil or not isFiniteNumber(nowUnix) then
		return view
	end
	view.sceneSeen = kitchen.sceneSeen == true
	if kitchen.steaks >= 1 then
		view.steaks = kitchen.steaks
		view.kind = cookKind(kitchen)
		view.readyIn = math.max(0, kitchen.readyAt - nowUnix)
		view.cookSeconds = math.max(0, kitchen.readyAt - kitchen.startedAt)
		view.cookHours = if KitchenConfig.isCookHours(kitchen.hours) then kitchen.hours else KitchenConfig.BoostHours
	end
	local steak = GainBoosts.active(boosts.steak, nowUnix)
	if steak then
		view.boostPercent = steak.percent
		view.boostLeft = steak.endsAt - nowUnix
		view.boostSteaks = if isFiniteNumber(boosts.steak.steaks) then boosts.steak.steaks else 0
	end
	local meal = GainBoosts.active(boosts.meal, nowUnix)
	if meal then
		view.mealPercent = meal.percent
		view.mealLeft = meal.endsAt - nowUnix
		view.mealCount = if isFiniteNumber(boosts.meal.meals) then boosts.meal.meals else 0
	end
	return view
end

--[[
	Notes that the player has watched the chef scene to the end once (after that it can be skipped). Only ever sets it
	true; returns whether the record could be written. Nothing else changes, so a client asking for it early gains
	nothing but a skip button on a cut-scene.
]]
function ProfileOperations.markChefSceneSeen(data: ProfileData): boolean
	local kitchen = usableKitchen(data)
	if kitchen == nil then
		return false
	end
	kitchen.sceneSeen = true
	return true
end

--[[
	Pays for `steaks` of `kind` ("Steak", or "Meal" for meet meals; nil = steaks) and puts them in the cooker. "Busy"
	when something is already in it (cooking or waiting to be eaten; one cook at a time, either kind), "NotEnough" (with
	the balance) when the player can't afford it, "Rejected" for a bad count or kind or broken data. Nothing is written
	unless it returns "Started".
]]
function ProfileOperations.startCook(data: ProfileData, steaks: number, nowUnix: number, kind: string?, hours: number?)
	: (CookOutcome, number?)
	local kitchen = usableKitchen(data)
	local wallet = walletOf(data)
	local cooking = kind or "Steak"
	-- The cook timer (§41.5): one of the offered lengths; nil = 24 hours.
	local length = hours or KitchenConfig.BoostHours
	if kitchen == nil or wallet == nil or not KitchenConfig.isSteakCount(steaks) or not KitchenConfig.isKind(cooking)
		or not KitchenConfig.isCookHours(length) or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return "Rejected", nil
	end
	if cooking == "Meal" and typeof((data :: any).boosts.meal) ~= "table" then
		return "Rejected", nil
	end
	if kitchen.steaks >= 1 then
		return "Busy", wallet.coins
	end
	local price = KitchenConfig.cost(steaks, cooking, length)
	if not isWholeCoins(price) then
		return "Rejected", nil
	end
	if wallet.coins < price then
		return "NotEnough", wallet.coins
	end
	wallet.coins -= price
	wallet.spentTotal += price
	kitchen.steaks = steaks
	kitchen.kind = cooking
	kitchen.hours = length
	kitchen.startedAt = math.floor(nowUnix)
	kitchen.readyAt = kitchen.startedAt + KitchenConfig.cookSeconds(steaks, cooking, length)
	return "Started", wallet.coins
end

--[[
	Eats a finished cook: empties the cooker and sets its boost (steaks: the training boost; meals: the meet boost) for
	the cook's hours (the cook timer, §41.5). A boost of the same kind and the same percent still running gets the hours
	ADDED, never past BoostHours (24) from now; any other boost of that kind is replaced. Returns the boost's percent and
	the kind with "Eaten". Nothing is written otherwise.
]]
--[[
	Sets a food's boost on `boosts` (steaks: training; meals: meets) for `hours`: the same kind and percent still running
	gets the hours added, never past BoostHours from now; anything else of that kind is replaced. Returns the percent,
	or nil (nothing written) for a bad food.
]]
local function applyFood(boosts: any, kind: string, count: number, hours: number, nowUnix: number): number?
	local percent = KitchenConfig.boostPercent(count, kind)
	if not isFiniteNumber(percent) or percent <= 0 or not KitchenConfig.isCookHours(hours) then
		return nil
	end
	if kind == "Meal" and typeof(boosts.meal) ~= "table" then
		return nil
	end
	local now = math.floor(nowUnix)
	local entry = if kind == "Meal" then boosts.meal else boosts.steak
	local running = GainBoosts.active(entry, nowUnix)
	local from = if running and math.abs(running.percent - percent) < 1e-6 then running.endsAt else now
	local endsAt = math.min(from + math.floor(hours * 3600), now + KitchenConfig.BoostHours * 3600)
	entry.percent = percent
	entry.endsAt = endsAt
	if kind == "Meal" then
		entry.meals = count
	else
		entry.steaks = count
	end
	return percent
end

function ProfileOperations.eatSteak(data: ProfileData, nowUnix: number): (EatOutcome, number?, string?)
	local kitchen, boosts = usableKitchen(data)
	if kitchen == nil or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return "Rejected", nil, nil
	end
	if kitchen.steaks < 1 then
		return "Empty", nil, nil
	end
	if nowUnix < kitchen.readyAt then
		return "NotReady", nil, nil
	end
	local count, kind = kitchen.steaks, cookKind(kitchen)
	local percent = KitchenConfig.boostPercent(count, kind)
	if not isFiniteNumber(percent) or percent <= 0 then
		return "Rejected", nil, nil
	end
	local hours = if KitchenConfig.isCookHours(kitchen.hours) then kitchen.hours else KitchenConfig.BoostHours
	local now = math.floor(nowUnix)
	local entry = if kind == "Meal" then boosts.meal else boosts.steak
	local running = GainBoosts.active(entry, nowUnix)
	local from = if running and math.abs(running.percent - percent) < 1e-6 then running.endsAt else now
	local endsAt = math.min(from + math.floor(hours * 3600), now + KitchenConfig.BoostHours * 3600)
	if kind == "Meal" then
		if typeof(boosts.meal) ~= "table" then
			return "Rejected", nil, nil
		end
		boosts.meal.percent = percent
		boosts.meal.endsAt = endsAt
		boosts.meal.meals = count
	else
		boosts.steak.percent = percent
		boosts.steak.endsAt = endsAt
		boosts.steak.steaks = count
	end
	kitchen.steaks = 0
	kitchen.kind = "Steak"
	kitchen.hours = KitchenConfig.BoostHours
	kitchen.startedAt = 0
	kitchen.readyAt = 0
	return "Eaten", percent, kind
end

--[[
	=========================================================================
	LUCK  (GAME_DESIGN §40.7, user 2026-11-21: the mafia boss cow's wheel)
	=========================================================================

	One multiplier at a time on every rollable, from the cow's wheel; a new spin replaces it, better or worse. One
	free spin a UTC day; spins won from the cow's games wait in `spins`; each game costs one of the day's tries and
	never anything else. Every number is LuckConfig's and every clock the server's; the wedge a spin lands on is
	rolled by the server (LuckService) and only checked here. No yield.
]]
export type LuckView = {
	-- The multiplier in force (1 = none) and its seconds left.
	multiplier: number,
	secondsLeft: number,
	-- Whether today's free spin is still unused, and spins won and waiting.
	freeSpin: boolean,
	spins: number,
	-- The cow's games: tries left today.
	triesLeft: number,
}
export type SpinOutcome = "Spun" | "NoSpins" | "Rejected"
export type GameOutcome = "Started" | "NoTries" | "Rejected"

local function usableLuck(data: ProfileData): any?
	local luck = (data :: any).luck
	if typeof(luck) ~= "table" or not isFiniteNumber(luck.multiplier) or luck.multiplier <= 0 then
		return nil
	end
	for _, field in ipairs({ "endsAt", "spins", "gameTries" }) do
		if not isFiniteNumber(luck[field]) or luck[field] < 0 then
			return nil
		end
	end
	if typeof(luck.freeDayKey) ~= "string" or typeof(luck.gameDayKey) ~= "string" then
		return nil
	end
	return luck
end

-- The multiplier in force at `nowUnix` (1 when none, ended or unusable). Reads only.
function ProfileOperations.luckMultiplier(data: ProfileData, nowUnix: number): number
	local luck = usableLuck(data)
	local wheel = 1
	if luck ~= nil and isFiniteNumber(nowUnix) and luck.endsAt > nowUnix and LuckConfig.isMultiplier(luck.multiplier) then
		wheel = luck.multiplier
	end
	-- A new rank name's boost doubles the luck in force, never above its cap (GAME_DESIGN §41, RankConfig.LuckBoost).
	local ranks = (data :: any).ranks
	if typeof(ranks) == "table" and isFiniteNumber(ranks.luckBoostEndsAt) and isFiniteNumber(nowUnix)
		and ranks.luckBoostEndsAt > nowUnix then
		return math.min(wheel * RankConfig.LuckBoost.Factor, RankConfig.LuckBoost.Cap)
	end
	return wheel
end

-- Luck for the wheel's screen and the luck chip. Reads only.
function ProfileOperations.getLuck(data: ProfileData, nowUnix: number): LuckView
	local view: LuckView = { multiplier = 1, secondsLeft = 0, freeSpin = false, spins = 0, triesLeft = 0 }
	local luck = usableLuck(data)
	if luck == nil or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return view
	end
	local today = DayKey.fromUnix(nowUnix)
	view.multiplier = ProfileOperations.luckMultiplier(data, nowUnix)
	view.secondsLeft = if view.multiplier ~= 1 or luck.endsAt > nowUnix then math.max(0, luck.endsAt - nowUnix) else 0
	view.freeSpin = luck.freeDayKey ~= today
	view.spins = math.floor(luck.spins)
	local used = if luck.gameDayKey == today then luck.gameTries else 0
	view.triesLeft = math.max(0, LuckConfig.GameTriesPerDay - math.floor(used))
	return view
end

--[[
	Spins the wheel onto wedge `wedge` and its band's result `multiplier` (both rolled by the server): uses today's
	free spin if it is unused, else one won spin. Sets the multiplier (replacing the one in force) for its hours
	(LuckConfig.hoursFor: 24, or 2 for bad luck).
	Returns "Spun" with the multiplier and whether the free spin paid for it. Nothing is written otherwise, nor when
	the multiplier isn't one of that wedge's band.
]]
function ProfileOperations.spinLuckWheel(data: ProfileData, wedge: number, multiplier: number, nowUnix: number): (SpinOutcome, number?, boolean?)
	local luck = usableLuck(data)
	local prize = LuckConfig.wedgePrize(wedge)
	if luck == nil or prize == nil or not isFiniteNumber(nowUnix) or nowUnix < 0 or not LuckConfig.inBand(prize, multiplier) then
		return "Rejected", nil, nil
	end
	local today = DayKey.fromUnix(nowUnix)
	local free = luck.freeDayKey ~= today
	if not free and luck.spins < 1 then
		return "NoSpins", nil, nil
	end
	if free then
		luck.freeDayKey = today
	else
		luck.spins = math.floor(luck.spins) - 1
	end
	luck.multiplier = multiplier
	-- (bad luck, below 1x, lasts BadLuckHours; anything else LuckHours)
	luck.endsAt = math.floor(nowUnix) + LuckConfig.hoursFor(multiplier) * 3600
	return "Spun", multiplier, free
end

-- Starts one of the cow's games: uses one of today's tries. Nothing is written unless it returns "Started".
function ProfileOperations.startCowGame(data: ProfileData, nowUnix: number): GameOutcome
	local luck = usableLuck(data)
	if luck == nil or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return "Rejected"
	end
	local today = DayKey.fromUnix(nowUnix)
	local used = if luck.gameDayKey == today then math.floor(luck.gameTries) else 0
	if used >= LuckConfig.GameTriesPerDay then
		return "NoTries"
	end
	luck.gameDayKey = today
	luck.gameTries = used + 1
	return "Started"
end

--[[
	Adds `count` spins to the ones waiting (a game won, or a bought spin), up to LuckConfig.MaxBankedSpins when
	`capped` (a won spin; a bought one is never lost to the cap). Returns how many are waiting now, or nil.
]]
function ProfileOperations.addLuckSpins(data: ProfileData, count: number, capped: boolean): number?
	local luck = usableLuck(data)
	if luck == nil or not isFiniteNumber(count) or count < 1 or count ~= math.floor(count) or count > 100 then
		return nil
	end
	local total = math.floor(luck.spins) + count
	if capped then
		total = math.max(math.floor(luck.spins), math.min(total, LuckConfig.MaxBankedSpins))
	end
	luck.spins = total
	return total
end

--[[
	=========================================================================
	ADMIN  (the admin panel's PLAYER STATS page, user 2026-11-08: "fully control
	anyones stats" for playtesting)
	=========================================================================

	The one exception to "no setter": each of these REPLACES a value, because
	that is what testing needs. They still name exactly what they change, from
	AdminConfig.StatFields, and clamp it to AdminConfig.StatLimits.

	SECURITY BOUNDARY: their only caller is AdminService, which checks the
	caller is on its server-only admin list on every call.
]]

-- Sets one AdminConfig stat field to `value` (clamped). Returns whether it worked and what was set.
function ProfileOperations.adminSetStat(data: ProfileData, fieldId: string, value: number, nowUnix: number): (boolean, string)
	local field = AdminConfig.statField(fieldId)
	local limits = field and AdminConfig.StatLimits[field.kind]
	if field == nil or limits == nil then
		return false, "That isn't a stat."
	end
	if not isFiniteNumber(value) then
		return false, "Type a number."
	end
	local kind = field.kind
	local set = math.clamp(value, limits.min, limits.max)
	set = if kind == "Ladder" or kind == "Nationals" then math.floor(set + 0.5) else math.floor(set * 10 + 0.5) / 10
	local profile = data :: any
	if kind == "Bodyweight" then
		local classKey = PlayerProfileSchema.classKeyFor(set)
		if typeof(profile.bodyweight) ~= "table" or classKey == nil then
			return false, "The save has no usable bodyweight."
		end
		profile.bodyweight.currentKg = set
		profile.bodyweight.targetKg = set
		PlayerProfileSchema.ensureBuild(data, classKey)
		return true, string.format("Bodyweight %s kg: the %s class.", tostring(set), classKey)
	elseif kind == "Technique" then
		if typeof(profile.technique) ~= "table" or field.stat == nil then
			return false, "The save has no technique stats."
		end
		profile.technique[field.stat] = set
		return true, string.format("%s set to %s.", field.label, tostring(set))
	end
	local classKey = ProfileOperations.getActiveClassKey(data)
	local build = ProfileOperations.getActiveBuild(data)
	if classKey == nil or build == nil then
		return false, "The save has no build for its class."
	end
	if kind == "CompetitionNumber" and field.lift then
		(build.competitionNumber :: any)[field.lift] = set
		return true, string.format("%s %s kg in %s.", field.label, tostring(set), classKey)
	elseif kind == "Scale" and field.lift then
		(build.competitionScale :: any)[field.lift] = set
		return true, string.format("%s %s kg in %s.", field.label, tostring(set), classKey)
	elseif kind == "Ladder" then
		local ladders = laddersOf(data)
		if ladders == nil then
			return false, "The save has no ladders."
		end
		ladders[classKey] = { season = MeetLevelConfig.seasonFor(nowUnix), points = set, qualified = set >= targetFor(data) }
		local view = ProfileOperations.getLadder(data, classKey, nowUnix)
		return true, string.format("Ladder %d/%d in %s%s.", view.points, view.target, classKey,
			if view.qualified then ": qualified for State" else "")
	elseif kind == "Nationals" then
		local spots = nationalsOf(data)
		if spots == nil then
			return false, "The save has no Nationals placings."
		end
		local target = MeetLevelConfig.Nationals.PlacingsTarget
		spots[classKey] = { placings = set, qualified = set >= target, competedSeason = "" }
		return true, string.format("Nationals placings %d/%d in %s%s.", set, target, classKey,
			if set >= target then ": Nationals spot" else "")
	end
	return false, "That isn't a stat."
end

-- Qualifies the player for State in their current class this season (their ladder at the target).
function ProfileOperations.adminQualifyForState(data: ProfileData, nowUnix: number): (boolean, string)
	local classKey = ProfileOperations.getActiveClassKey(data)
	local ladders = laddersOf(data)
	if classKey == nil or ladders == nil then
		return false, "The save has no class or no ladders."
	end
	local target = targetFor(data)
	ladders[classKey] = { season = MeetLevelConfig.seasonFor(nowUnix), points = target, qualified = true }
	return true, string.format("Qualified for State in %s this season.", classKey)
end

-- Gives back today's training: the CN and technique allowances and the training time on every lift.
function ProfileOperations.adminRefillDaily(data: ProfileData): (boolean, string)
	local profile = data :: any
	for _, name in ipairs({ "cnAllowance", "techniqueAllowance" }) do
		local allowance = profile[name]
		if typeof(allowance) == "table" and isFiniteNumber(allowance.spentToday) then
			allowance.spentToday = 0
		end
	end
	local time = profile.trainingTimeToday
	if typeof(time) == "table" then
		for _, lift in ipairs(ProgressionConfig.Lifts) do
			if isFiniteNumber(time[lift]) then
				time[lift] = 0
			end
		end
	end
	return true, "Today's training limits are full again."
end

--[[
	ADMIN PANEL: SKIP ALL COOLDOWNS (user 2026-11-23: "a skip cooldown for everything like food, and for the future if there
	is a cooldown make it where i can skip anything"). Ends every wait in the save at once: the cook is ready now, today's
	training limits refill, every build's meet allowance refills to full, the cow's free daily spin and today's game tries
	come back, today's coach quests start over, and a rare suit test can be tried again now. Returns the names of what it
	skipped. EVERY NEW COOLDOWN ADDS ITS OWN LINE HERE (memory "admin-skip-cooldowns"); waits kept outside the save (the
	Mock Meet's) are skipped by their service from AdminService. ADMIN ONLY: AdminService checks the caller.
]]
function ProfileOperations.adminSkipCooldowns(data: ProfileData, nowUnix: number): { string }
	local profile = data :: any
	local skipped: { string } = {}
	if not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return skipped
	end
	-- The Kitchen: whatever is cooking is ready now.
	local kitchen = profile.kitchen
	if typeof(kitchen) == "table" and isFiniteNumber(kitchen.steaks) and kitchen.steaks >= 1 and isFiniteNumber(kitchen.readyAt)
		and kitchen.readyAt > nowUnix then
		kitchen.readyAt = math.floor(nowUnix)
		table.insert(skipped, "cooking")
	end
	-- Today's training limits.
	ProfileOperations.adminRefillDaily(data)
	table.insert(skipped, "training limits")
	-- Every build's meet allowance, full.
	local refilled = false
	if typeof(profile.builds) == "table" then
		for _, build in pairs(profile.builds) do
			local allowance = if typeof(build) == "table" then build.meetAllowance else nil
			if typeof(allowance) == "table" then
				for _, lift in ipairs(ProgressionConfig.Lifts) do
					local resource = allowance[lift]
					if typeof(resource) == "table" then
						resource.amount = ProgressionConfig.MeetCnAllowance.MaxDays
						resource.lastUpdatedUnix = math.floor(nowUnix)
						refilled = true
					end
				end
			end
		end
	end
	if refilled then
		table.insert(skipped, "meet allowance")
	end
	-- The cow's wheel: the free daily spin and today's game tries.
	local luck = profile.luck
	if typeof(luck) == "table" then
		luck.freeDayKey = ""
		luck.gameDayKey = ""
		luck.gameTries = 0
		table.insert(skipped, "free spin and cow game tries")
	end
	-- Today's coach quests start over (a fresh day).
	local quests = profile.dailyQuests
	if typeof(quests) == "table" then
		quests.dayKey = DayKey.UNSTAMPED
		for _, field in ipairs({ "goodLifts", "done", "taken" }) do
			if typeof(quests[field]) == "table" then
				for _, lift in ipairs(ProgressionConfig.Lifts) do
					quests[field][lift] = if field == "goodLifts" then 0 else false
				end
			end
		end
		table.insert(skipped, "daily quests")
	end
	-- Rare suit tests: no wait before the next try.
	local inventory = profile.inventory
	if typeof(inventory) == "table" and typeof(inventory.suitTests) == "table" then
		for _, test in pairs(inventory.suitTests) do
			if typeof(test) == "table" and test.passed ~= true then
				test.nextTryAt = nil
			end
		end
		table.insert(skipped, "suit test waits")
	end
	return skipped
end

--[[
	WALK-OUTS, CELEBRATIONS AND FAIL STYLES: COLLECTIONS WITH ATTEMPT SLOTS (schema version 24, LoadoutConfig; user
	2026-11-12: "I want people to be able to collect these walk outs, celebrations, and lift fails ... 3 slots ... 1st
	attempt celebration, 2nd attempt celebration 3rd attempt"). Everyone has each kind's Default; everything won is kept;
	three slots per kind say which one they do on their 1st, 2nd and 3rd attempt. An id the configs don't know is never
	granted, and one in a slot that they don't own (or the game no longer has) counts as the Default.
]]

local OWNED_FIELD = { Entrance = "entrances", Celebration = "celebrations", Fail = "failStyles" }

local function ownedOf(data: ProfileData, kind: string): { [string]: boolean }?
	local inventory = (data :: any).inventory
	local field = OWNED_FIELD[kind]
	if typeof(inventory) ~= "table" or field == nil then
		return nil
	end
	if typeof(inventory[field]) ~= "table" then
		inventory[field] = {}
	end
	return inventory[field]
end

function ProfileOperations.ownsLoadoutItem(data: ProfileData, kind: string, id: string): boolean
	if not LoadoutConfig.isKind(kind) or not LoadoutConfig.isItem(kind, id) then
		return false
	end
	if id == LoadoutConfig.defaultOf(kind) then
		return true
	end
	local owned = ownedOf(data, kind)
	return owned ~= nil and owned[id] == true
end

-- Adds one to what they own (the Default is everyone's: true, nothing stored). False for an unknown id or kind.
function ProfileOperations.grantLoadoutItem(data: ProfileData, kind: string, id: string): boolean
	local owned = ownedOf(data, kind)
	if owned == nil or not LoadoutConfig.isItem(kind, id) then
		return false
	end
	if id ~= LoadoutConfig.defaultOf(kind) then
		owned[id] = true
	end
	return true
end

-- Everything of a kind they own (the Default first), in LoadoutConfig.items' order.
function ProfileOperations.getOwnedLoadout(data: ProfileData, kind: string): { string }
	local out = {}
	for _, item in ipairs(LoadoutConfig.items(kind)) do
		if ProfileOperations.ownsLoadoutItem(data, kind, item.id) then
			table.insert(out, item.id)
		end
	end
	return out
end

-- Their three slots of a kind, each one they own (else the Default).
function ProfileOperations.getLoadoutSlots(data: ProfileData, kind: string): { string }
	local inventory = (data :: any).inventory
	local saved = if typeof(inventory) == "table" and typeof(inventory.loadout) == "table" then inventory.loadout[kind] else nil
	local default = LoadoutConfig.defaultOf(kind)
	local out = {}
	for slot = 1, LoadoutConfig.Slots do
		local id = if typeof(saved) == "table" then saved[slot] else nil
		out[slot] = if typeof(id) == "string" and ProfileOperations.ownsLoadoutItem(data, kind, id) then id else default
	end
	return out
end

-- The one they do on `attempt` (1, 2 or 3; nil is the 1st).
function ProfileOperations.getLoadoutFor(data: ProfileData, kind: string, attempt: number?): string
	return ProfileOperations.getLoadoutSlots(data, kind)[LoadoutConfig.slotFor(attempt)]
end

-- Writes the slots of a kind (the checked ones from getLoadoutSlots, with `changes` applied).
local function writeSlots(data: ProfileData, kind: string, changes: { [number]: string })
	local inventory = (data :: any).inventory
	if typeof(inventory.loadout) ~= "table" then
		inventory.loadout = {}
	end
	local slots = ProfileOperations.getLoadoutSlots(data, kind)
	for slot, id in pairs(changes) do
		slots[slot] = id
	end
	inventory.loadout[kind] = slots
end

-- Puts one they own in a slot (1 to 3). The player's own choice, from the emote wheel's pages.
function ProfileOperations.setLoadoutSlot(data: ProfileData, kind: string, slot: number, id: string): (boolean, string)
	local inventory = (data :: any).inventory
	if typeof(inventory) ~= "table" or not LoadoutConfig.isKind(kind) then
		return false, "That isn't something with slots."
	end
	if typeof(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > LoadoutConfig.Slots then
		return false, "That isn't a slot."
	end
	if typeof(id) ~= "string" or not ProfileOperations.ownsLoadoutItem(data, kind, id) then
		return false, "You don't have that one yet. Win it at Hype Man."
	end
	writeSlots(data, kind, { [slot] = id })
	return true, "Set."
end

-- Puts one in all three slots (the admin's MAKE IT MINE / GiveEntrance). They must own it.
local function setAllSlots(data: ProfileData, kind: string, id: string)
	writeSlots(data, kind, { id, id, id })
end

-- A newly won one goes in the first slot still on the Default, so it shows up at the next meet without a trip to the
-- wheel (user 2026-11-12). Slots they have filled themselves are never changed.
local function fillFirstDefaultSlot(data: ProfileData, kind: string, id: string)
	local default = LoadoutConfig.defaultOf(kind)
	if id == default then
		return
	end
	for slot, current in ipairs(ProfileOperations.getLoadoutSlots(data, kind)) do
		if current == default then
			writeSlots(data, kind, { [slot] = id })
			return
		end
	end
end

-- (The walk-out names the rest of the game already uses.)
function ProfileOperations.ownsEntrance(data: ProfileData, id: string): boolean
	return ProfileOperations.ownsLoadoutItem(data, "Entrance", id)
end

-- The walk-out they use on `attempt` (nil: the 1st).
function ProfileOperations.getEntrance(data: ProfileData, attempt: number?): string
	return ProfileOperations.getLoadoutFor(data, "Entrance", attempt)
end

function ProfileOperations.grantEntrance(data: ProfileData, id: string): boolean
	return ProfileOperations.grantLoadoutItem(data, "Entrance", id)
end

-- Uses one walk-out they own on all three attempts.
function ProfileOperations.setEntrance(data: ProfileData, id: string): (boolean, string)
	if typeof(id) ~= "string" or not ProfileOperations.ownsEntrance(data, id) then
		return false, "They don't own that entrance."
	end
	setAllSlots(data, "Entrance", id)
	return true, "Entrance set."
end

-- The admin panel: gives the entrance and puts it on, for all three attempts.
function ProfileOperations.adminGiveEntrance(data: ProfileData, id: string): (boolean, string)
	local entrance = EntranceConfig.get(id)
	if entrance == nil or not ProfileOperations.grantEntrance(data, id) then
		return false, "That isn't an entrance."
	end
	ProfileOperations.setEntrance(data, id)
	return true, string.format("Entrance: %s.", entrance.name)
end

-- The celebration they do after a good lift on `attempt` (nil: the 1st).
function ProfileOperations.getCelebration(data: ProfileData, attempt: number?): string
	return ProfileOperations.getLoadoutFor(data, "Celebration", attempt)
end

-- Their fail style on `attempt` (nil: the 1st): a FailStyles id or "Default".
function ProfileOperations.getFailStyle(data: ProfileData, attempt: number?): string
	return ProfileOperations.getLoadoutFor(data, "Fail", attempt)
end

export type SpinOutcome = "Spun" | "NotEnough" | "Rejected"

-- Takes `price` coins and gives `given` back in one step (the wallet already checked).
local function charge(wallet: any, price: number, given: number)
	wallet.coins += given - price
	wallet.spentTotal += price - given
end

--[[
	One spin of a kind with slots: takes `price` coins and adds `resultId` to their collection; when they already had it
	(the Default included) gives `refund` back (user 2026-11-11: a duplicate gives coins back). A new one goes in the
	first slot still on the Default. All in one step. SERVER-ONLY: the price, the refund and the roll are the server's
	(CelebrationSpinService), never a client's. Returns the outcome, the balance and the coins given back; only "Spun"
	changes anything.
]]
local function spinLoadout(data: ProfileData, kind: string, price: number, resultId: string, refund: number)
	: (SpinOutcome, number?, number)
	local wallet = walletOf(data)
	if wallet == nil or ownedOf(data, kind) == nil or not isWholeCoins(price) or not isWholeCoins(refund) or refund > price
		or typeof(resultId) ~= "string" or not LoadoutConfig.isItem(kind, resultId) then
		return "Rejected", nil, 0
	end
	if wallet.coins < price then
		return "NotEnough", wallet.coins, 0
	end
	local had = ProfileOperations.ownsLoadoutItem(data, kind, resultId)
	local given = if had then refund else 0
	charge(wallet, price, given)
	if not had then
		ProfileOperations.grantLoadoutItem(data, kind, resultId)
		fillFirstDefaultSlot(data, kind, resultId)
	end
	return "Spun", wallet.coins, given
end

function ProfileOperations.spinCelebration(data: ProfileData, price: number, resultId: string, refund: number)
	: (SpinOutcome, number?, number)
	return spinLoadout(data, "Celebration", price, resultId, refund)
end

function ProfileOperations.spinEntrance(data: ProfileData, price: number, resultId: string, refund: number)
	: (SpinOutcome, number?, number)
	return spinLoadout(data, "Entrance", price, resultId, refund)
end

function ProfileOperations.spinFailStyle(data: ProfileData, price: number, resultId: string, refund: number)
	: (SpinOutcome, number?, number)
	return spinLoadout(data, "Fail", price, resultId, refund)
end

-- The admin panel: gives any fail style ("Default" too) and uses it on all three attempts.
function ProfileOperations.adminSetFailStyle(data: ProfileData, id: string): (boolean, string)
	if not ProfileOperations.grantLoadoutItem(data, "Fail", id) then
		return false, "That isn't a fail style."
	end
	setAllSlots(data, "Fail", id)
	return true, "Fail style set."
end

-- The admin panel: gives any celebration, for free, and uses it on all three attempts.
function ProfileOperations.adminSetCelebration(data: ProfileData, id: string): (boolean, string)
	local celebration = CelebrationConfig.byId[id]
	if celebration == nil or not ProfileOperations.grantLoadoutItem(data, "Celebration", id) then
		return false, "That isn't a celebration."
	end
	setAllSlots(data, "Celebration", id)
	return true, string.format("Celebration: %s.", celebration.name)
end

--[[
	THE EMOTES (schema version 23, user 2026-11-11): a collection (every one won is kept), played from the wheel; no
	slots. An id EmoteConfig doesn't know is never saved or used. SERVER-ONLY, as the spins above.
]]

local function emotesOf(data: ProfileData): { [string]: boolean }?
	local inventory = (data :: any).inventory
	if typeof(inventory) ~= "table" then
		return nil
	end
	if typeof(inventory.emotes) ~= "table" then
		inventory.emotes = {}
	end
	return inventory.emotes
end

function ProfileOperations.ownsEmote(data: ProfileData, id: string): boolean
	if EmoteConfig.isFree(id) then
		return true
	end
	local owned = emotesOf(data)
	return EmoteConfig.byId[id] ~= nil and owned ~= nil and owned[id] == true
end

-- The emotes they can play (the free ones included), in the wheel's order.
function ProfileOperations.getEmotes(data: ProfileData): { string }
	local out = {}
	for _, emote in ipairs(EmoteConfig.List) do
		if ProfileOperations.ownsEmote(data, emote.id) then
			table.insert(out, emote.id)
		end
	end
	return out
end

function ProfileOperations.spinEmote(data: ProfileData, price: number, resultId: string, refund: number)
	: (SpinOutcome, number?, number)
	local wallet = walletOf(data)
	local owned = emotesOf(data)
	if wallet == nil or owned == nil or not isWholeCoins(price) or not isWholeCoins(refund) or refund > price
		or typeof(resultId) ~= "string" or EmoteConfig.byId[resultId] == nil or EmoteConfig.isFree(resultId) then
		return "Rejected", nil, 0
	end
	if wallet.coins < price then
		return "NotEnough", wallet.coins, 0
	end
	local given = if owned[resultId] == true then refund else 0
	charge(wallet, price, given)
	owned[resultId] = true
	return "Spun", wallet.coins, given
end

function ProfileOperations.adminGiveEmote(data: ProfileData, id: string): (boolean, string)
	local owned = emotesOf(data)
	if owned == nil or EmoteConfig.byId[id] == nil then
		return false, "That isn't an emote."
	end
	if not EmoteConfig.isFree(id) then
		owned[id] = true
	end
	return true, "Emote given."
end

--------------------------------------------------------------------------------
-- Clothes and the gear toggle (version 25, ClothesConfig, GAME_DESIGN §38.6)
--------------------------------------------------------------------------------

local function inventoryTable(data: ProfileData): any
	local inventory = (data :: any).inventory
	return if typeof(inventory) == "table" then inventory else nil
end

-- Whether they may wear this item: free ones are everyone's; the rest must be in `clothes`.
function ProfileOperations.ownsClothing(data: ProfileData, itemId: string): boolean
	local item = ClothesConfig.item(itemId)
	if item == nil then
		return false
	end
	if item.free then
		return true
	end
	local inventory = inventoryTable(data)
	return inventory ~= nil and typeof(inventory.clothes) == "table" and inventory.clothes[itemId] == true
end

-- What they wear, every kind filled in: a missing, unknown or no-longer-owned choice reads as the default.
function ProfileOperations.getOutfit(data: ProfileData): { [string]: ClothesConfig.Choice }
	local inventory = inventoryTable(data)
	local saved = if inventory and typeof(inventory.outfit) == "table" then inventory.outfit else {}
	local outfit: { [string]: ClothesConfig.Choice } = {}
	for _, kind in ipairs(ClothesConfig.Kinds) do
		local choice = saved[kind]
		local default = ClothesConfig.Default[kind]
		local item = if typeof(choice) == "table" then ClothesConfig.item(choice.item) else nil
		local colour = if typeof(choice) == "table" then ClothesConfig.colour(choice.colour) else nil
		if item and item.kind == kind and ProfileOperations.ownsClothing(data, item.id) then
			outfit[kind] = { item = item.id, colour = if colour then colour.id else default.colour }
		else
			outfit[kind] = { item = default.item, colour = if colour then colour.id else default.colour }
		end
	end
	return outfit
end

-- Puts on one piece in one colour. Checks the kind, that the item is that kind and theirs, and the colour.
function ProfileOperations.setOutfitPiece(data: ProfileData, kind: string, itemId: string, colourId: string): (boolean, string)
	local inventory = inventoryTable(data)
	if inventory == nil then
		return false, "The save has no inventory."
	end
	if not ClothesConfig.isKind(kind) then
		return false, "That isn't clothing."
	end
	local item = ClothesConfig.item(itemId)
	if item == nil or item.kind ~= kind then
		return false, "That doesn't go there."
	end
	if not ProfileOperations.ownsClothing(data, item.id) then
		return false, "You don't own that yet."
	end
	if ClothesConfig.colour(colourId) == nil then
		return false, "Unknown colour."
	end
	if typeof(inventory.outfit) ~= "table" then
		inventory.outfit = {}
	end
	inventory.outfit[kind] = { item = item.id, colour = colourId }
	return true, item.label .. " on."
end

-- The gear toggle; true when the save has none (version 25 starts it on).
function ProfileOperations.getGearOn(data: ProfileData): boolean
	local inventory = inventoryTable(data)
	return not (inventory and inventory.gearOn == false)
end

function ProfileOperations.setGearOn(data: ProfileData, on: boolean): boolean
	local inventory = inventoryTable(data)
	if inventory == nil or typeof(on) ~= "boolean" then
		return false
	end
	inventory.gearOn = on
	return true
end

--[[
	=====================================================================================================================
	RANKS AND TITLES (schema 35; GAME_DESIGN §41, RankConfig)
	=====================================================================================================================
	SECURITY BOUNDARY: every value comes from the server's meet result (LocalMeetService) and RankConfig; a client only
	asks to claim, to open a free crate or to pick a title it owns.
]]

local function usableRanks(data: ProfileData): any?
	local ranks = (data :: any).ranks
	if typeof(ranks) ~= "table" or typeof(ranks.hasTotal) ~= "boolean" or typeof(ranks.feats) ~= "table"
		or typeof(ranks.title) ~= "string" or typeof(ranks.streakDayKey) ~= "string" or typeof(ranks.bestClass) ~= "string" then
		return nil
	end
	for _, field in ipairs({ "bestPoints", "bestTotalKg", "bestBodyweightKg", "bestUnix", "claimed", "freeCrates",
		"luckBoostEndsAt", "titlesSeenUnix", "streakDays" }) do
		if not isFiniteNumber(ranks[field]) or ranks[field] < 0 then
			return nil
		end
	end
	return ranks
end

-- The rank reached (0 = none yet). Reads only.
function ProfileOperations.getRank(data: ProfileData): number
	local ranks = usableRanks(data)
	return if ranks then RankConfig.rankFor(ranks.bestPoints, ranks.hasTotal) else 0
end

-- Whether the lifter owns title `id`: a feat in the ranks record, or a meet title in career.titles.
local function ownsTitle(data: ProfileData, ranks: any, id: string): boolean
	if RankConfig.TitleById[id] == nil then
		return false
	end
	if RankConfig.isFeat(id) then
		return isFiniteNumber(ranks.feats[id])
	end
	local career = (data :: any).career
	local count = if typeof(career) == "table" and typeof(career.titles) == "table" then career.titles[id] else nil
	return isFiniteNumber(count) and count >= 1
end

export type RankMeet = {
	-- GL points of the meet total, the total and the weigh-in it was made at.
	points: number,
	totalKg: number,
	bodyweightKg: number,
	classLabel: string,
	-- The best good lift of each lift at the meet (kg).
	bestByLift: { [string]: number },
	perfect: boolean, -- 9/9
	clutch: boolean, -- a third attempt made after missing the first two on that lift
	gymRecord: boolean, -- set a gym record at this meet
}

export type RankMeetResult = {
	rankBefore: number,
	rankAfter: number,
	newBest: boolean,
	newFeats: { string },
	streakDays: number,
}

--[[
	Records a real meet finished WITH A TOTAL: the best GL total (a rank never goes down), the feats it earned and the
	day streak. Rewards are not paid here (claimRankRewards does, so a crash between the two never pays twice or loses
	one). Returns nil (nothing written) for an unusable record or bad numbers.
]]
function ProfileOperations.recordRankMeet(data: ProfileData, meet: RankMeet, nowUnix: number): RankMeetResult?
	local ranks = usableRanks(data)
	if ranks == nil or typeof(meet) ~= "table" or not isFiniteNumber(meet.points) or meet.points <= 0
		or not isFiniteNumber(meet.totalKg) or meet.totalKg <= 0 or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return nil
	end
	local result: RankMeetResult = { rankBefore = RankConfig.rankFor(ranks.bestPoints, ranks.hasTotal), rankAfter = 0,
		newBest = false, newFeats = {}, streakDays = 0 }
	if not ranks.hasTotal or meet.points > ranks.bestPoints then
		ranks.hasTotal = true
		ranks.bestPoints = meet.points
		ranks.bestTotalKg = meet.totalKg
		ranks.bestBodyweightKg = if isFiniteNumber(meet.bodyweightKg) then meet.bodyweightKg else 0
		ranks.bestClass = if typeof(meet.classLabel) == "string" then string.sub(meet.classLabel, 1, 20) else ""
		ranks.bestUnix = math.floor(nowUnix)
		result.newBest = true
	end
	result.rankAfter = RankConfig.rankFor(ranks.bestPoints, ranks.hasTotal)
	-- The day streak (Iron Streak): today continues yesterday's run; the same day keeps it; a gap starts over.
	local today = DayKey.fromUnix(nowUnix)
	if ranks.streakDayKey ~= today then
		local yesterday = DayKey.fromUnix(nowUnix - 86400)
		ranks.streakDays = if ranks.streakDayKey == yesterday then ranks.streakDays + 1 else 1
		ranks.streakDayKey = today
	end
	result.streakDays = ranks.streakDays
	local function earn(id: string)
		if RankConfig.isFeat(id) and not isFiniteNumber(ranks.feats[id]) then
			ranks.feats[id] = math.floor(nowUnix)
			table.insert(result.newFeats, id)
		end
	end
	if meet.perfect then
		earn("NineForNine")
	end
	if meet.clutch then
		earn("Clutch")
	end
	if meet.gymRecord then
		earn("GymRecordHolder")
	end
	if ranks.streakDays >= RankConfig.StreakDays then
		earn("IronStreak")
	end
	for _, club in ipairs(RankConfig.TotalClubs) do
		if meet.totalKg >= club.kg then
			earn(club.id)
		end
	end
	if typeof(meet.bestByLift) == "table" then
		for lift, clubs in pairs(RankConfig.LiftClubs) do
			local kg = meet.bestByLift[lift]
			if isFiniteNumber(kg) then
				for _, club in ipairs(clubs) do
					if kg >= club.kg then
						earn(club.id)
					end
				end
			end
		end
	end
	return result
end

export type RankRewards = {
	ranks: { number }, -- the ranks paid, lowest first
	coins: number,
	crates: number,
	luckBoost: boolean,
	coinsRefused: boolean, -- the wallet was full (CoinConfig.MaxBalance): the crates and boost were still given
	balance: number?,
}

--[[
	Pays every rank reached but not yet paid, up to rank `upTo` (nil = all): coins (RankConfig.coinsFor), a free crate
	each, and the luck boost when one of them starts a new name (it lasts RankConfig.LuckBoost.Hours from now). Each
	rank-up moment collects only its own ranks, so a later moment still has its rewards. Returns what was paid (an empty
	list = nothing waiting), or nil for an unusable record.
]]
function ProfileOperations.claimRankRewards(data: ProfileData, nowUnix: number, upTo: number?): RankRewards?
	local ranks = usableRanks(data)
	if ranks == nil or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return nil
	end
	local reached = RankConfig.rankFor(ranks.bestPoints, ranks.hasTotal)
	if upTo ~= nil and isFiniteNumber(upTo) then
		reached = math.min(reached, math.floor(upTo))
	end
	local paid: RankRewards = { ranks = {}, coins = 0, crates = 0, luckBoost = false, coinsRefused = false, balance = nil }
	local from = math.floor(ranks.claimed) + 1
	if reached < from then
		return paid
	end
	for index = from, reached do
		local rank = RankConfig.Ranks[index]
		table.insert(paid.ranks, index)
		paid.coins += rank.coins
		paid.crates += RankConfig.CratesPerRank
		if rank.newName then
			paid.luckBoost = true
		end
	end
	if paid.coins > 0 then
		local outcome, balance = ProfileOperations.addCoins(data, paid.coins)
		if outcome == "Added" then
			paid.balance = balance
		else
			paid.coinsRefused = true
			paid.coins = 0
		end
	end
	ranks.freeCrates += paid.crates
	if paid.luckBoost then
		ranks.luckBoostEndsAt = math.floor(nowUnix) + RankConfig.LuckBoost.Hours * 3600
	end
	ranks.claimed = reached
	return paid
end

export type FreeCrateOutcome = "Opened" | "NoneLeft" | "Full" | "Rejected"

-- Opens one free rank crate: uses one and adds `piece` (rolled by the server). Only "Opened" changes anything.
function ProfileOperations.useFreeCrate(data: ProfileData, piece: PlayerProfileSchema.StatPiece, maxPieces: number)
	: (FreeCrateOutcome, string?, number?)
	local ranks = usableRanks(data)
	local inventory, pieces = piecesOf(data)
	if ranks == nil or inventory == nil or typeof(piece) ~= "table" or not isItemId(piece.slot)
		or not isItemId(piece.rarity) or not isItemId(piece.look) then
		return "Rejected", nil, nil
	end
	if ranks.freeCrates < 1 then
		return "NoneLeft", nil, 0
	end
	local count = 0
	for _ in pairs(pieces) do
		count += 1
	end
	if count >= maxPieces then
		return "Full", nil, ranks.freeCrates
	end
	local id = tostring(inventory.nextPieceId)
	inventory.nextPieceId += 1
	pieces[id] = { slot = piece.slot, rarity = piece.rarity, look = piece.look }
	ranks.freeCrates -= 1
	return "Opened", id, ranks.freeCrates
end

-- Picks the title to show ("" = none: the newest shows). Only a title the lifter owns. Returns true when set.
function ProfileOperations.setTitle(data: ProfileData, id: string): boolean
	local ranks = usableRanks(data)
	if ranks == nil or typeof(id) ~= "string" then
		return false
	end
	if id ~= "" and not ownsTitle(data, ranks, id) then
		return false
	end
	ranks.title = id
	return true
end

--[[
	ADMIN ONLY (AdminService checks the caller): puts the rank back to the start so the whole ladder can be tested again
	(user 2026-11-23: "do the admin only reset my rank"). Clears the best total, the rewards paid and waiting, the unopened
	free rank crates, the rank luck boost and the day streak. Keeps the titles (feats and meet titles) and every coin
	already earned. Returns true when written.
]]
function ProfileOperations.adminResetRank(data: ProfileData): boolean
	local ranks = usableRanks(data)
	if ranks == nil then
		return false
	end
	ranks.hasTotal = false
	ranks.bestPoints = 0
	ranks.bestTotalKg = 0
	ranks.bestBodyweightKg = 0
	ranks.bestClass = ""
	ranks.bestUnix = 0
	ranks.claimed = 0
	ranks.freeCrates = 0
	ranks.luckBoostEndsAt = 0
	ranks.streakDayKey = ""
	ranks.streakDays = 0
	return true
end

-- Marks every title earned so far as seen (the titles screen's NEW tags go). Returns true when written.
function ProfileOperations.markTitlesSeen(data: ProfileData, nowUnix: number): boolean
	local ranks = usableRanks(data)
	if ranks == nil or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return false
	end
	ranks.titlesSeenUnix = math.floor(nowUnix)
	return true
end

export type TitleOwned = { count: number, earnedUnix: number, new: boolean }
export type RankView = {
	rank: number,
	points: number,
	bestTotalKg: number,
	bestBodyweightKg: number,
	bestClass: string,
	claimed: number,
	freeCrates: number,
	luckBoostLeft: number,
	streakDays: number,
	title: string, -- the title shown: the picked one, else the best one owned ("" = none)
	picked: string,
	titles: { [string]: TitleOwned },
}

-- The lifter's rank, rewards waiting and titles, for their screens and their name tag. Reads only.
function ProfileOperations.getRanks(data: ProfileData, nowUnix: number): RankView
	local view: RankView = { rank = 0, points = 0, bestTotalKg = 0, bestBodyweightKg = 0, bestClass = "", claimed = 0,
		freeCrates = 0, luckBoostLeft = 0, streakDays = 0, title = "", picked = "", titles = {} }
	local ranks = usableRanks(data)
	if ranks == nil then
		return view
	end
	view.rank = RankConfig.rankFor(ranks.bestPoints, ranks.hasTotal)
	view.points = ranks.bestPoints
	view.bestTotalKg = ranks.bestTotalKg
	view.bestBodyweightKg = ranks.bestBodyweightKg
	view.bestClass = ranks.bestClass
	view.claimed = math.floor(ranks.claimed)
	view.freeCrates = math.floor(ranks.freeCrates)
	view.luckBoostLeft = if isFiniteNumber(nowUnix) then math.max(0, ranks.luckBoostEndsAt - nowUnix) else 0
	local live = ranks.streakDayKey == DayKey.fromUnix(nowUnix) or ranks.streakDayKey == DayKey.fromUnix(nowUnix - 86400)
	view.streakDays = if live then math.floor(ranks.streakDays) else 0
	for id, when in pairs(ranks.feats) do
		if RankConfig.TitleById[id] and isFiniteNumber(when) then
			view.titles[id] = { count = 1, earnedUnix = when, new = when > ranks.titlesSeenUnix }
		end
	end
	-- Meet titles have no time saved (career.titles counts them): never NEW.
	local career = (data :: any).career
	if typeof(career) == "table" and typeof(career.titles) == "table" then
		for id, count in pairs(career.titles) do
			if typeof(id) == "string" and RankConfig.TitleById[id] and isFiniteNumber(count) and count >= 1 then
				view.titles[id] = { count = math.floor(count), earnedUnix = 0, new = false }
			end
		end
	end
	-- Nothing picked: the grandest title owned shows (highest tier, then the latest in the list).
	local best = ""
	for id in pairs(view.titles) do
		local entry, current = RankConfig.TitleById[id], RankConfig.TitleById[best]
		if current == nil or entry.tier > current.tier or (entry.tier == current.tier and entry.order > current.order) then
			best = id
		end
	end
	view.picked = if ranks.title ~= "" and view.titles[ranks.title] then ranks.title else ""
	view.title = if view.picked ~= "" then view.picked else best
	return view
end

--[[
	=====================================================================================================================
	INVENTORY ITEMS (schema 37; GAME_DESIGN §42): food collected from the chef, medals and trophies
	=====================================================================================================================
	An item is a record with a `type` and a `qty`; identical items stack (more qty). Food: { type "Food", food "Steak" |
	"Meal", count, hours } (its boost comes from KitchenConfig when eaten). Medals and trophies: { type "Medal" |
	"Trophy", level, place }. SECURITY BOUNDARY: the server makes every item from its own results; a client only asks
	to collect its cook or use an item it owns.
]]
export type Item = { type: string, qty: number, food: string?, count: number?, hours: number?, level: string?, place: number? }
export type CollectOutcome = "Collected" | "NotReady" | "Empty" | "Full" | "Rejected"
export type UseOutcome = "Eaten" | "NotFood" | "Missing" | "Rejected"

-- How many different item stacks an inventory holds (a safety limit).
local MAX_ITEM_STACKS = 200

local function itemsOf(data: ProfileData): (any?, any?)
	local inventory = (data :: any).inventory
	if typeof(inventory) ~= "table" or typeof(inventory.items) ~= "table" or not isFiniteNumber(inventory.nextItemId) then
		return nil, nil
	end
	return inventory, inventory.items
end

local function sameItem(a: any, b: any): boolean
	return a.type == b.type and a.food == b.food and a.count == b.count and a.hours == b.hours and a.level == b.level
		and a.place == b.place
end

-- Adds one of `record` (stacking onto an identical item). Returns its id, or nil when full or broken.
local function addItem(data: ProfileData, record: any): string?
	local inventory, items = itemsOf(data)
	if inventory == nil then
		return nil
	end
	local stacks = 0
	for id, item in pairs(items) do
		if typeof(item) == "table" and sameItem(item, record) then
			item.qty = (if isFiniteNumber(item.qty) then item.qty else 0) + 1
			return id
		end
		stacks += 1
	end
	if stacks >= MAX_ITEM_STACKS then
		return nil
	end
	local id = tostring(math.floor(inventory.nextItemId))
	inventory.nextItemId += 1
	record.qty = 1
	items[id] = record
	return id
end

--[[
	Collects the finished cook from the chef into the inventory as a food item (user 2026-11-24: "walk up to the chef and
	ask for their food then it appears in their Inventory") and empties the cooker. Returns the outcome and the item's id.
	Nothing is written unless "Collected".
]]
function ProfileOperations.collectFood(data: ProfileData, nowUnix: number): (CollectOutcome, string?)
	local kitchen = usableKitchen(data)
	local inventory = itemsOf(data)
	if kitchen == nil or inventory == nil or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return "Rejected", nil
	end
	if kitchen.steaks < 1 then
		return "Empty", nil
	end
	if nowUnix < kitchen.readyAt then
		return "NotReady", nil
	end
	local hours = if KitchenConfig.isCookHours(kitchen.hours) then kitchen.hours else KitchenConfig.BoostHours
	local id = addItem(data, { type = "Food", food = cookKind(kitchen), count = math.floor(kitchen.steaks), hours = hours })
	if id == nil then
		return "Full", nil
	end
	kitchen.steaks = 0
	kitchen.kind = "Steak"
	kitchen.hours = KitchenConfig.BoostHours
	kitchen.startedAt = 0
	kitchen.readyAt = 0
	return "Collected", id
end

-- Uses (eats) one of item `id`: a food's boost starts (KitchenConfig, the cook-timer rules). Returns the outcome, the
-- boost's percent and the food kind. Nothing is written unless "Eaten".
function ProfileOperations.useItem(data: ProfileData, id: string, nowUnix: number): (UseOutcome, number?, string?)
	local _, items = itemsOf(data)
	local boosts = (data :: any).boosts
	if items == nil or typeof(boosts) ~= "table" or typeof(boosts.steak) ~= "table" or typeof(id) ~= "string"
		or not isFiniteNumber(nowUnix) or nowUnix < 0 then
		return "Rejected", nil, nil
	end
	local item = items[id]
	if typeof(item) ~= "table" or not isFiniteNumber(item.qty) or item.qty < 1 then
		return "Missing", nil, nil
	end
	if item.type ~= "Food" or not KitchenConfig.isKind(item.food) or not KitchenConfig.isSteakCount(item.count) then
		return "NotFood", nil, nil
	end
	local percent = applyFood(boosts, item.food, item.count, item.hours, nowUnix)
	if percent == nil then
		return "Rejected", nil, nil
	end
	item.qty -= 1
	if item.qty < 1 then
		items[id] = nil
	end
	return "Eaten", percent, item.food
end

-- Gives one medal or trophy (Stage 4, the meet's result decides it). Returns its id or nil.
function ProfileOperations.addAward(data: ProfileData, kind: string, level: string, place: number): string?
	if (kind ~= "Medal" and kind ~= "Trophy") or typeof(level) ~= "string" or #level > 20 or not isFiniteNumber(place)
		or place < 1 or place > 3 then
		return nil
	end
	return addItem(data, { type = kind, level = level, place = math.floor(place) })
end

-- A copy of the items: id -> item. Reads only.
function ProfileOperations.getItems(data: ProfileData): { [string]: Item }
	local copy: { [string]: Item } = {}
	local _, items = itemsOf(data)
	for id, item in pairs(items or {}) do
		if typeof(id) == "string" and typeof(item) == "table" and typeof(item.type) == "string" and isFiniteNumber(item.qty)
			and item.qty >= 1 then
			copy[id] = table.clone(item)
		end
	end
	return copy
end

--[[
	=========================================================================
	COACHING  (GAME_DESIGN §40.5, version 38)
	=========================================================================

	Every player is coached by the gym owner (free). A lift coach is hired in steps: pay (hireCoach), pass trial 1 in
	the Mock Meet room (endCoachTrial1; a fail means paying again), pass trial 2 at a real meet (passCoachTrial2), and
	they're the player's coach. One coach is active at a time (setActiveCoach). SERVER-ONLY callers; the client only
	asks (CoachingService).
]]

export type CoachingView = { active: string, coaches: { [string]: { stage: string, bond: number } } }
export type HireOutcome = "Paid" | "NotEnough" | "AlreadyPaid" | "Rejected"

-- The coaching record, repaired in place (nil only when the data itself is unusable).
local function coachingOf(data: ProfileData): PlayerProfileSchema.Coaching?
	if typeof(data) ~= "table" then
		return nil
	end
	local coaching = (data :: any).coaching
	if typeof(coaching) ~= "table" then
		(data :: any).coaching = { active = CoachingConfig.OwnerId, coaches = {} }
		coaching = (data :: any).coaching
	end
	if typeof(coaching.coaches) ~= "table" then
		coaching.coaches = {}
	end
	for _, lift in ipairs(CoachingConfig.Lifts) do
		local record = coaching.coaches[lift]
		if typeof(record) ~= "table" then
			record = {}
			coaching.coaches[lift] = record
		end
		if not CoachingConfig.isStage(record.stage) then
			record.stage = "none"
		end
		if not isFiniteNumber(record.bond) or record.bond < 0 then
			record.bond = 0
		end
	end
	if coaching.active ~= CoachingConfig.OwnerId
		and not (CoachingConfig.isLift(coaching.active) and coaching.coaches[coaching.active].stage == "hired") then
		coaching.active = CoachingConfig.OwnerId
	end
	return coaching
end

-- A copy of the player's coaching, for screens.
function ProfileOperations.getCoaching(data: ProfileData): CoachingView?
	local coaching = coachingOf(data)
	if coaching == nil then
		return nil
	end
	local view: CoachingView = { active = coaching.active, coaches = {} }
	for _, lift in ipairs(CoachingConfig.Lifts) do
		local record = coaching.coaches[lift]
		view.coaches[lift] = { stage = record.stage, bond = record.bond }
	end
	return view
end

--[[
	Pays `price` coins to `lift`'s coach to start their trials (stage "none" -> "trial1"). Returns "Paid" and the new
	balance; "NotEnough" and the balance; "AlreadyPaid" when this coach is past "none"; "Rejected" otherwise. Nothing
	changes unless "Paid".
]]
function ProfileOperations.hireCoach(data: ProfileData, lift: string, price: number): (HireOutcome, number?)
	local coaching = coachingOf(data)
	if coaching == nil or not CoachingConfig.isLift(lift) or not isWholeCoins(price) then
		return "Rejected", nil
	end
	if coaching.coaches[lift].stage ~= "none" then
		return "AlreadyPaid", ProfileOperations.getCoins(data)
	end
	local outcome, balance = ProfileOperations.spendCoins(data, price)
	if outcome == "NotEnough" then
		return "NotEnough", balance
	elseif outcome ~= "Spent" then
		return "Rejected", nil
	end
	coaching.coaches[lift].stage = "trial1"
	return "Paid", balance
end

-- Trial 1's result for `lift`'s coach: passed -> "trial2"; failed -> "none" (pay again). Returns the new stage, or nil
-- when this coach wasn't on trial 1.
function ProfileOperations.endCoachTrial1(data: ProfileData, lift: string, passed: boolean): string?
	local coaching = coachingOf(data)
	if coaching == nil or not CoachingConfig.isLift(lift) or coaching.coaches[lift].stage ~= "trial1" then
		return nil
	end
	coaching.coaches[lift].stage = if passed then "trial2" else "none"
	return coaching.coaches[lift].stage
end

-- Trial 2 passed for `lift`'s coach: they're hired, and become the active coach. Returns whether it changed anything.
function ProfileOperations.passCoachTrial2(data: ProfileData, lift: string): boolean
	local coaching = coachingOf(data)
	if coaching == nil or not CoachingConfig.isLift(lift) or coaching.coaches[lift].stage ~= "trial2" then
		return false
	end
	coaching.coaches[lift].stage = "hired"
	coaching.active = lift
	return true
end

-- Makes `id` the active coach: "Owner" or a hired coach's lift. Returns whether it is now the active coach.
function ProfileOperations.setActiveCoach(data: ProfileData, id: string): boolean
	local coaching = coachingOf(data)
	if coaching == nil then
		return false
	end
	if id == CoachingConfig.OwnerId or (CoachingConfig.isLift(id) and coaching.coaches[id].stage == "hired") then
		coaching.active = id
		return true
	end
	return false
end

-- A real meet finished with a hired coach active: their bond grows by one (for the coach's unlocks, later).
function ProfileOperations.addCoachBond(data: ProfileData)
	local coaching = coachingOf(data)
	if coaching and CoachingConfig.isLift(coaching.active) then
		coaching.coaches[coaching.active].bond += 1
	end
end

-- ADMIN (testing): puts `lift`'s coach at `stage` (and the gym owner back in charge if they're no longer hired).
function ProfileOperations.adminSetCoachStage(data: ProfileData, lift: string, stage: string): boolean
	local coaching = coachingOf(data)
	if coaching == nil or not CoachingConfig.isLift(lift) or not CoachingConfig.isStage(stage) then
		return false
	end
	coaching.coaches[lift].stage = stage
	coachingOf(data)
	return true
end

return ProfileOperations
