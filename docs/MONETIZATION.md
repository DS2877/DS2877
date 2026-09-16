# MONETIZATION.md

Phase 1.1. Catalog, the currency firewall, offer placement and frequency caps, and the revenue model.

Compliance rules that constrain everything here are in `docs/COMPLIANCE.md`; the platform facts they rest on are verified in `docs/VERIFY.md` §3.3–3.4.

---

## 1. Non-negotiable rules

1. **Fun first.** Nothing needed to enjoy the core loop is behind a paywall.
2. **No bought advantage for stealing.** Robux never buys a permanent snatching advantage — no speed, no strength, no carry-time. Defensive perks are fine. (A game where paying players rob non-paying children is not a game we ship.)
3. **Show real prices.** Always fetch from `MarketplaceService` at runtime. Roblox's own docs warn: *"If you hard-code prices, your in-game UI might display incorrect pricing to Plus subscribers."* Regional Pricing, Price Optimization and Plus discounts all depend on this.
4. **No manipulative timing.** No offer after a loss or failure; no fake timers or fake scarcity; at most **one unsolicited offer per session**; never interrupt a reveal.
5. **Bonded items.** Anything bought with Robux cannot be snatched or traded.
6. **Catalog as code.** `monetization/catalog.json` is the source of truth, syncs to Roblox via Open Cloud, and generates `src/shared/Generated/CatalogIds.luau`.

---

## 2. The currency firewall

**Coins are the only currency.** Eggs and fusions cost coins.

Every catalog item carries a risk tier:

| Tier | Covers | Examples |
|---|---|---|
| **1 — odds / currency** | sells coins, or changes odds | `coinPackS/M/L`, `luckyPaws`, `luck15` |
| **2 — currency multipliers** | multiplies coin income | `coins2x` |
| **3 — indirect / deterministic** | everything else | slots, timer speed, vault, offline cap, cosmetics, server boosts |

### For players with `ArePaidRandomItemsRestricted = true`

**Hide all Tier 1 and Tier 2 items**, and ignore those effects even if already owned (a player can travel).

**Why this works, now verified.** Roblox's policy binds on random items bought with Robux *or with in-game currency purchasable with Robux*. If a restricted player can never buy coins, their coins are wholly earned — so eggs and fusion become "an unpaid, earnable path to acquiring the random item", which is the **first** of the six treatments Roblox lists. Full quote and the other five treatments in `docs/VERIFY.md` §3.4.

**Two honest notes:**
- Hiding **Tier 2** is *stricter than required*. A coin multiplier is not a currency purchase. We do it anyway because the cost is small and the argument becomes airtight. **This is our choice, not a Roblox rule** — record it as such.
- ⚠️ **Unresolved:** Tier 3 items that indirectly accelerate random outcomes (`turboIncubators`, `fusionPro`, `skipHatch*`, `skipFusion*`). They buy *time*, not odds and not currency, so our reading is that they sit outside the PRI definition. This needs a `compliance-reviewer` pass in Phase 5 and, if still unclear, a DevForum question before launch. It is the single largest open compliance question in the project.

### For everyone
- Odds are shown for eggs, fusions and weather, and **update live** whenever a luck effect is active.
- Server-wide boosts sold for Robux must be **deterministic** and must never touch coins or odds — that is what makes them safe to apply to every player in the server, including restricted ones.

### CI enforcement
- Every item has a tier.
- Every Tier 1 item that changes odds carries odds metadata.
- Every odds table sums to exactly **1,000,000 ppm**.
- No Tier 1 or Tier 2 item is reachable from a code path that ignores the policy check.

---

## 3. Catalog v1

Prices are **starting points**, to be validated with Price Optimization and Experiments. Regional Pricing on.

### Game passes

