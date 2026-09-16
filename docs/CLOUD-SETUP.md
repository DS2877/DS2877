# CLOUD-SETUP.md — What to paste into the Claude Code cloud environment

Philip: this is task 5 in `docs/PHILIP-TODO.md`.

⚠️ **Sections 5–7 were corrected on 2026-09-16** after the first version didn't match the real Roblox UI. Everything below is now checked against Roblox's own documentation.

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

**Variables** (same page, Variables tab) — these are IDs, not secrets, so they are safe to record:

| Name | Value |
|---|---|
| `ROBLOX_TEST_UNIVERSE_ID` | `10766688851` |
| `ROBLOX_TEST_PLACE_ID` | `107785954354396` |
| `ROBLOX_PROD_UNIVERSE_ID` | *(not created yet — December)* |
| `ROBLOX_PROD_PLACE_ID` | *(not created yet — December)* |

**Environment** (Settings → Environments → New environment):

Create one named **`production`** and add yourself as a **required reviewer**.

⚠️ This is the gate that stops anything reaching PROD without you clicking approve. `tools/publish.py` refuses PROD without a flag that only the approved workflow supplies — but the environment gate is the real enforcement. Don't remove it to unblock a release.

---

## 4b. Before any of that: publish the place from Studio

⚠️ **Added 2026-09-16.** Philip was working in the Roblox Studio desktop app, where a new place exists **only on his computer** until it is published. That is why there were no IDs to look up — the experience did not exist on Roblox yet.

**In Studio, in this order:**

1. **Avatar tab** (or **File** menu) → **Avatar Settings** → the **⋯** button → **R15 Only**.
   Do this while Studio is open; it is free and takes seconds, and it is the setting that gates the higher DevEx rate.
2. **File** → **Publish to Roblox**.
3. In the **Publish Experience** window:
   - **Name**: `Fuse a Nomling TEST`
   - **Creator**: Philip's own account (Roblox recommends a group, but that costs 100 Robux and can wait for PROD)
   - **Devices**: leave the defaults, but confirm **Phone** is ticked
4. Click **Create**.

New games default to **Private**, which means the creator can already play them. No audience change is needed for Philip to test.

> ⚠️ **Do not build anything in Studio that you want to keep in this place.** From here on, CI publishes the Rojo-built place over the top of it on every deploy. Studio edits to the TEST place will be overwritten. Studio is for *looking* at what the pipeline produced, not for authoring content.

---

## 5. Creating the API key — the actual UI

⚠️ **Corrected 2026-09-16** after Philip found the earlier version didn't match reality. Re-verified against [Manage API keys](https://create.roblox.com/docs/en-us/cloud/auth/api-keys.md) and [Place publishing](https://create.roblox.com/docs/en-us/cloud/guides/usage-place-publishing.md).

You do **not** type scope strings anywhere. The UI asks you to pick an **API System**, then tick **operations** within it.

1. Creator Dashboard → **[Credentials](https://create.roblox.com/dashboard/credentials?activeTab=ApiKeysTab)** → **API Keys** tab → **Create API Key**.
2. Name it something like `NOMLING_PUBLISHING_KEY`.
3. Under **Access Permissions** → **Select API System**, add **`universe-places`**, then add the **Write** operation and select the experience.
   *(Roblox's own publishing guide says exactly this: "Add **universe-places** to Access Permissions. Add **Write** operation to your selected game.")*
4. **Optional, for the automated smoke test:** add the API system whose name contains **luau-execution**, with read and write operations. If you can't find it, skip it — publishing works without it and the smoke test is a nice-to-have.
5. Leave **Restrict IP addresses** unchecked (GitHub Actions has no fixed IP).
6. **Save & Generate key**, then copy the key. It's shown once.

Later milestones need more systems (configs, messaging, game passes, developer products). Claude will ask when they're actually needed — a key that can only do what's in use is a smaller problem if it leaks.

---

## 6. Finding the Universe ID and Place ID

Both appear in a single URL, which is the quickest route:

1. Creator Dashboard → **Creations** → click your experience's thumbnail.
2. Click the place's thumbnail.
3. Read the address bar:

```
https://create.roblox.com/dashboard/creations/experiences/1234567/places/7654321/configure
                                                          ^^^^^^^              ^^^^^^^
                                                          Universe ID          Place ID
```

Alternative for the Universe ID alone: on **Creations**, hover the experience thumbnail, click the **⋯** button, and choose **Copy Universe ID**.

---

## 7. Two things that are NOT needed yet

**The Community (group) — costs 100 Robux, and it's optional for now.**
Roblox charges 100 Robux to create a group, and it's made from Creator Dashboard → the **account switcher in the upper-left** → the **plus (+)** button — not from a "Communities" menu, which is what an earlier version of this document wrongly said. A personal-owned TEST experience works perfectly. Claude never spends money without asking (brief §11.3), so this is Philip's call, and it can wait until the PROD experience is created in December.

⚠️ *Claude could not find documentation confirming that an experience can be transferred from a personal account to a group afterwards.* So if group ownership matters for the real game, create **PROD** inside the group when the time comes, rather than assuming TEST can be moved.

**Avatar Settings / R15 Only — needs Studio, and is not urgent.**
Roblox's docs place Avatar Settings inside **Studio** (File menu or the Avatar tab), and state the values are "not visible outside of the settings interface or accessible with scripts" — so Rojo cannot set it and neither can a script. It does not appear on the Creator Dashboard's configure page.

⚠️ An earlier version of this document said "do this now, it can't be fixed later." **That was wrong.** The R15 requirement is about the higher DevEx rate, which only applies to Robux earned from *real players*. Nothing is earning anything until launch. So this moves to the **M4/M5 checklist**, to be done in the Studio session Philip already planned — well before December.

---

## 8. How to check it worked

Open a new cloud session and ask Claude to run `./scripts/check.sh`. You should see format, lint, unit tests, parity, catalog and build all pass.
