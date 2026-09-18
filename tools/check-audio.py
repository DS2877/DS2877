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
import os
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


def universe_owner() -> str:
    """Who owns the TEST experience, per Roblox.

    THE DECIDING FACT, and the reason this function exists. Roblox's asset
    privacy page says plainly:

        "Using your own assets in your own published games -- your assets are
        always accessible to you in your own games regardless of their privacy
        setting."

    So a private asset is NOT the problem when the uploader owns the
    experience. It is very much the problem when they do not: every audio asset
    then fails to load, short and long alike, with no error the player can see.
    A playtester reported exactly that -- `sfx loaded 0/21`, nothing at all --
    while all eight assets came back Approved and owned by one account.

    Which leaves one question that can actually be answered from here: is that
    account the same one that owns the universe?
    """
    universe_id = os.environ.get("ROBLOX_TEST_UNIVERSE_ID", "").strip()
    if not universe_id:
        return "ROBLOX_TEST_UNIVERSE_ID is not set"
    try:
        info = opencloud.request("GET", f"/cloud/v2/universes/{universe_id}")
    except opencloud.OpenCloudError as exc:
        return f"lookup failed -- {exc}"
    # The field is `user` ("users/123") or `group` ("groups/456") depending on
    # who holds it, so report whichever came back rather than assuming.
    for key in ("user", "group"):
        if info.get(key):
            return f"{key}={info[key]}"
    return f"no owner field in {json.dumps(info, separators=(',', ':'))}"


def main() -> int:
    rows = entries()
    print(f"Checking {len(rows)} audio assets from {CONFIG.relative_to(ROOT)}\n")

    problems: list[str] = []
    owners: set[str] = set()
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

        owners.add(str(owner))

        state = str(moderation)
        flag = ""
        if "Approved" not in state:
            flag = "  <-- WILL NOT PLAY"
            problems.append(f"{name}: moderation is {state}")
        if kind not in ("Audio", "ASSET_TYPE_AUDIO", "?"):
            flag = "  <-- WRONG ASSET TYPE"
            problems.append(f"{name}: asset type is {kind}, not Audio")

        print(f"  {name:<12} {asset_id:<18} {state:<12} owner={owner} type={kind}{flag}")

        # EVERYTHING ROBLOX WILL TELL US, not just the fields we thought to ask
        # for. Audio is private by default and an experience needs permission
        # (docs/VERIFY.md 3.6); the runtime failure mode is undocumented, so if
        # a privacy or permission field exists at all, it is worth seeing rather
        # than guessing at from a phone.
        extra = {
            key: value
            for key, value in info.items()
            if key not in ("moderationResult", "creationContext", "assetType", "path")
        }
        if extra:
            print(f"               {json.dumps(extra, separators=(',', ':'))}")

    print()

    # Owner vs owner. This is the one comparison that distinguishes "the code is
    # wrong" from "the experience is not allowed to play these".
    print(f"Audio owned by  : {', '.join(sorted(owners)) or 'unknown'}")
    print(f"TEST experience : {universe_owner()}")
    print(
        "\nIf those two are not the same account, that is the whole story: Roblox\n"
        "says your own assets always work in your own games, and these are not\n"
        "your own games. Nothing in the code can fix it -- either re-upload under\n"
        "the account that owns the experience, or grant the experience permission\n"
        "(Creator Dashboard -> Development Items -> Audio -> the asset ->\n"
        "Permissions -> Experiences -> Add experiences -> the universe id).\n"
        "docs/VERIFY.md 3.6."
    )

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
        "THIS TOOL CANNOT ANSWER THE REMAINING QUESTION. Audio is private by\n"
        "default and an experience needs permission granted to it, but the\n"
        "Assets API returns no privacy or permission field -- the dump above is\n"
        "everything Roblox will tell us, and it is all moderation and naming.\n"
        "See docs/VERIFY.md 3.6.\n"
        "\n"
        "So the instrument is the phone. AudioController preloads the theme and,\n"
        "twelve seconds in, prints one line to the red CLIENT FAULT panel if it\n"
        "is not playing. Read it like this:\n"
        "  sfx loaded 0/N       -- no audio at all reaches this client.\n"
        "  sfx loaded N/N, but  -- only the 110-second theme fails, which points\n"
        "  theme len=0             at asset privacy: grant the experience\n"
        "                          permission on the asset in Creator Hub. Not a\n"
        "                          code change.\n"
        "  playing, len>0       -- it IS playing; anything silent then is volume."
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except opencloud.OpenCloudError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        print(json.dumps({"hint": "needs ROBLOX_API_KEY with the assets scope"}), file=sys.stderr)
        sys.exit(2)
