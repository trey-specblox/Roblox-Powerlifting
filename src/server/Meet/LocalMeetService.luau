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
	rewards (Meet.solo): Scale, CN at half speed (SoloCostMultiplier),
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

	THE TIMETABLE. A meet starts on every multiple of CycleSeconds of server time
	if at least MinimumLifters signed up at the venue's desk (prompt or SIGN UP
	button; the same press takes a name off). Sign-ups close SignUpClosesSeconds
	before a start. The first MaxLifters on the list lift; the rest stay on it
	for the next meet, as do all names when too few signed up. A start during a
	running meet is skipped.

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
local TeleportConfig = require(ConfigFolder:WaitForChild("TeleportConfig"))
local CoinConfig = require(ConfigFolder:WaitForChild("CoinConfig"))
local MeetLevelConfig = require(ConfigFolder:WaitForChild("MeetLevelConfig"))
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local LiftAttemptConfig = require(ConfigFolder:WaitForChild("LiftAttemptConfig"))
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))
local StationAnimationConfig = require(ConfigFolder:WaitForChild("StationAnimationConfig"))
local MeetSoundConfig = require(ConfigFolder:WaitForChild("MeetSoundConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local LocalMeetRemotes = require(MeetFolder:WaitForChild("LocalMeetRemotes"))
local MockMeetRemotes = require(MeetFolder:WaitForChild("MockMeetRemotes"))
local AttemptRules = require(MeetFolder:WaitForChild("AttemptRules"))
local AttemptChoice = require(MeetFolder:WaitForChild("AttemptChoice"))
local MeetTotal = require(MeetFolder:WaitForChild("MeetTotal"))
local MeetPlacing = require(MeetFolder:WaitForChild("MeetPlacing"))

local ServerFolder = script.Parent.Parent
local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))
local LocalMeetWarmUp = require(script.Parent:WaitForChild("LocalMeetWarmUp"))
local GymRecords = require(script.Parent:WaitForChild("GymRecords"))
local MeetPayout = require(script.Parent:WaitForChild("MeetPayout"))
local Trophies = require(script.Parent:WaitForChild("Trophies"))
local ComputerLifters = require(script.Parent:WaitForChild("ComputerLifters"))
local MeetLiftAnimation = require(script.Parent:WaitForChild("MeetLiftAnimation"))
local PlayerDataFolder = ServerFolder:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))

local LocalMeetService = {}

-- Marks other systems put on a character: a cardio rider or a lifter posed at a rack cannot go.
local BUSY_ATTRIBUTES = { "CardioMachine", "StationPose" }
-- The Mock Meet's room attribute: a player in their private room is not in the gym.
local MOCK_MEET_ATTRIBUTE = "MockMeetSlot"
local MAX_TRIGGER_DISTANCE = LocalMeetConfig.PromptDistanceStuds + 4
local STREAM_TIMEOUT_SECONDS = 5
local POLL_SECONDS = 0.1
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
}

type Lifter = {
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
	-- Their meet titles (career.titles, GAME_DESIGN §35.8): id -> count.
	titles: { [string]: number },
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
	-- The last attempt's result and weight, for the other lifters' coaches ("Tess missed 30 kg!").
	lastResult: string?,
	lastKg: number?,
	-- On the walk out to the platform or back (GAME_DESIGN §37.5); a new walk bumps the token and ends the old one.
	walking: boolean?,
	walkToken: number?,
	-- The lift being animated on the platform (MeetLiftAnimation, §37.5).
	liftAnim: MeetLiftAnimation.Handle?,
	-- A player's running minigame phase (1 or 2), while it runs: its live progress moves the lift (§37.5).
	livePhase: number?,
	-- When their last progress update came (at most one per PROGRESS_MIN_GAP_SECONDS is used).
	progressAt: number?,
	-- From the walk out until they are back in the warm-up room: the next round waits for it.
	outOnPlatform: boolean?,
}

type Meet = {
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
}

local venue: LocalMeetVenue.Venue? = nil
-- The warm-up room's working racks (made once the venue is built).
local warmUp: LocalMeetWarmUp.WarmUp? = nil
local remotes: LocalMeetRemotes.RemoteSet? = nil
local started = false

local visits: { [Player]: Visit } = {}
local entering: { [Player]: boolean } = {}
local signUps: { Player } = {}
local meet: Meet? = nil
local nextStartAt = 0
-- The next meet's level, rolled when its sign-ups open (GAME_DESIGN §35.8).
local nextLevel = "Local"
local levelRandom = Random.new()
-- Computer lifters' strength, attempts and makes (§37.2).
local cpuRandom = Random.new()
local lastPress: { [Player]: number } = {}

local function log(message: string, ...: any)
	print("[LocalMeetService] " .. string.format(message, ...))
end

local function notify(player: Player, message: string)
	if remotes and player.Parent then
		remotes.notice:FireClient(player, message)
	end
end

local function cycleSeconds(): number
	return if RunService:IsStudio() then LocalMeetConfig.StudioCycleSeconds else LocalMeetConfig.CycleSeconds
end

local function closesSeconds(): number
	return if RunService:IsStudio() then LocalMeetConfig.StudioSignUpClosesSeconds else LocalMeetConfig.SignUpClosesSeconds
end

local function minimumLifters(): number
	return if RunService:IsStudio() then LocalMeetConfig.StudioMinimumLifters else LocalMeetConfig.MinimumLifters
end

local function rewardMinimumLifters(): number
	return if RunService:IsStudio() then LocalMeetConfig.StudioRewardMinimumLifters
		else LocalMeetConfig.RewardMinimumLifters
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- The next timetable start after `time`.
local function startAfter(time: number): number
	local cycle = cycleSeconds()
	return (math.floor(time / cycle) + 1) * cycle
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

local function signedUp(player: Player): boolean
	return table.find(signUps, player) ~= nil
end

local function removeSignUp(player: Player)
	local index = table.find(signUps, player)
	if index then
		table.remove(signUps, index)
	end
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

