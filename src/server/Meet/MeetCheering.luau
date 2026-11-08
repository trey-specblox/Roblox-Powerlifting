--!strict
--[[
	MeetCheering
	Server / Meet

	Cheering at the big meets (GAME_DESIGN.md §36.4 "Cheering", user 2026-11-08;
	numbers in CheerConfig). Invisible zones (StateArenaVenue): each rack has one in the
	stands in front of it for spectators, and the whole meet area is the lifters' zone,
	where each picks which rack's lifter to cheer for (one at a time). While a lifter is
	up, anyone cheering for them sees a bar, "CHEER FOR <name>", and cheering through
	voice chat fills it. When it is full
	the rest of the lift is easier (a second discount on the lifter's own gear
	Technique, CheerConfig.bonusFor), and if the lift is good everyone who helped gets
	the lift's GL points in coins.

	TRUST: Roblox measures a voice's loudness only on that player's own device; the
	server hears nothing. So the server takes a cheerer's word for how loud they were,
	but only from someone standing in a zone of a rack whose lifter is up, who has voice
	chat and isn't that lifter, at most about 4 times a second and never more than
	full voice. Coins only come from a real good lift by someone else, at a meet that
	pays. A cheater could still fake being loud for a friend: that is the limit of voice
	(GAME_DESIGN §36.2).

	PERFORMANCE: every TickSeconds, a point-in-box test per player against at most 8
	zones, and a small message to a player only when their bar changes.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VoiceChatService = game:GetService("VoiceChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CheerConfig = require(Shared:WaitForChild("Config"):WaitForChild("CheerConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))
local MeetPlacing = require(Shared:WaitForChild("Meet"):WaitForChild("MeetPlacing"))
local GearStats = require(Shared:WaitForChild("Economy"):WaitForChild("GearStats"))

local ServerFolder = script.Parent.Parent
local PlayerDataService = require(ServerFolder:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))

local MeetCheering = {}

-- The source name the bonus goes by in a lift's modifiers (LiftAttemptService.setPhaseBoost).
local SOURCE_NAME = "Cheering"

type Turn = {
	rack: number,
	lifter: Player,
	name: string,
	lift: string,
	bodyweightKg: number,
	-- Whether this meet pays coins.
	rewards: boolean,
	fill: number,
	full: boolean,
	-- Full-voice seconds since the last tick, and in all this attempt, per cheerer.
	pending: { [Player]: number },
	helped: { [Player]: number },
	paid: boolean,
	-- "GOOD LIFT" or "NO LIFT" once the lift is over (the bar shows it until the turn ends).
	verdict: string?,
	onFull: (() -> ())?,
}

local remotes: LocalMeetRemotes.RemoteSet? = nil
-- The lifter up on each rack, by rack index.
local turns: { [number]: Turn } = {}
local byLifter: { [Player]: Turn } = {}
-- The turn whose zone each player stood in at the last tick.
local standingIn: { [Player]: Turn } = {}
local lastReportAt: { [Player]: number } = {}
-- In the lifters' zone: the rack each player picked to cheer for.
local pickedRack: { [Player]: number } = {}
-- Whether each player has voice chat (nil: not known yet).
local voiceOf: { [Player]: boolean } = {}
local checkingVoice: { [Player]: boolean } = {}
-- The last view sent to each player, as a short key, so nothing is sent twice.
local lastSent: { [Player]: string } = {}

local function send(player: Player, view: LocalMeetRemotes.CheerView)
	local set = remotes
	if set and player.Parent then
		set.cheerState:FireClient(player, view)
	end
end

