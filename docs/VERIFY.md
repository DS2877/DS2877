# VERIFY.md — Platform fact check of the kickoff brief §3

**Verification date: 2026-09-16.** All `create.roblox.com` pages below reported `last_updated: 2026-09-15`, so this is current as of one day before checking.

**Verdict key**

| | Meaning |
|---|---|
| ✅ | Confirmed as written in the brief |
| ⚠️ | Substantially right, but the brief is imprecise or incomplete — read the correction |
| ❌ | Contradicted by official docs |
| ❓ | Not found in official sources — do not build on it until re-checked |

**Re-verify before M5 (launch).** Roblox changes these rules often; the Kids/Select framework in particular moved several times during 2026.

---

## Headline findings (the five that change our plans)

1. **Discovery ranking only counts organically-acquired users.** Roblox explicitly excludes users first acquired from ads, friends, search, social media or any other source from the *ranking* stage of Recommended for You. Our launch plan (§9) therefore drives **two separate funnels**: invited/ads traffic earns Kids/Select eligibility, but does **nothing** for home-page ranking. See §3.2 below.
2. **Audience Expansion Rewards require the game to average 100+ DAU for 60 days** after the user joins. The brief omits this gate. A small game earns **zero** here, so it must not be modelled as early revenue. See §3.3.
3. **"Highly engaged player" now includes a platform-spend test.** The 250-play gate counts users qualified on account tenure, playtime *and* Roblox-wide spend. Recruiting 250 brand-new alt accounts cannot work by design. See §3.1.
4. **Private servers are a weak revenue line for our core audience.** Under-13 players may be unable to join private servers at all, and changing the price **cancels every active subscription**. See §3.3.
5. **`cargo install` works in this cloud environment** (validated live, 44 s for StyLua). Toolchain Option B is viable and Option A (mirroring GitHub release binaries) is not needed. See the Environment appendix.

---

## §3.1 Age tiers and the launch gate — ⚠️ confirmed with important additions

