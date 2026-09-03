# Aeria — Business Plan

Supporting documents: `/docs/business/competitive-analysis.md`, `/docs/business/customer-personas.md`, `/docs/business/positioning.md`, `/docs/business/unit-economics.md`. Research sources: `/docs/research/`.

## Executive summary

Aeria is a premium VPN subscription service, built with Apple-native craft and broad device reach as a deliberate goal. It competes not on server count or feature breadth but on native platform craft, architectural privacy, and honest pricing — a combination no current competitor owns (`/docs/business/competitive-analysis.md`). Target launch footprint: Mac and iPhone/iPad first (Mac prioritized for future integration with Aeria+, an existing Aeria streaming product — `/docs/architecture/adr/0007-platform-sequencing.md`), with Windows and Android as committed fast-follow phases. Apple TV is out of the near-term roadmap. MVP is subscription-only, no permanent free tier, 7-day trial, WireGuard-based.

## Market

The consumer VPN market is mature and commoditized on the dimensions most competitors compete on (server count, protocol support, basic audit claims — see `/docs/business/competitive-analysis.md`). It is not commoditized on Apple-ecosystem-specific craft or pricing honesty. Aeria's addressable market is not "all internet users" but the intersection of Apple-device-heavy households/professionals and the growing privacy-aware consumer segment — sized at a fraction of the total VPN market but with materially higher willingness-to-pay per the personas in `/docs/business/customer-personas.md`.

## Business model

Subscription-only SaaS. Monthly and annual plans via App Store in-app purchase (StoreKit 2), family plan deferred to post-MVP. Full pricing rationale and modeled unit economics: `/docs/business/unit-economics.md`.

- Monthly: €9.99
- Annual: €79.99 (≈€6.67/mo equivalent)
- No permanent free tier; 7-day free trial with payment method required
- Renewal price = list price, always (core differentiator vs. teaser-then-shock competitor pricing)

## Go-to-market

Per the brief (§87), Aeria should not rely entirely on paid acquisition:

- **App Store discovery/ASO** — description, keywords, screenshots per `/docs/release/app-store-checklist.md` (in progress).
- **Apple-focused communities** — where Apple enthusiasts already gather; credible because the product genuinely is Apple-native, not marketing-only positioning.
- **Privacy-conscious communities** (Reddit r/privacy-adjacent spaces, etc.) — credible only if Aeria's actual data-collection practice (`/docs/security/data-collection.md`) holds up to scrutiny; do not overclaim.
- **Tech/Apple-focused reviewers and YouTube** — a product built with genuine design craft is reviewable/demoable in a way commodity VPNs aren't.
- **Referral program** — deferred to post-launch; not required for MVP.

Full paid-acquisition, CAC-target, and channel-budget planning is deferred until Phase 1-2 trial/conversion data exists (`/docs/business/unit-economics.md` §Key unmodeled variables) — modeling CAC today would be unfounded precision.

## Launch strategy

Phased rollout per the brief: Private alpha (5-20 users) → Closed beta (50-200) → Public beta (500-2,000) → Public App Store launch, using TestFlight throughout. See `/docs/product/ROADMAP.md` for how this maps to engineering phases and milestones.

## KPIs and North Star Metric

Tracked categories: Acquisition (installs, conversion, CAC), Product (activation, first successful connection, DAU/WAU), Revenue (MRR, ARR, ARPU, LTV, churn), Reliability (connection success rate, crash rate, server health).

**Proposed North Star Metric: Successfully protected sessions per paying customer per week.** Rationale: it's the metric that most directly reflects the product's actual job (protect a session, reliably, repeatedly) rather than a proxy like DAU that could be gamed by re-engagement nudges the brand explicitly rejects (no urgency marketing, no dark patterns — `/docs/business/positioning.md`). Revisit once real usage data can validate whether this metric actually correlates with retention.

## Legal/compliance checkpoints requiring professional counsel (not resolved here)

- Company structure and formation (jurisdiction, likely Sweden given founding context).
- Trademark clearance for "Aeria" / "Aeria VPN."
- Final Terms of Service, Privacy Policy, Acceptable Use Policy, Refund Policy — drafted with counsel, not generated as legally-binding text by this process.
- GDPR compliance program sign-off (grounding research exists at `/docs/research/infra-protocol-legal-basics.md` and `/docs/privacy/`, but is explicitly not a substitute for legal review).
- VAT/consumer-rights treatment across target launch markets (partially simplified by App Store billing, per `/docs/business/unit-economics.md`, but not eliminated as a checkpoint).
- Any VPN-specific licensing requirement in a given launch territory (App Store Guideline 5.4 requires this to be declared in App Review Notes if applicable — `/docs/research/apple-platform-requirements.md`).

This document does not take legal positions on any of the above — it flags them as required checkpoints, per the brief's explicit instruction not to invent legal certainty.

## Open items (deliberately deferred, not overlooked)

- Full 12/24/36-month Conservative/Base/Aggressive financial scenarios — blocked on real churn/CAC data (`/docs/business/unit-economics.md`).
- Company economics (staffing plan, burn rate, funding requirement) — outside this document's scope until a team/funding plan exists.
- FinOps dashboard (§80 of the brief) — a Phase 4+ engineering deliverable, not a Phase 0 planning document.
