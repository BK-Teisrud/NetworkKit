# ADR-0018: Proposed Foundation foreground WebSocket connection

Date: 2026-11-08
Status: Owner-approved architecture/design direction on 2026-11-08 only. Exact contract was subsequently owner-approved in [the API/delivery specification](../planning/F5_API_AND_DELIVERY_CONTRACT.md) on 2026-11-08; required plan PR/main, implementation/runtime and production/publication decisions remain.
Owner: Teisrud Development AS / BK-Teisrud
Issue / requirement: #89 / #17, proposed NK-10-01/05/06/07 increment

## Context and problem

The owner selected future foreground raw status/data messages, pull receipt, app-owned new connection and optional per-connection auth; no real server protocol exists. The high-level contract direction was approved in PR #167. Separately authorized #165/#168 native probes demonstrate bounded mechanics and explicit negative/incomplete security findings, not a production client. See the [proposed detailed design](../planning/F5_FOUNDATION_DESIGN_PROPOSAL.md) and [#168 report](../planning/F5_HANDSHAKE_SECURITY_REPORT.md).

## Alternatives

- Network framework: Apple's general new-WebSocket recommendation; additional Host/protocol/TLS instrumentation and async state design would be needed here. It is not disproven by an incomplete probe.
- URLSessionWebSocketTask: original source-specification suggestion; stronger retained request-target/redirect/system-trust evidence and existing Foundation expertise, with native limitations/async design still unverified.
- Defer until a concrete server exists; valid if required protocol/workload evidence cannot be obtained within approved scope.
- Two production adapters/generic transport framework: no selected need; avoid doubling state/security/verification paths.

## Accepted architecture direction and rationale

The owner selected one URLSessionWebSocketTask adapter as the architecture direction behind a dedicated per-connection actor and owned store-free session. Keep one NetworkKit product and HTTP NetworkClient/APIClient contracts unchanged. No injected session, public event stream, heartbeat/reconnect scheduler, background continuity or direct generic Watch WebSocket.

The detailed proposal defines reviewable surface/ownership, explicit subprotocol guard, origin-bound optional auth, logical budgets, cancellation/terminal rules and verification slices. It does not claim exact types/signatures compiled or production feasible. Foundation is proposed for project-specific evidence, not a universal performance/security conclusion or authority to reuse HTTP delegates blindly.

## Security, privacy, platforms, and compatibility

WSS/system trust, denied redirects, reserved headers, no automatic stores/refresh/replay and explicit local anonymous loopback exception. Proposed reuse of existing auth types maps WSS to the HTTPS handshake origin; the owner selected this mapping for planning on 2026-11-08; exact API and tests remain. A noncooperative app provider can outlive logical cancellation: the owner selected the cooperative requirement/retention boundary for planning, not production suitability or a hidden hard-timeout promise.

iOS/iPadOS18, macOS15, tvOS18; Watch HTTP support and #132 unchanged. No broader OS requirement change. No raw payload/URL/header/close-reason diagnostics. Public binary-WSS and async/provider/platform evidence remain incomplete; no acceptance inferred from #168 completion.

## Consequences and deferred scope

Prospective four work slices are described, not yet created/authorized. The owner accepted the close subset and invalid-local-input semantics as planning direction on 2026-11-08. Streams/heartbeat/automatic reconnect remain deferred; no new module/dependency/refactor or extra milestone. #29/#132 publication gates stay open.

## Approval and verification

The owner explicitly approved the architecture/design direction in conversation on 2026-11-08, still no new code. Architecture PR #170 is merged; its main acceptance remains a predecessor gate. The owner subsequently approved the separate exact API/delivery plan, still no code. Required exact-plan PR/main and verified task decomposition remain before #89 closure. Separate code-start and finite native-budget authorization required. Do not close #89 or create Ready implementation work from this architecture-only approval. The separate #165/#168 authorizations do not extend to production code.

## Supersedes / superseded by

Supplements ADR-0005/0006/0007 only as accepted planning direction for a separately scoped WebSocket extension; does not change their HTTP contracts or authorize implementation. ADR-0017 deployment floors remain. Preserve all source-specific failure and incomplete evidence.
