--!strict
--[[
	KitchenBackDoor
	Client / World

	W Chews' EMPLOYEES ONLY door (GAME_DESIGN §40.7): the door between the kitchen and the mafia boss cow's back room
	swings open, into the back room, when a lifter comes near it, and shuts behind them. The doorway itself is always
	open to walk through (KitchenBuilding leaves it out of the walls' hidden blocks); this only moves the door's three
	pieces, on this screen.

	KitchenBackDoor.hold(true) keeps it open whoever is near (the chef scene's cow walk-on, KitchenScene); every
	hold(true) needs its hold(false).

	PERFORMANCE: one distance check five times a second while this player is in the hall, and a per-frame step only
	during the half second the door is moving.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))

local KitchenBackDoor = {}

local OPEN_ANGLE = math.rad(100)
local SWING_SECONDS = 0.45
local NEAR = 12 -- studs from the doorway's middle
local HALL_REACH = 700 -- further than this from the door, this player isn't in the restaurant: check rarely
-- The doorway in plan space (build_wchews_hall_01.py DOOR: x 245..251 in the kitchen's back wall, y 265..267); the
-- door hangs on its x 245 side.
local HINGE_X, MIDDLE_X, DOOR_Y = 245, 248, 266
local PIECES = { "WcStaffDoor_Door", "WcStaffDoor_DoorBrass", "WcStaffDoor_DoorText" }

local started = false
local holds = 0

-- Keeps the door open (true) until the matching hold(false).
function KitchenBackDoor.hold(open: boolean)
	holds = math.max(0, holds + (if open then 1 else -1))
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
	local middle = (hall0 * KitchenConfig.planSpot(MIDDLE_X, DOOR_Y, 4)).Position
	local hingeAt = (hall0 * KitchenConfig.planSpot(HINGE_X, DOOR_Y, 0)).Position
	task.spawn(function()
		-- The door's pieces as they stand shut (found again whenever the hall streams back in).
		local pieces: { { part: BasePart, home: CFrame } } = {}
		local hinge = CFrame.new(hingeAt)
		local angle = 0
		local function find(): boolean
			if #pieces > 0 and pieces[1].part.Parent ~= nil then
				return true
			end
			table.clear(pieces)
			angle = 0
			local hall = Workspace:FindFirstChild("KitchenHall")
			local kit = hall and hall:FindFirstChild("WChewsKit")
			local door = kit and kit:FindFirstChild("WcStaffDoor")
			if door == nil then
				return false
			end
			for _, name in ipairs(PIECES) do
				local part = door:FindFirstChild(name, true)
				if part and part:IsA("BasePart") then
					table.insert(pieces, { part = part, home = part.CFrame })
				end
			end
			if #pieces == 0 then
				return false
			end
			-- The hinge line: straight up through the door's hung edge, at the leaf's own depth in the wall.
			hinge = CFrame.new(hingeAt.X, pieces[1].home.Position.Y, pieces[1].home.Position.Z)
			return true
		end
		local function pose()
			for _, piece in ipairs(pieces) do
				piece.part.CFrame = hinge * CFrame.Angles(0, angle, 0) * hinge:ToObjectSpace(piece.home)
			end
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
					while math.abs(target - angle) > 0.001 and pieces[1].part.Parent ~= nil do
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
