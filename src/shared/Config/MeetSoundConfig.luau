--!strict
--[[
	MeetSoundConfig
	Shared / Config

	The bar, crowd and background sounds (GAME_DESIGN §37.5 "Meet sounds"). An
	empty id plays nothing, so the game works with any of them missing.

	WHERE SOUNDS MAY COME FROM: the Sonniss GDC bundles (built by
	art/scripts/make_meet_sounds.py; the WAVs stay outside this public repo, ids in
	art/sounds/sonniss_sounds.json), our own recordings or syntheses, or Roblox's
	licensed library, always uploaded under the game's group. NOT the kit in
	RobloxKits/SFX: it has no licence and is ripped from other games. Every id gets
	a `source` saying where it came from.

	The cues, and when the server sends them:
	  Clap        the head referee's command (real referees clap as they call)
	  BarRack     the bar leaving the J-cups, and going back into them after the lift
	  BarThud1-4  a deadlift landing, light to massive (barThudCue picks by the bar's weight)
	  BarCaught   the spotters taking a missed squat or bench
	  BarShake    a gym squat or bench rep, at the bottom (StationRepSounds)
	  LightsGood / LightsBad   the three referees' lights coming on
	  CrowdCheer / CrowdGroan  the hall's answer, just after the lights
	  LiftCrowd / LiftShout1-21 / WalkShout1-11  people yelling the lifter on, from the walk out
	  SquatShout1-3 / BenchShout1-3 / DeadliftShout1-3  what people yell at that lift
	  GoodShout1-10 / MissShout1-12  someone reacting after the lights, laughs and "nice try" at a miss
	  BigShout1-5  someone calling out a new best, a record, a saved meet or the lead

	PERFORMANCE: every cue is its own Sound, loaded when the game starts. Each single-voice shout from
	number 9 on has one Sound and is about 1.5 s of mono audio, so the 58 of them add little, but new
	ones aren't free: reuse one before adding another.
]]

local MeetSoundConfig = {}

export type Cue = {
	id: string,
	volume: number,
	-- Full volume out to `near` studs from the platform, silent at `far`.
	near: number,
	far: number,
	-- Sounds at once for this cue (the oldest is cut off when more come).
	voices: number,
	-- At least this long between plays, except on the listener's own platform: 8 platforms lift at once.
	minGapSeconds: number,
	source: string,
}

local function cue(id: string, volume: number, near: number, far: number, voices: number, minGapSeconds: number,
	source: string): Cue
	return { id = id, volume = volume, near = near, far = far, voices = voices, minGapSeconds = minGapSeconds,
		source = source }
end

-- One voice in the crowd: one Sound each, however many there are. A voice never overlaps itself, so one is plenty.
local function shout(id: string, source: string): Cue
	return cue(id, 0.8, 24, 90, 1, 2, source)
end

MeetSoundConfig.Cues = {
	Clap = cue("rbxassetid://117883845964473", 0.5, 14, 60, 2, 0, "Own work, made by make_meet_sounds.py"),
	BarRack = cue("rbxassetid://86935138704030", 1, 16, 80, 2, 0, "Sonniss layers (Borg Sound, Gym weights), made by make_meet_sounds.py"),
	-- The plates' hit gets louder and deeper with the weight, and carries further across the hall. All four volumes stay
	-- equal: the loudness is in the files, so the bar's own noise after the hit sounds the same at every weight.
	BarThud1 = cue("rbxassetid://99006547979222", 1, 14, 80, 2, 0, "Sonniss layers, made by make_meet_sounds.py"),
	BarThud2 = cue("rbxassetid://74202992096015", 1, 18, 110, 2, 0, "Sonniss layers, made by make_meet_sounds.py"),
	BarThud3 = cue("rbxassetid://91626447337542", 1, 24, 150, 2, 0, "Sonniss layers, made by make_meet_sounds.py"),
	BarThud4 = cue("rbxassetid://115911115288617", 1, 30, 200, 2, 0, "Sonniss layers, made by make_meet_sounds.py"),
	BarCaught = cue("rbxassetid://90626293042410", 0.8, 14, 80, 2, 0, "Sonniss layers, made by make_meet_sounds.py"),
	BarShake = cue("rbxassetid://133585865400084", 1, 14, 60, 2, 0, "Sonniss: Christophe Davaille, The Gym - Sounds Of Bodybuilding"),
	LightsGood = cue("rbxassetid://133004907730711", 0.35, 16, 90, 2, 0, "Own work, made by make_meet_sounds.py"),
	LightsBad = cue("rbxassetid://126005722823250", 0.22, 16, 90, 2, 0, "Own work, made by make_meet_sounds.py"),
	CrowdCheer = cue("rbxassetid://117986972792203", 0.5, 30, 140, 2, 3, "Sonniss: Small Club, 50 People"),
	CrowdGroan = cue("rbxassetid://106001648154233", 0.45, 30, 140, 2, 3, "Sonniss: Bar Pub, Boo, Aww"),
	-- During a lift: the same recording as the cheer, quieter, under the shouts.
	LiftCrowd = cue("rbxassetid://117986972792203", 0.3, 30, 140, 3, 5, "Sonniss: Small Club, 50 People"),
	-- During a lift: single voices yelling the lifter on (prompts in art/sounds/elevenlabs_shouts.json).
	LiftShout1 = cue("rbxassetid://88650045295512", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: UP! UP! UP!"),
	LiftShout2 = cue("rbxassetid://85759075386502", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: UPPPPP!"),
	LiftShout3 = cue("rbxassetid://102145250898707", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: You got this!"),
	LiftShout4 = cue("rbxassetid://124723740426288", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: Come on!"),
	LiftShout5 = cue("rbxassetid://132787944284167", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: Let's go!"),
	LiftShout6 = cue("rbxassetid://134812369331510", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: Drive!"),
	LiftShout7 = cue("rbxassetid://96519684386231", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: Keep pushing!"),
	LiftShout8 = cue("rbxassetid://93544230817104", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: Big lift, come on!"),
	-- On the walk out to the bar only (walkOutShouts).
	WalkShout1 = cue("rbxassetid://82391465593479", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: Easy weight!"),
	WalkShout2 = cue("rbxassetid://108091981985004", 0.8, 24, 90, 2, 2, "ElevenLabs Sound Effects: Easy!"),
	-- On the walk out, more voices.
	WalkShout3 = shout("rbxassetid://79247368338280", "ElevenLabs Sound Effects: Let's goooooo!"),
	WalkShout4 = shout("rbxassetid://98604994214888", "ElevenLabs Sound Effects: Let's goooo!"),
	WalkShout5 = shout("rbxassetid://101894713441519", "ElevenLabs Sound Effects: Light weight!"),
	WalkShout6 = shout("rbxassetid://132519921470853", "ElevenLabs Sound Effects: You own this!"),
	WalkShout7 = shout("rbxassetid://138547795525987", "ElevenLabs Sound Effects: This is yours!"),
	WalkShout8 = shout("rbxassetid://82667830825330", "ElevenLabs Sound Effects: Go get it!"),
	WalkShout9 = shout("rbxassetid://113888590268054", "ElevenLabs Sound Effects: Nice and tight!"),
	WalkShout10 = shout("rbxassetid://104016337436187", "ElevenLabs Sound Effects: Time to work!"),
	WalkShout11 = shout("rbxassetid://85863084757990", "ElevenLabs Sound Effects: Easy money!"),
	-- During any lift, more voices, wordless rallying cheers first (the first takes sounded terrified: user 2026-11-05).
	LiftShout9 = shout("rbxassetid://123615255611016", "ElevenLabs Sound Effects: happy YEEEEAAAAAH! cheer"),
	LiftShout10 = shout("rbxassetid://110678563480923", "ElevenLabs Sound Effects: joyful WOOOOOOOO! cheer"),
	LiftShout11 = shout("rbxassetid://111261566401497", "ElevenLabs Sound Effects: deep HOOOOO-RAAAAH! rally cheer"),
	LiftShout12 = shout("rbxassetid://120019086737764", "ElevenLabs Sound Effects: excited AAAAYYYYYYY! cheer"),
	LiftShout13 = shout("rbxassetid://88128578376287", "ElevenLabs Sound Effects: Push! Push! Push!"),
	LiftShout14 = shout("rbxassetid://92859395750675", "ElevenLabs Sound Effects: Get it! Get it!"),
	LiftShout15 = shout("rbxassetid://70809770249736", "ElevenLabs Sound Effects: Don't you quit!"),
	LiftShout16 = shout("rbxassetid://113179212662492", "ElevenLabs Sound Effects: All you! All you!"),
	LiftShout17 = shout("rbxassetid://138376250510208", "ElevenLabs Sound Effects: Finish it!"),
	LiftShout18 = shout("rbxassetid://92491501492797", "ElevenLabs Sound Effects: Stay tight!"),
	LiftShout19 = shout("rbxassetid://131316488877824", "ElevenLabs Sound Effects: Keep going!"),
	LiftShout20 = shout("rbxassetid://135790096814440", "ElevenLabs Sound Effects: Up! Up! Up!"),
	LiftShout21 = shout("rbxassetid://121978364157695", "ElevenLabs Sound Effects: Up! Up!"),
	-- During that lift only.
	SquatShout1 = shout("rbxassetid://75834581112249", "ElevenLabs Sound Effects: Knees out!"),
	SquatShout2 = shout("rbxassetid://106441317874920", "ElevenLabs Sound Effects: Chest up!"),
	SquatShout3 = shout("rbxassetid://81238679048761", "ElevenLabs Sound Effects: Stand it up!"),
	BenchShout1 = shout("rbxassetid://104462044381291", "ElevenLabs Sound Effects: Leg drive!"),
	BenchShout2 = shout("rbxassetid://97462955193534", "ElevenLabs Sound Effects: Stay on it!"),
	BenchShout3 = shout("rbxassetid://108076731648106", "ElevenLabs Sound Effects: Squeeze it!"),
	DeadliftShout1 = shout("rbxassetid://82181720916294", "ElevenLabs Sound Effects: Pull! Pull! Pull!"),
	DeadliftShout2 = shout("rbxassetid://104521722412983", "ElevenLabs Sound Effects: Lock it out!"),
	DeadliftShout3 = shout("rbxassetid://81875562795817", "ElevenLabs Sound Effects: Hips through!"),
	-- After a good lift.
	GoodShout1 = shout("rbxassetid://125876457036400", "ElevenLabs Sound Effects: Let's goooooo!"),
	GoodShout2 = shout("rbxassetid://83399404070933", "ElevenLabs Sound Effects: Yeah! Let's go!"),
	GoodShout3 = shout("rbxassetid://127084376899712", "ElevenLabs Sound Effects: That's what I'm talking about!"),
	GoodShout4 = shout("rbxassetid://102327352629954", "ElevenLabs Sound Effects: Light work!"),
	GoodShout5 = shout("rbxassetid://98125825945499", "ElevenLabs Sound Effects: Too easy!"),
	GoodShout6 = shout("rbxassetid://123984005671168", "ElevenLabs Sound Effects: There it is!"),
	GoodShout7 = shout("rbxassetid://89927247474830", "ElevenLabs Sound Effects: Beautiful lift!"),
	GoodShout8 = shout("rbxassetid://97483044506373", "ElevenLabs Sound Effects: So strong!"),
	GoodShout9 = shout("rbxassetid://108238962444743", "ElevenLabs Sound Effects: What a lift!"),
	GoodShout10 = shout("rbxassetid://101878361109447", "ElevenLabs Sound Effects: WOOOOOO!"),
	-- After a miss.
	MissShout1 = shout("rbxassetid://111464244047245", "ElevenLabs Sound Effects: Single man laughing loudly"),
	MissShout2 = shout("rbxassetid://132065134091851", "ElevenLabs Sound Effects: Nice try!"),
	MissShout3 = shout("rbxassetid://103552772847361", "ElevenLabs Sound Effects: Single woman laughing out loud"),
	MissShout4 = shout("rbxassetid://138261206183662", "ElevenLabs Sound Effects: Single young man laughing hard"),
	MissShout5 = shout("rbxassetid://107755833351562", "ElevenLabs Sound Effects: Nice try!"),
	MissShout6 = shout("rbxassetid://90471194455503", "ElevenLabs Sound Effects: So close!"),
	MissShout7 = shout("rbxassetid://128205685292520", "ElevenLabs Sound Effects: You'll get it next time!"),
	MissShout8 = shout("rbxassetid://89232899893228", "ElevenLabs Sound Effects: You've got the next one!"),
	MissShout9 = shout("rbxassetid://133322911119247", "ElevenLabs Sound Effects: Unlucky!"),
	MissShout10 = shout("rbxassetid://107299750113352", "ElevenLabs Sound Effects: Almost!"),
	MissShout11 = shout("rbxassetid://123781580033789", "ElevenLabs Sound Effects: Ooooooh!"),
	MissShout12 = shout("rbxassetid://90086924258505", "ElevenLabs Sound Effects: Next one!"),
	-- First voice after a big moment (momentShouts).
	BigShout1 = shout("rbxassetid://127030106765313", "ElevenLabs Sound Effects: New PR! New PR!"),
	BigShout2 = shout("rbxassetid://139968385671294", "ElevenLabs Sound Effects: That's a PR!"),
	BigShout3 = shout("rbxassetid://103825655529490", "ElevenLabs Sound Effects: New gym record!"),
	BigShout4 = shout("rbxassetid://132348431572583", "ElevenLabs Sound Effects: Yes! Still in it!"),
	BigShout5 = shout("rbxassetid://94374920564013", "ElevenLabs Sound Effects: You took the lead!"),
} :: { [string]: Cue }

--[[
	Gym training reps (StationRepSounds): when in each rep the bar makes its sound, in
	seconds into the 6-second loop (station_animations.py PHASES): a deadlift reaches the
	floor at 4.2, a squat reaches the bottom at 1.9, a bench touches the chest at 2.0.
	Reps repeat, so they are quieter than a meet lift. Others' reps are heard only from
	close by and are spaced out.
]]
MeetSoundConfig.TrainingReps = {
	moments = { Deadlift = 4.2, Squat = 1.9, Bench = 2.0 } :: { [string]: number },
	ownVolume = 0.6,
	othersVolume = 0.35,
	othersHeardStuds = 45,
	othersGapSeconds = 1.5,
}

-- The sound of a gym rep. A deadlift's thud follows the lifter's own number: every rack's bar looks the same.
function MeetSoundConfig.repCue(lift: string, competitionNumberKg: number): string
	return if lift == "Deadlift" then MeetSoundConfig.barThudCue(competitionNumberKg, false) else "BarShake"
end

-- The heaviest bar each thud is for, in kg. Above the last one is BarThud4. (Deadlift records run from about 300 kg up.)
MeetSoundConfig.BarThudUpToKg = { 100, 180, 260 }

-- The thud for a deadlift of this weight. Dropped from above the knees, it lands one size bigger than set down.
function MeetSoundConfig.barThudCue(weightKg: number, dropped: boolean): string
	local tier = #MeetSoundConfig.BarThudUpToKg + 1
	for index, upTo in ipairs(MeetSoundConfig.BarThudUpToKg) do
		if weightKg <= upTo then
			tier = index
			break
		end
	end
	if dropped then
		tier = math.min(tier + 1, #MeetSoundConfig.BarThudUpToKg + 1)
	end
	return "BarThud" .. tier
end

-- What the bar makes at the end of a lift. A missed deadlift in part 1 never left the floor; in part 2 it is dropped.
function MeetSoundConfig.endOfLiftCue(lift: string, good: boolean, failedPart: number, weightKg: number): string
	if lift == "Deadlift" then
		return MeetSoundConfig.barThudCue(weightKg, not good and failedPart >= 2)
	end
	return if good then "BarRack" else "BarCaught"
end

-- How long a deadlift dropped at the failed lockout takes to reach the floor after leaving the hands. The bar glides down
-- on the client (StationPoseAnimator GLIDE_RATE 7): most of the way in this time.
MeetSoundConfig.DropFallSeconds = 0.3

-- Seconds between a missed bar leaving the hands and the sound of it landing or being caught.
function MeetSoundConfig.fallSeconds(lift: string, failedPart: number): number
	return if lift == "Deadlift" and failedPart >= 2 then MeetSoundConfig.DropFallSeconds else 0
end

-- From a good squat or bench's bar being let go to it reaching the J-cups (StationPoseAnimator GLIDE_RATE 7).
MeetSoundConfig.RackGlideSeconds = 0.3

-- From the lights to the crowd's cheer, or from a missed bar landing to the groan.
MeetSoundConfig.CrowdDelaySeconds = 0.25

export type Background = {
	-- A Model or Folder directly in Workspace: the player is "in" it inside its bounding box (each child's, for a Folder).
	place: string,
	id: string,
	volume: number,
	source: string,
}

-- The looping background of each place, heard equally all over it. The first place the player is inside wins, so the
-- smaller places come before the gym. Outside all of them there is none.
MeetSoundConfig.Backgrounds = {
	{ place = "LocalMeetVenue", id = "rbxassetid://93797393745230", volume = 0.5, source = "Sonniss crowds with far-off weights, made by make_meet_sounds.py" },
	{ place = "StateArenaVenue", id = "rbxassetid://105086233520753", volume = 0.4, source = "Sonniss: volleyball match crowd in a made big room, made by make_meet_sounds.py" },
	{ place = "MockMeetRooms", id = "rbxassetid://99057894405433", volume = 0.25, source = "The gym's background, quieter: a Mock Meet is a closed room in the gym" },
	{ place = "StarterGym", id = "rbxassetid://99057894405433", volume = 0.35, source = "Sonniss: ventilation, far voices, weights in other rooms, made by make_meet_sounds.py" },
} :: { Background }

MeetSoundConfig.BackgroundFadeSeconds = 2

--[[
	People yell a lifter through the lift (§37.5, user 2026-11-05: "people screaming saying
	stuff like 'you got this' or 'UPPPP' while the lifter is lifting"). While a lift runs the
	server sends LiftCrowd every so often and one of the LiftShout cues that has a sound.
]]
MeetSoundConfig.LiftCrowd = {
	CrowdEverySeconds = 3.5,
	-- (How often the shouts come, and how loud all this is, goes by the attempt: LocalMeetConfig.StakesBuild.)
	-- Shouts from other platforms, all together, are at least this far apart on one player's screen.
	OthersShoutGapSeconds = 1.5,
	-- The crowd's answer to the player's own lift, after the lights.
	RoarVolume = 1.8,
	-- How long after the lights it may still come: a missed bar has to land first.
	RoarWindowSeconds = 6,
}

-- Those of these cues that have a sound.
local function withSounds(cues: { string }): { string }
	local names = {}
	for _, name in ipairs(cues) do
		local config = MeetSoundConfig.Cues[name]
		if config and config.id ~= "" then
			table.insert(names, name)
		end
	end
	return names
end

-- The cues Prefix1 to PrefixCount that have a sound, added to `extra`.
local function numbered(prefix: string, count: number, extra: { string }?): { string }
	local names = table.clone(extra or {})
	for number = 1, count do
		table.insert(names, prefix .. number)
	end
	return withSounds(names)
end

--[[
	The shouts during a lift: anyone can yell these at any lift, plus the lift's own, what people really yell at
	that lift (user 2026-11-05: "Just add more to the rotation and mix").
]]
function MeetSoundConfig.liftShouts(lift: string): { string }
	return numbered("LiftShout", 21, numbered(lift .. "Shout", 3))
end

-- The shouts on the walk out to the bar (user 2026-11-05: "You got this", "easy weight", "Lets go", "Easy").
function MeetSoundConfig.walkOutShouts(): { string }
	return numbered("WalkShout", 11, { "LiftShout3", "LiftShout5" })
end

-- After the lights (user 2026-11-05): someone yells for a good lift, and someone laughs or says nice try at a miss.
function MeetSoundConfig.goodShouts(): { string }
	return numbered("GoodShout", 10)
end

function MeetSoundConfig.missShouts(): { string }
	return numbered("MissShout", 12)
end

-- The voice that goes first after a big moment (LocalMeetService momentAfter). Others use goodShouts.
function MeetSoundConfig.momentShouts(moment: string): { string }
	local names: { string } = if moment == "NEW GYM RECORD!" then { "BigShout3" }
		elseif moment == "STILL IN THE MEET!" then { "BigShout4" }
		elseif moment == "TAKES THE LEAD!" then { "BigShout5" }
		elseif moment == "NEW BEST!" then { "BigShout1", "BigShout2" }
		else {}
	return withSounds(names)
end

return MeetSoundConfig
