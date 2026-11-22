# Batch B7 notes: Pets Go "ALL PET CUTSCENES! (1/1M TO 1/100B)"

## 1. Videos and coverage log
- Video id JRClaaYZXJc, "ALL PET CUTSCENES! (1/1M TO 1/100B) | PETS GO!" by PsychoRages, 36:35 (2195.4 s), 1080p source.
- My range: 0:00-18:20 (another helper does 18:20 to the end). The clip running at 18:20 ends at 18:22, so I covered it to 18:23.
- No captions/transcript on this video (transcript button absent). No talking YouTuber; his additions are on-screen
  text, credit labels, black text cards and zoom-ins.
- YouTuber chapters (from description): 0:00 1/1M-1/10M; 3:19 1/10M-1/50M (Egg Cutscene); 5:40 1/50M-1/100M;
  9:12 1/100M-1/1B (Huge Egg Cutscene); 19:20 1/1B-1/5B (Actual Huge Egg Cutscenes); 32:37 1/5B-1/10B; 34:52 1/100B (Titanic).
  (The chapter names are a bit off: the first egg cutscene actually appears at 5:40, not 3:19.)

### Coverage log
- SOUND: whole range 0:00-18:32 recorded with __audioRun at 2x (chunks 0-240, 240-480, 480-720, 720-750, then
  748-988 and 987-1112). A YouTube mid-roll ad started at ~12:30 during the first pass; its audio got mapped onto
  video time 0:00-0:15 by the tool, so I deleted those map points/blocks (everything recorded after the ad began) and
  re-recorded 12:28-18:32. Final check: every 1-s bin from 0:00 to 18:32 has audio data; every chunk returned "ok".
  __audioEvents run for 0:00-4:00 (whole), and per cutscene; __audioTable at 0.5 s for 0:00-0:30, 5:38-6:02,
  6:52-7:08, 10:30-10:41, 14:32-14:41, 16:20-16:36, 17:53-18:24; at 0.25 s for 0:11-0:16 (roll reveal),
  5:43.5-5:49 and 5:51-5:56 (egg), 16:29-16:32 (egg reveal). A script also listed EVERY "silence -> hit" pair from
  5:30 to 18:24 at 0.25 s (56 pairs, used in section 4).
- PICTURES: overview grids __sheet(start, 1, 16, 4) back to back with no gaps from 0:00 to 18:24 (70 grids: 0, 16,
  32 ... 1088). Every grid was looked at.
- Close-ups (__frames): 0:11-0:19 at 0.25 s and 0:13.3-0:13.8 at 0.1 s (roll reveal template); 0:43.5-0:51.5 at 0.5 s
  (triple roll); 5:39.5-5:55.5 at 0.25 s plus 5:40.6-5:41.3 and 5:51.4-5:54.0 at 0.1 s (first egg cutscene, full);
  6:07.3-6:08.5 at 0.1-0.3 s (egg reveal); 6:57.5-7:05.5 at 0.25 s (lightning egg variant); 8:05.6-8:09 at 0.1-0.5 s
  (falling-egg variant); 8:47.5-8:59.5 at 0.25-0.5 s (triple Huge reveal); 10:33.5-10:37.5 at 0.25 s (dark Bloo Cat
  reveal); 14:34.5-14:40 at 0.5 s (text punch-in); 16:22-16:34 at 0.25 s (spotlight-stage egg, full); 17:50-17:51.5,
  17:57-18:13 at 0.25-0.5 s (frost egg and disco room).
- NOT done at 0.25 s: about 45 of the ~75 rare clips (they repeat the two templates; seen only at 1 s in the grids).
- Viewing limits: the Browser pane was hidden, so every image came from the zoom action at 800x456 physical pixels
  (some zooms timed out and were retried). I CSS-scaled the frame canvas: overview grids show each frame at ~200x112 px,
  close-ups ~200-400 px wide. Big text ("1 in N") is readable everywhere; pet names under it only in close-ups.
- Note on the data: in my first pass of writing notes, the Bash appends went to a sandbox copy, not the real file;
  I rebuilt this file from that copy in full. Nothing was lost.

## Video structure seen (0:00-18:20)
- The video is the YouTuber's compilation of many short clips (his own and "Credits: <name>" clips from other players),
  hard-cut together, with a ~1-2 s black gap between egg clips. Constant YouTuber overlay text in yellow with a black
  outline at lower centre ("this video took SO long to make so you should drop a like ... THANKS ;)") sits on top of
  the game's "1 in N" text for most of 0:00-1:00.
