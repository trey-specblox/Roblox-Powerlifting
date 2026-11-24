--!strict
--[[
	RankRemotes
	Shared / Progression

	Ranks and titles (GAME_DESIGN §41, RankConfig). Same pattern as the other remotes: the server creates them in code,
	the client waits for them. Every answer carries the fresh RankView.

		GetRanks       client -> server (RemoteFunction)  -> RankView?
			The lifter's rank, rewards waiting, free crates and titles. Reads only.
		Claim          client -> server (RemoteFunction)  (upTo: number?) -> { paid: RankRewards?, view: RankView? }
			Collect the ranks reached but not yet paid, up to rank upTo (nil = all): coins, a free crate each, the
			new-name luck boost.
		OpenFreeCrate  client -> server (RemoteFunction)  (crateId: string) -> { ok, message, piece?, pieceId?, view? }
			Open one free rank crate of that kind (the roll is the server's, with the lifter's luck).
		SetTitle       client -> server (RemoteFunction)  (id: string) -> RankView?
			Show that title ("" = none picked). Only a title the lifter owns.
		TitlesSeen     client -> server (RemoteFunction)  -> RankView?
			The titles screen was opened: the NEW tags go.
		RankNews       server -> client (RemoteEvent)     (news: RankNews)
			A real meet just moved this lifter's rank or earned titles. Shown after the meet's awards.
		Announce       server -> every client (RemoteEvent) (line: Announcement)
			A rare rank name or a Legendary title reached by someone in the server (one chat line).

	THE NAME TAG reads player attributes the server sets: RankIndex (0 = none), TitleId ("" = none) and TitleCount.
]]

local RankRemotes = {}

RankRemotes.FOLDER_NAME = "RankRemotes"

export type TitleOwned = { count: number, earnedUnix: number, new: boolean }
export type RankView = {
	rank: number,
	points: number,
	bestTotalKg: number,
	bestBodyweightKg: number,
	bestClass: string,
	claimed: number,
	freeCrates: number,
	luckBoostLeft: number,
	streakDays: number,
	title: string,
	picked: string,
	titles: { [string]: TitleOwned },
}
export type RankRewards = {
	ranks: { number },
	coins: number,
	crates: number,
	luckBoost: boolean,
	coinsRefused: boolean,
	balance: number?,
}
export type RankNews = {
	rankBefore: number,
	rankAfter: number,
	pointsBefore: number,
	points: number, -- this meet's GL points
	newBest: boolean,
	newFeats: { string },
	view: RankView?,
}
export type Announcement = { name: string, kind: string, id: string, rank: number? }

export type RemoteSet = {
	get: RemoteFunction,
	claim: RemoteFunction,
	openFreeCrate: RemoteFunction,
	setTitle: RemoteFunction,
	titlesSeen: RemoteFunction,
	news: RemoteEvent,
	announce: RemoteEvent,
}

local FUNCTIONS = { get = "GetRanks", claim = "Claim", openFreeCrate = "OpenFreeCrate", setTitle = "SetTitle",
	titlesSeen = "TitlesSeen" }
local EVENTS = { news = "RankNews", announce = "Announce" }

function RankRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(RankRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = RankRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	local set: { [string]: Instance } = {}
	for key, name in pairs(FUNCTIONS) do
		local existing = folder:FindFirstChild(name)
		if existing == nil then
			existing = Instance.new("RemoteFunction")
			existing.Name = name
			existing.Parent = folder
		end
		set[key] = existing :: Instance
	end
	for key, name in pairs(EVENTS) do
		local existing = folder:FindFirstChild(name)
		if existing == nil then
			existing = Instance.new("RemoteEvent")
			existing.Name = name
			existing.Parent = folder
		end
		set[key] = existing :: Instance
	end
	return set :: any
end

-- Waits for the remotes to replicate. Client only.
function RankRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(RankRemotes.FOLDER_NAME, math.huge) :: Instance
	local set: { [string]: Instance } = {}
	for key, name in pairs(FUNCTIONS) do
		set[key] = folder:WaitForChild(name)
	end
	for key, name in pairs(EVENTS) do
		set[key] = folder:WaitForChild(name)
	end
	return set :: any
end

return RankRemotes
