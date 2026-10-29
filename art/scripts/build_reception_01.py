# Builds Reception_01 in the live Blender scene: the lobby's block-built furniture (blocks to Blender, batch 4;
# user 2026-10-28: "everything still made with blocks change into models through blender ... If its a micro
# model/detail it does not have to be SUPER detailed because i want to make sure everything is optimized").
# Low detail on purpose: one piece per colour, small triangle counts, one mesh reused for every copy.
#
#   ReceptionDesk  the reception desk round the game's picture front (the front panel with the logo stays the
#                  game's own block): dark plinth with its glow strip, white body and end panels, the light-grey
#                  work top behind, an oak counter ledge with a yellow line along its front.
#   CardReader     the payment terminal on the ledge: a stand and a tilted body with a green screen.
#   LightStrip     a slim ceiling light: an aluminium channel with a glowing diffuser (the lobby's strips);
#                  stretched to each strip's length.
#   Turnstile      the gate cabinet: body, steel cap with an arm hub on each side, green top light, a dark
#                  card-reader plate front and back.
#   TurnstileArm   the steel arm across a lane, with yellow rubber caps.
#   RailPost       a round railing post on a base plate.
#   RailRun        the railing's top and middle rails between posts; stretched to each run's length.
#   MerchWall      the merch wall opposite the desk: navy back panel with CENTRAL in yellow, three white shelves
#                  lit from below, shakers on the top shelf, folded shirts on the others.
#   FloodLamp      the outside sign's lamp: wall plate, arm and a head tilted down and back at the sign.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, items stand on z = 0 with their front toward
# -Y. Sizes are the game's (StarterGymBuilder buildReception, StarterGymConfig Desk*/Gate*/CeilingStrip*).
# Run in an otherwise empty file (art/blender/Reception_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("Reception_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, emission=None):
    return H.material("RC_" + name, tuple(linear(c) for c in rgb), metallic, roughness, 1.0, emission)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways).
WHITE = mat("White", (236, 236, 232), 0.0, 0.5)
GREY = mat("LightGrey", (176, 180, 186), 0.0, 0.5)
BLACK = mat("Black", (22, 22, 24), 0.0, 0.5)
CHARCOAL = mat("Charcoal", (46, 48, 54), 0.2, 0.5)
OAK = mat("Oak", (198, 152, 102), 0.0, 0.6)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.5)
NAVY = mat("Navy", (30, 48, 98), 0.0, 0.6)
RED = mat("Red", (200, 30, 38), 0.0, 0.5)
BLUE = mat("Blue", (30, 92, 205), 0.0, 0.5)
STEEL = mat("Silver", (190, 192, 198), 1.0, 0.3)
GLOW = mat("GlowWhite", (255, 250, 240), 0.0, 0.3, emission=(1.0, 0.98, 0.94))
GREEN = mat("GlowGreen", (60, 220, 110), 0.0, 0.3, emission=(0.2, 0.9, 0.4))

# ------------------------------------------------------------------ ReceptionDesk (x = 0)
# 22 long; the customers' front (frontX in the game) is y = -1.75, the back (backX) y = +1.75. The game's
# picture panel fills y -1.75..-1.15 from z 0.3 to the counter (4.4), so nothing here touches its front face.
DL, DF, DB, COUNTER, WORK = 22.0, -1.75, 1.75, 4.4, 3.0

B.piece("ReceptionDesk_Plinth", BLACK, lambda bm: H.box(
    bm, Vector((0, (DF + 0.5 + DB - 0.2) / 2, 0.15)), Vector((DL - 0.6, DB - 0.2 - DF - 0.5, 0.3))), smooth=False)
B.piece("ReceptionDesk_Glow", GLOW, lambda bm: H.box(
    bm, Vector((0, DF + 0.525, 0.125)), Vector((DL - 0.6, 0.15, 0.25))), smooth=False)


def desk_body(bm):
    # The cabinet under the work top and the two end panels up to the counter.
    H.box(bm, Vector((0, (DF + 0.6 + DB) / 2, (0.3 + WORK - 0.2) / 2)), Vector((DL - 1.0, DB - DF - 0.6, WORK - 0.5)))
    for x in (-DL / 2 + 0.25, DL / 2 - 0.25):
        H.rounded_box(bm, Vector((x, (DF + 0.6 + DB) / 2, (0.3 + COUNTER) / 2)),
                      Vector((0.5, DB - DF - 0.6, COUNTER - 0.3)), 0.03, 1)


B.piece("ReceptionDesk_Body", WHITE, desk_body, smooth=False)
B.piece("ReceptionDesk_Work", GREY, lambda bm: H.rounded_box(
    bm, Vector((0, (DF + 0.6 + DB + 0.3) / 2, WORK - 0.1)), Vector((DL - 1.0, DB + 0.3 - DF - 0.6, 0.2)), 0.03, 1))
B.piece("ReceptionDesk_Ledge", OAK, lambda bm: H.rounded_box(
    bm, Vector((0, (DF - 0.15 + DF + 1.4) / 2, COUNTER + 0.1)), Vector((DL, 1.55, 0.2)), 0.04, 2))
