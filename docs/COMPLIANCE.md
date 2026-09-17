# COMPLIANCE.md

Phase 1.1. The rules we must not break, why, and the draft Maturity & Compliance Questionnaire answers.

Sources and verification dates: `docs/VERIFY.md`. Everything marked ✅ was read in Roblox's own documentation on 2026-09-16.

---

## 1. Target rating

**Minimal.** Mild is acceptable; Moderate is not.

Verified label gates:

| Label | Who can play |
|---|---|
| **Minimal / Mild** | Roblox Kids (5–8), Roblox Select (9–15), Roblox (16+) |
| Moderate | Select (9–15) and 16+ only — **no Kids** |
| Restricted | age-verified 18+ only |

Our core audience is 9–15 and the brief wants 5–8 once eligible. **Moderate loses us the Kids tier entirely**, so every design decision that could raise the label is a real cost.

### The one that nearly caught us

**"Unplayable gambling content" forces Moderate.** Roblox defines gambling as "exchanging real world money, Robux, or in-experience items of value for a game of chance", and states experiences "cannot contain playable gambling content, including simulated gambling."

Paid random items are a **separate descriptor** and — as far as the documentation shows — do **not** raise the maturity label. So eggs and fusion are compatible with Minimal. But **gambling imagery is not**.

> ### 🚫 Hard art rule
> **No casino visual language anywhere in the game.** No prize wheels, no slot-machine reels, no playing cards, no dice, no chips, no jackpot levers.
>
> The Egg Market is a **vending machine / market stall**. The Fusion Lab is a **kitchen**.
>
> This is the single cheapest compliance win in the project and the easiest to lose by accident during the art pass.

⚠️ Confidence note: that paid random items do not raise the label is **inferred from the structure of the docs**, which never state a label consequence for that descriptor. Philip's actual questionnaire result is the real answer — flagged in `docs/PHILIP-TODO.md` task 7.

---

## 1a. The kid-safety gate — enforced, not reviewed

`python3 tools/validate-kid-safe.py`, run by `scripts/check.sh` and by CI.

Everything in this document that can be checked mechanically now is, because a
rule that lives only in a doc is a rule somebody breaks during an art pass. It
scans **string literals only**, so `instance:Destroy()` is never mistaken for
the word "destroy" shown to a player.

| Rule | Why it is a gate and not a guideline |
|---|---|
| No casino language or imagery | "Unplayable gambling content" forces a **Moderate** rating, which loses the Roblox Kids tier outright. The cheapest compliance win we have and the easiest to lose by accident. |
| Nothing violent or frightening | The audience is 9–15, then 5–8. "Snatch", "steal" and "thief" are the brief's own words for a friendly mechanic and are deliberately allowed. |
| No menacing emoji | 😈 👹 💀 🔫 🎰 🃏 🎲 and friends. An emoji is content. |
| No internal text reaching a player | A sentence containing `nil`, `RemoteEvent` or "invalid request" is a bug, not a message. |
| Every rarity has a text label | Colour alone is unreadable for roughly 1 in 12 boys (`docs/GDD.md` §5.16). Checked structurally against `Style.RARITY`. |

**Verified to fail.** Three deliberate violations were introduced and each rule
fired. A check that cannot fail is worse than no check — see `docs/DECISIONS.md`
D-018, where a green-but-inert format gate went unnoticed for the life of the repo.

**Word boundaries, not substrings.** The first run flagged "shell" for containing
"hell" — the same trap the name blocklist already fell into with "Titan" and
"tit" (`docs/NOMLINGS.md` §4). Unlike generated names these strings are real
English written by us, so a `\b` match is the correct fix rather than an allowlist.

---

## 2. Paid random items — the big one

### What counts as a PRI in our game

✅ Verified against Roblox's [paid random items policy](https://create.roblox.com/docs/en-us/production/monetization/paid-random-items.md):

| Our feature | PRI type | Why |
|---|---|---|
| **Eggs** | Capsule item | "hatch an egg for a pet" is Roblox's own example |
| **Fusion** | **Combination item** | Roblox's own example: "consuming or synthesizing two rare eggs for a better chance of a higher-quality result" |
| `luckyPaws`, `luck15` | Probability modifier | "luck boosts" is Roblox's own example |

