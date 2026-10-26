--[[
	ShopGear01_PrepareImport  (TEMPORARY Command Bar script, 2026-10-23)

	NOT game code. Run in Studio EDIT mode, in the real game place, right after
	importing art/exports/ShopGear_01.fbx with Home -> Import 3D (the Shop's
	gear: knee sleeve, wrist wraps, lever belt, singlet and T-shirt mannequins;
	built by art/scripts/build_shop_gear_01.py).

	Touches exactly one instance: the freshly imported Workspace.ShopGear_01
	Model and the 29 MeshParts in it. Before changing anything it checks that:
	  - Studio is in Edit mode and this is the game place (PlaceId 96814269062063);
	  - exactly ONE instance named ShopGear_01 exists in Workspace, a Model
	    directly in Workspace, with no tags;
	  - it holds exactly the 29 expected MeshParts (table LOOKS) and nothing
	    else, each with an uploaded rbxassetid:// mesh;
	  - it is the expected size (about 14.7 x 5.7 x 1.3 studs) and upright.
	If any check fails it changes nothing.

	Then it:
	  - sets on every part: Anchored, CanCollide/CanTouch/CanQuery off (the gear
	    is decoration; the Shop adds its own collision boxes), and the Roblox
	    Material + Color from LOOKS;
	  - groups the parts into one Model per item (the name before the first
	    "_": KneeSleeve, WristWrap, WristWrapHanging, LeverBelt,
	    MannequinSinglet, MannequinTee), inside ShopGear_01;
	  - gives each item Model a WorldPivot at the middle of its bottom (the
	    hanging wrap: the top of its loop, where it hangs on a hook), turned so
	    the pivot's LookVector is the item's front (worked out from its badge,
	    loose end or buckle). RoomProps places the items by that pivot.
	It never deletes, resizes or reshapes anything. Running it twice is safe
	(the second run finds the items already grouped and only re-applies the
	looks and pivots). Undo with Ctrl+Z. It does NOT save the place.

	Afterwards: right-click Workspace.ShopGear_01 -> Save to File ->
	D:\Powerlifting Roblox\art\roblox\ShopGear_01.rbxmx, then delete the
	Workspace copy (it is only the import) and do not save the place with it.
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local GAME_PLACE_ID = 96814269062063
local MODEL_NAME = "ShopGear_01"
local EXPECTED_SIZE = Vector3.new(14.74, 5.69, 1.31)
local SIZE_TOLERANCE = 0.3

local BLACK = { Enum.Material.Fabric, Color3.fromRGB(24, 24, 26) }
local RED = { Enum.Material.Fabric, Color3.fromRGB(190, 28, 36) }
local RED_PRINT = { Enum.Material.SmoothPlastic, Color3.fromRGB(210, 32, 40) } -- badges and text: crisp
local GREY = { Enum.Material.Fabric, Color3.fromRGB(78, 78, 82) }
local FORM = { Enum.Material.SmoothPlastic, Color3.fromRGB(232, 232, 230) }
local STAND = { Enum.Material.Metal, Color3.fromRGB(30, 30, 34) }

-- { Material, Color } per part.
local LOOKS: { [string]: { any } } = {
	KneeSleeve_Body = BLACK,
	KneeSleeve_Stripes = RED,
	KneeSleeve_Patch = RED_PRINT,
	WristWrap_Body = BLACK,
	WristWrap_Tail = BLACK,
	WristWrap_Stripes = RED,
	WristWrap_Text = { Enum.Material.SmoothPlastic, Color3.fromRGB(238, 238, 238) },
	WristWrapHanging_Body = BLACK,
	WristWrapHanging_Loop = BLACK,
	WristWrapHanging_Stripes = RED,
	WristWrapHanging_Velcro = GREY,
	WristWrapHanging_Text = { Enum.Material.SmoothPlastic, Color3.fromRGB(238, 238, 238) },
	LeverBelt_Outer = { Enum.Material.Fabric, Color3.fromRGB(20, 20, 22) },
	LeverBelt_Lining = RED,
	LeverBelt_Stitch = GREY,
	LeverBelt_Lever = { Enum.Material.Metal, Color3.fromRGB(150, 152, 158) },
	LeverBelt_Text = { Enum.Material.SmoothPlastic, Color3.fromRGB(22, 22, 24) },
	MannequinSinglet_Form = FORM,
	MannequinSinglet_Stand = STAND,
	MannequinSinglet_Black = BLACK,
	MannequinSinglet_Red = RED,
	MannequinSinglet_Trim = RED,
	MannequinSinglet_Shorts = BLACK,
	MannequinSinglet_ShortsRed = RED,
	MannequinSinglet_Patch = RED_PRINT,
	MannequinTee_Form = FORM,
	MannequinTee_Stand = STAND,
	MannequinTee_Black = BLACK,
	MannequinTee_Logo = RED_PRINT,
}

-- Per item: the part that marks its front, the part it is measured from, and
-- whether it hangs from its top.
local ITEMS: { [string]: { front: string, body: string, hangs: boolean } } = {
	KneeSleeve = { front = "KneeSleeve_Patch", body = "KneeSleeve_Body", hangs = false },
	WristWrap = { front = "WristWrap_Tail", body = "WristWrap_Body", hangs = false },
	WristWrapHanging = { front = "WristWrapHanging_Text", body = "WristWrapHanging_Body", hangs = true },
	LeverBelt = { front = "LeverBelt_Lever", body = "LeverBelt_Outer", hangs = false },
	MannequinSinglet = { front = "MannequinSinglet_Patch", body = "MannequinSinglet_Form", hangs = false },
	MannequinTee = { front = "MannequinTee_Logo", body = "MannequinTee_Form", hangs = false },
}

local function countKeys(t: { [string]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function itemOf(partName: string): string
	return (string.split(partName, "_"))[1]
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
		return false, "the imported gear has tags; it is not a fresh import"
	end

	-- Exactly the expected MeshParts; item Models from an earlier run are allowed.
	local parts: { [string]: MeshPart } = {}
	local count = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("MeshPart") then
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
			count += 1
		elseif not (d:IsA("Model") and d.Parent == model and ITEMS[d.Name] ~= nil) then
			return false, string.format("it contains a %s (%s); expected only the gear's MeshParts", d.ClassName, d:GetFullName())
		end
	end
	if count ~= countKeys(LOOKS) then
		local missing = {}
		for name in pairs(LOOKS) do
			if parts[name] == nil then
				table.insert(missing, name)
			end
		end
		return false, string.format("found %d of %d parts; missing: %s", count, countKeys(LOOKS), table.concat(missing, ", "))
	end

	local _, size = model:GetBoundingBox()
	if math.abs(size.X - EXPECTED_SIZE.X) > SIZE_TOLERANCE or math.abs(size.Y - EXPECTED_SIZE.Y) > SIZE_TOLERANCE
		or math.abs(size.Z - EXPECTED_SIZE.Z) > SIZE_TOLERANCE then
		return false, string.format("it is %s studs, expected about %s (wrong importer scale, or rotated?)",
			tostring(size), tostring(EXPECTED_SIZE))
	end
	if parts.MannequinSinglet_Stand.Position.Y > parts.MannequinSinglet_Form.Position.Y then
		return false, "the mannequin's stand is above its form: the import is upside down"
	end

	local recording = ChangeHistoryService:TryBeginRecording("Prepare ShopGear_01 import")
	for name, part in pairs(parts) do
		local look = LOOKS[name]
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = look[1]
		part.Color = look[2]
	end
	local summary = {}
	for itemName, item in pairs(ITEMS) do
		local itemModel = model:FindFirstChild(itemName)
		if itemModel == nil then
			itemModel = Instance.new("Model")
			itemModel.Name = itemName
			itemModel.Parent = model
		end
		for name, part in pairs(parts) do
			if itemOf(name) == itemName then
				part.Parent = itemModel
			end
		end
		-- The pivot: bottom middle (or top, if it hangs), facing the item's front.
		local box, boxSize = (itemModel :: Model):GetBoundingBox()
		local height = if item.hangs then boxSize.Y / 2 else -boxSize.Y / 2
		local anchor = Vector3.new(box.Position.X, box.Position.Y + height, box.Position.Z)
		local toFront = parts[item.front].Position - parts[item.body].Position
		local front = Vector3.new(toFront.X, 0, toFront.Z)
		if front.Magnitude < 0.001 then
			front = Vector3.new(0, 0, -1)
		end
		(itemModel :: Model).WorldPivot = CFrame.lookAt(anchor, anchor + front.Unit)
		table.insert(summary, string.format("%s %.1fx%.1fx%.1f", itemName, boxSize.X, boxSize.Y, boxSize.Z))
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	table.sort(summary)
	return true, string.format("checked and prepared %d MeshParts in 6 items (%s). Ctrl+Z undoes it. "
		.. "Next: right-click Workspace.%s -> Save to File -> art\\roblox\\%s.rbxmx, then delete the Workspace copy.",
		count, table.concat(summary, "; "), MODEL_NAME, MODEL_NAME)
end

local ok, success, message = pcall(run)
if not ok then
	warn("[ShopGear_01 import] SCRIPT ERROR: " .. tostring(success) .. ". Nothing is saved; Ctrl+Z if anything changed.")
elseif success then
	print("[ShopGear_01 import] SUCCESS: " .. message)
else
	warn("[ShopGear_01 import] REFUSED, nothing was changed: " .. tostring(message))
end