| Key | Name | Effect | Price | Tier |
|---|---|---|---|---|
| `vip` | Nom Club VIP | +1 Vault slot, offline cap 2 h → 4 h, VIP skin and name tag, VIP lounge, daily gift of 2 hatch skips | 249 | 3 |
| `coins2x` | 2× Coins | Doubles coin income | 399 | 2 |
| `biggerBase` | Bigger Base | +6 pedestals | 199 | 3 |
| `turboIncubators` | Turbo Incubators | Hatching 40% faster, +1 incubator | 179 | 3 |
| `fusionPro` | Fusion Lab Pro | Second fusion slot, fusions 30% faster | 249 | 3 |
| `vaultPlus` | Vault+ | +2 Vault slots | 149 | 3 |
| `autoCollect` | Auto-Collect | Coins collected automatically | 129 | 3 |
| `luckyPaws` | Lucky Paws | Permanent +25% luck, live odds shown | 349 | 1 |
| `creatorKit` | Creator Kit | Photo filters, poses, backdrops | 79 | 3 |

⚠️ **Watch `fusionPro` closely.** The economy simulator showed the single fusion slot is the main throttle on income growth (`docs/ECONOMY.md` §4.2), which makes a second slot the most mechanically powerful purchase in the game. That is acceptable — it buys *throughput*, not odds — but if playtests show the game feels bad without it, the base game needs a second slot at some rebirth milestone and `fusionPro` needs a different benefit. Re-check at M3.

### Developer products

| Key | Effect | Price | Tier |
|---|---|---|---|
| `starterPack` | One-time: exclusive Bonded Nomling "Sprinkle Sprout" + 5 hatch skips | 49 | 3 |
| `skipHatchS/M/L` | Finish one egg now (bucketed by remaining time) | 15 / 29 / 49 | 3 |
| `skipAll` | Finish all incubators now | 79 | 3 |
| `skipFusionS/L` | Finish a fusion now | 29 / 59 | 3 |
| `serverHatchRush` | Server-wide: hatch timers ×0.5 for 10 min; buyer thanked in a banner | 99 | 3 |
| `serverFusionFrenzy` | Server-wide: fusion timers ×0.5 for 10 min | 99 | 3 |
| `serverDisco` | Server-wide: party lights + dance emote, 5 min (cosmetic) | 49 | 3 |
| `coinPackS/M/L` | Coins equal to 30 min / 3 h / 12 h of current income | 49 / 199 / 599 | 1 |
| `luck15` | Personal +100% luck for 15 min, live odds shown | 59 | 1 |
| `exclusive_<season>` | Direct purchase of a named Bonded Nomling, stats shown first | 199–499 | 3 |
| `gift_<key>` | Gift version, for a player in the same server | same | same |
| `adReward_skip` | Rewarded-video reward (free hatch skip); off until eligible | — | 3 |

**`exclusive_*` is also our PRI safety valve.** Roblox's third listed treatment is "offering the specific outcomes for direct, guaranteed purchase, priced on expected value." Selling named Nomlings outright gives restricted players a real way to get a great creature without any randomness.

### Other revenue

- **Gifts.** A game pass cannot be transferred, so gifted passes are in-game **entitlements**. A player owns a perk if they own the pass **or** hold a gifted entitlement. One code path, `Shop:hasPerk(player, key)`.
- **Private servers — 99 R$/month**, with Chill Mode.
  - ⚠️ **Set the price once and never change it.** Verified: changing it **cancels every active subscription**.
  - ⚠️ Under-13 players may be unable to join private servers at all, depending on parental settings. Our core audience is 9–15, so this is a small revenue line, not a pillar.
- **Roblox Plus prompt.** Shown in the private-server panel and VIP lounge ("Plus members get free private servers"). Non-subscribers only, at most once per day. Check `Player.HasRobloxSubscription` first; confirm server-side via `GetPropertyChangedSignal` before granting anything. Worth **250 R$/month for three months, up to 750 R$ per subscriber**.
- **Rewarded video** — once eligible (2,000+ unique monthly visitors, 13+ ID-verified creator, questionnaire approved, no free-form creation). Voluntary button only, daily cap, hidden when `GetAdAvailabilityNowAsync` says no. Reward sized at **3–10 Robux of value**, per Roblox's own recommendation.
- **Season Pass** — Update 2, premium track 399 R$.

