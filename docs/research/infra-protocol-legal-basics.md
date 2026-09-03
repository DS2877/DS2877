# Research Notes: Cloud Provider Suitability, WireGuard Control-Plane Patterns, GDPR Basics

**Date researched:** 2026-09-03
**Method:** Primary sources (provider ToS/AUP pages, WireGuard.com papers, eur-lex, gdpr-info.eu mirror of the regulation, IMY) with secondary/aggregator sources flagged inline. GDPR section is grounding only, not legal advice — flagged explicitly where counsel review is needed.

---

## 1. Cloud/Bare-Metal Provider VPN-Hosting Suitability

**ToS/AUP treatment of VPN hosting:**
- **OVH — explicitly PROHIBITS VPN hosting.** Service-Specific Terms: *"Anonymization services or public proxy (including VPN, Tor, P2P, IRC) and cardsharing... are prohibited."* (us.ovhcloud.com/legal/service-specific-terms/). **Disqualified.**
- **Hetzner** — no explicit VPN/proxy prohibition in published Terms & System Policies; Hetzner even publishes a one-click WireGuard app for Cloud servers, implying tolerance (docs.hetzner.com/cloud/apps/list/wireguard/). Not confirmed for large-scale commercial VPN operation specifically.
- **DigitalOcean** — AUP prohibits open proxies/mail relays/recursive DNS/Tor exit nodes but does not name VPN services (digitalocean.com/legal/acceptable-use-policy).
- **Vultr** — Use Policy prohibits open/anonymous proxy-type services but does not name commercial VPN subscriptions (vultr.com/legal/use-policy/ — full text 403'd on fetch, based on search-indexed excerpts, lower confidence).
- **AWS** — AUP prohibits illegal activity/fraud/network-security violations, no VPN-specific clause (aws.amazon.com/aup).

**Bandwidth pricing (mid-tier VM, indicative):**
- Hetzner: ~20 TB included (EU/US), overage ≈ €1.00–1.19/TB (~€7.40/TB Singapore) — third-party aggregated, not confirmed on Hetzner's own pricing page directly.
- DigitalOcean: ~500 GiB+ pooled free transfer/account, overage $0.01/GiB ≈ $10.24/TB (aggregator-sourced).
- Vultr: 2 TB free monthly egress pooled account-wide + per-instance allotment, free ingress, flat overage $0.01/GB ≈ $10.24/TB — confirmed via Vultr's own docs/blog.
- AWS EC2: ~$0.09/GB ≈ $90/TB overage (aggregator-sourced) — far costlier for bandwidth-heavy VPN workload.

**Community-reported VPN/proxy tolerance (anecdotal, not official):**
- Hetzner: LowEndTalk/HN threads describe inconsistent abuse handling for VPS-at-scale operators. Unverified sentiment, not official policy.
- Vultr/DigitalOcean: no VPN-specific ban pattern surfaced; reported issues found were billing/content disputes, not VPN-specific.

**DDoS protection by default:**
- Hetzner: free L3/L4 protection on all cloud products (largely community-confirmed).
- DigitalOcean: free always-on L3/L4 for all Droplets, no config needed, L7 not covered (official).
- Vultr: built-in edge DDoS mitigation on Cloud Compute, effectiveness tied to using Vultr's own recursive DNS resolver (official docs).
- AWS: Shield Standard automatic/free on all resources; Shield Advanced is paid.

**Terraform provider maturity:** All five have official, actively maintained providers — Hetzner (`hetznercloud/hcloud`), Vultr (`vultr/vultr`, HashiCorp-built), DigitalOcean (`digitalocean/digitalocean`), AWS (`hashicorp/aws`, most mature in the ecosystem overall).

**Recommendation:** Primary = **Vultr** (no explicit VPN prohibition, official Terraform provider, generous globally-pooled bandwidth at low flat overage, built-in DDoS, 30+ locations for standing up 5-8 country endpoints under one account). Fallback = **Hetzner** for cost-efficient EU/US anchor nodes (cheapest bandwidth found) — budget time to monitor its anecdotally inconsistent abuse handling, confirm current DDoS/ToS specifics directly before committing spend. **OVH excluded** (ToS explicitly bans VPN hosting). AWS not recommended as primary due to materially higher bandwidth cost for a bandwidth-heavy product.

## 2. WireGuard Protocol Basics

**Cryptographic primitives & review:** Curve25519 (ECDH), ChaCha20-Poly1305 (AEAD, RFC 7539), BLAKE2s (hash/HMAC), SipHash24 (hashtable keys), HKDF (key derivation) — a Noise Protocol Framework construction named `Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s` (wireguard.com/protocol/). Independent academic review: Tamarin-prover formal verification (Donenfeld & Milner), a computational cryptographic proof (Dowling & Paterson, 2018), a mechanised computational analysis (Lipp/Blanchet/Bhargavan, EuroS&P 2019), and a unified symbolic analysis at NDSS 2024. Papers linked at wireguard.com/papers/.

**Commercial control-plane pattern (client generates keypair, server only ever sees the public key):**
- **Mullvad**: rotates the device's WireGuard keypair automatically (default every 7 days, configurable), tied to a per-device static internal IP. Client generates keypair locally, registers public key via Mullvad's API; propagates to relays within seconds. (mullvad.net blog posts.)
- **Cloudflare WARP**: client generates keypair locally, registers public key with WARP registration API, receives peer/endpoint config back. Cloudflare never issues private keys to clients.
- **This pattern (client-generates-keypair, server-registers-pubkey-only) should be Aeria's default control-plane design** — private keys never transit the network or touch Aeria's servers.

**wg-quick vs wireguard-go vs kernel module:** For a Linux server handling many concurrent users, the **in-kernel WireGuard module** is the relevant throughput choice — avoids user/kernel context-switch overhead that costs an estimated 20-40% throughput vs `wireguard-go` at high (10G+) speeds (third-party benchmark, not an official WireGuard figure — indicative only). `wg-quick` is just a config/interface-bringup script, not itself performance-relevant. Peer scaling: CPU cost scales with active throughput/PPS, not idle peer count; memory cost per peer roughly 20-30 KB (aggregator-sourced), implying tens of thousands of idle peers are theoretically supportable on typical server RAM — **no official max-peers figure or production benchmark located; load-test independently before launch.**

## 3. GDPR Basics for EU-Facing VPN Operations

*(Grounding only — not legal advice. Counsel review flagged explicitly.)*

**IP addresses as personal data:** Confirmed by CJEU case law, *Breyer v Bundesrepublik Deutschland* (C-582/14, 19 Oct 2016) — a dynamic IP address is personal data for a controller with legal means reasonably likely to obtain identifying info from a third party (e.g. an ISP). GDPR Art. 4(1) (eur-lex.europa.eu/eli/reg/2016/679/oj/eng) lists "online identifiers" in its definition of personal data. **For a VPN provider — which by design sees users' real originating IPs and connection metadata — IP addresses should be treated as personal data as policy**, regardless of dynamic/static status.

**Lawful basis & data minimization:** Art. 5(1) requires data be "adequate, relevant and limited to what is necessary"; Art. 6 requires every processing activity rest on one of six lawful bases (consent, contract necessity, legal obligation, vital interests, public task, legitimate interests). For Aeria's logging policy: collect only what's operationally necessary (e.g. aggregate bandwidth for billing, not per-session browsing metadata); define lawful basis per data category up front (billing = contract necessity; abuse-prevention data, if any = legitimate interest requiring a balancing test); set retention limits tied to purpose.

**Data subject rights to support:** Access (Art. 15), rectification (Art. 16), erasure (Art. 17), data portability in structured machine-readable format (Art. 20) — GDPR Chapter III. Account/billing systems need export and deletion workflows from day one.

**International transfers:** Operating VPN nodes outside the EU (e.g. US) creates a GDPR Chapter V "international transfer" consideration if EU personal data is processed there, even momentarily. Default safeguards: an adequacy decision (Art. 45) where the EU Commission has determined a country's protections are adequate, or absent that, Standard Contractual Clauses (Art. 46, 2021 modular SCCs). Practically: minimizing what data is generated/retained at non-EU nodes reduces this exposure significantly — a strong technical argument for strict no-persistent-logs architecture regardless of node location.

**Sweden-specific (IMY):** No IMY document specifically addressing VPN-provider logging found. IMY's general guidance confirms indirect identifiers (like IPs) count as personal data when identification is reasonably possible (referencing Breyer), and discusses IP truncation as mitigation. Separately, Mullvad's own legal-analysis pages claim VPN services are **not** classified as an "electronic communications service" under Sweden's Electronic Communications Act (LEK) and are therefore not subject to Sweden's telecom data-retention obligations — **this is sourced from Mullvad's own page, not a primary government document (PTS/Government Offices), and must be independently verified before relying on it.**

---

## Explicit Gaps / Follow-Up Needed
- Vultr's full Use Policy text (403 on direct fetch; search-excerpt only).
- Exact current Hetzner and AWS bandwidth-overage figures on providers' own pricing pages.
- No official max-WireGuard-peers-per-interface benchmark located — load-test independently.
- No direct IMY publication on VPN-specific logging found.
- Sweden/LEK/PTS "VPN is not an electronic communications service" claim traces to Mullvad's own page — verify against PTS/Government Offices primary sources.
- **GDPR section requires qualified legal counsel review before being relied on for compliance decisions** — this document is grounding/orientation only.
