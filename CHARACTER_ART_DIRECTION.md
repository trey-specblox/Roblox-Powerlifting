---
tags: [art-direction, characters, standards]
status: investigation (2026-11-12), waiting for the user's approval
---
# Character Art Direction and Modeling Standards

The one place for how the lifter bodies should look and be built. **GAME_DESIGN.md §38 stays the authority for
approved gameplay decisions**; this file holds art standards, findings and proposals.

**Labels used below:**
- **[APPROVED]** = the user approved it (date and where).
- **[EXPERIMENTAL]** = Claude's proposal or finding, NOT approved. Nothing marked experimental is built.
- **[OPEN]** = a question for the user.

Related: [[References/Body Study]] (first reference pass), GAME_DESIGN.md §29.11, §38, memory
`character-quality-standard`, `gear-fitting-architecture`. Investigation written by session "Character redesign
investigation", 2026-11-12. Pictures of the current bodies: `art/previews/Redesign_Current_*.png`.

---

## 1. What is already approved

- **[APPROVED 2026-11-12, §38.7]** Chunky cartoon style on the game's own R15 skeleton; the player's own full-size
  Roblox head, hair, face and skin colour stay; no visible neck; hand-shape swaps; one smooth body, no gaps.
- **[APPROVED 2026-11-12, §38.1]** Size from bodyweight (a lifter always looks like their weight class); muscle from
  closeness to the class's Progression Reference table (PP); technique never changes the body; looks only, never
  strength.
- **[APPROVED 2026-11-12, §38.2]** Five builds to start (skinny, skinny-fat, average, muscular, big and buff), more
  later. Bodies change in steps.
- **[APPROVED 2026-11-12, §38.3]** Bulk / Maintain / Cut setting later (no food system).
- **[APPROVED 2026-11-12, memory gear-fitting-architecture]** Clothes and gear are separate assets: one master mesh
  per item + an automatic per-build fitter; rigid belt; no Roblox layered clothing for now.
- **[APPROVED 2026-11-12]** Bodies made ~13% taller (legs x1.23, torso and arms x1.15, ~5.9 studs) after the user's
  play test ("everyone too short/stubby"); all 84 animations re-made for it, NOT uploaded yet.
