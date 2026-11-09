# ``NetworkKit``

Execute typed/raw buffered HTTP calls and explicit foreground file downloads for Apple platforms.

## Overview

NetworkKit provides ``APIClient`` behind the injectable ``NetworkClient`` boundary.
Typed endpoints and raw URLRequest inputs use shared request validation, secured
URLSession transport, status checks and response interpretation. Consolidated lifecycle/authentication/privacy review and release gates remain outstanding.

Define an ``Endpoint`` with an ``EndpointPath`` and optional ``HTTPQueryItem`` values.
Use ``NetworkConfiguration`` for client defaults and ``NetworkCallOptions`` for explicit
call headers/timeouts. ``RequestBody`` describes buffered data; ``JSONEncodingOptions``
selects value-based Apple JSONEncoder strategies with a new encoder per preparation.

Ordinary failures use ``NetworkError``. CancellationError remains a separate Swift error.
See the repository's planning guides for exact request rules, actual test evidence,
remaining implementation tasks, and the proprietary rights policy.

## Integration guide

Start with <doc:IntegrationGuide> for compiled consumer examples, installation, formats, errors, session ownership, authentication and testing.

## File downloads

See <doc:FileDownloads> for the separate bodyless GET file operation, required size limit, temporary-file ownership and error/cleanup boundaries.

## Foreground WebSocket candidate

See <doc:WebSockets> for ownership, cancellation, message limits and pending native verification.

## Response interpretation

Select ``ResponseStrategy`` for JSON models, Data, strict UTF-8 text, or explicit
``EmptyResponse``. ``JSONDecodingOptions`` applies immutable native settings to a fresh
JSONDecoder per response. ``HTTPStatusPolicy`` defaults to 200...299 and allows explicit
per-call replacements through ``NetworkCallOptions``. Status is checked before payload
decoding; returned ``NetworkResponse`` retains status and case-insensitive headers.
An empty JSON response fails decoding; an explicitly empty strategy skips body decoding.
ResponseStrategy can interpret local buffered values; APIClient connects it to HTTP execution.

## Session foundation

An internal foreground URLSession adapter reuses one owned session or borrows an
app-owned session. Strict defaults explicitly disable automatic cookie, credential,
and cache stores. Borrowed sessions are never invalidated by the adapter. This is
the transport for APIClient; per-call timing/cancellation and explicit shutdown are enforced.
See the repository session transport guide for compatibility and lifetime constraints.

## Network security policy

``NetworkSecurityPolicy`` on ``NetworkConfiguration`` defaults to HTTPS and system trust.
``NetworkOrigin`` identifies scheme, normalized host and effective port. Explicit extra
raw origins do not inherit client default headers or authorize cross-origin redirects.
Loopback HTTP requires an explicit development option and excludes credentials/custom
headers and automatic storage. No ATS or trust settings are weakened.

The internal adapter supplies a per-operation task delegate. It follows only validated
same-origin GET/HEAD redirects up to five hops; denied redirects remain 3xx responses.
Loops/excess hops fail. Trust challenges use system handling; no credentials are supplied.
See the network security guide for native versus scripted test evidence and remaining
physical-device, TLS and lifecycle gates.

## Client execution

Create ``APIClient`` with immutable ``NetworkConfiguration`` and reuse it across calls.
Use `try await client.send(endpoint)` or `try await client.send(request, response: .text)`.
Both return ``NetworkResponse`` with value/status/headers. Retry is disabled by default;
``NetworkCallOptions`` can opt safe bodyless reads into one bounded retry. No token refresh occurs. The client can own a strict session or borrow a compatible app-owned
session, which it never invalidates. Public injection defaults to strict storage; explicit appManaged selection permits only the documented app-owned HTTPS cookie/cache profile.
Default request inactivity is 30 seconds; the monotonic total budget is 60 seconds.
Explicit call options override client defaults. Preparation, transport and response handling
share one budget. Timeout/caller cancellation cancels only that call, and both worker and
watchdog are joined before return. Cooperative cleanup can delay return; no hard real-time
latency is promised. System timeout errors use NetworkError.timeout(.system);
NetworkError.transportFailure exposes its safe known system code without userInfo.
CancellationError remains separate; unexplained system cancellation is a transport error.

## Explicit shutdown

Call `await client.shutdown()` through ``NetworkClient`` or ``APIClient`` to close
admission, cancel only this client's active operations and await worker/watchdog cleanup.
New calls fail with NetworkError.invalidRequest(.clientClosed). Concurrent and repeated
shutdown callers share completion, including cancelled waiters. The client invalidates
only its own session; an injected session remains app-owned and usable by others.
Client doubles implement the async nonthrowing shutdown requirement explicitly.
Shutdown is cooperative; unresponsive work can delay return. Use an owning task/service
boundary so work being joined does not await its own shutdown. Deinit is fallback
owned-session cleanup, not a substitute for explicit asynchronous closure.

## Authentication headers

Supply a concurrency-safe ``AuthenticationHeaderProvider`` through
``NetworkAuthentication`` in ``NetworkConfiguration``. It receives minimal
``AuthenticationContext`` values for the client's HTTPS base origin and immutable
account/environment binding. It runs once inside the operation's cancellation/total
budget. Apps own login, token storage, logout and renewal; no refresh/replay is provided.
Provider/header conflicts fail before transport. Additional raw origins never inherit
this binding's provider or client defaults. ``NetworkCallOptions`` can select
``AuthenticationPolicy/disabled`` to skip only the provider; explicit/default headers
and security validation remain active. Provider cleanup must cooperate with cancellation
and must not await the same client's shutdown. Native TLS/device/release gates remain open.

## Optional diagnostics

``NetworkConfiguration`` accepts an optional ``NetworkDiagnosticSink``, disabled by default.
The sink receives only ``NetworkDiagnosticEvent``: random request ID, allowlisted method,
validated status, monotonic duration and safe terminal category. No URL/header/payload,
account, raw custom method, raw error object/text or external telemetry is exposed.
The request ID correlates with ``AuthenticationContext`` for the same operation.
One nonthrowing synchronous event follows joined cleanup before send returns; recording
must be concurrency-safe, fast and nonblocking. Callback time is excluded from duration
and cannot rewrite the selected result. An admitted send remains registered through
recording: never block the sink waiting for this client's shutdown. Nil disables the
sink without changing request/result semantics. Consolidated privacy/release gates remain open.

## Borrowed storage profiles

Owned ``APIClient`` instances always use the strict storage profile. For a borrowed
URLSession, ``SessionStorageProfile`` defaults to strict; explicit appManaged selection
permits app-owned HTTPS cookie/cache settings while credential stores, global headers,
external delegates and background sessions remain incompatible. Both profiles retain
normal security/lifecycle checks. Active stores are rejected for loopback HTTP; automatic
cookies cannot follow additional raw-origin permission. App-managed cache reload policy
is not a promise to suppress all writes. Apps own store isolation, disk/memory selection,
capacity and deletion; client shutdown never clears or invalidates a borrowed session.
Disabling the auth provider does not disable app-managed cookies/cache. Native macOS
loopback storage tests exist; native HTTPS/device/consolidated privacy gates remain open.

## Topics

### Integration and operation guides

- <doc:IntegrationGuide>
- <doc:FileDownloads>
- <doc:WebSockets>
