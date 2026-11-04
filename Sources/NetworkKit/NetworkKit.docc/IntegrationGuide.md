# Integrating NetworkKit

Configure a reusable client, execute buffered HTTP calls and control its lifetime.

## Installation and current status

The repository and Swift package are named SwiftNetworkKit; the library product and import are NetworkKit. Open the repository-root Package.swift in Xcode, or add the repository URL as a package dependency and select the NetworkKit product. There is no published v1 tag yet: evaluate an explicitly reviewed commit/revision, subject to Teisrud Development AS's proprietary rights and written permission requirements. Public visibility is not permission to ship the library in another application.

Use Xcode 26.3 with the verified Swift 6.2.4 compiler for the current CI baseline; tools version is 6.2 and language mode is Swift 6. Product deployment minima are iOS/iPadOS 17, macOS 14, watchOS 10 and tvOS 17. Newer-SDK builds do not prove minimum-runtime support. The accepted platform matrix records actual minimum-family and non-Watch physical results with exact patch/architecture/suite limits. Physical Watch verification remains a separate pre-publication requirement; no stable release or production workload suitability is approved. No visionOS, Catalyst, Linux or external package dependency is selected.

All Swift blocks below belong to one consumer file with `import Foundation` and `import NetworkKit`. The exact blocks are compiled and exercised by DocumentationExamplesTests with an ordinary external module import, without @testable. CI checks that the published blocks match that source. They demonstrate a local consumer contract; they do not provision a server, send credentials, or establish native TLS/device compatibility.

## Typed JSON calls

An endpoint describes a response strategy and safely encoded path/query data. Keep values decoded when supplying segments. Typed endpoints cannot change the client's origin. The reusable client returns the decoded value plus HTTP status and case-insensitive response headers.

<!-- DOC-EXAMPLE: typed -->
```swift
struct GuideItem: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

struct GuideItemCall: Endpoint {
    let path: EndpointPath
    let query: [HTTPQueryItem]
    let responseStrategy: ResponseStrategy<GuideItem> = .json()

    init(id: Int) throws {
        path = try EndpointPath(segments: ["items", String(id)])
        query = [try HTTPQueryItem(name: "include", value: "summary")]
    }
}

func guideLoadItem(using client: any NetworkClient, id: Int) async throws -> NetworkResponse<GuideItem> {
    try await client.send(GuideItemCall(id: id))
}
```

Use `guideMakeOwnedClient` below at the owning service boundary, then call `guideLoadItem`. The fixture model is Codable/Sendable, and the endpoint defaults to GET. For a real app, adapt the model and server contract. Header values returned to the app are not automatically safe to log.

## Raw calls, other formats and request bodies

Raw URLRequest follows the same APIClient security/status/time-budget checks. JSON is selected explicitly for a model; Data preserves buffered bytes, text requires supported UTF-8 semantics, and EmptyResponse skips payload decoding. Use explicit empty semantics for HEAD/204 rather than expecting an empty body to manufacture a JSON model. The send APIs buffer their responses. Use the separate <doc:FileDownloads> operation for foreground GET-to-file transfers with explicit size and ownership rules.

<!-- DOC-EXAMPLE: formats -->
```swift
func guideReadFormats(using client: any NetworkClient, url: URL) async throws -> (Data, String, EmptyResponse) {
    let request = URLRequest(url: url)
    let data = try await client.send(request, response: .data)
    let text = try await client.send(request, response: .text)
    let empty = try await client.send(request, response: .empty)
    return (data.value, text.value, empty.value)
}

func guideReadExplicitErrorBody(using client: any NetworkClient, url: URL) async throws -> Data {
    let options = try NetworkCallOptions(
        inactivityTimeout: 15, totalTimeout: 45,
        acceptedStatuses: HTTPStatusPolicy(codes: [200, 404]), authentication: .disabled)
    return try await client.send(URLRequest(url: url), response: .data, options: options).value
}

/// Opt in only when the service's read semantics permit replay.
func guideReadWithOneRetry(using client: any NetworkClient, url: URL) async throws -> Data {
    let options = try NetworkCallOptions(retry: .oneRetryForSafeReads)
    return try await client.send(URLRequest(url: url), response: .data, options: options).value
}

func guideEncodeItem(_ item: GuideItem, baseURL: URL) throws -> URLRequest {
    struct CreateItem: Endpoint {
        typealias Response = EmptyResponse
        let path: EndpointPath
        let method: HTTPMethod = .post
        let body: RequestBody?
    }
    let call = CreateItem(path: try EndpointPath(segments: ["items"]), body: .json(item))
    return try call.request(configuration: NetworkConfiguration(baseURL: baseURL))
}
```

An explicit accepted-status policy replaces 2xx for that call; accepting 404 permits interpreting its body but does not authorize redirects or bypass media-type/security rules. The example skips only the configured auth provider. It does not remove explicit headers or app-managed cookies/cache. JSON body content type is selected by default; an explicit header can change it without changing the encoded bytes. GET/HEAD bodies, streams and transport-managed header overrides are rejected.

