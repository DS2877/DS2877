# DECISIONS.md

Decision log (brief §11.5). Newest first. Each entry: what, why, what would reverse it.

Platform facts with source URLs and check dates live in `docs/VERIFY.md`.

---

## 2026-09-17 — Phase 4 (M2 core fun)

### D-026 · The death screen says WASTED — Philip's call, flagged not softened
**Decision.** Dying desaturates the world and fades up **WASTED** in red, with a sound. Asked for directly: *"When you die I want something exactly similar to when you do it in gta."*
**The concern, stated once and then dropped.** Everything else in this game avoids the vocabulary of dying on purpose — the PvP is "friendly snatchers", and `tools/validate-kid-safe.py` rejects the whole violent word list in any player-facing string. WASTED is a quotation from an 18-rated game and is the only place the project points at that register. It trips no automated rule, and a single stylised word is not what decides a Roblox maturity questionnaire — the questionnaire asks about blood, realistic violence and gambling, none of which this is. So it ships.
**What would actually change this.** If the Maturity & Compliance Questionnaire at M5 asks anything where this is a defensible "yes", or if a playtest with an actual nine-year-old reads it as scary rather than funny, swap the word. The screen itself — the desaturate, the fade, the sting — is the part doing the work and survives any wording.
**Also true:** there is barely any way to die yet. The street is flat and there is no combat. This is for falling off things, and for whatever M4 adds.

### D-025 · The Laser Gate is 60 s up in every 90, and does not collide
**Decision.** `GATE_SECONDS = 60`, `GATE_COOLDOWN_SECONDS = 90` measured **from the raise**, and the lasers are `CanCollide = false`.
**Why from the raise.** Measured from the drop it would be 60 up then 90 down — 40% of the time locked. From the raise it is 60 in every 90, so the real gap between one gate falling and the next going up is 30 s. That is the difference between a defence and a wall, and it is easy to implement the wrong one by accident, so `tests/unit/gate.spec.luau` asserts which it is.
**Why it does not collide.** A solid barrier traps the owner on whichever side they are standing, and it puts client physics in charge of who gets robbed. The refusal is a server rule (`SnatchRules`); the lasers exist so a thief can see it from the road. A defence that is invisible until you are refused is not a defence, it is a bug report.
**Not saved across sessions, on purpose.** Leaving releases your base (`PlotService.release`), so rejoining to reset a cooldown means rejoining into a different, empty plot. There is nothing to exploit, and a persisted cooldown would instead punish a player for a disconnect.
**Reversal condition.** If `gate_raised` shows raise rates near the cap with no relationship to snatches on that base, the cooldown is making the decision rather than the player — lengthen it until choosing the moment matters.

### D-024 · A vaulted Nomling does not earn
**Decision.** The Vault is pedestal 9. A creature in it cannot be snatched and cannot mutate (GDD 5.7) — and it also earns nothing.
**Why the third one is ours and not the GDD's.** The GDD's trade is "safe but does not mutate". On its own that makes the Vault a strictly better ninth pedestal: mutation is a 6% roll per weather event, so giving it up costs almost nothing most sessions, and the correct play for every player becomes "vault your best creature and never think about it again". A defence nobody has to think about is not a decision, it is a chore with an obvious answer.
**It also keeps the economy honest.** `tools/simulate-economy` models exactly `PEDESTALS_BASE` earners. An earning Vault is +12.5% income at base that the simulator does not know about, which would quietly falsify every pacing claim in `docs/ECONOMY.md` — and the parity test would not catch it, because it compares constants, not consequences. `VAULT_PEDESTAL` and `PEDESTALS_TOTAL` are mirrored into `config.py` precisely so that a future change making the Vault earn cannot land without the simulator growing a ninth slot in the same commit.
**Reversal condition.** If playtests show the Vault sitting empty — nobody using it at all — the cost is too high; make it earn at a reduced rate and re-run `tune.py` in the same change. Empty is the failure signal, not "used rarely": rarely is correct for a slot you spend on your one irreplaceable creature.

