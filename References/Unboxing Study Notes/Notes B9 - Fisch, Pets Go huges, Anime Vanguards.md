# Batch B9 notes: Fisch (2 videos), Pets Go (1), Anime Vanguards (2)

Study date 2026-11-19. Tool notes for this batch:
- The browser pane screenshots come back at 800 px wide, and "zoom" only crops (it does not add resolution). So
  every 16-frame 1-second grid was viewed at ~200 px per frame, and every detail check was redrawn as 2x2 frames
  (~400 px per frame) or 4x4 at 0.25 s steps. Small UI text (chat, HUD numbers) is not always readable.
- `javascript_tool` times out after 45 s, but `__audioRun` keeps running in the page; I polled until it finished.
- On video 1 the sound pass ran into the end of the video and YouTube autoplayed the next video; the sound data
  for 0:00-1:51 was saved first, then I re-opened the video for the pictures. Later videos: sound runs stop
  0.3 s before the end.

## 1. Videos and coverage log

| # | id | title | length | range studied |
|---|----|-------|--------|---------------|
| V1 | kRRu9RJpeco | 3 *NEW* SECRET CUTSCENE + SHOWCASE! / Roblox Fisch (channel "Bucket") | 1:50.7 | whole, 0:00-1:50.7 |
| V2 | TkJmsP4wFB8 | Every Secret Fish Caught and Cutscene in Marian's Veil / Fisch | 2:18.2 | whole |
| V3 | fehEuD-OYU0 | EVERY HUGE CUTSCENE IN PETS GO | 5:25.2 | whole |
| V4 | w5xdj9kQqVQ | ALL Character Obtainment CUTSCENES / Anime Vanguards (OUTDATED) | 1:45.1 | whole |
| V5 | T_zMREGoFP8 | Every Summon Vanguard In Anime Vanguards Cutscene's | 2:34.1 | whole |

### Coverage log
- V1 sound: `__audioRun(0,111,2)` once, whole video, note "ok" (1275 blocks, series 0:00.1-1:51.0). Events and
  0.5 s table taken for 0:00-1:51.
- V1 captions: auto-captions loaded (the YouTuber talks over nearly the whole video; game sound sits under him).
- V1 pictures: 1 s grids 0:00-0:16, 0:16-0:32, 0:32-0:48, 0:48-1:04, 1:04-1:20, 1:20-1:36, 1:36-1:50 (end) = whole
  video, no gaps. 0.25 s close-ups: 0:14.0-0:34.0 (Crowned Anglerfish cutscene + catch), 0:33.75-0:37.5,
  0:44.5-1:04.25 (Magma Leviathan), 1:14.5-1:34.25 (Frozen Leviathan). 0.1 s on 0:14.9-0:15.2 (the break into
  the scene). 2x2 detail frames at 0:00.5, 0:06, 0:09.2, 0:15.2, 0:20.0, 0:22.5, 0:24.3, 0:25.8, 0:30.2, 0:32.5,
  0:33.0, 0:33.8, 0:33.9, 0:34.0, 0:34.4, 0:34.7, 1:00.2, 1:00.6, 1:01.0, 1:04.2, 1:30.7, 1:31.1, 1:42.5, 1:44.0.
- Nothing missed in V1.
- V2 (TkJmsP4wFB8, 2:18.2, whole) sound: `__audioRun` 0-70, 70-104, 104-137.9, all "ok" (1595 blocks). No captions
  (no transcript; no commentary heard in the data either). Events 0-138; tables at 0.5 s for 0-22, 26-28, 31-46,
  50-52.5, 56-71, 76-79, 84-97, 103-106, 110.5-126, 1 s for 126-138; at 0.25 s for 3-6.5, 28-31, 52.5-56, 79-84,
  106-110.5.
- V2 pictures: 1 s grids 0:00-0:16, 0:16-0:32, 0:32-0:48, 0:48-1:04, 1:04-1:20, 1:20-1:36, 1:36-1:52, 1:52-2:08,
  2:08-2:18 (end) = whole video. 0.25 s close-ups: 0:01.5-0:21.25 (C4), 0:27.5-0:47.25 (C5), 0:51.75-1:11.5 (C6),
  1:11.75-1:35.5 (cast, reel and C7), 1:44.75-2:04.5 (C8). 2x2 detail at 0:05.6, 0:06.0, 0:07.2, 0:10.6, 0:55.2,
  0:56.4, 0:56.9, 0:59.4, 1:19.1, 1:19.2, 1:19.35, 1:19.5, 1:21.1, 1:22.9, 1:23.2, 1:23.6, 1:49.3, 1:50.0, 1:52.4,
  1:52.6. Gap: 1:36.0-1:44.75 (Scylla reel) seen only at 1 s steps; it is the reel, not the cutscene.
- V3 (fehEuD-OYU0, 5:25.2, whole) sound: `__audioRun` 0-66, 66-132, 132-198, 198-264, 264-324.9, all "ok" (3755
  blocks). No captions. Events 0-325.2; tables at 0.25 s for 1.5-7, 13-23, 53.5-60, 71-74, 224-228, 235-242,
  260-263, 292-296, 307-316; at 0.5 s for 7-13, 60-71, 74-84, 96-106, 129-139, 160-170, 188-206, 218-224, 228-235,
  242-260, 316-325; at 1 s for 263-292, 296-307.
- V3 pictures: 1 s grids 0:00-5:25 complete (0:00, 0:16, ... 5:04, 5:18 starts). 0.25 s close-ups: 0:01.75-0:21.5
  (C9 whole), 0:51.75-1:19.5 (C11 whole after the standard part), 1:37.75-1:45.5 (C12 flicker + candy world),
  2:09.75-2:17.5 (C13 castle + dragon egg), 2:41.75-2:49.5 (C14), 3:08.75-3:24.5 (C15 chest), 3:44.75-4:00.5
  (C16), 4:19.75-4:23.5, 4:30.25-4:38.0, 4:52.25-4:56.0, 5:07.75-5:15.5 (C17 transitions). 0.1 s at 2:41.3-2:41.85
  (TV-off), 3:45.4-3:46.0 (meteor), 2x2 at 0:02.6, 0:03.5, 0:04.6, 0:05.1, 0:20.6, 0:20.9, 0:21.3, 0:21.9, 3:55.6,
  3:56.6, 3:57.6, 3:59.0, 4:05.6, 4:06.3, 4:10.6, 4:11.2; chat crop at 4:10.6.
- V3 NOT at 0.25 s (seen only in the 1 s grids): C10 (0:24-0:44, identical to C9), the standard egg openings of
  C11-C17 (each the same 6-8 s as C9), C12 1:31-1:37.5 and 1:45.5-1:54, C13 2:17.5-2:25, C15 3:03-3:08.75, C17
  4:23.5-4:30.25, 4:38-4:52.25 (slow nebula drift), 4:56-5:07.75 (slow galaxy push), and every reveal card except
  C9/C16 (1 s grids show them; they share one layout).
- V4 (w5xdj9kQqVQ, 1:45.1, whole) sound: `__audioRun` 0-66, 66-104.8, "ok" (1212 blocks). Captions loaded (the
  YouTuber's intro line + song lyrics: the track is his music). Events 0-105.2; table at 1 s for 0-105 (not
  broken down further because the measured sound is mainly his song).
- V4 pictures: 1 s grids 0:00-1:45 complete (0, 16, 32, 48, 64, 80, 96). 0.25 s close-ups for 0:04.0-1:43.75
  without gaps (25 sheets: 4, 8, 12, ... 100) and 1:44.0-1:45.05 in 2x2; 2x2 detail at 1:09.2, 1:14.6, 1:21.5,
  1:22.6. Nothing missed.
- V5 (T_zMREGoFP8, 2:34.1, whole) sound: `__audioRun` 0-66, 66-132, 132-153.7, all "ok" (1783 blocks); the last run
  touched the end and YouTube autoplayed another video, but the events and the 0.5 s table for 0-154 were taken
  first (the page keeps its data); then I re-opened the video for pictures. No captions.
- V5 pictures: 1 s grids 0:00-2:34 complete (0, 16, ... 144). 0.25 s close-ups: 0:06.0-0:09.75 (results grid),
  0:12.5-0:16.25, 1:35.5-1:39.25, 1:39.5-1:43.25, 2:07.5-2:34.0 (C37 whole, 7 sheets). Crops at 0:07.6 (results
  grid text) and 2:07.75 (unlock card text); 2x2 at 1:08.3, 1:39.6, 1:49.4, 2:07.8.
- V5 NOT at 0.25 s (1 s grids only): 0:00-0:06, 0:16.25-1:35.5 (C31-C34 except the end of C34; these units were
  covered at 0.25 s in V4 as C22, C24, C25), 1:43.25-2:07.5 (rest of C35 and the shiny repeat of the giant).

## 2. Cutscene log

