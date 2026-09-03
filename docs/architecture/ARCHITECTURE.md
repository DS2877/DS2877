# Aeria — Architecture

Status: living document. Decisions with rationale live as ADRs in `/docs/architecture/adr/` — this document is the map, not the source of truth for *why*.

## 1. System overview

Aeria has two independently-scalable systems (ADR 0004):

```
Aeria Clients (iOS/iPadOS/macOS/tvOS, later Windows)
        |
        v
Aeria Control API  <-- stateless app servers, PostgreSQL (source of truth) + Redis (cache/rate-limit/ephemeral state)
        |
        +-- Sign in with Apple verification
        +-- App Store Server API (subscription state, source of truth server-side)
        +-- Device Registry
        +-- Server Registry + health + scoring
        |
        v
VPN Nodes (WireGuard, data plane) -- provisioned via Terraform, stateless peer sets
        |
        v
Internet
```

The Control Plane never depends on a specific VPN node being healthy. A VPN node never holds user, billing, or auth data — only ephemeral WireGuard peer state.

## 2. Client architecture (Apple platforms)

Native Swift/SwiftUI everywhere (ADR 0002). Shared Swift packages, platform-specific UI:

- **AeriaCore** — shared business logic, no UI, no platform-specific APIs beyond what's universally available.
- **AeriaModels** — Codable data models shared between API client and UI.
- **AeriaNetworking** — Control API client (URLSession-based), typed requests/responses, retry/backoff.
- **AeriaVPN** — wraps `NEPacketTunnelProvider` / `NETunnelProviderManager` interaction; owns connection state machine (see `/docs/product/PRODUCT_REQUIREMENTS.md` for the state machine itself); the actual tunnel provider extension links `WireGuardKit`.
- **AeriaAuthentication** — Sign in with Apple flow, session token storage in Keychain.
- **AeriaSubscriptions** — StoreKit 2 wrapper, `Transaction` listening, restore purchases.
- **AeriaDesignSystem** — shared design tokens (color, type, spacing, motion) consumed by per-platform SwiftUI views; views themselves are NOT shared 1:1 across iPhone/iPad/Mac/TV (ADR 0002) — each platform gets an idiomatic layout, especially tvOS's focus-engine-driven UI.

Per-platform app targets (`AeriaiOS`, `AeriaMac`, `AeriaTV`, each with a `PacketTunnel` extension target) consume these packages. iPad ships from the same target as iPhone with size-class-adaptive layouts (not a separate package) per the brief's "no simple iPhone-stretch" instruction.

### VPN credential handling (client side)

- WireGuard keypair generated on-device (`Curve25519` keygen via WireGuardKit), private key stored in Keychain with the strictest applicable accessibility class, never leaves the device, never transmitted, never logged.
- Only the public key is sent to the Control API when requesting a VPN configuration.
- App Group shared container passes minimal state (current connection status, selected region) between the container app and the `PacketTunnelProvider` extension — no credentials duplicated into the App Group store.

## 3. Control Plane

- **API**: REST (see draft endpoint list in `/docs/product/PRODUCT_REQUIREMENTS.md`), versioned, JWT session tokens issued after Sign in with Apple verification.
- **Database**: PostgreSQL. Entities: User, Device, Subscription, Product, Server, Region, ServerHealth, VPNConfiguration, FeatureFlag, AuditEvent (see `/docs/architecture/ARCHITECTURE.md#5-data-model` below). No speculative tables — every column must have a named consumer.
- **Cache/ephemeral state**: Redis — rate limiting, server-selection scoring cache, distributed locks during node provisioning. Redis is never the source of truth for anything durable (subscription state, device registration).
- **Subscription verification**: server-side via the App Store Server API (JWT-authenticated, `getAllSubscriptionStatuses` + App Store Server Notifications V2 webhooks) — the client's StoreKit state is never trusted directly for entitlement decisions (ADR reference: `/docs/research/apple-platform-requirements.md` §4).

## 4. Data Plane (VPN nodes)

- Each node runs: a WireGuard kernel interface, a minimal **node agent** (internal-network-only API: add/remove peer, report health metrics), and a health-probe sidecar.
- **Node lifecycle** (see `/docs/product/PRODUCT_REQUIREMENTS.md` for full state machine): PROVISIONING → BOOTSTRAPPING → HEALTH_CHECK → ACTIVE → DRAINING → OFFLINE.
- **Provisioning**: Terraform against the chosen cloud provider (ADR 0005: Vultr primary, Hetzner fallback), cloud-init bootstrap installs WireGuard + node agent, node self-registers with the Control Plane, which then health-checks before marking it ACTIVE and eligible for the server-selection algorithm.
- Nodes carry **no persistent user data**. Losing a node loses only in-flight connections for users routed to it (who reconnect through the client's normal failure-handling path) — never data.

## 5. Data model (initial entities)

| Entity | Purpose | Notes |
|---|---|---|
| User | Apple-ID-derived stable identity | No email required to function (Sign in with Apple relay email optional) |
| Device | One per registered client install | Holds device name, platform, app version, last-active, WireGuard public key reference |
| Subscription | Mirrors App Store Server API state | Server-authoritative, refreshed via webhook + periodic reconciliation |
| Product | StoreKit product catalogue mirror | monthly / annual / (future) family |
| Server | A single VPN node | region, provider, capacity, current load |
| Region | Logical grouping (e.g. "Sweden") | may map to 1+ Servers |
| ServerHealth | Time-series-ish health snapshots | latency, packet loss, load, availability — feeds scoring, short retention |
| VPNConfiguration | Active peer registration | device_id, server_id, public_key, allowed_ips, issued_at |
| FeatureFlag | Operational rollout control | boolean/percentage flags, admin-managed |
| AuditEvent | Admin/action audit trail | append-only, access-controlled (see `/docs/security/THREAT_MODEL.md`) |

Explicitly **not** modeled: browsing history, DNS query logs, destination IPs, traffic content — see `/docs/security/data-collection.md`.

## 6. Server selection algorithm

`score = latency_weight + packet_loss_weight + load_weight + availability_weight + geography_weight` (weights tunable, not hardcoded "closest = best"). Client measures latency to a small candidate set (recommended region + user's manually-favorited regions); Control API supplies live load/availability/packet-loss from ServerHealth. Default UX is "Fastest Location" — the user never has to understand routing (see `/docs/product/PRODUCT_REQUIREMENTS.md`).

## 7. Environments

`local` → `development` → `staging` → `production`. No development against production. CI/CD: GitHub Actions, pipeline per `/docs/product/PRODUCT_REQUIREMENTS.md` operations section; production deploy requires deliberate approval gate.

## 8. What this architecture deliberately does NOT include yet

Per the brief's anti-overengineering instruction (§101) and "boring infrastructure that works" (§79):
- No Kubernetes — Terraform + systemd-managed node agents is sufficient at MVP scale.
- No multi-region control plane — single control-plane region (EU, for GDPR-simplicity — see `/docs/research/infra-protocol-legal-basics.md`) until real load requires otherwise.
- No dedicated IP, double-hop, obfuscation, or DNS-blocklist features — out of MVP scope (`/docs/product/PRODUCT_REQUIREMENTS.md` §"What NOT to build").
