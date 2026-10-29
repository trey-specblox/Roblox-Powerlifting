--!strict
--[[
	LocalMeetRemotes
	Shared / Meet

	The Local meet's remotes (GAME_DESIGN.md §29.10 "The Local meet — first
	build"). Same pattern as MockMeetRemotes: the server creates them in code,
	the client waits for them. The lifter's own screen uses the Mock Meet's
	screen and the same five names' meaning (leave, choose, ready, state,
	notice), so MockMeetController can drive it.

		LocalMeetLeave      client -> server  (no arguments)
			"Withdraw me from the meet" (the meet screen's LEAVE). The lifter
			steps off their platform and stays in the venue.
		LocalMeetChoose     client -> server  (weightKg: number)
			"My next attempt is this weight." A request: the server checks it.
		LocalMeetReady      client -> server  (no arguments)
			"Start my lift" (LIFT once the bar is loaded).
		LocalMeetState      server -> client  (MockMeetRemotes.MeetState)
			The lifter's own meet, as the server sees it.
		LocalMeetNotice     server -> client  (message: string)
			A short message to show.
		LocalMeetExit       client -> server  (no arguments)
			"Take me back to the gym" (the venue screen's EXIT). Withdraws a
			lifter first.
		LocalMeetSignUp     client -> server  (no arguments)
			"Sign me up, or take my name off" for the next meet. The sign-up
			desk's prompt does the same.
		LocalMeetLobby      server -> client  (LobbyState)
			The timetable and the sign-ups, for everyone in the venue.
		LocalMeetStandings  server -> client  (Standings)
			The live and final ranking, for everyone in the venue.

	Going INTO the venue is not a remote: it is the gym entrance's
	ProximityPrompt, which the server listens to. Nothing here is saved yet.
]]

local LocalMeetRemotes = {}

LocalMeetRemotes.FOLDER_NAME = "LocalMeetRemotes"
LocalMeetRemotes.LEAVE = "LocalMeetLeave"
LocalMeetRemotes.CHOOSE = "LocalMeetChoose"
LocalMeetRemotes.READY = "LocalMeetReady"
LocalMeetRemotes.STATE = "LocalMeetState"
LocalMeetRemotes.NOTICE = "LocalMeetNotice"
LocalMeetRemotes.EXIT = "LocalMeetExit"
LocalMeetRemotes.SIGN_UP = "LocalMeetSignUp"
LocalMeetRemotes.LOBBY = "LocalMeetLobby"
LocalMeetRemotes.STANDINGS = "LocalMeetStandings"

export type RemoteSet = {
	leave: RemoteEvent,
	choose: RemoteEvent,
	ready: RemoteEvent,
	state: RemoteEvent,
	notice: RemoteEvent,
	exit: RemoteEvent,
	signUp: RemoteEvent,
	lobby: RemoteEvent,
	standings: RemoteEvent,
}

local NAMES = { LocalMeetRemotes.LEAVE, LocalMeetRemotes.CHOOSE, LocalMeetRemotes.READY, LocalMeetRemotes.STATE,
	LocalMeetRemotes.NOTICE, LocalMeetRemotes.EXIT, LocalMeetRemotes.SIGN_UP, LocalMeetRemotes.LOBBY,
	LocalMeetRemotes.STANDINGS }

--[[
	The timetable and sign-ups, server -> client, sent when they change.
	`nextStartAt` is in server time (workspace:GetServerTimeNow()), so every
	client counts down to the same moment.
]]
export type LobbyState = {
	nextStartAt: number,
	signUpClosesAt: number,
	signedUpCount: number,
	-- Whether THIS player is signed up.
	signedUp: boolean,
	meetRunning: boolean,
	minimumLifters: number,
	maxLifters: number,
}

-- One lifter's line on the standings.
export type StandingRow = {
	name: string,
	platform: number,
	classLabel: string,
	bodyweightKg: number,
	-- Best good lift per lift so far (absent = none yet).
	best: { [string]: number },
	-- The sum of the bests so far, or the final total.
	subtotalKg: number,
	-- Score as a percentage (Total / class reference Total x 100), or nil for none.
	scorePercent: number?,
	-- 1 = first; nil for no place (yet).
	place: number?,
	-- "Lifting", "Bombed" (a lift with no good attempt), "Withdrawn", or "Done".
	status: string,
	-- The referees' lights of the lifter's latest attempt, e.g. { "White", "White", "White" }.
	lights: { string }?,
}

export type Standings = {
	-- "SQUAT · ROUND 2", "FINAL", ...
	heading: string,
	final: boolean,
	rows: { StandingRow },
}

function LocalMeetRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(LocalMeetRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = LocalMeetRemotes.FOLDER_NAME
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
		leave = get(LocalMeetRemotes.LEAVE),
		choose = get(LocalMeetRemotes.CHOOSE),
		ready = get(LocalMeetRemotes.READY),
		state = get(LocalMeetRemotes.STATE),
		notice = get(LocalMeetRemotes.NOTICE),
		exit = get(LocalMeetRemotes.EXIT),
		signUp = get(LocalMeetRemotes.SIGN_UP),
		lobby = get(LocalMeetRemotes.LOBBY),
		standings = get(LocalMeetRemotes.STANDINGS),
	}
end

-- Waits for the remotes to replicate. Client only.
function LocalMeetRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(LocalMeetRemotes.FOLDER_NAME, math.huge) :: Instance
	local function get(name: string): RemoteEvent
		return folder:WaitForChild(name) :: RemoteEvent
	end
	return {
		leave = get(LocalMeetRemotes.LEAVE),
		choose = get(LocalMeetRemotes.CHOOSE),
		ready = get(LocalMeetRemotes.READY),
		state = get(LocalMeetRemotes.STATE),
		notice = get(LocalMeetRemotes.NOTICE),
		exit = get(LocalMeetRemotes.EXIT),
		signUp = get(LocalMeetRemotes.SIGN_UP),
		lobby = get(LocalMeetRemotes.LOBBY),
		standings = get(LocalMeetRemotes.STANDINGS),
	}
end

return LocalMeetRemotes
