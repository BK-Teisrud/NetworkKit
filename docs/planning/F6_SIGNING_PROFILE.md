# F6 request-signing profile proposal

Status: proposed profile, not approved contract or implementation. Tracking #90 / PR #177, 2026-11-09. The owner selected RFC 9421 HMAC-SHA256 and RFC 9530 SHA-256 Content-Digest as the design basis. Values below are NetworkKit profile proposals, not defaults mandated by those standards.

## Profile boundary

Proposed identifier: networkkit-hmac-v1. Explicit opt-in for typed/raw HTTP calls and foreground GET downloads through APIClient. No WebSocket handshake signing, response verification, streamed/file upload signing, asymmetric signatures or server SDK is implied. Preserve these as visible non-selected profile extensions pending owner decision; do not mark the entire original signing catalog delivered from this one profile.

Only a cooperating verifier implementing this profile can accept it. The client cannot enforce server nonce storage, authorization or key revocation. App provisioning binds a unique key ID and at least 32 random key bytes to one exact HTTPS origin and account/environment. Production secret creation/storage belongs to the app; no secret is generated, persisted or printed by NetworkKit. Application-selected HMAC keys are not a Secure Enclave key type or a claim of hardware-backed signing.

## Proposed wire inputs

- Final admitted HTTPS request only, after serialization and header authentication. Reject user info, fragment, body streams and ambiguous URL/header representations before signing. Never decode/re-encode percent escapes, sort query items or silently normalize the target after it has been signed. Compare observed server reconstruction with the sender's final URL before claiming native interoperability.
- Fixed signature label sig1. Covered components, in this order: @method, @target-uri, content-digest; append content-type when present and authorization when present. This optional-presence rule is part of the profile; the verifier rejects omission of either existing field. Headers that influence application semantics beyond this set need an explicitly extended profile; the signature does not cover the entire HTTP message.
- SHA-256 over exact transmitted body bytes, including zero bytes for an absent/empty body. Set one Content-Digest member for SHA-256. The profile rejects Content-Encoding in the initial contract, rather than assuming encoded and unencoded bytes are identical. Transfer framing is not part of the body digest. Reject preexisting Signature, Signature-Input or Content-Digest from caller/default/auth fields instead of overwriting them.
- Require one logical value for each covered field. Existing HTTPHeaders cannot establish the original multiplicity of arbitrary raw Foundation input; reject observable conflicts and do not claim detection of duplicates already collapsed by Foundation. Trim/serialize using the selected RFC component rules; control characters and invalid structured values fail. Explicitly test tabs/spaces and quoted-string escaping. Do not sign Foundation-controlled Host or Content-Length as if the SDK owned their wire values.
- Fixed metadata order: created, expires, nonce, keyid, alg. Algorithm fixed to hmac-sha256. created is a whole Unix second sampled once after key acquisition; expires = created + 60 with checked arithmetic. A random nonce contains 16 bytes from the system random source encoded as unpadded base64url. Randomness failure aborts; no counter/time fallback. Test seams use fixed synthetic clock/nonce values without becoming public insecure defaults.
- keyid is a nonempty printable ASCII identifier, at most 128 bytes, escaped as a structured string; it is an identifier, never a secret. The profile permits no caller-controlled algorithm selection or extra arbitrary signature parameters. Signature-Input and Signature are emitted using structured-field syntax and the fixed label; the signature authenticates the UTF-8 signature-base bytes. No line wrapping on the actual wire.

