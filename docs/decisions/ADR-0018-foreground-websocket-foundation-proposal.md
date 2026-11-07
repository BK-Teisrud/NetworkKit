# ADR-0018: Proposed Foundation foreground WebSocket connection

Date: 2026-11-08
Status: Proposed; not accepted and no production implementation authorized.
Owner: Teisrud Development AS / BK-Teisrud
Issue / requirement: #89 / #17, proposed NK-10-01/05/06/07 increment

## Context and problem

The owner selected future foreground raw status/data messages, pull receipt, app-owned new connection and optional per-connection auth; no real server protocol exists. The high-level contract direction was approved in PR #167. Separately authorized #165/#168 native probes demonstrate bounded mechanics and explicit negative/incomplete security findings, not a production client. See the [proposed detailed design](../planning/F5_FOUNDATION_DESIGN_PROPOSAL.md) and [#168 report](../planning/F5_HANDSHAKE_SECURITY_REPORT.md).

## Alternatives

- Network framework: Apple's general new-WebSocket recommendation; additional Host/protocol/TLS instrumentation and async state design would be needed here. It is not disproven by an incomplete probe.
- URLSessionWebSocketTask: original source-specification suggestion; stronger retained request-target/redirect/system-trust evidence and existing Foundation expertise, with native limitations/async design still unverified.
- Defer until a concrete server exists; valid if required protocol/workload evidence cannot be obtained within approved scope.
- Two production adapters/generic transport framework: no selected need; avoid doubling state/security/verification paths.

## Proposed decision and rationale

Propose one URLSessionWebSocketTask adapter behind a dedicated per-connection actor and owned store-free session. Keep one NetworkKit product and HTTP NetworkClient/APIClient contracts unchanged. No injected session, public event stream, heartbeat/reconnect scheduler, background continuity or direct generic Watch WebSocket.

The detailed proposal defines reviewable surface/ownership, explicit subprotocol guard, origin-bound optional auth, logical budgets, cancellation/terminal rules and verification slices. It does not claim exact types/signatures compiled or production feasible. Foundation is proposed for project-specific evidence, not a universal performance/security conclusion or authority to reuse HTTP delegates blindly.

## Security, privacy, platforms, and compatibility

WSS/system trust, denied redirects, reserved headers, no automatic stores/refresh/replay and explicit local anonymous loopback exception. Proposed reuse of existing auth types maps WSS to the HTTPS handshake origin; this material mapping requires acceptance and tests. A noncooperative app provider can outlive logical cancellation: the proposed cooperative requirement/retention boundary needs explicit owner disposition, not a hidden hard-timeout promise.

iOS/iPadOS18, macOS15, tvOS18; Watch HTTP support and #132 unchanged. No broader OS requirement change. No raw payload/URL/header/close-reason diagnostics. Public binary-WSS and async/provider/platform evidence remain incomplete; no acceptance inferred from #168 completion.

## Consequences and deferred scope

Prospective four work slices are described, not yet created/authorized. Close subsets and invalid-local-input semantics are proposed clarifications requiring approval. Streams/heartbeat/automatic reconnect remain deferred; no new module/dependency/refactor or extra milestone. #29/#132 publication gates stay open.

## Approval and verification

Pending explicit owner review of transport/design/material boundaries and subsequent plan PR/main. Separate code-start and finite native-budget authorization required. Do not close #89 or create Ready implementation work from this proposed ADR. Earlier approvals of planning direction and #165/#168 code do not accept this decision.

## Supersedes / superseded by

None while proposed. If accepted, supplements ADR-0005/0006/0007 only for a separately scoped WebSocket extension; does not change their HTTP contracts. ADR-0017 deployment floors remain. Preserve all source-specific failure and incomplete evidence.
