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
local BuildParts = require(script.Parent:WaitForChild("BuildParts"))

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
	-- A copy of a model template (decor), its pivot at (a, d, y), its front
	-- (the pivot's LookVector) toward `facing`. It must stay inside the room.
	place: (name: string, template: Model, a: number, d: number, y: number, facing: string) -> Model,
}
type Zone = { a0: number, a1: number, d0: number, d1: number }

-- The face of an unrotated part that looks toward `direction`.
local function faceToward(direction: Vector3): Enum.NormalId
	if math.abs(direction.X) > 0.5 then
		return if direction.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	elseif math.abs(direction.Z) > 0.5 then
		return if direction.Z > 0 then Enum.NormalId.Back else Enum.NormalId.Front
	end
	return if direction.Y > 0 then Enum.NormalId.Top else Enum.NormalId.Bottom
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
	for _, spot in ipairs(doorSpots) do
		if spot.X >= low.X - 0.7 and spot.X <= high.X + 0.7 and spot.Z >= low.Z - 0.7 and spot.Z <= high.Z + 0.7
			and spot.Y > low.Y and spot.Y < high.Y then
			local a, d = toLocal(spot)
			local toFront, toBack, toLeft, toRight = math.abs(d), math.abs(D - d), math.abs(a + W / 2), math.abs(W / 2 - a)
			local nearest = math.min(toFront, toBack, toLeft, toRight)
			if nearest == toFront then
				table.insert(zones, { a0 = a - DOOR_HALF_CLEAR, a1 = a + DOOR_HALF_CLEAR, d0 = 0, d1 = DOOR_DEPTH_CLEAR })
			elseif nearest == toBack then
				table.insert(zones, { a0 = a - DOOR_HALF_CLEAR, a1 = a + DOOR_HALF_CLEAR, d0 = D - DOOR_DEPTH_CLEAR, d1 = D })
			elseif nearest == toLeft then
				table.insert(zones, { a0 = -W / 2, a1 = -W / 2 + DOOR_DEPTH_CLEAR, d0 = d - DOOR_HALF_CLEAR, d1 = d + DOOR_HALF_CLEAR })
			else
				table.insert(zones, { a0 = W / 2 - DOOR_DEPTH_CLEAR, a1 = W / 2, d0 = d - DOOR_HALF_CLEAR, d1 = d + DOOR_HALF_CLEAR })
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
	kit.W, kit.D, kit.H, kit.doorA = W, D, H, doorA
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
	kit.place = function(name, template, a, d, y, facing)
		local copy = template:Clone()
		copy.Name = name
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

local function plant(kit: Kit, name: string, a: number, d: number)
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

-- An office chair (decor), the sitter looking toward `facing` ("+d", "-d", "+a" or "-a").
local function chair(kit: Kit, name: string, a: number, d: number, facing: string)
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

-- A desk: wooden top at 3.0 on two steel side panels.
local function desk(kit: Kit, name: string, a0: number, a1: number, d0: number, d1: number)
	kit.block(name .. "_Top", a0, a1, d0, d1, 2.8, 3, looks.Wood)
	kit.block(name .. "_Side_1", a0, a0 + 0.2, d0 + 0.1, d1 - 0.1, 0, 2.8, looks.SteelBeam)
	kit.block(name .. "_Side_2", a1 - 0.2, a1, d0 + 0.1, d1 - 0.1, 0, 2.8, looks.SteelBeam)
end

-- A monitor standing on a desk top (at 3.0), its screen across the room.
local function monitor(kit: Kit, name: string, a: number, d: number)
	kit.item(name .. "_Base", a - 0.5, a + 0.5, d - 0.35, d + 0.35, 3, 3.04, looks.Gadget)
	kit.item(name .. "_Stand", a - 0.1, a + 0.1, d - 0.1, d + 0.1, 3.04, 3.5, looks.Gadget)
	kit.item(name .. "_Screen", a - 1.4, a + 1.4, d - 0.06, d + 0.06, 3.5, 5.1, looks.Gadget)
end

