--!strict
--[[
	MockMeetService
	Server / Meet

	The Mock Meet (GAME_DESIGN.md §29.10 "The Solo meet — first build", user
	2026-10-27): the check-in, the move in and out of the private rooms, and the
	meet itself.

	WHAT IT SAVES (GAME_DESIGN.md 29.11, 33.7 and 33.3b): only into the build of
	the class locked at the weigh-in, and only when the meet ENDS WITH A TOTAL
	(user 2026-10-29: a bomb-out, or leaving before the last attempt, saves
	nothing). Then each lift's best good lift raises its Competition Scale and
	the Total can raise the build's best Total, in one write. Both go through
	the monotone ProfileOperations raises, fed by MeetTotal (good lifts only).
	No records (never the GYM RECORD wall, never a World Record), no money, and
	never Competition Number (33.3).

	CHECK-IN. The check-in point in the gym's Mock Meet Room (tagged
	MockMeetConfig.CheckInTag by RoomProps) gets a "Start Mock Meet" prompt. The
	server checks that the player is alive, on their feet (not on a cardio
	machine or posed at a rack), near the desk, not already in a room, off the
	cooldown, and that a slot is free. Then it builds the player's own room
	(MockMeetArena), streams it in around them, moves them there, sets the
	player attribute MockMeetConfig.SlotAttribute and starts the meet.

	THE MEET (server-run; the client only asks and draws MockMeetRemotes.STATE):
		weigh-in: the weight class (= build) from current bodyweight, locked for the meet
		for each lift in MeetConfig.LiftOrder, 3 attempts:
			Choose   the client asks for a weight (MockMeetRemotes.CHOOSE); the
			         server accepts only a multiple of WeightStepKg inside the
			         Competition Number's percentage bounds that AttemptRules
			         allows; time out -> the default (see MockMeetConfig)
			Ready    the lifter stands on the platform; LIFT (READY) starts the
			         lift; time out -> no lift
			Lifting  LiftAttemptService.startServerAttempt runs the minigames
			Result   the coach reacts, attempt board (no judges in a Mock Meet)
		Done: best lifts and the total (MeetTotal), or bombed out.
	While in a meet the player's own attempt requests (the test keys) are ignored.

	THE COACH'S TEST (GAME_DESIGN §35.12, user 2026-11-06): a locked rare suit is proven in the same room. Three attempts in the
	gear on its own lift, at fixed shares of the Competition Number (no choosing), and every one must be good; the first miss
	ends it. It saves only the test's result: never Scale, Total, Competition Number or coins, and it doesn't use the mock meet's
	cooldown. The try and its wait start on arrival, so leaving counts as not passing.

	LEAVING. Leave (MockMeetRemotes.LEAVE: the server only moves the sender, out
	of the room the server put them in) puts them back where they checked in.
	Dying, respawning or leaving the game also ends it; in every case the room
	is cleared away and a running lift is stopped.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local MockMeetConfig = require(ConfigFolder:WaitForChild("MockMeetConfig"))
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local LiftAttemptConfig = require(ConfigFolder:WaitForChild("LiftAttemptConfig"))
local MeetSoundConfig = require(ConfigFolder:WaitForChild("MeetSoundConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local MockMeetRemotes = require(MeetFolder:WaitForChild("MockMeetRemotes"))
local LocalMeetRemotes = require(MeetFolder:WaitForChild("LocalMeetRemotes"))
local AttemptRules = require(MeetFolder:WaitForChild("AttemptRules"))
local AttemptChoice = require(MeetFolder:WaitForChild("AttemptChoice"))
local MeetTotal = require(MeetFolder:WaitForChild("MeetTotal"))
local GearStats = require(Shared:WaitForChild("Economy"):WaitForChild("GearStats"))
local GearRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("GearRemotes"))

local ServerFolder = script.Parent.Parent
local MockMeetArena = require(script.Parent:WaitForChild("MockMeetArena"))
local PlayerDataFolder = ServerFolder:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))
-- For the two meet-only raises (Scale, best Total); see their security notes.
local ProfileOperations = require(PlayerDataFolder:WaitForChild("ProfileOperations"))
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))
local GearService = require(ServerFolder:WaitForChild("Economy"):WaitForChild("GearService"))
local MeetFigures = require(script.Parent:WaitForChild("MeetFigures"))