- 0:44.0-0:44.9: a dark editor/settings window flashes on screen (YouTuber's editing mistake, not the game).
- Credited clips (LuLu, WyvernOfHades, OfficialZakLibrary, Nexik2rree, LeLe, RyanBlox) have louder steady LOW/MID
  sound (-8 to -15 dB) = probably their own music or their game music; I do not credit that sound to the reveal.

## The normal (non-rare) roll in Pets Go
Pets Go here is an RNG "roll"; rare enough rolls turn into an egg cutscene (from 1 in 50M).
- View: full-screen roll view: sky-blue background with soft white clouds, coloured triangle bunting (blue, purple,
  green, yellow, red) across the top third, faint pale diagonal rays from the centre. HUD stays on the left (coins
  2.49b, 50m, gems 2,690), round "Auto Roll" button bottom-left, a "New Index / View Your Collection" banner at top
  centre when a pet is new. The backdrop follows the zone: from 1:41 it is an orange autumn sky.
- Commons: one big blocky pet at centre (~1/3 screen high) with grey/dark "1 in 2" ... "1 in 9" under it; the pet
  swaps every ~0.25-0.5 s like a slot machine, each swap a small scale pop and a bright chime; the last one stays
  ~1 s and goes to the collection. About 2 s, no white-out, no burst (e.g. 1:40 "1 in 9", 5:40.0, 12:22, 13:58).
- In the newer version (12:22, 16:07, 18:22) the common shows over the live world with the HUD, not over a sky card.
- A rare looks the same size as a common; only the white-out, burst, sparkles and text colour tell them apart.

## Running log of rolls and cutscenes (0:00-18:23)
"Credits: X" = a clip by another player.
- 0:00-0:11 snowy hub world, player avatar with a green-winged pet; at 0:05 already on the reveal of a rare
  (green-winged pet, "View Your Collection" banner) -> 0:11 cut. (the roll itself is cut out)
- 0:11-0:15.8 Silver Stag 1 in 1,000,000 (pink burst, gold sparkles). Detailed below (TEMPLATE A).
- 0:16-0:21 unicorn-sunglasses pet 1 in 1,000,000 (pink).
- 0:21-0:26 fox/kitsune 1 in 1,000,000 (orange fire burst, fire particles). 0:26-0:30 kitsune-mask fox 1 in 1,000,000
  (pink). 0:32-0:35 pink bunny-jar 1 in 1,000,000. 0:37-0:39 ice snowman 1 in 1,000,000 (pink). 0:41-0:43 golden flower
  dog 1 in 1,000,000 (pink).
- 0:44.0-0:44.9 YouTuber editing glitch (dark settings window).
- 0:45-0:49 Credits: LuLu: autumn world, TRIPLE roll (3 pets side by side: pumpkin, ghost, dice), white-out 0:46.0-0:47.0,
  reveal 0:47.5: green ghost pet "1 in 1m" (centre) between two "1 in 66k" dice; radial speed-line burst and
  yellow/orange glow behind; coin counters on the HUD tick up (+5,000 ...).
- 0:51-0:56 candy-cane reindeer 1 in 1,000,000 (pink burst, red/white candy canes flying out).
- 0:56-0:59 neon-outline pet 1 in 1,350,000 (pink). 1:00-1:04 dark cat 1 in 1,500,000 (gold-black rays).
  1:05-1:08 rainbow pinata pet 1 in 1,800,000 (pink, confetti).
- 1:09-1:13 Credits: LuLu triple roll in an autumn world: black cat "1 in 2m" centre, two "1 in 32.5k".
- 1:14-1:19 red dragon-cat 1 in 2,200,000. 1:22-1:25 unicorn cat 1 in 2,500,000. 1:27-1:30 jelly 1 in 2,500,000.
  1:31-1:35 narwhal 1 in 2,850,000. 1:37-1:40 purple axolotl 1 in 3,000,000.
- 1:41 onward the roll backdrop is ORANGE (autumn zone) instead of blue sky.
- 1:44-1:45 skeleton 1 in 3,330,000: burst is DARK SMOKE (black/brown cloud) instead of pink.
- 1:49-1:51 grim reaper 1 in 3,500,000: pink flash then a black smoke cloud with flying black shards.
- 1:55-1:57 cyborg pet 1 in 3,900,000 (purple burst, teal laser streak). 2:00-2:02 demon 1 in 4,000,000 (RED/BLACK
  explosion cloud). 2:06-2:07 golden cat 1 in 4,000,000 (gold/pink). 2:11-2:13 dark crystal cat 1 in 4,600,000.
  2:17-2:18 Christmas pet 1 in 5,000,000 (GREEN burst). 2:22-2:24 ice cat 1 in 5,000,000 (white/blue).
- 2:25-2:30 Credits: WyvernOfHades: roll shown IN THE WORLD (player avatar visible behind, the pet pops up in front of
  the player in the map), reveal 2:28 panda-mask pet 1 in 5,000,000 with pink burst.
- 2:34-2:35 dog 1 in 5,000,000 (brown dust burst + white shock ring). 2:39-2:40 sphinx cat 1 in 5,750,000 (pink).
  2:44-2:46 cyber bunny 1 in 6,500,000. 2:50-2:52 forest spirit 1 in 7,000,000 (GREEN burst + green ground wave).
  2:56-2:58 white angel 1 in 7,780,000 (gold). 3:02-3:04 angel 1 in 7,780,000. 3:08-3:10 wizard-hat cat 1 in 8,000,000.
  3:13-3:15 fire flower 1 in 8,900,000 (text flies in rotated). 3:19-3:20 three-headed dog 1 in 9,500,000: the whole
  backdrop goes DARK (black sky with red eyes) - a darkening grade for evil pets.
- 3:24-3:25 red fox-demon 1 in 10,000,000. 3:26-3:30 Credits: LuLu triple roll: purple-hair pet "1 in 10m".
- 3:34-3:37 crowned sunglasses cube, 3:40-3:43 green slime, 3:46-3:47 fox, 3:51-3:53 and 3:57-3:59 purple demons:
  all 1 in 10,000,000.
- 4:03-4:05 TV-head pet 1 in 10,100,000 (red laser line across the screen on the reveal frame).
- 4:08-4:10 white pegasus 1 in 13,000,000: from here the "1 in N" text is MAGENTA/PURPLE instead of red (text colour
  steps up with rarity: red up to ~10M, magenta ~13M-40M).
- 4:13-4:15 red devil 1 in 15,000,000. 4:19-4:20 red/black spider 1 in 20,000,000 (red fire cloud). 4:24-4:26 purple
  dragon, 4:30-4:32 ice hydra, 4:36 pink pet, 4:40-4:43 jelly, 4:46-4:48 ice phoenix, 4:51-4:53 green cat: all
  1 in 25,000,000. 4:57-4:59 tiki mask 1 in 27,500,000. 5:03-5:04 blue ghost 1 in 31,000,000.
- 5:05-5:10 BLACK TEXT CARD by the YouTuber (yellow glowing text) saying the 1/35M pet was the only one he could not find.
- 5:14-5:16 phoenix 1 in 35,000,000. 5:20-5:22 goggles cat 1 in 37,500,000. 5:26-5:28 and 5:31-5:33 blue compass pet
  1 in 40,000,000 (white shock rings). 5:36-5:39 green goggles pet 1 in 46,000,000 (pink -> gold; a black scythe-like
  shape sweeps across the bottom).
- 5:40.0-5:56 FIRST EGG CUTSCENE: Runic Agony 1 in 50,000,000 (TEMPLATE B, detailed below).
- 5:57-6:10 EGG: Party Panda 1 in 50,000,000 (green circle on a purple reveal).
- 6:11-6:23 EGG: red Christmas pet 1 in 50,000,000 (pink/red pillar reveal).
- 6:24-6:38 EGG: headset cat 1 in 58,900,000 (purple text). 6:39-6:51 EGG: black cat 1 in 50,000,000 (purple
  swirl/smoke reveal).
- 6:52-7:06 EGG, lightning variant (egg crackles with blue lightning then bursts into a white light orb ON the ground
  instead of flying up) -> rainbow penguin 1 in 55,000,000 (yellow text; the glow ring round the pet cycles
  pink -> green -> yellow -> pink -> blue every ~0.25-0.5 s).
- 7:07-7:22 EGG -> rainbow monkey 1 in 55,000,000. 7:23-7:37 EGG -> crowned lion-dragon 1 in 65,000,000 (reveal frame:
  concentric yellow/blue rings like a hypnotic tunnel). 7:38-7:49 EGG -> ice-crystal pet 1 in 65,000,000 (white
  explosion with blue shards). 7:50-8:02 EGG -> electric bunny 1 in 69,000,000 (gold text).
- 8:03-8:18 EGG, falling variant (egg drops from the sky into the shot) -> electric bunny 1 in 69,000,000.
- 8:19-8:31 EGG (crackles + bursts on the ground) -> purple dragon-cat 1 in 80,000,000. 8:32-8:46 EGG -> blue dragon
  1 in 90,000,000. 8:46 one second of another player's autumn world.
- 8:47-9:02 another player's EGG: the egg dimension's sky is YELLOW/ORANGE with sunset clouds (it takes that player's
  world sky), egg hit-flashes pure white at 8:50.5; 8:56.8 the YouTuber zooms his edit into the big text;
  8:57-9:02 TRIPLE reveal: "1 in 400m Night Terror Dog", "1 in 1.2b Huge Ghostface Cat" (centre, much bigger Huge pet),
  "1 in 90m Plague Dragon"; black void with magenta edges, yellow "New!" stickers with stars, then black smoke and a
  yellow fire swirl; white text for 400m/1.2b, yellow for 90m.
- 9:03-9:14 EGG (egg lands, flashes white hard at 9:06 with green-white spikes, floats away) -> candy reindeer
  1 in 90,000,000 (red/white swirl).
- 9:15-9:28 EGG -> Party Penguin 1 in 100,000,000 (cyan/teal energy burst).
- 9:29-9:42 EGG (egg falls in during the fade-up from black: a black dot at top centre) -> Santa-hat ice cat
  1 in 100,000,000 (blue frost burst, gold sparkles). 9:43-9:56 EGG -> purple cat 1 in 100,000,000.
- 9:57-10:09 EGG -> cookie mouse 1 in 100,000,000: the burst throws dozens of COOKIES (themed particles).
- 10:10-10:24 EGG -> Ancient Dragon 1 in 100,000,000 (pink-white explosion).
- 10:25-10:41 "CR: LuLu" EGG -> Bloo Cat 1 in 110,000,000: 10:34.8 the YouTuber zooms in; 10:35.0-10:36.5 the reveal
  background is a BLACK STARFIELD with a green glow at the edges, the pet only a faint silhouette, gold coins rain
  from the top, a yellow "New!" sticker spins top right, and the HUD coin counter counts up (+20,000 -> +100,000 ->
  +153,333 -> +253,333 -> +300,000 -> +446,667); 10:36.8 the pet lights up fully and multi-coloured confetti falls.
  A slow fade-up reveal (1.5-2 s in the dark) instead of an instant burst.
- 10:42-10:55 EGG -> galaxy fox 1 in 120,000,000 (pale white-on-white: hard to see).
- 10:56-11:09 EGG -> blue armoured dragon 1 in 125,000,000 (purple/blue nebula burst).
- 11:10-11:24 EGG -> white pet 1 in 135,000,000: white pet on a white burst; for ~4 s the pet is almost invisible.
- 11:25-11:40 EGG (11:29 the egg flashes pure white, 11:30 a white streak trail as it lifts) -> Black Hole pet
  1 in 140,000,000: background is a PURPLE SPIRAL VORTEX that keeps turning for 4 s (11:36-11:39).
- 11:41-11:53 EGG -> pixel/glitch dragon 1 in 160,000,000 (white/gold).
- 11:54-12:04 another player's EGG (yellow sunset sky) -> 12:05-12:07 TRIPLE reveal: "1 in 90m Plague Dragon" x2 and
  "1 in 175m Nightmare Kraken"; the screen splits into each pet's colour: green toxic cloud left, red spiral right.
- 12:08-12:22 EGG -> neon monkey 1 in 185,000,000 (pink explosion). 12:23-12:36 EGG -> neon cat 1 in 185,000,000.
- 12:37-12:49 EGG (12:47 the number appears small in the world first, then the burst) -> golden angel 1 in 235,000,000.
- 12:50-13:03 EGG -> Pumpkin Spice cat 1 in 250,000,000 (orange-red sphere, then pink-white bloom).
- 13:04-13:18 EGG -> pink jelly bunny 1 in 250,000,000.
- 13:19-13:31 EGG -> Night Terror Cat 1 in 266,000,000: DARK reveal (black/magenta vignette, dark-purple then
  dark-orange radial glow).
- 13:32-13:44 EGG -> blue dragon 1 in 290,000,000 (gold stars round its head). 13:45-13:58 EGG -> white angel
  1 in 333,000,000 (white-gold halo; hard to see on white). 13:59-14:11 EGG -> 1 in 350,000,000 (purple orbs + purple
  crescent swirl; the pet is mostly hidden inside its own effect).
- 14:12-14:25 EGG (a small Roblox notification sits top-centre the whole time) -> Santa cat 1 in 400,000,000
  (snowflakes + gold stars).
- 14:26-14:40 another player's EGG (yellow sky, the egg is seen FALLING from the sky at 14:28) -> TRIPLE reveal (same as
  8:57). 14:36.0 starts on a black frame with a thin white lightning bolt and magenta glow; the numbers are HUGE (the
  "1 in 400m" fills ~1/4 of the screen width) and shrink to normal in ~0.5 s (text punch-in); 14:37.0 black + green,
  14:37.5 grey-white smoke, 14:38.0 yellow-orange fire background; "New!" stickers spin.
