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
KitchenConfig.PanZones = 40
KitchenConfig.ZoneColumns = 8
-- Studs between zone centres, across and front to back.
-- (Across: the pan is about 45 studs with its handle, so 52 keeps each handle out of the next zone; Studio 2026-11-19.)
KitchenConfig.ZonePitch = Vector2.new(52, 48)
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
