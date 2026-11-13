--!strict
--[[
	GearService
	Server / Economy

	Wearing the Shop's gear (GAME_DESIGN.md 30.6, the money system's step 5).

		- GetGear answers what the player owns and wears (read only)
		- SetWorn puts an item on in a slot, or takes it off, after checking
		  the slot, that the item belongs in it (ShopConfig category) and,
		  through PlayerDataService.setWorn, that the player owns it
		- every R15 character is dressed in what its player wears (the worn
		  models, WornGearConfig.AssetId, loaded once and fitted by
		  WornGearFit), on every spawn and after every change

	- SetWornPiece puts on a piece of stat gear and ScrapPiece scraps one for coins
	  (GAME_DESIGN §35.12); the coins come from its rarity, never from a client

	- giveSuit makes a rare suit (a meet's drop or the admin panel; GAME_DESIGN §35.12), and a worn bench
	  shirt holds the arms forward. Previews of the worn-only models go to the menus.

	The worn models have no mass, no collision, no touch or query, no shadow. R6
	bodies are not dressed (the gear is fitted to R15). A worn piece's stats are read
	when a lift starts or training ticks (GearStats), so they work on any rig.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local WornGearConfig = require(ConfigFolder:WaitForChild("WornGearConfig"))
local EconomyFolder = Shared:WaitForChild("Economy")
local GearRemotes = require(EconomyFolder:WaitForChild("GearRemotes"))
local ShopRemotes = require(EconomyFolder:WaitForChild("ShopRemotes"))
local GearStats = require(EconomyFolder:WaitForChild("GearStats"))

local PlayerDataFolder = script.Parent.Parent:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))
local WornGearFit = require(script.Parent:WaitForChild("WornGearFit"))
local LifterBodyService = require(script.Parent:WaitForChild("LifterBodyService"))

local GearService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.3
local APPEARANCE_WAIT_SECONDS = 10

local started = false
local lastAsked: { [Player]: number } = {}
local pieces: WornGearFit.Pieces? = nil
local loadTried = false
local remotesSet: GearRemotes.RemoteSet? = nil
local armTracks: { [Model]: AnimationTrack } = {}
-- The suit an admin has set their own next meet to drop (AdminService), until it drops or they leave.
local forcedDrops: { [Player]: string } = {}
-- MockMeetService's way into a suit test (set when it starts; it needs this module, so not the other way round).
local testStarter: ((Player, string) -> (boolean, string))? = nil

-- (defined further down)
local cartoonGear: (string) -> Instance?

local function log(message: string, ...: any)
	print("[GearService] " .. string.format(message, ...))
end

-- Previews of the models only worn, never in the Shop's own gear file, for the menus (GearPreview finds them by `model`).
local function sharePreviews(loaded: WornGearFit.Pieces)
	local folder = ReplicatedStorage:FindFirstChild(ShopRemotes.PREVIEWS_NAME)
	if folder == nil then
		local made = Instance.new("Folder")
		made.Name = ShopRemotes.PREVIEWS_NAME
		made.Parent = ReplicatedStorage
		folder = made
	end
	for _, item in ipairs(ShopConfig.Items) do
		local slot = if item.rough then WornGearConfig.slot(item.slot or "BenchShirt") else nil
		local wornName = item.worn or (slot and slot.worn)
		local list = wornName and loaded[wornName]
		if slot and list and #list > 0 and (folder :: Instance):FindFirstChild(item.model) == nil then
			-- One leg is enough to see knee wraps, and half the triangles in a crate's reel of them.
			WornGearFit.previewModel(item.model, list, slot.id == "KneeSleeves").Parent = folder
		end
	end
end

-- The uploaded model's pieces (WornGearFit.fromModel), or nil when it is not uploaded or did not load.
local function loadPieces(): WornGearFit.Pieces?
	if loadTried then
		return pieces
	end
	loadTried = true
	if WornGearConfig.AssetId == 0 then
		warn("[GearService] the worn gear models are not uploaded yet (WornGearConfig.AssetId = 0): gear is saved but not drawn")
		return nil
	end
	local ok, problem = pcall(function()
		local loaded = game:GetService("InsertService"):LoadAsset(WornGearConfig.AssetId)
		local result, count = WornGearFit.fromModel(loaded)
		loaded:Destroy()
		pieces = result
		log("worn gear loaded: %d pieces", count)
		sharePreviews(result)
	end)
	if not ok then
		warn("[GearService] the worn gear models did not load (gear is saved but not drawn): " .. tostring(problem))
		pieces = nil
	end
	return pieces
