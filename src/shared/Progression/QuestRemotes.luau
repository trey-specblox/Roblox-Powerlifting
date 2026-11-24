--!strict
--[[
	QuestRemotes
	Shared / Progression

	The coaches' daily quests (GAME_DESIGN §40.6). Same pattern as the other remotes: the server creates them in code,
	the client waits for them.

		GetQuests   client -> server (RemoteFunction)  -> { [lift]: QuestView }
			Today's quests, for the coach dialogue and the quest tracker. Reads only.
		TakeQuest   client -> server (RemoteFunction)  (lift: string) -> { [lift]: QuestView }
			"I need a stronger squat": that coach's quest goes on the player's tracker. The server checks the lift.
		QuestNews   server -> one client (RemoteEvent)  ({ string })
			Lines after a meet moved a quest ("Coach Squatavious: 1/2 good squats today."). Display only.
]]

local QuestRemotes = {}

QuestRemotes.FOLDER_NAME = "QuestRemotes"
QuestRemotes.GET = "GetQuests"
QuestRemotes.NEWS = "QuestNews"
QuestRemotes.TAKE = "TakeQuest"

-- `taken`: asked that coach today; `resetIn`: seconds until the daily reset (server clock).
export type QuestView = { goodLifts: number, needed: number, done: boolean, taken: boolean, resetIn: number }
export type RemoteSet = { get: RemoteFunction, news: RemoteEvent, take: RemoteFunction }

local function child(folder: Instance, name: string, className: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = folder
	return made
end

function QuestRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(QuestRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = QuestRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	return {
		get = child(folder, QuestRemotes.GET, "RemoteFunction") :: RemoteFunction,
		news = child(folder, QuestRemotes.NEWS, "RemoteEvent") :: RemoteEvent,
		take = child(folder, QuestRemotes.TAKE, "RemoteFunction") :: RemoteFunction,
	}
end

-- Waits for the remotes to replicate. Client only.
function QuestRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(QuestRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		get = folder:WaitForChild(QuestRemotes.GET) :: RemoteFunction,
		news = folder:WaitForChild(QuestRemotes.NEWS) :: RemoteEvent,
		take = folder:WaitForChild(QuestRemotes.TAKE) :: RemoteFunction,
	}
end

return QuestRemotes