This design uses the component/metadata model from [RFC 9421](https://www.rfc-editor.org/rfc/rfc9421.html) and the content integrity field from [RFC 9530](https://www.rfc-editor.org/rfc/rfc9530.html). The selected profile and interoperability checks are NetworkKit decisions; no general RFC implementation or response-authenticity guarantee is claimed.

## Proposed verifier rules

The native experiment verifier has its own canonical assembly/parser in Python, separate from the Swift/CryptoKit signer. Offline Phase A used Python standard-library primitives on both paths and did not meet that cross-language/primitive separation goal. It must not import or call the Swift signer's canonicalization or expected-output generator. Fixed vectors cross-check both sides; at least one expected result is prepared independently before the Swift path is exercised. No production verifier package or new dependency is needed merely to test this profile.

The verifier requires the selected algorithm and covered components; checks the key binding and MAC with constant-time comparison; recomputes the body digest; checks created/expires and atomic nonce uniqueness; then separately authorizes the request. It rejects expired signatures, created more than 5 seconds in the future, lifetimes other than 60 seconds, and repeated (keyid, nonce). Retain replay entries until expires plus 5 seconds. Concurrent duplicate submissions must produce at most one accepted admission. Production verifier scaling/persistence and clocks remain app/server responsibilities; sample success is not an authorization system.

Rotation: new key IDs overlap for deployment only while the server explicitly allows them. A new client binding/session selects the replacement key. No automatic old-key fallback, secret refresh, alternate algorithm or unsigned fallback. Removing a compromised key at the server must reject old signatures even if their nominal time window remains valid.

## Admission, timeout and compatibility

Signing is disabled by default and independently selected from header auth. A signing configuration must match the client's base origin/account. Additional raw origins never inherit a signer. A mismatch fails locally; it never silently sends unsigned data. Header providers cannot alter the target/body after signing. A dedicated signer receives the finalized signature-base bytes and a bound nonsecret context, rather than broadening AuthenticationContext.

Mandatory maximum body bytes is supplied by the app and checked before hashing/signing. This bounds processed body bytes, not all memory already used by request serialization or Foundation. Signing/provider work runs within the existing monotonic total call budget, sampled before preparation; no new 60-second network budget starts afterward. Wall time is used only for signature metadata. Cooperative provider work may outlive logical cancellation; late output is discarded and cannot start a task.

Reject non-disabled retry when signing is selected; do not silently change RetryPolicy or re-sign. Never follow redirects for a signed request, including same-origin redirects. Preserve the first HTTP response/status behavior under existing accepted-status rules. No automatic clock repair, challenge re-signing, token refresh or fallback. Auth and signing errors must not expose key IDs, signature bytes, nonce, target, auth headers, body or provider text through diagnostic descriptions.

## Public contract shape to finalize

Proposed separate immutable RequestSigning binding: exact origin/account/environment, mandatory maximumBodyBytes and a Sendable HMAC signing provider. The provider exposes a nonsecret key identifier and signs SDK-assembled base bytes; no raw key crosses the SDK boundary. It must bind the same key identity to the returned MAC; reject invalid identifier/MAC length. Exact API must prevent a race between independently read key ID and rotating signer state, for example by obtaining one immutable signing-key handle per logical call. That handle signs once; app rotation creates a new handle/binding. Security review must assess any Sendable wrappers rather than applying unchecked annotations merely to compile.

Do not modify existing NetworkClient requirements or remove prior initializer overloads. Introduce additive configuration/operation policy only after exact API approval. Compilation-only consumer checks must preserve existing initializer-as-function usage. Exact signatures, errors and property names remain unresolved, not approved by this profile text.

## Required evidence

Positive vectors: absent/empty/binary/JSON bodies; absent/present content type/auth; Unicode serialized JSON; escaped query and repeated query keys; explicit port, IPv6 and empty path; exact limit boundary; fixed clock/nonce reproducibility. Negative vectors: method/host/path/query/body/auth/content-type mutation, wrong/rotated key, bad MAC/digest/field syntax, duplicate/replayed nonce, parallel replay, expiry/future time/overflow, body limit, existing reserved headers, retry, redirect, cancellation and late provider.

Pure vectors do not establish actual wire target reconstruction. A later separately authorized controlled server must observe Foundation's emitted request and independently verify it, including redirect refusal and absent/empty body behavior. No network execution, key provisioning or production acceptance is authorized here.


## Native fixture finding

The [Mac result report](F6_MAC_FEASIBILITY_RESULTS_2026-11-09.md) records a body/header-finalization failure and corrected actual-wire verification. Finalize an explicit content type for nonempty signed raw bodies before canonicalization; do not rely on Foundation leaving an absent Content-Type unchanged. H06 requires an independently valid positive input before its mutation negative. These results refine the proposed profile; they do not establish general RFC interoperability or production suitability.
