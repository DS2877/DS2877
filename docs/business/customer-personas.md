# Aeria — Customer Personas

Aeria's target is not "all internet users." Five personas, informed by the competitive gaps in `/docs/business/competitive-analysis.md`.

## 1. The Apple-Heavy Professional — "Erik, 34, product manager"

Owns an iPhone, iPad, MacBook, and Apple TV; lives inside the Apple ecosystem by habit and preference. Uses a VPN on business travel and public Wi-Fi. Currently on NordVPN through work recommendation but finds the Windows-first UI and constant upsell prompts jarring against his otherwise Apple-clean setup.

- **Willingness to pay**: high (€8-12/month equivalent is a rounding error against his other subscriptions).
- **Pain points**: apps that don't feel native, feature bloat, aggressive marketing emails.
- **Why he'd switch**: an app that feels like it was built by Apple's own design team; one-tap trust.
- **What makes him cancel**: any sign the "protected" indicator lied, or a renewal price surprise.

## 2. The Privacy-Conscious Consumer — "Sara, 41, teacher"

Read about data broker practices, wants to reduce her digital footprint without becoming a Linux/Tor power user. Considered Mullvad but found the anonymous-account-number flow and menu-bar-only Mac app intimidating/unpolished.

- **Willingness to pay**: moderate-high (€7-10/month), values transparency over price.
- **Pain points**: not wanting to "learn" a technical product; distrust of VPNs that make big anonymity claims.
- **Why she'd switch**: honest, plain-language privacy communication (no "100% anonymous" claims — see `/docs/business/positioning.md`) and a genuinely simple interface.
- **What makes her cancel**: any hint of data misuse, confusing settings.

## 3. The Frequent Traveler — "Marcus, 29, consultant"

On planes and hotel Wi-Fi weekly. Wants auto-connect on untrusted networks and doesn't want to think about it. Currently uses ExpressVPN, generally happy but resents the price relative to what he perceives as a commodity feature.

- **Willingness to pay**: high, but price-sensitive relative to *perceived* value — needs to feel like he's paying for something premium, not "just a VPN."
- **Pain points**: manual connect/disconnect friction, forgetting to enable it, slow servers on unfamiliar networks.
- **Why he'd switch**: trusted-network auto-connect done well (`/docs/product/PRODUCT_REQUIREMENTS.md` §Auto-Connect) and consistently fast "fastest server" selection.
- **What makes him cancel**: any experience of the VPN slowing him down noticeably.

## 4. The Multi-Device Apple Family — "The Lindqvist household"

Two adults, two teenagers, a mix of Macs, iPhones, and at least one Windows laptop between them. Currently unprotected or using a family plan from a mainstream provider they find clunky to manage across devices.

- **Willingness to pay**: moderate per-device, but a family bundle (future, not MVP — see `/docs/product/ROADMAP.md`) at a fair multiple of the single price is attractive.
- **Pain points**: managing multiple accounts/devices across a mixed-platform household, explaining VPN concepts to less technical family members.
- **Why they'd switch**: a device list that "just works" (`/docs/product/PRODUCT_REQUIREMENTS.md` §Device Management) and not being forced to choose an Apple-only product when one family member has a Windows laptop — Aeria's fast-follow Windows support (`/docs/architecture/adr/0007-platform-sequencing.md`) matters directly to this household.
- **What makes them cancel**: complexity, a family member's device breaking silently, or discovering a household device isn't supported at all.

## 5. The Premium-Tech Enthusiast — "Yuki, 26, designer"

Buys the best version of everything — hardware, software, subscriptions. Not primarily privacy-motivated; VPN is one more piece of a considered, well-designed digital life. Would never install NordVPN because it "doesn't look like something I'd use."

- **Willingness to pay**: highest of all personas, price is not the deciding factor — design and brand coherence are.
- **Pain points**: cheap-feeling UI, generic branding, VPN-hacker aesthetic (see brand principles, `/docs/business/positioning.md`).
- **Why she'd switch**: the product simply looking and feeling like something worth using.
- **What makes her cancel**: any UI regression, any feeling that the brand has become "just another VPN."

## Cross-persona patterns

- **Existing VPN behavior**: all five are either already paying a competitor or actively considering one — Aeria is not creating category demand, it's winning switches.
- **Trust signal that matters most**: consistently, "does it feel honest and doesn't oversell," not "does it have the most features."
- **Universal cancel trigger**: any experience that breaks trust — a fake "Protected" state, a renewal price surprise, or a UI that stops feeling premium. This directly informs the "never fake functionality" and "no deceptive pricing" product/business principles.
