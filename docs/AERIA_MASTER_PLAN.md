# Aeria — Master Plan

**Status**: Phase 0 (Architecture + Research) complete, revised 2026-09-03 for updated platform strategy (ADR 0007). This document is the entry point into the full plan — every claim below is backed by a linked document; this file is a summary, not the source of truth.

## What Aeria is

A premium VPN subscription service, built with Apple-native craft, with **Mac and iPhone as the lead platforms** and broad device reach (Windows, Android fast-follow) as a deliberate goal — not a Mullvad-style narrow, single-ecosystem product. Mac priority is a business decision: Aeria VPN is planned to eventually integrate with **Aeria+**, an existing Aeria streaming/TV product, into a broader bundle — out of scope for this codebase, but the reason Mac leads. Core promise: *Open Aeria → tap Connect → you're protected.* Positioning: "Privacy, beautifully simple." Full detail: `/docs/business/positioning.md`, `/docs/architecture/adr/0007-platform-sequencing.md`.

## Why now / why this shape

Competitive research (`/docs/business/competitive-analysis.md`) found a real gap: mainstream VPNs (NordVPN, Surfshark, ExpressVPN, CyberGhost, PIA) compete on server count and feature bundling with commodity trust and manipulative renewal pricing; privacy-purist minimalists (Mullvad, IVPN) have excellent trust but neglect platform craft (Mullvad's Mac app is menu-bar-only) and narrow their reach. Aeria's opening is craft + trust + honest pricing, combined with the broad platform reach of the mainstream players rather than the minimalists' narrowness — with Mac given outsized priority for the Aeria+ integration reason above.

## Foundational decisions (all documented as ADRs, `/docs/architecture/adr/`)

| Decision | Choice | Why (one line) |
|---|---|---|
| VPN protocol | WireGuard | Reviewed cryptography, MIT-licensed official Apple reference implementation, no custom crypto written |
| Client UI | Native Swift/SwiftUI, no cross-platform framework | NetworkExtension/StoreKit reliability and Apple-native feel are non-negotiable |
| Platform sequencing | Mac + iPhone lead (built together); Windows + Android fast-follow right after; Apple TV deprioritized | Mac matters most for future Aeria+ integration; "any device" reach is explicit, not Mullvad-style narrow (ADR 0007) |
| System split | Control Plane (auth/billing/registry) vs. Data Plane (VPN nodes) | Nodes are disposable/stateless; control plane never depends on one node |
| Key handling | Client generates WireGuard keypair on-device; only public key ever transmitted | Same pattern as Mullvad/Cloudflare WARP in production |
| Server provider | Vultr primary, Hetzner fallback, OVH excluded | OVH's own ToS bans VPN hosting; Vultr has best bandwidth economics + official Terraform provider without that risk |
| Authentication | Sign in with Apple only, MVP | Avoids Guideline 4.8 exposure entirely, minimizes account friction |

## Business plan summary

Subscription-only, no permanent free tier, 7-day trial. Monthly €9.99 / Annual €79.99, with a deliberate commitment: **renewal price = list price, always** — the opposite of the teaser-then-shock pattern nearly every competitor uses. Full model: `/docs/business/unit-economics.md`, `/docs/business/BUSINESS_PLAN.md`. Five target personas defined in `/docs/business/customer-personas.md`; all already use or are actively evaluating a competitor — Aeria is winning switches, not creating category demand.

## Security & privacy summary

Architecture-level privacy: VPN nodes hold no user/billing/auth data, ever (`/docs/architecture/adr/0004-control-data-plane-split.md`). No browsing history, DNS queries, destination IPs, or traffic content are ever logged, by design (`/docs/security/data-collection.md`). Full threat model with actor-by-actor mitigations: `/docs/security/THREAT_MODEL.md`. GDPR grounding (not legal advice — counsel review required before launch): `/docs/research/infra-protocol-legal-basics.md`.

## Product scope

MVP: Sign in with Apple, StoreKit 2 subscriptions with server-side verification, WireGuard connect/disconnect with automatic fastest-server selection, kill switch, DNS protection, on **Mac, iPhone, and iPad** (built together, Mac and iPhone leading). Windows and Android are committed fast-follow phases immediately after Apple launch — not indefinitely deferred. Apple TV is out of the roadmap entirely for now (tied to the separate Aeria+ bundle decision). Explicitly excluded from MVP: dedicated IP, double VPN, Tor, ad/tracker blocking, antivirus, password manager, family plan. Full requirements: `/docs/product/PRODUCT_REQUIREMENTS.md`.

## Roadmap (9 phases + Scale, full detail in `/docs/product/ROADMAP.md`)

0. Architecture + research (done)
1. WireGuard prototype — real iPhone, real tunnel, real server, real traffic
2. Client shell: iPhone + Mac built together (not sequential)
3. Backend (Control Plane v1 — auth, devices, server registry)
4. Infrastructure automation (Terraform, node lifecycle, zero manual SSH)
5. Subscriptions (server-verified) + iPad layout polish — full commercial flow live on iPhone/iPad/Mac
6. Security hardening (incident response, key management, GDPR data-subject-rights flows — non-negotiable gate, not optional polish)
7. App Store launch (Apple platforms)
8. Windows + Android (fast-follow, not deferred)
9. Scale (only what real usage data demands — no premature Kubernetes/multi-region)

Apple TV is deliberately not a numbered phase — see `/docs/product/ROADMAP.md` for why.

## What's deliberately not done yet

- Full legal documents (Terms, Privacy Policy, refund policy) — require counsel, not generated as binding text here; checkpoints listed in `/docs/business/BUSINESS_PLAN.md`.
- Full 12/24/36-month financial scenarios — blocked on real churn/CAC data that doesn't exist pre-launch.
- Incident response, key management, disaster recovery documents — tracked as named Phase 6 deliverables, not silently dropped.
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
    /adr  (0001-0007; 0003 superseded by 0007)
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
