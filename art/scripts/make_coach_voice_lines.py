"""Turn the coaches' ElevenLabs takes into upload-ready WAVs and the upload manifest.

    uv run --no-project --with soundfile --with numpy python art/scripts/make_coach_voice_lines.py
    python art/scripts/upload_group_images.py art/sounds/coach_voice_lines.json

Reads the word-checked takes in D:/ClaudeScratch/coachvoices/lines/<Lift>_<key>.mp3 and their texts in
D:/ClaudeScratch/coachvoices/lines.json (the voices and tags are in art/sounds/coach_voices.json). Each take is
trimmed to its speech (a short lead-in and tail kept), faded at both ends so nothing clicks, and set to one
loudness, so every coach sounds equally loud next to the others. WAVs go to
D:/Powerlifting Roblox Extras/Sounds/CoachVoices (outside the repo). The manifest keeps ids already uploaded.
"""
import json
from pathlib import Path

import numpy as np
import soundfile as sf

TAKES = Path("D:/ClaudeScratch/coachvoices")
OUT = Path("D:/Powerlifting Roblox Extras/Sounds/CoachVoices")
MANIFEST = Path(__file__).resolve().parents[1] / "sounds" / "coach_voice_lines.json"
COACH = {"Squat": "Coach Squatavious", "Bench": "Coach Benchamin", "Deadlift": "Coach Sumo", "Owner": "The Gym Owner"}
PLURAL = {"Squat": "squats", "Bench": "bench presses", "Deadlift": "deadlifts"}
WORD = {"Squat": "squat", "Bench": "bench", "Deadlift": "deadlift"}
TARGET_RMS = 0.10  # loudness of the speech itself (frames above the silence gate)
PEAK = 0.95


def clean(data, sr):
    frame = int(sr * 0.01)
    env = np.array([np.sqrt(np.mean(data[i:i + frame] ** 2)) for i in range(0, len(data) - frame, frame)])
    speech = np.where(env > 0.01)[0]
    start = max(0, speech[0] * frame - int(sr * 0.05))
    end = min(len(data), (speech[-1] + 1) * frame + int(sr * 0.15))
    data = data[start:end].copy()
    fade = int(sr * 0.01)
    data[:fade] *= np.linspace(0, 1, fade)
    data[-fade:] *= np.linspace(1, 0, fade)
    loud = env[speech]
    gain = TARGET_RMS / float(np.sqrt(np.mean(loud ** 2)))
    gain = min(gain, PEAK / float(np.max(np.abs(data))))
    return (data * gain).astype("float32")


def main():
    lines = json.loads((TAKES / "lines.json").read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.is_file() else {}
    manifest["about"] = ("The coaches' voice lines (made by art/scripts/make_coach_voice_lines.py from the takes listed in "
                         "art/sounds/coach_voices.json; uploaded with art/scripts/upload_group_images.py). Name = "
                         "Coach<Lift>_<key>; text = what the line says.")
    sounds = manifest.setdefault("sounds", {})
    OUT.mkdir(parents=True, exist_ok=True)
    for lift, gens in lines["generations"].items():
        for key in gens:
            text = lines["keys"].get(key) or lines["talk_keys"][key]
            text = text.replace("{plural}", PLURAL.get(lift, "")).replace("{word}", WORD.get(lift, ""))
            data, sr = sf.read(TAKES / "lines" / f"{lift}_{key}.mp3", dtype="float32")
            if data.ndim > 1:
                data = data.mean(axis=1)
            name = f"Coach{lift}_{key}"
            path = OUT / f"{name}.wav"
            clean_data = clean(data, sr)
            sf.write(path, clean_data, sr, subtype="PCM_16")
            entry = sounds.setdefault(name, {})
            entry.update({"coach": COACH[lift], "lift": lift, "key": key, "text": text, "file": path.as_posix(),
                          "seconds": round(len(clean_data) / sr, 2), "generation": gens[key],
                          "license": "ElevenLabs generated; commercial use depends on the account's plan"})
            entry.setdefault("ids", {})
    MANIFEST.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(len(sounds), "lines ready in", OUT)


if __name__ == "__main__":
    main()
