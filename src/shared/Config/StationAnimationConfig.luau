--!strict
--[[
	StationAnimationConfig
	Shared / Config

	The station rep animations (GAME_DESIGN.md §34.12 decision 15: slow repeating
	reps). They are made by art/scripts/station_animations.py, exported to
	art/animations/Station_<Lift>.rbxmx, and published to Roblox from Studio
	(Insert from File -> right-click the KeyframeSequence -> Save to Roblox).

	Paste each published ID below as "rbxassetid://<number>". An empty ID means
	that lift has no animation yet: the lifter keeps the still station position
	and the bar stays where it rests. Visual only; nothing here affects training.
]]

local StationAnimationConfig = {}

-- Published 2026-10-19 from art/animations/Station_<Lift>.rbxmx under the GROUP
-- that owns the game (529442797). An animation owned by anyone else (even the
-- group's owner personally) will not play in this game.
StationAnimationConfig.AnimationIds = {
	Squat = "rbxassetid://132820904488036",
	Bench = "rbxassetid://87040674560117",
	Deadlift = "rbxassetid://91506920973531",
} :: { [string]: string }

--[[
	When the bar is in the lifter's hands, in seconds into the 6-second loop.
	A lift not listed holds the bar the whole time (squat: on the back; bench).
	Deadlift: gripped at 1.6 s, set down at 4.3 s (station_animations.py
	DEADLIFT_BAR_HELD); otherwise the bar lies on the floor.
]]
StationAnimationConfig.BarHeldWindows = {
	Deadlift = { { 1.6, 4.3 } },
} :: { [string]: { { number } } }

--[[
	THE MEET LIFTS (GAME_DESIGN §37.5, user 2026-11-01): a meet plays the same
	reps ONE STAGE AT A TIME instead of looping, so the lifter does the lift the
	minigame is playing. Seconds into the 6-second loop (station_animations.py
	SQUAT_PHASES, BENCH_PHASES, DEADLIFT_PHASES):
		setup     the pose on arriving (from, to: played once; equal = held still)
		phases    one stretch per minigame phase. A player's FIRST phase follows
		          that minigame's live progress (MeetLiftProgress, user
		          2026-11-02: the character moves only as the meter fills, and
		          stands still when it slips back); a computer lifter's moves over
		          its time. The second phase is the pause before the command (a
		          timing check has no progress).
		finish    after a good lift: standing up / pressing / lockout and lowering
	Squat: 0.6 standing, 1.9 at the bottom, 2.1 to 3.1 stand up. Bench: 0.6 at
	lockout, 2.0 on the chest (still until 2.2), 2.2 to 3.0 press. Deadlift: 0.5 to
	1.8 hinge down and set, 1.8 to 2.2 pull to mid-thigh, above the knees (NOT locked out:
	user 2026-11-02, "why am i even locked out before i do the lock out game?"),
	held there straining through the lockout game, then 2.2 to 4.2: lock out
	(2.9), hold, lower.
]]
export type MeetStages = {
	setup: { number },
	phases: { { number } },
	finish: { number },
}
--[[
	THE MEET SETUPS (GAME_DESIGN §37.5, user 2026-11-08: "On squat im basically teleporting inside the bar, no unrack
	animation either on squat and bench. No walk up animation, no sitting down animation"), made after the SBD
	Sheffield 2026 video by art/scripts/setup_animations.py. Each plays once from where the walk out ends
	(MeetLiftAnimation.approachFor) and ends on the meet's rep pose above (MeetStages[lift].setup), so the lift carries
	straight on:
		Squat     two steps up, grip the bar wide, duck under it, brace, stand it up, three steps back, set
		Bench     turn round, back up to the bench, sit on its end, lie back, slide up, grip, the hand-off to arms' length
		Deadlift  set the feet, stand tall and breathe, hinge down, grip (right hand, then left), set
	The root part stands at the lift's spot all along; the walking is in the animation. `barHeldAt`: when the bar
	leaves its rest and is in the hands (the J-cups for squat and bench; the deadlift's stays on the floor until the
	lift). An empty id: no setup, the lifter is put at the bar as before.
]]
export type Setup = { id: string, length: number, barHeldAt: number }
StationAnimationConfig.Setups = {
	Squat = { id = "rbxassetid://81320883735495", length = 6.7, barHeldAt = 3.1 },
	Bench = { id = "rbxassetid://99874634718117", length = 6.9, barHeldAt = 5.4 },
	Deadlift = { id = "rbxassetid://112100062833525", length = 3.3, barHeldAt = 3.3 },
} :: { [string]: Setup }

StationAnimationConfig.MeetStages = {
	Squat = { setup = { 0.6, 0.6 }, phases = { { 0.6, 1.9 }, { 1.9, 2.1 } }, finish = { 2.1, 3.1 } },
	Bench = { setup = { 0.6, 0.6 }, phases = { { 0.6, 2.0 }, { 2.0, 2.2 } }, finish = { 2.2, 3.0 } },
	Deadlift = { setup = { 0.5, 1.8 }, phases = { { 1.8, 2.2 }, { 2.2, 2.2 } }, finish = { 2.2, 4.2 } },
} :: { [string]: MeetStages }

--[[
	THE FAIL ANIMATIONS (GAME_DESIGN §37.5 "The fail animations", 2026-11-02):
	one for each part of each lift (a lift's two parts are its two minigames).
	Made by art/scripts/fail_animations.py, exported to
	art/animations/Fail_<Lift>_<Part>.rbxmx, published from Studio under the
	group (as above; published by the user 2026-11-02), and pasted here as
	"rbxassetid://<number>". An empty ID plays nothing: the lifter holds where
	the lift stopped, and the spotters still take the bar.
		length   seconds, ending standing (bench: lying, relaxed)
		release  when the bar leaves the hands, seconds in (the spotters take it,
		         or the deadlift is set down); after it the bar goes back to its rest
		catch    when the spotters get their hands on the bar (nil: no catch)
	Keep these in step with fail_animations.py FAILS.
]]
export type Fail = { id: string, length: number, release: number, catch: number? }
StationAnimationConfig.Fails = {
	Squat = {
		{ id = "rbxassetid://84903718437719", length = 5.0, release = 1.3, catch = 0.9 }, -- 1: "Lost it on the way down"
		{ id = "rbxassetid://86328163429809", length = 5.6, release = 2.6, catch = 2.1 }, -- 2: "Stuck in the hole"
	},
	Bench = {
		{ id = "rbxassetid://76203047859489", length = 4.4, release = 2.2, catch = 1.5 }, -- 1: "Crushed on the way down"
		{ id = "rbxassetid://83126819156638", length = 4.4, release = 2.8, catch = 2.2 }, -- 2: "Stalls on the press"
	},
	Deadlift = {
		-- Both remade and published 2026-11-03 with art/scripts/upload_animations.py.
		{ id = "rbxassetid://136367570731516", length = 4.8, release = 2.55, catch = nil }, -- 1: "Won't break the floor"
		{ id = "rbxassetid://89595096759924", length = 3.8, release = 1.45, catch = nil }, -- 2: "Can't lock out"
	},
} :: { [string]: { Fail } }

--[[
	THE FAIL STYLES (user 2026-11-11: "Replace the failure itself", three styles, played at every meet): each a full set
	of the six fails, made by art/scripts/fail_styles.py (Fail_<Style>_<Lift>_<Part>), won at the celebration NPC's spin
	(CelebrationSpinService, by `rarity`) and saved per player (ProfileOperations.getFailStyle). Same fields as Fails;
	"Default" is everyone's (the Fails above). Keep these in step with fail_styles.py STYLES.
]]
export type FailStyle = { name: string, rarity: string, description: string, fails: { [string]: { Fail } } }
StationAnimationConfig.FailStyles = {
	Bailout = {
		name = "BAIL-OUT",
		rarity = "Common",
		description = "Quick escapes: dumps the squat off the back, lets go at once on the bench, drops the deadlift fast.",
		fails = {
			Squat = {
				{ id = "rbxassetid://104699451246353", length = 3.4, release = 0.6, catch = 0.5 },
				{ id = "rbxassetid://104224688950961", length = 3.4, release = 0.55, catch = 0.45 },
			},
			Bench = {
				{ id = "rbxassetid://119068247255634", length = 3.0, release = 0.7, catch = 0.45 },
				{ id = "rbxassetid://124963246140386", length = 3.0, release = 0.8, catch = 0.55 },
			},
			Deadlift = {
				{ id = "rbxassetid://91525345354865", length = 3.4, release = 0.9, catch = nil },
				{ id = "rbxassetid://89404221495583", length = 3.0, release = 0.35, catch = nil },
			},
		},
	},
	Grinder = {
		name = "GRINDER",
		rarity = "Uncommon",
		description = "Long, shaking grinds that get so close, then give out at the last moment.",
		fails = {
			Squat = {
				{ id = "rbxassetid://90292420083198", length = 5.2, release = 3.6, catch = 3.2 },
				{ id = "rbxassetid://130852838697366", length = 5.6, release = 3.8, catch = 3.4 },
			},
			Bench = {
				{ id = "rbxassetid://105833668719392", length = 4.6, release = 3.4, catch = 3.1 },
				{ id = "rbxassetid://83755185682700", length = 4.6, release = 3.3, catch = 2.9 },
			},
			Deadlift = {
				{ id = "rbxassetid://116590810428713", length = 4.8, release = 2.9, catch = nil },
				{ id = "rbxassetid://80066352596888", length = 3.9, release = 2.7, catch = nil },
			},
		},
	},
	Dramatic = {
		name = "DRAMATIC",
		rarity = "Rare",
		description = "Big collapses and frustration: floor slaps, head in hands, flopped out on the bench.",
		fails = {
			Squat = {
				{ id = "rbxassetid://138743801019475", length = 5.6, release = 1.3, catch = 0.9 },
				{ id = "rbxassetid://129516000420910", length = 5.6, release = 2.6, catch = 2.1 },
			},
			Bench = {
				{ id = "rbxassetid://122588216461359", length = 4.6, release = 2.2, catch = 1.5 },
				{ id = "rbxassetid://133908083326219", length = 4.6, release = 2.8, catch = 2.2 },
			},
			Deadlift = {
				{ id = "rbxassetid://108533985724841", length = 4.8, release = 3.0, catch = nil },
				{ id = "rbxassetid://103466352260214", length = 3.9, release = 1.45, catch = nil },
			},
		},
	},
} :: { [string]: FailStyle }
StationAnimationConfig.FailStyleOrder = { "Default", "Bailout", "Grinder", "Dramatic" }
-- The default set's own card text (it isn't in FailStyles).
StationAnimationConfig.DefaultFailStyle = {
	name = "STANDARD",
	rarity = "Default",
	description = "The usual misses: lost on the way down, stuck in the hole, crushed, stalled, won't break the floor.",
}

-- The fail animation for `lift` failed in part `part` (1 or 2; anything else counts as the nearest), in fail style
-- `style` (a FailStyles id; the default set for nil, "Default" or an unknown one).
function StationAnimationConfig.failFor(lift: string, part: number, style: string?): Fail?
	local chosen = if style then StationAnimationConfig.FailStyles[style] else nil
	local fails = if chosen then chosen.fails[lift] else StationAnimationConfig.Fails[lift]
	if fails == nil or #fails == 0 then
		return nil
	end
	return fails[math.clamp(part, 1, #fails)]
end

function StationAnimationConfig.isBarHeld(lift: string, timePosition: number): boolean
	local windows = StationAnimationConfig.BarHeldWindows[lift]
	if windows == nil then
		return true
	end
	for _, window in ipairs(windows) do
		if timePosition >= window[1] and timePosition < window[2] then
			return true
		end
	end
	return false
end

return StationAnimationConfig
