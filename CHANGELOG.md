# Changelog

All notable changes to this project. Newest first.

## [Unreleased]

### Phase 1 — Design pack · 2026-09-16

**Added**
- Full design pack: `GDD`, `NOMLINGS`, `ECONOMY`, `MONETIZATION`, `COMPLIANCE`, `TECH`, `CONFIG`, `ANALYTICS`, `ROADMAP`, `LIVEOPS`, `MARKETING`, `STORE-PAGE`, `RUNBOOKS`, `TITLES`, `RISKS`, `DECISIONS`.
- `tools/simulate-economy/` — behaviour-model economy simulator and grid-search tuner. All four of the brief's pacing targets pass.
- `tools/revenue-model/` — revenue scenarios for 1k/10k/100k DAU, with every assumption labelled by confidence.

**Found**
- **The brief's differentiation claim is false.** Steal An Egg, the most-played game on Roblox (~1.7M CCU), already has stealing, hatching, income pets, base upgrades, a Fuse Machine and seven mutations. Repositioned on procedural generation and World First.
- **Rebirth was a dead end** — it resets coins and all Nomlings, leaving the player with no income and no bank. Fixed with a free restart egg.
- **Fusion was an infinite upgrade treadmill** — unlimited concurrent fusions made income compound geometrically. Fixed with a single fusion slot.
- **Flat egg prices broke the late game** — a heavy player reached 220 rebirths in 28 days. Fixed by scaling egg prices with rebirth count.
- The fusion name space is **876 creatures / 6,132 book entries**, not "thousands" of creatures. World First split into Species and Mutation firsts.

**Decided**
- Toolchain installs via `cargo install --locked`; `toolchain-mirror.yml` dropped.
- UI: React-Lua, with high-frequency values bypassing the reconciler. Data: ProfileStore. Both pending dependency approval.
- Title stays "Fuse a Nomling"; Taco Cat becomes Taco Tiger.
- No casino visual language anywhere — gambling imagery would force a Moderate rating and lose the Roblox Kids tier.
- Launch re-planned to 8–12 December, all-ages to January. **Needs approval.**

### Phase 0 — Orientation · 2026-09-16

**Added**
- `docs/00-kickoff-brief.md` — the brief, saved unchanged.
- `docs/VERIFY.md` — every claim in brief §3 checked against official sources, with URLs and dates, plus environment detection.
- `docs/PHILIP-TODO.md` — owner-only tasks.

**Found**
- Discovery ranking counts only organically-acquired users; recruitment and ranking are separate funnels.
- Audience Expansion Rewards need a 100+ DAU average for 60 days.
- "Highly engaged player" includes a platform-spend test.
- Publishing to 16+ needs only an age check, a 2-day-old account and the questionnaire.
- Private server price changes cancel every active subscription.
- The 0.0054 DevEx rate requires R15 rigs for 100% of active playtime.
- Luau Execution allows 5 task creations per minute per key.
