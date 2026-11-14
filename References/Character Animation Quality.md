# Character Animation Quality

The quality bar for lifter animations, rigging and equipment contact, and how every animation is checked before the
user sees it. Started 2026-11-13 from the user's review of the torso-rig pose pictures
(`art/previews/TorsoAnim_*.png`) and the brief "CRITICAL: character animation, rigging & equipment interaction quality
corrections".

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