--[[
	Shelving against a wall from s0 to s1: a back panel, two end panels and
	`levels` boards plus a top board, `depth` deep and `height` tall. `fill` is
	called for every slot on every board (level 1 = lowest) with the slot's s,
	its middle depth t and the board's top y.
]]
local function shelving(wall: Wall, name: string, s0: number, s1: number, depth: number, height: number, levels: number,
	look: Look, fill: ((level: number, s: number, t: number, y: number) -> ())?)
	wall.block(name .. "_Back", s0, s1, 0, 0.1, 0, height, look)
	wall.block(name .. "_End_1", s0, s0 + 0.15, 0.1, depth, 0, height, look)
	wall.block(name .. "_End_2", s1 - 0.15, s1, 0.1, depth, 0, height, look)
	wall.block(name .. "_Board_Top", s0 + 0.15, s1 - 0.15, 0.1, depth, height - 0.15, height, look)
	local spacing = height / levels
	for level = 1, levels do
		local y = 0.15 + (level - 1) * spacing
		wall.block(string.format("%s_Board_%d", name, level), s0 + 0.15, s1 - 0.15, 0.1, depth, y, y + 0.15, look)
		if fill then
			local s = s0 + 0.9
			while s <= s1 - 0.9 do
				fill(level, s, (depth + 0.1) / 2, y + 0.15)
				s += 1.3
			end
		end
	end
end

local function towels(wall: Wall, name: string): (level: number, s: number, t: number, y: number) -> ()
	return function(level, s, t, y)
		for fold = 0, 2 do
			wall.item(string.format("%s_Towel_%d_%.0f_%d", name, level, s * 10, fold), s - 0.5, s + 0.5, t - 0.45, t + 0.45,
				y + fold * 0.3, y + (fold + 1) * 0.3 - 0.02, looks.ShirtWhite)
		end
	end
end

local function boxes(wall: Wall, name: string): (level: number, s: number, t: number, y: number) -> ()
	return function(level, s, t, y)
		local tall = if (level + math.floor(s)) % 2 == 0 then 1.0 else 1.4
		wall.item(string.format("%s_Box_%d_%.0f", name, level, s * 10), s - 0.5, s + 0.5, t - 0.6, t + 0.6, y, y + tall,
			looks.Cardboard)
	end
end

local function books(wall: Wall, name: string): (level: number, s: number, t: number, y: number) -> ()
	local colours = { looks.PlateRed, looks.PlateBlue, looks.Gadget, looks.ShirtWhite }
	return function(level, s, t, y)
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

local function cafeTable(kit: Kit, name: string, a: number, d: number)
	kit.block(name .. "_Top", a - 1.3, a + 1.3, d - 1.3, d + 1.3, 3, 3.15, looks.Wood)
	kit.block(name .. "_Pole", a - 0.15, a + 0.15, d - 0.15, d + 0.15, 0.1, 3, looks.SteelBeam)
	kit.block(name .. "_Base", a - 0.7, a + 0.7, d - 0.7, d + 0.7, 0, 0.1, looks.Stainless)
	stool(kit, name .. "_Stool_1", a - 2.3, d)
	stool(kit, name .. "_Stool_2", a + 2.3, d)
end

-- A see-through drinks fridge against a wall, full of bottles.
local function drinksFridge(kit: Kit, wall: Wall, name: string, s0: number, s1: number)
	local depth, height = 2.2, 7.5
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
	for index, look in ipairs(plates) do
		kit.cylinder(string.format("%s_%d", name, index), a, d, 0.09 + (index - 1) * 0.18, 0.18, 2, "up", look)
	end
end

-- ---------------------------------------------------------------- the rooms (step 6a: ground floor)

local FURNISH: { [string]: (kit: Kit) -> () } = {}

FURNISH.Lockers = function(kit)
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

FURNISH.Showers = function(kit)
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
	shelving(shelfWall, "TowelShelf", 10, 16, 1.2, 4.5, 3, looks.DeskBody, towels(shelfWall, "TowelShelf"))
end

FURNISH.Cafe = function(kit)
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

FURNISH.Kitchen = function(kit)
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
	shelving(pantryWall, "Pantry", 9, 18, 1.4, 7, 3, looks.DeskBody, boxes(pantryWall, "Pantry"))
	plant(kit, "Plant", if kit.doorA > 0 then -hw + 1.5 else hw - 1.5, 1.5)
end

