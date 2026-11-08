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
		LocalMeetSignUp     client -> server  (hallIndex: number)
			"Sign me up for this meet, or take my name off." A hall's sign-up
			desk's prompt does the same for its own meet.
		LocalMeetSpectate   client -> server  (hallIndex: number)
			"Take me to this meet's hall to watch it." The server checks it.
		LocalMeetLobby      server -> client  (LobbyState)
			The five meets' timetable and sign-ups, for everyone in the venue.
		LocalMeetStandings  server -> client  (Standings)
			The live and final ranking, for everyone in that meet's hall.
		LocalMeetAwards     server -> client  (AwardsMoment)
			The awards ceremony has started, for everyone in that meet's hall:
			the camera shots, the crowd cheer and the winner's theme song; the
			winner's own client also plays their celebration.
		LocalMeetWarmUpLift   client -> server  (liftName: string, weightKg: number)
			"Lift this at my warm-up rack." A request: the server checks the lift,
			the weight (AttemptChoice, as for a meet attempt) and the rack.
		LocalMeetWarmUpLeave  client -> server  (no arguments)
			"Step off my warm-up rack."
		LocalMeetWarmUpState  server -> client  (WarmUpState)
			The player's own warm-up: their rack (or none), their CNs, whether a
			lift is running and the last result. Practice only: nothing is saved.
		LocalMeetLevelNews    server -> EVERY client  (LevelNews)
			The next meet is a Regional or a State meet (GAME_DESIGN §35.8),
			for everyone in the server, as soon as its sign-ups open. Display
			only.

	Going INTO the venue is not a remote: it is the gym entrance's
	ProximityPrompt, which the server listens to. What a meet saves is the
	server's (LocalMeetService); nothing here writes anything.
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
LocalMeetRemotes.SPECTATE = "LocalMeetSpectate"
LocalMeetRemotes.LOBBY = "LocalMeetLobby"
LocalMeetRemotes.STANDINGS = "LocalMeetStandings"
LocalMeetRemotes.AWARDS = "LocalMeetAwards"
LocalMeetRemotes.WARM_UP_LIFT = "LocalMeetWarmUpLift"
LocalMeetRemotes.WARM_UP_LEAVE = "LocalMeetWarmUpLeave"
LocalMeetRemotes.WARM_UP_STATE = "LocalMeetWarmUpState"
LocalMeetRemotes.LEVEL_NEWS = "LocalMeetLevelNews"
-- Client -> server, visual only: the live progress of the lifter's running minigame (0..1), so their character's
-- lift follows it (GAME_DESIGN §37.5). Never decides anything.
LocalMeetRemotes.LIFT_PROGRESS = "LocalMeetLiftProgress"
-- The live minigame on a State rack's screen (GAME_DESIGN §36.1), visual only. LIVE_REPORT: the lifter's client -> server, numbers
-- only, about 10 a second. LIVE_SHOW: server -> the players near that screen. Both may drop an update, which only costs a frame.
-- LIVE_EVENT: server -> everyone, a phase starting or ending and the lift's result.
LocalMeetRemotes.LIVE_REPORT = "LocalMeetLiveReport"
LocalMeetRemotes.LIVE_SHOW = "LocalMeetLiveShow"
LocalMeetRemotes.LIVE_EVENT = "LocalMeetLiveEvent"
-- Cheering at the big meets (GAME_DESIGN §36.4, CheerConfig). CHEER_REPORT: a cheerer's client -> server, how loud (0..1) since its
-- last report, about 4 a second, only while in a zone; may drop one. CHEER_STATE: server -> one client, its cheering bar (CheerView).
LocalMeetRemotes.CHEER_REPORT = "LocalMeetCheerReport"
LocalMeetRemotes.CHEER_STATE = "LocalMeetCheerState"
-- CHEER_CHOOSE: client -> server, in the lifters' zone (the meet area): cheer for the next (+1) or previous (-1) lifter up.
LocalMeetRemotes.CHEER_CHOOSE = "LocalMeetCheerChoose"
-- Server -> clients, sound only: a meet sound cue (MeetSoundConfig), where it happened, and optionally how loud (x normal).
LocalMeetRemotes.SOUND = "LocalMeetSound"
-- Client -> server: "send me the meets list" (no arguments). The list works from anywhere, not only in the venue.
LocalMeetRemotes.LOBBY_REQUEST = "LocalMeetLobbyRequest"

