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

return CelebrationRemotes
