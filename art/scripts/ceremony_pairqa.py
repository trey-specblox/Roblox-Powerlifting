# READ-ONLY pair check of the podium ceremony clips (ceremony_animations.py) on the real bodies, run through
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/ceremony_animations.py -- pairqa <out dir>
# The lifter wears the meet outfit (the game's newest exports, as anim_qa), the referee is the Fat staff body in his tee,
# joggers and sneakers (MeetFigures "Referee"). Both posed exactly as the game does (gear_fit_03.pose_rig), the head
# turned by the Neck (the stand-in head), the game's hand swaps shown (Grip on the referee while he holds the ribbon /
# the trophy's stem). Fits the referee's spot per lifter build, measures every keyframe (bodies, hands, props), and
# renders pair pictures (front three-quarter, side, close-ups). Nothing is saved to the .blend.
#   env CER_CLIPS=Medal,Handshake,Trophy,StepUp   CER_LIFTERS=Skinny,...   CER_PICTURES=Skinny,Fat,BigBuff
#       CER_ANIMS=<folder with the clips> (default art/animations)   CER_FIT=0 (use C.PLACEMENT as it is)
import glob
import math
import os

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
OUTFIT = ("Tee", "WornSinglet_Black", "WornSinglet_Red", "WornSinglet_Shorts", "WornSinglet_Trim",
          "WornLeverBelt_Outer", "WornLeverBelt_Lining", "WornLeverBelt_Lever")
