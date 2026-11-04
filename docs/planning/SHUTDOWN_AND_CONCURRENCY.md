# Client shutdown and concurrent operations

I13 / [#54](https://github.com/BK-Teisrud/NetworkKit/issues/54), 2026-10-21.
The client now admits/tracks its own calls and supports explicit idempotent shutdown.
The earlier [timing/cancellation behavior](CANCELLATION_AND_BUDGET.md) remains in force.
Provider/diagnostics/storage/final API and release reviews remain later tasks.

## Public API

`NetworkClient` now requires `func shutdown() async`; `APIClient` implements it. App
client doubles must implement this requirement explicitly. There is no public default
no-op that silently promises cleanup. This is an unreleased API addition before I18
stabilization, following the already approved lifecycle contract.

```swift
let client: any NetworkClient = try APIClient(configuration: configuration)
// Execute/await the app's calls using this client.
await client.shutdown()
```

Shutdown is nonthrowing. Every caller waits for the same closed transition, including
a waiter whose Swift task is cancelled. Cancelling a shutdown waiter does not reverse
closing, return early or abandon cleanup ownership. Shutdown has no drain-without-cancel
mode, and a closed client cannot reopen; construct a new client when needed.

Once closing starts, typed and raw sends fail with `NetworkError.invalidRequest(.clientClosed)`
before endpoint option getters, preparation or I/O. Closed admission also takes precedence
over pre-existing task cancellation. Input expressions constructed by the app before
entering send remain the app's work, outside the admission boundary.

## Lifecycle, operation scope and ownership

| Phase | Calls | Shutdown behavior |
| --- | --- | --- |
| open | Register before reading app options; own immutable snapshots/codecs | First shutdown caller atomically selects closing and owns finalization |
| closing | Reject all new calls | Cancel admitted operations, await their worker/watchdog cleanup and registration release; concurrent callers await closed |
| closed | Reject all new calls | Repeated shutdown returns without another finalization |

ClientLifecycle synchronizes only phase, registrations and continuations. No user
callback, session operation or await executes under that lock. Callback invocation and
continuation resumption happen after unlocking. Client configuration remains immutable;
network waits and codec work are not globally serialized behind a client actor/lock.

Admission creates a registration before reading endpoint options. If shutdown occurs
before the worker binds its cancellation callback, the registration remembers cancellation;
binding then immediately selects cancellation, preventing the call from starting I/O.
The registration is removed by defer after success, validation/coding/transport/status
failure or cancellation, and only after the structured operation has joined its children.

NetworkOperation's group now awaits a synchronized terminal-selection signal rather
than waiting solely for a child to return. This lets shutdown select CancellationError
and wake the group promptly while I/O is suspended. The group then cancels and joins
its worker/watchdog. Existing first-recorded-outcome arbitration is preserved: earlier
timeout stays timeout; earlier completion stays success/error. There is no detached
cleanup task, global task cancellation, unsafe isolation escape or new diagnostics stream.

Only registrations belonging to this client are cancelled. Shutdown does not cancel the
app's caller task itself or enumerate/cancel all tasks in an injected session. After the
registry drains, the leader invokes transport finalization exactly once, then records
closed and resumes all shutdown waiters.

| Session ownership | Finalization |
| --- | --- |
| Owned | Mark the adapter closed and call invalidateAndCancel once after this client's operations join; deinit does not repeat an explicit invalidation |
| Borrowed | Never invalidate/reset/flush the session; another client and app-owned work remain usable |

Foundation controls its subsequent native resource teardown. The library waits for its
workers/watchdogs and requests owned-session invalidation; it does not promise physical
connection termination at a particular instant. A borrowed session must still satisfy
[compatibility/lifetime rules](SESSION_TRANSPORT.md); external app invalidation is not
concealed by creating a replacement session.

Cancellation remains cooperative. A codec or other operation that does not return after
cancellation can delay shutdown, just as it can delay timed-call cleanup. Shutdown must
be initiated from an owning service/task boundary: work being joined must not itself
await the same client's shutdown. Deinit supplies only owned-session fallback cleanup;
use explicit shutdown for controlled closure. No hard latency/forced hook interruption
or release-readiness claim is made.

## Verification

The local full suite passed **170 test functions / 21 suites** with Swift warnings as
errors. ClientLifecycleTests covers:

- Empty and repeated shutdown, typed/raw rejection without further sends, and rejection
  during held cleanup before reading app options.
- Multiple shutdown callers, cancelled leader/follower/both and a pre-cancelled leader;
  cleanup remains owned and finalization happens once.
- Waiting through transport finalization, including a cancelled shutdown owner.
- Shutdown between admission and callback binding, without lost cancellation.
- Both timeout/shutdown orders and already selected success/error during cleanup.
- 64 simultaneously admitted, suspended client calls with distinct paths/headers/timeouts
  and alternating JSON codec strategies; all return the correct payload/metadata. The
  barrier requires all calls to enter transport, detecting global serialization.
- Registration release after transport/HTTP/decoding/validation/encoding failures and
  pre-cancellation, allowing shutdown to finish with no pending sleepers.
- Owned-session closure after joined calls, and two clients sharing a borrowed session:
  shutting down the first cancels its operation while the second's already active call
  completes normally; the original session remains usable afterward.

Native session tests use URLSession/URLProtocol on macOS/iOS/tvOS, with controlled
continuation/gate ordering and no public networking or wall-clock timing assertions.
watchOS uses explicitly scripted adapter I/O for unsupported URLProtocol interception;
that branch does not prove native watch networking or TLS. Existing I12 budget/race
and native stopLoading tests remain in the full suite. Public API tests import NetworkKit
without @testable and exercise shutdown through `any NetworkClient`.

[Issue #54](https://github.com/BK-Teisrud/NetworkKit/issues/54) records exact PR/main
hashes, five-runtime counts, source/DocC results and any isolated negative control before
acceptance. Minimum-OS, physical-device, complete TLS/privacy/resource and release gates
remain later work. No dependency, workflow, rule, paid service, tag or release is added.

Negative control: in an isolated source copy, removing the closed-admission guard
made `shutdownWithoutActiveWorkIsIdempotent` fail three assertions: typed/raw calls
unexpectedly succeeded and reached transport. The control built successfully;
repository source was unchanged.
