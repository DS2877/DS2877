# TECH.md — Architecture and technical decisions

Phase 1.1. Decisions are logged in `docs/DECISIONS.md`.

**A Roblox primer, since this is Philip's first Roblox project.** A *place* is one level; an *experience* (universe) contains one or more places. A `ModuleScript` is a JS module. A `RemoteEvent` is a websocket message from client to server or back. A `DataStore` is a key-value database. `ReplicatedStorage` is code and data both sides can see; `ServerScriptService` is server-only. Nothing the client says can be trusted, ever.

---

## 1. The constraint that shapes everything

**Philip is phone-only during business hours and has no Roblox Studio.** Confirmed 2026-09-16.

The brief assumed Studio for two things. Neither is available, so both need engineered replacements:

| Assumed | Replacement |
|---|---|
| Multi-client playtests (snatching is PvP) | **Scripted NPC snatchers** driving the same server code paths, plus Luau Execution scenario tests |
| Visual review via viewport captures | **Philip's phone screenshots.** Claude cannot see the game otherwise. |

This is not a footnote — it is why §6 (testing) looks the way it does, and it makes automated testing load-bearing rather than nice-to-have.

---

## 2. Environments

| | Purpose |
|---|---|
| **PROD** | the public experience |
| **TEST** | Audience = Limited → Playtesters. Philip's phone playtests and CI integration tests. **Separate DataStores** so tests never touch player data. |

Both places: **Avatar Settings → R15 Only** at creation. Required for the 0.0054 DevEx rate and unrecoverable later (`docs/VERIFY.md` §3.3).

---

## 3. Where work happens

