--!strict
--[[
	LocalMeetWarmUp
	Server / Meet

	The warm-up room's working racks (GAME_DESIGN.md §29.10 "Venue redesign and
	awards ceremony", build step 3; user 2026-10-29: "make them work like a
	normal meet"; at Nationals and Worlds lifters wait longer and practise over
	and over). LocalMeetService creates it once the venue is built.

		hold E at a free rack   the player steps up to it (anchored, facing the
		                        hall, like on a platform) and gets the WARM-UP
		                        card (LocalMeetRemotes.WarmUpState)
		LIFT (lift, weight)     the server checks the lift, the weight
		                        (AttemptChoice: the meet's step and its 40-125%
		                        of CN) and that nothing else is running, then
		                        starts a MEET attempt (the same minigames and
		                        difficulty as a meet, Scale challenge included),
		                        with the same lift and fail animations and bar
		                        sounds as a meet (user 2026-11-04)
		LEAVE                   the player steps off the rack

	PRACTICE ONLY: a verdict is shown and nothing is written (no CN, no Scale,
	no records, no allowance). The client only asks; one player per rack.
	A player who starts lifting in a meet, leaves the venue or dies is taken
	off their rack (stop).

	The gym's racks use this too (GymPractice): an instance with no racks of its
	own, stepUp called when the player picks Practice Lifts. Both instances listen
	to the same remotes, and each answers only the players it has on a rack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local MeetSoundConfig = require(ConfigFolder:WaitForChild("MeetSoundConfig"))
local StationAnimationConfig = require(ConfigFolder:WaitForChild("StationAnimationConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local LocalMeetRemotes = require(MeetFolder:WaitForChild("LocalMeetRemotes"))
local AttemptChoice = require(MeetFolder:WaitForChild("AttemptChoice"))

local ServerFolder = script.Parent.Parent
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))
local PlayerDataService = require(ServerFolder:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))
local MeetLiftAnimation = require(script.Parent:WaitForChild("MeetLiftAnimation"))
local StationVisuals = require(ServerFolder:WaitForChild("Training"):WaitForChild("StationVisuals"))

local LocalMeetWarmUp = {}

