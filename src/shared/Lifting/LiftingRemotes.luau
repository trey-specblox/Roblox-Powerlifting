--!strict
--[[
	LiftingRemotes
	Shared / Lifting

	Names and accessors for the lifting RemoteEvents, so neither side hardcodes a
	string and a typo cannot silently create a second, dead remote.

	The server creates them; the client waits for them. Creating them in code
	rather than declaring them in default.project.json keeps the Rojo project
	file untouched.

	THE FOUR MESSAGES

		RequestAttempt   client -> server  (phaseName, percentOfForecastedMax)
		PresentChallenge server -> client  the concrete challenge to render
		ReportPress      client -> server  pressTimeSeconds, or nil for a miss
		AnnounceResult   server -> client  the graded verdict

	These are shared by every lift phase, not just the squat. The phase name
	travels with the request so Bench Press and Deadlift Lockout can reuse this
	protocol unchanged rather than needing remotes of their own.

	WHAT THE CLIENT IS TRUSTED WITH

	Three things, none of them authoritative: which phase it is attempting, a
	percentage of its own forecasted max, and a press time. The server validates
	the phase against its own enabled list, clamps the percentage, derives the
	actual weight from the profile it already holds, builds the challenge, and
	grades the press itself. The client never sends a weight, a difficulty, a
	technique stat, or a result.
]]

local LiftingRemotes = {}

LiftingRemotes.FOLDER_NAME = "LiftingRemotes"

LiftingRemotes.REQUEST_ATTEMPT = "RequestAttempt"
LiftingRemotes.PRESENT_CHALLENGE = "PresentChallenge"
LiftingRemotes.REPORT_PRESS = "ReportPress"
LiftingRemotes.ANNOUNCE_RESULT = "AnnounceResult"

--[[
	THE CONTROL PHASE USES ITS OWN FOUR REMOTES.

	A control phase reports a whole list of click times rather than one press, and
	its challenge is a completely different shape. Routing both phase kinds through
	the four remotes above would mean every listener had to discriminate between
	them, and a mistake there would break the working timing check.

	Separate remotes keep the two phases from being able to interfere at all. When
	Control and Depth are eventually chained into one squat there is an obvious
	refactor to a single phase-routed protocol; doing it now would mean touching
	working code for no present benefit.
]]
LiftingRemotes.REQUEST_CONTROL_ATTEMPT = "RequestControlAttempt"
LiftingRemotes.PRESENT_CONTROL_CHALLENGE = "PresentControlChallenge"
LiftingRemotes.REPORT_CONTROL_INPUT = "ReportControlInput"
LiftingRemotes.ANNOUNCE_CONTROL_RESULT = "AnnounceControlResult"

local REMOTE_NAMES = {
	LiftingRemotes.REQUEST_ATTEMPT,
	LiftingRemotes.PRESENT_CHALLENGE,
	LiftingRemotes.REPORT_PRESS,
	LiftingRemotes.ANNOUNCE_RESULT,
	LiftingRemotes.REQUEST_CONTROL_ATTEMPT,
	LiftingRemotes.PRESENT_CONTROL_CHALLENGE,
	LiftingRemotes.REPORT_CONTROL_INPUT,
	LiftingRemotes.ANNOUNCE_CONTROL_RESULT,
}

export type RemoteSet = {
	-- Timing / skill-check phase.
	requestAttempt: RemoteEvent,
	presentChallenge: RemoteEvent,
	reportPress: RemoteEvent,
	announceResult: RemoteEvent,
	-- Control phase.
	requestControlAttempt: RemoteEvent,
	presentControlChallenge: RemoteEvent,
	reportControlInput: RemoteEvent,
	announceControlResult: RemoteEvent,
}

--[[
	Creates the remotes under ReplicatedStorage. Server only, called once.
]]
function LiftingRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(LiftingRemotes.FOLDER_NAME)

	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = LiftingRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end

	for _, name in ipairs(REMOTE_NAMES) do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	return {
		requestAttempt = folder:FindFirstChild(LiftingRemotes.REQUEST_ATTEMPT) :: RemoteEvent,
		presentChallenge = folder:FindFirstChild(LiftingRemotes.PRESENT_CHALLENGE) :: RemoteEvent,
		reportPress = folder:FindFirstChild(LiftingRemotes.REPORT_PRESS) :: RemoteEvent,
		announceResult = folder:FindFirstChild(LiftingRemotes.ANNOUNCE_RESULT) :: RemoteEvent,
		requestControlAttempt = folder:FindFirstChild(LiftingRemotes.REQUEST_CONTROL_ATTEMPT) :: RemoteEvent,
		presentControlChallenge = folder:FindFirstChild(LiftingRemotes.PRESENT_CONTROL_CHALLENGE) :: RemoteEvent,
		reportControlInput = folder:FindFirstChild(LiftingRemotes.REPORT_CONTROL_INPUT) :: RemoteEvent,
		announceControlResult = folder:FindFirstChild(LiftingRemotes.ANNOUNCE_CONTROL_RESULT) :: RemoteEvent,
	}
end

--[[
	Waits for the remotes to replicate. Client only.
]]
function LiftingRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(LiftingRemotes.FOLDER_NAME)

	return {
		requestAttempt = folder:WaitForChild(LiftingRemotes.REQUEST_ATTEMPT) :: RemoteEvent,
		presentChallenge = folder:WaitForChild(LiftingRemotes.PRESENT_CHALLENGE) :: RemoteEvent,
		reportPress = folder:WaitForChild(LiftingRemotes.REPORT_PRESS) :: RemoteEvent,
		announceResult = folder:WaitForChild(LiftingRemotes.ANNOUNCE_RESULT) :: RemoteEvent,
		requestControlAttempt = folder:WaitForChild(LiftingRemotes.REQUEST_CONTROL_ATTEMPT) :: RemoteEvent,
		presentControlChallenge = folder:WaitForChild(LiftingRemotes.PRESENT_CONTROL_CHALLENGE) :: RemoteEvent,
		reportControlInput = folder:WaitForChild(LiftingRemotes.REPORT_CONTROL_INPUT) :: RemoteEvent,
		announceControlResult = folder:WaitForChild(LiftingRemotes.ANNOUNCE_CONTROL_RESULT) :: RemoteEvent,
	}
end

return LiftingRemotes
