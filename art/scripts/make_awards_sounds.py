"""Makes the Local meet awards' default sounds from scratch (GAME_DESIGN §29.10 "Venue redesign and awards ceremony",
user 2026-10-29: the winner's theme song plays and they celebrate; "a default song and cheer at first", the user's
custom theme songs plug in later). Pure synthesis, no samples from anywhere, so they are our own work:

    python -I art/scripts/make_awards_sounds.py            writes art/sounds/Awards_<Name>.wav

    Theme  the default winner's theme: 16 seconds at 120 BPM, a big brassy I-V-vi-IV progression twice with a
           kick-snare-hat beat, a bright lead melody over it and a final held chord
    Cheer  the crowd: applause (hundreds of short claps that swell and fade), a low roar under it and a few
           rising "woo" whistles

Mono, 16-bit, 44.1 kHz WAV (Roblox accepts WAV audio uploads). The same seed gives the same files every run.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "sounds"
rng = random.Random(20261029)

BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def add(buf, start, samples, gain=1.0):
    i0 = int(start * RATE)
    for k, s in enumerate(samples):
        if 0 <= i0 + k < len(buf):
            buf[i0 + k] += s * gain


def brass(freq, length, detune=0.004):
    """A brassy chord voice: a few harmonics on two slightly detuned oscillators, a soft attack, a gentle fall."""
    n = int(length * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        s = 0.0
        for f in (freq * (1 - detune), freq * (1 + detune)):
            for h, a in ((1, 1.0), (2, 0.5), (3, 0.33), (4, 0.22), (5, 0.14)):
                s += a * math.sin(2 * math.pi * f * h * t)
        attack = min(1.0, t / 0.04)
        release = min(1.0, (length - t) / 0.06)
        out.append(s * 0.12 * attack * release * (0.75 + 0.25 * math.exp(-t / 0.3)))
    return out


def lead(freq, length):
    """The melody: a bright square-ish tone with a little vibrato."""
    n = int(length * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1 + 0.006 * math.sin(2 * math.pi * 5.5 * t) * min(1.0, t / 0.15))
        phase += 2 * math.pi * f / RATE
        s = math.sin(phase) + 0.3 * math.sin(3 * phase) + 0.15 * math.sin(5 * phase)
        attack = min(1.0, t / 0.015)
        release = min(1.0, (length - t) / 0.04)
        out.append(s * 0.32 * attack * release)
    return out


def kick():
    n, out, phase = int(RATE * 0.35), [], 0.0
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * (50 + 110 * math.exp(-t / 0.04)) / RATE
        out.append(math.sin(phase) * math.exp(-t / 0.13))
    return out


def snare():
    n, out, last = int(RATE * 0.25), [], 0.0
    for i in range(n):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        out.append(0.7 * (noise - last) * math.exp(-t / 0.08) + 0.4 * math.sin(2 * math.pi * 200 * t) * math.exp(-t / 0.04))
        last = noise
    return out


def hat():
    n, out, p1, p2 = int(RATE * 0.06), [], 0.0, 0.0
    for i in range(n):
        noise = rng.uniform(-1, 1)
        out.append(0.3 * (noise - 2 * p1 + p2) * math.exp(-(i / RATE) / 0.015))
        p2, p1 = p1, noise
    return out


def theme():
    length = 8 * BAR + 2.0
    buf = [0.0] * int(length * RATE)
    # C - G - Am - F, twice (root, third, fifth an octave below middle C and up).
    chords = [(48, 52, 55, 60), (43, 47, 50, 55), (45, 48, 52, 57), (41, 45, 48, 53)] * 2
    for bar, chord in enumerate(chords):
        for midi in chord:
            # Two pushes a bar: a long one and a short stab on the "and" of 3, the fanfare feel.
            add(buf, bar * BAR, brass(note(midi), 2.4 * BEAT), 1.0)
            add(buf, bar * BAR + 2.5 * BEAT, brass(note(midi), 1.3 * BEAT), 0.8)
        add(buf, bar * BAR, brass(note(chord[0] - 12), BAR - 0.05, detune=0.0), 1.4)  # the bass
        for beat in range(4):
            add(buf, bar * BAR + beat * BEAT, kick(), 0.9 if beat in (0, 2) else 0.5)
            if beat in (1, 3):
                add(buf, bar * BAR + beat * BEAT, snare(), 0.8)
            for half in (0, 0.5):
                add(buf, bar * BAR + (beat + half) * BEAT, hat(), 0.6)
    # The melody: (beat from the start, length in beats, midi note).
    melody = [
        (0, 1, 67), (1, 0.5, 67), (1.5, 0.5, 72), (2, 2, 76),
        (4, 1, 74), (5, 0.5, 71), (5.5, 0.5, 74), (6, 2, 79),
        (8, 1, 76), (9, 0.5, 72), (9.5, 0.5, 76), (10, 2, 81),
        (12, 1, 79), (13, 1, 77), (14, 2, 76),
        (16, 1, 67), (17, 0.5, 67), (17.5, 0.5, 72), (18, 2, 76),
        (20, 1, 74), (21, 0.5, 71), (21.5, 0.5, 74), (22, 2, 79),
        (24, 1, 81), (25, 0.5, 79), (25.5, 0.5, 81), (26, 2, 84),
        (28, 1, 83), (29, 1, 79), (30, 2, 84),
    ]
    for start, beats, midi in melody:
        add(buf, start * BEAT, lead(note(midi), beats * BEAT - 0.03))
    # The ending: one big held C major chord with a cymbal-like wash.
    end = 8 * BAR
    for midi in (36, 48, 52, 55, 60, 64, 67, 72):
        add(buf, end, brass(note(midi), 1.9), 1.1)
    add(buf, end, kick(), 1.0)
    wash = [rng.uniform(-1, 1) * 0.25 * math.exp(-(i / RATE) / 0.6) for i in range(int(RATE * 1.9))]
    add(buf, end, wash)
    return buf


def cheer():
    length = 5.5
    n = int(length * RATE)
    buf = [0.0] * n

    def swell(t):
        # Up fast, hold, fade out over the last two seconds.
        return min(1.0, t / 0.6) * min(1.0, (length - t) / 2.0)

    # Applause: about 900 short claps, more of them while the swell is high.
    for _ in range(900):
        t0 = rng.uniform(0, length - 0.1)
        if rng.random() > swell(t0):
            continue
        clap, last = [], 0.0
        tone = rng.uniform(0.3, 0.9)
        for i in range(int(RATE * 0.03)):
            noise = rng.uniform(-1, 1)
            clap.append(((noise - last * tone)) * math.exp(-(i / RATE) / 0.006))
            last = noise
        add(buf, t0, clap, rng.uniform(0.15, 0.4))
    # The roar: low-passed noise following the swell.
    low = 0.0
    for i in range(n):
        low += 0.02 * (rng.uniform(-1, 1) - low)
        buf[i] += low * 2.2 * swell(i / RATE)
    # A few "woo" whistles gliding up.
    for _ in range(7):
        t0 = rng.uniform(0.3, 3.0)
        dur = rng.uniform(0.5, 0.9)
        f0 = rng.uniform(600, 900)
        woo, phase = [], 0.0
        for i in range(int(dur * RATE)):
            t = i / RATE
            phase += 2 * math.pi * f0 * (1 + 0.5 * t / dur) / RATE
            woo.append(math.sin(phase) * math.sin(math.pi * t / dur) ** 2)
        add(buf, t0, woo, 0.12)
    return buf


SOUNDS = {
    "Theme": theme,
    "Cheer": cheer,
}


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.89 / peak  # leave a little headroom
    fade = int(RATE * 0.02)
    for k in range(1, fade + 1):
        samples[-k] *= k / fade
    path = OUT / f"Awards_{name}.wav"
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    return path


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        path = write(name, make())
        print(f"{path.name}: {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