### D-023 · CI typechecks Luau — approved by Philip 2026-09-17
**Problem.** D-014 assumed CI typechecks. It did not (see the correction there). A plain argument-type error reached a playtester twice.
**Decision.** A `typecheck` job in `.github/workflows/ci.yml` pins `luau-lsp` **1.69.0**, generates a Rojo sourcemap, fetches Roblox's type definitions, and runs `luau-lsp analyze` over `src`. Blocking, like every other check.
**Three things it needs, and why each one matters.**
- **The sourcemap.** Roblox resolves a require through the DataModel tree (`script.Parent`), not the filesystem. Without `--sourcemap` every cross-module require is `any`, and a typecheck where everything is `any` is theatre.
- **`globalTypes.d.luau`.** Roblox's own API as Luau types. Without it every Instance, service and Enum is `any` — including `BasePart`, which is precisely the type the bug turned on.
- **`strictDatamodelTypes: false`** (`.github/luau-lsp-settings.json`). With it on, the sourcemap is treated as the complete DataModel and every lookup of a runtime-built instance is an error — and this game builds its entire world at runtime. Hundreds of false errors is how a check gets ignored.
**Cost.** It cannot run in a cloud session: `luau-lsp` is C++ with no crates.io package, and the sandbox's egress proxy blocks GitHub release downloads (the crates.io toolchain and `raw.githubusercontent.com` both work — it is specifically releases). So for Claude this is push-then-read-CI rather than part of `./scripts/check.sh`. Accepted: the alternative was no typecheck at all.
**Reversal condition.** If it proves too noisy to gate a push, downgrade it to a non-blocking annotation job rather than deleting it — a warning that is read beats a check that is not there.

## 2026-09-16 — Phase 2 (pipeline)

### D-019 · M1 ships without ProfileStore and without React-Lua — both still approved
**Decision.** `DataService` is a hand-written DataStore wrapper with its own session lock, and the HUD is plain Instances. Both approved dependencies (D-005, D-006) are deferred to their own change.
**Why, per dependency.**
- **ProfileStore:** the Wally registry returned HTTP 500 for every ProfileStore/ProfileService lookup on 2026-09-16 while other packages (`jsdotlua/react`, `jsdotlua/react-roblox`) resolved fine. Blocking the first playable slice on a registry outage buys nothing.
- **React-Lua:** it resolves fine — this one is a judgement call. Four labels and two buttons do not need a reconciler, and adding one to a slice that is itself brand new means two untested things at once.
**What was kept.** The wrapper keeps ProfileStore's two load-bearing behaviours: a **session lock** (without it, one player on two servers gets two profiles and the last save wins — a duplication exploit once stealing exists) and **atomic `UpdateAsync` writes**. Swapping ProfileStore in touches `DataService.luau` only.
**Reverse at:** M2a for React-Lua, when the Fusion Book and reveal UI make hand-built Instances the wrong tool. ProfileStore as soon as the registry serves it — and before any feature that can duplicate value.

### D-018 · stylua is installed with `--features luau`, and the syntax is named at every call site
**Decision.** Every install of stylua passes `--features luau`, and every invocation passes `--syntax Luau`.
**Why.** `cargo install --locked stylua` builds *without* Luau support. That binary cannot parse `.luau` — and, far worse, drops `.luau` from its default glob, so `stylua --check src tests` **exits 0 having checked nothing**. The format gate was green in CI and in `scripts/check.sh` from day one while never reading a single file; formatting it, once fixed, touched 8 files and 374 lines.
**The guard matters more than the fix.** Naming `--syntax Luau` makes a feature-less binary fail loudly (`isn't a valid value`) instead of passing vacuously. `setup-cloud.sh` also re-checks an already-installed stylua for Luau support, because the version string alone cannot tell the two builds apart.
**Worth generalising:** this is the third gate in this repo found green-but-inert, after the CI publish step that skipped on empty variables and `Swatinem/rust-cache` failing on a repo with no `Cargo.toml`. A check that cannot fail is worse than no check. Prefer gates that assert they did work.

