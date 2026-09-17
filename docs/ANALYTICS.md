# ANALYTICS.md — Events, funnels and KPIs

Phase 1.1. What we log, how it is named, and what Philip checks weekly.

---

## 1. Naming rules

- `snake_case`, `noun_verb` past tense: `egg_hatched`, `fusion_completed`, `offer_shown`.
- **Never** put identifying content in an event. No names, no free text, no chat. `UserId` only, and only where Roblox already has it.
- Every event carries the standard context block below; event-specific fields are additive.
- **Never rename a live event.** Add a new one and deprecate the old, or the history breaks.
- A new event needs a row in this file in the same PR. An event not documented here does not ship.

**Standard context on every event:**

```
{ rebirths, session_seconds, ftue_complete, is_payer, plus_subscriber,
  pri_restricted, ads_eligible, platform, server_players }
```

`pri_restricted` and `ads_eligible` come from the Compliance service's cached `PolicyService` info and power the compliance KPIs in §5.

---

## 1b. What is actually wired, as of 2026-09-17

This file is the spec, and the spec has always been larger than the build. This
section is the honest half: what exists in code today.

**Implemented:** `src/server/Services/AnalyticsService.luau`, with the funnel
logic split into the pure, Lune-tested `src/shared/Logic/Funnel.luau`.

| Live | Event |
|---|---|
| ✅ | the full 7-step onboarding funnel |
| ✅ | `egg_bought`, `egg_hatched`, `nomling_placed` |
| ✅ | `fusion_started`, `fusion_completed`, `world_first_claimed` |
| ✅ | `snatch_succeeded`, `rebirth` |
| ✅ | `coins_source` / `coins_sink` (offline, egg, belt, rebirth) |
| ✅ | `snatch_attempted` (with `blocked_reason`), `gate_raised` |
| ⬜ | `weather_started`, `mutation_gained`, `snatch_defended` |
| ⬜ | everything under §4 monetisation — the features do not exist yet (M3) |

**Three properties the funnel guarantees**, each tested in
`tests/unit/funnel.spec.luau` because each is a bug that would otherwise surface
as inexplicable data months later: a step fires **once ever**, steps fire **in
order** even when a player leaps several beats in one action, and a **rejoin
does not re-enter the funnel at the top**. Progress lives in the profile
(`data.funnel`), not in memory.

**Analytics never breaks the game.** Every Roblox call is wrapped; a telemetry
outage costs a data point and nothing else. Warnings are once per event name,
because a broken event fires as often as the thing it measures.

**Custom fields are capped at 3 and sorted** before truncation, so which three
survive is deterministic rather than dependent on Luau's undefined table order —
otherwise two servers would report different fields for the same event. Values
are buckets and keys, never quantities: Roblox limits how many *distinct* values
a field may have, and a raw coin amount would exhaust that within an hour. The
amount goes through the numeric `value` argument instead.

---

## 2. Onboarding funnel

The most important instrumentation in the project. Phase 0 confirmed **first-play bounce rate** (`<60 s` and `61–180 s`) is one of the most heavily weighted discovery signals, and that "qualified play sessions" filter out quick bounces.

Logged via `AnalyticsService` onboarding funnel, one step per FTUE beat (`docs/GDD.md` §4):

| Step | Event | Target time |
|---|---|---|
| 1 | `ftue_spawned` | 0 s |
| 2 | `ftue_first_hatch` | 5 s |
| 3 | `ftue_first_placed` | 30 s |
| 4 | `ftue_first_collect` | 45 s |
| 5 | `ftue_second_egg_bought` | 60 s |
| 6 | `ftue_first_fusion_started` | 90 s |
| 7 | `ftue_first_fusion_revealed` | 120 s |
| 8 | `ftue_first_weather` | 3–5 min |
| 9 | `ftue_sneaky_sam_bubbled` | 4–5 min |
| 10 | `ftue_complete` | 8 min |

**The number to watch is step-to-step drop-off, not the total.** A cliff between two consecutive steps points at one specific interaction. Steps 3 and 6 are the likeliest suspects — "walk somewhere and place a thing" and "open a menu and pick two things" are the only moments we ask for real navigation on a touch screen.

---

## 3. Core gameplay events

