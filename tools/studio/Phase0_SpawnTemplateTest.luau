--[[
	Phase0_SpawnTemplateTest  (Step 6D.2 Phase 0, TEMPORARY Command Bar script)

	NOT game code. Rojo does not sync tools/studio/. Paste the whole file into
	Studio's Command Bar in EDIT mode (not Play) and press Enter.

	What it does:
	  1. Checks ServerStorage.RackTemplates.PowerRack_01 is a Model holding exactly
	     the 21 expected MeshParts (names, rbxassetid MeshIds, sizes), with no
	     tags, no StationId and nothing else inside.
	  2. Checks exactly one Workspace.PowerRack_01 (the working rack) exists, and
	     that nothing called TemplateTest exists anywhere in Workspace.
	  3. Picks a spot 12 studs to the +X side of the working rack, on the same
	     floor height, and checks no other part is in that space.
	  4. Clones the template, names the clone TemplateTest, anchors every part,
	     moves it to that spot (move only, no rotation), marks it with the
	     attribute TemporaryTestModel, and only then parents it to Workspace.

	It READS the template and the working rack and never changes them. It adds
	no tag, StationId, prompt or sign. If any check fails it prints why and
	changes nothing. The spawn is one undo step (Ctrl+Z).
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local TEST_NAME = "TemplateTest"
local MARKER_ATTRIBUTE = "TemporaryTestModel"
local MARKER_VALUE = "Step6D2_Phase0"
local SIDE_OFFSET = Vector3.new(12, 0, 0) -- from the working rack's centre
local SIZE_TOLERANCE = 0.01
local EXTENTS_TOLERANCE = 0.02

-- Sizes from art/roblox/PowerRack_01.rbxmx (the Blender build, 1 unit = 1 stud).
local EXPECTED_SIZES = {
	Upright_FrontLeft = Vector3.new(0.3, 8, 0.3),
	Upright_FrontRight = Vector3.new(0.3, 8, 0.3),
	Upright_BackLeft = Vector3.new(0.3, 8, 0.3),
	Upright_BackRight = Vector3.new(0.3, 8, 0.3),
	Crossbar_Front = Vector3.new(5.4, 0.3, 0.3),
	Crossbar_Back = Vector3.new(5.4, 0.3, 0.3),
	Crossbar_Left = Vector3.new(0.3, 0.3, 5.4),
	Crossbar_Right = Vector3.new(0.3, 0.3, 5.4),
	BaseRail_Left = Vector3.new(0.3, 0.25, 5.4),
	BaseRail_Right = Vector3.new(0.3, 0.25, 5.4),
	BaseRail_Back = Vector3.new(5.4, 0.25, 0.3),
	JCup_Left = Vector3.new(0.34, 0.6, 0.34),
	JCup_Right = Vector3.new(0.34, 0.6, 0.34),
	JCupLiner_Left = Vector3.new(0.3, 0.28, 0.21),
	JCupLiner_Right = Vector3.new(0.3, 0.28, 0.21),
	JCupPin_Left = Vector3.new(0.07, 0.07, 0.04),
	JCupPin_Right = Vector3.new(0.07, 0.07, 0.04),
	SafetyBar_Left = Vector3.new(0.1, 0.1, 6.4),
	SafetyBar_Right = Vector3.new(0.1, 0.1, 6.4),
	SafetyPins = Vector3.new(5.75, 0.16, 6.27),
	FrameBolts = Vector3.new(6.06, 7.885, 6.06),
}
local EXPECTED_COUNT = 21

local function fmtV(v: Vector3): string
	return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end

local function closeTo(a: Vector3, b: Vector3, tolerance: number): boolean
	return math.abs(a.X - b.X) <= tolerance and math.abs(a.Y - b.Y) <= tolerance and math.abs(a.Z - b.Z) <= tolerance
end

-- World-axis box around every BasePart in a model (exact for rotated parts too).
local function worldBounds(model: Model): (Vector3, Vector3)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local cf, half = d.CFrame, d.Size / 2
			local r = Vector3.new(
				math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z,
				math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z,
				math.abs(cf.RightVector.Z) * half.X + math.abs(cf.UpVector.Z) * half.Y + math.abs(cf.LookVector.Z) * half.Z
			)
			minV = minV:Min(cf.Position - r)
			maxV = maxV:Max(cf.Position + r)
		end
	end
	return minV, maxV
end

local function run(): (boolean, string)
	-- 0. Edit mode only.
	if RunService:IsRunning() then
		return false, "Studio is in Play/Run mode. Stop the test and run this in Edit mode."
	end

	-- 1. Template.
	local folder = ServerStorage:FindFirstChild("RackTemplates")
	if not folder then
		return false, "ServerStorage.RackTemplates not found (is Rojo connected?)"
	end
	local templates = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child.Name == "PowerRack_01" then
			table.insert(templates, child)
		end
	end
	if #templates ~= 1 then
		return false, string.format("expected exactly 1 RackTemplates.PowerRack_01, found %d", #templates)
	end
	local template = templates[1]
	if not template:IsA("Model") then
		return false, "RackTemplates.PowerRack_01 is a " .. template.ClassName .. ", not a Model"
	end
	if #CollectionService:GetTags(template) > 0 then
		return false, "the template has tags: " .. table.concat(CollectionService:GetTags(template), ", ")
	end
	if template:GetAttribute("StationId") ~= nil then
		return false, "the template has a StationId attribute"
	end

	local descendants = template:GetDescendants()
	if #descendants ~= EXPECTED_COUNT then
		return false, string.format("the template has %d descendants, expected exactly %d MeshParts", #descendants, EXPECTED_COUNT)
	end
	local seen = {}
	local meshIdsOk = 0
	for _, d in ipairs(descendants) do
		if not d:IsA("MeshPart") then
			return false, string.format("unexpected %s '%s' in the template", d.ClassName, d.Name)
		end
		if d.Parent ~= template then
			return false, string.format("'%s' is nested inside '%s', expected a direct child", d.Name, d.Parent.Name)
		end
		local expectedSize = EXPECTED_SIZES[d.Name]
		if expectedSize == nil then
			return false, string.format("unexpected MeshPart name '%s'", d.Name)
		end
		if seen[d.Name] then
			return false, string.format("duplicate MeshPart name '%s'", d.Name)
		end
		seen[d.Name] = true
		if not string.match(d.MeshId, "^rbxassetid://%d+$") then
			return false, string.format("'%s' has an invalid MeshId: '%s'", d.Name, d.MeshId)
		end
		meshIdsOk += 1
		if not closeTo(d.Size, expectedSize, SIZE_TOLERANCE) then
			return false, string.format("'%s' size %s, expected %s", d.Name, fmtV(d.Size), fmtV(expectedSize))
		end
		if #CollectionService:GetTags(d) > 0 or d:GetAttribute("StationId") ~= nil then
			return false, string.format("'%s' has tags or a StationId", d.Name)
		end
	end

	-- 2. Working rack (read only) and no earlier test model.
	local racks = {}
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "PowerRack_01" then
			table.insert(racks, child)
		end
	end
	if #racks ~= 1 or not racks[1]:IsA("Model") then
		return false, string.format("expected exactly 1 Workspace.PowerRack_01 Model, found %d", #racks)
	end
	local workingRack = racks[1] :: Model
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == TEST_NAME then
			return false, d:GetFullName() .. " already exists. Run the cleanup script first."
		end
	end

	-- Template and working rack must have the same overall size.
	local tMin, tMax = worldBounds(template)
	local rMin, rMax = worldBounds(workingRack)
	local templateExtents, rackExtents = tMax - tMin, rMax - rMin
	if not closeTo(templateExtents, rackExtents, EXTENTS_TOLERANCE) then
		return false, string.format("template extents %s differ from the working rack %s",
			fmtV(templateExtents), fmtV(rackExtents))
	end

	-- 3. Target spot: same floor height as the working rack, 12 studs to +X.
	local rackCentre = (rMin + rMax) / 2
	local targetBottomCentre = Vector3.new(rackCentre.X, rMin.Y, rackCentre.Z) + SIDE_OFFSET
	local targetCentre = targetBottomCentre + Vector3.new(0, templateExtents.Y / 2, 0)

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { workspace.Terrain }
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		table.insert(exclude, baseplate)
	end
	overlap.FilterDescendantsInstances = exclude
	-- 1 stud of clearance each side, lifted 0.05 so the floor itself is not counted.
	local checkSize = templateExtents + Vector3.new(2, -0.1, 2)
	local blockers = workspace:GetPartBoundsInBox(CFrame.new(targetCentre + Vector3.new(0, 0.05, 0)), checkSize, overlap)
	if #blockers > 0 then
		local names = {}
		for i = 1, math.min(#blockers, 5) do
			table.insert(names, blockers[i]:GetFullName())
		end
		return false, string.format("the test spot %s is not clear: %s", fmtV(targetBottomCentre), table.concat(names, ", "))
	end

	-- 4. Clone, anchor, move, then parent. Template and working rack untouched.
	local recording = ChangeHistoryService:TryBeginRecording("Spawn TemplateTest")
	local clone = template:Clone()
	clone.Name = TEST_NAME
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local cMin, cMax = worldBounds(clone)
	local cloneBottomCentre = Vector3.new((cMin.X + cMax.X) / 2, cMin.Y, (cMin.Z + cMax.Z) / 2)
	clone:PivotTo(clone:GetPivot() + (targetBottomCentre - cloneBottomCentre))
	clone:SetAttribute(MARKER_ATTRIBUTE, MARKER_VALUE)
	clone.Parent = workspace
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	-- Report from the placed clone.
	local pMin, pMax = worldBounds(clone)
	local count = 0
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("MeshPart") then
			count += 1
		end
	end
	return true, string.format(
		"Workspace.%s created.\n  MeshParts: %d\n  MeshIds present: %s (%d/%d)\n  Overall size (W x H x D): %.2f x %.2f x %.2f studs (working rack %.2f x %.2f x %.2f)\n  Floor centre: %s (working rack floor centre %s)\n  Template and Workspace.PowerRack_01 were not changed.",
		TEST_NAME, count, tostring(meshIdsOk == EXPECTED_COUNT), meshIdsOk, EXPECTED_COUNT,
		pMax.X - pMin.X, pMax.Y - pMin.Y, pMax.Z - pMin.Z, rackExtents.X, rackExtents.Y, rackExtents.Z,
		fmtV(Vector3.new((pMin.X + pMax.X) / 2, pMin.Y, (pMin.Z + pMax.Z) / 2)),
		fmtV(Vector3.new(rackCentre.X, rMin.Y, rackCentre.Z))
	)
end

local ok, success, message = pcall(run)
if not ok then
	warn("[TemplateTest] SCRIPT ERROR: " .. tostring(success)
		.. "\n  Check Workspace for a TemplateTest and tell Claude before running anything else.")
elseif success then
	print("[TemplateTest] SUCCESS. " .. message)
else
	warn("[TemplateTest] REFUSED, nothing was changed: " .. message)
end
