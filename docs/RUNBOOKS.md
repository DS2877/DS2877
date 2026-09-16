# RUNBOOKS.md

Phase 1.1. What to do when something goes wrong, written to be followed **on a phone, under stress, by one person.**

Every runbook: symptom → immediate action → diagnosis → fix → follow-up. Rehearse them in TEST before M5 (`docs/ROADMAP.md`).

---

## 0. The first thirty seconds of any incident

1. **Is player data at risk?** If yes, jump to §3 and stop the bleeding first.
2. **Is money involved?** If yes, §4. Never leave a player charged without their item.
3. Otherwise: is it getting worse, or is it stable? Stable buys time to diagnose.
4. Write down the time and what you saw. Memory is unreliable ten minutes later.

**Claude may never, without Philip's explicit OK:** publish PROD, publish live config, apply catalog changes, or spend money. In an incident these limits still hold — Claude prepares the fix and says exactly what it will do; Philip approves.

---

## 1. Bad release on PROD

**Symptom:** errors spike, players report breakage, or a core loop is broken after a deploy.

**Immediate:**
1. If it is config-driven, **roll back the config** (§2) — seconds, not minutes.
2. If it is code, re-publish the previous place version through Open Cloud. Every CI publish is a *Saved* version, so the last good one is one call away.
3. Post a server banner via `events.bannerText`: *"We're fixing a problem — back shortly!"* Short, honest, no promises about timing.

**Diagnose:** Creator Hub → Analytics → Errors. Compare with the diff in the release.

**Fix:** forward-fix on a branch, ship via `deploy-prod.yml` with Philip's approval. **Do not hotfix straight to PROD** — the approval gate exists precisely for the moments when skipping it feels justified.

**Follow-up:** `CHANGELOG.md` entry; add a regression test; if CI could have caught it, add that check.

---

## 2. Config rollback

**Symptom:** a live config change made things worse.

**Immediate:** re-publish the previous config JSON. `config/live.defaults.json` is version-controlled, so the previous values are in git history.

**If config is unreachable or corrupt:** the game runs on code defaults by design (`docs/CONFIG.md`). A failed config load is not an outage.

**Prevention:** one 🔴 key at a time; TEST first; every 🔴 change logged with before/after.

---

## 3. Data loss or corruption

**The worst case.** ProfileStore session locking exists to prevent it, but assume it can still happen.

**Immediate:**
1. **Stop the spread.** If a code path is corrupting profiles, roll back (§1) before anything else. Every minute of uptime is more damaged profiles.
2. Do **not** attempt bulk repair while the bad code is live.

**Diagnose:** identify the affected key pattern and the time window. Was it a migration, a bad write, or a lock failure?

**Fix:**
- **Migration bug:** fix the migration, bump `schemaVersion`, and write a repair pass that detects the bad shape and corrects it. Test it against a TEST copy first — **always dry-run migrations** (`docs/TECH.md` §7).
- **Individual profiles:** restore from the last good autosave if available. Roblox DataStores keep limited versioning — check `DataStoreService` versioning before assuming data is gone.
- **If data is unrecoverable:** say so plainly to the affected players and compensate generously. A silent loss costs more trust than an admitted one.

**Follow-up:** a regression test reproducing the exact corruption.

---

## 4. Purchase not granted

**Symptom:** a player paid and did not receive their item.

**Why it should not happen:** `ProcessReceipt` grants → persists → *then* returns `PurchaseGranted`, and returns `NotProcessedYet` if the profile is not loaded. Roblox retries `NotProcessedYet`, so an unfinished purchase should self-heal on their next join.

**Immediate:** ask the player to rejoin. That resolves most cases.

**If it persists:**
1. Check the purchase ledger in their profile for the receipt ID.
2. If the receipt is absent but Roblox shows the transaction, grant manually via the admin panel and record it.
3. If the receipt is present but the item is missing, the grant logic is broken — that is a code bug and a §1 incident.

**Never** grant without checking the ledger; double-granting is its own incident.

**Follow-up:** any manual grant means the idempotency path has a hole. Find it.

---

## 5. Right to Erasure

**Trigger:** Roblox forwards a data deletion request for a `UserId`.

This is a legal obligation with a deadline. It must work before launch, and it must be tested in TEST first.

**Steps:**
1. Record the request: date, `UserId`, deadline.
2. Run `tools/erase-user --userid <id> --env prod --dry-run`. Review what it reports.
3. Run without `--dry-run`. It must delete from **every** store:
   - the main profile DataStore
   - all four OrderedDataStore leaderboards
   - the code-redemption store
   - **World First records** — see below
4. Verify by re-running the dry run; it should find nothing.
5. Record completion.

⚠️ **World First needs a decision before launch.** A World First entry stores a discoverer's name and is displayed permanently to everyone. On erasure we **anonymize rather than delete** — keep the combo record, replace the discoverer with "A Nomling Scientist". Deleting the record entirely would let someone else re-claim a first that already happened, corrupting the Fusion Book for everyone.
→ Therefore **store the `UserId` and resolve the display name at read time**, never store the name. Then erasure is a single field write. This must be in the M2a schema (`docs/TECH.md`), not retrofitted.

