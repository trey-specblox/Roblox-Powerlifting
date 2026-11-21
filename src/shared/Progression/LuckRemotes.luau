--!strict
--[[
	LuckRemotes
	Shared / Progression

	The mafia boss cow's wheel and games (GAME_DESIGN §40.7, LuckConfig). Same pattern as the other remotes: the
	server creates them in code, the client waits for them. Every answer carries the fresh LuckView.

		GetLuck      client -> server (RemoteFunction)  -> LuckView?
			Your multiplier and its time left, whether today's free spin is unused, spins waiting, tries left.
		Spin         client -> server (RemoteFunction)  -> { outcome, wedge?, multiplier?, free?, view? }
			Spin the wheel (the free daily spin first, else a won spin). The SERVER rolls the wedge; the client only
			turns the wheel to it. "Spun", "NoSpins", "TooFar" (not in the back room), "Busy", "Rejected".
		GameStart    client -> server (RemoteFunction)  (game: string) -> { outcome, start?, swaps?, view? }
			Start one of the cow's games (today: "Shuffle"): uses one of the day's tries. The server decides where the
			steak starts and every swap, and sends them for the client to show. "Started", "NoTries", "TooFar",
			"Busy", "Rejected".
		GameFinish   client -> server (RemoteFunction)  (pick: number) -> { outcome, final?, view? }
			The cloche the player picked (1 to 3, left to right from the player's side). "Won" (a spin is added),
			"Lost", "TooLate", "Rejected".

	Nothing is ever staked: a game costs a try and can only add a spin; a spin only sets the multiplier.
]]

local LuckRemotes = {}

LuckRemotes.FOLDER_NAME = "LuckRemotes"
LuckRemotes.GET = "GetLuck"
LuckRemotes.SPIN = "Spin"
LuckRemotes.GAME_START = "GameStart"
LuckRemotes.GAME_FINISH = "GameFinish"

-- The tag on the "Talk" prompt of the mafia boss cow (KitchenBackRoom puts it there; LuckMenu answers it).
LuckRemotes.PromptTag = "LuckCowPrompt"

-- Seconds are relative to the server's clock at the moment it answered.
export type LuckView = {
	multiplier: number,
	secondsLeft: number,
	freeSpin: boolean,
	spins: number,
	triesLeft: number,
}
export type RemoteSet = { get: RemoteFunction, spin: RemoteFunction, gameStart: RemoteFunction, gameFinish: RemoteFunction }

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

function LuckRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:FindFirstChild(LuckRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = LuckRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	return {
		get = child(folder, LuckRemotes.GET),
		spin = child(folder, LuckRemotes.SPIN),
		gameStart = child(folder, LuckRemotes.GAME_START),
		gameFinish = child(folder, LuckRemotes.GAME_FINISH),
	}
end

-- Waits for the remotes to replicate. Client only.
function LuckRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(LuckRemotes.FOLDER_NAME, math.huge) :: Instance
	return {
		get = folder:WaitForChild(LuckRemotes.GET) :: RemoteFunction,
		spin = folder:WaitForChild(LuckRemotes.SPIN) :: RemoteFunction,
		gameStart = folder:WaitForChild(LuckRemotes.GAME_START) :: RemoteFunction,
		gameFinish = folder:WaitForChild(LuckRemotes.GAME_FINISH) :: RemoteFunction,
	}
end

return LuckRemotes