- 14:41-14:54 EGG (14:46 blue lightning crackles round the egg) -> red robot 1 in 400,000,000 (pink then red laser beams).
- 14:55-15:12 EGG -> Diamond Dragon 1 in 475,000,000: dozens of gold coins and gold sparkles + ice-blue shards; the reveal
  holds 5 s (15:05-15:09), then 15:10 the player opens the Collection menu over it.
- 15:12-15:27 EGG -> snowflake pet 1 in 500,000,000 (green holly on top, ice-blue).
- 15:27-15:39 EGG (15:31 lightning) -> present-box cat 1 in 500,000,000 (red gift box with gold stars).
- 15:40-15:54 EGG -> jelly monkey 1 in 500,000,000 (green/yellow).
- 15:54-16:08 Credits: OfficialZakLibrary: EGG -> 16:04 their world (different HUD, purple/ice), 16:05 red skull pet
  1 in 500,000,000 (red smoke), 16:07 back to the next common roll "1 in 3".
- 16:09-16:20 Credits: OfficialZakLibrary EGG -> 1 in 500,000,000 (pink/teal); 16:20 "The Index" UI on a common.
- 16:21-16:34 EGG in the NEWER egg stage (purple-magenta sky with pale diagonal SPOTLIGHT BEAMS, green checker floor)
  -> "Ascended" axolotl-cat 1 in 556,000,000 (detail below).
