# ADR 0007: Platform sequencing — Mac and iPhone lead, Windows and Android fast-follow, Apple TV deprioritized

**Status:** Accepted
**Date:** 2026-09-03
**Supersedes:** ADR 0003 (Android exclusion framing)

## Context

Founder clarification, 2026-09-03, revises the platform strategy the original brief and ADR 0002/0003 encoded:

1. Aeria VPN is **not** meant to be Mullvad-style narrow (Apple-only, minority-platform, deliberately small reach) — it should ultimately be **accessible on any device**, closer to mainstream competitors' reach, but with Aeria's premium craft and honest pricing rather than their commodity trust and manipulative pricing.
2. **Mac availability is the single most important platform**, because Aeria VPN is planned to eventually integrate into **Aeria+** — an existing Aeria product, today a premium streaming/TV service ("what if Apple did a streaming network"), which will in the future bundle VPN, streaming, and other Aeria products together.
3. **tvOS is explicitly not a VPN launch focus.** The tvOS-as-differentiator argument in the original competitive analysis (`/docs/business/competitive-analysis.md`) is no longer the strategy for the VPN product specifically — Apple TV's role, if any, is downstream of the Aeria+ bundle strategy, not something the VPN roadmap should lead with.
4. To begin with, the VPN still needs to be **built for all platforms** — this is a sequencing statement, not a "launch everywhere simultaneously" one: every platform is in scope, but not all at once.

## Decision

Revise platform sequencing to:

1. **Mac and iPhone — lead platforms.** Built together, first. iPad ships alongside iPhone via the shared SwiftUI/size-class-adaptive codebase (ADR 0002) at negligible incremental cost, not as separate priority work.
2. **Windows and Android — fast-follow, not indefinitely deferred.** These ship shortly after the Mac/iPhone MVP is stable and commercially live, not "someday, if evidence demands it" as ADR 0003 originally framed Android. This is a direct consequence of point 1 above: Aeria wants broad device reach, not Mullvad-style narrowness.
3. **Apple TV — deprioritized out of the near-term VPN roadmap.** tvOS NetworkExtension support is still technically real and documented (`/docs/research/apple-platform-requirements.md`) for if/when it's needed, but Apple TV is not a Phase 1-8 deliverable for the VPN product. Its future, if any, is tied to Aeria+ bundle strategy, which is out of this document's scope.

## Rationale

- Mac-first is not primarily a "which platform is easiest" engineering call — it's a **business** call: Aeria+ (streaming) is the sibling product this VPN is ultimately meant to integrate with, and Mac is where that integration matters most. Engineering priority follows business priority here, not the other way around.
- "Accessible on any device" directly changes the competitive positioning: Aeria is not trying to out-narrow Mullvad/IVPN on platform minimalism. The differentiation stays craft + trust + honest pricing (`/docs/business/positioning.md`), but reach is closer to the mainstream players (Nord, Surfshark, ExpressVPN) than to the privacy-purist minimalists — see updated `/docs/business/competitive-analysis.md`.
- Keeping Windows/Android as fast-follow rather than indefinitely deferred avoids the original brief's risk of Aeria being read as "Apple-only forever," which conflicts with the "any device" instruction directly.
- WireGuard (ADR 0001) and the platform-neutral control-plane API (ADR 0004) already made no Apple-only assumptions, so this sequencing change requires **no architecture rework** — only roadmap and positioning updates.

## Consequences

- `/docs/product/ROADMAP.md` phase order changes: Mac ships alongside iPhone in the earliest client-facing phase (not after Apple TV as in the original phase list); Windows and Android move up to immediately follow the Apple MVP launch; Apple TV is removed from the numbered phase list and noted only as a future, Aeria+-contingent possibility.
- `/docs/product/PRODUCT_REQUIREMENTS.md` MVP platform list changes to iPhone + iPad + Mac (Apple TV removed as an MVP-conditional item).
- `/docs/business/competitive-analysis.md` and `/docs/business/positioning.md` de-emphasize tvOS as the headline differentiator; Mac craft and multi-platform reach (without sacrificing premium positioning) become the emphasized points.
- Windows client work (native, not shared Swift code — ADR 0002 already anticipated this) and Android client work should each get real design/engineering investment on a fast-follow timeline, not treated as an afterthought bolted onto a finished Apple product.
- Aeria+ itself (the streaming product and eventual bundle) is **out of scope** for this VPN engineering effort — it is referenced here only as the business rationale for Mac priority, not something this codebase builds.