**Fusion being a PRI is easy to overlook and is not optional.** Its outcome odds must be disclosed exactly like an egg's.

### Disclosure requirements

| Requirement | Our implementation |
|---|---|
| Show **all possible outcomes with actual numerical odds** | Odds panel per egg and per fusion |
| Odds as **percentages summing to exactly 100%** | Stored as integer ppm summing to 1,000,000; CI-asserted |
| A pop-up is acceptable **only with a descriptive word**, not a bare (i) | Button reads **"Odds"** — never an icon alone |
| Odds **update live** while a modifier is active | Odds panel recomputes whenever `luckyPaws`/`luck15` is active |
| Applies to **indirect** purchases too | Coin packs are Robux→coins→eggs, so the whole chain is covered |
| One-instance-only outcomes must show **remaining** odds | Applies if any Nomling becomes once-per-player |

Rounding is explicitly permitted: round to four or more decimal places below the first non-zero digit, with a disclaimer. Our exact-ppm approach is stricter and needs no disclaimer. The Basic Egg's Secret at 0.0001% is exactly representable.

**Free randomness is exempt.** Weather mutations and quest rewards involve no payment, so no disclosure is required. **We disclose anyway** — it costs nothing and builds trust. Recorded as a choice, not an obligation.

### `ArePaidRandomItemsRestricted`

When true, the player "cannot interact with paid random item generators, either through Robux directly or game currency bought with Robux."

Our treatment: **hide all Tier 1 and Tier 2 items**, making coins unbuyable for that player, so eggs and fusion become an **unpaid, earnable path** — Roblox's first listed treatment. Plus `exclusive_*` Nomlings give them a guaranteed direct-purchase route, which is Roblox's third.

The full six permitted treatments are in `docs/VERIFY.md` §3.4.

⚠️ **Open question, highest priority in Phase 5:** do `turboIncubators`, `fusionPro`, `skipHatch*` and `skipFusion*` count? They buy time, not odds or currency. Our reading is no. Needs a `compliance-reviewer` pass and, if unresolved, a DevForum question before launch.

### `IsPaidItemTradingAllowed`

When false, the player must not be able to trade paid items or PRI outcomes. **Moot in v1 — there is no trading.** When trading lands in Update 1 it must respect this flag from day one, and Bonded items stay untradeable for everyone.

---

## 3. Questionnaire — draft answers

To be completed by Philip in Creator Hub (`docs/PHILIP-TODO.md` task 7). Answer for **the most extreme content a player can encounter.**

| Category | Answer | Reasoning |
|---|---|---|
| **Violence** | **Yes — Mild, Repeated** | The Bubble Wand traps a player in a bubble. It is non-damaging, unrealistic and instantly reversible, but it *is* force used against another player, so we disclose it. It happens often, so "Repeated". Mild is defined as "implied or unrealistic depictions... such as bodies disappearing the moment their health reaches zero" — bubbling is well inside that. **Mild violence is still Kids-eligible.** |
| **Blood** | No | None anywhere. |
| **Fear** | No | Bright, silly, no horror, no jump scares. |
| **Crude humour** | No | Snack puns only. No bodily-function jokes — this is a deliberate design constraint, since crude humour pushes toward Mild/Moderate. |
| **Unplayable gambling content** | **No** | And it must stay no. See the hard art rule in §1. |
| **Strong language** | No | No chat. Generated names pass a blocklist test in CI. |
| **Romantic themes** | No | None. No private spaces, no adult settings. |
| **Alcohol** | No | Snacks only. No "Root Beer Raccoon" or similar — added to the name blocklist. |
| **Social hangout** | **No** | The primary activity is hatching, fusing and defending. Not a hangout, not a vibe game. Our title and description must never suggest otherwise, since Roblox classifies on metadata too. |
| **Free-form user creation** | **No** | No drawing, no text input, no user-authored content. Nomling names are generated by us from curated tables, not written by players. **This is also a rewarded-video eligibility requirement.** |
| **Sensitive issues** | No | None. |
| **Paid random items** | **Yes** | Eggs, fusion, luck items. |
| **— respects `ArePaidRandomItemsRestricted`?** | **Yes** | See §2. |
| **Paid item trading** | **No** in v1 | Becomes Yes in Update 1. |
| **— respects `IsPaidItemTradingAllowed`?** | Yes (when trading ships) | |
| **Media — users share media from gameplay?** | No | Creator Mode uses Roblox's own capture features; we build no in-experience sharing. |
| **Media — content feeds with continuous loading or autoplay?** | **No** | And never will. See §4. |
| **Media — view content captured from other experiences?** | No | |
| **AI interaction** | **No** | Text-to-speech reads a name we generated. Players cannot interact with a generative model, there is no cross-session memory, and no AI character. Generative AI used to *build* the game is explicitly out of scope for this question. |

