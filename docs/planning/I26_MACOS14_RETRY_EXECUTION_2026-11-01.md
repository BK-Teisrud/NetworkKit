# I26 — actual macOS 14 retry execution

[Manual run 41294523457](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41294523457) succeeds for accepted main `660f8c099faccdd4215ad5e4bf1d082faaa3e403` after PR #141/main run 41293485494 acceptance. The approved Xcode 26.3/Swift 6.2.4 builder and actual native ARM64 execution jobs both pass. The execution host reports **macOS 14.8.9 / 23J631**, not macOS 14.0 or this local Intel/macOS 15 host.

[Sanitized immutable evidence](evidence/I26_MACOS14_RETRY_EXECUTION_2026-11-01.json) preserves the exact manifest, source hashes, transfer checksums, real runtime, cases and resource results. A separate local download/extraction verified the payload against accepted HEAD and current source hashes, compared the manifest to execution evidence, and confirmed ARM64 slices and macOS 14.0 load metadata without executing those binaries on Intel. Full workflow logs were reviewed; no failed probe or hidden rerun is accepted.

## Native results

Six fixed HTTPS cases pass: typed/raw × disabled HTTP 503 (one SDK invocation), enabled HTTP 503 (two), and opted-in self-signed TLS rejection (one, NSURLErrorDomain/-1202 with the existing exact independent Foundation trust oracle). Each logical call emits one terminal event. Fixed public fixtures do not provide external wire counters; SDK invocations are not handshake/redirect/Foundation wire counts.

The independent loopback server validates each bounded resource workload's actual contacts:

| Workload, eight concurrent calls | Payload contacts including warmup | Peak process RSS | Reported live malloc at shutdown → after original deadlines |
| --- | --- | --- | --- |
| Disabled, 64 KiB | 97 | 14.44 MiB | 864,208 → 580,432 bytes |
| Retry, 64 KiB | 193 | 13.69 MiB | 882,720 → 630,736 bytes |
| Retry, 1 MiB | 193 | 33.02 MiB | 3,836,272 → 3,572,432 bytes |
| Cancel after first retryable replies, 64 KiB | 9 | 12.88 MiB | 729,488 → 495,648 bytes |

All eight cancellations join; no subsequent retry contact appears during the post-deadline sample. Server response-write observation is not an exact per-SDK-sleeper trace. Live malloc block counts fall after the original deadlines in every workload, but retained bytes/RSS do not return to zero or uniformly match another platform. The 1 MiB case retains approximately 3.41 MiB of reported malloc allocations at the final sample. This is neither a leak diagnosis nor a proof of leak absence.

Only one repetition per mode executes on this ARM64 hosted macOS 14 patch. Different OS/architecture/host/call rate and sampling prevent a causal overhead comparison with the local Intel results. The app workload remains unknown; buffered response size is not enforced. I27 must carry these concrete limits into its review and owner gate disposition. #29 still requires actual app/device/workload suitability and separate publication authorization.

## I26 acceptance and cleanup

The [Mac native/resource slice](NATIVE_RETRY_VERIFICATION.md), [16 actual minimum-simulator parameter cases](I26_MINIMUM_RETRY_2026-11-01.md), accepted current four-platform deterministic matrix and this actual macOS 14 observation now cover the selected I26 verification criteria under their explicit bounds. No physical-device result is inferred: Watch #132 remains a mandatory separate publication gate, and all other old F2 results retain their original source/runtime applicability.

The completed manual workflow is disabled immediately (`disabled_manually`) and removed in this cleanup PR. Its probe/controller and dated evidence remain available for custody/review; the existing retirement guard is not extended. No new runner, purchase, device/account/trust setting, SDK source or release/tag is changed. Candidate cleanup PR/main acceptance is still required before I26 is marked completed/Done and I27 starts. Return #109 from temporary P1 after that verified transition; no additional feature issue, milestone or speculative resource refactor is justified by these finite observations.
