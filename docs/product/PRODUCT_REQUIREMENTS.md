# Aeria — Product Requirements

## MVP scope (must contain)

- **Authentication**: Sign in with Apple only (ADR 0006).
- **Subscription**: StoreKit 2, annual + monthly plans, restore purchases, server-side verification via App Store Server API (never trust client state — `/docs/architecture/ARCHITECTURE.md` §3).
- **VPN**: WireGuard (ADR 0001), connect/disconnect, server selection with automatic "fastest server" default, kill switch, DNS protection, secure on-device credential storage.
- **Platforms**: iPhone, iPad, Mac. Apple TV included if technically stable enough at launch time (tvOS 17+ NetworkExtension support confirmed feasible — `/docs/research/apple-platform-requirements.md`); otherwise ships immediately after iOS/macOS.

## Explicitly NOT in MVP

Dedicated IP, double VPN, Tor, obfuscation, ad blocker, antivirus, password manager, identity-theft monitoring, file storage, browser, email, cryptocurrency payments, social features, permanent free tier, Android. Each future feature must pass: *does this strengthen Aeria's core proposition* (privacy, simplicity, Apple-ecosystem craft)? If not, it doesn't belong even post-MVP.

## Core user flow (must work end-to-end, acceptance-tested)

```
Install → Sign in → Trial/Subscribe → Choose location → Connect → Protected
```

### VPN connection — acceptance criteria

Given a valid subscription:
1. User opens Aeria.
2. User taps Connect.
3. App selects optimal server (or the user's manual choice).
4. VPN tunnel establishes.
5. UI reports "Protected" — **only once the tunnel is actually verified up**, never optimistically (brief §103: never fake functionality).
6. External IP changes (verifiable).
7. DNS resolves through the intended DNS path (no leak).
8. Traffic remains protected through Wi-Fi/cellular transitions, sleep/wake, and server hiccups (kill switch engages instead of leaking).

If any step fails, the feature is not complete — "it compiles" is not a completion bar (brief §91).

## VPN connection state machine

```
DISCONNECTED
    -> CONNECTING (server selected, tunnel handshake in progress)
    -> CONNECTED (handshake verified, UI may say "Protected")
    -> RECONNECTING (handshake lost, kill switch engages, traffic blocked until restored)
    -> DISCONNECTING (user- or system-initiated teardown)
    -> DISCONNECTED
ERROR states branch from CONNECTING/RECONNECTING when a server/auth/subscription failure is terminal (not transient) -> surfaced to user in plain language, never silently retried forever.
```

The "Protected" UI state is driven strictly by verified tunnel state, never by user intent (tapping Connect ≠ Protected until the handshake is confirmed).

## Kill switch — desired behavior

```
VPN CONNECTED -> VPN FAILS -> TRAFFIC BLOCKED -> VPN RECONNECTS -> TRAFFIC RESTORED
```

Test matrix (must pass before any release, physical-device-tested per brief §104): Wi-Fi → cellular, cellular → Wi-Fi, airplane mode, router reboot, server failure, DNS failure, VPN process failure, sleep/wake, Mac network changes, Apple TV network changes.

## Auto-connect / On-Demand

Trusted-network model:
```
Home Wi-Fi   -> Trusted   -> VPN off (user-configurable, off by default is a product decision to confirm during design)
Office Wi-Fi -> Protected -> VPN auto-connects
Public Wi-Fi -> Protected -> VPN auto-connects
```
Implemented via platform on-demand VPN rules where supported (iOS/iPadOS/macOS); tvOS has no per-app on-demand distinction given whole-tunnel-only support (`/docs/research/apple-platform-requirements.md`).

## Main screen — design philosophy

Minimal, no information shown "because it's there" — every element must have a purpose (brief §27).

Connected example:
```
AERIA
● PROTECTED
Sweden · Stockholm
184 Mbps · 12 ms
[Disconnect]
```

Disconnected example:
```
AERIA
Not Protected
Sweden · Stockholm
[Connect]
```

## Server selection

Default: "Fastest Location" — user never needs to understand routing. Scoring model: `score = latency_weight + packet_loss_weight + load_weight + availability_weight + geography_weight` (`/docs/architecture/ARCHITECTURE.md` §6) — never hardcode "closest = best."

Manual server list groups by proximity tier (Recommended / Europe / Americas / etc.) with live latency shown; favorites supported.

## Device management

```
Your devices
  iPhone 17 Pro     (rename, remove, last active, platform, app version)
  MacBook Pro
  iPad Pro
  Apple TV
```
No collection of device data beyond what's needed for this feature (`/docs/security/data-collection.md`).

## Server locations — MVP launch footprint (recommendation)

Small, premium footprint, not 50+ countries (brief §15, `/docs/business/competitive-analysis.md`). Candidate set to validate against latency/demand/legal considerations before finalizing: Sweden, Finland, Denmark, Norway, Germany, Netherlands, UK, USA. Exact final footprint is a Phase 3-4 decision made against real latency testing and provider node availability (`/docs/product/ROADMAP.md`), not fixed here.

## API surface (draft — refined during implementation)

```
POST   /auth/apple
GET    /me
GET    /devices
POST   /devices
DELETE /devices/:id
GET    /servers
GET    /servers/recommended
POST   /vpn/config
POST   /vpn/config/rotate
GET    /subscription
POST   /subscription/verify
GET    /health
```

## Node lifecycle

```
PROVISIONING -> BOOTSTRAPPING -> HEALTH_CHECK -> ACTIVE -> DRAINING -> OFFLINE
```
An unhealthy node is automatically drained out of the server-selection pool (`/docs/architecture/ARCHITECTURE.md` §4).

## Admin panel (sections, MVP-relevant subset first)

Overview, Users, Subscriptions, Devices, Servers, Regions, Health, Audit Logs. (Incidents, Abuse, Infrastructure/FinOps dashboards are Phase 4+ additions — brief §80-81 — not required for Milestone 1-4.)

## CI/CD pipeline

```
Commit -> Lint -> Unit tests -> Integration tests -> Security scan -> Build -> Deploy staging -> Smoke tests -> Production (manual approval gate)
```
GitHub Actions. Never skip stages to ship faster (brief §102: security over speed).

## Target metrics (initial proposals, to refine with real data)

Connection success >99%, API availability >99.9%, crash-free sessions >99.5%, fast connection establishment (target sub-2s handshake on a healthy network — to validate against real measurement, not asserted here), minimal measurable battery impact versus no-VPN baseline.

## Quality bar (definition of done)

Compiles, tests pass, real-device tested (simulator is not sufficient for NetworkExtension — brief §104), error states handled, loading state handled, offline state handled, security considered, logging considered (per `/docs/security/data-collection.md` boundaries), accessibility considered (Dynamic Type, VoiceOver, sufficient contrast, reduced motion), documentation updated.