local MockMeetService = {}

-- Marks other systems put on a character: a cardio rider or a lifter posed at a rack cannot check in.
local BUSY_ATTRIBUTES = { "CardioMachine", "StationPose" }
-- The farthest a player may stand from the check-in point when the prompt fires (its reach plus slack).
local MAX_TRIGGER_DISTANCE = MockMeetConfig.PromptDistanceStuds + 4
local STREAM_TIMEOUT_SECONDS = 5
local POLL_SECONDS = 0.1
-- Longest wait for a lift's verdict (its own safety bound plus slack).
local LIFT_TIMEOUT_SECONDS = LiftAttemptConfig.MaxAttemptSeconds + 5
local PASSED = "Passed"

type Body = { character: Model, root: BasePart, humanoid: Humanoid }

-- A running coach's test: which suit, on which piece. `running` once the save has it on loan; `over` once the result is in.
type SuitTest = { suit: GearStatsConfig.Suit, pieceId: string, running: boolean, over: boolean }

-- One lift's attempts as the meet keeps them: AttemptRules' history, plus passed attempts.
type LiftRecord = { history: AttemptRules.AttemptHistory, passed: number }

type Visit = {
	room: MockMeetArena.Room,
	character: Model,
	-- Where the player stood when they checked in; Leave puts them back there.
	returnTo: CFrame,
	connections: { RBXScriptConnection },
	-- Locked at the weigh-in for the whole meet. classLabel is also the build every save goes to.
	bodyweightKg: number,
	classLabel: string,
	competitionNumber: { [string]: number },
	lifts: { [string]: LiftRecord },
	-- What the client last asked for (cleared when read).
	choice: number?,
	readyPressed: boolean,
	-- Set when this visit is the coach's test instead of a mock meet.
	suitTest: SuitTest?,
}

-- Who is in which room. Entries are removed on every way out, so no room is left behind.
local visits: { [Player]: Visit } = {}
local slotOwner: { [number]: Player? } = {}
-- Players between the prompt and arriving (the room streams in first), so a double trigger does nothing.
local entering: { [Player]: boolean } = {}
local lastLeave: { [Player]: number } = {}
-- When each player last checked in (by UserId, so leaving and rejoining this server keeps it).
local lastCheckIn: { [number]: number } = {}
local remotes: MockMeetRemotes.RemoteSet? = nil
local started = false

local function log(message: string, ...: any)
	print("[MockMeetService] " .. string.format(message, ...))
end

local function notify(player: Player, message: string)
	if remotes and player.Parent then
		remotes.notice:FireClient(player, message)
	end
end

local function suitWaitSeconds(): number
	return if RunService:IsStudio() then GearStatsConfig.SuitTest.StudioWaitSeconds else GearStatsConfig.SuitTest.WaitSeconds
end

local function cooldownSeconds(): number
	return if RunService:IsStudio() then MockMeetConfig.StudioCooldownSeconds else MockMeetConfig.CooldownSeconds
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

local function freeSlot(): number?
	for slot = 1, MockMeetConfig.MaxSlots do
		if slotOwner[slot] == nil then
			return slot
		end
	end
	return nil
end

-- True while `visit` is still the player's current visit (they have not left, died or rejoined).
local function stillIn(player: Player, visit: Visit): boolean
	return visits[player] == visit and player.Parent ~= nil
end

-- ---------------------------------------------------------------- weights (AttemptChoice, shared with the Local meet)

-- The range of weights the lifter may declare on this lift: the Competition Number's percentage bounds.
local function bounds(visit: Visit, lift: string): (number, number)
	return AttemptChoice.meetBounds(visit.competitionNumber[lift], MockMeetConfig.WeightStepKg)
end

