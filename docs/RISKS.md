# RISKS.md — Challenging the brief

Phase 1.4. The brief asked for the five biggest risks to this becoming a hit, and how to reduce each. This is the honest version.

**Overall read:** the project is worth building. The plan is sound on compliance, monetization and engineering — those parts are unusually well thought through for a first Roblox project. The weak points are all in **positioning and capacity**, and one of them is a factual error in the brief that changes what we are making.

Ordered by how much damage each does if ignored.

---

## Risk 1 — The differentiation claim is false, and the genre is the most crowded on Roblox

**The brief says** (§4.1) the game combines steal-and-defend with idle-grow "with a fusion twist that **no current hit owns**."

**Reality, as of 2026-09-16:** **Steal An Egg is the single most-played game on Roblox — around 1.7 million concurrent players.** Its loop is: steal eggs from other players, hatch them into pets, pets earn money per second, upgrade your base, a **Fuse Machine**, and **seven income-multiplying mutations**. That is our feature list, held by the #1 game on the platform.

Fusion is not novel elsewhere either: Pet Simulator X and 99 both have fuse machines; Merge Pets!, Pet Merge Simulator, Creatures Tycoon and Collect All Pets all merge pets. Even procedurally generated pets exist — **Random Pets World** advertises "over a billion combos" and DNA combination.

**Why this compounds:** Roblox explicitly deprioritizes games whose "metadata and place files closely resemble existing games" in both recommendations and search. So entering this genre with feature parity is not neutral — it is actively penalized.

**Severity: high.** It does not kill the project, but it invalidates the marketing plan as written and means feature parity is table stakes, not a pitch.

**Mitigation (already applied across Phase 1):**
- **Reposition entirely.** The pitch is **"the creatures are generated, not listed"** — the one thing genuinely ours. Steal An Egg has 157 hand-made pets you can read in an index; we have 876 creatures nobody has seen, and fusion produces a creature that *has never existed* rather than a higher tier of an existing one.
- **World First becomes the headline feature**, not a nice-to-have. It is the only mechanic in this comparison that no competitor has.
- Marketing never says "fuse your pets" (`docs/MARKETING.md` §2).
- Original art direction is treated as a **discovery requirement**, not taste.

**What would tell us we are wrong:** if early players describe the game as "like Steal An Egg but smaller," the repositioning has failed and the honest move is to lean harder into generation — more visual variance per fusion, not more features.

---

## Risk 2 — The whole bet rests on procedural creatures looking good, and we cannot see them

Everything above depends on generated Nomlings being *delightful*. A fused creature has to look deliberate, funny and worth screenshotting. Combinatorial generation from ~30 parts very easily produces things that are **samey, muddy, or just ugly** — and "ugly" is fatal when the entire product is "look what I made."

**This is the highest-variance part of the project**, and it is made much worse by a compounding constraint: **Philip is phone-only with no Studio, so Claude cannot see the game at all.** The only visual feedback channel is Philip sending screenshots. The thing hardest to get right is also the thing hardest to check.

**Severity: high.** Risk 1 is a positioning problem with a known answer. This one is an execution problem with no guarantee.

**Mitigation:**
- **Build the generator first, in M2a**, before anything depends on it. If gen-2 creatures do not look good at M2a, everything downstream needs rethinking — better to know in October than in December.
- **Constrain rather than randomise.** Palette anchors, body archetypes and snack overlays come from curated tables (`docs/NOMLINGS.md`), not free RNG. The snack-overlay rule — animal sets silhouette, snack sets recognisable topping — is specifically designed so fusions read instantly.
- **Deterministic seeds** mean any creature Philip screenshots can be reproduced exactly for iteration.
- **Build a contact-sheet tool early:** a Luau Execution task that renders a grid of many creatures and saves the place, so Philip can inspect dozens in one screenshot instead of one at a time. This is the single highest-value tool in the project and it should exist in M2a.
- **Budget screenshot round-trips into the schedule**, which `docs/ROADMAP.md` now does.
- Keep the MeshPart upgrade path open so art quality can rise later without changing the genome.

**What would tell us we are wrong:** a contact sheet of 50 random gen-2 creatures where Philip cannot pick a favourite. That means variance is too low, and the fix is more distinct archetypes rather than more parts.

---

## Risk 3 — The scope does not fit one person at 8–10 h/week with no Studio

The brief targets launch ten weeks out with: procedural generation, a full PvP steal-and-defend system, six egg tiers, fusion with three generations, weather and mutations, rebirth, four leaderboards, a complete monetization catalog with compliance gating, daily systems, quests, referrals, notifications, codes, live config, an admin panel, and localization.

M2 alone packs fusion + reveals + TTS + Fusion Book + World First + weather + mutations + snatching + Bubble Wand + Laser Gate + Vault + Sneaky Sam + rebirth + leaderboards into two weeks. That is two milestones, and it contains the project's two hardest systems.

Claude does the building, but **review latency is the real constraint**: at 8–10 h/week in business-hours phone fragments, assume 2–4 days wall-clock between "ready" and "approved".

**Severity: medium-high.** The usual failure mode is not missing the date — it is shipping M4 polish at M2 quality and launching something that bounces.

**Mitigation:**
- `docs/ROADMAP.md` re-plans: M2 splits in two, launch moves to **Dec 8–12**, all-ages to January.
- M0 and M1 keep the brief's original dates deliberately, to prove the pipeline early.
- Heavy automation instead of manual QA (`docs/TECH.md` §7), since manual testing is one person on one phone.
- An explicit cut list, in cost order, if Philip wants November back.