### D-017 · Selene's Roblox standard library is committed, not generated
**Decision.** `roblox.yml` is a hand-maintained minimal std file, committed to the repo.
**Why.** `selene generate-roblox-std` fetches the Roblox API dump over TLS using its own bundled cert roots and ignores the agent proxy's CA — `SSL_CERT_FILE`, `CURL_CA_BUNDLE` and `REQUESTS_CA_BUNDLE` were all tried and all failed. Without a committed file, lint is unavailable in the exact environment where most work happens.
**Cost.** The file lists only the globals the codebase actually uses, so a newly-used global surfaces as an `undefined_variable` error. That is a clear signal rather than a silent gap, and adding an entry takes seconds.
**Reverse if:** selene gains an offline generation path, or starts honouring the system trust store.

### D-016 · The M0 plaza is built in code, not loaded from a `.rbxm`
**Decision.** `PlazaService` constructs the plaza with `Instance.new`. The `worldgen/` Lune pipeline the brief describes is deferred.
**Why.** Putting an asset-serialisation pipeline on the critical path for the very first deploy buys risk with no payoff while the plaza is eight pads and two props.
**Reverse at:** M2, when the plaza gains real content. `worldgen/` remains the destination.

### D-015 · M0 ships with zero Wally dependencies
**Decision.** `wally.toml` declares no dependencies. React-Lua and ProfileStore — both approved — land in M1.
**Why.** Publishing an empty plaza needs neither, and adding them now would put the Wally registry's reachability on the critical path for the first deploy. One risk at a time.

### D-014 · Typechecking is CI-only
**Decision.** No `luau-lsp` in cloud sessions. Cloud gets format, lint, unit tests and parity; CI adds typecheck.
**Why.** Confirmed by experiment: `luau-lsp` is not published to crates.io (it is a C++ project released as GitHub binaries), and GitHub release downloads are blocked by the egress proxy. Committing a ~30 MB binary to git was the alternative and is worse.
**Cost.** Type errors surface in CI rather than before the push. Acceptable — CI is fast and the inner loop still catches most problems.

> ⚠️ **Correction, 2026-09-17: the second half of this was never built.** `.github/workflows/ci.yml` has no typecheck job. Nothing, anywhere, typechecks this repo — the `--!strict` headers are decoration. It cost a real bug: `PlotService` passed `plot.index` (a number) to `pedestalPositions(pad: BasePart)` for four commits. Indexing a number threw on the first base, `plots` stayed empty, and **no player on any server was ever assigned a base** — every sign read "EMPTY BASE" and a playtester lost two sessions to it. Format, lint, 142 unit tests, parity, kid-safe and the Rojo build all passed on that code, because none of them look at types.
> **Superseded by D-023.**

### D-014a · Toolchain timings, measured
Cold `cargo install` on a 4-core runner, measured twice: **440 s** and **573 s** total (7–10 min) — over the brief's ~5-minute setup budget either way. Per-tool on the faster run: stylua 44 s, selene 54 s, wally 69 s, rojo 101 s, lune 172 s. `scripts/setup-cloud.sh` therefore installs in priority order (format, lint, tests, then build, then packages) so a truncated run still leaves the important tools. Results cache for about a week.

### D-013a · An economy parity test guards the simulator
**Decision.** `tests/parity/economy_parity.py` parses `src/shared/Config/Economy.luau` and asserts it matches `tools/simulate-economy/config.py`, curve for curve.
**Why.** The pacing claims in `docs/ECONOMY.md` are only true while the game and the simulator agree. Nothing else would catch the drift, and it would be silent. Verified to fail on a one-ppm change and a single-digit constant change.

## 2026-09-16 — Phase 1

