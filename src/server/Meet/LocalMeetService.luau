--!strict
--[[
	LocalMeetService
	Server / Meet

	The Local meet, the first meet against other players (GAME_DESIGN.md §29.10
	"The Local meet — first build", user 2026-10-29). STEP 1: the meet itself on
	the temporary venue (LocalMeetVenue). STEP 2: what it saves (§33.3b), into
	the build of each lifter's weigh-in class, in one write per lifter:
		- a meet WITH A TOTAL: each lift's best good lift raises its
		  Competition Scale, and the Total can raise the best Total
		- a meet that started with RewardMinimumLifters (against other players):
		  each lift's CN is settled against the build's meet allowance
		  (ProfileOperations.settleMeetCompetitionNumber): good lifts above CN
		  raise it as far as the allowance pays, misses above CN still use it;
		  without a total nothing is raised and only the misses cost
		- 1st place in such a meet: one Local win (career.localWins, a lifetime
		  statistic)
		- finishing such a meet with a total: ladder points toward the State
		  Championship in the weigh-in class (GAME_DESIGN §35.8, §36.3,
		  MeetLevelConfig.Ladder), more for a top 3 place and a Regional meet
	A lifter who withdraws, exits, dies or leaves has no total: only their
	misses are settled, at once.

	COMPUTER LIFTERS (GAME_DESIGN §37.2, user 2026-11-01): a meet runs with one
	real player; with fewer than FillToLifters, computer lifters
	(ComputerLifters) fill it. They lift, show on the boards and place like
	anyone, but never take a reward from a real player: prizes, ladder place
	points, titles and wins go by the real lifters' order among themselves
	(Meet.rewardPlaces). A meet with only ONE real player pays the reduced
	rewards (Meet.solo): Scale, CN at full speed (SoloCostMultiplier 1),
	finishing and 9/9 coins, finishing ladder points; no prize pot, gym
	records, titles or win.

	GETTING THERE. The point in front of the doors of the venue's entrance
	building outside the gym (LocalMeetVenue.buildEntrance, tagged
	LocalMeetConfig.EntranceTag) gets a "Go to the Local Meet" prompt; the
	server checks the player is alive, on
	their feet and near it, then moves them into the venue and sets the player
	attribute LocalMeetConfig.VenueAttribute. The venue's exit point (or the
	EXIT button) takes them back where they came from. Dying, respawning or
	leaving the game also takes them out of the venue.

	FIVE MEETS AT ONCE (user 2026-11-05). The venue is LocalMeetConfig.HallCount
	identical halls (type Hall), each with its own meet, sign-up list, level, timetable,
	placings and rewards. A player is on one list at a time and in one meet at a
	time, and stands in one hall (Visit.hall): SPECTATE moves them to another, and a
	meet starting moves its lifters to its hall. Only the people in a hall get its
	standings, awards and sounds. They arrive in hall 1. The warm-up racks of every
	hall share one LocalMeetWarmUp.

	THE TIMETABLE. A hall's meet starts once every CycleSeconds of server time, the
	halls evenly staggered, if at least MinimumLifters signed up (the SIGN UP
	button or the hall's desk; the same press takes a name off). Sign-ups close
	SignUpClosesSeconds before a start. The first MaxLifters on the list lift; the
	rest stay on it for the next meet, as do all names when too few signed up. A
	start during a running meet is skipped.

	THE MEET (server-run; the clients only ask and draw):
		weigh-in: each lifter's class (= build) and Competition Numbers, locked
		9 rounds (3 attempts x squat, bench, deadlift), everyone together:
			Choose   every lifter declares a weight (AttemptChoice, the Mock
			         Meet's rules); time out -> the default. A lifter with no
			         legal heavier weight passes the attempt
			Lift     every lifter stands on their own platform and presses
			         LIFT when ready (time out -> no lift); the existing
			         minigames decide good lift or no lift
			Result   the three referees' lights (all white for a good lift, all
			         red for a no lift: the minigames decide, the referees show
			         it) on the lifter's screen and their platform's board
		The round moves on once every lifter is done.
		Done: everyone's total, the ranking by score (MeetPlacing), the place;
		the racks make way for the awards stage (LocalMeetVenue.showAwards) and
		the top three stand on its podium while the standings show;
		LocalMeetRemotes.AWARDS tells everyone in the venue (camera shots, the
		crowd cheer, the winner's theme song and celebration: themeFor /
		celebrationFor, the defaults until custom ones exist).
	Each platform's big screen (LifterDisplay, boardFor) shows its lifter: name,
	class, bodyweight, forecast total, bests, the lift now and fun facts.
	The warm-up room's racks are LocalMeetWarmUp's (practice, nothing saved).
	A lifter who withdraws (LEAVE), exits, dies or leaves the game is out of the
	meet; the others carry on. LocalMeetRemotes.STANDINGS keeps everyone in the
	venue up to date, and the scoreboard shows the same.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local StateArenaConfig = require(ConfigFolder:WaitForChild("StateArenaConfig"))
local TeleportConfig = require(ConfigFolder:WaitForChild("TeleportConfig"))
local CoinConfig = require(ConfigFolder:WaitForChild("CoinConfig"))
local MeetLevelConfig = require(ConfigFolder:WaitForChild("MeetLevelConfig"))
local NationalsConfig = require(ConfigFolder:WaitForChild("NationalsConfig"))
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local LuckConfig = require(ConfigFolder:WaitForChild("LuckConfig"))
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local LiftAttemptConfig = require(ConfigFolder:WaitForChild("LiftAttemptConfig"))
local StationAnimationConfig = require(ConfigFolder:WaitForChild("StationAnimationConfig"))
local MeetSoundConfig = require(ConfigFolder:WaitForChild("MeetSoundConfig"))
local EntranceConfig = require(ConfigFolder:WaitForChild("EntranceConfig"))
local CelebrationConfig = require(ConfigFolder:WaitForChild("CelebrationConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local LocalMeetRemotes = require(MeetFolder:WaitForChild("LocalMeetRemotes"))
local MockMeetRemotes = require(MeetFolder:WaitForChild("MockMeetRemotes"))
local AttemptRules = require(MeetFolder:WaitForChild("AttemptRules"))
local AttemptChoice = require(MeetFolder:WaitForChild("AttemptChoice"))
local MeetTotal = require(MeetFolder:WaitForChild("MeetTotal"))
local MeetPlacing = require(MeetFolder:WaitForChild("MeetPlacing"))

local ServerFolder = script.Parent.Parent
local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))
local StateArenaVenue = require(script.Parent:WaitForChild("StateArenaVenue"))
local LocalMeetWarmUp = require(script.Parent:WaitForChild("LocalMeetWarmUp"))
local GymRecords = require(script.Parent:WaitForChild("GymRecords"))
local MeetPayout = require(script.Parent:WaitForChild("MeetPayout"))
local Trophies = require(script.Parent:WaitForChild("Trophies"))
local ChampionBadges = require(script.Parent:WaitForChild("ChampionBadges"))
local ComputerLifters = require(script.Parent:WaitForChild("ComputerLifters"))
local MeetLiftAnimation = require(script.Parent:WaitForChild("MeetLiftAnimation"))
local MeetChalk = require(script.Parent:WaitForChild("MeetChalk"))
local MeetEntrance = require(script.Parent:WaitForChild("MeetEntrance"))
local MeetLiveScreens = require(script.Parent:WaitForChild("MeetLiveScreens"))
local MeetCheering = require(script.Parent:WaitForChild("MeetCheering"))
local StateArenaShow = require(script.Parent:WaitForChild("StateArenaShow"))
local MeetFigures = require(script.Parent:WaitForChild("MeetFigures"))
local NationalsScenes = require(script.Parent:WaitForChild("NationalsScenes"))
local CelebrationService = require(script.Parent:WaitForChild("CelebrationService"))
local PlayerDataFolder = ServerFolder:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))
local GearService = require(ServerFolder:WaitForChild("Economy"):WaitForChild("GearService"))
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))
local GainNews = require(PlayerDataFolder:WaitForChild("GainNews"))
local RankService = require(PlayerDataFolder:WaitForChild("RankService"))
-- Modules this file uses in only one place, in one table: the main chunk is at Luau's 200-local limit (each top-level
-- `local` that holds a value takes one of 200 slots; a table entry takes none).
local Once = {
	ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig")),
	CheerConfig = require(ConfigFolder:WaitForChild("CheerConfig")),
	EmoteConfig = require(ConfigFolder:WaitForChild("EmoteConfig")),
	QuestService = require(PlayerDataFolder:WaitForChild("QuestService")),
}
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))
local TrainingStationService = require(ServerFolder:WaitForChild("Training"):WaitForChild("TrainingStationService"))
local CardioMachineService = require(ServerFolder:WaitForChild("World"):WaitForChild("CardioMachineService"))

local LocalMeetService = {}

-- Marks other systems put on a character: a cardio rider or a lifter posed at a rack cannot go.
local BUSY_ATTRIBUTES = { "CardioMachine", "StationPose" }
-- The Mock Meet's room attribute: a player in their private room is not in the gym.
local MOCK_MEET_ATTRIBUTE = "MockMeetSlot"
local MAX_TRIGGER_DISTANCE = LocalMeetConfig.PromptDistanceStuds + 4
local STREAM_TIMEOUT_SECONDS = 5
local POLL_SECONDS = 0.1
-- The coach's cutscene: how long after the player is moved it starts, and how long it waits for them to be alive.
local DROP_SCENE_SETTLE_SECONDS = 1
local DROP_SCENE_WAIT_SECONDS = 10
local LIFT_TIMEOUT_SECONDS = LiftAttemptConfig.MaxAttemptSeconds + 5
local PASSED = "Passed"

type Body = { character: Model, root: BasePart, humanoid: Humanoid }
type LiftRecord = { history: AttemptRules.AttemptHistory, passed: number }

-- A player in the venue.
type Visit = {
	character: Model,
	-- Where they stood in the gym; exiting puts them back there.
	returnTo: CFrame,
	connections: { RBXScriptConnection },
	-- The hall they are in (its index).
	hall: number,
}

