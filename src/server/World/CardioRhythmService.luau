--!strict
--[[
	CardioRhythmService
	Server / World

	Runs the treadmill rhythm game (GAME_DESIGN.md §27 "The treadmill rhythm
	game"). The server owns everything that matters: the rounds, the notes
	(from a seed it picks), the clock, every judgement, health and when a
	runner is out. Clients only send "I pressed lane N"
	(CardioRhythmRemotes.RhythmPress). Fun only: nothing here touches player
	data. When a runner is out, their time (measured here) goes to
	CardioRhythmLeaderboard, which keeps the saved all-time and weekly boards.

	A ROUND
	  Idle       nobody is on a treadmill.
	  Countdown  someone hopped on: CountdownSeconds, and everyone on a
	             treadmill when it ends is a runner (all start at the same speed).
	  Running    the music plays; each runner survives until their health runs
	             out (misses only drain), they get off, or they leave the game.
	  Results    when the last runner is out: everyone's time, ResultsSeconds.
	Then Idle again, and a new countdown if someone is on a treadmill. Players
	who hop on during a round just run, and join the next one.

	JUDGING A PRESS
	The press counts at the moment it arrived, moved back by the player's lag
	(half their ping, at most MaxLagAllowanceSeconds). It hits the earliest
	unjudged note in that lane within HitWindowSeconds; with no note near it is
	a stray press (StrayPressCost). A note nobody hit is a miss (MissCost) once
	its window and the lag allowance have passed. Presses beyond
	MaxPressesPerSecond are ignored.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("CardioRhythmConfig"))
local RhythmChart = require(Shared:WaitForChild("World"):WaitForChild("RhythmChart"))
local CardioRhythmRemotes = require(Shared:WaitForChild("World"):WaitForChild("CardioRhythmRemotes"))
local CardioRhythmLeaderboard = require(script.Parent:WaitForChild("CardioRhythmLeaderboard"))

local CardioRhythmService = {}

-- CardioMachineService's mark on a rider's character.
local MACHINE_ATTRIBUTE = "CardioMachine"
local TREADMILL = "Treadmill"
local BROADCAST_SECONDS = 0.25

type Runner = {
	player: Player,
	userId: number,
	name: string,
	health: number,
	out: boolean,
	seconds: number, -- survived so far (final once out)
	hit: { [number]: boolean }, -- note index -> judged (hit or missed)
	missPointer: number, -- the next note to check for a miss
	presses: { number }, -- recent press times, for the rate limit
}

type Round = {
	phase: string,
	seed: number,
	startAt: number,
	endsAt: number,
	notes: { RhythmChart.Note },
	runners: { [Player]: Runner },
}

local remotes: CardioRhythmRemotes.RemoteSet
local round: Round = { phase = "Idle", seed = 0, startAt = 0, endsAt = 0, notes = {}, runners = {} }
local lastBroadcast = 0
local started = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function onTreadmill(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character ~= nil and character:GetAttribute(MACHINE_ATTRIBUTE) == TREADMILL and humanoid ~= nil
		and humanoid.Health > 0
end

local function lagAllowance(player: Player): number
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	return math.clamp(if ok and typeof(ping) == "number" then ping / 2 else 0, 0, Config.MaxLagAllowanceSeconds)
end

local function broadcast()
	local runners: { CardioRhythmRemotes.RunnerView } = {}
	for _, runner in pairs(round.runners) do
		table.insert(runners, { userId = runner.userId, name = runner.name, health = runner.health, out = runner.out,
			seconds = runner.seconds })
	end
	table.sort(runners, function(a, b)
		return a.seconds > b.seconds
	end)
	local state: CardioRhythmRemotes.State = { phase = round.phase, seed = round.seed, startAt = round.startAt,
		endsAt = round.endsAt, runners = runners }
	remotes.state:FireAllClients(state)
	lastBroadcast = os.clock()
end

local function newRunner(player: Player): Runner
	return { player = player, userId = player.UserId, name = player.DisplayName, health = Config.StartHealth,
		out = false, seconds = 0, hit = {}, missPointer = 1, presses = {} }
end

local function knockOut(runner: Runner, at: number)
	if not runner.out then
		runner.out = true
		runner.seconds = math.max(0, at)
		CardioRhythmLeaderboard.submit(runner.userId, runner.player.Name, runner.seconds)
	end
end

local function damage(runner: Runner, amount: number, at: number)
	runner.health = math.max(0, runner.health - amount)
	if runner.health <= 0 then
		knockOut(runner, at)
	end
end

local function setPhase(phase: string)
	round.phase = phase
	broadcast()
end

local function startCountdown()
	round.seed = Random.new():NextInteger(1, 2 ^ 30)
	round.notes = RhythmChart.generate(round.seed).notes
	round.startAt = now() + Config.CountdownSeconds
	round.endsAt = round.startAt
	round.runners = {}
	setPhase("Countdown")
end

-- Every note of `runner` that can no longer be hit counts as a miss.
local function checkMisses(runner: Runner, elapsed: number)
	local late = Config.HitWindowSeconds + lagAllowance(runner.player)
	local notes = round.notes
	while not runner.out and runner.missPointer <= #notes and notes[runner.missPointer].time < elapsed - late do
		local note = notes[runner.missPointer]
		if not runner.hit[note.index] then
			runner.hit[note.index] = true
			remotes.judged:FireAllClients(runner.userId, note.index, "Miss")
			damage(runner, Config.MissCost, note.time + late)
		end
		runner.missPointer += 1
	end
end

local function step()
	local t = now()
	if round.phase == "Idle" then
		for _, player in ipairs(Players:GetPlayers()) do
			if onTreadmill(player) then
				startCountdown()
				break
			end
		end
	elseif round.phase == "Countdown" then
		-- Everyone on a treadmill now is in the round.
		for _, player in ipairs(Players:GetPlayers()) do
			if onTreadmill(player) and round.runners[player] == nil then
				round.runners[player] = newRunner(player)
			elseif not onTreadmill(player) then
				round.runners[player] = nil
			end
		end
		if t >= round.startAt then
			if next(round.runners) == nil then
				setPhase("Idle")
			else
				setPhase("Running")
			end
		end
	elseif round.phase == "Running" then
		local elapsed = t - round.startAt
		local anyIn = false
		for player, runner in pairs(round.runners) do
			if runner.out then
				continue
			end
			if player.Parent ~= Players or not onTreadmill(player) or elapsed >= Config.MaxRoundSeconds then
				knockOut(runner, elapsed)
				continue
			end
			checkMisses(runner, elapsed)
			if not runner.out then
				runner.seconds = elapsed
				anyIn = true
			end
		end
		if not anyIn then
			round.endsAt = t + Config.ResultsSeconds
			setPhase("Results")
		end
	elseif round.phase == "Results" then
		if t >= round.endsAt then
			setPhase("Idle")
		end
	end
	if round.phase ~= "Idle" and os.clock() - lastBroadcast >= BROADCAST_SECONDS then
		broadcast()
	end
end

local function onPress(player: Player, lane: unknown)
	if round.phase ~= "Running" then
		return
	end
	local runner = round.runners[player]
	if runner == nil or runner.out then
		return
	end
	if typeof(lane) ~= "number" or lane ~= lane or lane % 1 ~= 0 or lane < 1 or lane > Config.Lanes then
		return
	end
	-- The rate limit: presses in the last second.
	local clock = os.clock()
	local recent = runner.presses
	while #recent > 0 and clock - recent[1] > 1 do
		table.remove(recent, 1)
	end
	if #recent >= Config.MaxPressesPerSecond then
		return
	end
	table.insert(recent, clock)

	local pressedAt = now() - round.startAt - lagAllowance(player)
	local window = Config.HitWindowSeconds
	local notes = round.notes
	local index = RhythmChart.firstFrom(notes, pressedAt - window)
	while index <= #notes and notes[index].time <= pressedAt + window do
		local note = notes[index]
		if note.lane == lane and not runner.hit[note.index] then
			runner.hit[note.index] = true
			local off = math.abs(note.time - pressedAt)
			remotes.judged:FireAllClients(runner.userId, note.index,
				if off <= Config.PerfectWindowSeconds then "Perfect" else "Good")
			return
		end
		index += 1
	end
	remotes.judged:FireAllClients(runner.userId, 0, "Stray")
	damage(runner, Config.StrayPressCost, pressedAt)
end

function CardioRhythmService.start()
	if started then
		return
	end
	started = true
	remotes = CardioRhythmRemotes.createOnServer(ReplicatedStorage)
	remotes.press.OnServerEvent:Connect(onPress)
	-- A player who arrives mid-round gets the round's state at once.
	Players.PlayerAdded:Connect(function()
		if round.phase ~= "Idle" then
			broadcast()
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return CardioRhythmService
