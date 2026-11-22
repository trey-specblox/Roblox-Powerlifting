--[[
	RemoveScaleTestCube  (Studio Command Bar, EDIT mode; a one-time CLEANUP script. NOT RUN YET: it waits for the
	user's yes. Written 2026-11-22 during the whole-map flicker and overlap check.)

	WHAT IT DOES: takes ONE thing out of the place: Workspace.ScaleTest_2StudCube_v2, the plain grey 2 x 2 x 2 cube
	left over from the very first Blender import test (it proved that a 2-stud cube arrives 2 studs big). Nothing in
	the game's code makes or uses it. It is saved in the place inside the gym near (69, 1, 21), is not anchored, and
	players can bump into it and push it about.

	WHAT IT TOUCHES: only Workspace.ScaleTest_2StudCube_v2 and the one mesh inside it. Nothing else.

	IT CHANGES NOTHING unless every check passes:
		- Studio is in Edit mode (not a play test);
		- there is exactly one child of Workspace named "ScaleTest_2StudCube_v2", and it is a Model;
		- the only thing inside it is one MeshPart named "ScaleTest_2StudCube", 2 x 2 x 2 studs (no script, no weld,
		  nothing else: if anything else is in there, somebody put it there on purpose).

	It can be run again safely (a second run finds nothing to remove), and Ctrl+Z in Studio puts the cube back.
	After running it, SAVE the place (File > Save to Roblox), or the cube comes back the next time it opens.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local MODEL_NAME = "ScaleTest_2StudCube_v2"
local MESH_NAME = "ScaleTest_2StudCube"
local EXPECTED_SIZE = Vector3.new(2, 2, 2)

local function fail(why: string): string
	local message = "[RemoveScaleTestCube] NOTHING CHANGED: " .. why
	warn(message)
	return message
end

if RunService:IsRunning() then
	return fail("Studio is in a play test. Stop it and run this in Edit mode.")
end

local found = {}
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name == MODEL_NAME then
		table.insert(found, child)
	end
end
if #found == 0 then
	local message = "[RemoveScaleTestCube] Nothing to remove: there is no Workspace." .. MODEL_NAME .. " (already cleaned up)."
	print(message)
	return message
end
if #found > 1 then
	return fail(string.format("there are %d things named \"%s\" at the top of the Workspace, not one. Look at them by hand.", #found,
		MODEL_NAME))
end

local model = found[1]
if not model:IsA("Model") then
	return fail(string.format("Workspace.%s is a %s, not a Model.", MODEL_NAME, model.ClassName))
end
local inside = model:GetDescendants()
if #inside ~= 1 then
	return fail(string.format("the model holds %d things, not just its one cube. Look at it by hand.", #inside))
end
local cube = inside[1]
if not cube:IsA("MeshPart") or cube.Name ~= MESH_NAME then
	return fail(string.format("the thing inside the model is a %s named \"%s\", not the test cube.", cube.ClassName, cube.Name))
end
if ((cube :: MeshPart).Size - EXPECTED_SIZE).Magnitude > 0.01 then
	return fail(string.format("the cube is %s, not 2 x 2 x 2.", tostring((cube :: MeshPart).Size)))
end

ChangeHistoryService:SetWaypoint("Before RemoveScaleTestCube")
model.Parent = nil
ChangeHistoryService:SetWaypoint("RemoveScaleTestCube")

local message = "[RemoveScaleTestCube] DONE: took the 2-stud test cube out of the Workspace (Ctrl+Z puts it back). Now save the place."
print(message)
return message