type Lifter = {
	-- The hall of their meet.
	hall: Hall,
	-- Nil for a computer lifter (§37.2), which has `cpu` instead.
	player: Player?,
	-- The standings' key: the player's UserId, or a negative number for a computer lifter.
	key: number,
	cpu: ComputerLifters.Plan?,
	-- A computer lifter's body on the platform.
	body: Model?,
	name: string,
	platform: LocalMeetVenue.Platform,
	order: number,
	-- Locked at the weigh-in.
	bodyweightKg: number,
	classLabel: string,
	competitionNumber: { [string]: number },
	lifts: { [string]: LiftRecord },
	withdrawn: boolean,
	-- This round: what the client last asked for (cleared when read), the accepted weight, the default.
	choice: number?,
	chosenKg: number?,
	defaultKg: number?,
	readyPressed: boolean,
	roundDone: boolean,
	lights: { string }?,
	-- The lift of the round being lifted (for the big screen's "going for a new CN").
	currentLift: string?,
	-- For the big screen's fun facts, read at the weigh-in: the class's best Total, the Local wins and whether
	-- they have qualified for State in this class this season.
	bestTotalKg: number?,
	localWins: number,
	stateQualified: boolean,
	-- Their top-3 State placings toward Nationals in this class, and whether they hold its Nationals spot (GAME_DESIGN
	-- §36.4 "The Nationals spot"), read at the weigh-in and updated when this meet is saved.
	nationalsPlacings: number,
	nationalsQualified: boolean,
	-- A placing toward Nationals counted at this meet, for the card at the awards (nil = none).
	nationalsNews: LocalMeetRemotes.NationalsNews?,
	-- Their meet titles (career.titles, GAME_DESIGN §35.8): id -> count.
	titles: { [string]: number },
	-- Their numbered State Champion badges, newest first (GAME_DESIGN §36.4; number 0 = on its way), the one won at
	-- this meet included once it is saved.
	championBadges: { ProfileOperations.ChampionBadgeView },
	-- The State Champion badge won at this meet, for the awards ceremony's reveal (nil = none).
	newBadge: ProfileOperations.ChampionBadgeView?,
	-- Gym records set at this meet ("Squat", "Total", ...), first on the big screen's facts.
	gymRecords: { string },
	-- What the big screen last showed (redrawn when a gym record comes back from the save).
	boardLines: { string }?,
	boardMood: ("good" | "bad")?,
	-- The weight of this round already announced as a record attempt (said once).
	announcedKg: number?,
	-- While this round's weight would beat a record: the big screen's GYM RECORD ATTEMPT sign.
	recordAttempt: { title: string, detail: string }?,
	-- Lifts actually started (LIFT pressed and the minigames ran): one makes the lifter count toward the prize pot.
	liftsStarted: number,
	-- Coins paid to this lifter at this meet (gym record bonuses during it, the rest at the end).
	coinsEarned: number,
	-- This meet's gym record bonus has been paid (once a meet, GAME_DESIGN §41.4).
	recordPaid: boolean?,
	-- The last attempt's result and weight, for the other lifters' coaches ("Tess missed 30 kg!").
	lastResult: string?,
	-- A miss: how long its fail animation lasts (the walk back starts right after it, user 2026-11-15).
	failSeconds: number?,
	lastKg: number?,
	-- On the walk out to the platform or back (GAME_DESIGN §37.5); a new walk bumps the token and ends the old one.
	walking: boolean?,
	-- A computer lifter's walk style for this meet (EntranceConfig id, picked at random); a player's is read from their save.
	entranceId: string?,
	-- How long their walk out may take this turn (their walk style's speed, plus the hype move): the lift waits this long.
	walkOutSeconds: number?,
	walkToken: number?,
	-- The lift being animated on the platform (MeetLiftAnimation, §37.5).
	liftAnim: MeetLiftAnimation.Handle?,
	-- A player's running minigame phase (1 or 2), while it runs: its live progress moves the lift (§37.5).
	livePhase: number?,
	-- When their last progress update came (at most one per PROGRESS_MIN_GAP_SECONDS is used).
	progressAt: number?,
	-- From the walk out until they are back in the warm-up room: the next round waits for it.
	outOnPlatform: boolean?,
	-- Stops the crowd yelling them on (crowdBehind), while it does.
	stopCrowd: (() -> ())?,
	-- How much hangs on their current attempt (LocalMeetConfig.StakesBuild), and what, in a few words.
	stakesLevel: number?,
	stakesLine: string?,
	-- A good lift's big moment ("NEW GYM RECORD!", "TAKES THE LEAD!"...), shown until their next turn (the State cube).
	moment: string?,
	-- Chalking up while they choose (LocalMeetConfig.Chalk): their animation and their coach's; a new walk of the
	-- coach's bumps the token and ends the old one.
	chalkTrack: AnimationTrack?,
	coachTrack: AnimationTrack?,
	coachToken: number?,
	-- What the coach has to say, and whether they have reached the lifter to say it (see coachTell).
	coachLine: string?,
	coachHere: boolean?,
	-- A rare suit won at this meet: the coach's cutscene plays once the awards are over.
	droppedSuit: string?,
	droppedPiece: string?,
	-- The State meet: their seat on their rack's benches, and whether they have the rack's big screen (it's their turn).
	seat: Seat?,
	onScreen: boolean?,
	-- It's their turn: they can't practise.
	onTurn: boolean?,
	-- A computer lifter standing on the podium (its emotes go on there: runComputerEmotes).
	onPodium: boolean?,
	-- A Nationals lift-off (GAME_DESIGN §39): picking its lift now, the lift picked, and an attempt in it under way (it
	-- saves nothing: no history, best or record).
	liftOffChoosing: boolean?,
	liftOffPick: string?,
	liftOffRound: boolean?,
}

type Meet = {
	-- The hall it is held in.
	hall: Hall,
	lifters: { Lifter },
	byPlayer: { [Player]: Lifter },
	heading: string,
	final: boolean,
	-- Whether it started with enough REAL players to pay in full (RewardMinimumLifters).
	rewards: boolean,
	-- One real player and computer lifters, not paying in full: the reduced rewards (§37.2).
	solo: boolean,
	-- Each real lifter's place among the real lifters only (key -> place): what rewards go by (§37.2).
	rewardPlaces: { [number]: number },
	-- Its level (MeetLevelConfig, GAME_DESIGN §35.8): "Local", "Regional" or "State".
	level: string,
	-- The final placing, by UserId (set when the meet ends).
	places: { [number]: MeetPlacing.Placing },
	-- Nationals: each lift-off lifter's finish in it (key -> 1 = won), which breaks their tie (GAME_DESIGN §39).
	liftOff: { [number]: number },
	-- Nationals only (user 2026-11-18, "Everyone on points"): some weight class has only one lifter, so the whole meet is
	-- placed together by GL points instead of class by class on total.
	pointsMode: boolean?,
}

-- One of the five meets: its hall, sign-up list, running meet and timetable.
type Hall = {
	index: number,
	venue: LocalMeetVenue.Venue,
	signUps: { Player },
	meet: Meet?,
	nextStartAt: number,
	-- Its next meet's level, rolled when its sign-ups open (GAME_DESIGN §35.8).
	nextLevel: string,
	-- The start its signed-up lifters were last told about (CallSeconds before it).
	calledFor: number?,
	-- The State arena (GAME_DESIGN §36.4), not one of the five halls: its own timetable, qualified lifters only, no computer
	-- lifters, one lifter at a time.
	state: boolean,
	-- The Nationals hall (GAME_DESIGN §39; also `state`, as it runs the same way: racks on their own, turns, benches): no
	-- timetable (NationalsService starts its meet), placed per weight class, its own walk-out from behind the curtain.
	nationals: boolean,
}

-- Filled when the venue is built; empty until then.
local halls: { Hall } = {}
-- The warm-up rooms' working racks, every hall's (made once the venue is built).
local warmUp: LocalMeetWarmUp.WarmUp? = nil
local remotes: LocalMeetRemotes.RemoteSet? = nil
local started = false

local visits: { [Player]: Visit } = {}
local entering: { [Player]: boolean } = {}
local levelRandom = Random.new()
-- Computer lifters' strength, attempts and makes (§37.2).
local cpuRandom = Random.new()
local suitRandom = Random.new()
-- The State arena, once built, and its warm-up racks.
local stateArena: StateArenaVenue.Venue? = nil
local stateRackSet: { [LocalMeetVenue.WarmUpRack]: boolean } = {}
local lastPress: { [Player]: number } = {}
-- The Nationals hall (setNationalsVenue): not in `halls` (no timetable, no MEETS row, no SPECTATE), but a hall like the
-- others for visits, sounds, standings and its meet. Its number is out of the halls' range.
local NATIONALS_HALL_INDEX = 99
local nationalsHall: Hall? = nil
-- Where leaving the Nationals hall lands a player (outside the porch), and what the arena wants to hear.
local nationalsOutside: CFrame? = nil
export type NationalsHooks = {
	-- A player left the hall (EXIT, death, leaving the game, the meet screen's EXIT).
	onLeft: (player: Player) -> (),
	-- Off the hall's own warm-up racks (a lifter called up, the meet starting).
	stopWarmUp: (player: Player) -> (),
	-- The crowd's chant for platform `rack`'s lifter, building while they wait behind the curtain until their lift's
	-- result (nil: their lift is over). `forFirst`: making it wins them their class.
	chant: (rack: number, lift: string?, forFirst: boolean?) -> (),
	-- The lifter behind platform `rack`'s curtain (their name and class), or nobody: the platform's screens say who is up.
	behindCurtain: (rack: number, name: string?, classLabel: string?) -> (),
}
local nationalsHooks: NationalsHooks? = nil
-- Told when the Nationals meet is over (NationalsService), with each lifter's class place (UserId -> place or nil).
local nationalsOnFinished: ((places: { [number]: number? }) -> ())? = nil
-- A Nationals lifter waiting behind the curtain clicks to step out within this long, or steps out anyway.
local CURTAIN_WAIT_SECONDS = 30
-- When each player's screen said the Nationals hall had finished arriving on it (os.clock; the "HallReady" message),
-- for the opening; forgotten when they leave the hall.
local hallReadyAt: { [Player]: number } = {}

local function log(message: string, ...: any)
	print("[LocalMeetService] " .. string.format(message, ...))
end

-- Off any warm-up rack: the five halls' and the State arena's, and the Nationals hall's own.
local function stopWarmUps(player: Player)
	if warmUp then
		warmUp.stop(player, false)
	end
	local hooks = nationalsHooks
	if hooks then
		hooks.stopWarmUp(player)
	end
end

local function notify(player: Player, message: string)
	if remotes and player.Parent then
		remotes.notice:FireClient(player, message)
	end
end

local function cycleSeconds(hall: Hall?): number
	if hall and hall.state then
		return if RunService:IsStudio() then StateArenaConfig.StudioCycleSeconds else StateArenaConfig.CycleSeconds
	end
	return if RunService:IsStudio() then LocalMeetConfig.StudioCycleSeconds else LocalMeetConfig.CycleSeconds
end

local function closesSeconds(hall: Hall?): number
	if hall and hall.state then
		return if RunService:IsStudio() then StateArenaConfig.StudioSignUpClosesSeconds else StateArenaConfig.SignUpClosesSeconds
	end
	return if RunService:IsStudio() then LocalMeetConfig.StudioSignUpClosesSeconds else LocalMeetConfig.SignUpClosesSeconds
end

local function minimumLifters(hall: Hall?): number
	if hall and hall.state then
		return if RunService:IsStudio() then StateArenaConfig.StudioMinimumLifters else StateArenaConfig.MinimumLifters
	end
	return if RunService:IsStudio() then LocalMeetConfig.StudioMinimumLifters else LocalMeetConfig.MinimumLifters
end

local function maximumLifters(hall: Hall): number
	return if hall.state then StateArenaConfig.MaxRacks * StateArenaConfig.LiftersPerRack else LocalMeetConfig.MaxLifters
end

-- How a message names a meet.
local function meetName(hall: Hall): string
	return if hall.nationals then "Nationals" elseif hall.state then "the State meet" else "meet " .. hall.index
end

local function rewardMinimumLifters(): number
	return if RunService:IsStudio() then LocalMeetConfig.StudioRewardMinimumLifters
		else LocalMeetConfig.RewardMinimumLifters
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- A hall's next timetable start after `time`: the five halls are evenly staggered through the cycle.
local function startAfter(time: number, hall: Hall): number
	local cycle = cycleSeconds(hall)
	-- The State meet is on no fixed clock: the next one is a full wait after this moment (user 2026-11-06).
	if hall.state then
		return time + cycle
	end
	local offset = (hall.index - 1) * cycle / LocalMeetConfig.HallCount
	return (math.floor((time - offset) / cycle) + 1) * cycle + offset
end

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

local function clockText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function placeText(place: number): string
	local suffix = "th"
	if place % 100 < 11 or place % 100 > 13 then
		suffix = if place % 10 == 1 then "st" elseif place % 10 == 2 then "nd" elseif place % 10 == 3 then "rd" else "th"
	end
	return string.format("%d%s", place, suffix)
end

local function bodyOf(player: Player): Body?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil
	end
	return { character = character, root = root, humanoid = humanoid }
end

-- Height of the root part's centre above the floor when the character stands.
local function standingHeight(body: Body): number
	if body.humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 3
	end
	return body.humanoid.HipHeight + body.root.Size.Y / 2
end

local function standAt(player: Player, spot: CFrame, anchored: boolean)
	local body = bodyOf(player)
	local visit = visits[player]
	if body == nil or visit == nil or body.character ~= visit.character or body.humanoid.Health <= 0 then
		return
	end
	body.root.Anchored = anchored
	body.character:PivotTo(spot * CFrame.new(0, standingHeight(body), 0))
end

local function release(player: Player)
	local body = bodyOf(player)
	if body then
		body.root.Anchored = false
	end
end

-- The hall whose list the player is on, if any (one at a time).
local function signedUpAt(player: Player): Hall?
	for _, hall in ipairs(halls) do
		if table.find(hall.signUps, player) then
			return hall
		end
	end
	return nil
end

local function removeSignUp(player: Player)
	local hall = signedUpAt(player)
	if hall then
		table.remove(hall.signUps, table.find(hall.signUps, player) :: number)
	end
end

-- The meet the player is lifting in right now and their place in it, if any (one at a time).
local function activeLifter(player: Player): (Meet?, Lifter?)
	for _, hall in ipairs(halls) do
		local current = hall.meet
		local lifter = current and current.byPlayer[player]
		if lifter and not lifter.withdrawn then
			return current, lifter
		end
	end
	local nationals = nationalsHall
	local current = nationals and nationals.meet
	local lifter = current and current.byPlayer[player]
	if current and lifter and not lifter.withdrawn then
		return current, lifter
	end
	return nil, nil
end

-- ---------------------------------------------------------------- what the venue sees

-- How far a meet could raise each lift's CN for the player's current class right now, in percent.
local function allowancePercent(player: Player): { [string]: number }
	local percent: { [string]: number } = {}
	local data = PlayerDataService.getData(player)
	local classKey = data and ProfileOperations.getActiveClassKey(data)
	if data == nil or classKey == nil then
		return percent
	end
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local share = ProfileOperations.getMeetAllowanceShare(data, classKey, lift, os.time())
		if share then
			percent[lift] = share * 100
		end
	end
	return percent
end

-- Whether a player may lift at the State meet in their class today, and how far off they are (GAME_DESIGN §36.3).
local function stateLadder(player: Player): (boolean, string?)
	if RunService:IsStudio() and Workspace:GetAttribute("StudioStateNeedsQualifying") ~= true then
		return true, nil
	end
	local data = PlayerDataService.getData(player)
	local classKey = data and ProfileOperations.getActiveClassKey(data)
	if data == nil or classKey == nil then
		return false, "Your data is still loading."
	end
	local ladder = ProfileOperations.getLadder(data, classKey, os.time())
	if ladder.qualified then
		return true, nil
	end
	return false, string.format("LADDER %d/%d IN %s", ladder.points, ladder.target, classKey)
end

--[[
	The entrance buildings' floating signs (user 2026-11-18: "put the timers for the meets like nationals, for local meet
	building ... make the meet timer stack up, like meet 1 - 8 timer and if there is a regional meet you can change it"):
	the Local meet building lists every meet, one line each, "MEET 1  ·  1:23" (white), "MEET 2  ·  REGIONAL  ·  0:45"
	(yellow) or "MEET 3  ·  LIFTING NOW"; the State arena says when its next State meet starts. Written as the timetable
	ticks (only changed text goes out).
]]
local SIGN_WHITE, SIGN_YELLOW, SIGN_GREEN = Color3.fromRGB(248, 248, 244), Color3.fromRGB(250, 206, 36),
	Color3.fromRGB(90, 220, 120)

local function clockFor(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function refreshEntranceSigns()
	local lines: { string } = {}
	local colours: { Color3 } = {}
	local t = now()
	for _, hall in ipairs(halls) do
		if hall.nationals then
			continue
		end
		local level = MeetLevelConfig.Levels[hall.nextLevel]
		local levelWord = if level then (string.gsub(level.label, " MEET$", "")) else ""
		if hall.state then
			StateArenaVenue.setEntranceLines({ "State Championship",
				if hall.meet then "State meet LIFTING NOW" else "Next State meet in " .. clockFor(hall.nextStartAt - t) })
		elseif hall.meet then
			table.insert(lines, string.format("MEET %d  ·  LIFTING NOW", hall.index))
			table.insert(colours, SIGN_GREEN)
		elseif hall.nextLevel ~= "Local" then
			table.insert(lines, string.format("MEET %d  ·  %s  ·  %s", hall.index, levelWord, clockFor(hall.nextStartAt - t)))
			table.insert(colours, SIGN_YELLOW)
		else
			table.insert(lines, string.format("MEET %d  ·  %s", hall.index, clockFor(hall.nextStartAt - t)))
			table.insert(colours, SIGN_WHITE)
		end
	end
	if #lines > 0 then
		LocalMeetVenue.setEntranceLines(lines, colours)
	end
end

local function sendLobby(player: Player)
	if remotes == nil then
		return
	end
	-- From anywhere in the game: the MEETS tab shows this too (user 2026-11-06).
	local visit = visits[player]
	local mine = signedUpAt(player)
	local meets: { LocalMeetRemotes.MeetRow } = {}
	for _, hall in ipairs(halls) do
		local level = MeetLevelConfig.Levels[hall.nextLevel]
		table.insert(meets, {
			index = hall.index,
			nextStartAt = hall.nextStartAt,
			signUpClosesAt = hall.nextStartAt - closesSeconds(hall),
			signedUpCount = #hall.signUps,
			signedUp = mine == hall,
			running = hall.meet ~= nil,
			levelLabel = level.label,
			potMultiplier = level.potMultiplier,
			titles = level.titles,
			state = hall.state,
			maxLifters = maximumLifters(hall),
			notQualified = if hall.state then select(2, stateLadder(player)) else nil,
		})
	end
	local state: LocalMeetRemotes.LobbyState = {
		meets = meets,
		hereIndex = if visit then visit.hall else nil,
		allowancePercent = allowancePercent(player),
		minimumLifters = minimumLifters(),
		maxLifters = LocalMeetConfig.MaxLifters,
	}
	remotes.lobby:FireClient(player, state)
end

local function broadcastLobby()
	for _, player in ipairs(Players:GetPlayers()) do
		sendLobby(player)
	end
end

-- What a level pays, for its boards ("Coins x3", "Top 3 earn titles").
local function perksOf(level: string): { string }
	local info = MeetLevelConfig.Levels[level]
	if info.potMultiplier <= 1 then
		return { "Everyone lifts together", "Most points win" }
	end
	return { string.format("Coins x%d", info.potMultiplier), if info.titles then "Top 3 earn titles" else "" }
end

--[[
	Rolls a hall's next meet's level as its sign-ups open (GAME_DESIGN §35.8) and
	shows it on the hall's boards. A Regional or State meet is announced to
	everyone in the server. In Studio, the workspace attribute
	"ForceMeetLevel" ("Local", "Regional" or "State") picks the level, for
	testing.
]]
local function rollLevel(hall: Hall)
	if hall.state then
		-- Always State, with nothing to announce: it comes round on its own timetable.
		hall.nextLevel = "State"
		LocalMeetVenue.setLevel(hall.venue, MeetLevelConfig.Levels.State.label, perksOf("State"), hall.index)
		return
	end
	local forced = if RunService:IsStudio() then Workspace:GetAttribute("ForceMeetLevel") else nil
	hall.nextLevel = if typeof(forced) == "string" and MeetLevelConfig.Levels[forced] then forced
		else MeetLevelConfig.roll(levelRandom:NextNumber())
	local info = MeetLevelConfig.Levels[hall.nextLevel]
	LocalMeetVenue.setLevel(hall.venue, info.label, perksOf(hall.nextLevel), hall.index)
	if hall.nextLevel ~= "Local" then
		log("meet %d's next is a %s (coins x%d)", hall.index, info.label, info.potMultiplier)
		if remotes then
			local news: LocalMeetRemotes.LevelNews = {
				hallIndex = hall.index,
				levelLabel = info.label,
				potMultiplier = info.potMultiplier,
				startsAt = hall.nextStartAt,
				signUpClosesAt = hall.nextStartAt - closesSeconds(hall),
			}
			remotes.levelNews:FireAllClients(news)
		end
	end
end

local function attemptViews(lifter: Lifter): { [string]: { MockMeetRemotes.AttemptView } }
	local views: { [string]: { MockMeetRemotes.AttemptView } } = {}
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local record = lifter.lifts[lift]
		local list: { MockMeetRemotes.AttemptView } = {}
		for _, attempt in ipairs(record.history) do
			local result: string = attempt.result
			table.insert(list, { weightKg = attempt.weightKg, result = result })
		end
		for _ = 1, record.passed do
			table.insert(list, { weightKg = 0, result = PASSED })
		end
		views[lift] = list
	end
	return views
end

local function meetAttempts(lifter: Lifter): MeetTotal.MeetAttempts
	local all: MeetTotal.MeetAttempts = {}
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		all[lift] = lifter.lifts[lift].history
	end
	return all
end

-- How many good lifts the lifter has made so far (9 = 9/9): the first tie-break in the ranking.
local function goodLiftCount(lifter: Lifter): number
	local good = 0
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		for _, attempt in ipairs(lifter.lifts[lift].history) do
			if attempt.result == "GoodLift" then
				good += 1
			end
		end
	end
	return good
end

-- True when a lift has no attempts left and no good one: the lifter has no total any more.
local function bombed(lifter: Lifter): boolean
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local record = lifter.lifts[lift]
		if #record.history + record.passed >= MeetConfig.AttemptsPerLift and MeetTotal.bestSuccessful(record.history) == nil then
			return true
		end
	end
	return false
end

local function sendState(lifter: Lifter, phase: string, extra: { [string]: any }?)
	local player = lifter.player
	if remotes == nil or lifter.withdrawn or player == nil or player.Parent == nil then
		return
	end
	local state: { [string]: any } = {
		phase = phase,
		bodyweightKg = lifter.bodyweightKg,
		classLabel = lifter.classLabel,
		competitionNumber = lifter.competitionNumber,
		attempts = attemptViews(lifter),
		-- The screen's title: which level this meet is.
		meetTitle = if lifter.hall.meet then MeetLevelConfig.Levels[(lifter.hall.meet :: Meet).level].label else nil,
	}
	if extra then
		for key, value in pairs(extra) do
			state[key] = value
		end
	end
	remotes.state:FireClient(player, state)
end

-- The standings: everyone's bests, subtotal, live (or final) score and place, best first.
-- Who a Nationals lifter is placed against (GAME_DESIGN §39): their weight class, or everyone together on points when some
-- class has only one lifter (Meet.pointsMode, user 2026-11-18). Elsewhere everyone is one group anyway.
local POINTS_GROUP = "ALL CLASSES"
local function groupOf(current: Meet, lifter: Lifter): string
	return if current.pointsMode then POINTS_GROUP else lifter.classLabel
end

-- The weight classes in order, lightest first ("59 kg" ... "120+ kg").
local function classOrder(a: string, b: string): boolean
	local aKg, bKg = tonumber(string.match(a, "^%d+")) or 0, tonumber(string.match(b, "^%d+")) or 0
	if aKg ~= bKg then
		return aKg < bKg
	end
	return a < b
end

--[[
	Ranks a meet's entries: one ranking by GL points (MeetPlacing.rank), or at Nationals each weight class by its total
	(MeetPlacing.rankByTotal, its lift-offs breaking ties; GAME_DESIGN §39), the classes lightest first, each with its own
	places 1, 2, 3...
]]
local function rankFor(current: Meet, entries: { MeetPlacing.Entry }): { MeetPlacing.Placing }
	-- (A Nationals with a weight class of one is placed on points too, everyone together: Meet.pointsMode.)
	if not current.hall.nationals or current.pointsMode then
		return MeetPlacing.rank(entries)
	end
	local classOf: { [number]: string } = {}
	for _, lifter in ipairs(current.lifters) do
		classOf[lifter.key] = lifter.classLabel
	end
	local byClass: { [string]: { MeetPlacing.Entry } } = {}
	local classes: { string } = {}
	for _, entry in ipairs(entries) do
		local label = classOf[entry.key] or "?"
		if byClass[label] == nil then
			byClass[label] = {}
			table.insert(classes, label)
		end
		table.insert(byClass[label], entry)
	end
	table.sort(classes, classOrder)
	local placings: { MeetPlacing.Placing } = {}
	for _, label in ipairs(classes) do
		for _, placing in ipairs(MeetPlacing.rankByTotal(byClass[label], current.liftOff)) do
			table.insert(placings, placing)
		end
	end
	return placings
end

local function buildStandings(current: Meet): LocalMeetRemotes.Standings
	local entries: { MeetPlacing.Entry } = {}
	local rowsByKey: { [number]: LocalMeetRemotes.StandingRow } = {}
	for _, lifter in ipairs(current.lifters) do
		local result = MeetTotal.resolve(meetAttempts(lifter))
		local subtotal = 0
		for _, kg in pairs(result.best) do
			subtotal += kg
		end
		local out = lifter.withdrawn or bombed(lifter)
		local status = if lifter.withdrawn then "Withdrawn" elseif bombed(lifter) then "Bombed"
			elseif current.final then "Done" else "Lifting"
		-- Live: rank by the subtotal so far; final: by the total (nil for a bomb-out).
		local rankKg: number? = if out then nil elseif current.final then result.total elseif subtotal > 0 then subtotal else nil
		table.insert(entries, { key = lifter.key, bodyweightKg = lifter.bodyweightKg,
			totalKg = rankKg, goodLifts = goodLiftCount(lifter), order = lifter.order })
		rowsByKey[lifter.key] = {
			name = lifter.name,
			platform = lifter.platform.index,
			classLabel = lifter.classLabel,
			bodyweightKg = lifter.bodyweightKg,
			best = result.best,
			subtotalKg = subtotal,
			points = nil,
			userId = if lifter.player then lifter.player.UserId else nil,
			place = nil,
			status = status,
			lights = lifter.lights,
		}
	end
	local rows: { LocalMeetRemotes.StandingRow } = {}
	for _, placing in ipairs(rankFor(current, entries)) do
		local row = rowsByKey[placing.key]
		row.points = placing.points
		row.place = placing.place
		table.insert(rows, row)
	end
	return { meetIndex = if current.hall.state then nil else current.hall.index,
		heading = if current.hall.nationals then "NATIONALS  ·  " .. current.heading
			elseif current.hall.state then "STATE  ·  " .. current.heading else current.heading, final = current.final, rows = rows }
end

-- Sends the standings to everyone in the meet's hall and writes them on its scoreboard.
local function updateStandings(current: Meet)
	local standings = buildStandings(current)
	if remotes then
		for player, visit in pairs(visits) do
			if visit.hall == current.hall.index then
				remotes.standings:FireClient(player, standings)
			end
		end
	end
	local lines: { string } = {}
	for _, row in ipairs(standings.rows) do
		table.insert(lines, string.format("%s  %s  ·  %s  ·  %s kg%s",
			if row.place then placeText(row.place) else "—", row.name, row.classLabel, kgText(row.subtotalKg),
			if row.points then string.format("  ·  %.2f PTS", row.points)
				elseif row.status == "Bombed" then "  ·  BOMBED OUT"
				elseif row.status == "Withdrawn" then "  ·  WITHDRAWN" else ""))
	end
	LocalMeetVenue.setScoreboard(current.hall.venue, if standings.final then "FINAL STANDINGS" else standings.heading, lines)
end

-- ---------------------------------------------------------------- what the meet saves (step 2)

--[[
	Saves one lifter's meet in ONE write (see the header): Competition Scale and
	best Total when `totalKg` is set; the CN settlement, and a win for 1st place,
	when the meet rewards. `totalKg` nil = no total (a bomb-out, or withdrawn):
	nothing is raised and only the misses above CN use the meet allowance.
	`place` is the lifter's place among the REAL lifters (§37.2). A meet with
	one real player (`current.solo`) settles CN at full speed and pays only the
	finishing ladder points: no win, title, or place points. A computer lifter
	saves nothing. Returns short lines for the lifter's result screen.
]]
local function saveLifter(current: Meet, lifter: Lifter, totalKg: number?, best: { [string]: number },
	place: number?): { string }
	local lines: { string } = {}
	local player = lifter.player
	-- CN is settled in full meets and in a meet with one real player (§37.1; full speed since 2026-11-19).
	local settlesCn = current.rewards or current.solo
	if player == nil or (totalKg == nil and not settlesCn) then
		return lines
	end
	local cnCost = if current.rewards then 1 else Once.ProgressionConfig.MeetCnAllowance.SoloCostMultiplier
	local nowUnix = os.time()
	local scaleOutcomes: { [string]: ProfileOperations.ScaleRaiseOutcome } = {}
	-- How much each lift's Competition Scale rose (for the gain display, GAME_DESIGN §40.1).
	local scaleGained: { [string]: number } = {}
	-- Today's coach quests this meet moved (GAME_DESIGN §40.6).
	local questProgress: { ProfileOperations.QuestProgress } = {}
	local cnOutcomes: { [string]: string } = {}
	local cnAfter: { [string]: number } = {}
	local totalOutcome: ProfileOperations.ScaleRaiseOutcome? = nil
	local wins: number? = nil
	-- A Regional or State meet's top 3 earn a title (GAME_DESIGN §35.8).
	local titleId = if current.rewards and totalKg then MeetLevelConfig.titleFor(current.level, place) else nil
	local titleCount: number? = nil
	-- Ladder points toward State, in the weigh-in class, for finishing an official meet (GAME_DESIGN §35.8, §36.3),
	-- with a bonus for a perfect meet (every attempt a good lift).
	local perfect = goodLiftCount(lifter) == #MeetConfig.LiftOrder * MeetConfig.AttemptsPerLift
	-- A meet with one real player: the finishing points only (§37.2).
	local ladderPoints = if current.rewards and totalKg then MeetLevelConfig.ladderPointsFor(current.level, place, perfect)
		elseif current.solo and totalKg then MeetLevelConfig.ladderPointsFor(current.level, nil, false)
		else 0
	if current.solo then
		perfect = false -- no 9/9 ladder bonus to mention
	end
	local perfectNote = if perfect then " (9/9 bonus)" else ""
	-- A win that counts (1st place among the real lifters, in a meet that pays in full) earns the level's Roblox badge,
	-- and at State the numbered State Champion badge for this season (GAME_DESIGN §36.4).
	local wonIt = current.rewards and totalKg ~= nil and place == 1
	local championSeason = if wonIt and current.level == "State" then MeetLevelConfig.seasonFor(nowUnix) else nil
	local badgeOutcome: ProfileOperations.ChampionBadgeOutcome? = nil
	-- A top-3 place at a State meet that pays in full is a placing toward Nationals, but never for more than half the
	-- lifters in the meet (GAME_DESIGN §36.4 "The Nationals spot", MeetLevelConfig.Nationals).
	local fieldSize = 0
	for _, other in ipairs(current.lifters) do
		if other.player then
			fieldSize += 1
		end
	end
	local stateTop3 = current.rewards and current.level == "State" and totalKg ~= nil and place ~= nil
		and place <= MeetLevelConfig.Nationals.TopPlaces
	local nationalsCounts = stateTop3 and (place :: number) <= MeetLevelConfig.nationalsPlaces(fieldSize)
	local nationalsOutcome: ProfileOperations.NationalsOutcome? = nil
	local nationals: ProfileOperations.NationalsView? = nil
	local ladderOutcome: ProfileOperations.LadderOutcome? = nil
	local ladder: ProfileOperations.LadderView? = nil
	-- A National Champion (1st in their class at Nationals, GAME_DESIGN §39) earns that class's Worlds spot.
	local worldsOutcome: ProfileOperations.WorldsOutcome? = nil
	local earnsWorlds = wonIt and current.level == "Nationals"
	-- RANKS AND TITLES (GAME_DESIGN §41): every real meet finished with a total (computer lifters too, never the Mock
	-- Meet) scores the total in GL points for the lifter's rank, and checks the feat titles.
	local rankMeet: ProfileOperations.RankMeet? = nil
	if totalKg then
		local clutch = false
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			local history = lifter.lifts[lift].history
			if #history >= 3 and history[1].result ~= "GoodLift" and history[2].result ~= "GoodLift"
				and history[3].result == "GoodLift" then
				clutch = true
			end
		end
		rankMeet = {
			points = MeetPlacing.points(lifter.bodyweightKg, totalKg) or 0,
			totalKg = totalKg,
			bodyweightKg = lifter.bodyweightKg,
			classLabel = lifter.classLabel,
			bestByLift = best,
			perfect = goodLiftCount(lifter) == #MeetConfig.LiftOrder * MeetConfig.AttemptsPerLift,
			clutch = clutch,
			gymRecord = #lifter.gymRecords > 0,
		}
	end
	local rankResult: ProfileOperations.RankMeetResult? = nil
	local saved = PlayerDataService.update(player, function(data)
		if totalKg then
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				-- (A lift over the normal limit counts for the total, not for Scale, §37.5.)
				local kg = if best[lift]
					then AttemptChoice.bestWithinLimit(lifter.competitionNumber[lift], lifter.lifts[lift].history)
					else nil
				if kg then
					local scaleBefore = ProfileOperations.getCompetitionScale(data, lift, lifter.classLabel) or 0
					local scaleOutcome, scaleNow = ProfileOperations.raiseCompetitionScale(data, lifter.classLabel, lift, kg)
					scaleOutcomes[lift] = scaleOutcome
					if scaleOutcome == "Raised" and scaleNow then
						scaleGained[lift] = scaleNow - scaleBefore
					end
				end
			end
			totalOutcome = ProfileOperations.raiseBestTotal(data, lifter.classLabel, totalKg)
			if rankMeet then
				rankResult = ProfileOperations.recordRankMeet(data, rankMeet, nowUnix)
			end
		end
		if settlesCn then
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				local outcome, cnKg = ProfileOperations.settleMeetCompetitionNumber(data, lifter.classLabel, lift,
					lifter.competitionNumber[lift], lifter.lifts[lift].history, totalKg ~= nil, nowUnix, cnCost)
				cnOutcomes[lift] = outcome
				if cnKg then
					cnAfter[lift] = cnKg
				end
			end
			-- The coaches' daily quests (GAME_DESIGN §40.6): this meet's good lifts count, only with a total (a bomb-out
			-- saves nothing), after the meet's own strength raise.
			if totalKg then
				local goodByLift: { [string]: number } = {}
				for _, lift in ipairs(MeetConfig.LiftOrder) do
					local good = 0
					for _, attempt in ipairs(lifter.lifts[lift].history) do
						if attempt.result == "GoodLift" then
							good += 1
						end
					end
					goodByLift[lift] = good
				end
				questProgress = ProfileOperations.addQuestGoodLifts(data, lifter.classLabel, goodByLift, nowUnix)
			end
		end
		if current.rewards then
			if totalKg and place == 1 then
				wins = ProfileOperations.addLocalWin(data)
			end
			if titleId then
				titleCount = ProfileOperations.addTitle(data, titleId)
			end
			if championSeason then
				-- Its number comes from the game-wide counter just after this save (ChampionBadges.numberPending).
				badgeOutcome = ProfileOperations.addStateChampionBadge(data, championSeason, 0)
			end
			if nationalsCounts then
				nationalsOutcome, nationals = ProfileOperations.addNationalsPlacing(data, lifter.classLabel, nowUnix)
			end
			if earnsWorlds then
				worldsOutcome = ProfileOperations.addWorldsSpot(data, lifter.classLabel, nowUnix)
			end
		end
		if ladderPoints > 0 then
			ladderOutcome, ladder = ProfileOperations.addLadderPoints(data, lifter.classLabel, ladderPoints, nowUnix)
		end
	end)
	if not saved then
		warn(string.format("[LocalMeetService] %s's meet result was not saved", player.Name))
		return { "Your result could not be saved." }
	end
	-- The gain display (GAME_DESIGN §40.1): the strength and Scale this meet really saved.
	local gains = {}
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		if cnOutcomes[lift] == "Raised" and cnAfter[lift] then
			table.insert(gains, GainNews.strength(lift, cnAfter[lift] - lifter.competitionNumber[lift]))
		end
	end
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		if scaleGained[lift] then
			table.insert(gains, GainNews.scale(lift, scaleGained[lift]))
		end
	end
	GainNews.send(player, "Meet", gains)
	-- The coaches' quests: finished ones pay strength (the gain display), and every step gets a line.
	local questGains = {}
	for _, step in ipairs(questProgress) do
		if step.finished and step.cnBefore and step.cnAfter then
			table.insert(questGains, GainNews.strength(step.lift, step.cnAfter - step.cnBefore))
		end
	end
	GainNews.send(player, "Quest", questGains)
	Once.QuestService.tell(player, questProgress)
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		if cnOutcomes[lift] == "Raised" and cnAfter[lift] then
			table.insert(lines, string.format("%s CN %.1f → %.1f kg", lift, lifter.competitionNumber[lift], cnAfter[lift]))
		end
		if scaleOutcomes[lift] == "Rejected" or cnOutcomes[lift] == "Rejected" then
			warn(string.format("[LocalMeetService] %s's %s (%s) was not fully saved: Scale %s, CN %s", player.Name, lift,
				lifter.classLabel, tostring(scaleOutcomes[lift]), tostring(cnOutcomes[lift])))
		end
	end
	if totalOutcome == "Raised" and totalKg then
		table.insert(lines, string.format("New best Total %s kg", kgText(totalKg)))
	end
	if titleId and titleCount then
		local title = MeetLevelConfig.Titles[titleId]
		-- At Nationals the class goes with it ("74 kg National Champion", §39), unless placed on points (no class).
		if current.level == "Nationals" and not current.pointsMode then
			title = lifter.classLabel .. " " .. title
		end
		table.insert(lines, if titleCount > 1 then string.format("%s x%d", title, titleCount) else "New title: " .. title)
		RankService.titleEarned(player, titleId)
	end
	if worldsOutcome == "Earned" then
		table.insert(lines, string.format("WORLDS SPOT EARNED (%s)!", lifter.classLabel))
	elseif worldsOutcome == "AlreadyHeld" then
		table.insert(lines, string.format("You already hold a Worlds spot (%s)", lifter.classLabel))
	elseif worldsOutcome == "Rejected" then
		warn(string.format("[LocalMeetService] %s's Worlds spot was not saved", player.Name))
	end
	if wonIt then
		ChampionBadges.awardWin(player, current.level)
	end
	if championSeason and badgeOutcome == "Added" then
		local number = ChampionBadges.numberPending(player)[championSeason]
		local badge = { season = championSeason, number = number or 0 }
		table.insert(lifter.championBadges, 1, badge)
		lifter.newBadge = badge
		table.insert(lines, if number
			then string.format("New badge: #%d %s · %s", number, MeetLevelConfig.ChampionBadge.Name,
				MeetLevelConfig.seasonLabel(championSeason))
			else string.format("New badge: %s · %s (your number is on its way)", MeetLevelConfig.ChampionBadge.Name,
				MeetLevelConfig.seasonLabel(championSeason)))
	elseif badgeOutcome == "AlreadyThisSeason" then
		table.insert(lines, "You already have this month's State Champion badge")
	elseif badgeOutcome == "Rejected" then
		warn(string.format("[LocalMeetService] %s's State Champion badge was not saved", player.Name))
	end
	if nationals and (nationalsOutcome == "Added" or nationalsOutcome == "Qualified") then
		lifter.nationalsPlacings, lifter.nationalsQualified = nationals.placings, nationals.qualified
		lifter.nationalsNews = { classLabel = lifter.classLabel, placings = nationals.placings, target = nationals.target,
			earned = nationalsOutcome == "Qualified" }
		table.insert(lines, if nationalsOutcome == "Qualified"
			then string.format("NATIONALS SPOT EARNED (%s)! %d / %d top-3 State placings", lifter.classLabel, nationals.placings,
				nationals.target)
			else string.format("Top 3 at State: %d / %d toward Nationals (%s)", nationals.placings, nationals.target,
				lifter.classLabel))
	elseif nationalsOutcome == "AlreadyQualified" then
		table.insert(lines, string.format("You already hold a Nationals spot (%s)", lifter.classLabel))
	elseif nationalsOutcome == "Rejected" then
		warn(string.format("[LocalMeetService] %s's Nationals placing was not saved", player.Name))
	elseif stateTop3 and not nationalsCounts and place then
		-- A top-3 place in a small field: say what it takes.
		local needs = MeetLevelConfig.nationalsFieldFor(place)
		if needs then
			table.insert(lines, string.format("%s place counts toward Nationals with %d+ lifters", placeText(place), needs))
		end
	end
	if ladder and ladderOutcome == "Qualified" then
		table.insert(lines, string.format("+%d ladder points%s: QUALIFIED FOR STATE (%s)!", ladderPoints, perfectNote,
			lifter.classLabel))
	elseif ladder and ladderOutcome == "Added" then
		table.insert(lines, string.format("+%d ladder points%s: %d / %d for State (%s)", ladderPoints, perfectNote,
			ladder.points, ladder.target, lifter.classLabel))
	elseif ladderOutcome == "AlreadyQualified" then
		table.insert(lines, string.format("Already qualified for State (%s) this season", lifter.classLabel))
	elseif ladderOutcome == "Rejected" then
		warn(string.format("[LocalMeetService] %s's ladder points were not saved", player.Name))
	end
	log("%s saved (%s, total %s, rewards %s, solo %s): CN S %s B %s D %s, best Total %s, wins %s, ladder +%d %s, nationals %s%s",
		player.Name, lifter.classLabel, if totalKg then kgText(totalKg) else "none", tostring(current.rewards),
		tostring(current.solo),
		tostring(cnOutcomes.Squat), tostring(cnOutcomes.Bench), tostring(cnOutcomes.Deadlift), tostring(totalOutcome),
		tostring(wins), ladderPoints, tostring(ladderOutcome), tostring(nationalsOutcome),
		if nationals then string.format(" %d/%d", nationals.placings, nationals.target) else "")
	if worldsOutcome then
		log("%s's Worlds spot (%s): %s", player.Name, lifter.classLabel, tostring(worldsOutcome))
	end
	-- MEDALS AND TROPHIES (GAME_DESIGN §42): a top-3 place in the whole field (the podium they stand on) wins one, solo
	-- meets too (user 2026-11-24: "yea we can give it to them in solo meets too") (InventoryService.meetPlaced). One
	-- statement and no new locals on purpose: this file is at Luau's 200-local limit.
	require(PlayerDataFolder:WaitForChild("InventoryService")).meetPlaced(player, current.level,
		if totalKg and current.places[lifter.key] then current.places[lifter.key].place else nil, lines)
	-- COACHING (GAME_DESIGN §40.5): a coach's trial 2 is judged from this meet, and the active coach's bond grows
	-- (CoachingService.meetFinished; one statement, no new locals: this file is at Luau's 200-local limit).
	require(PlayerDataFolder:WaitForChild("CoachingService")).meetFinished(player, current, lifter, totalKg, lines)
	if rankResult then
		log("%s's rank: %d -> %d (%.1f GL%s), new titles: %s, streak %d day(s)", player.Name, rankResult.rankBefore,
			rankResult.rankAfter, rankMeet and rankMeet.points or 0, if rankResult.newBest then ", new best" else "",
			if #rankResult.newFeats > 0 then table.concat(rankResult.newFeats, ", ") else "none", rankResult.streakDays)
		RankService.meetRecorded(player, rankResult, rankMeet and rankMeet.points)
	elseif rankMeet then
		warn(string.format("[LocalMeetService] %s's rank was not recorded", player.Name))
	end
	return lines
end

local function lightsText(lights: { string }?): string
	if lights == nil then
		return ""
	end
	return "LIGHTS  " .. table.concat(lights, " · "):upper()
end

local function bestOf(lifter: Lifter, lift: string): number?
	local best: number? = nil
	for _, attempt in ipairs(lifter.lifts[lift].history) do
		if attempt.result == "GoodLift" and (best == nil or attempt.weightKg > best) then
			best = attempt.weightKg
		end
	end
	return best
end

-- "SQUAT", "TOTAL", ... as the screens write a record's name.
local function recordName(record: string): string
	return string.upper(record)
end

--[[
	The big screen's fun facts: gym records set at this meet first, then
	anything else the lifter is breaking right now, then the gym records they
	hold, their titles and best marks. World records join when the WORLD
	RECORD board exists (GAME_DESIGN §31).
]]
local function factsFor(lifter: Lifter): { string }
	local facts: { string } = {}
	for _, record in ipairs(lifter.gymRecords) do
		table.insert(facts, string.format("NEW GYM %s RECORD!", recordName(record)))
	end
	local total, allThree = 0, true
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local best = bestOf(lifter, lift)
		local cn = lifter.competitionNumber[lift]
		if best then
			total += best
			if cn and best > cn then
				table.insert(facts, string.format("BEAT THEIR %s CN!", string.upper(lift)))
			end
		else
			allThree = false
		end
	end
	if allThree and (lifter.bestTotalKg == nil or total > (lifter.bestTotalKg :: number)) then
		table.insert(facts, string.format("NEW BEST TOTAL!  %s KG", kgText(total)))
	end
	local lift, kg = lifter.currentLift, lifter.chosenKg
	if lift and kg and not lifter.roundDone and lifter.competitionNumber[lift] and kg > lifter.competitionNumber[lift] then
		table.insert(facts, string.format("GOING FOR A NEW %s CN", string.upper(lift)))
	end
	-- The gym records they already hold in this class (not the ones set today: those are above).
	local held: { string } = {}
	for record, holder in pairs(GymRecords.get(lifter.classLabel) or {}) do
		if holder.userId == lifter.key and not table.find(lifter.gymRecords, record) then
			table.insert(held, record)
		end
	end
	if #held == 1 then
		table.insert(facts, string.format("GYM %s RECORD HOLDER", recordName(held[1])))
	elseif #held > 1 then
		table.insert(facts, string.format("HOLDS %d GYM RECORDS", #held))
	end
	-- Their newest numbered State Champion badge (GAME_DESIGN §36.4), before the titles.
	local badge = lifter.championBadges[1]
	if badge then
		local more = #lifter.championBadges - 1
		table.insert(facts, string.format("%s%s · %s%s", if badge.number > 0 then string.format("#%d ", badge.number) else "",
			MeetLevelConfig.ChampionBadge.Name, MeetLevelConfig.seasonLabel(badge.season),
			if more > 0 then string.format(" (+%d MORE)", more) else ""))
	end
	-- The best titles first: State over Regional, champion over runner-up.
	for _, id in ipairs({ "StateChampion", "StateRunnerUp", "StateThird", "RegionalChampion", "RegionalRunnerUp",
		"RegionalThird" }) do
		local count = lifter.titles[id]
		if count and count > 0 then
			local name = string.upper(MeetLevelConfig.Titles[id])
			table.insert(facts, if count > 1 then string.format("%dx %s", count, name) else name)
		end
	end
	-- Their road to Nationals in this class (GAME_DESIGN §36.4 "The Nationals spot").
	if lifter.nationalsQualified then
		table.insert(facts, "QUALIFIED FOR NATIONALS")
	elseif lifter.nationalsPlacings > 0 then
		table.insert(facts, string.format("%d / %d TOWARD NATIONALS", lifter.nationalsPlacings,
			MeetLevelConfig.Nationals.PlacingsTarget))
	end
	if lifter.stateQualified then
		table.insert(facts, "QUALIFIED FOR STATE")
	end
	if lifter.localWins > 0 then
		table.insert(facts, string.format("%dx LOCAL CHAMPION", lifter.localWins))
	end
	table.insert(facts, if lifter.bestTotalKg then string.format("BEST TOTAL %s KG", kgText(lifter.bestTotalKg :: number))
		else "CHASING A FIRST TOTAL")
	return facts
end

-- Writes the lifter's big screen: who they are, their numbers, what they are doing (`lines`) and the fun facts.
local function boardFor(lifter: Lifter, lines: { string }, mood: ("good" | "bad")?)
	lifter.boardLines, lifter.boardMood = lines, mood
	-- Several lifters share a State rack: its screen shows the one lifting.
	if lifter.hall.state and not lifter.onScreen then
		return
	end
	local forecast = 0
	local best: { [string]: number } = {}
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		forecast += lifter.competitionNumber[lift] or 0
		local kg = bestOf(lifter, lift)
		if kg then
			best[lift] = kg
		end
	end
	local player = lifter.player
	-- The State arena's centre cube follows every rack's screen and shows the biggest moment (StateArenaShow).
	if lifter.hall.state and not lifter.hall.nationals then
		StateArenaShow.show(lifter.platform.index, {
			name = if player then player.Name else lifter.name,
			status = lines,
			mood = mood,
			recordAttempt = lifter.recordAttempt,
			stakesLevel = lifter.stakesLevel,
			stakesLine = lifter.stakesLine,
			moment = lifter.moment,
		})
	end
	LocalMeetVenue.showLifter(lifter.platform, {
		name = if player then player.Name else lifter.name,
		classLabel = lifter.classLabel,
		bodyweightKg = lifter.bodyweightKg,
		forecastTotalKg = forecast,
		best = best,
		status = lines,
		mood = mood,
		facts = factsFor(lifter),
		recordAttempt = lifter.recordAttempt,
	})
end

-- ---------------------------------------------------------------- the meet

local COACH_READY = { "You got this.", "Breathe. Brace. Go.", "Same as training.", "Big lift. Let's go." }
local COACH_GOOD = { "Smoked it!", "That's the one!", "Easy work!" }
local COACH_MISS = { "Shake it off.", "Reset. Next one.", "You had that. Again." }
local function pick(lines: { string }): string
	return lines[math.random(1, #lines)]
end

-- Waits until `done()` is true or the time runs out. Returns whether `done()` became true.
local function waitUntil(seconds: number, done: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if done() then
			return true
		end
		task.wait(POLL_SECONDS)
	end
	return done()
end

local function stillLifting(lifter: Lifter): boolean
	local player = lifter.player
	return not lifter.withdrawn and (player == nil or player.Parent ~= nil)
end

-- The longest a lift waits for its lifter to arrive on the platform.
local WALK_OUT_TIMEOUT_SECONDS = 12
-- The longest the next round waits for everyone to be back in the warm-up room before anyone chooses.
local WALK_BACK_TIMEOUT_SECONDS = 20
-- After a good lift's finish, how long the lifter stays before racking the bar and walking off.
local LEAVE_AFTER_FINISH_SECONDS = 0.8
-- After a miss's fail animation, this beat and he turns and walks off (user 2026-11-15).
local MISS_WALK_BEAT_SECONDS = 0.25
-- The spotters stand clear of a celebrating lifter (LocalMeetVenue.clearSpotters): long enough for the step back to
-- the lift spot (renewed when the celebration starts), and this long after it, while the lifter walks off.
local SPOTTERS_CLEAR_TO_SPOT_SECONDS = 6
local SPOTTERS_CLEAR_AFTER_SECONDS = 3
-- After the referee's start command, a beat before the lift starts.
local COMMAND_BEAT_SECONDS = 0.6
-- Room in a round for the setup at the bar (MeetLiftAnimation: up to about 7 s, the bench's) and the start command.
local UNRACK_ALLOWANCE_SECONDS = 10
-- How far through the failing part a computer lifter's miss stops (§37.5: its fail animation takes over there).
local CPU_FAIL_SHARE = 0.6
-- From the start of a good deadlift's finish to its lockout (StationAnimationConfig.MeetStages: 2.2 -> 2.9 s).
local DOWN_AT_LOCKOUT_SECONDS = 0.7
-- The live minigame progress (visual only): at most one update this often per player is used.
local PROGRESS_MIN_GAP_SECONDS = 0.05

--[[
	Walks a lifter along `points` to `final` (GAME_DESIGN §37.5: out from the
	warm-up room to the platform, and back after the lift), in the background.
	The SERVER walks a player's body the same way as a computer lifter's, held
	still (anchored), so their controls can't steer them away, stop their turn
	coming, or be stopped by the closed doorways (user 2026-11-04). At the end
	they stand at `final` exactly (a player anchored when `anchoredAtEnd`).
	`lifter.walking` is true on the way; a newer walk ends this one.
]]
local function walkLifter(lifter: Lifter, points: { Vector3 }, final: CFrame, anchoredAtEnd: boolean,
	onArrive: (() -> ())?, options: ComputerLifters.WalkOptions?)
	local token = (lifter.walkToken or 0) + 1
	lifter.walkToken = token
	lifter.walking = true
	local function current(): boolean
		return lifter.walkToken == token and stillLifting(lifter)
	end
	task.spawn(function()
		local player = lifter.player
		if player then
			local body = bodyOf(player)
			if body and body.humanoid.Health > 0 then
				body.root.Anchored = true
				ComputerLifters.walkBody(body.character, points, final, current, options)
			end
			if current() then
				standAt(player, final, anchoredAtEnd)
			end
		else
			ComputerLifters.walkBody(lifter.body, points, final, current, options)
		end
		if lifter.walkToken == token then
			if onArrive and current() then
				onArrive()
			end
			lifter.walking = false
		end
	end)
end

-- The lifter's character: a player's, or a computer lifter's body.
local function characterOf(lifter: Lifter): Model?
	local player = lifter.player
	return if player then player.Character else lifter.body
end

--[[
	Walks a real lifter's coach to `final` (GAME_DESIGN §37.5), through the doorway
	when they're on the other side of the wall, on their own line beside the lifter's (user 2026-11-07); then `onArrive`. A computer
	lifter's coach stands watching at the doorway: nobody reads what they say, and walking
	every coach would cost eight more moving bodies per hall.
]]
local function coachWalk(lifter: Lifter, final: CFrame, onArrive: ((coach: Model) -> ())?, via: Vector3?, first: Vector3?)
	local coach = LocalMeetVenue.coachFigure(lifter.platform)
	if coach == nil or lifter.player == nil then
		return
	end
	-- Their own line through the doorway or past the banner, beside the lifter's (user 2026-11-07).
	local way = lifter.platform.coachWay
	local wallZ = way[1].Z
	local going = final.Position.Z < wallZ
	local points: { Vector3 } = {}
	if (ComputerLifters.positionOf(coach).Position.Z < wallZ) ~= going then
		points = if going then { way[1], way[2] } else { way[2], way[1] }
	end
	if first then
		table.insert(points, first)
	end
	if via then
		table.insert(points, via)
	end
	local token = (lifter.coachToken or 0) + 1
	lifter.coachToken = token
	local function current(): boolean
		return lifter.coachToken == token and stillLifting(lifter) and coach.Parent ~= nil
	end
	task.spawn(function()
		ComputerLifters.walkBody(coach, points, final, current)
		if onArrive and current() then
			onArrive(coach)
		end
	end)
end

-- The coach's slaps keep to the lifter's own chalking; a coach arriving with the lifter's loop past the first slap less
-- this moves the lifter's loop back to the slaps (coachSendOff).
local RITUAL_LATE_LIMIT_SECONDS = 0.1
-- On the send-off the coach first steps this far out to the open side (coachSendOff).
local RITUAL_COACH_WIDE_STUDS = 4.3
-- ... and this far back from the lifter, so he passes behind that camera, not in front of it.
local RITUAL_COACH_BACK_STUDS = 1.4

local function stopChalk(lifter: Lifter)
	MeetChalk.stop(lifter.chalkTrack)
	MeetChalk.stop(lifter.coachTrack)
	lifter.chalkTrack, lifter.coachTrack = nil, nil
end

-- Lets a lifter off their seat, if they are on it (they may have jumped off already).
local function offSeat(lifter: Lifter)
	local seat = lifter.seat
	local player = lifter.player
	if seat == nil or player == nil then
		return
	end
	seat.Disabled = true
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	local body = bodyOf(player)
	if body then
		body.humanoid.Sit = false
	end
end

-- A lifter stands up from (and sits down from) this far in front of their seat.
local SEAT_STAND_STUDS = 1.3
-- A lifter within this of their seat is "at it" (sitting, or just up): their walk away starts by the lane.
local SEAT_NEAR_STUDS = 3.5
-- A walk between a seat and somewhere off the lane keeps to the lane until this far (along the row) short of there,
-- and only then cuts across: it passes the coach and the caller square on the lane, not on a slant through them.
local LANE_TURN_STUDS = 2.8

--[[
	On and off a bench without walking through the lifters sitting beside (user 2026-11-18: "you can see the characters
	phasing through each other even when they are walking"): where the venue's seats stand in a row with a lane in front
	(Platform.seatLane, the Nationals hall), the spot straight out in front of this lifter's seat, facing away from it.
	A walk to the seat comes here first and then steps back to the bench; a walk from the seat goes out to here first.
	Nil when they have no seat or the venue has no lane (the walk is straight, as before).
]]
local function seatLane(lifter: Lifter): CFrame?
	local seat, lane = lifter.seat, lifter.platform.seatLane
	if seat == nil or lane == nil then
		return nil
	end
	return CFrame.new(seat.Position.X, lifter.platform.waitSpot.Y, seat.Position.Z) * seat.CFrame.Rotation
		* CFrame.new(0, 0, -(SEAT_STAND_STUDS + lane))
end

-- A back row's seat (the State arena): the way from its own lane round the end of the row in front, onto the front
-- lane (LocalMeetVenue.Platform.seatAround). Empty for a seat whose own lane is the front one.
local function seatAround(lifter: Lifter): { Vector3 }
	local seat, around = lifter.seat, lifter.platform.seatAround
	return (if seat and around then around[seat] else nil) or {}
end

-- The point on the front lane abreast of `at`, LANE_TURN_STUDS back toward where this lifter comes onto that lane; nil
-- when there is no lane or `at` is nearer than that along the row.
local function laneNear(lifter: Lifter, at: Vector3): Vector3?
	local lane = seatLane(lifter)
	if lane == nil then
		return nil
	end
	local around = seatAround(lifter)
	local from = around[#around] or lane.Position
	local along = (at - from):Dot(lane.RightVector)
	if math.abs(along) <= LANE_TURN_STUDS then
		return nil
	end
	return from + lane.RightVector * (along - math.sign(along) * LANE_TURN_STUDS)
end

-- The way of a walk from their seat to `to` (out to the lane, then along it), when they are at their seat; nothing
-- otherwise (a lifter up and about walks straight, as before).
local function offSeatWay(lifter: Lifter, to: Vector3): { Vector3 }
	local lane, seat, player = seatLane(lifter), lifter.seat, lifter.player
	local body = if player then bodyOf(player) else nil
	if lane == nil or seat == nil or body == nil then
		return {}
	end
	local away = Vector3.new(body.root.Position.X - seat.Position.X, 0, body.root.Position.Z - seat.Position.Z)
	if away.Magnitude > SEAT_NEAR_STUDS then
		return {}
	end
	local way = { lane.Position }
	for _, point in ipairs(seatAround(lifter)) do
		table.insert(way, point)
	end
	local turn = laneNear(lifter, to)
	if turn then
		table.insert(way, turn)
	end
	return way
end

--[[
	The State meet (user 2026-11-06): a lifter sits on their bench, on a real seat, so they can jump up and roam the meet area or
	practise at the warm-up racks while they wait. `walk`: walks there first. Their turn brings them back (bringBack).
]]
local function sitLifter(lifter: Lifter, walk: boolean)
	local player = lifter.player
	local seat = lifter.seat
	if player == nil or seat == nil or not stillLifting(lifter) then
		return
	end
	local inFront = CFrame.new(seat.Position.X, lifter.platform.waitSpot.Y, seat.Position.Z) * seat.CFrame.Rotation
		* CFrame.new(0, 0, -SEAT_STAND_STUDS)
	local function sitDown()
		local body = bodyOf(player)
		if body and stillLifting(lifter) then
			standAt(player, inFront, false)
			seat.Disabled = false
			seat:Sit(body.humanoid)
		end
	end
	local lane = seatLane(lifter)
	if walk and lane then
		-- Onto the lane, along it to the spot in front of their seat, then a step straight back to the bench
		-- (MeetWalkPath.isBackStep).
		-- (a back row's seat: round the end of the row in front first, then along its own lane)
		local body = bodyOf(player)
		local onto = if body then laneNear(lifter, body.root.Position) else nil
		local way: { Vector3 } = if onto then { onto } else {}
		local around = seatAround(lifter)
		for index = #around, 1, -1 do
			table.insert(way, around[index])
		end
		walkLifter(lifter, way, lane, false, function()
			walkLifter(lifter, {}, inFront, false, sitDown)
		end)
	elseif walk then
		walkLifter(lifter, {}, inFront, false, sitDown)
	else
		sitDown()
	end
end

-- Their turn: from wherever they are (a seat, a warm-up rack, roaming) to their spot at the chalk stand. Waits until they are there.
local function bringBack(lifter: Lifter)
	local player = lifter.player
	if player == nil then
		return
	end
	stopWarmUps(player)
	if LiftAttemptService.isAttemptActive(player) then
		LiftAttemptService.abandon(player)
	end
	local way = offSeatWay(lifter, lifter.platform.waitSpot.Position)
	offSeat(lifter)
	local body = bodyOf(player)
	local spot = lifter.platform.waitSpot
	if body and (body.root.Position - spot.Position).Magnitude > StateArenaConfig.BringBackWalkStuds then
		standAt(player, spot, true)
		return
	end
	walkLifter(lifter, way, spot, true)
	waitUntil(WALK_BACK_TIMEOUT_SECONDS, function()
		return not lifter.walking or not stillLifting(lifter)
	end)
end

--[[
	What the coach tells the lifter while they choose. It waits until the coach has walked in: said on the way, the
	doorway's walls would cut the bubble off (user 2026-11-06: their words went through the wall).
]]
local function coachTell(lifter: Lifter, line: string?)
	lifter.coachLine = line
	if lifter.coachHere then
		LocalMeetVenue.coachSays(lifter.platform, line)
	end
end

--[[
	Chalking up while they choose (user 2026-11-06): the lifter at the stand; on squat
	the coach behind them chalking their upper back, otherwise in front of them,
	talking to them. With the coach's ritual (`ritual`, State and up) the coach always
	starts in front, talking, and goes round to their back for the send off (coachSendOff).
]]
local function startChalk(lifter: Lifter, lift: string, ritual: boolean?)
	stopChalk(lifter)
	-- (A computer lifter's emote ends as it starts chalking up: runComputerEmotes.)
	if lifter.player == nil then
		ComputerLifters.stopEmote(lifter.body)
	end
	local chalk = LocalMeetConfig.Chalk
	lifter.chalkTrack = MeetChalk.play(characterOf(lifter), chalk.LifterAnimationId)
	-- With the ritual, the lifter's loop starts where it reaches the coach's slaps as the coach gets round to their back
	-- (coachSendOff), so the two play in step without a jump.
	if ritual and lifter.chalkTrack then
		local first = chalk.SlapAt[1] - LocalMeetConfig.Ritual.SlapLeadSeconds
		local arrive = LocalMeetConfig.Ritual.CoachMoveAt + LocalMeetConfig.Ritual.CoachRoundSeconds
		lifter.chalkTrack.TimePosition = (first - arrive) % chalk.LoopSeconds
	end
	local onBack = lift == "Squat" and not ritual
	local platform = lifter.platform
	MeetFigures.showClipboard(LocalMeetVenue.coachFigure(platform), not onBack)
	lifter.coachHere, lifter.coachLine = false, nil
	LocalMeetVenue.coachSays(platform, nil)
	coachWalk(lifter, if onBack then platform.coachBackSpot else platform.coachFrontSpot, function(coach: Model)
		lifter.coachTrack = MeetChalk.play(coach, if onBack then chalk.CoachBackAnimationId else chalk.CoachTalkAnimationId)
		lifter.coachHere = true
		LocalMeetVenue.coachSays(platform, lifter.coachLine)
	end, if onBack then platform.coachBackVia else platform.coachFrontVia)
end

--[[
	The coach's ritual (GAME_DESIGN §36.4, user 2026-11-11): halfway through the chalking up the coach goes round to the
	lifter's back, slaps it twice and shouts `line` (text only). The lifter's own screen cuts to it (MeetRitualShot).
]]
local function coachSendOff(lifter: Lifter, line: string)
	if not stillLifting(lifter) or lifter.chalkTrack == nil then
		return
	end
	local platform = lifter.platform
	MeetChalk.stop(lifter.coachTrack)
	lifter.coachTrack = nil
	lifter.coachHere = false
	LocalMeetVenue.coachSays(platform, nil)
	local coachFigure = LocalMeetVenue.coachFigure(platform)
	MeetFigures.showClipboard(coachFigure, false)
	-- Out wide first, round behind the Hands shot's camera (MeetRitualShot: in front of the lifter on the open side): the
	-- straight way round crossed its lens two studs away, a blur of coach filling the screen (Studio 2026-11-15).
	local wide: Vector3? = nil
	if coachFigure then
		local at = ComputerLifters.positionOf(coachFigure)
		local away = Vector3.new(-at.LookVector.X, 0, -at.LookVector.Z)   -- (he faces the lifter: away is behind him)
		local floor = Vector3.new(at.Position.X, platform.coachBackSpot.Position.Y, at.Position.Z)   -- (a floor point)
		wide = floor + platform.chalkOut * RITUAL_COACH_WIDE_STUDS
			+ (if away.Magnitude > 1e-3 then away.Unit * RITUAL_COACH_BACK_STUDS else Vector3.zero)
	end
	coachWalk(lifter, platform.coachBackSpot, function(coach: Model)
		-- (Still chalking up: the walk out may have begun while they came round.)
		if lifter.chalkTrack == nil then
			return
		end
		local track = MeetChalk.play(coach, LocalMeetConfig.Chalk.CoachBackAnimationId)
		if track then
			-- In step with the lifter's own chalking, so the slaps land on the back pose they were made for. Before, the
			-- coach jumped to its slaps on its own, the two ran about 1.4 s apart and the slaps landed on the back of
			-- the head (Studio 2026-11-15; the user: "the coach is not even slapping the shoulders or neck"). The
			-- lifter's chalking was started so it is about at `first` now (startChalk); only a late coach moves it.
			local first = math.max(0, LocalMeetConfig.Chalk.SlapAt[1] - LocalMeetConfig.Ritual.SlapLeadSeconds)
			local chalkTrack = lifter.chalkTrack :: AnimationTrack
			local at = chalkTrack.TimePosition
			-- The coach falls in step with the lifter; only a coach too late for the slaps moves the lifter back to them
			-- (a jump, so not for a coach a little late or early: that popped the arms).
			if at > LocalMeetConfig.Chalk.SlapAt[1] - RITUAL_LATE_LIMIT_SECONDS then
				chalkTrack.TimePosition = first
				at = first
			end
			track.TimePosition = at
		end
		lifter.coachTrack = track
		lifter.coachHere = true
		lifter.coachLine = line
		LocalMeetVenue.coachSays(platform, line)
	end, platform.coachBackVia, wide)
end

-- The coach follows the lifter back from the platform, once they have gone past, to wait near the chalk stand (user 2026-11-07).
local function coachFollowBack(lifter: Lifter)
	local platform = lifter.platform
	local player = lifter.player
	local coach = LocalMeetVenue.coachFigure(platform)
	if player == nil or coach == nil then
		return
	end
	local token = lifter.coachToken
	task.spawn(function()
		local passedZ = platform.coachWay[1].Z
		waitUntil(WALK_BACK_TIMEOUT_SECONDS, function()
			local character = player.Character
			return character == nil or ComputerLifters.positionOf(character).Position.Z > passedZ or not lifter.outOnPlatform
		end)
		task.wait(LocalMeetConfig.CoachFollowSeconds)
		-- (Their next turn may have called them to the chalk stand already.)
		if lifter.coachToken == token and stillLifting(lifter) then
			local rest = platform.coachSpot
			coachWalk(lifter, CFrame.lookAt(rest, Vector3.new(platform.waitSpot.X, rest.Y, platform.waitSpot.Z)))
		end
	end)
end

-- A sound on the lifter's platform, for the people in that hall (MeetSoundController). Sound only.
local function soundCue(lifter: Lifter, cue: string, volume: number?)
	local set, rack = remotes, lifter.platform.rack
	if set and rack then
		local at = rack:GetPivot().Position
		for player, visit in pairs(visits) do
			if visit.hall == lifter.hall.index then
				set.sound:FireClient(player, cue, at, volume)
			end
		end
	end
end

-- The head referee's command: the line on the lifter's screen and a clap the hall can hear.
local function refereeCommand(lifter: Lifter, line: string?)
	LocalMeetVenue.refereeSays(lifter.platform, line)
	if line then
		soundCue(lifter, "Clap")
	end
end

-- Sets the lifter up on the platform for `lift` (§37.5): the pose and the lift's animation at its setup stage.
local function setUpLift(lifter: Lifter, lift: string)
	-- (The spotters, aside for the walk-out, come back for the lift.)
	LocalMeetVenue.releaseSpotters(lifter.platform)
	MeetLiftAnimation.stop(lifter.liftAnim)
	local character, rack = characterOf(lifter), lifter.platform.rack
	lifter.liftAnim = if character and rack then MeetLiftAnimation.begin(character, rack, lift) else nil
end

-- The lift is over on the platform: the animation stops and the referee falls silent.
local function endLift(lifter: Lifter)
	if lifter.player then
		MeetLiveScreens.stop(lifter.player)
	end
	MeetLiftAnimation.stop(lifter.liftAnim)
	lifter.liftAnim = nil
	lifter.livePhase = nil
	LocalMeetVenue.refereeSays(lifter.platform, nil)
end

--[[
	The deadlift's DOWN (§37.5): said when the bar reaches lockout. The lift waits
	above the knees through the lockout game and locks out at the start of its
	finish, DOWN_AT_LOCKOUT_SECONDS in.
]]
local function sayAtLockout(lifter: Lifter, line: string)
	local handle = lifter.liftAnim
	task.delay(DOWN_AT_LOCKOUT_SECONDS, function()
		if lifter.liftAnim == handle then
			refereeCommand(lifter, line)
		end
	end)
end

--[[
	The fail animation a lifter plays for missing `lift` in part `part` (1 or 2:
	its first or second minigame; GAME_DESIGN §37.5 "The fail animations"): a
	player's own fail style in this attempt's slot (`attemptNumber`; won at Hype
	Man, LoadoutConfig, user 2026-11-12); a computer lifter's own, picked when its body was made (ComputerLifters,
	LocalMeetConfig.ComputerLifters.FailStyleWeights).
]]
local function failAnimationFor(lifter: Lifter, lift: string, part: number, attemptNumber: number): StationAnimationConfig.Fail?
	local player = lifter.player
	local cpuStyle = if player == nil and lifter.body then lifter.body:GetAttribute(ComputerLifters.FailStyleAttribute)
		else nil
	local style = if player then PlayerDataService.getFailStyle(player, attemptNumber)
		elseif typeof(cpuStyle) == "string" then cpuStyle
		else nil
	return StationAnimationConfig.failFor(lift, part, style)
end

--[[
	The end of a lift on the platform (§37.5): after a good lift the finish
	(stand up, press, lower) and the referee's RACK (the deadlift's DOWN was
	said at lockout); after a miss the fail animation for the part that failed
	(`failedPart`), and the spotters take the bar. The sound the bar makes follows
	its weight (`weightKg`). Returns the seconds until a missed bar lands or is
	caught (0 after a good lift).
]]
local function finishLift(lifter: Lifter, lift: string, good: boolean, failedPart: number, weightKg: number,
	attemptNumber: number): number
	lifter.livePhase = nil
	local fail = if good then nil else failAnimationFor(lifter, lift, failedPart, attemptNumber)
	local seconds = MeetLiftAnimation.finish(lifter.liftAnim, good, fail)
	lifter.failSeconds = if fail then fail.length else nil
	local commands = LocalMeetConfig.RefereeCommands[lift]
	local handle = lifter.liftAnim
	local barCue = MeetSoundConfig.endOfLiftCue(lift, good, failedPart, weightKg)
	local barLandsIn = if fail then fail.release + MeetSoundConfig.fallSeconds(lift, failedPart) else 0
	if good and commands and not commands.goodAtLockout then
		-- The command only: the bar still has to go back, and makes its sound then (walkBack).
		task.delay(seconds, function()
			if handle and lifter.liftAnim == handle then
				refereeCommand(lifter, commands.good)
			end
		end)
	elseif good then
		-- A good deadlift: on the floor at the end of its finish.
		task.delay(seconds, function()
			if handle and lifter.liftAnim == handle then
				soundCue(lifter, barCue)
			end
		end)
	else
		LocalMeetVenue.refereeSays(lifter.platform, nil)
		if fail then
			task.delay(barLandsIn, function()
				if handle and lifter.liftAnim == handle then
					soundCue(lifter, barCue)
				end
			end)
		end
	end
	return barLandsIn
end

--[[
	The winner's theme song and celebration at the awards. The defaults for
	now (LocalMeetConfig.Awards); the user's custom theme songs and
	celebrations (GAME_DESIGN §29.10) plug in HERE, e.g. read from the winner's
	save, so the ceremony itself does not change.
]]
local function themeFor(_winner: Player): string
	return LocalMeetConfig.Awards.DefaultThemeSoundId
end

local function celebrationFor(_winner: Player): string
	return LocalMeetConfig.Awards.DefaultCelebrationAnimationId
end

-- The walk back from the platform to the warm-up room: the bar put back, back on their feet where they are, out to
-- the lift spot, then the way out, reversed. `celebrate` (optional) plays at the lift spot, well clear of the bar, and
-- says how long it takes; a computer lifter's cheer does the same (user 2026-11-07: nobody touches the bar).
-- `overWalk` (optional): starts as the walk back starts and plays OVER it (a miss reaction: user 2026-11-15, "fail, turn
-- while walking hand gestures, scream"), with no stop at the lift spot first.
local function walkBack(lifter: Lifter, celebrate: (() -> number)?, overWalk: (() -> ())?)
	LocalMeetVenue.setStageLight(lifter.platform, 1)
	local good = lifter.lastResult == "GoodLift"
	local racked, clear = 0, 0
	if good then
		racked, clear = MeetLiftAnimation.rerack(lifter.liftAnim)
		if lifter.currentLift ~= "Deadlift" then
			task.delay(racked + MeetSoundConfig.RackGlideSeconds, soundCue, lifter, "BarRack")
		end
	else
		-- A missed bench: he sits up and stands before he turns and walks off (MeetLiftAnimation.getUp).
		clear = MeetLiftAnimation.getUp(lifter.liftAnim)
	end
	local function leave()
		endLift(lifter)
		local function home()
			lifter.outOnPlatform = false
			-- A celebration that lasts the whole walk back stops now they're back (user 2026-11-11).
			CelebrationService.endWalk(characterOf(lifter))
		end
		local character = characterOf(lifter)
		local spot = lifter.platform.liftSpot
		if character then
			local at = character:GetPivot().Position
			-- After a miss he keeps facing the way he is (no snap round to the front first); the walk turns him toward
			-- the way out as he goes (MeetWalkPath).
			local facing = if overWalk then character:GetPivot().Rotation else spot.Rotation
			local here = CFrame.new(at.X, spot.Y, at.Z) * facing
			local player = lifter.player
			if player then
				standAt(player, here, true)
			else
				ComputerLifters.moveBody(lifter.body, here)
			end
		end
		local back: { Vector3 } = {}
		for index = #lifter.platform.walkOut, 1, -1 do
			table.insert(back, lifter.platform.walkOut[index])
		end
		-- A computer lifter cheers a good lift before walking off, as players emote (§37.2), unless it has a celebration
		-- (State and up: CelebrationService).
		local pause = celebrate
		if pause == nil and lifter.player == nil and good and lifter.body then
			pause = function(): number
				local cheerSeconds = LocalMeetConfig.ComputerLifters.GoodLiftCheerSeconds
				ComputerLifters.cheer(lifter.body, cheerSeconds)
				return cheerSeconds
			end
		end
		if pause then
			local thePause = pause
			-- The spotters make way (user 2026-11-11): from now, while the lifter steps back to the lift spot, through
			-- the celebration, until they have walked off the platform.
			LocalMeetVenue.clearSpotters(lifter.platform, SPOTTERS_CLEAR_TO_SPOT_SECONDS)
			walkLifter(lifter, {}, spot, true, function()
				local seconds = thePause()
				LocalMeetVenue.clearSpotters(lifter.platform, seconds + SPOTTERS_CLEAR_AFTER_SECONDS)
				local token = lifter.walkToken
				task.delay(seconds, function()
					if lifter.walkToken == token and stillLifting(lifter) then
						walkLifter(lifter, back, lifter.platform.waitSpot, true, home)
						coachFollowBack(lifter)
					end
				end)
			end)
			return
		end
		table.insert(back, 1, spot.Position)
		-- Held still at their waiting spot until the next walk out (user 2026-11-04): a lifter stays put all meet.
		walkLifter(lifter, back, lifter.platform.waitSpot, true, home)
		coachFollowBack(lifter)
		if overWalk then
			overWalk()
		end
	end
	if clear <= 0 then
		leave()
		return
	end
	-- A walk out that started meanwhile wins.
	local token = lifter.walkToken
	task.delay(clear, function()
		if lifter.walkToken == token and stillLifting(lifter) then
			leave()
		end
	end)
end

--[[
	A computer lifter's emotes while it waits (GAME_DESIGN §37.2, user 2026-11-01 "the same animations. and emotes n
	stuff"; LocalMeetConfig.ComputerLifters.IdleEmotes, Claude's defaults waiting for the user's OK): now and then one
	of its own emotes, only while it stands still at its waiting spot (never walking, out on the platform, chalking,
	lifting, celebrating or seated) or on the podium. Runs for as long as its body is in this meet. PERFORMANCE: one
	check every half second per computer lifter (at most 3 per hall); an emote is one short track.
]]
local EMOTE_CHECK_SECONDS = 0.5
-- On the podium each computer lifter waves this long or less after it has settled there (a random moment).
local PODIUM_WAVE_STAGGER_SECONDS = 2.5
-- An emote starts only when the round is held up this much longer than the emote lasts.
local EMOTE_SPARE_SECONDS = 0.5
local function runComputerEmotes(current: Meet, lifter: Lifter)
	local settings = LocalMeetConfig.ComputerLifters.IdleEmotes
	local body = lifter.body
	if lifter.player ~= nil or body == nil then
		return
	end
	local function between(range: { number }): number
		return cpuRandom:NextNumber(range[1], range[2])
	end
	-- The next round can't start for at least `seconds`: someone is still out on a platform (lifting, celebrating: the
	-- walk back still to come) or has that long left of their walk back. A round starts, and everyone chalks up, the
	-- moment the last lifter is back (Studio 2026-11-19: emotes begun just before that were cut off after a second).
	local function roundHeldUpFor(seconds: number): boolean
		for _, other in ipairs(current.lifters) do
			if other ~= lifter and stillLifting(other) and (other.outOnPlatform or other.walking) then
				local left = ComputerLifters.walkSecondsLeft(characterOf(other))
				if (left == nil and other.outOnPlatform) or (left ~= nil and left >= seconds) then
					return true
				end
			end
		end
		return false
	end
	local function free(): boolean
		local figure = lifter.body
		return figure ~= nil and figure.Parent ~= nil and current.hall.meet == current and stillLifting(lifter)
			and (lifter.onPodium == true or not current.final)
			and not lifter.walking and not lifter.outOnPlatform and lifter.liftAnim == nil and lifter.chalkTrack == nil
			and lifter.seat == nil and not ComputerLifters.isWalking(figure) and not CelebrationService.isPlaying(figure)
	end
	-- When emote `id` may START: on the podium, or in a wait while the others finish that lasts the whole emote. (Not the
	-- weigh-in: 6 s, straight into round 1's chalking.)
	local function mayStart(id: string): boolean
		local emote = Once.EmoteConfig.byId[id]
		return emote ~= nil and (lifter.onPodium == true or roundHeldUpFor(emote.seconds + EMOTE_SPARE_SECONDS))
	end
	task.spawn(function()
		local nextAt = os.clock() + between(settings.FirstDelaySeconds)
		local stillSince: number? = nil
		local last: string? = nil
		local waved = false
		local waveAt: number? = nil
		while lifter.body == body and body.Parent and current.hall.meet == current do
			task.wait(EMOTE_CHECK_SECONDS)
			if not free() then
				stillSince = nil
				-- (Its walk, chalk or lift ends an emote at once in ComputerLifters; this catches anything else.)
				if ComputerLifters.isEmoting(body) then
					ComputerLifters.stopEmote(body)
				end
				continue
			end
			local now = os.clock()
			stillSince = stillSince or now
			if ComputerLifters.isEmoting(body) or now - (stillSince :: number) < settings.SettleSeconds then
				continue
			end
			-- On the podium: a wave to the crowd first (players there stand with their trophy and emote as they like), each at
			-- its own moment (Studio 2026-11-19: two waving in the same instant looked robotic).
			if lifter.onPodium and not waved then
				waveAt = waveAt or now + cpuRandom:NextNumber(0, PODIUM_WAVE_STAGGER_SECONDS)
				if now >= (waveAt :: number) then
					waved = true
					last = "Wave"
					ComputerLifters.emote(body, "Wave")
					nextAt = now + between(settings.GapSeconds) * 0.5
				end
				continue
			end
			if now < nextAt then
				continue
			end
			-- (One that wouldn't finish before the round's chalking waits: another pick next check.)
			local id = ComputerLifters.pickEmote(body, last, cpuRandom)
			if id == nil or not mayStart(id) then
				continue
			end
			nextAt = now + between(settings.GapSeconds)
			if cpuRandom:NextNumber() < settings.Chance and ComputerLifters.emote(body, id) then
				last = id
			end
		end
	end)
end

--[[
	Saves a good lift as the lifter's official-meet best for their weigh-in
	class (GAME_DESIGN §31.6, the gym records wall; user 2026-10-30): right
	after the lift, with or without a total at the end. Only a meet that
	rewards is official, so a meet without enough real players saves nothing.
]]
local function saveOfficialBest(current: Meet, lifter: Lifter, lift: string, kg: number)
	local player = lifter.player
	if not current.rewards or player == nil then
		return
	end
	local outcome: ProfileOperations.ScaleRaiseOutcome? = nil
	local totalKg: number? = nil
	local saved = PlayerDataService.update(player, function(data)
		outcome = ProfileOperations.raiseOfficialMeetBest(data, lifter.classLabel, lift, kg)
		totalKg = ProfileOperations.getOfficialMeetBestTotal(data, lifter.classLabel)
	end)
	if not saved or outcome == "Rejected" then
		warn(string.format("[LocalMeetService] %s's official %s best (%s kg, %s) was not saved: %s", player.Name,
			lift, kgText(kg), lifter.classLabel, tostring(outcome)))
		return
	end
	log("%s official %s best (%s): %s kg %s", player.Name, lift, lifter.classLabel, kgText(kg), tostring(outcome))
	if outcome ~= "Raised" then
		return -- not a new best for them, so it cannot be a new gym record either
	end
	-- The gym record wall (GymRecords): this lift, and their Total once all three lifts have a best.
	local name, userId = player.Name, player.UserId
	GymRecords.submit(userId, lifter.classLabel, { [lift] = kg, Total = totalKg }, function(broken)
		if #broken == 0 then
			return
		end
		for _, record in ipairs(broken) do
			local previous = record.previous
			log("NEW GYM RECORD: %s %s %s kg (%s), before: %s", name, record.record, kgText(record.kg), lifter.classLabel,
				if previous then string.format("%d with %s kg", previous.userId, kgText(previous.kg)) else "empty")
			if not table.find(lifter.gymRecords, record.record) then
				table.insert(lifter.gymRecords, record.record)
			end
		end
		-- The big screen puts it first (the save takes a moment, so the lift's result is already showing).
		if current.hall.meet == current and not current.final and stillLifting(lifter) and lifter.boardLines then
			boardFor(lifter, lifter.boardLines :: { string }, lifter.boardMood)
		end
		-- The gym record bonus (GAME_DESIGN §41.4): once a meet, times the level; someone else's record or your own,
		-- never an empty spot.
		local bonus = MeetPayout.forGymRecord(userId, broken :: any, CoinConfig.LocalMeet,
			MeetLevelConfig.Levels[current.level].potMultiplier, lifter.recordPaid)
		if bonus and player.Parent then
			lifter.recordPaid = true
			local outcome = PlayerDataService.addCoins(player, bonus.amount, bonus.reason)
			if outcome == "Added" then
				lifter.coinsEarned += bonus.amount
			end
		end
		GymRecords.announce(name, userId, lifter.classLabel, broken)
	end)
end

--[[
	A declared weight that would beat a gym record is news for the whole
	server, with a small WATCH button that teleports a player to the venue
	(GAME_DESIGN §31.6; user 2026-10-30). Only an official meet, as for the
	records themselves; once per attempt. The Total counts when making this
	lift would lift the lifter's official-meet bests in the class past it.
]]
local function announceAttempt(current: Meet, lifter: Lifter, lift: string, kg: number)
	local player = lifter.player
	if not current.rewards or player == nil or lifter.announcedKg == kg then
		return
	end
	-- A lift over the normal limit can't set a record (§37.5).
	if AttemptChoice.isOverLimit(lifter.competitionNumber[lift], kg) then
		return
	end
	lifter.announcedKg = kg
	local claims: { [string]: number } = { [lift] = kg }
	local data = PlayerDataService.getData(player)
	local build = data and ProfileOperations.getBuild(data, lifter.classLabel)
	local bests = build and (build :: any).officialMeetBest
	if typeof(bests) == "table" then
		local total = 0
		for _, name in ipairs(MeetConfig.LiftOrder) do
			local best = bests[name]
			local counted = if name == lift then math.max(kg, if typeof(best) == "number" then best else 0) else best
			if typeof(counted) ~= "number" or counted <= 0 then
				total = 0
				break
			end
			total += counted
		end
		if total > 0 then
			claims.Total = total
		end
	end
	local chasing = GymRecords.wouldBreak(lifter.classLabel, claims)
	if #chasing == 0 then
		return
	end
	log("%s is going for a gym record: %s %s kg (%s)", player.Name, lift, kgText(kg), lifter.classLabel)
	-- The big screen's sign (user 2026-10-30: "a bigger sign at the top saying GYM RECORD ATTEMPT"), until the lift's result.
	local first = chasing[1]
	local detail = string.format("%s KG %s  ·  RECORD %s KG", kgText(first.kg), string.upper(first.record),
		kgText(if first.previous then first.previous.kg else 0))
	if #chasing > 1 then
		detail ..= "  +  TOTAL"
	end
	lifter.recordAttempt = { title = "GYM RECORD ATTEMPT", detail = detail }
	if current.hall.meet == current and not current.final and stillLifting(lifter) and lifter.boardLines then
		boardFor(lifter, lifter.boardLines :: { string }, lifter.boardMood)
	end
	GymRecords.announceAttempt(player.Name, player.UserId, lifter.classLabel, chasing,
		MeetLevelConfig.Levels[current.level].label,
		TeleportConfig.LocalMeetId, current.hall.index)
end

local function activeLifters(current: Meet): { Lifter }
	local list: { Lifter } = {}
	for _, lifter in ipairs(current.lifters) do
		if stillLifting(lifter) then
			table.insert(list, lifter)
		end
	end
	return list
end

-- Takes a lifter out of the running meet (LEAVE, exit, death, leaving the game). The others carry on.
local function withdraw(player: Player, why: string)
	local current, lifter = activeLifter(player)
	if current == nil or lifter == nil then
		return
	end
	lifter.withdrawn = true
	MeetCheering.closeTurn(player)
	-- No total: nothing is raised, and the misses so far use the meet allowance (§33.3b). Saved at once,
	-- while the player's data is still loaded.
	if not current.final then
		saveLifter(current, lifter, nil, {}, nil)
	end
	LiftAttemptService.abandon(player)
	LiftAttemptService.setFreeAttemptsBlocked(player, false)
	endLift(lifter)
	stopChalk(lifter)
	if lifter.hall.state then
		offSeat(lifter)
		StateArenaVenue.setCompetitor(player, false)
	end
	if player.Parent then
		player:SetAttribute(LocalMeetConfig.PlatformAttribute, nil)
	end
	release(player)
	-- Off the platform: the doorways are closed to anyone walking back by themselves.
	standAt(player, lifter.platform.waitSpot, false)
	-- (A State rack's staff and lights stay for the others on it.)
	if not lifter.hall.state then
		LocalMeetVenue.clearStaff(lifter.platform)
		LocalMeetVenue.setLights(lifter.platform, nil)
		LocalMeetVenue.setStageLight(lifter.platform, 1)
	end
	lifter.recordAttempt = nil
	boardFor(lifter, { "WITHDRAWN" })
	log("%s withdrew from the meet (%s)", player.Name, why)
	if not current.final then
		updateStandings(current)
	end
end

--[[
	One lifter's lift in a round (§37.5): out at the bar (the walk out), set
	up, the unrack (squat: step back; bench: get steady; deadlift: set), the
	head referee's start command, then the lift itself: a player's minigames,
	or a computer lifter's stages over its lift time. No LIFT button: the lift
	starts by itself once the lifter is ready at the bar. Records the verdict.
]]
--[[
	People yell the lifter on from the walk out to the verdict (§37.5, user 2026-11-05),
	players and computer lifters alike: the crowd every so often and a single voice from
	`shouts` between. Sound only. Replaces whatever was running for this lifter; nil just
	stops it. It also stops if the lifter leaves. PERFORMANCE: about one small message a
	second per lifter, only during their turn; each client spaces out the shouts it plays
	from other platforms. The higher the attempt's stakes level, the louder and the closer
	together (LocalMeetConfig.StakesBuild).
]]
local function crowdBehind(lifter: Lifter, shouts: { string }?)
	if lifter.stopCrowd then
		lifter.stopCrowd()
		lifter.stopCrowd = nil
	end
	if shouts == nil then
		return
	end
	local settings = MeetSoundConfig.LiftCrowd
	local build = LocalMeetConfig.StakesBuild
	local level = lifter.stakesLevel or 1
	local gap = build.ShoutGapSeconds[level]
	local active = true
	local stopAt = os.clock() + (lifter.walkOutSeconds or WALK_OUT_TIMEOUT_SECONDS) + UNRACK_ALLOWANCE_SECONDS + LIFT_TIMEOUT_SECONDS
	lifter.stopCrowd = function()
		active = false
	end
	task.spawn(function()
		local nextCrowdAt = 0
		-- Every line once, in a random order, before any comes round again.
		local bag: { string } = {}
		while active and stillLifting(lifter) and os.clock() < stopAt do
			if os.clock() >= nextCrowdAt then
				soundCue(lifter, "LiftCrowd", build.CrowdVolume[level])
				nextCrowdAt = os.clock() + settings.CrowdEverySeconds
			end
			if #shouts > 0 then
				if #bag == 0 then
					bag = table.clone(shouts)
					cpuRandom:Shuffle(bag)
				end
				soundCue(lifter, table.remove(bag) :: string, build.ShoutVolume[level])
			end
			task.wait(cpuRandom:NextNumber(gap[1], gap[2]))
		end
	end)
end

-- The last attempt of the last lift: the meet's final attempt.
local function isMeetsLastAttempt(lift: string, attemptNumber: number): boolean
	return lift == MeetConfig.LiftOrder[#MeetConfig.LiftOrder] and attemptNumber >= MeetConfig.AttemptsPerLift
end

-- The lifter's place right now, or nil with no score yet. Set below, with the race.
local placeOf: (current: Meet, lifter: Lifter) -> number?

-- The lifter's best official meet lift in this class so far, or nil (a computer lifter has none).
local function officialBest(lifter: Lifter, lift: string): number?
	local player = lifter.player
	local data = player and PlayerDataService.getData(player)
	local build = data and ProfileOperations.getBuild(data, lifter.classLabel)
	local bests = build and (build :: any).officialMeetBest
	local best = if typeof(bests) == "table" then bests[lift] else nil
	return if typeof(best) == "number" and best > 0 then best else nil
end

-- What a good lift just did, in a few words, or nil when it did nothing special (§37.5). Against how things stood before it.
local function momentAfter(current: Meet, lifter: Lifter, wasRecordAttempt: boolean, wasMustMake: boolean, weightKg: number,
	bestBefore: number?, placeBefore: number?, overLimit: boolean): string?
	if wasRecordAttempt then
		return "NEW GYM RECORD!"
	end
	if wasMustMake then
		return "STILL IN THE MEET!"
	end
	local placeNow = placeOf(current, lifter)
	if placeBefore and placeNow == 1 and placeBefore ~= 1 then
		return "TAKES THE LEAD!"
	end
	if overLimit then
		return "OVER THE LIMIT!"
	end
	if bestBefore and weightKg > bestBefore then
		return "NEW BEST!"
	end
	if placeBefore and placeNow and placeNow < placeBefore then
		return string.format("UP TO %s!", string.upper(placeText(placeNow)))
	end
	return nil
end

local function liftOne(current: Meet, lifter: Lifter, lift: string, attemptNumber: number, weightKg: number)
	local player = lifter.player
	local verdict: string? = nil
	-- Which part of the lift (minigame 1 or 2) a miss failed in: the fail animation shows it.
	local failedPart = 1
	waitUntil(lifter.walkOutSeconds or WALK_OUT_TIMEOUT_SECONDS, function()
		return not lifter.walking or not stillLifting(lifter)
	end)
	if not stillLifting(lifter) then
		return
	end
	lifter.walkToken = (lifter.walkToken or 0) + 1
	lifter.walking = false
	if lifter.liftAnim == nil then
		-- The walk timed out: straight to the bar.
		local approach = lifter.platform.rack and MeetLiftAnimation.approachFor(lifter.platform.rack, lift)
		if player and approach then
			standAt(player, approach, true)
		end
		setUpLift(lifter, lift)
	end
	-- The unrack, then the start command ("SQUAT!", "START!"; the deadlift has none: the lifter goes when ready).
	local commands = LocalMeetConfig.RefereeCommands[lift]
	if lift ~= "Deadlift" then
		task.delay(MeetLiftAnimation.unrackSoundIn(lifter.liftAnim), function()
			if stillLifting(lifter) then
				soundCue(lifter, "BarRack")
			end
		end)
	end
	waitUntil(MeetLiftAnimation.unrack(lifter.liftAnim), function()
		return not stillLifting(lifter)
	end)
	if not stillLifting(lifter) then
		return
	end
	local startCommand = commands and commands.phases[1]
	if startCommand then
		refereeCommand(lifter, startCommand)
		task.wait(COMMAND_BEAT_SECONDS)
		if not stillLifting(lifter) then
			return
		end
	end

	crowdBehind(lifter, MeetSoundConfig.liftShouts(lift, current.level))
	if player == nil then
		-- A computer lifter (§37.2): the same stages as a player's minigames, over its lift time; the server decides.
		lifter.liftsStarted += 1
		local seconds = ComputerLifters.liftSeconds(cpuRandom)
		local made = ComputerLifters.makes(attemptNumber, cpuRandom)
		local stages = { seconds * 0.7, seconds * 0.3 }
		-- A miss fails in either part, and stops partway through it (the fail animation takes over there).
		failedPart = cpuRandom:NextInteger(1, #stages)
		for index, stageSeconds in ipairs(stages) do
			MeetLiftAnimation.phase(lifter.liftAnim, index, stageSeconds)
			if index > 1 then
				refereeCommand(lifter, commands and commands.phases[index])
			end
			local failsHere = not made and index == failedPart
			task.wait(if failsHere then stageSeconds * CPU_FAIL_SHARE else stageSeconds)
			if not stillLifting(lifter) then
				return
			end
			if failsHere then
				break
			end
		end
		verdict = if made then "GoodLift" else "NoLift"
		if made and commands and commands.goodAtLockout then
			sayAtLockout(lifter, commands.good)
		end
	else
		-- The lift follows the minigame: each phase moves the animation through its stretch; the head referee gives
		-- the commands after the start (bench: PRESS) and the deadlift's DOWN at lockout.
		local function onPhase(event: string, index: number, count: number, seconds: number?, passed: boolean?, kind: string?,
			challenge: any)
			if not stillLifting(lifter) then
				return
			end
			-- The State meet's screens show the minigame live (§36.1).
			if current.hall.state and event == "start" and kind then
				MeetLiveScreens.phaseStart(player, lifter.platform.display.guis, { name = lifter.name, lift = lift,
					attemptNumber = attemptNumber, weightKg = weightKg }, kind, challenge)
			elseif current.hall.state and event == "end" and passed and index < count then
				MeetLiveScreens.phasePassed(player)
			end
			if event == "start" then
				failedPart = index
				lifter.livePhase = index
				-- The first phase follows the minigame's live progress (MeetLiftProgress); the second is the pause.
				MeetLiftAnimation.phase(lifter.liftAnim, index, seconds, index == 1)
				if index > 1 then
					refereeCommand(lifter, commands and commands.phases[index])
				end
			else
				lifter.livePhase = nil
				if passed then
					-- Passed: all the way through the stretch, whatever progress updates were still on the way.
					MeetLiftAnimation.progress(lifter.liftAnim, index, 1)
				end
				if passed and index == count and commands and commands.goodAtLockout then
					sayAtLockout(lifter, commands.good)
				end
			end
		end
		local ok, problem = LiftAttemptService.startServerAttempt(player, lift, weightKg, function(result)
			verdict = result
		end, onPhase)
		if ok then
			lifter.liftsStarted += 1
			sendState(lifter, "Lifting", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg })
			waitUntil(LIFT_TIMEOUT_SECONDS, function()
				return not stillLifting(lifter) or verdict ~= nil
			end)
			if not stillLifting(lifter) then
				return
			end
		else
			warn(string.format("[LocalMeetService] %s's %s attempt could not start: %s", player.Name, lift, tostring(problem)))
		end
	end
	crowdBehind(lifter, nil)
	local result: AttemptRules.AttemptResult = if verdict == "GoodLift" then "GoodLift" else "NoLift"
	local wasRecordAttempt = lifter.recordAttempt ~= nil
	-- The last attempt at this lift, with none made yet: a miss would have been a bomb-out.
	local wasMustMake = attemptNumber >= MeetConfig.AttemptsPerLift and bestOf(lifter, lift) == nil and not bombed(lifter)
	-- Only a meet that saves bests can set a new one.
	local bestBefore = if current.rewards then officialBest(lifter, lift) else nil
	local placeBefore = placeOf(current, lifter)
	-- The attempt is over: the sign comes down (a record it set shows in the facts once saved).
	lifter.recordAttempt = nil
	-- The crowd's chant for it stops (the cheer or the groan takes over).
	if lifter.hall.state and not lifter.hall.nationals then
		StateArenaShow.chant(lifter.platform.index, nil)
	elseif lifter.hall.nationals and nationalsHooks then
		(nationalsHooks :: NationalsHooks).chant(lifter.platform.index, nil)
	end
	local good = result == "GoodLift"
	if player then
		MeetLiveScreens.verdict(player, good)
		-- Everyone who filled the crowd's bar for a good lift gets its points in coins (§36.4).
		MeetCheering.result(player, good, weightKg)
	end
	-- A lift-off attempt (Nationals, §39) only decides a tie: it never counts toward the total, a best or a record.
	local liftOff = lifter.liftOffRound == true
	if not liftOff then
		table.insert(lifter.lifts[lift].history, { weightKg = weightKg, result = result })
	end
	lifter.lastResult, lifter.lastKg = result, weightKg
	local barLandsIn = finishLift(lifter, lift, good, failedPart, weightKg, attemptNumber)
	-- A lift over the normal limit counts for the total and the place, and pays coins at the end of the meet, but sets
	-- no best or record (§37.5).
	local overLimit = AttemptChoice.isOverLimit(lifter.competitionNumber[lift], weightKg)
	if good and not overLimit and not liftOff then
		saveOfficialBest(current, lifter, lift, weightKg)
	end
	local moment = if liftOff then (if good then "MADE IT!" else nil)
		elseif good then momentAfter(current, lifter, wasRecordAttempt, wasMustMake, weightKg, bestBefore, placeBefore, overLimit)
		else nil
	-- The minigames decide; the three referees show it.
	lifter.lights = if good then { "White", "White", "White" } else { "Red", "Red", "Red" }
	lifter.roundDone = true
	LocalMeetVenue.setLights(lifter.platform, lifter.lights)
	soundCue(lifter, if good then "LightsGood" else "LightsBad")
	-- The hall cheers the lights, and groans when the missed bar actually goes: more the more hung on it, and a big
	-- moment gets a second cheer.
	local build = LocalMeetConfig.StakesBuild
	local answer = build.AnswerVolume[lifter.stakesLevel or 1] * (if moment then build.BigMomentVolume else 1)
	local answerIn = MeetSoundConfig.CrowdDelaySeconds + barLandsIn
	task.delay(answerIn, soundCue, lifter, if good then "CrowdCheer" else "CrowdGroan", answer)
	if moment then
		task.delay(answerIn + build.SecondCheerSeconds, soundCue, lifter, "CrowdCheer", answer)
	end
	-- Then single voices over it (user 2026-11-05): the more hung on it, the more of them. A big moment gets its own first.
	local level = lifter.stakesLevel or 1
	local bag = table.clone(if good then MeetSoundConfig.goodShouts(current.level) else MeetSoundConfig.missShouts(current.level))
	cpuRandom:Shuffle(bag)
	local fitting = if moment then MeetSoundConfig.momentShouts(moment) else {}
	if #fitting > 0 then
		table.insert(bag, pick(fitting))
	end
	for voice = 1, math.min(build.ReactionVoices[level], #bag) do
		task.delay(answerIn + build.ReactionDelaySeconds + (voice - 1) * build.ReactionGapSeconds, soundCue, lifter,
			table.remove(bag) :: string, build.ShoutVolume[level])
	end
	-- A big made lift gets his big yell (third attempt, the lead, a place up: MeetCoachCalls, user 2026-11-25).
	LocalMeetVenue.coachSays(lifter.platform, (if good
		then require(script.Parent:WaitForChild("MeetCoachCalls")).bigYell(attemptNumber, moment)
		else nil) or pick(if good then COACH_GOOD else COACH_MISS))
	lifter.moment = moment
	boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber),
		string.format("%s KG  ·  %s", kgText(weightKg), if good then "GOOD LIFT" else "NO LIFT"), lightsText(lifter.lights) },
		if good then "good" else "bad")
	sendState(lifter, "Result", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg, verdict = result,
		lights = lifter.lights, moment = moment })
	log("%s %s attempt %d: %s kg %s (stakes level %d%s%s)", lifter.name, lift, attemptNumber, kgText(weightKg), result,
		lifter.stakesLevel or 1, if lifter.stakesLine then ", " .. lifter.stakesLine else "", if moment then " -> " .. moment else "")
	updateStandings(current)
	-- Rack the bar and walk away (§37.5): back to the warm-up room, while the others still lift. After a good lift
	-- soon after its finish; after a miss once its fail animation has played. A walk out that started meanwhile wins.
	local token = lifter.walkToken
	local finish = StationAnimationConfig.MeetStages[lift].finish
	-- (A miss: right after its own fail animation, not a flat ResultSeconds that left him standing frozen; user
	-- 2026-11-15.)
	local leaveIn = if good then finish[2] - finish[1] + LEAVE_AFTER_FINISH_SECONDS
		else (lifter.failSeconds or LocalMeetConfig.ResultSeconds) + MISS_WALK_BEAT_SECONDS
	task.delay(leaveIn, function()
		if current.hall.meet ~= current or current.final or not stillLifting(lifter) or lifter.walkToken ~= token then
			return
		end
		-- A good lift gets its celebration (CelebrationConfig.MeetLevels: every meet since user 2026-11-12), players and
		-- computer lifters alike, before they walk back to the bench; its camera shots at State only (no flashy cinematic
		-- at Local and Regional, to keep them quick).
		local player = lifter.player
		if good and CelebrationConfig.MeetLevels[current.level] then
			local cinematic = CelebrationConfig.CinematicMeetLevels[current.level] == true
			walkBack(lifter, function(): number
				if player then
					return CelebrationService.play(player.Character, CelebrationService.forPlayer(player, attemptNumber), player,
						cinematic)
				end
				return CelebrationService.play(lifter.body, CelebrationService.forComputer(lifter.body), nil)
			end)
			return
		end
		-- A miss, once its fail animation has played: he turns and walks off at once, a miss reaction (gestures, the yell)
		-- playing OVER the walk (user 2026-11-15: "fail, turn while walking hand gestures, scream";
		-- CelebrationConfig.MissReactions, arms and head only), players and computer lifters alike.
		local reaction = if not good and CelebrationConfig.MeetLevels[current.level] then CelebrationService.missReaction()
			else nil
		if reaction then
			walkBack(lifter, nil, function()
				CelebrationService.play(if player then player.Character else lifter.body, reaction :: string, player)
			end)
			return
		end
		walkBack(lifter)
	end)
end

-- ---------------------------------------------------------------- the race (user 2026-11-01)

type LiveScore = { lifter: Lifter, score: number, place: number }

-- Whether two lifters race each other: everyone does, but at Nationals only within a placing group (GAME_DESIGN §39: a
-- weight class, or everyone on points).
local function areRivals(current: Meet, a: Lifter, b: Lifter): boolean
	return not current.hall.nationals or groupOf(current, a) == groupOf(current, b)
end

-- Everyone's live points (on their best lifts so far), best first, with their place; at Nationals placed by class, the
-- subtotal in kilograms within `group` (a class label).
local function liveScores(current: Meet, group: string?): { LiveScore }
	local list: { LiveScore } = {}
	local byTotal = current.hall.nationals and not current.pointsMode
	for _, lifter in ipairs(current.lifters) do
		if not lifter.withdrawn and not bombed(lifter) and (group == nil or groupOf(current, lifter) == group) then
			local subtotal = 0
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				subtotal += bestOf(lifter, lift) or 0
			end
			local score = if subtotal <= 0 then nil elseif byTotal then subtotal
				else MeetPlacing.points(lifter.bodyweightKg, subtotal)
			if score then
				table.insert(list, { lifter = lifter, score = score, place = 0 })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	for index, entry in ipairs(list) do
		entry.place = index
	end
	return list
end

placeOf = function(current: Meet, lifter: Lifter): number?
	for _, entry in ipairs(liveScores(current, if current.hall.nationals then groupOf(current, lifter) else nil)) do
		if entry.lifter == lifter then
			return entry.place
		end
	end
	return nil
end

-- A lifter's subtotal if they make the weight they have declared this round (their best lifts so far otherwise).
local function subtotalIfMade(lifter: Lifter, lift: string): number
	local subtotal = 0
	for _, name in ipairs(MeetConfig.LiftOrder) do
		local best = bestOf(lifter, name) or 0
		subtotal += if name == lift then math.max(best, lifter.chosenKg or 0) else best
	end
	return subtotal
end

--[[
	What this attempt can do for `lifter` (MockMeetRemotes.RaceView): for each
	rival, the lightest weight on the meet's step that puts the lifter's score
	above theirs if both make the weight they declared (0 = ahead even if the
	lifter misses). Rivals with nothing yet and no declared weight don't count.
	Points compare totals across bodyweights, so the kilograms already include that
	sum: the player never has to work out any points.
]]
local function raceFor(current: Meet, lifter: Lifter, lift: string, attemptNumber: number): MockMeetRemotes.RaceView
	local step = LocalMeetConfig.WeightStepKg
	local others = 0
	for _, name in ipairs(MeetConfig.LiftOrder) do
		if name ~= lift then
			others += bestOf(lifter, name) or 0
		end
	end
	local bestHere = bestOf(lifter, lift) or 0
	local rivals: { MockMeetRemotes.RaceRival } = {}
	for _, other in ipairs(current.lifters) do
		if other ~= lifter and not other.withdrawn and not bombed(other) and areRivals(current, lifter, other) then
			local subtotal = subtotalIfMade(other, lift)
			local points = if subtotal > 0 then MeetPlacing.points(other.bodyweightKg, subtotal) else nil
			if points then
				-- My points beat theirs once my subtotal passes the total that gives their points at my bodyweight. At
				-- Nationals a class goes by kilograms: past their subtotal (an equal one is a tie, for a lift-off).
				local needSubtotal = if current.hall.nationals then subtotal
					else MeetPlacing.totalForPoints(lifter.bodyweightKg, points)
				local needKg = 0
				if others + bestHere <= needSubtotal + 1e-6 then
					needKg = (math.floor((needSubtotal - others) / step + 1e-6) + 1) * step
				end
				table.insert(rivals, { name = other.name, needKg = needKg, declaredKg = other.chosenKg })
			end
		end
	end
	return {
		place = placeOf(current, lifter),
		rivals = rivals,
		mustMake = bestHere <= 0 and attemptNumber >= MeetConfig.AttemptsPerLift,
		lastAttempt = isMeetsLastAttempt(lift, attemptNumber),
	}
end

-- How many rivals are ahead of the lifter, and how many of them making `weightKg` passes.
local function rivalsPassed(race: MockMeetRemotes.RaceView, weightKg: number): (number, number)
	local ahead, passed = 0, 0
	for _, rival in ipairs(race.rivals) do
		if rival.needKg > 0 then
			ahead += 1
			if weightKg >= rival.needKg then
				passed += 1
			end
		end
	end
	return ahead, passed
end

-- Whether making `weightKg` puts the lifter in first place, as things stand when they walk out (the crowd's LIFT OR LOSE).
local function liftForFirst(current: Meet, lifter: Lifter, lift: string, attemptNumber: number, weightKg: number): boolean
	if bombed(lifter) then
		return false
	end
	local ahead, passed = rivalsPassed(raceFor(current, lifter, lift, attemptNumber), weightKg)
	return ahead > 0 and passed == ahead
end

--[[
	What this attempt is for, in a few words, for the lifter's card (client
	MeetLiftMoment, §37.5), or nil when nothing special hangs on it, and whether it
	raises the attempt's stakes level. As things stand when they walk out: the others
	are lifting at the same time. On the meet's last attempt the lead is the win.
]]
local function stakesFor(current: Meet, lifter: Lifter, lift: string, attemptNumber: number, weightKg: number): (string?, boolean)
	if bombed(lifter) then
		return nil, false
	end
	if lifter.recordAttempt then
		return "FOR THE GYM RECORD", true
	end
	local race = raceFor(current, lifter, lift, attemptNumber)
	if race.mustMake then
		return "MUST MAKE IT FOR A TOTAL", true
	end
	local last = isMeetsLastAttempt(lift, attemptNumber)
	local ahead, passed = rivalsPassed(race, weightKg)
	if ahead > 0 and passed == ahead then
		return if last then "FOR THE WIN" else "TO TAKE THE LEAD", true
	end
	-- A new best only counts in a meet that saves it.
	local overLimit = AttemptChoice.isOverLimit(lifter.competitionNumber[lift], weightKg)
	local best = if current.rewards then officialBest(lifter, lift) else nil
	if best and weightKg > best and not overLimit then
		return "FOR A NEW BEST " .. string.upper(lift), true
	end
	if passed > 0 then
		local place = string.upper(placeText(ahead - passed + 1))
		return if last then "FOR " .. place .. " PLACE" else "TO MOVE UP TO " .. place, true
	end
	if overLimit then
		return "OVER THE LIMIT", true
	end
	if #race.rivals > 0 and ahead == 0 then
		return "LEADING THE MEET", false
	end
	return nil, false
end

-- How much hangs on this attempt (LocalMeetConfig.StakesBuild): which attempt it is, and one higher with something on it.
local function stakesLevelFor(lifter: Lifter, lift: string, attemptNumber: number, raises: boolean): number
	if bombed(lifter) then
		return 1
	end
	local level = math.clamp(attemptNumber, 1, MeetConfig.AttemptsPerLift)
	if raises or isMeetsLastAttempt(lift, attemptNumber) then
		level += 1
	end
	return math.min(level, #LocalMeetConfig.StakesBuild.CrowdVolume)
end

-- "a 25 kg bench" ("an 80 kg bench").
local function weightOf(kg: number, lift: string): string
	local whole = math.floor(kg)
	local an = string.sub(tostring(whole), 1, 1) == "8" or whole == 11 or whole == 18
	return string.format("%s %s kg %s", if an then "an" else "a", kgText(kg), string.lower(lift))
end

--[[
	What the coach tells their lifter as they choose (only that lifter sees it),
	the same thing THE RACE says at the top: a bomb-out warning first, then the
	weight that takes first, or the best place still in reach ("You need a 25 kg
	bench to take the lead."), after a rival's miss if one just missed ("Tess
	missed 30 kg!", user 2026-11-01), or that they lead.
]]
local function coachLineFor(current: Meet, lifter: Lifter, race: MockMeetRemotes.RaceView, lift: string, minKg: number,
	maxKg: number): string?
	if race.mustMake then
		return "Make this one or you bomb out. Play it safe!"
	end
	local ahead: { MockMeetRemotes.RaceRival } = {}
	for _, rival in ipairs(race.rivals) do
		if rival.needKg > 0 then
			table.insert(ahead, rival)
		end
	end
	table.sort(ahead, function(a, b)
		return a.needKg < b.needKg
	end)
	if #ahead == 0 then
		return if #race.rivals > 0 then "You're in the lead. Don't give it away!" else nil
	end
	local line: string
	local topKg = math.max(ahead[#ahead].needKg, minKg)
	if topKg <= maxKg then
		local goal = if race.lastAttempt then "win the meet" elseif race.place == 1 then "stay in the lead" else "take the lead"
		line = string.format("You need %s to %s.", weightOf(topKg, lift), goal)
	else
		line = "1st is out of reach this attempt. Lock in your spot."
		for index = #ahead - 1, 1, -1 do
			local needKg = math.max(ahead[index].needKg, minKg)
			if needKg <= maxKg then
				line = string.format("1st is out of reach. Try %s for %s.", weightOf(needKg, lift), placeText(#ahead - index + 1))
				break
			end
		end
	end
	-- A rival ahead who just missed comes first.
	for _, other in ipairs(current.lifters) do
		if other ~= lifter and other.lastResult == "NoLift" and other.lastKg then
			for _, rival in ipairs(ahead) do
				if rival.name == other.name then
					return string.format("%s missed %s kg! %s", other.name, kgText(other.lastKg), line)
				end
			end
		end
	end
	return line
end

--[[
	A lifter's entrance (GAME_DESIGN §36.4, user 2026-11-08): a player's own walk-out in this attempt's slot
	(`attemptNumber`, LoadoutConfig, user 2026-11-12), a computer lifter's walk style picked at random once per meet.
]]
local function entranceOf(lifter: Lifter, attemptNumber: number): EntranceConfig.Entrance?
	local player = lifter.player
	if player then
		return EntranceConfig.get(PlayerDataService.getEntrance(player, attemptNumber))
	end
	if lifter.entranceId == nil then
		lifter.entranceId = MeetEntrance.randomComputerId()
	end
	return EntranceConfig.get(lifter.entranceId)
end

-- A rack's caller (user 2026-11-06): the words over their head, nil to say nothing. `aloud`: what they say over the speakers
-- (client MeetCallerVoice).
local function callerSays(platform: LocalMeetVenue.Platform, line: string?, aloud: string?)
	MeetFigures.say(platform.callerLine, line)
	local caller = platform.caller
	if caller and aloud then
		caller:SetAttribute(StateArenaConfig.CallerLineAttribute, aloud)
	end
end

-- One round: everyone chooses, everyone lifts, the lights show. `group`: only these lifters (a State rack, running beside the others).
-- The State meet's lifting order board shows at most this many lifters.
local ORDER_BOARD_LINES = 5

--[[
	Nationals (GAME_DESIGN §39, user 2026-11-17): a chalked-up lifter walks round to stand right behind their platform's
	curtain, in a "flow state", rocking (NationalsConfig.FlowAnimationId), while the crowd's chant builds, until they click
	anywhere on the screen to step onto the platform (the ready remote), or CURTAIN_WAIT_SECONDS run out. Then the walk
	out (liftGroup) starts from there.
]]
local function waitBehindCurtain(current: Meet, lifter: Lifter, lift: string, attemptNumber: number, weightKg: number)
	local platform = lifter.platform
	local spot = platform.curtainSpot
	local hooks = nationalsHooks
	if spot == nil or not stillLifting(lifter) then
		return
	end
	stopChalk(lifter)
	MeetFigures.showClipboard(LocalMeetVenue.coachFigure(platform), true)
	lifter.coachHere = false
	LocalMeetVenue.coachSays(platform, nil)
	walkLifter(lifter, {}, spot, true)
	waitUntil(WALK_BACK_TIMEOUT_SECONDS, function()
		return not lifter.walking or not stillLifting(lifter)
	end)
	if not stillLifting(lifter) then
		return
	end
	if hooks then
		hooks.behindCurtain(platform.index, lifter.name, lifter.classLabel)
		hooks.chant(platform.index, lift, liftForFirst(current, lifter, lift, attemptNumber, weightKg))
	end
	local flow = MeetChalk.play(characterOf(lifter), NationalsConfig.FlowAnimationId)
	lifter.readyPressed = false
	-- (STUDIO TEST ONLY: the workspace attribute "StudioCurtainWaitSeconds" holds them there longer, to look at the
	-- cinematic's shots; Studio's screen capture lands seconds late.)
	local studioWait = if RunService:IsStudio() then Workspace:GetAttribute("StudioCurtainWaitSeconds") else nil
	local waitSeconds = if typeof(studioWait) == "number" then studioWait else CURTAIN_WAIT_SECONDS
	sendState(lifter, "Waiting", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg,
		note = "Behind the curtain. Get in the zone.", curtain = { secondsLeft = waitSeconds } })
	waitUntil(waitSeconds, function()
		return lifter.readyPressed or not stillLifting(lifter)
	end)
	MeetChalk.stop(flow)
	if hooks then
		hooks.behindCurtain(platform.index, nil, nil)
	end
	-- Parting the curtain (user 2026-11-18: "they are seen using their arms and moving the curtain to enter the platform"):
	-- the hands go into the split, then the walk out starts underneath (arms, chest and head only), pushing through it.
	-- The curtain's halves swing apart on every screen as they go (NationalsCurtains).
	if stillLifting(lifter) then
		local part = MeetChalk.play(characterOf(lifter), NationalsConfig.CurtainPartAnimationId)
		if part then
			part.Looped = false
			-- (Length is 0 until the animation has loaded: the clip is 1.8 s.)
			task.delay(math.max(part.Length, 1.8) + 1, function()
				part:Destroy()
			end)
		end
		task.wait(NationalsConfig.CurtainPartLeadSeconds)
	end
end

local function runRound(current: Meet, lift: string, attemptNumber: number, group: { Lifter }?)
	current.heading = string.format("%s  ·  ROUND %d", string.upper(lift), attemptNumber)
	updateStandings(current)
	local function inThisRound(): { Lifter }
		local list: { Lifter } = {}
		for _, lifter in ipairs(activeLifters(current)) do
			if group == nil or table.find(group, lifter) then
				table.insert(list, lifter)
			end
		end
		return list
	end

	-- Choose. Computer lifters declare first, so the race can count what they're going for.
	local choosing: { Lifter } = {}
	for _, lifter in ipairs(inThisRound()) do
		lifter.choice, lifter.chosenKg, lifter.readyPressed, lifter.roundDone, lifter.lights = nil, nil, false, false, nil
		lifter.announcedKg, lifter.recordAttempt = nil, nil
		lifter.currentLift = lift
		if lifter.player == nil then
			local cn, history = lifter.competitionNumber[lift], lifter.lifts[lift].history
			local _, default = AttemptChoice.nextWeights(cn, history, LocalMeetConfig.WeightStepKg,
				LocalMeetConfig.OpenerSuggestionPercent)
			if default then
				-- (Section 37.2) At once.
				lifter.chosenKg = ComputerLifters.nextWeight(cn, history, attemptNumber) or default
			end
		end
	end
	local chooseStarted = os.clock()
	local chooseEnds = chooseStarted + LocalMeetConfig.ChooseSeconds
	-- The State meet (user 2026-11-06): everyone chooses, wherever they are, then the rack lifts in turn, lightest bar first, each
	-- chalking up when their turn comes.
	local turns = current.hall.state
	if turns and group and group[1] then
		callerSays(group[1].platform, string.format("%s, ROUND %d. PICK YOUR WEIGHTS!", string.upper(lift), attemptNumber))
		local board = group[1].platform.orderBoard
		if board then
			board(string.format("%s  ·  ROUND %d", string.upper(lift), attemptNumber), { "CHOOSING WEIGHTS..." })
		end
	end
	local function chalkView(lifter: Lifter): MockMeetRemotes.ChalkView
		local platform = lifter.platform
		return { at = platform.chalkCentre, out = platform.chalkOut, coach = LocalMeetVenue.coachFigure(platform) }
	end
	-- The chalk camera, while they choose: at a meet with turns it waits for their turn.
	local function choosingChalk(lifter: Lifter): MockMeetRemotes.ChalkView?
		return if turns then nil else chalkView(lifter)
	end
	-- Puts the weight choice on a player's screen with the race as it stands, and the coach's word on it.
	local function offerChoice(lifter: Lifter, minKg: number, maxKg: number, default: number)
		local secondsLeft = math.max(1, chooseEnds - os.clock())
		if bombed(lifter) then
			-- No total any more: no race to show.
			sendState(lifter, "Choose", { lift = lift, attemptNumber = attemptNumber, minKg = minKg, maxKg = maxKg,
				suggestedKg = default, secondsLeft = secondsLeft, chalk = choosingChalk(lifter) })
			if not turns then
				coachTell(lifter, "No total today. Use these lifts as practice.")
			end
		else
			-- The race: what this attempt can do, in kilograms, and the coach's word on it (only they see it).
			local race = raceFor(current, lifter, lift, attemptNumber)
			sendState(lifter, "Choose", { lift = lift, attemptNumber = attemptNumber, minKg = minKg, maxKg = maxKg,
				suggestedKg = default, secondsLeft = secondsLeft, race = race, chalk = choosingChalk(lifter) })
			if not turns then
				coachTell(lifter, coachLineFor(current, lifter, race, lift, minKg, maxKg))
			end
		end
	end
	for _, lifter in ipairs(inThisRound()) do
		-- The rack set up for this lift, like a gym training rack (§37.5): no bench for squat and deadlift.
		LocalMeetVenue.rackFor(lifter.platform, lift)
		local cn = lifter.competitionNumber[lift]
		local history = lifter.lifts[lift].history
		-- A real lifter may go over the normal limit (§37.5), so they're never stuck passing; a computer lifter stays under.
		local minKg, default = AttemptChoice.nextWeights(cn, history, LocalMeetConfig.WeightStepKg,
			LocalMeetConfig.OpenerSuggestionPercent, lifter.player ~= nil)
		if minKg == nil or default == nil then
			-- No heavier weight is allowed inside the bounds: the attempt is passed.
			lifter.lifts[lift].passed += 1
			lifter.roundDone = true
			sendState(lifter, "Waiting", { lift = lift, attemptNumber = attemptNumber,
				note = "Attempt passed: no heavier weight is allowed. Waiting for the other lifters." })
			boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber), "PASSED" })
		else
			lifter.defaultKg = default
			table.insert(choosing, lifter)
			if not turns then
				startChalk(lifter, lift)
			end
			if lifter.player then
				local _, maxKg = AttemptChoice.meetBounds(cn, LocalMeetConfig.WeightStepKg)
				offerChoice(lifter, minKg, maxKg, default)
			end
			boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber), "CHOOSING A WEIGHT" })
		end
	end
	-- A player's declared weight changes the race for anyone still choosing.
	local function refreshRaces()
		for _, lifter in ipairs(choosing) do
			if lifter.player and lifter.chosenKg == nil and stillLifting(lifter) then
				local cn = lifter.competitionNumber[lift]
				local minKg, default = AttemptChoice.nextWeights(cn, lifter.lifts[lift].history, LocalMeetConfig.WeightStepKg,
					LocalMeetConfig.OpenerSuggestionPercent, true)
				if minKg and default then
					local _, maxKg = AttemptChoice.meetBounds(cn, LocalMeetConfig.WeightStepKg)
					offerChoice(lifter, minKg, maxKg, default)
				end
			end
		end
	end
	waitUntil(LocalMeetConfig.ChooseSeconds, function()
		local everyone = true
		for _, lifter in ipairs(choosing) do
			if stillLifting(lifter) and lifter.chosenKg == nil then
				local requested = lifter.choice
				if requested ~= nil then
					lifter.choice = nil
					local kg, problem = AttemptChoice.check(lifter.competitionNumber[lift], lifter.lifts[lift].history,
						LocalMeetConfig.WeightStepKg, requested, true)
					if kg then
						lifter.chosenKg = kg
						task.spawn(announceAttempt, current, lifter, lift, kg)
						sendState(lifter, "Waiting", { lift = lift, attemptNumber = attemptNumber, declaredKg = kg,
							note = string.format("%s kg declared. Waiting for the other lifters to choose.", kgText(kg)),
							chalk = choosingChalk(lifter) })
						refreshRaces()
					elseif lifter.player then
						notify(lifter.player, problem or "That weight is not allowed.")
					end
				end
				if lifter.chosenKg == nil then
					everyone = false
				end
			end
		end
		return everyone
	end)
	-- Everyone gets to be seen chalking up, however fast they chose.
	local chalkLeft = chooseStarted + LocalMeetConfig.Chalk.MinSeconds - os.clock()
	if chalkLeft > 0 and not turns then
		task.wait(chalkLeft)
	end
	-- A weight left to the default (time ran out) counts for everyone's stakes below.
	for _, lifter in ipairs(choosing) do
		if stillLifting(lifter) then
			lifter.chosenKg = lifter.chosenKg or lifter.defaultKg or 0
		end
	end

	-- Lift: this group on their own platforms at once; each walks out, sets up and lifts on the referee's command.
	local function liftGroup(group: { Lifter })
		local lifting: { Lifter } = {}
		for _, lifter in ipairs(group) do
			if stillLifting(lifter) then
				local weightKg = lifter.chosenKg or lifter.defaultKg or 0
				lifter.chosenKg = weightKg
				LocalMeetVenue.loadBar(lifter.platform, weightKg)
				-- A weight left to the default (time ran out) can be a record attempt too.
				task.spawn(announceAttempt, current, lifter, lift, weightKg)
				lifter.readyPressed = false
				LocalMeetVenue.setLights(lifter.platform, nil)
				-- How much hangs on it sets the crowd, the stage light and the lifter's camera (LocalMeetConfig.StakesBuild).
				local stakes, raises = stakesFor(current, lifter, lift, attemptNumber, weightKg)
				lifter.stakesLevel, lifter.stakesLine = stakesLevelFor(lifter, lift, attemptNumber, raises), stakes
				LocalMeetVenue.setStageLight(lifter.platform, LocalMeetConfig.StakesBuild.StageLight[lifter.stakesLevel])
				-- The walk out from the warm-up room straight in to the bar (§37.5: the rack faces the entrance), then set
				-- up for the lift.
				lifter.outOnPlatform = true
				-- At State, on a third attempt, the arena's crowd stomps, claps and chants until the lift's result (§36.4,
				-- MeetChant, user 2026-11-10): LIFT OR LOSE when making it puts them first, else the lift's own chant. At a
				-- meet with turns it started already while they chalked up (below); here it starts for a meet without turns.
				if current.hall.state and not current.hall.nationals and attemptNumber >= MeetConfig.AttemptsPerLift then
					StateArenaShow.chant(lifter.platform.index, lift,
						liftForFirst(current, lifter, lift, attemptNumber, weightKg))
				end
				-- Hands chalked: the lifter walks out first, and the coach follows behind to watch (user 2026-11-07).
				stopChalk(lifter)
				MeetFigures.showClipboard(LocalMeetVenue.coachFigure(lifter.platform), true)
				lifter.coachHere = false
				LocalMeetVenue.coachSays(lifter.platform, nil)
				-- (Their word for the lifter once there, not on the way through the doorway, where the wall would cut it off.)
				task.delay(LocalMeetConfig.CoachFollowSeconds, function()
					if stillLifting(lifter) and lifter.outOnPlatform then
						coachWalk(lifter, lifter.platform.coachDoorSpot, function()
							-- A third attempt that decides places gets his scream instead (MeetCoachCalls, user 2026-11-25).
							LocalMeetVenue.coachSays(lifter.platform, require(script.Parent:WaitForChild("MeetCoachCalls"))
								.walkOut(lifter.stakesLine, attemptNumber, isMeetsLastAttempt(lift, attemptNumber),
									placeOf(current, lifter)) or pick(COACH_READY))
						end)
					end
				end)
				-- The crowd starts as they step out (user 2026-11-05), with its own lines until the lift starts.
				crowdBehind(lifter, MeetSoundConfig.walkOutShouts(current.level))
				local approach = lifter.platform.rack and MeetLiftAnimation.approachFor(lifter.platform.rack, lift)
				local final = approach or lifter.platform.liftSpot
				-- Their entrance (§36.4): their walk style out to the bar, then at State and up their hype move there; at
				-- Local and Regional the quick clap and belt tap over the last steps instead (user 2026-11-08), no longer.
				local entrance = entranceOf(lifter, attemptNumber)
				local walkId, walkSpeed = MeetEntrance.walkOf(entrance)
				local hype = if EntranceConfig.HypeMeetLevels[current.level] then entrance else nil
				local touch = if hype == nil then EntranceConfig.QuickTouch else nil
				local character = characterOf(lifter)
				local route = { if character then ComputerLifters.positionOf(character).Position else final.Position }
				for _, point in ipairs(lifter.platform.walkOut) do
					table.insert(route, point)
				end
				table.insert(route, final.Position)
				-- The walk style from the banner (State) or the doorway (Local, Regional) all the way to the bar.
				local styleStuds = MeetEntrance.styleStudsFrom(route, lifter.platform.styleFrom)
				lifter.walkOutSeconds = math.max(WALK_OUT_TIMEOUT_SECONDS, MeetEntrance.walkOutSeconds(route, walkSpeed,
					LocalMeetConfig.ComputerLifters.WalkSpeed, styleStuds) + MeetEntrance.hypeSeconds(hype) + 3)
				-- The spotters stand aside for the entrance (user 2026-11-12: "make sure any spotters or loaders are not
				-- in the way of entrances"), out of the walk-out's shots, until the lifter is set up at the bar.
				LocalMeetVenue.clearSpotters(lifter.platform, lifter.walkOutSeconds,
					if current.hall.state then "StateWalkOut" else nil)
				walkLifter(lifter, lifter.platform.walkOut, final, true, function()
					local token = lifter.walkToken
					MeetEntrance.playHype(characterOf(lifter), hype)
					-- (A walk out that ran out of time has already set them up at the bar.)
					if lifter.walkToken == token and lifter.liftAnim == nil and stillLifting(lifter) then
						setUpLift(lifter, lift)
					end
				end, {
					animationId = walkId,
					speed = walkSpeed,
					styleStuds = styleStuds,
					touchAnimationId = if touch and touch.animationId ~= "" then touch.animationId else nil,
					touchSeconds = if touch then touch.seconds else nil,
					onTouch = if touch then function()
						for _, at in ipairs(touch.clapSeconds) do
							task.delay(at, soundCue, lifter, "ChalkClap", touch.clapVolume)
						end
					end else nil,
				})
				boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber),
					string.format("BAR LOADED  ·  %s KG", kgText(weightKg)) })
				sendState(lifter, "Ready", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg,
					autoLift = true, stakes = stakes, stakesLevel = lifter.stakesLevel, walkOutShot = turns })
				table.insert(lifting, lifter)
				task.spawn(liftOne, current, lifter, lift, attemptNumber, weightKg)
			end
		end
		local walkOutSeconds = WALK_OUT_TIMEOUT_SECONDS
		for _, lifter in ipairs(lifting) do
			walkOutSeconds = math.max(walkOutSeconds, lifter.walkOutSeconds or 0)
		end
		waitUntil(walkOutSeconds + UNRACK_ALLOWANCE_SECONDS + LIFT_TIMEOUT_SECONDS + 2, function()
			for _, lifter in ipairs(lifting) do
				if stillLifting(lifter) and not lifter.roundDone then
					return false
				end
			end
			return true
		end)

		-- The last verdict stays up for a moment before the next round.
		task.wait(LocalMeetConfig.ResultSeconds)
		-- Everyone is back in the warm-up room before anyone chooses their next attempt (user 2026-11-04).
		waitUntil(WALK_BACK_TIMEOUT_SECONDS, function()
			for _, lifter in ipairs(lifting) do
				if stillLifting(lifter) and lifter.outOnPlatform then
					return false
				end
			end
			return true
		end)
		for _, lifter in ipairs(lifting) do
			LocalMeetVenue.coachSays(lifter.platform, nil)
		end
	end

	if not turns then
		liftGroup(choosing)
		return
	end
	-- One at a time on this rack, lightest bar first (GAME_DESIGN §36.4), ties in the order they lift in.
	local order = table.clone(choosing)
	table.sort(order, function(a: Lifter, b: Lifter)
		local aKg, bKg = a.chosenKg or 0, b.chosenKg or 0
		return if aKg ~= bKg then aKg < bKg else a.order < b.order
	end)
	for position, lifter in ipairs(order) do
		if stillLifting(lifter) then
			local weightKg = lifter.chosenKg or 0
			-- The caller: who is up, on deck and in the hole. The next lifters still with us, in order.
			local coming: { Lifter } = {}
			for other = position + 1, #order do
				if stillLifting(order[other]) then
					table.insert(coming, order[other])
				end
			end
			local platform = lifter.platform
			local calls = { string.format("UP: %s, %s KG", lifter.name, kgText(weightKg)) }
			if coming[1] then
				table.insert(calls, "ON DECK: " .. coming[1].name)
			end
			if coming[2] then
				table.insert(calls, "IN THE HOLE: " .. coming[2].name)
			end
			-- Out loud too, with whatever name each lifter goes by.
			local spoken = { lifter.name .. ", you're up." }
			if coming[1] then
				table.insert(spoken, "On deck, " .. coming[1].name .. ".")
			end
			if coming[2] then
				table.insert(spoken, "In the hole, " .. coming[2].name .. ".")
			end
			callerSays(platform, table.concat(calls, "\n"), table.concat(spoken, " "))
			-- The lifting order board behind the rack: this lifter and the next ones, as many as fit.
			local board = platform.orderBoard
			if board then
				local places = { "UP", "ON DECK", "IN THE HOLE" }
				local lines = { string.format("UP  ·  %s  ·  %s KG", lifter.name, kgText(weightKg)) }
				for place, upcoming in ipairs(coming) do
					if #lines >= ORDER_BOARD_LINES then
						break
					end
					table.insert(lines, string.format("%s  ·  %s  ·  %s KG", places[place + 1] or string.format("%d.", place + 1),
						upcoming.name, kgText(upcoming.chosenKg or 0)))
				end
				board(string.format("%s  ·  ROUND %d", string.upper(lift), attemptNumber), lines)
			end
			-- Everyone else on the rack hears where they stand, wherever they have got to.
			for other = 1, #order do
				local waiting = order[other]
				if other ~= position and stillLifting(waiting) then
					local left = table.find(coming, waiting)
					sendState(waiting, "Waiting", { lift = lift, attemptNumber = attemptNumber, declaredKg = waiting.chosenKg,
						note = string.format("%s is lifting %s kg. %s", lifter.name, kgText(weightKg),
							if left == 1 then "You are ON DECK." elseif left == 2 then "You are IN THE HOLE."
								elseif left then string.format("You lift in %d turns. Practise at a warm-up rack if you like.", left)
								else "You have lifted this round. Practise at a warm-up rack if you like.") })
					if left and left <= 2 and waiting.player then
						notify(waiting.player, if left == 1 then "You are ON DECK. Your turn is next." else "You are IN THE HOLE.")
					end
				end
			end
			-- The rack's screen, staff tags and coach go to this lifter.
			lifter.onTurn = true
			for other = 1, #order do
				order[other].onScreen = order[other] == lifter
			end
			LocalMeetVenue.staffFor(platform, lifter.player)
			-- Their rack is spotlit in the dark arena, from now until they sit back down (StateArenaShow).
			if not current.hall.nationals then
				StateArenaShow.rackActive(platform.index, true)
			end
			lifter.moment = nil
			-- The crowd can cheer them on from this rack's watching zones (§36.4), from now until their lift is over. A full
			-- bar gets a roar from the crowd.
			local cheered = lifter.player
			if cheered and Once.CheerConfig.MeetLevels[current.level] then
				MeetCheering.openTurn(platform.index, cheered, lifter.name, lift, lifter.bodyweightKg, current.rewards, function()
					if stillLifting(lifter) then
						soundCue(lifter, "CrowdCheer", MeetSoundConfig.LiftCrowd.RoarVolume)
						local shouts = MeetSoundConfig.liftShouts(lift, current.level)
						if #shouts > 0 then
							task.delay(0.4, soundCue, lifter, pick(shouts), MeetSoundConfig.LiftCrowd.RoarVolume)
						end
					end
				end)
			end
			-- Their bar, ready while they chalk up.
			LocalMeetVenue.loadBar(platform, weightKg)
			boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber),
				string.format("%s KG  ·  UP NEXT", kgText(weightKg)) })
			bringBack(lifter)
			if stillLifting(lifter) then
				-- The coach's ritual before the walk out (§36.4, user 2026-11-11): every turn at State and up.
				local ritual = LocalMeetConfig.Ritual
				local withRitual = ritual.MeetLevels[current.level] == true
				startChalk(lifter, lift, withRitual)
				-- On a third attempt the State crowd starts its chant as they chalk up (user 2026-11-10), until the result.
				if current.hall.state and not current.hall.nationals and attemptNumber >= MeetConfig.AttemptsPerLift then
					StateArenaShow.chant(platform.index, lift, liftForFirst(current, lifter, lift, attemptNumber, weightKg))
				end
				coachTell(lifter, pick(COACH_READY))
				local ritualView: MockMeetRemotes.RitualView? = nil
				if withRitual then
					local sendOffLine = pick(ritual.SendOffLines)
					ritualView = { startedAt = now(), coachLine = lifter.coachLine, sendOffLine = sendOffLine }
					task.delay(ritual.CoachMoveAt, coachSendOff, lifter, sendOffLine)
				end
				sendState(lifter, "Waiting", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg,
					note = "You're up. Chalk your hands.", chalk = chalkView(lifter), ritual = ritualView })
				task.wait(if withRitual then ritual.Seconds else LocalMeetConfig.Chalk.MinSeconds)
				-- Nationals (GAME_DESIGN §39, user 2026-11-17): chalked up, they wait right behind the curtain while the
				-- crowd's chant builds, until they click to step onto the platform.
				if current.hall.nationals then
					waitBehindCurtain(current, lifter, lift, attemptNumber, weightKg)
				end
				liftGroup({ lifter })
				lifter.onTurn = false
				sitLifter(lifter, true)
			end
			if cheered then
				MeetCheering.closeTurn(cheered)
			end
			if not current.hall.nationals then
				StateArenaShow.rackActive(platform.index, false)
			end
		end
	end
end

-- Tells everyone in the venue the awards ceremony has started (the camera shots, the cheer, the theme song). At Nationals
-- one weight class's (`classLabel`), for `seconds`.
local function announceAwards(current: Meet, v: LocalMeetVenue.Venue, classLabel: string?, seconds: number?)
	local gold: CFrame? = v.podiumSpots[1]
	if remotes == nil or gold == nil then
		return
	end
	-- The theme and celebration are a real winner's; a computer lifter in 1st gets the stage without them.
	local winner: Player? = nil
	local winnerName: string? = nil
	local badge: ProfileOperations.ChampionBadgeView? = nil
	for _, lifter in ipairs(current.lifters) do
		local placing = current.places[lifter.key]
		local player = lifter.player
		if placing and placing.place == 1 and not lifter.withdrawn and player and visits[player]
			and (classLabel == nil or groupOf(current, lifter) == classLabel) then
			winner, winnerName = player, lifter.name
			badge = lifter.newBadge
		end
	end
	-- A National Champion: every platform's caller says it over the speakers (GAME_DESIGN §39); on points, no class.
	if current.hall.nationals and classLabel and winnerName then
		local aloud = if current.pointsMode then string.format("Please welcome your National Champion, %s!", winnerName)
			else string.format("Please welcome your %s National Champion, %s!", classLabel, winnerName)
		local bubble = if current.pointsMode then string.format("NATIONAL CHAMPION: %s!", string.upper(winnerName))
			else string.format("%s NATIONAL CHAMPION: %s!", string.upper(classLabel), string.upper(winnerName))
		for _, platform in ipairs(current.hall.venue.platforms) do
			callerSays(platform, bubble, aloud)
		end
	end
	-- A new State Champion badge: the caller of every rack in use says it over the speakers (each screen hears one).
	if badge and winnerName then
		local aloud = if badge.number > 0
			then string.format("Please welcome State Champion number %d, %s!", badge.number, winnerName)
			else string.format("Please welcome your State Champion, %s!", winnerName)
		local bubble = string.format("%s%s: %s!", if badge.number > 0 then string.format("#%d ", badge.number) else "",
			MeetLevelConfig.ChampionBadge.Name, string.upper(winnerName))
		for _, lifter in ipairs(current.lifters) do
			callerSays(lifter.platform, bubble, aloud)
		end
	end
	local moment: LocalMeetRemotes.AwardsMoment = {
		winnerUserId = winner and winner.UserId,
		winnerName = winnerName,
		winnerSpot = winner and gold,
		stageCentre = gold.Position,
		stageFacing = gold.LookVector,
		themeSoundId = winner and themeFor(winner),
		celebrationAnimationId = winner and celebrationFor(winner),
		championBadge = badge and { number = badge.number, seasonLabel = MeetLevelConfig.seasonLabel(badge.season),
			name = MeetLevelConfig.ChampionBadge.Name },
		seconds = seconds or LocalMeetConfig.DoneSeconds,
	}
	-- A placing toward Nationals at this meet: a card on that lifter's own screen only.
	local news: { [Player]: LocalMeetRemotes.NationalsNews } = {}
	for _, lifter in ipairs(current.lifters) do
		if lifter.player and lifter.nationalsNews then
			news[lifter.player] = lifter.nationalsNews
		end
	end
	local skippedEnd = (current :: any).endSkipped or {} -- skipped the end-of-meet scene and let go (MeetEndScene)
	for player, visit in pairs(visits) do
		if visit.hall == current.hall.index and not skippedEnd[player] then
			local mine = news[player]
			if mine then
				local own = table.clone(moment)
				own.nationals = mine
				remotes.awards:FireClient(player, own)
			else
				remotes.awards:FireClient(player, moment)
			end
		end
	end
end

--[[
	The coach's cutscene for a suit this lifter just won, once, however they leave: the end of the awards, or LEAVE, EXIT or the
	TELEPORT menu during them (user 2026-11-06: pressing LEAVE on the results skipped it). It waits a moment for any move to finish,
	and for a living body. A player who never sees it can still start the test from MY GEAR.
]]
local function showDroppedSuit(lifter: Lifter, player: Player)
	local suitId, pieceId = lifter.droppedSuit, lifter.droppedPiece
	if suitId == nil or pieceId == nil then
		return
	end
	lifter.droppedSuit, lifter.droppedPiece = nil, nil
	task.spawn(function()
		task.wait(DROP_SCENE_SETTLE_SECONDS)
		local giveUpAt = os.clock() + DROP_SCENE_WAIT_SECONDS
		while player.Parent and os.clock() < giveUpAt do
			local body = bodyOf(player)
			if body and body.humanoid.Health > 0 then
				GearService.playCutscene(player, suitId, pieceId)
				return
			end
			task.wait(0.25)
		end
	end)
end

-- Ends the meet: the final ranking, everyone's result, then the platforms are cleared.
-- The chance of a rare suit at this level of meet. Never anything but MeetLevelConfig's in a live game.
local function suitChance(level: string): number
	local override = if RunService:IsStudio() then Workspace:GetAttribute("StudioSuitDropChance") else nil
	return if typeof(override) == "number" then override else MeetLevelConfig.Levels[level].suitDropChance
end

--[[
	Rolls a lifter's rare suit (GAME_DESIGN §35.10, §35.12): once a meet, for a real lifter with a total, only at a meet that pays a
	prize pot, so nobody can farm them alone with computer lifters. Returns the suit's name when one dropped.
	An admin's panel can force their own next one (GearService.takeForcedDrop), at any meet. Studio only: the workspace
	attribute ForceSuitDrop (a suit's id) does the same for everyone, and StudioSuitDropChance (0 to 1) replaces the normal
	chance, to test the random path without touching MeetLevelConfig.
]]
local function rollSuit(current: Meet, lifter: Lifter, player: Player): string?
	local forced: any = GearService.takeForcedDrop(player)
	if forced == nil and RunService:IsStudio() then
		forced = Workspace:GetAttribute("ForceSuitDrop")
	end
	local suitId: string? = nil
	if typeof(forced) == "string" then
		suitId = forced
	-- (the lifter's luck from the cow's wheel raises or lowers the chance, up to LuckConfig.SuitLuckCap times it)
	elseif current.rewards and suitRandom:NextNumber() < LuckConfig.applyToChance(suitChance(current.level),
		PlayerDataService.luckMultiplier(player), LuckConfig.SuitLuckCap) then
		suitId = GearStatsConfig.Suits[suitRandom:NextInteger(1, #GearStatsConfig.Suits)].id
	end
	if suitId == nil then
		return nil
	end
	local pieceId = GearService.giveSuit(player, suitId, true)
	if pieceId == nil then
		return nil
	end
	lifter.droppedSuit, lifter.droppedPiece = suitId, pieceId
	for _, suit in ipairs(GearStatsConfig.Suits) do
		if suit.id == suitId then
			log("%s got the %s at a %s meet", player.Name, suit.name, current.level)
			return suit.name
		end
	end
	return nil
end

-- ---------------------------------------------------------------- the Nationals lift-off (GAME_DESIGN §39)

local runLiftOffs: (current: Meet) -> ()

--[[
	One lift-off attempt (user 2026-11-17): from wherever they are to the chalk stand, behind the curtain (the click to step
	out), out to the bar at `weightKg` and the lift itself (liftOne), then back. Returns whether it was a good lift. An
	attempt not started in time is a miss (Claude's guard).
]]
local function liftOffAttempt(current: Meet, lifter: Lifter, lift: string, weightKg: number, stakes: string): boolean
	if not stillLifting(lifter) then
		return false
	end
	local platform = lifter.platform
	lifter.liftOffRound = true
	lifter.roundDone, lifter.lights, lifter.readyPressed, lifter.lastResult = false, nil, false, nil
	lifter.currentLift, lifter.chosenKg, lifter.recordAttempt, lifter.moment = lift, weightKg, nil, nil
	lifter.onTurn = true
	lifter.onScreen = true
	LocalMeetVenue.staffFor(platform, lifter.player)
	LocalMeetVenue.rackFor(platform, lift)
	LocalMeetVenue.loadBar(platform, weightKg)
	LocalMeetVenue.setLights(platform, nil)
	callerSays(platform, string.format("LIFT-OFF: %s, %s %s KG", lifter.name, string.upper(lift), kgText(weightKg)),
		string.format("Lift-off. %s, you're up.", lifter.name))
	boardFor(lifter, { "LIFT-OFF", string.format("%s  ·  %s KG", string.upper(lift), kgText(weightKg)) })
	bringBack(lifter)
	if stillLifting(lifter) then
		startChalk(lifter, lift, false)
		sendState(lifter, "Waiting", { lift = lift, attemptNumber = MeetConfig.AttemptsPerLift, declaredKg = weightKg,
			note = "Lift-off: you're up. Chalk your hands." })
		task.wait(LocalMeetConfig.Chalk.MinSeconds)
		waitBehindCurtain(current, lifter, lift, MeetConfig.AttemptsPerLift, weightKg)
	end
	if not stillLifting(lifter) then
		lifter.liftOffRound, lifter.onTurn = false, false
		return false
	end
	stopChalk(lifter)
	lifter.outOnPlatform = true
	lifter.stakesLevel, lifter.stakesLine = #LocalMeetConfig.StakesBuild.StageLight, stakes
	LocalMeetVenue.setStageLight(platform, LocalMeetConfig.StakesBuild.StageLight[lifter.stakesLevel])
	crowdBehind(lifter, MeetSoundConfig.walkOutShouts(current.level))
	local approach = platform.rack and MeetLiftAnimation.approachFor(platform.rack, lift)
	local final = approach or platform.liftSpot
	local character = characterOf(lifter)
	local route = { if character then ComputerLifters.positionOf(character).Position else final.Position }
	for _, point in ipairs(platform.walkOut) do
		table.insert(route, point)
	end
	table.insert(route, final.Position)
	lifter.walkOutSeconds = math.max(WALK_OUT_TIMEOUT_SECONDS, MeetEntrance.walkOutSeconds(route, nil,
		LocalMeetConfig.ComputerLifters.WalkSpeed, 0) + 3)
	LocalMeetVenue.clearSpotters(platform, lifter.walkOutSeconds, "StateWalkOut")
	walkLifter(lifter, platform.walkOut, final, true, function()
		if lifter.liftAnim == nil and stillLifting(lifter) then
			setUpLift(lifter, lift)
		end
	end)
	sendState(lifter, "Ready", { lift = lift, attemptNumber = MeetConfig.AttemptsPerLift, declaredKg = weightKg,
		autoLift = true, stakes = stakes, stakesLevel = lifter.stakesLevel, walkOutShot = true })
	liftOne(current, lifter, lift, MeetConfig.AttemptsPerLift, weightKg)
	local good = lifter.lastResult == "GoodLift"
	task.wait(LocalMeetConfig.ResultSeconds)
	waitUntil(WALK_BACK_TIMEOUT_SECONDS, function()
		return not lifter.outOnPlatform or not stillLifting(lifter)
	end)
	LocalMeetVenue.coachSays(platform, nil)
	lifter.liftOffRound, lifter.onTurn = false, false
	sitLifter(lifter, true)
	return good and stillLifting(lifter)
end

-- After this many rounds in a row where everyone missed, the lighter lifter wins (Claude's guard: never endless).
local LIFT_OFF_ALL_MISS_LIMIT = 5

--[[
	The lift-off for lifters tied on total for a medal place in one class (user 2026-11-17, "sudden death"): each picks a
	lift (squat, bench or deadlift) and lifts their best in it + 2.5 kg, one at a time, lightest bar first. Everyone makes
	it: +2.5 kg each and again. Everyone misses: again at the same weights. Those who miss while others make it are out.
	Until one is left. Returns each lifter's finish (key -> 1 = won; lifters out in the same round share one).
]]
local function liftOff(current: Meet, group: { Lifter }, forPlace: number): { [number]: number }
	local label = group[1].classLabel
	local finish: { [number]: number } = {}
	local remote = remotes
	-- THE JUDGE (user 2026-11-18): first the tied lifters are told, together, by the head referee, who walks from the
	-- chair through the curtain's split to them (NationalsScenes; each tied lifter's own screen shows it as a cinematic).
	-- The judge looks over at them on their bench and they walk over to stand in front of the judge. Then the pick.
	local judge: NationalsScenes.LiftOffHandle? = nil
	-- (STUDIO TEST ONLY: with the workspace attribute "StudioLiftOffAtStart" one lifter alone gets the judge too, standing
	-- as one of two.)
	local needed = if RunService:IsStudio() and Workspace:GetAttribute("StudioLiftOffAtStart") == true then 1 else 2
	-- (whether this venue has a judge's way at all; the real spots come once the lifters sit, below)
	local spots: { CFrame }? = nil
	local judgeSpot: CFrame? = nil
	-- The tied lifters who walk over, in the order they stand (spot 1 first: nearest the chalk stand).
	local standers: { Lifter } = {}
	if remote then
		spots, judgeSpot = NationalsScenes.liftOffSpots(group[1].platform, { 0, 0 })
	end
	if remote and spots then
		local function stillOn(): boolean
			if current.hall.meet ~= current then
				return false
			end
			for _, lifter in ipairs(group) do
				if stillLifting(lifter) then
					return true
				end
			end
			return false
		end
		-- (anyone still on the way back from their last lift arrives first: no walking through the backdrop)
		waitUntil(WALK_BACK_TIMEOUT_SECONDS, function()
			for _, lifter in ipairs(group) do
				if stillLifting(lifter) and (lifter.outOnPlatform or lifter.walking) then
					return false
				end
			end
			return true
		end)
		local function settled(): boolean
			for _, lifter in ipairs(group) do
				if stillLifting(lifter) and lifter.walking then
					return false
				end
			end
			return true
		end
		-- They are on their benches when the judge comes through (user 2026-11-18: "the ref comes through, looks at the
		-- two lifters, then they go to him"): anyone up and about is walked back to their seat first.
		local players: { Player } = {}
		for _, lifter in ipairs(group) do
			local player = lifter.player
			if player and stillLifting(lifter) then
				table.insert(players, player)
				stopWarmUps(player)
				if LiftAttemptService.isAttemptActive(player) then
					LiftAttemptService.abandon(player)
				end
				sendState(lifter, "Waiting", { note = "Tied for a medal. The head judge is on the way.", stepTag = "LIFT-OFF",
					banner = "TIED FOR " .. string.upper(placeText(forPlace)) })
				local body = bodyOf(player)
				if lifter.seat and body and body.humanoid.SeatPart ~= lifter.seat then
					sitLifter(lifter, true)
				end
			end
		end
		waitUntil(WALK_BACK_TIMEOUT_SECONDS, settled)
		-- WHO STANDS WHERE (user 2026-11-18: "make sure they are shoulder to shoulder not inside each other, and make sure
		-- there is a separation between the walk"): in the order they sit along the bench, each on a spot as wide as
		-- their own body, so no two walks cross and nobody ends up inside a neighbour.
		local outward = group[1].platform.chalkOut
		local along: { [Lifter]: number } = {}
		for _, lifter in ipairs(group) do
			local player = lifter.player
			local body = if player and stillLifting(lifter) then bodyOf(player) else nil
			if body then
				table.insert(standers, lifter)
				along[lifter] = body.root.Position:Dot(outward)
			end
		end
		table.sort(standers, function(a: Lifter, b: Lifter)
			return along[a] < along[b]
		end)
		local widths: { number } = {}
		for _, lifter in ipairs(standers) do
			table.insert(widths, NationalsScenes.bodyWidth(characterOf(lifter)))
		end
		-- (the Studio test of one lifter: they stand as one of two)
		if #widths == 1 then
			table.insert(widths, widths[1])
		end
		if #widths >= 1 then
			spots, judgeSpot = NationalsScenes.liftOffSpots(group[1].platform, widths)
		end
		local standAts: { CFrame } = spots or {}
		-- The judge has looked over at them: they get up, step out to the lane in front of their seats and walk over to
		-- stand side by side in front of the judge, behind the curtain of the first one's platform (one from too far off
		-- is simply stood there).
		local function gather()
			-- One after another, the one whose spot is furthest along first: they walk the lane in a file.
			for index = #standers, 1, -1 do
				local lifter = standers[index]
				local player = lifter.player
				local spot = standAts[index]
				if index < #standers then
					task.wait(NationalsConfig.LiftOffScene.GatherStaggerSeconds)
				end
				if player and spot and stillLifting(lifter) then
					local way = offSeatWay(lifter, spot.Position)
					offSeat(lifter)
					local body = bodyOf(player)
					if body and (body.root.Position - spot.Position).Magnitude > StateArenaConfig.BringBackWalkStuds then
						lifter.walkToken = (lifter.walkToken or 0) + 1
						lifter.walking = false
						standAt(player, spot, true)
					else
						walkLifter(lifter, way, spot, true)
					end
				end
			end
			waitUntil(WALK_BACK_TIMEOUT_SECONDS, settled)
		end
		if #players >= needed and spots and judgeSpot and stillOn() then
			log("lift-off (%s, %s place): the judge walks to %d tied lifters", label, placeText(forPlace), #players)
			-- The hall hears there is a tie: the crowd comes up as the judge leaves the chair.
			soundCue(group[1], "CrowdCheer", 1.3)
			judge = NationalsScenes.liftOff({ platform = group[1].platform, players = players, place = forPlace,
				classLabel = label, totalKg = MeetTotal.resolve(meetAttempts(group[1])).total, spots = spots,
				judgeSpot = judgeSpot, widths = widths, gather = gather, remote = remote.scene, stillOn = stillOn })
		end
	end
	-- Their lifts: their pick, or else their strongest (the heaviest best of the three).
	local options: { [Lifter]: { { lift: string, weightKg: number } } } = {}
	for _, lifter in ipairs(group) do
		options[lifter] = {}
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			table.insert(options[lifter], { lift = lift, weightKg = (bestOf(lifter, lift) or 0) + LocalMeetConfig.WeightStepKg })
		end
		lifter.liftOffPick, lifter.liftOffChoosing = nil, true
		sendState(lifter, "Waiting", { note = "Tied for a medal: a lift-off! Pick your lift.", stepTag = "LIFT-OFF",
			banner = "TIED FOR " .. string.upper(placeText(forPlace)),
			liftOff = { place = forPlace, classLabel = label, secondsLeft = NationalsConfig.LiftOffChooseSeconds,
				options = options[lifter] } })
	end
	for _, platform in ipairs(current.hall.venue.platforms) do
		callerSays(platform, string.format("LIFT-OFF FOR %s PLACE IN %s!", string.upper(placeText(forPlace)), label),
			string.format("Ladies and gentlemen, we have a tie. A lift-off for %s place in the %s class!", placeText(forPlace),
				label))
	end
	current.heading = string.format("LIFT-OFF  ·  %s  ·  %s PLACE", label, string.upper(placeText(forPlace)))
	updateStandings(current)
	waitUntil(NationalsConfig.LiftOffChooseSeconds, function()
		for _, lifter in ipairs(group) do
			if stillLifting(lifter) and lifter.liftOffPick == nil then
				return false
			end
		end
		return true
	end)
	local liftOf: { [Lifter]: string } = {}
	local kgOf: { [Lifter]: number } = {}
	for _, lifter in ipairs(group) do
		lifter.liftOffChoosing = false
		local pick = lifter.liftOffPick
		if pick == nil then
			local heaviest = 0
			for _, option in ipairs(options[lifter]) do
				if option.weightKg > heaviest then
					heaviest, pick = option.weightKg, option.lift
				end
			end
		end
		for _, option in ipairs(options[lifter]) do
			if option.lift == pick then
				liftOf[lifter], kgOf[lifter] = option.lift, option.weightKg
			end
		end
		log("lift-off (%s, %s place): %s picks %s at %s kg", label, placeText(forPlace), lifter.name, tostring(liftOf[lifter]),
			kgText(kgOf[lifter] or 0))
	end
	-- They have their lifts: the tied lifters go back to their benches and the judge to the chair (the lift-off needs its
	-- head referee seated).
	if spots then
		-- (back along the lane the same way, one after another: the one whose seat is furthest first)
		local walked: { [Lifter]: boolean } = {}
		for index, lifter in ipairs(standers) do
			if index > 1 then
				task.wait(NationalsConfig.LiftOffScene.GatherStaggerSeconds)
			end
			walked[lifter] = true
			sitLifter(lifter, true)
		end
		for _, lifter in ipairs(group) do
			if not walked[lifter] then
				sitLifter(lifter, true)
			end
		end
	end
	if judge then
		judge.back()
	end
	local alive = table.clone(group)
	local outRounds: { { Lifter } } = {}
	local allMissed = 0
	local round = 0
	while #alive > 1 do
		round += 1
		table.sort(alive, function(a: Lifter, b: Lifter)
			local aKg, bKg = kgOf[a] or 0, kgOf[b] or 0
			return if aKg ~= bKg then aKg < bKg else a.order < b.order
		end)
		local made: { Lifter } = {}
		local missed: { Lifter } = {}
		for _, lifter in ipairs(alive) do
			local stakes = string.format("LIFT-OFF  ·  ROUND %d", round)
			if liftOffAttempt(current, lifter, liftOf[lifter] or "Deadlift", kgOf[lifter] or 0, stakes) then
				table.insert(made, lifter)
			else
				table.insert(missed, lifter)
			end
		end
		if #made == 0 then
			allMissed += 1
			if allMissed >= LIFT_OFF_ALL_MISS_LIMIT then
				-- Never endless: the lighter lifter wins, then the earlier entry.
				table.sort(alive, function(a: Lifter, b: Lifter)
					if math.abs(a.bodyweightKg - b.bodyweightKg) > 1e-9 then
						return a.bodyweightKg < b.bodyweightKg
					end
					return a.order < b.order
				end)
				log("lift-off (%s): %d rounds all missed, the lighter lifter wins", label, allMissed)
				break
			end
		else
			allMissed = 0
			if #missed > 0 then
				table.insert(outRounds, missed)
				alive = made
			end
			if #alive > 1 then
				for _, lifter in ipairs(alive) do
					kgOf[lifter] = (kgOf[lifter] or 0) + LocalMeetConfig.WeightStepKg
				end
			end
		end
	end
	local place = 0
	for _, lifter in ipairs(alive) do
		place += 1
		finish[lifter.key] = place
	end
	for index = #outRounds, 1, -1 do
		place += 1
		for _, lifter in ipairs(outRounds[index]) do
			finish[lifter.key] = place
		end
	end
	local winner = alive[1]
	if winner then
		for _, platform in ipairs(current.hall.venue.platforms) do
			callerSays(platform, string.format("%s WINS THE LIFT-OFF!", string.upper(winner.name)),
				string.format("%s wins the lift-off!", winner.name))
		end
		log("lift-off (%s, %s place) won by %s", label, placeText(forPlace), winner.name)
	end
	if remote then
		task.wait(2)
	end
	return finish
end

--[[
	Every tie for a medal place at Nationals (per class: the same total in the top 3, user 2026-11-17: "only for medal
	places"), settled one lift-off at a time. A lift-off only orders the tied lifters: totals and saved bests don't change.
]]
runLiftOffs = function(current: Meet)
	-- (Placed on points, ties are near impossible and the points ranking settles them: no lift-offs.)
	if current.pointsMode then
		return
	end
	local byClass: { [string]: { MeetPlacing.Entry } } = {}
	local byKey: { [number]: Lifter } = {}
	for _, lifter in ipairs(current.lifters) do
		local result = MeetTotal.resolve(meetAttempts(lifter))
		byKey[lifter.key] = lifter
		byClass[lifter.classLabel] = byClass[lifter.classLabel] or {}
		table.insert(byClass[lifter.classLabel], { key = lifter.key, bodyweightKg = lifter.bodyweightKg,
			totalKg = if lifter.withdrawn then nil else result.total, goodLifts = goodLiftCount(lifter), order = lifter.order })
	end
	local classes: { string } = {}
	for label in pairs(byClass) do
		table.insert(classes, label)
	end
	table.sort(classes, classOrder)
	for _, label in ipairs(classes) do
		local placings = MeetPlacing.rankByTotal(byClass[label])
		local placeOfKey: { [number]: number } = {}
		for _, placing in ipairs(placings) do
			if placing.place then
				placeOfKey[placing.key] = placing.place
			end
		end
		for _, keys in ipairs(MeetPlacing.medalTies(byClass[label], MeetLevelConfig.Nationals.TopPlaces)) do
			local group: { Lifter } = {}
			local forPlace = math.huge
			for _, key in ipairs(keys) do
				local lifter = byKey[key]
				if lifter and stillLifting(lifter) then
					table.insert(group, lifter)
					forPlace = math.min(forPlace, placeOfKey[key] or math.huge)
				end
			end
			if #group >= 2 then
				local finish = liftOff(current, group, forPlace)
				for key, at in pairs(finish) do
					current.liftOff[key] = at
				end
			end
		end
	end
end

local podiumAndAwards: (current: Meet, v: LocalMeetVenue.Venue, classLabel: string?, seconds: number) -> ()
local nationalsAwards: (current: Meet, v: LocalMeetVenue.Venue) -> ()
local finishCleanUp: (current: Meet, v: LocalMeetVenue.Venue) -> ()

local function finishMeet(current: Meet)
	-- Nationals: tied medal places in a class are settled by a lift-off first (GAME_DESIGN §39), which only orders them.
	if current.hall.nationals then
		local ok, problem = pcall(runLiftOffs, current)
		if not ok then
			warn("[LocalMeetService] a Nationals lift-off failed: " .. tostring(problem))
		end
	end
	current.final = true
	current.heading = "FINAL"
	if current.hall.state then
		MeetCheering.closeAll()
		if not current.hall.nationals then
			StateArenaShow.meetOn(false)
		end
	end
	-- Any walk back from the last round ends here: the awards place everyone.
	for _, lifter in ipairs(current.lifters) do
		lifter.walkToken = (lifter.walkToken or 0) + 1
		lifter.walking = false
		endLift(lifter)
	end
	local entries: { MeetPlacing.Entry } = {}
	for _, lifter in ipairs(current.lifters) do
		local result = MeetTotal.resolve(meetAttempts(lifter))
		table.insert(entries, { key = lifter.key, bodyweightKg = lifter.bodyweightKg,
			totalKg = if lifter.withdrawn then nil else result.total, goodLifts = goodLiftCount(lifter), order = lifter.order })
	end
	-- Rewards go by the real lifters' order among themselves: a computer lifter never takes one (§37.2).
	local realKeys: { [number]: boolean } = {}
	for _, lifter in ipairs(current.lifters) do
		if lifter.player then
			realKeys[lifter.key] = true
		end
	end
	local realPlace = 0
	for _, placing in ipairs(rankFor(current, entries)) do
		current.places[placing.key] = placing
		if current.hall.nationals then
			-- Real players only, and placed per class: the class place is the reward place.
			current.rewardPlaces[placing.key] = placing.place
		elseif placing.place and realKeys[placing.key] then
			realPlace += 1
			current.rewardPlaces[placing.key] = realPlace
		end
	end
	updateStandings(current)

	local placed = 0
	for _, placing in pairs(current.places) do
		if placing.place then
			placed += 1
		end
	end
	-- The coins (GAME_DESIGN §41.4): every real meet pays, computer-lifter meets too, never a Mock Meet. Finishing
	-- with a total, 9/9, and a top-3 place in the WHOLE field (computer lifters counted; at Nationals in the class),
	-- all times the meet's level. Real players only are paid.
	local payouts: { [number]: { MeetPayout.Item } } = {}
	if current.rewards or current.solo then
		local results: { MeetPayout.Lifter } = {}
		for _, lifter in ipairs(current.lifters) do
			if lifter.player then
				local placing = current.places[lifter.key]
				local place = if placing then placing.place else nil
				local good = goodLiftCount(lifter)
				local overLimit: { { lift: string, percentOfCn: number } } = {}
				for _, lift in ipairs(MeetConfig.LiftOrder) do
					local cn = lifter.competitionNumber[lift]
					for _, attempt in ipairs(lifter.lifts[lift].history) do
						if attempt.result == "GoodLift" and AttemptChoice.isOverLimit(cn, attempt.weightKg) then
							table.insert(overLimit, { lift = lift, percentOfCn = attempt.weightKg / cn })
						end
					end
				end
				table.insert(results, { key = lifter.key, place = place, hasTotal = not lifter.withdrawn and place ~= nil,
					perfect = good == #MeetConfig.LiftOrder * MeetConfig.AttemptsPerLift, overLimit = overLimit })
			end
		end
		local multiplier = MeetLevelConfig.Levels[current.level].potMultiplier
		payouts = MeetPayout.forMeet(results, CoinConfig.LocalMeet, multiplier)
		log("meet pay: %s, x%d, solo %s", current.level, multiplier, tostring(current.solo))
	end
	-- Each State rack's screen ends on the best finisher on it.
	if current.hall.state then
		local bestOnRack: { [LocalMeetVenue.Platform]: Lifter } = {}
		for _, lifter in ipairs(current.lifters) do
			lifter.onScreen = false
			local placing = current.places[lifter.key]
			local best = bestOnRack[lifter.platform]
			local bestPlacing = best and current.places[best.key]
			if best == nil or (placing and placing.place and (bestPlacing == nil or bestPlacing.place == nil or placing.place < bestPlacing.place)) then
				bestOnRack[lifter.platform] = lifter
			end
		end
		for _, lifter in pairs(bestOnRack) do
			lifter.onScreen = true
		end
	end
	for _, lifter in ipairs(current.lifters) do
		local result = MeetTotal.resolve(meetAttempts(lifter))
		local placing = current.places[lifter.key]
		local player = lifter.player
		local saved: { string } = {}
		if not lifter.withdrawn and player then
			saved = saveLifter(current, lifter, result.total, result.best, current.rewardPlaces[lifter.key])
			if player.Parent then
				for _, item in ipairs(payouts[lifter.key] or {}) do
					if PlayerDataService.addCoins(player, item.amount, item.reason) == "Added" then
						lifter.coinsEarned += item.amount
					end
				end
			end
			if current.solo and result.total then
				table.insert(saved, "Alone with computer lifters: no titles, gym records or rare drops")
			end
			if result.total and player.Parent then
				local suitName = rollSuit(current, lifter, player)
				if suitName then
					table.insert(saved, 1, "RARE DROP: THE " .. suitName)
				end
			end
		end
		if lifter.coinsEarned > 0 then
			table.insert(saved, 1, string.format("+%s %s", CoinConfig.format(lifter.coinsEarned), CoinConfig.Name))
		end
		local note: string
		if placing and placing.place and placing.points and current.hall.nationals and not current.pointsMode then
			local inClass = 0
			for _, other in ipairs(current.lifters) do
				if other.classLabel == lifter.classLabel then
					inClass += 1
				end
			end
			note = string.format("%s PLACE of %d IN %s  ·  TOTAL %s KG%s", string.upper(placeText(placing.place)), inClass,
				string.upper(lifter.classLabel), kgText(result.total or 0),
				if #saved > 0 then "  ·  " .. table.concat(saved, "  ·  ") else "")
			boardFor(lifter, { string.format("%s PLACE  ·  %s", string.upper(placeText(placing.place)), lifter.classLabel),
				string.format("TOTAL %s KG", kgText(result.total or 0)) })
		elseif placing and placing.place and placing.points then
			note = string.format("%s PLACE of %d  ·  %.2f POINTS%s", string.upper(placeText(placing.place)),
				#current.lifters, placing.points, if #saved > 0 then "  ·  " .. table.concat(saved, "  ·  ") else "")
			boardFor(lifter, { string.format("%s PLACE", string.upper(placeText(placing.place))),
				string.format("TOTAL %s KG", kgText(result.total or 0)), string.format("%.2f POINTS", placing.points) })
		else
			note = "No total, no place  ·  A bomb-out saves nothing" .. (if current.rewards or current.solo
				then " (misses above your CN still used your meet allowance)" else "")
			boardFor(lifter, { if lifter.withdrawn then "WITHDRAWN" else "BOMBED OUT" })
		end
		-- (The coach's word on how it went is now the end-of-meet scene's, below: MeetEndScene.)
		sendState(lifter, "Done", { best = result.best, total = result.total, bombedOut = result.bombedOut, note = note })
		log("%s finished the Local meet: %s", lifter.name,
			if placing and placing.place then string.format("%s, total %s", placeText(placing.place), kgText(result.total or 0))
				else "no total")
	end
	log("Local meet over: %d lifters, %d placed (rewards: %s)", #current.lifters, placed, tostring(current.rewards))

	-- The awards: the racks make way for the awards stage, and the top three stand on its podium while the final
	-- standings show.
	local v = current.hall.venue
	LocalMeetVenue.showAwards(v, true)
	for _, lifter in ipairs(current.lifters) do
		local player = lifter.player
		if current.hall.state and player and not lifter.withdrawn then
			-- Off the benches and the practice racks, and only the winners' names on the screens are left to draw (below).
			stopChalk(lifter)
			offSeat(lifter)
			stopWarmUps(player)
		end
	end
	-- THE END-OF-MEET COACH SCENE (GAME_DESIGN §40.5, user 2026-11-25): each player's coach walks up, pats their back
	-- and says how it went, before the podium. SKIP lets a player off the podium go at once (their part of
	-- finishCleanUp now, and no awards camera).
	local MeetEndScene = require(script.Parent:WaitForChild("MeetEndScene"))
	local beats: { any } = {}
	-- (user 2026-11-26) the top 3 walk into a line for the podium at a Local meet hall: their place in it, 3rd at the
	-- front (MeetCeremony.lineSpots); the computer lifters among them walk in with the players.
	local lineSlots = if v.podiumSpots[1] then require(script.Parent:WaitForChild("MeetCeremony")).lineSpots(v.podiumSpots[1]).slots
		else {}
	local onPodium = 0
	for _, lifter in ipairs(current.lifters) do
		local placing = current.places[lifter.key]
		if placing and placing.place and placing.place <= 3 and not lifter.withdrawn
			and (lifter.player == nil or visits[lifter.player]) then
			onPodium += 1
		end
	end
	local walkers: { any } = {}
	for _, lifter in ipairs(current.lifters) do
		local player = lifter.player
		local body = player and bodyOf(player)
		if player and body and visits[player] and not lifter.withdrawn then
			local placing = current.places[lifter.key]
			local histories = {}
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				histories[lift] = lifter.lifts[lift].history
			end
			local place = if placing and placing.place and not bombed(lifter) then placing.place else nil
			-- Off the podium: a step out to open floor in the warm-up room (MeetEndScene.sceneSpot: room for the coach
			-- at their right and the camera). On it, at a Local meet hall: on their own platform, then the walk
			-- together to the podium (user 2026-11-25). At a State meet (user 2026-11-27: "State: add the walk") the
			-- top 3 start from the open-floor spot and walk into the line the same way.
			local gold = v.podiumSpots[1]
			local top = lifter.platform.platformTop
			local walksToLine = place ~= nil and place <= 3 and gold ~= nil and not current.hall.nationals
			local onStage = walksToLine and top ~= nil and lifter.platform.frontFloor ~= nil and not current.hall.state
			local sceneAt = if onStage then MeetEndScene.platformSpot(top :: CFrame)
				else MeetEndScene.sceneSpot(body.root.CFrame * CFrame.new(0, -standingHeight(body), 0),
					{ player.Character, LocalMeetVenue.coachFigure(lifter.platform) }, v.model)
			standAt(player, sceneAt, true)
			-- (Studio 2026-11-26: his walk back after the last lift was still going and pulled him off mid-pat) any
			-- coachWalk still under way ends here.
			lifter.coachToken = (lifter.coachToken or 0) + 1
			local stage = nil
			local slotIndex = if place then onPodium - place + 1 else 0
			if walksToLine and lineSlots[slotIndex] then
				stage = { slot = lineSlots[slotIndex], slotIndex = slotIndex }
			end
			table.insert(beats, {
				player = player,
				platform = lifter.platform,
				lifterAt = sceneAt,
				lineKey = MeetEndScene.lineKey(place, MeetEndScene.allGood(histories :: any)),
				podium = place ~= nil and place <= 3,
				stage = stage,
				onArrived = function(final: CFrame)
					if visits[player] then
						standAt(player, final, true)
					end
				end,
			})
		end
	end
	if not current.hall.nationals then
		for _, lifter in ipairs(current.lifters) do
			local placing = current.places[lifter.key]
			local slot = placing and placing.place and lineSlots[onPodium - placing.place + 1]
			if lifter.player == nil and lifter.body and not lifter.withdrawn and placing and placing.place <= 3 and slot then
				table.insert(walkers, { body = lifter.body, slot = slot, slotIndex = onPodium - placing.place + 1 })
			end
		end
	end
	local endSkipped: { [Player]: boolean } = {}
	local meetAny: any = current
	meetAny.endSkipped = endSkipped
	if #beats > 0 or #walkers > 0 then
		local skipped = MeetEndScene.run(beats, remotes, function()
			return current.hall.meet == current
		end, function(player: Player)
			for index, lifter in ipairs(current.lifters) do
				if lifter.player == player and not lifter.withdrawn then
					endSkipped[player] = true
					lifter.withdrawn = true
					LiftAttemptService.setFreeAttemptsBlocked(player, false)
					player:SetAttribute(LocalMeetConfig.PlatformAttribute, nil)
					release(player)
					if visits[player] then
						standAt(player, LocalMeetVenue.lobbySpotFor(v, index), false)
					end
					if current.hall.state then
						StateArenaVenue.setCompetitor(player, false)
					end
					showDroppedSuit(lifter, player)
				end
			end
		end, walkers)
		-- (A podium lifter who skipped stays for the podium, without the awards camera.)
		for player in pairs(skipped) do
			endSkipped[player] = true
		end
	end
	MeetEndScene.hideCoaches(v.platforms)
	if current.hall.nationals then
		nationalsAwards(current, v)
	else
		podiumAndAwards(current, v, nil, LocalMeetConfig.DoneSeconds)
	end
	finishCleanUp(current, v)
end

--[[
	The awards for `current`'s lifters (only `classLabel`'s at Nationals, nil = everyone): the top three on the podium
	holding their trophies, the moment for everyone in the hall, then `seconds` before the next.
]]
podiumAndAwards = function(current: Meet, v: LocalMeetVenue.Venue, classLabel: string?, seconds: number)
	-- THE PODIUM CEREMONY (GAME_DESIGN §40.5, user 2026-11-25; MeetCeremony): called up 3rd, 2nd, 1st, the medal or the
	-- trophy from a referee on the floor, a handshake, then the hop up onto the block. Not at Nationals yet (its awards
	-- go class by class).
	if classLabel == nil and not current.hall.nationals then
		local entries = {}
		for _, lifter in ipairs(current.lifters) do
			local placing = current.places[lifter.key]
			local place = placing and placing.place
			local player = lifter.player
			local model = if player then player.Character else lifter.body
			if place and place <= 3 and not lifter.withdrawn and model and (player == nil or visits[player]) then
				table.insert(entries, { model = model, place = place, lifter = lifter })
			end
		end
		local clear = require(script.Parent:WaitForChild("MeetCeremony")).run({ lifters = entries,
			podiumSpots = v.podiumSpots, level = current.level, stillOn = function()
				return current.hall.meet == current
			end, notify = function(data: any)
				-- (everyone in the hall sees the ceremony; not those who skipped the end of the meet and left)
				local skipped = (current :: any).endSkipped or {}
				for player, visit in pairs(visits) do
					if visit.hall == current.hall.index and not skipped[player] and remotes then
						remotes.scene:FireClient(player, data)
					end
				end
			end })
		-- (a computer lifter's waves and emotes on the podium start once it's up there: none during the ceremony)
		for _, entry in ipairs(entries) do
			if entry.lifter.player == nil then
				entry.lifter.onPodium = true
			end
		end
		announceAwards(current, v, classLabel, seconds)
		task.wait(seconds)
		clear()
		return
	end
	for _, lifter in ipairs(current.lifters) do
		if classLabel and groupOf(current, lifter) ~= classLabel then
			continue
		end
		local placing = current.places[lifter.key]
		local spot = placing and placing.place and v.podiumSpots[placing.place]
		local player = lifter.player
		if spot and not lifter.withdrawn and player == nil then
			-- A computer lifter in the top 3 stands on the podium too, without a trophy: a wave to the crowd, then now and
			-- then one of its own emotes (runComputerEmotes), as a player would; before, Roblox's stock cheer for 20 s.
			ComputerLifters.moveBody(lifter.body, spot)
			lifter.onPodium = true
		elseif spot and not lifter.withdrawn and player and visits[player] then
			standAt(player, spot, true)
			-- A Regional or State meet's top 3 hold a trophy (GAME_DESIGN §35.8), in a meet that pays in full.
			local character = player.Character
			if MeetLevelConfig.Levels[current.level].titles and current.rewards and character and placing and placing.place then
				Trophies.give(character, placing.place)
			end
		end
	end
	announceAwards(current, v, classLabel, seconds)
	task.wait(seconds)
	local characters: { Model } = {}
	for _, lifter in ipairs(current.lifters) do
		local character = lifter.player and lifter.player.Character
		if character and (classLabel == nil or groupOf(current, lifter) == classLabel) then
			table.insert(characters, character)
		end
	end
	Trophies.clearFrom(characters)
end

--[[
	Nationals' awards (GAME_DESIGN §39): class by class, lightest first, each class's top three on the podium in turn (on
	points: one podium for everyone). Those off the podium wait at the front of the stage.
]]
nationalsAwards = function(current: Meet, v: LocalMeetVenue.Venue)
	local classes: { string } = {}
	for _, lifter in ipairs(current.lifters) do
		if not table.find(classes, groupOf(current, lifter)) then
			table.insert(classes, groupOf(current, lifter))
		end
	end
	table.sort(classes, classOrder)
	for _, label in ipairs(classes) do
		local placed = false
		for _, lifter in ipairs(current.lifters) do
			local placing = current.places[lifter.key]
			if groupOf(current, lifter) == label and placing and placing.place and not lifter.withdrawn then
				placed = true
			end
		end
		if placed then
			podiumAndAwards(current, v, label, NationalsConfig.AwardsClassSeconds)
			for index, lifter in ipairs(current.lifters) do
				local player = lifter.player
				if groupOf(current, lifter) == label and player and visits[player] and not lifter.withdrawn then
					standAt(player, LocalMeetVenue.lobbySpotFor(v, index), true)
				end
			end
		end
	end
end

-- After the awards: the platforms cleared, every lifter free again, the hall's meet over.
finishCleanUp = function(current: Meet, v: LocalMeetVenue.Venue)
	LocalMeetVenue.showAwards(v, false)
	for index, lifter in ipairs(current.lifters) do
		local player = lifter.player
		LocalMeetVenue.clearStaff(lifter.platform)
		LocalMeetVenue.setLights(lifter.platform, nil)
		LocalMeetVenue.setStageLight(lifter.platform, 1)
		LocalMeetVenue.showLifter(lifter.platform, nil)
		LocalMeetVenue.rackFor(lifter.platform, nil)
		if player == nil then
			lifter.withdrawn = true
			ComputerLifters.removeBody(lifter.body)
			lifter.body = nil
		elseif not lifter.withdrawn then
			lifter.withdrawn = true
			LiftAttemptService.setFreeAttemptsBlocked(player, false)
			if player.Parent then
				player:SetAttribute(LocalMeetConfig.PlatformAttribute, nil)
			end
			release(player)
			if visits[player] then
				standAt(player, LocalMeetVenue.lobbySpotFor(v, index), false)
			end
			if current.hall.state then
				StateArenaVenue.setCompetitor(player, false)
			end
			showDroppedSuit(lifter, player)
		end
	end
	current.hall.meet = nil
	-- The State arena's floor goes back to the sign-up desk and booths, and the wait for the next meet starts now (user 2026-11-06).
	if current.hall.state and not current.hall.nationals and stateArena then
		stateArena.setFloor(0, 0)
		current.hall.nextStartAt = startAfter(now(), current.hall)
	end
	broadcastLobby()
	-- Nationals is over: NationalsService sends everyone on.
	local onFinished = nationalsOnFinished
	if current.hall.nationals and onFinished then
		nationalsOnFinished = nil
		local places: { [number]: number? } = {}
		for _, lifter in ipairs(current.lifters) do
			local placing = current.places[lifter.key]
			if lifter.player then
				places[lifter.player.UserId] = placing and placing.place
			end
		end
		task.spawn(onFinished, places)
	end
end

local function runMeet(current: Meet)
	local hall = current.hall
	local staffed: { [LocalMeetVenue.Platform]: boolean } = {}
	for _, lifter in ipairs(current.lifters) do
		local player = lifter.player
		local plan = lifter.cpu
		if player then
			player:SetAttribute(LocalMeetConfig.PlatformAttribute, lifter.platform.index)
			stopWarmUps(player)
			LiftAttemptService.setFreeAttemptsBlocked(player, true)
			-- Now in this meet's hall. Held still from here until the meet ends or they withdraw (user 2026-11-04), so
			-- they can't fall while the hall loads around them.
			local visit = visits[player]
			if visit then
				visit.hall = hall.index
				player:SetAttribute(LocalMeetConfig.HallAttribute, hall.index)
			end
			local spot = lifter.platform.waitSpot
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(spot.Position, STREAM_TIMEOUT_SECONDS)
				end)
			end)
			if hall.state then
				-- Into the meet area, onto their bench, free to get up and roam (user 2026-11-06).
				StateArenaVenue.setCompetitor(player, true)
				sitLifter(lifter, false)
			else
				standAt(player, spot, true)
			end
		elseif plan then
			lifter.body = ComputerLifters.spawnBody(plan, lifter.platform.waitSpot, cpuRandom)
			-- Its emotes now and then while it waits (§37.2).
			runComputerEmotes(current, lifter)
		end
		-- (A State rack's lifters share one set of staff.)
		if not staffed[lifter.platform] then
			staffed[lifter.platform] = true
			LocalMeetVenue.staffPlatform(lifter.platform)
			-- Only the lifter sees their referees' and coach's tags and what the coach says; a computer lifter's staff
			-- show nothing (§37.4, §37.5).
			LocalMeetVenue.staffFor(lifter.platform, player)
			-- A computer lifter's coach stays where they can watch (coachWalk says why).
			if player == nil then
				ComputerLifters.moveBody(LocalMeetVenue.coachFigure(lifter.platform), lifter.platform.coachDoorSpot)
			end
		end
		boardFor(lifter, { "WEIGH-IN", string.format("%s CLASS  ·  %.1f KG", lifter.classLabel, lifter.bodyweightKg) })
		sendState(lifter, "WeighIn", { secondsLeft = LocalMeetConfig.WeighInSeconds })
	end
	current.heading = "WEIGH-IN"
	updateStandings(current)
	broadcastLobby()
	task.wait(LocalMeetConfig.WeighInSeconds)
	-- NATIONALS: THE OPENING (user 2026-11-18), with the lifters on their benches, after the weigh-in: the camera tour of
	-- the hall, the announcer's welcome under the spotlight, then each lifter's coach on who they are up against
	-- (NationalsScenes; each lifter's own screen shows it as a cinematic). The first round follows it.
	-- (STUDIO TEST ONLY: left out when "StudioLiftOffAtStart" is set, to get straight to the lift-off's judge.)
	local set = remotes
	if hall.nationals and set and not (RunService:IsStudio() and Workspace:GetAttribute("StudioLiftOffAtStart") == true) then
		local opening: { NationalsScenes.OpeningLifter } = {}
		for _, lifter in ipairs(current.lifters) do
			local player = lifter.player
			if player and stillLifting(lifter) then
				local rivals: { number } = {}
				local classmates = 0
				for _, other in ipairs(current.lifters) do
					if other ~= lifter and stillLifting(other) then
						if other.classLabel == lifter.classLabel then
							classmates += 1
						end
						if other.player and groupOf(current, other) == groupOf(current, lifter) then
							table.insert(rivals, other.key)
						end
					end
				end
				-- (STUDIO TEST ONLY: with the workspace attribute "StudioOpeningRivals" a lifter alone gets the coach's
				-- "there is your competition" too, standing in as their own rival, to look at that part with one player.)
				if RunService:IsStudio() and Workspace:GetAttribute("StudioOpeningRivals") == true and #rivals == 0 then
					table.insert(opening, { player = player, platform = lifter.platform, rivals = { lifter.key },
						onPoints = false, alone = false, studioSelfRival = true })
				else
					table.insert(opening, { player = player, platform = lifter.platform, rivals = rivals,
						onPoints = current.pointsMode == true, alone = classmates == 0 })
				end
			end
		end
		-- Every lifter's screen has the hall first (its lights show late in a place just walked into: NationalsConfig
		-- .Opening): each says when ("HallReady"), and the opening starts a little after the last one, or anyway.
		local waitedFrom = os.clock()
		waitUntil(NationalsConfig.Opening.ReadyWaitSeconds, function()
			for _, entry in ipairs(opening) do
				local readyAt = hallReadyAt[entry.player]
				if entry.player.Parent and (readyAt == nil or os.clock() - readyAt < NationalsConfig.Opening.LightsSeconds) then
					return false
				end
			end
			return true
		end)
		log("the Nationals opening waited %.1f s for the lifters' screens to have the hall", os.clock() - waitedFrom)
		local ok, played = pcall(NationalsScenes.opening, {
			venue = hall.venue,
			lifters = opening,
			remote = set.scene,
			cheer = function(platform: LocalMeetVenue.Platform)
				local rack = platform.rack
				if rack then
					local at = rack:GetPivot().Position
					for player, visit in pairs(visits) do
						if visit.hall == hall.index then
							set.sound:FireClient(player, "CrowdCheer", at, 1.5)
						end
					end
				end
			end,
			stillOn = function(): boolean
				return hall.meet == current and #activeLifters(current) > 0
			end,
		})
		if not ok then
			warn("[LocalMeetService] the Nationals opening failed: " .. tostring(played))
		else
			log("the Nationals opening %s", if played then "played" else "was left out (no announcer or tour)")
		end
	end
	-- (STUDIO TEST ONLY: the workspace attribute "StudioLiftOffAtStart" runs a lift-off between every real lifter right
	-- after the weigh-in, to look at the judge's cinematic without lifting a whole meet first. It changes no totals.)
	if hall.nationals and RunService:IsStudio() and Workspace:GetAttribute("StudioLiftOffAtStart") == true then
		-- (A hall just walked into shows its lights late, for about ten seconds: a real lift-off comes at the end of a meet.)
		task.wait(12)
		local tied: { Lifter } = {}
		for _, lifter in ipairs(current.lifters) do
			if lifter.player and stillLifting(lifter) then
				table.insert(tied, lifter)
			end
		end
		if #tied >= 1 then
			local ok, problem = pcall(liftOff, current, tied, 1)
			if not ok then
				warn("[LocalMeetService] the Studio test lift-off failed: " .. tostring(problem))
			end
		end
	end
	-- The State meet: each rack runs on its own (user 2026-11-06), and the meet ends when they all have. The arena goes
	-- dark, its racks spotlit as lifters come up (StateArenaShow, user 2026-11-10).
	if hall.state then
		if not hall.nationals then
			StateArenaShow.meetOn(true)
		end
		local racks: { [LocalMeetVenue.Platform]: { Lifter } } = {}
		for _, lifter in ipairs(current.lifters) do
			racks[lifter.platform] = racks[lifter.platform] or {}
			table.insert(racks[lifter.platform], lifter)
		end
		local running = 0
		for platform, group in pairs(racks) do
			running += 1
			task.spawn(function()
				for _, lift in ipairs(MeetConfig.LiftOrder) do
					for attemptNumber = 1, MeetConfig.AttemptsPerLift do
						local left = false
						for _, lifter in ipairs(group) do
							left = left or stillLifting(lifter)
						end
						if left then
							local ok, problem = pcall(runRound, current, lift, attemptNumber, group)
							if not ok then
								warn("[LocalMeetService] a State rack's round failed: " .. tostring(problem))
							end
						end
					end
				end
				callerSays(platform, "THAT'S THIS RACK DONE!")
				running -= 1
			end)
		end
		while running > 0 do
			task.wait(0.5)
		end
		finishMeet(current)
		return
	end
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		for attemptNumber = 1, MeetConfig.AttemptsPerLift do
			local realLeft = 0
			for _, lifter in ipairs(activeLifters(current)) do
				if lifter.player then
					realLeft += 1
				end
			end
			-- Computer lifters never lift on their own (§37.2).
			if realLeft == 0 then
				log("every real lifter left: the meet ends early")
				finishMeet(current)
				return
			end
			runRound(current, lift, attemptNumber)
		end
	end
	finishMeet(current)
end

-- Reads a signed-up player's weigh-in, or nil and why they cannot lift.
local function weighIn(player: Player): ({ bodyweightKg: number, classLabel: string, competitionNumber: { [string]: number },
	bestTotalKg: number?, localWins: number, titles: { [string]: number }, stateQualified: boolean,
	nationals: ProfileOperations.NationalsView, championBadges: { ProfileOperations.ChampionBadgeView } }?, string?)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return nil, "your data is still loading"
	end
	local classKey = ProfileOperations.getActiveClassKey(data)
	if classKey == nil or ProfileOperations.getBuild(data, classKey) == nil then
		return nil, "you have no build for your weight class"
	end
	local competitionNumber: { [string]: number } = {}
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local cn = ProfileOperations.getCompetitionNumber(data, lift)
		if cn == nil or cn <= 0 then
			return nil, "a Competition Number is missing"
		end
		competitionNumber[lift] = cn
	end
	local build = ProfileOperations.getBuild(data, classKey)
	local best = build and build.bestTotalKg
	local career = data.career
	local wins = if typeof(career) == "table" and typeof(career.localWins) == "number" then career.localWins else 0
	return { bodyweightKg = data.bodyweight.currentKg, classLabel = classKey, competitionNumber = competitionNumber,
		bestTotalKg = if typeof(best) == "number" and best > 0 then best else nil, localWins = wins,
		titles = ProfileOperations.getTitles(data),
		stateQualified = ProfileOperations.getLadder(data, classKey, os.time()).qualified,
		nationals = ProfileOperations.getNationals(data, classKey, os.time()),
		championBadges = ProfileOperations.getStateChampionBadges(data) }, nil
end

-- Moves a player into the venue. Set below, with the rest of the way in and out.
local enterVenue: (player: Player, point: BasePart?, toHall: Hall?) -> (boolean, string?)

--[[
	Takes everyone on this hall's list who is elsewhere in the game to the hall (user
	2026-11-06): off a rack or a cardio machine, out of a gym lift, nothing there is worth
	missing a meet for. Someone in their Mock Meet stays there, and stays on the list. Waits
	for them all, at most as long as the stream can take.
]]
local function bringToMeet(hall: Hall)
	local waiting = 0
	for _, player in ipairs(table.clone(hall.signUps)) do
		if visits[player] == nil and player:GetAttribute(MOCK_MEET_ATTRIBUTE) == nil then
			waiting += 1
			task.spawn(function()
				if LiftAttemptService.isAttemptActive(player) then
					LiftAttemptService.abandon(player)
				end
				TrainingStationService.letGo(player, "Your meet is starting.")
				CardioMachineService.hopOff(player)
				local went, why = enterVenue(player, nil, hall)
				if not went then
					log("could not bring %s to meet %d: %s", player.Name, hall.index, tostring(why))
				end
				waiting -= 1
			end)
		end
	end
	local gaveUpAt = os.clock() + STREAM_TIMEOUT_SECONDS + 2
	while waiting > 0 and os.clock() < gaveUpAt do
		task.wait(0.1)
	end
end

-- At a hall's timetable start: holds its meet if enough signed-up lifters are ready.
local function tryStartMeet(hall: Hall)
	local v = hall.venue
	if hall.meet ~= nil then
		return
	end
	-- A Nationals server (GAME_DESIGN §39, NationalsService) runs no State meet; the list carries over.
	if hall.state and Workspace:GetAttribute(NationalsConfig.ServerAttribute) ~= nil then
		return
	end
	-- Anyone signed up who went off to do something else is taken there now (user 2026-11-06).
	bringToMeet(hall)
	-- Only names now in the venue, alive and free can lift; the list keeps its order, and anyone who can't lift stays
	-- on it for the next meet.
	local ready: { Player } = {}
	for _, player in ipairs(table.clone(hall.signUps)) do
		local body = bodyOf(player)
		local visit = visits[player]
		if visit == nil or body == nil or body.character ~= visit.character or body.humanoid.Health <= 0 then
			notify(player, string.format("You missed %s. You stay on its list for the next one.", meetName(hall)))
		elseif not LiftAttemptService.isAttemptActive(player) then
			table.insert(ready, player)
		end
	end
	if #ready < minimumLifters(hall) then
		if #ready > 0 then
			log("not enough lifters (%d of %d): no meet", #ready, minimumLifters(hall))
		end
		for _, player in ipairs(ready) do
			notify(player, string.format("Not enough lifters signed up (%d of %d). You stay on the list for the next meet.",
				#ready, minimumLifters(hall)))
		end
		return
	end

	local current: Meet = { hall = hall, lifters = {}, byPlayer = {}, heading = "WEIGH-IN", final = false, rewards = false,
		solo = false, rewardPlaces = {}, places = {}, level = hall.nextLevel, liftOff = {} }
	-- The State arena's floor is set up for this many lifters now: one rack per LiftersPerRack (user 2026-11-06).
	local stateRacks = 0
	local statePerRack = 0
	if hall.state then
		local arena = stateArena
		local lifting = math.min(#ready, maximumLifters(hall))
		if arena == nil then
			return
		end
		stateRacks = math.clamp(math.ceil(lifting / StateArenaConfig.LiftersPerRack), 1, StateArenaConfig.MaxRacks)
		statePerRack = math.ceil(lifting / stateRacks)
		-- (STUDIO TEST ONLY: the workspace attribute "StudioStateSeats" builds each rack's benches for at least that many
		-- lifters, to look at a full rack's two rows with one lifter.)
		local benchSeats = statePerRack
		local studioSeats = if RunService:IsStudio() then Workspace:GetAttribute("StudioStateSeats") else nil
		if typeof(studioSeats) == "number" then
			benchSeats = math.max(benchSeats, math.floor(studioSeats))
		end
		local problem = arena.setFloor(stateRacks, benchSeats)
		if problem then
			warn("[LocalMeetService] the State floor could not be set up: " .. problem)
			arena.setFloor(0, 0)
			return
		end
		-- Anyone watching from the floor steps back behind the new barricades.
		for watcher, visit in pairs(visits) do
			local body = bodyOf(watcher)
			if visit.hall == hall.index and body and arena.inMeetArea(body.root.Position) and not table.find(ready, watcher) then
				standAt(watcher, LocalMeetVenue.lobbySpotFor(v, 1), false)
			end
		end
	end
	for _, player in ipairs(ready) do
		if #current.lifters >= maximumLifters(hall) then
			notify(player, "This meet is full. You stay on the list for the next one.")
			continue
		end
		local weigh, problem = weighIn(player)
		-- Checked again: they may have changed class since signing up (§36.3).
		if weigh and hall.state and not stateLadder(player) then
			weigh, problem = nil, "you are not qualified for State in this class"
		end
		if weigh == nil then
			removeSignUp(player)
			notify(player, "You cannot lift today: " .. (problem or "unknown problem") .. ".")
			continue
		end
		removeSignUp(player)
		local lifts: { [string]: LiftRecord } = {}
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			lifts[lift] = { history = {}, passed = 0 }
		end
		local index = #current.lifters + 1
		-- At State, dealt round the racks in sign-up order.
		local platformIndex = if hall.state then (index - 1) % stateRacks + 1 else index
		local platform = v.platforms[platformIndex]
		local seats = platform.seats
		local lifter: Lifter = {
			hall = hall,
			player = player,
			key = player.UserId,
			cpu = nil,
			body = nil,
			name = player.DisplayName,
			platform = platform,
			-- (STUDIO TEST ONLY: the workspace attribute "StudioStateSeatIndex" sits the first lifter on that seat of the
			-- rack, e.g. one of the back row's.)
			seat = if seats then seats[(if index == 1 and RunService:IsStudio()
				and typeof(Workspace:GetAttribute("StudioStateSeatIndex")) == "number"
				then Workspace:GetAttribute("StudioStateSeatIndex") :: number
				else (index - 1) // math.max(stateRacks, 1) + 1)] else nil,
			order = index,
			bodyweightKg = weigh.bodyweightKg,
			classLabel = weigh.classLabel,
			competitionNumber = weigh.competitionNumber,
			lifts = lifts,
			withdrawn = false,
			choice = nil,
			chosenKg = nil,
			defaultKg = nil,
			readyPressed = false,
			roundDone = false,
			lights = nil,
			currentLift = nil,
			bestTotalKg = weigh.bestTotalKg,
			localWins = weigh.localWins,
			stateQualified = weigh.stateQualified,
			nationalsPlacings = weigh.nationals.placings,
			nationalsQualified = weigh.nationals.qualified,
			nationalsNews = nil,
			titles = weigh.titles,
			championBadges = weigh.championBadges,
			gymRecords = {},
			boardLines = nil,
			boardMood = nil,
			liftsStarted = 0,
			coinsEarned = 0,
		}
		table.insert(current.lifters, lifter)
		current.byPlayer[player] = lifter
	end
	if #current.lifters < minimumLifters(hall) then
		-- Someone could not lift after all: back on the list, in front.
		for index = #current.lifters, 1, -1 do
			table.insert(hall.signUps, 1, current.lifters[index].player :: Player)
		end
		log("not enough lifters could weigh in: no meet")
		if hall.state and stateArena then
			stateArena.setFloor(0, 0)
		end
		return
	end
	-- Full rewards need enough REAL players; one real player gets the reduced ones (§37.2). In Studio the
	-- workspace attribute "ForceSoloMeet" tests the reduced ones alone.
	local realCount = #current.lifters
	local forceSolo = RunService:IsStudio() and Workspace:GetAttribute("ForceSoloMeet") == true
	-- (State is real players only, so it always pays in full.)
	current.rewards = hall.state or (realCount >= rewardMinimumLifters() and not forceSolo)
	current.solo = not current.rewards
	-- Computer lifters fill the empty spots (§37.2).
	local fillTo = math.min(LocalMeetConfig.FillToLifters, LocalMeetConfig.MaxLifters, #v.platforms)
	if realCount < fillTo and not hall.state then
		local templates: { ComputerLifters.Template } = {}
		for _, real in ipairs(current.lifters) do
			table.insert(templates, { classLabel = real.classLabel, bodyweightKg = real.bodyweightKg,
				competitionNumber = real.competitionNumber })
		end
		for cpuIndex, plan in ipairs(ComputerLifters.plan(templates, fillTo - realCount, cpuRandom)) do
			local lifts: { [string]: LiftRecord } = {}
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				lifts[lift] = { history = {}, passed = 0 }
			end
			local index = #current.lifters + 1
			table.insert(current.lifters, {
				hall = hall,
				player = nil,
				-- Far from any real player's: a Studio test server's players have UserIds -1, -2, ... (two lifters on one
			-- key overwrote each other in the standings, user's two-player test 2026-11-06).
			key = -1000 - cpuIndex,
				cpu = plan,
				body = nil,
				name = plan.name,
				platform = v.platforms[index],
				order = index,
				bodyweightKg = plan.bodyweightKg,
				classLabel = plan.classLabel,
				competitionNumber = plan.competitionNumber,
				lifts = lifts,
				withdrawn = false,
				choice = nil,
				chosenKg = nil,
				defaultKg = nil,
				readyPressed = false,
				roundDone = false,
				lights = nil,
				currentLift = nil,
				bestTotalKg = nil,
				localWins = 0,
				stateQualified = false,
				nationalsPlacings = 0,
				nationalsQualified = false,
				nationalsNews = nil,
				titles = {},
				championBadges = {},
				gymRecords = {},
				boardLines = nil,
				boardMood = nil,
				liftsStarted = 0,
				coinsEarned = 0,
			})
		end
	end
	hall.meet = current
	log("meet %d, a %s, starts: %d lifters, %d real (rewards: %s, solo: %s)", hall.index,
		MeetLevelConfig.Levels[current.level].label, #current.lifters, realCount, tostring(current.rewards),
		tostring(current.solo))
	task.spawn(runMeet, current)
end

-- ---------------------------------------------------------------- in and out of the venue

-- Takes a player out of the venue (EXIT, death, leaving the game), back to the gym when `sendBack`.
local function leaveVenue(player: Player, sendBack: boolean)
	stopWarmUps(player)
	local _, leaving = activeLifter(player)
	withdraw(player, "left the venue")
	-- Their sign-up stays: they can go and do something else, and are brought back for the meet (user 2026-11-06).
	local visit = visits[player]
	if visit == nil then
		if leaving then
			showDroppedSuit(leaving, player)
		end
		return
	end
	visits[player] = nil
	hallReadyAt[player] = nil
	for _, connection in ipairs(visit.connections) do
		connection:Disconnect()
	end
	if player.Parent then
		player:SetAttribute(LocalMeetConfig.VenueAttribute, nil)
		player:SetAttribute(LocalMeetConfig.HallAttribute, nil)
	end
	local hooks = nationalsHooks
	if visit.hall == NATIONALS_HALL_INDEX and hooks then
		hooks.onLeft(player)
	end
	local body = bodyOf(player)
	if sendBack and body and body.character == visit.character and body.humanoid.Health > 0 then
		body.root.Anchored = false
		local position = visit.returnTo.Position
		pcall(function()
			player:RequestStreamAroundAsync(position, STREAM_TIMEOUT_SECONDS)
		end)
		if player.Parent and body.character.Parent and body.humanoid.Health > 0 then
			body.character:PivotTo(visit.returnTo)
		end
	end
	log("%s left the venue", player.Name)
	broadcastLobby()
	if leaving then
		showDroppedSuit(leaving, player)
	end
end

--[[
	Moves `player` into the venue if everything allows it: through the doors
	(`point`, which they must be standing near) or by the TELEPORT menu (`point`
	nil). Returns whether they went, and why not when it is worth saying.
]]
enterVenue = function(player: Player, point: BasePart?, toHall: Hall?): (boolean, string?)
	-- Everyone arrives in hall 1 (the sign-up list and SPECTATE reach the others), unless they asked for a hall: WATCH.
	local firstHall = toHall or halls[1]
	if firstHall == nil then
		return false, "The Local meet is closed right now."
	end
	local v = firstHall.venue
	if visits[player] then
		return false, "You are already at the Local meet."
	end
	if entering[player] then
		return false, nil
	end
	if player:GetAttribute(MOCK_MEET_ATTRIBUTE) ~= nil then
		return false, "Leave the Mock Meet first."
	end
	local body = bodyOf(player)
	if body == nil or body.humanoid.Health <= 0 or body.root.Anchored then
		return false, nil
	end
	for _, attribute in ipairs(BUSY_ATTRIBUTES) do
		if body.character:GetAttribute(attribute) ~= nil then
			return false, "Get off the machine first."
		end
	end
	if point and (body.root.Position - point.Position).Magnitude > MAX_TRIGGER_DISTANCE + body.root.Size.Y then
		return false, nil
	end
	if LiftAttemptService.isAttemptActive(player) then
		return false, "Finish your lift first."
	end
	entering[player] = true
	local returnTo = body.root.CFrame
	local arrival = v.arrival * CFrame.new(0, standingHeight(body), 0)
	pcall(function()
		player:RequestStreamAroundAsync(arrival.Position, STREAM_TIMEOUT_SECONDS)
	end)
	entering[player] = nil
	local nowBody = bodyOf(player)
	if player.Parent == nil or nowBody == nil or nowBody.character ~= body.character or nowBody.humanoid.Health <= 0 then
		return false, nil
	end
	local visit: Visit = { character = body.character, returnTo = returnTo, connections = {}, hall = firstHall.index }
	visits[player] = visit
	body.character:PivotTo(arrival)
	player:SetAttribute(LocalMeetConfig.VenueAttribute, true)
	player:SetAttribute(LocalMeetConfig.HallAttribute, firstHall.index)
	table.insert(visit.connections, body.humanoid.Died:Connect(function()
		leaveVenue(player, false)
	end))
	table.insert(visit.connections, body.character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			leaveVenue(player, false)
		end
	end))
	log("%s entered the venue", player.Name)
	sendLobby(player)
	local current = firstHall.meet
	if current and remotes then
		remotes.standings:FireClient(player, buildStandings(current))
	end
	return true, nil
end

-- Through the doors: `player` must be standing near the entrance `point`. Returns whether they went.
function LocalMeetService.enter(player: Player, point: BasePart): boolean
	local went, problem = enterVenue(player, point)
	if problem then
		notify(player, problem)
	end
	return went
end

-- Through the State arena's doors (StateArenaService): `player` must be standing near the entrance `point`.
function LocalMeetService.enterState(player: Player, point: BasePart)
	for _, hall in ipairs(halls) do
		if hall.state then
			local _, problem = enterVenue(player, point, hall)
			if problem then
				notify(player, problem)
			end
			return
		end
	end
	notify(player, "The State arena is closed right now.")
end

-- The TELEPORT menu (TeleportService): into the venue from anywhere. Returns whether they went, and why not.
function LocalMeetService.teleportIn(player: Player): (boolean, string?)
	return enterVenue(player, nil)
end

--[[
	The TELEPORT menu, before it moves a player somewhere else: takes them out
	of the venue without sending them back (they stay on any sign-up list). A
	lifter in the running meet must press LEAVE first. Returns whether they may go.
]]
function LocalMeetService.teleportOut(player: Player): (boolean, string?)
	if visits[player] == nil then
		return true, nil
	end
	local current, lifter = activeLifter(player)
	if current and not current.final and lifter then
		return false, "You are lifting in this meet. Press LEAVE first."
	end
	leaveVenue(player, false)
	return true, nil
end

-- The hall with this number, if a client sent a real one.
local function hallFromClient(hallIndex: any): Hall?
	if typeof(hallIndex) ~= "number" or hallIndex ~= math.floor(hallIndex) then
		return nil
	end
	return halls[hallIndex]
end

-- A hall's sign-up desk and the SIGN UP buttons: puts the player's name on that meet's list (off any other), or takes it off.
local function toggleSignUp(player: Player, hall: Hall)
	local _, lifting = activeLifter(player)
	if lifting then
		notify(player, "You are lifting in a meet.")
		return
	end
	if signedUpAt(player) == hall then
		removeSignUp(player)
		notify(player, "You took your name off the list.")
	elseif hall.state and Workspace:GetAttribute(NationalsConfig.ServerAttribute) ~= nil then
		notify(player, "This is a Nationals server, so there is no State meet here.")
		return
	else
		local untilStart = hall.nextStartAt - now()
		if untilStart <= closesSeconds(hall) then
			notify(player, string.format("Sign-ups for %s are closed. They open again in %s.", meetName(hall),
				clockText(untilStart)))
			return
		end
		if hall.state then
			local qualified, why = stateLadder(player)
			if not qualified then
				notify(player, "State is for qualified lifters: " .. (why or "") .. ". Lift at Local and Regional meets to earn ladder points.")
				return
			end
		end
		if #hall.signUps >= maximumLifters(hall) then
			notify(player, if hall.state then "The list is full, but sign up again after the next meet." else "That list is full. Try another meet.")
			return
		end
		local weigh, problem = weighIn(player)
		if weigh == nil then
			notify(player, "You cannot sign up: " .. (problem or "unknown problem") .. ".")
			return
		end
		removeSignUp(player)
		table.insert(hall.signUps, player)
		notify(player, string.format("You are signed up for %s (%s class). It starts in %s.", meetName(hall),
			weigh.classLabel, clockText(untilStart)))
	end
	broadcastLobby()
end

-- SPECTATE: moves a player in the venue, not lifting, into another hall, at its doors. Their sign-up stays.
local function spectate(player: Player, hall: Hall)
	local visit = visits[player]
	local body = bodyOf(player)
	if visit == nil or body == nil or body.character ~= visit.character or body.humanoid.Health <= 0 then
		return
	end
	if visit.hall == hall.index then
		notify(player, string.format("You are already at %s.", meetName(hall)))
		return
	end
	local _, lifting = activeLifter(player)
	if lifting then
		notify(player, "You are lifting in a meet. Press LEAVE first.")
		return
	end
	if warmUp then
		warmUp.stop(player, false)
	end
	if LiftAttemptService.isAttemptActive(player) or entering[player] then
		return
	end
	entering[player] = true
	local arrival = hall.venue.arrival * CFrame.new(0, standingHeight(body), 0)
	pcall(function()
		player:RequestStreamAroundAsync(arrival.Position, STREAM_TIMEOUT_SECONDS)
	end)
	entering[player] = nil
	if player.Parent == nil or visits[player] ~= visit or body.humanoid.Health <= 0 then
		return
	end
	-- A meet this player signed up for may have started meanwhile.
	local _, nowLifting = activeLifter(player)
	if nowLifting then
		return
	end
	visit.hall = hall.index
	player:SetAttribute(LocalMeetConfig.HallAttribute, hall.index)
	body.root.Anchored = false
	body.character:PivotTo(arrival)
	log("%s is watching meet %d", player.Name, hall.index)
	sendLobby(player)
	local current = hall.meet
	if remotes then
		remotes.standings:FireClient(player, if current then buildStandings(current)
			else { heading = "STANDINGS", final = false, rows = {} })
	end
end

--[[
	WATCH on a record attempt (TeleportService): to the doors of that meet's hall, from
	the gym or from another hall. `hallIndex` comes from the client: anyone may go and
	watch any meet, so it can only choose a real hall. Returns whether they went, and why not.
]]
function LocalMeetService.watchMeet(player: Player, hallIndex: any): (boolean, string?)
	local hall = hallFromClient(hallIndex)
	if hall == nil then
		return false, nil
	end
	local visit = visits[player]
	if visit == nil then
		return enterVenue(player, nil, hall)
	end
	if visit.hall == hall.index then
		return false, string.format("You are already at meet %d.", hall.index)
	end
	local _, lifting = activeLifter(player)
	if lifting then
		return false, "You are lifting in a meet. Press LEAVE first."
	end
	spectate(player, hall)
	return visit.hall == hall.index, nil
end

-- ---------------------------------------------------------------- Nationals (GAME_DESIGN §39, NationalsService)

-- A message on the player's screen, as the meets' own.
function LocalMeetService.notify(player: Player, message: string)
	notify(player, message)
end

--[[
	Nationals is starting and `player` goes (user 2026-11-17: a spot-holder mid-meet elsewhere is pulled
	out): off any meet's list, off a warm-up rack, and out of a meet they lift in, which counts as
	withdrawing (their misses so far are saved now, while their data is still loaded). They stay where
	they are; NationalsService then sends them on.
]]
function LocalMeetService.pullOutForNationals(player: Player)
	removeSignUp(player)
	if warmUp then
		warmUp.stop(player, false)
	end
	local _, lifter = activeLifter(player)
	if lifter then
		withdraw(player, "went to Nationals")
		if visits[player] then
			standAt(player, LocalMeetVenue.lobbySpotFor(lifter.hall.venue, lifter.order), false)
		end
	end
	broadcastLobby()
end

--[[
	Out of the meet venue without sending them back (a lifter going to Nationals is moved on by NationalsService): off a
	rack, a machine or a lift too. Nothing when they aren't in it.
]]
function LocalMeetService.leaveForNationals(player: Player)
	if LiftAttemptService.isAttemptActive(player) then
		LiftAttemptService.abandon(player)
	end
	TrainingStationService.letGo(player, "You are going to Nationals.")
	CardioMachineService.hopOff(player)
	if visits[player] then
		leaveVenue(player, false)
	end
end

--[[
	The Nationals hall (NationalsArenaVenue.build, every server): its venue `v` (4 platforms, benches, callers, boards,
	screens), where leaving it by the meet screen's EXIT lands a player (`outside`, in front of the porch), and what the arena
	wants to hear. It is a hall like the others for visits, sounds, standings and its meet, but has no timetable, MEETS row
	or SPECTATE: NationalsService starts its meet (startNationalsMeet).
]]
function LocalMeetService.setNationalsVenue(v: LocalMeetVenue.Venue, outside: CFrame, hooks: NationalsHooks)
	nationalsOutside = outside
	nationalsHooks = hooks
	nationalsHall = { index = NATIONALS_HALL_INDEX, venue = v, signUps = {}, meet = nil, nextStartAt = math.huge,
		nextLevel = "Nationals", calledFor = nil, state = true, nationals = true }
	log("the Nationals hall is ready: %d platforms", #v.platforms)
end

--[[
	A player walked into the Nationals hall (NationalsArenaVenue.goInside, which moved them): a visitor of the hall now,
	for its sounds, standings, awards and the meet screen. Nothing when they are a visitor already. Out of any other hall
	first (Studio's stand-in, where the Local halls are in the same server).
]]
function LocalMeetService.visitNationals(player: Player)
	local hall = nationalsHall
	local outside = nationalsOutside
	local body = bodyOf(player)
	if hall == nil or outside == nil or body == nil or body.humanoid.Health <= 0 then
		return
	end
	local old = visits[player]
	if old and old.hall == NATIONALS_HALL_INDEX and old.character == body.character then
		return
	elseif old then
		leaveVenue(player, false)
	end
	local visit: Visit = { character = body.character, returnTo = outside, connections = {}, hall = NATIONALS_HALL_INDEX }
	visits[player] = visit
	player:SetAttribute(LocalMeetConfig.VenueAttribute, true)
	player:SetAttribute(LocalMeetConfig.HallAttribute, NATIONALS_HALL_INDEX)
	table.insert(visit.connections, body.humanoid.Died:Connect(function()
		leaveVenue(player, false)
	end))
	table.insert(visit.connections, body.character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			leaveVenue(player, false)
		end
	end))
	log("%s is in the Nationals hall", player.Name)
	sendLobby(player)
	local current = hall.meet
	if current and remotes then
		remotes.standings:FireClient(player, buildStandings(current))
	end
end

-- A player left the Nationals hall by its doors (NationalsArenaVenue.goOutside, which moves them): no longer a visitor;
-- a lifter in its meet withdraws. Nothing when they weren't in it.
function LocalMeetService.leaveNationalsVisit(player: Player)
	local visit = visits[player]
	if visit and visit.hall == NATIONALS_HALL_INDEX then
		leaveVenue(player, false)
	end
end

-- Whether the Nationals meet is running now.
function LocalMeetService.nationalsMeetRunning(): boolean
	local hall = nationalsHall
	return hall ~= nil and hall.meet ~= nil
end

--[[
	Starts the Nationals meet (GAME_DESIGN §39, NationalsService) for `entries`: each player with the class their spot is in.
	Only players inside the Nationals hall who still weigh in at that class lift (anyone else is told why). The lifters
	are sorted by class, lightest first, and dealt in turn onto the 4 platforms (each platform's lifters on its own benches),
	which all run at once, each lifting its own lifters in turn (user 2026-11-17). Every lifter competes on their spot
	(markNationalsCompeted, saved now). `onFinished` hears each lifter's class place when it is over. Returns whether it
	started, and why not.
]]
function LocalMeetService.startNationalsMeet(entries: { { player: Player, classKey: string } },
	onFinished: (places: { [number]: number? }) -> ()): (boolean, string?)
	local hall = nationalsHall
	if hall == nil then
		return false, "the Nationals hall isn't built"
	end
	if hall.meet ~= nil then
		return false, "the Nationals meet is already running"
	end
	type Ready = { player: Player, classKey: string, weigh: any, signed: number }
	local ready: { Ready } = {}
	for index, entry in ipairs(entries) do
		local player = entry.player
		local visit = visits[player]
		local body = bodyOf(player)
		if player.Parent == nil or visit == nil or visit.hall ~= NATIONALS_HALL_INDEX or body == nil
			or body.character ~= visit.character or body.humanoid.Health <= 0 then
			continue
		end
		local weigh, problem = weighIn(player)
		if weigh == nil then
			notify(player, "You cannot lift at Nationals: " .. (problem or "unknown problem") .. ".")
		elseif weigh.classLabel ~= entry.classKey then
			notify(player, string.format("You weigh in at %s now, but your Nationals spot is in %s. Weigh in at %s to lift.",
				weigh.classLabel, entry.classKey, entry.classKey))
		else
			table.insert(ready, { player = player, classKey = entry.classKey, weigh = weigh, signed = index })
		end
	end
	-- (as the gathering decides it: Studio 1; the admins' test Nationals while not Live, TestMeetMinimumLifters)
	local minimum = if RunService:IsStudio() then 1
		elseif NationalsConfig.Live then NationalsConfig.MeetMinimumLifters
		else NationalsConfig.TestMeetMinimumLifters
	if #ready < minimum then
		return false, string.format("only %d %s could lift (%d needed)", #ready, if #ready == 1 then "lifter" else "lifters",
			minimum)
	end
	table.sort(ready, function(a: Ready, b: Ready)
		if a.classKey ~= b.classKey then
			return classOrder(a.classKey, b.classKey)
		end
		return a.signed < b.signed
	end)
	local v = hall.venue
	local platforms = #v.platforms
	--[[
		Platforms (user 2026-11-18: "If they are in the same weight class put them in the same platform"): a weight class
		stays together on one platform. With no more classes than platforms each class gets its own; with more, whole
		classes are packed onto the platforms in order, about evenly. Only a class bigger than a platform's benches spills
		onto the next one. And when some class has only one lifter, the whole meet is placed together on points ("If there
		is two people at nationals and they are in different weightclasses, they will compete off the point system";
		Meet.pointsMode).
	]]
	local classSizes: { [string]: number } = {}
	local classList: { string } = {}
	for _, entry in ipairs(ready) do
		if classSizes[entry.classKey] == nil then
			classSizes[entry.classKey] = 0
			table.insert(classList, entry.classKey)
		end
		classSizes[entry.classKey] += 1
	end
	local pointsMode = false
	for _, size in pairs(classSizes) do
		if size == 1 then
			pointsMode = true
		end
	end
	local capacity = math.max(1, #(v.platforms[1].seats or {}))
	local platformOfClass: { [string]: number } = {}
	if #classList <= platforms then
		for index, classKey in ipairs(classList) do
			platformOfClass[classKey] = index
		end
	else
		local target = math.ceil(#ready / platforms)
		local p, count = 1, 0
		for _, classKey in ipairs(classList) do
			if count > 0 and count + classSizes[classKey] > target and p < platforms then
				p, count = p + 1, 0
			end
			platformOfClass[classKey] = p
			count += classSizes[classKey]
		end
	end
	local current: Meet = { hall = hall, lifters = {}, byPlayer = {}, heading = "WEIGH-IN", final = false, rewards = true,
		solo = false, rewardPlaces = {}, places = {}, level = "Nationals", liftOff = {}, pointsMode = pointsMode }
	local onPlatform: { [number]: number } = {}
	-- The platform with room nearest after `p` (a class bigger than a platform's benches spills over).
	local function withRoom(p: number): number
		for step = 0, platforms - 1 do
			local q = (p - 1 + step) % platforms + 1
			if (onPlatform[q] or 0) < capacity then
				return q
			end
		end
		return p
	end
	for index, entry in ipairs(ready) do
		local player = entry.player
		local weigh = entry.weigh
		removeSignUp(player)
		local lifts: { [string]: LiftRecord } = {}
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			lifts[lift] = { history = {}, passed = 0 }
		end
		local platformIndex = withRoom(platformOfClass[entry.classKey] or 1)
		onPlatform[platformIndex] = (onPlatform[platformIndex] or 0) + 1
		local platform = v.platforms[platformIndex]
		local seats = platform.seats
		local lifter: Lifter = {
			hall = hall,
			player = player,
			key = player.UserId,
			cpu = nil,
			body = nil,
			name = player.DisplayName,
			platform = platform,
			seat = if seats then seats[onPlatform[platformIndex]] else nil,
			order = index,
			bodyweightKg = weigh.bodyweightKg,
			classLabel = weigh.classLabel,
			competitionNumber = weigh.competitionNumber,
			lifts = lifts,
			withdrawn = false,
			choice = nil,
			chosenKg = nil,
			defaultKg = nil,
			readyPressed = false,
			roundDone = false,
			lights = nil,
			currentLift = nil,
			bestTotalKg = weigh.bestTotalKg,
			localWins = weigh.localWins,
			stateQualified = weigh.stateQualified,
			nationalsPlacings = weigh.nationals.placings,
			nationalsQualified = weigh.nationals.qualified,
			nationalsNews = nil,
			titles = weigh.titles,
			championBadges = weigh.championBadges,
			gymRecords = {},
			boardLines = nil,
			boardMood = nil,
			liftsStarted = 0,
			coinsEarned = 0,
		}
		table.insert(current.lifters, lifter)
		current.byPlayer[player] = lifter
		-- They compete on their spot now: it resets once this month is over (GAME_DESIGN §36.4 "The Nationals spot").
		local classKey = entry.classKey
		local marked = false
		PlayerDataService.update(player, function(data)
			marked = ProfileOperations.markNationalsCompeted(data, classKey, os.time())
		end)
		log("Nationals: %s (%s) on platform %d, spot used: %s", player.Name, classKey, platformIndex, tostring(marked))
	end
	hall.meet = current
	nationalsOnFinished = onFinished
	local used = 0
	for _ in pairs(onPlatform) do
		used += 1
	end
	log("the Nationals meet starts: %d lifters in %d classes on %d platforms, placed %s", #current.lifters, #classList, used,
		if pointsMode then "on points (a class of one)" else "by class on total")
	task.spawn(runMeet, current)
	return true, nil
end

-- How often one player may ask for the meets list, and when each last did.
local LOBBY_REQUEST_GAP_SECONDS = 0.5
local lastLobbyRequest: { [Player]: number } = {}

--[[
	The admin panel's START A MEET NOW (AdminService, user 2026-11-08: "automatically start any
	meet"). Every meet, for its buttons: its name, how many are signed up, whether it runs now.
]]
function LocalMeetService.adminMeets(): { { index: number, label: string, signedUp: number, running: boolean } }
	local list = {}
	for _, hall in ipairs(halls) do
		local label = if hall.state then "STATE"
			elseif hall.nextLevel ~= "Local" then string.format("MEET %d %s", hall.index, string.upper(hall.nextLevel))
			else "MEET " .. hall.index
		table.insert(list, { index = hall.index, label = label, signedUp = #hall.signUps, running = hall.meet ~= nil })
	end
	return list
end

--[[
	Starts meet `hallIndex` now instead of at its time: its start moves to now, and the meet clock
	below starts it as at any start (taking its signed-up lifters there, the weigh-in, the minimum
	number of lifters). Refused while it runs or with too few signed up. Returns whether it starts
	and what to tell the admin. SERVER-ONLY: AdminService checks the admin list first.
]]
function LocalMeetService.adminStartNow(hallIndex: any): (boolean, string)
	local hall = hallFromClient(hallIndex)
	if hall == nil then
		return false, "That isn't a meet."
	end
	local name = if hall.state then "The State meet" else "Meet " .. hall.index
	if hall.meet then
		return false, name .. " is already running."
	end
	local count, needed = #hall.signUps, minimumLifters(hall)
	if count < needed then
		return false, string.format("%s needs %d signed up; %d %s. Sign up from MEETS first.", name, needed, count,
			if count == 1 then "is" else "are")
	end
	hall.nextStartAt = now()
	log("%s started early by the admin panel, %d signed up", name, count)
	return true, string.format("%s starts now with %d signed up.", name, count)
end

local function pressAllowed(player: Player): boolean
	local time = os.clock()
	if time - (lastPress[player] or 0) < LocalMeetConfig.ButtonCooldownSeconds then
		return false
	end
	lastPress[player] = time
	return true
end

local function prompt(parent: BasePart, action: string, object: string, onTriggered: (Player) -> ()): ProximityPrompt
	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = action
	proximity.ObjectText = object
	proximity.HoldDuration = LocalMeetConfig.PromptHoldSeconds
	proximity.MaxActivationDistance = LocalMeetConfig.PromptDistanceStuds
	proximity.KeyboardKeyCode = Enum.KeyCode.E
	proximity.GamepadKeyCode = Enum.KeyCode.ButtonX
	proximity.RequiresLineOfSight = false
	proximity.Parent = parent
	proximity.Triggered:Connect(onTriggered)
	return proximity
end

local function setUpEntrance(instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local point = instance
	prompt(point, "Go to the Local Meet", "Local meet", function(player)
		LocalMeetService.enter(player, point)
	end)
end

function LocalMeetService.start()
	if started then
		return
	end
	started = true
	Trophies.preload()

	local set = LocalMeetRemotes.createOnServer(ReplicatedStorage)
	ComputerLifters.setWalkRemote(set.walk)
	MeetLiveScreens.start(set)
	MeetCheering.start(set)
	remotes = set
	set.choose.OnServerEvent:Connect(function(player, weightKg)
		local _, lifter = activeLifter(player)
		if lifter and typeof(weightKg) == "number" then
			lifter.choice = weightKg
		end
	end)
	-- A Nationals lift-off's lift (GAME_DESIGN §39): only while this lifter is picking one, and only one of the three.
	set.liftOffChoose.OnServerEvent:Connect(function(player, lift)
		local _, lifter = activeLifter(player)
		if lifter and lifter.liftOffChoosing and typeof(lift) == "string" and table.find(MeetConfig.LiftOrder, lift) then
			lifter.liftOffPick = lift
		end
	end)
	-- A screen says the Nationals hall has finished arriving on it (the opening waits for that): timing only, taken once
	-- per visit and only from someone in that hall.
	set.scene.OnServerEvent:Connect(function(player, what)
		local visit = visits[player]
		if what == "HallReady" and visit and visit.hall == NATIONALS_HALL_INDEX and hallReadyAt[player] == nil then
			hallReadyAt[player] = os.clock()
		end
	end)
	-- The lifter's live minigame progress (MeetLiftProgress): VISUAL ONLY, it moves their character's lift and
	-- never decides it. Checked for a number in 0..1 and rate-limited.
	set.liftProgress.OnServerEvent:Connect(function(player, fraction)
		local _, lifter = activeLifter(player)
		if typeof(fraction) ~= "number" or fraction ~= fraction then
			return
		end
		-- Not lifting in the meet: perhaps at a warm-up rack.
		if lifter == nil and warmUp then
			warmUp.progress(player, math.clamp(fraction, 0, 1))
		end
		if lifter == nil or lifter.livePhase == nil then
			return
		end
		local time = os.clock()
		if time - (lifter.progressAt or 0) < PROGRESS_MIN_GAP_SECONDS then
			return
		end
		lifter.progressAt = time
		MeetLiftAnimation.progress(lifter.liftAnim, lifter.livePhase, math.clamp(fraction, 0, 1))
	end)
	set.ready.OnServerEvent:Connect(function(player)
		local _, lifter = activeLifter(player)
		if lifter then
			lifter.readyPressed = true
		end
	end)
	set.leave.OnServerEvent:Connect(function(player)
		if not pressAllowed(player) then
			return
		end
		local _, lifter = activeLifter(player)
		withdraw(player, "pressed LEAVE")
		if lifter and visits[player] then
			standAt(player, LocalMeetVenue.lobbySpotFor(lifter.hall.venue, lifter.order), false)
		end
		if lifter then
			showDroppedSuit(lifter, player)
		end
	end)
	set.exit.OnServerEvent:Connect(function(player)
		if pressAllowed(player) then
			leaveVenue(player, true)
		end
	end)
	set.signUp.OnServerEvent:Connect(function(player, hallIndex)
		local hall = hallFromClient(hallIndex)
		if hall and pressAllowed(player) then
			toggleSignUp(player, hall)
		end
	end)
	set.spectate.OnServerEvent:Connect(function(player, hallIndex)
		local hall = hallFromClient(hallIndex)
		if hall and pressAllowed(player) then
			if visits[player] then
				spectate(player, hall)
			else
				-- WATCH on the MEETS tab, from elsewhere in the game.
				local _, why = LocalMeetService.watchMeet(player, hallIndex)
				if why then
					notify(player, why)
				end
			end
		end
	end)
	-- Not a button: it has its own limit, so opening the list can't swallow the SIGN UP pressed right after it.
	set.lobbyRequest.OnServerEvent:Connect(function(player)
		local time = os.clock()
		if time - (lastLobbyRequest[player] or 0) >= LOBBY_REQUEST_GAP_SECONDS then
			lastLobbyRequest[player] = time
			sendLobby(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeSignUp(player)
		lastLobbyRequest[player] = nil
		leaveVenue(player, false)
		entering[player] = nil
		lastPress[player] = nil
	end)

	for _, point in ipairs(CollectionService:GetTagged(LocalMeetConfig.EntranceTag)) do
		setUpEntrance(point)
	end
	CollectionService:GetInstanceAddedSignal(LocalMeetConfig.EntranceTag):Connect(setUpEntrance)

	-- The venue, then the timetable. Built in the background so the server's start is not held up.
	task.spawn(function()
		-- The entrance building outside the gym: its door point is tagged, so setUpEntrance gives it the prompt.
		if LocalMeetVenue.buildEntrance() == nil then
			warn("[LocalMeetService] the entrance building could not be built: there is no way into the Local meet")
		end
		-- One hall after another, handing back to the server between them. The doors open when all are up.
		local buildStart = os.clock()
		local allRacks: { LocalMeetVenue.WarmUpRack } = {}
		local builtHalls: { Hall } = {}
		for hallIndex = 1, LocalMeetConfig.HallCount do
			local built, problem = LocalMeetVenue.build(hallIndex)
			if built == nil then
				warn("[LocalMeetService] hall " .. hallIndex .. " could not be built: " .. tostring(problem))
				continue
			end
			table.insert(builtHalls, { index = #builtHalls + 1, venue = built, signUps = {}, meet = nil, nextStartAt = 0,
				nextLevel = "Local", state = false, nationals = false })
			for _, rack in ipairs(built.warmUpRacks) do
				table.insert(allRacks, rack)
			end
			task.wait()
		end
		if #builtHalls == 0 then
			return
		end
		-- The State arena, last on the list (GAME_DESIGN §36.4). Without it the five halls still run.
		local arena, arenaProblem = StateArenaVenue.build()
		if arena then
			stateArena = arena
			table.insert(builtHalls, { index = #builtHalls + 1, venue = arena.meet, signUps = {}, meet = nil, nextStartAt = 0,
				nextLevel = "State", state = true, nationals = false })
			for _, rack in ipairs(arena.meet.warmUpRacks) do
				stateRackSet[rack] = true
				table.insert(allRacks, rack)
			end
		else
			warn("[LocalMeetService] the State arena could not be built: " .. tostring(arenaProblem))
		end
		halls = builtHalls
		warmUp = LocalMeetWarmUp.new(allRacks, set, {
			canUse = function(player: Player, rack: LocalMeetVenue.WarmUpRack): (boolean, string?)
				local body = bodyOf(player)
				if visits[player] == nil or body == nil or body.humanoid.Health <= 0 then
					return false, nil
				end
				local _, lifter = activeLifter(player)
				-- The State arena's racks are for its lifters while they wait for their turn (user 2026-11-06).
				local atState = stateRackSet[rack] == true
				if atState and (lifter == nil or not lifter.hall.state) then
					return false, "These racks are for the lifters in the State meet."
				end
				if lifter and not (atState and not lifter.onTurn) then
					return false, "You are lifting in this meet."
				end
				if atState and lifter then
					offSeat(lifter)
				end
				if LiftAttemptService.isAttemptActive(player) then
					return false, "Finish your lift first."
				end
				return true, nil
			end,
			standAt = standAt,
			release = release,
			notify = notify,
			prompt = prompt,
			pressAllowed = pressAllowed,
		})
		for _, hall in ipairs(halls) do
			prompt(hall.venue.signUpPoint, "Sign up / take name off", if hall.state then "State desk" else "Meet " .. hall.index .. " desk", function(player)
				if pressAllowed(player) then
					toggleSignUp(player, hall)
				end
			end)
			prompt(hall.venue.exitPoint, "Back to the gym", "Exit", function(player)
				if visits[player] and pressAllowed(player) then
					leaveVenue(player, true)
				end
			end)
			-- THE LEAVE SIGN beside each platform's waiting spot (LocalMeetVenue, user 2026-11-24): hold to withdraw from
			-- the meet, as LEAVE does; the lifter stays in the venue. Only that platform's lifter sees it (LocalMeetController
			-- switches it on for them; it starts off), and the server checks it is theirs. Not at State or Nationals, whose
			-- lifters can walk to the arena's EXIT.
			for _, platform in ipairs(hall.venue.platforms) do
				if platform.leavePoint then
					local leave = prompt(platform.leavePoint, "Leave the meet", "Hold to withdraw", function(player)
						local current, lifter = activeLifter(player)
						if not pressAllowed(player) or lifter == nil or lifter.hall ~= hall or lifter.platform ~= platform
							or current == nil or current.final then
							return
						end
						withdraw(player, "held the LEAVE sign")
						if visits[player] then
							standAt(player, LocalMeetVenue.lobbySpotFor(hall.venue, lifter.order), false)
						end
						showDroppedSuit(lifter, player)
					end)
					leave.HoldDuration = 1.5
					-- (the sign sits clear of the doorway, ~7 studs from the waiting spot: a little more reach than the
					-- venue's other prompts)
					leave.MaxActivationDistance = 10
					leave.Enabled = false
					leave:SetAttribute("Hall", hall.index)
					leave:SetAttribute("Platform", platform.index)
					-- No prompt tile (user 2026-11-24: "it covers up the screen. Just have the screen n when players hold it
					-- the bar fills up"): the sign's own screen is the button and fills a bar (LocalMeetController).
					leave:SetAttribute("NoTile", true)
					CollectionService:AddTag(leave, LocalMeetConfig.LeavePromptTag)
				end
			end
			hall.nextStartAt = startAfter(now(), hall)
			rollLevel(hall)
		end
		log("venue ready in %.1f s: %d halls of %d platforms, each a meet every %d s (Studio: %s)", os.clock() - buildStart,
			#halls, #halls[1].venue.platforms, cycleSeconds(), tostring(RunService:IsStudio()))

		while true do
			for _, hall in ipairs(halls) do
				-- Anyone signed up from elsewhere hears they're about to go.
				if hall.calledFor ~= hall.nextStartAt and hall.meet == nil
					and hall.nextStartAt - now() <= LocalMeetConfig.CallSeconds then
					hall.calledFor = hall.nextStartAt
					for _, player in ipairs(hall.signUps) do
						if visits[player] == nil then
							notify(player, string.format("%s starts in %d seconds. Taking you there.",
								if hall.state then "The State meet" else "Meet " .. hall.index, LocalMeetConfig.CallSeconds))
						end
					end
				end
				-- (A State meet in progress has no next start yet: the wait starts when it finishes.)
				if now() >= hall.nextStartAt and not (hall.state and hall.meet) then
					tryStartMeet(hall)
					-- Its next meet's sign-ups open now, with its level (a meet that did not start does not keep its level).
					hall.nextStartAt = startAfter(now(), hall)
					rollLevel(hall)
					broadcastLobby()
				end
			end
			refreshEntranceSigns()
			task.wait(0.5)
		end
	end)
end

return LocalMeetService
