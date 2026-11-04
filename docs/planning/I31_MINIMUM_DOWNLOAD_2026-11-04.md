# I31 minimum simulator native download execution

Date: 2026-11-04
Status: Actual partial I31 runtime evidence; checkpoint PR/main acceptance pending.

## Route and result

Use existing task-owned iOS/iPadOS 17.0, tvOS 17.0 and watchOS 10.0 simulators, with the existing Watch/iPhone pair. The non-shipping SwiftPM scheme runs unsigned, Swift warnings as errors, parallel testing disabled, only the three public native download declarations. No runtime download, new simulator/pair, identity/profile, physical install or trust setting change.

| Actual destination | Runtime/build | Passed |
| --- | --- | --- |
| iPhone 14 Pro | 17.0 / 21A328 | 3 declarations / 6 parameter cases |
| iPad (10th generation) | 17.0 / 21A328 | 3 declarations / 6 parameter cases |
| Apple TV 4K (3rd generation) | 17.0 / 21J353 | 3 declarations / 6 parameter cases |
| Apple Watch Series 9 (45mm) | 10.0 / 21R355 | 3 declarations / 6 parameter cases |

All four xcresult summaries have zero failed/skipped/expected-failure tests, three passed declarations, command exit 0 and six unique expected owned/borrowed native markers. All task-started simulators, including the Watch companion, shut down with exit 0. Source hashes, sanitized environment/results and raw-log digests are in [evidence](evidence/I31_MINIMUM_DOWNLOAD_2026-11-04.json). Raw result bundles/logs/device identifiers stay private. These are **24 new actual parameter cases**, not inferred from compilation or copied core/retry evidence.

Each destination runs the [I31 live fixture](I31_NATIVE_DOWNLOAD_2026-11-04.md): stored bytes/content, empty and unknown-length files, oversize/206/503 rejection and server counts, same-origin/denied-target contacts, cancellation/shutdown after a server partial write and app-owned persistence. Mac-only capture/fault/resource declarations are excluded by source guards, not skipped into a false pass. The filtered suite excludes all public-service calls.

## Limits and privacy-correction provenance

These are Intel x86_64 simulator results, not ARM64/physical or every current OS environment. They do not execute trusted HTTPS/auth/app-managed storage or simulator resource measurements. Actual macOS 14 file downloads remain unproved after the old runner route's retirement. Missing I31 criteria stay explicit; #29/#132 publication barriers are preserved.

The runtime tests completed before the separately reviewed privacy-manifest correction. The functional SDK Swift and native fixture sources are identical; the old manifest hash is recorded so these runs are not mislabeled as validation of the updated resource. The corrected FileTimestamp/C617.1 bundle is validated separately by the updated packaged-resource test and required CI. This distinction does not turn a privacy test into a new native behavioral execution claim.

I31 #149 remains In Progress for the remaining criteria and source-specific review; I32 #150 retains its final API/docs/technical gate. No new issue/milestone, release/date or support downgrade is selected.