| # | video | start-end | length | what | rarity | VFX 1-5 | leaves world | avatar in it | good 1-5 | why |
|---|-------|-----------|--------|------|--------|---------|--------------|--------------|----------|-----|
| C1 | V1 | 0:14.9-0:32.4 | 17.5 s (incl. 1.2 s black in, 1.2 s black out) | Fisch: catching the Crowned Anglerfish | "Secret" (per title) | 1 | no (same dark underwater cave, real map) | yes, 3 shots | 2 | Dark, slow, almost no VFX; the fish just swims around in letterbox; reads as "trailer of the creature", but the big crowned fish lunging at the lens on the fade-out is a good first hit |
| C2 | V1 | 0:45.5-1:02.7 | 17.2 s | Fisch: catching the Magma Leviathan | Secret | 2 | no (the lava cavern you fish in) | yes, 4+ shots | 3 | Strong creature: a dragon body with glowing lava cracks sliding past the lens, flame wisps around the player; ends with the body crashing into the camera |
| C3 | V1 | 1:15.5-1:32.9 | 17.4 s | Fisch: catching the Frozen Leviathan | Secret | 2 | no (ice cavern) | yes, 3 shots | 3 | Same template as C2 in ice: a translucent glowing ice serpent; ends with it rising tall in front of the camera |
| C4 | V2 | 0:03.4-0:21.0 (cut by YouTuber) | ~17.6 s | Fisch: Magma Leviathan again, with clean game sound | Secret | 2 | no | yes | 3 | Same scene; sound shows a loud bass bed ~20 dB over fishing |
| C5 | V2 | 0:28.3-0:45.4 | 17.1 s | Fisch: Frozen Leviathan again | Secret | 2 | no | yes | 3 | Bass swell +32 dB in 0.75 s as the picture fades in |
| C6 | V2 | 0:52.8-1:10.0 | 17.2 s | Fisch: Crowned Anglerfish again (gold/white crowned model) | Secret | 2 | no | yes | 3 | Lantern god rays; slow crescendo through the scene |
| C7 | V2 | 1:19.1-1:35.3 | 16.2 s | Fisch: Crystallized Sea Dragon | Secret | 3 | no (acid lagoon) | yes | 4 | Best Fisch beat: the dragon erupts from neon water with god rays; bass hit lands just before it |
| C8 | V2 | 1:45.5-2:04.3 | 18.8 s | Fisch: Scylla | Secret | 2 | no (dark cave) | yes | 2 | Flashy colour-cycling tentacles during the reel, but the cutscene is too dark to read |
| C9 | V3 | 0:02.5-0:19.5 (+reveal to 0:21.9) | 17 s + 2 s card | Pets Go: standard huge hatch, Huge Dog | 1 in 1,000,000,000 | 2 (4 at burst) | yes (green checker void) | no | 3 | Clean template: boom to black, silence, egg pulses every 1.6 s, white-ring burst, white-out, odds card |
| C10 | V3 | 0:24.4-0:42 | ~17 s | Pets Go: Huge Cat, same template | 1 in 1,000,000,000 | 2 | yes | no | 3 | Identical to C9 |
| C11 | V3 | 0:45.7-1:22.5 | ~37 s | Pets Go Halloween: Huge Ghostface Cat | 1 in 1,200,000,000 | 3 | yes (graveyard) | no (but the player's NAME is on the grave) | 5 | Fake-out: standard start, doors slam shut, "RIP <username>" engraved, jump scare, slasher egg |
| C12 | V3 | 1:31.0-1:53 | ~22 s | Pets Go Valentine: yellow huge | 1 in 1,250,000,000 | 3 | yes (candy world) | no | 3 | Picture and sound flicker between normal and a muffled pink heart world |
| C13 | V3 | 2:02.2-2:25 | ~23 s | Pets Go: Huge Dragon | 1 in 1,400,000,000 | 3 | yes (castle builds itself) | no | 4 | Shadow of an unseen giant, castle rises, fire chars the egg, new dragon egg drops in |
| C14 | V3 | 2:33.8-2:55 | ~21 s | Pets Go: Huge Nightmare Corgi | 1 in 1,500,000,000 | 3 | yes (red hell) | no | 4 | Old-TV switch-off, silence, giant eye, red world |
| C15 | V3 | 3:03.2-3:30 | ~27 s | Pets Go: Huge Jelly, CHEST variant | 1 in 1,500,000,000 | 5 at peak | yes | no | 3 | Gold chest slams over the egg, held silence, jellies flood out (cluttered) |
| C16 | V3 | 3:38.0-4:05 | ~27 s | Pets Go: Huge Inferno Cat, LAVA variant | 1 in 1,800,000,000 | 1 then 4 | yes (void, then lava land with volcanoes) | no | 5 | Meteor hits the lens, dark void with only bass and approaching eyes, then a loud lava world |
| C17 | V3 | 4:13.3-5:20 | ~62 s | Pets Go: Huge Cosmic Axolotl, SPACE | 1 in 5,000,000,000 | 2 (4 at end) | yes (space, galaxy, moon base) | no | 3 | Rarest = longest; grand scale but 40 s of slow drifting |
| C18 | V4 | 0:04.3-0:11.2 | 7 s | Anime Vanguards intro: pink-haired suited unit | not shown | 5 | yes (void) | no | 4 | Pink energy ring, impact frames, held hero pose with speed lines |
| C19 | V4 | 0:11.3-0:17.9 | 6.6 s | AV: red-haired muscular fighter | not shown | 5 | yes (space) | no | 4 | Lands fist-first, close-up eyes, gold light pillar into space |
| C20 | V4 | 0:18.0-0:27.3 | 9 s | AV: dark shadow unit | not shown | 5 | yes (void) | no | 3 | Purple flame vortex, greyscale glitch frames |
| C21 | V4 | 0:28.0-0:31.8 | 3.8 s | AV: white-haired robed unit | not shown | 2 | yes (space) | no | 2 | One calm orbit |
| C22 | V4 | 0:32.0-0:37.0 (+0:48.8-0:52.2) | 5 s | AV: horned woman | not shown | 3 | yes (dark) | no | 4 | Body parts materialise one by one, then the eyes open |
| C23 | V4 | 0:37.3-0:48.5 | 11 s | AV: unit with orbiting blades | not shown | 3 | yes (space) | no | 3 | Floating weapons, slow orbits |
| C24 | V4 | 0:52.3-1:05.4 | 13 s | AV: hooded skull-mask unit | not shown | 3 | no (game map) | YES | 1 | 12 s of the same over-the-shoulder frame |
| C25 | V4 | 1:05.5-1:23.4 | 18 s | AV: giant buff axe warrior | not shown | 4 | no (game map, sky turns orange) | YES | 5 | Fireball from the sky, giant towers over the tiny player avatar, ends on his flexing back |
| C26 | V4 | 1:23.5-1:31.2 | 7.7 s | AV: bald hero, gold aura | not shown | 4 | yes | no | 3 | White strobe, low angles, handheld shake |
| C27 | V4 | 1:31.3-1:41.0 | 9.7 s | AV: lime-green berserker | not shown | 5 | yes | no | 3 | Silhouette impact frame, green radial beams |
| C28 | V4 | 1:41.3-1:45.1 (cut) | 3.8 s+ | AV: red-hat gunman | not shown | 3 | yes (pink sky) | no | 4 | His name written into the spinning magic seal |
| C29 | V5 | 0:00-0:06.3 (+grid 0:06.5-0:08.0) | 6.3 s | AV: pink suited unit + normal 10x results grid | gold/pink tile | 5 | yes | no | 4 | Shows the order: rare intro first, then the result tiles pop in |
| C30 | V5 | 0:08.3-0:15.9 | 7.6 s | AV: red-haired fighter (player's recording) | - | 5 | yes | no | 4 | Same as C19 |
| C31 | V5 | 0:17.0-0:47.5 | 30 s (2 recordings) | AV: horned woman | - | 3 | yes (purple space) | YES | 4 | The player's avatar stands in the summon scene while the unit looms huge |
| C32 | V5 | 0:48.0-1:08.0 | 20 s | AV: horned woman, second player + results grid | - | 3 | yes | YES | 3 | Ends on "Rewards obtained:" |
| C33 | V5 | 1:09.0-1:20.0 | 11 s | AV: skull-mask unit | - | 3 | no | YES | 1 | Static |
| C34 | V5 | 1:20.5-1:39.5 | 19 s | AV: giant axe warrior, player's view | - | 4 | no (sky turns orange) | YES | 5 | Avatar looks up at the sky, giant towers behind it, back flex |
| C35 | V5 | 1:39.5-1:49.5 | 10 s | AV: blue ice unit | - | 3 | yes (blizzard) | YES (close-up face) | 3 | The player's face is the hero shot |
| C36 | V5 | 1:50.0-2:07.8 | 18 s | AV: giant, SHINY gold version + unlock card | Shiny / Vanguard | 4 | no | YES | 5 | Gold recolour = extra tier; unlock card layout visible |
| C37 | V5 | 2:08.0-2:33.0 | 25 s | AV: skeletal overlord on a throne | - | 5 | yes (palace) | yes (first 6 s) | 4 | Throne room, magic circle, ends cluttered |

## 3. Cutscenes in detail

### V1 general: what a normal Fisch catch looks like (seen 0:00-0:14.8, 0:44.5-0:45.3, 1:13-1:15.5)
- Third-person camera behind the avatar, who stands on a ledge holding a rod (here a glowing cyan spear-like rod).
  Bottom centre: the REEL bar, a long thin white/black horizontal bar with a moving white segment and an arrow
  marker; a small "progress" bar under it. The player keeps the fish inside the white segment until progress fills.
  Other players stand nearby; chat log top left, a leaderboard top right, money "17,700,570 C$" bottom right.
- Boss-type fish: the Crowned Anglerfish was already swimming next to the player during the reel (0:00-0:14), a
  big flat brown fish with a glowing green lantern; a red/orange world prompt "Feed To Take Lantern" floats above.
- The catch itself, for a normal fish, is the bar filling and the fish being held up by the player (not shown in
  full here). For these three secret fish the moment the bar fills, the screen goes straight to the cutscene: no
  pause, no UI flourish. Caption at 0:15: "bang oh wait it has a cut scene" (the YouTuber did not expect it).
- After the cutscene, the avatar is back on the ledge holding the catch; the YouTuber then opens the inventory
  and equips the fish: it is held up over the avatar's head at full size (0:33.9-0:34.7 the Crowned Anglerfish
  fills the left half of the screen, far bigger than the player; 1:04.0-1:05 the Magma Leviathan; 1:40-1:50 the
  Frozen Leviathan, a 40+ stud serpent arching over a tiny player). Scale gag: tiny player, huge trophy.

### C1. Crowned Anglerfish (V1 0:14.9-0:32.4, 17.5 s, game footage; YouTuber's title card "Crowned Anglerfish" at 0:00-0:02 is his edit)
1. What: Fisch secret catch, Crowned Anglerfish. First frame 0:14.9 (fade starts), last 0:32.4 (game back).
2. Beats: 0:14.8 reel bar full -> 0:14.9 a much bigger golden "crowned" anglerfish (white-gold body, spiky
   gold fins like wings, a crown and a lantern) appears huge, half-transparent, in the upper half of the screen,
   lunging at the lens, with a few white sparkles round the player, while the whole picture fades to black over
   0.5 s (0:14.9 visible -> 0:15.2 nearly black). 0:15.5-0:16.6 pure black (1.1 s). 0:16.7 fade in, letterbox bars
   appear (black bars top and bottom, about 1/8 of the height each). Shot A 0:16.7-0:19.3: dark navy underwater
   cave, the anglerfish (normal brown model) swims left to right away from camera, getting smaller, its green
   lantern bobbing; camera nearly static. Shot B 0:19.4-0:24.2: the player avatar on a rock ledge, high angle, slow
   push-in/drift; 0:21-0:22 a green glow, 0:22.5 low-angle close-up looking up at the avatar holding the rod up (rod
   glows cyan); 0:23-0:24 the camera keeps drifting around him (handheld feel). Shot C 0:24.3-0:27.4: wide, the
   avatar tiny on a ledge, then the fish swims out of the dark straight at the camera, mouth open, until it fills
   the frame (0:27.0-0:27.3). Shot D 0:27.5-0:29.6: close over-the-shoulder of the avatar raising the rod, camera
   pulling back. Shot E 0:29.7-0:30.7: wide, very dark, only the glowing lantern (a cyan dot) drifting in from the
   left towards the avatar (a ghostly purple silhouette with a red name tag). 0:30.8 fade to black, 0:31.0-0:32.1
   black (1.1 s). 0:32.3 fade back to normal play: the avatar stands inside a pale green-cyan glowing sphere
   (catch aura) for ~1 s, a green "...has a chance..." message line bottom centre.
3. VFX: 1/5. Almost none: one sparkle cluster at the break, the lantern's glow, the cyan rod glow, the green aura
   at the end. No flashes, no shake. Colour: the whole scene is the map's normal dark navy. Clean but flat.
4. Scenery: does NOT leave the world; it is the same cave the player is fishing in, filmed with cinematic shots.
   Scale: fish is ~2-3 times the avatar's size; no giant tricks except the lunge at the lens.
5. Camera: 5 shots, each 1-5 s, all cuts are hard cuts inside the letterbox; mostly slow drifting moves, one
   low-angle hero shot of the avatar (0:22.5), one "creature charges the camera" (0:26-0:27.3). Player avatar is in
   3 of 5 shots, doing only an idle with the rod raised (no special animation).
6. Sound: the YouTuber talks over most of it (captions 0:15 "bang oh wait it has a cut scene", 0:24 "scene wait
   that's crazy", 0:29 "[Music]"). Where he is quiet the game bed is a LOW, bass-heavy drone: 0:17.5-0:19.5 and
   0:27-0:31.5 MIX -29 to -35 dB with SUB about equal to MIX (-28 to -36) and HIGH -43 to -50 (dark rumble, no
   sparkle). RISER detected 0:23.0-0:24.5 (gets louder and brighter, into the wide shot / fish charge). Black
   frames 0:15.5-0:16.6 are not silent: -29 to -32 dB drone continues across the black (no sound gap). 0:31.8 -38 dB
   (quietest point, during the black), then 0:32.3 SUB jumps to -20 (BOOM +15 at 0:32.2) and 0:32.5 a bright HIGH
   spike (-16 dB while LOW drops to -39): the catch "ding"/splash lands exactly on the return to the game.
7. Characters: only the fish; it swims, charges the lens; no voice, no text.
8. Ending: fade to black, then back to normal play with a short aura on the avatar and a chat line. No unlock card
   at all (Fisch uses its normal catch UI and the held fish).
9. Feels: serious and moody, not funny. Cheap parts: dark map, the fish model is the same low-detail one used in the
   fight, other players' noob avatars wander through the letterboxed shots (0:21.5-0:24.3, a yellow/green avatar
   walks into frame), which breaks the "movie" feeling.
10. Others: other players are visible in the shots (the cutscene is only on the catcher's screen; the others just
   keep standing in the world).

### C2. Magma Leviathan (V1 0:45.5-1:02.7, 17.2 s; YouTuber title card "Magma LEVIATHAN" 0:39-0:41)
1. What: Fisch secret, Magma Leviathan, caught in a lava cavern (orange lava lake, red-brown rock, yellow lava
   spikes). First frame 0:45.5, last 1:02.7.
2. Beats: 0:45.3 reel still running -> 0:45.5 UI hides and picture fades to black in 0.4 s; 0:46.0-0:47.1 black
   (1.2 s). 0:47.3 hard cut (no fade) to letterbox shot A 0:47.3-0:49.9: low camera next to a yellow lava spike,
   the leviathan (a black dragon/serpent with glowing orange-yellow cracks, a crest of black spikes along its back
   and a horned head) slides past the lens left to right; its head with spiky horns rises at the top of frame
   (0:48.5-0:49.8). Shot B 0:50.0-0:50.4: wide, low angle along a rock ledge, the avatar tiny on it. Shot C
   0:50.5-0:54.7: high-angle medium on the avatar and a second player standing on a rock, camera orbiting slowly;
   orange flame wisps / tongues of fire curl up around them (0:52.5-0:54.5). Shot D 0:54.8-0:57.9: wide, the lava
   lake, the avatar small on a ledge, slow pan. Shot E 0:58.0-0:59.9: medium on the avatar from the side, rod up.
   Shot F 1:00.0-1:01.2: the leviathan rears up behind the two players as a big dark silhouette with glowing cracks
   (1:00.2), then its body sweeps into the camera (1:00.6 frame full of dark scaled body, 1:01.0 glowing cracks
   fill the frame) as the picture fades to black. 1:01.3-1:02.6 black (1.3 s). 1:02.8 fade back into normal play.
3. VFX: 2/5. Flame wisps around the avatar, glowing lava cracks on the creature, the lava lake glow. No flashes, no
   shake, no text. Not cluttered.
4. Scenery: same lava cavern the player fishes in; the leviathan is the only "set piece". Scale: head and body
   larger than the camera frame at the end.
5. Camera: 6 shots of 0.4-4 s, hard cuts; moves are slow drifts/orbits; the strongest move is the creature
   hitting the lens to end it (an "eaten by the monster" cut to black). Avatar in 4 of 6 shots, idle with rod up.
6. Sound: the YouTuber talks over shots C-E ("what the heck all right all right that's cool"). Clean game bed at
   0:45.3-0:47.0 (-34 to -38 dB, SUB = MIX, a low rumble through the black) and 0:59.8-1:02.0 (-30 to -37 dB, SUB
   -29 to -35, MID -42 to -47, HIGH -47 to -50: a deep drone that does NOT peak at the creature's lunge). Back to the
   game at 1:02.3: mix jumps +17 dB (HIT 1:02.3, BOOM 1:02.4 +11 dB bass) = the catch sound lands on the return.
7. Characters: the leviathan; slides, rears, lunges; no voice.
8. Ending: creature lunges into camera -> black -> back to play. No card.
9. Feels: the "creature crashes into the lens" ending is a good punch; the rest is slow.
10. A second player is visible beside the catcher in the cutscene shots.

### C3. Frozen Leviathan (V1 1:15.5-1:32.9, 17.4 s; YouTuber title card "Frozen LEVIATHAN" 1:13-1:15)
1. What: Fisch secret, Frozen Leviathan, ice cavern (pale blue snow floor, translucent blue ice spikes and walls).
2. Beats: 1:15.3 a translucent ice serpent shape is already visible behind the avatar while the reel bar is still
   up -> 1:15.8 fade to black (0.4 s); 1:16.0-1:17.3 black (1.3 s); 1:17.5 fade in to letterbox shot A 1:17.5-1:20.4:
   the serpent (glassy blue, crystal spikes along its back, glowing bright-blue spine) slithers along the snow
   past a low camera, then away up a slope. Shot B 1:20.5-1:24.9: the avatar on an ice ledge, high angle then
   tilting/orbiting round him; a green glow from his rod. Shot C 1:25.0-1:28.2: wide, ice cavern; the serpent's thin
   bright-blue body weaves between ice spikes in the distance. Shot D 1:28.3-1:30.4: medium-close on the avatar,
   rod up. Shot E 1:30.5-1:31.2: the serpent rises straight up in front of the camera, camera tilting up to follow
   it (a towering S-shape), fade to black from 1:31.3. 1:31.8-1:32.8 black. 1:33.0 back to play.
3. VFX: 2/5 (glow of the serpent's spine, translucent ice). Colour is all blue/white. Clean.
4. Scenery: the same ice cavern. Scale: the serpent rising tall over the camera at the end.
5. Camera: 5 shots, 0.7-4.4 s, slow drifts/tilts; best move = tilt-up as the serpent rises (1:30.5-1:31.2).
6. Sound: YouTuber talks at 1:15-1:16 and 1:26-1:31. Black 1:16.8: -35 dB; letterbox start 1:17.3: SUB -23 jumps
   (+12 dB vs the black) with MID/HIGH staying low (-40/-43): a low rumble/whoosh as the serpent slides in. Shots
   1:17-1:29: MIX -25 to -33, SUB -25 to -32 = steady bass drone. End: 1:31.3-1:32.3 -26 to -33 dB, again no
   sting, then the catch sound with the game's return 1:32.8 (-17).
7. Characters: the serpent only.
8. Ending: rises -> black -> play. No card.
9. Feels: the same template three times (black in, letterbox, 5 slow shots, creature at the lens, black out).
   The YouTuber at 1:26: "all the cut scenes are different... that was an okay cut scene, that wasn't that bad".
   Lukewarm reaction to a long cutscene with no reward card.
10. Nothing server-wide visible.

### V2 general (TkJmsP4wFB8 "Every Secret Fish Caught and Cutscene in Marian's Veil", channel zmrhabeplayz, 2:18.2)
- No captions, no commentary: the sound here is the game's own (best sound data for Fisch in this batch).
- The YouTuber adds a name label in each cutscene: a cartoon bold font with a soft outer glow, centred in the lower
  middle, colour matched to the fish (cream-yellow "Magma Leviathan", white-blue "Frozen Leviathan", yellow
  "Crowned Anglerfish", purple-pink "Crystallized Sea Dragon", silver-white with red shadow "SCYLLA"). It pops on
  0.5-1.5 s after the letterbox appears and stays 4-5 s. I judge it the YouTuber's edit: V1 shows the same game
  cutscenes with no title, and it sits over the game's letterbox like an editor's caption.
- Normal Fisch fishing (seen 1:10.3-1:19.0): the avatar casts with a power meter ("MAX!" label over the head,
  1:11-1:14); a bobber sits in the water; the reel minigame appears at the bottom (1:14.5): a long white bar with a
  moving marker, a progress bar under it; the hooked fish's model thrashes in the water next to the avatar (the
  Crystallized Sea Dragon's spiky dark-blue/pink body 1:15.5-1:19.0, Scylla's colour-cycling tentacles blue -> pink
  -> yellow -> green -> cyan 1:37-1:45). On success the fish leaps out at the camera and a small white "PERFECT
  CATCH!" text appears in the centre (1:19.2), then the secret cutscene fades in. For a normal fish the leap +
  "PERFECT CATCH!" + the fish in the hand is the whole reward.
- After the cutscene the YouTuber cuts away; at 2:05-2:16 he equips each secret fish: every one is held up over the
  avatar's head at enormous size (a green-gold dragon, the orange Magma Leviathan, the blue Frozen Leviathan, the
  rainbow Crystallized Sea Dragon, the gold Crowned Anglerfish), one per second. Ends 2:16-2:18 fade to black.

### C4. Magma Leviathan, second recording (V2 0:03.4-0:21.0+, ~17.6 s shown, the YouTuber cuts at 0:21.0)
1. Same fish as C2, different player, music audible. 0:00-0:03.3 normal reel in the lava area (avatar with spiky
   white hair, a rod with a pink tip, reel bar). 0:03.5 catch; 0:03.8 fade to black (0.4 s); 0:04.0-0:05.3 black.
   0:05.5 fade in, letterbox. Shot A 0:05.5-0:09.4: the leviathan's spiky head and cracked glowing body sliding
   across, sun-ray streaks behind it (0:07.0-0:07.8 white light rays fanning out from behind the body). Shot B
   0:09.5-0:12.5: the avatar on a rock among flame tongues, camera orbiting fast round him (a near full half-orbit in
   3 s). Shot C 0:12.5-0:16.0: low close angle against a rock wall and a yellow lava spike (the body passing).
   Shot D 0:16.3-0:18.0: the avatar seen from below, lava cracks glowing behind. Shot E 0:18.3-0:19.5: lava cracks
   rush into the lens, fade to black 0:19.3-0:19.8. 0:21.0 the YouTuber cuts to the next fish.
2. VFX 2/5: flame tongues, lava cracks, light rays. Scenery: in-world lava cavern.
3. SOUND (game, no talk): fishing 0:00.5-0:03.3 MIX -45 -> -34 (quiet ambient, MID/HIGH lead). 0:03.5 catch BOOM
   +28 dB (SUB -48 -> -20) = a deep impact on the catch frame. 0:04.5 dip -33 in the black. 0:05.0 second BOOM (SUB
   -19) as the picture fades in. 0:05.5-0:20.0 the cutscene bed is LOUD and flat: MIX -11 to -18 the whole time,
   SUB equal to MIX (-11 to -17), MID -20 to -29, HIGH -27 to -37. So the cutscene is about 20 dB louder than
   fishing, mostly bass (a sustained rumble/drone with drums), no single peak at a reveal. 0:20.5 -25 as it fades.

### C5. Frozen Leviathan, second recording (V2 0:28.3-0:45.4, 17.1 s)
1. 0:22-0:28 reel in the ice area. 0:28.3 the reel bar vanishes and the avatar's rod snaps (catch frame); 0:28.5
   fade to black 0.5 s; 0:29.0-0:29.8 black; 0:30.0 fade in WITHOUT letterbox for 0.3 s, then the bars slide in by
   0:30.5 (animated letterbox). Shots: 0:30.0-0:33.0 serpent slithering across snow (camera low, tracking); 0:33.0-
   0:35.4 avatar small on an ice ledge, high angle; 0:35.5-0:37.4 avatar medium, camera circling, glowing rod;
   0:37.5-0:40.9 serpent's glowing spine weaving between ice spikes, wide; 0:41.0-0:42.8 avatar medium close, low
   angle; 0:43.0-0:43.8 the serpent rears up into the lens (blue body filling the frame); 0:44.0 fade, 0:44.3-0:45.3
   black; 0:45.5 the YouTuber's blur transition to the next area.
2. VFX 2/5. In-world.
3. SOUND: 0:28.3 catch HIT (MIX -34 -> -19, all bands). 0:29.5 a 0.25 s near-gap (SUB -42) in the black, then
   0:29.8-0:30.3 a bass swell SUB -42 -> -10 (+32 dB in 0.75 s) exactly as the picture fades in = the "you're in"
   hit. Scene 0:30.3-0:44.0: MIX -11 to -18, SUB -9 to -15 (bass-led). One dip 0:35.5-0:36.0 (-24/-27) on the cut
   from the serpent to the avatar (a breath between shots). Fade 0:44.5-0:45.5 -19 to -22.

### C6. Crowned Anglerfish, second recording (V2 0:52.8-1:10.0, 17.2 s)
1. Area: a dark lagoon with glowing purple crystals and a lantern-headed statue/tree. 0:46-0:52 reel. 0:52.8 the
   reel bar hides and the camera jolts to a new angle (catch); 0:53.0 fade 0.3 s; 0:53.3-0:54.5 black; 0:54.8 fade in
   with letterbox: the white-and-gold crowned anglerfish (spiky white fins, gold crown, glowing lantern) swimming;
   0:56.3-0:57.3 its lantern throws WHITE GOD RAYS (light shafts fanning out across the frame) - the prettiest frame
   in the Fisch cutscenes. 0:57.5-0:59.6 avatar small in the dark water; 0:59.8-1:02.4 avatar medium, camera
   drifting round; 1:02.5-1:05.4 wide: the fish swims through purple crystals towards the camera and fills the
   frame (1:05.3); 1:05.8-1:07.5 avatar close from behind, rod raised; 1:07.8-1:08.3 wide: crystals, the lantern's
   red name tag; 1:08.5 fade, 1:08.8-1:10.0 black; 1:10.3 YouTuber cut.
2. VFX 2/5 (god rays, purple crystal glow). In-world.
3. SOUND: catch 0:52.8-0:53.0 (HIGH/MID up first: a splash/chime -25/-27); black 0:53.3-0:54.0 SUB -19 to -22
   (rumble) ; 0:54.5 scene in at -16. Then a slow CRESCENDO: -18 to -20 for 0:56-1:01, -12 to -16 for 1:02-1:08.5
   (the fish charging the camera at 1:05 sits inside the loudest stretch). 1:09.5 -26 in the black.

### C7. Crystallized Sea Dragon (V2 1:19.1-1:35.3, 16.2 s) - new fish, toxic lagoon
1. Area: bright acid-green/yellow glowing water, dark blue rocks, pink/red/cyan crystals. 1:11-1:14 cast with "MAX!"
   power meter; 1:14.5-1:19.0 reel with the dragon (dark blue/purple spiky crystal body with pink highlights)
   thrashing beside the avatar. 1:19.1 the dragon bursts up at the camera filling the frame, "PERFECT CATCH!" in
   small white letters in the centre, fade to black over 0.4 s (1:19.1-1:19.5). 1:19.8-1:20.8 black (1.0 s). 1:21.0
   fade in to a full-frame shot of the acid water, bars slide in over 0.5 s (1:21.0-1:21.5). 1:21.5-1:22.8 slow push
   across the water. 1:22.9-1:23.6 the dragon ERUPTS out of the green water: dark spiky silhouette, dark splash
   particles, WHITE GOD RAYS fanning out behind it, camera low looking up. 1:23.8-1:28.4 the avatar among the
   pink crystals, camera orbiting (crystals sweep past the lens in the foreground 1:26.5-1:27.5). 1:28.5-1:31.5 wide
   along the glowing shore, the dragon's body weaving through the rocks. 1:31.8-1:34.0 avatar close, rod up, camera
   circling. 1:34.3-1:34.8 a big pink crystal fills the frame. 1:34.5-1:35.3 fade to black.
2. VFX 3/5: god rays at the eruption, dark splash particles, very saturated neon colours (acid green + pink +
   blue). Not cluttered. The eruption with rays is the closest thing to a "reveal" moment in Fisch.
3. SOUND: 1:18.5-1:19.0 the mix DIPS to -33/-35 (a quiet half-second just before the catch), 1:19.3 catch HIT
   -20 (all bands flat = splash + chime). Black 1:20.0-1:20.5 ~-31 with SUB -40 (no bass). 1:21.0 SUB swell starts
   (-23) with MID/HIGH almost silent (-45/-50) = a pure sub rumble while the bars slide in; 1:21.8-1:22.0 the bed hits
   (-11 dB, +11 dB in 0.5 s) just before the eruption; eruption 1:23.0 sits in the steady -14/-17 bed (no extra
   boom). Steady -12 to -21 to 1:35, fade after.

### C8. Scylla (V2 1:45.5-2:04.3, 18.8 s) - new fish, dark cave
1. 1:37-1:45 reel: a horned head and colour-cycling glowing tentacles around the avatar (each tentacle set changes
   colour every ~1 s: blue, pink, yellow, green, cyan) = the hooked boss is visible and flashy during the reel.
   1:45.5 the tentacles burst at the camera (pink/blue shapes over the lens) while the picture fades (0.5 s);
   1:46.0-1:47.3 black; 1:47.5 faint full-frame image, bars in by 1:47.8. 1:48.0-1:50.4 dark cave, white GOD RAYS
   from behind the Scylla (purple/orange creature) fanning out; 1:50.5-1:52.0 avatar small in the dark; 1:52.3-
   1:55.0 red crystals and the avatar, camera orbiting high; 1:55.0-1:58.0 wide dark cave with orange/blue crystals,
   the creature moving in the distance; 1:58.3-2:00.5 avatar close, low angle, rod raised; 2:00.5-2:02.3 the
   creature's orange/red shapes pass the camera; 2:02.5 fade; 2:02.8-2:04.0 black; 2:04.3 back to play (avatar
   standing on the cave floor with the rod, no card).
