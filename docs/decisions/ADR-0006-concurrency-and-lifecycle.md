# ADR-0006: Session ownership, concurrency, and time limits

Date: 2026-10-19. Status: Core choices accepted by the owner; lifecycle and concurrency details elaborate those choices.
Issue: [DEC-05 / #5](https://github.com/BK-Teisrud/NetworkKit/issues/5).

## Owner's choices

- A reused, owned URLSession by default, with support for injection. The client never invalidates an injected session owned by the app.
- A default timeout after 30 seconds without new data and a 60-second total budget. Both are configurable per client or call.

[CONCURRENCY_AND_LIFECYCLE.md](../planning/CONCURRENCY_AND_LIFECYCLE.md) elaborates these choices and ADR-0003/0005 requirements for safe concurrency and a separate CancellationError. No implementation or exact Swift signatures are created now.

## Decision

Multiple concurrent tasks may use the client. Configuration and request input are snapshots; shared mutable state is isolated. No client-wide actor may unintentionally serialize the entire HTTP/decoding operation. Typed values and client boundaries must satisfy Swift 6 contracts without blanket unchecked Sendable exemptions.

The client either owns its session or borrows an app-owned session. Ownership is explicit and fixed during use. Shutdown rejects new calls, cancels the client's active operations, and performs cleanup. Only an owned session may be invalidated. A separate graceful-drain mode is outside v1; the app may await its calls before shutdown.

The production clock is monotonic, with ContinuousClock as the planned system foundation and an injectable internal clock/sleeper boundary for deterministic tests. No external clock library is allowed. Timeout, user cancellation, shutdown, and normal completion have explicit terminal causes, preventing internal timeout cancellation from being reported as the user's CancellationError.

## Rationale and alternatives

Owned sessions alone would be less flexible. The owner also chose injection, which requires a clear boundary around the client's control of a borrowed session.

Longer defaults (60/300 seconds) or no total library deadline were offered as alternatives. The owner chose 30/60 seconds. These are HTTP-core defaults, not support for long-running transfers.

A global singleton, one session per request, a global request lock, or wall-clock deadlines would weaken ownership, resource use, parallelism, or testability. They are outside the contract. Actor isolation applies to state requiring it, without promising one particular public implementation type.

## Material limitations

Request timeout follows URLSession's inactivity/wait-for-data semantics, not total elapsed operation time. The client's total budget also includes preparation, hooks, and response processing. OS scheduling and cooperative cancellation mean there is no hard real-time guarantee of returning at exactly 60 seconds. Do not return a late result as success once expiration of the selected deadline has been recorded.

An injected session may impose stricter resource timeouts or external invalidation that the client cannot override. A call cannot promise to extend those constraints. Raw URLRequest uses the same explicit time limits as typed endpoints. DEC-06 sets security/authentication/redirect/cache policy for both ownership modes; reject incompatible injection instead of making a false security promise.

## Checks and next steps

Apple documentation and local SDK declarations were inspected for request timeout, session invalidation, and ContinuousClock/CancellationError. The base symbols' declared availability fits the approved OS minimums. These are source/declaration checks, not builds or runtime tests.

The contract document specifies cancellation, ownership, deadline, race, shutdown, and concurrency tests. None has run. At adoption, DEC-06, DEC-07, and the F0 gate remained open.

## Sources

- [Apple: timeoutIntervalForRequest](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforrequest)
- [Apple: invalidateAndCancel](https://developer.apple.com/documentation/foundation/urlsession/invalidateandcancel%28%29)
- [Apple: Task.cancel](https://developer.apple.com/documentation/swift/task/cancel%28%29)
- [Apple: TaskGroup](https://developer.apple.com/documentation/swift/taskgroup)
- [Apple: ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock)
- Local SDK 26.2: Foundation/Headers/NSURLSession.h and usr/lib/swift/_Concurrency.swiftmodule/x86_64-apple-macos.swiftinterface.
