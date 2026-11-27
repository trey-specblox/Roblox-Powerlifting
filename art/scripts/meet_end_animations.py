# End-of-meet scene (2026-11-25): the lifter's coach walks up to the lifter's right, turned 36-45 deg toward him, and
# lands his near (LEFT) hand open and flat on the lifter's upper back by the right shoulder blade, fingers toward the
# spine. Fat (default), Benchamin and Sumo REACH with the arm close to its relaxed shape (elbow ~23-31 deg, the shoulder
# swinging the arm out and round behind the lifter, the coach about an arm's length off: the user's elbow note);
# Squatavious, short, stands close behind the shoulder and reaches UP to the mid back (elbow ~52 deg). Two small pats
# (lift and land), the hand rests while he talks (head turned to the lifter, small nods), then it comes away and hangs.
# His right hand hangs relaxed the whole time (no clipboard: the game hides it). The lifter gets no new animation.
#
# One clip per coach body (each solved on that body's own skeleton, so the arm bends the same way on every coach):
#   MeetEnd_Coach_BackPat              the gym coach's default staff body: the Fat build (MeetFigures.build "Coach"
#                                      without a look -> LifterBuild.BuildRules.Spotter = "Fat"; the Gym Owner keeps it)
#   MeetEnd_Coach_BackPat_Squatavious  short (shoulders 2.87 up): pats the MID back at his own reach, never the belt
#   MeetEnd_Coach_BackPat_Benchamin    the BigBuff skeleton (wide, splayed arms)
#   MeetEnd_Coach_BackPat_Sumo         long arms, high hips
# All 9.0 s, NOT looped, Action priority. Pats land at PATS; the hand rests to RELEASE[0]; hangs from RELEASE[1].
# (MeetCoachLook copies the platform coach's joints onto the chosen coach's copy each frame: the game plays the chosen
# coach's version on the platform coach and stands the platform coach where PLACEMENT says for that version.)
#
# HOW: the body is joint turns only (the Waist leans and turns toward the lifter, the Neck turns and nods; legs and root
# untouched, so the feet never move). The left arm is the approved exact two-bone solve (entrance_animations.ik_arm,
# the elbow pointed where it is told: down), on THIS body's joints (S.JOINTS swapped for the body's rest joints, from
# art/blender/CartoonBodies_05_Rigged.blend / CoachBodies_01_Rigged.blend), and in contact the hand is turned palm-to-
# back (S.hand_frame) and the arm solved again for the wrist (Hype._palm_solve's method).
#
# PLACEMENT (the game): the coach's root stands `side` to the lifter's right (+X of the lifter's root), `back` behind it
# (+Z), turned `yaw` degrees toward the lifter (about the vertical, from facing the same way), both on the floor:
#   coachRoot = lifterRoot * CFrame.new(side, 0, back) * CFrame.Angles(0, math.rad(yaw), 0)   (then HipHeight)
# measured per lifter build by `pairqa` on the real bodies (the lifter in the meet outfit, the coach in his own clothes):
# the palm ON the outer layer, the bodies a small gap apart, nothing ever inside the other.
#
#   blender -b --factory-startup --python art/scripts/meet_end_animations.py
#       writes art/animations/MeetEnd_Coach_BackPat*.rbxmx (all four)
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/meet_end_animations.py -- pairqa <out dir>
#       READ-ONLY: each version's coach with each lifter build; fits side/back/yaw, measures every keyframe, pictures.
#       env PAIR_VERSIONS=MeetEnd_Coach_BackPat,...  PAIR_LIFTERS=Skinny,...  PAIR_PICTURES=Skinny,Fat,BigBuff
# Check each coach on his own body with art/scripts/anim_qa.py. Publish with upload_animations.py (ask the user first).
import importlib.util
import math
import os
import sys

from mathutils import Matrix, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
ROOT = os.path.dirname(os.path.dirname(_HERE))
LENGTH = 9.0
PATS = (0.85, 1.20)            # the two pats land (seconds)
RELEASE = (8.00, 8.70)         # the hand leaves the back / hangs again
LIFTERS = ("Skinny", "SkinnyFat", "Fit", "Fat", "Muscular", "BigBuff")

# Rest joints (rig-local Roblox studs from the floor: x = the body's left is -x, y up, z back), from the rigs.
BODY_JOINTS = {
    "Fat": {"HumanoidRootNode": (0, 3.0, 0), "LowerTorso": (0, 2.0, 0), "UpperTorso": (0, 2.54, 0),
            "LeftUpperArm": (-1.0, 4.38, 0), "LeftLowerArm": (-1.42, 3.287, 0), "LeftHand": (-1.42, 2.148, 0),
            "LeftUpperLeg": (-0.5, 2.0, 0), "LeftLowerLeg": (-0.5, 1.0, 0), "LeftFoot": (-0.5, 0.252, 0),
            "Neck": (0, 4.7, 0)},
    "Benchamin": {"HumanoidRootNode": (0, 3.0, 0), "LowerTorso": (0, 2.0, 0), "UpperTorso": (0, 2.54, 0),
                  "LeftUpperArm": (-1.05, 4.38, 0), "LeftLowerArm": (-1.66, 3.287, 0), "LeftHand": (-1.66, 2.148, 0),
                  "LeftUpperLeg": (-0.5, 2.0, 0), "LeftLowerLeg": (-0.5, 1.0, 0), "LeftFoot": (-0.5, 0.252, 0),
                  "Neck": (0, 4.7, 0)},
    "Squatavious": {"HumanoidRootNode": (0, 2.192, 0), "LowerTorso": (0, 1.192, 0), "UpperTorso": (0, 1.582, 0),
                    "LeftUpperArm": (-1.06, 2.8701, 0), "LeftLowerArm": (-1.6112, 2.1701, 0),
                    "LeftHand": (-1.6112, 1.4701, 0), "LeftUpperLeg": (-0.5, 1.192, 0), "LeftLowerLeg": (-0.5, 0.672, 0),
                    "LeftFoot": (-0.5, 0.252, 0), "Neck": (0, 3.142, 0)},
    "Sumo": {"HumanoidRootNode": (0, 3.902, 0), "LowerTorso": (0, 2.902, 0), "UpperTorso": (0, 3.242, 0),
             "LeftUpperArm": (-0.8096, 4.3481, 0), "LeftLowerArm": (-1.1264, 2.9481, 0), "LeftHand": (-1.1264, 1.4981, 0),
             "LeftUpperLeg": (-0.5, 2.902, 0), "LeftLowerLeg": (-0.5, 1.352, 0), "LeftFoot": (-0.5, 0.252, 0),
             "Neck": (0, 4.602, 0)},
}

# The lifter's upper back where the palm goes (lifter's root frame, his root 3.0 up): by the right shoulder blade; its
# outward normal there (turned toward his right as the back rounds), the fingers' way along it (to the spine and up).
BACK_NORMAL = Vector((0.30, 0.03, 0.95)).normalized()
FINGERS = Vector((-0.9, 0.42, 0.0))
PALM_X = 0.40                  # (pairqa) the palm's middle this far right of the lifter's spine (Fit), scaled by each
#                                build's back width (UpperTorso half widths 0.71-1.20), so it sits on the shoulder blade
#                                of every build and the coach stands as close to a slim lifter as to a big one
BACK_HALF = {"Skinny": 0.71, "SkinnyFat": 0.79, "Fit": 0.91, "Fat": 1.10, "Muscular": 1.02, "BigBuff": 1.20}
NOMINAL_YAW = 42.0             # the yaw each clip's palm turn is written for (pairqa picks 38-45 per lifter build)

# Per version: the body, its hip height, the left hand's centre resting on the back from the LEFT SHOULDER JOINT in the
# coach's root frame (x left -, y up, z back +; the coach faces -z), and the elbow's pull (chest frame: down, a touch
# out). Written so the arm reads forward-down / elbow bent ~90 deg and pointing down / forearm forward, and the hand at
# the lifter's upper back (~4.0 up) - Squatavious's at the mid back (~3.6 up), his reach up from 2.87.
# (Scanned 2026-11-25, scan of hand spot x elbow pull x finger way: with the hand straight ahead of the shoulder the
# forearm points INTO the back and the wrist must turn 80-108 deg to lay the palm on it; with the hand ahead and to
# the left, the forearm runs diagonally across the back toward the spine and the wrist turns 40-60 deg, the least
# for these bodies. Squatavious reaches UP to the back: his upper arm comes forward level, elbow under the line,
# fingers up.)
# (2026-11-25, user on Sumo: "the arms are just bending unnaturally looking like the arm is getting pinched until it
# creases ... keep the arm's shape but just move it to pat the lifter's back") Fat, Benchamin and Sumo now REACH: the
# arm stays close to its relaxed shape (elbow bent `bend` deg from straight, ~30-35; it was 96-116 and creased on all
# three) and the shoulder swings it out to the coach's left and round behind the lifter; the coach stands about an
# arm's length off. "reach": (degrees left of his forward, degrees up) of the shoulder-to-hand line. A scan (hand way x
# yaw x finger way x elbow pull, the coach kept behind the lifter's shoulder line) gave the least wrist turn, 23-31 deg,
# with the arm out 55 deg left of forward and 10 deg down at yaw 40, fingers toward the spine. Squatavious keeps his bent
# reach UP (52 deg at rest, no crease: his short arm is thick).
VERSIONS = {
    "MeetEnd_Coach_BackPat": {"body": "Fat", "hip": 2.0, "reach": (55.0, -10.0), "bend": 34.0,
                              "pull": (-0.3, -1.0, 0.0), "fingers": (-1.0, 0.1, 0.0), "side": (85.0, -50.0)},
    "MeetEnd_Coach_BackPat_Benchamin": {"body": "Benchamin", "hip": 2.0, "reach": (55.0, -10.0), "bend": 34.0,
                                        "pull": (-0.3, -1.0, 0.0), "fingers": (-1.0, 0.1, 0.0), "side": (85.0, -50.0)},
    "MeetEnd_Coach_BackPat_Sumo": {"body": "Sumo", "hip": 2.902, "reach": (55.0, -10.0), "bend": 34.0,
                                   "pull": (-0.3, -1.0, 0.0), "fingers": (-1.0, 0.1, 0.0), "side": (85.0, -50.0)},
    "MeetEnd_Coach_BackPat_Squatavious": {"body": "Squatavious", "hip": 1.192, "on": (-0.55, 0.74, -1.12),
                                          "pull": (-0.3, -1.0, 0.15), "fingers": (-0.3, 0.95, 0.0),
                                          "mid": (-0.75, -0.75, -0.75)},
}

# ---------------- the walk together (user 2026-11-25: "if the lifter made podium let the cutscene have the lifter and
# coach walk together, with the coach having the same arm position of the coach patting the lifter"): after the pat
# and the talk the coach keeps the hand resting on the lifter's upper back and they walk side by side, the coach at the
# lifter's right, out to the front of the stage. LOOPED, Action priority, UPPER BODY ONLY: the Waist (the chest turned
# to the lifter), the Neck and the LEFT arm; the game's walk cycle plays the legs, root and right arm underneath
# (ComputerLifters.walkBody, LocalMeetConfig.ComputerLifters.WalkAnimationId: Roblox's stock R15 walk, not loadable
# here; pairqa puts the game's own Entrance_Walk_Swagger under both figures instead: the nearest plain walk, its arm
# swing 32 deg as big as the stock walk's or bigger, so the lifter's right arm swinging back is tested at least as hard).
# Both roots face the walk (yaw 0); the BackPat rest arm (same elbow bend, same palm on the back) turned by the yaw the
# coach stood at (WALK_FROM_YAW) so it still points at the lifter's back from his right.
WALK_LENGTH = 4.0
WALK_TURN = 18.0               # the chest turned toward the lifter (degrees, at the Waist)
WALK_FROM_YAW = 40.0
# (2026-11-25, main session: option (b)) the LowerTorso is keyed too: the hips held square to the walk (no hip twist or
# side sway from the walk can swing the hand off the lifter's back), with a gentle bob of its own (WALK_BOB)
WALK_PARTS = ("LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand")
WALK_BOB = (0.035, 2.0)        # (studs down at the dip, dips per second: two steps a second at the meet walk's 9 st/s)
WALK_UNDER = "Entrance_Walk_Swagger"
# "yaw": the BackPat hand spot turned by this much (the BackPat yaw was 36-45; less turns the arm to point more forward,
# so the coach walks a little further back and the forearm crosses BEHIND the lifter's right arm swinging back: at the
# full BackPat turn the swinging arm met the forearm, 0.06-0.48 deep, pairqa walk 2026-11-25); "raise": degrees the
# reaching arm is lifted (with the hips keyed the forearm clears the swing at -2: the palm ~3.9 up, on the flatter
# part of the upper back, rides closer than at +6 / 4.2 up on the back's curve toward the neck).
WALK_VERSIONS = {
    "MeetEnd_Coach_WalkPat": {"from": "MeetEnd_Coach_BackPat", "yaw": 22.0, "raise": -2.0, "elbow": 31.0},
    # (Squatavious, short: walking just behind the lifter's right side, his arm across the lifter's back, the hand on
    #  the mid back left of the spine, just above the belt, wrist ~55 deg. Tried and dropped: (1) his hand up flat on
    #  the right side of the back from behind: the wrist bent ~100 deg, "a hand pushed up onto the back"; (2) walking
    #  beside with the arm straight out (wrist 25-39 deg): the lifter's right arm swinging back went through his arm and
    #  chest, 0.27-0.42 deep; (3) further across, wrist 46-49: his chest met a BigBuff lifter's back. The palm laid on
    #  the back's left side (normal turned to the lifter's left) so the forearm lies more along the back.)
    "MeetEnd_Coach_WalkPat_Squatavious": {"from": "MeetEnd_Coach_BackPat_Squatavious", "reach_dir": (35.0, 15.0),
                                          "normal": (-0.45, 0.03, 1.0), "palm_scale": -0.9, "elbow": 40.0},
    "MeetEnd_Coach_WalkPat_Benchamin": {"from": "MeetEnd_Coach_BackPat_Benchamin", "yaw": 22.0, "raise": -2.0,
                                        "elbow": 23.0},
    "MeetEnd_Coach_WalkPat_Sumo": {"from": "MeetEnd_Coach_BackPat_Sumo", "yaw": 22.0, "raise": -2.0, "elbow": 31.0},
}
# Measured by pairqa PAIR_WALK=1 (2026-11-25, D:/ClaudeScratch/backpat/walk/final_*): {version: {lifter build: (side,
# back)}}, both roots facing the walk (yaw 0), the coach's LowerTorso keyed by the clip (hips square, so the walk under
# him cannot swing the hand), the lifter on the full Swagger walk. Over 8 lifter x 4 coach walk phases: never a sink, no
# body inside the other; the palm 0.001-0.15 off the back (Squatavious 0.004-0.083); within 0.05 for 12-20 of the 32
# phase pairs (Squatavious 20-32): what is left is the LIFTER's own walk (his chest turning +-9 deg, his bob) moving
# his back under the still hand.
WALK_PLACEMENT = {
    "MeetEnd_Coach_WalkPat": {
        "Skinny": (3.704, 1.045), "SkinnyFat": (3.749, 1.080), "Fit": (3.840, 1.188),
        "Fat": (3.879, 1.215), "Muscular": (3.890, 1.245), "BigBuff": (3.970, 1.331)},
    "MeetEnd_Coach_WalkPat_Squatavious": {
        "Skinny": (1.723, 1.867), "SkinnyFat": (1.681, 1.908), "Fit": (1.625, 1.972),
        "Fat": (1.597, 2.045), "Muscular": (1.579, 2.033), "BigBuff": (1.484, 2.118)},
    "MeetEnd_Coach_WalkPat_Benchamin": {
        "Skinny": (3.839, 1.057), "SkinnyFat": (3.885, 1.093), "Fit": (3.987, 1.209),
        "Fat": (4.019, 1.236), "Muscular": (4.037, 1.266), "BigBuff": (4.112, 1.355)},
    "MeetEnd_Coach_WalkPat_Sumo": {
        "Skinny": (4.064, 1.185), "SkinnyFat": (4.107, 1.224), "Fit": (4.184, 1.310),
        "Fat": (4.240, 1.345), "Muscular": (4.223, 1.370), "BigBuff": (4.303, 1.455)},
}
WALK_PLACEMENT_TWIST = WALK_PLACEMENT    # (the coach's hips are keyed now: one table for any walk under him)
GAP_REACH = [0.8, 0.6]                   # (pairqa) how far the body gaps are looked for (walk_talk_qa: further)
WALK_EXTRA_BACK = {}                     # {(version, lifter build): studs}: a pair moved further back by hand (none)

