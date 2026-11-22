# Unboxing study, batch B8

## 1. Videos and coverage log

- Video: JRClaaYZXJc "ALL PET CUTSCENES! (1/1M TO 1/100B) | PETS GO!" by PsychoRages, 36:35 (2195.4 s), uploaded Dec 30, 2024.
- My range: 18:20 (1100 s) to the end (36:35).
- No captions/transcript on this video (`__captions` found no transcript button). So any voice in the sound data
  cannot be checked against captions; judged from the sound shape only.
- YouTuber's chapters (from the description): 0:00 1/1M-1/10M; 3:19 1/10M-1/50M (Egg Cutscene); 5:40 1/50M-1/100M;
  9:12 1/100M-1/1B (Huge Egg Cutscene); 19:20 1/1B-1/5B (Actual Huge Egg Cutscenes); 32:37 1/5B-1/10B;
  34:52 1/100B (Titanic). Description says it is every rare pet rolled on camera, ending with the Titanic Reindeer Cat.

Coverage log (the final exact coverage is at the end of this file, "Coverage summary (final)"):
- SOUND: recorded the whole range 18:18-36:35 with `__audioRun` at 2x in 5 chunks (18:18-22:20, 22:18-26:20,
  26:18-30:20, 30:18-34:20, 34:18-36:35); every chunk returned note "ok" (peak RMS 0.70-0.74); checked: every whole
  second 18:20-36:35 has audio data (no gaps). After the last chunk YouTube autoplayed the next video; I saved the
  measured series in the page's localStorage first, reloaded my video and re-ran setup.js with the sound helpers
  reading the saved series, so all sound numbers below come from that one recording.
- Browser limit: the pane is hidden, so screenshots are ~800 px wide (zoom is "not magnified"); 4-column grid tiles
  are ~165 px wide. Small text (pet names) was read from 1- or 2-column `__frames` where needed. Screenshots of the
  background tab sometimes timed out; every failed grid was re-run until it was seen.
- (Note for the caller: my shell appends went to a sandboxed copy, so this file was rebuilt with the editor at the
  end; content is the same as written during the session.)

### Working structure log from the 1 s grids (times = video time; "clip" = one creator's recording the YouTuber cut in)
- 18:20-19:20 (chapter 1/100M-1/1B "Huge Egg Cutscene", started in B7): repeated ~11-13 s clips of the SAME generic
  egg cutscene: black ~1.5 s -> black/blue "?" egg in the default room (green checker floor, purple sky with white
  diagonal light stripes) ~4 s -> white screen ~3 s -> game world 1 s -> reveal card "1 in 800,000,000" etc. ~3-5 s
  -> often a normal hatched pet "1 in 7"/"1 in 3" for 1 s -> black. The clip running at 18:20 (multi-pet result screen
  18:20-18:21, then pink bunny 18:22) was started in B7.
  Reveals seen: 18:33-18:36 "1 in 800,000,000" (orange fluffy pet, pink/gold glow); 18:48-18:52 "1 in 800,000,000"
  (yellow cat with corn stalks); 19:04 "1 in 850,000,000" (grey/pink pet in pink cloud); 19:16-19:21
  "1 in 999,000,000" (red/white candy-cane pet with red/white rays).
- 19:20+ (chapter 1/1B-1/5B "Actual Huge Egg Cutscenes"): longer and THEMED cutscenes:
  - 19:24-19:44 lavender/snow room egg, sparkles, gold rays, white 5 s -> "1 in 1,000,000,000" white angel pet with
    gold stars.
  - 19:45-20:18 (vertical phone clip, WuxingGaming) CHRISTMAS template: egg -> turns into a green present with red
    ribbon -> presents pile up -> white -> snowy gingerbread village, red/green striped ornament egg -> white -> reveal.
  - 20:19-20:40 (qSkull) generic egg, pale sky -> "1 in 1,000,000,000" brown dog; 20:40 normal "1 in 5" pet.
  - 20:41-21:02 generic egg, camera/egg recedes, white burst with blue shards -> "1 in 1,000,000,000" white husky.
  - 21:03-21:31 (RussoPlays, facecam) generic egg -> "1 in 1,000,000,000" blue cat, orange confetti.
  - 21:38-22:00 (Thomas Baker) generic egg with green-yellow aura and rays -> "1 in 1,000,000,000" calico cat.
  - 22:01-22:20 (vertical, Elkami) egg far away -> big white/blue candy pet -> white.
  - 22:21-22:23 normal 3-egg hatch: three pets pop out with black smoke puffs, each with its own "1 in ..." label.
  - 22:24-23:05 HALLOWEEN template: generic egg -> purple graveyard, a tombstone types "RIP <player name>" letter
    by letter, bats, jack-o-lanterns, skeleton hands from the ground -> extreme close-up of a ghost-mask face ->
    ghost-mask pet with knife -> white -> 3-pet reveal "1 in 400m / 1 in 1.2b / 1 in 90m".
  - 23:08-23:39 VALENTINE template: generic egg -> pink hearts, screen washes pink -> pink candy land with rainbow,
    stars, pink trees, heart-spotted egg -> white -> "1 in 1,250,000,000" shiba with pink hearts.
  - 23:40-23:58 DRAGON CASTLE template: generic egg -> white smoke puff -> castle courtyard -> egg blackens with
    glowing orange cracks and flames -> green dragon hatches, wings spread -> white.
  - 24:00-24:23 BLOOD FOREST template: generic egg -> black -> red fog forest of dead trees, black egg covered in
    red-iris eyeballs -> egg glows white -> "1 in 1,500,000,000" black/white demon wolf, black smoke.
  - 24:24-24:55 TREASURE/JELLY template: generic egg -> golden treasure chest -> swarm of jelly pets fills screen ->
    rainbow-striped egg on a green hill -> white -> "1 in 1,500,000,000" blue fluffy pet on a yellow burst.
  - 24:56-25:31 CHRISTMAS template again (horizontal) -> 8-pet multi-hatch result with confetti.
  - 25:32-26:03 HELL/LAVA template: generic egg -> ember -> black with drifting orange embers -> glowing orange
    eyes in the dark -> red glow -> red-orange lava arena with jagged rocks, flaming egg -> shockwave dome -> white
    -> "1 in 1,800,000,000" Huge Inferno Cat.
  - 26:04-26:19 (NightFoxx) generic egg -> "1 in 2,000,000,000" dark reindeer.
  - 26:20-26:45 THANKSGIVING template: generic egg -> pilgrim hat appears, turkeys swarm in, a turkey flies into
    the lens (orange screen), extreme close-ups of hat buckle and face -> turkey pumpkin pet with rays -> white ->
    multi-hatch result.
  - 26:46-27:26 (ThatOneRobloxian) "Buy item" gift dialog -> confetti egg -> CHRISTMAS template -> "1 in
    2,000,000,000" red cube pet; 27:25-26 normal "1 in 3" fox.
  - 27:27-27:55 (Brandhimo) TREASURE/JELLY template -> "1 in 2,000,000,000" purple pet.
  - 27:55-28:34 (FroggyHops, streamer captions burned in) CHRISTMAS template -> red burst reveal, "LETS GOOOO!".
  - 28:35-29:08 generic egg -> egg frosts over -> snowy village, snowman pet with hat and scarf ->
    "1 in 2,000,000,000" ice yeti with flame hair.
  - 29:09 title card "Huge Abyssal Jellyfish"; 29:10-29:34 UNDERWATER template: all-cyan underwater room,
    water ring, egg dissolves into bubbles -> white -> "1 in 2,000,000,000" glowing blue jellyfish cube.
  - 29:35-30:04 (Thomas Baker) generic egg -> frosts -> snowy hill with snowman -> "1 in 2,500,000,000" blue cat.
  - 30:05-30:38 (Thomas Baker) 6 s black -> generic egg -> LIGHTNING strikes the egg -> white castle appears ->
    red castle interior, egg turns black with flame -> explosion -> red dragon -> shockwave -> white ->
    "1 in 2,500,000,000" red dragon cat.
  - 30:39-31:16 (vertical, LimitedRBLX) CHRISTMAS template: presents pile, white, red/gold ornament egg in the snow
    village, white -> "1 in 2,500,000,000" red/yellow/green elf-like pet (31:12-31:15); 31:16 normal pink bunny.
  - 31:17-31:45 generic egg -> frost -> snowman cutscene with fire torches round the snowman -> "1 in 2,500,000,000"
    green grinch-like cat in a santa hat.
  - 31:46-32:17 (RyanBlox) hatch-menu popup, multi-egg result -> generic egg -> frost -> DISCO template: rainbow
    light-up dance floor, wall speakers, spiky dark pet in pink LED shades, pink light burst -> white -> multi-pet
    result with rainbow streaks; 32:17 normal "1 in 3" fox.
  - 32:18-32:38 (hhfhggrs8) UNDERWATER template -> "1 in 3,000,000,000" on a black/purple card; 32:38 normal "1 in 5".
  - 32:39-33:49 (Tek; chapter 1/5B-1/10B from 32:37) SPACE template, ~70 s (details below).
  - 33:50-34:52 TEMPLE template, ~60 s (details below).
  - 34:53-36:28 (ZOMG, chapter 1/100B Titanic from 34:52): normal mass hatch -> streamer caption "Wow! Another
    huge?" -> generic egg -> CHRISTMAS presents -> Santa sleigh story -> reindeer-antler egg -> mass-hatch grid ->
    cards "1 in 10k" + "1 in 100b" (details below).
  - 36:28.5-36:35 the YouTuber's own outro (his avatar with golden wings, like/subscribe text). NOT a server message.
