# GDD.md — Game design document

Phase 1.1. This document **resolves** the brief rather than repeating it. Where the brief left a choice open, the decision is here and logged in `docs/DECISIONS.md`. Where Phase 0/1 research contradicted the brief, the correction is marked ⚠️.

Companion documents: `docs/NOMLINGS.md` (roster, genome, names), `docs/ECONOMY.md` (numbers), `docs/MONETIZATION.md`, `docs/COMPLIANCE.md`, `docs/TECH.md`.

---

## 1. Positioning — what we are actually selling

⚠️ **The brief's differentiation claim does not survive research.** It says the game combines steal-and-defend with idle-grow "with a fusion twist that no current hit owns." As of 2026-09-16, **Steal An Egg is the most-played game on Roblox at ~1.7M concurrent players**, and it has: stealing eggs from other players' bases, hatching, pets that earn money per second, base upgrades, a **Fuse Machine**, and **seven income-multiplying mutations**. Full evidence in `docs/TITLES.md`.

So "we have fusion" cannot be the pitch. What is still genuinely ours:

| | The market | Fuse a Nomling |
|---|---|---|
| Creatures | A fixed index of hand-made pets | **Generated from a genome** |
| Fusion output | A higher tier of a pet that already exists | **A creature that has never existed, with a generated name** |
| Endgame social | Leaderboards | **World First — be the first player anywhere to make one** |

**The pitch is: the creatures are generated, not listed.** The emotional hook is the brief's own first pillar — *"What did I just make?!"*

Everything downstream follows from this:
- Eggs, stealing, mutations and idle income are **table stakes**. They must be as good as the leader's, and they are not selling points.
- The **fusion reveal** is the product. It gets the budget, the polish, the audio, the camera and the share button.
- Marketing never says "fuse your pets". It shows a creature nobody has seen and the words *"nobody has ever made this before."*

---

## 2. Pillars (unchanged from the brief, ranked)

1. **"What did I just make?!"** — every fusion is a surprise worth recording.
2. **Big numbers, fast** — growth visible every minute.
3. **Friendly chaos** — snatching is dramatic, never devastating.
4. **Bite-sized or binge** — 3 minutes and 30 minutes both feel complete.
5. **One-glance readable on a phone** — icons and motion before text; fully fun with zero chat.

When two pillars conflict, the lower number wins.

---

## 3. Core loop

```
buy egg → hatch (timer) → place on pedestal → collect coins
    ↘ fuse two Nomlings → public reveal → new creature ↗
weather mutates · snatch and defend · rebirth for a permanent multiplier
```

**Session anchors:** egg restock every 5 min (UTC-synced), hatch and fusion timers, a weather event every 12–20 min, daily rewards and quests, weekend Nom Storms.

---

## 4. First-time experience

The single most important 180 seconds in the project. Phase 0 confirmed **first-play bounce rate is one of the most important discovery signals**, measured at both `<60 s` and `61–180 s`, and that **"qualified play sessions"** explicitly filter out quick bounces.

| Time | Beat | Why |
|---|---|---|
| 0–5 s | Spawn on your own plot. A free egg is **already** hatching, 5 s countdown. | No menu, no choice, no reading. Something is already happening. |
| 5 s | **First reveal.** Rarity banner, confetti, the Nomling says its own name. | Delivers the core feeling before the player has decided whether to stay. |
| 5–30 s | Arrow to a pedestal. Place it. Coins start popping. | First verb, first number going up. |
| 30–60 s | First collect. Guided purchase of a second egg. | Teaches the loop's only two buttons. |
| 60–180 s | **"Fuse them!"** An 8-second fusion, then the first **public** reveal on the plaza screen. | The hook, landed inside the 180 s bounce window. |
| 3–5 min | Forced first weather event. Sneaky Sam steals once; you bubble him. | Teaches snatching as something you *survive*, not something done to you. |
| 5–8 min | Rebirth goal shown. Daily rewards introduced. Starter Pack offered — **only** after the first fusion *and* 5+ minutes. | First offer lands after value, never before. |
| ~15 min | Incubators busy → "Kitchen's cooking! Back in 12 min" → opt-in notification prompt. | A clean stopping point, and the one moment a notification ask is honest. |