# ---------------- TALKING WITH HIS BODY (user 2026-11-26, after the game test: "the coach should be walking with the
# lifter saying this with his arm patting his back ... you could add the realism animation making it look like the
# coach is talking through motions"; "the coach is too close"). New clips, the BackPat / WalkPat ones kept as they are:
#   MeetEnd_Coach_TalkPat[...]   standing: the BackPat start (two pats 0.85 / 1.20 s), then the hand rests on the back
#                                with a small pat now and then (TALK_REST_PATS) while the free RIGHT hand, the head and
#                                a little of the chest talk (gestures 1.4-7.6 s); the hand comes away by RELEASE. 9.0 s.
#   MeetEnd_Coach_WalkTalk[...]  walking beside the lifter (both facing the walk): the near arm round behind him, the
#                                open hand on his shoulder blade with small pats, the free hand and head talking. Upper
#                                body only on top of the game's walk (legs); 8.0 s LOOPED.
# The free hand is OPEN throughout (rule 8: no fist without the game's hand swap; the "big word" is an open-hand shake).
# Gestures are written from the right shoulder in the chest's frame, in units of the arm's length (so they read the
# same on short Squatavious and long-armed Sumo), and kept in front of each body's own chest/belly (TALK_FRONT, measured
# on the rest bodies with their clothes, 2026-11-26) by TALK_CLEAR. The wrist only rolls (palm up / down) and flexes a
# little on top of the forearm's own line: no wrist pointing the hand somewhere the forearm is not.
TALK_LENGTH = 9.0
TALK_REST_PATS = (2.95, 4.75, 6.45)     # standing: the small pats while he talks (1.5-2.5 s apart)
TALK_PAT_LIFT = 0.085                   # how far the hand lifts off the back for them (studs, along the back's normal)
WALKTALK_LENGTH = 8.0
WALKTALK_PATS = (1.45, 3.35, 5.15, 7.05)
TALK_CLEAR = 0.34                       # the hand's centre kept this far in front of his own chest / belly
# the most-forward point of each body's front (z, coach root frame, -z = in front) at each height, right half, at rest
TALK_FRONT = {
    "Fat": [(2.0, -0.60), (2.2, -0.79), (2.4, -0.87), (2.6, -0.98), (2.8, -1.0), (3.0, -1.0), (3.2, -0.94),
            (3.4, -0.88), (3.6, -0.75), (3.8, -0.67), (4.0, -0.62), (4.2, -0.53), (4.4, -0.50)],
    "Squatavious": [(1.2, -0.50), (1.4, -0.55), (1.6, -0.51), (1.8, -0.50), (2.0, -0.51), (2.2, -0.56), (2.4, -0.71),
                    (2.6, -0.77), (2.8, -0.76), (3.0, -0.58), (3.2, -0.39)],
    "Benchamin": [(2.0, -0.44), (2.4, -0.50), (2.8, -0.48), (3.2, -0.45), (3.4, -0.61), (3.6, -0.70), (3.8, -0.77),
                  (4.0, -0.80), (4.2, -0.82), (4.4, -0.73)],
    "Sumo": [(2.4, -0.31), (2.8, -0.36), (3.0, -0.46), (3.4, -0.40), (3.8, -0.49), (4.0, -0.55), (4.2, -0.61),
             (4.4, -0.58)],
}
# The free hand's poses: (x, y, z) from the right shoulder joint, chest frame (x + = his right, y up, z + = behind;
# x and y in torso lengths, z in arm lengths), the wrist's roll (deg about the hand's long axis; - = palm turning
# up) and flex (deg; + = back).
TALK_POSES = {
    "ready_low": ((-0.04, -0.70, -0.34), -15.0, 0.0),   # forearm forward at the belly, palm in: the listening hand
    "ready": ((-0.08, -0.45, -0.48), -20.0, 5.0),       # raised a little, about to say something
    "point": ((-0.26, -0.22, -0.74), 30.0, -5.0),       # open hand out at the lifter, palm angled down
    "point2": ((-0.20, -0.32, -0.70), 20.0, 0.0),       # a smaller one, lower
    "chop": ((-0.06, -0.28, -0.70), 0.0, 8.0),          # the hand on its edge, fingers forward
    "palm": ((-0.22, -0.30, -0.72), -72.0, 14.0),       # open palm up: "that's it"
    "shake": ((-0.02, -0.24, -0.64), 38.0, -6.0),       # palm down-in, the hand shaken on a big word
}
# (standing, short Squatavious is close behind the lifter's right shoulder and turned 38-45 deg to him: his forward
#  IS the lifter, and the point at 2.3 s went into a Muscular / BigBuff lifter's arm, pairqa overlap 0.125. His hand
#  talks out to his own right front instead: x moved this far right (torso lengths), the reach shortened.)
#  The chest's small forward beats are left out for him too: they took his chest to 0.09 from a BigBuff lifter.
TALK_TWEAK = {("stand", "Squatavious"): {"dx": 0.34, "far": 0.82, "lean": 0.0}}
TALK_PULL = (0.38, -1.0, 0.28)          # the talking arm's elbow: down, a little out and back (chest frame, right side)
# (time, pose) keys of the free hand ("hang" = hanging at his side as in BackPat) and the beats on top of them:
# (time, kind, size): push (a little toward the lifter), chop (down), open (a small lift of the open palm), shake.
TALK_KEYS = {
    "stand": [(0.0, "hang"), (1.40, "hang"), (1.85, "ready"), (2.05, "point"), (2.55, "point"), (2.85, "ready_low"),
              (3.10, "chop"), (3.78, "chop"), (4.05, "ready"), (4.40, "palm"), (5.05, "palm"), (5.35, "ready_low"),
              (5.65, "shake"), (6.30, "shake"), (6.55, "point2"), (7.00, "point2"), (7.30, "ready_low"),
              (7.60, "ready_low"), (8.30, "hang"), (TALK_LENGTH, "hang")],
    "walk": [(0.0, "ready_low"), (0.55, "ready_low"), (0.85, "point"), (1.35, "point"), (1.60, "ready"),
             (1.80, "chop"), (2.45, "chop"), (2.70, "ready_low"), (2.95, "palm"), (3.55, "palm"), (3.85, "ready"),
             (4.25, "shake"), (4.85, "shake"), (5.10, "ready_low"), (5.35, "point2"), (5.85, "point2"),
             (6.10, "ready"), (6.40, "palm"), (6.95, "palm"), (7.30, "ready_low"), (WALKTALK_LENGTH, "ready_low")],
}
TALK_BEATS = {
    "stand": [(2.30, "push", 1.0), (3.28, "chop", 1.0), (3.58, "chop", 0.8), (4.70, "open", 1.0),
              (5.95, "shake", 1.0), (6.78, "push", 0.7)],
    "walk": [(1.10, "push", 1.0), (1.98, "chop", 1.0), (2.28, "chop", 0.8), (3.22, "open", 1.0), (4.55, "shake", 1.0),
             (5.60, "push", 0.7), (6.68, "open", 0.7)],
}
# the head: (time, nod deg, tilt deg) bumps - nods on the beats, a tilt on the open palm, and a couple of his own
TALK_HEAD = {
    "stand": [(1.55, -4.0, 0.0), (2.30, -6.0, 0.0), (3.28, -5.0, 0.0), (3.58, -3.0, 0.0), (4.70, -3.0, 5.0),
              (5.95, -6.0, 0.0), (6.78, -4.0, -3.0), (7.40, -3.0, 0.0)],
    "walk": [(0.30, -3.0, 0.0), (1.10, -6.0, 0.0), (1.98, -5.0, 0.0), (2.28, -3.0, 0.0), (3.22, -3.0, 5.0),
             (4.55, -6.0, 0.0), (5.60, -4.0, -3.0), (6.68, -3.0, 4.0), (7.50, -3.0, 0.0)],
}

TALK_VERSIONS = {
    "MeetEnd_Coach_TalkPat": {"from": "MeetEnd_Coach_BackPat"},
    "MeetEnd_Coach_TalkPat_Squatavious": {"from": "MeetEnd_Coach_BackPat_Squatavious"},
    "MeetEnd_Coach_TalkPat_Benchamin": {"from": "MeetEnd_Coach_BackPat_Benchamin"},
    "MeetEnd_Coach_TalkPat_Sumo": {"from": "MeetEnd_Coach_BackPat_Sumo"},
}
for _n, _s in TALK_VERSIONS.items():
    VERSIONS[_n] = dict(VERSIONS[_s["from"]], talk=True)

# The walk beside (user 2026-11-26: "the coach is too close"): both roots face the walk; the coach at the lifter's right,
# a clear gap between the bodies (WALK_GAP, everything but his near arm, his free arm's gestures and both walks'
# swinging arms and legs included), no more than WALK_MAX_BACK behind. His near arm goes out from the shoulder and
# round behind the lifter's shoulder, the elbow pointing down and a little back (the arm close to its relaxed
# bend, swung from the shoulder), the open hand on the shoulder blade. (Elbow pointing back: the wrist had to turn
# 65 deg to lay the palm on the back; pointing down it turns 33-37.) Per version: "hand" = the hand's centre from
# the turned left shoulder (coach root frame: x left -, y up, z back +), "pull" = where the elbow points (chest frame).
WALK_GAP = 0.35
WALK_MAX_BACK = 0.70
WALKTALK_TURN = 18.0
WALKTALK_PARTS = WALK_PARTS + ("RightUpperArm", "RightLowerArm", "RightHand")
WALKTALK_VERSIONS = {
    "MeetEnd_Coach_WalkTalk": {"body": "Fat", "hip": 2.0, "hand": (-2.20, -0.38, 0.12), "bend": 30.0,
                               "pull": (0.0, -1.0, 0.4)},
    # (short Squatavious: his arm out to his left and UP to the lifter's mid back, straighter (bend 20), the elbow
    #  down and back; side set by the gap (fit_gap) rather than by where the palm lands, his chest turned further;
#  bend 20 left 0.02 of reach: the chest's talking moves straightened the arm)
    "MeetEnd_Coach_WalkTalk_Squatavious": {"body": "Squatavious", "hip": 1.192, "hand": (-1.354, 0.634, 0.119),
                                           "bend": 32.0, "pull": (0.0, -1.0, 0.4), "turn": 28.0, "fit_gap": 0.40},
    "MeetEnd_Coach_WalkTalk_Benchamin": {"body": "Benchamin", "hip": 2.0, "hand": (-2.20, -0.38, 0.12), "bend": 30.0,
                                         "pull": (0.0, -1.0, 0.4)},
    "MeetEnd_Coach_WalkTalk_Sumo": {"body": "Sumo", "hip": 2.902, "hand": (-2.60, -0.30, 0.12), "bend": 30.0,
                                    "pull": (0.0, -1.0, 0.4)},
}
for _n, _s in WALKTALK_VERSIONS.items():                 # (env WALKTALK_<Body>_HAND / _PULL = "x,y,z": trials)
    for _k in ("hand", "pull"):
        _e = os.environ.get("WALKTALK_%s_%s" % (_s["body"].upper(), _k.upper()))
        if _e:
            _s[_k] = tuple(float(c) for c in _e.split(","))
    if os.environ.get("WALKTALK_%s_BEND" % _s["body"].upper()):
        _s["bend"] = float(os.environ["WALKTALK_%s_BEND" % _s["body"].upper()])
# Measured by pairqa PAIR_WALKTALK=1 WALKTALK_DENSE=1 (2026-11-26, D:/ClaudeScratch/talk/walk_final, walk_sq3): {version:
# {lifter build: (side, back)}}, both roots facing the walk; WALK_PICTURES_ONLY=1 re-renders from it.
WALKTALK_PLACEMENT = {
    "MeetEnd_Coach_WalkTalk": {
        "Skinny": (3.900, 0.407), "SkinnyFat": (3.948, 0.432), "Fit": (3.963, 0.545),
        "Fat": (4.142, 0.555), "Muscular": (3.996, 0.607), "BigBuff": (4.164, 0.661)},
    "MeetEnd_Coach_WalkTalk_Squatavious": {
        "Skinny": (2.973, 0.242), "SkinnyFat": (3.041, 0.257), "Fit": (3.241, 0.361),
        "Fat": (3.371, 0.413), "Muscular": (3.491, 0.505), "BigBuff": (3.625, 0.581)},
    "MeetEnd_Coach_WalkTalk_Benchamin": {
        "Skinny": (4.002, 0.426), "SkinnyFat": (4.051, 0.456), "Fit": (4.058, 0.538),
        "Fat": (4.248, 0.559), "Muscular": (4.087, 0.600), "BigBuff": (4.202, 0.697)},
    "MeetEnd_Coach_WalkTalk_Sumo": {
        "Skinny": (4.279, 0.398), "SkinnyFat": (4.327, 0.421), "Fit": (4.350, 0.522),
        "Fat": (4.516, 0.529), "Muscular": (4.391, 0.583), "BigBuff": (4.562, 0.624)},
}


def _rot_y(v, deg):
    a = math.radians(deg)
    return Vector((v.x * math.cos(a) + v.z * math.sin(a), v.y, -v.x * math.sin(a) + v.z * math.cos(a)))


