# Optional sanitized diagnostics

I15 / [#56](https://github.com/BK-Teisrud/NetworkKit/issues/56), 2026-10-22.
APIClient now supports a local app-owned sink through the immutable
`NetworkConfiguration.diagnostics: (any NetworkDiagnosticSink)?` setting.
It defaults to nil (disabled). There is no automatic stdout/OS log, file write,
remote endpoint, analytics, telemetry, queue, background task or additional dependency.

## Public boundary and fixed allowlist

```swift
final class AppDiagnostics: NetworkDiagnosticSink {
    func record(_ event: NetworkDiagnosticEvent) {
        // Consume only this already-sanitized value using a concurrency-safe,
        // fast, nonblocking local receiver. No request/response hook is available.
    }
}

let configuration = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    diagnostics: AppDiagnostics())
// Omit diagnostics (or pass nil) to disable it for a client.
```

NetworkDiagnosticSink is Sendable, synchronous and nonthrowing. Its only input is the
library-constructed NetworkDiagnosticEvent with these six fields:

| Field | Meaning and bound |
| --- | --- |
| requestID | A new random UUID for each logical send, including rejected admission; shared with AuthenticationContext for the original operation |
| method | GET, HEAD, POST, PUT, PATCH, DELETE or OPTIONS by exact prepared spelling; every other method is `custom`; nil if preparation never completed |
| status | Validated HTTPStatus from the final started attempt if transport returned an HTTP response; nil for absent/non-HTTP/invalid status, even when a thrown error contains other metadata |
| duration | Nonnegative finite monotonic seconds from call entry through joined worker/watchdog/provider cleanup, excluding sink recording |
| attemptCount | Actual library transport invocations: 0 before networking, 1 for the initial attempt, 2 only after the retry starts; redirects/OS wire attempts are excluded |
| outcome | Closed safe category: success, invalid-request reason, transport, HTTP-status failure, invalid-response reason, encoding, decoding, timeout reason, cancellation cause or other |

No hostname, origin, path, query, fragment, full URL, header name/value, payload, account,
environment, model description, raw custom method, raw error object/body, localized
error text, transport domain or arbitrary string is an event field. Classification
never calls app error formatting. TRACE and other methods outside the seven-method
allowlist are custom. HTTPStatus is metadata actually received before decoding:
a decoding/status failure may include it, and an interruption may have raced a response.
It is not a promise of a delivered/decoded successful result.

App-managed sinks receive precisely this same value, not a privileged raw hook. Default
String(describing:)/String(reflecting:) of the event contains only these safe values.
NetworkError descriptions remain sanitized; explicitly accessible response/error headers
and transport identity are still app data and are not thereby safe to log. An app can
leak its own captured state or join UUIDs with its own sensitive records; NetworkKit
cannot police that behavior or arbitrary OS/app diagnostics.

## Completion, cancellation and callback rules

One terminal event is delivered before a completed send returns/throws, after its
structured operation children have joined. Invalid preparation, pre-cancellation and
closed-client rejection also emit one event when enabled, without reading endpoint
properties again. There are no start/progress/shutdown-only event streams. A standalone
shutdown with no send emits nothing. Concurrent calls may invoke the sink concurrently;
events are not globally ordered by call start.

Cancellation remains CancellationError in the public result. Diagnostic cause records
caller or shutdown only when that cause selected the operation's terminal result.
Pre-cancelled entry is caller; a provider/transport independently throwing CancellationError
is unspecified rather than guessed to be caller/shutdown. The first selected result
and cause survive later cancellation/shutdown/cleanup. Timeout remains its own reason;
ordinary system cancellation without actual task cancellation remains transport failure.
No raw error is retained in an event.

Recording happens outside library locks and after result selection, using a nonthrowing
callback. No sink error channel, detached delivery or timeout/cancellation reinterpretation
is introduced. Sink latency cannot retroactively change the selected result or event's
measured duration; it does add wall time before send returns, and an admitted send remains
registered until the callback returns. Keep sinks fast/nonblocking and concurrency-safe.
A sink must not block waiting for this client's shutdown or another dependent operation,
mutate app state unsafely, or retain a client in a cycle. Host callbacks that block, crash,
perform I/O, spawn tasks or alter external state are app-owned behavior, not isolated
by the library. There is no hard latency guarantee, secure memory erasure or guarantee
against process termination during recording. No event retry/buffer/persistence is added.

The sink defaults to nil. Enabled/disabled configurations preserve request preparation,
transport/decode results and existing typed error semantics. The monotonic request
budget still covers preparation/provider/transport/decoding; selected operation results
are unchanged by observing them. Diagnostic duration additionally includes joined cleanup.
Use the existing [timing](CANCELLATION_AND_BUDGET.md), [shutdown](SHUTDOWN_AND_CONCURRENCY.md)
and [provider](AUTHENTICATION_PROVIDER.md) guides for cooperative cleanup limits.

## Actual verification and limits

Local Swift warnings-as-errors: **200 test functions / 23 suites passed**. Thirteen
new diagnostic-suite functions with parameterized cases cover:

- Canary secrets in hostname/path/query, custom method, headers/cookies, request/response
  bodies, provider account/environment/output/errors, NSError domain/userInfo/text,
  Encodable/Decodable failures, invalid requests and non-HTTP responses. Default event
  descriptions/reflection and returned error descriptions exclude the canary.
- Exactly the six allowlisted event fields; exact standard/custom method classification;
  observed status on success/status/decode failure and no invented status otherwise.
- Enabled/disabled request/result parity and no extra endpoint property/description reads.
- Pre-cancellation and closed admission; caller/shutdown/unspecified cancellation, both
  cancellation/shutdown orders, preserving selected success/error during late cancellation.
- Total/system/provider-signalled timeouts; held cleanup emits no early event, measures
  nine exact clock seconds, and leaves no pending clock work. A deliberately slow sink
  advances time beyond the budget without rewriting success or measured duration.
- Thirty-two concurrent calls across two accounts, unique IDs correlated to provider
  context, one terminal event each and no account/credential values in the event.
- Unknown app errors classified as other without evaluating their description/localization.

The external consumer test imports NetworkKit without @testable. macOS/iOS/tvOS use
native URLSession/URLProtocol with a canary HTTP error body/cookie and verify enabled/
disabled behavior and sanitized error/event values. watchOS checks public configuration
and closed-admission reporting; deterministic internal transport tests exercise the full
diagnostic contract. Unsupported interception is not native watch networking evidence.
Existing platform/security/cancellation tests remain in the complete suite. This does
not complete minimum-OS/physical-device, consolidated TLS/privacy/storage or release gates.
No dependency, workflow, rule, paid service, tag, release or F3–F6 feature is added.
Issue #56 records exact PR/main commits and five-runtime results before completed closure.

Negative control: an isolated source copy added a rawURL event field and copied the
prepared request URL into it. The selected canary test built successfully, then failed
57 assertions across 11 cases, detecting canary/HTTPS leakage and the extra field.
Repository source was unchanged by this control.

## I25 diagnostic addition — 2026-11-01

The approved retry contract adds only attemptCount to the existing terminal event. Status is cleared at each actual transport invocation, so a second-attempt transport failure cannot expose the first attempt's HTTP status as final-attempt metadata. One request ID, duration, cancellation cause and terminal outcome cover the entire admitted operation and joined cleanup. No retry reason, extra event stream or response history is added. Earlier dated evidence describes its original schema; new PR/main acceptance is required for this addition.
