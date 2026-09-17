# ROADMAP.md

Phase 1.1. ✅ **Approved by Philip on 2026-09-16.** The cut list at the end stays available if the date ever needs pulling back.

---

## Why the brief's schedule does not survive contact

The brief targets M5 launch on **~21–27 Nov**, ten weeks from kickoff. Three things learned since it was written argue against it:

1. **No Studio.** Philip is phone-only during business hours. Every visual iteration becomes a screenshot round-trip, and multi-client PvP testing has to be replaced with scripted NPCs. Both are solvable (`docs/TECH.md` §1, §7) but neither is free.
2. **M2 is not one milestone.** The brief packs fusion + reveals + TTS + Fusion Book + World First + weather + mutations + snatching + Bubble Wand + Laser Gate + Vault + Sneaky Sam + rebirth + leaderboards into a fortnight. That is two milestones of work, and it contains the two hardest systems in the project (procedural generation and PvP).
3. **Review latency is the real bottleneck.** Claude does the building, but every gate needs Philip to actually play it on a phone. At 8–10 h/week in business-hours fragments, assume **2–4 days** of wall-clock between "ready" and "approved", not hours.

**There is also an opportunity the brief missed.** Roblox traffic peaks over the winter holidays — the discovery docs list holiday seasonality explicitly. A launch that lands *just before* the break, with the 250-play push running *through* it, is better positioned than one in late November. The slip is partly a gift.

---

## Schedule

| Milestone | Brief | **Agreed** | Change |
|---|---|---|---|
| M0 Setup | Sep 27 | **Sep 27** | unchanged |
| M1 Vertical slice | Oct 11 | **Oct 11** | unchanged |
| **M2a Fusion & discovery** | *(part of M2)* | **Oct 25** | split |
| **M2b Weather, snatching, rebirth** | *(part of M2)* | **Nov 8** | split |
| M3 Money & retention | Nov 8 | **Nov 22** | +2 weeks |
| M4 Polish | Nov 20 | **Dec 5** | +2 weeks |
| M5 Launch (16+ trial) | ~Nov 21–27 | **Dec 8–12** | +2 weeks |
| M6 All ages + holiday event | Dec 12 → Jan 4 | **Jan 5–16** | +3 weeks |
| Update 1 — Trading | January | **February** | +1 month |
| Update 2 — Season Pass | February | **March** | +1 month |

**M0 and M1 are unchanged deliberately.** They are pipeline and vertical-slice work, almost entirely Claude-side, and hitting them on the brief's dates proves the pipeline is real before anything else is committed to.

**The Plus clock still clears comfortably.** Philip subscribes ~16 Sep, so the 2-consecutive-month bar is met ~16 Nov — well before the M6 all-ages publish in January.

---

## Milestones

### M0 — Setup · Sep 27
Repo scaffold, toolchain, CI/CD, cloud setup script and allowlist text, `CLAUDE.md` and `.claude/`. Empty plaza published to TEST. One Luau Execution smoke test. Catalog sync dry run.

**Done when:** Philip opens the TEST place on his iPhone and walks around an empty plaza.
**Phone demo:** join TEST, walk, confirm 60 FPS.
**KPIs:** none yet. **Blocked by:** Philip tasks 3, 4, 5.

### M1 — Vertical slice · Oct 11 — 🟢 all but analytics
Plot, pedestals, coins, Basic egg, hatch, collect, save/load, the first 60 seconds of the FTUE, analytics funnel.

**Done 2026-09-16/17:** plot assignment, pedestals, server-side coin income with offline accrual, Basic egg purchase and hatch, save/load with a session lock, phone HUD, the street layout, the delivery belt, stealing with NPC thieves and the Bubble Wand, an objective-driven tutorial, art direction with per-device quality scaling, real client-built creatures, game feel, and **M2a fusion with the reveal and World First — pulled forward from 25 Oct**.
**Done 2026-09-17 (second playtest pass):** the HUD shrunk and recomposed to a
tested layout budget, belt purchases that say why they refuse, pocket money so
losing everything is a setback rather than a dead end, a home beacon, an
arrivals board with live countdowns and the server top five, eight
colour-coded bases, and **all eight audio assets uploaded and live** — the
game has sound.

**Still open:** the analytics funnel (0 lines written against ~65 spec'd rows
in `docs/ANALYTICS.md`) and placing/moving a Nomling by hand.

**Done when:** a player can join, hatch, place, collect, leave and come back to their coins.
**Phone demo (3 min):** join → egg hatches in 5 s → place it → collect → rejoin and confirm data persisted.
**KPIs:** FTUE steps 1–5 firing. **Risk:** ProfileStore integration and `ProcessReceipt` idempotency.

### M2a — Fusion and discovery · Oct 25 — 🟢 pulled forward, largely done
Built early during the M1 sprint: `NomlingBuilder`, `NameGen`, the fusion flow,
the reveal, the Fusion Book and World First. **Open:** the TTS name callout and
the shared plaza reveal screen for two players in one server.

`NomlingBuilder`, `NameGen`, fusion flow, public reveal, TTS name callout, Fusion Book, World First (DataStore + MessagingService).