FURNISH.Office = function(kit)
	local hw, D = kit.W / 2, kit.D
	desk(kit, "Desk", -5, 5, D - 7, D - 4.5)
	monitor(kit, "Monitor", 0, D - 6.4)
	kit.item("Keyboard", -1, 1, D - 5.6, D - 5.1, 3, 3.06, looks.Gadget)
	chair(kit, "Chair", 0, D - 2.8, "-d")
	local right = kit.wall("right")
	shelving(right, "Bookshelf", 8, 20, 1.4, 8, 4, looks.Wood, books(right, "Bookshelf"))
	local left = kit.wall("left")
	left.block("Filing", 10, 14, 0, 2, 0, 4.5, looks.LockerBody)
	for drawer = 1, 2 do
		left.item("Filing_Seam_" .. drawer, 10.2, 13.8, 2, 2.03, drawer * 1.5 - 0.03, drawer * 1.5 + 0.03, looks.Gadget)
		left.item("Filing_Handle_" .. drawer, 11.5, 12.5, 2, 2.12, drawer * 1.5 + 0.5, drawer * 1.5 + 0.62, looks.Stainless)
	end
	kit.cylinder("Clock", 0, D - 0.075, 9, 0.15, 1.6, "d", looks.Whiteboard)
	plant(kit, "Plant_1", -hw + 1.5, D - 1.5)
	plant(kit, "Plant_2", hw - 1.5, 1.5)
end

FURNISH.Recovery = function(kit)
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
	shelving(right, "TowelShelf", 9, 15, 1.4, 6, 3, looks.DeskBody, towels(right, "TowelShelf"))
	bench(kit, "Bench", -4, 4, 13, 14.4)
	plant(kit, "Plant", hw - 1.5, 1.5)
end

FURNISH.Massage = function(kit)
	local hw, D = kit.W / 2, kit.D
	paddedTable(kit, "Table_1", -6, 11, 18, looks.Padding)
	paddedTable(kit, "Table_2", 6, 11, 18, looks.Padding)
	stool(kit, "Stool_1", -3, 14)
	stool(kit, "Stool_2", 3, 14)
	local back = kit.wall("back")
	shelving(back, "TowelShelf", -6, 6, 1.5, 6, 3, looks.Wood, towels(back, "TowelShelf"))
	local left = kit.wall("left")
	for index = 0, 7 do
		left.item("Slat_" .. index + 1, 8 + index * 1.4, 8.6 + index * 1.4, 0, 0.15, 1, 9, looks.Wood)
	end
	plant(kit, "Plant_1", -hw + 1.5, D - 1.5)
	plant(kit, "Plant_2", hw - 1.5, D - 1.5)
end

FURNISH.Physio = function(kit)
	local hw, D = kit.W / 2, kit.D
	paddedTable(kit, "TreatmentTable", -6, 11, 18, looks.PaddingBlue)
	local right = kit.wall("right")
	right.item("BandRack_Bar", 7, 17, 0, 0.6, 6.5, 6.75, looks.Stainless)
	local bandLooks = { looks.PlateRed, looks.PlateBlue, looks.PlateYellow, looks.PlateGreen, looks.Gadget }
	for index = 0, 7 do
		local s = 7.6 + index * 1.2
		right.item("Band_" .. index + 1, s - 0.15, s + 0.15, 0.25, 0.4, 3, 6.5, bandLooks[index % 5 + 1])
	end
	kit.ball("ExerciseBall_1", 5, 20, 1.3, 2.6, looks.PlateBlue)
	kit.ball("ExerciseBall_2", 8.5, 22.5, 1.1, 2.2, looks.Gadget)
	desk(kit, "Desk", -hw + 0.5, -hw + 6.5, D - 3, D - 0.5)
	monitor(kit, "Monitor", -hw + 3.5, D - 1.2)
	chair(kit, "Chair", -hw + 3.5, D - 4.5, "+d")
	local back = kit.wall("back")
	local poster = back.item("Poster", -2, 6, 0, 0.1, 4, 9, looks.Whiteboard)
	writing(poster, back.out, "PHYSIO", { "Mobility", "Rehab", "Injury care" }, WHITE, INK)
	plant(kit, "Plant", hw - 1.5, 1.5)
end

