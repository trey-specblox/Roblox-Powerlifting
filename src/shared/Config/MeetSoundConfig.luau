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

return MeetSoundConfig
