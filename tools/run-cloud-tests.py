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

    task = run_with_retry(universe, place, script, args.version)
    if task is None:
        return 1
    return report(task)


def run_with_retry(universe: str, place: str, script: str, version: str | None):
    """Runs the task, retrying once if Luau Execution never started it.

    A task that times out having printed NOTHING never ran: smoke.luau's first
    statement is a print, so no output at all means the service accepted the
    task and never executed it. That happened three times in five runs on
    2026-09-17, either side of the same script passing 25/25 in six seconds.

    This is a retry, NOT a skip. A task that started and then hung, or ran and
    failed, is reported exactly as it came back and is never retried -- the
    difference is whether it produced output, which is the whole reason the
    timeout path fetches logs. A test is never retried into passing here; only
    a task that never became a test run is given a second chance.
    """
    for attempt in (1, 2):
        try:
            return opencloud.run_luau_task(universe, place, script, version_id=version)
        except opencloud.TaskTimeout as exc:
            lines: list[str] = []
            try:
                lines = opencloud.task_logs(exc.task_path)
            except opencloud.OpenCloudError as log_exc:
                print(f"  (could not fetch logs: {log_exc})", file=sys.stderr)

            if not lines and attempt == 1:
                print(
                    "\nThe task never started: no output at all within the timeout, "
                    "and the script's first line is a print.\n"
                    "That is a Luau Execution flake rather than a test failure, "
                    "so retrying once.",
                    file=sys.stderr,
                )
                continue

            print(f"\nTIMED OUT: {exc}", file=sys.stderr)
            print("Logs up to the point it stopped:", file=sys.stderr)
            if lines:
                for line in lines:
                    print(f"  | {line}", file=sys.stderr)
            else:
                print(
                    "  (nothing at all, on both attempts -- Luau Execution is not "
                    "running tasks for this place right now)",
                    file=sys.stderr,
                )
            return None
        except opencloud.OpenCloudError as exc:
            opencloud.die(str(exc))
    return None


def report(task: dict) -> int:
    """Prints a finished task's logs and turns its state into an exit code."""
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
