# KICKOFF BRIEF: "Fuse a Nomling" (working title)
_A phone-first Roblox game by Philip, built with Claude Code. Brief written 2026-09-16._

> **Claude, read this entire brief before you do anything.** It is the source of truth for scope, design, monetization, compliance and workflow. In Phase 0, save it unchanged as `docs/00-kickoff-brief.md` so every future session can re-read it. Then follow §13 (Phase plan), starting at Phase 0. At every **STOP**, wait for Philip's OK.

---

## 1. Mission

Build and launch an original, mobile-first Roblox game that can become a global hit with players aged about 9–15, and 5–8 once the game is eligible. It must also be fun for the 16+ players that Roblox shows new games to first.

- **The game:** hatch silly snack-animal creatures called **Nomlings** and earn coins from them.
  - **Fuse** two Nomlings into a brand-new, procedurally generated creature.
  - Defend your base from friendly **snatchers**.
- **The viral engine:** surprise fusion reveals and "World First" discoveries.
- **Money:** revenue is designed in from day one. Every purchase must be fair, clearly priced and compliant with Roblox policy.
- **Phone-first:** Philip works mostly from his iPhone. The pipeline (code → build → test → publish to a TEST place) must run without Roblox Studio.

## 2. Who you are working with

- **Time:** Philip is a solo developer in Sweden with a full-time IT job, so his time is limited. Assume about 8–10 hours a week of his attention and confirm this in Phase 0. You do the heavy lifting.
- **Background:** he knows web technologies, Python and AI tooling, but is **new to Roblox and Luau**.
  - The first time a Roblox concept appears, explain it in one or two plain sentences.
  - Use web analogies when they help: RemoteEvent ≈ a websocket message, DataStore ≈ a key-value database, ModuleScript ≈ a JS module.
- **Device:** he works mainly from an **iPhone**. Keep chat reports short and scannable, and put the details in files. If he sends screenshots, use them.
- **Language:** he writes in Swedish or English. Reply in the language of his latest message. Code, comments, docs and commit messages are always in English.

## 3. Platform facts that shape everything (as of September 2026)

Verify every point in Phase 0 against official sources, and log confirmations and contradictions in `docs/VERIFY.md` with URL and date. Sources:
- Docs index: `https://create.roblox.com/docs/llms.txt` (most doc pages are also served as `.md`).
- Open Cloud index: `https://create.roblox.com/docs/cloud/llms.txt`.
- Roblox DevForum announcements.

### 3.1 Age tiers and the launch gate

Roblox splits accounts into **Roblox Kids (5–8)**, **Roblox Select (9–15)** and **Roblox (16+)**.

**Every new game starts with age-checked 16+ players only.** Reaching under-16s requires all of the following:
- **Verified creator:** an age-checked account, verified with government ID if the creator is 18+.
- **Security:** 2-Step Verification on the account.
- **Fee or subscription:** either a one-time refundable per-game fee, or a Roblox Plus/Premium subscription active for 2+ consecutive months.
- **Evaluation:** **250 unique plays from "highly engaged" age-checked players within 60 days**, plus a safety review.
- **Optional shortcut:** an expedited review for a refundable 50,000 Robux.

**Content rules:**
- Kids accounts only see **Minimal/Mild** content, Select accounts up to Moderate. **Target: Minimal (Mild at most).**
- Kids have chat off by default. Games centered on social hangouts, sensitive topics or free-form drawing are excluded by default. → **The game must be fully fun with zero chat.**
- **Banned for Kids/Select:** a media feed (videos, images, posts) combined with autoplay, looping or auto-scroll, combined with a reward for continued watching. → Never build anything feed-like.

**Testing access:** private games are restricted to accounts with edit permissions. Testers are added through Audience → Limited → Playtesters.

**Strategic consequence:**
1. The launch must first win age-checked 16+ players. Use teen-friendly absurd humor and competitive leaderboards.
2. Only after Kids/Select eligibility do we go loud on kid-heavy social platforms.

### 3.2 What discovery rewards

Home Recommendations weigh these signals:
- **Play-through rate:** driven by the icon, title and thumbnail.
- **First-play bounce rate:** leaving within 60 s, or within 61–180 s, counts against the game.
- **Play days per user.**
- **7-day playtime:** capped per day.
- **Spend days and Robux spent per user.**
- **Intentional co-play:** joining friends, invites, private servers.

Changes announced at RDC 2026:
- Ranking is becoming age-aware: shorter-form games for younger players, deeper return-visit games for older ones.
- Engagement is measured over the first 28 days and beyond.
- A "direct growth" signal (bringing new players to Roblox) is being tested.

→ The first 60 seconds are sacred, daily return reasons are mandatory, and playing with friends must be rewarded.

### 3.3 Money tools available

**Basics:**
- Game passes, developer products and paid private servers.
- Regional Pricing (passes and developer products), Price Optimization, developer product discounts, and Experiments.

**Roblox Plus ($4.99/month):**
- Subscribers get 10–20% off purchases (Roblox covers the discount) and free private servers.
- Creators earn up to 100 R$ per subscriber who spends 60+ minutes a month in their paid private servers.
- Creators also earn 250 R$/month for the first 3 paid months of each subscriber who signs up in-game via `PromptRobloxSubscriptionPurchase`.

**Creator Rewards:**
- **Daily Engagement:** 5 R$ per day for each Active Spender who plays 10+ minutes, if the game is among the first three they launch that day.
- **Audience Expansion:** 35% of the first $100 of Robux purchases made by new or returning users (60+ days inactive) during their first two months. It is credited when they arrive through the game's links, or search the game by name, and play 10+ minutes.

**Rewarded Video ads:**
- Requirements: a public, unrestricted experience with 2,000+ unique monthly visitors, a creator who is 13+ with ID verification and 2FA, and a completed maturity questionnaire.
- The reward must be a developer product, never Robux.
- Under-13 users aren't eligible. Check `GetAdAvailabilityNowAsync` before showing any ad button.

**DevEx:**
- Standard rate: $0.0038 per earned Robux.
- About $0.0054 on eligible in-game spend by age-checked 18+ US players, in games using R15 avatars or equivalent rigs (verify the exact eligibility). → **Use R15.**
- Minimum cash-out: 30,000 earned Robux.

