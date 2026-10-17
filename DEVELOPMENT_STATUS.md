# Development Status

Short handoff between Claude Code sessions. Read this first, then verify it
against `git status` / `git log` before acting. Last updated: 2026-10-17
(Step 6D.2b completed and committed).

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

1. Read `CLAUDE.md`, then this file. Check `git status` against section 4:
   only the deliberately uncommitted files listed there should remain.
2. Step 6D.2c: start ONLY when the user asks.

**Studio place:** the game is the CLOUD place `96814269062063` (universe
`10769034794`), not a local file. Always open it from Studio's Recent /
My Experiences or Creator Hub "Edit in Studio". On 2026-10-17 a restart opened
Roblox's blank Baseplate template (`95206881`) instead; Rojo synced the scripts
and template into it, so only the hand-placed objects looked "missing". Check
with `print(game.PlaceId)` before working or saving.

## 1. Latest Verified Commit

- (2026-10-17) Replace the hand-placed power rack with a spawned rack (Step 6D.2b).
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
Roblox: height +Y, J-cup (front) side +Z. Parts: `Upright_*` x4, `Crossbar_*` x4,
`BaseRail_Left/Right/Back`, `JCup_*`, `JCupLiner_*`, `JCupPin_*`, `SafetyBar_*`,
`SafetyPins`, `FrameBolts`. One material per part. J-cup/safety heights provisional.

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
gameplay scripts. Rack design: `GAME_DESIGN.md` section 34; layout: section 27.

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

## 5. Current Limitations

- Every modeled rack now exists only at runtime, from the template. Spawned racks need `ServerStorage.RackTemplates` in the running place. In
  Studio, Rojo provides it. A PUBLISHED game only has it if the place was
  saved/published while Rojo had synced it; otherwise RackSpawner skips every
  gym rack with a warning (the game still runs).
- The placeholder racks (`PlaceholderStations.luau`) are still live alongside it.
- Rack materials/colours in Studio have not been tuned. No barbell, plates or gym yet.
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

**Must stay untouched:** the placeholder racks, the rack template, the place
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
