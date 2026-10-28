--!strict
--[[
	MockMeetRemotes
	Shared / Meet

	The Mock Meet's remotes, so neither side hardcodes their names. Same pattern
	as CardioRemotes: the server creates them in code, the client waits for
	them, and default.project.json is untouched.

		MockMeetLeave  client -> server  (no arguments)
			"Take me back to the gym" (the Leave button). The server only ever
			moves the player who sent it, and only out of the private room the
			server itself put them in.

	Checking IN is not a remote: it is the check-in desk's ProximityPrompt,
	which the server listens to. Nothing here is saved or rewarded.
]]

local MockMeetRemotes = {}

MockMeetRemotes.FOLDER_NAME = "MockMeetRemotes"
MockMeetRemotes.LEAVE = "MockMeetLeave"

export type RemoteSet = {
	leave: RemoteEvent,
}

local NAMES = { MockMeetRemotes.LEAVE }

--[[
	Creates the remotes under ReplicatedStorage. Server only, called once. Any
	unexpected child left over from an earlier version is destroyed.
]]
function MockMeetRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(MockMeetRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = MockMeetRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	for _, child in ipairs(folder:GetChildren()) do
		if not table.find(NAMES, child.Name) then
			child:Destroy()
		end
	end
	for _, name in ipairs(NAMES) do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	return { leave = folder:FindFirstChild(MockMeetRemotes.LEAVE) :: RemoteEvent }
end

--[[
	Waits for the remotes to replicate. Client only.
]]
function MockMeetRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(MockMeetRemotes.FOLDER_NAME)
	return { leave = folder:WaitForChild(MockMeetRemotes.LEAVE) :: RemoteEvent }
end

return MockMeetRemotes
