--!strict
--[[
	LifterBodyService
	Server / Economy

	Puts the realistic lifter body and the player's clothes on their character (GAME_DESIGN.md §38.5-38.6;
	ClothesConfig). GearService runs it in its one dressing pipeline: prepare (the body, once per character) before the
	worn gear is fitted, dressOutfit (the clothes) after. The remotes (ClothesRemotes) save the outfit and the gear toggle
	and ask GearService to dress again.

	The body swap (tested in Studio 2026-11-12, tools/studio/LifterBody01_SwapTest.luau):
	- clothes made for normal Roblox bodies (Shirt, Pants, layered clothing, body accessories) come off: they can't fit;
	  accessories on the head (hats, hair) stay
	- the 14 body parts are replaced (the head stays, shrunk to ClothesConfig.HeadScale) and every joint mark moved to
	  the new body's joints, its hidden OriginalPosition too (Roblox's automatic scaling puts marks back there)
	- RequiresNeck is off during the swap (replacing the torso breaks the neck for a moment, which would kill them)
	- HipHeight is the new legs' (ClothesConfig.HipHeight)

	Clothes: each piece of ClothesConfig.ClothesAssetId ("<Item>__<Part>") is welded on its body part where it sat on the
	body in Blender, and bends with the body (it is skinned to the same skeleton). Looks only: no mass, collision,
	touch or query.
]]

local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClothesConfig = require(Shared:WaitForChild("Config"):WaitForChild("ClothesConfig"))
local ClothesRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("ClothesRemotes"))

local PlayerDataService = require(script.Parent.Parent:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))

local LifterBodyService = {}

local TEMPLATES_FOLDER = "LifterBodyTemplates"
local TOO_FAST_SECONDS = 0.25

-- R15 part -> the joint whose mark it carries towards its parent.
local JOINT_OF: { [string]: string } = { LowerTorso = "Root", UpperTorso = "Waist" }
for _, side in ipairs({ "Left", "Right" }) do
	JOINT_OF[side .. "UpperArm"] = side .. "Shoulder"
	JOINT_OF[side .. "LowerArm"] = side .. "Elbow"
	JOINT_OF[side .. "Hand"] = side .. "Wrist"
	JOINT_OF[side .. "UpperLeg"] = side .. "Hip"
	JOINT_OF[side .. "LowerLeg"] = side .. "Knee"
	JOINT_OF[side .. "Foot"] = side .. "Ankle"
end

type Joint = { parent: string, inParent: Vector3, inChild: Vector3 }
-- One build's body (ClothesConfig.Bodies), loaded once.
type Templates = {
	body: Model,
	joints: { [string]: Joint },
	-- Each body part's resting place (the body and the clothes share one frame: the import's RootPart at the origin).
	rest: { [string]: CFrame },
	neckMark: Vector3,
}

local templates: { [string]: Templates } = {}
local loadFailed: { [string]: boolean } = {}
local loading: { [string]: boolean } = {}
local clothesModel: Model? = nil
local clothesTried = false
local redress: ((Player) -> ())? = nil
local lastAsked: { [Player]: number } = {}

local function log(message: string, ...: any)
	print("[LifterBodyService] " .. string.format(message, ...))
end

-- Whether characters get the lifter body: off in the live game until the lift animations fit it (ClothesConfig).
function LifterBodyService.enabled(): boolean
	if RunService:IsStudio() then
		local override = Workspace:GetAttribute(ClothesConfig.StudioAttribute)
		if typeof(override) == "boolean" then
			return override
		end
		return ClothesConfig.StudioEnabled
	end
	return ClothesConfig.LiveEnabled
end

local function loadModel(assetId: number): Model?
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		warn("[LifterBodyService] could not load asset " .. assetId .. ": " .. tostring(result))
		return nil
	end
	local model = (result :: Instance):FindFirstChildWhichIsA("Model")
	return model
end

local function templatesFolder(): Folder
	local folder = ServerStorage:FindFirstChild(TEMPLATES_FOLDER)
	if folder and folder:IsA("Folder") then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = TEMPLATES_FOLDER
	made.Parent = ServerStorage
	return made
end

-- Which build a character gets: from the lifter's progress later (§38.1); for now the default, or in Studio the
-- workspace attribute ClothesConfig.StudioBuildAttribute.
function LifterBodyService.buildFor(_player: Player): string
	if RunService:IsStudio() then
		local picked = Workspace:GetAttribute(ClothesConfig.StudioBuildAttribute)
		if typeof(picked) == "string" and ClothesConfig.Bodies[picked] then
			return picked
		end
	end
	return ClothesConfig.DefaultBuild
end

