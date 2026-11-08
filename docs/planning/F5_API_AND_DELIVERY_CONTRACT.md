# F5 exact API and delivery contract proposal

Date: 2026-11-08. Tracking: #89 / #17. Status: owner-approved exact contract and delivery plan on 2026-11-08; required plan PR/main remains pending. No implementation/runtime authorized. ADR-0018 accepts architecture direction only. This document makes the remaining API, validation and delivery decisions reviewable together.

## Owner-approved interface specification

The following is a declaration specification, not a complete/compiled Swift file or SDK implementation. Existing HTTPHeaders, NetworkAuthentication and NetworkError.TransportFailure are reused without changing their declarations. Each new public type containing URL/header/auth/message/reason data has redacted descriptions; accessors remain explicit data access. All connection-specific APIs are unavailable on watchOS; HTTP support is unchanged.

```swift
public struct WebSocketTimeouts: Sendable, Equatable {
    public let connect: TimeInterval
    public let send: TimeInterval
    public let close: TimeInterval
    public init(connect: TimeInterval = 10, send: TimeInterval = 10,
                close: TimeInterval = 2) throws
    public static let `default`: WebSocketTimeouts
}

public struct WebSocketConfiguration: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let endpoint: URL
    public let maximumMessageBytes: Int
    public let headers: HTTPHeaders
    public let authentication: NetworkAuthentication?
    public let subprotocols: [String]
    public let timeouts: WebSocketTimeouts
    public let allowInsecureLoopback: Bool
    public init(endpoint: URL, maximumMessageBytes: Int,
                headers: HTTPHeaders = HTTPHeaders(),
                authentication: NetworkAuthentication? = nil,
                subprotocols: [String] = [],
                timeouts: WebSocketTimeouts = .default,
                allowInsecureLoopback: Bool = false) throws
}

public enum WebSocketMessage: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case text(String)
    case binary(Data)
}

public struct WebSocketCloseCode: Sendable, Hashable {
    public let rawValue: UInt16
    public static let normal: WebSocketCloseCode
    public static let goingAway: WebSocketCloseCode
    public static func application(_ code: UInt16) throws -> WebSocketCloseCode
}

public struct WebSocketCloseInfo: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public let code: UInt16?
    public let reason: String?
}

public actor WebSocketConnection: CustomStringConvertible, CustomDebugStringConvertible {
    public static func connect(configuration: WebSocketConfiguration)
        async throws -> WebSocketConnection
    public var selectedSubprotocol: String? { get }
    public var closeInfo: WebSocketCloseInfo? { get }
    public func send(_ message: WebSocketMessage) async throws
    public func receive() async throws -> WebSocketMessage?
    public func close(code: WebSocketCloseCode = .normal,
                      reason: String? = nil) async throws
}

public enum WebSocketError: Error, Sendable, Equatable, LocalizedError, CustomStringConvertible, CustomDebugStringConvertible {
    case invalidInput(InvalidInputReason)
    case authenticationFailed
    case handshakeRejected
    case subprotocolMismatch
    case transport(NetworkError.TransportFailure)
    case timeout(TimeoutPhase)
    case operationConflict(Operation)
    case messageTooLarge
    case protocolViolation
    case closed
    case peerClosed(code: UInt16?)

    public enum TimeoutPhase: String, Sendable { case connect, send }
    public enum Operation: String, Sendable { case send, receive }
    public enum InvalidInputReason: String, Sendable {
        case invalidEndpoint, insecureTransport, credentialsOverWS
        case invalidMessageLimit, invalidTimeout
        case reservedHeader, conflictingHeaders, invalidSubprotocol
        case invalidCloseCode, invalidCloseReason
    }
}
```

Only the listed initializers/factory create configuration/timeouts/close codes/connections. No public connection or close-info initializer, mutable configuration, injected session/transport/delegate, shared manager or new public protocol. Every listed CustomStringConvertible/CustomDebugStringConvertible type exposes public get-only description/debugDescription:String; actor descriptions are nonisolated constant redactions. WebSocketError additionally exposes public get-only errorDescription:String? for LocalizedError. The block omits these repetitive getter declarations, not their names/types/privacy requirement. Generated API review must include them. Error text describes categories, never arbitrary underlying localized errors, URL, headers, payloads, account/environment or peer reason. HTTPHeaders construction still throws its existing NetworkError for malformed raw fields; provider-thrown errors are sanitized below.

The connect factory reports a validated native opening, not a guarantee the connection remains open until the caller resumes. No public state stream, automatic diagnostic event stream or app acknowledgement. The single actor is per connection; no global singleton. Static factory/actor availability, custom close-code bridging and concurrency signatures require actual compilation and symbol review after code authorization; failure returns to review rather than silently changing the contract.

