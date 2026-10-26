# Development Status

Short handoff between Claude Code sessions. Read this first, then verify it
against `git status` / `git log` before acting. Last updated: 2026-10-26
(Starter Gym step 6: Showers, Recovery and Massage remade with the kits; new
layout decision: closed rooms with doors and an upstairs spa wing; newest
entries at the end of the CURRENT MILESTONE block).

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
  NEXT ACTION: build the new layout in StarterGymBuilder, in steps: (1) closed
  rooms: generalise PrivateRooms (front block ground floor only today) to
  every block and both floors, with a door for every closed room; (2) the spa
  wing in the left upper block with internal walls and doors, the Sauna moved
  there, Recovery and Massage moved up; (3) settle the [TBD]s in GAME_DESIGN
  with the user first (what fills the freed rooms, where the six side rooms
  go). Then continue the room batches (Index, Office, Storage, ...).
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