- PICTURES, 1 s grids: COMPLETE for 18:20-36:35 (69 grids at 1100, 1116, ... 2188). A mid-roll ad interrupted one grid
  at 34:00-34:03; I cleared it (`__clearAd`) and re-ran that grid, so those seconds are seen from the video itself.

## 2. Cutscene log
(the one-line table is in section "2b" further down: written after all detail passes)

## 3. Cutscenes in detail

### General facts about this video (apply to every cutscene below)
- It is a compilation: the YouTuber (PsychoRages) cut together clips from many players/streamers ("Credits: X"
  label top-left from ~19:45). The cutscenes themselves are the GAME'S OWN footage (Pets Go, Roblox); the YouTuber's
  editing is only: hard cuts between clips, the credit label, and short black gaps. Some clips carry the streamer's
  own burned-in captions ("WOW! I've never gotten this cutscene before", "LETS GOOOO!", "No way...") and facecams.
- SOUND: every clip boundary shows a SILENCE/DROP to about -60..-120 dB, then the next clip starts. So the
  YouTuber did NOT lay music over the video; what is measured inside a clip is the game's sound plus, in some clips,
  the streamer's voice. There are no captions to check voices. The game's cutscene audio is very bass-heavy: the SUB
  band (<150 Hz) sits around -6..-12 dB, about as loud as the whole mix, for most of every cutscene. Stretches of
  exact -120 dB (digital silence) inside a clip are edits/mutes by the recorder or YouTuber, not game sound.
- Pets Go is a ROLL game ("Auto Roll!" button bottom-left of the HUD): the player rolls/hatches constantly; a rare
  roll interrupts with a cutscene, then the result card.
- The reveal card is the same for every rarity (see 25:58 below): full-screen close-up of the pet, huge white
  rounded bold "1 in 1,800,000,000" with a dark outline at the bottom centre, the pet's name in smaller white text
  under it ("Huge Inferno Cat"), radial speed-line burst behind the pet in the pet's own colours, HUD still visible
  (currencies left, "Auto Roll!" bottom-left, a "People / Best Roll" leaderboard top-right). It holds ~3-4 s.

### NORMAL hatch (what a non-rare roll looks like), best seen 34:53.0-34:56.5 (ZOMG clip) and many 1 s moments
- 34:53.0 the player stands in the snowy world with his pets; 34:53.6 a lucky-dice icon on screen; 34:54.0 a GRID of
  ~32 white/pale-blue eggs (8 x 4) pops up over the world (semi-transparent, the world still visible behind);
  34:54.4 (~0.4 s later) every egg is replaced by its pet (reindeer, yellow chicks, white bears, grey cats) with a
  small "1 in 3" / "1 in 5" / "1 in 10k" label under each; pets wiggle; 34:56.5 the grid is gone, back to the world.
  Total ~2.5 s, no camera change, no flash. Sound: a short HIT +26 dB at 34:53.0, otherwise the mix stays ~-21 dB.
- Single normal hatch (18:37, 18:53, 19:05, 20:40, 21:38, 23:05, 24:23, 27:25, 30:04, 31:16, 32:17, 32:38, 33:49):
  one pet appears in the middle of the world view, ~1 s, small white "1 in 7"/"1 in 3"/"1 in 5" label under it;
  sometimes 3 in a row (22:21-22:23: three pets pop out together, each in a puff of black smoke, each labelled).
  This is all the excitement a common roll gets: 1-2 s, no scene change.
- Mid-tier (23:01-23:04, 32:13-32:16): several special pets in a row with odds like "1 in 400m" share one card.

### C-LAVA: 25:31-26:01.3 "Huge Inferno Cat", 1 in 1,800,000,000 (game footage; clip with no credit label)
Length: black 25:31.0 -> card ends 26:01.3 = ~30 s (cutscene proper 25:33.0-25:52.3 = 19.3 s, white 4.5 s, card 3.3 s).
Pictures: 0.25 s frames through 25:31.0-26:02.8, single big frames at 25:59.5 and 26:00.1. Sound: 0.5 s table.
Beats:
- 25:31.0-25:32.8 black (clip gap; sound DROP -18 dB at 25:31.7, SILENCE 25:32.4).
- 25:33.0 fade up from black on the DEFAULT EGG ROOM: green checker floor stretching to the horizon, pale sky,
  first frame is dark grey with a tiny black egg dot high in frame -> 25:33.3-25:33.5 room brightens, no egg ->
  25:33.8 the black/blue "?" egg is suddenly big in the centre (it DROPS in from above and lands; next frames it
  settles slightly smaller = squash/bounce). Sound: HIT +30 dB and BOOM +69 dB bass at 25:33.5-25:33.6 = the landing
  thump (mix jumps from -63 to -15 in 0.5 s).
- 25:34.8 egg flashes white (white silhouette + glow) for ~0.2 s; 25:35.0 rainbow rim glow and white 4-point
  sparkle stars around it; 25:36.5 a big PULSE (egg scales up ~10%, yellow-white glow behind); 25:36.8 sparkle burst;
  pulses about every 1.5 s. 25:37.0 a small orange spark appears beside the egg, 25:37.8 a white electric arc
  crackles round it, 25:38.0 a small FIREBALL flies in at the upper right = foreshadowing of the theme.