-- After the setup, a beat before the minigame starts (a warm-up has no referee's command).
local START_BEAT_SECONDS = 0.6
-- After a good lift's finish, how long the lifter stays before the bar goes back, as on a platform.
local LEAVE_AFTER_FINISH_SECONDS = 0.8
-- At most one live minigame update this often per player is used.
local PROGRESS_MIN_GAP_SECONDS = 0.05

-- What LocalMeetService lends the warm-up (it owns the venue visits, the characters and the prompts' look).
export type Hooks = {
	-- Whether the player may step up to a warm-up rack now, or the reason they may not.
	canUse: (player: Player) -> (boolean, string?),
	standAt: (player: Player, spot: CFrame, anchored: boolean) -> (),
	release: (player: Player) -> (),
	notify: (player: Player, message: string) -> (),
	-- Only for racks with a prompt of their own (the racks passed to new).
	prompt: ((parent: BasePart, action: string, object: string, onTriggered: (Player) -> ()) -> ProximityPrompt)?,
	pressAllowed: (player: Player) -> boolean,
	-- Told when a player has come off a rack, whatever the reason.
	onLeft: ((player: Player) -> ())?,
	-- The card's title; the client's own (WARM-UP) when nil.
	cardTitle: string?,
}

export type WarmUp = {
	-- Puts the player on `rack`, if they may use it. The prompts call this.
	stepUp: (player: Player, rack: LocalMeetVenue.WarmUpRack) -> (),
	-- Takes the player off their rack (if they are at one) and stops their lift; steps them off the rack when
	-- `stepOff` (otherwise the caller moves them).
	stop: (player: Player, stepOff: boolean) -> (),
	isWarmingUp: (player: Player) -> boolean,
	-- The player's running minigame is `fraction` of the way through (MeetLiftProgress): their lift follows it.
	progress: (player: Player, fraction: number) -> (),
}

type Use = {
	rack: LocalMeetVenue.WarmUpRack,
	lifting: boolean,
	last: { lift: string, weightKg: number, good: boolean }?,
	anim: MeetLiftAnimation.Handle?,
	-- The minigame phase running now, and when its last progress update came.
	livePhase: number?,
	progressAt: number?,
}

local function log(message: string, ...: any)
	print("[LocalMeetWarmUp] " .. string.format(message, ...))
end

function LocalMeetWarmUp.new(racks: { LocalMeetVenue.WarmUpRack }, remotes: LocalMeetRemotes.RemoteSet,
	hooks: Hooks): WarmUp
	local uses: { [Player]: Use } = {}
	local takenBy: { [number]: Player } = {}
	local prompts: { [number]: ProximityPrompt } = {}

	local function competitionNumbers(player: Player): { [string]: number }
		local numbers: { [string]: number } = {}
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			local cn = PlayerDataService.getCompetitionNumber(player, lift)
			if typeof(cn) == "number" and cn > 0 then
				numbers[lift] = cn
			end
		end
		return numbers
	end

	local function sendState(player: Player)
		if player.Parent == nil then
			return
		end
		local use = uses[player]
		local state: LocalMeetRemotes.WarmUpState = {
			rack = use and use.rack.index,
			competitionNumbers = if use then competitionNumbers(player) else {},
			stepKg = LocalMeetConfig.WeightStepKg,
			startPercent = LocalMeetConfig.WarmUp.StartPercent,
			lifting = use ~= nil and use.lifting,
			last = use and use.last,
			title = hooks.cardTitle,
		}
		remotes.warmUpState:FireClient(player, state)
	end

	local warmUp = {} :: WarmUp

	function warmUp.isWarmingUp(player: Player): boolean
		return uses[player] ~= nil
	end

	function warmUp.progress(player: Player, fraction: number)
		local use = uses[player]
		if use == nil or use.livePhase == nil then
			return
		end
		local now = os.clock()
		if now - (use.progressAt or 0) >= PROGRESS_MIN_GAP_SECONDS then
			use.progressAt = now
			MeetLiftAnimation.progress(use.anim, use.livePhase, fraction)
		end
	end

	function warmUp.stop(player: Player, stepOff: boolean)
		local use = uses[player]
		if use == nil then
			return
		end
		uses[player] = nil
		takenBy[use.rack.index] = nil
		local prompt = prompts[use.rack.index]
		if prompt then
			prompt.Enabled = true
		end
		if use.lifting then
			LiftAttemptService.abandon(player)
		end
		MeetLiftAnimation.stop(use.anim)
		use.anim = nil
		if use.rack.rack then
			StationVisuals.show(use.rack.rack, nil)
		end
		hooks.release(player)
		if stepOff then
			-- A couple of steps forward, off the rack, free to walk.
			hooks.standAt(player, use.rack.stepOffSpot or (use.rack.liftSpot * CFrame.new(0, 0, -3)), false)
		end
		sendState(player)
		log("%s left warm-up rack %d", player.Name, use.rack.index)
		if hooks.onLeft then
			hooks.onLeft(player)
		end
	end

	function warmUp.stepUp(player: Player, rack: LocalMeetVenue.WarmUpRack)
		if uses[player] or not hooks.pressAllowed(player) then
			return
		end
		if takenBy[rack.index] then
			hooks.notify(player, "Someone is already warming up on this rack.")
			return
		end
		local ok, problem = hooks.canUse(player)
		if not ok then
			hooks.notify(player, problem or "You cannot warm up right now.")
			return
		end
		uses[player] = { rack = rack, lifting = false, last = nil }
		takenBy[rack.index] = player
		local prompt = prompts[rack.index]
		if prompt then
			prompt.Enabled = false
		end
		hooks.standAt(player, rack.liftSpot, true)
		sendState(player)
		log("%s stepped up to warm-up rack %d", player.Name, rack.index)
	end

	local makePrompt = hooks.prompt
	if makePrompt then
		for _, rack in ipairs(racks) do
			prompts[rack.index] = makePrompt(rack.point, LocalMeetConfig.WarmUp.PromptAction,
				LocalMeetConfig.WarmUp.PromptObject, function(player)
					warmUp.stepUp(player, rack)
				end)
		end
	end

	remotes.warmUpLift.OnServerEvent:Connect(function(player: Player, liftName: unknown, weightKg: unknown)
		local use = uses[player]
		if use == nil or use.lifting or LiftAttemptService.isAttemptActive(player) then
			return
		end
		if typeof(liftName) ~= "string" or not table.find(MeetConfig.LiftOrder, liftName) then
			return
		end
		local lift = liftName :: string
		local cn = PlayerDataService.getCompetitionNumber(player, lift)
		if typeof(cn) ~= "number" or cn <= 0 then
			hooks.notify(player, "You have no Competition Number for that lift yet.")
			return
		end
		-- The same weights a meet attempt allows; a warm-up has no attempt history, so any of them.
		local kg, problem = AttemptChoice.check(cn, {}, LocalMeetConfig.WeightStepKg, weightKg)
		if kg == nil then
			hooks.notify(player, problem or "That weight is not allowed.")
			return
		end
		use.lifting = true
		sendState(player)
		local rack = use.rack.rack
		local character = player.Character
		if rack and character then
			StationVisuals.show(rack, lift)
			use.anim = MeetLiftAnimation.begin(character, rack, lift)
		end
		-- Only while the player is still on this rack (stop() ends a use; a new use is a new table).
		local function stillHere(): boolean
			return uses[player] == use
		end
		-- The bar's sound, for everyone in earshot. Sound only.
		local function barSound(cue: string)
			if stillHere() and rack then
				remotes.sound:FireAllClients(cue, rack:GetPivot().Position)
			end
		end
		-- Off the bar and back at the rack's spot, ready for the next lift.
		local function backAtSpot()
			if stillHere() then
				MeetLiftAnimation.stop(use.anim)
				use.anim = nil
				hooks.standAt(player, use.rack.liftSpot, true)
				use.lifting = false
				sendState(player)
			end
		end
		local function onVerdict(failedPart: number, verdict: string)
			if not stillHere() then
				return
			end
			local good = verdict == "GoodLift"
			use.livePhase = nil
			use.last = { lift = lift, weightKg = kg, good = good }
			local fail = if good then nil else StationAnimationConfig.failFor(lift, failedPart)
			local seconds = MeetLiftAnimation.finish(use.anim, good, fail)
			local barCue = MeetSoundConfig.endOfLiftCue(lift, good, failedPart, kg)
			if fail then
				task.delay(fail.release + MeetSoundConfig.fallSeconds(lift, failedPart), barSound, barCue)
				task.delay(seconds, backAtSpot)
			elseif good and lift == "Deadlift" then
				task.delay(seconds, barSound, barCue)
				task.delay(seconds + LEAVE_AFTER_FINISH_SECONDS, backAtSpot)
			elseif good then
				-- A good squat or bench: the bar goes back into the J-cups as the lifter comes off it.
				task.delay(seconds + LEAVE_AFTER_FINISH_SECONDS, backAtSpot)
				task.delay(seconds + LEAVE_AFTER_FINISH_SECONDS + MeetSoundConfig.RackGlideSeconds, barSound, barCue)
			else
				backAtSpot()
			end
		end
		task.spawn(function()
			if lift ~= "Deadlift" then
				barSound("BarRack")
			end
			task.wait(MeetLiftAnimation.unrack(use.anim) + START_BEAT_SECONDS)
			if not stillHere() then
				return
			end
			-- Which part of the lift (minigame 1 or 2) a miss failed in: the fail animation shows it.
			local failedPart = 1
			local started, reason = LiftAttemptService.startServerAttempt(player, lift, kg, function(verdict)
				onVerdict(failedPart, verdict)
			end, function(event: string, index: number, _count: number, phaseSeconds: number?, passed: boolean?)
				if not stillHere() then
					return
				end
				if event == "start" then
					failedPart = index
					use.livePhase = index
					-- The first phase follows the minigame's live progress; the second is the pause, as in a meet.
					MeetLiftAnimation.phase(use.anim, index, phaseSeconds, index == 1)
				else
					use.livePhase = nil
					if passed then
						MeetLiftAnimation.progress(use.anim, index, 1)
					end
				end
			end)
			if not started then
				hooks.notify(player, "The lift could not start: " .. tostring(reason))
				backAtSpot()
			end
		end)
	end)

	remotes.warmUpLeave.OnServerEvent:Connect(function(player: Player)
		if uses[player] and hooks.pressAllowed(player) then
			warmUp.stop(player, true)
		end
	end)

	return warmUp
end

return LocalMeetWarmUp