local function sendLobby(player: Player)
	if remotes == nil or visits[player] == nil then
		return
	end
	local state: LocalMeetRemotes.LobbyState = {
		allowancePercent = allowancePercent(player),
		nextStartAt = nextStartAt,
		signUpClosesAt = nextStartAt - closesSeconds(),
		signedUpCount = #signUps,
		signedUp = signedUp(player),
		meetRunning = meet ~= nil,
		minimumLifters = minimumLifters(),
		maxLifters = LocalMeetConfig.MaxLifters,
		levelLabel = MeetLevelConfig.Levels[nextLevel].label,
		potMultiplier = MeetLevelConfig.Levels[nextLevel].potMultiplier,
		titles = MeetLevelConfig.Levels[nextLevel].titles,
	}
	remotes.lobby:FireClient(player, state)
end

local function broadcastLobby()
	for player in pairs(visits) do
		sendLobby(player)
	end
end

-- What a level pays, for its boards ("Prize pot x3", "Top 3 earn titles").
local function perksOf(level: string): { string }
	local info = MeetLevelConfig.Levels[level]
	if info.potMultiplier <= 1 then
		return { "Everyone lifts together", "Best score wins" }
	end
	return { string.format("Prize pot x%d", info.potMultiplier), if info.titles then "Top 3 earn titles" else "" }
end

--[[
	Rolls the next meet's level as its sign-ups open (GAME_DESIGN §35.8) and
	shows it on the venue's boards. A Regional or State meet is announced to
	everyone in the server. In Studio, the workspace attribute
	"ForceMeetLevel" ("Local", "Regional" or "State") picks the level, for
	testing.
]]
local function rollLevel()
	local forced = if RunService:IsStudio() then Workspace:GetAttribute("ForceMeetLevel") else nil
	nextLevel = if typeof(forced) == "string" and MeetLevelConfig.Levels[forced] then forced
		else MeetLevelConfig.roll(levelRandom:NextNumber())
	local info = MeetLevelConfig.Levels[nextLevel]
	if venue then
		LocalMeetVenue.setLevel(venue, info.label, perksOf(nextLevel))
	end
	if nextLevel ~= "Local" then
		log("the next meet is a %s (prize pot x%d)", info.label, info.potMultiplier)
		if remotes then
			local news: LocalMeetRemotes.LevelNews = {
				levelLabel = info.label,
				potMultiplier = info.potMultiplier,
				startsAt = nextStartAt,
				signUpClosesAt = nextStartAt - closesSeconds(),
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
	}
	if extra then
		for key, value in pairs(extra) do
			state[key] = value
		end
	end
	remotes.state:FireClient(player, state)
end

-- The standings: everyone's bests, subtotal, live (or final) score and place, best first.
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
		table.insert(entries, { key = lifter.key, classLabel = lifter.classLabel, bodyweightKg = lifter.bodyweightKg,
			totalKg = rankKg, goodLifts = goodLiftCount(lifter), order = lifter.order })
		rowsByKey[lifter.key] = {
			name = lifter.name,
			platform = lifter.platform.index,
			classLabel = lifter.classLabel,
			bodyweightKg = lifter.bodyweightKg,
			best = result.best,
			subtotalKg = subtotal,
			scorePercent = nil,
			place = nil,
			status = status,
			lights = lifter.lights,
		}
	end
	local rows: { LocalMeetRemotes.StandingRow } = {}
	for _, placing in ipairs(MeetPlacing.rank(entries)) do
		local row = rowsByKey[placing.key]
		row.scorePercent = if placing.score then placing.score * 100 else nil
		row.place = placing.place
		table.insert(rows, row)
	end
	return { heading = current.heading, final = current.final, rows = rows }
end

-- Sends the standings to everyone in the venue and writes them on the scoreboard.
local function updateStandings(current: Meet)
	local standings = buildStandings(current)
	if remotes then
		for player in pairs(visits) do
			remotes.standings:FireClient(player, standings)
		end
	end
	local v = venue
	if v then
		local lines: { string } = {}
		for _, row in ipairs(standings.rows) do
			table.insert(lines, string.format("%s  %s  ·  %s  ·  %s kg%s",
				if row.place then placeText(row.place) else "—", row.name, row.classLabel, kgText(row.subtotalKg),
				if row.scorePercent then string.format("  ·  %.1f%%", row.scorePercent)
					elseif row.status == "Bombed" then "  ·  BOMBED OUT"
					elseif row.status == "Withdrawn" then "  ·  WITHDRAWN" else ""))
		end
		LocalMeetVenue.setScoreboard(v, if standings.final then "FINAL STANDINGS" else standings.heading, lines)
	end
end

-- ---------------------------------------------------------------- what the meet saves (step 2)

