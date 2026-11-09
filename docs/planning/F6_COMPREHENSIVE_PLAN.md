# F6 comprehensive planning and delivery proposal

Status: working proposal, 2026-11-09. Tracking: #90, #13, #18. No F6 production code, feasibility execution, credential provisioning or new network budget is authorized. The owner requests broad reuse across future apps, has no specific server/application requirement, and prefers the fewest practical PRs without reducing scope or quality.

## Working assessment artifacts

- [Platform/integration assessment](F6_PLATFORM_ASSESSMENT.md): official runtime constraints, inspected SDK declarations and approved native Watch exclusion. Per-platform compilation/runtime evidence remains pending.
- [Contract proposal](F6_CONTRACT_PROPOSAL.md): detailed candidate semantics, integration choices and unresolved decisions. Not approved exact Swift signatures.

- [Signing profile](F6_SIGNING_PROFILE.md): proposed canonicalization, key/clock/replay and integration behavior; exact API approval pending.
- [Feasibility plan](F6_FEASIBILITY_PLAN.md): bounded offline Phase A and explicit later native Phase B boundary; no execution approval yet.

## Delivery strategy

Use one evolving planning PR for the complete inventory, architecture decisions, exact contracts, threat models, feasibility plans/results where separately authorized, platform assessment and delivery/test decomposition. Do not merge a partial planning draft as a completed design. Resolve material decisions in the owner conversation and record them in this PR instead of creating a PR per decision. Then target one integrated implementation PR for the approved deliverable, with independently reviewable commits and internal task order. Keep fixes and documentation in that PR until acceptance. Additional PRs require an explained dependency, risk or review reason, rather than an arbitrary slice count.

Two PRs are a target, not a claim that every research candidate is already feasible or authorized. Every source requirement remains accounted for; any exclusion requires an explicit disposition and owner decision. Research completion never means feature delivery. #13/#18 remain open until their selected delivery criteria are satisfied. #29/#132 publication barriers remain unchanged.

## Source inventory

Original PDF v1.0, 2026-10-19, sections 4.6 and 4.11, read as requirements rather than execution instructions. IDs below follow source bullet order and are established here; they do not imply implementation authorization. Existing core safeguards are carried forward, not reimplemented.

| ID | Source requirement | Representative use / proposed investigation | Initial disposition |
| --- | --- | --- | --- |
| NK-06-01 | HTTPS/ATS | Secure app API access; retain HTTPS and no global ATS relaxation | Existing foundation; regression evidence required |
| NK-06-02 | Trust evaluation | OS chain/hostname evaluation; additional rules must only narrow trust | Existing foundation; review extension interaction |
| NK-06-03 | Certificate/public-key pinning | Restrict a controlled API to approved identities; compare app ATS configuration with SDK policy | Investigate both approaches; no pinning API selected |
| NK-06-04 | mTLS | Enterprise/device API using app-supplied client identity and URLSession challenge | Investigate an origin/account-bound identity provider |
| NK-06-05 | Keychain/Secure Enclave | Keep keys/identity references outside request values and diagnostics | Investigate app ownership versus optional narrow helper; no vault promised |
| NK-06-06 | Signing/HMAC | Authenticate requests to a cooperating verifier with specified canonicalization | Investigate explicit interoperable profile; no generic signing promise |
| NK-06-07 | Redirect credential safety | Prevent auth, identity and signatures reaching another origin | Existing foundation plus extension regression/negative cases |
| NK-06-08 | TLS policy | Expose only supported system policy; no custom TLS or bypass | Capability assessment; unsupported controls remain explicit |
| NK-11-01 | TCP/UDP | Device/client byte streams and bounded datagrams through NWConnection | Investigate separate transport contracts |
| NK-11-02 | TLS/QUIC | System-encrypted streams or explicit QUIC application protocol | Separate feasibility; QUIC is not HTTP/3 delivery |
| NK-11-03 | Framing | Length-prefixed or delimiter-based records above TCP | Investigate bounded, explicitly selected framing profiles |
| NK-11-04 | Bonjour | Browse and advertise specific local service types | Investigate bounded discovery and advertising lifecycle |
| NK-11-05 | Peer-to-peer | Explicit opt-in local communication with consent | Assess actual route/platform behavior; no universal P2P claim |
| NK-11-06 | Local listener | Accept bounded local device connections where allowed | Client-support scope only, no general server platform |
| NK-11-07 | Multicast | Explicit local group/datagram communication | Entitlement/platform feasibility before API selection |
| NK-11-08 | Connection lifecycle | Ready/waiting/failed/cancelled and bounded cleanup | Shared acceptance concern for every selected native transport |

