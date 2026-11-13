--!strict
--[[
	ClothesRemotes
	Shared / Economy

	The clothes' and gear toggle's remotes (ClothesConfig, GAME_DESIGN §38.6). Same pattern as the others: the server
	makes them in code (server LifterBodyService), the client waits (client GearMenu). In the folder ClothesRemotes:

		GetClothes     client -> server  () -> ClothesView?
			What they wear and may wear. Read only.
		SetClothing    client -> server  (kind: string, itemId: string, colourId: string) -> (ok, message, ClothesView?)
			Puts on one piece; the server checks the kind, the item, that it's theirs and the colour, then redresses.
		SetGearOn      client -> server  (on: boolean) -> (ok, message, ClothesView?)
			The gear toggle; the server saves it and redresses.
]]

local ClothesRemotes = {}

ClothesRemotes.FOLDER = "ClothesRemotes"
ClothesRemotes.GET = "GetClothes"
ClothesRemotes.SET = "SetClothing"
ClothesRemotes.GEAR = "SetGearOn"

export type ClothesView = {
	outfit: { [string]: { item: string, colour: string } },
	-- Item ids they may wear (the free ones included).
	owned: { string },
	gearOn: boolean,
	-- Whether their character has the lifter body (the clothes only show on it).
	lifterBody: boolean,
}

export type RemoteSet = {
	get: RemoteFunction,
	set: RemoteFunction,
	gear: RemoteFunction,
}

function ClothesRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(ClothesRemotes.FOLDER)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = ClothesRemotes.FOLDER
		created.Parent = replicatedStorage
		folder = created
	end
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
	return { get = make(ClothesRemotes.GET), set = make(ClothesRemotes.SET), gear = make(ClothesRemotes.GEAR) }
end

-- Waits for the remotes to replicate. Client only.
function ClothesRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(ClothesRemotes.FOLDER, math.huge) :: Instance
	return {
		get = folder:WaitForChild(ClothesRemotes.GET) :: RemoteFunction,
		set = folder:WaitForChild(ClothesRemotes.SET) :: RemoteFunction,
		gear = folder:WaitForChild(ClothesRemotes.GEAR) :: RemoteFunction,
	}
end

return ClothesRemotes
