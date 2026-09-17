"""Shared Open Cloud client.

Endpoints and permission names verified against Roblox documentation on 2026-09-16:
  https://create.roblox.com/docs/en-us/cloud/guides/usage-place-publishing.md
  https://create.roblox.com/docs/cloud/reference/features/luau-execution.md

SECRETS: the API key is read from the ROBLOX_API_KEY environment variable and
is never logged, printed or written to disk. If you are reading this while
adding a debug print, do not print `key`.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = "https://apis.roblox.com"

# Status codes worth retrying. Roblox returns 409 with "Server is busy and
# unable to process your upload request. Please try again in a couple minutes."
# -- transient, and its own message tells you to retry. A deploy failing on that
# is noise, not signal.
RETRYABLE_STATUS = {409, 429, 500, 502, 503, 504}

# Roblox says "a couple minutes", so the backoff climbs into that range rather
# than giving up after a few seconds.
RETRY_DELAYS = (5, 15, 40, 75)

# Permissions this tooling needs on the key Philip creates in Creator Hub.
#
# You do NOT type scope strings anywhere -- Creator Hub asks you to pick an
# "API System" and then tick its operations, so these are written the way they
# actually appear in that UI. Verified against
# https://create.roblox.com/docs/en-us/cloud/guides/usage-place-publishing
# on 2026-09-16, which says: "Add universe-places to Access Permissions" and
# "Add Write operation to your selected game."
REQUIRED_PERMISSIONS = [
    ("universe-places", "Write", "publish a place -- required"),
    ("universe.place.luau-execution-session", "Read and Write", "cloud tests -- M1"),
]


def _permission_help() -> str:
    return "\n".join(
        f"    {system} -> {operation}  ({why})"
        for system, operation, why in REQUIRED_PERMISSIONS
    )


class OpenCloudError(RuntimeError):
    pass


def api_key() -> str:
    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if not key:
        raise OpenCloudError(
            "ROBLOX_API_KEY is not set.\n"
            "  In GitHub Actions it comes from the repository secret.\n"
            "  In a cloud session it comes from the environment API credential.\n"
            "  Never paste a key into a command line or a file."
        )
    return key


def request(
    method: str,
    path: str,
    *,
    body: bytes | None = None,
    content_type: str = "application/json",
    timeout: int = 120,
    retries: int = len(RETRY_DELAYS),
) -> dict:
    """Call Open Cloud, retrying transient failures with backoff."""
    url = path if path.startswith("http") else f"{BASE}{path}"
    attempt = 0

    while True:
        req = urllib.request.Request(url, data=body, method=method)
        req.add_header("x-api-key", api_key())
        if body is not None:
            req.add_header("Content-Type", content_type)

        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                raw = response.read()
            break
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")[:500]

            if exc.code in RETRYABLE_STATUS and attempt < retries:
                delay = RETRY_DELAYS[attempt]
                attempt += 1
                print(
                    f"  HTTP {exc.code} (transient) -- retry {attempt}/{retries} in {delay}s",
                    flush=True,
                )
                time.sleep(delay)
                continue

            hint = ""
            if exc.code in (401, 403):
                hint = (
                    "\n  401/403 usually means the key lacks a permission, or is bound to "
                    "a different experience.\n  In Creator Hub -> Credentials -> API Keys, "
                    f"the key needs:\n{_permission_help()}"
                )
            elif exc.code == 409:
                hint = (
                    f"\n  409 after {retries} retries over ~{sum(RETRY_DELAYS)}s. Roblox's "
                    "message says 'server is busy', but a 409 that persists across hours is "
                    "usually the place, not the platform. Checked in that order:\n"
                    "    1. Is Roblox Studio open on that place? Close it fully and retry.\n"
                    "    2. Is collaborative editing (Team Create) on for the place?\n"
                    "    3. Does File -> Publish to Roblox from Studio also fail? If it does,\n"
                    "       this is not an Open Cloud problem -- check status.roblox.com.\n"
                    "  A mismatched universe/place pair does NOT produce this error; you can\n"
                    "  confirm the pair with the public endpoint\n"
                    "    GET https://apis.roblox.com/universes/v1/places/<placeId>/universe"
                )
            elif exc.code == 429:
                hint = (
                    "\n  429 is a rate limit. Luau Execution allows only 5 task creations "
                    "per minute per API key owner -- run one task with many assertions, "
                    "not one task per test."
                )
            raise OpenCloudError(f"{method} {url} -> HTTP {exc.code}\n  {detail}{hint}") from None
        except urllib.error.URLError as exc:
            if attempt < retries:
                delay = RETRY_DELAYS[attempt]
                attempt += 1
                print(f"  network error -- retry {attempt}/{retries} in {delay}s", flush=True)
                time.sleep(delay)
                continue
            raise OpenCloudError(f"{method} {url} -> network error: {exc.reason}") from None

    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"raw": raw.decode("utf-8", "replace")}


def check_place_pair(universe_id: str, place_id: str) -> str | None:
    """Confirm a place really belongs to a universe. Needs no API key.

    The GitHub variables holding these IDs are typed by hand, and a mismatched
    pair fails several minutes into a deploy with an error that does not say so.
    This asks the public mapping endpoint first, which takes about a second.

    Returns an error string if the pair is definitely wrong, otherwise None --
    including when the check itself could not run, because an unreachable
    lookup service is no reason to block a publish.
    """
    url = f"{BASE}/universes/v1/places/{place_id}/universe"
    try:
        with urllib.request.urlopen(url, timeout=20) as response:
            payload = json.loads(response.read())
    except Exception:
        return None

    # A place that does not exist answers 200 with a null universeId, so the
    # null case is a real finding rather than a failed lookup.
    actual = payload.get("universeId")
    ids_hint = (
        "  Check ROBLOX_TEST_UNIVERSE_ID and ROBLOX_TEST_PLACE_ID -- both IDs\n"
        "  appear in the Creator Hub URL for the experience."
    )

    if actual is None:
        return f"no place with ID {place_id} exists.\n{ids_hint}"
    if str(actual) != str(universe_id):
        return (
            f"place {place_id} belongs to universe {actual}, not {universe_id}.\n"
            f"{ids_hint}"
        )
    return None


def publish_place(universe_id: str, place_id: str, rbxl_path: str, version_type: str) -> dict:
    """Publish a .rbxl. version_type is 'Saved' (CI) or 'Published' (live)."""
    if version_type not in ("Saved", "Published"):
        raise OpenCloudError("version_type must be 'Saved' or 'Published'")

    with open(rbxl_path, "rb") as fh:
        payload = fh.read()

    path = (
        f"/universes/v1/{universe_id}/places/{place_id}/versions"
        f"?versionType={version_type}"
    )
    return request("POST", path, body=payload, content_type="application/octet-stream")


def run_luau_task(universe_id: str, place_id: str, script: str, *, version_id: str | None = None,
                  timeout_seconds: int = 300, poll_seconds: float = 5.0) -> dict:
    """Run a Luau script headlessly and wait for it. Returns the finished task.

    Tasks run for at most 5 minutes with 10 concurrent per place; creating one
    is limited to 5 per minute per API key owner.
    """
    if version_id:
        create_path = (
            f"/cloud/v2/universes/{universe_id}/places/{place_id}"
            f"/versions/{version_id}/luau-execution-session-tasks"
        )
    else:
        create_path = (
            f"/cloud/v2/universes/{universe_id}/places/{place_id}"
            "/luau-execution-session-tasks"
        )

    task = request("POST", create_path, body=json.dumps({"script": script}).encode())
    task_path = task.get("path")
    if not task_path:
        raise OpenCloudError(f"task creation returned no path: {task}")

    deadline = time.time() + timeout_seconds + 60
    while time.time() < deadline:
        state = task.get("state")
        if state in ("COMPLETE", "FAILED", "CANCELLED"):
            return task
        time.sleep(poll_seconds)
        task = request("GET", f"/cloud/v2/{task_path}")

    # Carries the path so the caller can still fetch whatever the task printed
    # before it stopped. Without this a hang is a black box: the run that found
    # this printed the timeout and not one line of the script's own output, so
    # there was nothing to debug from.
    raise TaskTimeout(f"task did not finish within {timeout_seconds}s: {task_path}", task_path)


class TaskTimeout(OpenCloudError):
    """A Luau task that never reached a terminal state.

    Separate from a plain OpenCloudError because the caller can do something
    useful with it: the task is still there, and its logs usually say exactly
    where the script stopped.
    """

    def __init__(self, message: str, task_path: str) -> None:
        super().__init__(message)
        self.task_path = task_path


def task_logs(task_path: str) -> list[str]:
    result = request("GET", f"/cloud/v2/{task_path}/logs")
    lines: list[str] = []
    for chunk in result.get("luauExecutionSessionTaskLogs", []):
        lines.extend(chunk.get("messages", []))
    return lines


def die(message: str) -> None:
    # Flush stdout first, or the error lands above the context that explains it
    # -- which is exactly how the first real failure read in the CI log.
    sys.stdout.flush()
    print(f"ERROR: {message}", file=sys.stderr, flush=True)
    sys.exit(1)
