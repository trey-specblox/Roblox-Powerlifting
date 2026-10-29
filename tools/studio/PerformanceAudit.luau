--[[
	PerformanceAudit  (Studio Command Bar, READ-ONLY)

	WHAT IT DOES: counts what the running game puts in the world and prints a
	report: parts and 3D models, unique meshes, shadow casters, lights, world
	screens, and the heaviest rooms, each line marked OK or WARN against the
	budgets below (user 2026-10-28: "warn me ... if optimalization will be a
	problem ... optimize everything"). It changes NOTHING.

	HOW TO USE: press Play in Studio (the gym is built when the game starts),
	then paste this whole file into the Command Bar (View -> Command Bar) of the
	SERVER view and press Enter. Read the report in the Output window.

	It cannot measure frame rate on a phone: play the published game on a phone
	now and then for that.
]]

local BUDGET = {
	parts = 10000, -- every part in the world
	uniqueMeshes = 600, -- different 3D models (copies of one model are cheap)
	shadowCasters = 3000, -- parts that cast shadows
	lights = 200, -- point, surface and spot lights
	worldScreens = 120, -- SurfaceGuis and BillboardGuis in the world
	roomParts = 600, -- parts in one furnished room
}

local counts = { parts = 0, meshParts = 0, shadowCasters = 0, lights = 0, shadowLights = 0, worldScreens = 0,
	solidDecor = 0, preciseCollision = 0 }
local meshIds = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") then
		counts.parts += 1
		if d.CastShadow and d.Transparency < 1 then
			counts.shadowCasters += 1
		end
		if d:GetAttribute("Decor") and d.CanCollide then
			counts.solidDecor += 1
		end
		if d:IsA("MeshPart") then
			counts.meshParts += 1
			meshIds[d.MeshId] = true
			if d.CanCollide and d.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition then
				counts.preciseCollision += 1
			end
		end
	elseif d:IsA("Light") then
		counts.lights += 1
		if d.Shadows then
			counts.shadowLights += 1
		end
	elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
		counts.worldScreens += 1
	end
end
local uniqueMeshes = 0
for _ in pairs(meshIds) do
	uniqueMeshes += 1
end

local warnings = 0
local function line(label: string, value: number, budget: number?)
	local over = budget ~= nil and value > budget
	if over then
		warnings += 1
	end
	print(string.format("  %-4s %-28s %6d%s", if over then "WARN" else "OK", label, value,
		if budget then string.format("   (budget %d)", budget) else ""))
end

print("[PerformanceAudit] ---------------------------------------------")
line("parts", counts.parts, BUDGET.parts)
line("3D model parts (MeshParts)", counts.meshParts)
line("unique meshes", uniqueMeshes, BUDGET.uniqueMeshes)
line("shadow casters", counts.shadowCasters, BUDGET.shadowCasters)
line("lights", counts.lights, BUDGET.lights)
line("lights with shadows", counts.shadowLights, 0)
line("world screens", counts.worldScreens, BUDGET.worldScreens)
line("solid decor (should be 0)", counts.solidDecor, 0)
line("precise-collision meshes", counts.preciseCollision, 0)

-- The heaviest furnished rooms.
local gym = workspace:FindFirstChild("StarterGym")
local props = gym and gym:FindFirstChild("Props")
if props then
	local rooms = {}
	for _, room in ipairs(props:GetChildren()) do
		local n = 0
		for _, d in ipairs(room:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		table.insert(rooms, { name = room.Name, parts = n })
	end
	table.sort(rooms, function(a, b)
		return a.parts > b.parts
	end)
	print("  heaviest rooms:")
	for index = 1, math.min(6, #rooms) do
		line("  " .. rooms[index].name, rooms[index].parts, BUDGET.roomParts)
	end
end
print(string.format("[PerformanceAudit] %s (%d warning%s); nothing was changed",
	if warnings == 0 then "ALL OK" else "SEE WARN LINES", warnings, if warnings == 1 then "" else "s"))