export type RemoteSet = {
	leave: RemoteEvent,
	choose: RemoteEvent,
	ready: RemoteEvent,
	state: RemoteEvent,
	notice: RemoteEvent,
	exit: RemoteEvent,
	signUp: RemoteEvent,
	spectate: RemoteEvent,
	lobby: RemoteEvent,
	standings: RemoteEvent,
	awards: RemoteEvent,
	warmUpLift: RemoteEvent,
	warmUpLeave: RemoteEvent,
	warmUpState: RemoteEvent,
	levelNews: RemoteEvent,
	liftProgress: RemoteEvent,
	lobbyRequest: RemoteEvent,
	sound: RemoteEvent,
	liveReport: UnreliableRemoteEvent,
	liveShow: UnreliableRemoteEvent,
	liveEvent: RemoteEvent,
	cheerReport: UnreliableRemoteEvent,
	cheerState: RemoteEvent,
	cheerChoose: RemoteEvent,
}

local NAMES = { LocalMeetRemotes.LEAVE, LocalMeetRemotes.CHOOSE, LocalMeetRemotes.READY, LocalMeetRemotes.STATE,
	LocalMeetRemotes.NOTICE, LocalMeetRemotes.EXIT, LocalMeetRemotes.SIGN_UP, LocalMeetRemotes.LOBBY,
	LocalMeetRemotes.STANDINGS, LocalMeetRemotes.AWARDS, LocalMeetRemotes.WARM_UP_LIFT, LocalMeetRemotes.WARM_UP_LEAVE,
	LocalMeetRemotes.WARM_UP_STATE, LocalMeetRemotes.LEVEL_NEWS, LocalMeetRemotes.LIFT_PROGRESS, LocalMeetRemotes.SOUND,
	LocalMeetRemotes.SPECTATE, LocalMeetRemotes.LOBBY_REQUEST, LocalMeetRemotes.LIVE_EVENT, LocalMeetRemotes.CHEER_STATE,
	LocalMeetRemotes.CHEER_CHOOSE }
-- Allowed to lose an update now and then.
local UNRELIABLE_NAMES = { LocalMeetRemotes.LIVE_REPORT, LocalMeetRemotes.LIVE_SHOW, LocalMeetRemotes.CHEER_REPORT }

--[[
	One of the five meets, as the sign-up list shows it. `nextStartAt` is in
	server time (workspace:GetServerTimeNow()), so every client counts down to
	the same moment.
]]
export type MeetRow = {
	index: number,
	nextStartAt: number,
	signUpClosesAt: number,
	signedUpCount: number,
	-- Whether THIS player is on this meet's list.
	signedUp: boolean,
	running: boolean,
	-- This meet's next level (MeetLevelConfig, GAME_DESIGN §35.8): "LOCAL MEET", "REGIONAL MEET", "STATE MEET",
	-- its prize pot multiplier, and whether its top 3 earn titles.
	levelLabel: string,
	potMultiplier: number,
	titles: boolean,
	-- The State meet (GAME_DESIGN §36.4), how many may lift in this meet, and when THIS player isn't qualified for State, how far off.
	state: boolean,
	maxLifters: number,
	notQualified: string?,
}

-- The timetable and sign-ups, server -> client, sent when they change.
export type LobbyState = {
	meets: { MeetRow },
	-- The hall this player is in, or nil when they are elsewhere in the game.
	hereIndex: number?,
	minimumLifters: number,
	maxLifters: number,
	-- How far a meet could raise each lift's CN right now (8.5 = +8.5%), for THIS player's current
	-- class; absent for a class with no allowance.
	allowancePercent: { [string]: number },
}

