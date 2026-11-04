# I02 HTTP values and error API review

Date: 2026-10-20. Issue: [I02 / #43](https://github.com/BK-Teisrud/NetworkKit/issues/43). This implements the foundational value layer of ADR-0005, not the HTTP client or response pipeline.

## Public API and rationale

| Type | Implemented contract |
| --- | --- |
| HTTPMethod | Immutable, Sendable, Hashable method token; throwing custom initializer, exact case preserved, seven standard constants |
| HTTPHeaders | Immutable Sendable dictionary snapshot, lowercase ASCII names, case-insensitive lookup, explicit raw-value access, safe default descriptions |
| HTTPStatus | Immutable Sendable/Hashable code in 100...599; isSuccessful classifies 200...299 without overriding future per-call status policy |
| NetworkResponse<Value: Sendable> | Immutable value/status/headers; conditional Equatable; descriptions omit payload and header contents |
| EmptyResponse | Explicit empty marker, Sendable/Hashable; no Codable conformance or implicit JSON decoding |
| NetworkError | Typed request/transport/status/response/coding/timeout categories, Sendable/Equatable, safe localized/default/debug descriptions |
| NetworkError.TransportFailure | Domain/code identity only, with a URLError initializer that discards userInfo and localized text |

Request values at this stage are method and header components. No full request container, Endpoint, NetworkClient, APIClient, URL builder, configuration policy, serializer, or transport is introduced. Those belong to subsequent tasks; this avoids publishing speculative signatures before their implementations.

Throwing initializers prevent malformed methods, field names, unsafe field controls, conflicting duplicate values, and invalid status integers from entering these values. Neither HTTPMethod nor HTTPStatus offers an unchecked public initializer. All stored public properties are let values; no unchecked Sendable or external package is used. The response wrapper does not deep-copy arbitrary app payloads; their own Sendable/value semantics govern nested state.

## Header semantics

Lookup first validates the ASCII name, preventing Unicode lookalikes from aliasing ASCII fields. Equal case-insensitive duplicates collapse; differing values are rejected. Field values compare by UTF-8 bytes, so Swift's Unicode-equivalent String equality does not silently combine different opaque data. Validation order is deterministic by input name.

Values are not split, joined, trimmed, or otherwise rewritten. Tabs, visible text, empty values, and opaque non-ASCII text are retained; unsafe ASCII controls, including CR/LF/NUL/DEL, are rejected. This is a value container with token/control validation, not a complete parser for every field grammar or a promise about URLSession's final wire encoding. Field names are canonicalized and original name casing/order is not retained. URLSession response adaptation remains future work.

The `fields` property and subscript deliberately expose values to the app. They are not safe logging APIs. Default description/debugDescription disclose only field count; response descriptions contain status and count, not the decoded model's description. Explicit reflection/dumps of storage and application logging outside these descriptions are not a security sandbox. Future logging still uses the stricter event allowlist from ADR-0007, not arbitrary object descriptions.

## Error and cancellation boundary

NetworkError distinguishes invalidRequest(reason), transport(identity), httpStatus(status, headers), invalidResponse(reason), encoding, decoding, and timeout(reason). Fixed reason enums avoid raw server/provider text. Coding errors intentionally retain no arbitrary underlying Error or coding path, which could contain sensitive data. Revisit necessary safe coding context during I05/I07 rather than capturing error objects by default.

HTTP status errors retain status and explicit header metadata but no body. Transport errors retain machine-readable domain/code; descriptions omit the domain because even custom domains can contain app data. The underlying error and its userInfo are not retained.

Timeout reasons distinguish inactivity, total budget, and system timeout. These are value categories, not an implemented timer or error normalizer. CancellationError remains Swift's separate error; there is no cancellation case in NetworkError. Mapping URLError.cancelled, shutdown, or timeout requires actual operation context in I12/I13; these value types do not infer that context or implement cancellation.

## API and platform checks

Reviewed the local SDK 26.2 Foundation Swift interface for URLError and its code access. Its base availability annotation is macOS 10.10 / iOS 8 / watchOS 2 / tvOS 9, within the approved minimums. Other stored values use Swift standard-library String/Int/Dictionary and Sendable protocols under Swift 6. The library imports Foundation only for transport identity and LocalizedError. Test-only Data/URLError usage does not add a product dependency.

Compilation verifies the public types with Swift 6 strict concurrency. Test code uses public import NetworkKit, without @testable, and transfers response/method/error values through a task boundary. This is a Sendable/API check, not proof of the later client's concurrency or lifecycle behavior. Only local macOS execution is verified; cross-platform builds and minimum-runtime evidence remain outstanding.

Protocol references reviewed for the chosen validation rules: [RFC 9110 tokens](https://www.rfc-editor.org/rfc/rfc9110.html#section-5.6.2), [field values](https://www.rfc-editor.org/rfc/rfc9110.html#section-5.5), and [status codes](https://www.rfc-editor.org/rfc/rfc9110.html#section-15). These rules guide the independent implementation; no external parser or package is included.

## Actual verification

- `swift test`: 21 tests in five Swift Testing suites passed on Xcode 26.3 (17C529), Swift 6.2.4, macOS 15.8.1 x86_64 / SDK 26.2.
- HTTPMethodTests covers standard/custom methods, exact case, all 128 ASCII characters, malformed/non-ASCII input, and custom-method redaction.
- HTTPHeadersTests covers lookup, duplicates/conflicts, malformed names, control bytes, Unicode aliases, exact opaque bytes, snapshot independence, and safe descriptions.
- HTTPStatusTests checks every integer in 100...599, 2xx boundaries, unregistered valid codes, and invalid/extreme integers.
- NetworkResponseTests covers Data/text/empty values, metadata, conditional equality, snapshots, payload redaction, and Sendable transfers.
- NetworkErrorTests covers transport code retention without userInfo, explicit HTTP metadata, all top-level categories, timeout distinctions, safe default/debug/localized descriptions, and separate CancellationError.
- Isolated negative control: replacing case-insensitive lookup with case-sensitive lookup caused the header suite to fail as expected. The repository source was not modified by this experiment.
- A separate temporary consumer resolves the local NetworkKit product, constructs the public values, links, and executes without networking.

No URLSession calls, JSON coding, actual timeout/cancellation, header layering, status-acceptance overrides, CI workflows, or releases are implemented by I02. I03 follows with configuration snapshots and internal test boundaries.
