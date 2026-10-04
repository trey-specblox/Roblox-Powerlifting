--!strict
--[[
	LiftingRemotes
	Shared / Lifting

	Names and accessors for the lifting RemoteEvents, so neither side hardcodes a
	string and a typo cannot silently create a second, dead remote.

	The server creates them; the client waits for them. Creating them in code
	rather than declaring them in default.project.json keeps the Rojo project file
	untouched.

	THE FIVE MESSAGES

		RequestLiftAttempt   client -> server  (liftName, attemptPercent)
		PresentPhase         server -> client  render this phase
		ReportPhaseInput     client -> server  (attemptId, kind, payload)
		AnnouncePhaseResult  server -> client  that phase is decided
		AnnounceAttemptResult server -> client the whole lift is decided

	WHAT THE CLIENT IS TRUSTED WITH

	Two things, neither authoritative: which lift it wants to attempt and at what
	percentage of its own forecasted max, and the raw inputs it produced during a
	phase. It never sends a weight, a difficulty, a progress value, a phase name of
	its choosing, a phase result, or a lift verdict.

	WHY THERE IS NO PER-PHASE REQUEST REMOTE

	There used to be: RequestAttempt and RequestControlAttempt each took a phase
	name, which meant a client could ask for Squat Depth directly and skip the
	control phase entirely. Deleting them is what makes phase order a server
	property rather than a client suggestion. The orchestrator decides the sequence;
	there is no message a client can send to influence it.

	ReportPhaseInput carries the phase kind so the server can reject input that
	does not belong to the phase actually running, and an attemptId so a reply to a
	finished attempt cannot affect a newer one.
]]

local LiftingRemotes = {}

LiftingRemotes.FOLDER_NAME = "LiftingRemotes"

LiftingRemotes.REQUEST_LIFT_ATTEMPT = "RequestLiftAttempt"
LiftingRemotes.PRESENT_PHASE = "PresentPhase"
LiftingRemotes.REPORT_PHASE_INPUT = "ReportPhaseInput"
LiftingRemotes.ANNOUNCE_PHASE_RESULT = "AnnouncePhaseResult"
LiftingRemotes.ANNOUNCE_ATTEMPT_RESULT = "AnnounceAttemptResult"

local REMOTE_NAMES = {
	LiftingRemotes.REQUEST_LIFT_ATTEMPT,
	LiftingRemotes.PRESENT_PHASE,
	LiftingRemotes.REPORT_PHASE_INPUT,
	LiftingRemotes.ANNOUNCE_PHASE_RESULT,
	LiftingRemotes.ANNOUNCE_ATTEMPT_RESULT,
}

export type RemoteSet = {
	requestLiftAttempt: RemoteEvent,
	presentPhase: RemoteEvent,
	reportPhaseInput: RemoteEvent,
	announcePhaseResult: RemoteEvent,
	announceAttemptResult: RemoteEvent,
}

local function collect(folder: Instance, wait: boolean): RemoteSet
	local function get(name: string): RemoteEvent
		if wait then
			return folder:WaitForChild(name) :: RemoteEvent
		end
		return folder:FindFirstChild(name) :: RemoteEvent
	end

	return {
		requestLiftAttempt = get(LiftingRemotes.REQUEST_LIFT_ATTEMPT),
		presentPhase = get(LiftingRemotes.PRESENT_PHASE),
		reportPhaseInput = get(LiftingRemotes.REPORT_PHASE_INPUT),
		announcePhaseResult = get(LiftingRemotes.ANNOUNCE_PHASE_RESULT),
		announceAttemptResult = get(LiftingRemotes.ANNOUNCE_ATTEMPT_RESULT),
	}
end

--[[
	Creates the remotes under ReplicatedStorage. Server only, called once.

	Any remote left over from an earlier version is destroyed, so a stale
	RequestAttempt cannot survive a live-sync in Studio and reopen the bypass this
	protocol exists to close.
]]
function LiftingRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(LiftingRemotes.FOLDER_NAME)

	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = LiftingRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end

	local expected: { [string]: boolean } = {}
	for _, name in ipairs(REMOTE_NAMES) do
		expected[name] = true
	end

	for _, child in ipairs(folder:GetChildren()) do
		if not expected[child.Name] then
			child:Destroy()
		end
	end

	for _, name in ipairs(REMOTE_NAMES) do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	return collect(folder, false)
end

--[[
	Waits for the remotes to replicate. Client only.
]]
function LiftingRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(LiftingRemotes.FOLDER_NAME)
	return collect(folder, true)
end

return LiftingRemotes
