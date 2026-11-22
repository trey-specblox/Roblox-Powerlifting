--!strict
--[[
	KitchenBackDoor
	Client / World

	W Chews' EMPLOYEES ONLY door (GAME_DESIGN §40.7): the DOUBLE door in the middle of the kitchen's back wall, between
	the kitchen and the mafia boss cow's back room (user 2026-11-22: "like a double door ... push open both of them
	at the same time"). Both leaves swing open together, into the back room, when a lifter comes near, and shut behind
	them. The doorway itself is always open to walk through (KitchenBuilding leaves it out of the walls' hidden
	blocks); this only moves the leaves' pieces, on this screen.

	Each leaf hangs on its OUTER edge and turns on the corner of that edge on the back room's side, 90 degrees
	(WChewsLayout.LeafHinge / LeafHingeY; the model is built so an open leaf lies 0.3 clear of its jamb and the two
	never touch: art/scripts/build_wchews_door_01.py). The single door this replaced swung about its middle line past
	90 degrees, cut through its own frame and flickered against it (user 2026-11-22).

	KitchenBackDoor.hold(true) keeps it open whoever is near (the chef scene's cow, KitchenScene); every hold(true)
	needs its hold(false).

	PERFORMANCE: one distance check five times a second while this player is in the hall, and a per-frame step only
	during the half second the leaves are moving (10 small parts).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local WChewsLayout = require(Shared:WaitForChild("Config"):WaitForChild("WChewsLayout"))

local KitchenBackDoor = {}

local OPEN_ANGLE = math.rad(90)
local SWING_SECONDS = 0.45
local NEAR = 14 -- studs from the doorway's middle (the doorway is 16 wide)
local HALL_REACH = 700 -- further than this from the door, this player isn't in the restaurant: check rarely
local ITEM = "WcDoubleDoor"

type Leaf = { hinge: CFrame, turn: number, pieces: { { part: BasePart, home: CFrame } } }

local started = false
local holds = 0
local openShare = 0 -- 0 shut .. 1 open, as last posed

-- Keeps the door open (true) until the matching hold(false).
function KitchenBackDoor.hold(open: boolean)
	holds = math.max(0, holds + (if open then 1 else -1))
end

-- How far open the leaves stand on this screen now: 0 shut .. 1 fully open.
function KitchenBackDoor.openShare(): number
	return openShare
end

local function sound(id: string?, at: Vector3)
	if id == nil or id == "" then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = at
	holder.Parent = Workspace.Terrain
	local made = Instance.new("Sound")
	made.SoundId = id
	made.Volume = 0.6
	made.RollOffMaxDistance = 90
	made.Parent = holder
	made:Play()
	task.delay(4, function()
		holder:Destroy()
	end)
end

function KitchenBackDoor.start()
	if started then
		return
	end
	started = true
	local hall0 = KitchenConfig.HallOrigin
	local door = WChewsLayout.BackDoor
	local middle = (hall0 * KitchenConfig.planSpot(door.Middle, WChewsLayout.BackWallY + WChewsLayout.WallThickness / 2, 4)).Position
	task.spawn(function()
		-- The two leaves' pieces as they stand shut (found again whenever the hall streams back in).
		local leaves: { Leaf } = {}
		local model: Instance? = nil
		local angle = 0
		local function find(): boolean
			if model and model:IsDescendantOf(Workspace) and #leaves > 0 then
				return true
			end
			table.clear(leaves)
			angle = 0
			openShare = 0
			local hall = Workspace:FindFirstChild("KitchenHall")
			local kit = hall and hall:FindFirstChild("WChewsKit")
			local found = kit and kit:FindFirstChild(ITEM)
			if found == nil then
				return false
			end
			-- The left leaf (plan x under the doorway's middle) turns one way, the right leaf the other: both into
			-- the back room (the hall's +Z).
			for _, side in ipairs({ { name = "L", x = door.Middle - WChewsLayout.LeafHinge, turn = 1 },
				{ name = "R", x = door.Middle + WChewsLayout.LeafHinge, turn = -1 } }) do
				local leaf: Leaf = { hinge = hall0 * KitchenConfig.planSpot(side.x, WChewsLayout.LeafHingeY, 0),
					turn = side.turn, pieces = {} }
				local prefix = ITEM .. "_Leaf" .. side.name
				for _, part in ipairs(found:GetDescendants()) do
					if part:IsA("BasePart") and string.sub(part.Name, 1, #prefix) == prefix then
						table.insert(leaf.pieces, { part = part, home = part.CFrame })
					end
				end
				if #leaf.pieces > 0 then
					table.insert(leaves, leaf)
				end
			end
			if #leaves == 0 then
				return false
			end
			model = found
			return true
		end
		local function pose()
			for _, leaf in ipairs(leaves) do
				local turned = leaf.hinge * CFrame.Angles(0, leaf.turn * angle, 0)
				for _, piece in ipairs(leaf.pieces) do
					piece.part.CFrame = turned * leaf.hinge:ToObjectSpace(piece.home)
				end
			end
			openShare = angle / OPEN_ANGLE
		end
		local function someoneNear(): boolean
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and (root.Position - middle).Magnitude < NEAR then
					return true
				end
			end
			return false
		end
		while true do
			local camera = Workspace.CurrentCamera
			local far = camera == nil or (camera.CFrame.Position - middle).Magnitude > HALL_REACH
			if far and holds == 0 then
				task.wait(2)
			elseif not find() then
				task.wait(1)
			else
				local target = if holds > 0 or someoneNear() then OPEN_ANGLE else 0
				if math.abs(target - angle) > 0.001 then
					sound(if target > 0 then KitchenConfig.Sounds.DoorOpen else KitchenConfig.Sounds.DoorClose, middle)
					-- Swing to the target (it may change on the way: someone turns back).
					while math.abs(target - angle) > 0.001 and model ~= nil and model:IsDescendantOf(Workspace) do
						local dt = RunService.Heartbeat:Wait()
						target = if holds > 0 or someoneNear() then OPEN_ANGLE else 0
						local step = OPEN_ANGLE / SWING_SECONDS * dt
						angle = if target > angle then math.min(target, angle + step) else math.max(target, angle - step)
						pose()
					end
				else
					task.wait(0.2)
				end
			end
		end
	end)
end

return KitchenBackDoor
