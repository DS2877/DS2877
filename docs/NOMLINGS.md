# NOMLINGS.md — v1 roster, genome and name generation

Phase 1.3. Everything here is data, not code: it belongs in `src/shared/Config/` so it can be tuned without touching logic (brief §11.6, "config over constants").

---

## 1. The 12 base Nomlings

Each base Nomling is a **snack** crossed with an **animal**. Two changes from the brief, both forced:

1. **Taco Cat → Taco Tiger**, because "Tacocat" is an established meme, band and game name, and unique metadata is a discovery requirement (`docs/TITLES.md`).
2. **Taco Tiger → Taco Rhino**, because the name-safety test found that `Sushi` + `tiger` spells **Sushitiger**. Tiger was the only tail on the roster starting with `t`, so the species changed rather than the rule. A human reading a list of twelve names would never have caught this; the exhaustive test caught it on the first run.

| # | Name | Snack token | Animal token | `head` | `tail` | Body archetype | Palette anchor |
|---|---|---|---|---|---|---|---|
| 1 | Taco Rhino | taco | rhino | `Taco` | `rhino` | quadruped, wide stance | warm ochre / shell-cream |
| 2 | Sushi Pup | sushi | pup | `Sushi` | `pup` | quadruped, small | rice-white / salmon-coral |
| 3 | Pizza Penguin | pizza | penguin | `Pizza` | `guin` | biped, upright | crust-gold / tomato-red |
| 4 | Donut Duck | donut | duck | `Donut` | `duck` | biped, round | glaze-pink / sprinkle-multi |
| 5 | Burger Bear | burger | bear | `Burger` | `bear` | quadruped, bulky | bun-tan / lettuce-green |
| 6 | Noodle Frog | noodle | frog | `Noodle` | `frog` | squat, wide | broth-amber / scallion-green |
| 7 | Popcorn Pig | popcorn | pig | `Popcorn` | `pig` | quadruped, round | popcorn-cream / butter-yellow |
| 8 | Waffle Walrus | waffle | walrus | `Waffle` | `wal` | pinniped, long | waffle-brown / syrup-amber |
| 9 | Cupcake Croc | cupcake | croc | `Cupcake` | `croc` | long, low | frosting-lilac / cherry-red |
| 10 | Pickle Parrot | pickle | parrot | `Pickle` | `parr` | biped, winged | pickle-green / beak-orange |
| 11 | Mochi Mole | mochi | mole | `Mochi` | `mole` | squat, small | mochi-white / dust-mauve |
| 12 | Nacho Narwhal | nacho | narwhal | `Nacho` | `narw` | aquatic, long | nacho-gold / cheese-orange |

**Spread check.** Body archetypes cover quadruped (4), biped (3), squat (2), long-low (1), pinniped (1), aquatic (1) — enough silhouette variety that a fused creature reads as genuinely different at phone size, which is the whole point.

Two tails are clipped for phonetics: Pizza Penguin gives `guin` (not `penguin`, which would produce "Tacopenguin" — too long for a name banner) and Nacho Narwhal gives `narw`.

---

## 2. Genome

```
genome = {
  animal, snack,          -- species tokens, drive silhouette and name
  palette, pattern,       -- colour identity
  eyes, accessory,        -- personality
  sizeScale,              -- 0.8 – 1.25, or mutation-driven
  mutation,               -- nil or a mutation token
  gen,                    -- 1, 2 or 3
  parents,                -- {uidA, uidB} or nil for gen 1
  seed,                   -- deterministic RNG seed
}
```

**The rule that makes this work:** `seed` is derived from the genome's own identity, never from `os.time()` or `Random.new()`. The same genome must build the same creature on every client, every session, forever — otherwise the Fusion Book, World First credit and screenshots all break.

```
seed = hash(snack .. "|" .. animal .. "|" .. gen .. "|" .. affix .. "|" .. mutation)
```

Palette, pattern, eyes and accessory are then **derived** from `seed`, not stored. That keeps the stored genome tiny (important at 300 Nomlings per profile) and guarantees consistency. Only `sizeScale` and `mutation` are stored independently, because weather can change them after birth.

**Inheritance (brief §4.5 F, made concrete):**

| Trait | Rule |
|---|---|
| `snack` | from parent **A** |
| `animal` | from parent **B** |
| `gen` | `max(A.gen, B.gen) + 1`, capped at 3 |
| `tier` | the higher parent's tier; **12%** chance to upgrade one step if both parents share a tier, **5%** otherwise |
| `mutation` | chance to inherit from either parent (config; 0 if neither has one) |
| `sizeScale` | derived from seed, ×1.4 at gen 3 |
| income | `(A + B) × 1.3 × genBonus` |

A fused from B and B fused from A are **different creatures** — ordered pairs. Sushi Pup + Waffle Walrus is `Sushiwal`; Waffle Walrus + Sushi Pup is `Wafflepup`. This doubles the discovery space for free and makes "which order?" a thing players talk about.

---

## 3. Name generation

**Rule: `name = affix + head(A) + tail(B)`.**