# ---------------------------------------------------------------- the clips
def build():
    _espec = importlib.util.spec_from_file_location("entrance_animations", os.path.join(_HERE, "entrance_animations.py"))
    E = importlib.util.module_from_spec(_espec)
    _espec.loader.exec_module(E)
    F, S = E.F, E.S
    I4 = Matrix.Identity(4)
    original = dict(S.JOINTS)

    def use_body(body):
        """S.JOINTS = this body's rest joints, each part's frame at its own joint (the hand's at its centre, 0.125 under
        the wrist, as anim_qa and the game's hand centre): S.forward_kinematics and ik_arm then pose THIS body."""
        j = {k: Vector(v) for k, v in BODY_JOINTS[body].items()}
        for side, sx in (("Left", 1), ("Right", -1)):
            for part in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot"):
                v = j["Left" + part]
                j[side + part] = Vector((v.x * sx, v.y, v.z))
        z = lambda a, b: tuple(j[a] - j[b])
        table = {
            "Root": ("HumanoidRootPart", "LowerTorso", z("LowerTorso", "HumanoidRootNode"), (0, 0, 0)),
            "Waist": ("LowerTorso", "UpperTorso", z("UpperTorso", "LowerTorso"), (0, 0, 0)),
            "Neck": ("UpperTorso", "Head", z("Neck", "UpperTorso"), (0, 0, 0)),
        }
        for side in ("Left", "Right"):
            table[side + "Shoulder"] = ("UpperTorso", side + "UpperArm", z(side + "UpperArm", "UpperTorso"), (0, 0, 0))
            table[side + "Elbow"] = (side + "UpperArm", side + "LowerArm", z(side + "LowerArm", side + "UpperArm"), (0, 0, 0))
            table[side + "Wrist"] = (side + "LowerArm", side + "Hand", z(side + "Hand", side + "LowerArm"), (0, 0.125, 0))
            table[side + "Hip"] = ("LowerTorso", side + "UpperLeg", z(side + "UpperLeg", "LowerTorso"), (0, 0, 0))
            table[side + "Knee"] = (side + "UpperLeg", side + "LowerLeg", z(side + "LowerLeg", side + "UpperLeg"), (0, 0, 0))
            table[side + "Ankle"] = (side + "LowerLeg", side + "Foot", z(side + "Foot", side + "LowerLeg"), (0, 0, 0))
        S.JOINTS.clear()
        S.JOINTS.update(table)
        return j

    def track(keys, t):
        a, b, u = F.at(keys, t)
        return a + (b - a) * u if not isinstance(a, Vector) else a.lerp(b, u)

    def bump(t, centre, half):
        u = (t - centre) / half
        return 0.0 if abs(u) >= 1.0 else 0.5 * (1.0 + math.cos(math.pi * u))

    NODS = (2.25, 3.15, 4.4, 5.55, 6.3, 7.15)
    HANG = F.HANG
    RIGHT_HANG = {"raise": 7.0, "swing": 2.0, "twist": 0.0, "elbow": 10.0}   # (relaxed, a hair off his side)

    def body_at(t):
        lean = track([(0.0, 0.0), (0.12, 0.0), (0.75, -4.0), (RELEASE[0], -4.0), (8.8, 0.0), (LENGTH, 0.0)], t)
        turn = track([(0.0, 0.0), (0.12, 0.0), (0.75, 6.0), (RELEASE[0], 6.0), (8.8, 0.0), (LENGTH, 0.0)], t)
        yaw = track([(0.0, 0.0), (0.12, 0.0), (0.72, 18.0), (RELEASE[0], 18.0), (8.75, 0.0), (LENGTH, 0.0)], t)
        nod = -5.0 * sum(bump(t, c, 0.22) for c in NODS)
        return {"Waist": S.ry(turn) @ S.rx(lean), "Neck": S.ry(yaw) @ S.rx(nod - 2.0 * (yaw / 18.0))}

    # ---------------- talking with his body (TALK_*): the free right arm, the head and a little of the chest
    P = Matrix.Diagonal((-1.0, 1.0, 1.0, 1.0))

    def mirrored(m):
        return P @ m @ P

    def ik_right(body, target, pull, prev):
        """The RIGHT arm's angles (one_arm("Right", ...)) putting its hand centre on `target` (root frame), the elbow
        toward `pull` (chest frame): the left arm's exact solve on the mirrored body (the rig is symmetric)."""
        mb = {k: mirrored(v) for k, v in body.items()}
        return E.ik_arm(mb, Vector((-target.x, target.y, target.z)), Vector((-pull[0], pull[1], pull[2])), prev)

    def front_at(body_name, y_root, root_y):
        rows = TALK_FRONT[body_name]
        y = y_root + root_y
        if y <= rows[0][0]:
            return rows[0][1]
        for (y0, z0), (y1, z1) in zip(rows, rows[1:]):
            if y <= y1:
                return z0 + (z1 - z0) * (y - y0) / (y1 - y0)
        return rows[-1][1]

    class Talk:
        """The talking layer of one clip on one body: body(t) the Waist / Neck (and the walk's Root bob), right(t,
        body, prev) the free arm's joints, pat(t) 0..1 the near hand lifted off the back."""

        def __init__(self, mode, body_name, base_body, length, pats, looped):
            self.mode, self.body_name, self.base, self.length, self.pats, self.looped = (
                mode, body_name, base_body, length, pats, looped)
            j = BODY_JOINTS[body_name]
            self.root_y = j["HumanoidRootNode"][1]
            sh = S.JOINTS["RightShoulder"][2]
            self.shoulder_c = Vector(sh)                                  # (UpperTorso frame)
            upper = (Vector(j["LeftLowerArm"]) - Vector(j["LeftUpperArm"])).length
            fore = (Vector(j["LeftHand"]) - Vector(j["LeftLowerArm"])).length + 0.125
            self.L = upper + fore
            # heights and sideways in units of the torso (shoulder joint to hip joint): long-armed Sumo's short torso
            # put his "chest-high" gestures at his hips when they were in arm lengths
            self.Tz = j["LeftUpperArm"][1] - j["LowerTorso"][1]
            self.front_x = {"Fat": 1.15, "Squatavious": 1.25, "Benchamin": 1.05, "Sumo": 0.95}[body_name]
            self.keys = TALK_KEYS[mode]
            self.beats = TALK_BEATS[mode]
            self.head = TALK_HEAD[mode]
            # the hanging hand (RIGHT_HANG) and the elbow way that solves back to exactly it
            hang_pose = {}
            hang_pose.update(E.one_arm("Right", RIGHT_HANG))
            fk = S.forward_kinematics(I4, hang_pose)
            ut = fk["UpperTorso"]
            self.hang_c = ut.inverted() @ fk["RightHand"].to_translation() - self.shoulder_c
            # (the arm's joints are not in line at rest - the upper arm splays out - so the elbow's way is found by
            #  trying ways round the shoulder-hand line: the one whose solve turns the shoulder as RIGHT_HANG does)
            want_sh = E.one_arm("Right", RIGHT_HANG)["RightShoulder"].to_quaternion()
            target0 = self.shoulder_c + self.hang_c                     # (UpperTorso frame = root frame at rest,
            target0 = ut @ target0                                       #  turned to the root frame)
            line = self.hang_c.normalized()
            ref = Vector((0.0, 0.0, 1.0))
            ref = (ref - line * ref.dot(line)).normalized()
            side_v = line.cross(ref)
            best = None
            for k in range(72):
                ang = math.radians(k * 5.0)
                pull = ref * math.cos(ang) + side_v * math.sin(ang)
                a0 = ik_right({}, target0, tuple(pull), dict(HANG))
                d = E.one_arm("Right", a0)["RightShoulder"].to_quaternion().rotation_difference(want_sh).angle
                if best is None or d < best[0]:
                    best = (d, tuple(pull))
            self.hang_pull = best[1]

        def _w(self, t):
            if self.looped:
                t = t % self.length
            return t

        def body(self, t):
            t = self._w(t)
            out = dict(self.base(t))
            lean = sum(-1.6 * b[2] * bump(t, b[0], 0.30) for b in self.beats if b[1] in ("push", "chop", "shake"))
            turn = 1.5 * math.sin(2 * math.pi * t / self.length * (2 if self.mode == "walk" else 1.5))
            nod = sum(h[1] * bump(t, h[0], 0.24) for h in self.head)
            tilt = sum(h[2] * bump(t, h[0], 0.45) for h in self.head)
            w_on = 1.0 if self.mode == "walk" else S.smooth((t - 1.2) / 0.4) * (1.0 - S.smooth((t - 7.8) / 0.6))
            lean *= TALK_TWEAK.get((self.mode, self.body_name), {}).get("lean", 1.0)
            out["Waist"] = S.ry(turn * w_on) @ out["Waist"] @ S.rx(lean * w_on)
            out["Neck"] = out["Neck"] @ S.rx(nod * w_on) @ S.rz(tilt * w_on)
            return out

        def _pose_at(self, name):
            if name == "hang":
                return self.hang_c, 0.0, 0.0, 0.0
            off, roll, flex = TALK_POSES[name]
            # (the hand as far from the shoulder, in arm lengths, as the pose says - so the elbow bends the same on
            #  every body - its height and sideways in torso lengths, the rest forward)
            tw = TALK_TWEAK.get((self.mode, self.body_name), {})
            x, y = (off[0] + tw.get("dx", 0.0)) * self.Tz, off[1] * self.Tz
            far = Vector(off).length * self.L * tw.get("far", 1.0)
            z = -math.sqrt(max(far * far - x * x - y * y, (0.3 * self.L) ** 2))
            return Vector((x, y, z)), roll, flex, 1.0

        def hand(self, t):
            """(hand centre from the right shoulder, chest frame), roll, flex, talking weight (0 = hanging)."""
            t = self._w(t)
            keys = self.keys
            if t <= keys[0][0]:
                a = b = self._pose_at(keys[0][1])
                u = 0.0
            else:
                for (t0, n0), (t1, n1) in zip(keys, keys[1:]):
                    if t <= t1:
                        a, b = self._pose_at(n0), self._pose_at(n1)
                        u = S.smooth((t - t0) / (t1 - t0))
                        break
                else:
                    a = b = self._pose_at(keys[-1][1])
                    u = 0.0
            pos = a[0].lerp(b[0], u)
            roll = a[1] + (b[1] - a[1]) * u
            flex = a[2] + (b[2] - a[2]) * u
            w = a[3] + (b[3] - a[3]) * u
            L, Tz = self.L, self.Tz
            for bt, kind, size in self.beats:
                if kind == "push":
                    k = bump(t, bt, 0.22) * size
                    pos = pos + Vector((-0.03 * Tz, 0.025 * Tz, -0.06 * L)) * k
                    flex -= 8.0 * k
                elif kind == "chop":
                    k = bump(t, bt, 0.13) * size
                    pos = pos + Vector((0.0, -0.065 * Tz, -0.02 * L)) * k
                    flex -= 14.0 * k
                elif kind == "open":
                    k = bump(t, bt, 0.28) * size
                    pos = pos + Vector((-0.03 * Tz, 0.04 * Tz, -0.03 * L)) * k
                    flex += 6.0 * k
                elif kind == "shake":
                    if bt - 0.25 < t < bt + 0.25:
                        edge = min(1.0, (t - (bt - 0.25)) / 0.08, ((bt + 0.25) - t) / 0.08)
                        pos = pos + Vector((0.0, 0.03 * Tz * edge * size * math.sin(2 * math.pi * 5.0 * (t - bt + 0.25)),
                                            0.0))
            return pos, roll, flex, w

        def right(self, t, body, prev):
            pos, roll, flex, w = self.hand(t)
            ut = S.forward_kinematics(I4, body)["UpperTorso"]
            target = ut @ (self.shoulder_c + pos)
            if w > 0.0:
                # in front of his own chest / belly at that height (root frame; the chest's small turns ignored)
                lim = front_at(self.body_name, target.y, self.root_y) - TALK_CLEAR
                # (fully while the hand is in front of the body, not beside it: rising from the hang it passed
                #  through the belly's side, anim_qa arm_in_outfit 0.06)
                k = 1.0 if target.x < self.front_x else w
                if target.z > lim:
                    target.z = lim + (target.z - lim) * (1.0 - k)
            pull = Vector(self.hang_pull).lerp(Vector(TALK_PULL), w)
            a = ik_right(body, target, pull, prev)
            # (the mirrored solve's twist sign is the left arm's: one_arm("Right", a) mirrors it back)
            wrist = S.ry(roll) @ S.rz(flex)
            return a, wrist, target

        def pat(self, t):
            t = self._w(t)
            s = 0.0
            for p in self.pats:
                for pp in ((p, p - self.length, p + self.length) if self.looped else (p,)):
                    # up over 0.16 s, down onto the back at p (a quicker drop than the lift)
                    if pp - 0.30 < t <= pp:
                        u = (t - (pp - 0.30)) / 0.30
                        s = max(s, math.sin(math.pi * u) ** 1.3 if u < 1 else 0.0)
            return s

    clips = {}
    for name, spec in VERSIONS.items():
        j = use_body(spec["body"])
        root = j["HumanoidRootNode"]
        shoulder0 = j["LeftUpperArm"] - root
        rest = S.forward_kinematics(I4, E.one_arm("Left", HANG))
        hang = rest["LeftHand"].to_translation()
        reach = "reach" in spec
        upper = (j["LeftLowerArm"] - j["LeftUpperArm"]).length
        fore = (j["LeftHand"] - j["LeftLowerArm"]).length + 0.125

        def arm_dir(az, el):
            a_, e_ = math.radians(az), math.radians(el)
            return Vector((-math.sin(a_) * math.cos(e_), math.sin(e_), -math.cos(a_) * math.cos(e_)))
        if reach:
            reach_len = math.sqrt(upper * upper + fore * fore + 2 * upper * fore * math.cos(math.radians(spec["bend"])))
            on = shoulder0 + arm_dir(*spec["reach"]) * reach_len
        else:
            on = shoulder0 + Vector(spec["on"])
        n_c = _rot_y(BACK_NORMAL, -NOMINAL_YAW)                     # the back's normal, coach frame
        fingers_c = _rot_y(Vector(spec["fingers"]), -NOMINAL_YAW)
        pre = on + n_c * 0.2 + Vector((0, 0.04, 0))                 # just off the back, before landing / after leaving
        lift = n_c * 0.12 + Vector((0, 0.03, 0))                    # a pat: the hand lifts a little off the back
        settle = Vector((0, -0.025, 0))
        # on the way: the hand rises at his own left side, the arm out a little, elbow down (`mid`), behind the
        # lifter's right arm, then goes forward onto the back; the release the same way back. (The coach faces the
        # lifter, so "forward" from the hang, or in front of his own chest, ran the hand into the lifter's right arm,
        # 0.10-0.23 deep, pairqa 2026-11-25.)
        arm_len = (j["LeftLowerArm"] - j["LeftUpperArm"]).length + (j["LeftHand"] - j["LeftLowerArm"]).length + 0.125
        mid = shoulder0 + Vector(spec.get("mid", (0, 0, 0))) * (arm_len / 2.43)
        mid_back = mid + Vector((0.0, -0.06, 0.0))
        if reach:
            # the arm keeps its length (the elbow its gentle bend): every spot on the sphere round the shoulder, the
            # pats and the settle pivoting at the shoulder; on the way the arm swings out to his left side, low
            # (`side`), behind the lifter's right arm, then up and round onto the back
            def on_sphere(v):
                return shoulder0 + (v - shoulder0).normalized() * reach_len
            pre, lift_on, settled = on_sphere(pre), on_sphere(on + lift), on_sphere(on + settle)
            mid = shoulder0 + arm_dir(*spec["side"]) * reach_len
            mid_back = shoulder0 + arm_dir(spec["side"][0], spec["side"][1] - 6.0) * reach_len
            keys = [(0.0, hang), (0.12, hang), (0.38, mid), (0.64, pre), (PATS[0], on), (1.02, lift_on), (PATS[1], on),
                    (1.7, settled), (RELEASE[0], settled), (8.16, on_sphere(pre + settle)), (8.42, mid_back),
                    (RELEASE[1], hang), (LENGTH, hang)]
        else:
            keys = [(0.0, hang), (0.12, hang), (0.38, mid), (0.64, pre), (PATS[0], on), (1.02, on + lift), (PATS[1], on),
                    (1.7, on + settle), (RELEASE[0], on + settle), (8.16, pre + settle), (8.42, mid_back),
                    (RELEASE[1], hang), (LENGTH, hang)]

        def arc_track(t):
            """Between keys round the shoulder: the direction turned, the distance eased (a straight line between two
            spots at arm's length cuts inside the reach and folds the elbow on the way)."""
            if t <= keys[0][0]:
                return keys[0][1]
            for (t0, a_), (t1, b_) in zip(keys, keys[1:]):
                if t <= t1:
                    u = S.smooth((t - t0) / (t1 - t0))
                    da, db = a_ - shoulder0, b_ - shoulder0
                    d = da.normalized().slerp(db.normalized(), u) if da.angle(db) > 1e-4 else da.normalized()
                    return shoulder0 + d * (da.length + (db.length - da.length) * u)
            return keys[-1][1]
        el_hang, el_down = Vector((-0.3, -0.8, 0.6)), Vector(spec["pull"])   # (hanging: the bend back and down; close
        #  to the reach's pull, so swapping them does not spin the arm round: pop 1157 deg/s with (-0.2, -0.3, 1.0))
        # (the elbow stays pointing down until the hand is back at his side: easing it to the hang earlier turned the
        #  elbow back while the hand was still up, anim_qa elbow_back 0.77-0.95 and the hand into his own body)
        pulls = [(0.0, el_hang), (0.1, el_hang), (0.2, el_down), (8.48, el_down), (8.72, el_hang), (LENGTH, el_hang)]
        palm_w = [(0.0, 0.0), (0.3, 0.0), (0.62, 1.0), (8.18, 1.0), (8.45, 0.0), (LENGTH, 0.0)]
        hcw = S.hand_centre_from_wrist("Left")
        _p, _c, c0s, c1s = S.JOINTS["LeftShoulder"]
        _p, _c, c0e, c1e = S.JOINTS["LeftElbow"]

        def lower_of(body, a):
            ut = S.forward_kinematics(I4, body)["UpperTorso"]
            sh, el = S._arm_tf("Left", a)
            return ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()

        poses, prev, worst = {}, dict(HANG), {"miss": 0.0, "wrist": 0.0, "elbow": 0.0}
        talk = Talk("stand", spec["body"], body_at, TALK_LENGTH, TALK_REST_PATS, False) if spec.get("talk") else None
        prev_r = dict(RIGHT_HANG)
        if talk:
            worst.update({"r_wrist": 0.0, "r_elbow": 0.0, "r_miss": 0.0})
        t = 0.0
        times = []
        while t < LENGTH - 1e-6:
            times.append(round(t, 3))
            t += 0.05 if (talk or t < 1.5 or RELEASE[0] - 0.1 <= t < RELEASE[1] + 0.1) else 0.1
        times.append(LENGTH)
        for t in times:
            body = talk.body(t) if talk else body_at(t)
            target = arc_track(t) if reach else track(keys, t)
            if talk and talk.pat(t) > 0.0:
                # (a small pat while he talks: the hand lifts off the back and lands again, pivoting at the shoulder
                #  for the reaching arms as the first two do)
                lifted = target + (n_c * TALK_PAT_LIFT + Vector((0, 0.02, 0))) * talk.pat(t)
                target = on_sphere(lifted) if reach else lifted
            pull = track(pulls, t)
            w = track(palm_w, t)
            a = E.ik_arm(body, target, pull, prev)
            wrist = I4
            if w > 0:
                free_rot = lower_of(body, a).to_3x3()
                want = S.hand_frame("Left", -n_c, fingers_c - (-n_c) * fingers_c.dot(-n_c))
                rot = free_rot.to_quaternion().slerp(want.to_quaternion(), w).to_matrix()
                a = E.ik_arm(body, target - rot @ hcw, pull, prev, wrist_point=True)
                wrist = (lower_of(body, a).to_3x3().transposed() @ rot).to_4x4()
                worst["wrist"] = max(worst["wrist"], math.degrees(wrist.to_quaternion().angle))
            prev = a
            pose = dict(body)
            pose.update(E.one_arm("Left", a))
            pose["LeftWrist"] = wrist
            if talk:
                ar, rwrist, rtarget = talk.right(t, body, prev_r)
                prev_r = ar
                pose.update(E.one_arm("Right", ar))
                pose["RightWrist"] = rwrist
            else:
                right = E.one_arm("Right", RIGHT_HANG)
                pose["RightShoulder"], pose["RightElbow"] = right["RightShoulder"], right["RightElbow"]
            fk = S.forward_kinematics(I4, pose)
            worst["miss"] = max(worst["miss"], (fk["LeftHand"].to_translation() - target).length)
            worst["elbow"] = max(worst["elbow"], a["elbow"])
            if talk:
                worst["r_miss"] = max(worst["r_miss"], (fk["RightHand"].to_translation() - rtarget).length)
                worst["r_elbow"] = max(worst["r_elbow"], ar["elbow"])
                worst["r_wrist"] = max(worst["r_wrist"], math.degrees(rwrist.to_quaternion().angle))
            poses[t] = pose
        clips[name] = (poses, spec, worst, {"on": on, "pre": pre, "mid": mid, "hang": hang})

    # ---------------- the walk together (WALK_VERSIONS): the BackPat rest arm held while both walk
    for name, wspec in WALK_VERSIONS.items():
        spec = VERSIONS[wspec["from"]]
        j = use_body(spec["body"])
        shoulder0 = j["LeftUpperArm"] - j["HumanoidRootNode"]
        upper = (j["LeftLowerArm"] - j["LeftUpperArm"]).length
        fore = (j["LeftHand"] - j["LeftLowerArm"]).length + 0.125
        # walking, his root faces the way they walk (yaw 0): the BackPat hand spot turned by the yaw it stood at, from
        # the shoulder where the chest turn puts it (from the rest shoulder the arm came out straighter: 0-24 deg)
        shoulder0 = S.joint_point(S.forward_kinematics(I4, {"Waist": S.ry(WALK_TURN) @ S.rx(-3.0)}), "LeftShoulder")
        if "reach_dir" in wspec:
            # (an arm way of its own for the walk, from the turned shoulder; its length set by the elbow below)
            az, el = wspec["reach_dir"]
            a_, e_ = math.radians(az), math.radians(el)
            on = shoulder0 + Vector((-math.sin(a_) * math.cos(e_), math.sin(e_), -math.cos(a_) * math.cos(e_))) * (upper + fore)
        elif "reach" in spec:
            reach_len = math.sqrt(upper * upper + fore * fore + 2 * upper * fore * math.cos(math.radians(spec["bend"])))
            az, el = spec["reach"]
            a_, e_ = math.radians(az + wspec.get("yaw", WALK_FROM_YAW)), math.radians(el + wspec.get("raise", 0.0))
            on = shoulder0 + Vector((-math.sin(a_) * math.cos(e_), math.sin(e_), -math.cos(a_) * math.cos(e_))) * reach_len
        else:
            on = shoulder0 + _rot_y(Vector(wspec.get("on", spec["on"])), wspec.get("yaw", WALK_FROM_YAW))
        n_c = Vector(wspec.get("normal", BACK_NORMAL)).normalized()
        pull = Vector(wspec.get("pull", spec["pull"]))
        hcw = S.hand_centre_from_wrist("Left")
        _p, _c, c0s, c1s = S.JOINTS["LeftShoulder"]
        _p, _c, c0e, c1e = S.JOINTS["LeftElbow"]
        # the fingers' way on the back (toward the spine ... straight up) with the least wrist turn for this arm
        side_dir = Vector((-1.0, 0.0, 0.0)) - n_c * (-n_c.x)
        side_dir.normalize()
        up_dir = n_c.cross(side_dir) if n_c.cross(side_dir).y > 0 else side_dir.cross(n_c)
        best = None
        body0 = {"Waist": S.ry(WALK_TURN) @ S.rx(-3.0)}
        ut0 = S.forward_kinematics(I4, body0)["UpperTorso"]
        for deg in range(-30, 91, 10):
            f = side_dir * math.cos(math.radians(deg)) + up_dir * math.sin(math.radians(deg))
            w_ = S.hand_frame("Left", -n_c, f)
            a0 = E.ik_arm(body0, on - w_ @ hcw, pull, dict(HANG), wrist_point=True)
            sh, el = S._arm_tf("Left", a0)
            lo = ut0 @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()
            turn = math.degrees((lo.to_3x3().transposed() @ w_).to_quaternion().angle)
            if best is None or turn < best[0]:
                best = (turn, deg, f)
        fingers_c = best[2]
        want = S.hand_frame("Left", -n_c, fingers_c)
        # the arm's length set so the elbow bends as much as at the BackPat rest (the approved shape)
        lo_s, hi_s = 0.6, 1.4
        for _ in range(24):
            mid_s = (lo_s + hi_s) / 2
            a0 = E.ik_arm(body0, shoulder0 + (on - shoulder0) * mid_s - want @ hcw, pull, dict(HANG), wrist_point=True)
            if a0["elbow"] > wspec["elbow"]:
                lo_s = mid_s
            else:
                hi_s = mid_s
        on = shoulder0 + (on - shoulder0) * ((lo_s + hi_s) / 2)
        print("WALK", name, "fingers %d deg up from the spine way, wrist %.1f, arm x%.3f" % (best[1], best[0],
                                                                                           (lo_s + hi_s) / 2))

        def walk_body(t):
            # the chest turned toward the lifter (the hips face the walk: the game's walk keys the legs and root);
            # the head turned a little further, looking at him now and then, a few small talking nods
            look = 14.0 + 12.0 * (bump(t, 1.4, 0.55) + bump(t, 3.1, 0.45))
            nod = -4.0 * (bump(t, 1.35, 0.18) + bump(t, 1.7, 0.18) + bump(t, 3.05, 0.18))
            bob = -WALK_BOB[0] * 0.5 * (1.0 - math.cos(2.0 * math.pi * WALK_BOB[1] * t))
            return {"Root": S.T((0.0, bob, 0.0)), "Waist": S.ry(WALK_TURN) @ S.rx(-3.0), "Neck": S.ry(look) @ S.rx(nod - 2.0)}

        poses, prev, worst = {}, dict(HANG), {"miss": 0.0, "wrist": 0.0, "elbow": 0.0}
        steps = int(round(WALK_LENGTH / 0.1))
        for i in range(steps + 1):
            t = round(min(WALK_LENGTH, i * 0.1), 3)
            body = walk_body(0.0 if i == steps else t)      # (looped: it ends on its first pose)
            a = prev
            for _ in range(2):                              # (the first frame: settle the euler branch)
                a = E.ik_arm(body, on - want @ hcw, pull, a, wrist_point=True)
            ut = S.forward_kinematics(I4, body)["UpperTorso"]
            sh, el = S._arm_tf("Left", a)
            lower = ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()
            wrist = (lower.to_3x3().transposed() @ want).to_4x4()
            prev = a
            pose = dict(body)
            pose.update(E.one_arm("Left", a))
            pose["LeftWrist"] = wrist
            fk = S.forward_kinematics(I4, pose)
            worst["miss"] = max(worst["miss"], (fk["LeftHand"].to_translation() - on).length)
            worst["elbow"] = max(worst["elbow"], a["elbow"])
            worst["wrist"] = max(worst["wrist"], math.degrees(wrist.to_quaternion().angle))
            poses[t] = pose
        clips[name] = (poses, dict(spec, walk=True), worst, {"on": on})

    # ---------------- walking beside him, talking (WALKTALK_VERSIONS)
    for name, wspec in WALKTALK_VERSIONS.items():
        if os.environ.get("BACKPAT_ONLY") and name not in os.environ["BACKPAT_ONLY"].split(","):
            continue
        j = use_body(wspec["body"])
        turn_w = float(os.environ.get("WALKTALK_%s_TURN" % wspec["body"].upper(), wspec.get("turn", WALKTALK_TURN)))
        base0 = {"Waist": S.ry(turn_w) @ S.rx(-3.0)}
        shoulder0 = S.joint_point(S.forward_kinematics(I4, base0), "LeftShoulder")
        on = shoulder0 + Vector(wspec["hand"])
        n_c = Vector(BACK_NORMAL).normalized()           # (both face the walk: the lifter's frame is the coach's)
        pull = Vector(wspec["pull"])
        hcw = S.hand_centre_from_wrist("Left")
        _p, _c, c0s, c1s = S.JOINTS["LeftShoulder"]
        _p, _c, c0e, c1e = S.JOINTS["LeftElbow"]
        ut0 = S.forward_kinematics(I4, base0)["UpperTorso"]

        def lower_rot(body, a):
            ut = S.forward_kinematics(I4, body)["UpperTorso"]
            sh, el = S._arm_tf("Left", a)
            return (ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()).to_3x3()
        # the fingers' way on the back (toward the spine ... up) with the least wrist turn for this arm
        side_dir = Vector((-1.0, 0.0, 0.0)) - n_c * (-n_c.x)
        side_dir.normalize()
        up_dir = n_c.cross(side_dir) if n_c.cross(side_dir).y > 0 else side_dir.cross(n_c)

        def fingers_for(on):
            best = None
            for deg in range(-40, 91, 5):
                f = side_dir * math.cos(math.radians(deg)) + up_dir * math.sin(math.radians(deg))
                w_ = S.hand_frame("Left", -n_c, f)
                a0 = E.ik_arm(base0, on - w_ @ hcw, pull, dict(HANG), wrist_point=True)
                a0 = E.ik_arm(base0, on - w_ @ hcw, pull, a0, wrist_point=True)
                turn = math.degrees((lower_rot(base0, a0).transposed() @ w_).to_quaternion().angle)
                if best is None or turn < best[0]:
                    best = (turn, deg, f, a0)
            return best
        if "bend" in wspec:
            # the hand's way kept, its distance set so the elbow bends `bend` degrees (the arm's relaxed shape)
            lo_s, hi_s = 0.7, 1.3
            for _ in range(22):
                mid_s = (lo_s + hi_s) / 2
                if fingers_for(shoulder0 + Vector(wspec["hand"]) * mid_s)[3]["elbow"] > wspec["bend"]:
                    lo_s = mid_s
                else:
                    hi_s = mid_s
            on = shoulder0 + Vector(wspec["hand"]) * ((lo_s + hi_s) / 2)
        best = fingers_for(on)
        want = S.hand_frame("Left", -n_c, best[2])
        print("WALKTALK", name, "fingers %d deg up from the spine way, wrist %.1f, elbow %.1f, hand %s from the "
              "shoulder" % (best[1], best[0], best[3]["elbow"], tuple(round(c, 3) for c in on - shoulder0)))

        def walk_base(t):
            bob = -WALK_BOB[0] * 0.5 * (1.0 - math.cos(2.0 * math.pi * WALK_BOB[1] * t))
            look = 15.0 + 6.0 * math.sin(2 * math.pi * t / WALKTALK_LENGTH * 2 + 0.6)
            return {"Root": S.T((0.0, bob, 0.0)), "Waist": S.ry(turn_w) @ S.rx(-3.0),
                    "Neck": S.ry(look) @ S.rx(-2.0)}
        talk = Talk("walk", wspec["body"], walk_base, WALKTALK_LENGTH, WALKTALK_PATS, True)
        poses, prev, prev_r = {}, best[3], dict(HANG)
        worst = {"miss": 0.0, "wrist": 0.0, "elbow": 0.0, "elbow_min": 999.0, "r_wrist": 0.0, "r_elbow": 0.0,
                 "r_miss": 0.0}
        steps = int(round(WALKTALK_LENGTH / 0.05))
        for i in range(steps):
            t = round(i * 0.05, 3)
            body = talk.body(t)
            target = on + n_c * (TALK_PAT_LIFT * talk.pat(t)) + Vector((0, 0.02, 0)) * talk.pat(t)
            # (the pat pivots at the shoulder, the arm keeping its length: lifted straight off the back it pulled the
            #  arm straight)
            target = shoulder0 + (target - shoulder0).normalized() * (on - shoulder0).length
            a = prev
            for _ in range(2 if i else 3):
                a = E.ik_arm(body, target - want @ hcw, pull, a, wrist_point=True)
            wrist = (lower_rot(body, a).transposed() @ want).to_4x4()
            prev = a
            for _ in range(1 if i else 3):
                ar, rwrist, rtarget = talk.right(t, body, prev_r)
                prev_r = ar
            pose = dict(body)
            pose.update(E.one_arm("Left", a))
            pose["LeftWrist"] = wrist
            pose.update(E.one_arm("Right", ar))
            pose["RightWrist"] = rwrist
            fk = S.forward_kinematics(I4, pose)
            worst["miss"] = max(worst["miss"], (fk["LeftHand"].to_translation() - target).length)
            worst["elbow"] = max(worst["elbow"], a["elbow"])
            worst["elbow_min"] = min(worst["elbow_min"], a["elbow"])
            worst["wrist"] = max(worst["wrist"], math.degrees(wrist.to_quaternion().angle))
            worst["r_miss"] = max(worst["r_miss"], (fk["RightHand"].to_translation() - rtarget).length)
            worst["r_elbow"] = max(worst["r_elbow"], ar["elbow"])
            worst["r_wrist"] = max(worst["r_wrist"], math.degrees(rwrist.to_quaternion().angle))
            poses[t] = pose
        poses[WALKTALK_LENGTH] = dict(poses[0.0])          # (looped: it ends on its first pose)
        clips[name] = (poses, dict(wspec, walktalk=True), worst, {"on": on})
    S.JOINTS.clear()
    S.JOINTS.update(original)
    return clips, S


