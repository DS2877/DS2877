# Changelog

All notable changes to this project. Newest first.

## [Unreleased]

### M1 vertical slice, first half · 2026-09-16

**The loop runs.** Join, get a plot, buy an egg, watch it hatch, a Nomling lands on a pedestal and starts earning, leave, come back to your coins.

**Added**
- `Logic/Profile.luau` — the save schema and every legal mutation. `sanitize` never rejects: a corrupt profile is repaired, not refused, because refusing locks a player out of the game permanently.
- `Logic/Income.luau` — per-second and offline accrual, the same formula the economy simulator uses.
- `DataService` — DataStore wrapper with a **session lock**, atomic writes, retry with backoff, autosave and a parallel `BindToClose` flush.
- `PlotService` — plot assignment, pedestal ring, Nomling rendering (placeholder visuals; the real builder is M2a).
- `EggService` — buy and hatch. The roll happens **on claim, on the server**, never at purchase and never on the client.
- `IncomeService` — time-based coin tick, so frame rate cannot change earnings.
- `BaseHudController` — phone-first HUD: coins, egg button, incubator slots, all touch targets ≥ 56 px.
- Three remotes declared in `shared/Net` first, implemented second.
- 24 tests, including regressions for double-placement, corrupt saves and backwards clocks.

**Fixed before it ever ran**
- **stylua was checking zero files.** Built without `--features luau` it drops `.luau` from its glob and exits 0, so the format gate was green and inert since day one across CI and local runs. See D-018.
- **A service ordering bug that would have killed the slice.** `PlotService` looked for the plaza in `init()`, but `PlazaService` builds it in `start()`, and every `init` runs before any `start`. Nobody would have been given a plot and nothing would have rendered.
- `Income.format` returned a nine-character string past 10³³, overflowing the HUD.

**The starter egg, which the model assumed and the game did not.**
A new profile had 0 coins, 0 income and no way to afford the cheapest egg — soft-locked on the first screen, the exact failure `REBIRTH_GRANTS_FREE_EGG` fixes for rebirth (D-008). The economy simulator had *always* granted a free starting egg, as an unnamed line inside `simulate.py`, so every pacing number in `docs/ECONOMY.md` already depended on it. It is now `STARTER_EGG` in both config files, used by both, with the grant written as a state test (`isStranded`) so it also rescues anyone already stranded by the previous build.

**Not done yet** — the analytics funnel and the rest of the FTUE, both listed under M1 in `docs/ROADMAP.md`.

### First TEST deploy · 2026-09-16

**Shipped**
- **`Fuse a Nomling TEST` is live at version 4** with the M0 plaza. The pipeline is real: a push to `main` builds and publishes on its own.

**Fixed**
- Open Cloud permission names were wrong in `tools/opencloud.py` — it named scopes that do not exist, so a 401 sent the reader hunting for something Creator Hub never shows. Roblox's guide says `universe-places` + the **Write** operation, picked from menus.
- Removed `Swatinem/rust-cache` from both workflows. It needs a Cargo workspace, and this repo is not one, so it cached nothing and failed in its post step on every run. `~/.cargo/bin` is cached directly instead, which turns a ~2-minute Rojo build into a restore.
- Dropped the deprecated `Workspace.FilteringEnabled` from the project file.

**Added**
- A universe/place preflight in `tools/publish.py`. It needs no API key, takes a second, and catches a mistyped GitHub variable before a multi-minute build instead of after it.
- Retry with backoff on transient Open Cloud failures (~135 s across 4 attempts).
- `docs/RUNBOOKS.md` §9a — the HTTP 409 decision tree.

**The 409, honestly**
Three failed publishes over 2½ hours, all `Save failed. Server is busy`. Everything on our side was ruled out by test: the universe/place pair against Roblox's public mapping endpoint, the key (an invalid one 401s instantly, ours got past that), the built file, the content type. Then it published first try with nothing changed — so it was Roblox-side and cleared on its own. The ruled-out table is kept because it is what makes the next one a minute's work.

### Name generator (M2a, pure-logic half) · 2026-09-16

**Added**
- `src/shared/Config/Nomlings.luau` — the 12 base species with their head/tail tokens.
- `src/shared/Logic/NameGen.luau` — deterministic name generation. The whole rule is `affix + head(A) + tail(B)`, which reproduces the brief's own Sushiwal example.
- `src/shared/Config/NameSafety.luau` — multilingual profanity, brand and filter-risk blocklists, plus an allowlist.
- 12 new tests, including an exhaustive sweep of all 876 names.
- `tools/sample/names.luau` — prints a sample of what the generator produces.

**The name-safety test found a real bug on its first run.**
`Sushi` + `tiger` spells **Sushitiger** — a name that would have appeared in a reveal banner, in front of children, read aloud by the game's text-to-speech. Tiger was the only tail on the roster starting with `t`, so slot 1 became **Taco Rhino**. No human reading twelve names would have caught it.

It also exposed a flaw in the blocklist itself: "Titan" contains "tit", "shell" contains "hell". A substring list needs an allowlist to be usable, so one was added — innocent words are stripped before scanning.


### Phase 2 — M0 pipeline · 2026-09-16

**Added**
- Repo scaffold: `default.project.json`, `.luaurc`, `stylua.toml`, `selene.toml`, `wally.toml`, `rokit.toml`, committed `roblox.yml`.
- Runtime skeleton: server and client bootstraps with explicit service ordering, `NetService` with per-player token buckets, `PlazaService` (eight plots, Egg Market, Fusion Lab, spawn), shared `Economy`, `Style`, `Net`, `Odds` and `TokenBucket` modules.
- 19 unit tests under Lune, plus an economy parity test and a catalog validator.
- Open Cloud tooling: `tools/publish.py`, `tools/run-cloud-tests.py`, shared `tools/opencloud.py`.
- `tests/cloud/smoke.luau` — one task, many assertions, because task creation is capped at 5/minute per key.
- Four GitHub Actions workflows, `scripts/setup-cloud.sh`, `scripts/check.sh`.
- `CLAUDE.md`, `.claude/settings.json`, five subagents, five slash commands.
- `docs/CLOUD-SETUP.md` — everything Philip needs to paste, in one page.

**Verified by experiment**
- The whole toolchain installs from crates.io: stylua 44 s, selene 54 s, wally 69 s, rojo 101 s, lune 172 s (~7.3 min cold, cached ~1 week).
- `luau-lsp` is **not** on crates.io, so typechecking is CI-only.
- `selene generate-roblox-std` cannot run here — it ignores the proxy CA — so `roblox.yml` is committed instead.

**Fixed**
- A real Luau syntax error the linter caught: `Net.REMOTES: {...} = {}`. Luau does not allow annotating a table field assignment; it needs a typed local.
- Dead `ReplicatedStorage` require in the client bootstrap.

**Guardrails**
- `tools/publish.py` refuses PROD without `--i-have-approval`, which only the approval-gated workflow supplies.
- The economy parity test fails on a one-ppm drift, verified deliberately.
- The catalog validator rejects an odds-changing item with no disclosure metadata, and a server-wide boost that is not deterministic.

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
- Launch re-planned to 8–12 December, all-ages to January. ✅ Approved 2026-09-16, along with React-Lua and ProfileStore.

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
