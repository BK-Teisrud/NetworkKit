# Buffered response strategies and HTTP status validation

I10 update: the public `APIClient` now connects both request inputs to this shared foundation.
See [HTTP pipeline](HTTP_PIPELINE.md) for current signatures, verification boundaries and
remaining timing/lifecycle gates. Earlier task descriptions below retain their historical scope.

I07 / #48, 2026-10-21. This is local interpretation of an already buffered response.
The executing client, URLSession adapter, redirect/security enforcement, total deadlines,
and cancellation arbitration remain later work. No network request is sent by this API.

## Public API and shared boundary

`ResponseStrategy<Value: Sendable>` selects `.json(Model.self, options:)`, `.data`,
`.text`, or `.empty`. JSON additionally requires Decodable. Its public
`decode(_:response:acceptedStatuses:)` returns `NetworkResponse<Value>` and can be
used with buffered data and URLResponse. It confirms HTTP response/status/headers,
checks the accepted status, applies the selected content/decoding contract, then returns
value/status/headers. It never infers a model from a status or performs networking.

`Endpoint` requires `responseStrategy: ResponseStrategy<Response>`. An endpoint whose
Response is EmptyResponse inherits `.empty`; other endpoints select their strategy
explicitly. `decodeResponse(_:response:)` delegates to the same boundary with
`options.acceptedStatuses`. No public client or raw-request executor is introduced.

```swift
struct Item: Decodable, Sendable { let name: String }
struct ItemEndpoint: Endpoint {
    let path: EndpointPath
    let responseStrategy: ResponseStrategy<Item> = .json()
    let options = NetworkCallOptions.default
}
```

`HTTPStatusPolicy.successful` accepts 200...299. An explicit nonempty `codes: Set<Int>`
or bounded `range: ClosedRange<Int>` replaces that default, and every code must be
100...599. Invalid policies throw invalidRequest(.invalidConfiguration) before a call.
Bounds are validated before range expansion, including extremely large input ranges.
There is no global accept-all switch. Accepted status never bypasses decoding rules.
NetworkCallOptions, ConfigurationSnapshot, and both typed/raw PreparedRequest values
retain the immutable policy; I10 must use it when connecting the executing pipeline.

## Body contracts

| Strategy | Behavior |
| --- | --- |
| JSON | New Apple JSONDecoder per decode; absent Content-Type allowed; a supplied declaration must be application/json or a nonempty +json subtype, case-insensitively; malformed declarations fail invalidResponse(.unexpectedContentType) before model decoding |
| Data | Exact bytes, including zero bytes; no media-type constraint |
| Text | Strict UTF-8, including empty text; absent charset defaults to UTF-8; supplied charset must be utf-8 (case-insensitive, optionally quoted); unsupported/empty/duplicate/malformed declarations or invalid UTF-8 fail decoding |
| Empty | Explicit EmptyResponse; does not decode or inspect the body/Content-Type; still validates HTTP metadata/status and returns headers |

204/HEAD-style no-body results use the explicit empty strategy. JSON selected for an
empty 204 response fails decoding; no default model is manufactured. Empty Data/text
are valid. The empty strategy intentionally ignores any received payload.

The media declaration parser handles token parameters and quoted/escaped values,
including semicolons inside quoted strings. It rejects ambiguous duplicate parameters,
comma-separated media declarations, unterminated strings, and trailing garbage. Text
has no MIME-family restriction: its contract is the selected UTF-8 interpretation.
JSON uses Apple's parser/encoding behavior and does not add a text transcoding layer.

`JSONDecodingOptions` contains immutable choices for dates (deferredToDate, secondsSince1970,
millisecondsSince1970, iso8601), keys (default or convertFromSnakeCase), Data (base64
or deferredToData), and floats (throw or explicit infinity/NaN strings). Defaults match
Apple JSONDecoder. No shared decoder, formatter, userInfo, or custom codec factory is
exposed. Application Decodable implementations must obey Sendable semantics and protect
shared state. Native date strategy details remain Apple's behavior, not a new parser.

## Errors, cancellation, and privacy

Non-HTTP responses and invalid status codes fail invalidResponse. Invalid exposed
headers fail invalidResponse(.invalidHeaders), rather than reporting a request error.
Headers preserve the values Foundation exposes, with HTTPHeaders case-insensitive
lookup; raw wire ordering/casing/duplicate preservation is not promised.

An unaccepted status fails httpStatus(status, headers:) before content/model decoding.
It retains no response body or URL. Malformed/empty/model-mismatched JSON, invalid text,
and arbitrary errors from app decoding hooks become fixed NetworkError.decoding.
CancellationError remains separate. Task cancellation is checked before processing,
after synchronous decoding, and when normalizing decoding errors. Synchronous custom
Decodable code cannot be forcibly interrupted. Total-timeout versus cancellation races
remain I12/I13 work, not something this local decoder resolves.

Descriptions of strategies/options/responses/errors exclude payloads, float strings,
header values, and URLs. Explicitly accessed metadata/value properties can be sensitive;
their accessibility is not permission to log them.

## Verification

The local suite passes 84 test functions in 14 suites, on the existing macOS/Xcode/Swift
baseline. New tests cover media declarations, UTF-8, JSON options/null/empty/malformed
bodies, Data/empty results, status precedence/exceptions, metadata, sanitized failures,
pre/post-decoding cancellation, 40 concurrent independent decoders, typed/raw policy
snapshots, and a public API consumer importing NetworkKit without @testable.

Actual PR and main CI results are recorded on [issue #48](https://github.com/BK-Teisrud/NetworkKit/issues/48)
before completion. Local success is not minimum-OS or physical-device evidence.

Primary references reviewed: [Apple JSONDecoder](https://developer.apple.com/documentation/foundation/jsondecoder),
[Apple date strategy](https://developer.apple.com/documentation/foundation/jsondecoder/datedecodingstrategy-swift.property),
and [RFC 6839 structured syntax suffixes](https://www.rfc-editor.org/info/rfc6839/).
