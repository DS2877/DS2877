"""Publish a built .rbxl to a Roblox place via Open Cloud.

    python3 tools/publish.py --env test  --type Saved     --file build/nomling.rbxl
    python3 tools/publish.py --env test  --type Published --file build/nomling.rbxl
    python3 tools/publish.py --env prod  --type Published --file build/nomling.rbxl

'Saved' creates a version without making it live; CI uses it on every PR so the
last good build is always one call away for a rollback (docs/RUNBOOKS.md 1).
'Published' makes it live.

PROD publishing requires Philip's explicit approval (brief 11.3). The
deploy-prod workflow enforces that with a GitHub Environment approval gate;
this script refuses to publish PROD unless --i-have-approval is passed, so an
accidental local invocation cannot do it.
"""

from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import opencloud  # noqa: E402


def env_ids(env: str) -> tuple[str, str]:
    prefix = "TEST" if env == "test" else "PROD"
    universe = os.environ.get(f"ROBLOX_{prefix}_UNIVERSE_ID", "").strip()
    place = os.environ.get(f"ROBLOX_{prefix}_PLACE_ID", "").strip()
    if not universe or not place:
        opencloud.die(
            f"ROBLOX_{prefix}_UNIVERSE_ID and ROBLOX_{prefix}_PLACE_ID must be set.\n"
            "  These come from Creator Hub once the experiences exist "
            "(docs/PHILIP-TODO.md task 3)."
        )
    return universe, place


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env", choices=["test", "prod"], required=True)
    parser.add_argument("--type", choices=["Saved", "Published"], default="Saved")
    parser.add_argument("--file", required=True, help="path to the built .rbxl")
    parser.add_argument(
        "--i-have-approval",
        action="store_true",
        help="required for --env prod; confirms Philip approved this release",
    )
    args = parser.parse_args()

    if args.env == "prod" and not args.i_have_approval:
        opencloud.die(
            "Refusing to publish PROD without --i-have-approval.\n"
            "  Publishing to PROD needs Philip's explicit OK (brief 11.3).\n"
            "  The deploy-prod workflow supplies this after the approval gate."
        )

    if not os.path.isfile(args.file):
        opencloud.die(f"no such file: {args.file}\n  Run `rojo build` first.")

    universe, place = env_ids(args.env)
    size_kb = os.path.getsize(args.file) / 1024

    print(f"Publishing {args.file} ({size_kb:.0f} KB)")
    print(f"  environment : {args.env.upper()}")
    print(f"  universe    : {universe}")
    print(f"  place       : {place}")
    print(f"  versionType : {args.type}")

    try:
        result = opencloud.publish_place(universe, place, args.file, args.type)
    except opencloud.OpenCloudError as exc:
        opencloud.die(str(exc))

    version = result.get("versionNumber", result.get("VersionNumber", "?"))
    print(f"\nPublished as version {version}.")

    # CI writes this out so downstream steps can target the exact version.
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as fh:
            fh.write(f"version={version}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
