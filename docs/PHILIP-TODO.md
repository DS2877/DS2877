# PHILIP-TODO

Things only Philip can do. Claude keeps this current (brief §12, §11.11).
Last updated: 2026-09-16 (Phase 0 answers recorded).

**Status key:** ⬜ not started · 🟡 in progress · ✅ done · ⏸️ not needed yet

---

## 🔥 Time-critical — the clock is running

### 🟡 1. Start Roblox Plus (or confirm an existing Premium subscription)

**Why now:** publishing to under-16 audiences requires an active Plus or Premium subscription **for 2 consecutive months** at the moment you publish for all ages. Starting today (2026-09-16) clears that bar around **2026-11-16**, comfortably before the M6 all-ages target of 2026-12-12. Every week of delay eats that buffer.

**Verified nuance (this is better than the brief assumed):** the subscription is only checked **when you publish or update for all ages**. If it lapses afterwards, the game stays published. So this is a ~2-month commitment, not forever.

**Alternative:** a one-time refundable per-game publishing fee instead of the subscription. It is auto-refunded 90 days after the game becomes Kids/Select eligible — or 90 days after payment if it never gets there. Not refunded if the game is permanently removed for Community Standards violations.

→ **Answered 2026-09-16: Philip is subscribing to Roblox Plus now.** Two-month bar clears ~2026-11-16. *Tell Claude the day it actually starts so the M6 date can be pinned.*

---

## Before building

### ⬜ 2. Account security
- Complete the **age check** (facial age estimation, or government ID since you're 18+).
- Turn on **2-Step Verification**.

**Correction from Phase 0:** you need the full ID + 2FA stack only to reach **under-16** players. To launch to **16+** you need just an account in good standing that is **at least 2 days old**, age verification, and a completed Maturity & Compliance Questionnaire. So this is not a blocker for M5 — but do it now anyway, since M6 needs it and ID verification can take time.

### ⬜ 3. Create the Community (group) and the two experiences
- Create a Roblox Community (group) to own the game.
- Inside it, create the **PROD** and **TEST** experiences.
- Set **TEST** to Audience → **Limited** → **Playtesters**.

⚠️ **Do this at creation time, in Avatar Settings on both places: set R15 Only.**
Verified: the higher DevEx rate (0.0054 vs 0.0038 per Robux) requires player characters on an R15 rig for **100% of active playtime**. If a player can spawn as or swap to R6 at any point, the game is permanently ineligible. It costs nothing now and cannot be recovered later.

### ⬜ 4. Open Cloud API keys
Create keys with minimal scopes and store as the GitHub Actions secret `ROBLOX_API_KEY`.
*Claude will give you the exact scope list in Phase 2 — wait for it rather than guessing.*

🆕 **You're on Claude Pro, so you also get the better option:** add an environment **API credential** for `apis.roblox.com` (header name `x-api-key`, no prefix) in the cloud environment settings. Cloud sessions can then call Open Cloud directly — Claude never sees the key, and publishing to TEST stops depending on a GitHub Actions round-trip. Claude will give you this text in Phase 2 too.

### ⬜ 5. Cloud environment setup
Set the network allowlist and setup script for the Claude Code cloud environment.
*Claude will hand you the exact text to paste in Phase 2.*

**Phase 0 finding:** this session already reaches `create.roblox.com`, `devforum.roblox.com`, `apis.roblox.com`, `api.github.com` and the crates.io endpoints. GitHub **release-binary** downloads are blocked, so the toolchain will be installed via `cargo install` instead — no allowlist change needed for that.

### ⬜ 6. Trademark check on the title
Before we commit to "Fuse a Nomling". *Claude produces a 5-title shortlist with risk notes in Phase 1 — this task starts then.*

---

## Before launch

### ⏸️ 7. Maturity & Compliance Questionnaire
Complete it using the draft answers Claude writes in Phase 1. Target label: **Minimal** (Mild at most).

Two things to watch when you fill it in:
- Answer **yes** to "contains paid random items" and **yes** to "respects the `ArePaidRandomItemsRestricted` policy API" — both will be true.
- Tell Claude what maturity label the questionnaire actually returns. We believe the paid-random-items descriptor does not raise the label above Minimal, but that is inferred from the docs, not stated — your result is the real answer.

### ⏸️ 8. Audience Expansion Rewards eligibility
Check it in Creator Hub and set up what it asks for (ID verification, DevEx account).

**Correction from Phase 0:** this pays 35% of a new user's first $100 — **but only while the game averages 100+ DAU for the 60 days after they join.** It is a post-traction revenue line, not launch income. Don't count on it early.

### ⏸️ 9. Pricing
Enable **Regional Pricing** and review **Price Optimization** suggestions.

### ⏸️ 10. Private server price — set it once
Verified: **changing the private-server price cancels every active subscription.** Pick 99 R$ (or whatever we settle on) and never change it.

---

## Ongoing

### ⬜ 11. Taxes
Roblox earnings are taxable in Sweden. Talk to Skatteverket or an accountant once money actually starts coming in — not urgent yet.

### ⬜ 12. Weekly rhythm
- Playtest on the phone.
- Review KPIs in Creator Hub.
- Approve releases.
- Send phone screenshots whenever something looks wrong — with no Studio, that is Claude's only view of the game.
- *Optional:* an hour at the computer with Studio open, if you ever get one. Not assumed by the plan.

---

## Answers on record (2026-09-16)

| Question | Answer |
|---|---|
| Weekly hours | ~8–10 h, **phone-only during business hours** (Sweden, CEST) |
| Roblox Plus / Premium | None yet — **subscribing now** |
| Community (group) name | "Nomling Games" (default accepted) |
| Claude plan tier | **Pro** → environment API credential for Open Cloud is available |
| TEST / PROD IDs | Not yet created — coming |

## Waiting on Philip right now

1. **TEST and PROD universe + place IDs**, once the Community and experiences exist (task 3). Remember **R15 Only** in Avatar Settings on both.
2. **The date your Roblox Plus subscription starts**, so the M6 all-ages date can be pinned.
3. **Do you ever have computer + Studio time** (evenings, weekends), or should Claude plan for zero? See the note below — it changes how snatching gets tested and how the art pass works.

### Why the Studio question matters

Phone-only means no Roblox Studio, and two parts of the plan assumed it:
- **Multi-client playtesting.** Snatching is player-vs-player; it needs two clients at once. Without Studio, Claude will build scripted NPC "test snatchers" and server-side simulation instead, and you verify on your phone against a bot.
- **Visual review.** Claude cannot see the game without Studio viewport captures. Your phone screenshots become the only art feedback channel, so the art pass (M4) will lean on you sending pictures.

Both are solvable and Claude is planning for zero Studio time by default. If you *do* get occasional computer time, say so — it makes M2 and M4 cheaper.
