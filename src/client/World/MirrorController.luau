--!strict
--[[
	MirrorController
	Client / World

	Makes the gym's wall mirrors reflect (parts tagged StarterGymConfig.MirrorTag,
	with a "Facing" attribute: the direction the glass faces; built by
	RoomProps). Roblox's Reflectance only mirrors the sky, so each mirror gets a
	SurfaceGui (in this player's PlayerGui) with a ViewportFrame showing a
	mirrored copy of the room in front of it: the room's parts reflected across
	the glass, and the players' characters, copied every frame. Visual only: it
	sends nothing to the server.

	How it lines up: the mirrored room sits behind the glass, so the mirror is a
	window into it. The viewport's camera stands where this player's camera is
	and looks straight at the glass; the picture is then exactly the right size
	when the ViewportFrame is centred on the point of the glass right in front
	of the camera, and the SurfaceGui clips it to the mirror.

	Only near a mirror (MirrorRangeStuds): the copy of the room is made when the
	camera comes near (the room has streamed in by then) and thrown away when it
	goes far away again.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StarterGymConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StarterGymConfig"))

local MirrorController = {}

local PIXELS_PER_STUD = 20
local MAX_HALF_ANGLE = math.rad(60) -- the widest the viewport's camera may see (FieldOfView 120)
local MAX_PARTS = 2500 -- the most room parts one mirror copies

-- A copy of a character in a mirror: each copied part with the original it follows.
type CharacterCopy = { model: Model, follow: { { copy: BasePart, original: BasePart } } }
type Mirror = {
	part: BasePart,
	normal: Vector3, -- the way the glass faces
	right: Vector3, -- left to right across the glass, as you face it
	centre: Vector3, -- the middle of the glass's face
	width: number,
	height: number,
	gui: SurfaceGui?,
	viewport: ViewportFrame?,
	camera: Camera?,
	world: WorldModel?,
	characters: { [Model]: CharacterCopy },
}

local mirrors: { [BasePart]: Mirror } = {}
local started = false

-- The face of an unrotated part that looks toward `direction`.
local function faceToward(direction: Vector3): Enum.NormalId
	if math.abs(direction.X) > 0.5 then
		return if direction.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	elseif math.abs(direction.Z) > 0.5 then
		return if direction.Z > 0 then Enum.NormalId.Back else Enum.NormalId.Front
	end
	return if direction.Y > 0 then Enum.NormalId.Top else Enum.NormalId.Bottom
end

-- How far a part reaches along a world direction (its size seen along that direction).
local function extentAlong(part: BasePart, direction: Vector3): number
	local cf, size = part.CFrame, part.Size
	return math.abs(cf.RightVector:Dot(direction)) * size.X + math.abs(cf.UpVector:Dot(direction)) * size.Y
		+ math.abs(cf.LookVector:Dot(direction)) * size.Z
end

-- `cf` reflected across the glass's plane (through `point`, facing `normal`). A reflection turns
-- right-handed into left-handed, which a CFrame cannot be, so the copy is also flipped along its own X:
-- the same for symmetric parts, and writing on a copy reads the right way round.
local function reflect(cf: CFrame, point: Vector3, normal: Vector3): CFrame
	local function mirrored(v: Vector3): Vector3
		return v - 2 * v:Dot(normal) * normal
	end
	local position = cf.Position - 2 * (cf.Position - point):Dot(normal) * normal
	return CFrame.fromMatrix(position, -mirrored(cf.RightVector), mirrored(cf.UpVector), mirrored(-cf.LookVector))
end

local function characterOf(instance: Instance): Model?
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and instance:IsDescendantOf(player.Character) then
			return player.Character
		end
	end
	return nil
end

-- A part copied into the mirror: anchored, not solid, nothing that runs or makes light or sound.
local function strip(copy: Instance)
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Light") or d:IsA("Sound") or d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter")
			or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
end

-- Copies the room in front of the glass into the mirror's world, reflected.
local function copyRoom(mirror: Mirror, world: WorldModel)
	local cfg = StarterGymConfig
	local depth, side = cfg.MirrorDepthStuds, cfg.MirrorSideStuds
	local box = CFrame.lookAt(mirror.centre + mirror.normal * (depth / 2), mirror.centre + mirror.normal * depth)
	local size = Vector3.new(mirror.width + 2 * side, cfg.MirrorHeightStuds, depth)
	local copied = 0
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, size)) do
		if copied >= MAX_PARTS then
			break
		end
		if part ~= mirror.part and part.Transparency < 0.99 and part.Archivable
			and (part.Position - mirror.centre):Dot(mirror.normal) > 0.2 and characterOf(part) == nil then
			local copy = part:Clone()
			strip(copy)
			copy.Anchored = true
			copy.CanCollide = false
			copy.CFrame = reflect(part.CFrame, mirror.centre, mirror.normal)
			copy.Parent = world
			copied += 1
		end
	end
end

