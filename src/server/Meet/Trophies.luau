--!strict
--[[
	Trophies
	Server / Meet

	The trophies the top 3 hold on the awards podium at a Regional or State
	meet (GAME_DESIGN.md §35.8). One uploaded model (MeetLevelConfig.
	TrophyAssetId, art/blender/Trophy_01.blend): Trophy_Metal, coloured gold,
	silver or bronze by place, and Trophy_Base. Each trophy is welded to the
	lifter's right hand for the ceremony and taken away after it. Looks only:
	no mass, collision, touch, query or shadow. Without the model (asset 0 or
	not loaded) nobody holds a trophy and nothing else changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeetLevelConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MeetLevelConfig"))

local Trophies = {}

local template: Model? = nil
local loadTried = false
local given: { Model } = {}

local function load(): Model?
	if loadTried then
		return template
	end
	loadTried = true
	if MeetLevelConfig.TrophyAssetId == 0 then
		return nil
	end
	local ok, problem = pcall(function()
		local loaded = game:GetService("InsertService"):LoadAsset(MeetLevelConfig.TrophyAssetId)
		local model = Instance.new("Model")
		model.Name = "Trophy"
		for _, d in ipairs(loaded:GetDescendants()) do
			if d:IsA("BasePart") and string.match(d.Name, "^Trophy_") then
				d.Parent = model
			end
		end
		loaded:Destroy()
		assert(model:FindFirstChild("Trophy_Metal"), "Trophy_Metal missing")
		template = model
	end)
	if not ok then
		warn("[Trophies] the trophy model did not load (no trophies): " .. tostring(problem))
	end
	return template
end

-- Puts a trophy for `place` (1-3) in the character's right hand until Trophies.clear(). Returns whether it did.
function Trophies.give(character: Model, place: number): boolean
	local colour: Color3? = MeetLevelConfig.TrophyColours[place]
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local model = load()
	if not colour or hand == nil or not hand:IsA("BasePart") or model == nil then
		return false
	end
	local trophy = model:Clone()
	local pivot, size = trophy:GetBoundingBox()
	-- Held by its base, standing upright, out in front of the hand so the cup clears the arm.
	local base = CFrame.new(0, -hand.Size.Y / 2 + size.Y / 2 - 0.1, -(hand.Size.Z / 2 + size.Z / 2 + 0.05))
	for _, part in ipairs(trophy:GetChildren()) do
		if part:IsA("BasePart") then
			if part.Name == "Trophy_Metal" then
				part.Color = colour :: Color3
				part.Material = Enum.Material.Metal
				part.Reflectance = 0.15
			else
				part.Color = Color3.fromRGB(24, 24, 26)
				part.Material = Enum.Material.SmoothPlastic
			end
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part.CastShadow = false
			local offset = base * pivot:ToObjectSpace(part.CFrame)
			part.CFrame = (hand :: BasePart).CFrame * offset
			local weld = Instance.new("Weld")
			weld.Part0 = hand
			weld.Part1 = part
			weld.C0 = offset
			weld.Parent = part
		end
	end
	trophy.Parent = character
	table.insert(given, trophy)
	return true
end

-- Takes every trophy away again (the ceremony is over).
function Trophies.clear()
	for _, trophy in ipairs(given) do
		trophy:Destroy()
	end
	table.clear(given)
end

-- Loads the model ahead of the first ceremony (it yields).
function Trophies.preload()
	task.spawn(load)
end

return Trophies
