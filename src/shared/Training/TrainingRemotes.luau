--!strict
--[[
	TrainingRemotes
	Shared / Training

	Names and accessors for the training-rack menu RemoteEvents, so neither side
	hardcodes a string. Same pattern as LiftingRemotes: the server creates them
	in code, the client waits for them, and default.project.json is untouched.

	THE TWO MESSAGES

		TrainingMenuRequest  client -> server  (action, payload?)
			"Start", { mode, lift, primary? }
			"Stop"
			"Close"

		TrainingMenuState    server -> client  (state)
			Everything the menu and the status bar show. Sent when the menu is
			authorized, after every request, on every tick while the player
			holds a rack, and once with open = false when they lose it.

	WHAT THE CLIENT IS TRUSTED WITH

	Only a REQUEST for a mode, a lift and a technique primary stat. It never
	sends a station id (the server knows which rack the player holds), a
	position, a duration, a timestamp, EV, CN or a Game Pass entitlement, and
	a request carrying any extra field is refused. There is no remote that
	reaches PlayerDataService.awardTrainingProgression.

	The menu itself is only OPENED by the server, after the player holds E at a
	rack and the server has checked their presence and the rack's availability.
]]

local TrainingRemotes = {}

TrainingRemotes.FOLDER_NAME = "TrainingRemotes"

TrainingRemotes.MENU_REQUEST = "TrainingMenuRequest"
TrainingRemotes.MENU_STATE = "TrainingMenuState"

local REMOTE_NAMES = {
	TrainingRemotes.MENU_REQUEST,
	TrainingRemotes.MENU_STATE,
}

export type RemoteSet = {
	menuRequest: RemoteEvent,
	menuState: RemoteEvent,
}

--[[
	The shape of a TrainingMenuState message. Display only: the client renders
	it and decides nothing from it.
]]
export type MenuState = {
	-- Whether the server currently authorizes this player's menu.
	open: boolean,
	-- Whether the player holds a rack at all (drives the small status bar).
	occupying: boolean,
	stationId: string?,
	sessionState: string?,
	mode: string?,
	lift: string?,
	primary: string?,
	statusLine: string,
	-- A one-off message: a refusal, the cap notice, the 5B.7 notice.
	notice: string?,
	cnAvailable: boolean,
	evToday: number?,
	evCap: number,
	liftHoursToday: { [string]: number }?,
}

local function collect(folder: Instance, wait: boolean): RemoteSet
	local function get(name: string): RemoteEvent
		if wait then
			return folder:WaitForChild(name) :: RemoteEvent
		end
		return folder:FindFirstChild(name) :: RemoteEvent
	end

	return {
		menuRequest = get(TrainingRemotes.MENU_REQUEST),
		menuState = get(TrainingRemotes.MENU_STATE),
	}
end

--[[
	Creates the remotes under ReplicatedStorage. Server only, called once. Any
	unexpected child left over from an earlier version is destroyed.
]]
function TrainingRemotes.createOnServer(replicatedStorage: Instance): RemoteSet
	local existing = replicatedStorage:FindFirstChild(TrainingRemotes.FOLDER_NAME)
	local folder: Instance

	if existing ~= nil then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = TrainingRemotes.FOLDER_NAME
		created.Parent = replicatedStorage
		folder = created
	end

	local expected: { [string]: boolean } = {}
	for _, name in ipairs(REMOTE_NAMES) do
		expected[name] = true
	end

	for _, child in ipairs(folder:GetChildren()) do
		if not expected[child.Name] then
			child:Destroy()
		end
	end

	for _, name in ipairs(REMOTE_NAMES) do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	return collect(folder, false)
end

--[[
	Waits for the remotes to replicate. Client only.
]]
function TrainingRemotes.waitForClient(replicatedStorage: Instance): RemoteSet
	local folder = replicatedStorage:WaitForChild(TrainingRemotes.FOLDER_NAME)
	return collect(folder, true)
end

return TrainingRemotes