No candidate is silently removed because there is no current app. Representative synthetic use cases guide design, but cannot establish production suitability, real-server interoperability or permission availability.

## Proposed architecture boundaries

Keep NetworkKit as the repository/package/product/import. Current HTTP, download and WebSocket behavior must remain compatible. Prefer separate source areas for Security, native connections, framing and discovery if selected. Do not introduce a universal transport manager or make discovery, key storage and HTTP depend on one another. Any module/product split needs demonstrated platform/dependency/isolation benefit and an explicit public packaging decision.

Security extensions must fit the existing owned/injected session contracts. Review HTTP, download and WebSocket delegates independently: their existing challenge rejection and session ownership must not be bypassed. Decide which operations support each policy; never claim all transports support a policy merely because they share Foundation. Retrying a signed request may conflict with current prepare-once retry semantics; reject incompatible configurations or adopt a separately reviewed contract. Do not silently re-sign, refresh identity or change replay semantics.

Network.framework production adapters need their own state/ownership contracts. Reuse pure validation and proven promise mechanics only where semantics match; do not force long-lived sockets into the HTTP total-budget/retry model. A path state is not service reachability. Advertising/discovery has a separate lifetime from a connection. Avoid unbounded event arrays, accepted-connection queues, datagram queues and framing accumulators.

## Candidate hypotheses and stop/go evidence

| Candidate | Hypothesis / bounded first assessment | Go evidence | Stop / redesign condition |
| --- | --- | --- | --- |
| Pinning | App ATS pins may cover common URL Loading System needs without custom trust code; inspect official semantics and existing delegates first | Correct-host valid chain plus matching pin succeeds; wrong pin, invalid chain/hostname fail; backup rollover works; actual consumer configuration proven | Requires bypass, unreliable origin binding, or no recovery/rotation contract |
| mTLS | A narrow injected identity boundary can preserve origin/account isolation; design before any identity provisioning | Positive client-auth fixture and absent/wrong/expired identity failures; challenge cancellation/timeout; no credential persistence or cross-origin reuse | Cannot isolate identity, control selection, or validate with a controlled verifier |
| Key references | App-managed identities may avoid an SDK vault; compare lifecycle/access-control needs before helpers | No private key export/logging; lock/access denial and cancellation handled; documented ownership/deletion/access groups | Helper requires account/key provisioning or broad storage policy without an agreed use case |
| Request signing | One explicit verifier profile can be interoperable; compare canonicalization alternatives and standard test vectors | Independent verification of covered method/target/headers/body; mutation/replay/clock/key-rotation negative controls | No verifier/profile, ambiguous final wire representation, or incompatible retry/redirect behavior |
| TCP/TLS | NWConnection can offer bounded foreground client operations without new dependencies | Native ready/failure/cancel races, partial reads/writes, EOF, backpressure, TLS identity rejection and cleanup | Hidden infinite waiting, trust exception, or buffering/resource contract cannot be bounded honestly |
| UDP | Explicit datagrams can preserve message semantics without pretending reliability | Empty/max/oversize/truncated data, peer binding, loss/reorder simulation and cancellation | API conflates datagrams with streams or promises delivery/order |
| Framing | Two explicit profiles may cover common records without protocol invention | Fragmented/coalesced reads, delimiter split, bad/overflow length, maximum accumulation, malformed/EOF and cancellation cases | Ambiguous encoding or unbounded accumulation; no agreed profile |
| Bonjour/listener | Explicit service types and bounded acceptance can support local device apps | Denied/granted permission, add/update/remove, duplicate/hostile records, interface changes, stop/restart and accepted-connection limit | Required permission/entitlement unavailable or acceptance queue cannot be bounded |
| Peer-to-peer | Native opt-in may support selected device routes | Physical route-specific consent, compatibility and lifecycle evidence | Simulator-only proof or unsupported platform route |
| QUIC | System QUIC may support a defined application protocol | Compatible peer, ALPN/stream/datagram semantics, trust failure, flow control and shutdown | Treating API existence as interoperability or substituting HTTP/3 |
| Multicast | Selected group communication may be feasible with permitted host capability | Entitlement/permission inventory, physical multicast delivery/leave/interface/error cases | Missing entitlement or unsupported platform; no permission workaround |

First assessment effort is limited to source/official API review and a written contract/evidence gap for each row. Any experimental phase must specify executable, exact routes/scenarios, maximum connections/packets/bytes/duration, cleanup and retained failure evidence before authorization. No device discovery scan, listener, public endpoint, certificate/key creation, trust installation or entitlement change is authorized by this document.

