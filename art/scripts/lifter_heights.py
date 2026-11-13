# The cartoon lifters' heights: ONE source for the bodies, their rig, the clothes and every animation script.
#
# User 2026-11-12 (after a play test): "the characters look tiny and stubby ... make all three builds noticeably
# taller (longer legs and torso, not just scaled up wider)", then "Re-make animations". The block skeleton the
# animations were made on had hips at 2.0 and the neck at 4.0 (5.2 studs with the head). Now:
#   legs   x1.2286 between the ankle (0.252, unchanged: the feet keep their size) and the hips (2.0 -> 2.4)
#   torso  x1.15 (waist 2.4 -> 2.86, neck 4.0 -> 4.70); arms x1.15 (the hands keep their size)
#   head, hands, feet unchanged: about 5.9 studs tall, ~13% taller, no wider.
# OLD heights (the block skeleton's, as the body scripts were written) go in; NEW heights come out.

ANKLE = 0.25          # below this nothing changes (the feet)
OLD_HIPS = 2.0
NEW_HIPS = 2.4
LEG = (NEW_HIPS - ANKLE) / (OLD_HIPS - ANKLE)     # 1.2286
TORSO = 1.15          # the torso, the arms (they hang from it) and everything above the hips
ARM = TORSO

HIP_HEIGHT = NEW_HIPS                              # Humanoid.HipHeight (ClothesConfig.HipHeight)
HRP_STAND_Y = NEW_HIPS + 1.0                       # the 2-stud root part's centre when standing


def z(old):
    """An old (block-skeleton) height to the new one."""
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
