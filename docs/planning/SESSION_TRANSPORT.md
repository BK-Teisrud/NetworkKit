# URLSession ownership and the internal transport adapter

I16 current update: [controlled-server storage verification and public profile selection](STORAGE_VERIFICATION.md) is implemented. The owned profile remains strict; borrowed clients may explicitly select appManaged. Earlier internal-only/I08 notes are historical.

I13 update: [explicit shutdown](SHUTDOWN_AND_CONCURRENCY.md) joins client operations and
invalidates only an owned session. Borrowed sessions and other clients' calls remain usable.

I10 update: the public `APIClient` now connects both request inputs to this shared foundation.
See [HTTP pipeline](HTTP_PIPELINE.md) for current signatures, verification boundaries and
remaining timing/lifecycle gates. Earlier task descriptions below retain their historical scope.

I09 update: the adapter now supplies a per-operation redirect/trust delegate and shared URL/header policy. Credential stores and global session headers are incompatible; explicit app-managed cookie/cache profiles remain available for HTTPS. See [current security rules](NETWORK_SECURITY.md).

I08 / #49, 2026-10-21. `URLSessionTransport` implements the internal NetworkTransport
boundary using one foreground URLSession. It is not a public HTTP client. The adapter
is exercised with isolated fixtures: native URLProtocol on macOS/iOS/tvOS and a
scripted internal I/O boundary on watchOS. No production TLS/security claim is made.

## Construction and storage

The owned configuration starts from ephemeral and explicitly disables even automatic
in-memory stores. Ephemeral alone is insufficient: Apple documents its private memory
cookie/cache stores.

| Setting | Owned strict default |
| --- | --- |
| httpCookieStorage | nil |
| httpShouldSetCookies | false |
| httpCookieAcceptPolicy | never |
| urlCredentialStorage | nil |
| urlCache | nil |
| requestCachePolicy | reloadIgnoringLocalCacheData |
| waitsForConnectivity | false |
| timeoutIntervalForRequest | Selected inactivity limit, default 30 seconds |
| timeoutIntervalForResource | Platform ephemeral default, independently limiting calls |

The strict request copy also sets httpShouldHandleCookies=false and the same cache
policy, preventing raw request settings from re-enabling automatic handling. The
original request remains unchanged. Explicit header fields are not automatic storage;
scoped authentication and sensitive-header rules remain I09/I14 work.

An owned adapter validates and copies its configuration before constructing one session;
all sends reuse that session. Custom protocolClasses on supported platforms and a Sendable DataOperation closure are internal test seams, not a
public transport plugin. Background configurations and invalid finite/positive session
timeouts are rejected before creating an owned session. Fixtures intercept all requests in their selected test paths; an unknown fixture fails locally.
The production DataOperation always calls URLSession.data(for:); the scripted operation
is explicitly selected only by tests and never chosen as a fallback after network failure.

## Borrowing and compatibility

`init(session:storagePolicy:)` borrows the app's existing session. It checks accessible
configuration without changing it. Background sessions and any external session
delegate are rejected as unsupportedRequest. A delegate could override future trust,
authentication, or redirect policies; accepting arbitrary delegates would overpromise
compatibility.

The default strict profile requires all disabled-store/cookie/cache settings above.
An ordinary ephemeral/default/shared session with active stores does not qualify.
An explicit internal appManaged policy accepts app-controlled cache/cookie
settings (I09 additionally requires nil credential storage and empty global session headers), while retaining foreground/no-external-delegate checks. It is an assembly
boundary for the later client API, not a public storage/cache feature added here.
Apps retain responsibility for account isolation, deletion and limits under that policy.

The adapter never changes an injected session's global configuration/stores, calls
reset/flush/getAllTasks, or invalidates it. It never creates a replacement when the
borrowed session fails. App-managed storage cannot bypass the security pipeline that
must be connected in I09/I10 and verified in I16.

## Concurrency, invalidation, and system limits

The adapter is an actor; network awaits are reentrant, allowing concurrent operations
on one session rather than serializing all network waiting. send returns buffered Data
and URLResponse. Body streams are rejected before transport. It checks cancellation at
entry and after data delivery; safe transport-error normalization and terminal-cause
arbitration remain later pipeline/lifecycle work.

`invalidateOwnedSession()` is an internal ownership primitive. It is idempotent, rejects
later owned sends as clientClosed, and cancels/invalidates only an owned session.
Borrowed sessions are untouched. Deinitialization also invalidates only owned sessions.
Full client shutdown, active-operation registries, borrowed-operation cancellation,
shared completion and watchdog cleanup remain I12/I13; this primitive is not that API.

