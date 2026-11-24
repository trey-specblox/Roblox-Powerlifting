--!strict
--[[
	InventoryRemotes
	Shared / Economy

	The INVENTORY's items (GAME_DESIGN §42): food collected from the chef, medals and trophies. Same pattern as the other
	remotes: the server creates them in code, the client waits for them. Gear (stat pieces and Shop items) keeps its own
	remotes (GearRemotes); the INVENTORY screen shows both.

		GetInventory  client -> server (RemoteFunction)  -> InventoryView?
		Use           client -> server (RemoteFunction)  (itemId: string) -> { outcome, percent?, kind?, view?, kitchen? }
			Eat a food item: its boost starts (KitchenConfig's cook-timer rules). The server checks it is theirs.
		Hold          client -> server (RemoteFunction)  (key: string | false) -> (held: boolean, message: string)
			Hold an item ("item:3", "piece:12", "shop:belt_black"); the same key again, or false, puts it away (HoldService).
		ItemsChanged  server -> client (RemoteEvent)     (view: InventoryView)
			The items changed on the server (food collected, a medal or trophy won).
]]

local InventoryRemotes = {}

InventoryRemotes.FOLDER_NAME = "InventoryRemotes"

export type Item = { type: string, qty: number, food: string?, count: number?, hours: number?, level: string?, place: number? }
export type InventoryView = { items: { [string]: Item } }
export type RemoteSet = { get: RemoteFunction, use: RemoteFunction, hold: RemoteFunction, changed: RemoteEvent }

local function child(folder: Instance, className: string, name: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = folder
	return made
end

function InventoryRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(InventoryRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = InventoryRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	return {
		get = child(folder, "RemoteFunction", "GetInventory") :: RemoteFunction,
		use = child(folder, "RemoteFunction", "Use") :: RemoteFunction,
		hold = child(folder, "RemoteFunction", "Hold") :: RemoteFunction,
		changed = child(folder, "RemoteEvent", "ItemsChanged") :: RemoteEvent,
	}
end

-- Waits for the remotes to replicate. Client only.
function InventoryRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(InventoryRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		get = folder:WaitForChild("GetInventory") :: RemoteFunction,
		use = folder:WaitForChild("Use") :: RemoteFunction,
		hold = folder:WaitForChild("Hold") :: RemoteFunction,
		changed = folder:WaitForChild("ItemsChanged") :: RemoteEvent,
	}
end

return InventoryRemotes
