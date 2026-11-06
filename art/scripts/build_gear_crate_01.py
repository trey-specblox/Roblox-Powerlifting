# Builds GearCrate_01: the CENTRAL gear crates that drop onto a lifting platform and pop open before the crate reel
# (GAME_DESIGN 35.12, user 2026-11-06). Our own design: a heavy road case, not a copy of any other game's case. One model for
# all four crates (belt, wrist wrap, singlet, knee sleeve): the game colours the Body and Lid for the crate
# (GearStatsConfig.Crates) and keeps only that crate's Label and LidLabel pieces.
#
#   GearCrate  a case with steel rails, chunky yellow corners, side handles and rubber feet. Big lettering on its front and
#              top (user 2026-11-06): CENTRAL, and the item in yellow under it, the biggest thing on the crate.
#              Hollow, with a Glow slab inside that the game lights when the lid opens.
#              On a lifting platform (wood centre, rubber sides) with two bumper plates lying beside it.
#
# The lid's pieces (Lid*) and the two latches are separate objects so the game can swing them. The lid hinges along the
# body's back top edge, each latch along its own bottom edge.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, it stands on z = 0 with its front toward -Y.
# Objects are "<Item>_<Piece>" with ONE material each.
#
#   blender -b --python art/scripts/build_gear_crate_01.py -- <out.blend> <out.glb> <preview.png>
# Then, before uploading: blender -b <out.blend> --python art/scripts/check_models.py (must say CHECK PASSED).

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