2. VFX 2/5 (god rays, crystal glows). Very dark: hard to read the creature at all.
3. SOUND: 1:45.5 catch HIT (+9, -22). Black 1:46.3-1:47.0: SUB drops to -43/-47 while LOW/MID stay at -26/-30 =
   bass is pulled out (a thin whoosh) for ~1 s; 1:47.3 SUB comes back (-27) and 1:47.8 the bed hits -15 as the bars
   arrive. Scene -13 to -20, bass-led, flat; 2:04.0 -23 in the black; back to play -23 with the game's normal bed.

### V2 audio events (whole video): HIT+BOOM pairs on every catch and every scene entry: 0:03.5 (+28 bass), 0:05.0
(+20), 0:23.3-0:29.9 a regular BOOM every 1.65 s (+18 to +24 bass) = the reel minigame's own pulsing music in the
ice area, 0:30.3, 0:36.7, 0:48.4-0:53.3 the same 1.65 s pulse during the anglerfish reel, 0:58.3, 1:12.6-1:16.0,
1:19.3, 1:20.8, 1:32.6, 1:37.6-1:47.3, 2:06.0-2:11.0. Only one RISER (0:00.5-0:02.0, the video's fade-in).
NOTE: the reel minigame has a bass pulse every ~1.65 s (about 36 bpm) that builds tension; it stops on the catch.

### V3 general (fehEuD-OYU0 "EVERY HUGE CUTSCENE IN PETS GO", 5:25.2, no captions, no commentary)
- Pets Go: the player auto-rolls eggs. A NORMAL hatch (seen 0:00-0:02.4, 0:22-0:24, 1:30, 2:01, 3:02, 3:37, 4:13):
  the pet's big face pops up in the screen centre over the normal world for ~0.5-1 s with "1 in 3" / "1 in 5" in
  white outlined text, a little pink/white sparkle, then the next one. Very fast, no camera change.
- A HUGE pet (1 in 1,000,000,000 and rarer) triggers the cutscene: the game hides the HUD and leaves the world for a
  separate "dimension", plays 13-60 s, ends in a full white-out, then the reveal card over the normal world.
- The YouTuber's audio is digitally silent (-120 dB) outside the cutscenes: during normal hatching and during
  every reveal card. So either the game plays no sound there or he cut it. The cutscene sound is complete.
- Reveal card (same for all): the huge pet's face fills the centre (it zooms in from enormous to settled in ~0.3 s:
  4:06.3 the face is bigger than the screen), a colour-matched radial burst / glow behind it (orange rays for the
  Inferno Cat, dark smoke + pink for the Ghostface Cat, red slashes for the Nightmare Corgi), "1 in 1,800,000,000"
  in big white rounded bold text with a dark outline under the face, the pet name ("Huge Inferno Cat") small
  under that. HUD stays visible at the sides. It stays 1-5 s (1 s for the first two, ~5 s later), then the pet
  shrinks/flies into the world with a coloured radial burst, and the YouTuber opens the Index (collection) to show
  the new tile (e.g. 4:11-4:12 "Collection! ... Collected 9/9").
