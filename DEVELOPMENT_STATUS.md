# Development Status

Short handoff between Claude Code sessions. Read this first, then verify it
against `git status` / `git log` before acting. Last updated: 2026-10-14.

## 1. Latest Verified Commit

- `PHASE0_COMMIT` Add Git-tracked power rack template synced by Rojo (Step 6D.2 Phase 0).
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
`PrimaryPart`. The rack title shows only the LAST character of StationId.

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
- `art/exports/ScaleTest_2StudCube.fbx`: v1, the failed 200-stud test. Local reference only.
- `art/blender/PowerRack_01.blend1`: Blender's automatic backup, ignored by the
  local `.gitignore` rule `*.blend1`.
- `.gitignore` (adds `ClaudeLogs/` and `*.blend1`), `.claude/hooks/Export-ClaudeLog.ps1`
  and `.claude/settings.json`: the conversation-log tooling. Not staged unless the user asks.
- `References/DBD.md`: line endings only, no content change. Do not edit.
- If `DEVELOPMENT_STATUS.md` shows as modified right after the Phase 0 commit,
  the only change is the commit hash recorded in section 1.

## 5. Current Limitations

- The WORKING rack is still the hand-imported `Workspace.PowerRack_01` (only in
  the user's saved place), configured by the temporary `PowerRackSetup`. The
  Git-tracked template exists but nothing spawns racks from it yet (6D.2a).
- The placeholder racks (`PlaceholderStations.luau`) are still live alongside it.
- Rack materials/colours in Studio have not been tuned. No barbell, plates or gym yet.
- Pre-existing luau-lsp type errors in untouched files: LiftAttemptService,
  PlayerDataService:318, LiftAttemptConfig, LiftingRemotes, CompetitionNumberReward.

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

**NOT yet verified at the modeled rack (regression cases still open):**
- CN training raising Competition Number, and Technique training raising the
  chosen stats (both proven at the placeholders in 5B, not re-run here).
- One player trying to use two racks ("already using another rack").
- Release by reset/death and by leaving the game (walk-away is verified).
- No double credit (one tick line per player per ~10 s).
- Placeholder racks still working alongside the modeled rack.
- A fresh Play session re-running the setup with one prompt and one sign.
- Collision feel (walk in through the open front, posts solid, no snagging).

**6D.2 Phase 0: PASSED and committed** (`PHASE0_COMMIT`). Reusable rack template.
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

**CURRENT CHECKPOINT: Step 6D.2a, automatic rack spawning. APPROVED
architecture (2026-10-14); NOT implemented.**
- Config: `TrainingStationConfig.GymRacks` list, first entry `GymRack_01`,
  template `PowerRack_01`, floor-centre position (0, 0, -30), facing 0 degrees.
  Startup integrity checks (unique `GymRack_NN` IDs, finite numbers, template name).
- New `src/server/Training/RackConfigurator.luau`: prepares a clone (21-part
  check, anchor, posts-only collision, StandPoint as PrimaryPart, pivot check).
  No tag. It COPIES the logic; `PowerRackSetup` stays unchanged until 6D.2b.
- New `src/server/Training/RackSpawner.luau`: per entry: template exists and is
  untagged with no StationId; clone; configure; PivotTo position + facing;
  StationId; parent to runtime `Workspace.GymRacks`; tag LAST. Fails closed per
  rack; duplicate IDs skipped.
- `src/server/init.server.luau`: one call after `PowerRackSetup.configure()`,
  before the services start.
- Rack titles (APPROVED for 6D.2a): show the full trailing number
  (`GymRack_01` -> "Training Rack 01"); IDs without digits keep the last character
  ("Training Rack A"). One line each in `TrainingStationService.luau` and
  `TrainingMenuController.luau`.
- Unchanged in 6D.2a: working rack, PowerRackSetup, placeholders, progression,
  training rules, Rojo mapping.
- 6D.2b (later): user deletes `Workspace.PowerRack_01`; `PowerRackSetup` removed.
- Open item: the sign sits at +7 studs, slightly low.