def export(name, poses, hip, S, looped=False, only=None):
    """Writes art/animations/<name>.rbxmx (Action priority). only: the parts keyed; their parents are written at
    weight 0 (left to whatever else plays, entrance_animations.export's way), every other part left out."""
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">{hip:g}</float><bool name="Loop">{"true" if looped else "false"}</bool>'
           f'<string name="Name">{name}</string><token name="Priority">2</token>'
           f'</Properties>']
    children, parent_of = {}, {}
    for joint, (parent, child, c0, c1) in S.JOINTS.items():
        children.setdefault(parent, []).append((child, joint))
        parent_of[child] = parent
    keep = None
    if only:
        keep = set(only)
        for part in only:
            while part in parent_of:
                part = parent_of[part]
                keep.add(part)

    def pose_xml(part, transforms):
        if keep is not None and part not in keep:
            return ""
        joint = S.CHILD_JOINT.get(part)
        m = transforms.get(joint, Matrix.Identity(4)) if joint else Matrix.Identity(4)
        weight = 0 if only and part not in only else 1
        s = (f'<Item class="Pose" referent="RBX{next(refs)}"><Properties>'
             f'<CoordinateFrame name="CFrame">{S._cframe_xml(m)}</CoordinateFrame>'
             f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
             f'<string name="Name">{part}</string><float name="Weight">{weight}</float></Properties>')
        for child, _ in children.get(part, []):
            s += pose_xml(child, transforms)
        return s + "</Item>"

    for t in sorted(poses):
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", poses[t]))
        out.append("</Item>")
    out.append("</Item></roblox>")
    os.makedirs(S.OUT_DIR, exist_ok=True)
    path = os.path.join(S.OUT_DIR, name + ".rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    return path, len(poses)


# ---------------------------------------------------------------- pair check on the real bodies (READ-ONLY)
def pair_qa(out_dir):
    import glob
    import bpy
    from mathutils.bvhtree import BVHTree

    os.makedirs(os.path.join(out_dir, "tiles"), exist_ok=True)
    G = {"__name__": "gear_fit_03"}
    exec(open(os.path.join(_HERE, "gear_fit_03.py"), encoding="utf-8").read(), G)
    TO_B = G["TO_B"]
    G["ANIMS"] = os.environ.get("PAIR_ANIMS", os.path.join(ROOT, "art", "animations"))
    versions = [v for v in os.environ.get("PAIR_VERSIONS", ",".join(VERSIONS)).split(",") if v]
    lifters = [b for b in os.environ.get("PAIR_LIFTERS", ",".join(LIFTERS)).split(",") if b]
    pictured = [b for b in os.environ.get("PAIR_PICTURES", "Skinny,Fat,BigBuff").split(",") if b]
    yaws = [float(y) for y in os.environ.get("PAIR_YAWS", "38,42,45").split(",")]
    OUTFIT = ("Tee", "WornSinglet_Black", "WornSinglet_Red", "WornSinglet_Shorts", "WornSinglet_Trim",
              "WornLeverBelt_Outer", "WornLeverBelt_Lining", "WornLeverBelt_Lever")
    BODY_PARTS = ["UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
                  "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftFoot", "RightFoot",
                  "LeftHand", "RightHand", "StandInHead"]
    LEFT_ARM = ("LeftUpperArm", "LeftLowerArm")
    SWAPS = ("Fist", "Grip", "SquatGrip", "Point", "ThumbsUp")
    COACH_CLOTHES = ("Tee", "TeeWhite", "Joggers", "JoggersWhite", "Sneakers", "SneakersSole")

    def mat(name, rgba):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.diffuse_color = rgba
        return m

    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            o.location = (500, 500, 0)
        if o.parent is not None and any(s in o.name for s in SWAPS):
            o.hide_render = True

    def dress(rig, build, items, tint=None):
        before = set(bpy.data.objects)
        for kind in ("Clothes", "Gear"):
            found = sorted(glob.glob(os.path.join(ROOT, "art", "exports", "Cartoon%s[0-9][0-9]_%s.glb" % (kind, build))))
            if found:
                bpy.ops.import_scene.gltf(filepath=found[-1])
        kept = []
        ref = [c for c in rig.children if c.name.endswith("_UpperTorso")][0]
        rel = ref.matrix_parent_inverse @ ref.matrix_basis
        for o in [o for o in bpy.data.objects if o not in before]:
            item, _, _part = o.name.partition("__")
            if o.type == "MESH" and item in items:
                o.data.transform(rel.inverted() @ o.matrix_world)
                o.parent = rig
                o.matrix_parent_inverse = ref.matrix_parent_inverse.copy()
                o.matrix_basis = ref.matrix_basis.copy()
                for m in o.modifiers:
                    if m.type == "ARMATURE":
                        m.object = rig
                if tint:
                    o.data = o.data.copy()
                    o.data.materials.clear()
                    o.data.materials.append(tint)
                kept.append(o)
            else:
                bpy.data.objects.remove(o, do_unlink=True)
        xs = [v.co.x for o in kept if o.name.partition("__")[2].split(".")[0] == "UpperTorso" for v in o.data.vertices]
        if xs:
            body = [v.co.x for v in ref.data.vertices]
            shift = (min(body) + max(body)) / 2 - (min(xs) + max(xs)) / 2
            if abs(shift) > 0.5:
                for o in kept:
                    o.data.transform(Matrix.Translation(Vector((shift, 0, 0))))
        return kept

    coach_tee = mat("PairCoachTee", (0.05, 0.09, 0.28, 1))
    coach_skin = mat("PairCoachSkin", (0.42, 0.27, 0.18, 1))
    figures = {}

    def coach_figure(body):
        """(rig, parts {name: obj}, clothes [obj]) of the coach body, in his own clothes."""
        if body in figures:
            return figures[body]
        if body + "Rig" in bpy.data.objects and body not in BODY_JOINTS or body == "Fat":
            # the staff body: a second figure of the lifter build (the lifter's own may be on screen too)
            src = bpy.data.objects[body + "Rig"]
            rig = src.copy()
            rig.name = "Coach" + body + "Rig"
            bpy.context.scene.collection.objects.link(rig)
            parts = {}
            for c in src.children:
                if any(s in c.name for s in SWAPS):
                    continue
                n = c.copy()
                n.name = "Coach" + body + "_" + c.name.partition("_")[2]
                bpy.context.scene.collection.objects.link(n)
                n.parent = rig
                n.parent_type, n.parent_bone = c.parent_type, c.parent_bone
                n.matrix_parent_inverse = c.matrix_parent_inverse.copy()
                for m in n.modifiers:
                    if m.type == "ARMATURE":
                        m.object = rig
                parts[c.name.partition("_")[2]] = n
            clothes = dress(rig, body, ("Tee",), coach_tee)
        else:
            # a lift coach: his rig, body and own clothes (tee, joggers, sneakers) from CoachClothes_01.blend
            path = os.path.join(ROOT, "art", "blender", "CoachClothes_01.blend")
            with bpy.data.libraries.load(path) as (src_lib, dst_lib):
                dst_lib.objects = [n for n in src_lib.objects if n == body + "Rig" or (
                    n.startswith(body + "_") and not any(s in n for s in SWAPS) and
                    ("__" not in n or n.split("_", 1)[1].split("__")[0] in COACH_CLOTHES))]
            for o in dst_lib.objects:
                if o is not None:
                    bpy.context.scene.collection.objects.link(o)
            rig = bpy.data.objects[body + "Rig"]
            parts = {o.name.partition("_")[2]: o for o in dst_lib.objects if o and o.parent == rig and "__" not in o.name}
            clothes = [o for o in dst_lib.objects if o and "__" in o.name]
        for n in parts.values():
            if n.type == "MESH" and n.name.split("_", 1)[1] in ("LeftHand", "RightHand", "StandInHead",
                                                                "LeftLowerArm", "RightLowerArm"):
                n.data = n.data.copy()
                n.data.materials.clear()
                n.data.materials.append(coach_skin)
        figures[body] = (rig, parts, clothes)
        return figures[body]

    lifter_dressed = {}

    def lifter_figure(build):
        if build not in lifter_dressed:
            rig = bpy.data.objects[build + "Rig"]
            parts = {c.name.partition("_")[2]: c for c in rig.children if not any(s in c.name for s in SWAPS)}
            lifter_dressed[build] = (rig, parts, dress(rig, build, OUTFIT))
        return lifter_dressed[build]

    J = {}

    def joints(rig):
        if rig.name not in J:
            J[rig.name] = {b.name: TO_B @ b.head_local for b in rig.data.bones}
        return J[rig.name]

    def frames_of(rig, transforms):
        j = joints(rig)
        world = {"HumanoidRootNode": Matrix.Translation(j["HumanoidRootNode"])}
        for part in ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                                     ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]:
            par = G["PARENT"][part]
            world[part] = world[par] @ Matrix.Translation(j[part] - j[par]) @ transforms.get(part, Matrix.Identity(4))
        return world

    def points(objs):
        dg = bpy.context.evaluated_depsgraph_get()
        verts, polys = [], []
        for o in objs:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            base = len(verts)
            verts += [o.matrix_world @ v.co for v in me.vertices]
            polys += [tuple(base + i for i in p.vertices) for p in me.polygons]
            ev.to_mesh_clear()
        return (BVHTree.FromPolygons(verts, polys) if polys else None), verts

    RAYS = [Vector(d).normalized() for d in ((0.31, 0.93, 0.19), (-0.27, -0.35, 0.9), (0.12, -0.95, -0.29))]

    def inside(p, tree):
        votes = 0
        for d in RAYS:
            o, n = p, 0
            for _ in range(24):
                hit = tree.ray_cast(o, d, 20.0)
                if hit[0] is None:
                    break
                n += 1
                o = hit[0] + d * 1e-4
            votes += n % 2
        return votes >= 2

    def clothes_out(p, skin, worn):
        """How far a point outside the skin is out from the OUTERMOST layer there (anim_qa's layer stacking); < 0 =
        inside the clothes."""
        loc, nrm, _i, d = skin.find_nearest(p, 3.0)
        if loc is None:
            return 9.0
        if worn is None:
            return d
        layer, q = 0.0, loc + nrm * 0.002
        for _ in range(8):
            hit = worn.ray_cast(q, nrm, 0.15 if layer == 0.0 else 0.08)
            if hit[0] is None:
                break
            layer = (hit[0] - loc).dot(nrm)
            q = hit[0] + nrm * 1e-4
            if layer > 0.35:
                break
        return d - layer

    def place(lifter_rig, coach_rig, side, back, yaw):
        lifter_rig.matrix_world = Matrix.Identity(4)
        coach_rig.matrix_world = (Matrix.Translation(TO_B.to_3x3() @ Vector((side, 0.0, back)))
                                  @ Matrix.Rotation(math.radians(yaw), 4, "Z"))

    def to_lifter(p):
        return TO_B @ p           # (the lifter rig stands at the origin)

    cache = {}

    def lifter_trees(lifter):
        key = lifter[0].name
        if key not in cache:
            l_rig, l_parts, l_worn = lifter
            bpy.context.view_layer.update()
            skin, skin_pts = points([l_parts[n] for n in BODY_PARTS if n in l_parts])
            worn, worn_pts = points([o for o in l_worn if o.name.partition("__")[2].split(".")[0] in
                                     ("UpperTorso", "LowerTorso")])
            cache[key] = (skin, worn, skin_pts + worn_pts)
        return cache[key]

    def measure(name, coach, lifter, t, full=True, coach_tf=None, lifter_tf=None):
        c_rig, c_parts, c_clothes = coach
        coach_tf = coach_tf or G["anim_at"](name, t)
        G["pose_rig"](c_rig, coach_tf)
        if lifter_tf is not None:                   # (walking: the lifter posed too, his trees rebuilt)
            G["pose_rig"](lifter[0], lifter_tf)
            cache.pop(lifter[0].name, None)
        bpy.context.view_layer.update()
        l_skin, l_out, l_pts = lifter_trees(lifter)
        _h, hand_pts = points([c_parts["LeftHand"]])
        gap, sink = 9.0, 0.0
        for p in hand_pts:
            if inside(p, l_skin):
                sink = max(sink, l_skin.find_nearest(p, 2.0)[3] + 0.07)
                continue
            out = clothes_out(p, l_skin, l_out)
            if out < 0:
                sink = max(sink, -out)
            else:
                gap = min(gap, out)
        res = {"gap": 0.0 if sink > 0 else gap, "sink": sink}
        w = frames_of(c_rig, coach_tf)
        palm = (c_rig.matrix_world.to_3x3() @ TO_B.to_3x3() @ (w["LeftHand"].to_3x3() @ Vector((1.0, 0.0, 0.0))))
        palm.normalize()
        hj = joints(c_rig)["LeftHand"]
        mid = c_rig.matrix_world @ (TO_B @ (w["LeftHand"] @ Vector((0, -0.3, 0))))
        loc, nrm, _i, _d = (l_out.find_nearest(mid, 3.0) if l_out else l_skin.find_nearest(mid, 3.0))
        res["tilt"] = math.degrees(palm.angle(-nrm)) if loc is not None else -1.0
        res["mid_on"] = to_lifter(loc) if loc is not None else None
        res["mid"] = mid
        if not full:
            return res
        # the bodies, judged on the outer clothes: the coach (but his left arm) and the lifter
        c_skin, _cs = points([c_parts[n] for n in BODY_PARTS if n in c_parts])
        hand_tree = points([c_parts["LeftHand"]])[0]
        c_body, _cb = points([c_parts[n] for n in BODY_PARTS if n in c_parts and n not in LEFT_ARM + ("LeftHand",)])
        torso_clothes = [o for o in c_clothes if o.name.partition("__")[2].split(".")[0] in ("UpperTorso", "LowerTorso")]
        c_out = points(torso_clothes)[0] if torso_clothes else None
        rest_objs = [c_parts[n] for n in BODY_PARTS if n in c_parts and n not in LEFT_ARM + ("LeftHand",)]
        rest_objs += [o for o in c_clothes if o.name.partition("__")[2].split(".")[0] not in LEFT_ARM]
        _r, rest_pts = points(rest_objs)
        arm_objs = [c_parts[n] for n in LEFT_ARM] + [o for o in c_clothes if o.name.partition("__")[2].split(".")[0]
                                                     in LEFT_ARM]
        _a, arm_pts = points(arm_objs)
        overlap, body_gap, arm_gap = 0.0, 9.0, 9.0
        for pts, is_arm in ((rest_pts[::2], False), (arm_pts, True)):
            for p in pts:
                h = l_skin.find_nearest(p, GAP_REACH[0])
                if h[0] is None:
                    continue
                if inside(p, l_skin):
                    overlap = max(overlap, h[3] + 0.05)
                    continue
                out = clothes_out(p, l_skin, l_out)
                if out < 0:
                    overlap = max(overlap, -out)
                    out = 0.0
                if is_arm:
                    arm_gap = min(arm_gap, out)
                else:
                    body_gap = min(body_gap, out)
        for p in l_pts[::2]:
            h = c_skin.find_nearest(p, GAP_REACH[1])
            if h[0] is None:
                continue
            if inside(p, c_skin) and not (hand_tree is not None and hand_tree.find_nearest(p, 0.25)[0] is not None
                                          and inside(p, hand_tree)):
                # (a lifter point inside the coach; the palm's own contact is `sink`'s, not counted twice here)
                overlap = max(overlap, h[3] + 0.05)
            elif c_out is not None and clothes_out(p, c_skin, c_out) < 0:
                overlap = max(overlap, -clothes_out(p, c_skin, c_out))
            else:
                hb = c_body.find_nearest(p, GAP_REACH[1])
                if hb[0] is not None:
                    body_gap = min(body_gap, clothes_out(p, c_body, c_out))
        res.update({"overlap": overlap, "body_gap": body_gap, "arm_gap": arm_gap})
        return res

    def fit(name, coach, lifter, yaw, t=4.0, want=0.012):
        """side, back for this yaw: the palm's middle at PALM_X (scaled) across the back, resting ON the outer layer."""
        palm_x = PALM_X * BACK_HALF.get(lifter[0].name[:-3], 0.91) / 0.91
        side, back = 2.5, 1.0
        place(lifter[0], coach[0], side, back, yaw)
        r = measure(name, coach, lifter, t, full=False)
        p = to_lifter(r["mid"])
        side += palm_x - p.x
        for _ in range(4):
            lo, hi = back - 1.2, back + 1.2
            for _ in range(16):
                m = (lo + hi) / 2
                place(lifter[0], coach[0], side, m, yaw)
                r = measure(name, coach, lifter, t, full=False)
                if r["sink"] > 0 or r["gap"] < want:
                    lo = m
                else:
                    hi = m
            back = hi
            place(lifter[0], coach[0], side, back, yaw)
            on = measure(name, coach, lifter, t, full=False)["mid_on"]
            if on is None or abs(on.x - palm_x) < 0.01:
                break
            side += palm_x - on.x
        return side, back

    if os.environ.get("PAIR_WALKTALK"):
        walk_talk_qa(out_dir, G, TO_B, lifters, pictured, coach_figure, lifter_figure, measure, place, frames_of, mat)
        return
    if os.environ.get("PAIR_WALK"):
        walk_qa(out_dir, G, TO_B, lifters, pictured, coach_figure, lifter_figure, measure, place, frames_of, mat)
        return

    report = ["# MeetEnd_Coach_BackPat pair check (meet_end_animations.py pairqa)\n\n",
              "Studs, degrees. Coach root `side` right of the lifter's root, `back` behind, turned `yaw` toward him. "
              "gap/sink: the coach's left hand on the lifter's outer layer; tilt: palm vs the back's normal (0 = flat); "
              "body_gap: the nearest the coach (not his left arm) comes to the lifter, outer clothes to outer clothes; "
              "arm_gap: the same for his left arm; overlap: deepest point of either body inside the other.\n\n"]
    placements = {}
    times = [t for t, _f in G["read_anim"](versions[0])]
    for name in versions:
        body = VERSIONS[name]["body"]
        coach = coach_figure(body)
        for f in list(figures.values()):
            f[0].location = (500, 500, 0)
        placements[name] = {}
        for lb in lifters:
            if os.environ.get("PAIR_USE_TABLE") and lb in PLACEMENT.get(name, {}):
                # (pictures only: the stored spot, no fitting or measuring)
                placements[name][lb] = tuple(PLACEMENT[name][lb]) + (None, {})
                continue
            lifter = lifter_figure(lb)
            for other in lifter_dressed.values():
                other[0].location = (500, 500, 0)
            tries = []
            for yaw in yaws:
                side, back = fit(name, coach, lifter, yaw)
                place(lifter[0], coach[0], side, back, yaw)
                r = measure(name, coach, lifter, 4.0, full=True)
                tries.append((yaw, side, back, r))
                print("[PairQA] %s/%s yaw %.0f side %.3f back %.3f body_gap %.3f arm_gap %.3f overlap %.3f tilt %.1f" % (
                    name, lb, yaw, side, back, r["body_gap"], r["arm_gap"], r["overlap"], r["tilt"]))
            ok = [x for x in tries if x[3]["overlap"] == 0 and x[3]["arm_gap"] >= 0.02 and 0.15 <= x[3]["body_gap"] <= 0.35]
            pick = min(ok or tries, key=lambda x: (abs(x[3]["body_gap"] - 0.25) + 0.01 * x[3]["tilt"]
                                                   + (0 if ok else 9 * x[3]["overlap"])))
            yaw, side, back, _r = pick
            place(lifter[0], coach[0], side, back, yaw)
            worst = {"sink_contact": (0.0, 0), "gap_contact": (0.0, 0), "tilt_contact": (0.0, 0), "overlap": (0.0, 0),
                     "body_gap_min": (9.0, 0), "body_gap_max_rest": (0.0, 0), "arm_gap_min": (9.0, 0),
                     "hand_path_min": (9.0, 0)}
            moments = {}
            for t in times:
                r = measure(name, coach, lifter, t, full=True)
                contact = PATS[0] - 0.01 <= t <= RELEASE[0] + 0.01 and (abs(t - PATS[0]) < 0.01 or t >= PATS[1] - 0.01)
                if VERSIONS[name].get("talk"):
                    # (the small pats while he talks lift the hand off on purpose; a sink counts at every moment)
                    contact = contact and not any(pp - 0.32 < t < pp + 0.02 for pp in TALK_REST_PATS)
                    if r["sink"] > worst["sink_contact"][0]:
                        worst["sink_contact"] = (r["sink"], t)
                if contact:
                    for k, v in (("sink_contact", r["sink"]), ("gap_contact", r["gap"]), ("tilt_contact", r["tilt"])):
                        if v > worst[k][0]:
                            worst[k] = (v, t)
                    if r["body_gap"] > worst["body_gap_max_rest"][0]:
                        worst["body_gap_max_rest"] = (r["body_gap"], t)
                if r["overlap"] > worst["overlap"][0]:
                    worst["overlap"] = (r["overlap"], t)
                if r["body_gap"] < worst["body_gap_min"][0]:
                    worst["body_gap_min"] = (r["body_gap"], t)
                if r["arm_gap"] < worst["arm_gap_min"][0]:
                    worst["arm_gap_min"] = (r["arm_gap"], t)
                if (t < 0.62 or t > 8.2) and r["gap"] < worst["hand_path_min"][0]:
                    worst["hand_path_min"] = (r["gap"], t)
                if abs(t - 4.0) < 0.01 or any(abs(t - p) < 0.01 for p in PATS):
                    moments[t] = r
            on = moments[4.0]["mid_on"]
            placements[name][lb] = (round(side, 3), round(back, 3), yaw, on, worst)
            report.append("## %s (%s) with lifter %s: side %.3f, back %.3f, yaw %.0f\n\n" % (name, body, lb, side, back, yaw))
            report.append("palm middle on the back at 4.0 s (lifter root frame): (%.2f, %.2f, %.2f), %.2f up\n\n" % (
                on.x, on.y - 3.0, on.z, on.y))
            for t, r in sorted(moments.items()):
                report.append("- t %.2f: gap %.3f, sink %.3f, tilt %.1f, body_gap %.3f, arm_gap %.3f, overlap %.3f\n" % (
                    t, r["gap"], r["sink"], r["tilt"], r["body_gap"], r["arm_gap"], r["overlap"]))
            report.append("\nworst: " + ", ".join("%s %.3f (t %.2f)" % (k, v, tt) for k, (v, tt) in worst.items()) + "\n\n")
            print("[PairQA] RESULT %s/%s side %.3f back %.3f yaw %.0f palm (%.2f, %.2f up) worst %s" % (
                name, lb, side, back, yaw, on.x, on.y, {k: (round(v, 3), tt) for k, (v, tt) in worst.items()}))
    open(os.path.join(out_dir, "MeetEnd_pair_qa_%s.md" % "_".join(v.split("_")[-1] for v in versions)), "w",
         encoding="utf-8").write("".join(report))
    lua = ["-- (side, back, yaw) per lifter build, meet_end_animations.py pairqa\n"]
    for name, rows in placements.items():
        lua.append("%s = {\n" % name)
        for lb, (side, back, yaw, _on, _w) in rows.items():
            lua.append("\t%s = { side = %.3f, back = %.3f, yaw = %.0f },\n" % (lb, side, back, yaw))
        lua.append("},\n")
    open(os.path.join(out_dir, "placement_%s.lua" % "_".join(v.split("_")[-1] for v in versions)), "w",
         encoding="utf-8").write("".join(lua))
    print("".join(lua))

    # ---------------- pictures: each version with each pictured lifter, four moments, five views + hand close-ups
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError as e:
        print("engine", e)
    sh = sc.display.shading
    sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
    sh.cavity_type = "WORLD"
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.16, 0.17, 0.2)
    sc.render.image_settings.file_format = "PNG"
    cd = bpy.data.cameras.new("PairCam")
    cd.type = "ORTHO"
    cd.clip_end = 300
    cam = bpy.data.objects.new("PairCam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    lc = bpy.data.curves.new("PairLabel", "FONT")
    label = bpy.data.objects.new("PairLabel", lc)
    label.data.materials.append(mat("PairLabelMat", (0.95, 0.95, 0.9, 1)))
    sc.collection.objects.link(label)
    label.parent = cam
    bpy.ops.mesh.primitive_cylinder_add(radius=40, depth=0.02, vertices=8)
    floor = bpy.context.active_object
    floor.location = (0, 0, -0.011)
    floor.data.materials.append(mat("PairFloor", (0.34, 0.35, 0.38, 1)))
    # (Blender: the lifter faces -Y, his right is -X, the coach stands at -X/+Y.) "game": the game's camera, in front
    # of the pair a little to the coach's side.
    VIEWS = {"game": (-0.55, -1.0, 0.22), "front": (0.0, -1.0, 0.12), "side": (-1.0, 0.0, 0.08),
             "back": (0.0, 1.0, 0.2), "backquarter": (-0.8, 0.9, 0.35)}
    ZOOMS = {"zoom_game": (-0.7, -0.6, 0.45), "zoom_back": (0.15, 1.0, 0.35), "zoom_top": (-0.1, 0.25, 1.0)}
    MOMENTS = [(0.45, "reach"), (PATS[0], "pat 1 lands"), (4.0, "resting, talking"), (8.35, "release")]
    if any(VERSIONS[v].get("talk") for v in versions):
        MOMENTS = [(PATS[0], "pat 1 lands"), (2.30, "point"), (4.70, "open palm"), (5.95, "shake"), (8.35, "release")]

    def shoot(path, text, direction, target, scale, size):
        cd.ortho_scale = scale
        sc.render.resolution_x, sc.render.resolution_y = size
        cam.location = target + Vector(direction).normalized() * 60
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        lc.body = text
        lc.size = scale * 0.03
        label.location = (-scale / 2 + scale * 0.015, scale * size[1] / size[0] / 2 - lc.size * 1.35, -5)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path

    for name in versions:
        coach = coach_figure(VERSIONS[name]["body"])
        for lb in [b for b in pictured if b in placements[name]]:
            lifter = lifter_figure(lb)
            for other in list(figures.values()) + list(lifter_dressed.values()):
                other[0].location = (500, 500, 0)
            side, back, yaw, _on, _w = placements[name][lb]
            place(lifter[0], coach[0], side, back, yaw)
            tiles, zooms = [], []
            centre = TO_B.to_3x3() @ Vector((side / 2, 0, back / 2))
            tag = name.replace("MeetEnd_Coach_BackPat", "BackPat").replace("MeetEnd_Coach_TalkPat", "TalkPat")
            for t, note in MOMENTS:
                G["pose_rig"](coach[0], G["anim_at"](name, t))
                bpy.context.view_layer.update()
                for v, d in VIEWS.items():
                    text = "%s (%s) + lifter %s  t %.2f %s  -  %s" % (tag, VERSIONS[name]["body"], lb, t, note, v)
                    tiles.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_%.2f_%s.png" % (tag, lb, t, v)),
                                                    text, d, Vector((centre.x, centre.y, 3.0)), 7.0, (700, 700))))
                if t >= PATS[0] - 0.01 and t < 8.0:
                    r = measure(name, coach, lifter, t, full=False)
                    for v, d in ZOOMS.items():
                        text = "%s + %s t %.2f %s  %s  gap %.3f sink %.3f tilt %.0f" % (
                            tag, lb, t, note, v, r["gap"], r["sink"], r["tilt"])
                        zooms.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_%.2f_%s.png" % (
                            tag, lb, t, v)), text, d, r["mid"], 2.6, (640, 640))))
            # the elbow at rest, close up (the user's check for a pinched, creased elbow), and its bend
            G["pose_rig"](coach[0], G["anim_at"](name, 4.0))
            bpy.context.view_layer.update()
            w = frames_of(coach[0], G["anim_at"](name, 4.0))
            ua, la = (w[k].to_3x3() @ Vector((0, -1, 0)) for k in ("LeftUpperArm", "LeftLowerArm"))
            bend = math.degrees(ua.angle(la))
            elbow = coach[0].matrix_world @ (TO_B @ w["LeftLowerArm"].to_translation())
            elbows = []
            for v, d in (("game", VIEWS["game"]), ("back", VIEWS["back"]), ("side", (-1.0, 0.3, 0.1))):
                text = "%s + %s t 4.00 resting  elbow %s  bend %.0f deg" % (tag, lb, v, bend)
                elbows.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_elbow_%s.png" % (tag, lb, v)),
                                                 text, d, elbow, 2.0, (640, 640))))
            pe = os.path.join(out_dir, "%s_Lifter%s_ElbowZoom.png" % (tag, lb))
            G["contact_sheet"](elbows, pe, 3)
            print("[PairQA] ELBOW %s/%s resting bend %.1f deg -> %s" % (name, lb, bend, pe))
            p1 = os.path.join(out_dir, "%s_Lifter%s.png" % (tag, lb))
            G["contact_sheet"](tiles, p1, len(VIEWS))
            p2 = os.path.join(out_dir, "%s_Lifter%s_HandZoom.png" % (tag, lb))
            G["contact_sheet"](zooms, p2, len(ZOOMS))
            print("[PairQA] sheet", p1, p2)
    print("[PairQA] DONE (nothing saved)")