**Coming soon:**
- Browser play in Chrome (end of 2026).
- Game-page videos in the Moments feed (US).
- Preset **Quick Words** chat phrases that any age can use.
- Roblox Wallet (US first, international in 2027).
- Launching ads from a phone.

### 3.4 Paid random items (PRI) and trading

**Definition:** a PRI is a random outcome bought with Robux, **or with in-game currency that can be bought with Robux**. It includes:
- Capsules, e.g. eggs.
- Enhancements.
- **Combinations**, e.g. fusing items for a chance at a better result.
- **Probability modifiers:** luck boosts, pity systems, enhanced drops.

**Disclosure rules:**
- Before purchase, show every possible outcome with numeric odds that sum to exactly 100%.
- A pop-up is fine if its button has a word label such as "Odds" or "Details". A bare (i) icon is not enough.
- Odds must update live while a modifier is active.
- Every outcome must give some value.

**Per-player rules** from `PolicyService:GetPolicyInfoForPlayerAsync()`:
- If `ArePaidRandomItemsRestricted` is true, that player must not access PRI. Allowed treatments:
  - an unpaid, earnable path;
  - a disclosed fixed order;
  - direct purchase of specific outcomes;
  - hiding the item;
  - blocking it with a message;
  - keeping the player out of PRI areas.
- If `IsPaidItemTradingAllowed` is false, the player must not trade paid items or PRI outcomes.

Read the DevForum post "Clarifying Requirements for Paid Random Items" (mid-2026) before finalizing the design.

### 3.5 Tools that make a phone-first workflow possible

**Open Cloud** (`apis.roblox.com`, API key in the `x-api-key` header):
- **Place publishing.**
- **Luau Execution:** runs scripts headlessly against a place version. Tasks last at most 5 minutes, with a concurrency limit per place (check the current number), and can save the place.
- **Experience Configs:** change live values without publishing; supports experiments.
- **Messaging:** broadcast a message to all live servers.
- **Developer Products and Game Passes APIs:** beta, multipart/form-data.
- Also: DataStores, Notifications, Analytics, Private servers and Sponsored campaigns.

Reference repo: `github.com/Roblox/place-ci-cd-demo` (Rojo + Selene + StyLua + Luau Execution tests in GitHub Actions).

**Studio's built-in MCP server** (local only; Studio must be open) can:
- read and write scripts, and explore the data model;
- run Luau and insert assets;
- run playtests and simulate input;
- capture the viewport.

**AudioTextToSpeech:** preset English voices with pitch and speed controls, rate-limited by concurrent users.

---

## 4. The game

### 4.1 Pitch

- **Working title:** Fuse a Nomling. Alternatives to evaluate: Nomling Fusion, Fuse & Snatch. The "Verb a Noun" pattern matches recent breakout hits.
- **Logline:** Hatch silly snack-animals, fuse them into ridiculous new creatures, and guard your base from sneaky snatchers.
- **Nomlings** are animal + snack hybrids. Placeholder starter set of 12:
  - Taco Cat, Sushi Pup, Pizza Penguin, Donut Duck
  - Burger Bear, Noodle Frog, Popcorn Pig, Waffle Walrus
  - Cupcake Croc, Pickle Parrot, Mochi Mole, Nacho Narwhal

  In Phase 1, screen every name for existing brands and trademarks, and replace any that conflict.
- **The hook:** fusing two Nomlings creates a new creature with a generated look and name (for example Sushi Pup + Waffle Walrus → "Sushiwal").
  - 12 base Nomlings, ordered pairs, mutations and three generations add up to thousands of combinations.
  - All of them are built from code, not hand-made assets.
- **Genre fit:** it combines two of the fastest-growing Roblox formats (steal-and-defend tycoons and idle-grow simulators) with a fusion twist that no current hit owns.

### 4.2 Design pillars

1. **"What did I just make?!"** Every fusion is a surprise reveal worth recording.
2. **Big numbers, fast.** Growth is visible every minute.
3. **Friendly chaos.** Snatching is dramatic but never devastating.
4. **Bite-sized or binge.** Both a 3-minute check-in and a 30-minute session feel good, and there is always a natural stopping point.
5. **One-glance readable on a phone.** Icons, colors and motion come before text. The game is fun without chat.

### 4.3 Audience and tone

- **Audience:**
  - Core: ages 9–15.
  - Also 5–8, once eligible.
  - Launch trial audience: 16+. The humor must be absurd enough that teens share it ironically.
- **Tone:** bright, silly and clean.
  - No blood, weapons, romance, crude humor, horror or real-world brands.
  - Target content maturity: Minimal (Mild at most).

### 4.4 Core loop

1. Buy an egg with coins.
2. Hatch it (timer).
3. Place the Nomling on a pedestal; it earns coins per second.
4. Collect the coins.
5. Buy better eggs **or** fuse two Nomlings at the Fusion Lab.
6. Weather mutations boost value.
7. Snatch from others and defend your own base.
8. Rebirth for a permanent multiplier and a new egg tier, then repeat.

**Session anchors:**
- Egg restock every 5 minutes.
- Hatch and fusion timers.
- A weather event every 12–20 minutes.
- Daily rewards and quests.
- Weekend global "Nom Storm" events.

### 4.5 Systems (v1 scope)

**A. Server and plots**
- 8 players per server, with 8 plots around a central plaza.
- The plaza holds the Egg Market, the Fusion Lab with a big public reveal stage, leaderboards, an event stage and a podium.
- A plot exists only while its owner is in the server.
- Each plot has:
  - 8 pedestals (coin upgrades to 16);
  - 2 incubators (coin upgrades to 4);
  - 1 **Vault** pedestal whose Nomling can't be snatched;
  - a collect pad;
  - a **Laser Gate** button;
  - an owner sign showing name and income per second.

**B. Eggs and the Egg Market**
- **Egg tiers:** six, unlocked by rebirths: Basic, Picnic, Bakery, Sushi Bar, Candy Cloud, Cosmic Diner.
- **Restock:** every 5 minutes, synced to UTC (`cycleId = floor(unixTime / 300)`) so all servers match.
  - Stock is personal, so there are no fights at the counter.
  - Basic eggs are always available.
  - A **Golden Egg** appears in about 5% of cycles and is announced server-wide.