**Hard rules for the FTUE:**
- The first fusion is **forced to be visually dramatic** — the two parents are chosen so the child looks obviously different from both. Never let a player's first fusion be a subtle one.
- The 8-second first fusion is a one-time FTUE value (`FUSION_FIRST_TIME_SECONDS`), not the real curve.
- No offer, no ad, no upsell of any kind before the 5-minute mark.
- Every beat emits an `AnalyticsService` funnel event (`docs/ANALYTICS.md`).

---

## 5. Systems

### 5.1 Server and plots
8 players, 8 plots around a central plaza. A plot exists only while its owner is in the server. Plaza holds the Egg Market, the Fusion Lab with a public reveal stage, four leaderboards, an event stage and a podium.

Each plot: **8 pedestals** (→16), **2 incubators** (→4), **1 Vault pedestal** (unsnatchable), a collect pad, a **Laser Gate** button, and an owner sign showing name and coins/s.

### 5.2 Eggs
Six tiers unlocked by rebirths — Basic, Picnic, Bakery, Sushi Bar, Candy Cloud, Cosmic Diner. Prices, hatch times and odds in `docs/ECONOMY.md`.

**Restock** every 5 minutes, synced to UTC via `cycleId = floor(unixTime / 300)` so every server agrees. Stock is **personal** — no queues, no contention at the counter. Basic is always in stock. A **Golden Egg** appears in ~5% of cycles and is announced server-wide.

**Odds** are on a button labelled **"Odds"** on every egg. Stored as integer ppm summing to exactly 1,000,000. Compliance detail in `docs/COMPLIANCE.md` — this is a legal requirement, not a UX choice.

**Rarity display is always colour + icon + text label**, never colour alone.

### 5.3 Hatching
5 s (first egg) to 10 min (Cosmic). Reveal is 2–3 s, skippable after the first time, and shows a rarity banner, tier-scaled confetti, and the Nomling saying its own generated name via `AudioTextToSpeech` with a seeded pitch. Falls back to sound effects when TTS is rate-limited — the fallback is the default assumption, not the exception.

### 5.4 Nomlings
Genome, inheritance, name generation and the model budget: **`docs/NOMLINGS.md`**.

Key constraints: ≤30 parts per creature, server replicates genomes only (never built models), and the same genome must build the same creature on every client forever.

### 5.5 Income
Base coins/s by rarity: 1 / 4 / 15 / 60 / 300 / 2,500 / 50,000.

Multipliers: mutation × generation × rebirth (`2.6^n`) × friends-in-server (+10% each, capped +30%) × passes × weather. All formulas live in pure engine-free modules so they are unit-testable.

**Offline:** 25% efficiency, capped 2 h (4 h with VIP). ⚠️ Note from `docs/ECONOMY.md`: this is worth **twice** a casual session, so it — not the end of a session — is what triggers most rebirths. Celebrate rebirth well on session start.

### 5.6 Fusion — the star

At the plaza Fusion Lab: pick two Nomlings (both consumed) → timer (30 s–20 min by tier) → **public reveal on the big screen** → the new Nomling flies to the owner's base.

⚠️ **One fusion slot in v1** (`FUSION_SLOTS_BASE = 1`). This is not a limitation to apologise for — it is the throttle that keeps the economy from collapsing (`docs/ECONOMY.md` §4.2) and the reason the reveal stays an event rather than background noise.

Inheritance: snack from A, animal from B, tier = higher parent with a **12%** upgrade chance if parents share a tier and **5%** otherwise, income `(A+B) × 1.3 × genBonus`, mutation inherited at 35%. Generations capped at 3; gen 3 creatures are Mega — bigger, with an aura and one of five affixes.

