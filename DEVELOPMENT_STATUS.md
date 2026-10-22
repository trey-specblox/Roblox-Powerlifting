# Development Status

Short handoff between Claude Code sessions. Read this first, then verify it
against `git status` / `git log` before acting. Last updated: 2026-10-19
(Starter Gym milestone: floor plan Option B approved; 30-rack stress test
passed in Studio after a J-cup fix; committed and pushed).

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
  NEXT ACTION: the next Starter Gym step, not started: reception desk and
  gym-name wall, then lighting (the inside is dark: Lighting.Ambient black).
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
