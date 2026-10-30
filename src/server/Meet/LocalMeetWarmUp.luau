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
		                        difficulty as a meet, Scale challenge included)
		LEAVE                   the player steps off the rack

	PRACTICE ONLY: a verdict is shown and nothing is written (no CN, no Scale,
	no records, no allowance). The client only asks; one player per rack.
	A player who starts lifting in a meet, leaves the venue or dies is taken
	off their rack (stop).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local LocalMeetRemotes = require(MeetFolder:WaitForChild("LocalMeetRemotes"))
local AttemptChoice = require(MeetFolder:WaitForChild("AttemptChoice"))

local ServerFolder = script.Parent.Parent
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))
local PlayerDataService = require(ServerFolder:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))

local LocalMeetWarmUp = {}

-- What LocalMeetService lends the warm-up (it owns the venue visits, the characters and the prompts' look).
export type Hooks = {
	-- Whether the player may step up to a warm-up rack now, or the reason they may not.
	canUse: (player: Player) -> (boolean, string?),
	standAt: (player: Player, spot: CFrame, anchored: boolean) -> (),
	release: (player: Player) -> (),
	notify: (player: Player, message: string) -> (),
	prompt: (parent: BasePart, action: string, object: string, onTriggered: (Player) -> ()) -> ProximityPrompt,
	pressAllowed: (player: Player) -> boolean,
}

export type WarmUp = {
	-- Takes the player off their rack (if they are at one) and stops their lift; steps them off the rack when
	-- `stepOff` (otherwise the caller moves them).
	stop: (player: Player, stepOff: boolean) -> (),
	isWarmingUp: (player: Player) -> boolean,
}

type Use = {
	rack: LocalMeetVenue.WarmUpRack,
	lifting: boolean,
	last: { lift: string, weightKg: number, good: boolean }?,
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
		}
		remotes.warmUpState:FireClient(player, state)
	end

	local warmUp = {} :: WarmUp

	function warmUp.isWarmingUp(player: Player): boolean
		return uses[player] ~= nil
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
		hooks.release(player)
		if stepOff then
			-- A couple of steps forward, off the rack, free to walk.
			hooks.standAt(player, use.rack.liftSpot * CFrame.new(0, 0, -3), false)
		end
		sendState(player)
		log("%s left warm-up rack %d", player.Name, use.rack.index)
	end

	local function stepUp(player: Player, rack: LocalMeetVenue.WarmUpRack)
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

	for _, rack in ipairs(racks) do
		prompts[rack.index] = hooks.prompt(rack.point, LocalMeetConfig.WarmUp.PromptAction,
			LocalMeetConfig.WarmUp.PromptObject, function(player)
				stepUp(player, rack)
			end)
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
		local started, reason = LiftAttemptService.startServerAttempt(player, lift, kg, function(verdict)
			-- Only if the player is still on this rack (stop() ends a use; a new use is a new table).
			if uses[player] ~= use then
				return
			end
			use.lifting = false
			use.last = { lift = lift, weightKg = kg, good = verdict == "GoodLift" }
			sendState(player)
		end)
		if not started then
			use.lifting = false
			hooks.notify(player, "The lift could not start: " .. tostring(reason))
		end
		sendState(player)
	end)

	remotes.warmUpLeave.OnServerEvent:Connect(function(player: Player)
		if uses[player] and hooks.pressAllowed(player) then
			warmUp.stop(player, true)
		end
	end)

	return warmUp
end

return LocalMeetWarmUp
