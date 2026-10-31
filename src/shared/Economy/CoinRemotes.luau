--!strict
--[[
	CoinRemotes
	Shared / Economy

	The coin screens' one remote (GAME_DESIGN.md 30.6, the money system).
	Same pattern as the other remotes: the server creates it in code, the
	client waits for it.

		CoinsChanged   server -> one client  (CoinChange)
			The player's coins just changed: the pop-up ("+150 COINS · 1ST
			PLACE"). Display only. The balance itself is also kept in the
			player attribute CoinConfig.BalanceAttribute, which the counter
			reads; the client can never change either.
]]

local CoinRemotes = {}

CoinRemotes.FOLDER_NAME = "CoinRemotes"
CoinRemotes.CHANGED = "CoinsChanged"

export type CoinChange = {
	-- +amount for coins earned, -amount for coins spent.
	change: number,
	balance: number,
	-- What it was for, shown under the amount ("1st place", "Shop: Red Belt").
	reason: string,
}

function CoinRemotes.createOnServer(replicatedStorage: Instance): RemoteEvent
	local folder = replicatedStorage:FindFirstChild(CoinRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = CoinRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	local remote = folder:FindFirstChild(CoinRemotes.CHANGED)
	if remote == nil then
		local made = Instance.new("RemoteEvent")
		made.Name = CoinRemotes.CHANGED
		made.Parent = folder
		remote = made
	end
	return remote :: RemoteEvent
end

-- Waits for the remote to replicate. Client only.
function CoinRemotes.waitForClient(replicatedStorage: Instance): RemoteEvent
	local folder = replicatedStorage:WaitForChild(CoinRemotes.FOLDER_NAME, math.huge) :: Instance
	return folder:WaitForChild(CoinRemotes.CHANGED) :: RemoteEvent
end

return CoinRemotes
