--!strict
--[[
	HandShapeConfig
	Shared / Config

	Hand-shape swaps on the cartoon bodies (GAME_DESIGN.md §38.7, user's pick: "Lets use hand-shape swaps"). The body's
	own hands are OPEN (user 2026-11-12, after a play test: "open by default, close only when gripping"). A lift's grip, a
	celebration or an emote shows another shape (Fist, Point, ThumbsUp) when it needs one: the open hand hides and the
	shape shows in its place, on the same hand, bending with the wrist.

	The shapes are one uploaded model (art/exports/CartoonHands_03.glb, made by art/scripts/build_cartoon_rig_02.py from
	build_cartoon_hands_03.py), one rigid MeshPart per shape and side, "<Shape>_<Side>", at a hand size of 1. Each build
	scales them by its hand size. Shapes: centre and size of each mesh in the hand bone's space at hand size 1 (Roblox
	axes), from art/exports/CartoonHands_03.json; a shape goes at handSize * (its centre - the open hand's centre) from
	the body's hand part (which is exactly the open hand).

	Who swaps: every client, for every character it sees (client HandShapeAnimator), from the animation's own playing
	time, so everyone sees the same hands. The server puts the hidden shapes on each body (LifterBodyService).

	Timelines (Claude's pick, 2026-11-12, frame by frame from art/scripts/celebration_animations.py and
	emote_animations.py): fists for pumps, roars, flexes and anything held; Point for Sky Point, "shhh" and pointing;
	thumbs up for Crowd Pleaser's double thumbs up; open everywhere else (waves, claps, salutes, hands on the head,
	the hips, the floor or the heart, arms flung wide).
]]

local CelebrationConfig = require(script.Parent:WaitForChild("CelebrationConfig"))
local EmoteConfig = require(script.Parent:WaitForChild("EmoteConfig"))

local HandShapeConfig = {}

-- The shapes model (materials.json "CartoonHands_03"); 0 = not uploaded yet (no swaps then, fists stay).
HandShapeConfig.AssetId = 0
-- Folder in the character holding the hidden shapes.
HandShapeConfig.FolderName = "HandShapes"

-- The swaps. The body's own hands are OPEN (art/scripts/build_cartoon_rig_02.py DEFAULT_HAND), so a closed fist is a
-- swap too: gripping the bar, the belt, a fist pump.
HandShapeConfig.Default = "Open"
HandShapeConfig.Shapes = { "Fist", "Point", "ThumbsUp" }
-- What the hands show while they grip something (the bar in a lift: client StationPoseAnimator says when).
HandShapeConfig.Grip = "Fist"

export type Mesh = { centre: Vector3, size: Vector3 }

-- From art/exports/CartoonHands_03.json (hand size 1, Roblox axes).
HandShapeConfig.Meshes = {
	Open_Left = { centre = Vector3.new(0.0159, -0.2668, -0.0726), size = Vector3.new(0.2816, 0.722, 0.5322) },
	Open_Right = { centre = Vector3.new(-0.0159, -0.2668, -0.0726), size = Vector3.new(0.2816, 0.722, 0.5322) },
	Point_Left = { centre = Vector3.new(0.0769, -0.2583, -0.0082), size = Vector3.new(0.4037, 0.7049, 0.401) },
	Point_Right = { centre = Vector3.new(-0.0769, -0.2583, -0.0082), size = Vector3.new(0.4037, 0.7049, 0.401) },
	ThumbsUp_Left = { centre = Vector3.new(0.0483, -0.187, -0.0314), size = Vector3.new(0.3461, 0.5624, 0.4503) },
	ThumbsUp_Right = { centre = Vector3.new(-0.0483, -0.187, -0.0314), size = Vector3.new(0.3461, 0.5624, 0.4503) },
	Fist_Left = { centre = Vector3.new(0.077, -0.1463, -0.0076), size = Vector3.new(0.4038, 0.4811, 0.4022) },
	Fist_Right = { centre = Vector3.new(-0.077, -0.1463, -0.0076), size = Vector3.new(0.4038, 0.4811, 0.4022) },
} :: { [string]: Mesh }

