--!strict
--[[
	GainRemotes
	Shared / Progression

	The gain display's one remote (GAME_DESIGN §40.1, user 2026-11-19: "gains as a whole should be on a screen gain
	display. Any sort of gains"). Same pattern as CoinRemotes: the server creates it in code, the client waits for it.

		Gained   server -> one client  (GainNews)
			Something just made this player stronger: Competition Number from training or a meet, Competition Scale
			from a meet, a technique stat from technique training. DISPLAY ONLY: the server already saved the gain
			before telling; the client can never change anything through this.

	Every later source (quests, boosts, food) sends through the same remote with its own `source`.
]]

local GainRemotes = {}

GainRemotes.FOLDER_NAME = "GainRemotes"
GainRemotes.GAINED = "Gained"

export type GainKind = "Strength" | "Scale" | "Technique"

export type Gain = {
	kind: GainKind,
	-- What grew: a lift ("Squat") for Strength and Scale, a technique stat id for Technique.
	stat: string,
	-- The lift it belongs to (its colour on screen).
	lift: string,
	-- The name shown: "SQUAT", "SQUAT SCALE", "BAR PATH".
	label: string,
	-- How much it grew, in `unit`. Always above zero.
	amount: number,
	-- "kg" for Strength and Scale, "" for technique (its 0-100 value, as the STATS screen shows it).
	unit: string,
}

export type GainNews = {
	-- Where it came from: "Training", "Meet", "MockMeet" (later: "Quest", "Boost"...).
	source: string,
	gains: { Gain },
}

function GainRemotes.createOnServer(replicatedStorage: Instance): RemoteEvent
	local folder = replicatedStorage:FindFirstChild(GainRemotes.FOLDER_NAME)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = GainRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end
	assert(folder ~= nil)
	local remote = folder:FindFirstChild(GainRemotes.GAINED)
	if remote == nil then
		local made = Instance.new("RemoteEvent")
		made.Name = GainRemotes.GAINED
		made.Parent = folder
		remote = made
	end
	return remote :: RemoteEvent
end

-- Waits for the remote to replicate. Client only.
function GainRemotes.waitForClient(replicatedStorage: Instance): RemoteEvent
	local folder = replicatedStorage:WaitForChild(GainRemotes.FOLDER_NAME, math.huge) :: Instance
	return folder:WaitForChild(GainRemotes.GAINED) :: RemoteEvent
end

return GainRemotes