-- The lightest legal next weight and the default, or nil when the attempt is passed.
local function nextWeights(visit: Visit, lift: string): (number?, number?)
	return AttemptChoice.nextWeights(visit.competitionNumber[lift], visit.lifts[lift].history, MockMeetConfig.WeightStepKg,
		MockMeetConfig.OpenerSuggestionPercent, true)
end

-- Checks a weight the client asked for. Returns the weight, or nil and a reason to show.
local function checkChoice(visit: Visit, lift: string, requested: unknown): (number?, string?)
	return AttemptChoice.check(visit.competitionNumber[lift], visit.lifts[lift].history, MockMeetConfig.WeightStepKg,
		requested, true)
end

-- ---------------------------------------------------------------- what the client and the board see

local function attemptViews(visit: Visit): { [string]: { MockMeetRemotes.AttemptView } }
	local views: { [string]: { MockMeetRemotes.AttemptView } } = {}
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local record = visit.lifts[lift]
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

local function meetAttempts(visit: Visit): MeetTotal.MeetAttempts
	local all: MeetTotal.MeetAttempts = {}
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		all[lift] = visit.lifts[lift].history
	end
	return all
end

local function sendState(player: Player, visit: Visit, phase: string, extra: { [string]: any }?)
	if remotes == nil or not stillIn(player, visit) then
		return
	end
	local state: { [string]: any } = {
		phase = phase,
		bodyweightKg = visit.bodyweightKg,
		classLabel = visit.classLabel,
		competitionNumber = visit.competitionNumber,
		attempts = attemptViews(visit),
	}
	if extra then
		for key, value in pairs(extra) do
			state[key] = value
		end
	end
	remotes.state:FireClient(player, state)
end

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

-- The attempt board: who, which lift and attempt, the weight, and the best lifts so far.
local function updateBoard(player: Player, visit: Visit, lift: string?, attemptNumber: number?, weightKg: number?,
	verdict: string?)
	local best = MeetTotal.resolve(meetAttempts(visit)).best
	local bests = {}
	for _, name in ipairs(MeetConfig.LiftOrder) do
		table.insert(bests, string.format("%s %s", string.sub(name, 1, 1), if best[name] then kgText(best[name]) else "—"))
	end
	MockMeetArena.setBoard(visit.room, {
		string.format("%s  ·  %s class", player.DisplayName, visit.classLabel),
		if lift then string.format("%s  ·  ATTEMPT %d", string.upper(lift), attemptNumber or 1) else "MEET OVER",
		if weightKg then kgText(weightKg) .. " KG" .. (if verdict == "GoodLift" then "  ·  GOOD LIFT"
			elseif verdict then "  ·  NO LIFT" else "") else "—",
		"BEST   " .. table.concat(bests, "   "),
	})
end

-- ---------------------------------------------------------------- the lifter on the platform

local function standAt(player: Player, visit: Visit, spot: CFrame, anchored: boolean)
	local body = bodyOf(player)
	if body == nil or body.character ~= visit.character or body.humanoid.Health <= 0 then
		return
	end
	body.root.Anchored = anchored
	body.character:PivotTo(spot * CFrame.new(0, standingHeight(body), 0))
end

local function releaseLifter(player: Player, visit: Visit)
	local body = bodyOf(player)
	if body and body.character == visit.character then
		body.root.Anchored = false
	end
end

-- ---------------------------------------------------------------- what the meet saves

-- True once every attempt of every lift was taken or passed, so the meet is over.
local function allAttemptsTaken(visit: Visit): boolean
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local record = visit.lifts[lift]
		if #record.history + record.passed < MeetConfig.AttemptsPerLift then
			return false
		end
	end
	return true
end

