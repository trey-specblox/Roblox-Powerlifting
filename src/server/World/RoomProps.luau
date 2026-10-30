--!strict
--[[
	RoomProps
	Server / World

	The furniture and equipment in the Starter Gym's rooms (GAME_DESIGN.md §27
	"What is in the rooms", approved by the user 2026-10-23). Step 6a: the
	ground floor. Decoration only: nothing here has gameplay. Built by
	StarterGymBuilder after the rooms exist, into Workspace.StarterGym.Props,
	one folder per room.

	Every room is furnished in its own frame (a Kit):
	  a  across the room, -W/2 .. W/2 (seen from the room's door);
	  d  from the wall with the room's door (0) to the opposite wall (D);
	  y  up from the floor.
	The usable box stays INSET studs inside the room's region, so nothing
	touches a wall. Furniture against a wall is written along that wall
	(Kit.wall): `s` along it, `t` out from it into the room.

	Big furniture is solid; small items are decor (not solid). A solid piece
	may never stand in front of any door into the room, and nothing may leave
	the room: either mistake stops THAT room with a warning (its furniture is
	left out) while the rest of the gym is still built.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local StarterGymConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StarterGymConfig"))
local WeightClassConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WeightClassConfig"))
local CardioRhythmConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CardioRhythmConfig"))
local MockMeetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MockMeetConfig"))
local GymRecordsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GymRecordsConfig"))
local BuildParts = require(script.Parent:WaitForChild("BuildParts"))
local StyledScreen = require(script.Parent:WaitForChild("StyledScreen"))

local RoomProps = {}

local INSET = 0.55 -- keeps furniture 0.05 off a wall whose centre line is the room's edge
local DOOR_HALF_CLEAR = 4.5 -- a door is 6 wide: keep 1.5 more on each side clear
local DOOR_DEPTH_CLEAR = 7 -- and this far into the room
local looks = StarterGymConfig.Looks
local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(30, 34, 44)

type Look = StarterGymConfig.Look
type BoxFn = (name: string, a0: number, a1: number, d0: number, d1: number, y0: number, y1: number, look: Look) -> BasePart
type WallBoxFn = (name: string, s0: number, s1: number, t0: number, t1: number, y0: number, y1: number, look: Look) -> BasePart
type Wall = {
	out: Vector3, -- world direction from the wall into the room
	axis: string, -- the Kit axis `s` runs along ("a" or "d")
	at: (s: number, t: number) -> (number, number), -- wall coordinates to (a, d)
	block: WallBoxFn,
	item: WallBoxFn,
}
type Kit = {
	W: number,
	D: number,
	H: number, -- just under the ceiling
	doorA: number, -- where the room's own door is, across
	block: BoxFn, -- solid
	item: BoxFn, -- decor
	-- A decor cylinder centred at (a, d, y), its length along "up", "a" or "d".
	cylinder: (name: string, a: number, d: number, y: number, length: number, diameter: number, axis: string,
		look: Look) -> BasePart,
	ball: (name: string, a: number, d: number, y: number, diameter: number, look: Look) -> BasePart,
	wall: (which: string) -> Wall, -- "back", "front" (the door's wall), "left" (a = -W/2) or "right" (a = W/2)
	-- The world direction of "+d", "-d" (toward the door), "+a" or "-a".
	toward: (direction: string) -> Vector3,
	-- Where the doors in each wall are, along it (its `s`): "front", "back", "left", "right".
	doors: { [string]: { number } },
	-- A copy of a model template (decor), its pivot at (a, d, y), its front
	-- (the pivot's LookVector) toward `facing`, stretched to `stretch` (width,
	-- height, depth) when given. It must stay inside the room.
	place: (name: string, template: Model, a: number, d: number, y: number, facing: string, stretch: Vector3?) -> Model,
}
type Zone = { a0: number, a1: number, d0: number, d1: number }

--[[
	Stretches a copy of a prop template (still unturned, as cloned) so its bounds
	become `size` (width, height, depth), about its pivot (the bottom centre):
	every piece keeps its place in the whole, so one mesh serves every desk or
	shelf size. The pieces from Blender may be turned, so each piece's own axes
	are matched to the template's.
]]
local function stretchTo(copy: Model, size: Vector3)
	local pivot = copy:GetPivot()
	local _, now = copy:GetBoundingBox()
	local scale = size / now
	local function along(axis: Vector3): number
		return math.abs(axis.X) * scale.X + math.abs(axis.Y) * scale.Y + math.abs(axis.Z) * scale.Z
	end
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(part.CFrame)
			part.Size = part.Size * Vector3.new(along(rel.RightVector), along(rel.UpVector), along(rel.LookVector))
			part.CFrame = pivot * CFrame.new(rel.Position * scale) * rel.Rotation
		end
	end
end

-- The 3D props, defined with the props further down and used by the furniture helpers before them.
local propsFor: (items: { string }) -> { [string]: Model }?
local propItem: (kit: Kit, templates: { [string]: Model }, name: string, item: string, colourway: number, a: number,
	d: number, y: number, facing: string, stretch: Vector3?) -> Model
local hidden: (part: BasePart) -> BasePart

-- The face of an unrotated part that looks toward `direction`.
local function faceToward(direction: Vector3): Enum.NormalId
	if math.abs(direction.X) > 0.5 then
		return if direction.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	elseif math.abs(direction.Z) > 0.5 then
		return if direction.Z > 0 then Enum.NormalId.Back else Enum.NormalId.Front
	end
	return if direction.Y > 0 then Enum.NormalId.Top else Enum.NormalId.Bottom
end

-- Paints the pieces of a placed prop ("<item>_<Piece>") named in `pieces` like blocks of those looks, so a
-- counter or table top keeps the room's own surfaces (tiles, planks, marble) and their textures.
local function paintLooks(copy: Model, item: string, pieces: { [string]: Look })
	for _, part in ipairs(copy:GetDescendants()) do
		local look = if part:IsA("BasePart") then pieces[string.sub(part.Name, #item + 2)] else nil
		if look then
			local basePart = part :: BasePart
			basePart.Material = look.material
			basePart.MaterialVariant = look.variant or ""
			basePart.Color = look.color
			basePart.Transparency = look.transparency or 0
			basePart.Reflectance = look.reflectance or 0
		end
	end
end

local function kitFor(folder: Folder, room: BasePart, doorSpots: { Vector3 }): Kit
	local centre, size = room.Position, room.Size
	local low, high = centre - size / 2, centre + size / 2
	local door = room:GetAttribute("DoorCentre") :: Vector3
	local alongX = room:GetAttribute("DoorAlongX") :: boolean
	local inward = if alongX
		then Vector3.new(0, 0, math.sign(centre.Z - door.Z))
		else Vector3.new(math.sign(centre.X - door.X), 0, 0)
	local right = inward:Cross(Vector3.yAxis)
	local usable = Vector3.new(size.X - 2 * INSET, 0, size.Z - 2 * INSET)
	local W = math.abs(usable:Dot(right))
	local D = math.abs(usable:Dot(inward))
	local H = size.Y - StarterGymConfig.CeilingThicknessStuds - 0.05 -- just under the ceiling
	local origin = Vector3.new(centre.X, low.Y, centre.Z) - inward * (D / 2)
	local function world(a: number, d: number, y: number): Vector3
		return origin + right * a + inward * d + Vector3.yAxis * y
	end
	local function toLocal(point: Vector3): (number, number)
		local offset = point - origin
		return offset:Dot(right), offset:Dot(inward)
	end

	-- Keep-clear zones in front of every door into this room (its own, and a
	-- neighbour's door in one of its walls), on the nearest wall.
	local zones: { Zone } = {}
	local doors: { [string]: { number } } = { front = {}, back = {}, left = {}, right = {} }
	for _, spot in ipairs(doorSpots) do
		if spot.X >= low.X - 0.7 and spot.X <= high.X + 0.7 and spot.Z >= low.Z - 0.7 and spot.Z <= high.Z + 0.7
			and spot.Y > low.Y and spot.Y < high.Y then
			local a, d = toLocal(spot)
			local toFront, toBack, toLeft, toRight = math.abs(d), math.abs(D - d), math.abs(a + W / 2), math.abs(W / 2 - a)
			local nearest = math.min(toFront, toBack, toLeft, toRight)
			if nearest == toFront then
				table.insert(zones, { a0 = a - DOOR_HALF_CLEAR, a1 = a + DOOR_HALF_CLEAR, d0 = 0, d1 = DOOR_DEPTH_CLEAR })
				table.insert(doors.front, a)
			elseif nearest == toBack then
				table.insert(zones, { a0 = a - DOOR_HALF_CLEAR, a1 = a + DOOR_HALF_CLEAR, d0 = D - DOOR_DEPTH_CLEAR, d1 = D })
				table.insert(doors.back, a)
			elseif nearest == toLeft then
				table.insert(zones, { a0 = -W / 2, a1 = -W / 2 + DOOR_DEPTH_CLEAR, d0 = d - DOOR_HALF_CLEAR, d1 = d + DOOR_HALF_CLEAR })
				table.insert(doors.left, d)
			else
				table.insert(zones, { a0 = W / 2 - DOOR_DEPTH_CLEAR, a1 = W / 2, d0 = d - DOOR_HALF_CLEAR, d1 = d + DOOR_HALF_CLEAR })
				table.insert(doors.right, d)
			end
		end
	end
	local doorA = toLocal(door)

	local function inside(name: string, a0: number, a1: number, d0: number, d1: number, y0: number, y1: number)
		local e = 0.001
		if a0 < -W / 2 - e or a1 > W / 2 + e or d0 < -e or d1 > D + e or y0 < -e or y1 > H + e
			or a1 <= a0 or d1 <= d0 or y1 <= y0 then
			error(string.format("%s does not fit (a %.2f..%.2f of +/-%.2f, d %.2f..%.2f of %.2f, y %.2f..%.2f of %.2f)",
				name, a0, a1, W / 2, d0, d1, D, y0, y1, H), 0)
		end
	end

	local function make(name: string, a0: number, a1: number, d0: number, d1: number, y0: number, y1: number,
		look: Look, solid: boolean): BasePart
		inside(name, a0, a1, d0, d1, y0, y1)
		if solid then
			for _, zone in ipairs(zones) do
				if a0 < zone.a1 - 0.01 and a1 > zone.a0 + 0.01 and d0 < zone.d1 - 0.01 and d1 > zone.d0 + 0.01 then
					error(string.format("%s stands in front of a door", name), 0)
				end
			end
		end
		local p, q = world(a0, d0, y0), world(a1, d1, y1)
		local part = BuildParts.box(folder, name, p:Min(q), p:Max(q), look)
		if not solid then
			BuildParts.decor(part)
		end
		return part
	end

	local kit = {} :: Kit
	kit.W, kit.D, kit.H, kit.doorA, kit.doors = W, D, H, doorA, doors
	kit.block = function(name, a0, a1, d0, d1, y0, y1, look)
		return make(name, a0, a1, d0, d1, y0, y1, look, true)
	end
	kit.item = function(name, a0, a1, d0, d1, y0, y1, look)
		return make(name, a0, a1, d0, d1, y0, y1, look, false)
	end
	kit.cylinder = function(name, a, d, y, length, diameter, axis, look)
		local ha, hd, hy = diameter / 2, diameter / 2, diameter / 2
		if axis == "up" then
			hy = length / 2
		elseif axis == "a" then
			ha = length / 2
		else
			hd = length / 2
		end
		inside(name, a - ha, a + ha, d - hd, d + hd, y - hy, y + hy)
		-- A cylinder's length runs along its own X axis.
		local along = if axis == "up" then Vector3.yAxis elseif axis == "a" then right else inward
		local up = if axis == "up" then right else Vector3.yAxis
		local part = BuildParts.placed(folder, name, Vector3.new(length, diameter, diameter),
			CFrame.fromMatrix(world(a, d, y), along, up), look);
		(part :: any).Shape = Enum.PartType.Cylinder
		return BuildParts.decor(part)
	end
	kit.ball = function(name, a, d, y, diameter, look)
		local r = diameter / 2
		inside(name, a - r, a + r, d - r, d + r, y - r, y + r)
		local part = BuildParts.placed(folder, name, Vector3.one * diameter, CFrame.new(world(a, d, y)), look);
		(part :: any).Shape = Enum.PartType.Ball
		return BuildParts.decor(part)
	end
	kit.toward = function(direction)
		if direction == "+d" then
			return inward
		elseif direction == "-d" then
			return -inward
		elseif direction == "+a" then
			return right
		end
		return -right
	end
	local usableLow = Vector3.new(low.X + INSET, low.Y, low.Z + INSET)
	local usableHigh = Vector3.new(high.X - INSET, low.Y + H, high.Z - INSET)
	kit.place = function(name, template, a, d, y, facing, stretch)
		local copy = template:Clone()
		copy.Name = name
		if stretch then
			stretchTo(copy, stretch)
		end
		local position = world(a, d, y)
		copy:PivotTo(CFrame.lookAt(position, position + kit.toward(facing)))
		local box, size = copy:GetBoundingBox()
		local half = size / 2
		for _, x in ipairs({ -1, 1 }) do
			for _, yy in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					local corner = box:PointToWorldSpace(Vector3.new(x * half.X, yy * half.Y, z * half.Z))
					if corner.X < usableLow.X - 0.01 or corner.Y < usableLow.Y - 0.01 or corner.Z < usableLow.Z - 0.01
						or corner.X > usableHigh.X + 0.01 or corner.Y > usableHigh.Y + 0.01 or corner.Z > usableHigh.Z + 0.01 then
						copy:Destroy()
						error(string.format("%s does not fit in the room", name), 0)
					end
				end
			end
		end
		for _, part in ipairs(copy:GetDescendants()) do
			if part:IsA("BasePart") then
				BuildParts.decor(part)
			end
		end
		copy.Parent = folder
		return copy
	end
	kit.wall = function(which)
		local function at(s: number, t: number): (number, number)
			if which == "back" then
				return s, D - t
			elseif which == "front" then
				return s, t
			elseif which == "left" then
				return -W / 2 + t, s
			end
			return W / 2 - t, s
		end
		local function ranges(s0: number, s1: number, t0: number, t1: number): (number, number, number, number)
			local aA, dA = at(s0, t0)
			local aB, dB = at(s1, t1)
			return math.min(aA, aB), math.max(aA, aB), math.min(dA, dB), math.max(dA, dB)
		end
		return {
			out = if which == "back" then -inward elseif which == "front" then inward elseif which == "left" then right else -right,
			axis = if which == "back" or which == "front" then "a" else "d",
			at = at,
			block = function(name, s0, s1, t0, t1, y0, y1, look)
				local a0, a1, d0, d1 = ranges(s0, s1, t0, t1)
				return make(name, a0, a1, d0, d1, y0, y1, look, true)
			end,
			item = function(name, s0, s1, t0, t1, y0, y1, look)
				local a0, a1, d0, d1 = ranges(s0, s1, t0, t1)
				return make(name, a0, a1, d0, d1, y0, y1, look, false)
			end,
		}
	end
	return kit
end

-- ---------------------------------------------------------------- shared furniture

-- Text on the face of `part` that looks toward `toward`: a title and lines (a whiteboard, menu or sign).
local function writing(part: BasePart, toward: Vector3, title: string, lines: { string }, background: Color3, ink: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = faceToward(toward)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.5
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = background
	frame.Parent = gui
	local function label(text: string, x: number, y: number, width: number, height: number, weight: Enum.FontWeight)
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.Position = UDim2.fromScale(x, y)
		textLabel.Size = UDim2.fromScale(width, height)
		textLabel.Text = text
		textLabel.TextColor3 = ink
		textLabel.TextScaled = true
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", weight)
		textLabel.Parent = frame
	end
	label(title, 0.06, 0.06, 0.88, 0.24, Enum.FontWeight.Heavy)
	local share = 0.58 / #lines
	for index, line in ipairs(lines) do
		label(line, 0.08, 0.36 + (index - 1) * share, 0.84, share * 0.8, Enum.FontWeight.Medium)
	end
end

-- The direction ("+d", "-d", "+a" or "-a") that looks out of `wall` into the room.
local function facingOut(kit: Kit, wall: Wall): string
	for _, facing in ipairs({ "+d", "-d", "+a", "-a" }) do
		if kit.toward(facing):Dot(wall.out) > 0.9 then
			return facing
		end
	end
	return "-d"
end

--[[
	A 3D prop in place of an old block box on `wall` (s0..s1 along it, t0..t1 out from it, y0..y1 up): stretched
	to the box, facing out of the wall, the pieces in `pieces` painted with the room's looks (paintLooks).
]]
local function wallProp(kit: Kit, templates: { [string]: Model }, wall: Wall, name: string, item: string, s0: number,
	s1: number, t0: number, t1: number, y0: number, y1: number, pieces: { [string]: Look }?): Model
	local a, d = wall.at((s0 + s1) / 2, (t0 + t1) / 2)
	local copy = propItem(kit, templates, name, item, 1, a, d, y0, facingOut(kit, wall), Vector3.new(s1 - s0, y1 - y0, t1 - t0))
	if pieces then
		paintLooks(copy, item, pieces)
	end
	return copy
end

-- A potted plant: the 3D leafy plant (SBarPlant), kept 1.8 off the walls where it is wider than the old one.
local function plant(kit: Kit, name: string, a: number, d: number)
	local props = propsFor({ "SBarPlant" })
	if props then
		local hw = kit.W / 2
		propItem(kit, props, name, "SBarPlant", 1, math.clamp(a, -hw + 1.8, hw - 1.8), math.clamp(d, 1.8, kit.D - 1.8),
			0.06, "+d")
		return
	end
	kit.cylinder(name .. "_Pot", a, d, 0.8, 1.6, 1.6, "up", looks.DeskBody)
	kit.ball(name .. "_Leaves", a, d, 2.7, 2.6, looks.Plant)
end

-- A bench along its longer side: a wooden seat at 1.8 on two steel legs.
local function bench(kit: Kit, name: string, a0: number, a1: number, d0: number, d1: number)
	kit.block(name .. "_Seat", a0, a1, d0, d1, 1.5, 1.8, looks.Wood)
	if a1 - a0 >= d1 - d0 then
		kit.block(name .. "_Leg_1", a0 + 0.4, a0 + 0.7, d0 + 0.1, d1 - 0.1, 0, 1.5, looks.SteelBeam)
		kit.block(name .. "_Leg_2", a1 - 0.7, a1 - 0.4, d0 + 0.1, d1 - 0.1, 0, 1.5, looks.SteelBeam)
	else
		kit.block(name .. "_Leg_1", a0 + 0.1, a1 - 0.1, d0 + 0.4, d0 + 0.7, 0, 1.5, looks.SteelBeam)
		kit.block(name .. "_Leg_2", a0 + 0.1, a1 - 0.1, d1 - 0.7, d1 - 0.4, 0, 1.5, looks.SteelBeam)
	end
end

-- An office chair (decor; Furniture_01's OfficeChair in `colourway`, 1 by default), the sitter looking
-- toward `facing` ("+d", "-d", "+a" or "-a").
local function chair(kit: Kit, name: string, a: number, d: number, facing: string, colourway: number?)
	local props = propsFor({ "OfficeChair" })
	if props then
		propItem(kit, props, name, "OfficeChair", colourway or 1, a, d, 0, facing)
		return
	end
	kit.item(name .. "_Seat", a - 0.9, a + 0.9, d - 0.9, d + 0.9, 1.6, 1.85, looks.Padding)
	if facing == "+d" then
		kit.item(name .. "_Back", a - 0.9, a + 0.9, d - 0.9, d - 0.7, 1.85, 4, looks.Padding)
	elseif facing == "-d" then
		kit.item(name .. "_Back", a - 0.9, a + 0.9, d + 0.7, d + 0.9, 1.85, 4, looks.Padding)
	elseif facing == "+a" then
		kit.item(name .. "_Back", a - 0.9, a - 0.7, d - 0.9, d + 0.9, 1.85, 4, looks.Padding)
	else
		kit.item(name .. "_Back", a + 0.7, a + 0.9, d - 0.9, d + 0.9, 1.85, 4, looks.Padding)
	end
	kit.cylinder(name .. "_Pole", a, d, 0.85, 1.5, 0.25, "up", looks.SteelBeam)
	kit.cylinder(name .. "_Base", a, d, 0.05, 0.1, 1.6, "up", looks.Gadget)
end

local function stool(kit: Kit, name: string, a: number, d: number)
	kit.cylinder(name .. "_Seat", a, d, 2.42, 0.25, 1.2, "up", looks.Padding)
	kit.cylinder(name .. "_Leg", a, d, 1.15, 2.3, 0.2, "up", looks.Stainless)
	kit.cylinder(name .. "_Foot", a, d, 0.05, 0.1, 1.0, "up", looks.Stainless)
end

-- A desk: wooden top at 3.0 on two steel side panels (Furniture_01's Desk stretched to the size, its long
-- side across, on a hidden solid block).
local function desk(kit: Kit, name: string, a0: number, a1: number, d0: number, d1: number)
	local props = propsFor({ "Desk" })
	if props then
		local across = a1 - a0 >= d1 - d0
		local long, short = math.max(a1 - a0, d1 - d0), math.min(a1 - a0, d1 - d0)
		propItem(kit, props, name, "Desk", 1, (a0 + a1) / 2, (d0 + d1) / 2, 0, if across then "-d" else "+a",
			Vector3.new(long, 3, short))
		hidden(kit.block(name .. "_Solid", a0, a1, d0, d1, 0, 3, looks.Glass))
		return
	end
	kit.block(name .. "_Top", a0, a1, d0, d1, 2.8, 3, looks.Wood)
	kit.block(name .. "_Side_1", a0, a0 + 0.2, d0 + 0.1, d1 - 0.1, 0, 2.8, looks.SteelBeam)
	kit.block(name .. "_Side_2", a1 - 0.2, a1, d0 + 0.1, d1 - 0.1, 0, 2.8, looks.SteelBeam)
end

-- A monitor standing on a desk top (at 3.0) at (a, d), its screen and the keyboard in front of it toward +d,
-- where the sitter is (Furniture_01's Workstation, whose pivot is 0.475 in front of the monitor).
local function monitor(kit: Kit, name: string, a: number, d: number)
	local props = propsFor({ "Workstation" })
	if props then
		propItem(kit, props, name, "Workstation", 1, a, d + 0.475, 3, "+d")
		return
	end
	kit.item(name .. "_Base", a - 0.5, a + 0.5, d - 0.35, d + 0.35, 3, 3.04, looks.Gadget)
	kit.item(name .. "_Stand", a - 0.1, a + 0.1, d - 0.1, d + 0.1, 3.04, 3.5, looks.Gadget)
	kit.item(name .. "_Screen", a - 1.4, a + 1.4, d - 0.06, d + 0.06, 3.5, 5.1, looks.Gadget)
	kit.item(name .. "_Keyboard", a - 1, a + 1, d + 0.8, d + 1.3, 3, 3.06, looks.Gadget)
end

--[[
	Shelving against a wall from s0 to s1: a back panel, two end panels and
	`levels` boards plus a top board, `depth` deep and `height` tall. `fill` is
	called for every slot on every board (level 1 = lowest) with the slot's s,
	its middle depth t and the board's top y. With the 3D props it is one
	Furniture_01 frame (ShelfThree or ShelfFour) stretched to the size and
	coloured with `look`, on a hidden solid block.
]]
local function shelving(kit: Kit, wall: Wall, name: string, s0: number, s1: number, depth: number, height: number,
	levels: number, look: Look, fill: ((level: number, s: number, t: number, y: number) -> ())?)
	local item = if levels == 4 then "ShelfFour" elseif levels == 3 then "ShelfThree" else nil
	local props = item and propsFor({ item })
	local spacing = height / levels
	if item and props then
		local a, d = wall.at((s0 + s1) / 2, depth / 2)
		local frame = propItem(kit, props, name, item, 1, a, d, 0, facingOut(kit, wall), Vector3.new(s1 - s0, height, depth))
		for _, part in ipairs(frame:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Material = look.material
				part.MaterialVariant = look.variant or ""
				part.Color = look.color
			end
		end
		hidden(wall.block(name .. "_Solid", s0, s1, 0, depth, 0, height, looks.Glass))
	else
		wall.block(name .. "_Back", s0, s1, 0, 0.1, 0, height, look)
		wall.block(name .. "_End_1", s0, s0 + 0.15, 0.1, depth, 0, height, look)
		wall.block(name .. "_End_2", s1 - 0.15, s1, 0.1, depth, 0, height, look)
		wall.block(name .. "_Board_Top", s0 + 0.15, s1 - 0.15, 0.1, depth, height - 0.15, height, look)
		for level = 1, levels do
			local y = 0.15 + (level - 1) * spacing
			wall.block(string.format("%s_Board_%d", name, level), s0 + 0.15, s1 - 0.15, 0.1, depth, y, y + 0.15, look)
		end
	end
	if fill then
		for level = 1, levels do
			-- The stretched frame's boards are as much thicker as the shelf is taller than the model's 6.
			local top = (if item and props then 0.05 * height else 0.3) + (level - 1) * spacing
			local s = s0 + 0.9
			while s <= s1 - 0.9 do
				fill(level, s, (depth + 0.1) / 2, top)
				s += 1.3
			end
		end
	end
end

-- Shelf fill: three folded towels per slot (the 3D Towel in mixed colours, or white blocks).
local function towels(kit: Kit, wall: Wall, name: string): (level: number, s: number, t: number, y: number) -> ()
	local props = propsFor({ "Towel" })
	return function(level, s, t, y)
		for fold = 0, 2 do
			local id = string.format("%s_Towel_%d_%.0f_%d", name, level, s * 10, fold)
			if props then
				local a, d = wall.at(s, t)
				propItem(kit, props, id, "Towel", (level * 3 + math.floor(s) + fold) % 6 + 1, a, d, y + fold * 0.26,
					facingOut(kit, wall))
			else
				wall.item(id, s - 0.5, s + 0.5, t - 0.45, t + 0.45, y + fold * 0.3, y + (fold + 1) * 0.3 - 0.02, looks.ShirtWhite)
			end
		end
	end
end

-- Shelf fill: a cardboard box per slot, short and tall ones mixed (Furniture_01's StorageBox, stretched).
local function boxes(kit: Kit, wall: Wall, name: string): (level: number, s: number, t: number, y: number) -> ()
	local props = propsFor({ "StorageBox" })
	return function(level, s, t, y)
		local tall = if (level + math.floor(s)) % 2 == 0 then 1.0 else 1.4
		local id = string.format("%s_Box_%d_%.0f", name, level, s * 10)
		if props then
			local a, d = wall.at(s, t)
			propItem(kit, props, id, "StorageBox", 1, a, d, y, facingOut(kit, wall), Vector3.new(1, tall, 1.2))
		else
			wall.item(id, s - 0.5, s + 0.5, t - 0.6, t + 0.6, y, y + tall, looks.Cardboard)
		end
	end
end

-- Shelf fill: four books per slot (Furniture_01's BookRow, each level in its own colour).
local function books(kit: Kit, wall: Wall, name: string): (level: number, s: number, t: number, y: number) -> ()
	local props = propsFor({ "BookRow" })
	local colours = { looks.PlateRed, looks.PlateBlue, looks.Gadget, looks.ShirtWhite }
	return function(level, s, t, y)
		if props then
			local a, d = wall.at(s, t)
			propItem(kit, props, string.format("%s_Books_%d_%.0f", name, level, s * 10), "BookRow", (level - 1) % 6 + 1, a, d,
				y, facingOut(kit, wall))
			return
		end
		for k = 0, 3 do
			local s0 = s - 0.5 + k * 0.25
			wall.item(string.format("%s_Book_%d_%.0f_%d", name, level, s * 10, k), s0, s0 + 0.22, t - 0.5, t + 0.5, y,
				y + 1.2 + (k % 2) * 0.35, colours[(level + k) % 4 + 1])
		end
	end
end

local function lockerBank(wall: Wall, name: string, s0: number, count: number)
	local unit, depth, height = 2.5, 1.6, 7.5
	wall.block(name, s0, s0 + count * unit, 0, depth, 0, height, looks.LockerBody)
	for index = 0, count - 1 do
		local s = s0 + index * unit
		if index > 0 then
			wall.item(string.format("%s_Seam_%d", name, index), s - 0.04, s + 0.04, depth, depth + 0.03, 0.2, height - 0.2,
				looks.Gadget)
		end
		wall.item(string.format("%s_Handle_%d", name, index + 1), s + unit - 0.6, s + unit - 0.45, depth, depth + 0.12,
			3.6, 4.4, looks.Stainless)
		wall.item(string.format("%s_Vent_%d", name, index + 1), s + 0.6, s + unit - 0.9, depth, depth + 0.03, 6.3, 6.7,
			looks.Gadget)
	end
end

-- A padded table along d (massage or treatment), with a face cradle at the d1 end and a rolled towel.
local function paddedTable(kit: Kit, name: string, a: number, d0: number, d1: number, pad: Look)
	kit.block(name .. "_Pad", a - 1.3, a + 1.3, d0, d1, 2.5, 3, pad)
	kit.block(name .. "_Frame", a - 1.1, a + 1.1, d0 + 0.3, d1 - 0.3, 2.2, 2.5, looks.Wood)
	for index, spot in ipairs({ { -1, d0 + 0.4 }, { 1, d0 + 0.4 }, { -1, d1 - 0.65 }, { 1, d1 - 0.65 } }) do
		local legA = a + spot[1] * 0.9
		kit.item(string.format("%s_Leg_%d", name, index), legA - 0.12, legA + 0.12, spot[2], spot[2] + 0.25, 0, 2.2, looks.Wood)
	end
	kit.item(name .. "_Cradle", a - 0.6, a + 0.6, d1, d1 + 0.9, 2.55, 2.9, pad)
	kit.cylinder(name .. "_Towel", a, d0 + 0.6, 3.25, 2, 0.5, "a", looks.ShirtWhite)
end

-- A high table; with `noStools` the caller seats it.
local function cafeTable(kit: Kit, name: string, a: number, d: number, top: Look?, noStools: boolean?)
	-- The CafeShop_01 high table (its top in `top`) on a hidden solid top and pole, or blocks.
	local props = propsFor({ "HighTable" })
	if props then
		paintLooks(propItem(kit, props, name, "HighTable", 1, a, d, 0, "+d"), "HighTable", { Top = top or looks.Wood })
		hidden(kit.block(name .. "_Solid", a - 1.3, a + 1.3, d - 1.3, d + 1.3, 3, 3.15, looks.Glass))
		hidden(kit.block(name .. "_PoleSolid", a - 0.15, a + 0.15, d - 0.15, d + 0.15, 0.1, 3, looks.Glass))
	else
		kit.block(name .. "_Top", a - 1.3, a + 1.3, d - 1.3, d + 1.3, 3, 3.15, top or looks.Wood)
		kit.block(name .. "_Pole", a - 0.15, a + 0.15, d - 0.15, d + 0.15, 0.1, 3, looks.SteelBeam)
		kit.block(name .. "_Base", a - 0.7, a + 0.7, d - 0.7, d + 0.7, 0, 0.1, looks.Stainless)
	end
	if not noStools then
		stool(kit, name .. "_Stool_1", a - 2.3, d)
		stool(kit, name .. "_Stool_2", a + 2.3, d)
	end
end

-- A see-through drinks fridge against a wall, full of bottles.
local function drinksFridge(kit: Kit, wall: Wall, name: string, s0: number, s1: number)
	local depth, height = 2.2, 7.5
	-- The CafeShop_01 fridge (its door and handle reach 2.45 out), stretched to the width, on a hidden solid block.
	local props = propsFor({ "DrinksFridge" })
	if props then
		wallProp(kit, props, wall, name, "DrinksFridge", s0, s1, 0, depth + 0.25, 0, height)
		hidden(wall.block(name .. "_Solid", s0, s1, 0, depth, 0, height, looks.Glass))
		return
	end
	wall.block(name .. "_Back", s0, s1, 0, 0.2, 0, height, looks.Stainless)
	wall.block(name .. "_Side_1", s0, s0 + 0.2, 0.2, depth, 0, height, looks.Stainless)
	wall.block(name .. "_Side_2", s1 - 0.2, s1, 0.2, depth, 0, height, looks.Stainless)
	wall.block(name .. "_Top", s0 + 0.2, s1 - 0.2, 0.2, depth, height - 0.3, height, looks.Stainless)
	wall.block(name .. "_Bottom", s0 + 0.2, s1 - 0.2, 0.2, depth, 0, 0.5, looks.Stainless)
	wall.item(name .. "_Glow", s0 + 0.3, s1 - 0.3, 0.3, 0.6, height - 0.45, height - 0.3, looks.GlowWhite)
	wall.item(name .. "_Door", s0 + 0.2, s1 - 0.2, depth, depth + 0.1, 0.5, height - 0.3, looks.Glass)
	wall.item(name .. "_Handle", s1 - 0.6, s1 - 0.45, depth + 0.1, depth + 0.25, 2.5, 5, looks.Stainless)
	local colours = { looks.PlateBlue, looks.PlateRed, looks.PlateGreen, looks.PlateYellow }
	local count = math.floor((s1 - s0 - 0.6) / 0.7)
	for level = 0, 3 do
		local y = 0.5 + level * 1.7
		if level > 0 then
			wall.item(string.format("%s_Shelf_%d", name, level), s0 + 0.2, s1 - 0.2, 0.2, depth - 0.1, y - 0.06, y, looks.Glass)
		end
		for index = 0, count - 1 do
			local a, d = wall.at(s0 + 0.6 + index * 0.7, 1.2)
			kit.cylinder(string.format("%s_Bottle_%d_%d", name, level, index), a, d, y + 0.6, 1.2, 0.45, "up",
				colours[(level + index) % 4 + 1])
		end
	end
end

-- An ice bath against a wall: an open white tub with water in it.
local function iceBath(wall: Wall, name: string, s0: number, s1: number)
	local depth, height, side = 7, 2.6, 0.3
	wall.block(name .. "_End_1", s0, s1, 0, side, 0, height, looks.DeskBody)
	wall.block(name .. "_End_2", s0, s1, depth - side, depth, 0, height, looks.DeskBody)
	wall.block(name .. "_Side_1", s0, s0 + side, side, depth - side, 0, height, looks.DeskBody)
	wall.block(name .. "_Side_2", s1 - side, s1, side, depth - side, 0, height, looks.DeskBody)
	wall.block(name .. "_Floor", s0 + side, s1 - side, side, depth - side, 0, side, looks.DeskBody)
	wall.item(name .. "_Water", s0 + side, s1 - side, side, depth - side, side, 2, looks.Water)
end

local function plateStack(kit: Kit, name: string, a: number, d: number, plates: { Look })
	-- Each plate the BackRooms_01 bumper plate lying flat, in its colour, or a block disc.
	local props = propsFor({ "FlatPlate" })
	for index, look in ipairs(plates) do
		local id = string.format("%s_%d", name, index)
		if props then
			paintLooks(propItem(kit, props, id, "FlatPlate", 1, a, d, (index - 1) * 0.18, "+d"), "FlatPlate", { Plate = look })
		else
			kit.cylinder(id, a, d, 0.09 + (index - 1) * 0.18, 0.18, 2, "up", look)
		end
	end
end

-- A warm light (sauna, mirrors): a PointLight in `part`.
local function warmGlow(part: BasePart, range: number, brightness: number)
	local glow = Instance.new("PointLight")
	glow.Color = looks.GlowWarm.color
	glow.Range = range
	glow.Brightness = brightness
	glow.Shadows = false
	glow.Parent = part
end

-- A solid piece nobody sees: it stops players walking through a 3D prop (props are decor).
function hidden(part: BasePart): BasePart
	part.Transparency = 1
	part.CastShadow = false
	return part
end

--[[
	A wall covering (paint, tiles, bricks...) over the whole of `which` wall up
	to the ceiling, 0.08 thick, with a doorway-sized hole where the wall has a
	door (Kit.doors).
]]
local function clad(kit: Kit, which: string, name: string, look: Look)
	local wall = kit.wall(which)
	local s0, s1 = if wall.axis == "a" then -kit.W / 2 else 0, if wall.axis == "a" then kit.W / 2 else kit.D
	local half, top = StarterGymConfig.RoomDoorWidthStuds / 2, StarterGymConfig.RoomDoorHeightStuds
	local doors = table.clone(kit.doors[which])
	table.sort(doors)
	local s, piece = s0, 0
	for _, door in ipairs(doors) do
		if door - half > s then
			piece += 1
			wall.item(string.format("%s_%d", name, piece), s, door - half, 0, 0.08, 0.06, kit.H, look)
		end
		wall.item(string.format("%s_OverDoor_%d", name, piece), door - half, door + half, 0, 0.08, top, kit.H, look)
		s = door + half
	end
	if s1 > s then
		wall.item(string.format("%s_%d", name, piece + 1), s, s1, 0, 0.08, 0.06, kit.H, look)
	end
end

-- One line of text filling the face of `part` that looks toward `toward` (a door sign, a label).
local function plaque(part: BasePart, toward: Vector3, text: string, background: Color3, ink: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = faceToward(toward)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.5
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = ink
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	label.Parent = gui
end

--[[
	A neon sign: glowing letters (no backing) on `wall` from s0 to s1 and y0 to
	y1, over a glowing underline that lights the wall a little; `at` studs out
	from the wall (0.08 by default: just in front of a wall covering).
]]
local function neonSign(wall: Wall, name: string, text: string, s0: number, s1: number, y0: number, y1: number,
	ink: Color3, stroke: Color3, line: Look, at: number?)
	local t = at or 0.08
	local sign = wall.item(name, s0, s1, t, t + 0.06, y0, y1, looks.SignPanel)
	sign.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = faceToward(wall.out)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local letters = Instance.new("TextLabel")
	letters.Size = UDim2.fromScale(1, 1)
	letters.BackgroundTransparency = 1
	letters.Text = text
	letters.TextScaled = true
	letters.TextColor3 = ink
	letters.TextStrokeColor3 = stroke
	letters.TextStrokeTransparency = 0.2
	letters.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	letters.Parent = gui
	local inset = (s1 - s0) / 16
	local underline = wall.item(name .. "_Underline", s0 + inset, s1 - inset, t, t + 0.08, y0 - 0.2, y0 - 0.08, line)
	local glow = Instance.new("PointLight")
	glow.Color = line.color
	glow.Range = 10
	glow.Brightness = 0.6
	glow.Shadows = false
	glow.Parent = underline
end

-- ---------------------------------------------------------------- 3D props

-- One template Model of `parts` (moved into it), its pivot at the bottom centre
-- of their bounds, facing -Z (where the props' fronts and labels face).
local function asTemplate(name: string, parts: { BasePart }): Model
	local model = Instance.new("Model")
	model.Name = name
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in ipairs(parts) do
		local half = part.Size / 2
		for _, x in ipairs({ -1, 1 }) do
			for _, y in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					local corner = part.CFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
					low, high = low:Min(corner), high:Max(corner)
				end
			end
		end
		part.Anchored = true
		part.Parent = model
	end
	model.WorldPivot = CFrame.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
	return model
end

--[[
	The rooms' 3D props (StarterGymConfig.PropAssets), loaded once with
	InsertService: one template per item ("Locker", "SBarWhey", ..., or the
	asset's `whole` name). An asset that fails to load is left out with a
	warning; rooms ask for the items they need with propsFor.
]]
local propTemplates: { [string]: Model }? = nil
local function loadPropTemplates(): { [string]: Model }
	if propTemplates then
		return propTemplates
	end
	local InsertService = game:GetService("InsertService")
	local templates: { [string]: Model } = {}
	for _, asset in ipairs(StarterGymConfig.PropAssets) do
		local ok, problem = pcall(function()
			local loaded = InsertService:LoadAsset(asset.id)
			local groups: { [string]: { BasePart } } = {}
			for _, d in ipairs(loaded:GetDescendants()) do
				local item = if d:IsA("BasePart") then asset.whole or string.match(d.Name, "^(%a+)_") else nil
				if item then
					groups[item] = groups[item] or {}
					table.insert(groups[item], d :: BasePart)
				end
			end
			for item, parts in pairs(groups) do
				templates[item] = asTemplate(item, parts)
			end
			loaded:Destroy()
		end)
		if not ok then
			warn(string.format("[RoomProps] props asset %d not loaded (simple props instead): %s", asset.id, tostring(problem)))
		end
	end
	propTemplates = templates
	return templates
end

-- The prop templates when every one of `items` has loaded, else nil (the room then uses simple props).
function propsFor(items: { string }): { [string]: Model }?
	local templates = loadPropTemplates()
	for _, item in ipairs(items) do
		if not templates[item] then
			return nil
		end
	end
	return templates
end

-- Paints every piece of a copy of `item` from the item's StarterGymConfig.PropColourways colourway.
local function paintProp(copy: Model, item: string, colourway: number)
	local cfg = StarterGymConfig
	local scheme = cfg.PropColourways[item]
	local colours = scheme and scheme[colourway]
	if colours then
		for _, part in ipairs(copy:GetDescendants()) do
			-- Letters and digits: the referee light box's lamps are Lamp1..Lamp3.
			local piece = if part:IsA("BasePart") then string.match(part.Name, "_(%w+)$") else nil
			local paint = piece and colours[piece] and cfg.PropPaints[colours[piece]]
			if paint then
				local basePart = part :: BasePart
				basePart.Color = paint.color
				basePart.Material = paint.material
					or (if cfg.PropFabricPieces[item .. "_" .. (piece :: string)] then Enum.Material.Fabric else Enum.Material.SmoothPlastic)
				basePart.Reflectance = paint.reflectance or 0
				basePart.Transparency = paint.transparency or 0
			end
		end
	end
end

-- A coloured copy of a 3D prop (Kit.place, so it must fit the room): every piece
-- takes its colour from the item's StarterGymConfig.PropColourways colourway.
function propItem(kit: Kit, templates: { [string]: Model }, name: string, item: string, colourway: number,
	a: number, d: number, y: number, facing: string, stretch: Vector3?): Model
	local copy = kit.place(name, templates[item], a, d, y, facing, stretch)
	paintProp(copy, item, colourway)
	return copy
end

--[[
	A coloured copy of the 3D prop `item` for building outside a room's kit (the
	Mock Meet's private rooms, the gym's light fittings), or nil when its asset
	did not load. Every piece is decor; the copy is not parented, and its pivot is
	the bottom centre of its bounds with its front toward the pivot's -Z. With
	`stretch` (width, height, depth) it is stretched to that size first.
]]
function RoomProps.propCopy(item: string, colourway: number, stretch: Vector3?): Model?
	local template: Model? = loadPropTemplates()[item]
	if template == nil then
		return nil
	end
	local copy = template:Clone()
	if stretch then
		stretchTo(copy, stretch)
	end
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			BuildParts.decor(part)
		end
	end
	paintProp(copy, item, colourway)
	return copy
end

--[[
	A light fitting (Lights_01) in `parent`: `item` (stretched to `stretch` when
	given) with its pivot, the bottom centre, at `pivot`. Its glowing piece
	("<item>_<glowPiece>") takes the old block light's `name` and goes straight
	into `parent` (StarterGym_VerifyShell finds the lights by name); the rest is
	the model "<name>_Fitting". No piece casts a shadow: the light is inside.
	Returns the glowing piece for the caller's light, or nil when the model did
	not load (the caller builds the old blocks).
]]
function RoomProps.fitting(parent: Instance, name: string, item: string, glowPiece: string, pivot: CFrame,
	stretch: Vector3?): BasePart?
	local copy = RoomProps.propCopy(item, 1, stretch)
	local glow = if copy then copy:FindFirstChild(item .. "_" .. glowPiece, true) :: BasePart? else nil
	if copy == nil or glow == nil then
		if copy then
			copy:Destroy()
		end
		return nil
	end
	copy:PivotTo(pivot)
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end
	copy.Name = name .. "_Fitting"
	copy.Parent = parent
	glow.Name = name
	glow.Parent = parent
	return glow
end

-- Shelving fill: every level holds one product line, `perSlot` side by side,
-- facing out of the wall (like a real supplement wall: rows of one product).
type ProductRow = { item: string, colourway: number, perSlot: number }
local function productRows(kit: Kit, templates: { [string]: Model }, wall: Wall, name: string, facing: string,
	rows: { ProductRow }): (level: number, s: number, t: number, y: number) -> ()
	return function(level, s, t, y)
		local row = rows[level]
		if row then
			for k = 1, row.perSlot do
				local a, d = wall.at(s + (k - (row.perSlot + 1) / 2) * 0.64, t)
				propItem(kit, templates, string.format("%s_%d_%.0f_%d", name, level, s * 10, k), row.item, row.colourway,
					a, d, y, facing)
			end
		end
	end
end

-- A pendant lamp of `item` hung with its bottom at `bottom`, on a cable from the
-- ceiling, its bulb lighting the room warmly.
local function pendant(kit: Kit, templates: { [string]: Model }, name: string, colourway: number, a: number, d: number,
	bottom: number)
	local lamp = propItem(kit, templates, name, "PendantLamp", colourway, a, d, bottom, "-d")
	local top = bottom + lamp:GetExtentsSize().Y
	kit.cylinder(name .. "_Cable", a, d, (kit.H + top) / 2, kit.H - top, 0.06, "up", looks.Gadget)
	local bulb = lamp:FindFirstChild("PendantLamp_Bulb", true)
	if bulb then
		local light = Instance.new("PointLight")
		light.Color = StarterGymConfig.PropPaints.WarmGlow.color
		light.Range = 14
		light.Brightness = 1
		light.Shadows = false
		light.Parent = bulb
	end
end

-- A round table: a marble-topped disc on a black pole and base (only the pole and base are solid).
local function roundTable(kit: Kit, name: string, a: number, d: number, top: Look, height: number)
	-- The CafeShop_01 round table (its top in `top`), stretched to the height, on a hidden solid pole.
	local props = propsFor({ "RoundTable" })
	if props then
		paintLooks(propItem(kit, props, name, "RoundTable", 1, a, d, 0, "+d", Vector3.new(2.8, height, 2.8)), "RoundTable",
			{ Top = top })
		hidden(kit.block(name .. "_Solid", a - 0.12, a + 0.12, d - 0.12, d + 0.12, 0.1, height - 0.16, looks.Glass))
		return
	end
	kit.cylinder(name .. "_Top", a, d, height - 0.08, 0.16, 2.8, "up", top)
	kit.block(name .. "_Pole", a - 0.12, a + 0.12, d - 0.12, d + 0.12, 0.1, height - 0.16, looks.Gadget)
	kit.block(name .. "_Base", a - 0.6, a + 0.6, d - 0.6, d + 0.6, 0, 0.1, looks.Gadget)
end

-- ---------------------------------------------------------------- the rooms (step 6a: ground floor)

local FURNISH: { [string]: (kit: Kit) -> () } = {}

-- The first lockers (step 6a), kept for when the 3D props do not load.
local function simpleLockers(kit: Kit)
	local hw, D = kit.W / 2, kit.D
	local count = math.floor((kit.W - 4) / 2.5)
	lockerBank(kit.wall("back"), "Lockers_Back", -count * 2.5 / 2, count)
	lockerBank(kit.wall("left"), "Lockers_Side", 8, math.floor((D - 10) / 2.5))
	local right = kit.wall("right")
	right.item("Mirror_Frame", 1.8, 12.2, 0, 0.08, 2.3, 8.7, looks.Stainless)
	right.item("Mirror", 2, 12, 0, 0.1, 2.5, 8.5, looks.Mirror)
	bench(kit, "Bench_1", -8, 8, 13, 14.4)
	bench(kit, "Bench_2", -8, 8, 19, 20.4)
	plant(kit, "Plant_1", -hw + 1.5, 1.5)
	plant(kit, "Plant_2", hw - 1.5, 1.5)
end

-- The first showers (step 6a), kept for when the 3D props do not load.
local function simpleShowers(kit: Kit)
	local hw = kit.W / 2
	local back = kit.wall("back")
	back.item("Tiles_Back", -hw, hw, 0, 0.2, 0, 9, looks.Tile)
	local stallWidth = 4.5
	local count = math.floor((kit.W - 2) / stallWidth)
	local start = -count * stallWidth / 2
	for index = 0, count do
		local s = start + index * stallWidth
		back.block("Stall_Wall_" .. index, s - 0.15, s + 0.15, 0.2, 4.2, 0, 7.5, looks.Tile)
	end
	for index = 1, count do
		local s = start + (index - 0.5) * stallWidth
		back.item("Shower_Pipe_" .. index, s - 0.06, s + 0.06, 0.2, 0.32, 4.5, 7.6, looks.Stainless)
		back.item("Shower_Arm_" .. index, s - 0.06, s + 0.06, 0.32, 1, 7.48, 7.6, looks.Stainless)
		back.item("Shower_Head_" .. index, s - 0.4, s + 0.4, 0.7, 1.5, 7.3, 7.45, looks.Stainless)
		back.item("Shower_Valve_" .. index, s - 0.25, s + 0.25, 0.2, 0.35, 3.8, 4.3, looks.Stainless)
		back.item("Shower_Drain_" .. index, s - 0.3, s + 0.3, 2, 2.6, 0, 0.03, looks.Gadget)
	end
	-- A bench with hooks on the side wall away from the door, towels on the other.
	local benchWall = kit.wall(if kit.doorA < 0 then "right" else "left")
	benchWall.block("Bench_Seat", 9, 19, 0, 1.4, 1.5, 1.8, looks.Wood)
	benchWall.block("Bench_Leg_1", 9.3, 9.6, 0.1, 1.3, 0, 1.5, looks.SteelBeam)
	benchWall.block("Bench_Leg_2", 18.4, 18.7, 0.1, 1.3, 0, 1.5, looks.SteelBeam)
	for index = 1, 5 do
		local s = 9 + index * 1.7
		benchWall.item("Hook_" .. index, s - 0.1, s + 0.1, 0, 0.4, 6, 6.2, looks.Stainless)
	end
	local shelfWall = kit.wall(if kit.doorA < 0 then "left" else "right")
	shelving(kit, shelfWall, "TowelShelf", 10, 16, 1.2, 4.5, 3, looks.DeskBody, towels(kit, shelfWall, "TowelShelf"))
end

-- The first cafe (step 6a), kept for when the 3D props do not load.
local function simpleCafe(kit: Kit)
	local hw = kit.W / 2
	local back = kit.wall("back")
	back.block("BackCounter", -14, 6, 0, 2, 0, 3.4, looks.DeskBody)
	back.block("BackCounter_Top", -14, 6, 0, 2.1, 3.4, 3.6, looks.DeskWork)
	back.item("CoffeeMachine", -11, -8.5, 0.3, 1.7, 3.6, 5.4, looks.Stainless)
	back.item("CoffeeMachine_Front", -10.6, -8.9, 1.7, 1.75, 4.2, 5.1, looks.Gadget)
	local menu = back.item("MenuBoard", -13, 5, 0, 0.15, 6, 10, looks.SignPanel)
	writing(menu, back.out, "ELITE PREP CAFE", { "Protein shake ...... 5", "Coffee ...... 3", "Pre-workout ...... 4",
		"Water ...... 1" }, looks.SignPanel.color, WHITE)
	drinksFridge(kit, back, "Fridge", 8, 13)
	-- The serving counter with shakers on it, staff behind it.
	back.block("Counter", -14, 6, 5, 6.5, 0, 3.6, looks.DeskBody)
	back.block("Counter_Top", -14.2, 6.2, 4.9, 6.7, 3.6, 3.8, looks.DeskWork)
	for index = 0, 4 do
		local a, d = back.at(-12 + index * 4, 5.75)
		kit.cylinder("Shaker_" .. index + 1, a, d, 4.25, 0.9, 0.5, "up", if index % 2 == 0 then looks.PlateRed else looks.Gadget)
	end
	for index, spot in ipairs({ { -16, 10 }, { -7, 12 }, { 7, 12 }, { 16, 10 } }) do
		cafeTable(kit, "Table_" .. index, spot[1], spot[2])
	end
	plant(kit, "Plant_1", -hw + 1.5, 1.5)
	plant(kit, "Plant_2", hw - 1.5, 1.5)
end

-- The old kitchen corner (step 6a), kept as the staff room for when the 3D props do not load.
local function simpleStaffRoom(kit: Kit)
	local hw = kit.W / 2
	local back = kit.wall("back")
	local counterEnd = hw - 6
	back.block("Counter", -hw, counterEnd, 0, 2.2, 0, 3.2, looks.DeskBody)
	back.block("Counter_Top", -hw, counterEnd, 0, 2.4, 3.2, 3.4, looks.DeskWork)
	back.block("Cabinets", -hw, counterEnd, 0, 1.4, 6, 8.5, looks.DeskBody)
	for index = 1, 5 do
		local s = -hw + index * (counterEnd + hw) / 6
		back.item("Counter_Seam_" .. index, s - 0.03, s + 0.03, 2.2, 2.23, 0.2, 3, looks.Gadget)
		back.item("Cabinet_Seam_" .. index, s - 0.03, s + 0.03, 1.4, 1.43, 6.1, 8.4, looks.Gadget)
	end
	back.item("Sink", -6, -3.5, 0.6, 1.8, 3.38, 3.42, looks.Stainless)
	back.item("Tap", -4.85, -4.65, 0.3, 0.5, 3.4, 4.4, looks.Stainless)
	back.item("Tap_Spout", -4.85, -4.65, 0.5, 1, 4.2, 4.35, looks.Stainless)
	for index, spot in ipairs({ { -12, 0.8 }, { -10.5, 0.8 }, { -12, 1.7 }, { -10.5, 1.7 } }) do
		local a, d = back.at(spot[1], spot[2])
		kit.cylinder("Hob_" .. index, a, d, 3.425, 0.05, 0.9, "up", looks.Gadget)
	end
	back.item("Oven_Door", -12.5, -10, 2.2, 2.25, 0.5, 2.8, looks.Gadget)
	back.item("Oven_Handle", -12.3, -10.2, 2.25, 2.4, 2.5, 2.62, looks.Stainless)
	back.block("Fridge", hw - 5.5, hw - 0.5, 0, 2.6, 0, 7.8, looks.Stainless)
	back.item("Fridge_Seam", hw - 5.5, hw - 0.5, 2.6, 2.63, 5, 5.06, looks.Gadget)
	back.item("Fridge_Handle", hw - 1.3, hw - 1.15, 2.6, 2.75, 2.5, 4.6, looks.Gadget)
	-- An island in the middle with stools on the door side.
	kit.block("Island", -4, 2, 13, 16, 0, 3.2, looks.DeskBody)
	kit.block("Island_Top", -4.2, 2.2, 12.8, 16.2, 3.2, 3.4, looks.DeskWork)
	for index, a in ipairs({ -3, -1, 1 }) do
		stool(kit, "Stool_" .. index, a, 11.6)
	end
	local pantryWall = kit.wall(if kit.doorA > 0 then "left" else "right")
	shelving(kit, pantryWall, "Pantry", 9, 18, 1.4, 7, 3, looks.DeskBody, boxes(kit, pantryWall, "Pantry"))
	plant(kit, "Plant", if kit.doorA > 0 then -hw + 1.5 else hw - 1.5, 1.5)
end

--[[
	The lockers (GAME_DESIGN §27: where players will change outfit and wear
	cosmetic gear, later). Remade 2026-10-25 with CC0 textures and 3D props: a
	dark tiled floor; banks of lockers in four colours against an oak slatted
	wall with a LOCKER ROOM sign; oak benches with gym bags and bottles; a
	vanity with three basins under round glowing mirrors on a green penny-tile
	wall; two changing cubicles with coloured curtains; towels by the showers.
]]
FURNISH.Lockers = function(kit)
	local props = propsFor({ "Locker", "LockerBench", "GymBag", "WaterBottle", "RoundMirror", "Sink", "Curtain",
		"SBarPlant" })
	if props == nil then
		simpleLockers(kit)
		return
	end
	local hw, D, H = kit.W / 2, kit.D, kit.H
	local back, left, right = kit.wall("back"), kit.wall("left"), kit.wall("right")
	local function put(name: string, item: string, colourway: number, a: number, d: number, y: number, facing: string): Model
		return propItem(kit, props, name, item, colourway, a, d, y, facing)
	end

	-- The room's surfaces.
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.LockersFloor)
	clad(kit, "back", "Wall_Slats", looks.LockersSlats)
	clad(kit, "left", "Wall_Penny", looks.LockersPenny)
	clad(kit, "right", "Wall_Right", looks.LockersWall)

	-- Sixteen lockers along the back wall, four of each colour, oak battens
	-- around them and the sign above.
	local columns = 16
	local l0 = -columns * 2.4 / 2
	for k = 0, columns - 1 do
		local a, d = back.at(l0 + (k + 0.5) * 2.4, 1.04)
		put("Locker_" .. k + 1, "Locker", math.floor(k / 4) % 4 + 1, a, d, 0.06, "-d")
	end
	hidden(back.block("Lockers_Solid", l0, -l0, 0.08, 2, 0.06, 7.46, looks.Glass))
	local batten, s = 0, -hw + 0.6
	while s + 0.15 <= hw do
		batten += 1
		back.item("Batten_" .. batten, s - 0.15, s + 0.15, 0.08, 0.3, if math.abs(s) < -l0 + 0.2 then 7.6 else 0.06, H,
			looks.LockersSlats)
		s += 1.2
	end
	neonSign(back, "Sign", "LOCKER ROOM", -8, 8, 8.9, 10.9, Color3.fromRGB(250, 250, 245), Color3.fromRGB(110, 110, 110),
		looks.GlowWhite, 0.32)

	-- Oak benches with bags and bottles: three in front of the lockers, one in the middle.
	for index, spot in ipairs({ { -12, D - 5.6 }, { 0, D - 5.6 }, { 12, D - 5.6 }, { -8, 15 } }) do
		put("Bench_" .. index, "LockerBench", 1, spot[1], spot[2], 0.06, "-d")
		hidden(kit.block("Bench_Solid_" .. index, spot[1] - 4, spot[1] + 4, spot[2] - 0.8, spot[2] + 0.8, 0.06, 1.86, looks.Glass))
	end
	for index, spot in ipairs({ { -14.5, D - 5.6, 1.86 }, { 2.5, D - 5.6, 1.86 }, { 14, D - 7.6, 0.06 }, { -3, D - 3.4, 0.06 },
		{ -10, 15, 1.86 } }) do
		put("GymBag_" .. index, "GymBag", index, spot[1], spot[2], spot[3], "-d")
	end
	for index, spot in ipairs({ { -10, D - 5.6 }, { 1, D - 5.4 }, { 10.8, D - 5.6 }, { -5.5, 15 } }) do
		put("Bottle_" .. index, "WaterBottle", index, spot[1], spot[2], 1.86, "-d")
	end

	-- The vanity on the penny-tile wall: an oak cabinet with a marble top, three
	-- basins, a round glowing mirror over each.
	-- The vanity, cubicle seats and hooks are Blender models (CafeShop_01, BackRooms_01) on hidden solid
	-- blocks, or blocks.
	local fittings = propsFor({ "CounterUnit", "WallShelf", "CoatHook" })
	if fittings then
		wallProp(kit, fittings, left, "Vanity", "CounterUnit", 5.8, 24.2, 0.08, 2.4, 0.06, 3.2,
			{ Body = looks.LockersSlats, Top = looks.CafeMarble })
		hidden(left.block("Vanity_Solid", 5.8, 24.2, 0.08, 2.4, 0.06, 3.2, looks.Glass))
	else
		left.block("Vanity", 6, 24, 0.08, 2.2, 0.06, 3, looks.LockersSlats)
		left.block("Vanity_Top", 5.8, 24.2, 0.08, 2.4, 3, 3.2, looks.CafeMarble)
	end
	for index, vs in ipairs({ 9, 15, 21 }) do
		local a, d = left.at(vs, 1.3)
		put("Basin_" .. index, "Sink", 1, a, d, 3.2, "+a")
		local ma, md = left.at(vs, 0.16)
		local mirror = put("Mirror_" .. index, "RoundMirror", 1, ma, md, 4.4, "+a")
		local glow = mirror:FindFirstChild("RoundMirror_Glow", true)
		if glow then
			warmGlow(glow :: BasePart, 10, 0.5)
		end
	end

	-- Two changing cubicles on the wall toward the showers, each with a seat
	-- and a coloured curtain (where outfits will be changed later).
	for index = 0, 2 do
		local c = 3.4 + index * 4.7
		right.block("Cubicle_Wall_" .. index + 1, c - 0.1, c + 0.1, 0.08, 4.6, 0.06, 7.5, looks.LockersSlats)
	end
	right.block("Cubicle_Header", 3.3, 12.9, 4.4, 4.7, 6.7, 7.5, looks.LockersSlats)
	for index = 1, 2 do
		local c = 3.4 + (index - 0.5) * 4.7
		local seat = right.block("Cubicle_Seat_" .. index, c - 1.6, c + 1.6, 0.08, 1.3, 1.5, 1.8, looks.LockersSlats)
		if fittings then
			-- An oak board on brackets reaching 0.5 under it, over the old seat block (now hidden); a coat hook.
			hidden(seat)
			wallProp(kit, fittings, right, "Cubicle_Seat_" .. index .. "_Model", "WallShelf", c - 1.6, c + 1.6, 0.08, 1.3, 1.0,
				1.8, { Board = looks.LockersSlats })
			wallProp(kit, fittings, right, "Cubicle_Hook_" .. index, "CoatHook", c - 0.08, c + 0.08, 0.08, 0.53, 5.35, 5.65)
		else
			right.item("Cubicle_Hook_" .. index, c - 0.1, c + 0.1, 0.08, 0.5, 5.4, 5.6, looks.Stainless)
		end
		local a, d = right.at(c, 4.45)
		put("Curtain_" .. index, "Curtain", index, a, d, 0.3, "-a")
	end
	shelving(kit, right, "TowelShelf", 26.4, 30.3, 1.4, 6, 3, looks.LockersSlats, towels(kit, right, "TowelShelf"))

	-- Plants by the glass.
	put("Plant_1", "SBarPlant", 1, -hw + 1.8, 1.7, 0.06, "+d")
	put("Plant_2", "SBarPlant", 1, hw - 1.8, 1.7, 0.06, "+d")
end

--[[
	The cafe (GAME_DESIGN §27: the social hangout). Remade 2026-10-25 with CC0
	textures and 3D props: a herringbone floor and a red brick wall; a back bar
	and serving counter in dark green tiles with white marble tops, espresso
	machines, grinders, shelves of CENTRAL coffee bags, a menu and a warm neon
	CAFE sign; a pastry case of donuts, muffins and croissants; booths, round
	tables and chairs in many colours under pendant lamps; a window bar
	looking out at the gym; the Staff Room door in the left wall.
]]
FURNISH.Cafe = function(kit)
	local props = propsFor({ "Espresso", "Grinder", "CoffeeCup", "Mug", "PastryCase", "Donut", "Muffin", "Croissant",
		"CafeChair", "Booth", "PendantLamp", "CoffeeBag", "SBarStool", "SBarPlant" })
	if props == nil then
		simpleCafe(kit)
		return
	end
	local hw, D = kit.W / 2, kit.D
	local back, left = kit.wall("back"), kit.wall("left")
	local function put(name: string, item: string, colourway: number, a: number, d: number, y: number, facing: string): Model
		return propItem(kit, props, name, item, colourway, a, d, y, facing)
	end
	-- Against the back wall, `t` out from it, facing into the room.
	local function onBack(name: string, item: string, colourway: number, s: number, t: number, y: number): Model
		local a, d = back.at(s, t)
		return put(name, item, colourway, a, d, y, "-d")
	end

	-- The room's surfaces.
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.CafeFloor)
	clad(kit, "back", "Wall_Brick", looks.CafeBrick)
	clad(kit, "left", "Wall_Left", looks.CafeWall)
	clad(kit, "right", "Wall_Right", looks.CafeWall)

	-- The back bar: green tiles under white marble, two espresso machines,
	-- grinders, mugs; shelves of coffee bags, the menu and the neon sign.
	-- The counters, shelves, till and window bar are CafeShop_01 models (in the room's tiles and marble) on hidden
	-- solid blocks; blocks if they did not load.
	local furniture = propsFor({ "CounterUnit", "WallShelf", "Till", "WindowBar" })
	local surfaces = { Body = looks.CafeTiles, Top = looks.CafeMarble }
	if furniture then
		wallProp(kit, furniture, back, "BackBar", "CounterUnit", 1, 22.5, 0.08, 2.35, 0.06, 3.6, surfaces)
		hidden(back.block("BackBar_Solid", 1, 22.5, 0.08, 2.35, 0.06, 3.6, looks.Glass))
	else
		back.block("BackBar", 1, 22.5, 0.08, 2.2, 0.06, 3.4, looks.CafeTiles)
		back.block("BackBar_Top", 1, 22.5, 0.08, 2.35, 3.4, 3.6, looks.CafeMarble)
	end
	onBack("Espresso_1", "Espresso", 1, 8, 1.2, 3.6)
	onBack("Espresso_2", "Espresso", 2, 19, 1.2, 3.6)
	onBack("Grinder_1", "Grinder", 1, 4.6, 1.2, 3.6)
	onBack("Grinder_2", "Grinder", 1, 11.4, 1.2, 3.6)
	for k = 0, 5 do
		onBack("BarMug_" .. k + 1, "Mug", k % 5 + 1, 13.5 + k * 0.55, 1.4, 3.6)
	end
	for level, y in ipairs({ 5.2, 6.9 }) do
		if furniture then
			-- The board on brackets reaching 0.5 under it.
			wallProp(kit, furniture, back, "Shelf_" .. level, "WallShelf", 2, 12, 0.08, 1, y - 0.5, y + 0.15,
				{ Board = looks.LockersSlats })
		else
			back.item("Shelf_" .. level, 2, 12, 0.08, 1, y, y + 0.15, looks.LockersSlats)
		end
		for k = 0, 11 do
			onBack(string.format("Shelf_%d_Bag_%d", level, k + 1), "CoffeeBag", (math.floor(k / 3) + level) % 4 + 1,
				2.6 + k * 0.8, 0.55, y + 0.15)
		end
	end
	local menu = back.item("MenuBoard", 13.5, 21.5, 0.08, 0.2, 5.6, 9.2, looks.SignPanel)
	writing(menu, back.out, "ELITE PREP CAFE", { "Flat white ...... 3", "Iced latte ...... 4", "Protein coffee ...... 5",
		"Croissant ...... 2" }, looks.SignPanel.color, WHITE)
	neonSign(back, "NeonSign", "CAFE", 3, 11, 9.2, 11.6, Color3.fromRGB(255, 214, 150), Color3.fromRGB(150, 90, 30),
		looks.GlowWarm)

	-- The serving counter: the pastry case, takeaway cups, mugs and a till;
	-- pendant lamps over it.
	if furniture then
		wallProp(kit, furniture, back, "Counter", "CounterUnit", 0.8, 20.2, 5, 7.1, 0.06, 3.85, surfaces)
		hidden(back.block("Counter_Solid", 0.8, 20.2, 5, 7.1, 0.06, 3.85, looks.Glass))
	else
		back.block("Counter", 1, 20, 5.2, 6.8, 0.06, 3.6, looks.CafeTiles)
		back.block("Counter_Top", 0.8, 20.2, 5, 7.1, 3.6, 3.85, looks.CafeMarble)
	end
	onBack("PastryCase", "PastryCase", 1, 5, 6.05, 3.85)
	for k = 0, 4 do
		onBack("Case_Donut_" .. k + 1, "Donut", k % 3 + 1, 3.6 + k * 0.65, 5.75, 4.15)
		onBack("Case_Croissant_" .. k + 1, "Croissant", 1, 3.6 + k * 0.65, 6.4, 4.15)
	end
	for k = 0, 5 do
		onBack("Case_Muffin_" .. k + 1, "Muffin", k % 3 + 1, 3.5 + k * 0.6, 6.05, 4.74)
	end
	for k = 0, 3 do
		onBack("Cup_" .. k + 1, "CoffeeCup", k + 1, 9 + k * 0.6, 5.6, 3.85)
		onBack("CounterMug_" .. k + 1, "Mug", k + 2, 12.5 + k * 0.6, 5.6, 3.85)
	end
	if furniture then
		-- Its screen at the back, toward the wall, like the old block screen.
		onBack("Till", "Till", 1, 17, 5.7, 3.85)
	else
		back.item("Till", 16.5, 17.5, 5.4, 6, 3.85, 3.95, looks.Gadget)
		back.item("Till_Screen", 16.7, 17.3, 5.5, 5.6, 3.95, 4.8, looks.Gadget)
	end
	for index, ps in ipairs({ 4, 10, 16 }) do
		local a, d = back.at(ps, 6.1)
		pendant(kit, props, "Pendant_" .. index, index, a, d, 7.2)
	end

	-- Booths along the brick wall, two tables at each (chairs at the second,
	-- away from the Staff Room door), a lamp over every table.
	for index, spec in ipairs({ { s = -18.6, colourway = 1, chairs = false }, { s = -7.6, colourway = 3, chairs = true } }) do
		onBack("Booth_" .. index, "Booth", spec.colourway, spec.s, 1.28, 0.06)
		hidden(back.block("Booth_Solid_" .. index, spec.s - 5.1, spec.s + 5.1, 0.08, 2.4, 0.06, 1.9, looks.Glass))
		for k, offset in ipairs({ -2.5, 2.5 }) do
			local id = string.format("Booth_%d_Table_%d", index, k)
			local a, d = back.at(spec.s + offset, 4.1)
			roundTable(kit, id, a, d, looks.CafeMarble, 3.06)
			put(id .. "_Mug", "Mug", (index + k) % 5 + 1, a + 0.5, d, 3.06, "-d")
			if spec.chairs then
				local ca, cd = back.at(spec.s + offset, 6.4)
				put(id .. "_Chair", "CafeChair", (index + k) % 4 + 1, ca, cd, 0.06, "+d")
			end
			pendant(kit, props, id .. "_Lamp", (index + k) % 4 + 1, a, d, 7.6)
		end
	end

	-- Round tables in the middle with chairs in mixed colours, cups and a pastry.
	for index, spot in ipairs({ { -16, 13 }, { -7, 15 }, { 8, 11.5 }, { 16, 13 } }) do
		local id = "Table_" .. index
		roundTable(kit, id, spot[1], spot[2], looks.CafeMarble, 3.06)
		put(id .. "_Chair_1", "CafeChair", index % 4 + 1, spot[1] - 2, spot[2], 0.06, "+a")
		put(id .. "_Chair_2", "CafeChair", (index + 1) % 4 + 1, spot[1] + 2, spot[2], 0.06, "-a")
		put(id .. "_Cup", "CoffeeCup", index, spot[1] - 0.5, spot[2] + 0.3, 3.06, "+a")
		put(id .. "_Donut", "Donut", index % 3 + 1, spot[1] + 0.5, spot[2] - 0.3, 3.06, "-a")
	end

	-- A window bar along the glass with stools, looking out at the gym.
	if furniture then
		paintLooks(put("WindowBar", "WindowBar", 1, -13.75, 0.85, 0.06, "+d"), "WindowBar", { Top = looks.CafeMarble })
		hidden(kit.block("WindowBar_Solid", -21.5, -6, 0.2, 1.5, 3.6, 3.85, looks.Glass))
	else
		kit.block("WindowBar", -21.5, -6, 0.2, 1.5, 3.6, 3.85, looks.CafeMarble)
	end
	for index, a in ipairs({ -20.8, -13.75, -6.7 }) do
		local leg = kit.block("WindowBar_Leg_" .. index, a - 0.1, a + 0.1, 0.75, 0.95, 0.06, 3.6, looks.Gadget)
		if furniture then
			hidden(leg)
		end
	end
	for k = 0, 5 do
		put("WindowStool_" .. k + 1, "SBarStool", 1, -20 + k * 2.6, 2.6, 0.06, "-d")
	end

	-- Plants, and a sign over the Staff Room door.
	put("Plant_1", "SBarPlant", 1, hw - 1.8, 1.7, 0.06, "+d")
	local pa, pd = left.at(12, 1.8)
	put("Plant_2", "SBarPlant", 1, pa, pd, 0.06, "+a")
	for index, door in ipairs(kit.doors.left) do
		local sign = left.item("StaffSign_" .. index, door - 2, door + 2, 0.08, 0.16, 9.4, 10.4, looks.SignPanel)
		plaque(sign, left.out, "STAFF ONLY", looks.SignPanel.color, WHITE)
	end
end

--[[
	The Staff Room (GAME_DESIGN §27: was the Kitchen; a staff break room, look
	only, staff NPCs later), behind the cafe. 2026-10-25: a laminate floor and
	a dusty blue wall; a kitchenette with sage units, a wooden worktop, a cream
	tiled splashback, a kettle, microwave and mugs, a retro fridge and a water
	cooler; a table with chairs; a sofa facing a wall TV with staff notices;
	staff lockers, a rail of CENTRAL STAFF tees and a cork rota board.
]]
FURNISH.StaffRoom = function(kit)
	local props = propsFor({ "Fridge", "WaterCooler", "Microwave", "Kettle", "Mug", "Sofa", "CafeChair", "Locker",
		"StaffTee", "SBarPlant" })
	if props == nil then
		simpleStaffRoom(kit)
		return
	end
	local hw, D = kit.W / 2, kit.D
	local back, left, right = kit.wall("back"), kit.wall("left"), kit.wall("right")
	local function put(name: string, item: string, colourway: number, a: number, d: number, y: number, facing: string): Model
		return propItem(kit, props, name, item, colourway, a, d, y, facing)
	end
	local function onBack(name: string, item: string, colourway: number, s: number, t: number, y: number): Model
		local a, d = back.at(s, t)
		return put(name, item, colourway, a, d, y, "-d")
	end

	-- The room's surfaces.
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.StaffFloor)
	clad(kit, "left", "Wall_Accent", looks.StaffAccent)
	for _, which in ipairs({ "back", "front", "right" }) do
		clad(kit, which, "Wall_" .. which, looks.LockersWall)
	end

	-- The kitchenette along the back wall.
	local k0, k1 = -hw + 0.1, 2.2
	-- The cabinets, sink, tables, rota board and tee rail are Blender models (BackRooms_01, Furniture_01, the
	-- Lockers' basin) on the old solid blocks, now hidden; blocks if they did not load.
	local kitchen = propsFor({ "KitchenUnit", "Sink", "Desk", "CorkBoard", "HangRail" })
	local cabinets = back.block("Cabinets", k0, k1 - 0.2, 0.08, 2.2, 0.06, 3.2, looks.StaffCabinet)
	local worktop = back.block("Worktop", k0, k1, 0.08, 2.4, 3.2, 3.4, looks.StaffWorktop)
	back.item("Splashback", k0, k1, 0.08, 0.14, 3.4, 6, looks.SBarTiles)
	local wallCabinets = back.block("WallCabinets", k0, k1 - 0.2, 0.14, 1.4, 6.2, 8.6, looks.StaffCabinet)
	if kitchen then
		hidden(cabinets)
		hidden(worktop)
		hidden(wallCabinets)
		wallProp(kit, kitchen, back, "Kitchen", "KitchenUnit", k0, k1, 0.08, 2.4, 0.06, 3.4,
			{ Body = looks.StaffCabinet, Top = looks.StaffWorktop })
		-- The same unit for the wall cabinets, its top in the cabinets' colour.
		wallProp(kit, kitchen, back, "Kitchen_WallCabinets", "KitchenUnit", k0, k1 - 0.2, 0.14, 1.52, 6.2, 8.6,
			{ Body = looks.StaffCabinet, Top = looks.StaffCabinet })
		local sa, sd = back.at(-4.75, 1.3)
		propItem(kit, kitchen, "Sink", "Sink", 1, sa, sd, 3.4, "-d")
	else
		for index = 1, 5 do
			local cs = k0 + index * (k1 - 0.2 - k0) / 6
			back.item("Cabinet_Seam_" .. index, cs - 0.03, cs + 0.03, 2.2, 2.23, 0.3, 3, looks.Gadget)
			back.item("WallCabinet_Seam_" .. index, cs - 0.03, cs + 0.03, 1.4, 1.43, 6.3, 8.5, looks.Gadget)
			back.item("Cabinet_Handle_" .. index, cs + 0.25, cs + 0.35, 2.2, 2.32, 2.2, 2.9, looks.Stainless)
			back.item("WallCabinet_Handle_" .. index, cs + 0.25, cs + 0.35, 1.4, 1.52, 6.4, 7.1, looks.Stainless)
		end
		back.item("Sink", -6, -3.5, 0.6, 1.8, 3.38, 3.42, looks.Stainless)
		back.item("Tap", -4.85, -4.65, 0.3, 0.5, 3.4, 4.4, looks.Stainless)
		back.item("Tap_Spout", -4.85, -4.65, 0.5, 1, 4.2, 4.35, looks.Stainless)
	end
	onBack("Kettle", "Kettle", 2, -11, 1.3, 3.4)
	onBack("Microwave", "Microwave", 1, -1, 1.2, 3.4)
	for k = 0, 2 do
		onBack("Mug_" .. k + 1, "Mug", k + 2, -8.6 + k * 0.6, 1.6, 3.4)
	end
	onBack("Fridge", "Fridge", 1, 4.4, 1.25, 0.06)
	hidden(back.block("Fridge_Solid", 3.2, 5.6, 0.1, 2.3, 0.06, 6, looks.Glass))
	onBack("WaterCooler", "WaterCooler", 1, 7.4, 0.85, 0.06)
	hidden(back.block("WaterCooler_Solid", 6.8, 8, 0.1, 1.5, 0.06, 3.4, looks.Glass))
	local roomSign = back.item("Sign", -9, -1, 0.08, 0.16, 9.4, 10.8, looks.SignPanel)
	plaque(roomSign, back.out, "STAFF ROOM", looks.SignPanel.color, WHITE)

	-- A table with six chairs.
	local tableParts = { kit.block("Table_Top", -7, 1, 15, 19, 2.86, 3.06, looks.StaffWorktop) }
	for index, corner in ipairs({ { -6.6, 15.4 }, { 0.6, 15.4 }, { -6.6, 18.6 }, { 0.6, 18.6 } }) do
		table.insert(tableParts, kit.block("Table_Leg_" .. index, corner[1] - 0.15, corner[1] + 0.15, corner[2] - 0.15,
			corner[2] + 0.15, 0.06, 2.86, looks.Gadget))
	end
	if kitchen then
		-- The Furniture_01 desk as the table, its top in the worktop's wood.
		for _, part in ipairs(tableParts) do
			hidden(part)
		end
		paintLooks(propItem(kit, kitchen, "Table", "Desk", 1, -3, 17, 0.06, "+d", Vector3.new(8, 3, 4)), "Desk",
			{ Top = looks.StaffWorktop })
	end
	for k, a in ipairs({ -5.5, -3, -0.5 }) do
		put("Chair_Near_" .. k, "CafeChair", k, a, 13.6, 0.06, "+d")
		put("Chair_Far_" .. k, "CafeChair", k + 1, a, 20.4, 0.06, "-d")
		put("Table_Mug_" .. k, "Mug", k, a + 0.4, 16 + k % 2 * 2, 3.06, "-d")
	end

	-- The lounge: a sofa facing a wall TV with the staff notices, a coffee table between.
	local tv = left.item("TV", 4, 12, 0.08, 0.3, 4.4, 8.8, looks.Gadget)
	writing(tv, left.out, "ELITE PREP GYM", { "Staff meeting: Monday 9:00", "New members: say hi!", "Keep the cafe tidy" },
		Color3.fromRGB(22, 44, 74), WHITE)
	put("Sofa", "Sofa", 2, -5.95, 8, 0.06, "-a")
	hidden(kit.block("Sofa_Solid", -7.25, -4.65, 5, 11, 0.06, 1.86, looks.Glass))
	local coffeeParts = { kit.block("CoffeeTable", -12, -9.4, 6.5, 9.5, 1.2, 1.4, looks.StaffWorktop) }
	for index, corner in ipairs({ { -11.8, 6.7 }, { -9.6, 6.7 }, { -11.8, 9.3 }, { -9.6, 9.3 } }) do
		table.insert(coffeeParts, kit.block("CoffeeTable_Leg_" .. index, corner[1] - 0.1, corner[1] + 0.1, corner[2] - 0.1,
			corner[2] + 0.1, 0.06, 1.2, looks.Gadget))
	end
	if kitchen then
		for _, part in ipairs(coffeeParts) do
			hidden(part)
		end
		paintLooks(propItem(kit, kitchen, "CoffeeTable_Model", "Desk", 1, -10.7, 8, 0.06, "+d", Vector3.new(2.6, 1.34, 3)),
			"Desk", { Top = looks.StaffWorktop })
	end
	put("CoffeeTable_Mug", "Mug", 5, -10.7, 7.4, 1.4, "-a")

	-- The outer wall: staff lockers under a cork rota board, a rail of staff tees.
	for k = 0, 3 do
		local a, d = right.at(13 + (k + 0.5) * 2.4, 1.04)
		put("Locker_" .. k + 1, "Locker", k + 1, a, d, 0.06, "-a")
	end
	hidden(right.block("Lockers_Solid", 13, 22.6, 0.08, 2, 0.06, 7.46, looks.Glass))
	if kitchen then
		wallProp(kit, kitchen, right, "Board", "CorkBoard", 12.8, 22.8, 0.08, 0.22, 8, 11.6,
			{ Frame = looks.LockersSlats, Cork = looks.StaffCork })
	else
		right.item("Board_Frame", 12.8, 22.8, 0.08, 0.14, 8, 11.6, looks.LockersSlats)
		right.item("Board", 13, 22.6, 0.14, 0.2, 8.2, 11.4, looks.StaffCork)
		local noteLooks = { looks.PlateYellow, looks.ShirtWhite, looks.PaddingBlue, looks.PlateGreen, looks.Whiteboard }
		for k = 0, 7 do
			local ns, ny = 13.5 + k * 1.15, 8.5 + (k % 2) * 1.1
			right.item("Note_" .. k + 1, ns, ns + 0.9, 0.2, 0.22, ny, ny + 1, noteLooks[k % 5 + 1])
		end
	end
	local title = right.item("Board_Title", 15.8, 19.8, 0.2, 0.24, 10.5, 11.2, looks.Whiteboard)
	plaque(title, right.out, "STAFF ROTA", WHITE, INK)
	if kitchen then
		-- The rail (its middle 0.06 above the model's bottom, the brackets' round wall plates).
		wallProp(kit, kitchen, right, "TeeRail", "HangRail", 3, 11.5, 0.08, 0.65, 7.0, 7.2)
	else
		right.item("TeeRail", 3, 11.5, 0.55, 0.65, 7.05, 7.15, looks.Stainless)
		for index, rs in ipairs({ 3.2, 11.3 }) do
			right.item("TeeRail_Bracket_" .. index, rs - 0.05, rs + 0.05, 0.08, 0.6, 7.05, 7.15, looks.Stainless)
		end
	end
	for index, ts in ipairs({ 4.5, 7.25, 10 }) do
		local a, d = right.at(ts, 0.6)
		put("StaffTee_" .. index, "StaffTee", index, a, d, 4.64, "-a")
	end

	put("Plant", "SBarPlant", 1, hw - 1.8, D - 1.8, 0.06, "-d")
end

FURNISH.Office = function(kit)
	local hw, D = kit.W / 2, kit.D
	desk(kit, "Desk", -5, 5, D - 7, D - 4.5)
	monitor(kit, "Monitor", 0, D - 6.4)
	chair(kit, "Chair", 0, D - 2.8, "-d")
	local right = kit.wall("right")
	shelving(kit, right, "Bookshelf", 8, 20, 1.4, 8, 4, looks.Wood, books(kit, right, "Bookshelf"))
	local left = kit.wall("left")
	-- The filing cabinet (on its old block, now hidden) and the clock are BackRooms_01 models, or blocks.
	local officeProps = propsFor({ "FilingCabinet", "WallClock" })
	local filing = left.block("Filing", 10, 14, 0, 2, 0, 4.5, looks.LockerBody)
	if officeProps then
		hidden(filing)
		wallProp(kit, officeProps, left, "Filing_Model", "FilingCabinet", 10, 14, 0, 2.1, 0, 4.5, { Body = looks.LockerBody })
		-- The clock's middle 9 up (its bounds reach 0.81 round it, 0.185 off the wall).
		wallProp(kit, officeProps, kit.wall("back"), "Clock", "WallClock", -0.81, 0.81, 0, 0.185, 8.19, 9.81)
	else
		for drawer = 1, 2 do
			left.item("Filing_Seam_" .. drawer, 10.2, 13.8, 2, 2.03, drawer * 1.5 - 0.03, drawer * 1.5 + 0.03, looks.Gadget)
			left.item("Filing_Handle_" .. drawer, 11.5, 12.5, 2, 2.12, drawer * 1.5 + 0.5, drawer * 1.5 + 0.62, looks.Stainless)
		end
		kit.cylinder("Clock", 0, D - 0.075, 9, 0.15, 1.6, "d", looks.Whiteboard)
	end
	plant(kit, "Plant_1", -hw + 1.5, D - 1.5)
	plant(kit, "Plant_2", hw - 1.5, 1.5)
	-- The guide board over the desk: what the Index room used to explain (user, 2026-10-26: the
	-- Office took over its "learn the game" job; GAME_DESIGN §27).
	local back = kit.wall("back")
	local guide = back.item("Guide", -6, 6, 0, 0.1, 4.2, 8.0, looks.Whiteboard)
	writing(guide, back.out, "LEARN THE GAME", { "COMPETITION NUMBER", "COMPETITION SCALE", "TECHNIQUE STATS",
		"WEIGHT CLASSES", "THE MEET LADDER" }, WHITE, INK)
end

--[[
	The open dumbbell & machine zone (StarterGymConfig.OpenToHall; user
	2026-10-26: the Dumbbells, Machines and Index rooms opened into the hall).
	Its "door" is the middle of its open side, so `back` is the building's
	outer wall: on the Office's side a long mirror over a diamond-plate strip
	with dumbbell racks full of CENTRAL hex dumbbells and flat benches facing
	the mirror; on the far side, against a steel-panelled wall, the machines of
	RoomProps_08 (tricep and lat pulldowns on the back wall, leg extensions and
	seated rows on the end wall); neon DUMBBELLS and MACHINES signs. The
	approved props of RoomProps_04 and _08.
]]
FURNISH.TrainingZone = function(kit)
	local hw, D = kit.W / 2, kit.D
	local back, endWall = kit.wall("back"), kit.wall("right")
	local split = 6 -- dumbbells left of it (toward the Office), machines right of it
	-- The mirror in panels about 4 wide, with thin black frames between them.
	local m0, m1 = -hw + 2, split - 2
	back.item("Mirror_Frame", m0 - 0.15, m1 + 0.15, 0, 0.06, 1.05, 9.35, looks.Gadget)
	-- A real mirror: each player's MirrorController shows the room reflected in it.
	local mirror = back.item("Mirror", m0, m1, 0.06, 0.1, 1.2, 9.2, looks.GymMirror)
	mirror:SetAttribute("Facing", back.out)
	mirror:AddTag(StarterGymConfig.MirrorTag)
	local panels = math.max(1, math.round((m1 - m0) / 4))
	for k = 1, panels - 1 do
		local s = m0 + k * (m1 - m0) / panels
		back.item("Mirror_Joint_" .. k, s - 0.06, s + 0.06, 0.1, 0.12, 1.2, 9.2, looks.Gadget)
	end
	back.item("SteelPanels", split, hw, 0, 0.06, 0, 9.6, looks.MachinesSteel)
	endWall.item("SteelPanels_End", 0, D, 0, 0.06, 0, 9.6, looks.MachinesSteel)
	kit.item("PlateStrip", -hw + 1, split - 1, D - 3.4, D, 0, 0.05, looks.DumbbellsPlate)
	neonSign(back, "Sign_Dumbbells", "DUMBBELLS", -hw + 8, split - 10, 10, 11.6, WHITE, Color3.fromRGB(200, 30, 38),
		looks.GlowRed)
	neonSign(back, "Sign_Machines", "MACHINES", split + 4, hw - 4, 10, 11.6, Color3.fromRGB(242, 190, 30), INK, looks.GlowGold,
		0.14)
	local props = propsFor({ "DumbbellRack", "HexDumbbell" })
	if props == nil then
		return
	end
	local function put(name: string, item: string, colourway: number, a: number, d: number, y: number, facing: string): Model
		return propItem(kit, props, name, item, colourway, a, d, y, facing)
	end
	-- Five dumbbell racks against the mirror, three dumbbells on each shelf.
	local rackD = D - 1.01
	for k = 0, 4 do
		local centre = -hw + 5 + k * 7
		put("Rack_" .. k + 1, "DumbbellRack", k % 2 + 1, centre, rackD, 0.05, "-d")
		hidden(kit.block("Rack_" .. k + 1 .. "_Solid", centre - 3, centre + 3, D - 2, D, 0, 2.75, looks.Glass))
		for j = 0, 2 do
			local a = centre + (j - 1) * 2
			put(string.format("Rack_%d_Low_%d", k + 1, j + 1), "HexDumbbell", (k * 3 + j) % 8 + 1, a, rackD - 0.2, 1.1, "-d")
			put(string.format("Rack_%d_High_%d", k + 1, j + 1), "HexDumbbell", (k * 3 + j + 4) % 8 + 1, a, rackD + 0.32, 2.1, "-d")
		end
	end
	-- Four flat benches facing the mirror, a pair of dumbbells beside each.
	-- The BackRooms_01 flat bench on its old pad block (now hidden), or blocks.
	local benchProps = propsFor({ "FlatBench" })
	for k = 0, 3 do
		local a, id = -33 + k * 8.5, "Bench_" .. k + 1
		local padLook = if k % 2 == 0 then looks.Padding else looks.PaddingBlue
		local pad = kit.block(id, a - 0.7, a + 0.7, D - 10, D - 5.4, 1.55, 1.95, padLook)
		if benchProps then
			hidden(pad)
			paintLooks(propItem(kit, benchProps, id .. "_Model", "FlatBench", 1, a, D - 7.7, 0.05, "-d"), "FlatBench",
				{ Pad = padLook, Frame = looks.SteelBeam })
		else
			for leg, d in ipairs({ D - 9.6, D - 5.8 }) do
				kit.item(string.format("%s_Leg_%d", id, leg), a - 0.6, a + 0.6, d - 0.2, d + 0.2, 0.05, 1.55, looks.SteelBeam)
			end
			kit.item(id .. "_Rail", a - 0.15, a + 0.15, D - 9.6, D - 5.8, 1.25, 1.55, looks.SteelBeam)
		end
		for side = 0, 1 do
			put(string.format("%s_Dumbbell_%d", id, side + 1), "HexDumbbell", (k * 2 + side) % 8 + 1, a + 1.8, D - 8.4 + side * 1.4,
				0.05, "-d")
		end
	end
	-- The machines of RoomProps_08 (user 2026-10-26, from Blender previews; they replaced five plain
	-- weight-stack stations), backs against the walls, in mixed colours. Each gets hidden solid blocks:
	-- `solids` = { { half width, out from the wall, height } } from the wall outward.
	local machines = propsFor({ "TricepPulldown", "LatPulldown", "SeatedRow", "LegExtension" })
	if machines == nil then
		return
	end
	local function machine(id: string, wall: Wall, s: number, item: string, colourway: number,
		solids: { { number } })
		local depth = 0
		for _, solid in ipairs(solids) do
			depth = math.max(depth, solid[2])
		end
		local a, d = wall.at(s, depth / 2)
		propItem(kit, machines, id, item, colourway, a, d, 0.05, if wall == back then "-d" else "-a")
		local from = 0
		for k, solid in ipairs(solids) do
			hidden(wall.block(string.format("%s_Solid_%d", id, k), s - solid[1], s + solid[1], from, solid[2], 0, solid[3],
				looks.Glass))
			from = solid[2]
		end
	end
	-- Back wall, right of the mirror: two tricep pulldowns and two lat pulldowns.
	machine("Tricep_1", back, split + 3.5, "TricepPulldown", 2, { { 1.86, 3.5, 7.2 } })
	machine("LatPulldown_1", back, split + 9, "LatPulldown", 1, { { 1.73, 1.8, 7.3 }, { 0.9, 4.25, 1.6 } })
	machine("LatPulldown_2", back, split + 14.5, "LatPulldown", 3, { { 1.73, 1.8, 7.3 }, { 0.9, 4.25, 1.6 } })
	machine("Tricep_2", back, split + 20.5, "TricepPulldown", 1, { { 1.86, 3.5, 7.2 } })
	-- End wall: two leg extension / curl seats and two seated rows (their benches reach into the zone).
	machine("LegExtension_1", endWall, 6.5, "LegExtension", 1, { { 2.13, 3.94, 5.4 } })
	machine("LegExtension_2", endWall, 12, "LegExtension", 2, { { 2.13, 3.94, 5.4 } })
	machine("SeatedRow_1", endWall, 17.5, "SeatedRow", 1, { { 1.17, 2.2, 5.8 }, { 0.8, 7.14, 1.4 } })
	machine("SeatedRow_2", endWall, 22.5, "SeatedRow", 2, { { 1.17, 2.2, 5.8 }, { 0.8, 7.14, 1.4 } })
end

--[[
	The Cardio room (user 2026-10-26, from a drawn plan and Blender previews):
	a big wall TV on the back wall with four treadmills facing it, three
	exercise bikes behind them, two rowers on the left wall, two ski ergs on the
	right wall, a water cooler and a "heart-rate zones" board by the door. The
	running-track stripe of the room's front runs round the side walls. Each
	machine is tagged StarterGymConfig.CardioMachineTag (its item in "Kind") so
	CardioMachineService can let a player hop on it; fun only, no stats. The
	machines of RoomProps_09.
]]
FURNISH.Cardio = function(kit)
	local hw, D = kit.W / 2, kit.D
	local back, front = kit.wall("back"), kit.wall("front")
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.GymFloor)
	for _, which in ipairs({ "back", "front", "left", "right" }) do
		clad(kit, which, "Wall_" .. which, looks.LockersWall)
	end
	for _, which in ipairs({ "left", "right" }) do
		kit.wall(which).item("Track_" .. which, 0.4, D - 0.4, 0.08, 0.14, 1.4, 2.6, looks.CardioTrack)
	end
	--[[
		The wall TV (user 2026-10-28: "very bland and just a square", then "I want
		every model to be made in blender"): the Blender model CardioTV_01 (slim
		bezel, CENTRAL chin, power light, steel mount, soundbar), facing into the
		room, its screen centred at the old TV's height (8.5). Its screen piece is
		renamed "TV" and moved into the room's folder, and its idle sign is named
		"Writing": the treadmill game (CardioRhythmController) finds them by those
		names and draws the round over the screen. A blue backlight washes the
		wall behind. If the model fails to load, the block TV below is built.
	]]
	local tvProps = propsFor({ "CardioTV" })
	if tvProps then
		local a, d = back.at(0, 0.5)
		local unit = propItem(kit, tvProps, "CardioTV", "CardioTV", 1, a, d, 3.81, "-d")
		local screen = unit:FindFirstChild("CardioTV_Screen", true) :: BasePart?
		local bezel = unit:FindFirstChild("CardioTV_Bezel", true) :: BasePart?
		if screen and bezel then
			screen.Name = "TV"
			screen.Reflectance = 0.06
			screen.Parent = unit.Parent
			-- The pieces are turned, so pick each one's own face that looks along the direction.
			BuildParts.surfaceLight(bezel, StyledScreen.faceToward(bezel, -back.out), 9, 1.6, 120, Color3.fromRGB(70, 146, 255))
			StyledScreen.build(screen, StyledScreen.faceToward(screen, back.out), "CARDIO ZONE", { "Hop on any machine: hold E",
				"Treadmills: the rhythm run", "Beat the boards on the side walls", "Jump to hop off" }, "corner")
		end
	end
	if tvProps == nil then
	back.item("TV_Mount", -2.4, 2.4, 0.08, 0.22, 7, 10, looks.SteelBeam)
	local bezel = back.item("TV_Bezel", -6.95, 6.95, 0.22, 0.62, 4.95, 12.05, looks.Gadget)
	BuildParts.surfaceLight(bezel, faceToward(-back.out), 9, 1.6, 120, Color3.fromRGB(70, 146, 255))
	local tv = back.item("TV", -6.5, 6.5, 0.62, 0.7, 5.4, 11.6, looks.Gadget)
	tv.Reflectance = 0.06
	StyledScreen.build(tv, faceToward(back.out), "CARDIO ZONE", { "Hop on any machine: hold E",
		"Treadmills: the rhythm run", "Beat the boards on the side walls", "Jump to hop off" }, "corner")
	local logo = back.item("TV_Logo", -1.3, 1.3, 0.62, 0.66, 5.03, 5.33, looks.Gadget)
	plaque(logo, back.out, "CENTRAL", Color3.fromRGB(12, 12, 14), WHITE)
	back.item("TV_PowerLight", 6.15, 6.35, 0.62, 0.66, 5.12, 5.24, looks.GlowGreen)
	back.item("TV_Soundbar", -5.6, 5.6, 0.08, 0.72, 4.05, 4.7, looks.Gadget)
	back.item("TV_Soundbar_Trim", -5.6, 5.6, 0.72, 0.76, 4.6, 4.7, looks.PlateYellow)
	for index, s in ipairs({ -4.2, 4.2 }) do
		local a, d = back.at(s, 0.76)
		kit.cylinder("TV_Speaker_" .. index, a, d, 4.36, 0.04, 0.42, "d", looks.FrontCharcoal)
	end
	end
	local door = kit.doors.front[1] or kit.doorA
	local board = front.item("Board", door - 12.2, door - 6.2, 0.08, 0.16, 4.6, 8.6, looks.ClassroomBoard)
	writing(board, front.out, "HEART-RATE ZONES", { "1  50-60%  easy", "2  60-70%  steady", "3  70-80%  tempo",
		"4  80-90%  hard", "5  90%+  all out" }, Color3.fromRGB(46, 72, 66), Color3.fromRGB(236, 224, 196))
	-- The rhythm game's two leaderboards (user 2026-10-27: one on each side wall), between the rowers / ski ergs
	-- and the treadmills. Blank screens here; CardioRhythmLeaderboard fills the tagged SurfaceGuis.
	for which, boardName in pairs({ left = "AllTime", right = "Weekly" }) do
		local wall = kit.wall(which)
		local screen = wall.item("Leaderboard_" .. boardName, 12.6, 21.4, 0.08, 0.24, 3.4, 10.6, looks.Gadget)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Leaderboard"
		gui.Face = faceToward(wall.out)
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		gui:SetAttribute("Board", boardName)
		gui:AddTag(CardioRhythmConfig.Leaderboard.BoardTag)
		gui.Parent = screen
	end

	local props = propsFor({ "Treadmill", "ExerciseBike", "Rower", "SkiErg", "WaterCooler" })
	if props == nil then
		return
	end
	local function put(name: string, item: string, colourway: number, a: number, d: number, facing: string): Model
		return propItem(kit, props, name, item, colourway, a, d, 0.06, facing)
	end
	-- A machine players can hop on, with a hidden solid block over its footprint (`w` across, `l` along).
	local function machine(name: string, item: string, colourway: number, a: number, d: number, facing: string, w: number,
		l: number, h: number)
		local model = put(name, item, colourway, a, d, facing)
		model:SetAttribute("Kind", item)
		model:AddTag(StarterGymConfig.CardioMachineTag)
		local alongA = facing == "+a" or facing == "-a"
		local ha, hd = if alongA then l / 2 else w / 2, if alongA then w / 2 else l / 2
		hidden(kit.block(name .. "_Solid", a - ha, a + ha, d - hd, d + hd, 0.06, h, looks.Glass))
	end
	-- Four treadmills, consoles to the TV wall; the runner faces the TV.
	for k, s in ipairs({ -7.5, -2.5, 2.5, 7.5 }) do
		local a, d = back.at(s, 3.15)
		machine("Treadmill_" .. k, "Treadmill", (k - 1) % 3 + 1, a, d, "-d", 3.1, 6.3, 4.8)
	end
	-- Three bikes behind them, also facing the TV.
	for k, a in ipairs({ -6, 0, 6 }) do
		machine("Bike_" .. k, "ExerciseBike", k, a, D - 11.6, "-d", 1.9, 3.6, 3.6)
	end
	-- Two rowers on the left wall and two ski ergs on the right wall, near the door.
	local left, right = kit.wall("left"), kit.wall("right")
	for k, s in ipairs({ 7, 10.5 }) do
		local a, d = left.at(s, 4.05)
		machine("Rower_" .. k, "Rower", k, a, d, "+a", 1.9, 8.1, 3.6)
	end
	for k, s in ipairs({ 7, 11 }) do
		local a, d = right.at(s, 1.45)
		machine("SkiErg_" .. k, "SkiErg", k + 1, a, d, "-a", 2.1, 2.9, 6.4)
	end
	-- The water cooler by the door.
	local ca, cd = front.at(door + 7.5, 0.85)
	put("WaterCooler", "WaterCooler", 1, ca, cd, "+d")
	hidden(front.block("WaterCooler_Solid", door + 6.9, door + 8.1, 0.1, 1.5, 0.06, 3.4, looks.Glass))
end

-- The first recovery room (step 6a), kept for when the 3D props do not load.
local function simpleRecovery(kit: Kit)
	local hw = kit.W / 2
	local back = kit.wall("back")
	iceBath(back, "IceBath_1", -10, -5)
	iceBath(back, "IceBath_2", 5, 10)
	local left = kit.wall("left")
	local rollerLooks = { looks.PlateBlue, looks.Gadget }
	for index, s0 in ipairs({ 9, 15.5 }) do
		left.item("Mat_" .. index, s0, s0 + 5, 0.5, 3.5, 0, 0.1, looks.Mat)
		local a, d = left.at(s0 + 2.5, 2)
		kit.cylinder("FoamRoller_" .. index, a, d, 0.5, 3, 0.8, left.axis, rollerLooks[index])
	end
	local right = kit.wall("right")
	shelving(kit, right, "TowelShelf", 9, 15, 1.4, 6, 3, looks.DeskBody, towels(kit, right, "TowelShelf"))
	bench(kit, "Bench", -4, 4, 13, 14.4)
	plant(kit, "Plant", hw - 1.5, 1.5)
end

-- The first massage room (step 6a), kept for when the 3D props do not load.
local function simpleMassage(kit: Kit)
	local hw, D = kit.W / 2, kit.D
	paddedTable(kit, "Table_1", -6, 11, 18, looks.Padding)
	paddedTable(kit, "Table_2", 6, 11, 18, looks.Padding)
	stool(kit, "Stool_1", -3, 14)
	stool(kit, "Stool_2", 3, 14)
	local back = kit.wall("back")
	shelving(kit, back, "TowelShelf", -6, 6, 1.5, 6, 3, looks.Wood, towels(kit, back, "TowelShelf"))
	local left = kit.wall("left")
	for index = 0, 7 do
		left.item("Slat_" .. index + 1, 8 + index * 1.4, 8.6 + index * 1.4, 0, 0.15, 1, 9, looks.Wood)
	end
	plant(kit, "Plant_1", -hw + 1.5, D - 1.5)
	plant(kit, "Plant_2", hw - 1.5, D - 1.5)
end

-- An oak shelf (6 along `wall` from s0, 6.2 tall, 3 boards) of folded 3D towels:
-- three stacks of two on every board, the colours starting `colourOffset` on.
local function towelShelf(kit: Kit, templates: { [string]: Model }, wall: Wall, facing: string, name: string, s0: number,
	colourOffset: number)
	shelving(kit, wall, name, s0, s0 + 6, 1.4, 6.2, 3, looks.LockersSlats)
	for level = 1, 3 do
		local y = 0.3 + (level - 1) * 6.2 / 3
		for k = 0, 2 do
			local a, d = wall.at(s0 + 1.1 + k * 1.9, 0.78)
			for fold = 0, 1 do
				propItem(kit, templates, string.format("%s_Towel_%d_%d_%d", name, level, k + 1, fold + 1), "Towel",
					(level * 3 + k + colourOffset) % 6 + 1, a, d, y + fold * 0.26, facing)
			end
		end
	end
end

--[[
	The showers (GAME_DESIGN §27: look only), behind the private Lockers and
	only reached through them. Remade 2026-10-26 with CC0 textures and 3D
	props: a dark blue mosaic floor; five stalls in white marble tiles along
	the back wall, each with a rain shower, a soap dispenser, a shelf of
	CENTRAL body wash and shampoo, a glass screen and an oak duckboard; a
	terrazzo wall and an oak bench with towels on rails and slides; a shelf of
	folded towels, used-towel bins and a SHOWERS sign.
]]
FURNISH.Showers = function(kit)
	local props = propsFor({ "RainShower", "ShowerGel", "Shampoo", "SoapDispenser", "Towel", "HangingTowel", "TowelBin",
		"Slides", "LockerBench", "SBarPlant" })
	if props == nil then
		simpleShowers(kit)
		return
	end
	local hw, D = kit.W / 2, kit.D
	local back, left, right = kit.wall("back"), kit.wall("left"), kit.wall("right")
	-- The stall screens, duckboards and shelves (Spa_01, CafeShop_01), or nil: blocks.
	local spa = propsFor({ "ShowerScreen", "Duckboard", "WallShelf" })
	local function put(name: string, item: string, colourway: number, a: number, d: number, y: number, facing: string): Model
		return propItem(kit, props, name, item, colourway, a, d, y, facing)
	end
	-- Against `wall`, `t` out from it, facing `facing` (into the room).
	local function onWall(wall: Wall, facing: string, name: string, item: string, colourway: number, s: number, t: number,
		y: number): Model
		local a, d = wall.at(s, t)
		return put(name, item, colourway, a, d, y, facing)
	end

	-- The room's surfaces.
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.ShowersFloor)
	clad(kit, "back", "Wall_Tiles", looks.ShowersTiles)
	clad(kit, "left", "Wall_Terrazzo", looks.ShowersTerrazzo)
	clad(kit, "right", "Wall_Right", looks.ShowersTiles)
	clad(kit, "front", "Wall_Front", looks.ShowersTiles)

	-- Five stalls along the back wall with tiled walls between them.
	local unit, depth = 5.8, 5
	local first = -2.5 * unit
	for k = 0, 5 do
		local s = first + k * unit
		back.block("Stall_Wall_" .. k, s - 0.2, s + 0.2, 0.08, depth, 0.06, 8.5, looks.ShowersTiles)
	end
	for k = 1, 5 do
		local c, id = first + (k - 0.5) * unit, "Stall_" .. k
		onWall(back, "-d", id .. "_Shower", "RainShower", k % 3 + 1, c, 1.15, 4)
		onWall(back, "-d", id .. "_Soap", "SoapDispenser", 1, c - 1.7, 0.3, 4.4)
		if spa then
			-- A steel shelf on brackets reaching 0.5 under it (CafeShop_01 WallShelf).
			wallProp(kit, spa, back, id .. "_Shelf", "WallShelf", c + 0.95, c + 2.45, 0.08, 0.7, 4.1, 4.72,
				{ Board = looks.Stainless })
		else
			back.item(id .. "_Shelf", c + 0.95, c + 2.45, 0.08, 0.7, 4.6, 4.72, looks.Stainless)
		end
		onWall(back, "-d", id .. "_Gel", "ShowerGel", k, c + 1.35, 0.4, 4.72)
		onWall(back, "-d", id .. "_Shampoo", "Shampoo", (k - 1) % 4 + 1, c + 2, 0.4, 4.72)
		back.item(id .. "_Drain", c - 2, c + 2, 3.7, 3.9, 0.06, 0.08, looks.Gadget)
		-- A glass screen across the right half of the opening, in a black frame; an oak duckboard.
		if spa then
			wallProp(kit, spa, back, id .. "_Screen", "ShowerScreen", c + 0.1, c + 2.5, depth - 0.12, depth + 0.02, 0.06, 7.6)
			wallProp(kit, spa, back, id .. "_Duckboard", "Duckboard", c - 1.6, c + 1.6, depth + 0.4, depth + 1.72, 0.06, 0.18,
				{ Slats = looks.LockersSlats })
		else
			back.item(id .. "_Glass", c + 0.2, c + 2.5, depth - 0.1, depth, 0.06, 7.5, looks.Glass)
			back.item(id .. "_GlassEdge", c + 0.1, c + 0.2, depth - 0.12, depth + 0.02, 0.06, 7.6, looks.Gadget)
			back.item(id .. "_GlassTop", c + 0.1, c + 2.5, depth - 0.12, depth + 0.02, 7.5, 7.6, looks.Gadget)
			for slat = 0, 5 do
				local t = depth + 0.4 + slat * 0.3
				back.item(string.format("%s_Duckboard_%d", id, slat + 1), c - 1.6, c + 1.6, t, t + 0.22, 0.06, 0.18,
					looks.LockersSlats)
			end
		end
	end
	neonSign(back, "Sign", "SHOWERS", -7, 7, 9.4, 11.4, Color3.fromRGB(120, 210, 235), Color3.fromRGB(20, 70, 95),
		looks.GlowIce)

	-- The terrazzo wall: an oak bench with slides under it, towels on rails above, a towel bin.
	onWall(left, "+a", "Bench_1", "LockerBench", 1, 10, 0.95, 0.06)
	hidden(left.block("Bench_Solid_1", 6, 14, 0.15, 1.75, 0.06, 1.86, looks.Glass))
	for index, s in ipairs({ 6.5, 9, 11.5, 14 }) do
		onWall(left, "+a", "RailTowel_Left_" .. index, "HangingTowel", index + 1, s, 0.41, 3.6)
	end
	onWall(left, "+a", "Slides_1", "Slides", 2, 8, 0.9, 0.06)
	onWall(left, "+a", "Slides_2", "Slides", 5, 12, 0.9, 0.06)
	onWall(left, "+a", "TowelBin_1", "TowelBin", 1, 18, 0.95, 0.06)

	-- The other wall: a shelf of folded towels, a towel bin, a bench with towels above it.
	towelShelf(kit, props, right, "-a", "TowelShelf", 2.5, 0)
	onWall(right, "-a", "TowelBin_2", "TowelBin", 3, 11, 0.95, 0.06)
	onWall(right, "-a", "Bench_2", "LockerBench", 1, 18, 0.95, 0.06)
	hidden(right.block("Bench_Solid_2", 14, 22, 0.15, 1.75, 0.06, 1.86, looks.Glass))
	for index, s in ipairs({ 15, 17.5, 20 }) do
		onWall(right, "-a", "RailTowel_Right_" .. index, "HangingTowel", index, s, 0.41, 3.6)
	end
	onWall(right, "-a", "Slides_3", "Slides", 3, 16, 0.9, 0.06)

	-- Plants by the Lockers wall.
	put("Plant_1", "SBarPlant", 1, -hw + 1.8, 1.7, 0.06, "+d")
	put("Plant_2", "SBarPlant", 1, hw - 1.8, 1.7, 0.06, "+d")
end

--[[
	Recovery (GAME_DESIGN §27: a relax spot, with sit and lie-down emotes
	later). Remade 2026-10-26 with CC0 textures and 3D props: a rubber floor, a
	micro-cement back wall and icy blue walls; two cold plunge tubs with ice;
	four zero-gravity loungers; stretching mats with foam rollers and towels;
	an oak wall ladder; a shelf of foam rollers, rolled yoga mats and CENTRAL
	massage guns; an icy RECOVERY sign.
]]
FURNISH.Recovery = function(kit)
	local props = propsFor({ "ColdPlunge", "FoamRoller", "Lounger", "MassageGun", "YogaMat", "WaterBottle", "Towel",
		"SBarPlant" })
	if props == nil then
		simpleRecovery(kit)
		return
	end
	local hw, D = kit.W / 2, kit.D
	local back, left, right = kit.wall("back"), kit.wall("left"), kit.wall("right")
	-- The plunge steps, wall ladders and mats (Spa_01), or nil: blocks.
	local spa = propsFor({ "PlungeStep", "WallLadder", "FloorMat" })
	local function put(name: string, item: string, colourway: number, a: number, d: number, y: number, facing: string): Model
		return propItem(kit, props, name, item, colourway, a, d, y, facing)
	end
	local function onWall(wall: Wall, facing: string, name: string, item: string, colourway: number, s: number, t: number,
		y: number): Model
		local a, d = wall.at(s, t)
		return put(name, item, colourway, a, d, y, facing)
	end

	-- The room's surfaces.
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.RecoveryFloor)
	clad(kit, "back", "Wall_Cement", looks.RecoveryCement)
	clad(kit, "left", "Wall_Left", looks.RecoveryWall)
	clad(kit, "right", "Wall_Right", looks.RecoveryWall)

	-- Two cold plunge tubs against the back wall, an oak step in front of each, the sign above.
	for index, spec in ipairs({ { s = -8.5, colourway = 1 }, { s = -2.5, colourway = 2 } }) do
		local id = "ColdPlunge_" .. index
		onWall(back, "-d", id, "ColdPlunge", spec.colourway, spec.s, 2.8, 0.06)
		hidden(back.block(id .. "_Solid", spec.s - 2.2, spec.s + 2.2, 0.6, 5, 0.06, 2.96, looks.Glass))
		local step = back.block(id .. "_Step", spec.s - 1, spec.s + 1, 5.3, 6.3, 0.06, 1, looks.LockersSlats)
		if spa then
			-- The Spa_01 two-tread step on the old block, now hidden.
			hidden(step)
			wallProp(kit, spa, back, id .. "_StepModel", "PlungeStep", spec.s - 1, spec.s + 1, 5.3, 6.3, 0.06, 1,
				{ Wood = looks.LockersSlats })
		end
	end
	neonSign(back, "Sign", "RECOVERY", -11, 0, 8.8, 10.8, Color3.fromRGB(225, 245, 255), Color3.fromRGB(40, 110, 160),
		looks.GlowIce)

	-- A shelf of foam rollers, rolled yoga mats, massage guns and bottles.
	shelving(kit, back, "GearShelf", 2, 12, 1.4, 5.6, 3, looks.LockersSlats)
	local spacing = 5.6 / 3
	for k = 0, 2 do
		local s = 3.75 + k * 3.25
		onWall(back, "-d", "Shelf_Roller_" .. k + 1, "FoamRoller", k * 2 + 1, s, 0.75, 0.3)
		onWall(back, "-d", "Shelf_Mat_" .. k + 1, "YogaMat", k + 1, s, 0.75, 0.3 + spacing)
	end
	for k = 0, 3 do
		onWall(back, "-d", "Shelf_MassageGun_" .. k + 1, "MassageGun", k + 1, 3 + k * 2, 0.75, 0.3 + 2 * spacing)
	end
	for k = 0, 1 do
		onWall(back, "-d", "Shelf_Bottle_" .. k + 1, "WaterBottle", k + 2, 10.6 + k * 0.7, 0.75, 0.3 + 2 * spacing)
	end

	-- Four loungers with their heads to the right wall, a water bottle beside each.
	for index, s in ipairs({ 7.5, 11, 14.5, 18 }) do
		local id = "Lounger_" .. index
		onWall(right, "-a", id, "Lounger", index, s, 3.3, 0.06)
		hidden(right.block(id .. "_Solid", s - 1.25, s + 1.25, 0.3, 6.2, 0.06, 1.7, looks.Glass))
		onWall(right, "-a", id .. "_Bottle", "WaterBottle", index, s + 1.7, 1, 0.06)
	end

	-- An oak wall ladder for stretching on the left wall.
	for ladder = 0, 1 do
		local s0 = 7 + ladder * 3.6
		if spa then
			wallProp(kit, spa, left, "Ladder_" .. ladder + 1, "WallLadder", s0 - 0.12, s0 + 3.12, 0.08, 0.5, 0.06, 9.6,
				{ Wood = looks.LockersSlats })
		else
			for side, s in ipairs({ s0, s0 + 3 }) do
				left.item(string.format("Ladder_%d_Rail_%d", ladder + 1, side), s - 0.12, s + 0.12, 0.08, 0.5, 0.06, 9.6,
					looks.LockersSlats)
			end
			local a, d = left.at(s0 + 1.5, 0.3)
			for rung = 1, 16 do
				kit.cylinder(string.format("Ladder_%d_Rung_%d", ladder + 1, rung), a, d, 0.06 + rung * 0.58, 2.76, 0.22,
					left.axis, looks.LockersSlats)
			end
		end
	end
	hidden(left.block("Ladder_Solid", 6.8, 13.8, 0.08, 0.55, 0.06, 9.6, looks.Glass))

	-- Stretching mats in the middle, a foam roller and a folded towel on each.
	for index, spec in ipairs({ { a = -9.5, look = looks.MatTeal }, { a = -5.5, look = looks.MatCoral },
		{ a = -1.5, look = looks.MatLavender } }) do
		local id = "Mat_" .. index
		if spa then
			paintLooks(put(id, "FloorMat", 1, spec.a, 12.25, 0.06, "-d"), "FloorMat", { Mat = spec.look })
		else
			kit.item(id, spec.a - 1.4, spec.a + 1.4, 9, 15.5, 0.06, 0.14, spec.look)
		end
		put(id .. "_Roller", "FoamRoller", index + 1, spec.a, 10.2, 0.14, "-d")
		put(id .. "_Towel", "Towel", index + 1, spec.a, 14.6, 0.14, "-d")
	end

	-- Plants by the glass.
	put("Plant_1", "SBarPlant", 1, -hw + 1.8, 1.7, 0.06, "+d")
	put("Plant_2", "SBarPlant", 1, hw - 1.8, 1.7, 0.06, "+d")
end

--[[
	Massage (GAME_DESIGN §27: a relax spot, with sit and lie-down emotes
	later). Remade 2026-10-26 with CC0 textures and 3D props: a light wood
	floor, a grey stone back wall and warm limewash walls; two massage tables
	with face cradles, bolsters and towels, a folding screen between them and a
	warm lamp over each; oak shelves of candles, diffusers, CENTRAL massage
	oils and spa stones under a warm MASSAGE sign; folded towels; poufs round
	a low table by the glass.
]]
FURNISH.Massage = function(kit)
	local props = propsFor({ "MassageTable", "OilBottle", "CandleSet", "Diffuser", "SpaStones", "Pouf", "FoldingScreen",
		"Towel", "PendantLamp", "SBarPlant" })
	if props == nil then
		simpleMassage(kit)
		return
	end
	local hw, D = kit.W / 2, kit.D
	local back, left = kit.wall("back"), kit.wall("left")
	local function put(name: string, item: string, colourway: number, a: number, d: number, y: number, facing: string): Model
		return propItem(kit, props, name, item, colourway, a, d, y, facing)
	end
	local function onBack(name: string, item: string, colourway: number, s: number, t: number, y: number): Model
		local a, d = back.at(s, t)
		return put(name, item, colourway, a, d, y, "-d")
	end
	-- A small warm light in a candle's flames or a diffuser's glow ring.
	local function glow(model: Model, piece: string)
		local part = model:FindFirstChild(piece, true)
		if part then
			warmGlow(part :: BasePart, 8, 0.4)
		end
	end

	-- The room's surfaces.
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.MassageFloor)
	clad(kit, "back", "Wall_Stone", looks.MassageStone)
	clad(kit, "left", "Wall_Left", looks.MassageWall)
	clad(kit, "right", "Wall_Right", looks.MassageWall)

	-- Two massage tables, their face cradles toward the stone wall, a warm
	-- lamp over each and a folding screen between them.
	for index, spec in ipairs({ { a = -6.5, colourway = 1, lamp = 1 }, { a = 6.5, colourway = 2, lamp = 3 } }) do
		local id = "Table_" .. index
		put(id, "MassageTable", spec.colourway, spec.a, D - 5.8, 0.06, "-d")
		hidden(kit.block(id .. "_Solid", spec.a - 1.5, spec.a + 1.5, D - 10.5, D - 2.5, 0.06, 3.36, looks.Glass))
		pendant(kit, props, id .. "_Lamp", spec.lamp, spec.a, D - 6.5, 7.6)
	end
	put("Screen", "FoldingScreen", 1, 0, D - 6.5, 0.06, "+a")
	hidden(kit.block("Screen_Solid", -0.5, 0.5, D - 9.3, D - 3.7, 0.06, 6.4, looks.Glass))

	-- Oak shelves on the stone wall: candles, diffusers, oils and stones; the sign above.
	-- Oak boards on brackets reaching 0.5 under them (CafeShop_01 WallShelf), or blocks.
	local shelfProps = propsFor({ "WallShelf" })
	for level, y in ipairs({ 4.4, 6.4 }) do
		if shelfProps then
			wallProp(kit, shelfProps, back, "Shelf_" .. level, "WallShelf", -3.6, 3.6, 0.08, 1.1, y - 0.65, y,
				{ Board = looks.LockersSlats })
		else
			back.item("Shelf_" .. level, -3.6, 3.6, 0.08, 1.1, y - 0.15, y, looks.LockersSlats)
		end
	end
	glow(onBack("Shelf_Candles_1", "CandleSet", 1, -2.4, 0.6, 4.4), "CandleSet_Flame")
	glow(onBack("Shelf_Diffuser_1", "Diffuser", 1, -0.2, 0.6, 4.4), "Diffuser_Light")
	for k = 0, 2 do
		onBack("Shelf_Oil_" .. k + 1, "OilBottle", k + 1, 1.6 + k * 0.5, 0.55, 4.4)
	end
	onBack("Shelf_Stones", "SpaStones", 1, -2.3, 0.6, 6.4)
	glow(onBack("Shelf_Candles_2", "CandleSet", 3, 0.3, 0.6, 6.4), "CandleSet_Flame")
	onBack("Shelf_Diffuser_2", "Diffuser", 2, 2.5, 0.6, 6.4)
	neonSign(back, "Sign", "MASSAGE", -6, 6, 8.8, 10.8, Color3.fromRGB(255, 214, 150), Color3.fromRGB(150, 90, 30),
		looks.GlowWarm)

	-- Folded towels on the left wall.
	towelShelf(kit, props, left, "+a", "TowelShelf", 4, 2)

	-- A waiting corner by the glass: poufs round a low oak table with candles.
	roundTable(kit, "LowTable", 9.8, 6.2, looks.LockersSlats, 2)
	glow(put("LowTable_Candles", "CandleSet", 4, 9.8, 6.2, 2, "-d"), "CandleSet_Flame")
	for index, spot in ipairs({ { 9.8, 3.6 }, { 9.8, 8.8 }, { 7.2, 6.2 } }) do
		put("Pouf_" .. index, "Pouf", index, spot[1], spot[2], 0.06, "-d")
		hidden(kit.block("Pouf_Solid_" .. index, spot[1] - 0.8, spot[1] + 0.8, spot[2] - 0.8, spot[2] + 0.8, 0.06, 1.66,
			looks.Glass))
	end

	-- Plants.
	put("Plant_1", "SBarPlant", 1, -hw + 1.8, 1.7, 0.06, "+d")
	put("Plant_2", "SBarPlant", 1, -hw + 1.8, D - 1.8, 0.06, "-d")
	put("Plant_3", "SBarPlant", 1, hw - 1.8, D - 1.8, 0.06, "-d")
end

--[[
	The spa reception (GAME_DESIGN §27 "Closed rooms and the spa wing", user
	2026-10-26): the front room of the upstairs Recovery & Spa wing, its one
	door from the balcony, the corridor to the Sauna, Recovery and Massage
	opening off its right wall by the door. Built from the approved spa looks
	and props: the light wood floor, the stone wall behind an oak desk with a
	white marble top and a warm glow, a "RECOVERY & SPA" sign, candles, a
	diffuser and CENTRAL oils on the desk, warm pendant lamps; a waiting corner
	of poufs round a low table; a shelf of folded towels; plants.
]]
FURNISH.SpaReception = function(kit)
	local props = propsFor({ "CandleSet", "Diffuser", "OilBottle", "Pouf", "Towel", "PendantLamp", "SpaStones",
		"SBarPlant" })
	if props == nil then
		return
	end
	local hw, D = kit.W / 2, kit.D
	local back, left = kit.wall("back"), kit.wall("left")
	local function put(name: string, item: string, colourway: number, a: number, d: number, y: number, facing: string): Model
		return propItem(kit, props, name, item, colourway, a, d, y, facing)
	end
	local function glow(model: Model, piece: string)
		local part = model:FindFirstChild(piece, true)
		if part then
			warmGlow(part :: BasePart, 8, 0.4)
		end
	end

	-- The room's surfaces. The corridor opens in the right wall by the door
	-- (it is not a room, so the kit has no door there): that wall is covered
	-- only beyond the corridor's wall, about 6 in.
	local right = kit.wall("right")
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.MassageFloor)
	clad(kit, "back", "Wall_Stone", looks.MassageStone)
	clad(kit, "left", "Wall_Left", looks.MassageWall)
	right.item("Wall_Right", 6, D, 0, 0.08, 0.06, kit.H, looks.MassageWall)

	-- An oak bench along the right wall with rolled towels, and a plant beside it.
	-- The oak locker bench and the counter (CafeShop_01) on hidden solid blocks, or blocks.
	local furniture = propsFor({ "LockerBench", "CounterUnit" })
	local bench = right.block("Bench", 9, 17, 0.08, 1.7, 0.06, 1.5, looks.LockersSlats)
	if furniture then
		hidden(bench)
		wallProp(kit, furniture, right, "Bench_Model", "LockerBench", 9, 17, 0.08, 1.7, 0.06, 1.5)
	end
	for k = 0, 2 do
		local a, d = right.at(10.5 + k * 2.5, 0.9)
		put("Bench_Towel_" .. k + 1, "Towel", k + 2, a, d, 1.5, "-a")
	end
	local pa, pd = right.at(19, 1.8)
	put("Plant_4", "SBarPlant", 1, pa, pd, 0.06, "-a")
	neonSign(back, "Sign", "RECOVERY & SPA", -7, 7, 8.4, 10.6, Color3.fromRGB(255, 240, 220), Color3.fromRGB(60, 120, 100),
		looks.GlowWarm)

	-- The desk in front of the stone wall, facing the door.
	local d0, d1 = D - 8, D - 5.6
	local deskBody = kit.block("Desk_Body", -5, 5, d0, d1, 0.06, 3.4, looks.LockersSlats)
	if furniture then
		-- The counter (oak body, marble top overhanging the front), the old body block hidden under it.
		hidden(deskBody)
		paintLooks(propItem(kit, furniture, "Desk", "CounterUnit", 1, 0, (d0 - 0.2 + d1 + 0.1) / 2, 0.06, "-d",
			Vector3.new(10.4, 3.54, d1 - d0 + 0.3)), "CounterUnit", { Body = looks.LockersSlats, Top = looks.CafeMarble })
	else
		kit.item("Desk_Top", -5.2, 5.2, d0 - 0.2, d1 + 0.1, 3.4, 3.6, looks.CafeMarble)
	end
	local deskGlow = kit.item("Desk_Glow", -4.8, 4.8, d0 - 0.06, d0, 0.2, 0.32, looks.GlowWarm)
	warmGlow(deskGlow, 6, 0.5)
	glow(put("Desk_Candles", "CandleSet", 2, -3.6, d0 + 1.1, 3.6, "-d"), "CandleSet_Flame")
	glow(put("Desk_Diffuser", "Diffuser", 1, 3.8, d0 + 1.1, 3.6, "-d"), "Diffuser_Light")
	for k = 0, 2 do
		put("Desk_Oil_" .. k + 1, "OilBottle", k + 1, -0.6 + k * 0.6, d0 + 1, 3.6, "-d")
	end
	put("Desk_Stones", "SpaStones", 1, 1.8, d0 + 1.1, 3.6, "-d")
	for index, a in ipairs({ -3, 3 }) do
		pendant(kit, props, "Desk_Lamp_" .. index, index * 2 - 1, a, d0 + 1.2, 7.4)
	end

	-- A waiting corner by the left wall: poufs round a low oak table with candles.
	local ta, td = -hw + 4.5, D / 2 - 1
	roundTable(kit, "LowTable", ta, td, looks.LockersSlats, 2)
	glow(put("LowTable_Candles", "CandleSet", 3, ta, td, 2, "-d"), "CandleSet_Flame")
	for index, spot in ipairs({ { ta, td - 2.6 }, { ta, td + 2.6 }, { ta + 2.6, td } }) do
		put("Pouf_" .. index, "Pouf", index, spot[1], spot[2], 0.06, "-a")
		hidden(kit.block("Pouf_Solid_" .. index, spot[1] - 0.8, spot[1] + 0.8, spot[2] - 0.8, spot[2] + 0.8, 0.06, 1.66,
			looks.Glass))
	end

	-- Folded towels on the left wall, near the desk.
	towelShelf(kit, props, left, "+a", "TowelShelf", D - 15, 3)

	-- Plants in the corners by the stone wall and beside the door.
	put("Plant_1", "SBarPlant", 1, -hw + 1.8, D - 1.8, 0.06, "-d")
	put("Plant_2", "SBarPlant", 1, hw - 1.8, D - 1.8, 0.06, "-d")
	put("Plant_3", "SBarPlant", 1, -hw + 1.8, 1.7, 0.06, "+d")
end

FURNISH.Storage = function(kit)
	local hw = kit.W / 2
	local back = kit.wall("back")
	shelving(kit, back, "Shelving", -hw + 0.5, hw - 0.5, 2, 8, 4, looks.Stainless, boxes(kit, back, "Shelving"))
	local left = kit.wall("left")
	local stacks = {
		{ looks.PlateRed, looks.PlateRed, looks.PlateRed, looks.PlateRed, looks.PlateRed, looks.PlateRed },
		{ looks.PlateBlue, looks.PlateBlue, looks.PlateBlue, looks.PlateBlue },
		{ looks.PlateYellow, looks.PlateYellow, looks.PlateGreen, looks.PlateGreen, looks.PlateGreen },
	}
	for index, s in ipairs({ 9, 12.5, 16 }) do
		local a, d = left.at(s, 1.6)
		plateStack(kit, "Plates_" .. index, a, d, stacks[index])
	end
	local right = kit.wall("right")
	-- The bar holder with its bars (on the old holder block, now hidden) and the spare boxes are Blender models
	-- (BackRooms_01, Furniture_01), or blocks.
	local storageProps = propsFor({ "BarStand", "StorageBox" })
	local holder = right.block("BarHolder", 9, 15, 0, 1.2, 0, 0.6, looks.SteelBeam)
	if storageProps then
		hidden(holder)
		wallProp(kit, storageProps, right, "BarStand", "BarStand", 9, 15, 0, 1.2, 0, 10.4, { Holder = looks.SteelBeam })
		propItem(kit, storageProps, "Boxes_1", "StorageBox", 1, hw - 2.5, 3.25, 0, "+d", Vector3.new(3, 2, 2.5))
		propItem(kit, storageProps, "Boxes_2", "StorageBox", 1, hw - 2.6, 3.25, 2, "+d", Vector3.new(2.4, 1.6, 1.9))
	else
		for index = 0, 4 do
			local a, d = right.at(9.6 + index * 1.2, 0.6)
			kit.cylinder("Bar_" .. index + 1, a, d, 0.6 + 4.9, 9.8, 0.14, "up", looks.Stainless)
			kit.cylinder("Bar_" .. index + 1 .. "_Sleeve", a, d, 0.6 + 9.8 - 1.8, 3.6, 0.22, "up", looks.Stainless)
		end
		kit.item("Boxes_1", hw - 4, hw - 1, 2, 4.5, 0, 2, looks.Cardboard)
		kit.item("Boxes_2", hw - 3.8, hw - 1.4, 2.3, 4.2, 2, 3.6, looks.Cardboard)
	end
end

--[[
	The sauna (user, 2026-10-23: "make it seem like an actual sauna", no open
	door). A wooden cabin inside the room: boards on the floor, on all four
	walls (the glass front too, around the door and one small window) and a
	low wooden ceiling; two tiers of slatted benches with a backrest; the
	heater with stones behind a wooden guard; warm lights only (no white
	panel: StarterGymConfig.OwnLightRooms). The real wooden door is built by
	StarterGymBuilder in the doorway.
]]
FURNISH.Sauna = function(kit)
	local hw, D, H = kit.W / 2, kit.D, kit.H
	local saunaDoor = StarterGymConfig.SwingDoors.Sauna
	local door, doorHalf = kit.doorA, saunaDoor.width / 2
	local doorTop = saunaDoor.height
	local back, front, left = kit.wall("back"), kit.wall("front"), kit.wall("left")
	local board, slat = looks.SaunaWood, looks.SaunaBench
	-- The Spa_01 models (benches, duckboard, heater, lamps, bucket, thermometer) and towels, or nil: blocks.
	local spa = propsFor({ "SaunaBench", "Duckboard", "SaunaHeater", "SaunaLamp", "SaunaBucket", "Thermometer", "Towel" })

	-- The cabin: floor, walls up to the ceiling, a lower wooden ceiling.
	kit.item("Floor", -hw, hw, 0, D, 0, 0.1, board)
	back.item("Wall_Back", -hw, hw, 0, 0.15, 0.1, H, board)
	left.item("Wall_Left", 0.15, D - 0.15, 0, 0.15, 0.1, H, board)
	kit.wall("right").item("Wall_Right", 0.15, D - 0.15, 0, 0.15, 0.1, H, board)
	local w0, w1, wy0, wy1 = door + 5, door + 10, 3.5, 7.5 -- the small window, away from the heater
	front.item("Wall_Front_1", -hw, door - doorHalf, 0, 0.15, 0.1, H, board)
	front.item("Wall_Front_OverDoor", door - doorHalf, door + doorHalf, 0, 0.15, doorTop, H, board)
	front.item("Wall_Front_2", door + doorHalf, w0, 0, 0.15, 0.1, H, board)
	front.item("Wall_Front_UnderWindow", w0, w1, 0, 0.15, 0.1, wy0, board)
	front.item("Wall_Front_OverWindow", w0, w1, 0, 0.15, wy1, H, board)
	front.item("Wall_Front_3", w1, hw, 0, 0.15, 0.1, H, board)
	front.item("Window", w0, w1, 0.05, 0.1, wy0, wy1, looks.SaunaGlass)
	front.item("Window_Sill", w0 - 0.2, w1 + 0.2, 0.15, 0.45, wy0 - 0.15, wy0, slat)
	front.item("Window_Head", w0 - 0.2, w1 + 0.2, 0.15, 0.3, wy1, wy1 + 0.15, slat)
	front.item("Door_Casing_Top", door - doorHalf - 0.25, door + doorHalf + 0.25, 0.15, 0.3, doorTop, doorTop + 0.25, slat)
	front.item("Door_Casing_1", door - doorHalf - 0.25, door - doorHalf, 0.15, 0.3, 0.1, doorTop, slat)
	front.item("Door_Casing_2", door + doorHalf, door + doorHalf + 0.25, 0.15, 0.3, 0.1, doorTop, slat)
	kit.item("Ceiling", -hw + 0.15, hw - 0.15, 0.15, D - 0.15, 9.85, 10, board)

	-- Two tiers of slatted benches with a backrest and warm LED strips under
	-- both front edges, along a wall from s0 to s1.
	local function benchTiers(wall: Wall, name: string, s0: number, s1: number)
		if spa then
			-- The Spa_01 tiers stretched along the wall, on hidden solid blocks like the old bases and slats.
			wallProp(kit, spa, wall, name, "SaunaBench", s0, s1, 0.15, 5.66, 0.1, 5.95, { Base = board, Slats = slat })
			hidden(wall.block(name .. "_Upper_Solid", s0, s1, 0.15, 3.2, 0.1, 3.15, board))
			hidden(wall.block(name .. "_Lower_Solid", s0, s1, 3.2, 5.6, 0.1, 1.65, board))
		else
			wall.block(name .. "_Upper_Base", s0, s1, 0.15, 3.2, 0.1, 3, board)
			for k = 0, 5 do
				local t0 = 0.25 + k * 0.5
				wall.block(name .. "_Upper_Slat_" .. k + 1, s0, s1, t0, t0 + 0.42, 3, 3.15, slat)
			end
			wall.item(name .. "_Upper_Skirt", s0, s1, 3.2, 3.26, 1.8, 2.3, slat)
			wall.block(name .. "_Lower_Base", s0, s1, 3.2, 5.6, 0.1, 1.5, board)
			for k = 0, 3 do
				local t0 = 3.3 + k * 0.58
				wall.block(name .. "_Lower_Slat_" .. k + 1, s0, s1, t0, t0 + 0.5, 1.5, 1.65, slat)
			end
			for k, band in ipairs({ { 0.3, 0.7 }, { 0.85, 1.25 } }) do
				wall.item(name .. "_Lower_Skirt_" .. k, s0, s1, 5.6, 5.66, band[1], band[2], slat)
			end
			for k, y in ipairs({ 4, 4.8, 5.6 }) do
				wall.item(name .. "_Backrest_" .. k, s0 + 0.35, s1 - 0.35, 0.15, 0.4, y, y + 0.35, slat)
			end
		end
		local upperStrip = wall.item(name .. "_Upper_Light", s0 + 0.85, s1 - 0.85, 3.2, 3.26, 2.7, 2.8, looks.GlowWarm)
		BuildParts.surfaceLight(upperStrip, Enum.NormalId.Bottom, 8, 1, 120, looks.GlowWarm.color)
		local lowerStrip = wall.item(name .. "_Lower_Light", s0 + 0.85, s1 - 0.85, 5.6, 5.66, 1.38, 1.46, looks.GlowWarm)
		BuildParts.surfaceLight(lowerStrip, Enum.NormalId.Bottom, 6, 0.8, 120, looks.GlowWarm.color)
	end
	-- Along the back wall, and (user 2026-10-25: the bigger sauna upstairs) down
	-- both side walls to the back benches, clear of the heater by the front.
	benchTiers(back, "Bench", -hw + 0.15, hw - 0.15)
	local sideStart = 7
	if D - 5.6 - sideStart >= 6 then
		benchTiers(left, "Bench_Left", sideStart, D - 5.6)
		benchTiers(kit.wall("right"), "Bench_Right", sideStart, D - 5.6)
	end
	-- A slatted duckboard on the floor in front of the benches.
	if spa then
		wallProp(kit, spa, back, "Duckboard", "Duckboard", -6, 6, 5.9, 9.1, 0.1, 0.22, { Slats = slat })
	else
		for k = 0, 5 do
			local t0 = 5.9 + k * 0.55
			back.item("Duckboard_" .. k + 1, -6, 6, t0, t0 + 0.45, 0.1, 0.22, slat)
		end
	end

	-- The heater by the front wall: a dark stove with a basket of stones,
	-- glowing underneath, a steel heat shield behind and a wooden guard rail.
	local h0, h1 = 1.2, 3.7 -- along the left wall
	local heater = left.block("Heater", h0, h1, 0.6, 3, 0.1, 2.6, looks.Gadget)
	warmGlow(heater, 14, 1)
	if spa then
		-- The Spa_01 heater (shield to guard: s 0.7..4.2, t 0.15..3.58, up to the shield's top at 6); the old
		-- stove block stays as its hidden solid block with the light.
		hidden(heater)
		wallProp(kit, spa, left, "Heater_Model", "SaunaHeater", h0 - 0.5, h1 + 0.5, 0.15, 3.58, 0.1, 6,
			{ Stones = looks.Stone, Guard = slat })
	else
		left.item("Heater_Shield", h0 - 0.5, h1 + 0.5, 0.15, 0.22, 0.6, 6, looks.Stainless)
		left.item("Heater_Glow", h0 + 0.2, h1 - 0.2, 0.8, 2.8, 2.6, 2.7, looks.GlowWarm)
		left.item("Heater_Rim_1", h0, h0 + 0.1, 0.6, 3, 2.6, 3.3, looks.Stainless)
		left.item("Heater_Rim_2", h1 - 0.1, h1, 0.6, 3, 2.6, 3.3, looks.Stainless)
		for i = 0, 3 do
			for j = 0, 3 do
				local a, d = left.at(h0 + 0.35 + i * 0.6, 0.95 + j * 0.6)
				kit.ball(string.format("Stone_%d_%d", i + 1, j + 1), a, d, 2.95, 0.6, looks.Stone)
			end
		end
		for i = 0, 2 do
			for j = 0, 2 do
				local a, d = left.at(h0 + 0.65 + i * 0.6, 1.25 + j * 0.6)
				kit.ball(string.format("Stone_Top_%d_%d", i + 1, j + 1), a, d, 3.4, 0.55, looks.Stone)
			end
		end
		local g0, g1, gt = h0 - 0.4, h1 + 0.4, 3.5
		for index, s in ipairs({ g0, g1 }) do
			left.item("Guard_Post_" .. index, s - 0.08, s + 0.08, gt - 0.08, gt + 0.08, 0.1, 3.6, slat)
		end
		for index, y in ipairs({ 1.6, 3.4 }) do
			left.item("Guard_Rail_Front_" .. index, g0, g1, gt - 0.05, gt + 0.05, y, y + 0.2, slat)
			left.item("Guard_Rail_Side1_" .. index, g0 - 0.05, g0 + 0.05, 0.15, gt, y, y + 0.2, slat)
			left.item("Guard_Rail_Side2_" .. index, g1 - 0.05, g1 + 0.05, 0.15, gt, y, y + 0.2, slat)
		end
	end

	-- Slatted wooden lamps in both back corners.
	for index, s in ipairs({ hw - 2.3, -hw + 2.3 }) do
		local lamp = "Lamp_" .. index
		if spa then
			local model = wallProp(kit, spa, back, lamp, "SaunaLamp", s - 0.9, s + 0.9, 0.15, 0.75, 6.85, 8.95, { Frame = slat })
			warmGlow(model:FindFirstChild("SaunaLamp_Glow", true) :: BasePart, 16, 0.8)
		else
			local lampGlow = back.item(lamp .. "_Glow", s - 0.7, s + 0.7, 0.15, 0.5, 7.2, 8.6, looks.GlowWarm)
			warmGlow(lampGlow, 16, 0.8)
			back.item(lamp .. "_Top", s - 0.9, s + 0.9, 0.15, 0.75, 8.8, 8.95, slat)
			back.item(lamp .. "_Bottom", s - 0.9, s + 0.9, 0.15, 0.75, 6.85, 7, slat)
			for k = 0, 3 do
				local s0 = s - 0.8 + k * 0.45
				back.item(lamp .. "_Slat_" .. k + 1, s0, s0 + 0.15, 0.6, 0.72, 7, 8.8, slat)
			end
		end
	end

	-- A bucket with a ladle on the lower bench, a thermometer, towels.
	local ba, bd = -4, D - 4.4
	if spa then
		-- The bucket's bounds reach 0.4 further toward +a (the ladle's handle) than its middle.
		paintLooks(propItem(kit, spa, "Bucket", "SaunaBucket", 1, ba + 0.4, bd, 1.65, "-d"), "SaunaBucket", { Wood = slat })
		paintLooks(wallProp(kit, spa, back, "Thermometer", "Thermometer", 3.3, 4.7, 0.15, 0.31, 6.9, 8.3), "Thermometer",
			{ Body = slat })
		for index, s in ipairs({ -6.2, 6.8 }) do
			local a, d = back.at(s, 1.5)
			propItem(kit, spa, "Towel_" .. index, "Towel", 1, a, d, 3.15, "-d")
		end
	else
		kit.cylinder("Bucket", ba, bd, 2.1, 0.9, 1, "up", slat)
		kit.cylinder("Bucket_Band", ba, bd, 1.9, 0.08, 1.04, "up", looks.Stainless)
		kit.cylinder("Ladle_Handle", ba + 0.5, bd, 2.62, 1.6, 0.08, "a", slat)
		kit.ball("Ladle_Cup", ba - 0.2, bd, 2.45, 0.35, slat)
		kit.cylinder("Thermometer", 4, D - 0.2, 7.6, 0.1, 1.4, "d", slat)
		kit.cylinder("Thermometer_Face", 4, D - 0.27, 7.6, 0.04, 1.05, "d", looks.Whiteboard)
		kit.item("Thermometer_Needle", 3.97, 4.03, D - 0.31, D - 0.29, 7.6, 8.05, looks.PlateRed)
		back.item("Towel_1", -7, -5.4, 0.8, 2.2, 3.15, 3.4, looks.ShirtWhite)
		back.item("Towel_2", 6, 7.6, 0.8, 2.2, 3.15, 3.4, looks.ShirtWhite)
	end
end

-- Supplement tubs on a shelf: a dark or white tub with a lid and a stripe, `tall` high.
local function tubs(kit: Kit, wall: Wall, name: string): (level: number, s: number, t: number, y: number) -> ()
	return function(level, s, t, y)
		local dark = (level + math.floor(s)) % 2 == 0
		local tall = if dark then 1.1 else 0.9 -- with the lid, still under the next board
		local a, d = wall.at(s, t)
		local id = string.format("%s_Tub_%d_%.0f", name, level, s * 10)
		kit.cylinder(id, a, d, y + tall / 2, tall, 1, "up", if dark then looks.Gadget else looks.ShirtWhite)
		kit.cylinder(id .. "_Lid", a, d, y + tall + 0.08, 0.16, 1.04, "up", if dark then looks.PlateRed else looks.Gadget)
		kit.cylinder(id .. "_Stripe", a, d, y + tall * 0.45, 0.2, 1.02, "up", if dark then looks.PlateRed else looks.Gadget)
	end
end

--[[
	The supplement bar (user, 2026-10-25: in the ground-floor room the sauna
	left when it moved upstairs; remade the same day with real CC0 textures:
	dark wood floor, cream tile feature wall, black marble, dark planks). A
	tiled back wall with a red neon "SUPPLEMENT BAR" sign, two menu screens,
	floating shelves and a planked back bar with blenders and a drinks fridge;
	a slatted serving counter with a black marble top, a red glow underneath, a
	foot rail and stools; pendant lamps over it; charcoal side walls with
	planked tub shelves; two high tables. Cosmetic only (GAME_DESIGN §27).
]]
FURNISH.SupplementBar = function(kit)
	local hw, D, H = kit.W / 2, kit.D, kit.H
	local back = kit.wall("back")
	-- the 3D props, or nil: simple part-built ones
	local props = propsFor({ "SBarWhey", "SBarIsolate", "SBarGainer", "SBarPreWorkout", "SBarCreatine", "SBarBCAA",
		"SBarShaker", "SBarStool", "SBarPlant" })

	-- The room's surfaces.
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.SBarFloor)
	back.item("Wall_Tiles", -hw, hw, 0, 0.08, 0.06, H, looks.SBarTiles)
	for _, which in ipairs({ "left", "right" }) do
		kit.wall(which).item("Wall_" .. which, 0, D, 0, 0.08, 0.06, H, looks.SBarWall)
	end

	-- The back bar: planked cabinets under a black marble top, blenders on it.
	-- The counters, shelves, blenders and till are CafeShop_01 models (in the room's planks and marble) on hidden
	-- solid blocks; blocks if they did not load.
	local furniture = propsFor({ "CounterUnit", "WallShelf", "Till", "Blender", "SBarCounter" })
	if furniture then
		wallProp(kit, furniture, back, "BackBar", "CounterUnit", -hw + 1, 6, 0.08, 2.15, 0.06, 3.6,
			{ Body = looks.SBarPlanks, Top = looks.SBarMarble })
		hidden(back.block("BackBar_Solid", -hw + 1, 6, 0.08, 2.15, 0.06, 3.6, looks.Glass))
	else
		back.block("BackBar", -hw + 1, 6, 0.08, 2, 0.06, 3.4, looks.SBarPlanks)
		back.block("BackBar_Top", -hw + 1, 6, 0.08, 2.15, 3.4, 3.6, looks.SBarMarble)
	end
	for index, s in ipairs({ -9, -5.5, -2 }) do
		local blender = "Blender_" .. index
		local a, d = back.at(s, 1)
		if furniture then
			propItem(kit, furniture, blender, "Blender", 1, a, d, 3.6, "-d")
		else
			back.item(blender .. "_Base", s - 0.6, s + 0.6, 0.4, 1.6, 3.6, 4.2, looks.Gadget)
			kit.cylinder(blender .. "_Jug", a, d, 4.95, 1.5, 0.8, "up", looks.Glass)
			kit.cylinder(blender .. "_Lid", a, d, 5.77, 0.14, 0.86, "up", looks.Gadget)
		end
	end
	-- Two floating shelves of products, each lit from underneath: small jars
	-- and bottles below, whey and isolate tubs above.
	-- `count` of one product side by side, in shelf order.
	local function run(list: { ProductRow }, item: string, colourway: number, count: number): { ProductRow }
		for _ = 1, count do
			table.insert(list, { item = item, colourway = colourway, perSlot = 1 })
		end
		return list
	end
	local shelfRows = {
		run(run(run({}, "SBarBCAA", 1, 4), "SBarCreatine", 1, 4), "SBarPreWorkout", 2, 4),
		run(run(run({}, "SBarWhey", 1, 3), "SBarWhey", 2, 3), "SBarIsolate", 1, 3),
	}
	for level, y in ipairs({ 5, 6.7 }) do
		local shelf = "Shelf_" .. level
		if furniture then
			wallProp(kit, furniture, back, shelf, "WallShelf", -12, -3, 0.08, 1, y - 0.5, y + 0.15, { Board = looks.SBarPlanks })
		else
			back.item(shelf, -12, -3, 0.08, 1, y, y + 0.15, looks.SBarPlanks)
		end
		local strip = back.item(shelf .. "_Light", -11.8, -3.2, 0.7, 0.8, y - 0.05, y, looks.GlowWarm)
		BuildParts.surfaceLight(strip, Enum.NormalId.Bottom, 4, 0.6, 120, looks.GlowWarm.color)
		if props then
			local row = shelfRows[level]
			local step = 8.6 / #row
			for k, entry in ipairs(row) do
				local a, d = back.at(-11.8 + (k - 0.5) * step, 0.55)
				propItem(kit, props, string.format("%s_Item_%d", shelf, k), entry.item, entry.colourway, a, d, y + 0.15, "-d")
			end
		else
			for k = 0, 7 do
				local a, d = back.at(-11.4 + k * 1.1, 0.55)
				local tub = string.format("%s_Tub_%d", shelf, k + 1)
				local tall = if k % 2 == 0 then 0.75 else 0.6
				kit.cylinder(tub, a, d, y + 0.15 + tall / 2, tall, 0.6, "up", if k % 3 == 0 then looks.ShirtWhite else looks.Gadget)
				kit.cylinder(tub .. "_Lid", a, d, y + 0.15 + tall + 0.05, 0.1, 0.62, "up", looks.PlateRed)
			end
		end
	end
	-- Two menu screens.
	for index, menu in ipairs({
		{ s0 = -2, s1 = 1.8, title = "SHAKES", lines = { "Whey vanilla ...... 5", "Whey chocolate ...... 5", "Mass gainer ...... 6" } },
		{ s0 = 2.2, s1 = 6, title = "PRE & POST", lines = { "Pre-workout ...... 4", "Creatine ...... 2", "Electrolytes ...... 2" } },
	}) do
		local screen = back.item("Screen_" .. index, menu.s0, menu.s1, 0.08, 0.2, 5, 7.4, looks.Gadget)
		writing(screen, back.out, menu.title, menu.lines, looks.Gadget.color, WHITE)
	end
	-- The red neon sign.
	neonSign(back, "NeonSign", "SUPPLEMENT BAR", -11, 5, 8.6, 10.8, Color3.fromRGB(255, 70, 70), Color3.fromRGB(140, 0, 0),
		looks.GlowRed)
	drinksFridge(kit, back, "Fridge", 8, hw - 0.6)

	-- The serving counter: dark plank slats, a black marble top, a red glow
	-- under the front lip, a steel foot rail, shakers and a till; staff behind.
	if furniture then
		-- One model (s -10.3..8.3, t 5.3..7.83 with the foot rail), on hidden solid blocks like the old body and top.
		wallProp(kit, furniture, back, "Counter", "SBarCounter", -10.3, 8.3, 5.3, 7.83, 0.06, 3.85,
			{ Body = looks.SBarPlanks, Top = looks.SBarMarble })
		hidden(back.block("Counter_Solid", -10, 8, 5.5, 6.95, 0.06, 3.6, looks.Glass))
		hidden(back.block("Counter_TopSolid", -10.3, 8.3, 5.3, 7.45, 3.6, 3.85, looks.Glass))
	else
		back.block("Counter_Plinth", -9.8, 7.8, 5.6, 6.7, 0.06, 0.4, looks.Gadget)
		back.block("Counter", -10, 8, 5.5, 6.95, 0.4, 3.6, looks.SBarPlanks)
		back.block("Counter_Top", -10.3, 8.3, 5.3, 7.45, 3.6, 3.85, looks.SBarMarble)
		local slat = 0
		local s = -9.85
		while s + 0.3 <= 7.9 do
			slat += 1
			back.item("Counter_Slat_" .. slat, s, s + 0.3, 6.95, 7.07, 0.45, 3.55, looks.SBarPlanks)
			s += 0.45
		end
		local railA, railD = back.at(-1, 7.75)
		kit.cylinder("FootRail", railA, railD, 0.9, 17.6, 0.16, "a", looks.Stainless)
		for index, rs in ipairs({ -9, -1, 7 }) do
			back.item("FootRail_Bracket_" .. index, rs - 0.06, rs + 0.06, 7.07, 7.75, 0.84, 0.96, looks.Stainless)
		end
	end
	local glow = back.item("Counter_Glow", -9.8, 7.8, 6.8, 6.95, 0.33, 0.4, looks.GlowRed)
	BuildParts.surfaceLight(glow, Enum.NormalId.Bottom, 3, 1, 120, looks.GlowRed.color)
	for index = 0, 5 do
		local a, d = back.at(-8.5 + index * 2.6, 6.4)
		if props then
			propItem(kit, props, "Shaker_" .. index + 1, "SBarShaker", index + 1, a, d, 3.85, "-d")
		else
			kit.cylinder("Shaker_" .. index + 1, a, d, 4.3, 0.9, 0.5, "up", if index % 2 == 0 then looks.PlateRed else looks.Gadget)
		end
	end
	if furniture then
		local tillA, tillD = back.at(6.9, 5.9)
		propItem(kit, furniture, "Till", "Till", 1, tillA, tillD, 3.85, "-d")
	else
		back.item("Till", 6.4, 7.4, 5.6, 6.2, 3.85, 3.95, looks.Gadget)
		back.item("Till_Screen", 6.6, 7.2, 5.7, 5.8, 3.95, 4.8, looks.Gadget)
	end
	for index, ss in ipairs({ -8, -5, -2, 1, 4 }) do
		local a, d = back.at(ss, 8.6)
		if props then
			propItem(kit, props, "BarStool_" .. index, "SBarStool", 1, a, d, 0.06, "-d")
		else
			stool(kit, "BarStool_" .. index, a, d)
		end
	end
	-- Three pendant lamps over the counter, hung low enough that the neon sign
	-- shows above them from the customers' side.
	-- The 3D pendant lamp (as in the Cafe), or blocks if it did not load.
	local lampProps = propsFor({ "PendantLamp" })
	for index, ps in ipairs({ -7, -1, 5 }) do
		local a, d = back.at(ps, 6.2)
		local lamp = "Pendant_" .. index
		if lampProps then
			pendant(kit, lampProps, lamp, index, a, d, 6.6)
		else
			kit.cylinder(lamp .. "_Cable", a, d, (H + 7.55) / 2, H - 7.55, 0.06, "up", looks.Gadget)
			kit.cylinder(lamp .. "_Shade", a, d, 7.2, 0.7, 1.3, "up", looks.Gadget)
			warmGlow(kit.ball(lamp .. "_Bulb", a, d, 6.75, 0.45, looks.GlowWarm), 14, 1.1)
		end
	end

	-- Planked shelves of products on both side walls (one product line per
	-- shelf: tall gainer jugs at the bottom, the low isolate tubs on top; small
	-- jars two to a slot); two high tables; plants by the door.
	local wallRows: { [string]: { ProductRow } } = {
		left = {
			{ item = "SBarGainer", colourway = 1, perSlot = 1 },
			{ item = "SBarWhey", colourway = 1, perSlot = 1 },
			{ item = "SBarWhey", colourway = 2, perSlot = 1 },
			{ item = "SBarIsolate", colourway = 1, perSlot = 1 },
		},
		right = {
			{ item = "SBarCreatine", colourway = 1, perSlot = 2 },
			{ item = "SBarPreWorkout", colourway = 1, perSlot = 2 },
			{ item = "SBarPreWorkout", colourway = 2, perSlot = 2 },
			{ item = "SBarBCAA", colourway = 1, perSlot = 2 },
		},
	}
	for _, which in ipairs({ "left", "right" }) do
		local wall = kit.wall(which)
		local name = "TubShelf_" .. which
		local fill = if props
			then productRows(kit, props, wall, name, if which == "left" then "+a" else "-a", wallRows[which])
			else tubs(kit, wall, name)
		shelving(kit, wall, name, 8, 18, 1.4, 7, 4, looks.SBarPlanks, fill)
	end
	for index, a in ipairs({ -6.5, 6.5 }) do
		cafeTable(kit, "Table_" .. index, a, 10, looks.SBarMarble, props ~= nil)
		if props then
			for side, sa in ipairs({ a - 2.3, a + 2.3 }) do
				propItem(kit, props, string.format("Table_%d_Stool_%d", index, side), "SBarStool", 1, sa, 10, 0.06,
					if sa < a then "+a" else "-a")
			end
		end
	end
	if props then
		propItem(kit, props, "Plant_1", "SBarPlant", 1, -hw + 1.8, 1.7, 0.06, "+d")
		propItem(kit, props, "Plant_2", "SBarPlant", 1, hw - 1.8, 1.7, 0.06, "+d")
	else
		plant(kit, "Plant_1", -hw + 1.5, 1.5)
		plant(kit, "Plant_2", hw - 1.5, 1.5)
	end
end

FURNISH.Coach = function(kit)
	local hw, D = kit.W / 2, kit.D
	local back = kit.wall("back")
	-- The whiteboard's frame and tray and the laptop are BackRooms_01 models, or blocks.
	local coachProps = propsFor({ "WhiteboardFrame", "Laptop" })
	if coachProps then
		wallProp(kit, coachProps, back, "Whiteboard_Frame", "WhiteboardFrame", -7.15, 7.15, 0, 0.5, 3.3, 8.65)
	else
		back.item("Whiteboard_Frame", -7.15, 7.15, 0, 0.12, 3.35, 8.65, looks.Stainless)
		back.item("Whiteboard_Tray", -4, 4, 0.15, 0.5, 3.3, 3.45, looks.Stainless)
	end
	local board = back.item("Whiteboard", -7, 7, 0, 0.15, 3.5, 8.5, looks.Whiteboard)
	writing(board, back.out, "TRAINING PLAN", { "Mon   Squat 5x5 @ 75%", "Wed   Bench 5x5 @ 75%",
		"Fri   Deadlift 3x5 @ 80%", "Next meet: 6 weeks" }, WHITE, INK)
	for index, a in ipairs({ -6, -2, 2, 6 }) do
		chair(kit, "Chair_" .. index, a, D - 9, "+d")
	end
	desk(kit, "Desk", hw - 3.5, hw - 0.5, 10, 16)
	if coachProps then
		-- Facing the desk chair; its bounds reach 0.14 further toward the screen (+a) than the base's middle.
		propItem(kit, coachProps, "Laptop", "Laptop", 1, hw - 2.1 + 0.14, 13, 3, "-a")
	else
		kit.item("Laptop", hw - 2.8, hw - 1.4, 12, 14, 3, 3.08, looks.Gadget)
		kit.item("Laptop_Screen", hw - 1.4, hw - 1.3, 12, 14, 3.08, 4.3, looks.Gadget)
	end
	chair(kit, "DeskChair", hw - 5, 13, "+a")
	plant(kit, "Plant_1", -hw + 1.5, D - 1.5)
	plant(kit, "Plant_2", -hw + 1.5, 1.5)
end

--[[
	The Mock Meet Room (user 2026-10-27): the gym's check-in for a mock meet. A
	red runway leads from the door to the check-in desk at the back; the desk's
	tagged point gets MockMeetService's "Start Mock Meet" prompt, which moves the
	player into their own private meet room. Waiting chairs line the side walls.
]]
FURNISH.MockMeet = function(kit)
	local hw, D = kit.W / 2, kit.D
	local back = kit.wall("back")
	kit.item("Floor", -hw, hw, 0, D, 0, 0.06, looks.GymFloor)
	for _, which in ipairs({ "back", "front", "left", "right" }) do
		clad(kit, which, "Wall_" .. which, looks.MaxBlack)
	end
	-- The competition stripes of the room's front, round the three walls without the door.
	back.item("Stripe_back", -hw, hw, 0.08, 0.12, 2.9, 3.5, looks.PlateRed)
	for _, which in ipairs({ "left", "right" }) do
		kit.wall(which).item("Stripe_" .. which, 0, D, 0.08, 0.12, 2.9, 3.5, looks.PlateRed)
	end
	kit.item("Runway", -2, 2, 0, D - 6, 0.06, 0.1, looks.PlateRed)

	-- The check-in desk, facing the door: the Blender model (MockMeet_01's MeetDesk, CHECK-IN on its
	-- front) with a hidden solid block, and its monitor's screen facing the clerk. Blocks if it fails to load.
	local deskProps = propsFor({ "MeetDesk" })
	if deskProps then
		local desk = propItem(kit, deskProps, "CheckInDesk", "MeetDesk", 1, 0, D - 4.1, 0.06, "-d")
		hidden(kit.block("CheckInDesk_Solid", -5.25, 5.25, D - 5.25, D - 2.95, 0.06, 3.3, looks.Glass))
		local monitor = desk:FindFirstChild("MeetDesk_MonitorScreen", true) :: BasePart?
		if monitor then
			StyledScreen.build(monitor, StyledScreen.faceToward(monitor, kit.toward("+d")), "CHECK-IN",
				{ "Mock Meet desk", "Next lifter: you" }, "bar", 120)
		end
	else
		kit.block("CheckInDesk_Body", -5, 5, D - 5, D - 3.2, 0.06, 3.1, looks.FrontCharcoal)
		kit.block("CheckInDesk_Top", -5.2, 5.2, D - 5.2, D - 3, 3.1, 3.3, looks.Wood)
		kit.item("CheckInDesk_Stripe", -5, 5, D - 5.08, D - 5, 0.9, 1.3, looks.PlateRed)
		local sign = kit.item("CheckInDesk_Sign", -2.5, 2.5, D - 5.12, D - 5.04, 1.6, 2.8, looks.SignPanel)
		plaque(sign, kit.toward("-d"), "CHECK-IN", Color3.fromRGB(16, 16, 18), WHITE)
		kit.item("CheckInDesk_Screen", -3.6, -1.4, D - 3.9, D - 3.8, 3.3, 4.8, looks.Gadget)
	end
	chair(kit, "DeskChair", 0, D - 2, "-d")
	local board = back.item("Board", -9, 9, 0.08, 0.3, 5, 10.4, looks.Gadget)
	StyledScreen.build(board, faceToward(back.out), "MOCK MEET", { "Your own private meet room",
		"Squat, bench, deadlift: 3 attempts each", "Check in at the desk to start" }, "star")

	-- Where the prompt sits: in front of the desk, on the player's side.
	local point = kit.item("CheckInPoint", -1, 1, D - 8, D - 6, 0.1, 4, looks.Glass)
	point.Transparency = 1
	point:AddTag(MockMeetConfig.CheckInTag)

	-- Waiting chairs along both side walls, facing across the room.
	for index, d in ipairs({ 8, 11, 14, 17, 20 }) do
		chair(kit, "WaitChair_L" .. index, -hw + 1.5, d, "+a", 2)
		chair(kit, "WaitChair_R" .. index, hw - 1.5, d, "-a", 2)
	end
	plant(kit, "Plant_1", -7.5, D - 1.5)
	plant(kit, "Plant_2", 7.5, D - 1.5)
	-- Black walls swallow light: ceiling panels over the waiting chairs and the desk.
	for _, a in ipairs({ -hw + 4, hw - 4 }) do
		for _, d in ipairs({ 9, 19 }) do
			local panel = kit.item(string.format("CeilingLight_%d_%d", a, d), a - 2.5, a + 2.5, d - 2.5, d + 2.5, kit.H - 0.2,
				kit.H, looks.GlowWhite)
			BuildParts.surfaceLight(panel, Enum.NormalId.Bottom, 20, 1.6, 110)
		end
	end
	local deskLight = kit.item("CeilingLight_Desk", -6, 6, D - 7, D - 4, kit.H - 0.2, kit.H, looks.GlowWhite)
	BuildParts.surfaceLight(deskLight, Enum.NormalId.Bottom, 20, 1.8, 110)
end

-- The user's SBD Central logo (StarterGymConfig.ShopLogoPieces) as large as
-- fits on the face of `part` that looks toward `toward`.
local function shopLogo(part: BasePart, toward: Vector3)
	local cfg = StarterGymConfig
	if not BuildParts.piecesReady(cfg.ShopLogoPieces) then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Logo"
	gui.Face = faceToward(toward)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.3
	gui.Parent = part
	local width = if math.abs(toward.X) > 0.5 then part.Size.Z else part.Size.X
	local height = part.Size.Y
	local pixels = 0
	for _, piece in ipairs(cfg.ShopLogoPieces) do
		pixels += piece.widthPixels
	end
	local aspect = pixels / cfg.ShopLogoHeightPixels
	local logoWidth = math.min(width * 0.94, height * 0.9 * aspect)
	local frame = Instance.new("Frame")
	frame.Name = "Picture"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(logoWidth / width, logoWidth / aspect / height)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	BuildParts.addImagePieces(frame, cfg.ShopLogoPieces)
end

-- The Shop's gear models (art/roblox/ShopGear_01.rbxmx, Rojo-mapped), or nil.
local function shopGear(): Instance?
	local templates = ServerStorage:FindFirstChild("PropTemplates")
	return templates and templates:FindFirstChild(StarterGymConfig.ShopGearTemplate)
end

--[[
	The shop (user, 2026-10-23: like the SBD gear stand and shop photos): red
	carpet, black walls, the user's SBD Central logo lit between red neon lines
	on the back wall; singlet and tee mannequins on a black podium under
	spotlights; a slatwall with hanging wrist wraps, knee sleeves in pairs and
	rolled wraps; a black shelf of lever belts; a black counter with the logo
	and a till; a table of folded tees. The gear is the Blender models (every
	badge says CENTRAL); without them the room is built bare, with a warning.
]]
FURNISH.Shop = function(kit)
	local hw, D = kit.W / 2, kit.D
	local back, left, right = kit.wall("back"), kit.wall("left"), kit.wall("right")
	local dark = looks.SignPanel
	local gear = shopGear()
	if gear == nil then
		warn("[RoomProps] Shop: no gear models (ServerStorage.PropTemplates." .. StarterGymConfig.ShopGearTemplate
			.. " is missing); the shop is built without its gear")
	end
	local placed = 0
	local function showGear(item: string, name: string, a: number, d: number, y: number, facing: string)
		local template = gear and gear:FindFirstChild(item)
		if template and template:IsA("Model") then
			kit.place(name, template, a, d, y, facing)
			placed += 1
		end
	end

	-- The store: red carpet, black walls, the logo on the back wall.
	kit.item("Carpet", -hw, hw, 0, D, 0, 0.06, looks.Carpet)
	back.item("Wall_Back", -hw, hw, 0, 0.15, 0, 11.2, dark)
	left.item("Wall_Left", 0, D - 0.15, 0, 0.15, 0, 11.2, dark)
	right.item("Wall_Right", 0, D - 0.15, 0, 0.15, 0, 11.2, dark)
	local logoPanel = back.item("LogoPanel", -6.6, 6.6, 0.15, 0.25, 6.9, 10.55, dark)
	shopLogo(logoPanel, back.out)
	back.item("LogoLine_Top", -6.6, 6.6, 0.15, 0.22, 10.65, 10.75, looks.GlowRed)
	back.item("LogoLine_Bottom", -6.6, 6.6, 0.15, 0.22, 6.7, 6.8, looks.GlowRed)

	-- Mannequins on a black podium, each under a spotlight, with an invisible
	-- solid column so nobody walks through them.
	-- The podium, slatwall, ledges, tees, table, counter top and till are CafeShop_01 models on hidden solid
	-- blocks where the old blocks were solid; blocks if they did not load.
	local furniture = propsFor({ "Podium", "Slatwall", "WallShelf", "TeeStack", "DisplayTable", "ShopCounterTop", "Till",
		"CardReader" })
	if furniture then
		wallProp(kit, furniture, back, "Podium", "Podium", -7.5, 7.5, 1.5, 6.06, 0, 0.3)
		hidden(back.block("Podium_Solid", -7.5, 7.5, 1.5, 6, 0, 0.3, looks.Glass))
	else
		back.block("Podium", -7.5, 7.5, 1.5, 6, 0, 0.3, looks.Gadget)
		back.item("Podium_Glow", -7.5, 7.5, 6, 6.06, 0.08, 0.2, looks.GlowRed)
	end
	local mannequins = {
		{ s = -4.6, item = "MannequinSinglet" },
		{ s = 0, item = "MannequinTee" },
		{ s = 4.6, item = "MannequinSinglet" },
	}
	for index, spec in ipairs(mannequins) do
		local a, d = back.at(spec.s, 3.75)
		showGear(spec.item, string.format("%s_%d", spec.item, index), a, d, 0.3, "-d")
		local column = kit.block("Mannequin_Collision_" .. index, a - 0.8, a + 0.8, d - 0.6, d + 0.6, 0.3, 6, looks.Glass)
		column.Transparency = 1
		-- The 3D track spotlight (Lights_01) under the track, or a block if it did not load.
		local spotProps = propsFor({ "TrackSpot" })
		local spot: BasePart
		if spotProps then
			local head = propItem(kit, spotProps, "Spotlight_" .. index, "TrackSpot", 1, a, d - 1.3, 11.9, "-d")
			spot = head:FindFirstChild("TrackSpot_Lens", true) :: BasePart
		else
			spot = kit.item("Spotlight_" .. index, a - 0.3, a + 0.3, d - 1.6, d - 1, 11.9, 12.4, looks.Gadget)
		end
		local light = Instance.new("SpotLight")
		light.Face = StyledScreen.faceToward(spot, -Vector3.yAxis)
		light.Range = 14
		light.Brightness = 2
		light.Angle = 60
		light.Color = StarterGymConfig.LightColor
		light.Shadows = false
		light.Parent = spot
	end
	local _, spotD = back.at(0, 3.75 + 1.3)
	local railProps = propsFor({ "TrackRail" })
	if railProps then
		propItem(kit, railProps, "Spotlight_Track", "TrackRail", 1, 0, spotD, 12.4, "-d")
	else
		kit.item("Spotlight_Track", -6, 6, spotD - 0.1, spotD + 0.1, 12.4, 12.55, looks.Gadget)
	end

	-- The slatwall on the left: hanging wraps on hooks, knee sleeves in pairs
	-- on a ledge, rolled wraps on a lower ledge.
	if furniture then
		-- The panel with its grooves and six hooks (to 0.97 out).
		wallProp(kit, furniture, left, "Slatwall", "Slatwall", 6, 24, 0.15, 0.97, 0.5, 9.5, { Panel = dark })
	else
		left.item("Slatwall", 6, 24, 0.15, 0.35, 0.5, 9.5, dark)
		for k = 0, 14 do
			local y = 0.8 + k * 0.6
			left.item("Slatwall_Groove_" .. k + 1, 6, 24, 0.35, 0.37, y, y + 0.06, looks.Stainless)
		end
	end
	for index = 0, 5 do
		local s = 8 + index * 2.8
		if not furniture then
			left.item("Hook_" .. index + 1, s - 0.05, s + 0.05, 0.37, 0.95, 8.4, 8.5, looks.Stainless)
		end
		local a, d = left.at(s, 0.6)
		showGear("WristWrapHanging", "WristWrapHanging_" .. index + 1, a, d, 8.45, "+a")
	end
	-- The two ledges: boards on brackets reaching 0.5 under them, on hidden solid blocks.
	local function ledge(name: string, y: number)
		if furniture then
			wallProp(kit, furniture, left, name, "WallShelf", 7, 23, 0.37, 1.3, y - 0.5, y + 0.15, { Board = dark })
			hidden(left.block(name .. "_Solid", 7, 23, 0.37, 1.3, y, y + 0.15, looks.Glass))
		else
			left.block(name, 7, 23, 0.37, 1.3, y, y + 0.15, dark)
		end
	end
	ledge("Ledge_Sleeves", 4)
	for pair, s in ipairs({ 9, 13, 17, 21 }) do
		for side, offset in ipairs({ -0.4, 0.4 }) do
			local a, d = left.at(s + offset, 0.85)
			showGear("KneeSleeve", string.format("KneeSleeve_%d_%d", pair, side), a, d, 4.15, "+a")
		end
	end
	ledge("Ledge_Wraps", 2)
	for index = 0, 5 do
		local a, d = left.at(8.5 + index * 2.8, 0.85)
		showGear("WristWrap", "WristWrap_" .. index + 1, a, d, 2.15, "+a")
	end

	-- The belt shelf on the right: lever belts on the upper boards, folded tees below.
	shelving(kit, right, "BeltShelf", 8, 20, 1.5, 6.5, 3, dark)
	for level, y in ipairs({ 0.15 + 6.5 / 3 + 0.15, 0.15 + 2 * 6.5 / 3 + 0.15 }) do
		for index, s in ipairs({ 10, 14, 18 }) do
			local a, d = right.at(s, 0.8)
			showGear("LeverBelt", string.format("LeverBelt_%d_%d", level, index), a, d, y, "-a")
		end
	end
	for index, s in ipairs({ 10, 14, 18 }) do
		if furniture then
			local a, d = right.at(s, 0.8)
			propItem(kit, furniture, "Tee_Stack_" .. index, "TeeStack", index, a, d, 0.3, facingOut(kit, right))
		else
			for fold = 0, 3 do
				right.item(string.format("Tee_Stack_%d_%d", index, fold + 1), s - 0.7, s + 0.7, 0.3, 1.3, 0.3 + fold * 0.25,
					0.53 + fold * 0.25, if fold % 2 == 0 then looks.ShirtBlack else looks.ShirtRed)
			end
		end
	end

	-- The counter by the door: black with the logo on its front (a block: the logo is drawn on it), a till on top.
	local counter = kit.block("Counter", 5, 11.5, 8, 10, 0, 3.6, dark)
	shopLogo(counter, kit.toward("-d"))
	if furniture then
		-- The top with its red edge on the customers' side (-d), the till's screen toward the customers like the
		-- old block screen, the Reception_01 card reader.
		propItem(kit, furniture, "Counter_Top", "ShopCounterTop", 1, 8.25, 8.97, 3.6, "-d")
		hidden(kit.block("Counter_TopSolid", 4.9, 11.6, 7.9, 10.1, 3.6, 3.8, looks.Glass))
		propItem(kit, furniture, "Till", "Till", 1, 10.25, 9.1, 3.8, "+d")
		propItem(kit, furniture, "CardReader", "CardReader", 1, 6.3, 8.5, 3.8, "-d")
	else
		kit.block("Counter_Top", 4.9, 11.6, 7.9, 10.1, 3.6, 3.8, looks.Gadget)
		kit.item("Counter_Edge", 4.9, 11.6, 7.84, 7.9, 3.6, 3.8, looks.GlowRed)
		kit.item("Till", 9.5, 11, 8.6, 9.6, 3.8, 4.4, looks.Gadget)
		kit.item("Till_Screen", 9.6, 10.9, 8.55, 8.6, 4.4, 5.2, looks.Gadget)
		kit.item("CardReader", 6, 6.6, 8.2, 8.8, 3.8, 3.95, looks.Gadget)
	end

	-- A table of folded tees.
	if furniture then
		propItem(kit, furniture, "Table", "DisplayTable", 1, -5.25, 12.5, 0, "-d")
		hidden(kit.block("Table_Solid", -8, -2.5, 11, 14, 0, 2.6, looks.Glass))
	else
		kit.block("Table", -8, -2.5, 11, 14, 0, 2.6, dark)
	end
	for i = 0, 2 do
		for j = 0, 1 do
			local a0, d0 = -7.6 + i * 1.8, 11.3 + j * 1.4
			if furniture then
				propItem(kit, furniture, string.format("Table_Tee_%d_%d", i + 1, j + 1), "TeeStack", (i + j) % 3 + 1, a0 + 0.7,
					d0 + 0.6, 2.6, "-d")
			else
				for fold = 0, 2 do
					kit.item(string.format("Table_Tee_%d_%d_%d", i + 1, j + 1, fold + 1), a0, a0 + 1.4, d0, d0 + 1.2,
						2.6 + fold * 0.25, 2.83 + fold * 0.25, if (i + j + fold) % 3 == 0 then looks.ShirtRed else looks.ShirtBlack)
				end
			end
		end
	end
	if gear then
		print(string.format("[RoomProps] Shop: %d gear models placed", placed))
	end
end

--[[
	Furnishes every room that has a plan above, into Workspace.StarterGym.Props
	(one folder per room). Returns how many rooms were furnished; a room whose
	plan does not fit is left empty with a warning.
]]
function RoomProps.build(model: Model): number
	local rooms = model:FindFirstChild("Rooms")
	if rooms == nil then
		return 0
	end
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = model

	-- The rooms, and the Strongman Shed's region (furnished the same way).
	local regions = rooms:GetChildren()
	local shed = model:FindFirstChild("Shed")
	if shed then
		for _, region in ipairs(shed:GetChildren()) do
			if string.sub(region.Name, 1, 5) == "Shed_" then
				table.insert(regions, region)
			end
		end
	end
	local doorSpots: { Vector3 } = {}
	for _, room in ipairs(regions) do
		local spot = room:GetAttribute("DoorCentre")
		if typeof(spot) == "Vector3" then
			table.insert(doorSpots, spot)
		end
	end

	local furnished = 0
	for _, room in ipairs(regions) do
		local name = string.sub(room.Name, 6) -- without "Room_" (or "Shed_")
		local furnish = FURNISH[name]
		if room:IsA("BasePart") and furnish then
			local folder = Instance.new("Folder")
			folder.Name = name
			local ok, problem = pcall(function()
				furnish(kitFor(folder, room, doorSpots))
			end)
			if ok then
				folder.Parent = props
				furnished += 1
			else
				folder:Destroy()
				warn(string.format("[RoomProps] %s left empty: %s", name, tostring(problem)))
			end
		end
	end
	return furnished
end

-- ---------------------------------------------------------------- themed room fronts

--[[
	Themed room fronts (GAME_DESIGN §27 "Themed room fronts", user-approved
	2026-10-26): each closed room's wall onto the hall is designed around what
	is inside, so you can tell the room without seeing in. StarterGymBuilder
	clads the wall (its `face` look), trims the doorway and fixes the name plaque; it
	leaves an invisible region "Front_<Room>" in model.Fronts. FRONT[<Room>]
	adds the details in the front's own frame (a FrontKit):
	  a  along the wall: 0 at the door's middle, + to the right as you face it;
	  d  out from the wall's face into the hall, 0 .. D (FrontDepthStuds);
	  y  up from the floor, 0 .. H (the ceiling, soffit or wall top).
	Details are decor; big props get hidden solid blockers, never near the door.
]]
type FrontKit = {
	aMin: number,
	aMax: number,
	D: number,
	H: number,
	doorHalf: number, -- the doorway's half width
	doorTop: number, -- the doorway's height
	block: BoxFn, -- solid
	item: BoxFn, -- decor
	cylinder: (name: string, a: number, d: number, y: number, length: number, diameter: number, axis: string,
		look: Look) -> BasePart,
	-- A strip along the wall from a0 to a1, cut round the doorway (and its trim) where it crosses it.
	band: (name: string, a0: number, a1: number, y0: number, y1: number, d0: number, d1: number, look: Look) -> (),
	toward: (direction: string) -> Vector3,
	place: (name: string, template: Model, a: number, d: number, y: number, facing: string, stretch: Vector3?) -> Model,
}

local FRONT: { [string]: (front: FrontKit) -> () } = {}

local function frontFor(folder: Folder, region: BasePart): FrontKit
	local outward = region:GetAttribute("Outward") :: Vector3
	local door = region:GetAttribute("DoorAt") :: Vector3
	local doorHalf = (region:GetAttribute("DoorWidth") :: number) / 2
	local doorTop = region:GetAttribute("DoorTop") :: number
	local right = (-outward):Cross(Vector3.yAxis)
	local low, high = region.Position - region.Size / 2, region.Position + region.Size / 2
	local aLow, aHigh = (low - door):Dot(right), (high - door):Dot(right)
	local front = {} :: FrontKit
	front.aMin, front.aMax = math.min(aLow, aHigh), math.max(aLow, aHigh)
	front.D, front.H = StarterGymConfig.FrontDepthStuds, high.Y - door.Y
	front.doorHalf, front.doorTop = doorHalf, doorTop
	local function world(a: number, d: number, y: number): Vector3
		return door + right * a + outward * d + Vector3.yAxis * y
	end
	local function inside(name: string, a0: number, a1: number, d1: number, y0: number, y1: number)
		local e = 0.001
		if a0 < front.aMin - e or a1 > front.aMax + e or d1 > front.D + e or y0 < -e or y1 > front.H + e then
			error(string.format("%s does not fit the front (a %.2f..%.2f of %.2f..%.2f, out to %.2f of %.2f, y %.2f..%.2f of %.2f)",
				name, a0, a1, front.aMin, front.aMax, d1, front.D, y0, y1, front.H), 0)
		end
	end
	local function make(name: string, a0: number, a1: number, d0: number, d1: number, y0: number, y1: number, look: Look,
		solid: boolean): BasePart
		inside(name, a0, a1, d1, y0, y1)
		-- Nothing solid in the way of the door: its width and 1.5 more each side, 4 out.
		if solid and a0 < doorHalf + 1.5 and a1 > -doorHalf - 1.5 and d0 < 4 and y0 < doorTop then
			error(string.format("%s stands in front of the door", name), 0)
		end
		local p, q = world(a0, d0, y0), world(a1, d1, y1)
		local part = BuildParts.box(folder, name, p:Min(q), p:Max(q), look)
		if not solid then
			BuildParts.decor(part)
		end
		return part
	end
	front.block = function(name, a0, a1, d0, d1, y0, y1, look)
		return make(name, a0, a1, d0, d1, y0, y1, look, true)
	end
	front.item = function(name, a0, a1, d0, d1, y0, y1, look)
		return make(name, a0, a1, d0, d1, y0, y1, look, false)
	end
	front.band = function(name, a0, a1, y0, y1, d0, d1, look)
		local cut = doorHalf + 0.35 -- the doorway and its trim
		if y0 >= doorTop + 0.35 then
			front.item(name, a0, a1, d0, d1, y0, y1, look)
			return
		end
		if a0 < -cut then
			front.item(name .. "_1", a0, math.min(a1, -cut), d0, d1, y0, y1, look)
		end
		if a1 > cut then
			front.item(name .. "_2", math.max(a0, cut), a1, d0, d1, y0, y1, look)
		end
		if y1 > doorTop + 0.35 and a0 < cut and a1 > -cut then
			front.item(name .. "_OverDoor", math.max(a0, -cut), math.min(a1, cut), d0, d1, doorTop + 0.35, y1, look)
		end
	end
	front.cylinder = function(name, a, d, y, length, diameter, axis, look)
		local half = if axis == "a" then length / 2 else diameter / 2
		inside(name, a - half, a + half, d + (if axis == "d" then length / 2 else diameter / 2), y - diameter / 2,
			y + (if axis == "up" then length / 2 else diameter / 2))
		local along = if axis == "up" then Vector3.yAxis elseif axis == "a" then right else outward
		local up = if axis == "up" then right else Vector3.yAxis
		local part = BuildParts.placed(folder, name, Vector3.new(length, diameter, diameter),
			CFrame.fromMatrix(world(a, d, y), along, up), look);
		(part :: any).Shape = Enum.PartType.Cylinder
		return BuildParts.decor(part)
	end
	front.toward = function(direction)
		if direction == "+d" then
			return outward
		elseif direction == "-d" then
			return -outward
		elseif direction == "+a" then
			return right
		end
		return -right
	end
	-- Like Kit.place; a front's details may touch or sink into the wall, but not stand out too far.
	front.place = function(name, template, a, d, y, facing, stretch)
		local copy = template:Clone()
		copy.Name = name
		if stretch then
			stretchTo(copy, stretch)
		end
		local position = world(a, d, y)
		copy:PivotTo(CFrame.lookAt(position, position + front.toward(facing)))
		local box, size = copy:GetBoundingBox()
		local aMin, aMax, dMax, yMin, yMax = math.huge, -math.huge, -math.huge, math.huge, -math.huge
		local half = size / 2
		for _, x in ipairs({ -1, 1 }) do
			for _, yy in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					local offset = box:PointToWorldSpace(Vector3.new(x * half.X, yy * half.Y, z * half.Z)) - door
					aMin, aMax = math.min(aMin, offset:Dot(right)), math.max(aMax, offset:Dot(right))
					dMax = math.max(dMax, offset:Dot(outward))
					yMin, yMax = math.min(yMin, offset.Y), math.max(yMax, offset.Y)
				end
			end
		end
		local ok, problem = pcall(inside, name, aMin + 0.01, aMax - 0.01, dMax - 0.01, yMin + 0.01, yMax - 0.01)
		if not ok then
			copy:Destroy()
			error(problem, 0)
		end
		for _, part in ipairs(copy:GetDescendants()) do
			if part:IsA("BasePart") then
				BuildParts.decor(part)
			end
		end
		copy.Parent = folder
		return copy
	end
	return front
end

-- A coloured 3D prop on a front (propItem works on a FrontKit too: it only uses `place`), optionally scaled.
local function frontProp(front: FrontKit, templates: { [string]: Model }, name: string, item: string, colourway: number,
	a: number, d: number, y: number, facing: string, scale: number?): Model
	local source = templates
	if scale then
		local big = templates[item]:Clone()
		big:ScaleTo(scale)
		source = { [item] = big }
	end
	local copy = propItem((front :: any) :: Kit, source, name, item, colourway, a, d, y, facing)
	if scale then
		source[item]:Destroy()
	end
	return copy
end

-- A glowing light inside a prop's piece (an uplight's lens, ...).
local function propGlow(model: Model, piece: string, range: number, brightness: number)
	local part = model:FindFirstChild(piece, true)
	if part then
		warmGlow(part :: BasePart, range, brightness)
	end
end

-- A steel (or other) portal round the doorway: two posts and a header, standing out from the wall.
local function portal(front: FrontKit, look: Look, width: number, out: number, above: number)
	local inner, outer = front.doorHalf + 0.35, front.doorHalf + 0.35 + width
	local top = front.doorTop + above
	front.item("Portal_1", -outer, -inner, 0.06, out, 0, top, look)
	front.item("Portal_2", inner, outer, 0.06, out, 0, top, look)
	front.item("Portal_Top", -outer, outer, 0.06, out, front.doorTop + 0.35, top, look)
end

--[[
	Recovery & Spa (the wing's long wall, its door near the front end): stone
	cladding (the builder's face), an oak portal round the door, and along the
	wall bays of oak slat panels and planters full of plants, warm uplights
	washing the stone between them.
]]
FRONT.SpaReception = function(front)
	portal(front, looks.LockersSlats, 1.25, 0.3, 1)
	local props = propsFor({ "Planter", "WallUplight", "SBarPlant" })
	local function planter(name: string, centre: number, colourway: number)
		if props == nil then
			return
		end
		frontProp(front, props, name, "Planter", colourway, centre, 0.72, 0, "+d")
		hidden(front.block(name .. "_Solid", centre - 2.06, centre + 2.06, 0.06, 1.38, 0, 1.3, looks.Glass))
		for index, offset in ipairs({ -0.9, 0.9 }) do
			frontProp(front, props, string.format("%s_Plant_%d", name, index), "SBarPlant", 1, centre + offset, 1.0, 0.25, "+d")
		end
	end
	-- Left of the door: one planter.
	planter("Planter_0", front.aMin + 2.7, 4)
	-- Right of the door: bays of 12 (an oak slat panel, an uplight, a planter).
	local bay, c = 0, front.doorHalf + 4.2 -- past the name plaque right of the door
	while c + 4 <= front.aMax - 0.3 do
		bay += 1
		local id = "Bay_" .. bay
		front.item(id .. "_Slats", c, c + 4, 0.06, 0.12, 0, front.H - 0.3, looks.LockersSlats)
		local x = c + 0.4
		local batten = 0
		while x + 0.15 <= c + 4 do
			batten += 1
			front.item(string.format("%s_Batten_%d", id, batten), x - 0.15, x + 0.15, 0.12, 0.3, 0, front.H - 0.3, looks.LockersSlats)
			x += 0.8
		end
		if props and c + 5.4 <= front.aMax then
			propGlow(frontProp(front, props, id .. "_Uplight", "WallUplight", bay % 3 + 1, c + 5, 0.3, 0.4, "+d"), "WallUplight_Light", 12, 0.9)
		end
		if c + 10.2 <= front.aMax then
			planter(id .. "_Planter", c + 8, bay % 4 + 1)
		end
		c += 12
	end
end

-- A competition barbell (2.2 m: 9.8 studs at 1 stud = 225 mm, like Barbell_01's plates) on a front,
-- centred at (a, d, y), lying along the wall ("a") or standing up ("up"): a shaft in `shaft`'s look,
-- steel collars and sleeves (a rusted bar is rusted all over).
local function barbell(front: FrontKit, name: string, a: number, d: number, y: number, axis: string, shaft: Look)
	local steel = if shaft == looks.RustBar then looks.RustSleeve else looks.Stainless
	-- The Fronts_01 barbell (lying, or standing for axis "up"), its middle at y, or block cylinders.
	local props = propsFor({ "Barbell", "BarbellUpright" })
	if props then
		local item = if axis == "a" then "Barbell" else "BarbellUpright"
		local bottom = if axis == "a" then y - 0.17 else y - 4.9
		paintLooks(frontProp(front, props, name, item, 1, a, d, bottom, "+d"), item, { Shaft = shaft, Steel = steel })
		return
	end
	local function at(offset: number): (number, number)
		if axis == "a" then
			return a + offset, y
		end
		return a, y + offset
	end
	local sa, sy = at(0)
	front.cylinder(name .. "_Shaft", sa, d, sy, 5.8, 0.15, axis, shaft)
	for side, sign in ipairs({ -1, 1 }) do
		local ca, cy = at(sign * 2.975)
		front.cylinder(string.format("%s_Collar_%d", name, side), ca, d, cy, 0.15, 0.34, axis, steel)
		local la, ly = at(sign * 3.975)
		front.cylinder(string.format("%s_Sleeve_%d", name, side), la, d, ly, 1.85, 0.22, axis, steel)
	end
end

--[[
	The Mock Meet Room (the gym's solo meet room; was Max Testing, renamed by the
	user 2026-10-27): black, with red and white competition stripes, barbells on
	wall racks either side of the door, stage lights along the top, an attempt
	board on the right and the three judges' lights on the left.
]]
FRONT.MockMeet = function(front)
	front.band("Stripe_Red", front.aMin, front.aMax, 2.9, 3.5, 0.06, 0.1, looks.PlateRed)
	front.band("Stripe_White", front.aMin, front.aMax, 3.62, 3.72, 0.06, 0.1, looks.LaneWhite)
	front.band("Stripe_Thin", front.aMin, front.aMax, 3.84, 3.96, 0.06, 0.1, looks.PlateRed)
	-- Barbells on the wall (user, 2026-10-26, with photos of wall bar racks): a
	-- horizontal rack left of the door, a vertical "gun rack" right of it.
	local shafts = { looks.Stainless, looks.RustBar, looks.PlateRed, looks.Stainless, looks.PlateBlue, looks.RustBar, looks.PlateRed }
	local left = -(front.doorHalf + 8)
	-- The racks and the judges' lights are Fronts_01 models (their bounds' middles out from the wall), or blocks.
	local rackProps = propsFor({ "WallBarRack", "GunRack", "JudgesLights" })
	if rackProps then
		frontProp(front, rackProps, "BarRack", "WallBarRack", 1, left, 0.34, 4.2, "+d")
	else
		for _, offset in ipairs({ -2.6, 2.6 }) do
			front.item("BarRack_Upright_" .. (if offset < 0 then 1 else 2), left + offset - 0.2, left + offset + 0.2, 0.06, 0.25, 4.2,
				9.6, looks.Gadget)
		end
	end
	for k, shaft in ipairs(shafts) do
		local y = 4.6 + (k - 1) * 0.72
		if not rackProps then
			for side, offset in ipairs({ -2.6, 2.6 }) do
				local id = string.format("BarRack_Hook_%d_%d", k, side)
				front.item(id, left + offset - 0.15, left + offset + 0.15, 0.25, 0.62, y - 0.2, y - 0.12, looks.Gadget)
				front.item(id .. "_Lip", left + offset - 0.15, left + offset + 0.15, 0.56, 0.62, y - 0.12, y + 0.06, looks.Gadget)
			end
		end
		barbell(front, "Bar_H_" .. k, left, 0.42, y, "a", shaft)
	end
	local right = front.doorHalf + 9 -- clear of the name plaque right of the door
	local bars = 11
	if rackProps then
		frontProp(front, rackProps, "GunRack", "GunRack", 1, right, 0.33, 1.0, "+d")
	else
		front.item("GunRack_Top", right - 5.2, right + 5.2, 0.06, 0.6, 7.7, 8.0, looks.Gadget)
		front.item("GunRack_Bottom", right - 5.2, right + 5.2, 0.06, 0.6, 1.0, 1.2, looks.Gadget)
	end
	for k = 1, bars do
		local a = right + (k - (bars + 1) / 2) * 0.9
		local shaft = if k == 4 then looks.PlateRed elseif k == 8 then looks.PlateBlue elseif k % 2 == 0 then looks.RustBar else looks.Stainless
		barbell(front, "Bar_V_" .. k, a, 0.38, 5.15, "up", shaft)
	end
	-- The attempt board (right) and the judges' lights (left), at eye height.
	local board = front.item("AttemptBoard", 19, 27, 0.06, 0.4, 4, 9, looks.Gadget)
	writing(board, front.toward("+d"), "ATTEMPT BOARD", { "LIFTER    —", "LIFT    —", "ATTEMPT    1   2   3", "WEIGHT    —  KG" },
		Color3.fromRGB(12, 12, 14), Color3.fromRGB(255, 255, 255))
	front.item("AttemptBoard_Glow", 19.4, 26.6, 0.4, 0.45, 3.85, 3.95, looks.PlateRed)
	-- Stage lights all along the top, like over a competition platform.
	local lightY = front.H - 1.6
	local at = front.aMin + 2
	local count = 0
	-- The 3D stage spotlight (Lights_01): its plate on the wall at 0.06, its pivot in the middle of its 0.85
	-- depth, the can's middle at lightY. Blocks if it did not load.
	local stageProps = propsFor({ "StageLight" })
	while at <= front.aMax - 2 do
		count += 1
		if stageProps then
			frontProp(front, stageProps, "StageLight_" .. count, "StageLight", 1, at, 0.06 + 0.425, lightY - 0.4, "+d")
		else
			front.item("StageLight_" .. count, at - 0.45, at + 0.45, 0.06, 0.25, lightY - 0.2, lightY + 0.2, looks.Gadget)
			front.cylinder("StageLight_" .. count .. "_Can", at, 0.55, lightY, 0.6, 0.8, "d", looks.Gadget)
			front.cylinder("StageLight_" .. count .. "_Lens", at, 0.87, lightY, 0.04, 0.6, "d", looks.GlowWhite)
		end
		at += 4
	end
	if rackProps then
		frontProp(front, rackProps, "JudgesLights", "JudgesLights", 1, -23, 0.29, 5, "+d")
	else
		front.item("JudgesLights", -27, -19, 0.06, 0.4, 5, 8, looks.Gadget)
		for index, a in ipairs({ -25, -23, -21 }) do
			front.cylinder("JudgesLight_" .. index, a, 0.46, 6.5, 0.12, 1.4, "d", looks.GlowWhite)
		end
	end
end

--[[
	Cardio: a red running track (four lanes with white lines and lane numbers)
	along the bottom of a dark wall, and glowing speed lines streaking past the
	door above it.
]]
FRONT.Cardio = function(front)
	front.band("Track", front.aMin, front.aMax, 0, 4.6, 0.06, 0.16, looks.CardioTrack)
	for index, y in ipairs({ 1.15, 2.3, 3.45 }) do
		front.band("Lane_" .. index, front.aMin, front.aMax, y - 0.05, y + 0.05, 0.16, 0.18, looks.LaneWhite)
	end
	front.band("TrackEdge", front.aMin, front.aMax, 4.6, 4.75, 0.06, 0.18, looks.LaneWhite)
	-- Lane numbers at both ends.
	for _, a in ipairs({ front.aMin + 0.5, front.aMax - 1.4 }) do
		for lane = 1, 4 do
			local y0 = (lane - 1) * 1.15 + 0.15
			local number = front.item(string.format("LaneNumber_%d_%d", if a < 0 then 1 else 2, lane), a, a + 0.9, 0.16, 0.17, y0,
				y0 + 0.85, looks.LaneWhite)
			number.Transparency = 1
			local gui = Instance.new("SurfaceGui")
			gui.Face = faceToward(front.toward("+d"))
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 50
			gui.Parent = number
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = tostring(lane)
			label.TextScaled = true
			label.TextColor3 = looks.LaneWhite.color
			label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
			label.Parent = gui
		end
	end
	-- Speed lines: glowing streaks of different lengths and colours either side of the door.
	local streaks = {
		{ y = 5.6, near = 4.6, far = 11.5, look = looks.GlowIce },
		{ y = 6.3, near = 6.2, far = 12.9, look = looks.GlowWhite },
		{ y = 7.0, near = 5.0, far = 9.5, look = looks.GlowWarm },
		{ y = 7.7, near = 7.0, far = 13.2, look = looks.GlowIce },
		{ y = 8.4, near = 5.5, far = 10.8, look = looks.GlowWhite },
	}
	for index, streak in ipairs(streaks) do
		local y, near, far, look = streak.y, streak.near, streak.far, streak.look
		for side, sign in ipairs({ -1, 1 }) do
			-- Right of the door, the low streaks start past the name plaque.
			local a0, a1 = sign * (if sign > 0 and y < 7.0 then math.max(near, 7.2) else near), sign * far
			front.item(string.format("Speed_%d_%d", index, side), math.min(a0, a1), math.max(a0, a1), 0.06, 0.12, y, y + 0.14, look)
		end
	end
end

-- Letters straight on a front (no backing): a see-through part `d` out from the wall, `text` filling it.
local function frontLetters(front: FrontKit, name: string, a0: number, a1: number, y0: number, y1: number, d: number,
	text: string, ink: Color3, lit: boolean?): BasePart
	local part = front.item(name, a0, a1, d, d + 0.04, y0, y1, looks.SignPanel)
	part.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = faceToward(front.toward("+d"))
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = if lit then 0 else 0.5
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = ink
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	label.Parent = gui
	return part
end

--[[
	Office (the gym manager's office and help point): dark walnut panels (the
	builder's face) with grooves and a brass rail, a frosted window with white
	blinds right of the door (no seeing in), brass wall lamps either side of
	the door, a brass name plate, a framed "HELP POINT" sign and a planter.
]]
FRONT.Office = function(front)
	local groove, a = 0, front.aMin + 1.5
	while a < front.aMax - 0.5 do
		if math.abs(a) > front.doorHalf + 0.6 then
			groove += 1
			front.item("Groove_" .. groove, a - 0.04, a + 0.04, 0.06, 0.08, 0.5, front.H - 0.2, looks.SignPanel)
		end
		a += 3
	end
	front.band("BrassRail", front.aMin, front.aMax, 3.3, 3.42, 0.06, 0.14, looks.Brass)
	-- The window: a dark panel (the room behind), white blinds, frosted glass, a black frame and a steel sill.
	local w0, w1, y0, y1 = 5.6, 12.4, 3.9, 8.3
	front.item("Window_Back", w0, w1, 0.06, 0.09, y0, y1, looks.SBarWall) -- over the grooves
	-- The Fronts_01 blinds (sixteen slats and a head rail, d 0.09..0.15), or block slats.
	local blindProps = propsFor({ "Blinds" })
	if blindProps then
		paintLooks(frontProp(front, blindProps, "Blinds", "Blinds", 1, (w0 + w1) / 2, 0.12, y0 + 0.15, "+d"), "Blinds",
			{ Slats = looks.Whiteboard })
	else
		local slat, y = 0, y0 + 0.15
		while y + 0.16 <= y1 - 0.1 do
			slat += 1
			front.item("Blind_" .. slat, w0 + 0.1, w1 - 0.1, 0.09, 0.12, y, y + 0.18, looks.Whiteboard)
			y += 0.26
		end
	end
	front.item("Window_Glass", w0, w1, 0.13, 0.16, y0, y1, looks.FrostedGlass)
	front.item("Window_Frame_1", w0 - 0.18, w0, 0.06, 0.24, y0, y1, looks.Gadget)
	front.item("Window_Frame_2", w1, w1 + 0.18, 0.06, 0.24, y0, y1, looks.Gadget)
	front.item("Window_Frame_Top", w0 - 0.18, w1 + 0.18, 0.06, 0.24, y1, y1 + 0.18, looks.Gadget)
	front.item("Window_Mullion", (w0 + w1) / 2 - 0.08, (w0 + w1) / 2 + 0.08, 0.06, 0.2, y0, y1, looks.Gadget)
	front.item("Window_Sill", w0 - 0.35, w1 + 0.35, 0.06, 0.5, y0 - 0.2, y0, looks.Stainless)
	-- The name plate and the framed help-point sign, left of the door.
	local plate = front.item("NamePlate", -8.4, -5.4, 0.06, 0.12, 4.5, 5.3, looks.Brass)
	plaque(plate, front.toward("+d"), "GYM MANAGER", looks.Brass.color, Color3.fromRGB(40, 28, 18))
	front.item("HelpPoint_Frame", -12.6, -7.8, 0.06, 0.14, 5.9, 8.9, looks.Brass)
	local sign = front.item("HelpPoint", -12.4, -8.0, 0.14, 0.18, 6.1, 8.7, looks.Whiteboard)
	-- The Office took over the Index room's "learn the game" job (user, 2026-10-26).
	writing(sign, front.toward("+d"), "HELP POINT & GUIDE", { "NEW HERE? QUESTIONS?", "LEARN THE GAME INSIDE",
		"ASK THE GYM MANAGER" }, Color3.fromRGB(236, 224, 196), Color3.fromRGB(40, 28, 18))
	local props = propsFor({ "WallSconce", "Planter", "SBarPlant" })
	if props == nil then
		return
	end
	-- The lamps over the name plaque's height (the plaque is left of the door, StarterGymConfig.ClosedRooms).
	for index, side in ipairs({ -1, 1 }) do
		propGlow(frontProp(front, props, "Sconce_" .. index, "WallSconce", 1, side * 4.4, 0.6, 7.6, "+d"), "WallSconce_Light", 12,
			0.8)
	end
	frontProp(front, props, "Planter", "Planter", 1, -10.2, 0.72, 0, "+d")
	hidden(front.block("Planter_Solid", -12.26, -8.14, 0.06, 1.38, 0, 1.3, looks.Glass))
	for index, offset in ipairs({ -0.9, 0.9 }) do
		frontProp(front, props, "Planter_Plant_" .. index, "SBarPlant", 1, -10.2 + offset, 1.0, 0.25, "+d")
	end
end

-- A small instruction board on a front: a title and lines in a black frame.
local function frontBoard(front: FrontKit, name: string, a0: number, a1: number, y0: number, y1: number, title: string,
	lines: { string }, background: Color3, ink: Color3)
	front.item(name .. "_Frame", a0 - 0.12, a1 + 0.12, 0.06, 0.16, y0 - 0.12, y1 + 0.12, looks.Gadget)
	local board = front.item(name, a0, a1, 0.16, 0.2, y0, y1, looks.Whiteboard)
	writing(board, front.toward("+d"), title, lines, background, ink)
end

--[[
	Storage: green corrugated steel (the builder's face) over a yellow kick
	band, stencilled letters, crates on a pallet and one beside it on the
	left, and stacks of bumper plates in mixed colours on the right.
]]
FRONT.Storage = function(front)
	local stencil = Color3.fromRGB(236, 236, 232)
	front.band("KickBand", front.aMin, front.aMax, 0.5, 0.85, 0.06, 0.1, looks.PlateYellow)
	-- (right of the name plaque)
	frontLetters(front, "Stencil", 7.2, 12.8, 6.2, 8.0, 0.06, "STORE 01", stencil)
	frontLetters(front, "Stencil_Clear", 7.2, 12.8, 5.4, 6.0, 0.06, "KEEP CLEAR", stencil)
	frontLetters(front, "Stencil_Load", -13.0, -6.4, 6.0, 6.7, 0.06, "MAX LOAD 500 KG", stencil)
	local props = propsFor({ "Pallet", "WoodCrate", "BumperPlate" })
	if props == nil then
		return
	end
	frontProp(front, props, "Pallet", "Pallet", 1, -11.3, 1.42, 0, "+d", 0.85)
	frontProp(front, props, "Crate_1", "WoodCrate", 1, -11.3, 1.3, 0.51, "+d")
	frontProp(front, props, "Crate_2", "WoodCrate", 3, -11.1, 1.3, 2.31, "+d")
	hidden(front.block("Pallet_Solid", -13.0, -9.6, 0.06, 2.78, 0, 4.11, looks.Glass))
	frontProp(front, props, "Crate_3", "WoodCrate", 5, -7.6, 1.0, 0, "+d")
	hidden(front.block("Crate_Solid", -8.8, -6.4, 0.1, 1.9, 0, 1.8, looks.Glass))
	for index, stack in ipairs({ { at = 6.0, plates = { 1, 2, 5, 3 } }, { at = 8.5, plates = { 5, 5, 2, 2, 1, 4 } },
		{ at = 11.0, plates = { 3, 4, 6 } } }) do
		for k, colourway in ipairs(stack.plates) do
			-- (0.02 up: a plate's flat bottom flickers on the floor)
			frontProp(front, props, string.format("Plates_%d_%d", index, k), "BumperPlate", colourway, stack.at, 1.1,
				0.02 + (k - 1) * 0.34, "+d")
		end
		hidden(front.block("Plates_Solid_" .. index, stack.at - 1, stack.at + 1, 0.1, 2.1, 0, 0.02 + #stack.plates * 0.34, looks.Glass))
	end
end

-- A round wall clock on a front: a black rim, a white face, two hands.
local function wallClock(front: FrontKit, name: string, a: number, y: number, radius: number)
	-- The BackRooms_01 wall clock (1.62 across, 0.185 deep at radius 0.8), scaled to the radius, or blocks.
	local props = propsFor({ "WallClock" })
	if props then
		local scale = radius / 0.8
		frontProp(front, props, name, "WallClock", 1, a, 0.06 + 0.0925 * scale, y - 0.81 * scale, "+d",
			if scale ~= 1 then scale else nil)
		return
	end
	front.cylinder(name .. "_Rim", a, 0.12, y, 0.12, radius * 2, "d", looks.Gadget)
	front.cylinder(name .. "_Face", a, 0.19, y, 0.02, radius * 1.8, "d", looks.Whiteboard)
	front.item(name .. "_Hour", a - 0.04, a + 0.04, 0.2, 0.22, y, y + radius * 0.5, looks.Gadget)
	front.item(name .. "_Minute", a, a + radius * 0.75, 0.22, 0.24, y - 0.03, y + 0.03, looks.Gadget)
end

-- A stick of chalk or a marker lying along the wall on a tray, its middle at (a, d, y): the Fronts_01 stick
-- stretched to its size and painted `look`, or a block cylinder.
local function stick(front: FrontKit, name: string, a: number, d: number, y: number, length: number, diameter: number,
	look: Look)
	local props = propsFor({ "Stick" })
	if props then
		paintLooks(propItem((front :: any) :: Kit, props, name, "Stick", 1, a, d, y - diameter / 2, "+d",
			Vector3.new(length, diameter, diameter)), "Stick", { Body = look })
		return
	end
	front.cylinder(name, a, d, y, length, diameter, "a", look)
end

-- A planter of leafy plants standing on a front (it is solid).
local function frontPlanter(front: FrontKit, props: { [string]: Model }, name: string, centre: number, colourway: number,
	out: number?)
	local back = out or 0.06
	frontProp(front, props, name, "Planter", colourway, centre, back + 0.66, 0, "+d")
	hidden(front.block(name .. "_Solid", centre - 2.06, centre + 2.06, back, back + 1.32, 0, 1.3, looks.Glass))
	for index, offset in ipairs({ -0.9, 0.9 }) do
		frontProp(front, props, string.format("%s_Plant_%d", name, index), "SBarPlant", 1, centre + offset, back + 0.94, 0.25,
			"+d")
	end
end

--[[
	Classroom (the tutorial room for the three lifts): a chalkboard wall (the
	builder's face) in an oak frame with a chalk tray, oak panelling below,
	four chalk drawings (Technique 101, squat, bench, deadlift; user-approved
	2026-10-26) and a school clock.
]]
FRONT.Classroom = function(front)
	local oak = looks.LockersSlats
	local inner = front.doorHalf + 0.35
	front.band("Wainscot", front.aMin, front.aMax, 0.5, 2.6, 0.06, 0.1, oak)
	front.band("Tray", front.aMin + 0.3, front.aMax - 0.3, 2.6, 2.75, 0.06, 0.45, oak)
	front.band("Tray_Lip", front.aMin + 0.3, front.aMax - 0.3, 2.75, 2.85, 0.4, 0.45, oak)
	front.item("Frame_Top", front.aMin, front.aMax, 0.06, 0.16, 9.7, 10.0, oak)
	-- Thin oak sides at the ends, wide oak pillars beside the door (the name plaque is on the right one).
	for index, span in ipairs({ { front.aMin, front.aMin + 0.3 }, { -inner - 2.4, -inner }, { inner, inner + 2.4 },
		{ front.aMax - 0.3, front.aMax } }) do
		front.item("Frame_Side_" .. index, span[1], span[2], 0.06, 0.16, 2.6, 9.7, oak)
	end
	-- Chalk sticks and a duster on the tray.
	for index, chalk in ipairs({ { a = -11.5, look = looks.Whiteboard }, { a = -10.9, look = looks.PlateYellow },
		{ a = 9.8, look = looks.Whiteboard }, { a = 10.5, look = looks.MatCoral } }) do
		stick(front, "Chalk_" .. index, chalk.a, 0.25, 2.8, 0.45, 0.09, chalk.look)
	end
	local dusterProps = propsFor({ "Duster" })
	if dusterProps then
		paintLooks(frontProp(front, dusterProps, "Duster", "Duster", 1, 12.05, 0.26, 2.75, "+d"), "Duster", { Body = looks.Wood })
	else
		front.item("Duster", 11.6, 12.5, 0.12, 0.4, 2.75, 2.95, looks.Wood)
	end
	-- The drawings, two each side of the door (portrait, 3 : 4).
	local width, height, bottom = 3.45, 3.45 * 4 / 3, 3.97
	for index, a0 in ipairs({ -13.1, -9.4, 5.95, 9.65 }) do
		local panel = front.item("Drawing_" .. index, a0, a0 + width, 0.06, 0.08, bottom, bottom + height, looks.SignPanel)
		panel.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = faceToward(front.toward("+d"))
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.6
		gui.Parent = panel
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = StarterGymConfig.ChalkLessons[index]
		image.Parent = gui
	end
	wallClock(front, "Clock", front.aMax - 1.6, 11.4, 0.8)
end

--[[
	Media Room (the podcast and video room): charcoal felt (the builder's face)
	covered in acoustic foam panels in several colours, a red ON AIR lamp over
	the door, a broadcast microphone on its wall arm and headphones on pegs
	beside it.
]]
FRONT.MediaRoom = function(front)
	local colours = { looks.FoamRed, looks.FoamBlue, looks.FoamYellow, looks.FoamGreen, looks.FoamPurple, looks.FoamGrey }
	local size, gap = 2.0, 0.15
	-- Each panel the Fronts_01 pyramid foam tile in its colour, or a block.
	local foamProps = propsFor({ "FoamTile" })
	local function foam(id: string, a0: number, columns: number, skip: ((column: number, row: number) -> boolean)?)
		for column = 1, columns do
			for row = 1, 4 do
				if not (skip and skip(column, row)) then
					local a, y = a0 + (column - 1) * (size + gap), 1.0 + (row - 1) * (size + gap)
					local name, look = string.format("Foam_%s_%d_%d", id, column, row), colours[(column + row * 2) % #colours + 1]
					if foamProps then
						paintLooks(frontProp(front, foamProps, name, "FoamTile", 1, a + size / 2, 0.21, y, "+d"), "FoamTile",
							{ Foam = look })
					else
						front.item(name, a, a + size, 0.06, 0.36, y, y + size, look)
					end
				end
			end
		end
	end
	foam("L", front.aMin + 0.4, 4)
	foam("R", 8.9, 2)
	-- A glowing equaliser over the mic.
	for k = 1, 9 do
		local a, height = 4.4 + (k - 1) * 0.46, 0.3 + 0.9 * math.abs(math.sin(k * 1.7))
		front.item("Equaliser_" .. k, a, a + 0.26, 0.06, 0.12, 8.2, 8.2 + height, if k % 3 == 0 then looks.GlowRed else looks.GlowIce)
	end
	local props = propsFor({ "StudioMic", "OnAirLamp", "Headphones" })
	if props == nil then
		return
	end
	propGlow(frontProp(front, props, "OnAir", "OnAirLamp", 1, 0, 0.26, front.doorTop + 0.37, "+d"), "OnAirLamp_Glow", 8, 1)
	-- The red mic (black vanished on the dark wall), as big as fits within FrontDepthStuds.
	frontProp(front, props, "Mic", "StudioMic", 3, 7.8, 1.5, 5.0, "+d", 1.25) -- right of the name plaque
	for index, a in ipairs({ 5.4, 7.8 }) do
		frontProp(front, props, "Headphones_" .. index, "Headphones", index, a, 0.35, 2.6, "+d")
	end
end

--[[
	Warm-up & Mobility: light oak (the builder's face) with horizontal oak
	slats over a sage-green dado, glowing "MOVE WELL" / "LIFT WELL" signs
	high up either side of the door, big resistance bands in many colours on hooks
	along a steel rail on the left, two wall racks of foam rollers and a
	warm-up routine board on the right, planters at both ends.
]]
FRONT.WarmUp = function(front)
	local oak = looks.LockersSlats
	front.band("Dado", front.aMin, front.aMax, 0.5, 3.0, 0.06, 0.1, looks.StaffCabinet)
	front.band("Dado_Rail", front.aMin, front.aMax, 3.0, 3.15, 0.06, 0.18, oak)
	local slat, y = 0, 3.5
	while y + 0.3 <= 9.7 do
		slat += 1
		front.band("Slat_" .. slat, front.aMin, front.aMax, y, y + 0.3, 0.06, 0.14, oak)
		y += 0.6
	end
	local mint = Color3.fromRGB(150, 240, 190)
	for index, sign in ipairs({ { text = "MOVE WELL", a0 = -27, a1 = -12 }, { text = "LIFT WELL", a0 = 12, a1 = 27 } }) do
		frontLetters(front, "Neon_" .. index, sign.a0, sign.a1, 10.4, 12.0, 0.14, sign.text, mint, true)
		front.item("Neon_" .. index .. "_Underline", sign.a0 + 1, sign.a1 - 1, 0.14, 0.2, 10.15, 10.25, looks.GlowGreen)
	end
	-- Big bands (1.3 x) on hooks along a rail.
	front.item("BandRail", -26.4, -6.4, 0.14, 0.3, 8.0, 8.25, looks.SteelBeam)
	local props = propsFor({ "ResistanceBand", "MobilityRoller", "RollerRack", "Planter", "SBarPlant" })
	if props then
		for k = 1, 7 do
			frontProp(front, props, "Band_" .. k, "ResistanceBand", k, -24 + (k - 1) * 2.6, 0.32, 8.125 - 2.45 * 1.3, "+d", 1.3)
		end
		-- Two racks of four rollers each.
		for index, centre in ipairs({ 8.5, 12.5 }) do
			frontProp(front, props, "RollerRack_" .. index, "RollerRack", 1, centre, 0.61, 0, "+d")
			hidden(front.block("RollerRack_Solid_" .. index, centre - 1.3, centre + 1.3, 0.14, 1.08, 0, 4.7, looks.Glass))
			for level, peg in ipairs({ 0.9, 1.9, 2.9, 3.9 }) do
				frontProp(front, props, string.format("Roller_%d_%d", index, level), "MobilityRoller", ((index - 1) * 4 + level - 1) % 6 + 1,
					centre, 0.64, peg, "+d")
			end
		end
		frontPlanter(front, props, "Planter_1", front.aMin + 2.6, 2, 0.14)
		frontPlanter(front, props, "Planter_2", front.aMax - 2.6, 4, 0.14)
	end
	frontBoard(front, "Routine", 17, 25, 4.2, 8.2, "WARM-UP ROUTINE",
		{ "5 MIN EASY CARDIO", "DYNAMIC STRETCHES", "BANDED SHOULDERS", "ROLL IT OUT" }, Color3.fromRGB(236, 224, 196),
		Color3.fromRGB(34, 98, 62))
end

--[[
	Coaches (later the squat, bench and deadlift coaches, GAME_DESIGN §27):
	navy panels (the builder's face) with a white and a gold team stripe, a big
	whiteboard with the week's training programme left of the door, the three
	coaches' name plates over a row of big clipboards in many colours right of
	it, a clock and planters.
]]
FRONT.Coach = function(front)
	front.band("Stripe_White", front.aMin, front.aMax, 2.55, 2.7, 0.06, 0.1, looks.Whiteboard)
	front.band("Stripe_Gold", front.aMin, front.aMax, 2.8, 2.95, 0.06, 0.1, looks.Brass)
	-- (right of the room's name plaque)
	for index, plate in ipairs({ { text = "SQUAT COACH", a0 = 8.0 }, { text = "BENCH COACH", a0 = 13.4 },
		{ text = "DEADLIFT COACH", a0 = 18.8 } }) do
		front.item("NamePlate_" .. index .. "_Frame", plate.a0 - 0.12, plate.a0 + 4.72, 0.06, 0.14, 7.68, 9.32, looks.Brass)
		local part = front.item("NamePlate_" .. index, plate.a0, plate.a0 + 4.6, 0.14, 0.18, 7.8, 9.2, looks.Whiteboard)
		plaque(part, front.toward("+d"), plate.text, Color3.fromRGB(250, 250, 250), Color3.fromRGB(30, 48, 98))
	end
	-- The whiteboard: a steel frame, the board and its marker tray.
	local w0, w1, y0, y1 = -26, -6, 3.2, 9.4
	-- The BackRooms_01 whiteboard frame and tray stretched round the board, or blocks.
	local frameProps = propsFor({ "WhiteboardFrame" })
	if frameProps then
		propItem((front :: any) :: Kit, frameProps, "Whiteboard_Frame", "WhiteboardFrame", 1, (w0 + w1) / 2, 0.28, y0 - 0.45, "+d",
			Vector3.new(w1 - w0 + 0.4, y1 - y0 + 0.65, 0.44))
	else
		front.item("Whiteboard_Frame", w0 - 0.2, w1 + 0.2, 0.06, 0.18, y0 - 0.2, y1 + 0.2, looks.Stainless)
	end
	local board = front.item("Whiteboard", w0, w1, 0.18, 0.22, y0, y1, looks.Whiteboard)
	writing(board, front.toward("+d"), "THIS WEEK'S PROGRAMME", {
		"MON   SQUAT 5 x 5   ·   BENCH 4 x 6",
		"WED   DEADLIFT 3 x 3   ·   ROWS 4 x 10",
		"FRI   BENCH 5 x 3   ·   SQUAT 3 x 8",
		"SAT   TECHNIQUE + MOBILITY",
	}, Color3.fromRGB(250, 250, 250), Color3.fromRGB(30, 48, 98))
	if not frameProps then
		front.item("Whiteboard_Tray", w0, w1, 0.06, 0.5, y0 - 0.45, y0 - 0.25, looks.Stainless)
	end
	for index, marker in ipairs({ { a = -24, look = looks.PlateRed }, { a = -23.3, look = looks.PlateBlue },
		{ a = -22.6, look = looks.Gadget }, { a = -21.9, look = looks.PlateGreen } }) do
		stick(front, "Marker_" .. index, marker.a, 0.3, y0 - 0.17, 0.55, 0.12, marker.look)
	end
	wallClock(front, "Clock", 15, 11.4, 0.8)
	front.item("ClipRail", 7.0, 25.0, 0.06, 0.2, 6.95, 7.1, looks.Stainless)
	local props = propsFor({ "Clipboard", "Planter", "SBarPlant" })
	if props == nil then
		return
	end
	-- Big clipboards (1.4 x) hanging from the rail.
	for k = 1, 9 do
		frontProp(front, props, "Clipboard_" .. k, "Clipboard", (k - 1) % 6 + 1, 8.0 + (k - 1) * 2, 0.17, 7.05 - 2.05, "+d", 1.4)
	end
	frontPlanter(front, props, "Planter_1", front.aMin + 2.6, 1)
	frontPlanter(front, props, "Planter_2", front.aMax - 2.6, 3)
end

-- Hand-written chalk lettering (Roblox's own fonts): bold marker for headings and numbers, neat hand for names.
local CHALK_BOLD = Font.fromEnum(Enum.Font.PermanentMarker)
local CHALK_HAND = Font.fromEnum(Enum.Font.PatrickHand)
local CHALK = {
	white = Color3.fromRGB(240, 238, 228),
	yellow = Color3.fromRGB(250, 222, 110),
	pink = Color3.fromRGB(246, 150, 180),
	blue = Color3.fromRGB(150, 200, 245),
	green = Color3.fromRGB(160, 230, 170),
}

-- A see-through writing surface on a front, `d` out from the wall, with a SurfaceGui named `name` facing the hall.
local function chalkPanel(front: FrontKit, name: string, a0: number, a1: number, y0: number, y1: number, d: number): SurfaceGui
	local part = front.item(name, a0, a1, d, d + 0.02, y0, y1, looks.SignPanel)
	part.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = faceToward(front.toward("+d"))
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.6
	gui.Parent = part
	return gui
end

-- Chalk writing at (x, y) with size (w, h), as fractions of `parent`.
local function chalkText(parent: Instance, name: string, text: string, x: number, y: number, w: number, h: number,
	colour: Color3, font: Font, align: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(w, h)
	label.Text = text
	label.TextColor3 = colour
	label.TextScaled = true
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.FontFace = font
	label.Parent = parent
	return label
end

-- A chalk line (a thin slightly see-through strip) from (x, y), `w` wide and `h` high (fractions), or
-- `pixels` thick when w or h is 0.
local function chalkLine(parent: Instance, name: string, x: number, y: number, w: number, h: number, pixels: number,
	colour: Color3?)
	local line = Instance.new("Frame")
	line.Name = name
	line.BorderSizePixel = 0
	line.BackgroundColor3 = colour or CHALK.white
	line.BackgroundTransparency = 0.15
	line.Position = UDim2.fromScale(x, y)
	line.Size = UDim2.new(w, if w == 0 then pixels else 0, h, if h == 0 then pixels else 0)
	line.Parent = parent
end

-- A chalk outline round a frame (a drawn box or circle).
local function chalkOutline(frame: GuiObject, colour: Color3, round: boolean)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = 3
	stroke.Transparency = 0.15
	stroke.Parent = frame
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
end

--[[
	The records wall (StarterGymConfig.RecordsWall; user 2026-10-26: the hall's
	back wall shows the gym's records, "like a drawn-on chalk wall, to give the
	game a more homely feeling", from photos of real gym record boards): a
	black chalkboard across the wall in an oak frame with a chalk tray. In the
	middle the GYM RECORDS table drawn in chalk: one row per weight class
	(WeightClassConfig, smallest at the top), a column each for the squat,
	bench, deadlift and total. On the right the meet ladder drawn in chalk, on
	the left a chalk barbell, planters at both ends.
	Every record cell is a Frame "Record_<class>_<LIFT>" (attributes
	WeightClass and Lift) in the SurfaceGui "RecordsTable", with an "Avatar"
	ImageLabel (the holder's Roblox headshot), a "Holder" label (their
	username) and a "Kg" label: GymRecordsWall fills them in from the saved
	gym records (the SurfaceGui is tagged GymRecordsConfig.WallTag). An empty
	record shows "?" and "—".
]]
FRONT.RecordsWall = function(front)
	local oak = looks.LockersSlats
	local w0, w1, b0, b1 = -86, 86, 2.2, 21.5
	front.item("Chalkboard", w0, w1, 0.06, 0.12, b0, b1, looks.ChalkWall)
	front.item("Frame_Top", w0 - 0.4, w1 + 0.4, 0.06, 0.24, b1, b1 + 0.4, oak)
	front.item("Frame_Bottom", w0 - 0.4, w1 + 0.4, 0.06, 0.24, b0 - 0.4, b0, oak)
	for index, a in ipairs({ w0 - 0.4, w1 }) do
		front.item("Frame_Side_" .. index, a, a + 0.4, 0.06, 0.24, b0, b1, oak)
	end
	front.item("Tray", w0, w1, 0.24, 0.6, b0 - 0.4, b0 - 0.25, oak)
	for index, chalk in ipairs({ { a = -40, look = looks.Whiteboard }, { a = -39.3, look = looks.PlateYellow },
		{ a = 22, look = looks.MatCoral }, { a = 70, look = looks.Whiteboard } }) do
		stick(front, "Chalk_" .. index, chalk.a, 0.42, b0 - 0.2, 0.45, 0.09, chalk.look)
	end

	-- The records table.
	local classes = WeightClassConfig.Classes
	local lifts = { "SQUAT", "BENCH", "DEADLIFT", "TOTAL" }
	local records = chalkPanel(front, "RecordsTable", -58, 58, b0 + 0.4, b1 - 0.3, 0.12)
	records:AddTag(GymRecordsConfig.WallTag)
	chalkText(records, "Title", "GYM RECORDS", 0.2, 0.0, 0.6, 0.1, CHALK.white, CHALK_BOLD)
	local top, rows = 0.12, #classes + 1
	local rowH = (1 - top - 0.01) / rows
	local classW = 0.13
	local liftW = (1 - classW) / #lifts
	-- The grid: a line under every row, a line between every column.
	for row = 0, rows do
		chalkLine(records, "Line_Row_" .. row, 0, top + row * rowH, 1, 0, 3)
	end
	for column = 0, #lifts + 1 do
		local x = if column == 0 then 0 elseif column == 1 then classW else classW + (column - 1) * liftW
		chalkLine(records, "Line_Column_" .. column, math.min(x, 0.997), top, 0, 1 - top - 0.01, 3)
	end
	chalkText(records, "Head_Class", "WEIGHT CLASS", 0.005, top + rowH * 0.15, classW - 0.01, rowH * 0.7, CHALK.yellow, CHALK_BOLD)
	for index, lift in ipairs(lifts) do
		chalkText(records, "Head_" .. lift, lift, classW + (index - 1) * liftW, top + rowH * 0.12, liftW, rowH * 0.76, CHALK.white,
			CHALK_BOLD)
	end
	for row, class in ipairs(classes) do
		local y = top + row * rowH
		chalkText(records, "Class_" .. row, string.upper(class.label), 0.01, y + rowH * 0.15, classW - 0.02, rowH * 0.7,
			CHALK.yellow, CHALK_BOLD)
		for index, lift in ipairs(lifts) do
			local cell = Instance.new("Frame")
			cell.Name = string.format("Record_%s_%s", class.label, lift)
			cell.BackgroundTransparency = 1
			cell.Position = UDim2.fromScale(classW + (index - 1) * liftW, y)
			cell.Size = UDim2.fromScale(liftW, rowH)
			cell:SetAttribute("WeightClass", class.label)
			cell:SetAttribute("Lift", lift)
			cell.Parent = records
			-- The holder's Roblox headshot in a chalk circle ("?" until there is one).
			local avatar = Instance.new("ImageLabel")
			avatar.Name = "Avatar"
			avatar.BackgroundTransparency = 1
			avatar.Image = ""
			avatar.AnchorPoint = Vector2.new(0, 0.5)
			avatar.Position = UDim2.fromScale(0.05, 0.5)
			avatar.Size = UDim2.fromScale(0.82, 0.82)
			avatar.SizeConstraint = Enum.SizeConstraint.RelativeYY
			avatar.Parent = cell
			chalkOutline(avatar, CHALK.white, true)
			chalkText(avatar, "Unknown", "?", 0.2, 0.15, 0.6, 0.7, CHALK.white, CHALK_HAND)
			-- The username beside the avatar, the weight big on the right.
			chalkText(cell, "Holder", "—", 0.13, 0.2, 0.42, 0.6, CHALK.blue, CHALK_HAND, Enum.TextXAlignment.Left)
			chalkText(cell, "Kg", "— KG", 0.55, 0.1, 0.41, 0.8, if lift == "TOTAL" then CHALK.pink else CHALK.white, CHALK_BOLD,
				Enum.TextXAlignment.Right)
		end
	end

	-- The meet ladder in chalk: four rising steps, each with its name above it.
	local ladder = chalkPanel(front, "MeetLadder", 62, 84, b0 + 2, b1 - 1.5, 0.12)
	chalkText(ladder, "Title", "THE MEET LADDER", 0.02, 0.0, 0.96, 0.14, CHALK.white, CHALK_BOLD)
	for k, step in ipairs({ { name = "LOCAL", colour = CHALK.green }, { name = "NATIONALS", colour = CHALK.blue },
		{ name = "WORLDS", colour = CHALK.white }, { name = "SHEFFIELD", colour = CHALK.yellow } }) do
		local height = 0.14 + k * 0.14
		local box = Instance.new("Frame")
		box.Name = "Step_" .. k
		box.BackgroundTransparency = 1
		box.Position = UDim2.fromScale(0.04 + (k - 1) * 0.235, 0.98 - height)
		box.Size = UDim2.fromScale(0.2, height)
		box.Parent = ladder
		chalkOutline(box, step.colour, false)
		chalkText(ladder, "Label_" .. k, step.name, 0.02 + (k - 1) * 0.235, 0.98 - height - 0.09, 0.24, 0.07, step.colour,
			CHALK_BOLD)
	end

	-- A chalk barbell on the left, the big three under it.
	local big = chalkPanel(front, "BigThree", -84, -62, b0 + 2, b1 - 1.5, 0.12)
	chalkText(big, "Title", "THE BIG THREE", 0.02, 0.0, 0.96, 0.14, CHALK.white, CHALK_BOLD)
	chalkLine(big, "Bar", 0.06, 0.34, 0.88, 0, 6)
	for index, plate in ipairs({ { x = 0.1, h = 0.3, colour = CHALK.blue }, { x = 0.16, h = 0.22, colour = CHALK.yellow },
		{ x = 0.82, h = 0.22, colour = CHALK.yellow }, { x = 0.88, h = 0.3, colour = CHALK.blue } }) do
		chalkLine(big, "Plate_" .. index, plate.x, 0.34 - plate.h / 2, 0, plate.h, 14, plate.colour)
	end
	for index, lift in ipairs({ "SQUAT", "BENCH", "DEADLIFT" }) do
		chalkText(big, "Lift_" .. index, lift, 0.1, 0.52 + (index - 1) * 0.15, 0.8, 0.12, CHALK.white, CHALK_HAND)
	end

	local props = propsFor({ "Planter", "SBarPlant" })
	if props then
		frontPlanter(front, props, "Planter_1", front.aMin + 4, 2, 0.24)
		frontPlanter(front, props, "Planter_2", front.aMax - 4, 4, 0.24)
	end
end

--[[
	The Strongman Shed (GAME_DESIGN §27, user 2026-10-26: a big shed of its own
	beside the gym), furnished like a room from its roller door (its walls,
	roof, lamps and sign are the builder's): two turf lanes with white lines
	(yoke on the left, farmer's walk beside it) and a chalk stand between their
	starts; at the far end a loaded yoke and farmer's handles, a steel rig with
	chains and a row of atlas stones on stands; tractor tyres and logs on the
	right; sandbags near the door. Look only (no gameplay yet).
]]
FURNISH.StrongmanShed = function(kit)
	-- The turf lanes, with white side lines and start and finish lines.
	for _, lane in ipairs({ { name = "YokeLane", a0 = -32, a1 = -22 }, { name = "FarmerLane", a0 = -18, a1 = -8 } }) do
		kit.item(lane.name, lane.a0, lane.a1, 4.4, 40.4, 0, 0.08, looks.YardTurf)
		for index, a in ipairs({ lane.a0, lane.a1 - 0.2 }) do
			kit.item(lane.name .. "_Side_" .. index, a, a + 0.2, 4.4, 40.4, 0.08, 0.1, looks.LaneWhite)
		end
		kit.item(lane.name .. "_Start", lane.a0, lane.a1, 4.4, 4.7, 0.08, 0.1, looks.LaneWhite)
		kit.item(lane.name .. "_Finish", lane.a0, lane.a1, 40.1, 40.4, 0.08, 0.1, looks.LaneWhite)
	end
	-- A chalk stand between the lanes' starts, and a steel rig at the far end with chains hanging from its front
	-- beam: the BackRooms_01 models on the old solid blocks (now hidden), or blocks.
	local shedProps = propsFor({ "ChalkStand", "StrongmanRig" })
	local solids = { kit.block("ChalkStand", -20.4, -19.6, 2.6, 3.4, 0, 3.2, looks.SteelBeam) }
	local r0, r1, e0, e1 = -4, 6, 42.4, 52.4
	for index, corner in ipairs({ { r0, e0 }, { r1, e0 }, { r0, e1 }, { r1, e1 } }) do
		table.insert(solids, kit.block("Rig_Post_" .. index, corner[1] - 0.3, corner[1] + 0.3, corner[2] - 0.3, corner[2] + 0.3,
			0, 10.2, looks.SteelBeam))
	end
	for index, d in ipairs({ e0, e1 }) do
		table.insert(solids, kit.block("Rig_Beam_" .. index, r0 - 0.3, r1 + 0.3, d - 0.3, d + 0.3, 9.6, 10.2, looks.SteelBeam))
	end
	for index, a in ipairs({ r0, r1 }) do
		table.insert(solids, kit.block("Rig_Side_" .. index, a - 0.3, a + 0.3, e0 + 0.3, e1 - 0.3, 9.6, 10.2, looks.SteelBeam))
	end
	if shedProps then
		for _, part in ipairs(solids) do
			hidden(part)
		end
		paintLooks(propItem(kit, shedProps, "ChalkStand_Model", "ChalkStand", 1, -20, 3, 0, "+d"), "ChalkStand",
			{ Stand = looks.SteelBeam })
		paintLooks(propItem(kit, shedProps, "Rig", "StrongmanRig", 1, (r0 + r1) / 2, (e0 + e1) / 2, 0, "+d"), "StrongmanRig",
			{ Frame = looks.SteelBeam })
	else
		kit.cylinder("ChalkStand_Bowl", -20, 3, 3.45, 0.5, 1.6, "up", looks.Whiteboard)
		kit.cylinder("Rig_PullUpBar", (r0 + r1) / 2, (e0 + e1) / 2, 9.35, r1 - r0, 0.2, "a", looks.Stainless)
	end
	local props = propsFor({ "Tyre", "Sandbag", "Yoke", "FarmerHandle", "AtlasStone", "AtlasStand", "StrongLog", "Chain",
		"CompPlate" })
	if props == nil then
		return
	end
	local function put(name: string, item: string, colourway: number, a: number, d: number, y: number, facing: string,
		scale: number?): Model
		return frontProp((kit :: any) :: FrontKit, props, name, item, colourway, a, d, y, facing, scale)
	end
	for index, a in ipairs({ -1.5, 1, 3.5 }) do
		put("Rig_Chain_" .. index, "Chain", index % 2 + 1, a, e0, 9.6 - 5.4, "-d")
	end
	-- The yoke at the end of its lane, a red and a blue plate on each horn.
	local yokeA, ends = -27, 46.4
	put("Yoke", "Yoke", 1, yokeA, ends, 0, "-d")
	for _, side in ipairs({ -1, 1 }) do
		hidden(kit.block("Yoke_Solid_" .. side + 2, yokeA + side * 2.6 - 0.25, yokeA + side * 2.6 + 0.25, ends - 1.2, ends + 1.2,
			0, 7.4, looks.Glass))
		for k = 0, 1 do
			put(string.format("Yoke_Plate_%d_%d", side + 2, k + 1), "CompPlate", k + 1, yokeA + side * (3.15 + k * 0.22), ends, 0,
				if side > 0 then "+a" else "-a")
		end
	end
	-- Two farmer's handles at the end of theirs, a plate at each end.
	for index, a in ipairs({ -14.3, -11.7 }) do
		put("Farmer_" .. index, "FarmerHandle", index, a, ends, 0, "+a")
		for side, sign in ipairs({ -1, 1 }) do
			put(string.format("Farmer_%d_Plate_%d", index, side), "CompPlate", 2 + index, a, ends + sign * 2.45, 0,
				if sign > 0 then "+d" else "-d")
		end
	end
	-- A row of atlas stones on their stands, smallest to biggest.
	for index, scale in ipairs({ 0.85, 1, 1.15, 1.3 }) do
		local a = 8 + index * 5
		put("Stand_" .. index, "AtlasStand", index % 2 + 1, a, ends, 0, "-d")
		put("Stone_" .. index, "AtlasStone", index % 3 + 1, a, ends, 1.24, "-d", scale)
		hidden(kit.block("Stand_Solid_" .. index, a - 1.3, a + 1.3, ends - 1.3, ends + 1.3, 0, 1.3 + 1.8 * scale, looks.Glass))
	end
	-- Tractor tyres and logs on the right.
	for index, d in ipairs({ 26, 17.5 }) do
		put("Tyre_" .. index, "Tyre", index, 30, d, 0, "-d")
		hidden(kit.block("Tyre_Solid_" .. index, 26.7, 33.3, d - 3.3, d + 3.3, 0, 2.6, looks.Glass))
	end
	for index, d in ipairs({ 19, 25 }) do
		put("Log_" .. index, "StrongLog", index + 1, 17, d, 0, "-d")
		hidden(kit.block("Log_Solid_" .. index, 13.5, 20.5, d - 0.7, d + 0.7, 0, 1.4, looks.Glass))
	end
	-- Sandbags near the door.
	for index, spot in ipairs({ { -1.5, 12 }, { 1.8, 12 }, { 5.1, 12 }, { 0.2, 15.5 }, { 3.5, 15.5 } }) do
		put("Sandbag_" .. index, "Sandbag", index, spot[1], spot[2], 0, "-d")
	end
end

--[[
	Decorates every closed room's front that has a FRONT design (StarterGymBuilder
	left their regions in model.Fronts), into model.FrontProps, one folder per
	room. A front that goes wrong is left out with a warning, like a room.
]]
function RoomProps.buildFronts(model: Model): number
	local regions = model:FindFirstChild("Fronts")
	if regions == nil then
		return 0
	end
	local holder = Instance.new("Folder")
	holder.Name = "FrontProps"
	holder.Parent = model
	local themed = 0
	for _, region in ipairs(regions:GetChildren()) do
		local name = string.sub(region.Name, 7) -- without "Front_"
		local decorate = FRONT[name]
		if region:IsA("BasePart") and decorate then
			local folder = Instance.new("Folder")
			folder.Name = name
			local ok, problem = pcall(function()
				decorate(frontFor(folder, region))
			end)
			if ok then
				folder.Parent = holder
				themed += 1
			else
				folder:Destroy()
				warn(string.format("[RoomProps] %s front left plain: %s", name, tostring(problem)))
			end
		end
	end
	return themed
end

return RoomProps