-- A meet's next level is Regional or State: which meet, its level, pot multiplier and when it starts / sign-ups close (server time).
export type LevelNews = {
	hallIndex: number,
	levelLabel: string,
	potMultiplier: number,
	startsAt: number,
	signUpClosesAt: number,
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
	-- IPF GL points (MeetPlacing), or nil for none.
	points: number?,
	-- The real player's UserId (a computer lifter has none), so each player's screen can pick out their own row.
	userId: number?,
	-- 1 = first; nil for no place (yet).
	place: number?,
	-- "Lifting", "Bombed" (a lift with no good attempt), "Withdrawn", or "Done".
	status: string,
	-- The referees' lights of the lifter's latest attempt, e.g. { "White", "White", "White" }.
	lights: { string }?,
}

export type Standings = {
	-- Which of the five meets; nil when the player's hall has no meet to show.
	meetIndex: number?,
	-- "SQUAT · ROUND 2", "FINAL", ...
	heading: string,
	final: boolean,
	rows: { StandingRow },
}

-- The awards ceremony, server -> client, once when it starts. Display only: nothing here is saved or trusted.
export type AwardsMoment = {
	-- The winner (1st place); nil when nobody placed (no close-up, no theme).
	winnerUserId: number?,
	winnerName: string?,
	-- Where the winner stands (the podium's gold top), looking at the crowd.
	winnerSpot: CFrame?,
	-- The middle of the podium's top, for the wide shots, and the way the stage faces (toward the crowd).
	stageCentre: Vector3,
	stageFacing: Vector3,
	-- The winner's theme song and celebration (rbxassetid://...), the defaults until custom ones exist.
	themeSoundId: string?,
	celebrationAnimationId: string?,
	-- How long the ceremony lasts.
	seconds: number,
}

--[[
	A player's cheering bar, server -> that player (CHEER_STATE), when it changes. Display only.
	  role "cheer": they stand in a rack's zone while `name` is up: the bar, whether it's full,
	                whether the server counts their voice (voice false: no voice chat, so they can't help),
	                and once the lift is over its `result` ("GOOD LIFT" / "NO LIFT"). In the lifters' zone, with
	                several lifters up, `choice` of `choices`: which one they cheer for (CHEER_CHOOSE switches).
	  role "lifter": the crowd filled their bar: `bonus` technique on what is left of the lift.
	  role "coins": they helped fill `name`'s bar and it was a good lift: `coins` earned.
	  role "none": nothing to show.
]]
export type CheerView = {
	role: string,
	name: string?,
	fill: number?,
	full: boolean?,
	voice: boolean?,
	result: string?,
	choice: number?,
	choices: number?,
	bonus: number?,
	coins: number?,
}

-- The player's own warm-up, server -> client, whenever it changes. Display only.
export type WarmUpState = {
	-- The warm-up rack the player is at (1..), or nil when they are not at one.
	rack: number?,
	-- The player's Competition Number per lift (the current class's), for the weight range and the %.
	competitionNumbers: { [string]: number },
	-- The weight step and the first weight's share of CN (LocalMeetConfig).
	stepKg: number,
	startPercent: number,
	-- A lift is running right now (the minigame is on screen).
	lifting: boolean,
	-- The last lift's result, if any.
	last: { lift: string, weightKg: number, good: boolean }?,
	-- The card's title when it isn't the warm-up room's: PRACTICE at a gym rack (GymPractice).
	title: string?,
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
		if not table.find(NAMES, child.Name) and not table.find(UNRELIABLE_NAMES, child.Name) then
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
	for _, name in ipairs(UNRELIABLE_NAMES) do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("UnreliableRemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	local function get(name: string): RemoteEvent
		return folder:FindFirstChild(name) :: RemoteEvent
	end
	local function getUnreliable(name: string): UnreliableRemoteEvent
		return folder:FindFirstChild(name) :: UnreliableRemoteEvent
	end
	return {
		leave = get(LocalMeetRemotes.LEAVE),
		choose = get(LocalMeetRemotes.CHOOSE),
		ready = get(LocalMeetRemotes.READY),
		state = get(LocalMeetRemotes.STATE),
		notice = get(LocalMeetRemotes.NOTICE),
		exit = get(LocalMeetRemotes.EXIT),
		signUp = get(LocalMeetRemotes.SIGN_UP),
		spectate = get(LocalMeetRemotes.SPECTATE),
		lobby = get(LocalMeetRemotes.LOBBY),
		standings = get(LocalMeetRemotes.STANDINGS),
		awards = get(LocalMeetRemotes.AWARDS),
		warmUpLift = get(LocalMeetRemotes.WARM_UP_LIFT),
		warmUpLeave = get(LocalMeetRemotes.WARM_UP_LEAVE),
		warmUpState = get(LocalMeetRemotes.WARM_UP_STATE),
		levelNews = get(LocalMeetRemotes.LEVEL_NEWS),
		liftProgress = get(LocalMeetRemotes.LIFT_PROGRESS),
		lobbyRequest = get(LocalMeetRemotes.LOBBY_REQUEST),
		sound = get(LocalMeetRemotes.SOUND),
		liveReport = getUnreliable(LocalMeetRemotes.LIVE_REPORT),
		liveShow = getUnreliable(LocalMeetRemotes.LIVE_SHOW),
		liveEvent = get(LocalMeetRemotes.LIVE_EVENT),
		cheerReport = getUnreliable(LocalMeetRemotes.CHEER_REPORT),
		cheerState = get(LocalMeetRemotes.CHEER_STATE),
		cheerChoose = get(LocalMeetRemotes.CHEER_CHOOSE),
	}
end

-- Waits for the remotes to replicate. Client only.
function LocalMeetRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(LocalMeetRemotes.FOLDER_NAME, math.huge) :: Instance
	local function get(name: string): RemoteEvent
		return folder:WaitForChild(name) :: RemoteEvent
	end
	local function getUnreliable(name: string): UnreliableRemoteEvent
		return folder:WaitForChild(name) :: UnreliableRemoteEvent
	end
	return {
		leave = get(LocalMeetRemotes.LEAVE),
		choose = get(LocalMeetRemotes.CHOOSE),
		ready = get(LocalMeetRemotes.READY),
		state = get(LocalMeetRemotes.STATE),
		notice = get(LocalMeetRemotes.NOTICE),
		exit = get(LocalMeetRemotes.EXIT),
		signUp = get(LocalMeetRemotes.SIGN_UP),
		spectate = get(LocalMeetRemotes.SPECTATE),
		lobby = get(LocalMeetRemotes.LOBBY),
		standings = get(LocalMeetRemotes.STANDINGS),
		awards = get(LocalMeetRemotes.AWARDS),
		warmUpLift = get(LocalMeetRemotes.WARM_UP_LIFT),
		warmUpLeave = get(LocalMeetRemotes.WARM_UP_LEAVE),
		warmUpState = get(LocalMeetRemotes.WARM_UP_STATE),
		levelNews = get(LocalMeetRemotes.LEVEL_NEWS),
		liftProgress = get(LocalMeetRemotes.LIFT_PROGRESS),
		lobbyRequest = get(LocalMeetRemotes.LOBBY_REQUEST),
		sound = get(LocalMeetRemotes.SOUND),
		liveReport = getUnreliable(LocalMeetRemotes.LIVE_REPORT),
		liveShow = getUnreliable(LocalMeetRemotes.LIVE_SHOW),
		liveEvent = get(LocalMeetRemotes.LIVE_EVENT),
		cheerReport = getUnreliable(LocalMeetRemotes.CHEER_REPORT),
		cheerState = get(LocalMeetRemotes.CHEER_STATE),
		cheerChoose = get(LocalMeetRemotes.CHEER_CHOOSE),
	}
end

return LocalMeetRemotes
