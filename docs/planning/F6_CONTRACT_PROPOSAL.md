# F6 contract proposal and unresolved decisions

Working design, 2026-11-09. Not an approved exact Swift API. Tracking #90, #13, #18 and PR #177. Broad coverage below is proposed for assessment, not an implementation commitment. Resolve this document into exact signatures and evidence before code-start approval.

## Owner design decisions — 2026-11-09

The owner approved the following planning directions, not exact API or code start:

- App-owned keys/client certificates, supplied through explicit references/providers. Initial SDK-managed pinning/mTLS is restricted to SDK-owned sessions; incompatible injected-session configurations fail before networking. No complete credential vault is selected.
- Develop one RFC 9421 HMAC-SHA256 signing profile with RFC 9530 SHA-256 Content-Digest and a separate verifier; no automatic retry or redirect. Other signing profiles remain visible future extensions, not delivered features.
- Direct native networking design targets iOS/iPadOS, macOS and tvOS; ordinary Watch native networking is excluded as recorded in the platform assessment.

These decisions supersede the alternatives below only for further detailed design. They do not establish implementation feasibility or production suitability.

## Common public behavior

Keep the existing NetworkKit product/import and current APIs. Prefer capability-specific values/actors over a generic transport class with dozens of options. Validate local configuration and already-cancelled caller before side effects. Resource limits must be positive, explicit and checked against arithmetic overflow. No automatic reconnect, silent retry, identity refresh or fallback to weaker security. An accepted call has one terminal outcome; late callbacks cannot revive it. Cancellation of stateful I/O ends that connection when delivery state becomes uncertain. Invalid local input or duplicate operation fails without damaging an otherwise healthy connection. Native shutdown completion is distinct from confirmed peer acknowledgement and full OS resource drain.

Each native connection permits one send and one receive concurrently; concurrent same-direction calls are rejected, not queued without bound. Use operation deadlines and an explicit connect deadline, not an automatic entire-connection lifetime. Propose 10-second connect/send and 2-second close defaults, caller-configurable positive finite durations up to 24 hours, with caller-bounded receive waiting. These are proposals, not inherited approved F5 behavior. App-owned actors can add scheduling; NetworkKit does not build an implicit event bus.

Structured errors should distinguish invalid configuration/input, duplicate operation, unsupported capability, connection/transport, timeout phase, size/framing, security-policy failure and closed lifecycle. Keep CancellationError separate. Do not collapse a platform-native failure into permission denial, certificate diagnosis or delivery certainty without evidence. Safe descriptions omit addresses, discovery names/TXT contents, keys, credentials, pin values and payloads. Separate new error families where the semantics differ from HTTP/WebSocket; exact names/payloads remain pending.

## Security contracts to resolve

### Pinning and TLS

Propose optional exact-origin pin sets that add restrictions to system hostname/chain validation. Compare certificate-DER digest versus SPKI digest explicitly; they are not interchangeable, and raw SecKey external bytes are not automatically SPKI. Never create an ad-hoc ASN.1 parser just to extract pins. Prefer documented app ATS configuration if a dynamic policy cannot be implemented correctly with supported APIs. Require at least two distinct current/backup pin identities, deterministic match semantics, atomic replacement through a new configuration/connection, fail-closed stale-pin behavior and a documented recovery rollout. Whether CA/leaf pin forms are both exposed remains undecided.

No policy can accept an invalid system trust result, self-signed peer, hostname mismatch or downgrade. TLS minimum settings must use supported Foundation/Network options and cannot imply a global cipher/ALPN guarantee. Proposal does not promise pinning on injected sessions or every transport. Define per-operation support and reject incompatible configurations before networking. The app owns deployment and monitoring of pin rotation.

### Client identity

Propose a dedicated asynchronous client-identity provider with exact HTTPS origin, immutable account/environment binding and connection/operation identity. It returns an app-owned identity reference plus an explicit certificate-chain representation if required; it must not receive arbitrary untrusted URLs or credentials from another account. Validate challenge origin/auth method and retry count. Nil identity, provider error, repeated challenge or cancellation fails without prompting, shared credential persistence or fallback identity. Provider output is used only for the matching admitted challenge and is discarded after logical termination. Provider work is cooperatively cancellable; a late completion must never respond to an already completed handler. Decide exactly-once callback ownership and timeout behavior before public signatures.

No PKCS#12 import, certificate enrollment/creation or identity deletion happens implicitly. Existing header auth remains separate. Session reuse and TLS client identity must not cross account boundaries: selected identity configuration is immutable per owned session; changing binding requires a new client/session. Request-level identity switching is not promised. WebSocket and native TLS need separate adapter proof rather than automatic inclusion.

### Key storage and signing

Recommend app-owned keys/identities by default and optional narrow reference-based adapters only after capability review. No general credential vault or Secure Enclave compatibility promise. The app decides access groups, accessibility, biometric/user-presence policy, key replacement/deletion and recovery. Hardware-backed capability failures must be explicit, without silently replacing a key with a software key.

For request signing, propose evaluating a constrained RFC 9421 profile with HMAC-SHA256 and Content-Digest SHA-256 from RFC 9530; asymmetric/Enclave-backed signing is a separate profile decision. The owner selected this profile as the further-design basis on 2026-11-09; exact canonicalization and interoperability remain unapproved and unimplemented. Exact canonical components, query/percent encoding, duplicate header handling, timestamp lifetime/clock skew, nonce replay, key ID/algorithm and verifier behavior must be specified. No public claim of generic interoperability without an independent verifier and vectors.