-- Whether the player has voice chat, asked once (Studio has none, so there everyone counts, for testing).
local function hasVoice(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	local known = voiceOf[player]
	if known ~= nil then
		return known
	end
	if not checkingVoice[player] then
		checkingVoice[player] = true
		task.spawn(function()
			local ok, enabled = pcall(function()
				return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
			end)
			if player.Parent then
				voiceOf[player] = ok and enabled == true
			end
			checkingVoice[player] = nil
		end)
	end
	return false
end

-- The rack whose zone holds this point (nil for none), or true for the lifters' zone, where each picks.
local function zoneAt(point: Vector3): (number | boolean)?
	for _, zone in ipairs(CollectionService:GetTagged(CheerConfig.ZoneTag)) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(workspace) then
			local seen = zone.CFrame:PointToObjectSpace(point)
			local half = zone.Size / 2
			if math.abs(seen.X) <= half.X and math.abs(seen.Y) <= half.Y and math.abs(seen.Z) <= half.Z then
				if zone:GetAttribute(CheerConfig.ZoneChoiceAttribute) == true then
					return true
				end
				local rack = zone:GetAttribute(CheerConfig.ZoneRackAttribute)
				if typeof(rack) == "number" then
					return rack
				end
			end
		end
	end
	return nil
end

-- The lifters up now that `player` could cheer for, by rack: never their own turn.
local function choicesFor(player: Player): { Turn }
	local list: { Turn } = {}
	if byLifter[player] then
		return list
	end
	for _, turn in pairs(turns) do
		table.insert(list, turn)
	end
	table.sort(list, function(a, b)
		return a.rack < b.rack
	end)
	return list
end

-- In the lifters' zone: the lifter `player` cheers for (their pick if still up, else the first), its place and how many there are.
local function pickedTurn(player: Player): (Turn?, number, number)
	local list = choicesFor(player)
	for index, turn in ipairs(list) do
		if turn.rack == pickedRack[player] then
			return turn, index, #list
		end
	end
	if list[1] then
		pickedRack[player] = list[1].rack
	end
	return list[1], 1, #list
end

-- The lifter's own gear Technique on this lift, as their lift's modifiers count it (GearStats.producer).
local function gearTechnique(player: Player, lift: string): number
	local data = PlayerDataService.getData(player)
	if data == nil then
		return 0
	end
	return GearStats.techniqueBonus(GearStats.wornRarities((data :: any).inventory), lift)
end

local function fillUp(turn: Turn)
	turn.fill, turn.full = 1, true
	send(turn.lifter, { role = "lifter", name = turn.name, bonus = CheerConfig.bonusFor(gearTechnique(turn.lifter, turn.lift)) })
	print(string.format("[MeetCheering] the crowd filled %s's bar on rack %d", turn.name, turn.rack))
	if turn.onFull then
		task.spawn(turn.onFull)
	end
end

local function tick(dt: number)
	-- The bars.
	for _, turn in pairs(turns) do
		if not turn.full then
			local loud = 0
			for _, seconds in pairs(turn.pending) do
				loud += seconds
			end
			table.clear(turn.pending)
			if loud > 0 then
				turn.fill += math.min(loud / CheerConfig.FillSecondsAlone, CheerConfig.MaxFillPerSecond * dt)
			else
				turn.fill = math.max(0, turn.fill - CheerConfig.DrainPerSecond * dt)
			end
			if turn.fill >= 1 then
				fillUp(turn)
			end
		end
	end
	-- Who stands where, and what their bar shows.
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local zone = if root and root:IsA("BasePart") then zoneAt(root.Position) else nil
		local turn: Turn? = nil
		local choice, choices = 0, 0
		if zone == true then
			turn, choice, choices = pickedTurn(player)
		elseif typeof(zone) == "number" then
			turn = turns[zone]
		end
		if turn and turn.lifter == player then
			turn = nil
		end
		standingIn[player] = turn
		local view: LocalMeetRemotes.CheerView = { role = "none" }
		local key = "none"
		if turn then
			local voice = hasVoice(player)
			-- (The fill in steps of 2%, rounded down so it only shows full when it is, and a slowly draining bar doesn't send every tick.)
			local fill = if turn.full then 1 else math.floor(turn.fill * 50) / 50
			view = { role = "cheer", name = turn.name, fill = fill, full = turn.full, voice = voice, result = turn.verdict,
				choice = if choices > 1 then choice else nil, choices = if choices > 1 then choices else nil }
			key = string.format("cheer|%d|%s|%.2f|%s|%s|%s|%d/%d", turn.rack, turn.name, fill, tostring(turn.full), tostring(voice),
				turn.verdict or "", choice, choices)
		end
		if lastSent[player] ~= key then
			lastSent[player] = key
			send(player, view)
		end
	end
end

-- A cheerer's device: how loud (0..1) they were since its last report.
local function onReport(player: Player, loudness: unknown)
	if typeof(loudness) ~= "number" or loudness ~= loudness then
		return
	end
	local turn = standingIn[player]
	if turn == nil or turn.lifter == player or turns[turn.rack] ~= turn or turn.verdict or not hasVoice(player) then
		return
	end
	local now = os.clock()
	local last = lastReportAt[player]
	if last and now - last < CheerConfig.MinReportGapSeconds then
		return
	end
	lastReportAt[player] = now
	local span = if last then math.min(now - last, CheerConfig.MaxReportSpanSeconds) else CheerConfig.ReportSeconds
	local seconds = math.clamp(loudness :: number, 0, 1) * span
	if seconds <= 0 then
		return
	end
	turn.pending[player] = (turn.pending[player] or 0) + seconds
	turn.helped[player] = (turn.helped[player] or 0) + seconds
end

-- In the lifters' zone: cheer for the next (+1) or previous (-1) lifter up. Takes effect at the next tick.
local function onChoose(player: Player, step: unknown)
	if typeof(step) ~= "number" or (step ~= 1 and step ~= -1) then
		return
	end
	local list = choicesFor(player)
	if #list < 2 then
		return
	end
	local _, index = pickedTurn(player)
	pickedRack[player] = list[(index - 1 + (step :: number)) % #list + 1].rack
end

--[[
	`lifter` is up on rack `rack` (their turn starts as they chalk up): the rack's zones
	cheer for them until closeTurn. `rewards`: whether this meet pays coins. `onFull` is
	called once if the crowd fills the bar (the meet's crowd roars).
]]
function MeetCheering.openTurn(rack: number, lifter: Player, name: string, lift: string, bodyweightKg: number, rewards: boolean,
	onFull: (() -> ())?)
	MeetCheering.closeTurn(lifter)
	local old = turns[rack]
	if old then
		MeetCheering.closeTurn(old.lifter)
	end
	local turn: Turn = {
		rack = rack,
		lifter = lifter,
		name = name,
		lift = lift,
		bodyweightKg = bodyweightKg,
		rewards = rewards,
		fill = 0,
		full = false,
		pending = {},
		helped = {},
		paid = false,
		verdict = nil,
		onFull = onFull,
	}
	turns[rack] = turn
	byLifter[lifter] = turn
end

--[[
	The lifter's attempt ended. A good lift with a full bar pays everyone who cheered at
	least HelperSeconds into it the lift's GL points in coins (user 2026-11-08), once.
]]
function MeetCheering.result(lifter: Player, good: boolean, weightKg: number)
	local turn = byLifter[lifter]
	if turn == nil or turn.paid then
		return
	end
	turn.paid = true
	turn.verdict = if good then "GOOD LIFT" else "NO LIFT"
	if not (good and turn.full and turn.rewards) then
		return
	end
	local coins = math.floor((MeetPlacing.points(turn.bodyweightKg, weightKg) or 0) + 0.5)
	if coins <= 0 then
		return
	end
	for cheerer, seconds in pairs(turn.helped) do
		if cheerer ~= lifter and cheerer.Parent and seconds >= CheerConfig.HelperSeconds then
			local outcome = PlayerDataService.addCoins(cheerer, coins, "cheered " .. turn.name)
			if outcome == "Added" then
				send(cheerer, { role = "coins", name = turn.name, coins = coins })
			end
		end
	end
end

-- The lifter's turn is over: their rack's zones go quiet. Safe to call for anyone.
function MeetCheering.closeTurn(lifter: Player)
	local turn = byLifter[lifter]
	if turn == nil then
		return
	end
	byLifter[lifter] = nil
	if turns[turn.rack] == turn then
		turns[turn.rack] = nil
	end
end

-- The meet is over: every rack goes quiet.
function MeetCheering.closeAll()
	for lifter in pairs(byLifter) do
		MeetCheering.closeTurn(lifter)
	end
end

--[[
	LiftAttemptService asks this as each phase of a lift starts: the extra technique for
	`player` whose gear gives `gear` on the lift. 0 unless the crowd filled their bar.
]]
local function boostFor(player: Player, gear: number): number
	local turn = byLifter[player]
	return if turn and turn.full then CheerConfig.bonusFor(gear) else 0
end

function MeetCheering.start(set: LocalMeetRemotes.RemoteSet)
	if remotes then
		return
	end
	remotes = set
	set.cheerReport.OnServerEvent:Connect(onReport)
	set.cheerChoose.OnServerEvent:Connect(onChoose)
	LiftAttemptService.setPhaseBoost(SOURCE_NAME, boostFor)
	Players.PlayerRemoving:Connect(function(player)
		MeetCheering.closeTurn(player)
		standingIn[player], lastReportAt[player], voiceOf[player], checkingVoice[player], lastSent[player] = nil, nil, nil, nil, nil
		pickedRack[player] = nil
		for _, turn in pairs(turns) do
			turn.pending[player], turn.helped[player] = nil, nil
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(CheerConfig.TickSeconds)
			local now = os.clock()
			tick(math.min(now - last, 1))
			last = now
		end
	end)
end

return MeetCheering
