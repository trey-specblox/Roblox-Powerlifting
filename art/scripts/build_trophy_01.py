# Builds Trophy_01 in the live Blender scene: the trophy the top 3 hold on the awards podium at a Regional or
# State meet (GAME_DESIGN.md §35.8, user 2026-10-31). A classic two-handled cup on a stem, on a black base with
# CENTRAL on its front (the gear brand on every label).
#
# Two objects, so the game colours each once (src/server/Meet/Trophies.luau):
#   Trophy_Metal   the cup, stem, knot, handles and the CENTRAL lettering: gold, silver or bronze by place
#   Trophy_Base    the square black base
#
# Units: 1 Blender unit = 1 stud; Z up, front toward -Y (prop_helpers). About 1.4 studs tall, sized to be held
# in one hand by an R15 avatar. Run in an empty file; objects are replaced by name.
import importlib
import math
import os
import sys

from mathutils import Vector

SCRIPTS = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
sys.path.insert(0, SCRIPTS)
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("Trophy_01")
GOLD = H.material("Trophy_Gold", (0.66, 0.4, 0.035), metallic=1.0, roughness=0.3)
BLACK = H.material("Trophy_Black", (0.012, 0.012, 0.014), roughness=0.6)

BASE_W, BASE_H = 0.62, 0.34


def metal(bm):
    # The cup, stem and knot in one closed outline spun round the middle: up the outside, over the rim, down the
    # inside of the bowl to its floor.
    outline = [
        (0.0, BASE_H), (0.2, BASE_H), (0.2, BASE_H + 0.05), (0.085, BASE_H + 0.11),   # foot
        (0.07, BASE_H + 0.32), (0.12, BASE_H + 0.37), (0.07, BASE_H + 0.43),          # stem and knot
        (0.1, BASE_H + 0.5), (0.27, BASE_H + 0.62), (0.35, BASE_H + 0.8),              # bowl
        (0.37, BASE_H + 1.0), (0.4, BASE_H + 1.04), (0.36, BASE_H + 1.05),             # rim
        (0.33, BASE_H + 0.84), (0.22, BASE_H + 0.68), (0.0, BASE_H + 0.62),            # inside the bowl
    ]
    H.lathe_z(bm, outline, 32)
    # Two handles, half rings standing out from the sides of the bowl.
    for side in (-1, 1):
        # Both ends sink into the bowl's wall, so no gap shows where they meet it.
        H.torus(bm, Vector((side * 0.29, 0, BASE_H + 0.84)), 0.14, 0.032, plane="XZ", segments=12, sides=8,
                arc=math.pi, start=-math.pi / 2 if side > 0 else math.pi / 2)
    # CENTRAL on the base's front.
    B.add_text(bm, H.BRAND, 0.095, 0.004, H.on_front(Vector((0, 0, 0)), -BASE_W / 2, BASE_H / 2))


def base(bm):
    H.rounded_box(bm, Vector((0, 0, BASE_H / 2)), (BASE_W, BASE_W, BASE_H), 0.03)


B.piece("Trophy_Metal", GOLD, metal)
B.piece("Trophy_Base", BLACK, base)
print("built Trophy_01")
