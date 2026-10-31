--!strict
--[[
	WornGearConfig
	Shared / Config

	Wearing the Shop's gear (GAME_DESIGN.md 30.6, the money system's step 5;
	user 2026-10-30): one item per slot, worn as 3D models on R15 bodies,
	always visible, put on and taken off anywhere from MY GEAR. Looks only.

	The worn models are one uploaded asset (art/blender/WornGear_01.blend,
	built by art/scripts/build_worn_gear_01.py) whose pieces are named
	"Worn<Item>_<ShopConfig colour key>[_<Segment>]". The server welds each
	piece to one body part and scales it with that part's size; limb pieces
	are modelled on the right limb and worn on both.
]]

local WornGearConfig = {}

-- The group Model asset with every worn piece (art/exports/WornGear_01.glb, materials.json "WornGear_01"; 0 would
-- mean not uploaded: the gear is then saved and chosen, but not drawn).
WornGearConfig.AssetId = 115016229826377

-- Folder in the character that holds the worn pieces (rebuilt whenever what is worn changes).
WornGearConfig.FolderName = "WornGear"

export type Slot = {
	id: string,
	-- The ShopConfig category whose items go in this slot.
	category: string,
	label: string,
	-- The worn model's pieces start with this name.
	worn: string,
	-- Which R15 part each piece segment sits on ("" = pieces with no segment), and the joint it is placed from
	-- (WornGearConfig.Joints). A limb part (no Left/Right) is worn on both sides.
	parts: { [string]: { part: string, joint: string } },
}

-- In MY GEAR's order.
WornGearConfig.Slots = {
	{ id = "Singlet", category = "SINGLETS", label = "SINGLET", worn = "WornSinglet", parts = {
		Upper = { part = "UpperTorso", joint = "Neck" },
		Lower = { part = "LowerTorso", joint = "Waist" },
		Leg = { part = "UpperLeg", joint = "Hip" },
	} },
	{ id = "Belt", category = "BELTS", label = "BELT", worn = "WornLeverBelt",
		parts = { [""] = { part = "LowerTorso", joint = "Waist" } } },
	{ id = "KneeSleeves", category = "KNEE SLEEVES", label = "KNEE SLEEVES", worn = "WornKneeSleeve", parts = {
		Upper = { part = "UpperLeg", joint = "Knee" },
		Lower = { part = "LowerLeg", joint = "Knee" },
	} },
	{ id = "WristWraps", category = "WRIST WRAPS", label = "WRIST WRAPS", worn = "WornWristWrap",
		parts = { [""] = { part = "LowerArm", joint = "Wrist" } } },
} :: { Slot }

-- R15 parts that come in a Left and a Right.
WornGearConfig.LimbParts = { UpperArm = true, LowerArm = true, Hand = true, UpperLeg = true, LowerLeg = true, Foot = true }

--[[
	The default R15 body the models were fitted to (measured in Studio,
	2026-10-30): each part's size and centre relative to the HumanoidRootPart,
	right-hand side for limbs. A piece is scaled by the wearer's part size /
	this size (and placed from the part's centre if a joint mark is missing).
]]
WornGearConfig.DefaultBody = {
	UpperTorso = { size = Vector3.new(1.943, 1.698, 1.004), centre = Vector3.new(0, 0.249, 0) },
	LowerTorso = { size = Vector3.new(1.991, 0.401, 1.004), centre = Vector3.new(0, -0.800, 0) },
	UpperArm = { size = Vector3.new(1.001, 1.242, 1.002), centre = Vector3.new(1.472, 0.428, 0) },
	LowerArm = { size = Vector3.new(1.001, 1.118, 1.002), centre = Vector3.new(1.472, -0.202, 0) },
	UpperLeg = { size = Vector3.new(0.993, 1.363, 0.973), centre = Vector3.new(0.500, -1.471, 0) },
	LowerLeg = { size = Vector3.new(0.993, 1.301, 0.973), centre = Vector3.new(0.500, -2.334, 0) },
}

--[[
	The joints pieces are placed from, on the default body (relative to the
	HumanoidRootPart, right side for limbs). Every R15 avatar marks them with
	rig attachments ("<Side><Joint>RigAttachment" in the body part, e.g.
	RightKneeRigAttachment in RightUpperLeg and in RightLowerLeg; the torso's
	have no side), so a piece sits at the wearer's real joint whatever the
	shape of their body: a knee sleeve's two halves always meet at the knee.
	Measured in Studio, 2026-10-30.
]]
WornGearConfig.Joints = {
	Neck = Vector3.new(0, 1.098, 0),
	Waist = Vector3.new(0, -0.600, 0),
	Hip = Vector3.new(0.500, -1.000, 0),
	Knee = Vector3.new(0.500, -1.921, 0),
	Wrist = Vector3.new(1.472, -0.734, 0),
}

--[[
	Three pieces whose centres the build script printed (relative to the
	HumanoidRootPart, Roblox axes), used to find how the uploaded model lies
	once loaded: the belt's middle, its buckle (to the front, -Z) and the
	singlet's trim (up, +Y).
]]
WornGearConfig.Anchors = {
	centre = { piece = "WornLeverBelt_Outer", at = Vector3.new(0, -0.800, 0) },
	front = { piece = "WornLeverBelt_Lever", at = Vector3.new(0.015, -0.800, -0.722) },
	up = { piece = "WornSinglet_Trim_Upper", at = Vector3.new(0, 0.684, 0) },
}

-- Materials by colour key; any other key is Fabric.
WornGearConfig.Materials = {
	Lever = Enum.Material.Metal,
	Text = Enum.Material.SmoothPlastic,
	Patch = Enum.Material.SmoothPlastic,
} :: { [string]: Enum.Material }
-- A colour key the item does not list keeps this.
WornGearConfig.FallbackColour = Color3.fromRGB(24, 24, 26)

-- The GEAR tab's key.
WornGearConfig.OpenKey = Enum.KeyCode.Y

function WornGearConfig.slot(id: string): Slot?
	for _, slot in ipairs(WornGearConfig.Slots) do
		if slot.id == id then
			return slot
		end
	end
	return nil
end

-- The slot a ShopConfig category goes in, or nil.
function WornGearConfig.slotForCategory(category: string): Slot?
	for _, slot in ipairs(WornGearConfig.Slots) do
		if slot.category == category then
			return slot
		end
	end
	return nil
end

return WornGearConfig