--[[
	Saves one lifter's meet in ONE write (see the header): Competition Scale and
	best Total when `totalKg` is set; the CN settlement, and a win for 1st place,
	when the meet rewards. `totalKg` nil = no total (a bomb-out, or withdrawn):
	nothing is raised and only the misses above CN use the meet allowance.
	`place` is the lifter's place among the REAL lifters (§37.2). A meet with
	one real player (`current.solo`) settles CN at half speed and pays only the
	finishing ladder points: no win, title, or place points. A computer lifter
	saves nothing. Returns short lines for the lifter's result screen.
]]
local function saveLifter(current: Meet, lifter: Lifter, totalKg: number?, best: { [string]: number },
	place: number?): { string }
	local lines: { string } = {}
	local player = lifter.player
	-- CN is settled in full meets and, at half speed, in a meet with one real player (§37.1).
	local settlesCn = current.rewards or current.solo
	if player == nil or (totalKg == nil and not settlesCn) then
		return lines
	end
	local cnCost = if current.rewards then 1 else ProgressionConfig.MeetCnAllowance.SoloCostMultiplier
	local nowUnix = os.time()
	local scaleOutcomes: { [string]: ProfileOperations.ScaleRaiseOutcome } = {}
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
	local ladderOutcome: ProfileOperations.LadderOutcome? = nil
	local ladder: ProfileOperations.LadderView? = nil
	local saved = PlayerDataService.update(player, function(data)
		if totalKg then
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				local kg = best[lift]
				if kg then
					scaleOutcomes[lift] = ProfileOperations.raiseCompetitionScale(data, lifter.classLabel, lift, kg)
				end
			end
			totalOutcome = ProfileOperations.raiseBestTotal(data, lifter.classLabel, totalKg)
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
		end
		if current.rewards then
			if totalKg and place == 1 then
				wins = ProfileOperations.addLocalWin(data)
			end
			if titleId then
				titleCount = ProfileOperations.addTitle(data, titleId)
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
		table.insert(lines, if titleCount > 1 then string.format("%s x%d", title, titleCount) else "New title: " .. title)
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
	log("%s saved (%s, total %s, rewards %s, solo %s): CN S %s B %s D %s, best Total %s, wins %s, ladder +%d %s",
		player.Name, lifter.classLabel, if totalKg then kgText(totalKg) else "none", tostring(current.rewards),
		tostring(current.solo),
		tostring(cnOutcomes.Squat), tostring(cnOutcomes.Bench), tostring(cnOutcomes.Deadlift), tostring(totalOutcome),
		tostring(wins), ladderPoints, tostring(ladderOutcome))
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
	-- The best titles first: State over Regional, champion over runner-up.
	for _, id in ipairs({ "StateChampion", "StateRunnerUp", "StateThird", "RegionalChampion", "RegionalRunnerUp",
		"RegionalThird" }) do
		local count = lifter.titles[id]
		if count and count > 0 then
			local name = string.upper(MeetLevelConfig.Titles[id])
			table.insert(facts, if count > 1 then string.format("%dx %s", count, name) else name)
		end
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
-- After the referee's start command, a beat before the lift starts.
local COMMAND_BEAT_SECONDS = 0.6
-- Room in a round for the unrack (squat walk-out) and the start command.
local UNRACK_ALLOWANCE_SECONDS = 8
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
	onArrive: (() -> ())?)
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
				ComputerLifters.walkBody(body.character, points, final, current)
			end
			if current() then
				standAt(player, final, anchoredAtEnd)
			end
		else
			ComputerLifters.walkBody(lifter.body, points, final, current)
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

-- A sound on the lifter's platform, on every player's screen (MeetSoundController). Sound only.
local function soundCue(lifter: Lifter, cue: string)
	local set, rack = remotes, lifter.platform.rack
	if set and rack then
		set.sound:FireAllClients(cue, rack:GetPivot().Position)
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
	MeetLiftAnimation.stop(lifter.liftAnim)
	local character, rack = characterOf(lifter), lifter.platform.rack
	lifter.liftAnim = if character and rack then MeetLiftAnimation.begin(character, rack, lift) else nil
end

-- The lift is over on the platform: the animation stops and the referee falls silent.
local function endLift(lifter: Lifter)
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
	its first or second minigame; GAME_DESIGN §37.5 "The fail animations"). The
	default for now; the user's future unboxable fail animations plug in here,
	like themeFor and celebrationFor.
]]
local function failAnimationFor(_lifter: Lifter, lift: string, part: number): StationAnimationConfig.Fail?
	return StationAnimationConfig.failFor(lift, part)
end

--[[
	The end of a lift on the platform (§37.5): after a good lift the finish
	(stand up, press, lower) and the referee's RACK (the deadlift's DOWN was
	said at lockout); after a miss the fail animation for the part that failed
	(`failedPart`), and the spotters take the bar. The sound the bar makes follows
	its weight (`weightKg`). Returns the seconds until a missed bar lands or is
	caught (0 after a good lift).
]]
local function finishLift(lifter: Lifter, lift: string, good: boolean, failedPart: number, weightKg: number): number
	lifter.livePhase = nil
	local fail = if good then nil else failAnimationFor(lifter, lift, failedPart)
	local seconds = MeetLiftAnimation.finish(lifter.liftAnim, good, fail)
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

