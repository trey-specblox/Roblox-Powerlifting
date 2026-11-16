--!strict
--[[
	CelebrationConfig
	Shared / Config

	The celebrations after a good lift (GAME_DESIGN §36.4; user 2026-11-11). Each is a real lifter's celebration from the
	user's 15 meet videos, studied move by move (References/Clip Study/Celebration Catalogue.md: `source` is its CEL
	number) and animated in Blender (art/scripts/celebration_animations.py), uploaded under the game's group.

	For now (user's choice, 2026-11-11):
		- every lifter, players and computer lifters, does their celebration after a good lift at every meet (MeetLevels;
		  State only until 2026-11-12), its camera shots at State only (CinematicMeetLevels);
		- the rest are seen in the admin's celebration viewer; later they are unlocked from crates (by `rarity`), and
		  every player can browse them all there, to see what they could unbox.

	Each one:
		id, name           the id (the animation's name without "Celebrate_") and what players see
		rarity             "Default" (free) or a crate rarity (GearStatsConfig.Rarities' ids)
		animationId        its uploaded animation
		seconds            how long it lasts
		kind               "Standing": on the spot, then the lifter walks back
		                   "Walk": arms and head only, played over the walk back (real lifters never stop walking)
		                   "WalkLoop": arms and head only, looped over the WHOLE walk back, until the lifter is back at
		                   their waiting spot (user 2026-11-11: "a celebration that continues even when your going back
		                   to the bench"); `seconds` is one round; its sound track loops with it
		source             its entry in the catalogue
		soundtrack         its own sound track (user 2026-11-11: "Take all these celebrations, have elevenlabs make sound
		                   affects for it"): one ElevenLabs take made for its moves, lined up with its animation
		                   (art/scripts/make_celebration_tracks.py), played from the lifter as it starts
		events             { at, sound }: the body's sounds one by one (this file's Sounds, or MeetSoundConfig.Cues): only
		                   for a celebration without a soundtrack
		fx                 { at, kind, seconds? }: its visual effects (Fx below), drawn by every nearby player's game
		cinematic          (Legendary) the lifter's own camera cuts through these shots, with the arena lit for it

	Display and timing only: who may do which is decided on the server (CelebrationService).
]]

local CelebrationConfig = {}

export type Event = { at: number, sound: string?, effect: string? }
-- A visual effect (client CelebrationFx): kind "Shout" (rings and lines from the mouth), "Swoosh" (wind trails and
-- chalk dust off the hands), "Jump" (trails off the feet), "Dust" (a ring and dust on the floor), "KneeDust" (the same,
-- bigger, with chalk at the knees), "ChalkPuff" / "ChalkBurst" (chalk from the hands); `seconds` for the ones that last.
export type Fx = { at: number, kind: string, seconds: number? }
export type Shot = { at: number, shot: string }
export type Look = { tint: Color3, key: Color3, haze: number }
export type Cinematic = { shots: { Shot }, look: Look }
export type Celebration = {
	id: string,
	name: string,
	rarity: string,
	animationId: string,
	seconds: number,
	kind: string,
	source: string,
	description: string,
	soundtrack: string?,
	events: { Event },
	fx: { Fx },
	cinematic: Cinematic?,
}

-- Where a good lift gets a celebration: every meet (user 2026-11-12: "i want local and regionals to have these
-- celebration, fails, entrances etc. but no flashy cinematic, just to keep local and regionals quick but still a little
-- styleish"; before, State only).
CelebrationConfig.MeetLevels = { Local = true, Regional = true, State = true } :: { [string]: boolean }
-- Where a celebration's own camera shots (`cinematic`, client CelebrationCinema) play on the lifter's screen: State only.
CelebrationConfig.CinematicMeetLevels = { State = true } :: { [string]: boolean }

-- Everyone's, until crates hand out the others.
CelebrationConfig.Default = "ChalkClapPump"

-- The body's sounds in a celebration (user 2026-11-11: "We dont need voices for the celebrations, just have the sound
-- affect like knee thumping and stuff, just make them very clear and smooth"): ElevenLabs Sound Effects (prompts in
-- art/sounds/elevenlabs_shouts.json, CelebFx_*), cleaned by art/scripts/make_celebration_sounds.py: each starts right on
-- its hit and dies away like a real impact, with a smooth fade. A sound with several takes plays one at random, never the
-- same take twice in a row. An event naming a sound that is neither here nor in MeetSoundConfig.Cues plays nothing.
export type Sound = { ids: { string }, volume: number }
CelebrationConfig.Sounds = {
	CelebKnees = { ids = { "rbxassetid://109314144737773" }, volume = 0.85 },
	CelebLand = { ids = { "rbxassetid://92250222061931" }, volume = 0.8 },
	CelebSit = { ids = { "rbxassetid://102136677463296" }, volume = 0.7 },
	CelebFootTap = { ids = { "rbxassetid://107912176890186" }, volume = 0.55 },
	-- (This one's hit is 0.04 s into its file: its events are 0.04 s early.)
	CelebStomp = { ids = { "rbxassetid://115953996885187" }, volume = 0.75 },
} :: { [string]: Sound }

-- One take of a sound (random, never `last` again when there is another), or nil.
function CelebrationConfig.pickSound(name: string, last: string?): (string?, number)
	local sound = CelebrationConfig.Sounds[name]
	if sound == nil or #sound.ids == 0 then
		return nil, 0
	end
	local choices = {}
	for _, id in ipairs(sound.ids) do
		if id ~= last or #sound.ids == 1 then
			table.insert(choices, id)
		end
	end
	return choices[math.random(1, #choices)], sound.volume
end

-- How loud a soundtrack plays.
CelebrationConfig.SoundtrackVolume = 0.75

-- How far the celebration's sounds carry (studs: full volume near, silent far).
CelebrationConfig.SoundNear = 20
CelebrationConfig.SoundFar = 110

local function ev(at: number, sound: string?): Event
	return { at = at, sound = sound }
end

local function fx(at: number, kind: string, seconds: number?): Fx
	return { at = at, kind = kind, seconds = seconds }
end

-- Rarity order, for the viewer's list.
CelebrationConfig.RarityOrder = { "Default", "Common", "Uncommon", "Rare", "Epic", "Legendary" }

CelebrationConfig.List = {
	{
		id = "ChalkClapPump", name = "Chalk Clap & Pump", rarity = "Default", seconds = 3.0, kind = "Standing",
		animationId = "rbxassetid://101433631364198", source = "CEL-71",
		soundtrack = "rbxassetid://130751571992816",
		description = "A chalky clap at the chest, a proud beat, one fist pump. What real lifters do on an ordinary good lift.",
		events = { ev(0.42, "ChalkClap") },
		fx = { fx(0.42, "ChalkPuff"), fx(1.6, "Swoosh", 0.6) },
	},
	{
		id = "ExitFistPump", name = "Exit Fist Pump", rarity = "Common", seconds = 1.6, kind = "Walk",
		animationId = "rbxassetid://134859787250285", source = "CEL-59",
		soundtrack = "rbxassetid://100065691077554",
		description = "Never stops walking: one fist up beside the head on the way off. 'Opener done.'",
		events = {},
		fx = { fx(0.15, "Swoosh", 0.55) },
	},
	{
		id = "FistSalute", name = "Fist Salute", rarity = "Common", seconds = 2.4, kind = "Standing",
		animationId = "rbxassetid://90866174331816", source = "CEL-60",
		soundtrack = "rbxassetid://129076185496758",
		description = "A fist held up beside the head, upper arm level, looking up at the crowd. Calm and businesslike.",
		events = {},
		fx = { fx(0.08, "Swoosh", 0.4), fx(0.4, "ChalkPuff") },
	},
	{
		id = "MilitarySalute", name = "Military Salute", rarity = "Common", seconds = 3.0, kind = "Standing",
		animationId = "rbxassetid://85071617856836", source = "CEL-66",
		soundtrack = "rbxassetid://112831292294445",
		description = "Chest out, a crisp salute to the judges, then at attention. Dignified, not every unlock is a scream.",
		events = { ev(0.21, "CelebStomp") },
		fx = { fx(0.21, "Dust"), fx(0.35, "Swoosh", 0.35) },
	},
	{
		id = "WingspanHold", name = "Wingspan", rarity = "Uncommon", seconds = 3.4, kind = "Standing",
		animationId = "rbxassetid://85457936961427", source = "CEL-46",
		soundtrack = "rbxassetid://70393531422307",
		description = "Arms swing out into a T and hold, chin up, soaking it in. 'What did you expect?'",
		events = {},
		fx = { fx(0.15, "Swoosh", 0.8) },
	},
	{
		id = "ArmsUpBounce", name = "Arms Up Bounce", rarity = "Uncommon", seconds = 2.5, kind = "Standing",
		animationId = "rbxassetid://84884154138335", source = "CEL-49",
		soundtrack = "rbxassetid://101557833195011",
		description = "Both arms straight up, then bouncing on the toes with the arms out, laughing.",
		events = { ev(0.75, "CelebFootTap"), ev(1.15, "CelebFootTap"), ev(1.55, "CelebFootTap") },
		fx = { fx(0.05, "Swoosh", 0.4), fx(0.25, "Shout", 0.5), fx(0.75, "Dust"), fx(1.55, "Dust") },
	},
	{
		id = "SkyPoint", name = "Finger to the Sky", rarity = "Uncommon", seconds = 3.4, kind = "Walk",
		animationId = "rbxassetid://133328327237528", source = "CEL-51",
		soundtrack = "rbxassetid://108014192803753",
		description = "Walking off with one arm straight up, a finger to the sky, chin up. Unhurried, dominant.",
		events = {},
		fx = { fx(0.2, "Swoosh", 0.4) },
	},
	{
		id = "LightsArmsUp", name = "Wait for the Lights", rarity = "Rare", seconds = 3.8, kind = "Standing",
		animationId = "rbxassetid://90598922249245", source = "CEL-36",
		soundtrack = "rbxassetid://104407525026280",
		description = "Hands on hips, watching the judges... then both arms shoot straight up.",
		events = {},
		fx = { fx(1.3, "Swoosh", 0.45), fx(1.55, "Shout", 1.15), fx(1.6, "ChalkPuff") },
	},
	{
		id = "SitAndLaugh", name = "Sit Down and Laugh", rarity = "Rare", seconds = 5.2, kind = "Standing",
		animationId = "rbxassetid://113230523485052", source = "CEL-43",
		soundtrack = "rbxassetid://124071275481756",
		description = "Just sits down on the platform, leaning back on one hand, laughing up at the lights.",
		events = { ev(1.15, "CelebSit"), ev(3.55, "CelebFootTap"), ev(4.2, "CelebFootTap") },
		fx = { fx(1.15, "Dust") },
	},
	{
		id = "PointAndPrance", name = "Point & Prance", rarity = "Epic", seconds = 3.6, kind = "Standing",
		animationId = "rbxassetid://131527478336184", source = "CEL-26",
		soundtrack = "rbxassetid://126738208009576",
		description = "Giddy hands at the chin, then both arms up pointing at the ceiling and high knees on the spot.",
		-- (a tap as each foot comes down from the skip and the high knees)
		events = { ev(0.55, "CelebFootTap"), ev(1.33, "CelebFootTap"), ev(1.58, "CelebFootTap"), ev(1.83, "CelebFootTap"),
			ev(2.08, "CelebFootTap"), ev(2.33, "CelebFootTap"), ev(2.58, "CelebFootTap") },
		fx = { fx(1.0, "Swoosh", 0.45), fx(1.2, "Shout", 0.8), fx(1.33, "Dust"), fx(1.83, "Dust"), fx(2.33, "Dust") },
	},
	{
		id = "RackSideRoar", name = "Rack-Side Roar", rarity = "Epic", seconds = 3.4, kind = "Standing",
		animationId = "rbxassetid://102747506662616", source = "CEL-20",
		soundtrack = "rbxassetid://128293594914349",
		description = "Wide half squat, up into a V, down into goalposts, then sinking deep and pulling it all down. Three roars.",
		events = { ev(0.26, "CelebStomp"), ev(2.45, "CelebFootTap") },
		fx = { fx(0.26, "Dust"), fx(0.45, "Swoosh", 1.3), fx(0.65, "Shout", 0.35), fx(1.1, "Shout", 0.35),
			fx(1.6, "Shout", 0.45) },
	},
	{
		id = "CrouchRoarJump", name = "Crouch Roar & Jump", rarity = "Epic", seconds = 4.2, kind = "Standing",
		animationId = "rbxassetid://88493667409251", source = "CEL-18",
		soundtrack = "rbxassetid://101654183248134",
		description = "A deep crouch roar with the fists low, a crunch, a tuck jump and a little hop.",
		events = { ev(0.36, "CelebStomp"), ev(2.35, "CelebLand"), ev(3.1, "CelebFootTap") },
		fx = { fx(0.36, "Dust"), fx(0.4, "Shout", 0.75), fx(1.6, "Swoosh", 0.8), fx(1.85, "Jump", 0.5), fx(2.35, "Dust"),
			fx(3.1, "Dust") },
	},
	{
		id = "WingspanCrunch", name = "Wingspan Crunch", rarity = "Epic", seconds = 4.2, kind = "Standing",
		animationId = "rbxassetid://137285118933604", source = "CEL-17",
		soundtrack = "rbxassetid://140504637248836",
		description = "Watching the lights, then arms flung out to a T roaring, held, then sweeping down into a crunching squeeze.",
		events = {},
		fx = { fx(0.8, "Swoosh", 0.4), fx(1.05, "Shout", 1.15), fx(2.3, "Swoosh", 0.6), fx(2.85, "Shout", 0.6) },
	},
	{
		id = "DisbeliefPrayer", name = "Disbelief", rarity = "Legendary", seconds = 9.6, kind = "Standing",
		animationId = "rbxassetid://117449701756272", source = "CEL-02",
		soundtrack = "rbxassetid://115588207298207",
		description = "A title-winning last attempt: frozen shock, hands on the head, a roar, a full deep squat, 'can you believe it', arms to the sky, hands over the face.",
		events = { ev(1.3, "CelebFootTap"), ev(4.45, "CelebFootTap") },
		fx = { fx(1.8, "Swoosh", 0.4), fx(2.05, "Shout", 0.5), fx(2.9, "Dust"), fx(6.2, "Swoosh", 0.45),
			fx(6.5, "Shout", 0.85), fx(6.5, "ChalkPuff") },
		cinematic = {
			shots = { { at = 0, shot = "FrontMid" }, { at = 1.9, shot = "Close" }, { at = 2.8, shot = "LowFront" },
				{ at = 5.4, shot = "FrontMid" }, { at = 6.4, shot = "Wide" }, { at = 8.2, shot = "Close" } },
			look = { tint = Color3.fromRGB(255, 244, 228), key = Color3.fromRGB(255, 238, 210), haze = 0.15 },
		},
	},
	{
		id = "WingspanBiceps", name = "World Record Wingspan", rarity = "Legendary", seconds = 6.2, kind = "Standing",
		animationId = "rbxassetid://106344233838305", source = "CEL-03",
		soundtrack = "rbxassetid://87589154566724",
		description = "A world record: a crouched scream, a hop back with the arms flung up and wide, leaning back, then a double biceps.",
		events = { ev(0.3, "CelebFootTap"), ev(1.05, "CelebLand"), ev(2.6, "CelebFootTap") },
		fx = { fx(0.3, "Dust"), fx(0.45, "Shout", 0.45), fx(0.6, "Jump", 0.45), fx(0.8, "Swoosh", 0.75), fx(1.05, "Dust"),
			fx(3.8, "Swoosh", 0.35), fx(4.05, "Shout", 0.55), fx(4.05, "ChalkPuff") },
		cinematic = {
			shots = { { at = 0, shot = "Close" }, { at = 0.85, shot = "BackHigh" }, { at = 2.6, shot = "Side" },
				{ at = 3.9, shot = "FrontMid" } },
			look = { tint = Color3.fromRGB(240, 246, 255), key = Color3.fromRGB(225, 236, 255), haze = 0.2 },
		},
	},
	{
		id = "BowAndRise", name = "Bow, Then Rise Roaring", rarity = "Legendary", seconds = 6.6, kind = "Standing",
		animationId = "rbxassetid://137915016316855", source = "CEL-05",
		soundtrack = "rbxassetid://103458950942006",
		description = "Stunned, the knees buckle into a face-down bow... then up on the knees, fists driven down, head thrown back: the roar. Hand on the heart.",
		events = { ev(1.55, "CelebKnees"), ev(4.6, "CelebFootTap"), ev(5.1, "CelebFootTap") },
		fx = { fx(1.55, "KneeDust"), fx(3.8, "Swoosh", 0.45), fx(4.0, "Shout", 0.95), fx(3.95, "ChalkPuff") },
		cinematic = {
			shots = { { at = 0, shot = "FrontMid" }, { at = 1.5, shot = "LowSide" }, { at = 3.55, shot = "Close" },
				{ at = 4.6, shot = "LowFront" } },
			look = { tint = Color3.fromRGB(255, 240, 225), key = Color3.fromRGB(255, 228, 200), haze = 0.2 },
		},
	},
	{
		id = "RecordJumpRoar", name = "Record Jump & Chalk Burst", rarity = "Legendary", seconds = 9.2, kind = "Standing",
		animationId = "rbxassetid://99930838223185", source = "CEL-01",
		soundtrack = "rbxassetid://75363847444209",
		description = "A meet-winning record: arms wide in disbelief, a look up at the screen, hands on the head, a skip, a tucked jump punching forward, a clap that bursts chalk, a fist to the sky out of the cloud.",
		events = { ev(0.4, "CelebFootTap"), ev(1.9, "CelebFootTap"), ev(5.25, "CelebFootTap"), ev(5.75, "CelebFootTap"),
			ev(6.45, "CelebLand"), ev(7.0, "ChalkClap") },
		fx = { fx(0.3, "Swoosh", 0.4), fx(0.4, "Shout", 1.1), fx(5.3, "Swoosh", 0.5), fx(5.95, "Jump", 0.5),
			fx(6.45, "Dust"), fx(7.0, "ChalkBurst"), fx(7.1, "Swoosh", 0.5), fx(7.3, "Shout", 0.65) },
		cinematic = {
			shots = { { at = 0, shot = "Side" }, { at = 1.9, shot = "BackHigh" }, { at = 3.5, shot = "FrontMid" },
				{ at = 5.4, shot = "Side" }, { at = 6.8, shot = "LowFront" } },
			look = { tint = Color3.fromRGB(255, 225, 245), key = Color3.fromRGB(255, 120, 200), haze = 0.3 },
		},
	},
	-- From the FULL Meet Study (user 2026-11-14: "study EVERYTHING ... the male celebrations"; References/Meet Study/Meet
	-- Celebration Catalogue.md: `source` is its MC number). No sound tracks yet: their body sounds play one by one.
	{
		id = "HeadClampRoar", name = "Head Clamp Roar", rarity = "Legendary", seconds = 7.0, kind = "Standing",
		animationId = "rbxassetid://83917301171358", source = "MC-010",
		description = "A heavyweight world-record deadlift: up out of the bend into a double-biceps roar, arms to the sky, both hands clamped on the head screaming, a crouched gorilla roar.",
		events = {},
		fx = { fx(0.8, "Swoosh", 0.4), fx(1.0, "Shout", 0.5), fx(1.75, "Swoosh", 0.4), fx(3.0, "Shout", 1.0),
			fx(4.5, "Shout", 0.6), fx(5.3, "Swoosh", 0.4) },
		cinematic = {
			shots = { { at = 0, shot = "FrontMid" }, { at = 0.9, shot = "LowFront" }, { at = 2.6, shot = "Close" },
				{ at = 4.4, shot = "Wide" } },
			look = { tint = Color3.fromRGB(255, 236, 222), key = Color3.fromRGB(255, 214, 180), haze = 0.2 },
		},
	},
	{
		id = "GorillaRoar", name = "Gorilla Roar", rarity = "Epic", seconds = 3.6, kind = "Standing",
		animationId = "rbxassetid://88188049616838", source = "MC-020",
		description = "Chest out, fists at the hips roaring at the ceiling, then crunching down roaring at the floor. Twice.",
		events = {},
		fx = { fx(0.4, "Shout", 0.45), fx(1.25, "Shout", 0.4), fx(2.35, "Shout", 0.4) },
	},
	{
		id = "HammerFistRoar", name = "Hammer Fist", rarity = "Epic", seconds = 3.4, kind = "Standing",
		animationId = "rbxassetid://137690240669280", source = "MC-008",
		description = "A junior world record: one fist to the sky yelling, then a deep lean hammering both fists down past the knees.",
		events = {},
		fx = { fx(0.3, "Swoosh", 0.35), fx(0.45, "Shout", 0.3), fx(1.3, "Swoosh", 0.35), fx(1.5, "Shout", 0.3) },
	},
	{
		id = "HopSkyPunch", name = "Hopping Sky Punch", rarity = "Epic", seconds = 2.4, kind = "Standing",
		animationId = "rbxassetid://71296247286322", source = "MC-018",
		description = "A little sideways hop, one leg kicked back, body arched, a fist punched up at the sky in mid-air.",
		events = { ev(1.45, "CelebLand") },
		fx = { fx(0.6, "Jump", 0.4), fx(0.8, "Swoosh", 0.4), fx(0.95, "Shout", 0.3), fx(1.45, "Dust") },
	},
	{
		id = "FistsBesideHead", name = "Fists Beside the Head", rarity = "Uncommon", seconds = 2.3, kind = "Standing",
		animationId = "rbxassetid://116731349065196", source = "MC-064",
		description = "A junior's signature on every good pull: a clap at the chin, both fists up beside the head, one fist pump.",
		events = { ev(0.55, "ChalkClap") },
		fx = { fx(0.55, "ChalkPuff"), fx(0.7, "Swoosh", 0.3), fx(0.85, "Shout", 0.3) },
	},
	{
		id = "SkyPointChalkYes", name = "Sky Point & Chalk", rarity = "Rare", seconds = 4.0, kind = "Standing",
		animationId = "rbxassetid://79016920083257", source = "MC-034",
		description = "A finger to the ceiling, one clap that throws a chalk cloud, then bent almost flat swinging the fists down: YES.",
		events = { ev(1.65, "ChalkClap") },
		fx = { fx(0.3, "Swoosh", 0.3), fx(1.65, "ChalkBurst"), fx(2.4, "Swoosh", 0.4), fx(3.0, "Shout", 0.4) },
	},
	{
		id = "HunchedDance", name = "Hunched Victory Dance", rarity = "Epic", seconds = 4.2, kind = "Standing",
		animationId = "rbxassetid://106118951508425", source = "MC-022",
		description = "After a record squat: bent forward, knees bouncing to the beat, elbows swinging, knee-lift stomps and a running-man kick.",
		events = { ev(0.85, "CelebStomp"), ev(1.35, "CelebStomp"), ev(2.35, "CelebFootTap"), ev(2.85, "CelebFootTap") },
		fx = { fx(0.85, "Dust"), fx(1.35, "Dust"), fx(2.35, "Dust"), fx(2.85, "Dust") },
	},
	{
		id = "ChalkClapRightHere", name = "Right Here", rarity = "Legendary", seconds = 5.8, kind = "Standing",
		animationId = "rbxassetid://108334306481725", source = "MC-004",
		description = "A meet-winning deadlift: an arm flung up screaming, arms thrown wide at the crowd, a chalk-cloud clap, a crouched roar, then a step in roaring 'right here' at the floor.",
		events = { ev(2.15, "ChalkClap"), ev(3.75, "CelebStomp") },
		fx = { fx(0.2, "Swoosh", 0.35), fx(0.35, "Shout", 0.5), fx(1.1, "Swoosh", 0.4), fx(2.15, "ChalkBurst"),
			fx(2.5, "Shout", 0.4), fx(3.75, "Dust"), fx(3.75, "Shout", 0.7) },
		cinematic = {
			shots = { { at = 0, shot = "FrontMid" }, { at = 1.2, shot = "Wide" }, { at = 2.0, shot = "Close" },
				{ at = 3.6, shot = "LowFront" } },
			look = { tint = Color3.fromRGB(240, 244, 255), key = Color3.fromRGB(220, 230, 255), haze = 0.3 },
		},
	},
	{
		id = "VStrutRoar", name = "V Strut", rarity = "Epic", seconds = 6.0, kind = "Standing",
		animationId = "rbxassetid://104580649958760", source = "MC-011",
		description = "A showman's world record: arms up in a high V with the hips swaying, a sudden half-squat roar, a flex, then a point at the crowd.",
		events = {},
		fx = { fx(0.25, "Swoosh", 0.4), fx(1.85, "Shout", 0.45), fx(3.0, "Shout", 0.35), fx(4.35, "Swoosh", 0.3) },
	},
	{
		id = "BackRollLegsUp", name = "Back Roll, Legs Up", rarity = "Legendary", seconds = 8.4, kind = "Standing",
		animationId = "rbxassetid://132710771867516", source = "MC-013",
		description = "A European-record deadlift: sits back, rolls onto his back with both legs in the air, then up onto his knees screaming at the ceiling.",
		events = { ev(1.15, "CelebSit"), ev(1.75, "CelebSit"), ev(4.8, "CelebKnees"), ev(7.2, "Clap"), ev(7.6, "Clap") },
		fx = { fx(1.15, "Dust"), fx(1.75, "Dust"), fx(4.8, "KneeDust"), fx(5.4, "Shout", 0.5) },
		cinematic = {
			shots = { { at = 0, shot = "FrontMid" }, { at = 1.6, shot = "Wide" }, { at = 4.6, shot = "LowSide" },
				{ at = 5.3, shot = "LowFront" }, { at = 6.8, shot = "FrontMid" } },
			look = { tint = Color3.fromRGB(255, 244, 228), key = Color3.fromRGB(255, 232, 200), haze = 0.2 },
		},
	},
	{
		id = "OneKneeFistPumps", name = "One-Knee Fist Pumps", rarity = "Epic", seconds = 6.0, kind = "Standing",
		animationId = "rbxassetid://122732418337477", source = "MC-016",
		description = "A national record: down on one knee pumping both fists, head bowed, then both arms up in a V from the knee.",
		events = { ev(1.2, "CelebKnees"), ev(4.8, "CelebStomp") },
		fx = { fx(0.45, "Shout", 0.3), fx(1.2, "KneeDust"), fx(3.2, "Swoosh", 0.3), fx(3.35, "Shout", 0.75), fx(4.8, "Dust") },
	},
	{
		id = "CrucifixTears", name = "Crucifix to Tears", rarity = "Epic", seconds = 6.6, kind = "Standing",
		animationId = "rbxassetid://77749737387518", source = "MC-021",
		description = "A last deadlift: a V, then arms out to the sides with the face to the sky... and he breaks down, forearm over his face.",
		events = {},
		fx = { fx(0.2, "Swoosh", 0.3), fx(0.35, "Shout", 0.4) },
	},
	{
		id = "SkyFingerArmsCrossed", name = "Finger Up, Arms Crossed", rarity = "Rare", seconds = 7.3, kind = "Standing",
		animationId = "rbxassetid://86186278650542", source = "MC-031",
		description = "The heaviest squat ever: a finger thrust to the sky, then standing still with the arms crossed, taking it in.",
		events = {},
		fx = { fx(0.3, "Swoosh", 0.3), fx(0.45, "Shout", 0.5) },
	},
	{
		id = "Gunslinger", name = "Gunslinger", rarity = "Epic", seconds = 5.0, kind = "Standing",
		animationId = "rbxassetid://138620700673748", source = "MC-051",
		description = "Two finger pistols at the mouth, blow the smoke off, holster them, point at the crowd, then fists by the head.",
		events = {},
		fx = { fx(2.3, "Swoosh", 0.3), fx(3.8, "Swoosh", 0.3), fx(3.9, "Shout", 0.4) },
	},
	{
		id = "AreYouNotEntertained", name = "Are You Not Entertained?", rarity = "Epic", seconds = 6.0, kind = "Standing",
		animationId = "rbxassetid://137415132772884", source = "MC-025",
		description = "A fist to the sky, a slap on the chest that throws chalk, then arms spread wide, palms up, chin raised, perfectly still.",
		events = { ev(1.75, "BackSlap") },
		fx = { fx(0.3, "Swoosh", 0.3), fx(1.75, "ChalkPuff"), fx(2.4, "Swoosh", 0.4) },
	},
	{
		id = "LongVHold", name = "The Long V", rarity = "Rare", seconds = 6.4, kind = "Standing",
		animationId = "rbxassetid://75249448938574", source = "MC-030",
		description = "The biggest deadlift in history: both arms straight up and held, head thrown back roaring at the ceiling.",
		events = {},
		fx = { fx(0.4, "Swoosh", 0.3), fx(0.55, "Shout", 1.5) },
	},
	{
		id = "StageEdgeDoubleBiceps", name = "Stage-Edge Double Biceps", rarity = "Epic", seconds = 5.6, kind = "Standing",
		animationId = "rbxassetid://121585072803238", source = "MC-035",
		description = "Six for six: a front double biceps pumped twice, a most-muscular squeeze, a 'come on' sweep, then the crab.",
		events = {},
		fx = { fx(0.9, "Swoosh", 0.3), fx(1.0, "Shout", 0.3), fx(2.45, "Shout", 0.45), fx(3.35, "Swoosh", 0.3) },
	},
	{
		id = "FistsChestCeilingRoar", name = "Ceiling Roar", rarity = "Rare", seconds = 5.4, kind = "Standing",
		animationId = "rbxassetid://130334347632285", source = "MC-024",
		description = "A grinder PR: fists pulled to the chest roaring, a fist thrust up, then the head thrown right back screaming at the ceiling.",
		events = {},
		fx = { fx(0.5, "Shout", 0.45), fx(1.3, "Swoosh", 0.3), fx(2.45, "Shout", 1.45) },
	},
	{
		id = "LightsArmsWideHeadHands", name = "Lights, Then Relief", rarity = "Uncommon", seconds = 4.8, kind = "Standing",
		animationId = "rbxassetid://137321931821990", source = "MC-049",
		description = "Staring up at the lights board... three whites: arms thrown wide 'come on!', then both hands on the head.",
		events = {},
		fx = { fx(1.5, "Swoosh", 0.4), fx(1.6, "Shout", 0.5) },
	},
	-- All the way back (user 2026-11-11), from the user's videos rewatched for how lifters step off and walk away
	-- (art/scripts/celebration_animations.py notes the moments).
	{
		id = "ThankYouWave", name = "Thank-You Wave", rarity = "Rare", seconds = 3.6, kind = "WalkLoop",
		animationId = "rbxassetid://93339834494171", source = "Walk-off: lNOrz4CVNMY 23:30",
		soundtrack = "rbxassetid://115133666349196",
		description = "All the way back to your spot: an open hand waved up to the crowd, then a hand on the heart and a nod.",
		events = {},
		fx = {},
	},
	{
		id = "CrowdPleaser", name = "Crowd Pleaser", rarity = "Epic", seconds = 4.4, kind = "WalkLoop",
		animationId = "rbxassetid://78622244351624", source = "Walk-off: 9FQM0Z6_s8Q 1:16.8, lNOrz4CVNMY 20:55",
		soundtrack = "rbxassetid://102629709943437",
		description = "All the way back to your spot: two roaring fist pumps, arms flung wide, then double thumbs up to the stands. Again and again.",
		events = {},
		fx = { fx(0.35, "Swoosh", 0.3), fx(0.85, "Swoosh", 0.3), fx(1.7, "Swoosh", 0.5), fx(2.8, "Swoosh", 0.4) },
	},
} :: { Celebration }

CelebrationConfig.byId = {} :: { [string]: Celebration }
for _, celebration in ipairs(CelebrationConfig.List) do
	CelebrationConfig.byId[celebration.id] = celebration
end

--[[
	MISS REACTIONS (user 2026-11-15): the two moves that were studied from lifts that were really MISSES (CEL-04, CEL-34;
	the full Meet Study found it) are no longer celebrations. After a failed lift's own fail animation, now and then the
	lifter reacts with one of them: about `MissReactionChance` of misses, one of these at random, for every lifter
	(players and computer lifters, no unlock, nothing saved), at the meets that have celebrations (MeetLevels). No camera
	shots: a miss stays quick. The server rolls (CelebrationService.missReaction); a player who owned one of them as a
	celebration now has the Default there (an id the list no longer has counts as the Default, ProfileOperations).
	Same fields as a celebration; never in the spin, the viewer's list or a loadout.
]]
--[[
	CHANGED (user 2026-11-15, after a Studio test): "the lifter does NOT do the fail animation while looking at the crowd,
	the lifter would be facing the direction they are going back to, then yelling or screaming ... it should be fail, turn
	while walking hand gestures, scream." So EVERY miss now gets one: after the fail animation the lifter turns toward
	where he is going and does one of these OVER the walk back (kind "Walk": arms and head only, the walk is the game's;
	LocalMeetService.walkBack). Leap & Bow and Sinking Roar (standing, facing the crowd) are no longer used. The roar is
	Sinking Roar's sound track for now (its roar lands at 0.4 s, these yell at 0.25-0.35 s).
]]
CelebrationConfig.MissReactionChance = 1
local MISS_ROAR = "rbxassetid://72039361401656"
CelebrationConfig.MissReactions = {
	{
		id = "MissHandsOnHead", name = "Hands on Head", rarity = "Default", seconds = 3.5, kind = "Walk",
		animationId = "rbxassetid://132007727430646", source = "User 2026-11-15 (miss: walk off)",
		soundtrack = MISS_ROAR,
		description = "After a miss, walking off: both hands up onto the head, a look up, then the head drops and shakes.",
		events = {},
		fx = { fx(0.35, "Shout", 0.6) },
	},
	{
		id = "MissArmSwipe", name = "Fist Swipe", rarity = "Default", seconds = 3.0, kind = "Walk",
		animationId = "rbxassetid://122776395159397", source = "User 2026-11-15 (miss: walk off)",
		soundtrack = MISS_ROAR,
		description = "After a miss, walking off: the right fist thrown up and slashed down, then hands on the hips, head shaking.",
		events = {},
		fx = { fx(0.25, "Shout", 0.6), fx(0.4, "Swoosh", 0.5) },
	},
	{
		id = "MissYell", name = "Yell", rarity = "Default", seconds = 2.8, kind = "Walk",
		animationId = "rbxassetid://70835981258039", source = "User 2026-11-15 (miss: walk off)",
		soundtrack = MISS_ROAR,
		description = "After a miss, walking off: yelling at the ceiling with tense fists low, two fists driven down, head drops.",
		events = {},
		fx = { fx(0.3, "Shout", 1.0) },
	},
} :: { Celebration }
CelebrationConfig.missById = {} :: { [string]: Celebration }
for _, reaction in ipairs(CelebrationConfig.MissReactions) do
	CelebrationConfig.missById[reaction.id] = reaction
end

-- A celebration or a miss reaction by id (what plays on a body), or nil.
function CelebrationConfig.get(id: string): Celebration?
	return CelebrationConfig.byId[id] or CelebrationConfig.missById[id]
end

--[[
	The celebration spin (user 2026-11-11: "lets make celebrations unlockable ... replace it with a npc ... hold e on it,
	the celebrations screen pops up, Make it where its like a rollable thing"; GAME_DESIGN §36.4). The player holds E on
	the placeholder NPC in the gym's dumbbell corner and spins: a REROLL (the user's choice), so the spin's result
	replaces their one celebration. Each spin costs `price` coins (like a gear crate); the rarity is rolled with the gear
	crates' odds (GearStatsConfig.Rarities), then one celebration of that rarity at random (never the Default). Landing on
	the one they already have gives `duplicateRefund` back. The server rolls and decides (CelebrationSpinService);
	the screen (client CelebrationSpinner) only shows it.
]]
CelebrationConfig.Spin = {
	price = 500,
	duplicateRefund = 250,
	-- RoomProps tags the NPC's spot with this; CelebrationSpinService stands the NPC there.
	spotTag = "CelebrationSpinnerSpot",
	-- The placeholder NPC (user: "our first npc as a placeholder for now").
	npcName = "Hype Man",
	promptText = "Spin celebrations",
	promptHoldSeconds = 0.5,
	promptDistanceStuds = 8,
	-- A spin is refused from further than this from the NPC.
	maxSpinDistanceStuds = 24,
}

--[[
	Where a rolled rarity lands when the thing being spun has none of that rarity (three fail styles, eight emotes): the
	nearest lower rarity that has some, else the nearest higher one. `rarities` lists the crate rarities lowest first
	(GearStatsConfig.Rarities' ids); `has` says which ones the pool has. The server's roll and the card's odds both use
	it, so the odds shown are the odds you get.
]]
function CelebrationConfig.landingRarity(rolled: string, rarities: { string }, has: { [string]: boolean }): string?
	local at = table.find(rarities, rolled)
	if at == nil then
		return nil
	end
	for i = at, 1, -1 do
		if has[rarities[i]] then
			return rarities[i]
		end
	end
	for i = at + 1, #rarities do
		if has[rarities[i]] then
			return rarities[i]
		end
	end
	return nil
end

return CelebrationConfig