**Done when:** two players in one server can each fuse and see the other's reveal on the plaza screen, and a World First banner fires globally.
**Phone demo (3 min):** fuse two Nomlings → watch the reveal → check the Book → confirm the name and look are identical after a rejoin.
**KPIs:** `fusion_completed`, `world_first_claimed`.
**Risk: this is the highest-risk milestone in the project.** It contains the differentiator, and "procedurally generated creature that looks good" is the hardest thing to verify without Studio. Budget screenshot round-trips.

### M2b — Weather, snatching, rebirth · Nov 8 — 🟡 nearly done
Weather, mutations, snatching, the Bubble Wand, Sneaky Sam and rebirth all
shipped early. **The Laser Gate and the Vault landed 2026-09-17** — the gate is
a button on each base with lasers across its front (60 s up, 90 s cooldown from
the raise, D-025), and the Vault is pedestal 9, where a creature is
unsnatchable and does not mutate or earn (D-024). Both are wired into
`SnatchRules`, and the NPC snatchers respect them too — a defence Sneaky Sam
ignores is a defence nobody ever tests.

**Still open: three of the four leaderboards** (one is live), and a HUD button
for the gate. Today the only way to raise it is the button on the base, which
teaches the mechanic but means you cannot defend from across the street — that
is deliberate (D-025), but a HUD button that respects the same proximity rule
would be kinder on a phone.

Weather and mutations; snatching, Bubble Wand, Laser Gate, Vault, Sneaky Sam; rebirth; four leaderboards.

**Done when:** the full loop closes — a player can rebirth and restart, and NPC snatch scenarios pass in CI.
**Phone demo (3 min):** survive a weather event → bubble Sneaky Sam → rebirth → confirm the free restart egg arrives.
**KPIs:** `snatch_attempted` blocked reasons, `rebirth`.
**Risk:** PvP feel, tested against NPCs rather than humans. Expect to re-tune after real players arrive.

### M3 — Money and retention · Nov 22
Catalog and sync, shop, receipts, compliance module, Starter Pack, server boosts, private servers with Chill Mode and the Plus prompt, daily rewards and quests, invites and referrals, friend bonus, notifications, codes, live config, rewarded-video scaffold (off).

**Done when:** a real Robux purchase in TEST grants correctly, survives a server restart without double-granting, and a PRI-restricted player sees no Tier 1 or Tier 2 item.
**Phone demo (3 min):** open shop → confirm prices come from `MarketplaceService` → buy the Starter Pack → verify the grant persists.
**Gate:** `compliance-reviewer` pass.
**Risk:** the open PRI question on time-skip items (`docs/COMPLIANCE.md` §2). Resolve it here, not at launch.

### M4 — Polish · Dec 5
Art, lighting, VFX and audio pass; UI polish; performance; localization; accessibility; security review; admin panel; store assets; **Creator Mode**.

**Done when:** 8 players and 150+ Nomlings hold 60 FPS on a mid-range phone.
**Gates:** `security-reviewer` and `mobile-ux-reviewer` passes; a written performance report.
**Risk:** the art pass is the part most damaged by having no Studio. Start screenshot loops early in the milestone, not at the end.

### M5 — Launch, 16+ trial · Dec 8–12
Launch checklist, store page, questionnaire submitted, admin panel verified, runbooks rehearsed, event schedule set. Then publish and push for 250 highly engaged plays.

**Gate: Philip's explicit approval before PROD.**
**KPIs:** bounce `<60 s`, FTUE completion, Audience Reach progress.
**Note:** the holiday break falls right inside the 60-day evaluation window. That is the plan, not an accident.

### M6 — All ages + holiday event · Jan 5–16
Kids/Select eligibility once the 250-play bar is cleared, plus the "Frosty Feast" event.

⚠️ The brief scheduled the holiday event for Dec 12 – Jan 4. On the new schedule the game is only just launched then. **Run "Frosty Feast" as a 16+ event over the break anyway** — it is exactly the content that drives the engagement we need for eligibility — and treat the all-ages switch as a January milestone.

---

## What would pull the dates back in

If Philip wants the original November launch, these are the honest levers, in the order they cost least:

1. **Cut Creator Mode from v1.** Saves ~3 days. Costs us filmability, which our growth plan leans on.
2. **Cut gen-3 fusion.** Saves ~4 days. Halves the Fusion Book and weakens the long tail.
3. **Cut snatching from v1 entirely.** Saves ~2 weeks and removes the hardest thing to test without Studio. But it also removes half the genre positioning and the "friendly chaos" pillar — and the market leader has it.
4. **Launch with 6 base Nomlings instead of 12.** Saves ~3 days, cuts the name space from 876 to 222.

**Recommendation: take the later date instead.** Option 3 is the only one that saves real time, and it guts the game. The December window is genuinely better than the November one.

---

## Weekly rhythm after launch

1. Review KPIs (Philip, on his phone).
2. Fix the top 3 problems.
3. Ship a content update — **new base species are the cheapest content we have**, and they expand the World First space (`docs/NOMLINGS.md` §3).
4. Run a weekend event.

Updates ship Saturdays (`docs/LIVEOPS.md`).
