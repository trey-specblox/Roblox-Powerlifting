# Development Status

Short handoff between Claude Code sessions. Read this first, then verify it
against `git status` / `git log` before acting. Last updated: 2026-10-14.

## 1. Latest Verified Commit

- Step 6B/6C art and docs: "Add verified Blender power rack assets and development
  docs" (hash: see `git log -1`; recorded here after the commit).
- Latest gameplay code commit: `5999fa1` Add unlimited gym technique stat
  progression (Step 5B.7). No gameplay code has changed since.

## 2. Completed Checkpoints

- **Step 5** (gym training system), up to and including 5B.7. Committed.
- **Step 6A**: Blender MCP integration verified (Claude can drive the live Blender).
- **Step 6B PASSED**: Blender-to-Roblox scale calibration. User-verified in Studio:
  `ScaleTest_2StudCube_v2.fbx` imported at 2 x 2 x 2 studs with no resizing.
- **Step 6C PASSED**: `PowerRack_01` modeled, exported and imported into Studio.
  User confirmed: dimensions correct, rack upright, main components visible.

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

**PowerRack_01:**
- Source: `art/blender/PowerRack_01.blend` (collection `PowerRack_01`)
- Export: `art/exports/PowerRack_01.fbx` (21 meshes, rack parts only)
- Build script: `art/scripts/build_power_rack_01.py`. It builds the parts into the
  open scene. It does not clear the scene, save or export.
- Size 6.06 W x 6.54 D x 8.0 H studs; fits the 8 x 8 placeholder platform.
- Blender: Z-up, origin (0,0,0) = footprint centre at floor level, front (J-cup
  side) faces -Y, "Left" = -X. Each part's origin is its own bounds centre;
  rotation 0, scale 1. In the FBX/Roblox: height is +Y, the J-cup side is +Z.
- Parts: `Upright_*` x4 (14 recessed holes per front/back face), `Crossbar_*` x4,
  `BaseRail_Left/Right/Back` (front open), `JCup_*`, `JCupLiner_*`, `JCupPin_*`,
  `SafetyBar_*`, `SafetyPins`, `FrameBolts`.
- Materials (one per part): `Steel_BlackPainted`, `Rubber_Black`, `Steel_Hardware`.
- 1,904 vertices, 3,620 triangles.
- J-cup height (z 4.3) and safety height (z 2.7) are provisional visuals.

**Design rules:**
- 1 Blender unit = 1 Roblox stud. Model at real stud size with scale 1 and
  transforms applied. Never "fix" scale by resizing models.
- One material per Blender object (one material per Roblox MeshPart).
- Name every object/file specifically (e.g. `Barbell`, never `Cube.001`).
- Art: `art/blender/` (.blend), `art/exports/` (.fbx), `art/scripts/` (build scripts).
- Art work must not edit gameplay scripts.
- The rack belongs to the universal gym rack training station (Step 5B,
  `96b16b7`). Design: `GAME_DESIGN.md` section 34; Starter Gym layout: section 27.

## 4. Uncommitted Work

Committed in the Step 6 commit (section 1): `ScaleTest.blend`, `PowerRack_01.blend`,
`ScaleTest_2StudCube_v2.fbx`, `PowerRack_01.fbx`, `build_power_rack_01.py`,
`DEVELOPMENT_STATUS.md`, and the approved `CLAUDE.md` / `GAME_DESIGN.md` updates.

Deliberately left uncommitted (keep, never discard):
- `art/exports/ScaleTest_2StudCube.fbx`: v1, the failed 200-stud test. Local reference only.
- `art/blender/PowerRack_01.blend1`: Blender's automatic backup. Ignored by the
  local `.gitignore` rule `*.blend1`, which is itself not committed yet.
- If `DEVELOPMENT_STATUS.md` shows as modified right after the Step 6 commit, the
  only change is the commit hash recorded in section 1.

Tooling (not gameplay, not committed):
- `.gitignore` adds `ClaudeLogs/` and `*.blend1`; `.claude/hooks/Export-ClaudeLog.ps1`
  and `.claude/settings.json` (untracked) write those logs. Do not stage the
  `.claude/` logging setup with Step 6 unless the user asks.

`References/DBD.md` shows as modified but has no content change (line endings).
Do not edit it as part of Step 6.

## 5. Current Limitations

- The imported rack is not anchored, not placed in the game world, not tagged as a
  training station, and not connected to any script.
- The placeholder racks (`src/server/Training/PlaceholderStations.luau`, config in
  `TrainingStationConfig.PlaceholderStations`) are still the live stations.
- Rack materials/colours in Studio have not been tuned.
- No barbell, plates or gym environment yet.

## 6. Current Checkpoint: Step 6D (functional rack integration)

**Status: read-only audit DONE and the plan APPROVED by the user (2026-10-14).
Nothing implemented yet: no code or Studio changes.**

Audit findings (code at `5999fa1`):
- Racks register via tag `GymTrainingStation` + string attribute `StationId`, on
  a Part or Model, anywhere in the DataModel (also ServerStorage). Duplicate IDs
  are ignored with a warning. Tag removal/destroy unregisters; the occupant is
  released on the next tick with no credit.
- Model racks: presence is measured from `Model:GetPivot()` (radius 12). The
  prompt and status sign go on `PrimaryPart` (fallback: the first BasePart
  found). Prompt at +3 studs, sign at +7 studs, prompt reach 8, no line of sight.
- So `StandPoint` must be the PrimaryPart with PivotOffset 0, or the presence point and
  prompt land in the wrong place. No code change is needed for one rack.
- The rack title shows only the LAST character of StationId ("Training Rack 1").
- The Studio place is not in the repo (`/Powerlifting Roblox.rbxlx` is gitignored
  and absent), so a hand-placed rack lives only in the cloud place.

Proposed plan: 6D.1 = configure one rack by hand in Studio (zero code), test.
6D.2 (later, needs approval) = Git-tracked template + config-driven spawner.

Next action: start 6D.1. Guide the user through the manual Studio setup
(StandPoint as PrimaryPart, tag, StationId `PowerRack_01`, collision: posts only,
position (0, 0, -18)), then run the 6D.1 Studio test checklist.