--[[
	At the end of a meet WITH A TOTAL (33.3b): raises each lift's Competition
	Scale in the build of the weigh-in class to that lift's best good lift, and
	the build's best Total, in one write. MeetTotal only ever counts GoodLift
	weights, so a miss can never reach a raise. A bomb-out has no total and
	saves nothing.
]]
local function saveMeetResult(player: Player, visit: Visit, result: MeetTotal.MeetResult)
	local totalKg = result.total
	if totalKg == nil then
		log("%s bombed out: nothing saved", player.Name)
		return
	end
	local scaleOutcomes: { [string]: ProfileOperations.ScaleRaiseOutcome } = {}
	local scaleKgs: { [string]: number? } = {}
	local totalOutcome: ProfileOperations.ScaleRaiseOutcome = "Rejected"
	PlayerDataService.update(player, function(data)
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			-- A lift over the normal limit counts for the total, not for Scale (GAME_DESIGN §37.5).
			local provenKg = AttemptChoice.bestWithinLimit(visit.competitionNumber[lift], visit.lifts[lift].history)
			if provenKg then
				scaleOutcomes[lift], scaleKgs[lift] =
					ProfileOperations.raiseCompetitionScale(data, visit.classLabel, lift, provenKg)
			else
				scaleOutcomes[lift] = "Unchanged"
			end
		end
		totalOutcome = ProfileOperations.raiseBestTotal(data, visit.classLabel, totalKg)
	end)
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local outcome = scaleOutcomes[lift] or "Rejected"
		local scaleKg = scaleKgs[lift]
		if outcome == "Raised" and scaleKg then
			notify(player, string.format("New %s Competition Scale: %s kg (%s class)", lift, kgText(scaleKg), visit.classLabel))
		elseif outcome == "Rejected" then
			warn(string.format("[MockMeetService] %s's %s Scale (%s kg, %s) was not saved", player.Name, lift,
				kgText(result.best[lift]), visit.classLabel))
		end
		log("%s %s Scale (%s): %s", player.Name, lift, visit.classLabel, outcome)
	end
	if totalOutcome == "Raised" then
		notify(player, string.format("New best Total: %s kg (%s class)", kgText(totalKg), visit.classLabel))
	elseif totalOutcome == "Rejected" then
		warn(string.format("[MockMeetService] %s's total (%s kg, %s) was not saved", player.Name, kgText(totalKg),
			visit.classLabel))
	end
	log("%s best Total (%s): %s", player.Name, visit.classLabel, totalOutcome)
end

-- ---------------------------------------------------------------- the meet

