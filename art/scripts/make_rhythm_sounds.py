"""Makes the treadmill rhythm game's sounds from scratch (GAME_DESIGN §27 "The treadmill rhythm game": "our own
endless beat", user 2026-10-26). Pure synthesis, no samples from anywhere, so they are our own work:

    python -I art/scripts/make_rhythm_sounds.py            writes art/sounds/Rhythm_<Name>.wav

    Kick   a deep drum: a sine wave falling from 150 to 48 Hz with a short click
    Snare  a bright crack: filtered noise over a 190 Hz body
    Hat    a short tick: high noise, 50 ms
    Hit    the "you hit it" blip: two short sine tones a fifth apart
    Miss   the "missed" buzz: a low, short, slightly rough tone
    Count  the countdown beep: a clean 880 Hz tone

Mono, 16-bit, 44.1 kHz WAV (Roblox accepts WAV audio uploads). The same seed gives the same files every run.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "sounds"
rng = random.Random(20261026)


def env(t, attack, decay):
    """A quick rise and an exponential fall."""
    return min(1.0, t / attack) * math.exp(-t / decay) if attack > 0 else math.exp(-t / decay)


def kick(n):
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        freq = 48 + 102 * math.exp(-t / 0.045)
        phase += 2 * math.pi * freq / RATE
        click = (rng.uniform(-1, 1) * math.exp(-t / 0.003)) * 0.3
        out.append(math.sin(phase) * env(t, 0.002, 0.16) + click)
    return out


def snare(n):
    out, last, phase = [], 0.0, 0.0
    for i in range(n):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        bright = noise - last  # a simple high-pass: the snappy part
        last = noise
        phase += 2 * math.pi * 190 / RATE
        body = math.sin(phase) * env(t, 0.001, 0.05)
        out.append(0.75 * bright * env(t, 0.001, 0.09) + 0.5 * body)
    return out


def hat(n):
    out, prev, prev2 = [], 0.0, 0.0
    for i in range(n):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        high = noise - 2 * prev + prev2  # second difference: only the hiss
        prev2, prev = prev, noise
        out.append(0.35 * high * env(t, 0.0005, 0.018))
    return out


def tones(n, freqs, decay, rough=0.0):
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(math.sin(2 * math.pi * f * t) for f in freqs) / len(freqs)
        if rough:
            s = math.copysign(abs(s) ** (1 - rough), s)
        out.append(s * env(t, 0.003, decay))
    return out


SOUNDS = {
    "Kick": lambda: kick(int(RATE * 0.45)),
    "Snare": lambda: snare(int(RATE * 0.3)),
    "Hat": lambda: hat(int(RATE * 0.08)),
    "Hit": lambda: tones(int(RATE * 0.14), (880, 1320), 0.04),
    "Miss": lambda: tones(int(RATE * 0.22), (110, 116), 0.08, rough=0.6),
    "Count": lambda: tones(int(RATE * 0.2), (880,), 0.07),
}


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.89 / peak  # leave a little headroom
    # A 4 ms fade-out so no sound ends with a click.
    fade = int(RATE * 0.004)
    for k in range(1, fade + 1):
        samples[-k] *= k / fade
    path = OUT / f"Rhythm_{name}.wav"
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
