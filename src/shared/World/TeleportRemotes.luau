--!strict
--[[
	TeleportRemotes
	Shared / World

	The TELEPORT menu's one remote (TeleportConfig). Same pattern as the other
	remotes: the server creates it in code, the client waits for it.

		RequestTeleport   client -> server  (destinationId: string) -> (ok: boolean, message: string?)
			Asks to go to one of TeleportConfig.Destinations. The server checks
			everything (TeleportService) and moves the player itself; `message`
			says why not.
]]

local TeleportRemotes = {}

TeleportRemotes.FOLDER_NAME = "TeleportRemotes"
TeleportRemotes.REQUEST = "RequestTeleport"

function TeleportRemotes.createOnServer(replicatedStorage: Instance): RemoteFunction
	local folder = replicatedStorage:FindFirstChild(TeleportRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = TeleportRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	local remote = folder:FindFirstChild(TeleportRemotes.REQUEST)
	if remote == nil then
		local made = Instance.new("RemoteFunction")
		made.Name = TeleportRemotes.REQUEST
		made.Parent = folder
		remote = made
	end
	return remote :: RemoteFunction
end

-- Waits for the remote to replicate. Client only.
function TeleportRemotes.waitForClient(replicatedStorage: Instance): RemoteFunction
	local folder = replicatedStorage:WaitForChild(TeleportRemotes.FOLDER_NAME, math.huge) :: Instance
	return folder:WaitForChild(TeleportRemotes.REQUEST) :: RemoteFunction
end

return TeleportRemotes
