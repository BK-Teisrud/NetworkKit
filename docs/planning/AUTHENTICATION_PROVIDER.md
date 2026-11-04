# Bounded authentication-header provider

I14 / [#55](https://github.com/BK-Teisrud/NetworkKit/issues/55), 2026-10-22.
Both APIClient send paths now support the approved asynchronous header boundary.
This is not an OAuth, Keychain, token-refresh, login or retry implementation.

## Public API and account binding

An app supplies an `AuthenticationHeaderProvider: Sendable` with
`func headers(for: AuthenticationContext) async throws -> HTTPHeaders`.
Use an actor or another concurrency-safe implementation. NetworkKit does not serialize
calls to the provider: independent operations may overlap.

```swift
actor AppAuthentication: AuthenticationHeaderProvider {
    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
        // The app looks up its current token for context.account/environment.
        // Do not call this same client's shutdown from inside the provider.
        return try HTTPHeaders(["Authorization": "Bearer app-managed-token"])
    }
}

let configuration = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    authentication: NetworkAuthentication(
        provider: AppAuthentication(), account: "account-A", environment: "production"))
let client = try APIClient(configuration: configuration)
```

`NetworkAuthentication` is an immutable binding to the client's normalized base origin.
Account/environment are opaque optional app identifiers, never inferred from headers,
URLs or system stores. Apps must choose them correctly; nil is an explicit absence of
an identifier, not an account discovery mechanism. Use separate bindings/clients for
accounts or environments. A shared actor may serve them using the supplied context.
The provider's own token state is app-owned and may change safely between operations;
NetworkKit does not copy, cache or refresh it.

Context contains only normalized origin, a new UUID for this original operation, HTTP
method, account and environment. It has no path/query/full URL, request headers, body,
response or general client reference. Identifiers and header values are accessible
explicitly; default descriptions expose none of them. This does not prevent intentional
app logging, reflection of app-owned state or OS diagnostics.

## Invocation, origin and precedence

1. Prepare and validate the original typed/raw request first. Invalid requests never
   invoke the provider. Request construction via `Endpoint.request` stays synchronous
   and does not invoke authentication; execute through APIClient to apply the provider.
2. Unless disabled, invoke the configured provider once for an HTTPS request at the
   client's normalized base origin, including the effective port. A configured provider
   on same-origin HTTP fails with `invalidRequest(.credentialsOverHTTP)` without invoking
   it, even for permitted loopback HTTP.
3. Additional permitted raw origins do not inherit any client default headers or the
   client's provider, regardless of the provider's custom header names. Raw destination
   permission is not permission to share this binding's credentials. To authenticate a
   different service, configure a client with that service as its base origin. Explicit
   raw/call headers remain deliberate caller inputs scoped by the app to their request;
   NetworkKit cannot classify arbitrary values as secrets.
4. Existing client defaults < raw headers < call headers precedence remains. Typed
   calls use defaults < call headers. Provider-returned fields are treated as credentials:
   any collision with a prepared field must have identical UTF-8 value bytes, otherwise
   fail with `invalidRequest(.conflictingHeaders)` before transport. This conservative
   rule also covers collisions with client defaults and custom credential names. No
   provider field silently replaces an explicit/default value or vice versa.
5. HTTPHeaders validates ASCII names, unsafe controls/CRLF and conflicting normalized
   duplicates. Provider fields also reject Host, Content-Length and Transfer-Encoding;
   the combined request is security-validated again before transport.

Choose `NetworkCallOptions(authentication: .disabled)` for a public/no-provider call.
This skips only the provider, leaving default and explicit headers in place; it neither
clears credentials nor disables HTTPS/header/origin validation. In particular, explicit
credential headers remain forbidden on loopback HTTP. Construct a separate credential-
free client or omit those headers when that is the intended public-call boundary.

Provider credentials are part of the original request only. Existing per-task redirect
rules permit bounded same-origin GET/HEAD redirects and reject cross-origin movement,
HTTPS downgrade and mutating replay. The provider is never called again for a redirect
or a 401/status failure. URLSession may perform its own internal connection handling;
no single-wire-event claim is made.

## Error, cancellation and lifecycle behavior

Ordinary provider errors, including errors thrown while constructing its HTTPHeaders,
become `invalidRequest(.authenticationProviderFailure)` without retaining raw error text,
underlying error, headers or token values. CancellationError remains separate and a
provider-thrown NetworkError.timeout retains its timeout category. This is an app signal,
not independent proof that a system timer expired. The operation's already selected
terminal result remains authoritative, including actual total-budget expiry/shutdown.

Provider execution is a structured part of the original operation and consumes the same
monotonic total budget, captured at call entry. Checkpoints run before/after provider
execution and before I/O. Caller cancellation, timeout or shutdown cancels and joins the
worker, including provider cleanup. A provider returning credentials after cancellation
cannot proceed to transport. No detached provider task, background refresh or replay is
created. One operation cancelling never cancels another account's provider task.

Cancellation is cooperative: uncooperative provider work/cleanup can delay call return
and shutdown. Initiate shutdown outside work being joined; a provider must not await its
own client's shutdown or create a client/provider retain cycle. No hard interruption,
secure memory erasure or instant logout of other active operations is promised. The app
owns login, storage, logout, renewal and account revocation policy.

## Actual verification and limits

Local warnings-as-errors suite: **186 test functions / 22 suites passed**. Fifteen
provider-suite functions (with parameterized cases) cover both input paths/minimal
context, default/raw/call collisions and identical/Unicode-byte values, malformed and
transport-managed fields, HTTP rejection, additional host/port/HTTP origins, opt-out,
normalized errors, caller cancellation/total timeout/shutdown during held cleanup,
32 overlapping calls across two accounts, cancellation isolated between accounts, unique identifiers, no 401/302/503 replay,
safe descriptions, pre-cancel/invalid-request non-invocation and redirect denial.

Public API tests import NetworkKit without @testable. macOS/iOS/tvOS verify that native
URLSession/URLProtocol receives provider headers through a compatible borrowed session.
watchOS checks public construction/HTTP rejection and uses deterministic internal
transport tests for provider behavior; unsupported URLProtocol interception is not native
watch networking evidence. The credential-bearing redirect case invokes the actual task
delegate with scripted I/O on every platform; it does not prove a native HTTPS handshake.
Existing native macOS local-server redirect tests remain green, without credentials on
HTTP. Minimum-OS, physical devices, consolidated TLS/privacy/storage and release gates
remain outstanding. No dependency, workflow, rule, paid service, release or F3–F6 feature
is added. Issue #55 records exact PR/main commits and five-runtime results before closure.

Negative control: an isolated source copy removed credential-conflict rejection. The
selected test built successfully, then default/raw/call/Unicode-conflict cases produced
eight failed assertions (unexpected success and transport access). The identical-value
case remained permitted. Repository source was unchanged by this control.
