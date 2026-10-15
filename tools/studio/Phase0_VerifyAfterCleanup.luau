--[[
	Phase0_VerifyAfterCleanup  (Step 6D.2 Phase 0, TEMPORARY Command Bar script)

	READ-ONLY. Changes nothing. Run in Studio EDIT mode after
	Phase0_CleanupTemplateTest to confirm:
	  - no TemplateTest is left anywhere in Workspace,
	  - Workspace.PowerRack_01 (working rack) is still there with its 21 MeshParts,
	  - ServerStorage.RackTemplates.PowerRack_01 (template) is still there with
	    its 21 MeshParts, no tags and no StationId.
]]

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local results = {}
local allPassed = true

local function check(passed: boolean, label: string)
	if not passed then
		allPassed = false
	end
	table.insert(results, (if passed then "  PASS  " else "  FAIL  ") .. label)
end

local function countMeshParts(model: Instance): number
	local count = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("MeshPart") then
			count += 1
		end
	end
	return count
end

local function namedChildren(parent: Instance?, name: string): { Instance }
	local list = {}
	if parent then
		for _, child in ipairs(parent:GetChildren()) do
			if child.Name == name then
				table.insert(list, child)
			end
		end
	end
	return list
end

-- 1. TemplateTest gone.
local leftovers = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d.Name == "TemplateTest" then
		leftovers += 1
	end
end
check(leftovers == 0, string.format("no TemplateTest in Workspace (found %d)", leftovers))

-- 2. Working rack intact.
local racks = namedChildren(workspace, "PowerRack_01")
check(#racks == 1, string.format("exactly 1 Workspace.PowerRack_01 (found %d)", #racks))
if #racks == 1 then
	check(racks[1]:IsA("Model"), "Workspace.PowerRack_01 is a Model")
	local n = countMeshParts(racks[1])
	check(n == 21, string.format("Workspace.PowerRack_01 has 21 MeshParts (found %d)", n))
end

-- 3. Template intact.
local templates = namedChildren(ServerStorage:FindFirstChild("RackTemplates"), "PowerRack_01")
check(#templates == 1, string.format("exactly 1 ServerStorage.RackTemplates.PowerRack_01 (found %d)", #templates))
if #templates == 1 then
	local template = templates[1]
	check(template:IsA("Model"), "template is a Model")
	local n = countMeshParts(template)
	check(n == 21 and #template:GetDescendants() == 21,
		string.format("template has exactly 21 MeshParts and nothing else (%d MeshParts, %d descendants)", n, #template:GetDescendants()))
	check(#CollectionService:GetTags(template) == 0 and template:GetAttribute("StationId") == nil,
		"template has no tags and no StationId")
end

local header = if allPassed then "[Phase0 verify] ALL CHECKS PASSED" else "[Phase0 verify] SOME CHECKS FAILED"
local report = header .. "\n" .. table.concat(results, "\n")
if allPassed then
	print(report)
else
	warn(report)
end