B.piece("ReceptionDesk_Accent", YELLOW, lambda bm: H.box(
    bm, Vector((0, DF - 0.15 - 0.005, COUNTER + 0.1)), Vector((DL - 0.2, 0.02, 0.08))), smooth=False)

# ------------------------------------------------------------------ CardReader (x = 14)
# On the ledge, the screen toward the customers (-Y). About 0.5 wide, 0.6 deep, 0.4 tall.
RX = 14.0
TILT = Matrix.Rotation(math.radians(-30), 4, "X")  # leans back: the top face looks up and toward -Y


def reader_body(bm):
    H.rounded_box(bm, Vector((RX, 0.05, 0.03)), Vector((0.4, 0.4, 0.06)), 0.02, 1)
    H.cylinder(bm, Vector((RX, 0.1, 0.12)), 0.05, 0.14, segments=8)
    H.rounded_box(bm, Vector((RX, 0.0, 0.26)), Vector((0.48, 0.6, 0.1)), 0.03, 1, rotation=TILT)


B.piece("CardReader_Body", BLACK, reader_body)
B.piece("CardReader_Screen", GREEN, lambda bm: H.box(
    bm, Vector((RX, 0.0, 0.26)) + TILT @ Vector((0, -0.08, 0.055)), Vector((0.36, 0.28, 0.02)), TILT), smooth=False)

# ------------------------------------------------------------------ LightStrip (x = 18)
# Reference 0.5 wide, 0.12 tall, 10 long along Y; the game stretches it to each strip's length.
SX, SLEN = 18.0, 10.0


def strip_housing(bm):
    H.box(bm, Vector((SX, 0, 0.1)), Vector((0.5, SLEN, 0.04)))
    for x in (-0.23, 0.23):
        H.box(bm, Vector((SX + x, 0, 0.05)), Vector((0.04, SLEN, 0.1)))
    for y in (-SLEN / 2 + 0.02, SLEN / 2 - 0.02):
        H.box(bm, Vector((SX, y, 0.05)), Vector((0.42, 0.04, 0.1)))


B.piece("LightStrip_Housing", STEEL, strip_housing, smooth=False)
B.piece("LightStrip_Diffuser", GLOW, lambda bm: H.box(
    bm, Vector((SX, 0, 0.04)), Vector((0.42, SLEN - 0.08, 0.04))), smooth=False)

# ------------------------------------------------------------------ Turnstile (x = 22)
# The cabinet: 1 wide, 1.2 deep, 3.2 tall, a cap to 3.35, its light to 3.42; arm hubs on both sides at the
# arm's height (2.775), so it is the same either way round.
TX = 22.0
B.piece("Turnstile_Body", CHARCOAL, lambda bm: H.rounded_box(
    bm, Vector((TX, 0, 1.6)), Vector((1.0, 1.2, 3.2)), 0.06, 2))


def turnstile_cap(bm):
    H.rounded_box(bm, Vector((TX, 0, 3.275)), Vector((1.1, 1.3, 0.15)), 0.04, 1)
    for x in (-0.55, 0.55):
        H.cylinder(bm, Vector((TX + x, 0, 2.775)), 0.15, 0.1, axis="X", segments=12)


B.piece("Turnstile_Cap", STEEL, turnstile_cap)
B.piece("Turnstile_Light", GREEN, lambda bm: H.rounded_box(
    bm, Vector((TX, 0, 3.385)), Vector((0.4, 0.3, 0.07)), 0.02, 1))


def turnstile_reader(bm):
    for side in (-1, 1):
        H.box(bm, Vector((TX, side * 0.61, 2.6)), Vector((0.6, 0.02, 0.5)))


B.piece("Turnstile_Reader", BLACK, turnstile_reader, smooth=False)

# ------------------------------------------------------------------ TurnstileArm (x = 26)
# 3.4 long along X (the lane minus 0.6), its middle 2.775 up; rubber caps on both ends.
AX, AL = 26.0, 3.4
B.piece("TurnstileArm_Arm", STEEL, lambda bm: H.cylinder(
    bm, Vector((AX, 0, 2.775)), 0.07, AL - 0.2, axis="X", segments=10))


def arm_tips(bm):
    for x in (-AL / 2 + 0.1, AL / 2 - 0.1):
        H.cylinder(bm, Vector((AX + x, 0, 2.775)), 0.09, 0.2, axis="X", segments=10)


B.piece("TurnstileArm_Tips", YELLOW, arm_tips)

# ------------------------------------------------------------------ RailPost (x = 30)
PX = 30.0


def rail_post(bm):
    H.cylinder(bm, Vector((PX, 0, 0.02)), 0.25, 0.04, segments=12)
    H.cylinder(bm, Vector((PX, 0, 1.7)), 0.13, 3.36, segments=12)
    H.sphere(bm, Vector((PX, 0, 3.38)), 0.14, scale=(1, 1, 0.5), segments=12, rings=4)


B.piece("RailPost_Post", STEEL, rail_post)