That is the whole generator. It is deterministic, needs no syllable-splicing heuristics, and reproduces the brief's own example exactly: Sushi Pup + Waffle Walrus → `Sushi` + `wal` → **Sushiwal** ✓.

### Affix table

| `gen` | Condition | Affix | Example |
|---|---|---|---|
| 2 | `snack ≠ animal` species | *(none)* | Sushiwal |
| 2 | same species both sides | `Prime ` | Prime Tacorhino |
| 3 | — | one of `Mega `, `Ultra `, `Giga `, `Omni `, `Titan ` — chosen by seed | Giga Sushicroc |

Gen 3 needs the affix or its names would collide with gen 2 (a gen-3 creature still carries one `head` and one `tail`). The affix also does double duty as the "Mega" label the brief asks for, and gives us five visual sub-themes for the gen-3 aura.

### How big is the space

| Layer | Count | Notes |
|---|---|---|
| Gen 1 base | 12 | the roster above |
| Gen 2 | **144** | 12 heads × 12 tails, ordered; the 12 diagonals become `Prime` |
| Gen 3 | **720** | 144 × 5 affixes |
| **Distinct names** | **876** | |
| × mutations (6 + none) | **6,132** | mutation changes look, aura and income, and counts separately in the book |
| × palette/pattern/eyes/accessory | thousands more | visual variety only; does not create book entries |

⚠️ **Honest correction to the brief.** §4.1 says "thousands of combinations". Thousands of *appearances*, yes — but only **876 distinct creatures** and **6,132 book entries**. That matters because World First is our viral engine: with a few hundred players it lasts months, but at 100k players the 876 species firsts would be claimed within days.

**Mitigations, carried into `docs/LIVEOPS.md`:**
- World First has **two tiers**: *Species First* (876, permanent) and *Mutation First* (6,132, rarer, ongoing).
- **Every content update adds base species.** Each new base adds 25 gen-2 keys and 125 gen-3 keys, so adding 4 species per season roughly doubles the discovery space each time. This is the cheapest content we can ship — it is a config edit, not art.
- Seasonal mutations (e.g. "Frosty") open a fresh Mutation First sweep across the whole existing roster at zero content cost.

### Fusion Book keys

```
gen 1   species:<snack>
gen 2   g2:<snack>-<animal>
gen 3   g3:<snack>-<animal>-<affix>
mutation firsts   m:<comboKey>:<mutation>
```

World First is claimed with a DataStore `UpdateAsync` on `firsts/<key>` — first writer wins — then broadcast via `MessagingService` (brief §4.5 F).

---

## 4. Name safety

The generator can emit 876 strings today and more with every content update, so screening cannot be manual. **`tests/unit` enumerates every reachable name and fails CI on any hit** (brief §7.6).

Three lists, all in `src/shared/Config/NameSafety.luau`:

1. **Profanity, multilingual.** Not just English — Swedish, Spanish, Portuguese, French, German, Russian, Turkish, Tagalog and Indonesian at minimum, since Roblox auto-translates and our audience is global. Substring matching, not word matching, because concatenation is exactly how accidental words appear.
   **Plus an allowlist**, or the substring list is unusable: "Titan" contains "tit", "shell" contains "hell", "class" contains "ass". Allowlisted words are stripped before scanning. Only ever add a genuinely innocent word — never to make a failing test pass.
2. **Brands and trademarks.** Snack names are the risk surface; a future seasonal species could easily collide.
3. **Roblox-specific.** Terms likely to trip Roblox's own text filter, so a name never renders as `####` in the reveal banner.

**The test enumerates the full cross-product, not a sample** — 876 strings is trivial to check exhaustively, and a sampled test would let a bad name ship on the day someone adds a species.

**It has already earned its place.** On its first run it found `Sushitiger` — a name that would have appeared in a reveal banner, in front of children, with the game's own text-to-speech reading it aloud.

When a collision is found, the fix is to change the offending `head`/`tail` token, not to add a runtime filter. The generator must stay pure and deterministic.

**Generated names are never localised** (brief §7.5) — "Sushiwal" is the same word everywhere. Only the surrounding UI strings translate.

---

## 5. Building the model

`NomlingBuilder` (client) turns a genome into a model. Budget: **≤30 parts** in v1 (brief §7.5).

Approximate part budget per creature:

| Group | Parts |
|---|---|
| Body core (from `animal` archetype) | 6–10 |
| Limbs / fins / wings | 4–8 |
| Head + snout | 3–4 |
| Eyes | 2–4 |
| Snack overlay (from `snack`) | 3–6 |
| Accessory | 0–2 |

The **snack overlay is the trick that makes fusion read instantly**: the animal archetype sets the silhouette, and the snack contributes a recognisable topping layer (taco shell back, sushi nori band, pizza-crust rim, waffle grid, sprinkles). A player sees "walrus shape, sushi colours" and understands the fusion in under a second — which is what the 2–3 second reveal needs.

Keep the upgrade path to MeshParts open (brief §4.5 D): the builder takes a genome and returns a model, so swapping part construction for mesh lookup later never changes the genome format, the book, or anyone's saved creatures.