- Others see: a chat line for every huge, e.g. at 4:10.6 "[Global] HUGE! @<player> has rolled a Huge Cosmic
  Axolotl with a 1/5,000,000,000 chance!" with "HUGE!" and the pet name and odds in coloured text (pet name purple).
  (Read by cropping the chat area; names of other players left out here.)

### C9. Pets Go standard huge cutscene: Huge Dog, 1 in 1,000,000,000 (V3 0:02.5-0:19.5, 17 s incl. 4.8 s white-out; reveal 0:20.8-0:21.9)
1. What: Pets Go "huge" hatch, the base template. Game footage. C10 (0:24.4-0:42, Huge Cat 1 in 1B) is identical.
2. Beats: 0:02.4 normal hatch on screen -> 0:02.5 HARD CUT to pure black (no fade, HUD gone). 0:02.5-0:04.8 black
   2.3 s. 0:05.0 fade in from black on a SKY (blue with white clouds) and the camera TILTS DOWN in 0.5 s to the
   horizon: an endless flat bright-green checkerboard plain = a blank "dimension". 0:05.75 the egg has just arrived
   in front of the camera (very close, white speed streaks around it) and the camera eases back over ~0.75 s. The
   egg: black, glossy, a big "?" in a rainbow gradient (cyan -> green -> pink -> blue). Then it PULSES about every
   1.6-1.7 s: 0:06.8 white glow + white streaks behind it; 0:08.0 a white lightning wisp; 0:08.5 the egg punches
   bigger (scale pop ~15%) with a yellow glow; 0:09.0 white wisps; 0:10.0 the WHOLE EGG FLASHES WHITE (a pale
   ghost egg twice the size for one frame-group, white streak burst); 0:10.3-0:13.5 a blue-white aura round it,
   white crackles (0:12.5 a thin white lightning line), the camera slowly dollies BACK (egg shrinks from ~45% to
   ~20% of the frame height). 0:13.8-0:14.5 the egg bursts: white shockwave RINGS (arcs) radiate, the light swells,
   0:14.8 full white. 0:14.8-0:19.5 pure white (4.7 s). 0:19.5 the white fades off the normal world (HUD back),
   0:20.8 reveal card (Huge Dog, brown dog face, "1 in 1,000,000,000", "Huge Dog"), 0:21.3 a white flash behind
   it, 0:21.9 the pet zooms off into the world with a green/yellow radial burst and sparkles.
