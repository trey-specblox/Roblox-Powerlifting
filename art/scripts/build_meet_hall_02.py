# Builds MeetHall_02: the Local meet's entrance building outside the gym, BIGGER (user 2026-11-18: "for local meet
# building, expand the model/shell and make the meet timer stack up"). The same design as MeetHall in
# build_local_meet_01.py (charcoal walls under a PITCHED black gable roof with yellow edges and CENTRAL in the front gable,
# an entrance porch with its own small gable, glass double doors in a black frame under a light strip, wall lamps, the
# gym's red competition stripe, navy front panels, high windows, glowing corner strips), scaled up:
#   hall 60 x 44 (was 40 x 30), walls 22 high (16), ridge 33 (24); porch 24 x 6, walls 11, gable to 14 (18 x 5, 9, 11).
# NO sign on the wall: the building's name and every meet's timer float in big text above its roof
# (StyledScreen.floatAbove, LocalMeetVenue). One item, MeetHallBig (letters only: the game reads an item's name as the letters before its first '_'), so LocalMeet_01's other items (the referees' light
# boxes, bleachers, podium, plate trees, the old MeetHall) stay as they are.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, the item stands on z = 0 with its front toward -Y,
# centred on x = 0. Objects are "MeetHallBig_<Piece>" with ONE material each.
#
#   blender -b --factory-startup --python art/scripts/build_meet_hall_02.py -- <out.blend> [<preview.png>] [<out.glb>]

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop_helpers as H  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_BLEND = argv[0] if len(argv) > 0 else None
PREVIEW = argv[1] if len(argv) > 1 else None
OUT_GLB = argv[2] if len(argv) > 2 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
B = H.Builder("MeetHall_02")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, emission=None, alpha=1.0):
    return H.material("MH2_" + name, tuple(linear(c) for c in rgb), metallic, roughness, alpha, emission)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways, as MeetHall's).
NAVY = mat("Navy", (30, 48, 98))
BLACK = mat("Black", (22, 22, 24))
CHARCOAL = mat("Charcoal", (46, 48, 54))
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)
WHITE = mat("White", (236, 236, 232), 0.0, 0.4)
RED = mat("Red", (200, 30, 38), 0.0, 0.45)
STEEL = mat("Steel", (190, 192, 198), 1.0, 0.3)
GREY = mat("Grey", (176, 180, 186), 0.0, 0.8)
GLOW = mat("Glow", (255, 250, 240), 0.0, 0.3, emission=(1.0, 0.98, 0.94))
WARM = mat("Warm", (255, 205, 150), 0.0, 0.3, emission=(1.0, 0.8, 0.6))
GLASS = mat("Glass", (205, 225, 235), 0.0, 0.1, alpha=0.35)


def italic_front(x0, y_front, z_mid, k=0.18):
    """place() for text on a front face (toward -Y), leaned like the UI's heavy italic headings."""
    def place(x, up, depth):
        return Vector((x0 + x + k * up, y_front - depth, z_mid + up))
    return place


HX = 0.0
HW, HD = 60.0, 44.0
EAVE, RIDGE = 22.0, 33.0
FRONT = -HD / 2
OVER_SIDE, OVER_END, ROOF_T = 1.6, 1.3, 0.8
PW, PD, PH, P_RIDGE = 24.0, 6.0, 11.0, 14.0
P_FRONT = FRONT - PD
DOOR_W, DOOR_H = 9.6, 8.6
STRIPE_Z = 3.6           # the red stripe's middle (the navy panels start above it)
PANEL_LOW = 4.6


