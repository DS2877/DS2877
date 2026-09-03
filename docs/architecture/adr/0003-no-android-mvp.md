# ADR 0003: No Android app in MVP

**Status:** Superseded by ADR 0007 (2026-09-03) — Android remains out of MVP, but is now an explicit fast-follow phase rather than an indefinitely-deferred one. See ADR 0007 for the current platform sequencing and the reasoning behind the change. This ADR is kept for history.
**Date:** 2026-09-03 (original)

## Context

The brief mandates an Apple-first strategy and explicitly forbids building Android in MVP absent a strong business/technical reason. No such reason has surfaced during research.

## Decision

Do not build an Android client in MVP (Phases 0-8). Document a forward-compatible path instead.

## Rationale

- Product differentiation (see `/docs/business/competitive-analysis.md`) is explicitly Apple-ecosystem-first: tvOS-idiomatic UI, deep NetworkExtension integration, StoreKit-native billing. Splitting design/engineering attention across a second platform family before the primary one is polished directly undermines the core strategy.
- Every major competitor already covers Android; it is not a differentiator, it is table stakes Aeria can defer.
- WireGuard as the protocol choice (ADR 0001) and a REST control-plane API (ADR 0004) are both platform-agnostic — so nothing architected for MVP blocks an eventual Android client.

## Consequences

- (Original, superseded) Android was scoped out through Phase 8 (App Store launch) of `/docs/product/ROADMAP.md` with no committed follow-up date. **This is no longer current** — see ADR 0007: Android is now a committed Phase 8 fast-follow deliverable, immediately after Apple launch.
- The control-plane API and WireGuard key-registration flow (ADR 0004) must remain platform-neutral (no Apple-only assumptions baked into the API contract) specifically so that a future Android client is additive, not a rewrite.
- Revisit this decision only with a concrete, evidenced trigger (e.g., post-launch demand data, a partnership requiring it) — not by default at the next planning cycle.