- 16:34-16:49 Credits: Nexik2rree EGG -> 16:46 the player avatar stands in the world in front of a white-gold burst,
  16:47 1 in 625,000,000 (yellow paper-like streaks + white bloom).
- 16:51-17:05 EGG (spotlight stage) -> fiery angel cat 1 in 700,000,000 (orange/red fire tongues + white wings).
- 17:05-17:20 Credits: LeLe: TRIPLE (yellow sky, autumn world): 1 in 175m Nightmare Kraken (red spiral), 1 in 750m
  Nightmare Cat (black, white grin), 1 in 90m Plague Dragon (green), "New!" stickers, big purple counters
  (+20,000 ... +80,000).
- 17:21-17:35 EGG (spotlight stage) -> Sun pet 1 in 778,000,000 (yellow square sun with a white-orange eye; orange
  radial rays and orange rings sweep round it).
- 17:36-17:52 EGG (spotlight stage) -> Subzero Cat 1 in 800,000,000 (white/ice-blue, pink and blue speed lines).
- 17:51-17:52 Credits: RyanBlox clip starts with a "Bonus Roll" pop-up (x1,000 roll, "enjoy a bonus roll on us for
  playing today").
- 17:53-18:22 Credits: RyanBlox: spotlight-stage EGG, frost charge-up 17:59-18:05, white, DISCO ROOM pet stage
  18:06-18:12, white, 18:13-18:21 MULTI reveal of 8+ pets (x1,000 bonus roll), 18:22 back to commons, 18:23 black.

## 2. Cutscene log (one line per cutscene type; all single clips are in the running log above)
From 0:11 to 5:39 every rare is the same short roll reveal (TEMPLATE A, ~50 clips); from 5:40 to 18:22 every rare
is the EGG cutscene (TEMPLATE B, ~45 clips) with variants.
| time | length | what | rarity | VFX 1-5 | leaves world | avatar in it | quality 1-5 | why |
|---|---|---|---|---|---|---|---|---|
| 0:11-0:16 (+ ~50 more to 5:39) | 4.5-5 s each | Template A roll reveal (Silver Stag etc.) | 1/1M-1/46M | 3 | no | no | 2 | fast and readable, identical every time; small step up from a common |
| 0:45-0:49, 1:09-1:13, 3:26-3:30 | ~4 s | other player's TRIPLE roll | 1/1M-1/10M | 3 | no | no | 2 | three pets at once, coin counters tick up |
| 2:25-2:30 | 5 s | roll shown in the live world (WyvernOfHades) | 1/5M | 2 | no | YES (behind) | 2 | pet pops up in front of the player's avatar |
| 5:40-5:56 | ~14 s | Template B EGG: Runic Agony | 1/50M | 4 | YES (egg dimension) | no | 3 | first real cutscene: own place, egg, white-out, silence, burst |
| 5:57-12:49 (~30 clips) | 13-15 s | Template B eggs | 1/50M-1/235M | 4 | YES | no | 3 | same template, colour/theme swaps; some reveals lost in their own VFX |
| 8:47-9:02, 11:54-12:08, 14:26-14:40, 17:05-17:20 | ~14 s | other players' egg + TRIPLE reveal (Huge 1/1.2b) | 1/90M-1/1.2B | 5 | YES | no | 4 | split-screen colour per pet, text punch-in, New! stickers |
| 10:25-10:41 | 16 s | egg -> Bloo Cat dark starfield reveal | 1/110M | 3 | YES | no | 4 | slow fade-up in darkness, coin rain, counter ticks |
| 11:25-11:40 | 15 s | egg -> Black Hole pet, spinning vortex backdrop | 1/140M | 4 | YES | no | 4 | backdrop IS the pet's theme |
| 12:50-16:20 (~16 clips) | 13-15 s | Template B eggs (some lightning variants) | 1/250M-1/500M | 4 | YES | no | 3 | same timing; white pets hard to see |
| 16:21-17:52 (5 clips) | 13-16 s | Template B in the NEW spotlight stage | 1/556M-1/800M | 4 | YES | no (16:46 yes) | 3 | purple sky + spotlights, otherwise same |
| 17:53-18:22 | 29 s | RyanBlox: frost egg -> DISCO ROOM pet stage -> x1,000 multi-reveal | rare (number not readable) | 5 | YES (themed room) | no | 4 | the pet has its OWN themed room before the card |

## 3. Cutscenes in detail

### TEMPLATE A: the short roll reveal (example 0:11.0-0:15.8 Silver Stag 1 in 1,000,000; ~4.8 s)
Game footage (Pets Go roll view); the YouTuber's caption text sits over the bottom.
1. Beats:
   - 0:11.0 hard cut in from the previous clip with motion blur (YouTuber edit).
   - 0:11.3-0:11.8 SLOT CYCLE: the cube pet at centre swaps every ~0.25 s (dog "1 in 5" -> yellow dog "1 in 3" with a
     green glow -> peach dog). Sound: bright MID/HIGH chime per swap (MID -14, HIGH -23 dB at 0:11.5).
   - 0:11.8-0:13.3 WHITE-OUT BUILD (1.5 s): the last common stays, scales up slightly, and a white veil grows over the
     whole screen until everything is ~80% white (pet and HUD are pale ghosts). Sound: a flat shimmering riser
     around -27 dB in all bands, SUB climbing -42 -> -28 dB.
   - 0:13.4 BURST (straight cut, no extra flash frame): a pink-white RADIAL BURST: white core, pink ring, ORANGE
     radial speed-line rays to the edges; the new pet appears as a white silhouette.
   - 0:13.4-0:13.8 TEXT FLY-IN: "1 in 1,000,000" (red with a white outline, chunky rounded font, ~1/12 screen high)
     enters from lower left, big and tilted about -30 deg, rotates to level and settles under the pet in ~0.4 s;
     the pet's name ("Silver Stag", small white text) under it.
   - 0:13.6-0:15.3 HOLD: the pet (white cube stag, gold antlers) at centre, soft pink glow behind, ~10 gold 4-point
     twinkle stars popping in and out round it, the sky/bunting backdrop returns, white rays turn slowly behind.
     Sound: a soft bass swell, SUB -22 -> -20 dB held ~2 s while HIGH falls (-33 -> -50): a warm low "bwoom" bloom,
     NOT a sharp hit.
   - 0:15.3 the YouTuber cuts away.
2. VFX 3/5: one radial burst + gold twinkles + glow. Not cluttered; the pet reads at once (except white pets).
3. Scenery: does not leave the game; full-screen roll card over a sky backdrop that follows the zone.
4. Camera: none (fixed view; the pet is a 3D model centred, ~1/3 screen high). Only scale pops (+10%) on each swap
   and on the reveal.
5. Theme variants (0:21-5:39): burst colour = pet theme (pink default; orange fire; black smoke for skeleton/reaper
   1:44-1:51; red/black cloud for demons 2:00; green for Christmas/forest 2:17, 2:50; white/blue for ice 2:22; brown
   dust + white shock ring 2:34); themed thrown items (candy canes 0:51, cookies 9:57); evil pets darken the whole
   backdrop (3:19 black sky with red eyes).
6. Rarity inside Template A: only the text colour changes (red to ~10M, magenta 13M-46M); length stays ~4.5-5 s.
   1/1M and 1/46M look almost the same.
7. Characters: none. 8. End: the card just holds; no buttons. 9. Feels cheap after the 10th one; the white-out
   build is the only suspense. 10. Other players: not shown.

### TEMPLATE B: the EGG cutscene (1 in 50M and rarer)
Main example 5:40.0-5:55 "Runic Agony" 1 in 50,000,000. Game footage; the YouTuber trims the ends.
1. Beats (0.25 s steps, 0.1 s round the burst):
   - 5:40.0-5:40.9 TRIGGER: an ordinary roll (pink bunny "1 in 4", dog "1 in 5", orange dog "1 in 3"); nothing says
     it is rare yet.
   - 5:41.0 ONE FULL-SCREEN WHITE FRAME (~0.1-0.2 s) with a deep BOOM (SUB jumps +40 dB to -19 dB; mix -23).
   - 5:41.3-5:43.6 BLACK SCREEN 2.3 s with a few tiny white specks. The boom decays (-23 -> -35 dB by 5:42.5), then
     5:43.3-5:44.1 dead silence.
   - 5:43.8 FADE UP (0.25 s, through a grey haze) into the EGG DIMENSION: flat endless green checkerboard floor, pale
     blue-white sky, horizon ~40% from the top, nothing else. No avatar, no HUD.
   - 5:44.3-5:44.5 THE EGG ARRIVES: a glossy black egg with a big rainbow-gradient "?" (cyan-green-blue-pink) slams in
     close to the camera (~45% of screen height) with a low thud (5:44.5, SUB -26 dB), and settles back to ~35% by
     5:44.8 (squash/bounce + small pull-back).
   - 5:44.8-5:47.0 THE WOBBLE (~2.2 s): the egg rocks left/right (~10-15 deg), PULSES toward the camera (5:45.5 back up
     to ~45% with a second thump, mix -27), and at 5:45.8 and 5:46.8 a white-yellow glow flashes behind it with a white
     streak and a small shake. Sound: thumps around -27/-34 dB, MID/HIGH crackle.
   - 5:47.0-5:47.5 LIFT-OFF: the egg shrinks fast as it flies up and away (5:47.3 ~10% height in the upper third), the
     sky warms slightly near it. Sound: a whoosh up to -25 dB (5:47.5).
   - 5:47.8-5:50.4 FULL WHITE-OUT 2.7 s (pure white). Sound fades -27 -> -52 dB, then ~1 s of total silence.
   - 5:50.5-5:51.5 the white fades down to the player's own world (snowy zone, orange buildings, HUD back on the left);
     nothing happens for ~1 s.
   - 5:51.6 BURST + NUMBER ON THE SAME FRAME: a magenta energy ORB (~half the screen) at centre with "1 in 50,000,000"
     (magenta, white outline) already under it; 5:51.7-5:51.8 the orb becomes a dense ball of purple lightning/static;
     5:51.9 the pet's dark silhouette appears inside a dark-purple circular vignette; 5:52.0-5:52.2 the pet (dark purple
     cube, glowing white eyes, horns) is lit inside a purple ring with lightning wisps; 5:52.5 a pale shock ring expands
     to the screen edges. Sound: from silence the loudest hit of the clip at 5:51.7 (mix -20, SUB -17/-19 dB), a second
     hit at 5:52.1, then 1.5 s of decay (-30 at 5:52.8, -52 at 5:53.3).
   - 5:52.5-5:54.5 HOLD ~2-3 s: pet pulsing in its aura over the world, name under the number. Then cut.
