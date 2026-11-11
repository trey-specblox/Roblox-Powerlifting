# The State arena's crowd chant beat (GAME_DESIGN §36.4, user 2026-11-10): the crowd stomping twice and clapping once,
# over and over, with a chant ("LIFT OR LOSE", "SQUAT IT UP"...) shouted over it by the game. In the spirit of the
# reference the user sent (a game's "sudden death" music): an ORIGINAL beat, own work, nothing copied from it.
#
#   uv run --no-project --with numpy python art/scripts/make_chant_beat.py
# writes art/sounds/ChantBeat.wav (the loop: 4 bars) and ChantBeat_Listen.wav (the loop twice) to D:\Powerlifting Roblox Extras\Sounds.
#
# Every sound here is made from scratch (no recordings), so it can go in the game without any licence question.
import importlib.util
import os

import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("make_meet_sounds", os.path.join(_HERE, "make_meet_sounds.py"))
M = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(M)

RATE = M.RATE
BPM = 116
BEAT = 60 / BPM
BARS = 4
# Each bar: stomp, stomp, clap, rest (the beat the user asked for: "stomps, claps").
PATTERN = ("stomp", "stomp", "clap", None)
STOMPERS, CLAPPERS = 60, 80
SPREAD = 0.022            # how far out of time each person is (seconds, standard deviation)


def one_stomp(random):
    """One person stamping on the stands: a deep thump and a wooden knock."""
    n = int(0.35 * RATE)
    t = np.arange(n) / RATE
    thump = M.sub_kick(random.uniform(80, 110), random.uniform(42, 55), 0.35, sweep=0.03)
    knock = M.band(random.standard_normal(n), random.uniform(140, 220), random.uniform(700, 1100)) * np.exp(-t / 0.035)
    return thump * random.uniform(0.7, 1.0) + knock * random.uniform(0.25, 0.45)


def one_clap(random):
    """One person clapping: a few tiny bursts of the palms meeting."""
    n = int(0.08 * RATE)
    t = np.arange(n) / RATE
    centre = random.uniform(1000, 2600)
    burst = M.band(random.standard_normal(n), centre * 0.6, centre * 1.8) * np.exp(-t / random.uniform(0.008, 0.016))
    gap = random.uniform(0.003, 0.007)
    return M.stack((burst, 0.5, 0), (burst, 1.0, gap))


def crowd(maker, people, seed, at):
    """`people` of them at once, each a little early or late, louder or softer."""
    random = np.random.default_rng(seed)
    size = int(1.0 * RATE)
    total = np.zeros(size)
    for _ in range(people):
        x = maker(random) * random.uniform(0.5, 1.0)
        offset = int(max(0.0, 0.08 + random.normal(0, SPREAD)) * RATE)
        end = min(size, offset + len(x))
        total[offset:end] += x[:end - offset]
    return total, at - 0.08


def build():
    loop_seconds = BARS * 4 * BEAT
    n = int(loop_seconds * RATE)
    # Room before the start (people a little early on the first stomp) and after the end; both fold back into the loop.
    lead = int(0.2 * RATE)
    dry = np.zeros(lead + n + int(1.0 * RATE))
    seed = 1
    for bar in range(BARS):
        for beat, kind in enumerate(PATTERN):
            if kind is None:
                continue
            seed += 1
            at = (bar * 4 + beat) * BEAT
            x, start = crowd(one_stomp if kind == "stomp" else one_clap, STOMPERS if kind == "stomp" else CLAPPERS, seed, at)
            x = M.peak_to(x, -1) * (1.0 if kind == "stomp" else 0.75)
            s = lead + int(start * RATE)
            dry[s:s + len(x)] += x[:len(dry) - s]
    # Wrap what runs past the end back onto the start, and what comes before the start onto the end: no seam.
    wrapped = dry[lead:lead + n].copy()
    tail = dry[lead + n:]
    wrapped[:len(tail)] += tail
    wrapped[n - lead:] += dry[:lead]
    # The big arena's echo, wrapped the same way.
    wet = M.room(wrapped, 2.4, 0.55, seed=41, dark=4200)
    looped = wet[:n].copy()
    looped[:len(wet) - n] += wet[n:]
    looped = M.saturate(M.band(looped, 40, 9000), 1.4)
    return M.peak_to(looped, -3), loop_seconds


def main():
    x, seconds = build()
    M.OUT.mkdir(exist_ok=True)
    # Own work, so the loop itself lives in the repo (art/sounds, listed in art/materials/materials.json for the uploader).
    import wave
    with wave.open(os.path.join(_HERE, "..", "sounds", "ChantBeat.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    M.save("ChantBeat_Listen", np.concatenate([x, x]))
    M.describe("ChantBeat", x)
    print(f"loop {seconds:.3f} s at {BPM} BPM: bars of stomp, stomp, clap, rest; a chant goes on bars 3 and 4 "
          f"(from {2 * 4 * BEAT:.3f} s)")


if __name__ == "__main__":
    main()
