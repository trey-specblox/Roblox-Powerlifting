--!strict
--[[
	EmoteConfig
	Shared / Config

	The emotes (user 2026-11-11: an emote wheel on a key, "8 gym emotes", COLLECTED: every one won is kept and goes on
	the wheel; everyone has the free ones; the rest are won at the celebration NPC's spin, CelebrationConfig.Spin, by
	`rarity`, a duplicate giving the refund back). Made in Blender by art/scripts/emote_animations.py; each its own
	ElevenLabs sound track lined up with it (art/sounds/emote_tracks.json), played in step with the animation on every
	screen. Moving cancels one. Not during a lift, a meet's turn or a mock meet (EmoteService checks).

		id, name     the id (the animation is Emote_<id>) and what players see
		rarity       "Free" (everyone's) or a crate rarity (GearStatsConfig.Rarities' ids)
		animationId  its uploaded animation
		soundtrack   its own sound track; nil until made
		seconds      how long it lasts
		description  what players read on the spin card

	Display and timing only: who may play which is decided on the server (EmoteService, ProfileOperations).
]]

local EmoteConfig = {}

export type Emote = {
	id: string,
	name: string,
	rarity: string,
	animationId: string,
	soundtrack: string?,
	seconds: number,
	description: string,
}

-- The key that opens the wheel (phones get a button).
EmoteConfig.WheelKey = Enum.KeyCode.B

-- The wheel's order (clockwise from the top).
EmoteConfig.List = {
	{
		id = "Wave", name = "Wave", rarity = "Free", seconds = 2.4,
		animationId = "rbxassetid://120416482547283",
		soundtrack = "rbxassetid://97266615028574",
		description = "A big wave, hand up beside the head.",
	},
	{
		id = "ChalkClap", name = "Chalk Clap", rarity = "Free", seconds = 2.0,
		animationId = "rbxassetid://124873861686909",
		soundtrack = "rbxassetid://88347836224985",
		description = "Two chalky claps at the chest and a rub of the hands.",
	},
	{
		id = "BeltTighten", name = "Belt Tighten", rarity = "Common", seconds = 2.6,
		animationId = "rbxassetid://80679624713090",
		soundtrack = "rbxassetid://129910481363826",
		description = "Hands to the belt, two hard snaps, then a flick of the lever.",
	},
	{
		id = "DoubleBiceps", name = "Double Biceps", rarity = "Common", seconds = 3.0,
		animationId = "rbxassetid://92757700994769",
		soundtrack = "rbxassetid://77190572314131",
		description = "The classic flex, held and shaking.",
	},
	{
		id = "TrapSlap", name = "Trap Slap", rarity = "Uncommon", seconds = 2.6,
		animationId = "rbxassetid://110729907160650",
		soundtrack = "rbxassetid://87589905559182",
		description = "Slaps both traps twice, then a hard clap, chest out. Ready to lift.",
	},
	{
		id = "PointLaugh", name = "Point & Laugh", rarity = "Uncommon", seconds = 3.0,
		animationId = "rbxassetid://105135225562870",
		soundtrack = "rbxassetid://103216270237695",
		description = "Points at someone, then laughs with a hand on the belly.",
	},
	{
		id = "SitBreath", name = "Catch Your Breath", rarity = "Rare", seconds = 5.0,
		animationId = "rbxassetid://77130447980143",
		soundtrack = "rbxassetid://75282229993061",
		description = "Sits down on the floor, forearms on the knees, catching a breath after a big set.",
	},
	{
		id = "MostMuscular", name = "Most Muscular", rarity = "Epic", seconds = 3.2,
		animationId = "rbxassetid://99513574475703",
		soundtrack = "rbxassetid://81047702836611",
		description = "The crab: leans in, fists together, every muscle tensed and shaking.",
	},
} :: { Emote }

EmoteConfig.byId = {} :: { [string]: Emote }
for _, emote in ipairs(EmoteConfig.List) do
	EmoteConfig.byId[emote.id] = emote
end

-- Whether everyone has it without winning it.
function EmoteConfig.isFree(id: string): boolean
	local emote = EmoteConfig.byId[id]
	return emote ~= nil and emote.rarity == "Free"
end

-- How loud an emote's sound plays, and how far it carries (studs: full volume near, silent far).
EmoteConfig.Volume = 0.7
EmoteConfig.SoundNear = 14
EmoteConfig.SoundFar = 80

return EmoteConfig