---

## 4. Offer placement and frequency

| Offer | Where | Trigger | Cap |
|---|---|---|---|
| Shop | Persistent button, always one tap away | player-initiated | none |
| `starterPack` | Full-screen card | after **first fusion** AND ≥5 min played | once ever; re-shown once at 24 h if dismissed |
| `skipHatch*` | Small button beside an incubator | only while that timer runs | contextual only |
| `skipFusion*` | Small button beside the fusion timer | only while a fusion runs | contextual only |
| `skipAll` | Beside the "Kitchen's cooking" panel | only when all incubators busy | contextual only |
| `coins2x`, `biggerBase` | Shop; contextual hint when pedestals full | player-initiated | 1 hint/session |
| `fusionPro` | Shop; hint when a second pair is waiting | player-initiated | 1 hint/session |
| Server boosts | Plaza event board | player-initiated | none |
| Plus prompt | Private-server panel, VIP lounge | non-subscribers only | 1/day |
| Rewarded video | Shop, opt-in button | availability check passes | daily cap, config |

**The one unsolicited offer per session is the Starter Pack**, and only after the player has had the core experience. Everything else is either player-initiated or attached to a timer the player created.

**Never:** after a snatch loss, during any reveal, during the FTUE before 5 minutes, or on the death/failure of anything.

---

## 5. Revenue model

Run `python3 tools/revenue-model/model.py`. Output: `docs/reports/revenue-scenarios.csv`.

| Line | 1k DAU | 10k DAU | 100k DAU |
|---|---|---|---|
| Paying users | 30 | 300 | 3,000 |
| Player spend (R$) | 18,000 | 180,000 | 1,800,000 |
| — our 70% share (R$) | 12,600 | 126,000 | 1,260,000 |
| Daily Engagement (R$) | 2,700 | 27,000 | 270,000 |
| Plus sign-ups (R$) | 375 | 3,750 | 37,500 |
| Plus private servers (R$) | 80 | 800 | 8,000 |
| Paid private servers (R$) | 139 | 1,386 | 13,860 |
| Rewarded video (R$) | 146 | 1,458 | 14,580 |
| **Total earned Robux** | **16,039** | **160,394** | **1,603,940** |
| Audience Expansion (USD) | $50 | $504 | $5,040 |
| **Total USD / month** | **$111** | **$1,113** | **$11,135** |

Direct player spend is ~79% of Robux earned; Creator Rewards Daily Engagement is ~17%. DevEx minimum cash-out is 30,000 earned Robux ($114), reached in about **1.9 months at 1k DAU** and under a week at 10k.

### How to read this

**Every assumption is labelled low or medium confidence and none of them is data.** The full table is printed by the script. The load-bearing guesses are payer conversion (3%), ARPPU (600 R$/month), and the share of Active Spenders for whom we are a top-three game (15%).

**Three known weaknesses, stated plainly:**
1. **The model is linear in DAU**, so USD per DAU is identical at 1k and 100k ($0.111). Reality is not linear — bigger games get better discovery, more co-play and a different spend mix. Treat the 100k column as a shape, not a number.
2. **Audience Expansion is nearly worthless to us early.** It requires a 100+ DAU average sustained for 60 days. Do not put it in any plan that depends on launch income.
3. **It does not interact with `docs/ECONOMY.md`.** `coins2x`, `coinPack*` and `luck*` all bend the pacing curves, and that reconciliation has not been done. Flagged in both documents.

### First experiments

Run via Roblox Experiments plus live config, one at a time, each for at least two weeks:

1. **Starter Pack timing** — after first fusion (control) vs after first rebirth. Measures whether earlier conversion costs retention.
2. **`coins2x` price** — 399 (control) vs 299 vs 499. The highest-volume pass; worth knowing its curve.
3. **Shop layout** — categorised (control) vs a single recommended item. Phone screens are small; fewer choices may convert better.
