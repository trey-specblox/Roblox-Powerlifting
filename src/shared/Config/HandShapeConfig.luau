--!strict
--[[
	HandShapeConfig
	Shared / Config

	Hand-shape swaps on the cartoon bodies (GAME_DESIGN.md §38.7, user's pick: "Lets use hand-shape swaps"). The body's
	own hands are OPEN (user 2026-11-12, after a play test: "open by default, close only when gripping"). A lift's grip, a
	celebration or an emote shows another shape (Fist, Point, ThumbsUp, Grip, SquatGrip) when it needs one: the open hand
	hides and the shape shows in its place, on the same hand, bending with the wrist.

	The shapes are one uploaded model (art/exports/CartoonHands05.glb, exported by art/scripts/export_cartoon_05.py from
	the CartoonBodies_05 swap hands, build_cartoon_hands_04.py), one rigid MeshPart per shape and side, "<Shape>_<Side>",
	at a hand size of 1. Each build scales them by its hand size. Meshes: each shape's offset from the body's own hand
	part (the open hand) and its size, at hand size 1 (Roblox axes), from art/exports/CartoonExport05.json (measured on
	all six builds: the offset scales exactly with the hand size).

	Who swaps: every client, for every character it sees (client HandShapeAnimator), from the animation's own playing
	time, so everyone sees the same hands. The server puts the hidden shapes on each body (LifterBodyService).

	Timelines (Claude's pick, 2026-11-12, frame by frame from art/scripts/celebration_animations.py and
	emote_animations.py): fists for pumps, roars, flexes and anything held; Point for Sky Point, "shhh" and pointing;
	thumbs up for Crowd Pleaser's double thumbs up; open everywhere else (waves, claps, salutes, hands on the head,
	the hips, the floor or the heart, arms flung wide).
]]

local CelebrationConfig = require(script.Parent:WaitForChild("CelebrationConfig"))
local EmoteConfig = require(script.Parent:WaitForChild("EmoteConfig"))
local EntranceConfig = require(script.Parent:WaitForChild("EntranceConfig"))

local HandShapeConfig = {}

-- The shapes model (materials.json "CartoonHands05"); 0 = not uploaded yet (no swaps then: open hands everywhere).
HandShapeConfig.AssetId = 94039364109733
-- Folder in the character holding the hidden shapes.
HandShapeConfig.FolderName = "HandShapes"

-- The swaps. The body's own hands are OPEN, so a closed fist is a swap too: gripping the bar, the belt, a fist pump.
HandShapeConfig.Default = "Open"
HandShapeConfig.Shapes = { "Fist", "Point", "ThumbsUp", "Grip", "SquatGrip" }
-- What the hands show while they hold the bar in a lift (client StationPoseAnimator says when; HandShapeConfig.gripFor
-- picks by lift): Grip = the fingers wrapped round the bar (bench, deadlift); SquatGrip = the squat's thumbless grip,
-- the bar in the heel of the palm (user 2026-11-14, Character Animation Quality.md §4.1b).
HandShapeConfig.Grip = "Grip"
HandShapeConfig.SquatGrip = "SquatGrip"
-- A body's attributes naming the shape a hand keeps while it HOLDS something (the announcer's microphone: "Grip"), until
-- the attribute is cleared. An animation's own hand timeline and a lift's grip still come first.
HandShapeConfig.HeldAttributes = { Left = "HandHeldLeft", Right = "HandHeldRight" } :: { [string]: string }

function HandShapeConfig.gripFor(lift: any): string
	return if lift == "Squat" then HandShapeConfig.SquatGrip else HandShapeConfig.Grip
end

export type Mesh = { offset: Vector3, size: Vector3 }

-- From art/exports/CartoonExport05.json (hand size 1, Roblox axes): offset = the shape's centre from the body's own
-- hand part's centre, in that part's space.
HandShapeConfig.Meshes = {
	Fist_Left = { offset = Vector3.new(0.0668, 0.1073, 0.0640), size = Vector3.new(0.4451, 0.4947, 0.438) },
	Fist_Right = { offset = Vector3.new(-0.0668, 0.1073, 0.0640), size = Vector3.new(0.4451, 0.4947, 0.438) },
	Point_Left = { offset = Vector3.new(0.0671, 0.0093, 0.0650), size = Vector3.new(0.4462, 0.6888, 0.4359) },
	Point_Right = { offset = Vector3.new(-0.0671, 0.0093, 0.0650), size = Vector3.new(0.4462, 0.6888, 0.4359) },
	ThumbsUp_Left = { offset = Vector3.new(0.0311, 0.0634, 0.0476), size = Vector3.new(0.3746, 0.5782, 0.471) },
	ThumbsUp_Right = { offset = Vector3.new(-0.0311, 0.0634, 0.0476), size = Vector3.new(0.3746, 0.5782, 0.471) },
	Grip_Left = { offset = Vector3.new(0.1501, 0.0311, 0.0652), size = Vector3.new(0.6095, 0.6435, 0.4335) },
	Grip_Right = { offset = Vector3.new(-0.1501, 0.0311, 0.0652), size = Vector3.new(0.6095, 0.6435, 0.4335) },
	SquatGrip_Left = { offset = Vector3.new(0.0802, 0.0797, 0.0651), size = Vector3.new(0.4728, 0.5473, 0.436) },
	SquatGrip_Right = { offset = Vector3.new(-0.0802, 0.0797, 0.0651), size = Vector3.new(0.4728, 0.5473, 0.436) },
} :: { [string]: Mesh }

