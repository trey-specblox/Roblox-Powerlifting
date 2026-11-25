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


def trim(data, sr):
    """The take cut to its speech (a short lead-in and tail), faded at both ends; and its speech loudness (RMS)."""
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
    return data, float(np.sqrt(np.mean(loud ** 2)))


def coach_gains(takes):
    """ONE gain per coach (his median line to TARGET_RMS), so within a coach a scream stays louder than a growl
    (user 2026-11-25: growls intense, the slap a full scream); each line only turned down if it would clip."""
    by = {}
    for (lift, _key), (_data, rms) in takes.items():
        by.setdefault(lift, []).append(rms)
    return {lift: TARGET_RMS / float(np.median(v)) for lift, v in by.items()}


def main():
    lines = json.loads((TAKES / "lines.json").read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.is_file() else {}
    manifest["about"] = ("The coaches' voice lines (made by art/scripts/make_coach_voice_lines.py from the takes listed in "
                         "art/sounds/coach_voices.json; uploaded with art/scripts/upload_group_images.py). Name = "
                         "Coach<Lift>_<key>; text = what the line says.")
    sounds = manifest.setdefault("sounds", {})
    OUT.mkdir(parents=True, exist_ok=True)
    # Round 2 (2026-11-25, in the delivery the user chose per kind of line) replaced round 1 (too calm).
    generations = lines.get("generations_v2") or lines["generations"]
    folder = "lines_v2" if "generations_v2" in lines else "lines"
    takes, rate = {}, {}
    for lift, gens in generations.items():
        for key in gens:
            data, sr = sf.read(TAKES / folder / f"{lift}_{key}.mp3", dtype="float32")
            if data.ndim > 1:
                data = data.mean(axis=1)
            takes[(lift, key)] = trim(data, sr)
            rate[(lift, key)] = sr
    gains = coach_gains(takes)
    texts = {key: lines["keys"].get(key) or lines["talk_keys"][key] for gens in generations.values() for key in gens}
    # Round 3 (2026-11-25: walk-out W, big yells H, end-of-meet scene P, coach unlock U) is added on top, at each
    # coach's round 2 gain, so the new lines are as loud as the ones already in the game (and those don't change).
    if lines.get("generations_v3"):
        generations = {lift: dict(gens) for lift, gens in generations.items()}
        for lift, gens in lines["generations_v3"].items():
            for key, gen in gens.items():
                data, sr = sf.read(TAKES / "lines_v3" / f"{lift}_{key}.mp3", dtype="float32")
                if data.ndim > 1:
                    data = data.mean(axis=1)
                takes[(lift, key)] = trim(data, sr)
                rate[(lift, key)] = sr
                generations.setdefault(lift, {})[key] = gen
                texts[key] = lines["keys_v3"][key]
    for lift, gens in generations.items():
        for key in gens:
            text = texts[key]
            text = text.replace("{plural}", PLURAL.get(lift, "")).replace("{word}", WORD.get(lift, ""))
            data, _rms = takes[(lift, key)]
            sr = rate[(lift, key)]
            name = f"Coach{lift}_{key}"
            path = OUT / f"{name}.wav"
            gain = min(gains[lift], PEAK / float(np.max(np.abs(data))))
            clean_data = (data * gain).astype("float32")
            sf.write(path, clean_data, sr, subtype="PCM_16")
            entry = sounds.setdefault(name, {})
            if entry.get("generation") and entry["generation"] != gens[key]:
                # a new take: the old upload is kept for the record and the new one gets uploaded
                entry.setdefault("replaced", []).append({"generation": entry["generation"], "ids": entry.get("ids", {})})
                entry["ids"] = {}
            entry.update({"coach": COACH[lift], "lift": lift, "key": key, "text": text, "file": path.as_posix(),
                          "seconds": round(len(clean_data) / sr, 2), "generation": gens[key],
                          "license": "ElevenLabs generated; commercial use depends on the account's plan"})
            entry.setdefault("ids", {})
    MANIFEST.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(len(sounds), "lines ready in", OUT)


if __name__ == "__main__":
    main()
