# Aeria — Master Plan

**Status**: Phase 0 (Architecture + Research) complete. This document is the entry point into the full plan — every claim below is backed by a linked document; this file is a summary, not the source of truth.

## What Aeria is

A premium, Apple-ecosystem-first VPN subscription service. Core promise: *Open Aeria → tap Connect → you're protected.* Positioning: "Privacy, beautifully simple." Full detail: `/docs/business/positioning.md`.

## Why now / why this shape

Competitive research (`/docs/business/competitive-analysis.md`) found a real gap: mainstream VPNs (NordVPN, Surfshark, ExpressVPN, CyberGhost, PIA) compete on server count and feature bundling with commodity trust and manipulative renewal pricing; privacy-purist minimalists (Mullvad, IVPN) have excellent trust but neglect platform craft (Mullvad's Mac app is menu-bar-only; neither has an Apple TV app). Nobody currently combines Apple-ecosystem-native craft, architectural privacy, and honest pricing. That's Aeria's opening.

## Foundational decisions (all documented as ADRs, `/docs/architecture/adr/`)

| Decision | Choice | Why (one line) |
|---|---|---|
| VPN protocol | WireGuard | Reviewed cryptography, MIT-licensed official Apple reference implementation, no custom crypto written |
| Client UI | Native Swift/SwiftUI, no cross-platform framework | NetworkExtension/StoreKit reliability and Apple-native feel are non-negotiable |
| Android | Not in MVP | Focus; API/protocol stay platform-neutral so it's additive later, not a rewrite |
| System split | Control Plane (auth/billing/registry) vs. Data Plane (VPN nodes) | Nodes are disposable/stateless; control plane never depends on one node |
| Key handling | Client generates WireGuard keypair on-device; only public key ever transmitted | Same pattern as Mullvad/Cloudflare WARP in production |
| Server provider | Vultr primary, Hetzner fallback, OVH excluded | OVH's own ToS bans VPN hosting; Vultr has best bandwidth economics + official Terraform provider without that risk |
| Authentication | Sign in with Apple only, MVP | Avoids Guideline 4.8 exposure entirely, minimizes account friction |

## Business plan summary

Subscription-only, no permanent free tier, 7-day trial. Monthly €9.99 / Annual €79.99, with a deliberate commitment: **renewal price = list price, always** — the opposite of the teaser-then-shock pattern nearly every competitor uses. Full model: `/docs/business/unit-economics.md`, `/docs/business/BUSINESS_PLAN.md`. Five target personas defined in `/docs/business/customer-personas.md`; all already use or are actively evaluating a competitor — Aeria is winning switches, not creating category demand.

## Security & privacy summary

Architecture-level privacy: VPN nodes hold no user/billing/auth data, ever (`/docs/architecture/adr/0004-control-data-plane-split.md`). No browsing history, DNS queries, destination IPs, or traffic content are ever logged, by design (`/docs/security/data-collection.md`). Full threat model with actor-by-actor mitigations: `/docs/security/THREAT_MODEL.md`. GDPR grounding (not legal advice — counsel review required before launch): `/docs/research/infra-protocol-legal-basics.md`.

## Product scope

MVP: Sign in with Apple, StoreKit 2 subscriptions with server-side verification, WireGuard connect/disconnect with automatic fastest-server selection, kill switch, DNS protection, on iPhone/iPad/Mac (Apple TV if stable at launch time — technically confirmed feasible since tvOS 17). Explicitly excluded from MVP: dedicated IP, double VPN, Tor, ad/tracker blocking, antivirus, password manager, family plan, Windows, Android. Full requirements: `/docs/product/PRODUCT_REQUIREMENTS.md`.

## Roadmap (10 phases, full detail in `/docs/product/ROADMAP.md`)

0. Architecture + research (done)
1. WireGuard prototype — real iPhone, real tunnel, real server, real traffic
2. Aeria iOS MVP (client shell around the proven tunnel)
3. Backend (Control Plane v1 — auth, devices, server registry)
4. Infrastructure automation (Terraform, node lifecycle, zero manual SSH)
5. Mac/iPad + real subscriptions (server-verified)
6. Apple TV (physical-device tested)
7. Security hardening (incident response, key management, GDPR data-subject-rights flows — non-negotiable gate, not optional polish)
8. App Store launch
9. Windows
10. Scale (only what real usage data demands — no premature Kubernetes/multi-region)

## What's deliberately not done yet

- Full legal documents (Terms, Privacy Policy, refund policy) — require counsel, not generated as binding text here; checkpoints listed in `/docs/business/BUSINESS_PLAN.md`.
- Full 12/24/36-month financial scenarios — blocked on real churn/CAC data that doesn't exist pre-launch.
- Incident response, key management, disaster recovery documents — tracked as named Phase 7 deliverables, not silently dropped.
- Any real cloud spend, Apple Developer org account setup, or App Store Connect configuration — these require the user's direct action/decision, not something this process executes unilaterally.

## Immediate next step

Milestone 1 (Phase 1): the smallest real vertical slice that proves the core technology — a real iPhone establishing a real WireGuard tunnel through an Aeria-controlled server, routing real traffic, with a correct (never-faked) kill switch and connection-state model. Proposed concretely, for sign-off, in the next message — this is where implementation begins.

## Document index

```
/docs
  AERIA_MASTER_PLAN.md          <- you are here
  /business
    BUSINESS_PLAN.md
    competitive-analysis.md
    customer-personas.md
    positioning.md
    unit-economics.md
  /architecture
    ARCHITECTURE.md
    /adr  (0001-0006)
  /security
    THREAT_MODEL.md
    data-collection.md
  /product
    PRODUCT_REQUIREMENTS.md
    ROADMAP.md
  /release
    app-store-checklist.md
  /research
    apple-platform-requirements.md
    competitor-landscape.md
    infra-protocol-legal-basics.md
```
