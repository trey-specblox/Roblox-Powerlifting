"""Prepares the shouts people yell at a meet (GAME_DESIGN §37.5, the *Shout cues in MeetSoundConfig).

Made with ElevenLabs Sound Effects; the prompts are in art/sounds/elevenlabs_shouts.json. This reads the downloaded
MP3s from Shouts/Raw, cuts the silence off both ends, makes them mono (a Roblox sound placed in the world needs that to
come from a place), evens out their loudness so no one voice jumps out, and writes one WAV each to Shouts.
Newer shouts have a raw file named after their manifest entry (Raw/GoodShout_1.mp3); it only makes the ones not uploaded yet.

The audio stays outside the repo, like the other game sounds. Run with:
    uv run --no-project --with numpy --with soundfile python art/scripts/make_lift_shouts.py
Upload with:
    python art/scripts/upload_group_images.py art/sounds/elevenlabs_shouts.json
"""
import json
import pathlib

import numpy as np
import soundfile as sf

SHOUTS = pathlib.Path(r"D:\Powerlifting Roblox Extras\Sounds\Shouts")
MANIFEST = pathlib.Path(__file__).resolve().parent.parent / "sounds" / "elevenlabs_shouts.json"
# A sound counts as started or finished at this level, relative to the file's own peak.
EDGE_DB = -35
KEEP_BEFORE_SECONDS = 0.01
# After the last loud moment, kept for the room's echo, and faded out.
KEEP_AFTER_SECONDS = 0.25
MAX_SECONDS = 3
FADE_SECONDS = 0.08
# All brought to about this loudness over their loud part, with the peak never above PEAK_LIMIT.
TARGET_RMS_DB = -14
PEAK_LIMIT = 0.97


def db(value):
    return 20 * np.log10(max(value, 1e-9))


def window_levels(mono, rate):
    size = max(1, int(rate * 0.01))
    usable = len(mono) // size * size
    blocks = mono[:usable].reshape(-1, size)
    return np.sqrt((blocks ** 2).mean(axis=1)), size


def prepare(path, out):
    data, rate = sf.read(path, always_2d=True)
    mono = data.mean(axis=1)
    levels, size = window_levels(mono, rate)
    edge = levels.max() * 10 ** (EDGE_DB / 20)
    loud = np.nonzero(levels >= edge)[0]
    start = max(0, loud[0] * size - int(KEEP_BEFORE_SECONDS * rate))
    end = min(len(mono), (loud[-1] + 1) * size + int(KEEP_AFTER_SECONDS * rate))
    # A few takes ramble on (one was 8 s long): a shout is short, or it talks over the next one.
    cut = mono[start:min(end, start + int(MAX_SECONDS * rate))].copy()

    fade = min(len(cut), int(FADE_SECONDS * rate))
    cut[-fade:] *= np.linspace(1, 0, fade)
    cut[:32] *= np.linspace(0, 1, 32)

    levels, _ = window_levels(cut, rate)
    rms = np.sqrt((levels[levels >= levels.max() * 0.25] ** 2).mean())
    gain = 10 ** (TARGET_RMS_DB / 20) / rms
    peak = np.abs(cut).max()
    limited = peak * gain > PEAK_LIMIT
    if limited:
        gain = PEAK_LIMIT / peak
    cut *= gain
    sf.write(out, cut, rate, subtype="PCM_16")
    print(f"{out.name}: was {len(mono) / rate:.2f} s, now {len(cut) / rate:.2f} s, starts {start / rate:.2f} s in, "
          f"peak {db(np.abs(cut).max()):.1f} dB, loud part {db(rms * gain):.1f} dB"
          f"{' (held by the peak limit)' if limited else ''}")


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for name, entry in manifest["sounds"].items():
        raw = SHOUTS / "Raw" / f"{name}.mp3"
        if raw.exists() and not entry.get("ids", {}).get("audio"):
            prepare(raw, SHOUTS / f"{name}.wav")


if __name__ == "__main__":
    main()