end

-- One build's refitted gear model (WornGearConfig.CartoonAssetIds), loaded once; nil when not uploaded or not loaded.
local cartoonModels: { [string]: Instance } = {}
local cartoonTried: { [string]: boolean } = {}
function cartoonGear(build: string): Instance?
	if cartoonModels[build] or cartoonTried[build] then
		return cartoonModels[build]
	end
	cartoonTried[build] = true
	local id = WornGearConfig.CartoonAssetIds[build]
	if id == nil or id == 0 then
		return nil
	end
	local ok, loaded = pcall(function()
		return game:GetService("InsertService"):LoadAsset(id)
	end)
	local model = ok and loaded and (loaded :: Instance):FindFirstChildWhichIsA("Model")
	if model then
		model.Name = "CartoonGear_" .. build
		model.Parent = game:GetService("ServerStorage")
		cartoonModels[build] = model
		log("%s gear loaded", build)
	else
		warn("[GearService] the " .. build .. " gear did not load: " .. tostring(loaded))
	end
	return cartoonModels[build]
end

-- Holds the arms forward while a bench shirt is worn, on any R15 body. Every lift and machine animation takes over by itself.
local function holdArms(character: Model, wearing: boolean)
	local track = armTracks[character]
	if wearing and track == nil then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if humanoid and animator and humanoid.RigType == Enum.HumanoidRigType.R15 then
			local animation = Instance.new("Animation")
			animation.AnimationId = WornGearConfig.BenchShirtArmsAnimation
			local ok, loaded = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok then
				loaded.Priority = Enum.AnimationPriority.Movement
				loaded.Looped = true
				loaded:Play(0.3)
				armTracks[character] = loaded
				character.Destroying:Once(function()
					armTracks[character] = nil
				end)
			end
		end
	elseif not wearing and track then
		track:Stop(0.3)
		armTracks[character] = nil
	end
end

--[[
	Rebuilds the character's worn gear and clothes from the save. Safe to call any time. With the gear toggle off
	(GAME_DESIGN §38.6) no gear is worn; the clothes (LifterBodyService, on the lifter body only) go on after the gear,
	which decides whether the shorts/pants come off.
]]
local function dress(player: Player)
	local character = player.Character
	local saved = PlayerDataService.getWorn(player)
	if character == nil or saved == nil then
		return
	end
	local worn = if PlayerDataService.getGearOn(player) == false then {} else saved
	local made
	local build = character:GetAttribute("LifterBodyBuild")
	if LifterBodyService.hasBody(character) and typeof(build) == "string" then
		-- A cartoon body wears its build's refitted gear (the block-body pieces float off it).
		local model = if next(worn) then cartoonGear(build) else nil
		local rest = LifterBodyService.restFor(build)
		if model and rest then
			made = WornGearFit.dressCartoon(character, worn, model, rest)
		else
			made = WornGearFit.dress(character, {}, {})
		end
	else
		local loaded = if next(worn) then loadPieces() else nil
		made = WornGearFit.dress(character, worn, loaded or {})
	end
	holdArms(character, worn.BenchShirt ~= nil)
	LifterBodyService.dressOutfit(player, character, worn)
	if made > 0 then
		log("%s dressed: %d pieces", player.Name, made)
	end
end

local function viewFor(player: Player): GearRemotes.GearView?
	local owned = PlayerDataService.getOwnedItems(player)
	local wearing = PlayerDataService.getWorn(player)
	if owned == nil or wearing == nil then
		return nil
	end
	local tests: { [string]: { passed: boolean, waitSeconds: number } } = {}
	for suitId, test in pairs(PlayerDataService.getSuitTests(player) or {}) do
		tests[suitId] = { passed = test.passed == true, waitSeconds = math.max(0, (test.nextTryAt or 0) - os.time()) }
	end
	return { owned = owned, wearing = wearing, drawn = loadPieces() ~= nil, suitTests = tests,
		pieces = PlayerDataService.getPieces(player) or {}, wearingPieces = PlayerDataService.getWornPieces(player) or {} }