REF_CLOTHES = ("Tee", "Joggers", "Sneakers")
SWAPS = ("Fist", "Grip", "SquatGrip", "Point", "ThumbsUp")
BODY = ["UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftUpperArm",
        "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]
TO_B = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
RAYS = [Vector(d).normalized() for d in ((0.31, 0.93, 0.19), (-0.27, -0.35, 0.9), (0.12, -0.95, -0.29))]


def run(C, out):
    os.makedirs(os.path.join(out, "tiles"), exist_ok=True)
    G = {"__name__": "gear_fit_03"}
    exec(open(os.path.join(ROOT, "art", "scripts", "gear_fit_03.py"), encoding="utf-8").read(), G)
    G["ANIMS"] = os.environ.get("CER_ANIMS", os.path.join(ROOT, "art", "animations"))
    clips = [c for c in os.environ.get("CER_CLIPS", "Medal,Handshake,Trophy,StepUp").split(",") if c]
    lifters = [b for b in os.environ.get("CER_LIFTERS", ",".join(C.LIFTERS)).split(",") if b]
    pictured = [b for b in os.environ.get("CER_PICTURES", "Skinny,Fat,BigBuff").split(",") if b]
    do_fit = os.environ.get("CER_FIT", "1") != "0"
    sc = bpy.context.scene

    def mat(name, rgba):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.diffuse_color = rgba
        return m

    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            o.location = (500, 500, 0)
        if o.parent is not None and any(s in o.name for s in SWAPS):
            o.hide_render = True

    # ---------------------------------------------------------------- figures
    def dress(rig, build, items, tints=None):
        before = set(bpy.data.objects)
        for kind in ("Clothes", "Gear"):
            found = sorted(glob.glob(os.path.join(ROOT, "art", "exports", "Cartoon%s[0-9][0-9]_%s.glb" % (kind, build))))
            if found:
                bpy.ops.import_scene.gltf(filepath=found[-1])
        kept = []
        ref = [c for c in rig.children if c.name.endswith("_UpperTorso")][0]
        rel = ref.matrix_parent_inverse @ ref.matrix_basis
        for o in [o for o in bpy.data.objects if o not in before]:
            item = o.name.partition("__")[0]
            if o.type == "MESH" and item in items:
                o.data.transform(rel.inverted() @ o.matrix_world)
                o.parent = rig
                o.matrix_parent_inverse = ref.matrix_parent_inverse.copy()
                o.matrix_basis = ref.matrix_basis.copy()
                for m in o.modifiers:
                    if m.type == "ARMATURE":
                        m.object = rig
                if tints and item in tints:
                    o.data = o.data.copy()
                    o.data.materials.clear()
                    o.data.materials.append(tints[item])
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

    class Fig:
        def __init__(self, rig, parts, swaps, clothes, build):
            self.rig, self.parts, self.swaps, self.clothes, self.build = rig, parts, swaps, clothes, build
            self.J = {b.name: TO_B @ b.head_local for b in rig.data.bones}
            self.head = parts.get("StandInHead")
            self.head_rest = None

        def place(self, m):
            self.rig.matrix_world = m
            if self.head is not None and self.head_rest is not None:     # (the unparented stand-in head goes along)
                self.head.matrix_world = m @ self.head_rest
            bpy.context.view_layer.update()

        def rest_head(self):
            G["rest_rig"](self.rig)
            if self.head is not None and self.head_rest is None:
                mw = self.head.matrix_world.copy()
                self.head.parent = None
                self.head.matrix_world = mw
                self.head_rest = self.rig.matrix_world.inverted() @ mw

        def frames(self, tf):
            w = {"HumanoidRootNode": Matrix.Translation(self.J["HumanoidRootNode"])}
            for part in ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                                         ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]:
                par = G["PARENT"][part]
                w[part] = w[par] @ Matrix.Translation(self.J[part] - self.J[par]) @ tf.get(part, Matrix.Identity(4))
            return w

        def pose(self, name, t):
            tf = G["anim_at"](name, t)
            G["pose_rig"](self.rig, tf)
            w = self.frames(tf)
            if self.head is not None and self.head_rest is not None:
                neck = Vector((0, 4.7, 0))
                d = w["UpperTorso"] @ Matrix.Translation(neck - self.J["UpperTorso"]) @ tf.get("Head", Matrix.Identity(4)) \
                    @ Matrix.Translation(-neck)
                self.head.matrix_world = self.rig.matrix_world @ TO_B @ d @ TO_B @ self.head_rest
            bpy.context.view_layer.update()
            self.w = w
            return w

        def show(self, side, shape):
            self.parts[side + "Hand"].hide_render = shape is not None
            for s in SWAPS:
                o = self.swaps.get(s + side)
                if o:
                    o.hide_render = s != shape

        def hand_obj(self, side):
            for s in SWAPS:
                o = self.swaps.get(s + side)
                if o is not None and not o.hide_render:
                    return o
            return self.parts[side + "Hand"]

        def at(self, part, local):
            """A point given from the part's joint in the part's frame (Roblox rig space) -> Blender world."""
            return self.rig.matrix_world @ (TO_B @ (self.w[part] @ Vector(local)))

        def to_rig(self, p_world):
            return TO_B @ (self.rig.matrix_world.inverted() @ p_world)

    lifter_figs = {}

    def lifter_fig(b):
        if b not in lifter_figs:
            rig = bpy.data.objects[b + "Rig"]
            parts = {c.name.partition("_")[2]: c for c in rig.children if not any(s in c.name for s in SWAPS)}
            swaps = {c.name.partition("_")[2]: c for c in rig.children if any(s in c.name for s in SWAPS)}
            f = Fig(rig, parts, swaps, dress(rig, b, OUTFIT), b)
            f.place(Matrix.Translation((500, 500, 0)))
            f.rest_head()
            lifter_figs[b] = f
        return lifter_figs[b]

    ref_skin = mat("CerRefSkin", (0.40, 0.26, 0.18, 1))
    tints = {"Tee": mat("CerRefTee", (0.9, 0.9, 0.88, 1)), "Joggers": mat("CerRefJoggers", (0.05, 0.05, 0.06, 1)),
             "Sneakers": mat("CerRefShoes", (0.08, 0.08, 0.09, 1))}

    def ref_fig():
        src = bpy.data.objects[C.REF_BUILD + "Rig"]
        rig = src.copy()
        rig.data = src.data.copy()
        rig.name = "CerRefRig"
        sc.collection.objects.link(rig)
        parts, swaps = {}, {}
        for c in src.children:
            n = c.copy()
            n.name = "CerRef_" + c.name.partition("_")[2]
            sc.collection.objects.link(n)
            n.parent = rig
            n.parent_type, n.parent_bone = c.parent_type, c.parent_bone
            n.matrix_parent_inverse = c.matrix_parent_inverse.copy()
            for m in n.modifiers:
                if m.type == "ARMATURE":
                    m.object = rig
            key = c.name.partition("_")[2]
            if n.type == "MESH" and (key in ("StandInHead",) or "Hand" in key or "LowerArm" in key or
                                     any(s in key for s in SWAPS)):
                n.data = n.data.copy()
                n.data.materials.clear()
                n.data.materials.append(ref_skin)
            (swaps if any(s in key for s in SWAPS) else parts)[key] = n
        f = Fig(rig, parts, swaps, dress(rig, C.REF_BUILD, REF_CLOTHES, tints), C.REF_BUILD)
        f.place(Matrix.Translation((500, 500, 0)))
        f.rest_head()
        return f

    ref = ref_fig() if any(c in clips for c in ("Medal", "Handshake", "Trophy")) else None

    # ---------------------------------------------------------------- props: the trophy (the real model), the medal
    # (a QA stand-in only: a disc on two ribbon strands; the real worn/held medal models are still to be made)
    trophy = []
    if "Trophy" in clips:
        with bpy.data.libraries.load(os.path.join(ROOT, "art", "blender", "Trophy_01.blend")) as (src, dst):
            dst.objects = ["Trophy_Metal", "Trophy_Base"]
        for o in dst.objects:
            sc.collection.objects.link(o)
            o.data = o.data.copy()
            o.data.transform(o.matrix_basis)          # (baked: the model's own origin = the base's bottom centre;
            #  matrix_world is not evaluated yet for a freshly linked object)
            o.matrix_world = Matrix.Identity(4)
            o.parent = None
            trophy.append(o)
        print("[CerQA] trophy z %.3f..%.3f" % (min(v.co.z for o in trophy for v in o.data.vertices),
                                                max(v.co.z for o in trophy for v in o.data.vertices)))
    gold = mat("CerMedalGold", (0.75, 0.55, 0.1, 1))
    ribbon = mat("CerRibbon", (0.75, 0.08, 0.08, 1))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.26, depth=0.05, vertices=24)
    disc = bpy.context.active_object
    disc.data.materials.append(gold)
    strands = []
    for i in range(3):
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        s_ = bpy.context.active_object
        s_.data.materials.append(ribbon)
        strands.append(s_)
    medal_objs = [disc] + strands
    for o in medal_objs:
        o.hide_render = True

    def strand(o, a, b, width=0.12, thick=0.02):
        d = b - a
        o.hide_render = False
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        o.matrix_world = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Diagonal((width, thick, d.length, 1))

    # The REAL medal (another session's build_worn_medal_01.py): HeldMedal_Ribbon + WornMedal_Disc/Text while the referee
    # holds it, WornMedal_Ribbon_<Build> + Disc/Text once it lands (art/exports/WornMedal_01_fit.json). Each export's
    # mesh is in Blender model space about its part's centre (Roblox part space = TO_B @ vertex).
    import json as _json
    fitj = _json.load(open(os.path.join(ROOT, "art", "exports", "WornMedal_01_fit.json")))
    real = {}

    def load_glb(name):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art", "exports", name + ".glb"))
        objs = [o for o in bpy.data.objects if o not in before]
        meshes = [o for o in objs if o.type == "MESH"]
        for o in meshes:
            o.data.transform(o.matrix_basis)
            o.matrix_basis = Matrix.Identity(4)
            o.parent = None
            o.hide_render = True
        for o in objs:
            if o.type != "MESH":
                bpy.data.objects.remove(o, do_unlink=True)
        return meshes

    if "Medal" in clips:
        for n in ["HeldMedal_Ribbon", "WornMedal_Disc", "WornMedal_Text"] + ["WornMedal_Ribbon_" + b for b in C.LIFTERS]:
            real[n] = load_glb(n)
        ut_centre = {}
        for b in C.LIFTERS:
            o = bpy.data.objects[b + "_UpperTorso"]
            rig_ = bpy.data.objects[b + "Rig"]
            vs = [TO_B @ (rig_.matrix_world.inverted() @ o.matrix_world @ v.co) for v in o.data.vertices]
            ut_centre[b] = Vector([(min(v[i] for v in vs) + max(v[i] for v in vs)) / 2 for i in range(3)])
    held = fitj["held"]
    TO_B4 = TO_B

    def cf(row):
        """[x, y, z, R00..R22] (a Roblox CFrame) -> 4x4."""
        m = Matrix(((row[3], row[4], row[5], row[0]), (row[6], row[7], row[8], row[1]), (row[9], row[10], row[11], row[2]),
                    (0, 0, 0, 1)))
        return m

    def show_real(names, M_by_name):
        for n, objs in real.items():
            for o in objs:
                o.hide_render = n not in names
                if n in names:
                    o.matrix_world = M_by_name[n]

    def medal_at(t, lifter, d, x, roll=0.0):
        """The real medal: held between the referee's grip holes until it lands, then worn on the lifter. roll: the
        held loop turned about the line between the grips, its front V swung out toward the referee (degrees)."""
        for o in medal_objs:
            o.hide_render = True
        s = C.HAND_SIZE[C.REF_BUILD]
        if t < C.MEDAL_ON_NECK + 0.01:
            # the held loop's +x hold point in the referee's LEFT fist (the lifter's right), its -z face toward him
            gl = lifter.to_rig(ref.at("LeftHand", C.grip_point("Left", s)))
            gr = lifter.to_rig(ref.at("RightHand", C.grip_point("Right", s)))
            X = (gl - gr).normalized()
            Y = (Vector((0, 1, 0)) - X * X.y).normalized()
            Z = X.cross(Y)
            R = Matrix((X, Y, Z)).transposed().to_4x4() @ Matrix.Rotation(math.radians(roll), 4, "X")
            mid = Vector(held["holdMidpoint"])
            p = (gl + gr) / 2 - (R.to_3x3() @ mid)
            base = lifter.rig.matrix_world @ TO_B4 @ Matrix.Translation(p) @ R
            M = {"HeldMedal_Ribbon": base @ TO_B4,
                 "WornMedal_Disc": base @ Matrix.Translation(Vector(held["Disc"])) @ TO_B4,
                 "WornMedal_Text": base @ Matrix.Translation(Vector(held["Text"])) @ TO_B4}
            show_real(M.keys(), M)
            medal_at.spacing = (gl - gr).length
        else:
            b = lifter.build
            w = fitj["worn"][b]
            c = ut_centre[b] - lifter.J["UpperTorso"]                   # the part's centre from the Waist joint
            ut = lifter.rig.matrix_world @ TO_B4 @ lifter.w["UpperTorso"] @ Matrix.Translation(c)
            M = {"WornMedal_Ribbon_" + b: ut @ cf(w["Ribbon"]) @ TO_B4, "WornMedal_Disc": ut @ cf(w["Disc"]) @ TO_B4,
                 "WornMedal_Text": ut @ cf(w["Text"]) @ TO_B4}
            show_real(M.keys(), M)

    def place_trophy(base_lifter_frame, lifter):
        """The trophy's base-bottom centre at `base_lifter_frame` (the lifter's root frame), upright, unturned."""
        p = lifter.rig.matrix_world @ (TO_B @ (base_lifter_frame + Vector((0, C.HRP_Y, 0))))
        for o in trophy:
            o.matrix_world = Matrix.Translation(p) @ lifter.rig.matrix_world.to_3x3().to_4x4()

    # ---------------------------------------------------------------- measuring
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

    def depth_in(pts, tree, reach=1.5):
        """Deepest of pts inside the closed surface `tree` (0 if none) and the nearest gap of the rest."""
        deep, gap = 0.0, 9.0
        if tree is None:
            return deep, gap
        for p in pts:
            loc, _n, _i, dist = tree.find_nearest(p, reach)
            if loc is None:
                continue
            if inside(p, tree):
                deep = max(deep, dist)
            else:
                gap = min(gap, dist)
        return deep, gap

    def body_objs(f, skip=()):
        out = [f.parts[n] for n in BODY if n in f.parts and n not in skip and n not in ("LeftHand", "RightHand")]
        for side in ("Left", "Right"):
            if side + "Hand" not in skip:
                out.append(f.hand_obj(side))
        if f.head is not None and "Head" not in skip:
            out.append(f.head)
        return out

    def outer_objs(f, skip=()):
        return [o for o in f.clothes if o.name.partition("__")[2].split(".")[0] not in skip]

    def bodies_overlap(a, b, skip_a=(), skip_b=()):
        """Deepest point of either figure (skin and clothes) inside the other's skin, and the nearest the two come,
        outer surface to outer surface (skin or clothes)."""
        worst, gap = 0.0, 9.0
        for x, y, sx, sy in ((a, b, skip_a, skip_b), (b, a, skip_b, skip_a)):
            _t, pts = points(body_objs(x, sx) + outer_objs(x, sx))
            pts = pts[::3]
            tr, _v = points(body_objs(y, sy))
            dp, _gp = depth_in(pts, tr)
            worst = max(worst, dp)
            tro, _v = points(body_objs(y, sy) + outer_objs(y, sy))
            for p in pts:
                loc, _n, _i, dist = tro.find_nearest(p, 1.0)
                if loc is not None:
                    gap = min(gap, dist)
        return worst, gap

    def objs_vs(objs_a, objs_b):
        tb, _v = points(objs_b)
        _ta, pa = points(objs_a)
        return depth_in(pa, tb, 2.0)

    # ---------------------------------------------------------------- placement
    def ref_matrix(lifter, x, d):
        """refRoot = lifterRoot * CFrame.new(x, 0, -d) * CFrame.Angles(0, pi, 0), as Blender world."""
        return lifter.rig.matrix_world @ TO_B @ Matrix.Translation((x, 0, -d)) @ Matrix.Rotation(math.pi, 4, "Y") @ TO_B

    lifter_home = Matrix.Identity(4)

    def stage(lifter, x, d):
        for f in lifter_figs.values():
            if f is not lifter:
                f.place(Matrix.Translation((500, 500, 0)))
        lifter.place(lifter_home)
        if ref is not None:
            ref.place(ref_matrix(lifter, x, d))

    def fit_medal(lifter):
        """d, the nearest the referee may stand: the largest of (1) his hands (Grip) 0.03 off the lifter's chest (outer
        clothes) as the ribbon lands; (2) his arms never into the lifter's head (0.03 off) on the way over; (3) his hands
        and forearms 0.6 or more off the lifter's torso once they leave (from 2.15: the 2026-11-25 review)."""
        arms_of = lambda: [ref.hand_obj("Left"), ref.hand_obj("Right"), ref.parts["LeftLowerArm"], ref.parts["RightLowerArm"]]
        torso = lambda: body_objs(lifter, ("LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "LeftUpperArm",
                                           "RightUpperArm")) + outer_objs(lifter)
        rules = [([C.MEDAL_ON_NECK], lambda: [ref.hand_obj("Left"), ref.hand_obj("Right")],
                  lambda: body_objs(lifter, ("LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm")) + outer_objs(lifter),
                  0.03),
                 ([0.9, 1.03, 1.15, 1.3, 1.43, 1.55], arms_of, lambda: [lifter.head], 0.03),
                 ([2.2, 2.35, 2.5, 2.62, 2.75, 2.85], arms_of, torso, 0.6)]
        best = 0.0
        for times, mine, his, want in rules:
            lo, hi = 2.4, 4.4
            for _ in range(11):
                m = (lo + hi) / 2
                ok = True
                for t in times:
                    stage(lifter, 0.0, m)
                    lifter.pose("Ceremony_Lifter_ReceiveMedal", t)
                    ref.pose("Ceremony_Ref_PlaceMedal", t)
                    set_shapes("Medal", t)
                    deep, gap = objs_vs(mine(), his())
                    if deep > 0 or gap < want:
                        ok = False
                        break
                if ok:
                    hi = m
                else:
                    lo = m
            print("[CerQA] fit %s rule %s -> d %.3f" % (lifter.build, times[0], hi))
            best = max(best, hi)
        return 0.0, round(best, 3)

    def palm_world(f, side, s):
        return f.at(side + "Hand", C.palm_point(side, s) + Vector((0, 0, 0)))

    def fit_shake(lifter):
        """x, d: at the middle of the clasp the two right palms' middles meet, then x adjusted so the hand meshes just
        touch (no hand inside the other)."""
        t = 0.62 + 0.5 * (1.78 - 0.62)
        x, d = C.SHAKE_X, C.D_SHAKE
        for _ in range(3):
            stage(lifter, x, d)
            lifter.pose("Ceremony_Lifter_Handshake", t)
            ref.pose("Ceremony_Ref_Handshake", t)
            pl = lifter.to_rig(palm_world(lifter, "Right", C.HAND_SIZE[lifter.build])) - Vector((0, C.HRP_Y, 0))
            pr = lifter.to_rig(palm_world(ref, "Right", C.HAND_SIZE[C.REF_BUILD])) - Vector((0, C.HRP_Y, 0))
            x += pl.x - pr.x
            d -= pl.z - pr.z
        # mesh contact along the palms' normal (lifter frame x, turned by SHAKE_ANGLE): binary search on x
        lo, hi = x - 0.4, x + 0.4
        for _ in range(12):
            m = (lo + hi) / 2
            stage(lifter, m, d)
            lifter.pose("Ceremony_Lifter_Handshake", t)
            ref.pose("Ceremony_Ref_Handshake", t)
            deep, gap = objs_vs([ref.hand_obj("Right")], [lifter.hand_obj("Right")])
            deep2, _g = objs_vs([lifter.hand_obj("Right")], [ref.hand_obj("Right")])
            # the referee's hand is on the lifter's LEFT of his: x larger pushes it into the lifter's hand
            if max(deep, deep2) > 0.0:
                hi = m
            else:
                lo = m
        return round(lo, 3), round(d, 3)

    placements = {c: {} for c in clips}
    report = ["# Podium ceremony pair check (ceremony_pairqa.py)\n\nStuds. Lifter in the meet outfit, referee (%s) in "
              "tee/joggers/sneakers. Placement: refRoot = lifterRoot * CFrame.new(x, 0, -d) * CFrame.Angles(0, pi, 0)."
              "\n\n" % C.REF_BUILD]

    def keytimes(name):
        return [t for t, _f in G["read_anim"](name)]

    SPANS = {"Medal": ("Ceremony_Ref_PlaceMedal", "Ceremony_Lifter_ReceiveMedal"),
             "Handshake": ("Ceremony_Ref_Handshake", "Ceremony_Lifter_Handshake"),
             "Trophy": ("Ceremony_Ref_HandTrophy", "Ceremony_Lifter_TakeTrophy_%s")}

    def set_shapes(clip, t):
        if ref is None:
            return
        if clip == "Medal":
            g = "Grip" if C.MEDAL_GRIP[0] <= t < C.MEDAL_GRIP[1] else None
            ref.show("Left", g)
            ref.show("Right", g)
        elif clip == "Trophy":
            ref.show("Left", None)
            ref.show("Right", "Grip" if C.TROPHY_GRIP[0] <= t < C.TROPHY_GRIP[1] else None)
        else:
            ref.show("Left", None)
            ref.show("Right", None)

    def pose_pair(clip, lifter, t, x, d):
        stage(lifter, x, d)
        rn, ln = SPANS[clip]
        ln = ln % lifter.build if "%s" in ln else ln
        lifter.pose(ln, t)
        ref.pose(rn, t)
        set_shapes(clip, t)
        for o in medal_objs:
            o.hide_render = True
        for objs in real.values():
            for o in objs:
                o.hide_render = True
        for o in trophy:
            o.hide_render = clip != "Trophy"
            if clip != "Trophy":
                o.matrix_world = Matrix.Translation((700, 700, 0))
        if clip == "Medal":
            medal_at(t, lifter, d, x)
        if clip == "Trophy":
            place_trophy(C.trophy_base_lifter(t, d, x, lifter.build), lifter)
        bpy.context.view_layer.update()

    def measure(clip, lifter, t, x, d):
        pose_pair(clip, lifter, t, x, d)
        r = {}
        if clip == "Medal":
            skip_r = ("LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm")
            r["bodies"], r["body_gap"] = bodies_overlap(ref, lifter, skip_r, ())
            arms = [ref.hand_obj("Left"), ref.hand_obj("Right"), ref.parts["LeftLowerArm"], ref.parts["RightLowerArm"]]
            r["ref_arm_in_head"], r["ref_arm_head_gap"] = objs_vs(arms, [lifter.head])
            r["ref_arm_in_lifter"], r["ref_arm_gap"] = objs_vs(arms, body_objs(lifter, ("Head",)) + outer_objs(lifter))
            if t >= C.MEDAL_GRIP[1] + 0.17:     # (from 2.15: his hands are off and on their way back)
                # letting go: hands and forearms vs the lifter's torso (skin and clothes, head included)
                _d, r["release_gap"] = objs_vs(arms, body_objs(lifter, ("LeftHand", "RightHand", "LeftLowerArm",
                                                                          "RightLowerArm", "LeftUpperArm",
                                                                          "RightUpperArm")) + outer_objs(lifter))
            if t < C.MEDAL_ON_NECK:
                held_objs = [o for n in ("HeldMedal_Ribbon", "WornMedal_Disc") for o in real.get(n, [])]
                r["held_medal_in_lifter"], r["held_medal_gap"] = objs_vs(held_objs, body_objs(lifter) + outer_objs(lifter))
                r["hold_spacing_err"] = abs(medal_at.spacing - 1.5)
                if r["held_medal_in_lifter"] > 0.0 and t >= 1.3:
                    # the least roll (front V out toward the referee) that clears the lifter: the game's recipe
                    need = 99.0
                    for a in range(5, 61, 5):
                        medal_at(t, lifter, d, x, roll=a)
                        if objs_vs(held_objs, body_objs(lifter) + outer_objs(lifter))[0] <= 0.0:
                            need = a
                            break
                    r["roll_needed"] = need
                    medal_at(t, lifter, d, x)
        elif clip == "Handshake":
            skip = ("RightHand", "RightLowerArm")
            r["bodies"], r["body_gap"] = bodies_overlap(ref, lifter, skip, skip)
            a, ga = objs_vs([ref.hand_obj("Right")], [lifter.hand_obj("Right")])
            b, gb = objs_vs([lifter.hand_obj("Right")], [ref.hand_obj("Right")])
            r["hand_in_hand"], r["hand_gap"] = max(a, b), min(ga, gb)
            fa, _g = objs_vs([ref.parts["RightLowerArm"]], [lifter.hand_obj("Right"), lifter.parts["RightLowerArm"]])
            fb, _g = objs_vs([lifter.parts["RightLowerArm"]], [ref.hand_obj("Right"), ref.parts["RightLowerArm"]])
            r["forearm_in_other"] = max(fa, fb)
        elif clip == "Trophy":
            skip = ("LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm")
            r["bodies"], r["body_gap"] = bodies_overlap(ref, lifter, skip, skip)
            lh = [lifter.hand_obj("Left"), lifter.hand_obj("Right")]
            r["lifter_hand_in_trophy"], r["lifter_hand_gap"] = objs_vs(lh, trophy)
            rh = [ref.hand_obj("Left"), ref.hand_obj("Right")]
            r["ref_hand_in_trophy"], r["ref_hand_gap"] = objs_vs(rh, trophy)
            r["trophy_in_lifter"], r["trophy_lifter_gap"] = objs_vs(trophy, body_objs(lifter, skip) + outer_objs(lifter))
            r["trophy_in_ref"], r["trophy_ref_gap"] = objs_vs(trophy, body_objs(ref, skip) + outer_objs(ref))
            hh, _g = objs_vs([ref.hand_obj("Left"), ref.hand_obj("Right")], lh)
            r["hands_touch_hands"] = hh
        return r

    for clip in [c for c in clips if c in SPANS]:
        rn, ln = SPANS[clip]
        for b in lifters:
            lifter = lifter_fig(b)
            x, d = C.PLACEMENT[clip][b]
            if do_fit and clip == "Medal":
                x, d = fit_medal(lifter)
            elif do_fit and clip == "Handshake":
                x, d = fit_shake(lifter)
            placements[clip][b] = (x, d)
            worst = {}
            rows = []
            for t in keytimes(rn)[::2] + [keytimes(rn)[-1]]:
                r = measure(clip, lifter, t, x, d)
                rows.append((t, r))
                for k, v in r.items():
                    if k.endswith("gap"):
                        if v < worst.get(k, (9.0, 0))[0]:
                            worst[k] = (v, t)
                    elif v > worst.get(k, (-1.0, 0))[0]:
                        worst[k] = (v, t)
            line = "%s/%s x %.3f d %.3f worst %s" % (clip, b, x, d, ", ".join(
                "%s %.3f (t %.2f)" % (k, v, tt) for k, (v, tt) in sorted(worst.items())))
            print("[CerQA] RESULT " + line)
            report.append("- " + line + "\n")
            if os.environ.get("CER_ROWS"):
                for t, r in rows:
                    print("[CerQA]   t %.2f %s" % (t, ", ".join("%s %.3f" % kv for kv in sorted(r.items()))))
    open(os.path.join(out, "ceremony_pair_qa.md"), "w", encoding="utf-8").write("".join(report))
    lua = ["-- ceremony_pairqa: refRoot = lifterRoot * CFrame.new(x, 0, -d) * CFrame.Angles(0, math.pi, 0)\n"]
    for clip, rows in placements.items():
        lua.append("%s = {\n" % clip)
        for b, (x, d) in rows.items():
            lua.append("\t%s = { x = %.3f, d = %.3f },\n" % (b, x, d))
        lua.append("},\n")
    open(os.path.join(out, "ceremony_placement.lua"), "w", encoding="utf-8").write("".join(lua))
    print("".join(lua))

    # ---------------------------------------------------------------- pictures
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
    cd = bpy.data.cameras.new("CerCam")
    cd.type = "ORTHO"
    cd.clip_end = 300
    cam = bpy.data.objects.new("CerCam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    lc = bpy.data.curves.new("CerLabel", "FONT")
    label = bpy.data.objects.new("CerLabel", lc)
    label.data.materials.append(mat("CerLabelMat", (0.95, 0.95, 0.9, 1)))
    sc.collection.objects.link(label)
    label.parent = cam
    bpy.ops.mesh.primitive_cylinder_add(radius=40, depth=0.02, vertices=8)
    floor = bpy.context.active_object
    floor.location = (0, 0, -0.011)
    floor.data.materials.append(mat("CerFloor", (0.34, 0.35, 0.38, 1)))

    def shoot(path, text, direction_roblox, target_roblox, scale, size, lifter):
        cd.ortho_scale = scale
        sc.render.resolution_x, sc.render.resolution_y = size
        tgt = lifter.rig.matrix_world @ (TO_B @ Vector(target_roblox))
        dirb = (lifter.rig.matrix_world.to_3x3() @ (TO_B.to_3x3() @ Vector(direction_roblox))).normalized()
        cam.location = tgt + dirb * 60
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        lc.body = text
        lc.size = scale * 0.028
        label.location = (-scale / 2 + scale * 0.015, scale * size[1] / size[0] / 2 - lc.size * 1.35, -5)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path

    # (Roblox lifter frame: he faces -z, his right is +x; the referee stands at -z facing him)
    VIEWS = {"front3q": (1.0, 0.30, -0.32), "side": (1.0, 0.08, 0.0), "back3q": (0.75, 0.38, 0.85)}
    MOMENTS = {
        "Medal": [(0.3, "showing the medal"), (0.78, "rising"), (C.MEDAL_OVER_HEAD, "over the head"),
                  (1.55, "down in front of the face"), (1.82, "laying it on"), (C.MEDAL_ON_NECK + 0.02, "worn (swap)"),
                  (2.2, "let go, drawing back"), (2.5, "back at his chest"), (2.75, "hands down; looks down")],
        "Handshake": [(0.35, "reaching"), (0.62, "hands meet"), (1.0, "pump"), (1.85, "letting go")],
        "Trophy": [(0.3, "holding it out"), (C.TROPHY_TOUCH, "lifter's palms on it"), (1.45, "taken"),
                   (2.4, "holding it")],
    }
    for clip in [c for c in clips if c in SPANS]:
        for b in [p for p in pictured if p in placements[clip]]:
            lifter = lifter_fig(b)
            x, d = placements[clip][b]
            tiles, zooms = [], []
            for t, note in MOMENTS[clip]:
                pose_pair(clip, lifter, t, x, d)
                for v, dr in VIEWS.items():
                    text = "%s  lifter %s  t %.2f %s  -  %s" % (clip, b, t, note, v)
                    tiles.append((None, None, shoot(os.path.join(out, "tiles", "%s_%s_%.2f_%s.png" % (clip, b, t, v)),
                                                    text, dr, (x / 2, 3.4, -d / 2), 8.6, (760, 760), lifter)))
                # the hands, close
                if clip == "Medal":
                    c_ = lifter.to_rig((ref.at("LeftHand", C.grip_point("Left", 1.3)) +
                                        ref.at("RightHand", C.grip_point("Right", 1.3))) / 2)
                elif clip == "Handshake":
                    c_ = lifter.to_rig(palm_world(lifter, "Right", C.HAND_SIZE[b]))
                else:
                    c_ = lifter.to_rig((lifter.at("LeftHand", Vector((0, -0.3, 0))) +
                                        lifter.at("RightHand", Vector((0, -0.3, 0)))) / 2)
                for v, dr in (("zoom3q", (0.85, 0.35, -0.6)), ("zoomtop", (0.25, 1.0, -0.2)), ("zoomside", (1, 0.1, 0.25))):
                    text = "%s %s t %.2f %s  %s" % (clip, b, t, note, v)
                    zooms.append((None, None, shoot(os.path.join(out, "tiles", "%s_%s_%.2f_%s.png" % (clip, b, t, v)),
                                                    text, dr, c_, 3.2, (560, 560), lifter)))
            p1 = os.path.join(out, "Ceremony_%s_Lifter%s.png" % (clip, b))
            G["contact_sheet"](tiles, p1, 3)
            p2 = os.path.join(out, "Ceremony_%s_Lifter%s_Hands.png" % (clip, b))
            G["contact_sheet"](zooms, p2, 3)
            print("[CerQA] sheet", p1, p2)

    if "StepUp" in clips:
        # the hop with the game's arc onto a block of each height (side view): root up(t), forward(t)
        lifter = lifter_fig(pictured[0])
        for f in lifter_figs.values():
            f.place(Matrix.Translation((500, 500, 0)))
        if ref is not None:
            ref.place(Matrix.Translation((600, 600, 0)))
        for o in trophy + medal_objs + [o for objs in real.values() for o in objs]:
            o.hide_render = True
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        block = bpy.context.active_object
        block.data.materials.append(mat("CerBlock", (0.85, 0.85, 0.82, 1)))
        for h in (1.4, 3.0):
            tiles = []
            fwd = 3.4                        # from 0.9 in front of the block's face to its middle
            block.matrix_world = TO_B @ Matrix.Translation((0, h / 2, -(0.9 + 2.5))) @ Matrix.Diagonal((5, h, 5, 1))
            for t in (0.0, 0.3, C.STEP_LAUNCH, 0.5, C.STEP_TOP, 0.7, C.STEP_LAND, 0.92, 1.2):
                up, fw = C.step_arc(t, h, fwd)
                lifter.place(TO_B @ Matrix.Translation((0, up, -fw)) @ TO_B)
                lifter.pose("Ceremony_Lifter_StepUp", t)
                text = "StepUp %s block %.1f  t %.2f  up %.2f fwd %.2f" % (lifter.build, h, t, up, fw)
                tiles.append((None, None, shoot(os.path.join(out, "tiles", "Step_%.1f_%.2f.png" % (h, t)), text,
                                                (1.0, 0.1, 0.0), (0, 2.6 + h / 2, -2.2), 9.5, (560, 560),
                                                lifter_figs[pictured[0]] if False else _Home())))
            p = os.path.join(out, "Ceremony_StepUp_Block%.1f.png" % h)
            G["contact_sheet"](tiles, p, 5)
            print("[CerQA] sheet", p)
    print("[CerQA] DONE (nothing saved)")


class _Home:
    """A stand-in 'lifter' for camera framing at the world origin."""

    class _R:
        matrix_world = Matrix.Identity(4)
    rig = _R()