### D-013 · World First stores `UserId`, never a display name
**Decision.** World First records store the discoverer's `UserId`; the display name is resolved at read time.
**Why.** Right-to-Erasure means we must be able to remove a person's identity on request. Deleting the whole record would let someone re-claim a first that already happened, corrupting the Fusion Book for everyone. Storing the ID lets erasure anonymize to "A Nomling Scientist" with a single field write.
**Must be in the M2a schema, not retrofitted.** → `docs/RUNBOOKS.md` §5.

### D-012 · Launch moves to 8–12 December; M2 splits in two
**Decision.** Re-plan the roadmap: M2a (fusion & discovery, Oct 25), M2b (weather, snatching, rebirth, Nov 8), M3 Nov 22, M4 Dec 5, M5 Dec 8–12, M6 January. M0 and M1 keep the brief's dates.
**Why.** No Studio, 8–10 h/week phone-only, 2–4 days review latency per gate, and the brief's M2 is two milestones of work. Holiday traffic makes December a better launch window than late November anyway.
✅ **Approved by Philip on 2026-09-16.** Cut list in `docs/ROADMAP.md` remains available if the date needs pulling back.

### D-011 · Reposition on generation, not fusion
**Decision.** The pitch is "the creatures are generated, not listed." Marketing never leads with fusion.
**Why.** Steal An Egg — the most-played game on Roblox at ~1.7M CCU — already has stealing, hatching, income pets, base upgrades, a Fuse Machine and seven mutations. The brief's claim that no current hit owns the fusion twist is false. Roblox also deprioritizes games resembling existing ones, so feature parity is penalized, not neutral.
**Reverse if:** players describe us as a smaller Steal An Egg despite the repositioning — then lean harder into visual variance per fusion.

### D-010 · Egg prices scale with rebirth count (`2.9^rebirths`)
**Decision.** Add `EGG_PRICE_REBIRTH_SCALE = 2.9`, absent from the brief.
**Why.** With flat prices the simulator showed a heavy player reaching **220 rebirths in 28 days** with eggs absorbing only 4.3% of coins earned — the progression curve inverts. Scaled: 33 rebirths and 46.6%.
**Reverse if:** a future sink (cosmetics, Book rewards) absorbs enough that the shop no longer needs to.

### D-009 · Fusion Lab has one slot in v1
**Decision.** `FUSION_SLOTS_BASE = 1`.
**Why.** With unlimited concurrent fusions, income compounds geometrically and casual, regular and heavy players pace identically — the economy has no throttle. Also keeps the reveal an event rather than background noise.
**Watch:** this makes `fusionPro` the most mechanically powerful purchase in the game. Re-check at M3 that the base game feels fine without it (`docs/MONETIZATION.md` §3).

### D-008 · Rebirth grants a free egg
**Decision.** `REBIRTH_GRANTS_FREE_EGG = True` — every rebirth hands over one free egg of the best unlocked tier, already incubating.
**Why.** Rebirth resets coins **and** all base Nomlings. With both at zero the player has no income and no bank, and can never buy another egg — permanently stuck, one minute into the reward for their first half-hour. The brief's §4.5 I does not list this grant.
**Covered by a regression test.**

### D-007 · Rebirth constants: base 1,900,000, growth 2.5, multiplier 2.6ⁿ
**Decision.** Grid-searched by `tools/simulate-economy/tune.py`.
**Why.** Lands the casual player's 1st rebirth at 30 min and 10th at day 18 — both mid-window against the brief's targets — while a heavy player reaches ~33 rebirths in 28 days rather than spiralling.
**Reverse if:** any income, egg-pricing or fusion change. Re-run `tune.py`.

### D-006 · Data layer: ProfileStore — ✅ approved 2026-09-16
**Decision.** ProfileStore. Approved by Philip on 2026-09-16 (brief §11.7 dependency approval).
**Why.** ⚠️ Correcting the brief: Roblox does **not** officially recommend any third-party data library, so "confirm it is still the recommended library" has no official answer. Chosen on merits: session locking (prevents cross-server duplication), schema versioning with migrations, autosave, `BindToClose`, active maintenance.
**Fallback if declined:** hand-rolled `DataStoreService` wrapper with a `MemoryStoreService` lock. More risk, no saving.

