# Development Status

Short handoff between Claude Code sessions. Read this first, then verify it
against `git status` / `git log` before acting. Last updated: 2026-10-27
(Starter Gym step 6: the treadmill rhythm game part 2, the saved leaderboards,
tested in Studio, approved by the user, COMMITTED, published, and saving
checked in the live game; then the Mock Meet part 1 (private meet rooms),
built, tested in Studio and COMMITTED; then Mock Meet part 2 (the meet
itself) COMMITTED; next the game-wide UI restyle; 2026-10-28: weight-class
builds (schema v6) and Mock Meet rewards, tested; then the Mock Meet's
Blender models, uploaded, tested and COMMITTED; newest entries at the end of the
CURRENT MILESTONE block).

## 0. NEXT ACTION (start here)

**Step 6D.2a (automatic rack spawning) is COMPLETE**: all tests passed
(section 6) and it was committed with user approval on 2026-10-17 as "Spawn gym
racks automatically from the rack template (Step 6D.2a)" and pushed to
`origin/main` (run `git log -1` for the hash; the file does not hold its own
commit's hash).

**Step 6D.2b (remove the hand-placed rack dependency) is COMPLETE**: passed in
Studio, the hand-placed rack is removed and the cloud place saved (user,
2026-10-17), and the code was committed with user approval on 2026-10-17 as
"Replace the hand-placed power rack with a spawned rack (Step 6D.2b)" and
pushed to `origin/main` (`git log -1` for the hash). See section 6.

**Step 6D.2c (retire the placeholder stations) is COMPLETE**: passed in Studio
(user, 2026-10-17) and committed with user approval on 2026-10-17 as "Replace
the placeholder training stations with spawned racks (Step 6D.2c)", pushed to
`origin/main` (`git log -1` for the hash). See section 6. No Studio place
change was needed (the placeholders only ever existed at runtime).

1. Read `CLAUDE.md`, then this file. Check `git status` against section 4:
   only the deliberately uncommitted files listed there should remain.
2. Current milestone (approved 2026-10-19): build the real Starter Gym. See
   "CURRENT MILESTONE" below. Step 6E and sign polish are still not started.

**ComboRack_01 station (GAME_DESIGN §34.12 decision 15), 2026-10-18: PASSED IN
STUDIO, COMMITTED AND PUSHED** (user-approved 2026-10-18 as "Use ComboRack_01 for every gym station and hide the bench per lift"; `git log` for the hash). All steps approved by the user 2026-10-18.
- Blockout committed `a816769` and pushed to `origin/main` (user-approved).
- Detail pass (rounded edges etc.) built, exported, approved by the user in Blender.
- Imported into Studio, prepared with `tools/studio/ComboRack01_PrepareImport.luau`,
  saved as `art/roblox/ComboRack_01.rbxmx`, synced by Rojo into
  `ServerStorage.RackTemplates.ComboRack_01` (PowerRack_01 template kept).
- Rack code: per-template profiles in RackConfigurator; RackSpawner checks
  each template against its profile and sets a `RackTemplate` attribute.
- Swap: all four `GymRacks` entries use `ComboRack_01` (same spots, facing 0).
- New `StationVisuals` (called from TrainingStationService `refreshSign`):
  Squat hides the bench and raises the J-cups 0.70 to the squat hole; Deadlift
  hides the bench; Bench / free shows it. Visual only, no rule change.
- Studio result (user, 2026-10-18, Local Server): "Everything worked" after the
  test list: racks look like the Blender model, verify script, bench hiding
  per lift, J-cups moving, training still counting, collisions. The verify
  script's output text itself was not shared.
- Player poses: plan approved by the user 2026-10-19 (recorded in GAME_DESIGN
  §34.12 decision 15): Blender keyframe animations on an R15 rig imported into
  Studio; slow repeating reps while training; barbell model first. Order:
  (1) `Barbell_01` model (bar + IPF-colour plates, same pipeline as the rack);
  (2) server positions/holds the character per lift and marks it with the lift;
  a client script plays the pose for every character (placeholder pose first);
  (3) the real animations; (4) polish. Each step Studio-tested before the next.
- Step (1) DONE 2026-10-19: `Barbell_01` (bar, 7 IPF plates, lock collar)
  built, plates enlarged after the user's reference photos (450 mm = 2.0
  studs, 0.225 m/stud), approved in Blender, imported with
  `tools/studio/Barbell01_PrepareImport.luau`, saved as
  `art/roblox/Barbell_01.rbxmx`, Rojo-mapped to
  `ServerStorage.BarbellTemplates.Barbell_01` (needed the reconnect; 10/10
  meshes confirmed).
- Step (2) DONE 2026-10-19 (positioning; no animations yet): every station gets
  a loaded barbell (`TrainingStationConfig.BarbellDisplayLoadPerSide`, 2x25 per
  side + collar) that follows the lift (J-cups at bench/squat height, floor
  for deadlift); `StationPoses` anchors and places the lifter (Squat: walked
  out under the bar facing the open front; Bench: face up on the bench, head
  under the bar; Deadlift: behind the floor bar FACING THE RACK, user choice),
  sets the character attribute `StationPose`, and on release puts them on
  their feet at the exit spot. Positions live in `StationLayout`. User-tested
  in Studio 2026-10-19 (2 players): "It all worked" (barbells, the three
  positions, bar moves, Stop release, reset, Player2 view, training counting);
  then deadlift turned to face the rack and re-tested: correct. The verify
  script output was not shared.
- Step (3) DONE 2026-10-19: rep animations. `art/scripts/station_animations.py`
  (run in Blender) holds all three reps as joint angles over a 6 s loop, on
  the exact Roblox R15 block rig measured from `art/animations/R15_BlockRig.rbxmx`
  (saved from Studio's Rig Builder; its joints are AnimationConstraints +
  rig attachments). It previews them in Blender (rack + loaded bar, all three
  side by side) and writes `art/animations/Station_<Lift>.rbxmx`
  KeyframeSequences (61 keyframes, Action priority, looped). Hands are placed
  on the bar by a small arm solver; feet stay planted. User-reviewed changes:
  squat faces the rack, more upright, wide stance, toes out; bench wide grip,
  straight-arm lockout with elbows out, flared elbows at the touch; deadlift
  faces the rack, bar path straight up in front of the legs, lockout with
  straight knees and shoulders back. J-cup heights set from the rig: bench
  hole 3.45 (bar 3.14), squat hole 3.80 (bar 3.49) (`StationLayout`).
  Published in Studio and listed in `src/shared/Config/StationAnimationConfig.luau`.
  **The game is owned by Group 529442797: every animation (and any future
  asset the game loads) must be published with that group as Creator.** User-
  owned copies fail with "experience doesn't have access permission" even
  after sharing. Studio's Insert from File silently failed for the
  KeyframeSequence files; temporarily mapping them in `default.project.json`
  (ServerStorage.AnimationSources) worked, and the mapping was removed again.
  `src/client/Training/StationPoseAnimator.luau` plays the rep on the local
  player's own character (replicates to everyone) and moves every posed
  lifter's rack barbell to the midpoint of their hands while held (deadlift:
  1.6-4.3 s), else to the Barbell's `RestCFrame` attribute (set by
  StationVisuals). StationPoses also sets the character attribute `StationRack`.
  User-tested in Studio 2026-10-19 (2 players): all three reps animate, bar
  follows the hands, Player2 sees it, Stop puts everything back.
- Later follow-ups (not scheduled): squat/bench walk-out and re-rack
  animation, avatars with other proportions (hands may sit slightly off the
  bar). Lighter plates only if the stress test below asks for it (measured in
  Blender 2026-10-19: the station's loaded bar is 5,012 tris, the rack 7,176,
  so ~12.2k per station; the older "~16k per loaded bar" note was wrong).

**CURRENT MILESTONE: build the real Starter Gym (user-approved 2026-10-19).**
Plan, each step Studio-tested before the next:
(1) floor plan; (2) 30-rack stress test; (3) gym shell (floor, walls,
ceiling, entrance) from Git-tracked files; (4) spawn and racks fitted to the
shell; (5) lighting; (6) props and decoration rooms; (7) phone performance
and polish.
- Step (1) DONE 2026-10-19: the user chose **Option B, three rows of 10**
  from three drawn options (A two wall rows, C back-to-back islands; Claude
  had recommended C). Recorded in GAME_DESIGN §27. 30 racks, open fronts
  toward the entrance/lobby at -Z (the place's SpawnLocation, Z -12..0, sits
  in the lobby), decoration rooms along the side wall on the right as you walk
  in (-X), about 166 x 89 studs.
