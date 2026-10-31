--!strict
--[[
	ShopConfig
	Shared / Config

	The Shop's catalogue (GAME_DESIGN.md 30.6, the money system's step 4):
	cosmetic gear bought with coins. APPEARANCE ONLY: nothing here changes a
	lift. The server reads the prices from here (never from a client); the
	client reads the same list to draw the menu.

	Each item is one of the Shop's Blender gear models (ServerStorage.
	PropTemplates.ShopGear_01, every logo says CENTRAL) in its own colours:
	`colours` maps a part of the model ("<Model>_<Part>", e.g. LeverBelt_Outer)
	to its colour. Parts not listed keep the model's own colour.

		LeverBelt         Outer, Lining, Stitch, Lever, Text
		KneeSleeve        Body, Stripes, Patch
		WristWrap         Body, Tail, Stripes, Text
		MannequinSinglet  Black (the body), Red (side panels), Trim, Patch,
		                  Shorts, ShortsRed (the stand and form stay)

	[PROVISIONAL] prices, about 150 to 1,500 coins (GAME_DESIGN 30.6). A new
	item is one more line; an item's `id` is saved in players' inventories,
	so never rename or reuse one.
]]

local ShopConfig = {}

export type Item = {
	id: string,
	name: string,
	category: string,
	model: string,
	colours: { [string]: Color3 },
	price: number,
}

-- The invisible point at the Shop's counter (RoomProps), where the "Browse the shop" prompt sits.
ShopConfig.CounterTag = "ShopCounter"
ShopConfig.PromptDistanceStuds = 8
ShopConfig.PromptHoldSeconds = 0.3
-- A purchase is refused unless the player stands this close to the counter.
ShopConfig.MaxBuyDistanceStuds = 24

-- The menu's tabs, in order.
ShopConfig.Categories = { "BELTS", "KNEE SLEEVES", "WRIST WRAPS", "SINGLETS" }

local rgb = Color3.fromRGB
local BLACK, WHITE, STEEL = rgb(22, 22, 24), rgb(238, 238, 238), rgb(150, 152, 158)
local GOLD, NAVY, YELLOW = rgb(214, 170, 52), rgb(20, 30, 74), rgb(250, 206, 36)

ShopConfig.Items = {
	-- Belts.
	{ id = "belt_black", name = "Classic Black Belt", category = "BELTS", model = "LeverBelt", price = 500,
		colours = { Outer = BLACK, Lining = rgb(190, 28, 36), Stitch = rgb(78, 78, 82), Lever = STEEL, Text = WHITE } },
	{ id = "belt_royal", name = "Royal Blue Belt", category = "BELTS", model = "LeverBelt", price = 600,
		colours = { Outer = rgb(28, 74, 196), Lining = BLACK, Stitch = WHITE, Lever = STEEL, Text = WHITE } },
	{ id = "belt_forest", name = "Forest Green Belt", category = "BELTS", model = "LeverBelt", price = 600,
		colours = { Outer = rgb(28, 104, 58), Lining = rgb(232, 224, 200), Stitch = rgb(232, 224, 200), Lever = STEEL,
			Text = rgb(232, 224, 200) } },
	{ id = "belt_violet", name = "Violet Belt", category = "BELTS", model = "LeverBelt", price = 700,
		colours = { Outer = rgb(106, 46, 168), Lining = rgb(250, 160, 200), Stitch = rgb(250, 160, 200), Lever = STEEL,
			Text = WHITE } },
	{ id = "belt_gold", name = "Gold Standard Belt", category = "BELTS", model = "LeverBelt", price = 900,
		colours = { Outer = GOLD, Lining = BLACK, Stitch = BLACK, Lever = rgb(60, 60, 64), Text = BLACK } },

	-- Knee sleeves.
	{ id = "sleeves_black", name = "Blackout Sleeves", category = "KNEE SLEEVES", model = "KneeSleeve", price = 300,
		colours = { Body = BLACK, Stripes = rgb(70, 70, 74), Patch = WHITE } },
	{ id = "sleeves_navy", name = "Central Navy Sleeves", category = "KNEE SLEEVES", model = "KneeSleeve", price = 350,
		colours = { Body = NAVY, Stripes = YELLOW, Patch = YELLOW } },
	{ id = "sleeves_teal", name = "Teal Sleeves", category = "KNEE SLEEVES", model = "KneeSleeve", price = 350,
		colours = { Body = rgb(18, 140, 140), Stripes = WHITE, Patch = BLACK } },
	{ id = "sleeves_pink", name = "Flamingo Sleeves", category = "KNEE SLEEVES", model = "KneeSleeve", price = 400,
		colours = { Body = rgb(236, 96, 150), Stripes = WHITE, Patch = WHITE } },

	-- Wrist wraps.
	{ id = "wraps_classic", name = "Classic Wraps", category = "WRIST WRAPS", model = "WristWrap", price = 150,
		colours = { Body = BLACK, Tail = BLACK, Stripes = rgb(190, 28, 36), Text = WHITE } },
	{ id = "wraps_ice", name = "Ice Wraps", category = "WRIST WRAPS", model = "WristWrap", price = 200,
		colours = { Body = WHITE, Tail = WHITE, Stripes = rgb(70, 146, 255), Text = rgb(20, 60, 140) } },
	{ id = "wraps_blaze", name = "Blaze Wraps", category = "WRIST WRAPS", model = "WristWrap", price = 200,
		colours = { Body = rgb(240, 120, 24), Tail = rgb(240, 120, 24), Stripes = BLACK, Text = BLACK } },
	{ id = "wraps_lime", name = "Lime Wraps", category = "WRIST WRAPS", model = "WristWrap", price = 250,
		colours = { Body = rgb(150, 210, 40), Tail = rgb(150, 210, 40), Stripes = rgb(30, 60, 30), Text = rgb(30, 60, 30) } },

	-- Singlets.
	{ id = "singlet_central", name = "Central Navy Singlet", category = "SINGLETS", model = "MannequinSinglet", price = 800,
		colours = { Black = NAVY, Red = YELLOW, Trim = YELLOW, Patch = YELLOW, Shorts = NAVY, ShortsRed = YELLOW } },
	{ id = "singlet_red", name = "Meet Day Red Singlet", category = "SINGLETS", model = "MannequinSinglet", price = 900,
		colours = { Black = rgb(190, 28, 36), Red = BLACK, Trim = WHITE, Patch = WHITE, Shorts = rgb(190, 28, 36),
			ShortsRed = BLACK } },
	{ id = "singlet_teal", name = "Lagoon Singlet", category = "SINGLETS", model = "MannequinSinglet", price = 1000,
		colours = { Black = rgb(18, 140, 140), Red = WHITE, Trim = WHITE, Patch = WHITE, Shorts = rgb(18, 140, 140),
			ShortsRed = WHITE } },
	{ id = "singlet_gold", name = "Black & Gold Singlet", category = "SINGLETS", model = "MannequinSinglet", price = 1500,
		colours = { Black = BLACK, Red = GOLD, Trim = GOLD, Patch = GOLD, Shorts = BLACK, ShortsRed = GOLD } },
} :: { Item }

-- The item with this id, or nil.
function ShopConfig.find(id: string): Item?
	for _, item in ipairs(ShopConfig.Items) do
		if item.id == id then
			return item
		end
	end
	return nil
end

return ShopConfig