## Precise validation and settings

- maximumMessageBytes accepts a positive Int; compare byte counts without overflowing arithmetic and set the native receive limit. It is not a promised safe memory allocation, compressed-wire/frame cap or total native-buffer limit. Outbound text uses UTF-8 byte count; inbound text uses the delivered String's UTF-8 representation; binary uses Data bytes. String equality remains Swift String equality, not raw wire-frame identity.64KiB is an example, not a universal default/workload guarantee.
- Proposed additional timeout bound: each value finite and greater than0, at most86400s (24h). This first-version configuration policy makes timer conversion bounded; it is not an Apple limit or change to HTTP NetworkTimeouts. It requires explicit acceptance in this exact-contract review. Defaults remain10/10/2s. Tiny positive values are logical budgets subject to scheduling/native behavior, not real-time guarantees.
- Configuration validates URL/settings/static headers/protocols before provider/network. Provider results are checked before native task creation. Anonymous connections skip provider entirely. Host normalization, effective port and percent-encoded path/query preservation follow tested private WebSocket validation; do not widen the existing HTTP URL/origin validators.
- Deny URL credentials/fragments and remote WS. Explicit anonymous localhost/IPv4-loopback/IPv6-loopback WS is a separate option; never infer local trust from arbitrary DNS. WSS maps to HTTPS origin with unchanged host/effective port only for the explicitly chosen provider's GET context. One fresh logical requestID per opening. Configuration's endpoint/account binding is immutable, redirects denied, no refresh/challenge credentials/cookies/replay.
- Reserved app/provider headers are the set in the accepted design, including Cookie/Origin and Sec-WebSocket-*; use HTTPHeaders' ASCII normalization and byte-exact duplicate rules. Provider/static duplicates must be identical or fail. No need to reimplement HTTPHeaders construction or expose malformed-header cases that the typed value cannot represent.
- Configured subprotocols are nonempty unique ASCII HTTP tokens, case-sensitive. If none offered, no selected protocol is expected. If offered, the selected protocol must be present and a member. Native acceptance of missing selection is not sufficient; fail before factory success and message admission. Native automatic extension negotiation must be inspected; no app extension/compression API or total decompression-memory guarantee.
- normal/goingAway map to1000/1001; application factory only accepts3000–4999. No broad raw initializer/RawRepresentable conformance bypass. Reason at most123 UTF-8 bytes; invalid code/reason is a local pre-admission error. Native internal failure closure may use other permitted protocol statuses; do not send1005/1006/1015 synthetic sentinels.

## Operation admission and result rules

For send/receive, inspect existing terminal result first, then caller cancellation before admission, then local argument validity, then the relevant active-operation gate. A pre-cancelled caller has not admitted an operation and throws CancellationError without closing a healthy connection. Invalid local input or duplicate call never disturbs already admitted work. At most one send and one receive overlap; no queued sends/receives or pre-open work backlog.

Once admitted, cancellation of send/receive ends the whole connection as owner-selected. Open/send logical timeout also terminates it. One serialized terminal cause controls unfinished operations and cannot be replaced by a later callback/error. An already completed send is not revoked by later close and proves local native acceptance only. Other admitted work sees the committed failure, CancellationError or orderly end as appropriate. No system cancelled code alone establishes caller cancellation.

For orderly remote normal/going-away or valid empty close: receive returns nil, repeated receive returns nil, sends throw closed. Other valid peer close codes cause peerClosed(code:); malformed peer close/unsupported data causes protocolViolation; oversized incoming data causes terminal messageTooLarge. A send rejected for local size before admission throws the same messageTooLarge category without ending a healthy connection. Failed connections rethrow their safe retained terminal category on receive/send; they never reopen.

Close validates its reason before changing state, then idempotently rejects new work and begins native graceful close. It returns normally after observed completion or configured cancellation fallback; no timeout(.close) case and no peer-ack/resource-drain guarantee. If caller is cancelled before close admission, throw CancellationError without changing a healthy connection. Cancellation after local close is committed expedites native cancellation but does not replace that committed local-close result. Repeated valid close after closed/failed returns normally, preserving earlier terminal cause. Invalid close arguments still throw even if already closed.

closeInfo is an immutable final snapshot of a valid peer close observed before local terminal finalization, if any. Its optional code distinguishes a valid empty close from a supplied wire code; never invent an on-wire code from a native sentinel. Validated peer reason is explicit opt-in access, not logging. Late callbacks after finalization cannot mutate the snapshot or reopen the connection. During closing, validated peer metadata may be captured without replacing the chosen terminal cause.