-- Each build's hand size (build_cartoon_body_05.body_spec "hand"; CHARACTER_ART_DIRECTION.md: the hands grow with the
-- build).
HandShapeConfig.HandSize = { Skinny = 1.05, SkinnyFat = 1.12, Fat = 1.30, Fit = 1.22, Muscular = 1.50, BigBuff = 1.58,
	-- the coaches' bodies (build_coach_bodies_01.py, ClothesConfig.Bodies Coach*)
	CoachSquatavious = 1.40, CoachBenchamin = 1.50, CoachSumo = 1.10 } :: { [string]: number }

-- Where shape `shape` on `side` sits in its hand part's space (the body's own, Default, hand), for `build`.
function HandShapeConfig.offset(build: string, shape: string, side: string): Vector3
	local size = HandShapeConfig.HandSize[build] or 1
	local mesh = HandShapeConfig.Meshes[shape .. "_" .. side]
	return if mesh then mesh.offset * size else Vector3.zero
end

-- A stretch of an animation (seconds into it) and the shape each hand shows then (nil = the fist).
export type Span = { from: number, to: number, left: string?, right: string? }

local function both(from: number, to: number, shape: string): Span
	return { from = from, to = to, left = shape, right = shape }
end

local function right(from: number, to: number, shape: string): Span
	return { from = from, to = to, right = shape }
end

local function left(from: number, to: number, shape: string): Span
	return { from = from, to = to, left = shape }
end

