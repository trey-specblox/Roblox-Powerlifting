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

local ProgressionFolder = Shared:WaitForChild("Progression")
local CompetitionNumberReward = require(ProgressionFolder:WaitForChild("CompetitionNumberReward"))
local TrainingAllowance = require(ProgressionFolder:WaitForChild("TrainingAllowance"))
local TechniqueTraining = require(ProgressionFolder:WaitForChild("TechniqueTraining"))
local WeightClass = require(ProgressionFolder:WaitForChild("WeightClass"))
local MeetCnAllowance = require(ProgressionFolder:WaitForChild("MeetCnAllowance"))
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
	nowUnix: number): (MeetCnOutcome, number?, number)
	local resource = meetAllowanceOf(data, classKey, lift)
	local build = ProfileOperations.getBuild(data, classKey)
	local current = build and buildCompetitionNumber(build, lift)
	if resource == nil or build == nil or current == nil or not isFiniteNumber(cnAtWeighInKg) or cnAtWeighInKg <= 0 then
		return "Rejected", nil, 0
	end
	local outcome = MeetCnAllowance.settle(resource, nowUnix, lift, classKey, cnAtWeighInKg, history, raises)
	if outcome == nil then
		return "Rejected", current, 0
	end
	if outcome.newCnKg > current + 1e-9 then
		(build.competitionNumber :: any)[lift] = outcome.newCnKg
		return "Raised", outcome.newCnKg, outcome.daysUsed
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

	purchaseItem is the ONLY way an item becomes owned, and it takes the coins
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

-- A copy of what is worn: slot -> item id (only owned items).
function ProfileOperations.getWorn(data: ProfileData): { [string]: string }
	local copy: { [string]: string } = {}
	for slot, itemId in pairs(wearingOf(data) or {}) do
		if typeof(slot) == "string" and typeof(itemId) == "string" and ProfileOperations.ownsItem(data, itemId) then
			copy[slot] = itemId
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
	if itemId == nil then
		wearing[slot] = nil
		return "TakenOff"
	end
	if not isItemId(itemId) then
		return "Rejected"
	end
	if not ProfileOperations.ownsItem(data, itemId) then
		return "NotOwned"
	end
	wearing[slot] = itemId
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
		local calculated, _ = CompetitionNumberReward.calculateTrainingAward(
			lift,
			weightClassLabel,
			competitionNumberBefore,
			earnedEV
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
	elapsedSeconds: number
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

	local totalRaw = TechniqueTraining.rawPointsFor(elapsedSeconds)

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

return ProfileOperations