2. VFX 4/5: white frame, black hold, egg glows/flashes, full white-out, then a big themed burst (orb, lightning,
   ring). Clean until the burst; the burst is busy but the pet reads within ~0.4 s for dark/colourful pets.
   CLUTTERED for pale pets: 10:42 galaxy fox, 11:10-11:24 white pet (almost invisible ~4 s), 13:45 white angel,
   13:59-14:11 pet hidden inside its own purple orbs.
3. Scenery: leaves the world for a blank "egg dimension" (green checkerboard + plain sky). In other players' clips the
   sky is their zone's (yellow/orange sunset at 8:47, 11:54, 14:26). Newer version (16:21+): a STAGE with a
   purple-magenta sky and pale diagonal spotlight beams. The reveal happens back in the world, over the live scene.
   Scale: the egg is big and close; no giant figures.
4. Camera: one continuous eye-level shot, camera about one egg-height above the floor, egg slightly below centre; the
   motion is the EGG (slam in, bounce, pulses toward camera, wobble, fly away) plus small shakes on flashes. Edit
   rhythm: white frame -> black -> fade up -> egg shot -> white -> fade to world -> reveal card (no camera move).
5. Sound: BOOM on the white frame -> silence on black -> thud when the egg lands -> crackles/thumps in the wobble ->
   whoosh as it flies -> fade out in the white -> silence -> the loudest hit exactly on the reveal frame.
   Measured across ALL eggs in my range (script over 5:30-18:24): 38 of the game's own egg reveals have 2.25-2.5 s of
   near-silence (below -60 dB) right before the hit, and the hit peaks at mix -17 to -20 dB, SUB -16 to -20 dB every
   time (5:51.8, 6:07.8, 6:22.0, 6:35.5 ... 16:31.0, 17:00.5, 17:31.5, 17:46.0). It is that regular, so it is the
   game's design, not the YouTuber's editing. Example 16:29.0-16:31.0: -73, -79, -94, -116, then -120 x4, then -19 dB.