end

local function tooFast(player: Player): boolean
	local now = os.clock()
	if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
		return true
	end
	lastAsked[player] = now
	return false
end

local function setWorn(player: Player, slotId: any, itemId: any): (boolean, string, GearRemotes.GearView?)
	local slot = if typeof(slotId) == "string" then WornGearConfig.slot(slotId) else nil
	if slot == nil then
		return false, "Unknown gear slot.", nil
	end
	if itemId == false then
		local outcome = PlayerDataService.setWorn(player, slot.id, nil)
		if outcome ~= "TakenOff" then
			return false, "That didn't go through. Try again.", viewFor(player)
		end
		dress(player)
		local name = string.gsub(string.lower(slot.label), "^%l", string.upper)
		return true, name .. " taken off.", viewFor(player)
	end
	local item = if typeof(itemId) == "string" then ShopConfig.find(itemId) else nil
	if item == nil or item.category ~= slot.category then
		return false, "That doesn't go there.", nil
	end
	local outcome = PlayerDataService.setWorn(player, slot.id, item.id)
	if outcome == "NotOwned" then
		return false, "You don't own that. Gear comes from crates at the Shop.", viewFor(player)
	elseif outcome ~= "Worn" then
		return false, "That didn't go through. Try again.", viewFor(player)
	end
	dress(player)
	return true, string.format("Wearing the %s.", item.name), viewFor(player)
end

-- Puts on a piece of stat gear, in its own slot.
local function setWornPiece(player: Player, pieceId: any): (boolean, string, GearRemotes.GearView?)
	if typeof(pieceId) ~= "string" then
		return false, "Unknown gear.", nil
	end
	-- A rare suit is locked until the coach's test is passed (GAME_DESIGN §35.12).
	local owned = (PlayerDataService.getPieces(player) or {})[pieceId]
	if owned and GearStats.suit(owned.rarity) then
		local test = (PlayerDataService.getSuitTests(player) or {})[owned.rarity]
		if test == nil or not test.passed then
			return false, "Pass the coach's test first.", viewFor(player)
		end
	end
	local outcome = PlayerDataService.setWornPiece(player, pieceId)
	if outcome == "NotOwned" then
		return false, "You don't have that any more.", viewFor(player)
	elseif outcome ~= "Worn" then
		return false, "That didn't go through. Try again.", viewFor(player)
	end
	dress(player)
	local piece = (PlayerDataService.getPieces(player) or {})[pieceId]
	return true, if piece then "Wearing the " .. GearStats.pieceName(piece) .. "." else "Worn.", viewFor(player)
end

-- Scraps a piece; the coins are the server's, from the piece's rarity.
local function scrapPiece(player: Player, pieceId: any): (boolean, string, GearRemotes.GearView?)
	if typeof(pieceId) ~= "string" then
		return false, "Unknown gear.", nil
	end
	local piece = (PlayerDataService.getPieces(player) or {})[pieceId]
	local rarity = if piece then GearStats.rarity(piece.rarity) else nil
	if piece == nil or rarity == nil then
		return false, "You don't have that any more.", viewFor(player)
	end
	local outcome = PlayerDataService.scrapPiece(player, pieceId, rarity.scrap)
	if outcome == "IsWorn" then
		return false, "Take it off before you scrap it.", viewFor(player)
	elseif outcome ~= "Scrapped" then
		return false, "That didn't go through. Try again.", viewFor(player)
	end
	return true, string.format("Scrapped for %d coins.", rarity.scrap), viewFor(player)
end

--[[
	Gives a rare suit, by its id, and tells everyone when `announce` (a meet's drop; the admin panel doesn't).
	SERVER-ONLY: the caller checked why. Returns the piece's id, or nil.
]]
function GearService.giveSuit(player: Player, suitId: string, announce: boolean): string?
	local suit = GearStats.suit(suitId)
	if suit == nil then
		return nil
	end
	local id = PlayerDataService.grantPiece(player, { slot = suit.slot, rarity = suit.id, look = suit.look })
	if id and announce and remotesSet then
		local news: GearRemotes.SuitDropNews = { name = player.Name, userId = player.UserId, suitName = suit.name }
		remotesSet.suitDropped:FireAllClients(news)
	end
	return id
end

