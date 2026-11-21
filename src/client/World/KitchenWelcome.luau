--!strict
--[[
	KitchenWelcome
	Client / World

	The chef greets you when you walk into the Kitchen hall (user 2026-11-21: "when you enter the building he should
	say 'hey, welcome into W Chews'" - W Chews, said "Double-u Chews", is the restaurant's name): his voice from where
	he stands (KitchenConfig.Sounds.ChefWelcome, ElevenLabs, his own voice) and his words in the game's dialogue
	caption over the live scene (KitchenScene.say).

	Only on this player's screen, once each time they come in (and not again within RepeatSeconds, so walking in and
	out of the door doesn't repeat it), never over the chef scene.

	PERFORMANCE: one position check every half second; one sound while he talks.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))

local KitchenScene = require(script.Parent:WaitForChild("KitchenScene"))

local KitchenWelcome = {}

local REPEAT_SECONDS = 25
-- The hall, in its own space (KitchenConfig.HallOrigin): W Chews reaches x +-287 and z -112..339 (plan 02).
local HALL_HALF_X, HALL_MIN_Z, HALL_MAX_Z, HALL_HALF_Y = 295, -118, 345, 60

local started = false

local function insideHall(position: Vector3): boolean
	local at = KitchenConfig.HallOrigin:PointToObjectSpace(position)
	return math.abs(at.X) < HALL_HALF_X and at.Z > HALL_MIN_Z and at.Z < HALL_MAX_Z and math.abs(at.Y) < HALL_HALF_Y
end

local function greet()
	-- (The hall is far from the gym, so right after arriving the chef may still be streaming in: wait for him a little.)
	local hall = Workspace:WaitForChild("KitchenHall", 6)
	local chef = hall and hall:WaitForChild("KitchenChef", 6)
	local head = chef and chef:WaitForChild("Head", 6)
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local voice = Instance.new("Sound")
	voice.Name = "ChefWelcome"
	voice.SoundId = KitchenConfig.Sounds.ChefWelcome
	voice.Volume = 1
	voice.RollOffMinDistance = 45 -- (full voice from the door, 26 studs away; fades past that)
	voice.RollOffMaxDistance = 160
	voice.Parent = head
	voice:Play()
	KitchenScene.say("Hey, welcome into W Chews!", 3.2)
	task.delay(5, function()
		voice:Destroy()
	end)
end

function KitchenWelcome.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local wasInside = false
	local lastGreeted = -math.huge
	while true do
		task.wait(0.5)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local inside = root ~= nil and root:IsA("BasePart") and insideHall(root.Position)
		if inside and not wasInside and os.clock() - lastGreeted > REPEAT_SECONDS and not KitchenScene.isPlaying() then
			lastGreeted = os.clock()
			task.wait(0.6) -- (a moment to arrive and look round first)
			greet()
		end
		wasInside = inside
	end
end

return KitchenWelcome