6. Characters: none; no NPC, voice or text box.
7. Ending/unlock card: the number "1 in N" (chunky rounded font, white outline, colour by rarity: magenta at 50M,
   yellow/gold 55M-69M, white from ~100M) with the pet's name in small white text under it, centred under the pet,
   the HUD stays; no buttons; 2-5 s. A yellow "New!" sticker with stars sits top-right of new pets (8:57, 10:35, 14:37).
8. Over-the-top / cheap vs epic: the cutscene is the same for 1/50M and 1/800M (only the burst theme changes), so by
   the 20th egg it feels routine. The epic ones: themed reveal backdrops (black-hole vortex 11:36, dark starfield
   10:35, split-colour triple 12:05), coin rain + counters, the text punch-in (14:36), the pet's own room (18:06).
9. Other players: not shown in my range (no chat or server messages visible).

### TEMPLATE B second example: spotlight-stage egg 16:21.0-16:33.5 ("Ascended" pet 1 in 556,000,000)
- 16:21.0 white flash + BOOM (SUB -19 dB), 16:22.0-16:22.8 black (near silence -95 dB at 16:23.0).
- 16:23.0 fade up into the stage: purple-to-magenta sky with 5-6 pale white/pink diagonal spotlight beams fanning
  down from the upper left and right, green checker floor; 16:23.5 empty for 0.3 s.
