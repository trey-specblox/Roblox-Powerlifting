# The tee's crew neck lowered so the neck shows (user 2026-11-20, Studio, the coaches and the chef: "they have no neck,
# and their shirts are covering almost to their chin fix that"). build_cartoon_gear_07.py cuts the tee's neck with
# crew_neck() instead of v6's (GEAR07_OLD_NECK=1 brings the old one back, for comparing).
#
# The old collar (build_cartoon_gear_06.py tee_lines: build_cartoon_gear_04.py NECK) was a vertical cylinder the size of
# the head's footprint (radius 0.55 x 0.46): on the bigger builds the shirt climbed the traps and the front of the neck
# right up under the chin. The new collar is a ring at the base of the neck: the shirt is cut away where it is inside a
# wider oval round the neck AND above a collar height that dips at the front and rises toward the sides (a round U,
# the front lower than the back, like a real crew neck), the two blended so the line turns softly. The builder draws
# the line through its finely refined mesh and gives the edge the fabric's thickness, as every other opening.
#
# Kept clear of the singlet: the oval stays inside the singlet straps' inner edges (the straps always lie on the shirt)
# and the front collar stays above the singlet's front scoop (the shirt's collar still shows over the scoop).
import math

# Build-local (x right, -y FRONT, z up; SH = the shoulder joints' height 4.38 on every build).
SH = 4.38
NECK_CX = 0.0
NECK_FRONT_Y = -0.80     # the oval's reach in front of the neck's middle (y), past the neck's front on every build
NECK_BACK_Y = 0.66       # its reach behind
NECK_RX = 0.62           # its half width (inside the singlet straps' inner edge, 0.66)
COLLAR_FRONT = SH + 0.07 # the collar's height at the front's middle
COLLAR_BACK = SH + 0.26  # at the back's middle (a crew neck sits higher behind)
COLLAR_RISE = 0.50       # how much higher it is at the oval's sides (x = NECK_RX): a round U, never a flat bottom
BACK_FLAT = 0.70         # ... a little less behind (the back's curve flatter, never a V)
SOFT = 0.10              # how softly the oval and the collar height blend at the corners


def _softmax(a, b, k):
    m = max(a, b)
    return m + k * math.log(math.exp((a - m) / k) + math.exp((b - m) / k))


# Per build: the collar this much lower (front, back). The thin builds' chests are shallower and their traps rise beside
# the head as high as the big builds', so at the big builds' height their collar sat right under the chin.
LOWER = {"Skinny": (0.16, 0.10), "SkinnyFat": (0.12, 0.08)}


def crew_neck_for(build):
    """crew_neck() for one build."""
    front, back = LOWER.get(build, (0.0, 0.0))
    return lambda c: crew_neck(c, front, back)


def crew_neck_np(X, build):
    """crew_neck() for many points at once (numpy rows of x, y, z): the long sleeve's builder (build_cartoon_gear_05.py,
    the v4 tee pipeline) works on arrays."""
    import numpy as np
    lower_front, lower_back = LOWER.get(build, (0.0, 0.0))
    cy = (NECK_FRONT_Y + NECK_BACK_Y) / 2
    ry = (NECK_BACK_Y - NECK_FRONT_Y) / 2
    dx, dy = X[:, 0] - NECK_CX, X[:, 1] - cy
    side = (dx / NECK_RX) ** 2
    ell = np.sqrt(side + (dy / ry) ** 2) - 1.0
    back = 0.5 + 0.5 * dy / np.maximum(1e-6, np.hypot(dx, dy))
    back = back * back * (3 - 2 * back)
    front_z, back_z = COLLAR_FRONT - lower_front, COLLAR_BACK - lower_back
    collar = front_z + (back_z - front_z) * back + COLLAR_RISE * (1 - BACK_FLAT * back) * side
    below = (collar - X[:, 2]) * 2.0
    m = np.maximum(ell, below)
    return m + SOFT * np.log(np.exp((ell - m) / SOFT) + np.exp((below - m) / SOFT))


def crew_neck(c, lower_front=0.0, lower_back=0.0):
    """> 0 keeps the shirt; < 0 is the neck opening. c: a build-local point (x, y, z)."""
    cy = (NECK_FRONT_Y + NECK_BACK_Y) / 2
    ry = (NECK_BACK_Y - NECK_FRONT_Y) / 2
    side = ((c.x - NECK_CX) / NECK_RX) ** 2
    ell = math.sqrt(side + ((c.y - cy) / ry) ** 2) - 1.0
    # how far round toward the back the point is (by its direction round the neck, not its depth: the thin builds'
    # necks are shallower, and by depth their fronts counted as half "back" and got a high collar, Skinny 2026-11-20)
    dy = c.y - cy
    back = 0.5 + 0.5 * dy / max(1e-6, math.hypot(c.x - NECK_CX, dy))
    back = back * back * (3 - 2 * back)
    front_z, back_z = COLLAR_FRONT - lower_front, COLLAR_BACK - lower_back
    collar = front_z + (back_z - front_z) * back + COLLAR_RISE * (1 - BACK_FLAT * back) * side
    return _softmax(ell, (collar - c.z) * 2.0, SOFT)
