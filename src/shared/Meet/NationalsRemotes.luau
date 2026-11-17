--!strict
--[[
	NationalsRemotes
	Shared / Meet

	Nationals' remotes (GAME_DESIGN.md §39, step 1: the gathering). The server creates them in code,
	the client waits for them. A client only ASKS; the server decides who may sign up and who goes.

		NationalsSignUp   client -> server  (no arguments)
			"Put my name down for the next Nationals, or take it off." The NATIONALS desk's prompt
			does the same. The server checks the spot (ProfileOperations.getNationals).
		NationalsLeave    client -> server  (no arguments)
			In a Nationals server: "take me back to the game" (a teleport to a public server).
		NationalsRequest  client -> server  (no arguments)
			"Send me my Nationals line" (the MEETS list opening).
		NationalsState    server -> client  (View)
			This player's NATIONALS line, when it changes. Display only.
]]

local NationalsRemotes = {}

NationalsRemotes.FOLDER_NAME = "NationalsRemotes"
NationalsRemotes.SIGN_UP = "NationalsSignUp"
NationalsRemotes.LEAVE = "NationalsLeave"
NationalsRemotes.REQUEST = "NationalsRequest"
NationalsRemotes.STATE = "NationalsState"

local NAMES = { NationalsRemotes.SIGN_UP, NationalsRemotes.LEAVE, NationalsRemotes.REQUEST, NationalsRemotes.STATE }

export type RemoteSet = {
	signUp: RemoteEvent,
	leave: RemoteEvent,
	request: RemoteEvent,
	state: RemoteEvent,
}

--[[
	The player's NATIONALS line. Times are server time (workspace:GetServerTimeNow()).
	  shown        false: no row at all (Nationals not open to this player yet: not Live and not an admin)
	  here         true in a Nationals server (or Studio's stand-in): they are AT Nationals
	  qualified    they hold the spot in the class they weigh in at now
	  classLabel   that class ("74 kg")
	  why          when they may not sign up, a few words ("4 / 10 TOWARD NATIONALS IN 74 kg")
	  signedUp     on the list for the next one
	  signedUpCount  across all servers, as last read (nil = not known)
	  status       a few words for the moment ("GATHERING LIFTERS…", "TAKING YOU TO NATIONALS")
	  liftersHere  at Nationals: how many lifters it gathered
	  test         the admins' test Nationals (not Live)
]]
export type View = {
	shown: boolean,
	here: boolean,
	nextStartAt: number,
	signUpClosesAt: number,
	minimumLifters: number,
	potMultiplier: number,
	qualified: boolean,
	classLabel: string?,
	why: string?,
	signedUp: boolean,
	signedUpCount: number?,
	status: string?,
	liftersHere: number?,
	test: boolean,
}

function NationalsRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(NationalsRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = NationalsRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
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
		signUp = get(NationalsRemotes.SIGN_UP),
		leave = get(NationalsRemotes.LEAVE),
		request = get(NationalsRemotes.REQUEST),
		state = get(NationalsRemotes.STATE),
	}
end

-- Waits for the remotes to replicate. Client only.
function NationalsRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(NationalsRemotes.FOLDER_NAME, math.huge) :: Instance
	local function get(name: string): RemoteEvent
		return folder:WaitForChild(name) :: RemoteEvent
	end
	return {
		signUp = get(NationalsRemotes.SIGN_UP),
		leave = get(NationalsRemotes.LEAVE),
		request = get(NationalsRemotes.REQUEST),
		state = get(NationalsRemotes.STATE),
	}
end

return NationalsRemotes