- 16:23.8 egg slams in big (~50% height) with a white ground-smoke ring and thud (16:23.8 BOOM, mix -30).
- 16:24.0-16:26.0 wobble; 16:24.8 a rainbow-edged white light flares at the edges of the screen; 16:25.0 a thin purple
  lightning crack across the egg; 16:25.3-16:26.0 small pulses, egg slowly shrinking (camera pulling back / egg rising).
- 16:26.3-16:26.8 lift: egg rises to upper centre, small.
- 16:27.0 the egg turns into a white glowing ORB (~60% of screen) with rainbow lens streaks at the edges (hit at
  16:26.9, mix -21), 16:27.3-16:29.8 full white 2.5 s, sound fading -27 -> -97 dB, 16:30.0-16:30.8 dead silence.
- 16:30.0-16:30.8 white fades to the player's world (pale, washed).
- 16:31.0 REVEAL: blue-white cat with ice-blue feather wings and a gold halo, green base, white star burst with
  pink/teal speed lines; text "1 in 556,000,000"; 16:31.3 one frame almost all white (a second flash pulse), 16:31.5
  back; 16:31.8-16:33.0 hold with white feather sparkles; small blue "unlock" labels appear right of the pet at 16:32.
  Sound: -120 dB -> -19 dB (SUB -18) on 16:31.0, decay to -50 by 16:32.5.
- 16:33.3 next common ("1 in 7", "1 in 2", "1 in 4") over another player's world.
- VFX 4/5. Camera: same as Template B. Length ~12.5 s.

### Template B variants seen in my range
- Lightning egg (6:52-7:06, 14:46, 15:31, 16:25): thin cyan/purple-white bolts crackle round the egg for ~0.5 s each
  during the wobble, with a white-yellow ground glow; the egg can burst into a white light orb ON the ground instead
  of flying up.
- Falling egg (8:03, 9:29-9:45, 14:28): the egg drops from the sky into the shot (black dot at top centre, then lands).
- Frost egg (17:59-18:05, RyanBlox): over ~4 s blue ice crystals grow over the egg until it is encased and the whole
  screen washes pale cyan, then white - a 4 s charge-up, twice the normal wobble.
