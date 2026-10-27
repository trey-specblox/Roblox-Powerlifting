# Draws the Classroom front's chalk drawings (GAME_DESIGN §27 "Themed room fronts": a chalkboard with chalk
# drawings of squat, bench and deadlift technique) as transparent PNGs, so the chalkboard texture shows
# through: a side-view stick lifter per lift with its technique cues, and a "TECHNIQUE 101" header panel.
# Text in Montserrat Black from the Roblox install (OFL), the font of every CENTRAL label.
#
#   python -I art/scripts/draw_chalk_lessons.py <out folder>
import glob
import math
import os
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

W, H = 768, 1024
WHITE, YELLOW, PINK, BLUE = (244, 242, 232), (250, 222, 110), (246, 150, 180), (150, 200, 245)


def montserrat():
    roots = [os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions"), r"C:\Program Files (x86)\Roblox\Versions",
             r"C:\Program Files\Roblox\Versions"]
    found = [f for root in roots for f in glob.glob(os.path.join(root, "*", "content", "fonts", "Montserrat-Black.ttf"))]
    if not found:
        sys.exit("Montserrat-Black.ttf not found in a Roblox install")
    return max(found, key=os.path.getmtime)


FONT = montserrat()


class Chalk:
    """One drawing: chalk strokes per colour, roughened, on a transparent background."""

    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.layers = {}

    def mask(self, colour):
        if colour not in self.layers:
            self.layers[colour] = Image.new("L", (W, H), 0)
        return self.layers[colour]

    def line(self, p, q, colour=WHITE, width=11, dashed=False):
        draw = ImageDraw.Draw(self.mask(colour))
        length = math.dist(p, q)
        steps = max(2, int(length / 3))
        for k in range(steps + 1):
            if dashed and (k * 3 // 18) % 2 == 1:
                continue
            t = k / steps
            x = p[0] + (q[0] - p[0]) * t + self.rng.uniform(-1.2, 1.2)
            y = p[1] + (q[1] - p[1]) * t + self.rng.uniform(-1.2, 1.2)
            r = width / 2 * self.rng.uniform(0.8, 1.05)
            draw.ellipse((x - r, y - r, x + r, y + r), fill=self.rng.randint(170, 255))

    def path(self, points, colour=WHITE, width=11):
        for p, q in zip(points, points[1:]):
            self.line(p, q, colour, width)

    def circle(self, centre, radius, colour=WHITE, width=10, dashed=False):
        n = max(24, int(radius / 3))
        pts = [(centre[0] + radius * math.cos(2 * math.pi * k / n), centre[1] + radius * math.sin(2 * math.pi * k / n))
               for k in range(n + 1)]
        for k, (p, q) in enumerate(zip(pts, pts[1:])):
            if not (dashed and k % 2):
                self.line(p, q, colour, width)

    def arrow(self, p, q, colour=YELLOW, width=9, both=False):
        self.line(p, q, colour, width)
        for tip, tail in ((q, p), (p, q)) if both else ((q, p),):
            angle = math.atan2(tip[1] - tail[1], tip[0] - tail[0])
            for side in (-1, 1):
                a = angle + math.pi + side * 0.5
                self.line(tip, (tip[0] + 34 * math.cos(a), tip[1] + 34 * math.sin(a)), colour, width)

    def text(self, words, centre, size, colour=WHITE, anchor="mm"):
        ImageDraw.Draw(self.mask(colour)).text(centre, words, font=ImageFont.truetype(FONT, size), fill=235, anchor=anchor)

    def lifter_head(self, centre, colour=WHITE):
        self.circle(centre, 38, colour, 10)

    def save(self, path):
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        noise = Image.effect_noise((W, H), 70).point(lambda v: min(255, 120 + v))
        for colour, layer in self.layers.items():
            alpha = ImageChops.multiply(layer.filter(ImageFilter.GaussianBlur(0.8)), noise)
            solid = Image.new("RGBA", (W, H), colour + (0,))
            solid.putalpha(alpha)
            out = Image.alpha_composite(out, solid)
        out.save(path, optimize=True)
        print("drew", path)


def cues(c, title, lines):
    c.text(title, (W / 2, 95), 92, WHITE)
    c.line((150, 160), (618, 160), WHITE, 7)
    for k, (words, colour) in enumerate(lines):
        c.text(words, (W / 2, 850 + k * 62), 44, colour)


def squat(out):
    c = Chalk(1)
    cues(c, "SQUAT", [("BRACE YOUR CORE", YELLOW), ("HIPS BELOW KNEES", PINK), ("DRIVE UP", YELLOW)])
    c.line((110, 780), (660, 780), WHITE, 7)  # the floor
    c.circle((372, 478), 80, BLUE, 9)  # the plate on the bar (blue, behind the lifter)
    c.circle((372, 478), 12, BLUE, 8)
    c.path([(450, 778), (395, 770), (470, 640), (300, 655), (390, 470), (418, 434)])  # foot, shin, thigh, back, neck
    c.lifter_head((438, 402))
    c.path([(390, 470), (330, 525), (364, 480)])  # arm to the bar
    c.line((230, 640), (580, 640), PINK, 7, dashed=True)  # depth: the top of the knee
    c.text("DEPTH", (100, 640), 34, PINK, "lm")
    c.arrow((620, 720), (620, 430), YELLOW)
    c.save(out / "Chalk_Squat.png")


def bench(out):
    c = Chalk(2)
    cues(c, "BENCH", [("FEET FLAT", YELLOW), ("TOUCH YOUR CHEST", PINK), ("PRESS & LOCK OUT", YELLOW)])
    c.line((80, 780), (690, 780), WHITE, 7)
    c.path([(130, 645), (560, 645), (560, 680), (130, 680), (130, 645)], BLUE, 8)  # the bench
    for x in (180, 510):
        c.line((x, 680), (x, 780), BLUE, 8)
    c.lifter_head((175, 600))
    c.path([(215, 615), (440, 618), (585, 585), (625, 778), (680, 778)])  # back, thigh, shin, foot
    # Locked out: a straight arm, the bar right over the shoulder (user, 2026-10-26: a bent arm looked wrong).
    c.circle((250, 352), 80, BLUE, 9)
    c.circle((250, 352), 12, BLUE, 8)
    c.line((250, 612), (250, 364))
    c.text("X", (300, 590), 40, PINK)  # where the bar touches (mid-chest)
    c.arrow((420, 380), (420, 560), YELLOW, both=True)
    c.save(out / "Chalk_Bench.png")


def deadlift(out):
    c = Chalk(3)
    cues(c, "DEADLIFT", [("FLAT BACK", YELLOW), ("BAR OVER MIDFOOT", PINK), ("LOCK HIPS & KNEES", YELLOW)])
    c.line((110, 780), (660, 780), WHITE, 7)
    c.circle((380, 700), 80, BLUE, 9)  # the plate on the floor
    c.circle((380, 700), 12, BLUE, 8)
    c.path([(440, 778), (360, 770), (420, 640), (270, 560), (420, 450), (440, 428)])  # foot, shin, thigh, back, neck
    c.lifter_head((462, 400))
    c.line((420, 450), (384, 696))  # straight arm to the bar
    c.line((385, 250), (385, 780), PINK, 7, dashed=True)  # the bar path, straight up over midfoot
    c.arrow((600, 720), (600, 430), YELLOW)
    c.save(out / "Chalk_Deadlift.png")


def lesson(out):
    c = Chalk(4)
    c.text("TECHNIQUE", (W / 2, 150), 92, WHITE)
    c.text("101", (W / 2, 270), 120, YELLOW)
    c.line((140, 350), (628, 350), WHITE, 7)
    c.text("THE BIG THREE", (W / 2, 440), 56, PINK)
    # A chalk barbell with two plates each side.
    c.line((90, 600), (678, 600), WHITE, 10)
    for x, r in ((150, 110), (190, 90), (618, 110), (578, 90)):
        c.line((x, 600 - r), (x, 600 + r), BLUE if r > 100 else YELLOW, 22)
    c.text("SQUAT", (W / 2, 790), 50, WHITE)
    c.text("BENCH", (W / 2, 860), 50, WHITE)
    c.text("DEADLIFT", (W / 2, 930), 50, WHITE)
    c.save(out / "Chalk_Lesson.png")


if __name__ == "__main__":
    folder = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    folder.mkdir(parents=True, exist_ok=True)
    for draw in (squat, bench, deadlift, lesson):
        draw(folder)
