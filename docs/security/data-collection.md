# Aeria — Data Collection Policy

Principle: **if Aeria doesn't need the data, Aeria should not collect it.** This document states exactly what is and isn't collected, and is the source of truth that the Privacy Policy and App Store Privacy Nutrition Label must match — never the other way around.

Legal grounding: `/docs/research/infra-protocol-legal-basics.md` (GDPR basics — orientation only, not legal advice; final Privacy Policy requires counsel review per `/docs/business/BUSINESS_PLAN.md`).

## Categories of data, separated by purpose

Per the brief's explicit instruction, these are kept architecturally separate — different retention, different access controls, never joined into a single "user activity" record.

### 1. Authentication information
- Apple-ID-derived stable user identifier (from Sign in with Apple).
- Optional Apple private relay email, if provided.
- Session tokens (short-lived, revocable).
- **Not collected**: Apple ID itself, real email (unless the user's Apple relay email is used, which Aeria never reverses).

### 2. Billing information
- Subscription state mirrored from the App Store Server API (product, status, expiry, renewal).
- **Not collected**: payment card details (App Store handles all payment; Aeria never sees card data).

### 3. Device/account management information
- Device name (user-editable), platform, app version, last-active timestamp, WireGuard **public** key reference.
- **Not collected**: device hardware identifiers beyond what's needed for the above; private WireGuard keys (never leave the device — see ADR 0004).

### 4. Operational telemetry (aggregate, non-identifying where possible)
- Connection success/failure counts, reconnect events, crash reports, onboarding funnel completion.
- Purpose: reliability engineering and product improvement only.
- **Not collected**: which server/region tied to which user beyond what's needed for active-session support (see §5); no linkage to browsing behavior.

### 5. Security telemetry
- VPN node health (CPU, RAM, disk, bandwidth, packet loss, latency, active session **count** — not session content), abuse-signal indicators (e.g., rate-limit triggers on the Control API).
- **Not collected**: per-session destination IPs, DNS queries, traffic content, browsing history — explicitly, permanently, architecturally.

## What Aeria will NEVER log, by design

- Browsing history
- DNS queries
- Destination IP addresses of user traffic
- Traffic content (payload)
- Detailed per-user activity timelines that could reconstruct browsing behavior

This is not just a policy statement — it constrains the architecture: VPN nodes run WireGuard peer state only, no packet logging, no NetFlow/traffic-accounting tied to destination. See `/docs/security/THREAT_MODEL.md` for the corresponding technical controls.

## Retention

| Data category | Retention | Rationale |
|---|---|---|
| Auth session tokens | Until expiry/revocation (short-lived) | Minimize replay window |
| Billing/subscription state | Duration of account + minimum legally-required period after cancellation | Refund/dispute handling, tax record obligations (exact period: counsel to confirm per jurisdiction) |
| Device records | Until user removes device or account deletion | User-facing feature (device management) |
| Operational telemetry | 30-90 days, aggregate only | Enough for reliability trend analysis, not indefinite retention |
| Security telemetry (node health) | 30 days raw, longer-term aggregated/anonymized trend data only | Capacity planning without indefinite per-node/per-session detail |
| Admin audit log (AuditEvent) | Longer retention (12+ months) | Security/incident investigation requires this to survive longer than operational data — see `/docs/security/THREAT_MODEL.md` |

Exact final retention periods are a joint product/legal decision, not unilaterally engineering's — flagged here as defaults, not final.

## Data subject rights (GDPR Chapter III)

Account deletion, data export, and correction must be supported end-to-end (not just "requestable via support email") before public launch. This is a Phase 6/7 engineering deliverable (`/docs/product/ROADMAP.md`), tracked from day one so the data model (`/docs/architecture/ARCHITECTURE.md`) doesn't accumulate fields that later make deletion/export hard to implement correctly.

## Product analytics boundary

Product analytics (onboarding completion, connection success/failure, subscription conversion, feature usage, crash rate) is allowed. Tracking browsing history, websites visited, DNS queries, or destination traffic is never allowed, regardless of product-analytics justification (brief §82, restated here as a hard boundary).
