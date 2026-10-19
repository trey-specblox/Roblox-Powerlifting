--[[
	ComboRack01_PrepareImport  (TEMPORARY Command Bar script, 2026-10-18)

	NOT game code. Run in Studio EDIT mode, in the real game place, right after
	importing art/exports/ComboRack_01.fbx with Home -> Import 3D.

	Touches exactly one instance: the freshly imported Workspace.ComboRack_01
	Model. Before changing anything it checks that:
	  - Studio is in Edit mode and this is the game place (PlaceId 96814269062063);
	  - exactly ONE instance named ComboRack_01 exists in Workspace, and it is a
	    Model directly in Workspace;
	  - it holds exactly the 26 expected MeshParts and nothing else, each with an
	    uploaded rbxassetid:// mesh, and no tag or StationId;
	  - it is the right size (about 7.9 W x 7.0 H x 5.4 D studs) and the right way
	    up: posts tallest along Y, J-cups on the -Z (front) side, Left at +X,
	    the same way round as the PowerRack_01 template.
	If any check fails it changes nothing.

	Then it sets, on those 26 parts only: Anchored = true, CanCollide = false,
	CanTouch = false (RackConfigurator decides collision at runtime), and the
	Roblox Material + Color of each part (table LOOKS below; easy to tweak), and
	RenderFidelity = Precise on the 4 parts made of scattered small pieces
	(automatic level of detail turns them into flat sheets at a distance). It
	never deletes, moves, renames or resizes anything. Running it twice is safe.
	Undo with Ctrl+Z. It does NOT save the place.

	Afterwards: right-click Workspace.ComboRack_01 -> Save to File ->
	D:\Powerlifting Roblox\art\roblox\ComboRack_01.rbxmx, then delete the
	Workspace copy (it is only the import) and do not save the place with it.
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local GAME_PLACE_ID = 96814269062063
local RACK_NAME = "ComboRack_01"
local EXPECTED_SIZE = Vector3.new(7.9, 7.0, 5.4)
local SIZE_TOLERANCE = 0.05

-- Look per kind of part. Materials that this Studio does not know fall back to the second name.
local LOOKS = {
	steel = { "Metal", "Metal", Color3.fromRGB(32, 32, 35) },
	zinc = { "Metal", "Metal", Color3.fromRGB(170, 172, 176) },
	hardware = { "Metal", "Metal", Color3.fromRGB(105, 107, 110) },
	rubber = { "Rubber", "SmoothPlastic", Color3.fromRGB(22, 22, 22) },
	vinyl = { "Leather", "Fabric", Color3.fromRGB(18, 18, 18) },
	deck = { "DiamondPlate", "DiamondPlate", Color3.fromRGB(40, 40, 43) },
}

local EXPECTED_PARTS: { [string]: string } = {
	Upright_Left = "steel", Upright_Right = "steel",
	UprightInsert_Left = "zinc", UprightInsert_Right = "zinc",
	InsertLockPins = "hardware",
	SpotterPost_Left = "steel", SpotterPost_Right = "steel",
	SafetyArm_Left = "steel", SafetyArm_Right = "steel",
	SafetyPins = "hardware",
	BaseRail_Left = "steel", BaseRail_Right = "steel", BaseRail_Back = "steel",
	BaseFoot_Left = "steel", BaseFoot_Right = "steel",
	SpotterDeck = "deck",
	FootCaps = "rubber",
	JCup_Left = "steel", JCup_Right = "steel",
	JCupLiner_Left = "rubber", JCupLiner_Right = "rubber",
	JCupPin_Left = "hardware", JCupPin_Right = "hardware",
	FrameBolts = "hardware",
	Bench_Pad = "vinyl",
	Bench_Frame = "steel",
}

local SCATTERED_PARTS = { FootCaps = true, FrameBolts = true, SafetyPins = true, InsertLockPins = true }

local function countKeys(t: { [string]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function materialNamed(first: string, fallback: string): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[first]
	end)
	if ok and value ~= nil then
		return value
	end
	return (Enum.Material :: any)[fallback]
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
		if d.Name == RACK_NAME then
			table.insert(found, d)
		end
	end
	if #found ~= 1 then
		return false, string.format("expected exactly 1 %s in Workspace, found %d (import it once, or remove extra copies)",
			RACK_NAME, #found)
	end
	local rack = found[1]
	if rack.Parent ~= workspace or not rack:IsA("Model") then
		return false, rack:GetFullName() .. " is not a Model directly in Workspace"
	end
	if #CollectionService:GetTags(rack) > 0 or rack:GetAttribute("StationId") ~= nil then
		return false, "the imported rack has tags or a StationId; it is not a fresh import"
	end

	local expectedCount = countKeys(EXPECTED_PARTS)
	local descendants = rack:GetDescendants()
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
		if EXPECTED_PARTS[d.Name] == nil then
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

	local _, size = rack:GetBoundingBox()
	if (size - EXPECTED_SIZE).Magnitude > SIZE_TOLERANCE then
		return false, string.format("it is %s studs, expected about %s (wrong importer scale?)",
			tostring(size), tostring(EXPECTED_SIZE))
	end
	local post = parts.Upright_Left
	if post.Size.Y < post.Size.X or post.Size.Y < post.Size.Z or post.CFrame.UpVector.Y < 0.999 then
		return false, "Upright_Left is not standing up along Y; the import is rotated"
	end
	-- Same orientation as the PowerRack_01 template (read from its .rbxmx): the open
	-- front with the J-cups is -Z, and "Left" (as seen from the front) is +X.
	if parts.JCup_Left.Position.Z >= post.Position.Z then
		return false, "the J-cups are not on the -Z side; the import is turned around"
	end
	if parts.Upright_Left.Position.X <= parts.Upright_Right.Position.X then
		return false, "Upright_Left is not on the +X side; the import is mirrored"
	end

	local recording = ChangeHistoryService:TryBeginRecording("Prepare ComboRack_01 import")
	for name, part in pairs(parts) do
		local look = LOOKS[EXPECTED_PARTS[name]]
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.Material = materialNamed(look[1], look[2])
		part.Color = look[3]
		-- Scattered small pieces in one mesh: Roblox's automatic level of detail merges
		-- them into flat sheets at a distance, so these are never simplified.
		if SCATTERED_PARTS[name] then
			part.RenderFidelity = Enum.RenderFidelity.Precise
		end
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return true, string.format("checked and prepared %d MeshParts (size %s). Ctrl+Z undoes it. "
		.. "Next: right-click Workspace.%s -> Save to File -> art\\roblox\\%s.rbxmx, then delete the Workspace copy.",
		expectedCount, tostring(size), RACK_NAME, RACK_NAME)
end

local ok, success, message = pcall(run)
if not ok then
	warn("[ComboRack_01 import] SCRIPT ERROR: " .. tostring(success) .. ". Nothing is saved; Ctrl+Z if anything changed.")
elseif success then
	print("[ComboRack_01 import] SUCCESS: " .. message)
else
	warn("[ComboRack_01 import] REFUSED, nothing was changed: " .. tostring(message))
end