def prism_y(bm, outline, y0, y1, x0=0.0):
    """A closed solid: the (x, z) polygon `outline` (convex, any winding) from y = y0 to y = y1, faces outward."""
    tmp = bmesh.new()
    a = [tmp.verts.new((x0 + x, y0, z)) for x, z in outline]
    b = [tmp.verts.new((x0 + x, y1, z)) for x, z in outline]
    tmp.faces.new(a)
    tmp.faces.new(list(reversed(b)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def gable_slabs(bm, half_w, eave, ridge, over, t, y0, y1, x0):
    """Two roof slabs (vertical thickness t) from the ridge down past both eaves by `over`."""
    slope = (ridge - eave) / half_w
    for side in (-1, 1):
        xo = side * (half_w + over)
        zo = ridge - (half_w + over) * slope
        prism_y(bm, [(0.0, ridge), (xo, zo), (xo, zo + t), (0.0, ridge + t)], y0, y1, x0)


def walls(bm):
    H.box(bm, Vector((HX, 0, EAVE / 2)), Vector((HW, HD, EAVE)))
    prism_y(bm, [(-HW / 2, EAVE), (HW / 2, EAVE), (0.0, RIDGE)], -HD / 2, HD / 2, HX)
    H.span(bm, Vector((HX - PW / 2, P_FRONT, 0)), Vector((HX + PW / 2, FRONT + 0.2, PH)))
    prism_y(bm, [(-PW / 2, PH), (PW / 2, PH), (0.0, P_RIDGE)], P_FRONT, FRONT + 0.2, HX)


def roofs(bm):
    gable_slabs(bm, HW / 2, EAVE, RIDGE, OVER_SIDE, ROOF_T, -HD / 2 - OVER_END, HD / 2 + OVER_END, HX)
    gable_slabs(bm, PW / 2, PH, P_RIDGE, 0.9, 0.5, P_FRONT - 0.9, FRONT, HX)


def roof_trim(bm):
    for half_w, eave, ridge, over, t, y in ((HW / 2, EAVE, RIDGE, OVER_SIDE, ROOF_T, -HD / 2 - OVER_END),
                                            (PW / 2, PH, P_RIDGE, 0.9, 0.5, P_FRONT - 0.9)):
        slope = (ridge - eave) / half_w
        for side in (-1, 1):
            xo = side * (half_w + over)
            zo = ridge - (half_w + over) * slope
            prism_y(bm, [(0.0, ridge - 0.05), (xo, zo - 0.05), (xo, zo + t + 0.05), (0.0, ridge + t + 0.05)],
                    y - 0.1, y, HX)


def stripes(bm, z, height, inset):
    H.box(bm, Vector((HX, FRONT - inset, z)), Vector((HW + 2 * inset, 2 * inset, height)))
    H.box(bm, Vector((HX, -FRONT + inset, z)), Vector((HW + 2 * inset, 2 * inset, height)))
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (HW / 2 + inset / 2), 0, z)), Vector((inset, HD, height)))
    H.box(bm, Vector((HX, P_FRONT - inset, z)), Vector((PW + 2 * inset, 2 * inset, height)))
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (PW / 2 + inset / 2), (P_FRONT + FRONT) / 2, z)), Vector((inset, PD, height)))


def door_frame(bm):
    y = P_FRONT - 0.2
    H.box(bm, Vector((HX, y, DOOR_H + 0.25)), Vector((DOOR_W + 0.9, 0.45, 0.5)))
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (DOOR_W / 2 + 0.22), y, (DOOR_H + 0.5) / 2)), Vector((0.45, 0.45, DOOR_H + 0.5)))
    H.box(bm, Vector((HX, y, DOOR_H / 2)), Vector((0.18, 0.32, DOOR_H)))


def doors(bm):
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * DOOR_W / 4, P_FRONT - 0.25, DOOR_H / 2)), Vector((DOOR_W / 2 - 0.22, 0.1, DOOR_H)))


def handles(bm):
    for side in (-1, 1):
        H.cylinder(bm, Vector((HX + side * 0.55, P_FRONT - 0.42, 4.1)), 0.07, 2.5, segments=8)


def wall_lamps(bm):
    for side in (-1, 1):
        H.rounded_box(bm, Vector((HX + side * 8.4, P_FRONT - 0.2, 7.2)), Vector((0.7, 0.45, 1.6)), 0.08, 2)