**Odds are shown before confirming**, to everyone, covering tier upgrade and mutation inheritance. Also a compliance requirement — fusion is a "combination item" and therefore a paid random item.

**Fusion Book** tracks discoveries — 876 species entries plus 6,132 mutation entries. Completion milestones pay fixed rewards.

**World First:** the first player anywhere to create a combination gets a global banner in every server and permanent "Discovered by" credit. Implemented as a DataStore `UpdateAsync` on `firsts/<comboKey>` (first writer wins) plus a `MessagingService` broadcast.

### 5.7 Weather and mutations — free
Every 12–20 min, a 90 s event announced 30 s ahead with a sky change: Golden Glaze ×3, Frost Sugar ×2, Lava Salsa ×4, Rainbow Sprinkles ×5, Galaxy Jelly ×10 (rare). Long-run uplift: **+22% income**, costing nothing.

Each Nomling on an **open** pedestal has a per-event mutation chance (6%). Vaulted Nomlings are safe but do not mutate — a real trade-off, not a free win.

**Nom Storm**: admin-triggered global weekend event; boosts mutation chance and enables the "Nomzilla" mutation (giant, ×8).

Chances are shown in an info panel even though weather is free and therefore exempt from disclosure rules. We disclose anyway; it costs nothing and builds trust.

### 5.8 Snatching — friendly PvP

Hold 1.5 s on a Nomling in an unlocked base → carry it (30% slower, glowing trail; owner gets an alarm and a direction arrow) → reach a free pedestal on your own plot to keep it. After 40 s of carrying it pops home.

**Bubble Wand** — everyone has one. One hit bubbles the carrier for 2 s and sends the Nomling home. 3 s cooldown. The bubbled player gets **3 s immunity** so nobody is stun-locked.

**Laser Gate** — locks the base for 60 s, 90 s cooldown.

**Fair play, all config values:**
- Newcomer shield for the first 20 minutes of total playtime.
- No snatching from anyone whose coins/s is under 20% of yours.
- One attempt per target per 60 s.
- Vault and Bonded Nomlings can never be taken.
- **Loss softener:** the victim immediately gets a Comeback Egg of the same tier, 2-minute hatch.

**Chill Mode** — private server owners can turn snatching off entirely.

**Design intent:** a player who is snatched from should feel *"that was exciting"*, never *"I lost my afternoon."* Every number above exists to protect that feeling. If playtests show otherwise, weaken snatching — never strengthen it.

⚠️ **Testing constraint.** Philip is phone-only with no Studio, so we cannot run two clients side by side. Snatching is therefore built against **scripted NPC snatchers** (Sneaky Sam and friends) that exercise the same server code paths a real player would, plus Luau Execution scenario tests. See `docs/TECH.md`.

### 5.9 Rebirth ("Re-Nom")
Costs `1,900,000 × 2.5^n` coins.
- **Resets:** coins, base Nomlings, coin upgrades.
- **Keeps:** Fusion Book, Vault Nomlings, Bonded Nomlings, passes, cosmetics.
- **Grants:** permanent `2.6^n` income multiplier, the next egg tier, a new plot theme, a Rebirth Token for a small fixed-effect perk tree, **and one free egg already incubating**.

⚠️ That last grant is not in the brief and the game is unplayable without it — see `docs/ECONOMY.md` §4.1.

### 5.10 Daily systems and stopping points
7-day login calendar with fixed rewards and a one-day grace period. 3 daily quests (hatch 5, fuse 2, bubble 3 snatchers) and 1 weekly.

**Stopping points are a feature.** When all incubators and fusions are busy: *"Kitchen's cooking! Back in 12 min."* Quests-done screen. Offline caps. Daily ad caps. **No infinite reward loops** — this is a design rule and a compliance one.