def walk_qa(out_dir, G, TO_B, lifters, pictured, coach_figure, lifter_figure, measure, place, frames_of, mat):
    """The walk together: each WalkPat clip over the walk cycle (WALK_UNDER) on the coach, the same walk on the lifter
    at another phase (in game the two walk cycles are not in step), both roots facing the walk (yaw 0). Per lifter
    build: side/back fitted so the palm rests ON the back (no sink anywhere in the cycle), then every phase pair of a
    grid measured: the palm's gap range (does the contact pop on and off?), sink, any body point inside the other
    (the lifter's right arm swinging back through the coach's forearm shows here), the gaps. Pictures."""
    import bpy
    versions = [v for v in os.environ.get("PAIR_VERSIONS", ",".join(WALK_VERSIONS)).split(",") if v]
    under = G["read_anim"](WALK_UNDER)
    period = under[-1][0]
    clip_t = 1.4

    no_yaw = bool(os.environ.get("WALK_NO_YAW"))

    def walk_tf(phase):
        tf = dict(G["anim_at"](WALK_UNDER, (phase % 1.0) * period))
        if no_yaw:
            # (a stand-in for a walk without the hip twist: the Swagger's hips turn +-5 deg and its chest counter-turns
            #  +-14; both turns taken out, the pitch, roll, bob, legs and arm swing kept)
            for part in ("LowerTorso", "UpperTorso"):
                if part in tf:
                    m = tf[part]
                    e = m.to_3x3().to_euler("YXZ")
                    e.y = 0.0
                    tf[part] = Matrix.Translation(m.to_translation()) @ e.to_matrix().to_4x4()
        return tf

    def coach_tf(name, phase, t=clip_t):
        tf = walk_tf(phase)
        mine = G["anim_at"](name, t)
        for part in WALK_PARTS:
            if part in mine:
                tf[part] = mine[part]
        return tf

    L_PH = [i / 8.0 for i in range(8)]
    C_PH = [0.0, 0.25, 0.5, 0.75]
    REF = (0.0, 0.5)                    # (lifter phase, coach phase) the fit is made at
    palm_x = {"Skinny": 0.31, "SkinnyFat": 0.35, "Fit": 0.40, "Fat": 0.48, "Muscular": 0.45, "BigBuff": 0.53}
    report = ["# MeetEnd_Coach_WalkPat walk check (meet_end_animations.py pairqa, PAIR_WALK=1)\n\n",
              "The game's walk cycle under both figures: %s (Roblox's stock R15 walk is not loadable here). Roots face "
              "the walk (yaw 0). Grid: lifter phases %s x coach phases %s, clip at %.1f s.\n\n" % (
                  WALK_UNDER, L_PH, C_PH, clip_t)]
    table = {}
    stored = (WALK_PLACEMENT if no_yaw else WALK_PLACEMENT_TWIST) if os.environ.get("WALK_PICTURES_ONLY") else None
    for name in versions:
        body = VERSIONS[WALK_VERSIONS[name]["from"]]["body"]
        coach = coach_figure(body)
        table[name] = {}
        if stored:
            table[name] = {lb: stored[name][lb] for lb in lifters if lb in stored.get(name, {})}
            continue
        for lb in lifters:
            lifter = lifter_figure(lb)
            want_x = palm_x.get(lb, 0.40) * WALK_VERSIONS[name].get("palm_scale", 1.0)

            for other in lifters:                 # (only this lifter at the origin: the others out of the way)
                if other != lb:
                    lifter_figure(other)[0].location = (500, 500, 0)

            def at(side, back, lph, cph, full=False):
                place(lifter[0], coach[0], side, back, 0.0)
                return measure(name, coach, lifter, clip_t, full=full, coach_tf=coach_tf(name, cph),
                               lifter_tf=walk_tf(lph))
            side, back = 3.0, 0.6
            r = at(side, back, *REF)
            side += want_x - (TO_B @ r["mid"]).x
            for _ in range(4):
                lo, hi = back - 1.2, back + 1.2
                for _ in range(16):
                    m = (lo + hi) / 2
                    r = at(side, m, *REF)
                    if r["sink"] > 0 or r["gap"] < 0.012:
                        lo = m
                    else:
                        hi = m
                back = hi
                on = at(side, back, *REF)["mid_on"]
                if on is None or abs(on.x - want_x) < 0.01:
                    break
                side += want_x - on.x
            # no sink anywhere in the cycle: back out by the deepest sink over the grid (the palm only, quick)
            for _ in range(3):
                deepest = max(at(side, back, lph, cph)["sink"] for lph in L_PH for cph in C_PH)
                if deepest <= 0:
                    break
                back += deepest + 0.004
            back += WALK_EXTRA_BACK.get((name, lb), 0.0)     # (a pair that still touched at the arm swing)
            worst = {"gap_min": 9.0, "gap_max": 0.0, "sink": 0.0, "tilt": 0.0, "overlap": 0.0, "body_gap": 9.0,
                     "arm_gap": 9.0}
            at_worst = {}
            near = 0
            for lph in L_PH:
                for cph in C_PH:
                    r = at(side, back, lph, cph, full=True)
                    near += 1 if r["sink"] == 0 and r["gap"] <= 0.05 else 0
                    for k, v, better in (("gap_min", r["gap"], min), ("gap_max", r["gap"], max),
                                         ("sink", r["sink"], max), ("tilt", r["tilt"], max),
                                         ("overlap", r["overlap"], max), ("body_gap", r["body_gap"], min),
                                         ("arm_gap", r["arm_gap"], min)):
                        if better(v, worst[k]) != worst[k]:
                            worst[k] = v
                            at_worst[k] = (lph, cph)
            on = at(side, back, *REF)["mid_on"]
            table[name][lb] = (round(side, 3), round(back, 3))
            line = "%s/%s side %.3f back %.3f palm (%.2f, %.2f up) gap<=0.05 in %d/%d %s" % (
                name, lb, side, back, on.x, on.y, near, len(L_PH) * len(C_PH),
                {k: (round(v, 3), at_worst.get(k)) for k, v in worst.items()})
            report.append("- " + line + "\n")
            print("[WalkQA] RESULT%s %s" % (" (no hip twist)" if no_yaw else "", line))
    tag = "_".join(v.split("_")[-1] for v in versions) + ("_noyaw" if no_yaw else "")
    open(os.path.join(out_dir, "MeetEnd_walk_qa_%s.md" % tag), "w", encoding="utf-8").write("".join(report))
    lua = ["-- (side, back) per lifter build, roots facing the walk (yaw 0); meet_end_animations.py pairqa PAIR_WALK=1\n"]
    for name, rows in table.items():
        lua.append("%s = {\n" % name)
        for lb, (side, back) in rows.items():
            lua.append("\t%s = { side = %.3f, back = %.3f },\n" % (lb, side, back))
        lua.append("},\n")
    open(os.path.join(out_dir, "walk_placement_%s.lua" % tag), "w", encoding="utf-8").write("".join(lua))
    print("".join(lua))

    # ---------------- pictures: three moments in the stride, game / side / back, and the hand close up
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError as e:
        print("engine", e)
    sh = sc.display.shading
    sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
    sh.cavity_type = "WORLD"
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.16, 0.17, 0.2)
    sc.render.image_settings.file_format = "PNG"
    cd = bpy.data.cameras.new("WalkCam")
    cd.type = "ORTHO"
    cd.clip_end = 300
    cam = bpy.data.objects.new("WalkCam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    lc = bpy.data.curves.new("WalkLabel", "FONT")
    label = bpy.data.objects.new("WalkLabel", lc)
    label.data.materials.append(mat("PairLabelMat", (0.95, 0.95, 0.9, 1)))
    sc.collection.objects.link(label)
    label.parent = cam
    bpy.ops.mesh.primitive_cylinder_add(radius=40, depth=0.02, vertices=8)
    floor = bpy.context.active_object
    floor.location = (0, 0, -0.011)
    floor.data.materials.append(mat("PairFloor", (0.34, 0.35, 0.38, 1)))
    VIEWS = {"game": (-0.55, -1.0, 0.22), "side": (-1.0, 0.0, 0.08), "back": (0.0, 1.0, 0.2)}
    MOMENTS = [(0.0, 0.5), (1.0 / 3.0, 5.0 / 6.0), (2.0 / 3.0, 1.0 / 6.0)]     # (lifter phase, coach phase)

    def shoot(path, text, direction, target, scale, size):
        cd.ortho_scale = scale
        sc.render.resolution_x, sc.render.resolution_y = size
        cam.location = target + Vector(direction).normalized() * 60
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        lc.body = text
        lc.size = scale * 0.03
        label.location = (-scale / 2 + scale * 0.015, scale * size[1] / size[0] / 2 - lc.size * 1.35, -5)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path

    os.makedirs(os.path.join(out_dir, "tiles"), exist_ok=True)
    for name in versions:
        for other in versions:                    # (only this coach in the pictures)
            coach_figure(VERSIONS[WALK_VERSIONS[other]["from"]]["body"])[0].location = (500, 500, 0)
        coach = coach_figure(VERSIONS[WALK_VERSIONS[name]["from"]]["body"])
        tag = name.replace("MeetEnd_Coach_WalkPat", "WalkPat") + ("_noyaw" if no_yaw else "")
        for lb in [b for b in pictured if b in table[name]]:
            for other in lifters:
                if other != lb:
                    lifter_figure(other)[0].location = (500, 500, 0)
            lifter = lifter_figure(lb)
            side, back = table[name][lb]
            tiles, zooms = [], []
            for i, (lph, cph) in enumerate(MOMENTS):
                place(lifter[0], coach[0], side, back, 0.0)
                r = measure(name, coach, lifter, clip_t, full=False, coach_tf=coach_tf(name, cph), lifter_tf=walk_tf(lph))
                centre = TO_B.to_3x3() @ Vector((side / 2, 0, back / 2))
                for v, d in VIEWS.items():
                    text = "%s + lifter %s  stride %d (lifter %.2f, coach %.2f)  -  %s" % (tag, lb, i + 1, lph, cph, v)
                    tiles.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_s%d_%s.png" % (tag, lb, i, v)),
                                                    text, d, Vector((centre.x, centre.y, 3.0)), 7.0, (700, 700))))
                text = "%s + %s stride %d  gap %.3f sink %.3f tilt %.0f" % (tag, lb, i + 1, r["gap"], r["sink"], r["tilt"])
                zooms.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_s%d_zoom.png" % (tag, lb, i)),
                                                text, (0.15, 1.0, 0.35), r["mid"], 2.6, (640, 640))))
            p1 = os.path.join(out_dir, "%s_Lifter%s.png" % (tag, lb))
            G["contact_sheet"](tiles, p1, len(VIEWS))
            p2 = os.path.join(out_dir, "%s_Lifter%s_HandZoom.png" % (tag, lb))
            G["contact_sheet"](zooms, p2, len(MOMENTS))
            print("[WalkQA] sheet", p1, p2)
    print("[WalkQA] DONE (nothing saved)")


