"""Shared Open Cloud client.

Endpoints and scope names verified against Roblox documentation on 2026-09-16:
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

# Scopes this tooling needs, for the key Philip creates in Creator Hub.
REQUIRED_SCOPES = [
    "universe.place:write",                        # publish places
    "universe.place.luau-execution-session:write",  # run cloud tests
    "universe.place.luau-execution-session:read",
]


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
) -> dict:
    url = path if path.startswith("http") else f"{BASE}{path}"
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", api_key())
    if body is not None:
        req.add_header("Content-Type", content_type)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:500]
        hint = ""
        if exc.code in (401, 403):
            hint = (
                "\n  401/403 usually means the key lacks a scope or is not bound to "
                f"this universe.\n  Needed: {', '.join(REQUIRED_SCOPES)}"
            )
        elif exc.code == 429:
            hint = (
                "\n  429 is a rate limit. Luau Execution allows only 5 task creations "
                "per minute per API key owner -- run one task with many assertions, "
                "not one task per test."
            )
        raise OpenCloudError(f"{method} {url} -> HTTP {exc.code}\n  {detail}{hint}") from None
    except urllib.error.URLError as exc:
        raise OpenCloudError(f"{method} {url} -> network error: {exc.reason}") from None

    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"raw": raw.decode("utf-8", "replace")}


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

    raise OpenCloudError(f"task did not finish within {timeout_seconds}s: {task_path}")


def task_logs(task_path: str) -> list[str]:
    result = request("GET", f"/cloud/v2/{task_path}/logs")
    lines: list[str] = []
    for chunk in result.get("luauExecutionSessionTaskLogs", []):
        lines.extend(chunk.get("messages", []))
    return lines


def die(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)
