"""Publish exported animations to Roblox, owned by the game's GROUP (Open Cloud Assets API).

    python art/scripts/upload_animations.py art/animations/Fail_Deadlift_1.rbxmx art/animations/Fail_Deadlift_2.rbxmx

Each file is an .rbxmx holding one KeyframeSequence (art/scripts/fail_animations.py exports them). Roblox takes
animations only in the binary .rbxm form, so each is first built into one with Rojo, in a temporary folder.
Prints one line per file, "<name> rbxassetid://<number>", to paste into
src/shared/Config/StationAnimationConfig.luau.

Every run publishes NEW assets; nothing checks for an earlier upload. The API key is handled as in
upload_group_images.py: read from outside the repo, sent only to apis.roblox.com, never printed.
"""
import json
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from upload_group_images import API, GROUP_ID, read_key, request  # noqa: E402


def to_rbxm(path, folder):
    """Builds the .rbxmx at `path` into an .rbxm in `folder` and returns its path."""
    project = Path(folder) / f"{path.stem}.project.json"
    project.write_text(json.dumps({"name": path.stem, "tree": {"$path": str(path.resolve())}}), encoding="utf-8")
    output = Path(folder) / f"{path.stem}.rbxm"
    subprocess.run(["rojo", "build", str(project), "-o", str(output)], check=True, capture_output=True)
    return output


def upload(path, key):
    meta = {
        "assetType": "Animation",
        "displayName": path.stem[:50],
        "description": "Animation for Powerlifting: Road to Elite",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    boundary = uuid.uuid4().hex
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\n"
        f"Content-Type: model/x-rbxm\r\n\r\n"
    ).encode() + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    op = request(f"{API}/assets", key, body, f"multipart/form-data; boundary={boundary}")
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(90):
        if op.get("done"):
            if "response" not in op:
                sys.exit(f"Upload of {path} failed: {op.get('error')}")
            return "rbxassetid://" + str(op["response"]["assetId"])
        time.sleep(2)
        op = request(f"{API}/operations/{op_id}", key)
    sys.exit(f"Upload of {path} did not finish in time")


def main(argv):
    if not argv:
        sys.exit(__doc__)
    paths = [Path(name) for name in argv]
    for path in paths:
        if not path.is_file() or path.suffix.lower() != ".rbxmx":
            sys.exit(f"Not an .rbxmx file: {path}")
    key = read_key()
    with tempfile.TemporaryDirectory() as folder:
        for path in paths:
            print(path.stem, upload(to_rbxm(path, folder), key), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