**The slip is partly an advantage.** Roblox traffic peaks over the winter holidays, and the 60-day evaluation window for Kids/Select eligibility would then run straight through the break.

**What would tell us we are wrong:** missing M1 on Oct 11. That is mostly Claude-side work — if it slips, the estimates are wrong and everything after needs re-planning immediately, not at M4.

---

## Risk 4 — The launch audience is not the audience the game is for

**The structural problem:** every new game starts with **age-checked 16+ players only**. Kids/Select eligibility needs **250 unique plays from highly engaged age-checked players within 60 days**.

Three things make this harder than the brief assumes:

1. **"Highly engaged" includes a platform-spend test.** A qualifying player needs bars on account tenure, playtime *and* Roblox-wide spend — the spend route requires a purchase anywhere on Roblox in the last 60 days. Recruiting fresh accounts cannot work; it is designed not to.
2. **Self-declared 16-year-olds are in Select, not Roblox.** The 16+ pool is only *age-checked* users — much smaller than "everyone who says they are 16".
3. **The game is designed for 9–15.** Snack animals, bright colours, friendly chaos. We must win over an audience it was not designed for, and their bounce rate is what the discovery algorithm learns from first.

**Severity: medium-high**, and unavoidable — every new game faces it.

**Mitigation:**
- **Absurdity is the bridge.** Teens share silly things ironically. The generated names are the asset here: "Sushiwal" and "Giga Pizzacroc" are funny to a 16-year-old in a way a cute taco tiger is not. Lean the humour older than the art.
- **World First is a competitive hook**, and competition travels up the age range better than cuteness does.
- **Leaderboards from day one**, for the same reason.
- **Guard bounce rate above all else during M5.** If `<60 s` bounce is high, stop recruiting and fix the FTUE — sending more people into a leaky first minute teaches the algorithm the wrong thing and burns the channel.
- The 50,000 Robux expedited review exists as a paid escape hatch if the 250 bar stalls. Refundable. Philip's call; Claude never spends money.

**What would tell us we are wrong:** 16+ players completing the FTUE but not returning on day 2. That would mean the game reads as "for little kids" — fixable with tone, not mechanics.

---

## Risk 5 — World First runs dry, and nothing replaces it

World First is the answer to Risk 1 — so its durability matters more than the brief realised.

⚠️ **The brief says "thousands of combinations". The real number is 876 distinct creatures** (12 gen-1 + 144 gen-2 + 720 gen-3), plus 6,132 mutation entries.

With a few hundred players that lasts months. **At 100k players, all 876 species firsts would be claimed within days** — and then the headline feature is a museum of other people's names.

**Severity: medium.** It only bites if the game succeeds, which makes it easy to under-plan.

**Mitigation (built into the design):**
- **Two tiers of firsts**: Species First (876, permanent) and **Mutation First** (6,132, rarer, ongoing).
- **Every content update adds base species.** Four new species per season adds 4 gen-1, 100 gen-2 and 500 gen-3 keys — roughly doubling the space each season, at the cost of a config edit. This is the cheapest content in the project (`docs/LIVEOPS.md` §2).
- **Seasonal mutations** re-open a Mutation First sweep across the entire existing roster at zero content cost.
- The Fusion Book gives a personal completion goal that survives the global firsts being gone.

**What would tell us we are wrong:** `world_first_claimed` events falling toward zero while daily active users hold steady. That is the signal to ship species early, not on the seasonal calendar.

---

## Also on the radar

Not top-five, but tracked:

| Risk | Where it lives |
|---|---|
| **The PRI question on time-skip items is unresolved** — `turboIncubators`, `fusionPro`, `skipHatch*`, `skipFusion*` buy time, not odds; our reading is they are outside the PRI definition, but it is unconfirmed | `docs/COMPLIANCE.md` §2 — resolve in Phase 5, before launch |
| **Gambling imagery would force a Moderate label** and lose the Kids tier entirely — easiest thing to break by accident during the art pass | `docs/GDD.md` §7, hard art rule |
| **`fusionPro` may become mandatory** — the single fusion slot is the economy's main throttle, which makes a second slot the most powerful purchase in the game | `docs/MONETIZATION.md` §3 — re-check at M3 |
| **Snatching is tested against NPCs, not humans** — the fairness numbers are guesses until real players arrive | `docs/CONFIG.md` snatch.* — all live-tunable, and the rule is always to weaken snatching, never strengthen it |
| **Audience Expansion pays nothing until 100+ DAU for 60 days** — it must not appear in any launch revenue plan | `docs/MONETIZATION.md` §5 |
| **Quick Words is unverified** and the brief leans on it for Kids communication | `docs/VERIFY.md` — the game is complete without it |

---

## What the brief got right

Worth saying, since the above is all criticism:

- **Compliance-by-construction.** The currency firewall is a genuinely good idea and it survived contact with the actual policy — Roblox's first listed treatment for restricted players is exactly the unpaid-earnable-path argument the brief constructed.
- **Phone-first as a hard constraint** rather than an aspiration, which forced the pipeline design that makes any of this possible.
- **"No bought advantage for stealing."** A game where paying players rob non-paying children would be both wrong and a moderation risk. Getting that right before writing any code is the mark of a serious plan.
- **Designing stopping points on purpose.** Most idle games do the opposite, and it is the right call for a young audience.
- **Insisting on verification before depending on platform facts.** That instruction is what surfaced Risks 1, 4 and 5.
