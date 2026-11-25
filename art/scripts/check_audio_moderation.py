"""Read-only: the moderation state of every uploaded audio in an upload manifest (Open Cloud Assets API).

    python art/scripts/check_audio_moderation.py art/sounds/coach_voice_lines.json

New audio is reviewed by Roblox before it plays in a live game (Studio plays it for the owner while it is still
under review), so a line can work in Studio and be silent on a phone. The API key is read the same way as
upload_group_images.py and is only sent to apis.roblox.com.
"""
import json
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path

KEY_FILE = Path.home() / ".fwjelaa" / "roblox-open-cloud.key"


def state(asset_id, key):
    req = urllib.request.Request(f"https://apis.roblox.com/assets/v1/assets/{asset_id}?readMask=moderationResult",
                                 headers={"x-api-key": key})
    for _ in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as res:
                return json.load(res).get("moderationResult", {}).get("moderationState", "?")
        except urllib.error.HTTPError as err:
            if err.code == 429:
                time.sleep(3)
                continue
            return f"HTTP {err.code}"
    return "rate limited"


def main(path):
    key = KEY_FILE.read_text(encoding="utf-8").strip()
    sounds = json.loads(Path(path).read_text(encoding="utf-8"))["sounds"]
    counts, by_coach = Counter(), {}
    for name, entry in sounds.items():
        audio = entry.get("ids", {}).get("audio", "")
        if not audio:
            continue
        st = state(audio.replace("rbxassetid://", ""), key)
        counts[st] += 1
        by_coach.setdefault(entry.get("lift", "?"), Counter())[st] += 1
        if st != "Approved":
            print(f"  {name}: {st}")
        time.sleep(0.25)
    print("all:", dict(counts))
    for coach, c in by_coach.items():
        print(f"  {coach}: {dict(c)}")


if __name__ == "__main__":
    main(sys.argv[1])
