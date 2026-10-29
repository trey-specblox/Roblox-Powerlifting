# Builds Steel_01 in the live Blender scene: the gym's structural steel that was block-built (blocks to Blender,
# batch 9; user 2026-10-28: "everything still made with blocks change into models through blender ... optimized").
# Two tiny meshes stretched to every piece (the game's unique-mesh budget):
#
#   SteelBeam  an I-beam (two flanges and a web): the hall roof's rafters, tie beams and ridge beam, the balcony
#              columns, the stair stringers and the Strongman Shed's trusses and ridge beam.
#   Handrail   a round steel tube: the balcony and stair handrails.
#
# Both run along Y here (the game's template Z): reference 10 long, the I-beam 1 wide and 1.5 deep (Z up = the
# flanges' side), the tube 1 across. The game stretches each to (thickness, height, length).
# Units, axes and names as in prop_helpers.py. Run in an otherwise empty file (art/blender/Steel_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("Steel_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


STEEL = H.material("ST_Steel", tuple(linear(c) for c in (70, 72, 78)), 0.7, 0.4, 1.0, None)
L = 10.0


def i_beam(bm):
    for z in (0.075, 1.5 - 0.075):
        H.box(bm, Vector((0, 0, z)), Vector((1.0, L, 0.15)))
    H.box(bm, Vector((0, 0, 0.75)), Vector((0.16, L, 1.2)))


B.piece("SteelBeam_Steel", STEEL, i_beam, smooth=False)
B.piece("Handrail_Steel", STEEL, lambda bm: H.cylinder(bm, Vector((4.0, 0, 0.5)), 0.5, L, axis="Y", segments=10))

print("Steel_01 built:", sorted(o.name for o in B.coll.objects))
