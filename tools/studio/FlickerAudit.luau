--[[
	FlickerAudit  (Studio, in a PLAY TEST, on the SERVER; READ-ONLY: it changes nothing)

	WHY: the user, 2026-11-22: "checking if any building or model does this thing where it flashes two different
	colors, or overlapping builds. This makes the game look not well made." Two surfaces lying in the same plane and
	facing the same way are drawn through each other, and the picture flickers between their two colours as the
	camera moves ("z-fighting"). The map is built by code when the game starts, so this has to run in a play test.

	WHAT IT FINDS: pairs of visible parts that have a face in the same plane (within PLANE studs), facing the same
	way, overlapping by at least MIN_AREA square studs, and that do not look the same (colour, material or
	transparency differ: two identical surfaces can't be seen flickering). Pairs are grouped by the two parts' names
	and listed with a place to go and look.

	THE THREE KINDS OF LINE (second version, 2026-11-22):
		- SAME PLANE: the two faces are less than SAME studs apart and nothing solid covers them. These flicker.
		- THIN LAYER: one face stands 0.01 to 0.03 studs in front of the other (a paint layer, a groove, a line on a
		  floor). Fine from near; from very far away it can shimmer. The project's rule is 0.05 proud for new work.
		- HIDDEN: the shared faces lie inside or under another solid, opaque block (two bottoms resting on the same
		  floor, a wall's top under the slab above it). Nobody can see them; counted, and listed only with
		  SHOW_HIDDEN. The test takes sample points just outside the shared faces and asks whether each one is inside
		  another opaque block; a mesh never counts as cover (its real surface can't be read).
		- IN A GAP: the shared faces look into a closed gap less than GAP_DEEP studs deep with an opaque block on
		  its far side (the BACKS of a room's wall boards, in the hollow between them and the building's wall).
		  A camera can't get in there; listed after the others so each kind can be looked at once from the side.

	HOW FAR TO TRUST IT:
		- "block-block" lines are EXACT: both parts are plain blocks, so their faces are their real surfaces.
		- "block-mesh" and "mesh-block" lines are LIKELY: the mesh's bounding box face often is a real flat surface
		  (a shelf's back, a desk's foot), but not always. Go and look.
		- "mesh-mesh" lines are only HINTS, and it MISSES flicker between surfaces INSIDE a mesh's bounding box (the
		  W Chews staff door's frame against the wall's cut edge was one: found by eye, not by this). A script can't
		  read a mesh's triangles unless the experience's "Allow Mesh / Image APIs" security setting is on (the user's
		  to change); with it on, this could be made exact.
		- Crowd figures overlap each other on purpose and fill the mesh-mesh list: skip those lines.

	HOW TO RUN: start a play test, switch the Command Bar to the server, paste, run. It takes a few seconds (it
	waits between chunks so Studio doesn't freeze) and prints the list; the full results stay in shared.FlickerAudit
	(and _G.FlickerAudit).
]]

local PLANE = 0.03 -- studs between two faces that still flicker at a distance
local SAME = 0.005 -- studs: closer than this is the same plane (flickers from anywhere)
local MIN_AREA = 0.4 -- square studs of overlap worth reporting
local CELL = 24 -- studs: the grid that keeps the number of pairs down
local SHOW = 200 -- lines printed (mesh-against-mesh lines are only counted unless SHOW_MESH_MESH)
local SHOW_HIDDEN = false -- list the hidden groups too
local SHOW_MESH_MESH = false -- list the mesh-against-mesh hints too
local COVER_OUT = 0.012 -- studs outside the shared faces where a covering block is looked for
local SAMPLES = 5 -- sample points each way across the shared rectangle
local GAP_DEEP = 0.75 -- studs: shared faces with an opaque block closer than this in front of them are "in a gap"

local function kindOf(part: BasePart): string?
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Block then
			return "block"
		elseif part.Shape == Enum.PartType.Cylinder then
			return "cyl" -- (only its two flat ends)
		end
		return nil
	elseif part:IsA("MeshPart") or part:IsA("UnionOperation") then
		return "mesh"
	end
	return nil
end

local parts = {}
for _, item in ipairs(workspace:GetDescendants()) do
	if item:IsA("BasePart") and item.Transparency < 0.98 and not item:IsA("Terrain") then
		local model = item:FindFirstAncestorOfClass("Model")
		local kind = kindOf(item)
		if kind and not (model and model:FindFirstChildOfClass("Humanoid")) then
			local cf, half = item.CFrame, item.Size / 2
			local axes = { cf.RightVector, cf.UpVector, -cf.LookVector }
			local halves = { half.X, half.Y, half.Z }
			local faces = {}
			for a = 1, 3 do
				if kind ~= "cyl" or a == 1 then
					for sign = -1, 1, 2 do
						local u, v = a % 3 + 1, (a + 1) % 3 + 1
						table.insert(faces, { c = cf.Position + axes[a] * sign * halves[a], n = axes[a] * sign, u = axes[u], v = axes[v],
							hu = halves[u], hv = halves[v] })
					end
				end
			end
			table.insert(parts, { p = item, kind = kind, faces = faces, r = item.Size.Magnitude / 2, pos = cf.Position, cf = cf,
				half = half, solid = kind == "block" and item.Transparency < 0.02 })
		end
	end
end

local function cellKey(x: number, y: number, z: number): number
	return x * 73856093 + y * 19349663 + z * 83492791
end

local grid = {}
for index, entry in ipairs(parts) do
	local low, high = entry.pos - Vector3.one * entry.r, entry.pos + Vector3.one * entry.r
	for x = math.floor(low.X / CELL), math.floor(high.X / CELL) do
		for y = math.floor(low.Y / CELL), math.floor(high.Y / CELL) do
			for z = math.floor(low.Z / CELL), math.floor(high.Z / CELL) do
				local key = cellKey(x, y, z)
				local cell = grid[key]
				if cell == nil then
					cell = {}
					grid[key] = cell
				end
				cell[#cell + 1] = index
			end
		end
	end
	if index % 2000 == 0 then
		task.wait()
	end
end

-- The rectangle of face b that lies over face a (b boxed in a's own two directions): its area and its edges
-- along a.u and a.v, measured from a's centre.
local function overlap(a, b): (number, number, number, number, number)
	local d = b.c - a.c
	local cu, cv = d:Dot(a.u), d:Dot(a.v)
	local eu = math.abs(b.u:Dot(a.u)) * b.hu + math.abs(b.v:Dot(a.u)) * b.hv
	local ev = math.abs(b.u:Dot(a.v)) * b.hu + math.abs(b.v:Dot(a.v)) * b.hv
	local u0, u1 = math.max(-a.hu, cu - eu), math.min(a.hu, cu + eu)
	local v0, v1 = math.max(-a.hv, cv - ev), math.min(a.hv, cv + ev)
	local w, h = u1 - u0, v1 - v0
	return if w > 0 and h > 0 then w * h else 0, u0, u1, v0, v1
end

-- Is this point inside an opaque block other than the two given ones?
local function covered(point: Vector3, ea, eb): boolean
	local cell = grid[cellKey(math.floor(point.X / CELL), math.floor(point.Y / CELL), math.floor(point.Z / CELL))]
	if cell == nil then
		return false
	end
	for _, index in ipairs(cell) do
		local entry = parts[index]
		if entry.solid and entry ~= ea and entry ~= eb then
			local l = entry.cf:PointToObjectSpace(point)
			if math.abs(l.X) < entry.half.X - 0.001 and math.abs(l.Y) < entry.half.Y - 0.001 and math.abs(l.Z) < entry.half.Z - 0.001 then
				return true
			end
		end
	end
	return false
end

-- Can the shared faces be seen? 0 = yes; 1 = no, they look into a closed gap (an opaque block stands less than
-- GAP_DEEP in front of every sample point); 2 = no, every sample point just outside them is inside another
-- opaque block.
local function outOfSight(fa, fb, ea, eb, u0: number, u1: number, v0: number, v1: number): number
	local out = math.max(0, (fb.c - fa.c):Dot(fa.n)) + COVER_OUT -- from a's plane, past whichever face is in front
	local level = 2
	for i = 1, SAMPLES do
		for j = 1, SAMPLES do
			local u = u0 + (u1 - u0) * (i - 0.5) / SAMPLES
			local v = v0 + (v1 - v0) * (j - 0.5) / SAMPLES
			local point = fa.c + fa.u * u + fa.v * v + fa.n * out
			if not covered(point, ea, eb) then
				local closed = false
				for step = 0.1, GAP_DEEP, 0.1 do
					if covered(point + fa.n * step, ea, eb) then
						closed = true
						break
					end
				end
				if not closed then
					return 0
				end
				level = 1
			end
		end
	end
	return level
end

local seen, found, checked = {}, {}, 0
for _, cell in pairs(grid) do
	for i = 1, #cell do
		local ia = cell[i]
		local ea = parts[ia]
		for j = i + 1, #cell do
			local ib = cell[j]
			local key = if ia < ib then ia * 100000 + ib else ib * 100000 + ia
			if not seen[key] then
				seen[key] = true
				local eb = parts[ib]
				local alike = ea.p.Color == eb.p.Color and ea.p.Material == eb.p.Material and ea.p.Transparency == eb.p.Transparency
				if not alike and (ea.pos - eb.pos).Magnitude < ea.r + eb.r then
					local meshMesh = ea.kind == "mesh" and eb.kind == "mesh"
					-- The biggest shared rectangle that can be seen; failing that, the biggest one in a gap; failing
					-- that, the biggest hidden one (sight 0, 1, 2 as outOfSight gives them).
					local best = {}
					for _, fa in ipairs(ea.faces) do
						for _, fb in ipairs(eb.faces) do
							local gap = math.abs((fb.c - fa.c):Dot(fa.n))
							if fa.n:Dot(fb.n) > 0.9995 and gap < PLANE then
								local area, u0, u1, v0, v1 = overlap(fa, fb)
								if area >= MIN_AREA then
									local sight = if meshMesh then 0 else outOfSight(fa, fb, ea, eb, u0, u1, v0, v1)
									if best[sight] == nil or area > best[sight].area then
										best[sight] = { a = ea, b = eb, area = area, gap = gap, n = fa.n, sight = sight,
											at = fa.c + fa.u * (u0 + u1) / 2 + fa.v * (v0 + v1) / 2 }
									end
								end
							end
						end
					end
					local hit = best[0] or best[1] or best[2]
					if hit then
						table.insert(found, hit)
					end
				end
			end
		end
		checked += 1
		if checked % 1500 == 0 then
			task.wait()
		end
	end
end

local function owner(part: Instance): string
	local at = part
	while at.Parent and at.Parent ~= workspace do
		at = at.Parent
	end
	return at.Name
end

-- 1 = same plane, 2 = thin layer, 3 = in a gap, 4 = hidden; block-against-block before block-against-mesh before
-- mesh-against-mesh.
local groups = {}
for _, hit in ipairs(found) do
	local an, bn = hit.a.p.Name:gsub("%d+", "#"), hit.b.p.Name:gsub("%d+", "#")
	local kinds = hit.a.kind .. "-" .. hit.b.kind
	if an > bn then
		an, bn = bn, an
	end
	local tier = if hit.sight == 2 then 4 elseif hit.sight == 1 then 3 elseif hit.gap < SAME then 1 else 2
	local trust = if kinds == "mesh-mesh" then 3 elseif string.find(kinds, "mesh") then 2 else 1
	local key = string.format("%s | %s + %s | %s | facing %.0f,%.0f,%.0f", owner(hit.a.p), an, bn, kinds, hit.n.X, hit.n.Y, hit.n.Z)
	local group = groups[key .. tier]
	if group == nil then
		group = { key = key, n = 0, area = 0, max = 0, sample = hit, tier = tier, trust = trust }
		groups[key .. tier] = group
	end
	group.n += 1
	group.area += hit.area
	if hit.area > group.max then
		group.max = hit.area
		group.sample = hit
	end
end
local list = {}
local counts = {}
for _, group in pairs(groups) do
	table.insert(list, group)
	local slot = group.trust * 10 + group.tier
	counts[slot] = (counts[slot] or 0) + 1
end
table.sort(list, function(x, y)
	if x.trust ~= y.trust then
		return x.trust < y.trust
	elseif x.tier ~= y.tier then
		return x.tier < y.tier
	end
	return x.area > y.area
end)
local result = { found = found, list = list, counts = counts }
_G.FlickerAudit = result
shared.FlickerAudit = result

local function count(trust: number, tier: number): number
	return counts[trust * 10 + tier] or 0
end
local tierNames = { "SAME PLANE", "thin layer", "in a gap", "hidden" }
local lines = {
	string.format("[FlickerAudit] %d parts looked at, %d overlapping pairs in %d groups", #parts, #found, #list),
	string.format("  block against block (exact):  %d SAME PLANE, %d thin layer, %d in a gap, %d hidden", count(1, 1), count(1, 2),
		count(1, 3), count(1, 4)),
	string.format("  block against mesh (likely):  %d SAME PLANE, %d thin layer, %d in a gap, %d hidden", count(2, 1), count(2, 2),
		count(2, 3), count(2, 4)),
	string.format("  mesh against mesh (hints):    %d groups", count(3, 1) + count(3, 2)),
}
local shown = 0
for _, group in ipairs(list) do
	if shown < SHOW and (SHOW_HIDDEN or group.tier ~= 4) and (SHOW_MESH_MESH or group.trust ~= 3) then
		shown += 1
		local at = group.sample.at
		table.insert(lines, string.format("%3d  %-10s pairs %-4d area %-8.0f biggest %-7.1f gap %.3f  %s  @ %.1f, %.1f, %.1f", shown,
			tierNames[group.tier], group.n, group.area, group.max, group.sample.gap, group.key, at.X, at.Y, at.Z))
	end
end
local report = table.concat(lines, "\n")
print(report)
return report