--[[
	Makes this player's next meet with a total drop this suit, or nothing special with nil. SERVER-ONLY: AdminService
	has checked the player is an admin.
]]
function GearService.setForcedDrop(player: Player, suitId: string?)
	forcedDrops[player] = suitId
end

function GearService.getForcedDrop(player: Player): string?
	return forcedDrops[player]
end

-- The forced suit, once: the meet that drops it uses it up.
function GearService.takeForcedDrop(player: Player): string?
	local suitId = forcedDrops[player]
	forcedDrops[player] = nil
	return suitId
end

-- Dresses the character again after something else changed what is worn (the suit test).
function GearService.redress(player: Player)
	dress(player)
end

-- Plays the coach's cutscene on this player's screen.
function GearService.playCutscene(player: Player, suitId: string, pieceId: string)
	if remotesSet and player.Parent then
		local news: GearRemotes.SuitCutsceneNews = { suitId = suitId, pieceId = pieceId }
		remotesSet.suitCutscene:FireClient(player, news)
	end
end

-- The big sound on this player's screen, for passing a test.
function GearService.celebrateTest(player: Player)
	if remotesSet and player.Parent then
		remotesSet.suitTestPassed:FireClient(player)
	end
end

function GearService.setTestStarter(starter: (Player, string) -> (boolean, string))
	testStarter = starter
end

-- Fits the gear again when a body part changes size (Roblox can scale an avatar a moment after it spawns).
local function refitOnResize(player: Player, character: Model)
	local pending = false
	for _, child in ipairs(character:GetChildren()) do
		local base = string.gsub(child.Name, "^Left", ""):gsub("^Right", "")
		if child:IsA("BasePart") and WornGearConfig.DefaultBody[base] then
			(child :: BasePart):GetPropertyChangedSignal("Size"):Connect(function()
				if pending then
					return
				end
				pending = true
				task.delay(0.5, function()
					pending = false
					if player.Character == character then
						dress(player)
					end
				end)
			end)
		end
	end
end

-- Dresses each new character once its player's data and avatar have loaded.
local function onCharacter(player: Player, character: Model)
	task.spawn(function()
		PlayerDataService.waitForData(player, 60)
		if not player:HasAppearanceLoaded() then
			local done = false
			local connection = player.CharacterAppearanceLoaded:Connect(function()
				done = true
			end)
			local start = os.clock()
			while not done and os.clock() - start < APPEARANCE_WAIT_SECONDS and player.Character == character do
				task.wait(0.2)
			end
			connection:Disconnect()
		end
		if player.Character == character then
			-- The lifter body first (once per character): the gear and clothes are fitted to whichever body it has.
			LifterBodyService.prepare(player, character)
			dress(player)
			refitOnResize(player, character)
		end
	end)
end

function GearService.start()
	if started then
		return
	end
	started = true
	local remotes = GearRemotes.createOnServer(ReplicatedStorage)
	remotesSet = remotes
	LifterBodyService.setRedress(dress)
	LifterBodyService.start()
	remotes.get.OnServerInvoke = function(player: Player): GearRemotes.GearView?
		if tooFast(player) then
			return nil
		end
		return viewFor(player)
	end
	remotes.set.OnServerInvoke = function(player: Player, slotId: any, itemId: any): (boolean, string, GearRemotes.GearView?)
		if tooFast(player) then
			return false, "One moment...", nil
		end
		return setWorn(player, slotId, itemId)
	end
	remotes.setPiece.OnServerInvoke = function(player: Player, pieceId: any): (boolean, string, GearRemotes.GearView?)
		if tooFast(player) then
			return false, "One moment...", nil
		end
		return setWornPiece(player, pieceId)
	end
	remotes.startTest.OnServerInvoke = function(player: Player, pieceId: any): (boolean, string)
		if tooFast(player) then
			return false, "One moment..."
		end
		if typeof(pieceId) ~= "string" or testStarter == nil then
			return false, "Unknown gear."
		end
		return testStarter(player, pieceId)
	end
	remotes.scrap.OnServerInvoke = function(player: Player, pieceId: any): (boolean, string, GearRemotes.GearView?)
		if tooFast(player) then
			return false, "One moment...", nil
		end
		return scrapPiece(player, pieceId)
	end
	task.spawn(loadPieces)
	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
		forcedDrops[player] = nil
	end)
end

return GearService
