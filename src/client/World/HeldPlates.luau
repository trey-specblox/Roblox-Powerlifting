--!strict
--[[
	HeldPlates
	Client / World

	FOOD CARRIED IN BOTH HANDS (GAME_DESIGN §42; user 2026-11-24: "just change it to where two hands are foward holding
	the plate"). The server makes held food a Tool in the right hand and plays the two-handed carry (HoldService,
	animation Carry_FoodTray, its id in the Tool's "CarryAnim" attribute). A Tool hangs from ONE hand, so on this screen,
	for every character carrying food, this sets the Tool's grip once the carry pose has settled: the plate then sits flat
	on top of both palms, in the middle, facing the way the lifter faces. Every body build has its own hand spread, so it
	is measured on the character itself, never a fixed number.

	Display only: it changes the grip on this player's own screen (the server's grip stays as made).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HeldPlates = {}

-- How far above the hands' centres the plate's bottom sits (the hand is about 0.3 thick, palms up).
local PALM_UP_STUDS = 0.16
-- How long the carry has to be playing before the hands are measured (the animation fades in over 0.25 s).
local SETTLE_SECONDS = 0.45
local CHECK_SECONDS = 0.2

local started = false
-- Tools carried and when their carry was first seen playing (os.clock), or true once their grip is set.
local watching: { [Tool]: number | boolean } = {}

local function carryPlaying(humanoid: Humanoid, animationId: string): boolean
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return false
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation and track.Animation.AnimationId == animationId and track.WeightCurrent > 0.95 then
			return true
		end
	end
	return false
end

-- Sets the grip so the handle (the plate's bottom middle) sits on both palms. Returns whether it could.
local function fitGrip(tool: Tool, character: Model): boolean
	local right = character:FindFirstChild("RightHand")
	local left = character:FindFirstChild("LeftHand")
	local torso = character:FindFirstChild("UpperTorso")
	local handle = tool:FindFirstChild("Handle")
	if not (right and left and torso and handle and right:IsA("BasePart") and left:IsA("BasePart") and torso:IsA("BasePart")) then
		return false
	end
	-- The weld Roblox made when the Tool was equipped (setting Tool.Grip on a client does not move it: checked in Studio
	-- 2026-11-24, so its C1 is set here instead).
	local grip: Weld? = nil
	for _, child in ipairs(right:GetChildren()) do
		if child:IsA("Weld") and child.Name == "RightGrip" and child.Part1 == handle then
			grip = child
		end
	end
	if grip == nil then
		return false
	end
	local middle = (right.Position + left.Position) / 2 + torso.CFrame.UpVector * PALM_UP_STUDS
	local wanted = CFrame.new(middle) * torso.CFrame.Rotation
	-- handle = hand * C0 * C1:Inverse(), so C1 = handle:Inverse() * hand * C0.
	grip.C1 = wanted:Inverse() * right.CFrame * grip.C0
	return true
end

local function check()
	for tool, state in pairs(watching) do
		local character = tool.Parent
		if character == nil or not character:IsA("Model") then
			watching[tool] = nil
			continue
		end
		if state == true then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animationId = tool:GetAttribute("CarryAnim")
		if humanoid == nil or typeof(animationId) ~= "string" then
			continue
		end
		if not carryPlaying(humanoid, animationId) then
			watching[tool] = 0
		elseif state == 0 then
			watching[tool] = os.clock()
		elseif os.clock() - (state :: number) >= SETTLE_SECONDS and fitGrip(tool, character) then
			watching[tool] = true
		end
	end
end

local function watchTool(tool: Instance)
	if tool:IsA("Tool") and tool:GetAttribute("HeldKind") == "Food" and watching[tool] == nil then
		watching[tool] = 0
	end
end

local function watchCharacter(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		watchTool(child)
	end
	character.ChildAdded:Connect(function(child)
		task.defer(watchTool, child)
	end)
end

local function watchPlayer(player: Player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

function HeldPlates.start()
	if started then
		return
	end
	started = true
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited >= CHECK_SECONDS then
			waited = 0
			check()
		end
	end)
end

return HeldPlates
