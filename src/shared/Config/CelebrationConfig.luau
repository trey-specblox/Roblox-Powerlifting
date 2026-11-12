--!strict
--[[
	CelebrationConfig
	Shared / Config

	The celebrations after a good lift (GAME_DESIGN §36.4; user 2026-11-11). Each is a real lifter's celebration from the
	user's 15 meet videos, studied move by move (References/Clip Study/Celebration Catalogue.md: `source` is its CEL
	number) and animated in Blender (art/scripts/celebration_animations.py), uploaded under the game's group.

	For now (user's choice, 2026-11-11):
		- every lifter, players and computer lifters, does the Default after a good lift at State and up (MeetLevels);
		- the rest are seen in the admin's celebration viewer; later they are unlocked from crates (by `rarity`), and
		  every player can browse them all there, to see what they could unbox.

	Each one:
		id, name           the id (the animation's name without "Celebrate_") and what players see
		rarity             "Default" (free) or a crate rarity (GearStatsConfig.Rarities' ids)
		animationId        its uploaded animation
		seconds            how long it lasts
		kind               "Standing": on the spot, then the lifter walks back
		                   "Walk": arms and head only, played over the walk back (real lifters never stop walking)
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

-- Where a good lift gets a celebration (the user: the big presentation is for State and up, GAME_DESIGN §36.4).
CelebrationConfig.MeetLevels = { State = true } :: { [string]: boolean }

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
		animationId = "rbxassetid://128556766854007", source = "CEL-71",
		soundtrack = "rbxassetid://130751571992816",
		description = "A chalky clap at the chest, a proud beat, one fist pump. What real lifters do on an ordinary good lift.",
		events = { ev(0.42, "ChalkClap") },
		fx = { fx(0.42, "ChalkPuff"), fx(1.6, "Swoosh", 0.6) },
	},
	{
		id = "ExitFistPump", name = "Exit Fist Pump", rarity = "Common", seconds = 1.6, kind = "Walk",
		animationId = "rbxassetid://87493089985283", source = "CEL-59",
		soundtrack = "rbxassetid://100065691077554",
		description = "Never stops walking: one fist up beside the head on the way off. 'Opener done.'",
		events = {},
		fx = { fx(0.15, "Swoosh", 0.55) },
	},
	{
		id = "FistSalute", name = "Fist Salute", rarity = "Common", seconds = 2.4, kind = "Standing",
		animationId = "rbxassetid://123710487093671", source = "CEL-60",
		soundtrack = "rbxassetid://129076185496758",
		description = "A fist held up beside the head, upper arm level, looking up at the crowd. Calm and businesslike.",
		events = {},
		fx = { fx(0.08, "Swoosh", 0.4), fx(0.4, "ChalkPuff") },
	},
	{
		id = "MilitarySalute", name = "Military Salute", rarity = "Common", seconds = 3.0, kind = "Standing",
		animationId = "rbxassetid://135407665577251", source = "CEL-66",
		soundtrack = "rbxassetid://112831292294445",
		description = "Chest out, a crisp salute to the judges, then at attention. Dignified, not every unlock is a scream.",
		events = { ev(0.21, "CelebStomp") },
		fx = { fx(0.21, "Dust"), fx(0.35, "Swoosh", 0.35) },
	},
	{
		id = "WingspanHold", name = "Wingspan", rarity = "Uncommon", seconds = 3.4, kind = "Standing",
		animationId = "rbxassetid://79043773456497", source = "CEL-46",
		soundtrack = "rbxassetid://70393531422307",
		description = "Arms swing out into a T and hold, chin up, soaking it in. 'What did you expect?'",
		events = {},
		fx = { fx(0.15, "Swoosh", 0.8) },
	},
	{
		id = "ArmsUpBounce", name = "Arms Up Bounce", rarity = "Uncommon", seconds = 2.5, kind = "Standing",
		animationId = "rbxassetid://117132977931241", source = "CEL-49",
		soundtrack = "rbxassetid://101557833195011",
		description = "Both arms straight up, then bouncing on the toes with the arms out, laughing.",
		events = { ev(0.75, "CelebFootTap"), ev(1.15, "CelebFootTap"), ev(1.55, "CelebFootTap") },
		fx = { fx(0.05, "Swoosh", 0.4), fx(0.25, "Shout", 0.5), fx(0.75, "Dust"), fx(1.55, "Dust") },
	},
	{
		id = "SkyPoint", name = "Finger to the Sky", rarity = "Uncommon", seconds = 3.4, kind = "Walk",
		animationId = "rbxassetid://109828605839081", source = "CEL-51",
		soundtrack = "rbxassetid://108014192803753",
		description = "Walking off with one arm straight up, a finger to the sky, chin up. Unhurried, dominant.",
		events = {},
		fx = { fx(0.2, "Swoosh", 0.4) },
	},
	{
		id = "ReliefRoar", name = "Relief Roar", rarity = "Rare", seconds = 4.2, kind = "Standing",
		animationId = "rbxassetid://136293012059892", source = "CEL-34",
		soundtrack = "rbxassetid://72039361401656",
		description = "A heavyweight's sinking roar, arms tense, then both hands locked on the head. Feet never move.",
		events = {},
		fx = { fx(0.4, "Shout", 1.0), fx(1.75, "Swoosh", 0.55) },
	},
	{
		id = "LightsArmsUp", name = "Wait for the Lights", rarity = "Rare", seconds = 3.8, kind = "Standing",
		animationId = "rbxassetid://89117731000961", source = "CEL-36",
		soundtrack = "rbxassetid://104407525026280",
		description = "Hands on hips, watching the judges... then both arms shoot straight up.",
		events = {},
		fx = { fx(1.3, "Swoosh", 0.45), fx(1.55, "Shout", 1.15), fx(1.6, "ChalkPuff") },
	},
	{
		id = "SitAndLaugh", name = "Sit Down and Laugh", rarity = "Rare", seconds = 5.2, kind = "Standing",
		animationId = "rbxassetid://104660341072158", source = "CEL-43",
		soundtrack = "rbxassetid://124071275481756",
		description = "Just sits down on the platform, leaning back on one hand, laughing up at the lights.",
		events = { ev(1.15, "CelebSit"), ev(3.55, "CelebFootTap"), ev(4.2, "CelebFootTap") },
		fx = { fx(1.15, "Dust") },
	},
	{
		id = "PointAndPrance", name = "Point & Prance", rarity = "Epic", seconds = 3.6, kind = "Standing",
		animationId = "rbxassetid://104214935349918", source = "CEL-26",
		soundtrack = "rbxassetid://126738208009576",
		description = "Giddy hands at the chin, then both arms up pointing at the ceiling and high knees on the spot.",
		-- (a tap as each foot comes down from the skip and the high knees)
		events = { ev(0.55, "CelebFootTap"), ev(1.33, "CelebFootTap"), ev(1.55, "CelebFootTap"), ev(1.77, "CelebFootTap"),
			ev(1.99, "CelebFootTap"), ev(2.21, "CelebFootTap"), ev(2.45, "CelebFootTap") },
		fx = { fx(0.9, "Swoosh", 0.45), fx(1.1, "Shout", 0.8), fx(1.33, "Dust"), fx(1.77, "Dust"), fx(2.21, "Dust") },
	},
	{
		id = "RackSideRoar", name = "Rack-Side Roar", rarity = "Epic", seconds = 3.4, kind = "Standing",
		animationId = "rbxassetid://108298610910777", source = "CEL-20",
		soundtrack = "rbxassetid://128293594914349",
		description = "Wide half squat, up into a V, down into goalposts, then sinking deep and pulling it all down. Three roars.",
		events = { ev(0.26, "CelebStomp"), ev(2.45, "CelebFootTap") },
		fx = { fx(0.26, "Dust"), fx(0.45, "Swoosh", 1.3), fx(0.65, "Shout", 0.35), fx(1.1, "Shout", 0.35),
			fx(1.6, "Shout", 0.45) },
	},
	{
		id = "CrouchRoarJump", name = "Crouch Roar & Jump", rarity = "Epic", seconds = 4.2, kind = "Standing",
		animationId = "rbxassetid://90946364509609", source = "CEL-18",
		soundtrack = "rbxassetid://101654183248134",
		description = "A deep crouch roar with the fists low, a crunch, a tuck jump and a little hop.",
		events = { ev(0.36, "CelebStomp"), ev(2.35, "CelebLand"), ev(3.1, "CelebFootTap") },
		fx = { fx(0.36, "Dust"), fx(0.4, "Shout", 0.75), fx(1.6, "Swoosh", 0.8), fx(1.85, "Jump", 0.5), fx(2.35, "Dust"),
			fx(3.1, "Dust") },
	},
	{
		id = "WingspanCrunch", name = "Wingspan Crunch", rarity = "Epic", seconds = 4.2, kind = "Standing",
		animationId = "rbxassetid://75711873319608", source = "CEL-17",
		soundtrack = "rbxassetid://140504637248836",
		description = "Watching the lights, then arms flung out to a T roaring, held, then sweeping down into a crunching squeeze.",
		events = {},
		fx = { fx(0.8, "Swoosh", 0.4), fx(1.05, "Shout", 1.15), fx(2.3, "Swoosh", 0.6), fx(2.85, "Shout", 0.6) },
	},
	{
		id = "DisbeliefPrayer", name = "Disbelief", rarity = "Legendary", seconds = 9.6, kind = "Standing",
		animationId = "rbxassetid://91590042223818", source = "CEL-02",
		soundtrack = "rbxassetid://115588207298207",
		description = "A title-winning last attempt: frozen shock, hands on the head, a roar, a full deep squat, 'can you believe it', arms to the sky, hands over the face.",
		events = { ev(1.3, "CelebFootTap"), ev(4.45, "CelebFootTap") },
		fx = { fx(1.7, "Swoosh", 0.4), fx(1.95, "Shout", 0.5), fx(2.9, "Dust"), fx(6.2, "Swoosh", 0.45),
			fx(6.5, "Shout", 0.85), fx(6.5, "ChalkPuff") },
		cinematic = {
			shots = { { at = 0, shot = "FrontMid" }, { at = 1.9, shot = "Close" }, { at = 2.8, shot = "LowFront" },
				{ at = 5.4, shot = "FrontMid" }, { at = 6.4, shot = "Wide" }, { at = 8.2, shot = "Close" } },
			look = { tint = Color3.fromRGB(255, 244, 228), key = Color3.fromRGB(255, 238, 210), haze = 0.15 },
		},
	},
	{
		id = "WingspanBiceps", name = "World Record Wingspan", rarity = "Legendary", seconds = 6.2, kind = "Standing",
		animationId = "rbxassetid://120155702006810", source = "CEL-03",
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
		id = "LeapAndBow", name = "Leap & Bow", rarity = "Legendary", seconds = 5.8, kind = "Standing",
		animationId = "rbxassetid://96553342636481", source = "CEL-04",
		soundtrack = "rbxassetid://83740584871242",
		description = "Springs up with the hands by the head and the shins tucked, lands straight on both knees and bows to the platform.",
		events = { ev(1.18, "CelebKnees"), ev(3.75, "CelebFootTap"), ev(4.45, "CelebFootTap") },
		fx = { fx(0.3, "Dust"), fx(0.4, "Swoosh", 0.55), fx(0.55, "Shout", 0.4), fx(0.55, "Jump", 0.63),
			fx(1.18, "KneeDust") },
		cinematic = {
			shots = { { at = 0, shot = "Side" }, { at = 0.5, shot = "LowFront" }, { at = 1.6, shot = "LowSide" },
				{ at = 3.4, shot = "FrontMid" } },
			look = { tint = Color3.fromRGB(255, 236, 236), key = Color3.fromRGB(255, 225, 225), haze = 0.25 },
		},
	},
	{
		id = "BowAndRise", name = "Bow, Then Rise Roaring", rarity = "Legendary", seconds = 6.6, kind = "Standing",
		animationId = "rbxassetid://125955308007974", source = "CEL-05",
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
		animationId = "rbxassetid://130354718153201", source = "CEL-01",
		soundtrack = "rbxassetid://75363847444209",
		description = "A meet-winning record: arms wide in disbelief, a look up at the screen, hands on the head, a skip, a tucked jump punching forward, a clap that bursts chalk, a fist to the sky out of the cloud.",
		events = { ev(0.4, "CelebFootTap"), ev(1.9, "CelebFootTap"), ev(5.25, "CelebFootTap"), ev(5.75, "CelebFootTap"),
			ev(6.45, "CelebLand"), ev(7.0, "ChalkClap") },
		fx = { fx(0.3, "Swoosh", 0.4), fx(0.4, "Shout", 1.1), fx(5.3, "Swoosh", 0.5), fx(5.95, "Jump", 0.5),
			fx(6.45, "Dust"), fx(7.0, "ChalkBurst"), fx(7.1, "Swoosh", 0.5), fx(7.25, "Shout", 0.65) },
		cinematic = {
			shots = { { at = 0, shot = "Side" }, { at = 1.9, shot = "BackHigh" }, { at = 3.5, shot = "FrontMid" },
				{ at = 5.4, shot = "Side" }, { at = 6.8, shot = "LowFront" } },
			look = { tint = Color3.fromRGB(255, 225, 245), key = Color3.fromRGB(255, 120, 200), haze = 0.3 },
		},
	},
} :: { Celebration }

CelebrationConfig.byId = {} :: { [string]: Celebration }
for _, celebration in ipairs(CelebrationConfig.List) do
	CelebrationConfig.byId[celebration.id] = celebration
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

return CelebrationConfig
