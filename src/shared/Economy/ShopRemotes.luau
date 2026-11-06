--!strict
--[[
	ShopRemotes
	Shared / Economy

	The Shop's remotes (GAME_DESIGN.md 30.6, the money system's step 4). Same
	pattern as the other remotes: the server creates them in code, the client
	waits for them.

		OpenShop   server -> one client
			The player held E at the Shop's counter: open the menu.
		GetShop    client -> server  () -> ShopView?
			The asking player's coins. Read only.
		OpenCrate  client -> server  (crateId: string) -> (ok, message, view, pieceId?, piece?)
			Asks to open one of the gear crates (GAME_DESIGN §35.12). The server checks the
			crate, the coins and the counter, and rolls what is inside itself; the client
			only says which crate.

	The Shop's gear models for the menu's previews are copied by the server
	into ReplicatedStorage[PREVIEWS_NAME] (the templates live in ServerStorage), and the
	crate for its opening intro into ReplicatedStorage[CRATE_MODEL_NAME].
]]

local ShopRemotes = {}

ShopRemotes.FOLDER_NAME = "ShopRemotes"
ShopRemotes.OPEN = "OpenShop"
ShopRemotes.GET = "GetShop"
ShopRemotes.CRATE = "OpenCrate"
ShopRemotes.PREVIEWS_NAME = "ShopPreviews"
ShopRemotes.CRATE_MODEL_NAME = "ShopGearCrate"

export type ShopView = {
	coins: number,
}

export type RemoteSet = {
	open: RemoteEvent,
	get: RemoteFunction,
	crate: RemoteFunction,
}

function ShopRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(ShopRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = ShopRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
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
		open = make(ShopRemotes.OPEN, "RemoteEvent") :: RemoteEvent,
		get = make(ShopRemotes.GET, "RemoteFunction") :: RemoteFunction,
		crate = make(ShopRemotes.CRATE, "RemoteFunction") :: RemoteFunction,
	}
end

-- Waits for the remotes to replicate. Client only.
function ShopRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(ShopRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		open = folder:WaitForChild(ShopRemotes.OPEN) :: RemoteEvent,
		get = folder:WaitForChild(ShopRemotes.GET) :: RemoteFunction,
		crate = folder:WaitForChild(ShopRemotes.CRATE) :: RemoteFunction,
	}
end

return ShopRemotes
