"""Finishes two emote tracks whose ElevenLabs takes would not give every clap (2026-11-11: every Chalk Clap take had a
single clap at its very start; the Trap Slap takes had the two shoulder slaps but no final clap).

    TRACKS_MANIFEST=art/sounds/emote_tracks.json TRACKS_ROOT="D:/Powerlifting Roblox Extras/Sounds/Emotes" \
    uv run --no-project --with numpy --with soundfile python art/scripts/compose_emote_claps.py

Chalk Clap: the clap from two different takes (so they don't sound copied), at its cues 0.35 and 0.65 s, each with its
natural tail. Trap Slap: its lined-up track (make_celebration_tracks.py) plus a clap from a third Chalk Clap take at its
1.15 s cue. Run after make_celebration_tracks.py; overwrites Track_ChalkClap.wav and Track_TrapSlap.wav.
"""
import json
import os
import pathlib

import numpy as np
import soundfile as sf

ROOT = pathlib.Path(os.environ.get("TRACKS_ROOT", r"D:\Powerlifting Roblox Extras\Sounds\Emotes"))
MANIFEST = pathlib.Path(os.environ.get("TRACKS_MANIFEST", pathlib.Path(__file__).resolve().parent.parent / "sounds" /
                                       "emote_tracks.json"))
CLAP_LENGTH = 0.45      # seconds of each clap kept (it has died away by then)
PEAK_DB = -3.0


def clap(take):
    x, rate = sf.read(ROOT / "Raw" / "candidates" / f"{take}.mp3", always_2d=True)
    x = x.mean(axis=1)
    start = int(np.argmax(np.abs(x) > np.abs(x).max() * 0.3))
    piece = x[max(0, start - int(0.004 * rate)): start + int(CLAP_LENGTH * rate)].copy()
    fade = int(0.08 * rate)
    piece[-fade:] *= np.linspace(1, 0, fade)
    return piece, rate


def place(out, piece, at, rate, gain=1.0):
    i = int(at * rate)
    end = min(len(out), i + len(piece))
    out[i:end] += piece[: end - i] * gain


def finish(out, rate, name):
    out *= 10 ** (PEAK_DB / 20) / max(np.abs(out).max(), 1e-9)
    sf.write(ROOT / f"Track_{name}.wav", out, rate, subtype="PCM_16")
    print(f"{name}: written")


manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
first, rate = clap("ChalkClap_3")
second, _ = clap("ChalkClap_4")
cues = manifest["tracks"]["ChalkClap"]["cues"]
out = np.zeros(int(rate * (manifest["tracks"]["ChalkClap"]["seconds"] + 0.4)))
place(out, first, cues[0], rate)
place(out, second, cues[1], rate, 0.92)
finish(out, rate, "ChalkClap")

track, trate = sf.read(ROOT / "Track_TrapSlap.wav")
third, crate = clap("ChalkClap_1")
assert crate == trate, "the takes' sample rates differ"
# The clap as loud as the track's loudest slap.
place(track, third * (np.abs(track).max() / max(np.abs(third).max(), 1e-9)), manifest["tracks"]["TrapSlap"]["cues"][2], trate)
finish(track, trate, "TrapSlap")