def walk_talk_qa(out_dir, G, TO_B, lifters, pictured, coach_figure, lifter_figure, measure, place, frames_of, mat):
    """The walk beside, talking (WALKTALK_VERSIONS): both roots facing the walk (yaw 0), a walk under both figures (the
    clip's upper body on top of the coach's), the two walks out of step. Per lifter build: side from where the palm
    sits across the shoulder blade, back so the palm rests ON the back (no sink at any lifter phase); then a grid of
    (lifter phase, coach phase, clip time) measured: the gap between the bodies (everything but the coach's near arm:
    his free arm's gestures, both walks' arms and legs), the near arm's own gap, anything inside the other, the palm.
    The walk under them: WALK_UNDER_MODE=plain (default: the Swagger's legs, hips and chest with the arms swinging
    +-WALK_PLAIN_SWING deg fore and aft from their rest hang, as Roblox's stock walk swings them) or swagger (its own
    arms, flung out wide: harder than the game's)."""
    import bpy
    versions = [v for v in os.environ.get("PAIR_VERSIONS", ",".join(WALKTALK_VERSIONS)).split(",") if v]
    mode = os.environ.get("WALK_UNDER_MODE", "plain")
    plain_swing = math.radians(float(os.environ.get("WALK_PLAIN_SWING", "30")))
    under = G["read_anim"](WALK_UNDER)
    period = under[-1][0]
    amp = max(abs(f[1]["RightUpperArm"].to_3x3().to_euler("YXZ").x) for f in under if "RightUpperArm" in f[1])
    fit_t = float(os.environ.get("WALKTALK_FIT_T", "0.5"))
    GAP_REACH[:] = [1.6, 1.4]               # (the real gap, not just "over 0.8")

    def walk_tf(phase):
        tf = dict(G["anim_at"](WALK_UNDER, (phase % 1.0) * period))
        if mode == "plain":
            for side in ("Right", "Left"):
                if side + "UpperArm" not in tf:
                    continue
                sw = tf[side + "UpperArm"].to_3x3().to_euler("YXZ").x / amp * plain_swing
                tf[side + "UpperArm"] = Matrix.Rotation(sw, 4, "X")
                lo = tf.get(side + "LowerArm")
                bend = 0.0 if lo is None else lo.to_3x3().to_euler("YXZ").x
                tf[side + "LowerArm"] = Matrix.Rotation(max(math.radians(4.0), min(math.radians(25.0), bend)), 4, "X")
                tf[side + "Hand"] = Matrix.Identity(4)
        return tf

    def coach_tf(name, phase, ct):
        tf = walk_tf(phase)
        mine = G["anim_at"](name, ct)
        for part in WALKTALK_PARTS:
            if part in mine:
                tf[part] = mine[part]
        return tf

    L_PH = [i / 8.0 for i in range(8)]
    C_PH = [0.0, 0.25, 0.5, 0.75]
    dense = bool(os.environ.get("WALKTALK_DENSE"))
    GRID = [(l, c, 1.10) for l in L_PH for c in (C_PH if dense else (0.0, 0.5))]
    GRID += [(L_PH[i % 8], C_PH[(i // 2) % 4], round(i * (0.25 if dense else 0.5), 2))
             for i in range(32 if dense else 16)]
    palm_x = {lb: PALM_X * BACK_HALF[lb] / 0.91 * float(os.environ.get("WALKTALK_PALM_SCALE", "1.25"))
              for lb in BACK_HALF}
    report = ["# MeetEnd_Coach_WalkTalk walk check (meet_end_animations.py pairqa, PAIR_WALKTALK=1)\n\n",
              "Walk under both figures: %s, mode %s (Roblox's stock R15 walk is not loadable here). Roots face the "
              "walk (yaw 0). Grid %d (lifter phase, coach phase, clip time). Gap rule: bodies >= %.2f apart (all but "
              "the coach's near arm), back <= %.2f.\n\n" % (WALK_UNDER, mode, len(GRID), WALK_GAP, WALK_MAX_BACK)]
    table = {}
    stored = WALKTALK_PLACEMENT if os.environ.get("WALK_PICTURES_ONLY") else None
    for name in versions:
        body = WALKTALK_VERSIONS[name]["body"]
        coach = coach_figure(body)
        for other in versions:
            if other != name:
                coach_figure(WALKTALK_VERSIONS[other]["body"])[0].location = (500, 500, 0)
        table[name] = {}
        if stored:
            table[name] = {lb: stored[name][lb] for lb in lifters if lb in stored.get(name, {})}
            continue
        for lb in lifters:
            lifter = lifter_figure(lb)
            want_x = palm_x.get(lb, 0.5)
            for other in lifters:
                if other != lb:
                    lifter_figure(other)[0].location = (500, 500, 0)

            def at(side, back, lph, cph, ct, full=False):
                place(lifter[0], coach[0], side, back, 0.0)
                return measure(name, coach, lifter, ct, full=full, coach_tf=coach_tf(name, cph, ct),
                               lifter_tf=walk_tf(lph))
            side, back = 3.2, 0.5
            r = at(side, back, 0.0, 0.5, fit_t)
            side += want_x - (TO_B @ r["mid"]).x
            for _ in range(4):
                lo, hi = back - 1.5, back + 1.5
                for _ in range(16):
                    m = (lo + hi) / 2
                    r = at(side, m, 0.0, 0.5, fit_t)
                    if r["sink"] > 0 or r["gap"] < 0.012:
                        lo = m
                    else:
                        hi = m
                back = hi
                on = at(side, back, 0.0, 0.5, fit_t)["mid_on"]
                if on is None or abs(on.x - want_x) < 0.01:
                    break
                side += want_x - on.x
            for _ in range(3):
                deepest = max(at(side, back, lph, 0.5, fit_t)["sink"] for lph in L_PH)
                if deepest <= 0:
                    break
                back += deepest + 0.004
            fit_gap = float(os.environ.get("WALKTALK_FIT_GAP", WALKTALK_VERSIONS[name].get("fit_gap", 0.0)))
            if fit_gap:
                # (short Squatavious) side set by the gap instead: out until the bodies are fit_gap apart at the
                # closest moments of the grid, the palm sliding out across the back with him, then back refitted
                probe = [g for g in GRID if g[0] in (0.625, 0.75, 0.875)]
                for _ in range(5):
                    gmin = min(at(side, back, *g, full=True)["body_gap"] for g in probe)
                    if abs(gmin - fit_gap) < 0.015:
                        break
                    side += fit_gap - gmin
                    lo, hi = back - 0.6, back + 0.6
                    for _ in range(14):
                        m = (lo + hi) / 2
                        r = at(side, m, 0.0, 0.5, fit_t)
                        if r["sink"] > 0 or r["gap"] < 0.012:
                            lo = m
                        else:
                            hi = m
                    back = hi
                    for _ in range(3):
                        deepest = max(at(side, back, lph, 0.5, fit_t)["sink"] for lph in L_PH)
                        if deepest <= 0:
                            break
                        back += deepest + 0.004
            worst = {"body_gap": (9.0, None), "arm_gap": (9.0, None), "overlap": (0.0, None), "sink": (0.0, None),
                     "palm_gap_max": (0.0, None)}
            for g in GRID:
                r = at(side, back, *g, full=True)
                resting = all(abs(((g[2] - p) + WALKTALK_LENGTH / 2) % WALKTALK_LENGTH - WALKTALK_LENGTH / 2) > 0.32
                              for p in WALKTALK_PATS)
                for k, v, better in (("body_gap", r["body_gap"], min), ("arm_gap", r["arm_gap"], min),
                                     ("overlap", r["overlap"], max), ("sink", r["sink"], max)):
                    if better(v, worst[k][0]) != worst[k][0]:
                        worst[k] = (v, g)
                if resting and r["gap"] > worst["palm_gap_max"][0]:
                    worst["palm_gap_max"] = (r["gap"], g)
            on = at(side, back, 0.0, 0.5, fit_t)["mid_on"]
            table[name][lb] = (round(side, 3), round(back, 3))
            ok = (worst["body_gap"][0] >= WALK_GAP and worst["overlap"][0] == 0 and worst["sink"][0] == 0
                  and back <= WALK_MAX_BACK + 1e-6)
            line = "%s/%s side %.3f back %.3f palm (%.2f, %.2f up) %s %s" % (
                name, lb, side, back, on.x, on.y, "PASS" if ok else "FAIL",
                {k: (round(v, 3), g) for k, (v, g) in worst.items()})
            report.append("- " + line + "\n")
            print("[WalkTalkQA] RESULT", line)
    tag = "_".join(v.split("_")[-1] for v in versions) + "_" + mode
    open(os.path.join(out_dir, "MeetEnd_walktalk_qa_%s.md" % tag), "w", encoding="utf-8").write("".join(report))
    lua = ["-- (side, back) per lifter build, roots facing the walk (yaw 0); meet_end_animations.py PAIR_WALKTALK=1\n"]
    for name, rows in table.items():
        lua.append("%s = {\n" % name)
        for lb, (side, back) in rows.items():
            lua.append("\t%s = { side = %.3f, back = %.3f },\n" % (lb, side, back))
        lua.append("},\n")
    open(os.path.join(out_dir, "walktalk_placement_%s.lua" % tag), "w", encoding="utf-8").write("".join(lua))
    print("".join(lua))
    if os.environ.get("WALK_NO_PICTURES"):
        return

    # ---------------- pictures: four moments (stride + gesture), five views, the hand close up
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError as e:
        print("engine", e)
    sh = sc.display.shading
    sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
    sh.cavity_type = "WORLD"
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.16, 0.17, 0.2)
    sc.render.image_settings.file_format = "PNG"
    cd = bpy.data.cameras.new("WalkTalkCam")
    cd.type = "ORTHO"
    cd.clip_end = 300
    cam = bpy.data.objects.new("WalkTalkCam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    lc = bpy.data.curves.new("WalkTalkLabel", "FONT")
    label = bpy.data.objects.new("WalkTalkLabel", lc)
    label.data.materials.append(mat("PairLabelMat", (0.95, 0.95, 0.9, 1)))
    sc.collection.objects.link(label)
    label.parent = cam
    bpy.ops.mesh.primitive_cylinder_add(radius=40, depth=0.02, vertices=8)
    floor = bpy.context.active_object
    floor.location = (0, 0, -0.011)
    floor.data.materials.append(mat("PairFloor", (0.34, 0.35, 0.38, 1)))
    VIEWS = {"game": (-0.55, -1.0, 0.22), "front": (0.0, -1.0, 0.1), "back": (0.0, 1.0, 0.2), "top": (0.0, 0.02, 1.0),
             "threequarter": (-0.8, 0.7, 0.3)}
    MOMENTS = [(0.0, 0.5, 1.10, "point"), (1.0 / 3.0, 5.0 / 6.0, 3.20, "open palm"),
               (2.0 / 3.0, 1.0 / 6.0, 4.55, "shake"), (0.5, 0.0, 7.05, "pat lands")]

    def shoot(path, text, direction, target, scale, size):
        cd.ortho_scale = scale
        sc.render.resolution_x, sc.render.resolution_y = size
        cam.location = target + Vector(direction).normalized() * 60
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        lc.body = text
        lc.size = scale * 0.03
        label.location = (-scale / 2 + scale * 0.015, scale * size[1] / size[0] / 2 - lc.size * 1.35, -5)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path

    os.makedirs(os.path.join(out_dir, "tiles"), exist_ok=True)
    for name in versions:
        for other in versions:
            coach_figure(WALKTALK_VERSIONS[other]["body"])[0].location = (500, 500, 0)
        coach = coach_figure(WALKTALK_VERSIONS[name]["body"])
        tag = name.replace("MeetEnd_Coach_WalkTalk", "WalkTalk") + "_" + mode
        for lb in [b for b in pictured if b in table[name]]:
            for other in lifters:
                if other != lb:
                    lifter_figure(other)[0].location = (500, 500, 0)
            lifter = lifter_figure(lb)
            side, back = table[name][lb]
            tiles, zooms = [], []
            for i, (lph, cph, ct, note) in enumerate(MOMENTS):
                place(lifter[0], coach[0], side, back, 0.0)
                r = measure(name, coach, lifter, ct, full=True, coach_tf=coach_tf(name, cph, ct),
                            lifter_tf=walk_tf(lph))
                centre = TO_B.to_3x3() @ Vector((side / 2, 0, back / 2))
                for v, d in VIEWS.items():
                    text = "%s + %s  t %.2f %s  body gap %.2f  -  %s" % (tag, lb, ct, note, r["body_gap"], v)
                    tiles.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_m%d_%s.png" % (tag, lb, i, v)),
                                                    text, d, Vector((centre.x, centre.y, 3.0)), 7.5, (640, 640))))
                text = "%s + %s t %.2f  palm gap %.3f sink %.3f tilt %.0f" % (tag, lb, ct, r["gap"], r["sink"], r["tilt"])
                zooms.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_m%d_zoom.png" % (tag, lb, i)),
                                                text, (0.15, 1.0, 0.35), r["mid"], 2.8, (600, 600))))
            p1 = os.path.join(out_dir, "%s_Lifter%s.png" % (tag, lb))
            G["contact_sheet"](tiles, p1, len(VIEWS))
            p2 = os.path.join(out_dir, "%s_Lifter%s_HandZoom.png" % (tag, lb))
            G["contact_sheet"](zooms, p2, len(MOMENTS))
            print("[WalkTalkQA] sheet", p1, p2)
    print("[WalkTalkQA] DONE (nothing saved)")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "pairqa":
        pair_qa(argv[1] if len(argv) > 1 else r"D:\ClaudeScratch\backpat\pair")
    else:
        clips, S = build()
        only = [v for v in os.environ.get("BACKPAT_ONLY", "").split(",") if v]
        for name, (poses, spec, worst, keys) in clips.items():
            if only and name not in only:
                continue
            walk = spec.get("walk", False)
            only_parts = WALK_PARTS if walk else None
            if spec.get("walktalk"):
                walk, only_parts = True, WALKTALK_PARTS
            print("EXPORTED", export(name, poses, spec["hip"], S, looped=walk, only=only_parts),
                  "worst", {k: round(v, 3) for k, v in worst.items()},
                  "on", tuple(round(c, 3) for c in keys["on"]))
        print("DONE")


