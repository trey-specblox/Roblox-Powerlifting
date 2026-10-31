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
			What the asking player owns and their coins. Read only.
		BuyItem    client -> server  (itemId: string) -> (ok: boolean, message: string, view: ShopView?)
			Asks to buy one item. The server checks the item, the price (its
			own, from ShopConfig), the coins, that it is not owned yet and that
			the player is at the counter; the client only sends the id.

	The Shop's gear models for the menu's previews are copied by the server
	into ReplicatedStorage[PREVIEWS_NAME] (the templates live in ServerStorage).
]]

local ShopRemotes = {}

ShopRemotes.FOLDER_NAME = "ShopRemotes"
ShopRemotes.OPEN = "OpenShop"
ShopRemotes.GET = "GetShop"
ShopRemotes.BUY = "BuyItem"
ShopRemotes.PREVIEWS_NAME = "ShopPreviews"

export type ShopView = {
	owned: { string },
	coins: number,
}

export type RemoteSet = {
	open: RemoteEvent,
	get: RemoteFunction,
	buy: RemoteFunction,
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
		buy = make(ShopRemotes.BUY, "RemoteFunction") :: RemoteFunction,
	}
end

-- Waits for the remotes to replicate. Client only.
function ShopRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(ShopRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		open = folder:WaitForChild(ShopRemotes.OPEN) :: RemoteEvent,
		get = folder:WaitForChild(ShopRemotes.GET) :: RemoteFunction,
		buy = folder:WaitForChild(ShopRemotes.BUY) :: RemoteFunction,
	}
end

return ShopRemotes
