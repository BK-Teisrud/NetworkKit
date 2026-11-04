# ADR-0005: HTTP, response, and error contract in v1

Date: 2026-10-19. Status: Core choices accepted by the owner; documented defaults elaborate those choices.
Issue: [DEC-04 / #4](https://github.com/BK-Teisrud/NetworkKit/issues/4).

## Approval and context

The owner selected:

1. Typed endpoints by default, with raw URLRequest support under the same client policies.
2. The decoded value together with HTTP status and response headers.
3. JSON, raw Data/text, and explicitly empty responses in v1; streaming and multipart are deferred.
4. Structured errors with a separate CancellationError.
5. HTTP 200–299 by default, with explicit per-call exceptions.

[HTTP_API_CONTRACT.md](../planning/HTTP_API_CONTRACT.md) elaborates these choices, including URL, header, body, and validation rules. No Swift code or public symbol implementation has been created.

## Decision

One HTTP client contract serves typed endpoints and raw requests. The planned public concepts are an injectable NetworkClient boundary, a concrete APIClient, Endpoint with an associated response type, NetworkResponse, and NetworkError. NetworkConfiguration, HTTPMethod, and an explicit EmptyResponse are part of the contract model. Exact Swift signatures will be designed during implementation and reviewed against these contracts; this ADR contains no code sketch.

Choose the response strategy explicitly: JSON, Data, text, or empty. This prevents Data/String from unintentionally passing through JSON decoding merely because they also conform to Codable. A raw request is an input mechanism, not a bypass of status, decoding, authentication, redirect, or cancellation rules.

CancellationError is separate control flow and is not wrapped as an ordinary NetworkError. DEC-05 elaborates request timeout, total deadline, and session ownership. DEC-06 elaborates authentication, redirects, caching, and network policy; these detailed decisions cannot expand ADR-0003's scope.

## Alternatives and rationale

- Typed endpoints alone would be less flexible for unusual HTTP contracts. The owner also selected raw URLRequest.
- Returning only a decoded value would hide status and headers that consumers may need. The owner selected a response wrapper.
- JSON alone would exclude simple text, binary, and empty responses. The owner selected these variants without a general format/streaming framework.
- Combining cancellation with all other errors would make one exhaustive list possible. The owner selected a separate CancellationError.
- A fixed 2xx rule would be less configurable. Explicit local exceptions were chosen instead of a hidden global redefinition of success.

## Platform checks and evidence

The Foundation baseline was checked using public Apple sources and availability declarations in local SDK 26.2. URLSession.data(for:delegate:), URLComponents, URLQueryItem, and JSONEncoder/JSONDecoder have declared availability within the approved minimums. This is a bounded declaration check in the macOS SDK's Swift interface, not a cross-platform build or runtime result. See the platform matrix for its scope.

Test contracts cover success, status exceptions, empty responses, URL/header handling, coding failures, and cancellation. None has run; no package or tests exist. Domain epics close only upon delivery. At adoption, DEC-05–DEC-07 and the F0 gate remained open.

## Sources

- [Apple: URLSession](https://developer.apple.com/documentation/foundation/urlsession)
- [Apple: URLComponents](https://developer.apple.com/documentation/foundation/urlcomponents)
- [Apple: CancellationError](https://developer.apple.com/documentation/swift/cancellationerror)
- Local SDK: Foundation.framework/Modules/Foundation.swiftmodule/x86_64-apple-macos.swiftinterface, SDK 26.2; Xcode 26.3 (17C529).
