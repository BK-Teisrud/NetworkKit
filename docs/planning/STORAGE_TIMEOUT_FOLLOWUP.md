# Native HTTP-probe liveness follow-up — BUG-01

Date: 2026-10-26. Task: [#95](https://github.com/BK-Teisrud/NetworkKit/issues/95). This acceptance blocker precedes I19; I18 / #59 remains unaccepted until its failed main evidence is reconciled.

## Observed failure and uncertainty

PR #94 passed all seven checks, but [main run 40382689252](https://github.com/BK-Teisrud/NetworkKit/actions/runs/40382689252) on `5ea73b3f8f4045bea23dd32bd0b8b3273c2a9358` failed. StorageIntegrationTests.strictProfileCannotServeAnAutomaticHTTPCacheEntry(borrowed: true) exceeded its original 60-second limit. Xcode restarted the test process. macos-core and quality-gate failed; the other platform/source/DocC checks succeeded. No accepted I18 main result exists from that run.

The retained log does not identify whether the storage server's readiness, strict I/O, raw cache positive control, client shutdown or child teardown stalled. Nearby socket warnings are not proof of a cause. This is distinct from previous jobs that never acquired a hosted runner. Do not erase the failure with a blind rerun or claim an OS/cache/product root cause without evidence.

## Concrete liveness and diagnostic changes

The previous test fixture performed an unbounded stdout read for its port and an unbounded Process.waitUntilExit in teardown. Its stderr pipe was never drained. The raw Foundation cache control used default timeouts that could exceed the enclosing test. These are observed source-level gaps even though the original stalled phase is unknown.

A macOS-only [test child-process helper](../../Tests/NetworkKitTests/BoundedFixtureProcess.swift) now bounds the readiness handshake to three seconds and 128 bytes, uses monotonic elapsed time with poll/read, and routes synthetic fixture stderr directly instead of retaining an undrained pipe. Teardown requests termination, waits at most one second, then force-stops only its owned running child and waits at most one additional second. A failed join is an assertion failure, not ignored acceptance. This is a test-helper boundary; Process launch/OS scheduling are not hard real-time guarantees.

The cache probe emits immediate, synthetic phase labels for owned/borrowed startup, each strict request, wire-record retrieval, client shutdown, positive cache control, teardown and completion. It logs no URLs, tokens, bodies or real account/device identifiers. The private raw positive-control session now has five-second request and ten-second resource limits. Library defaults, per-client 5/10 fixture limits and all original cache/owned/borrowed assertions remain unchanged. The suite's one-minute limit is unchanged.

No production transport/cache behavior is changed. If the test recurs, the phase labels and bounded child/raw-I/O failures narrow the next investigation. These changes do not prove that Foundation's internal cache path was the original cause or that the issue can never recur.

## Meaningful failure-path verification

[FixtureProcessTests.swift](../../Tests/NetworkKitTests/FixtureProcessTests.swift) is explicitly macOS-only. One test starts a child that never reports readiness and requires a startup-timeout error plus successful idempotent cleanup. Another waits for a child to install SIGTERM-ignore, then requires successful forced stop and idempotent cleanup. Only child processes created by these tests are signalled. Neither test contacts a network service.

These two declarations add native fixture-lifecycle coverage on macOS only. Other runtime destinations retain the 214 declarations from I18; do not create dummy passes elsewhere to make counts equal. The source inventory lists 216 declarations with these two marked macOS-only; actual counts must come from each runtime result.

Local final-candidate verification passed: `swift test --parallel -Xswiftc -warnings-as-errors` reported 216 tests / 26 suites; a separate StorageIntegrationTests run passed all eight test functions. Both owned/borrowed probes reached every phase through teardown/completion. Local DocC passed with warnings as errors on macOS 15.8.1 x86_64, Xcode 26.3 / 17C529, Swift 6.2.4. Hosted PR/main acceptance is pending and recorded in #95 and its PR after execution. The failed original run remains part of the acceptance record. Do not waive skipped/failed/incomplete tests, increase original timeouts, suppress native assertions or infer release readiness.

## Backlog adjustment

BUG-01 / #95 is P0 at Order 18.5 under testing epic #23 in F2. I18 #59 is explicitly blocked by #95, so I19 remains blocked transitively. #95 does not depend on #59 acceptance: this avoids a cycle while allowing repair of its main evidence. Remaining security/privacy/minimum-runtime/device/resource/release owners are unchanged.

Review the original timeout disposition after successful follow-up PR/main evidence. If a distinct unresolved defect appears, keep #95 open or create a precise blocking follow-up; a green run alone does not establish an undocumented root cause. No new milestone or product-scope change is justified. No parallel independent delivery is started at this failed-main boundary.

## PR #96 follow-up: redirect fixture boundary

PR run 40386411123 also failed, this time in sameOriginRedirectsHaveABoundedLifetime(GET), at the unchanged one-minute test limit. The process restarted. Both storage ownership probes subsequently reached every new phase through completion; those post-restart results are diagnostic evidence, not acceptance of the complete run. The original cache stall is not thereby explained.

The redirect server still duplicated the same unbounded readiness read, undrained stderr pipe and waitUntilExit pattern. Both native redirect fixtures now reuse BoundedFixtureProcess, eliminating the remaining copies of those unbounded operations in Tests. The GET/HEAD/loop/limit probe has immediate startup/native-request/session-invalidation/teardown labels and an explicit test-only ten-second resource ceiling while retaining its existing three-second request timeout and original one-minute test limit. Both denied-destination ownership paths also identify startup/teardown. All destination-count/status/hop/loop/cancellation assertions remain intact.

This extends the same BUG-01 instead of inventing a separate product defect or claiming a common internal OS root cause. The helper's existing no-readiness/SIGTERM-ignore tests cover its use by both fixture families. No additional test declarations or executable product changes are needed. The PR description and issue retain both failed runs; I18/I19 stay blocked pending successful, uninterrupted candidate evidence and review.

The extended local candidate passed all 216 tests / 26 suites and the separate three-function RedirectIntegrationTests suite. Every GET/HEAD/loop/limit phase reached completion. Structural checks and all four CI helper tests passed. These are local results; fresh hosted PR/main acceptance is still required.

## Accepted follow-up evidence

PR #96 latest head 23678d761a632f50b69c4a4e9322be83e7864324 passed all seven checks in run 40389390363 and merged as 21a204191eaa82a60ec88bf9f60ef57f5f054920. Main run 40390885712 passed all five runtime results (macOS 216/26; four other destinations 214/25), with all native phases complete and no timeout or process restart. #95 and I18 #59 are accepted for their bounded criteria; exact original internal stall cause is still unproven and R10 remains monitored by #23/#86. The failed original runs are preserved; no security/runtime/device/release gate is waived. QA-01 #97 is the next owner-requested review before I19.
