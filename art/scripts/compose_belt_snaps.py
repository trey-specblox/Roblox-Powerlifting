"""Builds the two belt sound tracks from ElevenLabs belt SNAP takes (user, 2026-11-11: belt moves get a crisp snap or
flick, like their reference Short https://www.youtube.com/shorts/ngP2vaQHlPg, not a leather creak).

    UV_CACHE_DIR=... uv run --no-project --with numpy --with soundfile python art/scripts/compose_belt_snaps.py

Why compose instead of lining up one take: the Belt hype takes put every snap in their first half second (and no clap),
so stretching them onto the cues smeared them. Each snap is cut from a take with its natural tail and placed exactly on
its cue, using snaps from different takes so two in a row don't sound copied.

- Hype "Belt" (STANDARD walk-out, art/sounds/hype_tracks.json): snaps at 1.05 and 1.4 s, chalky clap at 2.0 s.
- Emote "BeltTighten" (art/sounds/emote_tracks.json): snaps at 0.7 and 1.1 s, a lighter flick of the lever at 1.7 s.
Writes Track_Belt.wav (Sounds/Hype) and Track_BeltTighten.wav (Sounds/Emotes).
"""
import json
import pathlib

import numpy as np
import soundfile as sf

SOUNDS = pathlib.Path(r"D:\Powerlifting Roblox Extras\Sounds")
REPO = pathlib.Path(__file__).resolve().parent.parent
PIECE = 0.38   # seconds kept of each hit (died away by then)
PEAK_DB = -3.0


def hit(folder, take, after, before):
    """The loudest hit between `after` and `before` seconds of a take, from just before its onset, with its tail."""
    x, rate = sf.read(SOUNDS / folder / "Raw" / "candidates" / f"{take}.mp3", always_2d=True)
    x = x.mean(axis=1)
    window = np.abs(x[int(after * rate): int(before * rate)])
    onset = int(after * rate) + int(np.argmax(window > window.max() * 0.3))
    piece = x[max(0, onset - int(0.004 * rate)): onset + int(PIECE * rate)].copy()
    fade = int(0.1 * rate)
    piece[-fade:] *= np.linspace(1, 0, fade)
    return piece / max(np.abs(piece).max(), 1e-9), rate


def build(folder, name, seconds, parts):
    rate = parts[0][0][1]
    out = np.zeros(int(rate * seconds))
    for (piece, prate), at, gain in parts:
        assert prate == rate, "the takes' sample rates differ"
        i = int(at * rate)
        end = min(len(out), i + len(piece))
        out[i:end] += piece[: end - i] * gain
    out *= 10 ** (PEAK_DB / 20) / max(np.abs(out).max(), 1e-9)
    sf.write(SOUNDS / folder / f"Track_{name}.wav", out, rate, subtype="PCM_16")
    print(f"{name}: written, {seconds} s")


hype = json.loads((REPO / "sounds" / "hype_tracks.json").read_text(encoding="utf-8"))["tracks"]["Belt"]
emote = json.loads((REPO / "sounds" / "emote_tracks.json").read_text(encoding="utf-8"))["tracks"]["BeltTighten"]

snap_a = hit("Hype", "Belt_3", 0.0, 0.5)              # big snap at 0.15 s
snap_b = hit("Emotes", "BeltTighten_3", 0.6, 1.0)     # snap at 0.75 s
snap_c = hit("Emotes", "BeltTighten_3", 1.1, 1.5)     # snap at 1.2 s
flick = hit("Hype", "Belt_4", 0.0, 0.4)               # short snap at the start
clap = hit("Emotes", "ChalkClap_4", 0.0, 1.0)         # chalky clap

c = hype["cues"]
build("Hype", "Belt", hype["seconds"], [(snap_a, c[0], 0.9), (snap_c, c[1], 1.0), (clap, c[2], 1.0)])
c = emote["cues"]
build("Emotes", "BeltTighten", emote["seconds"], [(snap_b, c[0], 0.9), (snap_a, c[1], 1.0), (flick, c[2], 0.5)])