`guideEncodeItem` constructs request bytes only. Endpoint.request/url and ResponseStrategy.decode/decodeResponse are local helpers; they do not execute a secured call, authenticate, enforce the whole operation budget or prove a server response trustworthy. Use APIClient for execution.

## Session ownership, cancellation and shutdown

Own and reuse one client per immutable account/environment configuration. Configuration and per-call overrides are captured values. Public client/endpoint/model/provider/sink boundaries must satisfy Swift 6 Sendable/isolation requirements; no global singleton or MainActor hop is required by the library.

<!-- DOC-EXAMPLE: ownership -->
```swift
func guideMakeOwnedClient(baseURL: URL) throws -> APIClient {
    try APIClient(configuration: NetworkConfiguration(baseURL: baseURL))
}

func guideMakeBorrowedClient(baseURL: URL) throws -> (APIClient, URLSession) {
    let settings = URLSessionConfiguration.ephemeral
    settings.httpCookieStorage = nil
    settings.httpShouldSetCookies = false
    settings.httpCookieAcceptPolicy = .never
    settings.urlCredentialStorage = nil
    settings.urlCache = nil
    settings.requestCachePolicy = .reloadIgnoringLocalCacheData
    let session = URLSession(configuration: settings)
    do {
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: baseURL), session: session)
        return (client, session)
    } catch {
        session.invalidateAndCancel()
        throw error
    }
}

func guideRunAndClose(client: any NetworkClient, id: Int) async throws -> GuideItem {
    do {
        let result = try await guideLoadItem(using: client, id: id)
        await client.shutdown()
        return result.value
    } catch {
        await client.shutdown()
        throw error
    }
}
```

The owned client uses a private strict session with automatic cookies/credentials/cache disabled. Ephemeral alone does not establish this policy. The borrowed example configures all strict settings explicitly; client shutdown cancels only the client's operations and never invalidates/clears that session. After all session users have finished, the app closes its returned session. Do not invalidate it while other work needs it.

Explicit `storage: .appManaged` on the borrowed-client initializer permits app-owned HTTPS cookie/cache settings only. Credential stores, session-global headers, delegates and background sessions remain incompatible. The app owns capacity, account separation, disk/memory choice, logout/deletion and independent session lifetime. Client shutdown is not data deletion. Provider opt-out is not a public/no-cookie profile.

`guideRunAndClose` assumes exclusive responsibility for this client's lifetime; do not call it per request on a shared long-lived client. Closing rejects future calls and joins cleanup. The same pattern closes on both success and failure; async work cannot be awaited in a normal defer. App-owned callback code must not await its own client's shutdown while that work is being joined.

Cancellation of the task awaiting send yields CancellationError when attributable to caller/shutdown. Defaults are 30-second inactivity and a 60-second monotonic total budget, including preparation/providers/transport/response handling. Explicit NetworkCallOptions override client values; URLRequest.timeoutInterval alone is not the library override. A borrowed session can impose shorter system limits. Cancellation/timeout does not roll back a server mutation, forcibly interrupt synchronous app code or guarantee an exact real-time return deadline.

## Authentication, safe errors and diagnostics

The app owns login, token storage/renewal and account selection. The provider below is actor-isolated and receives only the permitted context. Its fixed token is an example input, not a recommended token-storage design. Construct it from the app's approved credential flow; never embed a real token in source, tests or logs. Header values are validated; conflicting provider and explicit credentials fail before transport.

<!-- DOC-EXAMPLE: authentication -->
```swift
actor GuideHeaders: AuthenticationHeaderProvider {
    private let token: String
    init(token: String) { self.token = token }

    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
        try Task.checkCancellation()
        return try HTTPHeaders(["Authorization": "Bearer \(token)"])
    }
}

func guideMakeAuthenticatedClient(baseURL: URL, token: String) throws -> APIClient {
    let provider = GuideHeaders(token: token)
    let binding = NetworkAuthentication(provider: provider, account: "selected-account", environment: "production")
    return try APIClient(configuration: NetworkConfiguration(baseURL: baseURL, authentication: binding))
}

func guideSafeFailureCategory(_ error: any Error) -> String {
    if error is CancellationError { return "cancelled" }
    guard let failure = error as? NetworkError else { return "unexpected" }
    switch failure {
    case .invalidRequest: return "invalid-request"
    case .transport: return "transport"
    case .httpStatus: return "http-status"
    case .invalidResponse: return "invalid-response"
    case .encoding: return "encoding"
    case .decoding: return "decoding"
    case .timeout: return "timeout"
    }
}
```

The provider runs once within the operation's cancellation/budget and never on HTTP or another raw origin. No automatic refresh, 401/503 replay or general interceptor framework exists. Use a new explicitly scoped client/binding when account/environment changes. HTTPS/system trust is the default; no TLS override or invalid-certificate mode exists. A development loopback-HTTP option does not permit credentials, remote/LAN HTTP or weaken host-app ATS.