# ---------------------------------------------------------------- notes (2026-11-25)
# anim_qa PASS (limits): MeetEnd_Coach_BackPat on Skinny, SkinnyFat, Fit, Fat, Muscular, BigBuff (meet outfit worn);
# each coach version on its own body (CoachBodies_01_Rigged.blend, QA_OUTFIT=none). Squatavious's name contains "Squat",
# which makes anim_qa draw a bar and use the squat exceptions: run it with QA_BAR=none and
# QA_FAIL_LIMITS="elbow_back=0.75;elbow_back_raised=0.4" (the normal limits; it passes them).
# The wrist turns 39-64 deg in contact (the palm laid on a back that faces the coach at ~40 deg): the least found by a
# scan of hand spot x elbow pull x finger way; anim_qa has no wrist limit; lock_hand's soft limit is 60.
# Rejected on the way: the hand straight ahead of the shoulder (wrist 80-108 deg); the hand coming up in front of the
# coach's chest (it ran into the lifter's right arm: the coach faces the lifter); the elbow pull eased back to the hang
# while the hand was still up (elbow 0.77-0.95 behind the shoulder); the reach waypoint close to the shoulder (elbow
# folded to 140-150, Squatavious's forearm into his own arm).
# (Later 2026-11-25, the user's elbow note) Fat, Benchamin and Sumo re-made as REACHES: resting elbow bend 31 / 23 / 31
# deg (was 97 / 97 / 116, creased); the coach stands about an arm's length to the lifter's right, level with him or a
# touch ahead (back -0.33..+0.10), turned 36-44 deg in, the arm out and round behind the lifter; the bodies 0.55+ apart
# (the user chose the arm's shape over closeness). Wrist turn 22-30 deg. Squatavious unchanged (52 deg, no crease).
# PAIR_USE_TABLE=1 re-renders pictures from PLACEMENT without fitting; each sheet set now has an _ElbowZoom.

