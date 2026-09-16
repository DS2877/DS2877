# PHILIP-TODO

Things only Philip can do. Claude keeps this current (brief §12, §11.11).
Last updated: 2026-09-16 (setup steps corrected against the real Roblox UI).

**Status key:** ⬜ not started · 🟡 in progress · ✅ done · ⏸️ not needed yet

---

## 🔥 Time-critical — the clock is running

### ✅ 1. Start Roblox Plus — DONE 2026-09-16

**Why now:** publishing to under-16 audiences requires an active Plus or Premium subscription **for 2 consecutive months** at the moment you publish for all ages. Starting today (2026-09-16) clears that bar around **2026-11-16**, comfortably before the M6 all-ages target of 2026-12-12. Every week of delay eats that buffer.

**Verified nuance (this is better than the brief assumed):** the subscription is only checked **when you publish or update for all ages**. If it lapses afterwards, the game stays published. So this is a ~2-month commitment, not forever.

**Alternative:** a one-time refundable per-game publishing fee instead of the subscription. It is auto-refunded 90 days after the game becomes Kids/Select eligible — or 90 days after payment if it never gets there. Not refunded if the game is permanently removed for Community Standards violations.

→ ✅ **Subscribed 2026-09-16.** The 2-consecutive-month bar clears **~16 November 2026**, comfortably before the M6 all-ages publish in January. Nothing further needed here — just don't cancel before mid-November.

---

## Before building

### ⬜ 2. Account security
- Complete the **age check** (facial age estimation, or government ID since you're 18+).
- Turn on **2-Step Verification**.

**Correction from Phase 0:** you need the full ID + 2FA stack only to reach **under-16** players. To launch to **16+** you need just an account in good standing that is **at least 2 days old**, age verification, and a completed Maturity & Compliance Questionnaire. So this is not a blocker for M5 — but do it now anyway, since M6 needs it and ID verification can take time.

### 🟡 3. Experiences — TEST done, rest deferred
- ✅ **TEST experience created 2026-09-16** ("Fuse a Nomling TEST"), personal-owned. That is fine.
- ⏸️ **Community (group): deferred.** Costs **100 Robux**, and Claude does not spend money without asking. Not needed for TEST. Created from Creator Dashboard → account switcher (upper-left) → **plus (+)**, *not* a "Communities" menu.
  ⚠️ Claude could not find docs confirming an experience can be moved from a personal account into a group later. So if group ownership matters, create **PROD** inside the group in December rather than planning to move TEST.
- ⏸️ **PROD experience: deferred** to M4/M5.
- ⏸️ **TEST audience → Limited → Playtesters:** only needed once someone other than Philip needs access. He can play his own experience without it.

### 🟡 3b. Set R15 Only — Philip has Studio on desktop, so do it now
**Update 2026-09-16:** Philip turned out to be working in the Roblox Studio desktop app. Avatar Settings is right there: **Avatar tab → Avatar Settings → ⋯ → R15 Only**. Thirty seconds, free, and it clears the M4 task early.

Also discovered at the same time: a place created in Studio exists only on the local machine until **File → Publish to Roblox**. That is the step that creates the experience on Roblox and produces the universe and place IDs.
⚠️ **Correcting an earlier instruction that said "do this now, it can't be fixed later."** That was wrong on both counts.

Avatar Settings lives **inside Roblox Studio** (File menu / Avatar tab), and Roblox's docs say the values are "not accessible with scripts" — so Rojo cannot set it either. It is not on the Creator Dashboard. That was why it was originally deferred.

Fallback if it gets missed: the R15 requirement gates the higher DevEx rate (0.0054 vs 0.0038 per Robux), which only applies to Robux earned from real players, so the true deadline is launch — not today.

### ⬜ 4. Open Cloud API keys
Create keys with minimal scopes and store as the GitHub Actions secret `ROBLOX_API_KEY`.
*Claude will give you the exact scope list in Phase 2 — wait for it rather than guessing.*

🆕 **You're on Claude Pro, so you also get the better option:** add an environment **API credential** for `apis.roblox.com` (header name `x-api-key`, no prefix) in the cloud environment settings. Cloud sessions can then call Open Cloud directly — Claude never sees the key, and publishing to TEST stops depending on a GitHub Actions round-trip. Claude will give you this text in Phase 2 too.

### ⬜ 5. Cloud environment setup
**→ Everything you need is now written out in [`docs/CLOUD-SETUP.md`](CLOUD-SETUP.md).**

That one page covers all of tasks 4 and 5: the network allowlist, the setup script line, the optional API credential, the GitHub secret and variables, the `production` environment gate, and the exact API key scopes.

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
| Weekly hours | ~8–10 h, mostly phone during business hours (Sweden, CEST) — but **has Roblox Studio on a desktop** and will use it when needed |
| Roblox Plus / Premium | None yet — **subscribing now** |
| Community (group) name | "Nomling Games" (default accepted) |
| Claude plan tier | **Pro** → environment API credential for Open Cloud is available |
| TEST / PROD IDs | Not yet created — coming |

## Waiting on Philip right now

### ✅ All Phase 1 gates cleared 2026-09-16
- Roadmap re-plan approved — launch **8–12 Dec**, all-ages January.
- React-Lua and ProfileStore approved.
- Studio time: available later in the project when needed.

### 🔴 Blocking Phase 2 completion

Claude can build the whole pipeline without these, but **cannot publish anything to TEST until they exist**:

1. **Send Claude the TEST universe ID and place ID.** Both are in one URL — Creator Dashboard → Creations → click the experience → click the place, then read the address bar:
   `.../experiences/<UNIVERSE_ID>/places/<PLACE_ID>/configure`
2. **Create the Open Cloud API key.** Creator Dashboard → **Credentials** → API Keys → Create API Key. Add the **`universe-places`** API system with the **Write** operation on this experience. (You pick systems and operations from menus; you never type scope strings — the earlier instruction to do so was wrong.) Full walkthrough in [`docs/CLOUD-SETUP.md`](CLOUD-SETUP.md) §5.
3. **Add to GitHub:** secret `ROBLOX_API_KEY`, variables `ROBLOX_TEST_UNIVERSE_ID` and `ROBLOX_TEST_PLACE_ID`.
4. ⏸️ The `production` GitHub Environment gate can wait until there is a PROD experience to protect.

### 📅 When you next have computer + Studio time

Two moments where it is worth most, in order:
1. **M2a (late October) — the procedural creature review.** This is the project's biggest risk (`docs/RISKS.md` risk 2): the whole pitch is that generated creatures look good, and screenshots are a slow way to judge that. An hour with Studio open then is worth more than an hour at any other point.
2. **M4 (early December) — the art and performance pass.**

Claude is still planning for zero Studio by default — NPC snatch tests and a contact-sheet tool so you can judge 50 creatures from one screenshot. Studio time makes those better, not necessary.
