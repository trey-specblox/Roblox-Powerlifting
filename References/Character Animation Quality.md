# Character Animation Quality

The quality bar for lifter animations, rigging and equipment contact, and how every animation is checked before the
user sees it. Started 2026-11-13 from the user's review of the torso-rig pose pictures
(`art/previews/TorsoAnim_*.png`) and the brief "CRITICAL: character animation, rigging & equipment interaction quality
corrections".

**FIRST: read §5.0, the user's standing rules (hands open for claps and slaps, the lifter unracks and racks every bar,
fails turn and walk off yelling, no joint flips, elbows never backward, nothing through the body), before ANY animation
or lift work, and check the game's own systems against them, not only the Blender pictures.**

Status words: **VERIFIED** = measured in this project. **UNVERIFIED** = a likely cause nobody has inspected yet.
**APPROVED** = the user said yes. Nothing here is approved yet unless it says so.

Related: [[CHARACTER_ART_DIRECTION]] (bodies, skeleton tables, §11 production plan), [[GAME_DESIGN]] (lift
mechanics), `References/Clip Study/` (real meet videos: setups, rituals, mechanics).

---

## 1. What the user flagged (2026-11-13)

The screenshots were taken on the user's computer and are **not in the project yet**. Put them in
`References/Character Animation Quality/screenshots/` (names like `01_deadlift_grip_side.png`) and this list can
link them. They appear to be crops of the Phase 1 pose sheets (`art/previews/TorsoAnim_Stations.png`,
`TorsoAnim_Entrances.png`, `TorsoAnim_Emotes_Chalk_Shirt.png`), which show the same moments.

| # | What | Animation(s) | What is wrong |
|---|---|---|---|
| 1 | Deadlift grip, side | Station_Deadlift 1.6, Setup_Deadlift 3.3 | "chicken wing" arms: cramped, bent-looking, not hanging from the shoulders to the bar |
| 2 | Squat, from behind | Station_Squat, Setup_Squat | arms go into the body; worse on some builds |
| 3 | Deadlift set-up, front | Setup_Deadlift 3.3 | arms look like they pass through the chest and neck |
| 4 | Squat duck-under | Setup_Squat ~1.76 | arms through the body while getting under the bar |
| 5 | Squat bar on the back | Station_Squat, Setup_Squat | bar not supported: floats or sinks into the upper back |
| 6 | Hips and glutes | standing / squat / deadlift | buttocks stick out; looks like leaning back |
| 7 | Bar into the back | Station_Squat | bar cuts into the back (Phase 1 measured 0.08-0.15 deep) |
| 8 | Deadlift set-up, hips | Setup_Deadlift | hips pushed far back, sitting into the bar instead of hinging |
| 9 | Hands/arms through the body | Entrance_Hype_ChestSlap, Entrance_Hype_NeckRoll, Entrance_Hype_WarCrouch, Emote_TrapSlap, Chalk_Coach_Talk, Chalk_Lifter | hands vanish into the torso; odd hips and arm angles |

---

## 2. Root causes

### 2.1 VERIFIED: the torso skeleton's arms are too short for its torso (deadlift and every low reach)
The approved torso table (`art/scripts/lifter_heights.py`, 2026-11-13) has legs x1.0 (hips 2.0), torso x1.35
(shoulder joint 4.38) and arms x1.2. Measured:
- Standing, the hands hang at **2.47 studs, ABOVE the hip joint (2.0)**. On a person the wrists hang at about hip
  level. (The block rig: 2.17.)
- To grip the floor bar (centre 1.0 up) the shoulder must come down to about 2.9. With a 2.38-long torso and 1.75-long
  legs there is **no pose** with upright shins, hips above the knees and the shoulders just over the bar. The
  original deadlift solver found the only way left: **the shins lean BACKWARD** (knees 0.49 behind the ankles), the
  hips sit 1.23 behind the feet, and the bar sits 0.48 ahead of the midfoot. That is screenshots 1, 3, 6 and 8.
- Proportion test (`art/scripts/station_animations.py` deadlift solver with `LIFTER_ARM` / `LIFTER_TORSO`, scratch):

| arms | torso | best set-up the solver finds |
|---|---|---|
| x1.2 (today) | x1.35 | shins upright needs the shoulders **1.05** past the bar, arms slanted 30 degrees: a frog crouch |
| x1.45 | x1.35 | shoulders 0.9 past the bar: still poor |
| **x1.5** | x1.35 | knees 0.32 ahead, hips 0.30 above the knees, back 36 degrees, **shoulders 0.34 past the bar, arms 8 degrees**: real technique |
| x1.55 | x1.35 | shoulders 0.5 / 0.19 past, back 32-40 degrees: real technique |
| x1.2 | x1.15 | shoulders 0.27 past, back 42 degrees: real technique (shorter torso instead of longer arms) |

The same shortness explains earlier work-arounds: belt, hip and chest hand targets had to be raised (`within_arm`)
because the arms could not reach them, and Hype_CrowdLift's solver struggled.

### 2.2 VERIFIED: the deadlift solver only knew "hands on the bar, hips above the knees"
`_solve_deadlift_bottom` (block-rig era) had no rule for the shins, the bar over the midfoot or the shoulders over the
bar, so on a new skeleton it drifted into the backward-shin pose without complaint. Fixed in code (2026-11-13, torso
rig only): see §4.

### 2.3 VERIFIED: one skeleton width in the animations, six different shoulder widths in the bodies
The animations were written for one rig (shoulder joints at x +-1.0, the arm hanging at +-1.5). The production bodies
(`CartoonBodies_05_Rigged.blend`) have their own shoulder joints and arm lines:

| build | shoulder joint x | arm hangs at x |
|---|---|---|
| Skinny | 0.80 | 0.99 |
| Skinny-fat | 0.86 | 1.09 |
| Fit | 0.92 | 1.24 |
| Fat | 1.00 | 1.38 |
| Muscular | 1.00 | 1.48 |
| Big and buff | 1.05 | 1.61 |

An animation only turns joints, so the same keys put each build's hands in a different place: up to 0.6 studs apart
between Skinny and Big and buff. Every hand target on the body (chest slap, trap slap, belt, chalk, coach talk) and the
squat grip is right on at most one or two builds and inside the body or short of it on the others. This is the main
systemic cause of screenshots 2, 4 and 9. Roblox works the same way (Motor6D offsets come from each body), so it has to
be solved per build in the game (§3.3).

### 2.4 VERIFIED: shared bar contact, different body depths
- Squat bar on the back: one bar height and depth for every build, but back and trap thickness differ: 0.08-0.15
  into the upper back (Phase 1, prototype bodies). Re-measure on CartoonBodies_05.
- Deadlift lockout: the bar path is shared, and on the Fat body it passes **0.31-0.40 into the belly** (before and
  after the fix); with arms x1.5 only 0.07 deep.

### 2.5 UNVERIFIED (not inspected yet)
- Skin weights at the elbows and shoulders (part of the "chicken wing" look may be the deltoid/shoulder skin, not the
  joint angles; the joints are straight in the deadlift).
- Pelvis and glute geometry when standing (screenshot 6 outside the deadlift): Phase 2 body shapes, not animation.
- The 578 degrees/second "pop" at 0.25-0.85 s in Setup_Deadlift (all versions): probably the feet turning out during
  the foot-setting steps; look at it in motion.
- `arm_in_body` 0.59-0.60 on the Fat and Skinny bodies at some moments: the number sits exactly at the test's reach
  limit, so it may be a measuring quirk (a hand beside a thigh). Check visually before acting on it.

---

## 3. Standards (what "right" means)