**Expected result: Minimal, with a Paid Random Items descriptor.** Kids- and Select-eligible.

⚠️ If Philip resubmits the questionnaire after any update that changes an answer, Roblox requires it — and a mismatch between answers and content risks losing the label entirely or worse.

---

## 4. Standing prohibitions

| Never | Why |
|---|---|
| A media feed with autoplay/looping/auto-scroll plus a reward for continued watching | Brief §3.1. ⚠️ *Our* rule — the audience consequence is not stated in Roblox's docs (`docs/VERIFY.md`). We follow it regardless. |
| Free-form user text or images | 16+ only, and blocks rewarded video |
| Off-platform links in-game | Use the approved social links on the game page |
| Rewarding likes, favourites, group joins or notification opt-ins | Check Community Standards and log the decision before any such reward. Also: Roblox deprioritizes metadata "leading with giveaways" in discovery. |
| Forced ads, or ads before eligibility | Voluntary button only |
| Any purchase that buys snatching advantage | Our own rule, §5.1 of the brief |
| Infinite reward loops | Design rule and compliance rule |

---

## 5. Notifications

Opt-in only, asked at a meaningful moment — **the "Kitchen's cooking" stopping point at ~15 minutes**, when a reminder is genuinely useful. Never at join. Within Roblox's content and frequency rules. Never rewarded (see §4).

---

## 6. Privacy and data

- Only gameplay data, keyed by `UserId`. **No personal data, ever** — no names, no ages, no locations, no free text.
- Analytics events carry no identifying content.
- **Right to Erasure:** Roblox forwards deletion requests; we must be able to delete a user's data on request. Runbook in `docs/RUNBOOKS.md`, and the process must be testable in TEST before launch.
- TEST and PROD use separate DataStores so test activity never touches player data.

---

## 7. Intellectual property

- Original names and designs only. Base roster screened (`docs/TITLES.md`) — Taco Cat was replaced over the "Tacocat" meme.
- **Every generated name is screened in CI.** The name-safety test enumerates the full cross-product (876 names today) against profanity in multiple languages, a brand list, and Roblox filter terms. It fails the build on any hit — no sampling.
- No meme IP, no real-world brands, no copyrighted music.
- `assets/manifest.json` records every asset's ID, source and licence. An asset without a manifest entry does not ship.

---

## 8. Anti-exploit

Server authority on everything that touches coins, inventory, odds or ownership. Every remote validates type, range, ownership and proximity, with per-player token buckets. **Never trust client position while a player carries a Nomling.**

**Prefer soft measures to bans.** Our audience is children who may not understand what they did. Rate-limit, reject, correct and log — escalate only on sustained, deliberate abuse.

---

## 9. Kids/Select readiness checklist

- [x] Fully playable and fun with **zero chat** — emote wheel, direction arrows, icon-led UI
- [x] Not a social hangout
- [x] No sensitive topics
- [x] No free-form creation
- [x] Minimal/Mild content
- [x] No gambling imagery
- [ ] Creator verified (ID) + 2FA — *Philip, task 2*
- [ ] Plus/Premium 2 consecutive months, or the refundable fee — *Philip, task 1, in progress*
- [ ] 250 unique plays from highly engaged age-checked players in 60 days — *M5*
- [ ] Questionnaire submitted and approved — *Philip, task 7*

⚠️ **Quick Words is unverified** (`docs/VERIFY.md` §3.3). The brief leans on it for Kids communication. The game must be complete without it, and it is.

---

## 10. Honest store page

Thumbnails and description must show the real game. Beyond being right, it is also mechanical: Roblox deprioritizes "mismatched metadata and content" in recommendations, and reduced-exposure games are flagged on the Creator Dashboard. See `docs/STORE-PAGE.md`.
