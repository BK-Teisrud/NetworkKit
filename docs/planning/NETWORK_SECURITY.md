# HTTPS, origin, loopback and redirect policy

Current evidence, 2026-10-27: [I19 security/privacy review](SECURITY_PRIVACY_REVIEW.md) is accepted. [TLS-01 native macOS rejection](NATIVE_TLS_REJECTION.md) adds a candidate untrusted-certificate regression; its PR/main acceptance remains required. Trusted positive HTTPS, independent hostname mismatch and complete minimum/physical/runtime evidence remain open. Earlier delivery/status notes below preserve their historical scope and are superseded by the linked current evidence.

I14 update: [provider origin/account binding and verification](AUTHENTICATION_PROVIDER.md) is now implemented; earlier I09 delivery notes below retain their historical scope. Consolidated security/release review remains outstanding.

I10 update: the public `APIClient` now connects both request inputs to this shared foundation.
See [HTTP pipeline](HTTP_PIPELINE.md) for current signatures, verification boundaries and
remaining timing/lifecycle gates. Earlier task descriptions below retain their historical scope.

I09 / #50, 2026-10-21. This adds shared request policy and a per-operation URLSession
delegate to the internal adapter. The public executing client remains I10; provider,
terminal-cause/deadline/shutdown arbitration and comprehensive security review remain
later tasks. No release/minimum-OS/physical-device or complete TLS test claim is made.

## Public value policy

`NetworkConfiguration.security` is an immutable `NetworkSecurityPolicy`, defaulting to
HTTPS only. `allowInsecureLoopback` defaults false. An explicit true allows plain HTTP
only to normalized localhost, canonical dotted IPv4 in 127.0.0.0/8, or IPv6 ::1.

`NetworkOrigin(URL)` validates absolute HTTP(S) URL structure using the shared URL
validator and retains scheme, normalized ASCII/IDNA host and effective port. Default
ports are 443/80; IPv6 uses Darwin inet_pton/inet_ntop parsing/canonicalization. The
loopback check performs no DNS lookup. Abbreviated/integer/hex/octal IPv4, mapped IPv6,
zone identifiers, LAN/unspecified/nonloopback addresses and hostname lookalikes are
not development permissions. Trailing-dot hosts/userinfo/fragments/ambiguous paths
retain the conservative existing rejection rules.

`additionalRawOrigins: Set<NetworkOrigin>` explicitly permits separately prepared raw
calls to another origin; it never permits automatic cross-origin redirects or insecure
remote HTTP. Typed endpoints stay on their configured base origin. Every additional
raw origin drops **all** client default headers (including ordinary fields) before
merging only explicit raw/call headers. Body Content-Type defaults remain derived when
needed. Explicit headers must belong to the actual destination/account; origin
permission is not credential-sharing permission. I14 must bind providers to that origin.
An additional-origin call rejects borrowed sessions with automatic cookie stores/handling,
which could otherwise share a domain cookie. Strict compatible sessions may make the call;
request/delegate copies disable automatic handling. The app may use a separate origin-scoped
client/session for an HTTPS service needing app-managed cookies.

Origins expose fields explicitly for deliberate app use; default descriptions hide the
host, URL, port, header values and credential data. Set membership is an exact normalized
scheme/host/effective-port comparison, not a wildcard or DNS-equivalence policy.

## Plain HTTP and compatible sessions

HTTP loopback is development-only. It permits ordinary public metadata fields:
Accept, Accept-Language, Accept-Encoding, Content-Type, User-Agent, Cache-Control,
Pragma, conditional request fields and Range/If-Range. Any other explicit field is
rejected as credentialsOverHTTP, including Authorization, Proxy-Authorization, Cookie,
API-key/token names and unknown custom names. Apps must not put secrets into allowed
metadata fields or use body/query data as a concealed authentication channel. Use
HTTPS with normal trust when a local service needs authentication or custom headers.

HTTP calls also require cookie/cache stores disabled, automatic cookie handling off,
and no credential store. The request copy disables automatic cookies/cache even if
raw request flags request them. An app-managed session with active stores cannot be
used for local HTTP. No ATS/Info.plist/global trust setting is modified; host-app/OS
permission to connect remains independent of library permission.

All adapters reject session httpAdditionalHeaders: those global fields could otherwise
add credentials after request validation or carry them to an additional origin. Use
scoped NetworkConfiguration/request headers instead. Credential stores are forbidden
also in the app-managed profile because Basic/Digest/mTLS fallback is outside v1.
App-managed profiles may retain explicit cookie/cache choices for HTTPS. Foreground,
no-external-delegate and positive finite resource-limit checks remain from I08.

Injection trusts the app: it must lend a valid compatible session without hidden prior
challenge/authentication state or concurrent global changes. The library cannot inspect
all OS/app/proxy state or make an arbitrary borrowed/custom transport a security sandbox.