External invalidation can stop a currently active borrowed operation; native URLProtocol tests on macOS/iOS/tvOS verify
Foundation's URLError.cancelled is preserved for later cause classification. watchOS
exercises the same forwarding/identity boundary with a scripted cancellation. The app
must keep an injected session valid while lending it. In an isolated local experiment,
starting a *new* async data task after session invalidation raised an Objective-C
NSException rather than a catchable Swift error. Foundation exposes no reliable public
is-invalidated query. The adapter does not promise to detect/recover from an already
invalid session; the later client must prevent reuse after its own closure, and app
invalidation remains outside the ownership contract. No replacement/retry hides it.

The adapter preserves the system resource timeout instead of setting a hidden 60-second
cap. A shorter injected/system resource timeout still wins, and an arbitrarily longer
library total budget cannot extend it. The per-request inactivity limit is already set
by RequestBuilder; the monotonic whole-operation budget remains I12 work. Synchronous
hooks and OS scheduling do not gain a hard real-time guarantee.

I08 initially used Foundation data(for:) without a policy delegate. I09 now binds
data(for:delegate:) to the per-operation policy. It still must not be exposed as a complete
client before the shared typed/raw pipeline, providers and lifecycle are connected. No automatic library retry/cache or
file/stream/background API is introduced.

## Verification and availability

The full local suite passes 98 test functions in 15 suites on macOS 15.8.1 x86_64,
Xcode 26.3 / Swift 6.2.4. Fourteen new tests cover strict configuration, request copies,
owned reuse/snapshots/invalidation, borrowed reuse after adapter cleanup/deinit, explicit
app-managed storage, rejected delegates/stores/limits/backgrounds, streams, cancellation
at entry, 20 concurrent calls, active external invalidation, and resource-budget limits.
The background constructor is tested where available (macOS/iOS/watchOS); tvOS instead
asserts the owned foreground configuration because it does not offer that constructor.

The test-only URLProtocol subclass restates Foundation's inherited unchecked Sendable
conformance. Its instances have no mutable fields; the shared per-URL fixture registry
is protected with OSAllocatedUnfairLock. No library unchecked Sendable declaration is
introduced. Unique fixture URLs, per-session protocolClasses where supported, and explicit watchOS
DataOperation injection prevent cross-test/public-network dependencies in the corrected suite.

The inspected SDK 26.2 Foundation interface declares data(for:delegate:) from macOS 12,
iOS 15, watchOS 8 and tvOS 15, within every selected minimum. The test lock is available
from macOS 13/iOS 16/watchOS 9/tvOS 16. Actual hosted PR/main evidence is recorded on
[issue #49](https://github.com/BK-Teisrud/NetworkKit/issues/49) before completion.
No minimum-OS, physical-device, TLS, redirect, secure-erasure or full shutdown claim follows.

Primary references: [Apple URLSession](https://developer.apple.com/documentation/foundation/urlsession),
[ephemeral configuration](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/ephemeral),
[cookie storage](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/httpcookiestorage),
and [session invalidation](https://developer.apple.com/documentation/foundation/urlsession/finishtasksandinvalidate()).

## watchOS test isolation correction

The initial hosted run [39625774288](https://github.com/BK-Teisrud/NetworkKit/actions/runs/39625774288)
passed source integrity, macOS/iPhone/iPad/tvOS and DocC, but watchOS ignored custom
URLProtocol handlers and attempted DNS resolution for the reserved example.invalid
fixture host. Those tests failed; the required quality-gate correctly blocked merge.
This was not merely a GitHub queue delay. Apple explicitly documents that custom
[URLProtocol implementations are unsupported on watchOS](https://developer.apple.com/documentation/foundation/urlprotocol).

The corrected suite never selects that handler as watchOS I/O. It injects a deterministic
internal DataOperation while still constructing the actual adapter/session, exercising
configuration, owned/borrowed identity, request policies, reuse, concurrency and error
forwarding. macOS/iOS/tvOS retain real URLSession + URLProtocol integration, including
borrowed-session usability and active external invalidation. watchOS scripted tests do
not prove its URLSession data transfer or external-invalidation delivery; real watch
networking is an outstanding integration/physical-device release requirement. No test
is replaced with a skip or a swallowed failure, and production execution is unchanged.
