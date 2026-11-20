--!strict
--[[
	KitchenRemotes
	Shared / Progression

	Steaks and the Kitchen (GAME_DESIGN §40.7). Same pattern as the other remotes: the server creates them in code, the
	client waits for them. Every answer carries the fresh KitchenView (the cooker and the steak boost).

		GetKitchen   client -> server (RemoteFunction)  -> KitchenView?
			The cooker and the boost, for the cooker's menu and the boost timer. Reads only.
		Cook         client -> server (RemoteFunction)  (steaks: number) -> { outcome, balance?, view? }
			Pay for that many steaks and start cooking. The server checks the count and the coins; the price and the
			cooking time come from KitchenConfig.
		Eat          client -> server (RemoteFunction)  -> { outcome, percent?, view? }
			Eat the finished meal: the steak boost starts (replacing one already running).
]]

local KitchenRemotes = {}

KitchenRemotes.FOLDER_NAME = "KitchenRemotes"
KitchenRemotes.GET = "GetKitchen"
KitchenRemotes.COOK = "Cook"
KitchenRemotes.EAT = "Eat"

-- Seconds are relative to the server's clock at the moment it answered.
export type KitchenView = {
	steaks: number,
	readyIn: number,
	cookSeconds: number,
	boostPercent: number,
	boostLeft: number,
	boostSteaks: number,
}
export type RemoteSet = { get: RemoteFunction, cook: RemoteFunction, eat: RemoteFunction }

local function child(folder: Instance, name: string): RemoteFunction
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteFunction
	end
	local made = Instance.new("RemoteFunction")
	made.Name = name
	made.Parent = folder
	return made
end

function KitchenRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(KitchenRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = KitchenRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	return {
		get = child(folder, KitchenRemotes.GET),
		cook = child(folder, KitchenRemotes.COOK),
		eat = child(folder, KitchenRemotes.EAT),
	}
end

-- Waits for the remotes to replicate. Client only.
function KitchenRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(KitchenRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		get = folder:WaitForChild(KitchenRemotes.GET) :: RemoteFunction,
		cook = folder:WaitForChild(KitchenRemotes.COOK) :: RemoteFunction,
		eat = folder:WaitForChild(KitchenRemotes.EAT) :: RemoteFunction,
	}
end

return KitchenRemotes
