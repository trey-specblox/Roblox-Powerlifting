"""Upload prepared assets to Roblox owned by the game's GROUP (Open Cloud Assets API).

    python art/scripts/upload_group_images.py art/materials/materials.json          upload what has no id yet
    python art/scripts/upload_group_images.py art/materials/materials.json --dry    only list what would be uploaded

The manifest lists each material's prepared map files (color/normal/roughness PNGs, made from ambientCG or
Poly Haven with the Roblox Maps kit's prep step) under "materials", GLB models under "models" (uploaded as
Model assets: a GLB arrives at 1 Blender unit = 1 stud) and single PNG pictures under "images" (signs,
drawings), and receives the uploaded asset ids. Ids already in the manifest are never uploaded again.

Why our own uploader: the game belongs to group 529442797, so its images must be owned by that group (images a
user uploads fail to load in a group game). The Maps kit's uploader always uploads as the user.

The API key is read from %USERPROFILE%/.fwjelaa/roblox-open-cloud.key (outside the repo). It is only ever sent to
apis.roblox.com as the x-api-key header and is never printed.
"""
import json
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

GROUP_ID = "529442797"
API = "https://apis.roblox.com/assets/v1"
KEY_FILE = Path.home() / ".fwjelaa" / "roblox-open-cloud.key"
MAP_ORDER = ("color", "normal", "roughness", "metalness")


def read_key():
    if not KEY_FILE.is_file():
        sys.exit(f"No API key file at {KEY_FILE}")
    key = KEY_FILE.read_text(encoding="utf-8").strip()
    if not key:
        sys.exit(f"The API key file {KEY_FILE} is empty")
    return key


def request(url, key, data=None, content_type=None):
    headers = {"x-api-key": key}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if data is not None else "GET")
    try:
        with urllib.request.urlopen(req, timeout=120) as res:
            return json.load(res)
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", "replace").replace(key, "<key>")
        sys.exit(f"Roblox answered {err.code}: {body[:300]}")


KINDS = {  # file suffix -> (asset type, content type)
    ".png": ("Image", "image/png"),
    ".glb": ("Model", "model/gltf-binary"),
}


def upload_file(path, display_name, key):
    asset_type, content_type = KINDS[path.suffix.lower()]
    meta = {
        "assetType": asset_type,
        "displayName": display_name[:50],
        "description": "Asset for the Elite Prep Gym (Powerlifting: Road to Elite)",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    boundary = uuid.uuid4().hex
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\n"
        f"Content-Type: {content_type}\r\n\r\n"
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
    manifest_path = Path(argv[0])
    dry = "--dry" in argv
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    todo = []
    for name, entry in manifest.get("materials", {}).items():
        folder = Path(entry["preparedFolder"]).expanduser()
        ids = entry.setdefault("ids", {})
        for kind in MAP_ORDER:
            if kind in entry["maps"] and not ids.get(kind):
                path = folder / f"{kind}.png"
                if not path.is_file():
                    sys.exit(f"{name}: missing {path}")
                todo.append(("materials", name, kind, path))
    for name, entry in manifest.get("models", {}).items():
        ids = entry.setdefault("ids", {})
        if not ids.get("model"):
            path = Path(entry["file"])
            if not path.is_file():
                sys.exit(f"{name}: missing {path}")
            todo.append(("models", name, "model", path))
    for name, entry in manifest.get("images", {}).items():
        ids = entry.setdefault("ids", {})
        if not ids.get("image"):
            path = Path(entry["file"]).expanduser()
            if not path.is_file():
                sys.exit(f"{name}: missing {path}")
            todo.append(("images", name, "image", path))
    print(f"{len(todo)} asset(s) to upload as group {GROUP_ID}:")
    for _, name, kind, path in todo:
        print(f"  {name} {kind}: {path} ({path.stat().st_size // 1024} KB)")
    if dry or not todo:
        return 0
    key = read_key()
    for section, name, kind, path in todo:
        asset = upload_file(path, f"{name} {kind}", key)
        manifest[section][name]["ids"][kind] = asset
        # save after every upload, so an interrupted run never uploads the same map twice
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"  uploaded {name} {kind} -> {asset}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
