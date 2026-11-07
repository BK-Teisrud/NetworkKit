# F5 server-update feasibility plan

Date: 2026-11-07. Tracking: PLAN-F5 #89 / domain #17. Status: discovery draft; owner-selected platform scope recorded; no prototype, public API, transport or implementation approved.

## Owner-selected need

Future apps need ongoing server-to-app status/data updates while active in the foreground. There is no concrete server or protocol yet. The app decides when to connect again after termination. Automatic reconnect, background continuity and resubscription are outside the first proposal. Subscription/filter messages, message format and delivery guarantees remain unknown. All four platform families were assessed. The owner explicitly approved deferring direct generic Watch WebSocket on 2026-11-07 and evaluating iOS/iPadOS, macOS and tvOS. HTTP Watch support and #132 remain unchanged.

Keep #29 and #132 open. F4 main f86ddcb5ba7a26d05b370007f70b439d0eff5999/run 42406475143 was accepted on 2026-11-07, with I31/I32 and F4 closed; technical acceptance does not authorize publication. No purchase, installation, signing/account change or public-service stress is authorized.

## Source traceability

Original specification v1.0, section 4.10, page 7 is requirements input, not authorization. Stable identifiers below decompose its seven bullets; proposed work does not mark any delivered.

| ID | Source requirement | Proposed disposition |
| --- | --- | --- |
| NK-10-01 | Connect/send/receive text and binary messages | Assess native capabilities; select actual exposed operations only after protocol discovery. Receive-only is not inferred. |
| NK-10-02 | Async events and state changes | Compare pull-based receive and bounded event delivery; no unbounded AsyncStream queue or silent loss selected. |
| NK-10-03 | Ping/pong heartbeat | Investigate native behavior and bounded liveness options; no automatic heartbeat policy selected. |
| NK-10-04 | Reconnect/backoff/attempts/lifecycle | App-owned new connection selected; automatic reconnect/backoff/resubscription deferred. HTTP retry semantics must not be reused by assumption. |
| NK-10-05 | Handshake authentication/renewal | Assess secure headers and origin binding; no automatic refresh, token persistence or hidden replay selected. |
| NK-10-06 | Close codes/reasons/graceful shutdown | Require bounded closure/cancellation and sanitized diagnostics; detailed API and error precedence pending. |
| NK-10-07 | Memory/backpressure/drop policy | Require explicit message/queue bounds and slow-consumer behavior; exact limits pending workload selection. |

## Platform assessment and transport decision

Apple TN3135 classifies both Network framework connections and URLSessionWebSocketTask as low-level networking on watchOS. Ordinary status-update apps do not qualify for its listed audio-streaming, active VoIP or application-service exceptions. Foreground operation alone does not qualify. Apple explicitly warns that the simulator permits low-level networking regardless of those device restrictions.

| Family / current floor | Discovery outcome | Evidence still needed |
| --- | --- | --- |
| iOS/iPadOS 18 | Candidate for foreground direct WebSocket | Native TLS/handshake/lifecycle/resource validation; no runtime pass from documentation. |
| macOS 15 | Candidate for foreground direct WebSocket | Sandbox/network access, cancellation, TLS and resource validation. |
| tvOS 18 | Candidate for foreground direct WebSocket | Native lifecycle, suspension and actual device verification plan. |
| watchOS 11 | Direct generic status-update WebSocket is not a supported proposed route under TN3135 | Owner decision to defer this feature on Watch; HTTP core support remains separate. Never infer a workaround from simulator success. |

Owner-approved scope decision, 2026-11-07: evaluate direct WebSocket for iOS/iPadOS/macOS/tvOS and defer direct generic Watch WebSocket. This changes only the selected F5 proposal, not HTTP platform support or #132. App-owned HTTP refresh/polling or companion integration may be separate future product choices; do not add them automatically or request audio/VoIP exceptions for an unrelated app.