Catch CancellationError separately from NetworkError. `guideSafeFailureCategory` demonstrates safe category handling without formatting arbitrary underlying errors. Ordinary failures cover invalid request, transport identity, HTTP status/headers, invalid response, encoding, decoding and timeout. Native unexplained URLError.cancelled is a transport error, not automatically caller cancellation. The optional `transportFailure` accessor supplies a safe code/domain identity for transport and known system timeout; do not infer retry safety from a category or log arbitrary app error objects.

Diagnostics are disabled unless NetworkConfiguration receives a NetworkDiagnosticSink. Its synchronous nonthrowing record method must be concurrency-safe, fast and nonblocking. Only random request ID, allowlisted method, final-attempt status, total duration, library attempt count (0–2) and safe outcome reach it; raw URLs/headers/bodies/account/error descriptions are excluded. Never block the sink awaiting the same client's shutdown. Detailed public-consumer sink assertions live in PublicResponseAPITests; no external telemetry sink is included.

## Injecting a client into app tests

Inject `any NetworkClient` into app services. This small double interprets buffered fixture data through public response helpers and has no network or production-policy simulation. It intentionally does not prove APIClient security, lifecycle or native transport behavior. Use the library's separate integration/evidence plan for those claims.

<!-- DOC-EXAMPLE: testing -->
```swift
/// A buffered consumer double: no URLSession, network, retry or production-policy simulation.
struct GuideStubClient: NetworkClient {
    let data: Data
    let status: Int

    func shutdown() async {}

    func send<E: Endpoint>(_ endpoint: E) async throws -> NetworkResponse<E.Response> {
        try Task.checkCancellation()
        let response = HTTPURLResponse(url: URL(string: "https://example.invalid")!,
            statusCode: status, httpVersion: nil, headerFields: [:])!
        return try endpoint.decodeResponse(data, response: response)
    }

    func send<Value: Sendable>(_ request: URLRequest, response strategy: ResponseStrategy<Value>,
                               options: NetworkCallOptions) async throws -> NetworkResponse<Value> {
        try Task.checkCancellation()
        let response = HTTPURLResponse(url: URL(string: "https://example.invalid")!,
            statusCode: status, httpVersion: nil, headerFields: [:])!
        return try strategy.decode(data, response: response, acceptedStatuses: options.acceptedStatuses)
    }
}
```

The guide tests exercise successful typed decoding/metadata, path/query construction, formats and explicit status, JSON body construction, owned/borrowed client closure and all documented error categories. An app can add its own scenarios without receiving the internal transport/clock seams or shipping an extra testing product.

## Resource use

Reuse a client per compatible account/origin context. Responses are buffered; the library has no response-size cap or task-queue limiter. Keep app concurrency, expected payload size and retained results bounded. Initial local evaluation measured up to eight calls with expected 1 MiB responses; this is provisional workload guidance, not an enforced memory ceiling or a device guarantee. An oversized response can exceed that expectation.

RES-01 attributes the observed local trend to runtime sleep-helper/dispatch retention that outlives logical cancellation until original deadlines pass. RSS can remain high after live allocations are released; no leak-free or stable long-run memory claim follows from tests or shutdown. Consider request rate and total budget as well as concurrency, and avoid unnecessarily large timeout overrides. Re-evaluate actual resource behavior on target devices before release acceptance.

## Delivery limits

DocC and compiled examples establish current API usability on selected build/runtime destinations. They do not replace full security/privacy review, actual minimum-OS/native trust/physical-device results, resource measurements or release authorization. The repository's API review and contract-evidence ledger identify the remaining gate owners. Per-call bounded read retry is opt-in under ADR-0014; cache/transfer/WebSocket/advanced TLS features remain excluded.

## Opt-in read retry

NetworkCallOptions.retry defaults to disabled. Select oneRetryForSafeReads only for bodyless GET/HEAD calls whose server semantics permit replay; an enabled policy on another method/body is invalid configuration before authentication or networking. At most one new library attempt is allowed for otherwise-unaccepted 429/503 or exact URL connection-lost/cannot-connect-to-host errors. Accepted statuses are decoded normally. No retry for timeout, DNS/offline/TLS, authentication, decoding or cancellation.

The initial call and retry share the original total budget, prepared request/auth binding and session. Waiting uses 250–500 ms jitter, respecting a valid Retry-After up to 30 seconds without shortening it; malformed/ambiguous/oversized hints or insufficient remaining budget preserve the current failure. Cancellation and shutdown interrupt waiting. No token refresh or provider repeat occurs; one-use signatures must keep retry disabled. Retries restart at the original target with normal per-attempt redirect security. Redirects and Foundation's internal wire attempts do not increment the library counter.

Foundation can normalize response headers before delivery. The library rejects duplicate/combined retry hints still visible through that boundary, but cannot reconstruct discarded wire fields. App-managed cookie/cache state is not frozen wire state. Native retry/resource/minimum-platform acceptance and publication remain separate gates.
