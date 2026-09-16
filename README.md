# Fuse a Nomling

A phone-first Roblox game: hatch silly snack-animal creatures called **Nomlings**, fuse two of them into a creature that has never existed, and guard your base from friendly snatchers.

> **Status:** Phase 2 (M0 pipeline) built. Empty plaza builds and passes every local check.
> **Blocked on:** the TEST place existing so it can actually be published — see [`docs/CLOUD-SETUP.md`](docs/CLOUD-SETUP.md).

## What makes it different

Every other pet game on Roblox has an index of pets you can read. Ours generates creatures from a genome — 876 distinct creatures and 6,132 Fusion Book entries, built from code rather than hand-made art. Fuse a Sushi Pup with a Waffle Walrus and you get a **Sushiwal**, and if nobody anywhere has made one before, your name stays on it forever.

## Documentation map

**Start here**
| Doc | What it is |
|---|---|
| [`docs/00-kickoff-brief.md`](docs/00-kickoff-brief.md) | The original brief. Source of truth for scope and intent. |
| [`docs/RISKS.md`](docs/RISKS.md) | The honest challenge to the brief. **Read this second.** |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Every decision, why, and what would reverse it. |
| [`docs/PHILIP-TODO.md`](docs/PHILIP-TODO.md) | Things only Philip can do. |

**Design**
| Doc | What it is |
|---|---|
| [`docs/GDD.md`](docs/GDD.md) | Game design. Resolves the brief rather than repeating it. |
| [`docs/NOMLINGS.md`](docs/NOMLINGS.md) | Roster, genome, name generation, name safety. |
| [`docs/ECONOMY.md`](docs/ECONOMY.md) | Tuned numbers, pacing, and the two design bugs the simulator caught. |
| [`docs/TITLES.md`](docs/TITLES.md) | Title shortlist, trademark screening, competitive finding. |

**Money and rules**
| Doc | What it is |
|---|---|
| [`docs/MONETIZATION.md`](docs/MONETIZATION.md) | Catalog, currency firewall, offer caps, revenue model. |
| [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) | Paid random items, draft questionnaire answers, standing prohibitions. |
| [`docs/VERIFY.md`](docs/VERIFY.md) | Every platform fact, with source URL and check date. |

**Build and run**
| Doc | What it is |
|---|---|
| [`docs/TECH.md`](docs/TECH.md) | Architecture, library decisions, testing, CI/CD. |
| [`docs/CLOUD-SETUP.md`](docs/CLOUD-SETUP.md) | **Philip:** exactly what to paste into the cloud environment and GitHub. |
| [`docs/CONFIG.md`](docs/CONFIG.md) | Live config reference and rollout rules. |
| [`docs/ANALYTICS.md`](docs/ANALYTICS.md) | Events, funnels, KPIs. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Milestones. **Proposed re-plan — needs approval.** |
| [`docs/LIVEOPS.md`](docs/LIVEOPS.md) | Weekly rhythm, events, the content engine. |
| [`docs/MARKETING.md`](docs/MARKETING.md) | Two funnels, and how not to lose reach. |
| [`docs/STORE-PAGE.md`](docs/STORE-PAGE.md) | Icon, thumbnails, description, trailer, launch checklist. |
| [`docs/RUNBOOKS.md`](docs/RUNBOOKS.md) | What to do when something breaks. |

## Tools

```bash
python3 tools/simulate-economy/simulate.py   # pacing tables
python3 tools/simulate-economy/tune.py       # re-derive rebirth constants
python3 tools/revenue-model/model.py         # revenue scenarios -> docs/reports/
```

## Ground rules

- Never publish to PROD, publish live config, apply catalog changes, or spend money without Philip's explicit approval.
- Verify platform facts in official docs before depending on them; record them in `docs/VERIFY.md` with URL and date.
- Config over constants. Server authority. Typed Luau.
- Code, comments, docs and commit messages are in English.
