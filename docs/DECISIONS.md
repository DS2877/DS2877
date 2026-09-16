# DECISIONS.md

Decision log (brief §11.5). Newest first. Each entry: what, why, what would reverse it.

Platform facts with source URLs and check dates live in `docs/VERIFY.md`.

---

## 2026-09-16 — Phase 1

### D-013 · World First stores `UserId`, never a display name
**Decision.** World First records store the discoverer's `UserId`; the display name is resolved at read time.
**Why.** Right-to-Erasure means we must be able to remove a person's identity on request. Deleting the whole record would let someone re-claim a first that already happened, corrupting the Fusion Book for everyone. Storing the ID lets erasure anonymize to "A Nomling Scientist" with a single field write.
**Must be in the M2a schema, not retrofitted.** → `docs/RUNBOOKS.md` §5.

### D-012 · Launch moves to 8–12 December; M2 splits in two
**Decision.** Re-plan the roadmap: M2a (fusion & discovery, Oct 25), M2b (weather, snatching, rebirth, Nov 8), M3 Nov 22, M4 Dec 5, M5 Dec 8–12, M6 January. M0 and M1 keep the brief's dates.
**Why.** No Studio, 8–10 h/week phone-only, 2–4 days review latency per gate, and the brief's M2 is two milestones of work. Holiday traffic makes December a better launch window than late November anyway.
**Needs Philip's OK — this moves the launch date.** Cut list in `docs/ROADMAP.md`.

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

### D-006 · Data layer: ProfileStore (pending Philip's OK)
**Decision.** ProfileStore, subject to brief §11.7 dependency approval.
**Why.** ⚠️ Correcting the brief: Roblox does **not** officially recommend any third-party data library, so "confirm it is still the recommended library" has no official answer. Chosen on merits: session locking (prevents cross-server duplication), schema versioning with migrations, autosave, `BindToClose`, active maintenance.
**Fallback if declined:** hand-rolled `DataStoreService` wrapper with a `MemoryStoreService` lock. More risk, no saving.

### D-005 · UI library: React-Lua (pending Philip's OK)
**Decision.** React-Lua, with a hard rule that high-frequency values bypass the reconciler.
**Why.** The brief's criterion — familiar to a web developer — is weak here, since Claude writes the code and Philip reviews it. The decisive reason is that React-Lua has the most documentation and the most predictable behaviour, which matters when the person debugging is on a phone, new to Luau, and cannot open Studio. The performance cost is handled by keeping coin counters and timers out of the tree.
**Reverse if:** GUI frame time exceeds 2 ms on a mid-range phone at M4 → reassess against Vide.

### D-004 · Keep the title "Fuse a Nomling"
**Decision.** Keep it. Shortlist of 5 in `docs/TITLES.md`.
**Why.** "Nomling" is unused on Roblox and unclaimed as a trademark — the unique noun is exactly what the discovery rules reward. The verb matches the current breakout pattern without duplicating anyone's metadata.
**Open:** Philip must confirm in Roblox's own search (`docs/PHILIP-TODO.md` task 6). A proper EUIPO/USPTO check before M5 is cheap insurance.

### D-003 · Taco Cat → Taco Tiger
**Decision.** Replace the base Nomling.
**Why.** "Tacocat" is an established palindrome meme, an indie band and several published games. It is the one name on the roster someone else already made famous, which is the opposite of the unique-metadata signal we need.

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