- **Odds:** every egg has an **Odds** button.
  - Odds are stored as integer parts-per-million (ppm) and must sum to exactly 1,000,000.
  - Starting example for the Basic Egg:

  | Rarity | ppm | Shown as |
  |---|---|---|
  | Common | 700,000 | 70% |
  | Uncommon | 220,000 | 22% |
  | Rare | 65,000 | 6.5% |
  | Epic | 13,000 | 1.3% |
  | Legendary | 1,900 | 0.19% |
  | Mythic | 99 | 0.0099% |
  | Secret | 1 | 0.0001% |

- **Rarity display:** each rarity has a color, an icon and a text label, so it stays readable for colorblind players.

**C. Hatching**
- Timers run from 5 s (the first Basic egg) up to 30 min (Cosmic).
- The reveal lasts 2–3 s and is skippable after the first time. It shows:
  - a rarity banner;
  - confetti scaled by tier;
  - the Nomling "saying" its own name through text-to-speech with a random pitch. Fall back to sound effects when rate-limited.

**D. Nomling genome and procedural models**
- `genome = { animal, snack, palette, pattern, eyes, accessory, sizeScale, mutation, gen, parents }`
- The client builds each model from its genome with a seeded RNG.
  - At most about 30 parts per Nomling in v1.
  - One consistent "chunky toy" style.
- The server replicates only genomes and simple hitboxes.
- Keep an upgrade path to MeshParts that doesn't change the genome format.

**E. Income**
- **Starting base income per tier (coins/s):**

  | Tier | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
  |---|---|---|---|---|---|---|---|
  | Coins/s | 1 | 4 | 15 | 60 | 300 | 2,500 | 50,000 |

- **Multipliers:** mutation, generation, rebirth, friends-in-server bonus, passes.
  - All formulas live in pure shared modules.
  - The economy simulator (§7.6) tunes every number.
- **Offline earnings:** 25% efficiency, capped at 2 h (4 h with VIP).

**F. Fusion (the star feature)**
- **Flow** at the plaza Fusion Lab:
  1. Choose two Nomlings; both are consumed.
  2. A timer runs (30 s to 20 min, by tier).
  3. The result is revealed publicly on the big screen.
  4. The new Nomling flies to the owner's base.
- **Inheritance rules** (starting values):
  - **Look:** body shape from parent A, snack traits from parent B (or another clearly documented rule).
  - **Name:** a portmanteau built from curated syllable tables.
  - **Tier:** the higher parent's tier, with a chance to upgrade: 12% if both parents share a tier, 5% otherwise.
  - **Income:** (A + B) × 1.3 × generation bonus.
  - **Mutation:** a chance to inherit a parent's mutation.
- **Generations:** capped at 3 in v1. Gen 3 creatures are "Mega": bigger, with an aura.
- **Odds:** before confirming, show the fusion's outcome odds (tier upgrade and mutation inheritance). Show them to everyone.
- **Fusion Book:** tracks discovered combinations. Completion milestones give fixed rewards.
- **World First:** the first player anywhere to create a combination gets:
  - a global banner in every server;
  - permanent "Discovered by" credit in the book.

  Implement it with a DataStore `UpdateAsync` on `firsts/<comboKey>` (first writer wins) plus a `MessagingService` broadcast.

**G. Weather and mutations (free)**
- Every 12–20 minutes per server there is a 90 s weather event, announced 30 s ahead with a sky change:

  | Weather | Multiplier |
  |---|---|
  | Golden Glaze | ×3 |
  | Rainbow Sprinkles | ×5 |
  | Frost Sugar | ×2 |
  | Lava Salsa | ×4 |
  | Galaxy Jelly (rare) | ×10 |

- Each Nomling on an open pedestal has a small mutation chance per tick (a config value).
- **Nom Storm:** a weekend event that an admin triggers globally. It boosts mutation chances and adds the special "Nomzilla" mutation (giant size, ×8).
- Show the chances in an info panel even though weather is free.

**H. Snatching (friendly PvP)**
- **How it works:**
  1. Enter an unlocked base and hold on a Nomling for 1.5 s. Vault and Bonded Nomlings can't be taken.
  2. You carry it, 30% slower, with a glowing trail. The owner gets an alarm and a direction arrow.
  3. Reach a free pedestal on your own plot and the Nomling is yours.
  4. After 40 s of carrying, it pops back home.
- **Bubble Wand:** everyone has one for defense.
  - One hit traps the carrier in a bubble for 2 s, and the Nomling zips home.
  - 3 s cooldown.
  - The bubbled player gets 3 s of immunity, so nobody gets stun-locked.
- **Laser Gate:** locks the base for 60 s, then has a 90 s cooldown (config values).
- **Fair-play rules:**
  - Newcomer shield for the first 20 minutes of total playtime.
  - No snatching from players whose income per second is under 20% of yours.
  - One attempt per target per 60 s.
  - Vault and Bonded Nomlings are always safe.
- **Loss softener:** the victim gets a Comeback Egg of the same tier, with a 2-minute hatch.
- **Chill Mode:** private server owners can switch snatching off.
- **Tutorial:** during the first-time experience, an NPC raccoon, "Sneaky Sam", steals once, and the player bubbles him to learn the mechanic safely.

**I. Rebirth ("Re-Nom")**
- Costs a scaling amount of coins.
- **Resets:** coins, base Nomlings and coin upgrades.
- **Keeps:** the Fusion Book, Vault Nomlings, Bonded Nomlings, passes and cosmetics.
- **Grants:**
  - a permanent income multiplier;
  - the next egg tier and a new plot theme;
  - a Rebirth Token for a small perk tree with fixed effects.

**J. Daily systems and stopping points**
- A 7-day login calendar with fixed rewards and a one-day grace period.
- 3 daily quests (for example: hatch 5, fuse 2, bubble 3 snatchers) and 1 weekly quest.
- **Natural stopping points:**
  - When all incubators and fusions are busy, show a friendly "Kitchen's cooking! Back in 12 min" screen.
  - A "Quests done for today" screen.
  - Offline earnings caps.
  - Daily caps on rewarded ads.
  - No infinite reward loops.