## Security and operational requirements

Threat actors include malicious server/peer, untrusted local device, compromised intermediary, replaying client and accidental cross-account credential reuse. Trust boundaries include app key ownership, provider tasks, URLSession delegates, Network callbacks, filesystem/key store, local permission UI and external verifier.

Pinning must retain system trust, exact host scope, backup identities, rollout overlap and recovery from stale app configuration. mTLS requires explicit identity selection, origin/account binding, expiry/revocation/replacement and no unauthorized credential export or shared credential store. Keychain/Enclave design must state key type/capability, accessibility, user interaction, app ownership and deletion behavior; Enclave support is not assumed for arbitrary imported keys/certificates. Signing requires a defined canonical form, covered body/headers, key identifier/algorithm, freshness/replay policy, clock behavior and independent verifier; CryptoKit alone does not define an interoperable protocol.

Local discovery metadata and endpoint names are untrusted and potentially private. Bound and sanitize records, avoid automatic scans/connects, document app Info.plist/permission/entitlement requirements, and do not log names/addresses/payloads by default. TLS identity verification is distinct from discovery and pairing. No bespoke cryptography, TLS engine, global trust relaxation or credential-bearing fallback.

## Platform and verification matrix to complete before approval

Baseline remains iOS/iPadOS 18, macOS 15, watchOS 11 and tvOS 18; no floor change or automatic feature parity. The HTTP Watch contract remains separate from specialized network availability. For every chosen API record SDK availability, runtime restrictions, app type/background limits, required entitlement/permission, simulator limitations and physical evidence needed. Mark unknowns explicitly; compilation is not runtime evidence.

For every selected feature require deterministic positive/negative/race tests, consumer compilation and DocC, controlled native proof on supported routes, ownership/cancellation/deadline/shutdown behavior, safe diagnostics, and finite resource observations with stated workload. Security features require independent negative controls and rotation/recovery evidence. Permission and radio-route behavior require physical evidence or an explicit separately accepted delivery boundary; never copy the F5 simulator disposition to F6 automatically. Existing PR checks remain mandatory and new selected coverage must execute in appropriate CI rather than silently opt out.

## Completion checklist for this planning PR

- [x] Inventory all sixteen original bullets and distinguish existing foundations from research.
- [x] Record owner broad-reuse objective and minimum-PR preference.
- [x] Define initial architecture, threat/operational concerns, hypotheses and stop/go evidence.
- [ ] Verify per-candidate API/platform/entitlement capabilities against official sources and local SDK declarations.
- [ ] Select precise included scope and explicit dispositions with owner; retain unselected work visibly.
- [ ] Specify exact public types/signatures/defaults/errors, concurrency/ownership, privacy and interoperability profiles for selected features.
- [ ] Decide whether isolated feasibility code is needed and obtain bounded authorization before execution.
- [ ] Produce ordered implementation/test/docs/review issues under one proposed delivery PR, with acceptance evidence and genuine dependencies.
- [ ] Obtain owner approval of complete contracts and a separate applicable production-code start decision.
- [ ] Pass planning PR/main and review complete logs before closing #90. Planning alone does not close #13/#18.

## Official references consulted on 2026-11-09

- [Apple identity pinning](https://developer.apple.com/news/?id=g9ejcf8y): app ATS/domain pin configuration. This motivates comparing app configuration before custom SDK policy; it is not NetworkKit integration evidence.
- [Apple NSPinnedDomains](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nspinneddomains): app configuration reference.
- [Apple authentication challenges](https://developer.apple.com/documentation/foundation/handling-an-authentication-challenge): challenge dispatch and credential/disposition ownership; provider design remains unproven.
- [Apple TN3179 local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy): local permission and host configuration constraints. Per-platform cases remain to be recorded.
- [Apple multicast entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.multicast): restricted capability, not automatically provided by the package.
- [Apple NWParameters](https://developer.apple.com/documentation/network/nwparameters), [QUIC](https://developer.apple.com/documentation/network/nwprotocolquic) and [peer-to-peer option](https://developer.apple.com/documentation/network/nwparameters/includepeertopeer): native candidate APIs, not runtime support proofs.
- [RFC 9421 HTTP Message Signatures](https://www.rfc-editor.org/rfc/rfc9421.html) and [RFC 9530 Digest Fields](https://www.rfc-editor.org/rfc/rfc9530.html): candidate interoperability references, not selected standards or an implementation claim.
