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
		- 1st place in such a meet: one Local win (career.localWins)
	A lifter who withdraws, exits, dies or leaves has no total: only their
	misses are settled, at once.

	GETTING THERE. A tagged point in the gym (LocalMeetConfig.EntranceTag) gets a
	"Go to the Local Meet" prompt; the server checks the player is alive, on
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
		Done: everyone's total, the ranking by score (MeetPlacing), the place.
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
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local LiftAttemptConfig = require(ConfigFolder:WaitForChild("LiftAttemptConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local LocalMeetRemotes = require(MeetFolder:WaitForChild("LocalMeetRemotes"))
local MockMeetRemotes = require(MeetFolder:WaitForChild("MockMeetRemotes"))
local AttemptRules = require(MeetFolder:WaitForChild("AttemptRules"))
local AttemptChoice = require(MeetFolder:WaitForChild("AttemptChoice"))
local MeetTotal = require(MeetFolder:WaitForChild("MeetTotal"))
local MeetPlacing = require(MeetFolder:WaitForChild("MeetPlacing"))

local ServerFolder = script.Parent.Parent
local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))
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
	player: Player,
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
}

type Meet = {
	lifters: { Lifter },
	byPlayer: { [Player]: Lifter },
	heading: string,
	final: boolean,
	-- Whether it started with enough lifters to raise CN and count a win (RewardMinimumLifters).
	rewards: boolean,
	-- The final placing, by UserId (set when the meet ends).
	places: { [number]: MeetPlacing.Placing },
}

local venue: LocalMeetVenue.Venue? = nil
local remotes: LocalMeetRemotes.RemoteSet? = nil
local started = false

local visits: { [Player]: Visit } = {}
local entering: { [Player]: boolean } = {}
local signUps: { Player } = {}
local meet: Meet? = nil
local nextStartAt = 0
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
	}
	remotes.lobby:FireClient(player, state)
end

local function broadcastLobby()
	for player in pairs(visits) do
		sendLobby(player)
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
	if remotes == nil or lifter.withdrawn or lifter.player.Parent == nil then
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
	remotes.state:FireClient(lifter.player, state)
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
		table.insert(entries, { key = lifter.player.UserId, classLabel = lifter.classLabel, bodyweightKg = lifter.bodyweightKg,
			totalKg = rankKg, order = lifter.order })
		rowsByKey[lifter.player.UserId] = {
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
	Returns short lines for the lifter's result screen.
]]
local function saveLifter(current: Meet, lifter: Lifter, totalKg: number?, best: { [string]: number },
	place: number?): { string }
	local player = lifter.player
	local lines: { string } = {}
	if totalKg == nil and not current.rewards then
		return lines
	end
	local nowUnix = os.time()
	local scaleOutcomes: { [string]: ProfileOperations.ScaleRaiseOutcome } = {}
	local cnOutcomes: { [string]: string } = {}
	local cnAfter: { [string]: number } = {}
	local totalOutcome: ProfileOperations.ScaleRaiseOutcome? = nil
	local wins: number? = nil
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
		if current.rewards then
			for _, lift in ipairs(MeetConfig.LiftOrder) do
				local outcome, cnKg = ProfileOperations.settleMeetCompetitionNumber(data, lifter.classLabel, lift,
					lifter.competitionNumber[lift], lifter.lifts[lift].history, totalKg ~= nil, nowUnix)
				cnOutcomes[lift] = outcome
				if cnKg then
					cnAfter[lift] = cnKg
				end
			end
			if totalKg and place == 1 then
				wins = ProfileOperations.addLocalWin(data)
			end
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
	if wins then
		table.insert(lines, string.format("Local wins: %d of %d for Nationals", wins, MeetConfig.LocalVictoriesForNationals))
	end
	log("%s saved (%s, total %s, rewards %s): CN S %s B %s D %s, best Total %s, wins %s", player.Name, lifter.classLabel,
		if totalKg then kgText(totalKg) else "none", tostring(current.rewards), tostring(cnOutcomes.Squat),
		tostring(cnOutcomes.Bench), tostring(cnOutcomes.Deadlift), tostring(totalOutcome), tostring(wins))
	return lines
end

local function lightsText(lights: { string }?): string
	if lights == nil then
		return ""
	end
	return "LIGHTS  " .. table.concat(lights, " · "):upper()
end

local function boardFor(lifter: Lifter, lines: { string })
	LocalMeetVenue.setPlatformBoard(lifter.platform, string.upper(lifter.name), lines)
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
	return not lifter.withdrawn and lifter.player.Parent ~= nil
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
	if player.Parent then
		player:SetAttribute(LocalMeetConfig.PlatformAttribute, nil)
	end
	release(player)
	LocalMeetVenue.clearStaff(lifter.platform)
	boardFor(lifter, { "WITHDRAWN" })
	log("%s withdrew from the meet (%s)", player.Name, why)
	if not current.final then
		updateStandings(current)
	end
end

