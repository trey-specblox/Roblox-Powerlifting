--!strict
--[[
	ClothesConfig
	Shared / Config

	The lifter body and the plain basic clothes (GAME_DESIGN.md §38.5-38.6, user 2026-11-12).

	The body (GAME_DESIGN §38.7, the cartoon style, user 2026-11-12): every character gets one of the cartoon lifter
	bodies (art/scripts/build_cartoon_rig_02.py, uploaded as Bodies) on the original block skeleton, so every existing
	animation still fits; the player keeps their own full-size head. Which build a lifter gets will come from their
	progress (§38.1); until that is built everyone gets DefaultBuild, and in Studio the workspace attribute
	"LifterBodyBuild" ("Skinny", "Heavy", "Muscular") picks one for a test. On in Studio only for now (LiveEnabled
	false); the workspace attribute "LifterBody" (true/false) overrides that in Studio.

	The clothes: one shirt, one bottom and one pair of shoes, in any of Colours. Every piece is a skinned mesh in
	ClothesAssetId (art/scripts/build_clothes_01.py), named "<Item>__<Part>", worn over the body part <Part> and bending
	with it. Basic clothes are free (`free`); clothing stores come later (the save keeps a list of owned clothes for
	them). Those pieces were shaped for the realistic body (§38.5, dropped), so they stay off (ClothesShown false)
	until they are remade for the cartoon bodies; the outfit, the toggle and the save keep working meanwhile.

	The gear toggle: gear ON wears the gear slots (WornGearConfig) and, when a singlet or suit is worn, takes the
	bottom off so the legs show; the shirt stays on under it. Gear OFF wears the outfit alone.
]]

local ClothesConfig = {}

export type Body = {
	assetId: number,
	-- The Neck mark in the body's UpperTorso, where the player's head sits (art/exports/CartoonBody_<Build>_joints.json).
	neckMark: Vector3,
	-- Where the squat bar's centre rests, in the UpperTorso's own space (+Z is the back): on the upper back, whatever
	-- the hands do. The squat animation was made for the thinner block body, and each build's arms hang differently, so
	-- following the hands left the bar inside the back (gym) or floating above it (meet, muscular). Measured on the
	-- Blender meshes 2026-11-12: the back reaches 0.36 / 0.74 / 0.53 behind the chest's centre at the bar's height;
	-- plus the bar's radius 0.07, plus 0.07 for the shirt and the singlet over it (build_cartoon_gear_02.py layers: shirt 0.04, singlet 0.07).
	squatBarRest: number,
	-- The bench bar comes down to the chest but never into it: its centre stays at least this far in front of the
	-- UpperTorso's centre (-Z). Measured on the Blender meshes at each build's touch height 2026-11-12: the chest
	-- front is 0.31 / 0.46 / 0.45 in front; plus the bar's radius 0.07 (the heavy bar sank 0.16 into the chest), plus
	-- 0.07 for the shirt and singlet.
	benchBarClear: number,
	-- This build's clothes (art/scripts/build_cartoon_clothes_02.py, materials.json "CartoonClothes02_<Build>"); 0 = not
	-- uploaded yet.
	clothesAssetId: number,
}

-- The cartoon bodies (materials.json "CartoonBody_<Build>"). All on the taller rig's heights: HipHeight 2.4.
ClothesConfig.Bodies = {
	Skinny = { assetId = 129935421578716, neckMark = Vector3.new(0, 0.843, -0.0055), squatBarRest = 0.51,
		benchBarClear = 0.46, clothesAssetId = 0 },
	Heavy = { assetId = 86964380216834, neckMark = Vector3.new(0, 0.9778, 0.1493), squatBarRest = 0.87,
		benchBarClear = 0.61, clothesAssetId = 0 },
	Muscular = { assetId = 92735685532150, neckMark = Vector3.new(0, 0.7484, 0.0221), squatBarRest = 0.67,
		benchBarClear = 0.60, clothesAssetId = 0 },
} :: { [string]: Body }
ClothesConfig.DefaultBuild = "Skinny"
ClothesConfig.StudioBuildAttribute = "LifterBodyBuild"

-- The clothes are remade for the cartoon bodies (one model per build, Bodies[build].clothesAssetId); shown once uploaded.
-- (The realistic body's clothes, 122615782726867, are no longer used.)
ClothesConfig.ClothesShown = true

-- On in the live game only once the bodies are tested with the lifts in Studio.
ClothesConfig.LiveEnabled = false
ClothesConfig.StudioEnabled = true
ClothesConfig.StudioAttribute = "LifterBody"

-- The Root joint's height above the floor (the taller bodies, user 2026-11-12, art/scripts/lifter_heights.py: hips 2.0 ->
-- 2.4; every animation re-made on that rig), and the player's head at its own size.
ClothesConfig.HipHeight = 2.4
ClothesConfig.HeadScale = 1.0