**K. Social**
- **Invites and referrals:**
  - Invites go through `SocialService`.
  - When an invited friend has played 10 minutes, both players get a Buddy Egg. Use join data to detect referrals.
- **Friend bonus:** +10% income per friend in the server, capped at +30%.
- **Communication and sharing:**
  - An emote wheel, plus Quick Words once they are available.
  - Gifting purchases to a player in the same server.
  - A podium "show off" pose.
- **Announcements:** server-wide banners for big hatches, fusions and World Firsts.

**L. Leaderboards**
- Four boards:
  - income per second (weekly and all-time);
  - World Firsts;
  - Fusion Book completion;
  - weekly Snatch Master.
- They use OrderedDataStores refreshed every 60–120 s, and are shown both in the plaza and in the UI.

**M. Codes**
- Redeemable codes are defined in live config (JSON), with one use per player and an expiry date.

**N. Creator Mode**
- Hides the UI, adds an orbit camera, and replays your last reveal in slow motion.
- Use Roblox capture and share features where available.
- This makes the game easy for TikTok and YouTube creators to film.

**O. Admin and live ops**
- **In-game admin panel,** visible only to user IDs on an allowlist in config. It has full tools in TEST and limited tools in PROD:
  - trigger weather, or a global Nom Storm;
  - broadcast a banner;
  - force a Golden Egg restock;
  - grant test items (TEST only);
  - soft shutdown.
- **`tools/trigger-event`:** a script that broadcasts events to all servers through Open Cloud Messaging.

**P. Settings and accessibility**
- Music, sound effects and text-to-speech toggles.
- Reduced motion, large text and a haptics toggle.
- Colorblind-safe rarity display (color + icon + label).

**Q. Not in v1** (backlog)
- **Update 1:** trading, with full compliance and a scam-proof two-sided confirmation screen.
- **Update 2:** Season Pass.
- **Later:**
  - custom naming or any other user-generated text or images;
  - clans, UGC avatar items, a standalone app, offline mode.

### 4.6 First-time user experience (target timeline)

| Time | What happens |
|---|---|
| 0–10 s | Spawn at your own plot. A free egg is already hatching (5 s countdown). |
| ~10 s | First reveal, with name callout and confetti. |
| 10–30 s | An arrow guides you to place it on a pedestal. Coins start popping. |
| 30–60 s | First collect, then a guided purchase of a second egg. |
| 60–180 s | "Fuse them!" An 8 s fusion, then your first public reveal. |
| 3–5 min | A forced first weather event. Sneaky Sam steals and you bubble him. |
| 5–8 min | Rebirth goal and daily rewards are introduced. The first offer (Starter Pack) appears only after the first fusion **and** 5+ minutes of play. |
| ~15 min | All incubators busy: "Kitchen's cooking" stopping point, then an opt-in notification prompt. |

Log every step with `AnalyticsService` onboarding funnel events.

### 4.7 Art and audio direction

- **Style: "toy food court diorama."**
  - Chunky rounded shapes and a saturated candy palette.
  - Future lighting, soft atmosphere, bloom on neon accents, gentle color correction.
  - Define palette tokens and material rules in one shared style module.
- **Licensing:**
  - Use only original work, or properly licensed Creator Store assets and Roblox-licensed music.
  - No meme IP, brands or copyrighted songs.
  - Keep `assets/manifest.json` with each asset's ID, source and license.
- **UI:**
  - A bold rounded font (verify availability) and big icons.
  - Number abbreviations: K, M, B, T, Qa, Qi, and so on.
  - Juicy tweens, and haptics on key moments.
- **Audio:** pops, squeaks, "nom" sounds, rising tones for higher rarities, and text-to-speech name callouts.

### 4.8 Clip moments (design for these on purpose)

- A fusion reveal, or the World First banner.
- A Galaxy mutation, a Nomzilla, or a Golden Egg restock.
- A snatch chase that ends in a bubble save.
- A rebirth explosion, or the Nom Storm countdown.

---

## 5. Monetization

### 5.1 Rules (non-negotiable)

1. **Fun first.** Nothing needed to enjoy the core loop is behind a paywall.
2. **No bought advantage for stealing.** Robux never buys a permanent snatching advantage, so no speed or strength passes. Defensive perks are fine.
3. **Show real prices.** Fetch price info from `MarketplaceService` at runtime, so Regional Pricing, Price Optimization and discounts display correctly. Never hardcode displayed prices.
4. **No manipulative timing:**
   - no offers right after a loss or failure;
   - no fake timers or fake scarcity;
   - at most one unsolicited offer per session;
   - never interrupt a reveal.
5. **Bonded items.** Nomlings bought with Robux can't be snatched or traded.
6. **Catalog as code.**
   - The whole catalog lives in `monetization/catalog.json`.
   - It syncs to Roblox through Open Cloud.
   - It generates `src/shared/Generated/CatalogIds.luau`.

### 5.2 The currency firewall (compliance by construction)

**Coins** are the only currency. Eggs and fusions cost coins.

Every catalog item carries a risk tier:

| Tier | Covers | Examples |
|---|---|---|
| **1 — odds/currency** | Anything that sells coins or changes odds | Coin packs, luck boosts |
| **2 — currency multipliers** | Anything that multiplies coin income | 2× Coins |
| **3 — indirect/deterministic** | Everything else | Slots, timer speed, vault, offline cap, cosmetics, deterministic server boosts |

**Players with `ArePaidRandomItemsRestricted = true`:**
- Hide all Tier 1 and Tier 2 items, and ignore such effects if they already own them (for example after travelling).
- Their coins are then never bought with Robux, so hatching and fusing remain an unpaid, earnable path.
- **This interpretation needs verification** (§3.4). If official guidance disagrees, switch those players to a stricter treatment and ask Philip.

**For everyone:**
- Always show odds for eggs, fusions and weather, updated live when luck effects are active.
- Server-wide boosts sold for Robux must be deterministic and must not touch coins or odds. That makes them safe for every player in the server.

**CI enforces:**
- every item has a tier;
- Tier 1 items that change odds carry odds metadata;
- every odds table sums to exactly 1,000,000 ppm.

### 5.3 Catalog v1 (starting prices in Robux)

Validate these prices with Price Optimization and Experiments, and enable Regional Pricing.