-- One lifter's lift in a round: waits for LIFT, runs the minigames, records the verdict.
local function liftOne(current: Meet, lifter: Lifter, lift: string, attemptNumber: number, weightKg: number)
	local player = lifter.player
	local ready = waitUntil(LocalMeetConfig.ReadySeconds, function()
		return not stillLifting(lifter) or (lifter.readyPressed and not LiftAttemptService.isAttemptActive(player))
	end)
	if not stillLifting(lifter) then
		return
	end
	local verdict: string? = nil
	if ready then
		local ok, problem = LiftAttemptService.startServerAttempt(player, lift, weightKg, function(result)
			verdict = result
		end)
		if ok then
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
	else
		notify(player, "Time ran out: no lift.")
	end
	local result: AttemptRules.AttemptResult = if verdict == "GoodLift" then "GoodLift" else "NoLift"
	local good = result == "GoodLift"
	table.insert(lifter.lifts[lift].history, { weightKg = weightKg, result = result })
	-- The minigames decide; the three referees show it.
	lifter.lights = if good then { "White", "White", "White" } else { "Red", "Red", "Red" }
	lifter.roundDone = true
	LocalMeetVenue.coachSays(lifter.platform, pick(if good then COACH_GOOD else COACH_MISS))
	boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber),
		string.format("%s KG  ·  %s", kgText(weightKg), if good then "GOOD LIFT" else "NO LIFT"), lightsText(lifter.lights) })
	sendState(lifter, "Result", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg, verdict = result,
		lights = lifter.lights })
	log("%s %s attempt %d: %s kg %s", player.Name, lift, attemptNumber, kgText(weightKg), result)
	updateStandings(current)
end

-- One round: everyone chooses, everyone lifts, the lights show.
local function runRound(current: Meet, lift: string, attemptNumber: number)
	current.heading = string.format("%s  ·  ROUND %d", string.upper(lift), attemptNumber)
	updateStandings(current)

	-- Choose.
	local choosing: { Lifter } = {}
	for _, lifter in ipairs(activeLifters(current)) do
		lifter.choice, lifter.chosenKg, lifter.readyPressed, lifter.roundDone, lifter.lights = nil, nil, false, false, nil
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
			sendState(lifter, "Choose", { lift = lift, attemptNumber = attemptNumber, minKg = minKg, maxKg = maxKg,
				suggestedKg = default, secondsLeft = LocalMeetConfig.ChooseSeconds })
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
						sendState(lifter, "Waiting", { lift = lift, attemptNumber = attemptNumber, declaredKg = kg,
							note = string.format("%s kg declared. Waiting for the other lifters to choose.", kgText(kg)) })
					else
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

	-- Lift: everyone on their own platform at once; each presses LIFT when ready.
	local lifting: { Lifter } = {}
	for _, lifter in ipairs(choosing) do
		if stillLifting(lifter) then
			local weightKg = lifter.chosenKg or lifter.defaultKg or 0
			lifter.chosenKg = weightKg
			lifter.readyPressed = false
			standAt(lifter.player, lifter.platform.liftSpot, true)
			LocalMeetVenue.coachSays(lifter.platform, pick(COACH_READY))
			boardFor(lifter, { string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber),
				string.format("BAR LOADED  ·  %s KG", kgText(weightKg)) })
			sendState(lifter, "Ready", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg,
				secondsLeft = LocalMeetConfig.ReadySeconds })
			table.insert(lifting, lifter)
			task.spawn(liftOne, current, lifter, lift, attemptNumber, weightKg)
		end
	end
	waitUntil(LocalMeetConfig.ReadySeconds + LIFT_TIMEOUT_SECONDS + 2, function()
		for _, lifter in ipairs(lifting) do
			if stillLifting(lifter) and not lifter.roundDone then
				return false
			end
		end
		return true
	end)

	-- The last verdict stays up for a moment before the next round.
	task.wait(LocalMeetConfig.ResultSeconds)
	for _, lifter in ipairs(lifting) do
		LocalMeetVenue.coachSays(lifter.platform, nil)
		if stillLifting(lifter) then
			release(lifter.player)
		end
	end
end

