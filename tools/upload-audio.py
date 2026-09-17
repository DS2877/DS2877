"""Upload an audio file to Roblox as an Audio asset, via Open Cloud.

    python3 tools/upload-audio.py --file build/nomling-theme.ogg \
        --name "Nomling Glade" --user-id 1234567

Roblox takes .ogg and .mp3 for audio, never .wav, so run
`python3 tools/music/render.py` first -- it emits the .ogg.

Uploading costs nothing. The asset then goes through automated moderation,
which is why this polls the returned operation rather than assuming success:
an asset that exists but is still pending will not play in a game.

NOTE ON SCOPES. This needs an API key with the **`asset`** API system and the
**Write** operation -- a different permission from the `universe-places` one
used for publishing. If the key lacks it, this fails with 401/403 and prints
exactly what to add in Creator Hub.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import opencloud  # noqa: E402

ASSETS_URL = f"{opencloud.BASE}/assets/v1/assets"
OPERATION_URL = f"{opencloud.BASE}/assets/v1/operations"

CONTENT_TYPES = {".ogg": "audio/ogg", ".mp3": "audio/mpeg"}


def multipart(request_json: dict, file_path: str, content_type: str) -> tuple[bytes, str]:
    """Builds a multipart/form-data body by hand -- no requests dependency."""
    boundary = f"----nomling{uuid.uuid4().hex}"
    with open(file_path, "rb") as fh:
        payload = fh.read()

    parts: list[bytes] = []

    def field(name: str, value: bytes, extra: str = "") -> None:
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"{extra}\r\n'.encode()
        )
        parts.append(b"\r\n" if not extra else b"")
        parts.append(value)
        parts.append(b"\r\n")

    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n'.encode())
    parts.append(json.dumps(request_json).encode())
    parts.append(b"\r\n")

    filename = os.path.basename(file_path)
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; '
        f'filename="{filename}"\r\nContent-Type: {content_type}\r\n\r\n'.encode()
    )
    parts.append(payload)
    parts.append(b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())

    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def upload(file_path: str, name: str, description: str, user_id: str, group_id: str | None) -> dict:
    extension = os.path.splitext(file_path)[1].lower()
    content_type = CONTENT_TYPES.get(extension)
    if not content_type:
        opencloud.die(
            f"{extension} is not an audio format Roblox accepts.\n"
            "  Use .ogg or .mp3 -- `python3 tools/music/render.py` emits the .ogg."
        )

    creator: dict = {"userId": str(user_id)} if not group_id else {"groupId": str(group_id)}
    request_json = {
        "assetType": "Audio",
        "displayName": name,
        "description": description,
        "creationContext": {"creator": creator},
    }

    body, ct = multipart(request_json, file_path, content_type)
    size_kb = os.path.getsize(file_path) / 1024
    print(f"Uploading {file_path} ({size_kb:.0f} KB) as Audio '{name}'")

    try:
        result = opencloud.request("POST", ASSETS_URL, body=body, content_type=ct)
    except opencloud.OpenCloudError as exc:
        message = str(exc)
        if "401" in message or "403" in message:
            message += (
                "\n\n  Audio upload needs a DIFFERENT permission from publishing.\n"
                "  Creator Hub -> Credentials -> API Keys -> edit your key:\n"
                "    add the `assets` API system with BOTH Read and Write.\n"
                "  Read is not optional: the upload is asynchronous and this\n"
                "  script polls GET /assets/v1/operations/... for the result.\n"
                "  Publishing uses `universe-places` -> Write; you need both.\n"
                "  Docs: create.roblox.com/docs/cloud/guides/usage-assets"
            )
        opencloud.die(message)

    return result


def wait_for_asset(operation: dict, timeout_seconds: int = 240) -> dict:
    """Polls the operation until moderation finishes. Returns the asset info."""
    path = operation.get("path") or operation.get("operationId")
    if not path:
        # Some responses return the asset directly with no operation to poll.
        return operation
    if not path.startswith("operations/"):
        path = f"operations/{path}"

    url = f"{opencloud.BASE}/assets/v1/{path}"
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        result = opencloud.request("GET", url)
        if result.get("done"):
            return result.get("response", result)
        print("  moderation pending...", flush=True)
        time.sleep(10)
    opencloud.die(
        "Upload did not finish moderation within the timeout.\n"
        "  The asset probably exists -- check Creator Hub -> Development Items -> Audio."
    )
    return {}


MANIFEST = {
    "nomling-glade": ("Nomling Glade", "MUSIC", "theme"),
    "sfx-coin": ("Nomling Coin", "SFX", "coin"),
    "sfx-purchase": ("Nomling Purchase", "SFX", "purchase"),
    "sfx-hatch": ("Nomling Hatch", "SFX", "hatch"),
    "sfx-reveal": ("Nomling Reveal", "SFX", "reveal"),
    "sfx-snatchAlarm": ("Nomling Snatch Alarm", "SFX", "snatchAlarm"),
    "sfx-snatchGrab": ("Nomling Snatch Grab", "SFX", "snatchGrab"),
    "sfx-deny": ("Nomling Deny", "SFX", "deny"),
}


def upload_all(directory: str, user_id: str, group_id: str | None) -> int:
    """Uploads every known audio file in a directory and prints the Luau block.

    Assembling the config by hand is the real bottleneck once the scope exists:
    eight asset ids typed into two tables is exactly the sort of thing that goes
    wrong quietly, so this prints the finished block instead.
    """
    results: dict[str, dict[str, int]] = {"MUSIC": {}, "SFX": {}}
    failures: list[str] = []

    for stem, (display, section, key) in MANIFEST.items():
        path = os.path.join(directory, f"{stem}.ogg")
        if not os.path.isfile(path):
            print(f"  skip {stem}: not found")
            continue
        try:
            operation = upload(path, display, f"Fuse a Nomling -- {display}.", user_id, group_id)
            asset = wait_for_asset(operation)
            asset_id = asset.get("assetId") or asset.get("id")
        except SystemExit:
            # opencloud.die() already explained the problem; keep going so one
            # bad file does not hide the rest.
            failures.append(stem)
            continue
        if asset_id:
            results[section][key] = int(asset_id)
            print(f"  ok   {stem} -> {asset_id}")
        else:
            failures.append(stem)

    print("\n--- paste into src/shared/Config/Audio.luau ---")
    for section in ("MUSIC", "SFX"):
        for key, value in results[section].items():
            print(f"  {section} {key}: assetId = {value},")

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as fh:
            fh.write("uploaded<<EOF\n")
            for section in ("MUSIC", "SFX"):
                for key, value in results[section].items():
                    fh.write(f"{section}.{key}={value}\n")
            fh.write("EOF\n")

    if failures:
        print(f"\nFAILED: {', '.join(failures)}")
        return 1
    return 0


#: Roblox caps audio uploads per creator per month: 100 if the account is
#: ID-verified, 10 if it is not. Philip confirmed ID-verified on 2026-09-17, so
#: the ceiling here is 100 and a re-render is affordable.
#:
#: Audio is still "not available for updating": a re-upload mints a NEW asset
#: and Config/Audio.luau has to be pointed at it. Bookkeeping, not budget.
#: create.roblox.com/docs/cloud/guides/usage-assets
UNVERIFIED_MONTHLY_AUDIO_LIMIT = 10
VERIFIED_MONTHLY_AUDIO_LIMIT = 100


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", help="a single file to upload")
    parser.add_argument("--all", metavar="DIR", help="upload every known audio file in DIR")
    parser.add_argument("--name", default="Nomling Audio")
    parser.add_argument("--description", default="Main theme for Fuse a Nomling.")
    parser.add_argument("--user-id", default=os.environ.get("ROBLOX_USER_ID", ""))
    parser.add_argument("--group-id", default=os.environ.get("ROBLOX_GROUP_ID", ""))
    args = parser.parse_args()

    if not args.file and not args.all:
        opencloud.die("Pass --file <path> or --all <directory>.")
    if args.file and not os.path.isfile(args.file):
        opencloud.die(f"no such file: {args.file}\n  Run tools/music/render.py first.")
    if not args.user_id and not args.group_id:
        opencloud.die(
            "Need --user-id (or --group-id).\n"
            "  This is the asset's owner. Your user ID is in your Roblox profile URL.\n"
            "  In CI it comes from the ROBLOX_USER_ID variable."
        )

    if args.all:
        return upload_all(args.all, args.user_id, args.group_id or None)

    operation = upload(args.file, args.name, args.description, args.user_id, args.group_id or None)
    print(f"Accepted: {json.dumps(operation)[:300]}")

    asset = wait_for_asset(operation)
    asset_id = asset.get("assetId") or asset.get("id")
    if not asset_id:
        print(f"\nUploaded, but no assetId in the response: {json.dumps(asset)[:400]}")
        return 1

    print(f"\n  Asset ID: {asset_id}")
    print(f"  Put this in src/shared/Config/Audio.luau as rbxassetid://{asset_id}")

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as fh:
            fh.write(f"asset_id={asset_id}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
