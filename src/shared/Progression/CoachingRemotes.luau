--!strict
--[[
	CoachingRemotes
	Shared / Progression

	Getting coached (GAME_DESIGN §40.5). The client only asks; CoachingService checks everything and keeps the save.

		GetCoaching   client -> server (RemoteFunction)  -> CoachingView?
			Where the player stands with each coach, and who is active.
		HireCoach     client -> server (RemoteFunction)  (lift: string) -> (outcome: string, view: CoachingView?)
			"Pay 28,000": starts that coach's trials. Outcome "Paid", "NotEnough", "AlreadyPaid" or "Rejected".
		StartTrial    client -> server (RemoteFunction)  (lift: string) -> (ok: boolean, message: string)
			Trial 1: into the player's Mock Meet room for that coach's lifts.
		SetActive     client -> server (RemoteFunction)  (id: string) -> CoachingView?
			"Be my coach": "Owner" or a hired coach's lift.
		CoachNews     server -> one client (RemoteEvent)  ({ string })
			Lines at the top of the screen (trial 2 passed, ...). Display only.
]]

local CoachingRemotes = {}

CoachingRemotes.FOLDER_NAME = "CoachingRemotes"

export type CoachingView = { active: string, coaches: { [string]: { stage: string, bond: number } }, price: number }
export type RemoteSet = { get: RemoteFunction, hire: RemoteFunction, trial: RemoteFunction, setActive: RemoteFunction,
	news: RemoteEvent }

local NAMES = { get = "GetCoaching", hire = "HireCoach", trial = "StartTrial", setActive = "SetActive", news = "CoachNews" }

local function child(folder: Instance, name: string, className: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = folder
	return made
end

function CoachingRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(CoachingRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = CoachingRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	return {
		get = child(folder, NAMES.get, "RemoteFunction") :: RemoteFunction,
		hire = child(folder, NAMES.hire, "RemoteFunction") :: RemoteFunction,
		trial = child(folder, NAMES.trial, "RemoteFunction") :: RemoteFunction,
		setActive = child(folder, NAMES.setActive, "RemoteFunction") :: RemoteFunction,
		news = child(folder, NAMES.news, "RemoteEvent") :: RemoteEvent,
	}
end

-- Waits for the remotes to replicate. Client only.
function CoachingRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(CoachingRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		get = folder:WaitForChild(NAMES.get) :: RemoteFunction,
		hire = folder:WaitForChild(NAMES.hire) :: RemoteFunction,
		trial = folder:WaitForChild(NAMES.trial) :: RemoteFunction,
		setActive = folder:WaitForChild(NAMES.setActive) :: RemoteFunction,
		news = folder:WaitForChild(NAMES.news) :: RemoteEvent,
	}
end

return CoachingRemotes