- Step (2) DONE (details and test results below): `TrainingStationConfig.GymRacks` is now BUILT from
  the new `TrainingStationConfig.GymLayout` (3 rows x 10, 12 studs apart,
  rows 21 apart, row 1 at Z 25, X from +54 to -54, facing 0); GymRack_01-10
  is the row nearest the entrance. The old 4 positions are gone. Station IDs
  are not stored in player data (checked), so nothing migrates.
  `ComboRack01_VerifyRacks` now also checks the rack count and minimum
  spacing, and prints only FAIL/LOOK/INFO lines (PASS lines counted). New
  read-only `tools/studio/GymStressTest_SceneStats.luau` (client view):
  object counts, full-detail triangles of the gym racks, 5 s frame rate.
  Checks by Claude: luau-lsp 0 errors in the changed and dependent files
  (only the known errors of section 5); `rojo build` OK; `git diff --check`
  clean. NOT yet tested in Studio. NOT committed.
  Studio result 1 (user, 2026-10-19 17:43, Local Server, 1 player, client
  view, user's PC; screenshot): 30 racks, 1073 parts (1039 MeshParts),
  0 lights, 30 signs, 30 prompts, ~365,640 full-detail triangles, average
  57 FPS over 5 s, slowest frame 67 ms (probably the frame the script itself
  ran in). Where the player stood was not stated.
  Studio result 2 (user, 17:46, server view): `ComboRack01_VerifyRacks`
  666 passed, 1 FAILED: "GymRack_28: J-cups together at bench or squat
  height (raise -0.700)", i.e. the -0.35 bench drop applied twice. Cause
  (code trace; only StationVisuals moves J-cups): its remembered "base"
  J-cup CFrames lived in a WEAK-keyed table; Roblox can drop an Instance key
  from a weak table while the Instance still exists, so the base was re-read
  from the already lowered J-cups. Fix (not yet Studio-tested): strong tables
  with cleanup on `Destroying` in `StationVisuals` (base CFrames, last look,
  barbells), `StationPoses` (posedAt: a lost entry could leave a lifter
  anchored) and the client `StationPoseAnimator` (bars). luau-lsp 0 errors
  in these files (only the known errors of section 5), `rojo build` OK.
  Studio result 3 (user, 17:59, after the fix): `ComboRack01_VerifyRacks`
  ALL 667 CHECKS PASSED (whether before or after training: not stated).
  Studio result 4 (user, 18:01, client view, back row; screenshot): same
  counts and triangles, average 52 FPS over 5 s, slowest frame 67.9 ms. Both
  runs had one ~67 ms frame, most likely the script's own Workspace scan;
  the script now skips its first frame. Conclusion: no lighter plates needed
  on PC; phones are checked in step 7.
  Studio result 5 (user, 2026-10-19): training at a back-row rack works
  (animation, bar, Stop), and the verify ALSO passed after a few minutes of
  training, so the weak-table fix holds.
  **Step (2) DONE 2026-10-19** (user-tested in Studio). COMMITTED and pushed
  2026-10-19 with user approval as "Lay out 30 gym racks in three rows and
  fix J-cups dropping twice (Starter Gym steps 1-2)" (`git log` for the hash).
- Step (3) BUILT, NOT YET STUDIO-TESTED, NOT committed (approach approved by
  the user 2026-10-19): new `src/server/World/StarterGymBuilder.luau` builds
  `Workspace.StarterGym` (Floors: Floor_Gym rubber, Floor_Lobby concrete,
  Floor_Rooms tiles; Walls: front with a 12 x 10 entrance in line with the
  rows, back, Wall_Left (+X), Wall_Right (-X), Wall_Rooms with one 8 x 9
  doorway per room, 3 room dividers; each wall = dark band 3 studs + painted
  wall, 20 studs high) at server start, called from `init.server.luau`
  before RackSpawner. Sizes worked out from `GymLayout` plus margins in the
  new `src/shared/Config/StarterGymConfig.luau`: gym floor X -70..70,
  Z 6..73.05; lobby Z -16..6; rooms X -97..-71. No ceiling (comes with the
  lights in step 5). `GymLayout.floorY = 0.05`: floor tops and racks sit
  0.05 above the Baseplate (no z-fighting). Fails closed (warning, no shell)
  and only builds for facing 0. New read-only
  `tools/studio/StarterGym_VerifyShell.luau` (Play, either view): parts
  anchored/solid, floor tops at floorY, every rack + bar + lifting space on
  Floor_Gym and clear of walls, entrance and doorways open, spawn in lobby.
  Checks by Claude: luau-lsp 0 errors in the new and changed files,
  `rojo build` OK, `git diff --check` clean.
  Studio result 1 (user, Play): `StarterGym_VerifyShell` 15 passed, 1 FAILED:
  "Workspace.SpawnLocation at (1.0, 0.5, 2.0) is inside the lobby". The
  spawn is NOT where the 16 Oct snapshot note said (0, 0.5, -6); at Z 2 a
  12-stud pad reaches Z 8, past the lobby's back edge (Z 6). Everything else
  passed (shell parts, floor heights, racks on the floor and clear of
  walls, entrance and doorways).
  Response (2026-10-21): the shell maths moved into
  `StarterGymConfig.footprint(layout)` (used by the builder and scripts; same
  numbers). New guarded one-time `tools/studio/StarterGym_MoveSpawnToLobby.luau`
  (Edit mode, place 96814269062063, exactly one Workspace.SpawnLocation, still
  at (1, 0.5, 2), must fit): moves ONLY its X/Z to the lobby centre (0, Y, -5),
  one Undo step; the user then saves the place. NOT yet run.
  User look in Studio (2026-10-21, screenshot): likes the rack colours; the
  gym feels TOO SMALL and TOO CROWDED; the floating "Training Rack" sign
  above every rack is bad; the shell is too basic and the four rooms in a
  strip on one side feel unplanned. Whether the spawn-move script was run:
  not stated.
  Response: Claude recommends getting the shell right (size, building shape,
  room placement, ceiling style) before any details, and replacing the
  floating signs (proposal, not approved yet). Shell references 11-15 and a
  tick list were added to `References/Visual Style/Visual Style.md` for the
  user to mark what they like.
  User picks (2026-10-21, recorded in Visual Style.md): a roof with
  skylights like the Gymshark Lifting Club (not flat); TWO FLOORS, all racks
  downstairs, bright Academia-2.0-style training rooms upstairs; a
  Gymshark-like entrance with reception desk, gym-name wall and glass doors;
  wall decoration later; more space between racks; high ceilings.
  Claude's redesign drawn in chat (NOT approved yet, nothing built):
  racks 16 apart, rows 28 apart (about 184 x 115 studs); a double-height
  rack hall (eaves 28, ridge 44) under a pitched roof with skylight strips;
  a 2-floor front block 30 deep: ground = lockers, lobby (glass doors,
  reception desk, gym-name wall, spawn, glass wall to the hall), stairs,
  office; upper (floor at 14) = balcony with glass railing over the hall,
  warm-up room, max testing room, stairs, coach room, glass fronts.
  Open questions: roof shape (one big pitched roof vs sawtooth vs curved);
  removing the floating rack signs (unanswered).
  User reply (2026-10-21): pitched roof APPROVED. Wants the gym BIGGER and
  rooms NOT all on one side, "plenty of rooms scattered across the gym" like
  Academia 2.0, because they plan to put plenty of NPCs in them (NPCs: a
  future idea, no design yet). Signs question still unanswered.
  Redesign v2 drawn in chat (NOT approved yet, nothing built): about
  250 x 132 studs (56 x 30 m). Central double-height rack hall (188 x 100,
  racks 16 apart, rows 28 apart, ~18-stud side aisles, ~21-stud open area
  in front of row 1) under the pitched roof with skylights. Two-floor room
  blocks on the LEFT, RIGHT and FRONT, every room with a glass front:
  ground = left Physio/Massage/Recovery/Office, right Shop/Coach/Sauna/
  Storage, front Stairs/Lockers/Lobby (glass doors, reception, name wall,
  spawn)/Cafe/Stairs; upper = Rooms 1-8 on the sides, Warm-up/Max testing/
  Studio at the front, stairs in both front corners, a U-shaped balcony
  walkway with glass railing around three sides of the hall. Room names are
  placeholders. 21 rooms in total.
  User (2026-10-21): v2 APPROVED, and the floating rack signs to be REMOVED
  (prompt only up close). Recorded in GAME_DESIGN §27 ("Starter Gym building,
  version 2" and "Rack signs").
  v2 STAGE 1: Studio checks passed (below); COMMITTED and pushed 2026-10-21
  with user approval as "Build the Starter Gym version 2, stage 1, and replace
  rack signs with the prompt" (`git log` for the hash). What it contains:
  - `TrainingStationConfig.GymLayout`: rackSpacingStuds 16, rowSpacingStuds 28.
  - `StarterGymConfig` rewritten for v2: hall margins (side/back aisle 14,
    front open area 21), side blocks 30 deep, front block 32 deep, storeys
    14 (upper floor top Y 14.05, block roofs Y 28.05), lobby 70 wide with a
    46-wide opening to the hall, entrance 16 x 10, room doors 6 x 9, glass
    look, the room name lists (placeholders), `footprint()` with every edge.
    Numbers: hall X -94..94, Z -3..97.05; building X -126..126, Z -37..98.05.
  - `StarterGymBuilder` rewritten: Floors (Floor_Hall, Floor_Lobby, room
    floors, Slab_* upper floors), Roofs (flat roofs of the 3 room blocks; the
    hall is still open to the sky until stage 2), Walls (outer walls with
    band, lobby glass front with the entrance, glass fronts with one door per
    room on both floors, room dividers), Rooms (26 invisible region parts
    Room_<Name> with Floor, DoorCentre, DoorAlongX attributes). The front
    corner rooms (the drawing's stairs places) get a door into the next front
    room; stairs and balcony are stage 3, so upstairs is NOT reachable yet.
  - Rack signs: `TrainingStationService` no longer makes the BillboardGui;
    the prompt's ObjectText is the rack title and its ActionText "Train" /
    "In use". `GymRackWatchProbe` (disabled dev probe) reads the prompt
    instead of the sign. `ComboRack01_VerifyRacks` expects NO sign.
  - `StarterGym_VerifyShell` rewritten for v2 (folders, solid parts, floor
    heights, racks clear, all 26 rooms once with open doors, entrance, spawn
    in Room_Lobby). `StarterGym_MoveSpawnToLobby` now targets the v2 lobby
    centre (0, Y, -20) and accepts the pad at (1, 0.5, 2) or (0, 0.5, -5).
  - Checks by Claude: luau-lsp 0 errors in every changed file, `rojo build`
    OK, `git diff --check` clean.
  - Rooms with roofs will look dark inside: Lighting.Ambient is black; the
    lights come in a later stage.
  Move script run 1 (user, 18:27, Edit): "SCRIPT ERROR ... CommandBar:69:
  attempt to perform arithmetic (sub) on nil and number" (nothing changed).
  Cause: the Command Bar caches every required module for the Studio session,
  so it still had the OLD StarterGymConfig (no hallFrontZ) from the first
  script version. Fix: the script now requires fresh copies from an
  unparented clone of ReplicatedStorage.Shared.Config (nothing enters the
  place) and stops with a clear message if the config is still old.
  LESSON for every Edit-mode Command Bar script: never trust require() of a
  module that may have changed in this Studio session; use a fresh clone.
  Studio results (user, 2026-10-21 18:39, after the fixed move script):
  `StarterGym_VerifyShell` ALL 12 CHECKS PASSED (so the spawn is in the v2
  lobby; whether the place was saved afterwards: not stated);
  `ComboRack01_VerifyRacks` ALL 667 CHECKS PASSED (racks at the new spacing,
  no signs). Not yet reported: the visual look, walking around, the new
  prompt, training once, and the answer on open staircases in the hall's
  front corners.
  User look (2026-10-21, 2 screenshots: hall seen from above the lobby, and
  from the lobby opening): stage 1 renders as built (two floors of glass
  fronts around the hall, racks at the new spacing, open sky). No problems
  reported. Stairs decision (user): two staircases coming out of the hall's
  two front corners right as you walk in, up to the second floor; recorded
  in GAME_DESIGN §27. Added by the user: the staircases are GLASS, and the
  rooms behind them must stay reachable (also in §27). Doors near the front
  corners: Lockers / Cafe on the hall's front glass (X +/-64.5) and the side
  blocks' front rooms Office / Storage (X +/-94.5, Z about 9.5). Design notes
  for stage 3: the stairs must sit inside the balcony line (the 14-stud side
  aisle may need to widen), and the verify script must check a clear
  walking zone in front of every room door (no stair or railing part in it).
  v2 STAGE 2 (hall roof) BUILT, NOT YET STUDIO-TESTED, NOT committed
  (user said 2026-10-21: commit stage 1, then start stage 2):
  - `StarterGymConfig`: RoofRiseStuds 16 (ridge Y 44.05, about 18 degrees),
    thickness 1, overhang 1, skylight band 0.30-0.75 of each slope with 6
    skylights per slope and 6-stud gaps, 9 steel beam bays (beam 1 x 1.5);
    looks HallRoof (light metal), Skylight (glass 0.55), SteelBeam (dark metal).
  - `StarterGymBuilder.buildHallRoof`: ridge along X over the hall's middle
    (Z 47.025), slopes from the eaves at Z -4 (front glass wall) and 98.05
    (back wall) at Y 28.05; per slope: lower and upper solid panels, the
    band of gaps and skylights (CastShadow off); a ridge cap; two WedgePart
    gables per side on the side glass line (X +/-94.5); RoofBeams folder
    (rafters under each slope + a tie beam per bay, one ridge beam).
  - `StarterGym_VerifyShell`: 60 upward rays over the hall must all hit the
    roof; 12 skylights expected.
  - Checks by Claude: luau-lsp 0 errors in the changed files, `rojo build`
    OK, `git diff --check` clean.
  - Expected side effect: with the roof on, the hall gets much darker
    (Lighting.Ambient is black; only the skylights and glass let light in).
  User look at stage 2 (2026-10-21, screenshot from outside): did NOT like
  the flat roofs around the pitched hall roof. Decision (user): ONE pitched
  roof over the WHOLE building, NO flat roof tops (recorded in GAME_DESIGN
  §27). Reworked (NOT yet Studio-tested, NOT committed):
  - Roof over the whole building: eaves on the front and back outer walls
    (Z -37 and 98.05, Y 28.05), ridge along X at Z 30.525, RoofRiseStuds 21
    (ridge Y 49.05, about 17 degrees), overhang 1 past the outer gables.
    Parts are named Roof_* (Roof_Front/Back_Lower/Upper/BandLeft/BandRight/
    Gap_n/Skylight_n, Roof_RidgeCap).
  - Skylights over the hall only, symmetric about the ridge: from 6 to 27
    studs from the ridge on each slope (config SkylightStartFromRidgeStuds,
    SkylightDepthStuds), 6 per slope.
  - The blocks' flat roofs are now Ceiling_* (white, hidden under the roof).
  - Gables on the outer side walls (Gable_Left/Right, wedges); inside,
    HallWall_Left/Right/Front close the hall off up to the roof's underside
    so the space over the rooms is not seen from the hall.
  - Beams over the hall only (rafters from the hall's edge to the ridge).
  - Verify: new check, 96 rays straight down over the whole building must
    all first hit a Roof_ part (no flat roof visible).
  - luau-lsp 0 errors, `rojo build` OK, `git diff --check` clean.
  Studio result (user, 2026-10-21, screenshot): the WHOLE BUILDING IS MISSING
  (racks, spawn and baseplate only). So StarterGymBuilder failed and removed
  its half-built gym (fail-closed; racks still spawn because the builder runs
  in xpcall before RackSpawner). Cause not known yet: the code reads
  consistently (luau-lsp 0 errors; every Looks entry used exists). One
  possibility: Studio got a mix of an old and a new file from Rojo. The
  builder now uses xpcall with debug.traceback so its warning names the line.
  RESOLVED (user, 2026-10-21): after a Rojo reconnect the building is back
  and "the roof looks good". So the cause was Studio holding a mix of old and
  new synced files (most likely the new StarterGymConfig without the old
  `Roof` look, with the old builder still using it). LESSON: when several
  files changed and Studio misbehaves, reconnect Rojo before debugging.
  Studio result (user, 2026-10-21 19:05): `StarterGym_VerifyShell` ALL 15
  CHECKS PASSED (hall roofed, whole building seen from above is the pitched
  roof, 12 skylights, rooms, doors, entrance, spawn). The user said the roof
  looks good. STAGE 2 DONE; COMMITTED and pushed 2026-10-21 with user
  approval as "Put one pitched roof with skylights over the whole Starter Gym
  (stage 2)" (`git log` for the hash).
  v2 STAGE 3 (balcony + glass staircases) BUILT, NOT YET STUDIO-TESTED, NOT
  committed (user said 2026-10-21: commit stage 2, then start stage 3):
  - `StarterGymConfig`: BalconyDepthStuds 6, railing 3.5 high / 0.3 thick,
    handrail 0.4, columns 1, StairWidthStuds 8, StairStepRiseStuds 1 (14
    steps), TreadThicknessStuds 0.4, StairBottomFromSideStuds 24; look
    StairGlass (glass, 0.35 transparent).
  - `StarterGymBuilder.buildBalconyAndStairs`: Balcony folder: Balcony_Front
    (Z -3..3 across the hall), Balcony_Left/Right (X +/-88..94, Z 3..97.05),
    tops at the upper floor (Y 14.05); glass railings with steel handrails on
    the inner edges (the side ones open at Z 3..11 where the stairs land);
    steel columns under the inner edge between the side rooms' doors
    (Z 22, 47, 72) and at X +/-31.3 on the front. Stairs folder: per side 14
    glass treads from X +/-70 to +/-88 at Z 3..11 (just behind the front
    balcony, rising toward the front corner), two sloped glass railings with
    handrails and two steel stringers. New helper `between` for sloped parts.
  - Rooms near the stairs: Lockers/Cafe doors (X +/-64.5 on the front glass)
    stay clear (stairs start at X +/-70); Office/Storage doors (X +/-94.5,
    Z 9.5) open under the side balcony beside the stair tops.
  - `StarterGym_VerifyShell`: Balcony and Stairs folders; walls/railings/
    columns/stairs all count as obstacles; NEW: the 4 studs in front of every
    room door must be clear; 28 treads with both top steps level with the
    balcony; landing onto the balcony clear; the way onto each first step clear.
  - Checks by Claude: luau-lsp 0 errors, `rojo build` OK, `git diff --check` clean.
  User test (2026-10-21): walking up the stairs is "very choppy" (the
  character hops up each 1-stud step); wants a smooth walk. Fix (NOT yet
  Studio-tested): the glass treads are now visual only (CanCollide off), and
  each staircase has an invisible, solid, non-queryable ramp
  (Stairs_Left/Right_Ramp, 1 thick, 8 wide) whose top runs through every
  step's front edge, from the floor one step before the first step to the
  top step's front edge at balcony level. The verify skips treads in the
  solid check and checks: no solid tread, 2 ramps, solid, invisible, top at
  the balcony's level, bottom at or below the floor. luau-lsp 0 errors,
  `rojo build` OK.
  Studio result (user, 19:16): verify 19 passed, 3 FAILED, all faults in the
  CHECK, not the stairs: (1) the ramp check measured tilted ramps with
  Position +/- Size/2 (wrong for rotated parts) -> `bounds()` now uses the
  8 world corners; (2)+(3) "the way onto the first step" found the ramps,
  which start one step in front of the stairs on purpose -> that check now
  leaves the ramps out. Also learned: CanQuery = false only works on parts
  with CanCollide off, so the ramp's CanQuery line was removed and its
  comment corrected. Smoothness itself not reported yet.
  User (2026-10-21): the stairs ARE SMOOTH now. Request: make the balcony
  wider, for 2-3 Roblox characters side by side, bulkier future players
  included (recorded in GAME_DESIGN §27, with "smooth stairs"). Change (NOT
  yet Studio-tested): BalconyDepthStuds 6 -> 12 (side balconies X +/-82..94,
  front balcony Z -3..9); stairs moved with it (Z 9..17, X +/-64 -> +/-82;
  StairBottomFromSideStuds 24 -> 30, same 18-stud run); to keep a 10-stud
  walkway before row 1, FrontOpenAreaStuds 21 -> 30 and GymLayout.firstRowZ
  25 -> 34 together, so hallFrontZ (-3), the lobby and the spawn do not
  move; the hall and building grow 9 studs deeper (hall back Z 106.05).
  luau-lsp 0 errors, `rojo build` OK. Whether the earlier verify fix passed
  (22 checks) was not reported.
  Studio result (user, 2026-10-21): "All checks pass" (StarterGym_VerifyShell
  and ComboRack01_VerifyRacks; exact lines not shared). STAGE 3 DONE;
  COMMITTED and pushed 2026-10-21 with user approval as "Add the Starter Gym
  balcony and smooth glass staircases (stage 3)" (`git log` for the hash).
  Stairs stay 8 studs wide for now (user decision, 2026-10-21).
  v2 STAGE 4 (reception + gym name) BUILT, NOT YET STUDIO-TESTED, NOT
  committed. User decisions (2026-10-21, recorded in GAME_DESIGN §27): the
  gym is called "ELITE PREP GYM"; the name wall is behind the reception desk
  on the lobby's left wall (+X), AND the name is on the front of the
  building outside, above the entrance.
  - `StarterGymConfig`: GymName, name wall 24 x 9 (2 above the floor), front
    sign 60 x 8 (15 above the floor), sign 0.3 thick, desk 16 long x 3 deep
    x 3.5 high, 6 studs in front of the wall, 3-stud returns, white text
    with a red accent line; looks DeskBody, DeskTop (black marble), SignPanel.
  - `StarterGymBuilder.buildReception` (folder Reception): NameWall (on the
    lobby side of Wall_Lobby_Left, X 34.2..34.5, centred Z -20), Desk_Body /
    Desk_Top / Desk_Return_1-2 (X 25.5..28.5, Z -28..-12), FrontSign (outside
    face of the front wall above the lobby glass, Z -37.3..-37, Y 15..23).
    Each name is a SurfaceGui "GymName" (TextLabel "Name", Montserrat Heavy,
    LightInfluence 0 so it stays bright) on the panel's lobby / street face;
    also on the desk's front.
  - `StarterGym_VerifyShell`: Reception folder (solid, an obstacle); the name
    3 times with the right text; the front sign outside the front wall; the
    straight way from the entrance into the hall clear; the spawn does not
    overlap the reception.
  - luau-lsp 0 errors, `rojo build` OK, `git diff --check` clean.
  User look (2026-10-21, with the Academia 2.0 reception photo): the desk
  "needs to be built better", like the photo; expand the entrance so the
  desk can be bigger; add a computer and other entrance things, lights and
  sign effects. Rebuilt (NOT yet Studio-tested, NOT committed; recorded in
  GAME_DESIGN §27 "Reception style"):
  - LobbyWidthStuds 70 -> 90 (lockers and cafe get narrower automatically;
    Lockers/Cafe doors now at X +/-69.5).
  - Desk (22 long, 3.5 deep, X 35..38.5, Z -32..-10): white front panel to a
    4.4 ledge, work surface at 3.0, end panels, dark set-back plinth with a
    neon base glow (SurfaceLight), monitor with a "Member check-in" screen
    (SurfaceGui facing the receptionist), keyboard, card reader with a green
    screen, a hanging neon light bar on two cables. No name on the desk front
    any more (white text on a white desk was invisible).
  - Name wall: dark panel 22 x 7 at Y 5..12, standing 0.6 off the wall with
    a neon halo and a PointLight behind it. Front sign: same halo, plus two
    tilted lamps with SpotLights above it.
  - White lobby ceiling (under the slab) with 4 neon LED strips
    (SurfaceLights).
  - Entrance gates at Z -9: free middle lane X -8..8, then 2 turnstiles per
    side (dark body, steel cap, green light, NON-SOLID arm) with 4-stud
    lanes, then steel railings (to the desk front on the left, to the wall
    on the right).
  - Merch wall on the right lobby wall: dark back panel, 3 white shelves with
    neon under-glow, shakers (cylinders) and folded shirts (black/white/red).
  - Small items are "decor": CanCollide and CanQuery off, attribute Decor.
  - Verify: Decor parts skipped in the solid check; the name 2x; the
    check-in screen and 10 lights; the way from the entrance through the
    gates still clear.
  - luau-lsp 0 errors, `rojo build` OK, `git diff --check` clean.
  User look at the rebuilt reception (2026-10-21, screenshot): name wall
  halo, desk base glow and ceiling strips render as intended. The verify
  script result for this version was NOT reported.
  User asked for an SBD logo on the desk: Claude advised against it (SBD
  Apparel's trademark; Roblox moderation risk for the group's game) and
  offered an ORIGINAL logo for the desk front instead, black on the white
  desk, about 8 studs wide: (1) "EPG" in a bold rounded outline badge,
  (2) "ELITE PREP" on two lines in the badge, (3) a barbell-plate icon with
  "EPG".
  Desk logo DECIDED (user, 2026-10-21, new session): "SBD Central", which
  the user confirmed is THEIR OWN game/group logo (red/silver shield with a
  barbell; recorded in GAME_DESIGN §27). Built as an image slot:
  `StarterGymConfig.DeskLogoImage` ("" = no logo yet), height 3.6 studs
  (the desk front is only 4.1 high, so ~3.4 wide, not 8), aspect 135/143;
  `StarterGymBuilder.deskLogo` puts SurfaceGui "DeskLogo" / ImageLabel
  "Logo" on Desk_Front's Left (-X) face, LightInfluence 0. Verify: FAILS
  on purpose while the ID is empty, else checks the gui, face and image.
  luau-lsp 0 errors, `rojo build` OK, `git diff --check` clean.
  WAITING ON THE USER: the only copy Claude has is a 135 x 143 screenshot
  with a dark background; the user needs the original (PNG, ideally 512+
  px, transparent background), uploaded with the GROUP as creator (Studio
  Asset Manager import in the cloud place), and gives Claude the image ID.
  DONE (2026-10-21): the user uploaded it; DeskLogoImage =
  rbxassetid://137721913391815 ("SBD Central Chrome Powerlifting Emblem";
  Roblox's asset API: type Image, creator Group 529442797 = the game's
  group). DeskLogoAspect left at 135/143 (real file size not known;
  ScaleType Fit keeps it undistorted).
  User look (2026-10-21, screenshot): the logo shows on the desk; asked to
  make it "cover the whole desk". Chose (of 3 options) "barbell across the
  desk". The original is `C:\Users\treyn\Downloads\SBD Central Chrome
  Powerlifting Emblem.png` (1254 x 1254, transparent); its plates sit behind
  the shield, so they are not cut out. Instead `deskLogo` draws a barbell in
  the SurfaceGui (Frames with UIGradient chrome / red plate shading, UICorner,
  black UIStroke rims): a bar end to end, per end a sleeve tip, 4 plates
  (3.8/3.8/3.2/2.6 tall) and a collar, mirrored; the whole emblem 4 x 4 in
  the middle in front (`StarterGymConfig.DeskBarbell`, DeskLogoAspect 1).
  Verify also counts 1 bar and 8 plates. luau-lsp 0 errors, `rojo build`
  OK, `git diff --check` clean. NOT yet seen in Studio.
  User (2026-10-21): wanted only the logo's own LETTERS + BARBELL covering
  the desk. The emblem is one opaque block (letters painted on the shield)
  and barbell-over-letters is ~1.36:1, so a cut-out is only ~5.4 studs wide.
  User chose: THEY make a wide version in their logo tool (barbell over
  "SBD CENTRAL" on one line, transparent, ~5:1); Claude then trims it,
  splits it into pieces <= 1024 px (Roblox's image limit), the user uploads
  them (group as creator), and the code places them across the whole desk
  front (replacing the emblem + drawn barbell, which is the code state now).
  Wide logo received (2026-10-21; the user's first try was replaced by
  `C:\Users\treyn\Downloads\Chrome Barbell SBD Central Logo.png`, 2172 x
  724, transparent). Trimmed to y 94..657 (2172 x 564) and cut into 3
  pieces of 724 x 564: `art/logos/SBDCentral_DeskBanner_1-3.png` (the
  user's own logo; whether to commit them to the PUBLIC repo is the user's
  call, ask at commit time). Code: the emblem and the drawn barbell are
  GONE; `StarterGymConfig.DeskLogoPieces` (3 x {image, widthPixels}),
  DeskLogoHeightPixels 564, DeskLogoHeightStuds 4 -> 15.4 x 4 studs on the
  22 x 4.1 desk front; `deskLogo` places a Frame "Logo" with ImageLabels
  Piece_1-3 edge to edge (adds nothing while any ID is empty). Verify:
  fails while any ID is empty, else checks the 3 pieces. Preview (scratchpad,
  edge-safe drawing) joins without seams. luau-lsp 0 errors, `rojo build`
  OK, `git diff --check` clean. WAITING: the user uploads the 3 pieces
  (group as creator) and sends the 3 IDs in order 1, 2, 3.
  IDs set (2026-10-21), ordered by their Roblox asset names (the user's
  list had 2 and 3 swapped): 1 = 72367430802433, 2 = 137359481610495,
  3 = 72007290259241; all type Image, creator Group 529442797.
  User (2026-10-21): signs "too bland". (1) Desk front: Claude added, in
  code (`StarterGymConfig.DeskFrontDetails`, `StarterGymBuilder.deskFront`,
  SurfaceGui now named "DeskFront"): Desk_Front material Marble (look
  DeskFront), chrome trims top/bottom (UIGradient), a black band with red
  lines behind the letters, 4 rotated black/red speed slashes per end
  (placed to stay inside the face; rotated GUI is not clipped). Preview in
  the scratchpad (desk_details_preview_A.png) approved by Claude only, NOT
  seen in Studio. (2) Name wall: user wants a MUSCULAR BACK behind "ELITE
  PREP GYM": user makes the art in their logo tool (~3:1, dark), Claude
  crops it to the panel's 22:7, splits it, user uploads; code ready:
  `StarterGymConfig.NameWallArt` (empty = plain panel), `nameOnPanel` puts
  Frame "Art" + pieces behind the text and a black UIStroke on the text.
  Shared helpers `piecesReady` / `addImagePieces`. Verify: desk details
  check; name wall art INFO while empty, else checked. luau-lsp 0 errors,
  `rojo build` OK. Outside FrontSign unchanged (60 x 8; ask if it should
  get art too).
  Back art received: `C:\Users\treyn\Downloads\Crimson Back Double-Biceps
  Silhouette.png` (2170 x 725; its "white smoke" is TRANSPARENT, so it
  fades into the dark panel). Cropped to 2170 x 690 (rows 0..689, the
  panel's 22:7) and cut into `art/logos/EPG_NameWallArt_1-3.png` (723 /
  723 / 724 x 690). User chose (2 previews) to keep the name BIG IN THE
  MIDDLE over the art (layout unchanged). NameWallArt filled with the 3
  widths, IDs empty: verify FAILS on it until the IDs are in.
  Art IDs set (2026-10-21, ordered by asset name; all Image, Group
  529442797): 1 = 79949429252377, 2 = 95378292317440, 3 = 98882870153735.
  User Studio look (2026-10-21, 3 screenshots): name wall art and desk show,
  but (1) the outside sign needs the art too; (2) the logos can't be seen
  THROUGH THE LOBBY GLASS (Roblox's Glass material hides see-through things
  behind it, SurfaceGuis included); (3) the desk front was "buggy": grey
  Marble flicker + white showing at the ends (Desk_End_1/2 shared the
  front's face: z-fighting) and jagged edges (rotated GUI Frames are not
  anti-aliased). Fixes (luau-lsp 0 errors, `rojo build` OK; NOT yet seen
  in Studio):
  - Looks.Glass = SmoothPlastic, transparency 0.7, reflectance 0.15 (new
    optional Look.reflectance, applied in `placed`). Skylight/StairGlass
    still use Glass (nothing behind them needs to show).
  - Desk front is now ONE pre-drawn picture: `art/scripts/build_desk_front.ps1`
    (PowerShell + System.Drawing, anti-aliased) draws white brushed bg with
    faint diagonal lines, slashes, band, red lines, chrome trims and the
    logo (from SBDCentral_DeskBanner_1-3) at 3072 x 573 (22 x 4.1 studs)
    and cuts `art/logos/EPG_DeskFront_1-3.png` (1024 x 573).
    `StarterGymConfig.DeskFrontPieces` (IDs EMPTY until uploaded); the GUI
    shapes, DeskFrontDetails, DeskLogoPieces and the Marble look are gone.
    Desk_End_1/2 now start at frontX + 0.6 (behind the front panel).
  - NameWallArt renamed NameSignArt (+ NameSignArtHeightPixels 690), used by
    BOTH signs; `nameOnPanel` sizes the art by its shape: fills the 22 x 7
    name wall, 25.2 x 8 in the middle of the 60 x 8 outside sign.
  - Verify: desk picture pieces, nothing sharing the desk front's face,
    art on NameWall AND FrontSign, no Glass material in Walls.
  WAITING: the user uploads EPG_DeskFront_1-3 and sends the IDs.
  Desk picture IDs set (2026-10-21, by asset name; all Image, Group
  529442797): 1 = 133447969053464, 2 = 126387502452428, 3 = 116605252867039.
  User Studio look (2026-10-21): the outside sign showed the art only in
  its middle ("make the background fit the whole thing"). Fix: wide art
  for the 60 x 8 sign by `art/scripts/build_front_sign_art.ps1`: the art
  enlarged to full width, blurred (shrink 24x + enlarge) and darkened
  behind, the sharp art at full height in the middle, flattened on the
  panel colour, 3840 x 512 -> `art/logos/EPG_FrontSignArt_1-4.png` (960 x
  512). `StarterGymConfig.FrontSignArt` (IDs EMPTY) + FrontSignArtHeightPixels
  512; haloSign takes art + artHeightPixels per sign. Verify: each sign's
  art pieces right AND the art frame spans the full width. luau-lsp 0
  errors, `rojo build` OK. WAITING: user uploads EPG_FrontSignArt_1-4.
  The user's verify output for the desk-picture version was not shared.
  FrontSignArt IDs set (2026-10-21, by asset name; all Image, Group
  529442797): 1 = 82111432062100, 2 = 111820337142904, 3 = 79408703692167,
  4 = 118298598117791.
  Studio result (user, 2026-10-21): "All checks passed and everything
  looks good" (StarterGym_VerifyShell; the screenshot and output lines did
  not come through). STAGE 4 DONE in Studio. COMMITTED and pushed
  2026-10-21 with user approval as "Build the Starter Gym reception with
  the SBD Central desk and Elite Prep Gym signs (stage 4)" (`git log` for
  the hash). The user chose to INCLUDE the pictures (`art/logos/`, 13 PNGs,
  ~9.6 MB) in the public repo, with `art/scripts/build_desk_front.ps1` and
  `build_front_sign_art.ps1`.
  AUTOMATIC ENTRANCE DOORS (user, 2026-10-23, new session; asked for before
  lighting; recorded in GAME_DESIGN §27): BUILT, NOT YET STUDIO-TESTED, NOT
  committed. User then asked (screenshot) for the same on the lobby's 46 x 10
  opening into the hall. `StarterGymBuilder.autoDoor` (called by
  `buildDoors`, folder Doors) makes one Model per opening (tag `AutoDoor`,
  ModelStreamingMode Atomic), on the lobby side of the glass: a steel
  Header, a SensorBox with a red SensorLamp, an invisible non-solid Sensor
  (opening + 2 per side, 10 studs out on both sides), and panel models
  (solid glass in a decor aluminium frame, attributes ClosedPivot +
  OpenOffset) that slide out behind the fixed glass. EntranceDoor: 1 panel
  per side (Panel_Left/Right). HallDoor: 2 per side (Panel_Left_1/2 ...),
  telescoping on separate layers, because one 23-stud panel would not fit in
  the 90-wide lobby when open (open they reach X +/-35.2). New client `src/client/World/AutoDoorAnimator.luau`
  (started in `init.client.luau`): every screen opens the door while any
  character's root is in the sensor, closes it DoorHoldOpenSeconds (1) after,
  slide DoorSlideSeconds (0.6), lamp green/red. The server's panels stay
  closed and solid; your character collides with your screen's copy.
  Config in `StarterGymConfig` (AutoDoorTag, DoorSensor*, DoorSlide/Hold,
  panel sizes, EntranceDoorPanelsPerSide 1, HallDoorPanelsPerSide 2; looks
  GlowRed, DoorFrame). Verify, per door: tagged, sensor, panels fill the
  opening closed, clear it open, hit nothing and do not run into each other.
  Studio result (user, 2026-10-23): "Both doors work and the verify script
  passed" (output lines not shared). DOORS DONE; COMMITTED and pushed
  2026-10-23 with user approval as "Add automatic sliding glass doors to the
  Starter Gym entrance and hall opening" (`git log` for the hash).
  v2 STAGE 5 (LIGHTING) BUILT, NOT YET STUDIO-TESTED, NOT committed (user,
  2026-10-23: "Start lighting"; style already approved: References/Visual
  Style "bright, clean, even lighting"):
  - `default.project.json` Lighting (Rojo applies it on Connect; the user
    must SAVE the place for the live game): Ambient 0 -> (0.43, 0.43, 0.45),
    OutdoorAmbient (0.5, 0.5, 0.52), Brightness 2 -> 2.5, ClockTime 14,
    EnvironmentDiffuseScale 1, EnvironmentSpecularScale 0.5, Technology
    Voxel -> Future (phones: check in milestone step 7).
  - `StarterGymBuilder.buildLights` (folder Lights): white Ceiling_Room_*
    (Roofs) under every ground-floor room except the lobby (it has
    Lobby_Ceiling), Soffit_Front/Left/Right (Balcony) under the balcony, a
    6 x 6 neon RoomLight_<Name> panel with a SurfaceLight in every room but
    the lobby (25), and 9 x 3 HallLight bars hanging 2 below the hall's tie
    beams on cables (27). All SurfaceLights without shadows. Config in
    `StarterGymConfig` ("Lighting" block).
  - Verify: Lighting is Future / ambient not dark / daytime; an upward ray
    in every room hits a ceiling; 22 rays under the balcony hit Soffit_;
    every room light; 27 hall bars.
  - luau-lsp 0 errors in the changed files, `rojo build` OK (Technology
    token 4 = Future), `git diff --check` clean.
  Studio result (user, 2026-10-23): "The lighting looks good and the verify
  script passed" (output lines and screenshots not shared). STAGE 5 DONE in
  Studio; COMMITTED and pushed 2026-10-23 with user approval as "Light the
  Starter Gym and give its rooms white ceilings (stage 5)" (`git log` for
  the hash). Whether the
  user saved the place with the new Lighting settings: not stated.
  MILESTONE STEP (6) PROPS AND DECORATION (user chose it 2026-10-23 over
  step 7). Room plan proposed by Claude and APPROVED by the user (recorded in
  GAME_DESIGN §27 "What is in the rooms"): 6a ground floor, 6b upstairs (with
  new names for Room1-8 and the upper corners), 6c the rack hall.
  STEP 6a (ground floor) BUILT, NOT YET STUDIO-TESTED, NOT committed:
  - Corner ground rooms renamed CornerLeft -> Showers, CornerRight -> Kitchen
    (`StarterGymConfig.Rooms.CornerGround`).
  - New `src/server/World/BuildParts.luau`: placed/box/surfaceLight/decor,
    moved out of StarterGymBuilder (same code; surfaceLight takes an optional
    colour) so RoomProps can share them.
  - New `src/server/World/RoomProps.luau`, called by StarterGymBuilder after
    the lights: folder Props/<Room> for Lockers, Showers, Cafe, Kitchen,
    Office, Recovery, Massage, Physio, Storage, Sauna, Coach, Shop. Each room
    is furnished in a Kit frame (a across, d from the door wall, y up; 0.55
    inset from the region). Big pieces solid, small items Decor. A solid
    piece in a door's keep-clear zone (own door, or a neighbour's door in its
    wall, e.g. Lockers -> Showers) or anything outside the room makes THAT
    room fail with a "[RoomProps] <room> left empty" warning; the gym still
    builds. Sauna heater has a warm PointLight. Text boards (cafe menu,
    coach whiteboard, physio poster, shop sign) are SurfaceGuis "Writing".
  - New looks in StarterGymConfig (LockerBody, Wood, SaunaWood, Tile, Mat,
    Padding, PaddingBlue, Water, Cardboard, Whiteboard, Mirror, Plant, Stone,
    GlowWarm, Plate*).
  - Verify: every ground room but the lobby has >= 10 prop parts, all inside
    the room, no solid prop within 7 studs of any door (both sides), no
    solid prop inside a wall.
  - luau-lsp 0 errors in the new/changed files (only the known section 5
    errors elsewhere), `rojo build` OK. No Luau runtime on this PC, so the
    layouts were only checked by hand: watch the Output for RoomProps warnings.
  User look (2026-10-23, screenshots + reference photos): Sauna and Shop
  "look basic, like filler"; the sauna must look like a real sauna with no
  open door; the shop should look like an SBD-style gear stand with models
  that look like real knee sleeves, wrist wraps, a lever belt and a singlet.
  "Every room just looks so basic." (The 6a Studio verify result was not
  reported.) Response, in progress (NOT yet Studio-tested, NOT committed):
  - SAUNA rebuilt: `StarterGymBuilder.swingDoor` (StarterGymConfig
    SwingDoorRooms = { "Sauna" }) fills the 6 x 9 doorway with a wooden frame
    (through the wall and the 0.55 inset) around a 3.6 x 7.6 wooden door with
    a bronze window and a "SAUNA" plaque, Doors.SaunaDoor tagged AutoDoor; the
    panel model's pivot is the hinge (ClosedPivot/OpenPivot, 90 degrees into
    the room); `AutoDoorAnimator` now also swings (CFrame Lerp about the
    pivot). RoomProps Sauna: wood floor, boards on all 4 walls up to the
    ceiling (front: around the door and one small window), wooden ceiling at
    10, two slatted bench tiers with skirt boards, backrest, warm LED strips
    under both tiers, duckboard, heater with stones, steel shield and a
    wooden guard rail, slatted corner lamp, bucket and ladle, thermometer,
    towels. No white panel: StarterGymConfig.OwnLightRooms. Kit: new "front"
    wall; H is now just under the ceiling. Verify: SaunaDoor check (solid
    panel, swings clear of the middle of the gap), light check skips
    OwnLightRooms.
  - SHOP GEAR models: `art/scripts/build_shop_gear_01.py` (run in Blender;
    saved as `art/blender/ShopGear_01.blend`): KneeSleeve, WristWrap (rolled),
    WristWrapHanging, LeverBelt, MannequinSinglet, MannequinTee (armless
    torso forms with arm stubs on stands), 23 objects, ~20k triangles, one
    material per object, black/red/grey/steel, NO brand names on the items.
    User review 1 (2026-10-23, photo of a real singlet): the singlet must be
    a one-piece with legs; "never empty boxes, put CENTRAL in them" (GAME_DESIGN
    §27, memory). Rebuilt: MannequinSinglet form with thighs (pole behind
    them), shell with red side columns, red Trim band round a high round
    neck and deep armholes (exact booleans: Black/Red minus big cylinders,
    Trim = shell AND big minus small), Shorts/ShortsRed as separate objects
    (the boolean dropped a leg when they were in the same mesh), crotch cap
    0.03 below the form. Fixed: radius lookup below the hips used the form's
    r = 0 pole. "CENTRAL" in Montserrat Black (found in the Roblox install,
    OFL) projected onto every badge: chest badges, knee sleeve (wrapped on
    the cylinder), raised black on the belt lever, white on both wraps.
    29 objects, ~28k triangles. Blend saved.
    User review 2: the words were too small. Chest badges about twice as
    big (singlet 0.68 x 0.2, text 0.15; tee 0.96 x 0.3, text 0.22). Saved.
    APPROVED by the user (2026-10-23). Exported `art/exports/ShopGear_01.fbx`
    (29 meshes, project FBX settings). New Command Bar script
    `tools/studio/ShopGear01_PrepareImport.luau` (checks the fresh import,
    sets looks, non-solid decor, groups into 6 item Models with pivots at
    the bottom middle (hanging wrap: top) facing the item's front).
    User (2026-10-23): imported, script "SUCCESS", saved
    `art/roblox/ShopGear_01.rbxmx`. But the saved file was the RAW import
    (default grey Plastic, unanchored, solid, ungrouped; probably saved
    before the script ran). Fixed in the file with the new
    `art/scripts/prepare_shop_gear_rbxmx.ps1` (same looks, groups and
    pivots as the Studio script; refuses anything but the raw import;
    raw copy kept in the Claude scratchpad): 6 item Models, 29 parts
    anchored and non-solid, pivots e.g. MannequinSinglet 2.82 x 5.68 x 1.30
    bottom middle facing -Z. Imported X is mirrored in position only
    (Blender -> FBX -> Roblox is a 180-degree turn, not a mirror).
    `default.project.json`: ServerStorage.PropTemplates.ShopGear_01 ->
    art/roblox/ShopGear_01.rbxmx. `rojo build` OK, the 6 Models and their
    WorldPivotData come through.
  - SHOP rebuilt in RoomProps (not yet Studio-tested): red Carpet look, black
    walls to 11.2, SBD Central logo (StarterGymConfig.ShopLogoPieces = the
    desk banner pieces, re-added) on a back panel between GlowRed lines,
    podium with 3 mannequins (singlet, tee, singlet) + invisible solid
    columns + spotlights, slatwall with 6 hanging wraps, 8 knee sleeves on a
    ledge, 6 rolled wraps, belt shelf with 6 belts and folded tees, black
    counter with the logo, till, table of folded tees. Kit.place clones a
    template by its pivot and refuses if it leaves the room; Kit.toward. No
    templates = bare shop + warning. BuildParts now also holds piecesReady /
    addImagePieces (moved from StarterGymBuilder). Verify: 29 gear models.
    WAITING for the user's approval of the look, then: export FBX, one
    Studio Import 3D, a prepare script, save `art/roblox/ShopGear_01.rbxmx`,
    Rojo-map it, then rebuild the Shop room around it.
  luau-lsp 0 errors in the changed files (with a `rojo sourcemap`; only the
  known section 5 errors elsewhere), `rojo build` OK, `git diff --check` clean.
  ROBLOX STUDIO MCP (2026-10-25, new session): Claude can now run Luau, take
  screenshots, start/stop Play and move the test character in the open place
  (Studio's "Enable Studio as MCP server"; Claude Code server `Roblox_Studio`).
  Code run through it CANNOT read `Lighting.Technology` (Command Bar can).
  Studio results BY CLAUDE via the MCP (2026-10-25, Play, cloud place):
  Output "[RoomProps] Shop: 29 gear models placed", 12 rooms furnished, no
  [RoomProps]/[StarterGymBuilder] warnings (one unrelated line:
  "rbxassetid://203785492 failed", not in our code). `StarterGym_VerifyShell`
  47/49; both failures were in the CHECK: (1) Technology unreadable via the
  MCP -> now an INFO line when unreadable; (2) the Kitchen's upward ceiling
  ray hit the kitchen island -> ceiling rays now skip Props. Then ALL 49
  PASSED. Screenshots: shop (logo wall, 3 mannequins, slatwall, belt shelf,
  counter) and sauna render as built; the sauna door swings open within 5
  studs and closes again. User look: shop fine; sauna door too small and the
  sauna belongs UPSTAIRS in a bigger room ("the room itself looks good").
  SAUNA MOVED UPSTAIRS (user-approved 2026-10-25, GAME_DESIGN §27):
  - `StarterGymConfig.Rooms`: a name repeated in neighbouring places of a
    side block is ONE room across them: RightUpper = { "Sauna", "Sauna",
    "Room6", "Room5" } (old Room8 + Room7, 30 x 54); RightGround's old sauna
    slot is "SupplementBar". New SwingDoorOpeningWidth/HeightStuds 8 x 10,
    SwingDoorLeaves 2, leaves 7.4 x 9 together.
  - `StarterGymBuilder`: `doorFor` (bigger doorway for SwingDoorRooms);
    sideBlock builds joined rooms (one region, door in the middle) and a
    divider only on the floor(s) where the names differ; `swingDoor` builds
    1 or 2 leaves (Panel / Panel_1, Panel_2), each hinged on its outer edge.
  - `RoomProps`: sauna benches via `benchTiers` on the back AND both side
    walls (from 7 studs in), a lamp in each back corner; new
    `FURNISH.SupplementBar` (back bar with 3 blenders, SUPPLEMENT BAR menu,
    drinks fridge, counter with shakers, tub shelves on both side walls via
    `tubs`, two high tables).
  - `StarterGym_VerifyShell`: joined rooms counted once; checks every swing
    door leaf; furniture checks also cover furnished upstairs rooms.
  - Checks by Claude: luau-lsp 0 errors (definitions from the VS Code
    luau-lsp extension), `rojo build` OK, `git diff --check` clean.
  - Studio by Claude via the MCP (after the user's Rojo reconnect): 25 rooms,
    13 furnished, no warnings; VerifyShell ALL 49 PASSED; both leaves open
    (-90/+90) with the character at the door and close after it leaves;
    screenshots of the doors, the sauna inside and the supplement bar. USER
    APPROVED the upstairs sauna (2026-10-25).
  ROOM PURPOSES (user-approved 2026-10-25, recorded in GAME_DESIGN §27 "Room
  purposes"): Physio -> Index (how CN / Competition Scale / meets work),
  Kitchen room -> Staff Room, Coach -> the big front-right upstairs room
  (where the Mobility Studio was), Max Testing = Solo meet room, Warm-up +
  Mobility together, side rooms Dumbbells / Machines / Cardio / Strongman /
  Classroom / Media Room, corners Lounge / Trophy Room; the steak Kitchen is
  a separate building after the gym rooms. NOT BUILT yet (only the room
  names in StarterGymConfig still say Physio / Kitchen / Coach / Room1-6 /
  WarmUp / MaxTesting / Studio; renames come with each room's rebuild).
  KITS AND TOOLS (2026-10-25, outside the repo): fwjelaa Maps / Animations /
  Picture-to-Model kits, UI-Icon-Pack and the art pipeline unzipped to
  `%USERPROFILE%\Downloads\RobloxKits`, safety-checked by Claude (no malware
  patterns; full read of the risky parts only). Only the icon folders "09
  Rank Icons" and "11 Keyboard Keys" are clearly CC0. RULE (user): kit TOOLS
  run on the PC only, never their Studio installers in the game place;
  results enter the game as files via Rojo/Git; the local test place
  `D:\Robloxkittest.rbxl` is only for an installer that must run in Studio.
  Python 3.12.10 + pillow + numpy installed (user scope); the kits find
  Blender only with `$env:BLENDER` set (Blender 5.4 alpha lives on D:\).
  Open Cloud key "Gym asset uploads": user key, asset read+write for group
  529442797 ONLY, IP-locked, expires 2027-01-24, stored outside the repo at
  `%USERPROFILE%\.fwjelaa\roblox-open-cloud.key`; verified by introspect and
  by reading the group's desk-logo asset. Nothing uploaded with it yet.
  COMMITTED and pushed 2026-10-25 with user approval (section 4).
  SUPPLEMENT BAR REMADE WITH THE KITS (pilot, user-approved 2026-10-25;
  GAME_DESIGN §27 "Supplement Bar look" and "Variety, not just red and black"):
  - Textures: 4 CC0 materials picked by the user from a preview sheet
    (ambientCG WoodFloor064, Poly Haven long_white_tiles, ambientCG
    Marble006, ambientCG Planks037A), prepared with the Maps kit's prep step
    (never its upload), uploaded as 12 group-owned images by the new
    `art/scripts/upload_group_images.py` (sets creator group 529442797; the
    Maps kit's uploader only uploads as a user). Ids, sources, licences:
    `art/materials/materials.json`.
  - MaterialVariants: game scripts may NOT create them ("lacking capability
    Plugin"), so they are in `default.project.json` (MaterialService, 4
    variants; needed a Rojo reconnect) and mirrored in
    `StarterGymConfig.MaterialVariants` (the verify compares them). Looks can
    name a `variant`; BuildParts.placed applies it.
  - Room: rebuilt in RoomProps (textured floor, tile wall, charcoal walls,
    marble/plank back bar and counter with slats, red glow and foot rail, neon
    sign, 2 menu screens, 2 lit floating shelves, 3 pendant lamps hung below
    the sign, marble tables).
  - 3D props: `art/scripts/build_sbar_props_01.py` (Blender;
    `art/blender/SBarProps_01.blend`, with a preview shelf) makes 7 CENTRAL
    product shapes + shaker + modern bar stool (29 parts); colourways in
    `StarterGymConfig.SBarColourways` (user: variety, not just red/black).
    Plant: Poly Haven potted_plant_02 via the kit's download step, simplified
    by `art/scripts/prep_sbar_plant.py` (leaves kept, 9k tris). Both exported
    as GLB (`art/exports/SBarProps_01.glb`, `SBarPlant_01.glb`), uploaded as
    group-owned Model assets (SBarPropsAsset 126463004640141, SBarPlantAsset
    72818612497691) and LOADED AT SERVER START by RoomProps
    (InsertService:LoadAsset, split into templates by name prefix, recoloured
    per colourway); no manual Studio import. If loading fails, the bar falls
    back to its part-built props. Placed: 105 products, 6 shakers, 9 stools,
    2 plants (~460 MeshParts; watch on phones in milestone step 7).
  - Studio by Claude via the MCP: no warnings; VerifyShell ALL 50 PASSED
    (condensed but complete copy of the checks, incl. the new textured-
    materials check); screenshots approved by the user.
  - Process notes: take MCP screenshots one at a time (parallel ones mix
    up); the game window must be visible or captures come out white.
  LOCKERS, CAFE AND STAFF ROOM REMADE WITH THE KITS (2026-10-25, user-approved
  in Studio screenshots; GAME_DESIGN §27 "Lockers look", "Private Lockers",
  "Cafe look", "Staff Room look"):
  - Textures: 10 CC0 materials picked by the user from a preview board
    (Lockers: ambientCG Tiles108 floor, Poly Haven oak_veneer_02 slats,
    ambientCG Tiles126 penny tiles; Cafe: Poly Haven herringbone_parquet,
    red_brick_03, ambientCG Tiles032 green tiles, Marble021; Staff Room: Poly
    Haven laminate_floor_03, ambientCG Wood049 worktop, Cork002; the Supplement
    Bar's cream tiles reused as splashback). 30 group-owned images; ids in
    `art/materials/materials.json`; MaterialVariants in `default.project.json`
    and `StarterGymConfig.MaterialVariants` (14 now). Rojo picked the new
    variants up without a reconnect this time.
  - Props: `art/scripts/build_room_props_02.py` (Blender, shared helpers in the
    new `art/scripts/prop_helpers.py`; `art/blender/RoomProps_02.blend` has a
    Preview collection) makes 25 items (lockers, bench, gym bag, bottle, round
    mirror, basin, curtain; espresso machine, grinder, takeaway cup, mug,
    pastry case, donut, muffin, croissant, shell chair, booth, pendant lamp,
    coffee bag; sofa, microwave, kettle, water cooler, retro fridge, staff tee),
    ~22.6k triangles, CENTRAL on every label. Previewed in all colourways and
    approved, exported `art/exports/RoomProps_02.glb`, uploaded as group Model
    asset 93719454817045.
  - Config: the Supplement Bar's prop settings are now general:
    `StarterGymConfig.PropAssets` (all 3 model assets; `whole` for the plant),
    `PropPaints` (paint name -> colour/material/reflectance/transparency),
    `PropFabricPieces`, `PropColourways` (per item, piece -> paint; the SBar
    lines converted from the old arrays, same colours). `CornerGround.Right`
    renamed "Kitchen" -> "StaffRoom". New Looks for the three rooms.
  - `RoomProps`: general prop helpers (`loadPropTemplates`, `propsFor`,
    `propItem`, `productRows`, `pendant`, `roundTable`, `neonSign`, `plaque`,
    `clad` = wall covering with doorway holes, `hidden` solid blockers; Kit now
    knows where the doors in each wall are). The Supplement Bar uses them
    (same layout). New FURNISH.Lockers / Cafe / StaffRoom; the old part-built
    rooms stay as fallbacks (`simpleLockers`, `simpleCafe`, `simpleStaffRoom`)
    when the props do not load. Fix found in Studio: lockers stood 0.02 out of
    the wall (handles make them deeper), moved out.
  - PRIVATE LOCKERS (user: a locker room must not be seen into and needs a
    door): `StarterGymConfig.SwingDoors` replaces SwingDoorRooms/Leaves/sizes
    (per room: Sauna = double wooden doors with windows as before; Lockers =
    one solid oak door, black frame); `PrivateRooms = { Lockers = "LOCKER
    ROOM" }`. `StarterGymBuilder`: the front block's ground glass is built per
    room; a private room's stretch is a painted wall, and its hall side gets
    oak slats with battens and a big glowing sign over the door
    (`privateFront`, decor only). `StarterGym_VerifyShell`: checks every swing
    door from its spec and that private rooms have no see-through wall.
  - Checks by Claude: luau-lsp 0 errors in the changed files, `rojo build` OK,
    `git diff --check` clean. Studio by Claude via the MCP (Play, cloud place):
    13 rooms furnished, no [RoomProps]/[StarterGymBuilder] warnings; Lockers
    121 / Cafe 242 / Staff Room 70 MeshParts; the Lockers door opened at 90
    degrees with the character in front and closed after it left;
    StarterGym_VerifyShell ALL 52 CHECKS PASSED (pasted in full, returning its
    lines). Screenshots approved by the user.
  - Still for the user: SAVE/PUBLISH the cloud place once so the new
    MaterialVariants (and the Supplement Bar's) reach the live game.
  SHOWERS, RECOVERY AND MASSAGE REMADE WITH THE KITS (2026-10-26; textures and
  props approved by the user from a preview board and Blender renders;
  GAME_DESIGN §27 "Showers look", "Recovery look", "Massage look"):
  - Textures: 8 CC0 materials (Showers: ambientCG Tiles035 mosaic floor,
    Tiles010 marble tiles, Terrazzo018; Recovery: ambientCG Rubber004,
    Concrete048; Massage: ambientCG WoodFloor051, Poly Haven
    japanese_stone_wall, painted_plaster_wall). 24 group-owned images (ids in
    `art/materials/materials.json`); MaterialVariants in `default.project.json`
    and `StarterGymConfig.MaterialVariants` (22 now). Rojo synced them without
    a reconnect.
  - Props: `art/scripts/build_room_props_03.py` (`art/blender/RoomProps_03.blend`)
    makes 20 items (rain shower, body wash, shampoo, folded towel, towel on a
    rail, soap dispenser, towel bin, slides; cold plunge, foam roller,
    zero-gravity lounger, massage gun, rolled yoga mat; massage table, oil
    bottle, candle set, diffuser, spa stones, pouf, folding screen), ~26k
    triangles, CENTRAL on every label. Exported `art/exports/RoomProps_03.glb`,
    uploaded as group Model asset 109192629566668 (PropAssets entry 4). New
    PropPaints (Coral, Lime, Sky, Slate, Amber, BlueGlass, Ice), fabric pieces
    and colourways in StarterGymConfig.
  - `RoomProps`: new FURNISH.Showers / Recovery / Massage and a `towelShelf`
    helper; the old rooms stay as `simpleShowers`, `simpleRecovery`,
    `simpleMassage` fallbacks. Fix after the first screenshots: the Showers
    sign glows icy blue (white was unreadable on white tiles) and all its
    walls are tiled.
  - Checks by Claude: luau-lsp 0 errors, `rojo build` OK. Studio via the MCP
    (Play, cloud place): 13 rooms furnished, no new warnings (only the known
    DataStore and 203785492 messages); Showers 159 / Recovery 86 / Massage 95
    MeshParts; StarterGym_VerifyShell ALL 52 CHECKS PASSED (pasted in full).
    Screenshots shown to the user.
  - NEW LAYOUT DECISION (user, 2026-10-26, GAME_DESIGN §27 "Closed rooms and
    the spa wing"): only the Cafe, Supplement Bar and Shop keep glass fronts;
    every other room gets a solid wall and a real door; the left block's four
    upstairs rooms become one private Recovery & Spa wing (one door from the
    balcony, a reception / corridor, bigger closed Sauna, Recovery and Massage
    rooms). Recovery and Massage were committed in their ground-floor rooms as
    a checkpoint and will MOVE (their FURNISH code and props are reused).
  CLOSED ROOMS, SPA WING, THEMED FRONTS (BATCH 1) AND THE STRONGMAN SHED
  (2026-10-26; every step Studio-tested by Claude via the MCP and approved by
  the user from screenshots; GAME_DESIGN §27 "Closed rooms and the spa wing",
  "Themed room fronts", "Strongman becomes an outdoor yard" / "Now a big
  shed"; COMMITTED and pushed 2026-10-26 with the user's approval as "Close the
  gym's rooms with real doors, add the Recovery & Spa wing, themed room fronts
  (batch 1) and the Strongman Shed"; `git log` for the hash):
  - Decisions (user, from a drawn top-down plan): Dumbbells and Machines take
    the ground-floor Recovery and Massage rooms, Cardio the old ground-floor
    Coach room, Coach (with its furniture) moves to the upstairs front-right
    room (was "Studio"), Classroom and Media Room upstairs right, the corners
    are Lounge and Trophy Room; the spa wing = reception + corridor + 3 big
    rooms; the freed upstairs room (where Sauna, then Strongman were) is
    `SpareRoom` ("COMING SOON"), its use decided later.
  - Closed rooms (`StarterGymConfig`: `GlassFrontRooms` = Cafe, SupplementBar,
    Shop; `OpenDoorwayRooms` = Showers; `ClosedRooms` = label / colour / face /
    signWidth / door / plaque per room; `ClosedRoomDoor`; helpers
    `roomNames()`, `roomLabel()`, `swingDoorFor()`). `StarterGymBuilder`: the
    per-floor glass walls became one stretch per room (`hallStretch`): glass,
    or a painted wall with `hallFront` (paint or a themed `face`, door trim,
    skirting, big sign) and a front region `Front_<Room>` in `model.Fronts`;
    every room but the open ones gets a swing door (20 doors). PrivateRooms is
    gone (Lockers keep their oak slats via ClosedRooms.slats).
  - Spa wing (`StarterGymConfig.SpaWing`, `Rooms.LeftUpper` = "SpaWing" x4):
    reception (one door from the balcony), a corridor with light wood floor and
    limewash walls, Sauna / Recovery / Massage off it with their own doors;
    corridor lights in `buildLights`. New `FURNISH.SpaReception` (approved
    textures and props: stone wall, oak desk with marble top, candles, oils,
    pendant lamps, poufs, towel shelf, oak bench, plants).
  - Themed fronts, batch 1 (the user rejected plain colour walls as "lazy";
    the other closed rooms keep the colour walls until their batch):
    `RoomProps.buildFronts` + `FRONT.<Room>` in a FrontKit frame (a along the
    wall, d out, y up; details within `FrontDepthStuds` = 3). Recovery & Spa
    (stone, oak portal and slat bays, planters, uplights), Max Testing (black,
    red/white competition stripes, stage lights, a horizontal barbell rack and
    a vertical gun rack of bars in silver / red / blue / RUSTED (no black bars:
    user), attempt board, judges' lights), Dumbbells (dark diamond plate, steel
    portal, big CENTRAL hex dumbbells, two dumbbell racks), Cardio (red running
    track with lane lines and numbers, speed lines).
  - Strongman Shed (`StarterGymConfig.StrongmanShed`; it went: room front ->
    outdoor yard behind the gym -> yard beside the gym -> a big shed of its own,
    all the same day at the user's request): a separate steel and timber barn
    beside the gym on the Cafe side (12-stud gap, front level with the gym's),
    corrugated walls and roof, trusses, hanging lamps, an always-open roller
    door, a STRONGMAN sign; inside `FURNISH.StrongmanShed` (turf lanes, loaded
    yoke and farmer's handles, rig with chains, atlas stones on stands, tyres,
    logs, sandbags). No door into it from the gym.
  - Art (all previewed and approved before upload; uploaded with the group
    key, ids in `art/materials/materials.json`): textures Strongman_Timber
    (Poly Haven weathered_brown_planks), Strongman_SteelPlates (ambientCG
    MetalPlates013), Dumbbells_DiamondPlate (DiamondPlate008A), Cardio_Track
    (Poly Haven rubberized_track), Shed_CorrugatedSteel (CorrugatedSteel005),
    Shed_Shutter (Poly Haven painted_metal_shutter): MaterialVariants in
    `default.project.json` and `StarterGymConfig.MaterialVariants` (28 now).
    Props: `art/scripts/build_room_props_04.py` (RoomProps_04: atlas stone and
    stand, strongman log, chain, hex dumbbell, dumbbell rack, competition
    plate, planter, wall uplight; Model asset 91749281309773) and
    `build_room_props_05.py` (RoomProps_05: tractor tyre, sandbag, yoke,
    farmer's handle; Model asset 126419721956699); .blend files in
    `art/blender/`, GLBs in `art/exports/`. New PropPaint Granite.
  - Tool notes: the kit's own Python (textures.py) is blocked by the auto-mode
    safety check ("code from external"); texture previews and maps were made
    by Claude's own small scripts instead (session notes folder). Bash breaks
    on apostrophes inside Python heredocs: write edit scripts to a file.
  - Checks: luau-lsp 0 errors in the changed files, `rojo build` OK, Studio via
    the MCP (Play, cloud place): no [RoomProps]/[StarterGymBuilder] warnings,
    15 rooms furnished, 4 themed fronts; StarterGym_VerifyShell ALL 55 CHECKS
    PASSED (new checks: closed rooms not see-through + real doors, the 3 glass
    shop windows, the spa wing, themed fronts, the Strongman Shed). Doors
    opened at 90 degrees with the character in front (Office, spa reception,
    Recovery, Sauna).
  - Open idea, NOT approved (GAME_DESIGN §27): a secret NPC in the shed that
    sells stat boosts; it conflicts with "no room gives CN, technique or
    lifting performance" and needs its own design decision first.
  - Still for the user: SAVE/PUBLISH the cloud place once so the new
    MaterialVariants reach the live game. (d045cd5 was pushed with this commit.)
  OLD NEXT ACTION (2a done below): themed fronts batch 2 (Office, Machines,
  Index, Storage, Classroom, Media Room, Warm-up & Mobility, Coaches, per
  GAME_DESIGN §27), same pipeline: textures and props previewed first.
  THEMED FRONTS BATCH 2A: OFFICE, MACHINES, INDEX, STORAGE (2026-10-26; the
  user split batch 2 into 2a = ground floor and 2b = upstairs; textures picked
  from a preview board, props approved from Blender renders, the fronts
  approved from Studio screenshots; GAME_DESIGN §27 "Batch 2"; COMMITTED and
  pushed 2026-10-26 with the user's approval as "Add themed room fronts batch
  2a: Office, Machines, Index and Storage"; `git log` for the hash):
  - `RoomProps.luau`: `FRONT.Office` (walnut, grooves, brass rail, frosted
    window with blinds, brass wall sconces, GYM MANAGER plate, HELP POINT sign,
    planter), `FRONT.Machines` (steel panels, yellow portal, steel columns, two
    weight stacks, HOW TO USE / MACHINE ZONE boards), `FRONT.Physio` (the Index:
    teal tiles, THE MEET LADDER board with rising steps LOCAL / NATIONALS /
    WORLDS / SHEFFIELD, medals on a brass rail, LEARN THE GAME board),
    `FRONT.Storage` (green corrugated steel, yellow kick band, stencils, crates
    on a pallet, bumper-plate stacks); new helpers `frontLetters` and
    `frontBoard`.
  - `StarterGymConfig`: ClosedRooms Office / Machines / Physio / Storage now
    have a `face` (and door look); Looks OfficeWalnut, MachinesSteel,
    IndexTiles, StorageSteel, FrostedGlass, Brass, GlowTeal, GlowGold;
    PropPaint Bronze; PropColourways for the new props; PropAssets +
    RoomProps_06.
  - Art (previewed and approved before upload; uploaded with the group key,
    ids in `art/materials/materials.json`): textures Office_Walnut (Poly Haven
    walnut_veneer_02), Machines_SteelPanels (ambientCG MetalPlates001),
    Index_Tiles (ambientCG Tiles107), Storage_Corrugated (ambientCG
    CorrugatedSteel006A): MaterialVariants in `default.project.json` and
    `StarterGymConfig.MaterialVariants` (32 now). Props:
    `art/scripts/build_room_props_06.py` (RoomProps_06: weight stack, wall
    sconce, wooden crate, pallet, flat bumper plate, medal; Model asset
    89330038688157), `art/blender/RoomProps_06.blend`,
    `art/exports/RoomProps_06.glb`.
  - Verify: `THEMED` in `tools/studio/StarterGym_VerifyShell.luau` now lists
    the 4 new fronts.
  - Checks: luau-lsp 0 errors in the changed files, `rojo build` OK, Studio via
    the MCP (Play, cloud place): "8 themed fronts", no [RoomProps] warnings;
    StarterGym_VerifyShell ALL 55 CHECKS PASSED (run twice, the second time
    after the last fix). Fixed after the first screenshots: walnut and steel
    tinted darker, teal deeper, window blinds visible (dark panel behind),
    ladder steps solid instead of neon, medals 1.4x, bumper plates 0.02 off the
    floor (they flickered).
  - Still for the user: SAVE/PUBLISH the cloud place once so the new
    MaterialVariants reach the live game.
  OLD NEXT ACTION (done below): themed fronts batch 2b (Classroom, Media
  Room, Warm-up & Mobility, Coaches), same pipeline.
  THEMED FRONTS BATCH 2B AND THE NAME PLAQUES (2026-10-26; textures picked
  from a preview board, chalk drawings and props approved from previews, the
  fronts approved from Studio screenshots; GAME_DESIGN §27 "Batch 2b
  approved" and "Name plaques instead of big signs"; committed and pushed
  with the user's approval as a save point; `git log` for the hash):
  - `RoomProps.luau`: `FRONT.Classroom` (chalkboard, oak frame and pillars,
    chalk tray, four chalk drawings as ImageLabels, clock), `FRONT.MediaRoom`
    (foam panel grid, ON AIR lamp, red mic, equaliser, headphones),
    `FRONT.WarmUp` (oak slats over a sage dado, MOVE WELL / LIFT WELL, bands
    on a rail, roller racks, routine board, planters), `FRONT.Coach` (stripes,
    whiteboard programme, coach name plates, clipboards, clock, planters);
    helpers `wallClock`, `frontPlanter`. Batch 2a and 1 fronts shifted clear
    of the new plaques (Office lamps up, Machines stacks out, Index medals
    left, Storage stencils right, Cardio streaks, Max Testing gun rack and
    full-width stage lights, spa bays).
  - Name plaques (user: "instead of the big ugly text on top of every room, a
    small sign", photos; "wall plaque only", names only):
    `StarterGymBuilder.hallFront` builds a plaque (steel back on stand-offs,
    black face, pale-gold name) instead of the big glowing sign;
    `buildDoors` drops the over-door plaque where a room has a hall front.
    Config: `StarterGymConfig.NamePlaque`, ClosedRooms `plaqueSide` /
    `plaqueOffset` (signWidth removed).
  - Art (previewed and approved; group-owned, ids in materials.json):
    textures Classroom_Chalkboard (ambientCG Plaster001), Media_Foam
    (AcousticFoam003, colour map lightened so tints show), Media_Felt
    (Fabric030), Coaches_Panels (Poly Haven white_planks_clean): 36
    MaterialVariants now. Chalk drawings `art/scripts/draw_chalk_lessons.py`
    (4 transparent PNGs, `StarterGymConfig.ChalkLessons`; the uploader now
    has an "images" section). Props `art/scripts/build_room_props_07.py`
    (RoomProps_07: studio mic, ON AIR lamp, headphones, resistance band,
    MobilityRoller, roller rack, clipboard; Model asset 111460003222169).
    Two earlier uploads of RoomProps_07 are unused (listed in materials.json
    "supersedes"): the first named its roller "FoamRoller", which clashed
    with the Recovery room's roller; the second had thin hoop bands.
  - Checks: luau-lsp 0 errors, `rojo build` OK, Studio via the MCP: 12 themed
    fronts, 14 wall plaques, 0 big signs, no [RoomProps] warnings;
    StarterGym_VerifyShell ALL 55 CHECKS PASSED.
  - Still for the user: SAVE/PUBLISH the cloud place once so the new
    MaterialVariants reach the live game.
  THE OPEN DUMBBELL & MACHINE ZONE, THE CHALK RECORDS WALL AND THE MIRROR
  (2026-10-26; plan approved by the user, built, Studio-tested and APPROVED
  from screenshots; COMMITTED and pushed with the user's approval as "Open
  the dumbbell & machine zone, add the chalk records wall and a real mirror";
  `git log` for the hash):
  - `StarterGymConfig`: `OpenToHall = { TrainingZone }`, column spacing and
    size, `RecordsWall`; Rooms.LeftGround = Office + TrainingZone x3;
    ClosedRooms Dumbbells / Machines / Physio removed; `swingDoorFor` gives
    open zones no door; Look `GymMirror`.
  - `StarterGymBuilder`: side-block floors per stretch (rubber up to the hall
    under an open zone), `openZone` (region + columns with yellow bands, no
    wall or door), a row of ceiling panels in long open zones, the
    `Front_RecordsWall` region on the hall's back wall.
  - `RoomProps`: `FURNISH.TrainingZone` (framed mirror, DUMBBELLS / MACHINES
    neon, 5 dumbbell racks, 4 benches, 5 cable stations), `FRONT.RecordsWall`
    (leaderboard, main records, meet ladder; helpers `displayBoard`,
    `boardGui`, `boardText`), Office help point "HELP POINT & GUIDE" and a
    LEARN THE GAME board inside; FRONT.Dumbbells / Machines / Physio and
    FURNISH.Physio removed (in Git history).
  - Verify: new check "zone open to the hall: nothing but its columns";
    closed rooms >= 11; THEMED and MUST_FURNISH updated. Full run 55 of 56
    passed; the one failure was the new check sampling inside the Office's
    divider wall, fixed (skips the end walls) and re-run on its own: passes.
  - Records wall redone as a CHALK wall (user, 2026-10-26, photos of gym
    record boards): `FRONT.RecordsWall` = a black chalkboard (Look
    `ChalkWall`, the Classroom chalkboard texture tinted black; no upload) in
    an oak frame, the GYM RECORDS table (rows = `WeightClassConfig.Classes`,
    smallest first; columns SQUAT / BENCH / DEADLIFT / TOTAL), the meet
    ladder and a "big three" barbell in chalk (Roblox fonts PermanentMarker
    and PatrickHand). For the later records system: SurfaceGui
    "RecordsTable", one Frame per record "Record_<class label>_<LIFT>"
    (attributes WeightClass, Lift) with "Avatar" (ImageLabel for
    Players:GetUserThumbnailAsync HeadShot), "Holder" and "Kg" labels. A
    preview filled the 83 kg row with the user's avatar and made-up numbers
    in a test run only (not saved). Front check: 10 fronts, 0 outside, 0 at
    a door.
  - A REAL MIRROR (user, 2026-10-26: "make this mirror reflect like a
    mirror"; Roblox Reflectance only mirrors the sky): new client module
    `src/client/World/MirrorController.luau` (started in
    `init.client.luau`): for parts tagged `StarterGymConfig.MirrorTag` with a
    "Facing" attribute (the zone's mirror; RoomProps tags it), a SurfaceGui
    in PlayerGui with a ViewportFrame: the room in front (MirrorDepthStuds
    70 deep, MirrorSideStuds, MirrorHeightStuds) copied and reflected across
    the glass, players' characters copied and reflected every frame (copied
    parts matched by name path: some character children are not cloned);
    the viewport camera stands at the player's camera looking straight at
    the glass, the frame centred on the point in front of it (exact
    window-into-a-mirrored-room projection), FOV capped at 120. Only within
    MirrorRangeStuds (70); built on approach, thrown away when far. Tested in
    Studio via the MCP: ~330 copied parts, the player's reflection follows
    them (x 118 -> 130.7 behind glass at 124.4), screenshots. Visual only,
    nothing sent to the server. Not tested on a phone yet (performance).
  - Leftovers: the MaterialVariants Dumbbells_DiamondPlate and
    Machines_SteelPanels are reused in the zone; Index_Tiles is now unused.
  THE OPEN ZONE'S MACHINES (2026-10-26; the user picked this step and the
  machines, changed two from Blender previews with photos, said yes to the
  upload and APPROVED them in Studio screenshots; COMMITTED and pushed with
  the user's approval as "Add the open zone's machines: tricep and lat
  pulldowns, seated rows and leg extensions"; `git log` for the hash):
  - At the start: StarterGym_VerifyShell ALL 56 CHECKS PASSED (fresh Play).
  - `art/scripts/build_room_props_08.py` (art/blender/RoomProps_08.blend,
    art/exports/RoomProps_08.glb): TricepPulldown, LatPulldown, SeatedRow,
    LegExtension; a shared `stack()` (plates with kg numbers, top plate,
    rods, pin, shroud panels with CENTRAL), `pulley()`, `cable()`; drawn at
    the WeightStack's size and shrunk by SCALE 0.85 to the racks' scale
    (players ~5.7 studs, racks 7). The first idea, a dual cable tower, was
    replaced by the tricep pulldown and the seated row got visible pulleys and
    a double-D handle (user feedback with photos). 52 pieces, ~33k triangles
    (largest 4.3k). Uploaded as group Model asset 83964902060436
    (materials.json "RoomProps_08").
  - `StarterGymConfig`: PropAssets + RoomProps_08; PropColourways for the
    four machines via a local `machine()` helper (3 mixed colourways each,
    same as the Blender COLOURWAYS).
  - `RoomProps`: `FURNISH.TrainingZone` places 8 machines (back wall: two
    tricep and two lat pulldowns; end wall: two leg extensions and two
    seated rows), each with hidden solid blocks; the five plain WeightStack
    stations are gone (the WeightStack prop stays on the Machines front).
  - Checks: luau-lsp 0 errors in the changed files, `rojo build` OK, Studio
    via the MCP: 8 machines placed, 12 solid blocks, no [RoomProps]
    warnings, StarterGym_VerifyShell ALL 56 CHECKS PASSED; screenshots.
  - Still for the user: SAVE/PUBLISH the cloud place (the scripts sync by
    Rojo; the place itself holds no new objects for this step).
  THE CARDIO ROOM (2026-10-26; the user picked "look-only + fun", approved
  the drawn plan and Blender previews, asked for the bike and ski erg fixes
  and APPROVED the room in Studio screenshots; COMMITTED and pushed with the
  user's approval as "Add the Cardio room: 11 machines players can hop on";
  `git log` for the hash):
  - `art/scripts/build_room_props_09.py` (RoomProps_09.blend / .glb):
    Treadmill, ExerciseBike, Rower, SkiErg (3 colourways each); moving pieces
    of their own: ExerciseBike_Crank, Rower_Handle / _Chain / _Pad (seat),
    SkiErg_HandleLeft/Right, CordLeft/Right. Group Model asset 77291688307242
    (materials.json "RoomProps_09"; the first upload 118823401986051 is
    superseded: its bike was sized for real people, so Roblox avatars could
    not reach the pedals). The second upload first failed with Roblox's
    "internal error" and worked on retry (the failed try may have left an
    unused asset).
  - `StarterGymConfig`: PropAssets + RoomProps_09, PropColourways via a local
    `cardio()` helper, `CardioMachineTag`, `CardioMachines` (per kind: label,
    motion, `spot` from the machine's pivot, seated, rower `chainFrom`, ski
    erg `pulleys`, bike `feet` / `hands`), prompt hold and reach.
  - `RoomProps`: `FURNISH.Cardio` (floor, walls, running-track stripe, wall
    TV "CENTRAL TV", heart-rate zones board, 4 treadmills, 3 bikes, 2 rowers,
    2 ski ergs, water cooler; each machine tagged, Kind attribute, hidden
    solid block).
  - New `src/server/World/CardioMachineService.luau` (started in
    init.server after the gym): a "Hop on" ProximityPrompt per machine; the
    server checks alive / not on a machine / not posed at a rack / near /
    machine free, anchors the player on the spot (seated: hips from the hip
    joint, Motor6D or AnimationConstraint), marks character "CardioMachine"
    and machine "Rider"; releases on Jump (remote), death, respawn, leaving,
    machine removed, putting the player down in front. New
    `src/shared/World/CardioRemotes.luau` (one remote, CardioHopOff, no
    arguments). New `src/client/World/CardioMachineAnimator.luau`: treadmill =
    the avatar's own run animation; rower and ski erg = joint transforms
    timed from the server clock, with the seat sliding, handles following the
    hands and chain / cords stretched (along their longest axis); bike =
    IKControl feet on the pedals and hands on the grips, crank turning
    forward. Lessons: the user's avatar uses AnimationConstraint joints (not
    Motor6D); a CFrame angle built from the raw server clock loses precision
    (wrap it to one turn); Roblox mirrors Blender's X (local x = -x, local
    z = y - centre).
  - Verify: Cardio added to MUST_FURNISH and a new check "the Cardio room has
    its 11 machines, each a known kind with a Hop on prompt" (57 checks).
  - Checks: luau-lsp 0 errors in the changed files, `rojo build` OK; Studio
    via the MCP with real key presses (E to hop on, Space to hop off) on
    every machine type: positions, run track, pedalling, rowing, skiing,
    hop-off cleanup; StarterGym_VerifyShell ALL 57 CHECKS PASSED (after the
    bike remake); screenshots. Not tested: two players at once, a phone.
  THE TREADMILL RHYTHM GAME, PART 1 (2026-10-26; no leaderboard yet; the
  user settled the rules from options, approved the 6 sounds for upload and
  APPROVED the numbers after the Studio test; COMMITTED and pushed with the
  user's approval as "Add the treadmill rhythm game (part 1: rounds, lanes,
  health and our own beat)"; `git log` for the hash):
  - New `src/shared/Config/CardioRhythmConfig.luau` (all the numbers: 100
    health, miss -10, stray press -4, hit window +-0.15 s / perfect
    +-0.06 s, lag allowance up to 0.2 s, 100 BPM +8 per 30-second level up
    to 196, note fall 1.6 s down to 1.0 s; lane keys arrows / D F J K /
    controller; lane colours; sound ids), `src/shared/World/RhythmChart.luau`
    (notes and beats built from the round's seed, the same on server and
    clients), `src/shared/World/CardioRhythmRemotes.luau` (RhythmPress: the
    client only sends a lane; RhythmState; RhythmJudged).
  - New `src/server/World/CardioRhythmService.luau` (started in
    init.server): rounds (5 s countdown, everyone on a treadmill joins, late
    arrivals wait for the next round, results 6 s), judges every press on the
    server clock, misses only drain health, a 15-minute safety stop.
  - New `src/client/World/CardioRhythmController.luau` (started in
    init.client): your own 4 lanes in a panel centred on screen (user's
    request), tap zones on phones, the wall TV shows the round with every
    runner's name and health; the beat plays from the TV (kick on odd beats,
    snare on even, hi-hat on half beats from level 2), Hit / Miss / Count in
    your own ears.
  - Sounds: `art/scripts/make_rhythm_sounds.py` makes 6 original WAVs
    (`art/sounds/Rhythm_{Kick,Snare,Hat,Hit,Miss,Count}.wav`).
    `art/scripts/upload_group_images.py` now uploads `.wav` as group Audio
    (manifest section "sounds", ids under "audio"); uploaded as group audio
    85088925719114 / 99723722634680 / 139986629908272 / 111016778868160 /
    127344920469973 / 105244845446461 (materials.json "sounds").
  - Checks: `rojo build` OK; Studio via the MCP (fresh Play, Treadmill_2,
    E to hop on, Space to hop off): all 6 sounds load (IsLoaded, lengths
    0.08-0.45 s); countdown beeps 1 s apart; kick/snare every 0.600 s at
    level 1 and 0.555 s at level 2 (108 BPM); hi-hat starts at 30.3 s;
    40 presses timed from the round's chart through the real remote were
    all judged PERFECT with the Hit sound; untouched notes judged Miss with
    the Miss sound, out after 10; real D/F/J/K key presses reach the server
    (judged Stray when no note is near) and J does not start a deadlift;
    hopping off during the countdown cancels the round; a runner who stays
    on joins the next round. Screenshots. Not tested: two players at once,
    a phone, a controller; whether the beat sounds good is the user's call.
  STRONGMAN SHED FIXES (2026-10-27, user's request; COMMITTED and pushed
  with the user's approval as f2e8ee1):
  - The tractor tyre looked as if "a huge chunk" was missing: its rubber
    body (from `prop_helpers.lathe_z`) was inside out (640 of 1024 faces
    pointing inward; Roblox draws one side only). `build_room_props_05.py`
    now points its faces outward (`recalc_face_normals`); rebuilt
    RoomProps_05.blend / .glb, the user approved the preview, uploaded as
    group Model asset 102621394697271 (materials.json "RoomProps_05"; the old
    126419721956699 is superseded), `StarterGymConfig.PropAssets` updated.
  - The "STRONGMAN" sign, its red glow bar and `StrongmanShed.label` are
    removed (`StarterGymBuilder`; GAME_DESIGN §27 "Sign removed").
  - Checks: `rojo build` OK; Studio (fresh Play): both tyres use the new
    mesh and render solid, no Shed.Sign / Sign_Glow, no "STRONGMAN" text
    left, shed front screenshot clean; no new errors in Output.
  - Found, NOT fixed (needs the user's go-ahead): `lathe_z` makes every
    lathed shape inside out. Convex ones look nearly right, but other
    hollow or ring shapes may show the same gaps: Chain_Metal (RoomProps_04),
    Sandbag body/strap (05), ColdPlunge, Pouf, FoamRoller, CoffeeCup,
    Donut, etc. (02, 03, 06, 07). A fix in `lathe_z` means rebuilding and
    re-uploading those model files. FIXED in the entry below.
  INSIDE-OUT PROPS FIX (2026-10-27, user's request; COMMITTED and pushed
  with the user's approval as 854c352):
  - `art/scripts/prop_helpers.py`: `lathe_z` turns its faces outward whatever
    way the outline runs (signed area of the outline), `torus` too (always
    anticlockwise ring), `span` accepts its corners in any order (a reversed
    corner pair made an inside-out box: TricepPulldown frame), `rounded_box`
    with a bevel over half the thinnest side now rounds only the edges across
    that side (a flat slab with rounded corners; before, the bevels crossed and
    folded the mesh: GymBag straps/end panels, Microwave door, Towel stripe,
    Clipboard board). Every other rounded box is unchanged.
  - `build_room_props_07.py`: the Headphones' CENTRAL was mirrored (read
    backwards, inside out); `build_room_props_05.py`: the Sandbag's CENTRAL sat
    just under the bag's surface (only visible because the bag was inside
    out), now follows the bag's surface. The tyre's own recalc stays (harmless).
  - Audit (every mesh of RoomProps_02..09, split into connected pieces, signed
    volume + `recalc_face_normals`): 80+ meshes had inside-out pieces in 02..08
    (lathed bottles/cups/mugs/plunge/pouf/plates/shades, torus chains/rings/
    straps/donuts/bars), none in 09; after the rebuild none in any file. The
    saved .blends matched their builders exactly before the rebuild; the fix
    changed shapes only for the four slabs and the two labels. Text pieces show
    "flipped" faces to recalc only because letters are open meshes (fine).
  - Rebuilt + saved RoomProps_02..08.blend, exported GLBs (only the collection,
    export_yup, export_apply, no materials; same object names as before), user
    approved Blender before/after previews (backface culling), uploaded as group
    Models: 02 95409978233696, 03 95190345614206, 04 103672329284661, 05
    125479986784261, 06 71767379502226, 07 122130943505239, 08 122294195016059
    (old ids under "supersedes" in materials.json); `StarterGymConfig.PropAssets`
    updated.
  - Studio (fresh Play): props load from the new assets, no prop errors in
    Output; screenshots: poufs, cold plunges, mugs, cups, sandbags (label
    visible), headphones (CENTRAL reads correctly), gym bag all render solid.
    Before the fix, screenshots showed poufs and plunges missing their near
    walls and mugs see-through at the bottom.
  - Not fixed (separate scripts with their own inline copies of `lathe_z`):
    `build_sbar_props_01.py` and `build_shop_gear_01.py` were not audited.
    FIXED in the entry below.
  SUPPLEMENT BAR + SHOP GEAR FIX AND A PERMANENT CHECK (2026-10-27, user:
  "the chairs are clipping through the floors, make sure every model in the
  future doesn't have the same visual issue"; COMMITTED and pushed with the
  user's approval as 7f1521b):
  - The bar stools stand 0.06 above the floor; their base, seat and foot ring
    were inside out, so the floor showed through. SBarProps_01 had 19 inside-
    out pieces (stool, every tub/lid/label, shaker), ShopGear_01 4 (KneeSleeve
    and WristWrap bodies, both mannequin forms). Fixed the scripts' own
    `lathe_z`/`lathe_x` and the stool's inline foot-ring torus.
  - Permanent check: `prop_helpers.winding_problems`/`check_winding`;
    `Builder.finish` now STOPS the build if a piece is inside out, folded or
    mirrored (tested with broken boxes). New `art/scripts/check_models.py`
    checks every mesh of any .blend (modifiers applied, "Preview" skipped),
    prints CHECK PASSED/FAILED (exit code 1 in -b). PASSED: RoomProps_02..09,
    SBarProps_01, ShopGear_01, Barbell_01, ComboRack_01. CLAUDE.md has a new
    "3D Models" rule: no export/upload unless it passes, preview one-sided.
  - SBarProps_01: rebuilt, saved, GLB exported (same 29 names), uploaded as
    group Model 82461187336012 (old 126463004640141 under "supersedes"),
    `StarterGymConfig.PropAssets` updated.
  - ShopGear_01: rebuilt, saved, re-exported `ShopGear_01.fbx` (project FBX
    settings) and a new `ShopGear_01.glb`, uploaded as group Model
    124788342666123 (new materials.json entry "ShopGear_01"). The game still
    loads `art/roblox/ShopGear_01.rbxmx`: only the four fixed MeshParts' MeshIds
    were swapped there (KneeSleeve_Body 74644086537529, WristWrap_Body
    123733480721433, MannequinSinglet_Form 96507931824892, MannequinTee_Form
    77603604749304); their MeshSize matches the old meshes exactly.
  - Studio (fresh Play): stools, mannequins, knee sleeves and wrist wraps
    use the new meshes and render solid (screenshots); "Shop: 29 gear models
    placed"; no new Output errors.
  - The user published the cloud place afterwards (2026-10-27), so the live
    game has both prop fixes (854c352 and 7f1521b).
  THE TREADMILL RHYTHM GAME, PART 2: THE SAVED LEADERBOARDS (2026-10-27; the
  user picked the board spots (side walls) and the reset (Monday 00:00 UTC)
  and approved the data design (ordered stores only, player save untouched);
  the user approved the boards in Studio; COMMITTED with the user's approval
  on 2026-10-27, see section 1):
  - `CardioRhythmConfig.Leaderboard`: top 10, times in tenths of a second,
    store names `RhythmBest_AllTime` and `RhythmBest_Week_<Monday date>`,
    `Studio_` prefix for Studio, refresh every 60 s, 3 save tries, runs under
    1 s not saved, board tag.
  - New `src/server/World/CardioRhythmLeaderboard.luau` (started in
    init.server): one OrderedDataStore per board, key = UserId, UpdateAsync
    keeps only a better time; a save queue with retries and a BindToClose
    flush; reads both top 10s every minute (names via
    GetNameFromUserIdAsync); draws the boards (avatar headshot, username,
    m:ss.t, gold/silver/bronze ranks, the weekly "resets in"). Studio: API
    access off -> boards in memory with a red "TEST BOARD" line; on ->
    `Studio_` stores. Live servers always use the real stores.
  - `CardioRhythmService`: a runner who is out (health, hop off, leaving,
    15-minute stop) is sent to the leaderboard with the server's own time.
  - `RoomProps` FURNISH.Cardio: two 8.8 x 7.2 board screens (Leaderboard_AllTime
    on the rowers' wall, Leaderboard_Weekly on the ski ergs' wall) with a
    tagged SurfaceGui each.
  - Checks: luau-lsp 0 errors in the changed files, `rojo build` OK. Studio
    (fresh Play, API access off -> "boards: memory"): a real run (E onto
    Treadmill_2, no presses, out on misses) put treylicious1 0:12.7 on both
    boards; a 5 s run (Space to hop off) left 0:12.7; a 20.6 s run (presses
    from the chart through the real RhythmPress remote) replaced it with
    0:20.6; the weekly subtitle read "Resets Monday 00:00 UTC (in 5d 5h)";
    week names checked: Sun 2026-11-01 23:59:59 UTC -> Week_2026-10-26, Mon
    2026-11-02 00:00 -> Week_2026-11-02; a full 10-row layout (sample text
    written into the GUI only, overwritten by the next refresh) fits;
    screenshots of both boards. Output: only the expected Studio line
    "StudioAccessToApisNotAllowed ... GetAsync ... Studio_RhythmBest_AllTime"
    (the one-time probe), no other new errors.
  - NOT tested: real DataStore saves and reads (Studio has no API access;
    first real test is the published game), two servers saving at once, the
    actual Monday rollover, names of players not in the server, two players
    at once, a phone.
  LIVE CHECK PASSED (user, 2026-10-27): published; in the live game a run's
  time was saved and was still on the boards after leaving and rejoining
  ("Saving works"). Still untested: two servers at once, the Monday reset,
  two players at once, a phone.
  RECORDS WALL DECISIONS (user, 2026-10-27, recorded in GAME_DESIGN under
  "A chalk records wall"): meet lifts only; Total = sum of each best meet
  lift (gym wall only, §31.2 unchanged); whole game, saved; ties keep the
  first lifter. Nothing built: the wall needs the meet system first.
  WORLD RECORD / SHEFFIELD CHANGE (user, 2026-10-27, GAME_DESIGN §31 note,
  §31.6, §32.4, §32.5): World Records start empty and are set at Worlds;
  Sheffield (admin-hosted) scores against ReferenceRecordConfig's Total
  records, not the player-set WR; two boards (WORLD RECORD, GYM RECORD).
  New §30.5: a money bonus for taking a gym record from someone else at
  Local/National/Worlds meets (no bonus for empty spots, own records, solo
  meets; one per lift; amounts TBD). Docs only; no code yet.
  SOLO MEET DECISIONS (user, 2026-10-27, GAME_DESIGN §29.10 "The Solo meet
  — first build"): Max Testing room; meet first, nothing saved (Scale and
  records switched on later, after the weight-class build decision); attempts
  chosen one at a time (+/-2.5 kg, % of CN, timer); a cooldown between solo
  meets (30 min, provisional); solo meets never count for the gym record
  wall (official multiplayer meets only; §30.5 and §31.6 updated).
  MOCK MEET PART 1: THE ROOMS AND THE MOVE IN AND OUT (2026-10-27; user:
  rename Max Testing to "Mock Meet Room", and each player gets their own
  private meet room "so its not crowded, or there is no line"; plan approved;
  the user tried it in Studio; COMMITTED with the user's approval on
  2026-10-28, see section 1):
  - Rename: StarterGymConfig ClosedRooms/Rooms key MaxTesting -> MockMeet
    (plaque "MOCK MEET"), RoomProps FRONT.MockMeet, the VerifyShell tool list.
  - RoomProps FURNISH.MockMeet: the gym room is the check-in (black walls, red
    stripe and runway, CHECK-IN desk, MOCK MEET board, waiting chairs, ceiling
    lights); its tagged CheckInPoint gets the prompt.
  - New src/shared/Config/MockMeetConfig.luau, src/shared/Meet/MockMeetRemotes
    .luau (MockMeetLeave), src/server/Meet/MockMeetArena.luau (builds one
    private room per slot at Origin (4000, 1000, 0) + 200 studs per slot, 60
    slots: platform, ComboRack_01 via RackConfigurator without the station
    tag, three judges with unlit light stands, attempt board, banners, lights)
    and MockMeetService.luau ("Start Mock Meet" prompt; checks alive, not
    anchored, not on a cardio machine or at a rack, near the desk, free slot;
    streams the room in, moves the player, player attribute MockMeetSlot;
    Leave puts them back where they checked in; death, respawn and leaving
    clear the room); src/client/Meet/MockMeetController.luau (title and
    "Leave Mock Meet" button). Started from init.server / init.client.
  - Checks: luau-lsp 0 errors in the new and changed files (other files'
    old errors unchanged), `rojo build` OK. Studio (Play, one player): the
    gym room built (17 rooms furnished, no RoomProps warning), the plaque reads
    MOCK MEET; holding E at the desk (the real prompt) put the player in room
    1 at (4000, 1003, -31) with the Leave button; a second trigger while inside
    did nothing; Leave returned them to the desk spot and removed the room;
    checking in again reused slot 1; dying in the room removed it and the
    player respawned in the gym; screenshots of both rooms; no new warnings.
  - NOT tested: two or more players at once (each in their own room), a phone,
    a live server. The look of the rooms needs the user's own check in Studio.
  MOCK MEET PART 2: THE MEET ITSELF (2026-10-28; user: "start Part 2"; NOT
  committed yet; nothing is saved by it):
  - LiftAttemptService: attempt creation moved into createAttempt; new
    startServerAttempt(player, lift, exactKg, onFinished) (weight must lie in
    the usual 40-125% of CN), setFreeAttemptsBlocked (the test keys are ignored
    in a meet), isAttemptActive, abandon (tells the client "STOPPED" so the
    minigame closes). The free-attempt path is unchanged.
  - MockMeetConfig: cooldown 30 min (Studio 15 s), weigh-in 4 s, choose 60 s,
    ready 60 s, result 4 s, opener 90% of CN, 2.5 kg steps.
  - MockMeetRemotes: + Choose, Ready (client -> server), State, Notice
    (server -> client); the MeetState and AttemptView types.
  - MockMeetArena: liftSpot (on the platform, facing the head judge),
    setLights (off / all white / all red), setBoard.
  - MockMeetService: the server-run meet (weigh-in class locked; per lift 3
    x Choose / Ready / Lifting / Result; passes; Done with MeetTotal); the
    cooldown by UserId from check-in (this server only); reads CN and
    bodyweight, writes nothing.
  - New src/client/Meet/MockMeetUI.luau (scorecard, picker, LIFT, verdict,
    results, notices); MockMeetController rewritten to draw the state and
    send the requests (client-side AttemptRules check for greying only).
  - Checks: luau-lsp 0 new errors (LiftAttemptService keeps its one old
    error about PhaseSpec.transitionSeconds), `rojo build` OK. Studio (Play,
    one player, through the real prompt and remotes): weigh-in 53.0 kg -> 59 kg
    class; squat opener range 10-30 kg, suggestion 22.5 (CN 25); server
    refused 31 ("2.5 kg steps") and 32.5 ("between 10.0 and 30.0"), took 25;
    lifter anchored on the platform; LIFT ran the real squat minigame (no
    input) -> NO LIFT (failed SquatDepth), logged at 25.0 kg; attempt 2
    offered 25 again; a test-key request during the meet started nothing; all
    9 attempts ran (no input) -> Done, BOMBED OUT, scorecard all red, board
    "MEET OVER"; Leave from the end returned to the desk; a quick re-check-in
    was refused with "Your next Mock Meet is ready in 0:01", later allowed;
    Leave during a lift stopped it, cleared the room, and (after the fix) the
    minigame closed on screen; screenshots of the picker, LIFT and end screens.
  - NOT tested: a GOOD LIFT and the white lights (needs a person playing the
    minigames), the 60 s choose and ready time-outs, a passed attempt, dying
    mid-lift, two players at once, a phone.
  MOCK MEET PART 2b: NEW LOOK, TYPED WEIGHTS, COACH INSTEAD OF JUDGES
  (2026-10-28; user, from screenshots: the screens were ugly, clicking +2.5
  over and over was too slow, "the coach will be watching", "for a mock meet we
  do not need refs"; NOT committed yet):
  - MockMeetUI rewritten: tilted black cards on white, red tags, heavy italic
    Montserrat; scorecard chips white = good, red = no lift; the action card
    has a typable weight box (Enter or CONFIRM), -5/-2.5/+2.5/+5 nudges, a live
    hint saying what the server would refuse, a timer badge (red under 10 s);
    LIFT ignores clicks for 0.8 s after it appears, so a double click on
    CONFIRM cannot start the lift; the card shrinks when it only shows text.
  - MockMeetController: typed/step handlers; the client checks range, 2.5 kg
    steps and AttemptRules before sending (the server still checks).
  - MockMeetArena: judges, chairs and light stands removed; a coach figure
    (HumanoidDescription R15, navy top, clipboard, COACH tag, speech bubble)
    at the platform's front corner; setLights replaced by coachSays.
  - MockMeetService: the coach speaks on Ready, after each verdict and at the
    end; the attempt board shows GOOD LIFT / NO LIFT.
  - Skills checked (user asked): the "model skill" is make-model in the
    Picture-to-Model kit (scanned clean); no UI skill exists, only the UI Icon
    Pack (pictures); OmniRoute's skills on D:\ scanned clean (not installed).
  - Checks: luau-lsp 0 errors in the meet files, `rojo build` OK. Studio
    (one player): the new screens drawn (screenshots); typing 28 + Enter showed
    "Weights go in 2.5 kg steps." and sent nothing; typing 27.5 / 22.5 / 30 +
    Enter declared them (server -> Ready); no judges in the room, coach present;
    coach lines seen ("Breathe. Brace. Go.", "You had that. Again."); NO LIFT
    card red; Leave cleared the room; no new warnings. Found while testing: the
    Studio screenshot tool clicks the screen centre (it pressed CONFIRM and
    LIFT once), which led to the LIFT delay above.
  - NOT tested: a GOOD LIFT (needs a person), the 0.8 s LIFT delay by a real
    double click, a phone (the cards are fixed pixel sizes), two players.
  Parts 2 and 2b COMMITTED with the user's approval on 2026-10-28 (see
  section 1) before the game-wide restyle below. The user played it: the
  meet works; the look is NOT approved ("UIs overlap ... a BIG no": the
  lift's own minigame bars and verdict draw over the meet card).
  GAME-WIDE UI RESTYLE (user, 2026-10-28, with screenshots of another
  game's menus as direction only, never copied): EVERY screen in one style.
  Picked from options: yellow, white and dark navy with a faint grid; the
  lockout timing check of each lift becomes a shrinking ring (squat yellow,
  bench red, deadlift blue); the bench mash becomes a coloured ring; the
  squat control game restyled; the rack stat picker as a "select your
  goal" panel; the deadlift typing game as a row of pattern boxes; a new
  STATS screen (a key plus a button; Competition Numbers, technique stats,
  class); the "E" prompts in the same style. Rollout order: style kit +
  Mock Meet (overlap fix) first for the user's approval, then the lift
  minigames, the rack menu and prompts, the stats screen, the rhythm game.
  STEP 1 BUILT (2026-10-28, NOT committed): new src/client/UI/UIStyle.luau
  (colours, the lift colours, panel with grid + yellow slab, titleTag,
  sectionHead, button outline/primary/danger, exitButton, ring); MockMeetUI
  rebuilt from it (title top left, LEAVE top right, SCORECARD panel, action
  panel); the action panel stays hidden while lifting AND during the lift's
  own verdict hold (2.5 s), then the meet's verdict (ResultSeconds 4 -> 5).
  Checks: luau-lsp 0 errors in these files, `rojo build` OK; Studio: the new
  look drawn (screenshots); panel visibility measured: hidden while lifting,
  at the verdict and 1.5 s later, shown after the hold; no new warnings.
  STEP 2 BUILT (2026-10-28, user: "Yes, the minigames"; NOT committed):
  ControlUI (squat control: UIStyle panel, yellow bar, white/red marker,
  HOW TO / ATTEMPT / LIVE sections), SkillCheckUI (the lockout of all three
  lifts as a ring closing onto a target; colour by lift via
  SkillCheckConfig.Phases[..].lift; ONE success band drawn exactly at the
  radii of the judged arc, a white line at its centre: SkillCheckConfig has
  no "perfect" zone, so none is drawn; late = the ring keeps shrinking to
  the band's inner edge at the timeout), PowerUI (bench mash: red ring
  closing on the target as progress rises, flash per counted press, yellow
  "get ready" / white HOLD states), TypingUI (deadlift: one box per letter,
  current blue, typed filled, wrong flashes red, NEXT words, vertical bar),
  LiftAttemptController (banner and status as slanted slabs: phase black,
  next yellow, GOOD LIFT white, NO LIFT red). UIStyle.fitToScreen: every
  restyled screen shrinks (UIScale = height/900, min 0.5) on short screens.
  All public functions, inputs, timing and remote calls unchanged (four
  parallel helpers, one file each; reviewed after). Checks: luau-lsp 0 new
  problems (LiftAttemptController keeps its old unused-variable warning),
  `rojo build` OK, LF kept. Studio (556 px tall window, free lifts via the
  RequestLiftAttempt remote, no input): screenshots of squat CONTROL, squat
  DEPTH ring (yellow), bench POWER ring (red), deadlift PULL boxes; banner
  no longer covered by the panels; verdicts as before (squat failed
  SquatDepth, bench failed BenchStart, deadlift failed DeadliftPull, same as
  before the restyle); 0 client and 0 server warnings.
  NOT seen yet: the bench and deadlift lockout rings (red, blue: only reached
  by passing phase 1, needs a person), the bench HOLD states, a good lift.
  STEP 2b (2026-10-28, user from screenshots: "They need to be centered,
  Bigger, Easier to read, The lock out games are really hard to visually tell
  when to press space"; NOT committed): UIStyle gets TextSizes (big 44,
  heading 26, body 20, small 16), UIStyle.text (fixed-size text),
  ShowDevReadouts = false (testing readouts hidden), MinigameCentre
  (0.5, +40 px below centre, clear of the banner), fitToScreen now
  re-anchors top-left pieces at their centre before shrinking (the drift),
  design height 860, min scale 0.6. Second pass on the four minigames (one
  helper per file, reviewed): each is one group anchored at its centre at
  MinigameCentre, ~1.3-1.6x bigger, readable text; the LOCKOUT ring now has a
  thick WHITE press band at exactly the judged radii, the closing ring in the
  lift colour with a glow, and while it is inside the band the target fills
  with the lift colour and a big "NOW!" shows (same clock/angle as the
  press), "WAIT..." before, "TOO LATE" after, a SPACE key cap; squat control
  shows "CONTROL x%" and "MARKER ON/OFF THE BAR"; bench "POWER x%" and
  "HOLDS x/y"; deadlift boxes up to 92 px; banner 32 px text, status 20 px.
  MockMeetUI's action panel anchored by its bottom middle. Checks: luau-lsp
  0 new problems, `rojo build` OK, LF kept. Studio (556 px window, free
  lifts, no input): screenshots of squat CONTROL, the squat DEPTH ring caught
  at NOW!, bench POWER, deadlift PULL; centred, below the banner (bench's
  ring glow just touches the status line in this very small window); lifts
  judged as before; 0 server warnings; 1 client start-up warning
  ("Infinite yield possible on LiftingRemotes": the server took >5 s to
  create the lift remotes while building the gym; not from the restyle).
  Steps 1, 2 and 2b COMMITTED with the user's approval on 2026-10-28 (see
  section 1).
  STEP 3 BUILT (2026-10-28, user: "commit + next"; NOT committed):
  - TrainingMenuController restyled with UIStyle (look only; every request
    and state rule unchanged): a SELECT YOUR GOAL panel with the rack's name,
    WHAT TO TRAIN // LIFT // PRIMARY STAT sections of outline buttons (chosen
    = yellow), the details, START TRAINING (yellow), STOP (red), EXIT under
    the panel (sends "Close" as the old Close button did); the panel fits
    what is showing; the top status strip navy with a yellow edge.
  - New src/client/UI/PromptController.luau (started first in init.client):
    every ProximityPrompt this client sees is switched to the Custom style
    (a local change), and each shown prompt is drawn as a navy tile with a
    yellow key cap (E / gamepad button / TAP), object and action text, and a
    yellow hold bar; on touch or mouse the tile itself holds the prompt.
  - Checks: luau-lsp 0 problems in these files, `rojo build` OK. Studio:
    the rack prompt switched to Custom and drawn (1 tile); holding it opened
    the rack menu (screenshots of the menu, before and after fitting); 0
    client and 0 server warnings. The Studio screenshot tool does NOT draw
    client-made BillboardGuis (even a plain test one), so the prompt was only
    seen as a flat copy on screen: the user must confirm it shows in play.
  - NOT tested: the technique view of the menu, Start/Stop/EXIT clicks, the
    prompt on a phone, the cardio and Mock Meet prompts.
  Step 3 COMMITTED with the user's approval on 2026-10-28 (see section 1).
  STEP 4 BUILT (2026-10-28, user: "commit + stats"; NOT committed):
  - New src/shared/Stats/StatsRemotes.luau (RemoteFunction GetMyStats, the
    StatsSnapshot type) and src/server/PlayerData/PlayerStatsService.luau
    (started after PlayerDataService): answers with a READ-ONLY snapshot of
    the asker's own data (class from bodyweight, bodyweight and target, CN
    and Competition Scale per lift, the five trainable technique stats as
    effective values via TechniqueCurve); writes nothing; at most one ask per
    0.5 s per player.
  - New src/client/UI/StatsScreen.luau (started from init.client): a STATS
    tab on the left edge and the key C (ignored while a text box is
    focused) open a PLAYER STATS panel: avatar headshot, name, class,
    bodyweight/target; COMPETITION NUMBER per lift + total; PROVEN IN A MEET
    (Scale or UNPROVEN); TECHNIQUE radar (pentagon rings at 25/50/75/100,
    yellow value shape, lift-coloured dots, name + value at each corner);
    BACK.
  - Checks: luau-lsp 0 problems in these files, `rojo build` OK. Studio:
    the snapshot read 59 kg class, 53.0 kg, CN 25/25/25, Scale 0, all five
    technique stats 10.0; pressing C (Studio keyboard input) opened the
    panel (screenshots, corner labels fixed after the first), C again closed
    it; 0 client and 0 server warnings.
  - NOT tested: the STATS tab by a real click or tap, the screen with grown
    stats, a phone.
  Step 4 COMMITTED with the user's approval on 2026-10-28 (see section 1).
  STEP 5 BUILT (2026-10-28, user: "commit + treadmill"; NOT committed; two
  parallel helpers, one file each, reviewed):
  - CardioRhythmController (look only): the runner's screen as a UIStyle
    panel at MinigameCentre titled TREADMILL //: LEVEL and time (yellow),
    a 10-segment health bar (red at or below 30%), four navyDeep lanes, a
    yellow hit line with a glow, lane-coloured targets, white notes with a
    lane-coloured edge, D F J K key caps, PERFECT yellow / GOOD white / MISS
    red at 44 px, countdown and OUT big; phone tap areas unchanged; the wall
    TV in the same palette (RHYTHM RUN // tag, info line, runner rows with
    health bars or OUT, results). Key binding, server-clock timing, chart,
    sounds and remotes unchanged.
  - CardioRhythmLeaderboard (drawing only; saving/loading untouched): navy
    grid panel with a white frame and yellow slab, ALL-TIME // or THIS WEEK
    // tag and BEST RUNS, ten rows with rank badges (1st yellow, 2nd white,
    3rd bronze, others navy), headshot, name, time; the red Studio TEST BOARD
    line kept. The server cannot require the client UIStyle, so its colours
    are copied into a local table marked "mirror UIStyle.Colours".
  - Checks: luau-lsp 0 problems in both files, `rojo build` OK, LF kept.
    Studio: hopped on Treadmill_2 through its prompt; screenshots of the
    countdown (GET READY, "1") and of a running round (LEVEL 1, 0:08, health
    draining, a falling note, MISS); Space hopped off; screenshot of the
    restyled ALL-TIME board; 0 client and 0 server warnings.
  - Known: the boards' screens are only 8.8 x 7.2 studs (RoomProps), so the
    rows are small from across the room; the wall TV's idle sign is still the
    old RoomProps "CENTRAL TV" writing; the round's TV view was not captured.
  CARDIO TV MADE IN BLENDER (2026-10-28; user: "I want every model to be
  made in blender" -> memory rule models-made-in-blender; "Yes, upload it";
  COMMITTED with the user's approval on 2026-10-28, see section 1): art/scripts/build_cardio_tv_01.py ->
  art/blender/CardioTV_01.blend (12 pieces: Bezel, Screen, Back, Mount,
  Logo, PowerLight, Soundbar, SoundbarGrille, SoundbarTrim, SoundbarCaps,
  SoundbarLogo, SoundbarBrackets), check_models CHECK PASSED, previewed
  with backface culling, art/exports/CardioTV_01.glb uploaded as group Model
  rbxassetid://127520535803138 (art/materials/materials.json).
  StarterGymConfig: PropAssets + CardioTV_01, PropColourways.CardioTV.
  RoomProps FURNISH.Cardio places it (facing "-d", screen centre at 8.5),
  renames its screen piece "TV" for the rhythm game, puts the CARDIO ZONE
  StyledScreen sign and the blue backlight on it (faces picked from the
  turned pieces); the old block TV is only the fallback if the asset fails
  to load. Studio: model loaded (11 pieces + the TV screen), sign faces into
  the room, screenshot OK; 0 client warnings; 2 server warnings not from
  this change (StreamingMinRadius, 'Technology' capability). Not seen: the
  rhythm round on the new screen.
  CARDIO WALL TV REBUILT (2026-10-28; user: "This Tv is very bland and just
  a square", and "Make sure models are getting updated through context of
  our history of conversations" -> saved as a memory rule; NOT committed):
  RoomProps FURNISH.Cardio: a steel wall mount, a black bezel (blue
  SurfaceLight washing the wall), the glossy screen part (still named "TV",
  in front of the bezel), a chin with a CENTRAL logo and a green power
  light, a soundbar with a yellow trim and two speakers. New styledScreen()
  helper (colours mirror UIStyle.Colours): the idle sign (still named
  "Writing", so the rhythm game still hides it during a round) is a navy
  grid screen with a CARDIO ZONE // tag, four lines with yellow markers and
  a CENTRAL mark. Checks: luau-lsp 0 problems, `rojo build` OK; Studio: all
  9 TV pieces built, screenshots of the new TV; 0 warnings.
  Older in-world screens/signs still in an earlier look (candidates for the
  same treatment): the Mock Meet arena's attempt board and banners (black and
  red), the Mock Meet Room's MOCK MEET board, the coach's speech bubble.
  Step 5 and the TV COMMITTED with the user's approval on 2026-10-28 (see
  section 1).
  VARIED MARKS + MOCK MEET SIGNS (2026-10-28, user: "Commit+ signs but, Not
  every title needs a double line. Change it up sometimes with different
  ques"; NOT committed):
  - UIStyle.cue (slashes / star / chevron / bar / corner / dots / none);
    titleTag and sectionHead take a mark; primary/danger buttons use
    chevrons. Marks mixed across MockMeetUI, the four minigames, the rack
    menu, the stats screen and the treadmill (SkillCheckUI now tints any mark
    in the lift colour).
  - New src/server/World/StyledScreen.luau: in-world screens in the style
    (colours mirror UIStyle.Colours; build() returns setTag/setLines); used
    by RoomProps (the Cardio TV: corner mark; the Mock Meet Room board: star)
    and MockMeetArena (attempt board: bar; banners MOCK MEET: star and THE BIG
    THREE: dots). Coach bubble: white with an ink edge, a yellow accent bar
    and a tail; COACH tag with a white edge.
  - StatsRemotes, MockMeetRemotes and LiftingRemotes wait for their folder
    with no time limit (the server makes them after building the gym), so
    the client's "Infinite yield possible" start-up warnings go away.
  - Checks: luau-lsp 0 new problems (LiftingRemotes keeps 2 older errors),
    `rojo build` OK, LF kept. Studio: screenshots of the Mock Meet Room
    board, the meet screen (star, corner, //, dots, chevrons), the arena
    banners and coach bubble, the live attempt board; 0 server warnings; a
    last run showed 0 client warnings.
  COMMITTED with the user's approval on 2026-10-28 (see section 1).
  PERFORMANCE PASS (2026-10-28, user: "Yes, do the pass"; COMMITTED with
  the user's approval, see section 1; RoomProps: only the hidden() line, the
  Blender TV's RoomProps lines stay with that work):
  - BuildParts.decor: CanTouch off, and CastShadow off for small (longest
    side <= 4 studs) or flat (thinnest <= 0.15) decor; RoomProps.hidden
    blockers cast no shadow.
  - art/scripts/check_models.py: also counts triangles per object; fails
    over TRI_BUDGET (5,000) or an object's own "tri_budget", and over
    Roblox's 20,000; prints the heaviest objects and the file total. Every
    model file passes; ShopGear_01's MannequinTee_Black (5,464, uploaded
    earlier) got tri_budget 6000 in build_shop_gear_01.py and the saved
    .blend (property only, no shape change, no re-upload).
  - New tools/studio/PerformanceAudit.luau (Command Bar, read-only): parts,
    MeshParts, unique meshes, shadow casters, lights, world screens, solid
    decor, precise collision, heaviest rooms, each OK/WARN vs budgets.
  - CLAUDE.md "3D Models": Blender-only models and the performance rules.
  - Measured (Studio Play, server): shadow casters 5,876 -> 2,138; parts
    5,975, MeshParts 3,247, unique meshes 411, lights 144 (0 with shadows),
    world screens 74, solid decor 0, precise collision 0; heaviest room
    Supplement Bar 596 (budget 600): ALL OK. 0 server warnings.
  - NOT checked: how the gym looks with fewer small shadows (user's eyes),
    frame rate on a phone.
  MOCK MEET REWARDS: WEIGHT-CLASS BUILDS, SCHEMA v6 (2026-10-28; decisions,
  plan and save change approved by the user; tested; COMMITTED with the
  user's approval as 368eee0 and pushed):
  - Decisions (GAME_DESIGN §29.11 "Weight-class builds", §33.7, §33.8,
    §33.11 items 9/11, §29.4 note): one build per class, free, kept forever;
    returning restores a build exactly; a first-time class copies the
    closest LIGHTER build's kg (moving up keeps kg, no skipping); every
    class passed through gets a build; Scale never changes class; best
    Total per build; a Mock Meet's good lifts count even if the lifter
    leaves early, best Total only for a finished meet. Game Pass "train
    every class at once" = idea only.
  - Schema v6 (`PlayerProfileSchema`): `builds[classKey]` =
    { competitionNumber, competitionScale, bestTotalKg }; template `builds`
    is EMPTY (Reconcile would plant a template build into every profile);
    `migrations[5]` moves the flat CN + Scale unchanged into the build of
    the current bodyweight's class and removes them; `ensureBuild` /
    `ensureActiveBuild` (run by migrate on every load); old steps guarded
    so a double migration cannot plant 25 kg over a build.
  - `ProfileOperations`: getActiveClassKey / getBuild / getActiveBuild;
    CN read/write go to the active build; `raiseCompetitionScale(data,
    classKey, lift, kg)` and new `raiseBestTotal(data, classKey, kg)` write
    only the named (weigh-in) class's build. Readers updated:
    PlayerDataService log, LiftAttemptService, PlayerStatsService (+
    bestTotalKg), StatsRemotes, StatsScreen (new BEST TOTAL row).
  - `MockMeetService`: weigh-in class = build; after each GOOD LIFT raises
    that lift's Scale (MeetTotal.bestSuccessful) via PlayerDataService.update
    and notifies "New ... Competition Scale"; finished meet with a total
    raises the best Total. Never CN, never records.
  - Probes updated (read the active build; 6 new sections 38-43 in
    PlayerDataProbe). New `src/server/Dev/MigrationFixtureV6.server.luau`
    (ENABLED = false). init.server.luau was temporarily flagged for the
    fixture run and is back to its committed state.
  - Checks: luau-lsp 0 new errors (2 older ones remain, PlayerDataService
    pcall line and LiftAttemptService Attempt table), `rojo build` OK.
    Studio (by Claude): PlayerDataProbe 462/0, TrainingProgressionProbe
    298/0, TrainingStationProbe 205/0; MigrationFixtureV6 on the disposable
    key in the REAL DataStore 30/0, key deleted. The user's real save then
    upgraded v5 -> v6 (59 kg build CN 25/25/25 kept, session 61). Mock Meet
    played by the user in Studio ("Worked"): Squat 22.5 miss / 22.5 good /
    25 good, Bench 3 misses, Deadlift 22.5 good on the 3rd -> Scale
    25 / UNPROVEN / 22.5 saved in the real DataStore; bombed out, so no best
    Total. Studio API access was turned ON by the user for the fixture.
  - NOT tested in gameplay: a finished (non-bombed) meet's best Total
    (covered by the probe and the fixture only); two players at once; a
    phone. Class changes are unreachable until a bodyweight system exists.
  - Rojo note: one file (ProfileOperations) stopped syncing mid-session; a
    rewrite of the file made it sync. If Studio behaves like old code,
    compare a script's Source with the file.
  MOCK MEET BLENDER MODELS (2026-10-28; models approved by the user in
  Blender previews ("Approve, upload"); uploaded; tested in Studio by Claude;
  COMMITTED and pushed with the user's approval, see section 1):
  - `art/scripts/build_mock_meet_01.py` -> `art/blender/MockMeet_01.blend`
    (30 pieces, 5 items): MeetDesk (navy body, oak top, slanted black
    CHECK-IN tag with yellow CENTRAL and // slashes, yellow band, monitor
    facing the clerk, brass bell, clipboard), MeetPlatform (oak planks in
    the middle, charcoal rubber mats on the sides, navy base, yellow edge,
    CENTRAL on the wood in front of the rack), MeetBench (oak slats, yellow
    frame, navy CENTRAL badge), MeetBoard (black frame round the 28 x 12
    screen, yellow slanted CENTRAL header, red trim), MeetBanner (navy cloth
    20 x 6 between steel rails with yellow caps, wall brackets; one mesh for
    both banners). check_models CHECK PASSED (6,476 triangles, heaviest
    piece 656); previewed with backface culling. Exported to
    `art/exports/MockMeet_01.glb`, uploaded as the group:
    rbxassetid://104295814087547 (materials.json).
  - StarterGymConfig: PropAssets entry and the five colourways.
  - RoomProps: `paintProp` split out of propItem; new `RoomProps.propCopy(item,
    colourway)` (a painted decor copy for building outside a room kit); the
    Mock Meet Room's check-in desk is the model with a hidden solid block,
    and its monitor screen shows a small CHECK-IN screen to the clerk side.
    Cardio TV's local face helper moved to `StyledScreen.faceToward` (same
    behaviour).
  - MockMeetArena: platform, attempt board frame, both banners and the wait
    bench are the models (hidden solid blocks for the platform and bench;
    board and banners are decor). The board's screen piece is renamed
    "AttemptBoard" and moved into the room model, so setBoard finds it;
    `hangOnWall` puts wall props' backs on the wall and their screens where
    the old blocks' were. Every piece falls back to the old blocks if the
    asset does not load.
  - Checks: luau-lsp 0 problems on the 4 changed files, `rojo build` OK.
    Studio (Play, by Claude): desk model in the Mock Meet Room (11 pieces,
    no old blocks); checked in with the prompt (E), private room built with
    every model at the old blocks' spots, board shows the live meet
    (lifter, SQUAT ATTEMPT 1), banners show MOCK MEET / THE BIG THREE;
    declared 22.5: lifter placed on the platform top (feet 0.60), meet ran
    to NO LIFT (no minigame played) and attempt 2; leaving (the Leave
    remote) cleared the room and returned the player. 0 errors in Output.
    PerformanceAudit numbers (gym, server): parts 5,982, MeshParts 3,258,
    unique meshes 422, shadow casters 2,139, lights 144 (0 shadows), world
    screens 74, solid decor 0, precise collision 0: all within budget.
  - User in Studio after the commit (2026-10-28): "looks good, leave button
    works" (the models in the game, and LEAVE clicked by hand).
  - NOT checked: a full meet with good lifts on the new platform; a phone.
  BLOCKS -> BLENDER, WHOLE MAP (user 2026-10-28: "Go around the map, and
  everything still made with blocks change into models through blender ...
  If its a micro model/detail it does not have to be SUPER detailed ...
  optimized for when there is actual players"). Read-only Studio count
  (Play, server): 2,501 visible plain blocks. Plan (Claude's proposal,
  shown to the user): architecture stays blocks (walls, floors, ceilings,
  roof panels, glass panes, wall paint and stripes, floor markings, flat
  light panels, hidden collision blocks: plain blocks are the cheapest
  thing Roblox draws); everything that is an object becomes a Blender
  model, in batches, each previewed for approval:
    1 shared furniture (chair, desk, monitor+keyboard, shelf frames,
      boxes, books; plants -> SBarPlant, towels -> Towel)  [BUILT, preview]
    2 light fittings (hall pendants + cables, corridor lights, shed
      lamps, stage lights, spotlights)
    3 doors and the 13 hall-front name plaques
    4 reception (desk, turnstiles, gate railings, merch wall, sign lamps)
    5 Cafe, Supplement Bar, Shop (counters, back bars, tills, fridge,
      blenders, tables, slatwall, podium, tee table, belt shelf)
    6 spa wing (sauna benches/heater/stones/bucket/lamps, shower stalls,
      recovery ladder, massage, spa reception desk)
    7 Staff Room, Storage, Office, Lockers, Training Zone, Strongman Shed
    8 themed fronts (bar rack and bars, judges' lights, foam, equaliser,
      blinds, clocks, boards, slats, battens) and the coach's clipboard
    9 structure details (stairs' railings, balcony railings, roof trusses)
  Performance rule for every batch: one piece per colour, low detail,
  one mesh reused for repeats, stretched meshes for size variants; watch
  the 600 unique-mesh budget (422 now).
  Batch 1: `art/scripts/build_furniture_01.py` -> `art/blender/
  Furniture_01.blend` (OfficeChair, Desk, Workstation, ShelfThree,
  ShelfFour, StorageBox, BookRow; 11 pieces, 1,300 triangles; check_models
  CHECK PASSED; a "Preview" collection holds a staged office scene).
  Approved by the user ("Approve, upload"); exported to
  `art/exports/Furniture_01.glb` and uploaded as the group:
  rbxassetid://80843208048332 (materials.json). COMMITTED and pushed with
  the user's approval (see section 1).
  - StarterGymConfig: PropAssets entry; colourways OfficeChair (2: charcoal,
    navy), Desk, Workstation, StorageBox, BookRow (6 colours).
  - RoomProps: new `stretchTo` and an optional `stretch` size on kit.place
    and propItem (one mesh fits every desk/shelf/box size); propsFor,
    propItem and hidden are declared before the furniture helpers so they
    can use the props. chair() (optional colourway), desk() (stretched, on
    a hidden solid block), monitor() (Workstation, keyboard included, the
    separate Office keyboard block removed), plant() (SBarPlant, kept 1.8
    off walls), shelving(kit, ...) (ShelfThree/ShelfFour stretched and
    coloured with the room's old look, on a hidden solid block; fill
    heights follow the stretched boards), towels/boxes/books(kit, ...)
    (Towel, StorageBox, BookRow). Every helper keeps the old blocks as
    the fallback. Mock Meet waiting chairs use the navy colourway.
  - Checks: luau-lsp 0 problems, `rojo build` OK. Studio Play (by Claude):
    17 rooms furnished, 0 errors; screenshots of the Office (desk, monitor,
    chair, bookshelf, plants), Storage (box shelving) and Lockers (towel
    shelf) look right. Audit: visible blocks 2,501 -> 2,119, parts 5,982
    -> 5,821, MeshParts 3,467, unique meshes 433 (budget 600), shadow
    casters 2,073, lights 144 (0 shadows), screens 74, solid decor 0,
    precise collision 0; heaviest room Supplement Bar 584 (budget 600).
  - NOT checked: the user's own look in the game.
  Batch 2 (light fittings): `art/scripts/build_lights_01.py` ->
  `art/blender/Lights_01.blend`: LightBar (hall bar with its cables,
  stretched), CeilingPanel (room/corridor/Mock Meet room panels,
  stretched), HighBayLamp (Strongman Shed), StageLight (Mock Meet front and
  private room), TrackSpot + TrackRail (Shop); 11 pieces, 1,032 triangles,
  CHECK PASSED; previews sent. The Supplement Bar's block pendants will use
  the existing PendantLamp model. Thin pendant cables under prop lamps stay
  Roblox cylinders (their length differs per room; a mesh adds nothing).
  Approved by the user ("Approve, upload"); exported to
  `art/exports/Lights_01.glb`, uploaded as the group:
  rbxassetid://110775352617639 (materials.json). COMMITTED and pushed with
  the user's approval (see section 1).
  - StarterGymConfig: PropAssets entry, colourways for the six items, and
    PropPaints GlowWhite and GlowGreen (GlowGreen also fixes the Cardio
    TV's power light, which named it but was left unpainted).
  - RoomProps: propCopy takes an optional stretch; new RoomProps.fitting
    (a light model whose glowing piece takes the old block light's name and
    sits straight in the folder, so StarterGym_VerifyShell still finds
    HallLight_* / RoomLight_* with their lights; the rest is
    "<name>_Fitting"; no fitting piece casts a shadow). Supplement Bar
    pendants -> PendantLamp via pendant(); Shop spots -> TrackSpot (the
    SpotLight on its lens) and TrackRail; Mock Meet front stage lights ->
    StageLight (frontProp).
  - StarterGymBuilder: hall bars (LightBar stretched to each segment, with
    its cables), room and corridor panels (CeilingPanel stretched), shed
    lamps (HighBayLamp); `shining` takes the glowing piece's own downward
    face (StyledScreen.faceToward, now required there).
  - MockMeetArena: ceiling-hung StageLight cans pointing down, CeilingPanel
    ceiling lights and board wash.
  - Each keeps the old blocks as the fallback.
  - Checks: luau-lsp 0 problems on the 4 changed scripts, `rojo build` OK.
    Studio Play (by Claude): first run still had the old scripts (Rojo had
    not synced yet); after the sync: 60 room and hall lights, 17 rooms, 10
    fronts, 0 errors; hall 27/27 bars and 26/26 room panels are MeshParts
    with their SurfaceLights, 60 fitting models; shed lens, stage lights
    and shop spot (with its SpotLight) are models; private Mock Meet room:
    stage cans hang from the ceiling over the platform, panels and wash
    lit; screenshots of the hall bars, the Mock Meet front and the private
    room look right. Audit: visible blocks 2,119 -> 1,926, parts 5,807,
    MeshParts 3,646, unique meshes 444, shadow casters 2,046, lights 144
    (0 shadows), screens 74, solid decor 0, precise 0; heaviest room
    Supplement Bar 584. StarterGym_VerifyShell itself was not re-run.
  - NOT checked: the user's own look; the Shop spots and Supplement Bar
    pendants were checked by script only (no screenshot).
  Batch 3 (doors and plaques): `art/scripts/build_doors_01.py` ->
  `art/blender/Doors_01.blend`: DoorLeaf (Leaf, Kick), DoorLeafGlazed
  (Leaf, Glass, Kick), DoorHandle (pull bars both faces), NamePlaque
  (Steel, Face), SlideDoorFrame, DoorSensor (Box, Lamp), DoorSign; 12
  pieces, 760 triangles, CHECK PASSED; preview sent. Plan for placing:
  swing leaves get the leaf model (coloured with the spec's look/handle
  look, stretched) plus an invisible solid slab in the same panel model
  (AutoDoorAnimator only pivots the panel model); sliding panels keep their
  glass pane (PrimaryPart, solid) and get SlideDoorFrame instead of 4
  frame blocks; the sensor lamp keeps the name "SensorLamp" straight under
  the door (the animator finds it by name). Door frames (jambs, header)
  and the hall-front paint, trims and skirting stay blocks (wall infill).
  Approved by the user ("Approve, upload"); exported to
  `art/exports/Doors_01.glb`, uploaded as the group:
  rbxassetid://138346322157297 (materials.json). COMMITTED and pushed
  with user approval on 2026-10-29 ("Commit, then batch 4").
  - StarterGymConfig: PropAssets entry only (no colourways: the pieces are
    painted with each door's own looks).
  - StarterGymBuilder: new doorPiece (propCopy, pivot, paint each piece
    like a block of looks[Piece]); swingDoor: DoorLeaf/DoorLeafGlazed
    stretched to the leaf (Leaf = spec look, Kick = handle look, Glass =
    SaunaGlass) + DoorHandle, inside the panel model, with an invisible
    "Leaf_Solid" slab; the sign over the door is DoorSign (gui face via
    StyledScreen.faceToward); autoDoor: SlideDoorFrame per panel round the
    glass pane, DoorSensor whose lamp is renamed "SensorLamp" under the
    door; hallFront: NamePlaque (gui on its Face piece). Old blocks are the
    fallback everywhere.
  - Checks: luau-lsp 0 problems, `rojo build` OK. Studio Play (by Claude):
    0 errors; 18 leaves with solid slabs and handle pairs, 6 sliding-panel
    frames, 5 door signs, 11 name plaques with text, both SensorLamps are
    MeshParts. Office door: swings the full 90 degrees with leaf, slab and
    handles together (a test character standing in the doorway was pushed
    out by the closed door's slab first, as before). Entrance: both panels
    slide the full 8.2 with their frames; the sensor lamp turns green.
    Screenshot: Office door open, OFFICE plaque (the first capture showed
    the plaque blank before its text loaded). Build summary "254 wall
    parts" (was 320: the plaques are 2 pieces, not 8). Audit: visible
    blocks 1,926 -> 1,722, parts 5,714, MeshParts 3,739, unique meshes 456,
    shadow casters 2,004, lights 144 (0 shadows), screens 74, solid decor
    0, precise 0. StarterGym_VerifyShell not re-run.
  - NOT checked: the sauna's glazed doors and the lobby's hall door opening
    (built the same way); the user's own look.
  Batch 4 (reception): `art/scripts/build_reception_01.py` ->
  `art/blender/Reception_01.blend`, 33 pieces, 4,346 triangles, CHECK PASSED;
  previews sent (backface culling). Items: ReceptionDesk (round the picture
  front, which stays a block: the logo picture is drawn on it and
  StarterGym_VerifyShell checks it), CardReader, LightStrip (stretched),
  Turnstile + TurnstileArm, RailPost + RailRun (stretched; reusable for the
  batch 9 railings), MerchWall (navy, CENTRAL in yellow, shakers and shirts in
  several colours), FloodLamp. The reception monitor reuses the Furniture_01
  Workstation and the desk's light bar the Lights_01 LightBar. The two glowing
  name signs (NameWall, FrontSign) and their halos stay blocks (flat picture
  panels). Approved by the user ("Approve, upload"); exported to
  `art/exports/Reception_01.glb`, uploaded as the group:
  rbxassetid://78320327648297 (materials.json). COMMITTED and pushed with
  user approval on 2026-10-29 ("Commit, then batch 5").
  - StarterGymConfig: PropAssets entry and colourways for the 9 items.
  - StarterGymBuilder buildReception: local prop() and solid() helpers; the
    desk, monitor, card reader, desk light bar, ceiling strips, turnstiles
    and arms, railings, merch wall and sign lamps are the models, with hidden
    solid blocks where the old blocks were solid (desk 4, turnstiles 4,
    railings 2, merch wall 4). Lights keep their names (Desk_LightBar,
    Lobby_LightStrip_n via RoomProps.fitting); the sign lamps' SpotLights sit
    on hidden parts FrontSign_Lamp_n_Aim aimed like the old lamps (the lens
    is tilted in the mesh). The check-in screen is on Workstation_Screen.
    Old blocks are the fallback everywhere.
  - Checks: luau-lsp 0 problems, `rojo build` OK. Studio Play (by Claude): no
    new errors; Reception has 75 MeshParts, 6 visible blocks left (Desk_Front,
    NameWall + halo, FrontSign + halo, Lobby_Ceiling), 14 hidden solids, 10
    lights (the verify script's CeilingStripCount + 6), CheckInScreen facing
    the receptionist. Positions checked by script (ledge to the customers,
    keyboard to the receptionist, lettering out of the wall, lamp lens on the
    street side). Screenshots: desk with the logo front, turnstiles and
    railing, merch wall, outside sign with its lamps. Audit: visible blocks
    1,722 -> 1,604, parts 5,702, MeshParts 3,814, unique meshes 488 (budget
    600), shadow casters 1,988, lights 144 (0 shadows), screens 74, solid
    decor 0, precise 0. StarterGym_VerifyShell not re-run.
  - NOT checked: walking through the turnstile lanes and against the desk
    and railings (the hidden solids are where the old blocks were); the
    user's own look.
  Batch 5 (Cafe, Supplement Bar, Shop): `art/scripts/build_cafe_shop_01.py`
  -> `art/blender/CafeShop_01.blend`, 36 pieces, 4,808 triangles, CHECK
  PASSED; previews sent (backface culling). Items: CounterUnit and WallShelf
  (stretched), Till, RoundTable (stretched to the height), HighTable,
  WindowBar, Blender, DrinksFridge, SBarCounter (39 slats in one mesh),
  Slatwall, Podium, TeeStack (3 colourways), DisplayTable, ShopCounterTop;
  the shop counter reuses the Reception_01 CardReader. Checked first in
  Studio that a MeshPart painted with a textured look (the Supplement Bar's
  ShelfFour in SBar_DarkPlanks) shows the texture, so the counters, shelves
  and table tops are painted with the room's looks (new RoomProps
  paintLooks). Stay blocks: the shop counter body (the logo is drawn on
  it), menu screens, neon signs, the glow strips under shelves and the bar
  counter (light only), the Cafe's STAFF ONLY sign, pendant cables.
  Approved by the user ("Approve, upload"); exported to
  `art/exports/CafeShop_01.glb`, uploaded as the group:
  rbxassetid://135516072435746 (materials.json). COMMITTED and pushed with
  user approval on 2026-10-29 ("Commit, then batch 6").
  - StarterGymConfig: PropAssets entry, colourways for the 14 items, the
    tees in PropFabricPieces.
  - RoomProps: paintLooks and wallProp (a prop stretched to an old block box
    on a wall, facing out); cafeTable, drinksFridge and roundTable use the
    models (so the spa's two LowTables changed too); Cafe, SupplementBar and
    Shop place the models with hidden solid blocks where the old blocks were
    solid. Old blocks are the fallback everywhere.
  - Checks: luau-lsp 0 problems, `rojo build` OK. Studio Play (by Claude): no
    new errors, 17 rooms furnished as before. Visible blocks: Supplement Bar
    111 -> 13, Cafe 52 -> 16, Shop 70 -> 8. Screenshots: the bar (planks,
    black marble, fridge with bottles, blenders, till), the Cafe (green tiled
    counters with marble tops, shelves, round tables), the Shop (slatwall with
    hooks and gear, tee table, podium). Audit: visible blocks 1,604 -> 1,402,
    parts 5,633, MeshParts 3,918, unique meshes 523 (budget 600), shadow
    casters 1,962, lights 144 (0 shadows), screens 74, solid decor 0, precise
    0; heaviest room Supplement Bar 584 -> 523 parts. StarterGym_VerifyShell
    not re-run.
  - NOT checked: walking into the counters and tables (the hidden solids are
    where the old blocks were); the user's own look.
  Batch 6 (spa wing): `art/scripts/build_spa_01.py` -> `art/blender/Spa_01.blend`,
  20 pieces, 3,466 triangles, CHECK PASSED; previews sent (backface culling).
  New items: SaunaBench (stretched), Duckboard (sauna, and stretched for the
  shower stalls), SaunaHeater, SaunaLamp, SaunaBucket, Thermometer,
  ShowerScreen, WallLadder, PlungeStep, FloorMat. Reused to keep unique meshes
  down: CafeShop_01 CounterUnit (spa desk, oak and marble), WallShelf (massage
  shelves, shower shelves in steel), RoundTable (low tables, batch 5), the
  Showers' Towel and LockerBench (sauna towels, spa bench). Stay blocks: the
  sauna's glow strips under the benches (their SurfaceLights), walls, ceiling,
  window and door trims; the shower stall walls and drains; desk glow; pendant
  cables. Approved by the user ("Approve, upload"); exported to
  `art/exports/Spa_01.glb`, uploaded as the group: rbxassetid://72413560307802
  (materials.json). COMMITTED and pushed with user approval on 2026-10-29
  ("Commit, then batch 7").
  - StarterGymConfig: PropAssets entry and colourways for the 10 items.
  - RoomProps: Sauna (bench tiers, duckboard, heater on the old stove block
    now hidden with its light, lamps with their lights on the glow piece,
    bucket, thermometer, towels), Showers (screens, duckboards, shelves),
    Recovery (plunge steps on the old step blocks now hidden, ladders, mats in
    their looks), Massage (shelves), SpaReception (desk on the old body block
    now hidden, bench on the old bench block now hidden). Old blocks are the
    fallback everywhere.
  - Checks: luau-lsp 0 problems, `rojo build` OK. Studio Play (by Claude): no
    script errors (only Studio DataStore messages). Visible blocks: Sauna
    144 -> 23, Showers 69 -> 19, Recovery 46 -> 5, Massage 9 -> 7, Spa
    Reception 11 -> 8; the sauna keeps its 9 lights. Screenshots: the sauna
    benches, duckboard, lamps, thermometer, bucket and towels; the heater
    with stones, shield and guard; Recovery ladders, mats and plunge step.
    Audit: visible blocks 1,402 -> 1,187, parts 5,492, MeshParts 3,983,
    unique meshes 543 (budget 600), shadow casters 1,922, lights 144 (0
    shadows), screens 74, solid decor 0, precise 0. StarterGym_VerifyShell
    not re-run.
  - NOT checked: the showers, massage and spa reception by screenshot (counts
    and names only); walking into the benches and steps; the user's own look.
  Batch 7 (Staff Room, Lockers, Office, Coach, Storage, Training Zone,
  Strongman Shed): `art/scripts/build_back_rooms_01.py` ->
  `art/blender/BackRooms_01.blend`, 25 pieces, 3,608 triangles, CHECK PASSED;
  previews sent (backface culling). New items (1-4 colour pieces each, for
  the mesh budget): KitchenUnit (stretched; base and wall cabinets),
  CorkBoard, HangRail, CoatHook, FilingCabinet, WallClock, WhiteboardFrame,
  Laptop, FlatPlate, BarStand, FlatBench, ChalkStand, StrongmanRig. Reused:
  CounterUnit (locker vanity), WallShelf (cubicle seats), Desk (staff dining
  and coffee tables), Sink (kitchen), StorageBox (spare boxes). Stay blocks:
  the Lockers' 40 oak wall battens (wall trim), cubicle walls, splashback,
  TV/guide/whiteboard/rota title writing surfaces, the mirror and its frame,
  steel wall panels, lane lines. Approved by the user ("Approve, upload");
  exported to `art/exports/BackRooms_01.glb`, uploaded as the group:
  rbxassetid://106359740301632 (materials.json; a first try was refused by
  the connection before reaching Roblox). COMMITTED and pushed with user
  approval on 2026-10-29 ("Commit, then batch 8").
  - StarterGymConfig: PropAssets entry and colourways for the 13 items.
  - RoomProps: Lockers (vanity, cubicle seats on their old blocks now hidden,
    hooks), StaffRoom (base and wall cabinets, sink, dining and coffee
    tables on their old blocks now hidden, rota board, tee rail), Office
    (filing cabinet on its old block now hidden, clock), Coach (whiteboard
    frame, laptop), plateStack (flat plates in their colours), Storage (bar
    stand on the old holder block now hidden, boxes), TrainingZone (benches
    on their old pad blocks now hidden), StrongmanShed (chalk stand and rig on
    their old blocks now hidden). Old blocks are the fallback everywhere.
  - Checks: luau-lsp 0 problems, `rojo build` OK. Rojo first missed the last
    edit (the Strongman Shed); a small comment change synced it before the
    test. Studio Play (by Claude): no script errors, no room warnings.
    Visible blocks: Staff Room 60 -> 11, Lockers 57 -> 51 (the battens),
    Office 7 -> 1, Coach 5 -> 1, Storage 28 -> 0, Training Zone 33 -> 17,
    Strongman Shed 21 -> 10. Screenshots: the Staff Room kitchen and table,
    Storage (bar stand, boxes), the strongman rig. Audit: visible blocks
    1,187 -> 1,067, parts 5,466, MeshParts 4,046, unique meshes 568 (budget
    600), shadow casters 1,910, lights 144 (0 shadows), screens 74, solid
    decor 0, precise 0. StarterGym_VerifyShell not re-run.
  - NOT checked: the Office, Coach, Lockers and Training Zone by screenshot
    (counts and names only); walking into the new pieces; the user's own look.
  Batch 8 (themed fronts, the coach's clipboard): `art/scripts/build_fronts_01.py`
  -> `art/blender/Fronts_01.blend`, 12 pieces, 1,912 triangles, CHECK PASSED;
  previews sent (backface culling). New items: Barbell and BarbellUpright
  (one model per bar, the shaft and steel painted with each bar's looks),
  WallBarRack, GunRack, JudgesLights, Stick (chalk and markers, stretched and
  painted), Duster, FoamTile (painted each panel's colour), Blinds. Reused:
  WallClock (the Classroom and Coach front clocks, scaled to the radius),
  WhiteboardFrame (the Coach front's board, stretched), the Coach front's
  Clipboard (the private meet room's coach, scaled to 1.4 tall). Stay
  blocks: stripes, battens, slats, panelling, dado rails, kick bands, track
  and lane lines, door portals, window frames, signs and screens, the
  chalkboards, the Media Room equaliser (a light display), the Coach clip
  rail and the Warm-up band rail (a stretched HangRail would flatten).
  Approved by the user ("Approve, upload"); exported to
  `art/exports/Fronts_01.glb`, uploaded as the group:
  rbxassetid://82188043511002 (materials.json). COMMITTED and pushed with
  user approval on 2026-10-29 ("Commit, then batch 9").
  - StarterGymConfig: PropAssets entry and colourways for the 9 items.
  - RoomProps: front.place (and the FrontKit type) take an optional stretch
    like Kit.place; barbell() places the bar models; new stick() for chalk
    and markers; wallClock() places the clock model; MockMeet (racks,
    judges' lights), Office (blinds), Classroom (chalk, duster), Coach
    (whiteboard frame, markers), MediaRoom (foam tiles), RecordsWall (chalk).
    MockMeetArena: the coach holds the Clipboard model (anchored, not
    queryable). Old blocks are the fallback everywhere.
  - Checks: luau-lsp 0 problems, `rojo build` OK. Studio Play (by Claude): no
    script errors, every front built. Front visible blocks 355 -> 166
    (Mock Meet 134 -> 8, Media Room 33 -> 9, Office 34 -> 18, Classroom 20 ->
    11, Coach 22 -> 12, Records Wall 10 -> 6). Screenshot: the Mock Meet front
    (wall rack with seven coloured bars, judges' lights, upright rack with
    eleven bars). The coach's clipboard checked by script on the server
    (0.94 x 1.4 x 0.13, pivot at its bottom middle), not seen in a running
    meet. Audit: visible blocks 1,067 -> 878, parts 5,360, MeshParts 4,129,
    unique meshes 580 (budget 600), shadow casters 1,915, lights 144 (0
    shadows), screens 74, solid decor 0, precise 0. StarterGym_VerifyShell
    not re-run.
  - NOT checked: the other fronts by screenshot (counts only); the coach in
    a running mock meet; the user's own look.
  Batch 9 (structural steel, the last batch): `art/scripts/build_steel_01.py` ->
  `art/blender/Steel_01.blend`, 2 pieces, 72 triangles, CHECK PASSED; preview
  sent. SteelBeam (an I-beam) and Handrail (a round tube), both stretched to
  every piece. Stay blocks: the glass railing panels (glass panes), the
  shed's outside roof ridge cap and roller-door rails (roof and door trim),
  the Training Zone's painted columns. Approved by the user ("Approve,
  upload"); exported to `art/exports/Steel_01.glb`, uploaded as the group:
  rbxassetid://139793685980962 (materials.json). COMMITTED and pushed with
  user approval on 2026-10-29 ("Commit and push").
  - StarterGymConfig: PropAssets entry and colourways.
  - StarterGymBuilder: new steelOver(part, item, look) lays the stretched
    model over a block (the part's longest side is the length, the side
    nearest upright an I-beam's depth) and hides the block under it (kept for
    collision and the verify script's Column_ names); used for the hall
    roof's rafters, tie beams and ridge beam, the balcony columns and
    handrails, the stairs' handrails and stringers, the Strongman Shed's
    truss ties and posts and its ridge beam. Blocks stay visible if the model
    did not load.
  - Checks: luau-lsp 0 problems, `rojo build` OK. Studio Play (by Claude): no
    script errors; 56 steel models, each old block hidden under its model;
    a rafter, a column and a stair handrail checked: same size and centre
    (difference 0.000), the column still solid. Screenshot: the hall's roof
    I-beams and the stair handrails. Audit: visible blocks 878 -> 822,
    parts 5,416, MeshParts 4,185, unique meshes 582 (budget 600), shadow
    casters 1,915, lights 144 (0 shadows), screens 74, solid decor 0,
    precise 0.
  - Whole map (batches 1-9, 2026-10-28/29): visible blocks 2,501 -> 822; what
    is left is architecture (walls, floors, ceilings, glass, trims, frames,
    floor and wall markings, flat light strips), screens and signs.
  - NOT checked: StarterGym_VerifyShell has not been re-run since batch 1
    (57 KB, not Rojo-synced, so it has to be pasted into the Command Bar in
    a Play test); the user's own look of every batch.
  StarterGym_VerifyShell, run by the user after batch 9 (2026-10-29): three
  FAILs, all the script counting the new Blender models wrongly (the game was
  fine): the sliding doors counted the DoorSensor model (SensorBox) as a
  panel (3 and 5 found), five swing doors counted the DoorSign model
  (PlaqueSign) as a leaf (Sauna, Recovery, Massage, Lounge, TrophyRoom), and
  the shop counted its CafeShop_01 furniture as gear (51 found). Fixed in
  the script (committed and pushed with user approval, 2026-10-29): door panels are child Models with a
  ClosedPivot (AutoDoorAnimator's own rule; a missing or broken panel still
  fails), and shop gear is counted by its item names. luau-lsp 0 problems.
  Studio Play (by Claude), the same counting run on the server: entrance 2
  and hall 4 panels, all 17 swing doors with their leaf counts, 29 shop gear
  models. The full script not re-run after the fix. (Its INFO about
  Lighting.Technology is not a failure.)
  Re-run by the user after the fix (2026-10-29): ALL CHECKS PASSED.
  Blocks to Blender is finished and verified.

  CHECKPOINT 9: REMOVE PULLSTRENGTH (GAME_DESIGN 34.6, 34.9, 34.14), 2026-10-29.
  The user chose it as the next step and approved keeping the Deadlift typing
  pull's difficulty exactly as it is ("keep it the same"; asked whether the
  pull should still scale with intensity: it does, more characters, faster sag
  and bigger mistakes as the attempt gets heavier; a shorter window at 110% was
  advised against, it would make the pull a typing-speed test). Every lifter
  had PullStrength at 0 (never trainable), where its curves multiplied by 1, so
  nobody's pull changes. COMMITTED and pushed with user approval on
  2026-10-29 ("Commit and push").
  - TypingPhaseConfig: the three fromTechnique curves and techniqueStat are
    gone; startup asserts refuse a technique stat or curve on a typing phase.
    TypingChallenge.techniqueStatFor returns nil; LiftAttemptService reads a
    nil stat as 0 (no curve uses it).
  - Save data version 7: PlayerProfileSchema drops the field (type and
    template); migrations[1] stays as a repair-only step (deleting it would
    strand version-1 saves); new migrations[6] deletes technique.PullStrength,
    nothing else. StartingValuesConfig drops it. Comments elsewhere updated.
  - Tests: PlayerDataProbe (versions 7, PullStrength absent after every
    migration, new section 44 for the 6 -> 7 step), MigrationFixtureV6 (v7,
    not run: needs the real DataStore), TrainingProgressionProbe,
    TechniqueTrainingProbe, TrainingStationProbe. Also fixed a PRE-EXISTING
    TechniqueTrainingProbe failure since schema v6 (its newProfile made no
    build; now ensureActiveBuild, like the other probes).
  - Checks: luau-lsp, no new errors (only the known pre-existing ones);
    `rojo build` OK. Studio Play (by Claude, DataStore API off so no real save
    touched): PlayerDataProbe 470/0, TrainingProgressionProbe 298/0,
    TrainingStationProbe 205/0, TechniqueTrainingProbe 73/0 (probes switched
    back off afterwards). The test profile loaded at version 7. The pull's
    numbers at 80/90/100/105/110% match the old table exactly (9/13/18/22/24
    characters, windows 8-12 s, 1.59-3.00 tokens/s). A real deadlift started
    and its pull ran and was judged with no errors (simulated keys arrived
    after the 10 s window, so it timed out); a replay through
    TypingSimulation passed at 40 WPM (100% and 110%) and 80% at 25 WPM, and
    failed 110% at 25 WPM, as designed.
  - GAME_DESIGN: 34.6 note (removed), 34.9 rebase [APPROVED], 34.14 row 9
    DONE and the migration requirements marked implemented.

  CHECKPOINT 6: THE COMPETITION SCALE CHALLENGE MODIFIER (GAME_DESIGN 33.4),
  2026-10-29. The user approved all six recommended decisions ("Use them"),
  recorded in GAME_DESIGN 33.4 [APPROVED] (values PROVISIONAL), 33.11 item 2
  DECIDED, 34.14 row 6 DONE: extra BASE-DIFFICULTY points added after the
  IntensityConfig curve; 0 at or below proven Scale (no easing), rising
  linearly to the +10 cap at attempt/Scale 1.50; unproven (Scale 0) = +10;
  meet attempts only; shown on the attempt screen as its own line.
  COMMITTED and pushed with user approval on 2026-10-29 ("Commit and push").
  - New: src/shared/Config/ScaleChallengeConfig.luau (MaxBonus 10, FullRatio
    1.5, UnprovenBonus 10, startup asserts) and
    src/shared/Progression/ScaleChallenge.luau (pure bonusFor and the
    ModifierRegistry producer: one BaseDifficulty "Add" modifier, meet
    attempts only).
  - ModifierRegistry: context gains isCompetition, attemptWeightKg,
    competitionScaleKg (header updated: ScaleChallenge is the one source).
  - PlayerDataService.getCompetitionScale (read-only, the current build).
  - LiftAttemptService: registers the source in start(); createAttempt takes
    isCompetition (startServerAttempt, the Mock Meet's only path, passes true;
    the test keys pass false), passes Scale and weight to the registry, keeps
    the bonus on the attempt, logs it, and sends scaleChallengeBonus in the
    phase payload (LiftAttempt.PresentPhasePayload). LiftAttemptController
    shows "unproven weight +N" after the difficulty.
  - Checks: luau-lsp, no new errors (only the known pre-existing ones);
    `rojo build` OK. Studio Play (by Claude): the rule 12/12 by script (at,
    below, 1.11, 1.25, 1.50, 2.2 times, unproven 0 and nil, bad input). A
    real Mock Meet (prompt, choose 22.5 kg, ready): log "meet attempt, Scale
    0.0 kg -> +10.0 difficulty", HUD "22.5 kg - 90% - difficulty 55 -
    unproven weight +10" (45 + 10). A practice squat after leaving: difficulty
    65, no bonus line. Not seen in play: a partial bonus after a proven lift
    (needs a good meet lift first; the rule covers it).

  CHECKPOINT 8: THE COMPETITION BUDGET AND TRAINING ENERGY, AND MEET CN
  RAISES (user decisions, 2026-10-29). The user first chose to retire both,
  then proposed that meets should raise CN (a big lift, e.g. 125% to beat a
  player, sets CN to that weight). Asked and answered: only meets AGAINST
  OTHER PLAYERS raise CN (the solo Mock Meet stays Scale-only); a good lift
  raises CN all the way to the weight lifted; at most +25% per lift per week
  in total; when used up, meet raises stop until it refills (no tapering);
  the Competition Budget is KEPT as that weekly limit; Training Energy is
  retired. COMMITTED and pushed 2026-10-29 (section 1).
  - GAME_DESIGN: new 33.3b (the rule, [APPROVED], value PROVISIONAL, two
    points to decide when built), 33.3 and 34.2 marked changed, 29.9 kept and
    repointed, 29.8 retired, 33.11 item 6, 34.13 items 7 and 8, 34.14 row 8
    decided. Not built: vs-player meets do not exist yet; the budget's stored
    pools stay untouched until then.
  - Save data version 8: migrations[7] deletes trainingEnergy (nothing
    else); migrations[2] keeps its step but no longer repairs Training
    Energy. Removed: the type field and template entry,
    ProgressionConfig.TrainingEnergy, ProfileOperations
    get/consumeTrainingEnergy, PlayerDataService get/consumeTrainingEnergy;
    comments updated (ProfileOperations, PlayerDataService, ProgressionConfig,
    CompetitionBudget, ResourceRegeneration).
  - Tests: PlayerDataProbe (Training Energy sections 10-12 and 22 replaced
    by retirement checks, migrations expect version 8 and no trainingEnergy,
    new section 45 for 7 -> 8), TrainingProgressionProbe, MigrationFixtureV6
    (v8; not run, needs the real DataStore).
  - Checks: luau-lsp, no new errors (only the known pre-existing ones);
    `rojo build` OK. Studio Play (by Claude, DataStore API off):
    PlayerDataProbe 454/0, TrainingProgressionProbe 298/0,
    TechniqueTrainingProbe 73/0, TrainingStationProbe 205/0 (probes
    switched back off). The test profile loaded at version 8. The user ran
    the probes themself too: all pass.

  MEET RISK (design only, user decisions 2026-10-29; GAME_DESIGN 33.3b,
  33.11 item 1 decided). COMMITTED and pushed 2026-10-29. The meet CN limit changed from
  +25% per week to a DAILY allowance: +4% of CN per lift per day, stacking
  up to 3 days, shrinking near the class's world-record level (Progression
  Reference). A missed attempt above CN uses the allowance it would have
  used had it been good. A bomb-out (no total; leaving early counts) saves
  nothing from the meet, in the Mock Meet too, so raises are applied when
  the meet ends. Edited: 33.3b table, 29.9 note, 29.10 Mock Meet bullet,
  33.6 note, the 29.5 obsolete note, 33.11 items 1, 6 and 9, 34.13 row 7,
  34.14 row 9.

  MOCK MEET SAVES ONLY WITH A TOTAL (built 2026-10-29, GAME_DESIGN 33.3b).
  COMMITTED and pushed 2026-10-29 (section 1).
  - MockMeetService: saveScale (after each good lift) and saveBestTotal are
    replaced by saveMeetResult, run once when the meet ends: with a total it
    raises all three lifts' Scale and the best Total in ONE
    PlayerDataService.update; a bomb-out logs "bombed out: nothing saved".
    Leaving (or dying) before the end saves nothing ("left before the meet
    ended"); leaving during the LAST verdict counts as finished
    (allAttemptsTaken). Header comment updated.
  - ProfileOperations.raiseCompetitionScale: caller rule 5 added (the meet
    ended with a total).
  - MockMeetUI: the Done screen's stale "(nothing is saved yet)" now reads
    "(proven lifts saved)" or "(a bomb-out saves nothing)".
  - Checks: luau-lsp, no new errors (only the known pre-existing ones).
    Studio Play (by Claude, DataStore API off), with TEMPORARY 1 s
    choose/ready timers (restored, Studio matches disk): (1) 9 timed-out
    no-lifts -> "bombed out: nothing saved", screen "(a bomb-out saves
    nothing)"; (2) leave after squat 1 -> "left before the meet ended:
    nothing saved"; (3) leave during the last verdict -> "bombed out:
    nothing saved" (the finished path); (4) with a TEMPORARY "time-out
    counts as good lift" line (removed): no Scale notice during the meet,
    then at the end Squat/Bench/Deadlift Scale 27.5 kg and best Total
    82.5 kg Raised, screen "(proven lifts saved)". Not seen: a real
    minigame good lift (the user's Mock Meet test covers it).
  - Rojo half-synced the first edit once (new function in, old runMeet
    kept); fixed by a nudge edit, then Studio's Source lengths were checked
    against the disk files.
  - USER'S OWN MOCK MEET (Studio Play, 2026-10-29, read from the server
    log by Claude): real minigames, 7 of 9 good (squat 22.5/25/27.5x,
    bench 22.5/25/27.5, deadlift 22.5x/22.5/25), total 77.5 kg; all three
    Scales and the best Total "Raised" only after the last attempt; no
    errors. Every attempt carried +10 (Scale 0 before the meet).
  - Decision (user, 2026-10-29, GAME_DESIGN 33.4 table): the Scale
    challenge reads the Scale proven BEFORE the meet, fixed for the whole
    meet. Matches the built code; no code change. COMMITTED and pushed
    2026-10-29 (section 1).

  LOCAL MEET (vs other players) — DESIGN DECIDED (user, 2026-10-29,
  GAME_DESIGN 29.10 "The Local meet — first build"), COMMITTED and pushed
  2026-10-29 (section 1).
  Picked from options: everyone lifts together on their own platforms (9
  rounds); one ranking by score = Total / class reference Total (class
  winners shown); starts on a 10-minute timer with at least 2 signed-up
  players, sign-ups close 1 minute before; a separate building on the same
  server through a door. Build order: (1) the meet itself on a temporary
  venue, (2) rewards incl. the daily CN allowance (save-data change), (3) the
  venue in Blender. Money/equipment wait for the economy design.

  LOCAL MEET STEP 1: THE MEET ITSELF ON A TEMPORARY VENUE (built
  2026-10-29). COMMITTED and pushed 2026-10-29 (section 1). Saves nothing
  (rewards are step 2).
  - New: LocalMeetConfig (timetable 10 min / Studio 90 s, sign-ups close
    60 s / 15 s before, min 2 lifters / Studio 1, max 8), LocalMeetRemotes,
    AttemptChoice (the weight rules, moved out of MockMeetService),
    MeetPlacing (score = total / class reference Total; ties lighter
    bodyweight, then entry order), MeetFigures (coach + referee figures,
    moved out of MockMeetArena), LocalMeetVenue (temporary hall at
    -4000,1000,0: 8 platforms with rack and board, benches, sign-up desk,
    exit point, scoreboard; referees + coach per used platform during a
    meet), LocalMeetService (entrance, sign-up toggle, timetable, 9 rounds
    together, lights, standings, final placing, withdraw/exit/death),
    LocalMeetController + LocalMeetLobbyUI (venue screen: countdown, SIGN
    UP, EXIT, standings; the lifter's screen reuses MockMeetUI).
  - Changed: MockMeetService (uses AttemptChoice), MockMeetArena (uses
    MeetFigures; placeRack and hangOnWall exported), MockMeetController
    (attach() for either meet), MockMeetUI (options, "Waiting" step,
    lights dots, note), MockMeetRemotes (lights, note), RoomProps (a
    TEMPORARY LocalMeetEntrance point right of the Mock Meet desk + a
    board line), server/client init.
  - Checks: luau-lsp, no new errors. Studio Play (by Claude, alone, with
    TEMPORARY short timers and "time-out = good lift" for attempts 1-2,
    both removed and Studio checked against disk): venue built (522 parts),
    entrance prompt -> venue; sign-up refused in the closed window, then
    accepted; meet started with 1 lifter; all 9 rounds (Choose, Waiting,
    Ready, Result, Done); referees, coach, platform board, lights dots and
    live score seen in a screenshot; final 1st, 75 kg total, 11.2%; back
    to the lobby, boards Free, 0 figures left, no errors. LEAVE mid-meet ->
    Withdrawn; EXIT -> back in the gym; meet ended early with nobody left.
    Mock Meet after the refactor: coach present, range 10-30, suggestion
    22.5, both bad weights refused. Venue screen layout fixed after a
    screenshot (STATS tab overlap; standings moved right).
  - NOT tested: two real players in one meet (Studio's Play is one
    player; use Test > Clients and Servers with 2 players, or a friend);
    real minigame lifts in a Local meet (same code path as the Mock Meet).
  - Performance: the hall is ~522 parts (8 racks); a full meet adds up to
    32 figures (3 referees + coach per lifter), removed after. 20 lights.
  - USER'S TEST (2026-10-29, reported by the user): a two-player Local meet
    in Studio and a full meet; "It all works out". Not seen by Claude.

  LOCAL MEET STEP 2: THE REWARDS, SAVE VERSION 9 (built 2026-10-29).
  COMMITTED and pushed 2026-10-29 (section 1). User decisions (2026-10-29, picked from options): the
  allowance shrinks on training's Hill curve (4% x Hill(PP) per day); refills
  smoothly; lives PER WEIGHT-CLASS BUILD, and a new build COPIES the lighter
  build's allowance (asked after the user questioned the abuse risk of
  per-class allowances).
  - New: MeetCnAllowance (shared, pure: days saved up 0..3, 1 day / 24 h;
    settle() in attempt order; nil for 120+ kg), ProgressionConfig
    .MeetCnAllowance (PercentPerDay 0.04, MaxDays 3).
  - Save v9: Build.meetAllowance {Squat, Bench, Deadlift: Resource in
    days}; career {localWins}; migrations[8] fills every build (full) and
    the career (0); newBuild copies the lighter build's allowance;
    fillMissing adds a full one to an older build.
  - ProfileOperations: getMeetAllowanceShare, settleMeetCompetitionNumber
    (monotone), addLocalWin, buildCompetitionNumber helper.
  - LocalMeetService: one write per lifter at the end (Scale + best Total
    with a total; CN settlement and a win when the meet rewards: started
    with RewardMinimumLifters, 2 live / 1 in Studio); withdraw settles the
    misses at once; the Done note lists the raises; the lobby sends
    allowancePercent. LocalMeetLobbyUI: "CN RAISE LEFT" line.
  - The old account-wide competitionBudget stays in the save, unread (a
    cleanup step removes it with its module, config and probe sections).
  - Checks: luau-lsp, no new errors. Studio Play (by Claude, DataStore API
    off): PlayerDataProbe 482/0 (new sections 46-47: v8 -> v9, copy on
    entry, settle cases, refill, 120+, monotone, wins);
    TrainingProgressionProbe 298/0; profile loaded at version 9. A real
    Local meet alone (TEMPORARY short timers and "time-out = good lift" for
    attempts 1-2, both removed, Studio checked against disk): squat 22.5 /
    27.5 / 30x, bench and deadlift 22.5 / 25 / 27.5x -> Squat CN 25 -> 27.5,
    bench/deadlift unchanged, Scale 27.5/25/25, best Total 77.5, Local wins
    1; allowance left S 0 %, B 2 %, D 2 % (as calculated); LEAVE mid-meet
    saved "no total", nothing raised. All probes switched back off.
  - NOT tested: a two-player rewarded meet (live rule: 2 lifters); real
    minigame lifts in it.

  COMPETITION BUDGET CLEANUP, SAVE VERSION 10 (2026-10-29, user: "Budget
  cleanup"). COMMITTED and pushed 2026-10-29 (section 1).
  - Removed: the save field (migrations[9] deletes competitionBudget; the
    type and template entry are gone; migrations[2] no longer repairs it),
    ProgressionConfig.CompetitionBudget, the CompetitionBudget module,
    ProfileOperations get/getState/consume, PlayerDataService
    get/getState/consume, and CompetitionNumberReward.calculate (the
    budgeted meet-EV award, unused since 33.3; calculateTrainingAward is
    unchanged). Comments updated (ProfileOperations, PlayerDataService,
    ProgressionConfig, CompetitionNumberReward, ResourceRegeneration).
  - Tests: PlayerDataProbe (budget-only sections 6-9 and 15-22 removed;
    23 rewritten for the meet allowance; old-save fixtures still carry a
    budget; post-migration checks now expect it removed; version 10; new
    section 48 for 9 -> 10), TrainingProgressionProbe (section 13 now
    checks the meet allowance), CompetitionNumberRewardProbe (calls moved
    to calculateTrainingAward; budget sections 12-15 and 19 removed),
    MigrationFixtureV6 (version 10, budget removed; not run).
  - Checks: luau-lsp, no new errors (CompetitionNumberReward's old error at
    the removed calculate is gone; DifficultyProbe's errors are older, file
    untouched). Studio Play (by Claude, DataStore API off): PlayerDataProbe
    409/0, TrainingProgressionProbe 298/0, CompetitionNumberRewardProbe
    128/0; profile loaded at version 10. All probes switched back off.

  LOCAL MEET STEP 3: THE VENUE (2026-10-29). COMMITTED AND PUSHED with the
  redesign below (user: "Commit and push now"), 90ff3dc.
  User decisions (picked from options): a building outside the gym; dark
  arena, lit platforms; referee light boxes, tiered seating, awards podium,
  warm-up area. Then: "Change the roof, I dont want any places to just have
  a square shape, and flat roof" -> pitched gable roof + entrance porch; saved
  as memory "no-flat-roofs".
  - Blender: art/scripts/build_local_meet_01.py -> art/blender/LocalMeet_01
    .blend (RefLights with Lamp1..3, Bleachers, AwardPodium, PlateTree with
    plates by size, MeetHall), CHECK PASSED (42 meshes, 6,878 tris),
    previews in art/previews/LocalMeet_01_*.png, exported
    art/exports/LocalMeet_01.glb, uploaded as group 529442797:
    rbxassetid://96498344946081 (materials.json "LocalMeet_01").
  - StarterGymConfig: PropAssets + PropColourways (RefLights, Bleachers,
    AwardPodium, PlateTree, MeetHall).
  - RoomProps.paintProp: piece names may contain digits (`_(%w+)$`) so
    Lamp1..3 are painted; no existing colourway key has digits. The
    temporary Mock Meet Room entrance prompt and its board line removed.
  - LocalMeetVenue rewritten: hall 208 x 92, walls 30 high, pitched ceiling
    (ridge 42 along X) of two slabs + wedge gable ends, SteelBeam rafters
    every 26 studs and a ridge beam; 8 platforms with boards, a RefLights per
    platform (setLights), stage lights hung under the ceiling; 6 Bleachers
    sections facing the platforms with hidden solid steps and a centre
    aisle; AwardPodium in the aisle (podiumSpots read from its gold, silver,
    bronze tops); warm-up area (2 racks, 2 plate trees); desk, exit,
    scoreboard, banner, dimmer ceiling panels. buildEntrance(): MeetHall at
    x 162, front wall at z -37, hidden solids, a big LOCAL MEET sign
    (SurfaceGui), the tagged door point.
  - LocalMeetService: builds the entrance at start; lamps lit after each
    lift and off at the next Ready, on withdraw and after the meet; the top
    three stand on the podium during DoneSeconds.
  - Checks: luau-lsp, no new errors. Studio Play (by Claude): venue 589
    parts / 26 lights, entrance 24 parts; walked in through the entrance
    prompt; screenshots of the entrance (sign reads LOCAL MEET), the hall,
    white lamps after a good lift, red after a miss, the winner on the
    podium's 1st place; lamps off and 0 figures after; no errors. The meet
    test used TEMPORARY short timers and "time-out = good lift" for attempts
    1-2 (removed; Studio checked against disk).
  - Performance: the hall is ~589 parts (8 platform racks + 2 warm-up racks
    are the bulk), 26 lights; entrance 24 parts.

  LOCAL MEET VENUE REDESIGN, part 1: the layout (2026-10-29). COMMITTED AND
  PUSHED with step 3 above as 90ff3dc "Build the Local meet venue in Blender
  and redesign it (step 3)" (user-approved before a full-meet test; previews
  in art/previews/ are not tracked, like earlier previews). User's own plan ("my original idea of
  how i want meets ran", reference photos) + the awards ceremony; layout picks
  were Claude's recommendations, accepted ("I approve build order"); recorded
  in GAME_DESIGN §29.10 "Venue redesign and awards ceremony". Build order:
  (1) layout + new models [this], (2) awards ceremony (winner camera, theme
  song and celebration slots), (3) working warm-up racks (practice, no CN).
  - Blender: art/scripts/build_local_meet_02.py -> art/blender/LocalMeet_02
    .blend (Barricade, RefChair, PlatformSign, AwardsBackdrop), CHECK PASSED
    (23 meshes, 10,676 tris), previews art/previews/LocalMeet_02_*.png
    (approved by the user: "Approve, upload"), exported
    art/exports/LocalMeet_02.glb, uploaded as group 529442797:
    rbxassetid://71979666360161 (materials.json "LocalMeet_02").
  - StarterGymConfig: PropAssets + PropColourways (Barricade, RefChair,
    PlatformSign, AwardsBackdrop).
  - LocalMeetVenue rewritten again: one building 220 x 176 under one pitched
    ceiling (ridge front to back, 46 high, eaves 30), cross walls with gable
    wedges. LOBBY (sign-up desk at the doors facing the arrival, exit doorway
    + EXIT board, boards over the hall opening and the corridor); MEET HALL
    (6 stands against the lobby wall + 2 on each side wall, open standing
    floor, 29 barricades on one hidden solid wall at z 6, 8 platforms each
    with a PLATFORM n sign on a post, 3 RefChairs, the light box, board on
    the back wall, stage light; scoreboard and banner on the side walls);
    WARM-UP ROOM behind the back wall (a doorway between each pair of
    platforms; 8 racks for looks, 4 plate trees, hangout corner: 2 sofas,
    water cooler, planters, WARM-UP banner); CORRIDOR along the right side.
    Per platform a `gear` folder (rack, chairs, light box). AWARDS STAGE
    (AwardsBackdrop with LOCAL CENTRAL MEET / AWARDS, AwardPodium + solids)
    kept out of the world; showAwards(v, on) swaps it with every platform's
    gear (and removes the seated referees). Shared writeSign() for the big
    italic signs (entrance, platform signs, backdrop title).
  - MeetFigures.build(..., seatTop?): seated figures. The figures' joints are
    AnimationConstraints (not Motor6Ds), so the hips and knees are bent by
    turning the joint's Attachment0 (Motor6D rigs handled too).
  - LocalMeetService: showAwards(true) before the top three go on the
    podium, showAwards(false) after DoneSeconds.
  - Checks: luau-lsp, no new errors. Studio Play (by Claude): venue 1135
    parts, 31 lights, one venue, no errors; screenshots of the hall, the
    platforms with signs/chairs/light boxes/barricades, the lobby, the
    warm-up room and hangout corner; the awards stage (title reads LOCAL
    CENTRAL MEET / AWARDS, a player on the gold block) and the seated pose
    were checked by running the same code from the command bar (a separate
    copy of the venue), NOT through a real meet.
  - Performance: the venue grew from ~589 to ~1135 parts (16 racks are the
    bulk: 8 on platforms, 8 in the warm-up room) and 26 -> 31 lights.
  NEXT ACTION: the user plays a full Local meet in Studio (referees sit on
  the chairs, racks vanish and the awards stage appears at the end, comes
  back after) and looks round the venue; then part 2, the awards ceremony.

  LOCAL MEET VENUE REDESIGN, part 2: the awards ceremony (2026-10-29).
  COMMITTED with the user's approval ("you can commit"); `git log` for the
  hash. GAME_DESIGN §29.10 "(2) built".
  - USER TEST (2026-10-29): played a full Local meet in Studio: "everything
    works" (venue, seated referees, the awards stage swap, the camera, the
    theme and cheer, the celebration). Asked whether the LOCAL MEET and
    STANDINGS panels should hide during the close-up: "No it should stay".
  - Sounds (own work): art/scripts/make_awards_sounds.py ->
    art/sounds/Awards_Theme.wav (18 s fanfare, 120 BPM C-G-Am-F twice + held
    chord) and Awards_Cheer.wav (5.5 s applause, roar, whistles); uploaded as
    group audio: Theme rbxassetid://116724943474598, Cheer
    rbxassetid://74322878777614 (materials.json "sounds"). The user has not
    heard them yet.
  - LocalMeetConfig.Awards: default theme / celebration (Roblox's R15 cheer
    emote 507770677) / cheer ids, volumes, camera timings (wide 4 s,
    close-up 10 s, distances 30 / 8, glide 1.2 s).
  - LocalMeetRemotes: new LocalMeetAwards (AwardsMoment: winner, gold spot,
    stage centre and facing, theme, celebration, seconds).
  - LocalMeetService: announceAwards() after the top three are on the
    podium, to everyone in the venue; themeFor / celebrationFor are the slots
    for custom songs and celebrations (defaults for now).
  - Client: new src/client/Meet/LocalMeetAwards.luau (Scriptable camera:
    drift in to the wide shot, glide to the winner's head, back out; cheer +
    theme Sounds in SoundService; the winner's own client loops the
    celebration; everything undone at the end or on leaving the venue),
    hooked up in LocalMeetController.
  - Checks: luau-lsp, no new errors. Studio Play (by Claude): fired the
    awards moment by hand at the player standing where the gold top is (a
    TEMP command-bar test, nothing left in the game): wide shot, close-up of
    the cheering winner, both sounds loaded and playing (Cheer 5.5 s, Theme
    18 s), the cheer animation playing, and after 20 s the camera back to
    Custom, the sounds gone and the animation stopped. NOT tested through a
    real meet (the stage was not shown in that test).
  NEXT ACTION (done below): part 3, the working warm-up racks.

  LOCAL MEET VENUE REDESIGN, part 3 + PLATFORM SCREENS (2026-10-29).
  COMMITTED AND PUSHED with the user's approval ("Commit and push now",
  before a full-meet test); `git log` for the hash. GAME_DESIGN §29.10 "(3)
  built" and "Platform screens".
  - Warm-up racks: new src/server/Meet/LocalMeetWarmUp.luau (prompt per
    rack, one player per rack, LIFT checked with AttemptChoice and started
    with LiftAttemptService.startServerAttempt = a meet attempt, nothing
    saved; stop() on meet start, leaving the venue, death) and
    src/client/Meet/LocalMeetWarmUpUI.luau (the WARM-UP card, bottom middle,
    hidden while lifting). LocalMeetRemotes: WarmUpLift / WarmUpLeave /
    WarmUpState. LocalMeetConfig.WarmUp. LocalMeetVenue: warmUpRacks (lift
    spot 4 studs in front of each rack, a prompt point). LocalMeetService
    wires it (canUse: in the venue, not lifting in the meet, no lift running).
  - BUG FIXED: the venue's prompt points were placed with the building's
    origin added twice (point() already adds it), so the SIGN-UP DESK and
    EXIT prompts have been unreachable in mid-air since step 3 (players used
    the on-screen SIGN UP / EXIT buttons). Now at the desk and the doors.
  - Platform screens: new src/server/Meet/LifterDisplay.luau (a SurfaceGui
    on each platform board, now MockMeet_01's board at 0.8 scale, middle
    18.5 high). LocalMeetVenue.showLifter replaces setPlatformBoard;
    LocalMeetService.boardFor builds the card (username, class, bodyweight,
    forecast total = sum of CNs, bests, status lines, mood) and factsFor (beat
    a CN, new best total, going above CN, Local wins, best Total). The
    weigh-in now also reads the class's bestTotalKg and career.localWins.
  - Checks: luau-lsp, no new errors. Studio Play (by Claude): walked in
    through the entrance prompt (keyboard E), held E at warm-up rack 1, the
    WARM-UP card showed (22.5 kg = 90% of a 25 kg squat CN), LIFT started the
    real squat minigame at meet difficulty ("unproven weight +10"), it timed
    out to NO LIFT and the card came back with "LAST SQUAT 22.5 KG · NO
    LIFT"; LEAVE RACK freed the player and re-enabled the prompt. Screens:
    all eight say OPEN; a sample lifter card built from the command bar on
    platform 4 (TEMP, not in the game) drew correctly; the facts strip turns
    every 4 s. Found and fixed while testing: a SurfaceGui MaxDistance hid the
    screens; setting TextWrapped off made TextScaled text tiny. NOT tested:
    the screens during a real meet, two players on warm-up racks.
  NEXT ACTION: the user plays a Local meet (watch the platform screen during
  the lifts) and tries a warm-up rack; fix anything found.

  MEET WEIGHT MENU, easier to read (2026-10-29). COMMITTED AND PUSHED with
  the user's approval ("Commit and push"); `git log` for the hash. User,
  with a screenshot of the old menu: "make this menu easier to read ... for
  new players", bigger, bigger fonts for the allowed range and % of CN,
  preset % buttons instead of -5/-2.5, and their stats visible so they can
  judge the jump. Display only (no rule changed); the Mock Meet and the Local
  meet share it.
  - src/client/Meet/MockMeetUI.luau: while choosing, the action panel is 660
    x 380 with YOUR CNs (S/B/D chips, this lift in its colour), THIS LIFT SO
    FAR (each attempt, GOOD / NO LIFT), the weight box, big lines for % of
    CN, the jump from the last attempt and ALLOWED min-max, and QUICK PICK
    buttons at 90/95/100/105/110/115/120/125% of CN with their kg (on the
    2.5 kg step; dimmed and inactive outside the allowed range). The -5/+5/
    -2.5/+2.5 nudges are gone (typing still works).
  - src/client/Meet/MockMeetController.luau: the nudge handler `step` is
    replaced by `set` (a QUICK PICK weight).
  - Checks: luau-lsp, no new errors. Studio Play (by Claude): showed the
    menu with sample states sent by hand (TEMP, nothing in the game): a 25 kg
    CN squat attempt 2 and a bench attempt 3 after a good 125 and a missed
    135; screenshots read well. The user then used it in a real meet
    (2026-10-30): "Yup it works". With very small
    CNs two picks can land on the same kg (e.g. 110% and 115% of 25 kg).

  GYM RECORD WALL, planned (2026-10-30). NOTHING BUILT YET. User: "Plan the
  record wall", then picked: any good lift counts (no total needed), venue +
  whole-server announcement, own records announced too. Recorded in
  GAME_DESIGN §31.6 "The gym record wall — first build". Found: the chalk
  wall's cells already exist (RoomProps FRONT.RecordsWall, frames
  "Record_<class>_<LIFT>" with Avatar / Holder / Kg); CardioRhythmLeaderboard
  is the pattern for a game-wide save (Studio_ stores or memory in Studio);
  LocalMeetService knows the class and `current.rewards` (official meet).
  Build order: (1) each lifter's official-meet bests per class in their save
  (schema 10 -> 11); (2) the shared gym records save (UpdateAsync, heavier
  only); (3) the wall shows avatar, username, kg, re-read about once a
  minute; (4) platform screen, facts strip and server announcement.
  Step 1 BUILT (2026-10-30, user: "Start step 1"). COMMITTED AND PUSHED with
  the user's approval ("Commit and push", before a real-meet test); `git log`
  for the hash.
  - PlayerProfileSchema: CURRENT_VERSION 11; Build.officialMeetBest {S, B, D}
    (NO_OFFICIAL_BEST = 0); newBuild and fillMissing add it; migrations[10]
    gives every existing build empty bests, nothing else touched.
  - ProfileOperations: raiseOfficialMeetBest (monotone, same rules as the
    Scale raise, no total needed) and getOfficialMeetBestTotal (the three
    bests added, nil until all three exist).
  - LocalMeetService: saveOfficialBest after each GOOD lift when
    `current.rewards` (official); logs "official <lift> best".
  - PlayerDataProbe: version checks 10 -> 11, new test 49.
  - Checks: luau-lsp, no errors in the changed files. Studio Play (by
    Claude): PlayerDataProbe switched on for one run (then off again, Studio
    checked): 423 passed, 0 failed; the real Studio profile loaded at version
    11. NOT tested: a real Local meet saving a best (look for "official Squat
    best" in the Output after a good lift).
  Step 2 BUILT (2026-10-30, user: "Start step 2"). COMMITTED AND PUSHED with
  the user's approval ("Commit and push", before a real-meet test); `git log`
  for the hash.
  - New src/shared/Config/GymRecordsConfig.luau (records, store "GymRecords",
    key "AllClasses", Studio_ prefix, refresh 60 s, 3 retries).
  - New src/server/Meet/GymRecords.luau: submit(userId, class, claims, done)
    queues a claim and saves it with UpdateAsync, heavier only (a tie keeps
    the first lifter); done(broken) lists the records broken and who held
    them before. get(class) (a copy), onChanged(listener), mode(). Reads
    are cleaned (unknown classes / bad entries dropped). Re-read every 60 s;
    a read that overlaps a save is dropped. Waits for saves on shutdown.
  - init.server.luau starts GymRecords before LocalMeetService.
  - LocalMeetService.saveOfficialBest: when the best was Raised, claims the
    lift and the lifter's official-meet Total (once all three exist); logs
    "NEW GYM RECORD: ..." for each record broken.
  - Checks: luau-lsp, no errors in the changed files. Studio Play (by
    Claude), a separate copy of GymRecords in memory mode: first record from
    empty; a tie broke nothing; a heavier lift by someone else took it (old
    holder reported); beating your own record and a first Total both saved;
    a lighter Total broke nothing; other classes separate; bad weights and an
    unknown class refused; get() returns a copy; 4 change signals. The live
    server's GymRecords started ("records: memory"). Found while testing:
    Rojo missed one edit (re-saved; Studio checked against disk). NOT
    tested: a real Local meet sending a claim (look for "NEW GYM RECORD" in
    the Output after a good lift).
  Steps 1 + 2 TESTED IN A REAL MEET (2026-10-30): the user played a Local
  meet in Studio (1 lifter, rewards: true); Claude read its Output: every
  good lift logged "official <lift> best ... Raised" then "NEW GYM RECORD"
  (first from empty, then over their own 22.5 kg); the misses saved
  nothing; the Total record appeared once all three lifts had a best (72.5,
  then 75 kg).

  Step 3 BUILT (2026-10-30, user: "Start step 3"). COMMITTED AND PUSHED
  with the user's approval ("Commit and push"); `git log` for the hash. Tested
  by Claude in Studio Play (user: "Yes, test it"): the table is tagged and
  the title reads "GYM RECORDS (STUDIO TEST)"; TEMP test records sent from
  the command bar (memory only, gone when Play stopped) for the user (59 kg
  S/B/D 25 + Total 75), builderman (83 kg) and Roblox (120+ kg): each cell
  showed the headshot, the looked-up username and the kg; empty cells kept
  "?" / "—" / "— KG"; screenshot of the wall reads well.
  - New src/server/World/GymRecordsWall.luau: fills every cell of the chalk
    GYM RECORDS table from GymRecords (headshot via rbxthumb, username from
    the server or GetNameFromUserIdAsync, cached; "190 KG"); an empty record
    shows "?", "—", "— KG"; redraws a class on GymRecords.onChanged; in
    Studio the title says "GYM RECORDS (STUDIO TEST)".
  - RoomProps FRONT.RecordsWall tags the table GymRecordsConfig.WallTag
    ("GymRecordsTable"); GymRecordsConfig gains WallTag.
  - init.server.luau starts GymRecordsWall after GymRecords.
  - Checks: luau-lsp, no errors in the changed files.
  Step 4 BUILT (2026-10-30, user: "Start step 4"). COMMITTED AND PUSHED
  together with step 4b, with the user's approval ("Commit and push");
  `git log` for the hash.
  - New src/shared/Meet/GymRecordRemotes.luau: GymRecordBroken (server ->
    every client, Announcement {name, userId, classLabel, records}).
  - GymRecords: creates the remote; nameOf(userId) (moved here from
    GymRecordsWall, which now uses it); announce(name, userId, class,
    broken) looks up the old holders' names and fires everyone.
  - LocalMeetService: Lifter.gymRecords / boardLines / boardMood; when a
    claim comes back with broken records, the platform screen is redrawn
    (only while that meet is still running) and GymRecords.announce fires;
    factsFor puts "NEW GYM <LIFT> RECORD!" first and adds "GYM <LIFT> RECORD
    HOLDER" / "HOLDS n GYM RECORDS" for records already held.
    saveOfficialBest moved below stillLifting/boardFor (it uses them).
  - New src/client/Meet/GymRecordAnnouncer.luau (started in
    init.client.luau): the NEW GYM RECORD card (UIStyle panel, top middle
    under the lift banner, slides in for 7 s, queued) and a yellow system
    chat line.
  - Checks: luau-lsp, no errors in the changed files. Rojo missed a
    GymRecords edit again (re-saved; every file checked against disk).
    Studio Play (by Claude), TEMP announcements fired from the command bar
    (display only): the card showed "treylicious1 / 190 KG SQUAT / 83 KG
    CLASS · OLD RECORD: builderman 180 KG / + NEW TOTAL RECORD 540 KG"
    (screenshot reads well); "BEAT THEIR OWN 100 KG" and "FIRST RECORD IN
    THIS CLASS" variants queued one after another and the card slid away;
    no errors; the chat channel exists (the chat line itself not looked at).
    NOT tested: the platform screen's record facts in a real meet.
  Step 4b BUILT (2026-10-30, user, from a screenshot of another game's
  top-line news: "on top and less visible ... I dont want players getting
  annoyed"; "a teleport button on the left, where you can tp to any place";
  a confirmed record weight "gets announced + a tiny option to tp to
  watch"). COMMITTED AND PUSHED with step 4 (see above). GAME_DESIGN: §31.6 "(4)"
  CHANGED note, and "The TELEPORT menu" under "One UI style".
  - GymRecordAnnouncer rewritten: no card; one outlined line at the very top
    (coloured name / record / kg), 7 s (attempts 12 s), at most 3 lines,
    below the lift banner while it shows; chat line kept for records set.
    RecordAttempt lines get a small WATCH button (not for the lifter or
    players already in the venue) that asks TeleportRemotes for the venue.
  - GymRecordRemotes: every record carries `level` (GYM now; NATIONAL /
    WORLD later); new RecordAttempt remote (AttemptNews {name, userId,
    classLabel, records, where, watch}); createOnServer / waitForClient
    return both remotes.
  - GymRecords: wouldBreak(class, claims) (only existing records, heavier
    only) and announceAttempt(...).
  - LocalMeetService: announceAttempt when a weight is confirmed and at the
    lift for a timed-out default (official meets only, once per attempt;
    Total = official-meet bests with this lift raised). enter() split into
    enterVenue(player, point?) + teleportIn / teleportOut (a lifter in the
    running meet must LEAVE first; teleporting out = off the sign-up list).
  - New TELEPORT menu: src/shared/Config/TeleportConfig.luau (22 places:
    rooms by their Room_ region, fixed points, a tag, the venue),
    src/shared/World/TeleportRemotes.luau (RequestTeleport RemoteFunction),
    src/server/World/TeleportService.luau (all checks, floor raycast,
    2 s cooldown; started in init.server after LocalMeetService),
    src/client/UI/TeleportMenu.luau (T or the TELEPORT tab under STATS;
    started in init.client).
  - Checks: luau-lsp, no errors in the changed files; every file checked
    against disk in Studio. Studio Play (by Claude): all 22 places teleport
    through the real remote and land on the floor (ground 3, upstairs 17,
    venue entered with its attribute set); venue -> Sauna left the venue;
    refused: unknown place, a number, the 2 s cooldown, "already at the
    Local meet", CardioMachine, MockMeetSlot, anchored. TEMP news lines fired
    from the command bar (display only): screenshot reads like the user's
    example; clicking WATCH teleported into the venue and hid the button;
    in the venue the attempt line shows no WATCH. wouldBreak on a memory-
    only copy of GymRecords: empty spot / tie / lighter / other class / bad
    input -> nothing; heavier squat + Total -> both. Menu screenshot OK
    (left column clipped -> 4 px inset added after, not re-screenshotted).
    NOT tested: a record attempt announced from a real meet (needs a record
    set first and passing the minigames); a lifter refused mid-meet.
  - CHANGED (user, same day: "Too much areas to tp"): TeleportConfig now has
    only 4 places, one section MAIN AREAS: Lobby, Shop, Mock Meet desk, Local
    meet (inside). Menu is a 2 x 2 grid (560 x 290 panel). Studio Play (by
    Claude): all 4 teleport and land on the floor; a removed place (Cafe) is
    refused as unknown; menu screenshot reads well.
  Step 4c BUILT (2026-10-30, user, from a screenshot of the platform screen:
  "more visible when someone is going for a gym record ... a bigger sign at
  the top saying GYM RECORD ATTEMPT"). COMMITTED AND PUSHED with the
  user's approval ("Commit and push"); `git log` for the hash. GAME_DESIGN §31.6 "The
  platform during a record attempt".
  - LifterDisplay: Card.recordAttempt {title, detail}?; a BillboardGui
    "RecordAttemptSign" (23 x 6 studs, as wide as the screen, 2 studs above
    the screen's top, above the CENTRAL header) on the screen part: red slab, white heavy
    italic title, yellow detail line, edge flashing white/yellow every 0.5 s
    while shown; the facts strip turns red with "GYM RECORD ATTEMPT!" first.
  - LocalMeetService: Lifter.recordAttempt, set in announceAttempt (detail
    "30 KG SQUAT · RECORD 25 KG", "+ TOTAL") with a board redraw; cleared at
    the round's start, at the lift's result and on withdraw; boardFor passes
    it in the card.
  - Checks: luau-lsp, no errors. The user's own Studio meet log (before this
    change loaded) showed a real meet announcing "treylicious1 is going for a
    gym record: Squat 27.5 kg (59 kg)" after their 25 kg record, so the
    record attempt alert works from a real meet. Studio Play (by Claude,
    user: "Yes, test it"): a TEMP copy of the new LifterDisplay drawn on
    platform 1's screen (real display hidden, then restored; Play only) with
    a record attempt card: screenshot from the audience area shows the red
    GYM RECORD ATTEMPT sign above the CENTRAL header, as wide as the screen,
    readable; the strip red with "GYM RECORD ATTEMPT!"; the edge flashes;
    after a result card the sign is off and the strip yellow ("NEW GYM SQUAT
    RECORD!"); an empty platform has no sign; no errors. First size (18 x 4.4)
    looked narrower than the screen -> enlarged to 23 x 6.
    NOT tested: the sign switched on by a real meet (needs a record and a
    heavier attempt in one meet).
  The user approved the record sign ("Its good").

  MONEY SYSTEM PLANNED (2026-10-30, user: "Plan the money system", picked
  from options): GAME_DESIGN §30.6. One currency, COINS, from official meets
  only (prize pot by place, finishing bonus, 9/9 bonus, gym record bonus:
  full for taking someone else's, small for your own, none for an empty
  spot); first thing to buy: cosmetic gear in the Shop. The deadlift-typing
  cosmetic currency is a later step. Amounts [PROVISIONAL] in §30.6. Build
  order: (1) coins in the save, (2) on screen, (3) meets pay, (4) the Shop,
  (5) wearing the gear. Nothing built yet.
  Money step 1 BUILT (2026-10-30, user: "Start step 1"). COMMITTED AND PUSHED
  with the user's approval ("Commit and push"), together with the money
  plan (GAME_DESIGN 30.6); `git log` for the hash.
  - PlayerProfileSchema: CURRENT_VERSION 12; `wallet {coins, earnedTotal,
    spentTotal}` (export type Wallet), template all 0; migrations[11] adds
    it or repairs (a usable whole count >= 0 kept, else 0).
  - New src/shared/Config/CoinConfig.luau: Name "COINS", MaxSingleChange
    1,000,000, MaxBalance 1,000,000,000 (safety limits, not balance).
  - ProfileOperations: getCoins / addCoins / spendCoins (CoinOutcome Added,
    Spent, NotEnough, Rejected); whole amounts > 0 only; unusable wallet
    refused. PlayerDataService: getCoins / addCoins / spendCoins(player,
    amount, reason) with a log line per change. Nothing calls them yet.
  - PlayerDataProbe: version checks 11 -> 12; new test 50 (new profile 0,
    11 -> 12 migration, repair, add/spend rules, limits, reload).
  - Checks: luau-lsp, no new errors (PlayerDataService line 325's pcall
    warning is old). Studio Play (by Claude) with the probe ENABLED: 441
    passed, 0 failed; the real Studio profile loaded at version 12. Probe
    switched back to ENABLED = false.
  Money step 2 BUILT (2026-10-30, user: "Start step 2"). COMMITTED AND PUSHED
  with the user's approval ("Commit and push"); `git log` for the hash.
  - PlayerDataService: onCoinsChanged(listener) (player, change, balance,
    reason), called after every add/spend; it still creates no remotes.
  - New src/server/PlayerData/CoinDisplayService.luau (started in
    init.server after PlayerStatsService): player attribute "Coins"
    (CoinConfig.BalanceAttribute) set on load and after each change;
    fires CoinRemotes.CHANGED to that player. Display only.
  - New src/shared/Economy/CoinRemotes.luau (CoinsChanged, CoinChange
    {change, balance, reason}). CoinConfig: BalanceAttribute, format()
    ("1,250").
  - New src/client/UI/CoinCounter.luau (started in init.client): COINS
    badge above the STATS tab (gold coin, counting balance), pop-ups
    (+green / -red, reason under, rise 60 px over 2 s, one per second).
  - StatsRemotes snapshot + PlayerStatsService: `coins`; StatsScreen shows
    "N COINS" under the bodyweight.
  - Checks: luau-lsp, no new errors. Studio Play (by Claude): the real code
    set the attribute to 0 when the save loaded; TEMP display test from the
    command bar (attribute + remote only, nothing saved): badge and coin
    read well; 3 payouts in a row overlapped at first -> spacing raised to
    1 s / 60 px, re-tested: stacked cleanly; a -200 "Shop: Red Belt" pop-up
    shows red and the counter counts down; STATS shows "0 COINS" from the
    real save. NOT tested: PlayerDataService.addCoins -> listener -> screen
    end to end (nothing calls addCoins yet; step 3 will).
  Money step 3 BUILT (2026-10-30, user: "Start step 3"). COMMITTED AND PUSHED
  with the user's approval ("Commit and push"); `git log` for the hash.
  - CoinConfig.LocalMeet [PROVISIONAL]: BasePot 100, PerQualifiedLifter 50,
    PlaceShares {1} / {0.6, 0.4} / {0.5, 0.3, 0.2}, FinishBonus 25,
    PerfectBonus 50, GymRecordBonus 150, OwnGymRecordBonus 40.
  - New src/server/Meet/MeetPayout.luau (pure): pot, forMeet (place
    shares rounded down, finishing, 9/9), forGymRecord (best eligible
    bonus once; empty spot 0).
  - LocalMeetService: Lifter.liftsStarted (counted when a lift really
    starts) and coinsEarned; finishMeet pays each lifter still in the game
    through PlayerDataService.addCoins when current.rewards and puts
    "+N COINS" first in the result note; the gym record callback pays the
    record bonus. Logs "prize pot N coins".
  - New src/server/Dev/CoinPayoutProbe.server.luau (ENABLED false; Studio
    only): MeetPayout checks + a real addCoins payout on the first player.
  - Checks: luau-lsp, no errors. Studio Play (by Claude) with the probe on:
    21 passed, 0 failed; real path 0 -> 225 coins through
    PlayerDataService.addCoins, attribute 225, pop-ups shown ("+150 COINS ·
    1ST PLACE"), a 1,000,000 spend NotEnough (nothing changed). Probe back
    to ENABLED = false. NOT tested: a whole real Local meet paying out
    (needs lifts passed by hand) and the record bonus from a real record.
  Money step 4 BUILT (2026-10-30, user: "Start step 4"). COMMITTED AND PUSHED
  with the user's approval ("Commit and push"); `git log` for the hash.
  - New src/shared/Config/ShopConfig.luau: CounterTag "ShopCounter",
    prompt/buy distances, Categories, 17 Items {id, name, category, model
    (ShopGear_01 part), colours per "<Model>_<Part>", price} [PROVISIONAL].
  - Save version 13: `inventory.owned {[id]=true}` (export type Inventory);
    migrations[12] adds/repairs it (keeps string id = true, drops the rest).
    ProfileOperations: ownsItem, getOwnedItems, purchaseItem (Bought /
    AlreadyOwned / NotEnough / Rejected; coins and item together).
    PlayerDataService: purchaseItem (log + coin pop-up), getOwnedItems.
  - PlayerDataProbe: version checks 12 -> 13; new test 51.
  - New src/shared/Economy/ShopRemotes.luau (OpenShop, GetShop, BuyItem,
    ShopPreviews name). New src/server/Economy/ShopService.luau (started in
    init.server after CoinDisplayService): counter prompt, GetShop, BuyItem
    (rate 0.4 s, known item, at the counter within 24 studs, ShopConfig
    price), copies ShopGear_01 to ReplicatedStorage.ShopPreviews.
  - RoomProps FURNISH.Shop: invisible "ShopPoint" in front of the counter,
    tagged ShopConfig.CounterTag.
  - UIStyle.coin (shared coin drawing; CoinCounter uses it). New
    src/client/UI/ShopMenu.luau (started in init.client): tabs, coins,
    cards with ViewportFrame previews recoloured per item (framed on the
    coloured parts), BUY -> CONFIRM (3 s), OWNED, greyed when unaffordable;
    closes when the player walks 20 studs away.
  - Checks: luau-lsp, no new errors. Studio Play (by Claude, both probes
    on): save checker 457 passed 0 failed; payout probe 21 passed; profile
    loaded at version 13; counter point + prompt; holding E opened the
    menu; belt, wrap and singlet previews read well; bought Ice Wraps with
    the probe's 225 coins -> 25 left, OWNED, "-200 COINS · SHOP: ICE WRAPS"
    pop-up, status message; direct remote cheats refused (owned, too
    expensive, made-up id, number, table, spam, from the lobby); teleporting
    away closed the menu. Fixes after screenshots: card price hidden under
    BUY (preview 150 -> 128 px); singlets framed small (framing on coloured
    parts). Probes back to ENABLED = false. Studio saved nothing.
  MONEY STEP 5 PLANNED (2026-10-30, user: "Start step 5", picked from
  options): GAME_DESIGN §30.6 "Step (5), wearing the gear — plan". All four
  kinds are 3D Blender models (singlet too); always visible; put on / take
  off anywhere from a GEAR tab -> MY GEAR (CHANGED: replaces "change at the
  Lockers"); R15 only. Build order: (5a) the four worn models in Blender
  (check_models, preview, user approval before upload); (5b) worn items
  saved, server dresses characters, GEAR tab.
  5a BUILT (2026-10-30, user: "Start 5a"). NOT COMMITTED, NOT UPLOADED.
  - Default R15 body measured in Studio (CreateHumanoidModelFromDescription):
    part sizes/centres and rig attachments (hip -1.0, knee -1.921, ankle
    -2.93, wrist -0.734, waist -0.6, relative to the HumanoidRootPart).
  - New art/scripts/build_worn_gear_01.py -> new art/blender/WornGear_01.blend
    (collection WornGear_01; "Preview" collection = reference body + 4
    dressed figures, skipped by check_models). 20 meshes, named
    Worn<Item>_<ShopConfig colour key>[_<Segment>], each with a
    "body_part" custom property; the script prints each piece's offset
    from its part's centre (Roblox axes) for 5b. Limb pieces built on the
    right limb only, one mesh shared by both sides. Wraps' Tail colour is
    merged into Body (ShopConfig Tail always equals Body).
  - check_models: CHECK PASSED, 20 meshes, 6,992 triangles; fully dressed
    player = 29 parts, about 10,000 triangles (flat sides one cell; the
    CENTRAL texts are the heaviest pieces, about 600 each).
  - Previews (backface culling on): art/previews/WornGear_01_Lineup.png,
    _Back.png, _Squat.png (Classic, Navy, Black & Gold, Lagoon squatting).
    Fixes after looking: shorter knee sleeves and singlet legs, slimmer
    wraps, sleeve top half longer past the knee.
  APPROVED by the user (2026-10-30: "Looks good, go on").
  Money step 5b BUILT (2026-10-31). COMMITTED AND PUSHED with the user's
  approval ("Commit and push", 2026-10-31) together with the gear rework,
  the lighting and dev coins; `git log` for the hash.
  UPLOAD DONE (2026-10-31): the user replaced the key file's contents (the
  old file held a key that had been regenerated on the Creator Hub, so its
  secret no longer matched; the new key is user-owned with Assets read +
  write, and the uploader still makes the GROUP the owner). Uploaded as
  rbxassetid://75664723615342 (materials.json WornGear_01);
  WornGearConfig.AssetId set. Loaded in Studio: 20 MeshParts exactly at
  the printed centres, front -Z, no rotation.
  Studio Play (by Claude) with the real asset: "worn gear loaded: 20
  pieces"; bought Blaze Wraps and wore them through SetWorn -> 6 pieces
  on both wrists; a full set (Meet Day Red singlet, Classic Black belt,
  Central Navy sleeves, Blaze wraps) on the user's own R15 avatar: 29
  pieces, screenshots show a snug fit with the CENTRAL badges readable;
  a held squat pose (joint transforms): sleeves, belt and wraps follow
  their body parts. MY GEAR opened with Y; after a layout fix (no line
  under the headings, TAKE OFF only when worn, empty rows shrink) all four
  rows fit; WEAR -> card WORN with a yellow outline, "Wearing: Classic
  Wraps", TAKE OFF shown, status message. Coin probe back to ENABLED =
  false; all probes off.
  (Earlier, before the upload:)
  - Exported art/exports/WornGear_01.glb (collection only, export_yup,
    export_apply, no materials, 20 objects); materials.json "models"
    entry WornGear_01 added with empty ids. Upload FAILED: Roblox answered
    401 "Invalid API Key": the Open Cloud key in
    %USERPROFILE%\.fwjelaa\roblox-open-cloud.key no longer works. The user
    must make a new key (group 529442797, Assets read + write) and put it
    in that file; then run upload_group_images.py, put the id in
    WornGearConfig.AssetId, and test the gear on a character in Studio.
  - Save version 14: `inventory.wearing { [slot] = itemId }`;
    migrations[13] adds/repairs it (keeps string slot -> owned id; makes a
    missing inventory). ProfileOperations.getWorn / setWorn (Worn /
    TakenOff / NotOwned / Rejected); PlayerDataService.setWorn / getWorn.
    PlayerDataProbe: version checks 13 -> 14; new test 52.
  - New src/shared/Config/WornGearConfig.luau (AssetId = 0, Slots with
    their ShopConfig category and body parts per piece segment,
    DefaultBody sizes/centres, Anchors, Materials, OpenKey Y).
  - New src/shared/Economy/GearRemotes.luau (GetGear, SetWorn; view has
    owned, wearing, drawn).
  - New src/server/Economy/WornGearFit.luau: fromModel (finds the model's
    turn from 3 anchor pieces, so the import's own axes don't matter;
    each piece's CFrame relative to its default body part) and dress
    (clone, ShopConfig colours, materials, Weld to the part, scaled by
    part size, mirrored for left limbs, massless / no collide / touch /
    query / shadow; R15 only).
  - New src/server/Economy/GearService.luau (started in init.server after
    ShopService): loads the asset once via InsertService, GetGear,
    SetWorn (slot + category checks, 0.3 s rate limit), dresses each
    character after its data + appearance load and after every change,
    re-fits when a body part's Size changes.
  - New src/client/UI/GearPreview.luau (the Shop's 3D preview, shared;
    ShopMenu now uses it). New src/client/UI/GearMenu.luau (started in
    init.client): GEAR tab under TELEPORT + key Y, MY GEAR rows per slot
    with cards (WEAR / WORN), TAKE OFF, status hints (R6, not drawn yet).
  - New src/server/Dev/WornGearProbe.server.luau (ENABLED false): tests
    WornGearFit with a stand-in model (plain parts at the printed piece
    centres, the model turned 180 degrees and moved).
  - Checks: luau-lsp, no new errors. Studio Play (by Claude): save checker
    473 passed 0 failed; profile loaded at version 14; WornGearProbe 13
    passed 0 failed (after fixing the probe to compare per body part, and
    a 1-degree turn from the off-centre buckle anchor in fromModel);
    remotes from the client: bought Classic Wraps, wear / swap / take off
    worked and the view matched; wrong slot, not owned, unknown slot,
    junk ids and spam refused.
  - NOT TESTED: the MY GEAR menu and GEAR tab on screen (Studio
    screenshots and simulated keys/clicks timed out in this session), and
    real meshes on a character (waiting for the upload).
  DEV COINS (2026-10-31, user: "How do i give myself inf coins"): new
  src/server/Dev/DevCoins.server.luau, Studio only, tops coins up to
  1,000,000 whenever they drop below 100,000 through
  PlayerDataService.addCoins; refuses to run when Studio's API access is
  on (the save store is shared with the live game). Committed with
  ENABLED = false; set it to true in Studio to test the Shop / MY GEAR.
  Tested: 1,000,000 on Play; bought 4 items.
  LIGHTING (2026-10-31, user: "its so bright and glary"): new
  src/shared/Config/LightingConfig.luau + src/server/World/LightingSetup.luau
  (applied at server start in init.server, before the gym is built):
  sun Brightness 2.5 -> 1.6, ExposureCompensation 0 -> -0.25, Ambient
  0.43 -> 0.33, OutdoorAmbient 0.5 -> 0.42, EnvironmentSpecularScale
  0.5 -> 0.25, Bloom 1 / 24 / 2 -> 0.3 / 14 / 2.6, Atmosphere Density
  0.3 -> 0.18. Before/after screenshots by Claude in Studio: the bloom
  halos on the plates, uprights and light bars are gone; a fresh Play
  shows every value applied, no errors. APPROVED by the user (2026-10-31:
  "Yes lightning is good"). Committed.
  WORN GEAR REWORK (2026-10-31, user's reference photos; memory
  "worn-gear-style"): build_worn_gear_01.py rebuilt: new swept() helper
  (a profile swept round a rounded box) and side_slab(). Belt: 0.62 tall,
  out to 0.17 at its middle with rounded bulging edges, stitch rows on the
  bulge, a big lever (base 0.62 x 0.46, lever 0.5 x 0.34, hinge). Knee
  sleeves: both halves the same size and meeting exactly at the knee (one
  smooth tube from KNEE+0.30 to KNEE-0.46, a strip of thigh above), a
  hidden collar on the lower half fills the gap when the knee bends, a
  diagonal stripe on each side (WornKneeSleeve_Stripes_Upper, was
  Stripes_Lower), bold logo low on the front. Wraps: one wide band from
  -0.86 to -0.30 (over the top of the hand, up the forearm), rounded edges,
  an edge stripe at top and bottom, bigger loose end and text.
  check_models CHECK PASSED (20 meshes, 6,896 tris). Previews
  art/previews/WornGear_02_*.png; APPROVED by the user ("Looks good,
  upload"). Uploaded rbxassetid://124628901641945, then in Studio on the
  user's avatar a light band showed across each knee sleeve: the avatar's
  idle pose bends the knees ~30 degrees, so the thigh and shin halves
  opened at the front. FIXES (2026-10-31):
  - WornGearFit now places every piece from the wearer's own joint mark
    (rig attachment: Neck, Waist, Hip, Knee, Wrist; WornGearConfig.Joints
    and Slot.parts = { part, joint }) instead of the part's centre, so the
    sleeve halves always meet at the real knee on any body shape (falls
    back to the part centre if a mark is missing).
  - Knee sleeves: each half has a collar (offset 0.054, reaching 0.22 past
    the knee) hidden inside the other half when straight, filling the
    opening when the knee bends; the sleeve top now tucks under the
    singlet's leg (KNEE+0.42) instead of leaving a strip of thigh.
  - check_models CHECK PASSED (20 meshes, 7,056 tris); re-exported and
    uploaded rbxassetid://115016229826377 (materials.json "supersedes"
    lists both earlier ids); WornGearConfig.AssetId and Anchors.front
    (0.015, -0.800, -0.722) set; WornGearProbe CENTRES updated, test bodies
    now hold only the root (joints keep the parts together), new check
    that the thigh's and shin's knee marks are one point.
  - Studio Play (by Claude): "worn gear loaded: 20 pieces"; WornGearProbe
    14 passed 0 failed; on the user's avatar the knee marks coincide
    (0.000 studs); full set bought with dev coins and worn through
    SetWorn (29 pieces); screenshot with knees bent 26/32 degrees: each
    sleeve one solid tube, belt and wraps right. Probe back to ENABLED =
    false.
  MONEY SYSTEM STEPS 1-5 DONE.
  NEXT ACTION: the user's call. Open question from the user (2026-10-31):
  force R15 for everyone, maybe one realistic body made in Blender, and
  later visible muscle gain/loss; Claude recommended forcing R15 now and
  planning the body + muscle tiers as their own design step (not decided
  yet). Not yet seen: gear during a real lift at a rack or on the meet
  platform, and on other players in a 2-player test. Still to see in a real Local meet:
  the payout at the end and a real gym record bonus.
  OLDER NEXT ACTION (done): the user approves the plan / amounts, then step 1 (coins in
  the save: new schema version, migration, server add/spend, probe test).
  Still to see in a real Local meet: the record sign switched on by a real
  record attempt and the platform screen's record facts.
  OLDER NEXT ACTION (done: committed): the user tries the TELEPORT menu and the news lines in
  Studio (a Local meet: set a record, then declare a heavier weight) and
  approves the commit of steps 4 + 4b.
  OLDER NEXT ACTION: the user plays a Local meet in Studio (watch the card and the
  platform screen's facts strip after a good lift) and approves the commit.
  OLDER NEXT ACTION: the user looks at it in Studio (visual check) and approves
  the commit. The user also has a Mock Meet and a deadlift to
  try in Studio.
  Optional:
  turn Studio API access back off if it is not wanted on.
  OLDER NEXT ACTION (done above for the Mock Meet pieces and the Cardio TV;
  the coach's block clipboard is the one block piece left there): per the user's newer rule (memory "models-made-in-blender",
  2026-10-28: every physical model is modelled in Blender, never stacked
  Roblox blocks in code), the block-built pieces from this work are
  candidates for Blender models: the Cardio TV unit (mount, bezel, logo
  chin, soundbar), the Mock Meet Room's check-in desk, the private room's
  platform, judge-free furniture, wait bench, board and banner frames.
  Screens on them stay as StyledScreen SurfaceGuis. (The rewards step that
  was blocked on the weight-class build decision is done, above.)
  Other open threads: the records
  system (needs a decision; no meet system exists yet, §33), more machines,
  the mirror on a phone, the remaining room interiors (Classroom, Media Room,
  Warm-up, Max Testing), the spare room.
  OLD NEXT ACTION (Cardio built above): ask the user what is next.
  Phone and console (user, 2026-10-26: "keep it for milestone step 7"): step 7
  covers BOTH speed (measure on a real phone first: rack hall, Supplement Bar,
  mirror; then a low-detail mode for weak devices) AND controls (touch and
  gamepad versions of the squat / bench / deadlift minigames: gameplay
  mechanics, so options and the user's yes first; console needs to be switched
  on in the experience's device settings before it can be tested).
  OLD NEXT ACTION (built above, user, 2026-10-26, from screenshots): open up the ground floor's
  left side: remove the walls of Dumbbells, Machines and Index so they join
  the hall as an open dumbbell & machine zone (columns hold the spa wing
  above; existing props now, new machine models previewed next); the Office
  stays and takes over the Index's "learn the game" job; the hall's back
  wall becomes a display wall of main records, leaderboards and the meet
  ladder (display boards now, live data in a later gameplay step).
  OLD NEXT ACTION (done above): build the new layout in StarterGymBuilder, in
  steps: (1) closed rooms; (2) the spa wing; (3) settle the [TBD]s with the
  user first. Then continue the room batches (Index, Office, Storage, ...).
  OLD NEXT ACTION (done above): the next batch of 2-3 rooms with the same
  pipeline (textures and props previewed first, variety in colours), per the
  approved room purposes. Reuse PropAssets/propItem/clad; add a new model
  asset per batch.
  OLD NEXT ACTION (done 2026-10-23, stage 5 above): lighting (Lighting.Ambient is black; the other rooms still
  show the upper floor's tiles as their ceiling). Old steps (a)-(d): done;
  (b) reconnect Rojo, run StarterGym_VerifyShell (expect ALL ... CHECKS
  PASSED) and look around; (c) commit stage 4 with approval (files:
  StarterGymBuilder, StarterGymConfig, StarterGym_VerifyShell, GAME_DESIGN,
  DEVELOPMENT_STATUS); (d) then lighting (Lighting.Ambient is black; the
  other rooms still show the upper floor's tiles as their ceiling).
  Side notes from this session (not game work): Claude packaged the
  downloaded art toolkit as an installable skill
  (`C:\Users\treyn\Downloads\roblox-art-pipeline-skill.zip`, SKILL.md at the
  top; needs a real Python 3.10+ to use); and advised NOT to install the
  OmniRoute AI gateway (routes all AI traffic through a third-party proxy,
  includes TLS-stealth/MITM features, terms-of-service risk).
  OLD NEXT ACTION (done above): user runs the move script (Edit mode) and saves, then tests
  in Studio: StarterGym_VerifyShell, ComboRack01_VerifyRacks, walk around,
  racks' prompts. Then stage 2 (hall roof with skylights).

**Long-term design note (user, 2026-10-17):** the final game is intended to
have a LARGE gym, potentially supporting about 30 players per server. The
current four-rack layout (`GymRack_01`-`04`) is TEMPORARY development
infrastructure, NOT the approved final gym layout. Rack count and positions
stay in `TrainingStationConfig.GymRacks` so the layout can grow without code
changes. Not yet a GAME_DESIGN decision.

**Studio place:** the game is the CLOUD place `96814269062063` (universe
`10769034794`), not a local file. Always open it from Studio's Recent /
My Experiences or Creator Hub "Edit in Studio". On 2026-10-17 a restart opened
Roblox's blank Baseplate template (`95206881`) instead; Rojo synced the scripts
and template into it, so only the hand-placed objects looked "missing". Check
with `print(game.PlaceId)` before working or saving.

## 1. Latest Verified Commit

- 2026-10-29, pushed: Remove the Competition Budget (save version 10); `git log -1` for the hash.
- `f76ffb8` (2026-10-29, pushed) Build the Local meet, step 2: rewards and the meet CN allowance (save version 9).
- `baa73cb` (2026-10-29, pushed) Record the user's passing two-player Local meet test.
- `db796f5` (2026-10-29, pushed) Build the Local meet, step 1: the meet itself on a temporary venue.
- `29fae94` (2026-10-29, pushed) Decide the Local meet's first build (turns, placing, start, venue).
- `ab14393` (2026-10-29, pushed) Keep the Scale challenge fixed for the whole meet, and record the user's Mock Meet test.
- `dda82af` (2026-10-29, pushed) Save a Mock Meet's proven lifts only when it ends with a total.
- `ca82437` (2026-10-29, pushed) Decide meet risk: a daily meet CN allowance, misses use it, a bomb-out saves nothing.
- `84c48a4` (2026-10-29, pushed) Retire Training Energy and record meet CN raises (checkpoint 8, save version 8).
- `d6a8c4b` (2026-10-29, pushed) Add the Competition Scale challenge to meet attempts (checkpoint 6).
- `b67b8a7` (2026-10-29, pushed) Remove PullStrength (checkpoint 9, save version 7).
- `56f7249` (2026-10-29, pushed) Count only real door panels and shop gear in StarterGym_VerifyShell.
- `bc4d903` (2026-10-29, pushed) Replace the gym's block steel with Blender I-beams and handrails (blocks to Blender, batch 9).
- `8a62d1b` (2026-10-29, pushed) Replace the themed fronts' block details with Blender models (blocks to Blender, batch 8).
- `5ed9cb2` (2026-10-29, pushed) Replace the back rooms' block furniture with Blender models (blocks to Blender, batch 7).
- `83234f1` (2026-10-29, pushed) Replace the spa wing's block furniture with Blender models (blocks to Blender, batch 6).
- `3118407` (2026-10-29, pushed) Replace the Cafe, Supplement Bar and Shop block furniture with Blender models (blocks to Blender, batch 5).
- `a29fb82` (2026-10-29, pushed) Replace the reception's block furniture with Blender models (blocks to Blender, batch 4).
- `a0206d1` (2026-10-29, pushed) Replace the block door pieces and name plaques with Blender models (blocks to Blender, batch 3).
- `177c37e` (2026-10-28, pushed) Replace the block light fittings with Blender models (blocks to Blender, batch 2).
- `3d267e2` (2026-10-28, pushed) Replace the shared block furniture with Blender models (blocks to Blender, batch 1).
- `1e9d3de` (2026-10-28, pushed) Record the user's Studio check of the Mock Meet models in DEVELOPMENT_STATUS.
- `44375cd` (2026-10-28, pushed) Replace the Mock Meet's block furniture with Blender models.
- `368eee0` (2026-10-28, pushed) Add weight-class builds (save v6) and let the Mock Meet save Competition Scale and best Total.
- 2026-10-28, pushed: Add the Blender Cardio TV; `git log -1` for the hash.
- `d5fa7d4` (2026-10-28, pushed) Performance pass: fewer decor shadows, triangle budgets, a performance audit tool.
- `8b17791` (2026-10-28, pushed) Vary the heading marks and restyle the Mock Meet signs and coach bubble. (It also carried part of the Blender Cardio TV's RoomProps code from a parallel session; without that session's PropAssets entry it falls back to the block TV.)
- `ca8dc47` (2026-10-28, pushed) Restyle the treadmill game, its leaderboards, and rebuild the Cardio TV (UI restyle step 5).
- `4039899` (2026-10-28, pushed) Add the PLAYER STATS screen (UI restyle step 4).
- `5f85a67` (2026-10-28, pushed) Restyle the rack menu and every "E" prompt (UI restyle step 3).
- `bd7f298` (2026-10-28, pushed) One UI style for the Mock Meet and all lift minigames (UI restyle steps 1-2).
- `ea6f636` (2026-10-28, pushed) Run the Mock Meet itself: attempts, lifts, coach and results (Mock Meet part 2).
- `023f46c` (2026-10-28, pushed) Add the Mock Meet Room and a private meet room per player (Mock Meet part 1).
- `3eb5be1` (2026-10-27, pushed) Design: player-set World Records, Sheffield vs configured records, gym record rules.
- `2d137c1` (2026-10-27, pushed) Add the rhythm game's saved leaderboards (part 2: all-time and weekly boards).
- `7f1521b` (2026-10-27, pushed) Fix see-through bar stools and Shop gear, and check every model for it.
- `854c352` (2026-10-27, pushed) Fix inside-out room props: lathed and ring shapes now render solid.
- `f2e8ee1` (2026-10-27, pushed) Fix the Strongman tyre's see-through gaps and remove the shed's STRONGMAN sign.
- `e728f47` (2026-10-26, pushed) Add the treadmill rhythm game (part 1: rounds, lanes, health and our own beat).
- `5a189cb` (2026-10-26, pushed) Add the Cardio room: 11 machines players can hop on.
- `e29401e` (2026-10-26, pushed) Add the open zone's machines: tricep and lat pulldowns, seated rows and leg extensions.
- `4044e82` (2026-10-26, pushed) Open the dumbbell & machine zone, add the chalk records wall and a real mirror.
- `bac11b5` (2026-10-26, pushed) Add themed room fronts batch 2b and replace the big room signs with name plaques.
- `fd4469d` (2026-10-26, pushed) Add themed room fronts batch 2a: Office, Machines, Index and Storage.
- `2619ca0` (2026-10-26, pushed) Close the gym's rooms with real doors, add the Recovery & Spa wing, themed room fronts (batch 1) and the Strongman Shed.
- `d045cd5` (2026-10-26, pushed) Remake the Showers, Recovery and Massage with CC0 textures and CENTRAL props.
- (2026-10-21, pushed) Build the Starter Gym reception with the SBD Central desk and Elite Prep Gym signs (stage 4).

- (2026-10-19, pushed) Lay out 30 gym racks in three rows and fix J-cups dropping twice (Starter Gym steps 1-2).
- `dbdacc4` (2026-10-19, pushed) Add the Visual Style reference note.
- `e64b0de` (2026-10-19, pushed) Add station rep animations for squat, bench and deadlift.
- `2168230` (2026-10-19, pushed) Add Barbell_01 and place the barbell and lifter per lift at every station.
- `363118b` (2026-10-18, pushed) Use ComboRack_01 for every gym station and hide the bench per lift.
- `a816769` (2026-10-18, pushed) Add ComboRack_01 station blockout model (black combo rack with bench).
- `0eadd1a` Replace the placeholder training stations with spawned racks (Step 6D.2c).
- `e4e5f53` Replace the hand-placed power rack with a spawned rack (Step 6D.2b).
- `9f4fdb0` Spawn gym racks automatically from the rack template (Step 6D.2a).
- `2555c49` Add Git-tracked power rack template synced by Rojo (Step 6D.2 Phase 0).
- `4efb75c` Integrate Blender power rack with training stations (Step 6D.1).
- `27a3214` Add verified Blender power rack assets and development docs (6B/6C).
- `5999fa1` Add unlimited gym technique stat progression (Step 5B.7).

## 2. Completed Checkpoints

- **Step 5** (gym training system), up to and including 5B.7. Committed.
- **Step 6A**: Blender MCP integration verified (Claude can drive the live Blender).
- **Step 6B PASSED**: Blender-to-Roblox scale calibration. User-verified in Studio:
  `ScaleTest_2StudCube_v2.fbx` imported at 2 x 2 x 2 studs with no resizing.
- **Step 6C PASSED**: `PowerRack_01` modeled, exported and imported into Studio.
  User confirmed: dimensions correct, rack upright, main components visible.
- **Step 6D.1 PASSED** (user's Studio multiplayer test, 2026-10-14): the
  hand-imported `PowerRack_01` works as a training station. See section 6.
- **Step 6D.2 Phase 0 PASSED** (user-verified in Studio, 2026-10-14): Git-tracked
  rack template synced into Studio by Rojo; visually matches the working rack.
  Temporary test model cleaned up and verified. See section 6.
- **Step 6D.2a PASSED and committed** (all Studio tests user-verified 2026-10-14
  to 2026-10-17; committed and pushed 2026-10-17). See section 6.
- **Step 6D.2b PASSED and committed** (user-verified in Studio 2026-10-17):
  hand-placed rack replaced by the spawned `GymRack_02`, removed from the cloud
  place and saved; code committed and pushed 2026-10-17. See section 6.

## 3. Reference

**Verified FBX export settings (project standard, Step 6B):**
- Limit to: Selected Objects; Object Types: Mesh only
- Transform: **Scale 0.01**, Apply Scalings "FBX Units None", Forward **-Z**,
  Up **Y**, Apply Unit **on**, Apply Transform **on**
- Geometry: Smoothing "Face", Apply Modifiers on
- Armature: Add Leaf Bones off; Animation (Bake) off
- Blender scene units: Metric, Unit Scale 1.0
- Why: Blender writes 1 unit as 100 FBX units (cm) and Studio reads the raw
  numbers as studs. Scale 0.01 makes the stored numbers equal stud sizes. Side
  effect: Blender re-imports these files 100x too small. That is expected.

**PowerRack_01 (art):** source `art/blender/PowerRack_01.blend`, export
`art/exports/PowerRack_01.fbx` (21 meshes), build script
`art/scripts/build_power_rack_01.py`. Size 6.06 W x 6.54 D x 8.0 H studs. In
Roblox: height +Y, J-cup (front) side **-Z**, Blender "Left" at +X (corrected
2026-10-18 from the template's .rbxmx CFrames; older notes said +Z). Parts: `Upright_*` x4, `Crossbar_*` x4,
`BaseRail_Left/Right/Back`, `JCup_*`, `JCupLiner_*`, `JCupPin_*`, `SafetyBar_*`,
`SafetyPins`, `FrameBolts`. One material per part. J-cup/safety heights provisional.

**ComboRack_01 (art, 2026-10-18; the model every gym station uses):** black
combo rack with a bench (GAME_DESIGN §34.12 decision 15; reference
`References/Visual Style/Images/Rack_ERCombo_Bench.webp`, simplified, no brand
text). Build script `art/scripts/build_combo_rack_01.py` (run in an empty
file; the blockout version is in `a816769`), source `art/blender/ComboRack_01.blend`,
export `art/exports/ComboRack_01.fbx` (26 meshes, project FBX settings above;
re-import checked: 26 named meshes, 7.9 W x 5.4 D x 7.0 H studs, 7,176 tris).
Detail pass: bmesh-baked bevels, smooth shading with sharp edges > 50 degrees
and a Weighted Normal modifier (applied by the FBX export). Blender origin =
tall posts' centre line at floor level, open front -Y (in Roblox: J-cup side
-Z, "Left" at +X, same as PowerRack_01).
- Rack parts (24): `Upright_Left/Right` (black sleeves), `UprightInsert_Left/Right`
  (silver, J-cup holes z 3.10-6.60 every 0.35), `InsertLockPins`,
  `SpotterPost_Left/Right` (with top cradles), `SafetyArm_Left/Right` (with
  brackets), `SafetyPins`, `BaseRail_Left/Right/Back`, `BaseFoot_Left/Right`,
  `SpotterDeck`, `FootCaps` (rubber), `JCup_*`, `JCupLiner_*`, `JCupPin_*`
  (Left/Right), `FrameBolts`.
- Roblox template `art/roblox/ComboRack_01.rbxmx`: 1 Model + 26 MeshParts with
  uploaded meshes, all anchored, CanCollide/CanTouch off (RackConfigurator sets
  collision at runtime: solid = the 2 tall + 2 short posts), looks from the
  prepare script (Metal black steel / zinc inserts / grey hardware, Rubber caps
  and liners, Leather pad, DiamondPlate deck). `RenderFidelity = Precise` on
  FootCaps, FrameBolts, SafetyPins, InsertLockPins (edited in the .rbxmx).
- **Rojo can drop MeshIds when it syncs a MeshPart template** (2026-10-18: the
  Studio copy had blank MeshIds, so every part rendered as a plain box of its
  Size; Disconnect + Connect with Sync Fallback ON fixed it). After any template
  change, check in the Command Bar that every template MeshPart has a MeshId.
  It happened again on 2026-10-19 with the NEW Barbell_01 template (0 of 10
  meshes after the first sync), so: a brand-new MeshPart template needs a
  Rojo Disconnect + Connect after its first sync. Manual fallback: delete
  Rojo's copy in Studio, then right-click the folder -> Insert from File.
- Bench parts (2, hideable): `Bench_Pad` (black vinyl), `Bench_Frame`.
- Provisional heights (studs): bench pad top 1.2; bar rest 3.52 at bench height
  (J-cups modelled there), 4.22 at the squat hole; safety arm top 2.0; inner
  gap between posts 5.4. Deadlift bar spot: 4.2 studs in front of the posts.
- Barbell rule for later: plate sleeves must start >= 3.2 studs from the bar's
  centre (plates hang outside the J-cups).
- The script ends with read-only clearance checks (bench bar path to the chest,
  plates, a lying lifter, squat bar and walkout, deadlift bar and lifter):
  CLEARANCE OK. Negative tests confirmed the check catches a short bar and a
  deadlift bar placed inside the rack.
- Blender session note: before building, the unsaved open `PowerRack_01.blend`
  session was saved as a COPY to the Claude scratchpad
  (`PowerRack_01_session_backup_20261018.blend`); `PowerRack_01.blend` itself
  was not saved or changed.

**Roblox rack template (Step 6D.2 Phase 0):** `art/roblox/PowerRack_01.rbxmx`,
exported from Studio (Edit mode, "Save to File"). Rojo maps it to
`ServerStorage.RackTemplates.PowerRack_01` (`default.project.json`). It holds
1 Model + exactly 21 MeshParts with uploaded `rbxassetid://` MeshIds (13 unique),
all anchored, CanCollide on the 4 Uprights only, default grey Plastic, no tags,
no StationId, no StandPoint/prompt/sign. Only attribute: `RBX_ReimportId`
(Studio importer metadata, harmless). To change the rack: edit in Studio,
re-export to the same path, commit.

**Rojo and MeshParts (Rojo 7.7.1, from its source):** the plugin cannot write
MeshPart `MeshId`/`MeshContent`/`InitialSize`/`PhysicsData`, so MeshParts sync
only through the plugin's "Enable Sync Fallback" setting (ON, default): the
server serializes the part and Studio swaps it in. An orange ⚠ in Rojo's
View Changes means a change FAILED to apply. The first live-sync attempt failed
(cause not captured); the second succeeded. If it fails again, read the
`[Rojo-Warn]` lines and `rojo serve -vv` output. The plugin's Log Level
dropdown offered only Error/Warning/Info for the user.

**Station visuals (2026-10-18):** `StationVisuals.show(rack, lift)` runs from
TrainingStationService `refreshSign` on every occupancy/selection change; it
uses the rack's `RackTemplate` attribute (set by RackSpawner) to find a visuals
profile (only ComboRack_01 has one). Rack profiles (parts, solid posts, centre
posts) live in RackConfigurator; StandPoint = centre posts' average at the
rack's lowest point. `TrainingStationConfig` facing note corrected: 0 = J-cup
side faces -Z.

**Station mechanics (TrainingStationService, unchanged):** racks register by tag
`GymTrainingStation` + string attribute `StationId` (Part or Model, anywhere in the
DataModel; duplicate IDs ignored). For a Model, presence is measured from
`GetPivot()` (radius 12), and the prompt (+3 studs, reach 8) and sign (+7) hang on
`PrimaryPart`. Rack titles come from `TrainingStationRules.rackTitle` (6D.2a):
the full trailing number ("Training Rack 01"), else the last character ("A").

**Studio Command Bar scripts:** temporary, in `tools/studio/` (not Rojo-mapped,
not game code). Rules: `CLAUDE.md` "Automation-First Workflow". Type-check with
the luau-lsp analyzer bundled in the VS Code extension
(`%USERPROFILE%\.vscode\extensions\johnnymorganz.luau-lsp-*\bin\server.exe analyze
--definitions=@roblox=<globalStorage>\globalTypes.PluginSecurity.d.luau <file>`).

**Design rules:** 1 Blender unit = 1 stud; never fix scale by resizing. One
material per object. Specific names (never `Cube.001`). Art work must not edit
gameplay scripts. Rack design: `GAME_DESIGN.md` section 34. There is NO approved
gym layout yet (GAME_DESIGN has no section 27; an older note here pointed to one).

## 4. Uncommitted Work

Deliberately left uncommitted (keep, never discard):
- `art/blender/PowerRack_01.blend`: shows modified (saved 14:41 on 2026-10-14,
  after commit 27a3214). Reason unknown. User decision: EXCLUDED from Phase 0;
  investigate separately later.
- `PlaceBackup_Before6D2.rbxl` (project root): Studio place backup made before
  the Phase 0 sync test. Never commit.
- `PlaceBackup_ServerSnapshot_20261016.rbxl` (project root): exact copy (SHA-256
  checked) of Studio's Local Server snapshot `%LOCALAPPDATA%\Roblox\server.rbxl`
  from 2026-10-16 23:53, made 2026-10-17. Contains `Workspace.PowerRack_01`
  (21 MeshParts). Safety copy only. Never commit. Since 6D.2b it is also a
  restore source for the removed hand-placed rack.
- `art/exports/ScaleTest_2StudCube.fbx`: v1, the failed 200-stud test. Local reference only.
- `art/blender/PowerRack_01.blend1`: Blender's automatic backup, ignored by the
  local `.gitignore` rule `*.blend1`.
- `.gitignore` (adds `ClaudeLogs/` and `*.blend1`), `.claude/hooks/Export-ClaudeLog.ps1`
  and `.claude/settings.json`: the conversation-log tooling. Not staged unless the user asks.
- `References/DBD.md`: line endings only, no content change. Do not edit.
- `art/blender/Animations.blend` (2026-10-19): the preview scene saved from
  `art/scripts/station_animations.py` (3 rigs, actions, linked rack/barbell).
  Regenerated by the script, so KEEP LOCAL; ignored by the local `.gitignore`.
- `References/Visual Style/Images/` (2 .webp photos of real gym products):
  third-party images and the GitHub repo is PUBLIC, so KEEP LOCAL; ignored by
  the local `.gitignore`.
- `References/Visual Style/Visual Style.md`: the approved art-direction note,
  referenced by GAME_DESIGN.md and the build scripts. COMMITTED and pushed
  2026-10-19 with user approval as "Add the Visual Style reference note"
  (`git log` for the hash). Its two image embeds stay local (above).

Lockers, Cafe and Staff Room remade with the kits + private Lockers (Studio-tested and user-approved 2026-10-25; COMMITTED and pushed 2026-10-25 with user approval as "Remake the Lockers, Cafe and Staff Room with CC0 textures and CENTRAL props; make the Lockers private"; `git log` for the hash):
- New: `art/scripts/prop_helpers.py`, `art/scripts/build_room_props_02.py`,
  `art/blender/RoomProps_02.blend`, `art/exports/RoomProps_02.glb`.
- Changed: `art/materials/materials.json`, `default.project.json`,
  `src/server/World/RoomProps.luau`, `src/server/World/StarterGymBuilder.luau`,
  `src/shared/Config/StarterGymConfig.luau`, `tools/studio/StarterGym_VerifyShell.luau`,
  `GAME_DESIGN.md`, `DEVELOPMENT_STATUS.md`.
- Keep OUT: the same unrelated files as above.

Supplement Bar remade with the kits (Studio-tested 2026-10-25; COMMITTED and pushed 2026-10-25 with user approval as "Remake the Supplement Bar with CC0 textures and CENTRAL product models"; `git log` for the hash):
- New: `art/scripts/upload_group_images.py`, `art/materials/materials.json`,
  `art/scripts/build_sbar_props_01.py`, `art/blender/SBarProps_01.blend`,
  `art/exports/SBarProps_01.glb`, `art/scripts/prep_sbar_plant.py`, `art/exports/SBarPlant_01.glb`.
- Changed: `default.project.json` (MaterialService variants), `src/server/World/BuildParts.luau`,
  `src/server/World/RoomProps.luau`, `src/shared/Config/StarterGymConfig.luau`,
  `tools/studio/StarterGym_VerifyShell.luau`, `GAME_DESIGN.md`, `DEVELOPMENT_STATUS.md`.
- Keep OUT: the same unrelated files as above.

Starter Gym step 6a + shop gear + sauna upstairs (Studio-tested 2026-10-25; COMMITTED and pushed 2026-10-25 with user approval as "Furnish the Starter Gym ground floor, add the shop gear models and move the sauna upstairs (step 6a)"; `git log` for the hash):
- New: `src/server/World/BuildParts.luau`, `src/server/World/RoomProps.luau`,
  `art/roblox/ShopGear_01.rbxmx`, `art/scripts/build_shop_gear_01.py`,
  `art/scripts/prepare_shop_gear_rbxmx.ps1`, `tools/studio/ShopGear01_PrepareImport.luau`.
- Changed: `src/server/World/StarterGymBuilder.luau`, `src/shared/Config/StarterGymConfig.luau`,
  `src/client/World/AutoDoorAnimator.luau` (swing doors), `default.project.json`
  (PropTemplates.ShopGear_01), `tools/studio/StarterGym_VerifyShell.luau`,
  `GAME_DESIGN.md` (§27 room quality, CENTRAL, sauna upstairs, room purposes),
  `DEVELOPMENT_STATUS.md`.
- Also `art/blender/ShopGear_01.blend` and `art/exports/ShopGear_01.fbx`: the
  user chose (2026-10-25) to include them in the public repo.
- Keep OUT: the same unrelated files as above.

Starter Gym step 3, gym shell v1 + v2 stage 1 (Studio-tested; COMMITTED and pushed 2026-10-21; listed for reference):
- New: `src/server/World/StarterGymBuilder.luau`,
  `src/shared/Config/StarterGymConfig.luau`, `tools/studio/StarterGym_VerifyShell.luau`,
  `tools/studio/StarterGym_MoveSpawnToLobby.luau`.
- Changed: `src/server/init.server.luau` (builds the shell),
  `src/shared/Config/TrainingStationConfig.luau` (GymLayout.floorY 0.05,
  racks at that height; v2: spacing 16 / 28),
  `src/server/Training/TrainingStationService.luau` (no rack sign; prompt text),
  `src/server/Dev/GymRackWatchProbe.server.luau` (reads the prompt),
  `tools/studio/ComboRack01_VerifyRacks.luau` (expects no sign),
  `GAME_DESIGN.md` (§27 v2 building, rack signs),
  `References/Visual Style/Visual Style.md` (shell references and the user's picks),
  `DEVELOPMENT_STATUS.md`.
- Keep OUT: the same unrelated files as above.

Starter Gym steps 1-2 (Studio-tested; COMMITTED and pushed 2026-10-19; listed for reference):
- New: `tools/studio/GymStressTest_SceneStats.luau`.
- Changed: `src/shared/Config/TrainingStationConfig.luau` (GymLayout, GymRacks
  built from it), `src/server/Training/StationVisuals.luau`,
  `src/server/Training/StationPoses.luau`,
  `src/client/Training/StationPoseAnimator.luau` (weak tables -> strong,
  the GymRack_28 J-cup fix), `tools/studio/ComboRack01_VerifyRacks.luau` (count and
  spacing checks, PASS lines counted), `GAME_DESIGN.md` (§27 floor plan),
  `DEVELOPMENT_STATUS.md`.
- Keep OUT: the same unrelated files as above.

ComboRack_01 blockout files (4, COMMITTED `a816769` and pushed 2026-10-18; for reference):
- New: `art/scripts/build_combo_rack_01.py`, `art/blender/ComboRack_01.blend`,
  `art/exports/ComboRack_01.fbx`. Changed: `DEVELOPMENT_STATUS.md`.

ComboRack_01 station swap (COMMITTED and pushed 2026-10-18; Studio-tested; listed for reference):
- New: `art/roblox/ComboRack_01.rbxmx`, `src/server/Training/StationVisuals.luau`,
  `tools/studio/ComboRack01_PrepareImport.luau`, `tools/studio/ComboRack01_VerifyRacks.luau`,
  `tools/studio/ComboRack01_PreviewTemplate.luau` (diagnostic).
- Changed: `art/scripts/build_combo_rack_01.py`, `art/blender/ComboRack_01.blend`,
  `art/exports/ComboRack_01.fbx` (detail pass), `default.project.json` (template
  mapping), `src/server/Training/RackConfigurator.luau`,
  `src/server/Training/RackSpawner.luau`, `src/server/Training/TrainingStationService.luau`
  (StationVisuals call only), `src/shared/Config/TrainingStationConfig.luau`,
  `DEVELOPMENT_STATUS.md`, `GAME_DESIGN.md` (decision 15 status cell; the file
  also holds the 2026-10-18 approved decisions written earlier: §27 layout
  direction and §34.12 decision 15).
- Not changed: progression, player data, training rules, registration, menu,
  ticks, PowerRack_01 template and profile.
- Checks by Claude: luau-lsp with sourcemap 0 errors in every changed Luau file
  (errors only in the untouched files of section 5); `rojo build` OK (templates
  ComboRack_01 26 MeshParts, PowerRack_01 21); `git diff --check` clean.
- `tools/studio/Step6D2a_VerifyRacks.luau` now reports failures (it expects
  PowerRack_01's 21 parts); `ComboRack01_VerifyRacks.luau` replaces it.
- Keep OUT: the same unrelated files as above.

Barbell + station positioning (COMMITTED and pushed 2026-10-19 as "Add Barbell_01 and place the barbell and lifter per lift at every station"; Studio-tested):
- New: `art/scripts/build_barbell_01.py`, `art/blender/Barbell_01.blend`,
  `art/exports/Barbell_01.fbx`, `art/roblox/Barbell_01.rbxmx`,
  `src/server/Training/StationLayout.luau`, `src/server/Training/StationPoses.luau`,
  `tools/studio/Barbell01_PrepareImport.luau`.
- Changed: `src/server/Training/StationVisuals.luau` (barbell, positions from
  StationLayout), `src/server/Training/TrainingStationService.luau` (one
  StationPoses call in refreshSign), `src/shared/Config/TrainingStationConfig.luau`
  (BarbellDisplayLoadPerSide), `default.project.json` (BarbellTemplates),
  `art/scripts/build_combo_rack_01.py` (clearance check uses the bigger
  plates; geometry unchanged, re-run: CLEARANCE OK), `tools/studio/ComboRack01_VerifyRacks.luau`
  (barbell and pose checks), `GAME_DESIGN.md` (decision 15: poses approved,
  deadlift faces the rack), `DEVELOPMENT_STATUS.md`.
- Checks by Claude: luau-lsp 0 errors in every changed Luau file; `rojo build`
  OK (BarbellTemplates/Barbell_01 10 MeshParts); `git diff --check` clean.
- Keep OUT: the same unrelated files as above.

Station rep animations (COMMITTED and pushed 2026-10-19 as "Add station rep animations for squat, bench and deadlift"; Studio-tested):
- New: `art/scripts/station_animations.py`, `art/animations/R15_BlockRig.rbxmx`
  (reference rig), `art/animations/Station_Squat.rbxmx`, `Station_Bench.rbxmx`,
  `Station_Deadlift.rbxmx`, `src/shared/Config/StationAnimationConfig.luau`,
  `src/client/Training/StationPoseAnimator.luau`.
- Changed: `src/client/init.client.luau` (starts StationPoseAnimator),
  `src/server/Training/StationPoses.luau` (squat faces the rack; StationRack
  attribute), `src/server/Training/StationVisuals.luau` (J-cup heights per
  lift; RestCFrame attribute), `src/server/Training/StationLayout.luau`
  (benchJCupDrop), `art/scripts/build_combo_rack_01.py` (clearance check at
  the new J-cup heights; geometry unchanged, CLEARANCE OK),
  `tools/studio/ComboRack01_VerifyRacks.luau` (new J-cup heights, squat
  facing), `GAME_DESIGN.md` (decision 15), `DEVELOPMENT_STATUS.md`.
- Checks by Claude: luau-lsp 0 errors in every changed Luau file; `rojo build`
  OK; `default.project.json` unchanged from the last commit.
- Keep OUT: the same unrelated files as above.

Step 6D.2a files (14, COMMITTED 2026-10-17; listed for reference):
- New: `src/server/Training/RackConfigurator.luau`, `src/server/Training/RackSpawner.luau`,
  `src/server/Dev/GymRackWatchProbe.server.luau` (ENABLED = false, checked in the
  Rojo build), `src/client/Dev/GymRackWatchDisplay.luau`,
  `tools/studio/Step6D2a_VerifyRacks.luau`, `tools/studio/Step6D2a_VerifyEditModeClean.luau`,
  `tools/studio/Step6D2a_CheckWatchSync.luau`.
- Changed: `src/server/init.server.luau`, `src/client/init.client.luau`,
  `src/shared/Config/TrainingStationConfig.luau`,
  `src/shared/Training/TrainingStationRules.luau`,
  `src/server/Training/TrainingStationService.luau`,
  `src/client/Training/TrainingMenuController.luau`, `DEVELOPMENT_STATUS.md`.
- Keep OUT of the 6D.2a commit: `PowerRack_01.blend`, `PlaceBackup_Before6D2.rbxl`,
  `PlaceBackup_ServerSnapshot_20261016.rbxl`, `ScaleTest_2StudCube.fbx`,
  `.gitignore`, `.claude/`, `References/DBD.md` (above).

Step 6D.2b files (9 entries, COMMITTED 2026-10-17; listed for reference):
- Deleted: `src/server/Training/PowerRackSetup.luau`.
- New: `tools/studio/Step6D2b_RemoveHandPlacedRack.luau`.
- Changed: `src/server/init.server.luau`, `src/shared/Config/TrainingStationConfig.luau`,
  `src/server/Training/RackSpawner.luau`, `src/server/Training/RackConfigurator.luau`,
  `tools/studio/Step6D2a_VerifyRacks.luau`, `tools/studio/Step6D2a_VerifyEditModeClean.luau`,
  `DEVELOPMENT_STATUS.md`.
- Keep OUT: the same unrelated files as above.

Step 6D.2c files (7 entries, COMMITTED 2026-10-17; listed for reference):
- Deleted: `src/server/Training/PlaceholderStations.luau`.
- Changed: `src/shared/Config/TrainingStationConfig.luau`,
  `src/server/Training/TrainingStationService.luau`,
  `src/server/Training/RackSpawner.luau`, `tools/studio/Step6D2a_VerifyRacks.luau`,
  `GAME_DESIGN.md` (§34.12 decision 12 + implementation note), `DEVELOPMENT_STATUS.md`.
- Keep OUT: the same unrelated files as above.

Closed rooms, spa wing, themed fronts batch 1 and the Strongman Shed (2026-10-26;
Studio-tested and user-approved; COMMITTED and pushed 2026-10-26 with user
approval, `git log` for the hash).

Themed fronts batch 2a and 2b, name plaques (2026-10-26; Studio-tested and
user-approved; COMMITTED and pushed 2026-10-26 with user approval, `git log`
for the hashes).

Open zone, chalk records wall, mirror (2026-10-26; Studio-tested and
user-approved; COMMITTED and pushed with user approval, `git log` for the
hash).

## 5. Current Limitations

- Every modeled rack now exists only at runtime, from the template. Spawned racks need `ServerStorage.RackTemplates` in the running place. In
  Studio, Rojo provides it. A PUBLISHED game only has it if the place was
  saved/published while Rojo had synced it; otherwise RackSpawner skips every
  gym rack with a warning (the game still runs).
- Since 6D.2c the placeholder platforms are retired; ALL training
  stations are now spawned racks. If the template were missing from a running
  place, there would be NO training stations (before 6D.2c the placeholders
  still worked). The saved cloud place had the template at the 6D.2b check.
- Since 2026-10-19 the racks follow the approved floor plan (GAME_DESIGN §27,
  Option B, 30 racks); its exact numbers are provisional, in
  `TrainingStationConfig.GymLayout`. There are no gym walls or floor yet.
  All racks face 0, i.e. their open J-cup front faces -Z (corrected
  2026-10-18; older notes said +Z). ComboRack_01
  reaches 3.0 studs to the front, 2.05 to the back and 3.95 to each side of
  its position; the deadlift spot is about 4.2 studs in front.
- Training signs work, but their visual design needs improvement (user,
  2026-10-17). Sign polish is deferred until the user asks.
- ComboRack_01 has first-pass Roblox materials/colours (prepare script); not
  yet reviewed in final gym lighting. No barbell, plates, player poses or gym yet.
- Pre-existing luau-lsp type errors in untouched files: LiftAttemptService,
  PlayerDataService:318, LiftAttemptConfig, LiftingRemotes, CompetitionNumberReward,
  and `src/client/Lifting/ControlInput.luau:44-45` (Enum.UserInputType; file
  unchanged since 2026-10-05; first noted 2026-10-17).

## 6. Step 6D: Functional Rack Integration

**6D.1: DONE.** Hand-imported rack configured automatically at server start.
- `src/server/Training/PowerRackSetup.luau` (temporary bridge, replaced by 6D.2).
  It finds the single direct Workspace child `PowerRack_01` and checks for all 21
  named MeshParts. It anchors everything, sets CanTouch off, and leaves CanCollide
  on for the 4 posts only. It creates or reuses an invisible `StandPoint` (2 x 0.2 x 2)
  at the posts' floor centre as PrimaryPart (pivot checked), sets
  `StationId = PowerRack_01`, and adds the tag LAST. It fails closed (warning, no tag),
  and on duplicate names prints read-only diagnostics for every candidate. Runtime
  only: it never edits the saved place.
- `src/server/init.server.luau` calls `PowerRackSetup.configure()` before any system
  starts, so the rack is anchored early and tagged before the service reads tags.
- User-verified (2 players): the rack stays standing; hold-E works; the menu
  opens; one player per rack; walking away releases it.

**6D.1 open cases (historical; all covered by the 6D.2a tests at GymRack_01
below, except cross-session persistence, which was skipped by decision):**
- CN training raising Competition Number, and Technique training raising the
  chosen stats (both proven at the placeholders in 5B, not re-run here).
- One player trying to use two racks ("already using another rack").
- Release by reset/death and by leaving the game (walk-away is verified).
- No double credit (one tick line per player per ~10 s).
- Placeholder racks still working alongside the modeled rack.
- A fresh Play session re-running the setup with one prompt and one sign.
- Collision feel (walk in through the open front, posts solid, no snagging).

**6D.2 Phase 0: PASSED and committed** (`2555c49`, pushed; origin/main matched 2026-10-14). Reusable rack template.
- Template exported, mapped by Rojo, `rojo build` OK (21 MeshParts, 21 mesh URIs,
  InitialSize and PhysicsData present). Mapping touches only
  `ServerStorage.RackTemplates`; project nodes without `$path` ignore unknown
  instances, so the working rack and other ServerStorage content are untouched.
- Live sync: test 1 failed (⚠ on every MeshPart, template absent); after a place
  backup and reconnect (Sync Fallback ON), test 2 succeeded.
- `tools/studio/Phase0_SpawnTemplateTest.luau` cloned the template to a marked
  `Workspace.TemplateTest` 12 studs beside the working rack. User verified: 21
  MeshParts, all MeshIds valid, 6.06 x 8 x 6.54 studs, VISUALLY matches the
  working rack; template and working rack unchanged.
- Cleanup (user, 2026-10-14): `Phase0_CleanupTemplateTest.luau` SUCCESS;
  `Phase0_VerifyAfterCleanup.luau` ALL CHECKS PASSED (no TemplateTest; exactly 1
  working rack with 21 MeshParts; exactly 1 template, 21 MeshParts, no tags/StationId).
  Placeholders exist only at Play time, built by code, so cleanup could not affect them.
- `CLAUDE.md` gained the "Automation-First Workflow" section.

**Step 6D.2a, automatic rack spawning: COMPLETE. All Studio tests
user-verified; committed and pushed 2026-10-17 with user approval.**
- Final local checks (2026-10-17, watcher OFF): luau-lsp with a Rojo sourcemap,
  0 errors in all 13 6D.2a Luau files (errors only in the untouched files listed
  in section 5); `rojo build` OK, probe `ENABLED = false` in the build;
  `git diff --check` clean; no trailing whitespace in the new files.
- Behaviour change to note: the hand-placed rack's title becomes "Training Rack 01"
  (was "Training Rack 1"); placeholders stay "Training Rack A" / "B".

**PASSED (user-verified in Studio, 2026-10-14):**
- `tools/studio/Step6D2a_VerifyRacks.luau` (Play, server view): ALL CHECKS PASSED.
  One GymRack_01 spawned; 4 racks registered with unique IDs; correct MeshParts,
  position, facing, collision, StandPoint, one prompt, one sign; template unchanged.
- All 4 multiplayer occupancy tests (2-player Local Server): Player 2 blocked at
  Player 1's occupied GymRack_01; Player 2 could take it after Player 1 walked
  away; Player 1 could not hold two racks; two players trained at the same time
  at different racks (which racks was not recorded).
- GymRackWatchProbe plus its on-screen panel work in Studio. Latest screenshot:
  **60 PASS, 0 FAIL**. Reported: positive CN gains at GymRack_01, rack release
  succeeded, no late credit after release, credited time <= held time.

**What the 60 PASS total does NOT prove** (the individual lines were not shared):
- The watcher silently ignores lines it does not recognise, so missing
  `technique tick` lines would lower the count instead of failing.
- The total does not say which release reasons happened: Stop logs "stopped",
  reset logs "died", leaving logs "character removed".
- It only watches GymRack_01.
- (Reviewed, no code change: every credit path is logged and watched, and a
  rejected award shows up as a FAIL, not as silence.)

**Watcher false FAIL, 2026-10-16 (diagnosed, watcher-only fix; user-verified in Studio: 0 FAIL):**
- Symptom: 2 FAILs at a GymRack_01 technique tick (23:42:36): DepthAwareness
  logged +0.00165 but rose ~0.0031 over the watcher's remembered value;
  SquatControl logged +0.00041 but rose ~0.00125.
- Cause (confirmed by the user from the full 23:30-23:42 Server Output): the
  watcher remembered Player2's stats from 23:32:30 (SquatControl 0.0125,
  DepthAwareness 0.0031). Player2 then earned legitimate technique gains at
  PowerRack_01 and PlaceholderStationB. The watcher ignored ticks at other racks
  WITHOUT updating its remembered values, so the next GymRack_01 tick was compared
  with stale numbers. The GymRack_01 award itself was correct; later ticks passed.
- Ruled out by code trace: no duplicate award (the only technique writer is
  `ProfileOperations.applyTechniqueTraining`, called only via
  `PlayerDataService.awardTechniqueTraining` from TrainingStationService; every
  credit path (tick, switch, Stop) logs exactly once through `logCredit`), and no
  async race (the award and tick never yield; the tick has an overlap guard).
- Fix (`src/server/Dev/GymRackWatchProbe.server.luau` only; no gameplay code):
  a technique or CN tick at ANY other rack now updates the watcher's remembered
  stat / CN values. All assertions unchanged, including "credited after leaving
  GymRack_01" and the per-tick continuity checks, which now also catch an
  unlogged change made anywhere. luau-lsp 0 errors; `rojo build` OK.
- The CN continuity check had the same blind spot (per-lift CN earned at another
  rack); fixed the same way in the same change.

**Verified 2026-10-16/17 (user's real Studio Local Server, 2 players, as reported):**
- CN and technique progression at GymRack_01 (technique tick PASS lines).
- Watcher baseline fix: cross-rack training then GymRack_01 training, 0 FAIL.
- Character reset while training at GymRack_01: released (`died`), sign Free,
  no further credit, 0 FAIL.
- Player2 trained technique at `PowerRack_01` and `PlaceholderStationB` (from the
  23:30-23:42 Server Output), so the other racks still train.
- Persistence across sessions: SKIPPED by decision, not tested. 6D.2a does not
  touch saving, and Local Server test players do not survive a new session.

**Source-level checks by Claude, 2026-10-17 (no Roblox runtime involved):**
- luau-lsp with a Rojo sourcemap: 0 errors in all 13 6D.2a files. Remaining
  errors are only in untouched files (section 5).
- `rojo build` to .rbxlx, inspected read-only: no GymRacks / GymRack_*, no
  CollectionService tag and no StationId anywhere; template = 1 Model, 21
  MeshParts, 21 rbxassetid MeshIds, no StandPoint/prompt/sign. This covers what
  Rojo writes; the user's saved place still needs the Studio Edit-mode check.
- Disconnect code trace: leaving fires `CharacterRemoving` -> `endTraining`
  ("character removed"), then `PlayerRemoving` -> `endTraining` ("left the game",
  a no-op if already released); the tick's presence check also releases
  (`LeftGame`). `release` credits nothing and nothing yields, so no tick can
  credit a departed player. Expected watcher reason: `character removed`.

**Final tests, user-verified in Studio 2026-10-17 (in the real cloud place):**
- Real player disconnect while training at GymRack_01: PASSED.
- Visual appearance and walk-in collisions of GymRack_01: PASSED.
- `tools/studio/Step6D2a_VerifyEditModeClean.luau` (Edit mode): ALL CHECKS
  PASSED. No Workspace.GymRacks, no GymRack_* saved, no GymTrainingStation tags
  in Edit mode; original `Workspace.PowerRack_01` intact (21 MeshParts);
  ServerStorage rack template intact.
- No 6D.2a tests remain.

**Test tooling (Studio only, read-only, luau-lsp 0 errors):**
- `src/server/Dev/GymRackWatchProbe.server.luau`: server Script synced by Rojo.
  It only runs when `ENABLED` is true and `RunService:IsStudio()`. It listens to
  `[TrainingStationService]` Output lines (the service's VERBOSE must be true) and
  reads the GymRack_01 sign. It writes PASS/FAIL/INFO lines as StringValues into
  the runtime folder `ReplicatedStorage.GymRackWatchProbeResults` (last 150;
  Passes/Fails as attributes). It uses no RemoteEvent and clients can only read.
  `ENABLED = false` (line 45) since 2026-10-17; set it to true temporarily to re-test.
- `src/client/Dev/GymRackWatchDisplay.luau`: started from the Dev section of
  `src/client/init.client.luau`. Studio only; top-right panel; F8 toggles it; it
  shows nothing if the probe is off.
- `tools/studio/Step6D2a_CheckWatchSync.luau`: Edit-mode check that Studio has
  the up-to-date probe copy. It was written for an earlier stale-sync problem,
  which is now resolved because the panel works.
- The earlier `tools/studio/Step6D2a_WatchTraining.luau` was deleted, never
  committed. The Command Bar could not reach Server context in a 2-client test.
- Optional extra: `src/server/Dev/TrainingStationProbe.server.luau` (off by
  default) tests the reward/stop/release/no-double-credit rules with synthetic
  players. Re-running it needs a temporary `ENABLED = true`: offered, not done.
- Data isolation: use a Local Server test (Player1/Player2, negative test
  UserIds), not Play Solo, so the user's real account data is untouched.

**Step 6D.2b: remove the hand-placed rack dependency (Option B approved 2026-10-17).
COMPLETE: passed in Studio, cloud place saved, committed and pushed 2026-10-17.**
Phase B1 implemented 2026-10-17:
- `TrainingStationConfig.GymRacks` gains `GymRack_02` at (-1.3, 0, 12), facing 0.
  Read from `PlaceBackup_ServerSnapshot_20261016.rbxl` (read-only binary decode,
  validated against the template's .rbxmx): all 21 parts of the hand-placed rack
  have exactly the template's CFrames and sizes (0 studs, 0 rotation difference),
  unrotated, all anchored. Template floor centre vs config: 1e-6 studs.
- `src/server/init.server.luau`: PowerRackSetup require and call removed.
- `src/server/Training/PowerRackSetup.luau`: deleted (recoverable from `9f4fdb0`).
- `RackSpawner.luau`, `RackConfigurator.luau`: comments only.
- `tools/studio/Step6D2a_VerifyRacks.luau`: expects exactly the gym racks +
  placeholders registered, PowerRack_01 NOT registered, and the hand-placed
  rack (if still present) inert.
- `tools/studio/Step6D2a_VerifyEditModeClean.luau`: expects NO
  Workspace.PowerRack_01 and exactly 1 intact template.
- New `tools/studio/Step6D2b_RemoveHandPlacedRack.luau` (NOT run): guarded,
  undoable removal; refuses unless Edit mode, PlaceId 96814269062063, exactly
  one untagged 21-MeshPart Workspace.PowerRack_01 whose every part matches the
  template's position, and the template is present. Never saves.
- Source checks: luau-lsp 0 errors in changed files; `rojo build` OK, no
  PowerRackSetup in the build, both GymRack entries present, template 21
  MeshParts; `git diff --check` clean. No progression, rules, placeholder,
  player-data, template or Rojo-mapping change.

**6D.2b Studio results (user-verified 2026-10-17, real cloud place):**
- `GymRack_01` and `GymRack_02` both spawned correctly.
- `Step6D2a_VerifyRacks` (updated for 6D.2b): ALL CHECKS PASSED.
- Technique training at `GymRack_02` worked.
- The hand-placed `Workspace.PowerRack_01` was removed with the approved,
  guarded `Step6D2b_RemoveHandPlacedRack` script.
- `Step6D2a_VerifyEditModeClean` (updated): ALL CHECKS PASSED; template intact
  with 21 MeshParts.
- Studio confirmed: "Saved new changes in "Powerlifting: Road to Elite" to Roblox".
- Rollback for the model if ever needed: Studio place Version History, or copy
  it from `PlaceBackup_ServerSnapshot_20261016.rbxl`. Code: `PowerRackSetup.luau`
  is in `9f4fdb0`.
- Final source checks (2026-10-17, no code changes after the Studio tests):
  luau-lsp with sourcemap 0 errors in all 8 6D.2b Luau files (errors only in
  the untouched files of section 5); `rojo build` OK, no PowerRackSetup in the
  build, template 1 Model / 21 MeshParts, watcher still ENABLED = false;
  `git diff --check` clean; no progression, player-data, training-rules,
  placeholder, template or Rojo-mapping file changed.

**Step 6D.2c: retire the placeholder stations (approved 2026-10-17). COMPLETE:
passed in Studio (user, 2026-10-17), committed and pushed 2026-10-17.**
- Approved decisions: retire `PlaceholderStationA`/`B`; add `GymRack_03` at
  (-14, 0, -18) and `GymRack_04` at (14, 0, -18), facing 0 (the placeholders'
  spots); keep `GymRack_01`/`02`; no sign-height change; positions stay
  configurable (no approved layout); document the retirement in GAME_DESIGN.
- Changes: `TrainingStationConfig` (2 GymRacks lines added, PlaceholderStations
  list removed, "positions are provisional" note); `PlaceholderStations.luau`
  deleted (recoverable from `e4e5f53`); `TrainingStationService` (require +
  build call removed, comment); `RackSpawner` (placeholder-ID reservation
  removed, comments); `Step6D2a_VerifyRacks` (expects exactly 4 gym racks, no
  TrainingStations folder, no PlaceholderStation* instance or ID, no
  PlaceholderStations config list); GAME_DESIGN §34.12 decision 12 marked
  [RETIRED] 6D.2c, implementation note updated.
- Not changed: progression, player data, training rules, registration, menu,
  ticks, the template, the Rojo mapping, `GymRack_01`/`02`. Two harmless text
  mentions remain: `TrainingStationProbe.server.luau:387` (the made-up ID
  "PlaceholderStationZ" in an unknown-station test) and a comment example in
  `TrainingStationRules.luau:918`.
- Source checks by Claude (2026-10-17): luau-lsp 0 errors in the changed and
  dependent files; `rojo build` OK; built place has no PlaceholderStations
  module, 4 GymRack entries, no PlaceholderStations in config or service,
  template 1 Model / 21 MeshParts; `git diff --check` clean.
- Footprint math (template is 6.06 x 6.54, footprint X -3.03..3.03, Z -3.34..3.20
  around its floor centre; facing 0): no overlaps. Closest racks: 01-03 and
  01-04, 9.64 studs apart (centres 18.44; prompt reach 8, so prompts never
  overlap). SpawnLocation (16 Oct snapshot): centre (0, 0.5, -6), 12 x 12,
  i.e. X -6..6, Z -12..0; nearest racks 03/04 about 5.7 studs away, 02 8.7,
  01 14.8. All inside the Baseplate.
- Studio results (user-verified 2026-10-17, real cloud place, Local Server):
  `Step6D2a_VerifyRacks` ALL CHECKS PASSED; four automatically spawned racks
  present; hold-E interaction and training progression work at `GymRack_03`
  and `GymRack_04`; placeholder platforms gone; all racks upright and
  separated, no obvious collisions or overlaps; training signs work (visual
  design to be improved later, not in 6D.2c).

**Must stay untouched:** the rack template, the place
backups, the unexplained `PowerRack_01.blend` change (investigate separately), and
the unrelated Git changes in section 4.

Approved design, as implemented:
- Config: `TrainingStationConfig.GymRacks` list, first entry `GymRack_01`,
  template `PowerRack_01`, floor-centre position (0, 0, -30), facing 0 degrees
  (0 = J-cups face +Z; 90 = +X). Entries are checked by RackSpawner, NOT by
  config asserts, so a bad entry skips that rack with a warning instead of
  stopping the training system (user requirement).
- New `src/server/Training/RackConfigurator.luau`: prepares a clone (21-part
  check, anchor, posts-only collision, StandPoint as PrimaryPart, pivot check).
  No tag. It COPIES the logic; `PowerRackSetup` stays unchanged until 6D.2b.
- New `src/server/Training/RackSpawner.luau`: per entry: ID `GymRack_NN`, not
  repeated, not already used by a tagged rack or a placeholder; template is
  exactly one Model with exactly 21 MeshParts, untagged, no StationId; clone;
  configure while unparented; PivotTo position + facing (checked); StationId;
  parent to runtime `Workspace.GymRacks`; tag LAST. Each rack runs in a pcall
  and any half-built clone is destroyed. spawnAll() runs once (repeat calls
  ignored); an existing rack of the same name in GymRacks is skipped.
- `src/server/init.server.luau`: one call after `PowerRackSetup.configure()`,
  before the services start.
- Rack titles: new pure `TrainingStationRules.rackTitle(stationId)` shows the
  full trailing number (`GymRack_01` -> "Training Rack 01"); IDs without digits
  keep the last character ("Training Rack A"). Used by `TrainingStationService`
  (sign) and `TrainingMenuController` (menu): one line changed in each.
- Unchanged in 6D.2a: working rack, PowerRackSetup, placeholders, progression,
  training rules, Rojo mapping.
- 6D.2b (done 2026-10-17): `Workspace.PowerRack_01` removed from the cloud place
  and replaced by `GymRack_02`; `PowerRackSetup` removed.
- Open item: the sign sits at +7 studs, slightly low.
