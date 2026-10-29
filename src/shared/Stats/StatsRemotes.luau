--!strict
--[[
	StatsRemotes
	Shared / Stats

	The stats screen's one remote (GAME_DESIGN "One UI style for the whole
	game": a STATS screen with the Competition Numbers, the technique stats and
	the weight class). Same pattern as the other remote modules: the server
	creates it in code, the client waits for it, default.project.json is
	untouched.

		GetMyStats  RemoteFunction, client -> server (no arguments)
			Returns a READ-ONLY snapshot of the asking player's own stats
			(StatsSnapshot), or nil when their data is not loaded yet or they
			asked too often. Nothing is ever written; no other player's data
			can be asked for.
]]

local StatsRemotes = {}

StatsRemotes.FOLDER_NAME = "StatsRemotes"
StatsRemotes.GET_MY_STATS = "GetMyStats"

export type TechniqueView = {
	stat: string,
	name: string,
	lift: string,
	-- The effective value (TechniqueCurve), roughly 10 .. 99.5; what the lifts use.
	effective: number,
}

export type StatsSnapshot = {
	classLabel: string,
	bodyweightKg: number,
	targetKg: number,
	-- Kilograms per lift: what training built.
	competitionNumber: { [string]: number },
	-- Kilograms per lift: the heaviest lift proven in a meet; 0 = unproven.
	competitionScale: { [string]: number },
	-- Every trainable technique stat, in lift order.
	technique: { TechniqueView },
}

export type RemoteSet = {
	getMyStats: RemoteFunction,
}

-- Creates the remote under ReplicatedStorage. Server only, called once.
function StatsRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(StatsRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = StatsRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	for _, child in ipairs(folder:GetChildren()) do
		if child.Name ~= StatsRemotes.GET_MY_STATS then
			child:Destroy()
		end
	end
	local remote = folder:FindFirstChild(StatsRemotes.GET_MY_STATS)
	if remote == nil then
		local made = Instance.new("RemoteFunction")
		made.Name = StatsRemotes.GET_MY_STATS
		made.Parent = folder
		remote = made
	end
	return { getMyStats = remote :: RemoteFunction }
end

-- Waits for the remote to replicate. Client only.
function StatsRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(StatsRemotes.FOLDER_NAME)
	return { getMyStats = folder:WaitForChild(StatsRemotes.GET_MY_STATS) :: RemoteFunction }
end

return StatsRemotes