## Error classification boundary

| Source | Surface |
| --- | --- |
| Invalid endpoint/limits/timeout/header policy/protocol or invalid local close arguments | invalidInput(reason), before affected admission/provider/network where applicable |
| Non-cancellation provider error without an already committed library timeout/cancellation | authenticationFailed; never expose the app error object |
| Provider/caller cancellation winning the logical opening/operation decision | CancellationError, separate from WebSocketError |
| Library connect/send deadline winning | timeout(connect/send), never reset after provider or handshake |
| Rejected upgrade/denied redirect | handshakeRejected; no promised HTTP status/response-header payload |
| Missing/unoffered negotiated protocol under configured policy | subprotocolMismatch |
| Native transport/trust identity | transport(existing safe TransportFailure domain/code), no userInfo/raw error or promise of exact TLS defect mapping |
| Conflicting active same-kind call | operationConflict(send/receive), no terminal effect |
| Oversized delivered message / invalid protocol / abnormal peer close | messageTooLarge / protocolViolation / peerClosed(code:), terminal |
| Send after orderly closure | closed |

The logical opening budget includes one provider acquisition and native/protocol opening. Owner selected cooperative-provider reuse with possible work retention after logical cancellation; never wait indefinitely to promise unconditional joining, never start network from a late provider result. Track/cancel each owned job and separately observe actual invalidation/resource lifetime. Noncooperative/late-provider behavior and native callback arbitration are deterministic test requirements, not a production guarantee from the architecture decision.

## Owner-approved delivery decomposition; code unauthorized

I33–I36 identifiers were checked for uniqueness and the four concrete tasks created Blocked, under domain #17 rather than planning #89: [I33/#171](https://github.com/BK-Teisrud/NetworkKit/issues/171), [I34/#172](https://github.com/BK-Teisrud/NetworkKit/issues/172), [I35/#173](https://github.com/BK-Teisrud/NetworkKit/issues/173), [I36/#174](https://github.com/BK-Teisrud/NetworkKit/issues/174). Group A shares the #89 planning/code-start gate with internal I33→I34 order; Group B is natively blocked by both Group A issues, with internal I35→I36 evidence/review order. No dependency cycle or implicit code permission. Four bounded task roles:

| Proposed task | Included requirements/result | Acceptance evidence |
| --- | --- | --- |
| Values, auth and deterministic actor state | NK-10-01/05/06/07 exact values/config/validation, origin mapping, provider-once and admission/terminal logic using internal transport/clock seams | Ordinary public-value tests; cancellation/deadline/order/late-provider/conflict scenarios, no production native transport claim |
| Foundation adapter and handshake security | Owned session/task/delegates, nil stores, native limits, selected-protocol guard, denied redirects/trust/defaults, safe errors and bounded cleanup | Focused deterministic adapter tests plus explicitly authorized finite native observations; no custom protocol/TLS code |
| Selected-platform integration and guide | iOS/iPadOS/macOS/tvOS build/runtime evidence, Watch HTTP regression, compiled app wrappers, finite lifetime/resources and controlled/appropriate binary-WSS route | Source-hashed actual current/minimum/simulator/physical distinctions; preserve failures; no silently waived binary-WSS/provider/async/platform criteria |
| Final technical gate | Requirement/API/privacy/security review, known limits and owner residual-risk disposition | All selected evidence and required PR/main; no production/release approval inferred |

A real binary-WSS evidence route and further native budgets remain unresolved. The corresponding verification task is Blocked until concrete authorized scope exists; do not mark it Ready from this table. No public reruns, tunnel/provisioning/dependency/device installation or certificate changes follow. No new milestone is needed; #29/#132 stay publication barriers. Scope reductions return for explicit owner decision.

To reduce CI churn, values/state and dependent adapter may share one coherent PR; verification/docs and final review may share a second if evidence order permits. Keep four issues and actual blocker relationships, create PRs sequentially and review overlaps. Each dependent merge requires accepted predecessor main plus its own checks; at mostfive work processes, no wait/poll loops. No date/release promise.

## Approval and stop/go

The owner explicitly approved this exact planning contract on 2026-11-08, including24h timeout ceiling, pre-admission cancellation, peer-close result rules, logical-provider retention and close cancellation/fallback behavior. Only after accepted plan PR/main should #89's final trace/decomposition be reconciled and a separate explicit implementation code-start gate be presented. ADR-0018 records the earlier architecture direction; this separate exact-contract decision supplements it without implementation authority. No code is authorized by this declaration document.
