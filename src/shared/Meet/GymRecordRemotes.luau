--!strict
--[[
	GymRecordRemotes
	Shared / Meet

	The record news remotes (GAME_DESIGN.md §31.6, "The gym record wall — first
	build", user 2026-10-30). Same pattern as the meet remotes: the server
	creates them in code, the client waits for them.

		GymRecordBroken   server -> every client  (Announcement)
			Someone just set a record at an official meet: everyone in the
			server sees it. Display only; the record itself is the server's
			(GymRecords).
		RecordAttempt     server -> every client  (AttemptNews)
			A lifter at an official meet just declared a weight that would beat
			a record; `watch` is the TELEPORT place to go and watch
			(TeleportConfig). Display only.

	Each record says its LEVEL. Only gym records exist so far; national and
	world records (GAME_DESIGN §31.6) will use the same messages.
]]

local GymRecordRemotes = {}

GymRecordRemotes.FOLDER_NAME = "GymRecordRemotes"
GymRecordRemotes.BROKEN = "GymRecordBroken"
GymRecordRemotes.ATTEMPT = "RecordAttempt"

export type RecordLevel = "GYM" | "NATIONAL" | "WORLD"

-- One record in an announcement: the record ("Squat", "Bench", "Deadlift", "Total"), the new kg, and who held it.
export type BrokenRecord = {
	level: RecordLevel,
	record: string,
	kg: number,
	-- Nil for an empty spot (the first record there).
	previousName: string?,
	previousKg: number?,
	-- The lifter beat their own record.
	own: boolean,
}

export type Announcement = {
	name: string,
	userId: number,
	classLabel: string,
	-- The lift first, then the Total if that fell too.
	records: { BrokenRecord },
}

-- One record a declared weight would beat.
export type AttemptRecord = { level: RecordLevel, record: string, kg: number }

export type AttemptNews = {
	name: string,
	userId: number,
	classLabel: string,
	-- The lift first, then the Total if that would fall too.
	records: { AttemptRecord },
	-- Where it happens, for the line ("LOCAL MEET"), and the TELEPORT place that goes there.
	where: string,
	watch: string?,
}

local function remoteIn(folder: Instance, name: string): RemoteEvent
	local remote = folder:FindFirstChild(name)
	if remote == nil then
		local made = Instance.new("RemoteEvent")
		made.Name = name
		made.Parent = folder
		remote = made
	end
	return remote :: RemoteEvent
end

-- Returns the BROKEN and the ATTEMPT remotes.
function GymRecordRemotes.createOnServer(replicatedStorage: Instance): (RemoteEvent, RemoteEvent)
	local folder = replicatedStorage:FindFirstChild(GymRecordRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = GymRecordRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	return remoteIn(folder, GymRecordRemotes.BROKEN), remoteIn(folder, GymRecordRemotes.ATTEMPT)
end

-- Waits for the remotes to replicate (BROKEN, ATTEMPT). Client only.
function GymRecordRemotes.waitForClient(replicatedStorage: Instance): (RemoteEvent, RemoteEvent)
	local folder = replicatedStorage:WaitForChild(GymRecordRemotes.FOLDER_NAME, math.huge) :: Instance
	return folder:WaitForChild(GymRecordRemotes.BROKEN) :: RemoteEvent,
		folder:WaitForChild(GymRecordRemotes.ATTEMPT) :: RemoteEvent
end

return GymRecordRemotes
