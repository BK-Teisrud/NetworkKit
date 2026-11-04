# Minimum-runtime regression execution — 2026-10-28

I21 / [#62](https://github.com/BK-Teisrud/NetworkKit/issues/62). Reviewed product/test source: main 5a5cfb2eed49065f0721e34c253292eacab0dd9c, after [PR #119](https://github.com/BK-Teisrud/NetworkKit/pull/119) and successful main run 40757232306. This follow-up changes evidence and planning only.

## Acquisition and boot history

[The acquisition record](MINIMUM_RUNTIME_ACCESS_2026-10-28.md) preserves the three exact authorized Apple archive imports, successful disk-image checks and earlier CLI/browser/boot/signature re-verification timeouts. No historical failure is replaced by a later pass.

After completed imports and a clean shutdown, one fresh iPhone 14 Pro / iOS 17.0 (21A328) boot-status observation exited 0 after approximately 69 seconds. This run completed the Preferences data migration. Earlier LaunchServices migration timeouts remain recorded; the successful follow-up does not establish their cause or prove that restarting is a universal fix. No simulator-data erasure, runtime patch, trust bypass, toolchain/support change or physical-device setting change was used.

## Actual regression results

The existing root-package NetworkKit scheme runs with the exact discovered simulator destination, unsigned builds, warnings as errors, parallel testing disabled, separate temporary derived data and a fresh xcresult. Each result must be Passed with 215/215 tests and zero failed, skipped or expected failures. Full logs must also show completed execution without unexpected restart or time-limit markers. The three macOS-only declarations retain their existing compile-time exclusions; they are not reported as skipped or executed on these targets.

| Destination | OS/build | Boot readiness | Root regression suite |
| --- | --- | --- | --- |
| iPhone 14 Pro | iOS 17.0 / 21A328 | Passed | 215/215 passed; zero failed/skipped/expected failures |
| iPad (10th generation) | iPadOS 17.0 / 21A328 | Passed | 215/215 passed; zero failed/skipped/expected failures |
| Apple Watch Series 9 (45mm) | watchOS 10.0 / 21R355 | Passed | 215/215 passed; zero failed/skipped/expected failures |
| Apple TV 4K (3rd generation) | tvOS 17.0 / 21J353 | Passed | 215/215 passed; zero failed/skipped/expected failures |
| macOS minimum | macOS 14 | No access route verified | Not executed |

The iPhone and iPad form factors are distinct results even though they share the same installed iOS runtime. The Watch route used a compatible task-owned iPhone/iOS 17 companion; pairing and both boot-readiness commands completed before the Watch regression run. All four task-owned destinations, including the companion, were shut down after their selected runs with exit 0. Only task-owned simulator destinations are started/stopped; no existing simulator data or physical-device app data is erased.

## Claim limits and next priorities

Root regressions include deterministic scripted transport/configuration assertions. A passed minimum simulator suite does not automatically supply the separate opt-in public HTTPS/native lifecycle observations, all ENV scenarios, physical-family coverage, minimum-target resource measurements, controlled server counters, application archive/aggregate privacy report or release authorization. macOS 14 remains an independent missing minimum target. #62/#63/#86/#64/#29 retain their actual remaining criteria.

Keep the existing #62 work item for minimum-target evidence; successful substeps reduce its access gaps without closing it. No product defect or need for a scheduler/framework/refactor is established by the observed first-boot migration behavior. Do not create a duplicate generic environment issue or change support minima to make the result appear complete.

[Sanitized execution evidence](evidence/MINIMUM_RUNTIME_EXECUTION_2026-10-28.json) records reviewed source hashes, actual xcresult device/OS/architecture and complete summaries. Raw results and local destination identifiers remain private.
