--!strict
--[[
	MockMeetRemotes
	Shared / Meet

	The Mock Meet's remotes, so neither side hardcodes their names. Same pattern
	as CardioRemotes: the server creates them in code, the client waits for
	them, and default.project.json is untouched.

		MockMeetLeave   client -> server  (no arguments)
			"Take me back to the gym" (the Leave button). The server only ever
			moves the player who sent it, and only out of the private room the
			server itself put them in.
		MockMeetChoose  client -> server  (weightKg: number)
			"My next attempt is this weight." A request only: the server checks
			it against the attempt rules and the allowed range, and answers a
			refusal with a notice.
		MockMeetReady   client -> server  (no arguments)
			"Start my lift" (the LIFT button once the bar is loaded).
		MockMeetState   server -> client  (state: table)
			The meet as the server sees it, sent whenever it changes; the
			client only draws it.
		MockMeetNotice  server -> client  (message: string)
			A short message to show (a refused choice, the cooldown).

	Checking IN is not a remote: it is the check-in desk's ProximityPrompt,
	which the server listens to. Nothing here is saved or rewarded.
]]

local MockMeetRemotes = {}

MockMeetRemotes.FOLDER_NAME = "MockMeetRemotes"
MockMeetRemotes.LEAVE = "MockMeetLeave"
MockMeetRemotes.CHOOSE = "MockMeetChoose"
MockMeetRemotes.READY = "MockMeetReady"
MockMeetRemotes.STATE = "MockMeetState"
MockMeetRemotes.NOTICE = "MockMeetNotice"

export type RemoteSet = {
	leave: RemoteEvent,
	choose: RemoteEvent,
	ready: RemoteEvent,
	state: RemoteEvent,
	notice: RemoteEvent,
}

local NAMES = { MockMeetRemotes.LEAVE, MockMeetRemotes.CHOOSE, MockMeetRemotes.READY, MockMeetRemotes.STATE,
	MockMeetRemotes.NOTICE }

--[[
	One attempt as the client sees it. `result` is nil for an attempt not taken
	yet, "Passed" when no legal heavier weight was allowed.
]]
export type AttemptView = { weightKg: number, result: string? }

--[[
	The meet's state, server -> client. `phase` is one of:
		"WeighIn"  the class is shown
		"Choose"   pick the next attempt (minKg..maxKg, suggestedKg, secondsLeft)
		"Ready"    the bar is loaded at declaredKg; press LIFT (secondsLeft)
		"Lifting"  the minigames are running
		"Result"   the verdict (GOOD LIFT or NO LIFT)
		"Waiting"  (Local meet) this lifter is done for the round; the others are still lifting
		"Done"     the meet is over (best, total or bombedOut)
	The Local meet (LocalMeetRemotes.STATE) sends the same state, plus the
	referees' `lights` with a Result, and a `note` (the place) with Done.
]]
export type MeetState = {
	phase: string,
	lift: string?,
	attemptNumber: number?,
	bodyweightKg: number,
	classLabel: string,
	competitionNumber: { [string]: number },
	attempts: { [string]: { AttemptView } },
	declaredKg: number?,
	minKg: number?,
	maxKg: number?,
	suggestedKg: number?,
	secondsLeft: number?,
	verdict: string?,
	best: { [string]: number }?,
	total: number?,
	bombedOut: boolean?,
	-- The referees' lights ("White" or "Red", three of them), Local meet only.
	lights: { string }?,
	-- A line to show instead of the default one (Done: the place; Waiting: why).
	note: string?,
	-- The coach's test (GAME_DESIGN §35.12): what the step tag and Done's banner say instead.
	stepTag: string?,
	banner: string?,
	-- A Local, Regional or State meet: which, for the screen's title.
	meetTitle: string?,
	-- This walk out gets the cinematic camera (the State meet, user 2026-11-06).
	walkOutShot: boolean?,
	-- (Local meet, Choose) where the lifter stands and what this attempt can do: RaceView.
	race: RaceView?,
	-- (Local meet, Ready) the lift starts by itself once the lifter is set up at the bar: no LIFT button.
	autoLift: boolean?,
	-- (Local meet, Ready) what this attempt is for, for the lifter's card ("TO TAKE THE LEAD"), when anything.
	stakes: string?,
	-- (Local meet, Ready) how much hangs on it: LocalMeetConfig.StakesBuild's level.
	stakesLevel: number?,
	-- (Local meet, Result) what a good lift just did, shown in place of GOOD LIFT ("NEW BEST!"), when anything.
	moment: string?,
	-- (Local meet, Choose and the Waiting after it) the lifter is chalking up: ChalkView (client MeetChalkShot).
	chalk: ChalkView?,
	-- (State and up, the Waiting of their turn) the coach's ritual cinematic plays (client MeetRitualShot).
	ritual: RitualView?,
}