-- What the watching coach says (flavour only; the minigames decide every verdict).
local COACH_READY = { "You got this.", "Breathe. Brace. Go.", "Same as training." }
local COACH_GOOD = { "Smoked it!", "That's the one!", "Easy work!" }
local COACH_MISS = { "Shake it off.", "Reset. Next one.", "You had that. Again." }
local function pick(lines: { string }): string
	return lines[math.random(1, #lines)]
end

-- Waits until `done()` is true, the time runs out, or the visit ends. Returns whether `done()` became true.
local function waitFor(player: Player, visit: Visit, seconds: number, done: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while stillIn(player, visit) and os.clock() < deadline do
		if done() then
			return true
		end
		task.wait(POLL_SECONDS)
	end
	return stillIn(player, visit) and done()
end

-- One attempt: choose, ready, lift, result. Returns false when the visit ended. With `fixedKg` (the coach's test) there is no choosing.
local function runAttempt(player: Player, visit: Visit, lift: string, attemptNumber: number, fixedKg: number?): boolean
	local record = visit.lifts[lift]
	local weightKg: number
	if fixedKg then
		weightKg = fixedKg
	else
		local minKg, default = nextWeights(visit, lift)
		if minKg == nil or default == nil then
			-- No heavier weight is allowed inside the bounds: the attempt is passed.
			record.passed += 1
			notify(player, string.format("%s attempt %d passed: no heavier weight is allowed.", lift, attemptNumber))
			return stillIn(player, visit)
		end
		local _, maxKg = bounds(visit, lift)

		-- Choose.
		visit.choice = nil
		local chosen: number? = nil
		updateBoard(player, visit, lift, attemptNumber, nil)
		sendState(player, visit, "Choose", { lift = lift, attemptNumber = attemptNumber, minKg = minKg, maxKg = maxKg,
			suggestedKg = default, secondsLeft = MockMeetConfig.ChooseSeconds })
		waitFor(player, visit, MockMeetConfig.ChooseSeconds, function()
			local requested = visit.choice
			if requested == nil then
				return false
			end
			visit.choice = nil
			local kg, problem = checkChoice(visit, lift, requested)
			if kg == nil then
				notify(player, problem or "That weight is not allowed.")
				return false
			end
			chosen = kg
			return true
		end)
		if not stillIn(player, visit) then
			return false
		end
		weightKg = chosen or default
	end

	-- Ready: on the platform, LIFT to start.
	visit.readyPressed = false
	standAt(player, visit, visit.room.liftSpot, true)
	MockMeetArena.coachSays(visit.room, pick(COACH_READY))
	updateBoard(player, visit, lift, attemptNumber, weightKg)
	sendState(player, visit, "Ready", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg,
		secondsLeft = MockMeetConfig.ReadySeconds })
	local ready = waitFor(player, visit, MockMeetConfig.ReadySeconds, function()
		return visit.readyPressed and not LiftAttemptService.isAttemptActive(player)
	end)
	if not stillIn(player, visit) then
		return false
	end

	-- Lift.
	local verdict: string? = nil
	if ready then
		local ok, problem = LiftAttemptService.startServerAttempt(player, lift, weightKg, function(result)
			verdict = result
		end)
		if ok then
			sendState(player, visit, "Lifting", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg })
			waitFor(player, visit, LIFT_TIMEOUT_SECONDS, function()
				return verdict ~= nil
			end)
			if not stillIn(player, visit) then
				return false
			end
		else
			warn(string.format("[MockMeetService] %s's %s attempt could not start: %s", player.Name, lift, tostring(problem)))
		end
	else
		notify(player, "Time ran out: no lift.")
	end
	local result: AttemptRules.AttemptResult = if verdict == "GoodLift" then "GoodLift" else "NoLift"

	-- The bar's sound (a lift that ran only: not when time ran out). Sound only.
	local character = player.Character
	if verdict ~= nil and character then
		LocalMeetRemotes.createOnServer(ReplicatedStorage).sound:FireAllClients(
			MeetSoundConfig.endOfLiftCue(lift, result == "GoodLift", 1, weightKg), character:GetPivot().Position)
	end

	-- Result.
	table.insert(record.history, { weightKg = weightKg, result = result })
	MockMeetArena.coachSays(visit.room, pick(if result == "GoodLift" then COACH_GOOD else COACH_MISS))
	updateBoard(player, visit, lift, attemptNumber, weightKg, result)
	sendState(player, visit, "Result", { lift = lift, attemptNumber = attemptNumber, declaredKg = weightKg,
		verdict = result })
	log("%s %s attempt %d: %s kg %s", player.Name, lift, attemptNumber, kgText(weightKg), result)
	task.wait(MockMeetConfig.ResultSeconds)
	if not stillIn(player, visit) then
		return false
	end
	MockMeetArena.coachSays(visit.room, nil)
	releaseLifter(player, visit)
	return true
end

local function runMeet(player: Player, visit: Visit)
	updateBoard(player, visit, nil, nil, nil)
	sendState(player, visit, "WeighIn", { secondsLeft = MockMeetConfig.WeighInSeconds })
	task.wait(MockMeetConfig.WeighInSeconds)
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		for attemptNumber = 1, MeetConfig.AttemptsPerLift do
			if not stillIn(player, visit) or not runAttempt(player, visit, lift, attemptNumber) then
				-- Gone before the end: nothing is saved, unless it was during the last verdict.
				if allAttemptsTaken(visit) and player.Parent then
					saveMeetResult(player, visit, MeetTotal.resolve(meetAttempts(visit)))
				else
					log("%s left before the meet ended: nothing saved", player.Name)
				end
				return
			end
		end
	end
	local result = MeetTotal.resolve(meetAttempts(visit))
	saveMeetResult(player, visit, result)
	MockMeetArena.coachSays(visit.room, if result.total then "Great meet. Proud of you." else "We'll get them next time.")
	updateBoard(player, visit, nil, nil, result.total)
	sendState(player, visit, "Done", { best = result.best, total = result.total, bombedOut = result.bombedOut })
	log("%s finished a mock meet: total %s", player.Name, if result.total then kgText(result.total) else "bombed out")
end

-- The coach's test: three attempts on the suit's own lift at fixed weights. The first miss ends it. Saves only its result.
local function runSuitTest(player: Player, visit: Visit, test: SuitTest)
	local lift = test.suit.onlyLift :: string
	local weights = GearStats.suitTestWeights(visit.competitionNumber[lift], MockMeetConfig.WeightStepKg)
	updateBoard(player, visit, nil, nil, nil)
	MockMeetArena.coachSays(visit.room, "Three lifts in that gear. Show me you can handle it.")
	local shown: { string } = {}
	for _, kg in ipairs(weights) do
		table.insert(shown, kgText(kg))
	end
	sendState(player, visit, "WeighIn", { secondsLeft = MockMeetConfig.WeighInSeconds, stepTag = test.suit.name .. " TEST",
		banner = table.concat(shown, "  ·  ") .. " KG", note = "All three must be good lifts. The coach is watching." })
	task.wait(MockMeetConfig.WeighInSeconds)
	local passed = true
	for attemptNumber, kg in ipairs(weights) do
		if not stillIn(player, visit) or not runAttempt(player, visit, lift, attemptNumber, kg) then
			-- Gone before the end: `finish` takes the gear back, and the wait stands.
			log("%s left the %s test", player.Name, test.suit.id)
			return
		end
		local history = visit.lifts[lift].history
		if history[#history].result ~= "GoodLift" then
			passed = false
			break
		end
	end
	test.over = true
	PlayerDataService.endSuitTrial(player, passed)
	GearService.redress(player)
	if passed then
		GearService.celebrateTest(player)
	end
	MockMeetArena.coachSays(visit.room, if passed then "You can handle it. It's yours." else "Not yet. Come back tomorrow.")
	updateBoard(player, visit, nil, nil, nil)
	sendState(player, visit, "Done", { best = MeetTotal.resolve(meetAttempts(visit)).best, bombedOut = not passed,
		stepTag = test.suit.name .. " TEST", banner = if passed then "PASSED" else "NOT YET",
		note = if passed then "You can handle it. The " .. test.suit.name .. " is yours, and you're wearing it."
			else "You keep the " .. test.suit.name .. ". Try again in " .. GearStats.waitText(suitWaitSeconds()) .. "." })
	log("%s %s the %s test", player.Name, if passed then "passed" else "did not pass", test.suit.id)
end

-- ---------------------------------------------------------------- in and out

--[[
	Ends a visit: stops a running lift, clears the room, and moves the player
	back to where they checked in when `sendBack` is true and they still have
	the same, living character.
]]
local function finish(player: Player, sendBack: boolean)
	local visit = visits[player]
	if visit == nil then
		return
	end
	visits[player] = nil
	for _, connection in ipairs(visit.connections) do
		connection:Disconnect()
	end
	if slotOwner[visit.room.slot] == player then
		slotOwner[visit.room.slot] = nil
	end
	LiftAttemptService.abandon(player)
	LiftAttemptService.setFreeAttemptsBlocked(player, false)
	if player.Parent then
		player:SetAttribute(MockMeetConfig.SlotAttribute, nil)
	end
	-- Left the coach's test before its result: the gear on loan comes off. (If they left the game the next load does this.)
	local test = visit.suitTest
	if test and test.running and not test.over and player.Parent then
		test.over = true
		PlayerDataService.endSuitTrial(player, false)
		GearService.redress(player)
	end

	local body = bodyOf(player)
	if body and body.character == visit.character then
		body.root.Anchored = false
	end
	if sendBack and body and body.character == visit.character and body.humanoid.Health > 0 then
		local position = visit.returnTo.Position
		pcall(function()
			player:RequestStreamAroundAsync(position, STREAM_TIMEOUT_SECONDS)
		end)
		-- The player may have left or died while the gym streamed back in.
		if player.Parent and body.character.Parent and body.humanoid.Health > 0 then
			body.character:PivotTo(visit.returnTo)
		end
	end
	MockMeetArena.clear(visit.room)
	log("%s left mock meet room %d", player.Name, visit.room.slot)
end

-- Builds the player's room and moves them in, for a mock meet or, with `suitTest`, the coach's test. Returns whether they went.
local function enterRoom(player: Player, body: Body, suitTest: SuitTest?): boolean
	-- The weigh-in reads the player's data; nothing is written. The class it locks is the build the meet saves to.
	local data = PlayerDataService.getData(player)
	if data == nil then
		notify(player, "Your data is still loading. Try again in a moment.")
		return false
	end
	local classKey = ProfileOperations.getActiveClassKey(data)
	if classKey == nil or ProfileOperations.getBuild(data, classKey) == nil then
		warn(string.format("[MockMeetService] %s has no build for their weight class", player.Name))
		return false
	end
	local competitionNumber: { [string]: number } = {}
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local cn = ProfileOperations.getCompetitionNumber(data, lift)
		if cn == nil or cn <= 0 then
			return false
		end
		competitionNumber[lift] = cn
	end
	local bodyweightKg = data.bodyweight.currentKg

	local slot = freeSlot()
	if slot == nil then
		notify(player, "Every Mock Meet room is in use. Try again in a moment.")
		return false
	end
	local room, problem = MockMeetArena.build(slot, player)
	if room == nil then
		warn(string.format("[MockMeetService] could not build a room for %s: %s", player.Name, tostring(problem)))
		return false
	end
	slotOwner[slot] = player
	entering[player] = true
	local returnTo = body.root.CFrame

	local arrival = room.arrival * CFrame.new(0, standingHeight(body), 0)
	pcall(function()
		player:RequestStreamAroundAsync(arrival.Position, STREAM_TIMEOUT_SECONDS)
	end)
	entering[player] = nil

	-- Anything could have happened while the room streamed in: check again before moving them.
	local now = bodyOf(player)
	if player.Parent == nil or now == nil or now.character ~= body.character or now.humanoid.Health <= 0 then
		slotOwner[slot] = nil
		MockMeetArena.clear(room)
		return false
	end

	local lifts: { [string]: LiftRecord } = {}
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		lifts[lift] = { history = {}, passed = 0 }
	end
	local visit: Visit = {
		room = room,
		character = body.character,
		returnTo = returnTo,
		connections = {},
		bodyweightKg = bodyweightKg,
		classLabel = classKey,
		competitionNumber = competitionNumber,
		lifts = lifts,
		choice = nil,
		readyPressed = false,
		suitTest = suitTest,
	}
	visits[player] = visit
	if suitTest == nil then
		lastCheckIn[player.UserId] = os.clock()
	else
		-- Only now it can't fail for the room's sake: the try starts here, and with it the wait.
		local outcome = PlayerDataService.startSuitTrial(player, suitTest.suit.id, suitTest.pieceId, suitWaitSeconds())
		if outcome ~= "Started" then
			finish(player, false)
			return false
		end
		suitTest.running = true
		GearService.redress(player)
	end
	LiftAttemptService.setFreeAttemptsBlocked(player, true)
	body.character:PivotTo(arrival)
	player:SetAttribute(MockMeetConfig.SlotAttribute, slot)
	table.insert(visit.connections, body.humanoid.Died:Connect(function()
		finish(player, false)
	end))
	table.insert(visit.connections, body.character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			finish(player, false)
		end
	end))
	table.insert(visit.connections, room.model.Destroying:Connect(function()
		finish(player, false)
	end))
	log("%s entered mock meet room %d (%.1f kg, %s class)", player.Name, slot, bodyweightKg, visit.classLabel)
	if suitTest then
		task.spawn(runSuitTest, player, visit, suitTest)
	else
		task.spawn(runMeet, player, visit)
	end
	return true
end

--[[
	Moves `player` into their own new room and starts their meet if everything
	allows it. Called by the check-in prompt (also usable from a Studio test).
	Returns whether they went.
]]
function MockMeetService.checkIn(player: Player, point: BasePart): boolean
	if visits[player] or entering[player] then
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
	local last = lastCheckIn[player.UserId]
	local remaining = math.ceil(if last then cooldownSeconds() - (os.clock() - last) else 0)
	if remaining > 0 then
		notify(player, string.format("Your next Mock Meet is ready in %d:%02d.", remaining // 60, remaining % 60))
		return false
	end

	return enterRoom(player, body, nil)
end

--[[
	Starts the coach's test for a locked rare suit (GAME_DESIGN §35.12): from the cutscene or MY GEAR, anywhere the player is free
	to go. It checks everything itself; the client only names the piece. Returns whether they went, and what to tell them.
]]
function MockMeetService.startSuitTest(player: Player, pieceId: string): (boolean, string)
	if visits[player] or entering[player] then
		return false, "You're in a mock meet room already."
	end
	if player:GetAttribute(LocalMeetConfig.PlatformAttribute) ~= nil then
		return false, "Finish your meet first."
	end
	local body = bodyOf(player)
	if body == nil or body.humanoid.Health <= 0 or body.root.Anchored then
		return false, "You can't go right now."
	end
	for _, attribute in ipairs(BUSY_ATTRIBUTES) do
		if body.character:GetAttribute(attribute) ~= nil then
			return false, "Step off first."
		end
	end
	if LiftAttemptService.isAttemptActive(player) then
		return false, "Finish your lift first."
	end
	local piece = (PlayerDataService.getPieces(player) or {})[pieceId]
	local suit = if piece then GearStats.suit(piece.rarity) else nil
	if suit == nil then
		return false, "You don't have that."
	end
	local test = (PlayerDataService.getSuitTests(player) or {})[suit.id]
	if test and test.passed then
		return false, "You've passed this one."
	end
	local left = if test and test.nextTryAt then test.nextTryAt - os.time() else 0
	if left > 0 then
		return false, "The coach will see you again in " .. GearStats.waitText(left) .. "."
	end
	if enterRoom(player, body, { suit = suit, pieceId = pieceId, running = false, over = false }) then
		return true, "Show the coach you can handle it."
	end
	return false, "That didn't go through. Try again."
end

-- The "Start Mock Meet" prompt on a check-in point.
local function setUpCheckIn(instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local point = instance
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Start Mock Meet"
	prompt.ObjectText = "Check-in"
	prompt.HoldDuration = MockMeetConfig.PromptHoldSeconds
	prompt.MaxActivationDistance = MockMeetConfig.PromptDistanceStuds
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function(player)
		MockMeetService.checkIn(player, point)
	end)
end

function MockMeetService.start()
	if started then
		return
	end
	started = true

	local set = MockMeetRemotes.createOnServer(ReplicatedStorage)
	remotes = set
	set.leave.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastLeave[player] or 0) < MockMeetConfig.LeaveCooldownSeconds then
			return
		end
		lastLeave[player] = now
		finish(player, true)
	end)
	-- Only remembered; the meet reads and checks it while it waits for a choice.
	set.choose.OnServerEvent:Connect(function(player, weightKg)
		local visit = visits[player]
		if visit and typeof(weightKg) == "number" then
			visit.choice = weightKg
		end
	end)
	set.ready.OnServerEvent:Connect(function(player)
		local visit = visits[player]
		if visit then
			visit.readyPressed = true
		end
	end)

	for _, point in ipairs(CollectionService:GetTagged(MockMeetConfig.CheckInTag)) do
		setUpCheckIn(point)
	end
	CollectionService:GetInstanceAddedSignal(MockMeetConfig.CheckInTag):Connect(setUpCheckIn)

	-- The way in to the coach's test, and the coach's figure for the cutscene to copy on the winner's screen.
	GearService.setTestStarter(MockMeetService.startSuitTest)
	task.spawn(function()
		local folder = Instance.new("Folder")
		folder.Name = GearRemotes.COACH_FIGURE
		MeetFigures.build(folder, "Coach", Vector3.zero, Vector3.new(0, 0, -5))
		folder.Parent = ReplicatedStorage
	end)

	Players.PlayerRemoving:Connect(function(player)
		finish(player, false)
		entering[player] = nil
		lastLeave[player] = nil
	end)
end

return MockMeetService
