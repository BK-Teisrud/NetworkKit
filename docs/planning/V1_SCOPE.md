# First stable release scope

Historical phase timing update, 2026-10-31: [ADR-0013](../decisions/ADR-0013-watch-publication-gate.md) moves unexecuted physical Watch evidence to mandatory #132/#29 pre-publication verification. This changes only phase timing; four platform families, watchOS 10 support, public API and toolchain minima remain unchanged. No F2 closure, support reduction, publication or F3 implementation is authorized.


Status: Core scope and module choices accepted 2026-10-19; see [ADR-0003](../decisions/ADR-0003-v1-scope-and-naming.md). The initial public HTTP pipeline is implemented through I10. [F1 review](F1_REVIEW.md) records I11 verification and the remaining F2/release requirements; this is not complete v1 readiness.

Repository/package NetworkKit distributes one library product and module named NetworkKit. Consumers import NetworkKit. Later test targets are not additional library modules.

## V1 user flow

A host app configures/injects the client, defines a typed HTTP call, executes it through URLSession, and receives JSON or a comprehensible error. Timeout/cancellation behavior is defined, logging preserves privacy, and behavior is deterministically testable without public networking.

This includes necessary URL/request construction, configuration, system trust, privacy, session lifecycle, and documented platform support. No advanced module is required for this flow.

## Traceable delivery boundary

The table defines domain scope. [HTTP_API_CONTRACT.md](HTTP_API_CONTRACT.md) / ADR-0005 specifies HTTP/responses/errors; [CONCURRENCY_AND_LIFECYCLE.md](CONCURRENCY_AND_LIFECYCLE.md) / ADR-0006 specifies concurrency/ownership; [SECURITY_AND_NETWORK_POLICY.md](SECURITY_AND_NETWORK_POLICY.md) / ADR-0007 specifies security/networking. Concrete verification tasks remain necessary before Ready. A row does not select every original subrequirement.

| Domain | Included in v1 | Deferred / no v1 commitment |
| --- | --- | --- |
| NK-01 HTTP and requests | Request execution, defined timeouts/cancellation, and core HTTP operations | General interceptor framework and advanced transport control |
| NK-02 Endpoints and URL construction | Typed calls, injected baseURL, safe URL/parameter construction | Automatic API versioning and advanced encoding variants |
| NK-03 Responses and data handling | JSON, raw Data/text, explicit empty responses, status/response validation, response wrapper | Streaming, AsyncSequence responses, custom alternative-format framework |
| NK-04 Error handling | Clear transport/HTTP/coding/timeout/cancellation contracts | Retry classification for a future resilience engine |
| NK-05 Authentication | Small injectable header provider and explicit headers; app-owned login/storage/renewal | Keychain adapter, login, OAuth/OIDC, refresh, multiple-profile management |
| NK-06 Security and TLS | HTTPS/system trust and safe credential handling as foundations | Pinning, mTLS, signing/HMAC, custom trust policies, separate security module |
| NK-07 Retries and resilience | Defined errors, timeouts, and cancellation | Custom retry engine/policy, circuit breakers, rate limiting, queues |
| NK-08 Caching | No automatic HTTP cache; other URLSession storage requires explicit app-managed profiles | Custom cache module, offline/TTL/fallback, stale-while-revalidate |
| NK-09 File transfers | Ordinary HTTP payloads under the core contract | File-transfer APIs, multipart, progress, resume, background transfers |
| NK-10 WebSocket and real-time communication | Outside the HTTP core | WebSocket and reconnect |
| NK-11 TCP, UDP, and local networking | Outside the HTTP core | TCP/UDP, Bonjour, QUIC APIs, listeners, multicast |
| NK-12 Network status | Handle failures from actual HTTP operations | Separate NWPathMonitor service and status streams |
| NK-13 Logging and observability | Safe logging/diagnostics with data minimization and a testable boundary | Detailed task metrics/signposts and expanded observability product |
| NK-14 Concurrency and lifecycle | async/await, necessary Sendable/isolation, cancellation, defined session ownership | Batch APIs, generic deduplication, stream/queue frameworks |
| NK-15 Configuration | Injectable client/session configuration and defined request defaults | Advanced mutable policy systems and module-specific policies |
| NK-16 Testing and mocking | Deterministic tests, injectable transport, negative/cancellation tests for the core | Separate distributed NetworkKitTesting product and deferred-module tests |
| NK-17 Performance and optimization | Reasonable resource use and representative quality measurements | Separate performance module, coalescing, unmeasured optimization projects |
| NK-18 Privacy and data protection | No sensitive default logs/external telemetry; documented session data handling | Storage/deletion APIs for custom cache/authentication/transfer modules |
| NK-19 Apple platform integration | Actual availability, guards, and a matrix for selected platforms | Background/local-network/App Groups and other advanced integrations |
| NK-20 Developer experience and API design | Small documented API, HTTP/JSON/error/injection/testing guides, DocC, release requirements | Examples/APIs for deferred modules; Combine adapter |

## Contract decisions and outstanding verification

DEC-04 / ADR-0005 selects typed endpoints plus raw URLRequest, JSON/Data/text/EmptyResponse, response wrappers, structured errors with separate CancellationError, and 2xx with explicit call exceptions. HTTP_API_CONTRACT elaborates methods, URL/query, header precedence, bodies, and validation. DEC-05 / ADR-0006 selects reused owned sessions plus injection, isolated state, cancellation/shutdown, and a controlled-clock 30-second inactivity / 60-second total budget. DEC-06 / ADR-0007 selects the header provider, stores off by default, HTTPS with explicit local HTTP access, bounded redirects, and privacy-safe diagnostics. These decisions cannot expand v1 into advanced modules without a new scope decision.

The owner-delegated [ADR-0017](../decisions/ADR-0017-current-platform-baseline.md) supersedes the OS minimums from DEC-01/ADR-0004 with iOS/iPadOS 18, macOS 15, watchOS 11 and tvOS 18. Xcode 26.3+, Swift tools 6.2 and Swift 6 remain. See the [platform matrix](PLATFORM_MATRIX.md). Selected API symbols compile on all four platform families under the actual CI matrix; final API/availability review and actual minimum-runtime compatibility remain unverified. No exclusion waives necessary core security/privacy/platform requirements: advanced security modules are deferred, but system trust is foundational.

## Completion and change control

V1 requires fulfilled contracts, real tests/CI, documented platform support, security/privacy review, and REL-01. F0 acceptance and explicit owner authorization are required before implementation. Specification catalog entries do not enter v1 automatically; scope changes require a reasoned decision.