| Event | Fields |
|---|---|
| `egg_bought` | `egg_tier`, `price_coins`, `source` (market/comeback/free/rebirth) |
| `egg_hatched` | `egg_tier`, `rarity`, `hatch_seconds`, `was_skipped` |
| `nomling_placed` | `rarity`, `gen`, `mutation`, `pedestal_index`, `is_vault` |
| `coins_collected` | `amount`, `seconds_since_last` |
| `fusion_started` | `parent_a_rarity`, `parent_b_rarity`, `same_tier`, `duration_seconds` |
| `fusion_completed` | `result_rarity`, `result_gen`, `tier_upgraded`, `mutation_inherited`, `combo_key` |
| `world_first_claimed` | `combo_key`, `first_type` (species/mutation) |
| `fusion_book_milestone` | `entries_discovered`, `milestone` |
| `weather_started` | `weather_type`, `multiplier` |
| `mutation_gained` | `mutation`, `rarity`, `gen` |
| `snatch_attempted` | `blocked_reason` (nil/shield/income_ratio/cooldown/gate/vault) |
| `snatch_succeeded` | `rarity`, `carry_seconds` |
| `snatch_defended` | `method` (bubble/gate/timeout) |
| `gate_raised` | `base_index` |
| `comeback_egg_granted` | `egg_tier` |
| `rebirth` | `rebirth_number`, `playtime_seconds`, `coins_at_rebirth` |
| `quest_completed` | `quest_id`, `quest_type` |
| `daily_claimed` | `day_index`, `used_grace` |
| `invite_sent` / `invite_accepted` | `-` / `referrer_present` |
| `code_redeemed` | `code` |

**`gate_raised` answers whether the Laser Gate is a real decision or a reflex.** The Gate is up 60 s in every 90 (D-025), so a player who simply mashes it whenever it is ready will show a raise rate near the cap with no correlation to `snatch_attempted` on their base. If that is what the data says, the cooldown is doing the deciding rather than the player, and the numbers need to change.

**`snatch_attempted` with `blocked_reason` is deliberately logged on failure.** The fair-play rules are guesses; this is the only way to learn whether they protect people or just frustrate them. A high `income_ratio` block rate means the servers are badly matched, not that the rule works.

---

## 4. Shop funnel and economy flow

| Event | Fields |
|---|---|
| `offer_shown` | `item_key`, `placement`, `trigger`, `was_unsolicited` |
| `offer_clicked` | `item_key`, `placement` |
| `offer_purchased` | `item_key`, `price_robux`, `placement`, `is_gift` |
| `offer_dismissed` | `item_key`, `placement`, `seconds_visible` |
| `purchase_failed` | `item_key`, `reason` |
| `ad_button_shown` / `ad_watched` | `placement` / `placement`, `reward_key` |
| `plus_prompt_shown` / `plus_subscribed` | `placement` |

**Economy sources and sinks** — every coin created or destroyed, so `docs/ECONOMY.md` can be checked against reality:

| Event | Fields |
|---|---|
| `coins_source` | `source` (income/offline/quest/daily/code/comeback/coinpack), `amount` |
| `coins_sink` | `sink` (egg/upgrade/rebirth), `amount` |

`was_unsolicited` on `offer_shown` is the audit trail for brief §5.1 rule 4. If it ever exceeds one per session, that is a bug and a compliance failure, and this field is how we find out.

---

## 5. KPIs — Philip's weekly phone review

Checked in Creator Hub. Anything in the top block that moves the wrong way for two weeks running is the next sprint.

| Area | Metric | Where |
|---|---|---|
| **Discovery** | Impressions, play-through rate | Analytics → Acquisition → Home Recommendations |
| **Discovery** | First-play bounce `<60 s` and `61–180 s` | same |
| **Discovery** | Play days per user (D1, D2–7, D8–28) | same |
| **Discovery** | Playtime per user (capped 60 min/day) | same |
| **Discovery** | Intentional co-play days, qualified play sessions | same |
| **FTUE** | Step-to-step drop-off | Analytics → Funnels |
| **Engagement** | Session length, play days per week | Analytics → Engagement |
| **Retention** | D1 / D7 / D30 vs benchmark games | Analytics → Retention |
| **Monetization** | Payer conversion, ARPPU, ARPDAU, spend days, product mix | Analytics → Monetization |
| **Monetization** | Starter Pack conversion | our own funnel |
| **Social** | Invites sent/accepted, private servers | our events |
| **Economy** | Coin sources vs sinks; time to first fusion and first rebirth | our events |
| **Compliance** | Share of players `pri_restricted` and `ads_eligible` | our context block |

### Reading discovery numbers without being misled

⚠️ **Roblox's ranking signals count only users who joined organically from Recommended for You.** Engagement from ads, friends, search and social media is excluded from ranking (`docs/VERIFY.md` §3.2).

So during the M5 push — when most traffic is invited friends, Discord and sponsored ads — **the Home Recommendations dashboard will look flat, and that is expected, not a failure.** Two separate scoreboards:

| Goal | Scoreboard |
|---|---|
| Kids/Select eligibility (250 highly engaged plays) | **Audience Reach** dashboard |
| Home-page ranking | **Home Recommendations** signals, organic cohort only |

Judging the launch by the wrong one leads to exactly the wrong conclusion.

### Benchmarks

Creator Hub shows benchmark games. They do **not** affect the algorithm — they are a comparison aid only. Use them to spot which signal is weakest, not as a target.

---

## 6. Weekly report

A workflow (or Claude Code routine) writes `docs/reports/kpi-YYYY-WW.md`: the table above, week-over-week deltas, the three biggest movers, and a suggested focus. Philip reads it on his phone; the raw dashboards stay the source of truth.