-- The walk back from the platform to the warm-up room: back on their feet where they are, out to the lift spot,
-- then the way out, reversed.
local function walkBack(lifter: Lifter)
	endLift(lifter)
	-- A good squat or bench: the bar goes back into the J-cups now (StationPoseAnimator glides it there).
	if lifter.lastResult == "GoodLift" and lifter.currentLift ~= "Deadlift" then
		task.delay(MeetSoundConfig.RackGlideSeconds, soundCue, lifter, "BarRack")
	end
	local function home()
		lifter.outOnPlatform = false
	end
	local character = characterOf(lifter)
	local spot = lifter.platform.liftSpot
	if character then
		local at = character:GetPivot().Position
		local here = CFrame.new(at.X, spot.Y, at.Z) * spot.Rotation
		local player = lifter.player
		if player then
			standAt(player, here, true)
		else
			ComputerLifters.moveBody(lifter.body, here)
		end
	end
	local back: { Vector3 } = { spot.Position }
	for index = #lifter.platform.walkOut, 1, -1 do
		table.insert(back, lifter.platform.walkOut[index])
	end
	-- A computer lifter cheers a good lift before walking off, as players emote (§37.2).
	local cheerSeconds = LocalMeetConfig.ComputerLifters.GoodLiftCheerSeconds
	if lifter.player == nil and lifter.lastResult == "GoodLift" and lifter.body then
		ComputerLifters.cheer(lifter.body, cheerSeconds)
		local token = lifter.walkToken
		task.delay(cheerSeconds, function()
			if lifter.walkToken == token and stillLifting(lifter) then
				walkLifter(lifter, back, lifter.platform.waitSpot, true, home)
			end
		end)
		return
	end
	-- Held still at their waiting spot until the next walk out (user 2026-11-04): a lifter stays put all meet.
	walkLifter(lifter, back, lifter.platform.waitSpot, true, home)
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
		if meet == current and not current.final and stillLifting(lifter) and lifter.boardLines then
			boardFor(lifter, lifter.boardLines :: { string }, lifter.boardMood)
		end
		-- The gym record bonus (GAME_DESIGN 30.5, 30.6): someone else's record or your own; never an empty spot.
		local bonus = MeetPayout.forGymRecord(userId, broken :: any, CoinConfig.LocalMeet)
		if bonus and player.Parent then
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
	if meet == current and not current.final and stillLifting(lifter) and lifter.boardLines then
		boardFor(lifter, lifter.boardLines :: { string }, lifter.boardMood)
	end
	GymRecords.announceAttempt(player.Name, player.UserId, lifter.classLabel, chasing,
		MeetLevelConfig.Levels[current.level].label,
		TeleportConfig.LocalMeetId)
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
	local current = meet
	local lifter = current and current.byPlayer[player]
	if current == nil or lifter == nil or lifter.withdrawn then
		return
	end
	lifter.withdrawn = true
	-- No total: nothing is raised, and the misses so far use the meet allowance (§33.3b). Saved at once,
	-- while the player's data is still loaded.
	if not current.final then
		saveLifter(current, lifter, nil, {}, nil)
	end
	LiftAttemptService.abandon(player)
	LiftAttemptService.setFreeAttemptsBlocked(player, false)
	endLift(lifter)
	if player.Parent then
		player:SetAttribute(LocalMeetConfig.PlatformAttribute, nil)
	end
	release(player)
	-- Off the platform: the doorways are closed to anyone walking back by themselves.
	standAt(player, lifter.platform.waitSpot, false)
	LocalMeetVenue.clearStaff(lifter.platform)
	LocalMeetVenue.setLights(lifter.platform, nil)
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
local function liftOne(current: Meet, lifter: Lifter, lift: string, attemptNumber: number, weightKg: number)
	local player = lifter.player
	local verdict: string? = nil
	-- Which part of the lift (minigame 1 or 2) a miss failed in: the fail animation shows it.
	local failedPart = 1
	waitUntil(WALK_OUT_TIMEOUT_SECONDS, function()
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
		soundCue(lifter, "BarRack")
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
		local function onPhase(event: string, index: number, count: number, seconds: number?, passed: boolean?)
			if not stillLifting(lifter) then
				return
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
	local result: AttemptRules.AttemptResult = if verdict == "GoodLift" then "GoodLift" else "NoLift"
	-- The attempt is over: the sign comes down (a record it set shows in the facts once saved).
	lifter.recordAttempt = nil
	local good = result == "GoodLift"
	table.insert(lifter.lifts[lift].history, { weightKg = weightKg, result = result })
	lifter.lastResult, lifter.lastKg = result, weightKg
	local barLandsIn = finishLift(lifter, lift, good, failedPart, weightKg)
	if good then
		saveOfficialBest(current, lifter, lift, weightKg)
	end
	-- The minigames decide; the three referees show it.
	lifter.lights = if good then { "White", "White", "White" } else { "Red", "Red", "Red" }
	lifter.roundDone = true
	LocalMeetVenue.setLights(lifter.platform, lifter.lights)
	soundCue(lifter, if good then "LightsGood" else "LightsBad")
	-- The hall cheers the lights, and groans when the missed bar actually goes.
	task.delay(MeetSoundConfig.CrowdDelaySeconds + barLandsIn, soundCue, lifter, if good then "CrowdCheer" else "CrowdGroan")
	LocalMeetVenue.coachSays(lifter.platform, pick(if good then COACH_GOOD else COACH_MISS))
	boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber),
		string.format("%s KG  ·  %s", kgText(weightKg), if good then "GOOD LIFT" else "NO LIFT"), lightsText(lifter.lights) },
		if good then "good" else "bad")
	sendState(lifter, "Result", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg, verdict = result,
		lights = lifter.lights })
	log("%s %s attempt %d: %s kg %s", lifter.name, lift, attemptNumber, kgText(weightKg), result)
	updateStandings(current)
	-- Rack the bar and walk away (§37.5): back to the warm-up room, while the others still lift. After a good lift
	-- soon after its finish; after a miss once its fail animation has played. A walk out that started meanwhile wins.
	local token = lifter.walkToken
	local finish = StationAnimationConfig.MeetStages[lift].finish
	local leaveIn = if good then finish[2] - finish[1] + LEAVE_AFTER_FINISH_SECONDS else LocalMeetConfig.ResultSeconds
	task.delay(leaveIn, function()
		if meet == current and not current.final and stillLifting(lifter) and lifter.walkToken == token then
			walkBack(lifter)
		end
	end)
end

-- ---------------------------------------------------------------- the race (user 2026-11-01)

type LiveScore = { lifter: Lifter, score: number, place: number }

-- Everyone's live score (best lifts so far / their class's score Total), best first, with their place.
local function liveScores(current: Meet): { LiveScore }
	local list: { LiveScore } = {}
	for _, lifter in ipairs(current.lifters) do
		if not lifter.withdrawn and not bombed(lifter) then
			local subtotal = 0
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				subtotal += bestOf(lifter, lift) or 0
			end
			local score = if subtotal > 0 then MeetPlacing.score(lifter.classLabel, subtotal) else nil
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

--[[
	What this attempt can do for `lifter` (MockMeetRemotes.RaceView): for each
	rival with a score, the lightest weight on the meet's step that puts the
	lifter's score above theirs if made (0 = already ahead). Scores compare
	totals across classes, so the kilograms already include that sum: the
	player never has to work out a percentage.
]]
local function raceFor(current: Meet, lifter: Lifter, lift: string, attemptNumber: number): MockMeetRemotes.RaceView
	local reference = MeetLevelConfig.ScoreTotals[lifter.classLabel] or 1
	local step = LocalMeetConfig.WeightStepKg
	local others = 0
	for _, name in ipairs(MeetConfig.LiftOrder) do
		if name ~= lift then
			others += bestOf(lifter, name) or 0
		end
	end
	local bestHere = bestOf(lifter, lift) or 0
	local rivals: { MockMeetRemotes.RaceRival } = {}
	local place: number? = nil
	for _, entry in ipairs(liveScores(current)) do
		if entry.lifter == lifter then
			place = entry.place
		else
			-- My score beats theirs once my subtotal passes theirs measured in my class.
			local needSubtotal = entry.score * reference
			local needKg = 0
			if others + bestHere <= needSubtotal + 1e-6 then
				needKg = (math.floor((needSubtotal - others) / step + 1e-6) + 1) * step
			end
			table.insert(rivals, { name = entry.lifter.name, needKg = needKg })
		end
	end
	return {
		place = place,
		rivals = rivals,
		mustMake = bestHere <= 0 and attemptNumber >= MeetConfig.AttemptsPerLift,
	}