A separate opt-in context may expose the finalized method/target and chosen headers/body digest to the signer; keep existing minimal AuthenticationContext unchanged. The signing step follows serialization/auth resolution and precedes network admission. Bound work/bytes and deadline; never pass raw secret material into diagnostics. Disable automatic retry and redirect-following for the first signed profile unless exact replay/re-signing semantics are separately approved. Rejection must occur locally rather than silently overriding the caller's requested retry policy.

## Native operation contracts to resolve

| Capability | Proposed operations and ownership | Required limits / edge semantics |
| --- | --- | --- |
| TCP/TLS client | Explicit connect; send bytes; receive up to a requested count; close. One actor owns one native connection | Bound per-send and requested receive bytes; partial reads are normal; distinguish EOF from empty data; send completion is not peer receipt; TLS validates identity |
| UDP client | Connected-peer datagram send/receive; explicit close, distinct from byte streams | Mandatory max datagram; zero-length datagram is data, not EOF; oversize/truncated input fails explicitly; no order/delivery guarantee; spoofing and path/MTU limits documented |
| Framed TCP | Explicit fixed 4-byte unsigned big-endian length prefix or byte delimiter profile above owned TCP/TLS | Mandatory max payload and accumulation; delimiter inclusion/escaping/empty-record rules explicit; reject overlong/incomplete frames and overflow; fragments/coalesced reads handled; no unbounded leftovers |
| Bonjour browser | Explicit start for one declared service type/domain; pull bounded snapshots; stop | Mandatory max records/TXT bytes; stable opaque result identity and add/update/remove semantics; endpoint lifetime documented; no auto-connect or arbitrary service enumeration |
| Advertisement/listener | Explicit start with local endpoint/service config; pull one accepted connection; stop | Mandatory active-connection/pending-accept limits; surplus arrivals rejected/cancelled; app owns handed-off connections; stop cleans only unhanded work; readiness/assigned port available only after ready |
| Peer-to-peer | Explicit native option within supported discovery/connection configuration | Never auto-activates; no route/authentication guarantee; physical compatibility proof; unsupported route fails honestly |
| QUIC | Dedicated application-protocol configuration, not an HTTP client switch | Mandatory ALPN and chosen stream/datagram model, resource counts and trust policy; independent peer verification; no automatic 0-RTT/replay-sensitive behavior |
| Multicast | Explicit group join, bounded datagram send/receive, leave/close | Mandatory group/port/interface policy and max datagram/queue; no discovery scan, automatic all-interface join or arbitrary unicast fallback; permission/entitlement failures preserved |

Browser snapshots may coalesce updates and therefore are not an event delivery guarantee. New accepted connections must never be silently retained without a bounded handoff policy. Default listener binding must not be all interfaces: decide explicit loopback versus user-selected local interface/service binding. TLS listener identity is app-supplied; unauthenticated plaintext listeners need an explicit opt-in and do not inherit HTTPS trust guarantees. UDP confidentiality requires an actual selected security protocol; do not label plain UDP as TLS-protected.

Do not combine QUIC with the TCP framing actor: QUIC stream/datagram boundaries and flow control need a separate exact contract. Do not treat a peer-to-peer Wi-Fi option as peer authentication. Do not introduce custom reliability atop UDP or a production general-purpose server.

## Internal sequence for one implementation PR

1. Pure configuration/error/capability values and protocol test vectors; compile compatibility/availability consumers first.
2. Security adapters on explicitly selected owned-session operations, with independent trust/identity/rotation/verifier tests.
3. Native stream/datagram state machine and bounded I/O; then framing.
4. Discovery and bounded listener handoff; selected peer-to-peer/QUIC/multicast adapters only after their feasibility gates.
5. Cross-capability cancellation/ownership/privacy/regression/resource tests, real platform evidence, compiled DocC and owner technical risk review.

These are proposed work groups, not newly numbered I issues or an artificial requirement for five PRs. A later task can be implemented on the same branch while earlier-group evidence is retained; no dependent group is accepted before prerequisites. Do not create precise production issues until selected contracts and unresolved platform/fixture decisions are adequate.

## Outstanding decisions before exact contract

- Choose SDK pinning versus host ATS integration and supported pin representations without a custom certificate parser.
- Select security operation coverage, owned-session requirement and client-identity isolation model.
- Specify the owner-selected RFC 9421 HMAC-SHA256 profile exactly and define the independent test verifier, canonicalization, replay and clock rules.
- Refine the approved app-owned key/reference boundary and document hardware capability policy; no SDK vault is selected.
- Set all size/queue/time bounds, exact framing grammar, browser snapshot semantics, listener binding/handoff and security requirements.
- Select precise QUIC stream model, physical peer-to-peer route and entitlement-supported multicast scope.
- Record exact Swift signatures, Sendable boundaries, platform annotations and errors only after those decisions.

No feature is rejected or delivered by this proposal. Unsupported or unproven candidates stay visible in the original inventory; any narrower selected delivery needs owner approval. No new runtime, key/certificate, trust, signing/install or capability authority is implied.


## Detailed profile and next evidence

See [signing profile](F6_SIGNING_PROFILE.md) for the proposed wire/rotation/admission rules and [feasibility plan](F6_FEASIBILITY_PLAN.md) for the bounded offline candidate compilation/vector proposal. These refine the working design without approving exact APIs or execution.