### 3.1 Lifting technique (stylised bodies, real mechanics)
**Deadlift set-up (conventional):** bar over the midfoot, touching or just in front of the shins; shins upright or
angled slightly forward (knees just ahead of the bar); hips above the knees and below the shoulders; back flat,
roughly 30-50 degrees from vertical on these bodies; shoulders slightly in front of the bar (about 0.1-0.35 studs);
arms straight and close to vertical (within about 10 degrees); the bar never moves before the grip.
**Deadlift pull:** the bar travels straight up over the midfoot, along the shins and thighs; lockout with knees and
hips straight, shoulders over or just behind the hips, arms straight, the bar against the thighs (not inside them).
**Squat:** bar across the upper back on the traps/rear delts (high or low bar, chosen once and kept), resting ON the
surface (contact, not separation, not sinking more than a cloth's thickness); hands just outside the shoulders,
wrists straight, elbows under/behind the bar; the duck-under is approach, back under the bar, hands set, bar seated,
brace, then unrack.
**Bench:** existing standard (StationAnimationConfig); same contact rules for the bar and the hands.

### 3.2 Contact
- Intended contact is required: a chest slap touches the chest, a trap slap the trap, a belt grab the belt.
- Not allowed: a hand or forearm disappearing into the torso, head or legs; an upper arm through the neck; the bar
  inside the body (more than about 0.05 studs); hands floating beside the bar while "gripping".
- Grips show the Fist swap (HandShapeConfig.Grip) wrapped round the bar; celebrations use the gesture's own shape.

### 3.3 Different bodies
- One animation per move stays the source (gameplay triggers and timing unchanged).
- Per-build corrections are allowed and expected: **in the game, an IKControl per hand** (Roblox's built-in
  inverse-kinematics instance; the game already uses IKControl in `SuitCutscene.luau` and `CardioMachineAnimator.luau`)
  pins the hands onto the bar's grip points and onto body-contact targets measured per build, so a Skinny and a Big and
  buff lifter grip the same bar at the same width without the arms going through the body. Plus a per-build bar offset
  for the squat (back depth) and the deadlift path (belly/thigh depth).
- Body size and posture are separate: a heavier body never gets a different (leaning) posture from the animation.

---

## 4. Corrections

### 4.1 Done (2026-11-13; the user's look on the rebuilt bodies is still to come)
- **Deadlift set-up solver** (`station_animations.py`, torso rig only; block and taller rebuild byte-identical):
  hands on the bar with straight arms, the bar against the shins (thickest shin + bar radius) and at most 0.25 ahead
  of the midfoot, hips above the knees, shoulders as close over the bar as the arms allow. `deadlift_forward()` (0.23)
  moves the lifter that much closer to the bar than the root part, with no game change; the set-up's two
  foot-setting steps carry it, so no sliding. The arms reach for the bar on the way down. Used by Setup_Deadlift,
  Station_Deadlift and the 8 deadlift fails (re-made; the other 74 files did not change).
- **Mixed grip, fingers round the bar** (user 2026-11-13: "make sure one hand is facing forward other is back ...
  the fingers are actually wrapped around grabbing it"): a quarter turn of each wrist turns the LEFT palm forward
  (under-hand, thumb out) and the RIGHT palm back (over-hand, thumb in), turning in as the hands reach and untwisting
  as they let go (setup, rep, the 8 deadlift fails). The bar is aimed into the new **Grip** hand swap's hole
  (Phase 2 session, `build_cartoon_hands_04.py`, `<Build>_Grip<Side>` in SwapHands05: four fingers wrapped round
  the bar, the thumb closing over them), not at the hand's centre (`station_animations.GRIP_POINT`, Fit's hand size);
  each arm gets its own swing (about 10 degrees apart). Close-ups: `art/previews/DeadliftQA_Grip_Closeups.png`.
- **Result on the rebuilt bodies (anim_qa, all three builds identical):** set position: shins upright against the
  bar, bar 0.25 ahead of the midfoot, hips 0.44 above the knees, back 31 degrees, arms straight and near vertical
  (left 9 degrees back, right 1), shoulders 0.20 over the bar, nothing through the body, no foot below the floor or
  sliding. Lockout: hands at mid-thigh. A version without the midfoot rule (shins forward, bar over the toes 0.52
  ahead) read as a squat in the side view and was dropped; hips are capped at 0.45 above the knees (higher read as a
  stiff-legged pull).
- **Still wrong (per-build, §2.3-2.4):** at lockout the bar is 0.11 into the Fat belly, 0.07 into the Muscular thighs
  (one shared bar path); the grip hole sits at Fit's hand size, so Skinny's hole is snug and Big and buff's roomy.
  Phase 4: per-build hand IK / bar path, and the client must draw the held bar at the GRIP points (an attachment in
  the Grip swap), not at the hands' midpoint as `StationPoseAnimator.followHands` does now (that would put the bar
  about 0.3 above the fingers); `HandShapeConfig.Grip` = "Grip" once uploaded.
- **Arms x1.5** in `lifter_heights.py` (elbow 3.287, wrist 2.148) and **all 84 animations re-made** for it into
  `art/animations` (keyframe times identical to the committed set, AuthoredHipHeight 2). The `within_arm` raise is now
  off by itself (arms longer than the torso). Hand misses vs arms x1.2: most moves the same or better (Setup_Bench
  0.30 -> 0.13, SitBreath 0.22 -> 0.12, LeapAndBow 2.67 -> 2.24); worse: TrapSlap 0.16 -> 0.24, Hype_NeckRoll
  0.13 -> 0.21, Hype_CrowdLift 0.15 -> 0.21, ChalkClapPump 0.11 -> 0.19. Not yet corrected one by one (the user's
  order: squat set-up next, then entrances and celebrations).
- **Bodies:** the six Phase 2 bodies were rebuilt with the longer arms by the Phase 2 session (2026-11-13:
  `build_cartoon_body_05.py` overrides E 3.287 / WR 2.148; CHECK PASSED, 5,424 triangles each with hands).
