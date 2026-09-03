# ADR 0004: Control-plane / data-plane separation, client-generated WireGuard keys

**Status:** Accepted
**Date:** 2026-09-03

## Context

The brief requires the control plane (auth, subscriptions, device/server registry) to never become dependent on any single VPN node, and requires VPN nodes to be as stateless/replaceable as possible.

## Decision

1. Split Aeria into two independently-scalable systems: a **Control Plane** (users, auth, subscriptions, device registry, server catalogue, health, feature flags, admin) and a **Data Plane** (the actual WireGuard VPN nodes carrying user traffic).
2. WireGuard keypairs are generated **on-device** by the client. Only the **public** key is ever sent to the Control Plane API. The Control Plane forwards the public key + a chosen node to the target VPN node, which adds it as a WireGuard peer. The private key never leaves the device (Keychain-backed).

## Rationale

- Matches production patterns used by Mullvad and Cloudflare WARP (client generates keypair, server only ever registers the public key) — see `/docs/research/infra-protocol-legal-basics.md`. This is the industry-standard commercial WireGuard control-plane pattern, not a novel design.
- A VPN node holds only ephemeral WireGuard peer state (public keys + allowed IPs), no user database, no billing data, no auth logic — nodes can be destroyed/replaced/re-provisioned via Terraform (see ADR 0005) without any data-loss risk, satisfying the "nodes are not databases" requirement.
- Control-plane availability is decoupled from any single node's health; a node outage degrades only the users currently routed through it, and the health system (see `/docs/product/PRODUCT_REQUIREMENTS.md`) drains it out of the recommended-server pool automatically.

## Architecture

```
Aeria Client (macOS/iOS/iPadOS lead; Windows/Android fast-follow — ADR 0007)
  |
  |  (1) Sign in with Apple -> session token
  |  (2) Register device, generate WireGuard keypair on-device
  |  (3) POST /vpn/config { device_id, public_key, region } -> Control API
  v
Aeria Control API  (stateless app servers, PostgreSQL + Redis)
  |
  +-- Auth / Subscription verification (App Store Server API)
  +-- Device Registry
  +-- Server Registry / health / scoring
  |
  |  (4) Control API calls chosen VPN Node's local agent: "add peer <pubkey>, allowed_ips=<assigned tunnel IP>"
  v
VPN Node (WireGuard interface, node agent, health probe)
  |
  v
Internet
```

## Consequences

- The Control API must never blindly trust a client-reported subscription state (see ADR on StoreKit server verification in `/docs/product/PRODUCT_REQUIREMENTS.md`) — it is the sole source of truth for "is this device allowed to get a VPN config."
- Node agents expose a minimal internal API (add/remove peer, health metrics) reachable only from the Control Plane's private network, not the public internet.
- This split enables independent scaling: Control Plane scales with user/auth/billing load, Data Plane scales with concurrent VPN sessions and bandwidth — see `/docs/architecture/ARCHITECTURE.md`.