# ------------------------------------------------------------------ RailRun (x = 34)
# Reference 6 long along X; the top rail at 3.2-3.4, the middle one at 1.6-1.75. Stretched along X only.
RRX, RRL = 34.0, 6.0


def rail_run(bm):
    H.cylinder(bm, Vector((RRX, 0, 3.3)), 0.1, RRL, axis="X", segments=10)
    H.cylinder(bm, Vector((RRX, 0, 1.675)), 0.075, RRL, axis="X", segments=8)


B.piece("RailRun_Rails", STEEL, rail_run)

# ------------------------------------------------------------------ MerchWall (x = 50)
# The wall is y = 0, the front -Y. The back panel 14 wide from 2.5 to 9.5 up; shelves 12 wide, 1.3 deep
# (from y -0.2 to -1.5) at 7.5, 5.5 and 3.5; six slots 2 apart on each shelf.
MX = 50.0
SHELVES = (7.5, 5.5, 3.5)
SLOTS = [-5 + 2 * k for k in range(6)]

B.piece("MerchWall_Back", NAVY, lambda bm: H.rounded_box(
    bm, Vector((MX, -0.1, 6.0)), Vector((14.0, 0.2, 7.0)), 0.04, 1))


def merch_shelves(bm):
    for h in SHELVES:
        H.rounded_box(bm, Vector((MX, -0.85, h + 0.1)), Vector((12.0, 1.3, 0.2)), 0.03, 1)


B.piece("MerchWall_Shelves", WHITE, merch_shelves)


def merch_glow(bm):
    for h in SHELVES:
        H.box(bm, Vector((MX, -0.85, h - 0.03)), Vector((11.6, 1.1, 0.06)))


B.piece("MerchWall_Glow", GLOW, merch_glow, smooth=False)


def shakers(colour):
    def build(bm):
        for k, x in enumerate(SLOTS):
            if k % 3 == colour:
                H.cylinder(bm, Vector((MX + x, -0.85, SHELVES[0] + 0.2 + 0.33)), 0.21, 0.66, segments=12, radius2=0.19)
    return build


def shaker_lids(bm):
    for x in SLOTS:
        H.cylinder(bm, Vector((MX + x, -0.85, SHELVES[0] + 0.2 + 0.745)), 0.22, 0.17, segments=12)
        H.cylinder(bm, Vector((MX + x + 0.08, -0.85, SHELVES[0] + 0.2 + 0.87)), 0.06, 0.08, segments=8, radius2=0.04)


B.piece("MerchWall_ShakerA", BLACK, shakers(0))
B.piece("MerchWall_ShakerB", YELLOW, shakers(1))
B.piece("MerchWall_ShakerC", BLUE, shakers(2))
B.piece("MerchWall_Lids", WHITE, shaker_lids)


def shirts(colour):
    # Stacks of three folded shirts on the lower two shelves; the colours run along each stack.
    def build(bm):
        for shelf, h in enumerate(SHELVES[1:], start=2):
            for item, x in enumerate(SLOTS):
                for fold in range(3):
                    if (item + fold + shelf) % 4 == colour:
                        H.rounded_box(bm, Vector((MX + x, -0.85, h + 0.2 + fold * 0.3 + 0.14)),
                                      Vector((1.4, 1.0, 0.28)), 0.07, 1)
    return build


B.piece("MerchWall_ShirtA", BLACK, shirts(0))
B.piece("MerchWall_ShirtB", WHITE, shirts(1))
B.piece("MerchWall_ShirtC", RED, shirts(2))
B.piece("MerchWall_ShirtD", NAVY, shirts(3))
B.piece("MerchWall_Lettering", YELLOW, lambda bm: B.add_text(
    bm, "CENTRAL", 0.9, 0.012, H.on_front(Vector((MX, 0, 0)), -0.2, 9.05)))

# ------------------------------------------------------------------ FloodLamp (x = 60)
# The wall is y = 0, the street -Y. A wall plate, an arm 2.2 out, and the head 2.4 out, tilted 35 degrees so its
# lens looks down and back at the sign below (as the old block lamp).
FX = 60.0
HEAD_TILT = Matrix.Rotation(math.radians(35), 4, "X")
HEAD = Vector((FX, -2.4, 0))


def lamp_arm(bm):
    H.rounded_box(bm, Vector((FX, -0.03, 0)), Vector((0.36, 0.06, 0.36)), 0.02, 1)
    H.cylinder(bm, Vector((FX, -1.12, 0)), 0.06, 2.2, axis="Y", segments=8)


B.piece("FloodLamp_Arm", STEEL, lamp_arm)
B.piece("FloodLamp_Head", BLACK, lambda bm: H.rounded_box(bm, HEAD, Vector((0.8, 0.8, 0.5)), 0.05, 1, rotation=HEAD_TILT))
B.piece("FloodLamp_Lens", GLOW, lambda bm: H.box(
    bm, HEAD + HEAD_TILT @ Vector((0, 0, -0.255)), Vector((0.66, 0.66, 0.02)), HEAD_TILT), smooth=False)

print("Reception_01 built:", sorted(o.name for o in B.coll.objects))
