# Builds Lights_01 in the live Blender scene: the gym's light fittings that were built from blocks (blocks to
# Blender, batch 2; user 2026-10-28: "everything still made with blocks change into models through blender ...
# optimized for when there is actual players"). Low detail: two pieces each (body + glowing part), one mesh
# reused for every copy; the game stretches the bar and the panel to every size and adds the lights.
#
#   LightBar      the rack hall's hanging LED bar: an aluminium housing with its two hanging cables, and the
#                 glowing diffuser underneath. Reference length 30 along Y (the game stretches it).
#   CeilingPanel  a recessed LED ceiling panel: a thin frame round a glowing diffuser, 6 x 6 (stretched).
#   HighBayLamp   the Strongman Shed's industrial lamp: a dome shade on its cable, a glowing lens under it.
#   StageLight    a stage spotlight: wall plate, yoke and can pointing forward (-Y), a glowing lens.
#   TrackSpot     the Shop's track spotlight head: an adapter, a short stem and a can pointing down, a lens.
#   TrackRail     the Shop's lighting track, 12 long, with end caps.
#
# Units, axes and names as in prop_helpers.py (1 unit = 1 stud, z up, front -Y). Objects are "<Item>_<Piece>"
# with ONE material each. Run in an otherwise empty file (art/blender/Lights_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})

import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("Lights_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, emission=None):
    return H.material("LT_" + name, tuple(linear(c) for c in rgb), metallic, roughness, 1.0, emission)


SILVER = mat("Silver", (190, 192, 198), 1.0, 0.3)
WHITE = mat("White", (236, 236, 232), 0.0, 0.5)
BLACK = mat("Black", (22, 22, 24), 0.2, 0.5)
CHARCOAL = mat("Charcoal", (46, 48, 54), 0.3, 0.5)
GLOW = mat("Glow", (250, 250, 244), 0.0, 0.3, emission=(1.0, 1.0, 0.95))

# ------------------------------------------------------------------ LightBar (x = 0)
# Old blocks: a 0.6 x 0.25 bar hanging 2 below the roof beam on two thin cables, 1 in from each end.
BL = 30.0


def bar_housing(bm):
    H.rounded_box(bm, Vector((0, 0, 0.16)), Vector((0.6, BL, 0.18)), 0.04, 2)
    for y in (-BL / 2 + 1, BL / 2 - 1):
        H.cylinder(bm, Vector((0, y, 1.25)), 0.04, 1.9, segments=6)
        H.cylinder(bm, Vector((0, y, 2.22)), 0.12, 0.06, segments=10)


B.piece("LightBar_Housing", SILVER, bar_housing)
B.piece("LightBar_Diffuser", GLOW, lambda bm: H.box(bm, Vector((0, 0, 0.04)), Vector((0.48, BL - 0.2, 0.08))), smooth=False)

# ------------------------------------------------------------------ CeilingPanel (x = 6)
# 6 x 6, 0.12 deep: its top touches the ceiling.
PX = 6.0


def panel_frame(bm):
    for y in (-2.875, 2.875):
        H.box(bm, Vector((PX, y, 0.06)), Vector((6.0, 0.25, 0.12)))
    for x in (-2.875, 2.875):
        H.box(bm, Vector((PX + x, 0, 0.06)), Vector((0.25, 5.5, 0.12)))


B.piece("CeilingPanel_Frame", WHITE, panel_frame, smooth=False)
B.piece("CeilingPanel_Diffuser", GLOW, lambda bm: H.box(bm, Vector((PX, 0, 0.07)), Vector((5.5, 5.5, 0.06))), smooth=False)

# ------------------------------------------------------------------ HighBayLamp (x = 12)
# Old blocks: a 2 x 2 shade, a 1.6 lens under it and a 2.4 cable: 3.1 tall in all.
LX = 12.0


def lamp_shade(bm):
    H.lathe_z(bm, [(0.0, 0.1), (1.0, 0.1), (0.98, 0.2), (0.7, 0.45), (0.3, 0.62), (0.12, 0.7), (0.0, 0.7)], 16,
              Vector((LX, 0, 0)))
    H.cylinder(bm, Vector((LX, 0, 1.9)), 0.05, 2.4, segments=6)


B.piece("HighBayLamp_Shade", CHARCOAL, lamp_shade)
B.piece("HighBayLamp_Lens", GLOW, lambda bm: H.cylinder(bm, Vector((LX, 0, 0.06)), 0.82, 0.12, segments=16))

# ------------------------------------------------------------------ StageLight (x = 16)
# Old blocks: a 0.9 x 0.4 wall plate 0.19 deep, a 0.8 can 0.6 long and a 0.6 lens, pointing out of the wall.
SX = 16.0


def stage_body(bm):
    H.rounded_box(bm, Vector((SX, -0.095, 0.4)), Vector((0.9, 0.19, 0.4)), 0.03, 1)
    for x in (-0.47, 0.47):
        H.box(bm, Vector((SX + x, -0.4, 0.4)), Vector((0.06, 0.45, 0.14)))
    H.cylinder(bm, Vector((SX, -0.5, 0.4)), 0.4, 0.62, axis="Y", segments=16)
    H.cylinder(bm, Vector((SX, -0.82, 0.4)), 0.43, 0.04, axis="Y", segments=16)


B.piece("StageLight_Body", BLACK, stage_body)
B.piece("StageLight_Lens", GLOW, lambda bm: H.cylinder(bm, Vector((SX, -0.83, 0.4)), 0.32, 0.04, axis="Y", segments=16))

# ------------------------------------------------------------------ TrackSpot (x = 20)
# Old block: 0.6 x 0.6 x 0.5 under the track; the head points down.
TX = 20.0


def spot_head(bm):
    H.box(bm, Vector((TX, 0, 0.47)), Vector((0.3, 0.2, 0.06)))
    H.cylinder(bm, Vector((TX, 0, 0.38)), 0.04, 0.14, segments=6)
    H.cylinder(bm, Vector((TX, 0, 0.17)), 0.26, 0.3, segments=12, radius2=0.2)


B.piece("TrackSpot_Head", BLACK, spot_head)
B.piece("TrackSpot_Lens", GLOW, lambda bm: H.cylinder(bm, Vector((TX, 0, 0.02)), 0.24, 0.04, segments=12))

# ------------------------------------------------------------------ TrackRail (x = 30)
# Old block: 12 x 0.2 x 0.15.
RX = 30.0


def rail(bm):
    H.rounded_box(bm, Vector((RX, 0, 0.075)), Vector((11.8, 0.2, 0.15)), 0.03, 1)
    for x in (-5.95, 5.95):
        H.rounded_box(bm, Vector((RX + x, 0, 0.075)), Vector((0.1, 0.24, 0.17)), 0.02, 1)


B.piece("TrackRail_Rail", BLACK, rail)

print("Lights_01 built:", sorted(o.name for o in B.coll.objects))
