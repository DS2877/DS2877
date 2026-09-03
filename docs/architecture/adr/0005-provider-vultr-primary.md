# ADR 0005: Vultr as primary VPN node provider, Hetzner as fallback, OVH excluded

**Status:** Accepted
**Date:** 2026-09-03

## Context

Server provider terms of service, bandwidth economics, DDoS protection, and Terraform automation maturity all directly affect whether Aeria can legally and reliably run commercial VPN nodes. Research findings: `/docs/research/infra-protocol-legal-basics.md`.

## Decision

- **Primary provider: Vultr.**
- **Fallback provider: Hetzner** (cost-efficient EU/US anchor nodes).
- **OVH is explicitly excluded.**
- Server provisioning is built against a **provider abstraction** (see ADR 0004 / `/docs/architecture/ARCHITECTURE.md`) so Aeria is never architecturally locked to one vendor.

## Rationale

- **OVH's own Service-Specific Terms explicitly prohibit VPN hosting** ("Anonymization services or public proxy (including VPN...) are prohibited") — using OVH would put the company in direct ToS violation from day one. This is a hard exclusion, not a preference.
- **Vultr**: no VPN-specific prohibition found in its Use Policy; official, HashiCorp-built Terraform provider; generous globally-pooled bandwidth (2 TB free egress/month account-wide, flat $0.01/GB overage) — materially cheaper than AWS (~$0.09/GB) for a bandwidth-heavy product; built-in DDoS mitigation; 30+ global locations under one account, useful for standing up a small premium footprint without multi-vendor overhead.
- **Hetzner**: cheapest bandwidth found in research and no explicit VPN prohibition (Hetzner even ships a one-click WireGuard app for Cloud), but community reports (LowEndTalk, HN — anecdotal, not official) describe inconsistent abuse-handling for VPS-at-scale operators. Kept as fallback for cost-sensitive EU/US nodes, not primary, until Aeria has direct experience with their abuse-response process.
- **AWS**: technically viable (no VPN-specific AUP clause, most mature Terraform provider in the ecosystem) but bandwidth cost (~$90/TB) is roughly 9x Vultr's, unjustifiable at Aeria's target scale absent a specific need (e.g. an AWS-only region).
- **DigitalOcean**: viable alternative, not chosen as primary/fallback for MVP but not excluded from future consideration — kept out only to avoid a three-provider Terraform surface at launch.

## Consequences

- Terraform modules (see `/docs/infrastructure/`) target the Vultr provider first; a Hetzner module is built in parallel for the fallback/cost-sensitive tier, sharing the same node-bootstrap contract (cloud-init script, node agent, health check) so nodes are provider-agnostic once running.
- Before committing real spend, directly confirm Hetzner's current DDoS/ToS specifics and Vultr's full Use Policy text (both flagged as not-fully-verified in research notes) rather than relying on aggregator sources.
- Revisit provider mix once real abuse/uptime data exists post-launch.
