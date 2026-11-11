# F6 security API design candidate

Working candidate, 2026-11-09, #90 / PR #177. Method/type names and semantics below are proposals for review, not approved or compiled production declarations. Preserve every existing public signature and protocol requirement. Nothing in this document authorizes code or native execution.

## Pinning decision

The owner approved SDK pinning based on SHA-256 of the complete DER leaf certificate, with a distinct backup pin and retained system trust. App-owned ATS SPKI pinning remains a supported configuration/design path to assess; dynamic SDK SPKI pinning stays a visible unselected extension. These formats are explicitly different. Certificate renewal changes the DER digest even when the public key is unchanged, so deploy overlapping current/backup certificate pins before renewal. This does not close the full original pinning catalog.

Proposed CertificatePin value: exactly 32 digest bytes, throwing initializer `init(leafCertificateSHA256: Data) throws`; canonical base64 import/export may be added only with strict decoding and length validation. Proposed CertificatePinSet: `init(origin: NetworkOrigin, pins: Set<CertificatePin>) throws`; exact HTTPS origin only, at least two distinct values, at most eight values. Pins match the leaf only; intermediate/root pins are not implicitly accepted. No key/certificate import, fetching or parsing by custom ASN.1 code.

System trust (including hostname and the host app's platform policy) must pass before a pin can authorize delivery. Retain OS trust evaluation context and do not replace anchors, verification date, exception data or hostname policy. Native proof must check that manual handling cannot weaken app ATS pin restrictions. Matching a pin never compensates for a failed trust result. Trust evaluation can involve system network activity; do not classify it as an offline pure function or run a synchronous evaluation on the main actor. Deadline/cancellation closes logical admission and discards late trust callbacks, without promising to stop all OS trust work immediately.

## Client identity: Foundation-native Sendable carrier

Proposed context ClientIdentityContext is an immutable Sendable value containing origin, setupID (UUID), account and environment only, with redacted descriptions. No path/query/body, complete challenge object or server-controlled issuer names are exposed to the provider in the initial design.

Proposed protocol `ClientIdentityProvider: Sendable` has `func credential(for context: ClientIdentityContext) async throws -> URLCredential`. Foundation URLCredential is marked NS_SWIFT_SENDABLE in the inspected SDK header and listed as Sendable in Apple's API documentation. This is a source-supported design direction, not an additional Phase A compiler test. Do not create a custom unchecked wrapper around raw SecIdentity/SecCertificate merely for concurrency.

Resolve the provider once during asynchronous secure-client construction, before opening a session or sending requests. Retain only a validated immutable URLCredential carrier: identity must be present, persistence must be .none and any certificate-chain elements must be SecCertificate references in the documented order. Reject password/server-trust credentials, incompatible persistence, malformed chain and nil/mismatched identity. Never inspect the password property or serialize credential debugDescription. The app constructs/owns the underlying identity and permissions; the SDK does not import PKCS#12, enroll, create, delete or export it.

Initial secure client factory proposal: `APIClient.make(configuration: NetworkConfiguration, tls: NetworkTLSConfiguration, identity: (any ClientIdentityProvider)?, setupTimeout: TimeInterval = 10) async throws -> APIClient`. Existing synchronous initializers stay unchanged. Timeout must be finite, positive and at most 86400 seconds. Setup uses its own bounded monotonic budget before a client exists; each later request retains the existing request budget. Cancelled setup does not return or open a session. Late noncooperative provider output is discarded; its task may outlive logical termination, as in existing provider boundaries.

A ready client owns a fresh store-free session and one immutable origin/account/identity binding. TLS resumption/session reuse never moves to another binding. Rotation creates a new client/session; old clients are shut down by the app. No request-level identity provider or automatic refresh. Challenges verify exact host/scheme/port and previous-failure state; supply the resolved credential only on an admitted matching client-certificate challenge. Unknown/repeated/proxy/cross-origin challenges fail closed. Exactly-once handler resolution is required even with timeout/shutdown/late callback. No shared URLCredentialStorage fallback.

NetworkTLSConfiguration proposal: exact origin plus optional CertificatePinSet and supported minimum TLS version (system default, TLS 1.2 or TLS 1.3; never below existing system policy). Configuration must not claim cipher/ALPN control where Foundation does not provide it. Default remains system trust and no client certificate. The new factory rejects a TLS origin different from the client's base origin. SDK-managed pinning/mTLS remains unavailable on injected sessions; no silent policy omission. Existing injected session behavior without new policy remains unchanged.

First candidate operation coverage: typed/raw HTTP and file downloads on that secure APIClient; separately configured owned WebSocket session after equivalent proof. Native TLS clients use the same immutable credential carrier only if their own sec_identity bridge/verification integration passes. These are proposed coverage gates, not established cross-transport compatibility or an owner-approved omission.

## Request signing

Proposed SigningContext: immutable origin/requestID/account/environment; no old AuthenticationContext expansion. Proposed `RequestSigningKey: Sendable` has read-only `keyID: String` and `func authenticate(_ signatureBase: Data) async throws -> Data`. Proposed `RequestSigningProvider: Sendable` has `func key(for context: SigningContext) async throws -> any RequestSigningKey`. The returned handle must permanently bind its keyID and key for that logical call. Changing app key selection produces another handle, never a mutable shared keyID/property race.

Proposed RequestSigning binding contains exact origin/account/environment, provider and mandatory maximumBodyBytes; app identity/header binding must agree. Add a new NetworkConfiguration initializer overload with an explicitly labelled signing argument while retaining all old overloads and initializer-as-function compatibility. Signing is disabled unless configured. The immutable key handle accepts SDK-assembled canonical bytes, not a URLRequest it can mutate. Reject an invalid key identifier or a MAC not exactly 32 bytes. Provider work and HMAC authentication remain inside the original request total budget.

Use [the proposed profile](F6_SIGNING_PROFILE.md) for wire rules and verifier requirements. Further transport mutation/duplicate-field/encoding restrictions must be explicit before final API approval. Signer secrecy depends on the app/provider; the SDK does not expose raw keys or build a vault. No nonce cache or verification service is added to the client. Reject retry selection for signed calls and refuse all redirects. Existing ordinary calls preserve current behavior.

## Proposed errors and diagnostic boundary

Keep NetworkError unchanged for ordinary operations; exact integration for opted-in security errors needs a compatibility decision. Candidate separate SecurityPolicyError categories: invalidConfiguration, unsupportedSession, originMismatch, trustRejected, pinMismatch, invalidCredential, identityUnavailable, providerFailure, invalidSignatureInput and invalidMAC. Security setup timeout and CancellationError remain distinct. Never publish raw provider errors, key IDs, cert subject chains, URLCredential values or trust CFError userInfo. HTTP diagnostic event shape must not silently gain sensitive error payloads; use the existing redacted fallback until an additive event contract is approved.

## Source findings and remaining proof

Apple's [URLCredential API](https://developer.apple.com/documentation/foundation/urlcredential) documents the client-identity carrier; the local NSURLCredential.h Sendable annotation supports the proposed async boundary. [SecIdentityCreate](https://developer.apple.com/documentation/security/secidentitycreate(_:_:_:)) can associate an existing in-memory key and certificate; this is a possible isolated fixture path, not authority to create keys. [Trust evaluation](https://developer.apple.com/documentation/security/sectrustevaluatewitherror(_:_:)) may perform system work beyond the caller, so native callbacks need bounded logical ownership.

No new compiler or test slot was consumed for these proposals. Still required: actual credential validation and cross-SDK Sendable signatures, certificate-chain semantics, exactly-once challenge completion, correct app ATS interaction, native identity/resumption isolation, same-wire signing verification and owner acceptance of exact public API/defaults/coverage.


## Mac source-specific follow-up

The [Mac experiment](F6_MAC_FEASIBILITY_RESULTS_2026-11-09.md) exercised the Foundation carrier and in-memory fixture identity successfully. That narrows the feasibility gap without approving this public API. It also retains I04 native error-oracle failure and identifies incomplete late-challenge terminal gating; production security code must not copy the toy delegate. No additional compilation/native attempt is authorized.


The subsequent [#178 correction](F6_TLS_CORRECTION_RESULTS_2026-11-09.md) verifies the selected terminal gate and I04 controls in the experiment. This narrows those source-specific gaps, not exact public API/production/platform acceptance.
