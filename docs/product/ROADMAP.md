# Aeria — Roadmap

Development proceeds in vertical slices (brief §89), not "build hundreds of files without a working product." Each phase below has an objective, deliverables, dependencies, acceptance criteria, and risks.

**Platform sequencing note (2026-09-03, ADR 0007):** Mac and iPhone are built together as the lead platforms, not iPhone-then-Mac-later as originally phased. Windows and Android are fast-follow phases immediately after Apple launch, not indefinitely deferred. Apple TV is removed from the numbered roadmap — see "Apple TV / tvOS" note at the bottom.

## Phase 0 — Architecture + Research (done)

- **Objective**: ground every foundational decision in primary-source research before writing product code.
- **Deliverables**: `/docs/AERIA_MASTER_PLAN.md`, `/docs/architecture/ARCHITECTURE.md` + ADRs, `/docs/business/*`, `/docs/security/THREAT_MODEL.md` + `data-collection.md`, `/docs/product/PRODUCT_REQUIREMENTS.md` + this roadmap, `/docs/research/*`.
- **Dependencies**: none.
- **Acceptance criteria**: every major technical/legal claim in the above documents is either sourced or explicitly flagged as unverified/requiring counsel.
- **Risks**: research staleness (Apple policy, pricing) by the time of actual implementation — re-verify before Phase 7 (App Store submission) specifically.

## Phase 1 — WireGuard prototype (Milestone 1)

- **Objective**: prove the core technology end-to-end before any product surface is built around it.
- **Deliverables**: one manually-provisioned Linux VPN node (WireGuard configured by hand, acceptable at this phase only — automation comes in Phase 4), one minimal client (iOS, the faster of the two lead platforms to prototype a `NEPacketTunnelProvider` extension on) that establishes a real WireGuard tunnel via `WireGuardKit` and routes real traffic.
- **Dependencies**: Phase 0 ADR 0001 (WireGuard), ADR 0002 (native Swift).
- **Acceptance criteria** (brief §105, verbatim intent): VPN connects; external IP changes; DNS works; IPv4 works; IPv6 behavior is understood and documented; disconnect works; reconnect works; server failure is handled; no false "Protected" state ever shown.
- **Risks**: NetworkExtension entitlement/provisioning-profile setup friction (self-service per research, but first-time setup can still surface surprises); physical-device requirement (brief §104) — simulator cannot validate this milestone.

## Phase 2 — Aeria client shell: iPhone + Mac together

- **Objective**: build the minimal real product UI around the proven tunnel from Phase 1, on **both** lead platforms from the start (ADR 0007) — main screen, connect/disconnect, connection state machine (`/docs/product/PRODUCT_REQUIREMENTS.md`).
- **Deliverables**: iOS app AND native Mac app (not menu-bar-only — competitive differentiation, `/docs/business/competitive-analysis.md`) with the Phase 1 tunnel wired into a real (not placeholder) UI on each; iPad gets size-class-adaptive layout from the same codebase as iPhone at this stage too. No auth or subscription yet — single hardcoded test server acceptable at this stage.
- **Dependencies**: Phase 1.
- **Acceptance criteria**: main screen accurately reflects real tunnel state at all times on both iPhone and Mac; kill switch behavior begins being tested against the matrix in `/docs/product/PRODUCT_REQUIREMENTS.md` on both platforms.
- **Risks**: building two platforms in parallel instead of one raises the temptation to under-invest in either — the Mac app must be a first-class citizen from this phase on, not a follow-on port, given it's the platform Aeria+ integration will eventually depend on (ADR 0007).

## Phase 3 — Backend (Control Plane v1)

- **Objective**: replace the hardcoded test server with a real Control API — auth, device registry, server registry (`/docs/architecture/ARCHITECTURE.md`).
- **Deliverables**: Sign in with Apple flow end-to-end (ADR 0006), device registration, `/vpn/config` issuing real per-device WireGuard peer registrations against the Phase 1 node (still manually managed).
- **Dependencies**: Phase 2, ADR 0004 (control/data plane split).
- **Acceptance criteria** (Milestone 2, brief §106): backend authenticates a user; registers a device; returns available servers; returns correct VPN configuration; rotates configuration when needed; revokes device access.
- **Risks**: server-side StoreKit verification is deferred to Phase 5 — Phase 3 must not silently skip the "no free access" boundary; gate appropriately even pre-subscription (e.g., invite-only alpha access control).

## Phase 4 — Infrastructure automation

- **Objective**: remove manual node management entirely.
- **Deliverables**: Terraform modules for Vultr (primary) and Hetzner (fallback) per ADR 0005, node bootstrap (cloud-init + node agent), node lifecycle state machine (`PROVISIONING → BOOTSTRAPPING → HEALTH_CHECK → ACTIVE → DRAINING → OFFLINE`), automated health-based rotation out of the recommended-server pool.
- **Dependencies**: Phase 3 (Control Plane must exist to register/health-check nodes against).
- **Acceptance criteria** (Milestone 3, brief §107): Aeria can automatically provision, register, health-check, and make nodes available, and drain/remove unhealthy nodes — with zero manual SSH required for routine operation.
- **Risks**: Vultr/Hetzner ToS and DDoS specifics were partially aggregator-sourced in research (`/docs/research/infra-protocol-legal-basics.md`) — confirm directly before committing real infrastructure spend.

