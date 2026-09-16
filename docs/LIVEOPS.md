# LIVEOPS.md

Phase 1.1. The operating rhythm after launch, and the content engine behind it.

---

## 1. Weekly cadence

| Day | What |
|---|---|
| **Saturday** | Ship the weekly update. Highest Roblox traffic day — the discovery docs name weekly seasonality peaking Saturday. |
| **Sat–Sun** | Weekend event window (Nom Storm or seasonal). |
| **Monday** | Philip reviews KPIs on his phone from `docs/reports/kpi-YYYY-WW.md`. |
| **Mon–Fri** | Claude builds; Philip reviews in business-hours fragments. |
| **Friday** | Release candidate on TEST; Philip's 3-minute phone playtest. |

**Never ship on a Friday evening or into a weekend event.** If Friday's playtest fails, the update waits a week. A broken Saturday costs more than a late feature.

---

## 2. The content engine

**New base species are the cheapest content in the project.** They are a config edit — a snack token, an animal token, a head, a tail, a body archetype and a palette anchor — with no new art pipeline (`docs/NOMLINGS.md`).

Each new base species adds:
- 1 gen-1 creature
- **25** new gen-2 combinations (12 as head × new tail, 12 as new head × tail, 1 Prime)
- **125** new gen-3 combinations
- A fresh sweep of Mutation Firsts across all of them

**Four new species per season roughly doubles the discovery space.** That is the whole reason World First keeps working past the first month.

| Season | New species | Theme |
|---|---|---|
| Launch | the 12 in `docs/NOMLINGS.md` | Food court |
| Frosty Feast (Dec–Jan) | 4 | Winter: Cocoa Cub, Gingerbread Goat, Peppermint Puffin, Snowcone Seal |
| Spring | 4 | Garden |
| Summer | 4 | Beach / ice cream |

**Seasonal mutations are even cheaper.** One new mutation re-opens a Mutation First sweep across the *entire* existing roster at zero content cost. Use sparingly — one per season — or the Book stops feeling finishable.

---

## 3. Events

### Nom Storm — weekend global
Admin-triggered via `tools/trigger-event` (Open Cloud Messaging) or the in-game admin panel. Boosts mutation chance and enables the Nomzilla mutation (giant, ×8).

**Timing.** Fixed times that work for both Europe and the Americas. Starting proposal, to be replaced by analytics after a month of data:

| | Time |
|---|---|
| Saturday | **18:00 UTC** — 19:00 CET, 13:00 EST, 10:00 PST |
| Sunday | **18:00 UTC** |

Duration 2 hours. Announced 24 h ahead via an Experience Event (opt-in notification) and an in-game banner.

⚠️ Experience Events let us attach up to 5 thumbnails and let players opt in to be notified. That is free reach and directly feeds the "intentional co-play" discovery signal — use it for every Nom Storm.

### Seasonal events
Frosty Feast, Spring, Summer. Each brings new species, one new mutation, a plot theme, and a title tag (`docs/STORE-PAGE.md`). All must stay **Minimal/Mild** — a seasonal event is not a reason to add anything that changes the maturity label (`docs/COMPLIANCE.md`).

### Golden Egg
Automatic, ~5% of restock cycles, announced server-wide. Not an ops action.

---

## 4. Codes

Defined in live config: reward, expiry, max redemptions. One use per player, enforced by DataStore.

- Post on socials at content moments, not on a schedule — a code should reward following, not train farming.
- **Never** reward a like, favourite, group join or notification opt-in (`docs/COMPLIANCE.md` §4).
- Always set an expiry. A permanent code is a permanent economy leak.

---

## 5. Config changes in production

Follow `docs/CONFIG.md` rollout rules. The short version:

1. TEST first, play it on a phone, then PROD.
2. **One 🔴 key at a time.**
3. Every 🔴 change gets a `CHANGELOG.md` line with before, after and why.
4. Keep previous values to hand; rollback is re-publishing the old config.
5. **Never change disclosed odds while an event is running.**
6. **Never publish live config without Philip's explicit OK** (brief §11.3).

Two settings that are effectively permanent:
- **Private server price.** Changing it cancels every active subscription. Set once.
- **`fusion.slotsBase`.** It is the economy's main throttle; treat a change as a release.

---

## 6. Monitoring

Watch daily for the first two weeks after launch, then weekly:

| Signal | Where | Act if |
|---|---|---|
| Server errors | Creator Hub → Analytics → Errors | any new error type appears |
| Bounce `<60 s` | Home Recommendations | rises two days running |
| Coin sources vs sinks | our events | sinks fall below ~50% of sources |
| `snatch_attempted` blocked rate | our events | a single `blocked_reason` dominates |
| `offer_shown` where `was_unsolicited` | our events | **more than one per session — this is a compliance bug** |
| Audience Reach progress | Creator Hub | stalls for 3+ days during M5 |
| Reduced-exposure banner | Creator Dashboard | appears at all — see `docs/RUNBOOKS.md` |

---

## 7. Communication

- **In-game:** server banners for big hatches, fusions, World Firsts and events.
- **Notifications:** opt-in only, asked at the "Kitchen's cooking" moment. Event reminders and "your fusion is ready". Never more than the platform's frequency rules allow, and never rewarded.
- **Off-platform:** socials for codes, clips and event announcements. **No off-platform links inside the game** — the game page's approved social links only.