end

--[[
	What the coach tells their lifter as they choose (only that lifter sees it):
	a bomb-out warning first, then a rival ahead who just missed ("Tess missed
	30 kg! 27.5 kg takes 1st."), then the next place to chase, or that they lead.
]]
local function coachLineFor(current: Meet, lifter: Lifter, race: MockMeetRemotes.RaceView, maxKg: number): string?
	if race.mustMake then
		return "Make this one or you bomb out. Play it safe!"
	end
	local ahead: { { name: string, needKg: number, place: number, missed: boolean, missedKg: number? } } = {}
	local byName: { [string]: Lifter } = {}
	for _, other in ipairs(current.lifters) do
		byName[other.name] = other
	end
	local places: { [string]: number } = {}
	for _, entry in ipairs(liveScores(current)) do
		places[entry.lifter.name] = entry.place
	end
	for _, rival in ipairs(race.rivals) do
		local other = byName[rival.name]
		if rival.needKg > 0 and other then
			table.insert(ahead, { name = rival.name, needKg = rival.needKg, place = places[rival.name] or 0,
				missed = other.lastResult == "NoLift", missedKg = other.lastKg })
		end
	end
	-- The nearest place first.
	table.sort(ahead, function(a, b)
		return a.needKg < b.needKg
	end)
	for _, rival in ipairs(ahead) do
		if rival.missed and rival.needKg <= maxKg then
			return string.format("%s missed %s kg! %s kg takes %s.", rival.name, kgText(rival.missedKg or 0),
				kgText(rival.needKg), placeText(rival.place))
		end
	end
	local nearest = ahead[1]
	if nearest and nearest.needKg <= maxKg then
		return string.format("%s kg passes %s for %s.", kgText(nearest.needKg), nearest.name, placeText(nearest.place))
	elseif nearest then
		return string.format("%s is out of reach this attempt. Lock in your spot.", nearest.name)
	elseif #race.rivals > 0 then
		return "You're in the lead. Don't give it away!"
	end
	return nil
end

-- One round: everyone chooses, everyone lifts, the lights show.
local function runRound(current: Meet, lift: string, attemptNumber: number)
	current.heading = string.format("%s  ·  ROUND %d", string.upper(lift), attemptNumber)
	updateStandings(current)

	-- Choose.
	local choosing: { Lifter } = {}
	for _, lifter in ipairs(activeLifters(current)) do
		lifter.choice, lifter.chosenKg, lifter.readyPressed, lifter.roundDone, lifter.lights = nil, nil, false, false, nil
		lifter.announcedKg, lifter.recordAttempt = nil, nil
		lifter.currentLift = lift
		-- The rack set up for this lift, like a gym training rack (§37.5): no bench for squat and deadlift.
		LocalMeetVenue.rackFor(lifter.platform, lift)
		local cn = lifter.competitionNumber[lift]
		local history = lifter.lifts[lift].history
		local minKg, default = AttemptChoice.nextWeights(cn, history, LocalMeetConfig.WeightStepKg,
			LocalMeetConfig.OpenerSuggestionPercent)
		if minKg == nil or default == nil then
			-- No heavier weight is allowed inside the bounds: the attempt is passed.
			lifter.lifts[lift].passed += 1
			lifter.roundDone = true
			sendState(lifter, "Waiting", { lift = lift, attemptNumber = attemptNumber,
				note = "Attempt passed: no heavier weight is allowed. Waiting for the other lifters." })
			boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber), "PASSED" })
		else
			lifter.defaultKg = default
			local _, maxKg = AttemptChoice.bounds(cn, LocalMeetConfig.WeightStepKg)
			table.insert(choosing, lifter)
			if lifter.player == nil then
				-- A computer lifter declares at once (§37.2).
				lifter.chosenKg = ComputerLifters.nextWeight(cn, history, attemptNumber) or default
			end
			if lifter.player and bombed(lifter) then
				-- No total any more: no race to show.
				sendState(lifter, "Choose", { lift = lift, attemptNumber = attemptNumber, minKg = minKg, maxKg = maxKg,
					suggestedKg = default, secondsLeft = LocalMeetConfig.ChooseSeconds })
				LocalMeetVenue.coachSays(lifter.platform, "No total today. Use these lifts as practice.")
			elseif lifter.player then
				-- The race: what this attempt can do, in kilograms, and the coach's word on it (only they see it).
				local race = raceFor(current, lifter, lift, attemptNumber)
				sendState(lifter, "Choose", { lift = lift, attemptNumber = attemptNumber, minKg = minKg, maxKg = maxKg,
					suggestedKg = default, secondsLeft = LocalMeetConfig.ChooseSeconds, race = race })
				LocalMeetVenue.coachSays(lifter.platform, coachLineFor(current, lifter, race, maxKg))
			end
			boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber), "CHOOSING A WEIGHT" })
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
						LocalMeetConfig.WeightStepKg, requested)
					if kg then
						lifter.chosenKg = kg
						task.spawn(announceAttempt, current, lifter, lift, kg)
						sendState(lifter, "Waiting", { lift = lift, attemptNumber = attemptNumber, declaredKg = kg,
							note = string.format("%s kg declared. Waiting for the other lifters to choose.", kgText(kg)) })
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

	-- Lift: everyone on their own platform at once; each walks out, sets up and lifts on the referee's command.
	local lifting: { Lifter } = {}
	for _, lifter in ipairs(choosing) do
		if stillLifting(lifter) then
			local weightKg = lifter.chosenKg or lifter.defaultKg or 0
			lifter.chosenKg = weightKg
			-- A weight left to the default (time ran out) can be a record attempt too.
			task.spawn(announceAttempt, current, lifter, lift, weightKg)
			lifter.readyPressed = false
			LocalMeetVenue.setLights(lifter.platform, nil)
			-- The walk out from the warm-up room straight in to the bar (§37.5: the rack faces the entrance), then set
			-- up for the lift.
			lifter.outOnPlatform = true
			local approach = lifter.platform.rack and MeetLiftAnimation.approachFor(lifter.platform.rack, lift)
			walkLifter(lifter, lifter.platform.walkOut, approach or lifter.platform.liftSpot, true, function()
				setUpLift(lifter, lift)
			end)
			LocalMeetVenue.coachSays(lifter.platform, pick(COACH_READY))
			boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber),
				string.format("BAR LOADED  ·  %s KG", kgText(weightKg)) })
			sendState(lifter, "Ready", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg,
				autoLift = true })
			table.insert(lifting, lifter)
			task.spawn(liftOne, current, lifter, lift, attemptNumber, weightKg)
		end
	end
	waitUntil(WALK_OUT_TIMEOUT_SECONDS + UNRACK_ALLOWANCE_SECONDS + LIFT_TIMEOUT_SECONDS + 2, function()
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

-- Tells everyone in the venue the awards ceremony has started (the camera shots, the cheer, the theme song).
local function announceAwards(current: Meet, v: LocalMeetVenue.Venue)
	local gold: CFrame? = v.podiumSpots[1]
	if remotes == nil or gold == nil then
		return
	end
	-- The theme and celebration are a real winner's; a computer lifter in 1st gets the stage without them.
	local winner: Player? = nil
	local winnerName: string? = nil
	for _, lifter in ipairs(current.lifters) do
		local placing = current.places[lifter.key]
		local player = lifter.player
		if placing and placing.place == 1 and not lifter.withdrawn and player and visits[player] then
			winner, winnerName = player, lifter.name
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
		seconds = LocalMeetConfig.DoneSeconds,
	}
	for player in pairs(visits) do
		remotes.awards:FireClient(player, moment)
	end
