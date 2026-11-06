--!strict
--[[
	GearRemotes
	Shared / Economy

	MY GEAR's remotes (GAME_DESIGN.md 30.6, the money system's step 5). Same
	pattern as ShopRemotes: the server creates them in code, the client waits.

		GetGear  client -> server  () -> GearView?
			What the asking player owns and wears. Read only.
		SetWorn  client -> server  (slot: string, itemId: string | false) -> (ok: boolean, message: string, view: GearView?)
			Puts an item on in a slot, or takes the slot's item off (false).
			The server checks the slot, that the item belongs in it and that
			the player owns it.
		SetWornPiece  client -> server  (pieceId: string) -> (ok, message, view)
			Puts on a piece of stat gear, in its own slot (GAME_DESIGN §35.12).
		ScrapPiece    client -> server  (pieceId: string) -> (ok, message, view)
			Scraps a piece for coins. The server decides the coins, from its rarity.
]]

local GearRemotes = {}

GearRemotes.FOLDER_NAME = "GearRemotes"
GearRemotes.GET = "GetGear"
GearRemotes.SET = "SetWorn"
GearRemotes.SET_PIECE = "SetWornPiece"
GearRemotes.SCRAP = "ScrapPiece"

export type GearView = {
	owned: { string },
	-- slot -> item id
	wearing: { [string]: string },
	-- False while the worn models are not in the game (not uploaded or not loaded): choices are saved, not drawn.
	drawn: boolean,
	-- Gear with stats: piece id -> piece, and which piece is worn in each slot.
	pieces: { [string]: { slot: string, rarity: string, look: string } },
	wearingPieces: { [string]: string },
}

export type RemoteSet = {
	get: RemoteFunction,
	set: RemoteFunction,
	setPiece: RemoteFunction,
	scrap: RemoteFunction,
}

function GearRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(GearRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = GearRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	local function make(name: string): RemoteFunction
		local existing = (folder :: Instance):FindFirstChild(name)
		if existing then
			return existing :: RemoteFunction
		end
		local made = Instance.new("RemoteFunction")
		made.Name = name
		made.Parent = folder
		return made
	end
	return { get = make(GearRemotes.GET), set = make(GearRemotes.SET), setPiece = make(GearRemotes.SET_PIECE),
		scrap = make(GearRemotes.SCRAP) }
end

-- Waits for the remotes to replicate. Client only.
function GearRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(GearRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		get = folder:WaitForChild(GearRemotes.GET) :: RemoteFunction,
		set = folder:WaitForChild(GearRemotes.SET) :: RemoteFunction,
		setPiece = folder:WaitForChild(GearRemotes.SET_PIECE) :: RemoteFunction,
		scrap = folder:WaitForChild(GearRemotes.SCRAP) :: RemoteFunction,
	}
end

return GearRemotes
