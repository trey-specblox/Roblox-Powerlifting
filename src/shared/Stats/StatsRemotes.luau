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

		SetWeightGoal  RemoteFunction, client -> server (goal, confirmed)
			GAME_DESIGN §38.3: `goal` is BodyweightConfig.Maintain or a weight
			class label, `confirmed` a boolean (the player agreed to leave a
			class that holds their Nationals/Worlds spot). The server checks
			both and decides; it returns a WeightGoalReply. It can only set the
			asking player's own goal, never their weight.

		WeightNews  RemoteEvent, server -> client (text)
			A line for the top of the screen: a new weight class, a goal
			reached.
]]

local StatsRemotes = {}

StatsRemotes.FOLDER_NAME = "StatsRemotes"
StatsRemotes.GET_MY_STATS = "GetMyStats"
StatsRemotes.SET_WEIGHT_GOAL = "SetWeightGoal"
StatsRemotes.WEIGHT_NEWS = "WeightNews"

export type TechniqueView = {
	stat: string,
	name: string,
	lift: string,
	-- The effective value (TechniqueCurve), roughly 10 .. 99.5; what the lifts use.
	effective: number,
}

-- One State Champion badge: its game-wide number (0 = on its way) and its season as players read it ("NOV 2026").
export type ChampionBadgeView = { number: number, seasonLabel: string }

export type StatsSnapshot = {
	classLabel: string,
	bodyweightKg: number,
	targetKg: number,
	-- Kilograms per lift: what training built.
	competitionNumber: { [string]: number },
	-- Kilograms per lift: the heaviest lift proven in a meet; 0 = unproven.
	competitionScale: { [string]: number },
	-- The best Total from one finished meet in this class; 0 = none yet.
	bestTotalKg: number,
	-- Every trainable technique stat, in lift order.
	technique: { TechniqueView },
	-- The player's coins (GAME_DESIGN 30.6).
	coins: number,
	-- The meet titles earned, best first ("State Champion x2"; GAME_DESIGN §35.8).
	titles: { string }?,
	-- The numbered State Champion badges, newest first (GAME_DESIGN §36.4; at most 24).
	championBadges: { ChampionBadgeView }?,
	-- This season's ladder toward State in the player's current class (GAME_DESIGN §35.8, §36.3): points of
	-- target, qualified, and when the season ends (Unix seconds).
	ladder: { points: number, target: number, qualified: boolean, seasonEndsAt: number }?,
	-- The road to Nationals in the player's current class (GAME_DESIGN §36.4 "The Nationals spot"): top-3 State
	-- placings of target, whether they hold the spot, and whether they have competed at Nationals on it yet.
	nationals: { placings: number, target: number, qualified: boolean, competed: boolean }?,
}

export type WeightGoalReply = {
	outcome: string, -- "Set", "NeedsConfirm" or "Rejected"
	message: string,
	targetKg: number?,
}

export type RemoteSet = {
	getMyStats: RemoteFunction,
	setWeightGoal: RemoteFunction,
	weightNews: RemoteEvent,
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
	local wanted = { [StatsRemotes.GET_MY_STATS] = "RemoteFunction", [StatsRemotes.SET_WEIGHT_GOAL] = "RemoteFunction",
		[StatsRemotes.WEIGHT_NEWS] = "RemoteEvent" }
	for _, child in ipairs(folder:GetChildren()) do
		if wanted[child.Name] ~= child.ClassName then
			child:Destroy()
		end
	end
	local function get(name: string): Instance
		local remote = (folder :: Instance):FindFirstChild(name)
		if remote == nil then
			local made = Instance.new(wanted[name])
			made.Name = name
			made.Parent = folder
			remote = made
		end
		return remote :: Instance
	end
	return {
		getMyStats = get(StatsRemotes.GET_MY_STATS) :: RemoteFunction,
		setWeightGoal = get(StatsRemotes.SET_WEIGHT_GOAL) :: RemoteFunction,
		weightNews = get(StatsRemotes.WEIGHT_NEWS) :: RemoteEvent,
	}
end

-- Waits for the remote to replicate. Client only.
function StatsRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	-- No time limit: the server makes this after building the gym, which takes a while (no "infinite yield" warning).
	local folder = replicatedStorage:WaitForChild(StatsRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		getMyStats = folder:WaitForChild(StatsRemotes.GET_MY_STATS) :: RemoteFunction,
		setWeightGoal = folder:WaitForChild(StatsRemotes.SET_WEIGHT_GOAL) :: RemoteFunction,
		weightNews = folder:WaitForChild(StatsRemotes.WEIGHT_NEWS) :: RemoteEvent,
	}
end

return StatsRemotes
