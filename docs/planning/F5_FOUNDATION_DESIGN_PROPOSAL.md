# F5 Foundation connection design proposal

Date: 2026-11-08. Tracking: #89 / #17. Status: draft for owner review. No production transport/API, implementation or additional network budget is approved. PR #169/main acceptance is a separate predecessor gate; #168 findings remain negative/incomplete.

## Proposed transport and scope

Propose one Foundation URLSessionWebSocketTask transport for the selected foreground raw-message increment, subject to explicit acceptance in proposed ADR-0018. It has stronger retained request-target/Host, denied-redirect and default-trust evidence in [#168 findings](F5_HANDSHAKE_SECURITY_REPORT.md), while the original specification suggests Foundation. Apple TN3151 generally favors Network for new WebSocket code; our project-specific delegate/security evidence is the reason to consider the alternative. The incomplete Network instrumentation does not prove Network unsuitable.

Keep one NetworkKit library product, current HTTP declarations/behavior and HTTP NetworkClient unchanged. No shared generic transport framework or alternate production adapter. No automatic reconnect, heartbeat scheduler, event stream, subscriptions/JSON, background continuity, production Watch WebSocket, shared HTTP session or new dependency. iOS/iPadOS18, macOS15 and tvOS18 are selected; unavailable connection APIs on Watch must preserve the existing four-family HTTP build/test matrix.

## Proposed public surface (names/signatures not yet accepted)

| Surface | Intended contract |
| --- | --- |
| WebSocketConfiguration value | One immutable endpoint URL, mandatory positive maximumMessageBytes, explicit headers, optional account-bound authentication, optional subprotocol list, local-loopback opt-in and finite10/10/2s settings. No arbitrary URLRequest/session/delegate injection. |
| WebSocketConnection actor + async connect factory | Creates exactly one owned connection/session from validated configuration; returns only after open and protocol checks. No mutable endpoint or reopen operation. |
| WebSocketMessage value | Text String or binary Data; default descriptions reveal only kind/byte count, not content. |
| send operation | One active send, may overlap one receive; local native acceptance only, no acknowledgement/replay guarantee. |
| receive operation | One active receiver, one complete message per call; optional end for orderly close. No library event queue or public AsyncStream. |
| close operation / close information | Idempotent asynchronous close with validated code/reason, finite cancellation fallback and explicit sanitized close metadata. No raw peer reason in descriptions. |
| WebSocketError | Separate structured category/value errors; no new NetworkError cases or raw error/URL payloads by default. CancellationError remains separate if cancellation wins. |

Apps can wrap their own message/domain value boundary and use app-owned fake values. Do not add a new public connection protocol/mock initializer simply to expose an internal adapter; reassess only for a demonstrated need. The actor/static factory proposal is not code or compiled API evidence.

## Ownership, validation and isolation

Each connection owns a dedicated store-free ephemeral session and its own delegates/task. No injected URLSession in this first increment: it would add external store/delegate/lifecycle policy without a selected need. Nil cookie/credential/cache stores and no session-global credential headers. Never touch a caller's unrelated session. App explicitly closes at foreground exit; destructor cleanup is not the supported completion mechanism or background promise.

One actor owns state/admission, deadlines and one terminal decision. Delegate callbacks deliver only sanitized native observations using an internal adapter; callbacks never mutate actor state directly. Every callback carries an immutable generation/operation identifier, cannot reopen a terminal handle and is discarded after terminal ownership expires. Use deterministic clock/transport seams internally; the synchronous semaphore experiment is not production architecture. Do not transplant HTTP task/delegate/retry/lifetime state.

Validate URL/settings/headers/subprotocols before invoking auth or creating network tasks. Preserve original path/query encoding; reject userinfo/fragments and invalid ports/hosts. Remote WSS/system trust only; explicit local WS allowed only for recognized localhost/loopback, with no auth provider or credential-bearing headers. A local exception does not authorize remote WS or DNS-derived trust bypass.

Proposed application-header reserved set: Host, Connection, Upgrade, Content-Length, Transfer-Encoding, Cookie, Set-Cookie, Proxy-Authorization, Proxy-Connection, Origin and all Sec-WebSocket-* names. Case-insensitive ASCII validation and byte-exact conflict checks; never allow provider headers to bypass the set. Dedicated subprotocol configuration uses nonempty unique valid tokens; when configured, open requires a selected member. No requested protocol means a selected unexpected protocol is a handshake failure. No custom extension/compression configuration; inspect native negotiation and limits before claiming any extension behavior.

## Owner-selected authentication reuse — 2026-11-08

Reuse HTTPHeaders and the existing opt-in NetworkAuthentication/AuthenticationHeaderProvider types, but not HTTP RequestAuthentication or request-building policy. Bind credentials to the configuration's immutable endpoint. Construct one fresh requestID/account/environment context per opening, methodGET, and explicitly map WSS origin to its underlying HTTPS handshake origin (same host/effective port). Local WS cannot acquire credentials. This leaves NetworkOrigin's HTTP-only initializer/validation unchanged; never broaden it to accept WS/WSS or silently rewrite provider context.

The HTTP-shaped context intentionally exposes no path/query/body/header data and does not identify a separate WebSocket operation kind. The owner explicitly selected this documented handshake-context reuse on 2026-11-08, rather than app-precomputed headers. Exact API/implementation and evidence remain pending. There is no automatic reuse of an HTTP client's authentication binding: the app explicitly supplies it to WebSocket configuration. No login/storage/refresh/replay. Merge provider/static headers only when duplicate values are byte-identical; conflict fails before handshake.

## Logical budgets and owner-selected provider boundary

Owner-selected10s connection budget includes header acquisition and native opening;10s send and2s close are finite configurable defaults. These are logical deadlines with scheduler/runtime limits, not hard real-time guarantees. One timer/terminal decision must encompass opening, rather than resetting after auth or protocol callbacks. No fixed lifetime or idle heartbeat for an already-open connection.

The owner selected provider reuse with cooperative cancellation as the app-provider requirement on 2026-11-08, including the disclosed possibility of provider work outliving logical termination. On deadline/cancellation, commit terminal state, cancel owned provider/open work and prevent late results from starting network. Caller completion may precede a provider that ignores cancellation; that task can retain values until it cooperates/returns. There is no safe forced termination of arbitrary Swift async app code. Bound library admission to one provider invocation per connection; do not claim a global resource cap or guaranteed prompt credential-memory release.

The owner selected this boundary for planning; it is not production suitability or a universal resource-risk acceptance. Precomputed headers were offered as the alternative and not selected. Never promise both a hard bounded return and unconditional joining of an uncooperative provider. Deterministic cooperative/noncooperative/late-result tests and a resource/ownership disposition are mandatory before technical acceptance.

## Proposed send/receive/terminal clarification

Validate local send size (UTF-8 byte count or Data length), settings and close parameters before admission. Recommended clarification: invalid local pre-admission input rejects that call without sending or closing an otherwise healthy connection; invalid/oversized incoming data is terminal. This distinction was not explicit in the high-level direction and needs approval. Duplicate concurrent calls reject without cancelling the already admitted call. One send and one receive may overlap; no internal work queue.

Cancellation of an admitted send/receive ends the whole connection as owner-selected. Send/open timeout is terminal; no replay of ambiguous data. One serialized first-committed terminal cause controls pending operations; no later failure/timeout replaces it. Test data/close/cancellation/deadline interleavings and exactly-once completion, not just happy-path actor access.

Proposed orderly end: native normal/going-away or valid empty close returns nil from receive and makes subsequent receives return end; explicit close likewise ends pending receipt. Other peer close codes/abrupt loss become structured failures with explicit optional sanitized close info. Record when a native code is a synthetic sentinel rather than an on-wire status. Validate UTF-8 reason before exposing it; a malformed close is a protocol failure. App-originated close accepts normal1000, going-away1001 or application3000–4999 in this first subset, with reason at most123 UTF-8 bytes; reject reserved codes before state change. Native internal error closure may use the appropriate protocol status. Exact names/public representations remain reviewable proposals.

Native cancellation after2s close does not prove a peer acknowledged, all callbacks/resources drained or secure erase. Keep logical completion separate from actual delegate/task invalidation observations; retained native/runtime allocations are a documented evidence question. No public state-change stream or detailed diagnostics event bus; explicit getters return redacted connection/close metadata only, with payload access opt-in.

## Files and regression boundaries (proposed, no files created)

Use Sources/NetworkKit/WebSockets/ with small values/configuration, connection state, Foundation adapter and validation units rather than a large addition to APIClient. Place deterministic tests under Tests/NetworkKitTests/WebSockets/ and opt-in native probes within the established tool boundary. One existing product; no external package/module/framework architecture. Do not widen public access or use @unchecked Sendable as a shortcut. Final file split follows real implementation size; do not pre-create empty files.

Before claiming availability, compile/run selected iOS/iPadOS/macOS/tvOS routes and keep Watch HTTP regression green. Preserve current floors; no further OS/toolchain bump from this proposal. Record current-family versus exact-minimum, simulator/physical/build-only results. No signing/install or new public fixture budget follows automatically.

## Evidence and proposed work slices

The public binary-echo failure, probe Host/TLS attribution limits and absence of production async/provider/platform evidence remain open. Existing local binary success plus public WSS/text/trust observations are complementary, not an end-to-end binary-WSS pass. Do not weaken binary support silently; obtain a controlled suitable route or explicitly revise scope before acceptance.

| Proposed slice (no issue/code authorization yet) | Reviewable result | Dependency |
| --- | --- | --- |
| Values and deterministic connection state | Exact reviewed API/config/error contract, auth origin mapping, admission/terminal/provider/deadline tests using an internal fake | Owner-approved ADR/design and separate code start |
| Foundation native adapter/security | Owned session/delegate integration; selected-protocol/redirect/store/trust/encoding checks; complete the agreed binary-WSS evidence or stop | Accepted first slice; explicit new finite native budget if needed |
| Platform integration/examples/resources | Actual selected-platform evidence, compiled app wrappers, finite slow-consumer/native lifetime/resource observations and failure history | Accepted adapter; concrete runtime/device authorization as applicable |
| Technical gate | Requirement/API/privacy/security review, owner residual-risk decision and PR/main acceptance | All selected criteria supported or separately approved scope disposition |

Four slices are a proposal, not four new Ready issues or a schedule. They may be grouped only after dependency/overlap review; maxfive work processes and no polling/wait loops remain. No reconnect/stream milestone is selected.

## Decisions needed before final decomposition

Approve or change the Foundation-only recommendation, proposed public surface, HTTP-auth mapping, logical deadline/noncooperative-provider boundary, pre-admission validation distinction and close subset. Then reconcile the exact requirement trace in #89/ADR-0018, fixture/binary-WSS strategy and stop/go conditions before creating implementation issues. #89 stays In Progress; #17 undelivered. #29/#132 remain open; direct generic Watch WebSocket deferred. No production code, new network budget, provisioning/device action or publication is authorized by this draft.

Primary reference for native framing/close validation: [RFC6455, sections5.5 and7.4](https://www.rfc-editor.org/rfc/rfc6455.html). No custom wire implementation is proposed.