-- Where the lifter's chalking up happens: the middle of the group, the way out into the room, and their coach.
export type ChalkView = { at: Vector3, out: Vector3, coach: Model? }

-- The coach's ritual (LocalMeetConfig.Ritual): when it started (Workspace:GetServerTimeNow()), what the coach says
-- while the lifter chalks up, and what they shout with the back slaps.
export type RitualView = { startedAt: number, coachLine: string?, sendOffLine: string }

--[[
	THE RACE (Local meet, user 2026-11-01: "It needs to be clear what you need
	to do before clicking that confirm weight button"). Sent with Choose, so
	the panel can say in plain kilograms what a weight does, without anyone
	working out scores. Measured against everyone's best lifts so far PLUS the
	weight they have declared this round, as if they make it (user 2026-11-06:
	"it is telling you that you need a 25kg bench to take the lead again";
	counting only finished lifts said "needed 2.5 kg" at the start of a lift).
		place        the lifter's place right now (nil: no score yet)
		rivals       everyone else with a score or a declared weight: their name,
		             the weight they declared this round (nil: none yet), and the
		             lightest weight THIS attempt that puts the lifter ahead of them
		             if both are made (0 = ahead even if the lifter misses)
		mustMake     true when missing this attempt means a bomb-out
		lastAttempt  true on the meet's last attempt: the lead is the win
]]
export type RaceRival = { name: string, needKg: number, declaredKg: number? }
export type RaceView = {
	place: number?,
	rivals: { RaceRival },
	mustMake: boolean,
	lastAttempt: boolean,
}

--[[
	Creates the remotes under ReplicatedStorage. Server only, called once. Any
	unexpected child left over from an earlier version is destroyed.
]]
function MockMeetRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(MockMeetRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = MockMeetRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	for _, child in ipairs(folder:GetChildren()) do
		if not table.find(NAMES, child.Name) then
			child:Destroy()
		end
	end
	for _, name in ipairs(NAMES) do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	local function get(name: string): RemoteEvent
		return folder:FindFirstChild(name) :: RemoteEvent
	end
	return {
		leave = get(MockMeetRemotes.LEAVE),
		choose = get(MockMeetRemotes.CHOOSE),
		ready = get(MockMeetRemotes.READY),
		state = get(MockMeetRemotes.STATE),
		notice = get(MockMeetRemotes.NOTICE),
	}
end

--[[
	Waits for the remotes to replicate. Client only.
]]
function MockMeetRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	-- No time limit: the server makes this after building the gym, which takes a while (no "infinite yield" warning).
	local folder = replicatedStorage:WaitForChild(MockMeetRemotes.FOLDER_NAME, math.huge) :: Instance
	local function get(name: string): RemoteEvent
		return folder:WaitForChild(name) :: RemoteEvent
	end
	return {
		leave = get(MockMeetRemotes.LEAVE),
		choose = get(MockMeetRemotes.CHOOSE),
		ready = get(MockMeetRemotes.READY),
		state = get(MockMeetRemotes.STATE),
		notice = get(MockMeetRemotes.NOTICE),
	}
end

return MockMeetRemotes
