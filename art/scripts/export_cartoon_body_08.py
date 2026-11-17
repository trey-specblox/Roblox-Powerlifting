# Exports the LONGER-LEGGED bodies (knee 1.00, user 2026-11-15 "make the legs a little longer"; go-live approved
# 2026-11-16), read-only on the .blend: export_cartoon_05.py run unchanged except for where it writes:
#   art/exports/CartoonBody08_<Build>.glb   the six bodies on the new legs (new uploads; the 05 bodies stay as they were)
#   art/exports/CartoonExport05.json        rewritten in place (the config's data file: joints now knee 1.00; the
#                                           neck marks, hands, bar rest and bench clearance are torso / arm values)
#   the v5 gear / clothes and the swap hands go to D:\ClaudeScratch\golive\gear\scratch_exports (gear and clothes are
#   v08: export_cartoon_08.py; the hands are compared with the uploaded CartoonHands05 and re-uploaded only if changed)
#   blender -b art/blender/CartoonGear_05_Knee100.blend --python art/scripts/export_cartoon_body_08.py
import os

SCRIPTS = r"D:\Powerlifting Roblox\art\scripts"
SCRATCH = r"D:\ClaudeScratch\golive\gear\scratch_exports"
src = open(os.path.join(SCRIPTS, "export_cartoon_05.py"), encoding="utf-8").read()
NUM = os.environ.get("BODY_EXPORT_NUM", "08")    # 10 = the body-polish weights (2026-11-17, user "Ship")
for a, b in (('os.path.join(EXPORTS, "CartoonBody05_%s.glb" % b)', 'os.path.join(EXPORTS, "CartoonBody%s_%%s.glb" %% b)' % NUM),
             ('os.path.join(EXPORTS, "CartoonGear05_%s.glb" % b)', 'os.path.join(SCRATCH, "CartoonGear05_%s.glb" % b)'),
             ('os.path.join(EXPORTS, "CartoonClothes05_%s.glb" % b)', 'os.path.join(SCRATCH, "CartoonClothes05_%s.glb" % b)'),
             ('os.path.join(EXPORTS, "CartoonHands05.glb")', 'os.path.join(SCRATCH, "CartoonHands05.glb")')):
    assert src.count(a) == 1, a
    src = src.replace(a, b)
exec(compile(src, os.path.join(SCRIPTS, "export_cartoon_05.py"), "exec"), {"__name__": "__main__", "SCRATCH": SCRATCH})
