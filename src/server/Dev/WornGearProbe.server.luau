--!strict
--[[
	WornGearProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Checks WornGearFit (the money system's step 5) in
	Studio without the uploaded models and prints a pass/fail line per check:

		1. a stand-in for the uploaded model (plain parts named like the worn
		   pieces, at the centres build_worn_gear_01.py printed, the whole
		   model turned round and moved, as an import might) is read back
		2. a default R15 body wearing all four slots: every piece lands where
		   it was modelled, measured from the body's own joint marks (rig
		   attachments; left limbs mirrored), upright and
		   facing the front, in its item's colours, welded, with no mass,
		   collision, touch, query or shadow
		3. a resized R15 body: pieces follow the parts' new sizes
		4. dressing again replaces the gear; wearing nothing removes it; an
		   R6 body gets nothing

	Studio only, and OFF BY DEFAULT: set ENABLED to true, play, then set it back.
	The test bodies are made far below the map and removed. Nothing requires
	this file.
]]

local ENABLED = false

local RunService = game:GetService("RunService")
if not ENABLED or not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local WornGearConfig = require(ConfigFolder:WaitForChild("WornGearConfig"))
local WornGearFit = require(script.Parent.Parent:WaitForChild("Economy"):WaitForChild("WornGearFit"))

local passed, failed = 0, 0
local function check(label: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print("  PASS  " .. label)
	else
		failed += 1
		warn("  FAIL  " .. label .. (if detail then "  -- " .. detail else ""))
	end
end

-- Each piece's centre relative to the HumanoidRootPart (right limb), as build_worn_gear_01.py printed them.
local CENTRES = {
	WornLeverBelt_Outer = Vector3.new(0, -0.800, 0),
	WornLeverBelt_Lining = Vector3.new(0, -0.800, 0),
	WornLeverBelt_Stitch = Vector3.new(0, -0.800, 0),
	WornLeverBelt_Lever = Vector3.new(0.015, -0.800, -0.722),
	WornLeverBelt_Text = Vector3.new(-0.031, -0.801, -0.784),
	WornKneeSleeve_Body_Upper = Vector3.new(0.5, -1.821, 0),
	WornKneeSleeve_Stripes_Upper = Vector3.new(0.5, -1.716, 0),
	WornKneeSleeve_Body_Lower = Vector3.new(0.5, -2.041, 0),
	WornKneeSleeve_Patch_Lower = Vector3.new(0.5, -2.201, -0.553),
	WornWristWrap_Body = Vector3.new(1.472, -0.580, -0.022),
	WornWristWrap_Stripes = Vector3.new(1.472, -0.580, 0),
	WornWristWrap_Text = Vector3.new(1.471, -0.581, -0.653),
	WornSinglet_Black_Upper = Vector3.new(0, 0.224, 0),
	WornSinglet_Red_Upper = Vector3.new(0, -0.118, 0),
	WornSinglet_Trim_Upper = Vector3.new(0, 0.684, 0),
	WornSinglet_Patch_Upper = Vector3.new(0, 0.520, -0.538),
	WornSinglet_Black_Lower = Vector3.new(0, -0.790, 0),
	WornSinglet_Red_Lower = Vector3.new(0, -0.790, 0),
	WornSinglet_Shorts_Leg = Vector3.new(0.5, -1.235, 0),
	WornSinglet_ShortsRed_Leg = Vector3.new(0.5, -1.235, 0),
}
local PIECE_SIZE = Vector3.new(0.6, 0.4, 0.2)
local WORN = { Singlet = "singlet_gold", Belt = "belt_gold", KneeSleeves = "sleeves_pink", WristWraps = "wraps_blaze" }
local EXPECTED_PIECES = 29 -- belt 5, sleeves 4 x 2, wraps 3 x 2, singlet 6 + 2 x 2

local function standIn(): Model
	local model = Instance.new("Model")
	model.Name = "WornGearStandIn"
	-- Turned round and moved, as the import might leave it.
	local turned = CFrame.new(20, -480, -5) * CFrame.Angles(0, math.pi, 0)
	for name, centre in pairs(CENTRES) do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = PIECE_SIZE
		part.Anchored = true
		part.CFrame = turned * CFrame.new(centre)
		part.Parent = model
	end
	model.Parent = workspace
	return model
end

local function body(description: HumanoidDescription, rig: Enum.HumanoidRigType, at: CFrame): Model
	local model = Players:CreateHumanoidModelFromDescription(description, rig)
	model.Name = "WornGearTestBody"
	-- Only the root is held still: the body's joints keep its parts together, as on a real character.
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	model:PivotTo(at)
	model.Parent = workspace
	-- A new body's parts settle (sizes and places) a moment after it is made.
	task.wait(1)
	return model
end

-- The worn piece and its side from a dressed part's name ("<item>_<Left|Right|><Piece>").
local function pieceOf(name: string): (string?, string)
	for pieceName in pairs(CENTRES) do
		for _, side in ipairs({ "Left", "Right", "" }) do
			local suffix = "_" .. side .. pieceName
			if string.sub(name, -#suffix) == suffix then
				return pieceName, side
			end
		end
	end
	return nil, ""
end

local function slotOf(pieceName: string): WornGearConfig.Slot?
	for _, slot in ipairs(WornGearConfig.Slots) do
		if string.sub(pieceName, 1, #slot.worn + 1) == slot.worn .. "_" then
			return slot
		end
	end
	return nil
end

-- Where a dressed piece should be, in its body part's own space: from the body's joint mark, the modelled
-- distance from that joint scaled with the part (mirrored on the left). Also returns the body part.
local function expectedOn(character: Model, pieceName: string, side: string): (BasePart?, Vector3?)
	local slot = slotOf(pieceName)
	local segment = string.match(pieceName, "^%a+_%a+_(%a+)$") or ""
	local place = slot and slot.parts[segment]
	if place == nil then
		return nil, nil
	end
	local bodyPart = character:FindFirstChild(side .. place.part) :: BasePart?
	local mark = bodyPart and bodyPart:FindFirstChild(side .. place.joint .. "RigAttachment")
	if bodyPart == nil or mark == nil or not mark:IsA("Attachment") then
		return bodyPart, nil
	end
	local defaultPart = WornGearConfig.DefaultBody[place.part]
	local fromJoint = (CENTRES[pieceName] - WornGearConfig.Joints[place.joint]) * (bodyPart.Size / defaultPart.size)
	if side == "Left" then
		fromJoint = Vector3.new(-fromJoint.X, fromJoint.Y, fromJoint.Z)
	end
	return bodyPart, mark.Position + fromJoint
end

print("=== Worn gear probe ===")
local made: { Instance } = {}

print("1. reading the model")
local standin = standIn()
table.insert(made, standin)
local pieces, count = WornGearFit.fromModel(standin)
check("all 20 pieces read", count == 20, tostring(count))
check("each slot has its pieces", #(pieces.WornLeverBelt or {}) == 5 and #(pieces.WornKneeSleeve or {}) == 4
	and #(pieces.WornWristWrap or {}) == 3 and #(pieces.WornSinglet or {}) == 8)

print("2. a default R15 body wearing everything")
local default = body(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15,
	CFrame.new(0, -500, 0) * CFrame.Angles(0, 0.7, 0))
table.insert(made, default)
local n = WornGearFit.dress(default, WORN, pieces)
check(string.format("%d pieces made", EXPECTED_PIECES), n == EXPECTED_PIECES, tostring(n))
local folder = default:FindFirstChild(WornGearConfig.FolderName)
local worst, worstName, badLook, badTurn = 0, "", 0, 0
for _, child in ipairs(if folder then folder:GetChildren() else {}) do
	if child:IsA("BasePart") then
		local part = child :: BasePart
		local pieceName, side = pieceOf(part.Name)
		local slot = pieceName and slotOf(pieceName)
		if pieceName and slot then
			-- Where it was modelled, from the body's own joint (each body's parts sit a little differently).
			local found, expected = expectedOn(default, pieceName, side)
			local bodyPart = found :: BasePart
			local off = if expected then (bodyPart.CFrame:PointToObjectSpace(part.Position) - expected).Magnitude
				else math.huge
			if off > worst then
				worst, worstName = off, part.Name
			end
			local item = ShopConfig.find(WORN[slot.id]) :: ShopConfig.Item
			local key = string.match(pieceName, "^%a+_(%a+)") :: string
			local weld = part:FindFirstChildOfClass("Weld")
			local colour: Color3 = item.colours[key] or WornGearConfig.FallbackColour
			if part.Color ~= colour or part.CanCollide or part.CanTouch
				or part.CanQuery or part.CastShadow or not part.Massless or part.Anchored or weld == nil then
				badLook += 1
			end
			-- Upright and facing the body's front, whatever way the model was turned.
			local turn = bodyPart.CFrame:ToObjectSpace(part.CFrame)
			if turn.UpVector:Dot(Vector3.yAxis) < 0.999 or turn.LookVector:Dot(-Vector3.zAxis) < 0.999 then
				badTurn += 1
			end
		end
	end
end
check("every piece where it was modelled, from the body's joints (left limbs mirrored)", worst < 0.02,
	string.format("worst %.3f studs: %s", worst, worstName))
check("colours, weld, no mass / collision / touch / query / shadow", badLook == 0, tostring(badLook) .. " wrong")
check("every piece upright and facing the front", badTurn == 0, tostring(badTurn) .. " turned")

print("3. a resized R15 body")
local description = Instance.new("HumanoidDescription")
description.WidthScale = 0.8
description.HeightScale = 1.15
description.DepthScale = 0.9
local resized = body(description, Enum.HumanoidRigType.R15, CFrame.new(10, -500, 0))
table.insert(made, resized)
WornGearFit.dress(resized, WORN, pieces)
local worstScaled, worstSize = 0, 0
local resizedFolder = resized:FindFirstChild(WornGearConfig.FolderName)
for _, child in ipairs(if resizedFolder then resizedFolder:GetChildren() else {}) do
	if child:IsA("BasePart") then
		local part = child :: BasePart
		local pieceName, side = pieceOf(part.Name)
		local slot = pieceName and slotOf(pieceName)
		if pieceName and slot then
			local found, expected = expectedOn(resized, pieceName, side)
			local bodyPart = found :: BasePart
			local segment = string.match(pieceName, "^%a+_%a+_(%a+)$") or ""
			local scale = bodyPart.Size / WornGearConfig.DefaultBody[slot.parts[segment].part].size
			worstScaled = math.max(worstScaled, if expected
				then (bodyPart.CFrame:PointToObjectSpace(part.Position) - expected).Magnitude else math.huge)
			worstSize = math.max(worstSize, (part.Size - PIECE_SIZE * scale).Magnitude)
		end
	end
end
local thigh = resized:FindFirstChild("RightUpperLeg") :: BasePart
local shin = resized:FindFirstChild("RightLowerLeg") :: BasePart
local kneeTop = thigh:FindFirstChild("RightKneeRigAttachment") :: Attachment
local kneeBottom = shin:FindFirstChild("RightKneeRigAttachment") :: Attachment
check("the thigh's and shin's knee marks are the same point (the sleeve halves meet)",
	(kneeTop.WorldPosition - kneeBottom.WorldPosition).Magnitude < 0.01)
local torso = resized:FindFirstChild("UpperTorso") :: BasePart
check("the body really is resized", math.abs(torso.Size.X / 1.943 - 1) > 0.05, tostring(torso.Size))
check("pieces follow their parts' new sizes", worstScaled < 0.02, string.format("worst %.3f studs", worstScaled))
check("pieces are scaled like their parts", worstSize < 0.01, string.format("worst %.3f studs", worstSize))

print("4. changes, nothing worn, R6")
local again = WornGearFit.dress(default, { Belt = "belt_gold" }, pieces)
local folders = 0
for _, child in ipairs(default:GetChildren()) do
	if child.Name == WornGearConfig.FolderName then
		folders += 1
	end
end
check("dressing again replaces the gear (only the belt now)", again == 5 and folders == 1)
check("an item in the wrong slot is not worn", WornGearFit.dress(default, { Belt = "wraps_blaze" }, pieces) == 0)
WornGearFit.dress(default, {}, pieces)
check("wearing nothing removes the gear", default:FindFirstChild(WornGearConfig.FolderName) == nil)
local r6 = body(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6, CFrame.new(20, -500, 0))
table.insert(made, r6)
check("an R6 body gets nothing", WornGearFit.dress(r6, WORN, pieces) == 0
	and r6:FindFirstChild(WornGearConfig.FolderName) == nil)

for _, thing in ipairs(made) do
	thing:Destroy()
end
print(string.format("=== %d passed, %d failed ===", passed, failed))