-- Ends the meet: the final ranking, everyone's result, then the platforms are cleared.
local function finishMeet(current: Meet)
	current.final = true
	current.heading = "FINAL"
	local entries: { MeetPlacing.Entry } = {}
	for _, lifter in ipairs(current.lifters) do
		local result = MeetTotal.resolve(meetAttempts(lifter))
		table.insert(entries, { key = lifter.player.UserId, classLabel = lifter.classLabel, bodyweightKg = lifter.bodyweightKg,
			totalKg = if lifter.withdrawn then nil else result.total, order = lifter.order })
	end
	for _, placing in ipairs(MeetPlacing.rank(entries)) do
		current.places[placing.key] = placing
	end
	updateStandings(current)

	local placed = 0
	for _, placing in pairs(current.places) do
		if placing.place then
			placed += 1
		end
	end
	for _, lifter in ipairs(current.lifters) do
		local result = MeetTotal.resolve(meetAttempts(lifter))
		local placing = current.places[lifter.player.UserId]
		local saved: { string } = {}
		if not lifter.withdrawn then
			saved = saveLifter(current, lifter, result.total, result.best, placing and placing.place)
		end
		local note: string
		if placing and placing.place and placing.score then
			note = string.format("%s PLACE of %d  ·  SCORE %.1f%%%s", string.upper(placeText(placing.place)),
				#current.lifters, placing.score * 100, if #saved > 0 then "  ·  " .. table.concat(saved, "  ·  ") else "")
			boardFor(lifter, { string.format("%s PLACE", string.upper(placeText(placing.place))),
				string.format("TOTAL %s KG", kgText(result.total or 0)), string.format("SCORE %.1f%%", placing.score * 100) })
		else
			note = "No total, no place  ·  A bomb-out saves nothing" .. (if current.rewards
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

	task.wait(LocalMeetConfig.DoneSeconds)
	local v = venue
	for index, lifter in ipairs(current.lifters) do
		local player = lifter.player
		LocalMeetVenue.clearStaff(lifter.platform)
		LocalMeetVenue.setPlatformBoard(lifter.platform, "PLATFORM " .. lifter.platform.index, { "Free" })
		if not lifter.withdrawn then
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
		player:SetAttribute(LocalMeetConfig.PlatformAttribute, lifter.platform.index)
		LiftAttemptService.setFreeAttemptsBlocked(player, true)
		LocalMeetVenue.staffPlatform(lifter.platform)
		standAt(player, lifter.platform.waitSpot, false)
		boardFor(lifter, { "WEIGH-IN", string.format("%s CLASS  ·  %.1f KG", lifter.classLabel, lifter.bodyweightKg) })
		sendState(lifter, "WeighIn", { secondsLeft = LocalMeetConfig.WeighInSeconds })
	end
	current.heading = "WEIGH-IN"
	updateStandings(current)
	broadcastLobby()
	task.wait(LocalMeetConfig.WeighInSeconds)
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		for attemptNumber = 1, MeetConfig.AttemptsPerLift do
			if #activeLifters(current) == 0 then
				log("every lifter left: the meet ends early")
				finishMeet(current)
				return
			end
			runRound(current, lift, attemptNumber)
		end
	end
	finishMeet(current)
end

-- Reads a signed-up player's weigh-in, or nil and why they cannot lift.
local function weighIn(player: Player): ({ bodyweightKg: number, classLabel: string, competitionNumber: { [string]: number } }?, string?)
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
	return { bodyweightKg = data.bodyweight.currentKg, classLabel = classKey, competitionNumber = competitionNumber }, nil
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
		places = {} }
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
		}
		table.insert(current.lifters, lifter)
		current.byPlayer[player] = lifter
	end
	if #current.lifters < minimumLifters() then
		-- Someone could not lift after all: back on the list, in front.
		for index = #current.lifters, 1, -1 do
			table.insert(signUps, 1, current.lifters[index].player)
		end
		log("not enough lifters could weigh in: no meet")
		return
	end
	current.rewards = #current.lifters >= rewardMinimumLifters()
	meet = current
	log("Local meet starts: %d lifters (rewards: %s)", #current.lifters, tostring(current.rewards))
	task.spawn(runMeet, current)
end

-- ---------------------------------------------------------------- in and out of the venue

-- Takes a player out of the venue (EXIT, death, leaving the game), back to the gym when `sendBack`.
local function leaveVenue(player: Player, sendBack: boolean)
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

-- Moves `player` from the gym into the venue if everything allows it. Returns whether they went.
function LocalMeetService.enter(player: Player, point: BasePart): boolean
	local v = venue
	if v == nil then
		notify(player, "The Local meet is closed right now.")
		return false
	end
	if visits[player] or entering[player] or player:GetAttribute(MOCK_MEET_ATTRIBUTE) ~= nil then
		return false
	end
	local body = bodyOf(player)
	if body == nil or body.humanoid.Health <= 0 or body.root.Anchored then
		return false
	end
	for _, attribute in ipairs(BUSY_ATTRIBUTES) do
		if body.character:GetAttribute(attribute) ~= nil then
			return false
		end
	end
	if (body.root.Position - point.Position).Magnitude > MAX_TRIGGER_DISTANCE + body.root.Size.Y then
		return false
	end
	if LiftAttemptService.isAttemptActive(player) then
		notify(player, "Finish your lift first.")
		return false
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
		return false
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
	return true
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

local function prompt(parent: BasePart, action: string, object: string, onTriggered: (Player) -> ())
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

	local set = LocalMeetRemotes.createOnServer(ReplicatedStorage)
	remotes = set
	set.choose.OnServerEvent:Connect(function(player, weightKg)
		local current = meet
		local lifter = current and current.byPlayer[player]
		if lifter and typeof(weightKg) == "number" then
			lifter.choice = weightKg
		end
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
		local built, problem = LocalMeetVenue.build()
		if built == nil then
			warn("[LocalMeetService] the venue could not be built: " .. tostring(problem))
			return
		end
		venue = built
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
		while true do
			if now() >= nextStartAt then
				tryStartMeet()
				nextStartAt = startAfter(now())
				broadcastLobby()
			end
			task.wait(0.5)
		end
	end)
end

return LocalMeetService
