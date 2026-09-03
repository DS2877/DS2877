# Aeria — Roadmap

Development proceeds in vertical slices (brief §89), not "build hundreds of files without a working product." Each phase below has an objective, deliverables, dependencies, acceptance criteria, and risks.

## Phase 0 — Architecture + Research (this phase)

- **Objective**: ground every foundational decision in primary-source research before writing product code.
- **Deliverables**: `/docs/AERIA_MASTER_PLAN.md`, `/docs/architecture/ARCHITECTURE.md` + ADRs, `/docs/business/*`, `/docs/security/THREAT_MODEL.md` + `data-collection.md`, `/docs/product/PRODUCT_REQUIREMENTS.md` + this roadmap, `/docs/research/*`.
- **Dependencies**: none.
- **Acceptance criteria**: every major technical/legal claim in the above documents is either sourced or explicitly flagged as unverified/requiring counsel.
- **Risks**: research staleness (Apple policy, pricing) by the time of actual implementation — re-verify before Phase 8 (App Store submission) specifically.

## Phase 1 — WireGuard prototype (Milestone 1)

- **Objective**: prove the core technology end-to-end before any product surface is built around it.
- **Deliverables**: one manually-provisioned Linux VPN node (WireGuard configured by hand, acceptable at this phase only — automation comes in Phase 4), one minimal iOS app that establishes a real WireGuard tunnel via `NEPacketTunnelProvider`/`WireGuardKit` and routes real traffic.
- **Dependencies**: Phase 0 ADR 0001 (WireGuard), ADR 0002 (native Swift).
- **Acceptance criteria** (brief §105, verbatim intent): VPN connects; external IP changes; DNS works; IPv4 works; IPv6 behavior is understood and documented; disconnect works; reconnect works; server failure is handled; no false "Protected" state ever shown.
- **Risks**: NetworkExtension entitlement/provisioning-profile setup friction (self-service per research, but first-time setup can still surface surprises); physical-device requirement (brief §104) — simulator cannot validate this milestone.

## Phase 2 — Aeria iOS MVP (client shell)

- **Objective**: build the minimal real product UI around the proven tunnel from Phase 1 — main screen, connect/disconnect, connection state machine (`/docs/product/PRODUCT_REQUIREMENTS.md`).
- **Deliverables**: iOS app with the Phase 1 tunnel wired into a real (not placeholder) UI; no auth or subscription yet — single hardcoded test server acceptable at this stage.
- **Dependencies**: Phase 1.
- **Acceptance criteria**: main screen accurately reflects real tunnel state at all times; kill switch behavior begins being tested against the matrix in `/docs/product/PRODUCT_REQUIREMENTS.md`.
- **Risks**: scope creep into auth/subscription before the core loop is solid — resist per vertical-slice discipline.

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

## Phase 5 — Mac/iPad + Subscriptions

- **Objective**: expand to the other MVP-required Apple platforms and turn on real billing.
- **Deliverables**: native Mac app (not menu-bar-only — ADR 0002/competitive differentiation), iPad-adapted layouts, StoreKit 2 integration with server-side App Store Server API verification (`/docs/architecture/ARCHITECTURE.md` §3), 7-day trial flow.
- **Dependencies**: Phase 3 (backend), Phase 4 (real multi-node infra to sell access to).
- **Acceptance criteria** (Milestone 4, brief §108): full commercial flow — Install → Sign in → Trial/Subscribe → Choose location → Connect → Protected — works end-to-end on iPhone, iPad, and Mac.
- **Risks**: server-side subscription verification is the single most trust-critical piece of billing logic — under no circumstance ship a client-trusts-itself shortcut.

## Phase 6 — Apple TV

- **Objective**: ship the tvOS client, Aeria's key strategic differentiator (`/docs/business/competitive-analysis.md`).
- **Deliverables**: tvOS app (min tvOS 17, whole-tunnel only per `/docs/research/apple-platform-requirements.md`), focus-engine-idiomatic minimal UI, physical Apple TV testing (brief §104).
- **Dependencies**: Phase 5 (shared backend/subscription infra).
- **Acceptance criteria** (Milestone 5, brief §109): shared Aeria design language across iPhone/iPad/Mac/Apple TV; VPN connects and holds reliably on a physical Apple TV across real network conditions.
- **Risks**: tvOS extension target build-config gotcha noted in research (`productType` must be `com.apple.product-type.app-extension`) — budget time for this.

## Phase 7 — Security hardening

- **Objective**: close the gaps intentionally deferred earlier — full threat-model follow-up documents, zero-trust admin panel, incident response, key management, data subject rights (GDPR) implementation.
- **Deliverables**: `/docs/security/incident-response.md`, `/docs/security/key-management.md`, `/docs/operations/disaster-recovery.md`, account deletion/export flows, admin MFA + audit logging live (not just documented).
- **Dependencies**: Phases 3-6 (there must be a real system to harden).
- **Acceptance criteria**: every threat in `/docs/security/THREAT_MODEL.md` has a corresponding implemented (not just documented) mitigation before Phase 8.
- **Risks**: this phase is the one most likely to be compressed under launch-date pressure — brief §102 explicitly forbids trading security for speed; treat this phase as non-negotiable gate, not optional polish.

## Phase 8 — App Store launch

- **Objective**: public availability.
- **Deliverables**: `/docs/release/app-store-checklist.md` fully executed — organization Apple Developer account, entitlements, Guideline 5.4 disclosure screen, Privacy Nutrition Label matching `/docs/security/data-collection.md` exactly, TestFlight phased rollout history (private alpha → closed beta → public beta), final legal documents (with counsel).
- **Dependencies**: Phase 7 complete.
- **Acceptance criteria**: passes App Review; phased release monitored per `/docs/product/PRODUCT_REQUIREMENTS.md` target metrics.
- **Risks**: Apple policy drift since Phase 0 research — re-verify Guideline 5.4/4.8 text and StoreKit/App Store Server API specifics immediately before submission, not from Phase 0 notes alone.

## Phase 9 — Windows

- **Objective**: secondary-priority platform, same backend/protocol (ADR 0003 keeps this additive, not a rewrite).
- **Deliverables**: native Windows client following Aeria's design language, reusing the existing Control API and WireGuard-based data plane unchanged.
- **Dependencies**: Phase 8 (Apple launch should be stable first, per explicit Apple-first strategy).

## Phase 10 — Scale

- **Objective**: grow from thousands to hundreds of thousands of users without a rewrite (`/docs/architecture/ARCHITECTURE.md` §8 — no premature Kubernetes, no premature multi-region).
- **Deliverables**: driven by real usage data at that point — multi-region control plane only if load actually requires it, FinOps dashboard, expanded server footprint based on real demand signals, family plan.
- **Dependencies**: Phase 8 launched and stable.

---

## Explicit non-goals through Phase 8

Android, dedicated IP, double VPN, Tor, obfuscation, DNS/tracker/ad blocking, permanent free tier, multi-region control plane, Kubernetes. Revisit each only with evidence, not by default (`/docs/architecture/ARCHITECTURE.md` §8, `/docs/architecture/adr/0003-no-android-mvp.md`).
