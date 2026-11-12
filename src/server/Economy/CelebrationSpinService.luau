--!strict
--[[
	CelebrationSpinService
	Server / Economy

	The celebration spin (CelebrationConfig.Spin, GAME_DESIGN §36.4; user 2026-11-11): the placeholder NPC in the gym's
	dumbbell corner, and the spins bought from it.

		- RoomProps leaves a spot tagged Spin.spotTag where a flat bench used to be; the NPC (a plain R15 avatar made
		  from a HumanoidDescription: never a real player's) stands there, idling, and shows off a celebration now and
		  then while someone is near. Holding E on it opens the client's spin screen (CelebrationSpinner).
		- GetSpinner answers the player's coins and celebration (read only).
		- SpinCelebration: one spin, of a celebration or a walk-out (EntranceConfig; user 2026-11-11: "Walk-outs at Hype
		  Man", same rules: a reroll of the walk-out they use). Checked here: not too fast, standing by the NPC; then the roll is the server's
		  (the gear crates' rarity odds, then a celebration of that rarity) and PlayerDataService.spinCelebration takes
		  the coins, makes it theirs and gives the duplicate refund, all in one step. The client only asks.

	PERFORMANCE: one avatar with an idle loop, its show-off only while a player is within SHOW_OFF_RANGE.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local CelebrationConfig = require(ConfigFolder:WaitForChild("CelebrationConfig"))
local EntranceConfig = require(ConfigFolder:WaitForChild("EntranceConfig"))
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local CelebrationRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("CelebrationRemotes"))

local ServerFolder = script.Parent.Parent
local PlayerDataService = require(ServerFolder:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local CelebrationService = require(ServerFolder:WaitForChild("Meet"):WaitForChild("CelebrationService"))
local MeetFigures = require(ServerFolder:WaitForChild("Meet"):WaitForChild("MeetFigures"))

local CelebrationSpinService = {}

local SPIN = CelebrationConfig.Spin
local MIN_SECONDS_BETWEEN_ASKS = 0.4
-- The NPC shows off one of the celebrations about this often, while a player is within SHOW_OFF_RANGE studs.
local SHOW_OFF_EVERY = 18
local SHOW_OFF_RANGE = 40
-- The NPC's look: fixed, so it is always recognisable (bright top, props colour variety; hair from the computer
-- lifters' free Roblox hair).
local NPC_SKIN = Color3.fromRGB(198, 145, 105)
local NPC_TOP = Color3.fromRGB(240, 120, 30)
local NPC_TROUSERS = Color3.fromRGB(35, 35, 40)
local NPC_HAIR = LocalMeetConfig.ComputerLifters.Hair[1]

local started = false
local lastAsked: { [Player]: number } = {}
local npcs: { Model } = {}
local random = Random.new()

local function root(player: Player): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if part and part:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return part
	end
	return nil
end

local function nearNpc(player: Player, range: number): boolean
	local body = root(player)
	if body == nil then
		return false
	end
	for _, npc in ipairs(npcs) do
		if npc.Parent and (npc:GetPivot().Position - body.Position).Magnitude <= range then
			return true
		end
	end
	return false
end

local function tooFast(player: Player): boolean
	local now = os.clock()
	if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
		return true
	end
	lastAsked[player] = now
	return false
end

local function viewFor(player: Player): CelebrationRemotes.SpinView?
	local coins = PlayerDataService.getCoins(player)
	if coins == nil then
		return nil
	end
	return { coins = coins, current = PlayerDataService.getCelebration(player), entrance = PlayerDataService.getEntrance(player) }
end

-- Everything a spin of `kind` can land on: id -> rarity (never a Default).
local function poolOf(kind: string): { { id: string, rarity: string } }
	local out = {}
	if kind == "Entrance" then
		for _, id in ipairs(EntranceConfig.Order) do
			local entrance = EntranceConfig.Entrances[id]
			if entrance.rarity ~= "Default" then
				table.insert(out, { id = id, rarity = entrance.rarity })
			end
		end
	else
		for _, celebration in ipairs(CelebrationConfig.List) do
			if celebration.rarity ~= "Default" then
				table.insert(out, { id = celebration.id, rarity = celebration.rarity })
			end
		end
	end
	return out
end

-- The ones of one rarity.
local function ofRarity(kind: string, rarity: string): { string }
	local out = {}
	for _, entry in ipairs(poolOf(kind)) do
		if entry.rarity == rarity then
			table.insert(out, entry.id)
		end
	end
	return out
end

-- The roll: a rarity with the gear crates' odds (or `forced`), then one of its celebrations at random.
local function roll(kind: string, forced: string?): string
	local rarity: string? = nil
	if typeof(forced) == "string" and #ofRarity(kind, forced) > 0 then
		rarity = forced
	else
		local total = 0
		for _, entry in ipairs(GearStatsConfig.Rarities) do
			total += entry.odds
		end
		local pick = random:NextNumber() * total
		for _, entry in ipairs(GearStatsConfig.Rarities) do
			pick -= entry.odds
			if pick <= 0 then
				rarity = entry.id
				break
			end
		end
	end
	local pool = ofRarity(kind, rarity or "Common")
	if #pool == 0 then
		-- (A rarity with none yet: any one but the Default.)
		for _, entry in ipairs(poolOf(kind)) do
			table.insert(pool, entry.id)
		end
	end
	return pool[random:NextInteger(1, #pool)]
end

local function spin(player: Player, kind: string): (boolean, string, CelebrationRemotes.SpinView?, string?, number)
	if not nearNpc(player, SPIN.maxSpinDistanceStuds) then
		return false, "Come back to " .. SPIN.npcName .. " to spin.", nil, nil, 0
	end
	-- Studio only: the workspace attribute StudioCelebrationRarity forces the rarity, to see every landing.
	local forced: any = nil
	if RunService:IsStudio() then
		forced = Workspace:GetAttribute("StudioCelebrationRarity")
	end
	local resultId = roll(kind, forced)
	local spinOf = if kind == "Entrance" then PlayerDataService.spinEntrance else PlayerDataService.spinCelebration
	local outcome, _, refund = spinOf(player, SPIN.price, resultId, SPIN.duplicateRefund)
	local view = viewFor(player)
	if outcome == "Spun" then
		return true, "", view, resultId, refund
	elseif outcome == "NotEnough" then
		return false, "Not enough coins yet. Earn them at official meets.", view, nil, 0
	end
	return false, "That spin didn't go through. Try again.", view, nil, 0
end

local function loadTrack(model: Model, id: string): AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	return if ok then track :: AnimationTrack else nil
end

-- Now and then, while a player is near, the NPC does one of the celebrations (any rarity), so players see what's in it.
local function showOff(npc: Model)
	local all = {}
	for _, celebration in ipairs(CelebrationConfig.List) do
		table.insert(all, celebration.id)
	end
	task.spawn(function()
		while npc.Parent do
			task.wait(SHOW_OFF_EVERY + random:NextNumber() * 6)
			local near = false
			for _, player in ipairs(Players:GetPlayers()) do
				local body = root(player)
				if body and (body.Position - npc:GetPivot().Position).Magnitude <= SHOW_OFF_RANGE then
					near = true
					break
				end
			end
			if near and npc.Parent then
				local seconds = CelebrationService.play(npc, all[random:NextInteger(1, #all)], nil)
				task.wait(seconds)
			end
		end
	end)
end

local function buildNpc(spot: Instance, remotes: CelebrationRemotes.SpinRemotes)
	if not spot:IsA("BasePart") or spot:GetAttribute("NpcBuilt") then
		return
	end
	spot:SetAttribute("NpcBuilt", true)
	local ok, made = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = NPC_SKIN
		description.LeftArmColor = NPC_SKIN
		description.RightArmColor = NPC_SKIN
		description.TorsoColor = NPC_TOP
		description.LeftLegColor = NPC_TROUSERS
		description.RightLegColor = NPC_TROUSERS
		description.HairAccessory = tostring(NPC_HAIR)
		description.WidthScale = 1.15
		description.DepthScale = 1.15
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(made) ~= "Instance" or not made:IsA("Model") then
		warn("[CelebrationSpinService] no NPC could be made: " .. tostring(made))
		return
	end
	local npc = made :: Model
	npc.Name = "CelebrationNpc"
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local body = npc:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or body == nil or not body:IsA("BasePart") then
		npc:Destroy()
		return
	end
	humanoid.DisplayName = SPIN.npcName
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 30
	humanoid.BreakJointsOnDeath = false
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Only the root is anchored: an animation can't move anchored limbs.
			part.Anchored = part.Name == "HumanoidRootPart"
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	MeetFigures.makeGhost(npc)
	-- Standing on the spot's floor, facing out into the room (the spot's Facing attribute, else its front).
	local facing = spot:GetAttribute("Facing")
	local look = if typeof(facing) == "Vector3" then facing else spot.CFrame.LookVector
	local floor = spot.Position - Vector3.new(0, spot.Size.Y / 2, 0)
	local standAt = floor + Vector3.new(0, humanoid.HipHeight + body.Size.Y / 2, 0)
	npc:PivotTo(CFrame.lookAt(standAt, standAt + Vector3.new(look.X, 0, look.Z)))
	npc.Parent = spot.Parent
	table.insert(npcs, npc)

	local idle = loadTrack(npc, LocalMeetConfig.ComputerLifters.IdleAnimationId)
	if idle then
		idle.Priority = Enum.AnimationPriority.Idle
		idle.Looped = true
		idle:Play(0.2)
	end
	showOff(npc)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpinPrompt"
	prompt.ActionText = SPIN.promptText
	prompt.ObjectText = SPIN.npcName
	prompt.HoldDuration = SPIN.promptHoldSeconds
	prompt.MaxActivationDistance = SPIN.promptDistanceStuds
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		if root(player) then
			remotes.open:FireClient(player)
		end
	end)
end

function CelebrationSpinService.start()
	if started then
		return
	end
	started = true
	local remotes = CelebrationRemotes.createSpinOnServer(ReplicatedStorage)
	remotes.get.OnServerInvoke = function(player: Player): CelebrationRemotes.SpinView?
		if tooFast(player) then
			return nil
		end
		return viewFor(player)
	end
	remotes.spin.OnServerInvoke = function(player: Player, kind: any): (boolean, string, CelebrationRemotes.SpinView?, string?, number)
		if typeof(kind) ~= "string" or not CelebrationRemotes.KINDS[kind] then
			return false, "That isn't something to spin.", nil, nil, 0
		end
		if tooFast(player) then
			return false, "One moment...", nil, nil, 0
		end
		return spin(player, kind)
	end
	for _, spot in ipairs(CollectionService:GetTagged(SPIN.spotTag)) do
		task.spawn(buildNpc, spot, remotes)
	end
	CollectionService:GetInstanceAddedSignal(SPIN.spotTag):Connect(function(spot)
		buildNpc(spot, remotes)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
end

return CelebrationSpinService