- Pet-themed room (18:06-18:12, RyanBlox): after the white-out, a DISCO ROOM (rainbow light-up dance floor, two big
  speakers with blue neon rings, purple walls); the pet (black spiky ball with pink shutter shades) stands in the middle
  facing camera ~3 s, white light rays burst from behind it (18:10), it turns into a white glowing shape (18:11-18:12)
  and the screen whites out, then the multi-reveal card. Static wide shot at eye level. The sound here is loud steady
  LOW/MID (-11 to -17 dB) = probably the clip-maker's music, so it is not evidence of the game's sound. The YouTube
  channel badge "RyanBlox / Subscribe" pops up at the bottom (clip-maker's edit).
- Dark reveal (10:35-10:37 Bloo Cat, 13:29-13:30 Night Terror Cat): black background (starfield, or black with
  magenta/orange glow), pet starts as a dim silhouette and lights up over ~1.5 s, gold coins rain, coin counter ticks.
- TRIPLE / multi reveal (8:57, 12:05, 14:36, 17:16, 18:13): 3 pets side by side (Huge pet in the middle, ~1.5x
  bigger), each with its own "1 in N", background split into each pet's colour, "New!" stickers spinning, big purple
  counters. 14:36.0: numbers start huge and shrink in ~0.5 s, the biggest hit in my range (from -120 dB silence to
  mix -13, SUB -18; earlier 14:25.8 another -> mix -4, SUB 0 on another player's clip, likely their music).

## 4. Patterns across my cutscenes
- Two tiers only, with a sharp line: up to 1/46M = ~5 s Template A (white-out + burst, never leaves the roll card);
  from 1/50M = ~13-15 s Template B (leaves the world, egg, white-out, silence, burst). Inside a tier, rarity only
  changes text colour and the burst theme, so a 1/800M egg plays almost like a 1/50M one. A missed chance to escalate.
- Every rare follows: TELL (white flash) -> HIDE (black 2.3 s) -> TEASE (egg slam + wobble 2-3 s) -> HIDE AGAIN
  (white-out 2.5-2.7 s, fading to silence) -> BANG (themed burst + number on the same frame) -> HOLD 2-5 s.
- White is the transition every time (white frame, white-out, white orb); black only once, right after the trigger.
- Sound: every egg reveal lands from 2.25-2.5 s of silence, at the same loudness every time (mix -17 to -20,
  SUB -16 to -20). The silence does most of the work. Booms sit on the flash frames; the egg has its own thud.
- Themes: the item's theme drives the burst colour, the thrown particles (cookies, candy canes, snowflakes, coins,
  fire), and sometimes the backdrop (black hole, starfield, dark sky, disco room). The best clips are the themed ones.
- The camera barely moves. Motion comes from the object (the egg) and from 2D effects (rays, rings, text fly-ins).
- The player's avatar is almost never in it (only 2:25 and 16:46, in other players' setups). It is about the item.
- Numbers matter: "1 in 556,000,000" in huge outlined text IS the reward screen; coin counters ticking up add to it.

## 5. Ideas for the lava-belt cinematic and other gear (copy the moves in spirit, not the art)
Worth copying:
1. Silence before the hit (all eggs, e.g. 5:50.5-5:51.6 and 16:30.0-16:31.0): cut ALL sound for ~1-2 s before the
   reveal and land the loudest hit of the cinematic on the reveal frame. For the lava belt: total silence for 1-1.5 s
   right after the giant lifter's "stay safe kid" and before he smashes lava and rock together; the SMASH is the
   loudest sound in the whole sequence.
2. Two "tell" hits before you know what you got (5:41.0 white frame + boom, 5:44.5 egg slam + thud): when the crate
   pulls the player in, use a single white frame with a deep boom, then 1-2 s of black, then fade up into the volcano
   dimension. That is the "you're being pulled into another world" beat in ~3 s.
3. A plain, readable "other dimension" (5:43.8: endless floor + one sky colour) and a themed stage for higher tiers
   (16:23 spotlight sky, 18:06 disco room, 11:36 black-hole vortex). For gear: lava world for the lava belt, a frozen
   world for ice knee sleeves, a storm for wrist wraps, a duck pond/bath for a duck-floaty belt. Keep the stage simple:
   one big thing (the volcano) and a clean floor.
4. The object does the acting, the camera stays calm (5:44.3-5:47.5): the egg slams in, bounces, pulses toward the
   camera, wobbles, flies away. For our crate: it slams down, rattles, its lid bulges toward the camera twice with
   thumps, then bursts. Use a few low, steady shots instead of lots of cutting.
5. The reveal number/title arrives WITH the burst, rotated and big, and settles in ~0.4 s (0:13.4-0:13.8), or starts
   huge and shrinks (14:36.0). For "LAVA BELT - LEGENDARY": punch the title in big on the hit frame, shrink it into
   place in 0.4-0.5 s.
6. Themed particles from the item itself (cookies 9:57, candy canes 0:51, snowflakes 14:23, coins 15:05): the lava
   belt reveal should spray small glowing rocks and embers, not generic stars; a duck belt throws rubber ducks.
7. Dark reveal for evil/heavy items (10:35, 13:29, 3:19): darken the background and let the item glow up over 1-1.5 s.
   Good for a "black iron" or "obsidian" belt.
8. Escalate by rarity (the thing Pets Go does NOT do well): rare = short card, epic = short scene, legendary = full
   cinematic with a character. Make each tier clearly longer and louder, and change the scene, not just the colour.
9. Counters and stickers on the card (10:35 coin counter ticking, "New!" sticker 8:57): show "NEW!" when it is the
   first time the player gets that belt, and tick up a collection counter.
10. Keep one recognisable template so players learn it (white flash -> black -> scene -> white -> world -> card), and
    vary only the middle scene per item.

Avoid:
- An item that vanishes in its own VFX: white pets on white bursts (11:10-11:24, 13:45-13:58), pet hidden in its own
  orbs (13:59-14:11). Our gear is small on a cartoon body: put a dark or contrasting backdrop behind the belt at the
  reveal, and keep particles off the item for the first second.
- The same cutscene for every rarity (5:40 vs 16:21: 1/50M and 1/556M feel the same).
- Long full-white holds with nothing happening (5:47.8-5:50.4 is 2.7 s of plain white): fine once, tiring when you see
  it 30 times. Use 1-1.5 s, or put something in it (the giant lifter's silhouette in the glare).
- Reveal backgrounds that fight the item (busy split screens at 12:05 make three pets hard to read).
- Pets Go never shows the player's own avatar; for the lava belt we WANT the player's character in the scene (being
  pulled in, being protected, then thrown out wearing the belt) - that is a step beyond what this game does.
