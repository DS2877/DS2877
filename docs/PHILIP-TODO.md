# PHILIP-TODO

Things only Philip can do. Claude keeps this current (brief §12, §11.11).
Last updated: 2026-09-17 (API key scopes granted — **the game has sound**, all 8 assets uploaded and live; cloud smoke test runs and passes 25/25).

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

### ✅ 3. TEST experience — PUBLISHED 2026-09-16

| | |
|---|---|
| Name | **Fuse a Nomling TEST** |
| **Universe ID** | **`10766688851`** |
| **Place ID** | **`107785954354396`** |
| Creator | McThad (personal account) |
| Audience | Private — only Philip can enter, which is all TEST needs |

*IDs are not secrets; they go in GitHub as **variables**, not secrets. Recorded here so a future session never has to ask again.*

- ✅ **TEST experience published 2026-09-16**, personal-owned. That is fine.
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

### 🔴 Blocking Phase 2 completion — one thing left

1. ✅ **Done** — universe and place IDs captured above.
2. ✅ **Done** — Open Cloud API key created with `universe-places` → **Write** on this experience.
3. ✅ **Done** — GitHub secret `ROBLOX_API_KEY` and variables `ROBLOX_TEST_UNIVERSE_ID`, `ROBLOX_TEST_PLACE_ID` all set.
4. ⏸️ The `production` GitHub Environment gate can wait until there is a PROD experience to protect.

#### ✅ 5. TEST publishing works — 2026-09-16

`Fuse a Nomling TEST` publishes on demand. The 409 that blocked it for 2½ hours
cleared on its own; the ruled-out table is in [`docs/RUNBOOKS.md`](RUNBOOKS.md) §9a
so the next one takes a minute rather than an afternoon.

---

## ✅ DONE 2026-09-17 — key scopes granted, audio is in the game

All three scopes are live on the new key and every one is confirmed by use
rather than assumption:

| API system | Proven by |
|---|---|
| `universe-places` → Write | TEST publishes |
| `assets` → Read + Write | 8 audio assets uploaded and through moderation |
| `universe.place.luau-execution-session` → R+W | cloud smoke test runs, 25/25 |

**Quota spent: 9 of 10 this month** (one canary plus the set of eight). Audio
cannot be updated in place, so re-running the upload mints *new* assets and
spends more — the ids in `src/shared/Config/Audio.luau` are final unless a
sound is deliberately re-rendered. Doing task 2 (age check / ID verification)
raises the ceiling to 100/month.

<details>
<summary>What the job was, for the record</summary>

## ONE 60-SECOND JOB ON ONE SCREEN — TWO CHECKBOXES

Both of these are the same API key, the same page, and neither changes the key
value, so **GitHub needs no update afterwards**.

Creator Hub → **Credentials** → **API Keys**.

| Add this API system | With these operations | What it unlocks |
|---|---|---|
| **`universe-places`** | **Write** | Publishing the place. Already working |
| **`assets`** | **Read** *and* **Write** | The music and all seven sound effects |
| **`universe.place.luau-execution-session`** | **Read** *and* **Write** | The cloud test that runs after every deploy |

⚠️ **`assets` needs READ as well as WRITE**, and an earlier version of this file
said Write only. The upload is asynchronous: the POST returns an *operation*,
and the script polls `GET /assets/v1/operations/...` for the result. Write alone
uploads and then fails on the very next call.

*(Publishing already works — that is `universe-places` → Write, which you added
on 2026-09-16. These are additions, not replacements.)*

**1. `assets` → the game is silent without it.** The theme and every sound effect
are built, committed and one click from being in the game. The audio system is
wired; it just has nothing to point at, and it degrades quietly rather than
erroring. Tried it again on 2026-09-17: all eight files still fail.

**2. `universe.place.luau-execution-session` → CI is red without it.** The place
publishes fine; the smoke test that runs *inside* the published place returns
`HTTP 403 PERMISSION_DENIED: the required scope
universe.place.luau-execution-session:10766688851:write is missing`. This has
been red since 2026-09-16 and is the **only** failing check on the open pull
request. Nothing in the game is broken by it — but a permanently red CI is a CI
nobody reads, so it is worth the extra checkbox.

### ⚠️ Before the audio upload: the monthly quota is smaller than it sounds

Roblox limits audio uploads **per creator per month**:

- **100/month if you are ID-verified**
- **10/month if you are not** ← this is you today (task 2 above is still open)

**We have 8 audio files.** On an un-verified account that is one clean run and
almost no margin, and audio is *"not available for updating"* — a bad upload is
a burnt slot, not something to fix in place.

So the upload goes: **one small sound effect first**, confirm it lands, then the
remaining seven. Same 8 total, but the key is proven before the budget is spent.

Doing **task 2 (age check / ID verification)** first raises this to 100/month and
is needed for the M6 all-ages launch anyway — so if it is quick, do it first.
Checked 2026-09-17: `create.roblox.com/docs/cloud/guides/usage-assets`.

### Two more things that silently break a key

- **Leave "Restrict IP addresses" OFF.** GitHub Actions runners have no fixed IP.
- **Set no expiration date** — and note Roblox expires a key after **60 days of
  inactivity** regardless, so a quiet stretch on the project can kill it.

### 🔑 A new key means a NEW SECRET VALUE

If you create a fresh key rather than editing the existing one, the old value
stops working. **GitHub → Settings → Secrets and variables → Actions → update
`ROBLOX_API_KEY`.** Nothing deploys until that is done.