### D-005 · UI library: React-Lua — ✅ approved 2026-09-16
**Decision.** React-Lua, with a hard rule that high-frequency values bypass the reconciler. Approved by Philip on 2026-09-16.
**Why.** The brief's criterion — familiar to a web developer — is weak here, since Claude writes the code and Philip reviews it. The decisive reason is that React-Lua has the most documentation and the most predictable behaviour, which matters when the person debugging is on a phone, new to Luau, and cannot open Studio. The performance cost is handled by keeping coin counters and timers out of the tree.
**Reverse if:** GUI frame time exceeds 2 ms on a mid-range phone at M4 → reassess against Vide.

### D-004 · Keep the title "Fuse a Nomling"
**Decision.** Keep it. Shortlist of 5 in `docs/TITLES.md`.
**Why.** "Nomling" is unused on Roblox and unclaimed as a trademark — the unique noun is exactly what the discovery rules reward. The verb matches the current breakout pattern without duplicating anyone's metadata.
**Open:** Philip must confirm in Roblox's own search (`docs/PHILIP-TODO.md` task 6). A proper EUIPO/USPTO check before M5 is cheap insurance.

### D-003 · Taco Cat → Taco Tiger → **Taco Rhino**
**Decision.** Slot 1 of the roster is **Taco Rhino**.
**Why, twice.** "Tacocat" is an established palindrome meme, an indie band and several published games — the one name on the roster someone else had already made famous, which is the opposite of the unique-metadata signal we need. The replacement, Taco Tiger, was then rejected by the exhaustive name-safety test: `Sushi` + `tiger` spells **Sushitiger**, and tiger was the only tail on the roster starting with `t`, so the species changed rather than the rule.
**Worth noting:** no human reading twelve names would have caught the second one. This is the case for generating names from tokens and testing the whole cross-product rather than hand-curating a list.

### D-002 · No casino visual language, anywhere
**Decision.** Hard art rule. No prize wheels, slot reels, playing cards, dice, chips or jackpot levers. The Egg Market is a vending machine; the Fusion Lab is a kitchen.
**Why.** "Unplayable gambling content" forces a **Moderate** maturity label, which loses the Roblox Kids tier entirely. Paid random items themselves do not appear to raise the label — but gambling *imagery* does. Cheapest compliance win available, and the easiest to lose by accident during an art pass.

### D-001 · Toolchain installs via `cargo install --locked`
**Decision.** Option B from the brief §7.3. Drop `toolchain-mirror.yml`.
**Why.** Validated by experiment: StyLua built in **44 s** in this environment. GitHub release downloads and `codeload.github.com` return 403 from the egress proxy, so Option A is not viable here; `index.crates.io` and `static.crates.io` are reachable. Needs `CARGO_HTTP_CAINFO=/root/.ccr/ca-bundle.crt`.
**Open:** Phase 2 must verify each remaining tool publishes an installable crate, and measure cold install time against the ~5-minute budget. Any tool that fails gets a committed binary fallback.

---

## 2026-09-16 — Phase 0

### D-000 · Platform facts verified against official documentation
All of brief §3 checked against `create.roblox.com` docs and DevForum announcements. Confirmations, corrections and open items with source URLs: **`docs/VERIFY.md`**.

Headline corrections that changed plans:
1. Discovery ranking counts **only** organically-acquired users — recruitment and ranking are separate funnels.
2. Audience Expansion Rewards require a **100+ DAU average for 60 days** — not launch revenue.
3. "Highly engaged player" includes a **platform-spend** test.
4. Publishing to 16+ needs only an age check, a 2-day-old account and the questionnaire.
5. Private server price changes **cancel every active subscription**; under-13s may not be able to join at all.
6. The 0.0054 DevEx rate requires **R15 rigs for 100% of active playtime** → both places set to R15 Only at creation.
7. Luau Execution: 10 concurrent tasks per place, **5 task creations per minute per key** → the cloud test suite is one task with many assertions.