- 25:38.3 HARD CUT to black. 25:38.3-25:47.0 (8.7 s) BLACK VOID with dozens of orange-red EMBERS drifting
  upward and faint dark-red smoke columns. Glowing orange slit-pupil CAT EYES open in the dark three times in
  different places: 25:40.5 faint in the centre (gone by 25:41.0), 25:42.5-25:42.8 right of centre, 25:44.5-25:45.0
  centre-top then left (with a hint of white fangs/whiskers), fading at 25:45.3 = something unseen circling you.
  Sound: steady deep rumble: SUB -7..-9 dB, LOW -17..-20, MID and HIGH sink to -35..-44 (dark, no sparkle).
  No hits at the eye blinks (silent "peek" moments in a drone).
- 25:46.8-25:47.3 red glow rises from the bottom and floods the frame (fade to deep red).
- 25:47.5 HARD CUT to the LAVA ARENA: floor of orange/red checker tiles like molten lava, ring of jagged dark-red
  rock spikes with glowing orange crack lines all around, red sky. The egg is now a LAVA EGG (red-orange with
  yellow flame pattern), large, centred, camera close and slightly low, egg bobbing. Sound at the cut: MID/HIGH
  jump to -20/-19 for 0.5 s (a bright whoosh) then the rumble returns.
- 25:49.3 a white LIGHTNING bolt strikes the egg from above; 25:49.5-25:50.8 a STORM of yellow/orange sparks and
  flame tongues bursts round the egg (frame very busy). Sound gets brightest: HIGH -18 -> -11 dB, MID -15 by 25:50.5.
- 25:51.0 a pink-magenta SHOCKWAVE DOME (half-sphere outline) expands round the egg, egg turns white-hot;
  25:51.8 white star burst with long rays; 25:52.3 FULL WHITE screen. BOOM +11 dB at 25:52.4 on the white.
- 25:52.3-25:56.8 white (4.5 s). Sound decays smoothly -9 -> -36 dB over 25:52.5-25:55.0, then digital silence
  (-120 dB) at 25:56.0 for ~0.5 s: very likely the YouTuber's cut that shortened the white.
- 25:56.8-25:57.8 white fades into the game world (HUD fades in, a gift prop beside the player).
- 25:58.0 REVEAL CARD snaps in: extreme close-up of the pet (red/orange flaming cat face, yellow eyes) filling the
  screen, 25:58.3-25:58.5 the frame is mostly a red flash (pet scaling in), 25:58.8 settled. Text: "1 in
  1,800,000,000" + "Huge Inferno Cat". Background = radial speed lines in red/orange/yellow; at 26:00.0 the burst
  colours shift to purple/blue/white (rotating rainbow burst). Sound: BOOM +51 dB bass (SUB -9) and HIT at
  25:58.1-.3 = the reveal slam; then the card sits quiet (-38..-48 dB) from 25:59.5.
