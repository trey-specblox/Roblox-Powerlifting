--!strict
--[[
	BuildParts
	Server / World

	The small part-making helpers shared by StarterGymBuilder and RoomProps,
	so both build parts exactly the same way. Every part is anchored; sizes are
	in studs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StarterGymConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StarterGymConfig"))

local BuildParts = {}

-- An anchored, solid part of `size` at `cframe` (a Part, or e.g. a WedgePart for the gables).
function BuildParts.placed(parent: Instance, name: string, size: Vector3, cframe: CFrame, look: StarterGymConfig.Look,
	className: string?): BasePart
	local part = Instance.new(className or "Part") :: BasePart
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = look.material
	if look.variant then
		part.MaterialVariant = look.variant -- a textured material (StarterGymConfig.MaterialVariants)
	end
	part.Color = look.color
	part.Transparency = look.transparency or 0
	part.Reflectance = look.reflectance or 0
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

-- An axis-aligned box between two corners.
function BuildParts.box(parent: Instance, name: string, low: Vector3, high: Vector3, look: StarterGymConfig.Look): BasePart
	return BuildParts.placed(parent, name, high - low, CFrame.new((low + high) / 2), look)
end

-- A light-giving face on a part (SurfaceLight), in the gym's clean white unless `color` is given.
function BuildParts.surfaceLight(part: BasePart, face: Enum.NormalId, range: number, brightness: number, angle: number,
	color: Color3?)
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Range = range
	light.Brightness = brightness
	light.Angle = angle
	light.Color = color or StarterGymConfig.LightColor
	light.Shadows = false
	light.Parent = part
end

--[[
	Decoration (items on shelves and desks, cables, turnstile arms, wall
	coverings): not solid, so it never snags a player, ignored by spatial checks
	and touch events.

	PERFORMANCE (user 2026-10-28: "optimize everything"): a small piece (no side
	longer than SHADOW_MIN_SIZE studs) or a flat one (thinner than SHADOW_FLAT
	studs: wall coverings, stripes, signs) casts no shadow. Their shadows are too
	small to see or fall onto the wall they cover, and in the 2026-10-28 audit
	they were 3,633 of the world's 5,876 shadow casters. Bigger decor (sofas,
	machines) keeps its shadow.
]]
local SHADOW_MIN_SIZE = 4
local SHADOW_FLAT = 0.15
function BuildParts.decor(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local size = part.Size
	if math.max(size.X, size.Y, size.Z) <= SHADOW_MIN_SIZE or math.min(size.X, size.Y, size.Z) <= SHADOW_FLAT then
		part.CastShadow = false
	end
	part:SetAttribute("Decor", true)
	return part
end

-- True when every piece of an uploaded image (StarterGymConfig.ImagePiece) has its ID.
function BuildParts.piecesReady(pieces: { StarterGymConfig.ImagePiece }): boolean
	if #pieces == 0 then
		return false
	end
	for _, piece in ipairs(pieces) do
		if piece.image == "" then
			return false
		end
	end
	return true
end

-- The pieces side by side in `frame`, left to right, each as wide as its share
-- of the picture, so together they fill the frame as one image.
function BuildParts.addImagePieces(frame: GuiObject, pieces: { StarterGymConfig.ImagePiece })
	local totalPixels = 0
	for _, piece in ipairs(pieces) do
		totalPixels += piece.widthPixels
	end
	local before = 0
	for index, piece in ipairs(pieces) do
		local image = Instance.new("ImageLabel")
		image.Name = string.format("Piece_%d", index)
		image.Position = UDim2.fromScale(before / totalPixels, 0)
		image.Size = UDim2.fromScale(piece.widthPixels / totalPixels, 1)
		image.BackgroundTransparency = 1
		image.Image = piece.image
		image.ScaleType = Enum.ScaleType.Stretch
		image.Parent = frame
		before += piece.widthPixels
	end
end

return BuildParts