- **[USER'S STANDARD 2026-11-12]** The current bodies are below standard: inflated, disconnected blobs. Wanted:
  intentional, exaggerated, rounded anatomy that still reads as Roblox; distinct silhouettes, not uniform scaling;
  heads that fit every physique; clothes that follow shapes without being fused. "THE GOAL IS NOT SIMPLY TO MAKE
  CHARACTERS BIGGER."

---

## 2. Reference observations (what Claude actually saw)

References are for looks only: our bodies are our own, never copies.

**Footage accessed:**
- **3 Medal clips** (downloaded earlier with the user's OK): frames and contact sheets in
  `D:\Powerlifting Roblox Extras\References\BodyClips\` (clip1: 33 frames, mostly bench close-ups and face shots;
  clip2: 18 frames, one gym scene with three players at very different stages side by side; clip3: 34 frames, one
  top-stage player from front, side and back). Enlarged crops: `...\BodyClips\study_2026-11-12\`.
- **The YouTube video** "I Became The BIGGEST PLAYER in Roblox Gym Universe" (37 min): opened in the built-in browser
  and sampled about 20 frames between 0:05 and 36:30 (every ~1.5 min, plus close-ups at 2:00, 13:30 and 36:00).
  Saved samples: `...\BodyClips\study_2026-11-12\youtube_q7cz_sample_*.jpg`. **Limits:** the video streams at 480p,
  several frames were menus, black transitions or the face-cam, and from ~20 min on the player wears a bulky hoodie,
  so late-stage muscle detail on the player was mostly hidden. No earlier session had saved frames of it.
- Not re-seen in this pass: the user's 12-14 screenshots (studied in the first pass, Body Study.md).

### 2.1 Observations (seen in the frames)

**Three stages side by side (clip2, one scene; the number under each name looks like the game's muscle stat):**
- *Beginner ("31")*: an almost default Roblox body. Shoulders about 1.6x the head's width, thin arms hanging close,
  slim legs. A plain tee and shorts.
- *Intermediate ("3.3K")*: shoulders about 2.5x the head. The growth is almost all upper body: big round delts (two
  or three stacked rounded masses per shoulder), thick upper arms, a forearm that flares at the elbow, a chest block.
  The waist stays narrow with a belt; the legs are short and thick but clearly smaller than the upper body. The tee is
  a tight shell that shows the delt and chest masses, not the abs.
- *Advanced ("7.9K-8.1K", clip3 and right side of clip2)*: shoulders about 3x the head. Traps rise to the bottom of
  the ears and climb the head's sides; the head sits INTO the body with no neck. Pecs are wide slabs, abs are visible
  as shallow pillows inside one torso shape (not separate balls). From behind: a big trap/upper-back mass, a deep spine
  groove, wide lats, round glutes. Arms hang far out from the torso and are nearly as thick as the legs. The legs are
  much less exaggerated than the torso. A glowing aura effect marks the top stage.
- *Heavy beginner (clip1, the "UnPure" hoodie lifter)*: a round soft torso under a hoodie, small arms, the head
  looks big; the body widens at the belly, the head stays the same size.

**Across the YouTube video (seen):**
- At 0:30-2:00 the player already has a boxy, chunky white upper body on slim black-trousered legs; an NPC ("Big
  Benny") seen from behind is round and soft, wide at the waist, smooth shoulders.
- At 5:00-7:00 visible six-pack and bigger arms/delts; shirtless; the legs stay slim.
- At 13:30 and 36:00 a "flex off": an orange NPC with a huge V-shaped upper body (traps into the head, very wide
  delts and chest) on ordinary-looking legs in trousers; the player in a hoodie is wide and round on top. The heads
  are the same size on every body.
- Stage cues the game shows: "BACK MAXED", "LEGS MAXED" banners; separate stats per muscle group (back, legs, arms...).
- The head never changes size in any frame; hands are chunky (wider than the wrist) on every stage.

### 2.2 Interpretations (Claude's reading, not facts)

- **Growth order:** shoulders/delts and arms grow first and most, then chest and traps, then back; legs grow least.
  The waist stays narrow on lean builds, so the V-taper grows faster than the overall size.
- **Size vs definition are separate:** the intermediate is big but smooth; definition (ab pillows, spine groove)
  shows mainly at the top stage. Heavy bodies have size with no definition.
- **Continuous growth with a few shape changes:** the silhouette swells gradually (the video shows small changes
  between samples), and the top stage adds new details (traps over the shoulder line, ab pillows, the aura).
- **Head readability comes from integration, not from head size:** the head looks right on huge bodies because the
  traps and shoulders wrap its lower part and the shoulder line rises toward the ears. It looks small only where a
  flat ledge or visible neck sits under it.
- **Roblox silhouette kept:** long torso, short legs, big hands, plain rounded feet. Big physiques get wider, never
  taller; the legs never dominate.
- **Clothes:** tight shells that follow the big masses (delts, chest, belly) but not small grooves; thick white
  cuffs and waistbands make the edges read.
- **Art style is consistent across stages:** same smooth plastic-like shading, the same head, the same hands; only
  volume and a few details change.
- No exact formulas can be read from footage; any numbers below are our own proposals.

---

## 3. What is wrong with the current bodies (CartoonBodies_02.blend, measured 2026-11-12)

Inspected headlessly (front, back, side, three-quarter, silhouettes, with a stand-in 1.2-stud Roblox head and
backface culling): `art/previews/Redesign_Current_front.png`, `_back.png`, `_side_spread.png`, `_threequarter.png`,
`_silhouettes.png`.

**Root cause:** `art/scripts/build_cartoon_body_02.py` builds every muscle as its own ellipsoid and fuses them with a
voxel remesh, then smooths and decimates. Ellipsoids added onto ellipsoids can only read as balls stuck onto a body;
the smoothing then blurs the joins on skinny/heavy (SOFTEN 12) and leaves hard rings on muscular (SOFTEN 4). The
result is also a triangle soup with no edge loops at elbows and knees, so it bends less cleanly.

**Specific weaknesses (seen in the renders):**
- **Abs:** Muscular has six small separate balls stuck on the stomach (the worst read in the set).
- **Chest:** two round pads on a flat torso (Muscular) or two small breast-like bumps (Heavy, Skinny); no flow from
  pec into the front delt or up to the collarbone.
- **Shoulders:** Skinny and Heavy show a small round "doll joint" knob where arm meets torso. Muscular delts are
  stacked balls; delt-to-upper-arm has a crease ring instead of the delt wrapping over the arm.
- **Traps/neck:** Muscular traps are two bumpy lumps beside the head. Skinny and Heavy have a FLAT LEDGE under the head
  (the torso top is a table), which makes the head look stuck on and small.
- **Back:** Muscular lats are two big separate ovals stuck on the back, not flowing from the armpit to the waist.
- **Glutes:** on all three, two balls hanging below a flat back with a hard crease.
- **Belly/waist:** Heavy's belly is a near-perfect sphere attached to the front; no love handles, no flow into the
  chest or the hips; from the side it is the only thing that differs from the other builds.
- **Side view:** all three bodies are almost the same depth; Skinny's torso is thinner front-to-back than the head
  (a lollipop look). Builds only differ in width, which reads as "the same body scaled".
- **Legs:** sausage segments; Muscular's thigh "teardrop" is a lump at the inside of the knee; knees and ankles pinch
  to thin sticks; calves are balls.
- **Wrists/hands:** the forearm pinches at the wrist; the open hands are thin and pale and read tiny, especially on
  Muscular (hand ~0.36 wide against a ~0.7 forearm, even with HandShapeConfig.HandSize 1.28).
- **Feet:** flat pancake ovals.
- **Silhouettes:** front silhouettes are three boxes of different widths; Muscular pinches hard at the waist and
  bulges at the knees. Side silhouettes are nearly identical.
- **Head relationship:** head 1.2 studs on a 5.9-stud body (about 1/4.9 of the height); the references sit nearer
  1/4.3. The taller pass made legs longer, which moves away from the Roblox silhouette (long torso, short legs).
- **Budget:** bodies 5,100-6,000 triangles plus 1,400 per hand (hands are ~1/3 of the body's budget); forearms only
  ~230-320 triangles.

---

## 4. Proposed anatomy standard [EXPERIMENTAL]

**Principle: big readable masses first, details second.** Each build is designed as a silhouette (front, side, back)
before any muscle detail. Muscles are shallow shapes carved INTO one continuous form, never balls added onto it.

- **Torso:** one continuous form per build (a rib cage block tapering into the waist), with real depth differences
  between builds (skinny shallow, heavy deep at the belly, muscular deep at the chest and upper back).
- **Neck/traps:** no flat ledge ever. The torso's top slopes up into the head's lower third on every build (small on
  Skinny, high on Muscular); the head's bottom edge is hidden by the slope. Clearance kept for the head's turn.
- **Shoulders:** the delt is a cap that WRAPS over the top of the upper arm and flows into the pec at the front and
  the trap at the back; no knob, no ring.
- **Chest:** wide slabs from the sternum to the delts, lower edge overhanging only on muscular builds; soft and low
  on heavy builds; flat on skinny.
- **Abs:** pillows pressed into one stomach surface (shallow grooves), visible only on lean, muscular builds; never on
  heavy or skinny-fat.
- **Back:** lats flow from under the armpit to the waist (V-taper); spine groove; trap diamond on muscular builds.
- **Belly/waist (heavy builds):** the belly is part of the torso: wide at the sides (love handles), low, pushing the
  waistline forward and down; it blends up into the chest and down into the hips.
- **Hips/glutes:** glutes are one rounded mass with the back of the thigh, a soft crease only at the bottom.
- **Legs:** quads sweep outward, hamstrings round the back, calves a diamond; knees and ankles keep a minimum
  thickness (no pinching). Legs grow less than the upper body (the reference look).
- **Arms:** biceps/triceps flow into a forearm that is thickest just below the elbow and tapers to a wrist that is
  still thick enough to meet the hand cleanly.
- **Hands:** chunky, at least as wide as the wrist, scaled per build so they never look small on big arms (target:
  hand width about 0.9-1.0x the forearm's widest point). Lower triangle count, better shape.
- **Feet:** rounded shoes with a little height at the toe and heel, not flat discs.
- **Exaggeration:** welcome, but every bulge must have a reason (a muscle or fat mass) and connect to its neighbours.

**Quality checklist for every body (before showing the user):** front, back, side, three-quarter and silhouette
renders at the same camera and light; no balls/lumps without flow; no flat ledge under the head; no pinched joints;
hands read at game distance; side silhouette differs from the other builds; check_models.py CHECK PASSED; posed
checks (squat bottom, bench, deadlift start, arms overhead) without tearing.

---

## 5. Physique progression [EXPERIMENTAL proposal on the EXISTING systems]

Nothing here changes how strength is earned. It only maps numbers the game already has to looks.

### 5.1 What the code does today
`src/shared/Economy/LifterBuild.luau`: PP = average of (CN / class reference) over the three lifts, clamped 0..2.
Muscular at PP >= 0.40, else Heavy above 83 kg, else Skinny. Three steps.

### 5.2 What the numbers do over time (from GAME_DESIGN)
- A new lifter starts at 53 kg with 25 kg in each lift: measured against the 59 kg references, PP is about 0.10.
- §34.11's projection (candidate BaseProgressRate, not live): a 59 kg lifter reaches about PP 0.94 by day 90, and PP
  keeps climbing past 1.0 very slowly (the Hill curve). The live rate is about 2.3x slower.
- **So with today's 0.40 threshold, a player jumps from Skinny to fully Muscular within a few weeks, then never changes
  again.** That is both too fast at the top and too abrupt.
- **Bodyweight today only changes through the admin panel** (Bulk/Maintain/Cut is approved but not built). So every
  real player is 53 kg for now: the fat axis below only matters for computer lifters until §38.3 exists.

### 5.3 Two separate axes
- **Muscle (from PP, looks only):** Low below 0.35, Mid 0.35-0.70, High 0.70 and up. Within each level, small steps
  (see 5.5). The top looks are held back for the long tail: "highly muscular" from PP ~0.95, "elite" from PP ~1.10
  (months of training, consistent with §29.13's curve). Thresholds are proposals to tune.
- **Body fat (from bodyweight against what the muscle "fills"):** each muscle level fills a lean weight (proposal: Low
  66 kg, Mid 83 kg, High 105 kg). Bodyweight at or under it = Lean; up to 20 kg over = Soft; more = Heavy.
- **Size (from bodyweight, §38.1):** the frame is resized to the class (width/depth only).
- Why this fits the approved rules: heavy and weak looks fat, heavy and strong looks big and buff, light and strong
  looks lean and muscular on a small frame, light and weak looks skinny. A lifter always looks like their class.
  Moving up a class keeps the kilos, so PP drops a little: the body softens a little, it never jumps.

**Worked examples:**

| Lifter | PP | Muscle | Fat | Look |
|---|---|---|---|---|
| New player, 53 kg | 0.10 | Low | Lean | Skinny |
| 83 kg, weak | 0.20 | Low | Soft (+17) | Skinny-fat |
| 120 kg, half the 59 kg numbers (§38.1 example) | ~0.34 | Low | Heavy (+54) | Fat |
| 66 kg, moved up from 59 kg | 0.56 | Mid | Lean | Fit |
| 93 kg | 0.50 | Mid | Soft (+10) | Big and buff (small end) |
| 59 kg, near the top | 1.0 | High | Lean | Highly muscular, small frame |
| 120 kg, strong | 0.90 | High | Soft (+15) | Big and buff (super-heavy powerlifter) |

### 5.4 The user's eight categories on six sculpted bodies
| Muscle \ Fat | Lean | Soft | Heavy |
|---|---|---|---|
| **Low** | Skinny | Skinny-fat | Fat |
| **Mid** | Fit ("average" at its smallest step) | Big and buff, small end | Fat, with thicker arms |
| **High** | Muscular -> Highly muscular -> Elite (steps) | Big and buff | Big and buff, heaviest step |

Six bodies: **Skinny, Skinny-fat, Fat, Fit, Muscular, Big and buff.** Average, highly muscular and elite are steps
within those bodies. This covers the approved five (§38.2) plus Fat and Fit. **[OPEN]** see §9.

### 5.5 Small steps between bodies (no ugly jumps)
- Each body has 3-5 continuous steps: per-part width/depth scaling (never length, so animations still fit), e.g. up to
  +12% on arms, chest and back.
- Neighbouring bodies are designed to OVERLAP: the top step of one is as big as the bottom step of the next, so a swap
  changes the shape language more than the size.
- Swaps happen at calm moments (respawn, after a training session or a meet result, with a small "you grew" moment),
  never mid-lift, with a small buffer so a lifter near a threshold doesn't flicker.
- **[OPEN] Per-lift emphasis** (§38.7 idea, not decided): the per-part steps could follow each lift's own PP (squat:
  thighs/glutes; bench: chest/delts/triceps; deadlift: back/traps/forearms). Cheap with per-part scaling; needs the
  user's yes.
- Definition (ab pillows, grooves) can't grow continuously in a mesh. It belongs to the Muscular body's sculpt; a
  texture/normal-map layer for extra definition is a later idea to test (it must keep the player's skin colour).

---

## 6. Roblox technical strategy [EXPERIMENTAL]

### 6.1 What Roblox supports for changing a body (checked 2026-11-12)
- **Swapping whole bodies:** fully supported (what LifterBodyService already does with ReplaceBodyPartR15).
- **Resizing body parts** (part Size / Humanoid body scales): supported on skinned bodies; uniform per part, so it
  inflates rather than reshapes: good for small steps, bad as the main tool.
- **Morph targets / blend shapes on bodies:** NOT available as a normal feature. Skinned meshes have no shape keys
  (Roblox staff, skinned-mesh beta thread); FACS shapes are for dynamic heads. EditableMesh gained skinning in a Studio
  beta, but it doesn't replicate (each client would rebuild every body), has size limits, and is still beta. Bones can
  only move/rotate, not scale. WrapDeformer/cages are the layered-clothing pipeline, not a body morph tool.
- **Conclusion:** **hybrid** = a few sculpted bodies (swaps) + small per-part scaling steps. Revisit EditableMesh if it
  leaves beta and replicates.

| Option | Looks | Cost | Risk |
|---|---|---|---|
| Swaps only | steps feel abrupt | each body = its own clothes/gear fits and uploads | jumps |
| Continuous morphing | smooth | not supported in live games today | beta APIs, per-client cost |
| **Hybrid (recommended)** | smooth enough | 6 bodies + code steps | seams if a step is too big (test) |

### 6.2 How to build the new bodies
- **One shared control cage for every build:** a low-poly body cage with the same vertices on all builds, subdivided
  into the smooth surface (clean flowing forms by construction, edge loops at elbows/knees/shoulders). Each build is
  the same cage with its vertices moved.
- Why: same topology and UVs on every build (clean bending, consistent shading); the gear fitter can map one body to
  another; any blend of two builds is a new build for free (so "more builds later" from §38.2 becomes cheap); ready for
  real morphs if Roblox ever supports them.
- Muscles: shallow sculpted detail on top of the cage forms (or cage creases), never added ellipsoids.
- Still built by a script in Blender (repeatable, Git-tracked), checked by check_models.py, previewed with backface
  culling.

### 6.3 Rig and alignment
- Keep the same R15 skeleton and joint table for every build (all 84 animations shared).
- Part splits at the same places on every build; neck mark, hip height and arm pivots per build as today
  (ClothesConfig.Bodies already holds neckMark, squatBarRest, benchBarClear).
- Arms: each build's arm must hang outside its own lats and belly so arm swings don't clip (wider builds = arms
  further out; the shoulder pivot stays fixed by the skeleton).

### 6.4 Budgets (about 30 players per server)
- **Proposal:** body 5,000-6,000 triangles including hands (hands ~600-800 each, not 1,400), clothes outfit ~2,000,
  full gear ~3,200 (gear session's budget): about 10,000-11,000 per fully dressed lifter, ~330k for 30 on screen
  (Roblox's automatic mesh LOD reduces distant ones). Six bodies share one topology, so memory is small; the real cost
  is authoring and checking.
- The hidden hand-shape swaps: rigid, low-poly, one set shared by all builds (scaled per build).

### 6.5 Clothes and gear (coordination, not ownership)
- The gear session owns gear (master mesh + fitter). The bodies must give it: smooth outlines without grooves, one
  shared topology, and stable part names. **Each new body means one more fitted clothes model and gear model to
  check and upload**, which is why the body count matters (§9).
- Tight clothes follow the big masses (delts, pecs, belly) but not the abs grooves; cuffs and waistbands make edges.

### 6.6 Heads
- Keep the player's own head at its normal size by default; make it read by integration (traps/shoulders wrap the lower
  third, no ledge, no visible neck).
- **[OPEN]** test a slightly bigger head (HeadScale 1.1) on the big builds in the comparison prototype; Roblox scales
  hats and hair with it.

---

## 7. Comparison prototype plan [EXPERIMENTAL; round 1 built 2026-11-13, results in §10]

**Goal:** decide the direction with pictures before any body is replaced.

- **New files only:** `art/scripts/build_cartoon_body_04.py` (shared cage), `art/blender/CartoonBodies_04_Proto.blend`,
  previews `art/previews/Redesign_Proto_*.png`. `CartoonBodies_02.blend` and its scripts stay untouched.
- **Builds in the first round:** Lean (Skinny), Heavier (Fat), Muscular, each as CURRENT vs NEW, side by side.
- **Views:** front, back, side, three-quarter, flat-black silhouettes, plus a head close-up (head/shoulder join) for each.
- **Same for every picture:** orthographic cameras at fixed positions, studio light, backface culling on, the same
  stand-in Roblox head (and one test with HeadScale 1.1), a scale bar and the 5.2 vs 5.9 stud height lines.
- **Also shown:** the height question (current taller legs vs a version with the extra height in the torso only),
  hands at game size, triangle counts per build, check_models.py result.
- **Clothing fit:** only where the gear session has a fitter ready; otherwise the tee/shorts preview colours.
- **Posed check:** squat bottom, bench lockout, deadlift start, arms overhead, a chest slap, using the existing
  animation scripts' poses, in Blender only.
- **Then STOP** for the user's pick. No uploads, no Studio, no replacing bodies until approved.

**Directed tests after the pick (each with a written pass/fail before it runs; replaces the dropped "stretch" test):**
1. Blender: each new body through the five check poses; pass = no tearing, no arm through torso/belly, hands meet the
   bar positions within 0.05 studs.
2. Blender: gear fitter on each new body (when the gear session's fitter is ready); pass = its clearance checker clean
   at rest and in the poses.
3. Studio (after an approved upload): spawn as each build; Roblox walk/run/idle; one training rep of each lift; one
   celebration with a hand swap; pass = feet on the floor, bar in the hands, no clipping seen, no errors.
4. Studio: computer lifters at a meet across classes; pass = the two-axis mapping gives the expected looks (table §5.3).

---

## 8. Animations

See section 8 detail below (inventory). Strategy [EXPERIMENTAL]:
- **One shared rig and one shared set** for every build (the 84 animations and their timing, triggers, lift mechanics,
  minigame timing and success/fail logic stay exactly as they are).
- **Per-build corrections in code, not per-build animation copies:** bar contact already uses per-build numbers
  (squatBarRest, benchBarClear, StationPoseAnimator following the hands). Bodies are designed with arm clearance.
- **Per-build variants only where a Studio test shows bad clipping** (e.g. hands-on-body moves on the widest builds),
  generated by the same scripts with an arm-offset setting, and only after asking the user.

### 8.1 Inventory (2026-11-12; full raw table with keyframes, ids and code lines in the session notes
`side-session-notes\local_10230866-...\animation-inventory-raw.md`)

**Facts that apply to all of them:**
- **84 animations** in `art/animations/` (+ `R15_BlockRig.rbxmx`, Roblox's stock R15 block rig, the source of the joint
  table: not an animation). Station 3, Setup 3, Fail 6 + Bailout 6 + Grinder 6 + Dramatic 6, Celebration 22, Emote 8,
  Entrance walk 9 + hype 10 + touch 1, Chalk 3, Bench shirt 1.
- **All generated by scripts** from ONE shared joint table (`art/scripts/station_animations.py`); every other generator
  loads it. `LIFTER_RIG=block` rebuilds the original block-rig versions.
- **Live vs new:** every id in the configs is the ORIGINAL upload (block rig, hip height 2.0) and works in the live game
  on block bodies. The 83 changed files + `Celebrate_Shhh` are the TALLER versions (hip height 2.4): **not uploaded,
  not tested in Studio**. Keyframe timing is identical to the originals (checked on all 83).
- **No per-build animation variants exist.** The only per-build correction is in code and moves the BAR, not the arms
  (`ClothesConfig` squatBarRest / benchBarClear, `StationPoseAnimator.barSpot`). Hand targets on the body assume the
  block body's width (`celebration_animations.py:33`: "the body is no wider").
- **Tested on the current cartoon bodies in Studio:** Station Squat/Bench/Deadlift (with the bar offsets) and Setup
  (meet lift) on all three builds; idle/run. Everything else: not seen on the cartoon bodies yet.
- **Found during the inventory:** `Celebrate_Shhh` has no id and is missing from `CelebrationConfig`, so its Point
  hand timeline can never play; `Chalk_Coach_Back` puts the coach's hands at a fixed spot on the lifter's back made for
  the block body (likely inside the Heavy build); `Entrance_Touch_GameFace` is now rarely or never reached (every meet
  level has hype moves since 2026-11-12); celebration/emote files end up to 0.017 s short of their config length
  (1/24 s sampling, harmless).

**Reading the tables:** Risk = how close the pose brings hands/arms to the body (clipping risk on wider bodies).
Reuse = can it play on the redesigned bodies unedited? **Yes** = expected fine; **Check** = test in the directed
Studio test, probably fine; **Fix likely** = expect a per-build adjustment (code offset or a script variant, with
the user's OK). Visual issues on current models: hands read small in every hand pose; arms close to the body clip
most on Heavy/Muscular.

**Lifts and setups** (StationPoseAnimator in training, MeetLiftAnimation at meets; hands grip via code)

| Animation | Purpose | Risk | Reuse |
|---|---|---|---|
| Station_Squat / _Bench / _Deadlift | the rep loop (6 s) | High: bar on back / chest / along thighs | Check: per-build bar numbers needed for each new body; squat keeps block arm angles (`SQUAT_ARM_RESOLVE = False`) |
| Setup_Squat / _Bench / _Deadlift | meet walk-up, unrack | High (squat, deadlift), Med (bench) | Check, same bar numbers |

**Fails** (StationAnimationConfig.failFor from LocalMeetService / warm-up; style chosen per player)

| Animation | Purpose | Risk | Reuse |
|---|---|---|---|
| Fail_Squat_1/2, Fail_Bench_1/2, Fail_Deadlift_1/2 | default fails | High (bar on body, sitting, hands on hips) | Check; hands-on-hips likely sinks into Fat / Big and buff -> Fix likely |
| Fail_Bailout_* (6) | push the bar away, shake out | Med | Check |
| Fail_Grinder_* (6) | long grind, then drop | High | Check (bar numbers) |
| Fail_Dramatic_* (6) | floor slaps, hands on head, arm over face | High | Fix likely on the big builds (hands on head/face pass close to traps) |

**Celebrations** (CelebrationService / CelebrationCinema; hand swaps from HandShapeConfig)

| Animation | Purpose | Risk | Reuse |
|---|---|---|---|
| WingspanHold, ArmsUpBounce, SkyPoint, CrowdPleaser, FistSalute | arms out / up | Low | Yes |
| ChalkClapPump, ExitFistPump, MilitarySalute, LightsArmsUp, PointAndPrance, ThankYouWave | clap, salute, pump, wave | Med | Check |
| WingspanBiceps | crouch + double biceps | Med-High | Check |
| Shhh | finger to lips | Med-High | Needs an id + config entry first (missing) |
| ReliefRoar, SitAndLaugh, RackSideRoar, CrouchRoarJump, WingspanCrunch, DisbeliefPrayer, LeapAndBow, BowAndRise, RecordJumpRoar | crouches, kneels, bows, fists at chest/belly, prayer, sitting | High | Fix likely on Fat / Big and buff (fists at the belly, knees to the belly, forehead to the floor) |

**Emotes** (EmoteService from the emote wheel)

| Animation | Purpose | Risk | Reuse |
|---|---|---|---|
| Wave | wave | Low | Yes |
| ChalkClap, DoubleBiceps | clap at chest, flex | Med | Check |
| BeltTighten, TrapSlap, PointLaugh, SitBreath, MostMuscular | hands on belt/shoulders/belly, sitting, crab pose | High | Fix likely (these touch the body on purpose: the hand target must follow each body's surface) |

**Entrances** (MeetEntrance; walks also on computer lifters)

| Animation | Purpose | Risk | Reuse |
|---|---|---|---|
| Walk_Swagger, Stomp, Airplane, RaiseRoof, CrowdLift, SuperHeavy, ArmUp | walk-out strides | Low | Yes (new walk speeds go live WITH the new ids) |
| Walk_Hype, Walk_WarCry | arms close to the sides / swung behind the hips | Med | Check |
| Hype_OverheadClap, WingsV, CrowdLift | open moves | Low | Yes |
| Hype_Flex, NeckRoll, WarCrouch | flex, claps, crouch | Med | Check |
| Hype_Belt, ChestSlap, TrapSlap, ChalkRitual | slaps and tugs on the body | High | Fix likely |
| Touch_GameFace | chest clap + belt tap | High | Fix likely, but rarely reached now |

**Chalk and gear**

| Animation | Purpose | Risk | Reuse |
|---|---|---|---|
| Chalk_Lifter | chalking at the bowl | Med | Check |
| Chalk_Coach_Back | coach's hands on the lifter's back | High (other body) | Fix likely: the coach's distance must follow the lifter's build |
| Chalk_Coach_Talk | coach with clipboard | Med | Check (on the coach's own build) |
| BenchShirt_ArmsForward | arms forward while a bench shirt is worn | Low | Yes |

**Summary:** about 17 play unedited, about 35 need only a check, and about 26-32 (the deliberate self-contact moves,
the crouch/kneel celebrations, the dramatic fails and possibly the default fails' hands-on-hips) will probably need a
per-build adjustment on the heaviest builds. Shhh first needs its id and config entry.
The best fix is a body-surface target per build (the scripts already place hands with targets like `B(v)`), so one
script setting regenerates the affected clips per build; whether that means per-build uploads is a decision for after
the directed Studio test.

---

## 9. Contradictions and decisions for the user

**User's answers to the first three (relayed by the coordinating session, 2026-11-12):**
- The eight body types were only a test of what Claude could make; the set should be redesigned to fit the quality
  standard, not bound to eight. Muscularity and body fat as separate parameters is still wanted.
- Heads vs taller bodies: fine; the redesign settles head size and height together.
- Animations: the 84 were re-made for the taller rig (not uploaded); the originals are kept (live ids, and
  `LIFTER_RIG=block` in the scripts rebuilds them).
- The "stretch" test is dropped; future body tests must be new and clearly directed (the prototype plan in §7 is that).

1. **Body count [OPEN, recommendation updated]:** **six sculpted bodies** (Skinny, Skinny-fat, Fat, Fit, Muscular, Big
   and buff) on one shared cage, two axes (muscle from PP, fat from bodyweight), small steps inside each body. That is
   one more than GAME_DESIGN §38.2's approved "five builds to start" (it adds Fat and Fit, folds "average" into Fit's
   smallest step), so §38.2 needs the user's OK to change. **Cost per body:** one fitted clothes model + one fitted gear
   model to check in every lift pose and upload, a hand size, bar-contact numbers (squatBarRest, benchBarClear) and a
   neck mark. Six is the most Claude recommends for now; the shared cage makes adding more later cheap.
   Start the comparison with three (lean, heavy, muscular).
2. **Height and head [settled together in the prototype]:** the ~13% taller pass (legs x1.23) makes the head a smaller
   share of the body and moves away from the long-torso/short-legs Roblox look. The prototype shows the current height
   vs the extra height moved into the torso, with the head at 1.0 and 1.1, before the 84 re-made animations are
   uploaded (they aren't yet, so changing course is still cheap). Heads read mainly through trap/shoulder integration.
3. **Animations [context confirmed]:** the re-made set has IDENTICAL keyframe timing to the committed originals (all
   83 changed files checked; only poses and AuthoredHipHeight 2 -> 2.4 differ), so timing, triggers, lift mechanics,
   minigame timing and success/fail logic are preserved. No new animation changes without asking.
4. **Muscle and fat as separate parameters** need bodyweight to move; today only the admin panel moves it. The fat axis
   only shows on computer lifters until Bulk/Maintain/Cut (§38.3) is built.
5. **Muscle from PP grows fast early** (Skinny to Muscular in weeks today). Recommendation: hold the top looks for PP
   0.95-1.10+, as in §5.3.
6. **Per-lift muscle emphasis** (squat legs, bench chest, deadlift back): yes or no?
7. **Style consistency:** the gym follows a "realistic, bright and clean" style (References/Visual Style) while the
   bodies are cartoon. Already accepted in §38.7; worth checking in the prototype that the bodies sit well in the gym.

---

## 10. Comparison results

### 10.1 Prototype round 1 (2026-11-13) [EXPERIMENTAL, waiting for the user's pick]

User: "Yes, build prototype". Built headlessly in Blender; nothing uploaded, no game file or existing model changed.

**Files (all new):**
- `art/scripts/build_cartoon_body_04.py` -> `art/blender/CartoonBodies_04_Proto.blend` (Skinny, Heavy, Muscular on the
  current taller heights, plus the same three with the extra height in the torso; stand-in heads in "Preview").
- `art/scripts/check_proto_04_poses.py` (rigs the bodies with build_cartoon_rig_02.py's joints and automatic weights,
  poses them with the real animation files through gear_fit_03.py's pose_rig; saves nothing back).
- Pictures: `art/previews/Redesign_Proto_Compare_{Front,Back,Threequarter,Side,Silhouettes}.png` (current vs new, same
  cameras, light, stand-in head, backface culling), `Redesign_Proto_Height.png`, `Redesign_Proto_HeadSize.png`,
  `Redesign_Proto_PoseCheck.png`.

**How the new bodies are made:** each body is one smooth distance field. Forms melt into each other with a chosen
softness (pec into delt, delt over the arm, traps up the head's sides, belly into chest and hips); definition is
CARVED in as shallow grooves (sternum, pec edge, ab lines, glute fold) on the muscular build only; left and right
limbs stay separate surfaces; arms join the torso only at the shoulder, legs only at the hips. Every position follows
the skeleton's joint heights. Meshed with OpenVDB, thinned to 4,800 triangles, fold-checked.

**What changed (seen in the pictures):**
- No balls: the abs are grooves in one stomach, the glutes one mass with the thigh, the heavy belly part of the torso
  with love handles, the lats flow from the armpit to the waist.
- No flat ledge under the head on any build; the muscular traps climb the head's sides; the heavy build's round
  collar meets the head.
- Side views now differ by build (shallow lean torso, forward belly, deep muscular chest and upper back).
- No doll-joint shoulder knobs; no pinched knees or ankles; rounded shoe-like feet.

**Checks:** check_models.py **CHECK PASSED** (18 meshes, 45,600 triangles in the file); 0 folded edges on all six bodies
after the fold fix; posed in 9 moments (rest, squat bottom, bench at the chest, deadlift bottom, arms up, double
biceps, chest slap, belt tighten, crouch roar) without tearing.

**Budget:** body 4,800 + hands 2,800 (still the 1,400-triangle hands_03) = 7,600 per body (current: ~7,900-8,000).

**Height (Redesign_Proto_Height.png):** with the extra height in the torso and block-length legs, the bodies read
more like Roblox characters (long torso, short legs) and the head becomes a bigger share of the body. Choosing it
means re-making the animations again for that joint table (the scripts do it automatically, as for the taller pass)
before any upload; the taller-legs animations aren't uploaded yet.

**Head size (Redesign_Proto_HeadSize.png):** 1.1 changes little now that the shoulders wrap the head; 1.0 (the
player's normal head) is Claude's recommendation.

**Known issues found by this round (for the production step):**
1. **Shoulder stretch in raised-arm poses** (squat bar hold, arms up, double biceps): the trap and delt skin stretches
   into a sheet. Cause: automatic weights; needs tuned weight zones (traps on the torso, delts split between torso
   and arm), as any production body would.
2. **Self-contact moves clip on the wide builds:** in Chest Slap the hands sink into the heavy and muscular chests
   (as §8.1 predicted). Needs per-build hand targets (see §8).
3. A small dark notch where the muscular delt/pec groove meets the armpit.
4. Hands are still the 1,400-triangle set; a lighter, chunkier hand is a separate step.
5. **The prototype is NOT on a shared topology** (§6.2): it was built as distance fields to iterate the look fast.
   If the direction is approved, the production step either puts every build on one shared cage (best for the gear
   fitter and future builds) or keeps one mesh per build; that choice comes with the production plan.
6. Torso-tall variant can't be pose-checked until animations exist for its joint table.

**Decisions for the user:** keep this direction or change it; taller legs (now) or the extra height in the torso;
head 1.0 or 1.1; then the production plan (six bodies, shared topology, tuned weights, hands) before anything goes
into the game.

**[APPROVED 2026-11-13] Height goes in the torso** (user: "Height in the torso", after the round-1 pictures). The
new bodies use the TORSO_TALL joint table (build_cartoon_body_04.py): block-length legs (ankle 0.252, knee 1.178,
hips 2.0, HipHeight 2.0), waist 2.54, shoulder joint 4.38, elbow 3.51, wrist 2.59, neck 4.70 (torso about x1.35,
arms x1.2, legs x1.0). **Arms shortened [APPROVED 2026-11-13, user: "Yes fix the arms, legs are good"]:** x1.2 of
the block arm instead of x1.35 (elbow 3.40 -> 3.51, wrist 2.37 -> 2.59), so the hands no longer hang to mid-thigh on
the big-handed builds; prototype rebuilt (CHECK PASSED, 0 folds; long-arm version kept only as a scratch copy).
Consequences, none done yet:
- The 84 re-made taller-LEG animations (uncommitted, AuthoredHipHeight 2.4) no longer fit the chosen bodies; do not
  upload them. Because the legs are block length again, the committed originals (AuthoredHipHeight 2) already fit the
  legs and root moves; only arm/hand targets (bar, belt, chalk, chest) need re-making for the longer arms and torso.
- lifter_heights.py, the rig scripts, ClothesConfig (HipHeight, squatBarRest, benchBarClear, neck marks) and the gear
  fitter all follow the taller-leg table today; they move to this table in the production step.
- Head size and the direction itself are still open (Claude recommends head 1.0).

**Torso-tall pose check (2026-11-13, `art/previews/Redesign_Proto_PoseCheck_TorsoTall.png`):** the three torso-tall
bodies rigged on the TORSO_TALL joints and posed with the COMMITTED original animations (git HEAD copies in the
session scratchpad, AuthoredHipHeight 2; the repo's animation files were not touched). Same 9 moments as round 1.
- Legs and root moves fit as authored: feet stay on the floor in the squat, deadlift and crouch; no tearing.
- Same shoulder stretch as round 1 when the arms go up or back (squat bar hold, arms up): an automatic-weights issue,
  not a height one.
- Hand targets land wrong because the arms are longer: chest-slap hands reach the collar/face instead of the chest,
  belt-tighten hands sit below the belly instead of at the belt. Expected; these are the arm/hand re-makes listed above.
- At rest the hands hang to the upper thigh (longer arms); reads Roblox-like, worth a look in the gym.

**Dressed preview (2026-11-13, user: "the pure body is throwing me off"):** the torso-tall bodies dressed with
build_cartoon_clothes_02.py's own garment code (heights moved to the torso-tall table, quick automatic cut, no
hand fixing), stand-in block heads: `art/previews/Redesign_Proto_Dressed_{DefaultOutfit,Variety,PoseCheck}.png`.
Quick-cut flaws that production fitting fixes (not body problems): small holes in the skinny shorts, a tear at the
muscular tee's armpit, the tank top cut too narrow on the muscular build, a gap at the heavy tee's back hem.

**Gear on the new bodies (2026-11-13, shorter arms; user: "show me a example but with gear on"):** the gear session's
build_cartoon_gear_03.py run UNCHANGED (in memory, EXPORT = False, its pose checks reading the committed block
animations) on a scratch copy of the torso-tall bodies laid out like CartoonBodies_02.blend. No gear file, export or
.blend of the gear session was written. Pictures: `art/previews/Redesign_Proto_ShortArms_{Gear,GearPoses,Clothes,
Body}.png` (Clothes = the quick cut above, re-run on the shorter arms).
- Singlet, lever belt (CENTRAL on the back), knee sleeves and wrist wraps fit all three builds with no hand tuning
  and follow every pose: the fitter's "a redesigned body is a re-run" works.
- The v3 TEE does not yet fit the new shoulders: its sleeves stand off the shoulders like pads, skin shows between
  sleeve and body, and the tee pokes through the singlet's chest in jagged patches (muscular worst). The new bodies'
  traps/delts melt into one slope, where the old ones had a clear shoulder knob the fitter keys on. Production fix:
  tune the fitter's shoulder/yoke landmarks (gear session's tools; coordinate, don't edit from here).
- Pose relief hit its 0.05 cap on every item and build (the raised-arm shoulder stretch, issue 1 above).

### 10.2 Gear remade from the user's photos (2026-11-13) [EXPERIMENTAL, waiting for the user]

User: "Fix the gear, here are prime examples of how singlets, belts, knee sleeves, and wrist wraps are supposed to be
fitted. Study the photo closely and remake it closely", with 17 photos (a brand's catalogue shots of a singlet over a
tee and a lever belt; national-team lifters squatting and posing in singlets, belts, knee sleeves, wrist wraps). Our
gear keeps its own brand (CENTRAL, memory gear-brand-central); only the fit and construction were copied.

**What the photos show (observations):**
- Singlet over a fitted short-sleeve tee; the tee's crew neck shows above the singlet's front scoop. Front scoop deep
  (well below the collarbones), back a shallower U, both piped in the accent colour. Wide straps sitting ON TOP of
  the shoulders, the shoulder tops in the accent colour. Deep armholes. A narrow accent side panel from the armhole
  down to the hip. Short legs, about a third down the thigh, plain hem, skin-tight (on the heavy lifters it stretches
  over the belly). A logo on the chest under the scoop and one across the middle of the back.
- Belt: about 4 inches tall, thick, stiff: it stays a straight band and does NOT follow the body's curves; worn round
  the navel, OVER the singlet, pressing the fabric (and on big lifters the belly) in above and below it. Double
  stitched edges, a steel lever on the front (a little off centre in some shots), holes on the tongue.
- Knee sleeves: thick tubes centred on the knee, from the lower third of the thigh to just below the top of the calf;
  they round the knee into a near-cylinder. Bare skin between the singlet's hem and the sleeve.
- Wrist wraps: a thick wound band right over the wrist joint, from the base of the palm up the forearm, a logo and a
  thumb loop; far wider than the wrist.

**Built:** `art/scripts/build_cartoon_rig_04.py` -> `art/blender/CartoonBodies_04_Rigged.blend` (the new bodies rigged and
split into R15 parts, the layout the gear tools read) and `art/scripts/build_cartoon_gear_04.py` ->
`art/blender/CartoonGear_04_Proto.blend`: tee and singlet as smooth shells over the groove-free body field (singlet 0.04
outside the tee from the same field, so it cannot cut into it; tight on the legs), clean curved neck/strap/armhole
lines, accent panels on clean straight lines, piping from the rolled hems; v03's belt at the navel (a third of the way
hip -> shoulder) pressing the fabric in; v03's knee sleeve as a thicker, rounder tube on the knee; v03's wrist wrap moved
down over the joint. v03 (the gear session's) is used as a library and unchanged. Prototype only: no export, no upload.

**Hands (user: "for squat, the palms are open, deadlifts palm are open ... clapping the hands are phasing through each
other"):** the game already shows FISTS while gripping the bar and in belt tighten, double biceps, the roars
(HandShapeConfig); the earlier prototype pictures drew open hands everywhere, which was wrong. `art/scripts/
check_gear_04_poses.py` now draws the game's hand shapes, and prototypes a CONTACT FIX: in moves where the hands meet
something (claps, praying hands, fists together, palms on the chest, fists on the belt) each arm is bent by two-bone IK
so the hand ends on its contact point for that build (touching, not passing through). In the game that would be an
IKControl per arm driven by a per-move contact table: a game-code change, not built, needs a Studio test.

**Results (pictures `art/previews/Redesign_Gear04_{MeetGear,Clothes,LiftPoses,HandContacts}.png`):**
- Singlet over a black tee with the crew neck showing, deep front scoop and back U piped red, red straps over the
  shoulders, red side panels armhole -> hip, short plain legs; belt round the navel pressing the fabric in; knee sleeves
  on the knee with bare skin above; wraps over the wrist joint; new sneakers that cover the flat-topped feet.
- check_models.py CHECK PASSED on CartoonGear_04_Proto.blend (232 meshes) and CartoonBodies_04_Rigged.blend (45).
- Hands: fists in the lifts, belt tighten, biceps, roars. Contact fix (preview only): fists land on the belt either side
  of the lever; roar fists press together; clap and overhead-clap palms meet; chest-slap palms land on the chest;
  prayer hands meet (the animation's crossed forearms stay crossed).
- **PERFORMANCE WARNING:** full meet gear is ~10,400 triangles per lifter (tee ~2,700, singlet ~3,300, belt 1,036,
  sleeves 1,224, wraps 880, sneakers ~1,270) + the body 7,600 = ~18,000, over the §6.4 target (~10-11k dressed) and the
  approved 3,200 for gear. Production must thin it (tee ~1,200, singlet ~1,600, sleeves ~800) before any upload.
- Still rough: small crinkles at the tee's sleeve cuffs and where the straps meet the head; the knee-sleeve gap is
  narrow on the muscular build.

### 10.3 Gear v4 round 2 (2026-11-13): straps, fabric thickness, slimming [EXPERIMENTAL]

User: "slim it down and fix these ... the straps of the singlets are being flipped inside out and mixed around, and i
can see bodies are still phasing through the singlet ... the straps are morphing while keeping a thin layer causing a
crease look".
- **Cause 1, inside-out/creased straps:** the singlet was a paper-thin sheet with its edges folded inward; from most
  angles the back of the sheet showed. **Fix:** real fabric thickness (0.018, Solidify inward, the inside copy kept only
  along the openings) and a separate raised red binding strip along the neck and armholes (the photos' piping).
- **Cause 2, twisting straps / body through the singlet:** the straps followed the upper-arm bones; the body's own
  trap skin did too (automatic weights). **Fix:** the singlet follows only the torso and thigh bones; the body's skin
  (build_cartoon_rig_04.shoulder_weights) and the tee (hold_shoulder) are held by the torso inside the shoulder joint,
  fading to the arm at the joint. The straps' inside is smoothed where they climb the traps.
- **Slimmer:** the tee worn under the singlet is cut to what shows (sleeves, collar, round the straps) as its own piece
  ("TeeUnder"; the everyday tee stays whole); fewer points along every edge; belt 22 segments, knee sleeves 16x6, wraps
  12 round. Full meet gear ~6,600 triangles (was ~10,400): under-tee ~1,100, singlet ~2,600, belt 868, sleeves 648,
  wraps 672, sneakers ~750. With the body (7,600, of which hands 2,800) ~14,200: still over the ~10-11k target; the
  lighter hands (planned) and a thinner singlet are the next savings.
- check_models CHECK PASSED (CartoonGear_04_Proto.blend 242 meshes, CartoonBodies_04_Rigged.blend).
- **Left:** at the very top of a raise (arms straight overhead, double biceps) the tee sleeve still tears at the
  armpit: the one-joint R15 shoulder's limit; needs hand-tuned shoulder weights in production. The hand contact fix is
  still preview-only (game code + Studio test needed).

**Round 3, knee sleeves (2026-11-13; user: the sleeves "look compressed and small ... cant be floating with spaces
inbetween the knee and the sleeve. It needs to be a accessory, that morphs with the shape of the leg"):** each sleeve
is now a thick neoprene shell over the leg's own smoothed shape (thigh, kneecap, calf), outside 0.065 off the skin and
0.055 thick, so its inside hugs the skin (0.01) and its ends show the full thickness; from the lower thigh (knee +0.36)
to mid-shin (knee -0.42), smooth weights across the knee. Singlet legs shortened (crotch -0.06). ~1,150 triangles a
pair (was 648): full meet gear ~7,100. Picture `art/previews/Redesign_Gear04_KneeSleeves.png`. CHECK PASSED. The bare
strip between singlet and sleeve is narrow on the heavy and muscular builds (their crotch sits low).

**Round 4, knee sleeves (user: "they seem to thick, they need to be thinner and morph off the leg more", 4 close-up
photos):** outside 0.030 off the skin over the knee, 0.020 at the ends (they grip there), 0.020 thick; squat room cut to
0.012 (the full 0.05 had puffed the whole sleeve up at rest). The kneecap and calf now show through. Markings as the
photos: the logo low on the front in the accent colour, two short accent stripes angled toward the back under the top
edge and over the bottom edge. CHECK PASSED; picture `Redesign_Gear04_KneeSleeves.png` (replaced).

**[APPROVED 2026-11-13] Gear v4 look** (user: singlet round 2 "Look about right", knee sleeves round 4 "Yes looks
right"): singlet over a black tee with piped edges and torso-held straps; belt at the navel; knee sleeves thin and snug
from the lower thigh to mid-shin. Still open before production: the armpit tear at extreme arm raises, the in-game hand
contact fix, the triangle budget (~7,100 full gear + body), uploads.

---

## 11. Production plan: new bodies and gear into the game [PLAN, 2026-11-13, each phase waits for the user's OK]

What is approved so far: cartoon direction, height in the torso (TORSO_TALL, arms x1.2), the gear v4 look. Everything
below moves the prototype into the game in phases. Each phase ends with pictures/checks and a stop for the user's OK.
Nothing is uploaded without the user's explicit OK. Nothing is committed without being asked.

### Phase 0: decisions and a safe checkpoint (user)
**Answered 2026-11-13 [APPROVED]:** six bodies; two axes; one shared base mesh; v03 gear/clothes NOT uploaded
(kept as reference); head 1.0 (recommended, not objected to). GAME_DESIGN §38.2 updated. Still open: the checkpoint
commit (item 6).
1. **Body count:** six sculpted bodies (Skinny, Skinny-fat, Fat, Fit, Muscular, Big and buff) vs GAME_DESIGN §38.2's
   approved five (adds Fat and Fit, folds "average" into Fit). Claude recommends six; §38.2 changes only on the OK.
2. **Two physique axes** (§5: muscle level from PP, fat from bodyweight over a per-level lean weight; top looks held
   for PP 0.95-1.10+; per-lift emphasis yes/no). Needs the OK before LifterBuild changes.
3. **Head size 1.0** (the player's own head unchanged; Claude's recommendation).
4. **One shared base mesh for all six bodies** (one topology, each build a reshaped copy: the gear fitter, clothes and
   future builds stay cheap) vs one separate mesh per build (simpler now, every new build costs a full refit).
   Recommended: shared base.
5. **The gear session's v03 gear/clothes (fitted to the CURRENT bodies, 11 uploads waiting):** don't upload them if
   the new bodies go ahead (they'd be thrown away); keep them as reference.
6. **Checkpoint commit** of today's work before production starts (CLAUDE.md: commit a working version before a major
   change). Many files are uncommitted, including the gear session's; the user decides what goes in.

### Phase 1: skeleton and animations
- `lifter_heights.py`: a third table, TORSO (legs x1.0, torso x1.35, arms x1.2, HipHeight 2.0), chosen like
  `LIFTER_RIG` today; arms get their own factor (today ARM = TORSO).
- Re-make all animations from their scripts for that table (`station_animations.py` and the celebration, emote,
  entrance scripts). AuthoredHipHeight becomes 2.0; keyframe timing stays identical (as in the taller pass). Bar,
  belt, chalk and chest hand targets follow the new arm reach.
- The uncommitted taller-leg set (AuthoredHipHeight 2.4) is replaced. Keep a copy outside the game folders first.
- **Check:** Blender pose check of every station rep and the hardest moment of each animation on all bodies; the
  keyframe-time diff against the originals must stay identical.

### Phase 2: production bodies
- Six bodies built from the prototype's distance-field method on the shared base (if approved in Phase 0), the
  anatomy checklist in §4, the small in-between steps in §5.5 as per-part width/depth scales in code.
- **Hand-tuned shoulder weights** (the armpit tear at full arm raises, §10.3): traps and upper chest held by the torso
  (started in `build_cartoon_rig_04.shoulder_weights`), the deltoid split torso/arm, checked in arms-up, overhead clap,
  double biceps and the squat bar hold.
- **Lighter hands:** about 600 triangles each instead of 1,400 (open hand plus the Fist, Point and ThumbsUp swaps),
  sized per build (prototype 1.05 / 1.30 / 1.50).
- **Budget per body:** about 5,500 with hands (today 7,600).
- **Check:** check_models.py CHECK PASSED, 0 folds, the pose check, front/back/side/three-quarter pictures with
  backface culling, then the user's look.

### Phase 3: clothes and gear on every body (v04 pipeline)
- Run `build_cartoon_gear_04.py` on all six bodies: tee and under-tee, singlet, belt, knee sleeves, wrist wraps,
  sneakers (built). Still to build the v04 way: long sleeve, tank, shorts, joggers, squat suit, deadlift suit, bench
  shirt, knee wraps.
- **Budgets:** under-tee ~800, singlet ~1,600, belt ~700, knee sleeves ~800 a pair, wraps ~500, sneakers ~600.
  That puts full meet gear at about 5,000; with the body, a fully geared lifter lands about 10,500, the §6.4 target.
- Game-format export (one skinned mesh per R15 part, colour keys, the CENTRAL logo as the one tinted decal). Also
  test ONE skinned mesh per item instead of per part (fewer draw calls) in Studio; switch if it works.
- **Check:** clearance and pose checks on every item, every build, rest and the lift poses; the user's look.

### Phase 4: game code (needs Studio tests; written incrementally, existing game kept playable)
- `ClothesConfig`: HipHeight 2.0; per-body neckMark, squatBarRest, benchBarClear for the six bodies; the asset ids.
- `HandShapeConfig`: hand sizes and the new shapes model.
- `LifterBuild` (+ ComputerLifters, MeetFigures, LocalMeetService, MockMeetService): six bodies and the two axes,
  only after the Phase 0 OK; GAME_DESIGN §38 updated to match.
- `LifterBodyService` / `WornGearFit.dressCartoon`: with gear on, the under-tee replaces the tee.
- `StationPoseAnimator`, `StationPoses`, `MeetLiftAnimation`: bar heights from the new body marks.
- **Hand contact fix:** a per-move contact table (claps, prayer, fists together, palms on the chest, fists on the
  belt) and an IKControl per arm that puts the hands on their contact point for each build (the preview's rule).
- Computer lifters wear random gear (memory: NPC lifter gear) on the new bodies.

### Phase 5: uploads (only on the user's OK, one batch at a time)
- Six bodies, the hands model, a clothes and a gear model per body, the logo image, every re-made animation; then the
  ids into ClothesConfig / WornGearConfig / HandShapeConfig / the animation configs.
- The old cartoon bodies and the block-rig animations stay until the new ones pass Phase 6.

### Phase 6: Studio and phone tests
- Studio play tests: the gym, every station lift, a meet with computer lifters, celebrations, emotes, the gear toggle,
  the clothes menu; two-player test; `tools/studio/PerformanceAudit.luau`; Rojo checksums (memory: Rojo misses edits
  during Play).
- The user checks the frame rate on a phone (Claude can't measure it).
- Then DEVELOPMENT_STATUS.md (coordinated with the gear session, which owns it today) and the switch-over.

**Order and size:** Phase 0 is decisions only. Phases 1 and 2 can run at the same time (skeleton/animations vs body
sculpting), then 3, 4, 5, 6 in order. Each phase is a session's worth of work or more; Phase 4 is the riskiest (game
code that needs Studio).