-- Folder in the character holding the clothes (rebuilt whenever the outfit or the gear toggle changes).
ClothesConfig.FolderName = "Outfit"
-- Marks a character that has the lifter body.
ClothesConfig.BodyAttribute = "LifterBody"

ClothesConfig.Kinds = { "Shirt", "Bottom", "Shoes" }
ClothesConfig.KindLabels = { Shirt = "SHIRT", Bottom = "SHORTS / PANTS", Shoes = "SHOES" } :: { [string]: string }

export type Item = {
	id: string,
	kind: string,
	label: string,
	free: boolean,
	-- Pieces of the item that keep their own colour (a sneaker's sole), by piece prefix.
	fixed: { [string]: Color3 }?,
}

local WHITE = Color3.fromRGB(238, 238, 234)

ClothesConfig.Items = {
	-- The thick white cuffs, the doubled white waistband and its drawstrings stay white (References/Body Study.md).
	{ id = "Tee", kind = "Shirt", label = "T-SHIRT", free = true, fixed = { TeeWhite = WHITE } },
	{ id = "LongSleeve", kind = "Shirt", label = "LONG SLEEVE", free = true, fixed = { LongSleeveWhite = WHITE } },
	{ id = "Tank", kind = "Shirt", label = "TANK TOP", free = true },
	{ id = "Shorts", kind = "Bottom", label = "SHORTS", free = true, fixed = { ShortsWhite = WHITE } },
	{ id = "Joggers", kind = "Bottom", label = "JOGGERS", free = true, fixed = { JoggersWhite = WHITE } },
	{ id = "Sneakers", kind = "Shoes", label = "SNEAKERS", free = true,
		fixed = { SneakersSole = Color3.fromRGB(236, 234, 228) } },
} :: { Item }

export type Colour = { id: string, label: string, colour: Color3 }

-- Plain colours, many of them (user: props in many colours, never just red and black).
ClothesConfig.Colours = {
	{ id = "Black", label = "BLACK", colour = Color3.fromRGB(24, 24, 27) },
	{ id = "Charcoal", label = "CHARCOAL", colour = Color3.fromRGB(58, 60, 66) },
	{ id = "Grey", label = "GREY", colour = Color3.fromRGB(128, 131, 138) },
	{ id = "White", label = "WHITE", colour = Color3.fromRGB(232, 232, 228) },
	{ id = "Sand", label = "SAND", colour = Color3.fromRGB(196, 176, 140) },
	{ id = "Navy", label = "NAVY", colour = Color3.fromRGB(28, 40, 78) },
	{ id = "Royal", label = "ROYAL BLUE", colour = Color3.fromRGB(36, 84, 190) },
	{ id = "Sky", label = "SKY BLUE", colour = Color3.fromRGB(110, 170, 225) },
	{ id = "Teal", label = "TEAL", colour = Color3.fromRGB(24, 128, 128) },
	{ id = "Forest", label = "FOREST GREEN", colour = Color3.fromRGB(34, 86, 50) },
	{ id = "Olive", label = "OLIVE", colour = Color3.fromRGB(104, 106, 58) },
	{ id = "Red", label = "RED", colour = Color3.fromRGB(196, 36, 36) },
	{ id = "Maroon", label = "MAROON", colour = Color3.fromRGB(110, 26, 36) },
	{ id = "Orange", label = "ORANGE", colour = Color3.fromRGB(226, 112, 32) },
	{ id = "Yellow", label = "YELLOW", colour = Color3.fromRGB(236, 196, 48) },
	{ id = "Pink", label = "PINK", colour = Color3.fromRGB(226, 120, 160) },
	{ id = "Purple", label = "PURPLE", colour = Color3.fromRGB(96, 58, 150) },
} :: { Colour }

export type Choice = { item: string, colour: string }

-- What a new lifter wears (and what a broken save falls back to).
ClothesConfig.Default = {
	Shirt = { item = "Tee", colour = "Grey" },
	Bottom = { item = "Shorts", colour = "Black" },
	Shoes = { item = "Sneakers", colour = "White" },
} :: { [string]: Choice }

local itemsById: { [string]: Item } = {}
for _, item in ipairs(ClothesConfig.Items) do
	itemsById[item.id] = item
end
local coloursById: { [string]: Colour } = {}
for _, colour in ipairs(ClothesConfig.Colours) do
	coloursById[colour.id] = colour
end

function ClothesConfig.item(id: any): Item?
	return if typeof(id) == "string" then itemsById[id] else nil
end

function ClothesConfig.colour(id: any): Colour?
	return if typeof(id) == "string" then coloursById[id] else nil
end

function ClothesConfig.isKind(kind: any): boolean
	return kind == "Shirt" or kind == "Bottom" or kind == "Shoes"
end

-- Every item of one kind, in the menu's order.
function ClothesConfig.itemsOf(kind: string): { Item }
	local list = {}
	for _, item in ipairs(ClothesConfig.Items) do
		if item.kind == kind then
			table.insert(list, item)
		end
	end
	return list
end

return ClothesConfig