### 5.11 Social
- **Invites** through `SocialService`. When an invited friend has played 10 minutes, both get a Buddy Egg.
- **Friend bonus:** +10% income per friend in server, capped +30%. Directly serves the "intentional co-play days" discovery signal.
- **Emote wheel**, plus Quick Words if and when they ship. ⚠️ Quick Words is unverified (`docs/VERIFY.md`) — the game must be complete without it.
- **Gifting** purchases to someone in the same server.
- **Podium** show-off pose.
- Server-wide banners for big hatches, fusions and World Firsts.

### 5.12 Leaderboards
Four, on OrderedDataStores refreshed every 60–120 s, shown in the plaza and in the UI: coins/s (weekly + all-time), World Firsts, Fusion Book completion, weekly Snatch Master.

### 5.13 Codes
Defined in live config JSON, one use per player, with an expiry date.

### 5.14 Creator Mode
Hides UI, adds an orbit camera, replays your last reveal in slow motion. Makes the game trivially filmable. Given that our growth plan leans on short video, this is a **growth feature, not a cosmetic one** — treat it as M4 scope, not backlog.

### 5.15 Admin and live ops
In-game panel gated on a config allowlist of user IDs; full tools in TEST, limited in PROD. Trigger weather, trigger a global Nom Storm, broadcast a banner, force a Golden Egg restock, grant test items (TEST only), soft shutdown. Plus `tools/trigger-event` for Open Cloud Messaging broadcasts.

### 5.16 Settings and accessibility
Music / SFX / TTS toggles. Reduced motion, large text, haptics toggle. Colourblind-safe rarity (colour + icon + label). Safe-area aware via `ScreenInsets`.

---

## 6. Not in v1

| When | What |
|---|---|
| Update 1 (Jan) | Trading, with full compliance and a two-sided scam-proof confirmation |
| Update 2 (Feb) | Season Pass |
| Later | Custom naming or any user-generated text/images; clans; UGC avatar items; standalone app; offline mode |

**Never:** anything feed-like (media feed + autoplay + reward for continued watching), free-form drawing, off-platform links in-game.

---

## 7. Art and audio

**Style: "toy food court diorama."** Chunky rounded shapes, saturated candy palette, Future lighting, soft atmosphere, bloom on neon accents, gentle colour correction. Palette tokens and material rules live in one shared style module — `src/shared/Style/`.

⚠️ **New constraint from Phase 0:** "unplayable gambling content" forces a **Moderate** maturity label, which would lock us out of Roblox Kids entirely. Paid random items themselves do *not* raise the label — but gambling **imagery** does.

> **Therefore: no casino visual language anywhere.** No prize wheels, no slot-machine reels, no playing cards, dice or chips. The Egg Market is a **vending machine / market stall**. The Fusion Lab is a **kitchen**. This is a hard art rule, not a preference.

**Licensing:** original work only, or properly licensed Creator Store assets and Roblox-licensed audio. No meme IP, no brands, no copyrighted music. Every asset recorded in `assets/manifest.json` with ID, source and licence.

**UI:** bold rounded font, big icons, number abbreviations (K, M, B, T, Qa, Qi…), juicy tweens, haptics on key moments.

**Audio:** pops, squeaks, "nom" sounds, a rising tone per rarity step, and TTS name callouts.

---

## 8. Clip moments — designed on purpose

A fusion reveal · the World First banner · a Galaxy mutation · a Nomzilla · a Golden Egg restock · a snatch chase ending in a bubble save · a rebirth explosion · the Nom Storm countdown.

Each one must be: readable in a vertical crop, under 10 seconds, and comprehensible with the sound off.

---

## 9. Performance budget

60 FPS on mid-range phones; playable on low-end. StreamingEnabled on. ≤30 parts per Nomling, an instance budget per plot, particle caps. **Test case: 8 players, 150+ Nomlings visible simultaneously.** Avatars: **R15 only** — required for the higher DevEx rate (`docs/VERIFY.md` §3.3).
