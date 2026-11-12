--!strict
--[[
	EmoteRemotes
	Shared / Meet

	The emotes' remotes (EmoteConfig; user 2026-11-11: an emote wheel on B). Same pattern as the others: the server makes
	them in code (EmoteService), the client waits (client EmoteWheel). In the folder EmoteRemotes:

		GetEmotes     client -> server  () -> { string }?
			The emotes this player can play (the free ones included), in the wheel's order. Read only.
		PlayEmote     client -> server  (emoteId: string) -> (ok, message)
			Asks to play one. The server checks it is theirs, that they aren't lifting, in a meet's turn or a mock meet,
			and not too fast, then plays it on their character for everyone (walking cancels it).
		EmoteStarted  server -> all clients  (emoteId: string, startedAt: number, figure: Model)
			Someone started one: each player's game plays its sound locked to the animation (client CelebrationFx).
			Display only.
]]

local EmoteRemotes = {}

EmoteRemotes.FOLDER = "EmoteRemotes"
EmoteRemotes.GET = "GetEmotes"
EmoteRemotes.PLAY = "PlayEmote"
EmoteRemotes.STARTED = "EmoteStarted"

export type RemoteSet = {
	get: RemoteFunction,
	play: RemoteFunction,
	started: RemoteEvent,
}

function EmoteRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(EmoteRemotes.FOLDER)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = EmoteRemotes.FOLDER
		created.Parent = replicatedStorage
		folder = created
	end
	local function make(name: string, className: string): Instance
		local existing = (folder :: Instance):FindFirstChild(name)
		if existing then
			return existing
		end
		local made = Instance.new(className)
		made.Name = name
		made.Parent = folder
		return made
	end
	return {
		get = make(EmoteRemotes.GET, "RemoteFunction") :: RemoteFunction,
		play = make(EmoteRemotes.PLAY, "RemoteFunction") :: RemoteFunction,
		started = make(EmoteRemotes.STARTED, "RemoteEvent") :: RemoteEvent,
	}
end

-- Waits for the remotes to replicate. Client only.
function EmoteRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(EmoteRemotes.FOLDER, math.huge) :: Instance
	return {
		get = folder:WaitForChild(EmoteRemotes.GET) :: RemoteFunction,
		play = folder:WaitForChild(EmoteRemotes.PLAY) :: RemoteFunction,
		started = folder:WaitForChild(EmoteRemotes.STARTED) :: RemoteEvent,
	}
end

return EmoteRemotes
