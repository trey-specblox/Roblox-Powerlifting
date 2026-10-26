--!strict
--[[
	AutoDoorAnimator
	Client / World

	Moves the automatic sliding doors (StarterGymConfig "automatic entrance
	doors"; built by StarterGymBuilder as Models tagged AutoDoorTag). Visual
	only: it sends nothing to the server and changes no game state.

	Every door has an invisible Sensor part. While any player's character
	stands in it, the door's panels (child Models with a ClosedPivot attribute)
	open: sliding ones by their OpenOffset, swing doors to their OpenPivot
	(turning about the hinge, where their pivot is); DoorHoldOpenSeconds after
	the last one has left, they close again. The sensor lamp is green while open, red while
	closed. Every player's screen works this out by itself from where the
	characters are, so everyone sees the same thing.

	The server's panels never move: closed, they are solid. Your own character
	bumps into the panels where YOUR screen shows them, so an open door lets
	you through.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StarterGymConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StarterGymConfig"))

local AutoDoorAnimator = {}

-- progress: 0 = closed, 1 = fully open. lastSeen: os.clock() when someone was last in the sensor.
type DoorState = { progress: number, lastSeen: number, open: boolean }

-- Strong keys, removed when a door is untagged or streamed out (see StationVisuals: weak keys can vanish early).
local doors: { [Instance]: DoorState } = {}
local started = false

local function someoneIn(sensor: BasePart): boolean
	local half = sensor.Size / 2
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local p = sensor.CFrame:PointToObjectSpace(root.Position)
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- Starts and stops gently.
local function ease(amount: number): number
	return amount * amount * (3 - 2 * amount)
end

local function placePanels(door: Instance, progress: number)
	local eased = ease(progress)
	for _, child in ipairs(door:GetChildren()) do
		if child:IsA("Model") then
			local closed = child:GetAttribute("ClosedPivot")
			local offset = child:GetAttribute("OpenOffset")
			local openPivot = child:GetAttribute("OpenPivot")
			if typeof(closed) == "CFrame" and typeof(openPivot) == "CFrame" then
				-- A swing door: its pivot is on the hinge, so this turns it about the hinge.
				child:PivotTo(closed:Lerp(openPivot, eased))
			elseif typeof(closed) == "CFrame" and typeof(offset) == "Vector3" then
				child:PivotTo(closed + offset * eased)
			end
		end
	end
end

local function update(deltaTime: number)
	local now = os.clock()
	for door, state in pairs(doors) do
		local sensor = door:FindFirstChild("Sensor")
		if sensor and sensor:IsA("BasePart") then
			if someoneIn(sensor) then
				state.lastSeen = now
			end
			local open = now - state.lastSeen < StarterGymConfig.DoorHoldOpenSeconds
			if open ~= state.open then
				state.open = open
				local lamp = door:FindFirstChild("SensorLamp")
				if lamp and lamp:IsA("BasePart") then
					lamp.Color = if open then StarterGymConfig.Looks.GlowGreen.color else StarterGymConfig.Looks.GlowRed.color
				end
			end
			local target = if open then 1 else 0
			if state.progress ~= target then
				local step = deltaTime / StarterGymConfig.DoorSlideSeconds
				state.progress = if target > state.progress
					then math.min(target, state.progress + step)
					else math.max(target, state.progress - step)
				placePanels(door, state.progress)
			end
		end
	end
end

-- A door that arrives (also after streaming back in) starts closed, as the server built it.
local function track(door: Instance)
	if doors[door] == nil then
		doors[door] = { progress = 0, lastSeen = -math.huge, open = false }
	end
end

local function untrack(door: Instance)
	doors[door] = nil
end

function AutoDoorAnimator.start()
	if started then
		return
	end
	started = true
	local tag = StarterGymConfig.AutoDoorTag
	for _, door in ipairs(CollectionService:GetTagged(tag)) do
		track(door)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
	RunService.RenderStepped:Connect(update)
end

return AutoDoorAnimator
