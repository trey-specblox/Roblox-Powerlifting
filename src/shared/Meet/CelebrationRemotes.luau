--!strict
--[[
	CelebrationRemotes
	Shared / Meet

	The celebrations' one remote (same pattern as MockMeetRemotes: the server makes it in code, the client waits):

		CelebrationStarted  server -> client  (celebrationId: string, startedAt: number, figure: Model)
			"This figure (a player's character or a computer lifter) has just started this celebration"
			(Workspace:GetServerTimeNow() when it started), sent to everyone: each player's game draws its effects
			(client CelebrationFx), and the celebrating player's own screen runs its cinematic, if it has one
			(client CelebrationCinema). Display only.

	Asking to play one (the admin's viewer) goes through the admin panel's own remote (AdminService "PlayCelebration"),
	which checks the account.

	The celebration spin (CelebrationConfig.Spin), in the folder CelebrationSpinRemotes:

		OpenSpinner  server -> one client
			The player held E on the celebration NPC: open the spin screen.
		GetSpinner   client -> server  () -> SpinView?
			Their coins and current celebration. Read only.
		SpinCelebration  client -> server  () -> (ok, message, view?, resultId?, refund)
			Asks for one spin. The server checks the coins and that they stand by the NPC, rolls the result itself, takes
			the price and makes the result theirs; the client only asks, then shows the reel landing on the result.
]]

local CelebrationRemotes = {}

CelebrationRemotes.STARTED = "CelebrationStarted"

function CelebrationRemotes.createOnServer(replicatedStorage: Instance): RemoteEvent
	local found = replicatedStorage:FindFirstChild(CelebrationRemotes.STARTED)
	if found and found:IsA("RemoteEvent") then
		return found
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = CelebrationRemotes.STARTED
	remote.Parent = replicatedStorage
	return remote
end

function CelebrationRemotes.waitForClient(replicatedStorage: Instance): RemoteEvent
	return replicatedStorage:WaitForChild(CelebrationRemotes.STARTED, math.huge) :: RemoteEvent
end

CelebrationRemotes.SPIN_FOLDER = "CelebrationSpinRemotes"
CelebrationRemotes.OPEN_SPINNER = "OpenSpinner"
CelebrationRemotes.GET_SPINNER = "GetSpinner"
CelebrationRemotes.SPIN = "SpinCelebration"

export type SpinView = {
	coins: number,
	current: string,
}

export type SpinRemotes = {
	open: RemoteEvent,
	get: RemoteFunction,
	spin: RemoteFunction,
}

function CelebrationRemotes.createSpinOnServer(replicatedStorage: Instance): SpinRemotes
	local folder = replicatedStorage:FindFirstChild(CelebrationRemotes.SPIN_FOLDER)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = CelebrationRemotes.SPIN_FOLDER
		created.Parent = replicatedStorage
		folder = created
	end
	local function make(name: string, className: string): Instance
		local existing = (folder :: Instance):FindFirstChild(name)
		if existing then
			return existing
		end
		local made = Instance.new(className)
		made.Name = name
		made.Parent = folder
		return made
	end
	return {
		open = make(CelebrationRemotes.OPEN_SPINNER, "RemoteEvent") :: RemoteEvent,
		get = make(CelebrationRemotes.GET_SPINNER, "RemoteFunction") :: RemoteFunction,
		spin = make(CelebrationRemotes.SPIN, "RemoteFunction") :: RemoteFunction,
	}
end

-- Waits for the spin's remotes to replicate. Client only.
function CelebrationRemotes.waitForSpinClient(replicatedStorage: Instance): SpinRemotes
	local folder = replicatedStorage:WaitForChild(CelebrationRemotes.SPIN_FOLDER, math.huge) :: Instance
	return {
		open = folder:WaitForChild(CelebrationRemotes.OPEN_SPINNER) :: RemoteEvent,
		get = folder:WaitForChild(CelebrationRemotes.GET_SPINNER) :: RemoteFunction,
		spin = folder:WaitForChild(CelebrationRemotes.SPIN) :: RemoteFunction,
	}
end

return CelebrationRemotes
