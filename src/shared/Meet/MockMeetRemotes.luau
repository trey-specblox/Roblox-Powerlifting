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
		"Done"     the meet is over (best, total or bombedOut)
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
