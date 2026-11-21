--!strict
--[[
	KitchenConfig
	Shared / Config

	Steaks and the Kitchen (GAME_DESIGN §40.7, user 2026-11-19):

		- put any number of steaks in the cooker; they cook into one meal (more steaks = a bigger meal, a longer cook)
		- each steak costs PricePerSteak coins and adds SecondsPerSteak to the cooking time; coins only, never Robux
		- it cooks while you're away, even offline; one cook at a time
		- eating the meal boosts TRAINING gains (strength and technique) by steakPercent(steaks) for BoostHours

	Shared so the cooker's menu shows exactly the numbers the server uses.
]]

local WChewsLayout = require(script.Parent:WaitForChild("WChewsLayout"))

local KitchenConfig = {}

-- Coins per steak (user's pick).
KitchenConfig.PricePerSteak = 25
-- Seconds of cooking each steak adds (user's pick).
KitchenConfig.SecondsPerSteak = 10
-- How long an eaten meal boosts training (user: "24 hours").
KitchenConfig.BoostHours = 24
-- A safety limit, not a design one (about 28 hours of cooking and 250,000 coins).
KitchenConfig.MaxSteaksPerCook = 10000

--[[
	THE PAN HALL (GAME_DESIGN §40.7, user 2026-11-19): every player in the server gets a pan zone (one per player, up to
	PanZones), a giant pan with a giant clock behind it; their cook shows as ONE big steak in it, sized by the number of
	steaks ("hugee like a person size, maby multiple person size"). The hall is off the map like the meet venues (an
	entrance building in the front square comes with the building); HallOrigin places it, so the map design can move it.
	Zones face -Z (toward the hall's entrance) in rows of ZoneColumns.
]]
KitchenConfig.HallOrigin = CFrame.new(4000, 1000, 0)
-- Where the chef stands (in the hall's space): at the front, between the entrance and the first row of pans, facing the
-- entrance (-Z). The meat grinder stands in front of him to his left, its spout toward the hall's middle line (+X), so
-- the meat mound grows out in the open in front of him (2026-11-21, chef scene: beside him with the spout toward the
-- entrance, the meat he held up hit its hopper when he turned to the pans, which are all behind him, +Z). From his spot
-- the grinder is then always behind him when he faces any pan, and the biggest mound (22 studs) still stops short of him.
--
-- W CHEWS, FLOOR PLAN 02 (user 2026-11-21: "enter in the middle ... straight across you'll see the kitchen and the
-- process"; art/previews/WChews_FloorPlan_02.png). The plan's numbers live in WChewsLayout (generated from
-- art/scripts/wchews_layout.py) in PLAN space: x across (+x = the walking-in player's right), y front to back, z up.
-- planSpot turns a plan point into the hall's space: (-x, z, y) (measured: that is where a Blender point lands).
-- `turn`: degrees anticlockwise seen from above; 0 = facing the entrance (-Z).
function KitchenConfig.planSpot(x: number, y: number, z: number?, turn: number?): CFrame
	return CFrame.new(-x, z or 0, y) * CFrame.Angles(0, math.rad(turn or 0), 0)
end
-- The chef stands behind his service counter on the centre line, facing the entrance (-Z). The grinder stands straight
-- behind him in the kitchen, its outlet toward the entrance, pouring into the meat display bay.
KitchenConfig.ChefSpot = KitchenConfig.planSpot(WChewsLayout.Chef.X, WChewsLayout.Chef.Y)
KitchenConfig.GrinderSpot = KitchenConfig.planSpot(WChewsLayout.Grinder.X, WChewsLayout.Grinder.Y)
-- The grinder model (about 9.7 studs tall at scale 1) is scaled up so it reads from the doors and a cow fits its tub.
KitchenConfig.GrinderScale = WChewsLayout.GrinderScale
-- The chef scene (KitchenScene): a bag for cooks under CowFrom steaks, a cow from there, and more cows from
-- ExtraCowsFrom (one more each time the count doubles, up to MaxCows).
KitchenConfig.CowFrom = 100
KitchenConfig.ExtraCowsFrom = 1000
KitchenConfig.MaxCows = 4
-- The chef's moves in the chef scene (art/scripts/chef_animations.py). They play on the cooking player's own copy of
-- the chef (KitchenScene).
KitchenConfig.ChefAnimations = {
	ButtonPress = "rbxassetid://111057903603358", -- 1.6 s: looks down, lifts his open right hand, slaps the palm on the button
	Walk = "rbxassetid://507777826", -- Roblox's own R15 walk (as the computer lifters'), made for 9 studs a second
}
-- The scoop / carry / throw scene's moves (2026-11-21, replaced the same day by the W Chews scene): kept, not loaded.
KitchenConfig.ChefAnimationsUnused = {
	ScoopLift = "rbxassetid://117821048478188",
	Hold = "rbxassetid://78128363970640",
	Throw = "rbxassetid://128406849556919",
}
KitchenConfig.ChefWalkSpeed = 7 -- studs per second
-- Chef_ButtonPress: its length, when the palm lands (seconds in), and where his right hand is then, from his root:
-- HandAhead in front of him, HandRight to his right, 0.28 below the root, 2.72 above the floor (measured in Studio on
-- the Fat build, 2026-11-21). The scene stands him so the button is under it; the button panel's scale (0.6, in
-- art/scripts/wchews_layout.py) puts the button's top 2.5 above the floor, under his palm.
KitchenConfig.ChefPress = { Seconds = 1.6, Press = 0.62, HandAhead = 2.23, HandRight = 0.57 }
-- The meat in the tube: how many lumps, how big, how far apart in time, and how long the run from the bay to the pan
-- takes (the path's length / 150 studs a second, kept between these).
KitchenConfig.TubeLumps = 7
KitchenConfig.TubeLumpSize = 2.6
KitchenConfig.TubeLumpGap = 0.14
KitchenConfig.TubeMinSeconds = 2.4
KitchenConfig.TubeMaxSeconds = 3.6

-- The Kitchen's sounds (ElevenLabs, art/sounds/elevenlabs_shouts.json; user's go-ahead 2026-11-20).
KitchenConfig.Sounds = {
	Sizzle = "rbxassetid://140335319453723", -- a seamless loop on cooking pans
	Grinder = "rbxassetid://99489705613915",
	CowMoo = "rbxassetid://116016869694788",
	BagThud = "rbxassetid://74704226139703",
	MeatLand = "rbxassetid://114323852821853",
	Eat = "rbxassetid://119322748175840",
	ChefLine = "rbxassetid://110659636124322", -- "Alright, I'll handle this for you!"
	ChefWelcome = "rbxassetid://117853087157699", -- "Hey, welcome into W Chews!" (said "Double-u Chews"; the restaurant)
	-- The W Chews scene's machine sounds (user 2026-11-21: "Make the sound new sound affects").
	Button = "rbxassetid://88662812930499", -- 0.31 s: the chef's palm on the start button, one clunk
	Buzzer = "rbxassetid://91215560990283", -- 1.18 s: the machine's start buzzer, right after the clunk (played quietly)
	Chute = "rbxassetid://100812110878986", -- 1.11 s: the bag or cow rumbling down the ceiling chute (the thud follows)
	Tube = "rbxassetid://138689375274677", -- 3.17 s: the meat drawn up the funnel and rushing along the tube
	Plop = "rbxassetid://84379172787367", -- 0.33 s: ONE lump landing on the pan (played for every lump after the first)
}

-- What drops into the grinder for a cook of `steaks`: "Bag" or "Cow", and how many.
function KitchenConfig.sceneDrops(steaks: number): (string, number)
	if steaks < KitchenConfig.CowFrom then
		return "Bag", 1
	end
	local cows, need = 1, KitchenConfig.ExtraCowsFrom
	while steaks >= need and cows < KitchenConfig.MaxCows do
		cows += 1
		need *= 2
	end
	return "Cow", cows
end

-- The chef scene's beats, in seconds (about 18 s for one bag; it was about 7 and read as rushed, user 2026-11-21).
KitchenConfig.DropSeconds = 1.3 -- a bag or cow falling into the hopper
KitchenConfig.DropGap = 0.45 -- between cows
KitchenConfig.GrindSeconds = 3.2 -- the grinder churning, the meat mound growing (the chef walks over meanwhile)
KitchenConfig.HoldSeconds = 2.4 -- the meat held up high while he says his line
KitchenConfig.CarrySpeed = 5.5 -- studs a second, carrying the meat back to his spot (a little slower than his walk)
KitchenConfig.FlightSeconds = 1.8 -- the meat flying to the pan
KitchenConfig.LandingSeconds = 2.5 -- the landing, steam and the steak in the pan
-- The entrance house in the front square between the Nationals building and the State arena, its front toward the gym
-- (+Z). The map design comes last (user), so this one point moves it.
KitchenConfig.EntranceOrigin = CFrame.new(17, 0, -105) * CFrame.Angles(0, math.pi, 0)
-- The hall shell's placement (its bounds' bottom middle, in the hall's space) and its exit door (hall space).
-- (WChewsHall_01's bounds: plan x -287..287, y -112..339, z -1..37.)
KitchenConfig.HallShellAt = KitchenConfig.planSpot(0, 113.5, -1)
KitchenConfig.ExitSpot = KitchenConfig.planSpot(0, -107, 3)
-- The tag on the arrival spot (the Teleport menu's KITCHEN stop).
KitchenConfig.ArriveTag = "KitchenArrive"
-- Where a lifter arrives in the hall (in the hall's space), facing the chef.
-- (just inside the glass doors, looking down the carpet at the chef, the display bay and the grinder)
KitchenConfig.ArriveSpot = KitchenConfig.planSpot(0, -100, 3, 180)
KitchenConfig.PanZones = 40
KitchenConfig.ZoneColumns = 8
-- Studs between zone centres, across and front to back.
-- (Across: the pan is about 45 studs with its handle, so 52 keeps each handle out of the next zone; Studio 2026-11-19.)
KitchenConfig.ZonePitch = Vector2.new(52, 48)
-- The centre of pan zone `index` (1..PanZones) on the hall's floor, in the hall's space: plan 02 has 20 pans each side
-- of the grinder station (WChewsLayout.PanColumns x PanRows), filled front row first, from the player's left.
function KitchenConfig.zoneSpot(index: number): CFrame
	local columns = WChewsLayout.PanColumns
	local column = (index - 1) % #columns
	local row = (index - 1) // #columns
	return KitchenConfig.planSpot(columns[column + 1], WChewsLayout.PanRows[row + 1])
end
-- The pan (KitchenPan_01 GiantPan, about 12.7 studs across at scale 1) and the clock behind it are scaled up.
KitchenConfig.PanScale = 2.2
KitchenConfig.ClockScale = 1.4
-- How far the scaled pan sinks into the hall floor (studs), so its rim is about chest height and the steak shows: at
-- full height the rim would be about 10 studs up, over everyone's head. Only the top of the burner stand shows.
KitchenConfig.PanSink = 4.5
-- The pan's floor above the ground at scale 1, and the clock post's distance behind the pan's centre (Blender units).
KitchenConfig.PanFloorHeight = 3.2
KitchenConfig.ClockBehind = 8.0

--[[
	How long the big steak is (studs) for a cook of `steaks`: about a person long (5 studs) for one steak, about five
	people (28 studs) at 500, still growing past that, but never past MaxSteakLength (bigger than the pan on purpose:
	huge cooks spill over).
]]
KitchenConfig.MaxSteakLength = 44
function KitchenConfig.steakLength(steaks: number): number
	if typeof(steaks) ~= "number" or steaks ~= steaks or steaks < 1 then
		return 0
	end
	return math.min(5 * steaks ^ 0.28, KitchenConfig.MaxSteakLength)
end

-- RoomProps / the Kitchen building tags the cooker's spot; KitchenService puts the "Cook" prompt there.
KitchenConfig.CookerSpotTag = "KitchenCookerSpot"
-- The tag the client looks for on the cooker's prompt.
KitchenConfig.PromptTag = "KitchenCookerPrompt"

--[[
	§25's table (user): steaks in one cook -> training boost in percent. Between two rows the boost rises in a straight
	line; past the last row it keeps rising more slowly, as the table's last rows do (a power curve through the last
	row: 1,000 steaks is about +408%). Infinite stacking: every extra steak still adds a little.
]]
KitchenConfig.Table = {
	{ 1, 1 },
	{ 2, 2 },
	{ 5, 5 },
	{ 10, 10 },
	{ 25, 24 },
	{ 50, 45 },
	{ 100, 80 },
	{ 250, 150 },
	{ 500, 250 },
} :: { { number } }
local PAST_TABLE_POWER = math.log(250 / 80) / math.log(500 / 100)

-- The training boost in percent that a meal of `steaks` steaks gives (0 for none).
function KitchenConfig.steakPercent(steaks: number): number
	if typeof(steaks) ~= "number" or steaks ~= steaks or steaks < 1 then
		return 0
	end
	local rows = KitchenConfig.Table
	for index = 2, #rows do
		local low, high = rows[index - 1], rows[index]
		if steaks <= high[1] then
			local share = (steaks - low[1]) / (high[1] - low[1])
			return low[2] + (high[2] - low[2]) * math.max(share, 0)
		end
	end
	local last = rows[#rows]
	return last[2] * (steaks / last[1]) ^ PAST_TABLE_POWER
end

function KitchenConfig.cost(steaks: number): number
	return steaks * KitchenConfig.PricePerSteak
end

function KitchenConfig.cookSeconds(steaks: number): number
	return steaks * KitchenConfig.SecondsPerSteak
end

-- Whether `steaks` is a steak count a cook accepts: a whole number from 1 to MaxSteaksPerCook.
function KitchenConfig.isSteakCount(steaks: any): boolean
	return typeof(steaks) == "number" and steaks == math.floor(steaks) and steaks >= 1
		and steaks <= KitchenConfig.MaxSteaksPerCook
end

-- "+80%" / "+12.5%".
function KitchenConfig.percentText(percent: number): string
	if math.abs(percent - math.floor(percent + 0.5)) < 0.05 then
		return string.format("+%d%%", math.floor(percent + 0.5))
	end
	return string.format("+%.1f%%", percent)
end

-- "1:23:45" or "4:05".
function KitchenConfig.clockText(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

assert(KitchenConfig.PricePerSteak >= 1 and KitchenConfig.PricePerSteak == math.floor(KitchenConfig.PricePerSteak),
	"[KitchenConfig] PricePerSteak must be a whole number of coins")
assert(KitchenConfig.SecondsPerSteak > 0 and KitchenConfig.BoostHours > 0, "[KitchenConfig] times must be above zero")
for index = 2, #KitchenConfig.Table do
	assert(KitchenConfig.Table[index][1] > KitchenConfig.Table[index - 1][1]
		and KitchenConfig.Table[index][2] > KitchenConfig.Table[index - 1][2], "[KitchenConfig] Table must rise")
end

return KitchenConfig