FURNISH.Storage = function(kit)
	local hw = kit.W / 2
	local back = kit.wall("back")
	shelving(back, "Shelving", -hw + 0.5, hw - 0.5, 2, 8, 4, looks.Stainless, boxes(back, "Shelving"))
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
	right.block("BarHolder", 9, 15, 0, 1.2, 0, 0.6, looks.SteelBeam)
	for index = 0, 4 do
		local a, d = right.at(9.6 + index * 1.2, 0.6)
		kit.cylinder("Bar_" .. index + 1, a, d, 0.6 + 4.9, 9.8, 0.14, "up", looks.Stainless)
		kit.cylinder("Bar_" .. index + 1 .. "_Sleeve", a, d, 0.6 + 9.8 - 1.8, 3.6, 0.22, "up", looks.Stainless)
	end
	kit.item("Boxes_1", hw - 4, hw - 1, 2, 4.5, 0, 2, looks.Cardboard)
	kit.item("Boxes_2", hw - 3.8, hw - 1.4, 2.3, 4.2, 2, 3.6, looks.Cardboard)
end

-- A warm light (sauna): a PointLight in `part`.
local function warmGlow(part: BasePart, range: number, brightness: number)
	local glow = Instance.new("PointLight")
	glow.Color = looks.GlowWarm.color
	glow.Range = range
	glow.Brightness = brightness
	glow.Shadows = false
	glow.Parent = part
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
	local door, doorHalf = kit.doorA, StarterGymConfig.SwingDoorWidthStuds / 2
	local doorTop = StarterGymConfig.SwingDoorHeightStuds
	local back, front, left = kit.wall("back"), kit.wall("front"), kit.wall("left")
	local board, slat = looks.SaunaWood, looks.SaunaBench

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
	for k = 0, 5 do
		local t0 = 5.9 + k * 0.55
		back.item("Duckboard_" .. k + 1, -6, 6, t0, t0 + 0.45, 0.1, 0.22, slat)
	end

	-- The heater by the front wall: a dark stove with a basket of stones,
	-- glowing underneath, a steel heat shield behind and a wooden guard rail.
	local h0, h1 = 1.2, 3.7 -- along the left wall
	local heater = left.block("Heater", h0, h1, 0.6, 3, 0.1, 2.6, looks.Gadget)
	warmGlow(heater, 14, 1)
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

	-- Slatted wooden lamps in both back corners.
	for index, s in ipairs({ hw - 2.3, -hw + 2.3 }) do
		local lamp = "Lamp_" .. index
		local lampGlow = back.item(lamp .. "_Glow", s - 0.7, s + 0.7, 0.15, 0.5, 7.2, 8.6, looks.GlowWarm)
		warmGlow(lampGlow, 16, 0.8)
		back.item(lamp .. "_Top", s - 0.9, s + 0.9, 0.15, 0.75, 8.8, 8.95, slat)
		back.item(lamp .. "_Bottom", s - 0.9, s + 0.9, 0.15, 0.75, 6.85, 7, slat)
		for k = 0, 3 do
			local s0 = s - 0.8 + k * 0.45
			back.item(lamp .. "_Slat_" .. k + 1, s0, s0 + 0.15, 0.6, 0.72, 7, 8.8, slat)
		end
	end

	-- A bucket with a ladle on the lower bench, a thermometer, towels.
	local ba, bd = -4, D - 4.4
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
	left when it moved upstairs). A back bar with blenders under a menu board
	and a drinks fridge, a serving counter with shakers, shelves of
	supplement tubs on both side walls, two high tables with stools.
]]
FURNISH.SupplementBar = function(kit)
	local hw = kit.W / 2
	local back = kit.wall("back")
	back.block("BackBar", -hw + 1, 6, 0, 2, 0, 3.4, looks.DeskBody)
	back.block("BackBar_Top", -hw + 1, 6, 0, 2.1, 3.4, 3.6, looks.DeskWork)
	for index, s in ipairs({ -9, -5.5, -2 }) do
		local blender = "Blender_" .. index
		back.item(blender .. "_Base", s - 0.6, s + 0.6, 0.4, 1.6, 3.6, 4.2, looks.Gadget)
		local a, d = back.at(s, 1)
		kit.cylinder(blender .. "_Jug", a, d, 4.95, 1.5, 0.8, "up", looks.Glass)
		kit.cylinder(blender .. "_Lid", a, d, 5.77, 0.14, 0.86, "up", looks.Gadget)
	end
	local menu = back.item("MenuBoard", -hw + 1, 6, 0, 0.15, 6, 10, looks.SignPanel)
	writing(menu, back.out, "SUPPLEMENT BAR", { "Whey shake ...... 5", "Creatine ...... 2", "Pre-workout ...... 4",
		"Electrolytes ...... 2" }, looks.SignPanel.color, WHITE)
	drinksFridge(kit, back, "Fridge", 8, hw - 0.6)
	-- The serving counter with shakers, staff behind it.
	back.block("Counter", -10, 8, 5.5, 7, 0, 3.6, looks.DeskBody)
	back.block("Counter_Top", -10.2, 8.2, 5.4, 7.2, 3.6, 3.8, looks.DeskWork)
	back.item("Counter_Stripe", -10, 8, 7, 7.03, 2.6, 2.9, looks.PlateRed)
	for index = 0, 5 do
		local a, d = back.at(-8.5 + index * 3, 6.25)
		kit.cylinder("Shaker_" .. index + 1, a, d, 4.25, 0.9, 0.5, "up", if index % 2 == 0 then looks.PlateRed else looks.Gadget)
	end
	-- Shelves of tubs on both side walls.
	for _, which in ipairs({ "left", "right" }) do
		local wall = kit.wall(which)
		local name = "TubShelf_" .. which
		shelving(wall, name, 8, 18, 1.4, 7, 4, looks.DeskBody, tubs(kit, wall, name))
	end
	cafeTable(kit, "Table_1", -6.5, 10)
	cafeTable(kit, "Table_2", 6.5, 10)
	plant(kit, "Plant_1", -hw + 1.5, 1.5)
	plant(kit, "Plant_2", hw - 1.5, 1.5)