-- By celebration id (CelebrationConfig) and emote id (EmoteConfig). Hands are OPEN unless a span says otherwise (user
-- 2026-11-12: open by default, closed only to grip or for fist pumps; open while clapping, flat for a salute, one clear
-- finger to point).
local CELEBRATIONS: { [string]: { Span } } = {
	ChalkClapPump = { right(1.6, 2.45, "Fist") },                                  -- the clap is open; one fist pump
	ExitFistPump = { right(0.15, 1.5, "Fist") },
	FistSalute = { right(0.2, 1.9, "Fist") },
	-- MilitarySalute, WingspanHold, ArmsUpBounce, SitAndLaugh, ThankYouWave: open all the way.
	SkyPoint = { right(0.25, 3.05, "Point") },                                     -- a finger to the sky as the arm rises
	LightsArmsUp = { both(1.45, 3.1, "Fist") },                                    -- open on the hips; fists shoot up
	PointAndPrance = { both(1.05, 2.8, "Point") },                                 -- giddy open hands, then pointing up
	RackSideRoar = { both(0.2, 2.3, "Fist") },
	CrouchRoarJump = { both(0.25, 3.6, "Fist") },
	WingspanCrunch = { both(2.45, 3.6, "Fist") },                                  -- open T; fists for the crunch
	DisbeliefPrayer = { both(1.95, 2.6, "Fist"), both(6.4, 7.5, "Fist") },         -- fists yanked in; the V roar
	WingspanBiceps = { both(0.2, 0.9, "Fist"), both(3.95, 5.2, "Fist") },          -- the crouched scream; double biceps
	BowAndRise = { both(3.6, 4.95, "Fist") },                                      -- fists at the chin, driven down
	RecordJumpRoar = { both(5.4, 6.6, "Fist"), right(7.2, 7.95, "Fist") },         -- the punching jump; a fist to the sky
	CrowdPleaser = { right(0.2, 1.25, "Fist"), both(2.7, 3.8, "ThumbsUp") },       -- fist pumps; double thumbs up
	Shhh = { right(0.2, 2.75, "Point") },                                          -- a finger to the lips
	-- From the full Meet Study (2026-11-14/15; each clip's notes in celebration_animations.py give these)
	HeadClampRoar = { both(0.85, 2.45, "Fist"), both(4.5, 6.2, "Fist") },          -- biceps and V; open on the head; low roar
	GorillaRoar = { both(0.3, 3.1, "Fist") },
	HammerFistRoar = { right(0.35, 0.95, "Fist"), both(1.0, 2.9, "Fist") },        -- fist to the sky; hammer down
	HopSkyPunch = { left(0.5, 1.4, "Fist") },                                      -- the punch at the sky
	FistsBesideHead = { both(0.2, 0.45, "Fist"), both(0.7, 1.8, "Fist") },         -- open for the clap
	SkyPointChalkYes = { right(0.4, 1.45, "Point"), both(2.3, 3.4, "Fist") },      -- open for the clap and the spread
	HunchedDance = { both(0.25, 3.4, "Fist") },
	ChalkClapRightHere = { both(2.4, 3.0, "Fist"), right(3.65, 4.6, "Point") },    -- open wide and for the clap; point down
	VStrutRoar = { both(1.75, 3.45, "Fist"), right(4.35, 5.0, "Point"), right(5.15, 5.5, "Fist") },
	BackRollLegsUp = { both(6.3, 6.95, "Fist") },                                  -- fists low getting up; open claps
	OneKneeFistPumps = { both(0.3, 5.0, "Fist") },
	CrucifixTears = { both(0.2, 0.95, "Fist") },                                   -- the V; open palms for the crucifix
	SkyFingerArmsCrossed = { right(0.3, 1.7, "Point"), both(2.5, 6.3, "Fist") },   -- finger up; fists at the shoulders
	Gunslinger = { left(0.6, 1.95, "Point"), right(0.6, 3.55, "Point"), both(3.6, 4.45, "Fist") },
	AreYouNotEntertained = { right(0.3, 1.4, "Fist") },                            -- open slap; open palms-up spread
	LongVHold = { both(0.4, 5.0, "Fist"), right(5.0, 5.6, "Fist") },
	StageEdgeDoubleBiceps = { both(0.3, 4.9, "Fist") },
	FistsChestCeilingRoar = { both(0.35, 4.3, "Fist") },
	-- LightsArmsWideHeadHands: open all the way.
	-- Miss reactions over the walk back (user 2026-11-15; MissHandsOnHead is open all the way, flat on the head)
	MissArmSwipe = { right(0.15, 0.9, "Fist") },                                   -- the swipe; open on the hips
	MissYell = { both(0.2, 2.2, "Fist") },                                         -- tense fists low, driven down
}
local EMOTES: { [string]: { Span } } = {
	BeltTighten = { both(0.3, 1.35, "Fist") },                                     -- gripping the belt; the slap is open
	DoubleBiceps = { both(0.0, 99, "Fist") },
	MostMuscular = { both(0.0, 99, "Fist") },
	PointLaugh = { right(0.15, 1.25, "Point") },
	-- Wave, ChalkClap, TrapSlap, SitBreath: open.
}

-- By walk-out style (EntranceConfig.Entrances): its hype move's hands (2026-11-15: hype moves had no timeline, so the
-- Flex's double biceps showed open hands). Open unless a span says otherwise (claps, slaps and belt taps open).
local HYPES: { [string]: { Span } } = {
	Swagger = { both(0.5, 2.0, "Fist") },                                         -- Hype_Flex: fists for the double biceps
}

-- The timeline for an animation, by its AnimationId ("rbxassetid://..."), or nil.
HandShapeConfig.ByAnimation = {} :: { [string]: { Span } }
local function digits(id: string?): string?
	return if id then string.match(id, "%d+$") else nil
end
for id, spans in pairs(CELEBRATIONS) do
	local entry = CelebrationConfig.get(id)   -- (a celebration or a miss reaction)
	local key = digits(entry and entry.animationId)
	if key then
		HandShapeConfig.ByAnimation[key] = spans
	end
end
for style, spans in pairs(HYPES) do
	local entrance = EntranceConfig.Entrances[style]
	local key = digits(entrance and entrance.hypeAnimationId)
	if key then
		HandShapeConfig.ByAnimation[key] = spans
	end
end
for _, emote in ipairs(EmoteConfig.List) do
	local key = digits(emote.animationId)
	if key and EMOTES[emote.id] then
		HandShapeConfig.ByAnimation[key] = EMOTES[emote.id]
	end
end

-- The podium ceremony (CeremonyConfig): the referee's fists close round the medal's ribbon until he lets go.
do
	local CeremonyConfig = require(script.Parent:WaitForChild("CeremonyConfig"))
	local key = digits(CeremonyConfig.Animations.RefPlaceMedal)
	if key then
		HandShapeConfig.ByAnimation[key] = { both(0.0, CeremonyConfig.Times.MedalLetGo, "Grip") }
	end
end

function HandShapeConfig.timelineFor(animationId: string): { Span }?
	local key = digits(animationId)
	return if key then HandShapeConfig.ByAnimation[key] else nil
end

-- The shape `side` shows at `t` seconds into a timeline (nil = the fist).
function HandShapeConfig.shapeAt(spans: { Span }, t: number, side: string): string?
	for _, span in ipairs(spans) do
		if t >= span.from and t < span.to then
			return if side == "Left" then span.left else span.right
		end
	end
	return nil
end

return HandShapeConfig
