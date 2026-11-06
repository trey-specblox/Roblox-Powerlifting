"""Makes the crate reel's tick from scratch (GAME_DESIGN §35.12): pure synthesis, no samples, so it is our own work.

    python -I art/scripts/make_crate_tick.py            writes art/sounds/Crate_Tick.wav

A short dry click, like a card flicking past a peg: a falling tone and a burst of noise, 40 ms.
Mono, 16-bit, 44.1 kHz WAV. The same seed gives the same file every run.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
SECONDS = 0.04
OUT = Path(__file__).resolve().parent.parent / "sounds" / "Crate_Tick.wav"


def main():
    random.seed(7)
    samples = []
    phase = 0.0
    for i in range(int(RATE * SECONDS)):
        t = i / RATE
        pitch = 1500 - 9000 * t
        phase += 2 * math.pi * max(pitch, 300) / RATE
        tone = math.sin(phase) * math.exp(-t * 110)
        noise = (random.random() * 2 - 1) * math.exp(-t * 320)
        samples.append(0.75 * tone + 0.35 * noise)
    peak = max(abs(s) for s in samples)
    with wave.open(str(OUT), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.9 * 32767)) for s in samples))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