end

FURNISH.Coach = function(kit)
	local hw, D = kit.W / 2, kit.D
	local back = kit.wall("back")
	back.item("Whiteboard_Frame", -7.15, 7.15, 0, 0.12, 3.35, 8.65, looks.Stainless)
	local board = back.item("Whiteboard", -7, 7, 0, 0.15, 3.5, 8.5, looks.Whiteboard)
	back.item("Whiteboard_Tray", -4, 4, 0.15, 0.5, 3.3, 3.45, looks.Stainless)
	writing(board, back.out, "TRAINING PLAN", { "Mon   Squat 5x5 @ 75%", "Wed   Bench 5x5 @ 75%",
		"Fri   Deadlift 3x5 @ 80%", "Next meet: 6 weeks" }, WHITE, INK)
	for index, a in ipairs({ -6, -2, 2, 6 }) do
		chair(kit, "Chair_" .. index, a, D - 9, "+d")
	end
	desk(kit, "Desk", hw - 3.5, hw - 0.5, 10, 16)
	kit.item("Laptop", hw - 2.8, hw - 1.4, 12, 14, 3, 3.08, looks.Gadget)
	kit.item("Laptop_Screen", hw - 1.4, hw - 1.3, 12, 14, 3.08, 4.3, looks.Gadget)
	chair(kit, "DeskChair", hw - 5, 13, "+a")
	plant(kit, "Plant_1", -hw + 1.5, D - 1.5)
	plant(kit, "Plant_2", -hw + 1.5, 1.5)
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
	back.block("Podium", -7.5, 7.5, 1.5, 6, 0, 0.3, looks.Gadget)
	back.item("Podium_Glow", -7.5, 7.5, 6, 6.06, 0.08, 0.2, looks.GlowRed)
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
		local spot = kit.item("Spotlight_" .. index, a - 0.3, a + 0.3, d - 1.6, d - 1, 11.9, 12.4, looks.Gadget)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 14
		light.Brightness = 2
		light.Angle = 60
		light.Color = StarterGymConfig.LightColor
		light.Shadows = false
		light.Parent = spot
	end
	local _, spotD = back.at(0, 3.75 + 1.3)
	kit.item("Spotlight_Track", -6, 6, spotD - 0.1, spotD + 0.1, 12.4, 12.55, looks.Gadget)

	-- The slatwall on the left: hanging wraps on hooks, knee sleeves in pairs
	-- on a ledge, rolled wraps on a lower ledge.
	left.item("Slatwall", 6, 24, 0.15, 0.35, 0.5, 9.5, dark)
	for k = 0, 14 do
		local y = 0.8 + k * 0.6
		left.item("Slatwall_Groove_" .. k + 1, 6, 24, 0.35, 0.37, y, y + 0.06, looks.Stainless)
	end
	for index = 0, 5 do
		local s = 8 + index * 2.8
		left.item("Hook_" .. index + 1, s - 0.05, s + 0.05, 0.37, 0.95, 8.4, 8.5, looks.Stainless)
		local a, d = left.at(s, 0.6)
		showGear("WristWrapHanging", "WristWrapHanging_" .. index + 1, a, d, 8.45, "+a")
	end
	left.block("Ledge_Sleeves", 7, 23, 0.37, 1.3, 4, 4.15, dark)
	for pair, s in ipairs({ 9, 13, 17, 21 }) do
		for side, offset in ipairs({ -0.4, 0.4 }) do
			local a, d = left.at(s + offset, 0.85)
			showGear("KneeSleeve", string.format("KneeSleeve_%d_%d", pair, side), a, d, 4.15, "+a")
		end
	end
	left.block("Ledge_Wraps", 7, 23, 0.37, 1.3, 2, 2.15, dark)
	for index = 0, 5 do
		local a, d = left.at(8.5 + index * 2.8, 0.85)
		showGear("WristWrap", "WristWrap_" .. index + 1, a, d, 2.15, "+a")
	end

	-- The belt shelf on the right: lever belts on the upper boards, folded tees below.
	shelving(right, "BeltShelf", 8, 20, 1.5, 6.5, 3, dark)
	for level, y in ipairs({ 0.15 + 6.5 / 3 + 0.15, 0.15 + 2 * 6.5 / 3 + 0.15 }) do
		for index, s in ipairs({ 10, 14, 18 }) do
			local a, d = right.at(s, 0.8)
			showGear("LeverBelt", string.format("LeverBelt_%d_%d", level, index), a, d, y, "-a")
		end
	end
	for index, s in ipairs({ 10, 14, 18 }) do
		for fold = 0, 3 do
			right.item(string.format("Tee_Stack_%d_%d", index, fold + 1), s - 0.7, s + 0.7, 0.3, 1.3, 0.3 + fold * 0.25,
				0.53 + fold * 0.25, if fold % 2 == 0 then looks.ShirtBlack else looks.ShirtRed)
		end
	end

	-- The counter by the door: black with the logo on its front, a till on top.
	local counter = kit.block("Counter", 5, 11.5, 8, 10, 0, 3.6, dark)
	shopLogo(counter, kit.toward("-d"))
	kit.block("Counter_Top", 4.9, 11.6, 7.9, 10.1, 3.6, 3.8, looks.Gadget)
	kit.item("Counter_Edge", 4.9, 11.6, 7.84, 7.9, 3.6, 3.8, looks.GlowRed)
	kit.item("Till", 9.5, 11, 8.6, 9.6, 3.8, 4.4, looks.Gadget)
	kit.item("Till_Screen", 9.6, 10.9, 8.55, 8.6, 4.4, 5.2, looks.Gadget)
	kit.item("CardReader", 6, 6.6, 8.2, 8.8, 3.8, 3.95, looks.Gadget)

	-- A table of folded tees.
	kit.block("Table", -8, -2.5, 11, 14, 0, 2.6, dark)
	for i = 0, 2 do
		for j = 0, 1 do
			local a0, d0 = -7.6 + i * 1.8, 11.3 + j * 1.4
			for fold = 0, 2 do
				kit.item(string.format("Table_Tee_%d_%d_%d", i + 1, j + 1, fold + 1), a0, a0 + 1.4, d0, d0 + 1.2,
					2.6 + fold * 0.25, 2.83 + fold * 0.25, if (i + j + fold) % 3 == 0 then looks.ShirtRed else looks.ShirtBlack)
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

	local doorSpots: { Vector3 } = {}
	for _, room in ipairs(rooms:GetChildren()) do
		local spot = room:GetAttribute("DoorCentre")
		if typeof(spot) == "Vector3" then
			table.insert(doorSpots, spot)
		end
	end

	local furnished = 0
	for _, room in ipairs(rooms:GetChildren()) do
		local name = string.sub(room.Name, 6) -- without "Room_"
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

return RoomProps