Tell me when it is saved and I run the audio upload, paste the asset IDs in, and
re-run CI.

</details>

---

## ⚠️ FULLY LEAVE AND REJOIN BEFORE TESTING

Roblox does not update a server that is already running. If you keep the app
open, or rejoin fast enough to land back in your old server, you get the OLD
build no matter what has been published. **Close the experience, give it a
minute, then join again.**

This is not a formality — on 2026-09-17 I published every fix as a `Saved`
version, which does not go live at all, and Philip playtested a build four
commits old. `tools/publish.py` now says `NOT LIVE` in capitals for a Saved
version instead of the word "Published", and **`Deploy TEST` is the only
workflow that makes a build playable.** CI's publish step is validation, not a
deploy.

---

## 📱 Playtest — just the fixes (90 seconds)

Everything you flagged in the last screenshots. Do this first; the full script
below still works if you have longer.

| # | Do this | Should happen |
|---|---|---|
| 1 | Join and look at the top of the screen | Nothing sits under the Roblox menu/chat buttons. Purse on the left, objective banner beside it, **not on top of it** |
| 2 | Look at the bottom | Three buttons, about **a third shorter** than before. **FUSE** fits inside its button. The blue one reads **SAVE** — it is not blank |
| 3 | Look at the "?" on the right | Below the banner, not across it |
| 4 | Wait for the egg to hatch | The green slot sits **directly on top of the bottom bar**, not floating in the middle |
| 5 | Walk to the belt with **0 coins** and tap Buy | **This is the one that was broken.** You should get a shake, a sound, and a message: *"78 more coins and it's yours — your Nomlings are earning right now!"* Before, it did nothing at all |
| 6 | Look at the banner while you wait | *"Saving up for the belt: 12 / 90 coins"* — it counts |
| 7 | Look at a belt Nomling from a distance | Big line on top (name, or **✨ MUTATION ✨**), small line under it with rarity, coins/sec and the **price**. Not four identical lines of grey |
| 8 | Earn 90 coins and tap Buy again | It buys, with the burst and the sound |
| 9 | Look around for a tall mint-green beam | **YOUR BASE**, readable through the buildings from either end of the road, counting down the studs as you walk back |

**If any button still does nothing, tell me exactly which one and what the purse
said at the time** — a refusal now always speaks, so silence means a real bug.

---

## 📱 Playtest — the whole game (5 minutes)

Open **Fuse a Nomling TEST** on your iPhone.

| # | Do this | Should happen |
|---|---|---|
| 1 | Just stand still and look | **Bright midday**, blue sky, fat clouds, candy-coloured buildings, striped awnings. Not moody — the GTA-ish look is gone |
| 2 | Look at a Nomling's face | **Smile, rosy cheeks, a shine in each eye.** They breathe |
| 3 | Walk right up to one | It **turns to look at you and bounces higher** |
| 4 | Follow the glowing marker | It points at wherever your current objective is, and moves with you |
| 5 | Tap the green slot when ready | A creature **rises up out of the pedestal** with a bounce |
| 6 | Watch the purse | Coins fly in, the number climbs smoothly |
| 7 | Walk to the belt | Creatures ride past. Mutated ones **glow and sparkle** |
| 8 | Tap **🥚** (right rail) or the market counter | The **Egg Market** — all six tiers, locked ones showing what Re-Nom unlocks them, and an **Odds** button on each |
| 9 | Tap the green **FUSE** button | Pick two — order matters. There's an **Odds** button here too |
| 10 | Claim it | **The reveal.** Silhouette, colours resolve, rarity banner, the name types itself out |
| 11 | Tap **📖** | **The Fusion Book** — a 12×12 grid. Rows are the snack, columns the animal. Tap any square |
| 12 | Read the board on the street | 🏆 **TOP NOMLERS**, ranked by coins/sec |
| 13 | Look at a base sign | Name, coins/sec, Nomling count — how you pick a target |
| 14 | Wait a few minutes | ⛅ **Weather**: 15 s warning, then a coin boost and possible permanent mutations |
| 15 | Wait a bit longer | 🦝 **Sneaky Sam** — a masked raccoon bandit — takes one and runs |
| 16 | Chase him, tap the blue **SAVE** button | **Bubbled.** Your Nomling comes home |
| 17 | Tap **?** | Full how-to-play, any time |

### What I most want to know

1. **Does it feel like a kids' game now?** That was the whole retune.
2. **Does the reveal land?** It is the product.
3. **Frame rate.** A great deal went in. Quality auto-drops if it struggles, but tell me where.
4. **Do the creatures read as snack-animals** rather than just animals?

### Known and deliberate

- ~~Silent~~ **The game has sound.** Theme plus seven effects, live since 2026-09-17.
- **You're alone in the server**, so player-vs-player stealing is untested. Sneaky Sam covers the mechanic.
- **No Laser Gate or Vault** — you can bubble a thief but not lock one out.
- **No daily rewards** and **no analytics funnel** yet.

### 📅 When you next have computer + Studio time

Two moments where it is worth most, in order:
1. **M2a (late October) — the procedural creature review.** This is the project's biggest risk (`docs/RISKS.md` risk 2): the whole pitch is that generated creatures look good, and screenshots are a slow way to judge that. An hour with Studio open then is worth more than an hour at any other point.
2. **M4 (early December) — the art and performance pass.**

Claude is still planning for zero Studio by default — NPC snatch tests and a contact-sheet tool so you can judge 50 creatures from one screenshot. Studio time makes those better, not necessary.