end

-- Ends the meet: the final ranking, everyone's result, then the platforms are cleared.
local function finishMeet(current: Meet)
	current.final = true
	current.heading = "FINAL"
	-- Any walk back from the last round ends here: the awards place everyone.
	for _, lifter in ipairs(current.lifters) do
		lifter.walkToken = (lifter.walkToken or 0) + 1
		lifter.walking = false
		endLift(lifter)
	end
	local entries: { MeetPlacing.Entry } = {}
	for _, lifter in ipairs(current.lifters) do
		local result = MeetTotal.resolve(meetAttempts(lifter))
		table.insert(entries, { key = lifter.key, classLabel = lifter.classLabel, bodyweightKg = lifter.bodyweightKg,
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
	for _, placing in ipairs(MeetPlacing.rank(entries)) do
		current.places[placing.key] = placing
		if placing.place and realKeys[placing.key] then
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
	-- The coins (GAME_DESIGN 30.6, §37.2): only an official meet pays, never a Solo / Mock Meet; real lifters
	-- only, by their order among themselves. With one real player there is no prize pot: only the finishing
	-- and 9/9 coins.
	local payouts: { [number]: { MeetPayout.Item } } = {}
	if current.rewards or current.solo then
		local results: { MeetPayout.Lifter } = {}
		for _, lifter in ipairs(current.lifters) do
			if lifter.player then
				local place = current.rewardPlaces[lifter.key]
				local good = goodLiftCount(lifter)
				table.insert(results, { key = lifter.key, place = place, hasTotal = not lifter.withdrawn and place ~= nil,
					qualified = lifter.liftsStarted > 0, perfect = good == #MeetConfig.LiftOrder * MeetConfig.AttemptsPerLift })
			end
		end
		local settings = CoinConfig.LocalMeet
		if not current.rewards then
			settings = table.clone(settings)
			settings.BasePot = 0
			settings.PerQualifiedLifter = 0
		end
		local multiplier = MeetLevelConfig.Levels[current.level].potMultiplier
		payouts = MeetPayout.forMeet(results, settings, multiplier)
		log("prize pot %d coins (%s, x%d, solo %s)", MeetPayout.pot(results, settings, multiplier), current.level, multiplier,
			tostring(current.solo))
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
				table.insert(saved, "Alone with computer lifters: half strength, no prize pot")
			end
		end
		if lifter.coinsEarned > 0 then
			table.insert(saved, 1, string.format("+%s %s", CoinConfig.format(lifter.coinsEarned), CoinConfig.Name))
		end
		local note: string
		if placing and placing.place and placing.score then
			note = string.format("%s PLACE of %d  ·  SCORE %.1f%%%s", string.upper(placeText(placing.place)),
				#current.lifters, placing.score * 100, if #saved > 0 then "  ·  " .. table.concat(saved, "  ·  ") else "")
			boardFor(lifter, { string.format("%s PLACE", string.upper(placeText(placing.place))),
				string.format("TOTAL %s KG", kgText(result.total or 0)), string.format("SCORE %.1f%%", placing.score * 100) })
		else
			note = "No total, no place  ·  A bomb-out saves nothing" .. (if current.rewards or current.solo
				then " (misses above your CN still used your meet allowance)" else "")
			boardFor(lifter, { if lifter.withdrawn then "WITHDRAWN" else "BOMBED OUT" })
		end
		LocalMeetVenue.coachSays(lifter.platform, if result.total and not lifter.withdrawn then "Great meet. Proud of you."
			else "We'll get them next time.")
		sendState(lifter, "Done", { best = result.best, total = result.total, bombedOut = result.bombedOut, note = note })
		log("%s finished the Local meet: %s", lifter.name,
			if placing and placing.place then string.format("%s, total %s", placeText(placing.place), kgText(result.total or 0))
				else "no total")
	end
	log("Local meet over: %d lifters, %d placed (rewards: %s)", #current.lifters, placed, tostring(current.rewards))

	-- The awards: the racks make way for the awards stage, and the top three stand on its podium while the final
	-- standings show.
	local v = venue
	if v then
		LocalMeetVenue.showAwards(v, true)
		for _, lifter in ipairs(current.lifters) do
			local placing = current.places[lifter.key]
			local spot = placing and placing.place and v.podiumSpots[placing.place]
			local player = lifter.player
			if spot and not lifter.withdrawn and player == nil then
				-- A computer lifter in the top 3 stands on the podium too, without a trophy, cheering.
				ComputerLifters.moveBody(lifter.body, spot)
				ComputerLifters.cheer(lifter.body, LocalMeetConfig.DoneSeconds)
			elseif spot and not lifter.withdrawn and player and visits[player] then
				standAt(player, spot, true)
				-- A Regional or State meet's top 3 hold a trophy (GAME_DESIGN §35.8), in a meet that pays in full.
				local character = player.Character
				if MeetLevelConfig.Levels[current.level].titles and current.rewards and character and placing and placing.place then
					Trophies.give(character, placing.place)
				end
			end
		end
		announceAwards(current, v)
	end

	task.wait(LocalMeetConfig.DoneSeconds)
	Trophies.clear()
	if v then
		LocalMeetVenue.showAwards(v, false)
	end
	for index, lifter in ipairs(current.lifters) do
		local player = lifter.player
		LocalMeetVenue.clearStaff(lifter.platform)
		LocalMeetVenue.setLights(lifter.platform, nil)
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
			if v and visits[player] then
				standAt(player, LocalMeetVenue.lobbySpotFor(v, index), false)
			end
		end
	end
	meet = nil
	broadcastLobby()
end

local function runMeet(current: Meet)
	local v = venue
	if v == nil then
		meet = nil
		return
	end
	for _, lifter in ipairs(current.lifters) do
		local player = lifter.player
		local plan = lifter.cpu
		if player then
			player:SetAttribute(LocalMeetConfig.PlatformAttribute, lifter.platform.index)
			if warmUp then
				warmUp.stop(player, false)
			end
			LiftAttemptService.setFreeAttemptsBlocked(player, true)
			-- Held still from here until the meet ends or they withdraw (user 2026-11-04).
			standAt(player, lifter.platform.waitSpot, true)
		elseif plan then
			lifter.body = ComputerLifters.spawnBody(plan, lifter.platform.waitSpot, cpuRandom)
		end
		LocalMeetVenue.staffPlatform(lifter.platform)
		-- Only the lifter sees their referees' and coach's tags and what the coach says; a computer lifter's staff
		-- show nothing (§37.4, §37.5).
		LocalMeetVenue.staffFor(lifter.platform, player)
		boardFor(lifter, { "WEIGH-IN", string.format("%s CLASS  ·  %.1f KG", lifter.classLabel, lifter.bodyweightKg) })
		sendState(lifter, "WeighIn", { secondsLeft = LocalMeetConfig.WeighInSeconds })
	end
	current.heading = "WEIGH-IN"
	updateStandings(current)
	broadcastLobby()
	task.wait(LocalMeetConfig.WeighInSeconds)
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
	bestTotalKg: number?, localWins: number, titles: { [string]: number }, stateQualified: boolean }?, string?)
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
		stateQualified = ProfileOperations.getLadder(data, classKey, os.time()).qualified }, nil
end

-- At a timetable start: holds the meet if enough signed-up lifters are ready.
local function tryStartMeet()
	local v = venue
	if v == nil or meet ~= nil then
		return
	end
	-- Only names still in the venue, alive and free can lift; the list keeps its order.
	local ready: { Player } = {}
	for _, player in ipairs(table.clone(signUps)) do
		local body = bodyOf(player)
		local visit = visits[player]
		if visit == nil or body == nil or body.character ~= visit.character or body.humanoid.Health <= 0 then
			removeSignUp(player)
		elseif not LiftAttemptService.isAttemptActive(player) then
			table.insert(ready, player)
		end
	end
	if #ready < minimumLifters() then
		if #ready > 0 then
			log("not enough lifters (%d of %d): no meet", #ready, minimumLifters())
		end
		for _, player in ipairs(ready) do
			notify(player, string.format("Not enough lifters signed up (%d of %d). You stay on the list for the next meet.",
				#ready, minimumLifters()))
		end
		return
	end

	local current: Meet = { lifters = {}, byPlayer = {}, heading = "WEIGH-IN", final = false, rewards = false,
		solo = false, rewardPlaces = {}, places = {}, level = nextLevel }
	for _, player in ipairs(ready) do
		if #current.lifters >= LocalMeetConfig.MaxLifters then
			notify(player, "This meet is full. You stay on the list for the next one.")
			continue
		end
		local weigh, problem = weighIn(player)
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
		local lifter: Lifter = {
			player = player,
			key = player.UserId,
			cpu = nil,
			body = nil,
			name = player.DisplayName,
			platform = v.platforms[index],
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
			titles = weigh.titles,
			gymRecords = {},
			boardLines = nil,
			boardMood = nil,
			liftsStarted = 0,
			coinsEarned = 0,
		}
		table.insert(current.lifters, lifter)
		current.byPlayer[player] = lifter
	end
	if #current.lifters < minimumLifters() then
		-- Someone could not lift after all: back on the list, in front.
		for index = #current.lifters, 1, -1 do
			table.insert(signUps, 1, current.lifters[index].player :: Player)
		end
		log("not enough lifters could weigh in: no meet")
		return
	end
	-- Full rewards need enough REAL players; one real player gets the reduced ones (§37.2). In Studio the
	-- workspace attribute "ForceSoloMeet" tests the reduced ones alone.
	local realCount = #current.lifters
	local forceSolo = RunService:IsStudio() and Workspace:GetAttribute("ForceSoloMeet") == true
	current.rewards = realCount >= rewardMinimumLifters() and not forceSolo
	current.solo = not current.rewards
	-- Computer lifters fill the empty spots (§37.2).
	local fillTo = math.min(LocalMeetConfig.FillToLifters, LocalMeetConfig.MaxLifters, #v.platforms)
	if realCount < fillTo then
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
				player = nil,
				key = -cpuIndex,
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
				titles = {},
				gymRecords = {},
				boardLines = nil,
				boardMood = nil,
				liftsStarted = 0,
				coinsEarned = 0,
			})
		end
	end
	meet = current
	log("%s starts: %d lifters, %d real (rewards: %s, solo: %s)", MeetLevelConfig.Levels[current.level].label,
		#current.lifters, realCount, tostring(current.rewards), tostring(current.solo))
	task.spawn(runMeet, current)
end

-- ---------------------------------------------------------------- in and out of the venue

-- Takes a player out of the venue (EXIT, death, leaving the game), back to the gym when `sendBack`.
local function leaveVenue(player: Player, sendBack: boolean)
	if warmUp then
		warmUp.stop(player, false)
	end
	withdraw(player, "left the venue")
	removeSignUp(player)
	local visit = visits[player]
	if visit == nil then
		return
	end
	visits[player] = nil
	for _, connection in ipairs(visit.connections) do
		connection:Disconnect()
	end
	if player.Parent then
		player:SetAttribute(LocalMeetConfig.VenueAttribute, nil)
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
end

--[[
	Moves `player` into the venue if everything allows it: through the doors
	(`point`, which they must be standing near) or by the TELEPORT menu (`point`
	nil). Returns whether they went, and why not when it is worth saying.
]]
local function enterVenue(player: Player, point: BasePart?): (boolean, string?)
	local v = venue
	if v == nil then
		return false, "The Local meet is closed right now."
	end
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
	local visit: Visit = { character = body.character, returnTo = returnTo, connections = {} }
	visits[player] = visit
	body.character:PivotTo(arrival)
	player:SetAttribute(LocalMeetConfig.VenueAttribute, true)
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
	local current = meet
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

-- The TELEPORT menu (TeleportService): into the venue from anywhere. Returns whether they went, and why not.
function LocalMeetService.teleportIn(player: Player): (boolean, string?)
	return enterVenue(player, nil)
end

--[[
	The TELEPORT menu, before it moves a player somewhere else: takes them out
	of the venue (and off the sign-up list) without sending them back. A lifter
	in the running meet must press LEAVE first. Returns whether they may go.
]]
function LocalMeetService.teleportOut(player: Player): (boolean, string?)
	if visits[player] == nil then
		return true, nil
	end
	local current = meet
	local lifter = current and current.byPlayer[player]
	if current and not current.final and lifter and not lifter.withdrawn then
		return false, "You are lifting in this meet. Press LEAVE first."
	end
	leaveVenue(player, false)
	return true, nil
end

-- The sign-up desk and the SIGN UP button: puts the player's name on the list, or takes it off.
local function toggleSignUp(player: Player)
	if visits[player] == nil then
		return
	end
	local current = meet
	if current and current.byPlayer[player] and not current.byPlayer[player].withdrawn then
		notify(player, "You are lifting in this meet.")
		return
	end
	if signedUp(player) then
		removeSignUp(player)
		notify(player, "You took your name off the list.")
	else
		local untilStart = nextStartAt - now()
		if untilStart <= closesSeconds() then
			notify(player, string.format("Sign-ups for this meet are closed. They open again in %s.", clockText(untilStart)))
			return
		end
		if #signUps >= LocalMeetConfig.MaxLifters then
			notify(player, "The list is full. Try again for the next meet.")
			return
		end
		local weigh, problem = weighIn(player)
		if weigh == nil then
			notify(player, "You cannot sign up: " .. (problem or "unknown problem") .. ".")
			return
		end
		table.insert(signUps, player)
		notify(player, string.format("You are signed up (%s class). The meet starts in %s.", weigh.classLabel,
			clockText(untilStart)))
	end
	broadcastLobby()
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
	remotes = set
	set.choose.OnServerEvent:Connect(function(player, weightKg)
		local current = meet
		local lifter = current and current.byPlayer[player]
		if lifter and typeof(weightKg) == "number" then
			lifter.choice = weightKg
		end
	end)
	-- The lifter's live minigame progress (MeetLiftProgress): VISUAL ONLY, it moves their character's lift and
	-- never decides it. Checked for a number in 0..1 and rate-limited.
	set.liftProgress.OnServerEvent:Connect(function(player, fraction)
		local current = meet
		local lifter = current and current.byPlayer[player]
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
		local current = meet
		local lifter = current and current.byPlayer[player]
		if lifter then
			lifter.readyPressed = true
		end
	end)
	set.leave.OnServerEvent:Connect(function(player)
		if not pressAllowed(player) then
			return
		end
		local current = meet
		local lifter = current and current.byPlayer[player]
		withdraw(player, "pressed LEAVE")
		local v = venue
		if lifter and v and visits[player] then
			standAt(player, LocalMeetVenue.lobbySpotFor(v, lifter.order), false)
		end
	end)
	set.exit.OnServerEvent:Connect(function(player)
		if pressAllowed(player) then
			leaveVenue(player, true)
		end
	end)
	set.signUp.OnServerEvent:Connect(function(player)
		if pressAllowed(player) then
			toggleSignUp(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
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
		local built, problem = LocalMeetVenue.build()
		if built == nil then
			warn("[LocalMeetService] the venue could not be built: " .. tostring(problem))
			return
		end
		venue = built
		warmUp = LocalMeetWarmUp.new(built.warmUpRacks, set, {
			canUse = function(player: Player): (boolean, string?)
				local body = bodyOf(player)
				if visits[player] == nil or body == nil or body.humanoid.Health <= 0 then
					return false, nil
				end
				local current = meet
				local lifter = current and current.byPlayer[player]
				if lifter and not lifter.withdrawn then
					return false, "You are lifting in this meet."
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
		prompt(built.signUpPoint, "Sign up / take name off", "Local meet desk", function(player)
			if pressAllowed(player) then
				toggleSignUp(player)
			end
		end)
		prompt(built.exitPoint, "Back to the gym", "Exit", function(player)
			if visits[player] and pressAllowed(player) then
				leaveVenue(player, true)
			end
		end)
		log("venue ready: %d platforms, a meet every %d s (Studio: %s)", #built.platforms, cycleSeconds(),
			tostring(RunService:IsStudio()))

		nextStartAt = startAfter(now())
		rollLevel()
		while true do
			if now() >= nextStartAt then
				tryStartMeet()
				-- The next meet's sign-ups open now, with its level (a meet that did not start does not keep its level).
				nextStartAt = startAfter(now())
				rollLevel()
				broadcastLobby()
			end
			task.wait(0.5)
		end
	end)
end

return LocalMeetService