def windows(bm):
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (HW / 2 + 0.05), 0, 16.0)), Vector((0.1, HD - 10.0, 3.0)))
    # (and two high windows on the front, either side of the porch roof)
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * 20.0, FRONT - 0.06, 16.0)), Vector((10.0, 0.1, 3.0)))


def corner_lights(bm):
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (HW / 2 - 0.35), FRONT - 0.07, (PANEL_LOW + EAVE - 0.4) / 2)),
              Vector((0.35, 0.14, EAVE - 0.4 - PANEL_LOW)))


B.piece("MeetHallBig_Walls", CHARCOAL, walls, smooth=False)
B.piece("MeetHallBig_Roof", BLACK, roofs, smooth=False)
B.piece("MeetHallBig_RoofTrim", YELLOW, roof_trim, smooth=False)
B.piece("MeetHallBig_GableLogo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 3.4, 0.04, italic_front(HX, FRONT - 0.02, EAVE + 3.6)), smooth=False)
B.piece("MeetHallBig_Stripe", RED, lambda bm: stripes(bm, STRIPE_Z, 1.0, 0.06), smooth=False)
B.piece("MeetHallBig_Pinstripe", WHITE, lambda bm: stripes(bm, STRIPE_Z + 0.66, 0.14, 0.06), smooth=False)
# The navy panels: the hall's front either side of and above the porch, and the porch's front round the doors.
B.piece("MeetHallBig_Facade", NAVY, lambda bm: (
    H.box(bm, Vector((HX, FRONT - 0.05, (PANEL_LOW + EAVE) / 2)), Vector((HW - 6.0, 0.1, EAVE - PANEL_LOW))),
    H.box(bm, Vector((HX, P_FRONT - 0.05, (PANEL_LOW + PH) / 2)), Vector((PW - 1.2, 0.1, PH - PANEL_LOW)))), smooth=False)
B.piece("MeetHallBig_DoorFrame", BLACK, door_frame, smooth=False)
B.piece("MeetHallBig_Inside", BLACK, lambda bm: H.box(
    bm, Vector((HX, P_FRONT - 0.14, DOOR_H / 2)), Vector((DOOR_W, 0.04, DOOR_H))), smooth=False)
B.piece("MeetHallBig_Doors", GLASS, doors, smooth=False)
B.piece("MeetHallBig_Handles", STEEL, handles)
B.piece("MeetHallBig_DoorLight", GLOW, lambda bm: H.box(
    bm, Vector((HX, P_FRONT - 0.12, PH - 0.4)), Vector((PW - 2.4, 0.12, 0.22))), smooth=False)
B.piece("MeetHallBig_Landing", GREY, lambda bm: H.box(
    bm, Vector((HX, P_FRONT - 3.0, 0.15)), Vector((PW + 3.0, 6.0, 0.3))), smooth=False)
B.piece("MeetHallBig_Lamps", WARM, wall_lamps)
B.piece("MeetHallBig_Windows", GLASS, windows, smooth=False)
B.piece("MeetHallBig_CornerLights", GLOW, corner_lights, smooth=False)

bpy.context.view_layer.update()
lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
tris = 0
for o in B.coll.objects:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
print("BOUNDS MeetHallBig tris=%d low=(%.2f, %.2f, %.2f) high=(%.2f, %.2f, %.2f) bottomcentre=(%.2f, %.2f, %.2f)" % (
    tris, lo.x, lo.y, lo.z, hi.x, hi.y, hi.z, (lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
print("FRONT (the hall's front wall, y) %.2f; PORCH FRONT %.2f" % (FRONT, P_FRONT))

if PREVIEW:
    for m in bpy.data.materials:
        m.use_backface_culling = True
    scene = bpy.context.scene
    world = bpy.data.worlds.new("MH2_World")
    world.use_nodes = True
    next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.55, 0.7, 0.95, 1)
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 24
    cam.location = (-38, -78, 14)
    cam.rotation_euler = (Vector((0, 0, 14)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)

if OUT_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("saved", OUT_BLEND)
if OUT_GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for o in B.coll.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_apply=True)
    print("exported", OUT_GLB)
