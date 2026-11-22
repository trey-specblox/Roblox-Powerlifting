--[[
	RemoveSpilledParts  (Studio Command Bar, EDIT mode; a one-time CLEANUP script, approved by the user 2026-11-22:
	"There is a ton of blocks just spilled everywhere fix that")

	WHAT IT DOES: takes ONE thing out of the place: the chain of plain grey blocks saved at the top of the Workspace.
	"Workspace.Part" is a default 4 x 1 x 2 block with another block named "Part" inside it, and another inside that,
	about 104 deep. Nothing in the game's code makes or uses them. They are not anchored, so in a play test they all
	fall out of each other and spill over the gym floor by the manager's desk.

	WHAT IT TOUCHES: only Workspace.Part and the blocks inside it. Nothing else.

	IT CHANGES NOTHING unless every check passes:
		- Studio is in Edit mode (not a play test);
		- there is exactly one child of Workspace named "Part";
		- it and everything inside it is a plain Part named "Part", 4 x 1 x 2, with nothing else inside (no script,
		  no weld, no mesh, no attachment): if anything else is in there, somebody put it there on purpose.

	It can be run again safely (a second run finds nothing to remove), and Ctrl+Z in Studio puts the blocks back.
	After running it, SAVE the place (File > Save to Roblox), or the blocks come back the next time it opens.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local EXPECTED_SIZE = Vector3.new(4, 1, 2)

local function fail(why: string): string
	local message = "[RemoveSpilledParts] NOTHING CHANGED: " .. why
	warn(message)
	return message
end

if RunService:IsRunning() then
	return fail("Studio is in a play test. Stop it and run this in Edit mode.")
end

local roots = {}
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name == "Part" then
		table.insert(roots, child)
	end
end
if #roots == 0 then
	local message = "[RemoveSpilledParts] Nothing to remove: there is no Workspace.Part (already cleaned up)."
	print(message)
	return message
end
if #roots > 1 then
	return fail(string.format("there are %d things named \"Part\" at the top of the Workspace, not one. Look at them by hand.", #roots))
end

local root = roots[1]
local chain = root:GetDescendants()
table.insert(chain, root)
for _, item in ipairs(chain) do
	if item.ClassName ~= "Part" or item.Name ~= "Part" then
		return fail(string.format("%s is a %s, not a plain block named \"Part\".", item:GetFullName():sub(-60), item.ClassName))
	end
	local part = item :: Part
	if (part.Size - EXPECTED_SIZE).Magnitude > 0.01 or part.Shape ~= Enum.PartType.Block then
		return fail(string.format("a block in the chain is %s, not the default 4 x 1 x 2 block.", tostring(part.Size)))
	end
end

ChangeHistoryService:SetWaypoint("Before RemoveSpilledParts")
root.Parent = nil
ChangeHistoryService:SetWaypoint("RemoveSpilledParts")

local message = string.format("[RemoveSpilledParts] DONE: took %d loose grey blocks out of the Workspace (Ctrl+Z puts them back). "
	.. "Now save the place.", #chain)
print(message)
return message
