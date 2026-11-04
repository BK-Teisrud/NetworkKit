# Shared public HTTP pipeline

I10 / #51, 2026-10-21. `APIClient` connects the approved request builders, secured
URLSession transport and response interpreter. This is an initial buffered HTTP slice,
not a complete v1 or a release approval. See the [work queue](WORK_QUEUE.md).

I12 update: [per-call cancellation and the total budget](CANCELLATION_AND_BUDGET.md) are now enforced.
The sections below describe current behavior; the original I10 evidence remains dated.

I14 update: the [bounded authentication provider](AUTHENTICATION_PROVIDER.md) now runs between request preparation and transport in both call paths, sharing the operation budget/cancellation.

I15 update: [optional sanitized diagnostics](SANITIZED_DIAGNOSTICS.md) emit one terminal event after joined cleanup, with no raw request/response/error hooks and no automatic logging.

I16 update: [storage verification](STORAGE_VERIFICATION.md) covers owned/borrowed strict defaults and explicit public app-managed selection, with native macOS loopback and disclosed other-runtime boundaries.

## Public boundary

`NetworkClient: Sendable` has two asynchronous throwing operations:

- `send<E: Endpoint>(_ endpoint: E) -> NetworkResponse<E.Response>`.
- `send<Value: Sendable>(_ request: URLRequest, response: ResponseStrategy<Value>, options: NetworkCallOptions) -> NetworkResponse<Value>`.

The raw overload without `options` forwards `.default`. Both requirements allow an app
to inject its own client double, including through `any NetworkClient`. Production
transport/clock implementations and scripted test I/O remain internal.

```swift
import Foundation
import NetworkKit

struct Item: Decodable, Sendable { let name: String }
struct ItemCall: Endpoint {
    let path: EndpointPath
    let responseStrategy: ResponseStrategy<Item> = .json()
}

func loadItem() async throws -> NetworkResponse<Item> {
    let client: any NetworkClient = try APIClient(configuration:
        NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!))
    return try await client.send(ItemCall(path: EndpointPath(segments: ["items", "42"])))
}
```

Reuse the client in the app's service layer rather than creating one for each call.
For a raw text response, use `try await client.send(request, response: .text)`; this
still validates the request and origin, applies defaults, and validates the response.

## Construction, isolation and ownership

`APIClient(configuration:)` validates base URL structure/security before creating one
private strict session. `APIClient(configuration:session:)` borrows a compatible active
foreground session. Both bind the immutable configuration's base URL and security policy
to the adapter. The final Sendable class holds only immutable configuration/transport
references; the transport actor and per-operation delegates isolate session work.

The public borrowed initializer currently supports **strict storage only**: nil cookie,
credential and cache stores, automatic cookies disabled, cookie acceptance `.never`,
cache policy `.reloadIgnoringLocalCacheData`, no session delegate/additional headers,
no background identifier, positive finite timeout values. Explicit app-managed storage
profiles remain internal until their later public review. A normal default/ephemeral
session is not automatically compatible; [session rules](SESSION_TRANSPORT.md) explain why.

The app must lend an active session and retain control of its lifetime. Never start new
calls after external invalidation: Foundation has no public validity query and may raise
a native exception for an already invalidated session. Client cleanup never invalidates
a borrowed session. Owned transport cleanup invalidates only its own session. Explicit client shutdown/operation registration is now implemented in I13;
see [shutdown behavior](SHUTDOWN_AND_CONCURRENCY.md).

## One execution and response path

Typed and raw inputs have their appropriate preparation overload, both using the existing
shared validators, snapshot and body/header policies. Each produces `PreparedRequest`.
One private execution method then performs cancellation check → one transport send →
cancellation check → HTTP/status/content validation → selected decoding → NetworkResponse.
Raw calls cannot bypass policy. Additional raw origins drop client defaults and never
permit cross-origin redirects. See [request rules](REQUEST_ENCODING.md),
[response rules](RESPONSE_DECODING.md) and [network security](NETWORK_SECURITY.md).

No automatic retry, authentication refresh, middleware, streaming or upload
system is added. Bodies/responses are buffered in memory.

## Error and timing boundaries

Transport normalization wraps only transport execution. Provider failures use the separate I14 sanitizer before I/O. Existing NetworkError categories
from adapter policy are preserved. Other transport errors retain only NSError domain/code;
URL, payload, userInfo, localized text and underlying error objects are discarded. Default
error descriptions omit the domain. A system NSURLErrorDomain/timedOut becomes
`NetworkError.timeout(.system)`: this does not prove an inactivity-versus-resource cause.
Unexplained URLError.cancelled remains `.transport`; observed task cancellation normalizes
to CancellationError. I12 arbitration preserves an already recorded total timeout or
completion instead of overwriting it with a later cancellation. Explicit CancellationError
remains separate.
Status/response/decoding failures occur outside this catch boundary and keep their category.

Request inactivity limits (default 30 seconds) reach URLSession. The total budget (default 60 seconds) now spans operation entry through final result selection,
with per-call terminal arbitration and joined worker/watchdog cleanup in I12. See the timing
guide for cooperative-cancellation limits. I13 now implements [explicit shutdown/lifecycle registration](SHUTDOWN_AND_CONCURRENCY.md).
The independent platform resource limit still applies to injected sessions.

## Verification and limits

`HTTPPipelineTests` exercises both entry points for JSON/Data/UTF-8/empty success and
metadata, default and replaced status policies, invalid JSON, non-HTTP responses, native
session failure normalization, TLS error identity/redaction, timeout versus unexplained
cancellation, pre-cancellation, pre-I/O security rejection, header precedence and inactivity
propagation. Counting transports verify a single send on failures. No public host is contacted.

Native URLProtocol fixtures run through the real URLSession adapter on macOS/iOS/tvOS;
watchOS uses the explicitly scripted adapter I/O seam because it cannot intercept URLSession
with URLProtocol. `PublicResponseAPITests` imports NetworkKit without @testable and checks
client injection, raw defaults and both public constructors; native borrowed-session I/O
runs where URLProtocol is supported. Test-owned sessions are explicitly invalidated.

`RedirectIntegrationTests` now checks the public owned-session client on macOS with two
real loopback listeners: typed/raw requests receive the denied 302 and the destination
counter remains zero, even when that destination is permitted as a separately initiated
raw origin. Other platforms exercise the real delegate callback with scripted transport.
Existing bounded-redirect/trust/storage suites remain in place.

Actual local and hosted run evidence is recorded on
[issue #51](https://github.com/BK-Teisrud/NetworkKit/issues/51). CI must pass source
integrity, all four platform build/test jobs, DocC and the required quality-gate before
merge. Minimum-OS runtimes, representative physical devices, complete TLS coverage and
v1 timing/lifecycle/auth/privacy/release gates remain outstanding.