- Known and older than this work: the squat fails sink a body point 0.17-0.41 under the floor (same with x1.2 arms).
- Backups: the arms x1.2 set in `D:\ClaudeScratch\backup_anims_torso_2026-11-13\`; the taller set is commit 1481684.

### 4.1b Squat (2026-11-13, APPROVED)
- **Found:** the squat arms were the block rig's fixed angles (SQUAT_ARM, approved 2026-10-19) on the x1.5 arms: the
  hands, and so the bar the game draws between them, sat high near the neck with the elbows flared; the bar was
  0.09-0.12 into the back standing and 0.19-0.25 at the unrack; in the setup the hands aimed their centres (not the
  fingers) at the bar, so the grip hole floated above it, open hands, 0.6 into the body in the duck-under.
- **Fixed (code, torso rig only):** the bar is now PLACED (on the middle build's back, at shoulder-blade height, below
  the neck: `station_animations.SQUAT_BAR_REST`) and both hands LOCK onto it (`lock_hand`: Grip hole on the bar, palm
  forward, fingers over the bar, thumbs in; the arm solved so the elbows sit under and behind it; the wrist turns to
  match). The setup locks the hands onto the J-cup bar at 1.2 s and keeps the same turn through the duck (the bar
  doesn't turn), then rides the back. The squat fails start from the same hold and ease the hands off when they let
  go. Only the 10 squat files changed; timing identical; the taller set is still the committed one (Setup_Squat
  within 0.000002).
- **Per-body hands (shown in the pictures' third row; the data for the game's per-build IK, Phase 4):** each body's
  bar sits on ITS OWN back, measured with the arms up (raised arms bunch the delts and traps past the rest depth):

  | body | back depth (rest) | + posed bunching | bar centre behind the spine | grip (each hand from the centre) |
  |---|---|---|---|---|
  | Skinny | 0.39 | 0.04 | 0.51 | 1.55 |
  | Skinny-fat | 0.44 | 0.00 | 0.52 | 1.66 |
  | Fit (the shared animation) | 0.56 | 0.00 | 0.64 | 1.87 (animation: 1.95) |
  | Fat | 0.58 | 0.19 | 0.85 | 2.05 |
  | Muscular | 0.62 | 0.23 | 0.93 | 2.17 |
  | Big and buff | 0.72 | 0.28 | 1.08 | 2.35 |

  (bar centre = back + bar radius 0.07 + 0.01 + bunching; grip = outer delt + 0.32.) With these, the bar sinks into
  none of the six bodies through the whole squat (anim_qa). In the setup the body stands that much closer to/further
  from the J-cups so its back meets the bar.
- **Still open:** the duck-under: for about 0.15 s (1.55-1.7 s) the head and neck pass through the bar while ducking
  (0.34-0.38 deep). A clean duck needs the head fully below the bar, which with these big heads means the deep crouch
  the user rejected (2026-11-08), so the accepted trade-off stays; the real heads may change it. The arms swing fast
  there (about 850 degrees a second for a moment) as the body passes under the bar. The squat fails' old floor sink
  is still there (Dramatic_Squat_1 now 0.52, was 0.41; others unchanged 0.05-0.20).
- **Found 2026-11-14 (gear session, gear v5 wrist wraps): the squat wrists bend far too much**, so the wraps cut into
  the hand (66-114 points, up to 0.15 deep). Measured in the installed files (hand's long axis vs the forearm):
  Station_Squat and the squat fails 80 degrees for the whole bar hold, Setup_Squat up to 149 (walk-in / duck-under).
  A real wrist bends back about 70 at most; under the bar lifters keep it near straight (that is what wraps are for).
  Cause, measured (what-if search, `D:\ClaudeScratch\squat_wrist_search.py`): with the bar THROUGH the Grip hole the
  hand can only turn round the bar, so a straight wrist needs the forearm square to the bar, and then the forearm plus
  the hand to the hole (~1.5) is longer than the elbow can be from the bar (~1.32 at most with arms x1.5): no
  straight-wrist shape exists. Turning the hand so the bar crosses the palm on a slant (~40-60 degrees) gets the bend
  to 13-15 degrees, but then the bar cuts through the Grip hand's curled fingers. Real low-bar squatters use a
  thumbless grip: the bar in the HEEL of the palm, fingers over it, wrist straight. Options for the user: a squat
  hand shape with the bar at the palm heel (straight wrist), the bar on a slant through the Grip hand (fingers clip),
  or the bar a little lower on the back. Not changed yet.
  **Correction, same day:** the "no straight-wrist shape exists" above came from a search with ONE starting arm
  shape. With many starts: turning the hand round the bar (SQUAT_TURN 60, was 17: the bar rests in the palm, the
  hand under it) and keeping the straightest-wrist solve gives 27 degrees with the current Grip hand, the elbows
  DOWN (0.9 under the bar) but slightly in front of it, forearms near upright (the old "elbows back" is what forced
  80). Palm-heel bar (wrist to bar 0.10-0.15 instead of 0.415) gives 11-12 with the same elbows.
  Built (scratch `D:\ClaudeScratch\sqfinal2\out`, NOT installed, user chose "Bar in palm heel" before this):
  station hold + 8 fails 27 degrees, wraps 7-35 points in the hand (was 63-103); Setup_Squat planned by a beam search
  over arm shapes and hand roll round the bar (`Setup._squat_hand_plan`; `lock_hand` gained `bend_weight`), wrists
  under ~45 except ~0.25 s in the reach (~70) and ~0.25 s mid-duck (~95, the bar passing over the head); at the
  set-up's hardest frame the wraps still cut in (51-93 points, was 97-125). Pictures `art/previews/SquatWristQA_*`.
  **REJECTED by the user (2026-11-14, "TERRIBLE"):** (1) the grip is too wide, against the plates; real lifters
  grip a little outside the shoulders, and only the big builds (105 kg+) go near the plates; (2) the ELBOWS POINTED
  FORWARD, against the approved "elbows back and down"; (3) the set-up got worse: the elbows rose level with the
  head, and in the duck the hand faced the opposite way to the walk with the shoulders and elbows through the bar.
  The scripts were put back to the approved version (rejected copy kept in
  `D:\ClaudeScratch\backup_squatwrist_rejected`). Lesson: never trade an approved look for a better number; check
  every approved rule in the pictures. Measured afterwards (`D:\ClaudeScratch\squat_real_search.py`), with the elbows
  at or behind the bar and 0.35+ under it, the straightest possible wrist is ~64 degrees with the Grip hand and ~43
  with a palm-heel bar (grip x 1.45-1.95 barely matters). A straight wrist with the elbows back does not exist with
  arms x1.5.
- **Squat, palm-heel grip (2026-11-14, user "Yes, do the plan"; APPROVED "Yes install it", installed: the 10 squat
  files):**
  - New "SquatGrip" swap hand (`build_cartoon_hands_04.py` HEEL_C (0, -0.197, -0.19): bar in the heel of the palm,
    fingers hooked over it, thumb beside the index), 600 triangles, added to every build of
    CartoonBodies_05_Rigged.blend by `add_squat_grip_05.py` (rig script knows it too); check_models CHECK PASSED.
  - Grip narrower: Fit 1.67 (outer delt + 0.12; was 1.95). Per build (game IK): delt + 0.12, wide (+0.32) only Fat and
    Big and buff.
  - Hold: the hand's turn chosen with the arm so the elbows sit where the approved hold has them (0.72 under,
    +0.23 behind the bar; `SQUAT_ELBOW_BEHIND` 0.20): wrist 59 degrees (was 80) in the hold and all 8 fails.
  - Set-up: same approved motion; each frame also tries a start nudged toward the hold (no stuck shapes): worst wrist
    65 (was 149), fastest moment 703 deg/s (was 819).
  - Wraps (gear v5, measured with the Grip hand mesh, the palm block is the same): still 57-103 points in the hand in
    the hold: the gear session reshapes the wrap's lower edge for ~60 degrees.
  - **Wraps tilted (gear session, 2026-11-15, user approved: "Looks right"):** build_cartoon_gear_05.py measures every
    keyframe of Station_Squat, the 8 squat fails and Setup_Squat from 1.2 s with the SquatGrip hand (bench/deadlift with
    Grip) in the forearm frame and tilts the whole wrap (lower edge up on the front where the hand bends; the set-up's
    open-hand reach 0.45-1.2 s left out). Wrap points inside the hand in the hold: Skinny 0, Skinny-fat 1, Fat 3, Fit 1
    (all <= 0.009); Muscular 28 (0.046, was 74/0.165), Big and buff 26 (0.065, was 87/0.174): their hands are too big
    to clear fully. CartoonGear_05.blend rebuilt from the current bodies (carries the SquatGrip hands), CHECK PASSED;
    check_gear_05.py "wrists" mode tests wraps with the swap hands. Picture
    `art/previews/Gear05_WristWraps_SquatGrip_BeforeAfter.png`. Not committed.
  - Pictures `art/previews/SquatHeelQA_*` (before row = the old hand and animation).

### 4.1d Celebrations from the Meet Study (2026-11-14, user: "Men's top celebrations")
- **First one: MC-010 "HeadClampRoar"** (Legendary; Meet Celebration Catalogue, a -120 kg man's world-record
  deadlift), waiting for the user's look, NOT installed. 7.0 s, feet planted (every build): up out of the bend,
  double-biceps roar, arms V head back, hands clamped on the head screaming, crouched "gorilla" roar with fists low,
  arms-flared roar. Fists via the game's hand swaps (HandShapeConfig spans: both hands Fist 0.85-2.45 and 4.5-6.2 (4.35 put fists on while the hands were still on the head),
  Phase 4 code). Hand miss 0.004, no foot slide, fastest ~960 deg/s (the arm throws).
- **Authoring rules learned on it** (celebration_rig): a channel interpolates between ITS OWN keys, so every hold must
  re-state its hands, elbows and wrists or the hand keeps sliding toward the next pose (the first try's head clamp
  slid for 1.8 s); on arms x1.5 the old BICEP target is reached with a straight arm (reads as a V): a double biceps
  needs the fist placed one upper-arm out from the shoulder and ~0.95 up; hands on the head need the wrist bent
  (lw/rw ~70) or the fingers point up beside the head. Contact with the head is approximate (0.28-0.37 into the
  stand-in head at the clamp): players' real heads differ in size, so exact contact needs head IK in the game.
- **Batch 2** (user "Yes, keep going" on HeadClampRoar; waiting for the user's look, NOT installed): GorillaRoar
  (MC-020, Epic, feet planted), HammerFistRoar (MC-008, Epic), HopSkyPunch (MC-018, Epic, light/middle), FistsBesideHead
  (MC-064, Uncommon, an NPC signature), SkyPointChalkYes (MC-034, Rare, chalk burst event). Rules added: a raised arm
  is held a little OUT from the head (SKY_CLEAR; straight up the upper arm sank into the head on the big builds); fists
  in front of the body sit forward of Fat's belly; feet stay planted (a quick step to a wide stance slid the feet).
  Leftover body contact 0.1-0.27 on Fat/Muscular at some beats = per-build hand fit (game IK). MC-054 (wings) = the
  built WingspanHold; MC-017 (belt held up) needs a belt prop in the celebration system (not built).
- **Found:** two built celebrations come from MISSED lifts (the 0.25 s study): CEL-04 LeapAndBow and CEL-34
  ReliefRoar; they belong with the fail reactions (user to decide). Large hand misses on built ones were mostly a
  checker fault (celebration_rig counted blend ends with zero weight; fixed, every existing export byte-identical);
  two real floor-hand misses remain: SitAndLaugh 0.76, BowAndRise 0.81 (user to decide).
- **Batch 3** (user "Yes, keep going" on batch 2; waiting for the user's look, NOT installed; builds in
  D:\ClaudeScratch\celebH\out, pictures art/previews/CelebQA_{HunchedDance,ChalkClapRightHere,VStrutRoar,
  BackRollLegsUp}_*.png): HunchedDance (MC-022, Epic, loopable dance on a 0.5 s beat), ChalkClapRightHere (MC-004,
  Legendary, chalk burst + "right here" point), VStrutRoar (MC-011, Epic, high-V hip sway, half-squat roars),
  BackRollLegsUp (MC-013, Legendary, 8.4 s: sits back, rolls onto the back with both legs up, hands on the face,
  hands and knees, kneeling scream, claps). QA on Skinny/Fat/Muscular: hand miss <=0.002, lowest -0.02, foot slide
  <=0.16 (BackRoll sitting up at 4.1, the rest <=0.03), fastest 770-964 deg/s, arm_in_body <=0.39 (Fat, chest/belly
  beats). Rules added: lying on the back, the knees need a pole target (lk/rk) pointing up, or a knee bends toward
  the toes and flips as the legs swing over; a kneeling torso this long only reaches the floor folded like the bow
  (bow_down); a clap held at y 0.6 (chin) lifts the elbows to head height, so claps sit at chest height (y ~0.2);
  per-joint speed read straight from an rbxmx shows false ~360 deg/frame jumps (q vs -q): trust anim_qa's pop.
- **Batch 4** (user "Yes, keep going" on batch 3; the top 15 are all built except MC-017, which needs a belt prop, so
  these come from the catalogue's next wave, solo and prop-free; waiting for the user's look, NOT installed; builds in
  D:\ClaudeScratch\celebI\out, pictures art/previews/CelebQA_{OneKneeFistPumps,CrucifixTears,SkyFingerArmsCrossed,
  Gunslinger}_*.png, rendered with the game's hand swaps via QA_SHAPES): OneKneeFistPumps (MC-016, Epic, new
  `one_knee()` pose: right knee down, left shin upright), CrucifixTears (MC-021, Epic, forearm over the face, sobbing
  shoulders; ends head down, no coach), SkyFingerArmsCrossed (MC-031, Rare), Gunslinger (MC-051, Epic). Hand shapes
  (HandShapeConfig, Phase 4): OneKnee both Fist 0.3-5.0; Crucifix both Fist 0.2-0.95; SkyFinger right Point 0.3-1.7,
  both Fist 2.5-6.3; Gunslinger left Point 0.6-1.95, right Point 0.6-3.55, both Fist 3.6-4.45. QA: hand miss
  <=0.09, foot slide 0.13 only while rising off the knee, fastest 750-1035 deg/s (the fist pumps), arm_in_body <=0.32.
  Rules added: on arms x1.5 a folded-arms pose overshoots (the forearm is longer than the chest is wide; the hands
  stick out past the body), and the wrist only pitches (rx @ ry), so a hand cannot lie flat on the opposite shoulder:
  crossed arms are built as an X with fists at the opposite shoulders and the elbows low; arms that cross in front
  of the body go out in front of the belly first (Fat 0.52 -> 0.29).
- **User notes on batch 4 (2026-11-14):** crucifix palms must face FORWARD and angle slightly UP; the fists-by-the-head
  should be a real double biceps with straighter arms. Fixed: wrist roll lw=(0, 120) / rw=(0, -120) on the T arms
  (found with QA_FOCUS close-ups: roll 0 = palm back/thumb down, +90 = palm forward/thumb up, +120 = forward and a
  little up; the wrist "pitch" does not turn the palm); `_DB_OPEN` = upper arm level (1.09), elbow ~90 deg, forearm
  straight up (fist 0.85 out, 1.44 up from the shoulder), where `_DB_FIST` (HeadClampRoar) folds tighter.
- **Batch 5** (user "Yes, keep going" after the palm/biceps fixes; waiting for the user's look, NOT installed; builds
  in D:\ClaudeScratch\celebJ\out, pictures art/previews/CelebQA_{AreYouNotEntertained,LongVHold,StageEdgeDoubleBiceps,
  FistsChestCeilingRoar,LightsArmsWideHeadHands}_*.png): AreYouNotEntertained (MC-025, Epic: fist up, chest slap with
  a chalk puff, still palms-up spread with a slow turn), LongVHold (MC-030, Rare: the super-heavy V held ~3.5 s),
  StageEdgeDoubleBiceps (MC-035, Epic: standing part only, the bench leg kick needs the bench; uses `_DB_OPEN`),
  FistsChestCeilingRoar (MC-024, Rare), LightsArmsWideHeadHands (MC-049, Uncommon). Skipped as already built: MC-066
  = FistSalute (CEL-60), MC-101 = ExitFistPump (CEL-59), MC-036's wingspan = WingspanHold (CEL-46). Hand shapes for
  Phase 4 are in each clip's comment. QA: hand miss <=0.08, no foot slide, fastest <=836 deg/s, arm_in_body <=0.36
  (the slap's hand on the chest and the hands on the head: contact). Rules: palms up on a held-out arm = wrist roll
  175 (`_PALMS_UP`); a raised right arm uses `_SKY_WIDE_R` (SKY_CLEAR grazes Muscular's head); a free hand must be
  re-stated (lh=REST) on every key until its next pose or it drifts toward that pose (the slap's left arm floated out).
- **REJECTED (user 2026-11-14), batch 5 slap and hands-on-head:** "elbows are going inside the body ... a unrealistic,
  bad way ... physically impossible to go backwards with your elbows like that", and asked why the standards keep being
  forgotten. Honest cause: the rules were stored (§3.2, the ChestSlap rejection) but not re-read, and a 0.35
  arm_in_body was explained away as "contact". What was done:
  - **§5.0 standing-rules gate** written; memory `animation-quality-gate`.
  - **anim_qa.py:** new `elbow_back`, `elbow_back_raised` (hand above the shoulder), `elbow_hyper` (forearm folding
    toward the back of the upper arm), and a PASS/FAIL line against FAIL_LIMITS, calibrated on approved moves
    (hanging arms put the elbows ~0.55 behind; the approved entrance ChestSlap pops 1250 deg/s and sits 0.20-0.25 into
    the big builds).
  - **Two solver bugs found in celebration_rig.py** (the real reason for elbows swinging behind the body):
    (1) a key was first solved early in the move, with the elbow hint still blending from the default "down and
    back", and kept that elbow-behind solution for good (two identical keys of a hold ended 0.91 vs 0.40 behind):
    keys are now solved with the elbow and wrist the clip gives AT THE KEY'S TIME; (2) between keys the shoulder's
    raise/swing/twist were blended number by number, so two near-identical arms numbered far apart (swing -195 vs
    +165) swung the long way round: the shoulder now blends as a rotation (quaternion slerp, `_blend_arm`, exact round
    trip 2e-7). Every clip re-exported with this rig changes; the installed ones are untouched until re-exported.
  - **Hands on the head rebuilt:** the old target was BEHIND the head and below its top (head top measured at 2.27 in
    the chest frame; the hand target is the WRIST and the cartoon hands are ~1 stud long): now the wrists at the sides
    just under the crown (`_HEAD_CLAMP` 0.88 out), elbows out and up (`_ELBOW_HEAD_SIDE`), wrist (70, -90/+90) so the
    hands drape over the top. Slap: hand flat on its own pec from the side, elbow out at chest height (as the approved
    entrance ChestSlap).
  - **Result:** all 19 new celebrations PASS (builds `D:\ClaudeScratch\celebK\out`).
- **The 22 INSTALLED celebrations checked (user "Yes, check them", 2026-11-14):** only MilitarySalute, Shhh and
  WingspanHold pass; rebuilt with the fixed rig, FistSalute passes too (the rest need their poses fixed). Faults
  (`D:\ClaudeScratch\celebL\summary_installed_keep.txt`; pictures art/previews/CelebQA_Installed_*_Before.png):
  - hands on the head with the elbows thrown back 0.88-1.11 (the old HEAD_TOP/ELBOW_HEAD hold): DisbeliefPrayer,
    RecordJumpRoar, ReliefRoar; raised-hand elbows behind: CrowdPleaser, ThankYouWave, LeapAndBow;
  - a raised arm through the head (upper_in_head 0.15-0.28): SkyPoint, LightsArmsUp, ArmsUpBounce, RecordJumpRoar;
  - arm snaps 1,500-2,800 deg/s (approved max 1,250): RecordJumpRoar 2,800, DisbeliefPrayer 1,960, BowAndRise 1,650,
    PointAndPrance 1,570, ArmsUpBounce 1,530;
  - arms into the body beyond the limits: ThankYouWave (Fat 0.75), BowAndRise, CrouchRoarJump, SitAndLaugh,
    WingspanBiceps, WingspanCrunch, ChalkClapPump, ExitFistPump, RackSideRoar;
  - feet sliding 0.11-0.13: RackSideRoar, SitAndLaugh, WingspanBiceps; floor-hand misses SitAndLaugh, BowAndRise.
  Fixing them changes uploaded animations (new uploads and ids in CelebrationConfig).
- **ROOT CAUSE of the user's 2026-11-15 Studio faults (closed hands, coach "punching", squat bar gap and floating
  unrack, bench bar leaving the hooks by itself, arms looking broken in set-ups):** the game never got the rebuilt
  set. Studio still runs the v02 cartoon bodies (block skeleton, FIST hands baked into the mesh), the hand swaps are not
  uploaded (HandShapeConfig.AssetId 0, so nothing can open or close), and the set-up / station / fail / walk-out /
  coach animation ids are the block-rig originals, while HipHeight 2.4 and the raised J-cups come from the taller config.
  The bar is never on the lifter: the client glides it from the J-cups to the hands' midpoint on a timer (barHeldAt),
  spotters' hands follow it, and re-racking is a code glide/slide. My celebration ids (torso-rig uploads, 2026-11-15)
  went live onto those old bodies against DEVELOPMENT_STATUS's own "do not publish taller animation ids until the
  cartoon bodies go live" note: a mistake. Fix order: (1) bodies, hand swaps, gear, clothes and the re-made animations
  live together, config matched (HipHeight 2.0, J-cups 0.525, per-body bar numbers); (2) the bar drawn at the grip /
  back point with the hand-off at the frame the hands are on it; lifter-driven unrack and re-rack animations; spotters
  wait; (3) coach slaps open-handed on shoulders/neck; fails walk off yelling; the heavy walk faster; joint-flip check
  on the hypes after (1).
- **LONGER THIGHS (2026-11-16, user-approved in the bodies session: knee 1.00, was 1.178; hips/ankle/leg length
  unchanged):** lifter_heights.py has NEW_KNEE / THIGH (x1.2165) / SHIN (x0.808), station_animations stretches upper
  and lower legs separately. Every animation re-made on the new legs and the new-leg outfit (Cartoon*08), with the
  outfit placement fix and the bodies session's inner-elbow weight spread (build_cartoon_rig_05.spread_elbows): all 108
  PASS on Skinny/Fat/Muscular/BigBuff; the 126-deg elbow caps were removed again. 106 installed (old-leg files in
  D:\ClaudeScratch\backup_oldlegs_2026-11-16), 103 uploaded (D:\ClaudeScratch\golive\legs\upload_ids.txt); the config
  switch D:\ClaudeScratch\golive\legs\wire_ids.py runs together with the body + gear upload (not before: the live
  bodies still have the old legs).
- **OUTFIT PLACEMENT BUG (found 2026-11-16 by the legs-fix helper):** the gear exports store each build's pieces where
  that build stood in the gear file (Fat 9.2 studs over, Muscular 18.4, BigBuff 23) while its skeleton stands at the
  centre. anim_qa, celebration_rig's clothed envelope and the entrance Hype.outfit all loaded them as-is, so on every
  build but Skinny the clothes hung beside the body: the "keep clear of the clothes" solves and the arm_in_outfit
  checks below were REALLY only done on Skinny (big builds were kept clear of the bare skin only). Fixed in all three
  (centre_outfit: the outfit's torso middle onto the build's centre line); everything is being re-solved and
  re-checked on the new legs. RULE: when loading a per-build export, measure that it lines up with the body
  (QA_OUTFIT_DEBUG=place prints both) before trusting any number.
- **CLOTHED PASS (2026-11-16, rules 16-17, user chose "widest build"):** audit of all 108 animations wearing the v5
  outfit on Skinny/Fat/Muscular/BigBuff found 77 FAILs (mostly hands/forearms into the tee/singlet/belt, e.g. hands
  on hips up through the belt's bottom edge). Fixed by four helpers: celebration_rig + entrance Hype solver now have an
  opt-in "keep clear of the clothes" solve on all six builds (celebrations, emotes: `clothed=True`, data
  art/data/clothed_envelope_05.json, remake after any outfit change; hypes/chalk: `Hype.outfit`), hips holds rest on the
  belt's side, low fists moved outside the knees, raised arms slightly more V (BigBuff head). 74 changed animations
  installed, uploaded and wired (ids: D:\ClaudeScratch\golive\clothed\upload_ids.txt); Studio State meet run clean
  (no joint > 1100 deg/s). Left for the user: the approved squat hold on the biggest builds (BigBuff elbow_back
  0.96 vs 0.95; Muscular/BigBuff duck forearm folding into its own upper arm 0.27-0.31); Skinny floats more than "a
  little" on chest contact (crossed arms, hand on heart, chest slap) - a per-build hand correction in the game would
  fix that. RE-RUN AGAINST GEAR v6 (2026-11-16, exports CartoonClothes06/CartoonGear06; the QA, celebration_rig and
  the Hype solver now take the newest export): arm_in_outfit clear on all 108; 97 PASS; the 11 FAILs are only the
  approved squat hold on Muscular/BigBuff (awaiting the user). clothed_envelope_05.json rebuilt from v6.
  GEAR v7 (same day, redesigned singlet): same result, arm_in_outfit clear on all 108, 97 PASS, the same 11 squat-hold
  FAILs; the scripts now take the highest-numbered export on disk; envelope rebuilt from v7.
- **GO-LIVE DONE + STUDIO-TESTED (2026-11-15, my own State-meet play tests, forced good lifts and misses):** every
  re-made animation is uploaded and wired (Station, Setup, Rerack, Chalk, 24 Fails, 8 Emotes, 9 walks + 10 hypes +
  GameFace, 3 walk-off miss reactions, BenchShirt). Checked in the game with a per-frame recorder (tracks, facing, hand
  shapes, bar in UpperTorso space, coach hands on the lifter) and a joint-speed monitor (AnimationConstraint.Transform,
  flags > 700 deg/s): squat bar ON the back (0.13 before the grab, 0.51 held), the lifter unracks / racks himself, hands
  close to the grip only on the bar and open after, bench unrack at 5.4 s by the lifter, celebrations open-handed with
  fists only in their spans, misses turn and walk off with the reaction over the walk. Faults found IN THE GAME and fixed:
  1. the player had NO hand shapes (LifterBodyService.getHands race: a second body built during the first load got
     nil) - nothing could open or close all session; now waits for the load.
  2. the "elbows and shoulders doing a full 360" between animations: the old track faded out while the new one was
     still downloading on the client, so the idle pose bled through (arms down and back up, ~0.45 s at 800-1000 deg/s).
     Fix: MeetAnimationPreload (client downloads every meet animation at start) + holdThenStop in MeetLiftAnimation
     (the old track stays at full weight 0.4 s). RULE: never stop the outgoing track at the same moment the new one
     starts; never start two tracks of the SAME animation and stop one (it can stop the other on clients).
  3. Setup_Bench at 4.40 s: the reach IK snapped from a straight to a bent arm in one frame (elbow 3 -> 40, 1020 deg/s);
     Setup(arm_step_limit=6) + no jump to the plain hanging pose at 3.9-4.3. RULE: QA's per-key pop check can miss
     single-step IK branch flips - check joint speed between EXPORTED keyframes (D:\ClaudeScratch\golive\jspeed.py).
  4. chalk loops had a seam (hand 42 deg, upper arm 18 deg off between 9.0 and 0.0): chalk export now eases the last
     0.6 s onto the first frame. RULE: every looped clip must end on its first frame.
  5. coach slaps ran 1.4 s out of step with the lifter (coach jumped to his slaps alone); now the lifter's loop is
     started so it reaches the slaps as the coach arrives and the coach syncs to it; the coach walks out wide round
     the Hands shot's camera (he crossed its lens at 2 studs, a screen full of coach).
  6. after a good squat/bench the lifter turned away, walked 4.6 studs and spun back to celebrate: short straight
     backward walks are now a back step (MeetWalkPath.isBackStep, reversed walk, 0.6 speed).
  7. a missed bench walked off from the lying pose (sank into the floor, popped up mid-walk): MeetLiftAnimation.getUp
     plays the second half of Rerack_Bench first.
  8. MissHandsOnHead off-the-head swing 1592 deg/s in game: slowed to 0.45 s (884 at keys).
  9. back-to-back walks restarted the walk from frame 0 (one-frame arm jump): the walk track is carried over.
  Still open: getting up from / sitting on the meet seat snaps in one frame (Roblox seat + Animate; needs a stand-up /
  sit-down animation); the heavy walk's speed needs the user's eye; TrapSlap's clap is knuckles (approved look).
- **GO-LIVE WORK (user "Yes, go ahead", 2026-11-15), in progress:** gear session uploads the six bodies, swap hands,
  gear v5, clothes and wires ClothesConfig / LifterBuild / HandShapeConfig assets / StationLayout (and the sticky-grip
  fix). This session: QA exceptions (squat elbow_back 0.95, walk cycles' foot_slide); Setup_Bench fixed (relaxed arms
  while sitting, hands out beside the hips lying back: PASS; the head passes 0.17 under the bar lying back: check in
  Studio); Chalk_Coach_Back rebuilt (open hands on the traps, slaps on the shoulders and back of the neck, down round
  the outside: PASS; contact with the lifter to check in Studio); Rerack_Squat (5.36 s, racked 2.88) and Rerack_Bench
  (5.75 s, racked 1.25) = the set-ups reversed (art/scripts/reverse_animation.py); three walking miss reactions
  (MissHandsOnHead, MissArmSwipe, MissYell: arms and head over the walk back, PASS); SuperHeavy walk 2.59 -> 3.87 studs/s.
  Code: the squat bar drawn ON the back (StationAnimationConfig.SquatBarOnBackY 0.68 in UpperTorso space + the build's
  squatBarRest), MeetLiftAnimation.rerack plays the re-rack with the bar held until racked then puts the lifter at the
  approach spot, the miss walks off right after its fail (failSeconds + 0.25) with the reaction over the walk (no snap to
  face the front). Helpers fixing Fail_*, Entrance_Hype_* and Emote_* FAILs in scratch folders.
- **UPLOADED and WIRED (user "Yes, upload them", 2026-11-15):** all 38 published to the group (ids in
  CelebrationConfig; the run's list in `D:\ClaudeScratch\celebM\upload_ids.txt`). The 19 fixed ones point at their new
  uploads; the 19 new ones are in CelebrationConfig.List (rarities from the catalogue; their body sounds one by one, no
  sound tracks yet; camera shots for the three Legendary ones) with HandShapeConfig spans. LeapAndBow and ReliefRoar
  ("Sinking Roar") moved to CelebrationConfig.MissReactions (GAME_DESIGN, 2026-11-15). Retimed fx/events/hand spans
  updated (DisbeliefPrayer, RecordJumpRoar, PointAndPrance). Not yet: their sound tracks re-lined, new sound tracks,
  a Studio play test.
- **INSTALLED (user "Yes, install them", 2026-11-14):** the 19 fixed + 19 new celebrations copied from
  `D:\ClaudeScratch\celebM\out` into art/animations (checksums match; MilitarySalute, Shhh, WingspanHold untouched;
  41 Celebrate_ files now). Backup of the previous 22: `D:\ClaudeScratch\backup_celebrations_2026-11-14`. NOT uploaded:
  CelebrationConfig still points at the OLD uploads; the 19 new ones have no entries, ids, hand-shape spans or
  soundtracks yet; retimed beats (DisbeliefPrayer roar 2.05, RecordJumpRoar sky pumps 7.3/7.55/7.8 and clap 8.15,
  PointAndPrance, BowAndRise) need their soundtracks re-lined (make_celebration_tracks.py) after upload.
- **The 19 failing installed ones FIXED in scratch (user "Yes, fix them all", 2026-11-14):** all PASS
  (builds `D:\ClaudeScratch\celebM\out`; before/after pictures art/previews/CelebQA_Installed_*_BeforeAfter.png).
  MilitarySalute, Shhh and WingspanHold passed as installed and are left as they are. Shared fixes: HEAD_TOP = the wrist
  at the side of the head (0.88 out, 2.3 up) with wrists HEAD_W (100, -/+90) so the hands fold onto the crown, ELBOW_HEAD
  out and up (never back); SKY out from the head (-1.55); CLAP palms meeting (-0.56); CHEST_HEART on the chest surface
  (-1.0) with ELBOW_HEART out-down-forward; PUMP_DOWN in front of the deltoid (-0.85); ELBOW_HIGH a touch forward;
  DB_OPEN_OLD for WingspanBiceps' double biceps. Per clip: snaps slowed (RecordJumpRoar's sky pumps, ArmsUpBounce,
  PointAndPrance's prance 0.25 s a step and an in-front step before the arms go up, BowAndRise's kneel, DisbeliefPrayer's
  roar); hands routed round the outside of the body between poses (ThankYouWave, SitAndLaugh, BowAndRise); fists and
  hands forward of thighs, hips and bellies; feet lifted when they step (RackSideRoar's hop out, SitAndLaugh,
  WingspanBiceps); BowAndRise kneels leaning forward so the hands reach the floor (miss 0.81 -> 0.14); SitAndLaugh gets
  up pushing off the knee (the floor behind was out of reach: miss 0.76 -> 0.21) with the propped hand out to the side;
  RecordJumpRoar's bent-over head hold is a shallower fold (25 deg) with the hands on the head (folded 46 deg the draped
  hands stuck up in the air). Rule learned: hands leaving the head go up and forward first, or curled fingers dig in.

### 4.1c Body-contact moves: entrances, celebrations, emotes, chalk (2026-11-13; ChestSlap APPROVED)
- **Measuring fixed first:** the old "hand in the body" number (nearest-normal test) read ~0.6 on every move, even
  standing with the hands by the thighs. `anim_qa.py` now uses a ray-crossing inside test (majority of three rays,
  the elbow fold ignored): standing reads 0, real contact reads real depths.
- **Found (the user's six, on the rebuilt bodies):** ChestSlap 0.22-0.31 into the body, TrapSlap 0.22-0.35,
  Coach_Talk up to 0.35 (Fat), Chalk_Lifter up to 0.46 (Fat) plus an upper arm 0.4 into the head; motion jumps of
  1,100-1,600 degrees a second in NeckRoll, WarCrouch and TrapSlap. Close-ups: the hands' TURN is the problem, not
  only where they are aimed. These moves aim only a hand's centre (written on the thin block body) and never say
  which way the palm faces, so at a "slap" the hand arrives palm-up in front of the chest (ChestSlap), or on the side
  of the head instead of on the trap (TrapSlap: the block body's x 0.62 is the production bodies' neck).
- **Tried and dropped:** (1) pushing aimed points out of the skin: changed almost nothing (the hand wasn't aimed in);
  (2) a generic "lie flat wherever a hand meets the body" pass on the finished poses: barely engaged, and added a
  4,200 degrees/second flip to TrapSlap. Both removed from the moves (the helpers `contact_out`, `contact_pass` stay
  in station_animations.py, unused).
- **The fix (authored contact):** a move names its contact moments: the spot, the fingers' direction, and a weight
  track. At those moments the hand goes onto the posed middle build's real skin (`art/data/body_surface_05.json`,
  `export_body_surface.py`), a hand's half-thickness off it, turned palm-to-skin; the arm and wrist are solved exactly
  (`lock_hand` with the hand-centre offset) and ease in and out with the weight. Built into the hype moves (`Hype(...,
  palms=...)`). **ChestSlap, first try REJECTED by the user (2026-11-13):** palms on the chest but "elbows are digging
  and phasing through the character's body" (the solver only knew "elbow below the hand"). **Second version:** the
  elbow and the whole forearm keep clear of the posed skin (`lock_hand(..., clear_of=frames)`), the slap comes from
  the side (fingers pointing in toward the breastbone, forearm and hand in line, elbows out at chest height), each
  hand on its own pec at x 0.66 so the fingertips stop short of the middle. Deepest contact now Skinny 0.11, Fat 0.20,
  Muscular 0.25 (that one is Muscular's bigger fingertips meeting in the middle: its per-build fit). Tried and
  dropped: the spots at x 0.76 laid onto the skin (hands higher and wider, an upper arm toward the head, a jerk).
  Only Entrance_Hype_ChestSlap changed; timing identical. Pictures: `art/previews/ContactQA_ChestSlap_*.png`
  (rows: the rejected version, the new one).
- **TrapSlap first tries (2026-11-13), put back, then solved with cross-body slaps (approved, see §4.3):** with arms x1.5 and the elbow's fold
  (150 degrees) a hand cannot reach the top of ITS OWN shoulder (the nearest reachable point of its own trap is beside
  the neck), so an own-side trap slap always lands at the side of the (stand-in) head: with authored palm contact it
  looked like the lifter holding their head. The wind-up also put the longer arms' fingers into the head (fixed in
  the trial by raising it up and out: 0.31-0.35 -> 0.03-0.11). The shared code stays (station_animations
  `palm_contact`, `_skin_near(facing=...)`, `lock_hand(clear_upper=...)`; celebration_rig `Clip.palms`).
  Options put to the user: each hand slapping the OTHER trap (alternating, arms crossing in front), slapping the front
  of the shoulders/upper chest instead, or waiting for the real heads.
- **NeckRoll (2026-11-13, APPROVED and installed, second version):** found: the two claps never met (the hands
  stopped a full stud apart, palms up), the pointing arm held a twisted "raised backwards" shape and dropped in 0.2 s
  along a straight line inside its reach (the elbow snapped, the arm flipped: ~1,600-2,000 degrees a second), and
  the hand cut through the Fat belly coming down. Fixed (torso rig only): the claps meet with the palms facing
  (`Hype.hands`: the hands' turn without skin contact, solved through arm and wrist), the arms start up for them a
  little earlier and the left hand goes out to the side after the second clap; the point uses the arm's natural shape
  (`Hype.natural`) and swings down along its arc (a midpoint on the arc). Peak speed ~1,000 degrees a second (the
  quick clap and the thrust into the point), contact 0.07-0.13 (the palms touching in the claps).
  **User review 2026-11-13:** "the point is pointing down instead of straight, and the palm is facing sideways ...
  the hands are phasing through each other". Fixed: the point aims straight out from the shoulder at shoulder height
  (aimed a little beyond the reach so the arm is fully straight), the hand turned palm down, knuckles up, the finger
  ahead, by the WRIST only (`hands` spec `wrist_only`: turning it through the arm had raised the arm out sideways and
  flipped); the clap and point turns no longer overlap; the claps leave room for the biggest hands (palms 0.40 apart:
  Muscular's touch, Skinny's stop just short, no fingers crossing); the arm can't dip sideways in the thrust. Peak
  ~1,000-1,450 degrees a second (the thrust). **Game note:** HandShapeConfig has no Point span for Hype_NeckRoll, so
  in game the pointing hand stays open until one is added (2.42-2.9 s; Phase 4, a config line).
  Pictures: `art/previews/ContactQA_NeckRoll_*.png` (the pictures show the Point swap: anim_qa `QA_SHAPES`).
- **WarCrouch (2026-11-13, APPROVED and installed):** no body contact in it (0.01-0.06); the
  problem was snaps: the arms' big swings (hanging to swung back at the start, swung back to up-and-out in the
  explosion, up-and-out to hanging at the end) went along straight lines inside the arms' reach, the elbows folding
  and snapping open (~1,600-1,840 degrees a second), and the arms-up spot was out of reach, so the solver jumped
  between arm shapes as the arms started down. Fixed (torso rig only): a midpoint ON each swing's arc
  (`arc_mid`), the arms-up spot and the lowering point pulled just inside the reach. Only the explosion is fast now
  (~1,000 degrees a second, even). Pictures: `art/previews/ContactQA_WarCrouch_*.png`.
- **Coach_Talk (2026-11-13, v2 APPROVED by the user "Yes, install it", installed):** the clipboard hand and the talking hand
  (written on the thin block body) sat 0.35 inside the Fat belly; these hands must NOT touch. v1 pushed the hands out,
  then re-solved each arm with a separate `lock_hand` pass; the user REJECTED it: "elbows are phasing through the body
  once again" and the talking arm went "a weird zigzag unnatural way". Cause: the post-pass re-solved the arm after the
  natural-arm solve, so it threw away the elbow-down preference and bent the arm to hit the pushed-out point.
  v2 (torso rig only): the post-pass is gone; the hands are still pushed a hand's half-thickness plus 0.12 in front of
  Fat's skin (`chalk Clip.clear_of_builds = ("Fat",)`), and the clearance lives INSIDE the one arm solve: elbow and two
  forearm points pay a cost when closer than 0.10 to Fat's skin (weight 6), with the hand-reach weight raised to 25 so
  the hand still lands (worst miss 0.06). Result: clipboard forearm across the chest with the elbow out to the side, the
  talking arm a plain L bend. Contact Skinny 0.00, Fat 0.00, Muscular 0.02; fastest moment ~360 degrees a second at
  0.7 s. Rule: never fix contact with a second solve after the natural one; put the clearance into the same solve.
  Pictures: `art/previews/ContactQA_CoachTalk_*.png`.
- **Chalk_Lifter (2026-11-13, APPROVED by the user "Yes, install it", installed):** coming up from the bowl the arms swung
  up into an X in front of the face (upper arm 0.40 into the head on every build), the "together" rubbing and
  clapping hands were a full stud apart with the palms up, and the hands went straight down through the Fat belly
  (0.46). Cause: the old chalk Clip solved each pose on its own with only a weak elbows-down wish, so with arms x1.5
  reaching a spot close to the chest it found the crossed, raised-backwards arm shape; the hand turn was never
  controlled. Fixed (torso rig only) by putting the move on the approved NeckRoll clap method (entrance Hype, imported
  by chalk_animations): solved in time order, `natural` (no raised-backwards arms), the rub and claps at NR_CLAP's
  spot (palms meet), turned palm to palm with the fingers forward and up, palms down in the bowl, the hands
  swinging forward round the shoulder to the bowl and, after the claps, parting out wide then dropping on the arm's
  arc. New option for this: `Hype.keep` passes `keep=0.01, first_step=4` to `lock_hand` (stay near the arm's natural
  solve, no 16-degree search hops): the elbows had swung round the shoulder-hand line between frames (1,300 degrees
  a second). Defaults unchanged, so the approved moves are unaffected (full rebuild: only Chalk_Lifter differs).
  Result: head 0.00 (was 0.40), arm in body 0.13-0.14 (was up to 0.46), fastest moment ~610 degrees a second in the
  claps. Same timing and clap times. Skinny's smaller hands leave a small gap between the palms in the rub (per-build
  hands, Phase 4). Pictures: `art/previews/ContactQA_ChalkLifter_*.png`.
- **Still to do:** none of the six flagged moves; per-body contact (Fat's chest is deeper than Fit's): per-build
  variants or runtime IK, Phase 4.

### 4.2 Proposed, needs the user
1. **Per-build hand IK and bar offsets in the game** (Phase 4, §3.3).
2. Then, in this order (user's recommendation 2026-11-13): squat set-up, then entrances and celebrations (§1 #9).

### 4.3 Approved
- **Arms x1.5** on the torso skeleton (user 2026-11-13, answering "Which fix do you want? 1. Arms x1.5 / 2. Shorter
  torso": "1."). Keeps the torso x1.35 and legs x1.0.
- **The deadlift** (Setup_Deadlift, Station_Deadlift, the 8 deadlift fails) on the rebuilt bodies: the set position
  in §4.1, the MIXED GRIP (left palm forward, right palm back) with the fingers wrapped round the bar in the Grip
  swap (user 2026-11-13, after the close-ups: "Looks good"). Blender pictures only; Studio not tested yet.
- **The squat** (Setup_Squat, Station_Squat, the 8 squat fails): the bar placed across the upper back below the neck,
  hands locked onto it (palms forward, fingers over, thumbs in, elbows back and down), the per-body hands and bar
  depths of §4.1b (user 2026-11-13, on the third row "AFTER + per-body hands": "It looks right to me"). Blender
  pictures only; Studio not tested yet. The duck-under's brief head/neck overlap stays the accepted trade-off.
- **Body-contact method** (ChestSlap, second version: user 2026-11-13 "Looks right"): authored contact moments, the
  palm flat on the posed skin, the arm and wrist solved exactly, the elbow and forearm kept clear of the body, the
  slap from the side. To be used for the other body-contact moves one by one.
- **TrapSlap as ALTERNATING CROSS-BODY slaps** (user 2026-11-13 "Yes", after the trial pictures): each hand slaps the
  OTHER trap in turn (a hand can't fold onto its own shoulder with arms x1.5), the palm on top of the trap, the free
  hand low at the side; then the original clap. Timing unchanged. Per-hand contact in celebration_rig (`palms` with
  "Left"/"Right").
- **NeckRoll, second version** (user 2026-11-13 "Yes, install it"): claps palm to palm without crossing fingers, the
  point straight out at shoulder height, knuckles up, finger ahead (turned at the wrist), the arm swinging down on
  its arc. Needs a HandShapeConfig Point span (2.42-2.9 s) in Phase 4.
- **WarCrouch** (user 2026-11-13 "Yes, install it"): the arm swings on their arcs, no snaps; the explosion sweeps
  the arms out wide; the roar a V with a slight elbow bend.
- **Coach_Talk, second version** (user 2026-11-13 "Yes, install it"): the hands kept off the belly, the clipboard
  forearm across the chest with the elbow out to the side, the talking arm a plain L bend; the clearance solved
  inside the one natural arm solve, never by a second fix-up solve.
- **Chalk_Lifter** (user 2026-11-13 "Yes, install it"): on the NeckRoll clap method; palms down in the bowl, palms
  together for the rub and the claps (fingers forward and up, elbows down), the hands parting wide and dropping on
  the arm's arc; no arm across the face. All six flagged moves are now approved and installed.

---

## 5. Validation (do this before showing an animation to the user)

### 5.0 The user's standing rules: re-read before EVERY animation, check every picture against them
(Written 2026-11-14 after the user asked why the same faults keep coming back: "i feel like im telling you to follow
my standards of quality, and you keep saying you will but you never remember." The rules were stored; they were not
re-read or applied. This list is the gate.)
1. **Joints only bend the way a body can.** Elbows bend FORWARD (forearm toward the biceps), never backward; an elbow
   never points behind the body. Hands on the head: elbows out to the sides, level or a little forward, never back
   behind the head. Chest slap: the elbow out to the side at chest height, the forearm coming across, never tucked
   behind or into the ribs. Knees bend toward the toes unless deliberately poled (lying, kneeling). (2026-11-14)
2. **Nothing passes through the body.** No hand, forearm, elbow or upper arm inside the torso, head or legs; a
   slap or grab TOUCHES the surface (ChestSlap rejection 2026-11-13: "elbows digging and phasing through").
3. **A QA number over its limit is a FAIL and gets fixed, never explained away** ("it's contact", "it's per-build
   fit"). anim_qa.py prints PASS/FAIL against FAIL_LIMITS (arm_in_body 0.15, upper_in_head 0.12, elbow_back 0.45,
   elbow_hyper 10 deg, foot_slide 0.1, pop 1100 deg/s). Raise a limit only for a stated, wanted reason in the notes.
4. **Real lifters, real meets.** Copy the studied video (References/Meet Study); squat: elbows back and down, grip
   just outside the shoulders (wide only 105 kg+), the approved duck-under; never trade an approved look for a metric.
5. **Hands as the video shows them:** palms facing where the lifter's palms face (crucifix: forward, slightly up;
   spread: up), fists/points via the game's hand swaps, shown in the QA pictures (QA_SHAPES).
6. **Poses as the user described them:** double biceps = upper arms out level, forearms straight up (`_DB_OPEN`).
7. Look at all three builds in front, side and three-quarter before sending; zoom (QA_FOCUS) on hands and elbows.

Added 2026-11-15 after the user's Studio test ("you should have been noticed this and i should not have to repeat this
over, and over, and over again"):
8. **Hands OPEN unless a fist or a point is the gesture.** Claps are open palms meeting; slaps (chest, trap, shoulder,
   neck, back) are OPEN hands landing flat; waves and salutes open. Fists only to grip the bar or for fist pumps/roars.
   This must be true IN THE GAME, not only in the Blender pictures: check the game's hand-swap code actually opens
   them (a closed hand slapping reads as punching).
9. **The coach ritual:** the coach SLAPS the lifter's shoulders, traps and neck with open hands, landing on them.
10. **Squat: the lifter does it all.** Walk to the bar, duck UNDER it, the bar sits ON the upper back (no gap), hands
   set on the bar, stand up to unrack it, walk it out; after the lift walk it back in and rack it. The bar never rises
   on its own or "floats" onto the lifter (that reads as the spotters doing it). Spotters only follow.
11. **Bench: the lifter unracks and racks the bar himself** (arms lift it out of the hooks and put it back); never a
   bar that leaves the rack by itself.
12. **Fails:** the lifter does not stand facing the crowd yelling, then walk. Fail -> turn toward where he is going
   back to -> walk off WHILE yelling/screaming with hand gestures.
13. **No joint flips, ever:** no elbow or shoulder spinning through a full turn in set-ups or transitions (check pop
   deg/s and LOOK at every transition, not only the poses). Blend joints as rotations, never raw angle numbers.
14. **Walk speeds look human:** even the "really heavy" walk must not crawl.
   (QA exceptions by name, 2026-11-15: squat animations allow elbow_back 0.95, the approved squat hold; in-place walk
   cycles Entrance_Walk_* are not judged on foot_slide. 2026-11-16, user "Keep it as approved" for the hold on the
   biggest builds: squat animations allow elbow_back 0.97, elbow_back_raised 0.62 and arm_in_body 0.32 on the bigger
   builds - BigBuff's elbows in the hold, and the duck's forearm folding into its own thick upper arm. Never change the
   hold to clear them.)
15. **What the player sees in Roblox is the test.** Blender QA pictures prove the animation file; the game's own
   systems (hand swaps, bar attach and rack/unrack, walk speed, facing) must be read in code and checked against
   these rules too, before saying something is done. Never claim it works in game without a Studio test.
16. **Gear is an ACCESSORY worn OVER the clothes** (user 2026-11-16, said before and not followed: "singlets are
   accessories. You put them on it should be over the shirt it should not delete or make something underneath
   disappear"). Putting on a singlet, belt or suit never cuts, hides or removes any part of the tee or body under it;
   the tee stays whole (its crew neck shows) and the gear sits outside it with clearance in EVERY pose, bending with it
   (same skin weights), never torn / inside-out / z-fighting at its edges.
17. **Clothes and gear count as the body for clipping** (user 2026-11-16: "phasing of the elbows and hands" through
   the singlet and tee in celebrations and walk-outs). anim_qa's arm_in_body limits (0.15 / 0.26 into the BARE body)
   let hands sink through the clothes; contact moves (claps at the chest, hands on hips/belly/belt, slaps) are judged
   against the OUTERMOST layer (tee, singlet, belt) on every build. One animation plays on all six builds, so contact
   targets are fitted to the widest clothed build (a small float on Skinny beats sinking on Fat; the user chose this
   2026-11-16). anim_qa now WEARS the meet outfit from the game's exports (tee, singlet, belt; QA_OUTFIT) on every
   build's rig and reports `arm_in_outfit`: how far the hand / the forearm's far half sinks into the stacked layers
   (limit 0.03). Run with QA_BUILDS=Skinny,Fat,Muscular,BigBuff for contact moves.
18. **The mirror shows the real body** (user 2026-11-16): the gym mirror copies each character as one rigid piece
   (MirrorController); never per-part reflection, which warped the skinned body and clothes.

Tool: `art/scripts/anim_qa.py` (read-only, headless Blender):

```
set QA_ANIM=Setup_Deadlift
set QA_TIMES=0.9:feet set,2.2:reaching down,3.3:set at the bar
set QA_FOLDERS=Before=<old folder>;After=D:\Powerlifting Roblox\art\animations
blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/anim_qa.py -- <out folder on D:>
```

- Poses the animation on Skinny, Fat and Muscular (QA_BUILDS for others), the game's fist swap when a hand is on the
  bar, the bar where the game draws it.
- One sheet per moment: front, side, three-quarter and back; one row per animation folder (before / after).
- Measures **every keyframe**: arm/hand depth into the body, upper arm into the head, bar into the body, hand-to-bar
  distance, elbow bend, feet below the floor, foot sliding, motion pops; for lifts: shin lean, hip above knee, back
  angle, arm angle, shoulder over the bar, bar over the midfoot, body centre over the midfoot. Writes
  `<ANIM>_qa.md`.
- What-if previews: `QA_ARM_STRETCH` (longer arms in memory only), `QA_EXTRA_ROWS` (add another run's rows).

Checklist per animation: start, middle, hardest moment and end; all three builds; front/side/back/three-quarter; the
numbers above; then **look at the pictures**. A clean table never replaces the look, and the user's look is the
acceptance.

Pictures from the first run (2026-11-13): `art/previews/DeadliftQA_Setup_1_FeetSet.png`,
`DeadliftQA_Setup_2_ReachingDown.png`, `DeadliftQA_Setup_3_SetAtTheBar.png`, `DeadliftQA_Pull_4_BarAtTheKnees.png`,
`DeadliftQA_Pull_5_Lockout.png` (updated after the arm change: rows BEFORE = old animation on the arms x1.2 bodies,
AFTER = new animation on the rebuilt arms x1.5 bodies; builds Skinny, Fat, Muscular left to right).
