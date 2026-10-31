--!strict
--[[
	WornGearFit
	Server / Economy

	Fits the worn gear models onto R15 bodies (GAME_DESIGN.md 30.6, the money
	system's step 5). No saving, no remotes: GearService decides what is worn,
	this only builds it, so a dev probe can test the fitting with a stand-in
	model (src/server/Dev/WornGearProbe.server.luau).

		fromModel  reads the uploaded model: where each piece sits relative to
		           its joint (knee, wrist, ...), worked out from three anchor pieces
		           (WornGearConfig.Anchors), so the import's own turn or shift
		           does not matter
		dress      rebuilds a character's WornGear folder: each piece cloned,
		           coloured in its item's ShopConfig colours, placed from the
		           wearer's own joint mark (rig attachment), welded to its body
		           part and scaled with the part's size (limb pieces on both
		           sides), so it fits any R15 body shape. Looks only: no mass, collision, touch, query or shadow.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local WornGearConfig = require(ConfigFolder:WaitForChild("WornGearConfig"))

local WornGearFit = {}

-- One worn piece, ready to clone: where it sits relative to its joint (right side, default body).
export type Piece = {
	template: BasePart,
	colourKey: string,
	part: string,
	joint: string,
	limb: boolean,
	relative: CFrame,
}

-- Pieces by worn model ("WornLeverBelt", ...).
export type Pieces = { [string]: { Piece } }

--[[
	Reads the pieces out of a loaded copy of the worn gear model (the parts are
	taken out of it). Errors when an anchor piece is missing.
]]
function WornGearFit.fromModel(model: Instance): (Pieces, number)
	local byName: { [string]: BasePart } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			byName[d.Name] = d
		end
	end
	local anchors = WornGearConfig.Anchors
	local centrePart, frontPart, upPart = byName[anchors.centre.piece], byName[anchors.front.piece], byName[anchors.up.piece]
	assert(centrePart and frontPart and upPart, "anchor pieces missing")
	-- The turn that takes the anchors' known directions (as modelled) to where they are in the loaded model.
	local function basis(upward: Vector3, frontward: Vector3): CFrame
		local e1 = upward.Unit
		local e2 = (frontward - e1 * frontward:Dot(e1)).Unit
		return CFrame.fromMatrix(Vector3.zero, e1, e2, e1:Cross(e2))
	end
	local at = anchors.centre.at
	local c = centrePart.Position
	local modelled = basis(anchors.up.at - at, anchors.front.at - at)
	local found = basis(upPart.Position - c, frontPart.Position - c)
	-- The HumanoidRootPart of the body the model was fitted to.
	local frame = CFrame.new(c) * (found * modelled:Inverse()) * CFrame.new(-at)

	local result: Pieces = {}
	local count = 0
	for _, slot in ipairs(WornGearConfig.Slots) do
		local list: { Piece } = {}
		for name, part in pairs(byName) do
			local wornName, colourKey, segment = string.match(name, "^(%a+)_(%a+)_?(%a*)$")
			local place = if wornName == slot.worn then slot.parts[segment or ""] else nil
			local jointAt = place and WornGearConfig.Joints[place.joint]
			if place and jointAt and WornGearConfig.DefaultBody[place.part] and colourKey then
				part.Anchored = true
				part.Parent = nil
				table.insert(list, {
					template = part,
					colourKey = colourKey,
					part = place.part,
					joint = place.joint,
					limb = WornGearConfig.LimbParts[place.part] == true,
					relative = CFrame.new(-jointAt) * frame:ToObjectSpace(part.CFrame),
				})
				count += 1
			end
		end
		result[slot.worn] = list
	end
	return result, count
end

-- The same placement on the other side of the body (a mirror across X; the pieces are symmetric).
function WornGearFit.mirrored(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- A piece's size on a part scaled by `scale` (per part axis): each piece axis takes the scale of the part axis it lies along.
local function scaledSize(size: Vector3, rotation: CFrame, scale: Vector3): Vector3
	local function along(axis: Vector3): number
		local v = rotation:VectorToWorldSpace(axis)
		local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
		return if ax >= ay and ax >= az then scale.X elseif ay >= az then scale.Y else scale.Z
	end
	return Vector3.new(size.X * along(Vector3.xAxis), size.Y * along(Vector3.yAxis), size.Z * along(Vector3.zAxis))
end

--[[
	Rebuilds the character's worn gear: `worn` is slot -> item id (already
	checked as owned). Removes the old folder first; builds nothing on a
	non-R15 body. Returns how many pieces it made.
]]
function WornGearFit.dress(character: Model, worn: { [string]: string }, pieces: Pieces): number
	local old = character:FindFirstChild(WornGearConfig.FolderName)
	if old then
		old:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 or next(worn) == nil then
		return 0
	end
	local folder = Instance.new("Folder")
	folder.Name = WornGearConfig.FolderName
	local made = 0
	for _, slot in ipairs(WornGearConfig.Slots) do
		local itemId = worn[slot.id]
		local item = if itemId then ShopConfig.find(itemId) else nil
		if item and item.category == slot.category then
			local list: { Piece } = pieces[slot.worn] or {}
			for _, info in ipairs(list) do
				local default = WornGearConfig.DefaultBody[info.part]
				local sides: { string } = if info.limb then { "Right", "Left" } else { "" }
				for _, side in ipairs(sides) do
					local bodyPart = character:FindFirstChild(side .. info.part)
					if bodyPart and bodyPart:IsA("BasePart") then
						local scale = bodyPart.Size / default.size
						local relative = if side == "Left" then WornGearFit.mirrored(info.relative) else info.relative
						local rotation = relative - relative.Position
						-- From the wearer's own joint mark; without one, from where the joint would be on a
						-- default body of this part's size.
						local mark = bodyPart:FindFirstChild(side .. info.joint .. "RigAttachment")
						local joint: Vector3
						if mark and mark:IsA("Attachment") then
							joint = mark.Position
						else
							joint = (WornGearConfig.Joints[info.joint] - default.centre) * scale
							if side == "Left" then
								joint = Vector3.new(-joint.X, joint.Y, joint.Z)
							end
						end
						local offset = CFrame.new(joint + relative.Position * scale) * rotation
						local piece = info.template:Clone()
						piece.Name = string.format("%s_%s%s", item.id, side, info.template.Name)
						piece.Size = scaledSize(info.template.Size, rotation, scale)
						piece.Color = item.colours[info.colourKey] or WornGearConfig.FallbackColour
						piece.Material = WornGearConfig.Materials[info.colourKey] or Enum.Material.Fabric
						piece.Anchored = false
						piece.CanCollide = false
						piece.CanTouch = false
						piece.CanQuery = false
						piece.Massless = true
						piece.CastShadow = false
						piece.CFrame = bodyPart.CFrame * offset
						local weld = Instance.new("Weld")
						weld.Part0 = bodyPart
						weld.Part1 = piece
						weld.C0 = offset
						weld.Parent = piece
						piece.Parent = folder
						made += 1
					end
				end
			end
		end
	end
	folder.Parent = character
	return made
end

return WornGearFit
