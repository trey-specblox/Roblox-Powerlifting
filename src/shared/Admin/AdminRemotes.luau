--!strict
--[[
	AdminRemotes
	Shared / Admin

	The admin panel's remotes. Same pattern as the other remotes: the server creates them in
	code, the client waits for them. Every player can see these and call them; the server
	(AdminService) checks the caller's account on every call and refuses everyone else.

		GetAdminPanel  client -> server  () -> AdminView?
			The asking admin's panel, or nil for anyone else (the client then builds nothing).
		AdminAction    client -> server  (action: string, value: any) -> (ok, message, view?)
			"ResetSuitTests", "Coins" with a button id from AdminConfig.CoinButtons, "CrateRarity" with a
			rarity id or nil to turn it off, "GiveSuit" with a suit id, or "ForceDrop" with a
			suit id or nil to turn it off. Never an amount.
]]

local AdminRemotes = {}

AdminRemotes.FOLDER_NAME = "AdminRemotes"
AdminRemotes.GET = "GetAdminPanel"
AdminRemotes.ACTION = "AdminAction"

export type AdminView = {
	coins: number,
	-- What the admin's crates are set to give; nil when they roll normally.
	crateRarity: string?,
	-- The suit the admin's next meet will drop; nil for the normal chance.
	forcedDrop: string?,
}

export type RemoteSet = {
	get: RemoteFunction,
	action: RemoteFunction,
}

function AdminRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = Instance.new("Folder")
	folder.Name = AdminRemotes.FOLDER_NAME
	local get = Instance.new("RemoteFunction")
	get.Name = AdminRemotes.GET
	get.Parent = folder
	local action = Instance.new("RemoteFunction")
	action.Name = AdminRemotes.ACTION
	action.Parent = folder
	folder.Parent = replicatedStorage
	return { get = get, action = action }
end

-- Waits for the remotes to replicate. Client only.
function AdminRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(AdminRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		get = folder:WaitForChild(AdminRemotes.GET) :: RemoteFunction,
		action = folder:WaitForChild(AdminRemotes.ACTION) :: RemoteFunction,
	}
end

return AdminRemotes
