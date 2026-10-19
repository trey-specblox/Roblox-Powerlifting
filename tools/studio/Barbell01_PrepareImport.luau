--[[
	Barbell01_PrepareImport  (TEMPORARY Command Bar script, 2026-10-19)

	NOT game code. Run in Studio EDIT mode, in the real game place, right after
	importing art/exports/Barbell_01.fbx with Home -> Import 3D.

	Touches exactly one instance: the freshly imported Workspace.Barbell_01
	Model. Before changing anything it checks that:
	  - Studio is in Edit mode and this is the game place (PlaceId 96814269062063);
	  - exactly ONE instance named Barbell_01 exists in Workspace, and it is a
	    Model directly in Workspace;
	  - it holds exactly the 10 expected MeshParts and nothing else, each with an
	    uploaded rbxassetid:// mesh, and no tag;
	  - it is the right size (about 9.9 long x 2.0 x 2.0 studs) and the bar lies
	    along X, with the plates on one sleeve.
	If any check fails it changes nothing.

	Then it sets, on those 10 parts only: Anchored = true, CanCollide = false,
	CanTouch = false, CanQuery = false (the barbell is decoration; nothing
	should bump into it or detect it), and the Roblox Material + Color of each
	part (table LOOKS below; easy to tweak). It never deletes, moves, renames or
	resizes anything. Running it twice is safe. Undo with Ctrl+Z. It does NOT
	save the place.

	Afterwards: right-click Workspace.Barbell_01 -> Save to File ->
	D:\Powerlifting Roblox\art\roblox\Barbell_01.rbxmx, then delete the
	Workspace copy (it is only the import) and do not save the place with it.
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local GAME_PLACE_ID = 96814269062063
local MODEL_NAME = "Barbell_01"
local EXPECTED_SIZE = Vector3.new(9.9, 2.0, 2.0)
local SIZE_TOLERANCE = 0.05

-- { Material, Color } per part. IPF plate colours: 25 red, 20 blue, 15 yellow, 10 green.
local LOOKS: { [string]: { any } } = {
	Bar_Shaft = { Enum.Material.Metal, Color3.fromRGB(175, 178, 182) },
	Bar_Sleeves = { Enum.Material.Metal, Color3.fromRGB(215, 217, 220) },
	Plate_25 = { Enum.Material.SmoothPlastic, Color3.fromRGB(196, 28, 28) },
	Plate_20 = { Enum.Material.SmoothPlastic, Color3.fromRGB(24, 62, 190) },
	Plate_15 = { Enum.Material.SmoothPlastic, Color3.fromRGB(240, 196, 20) },
	Plate_10 = { Enum.Material.SmoothPlastic, Color3.fromRGB(22, 140, 52) },
	Plate_5 = { Enum.Material.SmoothPlastic, Color3.fromRGB(235, 235, 235) },
	Plate_2_5 = { Enum.Material.SmoothPlastic, Color3.fromRGB(25, 25, 25) },
	Plate_1_25 = { Enum.Material.Metal, Color3.fromRGB(200, 202, 206) },
	Collar_Lock = { Enum.Material.Metal, Color3.fromRGB(205, 207, 210) },
}

local function countKeys(t: { [string]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function run(): (boolean, string)
	if RunService:IsRunning() then
		return false, "Studio is in Play/Run mode. Stop the test and run this in Edit mode."
	end
	if game.PlaceId ~= GAME_PLACE_ID then
		return false, string.format("this is place %d, not the game place %d. Open the real game first.",
			game.PlaceId, GAME_PLACE_ID)
	end

	local found = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == MODEL_NAME then
			table.insert(found, d)
		end
	end
	if #found ~= 1 then
		return false, string.format("expected exactly 1 %s in Workspace, found %d (import it once, or remove extra copies)",
			MODEL_NAME, #found)
	end
	local model = found[1]
	if model.Parent ~= workspace or not model:IsA("Model") then
		return false, model:GetFullName() .. " is not a Model directly in Workspace"
	end
	if #CollectionService:GetTags(model) > 0 then
		return false, "the imported barbell has tags; it is not a fresh import"
	end

	local expectedCount = countKeys(LOOKS)
	local descendants = model:GetDescendants()
	if #descendants ~= expectedCount then
		local names = {}
		for _, d in ipairs(descendants) do
			table.insert(names, d.Name .. " (" .. d.ClassName .. ")")
		end
		return false, string.format("it has %d descendants, expected exactly %d MeshParts. Found: %s",
			#descendants, expectedCount, table.concat(names, ", "))
	end
	local parts: { [string]: MeshPart } = {}
	for _, d in ipairs(descendants) do
		if not d:IsA("MeshPart") then
			return false, string.format("it contains a %s (%s)", d.ClassName, d.Name)
		end
		if LOOKS[d.Name] == nil then
			return false, "unexpected part name " .. d.Name .. " (did the importer rename it?)"
		end
		if parts[d.Name] then
			return false, "two parts named " .. d.Name
		end
		if string.sub(d.MeshId, 1, 13) ~= "rbxassetid://" then
			return false, string.format("%s has no uploaded mesh (MeshId '%s'); are you logged in?", d.Name, d.MeshId)
		end
		parts[d.Name] = d
	end

	local _, size = model:GetBoundingBox()
	if (size - EXPECTED_SIZE).Magnitude > SIZE_TOLERANCE then
		return false, string.format("it is %s studs, expected about %s (wrong importer scale or rotated?)",
			tostring(size), tostring(EXPECTED_SIZE))
	end
	local shaft = parts.Bar_Shaft
	if shaft.Size.X < shaft.Size.Y * 10 or shaft.Size.X < shaft.Size.Z * 10 then
		return false, "Bar_Shaft does not lie along X; the import is rotated"
	end
	if math.abs(parts.Plate_25.Position.X - shaft.Position.X) < 3 then
		return false, "Plate_25 is not out on a sleeve; the import looks wrong"
	end

	local recording = ChangeHistoryService:TryBeginRecording("Prepare Barbell_01 import")
	for name, part in pairs(parts) do
		local look = LOOKS[name]
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = look[1]
		part.Color = look[2]
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return true, string.format("checked and prepared %d MeshParts (size %s). Ctrl+Z undoes it. "
		.. "Next: right-click Workspace.%s -> Save to File -> art\\roblox\\%s.rbxmx, then delete the Workspace copy.",
		expectedCount, tostring(size), MODEL_NAME, MODEL_NAME)
end

local ok, success, message = pcall(run)
if not ok then
	warn("[Barbell_01 import] SCRIPT ERROR: " .. tostring(success) .. ". Nothing is saved; Ctrl+Z if anything changed.")
elseif success then
	print("[Barbell_01 import] SUCCESS: " .. message)
else
	warn("[Barbell_01 import] REFUSED, nothing was changed: " .. tostring(message))
end
