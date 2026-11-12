"""Builds one sound track per celebration (art/sounds/celebration_tracks.json; user 2026-11-11: "Take all these
celebrations, have elevenlabs make sound affects for it. The sound affects are just very off putting.").

Each celebration's ElevenLabs take (its own prompt: its moves in order, no voice; made at the celebration's exact length
with prompt influence 0.7) is edited like a foley track: the take's hits are paired, in order, with the cues (the
moments in its animation, art/scripts/celebration_animations.py), and the stretch of sound around each paired hit is
nudged so the hit lands on its cue, with soft crossfades where the stretches meet. The whole take stays continuous and
natural: nothing is repeated, cut out or filtered. A hit more than MAX_SHIFT from any cue stays where it is.

    uv run --no-project --with numpy --with soundfile python art/scripts/make_celebration_tracks.py
writes D:/Powerlifting Roblox Extras/Sounds/Celebrations/Track_<Name>.wav (mono), and a report of how each take's hits
were matched. Upload with art/scripts/upload_group_images.py (its "sounds" list is the manifest's).
"""
import json
import pathlib
import sys

import numpy as np
import soundfile as sf

import os

# Another set of tracks (the walk-outs' hype moves, art/sounds/hype_tracks.json) is built the same way with
# TRACKS_MANIFEST=<manifest> and TRACKS_ROOT=<folder> set.
ROOT = pathlib.Path(os.environ.get("TRACKS_ROOT", r"D:\Powerlifting Roblox Extras\Sounds\Celebrations"))
MANIFEST = pathlib.Path(os.environ.get("TRACKS_MANIFEST",
                                       pathlib.Path(__file__).resolve().parent.parent / "sounds" / "celebration_tracks.json"))
BLOCK = 0.005           # seconds per level block
RISE_DB = 5             # a hit: the level jumps this much ...
RISE_OVER = 0.04        # ... within this long
FLOOR_DB = 32           # and is within this much of the take's loudest
MERGE = 0.09            # hits closer than this are one
PRE = 0.008             # each piece starts this long before its hit
MAX_PIECE = 0.75        # and is at most this long
FADE_IN, FADE_OUT = 0.003, 0.05
PEAK_DB = -3.0
TAIL = 0.4              # the track runs this long past the celebration's end
MAX_SHIFT = 1.2         # a hit further than this from its cue stays where it is
XFADE = 0.03            # the crossfade where nudged stretches meet
LOOSE_SHIFT = 8.0       # a take that pairs under 60% of its cues: its stretches may move this far (order kept)