## Validation and transport binding

Typed and raw RequestBuilder paths use the same policy after header/body preparation.
Raw calls validate their configured base and explicit destination permission as well.
The internal adapter validates again before its DataOperation, then creates one new
NetworkTaskDelegate for the operation. Production DataOperation passes that delegate
to URLSession.data(for:delegate:); test operations must explicitly select scripted I/O.
There is no production fallback to a test driver.

The adapter's optional internal baseURL exists for isolated transport fixtures. I10's
client assembly passes its immutable baseURL and security policy; omitting the
internal base does not implement client-level raw-origin authorization. Public request
construction alone does not control networking performed directly by app-owned APIs.

## Redirect and trust behavior

| Callback condition | Result |
| --- | --- |
| 301/302/303/307/308, original exact GET/HEAD, unchanged method, same normalized origin, validated destination/headers, no body/stream | Follow up to five hops |
| Cross-origin, changed port, downgrade, changed method, mutating/other method, malformed destination, unsupported redirect status/body | Completion handler receives nil; return the 3xx response for normal status handling |
| Repeated URL or sixth permitted hop | Refuse and record invalidResponse(.redirectLimitExceeded), propagated by the adapter |
| Server-trust challenge | performDefaultHandling with nil credential; OS system trust evaluates it |
| Basic/Digest/client-certificate/default/unknown challenge | cancelAuthenticationChallenge with nil credential, even if a credential is proposed |

The delegate pins the original operation's origin and method, irrespective of additional
raw-origin permissions. Redirect state is protected with OSAllocatedUnfairLock; no lock
is held across completion callbacks. Stored visited URLs are private operation state,
never automatic diagnostic output. Storage flags remain strict on followed requests.
Accepting a 3xx status permits interpreting the response, not contacting its Location.

There is no trust bypass, credential construction from serverTrust, custom certificate
validation, automatic token refresh, retry engine or mutating replay. The same data task
and delegate span permitted redirects; I12 still must implement the original monotonic
whole-operation budget. Cancellation/timeout race arbitration remains I12/I13.

## Actual verification and limits

The local suite passes **121 test functions in 17 suites**, including a public consumer
without @testable. Tests cover normalized origins/ports/IDNA/IPv6, default HTTP rejection,
loopback variants/lookalikes, forbidden HTTP headers, explicit origin permissions with
no inherited defaults, typed/raw parity, callback completion decisions, HEAD/method/body
rules, five hops/loops, fixed policy errors, proposed-credential rejection, session
compatibility and zero DataOperation invocations for denied initial destinations.

On macOS, tests start two ephemeral Python standard-library HTTP listeners bound only
to 127.0.0.1. Real URLSession follows permitted five-hop GET/HEAD chains, rejects sixth
hops/loops, and refuses a different-port destination before contact for typed and raw
preparations. The denied server's request counter remains zero. Processes are terminated
by test cleanup. No public endpoint, dependency, TLS exemption or persistent server is
introduced. A native URLProtocol redirect experiment trapped in Foundation; the working
integration test therefore uses real controlled loopback HTTP, not that unsupported fixture.

A deliberate removal of the destination-origin comparison in an isolated source copy
made both typed/raw real-loopback tests fail: the response became 200 and the denied
server recorded one request. The repository source was unchanged. This proves those
assertions detect actual contact, not merely the shape of a helper's return value.

On iOS/watchOS/tvOS the redirect integration suite uses scripted I/O while calling the
actual delegate/policy boundary. Existing I08 native nonredirect URLProtocol tests stay
on iOS/tvOS; watchOS does not support custom URLProtocol. Scripted redirect results do
not establish native callback delivery, ATS, radio/network behavior or TLS on those
platforms. Controlled native/physical-device checks remain release requirements; no
platform test is hidden behind a skip or reported as stronger evidence than it provides.

SDK 26.2 declarations for data(for:delegate:) and OSAllocatedUnfairLock are within all
selected minimums (macOS 12/iOS 15/watchOS 8/tvOS 15 and macOS 13/iOS 16/watchOS 9/tvOS 16,
respectively). The new watchOS test target also compiles with warnings as errors. Actual
hosted PR/main run links are recorded on [#50](https://github.com/BK-Teisrud/NetworkKit/issues/50)
before completed closure. TLS rejection is implemented by system handling; no real
certificate/handshake integration is claimed from these callback tests.

Primary references reviewed: [Apple redirect callback](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession(_:task:willperformhttpredirection:newrequest:completionhandler:)),
[challenge handling](https://developer.apple.com/documentation/foundation/handling-an-authentication-challenge),
[system server trust](https://developer.apple.com/documentation/foundation/performing-manual-server-trust-authentication),
and [watchOS URLProtocol limitation](https://developer.apple.com/documentation/foundation/urlprotocol).