-- One build's body model, loaded once into ServerStorage. Nil when it can't load (characters keep their bodies).
local function getTemplates(build: string): Templates?
	local spec = ClothesConfig.Bodies[build]
	if spec == nil then
		return nil
	end
	if templates[build] or loadFailed[build] then
		return templates[build]
	end
	while loading[build] do
		task.wait(0.1)
	end
	if templates[build] or loadFailed[build] then
		return templates[build]
	end
	loading[build] = true
	local body = loadModel(spec.assetId)
	if body == nil then
		loadFailed[build] = true
		loading[build] = false
		return nil
	end
	body.Name = "Body_" .. build
	body.Parent = templatesFolder()
	-- The importer joins the parts with Motor6Ds: C0 = the joint in the parent part, C1 = in the child part.
	local joints: { [string]: Joint } = {}
	local rest: { [string]: CFrame } = {}
	for _, d in ipairs(body:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and JOINT_OF[d.Part1.Name] and d.Part0 then
			joints[JOINT_OF[d.Part1.Name]] = { parent = d.Part0.Name, inParent = d.C0.Position, inChild = d.C1.Position }
		end
	end
	for partName in pairs(JOINT_OF) do
		local part = body:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			rest[partName] = part.CFrame
		end
	end
	templates[build] = { body = body, joints = joints, rest = rest, neckMark = spec.neckMark }
	loading[build] = false
	log("%s body loaded", build)
	return templates[build]
end

-- The clothes model (only while ClothesConfig.ClothesShown).
local function getClothes(): Model?
	if clothesModel or clothesTried or not ClothesConfig.ClothesShown then
		return clothesModel
	end
	clothesTried = true
	clothesModel = loadModel(ClothesConfig.ClothesAssetId)
	if clothesModel then
		clothesModel.Name = "Clothes"
		clothesModel.Parent = templatesFolder()
	end
	return clothesModel
end

local function place(mark: Attachment, position: Vector3)
	mark.Position = position
	local original = mark:FindFirstChild("OriginalPosition")
	if original and original:IsA("Vector3Value") then
		original.Value = position
	end
end

-- Whether this character has the lifter body.
function LifterBodyService.hasBody(character: Model?): boolean
	return character ~= nil and character:GetAttribute(ClothesConfig.BodyAttribute) == true
end

--[[
	Gives the character the lifter body (once). Returns whether it has it. Call after the avatar has loaded (else Roblox
	puts the avatar's own parts back).
]]
function LifterBodyService.prepare(player: Player, character: Model): boolean
	if LifterBodyService.hasBody(character) then
		return true
	end
	if not LifterBodyService.enabled() then
		return false
	end
	local build = LifterBodyService.buildFor(player)
	local t = getTemplates(build)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	if t == nil or humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 or head == nil or not head:IsA("BasePart") then
		return false
	end
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	local skin = head.Color
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") then
			child:Destroy()
		elseif child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			local mark = handle and handle:FindFirstChildOfClass("Attachment")
			local onHead = mark ~= nil and head:FindFirstChild(mark.Name) ~= nil
			if not onHead or (handle and handle:FindFirstChildOfClass("WrapLayer")) then
				child:Destroy()
			end
		end
	end
	for partName, jointName in pairs(JOINT_OF) do
		local old = character:FindFirstChild(partName)
		local template = t.body:FindFirstChild(partName)
		local joint = t.joints[jointName]
		if old == nil or not old:IsA("BasePart") or template == nil or joint == nil then
			warn("[LifterBodyService] missing " .. partName .. " for " .. player.Name)
			continue
		end
		local new = template:Clone() :: MeshPart
		for _, d in ipairs(new:GetChildren()) do
			d:Destroy()
		end
		-- Every mark comes along: rig marks to the new joints, the rest (accessory marks) scaled to the new size.
		for _, mark in ipairs(old:GetChildren()) do
			if mark:IsA("Attachment") then
				local copy = mark:Clone()
				copy.Parent = new
				place(copy, mark.Position * (new.Size / (old :: BasePart).Size))
			end
		end
		local own = new:FindFirstChild(jointName .. "RigAttachment")
		if own and own:IsA("Attachment") then
			place(own, joint.inChild)
		end
		new.Color = skin
		new.Anchored = false
		new.CanCollide = (old :: BasePart).CanCollide
		local originalSize = Instance.new("Vector3Value")
		originalSize.Name = "OriginalSize"
		originalSize.Value = new.Size
		originalSize.Parent = new
		humanoid:ReplaceBodyPartR15(Enum.BodyPartR15[partName], new)
	end
	for jointName, joint in pairs(t.joints) do
		local parent = character:FindFirstChild(joint.parent)
		local mark = parent and parent:FindFirstChild(jointName .. "RigAttachment")
		if mark and mark:IsA("Attachment") then
			place(mark, joint.inParent)
		end
	end
	local upper = character:FindFirstChild("UpperTorso")
	for _, name in ipairs({ "NeckRigAttachment", "NeckAttachment" }) do
		local mark = upper and upper:FindFirstChild(name)
		if mark and mark:IsA("Attachment") then
			place(mark, t.neckMark)
		end
	end
	humanoid:BuildRigFromAttachments()
	local headScale = humanoid:FindFirstChild("HeadScale")
	if headScale and headScale:IsA("NumberValue") then
		headScale.Value = ClothesConfig.HeadScale
	end
	humanoid.HipHeight = ClothesConfig.HipHeight
	character:SetAttribute(ClothesConfig.BodyAttribute, true)
	character:SetAttribute(ClothesConfig.BodyAttribute .. "Build", build)
	return true
end

--[[
	Rebuilds the character's clothes from the save. `worn` is the gear actually being worn (GearService): with the gear
	toggle on and a singlet or suit worn, the bottom comes off so the legs show; the shirt always stays.
]]
function LifterBodyService.dressOutfit(player: Player, character: Model, worn: { [string]: string })
	local old = character:FindFirstChild(ClothesConfig.FolderName)
	if old then
		old:Destroy()
	end
	if not LifterBodyService.hasBody(character) then
		return
	end
	local build = character:GetAttribute(ClothesConfig.BodyAttribute .. "Build")
	local t = if typeof(build) == "string" then getTemplates(build) else nil
	local clothes = getClothes()
	local outfit = PlayerDataService.getOutfit(player)
	if t == nil or clothes == nil or outfit == nil then
		return
	end
	local gearOn = PlayerDataService.getGearOn(player) ~= false
	local folder = Instance.new("Folder")
	folder.Name = ClothesConfig.FolderName
	for _, kind in ipairs(ClothesConfig.Kinds) do
		local choice = outfit[kind]
		local item = ClothesConfig.item(choice.item)
		local colour = ClothesConfig.colour(choice.colour)
		if item == nil or colour == nil or (kind == "Bottom" and gearOn and worn.Singlet ~= nil) then
			continue
		end
		for _, piece in ipairs(clothes:GetChildren()) do
			local prefix, partName = string.match(piece.Name, "^(.-)__(.+)$")
			if prefix == nil or not piece:IsA("MeshPart") then
				continue
			end
			local fixed = item.fixed and item.fixed[prefix]
			if prefix ~= item.id and fixed == nil then
				continue
			end
			local bodyPart = character:FindFirstChild(partName :: string)
			local rest = t.rest[partName :: string]
			if bodyPart == nil or not bodyPart:IsA("BasePart") or rest == nil then
				continue
			end
			local copy = piece:Clone() :: MeshPart
			for _, d in ipairs(copy:GetChildren()) do
				d:Destroy()
			end
			copy.Color = fixed or colour.colour
			copy.Anchored = false
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Massless = true
			copy.CFrame = bodyPart.CFrame * rest:ToObjectSpace(piece.CFrame)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = bodyPart
			weld.Part1 = copy
			weld.Parent = copy
			copy.Parent = folder
		end
	end
	folder.Parent = character
end

local function viewFor(player: Player): ClothesRemotes.ClothesView?
	local outfit = PlayerDataService.getOutfit(player)
	local gearOn = PlayerDataService.getGearOn(player)
	local data = PlayerDataService.getData(player)
	if outfit == nil or gearOn == nil or data == nil then
		return nil
	end
	local owned = {}
	for _, item in ipairs(ClothesConfig.Items) do
		if item.free or (typeof((data :: any).inventory) == "table" and typeof((data :: any).inventory.clothes) == "table"
			and (data :: any).inventory.clothes[item.id] == true) then
			table.insert(owned, item.id)
		end
	end
	return { outfit = outfit, owned = owned, gearOn = gearOn, lifterBody = LifterBodyService.hasBody(player.Character) }
end

local function tooFast(player: Player): boolean
	local now = os.clock()
	if lastAsked[player] and now - lastAsked[player] < TOO_FAST_SECONDS then
		return true
	end
	lastAsked[player] = now
	return false
end

-- GearService hands over its dressing (worn gear, then these clothes), so a change here redresses the whole character.
function LifterBodyService.setRedress(callback: (Player) -> ())
	redress = callback
end

function LifterBodyService.start()
	local remotes = ClothesRemotes.createOnServer(ReplicatedStorage)
	remotes.get.OnServerInvoke = function(player: Player): ClothesRemotes.ClothesView?
		if tooFast(player) then
			return nil
		end
		return viewFor(player)
	end
	remotes.set.OnServerInvoke = function(player: Player, kind: any, itemId: any, colourId: any)
		if tooFast(player) then
			return false, "One moment...", nil
		end
		if typeof(kind) ~= "string" or typeof(itemId) ~= "string" or typeof(colourId) ~= "string" then
			return false, "Unknown clothing.", nil
		end
		local ok, message = PlayerDataService.setOutfitPiece(player, kind, itemId, colourId)
		if ok and redress then
			redress(player)
		end
		return ok, message, viewFor(player)
	end
	remotes.gear.OnServerInvoke = function(player: Player, on: any)
		if tooFast(player) then
			return false, "One moment...", nil
		end
		if typeof(on) ~= "boolean" then
			return false, "On or off?", nil
		end
		local ok = PlayerDataService.setGearOn(player, on)
		if ok and redress then
			redress(player)
		end
		return ok, if not ok then "Your save hasn't loaded yet." elseif on then "Gear on." else "Gear off.", viewFor(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
	if LifterBodyService.enabled() then
		task.spawn(getTemplates, ClothesConfig.DefaultBuild)
	end
end

return LifterBodyService