Sources:
- [Roblox Kids and Select](https://create.roblox.com/docs/en-us/production/publishing/kids-and-select.md)
- [Content maturity and compliance](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)
- DevForum: [New Publishing Requirements & Evaluation Process for Games](https://devforum.roblox.com/t/new-publishing-requirements-evaluation-process-for-games/4573166) (updated 2026-05-11)
- DevForum: [Roblox Kids and Select Global Launch](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717) (updated 2026-07-16)

### Confirmed ✅

| Brief claim | Status |
|---|---|
| Three tiers: Kids (5–8), Select (9–15), Roblox (16+) | ✅ |
| Kids see Minimal/Mild only; Select up to Moderate | ✅ |
| Verified creator: facial age estimation under 18, government ID at 18+ | ✅ |
| 2-Step Verification required | ✅ (for under-16 audiences) |
| One-time refundable per-game fee **or** Plus/Premium active 2+ consecutive months | ✅ |
| 250 unique plays from highly engaged age-checked players within 60 days | ✅ |
| Plus a safety review | ✅ (real-time moderation reports + gameplay reviewed) |
| Expedited review for a refundable 50,000 Robux | ✅ |
| Kids chat off by default | ✅ |
| Private games restricted to Edit permission; testers via Audience → Limited → Playtesters | ✅ |
| Every new game starts with age-checked 16+ only | ✅ (this is the "Trial phase") |

### Corrections and additions ⚠️

1. **Publishing to 16+ is a much lower bar than the brief implies.** It needs only: an account in good standing **and at least 2 days old**, age verification, and a completed Maturity & Compliance Questionnaire. No verified-creator ID step, no 2FA, no fee. The ID/2FA/fee/evaluation stack applies **only** to reaching under-16s.
2. **Self-declared 16-year-olds are in Select, not Roblox.** Tier assignment is: Select = "self-declared age 9 or older (until age-checked)"; Roblox = "age-checked age 16 or older". Our launch audience is *only* age-checked 16+, which is a genuinely small pool. This strengthens the brief's strategic read.
3. **"Highly engaged player" is defined and includes spend.** Quoting the docs: a highly engaged player "must meet requirements on account tenure, playtime in your game, and platform spend". Users qualifying on the spend test "have made a minimum purchase anywhere on Roblox in the last 60 days and have spent time in your game within that same window. They don't need to spend anything in your game specifically." Roblox states free-to-play games can still reach the threshold.
4. **The subscription requirement is checked only at publish/update time.** "If your subscription later expires, your game stays published for all ages." Philip needs 2 consecutive months of Plus/Premium *before* the all-ages publish, not forever. Starting Plus on ~2026-09-16 clears the 2-month bar around ~2026-11-16, comfortably before the M6 target of 2026-12-12.
5. **Fee refund terms:** the publishing fee is auto-refunded 90 days after the game becomes Kids/Select eligible, or 90 days after payment if it never becomes eligible. It is **not** refunded if the game is permanently removed for Community Standards violations. Same caveat on the 50,000 R$ expedited fee.
6. **Playtesters who are Trusted Friends of an age-checked game owner can access the game regardless of age**, provided the content maturity questionnaire is complete. Useful for Philip's own testing.
7. **Evaluation progress is tracked in the Audience Reach dashboard** in Creator Hub, in real time.

### Content-rule claims — mixed

- **"Games centered on social hangouts, sensitive topics or free-form drawing are excluded by default"** → ⚠️ true in substance, but the mechanism is different and the thresholds are worth knowing precisely:
  - **Social hangout** (primary theme is talking to / interacting with other players via voice or text chat): 16+ only without private spaces, 18+ with. Roleplay-primary experiences are explicitly *not* social hangouts.
  - **Free-form user creation** (free-form drawing/creation tools): **16+ only.** Explicitly does *not* cover assembling things from 3D assets, or anything moderated before publish/replication.
  - **Sensitive issues**: only when the *majority* of content/gameplay is themed on one; then 16+ and not recommended/discoverable unless age-verified.
  - → Our design touches none of these. The zero-chat requirement stands regardless.
- **"Banned for Kids/Select: a media feed combined with autoplay/looping/auto-scroll combined with a reward for continued watching"** → ❓ **not found.** The questionnaire has a **Media** category asking (1) whether users can share media from their gameplay, (2) whether the experience has "content feeds with continuous loading or audio/video that plays automatically", and (3) whether users can view content captured from other experiences. The docs do **not** state the audience consequence of answering yes, nor the "reward for continued watching" compound condition. **Treat the brief's rule as our own conservative design constraint, not as a verified platform rule.** We are building nothing feed-like either way, so this never becomes load-bearing.

### New constraint worth designing around

**Maturity labels vs. descriptors are different things.** The label (Minimal / Mild / Moderate / Restricted) is driven by violence, blood, fear, crude humor, gambling, language, romance and alcohol. Paid random items, paid item trading, social hangout, free-form creation, sensitive issues, media and AI interaction are **separate descriptors** with their own audience gates.

- **Paid random items does not appear to raise the maturity label.** So eggs/fusion are compatible with a **Minimal** label. ⚠️ This is inferred from the structure of the docs, which never state a label consequence for the PRI descriptor — re-confirm when Philip actually takes the questionnaire.
- **"Unplayable gambling content" *is* a Moderate-label trigger**, and Roblox defines gambling as "exchanging real world money, Robux, or in-experience items of value for a game of chance" while stating experiences "cannot contain playable gambling content, including simulated gambling". → **Design rule: the Egg Market and Fusion Lab must never use casino/gambling visual language** — no prize wheels, slot-machine reels, playing cards, dice or chips. Keep the vending-machine / kitchen framing. This is a real constraint on the art direction that the brief did not anticipate.

---

## §3.2 What discovery rewards — ⚠️ confirmed, with one strategy-changing correction

Source: [Discovery](https://create.roblox.com/docs/en-us/discovery.md)

### The signal list, as officially published

| Priority | Signal | Time segments |
|---|---|---|
| Most important | **Play through rate** — rate at which users play after seeing it in Recommended for You | n/a |
| Most important | **First play bounce rate** (negative signal) | <60 s avg; 61–180 s avg |
| Most important | **Play days per user** | D8–28, D2–7, D1 |
| Most important | **Playtime per user** — **max 60 minutes per user, per game, per day** | (same segments) |
| Important | **Intentional co-play days per user** — via join, invites, or private servers | |
| Important | **Qualified play sessions per user** — filters out accidental clicks and quick bounces | |
| Important | **Spend days per user** | |
| Important | **Robux spent per user** | |

All of the brief's signals are real. Corrections:

1. ⚠️ **The playtime cap is 60 minutes per user per game per day.** The brief said "7-day playtime: capped per day" without the number. The metric is "Playtime per user", segmented D1 / D2–7 / D8–28 — the brief's "first 28 days" framing is right.
2. ⚠️ **"Qualified play sessions per user" is a signal the brief omits.** It explicitly filters out accidental clicks and quick bounces, which doubles the value of a strong first 60 seconds.
3. ❗ **The correction that matters: only organic Recommended-for-You users count in ranking.** Verbatim: *"Roblox doesn't count the engagement, monetization, or retention of users first acquired from ads, curation, friends, search, social media, or any other source in the ranking stage of Recommended for You."* Every signal "is based on users who **organically** joined from the Recommended for You sort on Home."
   - Those other sources still help **retrieval** ("Signals from sponsored ads, curation, search, charts, friends, teleport, notifications... can accelerate your consideration for organic discovery"). So ads and friends get us *considered*; only organic cohorts decide how far we go.
   - **Consequence for §9:** the M5 push for 250 highly engaged plays and the home-page ranking climb are two different jobs. Sponsored ads and Discord/Reddit recruitment serve the first. Only the retention and spend of players who found us on Home serve the second. The revenue and growth model must not conflate them.
4. ❓ **The RDC 2026 claims are unverified.** Age-aware ranking, "engagement measured over the first 28 days and beyond" as a *change*, and a "direct growth" signal in testing do **not** appear in the discovery docs. The D1/D2–7/D8–28 segmentation is live and documented; the rest is not. Do not build plans on the age-aware ranking or direct-growth claims until sourced.

### New: documented ways to *lose* exposure

Worth writing into `docs/STORE-PAGE.md` and `docs/MARKETING.md`:

- **Leading with giveaways** — metadata implying monetary reward is deprioritized. (Our "[❄️ FROSTY]" style update tag is fine; a "FREE COINS!!" tag is not.)
- **Mismatched metadata and content** — thumbnails must show actual gameplay. Reinforces the brief's "honest store page" rule.
- **Non-unique games** — "Games with metadata and place files that closely resemble existing games... are no longer prioritized for recommendations and might rank lower in search." ⚠️ **This is a direct risk for us**, since the brief positions the game inside two crowded, heavily-cloned genres. The fusion hook and original art direction are not just differentiation for players — they are a discovery requirement. Flag for the Phase 1 risk list.
- Content quality is **reclassified with every update**, and affected games show a daily-updating banner on the Creator Dashboard.

Also documented and useful: thumbnail personalization for the home page, Experience Events (up to 5 thumbnails, opt-in notifications), semantic search, and in-experience notification permission prompts.

---

## §3.3 Money tools — ⚠️ mostly confirmed; two material gaps in the brief

### Roblox Plus — ✅ confirmed, and better than the brief says

Source: [Roblox Plus](https://create.roblox.com/docs/en-us/production/monetization/roblox-plus.md)

- Subscriber discount: **10% for the first two months, 20% from the third month.** Roblox subsidises it; creator earnings per purchase are unchanged. Effective revenue share to us rises from 70% → 78% → 88% of what the player pays.
- **Free paid private servers for subscribers** ✅ — and we are still compensated for their time.
- Plus sign-ups via `PromptRobloxSubscriptionPurchase`: **250 Robux/month for the first three consecutive paid months, up to 750 Robux per subscriber.** Free-trial periods excluded. Payout only when they subscribe *through our game*.
- Paid private server time: **up to 100 Robux per subscriber** who spends **60+ cumulative minutes over the last 30 days**. ⚠️ Three conditions the brief omits: only the **server owner's** time counts (invited subscribers' time does not); the server must rank in that subscriber's **top five paid private servers across all of Roblox**; and the amount earned scales with the server price.
- 🆕 **Not in the brief:** we earn **10% on in-game Robux transfers** via `PromptRobuxTransferAsync`, and that amount **is** DevEx-eligible. Transfers are age-restricted and need parental consent, so this is likely irrelevant for a 9–15 audience — logged for completeness, not for v1.
- 🆕 API surface for implementation: `Player.HasRobloxSubscription`, plus `GetPropertyChangedSignal` to confirm a subscription server-side before granting anything; `productInfo.UserBasePriceInRobux` vs `productInfo.PriceInRobux` to display discounts correctly.
- ✅ **Directly confirms brief §5.1 rule 3.** Verbatim warning: *"If you hard-code prices, your in-game UI might display incorrect pricing to Plus subscribers."*
- ❓ The **$4.99/month** price is not stated in the creator docs. Unverified; not load-bearing for us.

### Creator Rewards — ⚠️ confirmed with a critical omission

Source: [Creator Rewards](https://create.roblox.com/docs/en-us/creator-rewards.md)

**Daily Engagement — ✅ 5 Robux/day**, with the rule stated precisely as: the experience must be one of the **first three experiences the user visits *and spends 10+ minutes in*** that day. (The worked examples confirm this: an experience visited fifth still earns if only two earlier experiences crossed 10 minutes; an experience visited fourth-to-cross-10-minutes does not earn.) Time accumulates across visits in the day.

⚠️ **"Active Spender" is a demanding definition the brief omits:** a user who "(a) has made Qualifying Purchases totaling **at least $9.99 USD** anywhere on Roblox within the past 60 days; and (b) was not a New User or Reactivated User during the past 60 days." Qualifying Purchases = Robux, Roblox Premium, or UGC subscriptions. Only these users trigger the 5 R$.

**Audience Expansion — ⚠️ confirmed rate, but there is a hard gate the brief misses.**
- Rate ✅: **35% revenue share on the user's first $100 of Qualifying Purchases anywhere on the platform**, over their first **60 days**, less any qualifying purchases made in the 60 days after a previous reactivation.
- "New User" / "Reactivated User": a Lapsed User is one who has not logged in for **60 consecutive days** ✅.
- Three qualifying attribution paths ✅: Share Link; direct link where our game is their first session that day; or **searching our specific experience name** where our game is their first session that day. All three require **10+ minutes of play that day**.
- ❗ **Every path additionally requires: "the experience maintains an average of 100+ DAU for 60 days after the joining or rejoining date."** This is not in the brief. Until we hold 100+ DAU for a sustained 60 days, Audience Expansion pays **nothing**. Model it as a post-traction revenue line only.

### Rewarded Video ads — ✅ confirmed

Source: [Rewarded video ads](https://create.roblox.com/docs/en-us/production/promotion/rewarded-video-ads.md)

Eligibility, verbatim: game must be **public and unrestricted**; **offer no free-form user creation**; have a **complete Maturity and Compliance Questionnaire reviewed and approved** by Roblox (re-review requests answered within 24 h); average **at least 2,000 unique visitors per month**; comply with ToU, Community Standards and publisher integrity requirements. Creator must be **13+ with an ID-verified account**. All ✅ as the brief states (the brief's "2FA" is not listed on this page but is required elsewhere anyway).

- ✅ **Rewards must be developer products. "You can't reward users with Robux."**
- ✅ Check `AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)` before showing anything — and the docs add: call it **as close as possible to the moment you plan to show the ad** (e.g. on shop open, not at join).
- 🆕 Ineligibility reasons to handle: `PlayerIneligible`, `DeviceIneligible`, `PublisherIneligible`, `ExperienceIneligible`.
- 🆕 Server-side flow: `AdService:CreateAdRewardFromDevProductId` → `ShowRewardedVideoAsync`, optionally with a **Placement ID** for per-placement analytics. Worth using from day one so we can measure placements separately.
- 🆕 Roblox recommends rewards **worth roughly 3–10 Robux** — that is the right size for our `adReward_skip` hatch skip.
- ⚠️ The brief's "under-13 users aren't eligible" is not stated on this page; `PlayerIneligible` exists but is not age-explained. Since we must handle the ineligible cases anyway, nothing changes.

### Private servers — ⚠️ two warnings the brief misses

Source: [Private servers](https://create.roblox.com/docs/en-us/production/monetization/private-servers.md)

- ✅ Monthly Robux fee, set under Audience → Access Settings → Allow private servers → Requires Robux. Game must be **public** first.
- ❗ **"Changing the price of private servers cancels all active subscriptions."** Existing subscribers get an inbox message. → **Set the 99 R$ price once and never change it.** Put this in `docs/RUNBOOKS.md` and `docs/LIVEOPS.md` as a do-not-touch.
- ❗ **"Players under the age of 13 may not be able to join private servers depending on their privacy and parental control settings."** Our core audience is 9–15. The private-server revenue line, and the "Chill Mode" feature that depends on it, reach a much smaller share of our players than the brief assumes. Keep Chill Mode (it is cheap and it serves the 16+ trial audience and Plus subscribers), but do not model private servers as meaningful revenue for the core audience.
- 🆕 Private servers and paid access (Robux or local currency) are mutually exclusive. We are not using paid access, so this is fine.

### DevEx — ✅ confirmed exactly, and it settles the R15 decision

Sources: [Developer Exchange Program](https://create.roblox.com/docs/en-us/production/monetization/developer-exchange.md), [U.S. 18+ exchange rate](https://create.roblox.com/docs/en-us/production/monetization/18-plus-devex-rate.md)

- ✅ Standard rate **0.0038 per Earned Robux** = $114 USD per 30,000.
- ✅ Minimum cash-out **30,000 Earned Robux**.
- ✅ Higher rate **0.0054** for Earned Robux from **developer products, passes, subscriptions and private servers** bought by **U.S. players age-verified 18+**, in **eligible games**.
- ✅ **The R15 requirement is real and specific.** Qualifying games need player characters that spend **100% of active playtime** on a standard or advanced R15 rig. Using Roblox's built-in avatar system, the project must be set to **R15 Only** in Avatar Settings — *"If a player can spawn into or swap to a R6 avatar at any point during active playtime, your game is not eligible."* Animation packs on player characters must be R15, not R6.
  - → **Phase 2 action:** set Avatar Settings to **R15 Only** on both TEST and PROD at creation, and use only R15 animation packs. Cheap now, unrecoverable revenue later.
  - Note the honest caveat: our audience is 9–15 and non-US-heavy, so the 0.0054 rate will apply to a small slice of income. The setting costs us nothing, so we take it anyway.
- 🆕 Legacy balances earned before 2025-09-05 cash out at the old 0.0035 rate and must be cashed out first.

### "Coming soon" items — ❓ all unverified

Browser play in Chrome, game-page videos in the Moments feed, Quick Words, Roblox Wallet, and phone ad creation were **not found** in the current docs. None are v1 dependencies. The one to watch is **Quick Words**, because the brief's §6 Kids/Select readiness plan leans on it for communication — our fallback (emote wheel, zero-chat-complete design) must therefore be genuinely sufficient on its own, which it is.

---

## §3.4 Paid random items and trading — ✅ confirmed, near-verbatim

Sources: [Paid random items policy guidelines](https://create.roblox.com/docs/en-us/production/monetization/paid-random-items.md), [Content maturity](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md), DevForum: [Clarifying Requirements for Paid Random Items](https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622)

This is the best-confirmed section of the brief.

### Definition ✅

"Random items purchased directly or indirectly with Robux. **This includes random items purchased with paid in-game currency.**" Both "paying Robux to spin a prize wheel" and "paying Robux to buy gems or spin tickets that are spent at a prize wheel" are PRI. The four item types match the brief exactly:

| Type | Official examples | Our system |
|---|---|---|
| Capsule items | spin a wheel, **hatch an egg for a pet**, open a chest | Egg Market |
| Enhancement items | potion with random duration, upgrade spell with a chance of working | — |
| Combination items | **"Consuming or synthesizing two rare eggs for a better chance of a higher-quality result"** | **Fusion** |
| Probability modifier items | **luck boosts, pity systems**, enhanced drops, rate-up scrolls | `luckyPaws`, `luck15` |

→ The brief is right that **Fusion is itself a paid random item** under the "combination" type, and that luck items are PRI in their own right. Our odds-disclosure obligations cover eggs *and* fusion *and* every luck effect.

### Disclosure rules ✅ with one wording correction

- ✅ Must indicate **all possible outcomes and the actual numerical odds**.
- ⚠️ **Wording of the button:** the docs say the itemised list may live in a clickable pop-up "with an **'Info' or 'Details' icon** visible and accessible prior to purchase" and that "using a standalone symbol like the (i) icon **without a descriptive word is not sufficient**." The brief said "Odds" or "Details". The binding requirement is *a descriptive word, not a bare symbol*. → Our **"Odds"** button satisfies the intent; to be safe, label it **"Odds / Details"** or `ⓘ Odds`. Decision for `docs/COMPLIANCE.md`.
- ✅ Odds shown **as a probability percentage**, all final outcomes **summing to exactly 100%**.
  - 🆕 Rounding is explicitly permitted: round to "four or more decimal places lower than the decimal place with the first non-zero number", with a disclaimer such as *"Probabilities are rounded; total of displayed individual probabilities may not equal 100%."* → Our integer-ppm storage with exact 1,000,000 sum is **stricter than required** and is the right call. The Basic Egg's Secret at 0.0001% is representable exactly.
  - 🆕 Shortcut allowed: "Odds for each item listed below: X%" when many items share odds. Useful once a rarity tier contains many Nomlings.
- ✅ **Live updates while a modifier is active**: "The new odds of the enhanced random items must also be dynamically updated when these items are active to show the user's true odds." Confirms the brief's live-odds requirement for `luckyPaws` / `luck15`.
- ✅ Indirect purchases are covered — the warning names keys, re-roll tokens and spin tickets.
- 🆕 **"If users can only obtain one instance of an outcome, the odds for the remaining obtainable outcomes must be updated to reflect up-to-date remaining odds for that user."** → Applies if we ever make a Nomling once-only per player (e.g. Fusion Book completion rewards). Design note for `docs/GDD.md`.
- ✅ **Free randomness needs no disclosure**: "If your game offers randomized virtual rewards in exchange for completing an action that does not involve the payment of Robux or other in-game currency, you aren't required to disclose the odds." → Weather mutations and quest rewards are exempt. The brief's choice to disclose them anyway is voluntary good practice; keep it, but know it is optional.
- ❓ **"Every outcome must give some value" is not stated** in these docs. It may live in the Community Standards economy section. Harmless — our design gives every outcome value anyway — but do not cite it as a platform rule.

### `ArePaidRandomItemsRestricted` — ✅ all six treatments confirmed verbatim

When true, "the user cannot interact with paid random item generators, either through Robux directly or game currency bought with Robux." Creators **must** apply one of: an unpaid earnable path; a pre-determined non-random order disclosed before purchase; direct guaranteed purchase of specific outcomes priced at expected value; removing/hiding the item; blocking purchase with an error message; or removing the user from those parts of the game. The brief's list matches the docs one-for-one.

> ✅ **The brief's §5.2 "currency firewall" interpretation holds.** The policy binds on currency that is *purchasable with Robux*. If a restricted player can never buy Coins (Tier 1 hidden), their Coins are wholly earned, so eggs and fusion are "an unpaid, earnable path to acquiring the random item" — treatment #1, the first option Roblox lists. Also hiding Tier 2 (income multipliers) is **stricter than the policy requires**, since a multiplier is not a currency purchase. That extra strictness is cheap and defensible; keep it, but record that it is our choice, not a Roblox rule.
>
> ⚠️ Residual risk to re-check before M3: the exact treatment of Tier 3 items that *indirectly* accelerate PRI throughput (`turboIncubators`, `fusionPro`, `skipHatch*`, `skipFusion*`). These buy **time**, not odds and not currency — our reading is that they are outside the PRI definition. Worth a `compliance-reviewer` pass and, if still uncertain, a DevForum question before launch.

### `IsPaidItemTradingAllowed` — ✅ confirmed

When false, those users must not be able to trade the outcome of a paid random item or other paid items. Moot for v1 (no trading until Update 1), and the Bonded-item rule keeps us clear regardless.

### Questionnaire consequence

Both PRI and paid item trading are **questionnaire descriptors** with a second question each asking whether we respect the corresponding policy API. We answer **yes** to both, truthfully.

---

## §3.5 Phone-first tooling — ✅ confirmed, with exact limits

Source: [Luau Execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution.md), [Open Cloud index](https://create.roblox.com/docs/cloud/llms.txt)

- ✅ Base URL `https://apis.roblox.com`, API key in `x-api-key` (also supports OAuth2).
- ✅ **Luau Execution**: tasks run up to **5 minutes**, **10 concurrent tasks per place**, full DataModel and engine API access, **can save the place** via `AssetService:SavePlaceAsync`. Confirms the brief; the concurrency number it told us to look up is **10**.
  - 🆕 Hard limits for CI design: scripts up to **4 MB**; return values serialised to JSON must not exceed **4 MB**; binary inputs up to **100 MiB** (upload URI valid 15 min); binary output up to **256 MiB**; `timeout` defaults to 5 minutes; logs are capped and older logs discarded.
  - 🆕 **Rate limits matter for CI:** creating a task is **5/minute per API key owner** (45/min per IP). Polling `Get` is 40/min, log listing 200/min. → `ci.yml` must create few tasks and poll, not spawn a task per test. Design the cloud test suite as **one task that runs many assertions**, not many tasks.
  - ✅ `SerializationService` can deserialize RBXM — relevant to the `worldgen/` plan.
- ✅ **`Roblox/place-ci-cd-demo` is real** and is cited by Roblox's own docs as the reference implementation.
- ✅ Open Cloud features confirmed present: Publish (place publishing), Configs (experience configs), Messaging, **Developer products** and **Game passes** APIs, Assets, Analytics, Private servers, AdConfiguration, ItemConfiguration.
- ❓ Not yet checked in detail (defer to Phase 2, when we actually wire them): whether the Developer Products / Game Passes APIs are still beta and multipart/form-data; exact API-key scope names in Creator Hub; Messaging payload limits.
- ❓ **Studio MCP server** and **AudioTextToSpeech** rate limits not verified this phase. `AudioTextToSpeech` exists as an engine class with a [tutorial](https://create.roblox.com/docs/en-us/tutorials/use-case-tutorials/audio/add-text-to-speech.md) and a [beta DevForum announcement](https://devforum.roblox.com/t/beta-text-to-speech-api-from-text-to-voice-content-instantly/3792085). Since the brief already specifies a sound-effect fallback when rate-limited, this is not blocking — verify in Phase 4 (M2) when we build the reveal.

### One brief assumption that did not survive: ProfileStore

❓ **Roblox does not officially recommend any third-party data library.** The official guidance is [Implement player data and purchasing systems](https://create.roblox.com/docs/en-us/cloud-services/data-stores/player-data-purchasing.md), which covers `DataStoreService` directly. ProfileStore/ProfileService are community libraries with no official endorsement to "still" hold. → The brief's "confirm it is still the recommended library" has no official answer. **Make this an explicit Phase 1 technical decision** in `docs/TECH.md`, judged on the library's own merits (session locking, active maintenance, migration support) and recorded in `docs/DECISIONS.md`. It also interacts with brief §11 rule 7 (ask before adding dependencies).

---

## Open items to re-verify before launch

| # | Item | Why it matters | When |
|---|---|---|---|
| 1 | Media-feed rule for Kids/Select (§3.1) | Currently our own constraint, not a sourced rule | Before M4 |
| 2 | PRI descriptor's effect on the maturity label | Decides whether Minimal is achievable with eggs | When Philip takes the questionnaire (M4/M5) |
| 3 | Tier 3 time-skip items vs. the PRI definition | Affects the whole `skip*` product line | Phase 5 (M3), compliance-reviewer pass |
| 4 | RDC 2026 discovery changes (age-aware ranking, direct-growth signal) | Do not plan around unverified signals | Before M5 |
| 5 | Open Cloud dev-product / game-pass API shape and key scopes | Needed for `catalog-sync.yml` | Phase 2 |
| 6 | AudioTextToSpeech rate limits | Reveal design and fallback | Phase 4 (M2) |
| 7 | ProfileStore vs. alternatives | Data layer choice | Phase 1 |
| 8 | Roblox Plus price ($4.99) | Only affects marketing copy | Before M3 |

---

## Appendix: environment detection (Phase 0 step 2)

**Surface:** cloud session — `CLAUDE_CODE_REMOTE=true`, Linux x86_64, no Roblox Studio. Repo `DS2877/DS2877` on branch `claude/nomling-kickoff-31p9zv`; it was empty apart from `README.md`.

**Present:** `cargo` 1.94.1, `rustc` 1.94.1, `node` v22.22.2, `npm`, `python3` 3.11.15, `pip3`, `curl`, `jq`, `git`, `unzip`. ~30 GB writable disk.

**Missing — the entire Roblox toolchain:** `rojo`, `wally`, `stylua`, `selene`, `lune`, `rokit`, `luau-lsp`. Also `gh` (expected; GitHub work goes through MCP tools).

**Network, as measured:**

| Endpoint | Result |
|---|---|
| `create.roblox.com/docs/llms.txt` | ✅ 200 |
| `create.roblox.com/docs/cloud/llms.txt` | ✅ 200 |
| `devforum.roblox.com` | ✅ 200 |
| `apis.roblox.com` | ✅ reachable (404 at root is the expected no-route response) |
| `api.github.com` | ✅ 200 |
| `registry.npmjs.org`, `pypi.org` | ✅ 200 (bypass the proxy directly) |
| `index.crates.io`, `static.crates.io` | ✅ 200 |
| `crates.io/api/v1/...` | ❌ 403 (proxy policy) — not needed by cargo |
| `github.com/<repo>/releases/...`, `codeload.github.com` | ❌ 403 (proxy policy) |

**Toolchain decision — Option B, validated by experiment.** The brief left the choice open. `cargo install --locked stylua` was run live and **succeeded in 44 seconds**, producing a working `stylua 2.5.2`. Cargo needs only `index.crates.io` (sparse index) and `static.crates.io` (tarballs), both reachable; the blocked `crates.io/api` endpoint is not on cargo's path. Meanwhile GitHub release downloads are blocked, so **Option A (mirroring release binaries) would not work in this environment** without committing binaries to this repo.

→ **Recommendation for Phase 2:** build the cloud setup script on `cargo install --locked` with pinned versions, and drop `toolchain-mirror.yml` from the plan. Caveats to handle when writing it: `CARGO_HTTP_CAINFO=/root/.ccr/ca-bundle.crt` was needed for TLS through the proxy; several tools compiled together will take longer than one, so the ~5-minute setup-script budget must be measured, with the cache relied on for subsequent sessions. Whether `rojo`, `wally`, `selene`, `lune` and `luau-lsp` all publish installable crates still needs checking in Phase 2 — if any does not, that specific tool falls back to a committed binary.

**Still unknown (needs Philip):** whether the environment allowlist he configures matches what this session observed, and whether an `apis.roblox.com` API credential is available on his plan.
