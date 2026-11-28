--!strict
--[[
	EntranceConfig
	Shared / Config

	Meet entrances (GAME_DESIGN §36.4, decided by the user 2026-11-08): a lifter walks out to the bar in their own
	walk style, then, at State meets and up, stops for a short hype move before setting up. Every player owns the
	Default entrance; the others are saved per player (ProfileOperations.grantEntrance) and will come from crates
	(§35.9). They are won at the celebration NPC's spin (user 2026-11-11, "Walk-outs at Hype Man"): the same rules as
	celebrations (CelebrationConfig.Spin): a reroll, 500 coins, the gear crates' odds by `rarity`, 250 back on a duplicate.
	The admin panel can still hand any out, for testing.

	The animations are made in Blender by art/scripts/entrance_animations.py and published by
	art/scripts/upload_animations.py. Each walk is made for its own speed: the server walks the body at
	`walkSpeed`, so the feet keep up with the floor. A walk with no id is Roblox's own walk at the meet's usual speed.
	An empty hype id means the hype move is skipped (until it is uploaded).

	Ids are never renamed or reused: saves keep them.
]]

export type Entrance = {
	name: string,
	-- The looped walk (Movement priority); nil = Roblox's own walk at LocalMeetConfig.WalkSpeed.
	walkAnimationId: string?,
	-- Studs per second the walk is made for (entrance_animations.py prints it).
	walkSpeed: number?,
	-- The hype move at the platform's edge (Action priority, plays once).
	hypeAnimationId: string,
	hypeSeconds: number,
	-- "Default" (everyone's) or a crate rarity (GearStatsConfig.Rarities' ids), for the spin.
	rarity: string,
	-- What players read on the spin card.
	description: string,
	-- The hype move's own sound track (ElevenLabs, lined up with the move, art/scripts/make_celebration_tracks.py);
	-- nil until made.
	hypeSoundtrack: string?,
}

local EntranceConfig = {}

EntranceConfig.DefaultId = "Default"

EntranceConfig.Entrances = {
	Default = {
		name = "STANDARD",
		walkAnimationId = nil,
		walkSpeed = nil,
		hypeAnimationId = "rbxassetid://72592066579768",
		hypeSeconds = 3.0,
		hypeSoundtrack = "rbxassetid://102810729209176",
		rarity = "Default",
		description = "The usual walk out, then two snaps of the belt and a clap. Everyone starts with it.",
	},
	Swagger = {
		name = "SWAGGER",
		walkAnimationId = "rbxassetid://136277987646154",
		walkSpeed = 4.49,
		hypeAnimationId = "rbxassetid://113760315926183",
		hypeSeconds = 3.2,
		hypeSoundtrack = "rbxassetid://131229618807163",
		rarity = "Common",
		description = "Chin up, hips swaying, shoulders rolling. At the bar: a double biceps flex, held shaking.",
	},
	Hype = {
		name = "HYPE",
		walkAnimationId = "rbxassetid://116342313694165",
		walkSpeed = 5.48,
		hypeAnimationId = "rbxassetid://82685066561591",
		hypeSeconds = 3.2,
		hypeSoundtrack = "rbxassetid://132691743560862",
		rarity = "Uncommon",
		description = "Bouncy and quick, arms pumping. At the bar: two chest slaps and a roar at the ceiling.",
	},
	Stomp = {
		name = "STOMP",
		walkAnimationId = "rbxassetid://87197265679464",
		walkSpeed = 3.5,
		hypeAnimationId = "rbxassetid://107939027917954",
		hypeSeconds = 3.0,
		hypeSoundtrack = "rbxassetid://93314994803157",
		rarity = "Rare",
		description = "Slow and heavy, leaning in, arms held out. At the bar: a neck roll, two claps, a point at the bar.",
	},
	-- The six from the user's meet videos (References/Clip Study, "Walk-ups" and "Pre-lift rituals"; user 2026-11-11).
	ArmUp = {
		name = "ARM UP",
		walkAnimationId = "rbxassetid://85143213883410",
		walkSpeed = 4.37,
		hypeAnimationId = "rbxassetid://133467207011703", -- (2026-11-28: palms turned up/forward, no twist; was 113191256245253)
		hypeSeconds = 3.0,
		hypeSoundtrack = "rbxassetid://138706907614994",
		rarity = "Common",
		description = "One arm straight up all the way out, calling for noise. At the bar: a clap overhead, arms flung out.",
	},
	Airplane = {
		name = "AIRPLANE",
		walkAnimationId = "rbxassetid://132159144036114",
		walkSpeed = 4.24,
		hypeAnimationId = "rbxassetid://123213175310289", -- (2026-11-28: palms turned up/forward, no twist; was 123372212100433)
		hypeSeconds = 3.2,
		hypeSoundtrack = "rbxassetid://107210658191384",
		rarity = "Uncommon",
		description = "Arms out like wings, banking side to side. At the bar: wings wide, then up into a V with a roar.",
	},
	RaiseRoof = {
		name = "RAISE THE ROOF",
		walkAnimationId = "rbxassetid://117509819811484",
		walkSpeed = 5.13,
		hypeAnimationId = "rbxassetid://83291392791079",
		hypeSeconds = 3.0,
		hypeSoundtrack = "rbxassetid://92238157521990",
		rarity = "Rare",
		description = "A bouncing walk with both hands pumping overhead. At the bar: slaps both traps, then a hard clap.",
	},
	CrowdLift = {
		name = "LIFT THE CROWD",
		walkAnimationId = "rbxassetid://118872777261167",
		walkSpeed = 4.35,
		hypeAnimationId = "rbxassetid://97506867734908",
		hypeSeconds = 3.2,
		hypeSoundtrack = "rbxassetid://137884153261912",
		rarity = "Epic",
		description = "Palms up, lifting the crowd with every stride. At the bar: two big lifts, then a point at the bar.",
	},
	SuperHeavy = {
		name = "SUPER HEAVY",
		walkAnimationId = "rbxassetid://74471440726726",
		walkSpeed = 3.87,   -- (user 2026-11-15: 2.59 was far too slow; the walk re-made at this speed)
		hypeAnimationId = "rbxassetid://82860928141865", -- (2026-11-28: palms turned up/forward, no twist; was 110603558183471)
		hypeSeconds = 3.4,
		hypeSoundtrack = "rbxassetid://103499626687975",
		rarity = "Epic",
		description = "The super-heavyweight walk: wide, rocking, arms off the body. At the bar: thigh slaps and a chalk clap.",
	},
	WarCry = {
		name = "WAR CRY",
		walkAnimationId = "rbxassetid://79114437201204",
		walkSpeed = 3.68,
		hypeAnimationId = "rbxassetid://86505939583381",
		hypeSeconds = 3.6,
		hypeSoundtrack = "rbxassetid://112103457438818",
		rarity = "Legendary",
		description = "A low prowl, arms swung back. At the bar: a trembling war crouch, then up roaring, arms out.",
	},
} :: { [string]: Entrance }

