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

-- The default fail animation for `lift` failed in part `part` (1 or 2; anything else counts as the nearest).
function StationAnimationConfig.failFor(lift: string, part: number): Fail?
	local fails = StationAnimationConfig.Fails[lift]
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