**Game passes**

| Key | Name | Effect | Price | Tier |
|---|---|---|---|---|
| vip | Nom Club VIP | +1 Vault slot, offline cap 2 h → 4 h, VIP skin and name tag, VIP lounge, daily gift of 2 hatch skips | 249 | 3 |
| coins2x | 2× Coins | Doubles coin income | 399 | 2 |
| biggerBase | Bigger Base | +6 pedestals | 199 | 3 |
| turboIncubators | Turbo Incubators | Hatching 40% faster, +1 incubator | 179 | 3 |
| fusionPro | Fusion Lab Pro | Second fusion slot, fusions 30% faster | 249 | 3 |
| vaultPlus | Vault+ | +2 Vault slots | 149 | 3 |
| autoCollect | Auto-Collect | Coins are collected automatically | 129 | 3 |
| luckyPaws | Lucky Paws | Permanent +25% luck, with live odds shown | 349 | 1 |
| creatorKit | Creator Kit | Photo filters, poses and backdrops | 79 | 3 |

**Developer products**

| Key | Effect | Price | Tier |
|---|---|---|---|
| starterPack | One-time: exclusive Bonded Nomling "Sprinkle Sprout" + 5 hatch skips | 49 | 3 |
| skipHatchS / M / L | Finish one egg now (price bucket by remaining time) | 15 / 29 / 49 | 3 |
| skipAll | Finish all incubators now | 79 | 3 |
| skipFusionS / L | Finish a fusion now | 29 / 59 | 3 |
| serverHatchRush | Whole server: hatch timers ×0.5 for 10 min; the buyer is thanked in a banner | 99 | 3 |
| serverFusionFrenzy | Whole server: fusion timers ×0.5 for 10 min | 99 | 3 |
| serverDisco | Whole server: party lights and a dance emote for 5 min (cosmetic) | 49 | 3 |
| coinPackS / M / L | Coins equal to 30 min / 3 h / 12 h of current income | 49 / 199 / 599 | 1 |
| luck15 | Personal +100% luck for 15 min, with live odds shown | 59 | 1 |
| exclusive_<season> | Direct purchase of a named Bonded Nomling, stats shown before buying | 199–499 | 3 |
| gift_<key> | Gift versions of passes and products, for a player in the same server | same as original | same as original |
| adReward_skip | Reward for rewarded video (a free hatch skip); enable once eligible | — | 3 |

**Other revenue sources:**
- **Gifts:** a game pass can't be transferred, so gifted passes are in-game **entitlements**. A player owns a perk if they own the pass **or** have a gifted entitlement.
- **Private servers:** 99 R$/month, with Chill Mode. Plus subscribers get them free, and we still earn from their time in them.
- **Roblox Plus prompt:**
  - Shown in the private-server panel and the VIP lounge ("Plus members get free private servers").
  - Only for non-subscribers, and at most once a day.
- **Rewarded video (once eligible):** a voluntary button only, capped per day, and hidden when no ad is available.
- **Season Pass (Update 2):** premium track for 399 R$.

### 5.4 Offer placement and frequency

Document every offer in `docs/MONETIZATION.md`:
- **For each offer:** where it appears (shop, contextual buttons, after a fusion, VIP lounge), what triggers it, and its frequency cap.
- **Shop:** always one tap away.
- **Contextual "skip" buttons:** appear only next to an active timer.

### 5.5 Revenue model and experiments

- **Scenario model:** build a simple one (CSV plus a short write-up) for 1k, 10k and 100k daily players. Label every assumption clearly:
  - payer conversion and average spend per payer;
  - product mix;
  - Creator Rewards and Plus bonuses;
  - rewarded video.
- **First experiments** (Roblox Experiments + live config):
  - Starter Pack timing;
  - 2× Coins price;
  - a shop layout variant.

---

## 6. Compliance and safety (→ `docs/COMPLIANCE.md` + a `compliance-reviewer` subagent)

- **Maturity & Compliance Questionnaire:** draft honest answers in Phase 1 and design the game to stay Minimal (Mild at most). Check how the Bubble Wand and the odds disclosures are classified.
- **PRI and trading:** follow §3.4 and §5.2. Robux-bought items are Bonded, and trading waits for Update 1.
- **Reward-driven media feeds:** never build them.
- **User-generated content:** no user-generated text or images in v1. If it is ever added, filter text with `TextService` and never allow free-form drawing.
- **Links:** no off-platform links inside the game. Use the approved social links on the game page.
- **Incentives:** before rewarding likes, favorites, group joins or notification opt-ins, check the current Community Standards and Terms of Use, and log the decision.
- **Ads:** follow the Advertising Standards. Rewarded video only once eligible, and never forced.
- **Notifications:** opt-in only, asked at meaningful moments, within Roblox's content and frequency rules.
- **Privacy:**
  - Store only gameplay data keyed by UserId, and no personal data.
  - Write a Right-to-Erasure runbook for deleting a user's data when Roblox requests it.
- **Intellectual property:**
  - Use original names and designs, and screen names against brands and trademarks.
  - Keep a license record for every asset and sound.
- **Anti-exploit:** server authority, plus validation and rate limits on every remote. Prefer soft measures over bans for a young audience.
- **Kids/Select readiness:**
  - The game works without chat, using emotes and Quick Words.
  - It is not a hangout, and it avoids sensitive topics.
- **Honest store page:** thumbnails and descriptions must show the real game.

---

## 7. Technical architecture

### 7.1 Environments

- **PROD:** the public experience.
- **TEST:** an experience with Audience set to Limited.
  - Used for Philip's phone playtests and for CI integration tests.
  - It has separate data stores, so tests never touch PROD data.

### 7.2 Where work happens

