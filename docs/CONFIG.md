# CONFIG.md — Live config reference

Phase 1.1. Every key that can be changed without a code deploy.

**Contract:** typed defaults live in code (`src/shared/Config/`). Live config is an *override*, fetched at boot and refreshable. **If live config fails to load, the game runs normally on defaults.** A missing or malformed key falls back to its default and logs a warning — it never crashes a server and never blocks a join.

**Never publish live config without Philip's explicit OK** (brief §11.3).

Defaults file: `config/live.defaults.json`. Push with `tools/push-config`.

---

## Reading the tables

| Column | Meaning |
|---|---|
| Key | Dot path in the config JSON |
| Default | Value shipped in code |
| Range | Values that are safe to set live |
| Risk | 🟢 safe · 🟡 changes pacing · 🔴 economy-affecting, needs a simulator re-run |

---

## economy.*

| Key | Default | Range | Risk |
|---|---|---|---|
| `economy.rebirthCostBase` | 1900000 | 1e6–5e6 | 🔴 |
| `economy.rebirthCostGrowth` | 2.5 | 2.0–3.5 | 🔴 |
| `economy.rebirthMultBase` | 2.6 | 2.0–3.5 | 🔴 |
| `economy.eggPriceRebirthScale` | 2.9 | 2.0–4.0 | 🔴 |
| `economy.offlineEfficiency` | 0.25 | 0–0.5 | 🟡 |
| `economy.offlineCapSeconds` | 7200 | 1800–14400 | 🟡 |
| `economy.offlineCapSecondsVip` | 14400 | 3600–28800 | 🟡 |
| `economy.friendBonusPerFriend` | 0.10 | 0–0.25 | 🟡 |
| `economy.friendBonusCap` | 0.30 | 0–1.0 | 🟡 |

🔴 **Any change here invalidates `docs/ECONOMY.md`.** Re-run `tools/simulate-economy/tune.py` before shipping it.

## eggs.*

| Key | Default | Range | Risk |
|---|---|---|---|
| `eggs.restockSeconds` | 300 | 120–900 | 🟡 |
| `eggs.goldenEggCycleChance` | 0.05 | 0–0.25 | 🟡 |
| `eggs.<tier>.price` | see ECONOMY.md | — | 🔴 |
| `eggs.<tier>.hatchSeconds` | see ECONOMY.md | — | 🟡 |
| `eggs.<tier>.odds.<rarity>` | see ECONOMY.md | ppm | 🔴 |

🔴 **Odds are special.** The server rejects any odds table that does not sum to exactly **1,000,000 ppm** and keeps the previous values. This is a legal requirement, not a balance one (`docs/COMPLIANCE.md` §2) — a live-config typo must never be able to publish odds that do not total 100%.

## fusion.*

| Key | Default | Range | Risk |
|---|---|---|---|
| `fusion.slotsBase` | 1 | 1–2 | 🔴 |
| `fusion.incomeFactor` | 1.3 | 1.0–2.0 | 🔴 |
| `fusion.genBonus.gen3` | 1.6 | 1.0–3.0 | 🔴 |
| `fusion.upgradeChanceSameTier` | 0.12 | 0–0.3 | 🔴 |
| `fusion.upgradeChanceDiffTier` | 0.05 | 0–0.3 | 🔴 |
| `fusion.mutationInheritChance` | 0.35 | 0–1.0 | 🟡 |
| `fusion.seconds.<tier>` | see ECONOMY.md | — | 🟡 |
| `fusion.maxGen` | 3 | 2–3 | 🔴 |

🔴 `fusion.slotsBase` is the main throttle on the whole economy (`docs/ECONOMY.md` §4.2). Treat a change to it as a release, not a config tweak.
🔴 The two `upgradeChance` values are **disclosed odds**. Changing them changes what players were shown. The odds panel reads the same config, so it stays truthful automatically — but never change them mid-event.

## weather.*

