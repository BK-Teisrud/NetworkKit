# Storage profiles and controlled-server verification

I16 / [#57](https://github.com/BK-Teisrud/NetworkKit/issues/57), 2026-10-22.
The owned default remains strict. Tests now exercise actual URLSession behavior against
an isolated loopback HTTP server, rather than treating URLProtocol as storage evidence.
A public, explicit app-managed choice is now available for compatible borrowed sessions.
This implements the previously approved storage-profile boundary from ADR-0007; it is
not a custom cache, credential store, persistence or offline module.

## Public choices

```swift
// Owned: always strict, without automatic stores.
let owned = try APIClient(configuration: configuration)

// Borrowed: strict unless explicitly selected otherwise.
let strict = try APIClient(configuration: configuration, session: strictAppSession)
let managed = try APIClient(configuration: configuration, session: appSession,
                            storage: .appManaged)
```

`SessionStorageProfile` has two cases. The public borrowed-session initializer defaults
to strict, preserving existing calls. The owned initializer has no app-managed switch.

| Condition | strict | appManaged |
| --- | --- | --- |
| Cookie storage/automatic handling | nil store, false httpShouldSetCookies, accept policy never | Explicit app-owned settings may be used for HTTPS |
| Credential store | nil | nil; active stores are still rejected |
| HTTP cache | nil URLCache, reloadIgnoringLocalCacheData | App-owned URLCache/request cache policy permitted for HTTPS |
| External session delegate/global additional headers | Rejected | Rejected |
| Background session or invalid request/resource limits | Rejected | Rejected |
| Loopback HTTP | Public request metadata only, automatic stores disabled | Active cookie/cache stores rejected before I/O |
| Additional permitted raw origin | No inherited defaults/provider; cookie handling off and reload policy | Active automatic cookie configuration rejected; without cookies, copied request uses cookie-off/reload policy |
| Shutdown | Invalidate owned session only | Never invalidate borrowed session or delete its stores |

An app-managed HTTPS cache may still store responses under Foundation's behavior,
including for an allowed additional raw HTTPS origin. Reload policy bypasses local
cache reads; it is not a promise to disable writes in an explicitly cache-enabled
session. The strict profile has no URLCache object and is the no-automatic-cache choice.
No claim is made that URLSession.shared/default sessions automatically qualify: active
credential stores/global headers/delegates remain incompatible even after app-managed
selection. Injection checks accessible settings of a trusted app-owned dependency;
it cannot certify malicious subclasses, custom URLProtocol code or external app/OS state.

App-managed is an explicit privacy/persistence decision. The app owns account/environment
isolation, cache capacity, memory/disk choice, cookie scope and expiry, access control,
logout, deletion and coordination with all other users of a borrowed session. It must
choose correctly scoped stores before session construction. Changing a configuration
copy later does not change the live session. NetworkKit does not purge app data during
shutdown: another consumer may still need it. Quiesce relevant app work before deleting
stores if later responses could repopulate them. No secure-erasure or instant-revocation
guarantee is made.

AuthenticationPolicy.disabled skips only the header provider. In an app-managed profile,
it does not disable automatic cookies/cache or remove explicit/default auth headers.
Use a strict, credential-free client when that is the desired public-call boundary.
HTTPS/system trust, origin checks, redirect restrictions, header validation, cancellation,
time budgets and sanitized diagnostics remain active for both profiles. No TLS bypass,
root installation, ATS change, automatic Basic/Digest/mTLS credential fallback or OAuth/
Keychain/refresh implementation is introduced.

## Actual native loopback evidence

macOS tests spawn a Python standard-library HTTP server bound only to 127.0.0.1 on a
kernel-assigned port. Each fixture owns its process/realm/state; it closes on completion.
The tests use native URLSession, no URLProtocol or production host for these probes.
NetworkKit uses its explicit development loopback exception with no credential headers.

- **Cookies, both owned and strict borrowed:** the server returns Set-Cookie on each
  response. Two calls reach the server and neither carries Cookie or Authorization.
  A separate raw app session with a private ephemeral cookie store receives the same
  fixture cookie and sends it on its next request. Its cleanup removes only private
  fixtures. Identity guards abort before writing if a store were unexpectedly shared.
- **Cache, both ownership modes:** the server returns fresh-cache headers and an ETag.
  Even an input requesting cache-only access reaches the server twice and returns
  different hit numbers, with no If-None-Match. A separate app-owned memory cache,
  seeded with an in-memory-only response, serves that response through native URLSession
  instead of the server's JSON. This positive control proves the cache mechanism is
  functional; it is not evidence that the strict client owns or uses that cache.
- **Credentials:** a raw app session first authenticates successfully to a Basic
  challenge using a private ephemeral credential store and forSession dummy credentials.
  A fresh owned strict client then contacts that same challenge endpoint without
  inheriting/supplying Authorization. It either receives 401 or Foundation reports a
  challenge-cancellation transport error; successful credential use is forbidden for
  the strict client. This is a wire/storage check, not a native TLS/trust proof.

The direct Foundation controls deliberately demonstrate behavior outside NetworkKit's
strict boundary with dummy fixture data on loopback. They do not enable HTTP credential
use in NetworkKit. No user/shared cookie or credential store is seeded, purged or changed;
private-store identity is checked before writes. No Keychain fixture, certificate/root,
DNS/hosts change, paid service or global cache replacement is used.

## Other runtime and compatibility evidence

Local warnings-as-errors: **210 test functions / 24 suites passed**. Eight new storage-
suite functions (with parameterized ownership/profile/settings cases) plus a public
consumer function cover native probes, both public profiles, rejection of credential
stores/global headers/external delegates/background sessions, explicit opt-in, HTTP and
foreign-cookie prohibitions, cache-policy copying, preservation of app-owned cookie/cache
state after shutdown and app-controlled deletion.

On iOS/iPadOS/watchOS/tvOS the three native-server functions use disclosed adapter/config
checks instead of spawning a server. Their wire/storage behavior is not claimed as native
server evidence. The remaining tests construct actual sessions and exercise guards on
all runtimes. Public consumer tests import NetworkKit without @testable and perform
native URLSession/URLProtocol I/O on macOS/iOS/tvOS, demonstrating explicit profile selection
and a borrowed session still usable after client shutdown. watchOS checks public profile
construction/lifecycle and uses scripted adapter I/O where interception is unsupported.
URLProtocol proves assembly/policy there, not actual HTTP caching, cookie storage or TLS.

Minimum-OS, physical-device, native HTTPS storage/trust, filesystem/backup/privacy review
and release gates remain outstanding. Nil stores and these controlled probes do not
certify zero RAM copies, zero OS/app diagnostic writes or forensic erasure. Earlier
I08/F1 statements about internal-only app-managed selection retain their historical
scope; this I16 guide documents the current public choice. Exact PR/main commits and
five-runtime results are recorded in issue #57 before completed closure.

## Platform references

Apple documents that [ephemeral sessions](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/ephemeral)
keep session storage in memory, which is why ephemeral alone is insufficient for strict
no-automatic-storage semantics. The [credential-store setting](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/urlcredentialstorage)
can be nil; the ephemeral default is a private in-memory store. NetworkKit explicitly
sets nil and does not rely on that default. The controlled tests above are project
execution evidence, distinct from these platform descriptions.

Negative control: an isolated copied source removed app-managed credential-store
rejection. The profile-rejection test built successfully, then failed one assertion
because a credential-enabled appManaged session was accepted. Repository source was
unchanged by the control.

## Main verification follow-up, 2026-10-23

The initial PR passed all checks, but its first main run timed out in the pre-existing
native redirect-hop-limit test, before the new storage suite (which passed after the
runner restarted). This failed run is retained as evidence, not treated as acceptance.
A terminal loop/hop-limit failure now explicitly cancels its underlying URLSession task
when declining the redirect, rather than relying on Foundation to finish an empty
redirect response. Ordinary cross-origin denial still preserves its response. A new
three-case callback regression checks both terminal paths and the nonterminal denial
without starting network I/O; the original native redirect test remains unchanged.
No timeout is increased, assertion removed or protection weakened. Final PR/main evidence
includes this follow-up and the complete uninterrupted suite.

A second isolated negative control removed terminal task cancellation. The new callback
regression built and failed two assertions (loop/hop limit), with ordinary denial unchanged.
The repository was unaffected by this control; local source/DocC checks passed.