| Surface | Used for | Notes |
|---|---|---|
| **Cloud session** (default; started from the Claude iPhone app) | Almost everything | A fresh Ubuntu VM with the repo. Only repo config applies (`CLAUDE.md`, `.claude/`, `.mcp.json`). No Studio. |
| **Local session + Remote Control** (Philip's computer on, Studio open) | Visual work and multi-client playtests | Uses Studio's built-in MCP server. Use viewport captures for visual review. |
| **GitHub Actions** | Source of truth for build, test and publish | Holds the Roblox API key as a secret. |

### 7.3 Toolchain

**Tools** (pin all versions with Rokit or pinned binaries):
- **Rojo:** builds `.rbxl` place files from source files.
- **Wally:** packages.
- **StyLua:** formatting.
- **Selene:** linting.
- **luau-lsp:** type checking.
- **Lune:** scripts and pure-logic tests.

**Cloud-session caveats — solve these in Phase 2:**
- **Tool downloads:** GitHub release downloads only work for repos attached to the session. Two options:
  - **A.** A `toolchain-mirror.yml` workflow downloads pinned Linux x86_64 binaries in CI and commits them to `tools/bin/linux-x64/` (or publishes them as a release of this repo).
  - **B.** `cargo install --locked` from crates.io in the environment setup script. Rust is preinstalled; the script must finish in about 5 minutes, and its results are cached for about a week.

  Pick whichever works and document it.
- **Packages:** if the Wally registry is unreachable, commit `Packages/`.
- **Setup for Philip:** write the exact **setup script** and **network allowlist** for him to paste into the cloud environment settings. The allowlist is Custom access with the default list plus `apis.roblox.com`, `create.roblox.com`, `devforum.roblox.com`, and anything else you truly need.
- **Roblox API calls** go through GitHub Actions by default.
  - Optional, on Pro/Max plans: add an environment **API credential** for `apis.roblox.com`, with header name `x-api-key` and no prefix.
  - Sessions can then call Open Cloud without ever seeing the key.
- **Detecting the surface:** use `CLAUDE_CODE_REMOTE` to tell cloud sessions from local ones.

### 7.4 Repo layout (proposal; refine in Phase 1)

```
CLAUDE.md  README.md  CHANGELOG.md
default.project.json  rokit.toml  wally.toml  selene.toml  stylua.toml  .luaurc
.claude/settings.json  .claude/agents/  .claude/commands/
.github/workflows/{ci,deploy-test,deploy-prod,catalog-sync,toolchain-mirror}.yml
docs/      00-kickoff-brief.md VERIFY.md GDD.md ECONOMY.md MONETIZATION.md COMPLIANCE.md
           TECH.md CONFIG.md ANALYTICS.md ROADMAP.md LIVEOPS.md MARKETING.md
           STORE-PAGE.md PLAYTEST.md DECISIONS.md PHILIP-TODO.md RUNBOOKS.md
src/server/    Bootstrap + Services/
src/client/    Bootstrap + Controllers/ + UI/
src/shared/    Config/  Logic/ (pure, engine-free)  Net/  Style/  Types/  Generated/
worldgen/      Lune scripts that generate static map models (.rbxm) into assets/
monetization/catalog.json
config/live.defaults.json
tests/unit/    (Lune)
tests/cloud/   (Luau Execution scripts)
tools/         publish, run-cloud-tests, sync-catalog, push-config, trigger-event, simulate-economy
assets/manifest.json
```

### 7.5 Runtime architecture

**Structure**
- One server bootstrap loads the Services (init, then start, in an explicit order).
- One client bootstrap loads the Controllers.
- Use plain modules, and justify any framework.

**Services:**
- **Core:** Data, Economy, LiveConfig, Analytics, Admin, AntiCheat.
- **Gameplay:** Egg, Hatch, Fusion, Nomling (inventory), Base (plots, pedestals, vault, gate), Snatch, Weather, Event (global events, Nom Storm), WorldFirst, Codes, Quests/Daily, Leaderboard.
- **Money and social:** Shop (purchases, entitlements), Compliance (cached `PolicyService` info, product visibility), Ads, Social (invites, referrals, friend bonus), Notification.

**Networking**
- One `Net` module declares every remote, with its payload types and rate limits.
- The server validates types, ranges, ownership and proximity, using per-player token buckets.
- Never trust client positions while a player is carrying a Nomling.

**Data**
- ProfileStore (confirm it is still the recommended library), with:
  - session locking;
  - `schemaVersion` plus migrations;
  - autosave and `BindToClose`.
- Inventory cap of about 300 Nomlings. Store genomes, not derived values.
- Schema sketch: `{ schemaVersion, coins, lifetimeCoins, rebirths, rebirthPerks, nomlings{uid → {genome, tier, mutation, gen, origin, bonded}}, pedestals, vault, incubators, fusions, eggStock, discovered, worldFirsts, entitlements, purchaseLedger, daily, quests, settings, ftue, offersSeen, referral, stats }`

**Purchases**
- `ProcessReceipt` is idempotent, using a bounded purchase ledger in the profile:
  1. grant the item;
  2. persist the profile;
  3. return `PurchaseGranted`.

  Return `NotProcessedYet` if the profile isn't available.
- Passes are checked with `UserOwnsGamePassAsync`, purchase-finished events and gifted entitlements.

**Live config**
- `ConfigService`, with typed defaults in code. The game must run normally if config fails to load.
- Document every key in `docs/CONFIG.md`.

**Cross-server**
- `MessagingService`: global events and World First broadcasts.
- `MemoryStoreService`: event state and short-lived locks.
- DataStores: World First registry and code redemptions.
- OrderedDataStores: leaderboards.

**Procedural generation**
- `NomlingBuilder` (client): builds models from genomes.
- `NameGen`: deterministic names from curated syllables.
- `WorldGen`: Lune generates the static map as `.rbxm`; dynamic parts spawn at runtime.

**UI**
- Use a declarative UI library. In Phase 1, evaluate React-Lua (familiar to a web developer) against Vide or Fusion, and justify the choice.
- Touch-first; respect safe areas with `ScreenInsets`.
- Components: Button, Toast, Modal, OddsPanel, Shop, Inventory, FusionBook, Leaderboards, Daily, Settings, AdminPanel.

**Analytics**
- Onboarding funnel, shop funnel, and economy sources/sinks.
- Custom events: hatch, fuse, worldFirst, snatch, rebirth, offerShown, offerClicked, offerPurchased.
- Naming rules go in `docs/ANALYTICS.md`.

**Localization**
- All strings live in tables, using LocalizationTable plus automatic translation.
- Keep strings short, and never bake text into images.
- Generated Nomling names stay untranslated.

**Mobile performance budgets**
- 60 FPS on mid-range phones, and still playable on low-end ones.
- StreamingEnabled on.
- About 30 parts or fewer per Nomling in v1; an instance budget per plot; particle caps.
- Test with 8 players and 150+ Nomlings visible.

**Avatars:** R15.

### 7.6 Testing

- **Unit tests** (Lune, engine-free modules):
  - economy math;
  - every odds table sums to exactly 1,000,000 ppm;
  - fusion determinism;
  - **name safety:** generate every possible name and check it against a multilingual blocklist; CI fails on any hit;
  - price scaling, data migrations, catalog validation.
- **Cloud integration** (Open Cloud Luau Execution on the TEST place version):
  - all services boot with zero errors;
  - scripted scenarios (hatch → income → fuse → rebirth), where possible without real players;
  - data migration dry-runs.
- **Studio MCP** (local sessions): multi-client playtests, simulated input through the first-time experience, and viewport captures.
- **Economy simulator** (Python or Lune):
  - Models casual (15 min/day), regular (45 min/day) and heavy players.
  - Outputs pacing tables to `docs/ECONOMY.md`.
  - Starting pacing targets:
    - first hatch within 15 s;
    - first fusion within 3 min;
    - first rebirth at 25–40 min;
    - 10th rebirth after about 2–3 weeks of casual play.
- **Phone playtest script:** a test of 3 minutes or less in every PR description.

### 7.7 CI/CD (GitHub Actions)

- **`ci.yml`** (pull requests), using a concurrency group:
  1. format check, lint and type check;
  2. unit tests, plus catalog, odds and name-safety validation;
  3. Rojo build, then publish to TEST as a *Saved* version;
  4. Luau Execution tests;
  5. a summary comment on the PR.
- **`deploy-test.yml`** (merge to main): publish TEST as *Published* so Philip can play it.
- **`deploy-prod.yml`** (tag `v*`):
  - uses a GitHub Environment `production` with Philip as required approver;
  - publishes PROD and writes release notes.
- **`catalog-sync.yml`:** a dry run on PRs; applies changes only on manual dispatch.
- **`toolchain-mirror.yml`**, if option A is chosen.
- **Optional:** a weekly KPI report (workflow or Claude Code routine) that writes to `docs/reports/`.
- **API key scopes** (confirm exact names in Creator Hub):
  - place publishing and Luau execution, for TEST and PROD;
  - configs read/write and messaging publish;
  - game passes and developer products write.

  Use separate keys for TEST and PROD if practical.

### 7.8 Claude Code project setup (commit to the repo)

- **`CLAUDE.md`:** project summary, commands, conventions, the guardrails from §11, a doc map, and the phone report format.
- **`.claude/settings.json`:**
  - a SessionStart hook that checks or installs tools in the cloud;
  - a formatting hook after edits;
  - permissions that deny reading secret files.
- **`.claude/agents/`:** `compliance-reviewer`, `economy-balancer`, `mobile-ux-reviewer`, `security-reviewer`, `release-manager`.
- **`.claude/commands/`:**
  - `/status`: phone-friendly summary;
  - `/playtest`: 3-minute test script for the current branch;
  - `/ship-test`, `/release`, `/event`, `/kpi`.
- **Studio MCP:** document how Philip connects it on his computer for local sessions.

---

## 8. Roadmap (targets; re-plan in Phase 0 based on Philip's hours)

Today is 2026-09-16.

| Milestone | Target | Contents |
|---|---|---|
| M0 Setup | Sep 27 | Repo, toolchain, CI, TEST publish from phone, empty plaza playable on iPhone |
| M1 Vertical slice | Oct 11 | Plot, pedestals, coins, Basic egg, hatch, collect, save/load, first 60 s of the first-time experience, analytics funnel |
| M2 Core fun | Oct 25 | Fusion, reveals, text-to-speech, Fusion Book, World First; weather and mutations; snatching, Bubble Wand, Laser Gate, Vault, Sneaky Sam; rebirth; leaderboards |
| M3 Money & retention | Nov 8 | Catalog and sync, shop, receipts, compliance module, Starter Pack, server boosts, private servers with Chill Mode and Plus prompt, daily rewards and quests, invites and referrals, friend bonus, notifications, codes, live config, rewarded-video scaffold (off) |
| M4 Polish | Nov 20 | Art, lighting, VFX and audio pass; UI polish; performance; localization; accessibility; security review; admin panel; store assets |
| M5 Launch (16+ trial) | ~Nov 21–27 | Public launch; push to 250 highly engaged plays; fix bounce and retention |
| M6 All ages + holiday event | Dec 12 → Jan 4 | Kids/Select eligibility; "Frosty Feast" event over the holiday break |
| Update 1 | January | Trading with full compliance |
| Update 2 | February | Season Pass |

Every milestone needs a Definition of Done, a phone demo script, and the KPIs to check.

## 9. Launch and growth

**From M1 (pre-launch)**
- Post short devlog clips from the phone.
- Reserve the name on TikTok and YouTube.
- Create the Roblox Community (group).

**16+ trial (M5).** Goal: 250 highly engaged plays, fast.
- Invite age-checked 16+ friends and colleagues.
- Post in Roblox communities on Reddit and Discord, following their rules.
- Run a small sponsored ads campaign.
- Check the Audience Reach dashboard daily.

**All ages (M6 onward)**
- **Content:** 1–2 short videos a day — fusion reveals, World Firsts, snatch saves, Nomzilla.
- **Events:** weekend Nom Storms at fixed times that suit both Europe and the Americas. Propose the times from analytics.
- **Community:** codes on socials, and outreach to Video Stars creators.
- **Discovery:**
  - Put videos on the game page, for the Moments feed.
  - Always share the game link, for Audience Expansion.
  - Use browser play links once they are available.

**Store page**
- **Icon and thumbnail concepts:** one character, one emotion, readable at small sizes.
- **Title with an update tag,** e.g. "[❄️ FROSTY] Fuse a Nomling".
- **Description:** short and honest.
- **Trailer:** a shot list for a video of 30 s or less.

**Live ops**
- A weekly update, on Saturdays.
- Weekend events.
- Seasonal events that stay Minimal/Mild.

## 10. KPIs (→ `docs/ANALYTICS.md`; Philip reviews these weekly in Creator Hub on his phone)

| Area | What to track |
|---|---|
| Acquisition | Impressions, play-through rate |
| First-time experience | Bounce under 60 s and at 61–180 s; funnel completion |
| Engagement | Session length, playtime per day, play days per week |
| Retention | D1/D7/D30 versus Creator Hub benchmarks for similar games |
| Monetization | Payer conversion, average revenue per payer and per daily user, spend days, product mix, Starter Pack conversion |
| Social | Co-play days, invites sent and accepted, private servers |
| Economy health | Coin sources and sinks, time to first fusion and first rebirth |
| Compliance | Share of players who are PRI-restricted or ad-ineligible |

---

## 11. How we work (rules for you, Claude)

1. **Phase gates:** at every STOP, summarize and wait for Philip's OK.
2. **Small PRs:** one feature each, with tests, updated docs, and a phone playtest script of 3 minutes or less.
3. **Never do these without Philip's explicit OK:**
   - publish to PROD;
   - publish live config;
   - apply catalog changes;
   - spend money.
4. **Secrets:** never read, print or commit them.
5. **Verify** platform facts in official docs before depending on them. Record them in `docs/DECISIONS.md` with URL and date.
6. **Code style:**
   - config over constants;
   - server authority;
   - typed Luau (`--!strict` where practical).
7. **Dependencies:** ask before adding any.
8. **Respect Philip's time:** batch questions (at most 5) and suggest a default for each. If you're blocked, choose the safer default and log it.
9. **Pushback:** if Philip asks for something that breaks §5–§6, say so plainly and propose a compliant alternative.
10. **End every session with a phone-friendly report:**
    - ✅ Done (at most 5 bullets)
    - 📱 Test on phone (steps)
    - ⚠️ Decisions and risks
    - ⏭️ Next
11. **Keep current:** `docs/ROADMAP.md`, `CHANGELOG.md` and `docs/PHILIP-TODO.md`.

## 12. Tasks only Philip can do (track these in `docs/PHILIP-TODO.md` and remind him)

**Before building**
1. **Account security:** on his Roblox account, complete the age check and government ID verification, and turn on 2-Step Verification.
2. **Start Roblox Plus now** (or keep an existing Premium subscription). Publishing for Kids/Select requires 2 consecutive months of subscription. The alternative is the refundable per-game fee.
3. **Community and experiences:** create a Roblox Community (group) to own the game, then create the PROD and TEST experiences in it.
4. **API keys:** create Open Cloud API keys with minimal scopes. Store them as the GitHub Actions secret `ROBLOX_API_KEY` (optionally also as a cloud-environment API credential).
5. **GitHub and Claude Code:**
   - Create a private GitHub repo and connect Claude Code on the web.
   - Set the cloud environment's network allowlist and setup script, using the text you provide.
6. **Name check:** do a trademark check before committing to the title.

**Before launch**
7. **Questionnaire:** complete the Maturity & Compliance Questionnaire, using the answers you draft.
8. **Audience Expansion:** in Creator Hub, check eligibility for Audience Expansion Rewards and set up whatever it asks for (ID verification, DevEx account).
9. **Pricing:** enable Regional Pricing and review the Price Optimization suggestions.

**Ongoing**
10. **Taxes:** earnings are taxable in Sweden, so talk to Skatteverket or an accountant once money starts coming in.
11. **Weekly:**
    - playtest on the phone;
    - review KPIs;
    - approve releases;
    - spend about an hour at the computer with Studio when possible.

## 13. Phase plan (execute in order)

**Phase 0 — Orientation (no game code)**
1. Save this brief to `docs/00-kickoff-brief.md`.
2. Detect the environment (cloud or local, installed tools, network access) and report what's missing.
3. Verify §3 against official sources and write the results to `docs/VERIFY.md`.
4. Ask Philip up to 5 questions, each with a suggested default: weekly hours, Plus/Premium status, community name, plan tier, TEST/PROD IDs.
5. **STOP.**

**Phase 1 — Design pack**
1. Write the design docs:
   - `GDD.md`, `ECONOMY.md` (including the simulator), `MONETIZATION.md`;
   - `COMPLIANCE.md` (including draft questionnaire answers);
   - `TECH.md` (including the UI library decision), `CONFIG.md`, `ANALYTICS.md`;
   - `ROADMAP.md`, `LIVEOPS.md`, `MARKETING.md`, `STORE-PAGE.md`;
   - `RUNBOOKS.md` (incident response, data rollback, Right-to-Erasure).
2. Create a title shortlist: 5 options, each with a Roblox search check and a trademark-risk note.
3. Write the v1 Nomling roster: 12 base Nomlings plus the name syllable tables.
4. Challenge this brief: list the 5 biggest risks to it becoming a hit, and how you'd reduce each.
5. **STOP.**

**Phase 2 — Pipeline (M0)**
1. Set up:
   - the repo scaffold, toolchain and CI/CD;
   - the cloud setup script and allowlist text for Philip;
   - `CLAUDE.md` and `.claude/`.
2. Publish an empty plaza to TEST and run one Luau Execution smoke test.
3. Run a catalog sync dry run.
4. **STOP** once Philip has played the TEST place on his iPhone.

**Phases 3–7 — Build and launch**
- **Phase 3 — M1 Vertical slice.** **STOP** for a phone playtest.
- **Phase 4 — M2 Core fun.**
  - Rerun the economy simulator.
  - **STOP** for a phone playtest.
- **Phase 5 — M3 Money & retention.**
  - Run a compliance-reviewer pass.
  - **STOP.**
- **Phase 6 — M4 Polish.**
  - Run security and mobile-UX reviewer passes.
  - Write a performance report.
  - **STOP.**
- **Phase 7 — Launch ops (M5).**
  - Prepare: launch checklist, store page, questionnaire, admin panel check, rehearsed runbooks, event schedule.
  - **STOP** before publishing PROD.

**After launch:** a weekly cycle:
1. review KPIs;
2. fix the top 3 problems;
3. ship a content update;
4. run an event.

## 14. Start now

Begin **Phase 0**. Keep your first reply to Philip to 15 lines or fewer:
- Confirm the plan in 3 bullets.
- List what you found about the environment.
- Ask your questions (at most 5, each with a suggested default).