## Phase 5 — Subscriptions + iPad polish

- **Objective**: turn on real billing and finish the third lead-platform surface (iPad-specific layout refinement beyond the adaptive baseline from Phase 2).
- **Deliverables**: StoreKit 2 integration with server-side App Store Server API verification (`/docs/architecture/ARCHITECTURE.md` §3), 7-day trial flow, iPad-specific layout refinements.
- **Dependencies**: Phase 3 (backend), Phase 4 (real multi-node infra to sell access to).
- **Acceptance criteria** (Milestone 4, brief §108): full commercial flow — Install → Sign in → Trial/Subscribe → Choose location → Connect → Protected — works end-to-end on iPhone, iPad, and Mac. (This also satisfies the brief's Milestone 5 intent — "shared Aeria design language across the Apple ecosystem" — earlier than originally planned, since Mac shipped alongside iPhone in Phase 2 rather than after Apple TV.)
- **Risks**: server-side subscription verification is the single most trust-critical piece of billing logic — under no circumstance ship a client-trusts-itself shortcut.

## Phase 6 — Security hardening

- **Objective**: close the gaps intentionally deferred earlier — full threat-model follow-up documents, zero-trust admin panel, incident response, key management, data subject rights (GDPR) implementation.
- **Deliverables**: `/docs/security/incident-response.md`, `/docs/security/key-management.md`, `/docs/operations/disaster-recovery.md`, account deletion/export flows, admin MFA + audit logging live (not just documented).
- **Dependencies**: Phases 2-5 (there must be a real system to harden).
- **Acceptance criteria**: every threat in `/docs/security/THREAT_MODEL.md` has a corresponding implemented (not just documented) mitigation before Phase 7.
- **Risks**: this phase is the one most likely to be compressed under launch-date pressure — brief §102 explicitly forbids trading security for speed; treat this phase as non-negotiable gate, not optional polish.

## Phase 7 — App Store launch (Apple platforms)

- **Objective**: public availability on iPhone, iPad, and Mac.
- **Deliverables**: `/docs/release/app-store-checklist.md` fully executed — organization Apple Developer account, entitlements, Guideline 5.4 disclosure screen, Privacy Nutrition Label matching `/docs/security/data-collection.md` exactly, TestFlight phased rollout history (private alpha → closed beta → public beta), final legal documents (with counsel).
- **Dependencies**: Phase 6 complete.
- **Acceptance criteria**: passes App Review; phased release monitored per `/docs/product/PRODUCT_REQUIREMENTS.md` target metrics.
- **Risks**: Apple policy drift since Phase 0 research — re-verify Guideline 5.4/4.8 text and StoreKit/App Store Server API specifics immediately before submission, not from Phase 0 notes alone.

## Phase 8 — Windows + Android (fast-follow)

- **Objective**: extend to the two fast-follow platforms shortly after Apple launch is stable (ADR 0007) — Aeria is not aiming for Mullvad-style narrow reach.
- **Deliverables**: native Windows client and native Android client, each following Aeria's design language, both reusing the existing Control API and WireGuard-based data plane unchanged (ADR 0001/0004 were architected platform-neutral specifically for this).
- **Dependencies**: Phase 7 (Apple launch live and stable — proves the backend/protocol under real commercial load before extending client surface area).
- **Acceptance criteria**: full commercial flow (Install → Sign in → Trial/Subscribe → Choose location → Connect → Protected) works end-to-end on Windows and on Android, each with its own platform-appropriate auth (Sign in with Apple may not be available/idiomatic on Android — evaluate email/other auth for that platform specifically when this phase starts, not assumed here).
- **Risks**: two new platforms at once is real scope — consider sequencing Windows first (closer to the Mac/desktop experience already built) and Android shortly after, rather than strictly simultaneous, if engineering capacity requires a choice.

## Phase 9 — Scale

- **Objective**: grow from thousands to hundreds of thousands of users without a rewrite (`/docs/architecture/ARCHITECTURE.md` §8 — no premature Kubernetes, no premature multi-region).
- **Deliverables**: driven by real usage data at that point — multi-region control plane only if load actually requires it, FinOps dashboard, expanded server footprint based on real demand signals, family plan.
- **Dependencies**: Phase 7 (Apple) launched and stable; Phase 8 (Windows/Android) informs whether scale pressure is Apple-only or cross-platform.

---

## Apple TV / tvOS — explicitly not a numbered phase

tvOS NetworkExtension support is real and documented (`/docs/research/apple-platform-requirements.md`: tvOS 17+, whole-tunnel only), so it remains technically available if needed later. It is deliberately excluded from this roadmap because the VPN product's Apple TV strategy, if any, is downstream of the separate **Aeria+** bundle plan (an existing Aeria streaming product) — not something the VPN engineering roadmap should build ahead of that business decision (ADR 0007).

## Explicit non-goals through Phase 7 (Apple launch)

Dedicated IP, double VPN, Tor, obfuscation, DNS/tracker/ad blocking, permanent free tier, multi-region control plane, Kubernetes, Apple TV. Windows and Android are non-goals *through Phase 7 specifically* but are committed fast-follow work in Phase 8, not indefinitely deferred (ADR 0007) — revisit the rest only with evidence, not by default (`/docs/architecture/ARCHITECTURE.md` §8).
