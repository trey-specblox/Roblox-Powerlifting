--!strict
--[[
	CardioRemotes
	Shared / World

	The Cardio room's one RemoteEvent, so neither side hardcodes its name. Same
	pattern as TrainingRemotes: the server creates it in code, the client waits
	for it, and default.project.json is untouched.

		CardioHopOff  client -> server  (no arguments)
			"Take me off my machine" (the player pressed Jump). The server only
			ever releases the player who sent it, and only from the machine the
			server itself put them on.

	Hopping ON is not a remote: it is the machine's ProximityPrompt, which the
	server listens to. Nothing here is saved or rewarded.
]]

local CardioRemotes = {}

CardioRemotes.FOLDER_NAME = "CardioRemotes"
CardioRemotes.HOP_OFF = "CardioHopOff"

export type RemoteSet = {
	hopOff: RemoteEvent,
}

--[[
	Creates the remote under ReplicatedStorage. Server only, called once. Any
	unexpected child left over from an earlier version is destroyed.
]]
function CardioRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(CardioRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = CardioRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	for _, child in ipairs(folder:GetChildren()) do
		if child.Name ~= CardioRemotes.HOP_OFF then
			child:Destroy()
		end
	end
	local hopOff = folder:FindFirstChild(CardioRemotes.HOP_OFF)
	if hopOff == nil then
		local remote = Instance.new("RemoteEvent")
		remote.Name = CardioRemotes.HOP_OFF
		remote.Parent = folder
		hopOff = remote
	end
	return { hopOff = hopOff :: RemoteEvent }
end

--[[
	Waits for the remote to replicate. Client only.
]]
function CardioRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(CardioRemotes.FOLDER_NAME)
	return { hopOff = folder:WaitForChild(CardioRemotes.HOP_OFF) :: RemoteEvent }
end

return CardioRemotes