| Surface | Used for |
|---|---|
| **Cloud session** (default, from Philip's iPhone) | Almost everything. Fresh Ubuntu VM, repo, no Studio. |
| **GitHub Actions** | Source of truth for build, test, publish. Holds `ROBLOX_API_KEY`. |
| **Local session + Studio MCP** | Only if Philip ever has computer time. Not assumed. |

Detect the surface with `CLAUDE_CODE_REMOTE`.

**Philip is on Claude Pro**, which unlocks an environment **API credential** for `apis.roblox.com` (header `x-api-key`, no prefix). Cloud sessions can then call Open Cloud directly without ever seeing the key — publishing to TEST stops needing a GitHub Actions round-trip. Worth setting up in Phase 2; GitHub Actions remains the fallback and the only path for PROD.

---

## 4. Toolchain

**Decision: install via `cargo install --locked` with pinned versions.** Validated by experiment — the full toolchain installs cleanly. Cold install measured twice: **440 s** and **573 s** (7–10 minutes; the machine is the variable, not the plan). Cached about a week, so this is a cold-start cost only. The brief's Option A (mirroring GitHub release binaries) is **not viable here**: `github.com/*/releases/*` and `codeload.github.com` return 403 from the egress proxy, while `index.crates.io` and `static.crates.io` are reachable.

Needs `CARGO_HTTP_CAINFO=/root/.ccr/ca-bundle.crt` for TLS through the proxy.

**Verified in Phase 2** — every tool below installs from crates.io at the pinned version:

| Tool | Version | Purpose |
|---|---|---|
| Rojo | 7.7.0 | builds `.rbxl` from source |
| Selene | 0.31.0 | lint |
| StyLua | 2.5.2 | format |
| Lune | 0.10.5 | scripts and pure tests |
| Wally | 0.3.2 | packages |

❌ **`luau-lsp` is not on crates.io** — it is a C++ project released as GitHub binaries, and those downloads are blocked. **Typechecking is therefore CI-only** (`docs/DECISIONS.md` D-014). Cloud sessions get format, lint, unit tests and parity as the fast inner loop.

`scripts/setup-cloud.sh` installs in priority order, so a truncated run still leaves the tools that matter most. `rokit.toml` pins the same versions for GitHub Actions, where prebuilt binaries work.

⚠️ **Selene's Roblox std is committed, not generated.** `selene generate-roblox-std` uses its own bundled cert roots and ignores the proxy CA, so it cannot run here. `roblox.yml` lists the globals the codebase actually uses; a newly-used global surfaces as an `undefined_variable` error (`docs/DECISIONS.md` D-017).

If the Wally registry is unreachable, commit `Packages/`. M0 ships with zero dependencies, so this is not yet on the critical path.

---

## 5. Runtime architecture

Plain modules with an explicit bootstrap. **No framework** — Knit/Matter add concepts Philip would have to learn to debug a game he is reviewing on a phone, and we get service ordering from twenty lines of our own code.

- `src/server/Bootstrap.server.luau` — requires each service, calls `:init()` on all in a declared order, then `:start()` on all.
- `src/client/Bootstrap.client.luau` — same for controllers.

**Services.** Core: Data, Economy, LiveConfig, Analytics, Admin, AntiCheat. Gameplay: Egg, Hatch, Fusion, Nomling, Base, Snatch, Weather, Event, WorldFirst, Codes, Quests, Leaderboard. Money/social: Shop, Compliance, Ads, Social, Notification.

### Networking

One `src/shared/Net/` module declares **every** remote with its payload type and rate limit. Nothing creates a remote outside it.

The server validates, per call: type, range, **ownership**, **proximity**, and a per-player token bucket. **Never trust client position while a player carries a Nomling** — the server owns carry state and validates the drop against its own positions.

### Data

**Decision: ProfileStore.**

⚠️ Correcting the brief: Roblox does **not** officially recommend any third-party data library. The official guidance covers `DataStoreService` directly, so "confirm it is still the recommended library" has no official answer. ProfileStore is chosen on its merits — session locking (prevents duplication across servers, which is the bug that ruins economies), schema versioning with migrations, autosave, `BindToClose` handling, and active maintenance as the successor to ProfileService.

✅ **Approved by Philip on 2026-09-16** (brief §11.7 dependency approval). Lands in M1, when the first save actually needs it.

Profile schema:

```
{ schemaVersion, coins, lifetimeCoins, rebirths, rebirthPerks,
  nomlings { uid -> { genome, tier, mutation, gen, origin, bonded } },
  pedestals, vault, incubators, fusions, eggStock, discovered, worldFirsts,
  entitlements, purchaseLedger, daily, quests, settings, ftue, offersSeen,
  referral, stats }
```

Inventory cap ~300. **Store genomes, never derived values** — appearance, name and income all recompute from the genome, so a balance change never has to migrate anyone's creatures.

### Purchases

`ProcessReceipt` must be idempotent, via a bounded purchase ledger in the profile:
1. grant, 2. **persist**, 3. return `PurchaseGranted`.
Return `NotProcessedYet` if the profile is not loaded — never `PurchaseGranted` on unsaved state, or a server restart charges a child for nothing.

Perk ownership is one function: `Shop:hasPerk(player, key)` → true if they own the pass **or** hold a gifted entitlement. Nothing else checks passes directly.

### Live config

`LiveConfig` with typed defaults in code. **The game must run normally if config fails to load** — defaults are the contract, config is an override. Keys documented in `docs/CONFIG.md`.

### Cross-server

`MessagingService` for global events and World First banners. `MemoryStoreService` for event state and short-lived locks. DataStores for the World First registry (`UpdateAsync` on `firsts/<key>`, first writer wins) and code redemptions. OrderedDataStores for the four leaderboards, refreshed every 60–120 s.

### Procedural generation

`NomlingBuilder` (client) builds a model from a genome. `NameGen` produces deterministic names.

⚠️ **The M0 plaza is built in code**, not loaded from a `.rbxm` — `PlazaService` constructs it with `Instance.new`. The `worldgen/` Lune pipeline is deferred to M2, when the plaza gains real content; putting asset serialisation on the critical path for the first deploy bought risk with no payoff (`docs/DECISIONS.md` D-016).

**The seed is derived from the genome, never from time or `Random.new()`.** The same genome must build the same creature on every client forever, or the Fusion Book, World First credit and every screenshot break.

---

## 6. UI library decision: **React-Lua**

The brief asked for React-Lua vs Vide vs Fusion with justification.

| | React-Lua | Fusion | Vide |
|---|---|---|---|
| Familiar to a web dev | ✅ it *is* React | ✗ | ✗ (Solid-like) |
| Documentation / examples | ✅ most | medium | least |
| Performance | heaviest (reconciler) | light | ✅ lightest, fine-grained |
| API stability | ✅ stable | has had breaking rewrites | young |

**Choice: React-Lua.** ✅ Approved by Philip on 2026-09-16.

The brief justifies it as "familiar to a web developer", but that criterion is weaker than it looks — **Claude writes almost all of this code, Philip reviews it.** The decisive reason is different: React-Lua has the most documentation and the most predictable behaviour, which matters enormously when the person debugging is on a phone, new to Luau, and cannot open Studio. Predictability beats raw speed here.

**The cost is real and we handle it explicitly:**

> **Rule: high-frequency values never go through the reconciler.**
> Coin counters, income-per-second and countdown timers update many times a second. Those specific labels are driven by direct property writes from a controller. React-Lua owns structure — panels, lists, modals, routing — and not the fast-moving numbers inside them.

Without that rule, a coin counter would re-render the tree ~30×/second on a phone, and the 60 FPS budget would be gone before any Nomlings were on screen.

**Revisit trigger:** if GUI frame time exceeds **2 ms** on a mid-range phone during the M4 performance pass, reassess against Vide. The rule above should prevent that.

Lands in M1, with the first UI.

**Components:** Button, Toast, Modal, OddsPanel, Shop, Inventory, FusionBook, Leaderboards, Daily, Settings, AdminPanel. Touch-first, safe areas via `ScreenInsets`.

---

## 7. Testing

Weighted heavily toward automation, because there is no Studio and manual testing is one person on one phone.

### Unit tests (Lune, engine-free modules)
- Economy maths
- **Every odds table sums to exactly 1,000,000 ppm**
- Fusion determinism — same parents + same seed ⇒ identical child, name and appearance
- **Name safety — enumerate the full cross-product (876 names today), fail on any blocklist hit.** Exhaustive, never sampled.
- Price scaling, data migrations, catalog validation (every item has a tier; Tier 1 odds-changing items carry odds metadata)
- **Rebirth leaves the player able to play** — a direct regression test for the dead-end bug in `docs/ECONOMY.md` §4.1

### Cloud integration (Open Cloud Luau Execution, against the TEST place)
- All services boot with zero errors
- Scripted scenarios: hatch → income → fuse → rebirth
- **Snatch scenarios driven by NPC snatchers**, since we cannot run two real clients
- Data migration dry runs

⚠️ **Rate limits shape this.** Verified: **5 task creations per minute per API key owner**, 10 concurrent tasks per place, 5-minute max runtime, 4 MB script and 4 MB return. → **The cloud suite is one task running many assertions, not one task per test.** A per-test design would hit the limit immediately.

### Manual
A **3-minute phone playtest script in every PR description** (brief §11.2). It has to be genuinely 3 minutes — that is the real budget.

---

## 8. CI/CD

| Workflow | Trigger | Does |
|---|---|---|
| `ci.yml` | pull request | format, lint, typecheck → unit tests + catalog/odds/name validation → Rojo build → publish TEST as a *Saved* version → Luau Execution suite → PR summary comment |
| `deploy-test.yml` | merge to main | publish TEST as *Published* so Philip can play it |
| `deploy-prod.yml` | tag `v*` | GitHub Environment `production` with Philip as required approver → publish PROD → release notes |
| `catalog-sync.yml` | PR = dry run; apply only on manual dispatch | never applies automatically |

Concurrency groups on everything so a rapid second push cancels the first.

**API key scopes** (confirm exact names in Creator Hub): place publishing + Luau execution for TEST and PROD; configs read/write; messaging publish; game passes and developer products write. Separate TEST and PROD keys if practical.

**Never without Philip's explicit OK:** publish PROD, publish live config, apply catalog changes, spend money.

---

## 9. Performance budget

60 FPS mid-range, playable low-end. StreamingEnabled on. ≤30 parts per Nomling. Per-plot instance budget. Particle caps. **Test case: 8 players, 150+ Nomlings visible.**

The riskiest number is 150+ procedurally-built models on screen at once. If the budget breaks, the order of retreat is: (1) cull distant plots harder, (2) reduce part count on gen-1 Nomlings, (3) LOD — swap distant Nomlings for a single-part silhouette. **Never** reduce the Nomling count per plot, since that is the game's sense of growth.

---

## 10. Localization

All strings in tables via LocalizationTable plus automatic translation. Keep strings short. **Never bake text into images.** Generated Nomling names stay untranslated.
