# ECONOMY.md — Numbers, pacing and the simulator

Phase 1.1. All numbers produced by `tools/simulate-economy/` on 2026-09-16 and reproducible with:

```bash
cd tools/simulate-economy
python3 simulate.py --trials 25   # pacing tables below
python3 tune.py                   # re-derive the rebirth constants
```

`config.py` is the source of truth and maps 1:1 onto `src/shared/Config/Economy.luau`. **Tune here first, copy across second.** Re-run `tune.py` after any change to income, egg pricing or fusion.

---

## 1. Pacing — all four brief targets met

| Archetype | Session | First hatch | First fusion | 1st rebirth | 5th rebirth | 10th rebirth | Rebirths in 28d |
|---|---|---|---|---|---|---|---|
| casual | 15 min/day | 5 s | 1.4 min | **30.0 min** | 2.5 h (day 10) | **4.5 h (day 18)** | 14 |
| regular | 45 min/day | 5 s | 1.4 min | 43.8 min | 3.8 h (day 5) | 7.5 h (day 10) | 27 |
| heavy | 120 min/day | 5 s | 1.4 min | 43.8 min | 6.0 h (day 3) | 14.0 h (day 7) | 33 |

| Target (brief §7.6) | Result |
|---|---|
| First hatch ≤ 15 s | ✅ 5 s |
| First fusion ≤ 3 min | ✅ 1.4 min |
| First rebirth 25–40 min | ✅ 30.0 min |
| 10th rebirth in 2–3 weeks casual | ✅ day 18 |

Times are **playtime**, median of 25 seeded runs.

⚠️ **One honest caveat.** For a casual player, rebirth times snap to session boundaries: 30 min of playtime *is* the start of day 3. The offline grant (2 h at 25% = 30 min of income) is worth **twice** a casual session, so it, not the last few minutes of play, is what tips them over the line. That is good for retention — logging in is always rewarded — but it means "first rebirth at 30 minutes" is really "first rebirth when they open the app on day 3." Design the rebirth celebration to fire well, on a **session start**, not mid-session.

---

## 2. Egg reference

| Egg | Unlock | Base price | Hatch | Expected coins/s | Payback at unlock |
|---|---|---|---|---|---|
| Basic | rebirth 0 | 25 | 10 s | 4.2 | 6 s |
| Picnic | rebirth 1 | 1,200 | 30 s | 7.5 | 2.7 min |
| Bakery | rebirth 2 | 60,000 | 75 s | 15.0 | 1.1 h |
| Sushi Bar | rebirth 4 | 3,500,000 | 150 s | 39.0 | 24.9 h |
| Candy Cloud | rebirth 6 | 250,000,000 | 300 s | 112.5 | 25.7 d |
| Cosmic Diner | rebirth 8 | 40,000,000,000 | 600 s | 344.2 | 3.7 y |

Payback looks absurd at the top tiers only because it is measured against a *single* Nomling's base income with no rebirth multiplier. In practice the multiplier is `2.6^rebirths`, which at rebirth 8 is ~2,800×.

**Egg prices scale with rebirth count:** `price = base × 2.9^rebirths`. This is not cosmetic — see §5.

Every odds table sums to exactly **1,000,000 ppm**, asserted in `config.validate()` and again by a CI unit test (brief §5.2).

---

## 3. Tuned constants

| Constant | Value | Why |
|---|---|---|
| `REBIRTH_COST(n)` | `1,900,000 × 2.5ⁿ` | Grid-searched. Lands both pacing targets mid-window. |
| `REBIRTH_MULT(n)` | `2.6ⁿ` | Slightly below cost growth, so rebirths stay meaningful. |
| `EGG_PRICE_REBIRTH_SCALE` | `2.9` | The dominant coin sink. See §5. |
| `FUSION_SLOTS_BASE` | **1** | The main throttle on income growth. See §4. |
| `FUSION_INCOME_FACTOR` | 1.3 | From the brief. |
| `FUSION_GEN_BONUS` | gen2 ×1.0, gen3 ×1.6 | |
| Average weather uplift | **×1.220** | 90 s events every 12–20 min, EV multiplier 3.35 → +22% long-run income, free. |
| `MUTATION_CHANCE_PER_EVENT` | 0.06 per Nomling per weather event | |
| Offline | 25%, capped 2 h (4 h VIP) | From the brief. |

---

## 4. Two design bugs the simulator caught

These are the reason to build the simulator before the game, not after.

### 4.1 Rebirth was a dead end