-- Each build's hand size (build_cartoon_rig_02.py BUILDS).
HandShapeConfig.HandSize = { Skinny = 0.95, Heavy = 1.15, Muscular = 1.28 } :: { [string]: number }

-- Where shape `shape` on `side` sits in its hand part's space (the body's own, Default, hand), for `build`.
function HandShapeConfig.offset(build: string, shape: string, side: string): Vector3
	local size = HandShapeConfig.HandSize[build] or 1
	local mesh = HandShapeConfig.Meshes[shape .. "_" .. side]
	local own = HandShapeConfig.Meshes[HandShapeConfig.Default .. "_" .. side]
	return (mesh.centre - own.centre) * size
end

-- A stretch of an animation (seconds into it) and the shape each hand shows then (nil = the fist).
export type Span = { from: number, to: number, left: string?, right: string? }

local function both(from: number, to: number, shape: string): Span
	return { from = from, to = to, left = shape, right = shape }
end

local function right(from: number, to: number, shape: string): Span
	return { from = from, to = to, right = shape }
end

-- By celebration id (CelebrationConfig) and emote id (EmoteConfig). Hands are OPEN unless a span says otherwise (user
-- 2026-11-12: open by default, closed only to grip or for fist pumps; open while clapping, flat for a salute, one clear
-- finger to point).
local CELEBRATIONS: { [string]: { Span } } = {
	ChalkClapPump = { right(1.6, 2.45, "Fist") },                                  -- the clap is open; one fist pump
	ExitFistPump = { right(0.15, 1.5, "Fist") },
	FistSalute = { right(0.2, 1.9, "Fist") },
	-- MilitarySalute, WingspanHold, ArmsUpBounce, SitAndLaugh, LeapAndBow, ThankYouWave: open all the way.
	SkyPoint = { right(0.25, 3.05, "Point") },                                     -- a finger to the sky as the arm rises
	ReliefRoar = { both(0.25, 1.6, "Fist") },                                      -- tense fists low; open on the head
	LightsArmsUp = { both(1.45, 3.1, "Fist") },                                    -- open on the hips; fists shoot up
	PointAndPrance = { both(1.0, 2.6, "Point") },                                  -- giddy open hands, then pointing up
	RackSideRoar = { both(0.2, 2.3, "Fist") },
	CrouchRoarJump = { both(0.25, 3.6, "Fist") },
	WingspanCrunch = { both(2.45, 3.6, "Fist") },                                  -- open T; fists for the crunch
	DisbeliefPrayer = { both(1.85, 2.5, "Fist"), both(6.4, 7.5, "Fist") },         -- fists yanked in; the V roar
	WingspanBiceps = { both(0.2, 0.9, "Fist"), both(3.95, 5.2, "Fist") },          -- the crouched scream; double biceps
	BowAndRise = { both(3.6, 4.95, "Fist") },                                      -- fists at the chin, driven down
	RecordJumpRoar = { both(5.4, 6.6, "Fist"), right(7.2, 7.75, "Fist") },         -- the punching jump; a fist to the sky
	CrowdPleaser = { right(0.2, 1.25, "Fist"), both(2.7, 3.8, "ThumbsUp") },       -- fist pumps; double thumbs up
	Shhh = { right(0.2, 2.75, "Point") },                                          -- a finger to the lips
}
local EMOTES: { [string]: { Span } } = {
	BeltTighten = { both(0.3, 2.2, "Fist") },                                      -- gripping the belt
	DoubleBiceps = { both(0.0, 99, "Fist") },
	MostMuscular = { both(0.0, 99, "Fist") },
	PointLaugh = { right(0.15, 1.25, "Point") },
	-- Wave, ChalkClap, TrapSlap, SitBreath: open.
}

-- The timeline for an animation, by its AnimationId ("rbxassetid://..."), or nil.
HandShapeConfig.ByAnimation = {} :: { [string]: { Span } }
local function digits(id: string?): string?
	return if id then string.match(id, "%d+$") else nil
end
for id, spans in pairs(CELEBRATIONS) do
	local key = digits(CelebrationConfig.byId[id] and CelebrationConfig.byId[id].animationId)
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
