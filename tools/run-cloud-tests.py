"""Run the cloud integration suite via Open Cloud Luau Execution.

    python3 tools/run-cloud-tests.py --env test [--version 42]

ONE TASK, MANY ASSERTIONS -- deliberately. Task creation is limited to 5 per
minute per API key owner, so a task-per-test design would hit the limit
immediately (docs/TECH.md section 7). tests/cloud/smoke.luau is a single script
that asserts everything and prints a summary.
"""

from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import opencloud  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env", choices=["test", "prod"], default="test")
    parser.add_argument("--version", help="place version to run against; omit for latest")
    parser.add_argument("--script", default=os.path.join(ROOT, "tests", "cloud", "smoke.luau"))
    args = parser.parse_args()

    prefix = "TEST" if args.env == "test" else "PROD"
    universe = os.environ.get(f"ROBLOX_{prefix}_UNIVERSE_ID", "").strip()
    place = os.environ.get(f"ROBLOX_{prefix}_PLACE_ID", "").strip()
    if not universe or not place:
        opencloud.die(f"ROBLOX_{prefix}_UNIVERSE_ID and ROBLOX_{prefix}_PLACE_ID must be set")

    if not os.path.isfile(args.script):
        opencloud.die(f"no such script: {args.script}")

    with open(args.script, encoding="utf-8") as fh:
        script = fh.read()

    if len(script.encode()) > 4 * 1024 * 1024:
        opencloud.die("script exceeds the 4 MB Luau Execution limit")

    print(f"Running {os.path.relpath(args.script, ROOT)} on {args.env.upper()}")
    print(f"  universe: {universe}  place: {place}  version: {args.version or 'latest'}")

    try:
        task = opencloud.run_luau_task(universe, place, script, version_id=args.version)
    except opencloud.OpenCloudError as exc:
        opencloud.die(str(exc))

    state = task.get("state")
    print(f"\nTask finished: {state}")

    try:
        for line in opencloud.task_logs(task["path"]):
            print(f"  | {line}")
    except opencloud.OpenCloudError as exc:
        print(f"  (could not fetch logs: {exc})")

    if state != "COMPLETE":
        error = task.get("error", {})
        print(f"\nFAILED: {error.get('code', '?')} {error.get('message', '')}", file=sys.stderr)
        return 1

    output = task.get("output", {})
    results = output.get("results", [])
    if results and results[0] is not True:
        print(f"\nFAILED: smoke test returned {results[0]!r}", file=sys.stderr)
        return 1

    print("\nCloud tests passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