local function copyCharacter(character: Model, world: WorldModel): CharacterCopy?
	local was = character.Archivable
	character.Archivable = true
	local model = character:Clone() :: Model?
	character.Archivable = was
	if model == nil then
		return nil
	end
	strip(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- Each copied part follows the original at the same path of names (some of a character's
	-- children are not cloned, so the two are not in the same order).
	local follow = {}
	for _, copy in ipairs(model:GetDescendants()) do
		if copy:IsA("BasePart") then
			local path, at = {}, copy :: Instance
			while at ~= model do
				table.insert(path, 1, at.Name)
				at = at.Parent :: Instance
			end
			local original: Instance? = character
			for _, name in ipairs(path) do
				original = original and original:FindFirstChild(name)
			end
			copy.Anchored = true
			copy.CanCollide = false
			if original and original:IsA("BasePart") then
				table.insert(follow, { copy = copy, original = original })
			end
		end
	end
	model.Parent = world
	return { model = model, follow = follow }
end

local function build(mirror: Mirror)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Mirror_" .. mirror.part.Name
	gui.Adornee = mirror.part
	gui.Face = faceToward(mirror.part.CFrame:VectorToObjectSpace(mirror.normal))
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(165, 165, 168)
	viewport.LightColor = Color3.fromRGB(255, 252, 245)
	viewport.LightDirection = Vector3.new(0.2, -1, 0.3)
	viewport.Parent = gui
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	-- A faint tint over everything, so it reads as glass.
	local tint = Instance.new("Frame")
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = Color3.fromRGB(200, 222, 236)
	tint.BackgroundTransparency = 0.9
	tint.BorderSizePixel = 0
	tint.ZIndex = 2
	tint.Parent = gui
	copyRoom(mirror, world)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	mirror.gui, mirror.viewport, mirror.camera, mirror.world = gui, viewport, camera, world
end

local function tearDown(mirror: Mirror)
	if mirror.gui then
		mirror.gui:Destroy()
	end
	mirror.gui, mirror.viewport, mirror.camera, mirror.world = nil, nil, nil, nil
	mirror.characters = {}
end

-- Keeps every nearby player's copy in step with them, and drops the copies of those who left.
local function updateCharacters(mirror: Mirror, world: WorldModel)
	local seen: { [Model]: boolean } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local out = (root.Position - mirror.centre):Dot(mirror.normal)
			if out > 0 and out < StarterGymConfig.MirrorDepthStuds then
				seen[character] = true
				local copy: CharacterCopy? = mirror.characters[character]
				if copy == nil then
					copy = copyCharacter(character, world)
					if copy then
						mirror.characters[character] = copy
					end
				end
				if copy then
					for _, pair in ipairs(copy.follow) do
						pair.copy.CFrame = reflect(pair.original.CFrame, mirror.centre, mirror.normal)
					end
				end
			end
		end
	end
	for character, copy in pairs(mirror.characters) do
		if not seen[character] then
			copy.model:Destroy()
			mirror.characters[character] = nil
		end
	end
end

local function update()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local range = StarterGymConfig.MirrorRangeStuds
	for _, mirror in pairs(mirrors) do
		local distance = (eye - mirror.centre):Dot(mirror.normal)
		local across = math.abs((eye - mirror.centre):Dot(mirror.right))
		local near = distance > 0.3 and distance < range and across < mirror.width / 2 + range
		if not near then
			if mirror.gui and (distance > range + 20 or across > mirror.width / 2 + range + 20) then
				tearDown(mirror)
			elseif mirror.gui then
				mirror.gui.Enabled = false
			end
			continue
		end
		if mirror.gui == nil then
			build(mirror)
		end
		local gui, viewport, view, world = mirror.gui :: SurfaceGui, mirror.viewport :: ViewportFrame, mirror.camera :: Camera,
			mirror.world :: WorldModel
		gui.Enabled = true
		updateCharacters(mirror, world)
		-- Where the camera is in front of the glass: u from its left edge, v down from its top (studs).
		local topLeft = mirror.centre - mirror.right * (mirror.width / 2) + Vector3.yAxis * (mirror.height / 2)
		local foot = eye - mirror.normal * distance
		local u, v = (foot - topLeft):Dot(mirror.right), (topLeft - foot).Y
		local half = math.max(math.abs(u), math.abs(mirror.width - u), math.abs(v), math.abs(mirror.height - v))
		half = math.min(half, distance * math.tan(MAX_HALF_ANGLE))
		viewport.Position = UDim2.fromOffset((u - half) * PIXELS_PER_STUD, (v - half) * PIXELS_PER_STUD)
		viewport.Size = UDim2.fromOffset(2 * half * PIXELS_PER_STUD, 2 * half * PIXELS_PER_STUD)
		view.FieldOfView = math.deg(2 * math.atan(half / distance))
		view.CFrame = CFrame.lookAt(eye, eye - mirror.normal)
	end
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") or mirrors[instance] then
		return
	end
	local facing = instance:GetAttribute("Facing")
	if typeof(facing) ~= "Vector3" then
		warn(string.format("[MirrorController] %s has no Facing attribute", instance:GetFullName()))
		return
	end
	local normal = facing.Unit
	local right = (-normal):Cross(Vector3.yAxis).Unit
	mirrors[instance] = {
		part = instance,
		normal = normal,
		right = right,
		centre = instance.Position + normal * (extentAlong(instance, normal) / 2),
		width = extentAlong(instance, right),
		height = extentAlong(instance, Vector3.yAxis),
		characters = {},
	}
end

local function untrack(instance: Instance)
	local mirror = mirrors[instance :: BasePart]
	if mirror then
		tearDown(mirror)
		mirrors[instance :: BasePart] = nil
	end
end

function MirrorController.start()
	if started then
		return
	end
	started = true
	local tag = StarterGymConfig.MirrorTag
	for _, mirror in ipairs(CollectionService:GetTagged(tag)) do
		track(mirror)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
	RunService.RenderStepped:Connect(update)
end

return MirrorController
