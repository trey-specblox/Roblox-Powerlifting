"""Cleans up the celebrations' body sounds (GAME_DESIGN §36.4; CelebrationConfig.Sounds): knees on the platform, a jump
landing, sitting down, a light foot tap and a firm stomp. The user, 2026-11-11: "We dont need voices for the celebrations,
just have the sound affect like knee thumping and stuff, just make them very clear and smooth."

Made with ElevenLabs Sound Effects (prompts in art/sounds/elevenlabs_shouts.json, Celeb_* entries). For each raw MP3 in
Shouts/Raw this:
  - starts the sound right on its hit, 4 ms early with a 3 ms fade in (no click, and it lands on the animation's moment);
  - takes off the rumble under ~45 Hz and the hiss over ~7 kHz (a cleaner, rounder hit);
  - makes it die away like a real impact, about 12 dB in the first 0.1 s (real landings do: make_meet_sounds.py), so the
    board creak and room ring the takes carried don't linger, then fades it out smoothly;
  - brings every sound to the same peak, so the game's volumes set how loud each one is.
Writes Shouts/CelebFx_<Name>.wav (mono, as a sound placed in the world needs). The audio stays outside the repo.

    uv run --no-project --with numpy --with soundfile python art/scripts/make_celebration_sounds.py
Upload with:
    python art/scripts/upload_group_images.py art/sounds/elevenlabs_shouts.json
"""
import pathlib

import numpy as np
import soundfile as sf

SHOUTS = pathlib.Path(r"D:\Powerlifting Roblox Extras\Sounds\Shouts")
# name: (raw file, how fast it dies away: the decay's time constant in seconds)
SOUNDS = {
    "Knees": ("Celeb_Knees.mp3", 0.08),
    "Land": ("Celeb_Land.mp3", 0.065),
    "Sit": ("Celeb_Sit.mp3", 0.085),
    "FootTap": ("Celeb_FootTap.mp3", 0.045),
    "Stomp": ("Celeb_Stomp.mp3", 0.06),
}
HIGH_PASS_HZ = 45
LOW_PASS_HZ = 7000
PRE_SECONDS = 0.004
FADE_IN_SECONDS = 0.003
FADE_OUT_SECONDS = 0.03
# The hit: the first moment within this many dB of the loudest.
ONSET_DB = 12
PEAK_DB = -2.0


def filtered(mono, rate):
    """A smooth high-pass and low-pass, done in one go on the whole (short) clip."""
    pad = len(mono)
    spectrum = np.fft.rfft(np.concatenate([mono, np.zeros(pad)]))
    f = np.fft.rfftfreq(2 * pad, 1 / rate)
    high = (f / HIGH_PASS_HZ) ** 4 / (1 + (f / HIGH_PASS_HZ) ** 4)
    low = 1 / (1 + (f / LOW_PASS_HZ) ** 4)
    return np.fft.irfft(spectrum * high * low)[:pad]


def prepare(raw, out, tau):
    data, rate = sf.read(raw, always_2d=True)
    mono = filtered(data.mean(axis=1), rate)
    window = max(1, int(rate * 0.002))
    blocks = np.abs(mono[: len(mono) // window * window]).reshape(-1, window).max(axis=1)
    levels = 20 * np.log10(np.maximum(blocks, 1e-9))
    peak_level = levels.max()
    onset = int(np.argmax(levels >= peak_level - ONSET_DB)) * window
    peak = onset + int(np.argmax(np.abs(mono[onset: onset + int(rate * 0.06)])))
    start = max(0, onset - int(PRE_SECONDS * rate))
    length = (peak - start) + int(5 * tau * rate)
    cut = mono[start: start + length].copy()
    t = np.arange(len(cut)) / rate
    hit = (peak - start) / rate
    # A real impact's decay after the hit (never louder than the take itself).
    cut *= np.where(t > hit, np.exp(-(t - hit) / tau), 1.0)
    fade_in = int(FADE_IN_SECONDS * rate)
    cut[:fade_in] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, fade_in))
    fade_out = int(FADE_OUT_SECONDS * rate)
    cut[-fade_out:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, fade_out))
    cut *= 10 ** (PEAK_DB / 20) / max(np.abs(cut).max(), 1e-9)
    sf.write(out, cut, rate, subtype="PCM_16")
    print(f"{out.name}: {len(cut) / rate:.2f} s, hit at {hit:.3f} s, -12 dB by {hit + tau * 1.38:.2f} s")


def main():
    for name, (raw_name, tau) in SOUNDS.items():
        raw = SHOUTS / "Raw" / raw_name
        if raw.exists():
            prepare(raw, SHOUTS / f"CelebFx_{name}.wav", tau)
        else:
            print(f"(no {raw_name} yet)")


if __name__ == "__main__":
    main()
