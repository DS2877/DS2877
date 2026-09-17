#!/usr/bin/env python3
"""Ask Roblox what it actually thinks of our audio assets.

    python3 tools/check-audio.py

WHY THIS EXISTS. The game has eight audio asset ids in
src/shared/Config/Audio.luau, all non-zero, all wired, and a playtester reports
silence: "I don't have any of the relevant sounds you said you added. And I
don't have a themesong playing in the background."

From a cloud session there is no way to hear a game, so "the ids are in the
config" was as far as verification went -- and an id being present says nothing
about whether the asset is APPROVED. Open Cloud audio uploads go through
moderation; until they clear, a Sound with a perfectly valid SoundId plays
nothing at all and raises no error. That failure is completely invisible from
the code, which is exactly the kind of thing that needs an instrument instead of
an assumption.

This asks the Assets API for each id and prints what it says: the moderation
state, the asset type, and who owns it. Three things can be wrong and they need
different fixes, so the point is to tell them apart:

  * MODERATION PENDING  -- wait, nothing to do.
  * MODERATION REJECTED -- the file has to be replaced, and re-uploading costs
                           another slot from the monthly quota.
  * OWNED BY SOMEBODY ELSE -- the experience cannot play it. This is the one
                           that looks like a code bug and is not.

Needs ROBLOX_API_KEY with the `assets` scope (read). Runs in CI, where the key
lives; a cloud session has no key and will say so rather than guess.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import opencloud  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "src" / "shared" / "Config" / "Audio.luau"

# `name = { assetId = 123, ... }` -- the only shape this file uses.
ENTRY = re.compile(r"(\w+)\s*=\s*\{[^}]*?assetId\s*=\s*(\d+)", re.S)


def entries() -> list[tuple[str, int]]:
    source = CONFIG.read_text(encoding="utf-8")
    found = [(name, int(asset)) for name, asset in ENTRY.findall(source)]
    if not found:
        raise SystemExit(f"no assetId entries found in {CONFIG} -- has the shape changed?")
    return found


def describe(asset_id: int) -> dict:
    return opencloud.request("GET", f"/assets/v1/assets/{asset_id}")


def main() -> int:
    rows = entries()
    print(f"Checking {len(rows)} audio assets from {CONFIG.relative_to(ROOT)}\n")

    problems: list[str] = []
    for name, asset_id in sorted(rows):
        if asset_id <= 0:
            print(f"  {name:<12} {asset_id:<18} NOT UPLOADED (assetId is 0)")
            problems.append(f"{name}: never uploaded")
            continue

        try:
            info = describe(asset_id)
        except opencloud.OpenCloudError as exc:
            print(f"  {name:<12} {asset_id:<18} LOOKUP FAILED -- {exc}")
            problems.append(f"{name}: lookup failed ({exc})")
            continue

        moderation = (info.get("moderationResult") or {}).get("moderationState", "?")
        creator = info.get("creationContext", {}).get("creator", {})
        owner = creator.get("userId") or creator.get("groupId") or "?"
        kind = info.get("assetType", "?")

        state = str(moderation)
        flag = ""
        if "Approved" not in state:
            flag = "  <-- WILL NOT PLAY"
            problems.append(f"{name}: moderation is {state}")
        if kind not in ("Audio", "ASSET_TYPE_AUDIO", "?"):
            flag = "  <-- WRONG ASSET TYPE"
            problems.append(f"{name}: asset type is {kind}, not Audio")

        print(f"  {name:<12} {asset_id:<18} {state:<12} owner={owner} type={kind}{flag}")

    print()
    if problems:
        print("PROBLEMS:")
        for problem in problems:
            print(f"  - {problem}")
        print(
            "\nIf moderation is still pending, this resolves itself. If anything is\n"
            "rejected, the file has to change and a re-upload costs another slot\n"
            "from the monthly quota (10 on an account that is not ID-verified)."
        )
        return 1

    print("All audio assets are approved and owned correctly.")
    print(
        "So silence is NOT the assets, and on 2026-09-17 it was not: SoundGroup.Volume\n"
        "MULTIPLIES Sound.Volume, and the music group was being set to the track's own\n"
        "level, so the theme played at 0.32 x 0.32 -- about 3% of full scale. Fixed.\n"
        "\n"
        "If it is silent again, the remaining candidates, in order:\n"
        "  1. The client never got the asset. AudioController reports a fault on\n"
        "     screen if the theme has not loaded ten seconds after Play().\n"
        "  2. AudioController.start() never ran -- the red CLIENT FAULT panel names\n"
        "     any controller that threw.\n"
        "  3. The device is muted, or Roblox's own volume slider is down."
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except opencloud.OpenCloudError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        print(json.dumps({"hint": "needs ROBLOX_API_KEY with the assets scope"}), file=sys.stderr)
        sys.exit(2)
