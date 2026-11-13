--[[
	LifterBody01_SwapTest  (dev test, NOT game code; tools/studio is not synced by Rojo)

	What it does: during a Studio PLAY session, on the SERVER (execute it in the Server data model), puts the new
	realistic lifter body (GAME_DESIGN.md §38.5; art/scripts/build_lifter_body_01.py; uploaded as
	rbxassetid://102214076264098) on the first player's character, to see it walk with Roblox's own animations.
	It changes only that one character in that one play session; Stop Play throws it away. Nothing is saved.

	Steps: loads the model; takes off Shirt / Pants / ShirtGraphic / BodyColors and every accessory that is not on
	the head or is layered clothing (they can't fit a custom body); replaces the 14 body parts (the player keeps
	their head) and moves every joint mark to the new body's joints; head at 70% (HeadScale); HipHeight 2.529.

	Gotchas found 2026-11-12, all needed:
	- Humanoid.RequiresNeck = false while swapping: replacing the torso breaks the neck for a moment and the
	  character dies and respawns with the old body.
	- Every joint mark (Attachment) has a hidden OriginalPosition value; Roblox's automatic scaling puts the mark
	  back there. Set it together with Position, or the old block joints come back.
	- Roblox's importer turns a GLB half round; the build script exports facing -Y in Blender so it lands facing -Z.
	- HipHeight is set after the swap (the Root joint's height above the floor, 2.529).

	Result 2026-11-12: HRP 3.529 above the floor, feet on the floor (toe tips 0.03 down), head 0.84 tall on the
	neck, hat and head accessory kept, no death, no errors; Roblox's run animation plays on it.
]]

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local ASSET_ID = 102214076264098
local NECK = Vector3.new(0.0154, 0.7575, 0.1162) -- UpperTorso's Neck mark (art/exports/LifterBody_01_joints.json)
local HIP_HEIGHT = 2.529
local HEAD_SCALE = 0.7

local player = Players:GetPlayers()[1]
assert(player and player.Character, "Run this in a play session, on the server, with a character spawned.")
local char = player.Character
local hum = char:FindFirstChildOfClass("Humanoid")
assert(hum and hum.RigType == Enum.HumanoidRigType.R15, "Needs an R15 character.")

hum.RequiresNeck = false
hum.BreakJointsOnDeath = false

local loaded = InsertService:LoadAsset(ASSET_ID)
local src = loaded:FindFirstChildWhichIsA("Model")
assert(src, "The body model did not load.")

local JOINT = { LowerTorso = "Root", UpperTorso = "Waist" }
for _, s in ipairs({ "Left", "Right" }) do
	JOINT[s .. "UpperArm"] = s .. "Shoulder"
	JOINT[s .. "LowerArm"] = s .. "Elbow"
	JOINT[s .. "Hand"] = s .. "Wrist"
	JOINT[s .. "UpperLeg"] = s .. "Hip"
	JOINT[s .. "LowerLeg"] = s .. "Knee"
	JOINT[s .. "Foot"] = s .. "Ankle"
end

-- The importer turns the skeleton into Motor6Ds: C0 = the joint in the parent part, C1 = in the child part.
local joints = {}
for _, m in ipairs(src:GetDescendants()) do
	if m:IsA("Motor6D") and m.Part1 and JOINT[m.Part1.Name] then
		joints[JOINT[m.Part1.Name]] = { parent = m.Part0.Name, c0 = m.C0.Position, c1 = m.C1.Position }
	end
end

local function place(att: Attachment, pos: Vector3)
	att.Position = pos
	local original = att:FindFirstChild("OriginalPosition")
	if original and original:IsA("Vector3Value") then
		original.Value = pos
	end
end

local skin = char.Head.Color
for _, x in ipairs(char:GetChildren()) do
	if x:IsA("Shirt") or x:IsA("Pants") or x:IsA("ShirtGraphic") or x:IsA("BodyColors") then
		x:Destroy()
	elseif x:IsA("Accessory") then
		local handle = x:FindFirstChild("Handle")
		local att = handle and handle:FindFirstChildOfClass("Attachment")
		if not (att and char.Head:FindFirstChild(att.Name)) or (handle and handle:FindFirstChildOfClass("WrapLayer")) then
			x:Destroy()
		end
	end
end

for partName, jointName in pairs(JOINT) do
	local old = char[partName]
	local new = src[partName]:Clone()
	for _, d in ipairs(new:GetChildren()) do
		d:Destroy()
	end
	for _, a in ipairs(old:GetChildren()) do
		if a:IsA("Attachment") then
			local c = a:Clone()
			c.Parent = new
			place(c, a.Position * (new.Size / old.Size))
		end
	end
	place(new:FindFirstChild(jointName .. "RigAttachment") :: Attachment, joints[jointName].c1)
	new.Color = skin
	new.Anchored = false
	new.CanCollide = old.CanCollide
	local originalSize = Instance.new("Vector3Value")
	originalSize.Name = "OriginalSize"
	originalSize.Value = new.Size
	originalSize.Parent = new
	hum:ReplaceBodyPartR15(Enum.BodyPartR15[partName], new)
end
for jointName, j in pairs(joints) do
	if j.parent ~= "RootPart" then
		place(char[j.parent]:FindFirstChild(jointName .. "RigAttachment"), j.c0)
	end
end
place(char.UpperTorso.NeckRigAttachment, NECK)
local neckAccessoryMark = char.UpperTorso:FindFirstChild("NeckAttachment")
if neckAccessoryMark then
	place(neckAccessoryMark, NECK)
end
hum:BuildRigFromAttachments()
local headScale = hum:FindFirstChild("HeadScale")
if headScale then
	headScale.Value = HEAD_SCALE
end
hum.HipHeight = HIP_HEIGHT
loaded:Destroy()
print("[LifterBody01_SwapTest] SUCCESS: new body on " .. player.Name .. " (play session only)")
