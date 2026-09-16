# CLAUDE.md

Project guidance for Claude Code. Read this first in every session.

## What this is

**Fuse a Nomling** — a phone-first Roblox game. Hatch snack-animal creatures, fuse two into a creature that has never existed, guard your base from friendly snatchers.

**The pitch is "the creatures are generated, not listed."** Not fusion — the #1 game on Roblox (Steal An Egg, ~1.7M CCU) already has stealing, hatching, income pets, base upgrades, a Fuse Machine and mutations. Our differentiator is procedural generation plus World First. See `docs/RISKS.md` risk 1 before writing any marketing copy or store text.

**Working with Philip:** solo developer in Sweden, full-time job, ~8–10 h/week, **phone-only during business hours, no Roblox Studio** (occasional Studio time later, on request). New to Roblox and Luau; strong on web, Python and AI tooling.
- Explain each Roblox concept once, in a sentence, the first time it appears. Web analogies help: RemoteEvent ≈ websocket message, DataStore ≈ key-value database, ModuleScript ≈ JS module.
- He writes Swedish or English — **reply in the language of his latest message.** Code, comments, docs and commit messages are always English.
- Keep chat short and scannable; put detail in files.

## Commands

```bash
./scripts/check.sh              # everything CI runs — do this before every push
./scripts/check.sh --fix        # format in place first

lune run tests/unit/run                      # unit tests
python3 tests/parity/economy_parity.py       # Economy.luau vs the simulator
python3 tools/validate-catalog.py            # catalog + currency firewall rules
rojo build default.project.json --output build/nomling.rbxl

python3 tools/simulate-economy/simulate.py   # pacing tables
python3 tools/simulate-economy/tune.py       # re-derive rebirth constants
python3 tools/revenue-model/model.py         # revenue scenarios

python3 tools/publish.py --env test --type Saved --file build/nomling.rbxl
python3 tools/run-cloud-tests.py --env test
```

Toolchain is installed by `scripts/setup-cloud.sh` (cargo, from crates.io — GitHub releases are blocked by the egress proxy). **`luau-lsp` is unavailable in cloud sessions**, so typechecking is CI-only.

## Never do these without Philip's explicit OK

1. Publish to PROD.
2. Publish live config.
3. Apply catalog changes.
4. Spend money (ads, expedited review, anything).

Add a dependency without asking, too — that includes Wally packages and Python libraries.

## Hard rules

- **Secrets.** Never read, print or commit an API key. `ROBLOX_API_KEY` comes from the environment; if you are adding a debug print near it, don't.
- **Server authority.** Every remote validates type, range, ownership and proximity, with a per-player token bucket. Never trust a client position, especially while a player carries a Nomling.
- **Odds sum to exactly 1,000,000 ppm.** This is a legal disclosure requirement, not balance. CI enforces it in three places.
- **No casino visual language.** No prize wheels, slot reels, cards, dice, chips, jackpot levers. Gambling imagery forces a Moderate maturity rating, which loses the Roblox Kids tier entirely. The Egg Market is a market stall; the Fusion Lab is a kitchen.
- **No purchase buys snatching advantage.** Defensive perks are fine.
- **At most one unsolicited offer per session**, never after a loss, never during a reveal, never before 5 minutes.
- **Config over constants**, typed Luau (`--!strict` where practical), pure engine-free modules under `src/shared/Logic/` so Lune can test them.

## Conventions

- `src/shared/Logic/` modules **require nothing** — that is what makes them testable under Lune, which resolves requires by file path while Roblox resolves them via `script.Parent`.
- Luau does **not** allow annotating a table field assignment (`Foo.BAR: Type = {}`). Declare a typed local and assign it.
- Add a remote to `src/shared/Net/` first, implement second. Nothing creates a remote elsewhere.
- Any change to economy numbers: edit `tools/simulate-economy/config.py`, re-run `tune.py`, then copy into `src/shared/Config/Economy.luau`. The parity test fails otherwise.
- A new analytics event needs a row in `docs/ANALYTICS.md` in the same PR.
- New globals used in Luau may need adding to `roblox.yml` (the committed minimal selene std) — a missing one shows up as `undefined_variable`.

## Small PRs

One feature each, with tests, updated docs, and a **phone playtest script of 3 minutes or less** in the description. The playtest budget is real — Philip is on a phone between meetings.

## Phase gates

The project runs in phases (`docs/00-kickoff-brief.md` §13). At every **STOP**, summarise and wait. Currently: **Phase 2 (M0 pipeline)**.

## End every session with this report

```
✅ Done            (max 5 bullets)
📱 Test on phone   (steps)
⚠️ Decisions and risks
⏭️ Next
```

## Doc map

Read `README.md` for the full map. The ones that change decisions:

| Doc | When to read it |
|---|---|
| `docs/RISKS.md` | before any positioning, marketing or scope call |
| `docs/DECISIONS.md` | before re-deciding anything; includes reversal conditions |
| `docs/VERIFY.md` | before relying on any platform fact — has URLs and check dates |
| `docs/ECONOMY.md` | before touching a number |
| `docs/COMPLIANCE.md` | before anything involving odds, purchases, chat or content |
| `docs/PHILIP-TODO.md` | to see what is blocked on Philip |

**Verify platform facts in official docs before depending on them**, and record them in `docs/VERIFY.md` with URL and date. Roblox changes these rules often.

## Keep current

`docs/ROADMAP.md`, `CHANGELOG.md`, `docs/PHILIP-TODO.md`.