The original specification names URLSessionWebSocketTask. Apple TN3151 now recommends Network framework for new WebSocket code unless there is a specific reason for URLSession. Compare both before adopting a transport: secure handshake/auth/redirect/origin policy, system trust, proxy/cookie/credential behavior, framing/message bounds, cancellation and shutdown, testability, actor isolation and current OS availability. Reusing HTTP configuration is not itself proof of equivalent security. Do not build custom TLS or a custom production WebSocket stack. Keep one library product unless evidence justifies a separate decision; do not merge long-lived connections into HTTP request deadlines/retry state.

## Contract questions before a prototype

- Identify a representative future server contract or explicitly approve a synthetic reference protocol. Decide whether subscription messages/outbound sends are needed; text/JSON/binary, maximum message bytes, expected rate/bursts and maximum active connections.
- Define message meaning: snapshots versus deltas, freshness, sequencing/duplicates, missed-update recovery and an HTTP resynchronization route. WebSocket alone does not guarantee application-level recovery.
- Define state transitions and handshake/open/closing deadlines separately from a long-lived connection. The HTTP 60-second total budget is not automatically a connection lifetime.
- Define one reader versus multiple consumers, explicit bounded queues, oversize/slow-consumer policy and terminal event/error precedence. Native receive limits do not establish a total process-memory cap.
- Define WSS/system-trust/origin restrictions, optional explicitly local development exception, auth acquisition boundaries and redaction. Never log payloads, tokens, URL queries or raw close reasons by default.
- Define host-app foreground transitions and explicit closure. Avoid platform UI framework dependencies in the library. No promise of continuous background delivery.

Unknown server/workload details are blockers to a production contract, not invitations to invent generous defaults.

## Proposed non-delivering feasibility task

Do not execute this task until separately authorized. Prepare one bounded isolated spike using only synthetic local fixtures and native Apple APIs. First agree its exact source area and stop/go limits; do not add a public SDK API or new dependency. No paid/remote environment is assumed.

Compare the two native client options against a controlled fixture that can count connections/messages, delay handshake, send bounded text/binary frames, fragment messages, close normally/abnormally and exercise slow consumers. Use an appropriate local native fixture without building a production server. A local TLS route must use system-trusted certificates with separately approved provisioning, or remain an explicit evidence gap; local cleartext cannot stand in for WSS/trust proof. No certificate bypass or public stress route.

Produce deterministic state/cancellation tests and actual native evidence for handshake/auth/origin, message bounds, ordering, slow consumption, close/shutdown and finite resource observations. Separate build-only, simulator, physical, current-family and exact-minimum observations. No Watch support claim from simulation. Physical signing/installations or settings changes require their applicable separate authorization.

Stop if the native route cannot enforce the agreed contract without a custom protocol/TLS stack, uncontrolled buffering, hidden replay or broad HTTP-core restructuring. Report limitations before selecting architecture. A negative result is a valid outcome; do not expand scope to force a pass.

## Backlog and decision gates

1. Finish use-case/platform/transport discovery within existing #89. No duplicate planning issue needed.
2. Obtain owner approval of the bounded feasibility scope; only then create a narrowly scoped non-delivering spike issue if needed and obtain explicit code-start authorization.
3. Review evidence and approve a contract/ADR. Decide whether a real use case justifies delivery now; deferral remains valid.
4. Decompose accepted implementation into transport/lifecycle, bounded message/security tests, integration/docs/native verification and a technical review. Exact issue count follows evidence; no speculative I-issues now.
5. Evaluate a separate reconnect increment only after a concrete need. Do not add a milestone for it preemptively.

#89 remains In Progress until the requirements, scope/architecture, fixture strategy and resulting approved task decomposition are actually accepted. #17 remains an undelivered domain epic. Planning does not authorize code, production suitability, publication or changes to #29/#132.

## Primary sources reviewed

- [Apple TN3135: Low-level networking on watchOS](https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos) — supported scenarios and simulator/device distinction.
- [Apple TN3151: Choosing the right networking API](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api) — compare Network framework with URLSession for WebSocket.
- [Apple URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask) — native task candidate, not a support guarantee.
- [Apple maximumMessageSize](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask/maximummessagesize) — investigate message-limit behavior separately from aggregate memory.

No library WebSocket behavior was executed or verified by this documentation-only assessment.