3. VFX: 2/5 until the burst, then 4/5 for ~1 s (white rings, glow), then 5/5 white-out. Not cluttered: one
   object in an empty world.
4. Scenery: leaves the world completely: an empty green checker plain and sky (a "test room" look, deliberately
   simple). Scale: just the egg.
5. Camera: one continuous shot: tilt-down from the sky (0.5 s), then a slow pull-back while the egg pulses, a
   tiny push at each pulse. No cuts. Player's avatar never appears in any Pets Go cutscene.
6. Sound: 0:02.5 the cut to black lands on a deep SUB BOOM (-15 dB SUB, MID -56, HIGH -65 = pure bass) that
   decays over 1.8 s; then TRUE SILENCE 0:04.5-0:05.2 (0.75 s) in the black; 0:05.3-0:05.8 a whoosh rises -67 ->
   -25 dB in 0.5 s as the egg lands in front of the camera; pulses every ~1.6 s at -26 to -28 dB (each pulse a soft
   bass "thum" + shimmer); 0:12.5-0:14.3 the brightness climbs (MID/HIGH -26 to -31 while SUB drops to -37/-40 =
   a bright riser); 0:14.8-0:15.0 the burst: SUB -16, MIX -18 (BOOM +19); then a long 3.5 s tail fading to silence
   under the white (-23 at 0:15.5, -41 at 0:17.0, -65 at 0:18.0, -120 by 0:18.8). Reveal card silent.
   Overall level is modest (-25 to -35 dB, hits -15 to -18), much quieter than the Fisch cutscene beds.
7. Characters: none.
8. Ending: white-out -> fade back to the normal world -> reveal card with odds. Fast and clear.
9. Feels: clean, readable, a little plain; the "?" egg makes it a mystery until the card. The 2.3 s of black at
   the start + boom is a strong "something happened" signal.
10. Others: global chat line (see V3 general).

### C11. Halloween variant: Huge Ghostface Cat, 1 in 1,200,000,000 (V3 0:45.7-1:22.5, ~32 s; reveal 1:22.5-1:28.5)
1. Starts EXACTLY like C9 (0:45.7 boom to black, 0:49 sky tilt-down, egg pulses 0:50-0:54.3) so the player
   thinks it is the normal one, then BREAKS it: 0:54.5 a black panel slams in from the LEFT covering ~1/3 of the
   screen; 0:55.5 a second panel from the RIGHT; 0:55.8-0:56.8 only a narrow vertical strip of the egg shows
   between the black doors; 0:57.0 fully black (doors shut). 0:57.0-0:58.8 black. 0:59.0 fade from white into a
   purple Halloween graveyard at night: a lavender tombstone, a carved pumpkin, bats flying, a giant skeleton
   hand. 1:00.0-1:08.5 the PLAYER'S USERNAME is engraved on the tombstone letter by letter: "R", "RI", "RIP",
   then the name, one letter every ~0.3-0.5 s, with lightning flashes (the whole frame washes white for 0.25 s at
   1:01.5, 1:02.0, 1:05.5, 1:05.8, 1:06.8) and bats crossing. 1:08.3-1:10.8 the camera pulls back (dolly out) and
   a GIANT skeleton hand is revealed reaching over the grave (scale reveal). 1:11.0 hard cut through a white flash
   to an extreme close-up JUMP SCARE: a Ghostface-style white mask (black eyes, open mouth) filling the frame, red
   blood-like marks bottom left, held 1.3 s. 1:12.5 whip/motion-blur transition; 1:12.8 rainbow-lit graveyard;
   1:13.0 a hockey-mask egg holding a big knife (a slasher egg) in front of the skeleton hand; it pulses with white
   glows 1:13.5-1:15.5; 1:15.8-1:16.8 white crescent slashes and the burst; 1:17.0-1:22.0 white-out; 1:22.5 reveal
   "Huge Ghostface Cat, 1 in 1,200,000,000" with a black smoke + pink aura, held ~5 s.
2. VFX 3/5 (lightning washes, bats, rainbow light, white burst). Not cluttered.
3. Scenery: a themed set (graveyard) after the standard plain; giant skeleton hand = scale trick.
4. Camera: static on the tombstone during the typing, then dolly out; jump-scare extreme close-up; whip
   transition.
5. Sound: door slams 0:54.5 (-34), 0:55.5 (-29), 0:57.0 (-25): three hits, EACH LOUDER, each decaying to near
   silence (-55 to -66) before the next: slam ... silence ... SLAM ... silence ... SLAM. 0:59.0 the graveyard sting
   (all bands -29 to -31). Typing section quiet (-25 to -40) with MID rising 1:03.5-1:05.0 (-27/-28: scratching/
   engraving). 1:11.0 the jump-scare stinger is the brightest moment of the video: HIGH -21, MID -25 (a shriek)
   with the bass following 0.3 s later (SUB -34 -> -21). Burst 1:17.0 (-19). Fade to silence by 1:21.
6. Funny/OTT: putting the player's own name on a grave ("RIP <you>") as a joke before giving them the best pet.
   Personal, cheap to make, and memorable.

### C12. Valentine variant: Huge (yellow) pet, 1 in 1,250,000,000 (V3 1:31.0-1:50.5; reveal 1:54.5-1:59.5)
1. Standard start (1:31.0 boom to black, 1:34 plain, egg pulses). 1:38.5-1:41.5 the picture FLICKERS between the
   normal plain and a pink-tinted version full of floating pink hearts, about 2-3 swaps per second, and on each
   normal frame the camera has PUNCHED IN closer (egg ~30% -> ~70% of the frame height). 1:41.8-1:42.0 the egg
   fills the screen and turns white; 1:42.3-1:43.3 flat pink screen; 1:43.5 fade into a candy world (pastel pink
   floor, rainbow arch, pink trees, big yellow stars); 1:43.8 a red egg with pink hearts DROPS in and lands with a
   white puff; pulses; 1:45.5 white rays; 1:46.8 burst; 1:48-1:53 white; reveal 1:54.5.
2. Sound: on every pink frame the high end disappears (1:39.0 MID -63, HIGH -94; 1:39.5 HIGH -84) while the bass
   stays (-20 to -23): the pink "dream" frames are MUFFLED, the normal frames are clear: an audio flicker matching
   the picture flicker. 1:43.0 a bass hit (-19 SUB) as the candy world appears.
3. VFX 3/5 (flicker, hearts, pink tint). Camera: zoom punches in steps.

### C13. Castle/dragon variant: Huge Dragon, 1 in 1,400,000,000 (V3 2:02.2-2:19.3; reveal 2:25.5-2:31.5)
1. Standard start (2:02.2 boom to black, 2:05 plain, egg). 2:10.5-2:12.0 big dark SHADOWS sweep across the grass
   (something huge flying overhead, never shown); 2:11.0 a white castle pops up behind the egg; 2:12.0 white pillars
   with blue banners rise out of the ground on both sides (the set BUILDS ITSELF around the egg); 2:13.5 fire pours
   down onto the egg from above (dragon breath from off-screen); 2:14.0-2:15.3 the egg is charred black with glowing
   orange cracks and embers; 2:15.5 white flash; 2:15.8 a green egg with bat wings drops in from the top, replacing
   it; it flaps its wings with white speed streaks; 2:17.5-2:18.8 burst; white-out; reveal 2:25.5 "Huge Dragon,
   1 in 1,400,000,000".
2. Sound: 2:10.5 a dip to -43 (SUB -56) just before the castle appears = silence before the hit; 2:11.0 hit -28;
   2:13.5-2:14.0 fire roar -21; 2:15.5 small dip -31 before the new egg; 2:16.0-2:17.5 -20/-21; 2:18.5 HIGH leads
   (-24) = the bright riser before the burst.
3. VFX 3/5. Scale trick: the shadow of an unseen giant.

### C14. Nightmare variant: Huge Nightmare Corgi, 1 in 1,500,000,000 (V3 2:33.8-2:49.5; reveal 2:56-3:01)
1. Standard start (2:33.8 boom, plain, egg). 2:41.6-2:41.9 an OLD-TV SWITCH-OFF: the picture collapses to a white
   horizontal band then a thin white line in 0.3 s; 2:42.0-2:43.8 black; 2:44.0-2:44.5 a giant red-iris EYE fades
   in filling the screen; 2:44.8 pull back: the eye is one of many on a black egg (white eyeballs, red irises) in a
   red hell: red sky, black vertical streaks like burnt trees/rain, red fog; the camera pulls back slowly while red
   radial streaks grow behind the egg; 2:48.5 the egg turns white; 2:49.3 punch-in; 2:49.5 white.
2. Sound: 2:42.5-2:43.0 near silence (-63/-72) after the TV-off, 2:44.5 a boom (-21) as the eye appears;
   2:47.5-2:49.0 HIGH leads (-27/-28) = riser; 2:49.5 burst (SUB -18).
3. VFX 3/5; colour grading: the whole frame red/black. Strongest "the game broke" fake-out in the video.

