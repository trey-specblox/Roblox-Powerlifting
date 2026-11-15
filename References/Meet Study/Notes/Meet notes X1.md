# Meet study notes, batch X1 (misses, fails, crazy moments, belt flick)

Helper X1, 2026-11-14. Pane note: the built-in browser pane is about 967x545 CSS px and screenshots come back at
800x450, so the 1290-px grids were scaled down to fit the pane (each 4-col frame ~197x110 px in the screenshot);
detail passes used 3-col __frames (9 per screenshot, ~260x146 px each). "Zoom" only crops (no magnification).

## 1. Videos and coverage log

| # | id | title | length | kind |
|---|----|-------|--------|------|
| 1 | A5A39IMP3gs | CRAZIEST Moments in POWERLIFTING History (Powerlifting World channel, IPF footage) | 7:01 | IPF broadcast clips + commentary (it DOES have auto captions, read in full) |
| 2 | UnUJPzEesc4 | MOST VIEWED Powerlifting Clips OF ALL TIME (Powerlifting World) | 12:09 | IPF broadcast clips + commentary (captions read in full) |
| 3 | iIvTXa3Hdlo | Worst Squat Fails Ever (Gym Fails) | 4:52 | gym phone clips, music; not meets |
| 4 | LpSFwM1m4h4 | Epic Squat Fail at IPF Worlds 2016 | 0:14 | one IPF broadcast clip |
| 5 | FnFKPop-3IE | Heaviest bench fail ever. 1121lb fall | 1:01 | crowd phone footage, big equipped bench meet (ballroom) |
| 6 | SzX6w5mBIr4 | 265lbs Bench Press Fail, Roll Of Shame | 1:26 | home gym, fixed phone |
| 7 | gOVF6cczJls | Epic Bench press fail compilation (Health Hub) | 3:23 | gym phone clips, music |
| 8 | EYoGp89tZ9o | TOP 10 Funny deadlift fails (Power Mafia Motivation) | 2:47 | gym clips + 1 outdoor event + 1 strongman comp |
| 9 | APg5YKsYM9Y | Bench press fail | 0:36 | garage gym, fixed camera |
| 10 | ngP2vaQHlPg | Belt Flick Montage (Short, 1080x1920) | 0:18 | gym montage, quick cuts |

Coverage log (every second of every video was looked at; nothing skipped):
- A5A39IMP3gs 0:00-7:01 gridded at 1 s (27 grids of 16). Details listed under the video.
- UnUJPzEesc4 0:00-12:09 gridded at 1 s (46 grids). Two mid-roll ads (at ~2:42 and ~6:09) interrupted grids; those
  grids were redone after the ad, so no gap.
- iIvTXa3Hdlo 0:00-4:52 at 1 s (16 4x4 grids to 4:15, then 1-s cropped sheets 4:16-4:50; 4:51-4:52 is the end card).
- LpSFwM1m4h4 0:00-0:13.8 at 1 s, plus 0.5 s and 0.1-0.25 s passes.
- FnFKPop-3IE 0:00-1:00 at 1 s, plus 0.1-0.5 s around the miss.
- SzX6w5mBIr4 0:00-1:26 at 1 s, plus 0.5 s around the roll.
- gOVF6cczJls 0:00-3:23 at 1 s, plus 0.5 s passes on the three user-marked fails.
- EYoGp89tZ9o 0:00-2:47 at 1 s, plus 0.5 s passes on every clip.
- APg5YKsYM9Y 0:00-0:35 at 1 s, plus 0.25-0.5 s on the plate dump.
- ngP2vaQHlPg 0:00-17.7 at 0.25 s throughout, plus 0.05-0.1 s waist close-ups on every belt moment.
- Note: my first tab (tab-12) was closed by something outside my control during video 8; I opened tab-13 and continued
  from the same point (EYoGp89tZ9o 0:32 onward had not been lost: 0:00-0:31 was already gridded).
- Videos 4-10 were loaded with the player's own loadVideoById inside one YouTube page (same setup code), so captions
  were not re-read for them; they are short clips with no commentary (music or ambient only), except LpSFwM1m4h4 whose
  burned-in captions were readable on the frames.

## Running notes (sorted into sections at the end)

### A5A39IMP3gs clip 1 (0:00-1:32): super-heavy man, 2019 IPF Worlds, 3rd squat after two misses (caption: "tries to stay in competition after two missed squat attempts")
- Venue: IPF World Classic look: white/grey back wall with world map print, sponsor boards (ELEIKO, APLYFT), upright
  squat rack with hooks, red 25 kg Eleiko plates (bar loaded nearly to the collar, ~8 plates a side),
  3 spotter-loaders in white tees + black shorts: one at each bar end + one behind the lifter. Officials in
  white shirts at the front side.
- 0:00-0:15: intro title over crowd. Crowd in the stands is ON ITS FEET, clapping (0:10-0:14), many filming on phones.
- 0:16-0:22: lifter stands beside the rack, back to us, waiting, side spotters at the plates.
- 0:23-0:26 (other camera, front): lifter in red singlet (USA top over it, black knee sleeves, red shoes, black
  headband) at the rack; 0:25 raises BOTH ARMS straight overhead to the crowd (hype the crowd) then lowers them;
  0:27-0:29 crowd shots standing and cheering.
- 0:30-0:34 close front shot under the bar: very WIDE grip (hands near the inside of the collars, ~1.7x shoulder
  width on a super-heavy body), elbows back, head ducked under, face calm/serious, eyes forward.
- 0:35-0:40 wide: bar unracked, he stands upright under it in the rack; side spotters keep hands cupped under the
  bar ends while he steps back.
- 0:41-0:47 close on the feet: walkout of about 3-4 short shuffling steps, very wide stance, toes turned out ~30-40 deg.
  Commentary: "better walk out", "it's very unsteady".
- 0:48-0:57: standing set, knees soft, small wobbles; side spotters crouch slightly, hands open under the sleeves.
- 0:58-1:01 (slow-motion close-up of the face, side): lips pursed, blowing out / big breath; headband.
- 1:02-1:03: descends (about 1 s from top to a deep bottom: hips clearly below knees); spotters drop into a squat with
  him, hands just under the bar ends, not touching.
- 1:04-1:06.5 THE STALL: drives up only to roughly half depth, then stops. Hips shoot back, chest tips forward
  (~45 deg torso), knees stay out. He holds there grinding for ~2.5 s; spotters squat beside him, forearms under the
  sleeves.
- 1:07-1:12 SPOTTER TAKE: both side spotters hug the bar ends (arms wrapped round the sleeve/plates) and lift with him;
  he rises with their help, torso still bent, head down. The back spotter is behind him. 1:12 he is upright.
- 1:13 lights graphic: 3 RED (bottom right of the broadcast, three small circles).
- 1:13-1:15: spotters steer the bar forward; he walks it into the hooks; bar racked at 1:15.
- 1:16-1:17: steps out from under the bar, both hands still on the bar, head down. A judge in white shirt (woman) and a
  bearded official step in close (commentary: "the judge hopping in there").
- 1:18-1:18.5: stands facing forward, pulls at his singlet straps/chest with both hands.
- 1:19-1:22: REACTION: folds forward over the racked bar (bar at chest height), both forearms on the bar, face buried
  in both hands for ~3 s; 1:22 lifts the head, one hand over the mouth.
- 1:23: straightens and steps away from the rack.
- 1:24-1:29: walks off to the side; the black-shirt loaders (4-5 of them) swarm the rack straight away to strip plates.
- 1:30-1:32 backstage close-up: sweaty, eyes down, mouth shut; his coach (older bald man, team polo) reaches up and puts
  his palm on the lifter's cheek/jaw (consoling touch) while the lifter keeps looking down.
- Situation: a living legend bombing out (three missed squats = out of the meet); crowd stayed standing the whole time.

### A5A39IMP3gs clip 2 (1:33-3:36): equipped super-heavy man (Ukraine), 2017 IPF World Open (Pilsen), squat world-record attempts in a single-ply suit
- 1:33 lifter info card graphic (name, class, age, profession, best squat/total). Caption: "incredible comeback after
  an incident in his 2nd attempt".
- Venue: dark hall, red carpet edging round a grey platform, big LED scoreboard on the back wall (shows UKR 440.5),
  ELEIKO plates (red 25s + green 10s + small colours), white-shirt spotters (2 sides + 1 back), judges/officials in
  WHITE SHIRT + RED TIE seated at tables at the platform's front edge; a kid volunteer in white shirt + purple tie stands
  at the stage entrance.
- 1:36-1:43 2nd attempt 440.5 kg setup: blue suit, straps up, red/black wrist wraps; hands on bar about 1.3-1.5x
  shoulder width; ducks under at 1:43.
- 1:44-1:51 standing set after a short walkout (overlay graphic: lifter name, attempts row, flag).
- 1:55-2:00 face close-up under the bar: grimace, eyes squeezed, then 2:00 head tips BACK, eyes up, big breath in.
- 2:01-2:03 standing; 2:03-2:04 descent (~1 s) to a deep bottom (equipped, hips well below knees).
- 2:04.5-2:05.3 STUCK IN THE HOLE: no upward movement; spotters already crouched with hands at the sleeves.
- 2:05.5-2:05.8 FORWARD DUMP: his chest collapses forward, hips rise, he folds over his knees; the bar rolls up toward
  his neck/head; spotters grab and wrestle the bar ends.
- 2:06-2:07 he goes down onto his KNEES and hands on the platform under/behind the bar while the 2 side spotters lower
  the bar ends to near the floor; back spotter bends over him.
- 2:07.5-2:09 kneels a moment, then gets up; 2:09-2:10 walks out from between the spotters; commentary: "we may have seen
  a little bit of injury... he's walking away just fine... got out of position there at the bottom".
- 2:11-2:18 camera pans up to the scoreboard (results table, lifter list).
- 2:19 caption "10 minutes later he comes out with 5KG MORE to take the squat world record" (445.5 kg).
- 2:19-2:23 PRE-LIFT at the side of the stage: a teammate behind him slaps the side of his neck/shoulder (2:20), then
  GRABS BOTH TRAPS from behind and shakes/kneads them (2:20.5-2:21.5) while the lifter stands with arms hanging, fists
  loose, chin down. 2:24-2:27 older coach (black shirt) stands at his left, palm on his back, talking into his ear; lifter
  stares straight ahead, no reply.
