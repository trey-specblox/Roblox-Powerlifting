# The cartoon lifters' heights: ONE source for the bodies, their rig, the clothes and every animation script.
#
# OLD heights (the block skeleton's, as every script was written: hips 2.0, waist 2.4, shoulder joint 3.763, neck 4.0)
# go in; NEW heights come out. Three skeleton tables, chosen with the environment variable LIFTER_RIG:
#
#   torso  (DEFAULT, approved 2026-11-13, user: "Height in the torso", then "Yes fix the arms, legs are good")
#          legs x1.0 (ankle 0.252, knee 1.178, hips 2.0, HipHeight 2.0), torso x1.35 (waist 2.54, shoulder joint 4.38,
#          neck 4.70), arms x1.5 of the block arm (elbow 3.287, wrist 2.148; user 2026-11-13 "1." = arms x1.5, was x1.2:
#          the hands hung above the hips and no correct deadlift set-up existed). The new bodies (CHARACTER_ART_DIRECTION.md
#          §10.1, build_cartoon_body_04.py's TORSO_TALL). Head, hands and feet unchanged.
#   taller (user 2026-11-12, "make all three builds noticeably taller"): legs x1.2286 (hips 2.0 -> 2.4), torso and arms
#          x1.15 (waist 2.86, neck 4.70). The v02 cartoon bodies (build_cartoon_body_02.py, build_cartoon_rig_02.py,
#          build_cartoon_clothes_02.py) were built on it: rebuild those with LIFTER_RIG=taller.
#   block  the measured Roblox R15 block rig (everything x1.0; the live game's animations until Phase 5).
#
# The arms have their own factor (ARM): on the torso table they grow MORE than the torso (x1.5 vs x1.35), so the hands
# hang at hip height like a real person's.
import os

TABLES = {
    "torso": {"NEW_HIPS": 2.0, "TORSO": 1.35, "ARM": 1.5},
    "taller": {"NEW_HIPS": 2.4, "TORSO": 1.15, "ARM": 1.15},
    "block": {"NEW_HIPS": 2.0, "TORSO": 1.0, "ARM": 1.0},
}
RIG = os.environ.get("LIFTER_RIG", "torso").strip().lower() or "torso"
if RIG not in TABLES:
    raise ValueError(f"LIFTER_RIG must be one of {sorted(TABLES)}, not {RIG!r}")
# WHAT-IF ONLY (proportion experiments, 2026-11-13 deadlift diagnosis): LIFTER_ARM / LIFTER_TORSO / LIFTER_HIPS override
# one number of the chosen table for a scratch run. Never set them for files that go into the game.
TABLES[RIG] = dict(TABLES[RIG])
for _key, _env in (("ARM", "LIFTER_ARM"), ("TORSO", "LIFTER_TORSO"), ("NEW_HIPS", "LIFTER_HIPS")):
    if os.environ.get(_env):
        TABLES[RIG][_key] = float(os.environ[_env])

ANKLE = 0.25          # below this nothing changes (the feet)
OLD_HIPS = 2.0
NEW_HIPS = TABLES[RIG]["NEW_HIPS"]
LEG = (NEW_HIPS - ANKLE) / (OLD_HIPS - ANKLE)     # 1.0 torso / block, 1.2286 taller
TORSO = TABLES[RIG]["TORSO"]                      # the torso and everything above the hips
ARM = TABLES[RIG]["ARM"]                          # upper and lower arm (the hands keep their size)

HIP_HEIGHT = NEW_HIPS                              # Humanoid.HipHeight (ClothesConfig.HipHeight)
HRP_STAND_Y = NEW_HIPS + 1.0                       # the 2-stud root part's centre when standing


def z(old):
    """An old (block-skeleton) height on the body to the new one (the arms hang from it: lengths along an arm use ARM)."""
    if old <= ANKLE:
        return old
    if old <= OLD_HIPS:
        return ANKLE + (old - ANKLE) * LEG
    return NEW_HIPS + (old - OLD_HIPS) * TORSO


def slope(old):
    """How much a short length at that height stretches."""
    if old <= ANKLE:
        return 1.0
    return LEG if old <= OLD_HIPS else TORSO


def span(old_low, old_high):
    """How much a length between two old heights stretches on average."""
    if old_high <= old_low:
        return slope(old_low)
    return (z(old_high) - z(old_low)) / (old_high - old_low)