# (2026-11-25, the walk together) MeetEnd_Coach_WalkPat[_Squatavious|_Benchamin|_Sumo]: 4.0 s loops, upper body only
# (UpperTorso, Head, LeftUpperArm, LeftLowerArm, LeftHand; LowerTorso and the root written at weight 0, nothing else).
# anim_qa PASS on each body (the legs at rest). Walk pair check (pairqa PAIR_WALK=1; 8 lifter x 4 coach walk phases):
# with WALK_PLACEMENT and a walk without the hip twist, no sink and no body inside the other anywhere; the palm rides
# 0.004-0.26 off the back over the cycle (the two walk cycles are independent). With the Swagger's hip twist
# (WALK_PLACEMENT_TWIST) also no sink and no overlap, but the palm swings 0.6-0.7 on and off: the coach's hips turning
# +-5 deg swing a hand held at arm's length about his root; an upper-body clip cannot cancel it (it would have to be in
# step with the walk). The game's real walk (Roblox's stock R15 walk) needs a Studio look.
# (Later 2026-11-25, main session: option b) the WalkPat clips key the LowerTorso too: hips square to the walk, a 0.035
# bob twice a second (not in step with the legs; small enough not to read as a hitch). With that the walk under the coach
# no longer moves the hand; the palm rides 0.001-0.15 off the back (the lifter's own walk). Squatavious walks just
# behind the lifter's right side with his arm across the back, the hand left of the spine on the mid back (3.4 up),
# wrist ~55 deg (it was ~100 with his hand up flat from behind: "pushed up onto the back").

# (2026-11-26, the user's game test: talking with his body, and "the coach is too close") MeetEnd_Coach_TalkPat[...]
# (9.0 s, not looped) and MeetEnd_Coach_WalkTalk[...] (8.0 s loop: UpperTorso, Head, both arms, LowerTorso keyed; the
# legs from the game's walk), Action priority. BackPat / WalkPat untouched (rebuilt byte-identical).
#   blender -b --factory-startup --python art/scripts/meet_end_animations.py   (env BACKPAT_ONLY=<names> to write some)
#   ... CartoonBodies_05_Rigged.blend ... -- pairqa <dir>                       (PAIR_VERSIONS=MeetEnd_Coach_TalkPat...)
#   PAIR_WALKTALK=1 [WALKTALK_DENSE=1] [WALK_UNDER_MODE=plain|swagger] ... -- pairqa <dir>
# anim_qa PASS on every version on its own body (the gym coach: the Fat body in his Tee; the lift coaches:
# CoachBodies_01, no outfit), talk and walk; pop <= 1191 deg/s (= BackPat's own reach), the free arm's elbow <= 113
# deg, elbow_back <= 0.45. Standing pairqa (each coach x 6 lifter builds, every keyframe): no sink, no overlap, palm on
# the back 0.012-0.017 at contact, gaps as BackPat's; Squatavious' gestures go to his own right front (TALK_TWEAK). Walk
# check (plain stand-in walk, 8x4 phases at the point + 32 clip times): bodies 0.40-0.41 apart (Squatavious, fitted to
# it), 0.63-1.25 (gym coach / Benchamin), 0.95+ (Sumo); back 0.23-0.70; no sink, no overlap; the palm rides 0.14-0.19
# off the back over the lifter's walk (Squatavious on the wide builds 0.26-0.39: his hand is out on the shoulder
# blade's edge, where the stand-in walk's chest turn moves the back most). With the Swagger's own wide-flung arms
# (harder than the game's) the tall coaches still pass; Squatavious' near forearm meets a Skinny / SkinnyFat lifter's
# flung arm (0.05-0.09) at its widest swing.