def levels(x, rate):
    n = int(rate * BLOCK)
    blocks = np.abs(x[: len(x) // n * n]).reshape(-1, n).max(axis=1)
    return 20 * np.log10(np.maximum(blocks, 1e-9)), n


def hits(x, rate):
    """[(sample, strength dB)] of the take's hits, in time order."""
    db, n = levels(x, rate)
    top = db.max()
    back = max(1, int(RISE_OVER / BLOCK))
    found = []
    # A take that opens on a hit has no quiet before it to rise from: count it if it is loud right away.
    start = int(np.argmax(db[:back] >= top - FLOOR_DB)) if (db[:back] >= top - 10).any() else None
    if start is not None:
        found.append((start, db[start : start + int(0.06 / BLOCK)].max()))
    for i in range(back, len(db)):
        if db[i] - db[i - back : i].min() >= RISE_DB and db[i] >= top - FLOOR_DB:
            strength = db[i : i + int(0.06 / BLOCK)].max()
            if found and (i - found[-1][0]) * BLOCK < MERGE:
                if strength > found[-1][1]:
                    found[-1] = (found[-1][0], strength)
                continue
            found.append((i, strength))
    return [(i * n, s) for i, s in found]


def align(cues, found, rate, max_shift=None, gap_cost=2.0):
    """The best in-order pairing of cues with hits (no hit used twice, order never swapped): each pair scores its hit's
    strength minus how far it would have to move; a cue may stay unpaired. Returns [(cue seconds, hit sample)]."""
    hit_t = [h[0] / rate for h in found]
    strength = [max(0.0, (h[1] + 40) / 40) for h in found]
    n, m = len(cues), len(found)
    score = [[0.0] * (m + 1) for _ in range(n + 1)]
    move = [[None] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            options = [(score[i - 1][j], "skip_cue"), (score[i][j - 1], "skip_hit")]
            gap = abs(cues[i - 1] - hit_t[j - 1])
            if gap <= (max_shift or MAX_SHIFT):
                options.append((score[i - 1][j - 1] + 1.0 + strength[j - 1] - gap * gap_cost, "pair"))
            score[i][j], move[i][j] = max(options, key=lambda o: o[0])
    pairs, i, j = [], n, m
    while i > 0 and j > 0:
        step = move[i][j]
        if step == "pair":
            pairs.append((cues[i - 1], found[j - 1][0]))
            i, j = i - 1, j - 1
        elif step == "skip_cue":
            i -= 1
        else:
            j -= 1
    return list(reversed(pairs))


def build(name, track, raw):
    """The whole take, kept continuous, with each stretch around a paired hit nudged so the hit lands on its cue (soft
    crossfades where the stretches meet). Nothing is repeated or cut out."""
    data, rate = sf.read(raw, always_2d=True)
    x = data.mean(axis=1)
    found = hits(x, rate)
    pairs = align(track["cues"], found, rate)
    if len(pairs) < 0.6 * len(track["cues"]):
        # The take bunched its moves up (or spread them out): spread its stretches over the moves instead, still in order.
        loose = align(track["cues"], found, rate, LOOSE_SHIFT, 0.25)
        if len(loose) > len(pairs):
            pairs = loose
    length = int(rate * (track["seconds"] + TAIL))
    out = np.zeros(length + rate)
    if not pairs:
        out[: len(x)] += x[: len(out)]
        report = "no hits paired: the take as it is"
    else:
        # Stretch k runs from halfway after the previous paired hit to halfway before the next one.
        hits_at = [h for _, h in pairs]
        bounds = [0] + [(hits_at[k] + hits_at[k + 1]) // 2 for k in range(len(hits_at) - 1)] + [len(x)]
        xf = int(XFADE * rate)
        for k, (cue, at) in enumerate(pairs):
            begin, end = max(0, bounds[k] - xf), min(len(x), bounds[k + 1] + xf)
            piece = x[begin:end].copy()
            ramp = np.ones(len(piece))
            if k > 0:
                ramp[: 2 * xf] = np.linspace(0, 1, 2 * xf)
            if k < len(pairs) - 1:
                ramp[-2 * xf:] = np.minimum(ramp[-2 * xf:], np.linspace(1, 0, 2 * xf))
            shift = int(cue * rate) - at
            place = begin + shift
            lo, hi = max(0, place), min(len(out), place + len(piece))
            if hi > lo:
                out[lo:hi] += (piece * ramp)[lo - place: hi - place]
        report = ", ".join(f"{cue:.2f}s<-{at / rate:.2f}s" for cue, at in pairs)
    out = out[:length]
    if track.get("loop"):
        # A looping track ("WalkLoop" celebrations): exactly one round long, whatever rings past the round's end wrapped
        # onto its start, so the loop has no seam and no fade.
        period = int(rate * track["seconds"])
        tail = out[period:]
        out = out[:period].copy()
        out[: len(tail)] += tail
        out *= 10 ** (PEAK_DB / 20) / max(np.abs(out).max(), 1e-9)
    else:
        out *= 10 ** (PEAK_DB / 20) / max(np.abs(out).max(), 1e-9)
        fo = int(0.08 * rate)
        out[-fo:] *= np.linspace(1, 0, fo)
    path = ROOT / f"Track_{name}.wav"
    sf.write(path, out, rate, subtype="PCM_16")
    return path, (f"{name}: take {len(x) / rate:.1f} s, {len(found)} hits, {len(pairs)} of {len(track['cues'])} cues "
                  f"paired: {report}")


def pick(name, track):
    """With several takes of one celebration (Raw/candidates/<Name>_*.mp3), keeps the one that lines up best (the most
    cues paired, then the smallest nudges) as Raw/<Name>.mp3."""
    best = None
    for path in sorted((ROOT / "Raw" / "candidates").glob(f"{name}_*.mp3")):
        data, rate = sf.read(path, always_2d=True)
        x = data.mean(axis=1)
        pairs = align(track["cues"], hits(x, rate), rate)
        moved = sum(abs(cue - at / rate) for cue, at in pairs)
        score = (len(pairs), -moved)
        print(f"  {path.name}: {len(pairs)} of {len(track['cues'])} paired, moved {moved:.2f} s in all")
        if best is None or score > best[0]:
            best = (score, path)
    if best:
        (ROOT / "Raw" / f"{name}.mp3").write_bytes(best[1].read_bytes())
        print(f"  kept {best[1].name}")


def main(names):
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for name, track in manifest["tracks"].items():
        if (ROOT / "Raw" / "candidates").exists() and any((ROOT / "Raw" / "candidates").glob(f"{name}_*.mp3")):
            if not names or name in names:
                print(f"{name}: choosing between takes")
                pick(name, track)
    for name, track in manifest["tracks"].items():
        if names and name not in names:
            continue
        raw = ROOT / "Raw" / f"{name}.mp3"
        if not raw.exists():
            print(f"(no take for {name})")
            continue
        _, line = build(name, track, raw)
        print(line)


if __name__ == "__main__":
    main(sys.argv[1:])
