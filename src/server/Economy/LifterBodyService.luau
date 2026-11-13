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

	Clothes: each piece of the build's clothes model (ClothesConfig.Bodies[build].clothesAssetId, "<Item>__<Part>") is welded on its body part where it sat on the
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
local HandShapeConfig = require(Shared:WaitForChild("Config"):WaitForChild("HandShapeConfig"))
local ClothesRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("ClothesRemotes"))
local LifterBuild = require(Shared:WaitForChild("Economy"):WaitForChild("LifterBuild"))

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
-- One clothes model per build (the pieces are shaped over that build's body), and the hand shapes.
local clothesModels: { [string]: Model } = {}
local clothesTried: { [string]: boolean } = {}
local handsModel: Model? = nil
local handsTried = false
local redress: ((Player) -> ())? = nil
local lastAsked: { [Player]: number } = {}

-- (defined further down)
local swapBody: (Model, string, string) -> boolean
local dress: (Model, string, (string) -> (ClothesConfig.Item?, Color3?)) -> Folder?

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

-- Which build a player's character gets (§38.1, LifterBuild): their bodyweight and their active class's Competition
-- Numbers. In Studio the workspace attribute ClothesConfig.StudioBuildAttribute picks one for a test.
function LifterBodyService.buildFor(player: Player): string
	if RunService:IsStudio() then
		local picked = Workspace:GetAttribute(ClothesConfig.StudioBuildAttribute)
		if typeof(picked) == "string" and ClothesConfig.Bodies[picked] then
			return picked
		end
	end
	local data = PlayerDataService.getData(player)
	local bodyweight = data and (data :: any).bodyweight
	local kg = if typeof(bodyweight) == "table" then bodyweight.currentKg else nil
	if typeof(kg) ~= "number" then
		return ClothesConfig.DefaultBuild
	end
	local numbers: { [string]: number } = {}
	for _, lift in ipairs({ "Squat", "Bench", "Deadlift" }) do
		local cn = PlayerDataService.getCompetitionNumber(player, lift)
		if cn then
			numbers[lift] = cn
		end
	end
	local build = LifterBuild.forNumbers(kg, numbers)
	return if ClothesConfig.Bodies[build] then build else ClothesConfig.DefaultBuild
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

-- `build`'s clothes model (only while ClothesConfig.ClothesShown).
local function getClothes(build: string): Model?
	local spec = ClothesConfig.Bodies[build]
	if clothesModels[build] or clothesTried[build] or not ClothesConfig.ClothesShown or spec == nil
		or spec.clothesAssetId == 0 then
		return clothesModels[build]
	end
	clothesTried[build] = true
	local model = loadModel(spec.clothesAssetId)
	if model then
		model.Name = "Clothes_" .. build
		model.Parent = templatesFolder()
		clothesModels[build] = model
	end
	return model
end

-- The hand shapes model (HandShapeConfig), once.
local function getHands(): Model?
	if handsModel or handsTried or HandShapeConfig.AssetId == 0 then
		return handsModel
	end
	handsTried = true
	handsModel = loadModel(HandShapeConfig.AssetId)
	if handsModel then
		handsModel.Name = "HandShapes"
		handsModel.Parent = templatesFolder()
	end
	return handsModel
end

--[[
	Puts the hidden hand shapes on the body (HandShapeConfig): each one welded where the fist is, sized to the build,
	the skin's colour. Every client's HandShapeAnimator shows one in place of the fist while a celebration needs it.
]]
local function addHandShapes(character: Model, build: string, skin: Color3)
	local hands = getHands()
	local old = character:FindFirstChild(HandShapeConfig.FolderName)
	if old then
		old:Destroy()
	end
	if hands == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = HandShapeConfig.FolderName
	local scale = HandShapeConfig.HandSize[build] or 1
	for _, side in ipairs({ "Left", "Right" }) do
		local hand = character:FindFirstChild(side .. "Hand")
		if hand == nil or not hand:IsA("BasePart") then
			continue
		end
		for _, shape in ipairs(HandShapeConfig.Shapes) do
			local template = hands:FindFirstChild(shape .. "_" .. side, true)
			if template == nil or not template:IsA("MeshPart") then
				continue
			end
			local part = template:Clone()
			for _, d in ipairs(part:GetChildren()) do
				d:Destroy()
			end
			part.Size = template.Size * scale
			part.Color = skin
			part.Transparency = 1
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Massless = true
			local offset = CFrame.new(HandShapeConfig.offset(build, shape, side))
			part.CFrame = hand.CFrame * offset
			local weld = Instance.new("Weld")
			weld.Part0 = hand
			weld.Part1 = part
			weld.C0 = offset
			weld.Parent = part
			part.Parent = folder
		end
	end
	folder.Parent = character
end

local function place(mark: Attachment, position: Vector3)
	mark.Position = position
	local original = mark:FindFirstChild("OriginalPosition")
	if original and original:IsA("Vector3Value") then
		original.Value = position
	end
end

-- Each body part's resting place for `build` (the frame its clothes and gear models share), or nil.
function LifterBodyService.restFor(build: string): { [string]: CFrame }?
	local t = getTemplates(build)
	return if t then t.rest else nil
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
	return swapBody(character, LifterBodyService.buildFor(player), player.Name)
end

--[[
	A computer lifter's or a spotter's figure (§38.1: they get the same bodies): the `build` body, its skin from its
	head, dressed in `outfit` (kind -> { item = ClothesConfig item id, colour = Color3 }). Returns whether it has it.
	(Their singlets come with the computer lifters' random gear, GAME_DESIGN §38.4 step 4; a tank top stands in.)
]]
function LifterBodyService.prepareFigure(figure: Model, build: string, outfit: { [string]: { item: string, colour: Color3 } }): boolean
	if not LifterBodyService.enabled() then
		return false
	end
	if not LifterBodyService.hasBody(figure) and not swapBody(figure, build, figure.Name) then
		return false
	end
	local folder = dress(figure, build, function(kind)
		local choice = outfit[kind]
		return if choice then ClothesConfig.item(choice.item) else nil, if choice then choice.colour else nil
	end)
	if folder then
		for _, part in ipairs(folder:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CastShadow = false
			end
		end
	end
	return true
end

-- The body swap itself (see prepare). `label` names the character in warnings.
function swapBody(character: Model, build: string, label: string): boolean
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
			warn("[LifterBodyService] missing " .. partName .. " for " .. label)
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
	addHandShapes(character, build, skin)
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
	local outfit = PlayerDataService.getOutfit(player)
	if typeof(build) ~= "string" or outfit == nil then
		return
	end
	local gearOn = PlayerDataService.getGearOn(player) ~= false
	dress(character, build, function(kind)
		local choice = outfit[kind]
		local colour = choice and ClothesConfig.colour(choice.colour)
		if choice == nil or colour == nil or (kind == "Bottom" and gearOn and worn.Singlet ~= nil) then
			return nil, nil
		end
		return ClothesConfig.item(choice.item), colour.colour
	end)
end

--[[
	Puts clothes on a character with the lifter body: for each kind, `pick(kind)` says the item and its colour (nil =
	none). Returns the new folder, or nil.
]]
function dress(character: Model, build: string, pick: (string) -> (ClothesConfig.Item?, Color3?)): Folder?
	local old = character:FindFirstChild(ClothesConfig.FolderName)
	if old then
		old:Destroy()
	end
	local t = getTemplates(build)
	local clothes = getClothes(build)
	if t == nil or clothes == nil then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = ClothesConfig.FolderName
	for _, kind in ipairs(ClothesConfig.Kinds) do
		local item, colour = pick(kind)
		if item == nil or colour == nil then
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
			copy.Color = fixed or colour
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
	return folder
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
