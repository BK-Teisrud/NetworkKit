# F5 foreground connection contract proposal

Date: 2026-11-07. Tracking: #89 / #17. Status: proposal; only the explicitly listed owner selections are accepted. No public API, production transport or further code is authorized. Experiment #165 is completed after accepted PR #166/main210a8bbae8d017ca7cb94983e390df8676ea0355/run42412525675.

## Accepted planning inputs

- Future foreground server-to-app status/data updates; no concrete server yet.
- Minimal synthetic reference protocol: raw text/binary messages, no imposed JSON/subscription schema. Apps interpret data and choose recovery/resynchronization.
- Evaluate iOS/iPadOS18, macOS15, tvOS18. Direct generic Watch WebSocket deferred under TN3135; HTTP Watch support and #132 unchanged.
- App owns new connections after termination; no automatic reconnect, resubscription or background continuity.
- One active receiver requesting one message at a time; no library-owned unbounded event queue. Native buffering is not an aggregate-memory cap.
- Optional handshake headers once per new connection; anonymous connections permitted. No token persistence, automatic renewal or hidden reconnect.
- Cancellation of an active send or receive terminates the whole connection; no automatic new connection or message replay. Explicit owner selection on 2026-11-07.

These inputs were explicitly selected by the owner. Remaining details below are recommendations for review, not inferred owner approval.

## Proposed operations and ownership

Keep one SDK product and isolate long-lived connections from HTTP request/retry/deadline state. Define one explicit new connection operation, raw text/binary send, one-message receive and idempotent close; names, signatures, concrete types and transport remain pending an ADR/API review. No requirement is added to the existing buffered NetworkClient protocol and no direct SwiftUI/UIKit lifecycle dependency is introduced.

A handle owns one connection with created → connecting → open → closing → closed/failed progression. The app closes when its foreground use ends. A closed/failed handle cannot reopen; new connection means a new handle/auth acquisition. Admit send/receive only in open state. One send and one receive may overlap; a second concurrent send or receive is rejected rather than silently queued. Do not allow pre-handshake message queues.

Receive returns exactly one complete text/binary message, returns normal end on an orderly peer close, or throws a structured failure. Do not expose ping/pong or close payloads as application data. A successfully completed send means local native acceptance, not server receipt/application acknowledgement or persistence. Transport ordering is not an application-level exactly-once/sequence/recovery contract.

Apps may run their own receive loop and wrap decoded values in their own boundary. No built-in AsyncStream/event bus/multiple subscribers, JSON decoder, app cache or mock-only public initializer is proposed. Source NK-10-02 async event/state streams would therefore be explicitly deferred in favor of pull-based receipt, subject to final scope approval.

## Proposed finite settings

| Setting | Proposed first contract | Boundary |
| --- | --- | --- |
| Maximum message bytes | Required positive value per connection; 64KiB reference examples only | Incoming native setting plus delivered-size verification; outgoing UTF-8/Data byte count checked before native send. Not a frame or total-memory cap. Native representable bounds must be verified. |
| Connection establishment budget | Default10s, configurable finite positive value | Includes header acquisition plus opening; final cancellation/timeout arbitration must be designed and tested. |
| Open connection lifetime | No automatic HTTP60s lifetime | App closes explicitly; OS suspension remains possible. No permanent availability promise. |
| Idle receive | May wait while open until data/close/cancellation | No hidden heartbeat/idle timeout. App cannot infer peer liveness from silence. |
| Individual send budget | Default10s, configurable finite positive value | Timeout ends connection; no replay or ambiguous-delivery retry. |
| Graceful close budget | Default2s, configurable finite positive value | Then request native cancellation. Bound local completion without promising instantaneous OS resource release or remote acknowledgement. |
| Active operations | At most one send and one receive per handle | Reject conflicting admission; no SDK work backlog. App owns number of handles. |

Validate settings before auth/network. Exact maximum representable byte/time values and zero/nonfinite/overflow handling must be included in detailed design. The native Mac spike observed equality at64KiB and rejection above it; that is not all-platform proof or a workload recommendation. Multibyte text, fragmentation, long bursts, native buffering and lifecycle races need separate evidence.

## Proposed security and authentication boundary

WSS and system trust required for real remote connections. Consider only explicit loopback WS for local development, with address/host parsing reviewed separately; no general insecure mode. Reject URL userinfo and fragments; never put credentials in URLs. Verify exact path/query/Host and subprotocol negotiation in a controlled fixture before adoption.