-- The order they are listed in (the admin panel).
EntranceConfig.Order = {
	"Default", "Swagger", "ArmUp", "Hype", "Airplane", "Stomp", "RaiseRoof", "CrowdLift", "SuperHeavy", "WarCry",
}

-- The walk style covers only the last stretch of the walk out (studs), out on the platform where everyone watches; before
-- that the lifter walks at the usual speed. The whole State walk out is about 55 studs, so a slow walk style all the way
-- would add over 10 seconds to every attempt. [Claude's number, 2026-11-08]
EntranceConfig.StyleWalkStuds = 16

-- Meets where the hype move plays (the walk style plays at every meet): every meet (user 2026-11-12: Local and Regional
-- get the entrances too, "no flashy cinematic, just to keep local and regionals quick but still a little styleish"; it was
-- State only, user 2026-11-08). The coach's ritual and its film-look walk-out shots stay State only. Keyed by the meet's
-- level name, as CheerConfig.MeetLevels.
EntranceConfig.HypeMeetLevels = { Local = true, Regional = true, State = true, Nationals = true } :: { [string]: boolean }

-- (Now only for a walk-out with no hype move, at a meet without them; every meet has them since 2026-11-12.)
-- Local and Regional meets, where no hype move plays: everyone's quick "game face" over the last steps of the walk out
-- (user 2026-11-08: those walk-outs "too bland, and not smooth", but not flashy or long). Two chalky claps, then both hands
-- tap the belt, arms only, so the legs keep walking; timed to end as the walk does, so it adds no time. `clapSeconds`: the
-- claps' moments in it (the ChalkClap sound). An empty id skips it (until it is uploaded).
export type QuickTouch = {
	animationId: string,
	seconds: number,
	clapSeconds: { number },
	clapVolume: number,
}
EntranceConfig.QuickTouch = {
	animationId = "rbxassetid://97330538941149",
	seconds = 1.5,
	clapSeconds = { 0.32, 0.56 },
	clapVolume = 0.6,
} :: QuickTouch

-- The entrance an id names, or nil for an unknown id.
function EntranceConfig.get(id: string?): Entrance?
	if typeof(id) ~= "string" then
		return nil
	end
	return EntranceConfig.Entrances[id]
end

-- Whether a walk style is uploaded and usable (computer lifters pick from these).
function EntranceConfig.hasWalk(entrance: Entrance): boolean
	return entrance.walkAnimationId ~= nil and entrance.walkAnimationId ~= "" and entrance.walkSpeed ~= nil
end

-- The uploaded walk styles, for computer lifters' random walks (the Default's Roblox walk included).
function EntranceConfig.computerWalks(): { string }
	local ids = {}
	for _, id in ipairs(EntranceConfig.Order) do
		local entrance = EntranceConfig.Entrances[id]
		if id == EntranceConfig.DefaultId or EntranceConfig.hasWalk(entrance) then
			table.insert(ids, id)
		end
	end
	return ids
end

return EntranceConfig
