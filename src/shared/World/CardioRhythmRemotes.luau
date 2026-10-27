--!strict
--[[
	CardioRhythmRemotes
	Shared / World

	The treadmill rhythm game's RemoteEvents, so neither side hardcodes a name.
	Same pattern as CardioRemotes: the server creates them, the client waits.

		RhythmPress   client -> server  (lane: number)
			"I pressed this lane." The only thing a client ever sends. The server
			decides from its own clock whether it hit a note; a client never sends
			a time, a note, a score or its health.
		RhythmState   server -> every client  (state)
			The round: phase, seed, start and end times, and each runner's health,
			whether they are out and how long they have survived.
		RhythmJudged  server -> every client  (userId, noteIndex, result)
			Each judged note: "Perfect", "Good", "Miss", or "Stray" (a press with
			no note near; noteIndex 0).
]]

local CardioRhythmRemotes = {}

CardioRhythmRemotes.FOLDER_NAME = "CardioRhythmRemotes"
local NAMES = { "RhythmPress", "RhythmState", "RhythmJudged" }

export type RunnerView = { userId: number, name: string, health: number, out: boolean, seconds: number }
export type State = {
	phase: string, -- "Idle", "Countdown", "Running" or "Results"
	seed: number,
	startAt: number, -- server time (Workspace:GetServerTimeNow()) when the music starts
	endsAt: number, -- Countdown: = startAt; Results: when the results go
	runners: { RunnerView },
}

export type RemoteSet = { press: RemoteEvent, state: RemoteEvent, judged: RemoteEvent }

local function collect(folder: Instance, wait: boolean): RemoteSet
	local function get(name: string): RemoteEvent
		return (if wait then folder:WaitForChild(name) else folder:FindFirstChild(name)) :: RemoteEvent
	end
	return { press = get("RhythmPress"), state = get("RhythmState"), judged = get("RhythmJudged") }
end

-- Server only, once. Unexpected children left from an earlier version are destroyed.
function CardioRhythmRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(CardioRhythmRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = CardioRhythmRemotes.FOLDER_NAME
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
	return collect(folder, false)
end

-- Client only: waits for the remotes to replicate.
function CardioRhythmRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	return collect(replicatedStorage:WaitForChild(CardioRhythmRemotes.FOLDER_NAME), true)
end

return CardioRhythmRemotes