- 2:28-2:30 walks to the platform: steady medium strides, arms hanging slightly away from the body, fists half closed,
  eyes on the bar; passes the seated judges.
- 2:43-2:53 under the bar (face close-up): head DOWN looking at the floor for ~4 s (2:43-2:46), then lifts head 2:47,
  lips pressed, face going red, 2:52 cheeks puffed (holding breath).
- 2:57-3:01 walkout and set (wide). 3:02.5-3:03.5 descent ~1 s, 3:03.5-3:04 bottom (deep), 3:04-3:07 ascent ~3 s,
  slowing in the middle, chest kept up (a grinder). Spotters crouch and rise with the bar ends at hand distance.
- 3:08-3:10 after lockout: grimacing, eyes squinting, then glances to his LEFT (towards the side referee/lights).
- 3:11 lights appear while he still stands with the bar (graphic: 2 red, 1 white = no lift; commentary "didn't quite get
  dipped there"). 3:11.5-3:12 his head DROPS forward, chin to chest (head bowed under the bar); 3:12.5 looks round at
  the back spotter, mouth open saying something; 3:13.5 head drops again. 3:14-3:16 racks and walks off.
- 3:17 IPF logo wipe transition; 3:18-3:36 slow-motion replay from the side (for depth).

### A5A39IMP3gs clip 3 (3:37-4:39): super-heavy man (Canada), 2019 IPF Classic Worlds (Killeen, Texas), 400 kg squat; collapses after the miss
- Caption "Too much weight to handle for the spotters...". Commentary: "Canada's first ever raw 400 kilo squat".
- Venue: SBD and ELEIKO banners, white back wall, red plates, 2 side spotters in white tees + 1 back spotter; officials
  in white shirts behind; on-screen attempt clock.
- 3:37-3:41 face close-up under the bar: bearded, eyes down, calm. 3:42-3:51 walkout and set (stance ~1.5x shoulders).
- 3:51.5-3:52.5 descent ~1 s to a deep bottom. 3:53-3:54 starts up a few cm, then 3:54.5-3:57.8 STUCK in the hole
  ~4 s; upper back rounds, head drops; spotters crouch then grip the bar ends and lift.
- 3:58-3:59 the spotters stand the bar up and take its weight; he is semi-upright and steps FORWARD out from under the
  bar, staggering.
- 3:59.25-3:59.5 both arms come up over his head (flailing), legs giving way; 3:59.75 knees buckle; 4:00-4:00.5 he falls
  forward face-first onto the front of the platform (fainted/near-fainted; commentary "oh what the... what's happened
  there... he tried to stay with the bar", "almost convulsive").
- 4:01-4:03 spotters keep holding the loaded bar at shoulder height, staring down at him. 4:04-4:09 officials (white
  shirts) and a man in red run in and bend over him. 4:10-4:16 other angle: officials crowd round him.
- 4:17-4:27 crowd shots: seated, quiet, hands over mouths, worried faces.
- 4:28-4:35 he is back on his feet and walks off with a staff member in red at his side.
- 4:36 IPF wipe; 4:37-4:39 fast replay of the fall.

### A5A39IMP3gs clip 4 (4:40-5:12): small local meet (gym hall, bright red/yellow wall graphics), 220 kg/485 lb squat, cheating with knee wraps under sleeves
- Caption: "This guy tried to fool the judges by wearing knee wraps under his sleeves in a raw competition...".
- 4:40-4:47 lifter in black singlet squats (normal good-looking rep).
- 4:48-5:03 the CENTRAL REFEREE (suit jacket, lanyard medal) walks straight over after the lift, crouches at the lifter's
  knee and rolls down the knee sleeve to inspect it while the lifter stands still looking down; caption "But the
  central referee caught him right away in front of everybody".
- 5:04-5:09 referee walks away holding the wrap, gives a thumbs-up toward the camera; 5:10-5:12 lifter walks off.

### A5A39IMP3gs clip 5 (5:13-6:53): IPF 2021 Worlds, man (France) wearing a squat suit under his singlet + slingshot under his tee; runs away
- 5:13-5:23 the bar waits (close-up on the plates: yellow 15 + red 25s). Commentary: "he's been late out to the platform
  each time, 40 seconds on the clock".
- 5:24.5 walks in casually, LEFT hand reaches the bar first; 5:25.5-5:26.5 both hands on the bar about shoulder width
  while standing tall in front of it; 5:27-5:28 slides hands out wider; 5:30 grip set, steps in; 5:31.5 bends and ducks
  his head under the bar; 5:32.5 rises with the bar on his traps; 5:36-5:37 face looking up, eyes up.
- Spotters wear masks (Covid era), white tees.
- 5:38-5:39 walked out. 5:40-5:42 deep bottom; 5:43-5:45 slow grinding rise (face up, head tipped back, mouth open);
  5:46-5:47 lockout ("did the bar dip... he fought through it... good lift"). 5:49-5:50 racks. 5:51 overhead camera.
- 5:55 lights graphic, then bench clip: 5:56-6:04 overhead camera of the bench: wide foot plant, arch, centre hand-off
  spotter + 2 side spotters. 6:05-6:13 side close-up: presses, bar to chest and up. 6:14 racks and IMMEDIATELY sits up,
  6:15 hops off the bench and runs off the platform (caption "Running as soon as he completes the lift"); 6:16-6:18
  officials turn to look.
- 6:19-6:53 phone footage chasing him outside the venue and through corridors; caption "eventually he was disqualified
  from the competition and the federation". 6:54-7:01 end screen.

### UnUJPzEesc4 "MOST VIEWED Powerlifting Clips OF ALL TIME" (Powerlifting World, 12:09, IPF broadcast clips with commentary)
- 0:00-0:11 intro montage (0:05-0:06 a man in black singlet roaring, head back, mouth wide; IPF wipe 0:09/0:11).
- 0:12-0:16 lifter card graphic (young US man, 59 kg class, student).

#### Clip A (0:17-0:49): young 59 kg man, 2019 Worlds (Helsingborg), 3rd deadlift 265 kg, sumo, dizzy collapse (USER POINTED AT 0:33)
- Commentary: "dehydration has affected this young man", "I think that was just a little too much".
- 0:17-0:19 at the side of the stage before his call: head down, right hand brought up to his mouth/nose (0:18), long
  hair in a US-flag headband; attempt clock on the overlay shows 0:55-0:52 left.
- 0:20-0:22 walks onto the platform from the back, straight to the bar, arms hanging, steady pace.
- 0:23-0:26 steps into a WIDE SUMO stance (feet near the plates, toes out), bends, hands inside the knees.
- 0:28-0:31 close-up: bent over the bar, hair hanging, setting grip.
- 0:33-0:34 hips down, chest up, cheeks PUFFED with held breath, face red.
- 0:34.5-0:36 bar breaks the floor and creeps up to mid-shin only (slow); 0:36-0:36.25 he lets go; bar drops back
  to the floor; his head whips up/forward (hair flies).
- 0:36.5-0:38 he does NOT stand: stays crouched in a deep sumo squat behind the bar, arms dangling, swaying (dizzy).
- 0:38-0:39 two spotters walk in from the sides, bend, put hands on his shoulders/upper arms.
- 0:39.5-0:40 they hoist him up by the armpits; his legs are wobbly; 0:41 standing, a spotter keeps a hand on him.
- 0:42-0:44 walks off on his own toward the back; 0:45-0:49 backstage: scoreboard shows 3 red, coach in team shirt
  meets him.

#### Clip B (0:49-1:52): super-heavy man (USA), 2018 Worlds, squat 470 kg, slow grinder, 3 whites
- 0:50-0:50.5 behind the rack he spreads BOTH ARMS out wide and up (a "come on"/king-of-the-jungle spread, palms up)
  to the crowd; commentary "He shows who's king of the jungle".
- 0:51.5-0:52 walks round the front of the rack; 0:52.5-0:53 arms up again; 0:53.5 touches his headband.
- 0:54-0:54.5 grips the bar VERY WIDE (hands right next to the rack uprights), ducks under.
- 0:55-0:57 head bowed under the bar; 0:58-1:00 lifts his head, stares forward, serious.
- 1:01-1:03 close-up of the plates (bar loaded to the collars). 1:04-1:07 unrack + 3-4 step walkout.
- Platform: 8 spotter-loaders in white tees standing in two lines of 4 at the sides of the rack (on the platform),
  head referee at the front.
- 1:23-1:25 descent ~2 s (controlled), 1:25-1:25.5 bottom, 1:26-1:28 ascent ~3 s, slow and steady (grinder). Bar bends
  over his shoulders.
- 1:29-1:30 locked out, walks the bar forward; 1:31-1:32 racks (spotters' hands on the bar ends); 1:32.5 steps out.
- 1:33 lights 3 WHITE (graphic). He stands behind the bar, then walks off behind the spotters (no celebration on the
  platform).
- 1:39 walking off, raises his RIGHT arm forward/up once (small fist raise); 1:40-1:41 coach (bald, navy team polo)
  waits at the exit; low fist bump / hand clap; 1:41.5 walks past him. 1:42 IPF wipe; 1:43-1:52 slow-motion replay
  from behind.
- 1:53-1:55 next day/lift: walking backstage (bench). 1:56-2:03 crowd shots (seated, blue seats).

#### Clip C (2:04-2:36): same man, bench press, 3 whites
- 2:04-2:10 overhead camera: sits on the bench, lies back, slides under, grips.
- 2:11-2:13 camera behind his head: right hand reaches to the bar; spotter stands behind.
- 2:14 side: feet planted flat, wide. 2:17-2:21 front: centre spotter hands off and steps back at 2:21; lifter
  holds the bar on locked arms; head referee (bald, white shirt) stands at the side of the bench.
- 2:24-2:31 press: down 2:25-2:26, pause, press 2:27-2:29, lockout 2:30, rack 2:31; 2 side spotters follow with open
  hands under the bar ends. 2:32-2:35 crowd clapping; 2:35 3 white lights.

#### Clip D (2:37-4:00): same man, deadlift 398.5 kg world record (biggest deadlift in IPF history), CELEBRATION
- 2:37-2:48 loaders adjust and check the bar (overhead/close-ups of plates).
- 2:49-2:57 walks on from the back left, head down, arms swinging loosely, to the bar.
- 2:58-3:00.5 stands behind the bar and raises his RIGHT ARM straight overhead (fist) to the crowd, ~2.5 s; the crowd
  rises ("That place is on its feet").
- 3:01-3:02 lowers the arm, steps to the bar. 3:03-3:06 close-up: bent over the bar, looking down, breathing.
- 3:07-3:21 close on feet/hands: conventional stance (feet ~hip width), hands just outside the shins, chalked.
- 3:22-3:28 long set: bent over with hips HIGH (straight-ish legs) for ~6 s, shifting.
- 3:28.5-3:29 drops the hips fast into the start ("dip") and pulls straight away: 3:29.5 off the floor, 3:30 at the
  knees, 3:30.5 above the knees, 3:31 locked out. Whole pull ~1.5-2 s ("Whoa, that was fast").
- 3:31-3:33 holds lockout, shoulders back, waits for "down".
- 3:33.5 lowers the bar with control, hands on it all the way; 3:34 bar on the floor; he stays bent over 1 s.
- Spotters/officials at the side START CLAPPING already at 3:34 before the lights.
- 3:35-3:36.5 straightens and turns to his left; 3:37 lights 3 WHITE.
- CELEBRATION (energy 4): 3:37.5 BOTH ARMS shoot straight up overhead (V), standing still; 3:38-3:44.5 holds the arms up
  ~7 s, head tipped BACK, mouth open (roar up at the ceiling), press photographers shooting from the pit; 3:45 right arm
  still up with fist, left coming down; 3:45.5-3:46.5 turns his back to the camera and walks toward the back/side.
- 3:47 walks off with his right arm swinging/pointing forward to his coach (bald, black shirt) at the exit.
- 3:47.5-3:54 backstage (overhead cam): BEAR HUG with the coach, both arms round each other, back slaps, heads together,
  ~6 s. 3:55-3:57 crowd standing and applauding. 3:58-3:59 walks past in a team shirt.
- 4:00-4:02 hug continues; 4:03 IPF wipe; 4:04-4:18 slow-motion side replay of the pull and the arms-up celebration.

#### Clip E (4:19-5:35): US man (~74 kg class), 2019 Classic Worlds (Calgary/Canada), squat world record 275.5, 2 white 1 red
- 4:19-4:20 big name/weight graphic (name, flag, 275.5, total 607.4).
- 4:27-4:35 walks on from the back, round the rack to the front; 4:34-4:35 rubs his hands together as he walks.
- 4:36 reaches the bar with both hands at once; 4:36.5-4:39 stands in front of the bar with both hands on it, looking
  down, adjusting the grip.
- 4:40-4:47 face close-up: eyes down on the bar, calm, jaw set.
- 4:48-4:58 ducked under, head down for ~10 s; NARROW grip (hands just outside the shoulders), red wrist wraps,
  LOW-BAR position (bar below the rear delts), elbows pushed back/up.
- 4:59-5:00 unrack (stands up, head still down); 5:01-5:03 walkout ~3 steps back.
- 5:04-5:08 set and waits for the command.
- 5:09-5:10 bottom (deep, torso ~45 deg, low-bar lean), 5:10.5-5:11.5 FAST ascent (~1.5 s); "Wow, that moved fast".
- 5:12-5:12.5 walks the bar forward into the hooks; 5:13-5:14 close: still under the racked bar, head down, gritted grin;
  5:14.5 ducks out to his left.
- 5:16 lights 2 white 1 red.
- CELEBRATION (energy 4, after lights): 5:16.8 walking from behind the rack to the front-left corner; 5:17 big
  skipping STOMP: left knee driven up high, both fists yanked down/back at the hips; 5:17.3 lands leaning forward;
  5:17.5 drops into a DEEP CROUCH with both fists pulled down between his knees, mouth open (roar); 5:17.8 springs up;
  5:18 stands tall, chest out, arms at the sides, shouting; 5:18.3-5:22 walks off calmly, arms swinging, past his coach.
- 5:23 wipe; 5:24-5:31 slow-motion replay from behind.

#### Clip F (5:33-6:40): Japanese man (74 kg), same session, takes the record back with 276.0, 2 white 1 red
- 5:36-5:39 scoreboard close (name, JPN, 276.0, 01:00 clock).
- 5:40-5:44 at the bar: bends forward and ducks his head under, then rises under it; black headband.
- 5:45-5:49 face close: eyes down at the floor, then up; 5:53-5:55 close on the hands: red wrist wraps, thumbs.
  Commentary: "such a low bar setup", "he's got to watch his fingers", "He's got to stay upright to get that start
  command... They're scrutinizing" (the head referee waits until he is still and upright).
- 5:56-6:07 walked out, standing ~8 s waiting for "squat"; 6:08 command.
- 6:09-6:10 descent ~1 s, 6:11 bottom, 6:12-6:13 ascent ~2 s, 6:14 standing; 6:15 close front: waiting for "rack".
- 6:16-6:18.5 walks the bar into the rack, bent over; 6:19-6:19.5 steps out and turns away to the back.
- 6:20-6:21 walking off, right hand to his head. 6:21.5-6:22 lights board on the back wall (lights shown as colour
  dots). 6:22.5 goes down the side steps.
- CELEBRATION (energy 4-5, after lights): 6:23.5-6:24 at the side of the platform drops into a crouch; 6:24.5 both fists
  clenched up at his chin/shoulders, roaring; 6:25.5 walks past the spotters; 6:27-6:29 walks back along the front past
  the seated judges (suits); 6:29.5-6:30 walks toward the camera with mouth WIDE open shouting, fists clenched low
  and slightly out from the hips; 6:32.5 (2nd angle) crouches with fists pulled down, mouth open; 6:33 FLINGS the right
  arm up and out diagonally (open hand), left arm out, chest open, big shout; 6:34 spins away and walks off.

#### Clip G (6:40-7:27): equipped man (Indonesia), 2017 World Open (Pilsen), squat: PASSES OUT in the hole (USER POINTED AT 6:52)
- 6:40-6:48 face close-up under the bar: eyes up, breathing hard, face tense.
- 6:49-6:51 descent; 6:51-6:55 STUCK at the bottom ~4 s; spotters crouch with hands under the bar ends, then take it.
- 6:55.5 he slumps forward; 6:56 slides forward out from under the bar; 6:56.3-6:57 lies FACE DOWN on the platform
  in front of the rack, arms limp at his sides (unconscious). Spotters keep holding the bar.
- 6:57.5-6:59 spotters rack the bar; one bends over him.
- 7:00-7:09 team official (woman in red team jacket) and spotters kneel round him, cutting/unwinding his knee wraps
  (commentary: "I think he passed out... a lot of blood rush... wraps are tight... trying to get those wraps off him").
- 7:10 wipe; 7:11-7:19 front replay: bottom, spotters lift, 7:17 he tips forward. 7:20-7:25 helpers round him.

#### Clip H (7:27-8:29): man (US Virgin Islands), 2021 Classic Worlds, squat 320.5 kg world record, 3 whites, CROWD HYPE + CELEBRATION
- 7:28-7:29 lifter card (other lifter). 7:30-7:38 masked loaders tighten the collars; one points/gestures.
- ENTRANCE HYPE (energy 5): 7:39-7:40 walks out from the back and stops beside the rack; 7:41 looks to his left at the
  crowd, mouth open shouting; 7:42-7:42.5 grinning/yelling at the crowd, head turned; 7:43 swings BOTH ARMS up and out
  sideways (palms up, "come on!"), 7:43.5 arms wide at shoulder height, pumping; 7:44 arms down; 7:44.5-7:45 walks
  behind the bar pumping his arms; 7:45.5 BOTH FISTS straight up overhead; a spotter claps along; 7:46-7:47 walks round
  to the front; 7:48 reaches for the bar; 7:49 both hands on the bar, bending; 7:50-7:51 deeply bent under the bar, head
  down; 7:52-7:54 face close: head down under the bar, black headband.
- 7:55-7:59 unrack, walkout, set. 8:00-8:01 descent ~1 s, 8:02-8:03 ascent ~1.5 s (fast).
- 8:04-8:07 front close: locked out, waits for "rack"; 8:08 racked, he stands in front of the rack looking left.
- 8:08.5 lights 3 WHITE.
- CELEBRATION (energy 5, after lights): 8:09 shouts and steps forward; 8:09.5 marches straight AT the camera, both
  fists clenched and yanked down at belt height, chest pushed forward; 8:10 lunges past the camera, mouth wide (roar);
  8:12-8:14.5 (wide) walks across the platform front, calmer, arms hanging; ALL the masked loaders behind are clapping;
  8:15 a hand reaches out from the side (low five); 8:16-8:18 walks off past the camera.
- 8:19 wipe; 8:20-8:28 slow-motion side replay.

#### Clip I (8:30-10:41): US man, 2017 World Open, squat 350: PASSES OUT on the attempt (missed opener), then comes back and makes it (USER POINTED AT 9:52)
- 8:32-8:34 at the rack; 8:35-8:43 under the bar, head down, eyes closed (8:36-8:37), then lifts head. Commentary:
  "trouble with the unrack... rushed it... not finding the right position for his bar... why you need to be waiting in
  the on-deck area when that bar is loaded".
- 8:44-8:53 walked out, standing; attempt clock counting down on the overlay (0:37 to 0:33).
- 8:54-9:01 (side) walks back INTO the rack and re-racks to reset.
- 9:02-9:07 under the bar again, re-gripping, head down; 9:08-9:15 walks out again.
- 9:16-9:19 close: glances left then right (at the referees), uneasy; clock 0:10 to 0:07.
- 9:20-9:26 face: eyes down, cheeks puffed; clock hits 0:00 ("gets the squat command in time with one second to
  spare"); 9:26-9:26.5 eyes rolling up, head tipping back.
- 9:27-9:27.5 he folds; spotters grab the bar; 9:28 he is on his knees under the bar, spotters holding it at waist
  height; 9:28.5-9:29.5 sits/kneels on the platform, spotters bend over him ("massive blood rush... lost consciousness
  for a moment... the guys have caught him very well").
- 9:32-9:35 he gets up; 9:36-9:37 walks off with an official holding his arm.
- 9:38-9:42 the meet carries on (next lifter FRA 355 on the board). 9:43-9:44 wipe; 9:45-9:48 lifter card.
- COMEBACK: 9:49-9:51 walks back on calmly, passing officials; 9:52-9:53 past a spotter to the rack; 9:54-9:58 stands
  in front of the bar, hands up to it, gripping. Commentary: "huge deal to come back... You can hear the crowd" (crowd
  cheering for him though he is not their countryman).
- 10:00-10:06 under the bar, head down. 10:08-10:14 walkout and set. 10:15 face looking up.
- 10:16 descent, 10:17 bottom (deep), 10:18-10:20 slow grind up (~4 s, crowd screaming), 10:21 lockout. 10:22-10:24
  racks. 10:25 3 WHITE lights.
- REACTION (energy 3): 10:25 walks forward; 10:25.5-10:26 both fists raised to head height, elbows bent (double fist
  "yes"); 10:26.5-10:27 bends forward, hands on knees, exhausted; 10:27.5 walks off bent, hand on his stomach.
- 10:29-10:39 slow-motion replay from behind.

#### Clip J (10:41-11:23): the Ukrainian 440.5 squat dump again (same footage as A5A39IMP3gs 1:33-2:18; not re-detailed).

#### Clip K (11:24-12:03): US equipped super-heavy, 2019 Worlds (Dubai), squat 495 kg (biggest ever), 3 whites
- 11:28-11:33 standing set (red suit, white headband). 11:34-11:36 side close: face red, straining.
- 11:37 descent, 11:38 bottom, 11:39-11:41 ascent ~3 s, 11:42 standing. 11:43-11:46 crowd: dignitaries in suits
  clapping. 11:47-11:49 racks; lights 3 white.
- Walk-off (no celebration): 11:49.5-11:51.5 walks off toward the camera UNWINDING HIS WRIST WRAPS as he goes,
  suit straps still up; 11:52-11:54 bends down low at the platform edge. 11:55 wipe; 11:56-12:03 replay.
- 12:04-12:09 end screen.

### iIvTXa3Hdlo "Worst Squat Fails Ever" (Gym Fails channel, 4:52): GYM fails (phone clips, home/commercial gyms), NOT meets. Music bed, no commentary.
- 0:00-0:07 (vertical clip, home rack): chubby man in yellow tee squats, sinks and stalls at the bottom 0:00-0:04, 0:05-0:07
  he is lying flat on his back on the floor behind the bar (sat down and rolled back; bar on the safeties).
- 0:08-0:12 channel title card.
- 0:13-0:31 commercial gym, bearded man in grey tee with bands on the bar, spotter in red behind: 0:22-0:23.5 grinding up,
  folding forward; 0:24 chest collapses, bar rolls up the neck; 0:24.5-0:25.5 FORWARD DUMP: bar goes over/in front, plates
  crash to the floor front-right while he folds at the waist; 0:26 straightens and walks off; 0:27-0:31 walks toward the
  camera swearing ("god damn it... let's take it"); 0:32-0:39 spotter picks up plates; lifter stands with hands on hips.
- 0:40-1:07 joke clip: shirtless man squatting, a woman gives a "front spot" by hugging him at the bottom; cutaway
  reaction faces (0:52, 1:01, 1:07).
- 1:08-1:23 ("When you miss the rack by half an inch", vertical): heavy man in red shirt finishes his rep (1:18), walks
  the bar forward 1:19-1:19.5, 1:20-1:20.5 one end catches the hook, the other misses, the bar tilts; 1:21 bar slides off
  one side; 1:21.5-1:22 bar crashes to the floor in front; he bends over it; 1:23 crouches beside it.
- 1:24-1:36 green-shirt man with a spotter (white tee) hugging him under the armpits from behind ("come on, 230"):
  1:32-1:35 stuck at the bottom with the spotter wrapped round him; 1:35.5-1:36 BOTH collapse to the floor, spotter
  falling back onto his seat with the lifter on top.
- 1:37-2:01 (vertical): lifter squats heavy in a rack; 1:46-1:48 stuck low, folded forward; 1:49 dumps; 1:49.5-1:50 the
  bar rolls toward the phone and plates crash; 1:50.5-2:01 camera knocked over.
- 2:02-2:07 bench press clip: a lifter's head on the bench, woman walks past ("wtf just happened?").
- 2:08-2:38 green gym ("PRESS PULL"), man squats a bending bar for several reps, unremarkable; 2:35 someone walks in.
- 2:39-2:48 (USER POINTED AT 2:43; vertical, home gym): man in grey tee squats in a rack with blue/green bumpers;
  2:43-2:46 sits at the very bottom, chest tipping forward; 2:46.5 tipping forward; 2:47 DIVES forward out from under,
  the bar drops behind him onto the rack safeties, he lands on his hands; 2:47.5-2:48 lies FACE-DOWN flat on the floor,
  arms out, one shoe flown off. (Same "escape forward" as the meet faints, but deliberate.)
- 2:49-3:01 red rack with skull-emoji caption: 2:52 one side's plates slide off, the bar flips up on that end
  (see-saw), 2:53-2:55 lifter crouched under it, 2:56-2:58 stands up, 2:59-3:01 BOTH HANDS CLASPED ON TOP OF HIS HEAD
  (disbelief pose).
- 3:02-3:11 man squats facing away; 3:10 loses balance BACKWARD and falls onto his backside; 3:10.25-3:11.5 the loaded bar
  rolls across the floor toward the camera.
- 3:12-3:34 basement gym, yellow tee, belt, 225 lb: 3:24-3:28 stuck at the bottom; 3:28-3:34 sits down onto the safety
  pins and leans on them, giving up.
- 3:35-3:39 man with a pink-shirt spotter bear-hugging him from behind ("push push push").
- 3:40-3:46 woman in a CrossFit box: stuck at the bottom 3:41-3:43; 3:44-3:46 falls back onto the floor, lying on her
  back, bar rolled away.
- 3:47-3:58 big man in a singlet with red knee wraps in a red rack: 3:48.5 standing with the bar; 3:49.5 lets the bar
  slide off his back BEHIND him, plates slam down; 3:50-3:51.5 steps forward and walks away; 3:52-3:54 walks toward the
  camera, head down, RIPPING OFF HIS WRIST WRAPS (frustrated); 3:55-3:58 empty rack, bar tilted on the safeties.
- 3:59-4:07 smith machine: man with earphones squats; 4:02 falls forward out of it; 4:03 on the floor.
- 4:08-4:14 garage rack: bar comes down on the hooks/pins; he walks around (4:12-4:14).
- 4:16-4:23 ("I think I broke the squat rack", vertical): squats; 4:20 a hook gives way; 4:21 he walks off; 4:22-4:23
  bar on the floor.
- 4:24-4:28 ("Yeah I feel stupid here"): woman, unclipped plates slide off one side, the bar see-saws and flips
  vertical (4:26), she stands holding it.
- 4:29-4:41 man in a grey tee squats, 4:38.5 folds forward ("ah"). 4:42-4:52 outro card.

Coverage update: iIvTXa3Hdlo 0:00-4:15 gridded at 1 s (16 grids); 4:16-4:50 viewed at 1 s with a cropped-vertical frame
sheet (__FV, every second 4:16-4:48 + 4:50); detail passes 0:00-0:07, 0:22-0:26, 1:18-1:23, 1:32-1:38, 1:46-1:52,
2:02-2:07, 2:44-2:52, 2:50-3:01, 3:08-3:12, 3:48.5-3:54 (0.25-1 s).

### LpSFwM1m4h4 "Epic Squat Fail at IPF Worlds 2016" (0:14, IPF broadcast clip with English commentary, "@tpbotz" watermark)
- Venue: IPF Classic Worlds 2016 (Killeen, Texas look: ELEIKO/SBD banners, small tables of officials behind), red Eleiko
  plates, 2 side spotters (one in white, one in red tee) + back spotter; overlay: name, CAN flag, 150.0, attempt clock.
- 0:00-0:01 young man (CAN, red/black singlet, red wrist wraps) walks from the back of the platform round the bar end to
  the front of the rack; clock 0:48. 0:01.5 bends toward the bar; 0:02-0:03 hands on the bar, ducks under (clock 0:46).
- 0:03.5-0:10.4 close-up under the bar ~7 s: head down, bar LOW on the back (commentary "he's taking a low bar stance
  here"), grip ~1.4x shoulders, elbows up behind.
- 0:10.5-0:10.6 his head snaps up and back (face to the ceiling); 0:10.7-0:10.8 he goes over BACKWARD out of the shot.
- 0:10.9 wide: he is lying flat on his BACK on the platform behind the rack, the bar still sitting in the hooks (so he
  never got it out, or it went back into the hooks); the side spotters lunge in, one reaching for him. Commentary:
  "oh my God".
- 0:11.05-0:11.3 sits up; 0:12-0:12.75 rolls to his knees; 0:13 getting up on one knee, spotters beside him. 0:13.25 end.
- Coverage: 0:00-0:13.8 at 1 s, then 0:00-0:09.5 at 0.5 s and 0:09-0:13.8 at 0.1-0.25 s.

### FnFKPop-3IE "Heaviest bench fail ever. 1121lb fall" (1:01, phone footage from the crowd at a big equipped/multi-ply bench meet; YouTube title per player data)
- Venue: huge dark hotel ballroom, purple/pink stage lighting, crowd standing packed round a low platform; 6+ spotters/
  loaders and "STAFF" (federation logo on the back of black tees); a referee crouched at the head of the bench in a
  STAFF tee; plates red. No broadcast graphics.
- 0:00-0:03 lifter (bald, heavy, black multi-ply bench shirt) stands at the bench; the stiff shirt holds his ARMS OUT
  STRAIGHT IN FRONT at shoulder height; helpers tug at the shirt.
- 0:04-0:07 sits on the bench with his arms still sticking out forward; 0:08-0:15 lies back, wriggles into place;
  spotters close in. Someone shouts "come on Scott".
- 0:16-0:43 long setup (~25 s): lying, feet planted, helpers adjusting; 0:24 a staff member crosses in front; 0:28-0:31
  coach/handlers lean in.
- 0:40-0:48 bar handed out; 2 side spotters crouch at the plates with hands under the bar ends, centre spotter behind
  the head.
- 0:49-0:52 (USER POINTED AT 0:49) the bar is down near his chest/neck, barely moving; the left side spotter already has
  his hands round the plate end.
- 0:52.25-0:52.7 the lifter's arms shoot up and off the bar (hands open above him) while the spotters wrench the bar up.
- 0:52.8-0:53.25 the crowd lurches and the camera person backs away fast; 0:53.5-0:59.5 camera points at the hall
  (crowd standing, staff walking); 1:00 camera on the floor. The bar's final landing is NOT visible (blocked by spotters'
  bodies); what is visible is the spotters taking a bar that came down out of control.
- Coverage: 0:00-1:00 at 1 s (4 grids); 0:44-0:54 at 0.1-0.5 s (cropped close-ups), 0:52.75-1:00.4 at 0.5-1 s.

### SzX6w5mBIr4 "265lbs Bench Press Fail | Roll Of Shame" (1:26, home gym, phone on the floor beside the bench, no spotter, no talk)
- 0:00-0:03 teen in a teal tee sets the phone, walks past. 0:04 sits on the end of the bench.
- 0:05-0:23 sits ~19 s psyching up: elbows on knees, looking down, small head nods, deep breaths.
- 0:24 stands, 0:25 lies back, 0:26-0:31 grips and unracks (bar loaded with several plates, no collars).
- 0:32-0:55 PINNED: the bar sits on his chest, elbows bent and flared, ~23 s of failed pressing (bar does not move off the
  chest; small pushes, shoulders rising). (USER POINTED AT 0:54.)
- ROLL OF SHAME: 0:55.5-0:57 he pushes the bar DOWN his body, rolling it off the sternum onto his stomach; 0:57.5-0:59
  bar on the belly; 1:00-1:02 bar at the hip crease, he lets his head fall back on the bench, breathing; 1:02.5 does a
  sit-up with the bar across his hips; 1:03-1:10 sits upright with the bar in his lap / on his thighs.
- 1:11-1:19 stands, lifting the bar off his thighs, bends and puts it down on the floor in front of the bench.
- 1:20-1:23 stands rubbing his chest/stomach with one hand (sore), looks at the camera; 1:24-1:26 walks to the phone.
- Coverage: 0:00-1:26 at 1 s (6 grids); 0:53-1:03 at 0.5 s.

### gOVF6cczJls "Epic Bench press fail compilation" (Health Hub, 3:23; GYM phone clips, music, no meets)
- 0:00-0:08 channel intro + title cards.
- 0:09-0:15 man in orange tee on an incline bench, no spotter: 0:10-0:11 lies back; 0:12-0:13 sits up again (resets);
  0:14-0:15 lies back.
- 0:16-0:31 (USER POINTED AT 0:28) same man, flat bench in a power rack: unracks (0:18-0:20), lowers 0:21-0:23;
  0:24-0:27 presses partway, 0:27.5-0:29.5 the bar sinks back to his chest, elbows flared; 0:30-0:32 pinned on the chest.
- 0:32-0:46 ROLL OF SHAME, slower and more desperate: 0:33-0:35 bar rolls down to the belly; 0:35-0:36 he slides his
  body UP the bench, head off the top end; 0:36.5-0:38.5 bar at the hips, he wriggles further; 0:39-0:42 sits up behind
  the bar, the bar now on the floor side / bench end; 0:43 stands, 0:44-0:46 sits on the bench, one hand on his head,
  catching his breath, laughing.
- 0:47-1:02 (USER POINTED AT 0:54) close camera at the bar end, man in a black tee: 0:50-0:53 bar pinned at the chest;
  0:54-0:55.5 face contorted (mouth wide, teeth showing, eyes squeezed) pushing; 0:56-0:58 tilts the bar, one side
  rising; 0:58.5-0:59 one arm pushing, bar crooked; 0:59.5 sits up; 1:00-1:02 his face fills the frame, laughing/
  embarrassed, hand waving at the camera.
- 1:03-1:04 glitch transition.
- 1:05-1:15 commercial gym, two people at a bench; a spotter behind; partial reps.
- 1:16-1:35 (USER POINTED AT 1:17) young man in a maroon tee, Rogue blue plates, no collars, no spotter, in a rack:
  1:17-1:19 bar on the chest, pinned; 1:20-1:22 tries to tilt it; 1:23-1:23.5 drives his hips up into a high bridge
  (arch), 1:24-1:25 throws BOTH LEGS up in the air (knees to chest) to roll/kick out; 1:25.5-1:26 legs flailing;
  1:27-1:31 lies with his knees bent up, the bar across his hips/lap, arms flat on the bench, head turned to the side.
- 1:36-1:42 same man sits on the bench end with his head down, elbows on knees (dejected).
- 1:43-2:15 film-strip framed clip (outdoor/third-world gym, concrete floor): a man in red trousers lies under a bar
  pinned on his chest/neck; 1:46-1:48 a man in white leans over and pulls at the bar; 1:50-1:58 the helper hauls the bar
  off with both hands while the lifter stays flat; 2:06-2:15 another man in a yellow tee helps lift it off.
- 2:16-2:26 glitch; 2:18-2:26 seen from behind the bench head: lifter in blue jeans/orange top, legs flailing, bar on
  the chest, kicking.
- 2:27-2:49 incline press in a machine rack, lifter in grey tee with red wrist wraps: slow presses; 2:46-2:49 the bar
  comes down onto the face/neck; a spotter arrives.
- 2:50-3:17 crowded gym, far camera: someone on a bench in the background pinned; other gym users walk past and do not
  help (very small in frame).
- 3:18-3:23 end card.
- Coverage: 0:00-0:31 gridded at 1 s (4x4 grids); 0:32-3:23 at 1 s in cropped 6-column sheets (every second);
  detail 0:25-0:32 and 0:35-0:42 (0.5 s), 0:47-1:01 (0.5 s), 1:17-1:31 (0.5 s).

### EYoGp89tZ9o "TOP 10 Funny deadlift fails" (Power Mafia Motivation, 2:47; mostly gym clips, 2 event clips; music only)
- 0:00-0:15 intro logo animation.
- 0:16-0:28 (USER POINTED AT 0:20) young man in a black singlet, small gym/club (blue banner, yellow plates, black knee
  sleeves), conventional stance: 0:18-0:19 set; 0:20-0:22 pulls, hips rise but the BAR DOES NOT LEAVE THE FLOOR (hips shoot
  up, back rounds, knees straighten - "stripper pull" with no bar movement); 0:22.5-0:24 sets down again; 0:25-0:25.5
  tries again; same. 0:26-0:28 black cut.
- 0:29-0:49 living room, man in jeans, barbell on the carpet: 0:32-0:39 stands with the bar at lockout leaning far BACK
  (shoulders well behind hips, hips pushed forward), 0:40-0:43 locked, 0:43-0:47 lowers and drops it, bent over.
- 0:50-1:00 (USER POINTED AT 0:57) gym, man in black tank + shorts, wide conventional: 0:52 stands behind the bar, 0:53-0:54
  bends and grips; 0:55-0:56 starts the pull; 0:56.5-0:59 STRAIN FACE: mouth wide open in a grimace, teeth bared, eyes
  squeezed, head pushed up and forward, cheeks pulled back; arms straight; the bar barely leaves the floor (or does not);
  1:00 drops back down.
- 1:01-1:16 OUTDOOR head-to-head event (park, bouncy castle behind): two men in singlets (blue and red) deadlift side
  by side: 1:01-1:05 set; 1:07-1:09 pulling; 1:11-1:13 both locked out; 1:13.5-1:14 red drops his bar and walks forward;
  1:14.5-1:16 both walk toward each other (blue walks over to red, hand raised).
- 1:17-1:28 (USER POINTED AT 1:18) commercial gym, man with blue kinesio tape on the shoulders, singlet-style top, knee
  sleeves; red-shorts man watching behind with arms folded: 1:18-1:19 bar at mid-shin; 1:19.5-1:20.5 pulls past the knees,
  hitching; 1:21-1:21.5 at the hips, leaning back; 1:22 one end dips; 1:22.5-1:23 the bar tilts and slides out of one hand
  (one-handed), plates crashing; 1:23.5 he stumbles forward and falls, bar rolling; 1:24-1:28 bar on the floor; red-shorts
  man still standing with arms folded.
- 1:29 black. 1:30-1:36 (USER POINTED AT 1:31) brick-wall gym, man in a black tee ("Just Do It"): 1:30-1:34.5 bent over,
  grip set, pulling: the bar NEVER moves; 1:35 stands up empty-handed (gives up) and adjusts his belt; 1:36 walks away.
- 1:37 black. 1:38-1:48 STRONGMAN-type comp (sports hall, banner, a row of spectators/teammates in blue tees standing
  behind): man in a black tee pulls a tyre/frame deadlift by the handles; 1:38-1:43 bent over pulling, no movement;
  1:44-1:44.5 stands up; 1:45-1:47 tips his HEAD BACK, staring at the ceiling (frustration), arms hanging; 1:47.5-1:48 bends
  down to try again.
- 1:49-1:56 (USER POINTED AT 1:53) gym with a red rack, lifter in a red/black top, a man seated behind watching: 1:49-1:52
  pulls; 1:52.5-1:53 bar rising past the knees; 1:53.5-1:54 locks out and keeps going: hips drive through, his weight goes
  back onto his heels; 1:54.5 head and shoulders whip BACK, he tips over backward with the bar; 1:55 falls out of shot;
  1:55.5-1:56 black.
- 1:57 black. 1:58-2:16 gym, man in white tee + belt, sumo, blue plates: 1:58-2:11 bent, pulling, stalls at the knees;
  2:12-2:16 a helper (black hoodie) comes up behind him, wraps both arms round his waist/hips and hauls him upright.
- 2:17-2:33 gym: lifter (shirtless, belt) does reps; a coach in a black jacket stands right beside him; at every lockout
  (2:18, 2:22, 2:28, 2:32) the lifter throws his head way BACK, mouth open to the ceiling (exaggerated lean-back
  lockout); the coach holds a hand at his chin/neck.
- 2:34-2:43 outro (roaring man in blue tee, subscribe overlay); 2:44-2:47 black.
- Coverage: 0:00-2:47 gridded at 1 s in full (11 grids; 0:16-0:28 and 2:08-2:39 viewed as 4x4 sheets, all others too);
  detail 0:18-0:25.5, 0:52-1:00, 1:01-1:16.5, 1:17-1:26, 1:29-1:37, 1:38-1:49, 1:49-1:56, 2:12-2:36.

### APg5YKsYM9Y "Bench press fail" (0:36, garage gym, fixed camera, "140kg" caption; 1440x1080)
- 0:00-0:03 black title card "Bench press FAIL!".
- 0:04-0:16 man in black (tracksuit bottoms, belt, white shoes) lies on a rug-covered bench between stands, presses 140 kg;
  the bar comes down and stays on his chest from ~0:08; 0:09-0:16 pinned, pushing, no movement.
- 0:17 (USER POINTED AT 0:17) 0:17-0:18 bar on the chest, both hands on it; 0:19 he TILTS the bar: near (left) end dips
  toward the floor, far end rises; 0:19.5 near-side plates begin to slide (no collars); 0:20-0:20.5 the near plates slide
  off and crash to the floor; 0:21-0:21.5 more plates off; the bar see-saws, the far (blue) end flipping UP; 0:22-0:23 he
  lies holding a bar loaded on one side only; 0:24-0:31 lies there, then lets the bar down; 0:32 sits up; 0:33-0:35 stands
  up and walks off to the right.
- Coverage: 0:00-0:35 at 1 s (2 six-column sheets); 0:16-0:23 at 0.25-0.5 s.

Coverage update: UnUJPzEesc4 0:00-12:09 gridded at 1 s in full (46 grids; a mid-roll ad at 2:42 and another at 6:09
were skipped/played out and those grids were redone). Detail passes (0.25-1 s): 0:17-0:41, 0:49-1:00, 1:23-1:42,
2:55-3:01, 3:28.5-3:54, 4:33-4:39, 5:09-5:19.3, 6:18.5-6:34, 6:51-6:59, 7:39-7:50, 8:07.5-8:16, 9:25.5-9:29.5,
9:49-9:58, 10:16-10:28.5, 11:48.5-11:54.

Coverage update: A5A39IMP3gs 0:00-7:01 gridded at 1 s in full (27 grids). Detail passes: 0:47-1:32,
2:00-2:13 (0.25-0.5 s), 2:19-2:32, 3:02-3:14, 3:51-4:04 (0.25-0.5 s), 5:24-5:33, 5:40-5:47.

### ngP2vaQHlPg "Belt Flick Montage" (Short, 0:18, 1080x1920, one young man, several outfits/belts, gym with orange walls)
Every belt here is a LEVER belt (wide red or black band, ~10 cm tall, black steel lever plate at the front, sitting
LOW: bottom edge at the top of the shorts, i.e. below the navel to across the navel). "Belt flick" in this montage means
two things: (a) swinging the open belt round the waist to put it on, (b) popping the lever and flinging the belt OFF
the body into one hand after a set. Studied at 0.25 s throughout and 0.05-0.1 s on every belt moment.

- (a) PUT-ON FLICK, 0:00-0:95 (front camera, low): 0.00-0.10 belt open, held in the left hand at the left hip, the free
  end hanging down by the left thigh; right hand on the right hip. 0.15 the right hand reaches across low. 0.20 with a
  quick wrist flick the belt swings round the front: the red lever end swings up from the left into the right hand.
  0.25-0.30 the belt is now stretched across the lower belly, red front panel with rows of prong holes facing the camera,
  each hand holding one end at the hips. 0.40-0.70 both hands bring the two ends together at the navel. 0.80-0.90 head
  down, looking at the buckle, both hands centred, pulling tight. Whole move about 0.9 s; the swing itself ~0.1 s.
- 1.00-1.75 (side camera): belt on, both hands at the front lever, head down; 1.40 the right hand pulls the tail end
  down (it hangs off the front), a short tug; 1.6-1.7 hands still at the lever, closing it.
- 2.00-8.75 a deadlift in the same session (camera low at the plates): 2.00-3.75 set: bent over, hips high, looking
  ahead, grip; 3.75-4.25 bar off the floor and past the knees; 4.75-5.00 lockout; 5.00-8.00 HOLDS the lockout ~3 s with
  his head tipped right back looking at the ceiling, chest up, shoulders back; 8.25-8.75 drops/lowers the bar fast and
  steps back (camera shake).
- (b) TAKE-OFF FLICKS (all follow the same beat; 6 of them, cut back to back):
  1. 9.00-9.60 red belt: 9.00-9.20 right hand on the lever (fingers under its edge), left hand resting on the left
     hip; 9.30 the right hand yanks the lever outward/forward (lever pops open); 9.40 motion blur: the whole belt flies
     off the front of the body to his right; 9.50-9.60 the belt hangs open from the right hand beside the right thigh,
     swinging. Lever pop to belt-in-hand: ~0.2-0.3 s.
  2. 9.70-10.10 black belt (other outfit): 9.70 right hand gripping the lever end; 9.80 pulls it out to the right (blur);
     9.90 the arm swings out to the right holding the freed belt; 10.00-10.10 belt dangling from the right hand away
     from the body. ~0.3 s.
  3. 10.20-10.65 red belt, black tee: 10.20-10.40 right hand at the lever on the right front; 10.50 belt flips out, the
     holed panel swinging forward; 10.55-10.65 the belt rotates round off the body and hangs diagonally from the right
     hand. ~0.4 s.
  4. 10.70-11.10 red belt: 10.70-10.80 right thumb under the lever; 10.90 flicks the lever open; 11.00 the belt
     loosens and the front panel drops away from the belly (sags); 11.05 right hand pulls the end out to the right;
     11.10 belt swinging open. ~0.35 s.
  5. 11.90-12.40 black belt: 11.90-12.00 right hand on the lever; 12.10 yank (blur); 12.15-12.40 belt hangs from the
     right hand, arm held ~30 deg out from the body, red inside showing, swinging. Same again from a wide shot
     12.50-13.00 while WALKING toward the camera: 12.60 yank, 12.70-13.00 belt carried in the right hand at his side.
  6. 13.10-13.60 red belt, walking toward the camera: 13.10 right hand on the lever, left hand on the left hip; 13.20
     yank (blur) and the belt opens; 13.30 belt drooping off the front; 13.40-13.60 the belt falls below the waist and
     swings down on his right side, held by the right hand, arms swinging as he walks.
  7. 13.70-14.20 black belt: 13.70 right hand reaches to the lever; 13.80 yank; 13.90 belt opens and swings across;
     14.00 belt off, flipping down to his right hip; 14.10-14.20 belt hanging and swinging at his right side. 14.30-14.50
     a last quick one: hand on lever, 14.40 pop, 14.50 belt hanging at the right side.
- 15.00-17.70 walks back to the bar carrying lifting straps (no belt on), steps over to the bar (the loop restarts).
- ANIMATION RECIPE (take-off flick): right hand to the lever (0.1-0.2 s) -> sharp outward/forward yank of the lever
  (one frame of blur, ~0.1 s) -> belt springs open and the whole belt swings off the front of the body to the
  yanking-hand side (~0.1-0.2 s) -> belt hangs from that hand at the thigh and keeps swinging 1-2 times as he walks
  away. The OTHER hand stays relaxed on the hip or at the side. The sound would be the sharp lever pop/snap, not a
  creak (matches the project's belt-snap note).

## 2. Attempt log (meet attempts first; gym clips after)

Meet / competition attempts (broadcast or event footage):
| # | where | lift | who | attempt / weight | result | notes |
|---|-------|------|-----|------------------|--------|-------|
| 1 | A5A39IMP3gs 0:30-1:15 | squat | man, super-heavy, raw | 3rd, after 2 misses | 3 red | stall at half depth, spotters take it; bombs out; head in hands on the bar |
| 2 | A5A39IMP3gs 1:36-2:10 (= UnUJPzEesc4 10:41-11:23) | squat | man, super-heavy, single-ply | 2nd, 440.5 | miss | stuck in the hole, forward dump, falls to knees |
| 3 | A5A39IMP3gs 2:28-3:16 | squat | same man | 3rd, 445.5 (WR try) | 2 red 1 white | depth call; head drops chin-to-chest under the bar |
| 4 | A5A39IMP3gs 3:37-4:00 | squat | man, super-heavy, raw | 400 | miss | stuck ~4 s, spotters take it, he faints forward face-first |
| 5 | A5A39IMP3gs 4:40-4:47 | squat | man, local meet | 220 kg/485 lb | lift, then disqualified | referee rolls his sleeve down, finds knee wraps |
| 6 | A5A39IMP3gs 5:24-5:50 | squat | man, 2021 Worlds | ? | good (later DQ) | slow grinder; suit under singlet |
| 7 | A5A39IMP3gs 5:56-6:15 | bench | same man | ? | completed | racks and sprints off the platform |
| 8 | UnUJPzEesc4 0:20-0:36 | deadlift, sumo | man, 59 kg | 3rd, 265 | 3 red | bar to mid-shin, drops, cannot stand, spotters lift him |
| 9 | UnUJPzEesc4 0:54-1:33 | squat | man, super-heavy, raw | 470 | 3 white | very slow grinder; hype before; small fist walking off |
| 10 | UnUJPzEesc4 2:04-2:35 | bench | same man | ? | 3 white | no reaction |
| 11 | UnUJPzEesc4 2:49-3:37 | deadlift, conventional | same man | 398.5 WR | 3 white | arms-up celebration, bear hug |
| 12 | UnUJPzEesc4 4:27-5:16 | squat, low bar | man, ~74 kg | 275.5 WR | 2 white 1 red | stomp + crouch celebration |
| 13 | UnUJPzEesc4 5:40-6:22 | squat, low bar | man, 74 kg (JPN) | 276.0 WR | 2 white 1 red | crouch roar + arm fling |
| 14 | UnUJPzEesc4 6:40-6:57 | squat | man, equipped (IDN) | ? | miss | stuck, passes out, face down; wraps cut off |
| 15 | UnUJPzEesc4 7:39-8:08 | squat | man (ISV) | 320.5 WR | 3 white | crowd-hype entrance; charge-the-camera roar |
| 16 | UnUJPzEesc4 8:30-9:37 | squat | man (USA), 120+ | 350 (2nd try, after a missed opener) | miss | re-racks to reset, clock runs out, faints on his knees |
| 17 | UnUJPzEesc4 9:49-10:25 | squat | same man | 350, 3rd | 3 white | grinder; double fist then hands on knees |
| 18 | UnUJPzEesc4 11:24-11:49 | squat | man, super-heavy, equipped | 495 | 3 white | unwraps wrist wraps walking off |
| 19 | LpSFwM1m4h4 0:00-0:13 | squat | man (CAN), young | 150 | miss | goes over backward under/away from the racked bar |
| 20 | FnFKPop-3IE 0:00-1:00 | bench, multi-ply | man, super-heavy | 1121 lb (title) | miss | arms come off the bar, spotters wrestle it |
| 21 | EYoGp89tZ9o 1:01-1:16 | deadlift (outdoor event, head to head) | 2 men | ? | both lock out | drop and walk to each other |
| 22 | EYoGp89tZ9o 1:38-1:48 | strongman frame/tyre deadlift | man | ? | miss | cannot move it, head back to the ceiling |
Gym (non-meet) fail clips logged in the per-video notes: iIvTXa3Hdlo 17 squat clips, SzX6w5mBIr4 1 bench, gOVF6cczJls 8
bench, EYoGp89tZ9o 9 deadlift, APg5YKsYM9Y 1 bench (36 in all), plus 8 belt moments in ngP2vaQHlPg.
Women: only one female lifter appears (iIvTXa3Hdlo 3:40-3:46 and 4:24-4:28, gym squats); no women at meets in this batch.

## 3. Celebrations (all men; no women's celebrations in this batch)
Common thread: every big celebration here came AFTER the lights (the lifter looks at the lights board or the
commentators' graphic first), lasted 2-7 s, and happened while walking OFF, not standing at the bar. Energy is in the
legs and fists (stomps, crouches, fists yanked down) more than overhead arms, except the 398.5 deadlift.
1. UnUJPzEesc4 3:37.5-3:54, deadlift 398.5 kg world record, last lift of the meet, super-heavy man, energy 4. Bar lowered
   with control 3:33.5-3:34, he stays bent 1 s, straightens and turns to his left 3:35-3:36.5 (to see the lights).
   3:37.5 BOTH ARMS shoot straight up in a V, standing still; 3:38-3:44.5 holds them up ~7 s, head tipped back, mouth
   open (roar at the ceiling); press photographers in the pit; 3:45 left arm comes down, right fist stays up; 3:45.5-
   3:46.5 turns his back and walks off; 3:47 points/swings his right arm forward at his coach; 3:47.5-3:54 bear hug with
   the coach, both arms round each other, back slaps, heads together, ~6 s.
2. UnUJPzEesc4 5:16.8-5:22, squat 275.5 world record, ~74 kg man, energy 4: walking from behind the rack to the front
   left corner; 5:17 a big skipping STOMP, left knee driven high, both fists yanked down/back at the hips; 5:17.3 lands
   leaning forward; 5:17.5 drops into a DEEP CROUCH, both fists pulled down between the knees, mouth open roaring;
   5:17.8 springs up; 5:18 stands tall, chest out, arms at the sides, shouting; 5:18.3-5:22 walks off calmly.
3. UnUJPzEesc4 6:23.5-6:34, squat 276.0 (takes the record back 30 s later), 74 kg man, energy 4-5: 6:20 walks off with a
   hand to his head; 6:22 lights on the back-wall board; 6:23.5 drops into a crouch at the side of the platform; 6:24.5
   both fists clenched at chin height, roaring; 6:29.5-6:30 walks toward the camera, mouth WIDE open shouting, fists
   clenched low and a little out from the hips; 6:32.5 crouches again, fists down, mouth open; 6:33 FLINGS the right arm
   up and out diagonally (open hand) with the left arm out, chest open, big shout; 6:34 spins away.
4. UnUJPzEesc4 8:09-8:18, squat 320.5 world record, energy 5: 8:08.5 lights; 8:09 shouts and steps forward; 8:09.5
   marches straight AT the camera, both fists clenched and yanked down at belt height, chest pushed forward; 8:10 lunges
   past the camera, mouth wide; 8:12-8:14.5 walks across the front, calmer; all the loaders behind him clap; 8:15 a low
   five from someone at the side; 8:16-8:18 walks off.
5. UnUJPzEesc4 10:25-10:28, squat 350 (comeback after fainting on the previous attempt), energy 3: 10:25.5-10:26 both
   fists raised to head height, elbows bent (double fist "yes"); 10:26.5-10:27 bends forward, hands on knees,
   exhausted; 10:27.5 walks off bent over, a hand on his stomach.
6. UnUJPzEesc4 1:39-1:41.5, squat 470, energy 2: walking off he raises his right fist forward/up once; low fist bump /
   hand clap with his coach at the exit.
(Not counted: UnUJPzEesc4 0:05-0:06 intro clip of a man roaring, head back, mouth wide, no context.)

## 4. Before the platform, entrances and walk-ups, rituals
- Trap kneading and slaps by a teammate (A5A39IMP3gs 2:20-2:21.5): slap on the side of the neck/shoulder, then both
  hands grab the lifter's traps from behind and shake them; lifter passive, arms hanging, chin down. Then the coach
  stands at his side, palm on his back, talking into his ear (2:24-2:27); lifter stares ahead, says nothing.
- Hand to mouth/nose at the side of the stage (smelling salts style) before a 3rd deadlift (UnUJPzEesc4 0:18).
- Walk to the bar: steady, medium pace, arms hanging a little away from the body, fists half closed, eyes on the bar
  (A5A39IMP3gs 2:28-2:30; UnUJPzEesc4 2:49-2:57 head down, loose arm swing).
- Crowd hype at the rack (super-heavies and record attempts): both arms straight up overhead (A5A39IMP3gs 0:25), arms
  spread wide palms up "king of the jungle" (UnUJPzEesc4 0:50, 0:52.5), one fist straight overhead for ~2.5 s behind the
  deadlift bar while the crowd stands (UnUJPzEesc4 2:58-3:00.5), and the full version (UnUJPzEesc4 7:39-7:47): stops
  beside the rack, turns to the crowd yelling, swings both arms up and out sideways palms up ("come on"), pumps them at
  shoulder height, then both fists straight overhead; a spotter claps along.
- Rubbing the hands together walking to the bar (UnUJPzEesc4 4:34-4:35); touching the headband (0:53.5).
- Psych-up sitting on the bench end before a heavy bench, elbows on knees, head nodding, ~19 s (SzX6w5mBIr4 0:05-0:23).
- Belt: see the belt flick section (lever belts popped off with one yank; put on with a swing round the waist).
- Lifting/unwinding wrist wraps while walking off is common (UnUJPzEesc4 11:49.5; iIvTXa3Hdlo 3:52 angrily).

## 5. Going up to the bar, holding the bar, setup
- Squat: lifters walk round the bar end to the front of the rack, put both hands on the bar while still standing tall
  (often one hand first: A5A39IMP3gs 5:24.5 left hand first, then both at shoulder width 5:25.5, then slide out wider
  5:27-5:28), then bend and duck the head under (5:31.5) and rise under it (5:32.5).
- They then stay under the racked bar with the head DOWN, looking at the floor, for a long time: 4 s (A5A39IMP3gs
  2:43-2:46), 7 s (LpSFwM1m4h4 0:03.5-0:10.4), ~10 s (UnUJPzEesc4 4:48-4:58), before lifting the head, taking a big
  breath (head tips back, eyes up, cheeks puffed) and unracking.
- Grip width depends on body size and bar position: super-heavies grip almost at the collars/uprights (~1.7x shoulder
  width: A5A39IMP3gs 0:30, UnUJPzEesc4 0:54); low-bar 74 kg lifters grip just outside the shoulders with elbows driven
  up and back (UnUJPzEesc4 4:48, 5:53-5:55, "he's got to watch his fingers").
- Walkout: 3-4 short shuffling steps back (A5A39IMP3gs 0:41-0:47; UnUJPzEesc4 1:04-1:07, 5:01-5:03). Super-heavies
  take a very wide stance, toes out 30-40 deg.
- Waiting for "squat": standing set 5-10 s; the head referee waits until the lifter is still and upright
  (UnUJPzEesc4 6:01 "they're scrutinizing"; 5:56-6:08 ~8 s). A lifter who is uncomfortable walks the bar back into the
  rack and re-grips while the 60-s clock runs (UnUJPzEesc4 8:54-9:15).
- Bench (meet): sits, lies back, slides under, grips, feet flat and wide; a centre spotter hands off and steps back;
  the head referee stands at the side of the bench (UnUJPzEesc4 2:04-2:21). Equipped bench shirts hold the arms out
  straight in front even when standing and sitting (FnFKPop-3IE 0:00-0:07).
- Deadlift: walks to the bar, stands behind it for a moment (hype: 2:58), steps in, bends with HIPS HIGH for a long set
  (~6 s, UnUJPzEesc4 3:22-3:28), then a fast hip drop ("dip") and pulls straight away (3:28.5-3:29). Sumo: feet near the
  plates, toes out, hands inside the knees (UnUJPzEesc4 0:23-0:26).

## 6. The lift itself
- Squat tempo at meets: descent ~1 s (raw and equipped), easy ascent ~1.5 s (UnUJPzEesc4 5:10.5-5:11.5, 8:02-8:03),
  grinder ascent 3-4 s (A5A39IMP3gs 3:04-3:07; UnUJPzEesc4 1:26-1:28, 10:18-10:20). Super-heavy 470: controlled 2 s
  descent and 3 s ascent with the bar visibly bending.
- A grinder looks like: speed dies in the middle, hips stay back, chest held up, face up, mouth open, cheeks puffed,
  crowd screaming (UnUJPzEesc4 10:18).
- Deadlift WR pull: off the floor 3:29.5, knees 3:30, above knees 3:30.5, locked 3:31 (~1.5 s), holds 2 s for "down",
  lowers WITH control, hands on the bar all the way (3:33.5-3:34).
- Bench: down ~1 s, pause on the chest, press ~2-3 s, lockout, rack (UnUJPzEesc4 2:25-2:31). 2 side spotters follow
  the bar ends with open hands, not touching.
- After the squat lockout: walk the bar forward into the hooks bent over (UnUJPzEesc4 6:16-6:18.5), often stay under
  the racked bar a moment with the head down (5:13-5:14) before ducking out to one side.

## 7. Completing, the lights, misses and reactions to a miss (MOST DETAIL)
Lights: lifters look to their LEFT/RIGHT toward the side referee or the board as soon as they rack (A5A39IMP3gs 3:08-3:10
glances left; UnUJPzEesc4 3:35-3:36.5 turns left after the deadlift; 6:21.5 looks at the back-wall board). On the
broadcast the lights are 3 small dots at the bottom right (white/red). Staff and spotters sometimes clap BEFORE the
lights (UnUJPzEesc4 3:34).

How a squat miss unfolds (5 meet examples):
- STALL MID-WAY (A5A39IMP3gs 1:04-1:15): drives up to ~half depth and stops; hips shoot back, torso tips to ~45 deg,
  knees stay out; grinds ~2.5 s; the side spotters (already squatting with him, forearms under the sleeves) wrap their
  arms round the bar ends and lift; the lifter rises with them, head down, and walks the bar into the hooks.
- STUCK IN THE HOLE -> FORWARD DUMP (A5A39IMP3gs 2:04.5-2:10): no upward movement for ~0.8 s; chest collapses forward,
  hips rise, he folds over his knees, the bar rolls up the neck; spotters wrestle the ends; he goes down onto his KNEES
  and hands under/behind the bar while the spotters lower it to the platform; kneels a moment, gets up, walks out
  between the spotters.
- STUCK -> SPOTTERS TAKE IT -> FAINT (A5A39IMP3gs 3:54.5-4:00.5; UnUJPzEesc4 6:51-6:57, 9:26-9:29.5): stuck 3-4 s, eyes
  roll up / head tips back, spotters take the bar; the lifter steps or slides FORWARD out from under it, arms flail up
  (3:59.25), knees buckle, and he falls face-first, lying limp face down; spotters keep holding the loaded bar;
  officials/team run in and kneel; they cut the knee wraps (UnUJPzEesc4 7:00-7:09). Or he simply folds onto his knees
  under the bar with spotters holding it at waist height (9:27-9:29.5) and is walked off holding an official's arm.
- GOES OVER BACKWARD (LpSFwM1m4h4 0:10.5-0:13): under the racked bar, head snaps up and back, he falls backward and
  lands flat on his back behind the rack; the bar stays in the hooks; spotters lunge in; he sits up, rolls to his knees,
  stands.
- NO LIFT ON DEPTH (A5A39IMP3gs 3:11-3:14): stands with the bar while 2 red appear; his head DROPS forward chin to chest
  under the bar; looks round at the back spotter and says something; head drops again; racks.

Reactions after a miss:
- Head in hands folded over the racked bar, forearms on the bar, ~3 s (A5A39IMP3gs 1:19-1:22), then a hand over the
  mouth, straightens, walks off. Coach backstage puts a palm on his cheek (1:30-1:32).
- Head back staring at the ceiling, arms hanging (EYoGp89tZ9o 1:45-1:47).
- Both hands clasped on top of the head (iIvTXa3Hdlo 2:59-3:01).
- Sitting on the bench end, head down, elbows on knees (gOVF6cczJls 1:36-1:42); hand on head catching breath and
  laughing (0:44-0:46); embarrassed laugh into the camera (1:00-1:02).
- Swearing, walking away, hands on hips while someone else picks up plates (iIvTXa3Hdlo 0:27-0:39).
- Angry: ripping the wrist wraps off while walking away after dumping the bar behind (iIvTXa3Hdlo 3:49.5-3:54).
- The 59 kg deadlifter (UnUJPzEesc4 0:36.5-0:41) cannot stand after letting go: stays crouched in his sumo stance
  swaying; two spotters lift him by the armpits.
- Most broadcast misses get NO big emotion: the lifter walks off quietly, head down.

Deadlift misses: bar does not leave the floor at all (hips shoot up, back rounds, then set down again: EYoGp89tZ9o
0:20-0:25, 1:30-1:35 gives up and stands empty-handed); strain face = mouth wide, teeth bared, eyes squeezed, head
pushed up (0:56.5-0:59); bar reaches mid-shin then is dropped (UnUJPzEesc4 0:34.5-0:36); grip loss on one side at the
hips, bar tilts and slides out, lifter stumbles (EYoGp89tZ9o 1:22-1:23.5); over-pull: hips drive through and he tips
over backward with the bar (1:53.5-1:55).
Bench misses: pinned on the chest for many seconds (10-25 s alone in a gym); escapes: ROLL OF SHAME (push the bar down
the stomach to the hips, sit up with it in the lap: SzX6w5mBIr4 0:55.5-1:10; gOVF6cczJls 0:33-0:43), TILT AND DUMP the
plates off one unclipped side so the bar see-saws (APg5YKsYM9Y 0:19-0:22), legs thrown up in the air to kick out
(gOVF6cczJls 1:23-1:26); at a meet the spotters take the bar and the lifter's arms come off it (FnFKPop-3IE 0:52.25).

## 8. Going back / walk-off / coach and team
- Walk-off after a good lift is usually calm: arms swinging, past the coach at the exit with a low fist bump
  (UnUJPzEesc4 1:40-1:41). Big records end in a bear hug backstage (3:47.5-3:54).
- Walk off unwinding wrist wraps (11:49.5-11:51.5), suit straps still up; bends down low at the platform edge.
- After a faint the lifter is walked off by an official holding his arm (UnUJPzEesc4 9:36-9:37; A5A39IMP3gs 4:28-4:35).
- Loaders swarm the rack to strip the bar as soon as he steps away (A5A39IMP3gs 1:24-1:29).

## 9. The meet
- IPF Worlds platforms: upright squat rack with hooks, red 25 kg Eleiko plates loaded to the collars for super-heavies;
  3 spotter-loaders in white tees and black shorts (one at each bar end, one behind); for the heaviest squats EIGHT
  spotters in two lines of four (UnUJPzEesc4 1:04-1:07); 2017 era judges in white shirts + red ties at tables at the
  platform front; head referee in a white shirt (or suit jacket at small meets) standing at the side for bench.
- Spotters in masks in the 2021 footage. They crouch in sync with every squat, hands open under the sleeves, and only
  touch on a miss.
- Broadcast graphics: lifter name/flag/weight lower-third, attempt row, 60-s attempt clock, 3 light dots, lifter info
  cards (category, years competing, job, bests), IPF logo wipe between clips, slow-motion replays from the side or
  behind after every notable lift.
- Lights board also on the back wall (6:21.5) and a big scoreboard/results table (A5A39IMP3gs 2:11-2:18).
- Crowd: stands for super-heavy and record attempts, many filming with phones; quiet, hands over mouths after a
  collapse (A5A39IMP3gs 4:17-4:27); cheers a foreign lifter coming back from a faint (UnUJPzEesc4 9:51-10:20).
- Big US equipped bench meets (FnFKPop-3IE): hotel ballroom, purple/pink lights, crowd standing packed around a low
  platform, 6+ staff spotters in black "STAFF" tees.
- Small local meet (A5A39IMP3gs 4:40): gym hall with bright red/yellow wall graphics, referee in a suit with a medal
  lanyard.

## 10. What surprised me / what a game would most likely get wrong
1. Misses are not one animation: at least five distinct squat misses (mid-way stall, stuck-in-hole forward dump, faint
   after the spotters take it, backward fall, depth no-lift) with very different bodies and spotter actions
   (A5A39IMP3gs 1:04, 2:05, 3:58; LpSFwM1m4h4 0:10.5; A5A39IMP3gs 3:11).
2. Spotters move WITH every squat (crouching in sync, hands open under the sleeves) and on a miss they hug the bar ends
   and stand the bar up; the lifter rises with them. A game where spotters stand still until a miss looks wrong.
3. Fainting lifters fall FORWARD out from under the bar, not straight down; the spotters keep holding the bar
   (A5A39IMP3gs 3:59-4:03; UnUJPzEesc4 6:56).
4. Celebrations wait for the lights and happen while walking off, low and leg-driven (stomp, deep crouch with fists
   pulled down, charge at the camera) rather than standing at the bar with arms up (UnUJPzEesc4 5:17, 6:23, 8:09).
5. Super-heavies grip the squat bar almost at the collars; 74 kg low-bar lifters grip just outside the shoulders
   (A5A39IMP3gs 0:30 vs UnUJPzEesc4 4:48). Grip width should scale with build.
6. Long stillness under the bar before the unrack (4-10 s, head down) and before the deadlift pull (~6 s hips-high set)
   is normal; a game would rush it.
7. The pre-lift crowd hype (arms out palms-up "come on", fist overhead) is done standing BESIDE the rack or behind the
   deadlift bar, before touching the bar (UnUJPzEesc4 0:50, 2:58, 7:43).
8. Most misses get no drama: head drops, walk off quietly. The big reactions (head in hands on the bar) are rare and
   come at elimination (third miss) (A5A39IMP3gs 1:19).
9. The belt flick is a one-hand lever pop that throws the belt off the body into the same hand in ~0.3 s, and the belt
   then dangles and swings from that hand as he walks (ngP2vaQHlPg 9.30-9.60, 13.20-13.60). Lever belts sit LOW (top
   of the shorts to the navel).
10. On a re-rack or a failed setup the lifter walks the bar back in and re-grips with the clock running; the head
   referee only gives "squat" when he is still (UnUJPzEesc4 8:54-9:26).
