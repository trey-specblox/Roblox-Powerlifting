--!strict
--[[
	MeetLiveScreens
	Server / Meet

	Puts a lifter's running minigame on their rack's big screen at the State meet
	(GAME_DESIGN §36.1: "when a lifter walks up to a weight, spectators watch them
	play their minigame on the screen above"). The drawing is the client's
	(MeetLiveScreen); this passes the news along.

	VISUAL ONLY. Nothing here reaches a lift's verdict: the server still decides
	that from the inputs it replays. So a player faking these numbers could only
	make their own screen look wrong, and even then:

	  - The numbers are checked and clamped for the phase running now, and a sender
	    who isn't on a live screen is ignored.
	  - A client never sends text. Everything readable on the screen (the typing
	    game's letters, the phase's name) comes from the server's own challenge, so
	    nobody can put their own words on a big screen.

	TRAFFIC: the lifter's numbers about 10 times a second, passed on only to players
	within VIEW_STUDS of that screen. At most 4 racks lift at once.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalMeetRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local MeetLiveScreens = {}

-- The attribute on a lifter's character that tells their client to send its numbers.
local LIVE_ATTRIBUTE = "MeetLiveScreen"
-- Who gets the numbers: anyone this close to the screen (the arena's stands are well inside this).
local VIEW_STUDS = 450
-- At most one update from a lifter this often (they send about every 0.1 s).
local MIN_GAP_SECONDS = 0.06
-- The typing game: as many words as a pull can use, far more than one ever reaches.
local MAX_CUES = 60

export type Info = { name: string, lift: string, attemptNumber: number, weightKg: number }

type Live = {
	id: number,
	guis: { Instance },
	kind: string?,
	-- The highest allowed "holds done" (Power) or letter number (Typing).
	limit: number,
	lastAt: number,
}

local remotes: LocalMeetRemotes.RemoteSet? = nil
local lives: { [Player]: Live } = {}
local nextId = 0

-- What every screen needs of a phase's challenge. Only numbers and the server's own words, nothing about the lifter's input.
local function publicChallenge(kind: string, challenge: any): ({ [string]: any }, number)
	if kind == "Control" then
		return { barHeight = challenge.barHeightPx / challenge.trackHeightPx }, 0
	elseif kind == "Power" then
		return { holds = #challenge.holdTriggers }, #challenge.holdTriggers
	elseif kind == "Typing" then
		local cues = {}
		local tokens = 0
		for index, cue in ipairs(challenge.cues) do
			if index > MAX_CUES then
				break
			end
			table.insert(cues, { tokens = cue.tokens, label = cue.label })
			tokens += #cue.tokens
		end
		return { cues = cues }, tokens + 1
	end
	return {
		targetStartDeg = challenge.targetStartDeg,
		targetArcDeg = challenge.targetArcDeg,
		speed = challenge.needleSpeedDegPerSec,
		timeoutSeconds = challenge.timeoutSeconds,
		displayName = challenge.displayName,
	}, 0
end

local function fraction(value: unknown): number?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(value :: number, 0, 1)
end

local function whole(value: unknown, limit: number): number?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value :: number + 0.5), 0, limit)
end

-- A lifter's numbers, checked for the phase that is running, or nil if they make no sense for it.
local function checked(live: Live, a: unknown, b: unknown, c: unknown, d: unknown): (number?, number?, number?, number?)
	if live.kind == "Control" then
		-- Where the bar is, where the marker is, whether it's on the bar (0 or 1), and the meter.
		return fraction(a), fraction(b), whole(c, 1), fraction(d)
	elseif live.kind == "Power" then
		-- The ring, the cue (0 mash, 1 get ready, 2 hold, 3 done), the hold's progress, and holds done.
		return fraction(a), whole(b, 3), fraction(c), whole(d, live.limit)
	elseif live.kind == "Typing" then
		-- The bar, the letter they're on, whether they just missed one (0 or 1), and whether it's done (0 or 1).
		return fraction(a), whole(b, live.limit), whole(c, 1), whole(d, 1)
	end
	return nil
end

local function onReport(player: Player, a: unknown, b: unknown, c: unknown, d: unknown)
	local live = lives[player]
	local set = remotes
	if live == nil or set == nil then
		return
	end
	local now = os.clock()
	if now - live.lastAt < MIN_GAP_SECONDS then
		return
	end
	local first, second, third, fourth = checked(live, a, b, c, d)
	if first == nil or second == nil or third == nil or fourth == nil then
		return
	end
	live.lastAt = now
	local holder = live.guis[1].Parent
	if holder == nil or not holder:IsA("BasePart") then
		return
	end
	local at = holder.Position
	for _, viewer in ipairs(Players:GetPlayers()) do
		local character = viewer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - at).Magnitude <= VIEW_STUDS then
			set.liveShow:FireClient(viewer, live.id, first, second, third, fourth)
		end
	end
end

--[[
	A phase of `player`'s lift started: `guis` are their rack's screens, `kind` and
	`challenge` what LiftAttemptService just presented to them. The first phase of a
	lift puts the panels up.
]]
function MeetLiveScreens.phaseStart(player: Player, guis: { Instance }, info: Info, kind: string, challenge: any)
	local set = remotes
	if set == nil then
		return
	end
	local live = lives[player]
	if live == nil then
		nextId += 1
		live = { id = nextId, guis = guis, kind = nil, limit = 0, lastAt = 0 }
		lives[player] = live
	end
	assert(live)
	local public, limit = publicChallenge(kind, challenge)
	live.kind, live.limit = kind, limit
	local character = player.Character
	if character then
		character:SetAttribute(LIVE_ATTRIBUTE, true)
	end
	set.liveEvent:FireAllClients("phase", live.id, guis, info, kind, public)
end

-- The phase ended and the lift goes on to the next one.
function MeetLiveScreens.phasePassed(player: Player)
	local set, live = remotes, lives[player]
	if set and live then
		live.kind = nil
		set.liveEvent:FireAllClients("passed", live.id)
	end
end

-- The lift's result. The panel stays up with it until stop.
function MeetLiveScreens.verdict(player: Player, good: boolean)
	local set, live = remotes, lives[player]
	if set and live then
		live.kind = nil
		set.liveEvent:FireAllClients("verdict", live.id, good)
	end
end

-- The lift is over: the screen goes back to the lifter's card. Safe to call for anyone.
function MeetLiveScreens.stop(player: Player)
	local set, live = remotes, lives[player]
	if live == nil then
		return
	end
	lives[player] = nil
	local character = player.Character
	if character then
		character:SetAttribute(LIVE_ATTRIBUTE, nil)
	end
	if set then
		set.liveEvent:FireAllClients("stop", live.id)
	end
end

function MeetLiveScreens.start(set: LocalMeetRemotes.RemoteSet)
	if remotes then
		return
	end
	remotes = set
	set.liveReport.OnServerEvent:Connect(onReport)
	Players.PlayerRemoving:Connect(MeetLiveScreens.stop)
end

return MeetLiveScreens