# (Blender's start-up scene, so nothing but the crate ends up in the file.)
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("GearCrate_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5):
    return H.material("GC_" + name, tuple(linear(c) for c in rgb), metallic, roughness)


# Preview colours (Roblox colours each piece from the code).
NAVY = mat("Navy", (28, 44, 100), 0.1, 0.5)
STEEL = mat("Steel", (190, 195, 205), 1.0, 0.3)
YELLOW = mat("Yellow", (250, 205, 40), 0.0, 0.4)
RUBBER = mat("Rubber", (24, 24, 28), 0.0, 0.85)
WHITE = mat("White", (240, 240, 236), 0.0, 0.5)
GLOW = mat("Glow", (255, 225, 110), 0.0, 0.5)
WOOD = mat("Wood", (176, 128, 78), 0.0, 0.7)
RED = mat("PlateRed", (205, 40, 45), 0.0, 0.55)
BLUE = mat("PlateBlue", (35, 95, 205), 0.0, 0.55)

# The platform, then the crate on it.
PLATFORM_Z = 0.3
WIDE, DEEP = 4.6, 3.2
FEET = 0.14
Z0 = PLATFORM_Z + FEET
TALL = 2.0
RIM = Z0 + TALL
LID_TALL = 0.8
WALL = 0.16
LID_TOP = RIM + LID_TALL
HW, HD = WIDE / 2, DEEP / 2
PROUD = 0.05  # how far the steel rails stand off the shell
LATCH_X = 1.62


def rails(bm, z_low, z_high):
    """A steel band round the case between two heights."""
    x, y = HW + PROUD, HD + PROUD
    H.span(bm, (-x, -y, z_low), (x, -HD + 0.02, z_high))
    H.span(bm, (-x, HD - 0.02, z_low), (x, y, z_high))
    H.span(bm, (-x, -y, z_low), (-HW + 0.02, y, z_high))
    H.span(bm, (HW - 0.02, -y, z_low), (x, y, z_high))


def corners(bm, z_low, z_high):
    """Chunky yellow caps on the case's four corners between two heights."""
    size = 0.52
    for sx in (-1, 1):
        for sy in (-1, 1):
            at = Vector((sx * (HW + PROUD - size / 2 + 0.05), sy * (HD + PROUD - size / 2 + 0.05), (z_low + z_high) / 2))
            H.rounded_box(bm, at, Vector((size, size, z_high - z_low)), 0.07, 1)


def shell(bm):
    # Hollow: a floor and four walls, so the case has a real inside when the lid is up.
    H.span(bm, (-HW, -HD, Z0), (HW, HD, Z0 + WALL))
    H.span(bm, (-HW, -HD, Z0), (HW, -HD + WALL, RIM - 0.012))
    H.span(bm, (-HW, HD - WALL, Z0), (HW, HD, RIM - 0.012))
    H.span(bm, (-HW, -HD, Z0), (-HW + WALL, HD, RIM - 0.012))
    H.span(bm, (HW - WALL, -HD, Z0), (HW, HD, RIM - 0.012))


def glow(bm):
    # What the game lights: a slab just under the rim.
    z = RIM - 0.3
    H.span(bm, (-HW + WALL + 0.01, -HD + WALL + 0.01, z), (HW - WALL - 0.01, HD - WALL - 0.01, z + 0.08))


def handles(bm):
    for side in (-1, 1):
        for y in (-0.62, 0.62):
            H.span(bm, (side * HW, y - 0.08, Z0 + 1.08), (side * (HW + 0.3), y + 0.08, Z0 + 1.24))
    # (The grips are rubber: see rubber().)


def hinges(bm):
    for x in (-1.4, 0, 1.4):
        H.cylinder(bm, Vector((x, HD + 0.09, RIM)), 0.09, 0.62, axis="X", segments=10)


def steel(bm):
    rails(bm, Z0, Z0 + 0.2)
    rails(bm, RIM - 0.18, RIM)
    # Upright rails between the corners' caps.
    for sx in (-1, 1):
        for sy in (-1, 1):
            at = Vector((sx * (HW + PROUD - 0.14), sy * (HD + PROUD - 0.14), (Z0 + RIM) / 2))
            H.box(bm, at, Vector((0.28, 0.28, TALL - 0.1)))
    handles(bm)
    hinges(bm)
    # The plates the latches are bolted to.
    for x in (-LATCH_X, LATCH_X):
        H.span(bm, (x - 0.3, -HD - PROUD - 0.03, RIM - 0.62), (x + 0.3, -HD + 0.02, RIM - 0.36))


def yellow(bm):
    corners(bm, Z0 - 0.02, Z0 + 0.5)
    corners(bm, RIM - 0.5, RIM + 0.012)
    # A stripe round the case, above the bottom rail.
    x, y = HW + 0.015, HD + 0.015
    z_low, z_high = Z0 + 0.3, Z0 + 0.42
    H.span(bm, (-x, -y, z_low), (x, -HD + 0.02, z_high))
    H.span(bm, (-x, HD - 0.02, z_low), (x, y, z_high))
    H.span(bm, (-x, -y, z_low), (-HW + 0.02, y, z_high))
    H.span(bm, (HW - 0.02, -y, z_low), (x, y, z_high))


def rubber(bm):
    # Feet under the corners and the handles' grips.
    for sx in (-1, 1):
        for sy in (-1, 1):
            H.cylinder(bm, Vector((sx * (HW - 0.34), sy * (HD - 0.34), PLATFORM_Z + FEET / 2 + 0.01)), 0.22, FEET + 0.02, segments=12)
    for side in (-1, 1):
        H.span(bm, (side * (HW + 0.24), -0.82, Z0 + 1.06), (side * (HW + 0.38), 0.82, Z0 + 1.26))


def logo(bm):
    # CENTRAL across the front, over the item's name.
    B.add_text(bm, H.BRAND, 0.5, 0.012, H.on_front((0, 0, 0), -HD, Z0 + 1.36))


def latch(x):
    def build(bm):
        # A toggle latch: bolted below the rim, its hook reaching up over the lid's catch.
        H.rounded_box(bm, Vector((x, -HD - PROUD - 0.075, RIM - 0.1)), Vector((0.34, 0.09, 0.76)), 0.03, 1)
        H.cylinder(bm, Vector((x, -HD - PROUD - 0.09, RIM - 0.47)), 0.075, 0.4, axis="X", segments=10)
        H.span(bm, (x - 0.17, -HD - PROUD - 0.14, RIM + 0.2), (x + 0.17, -HD - PROUD - 0.03, RIM + 0.28))

    return build


def lid(bm):
    H.rounded_box(bm, Vector((0, 0, RIM + LID_TALL / 2)), Vector((WIDE, DEEP, LID_TALL)), 0.07, 2)


def lid_steel(bm):
    rails(bm, RIM + 0.014, RIM + 0.16)
    # Two ribs over the top.
    for x in (-1.72, 1.72):
        H.span(bm, (x - 0.13, -HD - 0.01, LID_TOP - 0.04), (x + 0.13, HD + 0.01, LID_TOP + 0.03))
    # The catches the latches hook onto.
    for x in (-LATCH_X, LATCH_X):
        H.span(bm, (x - 0.24, -HD - PROUD - 0.04, RIM + 0.12), (x + 0.24, -HD + 0.02, RIM + 0.34))


def lid_yellow(bm):
    corners(bm, RIM + 0.03, LID_TOP + 0.04)


def lid_top(x, up, depth):
    return Vector((x, up, LID_TOP + depth))


def label(text):
    # The item, big, on the front under CENTRAL.
    def build(bm):
        B.add_text(bm, text, 0.78 if len(text) < 9 else 0.56, 0.014, H.on_front((0, 0, 0), -HD, Z0 + 0.8))

    return build


def lid_label(text):
    # The item again on the lid's top, under its CENTRAL.
    def build(bm):
        B.add_text(bm, text, 0.6 if len(text) < 9 else 0.42, 0.014, lambda x, up, depth: lid_top(x, up - 0.42, depth))

    return build


# Short enough to be big: each fits between the case's upright rails.
LABELS = {"Belt": "BELTS", "WristWraps": "WRAPS", "Singlet": "SINGLETS", "KneeSleeves": "SLEEVES", "KneeWraps": "KNEE WRAPS"}
# The crates' colours, as GearStatsConfig.Crates has them.
CRATE_COLOURS = {"Belt": (28, 44, 100), "WristWraps": (150, 28, 36), "Singlet": (16, 110, 110), "KneeSleeves": (44, 46, 54), "KneeWraps": (30, 100, 50)}


def lid_logo(bm):
    # CENTRAL on the lid's top, and what kind of crate it is on the lid's front, between the latches.
    B.add_text(bm, H.BRAND, 0.56, 0.012, lambda x, up, depth: lid_top(x, up + 0.55, depth))
    B.add_text(bm, "GEAR CRATE", 0.34, 0.012, H.on_front((0, 0, 0), -HD, RIM + 0.48))


PLATFORM_WOOD = 2.9
PLATFORM_RUBBER = 2.6
PLATFORM_DEEP = 3.6


def wood(bm):
    # Three boards down the middle, with a gap between them.
    for k in (-1, 0, 1):
        x = k * PLATFORM_WOOD * 2 / 3
        H.span(bm, (x - PLATFORM_WOOD / 3 + 0.015, -PLATFORM_DEEP, 0.0), (x + PLATFORM_WOOD / 3 - 0.015, PLATFORM_DEEP, PLATFORM_Z))


def platform_rubber(bm):
    for side in (-1, 1):
        H.span(bm, (side * PLATFORM_WOOD, -PLATFORM_DEEP, 0.0), (side * (PLATFORM_WOOD + PLATFORM_RUBBER), PLATFORM_DEEP, PLATFORM_Z))


def plate(radius, z_low, thick, x, y):
    def build(bm):
        # A bumper plate lying flat, with its hub's hole.
        z = z_low
        H.lathe_z(bm, [(0.2, z), (radius - 0.04, z), (radius, z + 0.04), (radius, z + thick - 0.04), (radius - 0.04, z + thick),
                       (0.2, z + thick)], 28, Vector((x, y, 0)))

    return build


objects = [
    B.piece("GearCrate_Body", NAVY, shell, smooth=False),
    B.piece("GearCrate_Steel", STEEL, steel, smooth=False),
    B.piece("GearCrate_Yellow", YELLOW, yellow, smooth=False),
    B.piece("GearCrate_Rubber", RUBBER, rubber, smooth=False),
    B.piece("GearCrate_Logo", WHITE, logo, smooth=False),
    B.piece("GearCrate_Glow", GLOW, glow, smooth=False),
    B.piece("GearCrate_LatchLeft", STEEL, latch(-LATCH_X), smooth=False),
    B.piece("GearCrate_LatchRight", STEEL, latch(LATCH_X), smooth=False),
    B.piece("GearCrate_Lid", NAVY, lid, smooth=False),
    B.piece("GearCrate_LidSteel", STEEL, lid_steel, smooth=False),
    B.piece("GearCrate_LidYellow", YELLOW, lid_yellow, smooth=False),
    B.piece("GearCrate_LidLogo", WHITE, lid_logo, smooth=False),
    *[B.piece("GearCrate_Label" + crate, YELLOW, label(text), smooth=False) for crate, text in LABELS.items()],
    *[B.piece("GearCrate_LidLabel" + crate, YELLOW, lid_label(text), smooth=False) for crate, text in LABELS.items()],
    B.piece("GearCrate_PlatformWood", WOOD, wood, smooth=False),
    B.piece("GearCrate_PlatformRubber", RUBBER, platform_rubber, smooth=False),
    B.piece("GearCrate_PlateRed", RED, plate(1.25, PLATFORM_Z, 0.34, 4.0, 0.7)),
    B.piece("GearCrate_PlateBlue", BLUE, plate(1.05, PLATFORM_Z + 0.34, 0.28, 4.05, 0.75)),
]

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) >= 1:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True)
if len(argv) >= 3:
    # Previews as Roblox draws it (one-sided faces): each crate shut, then from behind and with the lid and latches open as
    # the game will swing them.
    scene = bpy.context.scene
    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 50
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_backface_culling = True
    scene.display.shading.show_shadows = False
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.12, 0.13, 0.18)
    scene.display.shading.background_type = "WORLD"
    scene.render.resolution_x, scene.render.resolution_y = 1000, 720
    root, ext = os.path.splitext(argv[2])

    def shoot(suffix, eye, target):
        camera.location = Vector(eye)
        camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = root + suffix + ext
        bpy.ops.render.render(write_still=True)

    def dress(crate):
        NAVY.diffuse_color = (*(linear(c) for c in CRATE_COLOURS[crate]), 1.0)
        for other in LABELS:
            bpy.data.objects["GearCrate_Label" + other].hide_render = other != crate
            bpy.data.objects["GearCrate_LidLabel" + other].hide_render = other != crate

    for crate in reversed(list(LABELS)):
        dress(crate)
        shoot("_" + crate, (5.2, -11.5, 6.6), (0.5, 0, 1.5))
    shoot("_Back", (-7, 9.5, 6.0), (0, 0, 1.5))

    def swing(ob, hinge, angle):
        ob.matrix_world = Matrix.Translation(hinge) @ Matrix.Rotation(angle, 4, "X") @ Matrix.Translation(-hinge) @ ob.matrix_world

    for name in ("Lid", "LidSteel", "LidYellow", "LidLogo", *("LidLabel" + crate for crate in LABELS)):
        swing(bpy.data.objects["GearCrate_" + name], Vector((0, HD, RIM)), math.radians(-105))
    for name in ("LatchLeft", "LatchRight"):
        swing(bpy.data.objects["GearCrate_" + name], Vector((0, -HD - PROUD, RIM - 0.47)), math.radians(100))
    bpy.context.view_layer.update()
    shoot("_Open", (5.2, -11.5, 8.0), (0.5, 0, 2.0))

print("GearCrate_01 built:", sorted(o.name for o in B.coll.objects))
print("DONE")
