--!strict
--[[
	KitchenChef
	Server / Economy

	The Kitchen's chef (GAME_DESIGN §40.7, user 2026-11-19): the NPC the lifter walks up to for steaks (and, later,
	meet meals). The coaches' cartoon figure (MeetFigures) in a white top and black trousers, wearing the Blender chef's
	hat and the two-part navy apron (KitchenChef_01: ChefHat welded to the head, ChefBib to the upper torso, ChefSkirt to
	the lower torso), standing at the front of the pan hall by its entrance.

	His root part carries KitchenConfig.CookerSpotTag, so KitchenService puts the "Cook" prompt on him; the chef's own
	screen (KitchenMenu) answers it.

	PERFORMANCE: one figure and nine small pieces, built once.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))

local ServerFolder = script.Parent.Parent
local MeetFigures = require(ServerFolder:WaitForChild("Meet"):WaitForChild("MeetFigures"))
local RoomProps = require(ServerFolder:WaitForChild("World"):WaitForChild("RoomProps"))
local BuildParts = require(ServerFolder:WaitForChild("World"):WaitForChild("BuildParts"))

local KitchenChef = {}

--[[
	Each clothing item's bounds centre in the figure's root space (studs: x right, y up, z back; the front is -z), from
	build_kitchen_chef_01.py's BOUNDS lines (Blender x, y, z -> root x, z, y), and the body part it is welded to.
]]
local CLOTHES = {
	{ item = "ChefHat", centre = Vector3.new(0, (2.6 + 4.187) / 2, 0), part = "Head" },
	{ item = "ChefBib", centre = Vector3.new(0, (-0.546 + 1.988) / 2, (-1.097 + 0.69) / 2), part = "UpperTorso" },
	{ item = "ChefSkirt", centre = Vector3.new(0, (-2.15 - 0.28) / 2, (-1.111 + 0.754) / 2), part = "LowerTorso" },
}

local started = false
local chef: Model? = nil

-- Puts `copy` with its bounds centre at root * centre and welds every piece to `body`.
local function wear(figure: Model, root: BasePart, copy: Model, centre: Vector3, body: BasePart)
	local box = copy:GetBoundingBox()
	local relative = box:ToObjectSpace(copy:GetPivot())
	copy:PivotTo(root.CFrame * CFrame.new(centre) * relative)
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			BuildParts.decor(part)
			part.Anchored = false
			part.Massless = true
			part.CanQuery = false
			part.CollisionGroup = body.CollisionGroup
			local weld = Instance.new("Weld")
			weld.Part0 = body
			weld.Part1 = part
			weld.C0 = body.CFrame:ToObjectSpace(part.CFrame)
			weld.Parent = part
		end
	end
	copy.Parent = figure
end

--[[
	The chef scene's moves (KitchenConfig.ChefAnimations: scoop, hold, throw, walk) are NOT played here: the cooking
	player's own screen plays them on a local copy of him (KitchenScene, user 2026-11-21), so his hands and the meat keep
	time. Everyone else sees him standing at his spot.
]]

-- The chef figure, or nil before start built him.
function KitchenChef.figure(): Model?
	return chef
end

function KitchenChef.start()
	if started then
		return
	end
	started = true
	local folder = Workspace:WaitForChild("KitchenHall", 60)
	if folder == nil then
		warn("[KitchenChef] no KitchenHall; no chef")
		return
	end
	local at = KitchenConfig.HallOrigin * KitchenConfig.ChefSpot
	local _, figure = MeetFigures.build(folder, "Coach", at.Position, (at * CFrame.new(0, 0, -10)).Position, nil,
		{ top = Color3.fromRGB(244, 244, 240), trousers = Color3.fromRGB(28, 28, 32), tag = "CHEF" })
	if figure == nil then
		warn("[KitchenChef] the chef figure couldn't be made")
		return
	end
	figure.Name = "KitchenChef"
	local clipboard = figure:FindFirstChild("Clipboard")
	if clipboard then
		clipboard:Destroy()
	end
	local root = figure:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	for _, piece in ipairs(CLOTHES) do
		local body = figure:FindFirstChild(piece.part)
		local copy = RoomProps.propCopy(piece.item, 1)
		if copy and body and body:IsA("BasePart") then
			copy.Name = piece.item
			wear(figure, root, copy, piece.centre, body)
		end
	end
	-- His name tag above the tall hat, at every distance (measured from the hat's top, now that he wears it).
	MeetFigures.seatTag(figure)
	-- The meat grinder beside him (its spout toward the hall's middle line), for the chef scene (KitchenScene, client).
	local grinder = RoomProps.propCopy("MeatGrinder", 1)
	if grinder then
		grinder.Name = "MeatGrinder"
		grinder:ScaleTo(KitchenConfig.GrinderScale)
		grinder:PivotTo(KitchenConfig.HallOrigin * KitchenConfig.GrinderSpot)
		grinder.Parent = folder
	end
	-- KitchenService puts the "Cook" prompt on him.
	root:AddTag(KitchenConfig.CookerSpotTag)
	chef = figure
end

return KitchenChef