Bind optional headers/auth acquisition to the original immutable endpoint and one logical opening. Header acquisition must be cancellable/budgeted without a provider callback being able to resurrect a terminal handle. Protected transport headers, malformed names/values and conflicting credentials are rejected before use. Define an explicit reserved-header set in detailed design rather than passing arbitrary Host/Upgrade/Connection/Sec-WebSocket-* overrides. Subprotocols require a separate validated configuration field and selected-protocol check.

Propose rejecting all handshake redirects and challenge-based credential renewal in the first version. No automatic account/origin change, token refresh, cookie store, credential store, shared HTTP session or request replay. Anonymous connections do not invoke an auth provider. Optional app-supplied credentials remain app-owned and must not be logged. A Network transport does not inherit Foundation/HTTP security by default.

No trust override, custom TLS, pinning, mTLS, automatic network-path recovery or entitlement workaround. These are proposed contract requirements: the spike did not verify WSS, redirect rejection, actual auth providers, path/query/Host or Network selected-subprotocol validation. A transport must prove them or the scope must return for explicit revision.

## Proposed termination and errors

Separate categories for invalid settings/endpoint/headers, opening/handshake rejection, trust/transport, message limit/type/protocol, operation conflicts, send timeout and closed connection. Public shape and whether an underlying native error is exposed remain open; do not add cases to NetworkError speculatively. Swift CancellationError remains separate when cancellation wins terminal arbitration.

Owner-selected policy: cancellation of active receive or active send terminates the whole connection. Cancellation during opening is also proposed to terminate opening. Native message receipt/partial-send state cannot safely be assumed resumable after a cancelled operation. No silent message discard followed by continued reads and no retry of an ambiguously delivered send. The active send/receive policy was explicitly accepted by the owner on 2026-11-07; it is not inferred from the HTTP client. Exact cancellation/terminal arbitration still needs detailed design and evidence.

Define one serialized terminal decision. The first committed terminal cause controls pending operations; no later timeout/error overrides it or reopens the handle. Normal close is distinct from failed transport; malformed/oversized/unexpected data ends the connection. Graceful close rejects new operations immediately and attempts native close before its configured cancellation fallback. Duplicate close is safe. Close/code/reason validation must exclude forbidden wire codes and enforce protocol length/UTF-8 requirements using native framing.

Do not claim hard real-time shutdown, universal callback drainage, secure erase, total-memory bounds or remote delivery acknowledgement. Define owned-task joining versus bounded return precisely in detailed design. Tests must cover cancellation/close/data/deadline races, late callbacks and peer noncooperation before a product contract can be accepted.

## Explicit exclusions and requirements disposition

NK-10-01 raw operations, NK-10-05 bound handshake auth, NK-10-06 closure and NK-10-07 bounded operation/message policy are proposed for the first increment. NK-10-02 event/state stream, NK-10-03 scheduled heartbeat and NK-10-04 automatic reconnect are proposed deferred. Native protocol-mandated ping responses are distinct from a library heartbeat scheduler and must be verified. No exactly-once, missed-update repair, persistence, subscriptions, JSON schema, background operation, reconnect, upload/download integration or production Watch WebSocket is selected.

The source document's URLSession suggestion remains under comparison with Network framework; [transport assessment](F5_TRANSPORT_ASSESSMENT.md) and [native findings](F5_NATIVE_FEASIBILITY_REPORT.md) are inputs. Do not reuse HTTP retry state, automatic diagnostic events or the standalone semaphore harness as a production architecture. No further module/framework or public protocol is justified yet.

## Evidence gates and next decisions

1. Review this combined proposal with the owner, retaining the accepted connection-ending cancellation policy and reviewing proposed explicit message bounds, new finite settings, exclusions and raw operation model. Record accepted changes in an ADR only after material questions are resolved.
2. Review the [complementary local/public WSS feasibility proposal](F5_SECURITY_VERIFICATION_PLAN.md), which distinguishes controlled handshake observations from public TLS/echo observations and does not replace a controlled trusted server universally. Establish feasibility for endpoint/header/subprotocol/redirect/trust controls and async state/backpressure boundaries. Additional experiment code requires separate scope and authorization beyond #165.
3. Choose one transport only after its security/lifecycle feasibility is sufficient. Explicitly accept any deviation from the source specification; do not adopt both adapters or create a transport framework speculatively.
4. Specify exact API and testable internal boundaries, supported platform evidence, source hashes, physical/current/minimum/build-only distinctions and actual publication workload review. Native SDK availability is not an execution pass.
5. Decompose concrete implementation/test/docs/native/gate issues only from accepted design. #89 remains In Progress and #17 undelivered; #29/#132 remain open. No production implementation code-start follows from a plan or experiment approval.
