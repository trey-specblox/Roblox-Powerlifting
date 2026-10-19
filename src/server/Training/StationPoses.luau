--!strict
--[[
	StationPoses
	Server / Training

	Puts a rack's occupant in position for the lift they selected (GAME_DESIGN.md
	§34.12, decision 15) and holds them there; lets them go when they stop,
	switch to "no lift", leave the rack, die or leave the game.

	  Squat     standing under the bar, walked out in front of the posts
	  Bench     lying face up on the bench, head under the racked bar
	  Deadlift  standing behind the bar on the floor in front of the rack,
	            facing the rack (user choice, 2026-10-19)

	For squat the lifter faces the rack's open front (-Z). They are held by
	anchoring their HumanoidRootPart; released lifters are put back on their
	feet at the layout's exit spot, in front of the rack.

	It also marks the character with the attribute StationPose = the lift (nil
	when released), so a client animation script can play that lift's
	animation for EVERY character. Until those animations exist, the character
	keeps its normal idle animation.

	Visual only. The server decides everything here; clients send nothing.
	Positions come from StationLayout; racks without a layout are skipped.
]]

local Players = game:GetService("Players")

local StationLayout = require(script.Parent.StationLayout)

local StationPoses = {}

local POSE_ATTRIBUTE = "StationPose"

type Posed = { player: Player, lift: string }

-- Who is posed at each rack, and in which lift.
local posedAt: { [Instance]: Posed } = setmetatable({}, { __mode = "k" }) :: any

-- Face up, head toward the rack (+Z), feet toward the open front.
local LYING = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.zAxis)

type Body = { character: Model, root: BasePart, humanoid: Humanoid }

local function bodyOf(player: Player): Body?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil
	end
	return { character = character, root = root, humanoid = humanoid }
end

-- Height of the root part's centre above the floor when the character stands.
local function standingHeight(body: Body): number
	if body.humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 3
	end
	return body.humanoid.HipHeight + body.root.Size.Y / 2
end

local function poseFrame(body: Body, layout: StationLayout.Layout, lift: string): CFrame?
	if lift == "Squat" then
		return CFrame.new(0, standingHeight(body), layout.squatStandZ)
	elseif lift == "Deadlift" then
		-- Behind the bar, turned round to face the rack.
		return CFrame.new(0, standingHeight(body), layout.deadliftStandZ) * CFrame.Angles(0, math.pi, 0)
	elseif lift == "Bench" then
		-- Head under the bar: measure how far the head sits above the root, along the body.
		local head = body.character:FindFirstChild("Head")
		local headUp = if head ~= nil and head:IsA("BasePart")
			then body.root.CFrame:PointToObjectSpace(head.Position).Y
			else 1.5
		local rootZ = layout.benchHeadZ - headUp
		return CFrame.new(0, layout.benchPadTop + body.root.Size.Z / 2, rootZ) * LYING
	end
	return nil
end

local function release(entry: Posed, rack: Model, layout: StationLayout.Layout)
	local body = bodyOf(entry.player)
	-- Only the character we posed: after a respawn the player has a new, unmarked one.
	if body == nil or body.character:GetAttribute(POSE_ATTRIBUTE) == nil then
		return
	end
	body.character:SetAttribute(POSE_ATTRIBUTE, nil)
	if body.root.Anchored then
		body.character:PivotTo(StationLayout.floorFrame(rack) * CFrame.new(0, standingHeight(body), layout.exitZ))
		body.root.Anchored = false
	end
end

local function pose(player: Player, rack: Model, layout: StationLayout.Layout, lift: string): boolean
	local body = bodyOf(player)
	if body == nil or body.humanoid.Health <= 0 then
		return false
	end
	local localFrame = poseFrame(body, layout, lift)
	if localFrame == nil then
		return false
	end
	body.root.Anchored = true
	body.character:PivotTo(StationLayout.floorFrame(rack) * localFrame)
	body.character:SetAttribute(POSE_ATTRIBUTE, lift)
	return true
end

--[[
	Brings `rack`'s lifter in line with its current occupant and lift. `occupant`
	is the rack's occupant (nil if free) and `lift` their selected lift (nil if
	none yet). Safe to call on every sign refresh: it only moves characters
	when the occupant or lift changes.
]]
function StationPoses.update(rack: Instance, occupant: any, lift: string?)
	local layout = StationLayout.of(rack)
	if layout == nil or not rack:IsA("Model") then
		return
	end

	-- Only real players are posed (the training probe uses made-up occupant keys).
	local player: Player? = if typeof(occupant) == "Instance" and occupant:IsA("Player") and occupant.Parent == Players
		then occupant
		else nil

	local current = posedAt[rack]
	if current ~= nil and current.player == player and current.lift == lift then
		return
	end
	if current ~= nil then
		release(current, rack, layout)
		posedAt[rack] = nil
	end
	if player ~= nil and lift ~= nil and pose(player, rack, layout, lift) then
		posedAt[rack] = { player = player, lift = lift }
	end
end

return StationPoses
