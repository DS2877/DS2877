# Aeria — Threat Model

Scope: the full system as described in `/docs/architecture/ARCHITECTURE.md`. This is a living document, updated as the system grows — MVP-scope threats first.

## Threat actors and analysis

| Actor | Likelihood | Impact | Primary mitigation | Detection | Recovery |
|---|---|---|---|---|---|
| **Malicious/abusive users** (spam, scanning, illegal activity via Aeria IPs) | High (any commercial VPN attracts this) | Medium (provider abuse reports, IP blocklisting affecting other users) | Rate limiting, abuse-signal monitoring on Control API, per-provider abuse-response process (`/docs/operations/`, TBD) | Abuse reports from providers/third parties, anomalous traffic-volume signals at node level (aggregate, not content) | IP rotation, node replacement (nodes are disposable — ADR 0004), account action per Acceptable Use Policy |
| **External network attackers** (MITM, traffic interception attempts) | Medium | High if successful | WireGuard's Noise-framework encryption (ADR 0001) — attacker cannot decrypt or inject into an established tunnel | Handshake failure anomalies, unexpected peer behavior | Standard TLS/WireGuard failure handling; no custom crypto to fail differently than upstream |
| **Compromised user device** | Medium | Medium (affects that user only) | Keychain-backed private key storage, no plaintext credential storage, session token short lifetimes | N/A (device-local compromise is outside Aeria's direct visibility) | Remote device revocation from account (Device Management, `/docs/product/PRODUCT_REQUIREMENTS.md`) |
| **Compromised VPN node** | Medium (nodes are internet-facing, provider-hosted) | Medium — bounded by design | Nodes hold no user/billing/auth data (ADR 0004); node agent API reachable only from Control Plane's private network; compromised node yields only currently-active peer public keys and routing capability, not historical data | Node health-check anomalies, node agent audit logging, provider-level intrusion signals | Immediate node drain/destroy + re-provision via Terraform (stateless by design — ADR 0004/0005); rotate any control-plane credentials the node held |
| **Malicious administrator** (Aeria employee/insider) | Low-medium | High if unmitigated | Zero-trust admin access: MFA, least privilege, short-lived credentials, no shared admin passwords (brief §43); all admin actions written to AuditEvent | Audit log review, anomalous admin-access-pattern alerting | Access revocation, incident response process (`/docs/security/` incident-response.md, tracked as follow-up doc) |
| **Cloud provider compromise** (Vultr/Hetzner-level breach) | Low | Medium — bounded by data-plane statelessness | Same mitigation as "compromised VPN node" — nodes hold no durable sensitive data; control plane's own hosting choice should be evaluated separately with the same bounded-blast-radius principle | Provider security bulletins, anomalous node behavior | Full node fleet re-provisioning if warranted; control-plane database backups (`/docs/operations/`, TBD) for a control-plane-hosting-level incident |
| **Credential theft / account takeover** | Medium | Medium | Sign in with Apple removes password-theft surface entirely (ADR 0006); session tokens short-lived and revocable | Anomalous device-registration patterns, geographically implausible session activity | Session revocation, forced re-authentication |
| **API abuse** (scraping, automated signup abuse, rate-limit evasion) | Medium | Low-medium | Rate limiting (Redis-backed), request validation, API versioning, structured request IDs for traceability (`/docs/architecture/ARCHITECTURE.md` §3) | Rate-limit trigger monitoring | Temporary IP/account throttling, escalation to manual review for sustained abuse |
| **Subscription/trial fraud** | Medium (7-day trial is an attack surface) | Low-medium (bounded bandwidth cost per abuse case) | Payment method required for trial start (StoreKit-standard — `/docs/business/unit-economics.md`), device/account correlation to detect repeat trial abuse | Repeat-trial-signup pattern detection | Trial-eligibility gating tightened per observed abuse pattern |
| **Server compromise leading to traffic interception** | Low (bounded by WireGuard's per-session forward secrecy properties and node statelessness) | High if it occurred | Same as "compromised VPN node"; additionally, WireGuard's key rotation pattern (ADR 0004) limits the value of a stolen public key alone (private key never present on the node) | Node health/behavior anomalies | Node destroy/re-provision |
| **Supply-chain attack** (compromised dependency — WireGuardKit fork, npm/CocoaPods/SPM package, Terraform provider) | Low-medium | High if unmitigated | Pin dependency versions, use official upstream sources only (ADR 0001 specifies the official `WireGuard/wireguard-apple` repo, not a fork), CI dependency scanning (`/docs/product/PRODUCT_REQUIREMENTS.md` §CI/CD security scan stage) | Dependency scanning alerts, unexpected build/behavior changes | Dependency pin rollback, incident response |

## Zero-trust admin posture (brief §43)

The admin system (`/docs/product/PRODUCT_REQUIREMENTS.md` §Admin Panel) is treated as highly sensitive from day one:
- MFA required for all admin access.
- Least-privilege role separation (e.g., support staff cannot see billing internals they don't need; infra admins cannot see user PII they don't need).
- Short-lived credentials, no long-lived shared admin passwords.
- Every admin action recorded in the append-only AuditEvent log (`/docs/architecture/ARCHITECTURE.md` §5).
- Production access kept separate from staging/development access.

## Explicitly out of scope for MVP threat modeling (revisit later)

- Nation-state-level traffic-correlation attacks against WireGuard itself — outside what Aeria's own architecture can mitigate; not a claim Aeria will make marketing promises about (see security-claims policy, `/docs/business/positioning.md`).
- Multi-region control-plane threat surface — deferred until multi-region is actually built (`/docs/architecture/ARCHITECTURE.md` §8).

## Follow-up documents (tracked, not yet written)

- `/docs/security/incident-response.md` — detection/containment/eradication/recovery/communication/postmortem process for the scenarios above.
- `/docs/security/key-management.md` — detailed key lifecycle (WireGuard keys, TLS certs, signing credentials, secrets rotation procedure).
- `/docs/operations/disaster-recovery.md` — backup/restore testing, infrastructure recreation procedure.

These are named explicitly here so they aren't silently dropped — they are Phase 3-6 deliverables (`/docs/product/ROADMAP.md`), not needed to start Milestone 1 implementation but required before public launch.
