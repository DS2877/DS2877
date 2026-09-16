# CLOUD-SETUP.md — What to paste into the Claude Code cloud environment

Philip: this is task 5 in `docs/PHILIP-TODO.md`. Two fields to fill in, then you're done.

Settings live in the Claude Code web app under the environment for this repo.

---

## 1. Network access

Choose **Custom access**: the default list, plus these hosts.

```
apis.roblox.com
create.roblox.com
devforum.roblox.com
index.crates.io
static.crates.io
```

**What each is for:**

| Host | Why |
|---|---|
| `apis.roblox.com` | Open Cloud — publishing places, running cloud tests, messaging |
| `create.roblox.com` | Roblox documentation, so Claude can verify platform facts instead of guessing |
| `devforum.roblox.com` | Roblox announcements, same reason |
| `index.crates.io` | the toolchain package index |
| `static.crates.io` | the toolchain packages themselves |

**Good news:** the session that wrote this already reached all five, so the defaults may already cover them. Set the list anyway — it makes the requirement explicit rather than accidental.

**Not needed, deliberately:** `github.com` release downloads are blocked by policy and we designed around it (the toolchain builds from crates.io instead). Don't try to open that up.

---

## 2. Setup script

Paste this one line:

```bash
bash scripts/setup-cloud.sh
```

The script itself is in the repo, so it stays under version control and you never have to re-paste it when it changes.

**First run takes 7–10 minutes** — it compiles five Rust tools from source (measured at 440 s and 573 s on two different cold containers). Results are cached for roughly a week, so most sessions start instantly. If the environment cuts it short, the script installs in priority order (format, lint, tests, then build, then packages), so a truncated run still leaves the important tools in place.

---

## 3. Optional but recommended — the API credential

You're on Claude Pro, which unlocks this.

Add an environment **API credential**:

| Field | Value |
|---|---|
| Host | `apis.roblox.com` |
| Header name | `x-api-key` |
| Prefix | *(leave empty)* |
| Value | your Open Cloud API key |

**Why bother:** cloud sessions can then publish to TEST directly instead of waiting on a GitHub Actions round-trip, and **Claude never sees the key** — the proxy injects it. Faster loop, smaller blast radius.

GitHub Actions still needs the key as a repository secret regardless (that's task 4), because it's the only path to PROD.

---

## 4. GitHub repository settings

While you're in settings, CI needs these. It skips publishing cleanly until they exist, so nothing breaks in the meantime.

**Secret** (Settings → Secrets and variables → Actions → Secrets):

| Name | Value |
|---|---|
| `ROBLOX_API_KEY` | your Open Cloud API key |

**Variables** (same page, Variables tab) — these are IDs, not secrets:

| Name | Value |
|---|---|
| `ROBLOX_TEST_UNIVERSE_ID` | TEST universe ID |
| `ROBLOX_TEST_PLACE_ID` | TEST place ID |
| `ROBLOX_PROD_UNIVERSE_ID` | PROD universe ID |
| `ROBLOX_PROD_PLACE_ID` | PROD place ID |

**Environment** (Settings → Environments → New environment):

Create one named **`production`** and add yourself as a **required reviewer**.

⚠️ This is the gate that stops anything reaching PROD without you clicking approve. `tools/publish.py` refuses PROD without a flag that only the approved workflow supplies — but the environment gate is the real enforcement. Don't remove it to unblock a release.

---

## 5. API key scopes

When you create the key in Creator Hub, grant exactly these — verified against Roblox's docs on 2026-09-16:

| Scope | For |
|---|---|
| `universe.place:write` | publishing places |
| `universe.place.luau-execution-session:write` | running cloud tests |
| `universe.place.luau-execution-session:read` | reading their results |

Bind the key to **both** the TEST and PROD universes.

Later milestones will need more (configs read/write, messaging publish, game passes and developer products write). Claude will ask when they're actually needed rather than requesting everything up front — a key that can only do what's in use is a smaller problem if it ever leaks.

**Separate TEST and PROD keys** if the Creator Hub UI makes it convenient. Not worth fighting for if it doesn't.

---

## 6. How to check it worked

Open a new cloud session and ask Claude to run `./scripts/check.sh`. You should see format, lint, unit tests, parity, catalog and build all pass.
