# Aeria — Unit Economics

All figures are **modeled estimates for planning purposes**, not audited financials. Assumptions stated explicitly; revisit once real infrastructure and conversion data exist.

## Pricing (recommendation)

The brief's hypothesis prices (€9.99/mo, €79.99/yr) are directionally reasonable against researched competitor pricing (`/docs/research/competitor-landscape.md`): Proton VPN Plus (€9.99 monthly equivalent, ~€2.99-3.99/mo on 2-year plans) and Mullvad (flat €5/mo, no discounting) bracket the credible premium range. Given Aeria's explicit "honest pricing, no renewal shock" positioning:

- **Monthly**: €9.99/month
- **Annual**: €79.99/year (≈ €6.67/month equivalent) — a real discount for commitment, not a teaser-then-shock structure
- **Renewal price = list price**, always — no multi-year-only teaser rates that jump on renewal. This is a deliberate divergence from Nord/Surfshark/CyberGhost's model and is itself part of the brand promise (`/docs/business/positioning.md`).
- **Family (post-MVP)**: ~€119.99/year hypothesis is reasonable relative to Proton's Family plan (~€24-30/mo for up to 6 users) but should be re-priced once Aeria's per-device cost is known from real usage, not modeled pre-launch.

Apple takes a commission on App Store subscriptions (up to 30% year one for a given subscriber, dropping to 15% after the subscriber's first year, per Apple's Small Business Program / standard subscription terms as publicly documented — **not re-verified against Apple's live commission page in this research pass; confirm current rate before finalizing pricing**). VAT/regional pricing is handled by Apple's App Store pricing tiers automatically for App-Store-billed subscriptions, which simplifies EU VAT compliance considerably versus direct billing.

## Free trial

**Recommendation: 7-day free trial**, matching the brief's hypothesis, with a required payment method on file (StoreKit-standard) to reduce trial-abuse relative to no-payment-required trials. Rationale:
- 3 days is too short to demonstrate value across a user's actual travel/Wi-Fi-switching patterns (a key use case per personas).
- 14 days materially increases bandwidth cost exposure and delays revenue recognition without clear evidence it lifts conversion enough to offset that, based on general subscription-industry patterns (not Aeria-specific data, which doesn't exist yet — **revisit with real A/B data post-launch**).
- No permanent free tier, per the brief: abuse/bandwidth-cost/support-burden/brand-dilution risk outweighs the acquisition benefit for a premium-positioned product.

## Cost assumptions (per user, modeled)

| Cost line | Assumption | Basis |
|---|---|---|
| VPN bandwidth | ~15 GB/month average active user, blended provider cost ~$8-10/TB (Vultr-weighted, per ADR 0005) | Assumption — no Aeria usage data exists yet |
| Server/compute amortized | ~$0.15-0.30/user/month at moderate node utilization | Modeled from Vultr instance + bandwidth pricing in `/docs/research/infra-protocol-legal-basics.md` |
| Control-plane infra (DB, Redis, app servers) | ~$0.05-0.15/user/month, falling with scale | Modeled, amortized fixed cost / user count |
| Payment processing (App Store) | Apple commission 15-30% of gross, tiered by subscriber tenure | Apple subscription terms (confirm current rate) |
| Support | ~$0.10-0.40/user/month depending on scale (higher per-user early, falls with self-serve tooling) | Modeled |
| Monitoring/observability | ~$0.02-0.05/user/month | Modeled |

## Modeled economics by user count (Annual plan, €79.99/yr, blended with some monthly mix)

Assumptions: 70% of paying users on annual plan, 30% monthly; blended ARPU ≈ €7.20/month (~$7.80); Apple commission blended at ~22% (mix of Small Business Program-eligible and standard-rate accounts); infra costs per above table.

| Users | MRR (est.) | ARR (est.) | Infra cost/mo (est.) | Apple fees/mo (est.) | Gross profit/mo (est.) | Gross margin |
|---|---|---|---|---|---|---|
| 100 | ~€720 | ~€8,640 | ~€40 | ~€158 | ~€522 | ~72% |
| 1,000 | ~€7,200 | ~€86,400 | ~€350 | ~€1,584 | ~€5,266 | ~73% |
| 10,000 | ~€72,000 | ~€864,000 | ~€3,200 | ~€15,840 | ~€52,960 | ~74% |
| 50,000 | ~€360,000 | ~€4.32M | ~€15,000 | ~€79,200 | ~€265,800 | ~74% |
| 100,000 | ~€720,000 | ~€8.64M | ~€28,000 | ~€158,400 | ~€533,600 | ~74% |
| 500,000 | ~€3.6M | ~€43.2M | ~€130,000 | ~€792,000 | ~€2.68M | ~74% |
| 1,000,000 | ~€7.2M | ~€86.4M | ~€250,000 | ~€1.58M | ~€5.37M | ~75% |

**These are directional planning numbers, not forecasts** — real ARPU, churn, CAC, and infra cost per user must be measured, not assumed, once Aeria has actual users. Gross margin excludes salaries, marketing spend, and non-infra overhead — this is *contribution margin* on the subscription/infra line, not net profitability.

## Break-even

At ~100-300 paying users, infra + Apple fees are comfortably covered by gross revenue (per the table above, gross margin is already ~72%+ at the smallest modeled tier) — the constraint at low user counts is **not unit economics, it's absolute revenue against fixed costs** (founder/team time, any fixed hosting minimums, tooling). True operating break-even (covering a small team's costs) plausibly falls somewhere in the low thousands of paying subscribers depending on team size — this must be modeled against an actual staffing plan, which is outside this document's scope.

## Key unmodeled variables (flag explicitly)

- **Churn** — no data exists; assume conservatively higher (8-12%/month) pre-product-market-fit, targeting <5%/month at maturity based on general subscription SaaS/consumer benchmarks (not VPN-specific data).
- **CAC** — entirely dependent on go-to-market execution (`/docs/business/BUSINESS_PLAN.md` §Go-to-Market); not modeled here.
- **Trial-to-paid conversion** — industry consumer-subscription benchmarks vary too widely (20-60%) to use a single assumed figure credibly; must be measured directly.

## Scenario modeling (Conservative / Base / Aggressive)

Full 12/24/36-month scenario modeling requires CAC and churn assumptions that don't yet exist in any credible form — producing specific numbers here would create false precision. This is deferred to `/docs/business/BUSINESS_PLAN.md` as a named open item, to be built once Phase 1-2 (see `/docs/product/ROADMAP.md`) produces real trial/conversion/churn data from a private alpha.