- 26:01.5 cut to the next clip (a "Redeem Merch!" code popup in another player's game).
VFX amount: 3 in the void (embers only, clean), 5 at 25:49.5-25:52 (lightning + spark storm + dome; the egg is hard
to see for ~1.5 s, CLUTTERED but short). Leaves the world: yes (void, then a lava arena). Player avatar: NO, never.
Camera: static, centred, slightly low; all movement is the egg's own drop/bob/pulse and hard cuts. No orbit.
What makes it work: three acts (normal egg -> dark void with eyes -> lava arena explosion); the 8.7 s of dark
with eyes is the scariest, most "serious" part and costs almost nothing (black + embers + two glowing eyes).

### C-TITANIC: 34:57.0-36:28.3 "Titanic Reindeer Cat", 1 in 100,000,000,000 (+ "Reindeer Corgi" 1 in 10k) (ZOMG clip)
Length: 34:57.0 (black, clip start) -> 36:28.3 (end of card) = 91 s. Cutscene proper from the egg drop 35:03.5 to
the white at 36:12.3 = 69 s, then white 36:12.3-36:17.0, result grid 36:18-36:24, cards 36:25-36:28.
Pictures: 1 s grid all through; 0.5 s frames 34:52-35:26.5 and 35:27-36:22.5; 0.25 s frames 36:07.0-36:14.75; big
frames at 34:53.6, 34:54.0, 34:54.4, 34:55.2, 35:25.5, 35:27.5, 35:31.5, 35:33.5, 36:20.0, 36:24.5, 36:25.5, 36:27.0.
Sound: 1 s table + events.
Beats:
- 34:57.0-35:03.0 black with the streamer's caption "Wow! Another huge?" (35:00-35:03).
- 35:03.5 dark grey fade-in, the egg is a small dot high up; 35:04.5 it has DROPPED and landed big in the default
  room (same opening as every rare roll). 35:05.0-35:05.5 a yellow glow pulse; 35:07.0 a white smoke RING puffs out
  at the egg's base ("poof"); 35:08.5 the egg is now a big green PRESENT with red/gold ribbon, sparkles round it.
- 35:09.0-35:18.5 more presents DROP IN one by one around it (red polka-dot box right 35:09.0, red box left 35:10.0,
  yellow box 35:10.5, then a green sack, more boxes) until the room is a heap of gifts; the camera slowly pushes in.
  Streamer caption "This the huge animation right?!" (35:15-35:21). Sound: a bass thump with each early drop (BOOM
  35:07.1, 35:08.5, HIT 35:11.0, 35:11.6), bed ~-20 dB, SUB-led, HIGH low (-46..-53). 35:18.0 sound brightens
  (MID -28, HIGH -25) as the heap starts to glow.
- 35:18.5-35:21.0 the heap dissolves into white from the centre outward; 35:21-35:24.0 white (sound fades to -43).
- (From here on is what ONLY the Titanic gets.) 35:24.5 fade from white: NIGHT SKY with stars, a medium close-up
  from the side of a red-and-black sleigh with gold trim and gifts, driven by a big white blocky cat with a blue nose
  and yellow glasses; slow push-in 35:24.5-35:28.5. Caption "Wait it's not...". BOOM+HIT at 35:24.5/35:25.0.
- 35:29.0-35:30.5 white flash transition (~1.5 s dissolve).
- 35:30.5-35:34.5 side TRACKING shot along the REINDEER team: blocky black/grey reindeer with gold antlers and
  gold-wrapped harness boxes, red reins hung with glowing white bulbs, snowflakes, camera slides along them.
  Caption "Then that means it has to be...". BOOM+HIT 35:30.9 (+23 dB) at the cut out of white.
- 35:35.0-35:36.5 white; 35:37.0-35:40.5 FRONT-ON symmetric shot: pink sleigh front with a white figure in a santa
  hat, reindeer heads framing both sides, slow push-in. Caption "No way...". BOOM+HIT 35:36.9.
- 35:41.0-35:42.5 white; 35:43.0-35:46.5 LOW ANGLE from behind and below: black reindeer legs left and right, pale
  blue ice blocks in the foreground, the sleigh up ahead under the night sky (makes the team feel huge). BOOM+HIT 35:42.9.
- 35:47.0-35:49.5 white (3 s); 35:50.0-35:52.5 HIGH WIDE aerial shot of a snowy North-Pole village with a big
  "SANTA'S..." workshop arch, the sleigh with reindeer on a runway, then rising (take-off). BOOM+HIT 35:49.4.
  So every one of the four story shots starts with the same bass thump, about every 6 s.
- 35:53.0 brief white (0.5 s); 35:53.5-35:56.5 wide: the sleigh flies right to left across candy-cane snow hills,
  camera pans with it; 35:57.0 white; 35:57.5-36:00.0 wide over the snowy forest/village; 36:00-36:01 white;
  36:01.0-36:03.5 static wide: the sleigh flies over a gingerbread town wall and exits frame left at 36:03.5;
  36:04.0-36:07.0 white (3 s). Sound 35:50-36:01: a long smooth fade from -27 to -101 dB, then DIGITAL SILENCE
  (-120) 36:01-36:06 while the picture keeps going = the clip's audio was cut, so the real game sound here is unknown.
- 36:07.25 the REINDEER EGG (green egg with dark antlers, string lights, red bow and gold bell) DROPS in front of the
  gingerbread wall with snowmen and Christmas trees; 36:07.5 landed, squashed big; rainbow light glints sweep across
  it 36:07.75-36:10.75 while it bobs. Sound: HIT +52 and BOOM +81 dB at 36:07.2-36:07.5 = the landing slam.
- 36:11.0-36:12.0 egg goes white with rainbow streaks; 36:12.25 FULL WHITE (BOOM 36:12.3). White to 36:16.5;
  digital silence 36:16-36:17 (cut).
- 36:17.0 the world fades in; 36:18.0 the MASS-HATCH grid (~30 pets with labels "1 in 10k", "1 in 2k"...) with a
  coin counter "+8,973,867" and sparkles; HIT +88 dB / BOOM +77 dB at 36:18.1 = biggest jump in the clip. Grid gets a
  white/rainbow sheen 36:19-36:22.5. 36:24.5 back in the world with RAINBOW CONFETTI raining.
- 36:25.0 TWO cards side by side: "1 in 10k / Reindeer Corgi" (left) and "1 in 100b / Titanic Reindeer Cat" (right),
  cyan/blue background with big white snowflake shapes; 36:27.0 the titanic pet's face (white cat, red nose) zooms
  huge behind the text. BOOM +49 dB at 36:27.8. The "People" leaderboard panel top right shows best roll "100B".
- 36:28.5-36:35 = the YOUTUBER'S OUTRO. Not part of the game. No server-wide message is shown in this video.
VFX amount: 2-3 for the story shots (clean, cosy: stars, snowflakes, glowing bulbs), 3 on the present heap, 4 on the
egg glints/white-out. Never cluttered. Leaves the world: yes (presents room -> night sky -> North Pole). Player
avatar: NO. Camera: the only cutscene in my range with real cinematography: push-ins, a side tracking shot, a
symmetrical front shot, a low-angle hero shot, a high aerial wide, pans following the sleigh; shots last 3-4 s each
and are joined by WHITE flashes (1-3 s) instead of cuts.
Why it is the top: it is the longest (69 s), tells a little story (meet the driver -> the team -> take-off -> flight
over the town -> the egg is delivered), and every beat lands on a bass thump. The streamer's captions show the viewer
realising mid-scene that it is the rarest thing: a cutscene that gets LONGER and more special than the ones you
know is itself the reveal.

### C-SPACE: 32:41.5-33:49 pet "1 in 5,000,000,000" (galaxy pet, name too small to read) (clip "Credits: Tek")
Length: 32:41.5 (egg room fades up) -> 33:49 card = ~67 s; cutscene proper 32:41.5-33:41 = ~60 s.
Pictures: 1 s grid all through; 0.5 s frames 32:42-32:49.5, 32:55-33:26.5, 33:32-33:39.5 (a YouTube ad broke into
one frame set at 32:42; I cleared it and re-ran the set). Sound: 1 s table + events.
Beats:
- 32:41.5 default egg room, egg drops in (HIT +66 / BOOM +59 at 32:41.5-32:41.7 = landing). 32:43.0 yellow glow
  pulse; 32:44.5 a white SMOKE PUFF engulfs the egg; 32:45.5 HARD CUT to black (2 s).
- 32:47.5-32:55.5 deep space: black with hundreds of small white stars, a small grey MOON right of centre that
  drifts left (slow pan). Sound goes dark at once: HIGH falls from -30 to -83..-98 dB, MID to -40..-62; only a low
  pad remains (SUB -15..-22).
- 32:56.0 CUT closer: the moon fills the right half, bright sun rim on its left edge; 32:56-33:00.5 slow push in
  (bump to -14 dB at the cut). 33:01.0 a white-grey wipe as if the camera goes INTO the moon; 33:01.5-33:02.5
  WARP SPEED: white speed lines rush out from the centre on black, turning bluish. MID/HIGH rise (-30/-47) at 33:03.
- 33:03-33:18 calm: a dark star field with a shooting star, a purple-pink NEBULA slowly fades in (by 33:09), stars
  twinkle, shooting stars at 33:11.5, 33:12.5, 33:14.5, 33:15.0; very slow drift. Sound bed -15..-24 dB.
- 33:18.0-33:19.5 warp streaks again; 33:20.0 a SPIRAL GALAXY far away at the top of frame with a bright 4-point
  star FLARE at its core; 33:20-33:33 slow push down into it: the galaxy grows, tilts more face-on, the flare gets
  bigger. The music is fullest here: mix -11..-14, MID -22, HIGH -30..-35 (a long sustained swell, no hits).
- 33:33.5 the core flare blows out into a pink-white burst; 33:34.0-33:35.5 BLACK (2 s; sound dips to -20, HIGH -74).
- 33:36.0 ALIEN PLANET: purple ground, pink crystal spikes, tall blue alien tree/tower shapes, purple sky. 33:36.5
  a STARRY BLUE EGG appears with a dark purple VORTEX swirling round it (HIT/BOOM 33:36.3); 33:37-33:39 it pulses
  inside the swirl, sound brightest (HIGH -20..-23); 33:39.5 the egg glows white-blue; 33:40.4 BOOM +16 dB (sub -6)
  on the burst; 33:41 white.
- 33:41-33:45.5 white (digital silence 33:44-33:45 = edit). 33:46 world; 33:46.2 HIT +53 / BOOM +60; 33:47.5-33:49
  card "1 in 5,000,000,000" on a pink/purple background (BOOM +54 at 33:48.4). 33:49 normal "1 in 5" husky.
VFX amount: 2 (stars, a moon) -> 3 (nebula, shooting stars) -> 4 (galaxy flare, vortex). Never cluttered; most of
the time the screen is calm and dark. Leaves the world: yes, completely. Player avatar: NO. Camera: slow pans and
push-ins, one cut closer, two warp-speed rushes; no shake. Feel: a journey; the long quiet stretches (8 s of moon,
15 s of nebula) feel grand rather than boring because the music keeps swelling.

### C-TEMPLE: 33:53.3-34:52.5 kitsune-mask pet "1 in 10,000,000,000" (name too small to read) (no credit label)
Length: egg drop 33:53.3 -> card ends ~34:52.5 = ~59 s; cutscene proper 33:53.3-34:43.0 = ~50 s.
Pictures: 1 s grid all through; 0.5 s frames 33:56-34:03.5 and 34:33-34:40.5. Sound: 1 s table + events.
Beats:
- 33:53.3 egg drops into the default room (HIT +65 / BOOM +69 = landing), pulses (33:56.5 yellow glow).
- 33:57.5 HARD CUT to black. Big white brush-calligraphy CHARACTERS flash up one at a time in different places,
  each bright for ~0.5 s then fading to grey: 33:59.5 "紅" top right; 34:01.0 "白" big in the centre; 34:02.5 "銭"
  lower left-centre. Bass hits with them (34:02.1 BOOM +15, 34:03.9 BOOM +22) = like gong/taiko strikes.
- 34:04.0 a white emblem (a lion/tiger crest face) on black; 34:05 black.
- 34:06.0-34:33.5 one long FIRST-PERSON FLY-THROUGH (camera glides forward, slight turns): bamboo forest with a stone
  path (34:06-34:10) -> soft dissolve -> cherry-blossom avenue with petals (34:12-34:16) -> pink dissolve -> a garden
  with a waterfall and stepping stones (34:18-34:22) -> THROUGH a big red torii gate (34:23-34:25) -> a street of
  wooden houses (34:26-34:28) -> lavender dissolve (34:29) -> a blue-roofed white palace, approach and climb the
  stairs to its gold-framed door (34:30-34:33) -> white as the camera enters (34:33.5-34:34.5). Sound: one steady
  melodic music bed the whole way: mix -10/-11 dB, LOW as loud as SUB (-10..-13), MID -15..-25, HIGH ~-33. No hits
  during the flight; scene changes are soft dissolves.
- 34:35.0-34:40.5 inside a long pale-pink hall with blue window walls and bonsai plants; a pink blossom-patterned EGG
  on a red cushion at the far end; the camera keeps pushing forward so the egg grows from tiny to large; pink petals
  fall. 34:40.5 white sparkles burst from the egg; 34:41-34:43 egg glows, MID/HIGH jump to -13..-16 dB (brightest
  moment); 34:43 white.
- 34:43-34:48.5 white (digital silence 34:47-34:48 = edit). 34:49 world; 34:49.4 BOOM/HIT +43 = reveal slam;
  34:50-34:52 card "1 in 10,000,000,000" with a white kitsune-mask pet (red markings) on a red radial burst.
VFX amount: 1-2 (the scenery does the work) until a 3-4 burst at the end. Leaves the world: yes. Player avatar: NO.
Camera: one continuous forward glide (dolly) with dissolves; feels like being carried to the shrine. A good model
for "the crate pulls you in and takes you somewhere": the trip itself is the build-up.

### C-HALLOWEEN: 22:25.4-23:04.5 ghost-mask pets, result "1 in 400m / 1 in 1.2b / 1 in 90m"
Length: egg 22:25.4 -> cards end ~23:04.5 = ~39 s; cutscene proper 22:25.4-22:54.5 = ~29 s.
Pictures: 1 s grid all through; 0.5 s frames 22:32-22:59.5. Sound: 0.5 s table + events.
Beats:
- 22:25.4-22:32 default egg room (pale sky variant), egg drops, pulses. 22:32-22:34.5 the picture narrows into a
  pillarbox (black bars grow from both sides) = editing in the source clip; 22:35-22:36.5 black.
- 22:37.0 HARD CUT to a purple-pink GRAVEYARD: a big grey TOMBSTONE fills the centre, a carved jack-o-lantern bottom
  right, black bats flapping across. Letters are carved onto the stone ONE BY ONE (~2 per second): 22:38.0 "R",
  22:38.5 "RI", 22:39.5 "RIP", then the PLAYER'S OWN USERNAME types out under it: 22:41 "U", 22:41.5 "US", 22:42
  "USE", 22:42.5 "USEST", 22:43 "USESTA" ... 22:46 "USESTARCODEL..." (the player's name).
- 22:44.5-22:48.5 the camera PULLS BACK slowly from the stone: the graveyard opens up, more stones, bare purple
  trees, white SKELETON HANDS rising out of the ground on the left, a dark ghost shape flits across the top (22:46).
- 22:49.0 JUMP SCARE: hard cut to an extreme close-up of a white GHOST-MASK face with black hollow eyes, filling the
  screen on darkness; 22:49.5 it dims, 22:50.0 even closer and darker. SUB jumps -34 -> -18/-12 dB (a bass sting).
- 22:50.5 bright white/rainbow flash; 22:51.0 the hatched pet (white hockey-mask ghost holding a knife up) stands in
  the graveyard among the skeleton hands; white light rays grow behind it 22:51.5-22:53.5 (HIGH -14 at 22:53);
  22:54.0-22:54.5 white burst; 22:55 white.
- 22:55-23:00 white/world (cuts at 22:58.0 and 23:00.0 are editing); 23:00.6 HIT +70 / BOOM +58 = reveal slam;
  23:01-23:04 THREE cards in a row "1 in 400m", "1 in 1.2b", "1 in 90m" (three ghost-mask panda pets) with BLACK
  SMOKE puffs and a green ghost behind them.
Sound caveat: this clip's audio is dominated by LOW (-3..-10 dB) with SUB weak (-25..-38) and choppy drops every
~1 s = almost certainly the streamer TALKING loudly over it. Only the jump-scare bass (22:49) and the burst
brightness (22:53) stand out as game sound.
VFX amount: 2 (bats, hands, rays), 4 on the final burst. Leaves the world: yes. Player avatar: NO, but the player's
NAME is in the scene (on the grave). Camera: static close-up, slow pull-back, hard-cut jump scare.
Funny/over-the-top: the game writes "RIP <your name>" on a tombstone before you get your pet; then a knife-wielding
ghost jumps at the camera. Personal and silly at the same time.

### C-RED-DRAGON: 30:11.5-30:38.5 red dragon cat "1 in 2,500,000,000" (clip "Credits: Thomas Baker")
Length: egg 30:11.5 -> card ends 30:38.5 = 27 s; cutscene proper 30:11.5-30:29.5 = 18 s.
Pictures: 1 s grid; 0.5 s frames 30:12-30:27.5. Sound: 0.5 s table + events.
Beats:
- 30:05-30:11 black (6 s, silent; clip start). 30:11.6 egg lands in the default room: HIT +89 / BOOM +86 dB.
- 30:13.0 yellow-green glow; 30:14.0 a white LIGHTNING bolt cracks down beside the egg; 30:14.5 big glow pulse;
  30:17.5 a WHITE CASTLE fades in behind the egg with another bolt at 30:18.0 (BOOM +37 at 30:17.6). Sound then
  darkens: MID/HIGH fall to -42..-71 by 30:19.5.
- 30:20.0-30:21.5 TOTAL SILENCE (-120 dB, 1.5 s) across the cut: 30:20.5 the camera is now INSIDE a red castle (tall
  dark-red walls and towers), the egg wrapped in a crackling blue electric aura. 30:21.7 a huge HIT +103 dB / BOOM
  +99 dB (the strongest jump measured in my range) = "silence, then slam". (Possibly a game-side mute, possibly the
  recorder; the picture does not go black.)
- 30:23.5 the egg CATCHES FIRE: it turns black and charred with orange flames licking up its left side, purple
  sparks; 30:25.0 it EXPLODES in white-red light rays; 30:25.5 a round red DRAGON with bat wings stands where the egg
  was; 30:26.5-30:27.0 golden rays fan out behind it; 30:27.5 it opens its mouth (roar). 30:28-30:29 HIGH band at its
  brightest (-11 dB). 30:29.0 white SHOCKWAVE dome; 30:29.5-30:34.5 white.
- 30:35.5 HIT/BOOM +37/+34 = reveal; 30:36-30:38 card "1 in 2,500,000,000" (red blocky dragon cat on a red/orange
  burst with flames).
VFX amount: 3-4 (lightning, electric aura, fire, rays, dome), CLEAN: one effect at a time. Leaves the world: yes
(castle). Player avatar: NO. Camera: static medium on the egg; one cut (outside castle -> inside); no movement.
Note: here the egg itself becomes a creature (the hatch IS the reveal of a living thing), not just a flash.

### C-GENERIC (the 1/100M-1/1B "Huge" cutscene, seen ~10 times 18:20-22:20): e.g. 18:37.5-18:52
(Pictures: 1 s grids only for these repeats, plus the 0.25 s look at the same opening inside C-LAVA 25:33-25:38.)
- black ~1.5 s -> fade up, egg DROPS in and lands (bass thump) -> ~3-4 s of the egg sitting in the room: rainbow
  rim glow, white 4-point sparkle stars, 1-2 glow pulses, sometimes white smoke puff or rainbow aura -> egg goes
  white / cracks with white light (19:12) or bursts into pale-blue diamond SHARDS (20:52) -> white screen 3-5 s ->
  world 0.5-1 s -> card ("1 in 800,000,000" ... "1 in 1,000,000,000") ~3-5 s with the pet in a coloured burst and
  sometimes confetti (21:25-21:31 orange confetti; 25:24-25:30 multicolour).
- Room variants: green checker floor + purple sky with white diagonal light stripes (18:25), lavender/snow floor +
  purple sky (19:25-19:33, with gold radial rays behind the egg at 19:32), green floor + pale sky (20:22+).
- Sound (18:20-19:20): each clip: SILENCE at the gap, HIT +23..+61 / BOOM +29..+69 dB on the landing, steady bass bed
  ~-15..-25 dB, sometimes a RISER (18:51.0-18:52.5) before the burst, BOOM on the card.
VFX 2-3; ~11-13 s total; no scene change. This is the "first rare" level: same scene every time.

### Other themed cutscenes (1/1B-1/5B tier), from the 1 s grid + sound events + 2 s tables; 0.5 s frames where noted
All share the opening (black -> egg drops into the default room, landing thump -> pulses) and the ending (white
3-5 s -> world -> card). Only the middle "theme" differs. The player's avatar never appears in any of them.
- C-VALENTINE 23:09-23:34 (shiba "1 in 1,250,000,000"): egg -> 23:14 pink HEARTS fly up round the egg -> 23:15-23:18
  the screen WASHES pink (the "?" egg grows huge and pale = push into the egg) -> 23:19 pink candy land: rainbow arc,
  yellow stars, pink blossom trees, pink egg with red heart spots -> 23:21-23:22 white light streaks -> 23:23 white
  burst. Card 23:30-23:34 with pink hearts floating. Sound: dips to -22 dB (HIGH -53) at 23:14 just before the pink
  wash, then -9..-13 with HIGH -13 at 23:22 (sparkly); BOOM +98 dB on the card (23:29.3). VFX 3.
- C-DRAGON-CASTLE 23:41-23:58 (green dragon): 0.5 s frames 23:47-23:54.5. 23:45 white smoke puff; 23:47.5 blue
  electric glint; 23:48.0 cut to a white CASTLE courtyard with blue banners; 23:50.5 the egg IGNITES top-right;
  23:51.0-23:52.0 egg turns CHARRED BLACK with glowing orange CRACKS and flames (a lava egg); 23:52.5 rainbow-white
  burst and a GREEN DRAGON bursts out, wings spread, a flame on its head; 23:53-23:54.5 sparkle bursts, slight
  pull-back; 23:56 white. Sound: BOOM +85 landing, BOOM +38 at the castle cut (23:48.1), steady -9..-11 dB with MID
  rising to -12 at 23:52 (the hatch). VFX 3. Only 17 s.
- C-BLOOD-FOREST 24:00-24:23 (black/white demon wolf "1 in 1,500,000,000"): egg -> 24:05-24:07 black -> 24:08 RED FOG
  forest of dead black trees, a black egg covered in white EYEBALLS with red irises; camera pulls back 24:08-24:11 ->
  24:12 the egg glows white -> 24:13 white. Card 24:19-24:22 with black smoke. Sound: quiet and flat the whole clip
  (-21..-26 dB, no big hits) = probably a low recording. VFX 2. Creepy by colour alone.
- C-TREASURE-JELLY 24:26-24:55 (blue fluffy "1 in 1,500,000,000"; again 27:29-27:54 "1 in 2,000,000,000"): egg ->
  24:30 a golden TREASURE CHEST -> 24:31-24:35 small jelly/blob pets pop out one by one -> 24:36-24:39 a SWARM of
  colourful jelly pets fills the whole screen (RISER 24:37.5-24:39.0) -> 24:40 a rainbow-striped egg on a green hill
  with trees and a rainbow -> 24:44 white. Sound: near-silent dip 24:30-24:35 (HIGH -62..-98) while the chest
  appears, then rising; digital silence 24:47-24:49 (edit). VFX 4 (the swarm hides the egg = cluttered).
- C-CHRISTMAS 24:56-25:31 (also 19:45-20:18 vertical, 26:52-27:23, 27:56-28:33, 30:42-31:15, and the start of the
  Titanic): egg -> white poof -> green PRESENT -> presents drop in one by one and pile up -> white -> snowy
  gingerbread village with Christmas trees, candy canes, snowmen; a red/green striped ORNAMENT egg with a snow cap and
  string lights -> white -> card or multi-hatch grid with confetti. Sound: SUB-led bed -13..-19 dB, a BOOM on each
  drop, HIGH -18 at 25:16 (sparkle before the white), BOOM at the card. VFX 3. ~30 s.
- C-THANKSGIVING 26:21-26:45 (turkey pumpkin pet + multi-hatch): 0.5 s frames 26:24-26:31.5. 26:25.0 a pilgrim hat
  pops onto the egg; 26:25.5 a FLOCK of small turkeys flies in from the left in smoke puffs and circles the egg;
  26:26.5 a big pilgrim-hat turkey stands in front; 26:28.0 a turkey flies straight INTO THE LENS (frame goes orange);
  26:28.5-26:31.5 crash-zoom EXTREME CLOSE-UPS: an eye and beak, the hat's gold buckle, the turkey's side, then its
  face with big glowing fiery eyes; 26:32 white; 26:33-26:36 the turkey pumpkin pet with rays. Sound: SUB drops out
  (-34..-56) during 26:26-26:31 while LOW stays -15 (gobbling or the streamer's voice); BOOM +101 dB on the
  multi-hatch at 26:42.9. VFX 3. Very silly.
- C-FROST-SNOWMAN 28:40-29:08 (also 29:38-30:03 and 31:20-31:45): egg -> 28:46 egg FROSTS over (pale blue, icy) ->
  28:50 white -> snowy village with candy canes; a SNOWMAN pet (top hat, red scarf, carrot nose) with snow falling
  (31:32-31:35 version has fire torches round it) -> white -> card (ice yeti with flame hair "1 in 2,000,000,000";
  blue cat "1 in 2,500,000,000"; grinch cat in santa hat "1 in 2,500,000,000"). Sound quiet in this clip
  (-22..-33). VFX 2-3.
- C-UNDERWATER 29:16-29:34 (glowing blue jellyfish cube "1 in 2,000,000,000", title card "Huge Abyssal Jellyfish" at
  29:09; again 32:20-32:38 "1 in 3,000,000,000"): the whole room turns CYAN, like being underwater; 29:21 a ring of
  water/bubbles bursts round the egg; 29:24-29:25 the egg dissolves into bubbles -> white. Sound: full and bright
  (-7..-11 dB, HIGH -10 at 29:24 on the bubble burst). VFX 3.
- C-DISCO 31:51-32:17 (multi-hatch): egg frosts -> 32:00 white -> 32:03 a DISCO: rainbow light-up dance floor, big
  wall speakers, a spiky dark pet in pink LED shades, 32:05 pink light burst -> white -> 32:13 multi-pet grid with
  rainbow streaks. Sound: RISER 31:56.5-31:58.0 into the white, then a louder, LOW-heavy beat (-14 dB, LOW -13)
  during the disco 32:02-32:07 with BOOMs about every 5 s. VFX 3-4.


## 2b. Cutscene log (one line each; times are video times; VFX 1-5; "world" = leaves the game world; "avatar" = player's own avatar in the scene; quality 1-5)

| # | start-end | len | what | rarity | VFX | world | avatar | quality / why |
|---|---|---|---|---|---|---|---|---|
| 1 | (B7)-18:22 | - | end of a clip started in B7: multi-pet result screen, pink bunny | - | 2 | no | no | started in B7 |
| 2 | 18:23.5-18:36 | ~12 s | generic egg -> orange fluffy pet | 1 in 800,000,000 | 2 | no | no | 2: same template every time |
| 3 | 18:38-18:52 | ~14 s | generic -> yellow corn cat | 1 in 800,000,000 | 2 | no | no | 2 |
| 4 | 18:54-19:05 | ~11 s | generic -> grey/pink cloud pet | 1 in 850,000,000 | 2 | no | no | 2 |
| 5 | 19:08-19:22 | ~14 s | generic (egg cracks white) -> candy-cane pet, red/white rays | 1 in 999,000,000 | 3 | no | no | 2 |
| 6 | 19:24-19:44 | ~20 s | lavender room, sparkles, gold rays -> white angel pet | 1 in 1,000,000,000 | 3 | no | no | 3: gold rays before the white |
| 7 | 19:48-20:18 | ~30 s | CHRISTMAS (vertical clip) -> star pet | 1B tier | 3 | yes | no | 4 |
| 8 | 20:21-20:40 | ~19 s | generic (pale sky) -> brown dog | 1 in 1,000,000,000 | 2 | no | no | 2 |
| 9 | 20:43-21:02 | ~19 s | generic, blue shard burst -> husky | 1 in 1,000,000,000 | 3 | no | no | 3 |
| 10 | 21:08-21:31 | ~23 s | generic (facecam clip) -> blue cat, confetti | 1 in 1,000,000,000 | 3 | no | no | 2 |
| 11 | 21:42-22:00 | ~18 s | generic, green-yellow aura -> calico cat | 1 in 1,000,000,000 | 3 | no | no | 2 |
| 12 | 22:01-22:20 | ~19 s | generic (vertical, far egg) -> big candy pet | 1B tier | 3 | no | no | 2 |
| 13 | 22:25-23:04 | ~39 s | HALLOWEEN: RIP name tombstone, ghost jump scare | 400m / 1.2b / 90m | 2-4 | yes | name only | 5: personal and funny |
| 14 | 23:09-23:34 | ~25 s | VALENTINE: hearts, pink wash, candy land | 1 in 1,250,000,000 | 3 | yes | no | 3 |
| 15 | 23:41-23:58 | ~17 s | DRAGON CASTLE: egg chars black with lava cracks, green dragon | 1B+ tier | 3 | yes | no | 4: egg becomes a creature |
| 16 | 24:00-24:22 | ~22 s | BLOOD FOREST: eyeball egg in red fog | 1 in 1,500,000,000 | 2 | yes | no | 3: creepy by colour |
| 17 | 24:26-24:55 | ~29 s | TREASURE/JELLY: chest, jelly swarm, rainbow egg | 1 in 1,500,000,000 | 4 | yes | no | 3: swarm is cluttered |
| 18 | 24:56-25:31 | ~35 s | CHRISTMAS -> 8-pet multi-hatch | 1B+ tier | 3 | yes | no | 3 |
| 19 | 25:33-26:01 | ~28 s | LAVA: dark void with cat eyes, lava arena, lightning | 1 in 1,800,000,000 | 3 then 5 | yes | no | 5: three acts, scary dark |
| 20 | 26:05-26:17 | ~12 s | generic -> dark reindeer | 1 in 2,000,000,000 | 2 | no | no | 2 |
| 21 | 26:21-26:45 | ~24 s | THANKSGIVING: turkey flock, turkey into the lens | 2B tier + multi | 3 | yes | no | 4: silly crash zooms |
| 22 | 26:52-27:24 | ~32 s | CHRISTMAS -> red cube pet | 1 in 2,000,000,000 | 3 | yes | no | 3 |
| 23 | 27:29-27:54 | ~25 s | TREASURE/JELLY -> purple pet | 1 in 2,000,000,000 | 4 | yes | no | 3 |
| 24 | 27:56-28:33 | ~37 s | CHRISTMAS (streamer captions) -> red burst pet | 2B tier | 3 | yes | no | 3 |
| 25 | 28:40-29:08 | ~28 s | FROST/SNOWMAN -> ice yeti | 1 in 2,000,000,000 | 3 | yes | no | 3 |
| 26 | 29:16-29:34 | ~18 s | UNDERWATER -> Huge Abyssal Jellyfish | 1 in 2,000,000,000 | 3 | yes | no | 3 |
| 27 | 29:38-30:03 | ~25 s | FROST/SNOWMAN -> blue cat | 1 in 2,500,000,000 | 3 | yes | no | 3 |
| 28 | 30:11-30:38 | ~27 s | RED DRAGON: lightning, castle, egg burns, dragon roars | 1 in 2,500,000,000 | 3-4 | yes | no | 4: silence then slam |
| 29 | 30:42-31:15 | ~33 s | CHRISTMAS (vertical) -> elf pet | 1 in 2,500,000,000 | 3 | yes | no | 3 |
| 30 | 31:19-31:45 | ~26 s | FROST/SNOWMAN with fire -> grinch cat | 1 in 2,500,000,000 | 3 | yes | no | 3 |
| 31 | 31:51-32:17 | ~26 s | DISCO -> multi-hatch | 2B+ tier | 3-4 | yes | no | 4: music changes to a beat |
| 32 | 32:20-32:38 | ~18 s | UNDERWATER -> purple pet | 1 in 3,000,000,000 | 3 | yes | no | 3 |
| 33 | 32:41-33:49 | ~67 s | SPACE: moon, warp, nebula, galaxy, alien planet | 1 in 5,000,000,000 | 2-4 | yes | no | 5: a real journey |
| 34 | 33:53-34:52 | ~59 s | TEMPLE: calligraphy, fly-through to a shrine | 1 in 10,000,000,000 | 1-3 | yes | no | 5: scenery does the work |
| 35 | 35:03-36:28 | ~85 s | TITANIC: presents, Santa sleigh story, reindeer egg | 1 in 100,000,000,000 | 3-4 | yes | no | 5: story and cinematography |

Normal hatches (not cutscenes) seen at 18:37, 18:53, 19:05, 20:40, 21:38, 22:21-22:23, 23:05, 24:23, 27:25, 30:04, 31:16, 31:47, 32:17, 32:38, 33:49, 34:53-34:56.5. Total: 34 full cutscenes logged in my range + 1 started in B7.

## 4. Patterns across my cutscenes

- RARITY LADDER (time, scenery, camera):
  - common roll: a pet pops up in the world with "1 in 7", about 1 s. Mass roll: a grid of eggs that turn into pets, about 2.5 s.
  - 1/100M-1/1B: the SAME generic egg-room scene every time, 11-14 s, never leaves the room, static camera.
  - 1/1B-1/5B: generic opening + a THEMED world (Christmas, Halloween, lava, castle, sea, disco...), 17-39 s.
  - 1/5B and 1/10B: 60-70 s journeys (space; temple fly-through) with long calm stretches and a moving camera.
  - 1/100B Titanic: about 85 s with a little story told in 6+ shots joined by white flashes, plus everything above.
  - So rarity mostly adds LENGTH, a NEW PLACE and CAMERA MOVEMENT, not more particles. VFX peaks at 4-5 only for 1-2 s right before the white-out.
- Every rare cutscene has the same skeleton: black -> the egg DROPS and LANDS with a heavy bass thump -> pulses -> (theme) -> white flash / white-out 3-5 s -> back in the world -> the card SLAMS in with another bass hit -> card holds 3-4 s -> back to rolling. The repeated opening is what makes the theme change a surprise (streamer captions: "Wait it's not...", "I've never gotten this cutscene before").
- Transitions: hard cuts to black or to a new place for scares; WHITE dissolves for "magic" changes. The white-out before the card is always 3-5 s.
- SOUND: the game uses a heavy SUB-bass bed; key moments are marked by bass thumps (landing, card) more than by loud highs. Brightness (MID/HIGH) climbs only for the final burst (lava 25:50-25:52 HIGH -11 dB; temple 34:42 HIGH -13). Dark scenes cut the highs completely (space HIGH -90; lava void HIGH -40). Silence before a hit: red dragon 30:20.0-30:21.5 total silence, then +103 dB. Each Titanic story shot opens on a bass thump about every 6 s.
- The PLAYER'S AVATAR is never in any Pets Go cutscene; the player is "the camera". Only the Halloween one makes it personal (writes "RIP <username>"). The card shows the pet, not the player.
- Nothing server-wide is shown in this video (only the player's own screen and a leaderboard panel with "best roll").

## 5. Ideas for the user's lava-belt cinematic and other gear (copy the moves, never the art or music)

Copy:
1. Same opening for every rare, then the twist: always start the crate-open the same way (character lifts the crate, sets it down, unlocks it, the crate THUMPS on landing), so when the lava version starts going somewhere new the player feels it. (25:33.8 egg drop + BOOM +69 dB; Titanic 35:24 "Wait it's not...")
2. The "pulled in" moment = a hard cut to BLACK with embers and glowing eyes for 5-8 s before the volcano (25:38.3-25:47.0). For the lava belt: cut to black, embers drifting up, a deep rumble with no highs, then the volcano's glow rises from below (25:46.8 red glow) and CUT to the volcano. Cheap and very effective.
3. Foreshadow the theme while still in the normal scene: a small fireball/spark flies past the crate 1-2 s before the cut (25:37.0-25:38.0).
4. Silence, then slam: 1-1.5 s of total silence right before the eruption or the moment the giant lifter smashes the rocks together, then the biggest bass hit of the scene (30:20.0-30:21.7, +103 dB).
5. One big effect at a time, peak clutter only about 1.5 s: lightning -> spark storm -> shockwave dome -> white (25:49.3-25:52.3). Keep the belt-forging moment readable: sparks round the hands, then a dome/flash.
6. Real camera moves for the top rarity only: a low angle under the giant (35:43 reindeer low shot makes them huge), a symmetrical front shot (35:37), slow push-ins (35:24-35:28), each shot change on a bass thump with a short white flash (Titanic, every ~6 s). For the lava belt: low angle up at the buff lifter blocking the eruption.
7. Personal touch: put the player's name in the scene (Halloween types "RIP <name>" letter by letter, 22:38-22:46). E.g. the forged belt gets the player's name stamped on it, shown in a close-up.
8. A journey sells "new dimension": Temple (34:06-34:33) and Space (32:47-33:36) carry the camera through a world for 30-60 s with dissolves and a swelling music bed; good for a tier above Legendary.
9. The card slam: white-out, back to the world, then the item card SLAMS in (bass hit) with a huge close-up and a radial burst in the item's colours, big rounded white text with a dark outline, the item name under it; hold 3-4 s (25:58.0-26:01.3). For gear: "LAVA BELT" big, "LEGENDARY" under it, lava-coloured burst.
10. Funny-serious moments: a turkey flying into the lens with crash-zoom close-ups (26:28-26:31); a knife-ghost jump scare (22:49). "Stay safe kid" works the same way: dead-serious delivery, absurd content.

Gear ideas from these templates: knee sleeves = FROST theme (egg frosts over 28:46, snowy world, ice burst); wrist wraps = LIGHTNING/storm (30:14 bolts, electric aura 30:21); singlet = the chest-and-swarm joke (24:30-24:39: the crate bursts and a swarm of mini lifters fills the screen); duck-floaty belt = UNDERWATER (29:16-29:25: room turns cyan, bubbles, the egg dissolves into bubbles) or a silly flock like the turkeys (26:25.5).

Avoid:
- One generic scene for many rarities: by the 10th identical egg room (18:20-21:31) it means nothing.
- Full-screen swarms that hide the item for seconds (24:36-24:39 jelly swarm).
- Long dead white screens: the 4-5 s white-outs (25:52.3-25:56.8, 36:12-36:17) are the dullest part; keep the white short or fill it with the sound tail/riser.
- Leaving the player out: Pets Go never shows the avatar; the user's idea (pulled in, thrown out with the belt on) is stronger. Keep the avatar in shot for the pull-in and the throw-out.

## Coverage summary (final)

- Pictures: 1 s grids for every second 18:20-36:35 (69 grids, back to back). 0.25 s frames: 25:31.0-26:02.8 (lava, whole cutscene), 36:07.0-36:14.75 (Titanic egg). 0.5 s frames: 22:32-22:59.5 (Halloween), 23:47-23:54.5 (dragon castle), 26:24-26:31.5 (Thanksgiving), 30:12-30:27.5 (red dragon), 32:42-32:49.5, 32:55-33:26.5 and 33:32-33:39.5 (space), 33:56-34:03.5 and 34:33-34:40.5 (temple), 34:52-36:22.5 (Titanic, whole). Big single frames for text at 25:59.5, 26:00.1, 34:53.6-34:55.2, 35:25.5-35:33.5, 36:20.0-36:27.0, 36:28.5, 36:30.5.
- NOT done at 0.25 s: the other ~25 cutscenes (generic repeats and the Christmas / frost / underwater / treasure / disco / valentine / blood-forest repeats) were seen at 1 s only (plus 0.5 s where listed). No 0.1 s passes were made (the hidden pane's screenshots are about 800 px wide; 0.25 s already showed the motion of the key hits).
- Sound: recorded 18:18-36:35 completely ("ok"). Events + tables read for lava (0.5 s), Titanic (1 s), space (1 s), temple (1 s), Halloween (0.5 s), red dragon (0.5 s); 2 s tables + events for valentine, dragon castle, blood forest, treasure, Christmas, Thanksgiving, frost, underwater, disco; events for 18:18-22:20. No captions exist; Halloween and some others are likely mixed with the streamer's voice.
- Two mid-roll ads appeared during frame grabs (around 34:00 and 32:42); both were cleared and the affected frames re-taken.
