# ADR 0001: WireGuard as the VPN protocol

**Status:** Accepted
**Date:** 2026-09-03

## Context

Aeria needs a VPN tunneling protocol. The master brief mandates: don't implement custom cryptography, don't invent a protocol, use established/well-audited components.

## Decision

Use **WireGuard** as the sole VPN protocol for MVP (no OpenVPN, no proprietary protocol).

## Rationale

- Cryptographic construction is a Noise Protocol Framework instantiation (`Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s`) using Curve25519, ChaCha20-Poly1305, BLAKE2s — all well-established primitives, not invented by Aeria. (docs/research/infra-protocol-legal-basics.md, wireguard.com/protocol/)
- Independently reviewed: Tamarin-prover formal verification, a computational cryptographic proof (Dowling & Paterson), a mechanised computational analysis (Lipp/Blanchet/Bhargavan, EuroS&P 2019), and a unified symbolic analysis at NDSS 2024.
- Official Apple-platform reference implementation exists: `github.com/WireGuard/wireguard-apple` (`WireGuardKit` + `wireguard-go`), **MIT licensed** — confirmed by direct repo inspection of the `COPYING` file. GPL2 applies only to the Linux *kernel module*, not the Apple/Go userspace stack Aeria will use client-side. Safe for a closed-source commercial app.
- Production precedent: ProtonVPN and PIA both ship their own MIT-licensed forks of the same reference implementation.
- Small, auditable codebase (~4,000 lines) versus OpenVPN's much larger attack surface — matches the brief's "security over speed" priority.
- On the server: in-kernel WireGuard module (available in modern Linux kernels) for throughput; avoids the 20-40% user/kernel context-switch overhead of `wireguard-go` at high speeds (indicative, not an official WireGuard benchmark — flagged in research notes).

## Alternatives considered

- **OpenVPN**: mature, widely supported, but larger codebase/attack surface, generally lower throughput than WireGuard, no clear advantage for a greenfield product.
- **Proprietary protocol (e.g., ExpressVPN's Lightway model)**: rejected outright — the brief explicitly forbids inventing a protocol, and it would mean owning cryptographic risk with no commensurate benefit at this stage.

## Consequences

- Client-side: use `WireGuardKit` (Swift) inside a `NEPacketTunnelProvider` extension on every Apple platform.
- Server-side: Linux nodes running the in-kernel `wg` interface, provisioned/managed via a thin control-plane API (see ADR 0004).
- Key management: client generates its own WireGuard keypair on-device; only the **public** key is ever transmitted to Aeria's backend (see ADR 0004 and `/docs/security/THREAT_MODEL.md`). This is the same pattern used by Mullvad and Cloudflare WARP in production.
- No custom crypto code is written by Aeria at any layer.