| Key | Default | Range | Risk |
|---|---|---|---|
| `weather.intervalMinSeconds` | 720 | 300–1800 | 🟡 |
| `weather.intervalMaxSeconds` | 1200 | 600–2400 | 🟡 |
| `weather.durationSeconds` | 90 | 30–300 | 🟡 |
| `weather.announceLeadSeconds` | 30 | 10–60 | 🟢 |
| `weather.<type>.multiplier` | 2–10 | 1–20 | 🔴 |
| `weather.<type>.weight` | see ECONOMY.md | — | 🟡 |
| `weather.mutationChancePerEvent` | 0.06 | 0–0.25 | 🔴 |
| `weather.nomStormActive` | false | bool | 🟡 |
| `weather.nomStormMutationMult` | 3.0 | 1–10 | 🟡 |

## snatch.*

| Key | Default | Range | Risk |
|---|---|---|---|
| `snatch.holdSeconds` | 1.5 | 0.5–4 | 🟢 |
| `snatch.carrySlowdown` | 0.30 | 0–0.5 | 🟢 |
| `snatch.carryTimeoutSeconds` | 40 | 15–120 | 🟢 |
| `snatch.bubbleSeconds` | 2 | 1–5 | 🟢 |
| `snatch.bubbleCooldownSeconds` | 3 | 1–10 | 🟢 |
| `snatch.bubbleImmunitySeconds` | 3 | 1–10 | 🟢 |
| `snatch.gateLockSeconds` | 60 | 15–180 | 🟢 |
| `snatch.gateCooldownSeconds` | 90 | 30–300 | 🟢 |
| `snatch.newcomerShieldSeconds` | 1200 | 0–7200 | 🟡 |
| `snatch.minIncomeRatio` | 0.20 | 0–1.0 | 🟡 |
| `snatch.perTargetCooldownSeconds` | 60 | 10–300 | 🟡 |
| `snatch.comebackEggEnabled` | true | bool | 🟡 |

**These are the fairness dials.** If playtests show snatching feels bad, the correct move is always to weaken it — raise shields and cooldowns, lower `minIncomeRatio` exposure. Never strengthen snatching to make it "more exciting" (`docs/GDD.md` §5.8).

## shop.*

| Key | Default | Range | Risk |
|---|---|---|---|
| `shop.starterPackMinMinutes` | 5 | 3–30 | 🟡 |
| `shop.starterPackRequiresFirstFusion` | true | bool | 🔴 |
| `shop.maxUnsolicitedOffersPerSession` | 1 | 0–1 | 🔴 |
| `shop.plusPromptPerDay` | 1 | 0–2 | 🟡 |
| `shop.adRewardDailyCap` | 5 | 0–20 | 🟡 |
| `shop.adsEnabled` | false | bool | 🟡 |

🔴 The first three encode brief §5.1 rule 4. **`maxUnsolicitedOffersPerSession` must never exceed 1** — the server clamps it regardless of config.

## events.*, codes.*, admin.*

| Key | Default | Risk |
|---|---|---|
| `events.globalEventActive` | false | 🟡 |
| `events.globalEventType` | `""` | 🟡 |
| `events.bannerText` | `""` | 🟢 |
| `codes.<code>.reward` | — | 🟡 |
| `codes.<code>.expiresAt` | — | 🟢 |
| `codes.<code>.maxRedemptions` | — | 🟡 |
| `admin.allowlist` | `[]` (user IDs) | 🔴 |
| `admin.testToolsEnabled` | true in TEST, false in PROD | 🔴 |

🔴 `admin.allowlist` grants in-game admin powers. Treat it like a secret: changes reviewed, never a wildcard, PROD entries only for Philip.
🟢 `events.bannerText` is displayed to players — it is **not** localized and must be short, plain and safe.

## ui.*

| Key | Default | Risk |
|---|---|---|
| `ui.reducedMotionDefault` | false | 🟢 |
| `ui.ttsEnabledDefault` | true | 🟢 |
| `ui.revealSkippableAfterFirst` | true | 🟢 |
| `ui.showWeatherOddsPanel` | true | 🟢 |

---

## Rollout rules

1. Change TEST first, play it on a phone, then PROD.
2. **One 🔴 key at a time.** Two at once and you cannot attribute the result.
3. Every 🔴 change gets a line in `CHANGELOG.md` with before, after and why.
4. Keep the previous values to hand — rollback is re-publishing the old config (`docs/RUNBOOKS.md`).
5. Never change disclosed odds while an event is running.
