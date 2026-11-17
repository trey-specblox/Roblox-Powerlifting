--!strict
--[[
	ClothesConfig
	Shared / Config

	The lifter body and the plain basic clothes (GAME_DESIGN.md §38.5-38.6, user 2026-11-12).

	The body (GAME_DESIGN §38.7, the cartoon style, user 2026-11-12): every character gets one of the cartoon lifter
	bodies (Bodies: the six production builds of CartoonBodies_05 on the torso-tall skeleton; every animation re-made
	for it); the player keeps their own full-size head. Which build a lifter gets comes from their bodyweight and
	numbers (§38.1, LifterBuild); in Studio the workspace attribute "LifterBodyBuild" ("Skinny", "SkinnyFat", "Fat",
	"Fit", "Muscular", "BigBuff") picks one for a test. Live for everyone since 2026-11-16 (LiveEnabled); the workspace
	attribute "LifterBody" (true/false) overrides that in Studio.

	The clothes: one shirt, one bottom and one pair of shoes, in any of Colours. Every piece is a skinned mesh in the
	build's clothes model (Bodies[build].clothesAssetId, art/scripts/export_cartoon_08.py: the tee from
	build_cartoon_gear_07.py, the rest from build_cartoon_gear_05.py), named "<Item>__<Part>",
	worn over the body part <Part> and bending with it. Basic clothes are free (`free`); clothing stores come later (the
	save keeps a list of owned clothes for them).

	The gear toggle: gear ON wears the gear slots (WornGearConfig) and, when a singlet or suit is worn, takes the
	bottom off so the legs show; the shirt stays on, WHOLE, under it (user 2026-11-16: gear is an accessory worn over the
	clothes, it never removes or cuts anything under it; gear v6, art/scripts/build_cartoon_gear_06.py: the tee and the
	singlet are both built on the body's own mesh, stacked, so they bend together. The suits are still v5's).
	Gear OFF wears the outfit alone.
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
	-- This build's clothes (art/scripts/export_cartoon_07.py, materials.json "CartoonClothes07_<Build>", uploaded
	-- 2026-11-15); 0 = not uploaded yet.
	clothesAssetId: number,
	-- Each hand's grip on the squat bar, from the bar's centre (studs; Character Animation Quality.md §4.1b): a
	-- little outside the shoulders, wide only on the big builds. For the game's per-build squat hold.
	squatGrip: number,
}

-- The production cartoon bodies (2026-11-15, materials.json "CartoonBody08_<Build>": CartoonBodies_05, the torso-tall
-- skeleton, arms x1.5, the OPEN hand as the body's own hand; since 2026-11-16 on the LONGER legs, knee 1.00 (was 1.178,
-- the 05 uploads); exported by art/scripts/export_cartoon_body_08.py, every number here from
-- art/exports/CartoonExport05.json). squatBarRest = the §4.1b bar centre behind the spine (0.51 / 0.52 /
-- 0.85 / 0.64 / 0.93 / 1.08) moved into the UpperTorso's own space (its centre isn't on the spine); benchBarClear = the
-- chest's front from the UpperTorso's centre + the bar's radius 0.07 + 0.07 for the tee and singlet. Replaced the
-- three block-skeleton fist bodies (Skinny 129935421578716, Heavy 86964380216834, Muscular 92735685532150).
ClothesConfig.Bodies = {
	Skinny = { assetId = 89940499075640, neckMark = Vector3.new(0, 1.0255, 0.0013), squatBarRest = 0.511,
		squatGrip = 1.55, benchBarClear = 0.581, clothesAssetId = 83677300602965 },
	SkinnyFat = { assetId = 119724826023810, neckMark = Vector3.new(0, 0.9993, 0.0838), squatBarRest = 0.604,
		squatGrip = 1.66, benchBarClear = 0.486, clothesAssetId = 135333972488670 },
	Fat = { assetId = 113520176766393, neckMark = Vector3.new(0, 0.9503, 0.179), squatBarRest = 1.029,
		squatGrip = 2.05, benchBarClear = 0.711, clothesAssetId = 114662706829485 },
	Fit = { assetId = 102399068343184, neckMark = Vector3.new(0, 0.9552, -0.0155), squatBarRest = 0.624,
		squatGrip = 1.87, benchBarClear = 0.69, clothesAssetId = 82908685773387 },
	Muscular = { assetId = 93479186515150, neckMark = Vector3.new(0, 0.8869, -0.0172), squatBarRest = 0.913,
		squatGrip = 2.17, benchBarClear = 0.754, clothesAssetId = 101044753006455 },
	BigBuff = { assetId = 127501040475668, neckMark = Vector3.new(0, 0.8354, -0.0047), squatBarRest = 1.075,
		squatGrip = 2.35, benchBarClear = 0.847, clothesAssetId = 138927065217215 },
} :: { [string]: Body }
ClothesConfig.DefaultBuild = "Skinny"
ClothesConfig.StudioBuildAttribute = "LifterBodyBuild"

-- The clothes are remade for the cartoon bodies (one model per build, Bodies[build].clothesAssetId); shown once uploaded.
-- (The realistic body's clothes, 122615782726867, are no longer used.)
ClothesConfig.ClothesShown = true

-- On in the live game: the user watched a full meet in Studio and approved going live (2026-11-16: "lets just go live",
-- skipping the phone test).
ClothesConfig.LiveEnabled = true
ClothesConfig.StudioEnabled = true
ClothesConfig.StudioAttribute = "LifterBody"

-- The Root joint's height above the floor: the torso-tall skeleton keeps the R15 block rig's legs (GAME_DESIGN §38.2,
-- user 2026-11-13: HipHeight 2.0, the root node at 3.0; every animation re-made on that rig), and the player's head at
-- its own size. (2.4 was the taller rig's, before.)
ClothesConfig.HipHeight = 2.0
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