### C15. Chest variant: Huge Jelly (cyan), 1 in 1,500,000,000 (V3 3:03.2-3:24.5; reveal 3:30.5-3:36)
1. Standard start. 3:09.25 a big translucent GOLDEN CHEST (gold frame, red round gem lock) SLAMS DOWN from above
   over the egg, bounces/squashes for 0.75 s; the egg is visible inside. 3:11.5 a tiny pink jelly pet peeks out;
   3:13-3:16.5 more and more small jelly pets (pink, green, orange, blue) pop out of the chest one after another with
   white swirl trails; 3:16.8-3:20.0 a STORM of jelly pets pours out and spins round the chest in an overexposed
   white-yellow glow (VFX 5/5: cluttered, the chest is lost); 3:20.3 white flash; 3:20.5 cut to a candy path in a
   pastel forest with a striped egg (yellow/blue/red bands); it glows, white burst 3:23.3-3:24.3, white-out.
2. Sound: chest slam 3:09.0 (-25); then 3:11.0 a TRUE SILENCE (-120) and very quiet (-40 to -75) until 3:13.0
   (a held breath while the first jelly peeks out); then a steady 6.5 s CRESCENDO -38 -> -21 dB (3:13.5-3:20.0) as
   the jellies pour out; 3:20.5 the candy world -24; HIGH leads 3:22.5-3:24.0 (riser); burst 3:24.5 (-18).
3. Directly relevant: a CHEST in the reveal; the "slam, silence, peek, flood" order works.

### C16. Lava variant: Huge Inferno Cat, 1 in 1,800,000,000 (V3 3:38.0-4:00.0, 22 s; reveal 4:05.5-4:11)
1. Standard start (3:38.0 boom to black, 3:41 plain, egg). 3:45.0 a small FIREBALL appears top right in the sky
   and grows as it flies at the camera (3:45.4 tiny, 3:45.7 a flaming rock with a star mark); 3:45.8 it SMASHES
   INTO THE CAMERA: the whole frame is a red/orange rock with fire; 3:46.0 cut to black with a red vertical glow
   like a curtain. 3:46.3-3:55.0 a DARK VOID: black, slow floating red-orange embers (dozens), red heat glows
   pulsing up from below (3:47.3, 3:49.5, 3:55.0); 3:50.0 a pair of glowing cat EYES (blue rims, orange slit
   pupils) fades in small in the dark, blinks out at 3:50.8; 3:52.0 the eyes are back, BIGGER and closer, with
   whiskers; gone by 3:53.0. 3:55.3 hard cut to a LAVA WORLD: orange-red checkered lava floor, pink-red volcano
   cones with yellow lightning-bolt and rib marks on them, dark red sky; a red egg with a yellow flame pattern,
   white sparkles, yellow fire particles drifting; 3:56.6 a yellow flare; 3:57.3-3:59.3 white crescent SLASH arcs
   whip around the egg, yellow radial burst lines, the egg turns white, a ring of light expands; 3:59.8-4:00.0
   white-out. 4:05.5 reveal: the cat face zooms in from huge, orange-red radial burst behind, "1 in 1,800,000,000",
   "Huge Inferno Cat", held 5 s.
2. VFX: 1/5 in the void (embers only), 4/5 in the lava world (fire particles, flares, slashes), not cluttered.
3. Scenery: leaves the world twice: void, then a stylised lava land with volcanoes = the closest thing in this
   batch to the user's volcano idea.
4. Camera: static in the void (the eyes do the "approach"), slow push on the egg in the lava world.
5. Sound: 3:46.0 the meteor impact (SUB -15). The void 3:48.5-3:54.5 is ONLY BASS: SUB -21 to -33 while MID/HIGH
   sit at -52 to -59 (a deep, ominous rumble with nothing bright), with two soft thumps exactly on the eye
   appearances (3:50.0 -24, 3:52.0 -22). 3:55.0 brightness returns (MID -31, HIGH -28) for 0.25 s, 3:55.3 boom
   (SUB -16) on the cut to the lava world; 3:55.5-3:56.8 the boom decays; 3:57.8-3:59.8 a bright riser (MID/HIGH
   -26 to -31, SUB falling to -41); 4:00.0 the burst (SUB -17); 3 s tail to silence.
6. Characters: only the eyes in the dark (the pet watching you).
7. Feels: the best build-up in the batch: an impact, then darkness + eyes (anticipation), then a loud colourful
   payoff.

### C17. Space variant: Huge Cosmic Axolotl, 1 in 5,000,000,000 (V3 4:13.3-5:15.3, ~62 s; reveal 5:20.5-5:25+)
1. The rarest one is by far the LONGEST. Standard start (4:13.3 boom to black, 4:16 plain, egg pulses 4:16-4:20).
   4:20.3 HARD CUT to black (2 s; a "lights out"), 4:22.3 outer space: black with white stars, a small moon in the
   middle, the camera drifting very slowly (8 s, 4:22-4:30). 4:30.8 hard cut (punch-in) to the moon huge on the
   right with the sun flaring behind it (5 s, nearly static). 4:35.8 WARP: white streak lines radiating from the
   centre (hyperspace), 2 s; 4:37.5-4:52 a purple-pink nebula starfield, slow drift, shooting stars (4:47). 4:53-
   4:54.5 a second warp (streaks). 4:54.8 a spiral GALAXY with a bright four-point star in its core, pink/purple
   particle arms rotating; slow push-in for 13 s (4:55-5:08); 5:08.3 the core star flares and fills the frame;
   5:08.5-5:10.5 black (2 s); 5:10.8 a purple moon-base: satellite dishes, pink crystal spikes, a dark blue egg
   speckled with stars DROPS in and lands (5:11.0) with a purple ring; it pulses with purple energy; 5:14.0 a pink
   energy dome expands; 5:14.3-5:15.0 the egg turns white and grows toward the camera; 5:15.3 white; reveal 5:20.5
   "1 in 5,000,000,000" (a purple axolotl face, purple-pink background, big white sparkles).
2. VFX: 1-2/5 for most of it (stars, nebula), 4/5 at the galaxy flare and the end. Long quiet stretches.
3. Camera: very slow drifts and pushes; two hard cuts; two warp transitions.
4. Sound: quiet and dark the whole way: MIX -26 to -37, SUB leads, HIGH -55 to -75 (no sparkle at all in space).
   Small swells on the cuts (moon 4:30 -27, warp 4:37 -26, galaxy 4:55-5:08 a steady -23 to -26). 5:08.8 in the
   black the highs vanish (MID -58, HIGH -68) but the bass rumble stays (-21). Moon base: egg lands 5:11.0 (-27 all
   bands), pulse 5:12.5, bright riser 5:13.3-5:15.0 (HIGH -25 to -28 above LOW -38/-40), burst 5:15.3 (SUB -16,
   +18 dB), 3.5 s tail to silence.
5. Feels: epic in scale but SLOW: 40 s of space with little happening. Rarity = length is clear, but the middle
   drags.

### V4 general (w5xdj9kQqVQ "ALL Character Obtainment CUTSCENES | Anime Vanguards (OUTDATED)", 1:45.1)
- A montage of ~10 unit "obtainment" intros, cut back to back by the YouTuber, no normal summon shown (no
  banner/summon UI anywhere in this video). Captions: his one line at 0:00 ("This is every character obtainment
  intro currently in anime Vanguards"), then "[Music]" plus SONG LYRICS for the rest ("...horizon", "never see it
  coming", "another blue sky") = he laid a vocal song over everything. So the sound data is mostly HIS MUSIC:
  steady -9 to -25 dB, SUB-led, no structure tied to the pictures. Only use it as "unknown". 0:00-0:04 is his
  title card ("EVERY" / "INTRO" captions over a lobby clip, then an "ANIME VANGUARDS" logo).
- The game's intros are anime-style: very fast cuts (a new shot every 0.25-0.5 s at the peaks), 2D manga
  "impact frames" (posterised red/black or white/black ink drawings for one or two frames: 0:07.3, 0:09.0, 0:13.8,
  0:48.3, 1:27.0, 1:38.0-1:38.3 black silhouette on lime), black-and-white halftone glitch frames (0:21.0, 0:23.5,
  0:35.8, 0:39.3, 0:51.3), pixel-mosaic wipes in the unit's colour (0:18.0 magenta, 0:24.0 and 0:39.5 blue,
  0:36.0 and 0:51.0 pink), white flash frames (0:14.8, 0:37.0, 1:24.0/1:24.5/1:25.0 strobe, 1:40.0), heavy
  colour-matched auras (pink, gold, purple, lime green, red).

### C18-C27 Anime Vanguards intros (V4, each listed: time, unit look, what happens)
- C18 0:04.3-0:11.2 (7 s) pink-haired unit in a black suit + red tie. 0:04.3 black with floating pink sparks;
  0:05.0 a pink energy blob; 0:05.3 a pink spiral burst fills the frame; 0:05.5-0:06.3 the unit's silhouette inside
  a pink energy ring, pink streaks radiating; 0:06.5 face revealed; 0:07.3 a manga impact panel; 0:08.0-0:08.8
  four cuts in 0.75 s (close-ups, white flash); 0:09.0 red/black posterised impact frame; 0:09.3-0:11.0 HERO POSE
  held 1.7 s with pink speed-lines streaking sideways past him (camera still, the lines move). VFX 5/5 (busy but
  readable because the pose is held at the end).
- C19 0:11.3-0:17.9 (6.6 s) red-haired muscular fighter (fusion-warrior look). Starts small in deep blue space with
  orange/blue stars (0:11.3-0:12.5), black lightning streaks; 0:12.8 yellow flash; 0:13.0 orange sparks on black;
  0:13.3 low angle as he lands fist-first, dust; 0:13.8 white-and-black ink sketch frame; 0:14.0 a thin horizontal
  white beam; 0:14.3 extreme close-up of the eyes; 0:14.5 the torso powering up; 0:14.8 white; 0:15.0 manga
  explosion burst; 0:15.3-0:17.8 he stands in a PILLAR OF GOLDEN LIGHT that reaches into space (vertical gold
  streaks, camera pulling back until space shows at the sides 0:17.0-0:17.8). VFX 5/5.
- C20 0:18.0-0:27.3 (9 s) a dark unit in purple shadow flames. 0:18.0 magenta mosaic wipe; 0:18.3-0:20.8 purple
  smoke swirling round a dark figure; 0:21.0 greyscale glitch; 0:21.3 pink mosaic; 0:21.5-0:21.8 sword with a red
  blade; 0:22.0 a white flare; 0:22.3-0:23.3 a vortex of purple flame round the dark figure; 0:23.5 greyscale
  halftone; 0:23.8-0:24.0 blue light grid; 0:24.3-0:25.5 the figure floating in a dark void, purple lightning;
  0:25.8-0:27.0 close-up face, glowing cyan eyes, purple lightning; 0:27.3 black (DROP -13 dB at 0:27.4).
- C21 0:28.0-0:31.8 (3.8 s) white-haired unit in a blue/white robe, in purple space: one continuous ORBIT of
  ~180 degrees round him, purple sparks drifting. VFX 2/5 (calm).
