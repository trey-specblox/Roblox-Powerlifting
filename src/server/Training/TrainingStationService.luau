--!strict
--[[
	TrainingStationService
	Server / Training

	The universal gym training racks of checkpoint 5B.6 (GAME_DESIGN.md section
	34.3, 34.5 and 34.12). The ONLY caller of
	PlayerDataService.awardTrainingProgression, and therefore the only place
	Competition Number is ever earned (section 34.2).

	=========================================================================
	HOW A PLAYER USES A RACK
	=========================================================================

	Every rack is identical: one ProximityPrompt, "Train", held E for
	PromptHoldSeconds. The prompt fires on the SERVER with the Player who held
	it. The server checks the player is really standing there and the rack is
	free, RESERVES it for them, and tells their client to open the Training
	Selection menu. Holding E at your own rack reopens the menu.

	In the menu the player picks Competition Number (a lift) or Technique (a
	lift and a primary stat) and presses Start Training. That is a REQUEST over
	TrainingMenuRequest; this service re-validates everything (TrainingRemotes
	lists what the client may and may not send).

	Racks are found through CollectionService (TrainingStationConfig.StationTag
	plus a "StationId" attribute), so adding a rack means placing a tagged
	model -- no new script, no progression code per rack.

	=========================================================================
	THE TICK
	=========================================================================

	ONE loop for the whole server, every TickSeconds. For each rack occupant:

		1. Check presence (in game, data loaded, alive, within range). Any
		   failure ends the occupancy with NO credit for the interval.
		2. Otherwise settle the interval through TrainingStationRules: measured
		   with os.clock() from this player's last tick, clamped to
		   MaxCreditSecondsPerTick, credited ONLY if CN training is running and
		   CN can still be earned today.

	At the 4.00 EV cap a FREE player's training STOPS: no more CN, no
	technique, no change of mode or lift. The rack stays theirs and they are
	told "Daily CN Limit Reached -- Training Stopped". Automatic switching to
	technique is a FUTURE Game Pass feature and is not implemented here.

	The gateway never yields, so nothing interleaves: a tick, a switch and a
	Stop can never credit the same seconds twice.

	=========================================================================
	WHAT 5B.6 DELIBERATELY DOES NOT DO
	=========================================================================

	- No technique points. Technique can be selected and is shown as "available
	  in Step 5B.7"; its time is discarded.
	- No Game Pass, no MarketplaceService, no automatic fallback.
	- No anti-idle measures. Roblox's idle kick disconnects the player, which
	  ends accrual like any other disconnect. No offline progression, ever.
	- The selection is remembered only while the player holds the rack.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local TrainingStationConfig = require(ConfigFolder:WaitForChild("TrainingStationConfig"))
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local TrainingAllowance = require(ProgressionFolder:WaitForChild("TrainingAllowance"))

local TrainingFolder = Shared:WaitForChild("Training")
local TrainingStationRules = require(TrainingFolder:WaitForChild("TrainingStationRules"))
local TrainingRemotes = require(TrainingFolder:WaitForChild("TrainingRemotes"))

local PlayerDataService = require(script.Parent.Parent.PlayerData.PlayerDataService)
local PlaceholderStations = require(script.Parent.PlaceholderStations)

local TrainingStationService = {}

-- Prints a line per occupancy change, refusal and tick. Useful while testing in Studio.
local VERBOSE = true

type Station = {
	stationId: string,
	instance: Instance,
	prompt: ProximityPrompt,
	sign: BillboardGui,
	statusLabel: TextLabel,
}

local stations: { [string]: Station } = {}
local registry = TrainingStationRules.newRegistry()
local limiter = TrainingStationRules.newRateLimiter()
local remotes: TrainingRemotes.RemoteSet? = nil

-- Death and respawn listeners for each occupant, disconnected when they leave the rack.
local occupantConnections: { [Player]: { RBXScriptConnection } } = {}

-- Whether we already logged that a player is being rate limited, so spam does not flood Output.
local rateLimitLogged: { [Player]: boolean } = {}

local started = false
local ticking = false

local function log(message: string, ...: any)
	if VERBOSE then
		print("[TrainingStationService] " .. string.format(message, ...))
	end
end

--------------------------------------------------------------------------------
-- READING THE PLAYER
--------------------------------------------------------------------------------

local function readCN(player: Player): TrainingStationRules.CNStatus
	local data = PlayerDataService.getData(player)
	if data == nil then
		return "Unavailable"
	end

	return TrainingStationRules.cnStatus(data.cnAllowance, os.time())
end

local function cnReaderFor(player: Player): TrainingStationRules.CNReader
	return function()
		return readCN(player)
	end
end

local function awardFor(player: Player): TrainingStationRules.AwardFunction
	return function(lift: string, elapsedSeconds: number)
		return PlayerDataService.awardTrainingProgression(player, lift, elapsedSeconds)
	end
end

local function aliveHumanoid(character: Model?): Humanoid?
	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end

	return humanoid
end

--[[
	Where a player stands to use this rack: the top centre of a Part, or the
	pivot of a Model. Read live, so a moved rack is measured where it is now.
]]
local function standPosition(station: Station): Vector3?
	local instance = station.instance

	if instance:IsA("BasePart") then
		return instance.Position + Vector3.new(0, instance.Size.Y / 2, 0)
	end

	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end

	return nil
end

--[[
	Gathers the facts about where the player really is, on the SERVER, and
	lets TrainingStationRules judge them. Nothing the client says is used.
]]
local function presenceFailure(player: Player, station: Station): TrainingStationRules.PresenceFailure?
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local stand = standPosition(station)

	local distance: number? = nil
	if rootPart ~= nil and rootPart:IsA("BasePart") and stand ~= nil then
		distance = (rootPart.Position - stand).Magnitude
	end

	return TrainingStationRules.presenceFailure({
		inGame = player.Parent == Players,
		dataReady = PlayerDataService.isReady(player),
		hasCharacter = character ~= nil and rootPart ~= nil,
		alive = aliveHumanoid(character) ~= nil,
		distance = distance,
		radius = TrainingStationConfig.PresenceRadiusStuds,
	})
end

--------------------------------------------------------------------------------
-- DISPLAY
--------------------------------------------------------------------------------

local function stationTitle(station: Station): string
	return string.format("Training Rack %s", string.sub(station.stationId, -1))
end

local function refreshSign(station: Station)
	local occupant = TrainingStationRules.occupantOf(registry, station.stationId)
	local session = if occupant ~= nil then TrainingStationRules.sessionOf(registry, occupant) else nil

	if occupant == nil or session == nil then
		station.statusLabel.Text = string.format("%s\nFree\nHold [E] to train", stationTitle(station))
		return
	end

	station.statusLabel.Text = string.format(
		"%s \u{2014} %s\n%s",
		stationTitle(station),
		(occupant :: Player).Name,
		TrainingStationRules.statusLine(session)
	)
end

--[[
	Tells one player's client what to show. `notice` is a one-off message.
]]
local function sendState(player: Player, notice: string?)
	local set = remotes
	if set == nil or player.Parent ~= Players then
		return
	end

	local session = TrainingStationRules.sessionOf(registry, player)
	local selection = if session then session.selection else nil
	local data = PlayerDataService.getData(player)
	local now = os.time()

	local evToday: number? = nil
	local liftHours: { [string]: number }? = nil

	if data ~= nil then
		local evRead, spent = pcall(TrainingAllowance.spentToday, data.cnAllowance, now)
		evToday = if evRead then spent else nil

		local hours: { [string]: number } = {}
		for _, lift in ipairs(ProgressionConfig.Lifts) do
			local hoursRead, value = pcall(TrainingAllowance.hoursOnLift, data.trainingTimeToday, lift, now)
			if hoursRead then
				hours[lift] = value
			end
		end
		liftHours = hours
	end

	local state: TrainingRemotes.MenuState = {
		open = session ~= nil and session.menuOpen,
		occupying = session ~= nil,
		stationId = if session then session.stationId else nil,
		sessionState = if session then session.state else nil,
		mode = if selection then selection.mode else nil,
		lift = if selection then selection.lift else nil,
		primary = if selection then selection.primary else nil,
		statusLine = TrainingStationRules.statusLine(session),
		notice = notice,
		cnAvailable = readCN(player) == "Available",
		evToday = evToday,
		evCap = ProgressionConfig.DailyTraining.DailyCapEV,
		liftHoursToday = liftHours,
	}

	set.menuState:FireClient(player, state)
end

local CAP_NOTICE = TrainingStationRules.CAP_REACHED_MESSAGE .. "\n" .. TrainingStationRules.CAP_REACHED_HINT

local MENU_REFUSAL_TEXT: { [string]: string } = {
	InvalidStation = "That is not a training rack.",
	UnknownStation = "That is not a training rack.",
	AtAnotherStation = "You are already using another rack. Stop training there first.",
	StationOccupied = "Someone is already using this rack.",
	NotPresent = "Stand at the rack to use it.",
}

--------------------------------------------------------------------------------
-- OCCUPANCY
--------------------------------------------------------------------------------

local function disconnectOccupant(player: Player)
	local connections = occupantConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		occupantConnections[player] = nil
	end
end

local function afterRelease(player: Player, stationId: string?, reason: string, notice: string?)
	disconnectOccupant(player)

	if stationId == nil then
		return
	end

	local station = stations[stationId]
	if station then
		refreshSign(station)
	end

	sendState(player, notice)
	log("%s left %s (%s)", player.Name, stationId, reason)
end

--[[
	Takes the player off their rack WITHOUT crediting the unfinished interval.
	Safe to call when they hold no rack.
]]
local function endTraining(player: Player, reason: string, notice: string?)
	afterRelease(player, TrainingStationRules.release(registry, player), reason, notice)
end

--[[
	Ends the occupancy the moment the character dies or is removed (respawn,
	reset, leaving). The next tick would catch it too; this is just faster.
]]
local function watchCharacter(player: Player)
	disconnectOccupant(player)

	local connections: { RBXScriptConnection } = {}

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil

	if humanoid then
		table.insert(connections, humanoid.Died:Connect(function()
			endTraining(player, "died")
		end))
	end

	table.insert(connections, player.CharacterRemoving:Connect(function()
		endTraining(player, "character removed")
	end))

	occupantConnections[player] = connections
end

local function logCredit(player: Player, report: TrainingStationRules.CreditReport)
	local result = report.result
	if typeof(result) ~= "table" then
		log("%s tick: %.1f s measured, %s %s, %s, nothing credited",
			player.Name, report.measuredSeconds, tostring(report.mode), tostring(report.lift), report.status)
		return
	end

	log(
		"%s %s tick: %.1f s credited, %s, +%.5f EV, CN %.3f -> %.3f%s",
		player.Name,
		tostring(report.lift),
		report.creditedSeconds,
		tostring(result.outcome),
		result.earnedEV or 0,
		result.competitionNumberBefore or 0,
		result.competitionNumberAfter or 0,
		if report.stoppedAtCap then " (DAILY CN CAP REACHED -- TRAINING STOPPED)" else ""
	)
end

--[[
	Handles a settlement: ends the occupancy on a fatal gateway result.
	Returns false if the player no longer holds a rack.
]]
local function handleCredit(player: Player, report: TrainingStationRules.CreditReport): boolean
	if report.status == "Credited" and TrainingStationRules.isFatalResult(report.result) then
		local reason = if typeof(report.result) == "table"
			then tostring(report.result.rejectionReason)
			else "no active data session"
		endTraining(player, "training rejected: " .. reason, "Training is unavailable right now.")
		return false
	end

	return true
end

--[[
	Rate limit shared by the prompt and the remote. Returns false to ignore.
]]
local function allowRequest(player: Player): boolean
	local allowed = TrainingStationRules.allowRequest(
		limiter,
		player,
		os.clock(),
		TrainingStationConfig.RequestLimit,
		TrainingStationConfig.RequestWindowSeconds
	)

	if allowed then
		rateLimitLogged[player] = nil
	elseif not rateLimitLogged[player] then
		rateLimitLogged[player] = true
		log("%s is sending too many training requests; ignoring them for a moment", player.Name)
	end

	return allowed
end

--------------------------------------------------------------------------------
-- THE PROMPT: AUTHORIZING THE MENU
--------------------------------------------------------------------------------

local function onPromptTriggered(player: Player, station: Station)
	if not allowRequest(player) then
		return
	end

	-- The rack may have been unregistered while the prompt still existed.
	if stations[station.stationId] ~= station then
		return
	end

	local presence: TrainingStationRules.PresenceFailure? = presenceFailure(player, station)
	local refusal = TrainingStationRules.menuRefusal(registry, player, station.stationId, presence)
	if refusal ~= nil then
		log("%s refused at %s: %s%s", player.Name, station.stationId, refusal,
			if presence then " (" .. presence .. ")" else "")
		sendState(player, MENU_REFUSAL_TEXT[refusal] or "You cannot use this rack right now.")
		return
	end

	local reserving = TrainingStationRules.sessionOf(registry, player) == nil

	if reserving then
		--[[
			A ZERO-SECOND CHECK through the real gateway before reserving. It
			earns nothing; it only confirms this player can train at all (for
			example, a weight class with no Progression Reference is refused
			here once, with a reason). A successful check writes at most a day
			rollover.
		]]
		local check = PlayerDataService.awardTrainingProgression(player, ProgressionConfig.Lifts[1], 0)
		if TrainingStationRules.isFatalResult(check) then
			log("%s refused at %s: cannot train (%s)", player.Name, station.stationId,
				if check then tostring(check.rejectionReason) else "no active data session")
			sendState(player, "Training is unavailable for your profile right now.")
			return
		end
	end

	local openRefusal, outcome = TrainingStationRules.openMenu(registry, player, station.stationId, presence, os.clock())
	if openRefusal ~= nil then
		sendState(player, MENU_REFUSAL_TEXT[openRefusal])
		return
	end

	if outcome == "Reserved" then
		watchCharacter(player)
		log("%s reserved %s", player.Name, station.stationId)
	end

	refreshSign(station)

	local session = TrainingStationRules.sessionOf(registry, player)
	sendState(player, if session and session.state == "StoppedAtCNCap" then CAP_NOTICE else nil)
end

--------------------------------------------------------------------------------
-- THE REMOTE: MENU REQUESTS
--------------------------------------------------------------------------------

local SELECT_NOTICE: { [string]: string } = {
	Cooldown = "Please wait a moment before changing again.",
	CNCapReached = CAP_NOTICE,
	CNUnavailable = "Competition Number training is unavailable right now.",
	Invalid = "That training choice is not valid.",
	NotAuthorized = "Hold E at a rack to open the menu.",
}

local function onStart(player: Player, session: TrainingStationRules.Session, selection: TrainingStationRules.Selection)
	local station = stations[session.stationId]

	local report = TrainingStationRules.selectTraining(
		registry,
		player,
		selection,
		os.clock(),
		TrainingStationConfig.SelectionCooldownSeconds,
		TrainingStationConfig.MaxCreditSecondsPerTick,
		cnReaderFor(player),
		awardFor(player)
	)

	local credit = report.credit
	if credit then
		logCredit(player, credit)
		if not handleCredit(player, credit) then
			return
		end
	end

	local notice: string? = SELECT_NOTICE[report.decision]

	if report.decision == "Started" then
		log("%s started %s %s%s on %s", player.Name, selection.mode, selection.lift,
			if selection.primary then " (" .. selection.primary .. ")" else "", session.stationId)
		if selection.mode == "Technique" then
			notice = TrainingStationRules.TECHNIQUE_PENDING_MESSAGE
		end
	elseif report.decision ~= "Unchanged" then
		log("%s selection refused: %s", player.Name, report.decision)
	end

	if station then
		refreshSign(station)
	end

	sendState(player, notice)
end

local function onMenuRequest(player: Player, ...: any)
	if not allowRequest(player) then
		return
	end

	local argumentCount = select("#", ...)
	local action, payload = ...

	local request, refusal = TrainingStationRules.parseRequest(action, payload, argumentCount)
	if request == nil then
		log("%s sent an invalid training request: %s", player.Name, tostring(refusal))
		sendState(player, SELECT_NOTICE.Invalid)
		return
	end

	local session = TrainingStationRules.sessionOf(registry, player)

	if request.action == "Close" then
		local closed = TrainingStationRules.closeMenu(registry, player)
		if closed == "Released" then
			afterRelease(player, session and session.stationId, "closed the menu without training")
		else
			sendState(player)
		end
		return
	end

	if session == nil then
		log("%s sent %s without holding a rack", player.Name, request.action)
		sendState(player, SELECT_NOTICE.NotAuthorized)
		return
	end

	local station = stations[session.stationId]
	if station == nil then
		endTraining(player, "station missing")
		return
	end

	-- Every request re-checks presence on the server. Absent: leave, no credit.
	local presence: TrainingStationRules.PresenceFailure? = presenceFailure(player, station)
	if presence ~= nil then
		endTraining(player, presence, MENU_REFUSAL_TEXT.NotPresent)
		return
	end

	if request.action == "Stop" then
		local stationId, credit = TrainingStationRules.stopTraining(
			registry,
			player,
			os.clock(),
			true,
			TrainingStationConfig.MaxCreditSecondsPerTick,
			cnReaderFor(player),
			awardFor(player)
		)
		if credit then
			logCredit(player, credit)
		end
		afterRelease(player, stationId, "stopped")
		return
	end

	local selection = request.selection
	if selection then
		onStart(player, session, selection)
	end
end

--------------------------------------------------------------------------------
-- THE TICK
--------------------------------------------------------------------------------

local function tickOccupants()
	local now = os.clock()

	-- Snapshot first: endTraining removes entries while we go.
	local occupants: { Player } = {}
	for playerKey in pairs(registry.sessionByPlayer) do
		table.insert(occupants, playerKey :: Player)
	end

	for _, player in ipairs(occupants) do
		local session = TrainingStationRules.sessionOf(registry, player)
		local station = if session then stations[session.stationId] else nil

		if session == nil or station == nil then
			endTraining(player, "station missing")
			continue
		end

		local failure = presenceFailure(player, station)
		if failure ~= nil then
			endTraining(player, failure)
			continue
		end

		local report = TrainingStationRules.creditSession(
			registry,
			player,
			now,
			TrainingStationConfig.MaxCreditSecondsPerTick,
			cnReaderFor(player),
			awardFor(player)
		)

		if report.status == "Credited" or report.status == "CNCapReached" or report.status == "CNUnavailable" then
			logCredit(player, report)
		end

		if handleCredit(player, report) then
			refreshSign(station)
			sendState(player, if report.stoppedAtCap then CAP_NOTICE else nil)
		end
	end
end

local function runTick()
	-- One loop and no yields inside, so this guard should never trip. It stays
	-- so a future yield cannot quietly create overlapping ticks.
	if ticking then
		warn("[TrainingStationService] tick skipped: the previous tick is still running")
		return
	end

	ticking = true
	local ok, err = pcall(function()
		tickOccupants()
	end)
	ticking = false

	if not ok then
		warn("[TrainingStationService] tick errored: " .. tostring(err))
	end
end

--------------------------------------------------------------------------------
-- RACK REGISTRATION
--------------------------------------------------------------------------------

local function makeStatusSign(parent: Instance): (BillboardGui, TextLabel)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TrainingStatus"
	billboard.Size = UDim2.fromOffset(340, 80)
	billboard.StudsOffset = Vector3.new(0, 7, 0)
	billboard.MaxDistance = 80
	billboard.AlwaysOnTop = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.TextScaled = true
	label.Font = Enum.Font.GothamMedium
	label.Text = ""
	label.Parent = billboard

	billboard.Parent = parent
	return billboard, label
end

--[[
	Makes a tagged Part or Model a rack. Every rack gets the same single prompt
	and the same rules; nothing here is specific to one rack.
]]
local function registerStation(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		warn("[TrainingStationService] ignoring tagged " .. instance.ClassName .. " " .. instance:GetFullName()
			.. ": a rack must be a Part or a Model")
		return
	end

	local stationId = instance:GetAttribute("StationId")
	if typeof(stationId) ~= "string" or stationId == "" then
		warn("[TrainingStationService] ignoring " .. instance:GetFullName() .. ": it has no StationId attribute")
		return
	end

	if not TrainingStationRules.registerStation(registry, stationId) then
		warn("[TrainingStationService] ignoring " .. instance:GetFullName() .. ": duplicate StationId " .. stationId)
		return
	end

	local promptParent: Instance = instance
	if instance:IsA("Model") then
		promptParent = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true) or instance
	end

	local promptAnchor = Instance.new("Attachment")
	promptAnchor.Name = "TrainingPromptAnchor"
	promptAnchor.Position = Vector3.new(0, 3, 0)
	promptAnchor.Parent = promptParent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainingPrompt"
	prompt.ActionText = "Train"
	prompt.ObjectText = "Training Rack"
	prompt.KeyboardKeyCode = TrainingStationConfig.PromptKeyboardKey
	prompt.GamepadKeyCode = TrainingStationConfig.PromptGamepadKey
	prompt.HoldDuration = TrainingStationConfig.PromptHoldSeconds
	prompt.MaxActivationDistance = TrainingStationConfig.PromptMaxDistanceStuds
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor

	local sign, label = makeStatusSign(promptParent)

	local station: Station = {
		stationId = stationId,
		instance = instance,
		prompt = prompt,
		sign = sign,
		statusLabel = label,
	}
	stations[stationId] = station

	prompt.Triggered:Connect(function(player: Player)
		onPromptTriggered(player, station)
	end)

	refreshSign(station)
	log("registered rack %s", stationId)
end

--[[
	The tag was removed or the rack destroyed. Its occupant is released on the
	next tick ("station missing"), without credit.
]]
local function unregisterStation(instance: Instance)
	for stationId, station in pairs(stations) do
		if station.instance == instance then
			stations[stationId] = nil
			TrainingStationRules.unregisterStation(registry, stationId)
			local anchor = station.prompt.Parent
			if anchor then
				anchor:Destroy()
			end
			station.sign:Destroy()
			log("unregistered rack %s", stationId)
		end
	end
end

--------------------------------------------------------------------------------
-- START
--------------------------------------------------------------------------------

--[[
	Creates the remotes, builds the placeholder racks, registers every tagged
	rack and starts the tick loop. Call once, from the server entry point,
	AFTER PlayerDataService.start().
]]
function TrainingStationService.start()
	assert(not started, "[TrainingStationService] start() must only be called once")
	started = true

	local set = TrainingRemotes.createOnServer(ReplicatedStorage)
	remotes = set
	set.menuRequest.OnServerEvent:Connect(onMenuRequest)

	PlaceholderStations.build(TrainingStationConfig.PlaceholderStations, TrainingStationConfig.StationTag)

	local tag = TrainingStationConfig.StationTag
	CollectionService:GetInstanceAddedSignal(tag):Connect(registerStation)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(unregisterStation)
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		registerStation(instance)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		endTraining(player, "left the game")
		TrainingStationRules.forgetRequester(limiter, player)
		rateLimitLogged[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TrainingStationConfig.TickSeconds)
			runTick()
		end
	end)

	log("started, ticking every %d s", TrainingStationConfig.TickSeconds)
end

return TrainingStationService
