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
]]

local GearRemotes = {}

GearRemotes.FOLDER_NAME = "GearRemotes"
GearRemotes.GET = "GetGear"
GearRemotes.SET = "SetWorn"

export type GearView = {
	owned: { string },
	-- slot -> item id
	wearing: { [string]: string },
	-- False while the worn models are not in the game (not uploaded or not loaded): choices are saved, not drawn.
	drawn: boolean,
}

export type RemoteSet = {
	get: RemoteFunction,
	set: RemoteFunction,
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
	return { get = make(GearRemotes.GET), set = make(GearRemotes.SET) }
end

-- Waits for the remotes to replicate. Client only.
function GearRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(GearRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		get = folder:WaitForChild(GearRemotes.GET) :: RemoteFunction,
		set = folder:WaitForChild(GearRemotes.SET) :: RemoteFunction,
	}
end

return GearRemotes