Rebirth resets coins **and** all base Nomlings. With both at zero, income is zero, so the player can never afford another egg — **permanently stuck, one minute into the reward for their first half-hour.**

The brief (§4.5 I) lists what rebirth resets and grants, and a free restart egg is not among them. It has to be.

> **Fix, now in config:** `REBIRTH_GRANTS_FREE_EGG = True`. Every rebirth hands over one free egg of the best tier the player has unlocked, already incubating, so the new run starts the same way the game does.

This must be covered by a test — it is exactly the kind of bug that is invisible in a 10-minute playtest and fatal in a retention curve.

### 4.2 Fusion was an infinite upgrade treadmill

The first model let any number of fusions run at once. Because a fusion always returns `(A + B) × 1.3`, strictly better than either parent, income compounded geometrically with every hatch. Result: identical pacing for casual, regular and heavy players — the economy had no throttle at all.

> **Fix:** `FUSION_SLOTS_BASE = 1`. The Fusion Lab takes one pair at a time. Overflow Nomlings wait in inventory as fodder.

This also retro-justifies a monetization item: `fusionPro` sells a **second** fusion slot (brief §5.3), which is now measurably the strongest non-currency purchase in the game. Worth watching that it does not become mandatory — see `docs/MONETIZATION.md`.

---

## 5. Why egg prices scale with rebirths

With flat egg prices, the first tuned build produced:

| | Flat egg prices | Scaled egg prices |
|---|---|---|
| Heavy player, rebirths in 28 days | **220** | **33** |
| Eggs as a share of coins earned | 4.3% | 46.6% |

At 220 rebirths the multiplier is `2.6^220` — the progression curve inverts, each rebirth becomes cheaper in real terms than the last, and the game turns into a rebirth button. Scaling egg prices by `2.9^rebirths` restores the shop as the primary sink and keeps a heavy player climbing steadily instead of spiralling.

**Coin sources and sinks (casual, 28 days):**

| Flow | Share of earnings |
|---|---|
| Sink: eggs | 46.6% |
| Sink: rebirths | 17.2% |
| Sink: base upgrades | 0.0% |
| **Total sunk** | **63.8%** |
| Unspent float | 36.2% |

---

## 6. Known tuning debt

Carry these into Phase 4 (M2), where the brief already schedules a simulator re-run.

1. **Base upgrades are free.** Pedestal and incubator upgrades absorb **0.0%** of earnings, so every player maxes 16 pedestals and 4 incubators within moments of each rebirth. That deletes a progression beat inside each cycle.
   → *Proposed fix:* scale upgrade costs with rebirths as eggs do, and re-run `tune.py`. Not done now because it shifts pacing and the pacing targets are currently met; changing both at once would muddy the result.
2. **36% unspent float.** Acceptable, but it says late-game players bank coins with nothing to want. The Fusion Book completion rewards and cosmetic sinks should soak this up — neither is modelled yet.
3. **Snatching is not modelled at all.** It moves Nomlings between players rather than creating or destroying them, so it is roughly economy-neutral in aggregate — but it is *not* neutral for an individual, and the Comeback Egg is a coin source. Model it once the fair-play rules are implemented.
4. **No monetization in the model.** `coins2x`, `coinPack*` and `luck*` all bend these curves. The revenue model in `docs/MONETIZATION.md` is built on separate assumptions and the two are not yet reconciled.
5. **The behaviour policy is greedy, not optimal.** Players buy the best egg they can afford and fuse their two best spares. Real players hoard, misplay, and chase rarities. Treat the pacing numbers as a centre of mass, not a promise.

---

## 7. How the simulator works

`simulate.py` steps one simulated second at a time through a player's session, applying a simple greedy policy:

1. Accrue income, applying rebirth multiplier and the average weather uplift.
2. Resolve finished hatches; place the Nomling, or bench it to inventory if the base is full and it is not an upgrade.
3. Resolve finished fusions; the child competes for a pedestal.
4. Feed the Fusion Lab if a slot is free and there is fodder.
5. Rebirth if affordable.
6. Buy capacity upgrades while cheap, then the best affordable egg.
7. Roll mutations on each weather event.

Between days it applies capped offline earnings. It runs 28 days because that matches the D1 / D2–7 / D8–28 windows Roblox ranks on (see `docs/VERIFY.md` §3.2).

It is a **behaviour** model, not a spreadsheet: pacing reflects what a player does, not what an optimiser could extract. `tune.py` grid-searches the rebirth constants against the brief's targets plus a sanity constraint that a heavy 28-day player should still be climbing.