- C22 0:32.0-0:37.0 (5 s) a horned, white-haired woman: darkness with blue pixel noise; 0:33.5-0:34.5 her PARTS
  materialise one at a time (a horn, a sleeve, a cuff, the face) in the dark; 0:34.8-0:35.5 face close-up, eyes
  shut; 0:35.8 greyscale flash; 0:36.0 pink mosaic; 0:36.3-0:36.8 she opens her eyes, a red third eye glows; 0:37.0
  white. (Shows again 0:48.8-0:52.2 after the next unit.)
- C23 0:37.3-0:48.5 (11 s) a teal-haired unit with floating weapons in purple space: swords/blades orbiting round
  him (0:37.3-0:39.0), halftone + blue mosaic (0:39.3-0:39.5), slow orbit shots, wide shots with blades circling
  (0:43-0:47), 0:48.3 black ink splash on white, 0:48.5 white crackle round black. VFX 3/5.
- C24 0:52.3-1:05.4 (13 s) a hooded white unit with a skull mask and red-pink fire, IN THE GAME WORLD (rocky
  battlefield). 0:52.3-0:52.8 dark, red glow; 0:53.0-1:05.3 ONE long over-the-shoulder shot: the PLAYER'S OWN
  AVATAR (black hair, a crown accessory) stands in the left foreground beside the unit while red-pink flames and
  black smoke swirl; the avatar turns its head slightly. 12 s of nearly the same frame: the weakest one.
- C25 1:05.5-1:23.4 (18 s) a GIANT, very buff blond warrior with a huge axe (lion crest on the back), in the game
  world, WITH THE PLAYER'S AVATAR. 1:05.5 low camera behind a head, looking up at a blue sky with player name
  tags; 1:06.8 the sky turns orange; 1:07.3-1:08.0 a fireball falls from the sky; 1:08.3 giant fists and face
  smash through fire; 1:08.5 yellow flash; 1:08.8-1:10.0 the giant (huge white-skinned arms and chest) in flames
  next to the player's avatar (the avatar is a third of his height); 1:10.3-1:11.8 wide: fireballs rain on the
  battlefield; 1:12.5 black + orange flash; 1:12.8-1:14.0 extreme close-up of the axe head passing the lens;
  1:14.3-1:17.5 LOW ANGLE: the player's avatar small in the foreground (its own name tag, title and level float
  over it), the giant towering behind it with the axe on his shoulder, fire everywhere; 1:17.8-1:19.8 high angle
  on the player's avatar looking round as fireballs land; 1:20.0 the camera rushes low along a burning furrow
  towards the giant; 1:20.5 orange flash; 1:20.8-1:23.3 his BACK fills the frame: a huge muscular back with a red
  lion crest, both arms flexed (a back double-biceps pose), flames rising, held 2.5 s. VFX 4/5. This is the
  closest thing in the batch to the user's "gigantic buff powerlifter steps in front of you".
- C26 1:23.5-1:31.2 (7.7 s) a bald orange-skinned hero in a green jacket, gold aura: 1:23.5 dark + white/yellow
  lightning at his feet; 1:24.0-1:25.0 WHITE FLASH STROBE (white, shot, white, shot, white at 0.25-0.5 s);
  1:25.3-1:26.8 extreme low-angle close-ups (chin, chest); 1:27.0 black silhouette on yellow (impact frame);
  1:27.5-1:31.0 powering up in a gold aura with a HANDHELD SHAKE (the frame jumps a few pixels every 0.25 s).
- C27 1:31.3-1:41.0 (9.7 s) a lime-green aura giant (berserker look): 1:31.3-1:32.8 green with glowing red/orange
  eye slits in the dark; 1:33.0-1:35.0 dark frames with green flame shapes sweeping across; 1:35.3-1:37.3 the
  unit in a green flame column with cyan lightning; 1:37.5 black; 1:38.0-1:38.3 black silhouette on lime;
  1:38.5-1:39.8 green radial light beams exploding outward round the face; 1:40.0 white; 1:40.3-1:41.0 a green
  bolt, then a green fireball shrinking into the distance.
- C28 1:41.3-1:45.1 (end of video) a red-hat, red-coat gunman (vampire-hunter look) on a purple-pink sky: red
  diamond flare; 1:42.0 purple streak wipe; 1:42.3-1:43.3 close-ups (hat brim, glowing eyes, guns); 1:43.5-1:45.0
  a RED MAGIC SEAL circle spins up behind/around him with HIS NAME written into the circle's ring, white
  light streaks shooting up = the unit's name shown inside the effect, not as UI.
- Avatar in it: only in C24 and C25 (the in-world ones). The space/void ones show the unit alone.
- No unlock card is shown in this video at all (the YouTuber cut every intro before any UI).

### V5 general (T_zMREGoFP8 "Every Summon Vanguard In Anime Vanguards Cutscene's", 2:34.1, no captions)
- A compilation of other players' recordings (on-screen "Credit: <name>" labels; the description says clips were
  borrowed). It repeats several V4 units (pink suit, red-haired fighter, horned woman, skull-mask, giant axe
  warrior) but from the PLAYER's own recordings, so it shows the parts V4 cut: the normal summon result screen,
  the unlock card, and the player's avatar inside the cutscenes.