**No personal data is stored anywhere else** — only gameplay data keyed by `UserId` (`docs/COMPLIANCE.md` §6).

---

## 6. Exploit or duplication

**Symptom:** impossible coin totals, duplicated Nomlings, leaderboard anomalies.

**Immediate:**
1. Identify the exploited path. If it is a remote, **rate-limit it to zero in live config** if possible — faster than a deploy.
2. If coins or items are being minted, that is an economy emergency: roll back the code path (§1).

**Diagnose:** `coins_source` events with impossible amounts; `snatch_attempted` patterns; leaderboard outliers.

**Fix:** close the hole server-side. Every remote validates type, range, ownership and proximity — find which check was missing and add it to the `Net` module's contract.

**On players:** **prefer soft measures to bans.** Our players are children. Roll back the affected profiles, rate-limit, and log. Escalate only on sustained deliberate abuse. A nine-year-old who found a bug is not an attacker.

**Follow-up:** unit test for the specific invariant. `security-reviewer` pass over neighbouring remotes.

---

## 7. Reduced exposure banner on Creator Dashboard

**Symptom:** a banner says the game's visibility is reduced.

Not an outage — a quality classification, and recoverable. Roblox reclassifies with every update.

**Diagnose** against the three published causes (`docs/MARKETING.md` §6): leading with giveaways, mismatched metadata and content, or non-unique metadata.

**Fix:** correct the metadata, ship an update, and wait for reclassification. The banner updates daily.

**Prevention:** the store-page checklist (`docs/STORE-PAGE.md` §7).

---

## 8. Moderation action on content maturity

**Symptom:** a moderation notification about the maturity label.

**Immediate:** read the moderator feedback on the Questionnaire page in Creator Hub.

**Fix:** either change the content to match our answers, or retake the questionnaire to match the content. **Whichever is true.** Repeated inaccuracy risks the experience and the account.

**Most likely cause, given our design:** gambling imagery creeping into the Egg Market or Fusion Lab during an art pass (`docs/COMPLIANCE.md` §1). Check that first.

**Appeal**, if genuinely wrong: roblox.com/report-appeals.

---

## 9. Open Cloud / CI failure

**Symptom:** CI cannot publish or run Luau Execution tests.

**Check in order:**
1. **Rate limits.** Task creation is **5/minute per API key owner**. Parallel CI runs will hit this. Concurrency groups should prevent it — verify they are working.
2. **API key permissions and expiry.** Keys expire; the error is a 401 or 403. The
   key needs the **`universe-places`** API system with the **Write** operation, added
   for this specific experience. `tools/opencloud.py` prints the list on any 401/403.
3. **Roblox status.** Not everything is our fault.

**Workaround:** publishing to TEST can be done manually from Philip's Creator Hub if CI is blocked and a playtest is urgent.

### 9a. HTTP 409 "Server is busy and unable to process your upload request"

Hit three times on 2026-09-16 over 2½ hours. The message says "busy", but a 409 that
survives hours is not load — it is the place.

**What has already been ruled out, so do not re-check it:**

| Suspect | Verdict | How it was checked |
|---|---|---|
| Wrong universe/place pair | ✅ correct | `GET https://apis.roblox.com/universes/v1/places/<placeId>/universe` returns `{"universeId":10766688851}`. Public, no key needed. `tools/publish.py` now runs this before every upload. |
| Bad or unscoped API key | ✅ fine | A deliberately invalid key returns **401 `Invalid API Key`** immediately. The real failures got past auth to a 409, so the key is valid and authorized for the place. |
| Malformed place file | ✅ valid | `rojo build` output carries the `<roblox!` binary magic and the `</roblox>` terminator; 24 KB. |
| Wrong `Content-Type` | ✅ correct | Docs require `application/octet-stream` for `.rbxl`; that is what we send. |

**So the remaining causes are all place-state, in this order:**
1. **Studio still has the place open.** Close Roblox Studio completely, then re-run the deploy.
2. **Collaborative editing (Team Create) is enabled** on the place.
3. **Roblox-side.** Decide this with one test: `File → Publish to Roblox` **from Studio**.
   If Studio publishes fine while Open Cloud 409s, it is not a platform outage.

`tools/opencloud.py` retries a 409 four times over ~135 s, so a genuine busy signal
never reaches the log. Anything that survives that is this list.

---

## 10. Escalation

Philip is a solo developer in Sweden with a day job. There is no on-call rotation, and that is fine — this is a game, not a hospital.

| Severity | Response |
|---|---|
| **Data loss or money** | Same day. Roll back first, diagnose second. |
| **Core loop broken** | Same day if noticed; a banner buys time. |
| **Degraded (one feature)** | Next working session. Banner if visible. |
| **Cosmetic** | Next weekly update. |

**Roll back first, diagnose second.** A rolled-back game loses a feature; a broken one loses players.
