--!strict
--[[
	EntranceConfig
	Shared / Config

	Meet entrances (GAME_DESIGN §36.4, decided by the user 2026-11-08): a lifter walks out to the bar in their own
	walk style, then, at State meets and up, stops for a short hype move before setting up. Every player owns the
	Default entrance; the others are saved per player (ProfileOperations.grantEntrance) and will come from crates
	(§35.9). Until then only the admin panel hands them out, for testing.

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
}

local EntranceConfig = {}

EntranceConfig.DefaultId = "Default"

EntranceConfig.Entrances = {
	Default = {
		name = "STANDARD",
		walkAnimationId = nil,
		walkSpeed = nil,
		hypeAnimationId = "rbxassetid://89625871512191",
		hypeSeconds = 3.0,
	},
	Swagger = {
		name = "SWAGGER",
		walkAnimationId = "rbxassetid://85475277226333",
		walkSpeed = 4.49,
		hypeAnimationId = "rbxassetid://102377451481538",
		hypeSeconds = 3.2,
	},
	Hype = {
		name = "HYPE",
		walkAnimationId = "rbxassetid://101259970458316",
		walkSpeed = 5.48,
		hypeAnimationId = "rbxassetid://110091133658573",
		hypeSeconds = 3.2,
	},
	Stomp = {
		name = "STOMP",
		walkAnimationId = "rbxassetid://105155362636460",
		walkSpeed = 3.5,
		hypeAnimationId = "rbxassetid://95478237981657",
		hypeSeconds = 3.0,
	},
} :: { [string]: Entrance }

-- The order they are listed in (the admin panel).
EntranceConfig.Order = { "Default", "Swagger", "Hype", "Stomp" }

-- The walk style covers only the last stretch of the walk out (studs), out on the platform where everyone watches; before
-- that the lifter walks at the usual speed. The whole State walk out is about 55 studs, so a slow walk style all the way
-- would add over 10 seconds to every attempt. [Claude's number, 2026-11-08]
EntranceConfig.StyleWalkStuds = 16

-- Meets where the hype move plays (the walk style plays at every meet): State and up (user 2026-11-08), so Local meets,
-- with 8 platforms at once, don't get longer. Keyed by the meet's level name, as CheerConfig.MeetLevels.
EntranceConfig.HypeMeetLevels = { State = true } :: { [string]: boolean }

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
	animationId = "rbxassetid://128059630802707",
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
