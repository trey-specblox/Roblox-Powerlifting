--!strict
--[[
	AdminRemotes
	Shared / Admin

	The admin panel's remotes. Same pattern as the other remotes: the server creates them in
	code, the client waits for them. Every player can see these and call them; the server
	(AdminService) checks the caller's account on every call and refuses everyone else.

		GetAdminPanel  client -> server  (targetUserId: number?) -> AdminView?
			The asking admin's panel, with the chosen player's stats (themself when nil), or nil for
			anyone else (the client then builds nothing).
		AdminAction    client -> server  (action: string, value: any) -> (ok, message, view?)
			On the admin's own account: "ResetSuitTests", "Coins" with a button id from
			AdminConfig.CoinButtons, "CrateRarity" with a rarity id or nil to turn it off, "GiveSuit"
			with a suit id, or "ForceDrop" with a suit id or nil to turn it off.
			On any player in the server (PLAYER STATS, value = { userId = ..., ... }): "SetStat" with
			`id` (an AdminConfig.StatFields id) and `value` (a number the server clamps), "QualifyState",
			"RefillDaily", and "GiveCoinsTo" with `id` (a coin button id). Coins are never an amount.
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
	-- Everyone in the server, for the PLAYER STATS page's picker.
	players: { { userId: number, name: string } },
	-- The chosen player's stats; nil when they have left or their save hasn't loaded.
	target: TargetView?,
}

-- One player's stats on the PLAYER STATS page. `values` by AdminConfig.StatFields id; `effective` the technique stats
-- through the curve, as the stats screen shows them.
export type TargetView = {
	userId: number,
	name: string,
	classKey: string,
	ladderTarget: number,
	qualified: boolean,
	coins: number,
	values: { [string]: number },
	effective: { [string]: number },
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
