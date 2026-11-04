# Cancellation and the whole-operation budget

I14 update: the [authentication provider](AUTHENTICATION_PROVIDER.md) now executes inside this operation boundary. The original I12 hook test remains historical evidence; dedicated provider cancellation/timeout/shutdown tests now supplement it.

I12 / [#53](https://github.com/BK-Teisrud/NetworkKit/issues/53), 2026-10-21.
The existing typed/raw public client now enforces the approved monotonic total budget
and isolates cancellation to each call. I13 / #54 adds [explicit shutdown and operation registration](SHUTDOWN_AND_CONCURRENCY.md); no provider, diagnostics or deferred module is introduced here.

## Timing and precedence

The client captures a synchronous ContinuousClock instant at method entry, before
reading endpoint options or suspending into its structured worker. The captured call
options are reused by preparation, avoiding a second read of a computed options getter.
Input creation performed by the app before calling the method is outside this budget.

| Limit | Default | Effective policy |
| --- | --- | --- |
| Inactivity | 30 seconds | URLSession request timeout; call override > client > default |
| Total | 60 seconds | Monotonic elapsed time through the final terminal decision; call override > client > default |

Raw URLRequest.timeoutInterval is not an explicit policy override. Use
NetworkCallOptions(inactivityTimeout:totalTimeout:). A total budget shorter than
inactivity is valid. Preparation/encoding, child scheduling, awaited transport and
response interpretation all consume the same budget. Checkpoints run before preparation,
after preparation, before transport, after transport and at final result selection.

The internal NetworkClock now reads time synchronously, so the start/checkpoints cannot
be delayed by an async clock actor hop. Its cancellable sleep remains async. Production
uses ContinuousClock; tests use a synchronized manually advanced clock without real sleeps.
Future provider/queue waits must stay inside this same operation boundary; the generic
suspending-hook test verifies that boundary without prematurely implementing I14.

All configured limits remain positive finite Double seconds. To avoid overflowing a
Duration/Instant for enormous values, the watchdog sleeps at most one day at a time,
rechecking the original elapsed-time budget after every wake. This is not a one-day cap.
Tiny sleeps round up to at least one nanosecond; elapsed-time checks still use the
selected budget. No Date/wall-clock timing, arbitrary upper policy cap or external clock
dependency is added. Tests include least-positive/greatest-finite Double and a two-day
budget crossing multiple watchdog sleeps without any real waiting.

URLSession still enforces its own request/resource limits. A larger library total cannot
extend a stricter borrowed-session resource limit. Owned sessions retain the existing
platform resource default rather than a hidden 60-second resource cap. System inactivity
semantics are those of URLSession; the library does not invent packet-progress events.

## Terminal causes and cleanup

Each operation owns one synchronized Result and two structured children: the worker
and the watchdog. The first recorded terminal result wins. Caller cancellation records
CancellationError through a synchronous cancellation handler. Expiration records
NetworkError.timeout(.totalBudget) before the task group cancels its children. Before
selecting a previously unselected completion, the worker checks observed task cancellation
and elapsed time, preventing a codec from delivering late success after expiration.

| Event | Observable result |
| --- | --- |
| Caller cancelled before entry or while work is active | CancellationError |
| Total budget expires first | NetworkError.timeout(.totalBudget), even if URLSession ends with cancelled |
| System reports NSURLErrorDomain / timedOut first | NetworkError.timeout(.system) |
| Unexplained system cancelled without recorded caller/total cause | NetworkError.transport with its domain/code |
| Valid success or ordinary failure already selected before later cancellation | Preserve that selected outcome |

System timeouts do not reliably identify inactivity versus resource/connectivity phase,
so they remain `.system`, not an assumed `.inactivity`. NetworkError.transportFailure
exposes safe domain/code for `.transport` and the known timedOut identity for `.timeout(.system)`;
other categories return nil. No userInfo, underlying error object, URL or payload is retained.
Descriptions continue to omit arbitrary error domains and sensitive data.

After the first child finishes, the group cancels and joins both children before return.
A cancelled watchdog is cleanup, not a new caller-cancellation event. No detached worker,
orphaned sleeper, retry, refresh, session-wide invalidation or getAllTasks cancellation
is used. Existing transport cancellation reaches URLSession.data(for:delegate:)'s own task.

Cancellation is cooperative. Synchronous codecs and cancellation-uncooperative operations
can delay cleanup/return; there is no hard real-time return bound. ContinuousClock advances
during system sleep but does not guarantee wakeup at expiration. The terminal decision is
made after response handling; joining cleanup can delay delivery and does not overwrite an
already selected result. A sent mutation may already have affected its server.

## Actual verification

The local full suite passed **158 test functions in 20 suites** with Swift warnings as
errors. OperationBudgetTests adds deterministic coverage for default and overridden
limits; pre-cancellation; cancellation during I/O; one cancelled call leaving another
active; encoding/options/decoding elapsed time; awaited hook time; system versus total
timeout; both orders of timeout/caller cancellation during held cleanup; success/error
selected before later cancellation; extreme values; multiple watchdog chunks; and zero
remaining sleepers/active operations after return. Continuations/gates establish event
ordering; no timing assertion relies on a wall-clock sleep.

The borrowed-session test checks both caller cancellation and total expiry. On
macOS/iOS/tvOS a held native URLSession/URLProtocol operation must invoke stopLoading,
and an independent app task must still succeed using the same session afterward.
watchOS uses explicit scripted adapter I/O because URLProtocol interception is unsupported;
that branch is not presented as real watch networking. Existing native redirect,
storage, response and public-consumer tests remain in the full suite. The new safe error
identity accessor is tested through import NetworkKit without @testable.

An isolated copied source removed the guard preserving an already selected result in
the cancellation handler. Both deterministic selected-completion cases failed: late
cancellation incorrectly replaced success and a decoding failure with CancellationError.
The repository source was unchanged by this negative control.

[Issue #53](https://github.com/BK-Teisrud/NetworkKit/issues/53) records exact PR/main
hashes, actual five-runtime results, source/DocC checks and any negative-control evidence
before acceptance. Minimum-OS/physical/TLS evidence and full v1/release readiness remain
later gates. Existing F1 review counts are dated evidence, not the new I12 suite count.