- NORMAL SUMMON (0:06.5-0:08.0 and 1:08.0-1:08.5): the screen dims over the summon banner UI ("SUMMON", "OCCULT
  BANNER", buttons "SUMMON 1X", "SUMMON 10X", "INDEX", "INFO", pity bars "EXCLUSIVE PITY 185/400", "LEGENDARY PITY
  30/50"); a white outline treasure-chest icon at the top with "Rewards obtained:" under it; then the unit portraits
  POP IN one by one, left to right, about 0.1 s apart (0:06.8: 4 portraits, 0:07.0: 7, 0:07.3: all 10), two rows of
  five rounded-square tiles with rarity-coloured glowing borders (blue, green, purple, gold/orange), a few white
  sparkles around the best one; the rare one has a pink/purple tile with its name under the face ("<unit>
  (Requiem)"); "(Click anywhere to close)" at the bottom. ~1.5 s, no camera move. For a RARE unit, the cutscene
  plays FIRST (0:00-0:06.3 the pink unit's intro), THEN this results grid.
- UNLOCK CARD (2:07.8, shown ~0.3 s before the YouTuber cut): in the summon hall (stone arch, pillars), the new unit
  stands in the centre inside a big PINK GLOWING RING with pink light orbs floating; a "Shiny" header in pink-to-
  white gradient bold letters with diamond icons above the unit; a right-hand panel: small "New Index Unlock!",
  big white "<Unit name> (Pride)", the rarity word "Vanguard" in orange-red with a small icon, an "Ascensions" bar,
  a stat box (DMG, SPA, RNG, Unit DPS with values); "(Click anywhere to continue)" bottom centre.
- "Shiny" variants reuse the same cutscene with a GOLD recolour of the unit (1:52-2:07: the axe giant in gold skin
  and gold armour). Cheap extra rarity tier.
- Sound: no captions; the data (0-154 s, 0.5 s table) is a steady SUB-led bed (-13 to -25 dB) with true silences
  only at the clip joins (0:08.1, 0:15.5, 1:38.6, 2:08.1: each a -52 to -120 gap then a hit = the editor's cuts).
  Treat it as game music + edit noise; it adds nothing reliable.

### C29-C35 (V5) in detail where they differ from V4
- C29 0:00-0:06.3 pink suited unit (same as C18, recorded by a player) -> 0:06.5 results grid (see above).
- C30 0:08.3-0:15.9 red-haired fighter (as C19) from the player's recording: 0:08.3-0:09.5 deep blue space with
  stars, the unit walking in small (0:09.5); 0:09.8 yellow flash; 0:10.0 white; 0:11-0:12 black/red impact frames;
  0:12.5-0:15.3 the gold light pillar (camera slowly rising, space visible at the sides from 0:14.0); 0:15.5 black.
- C31 0:17.0-0:47.5 the horned woman, from TWO players' recordings back to back: the PLAYER'S AVATAR stands in purple
  space (0:19-0:22 a spiky-haired avatar with a pet; 0:29-0:33 the same avatar, red-and-white pet on the shoulder),
  floating blades fly past (0:29.0), the woman's head looms huge over the scene (0:26.0 close-up, eyes closed),
  0:34.0 pink streak flash, 0:35.0 white, 0:40.0 white ink-crackle frame, 0:41.0 she rises, 0:42.0 pink mosaic,
  0:43.0 the red third eye opens; 0:44-0:47 a second player's avatar (red hair, a crown) in the same space.
- C32 0:48.0-1:08.0 the same unit from the second player (0:50.0 her face lit red with red sparks, 0:51.0 pink
  flash, 0:53-0:57 the avatar in purple space surrounded by red/purple glows, 0:58.0 white, 0:59-1:03 wide, the avatar
  small, 1:04 the avatar points/turns, 1:05.0 her back and horns, 1:06.0 white, 1:07.0 face) -> 1:08.0 "Rewards
  obtained:" grid (5 portraits; "(Click anywhere to close)").
- C33 1:09.0-1:20.0 skull-mask unit with the player's avatar in front (spiky crystal hair, a red bull pet and a
  butterfly floating near it): ~11 s of near-static over-the-shoulder framing, as in C24.
- C34 1:20.5-1:39.5 the giant axe warrior from the player's view: 1:20.5-1:22.0 the AVATAR LOOKS UP at the sky
  (low angle, the avatar in the middle of a green field, clouds), 1:23.0 the sky turns orange, 1:24.0 orange fire,
  1:25.0 the giant and the avatar in flames, 1:26-1:28 fireballs land round the avatar, 1:29.0 axe close-up,
  1:30.0-1:33.0 the giant towers behind the avatar (avatar's own name tag over it), 1:34-1:35 the avatar crouches
  and looks round, 1:35.5-1:35.8 the camera rushes along the burning furrow, 1:36.0 close on the crest, 1:36.3
  orange flash, 1:36.5-1:39.3 the giant's back with the lion crest, arms flexed, flames (held 2.8 s).
- C35 1:39.5-1:49.5 a blue-haired PLAYER AVATAR in close-up in a blue blizzard full of glowing cyan particles with
  a crowned pink pet on its shoulder: the avatar's face changes expression (smirk 1:41.3, set jaw 1:42.5) for ~9 s
  = the player's own face is the hero shot (blue ice unit summon; the unit itself only appears 1:39.5 as an ice
  streak and 1:49.4 as a dark cloaked shape passing the lens).
- C36 1:50.0-2:07.8 the giant axe warrior again, "Shiny" (gold) version, then the unlock card at 2:07.8.
- C37 2:08.0-2:33.0 a SKELETAL OVERLORD on a throne (25 s): 2:08.0 white explosion blur; 2:08.3-2:09.3 black;
  2:09.5-2:15.3 the player's avatar in a dark palace hall (red/black pillars), the camera dollying past its head
  toward the hall, crystal shards; 2:15.5-2:17.3 purple flame engulfs a throne with a skeletal king in a dark robe
  and a jewelled collar; 2:17.5-2:20.8 a hand with long nails (close-up), white flashes 2:17.8 and 2:18.8 with a
  black four-point star; 2:21.0-2:27.0 the skull face from below, purple fire rising, red jewels; 2:27.3 white ink
  crackle frame; 2:28.0-2:30.5 a huge purple MAGIC CIRCLE behind black ink tendrils framing the screen; 2:30.8-
  2:31.0 white radial zoom-blur flash; 2:31.3-2:32.8 a storm of purple energy and black shards (VFX 5/5,
  cluttered); 2:33.0-2:34 black. VFX 4-5/5. Strong "evil throne room" mood; avatar in the first 6 s only.

### V1 audio events list (whole video, includes the YouTuber's voice)
HIT/BOOM pairs at 0:06.2/0:06.4, 0:10.0, 0:20.1, 0:25.8, 0:32.2, 0:44.6, 0:47.4, 1:02.3, 1:15.4, 1:37.8, 1:40.6,
1:45.2, 1:45.9. Inside the cutscenes the only ones not explained by talking are 0:32.2 (catch, BOOM +15),
0:47.3-0:47.8 (cut into shot A: MIX -32 -> -13, SUB -45 -> -21; LOW leads at -11, and the caption "oh okay so
all the cut scene are unique" runs 0:40-0:49, so this is probably his voice, maybe with a bass hit under it) and 1:02.3
(catch). RISER 0:23.0-0:24.5. SILENCE only at the very end (1:50.8).

## 4. Patterns across my cutscenes

- THREE TEMPLATES in this batch:
  1. Fisch (C1-C8): "in-world trailer". Catch -> 0.4 s fade to black -> 1.0-1.3 s black -> letterbox fades in (bars
     sometimes slide in over 0.5 s) -> 5-6 slow shots (creature passes the lens / avatar idle with rod up / wide /
     creature charges or rises into the lens) -> fade to black -> back to play. ALWAYS ~17 s, VFX 1-3, never leaves
     the map, avatar in it but doing nothing, no unlock card. Sound: a catch hit, a bass swell on the fade-in (+30 dB
     in under a second), then a flat loud bass bed ~20 dB over normal fishing; no extra hit on the "reveal".
  2. Pets Go (C9-C17): "blank dimension + mystery object + white-out + odds card". Hard cut to black on a deep sub
     boom, true silence, a sky-to-ground tilt into an empty green checker void, a "?" egg that pulses every 1.6 s,
     then a bright riser, a white-ring burst, a 4-5 s white-out with a 3.5 s reverb tail, then the reveal card over
     the normal world with "1 in N". Variants BREAK the template partway (doors slam, TV switches off, a meteor hits
     the lens, the picture flickers) into a themed world.
  3. Anime Vanguards (C18-C37): "anime opening". Cuts every 0.25-0.5 s, manga impact frames, greyscale and mosaic
     glitch frames, auras in the unit's colour, a held hero pose at the end; some play IN the game map with the
     player's avatar (the giant warrior: the sky turns orange, fireballs fall, the giant towers over the avatar);
     then the results grid, then an unlock card in a summon hall.
- RARITY vs LENGTH: Pets Go is the clear case: 1 in 1B = ~17 s; 1.2-1.8B = 20-37 s with a themed world; 1 in 5B =
  ~62 s with several worlds. Fisch secrets are all ~17 s (no tiers). AV intros 4-18 s (giant warrior longest).
- RARITY vs VFX: higher Pets Go tiers add a whole extra WORLD rather than more particles; the VFX in each world stays
  readable (2-4) except the jelly flood (5, cluttered) and AV's endings (5).
- Things that work every time: (a) a silence or near-silence just before the big hit (Pets Go 0.75 s after the
  first boom; door slams with silence between; the chest's held 2 s; the void with only bass before the lava
  world; Fisch V2 1:18.5-1:19.0 dip before the catch); (b) a bright riser (HIGH/MID up, SUB down) for 1.5-2 s right
  before the burst; (c) the burst is a SUB hit with a long tail under a full white-out; (d) a hard cut to black on a
  bass boom as the "something happened" signal.
- Scale tricks: giant creature or figure vs a tiny avatar (AV giant warrior with the player's name tag at his knee
  height; Fisch held fish 3-10x the avatar; Pets Go: the shadow of an unseen giant, the giant skeleton hand).
- Personalisation: Pets Go engraves the player's username on a tombstone (C11); AV puts the player's avatar (with
  its own name tag) in the scene and gives it close-ups (C34, C35); AV writes the UNIT's name into the magic seal.
- Cheap vs epic: cheap = long static shots (AV skull unit 12 s on one frame), dark scenes you can't read (Fisch
  Scylla), other players walking through the "movie" (Fisch C1), 40 s of slow drifting (Pets Go space), clutter
  that hides the object (jelly flood, AV overlord ending). Epic = a clear object in an empty frame, impacts aimed at
  the lens, scale contrast, a pause before the hit, a themed world that matches the item.
- Unlock screens: Pets Go = huge face + "1 in N" + name, over the live world, 1-5 s, plus a global chat line. AV =
  results grid of tiles that pop in one by one, then a card in a summon hall: unit on a glowing ring, "Shiny"
  header, "New Index Unlock!", name, rarity word, stats, "(Click anywhere to continue)". Fisch = none (the normal
  "PERFECT CATCH!" text and the fish in hand).

## 5. Ideas for the lava-belt cinematic (and other gear)

Copy in spirit only (never their art, characters or music).

1. Fake-out start (Pets Go C11 0:54.5, C14 2:41.6, C16 3:45.0): every crate opening starts the same, so a legendary
   should begin like a normal opening and then BREAK it: the lid lifts, the normal glow starts, then the crate
   "inhales" and the screen is pulled into it. The first 1-2 s identical to a normal opening make the break land.
2. Boom to black + silence (C9 0:02.5-0:05.2): hard cut to black on a deep sub boom (SUB about -15 dB, nothing above
   1 kHz), 1.8 s decay, then 0.5-0.75 s of real silence before the new world fades in with a rising whoosh.
3. Something hits the lens (C16 3:45.0-3:45.8 meteor; Fisch C2 1:00.6 creature's body; C11 1:11.0 jump-scare mask):
   use it for the eruption: a lava rock flies straight at the camera, then the powerlifter's hand or back fills the
   frame as he blocks it (AV C25 1:12.8 the axe head passing the lens).
4. Dark void with only bass and eyes (C16 3:46.3-3:55.0): before the volcano, a short black void with slow floating
   embers and only a low rumble (MID/HIGH about -55 dB), two soft thumps; then a hard cut with a boom into the bright
   volcano world. Fits "pulled into a new dimension".
5. Stylised lava world (C16 3:55.3): clean/checkered lava floor, a few big volcano cones with simple glowing marks,
   dark red sky, drifting fire particles; simple and readable like Pets Go, not realistic.
6. Giant figure + tiny avatar (AV C25 1:14.3-1:17.5, C34 1:30-1:33): low angle, the player's avatar in the
   foreground with its own name tag, the gigantic powerlifter towering behind it in fire; the avatar LOOKS UP first
   (C34 1:20.5-1:22.0) and looks round as rocks land (C34 1:34-1:35). End his part on a held flex from behind
   (C25 1:20.8-1:23.3: a back double-biceps in flames, 2.5 s) = the "is it really this serious" joke beat. Put a
   CENTRAL crest on his back instead of their lion (house brand rule).
7. The shadow of something huge (C13 2:10.5-2:12.0): before the giant appears, a huge shadow sweeps over the avatar.
8. The set builds itself (C13 2:11.0-2:12.0 castle and pillars rise): an anvil rock could rise out of the lava as he
   smashes lava and rock together.
9. Riser, burst, white-out (all Pets Go): 1.5-2 s of rising brightness (HIGH/MID up, SUB down) while white crescent
   slashes whip round the forming belt (C16 3:57.3-3:59.3), a ring of light, a SUB hit with a 3 s tail under a full
   white-out = the belt is finished. Then "thrown out": the white fades back to the normal world with the belt on the
   avatar's waist.
10. Unlock card (Pets Go C9 0:20.8; AV 2:07.8): the item zooms in from huge to settled in ~0.3 s with a
   colour-matched radial burst (orange/red rays for lava), the item name big, the rarity word in its colour
   ("LEGENDARY" in orange), a small "New!" line, "tap to continue". Pets Go adds a server chat line in coloured words
   (V3 4:10.6): "<player> unboxed the LAVA BELT (Legendary)!". Others hearing about it is half the fun.
11. Personal joke (C11 1:00-1:08 "RIP <username>"): the giant's forge stamp or a sign could show the player's name,
   or the belt leather gets stamped with it. Big laugh for tiny cost (per the user's notes, Roblox TTS sounds
   robotic: show the name as text, keep any voice line generic).
12. Rarity = length, but keep it tight: Pets Go's 62 s space cutscene drags (4:23-4:52). Suggestion: common = no
   cinematic, rare = 3-5 s glow + card, epic = 8-12 s themed dimension, legendary = 20-30 s with a story beat;
   skippable after the first viewing.
13. Shiny/gold recolour tier (AV C36 1:52-2:07): the same cinematic with a gold-tinted belt and gold giant for an
   extra-rare roll.

Other gear, same toolkit:
- Knee sleeves: a "TV switch-off" break (C14 2:41.6) into a cold blue blizzard (AV C35) where two ice blocks slam
  shut on the knees; burst; card.
- Wrist wraps: the doors-slam fake-out (C11 0:54.5-0:57.0: three slams, each louder, silence between), then the wraps
  whip round the wrists like the white crescent slashes.
- Singlet: the chest-slam-and-flood beat (C15 3:09.25-3:20.0: a chest slams down, 2 s held silence, one item peeks
  out, then a flood) with singlets pouring out of the crate (keep the flood readable, unlike C15).
- Duck-floaty belt (funny): the Valentine flicker (C12 1:38.5-1:41.5: picture and sound flicker between normal and a
  muffled pink world) but into a bath-time world with rubber ducks; play the huge sub boom totally straight.

Things to AVOID (with timestamps):
- Long static shots: AV C24 0:53-1:05 (12 s one frame), C33 1:09-1:20.
- Too dark to read: Fisch C8 1:48-2:02 (Scylla in a black cave).
- Clutter that hides the item: Pets Go C15 3:16.8-3:20.0 jelly storm; AV C37 2:31.3-2:32.8.
- Other players walking through the cinematic: Fisch C1 0:21.5-0:24.3.
- Slow drift with nothing happening: Pets Go C17 4:23-4:30 and 4:38-4:52.
- The same cutscene for every item with no payoff card (Fisch; the YouTuber's lukewarm "that was an okay cut scene"
  at V1 1:26-1:34).

Performance note: the best moments here are cheap (one object in an empty space, a few dozen particles, full-screen
flashes and colour changes done as UI, a handful of camera cuts). The particle storms were the worst moments.

