# I26 — native retry and resource verification

Current disposition, 2026-11-01: [actual macOS 14 execution](I26_MACOS14_RETRY_EXECUTION_2026-11-01.md) succeeds in run 41294523457. The temporary workflow is disabled; its removal/evidence cleanup awaits PR/main acceptance. Earlier preparation/pending statements below are historical. No physical pass or production/release acceptance is inferred.

Current follow-up, 2026-11-01: this Mac slice is accepted through PR #140/main run 41290108646. [New minimum retry observations and the expiring macOS 14 route](I26_MINIMUM_RETRY_2026-11-01.md) supersede the candidate-pending/minimum-not-executed status below only where explicitly recorded. I26 remains open; no physical or publication pass is inferred.

Date: 2026-11-01. Tracking: #109; ADR-0014 / NK-07-01/02/03/04/08/09. Accepted product base: PR #139/main `dc76e9cca4f96c73424dcbc0d2eee88bf589705a`, all seven jobs verified in main run 41287067291. This slice changes verification tools/tests/docs, not product sources. Required candidate PR/main CI and target-applicability review remain pending before I26 acceptance.

## Native macOS execution

Xcode 26.3 / Swift 6.2.4 / macOS 15.8.1 on Intel. The root suite adds five native retry declarations plus one opt-in TLS declaration; the complete local suite passes 243 tests in 31 suites. The two focused native suites pass seven declarations (including the existing TLS declaration). Kernel-assigned IPv4 loopback fixtures use bounded subprocess teardown and synthetic data, with no trust-anchor installation, TLS bypass, root change or persistent credential.

- Actual URLSession 429/503→success for typed/raw and owned/borrowed strict/borrowed appManaged with stores disabled: four counted HTTP contacts, two logical events and two invocations per call. Borrowed sessions remain usable after shutdown.
- Same-origin redirect: `/redirect`, `/target`, `/redirect`, `/target`, but only two library invocations. The second invocation restarts at the original URL. Denied cross-origin redirect: one source contact, zero target contacts, one invocation.
- Terminal 503: two contacts/invocations; disabled, malformed/over-cap/duplicate Retry-After and explicitly accepted 503: one. A real duplicate header is rejected on this observed Foundation runtime; this does not reconstruct fields discarded by another runtime/proxy.
- Retry-After 1 second is respected in monotonic server contact timestamps. No elapsed timing threshold is used for throughput/memory acceptance.
- Fresh untrusted TLS fixture with retry enabled: typed/raw each fail with the exact expected certificate rejection domain/code and one library invocation. No trust bypass or external certificate dependency is used. A library invocation count is not a handshake/wire count.
- Server records contain only path, monotonic contact time and a credential-presence boolean. Credentials/cookies are absent from loopback SDK traffic; no credential values or raw bodies are published.

## Explicit public HTTPS storage composition

The separate non-shipping PublicRetryTests declaration runs six actual HTTPBingo cases: typed/raw × owned/borrowed strict/borrowed appManaged. Disabled fixed-503 calls report one invocation; enabled fixed-503 calls report two, with one terminal event each. Active appManaged uses an isolated ephemeral synthetic cookie and memory-only cache, retains cookie/session ownership after shutdown, independently observes its cookie via the owner's session, and deletes it. Cache presence does not prove a hit or frozen cache/cookie state across attempts.

This is the previously owner-selected fixed public service, not a public load benchmark. It has no maintainer-controlled wire counter; SDK counts and local controlled-server counts remain distinct evidence. TLS uses normal system trust. No real account data, user credential, echo body, client IP or device identifier is published. Normal root tests/required CI do not run these public calls.

## Release resource workload

[Immutable measured JSON](evidence/I26_RETRY_RESOURCES_2026-11-01.json) records eight fresh child processes: two repetitions of disabled reuse 8×64 KiB, retry 8×64 KiB, retry 8×1 MiB, and eight cancellations after first retryable responses. Each throughput process performs three cycles of 32 logical calls plus one non-retry warmup. Every first retry response also buffers the selected payload. The server observes 97 contacts without retry, 193 with retry, and 9 for cancellation (warmup plus eight first responses; no later retry). Six connections are reused in each observed workload.

| Workload | Peak process RSS, two repetitions | Live malloc at shutdown → after original deadlines |
| --- | --- | --- |
| Disabled, 64 KiB | 7.36–7.43 MiB | 696,400–725,040 → 425,072–443,040 bytes |
| Retry, 64 KiB | 7.09–7.29 MiB | 707,424–750,928 → 439,104–477,968 bytes |
| Retry, 1 MiB | 17.86–19.09 MiB | 726,144–749,136 → 452,688–465,792 bytes |
| Cancel after first retryable replies | 6.11–6.14 MiB | 610,016–617,232 → 367,520–370,912 bytes |

The final sample is 12 seconds after shutdown, beyond every selected original ten-second total budget and three-second retry wait. All eight cancellations join before sampling. The fixture confirms its first response writes, not the exact suspension point of every SDK call; this is not a native per-sleeper trace. The deterministic I25 suite separately establishes cancellation during the actual retry sleep. Live malloc blocks fall in every case, consistent with [RES-01](REPEATED_CALL_MEMORY.md)'s existing expiry-dependent runtime observation. These aggregate malloc-zone statistics do not identify individual Swift sleep-helper objects or prove leak absence. RSS remains allocator/process state and need not return to its warm baseline. No stack/address/raw profiler log is published.

These results cannot establish that retry reduces overhead: retry changes elapsed time/call rate, two repetitions are a small sample, and this is one Mac/runtime. Previous F2 measurements use different sampling/rate; the old raw dataset is unchanged. The workload is a bounded diagnostic comparison, not the unknown consuming-app workload or a new limit/default. The library still buffers unbounded server responses; the old eight-active-call/expected-1-MiB advice remains provisional, not an enforced cap or production guarantee.

Provenance records accepted product commit, a product-source-tree SHA-256, probe/runner hashes, toolchain/SDK and measured dirty-checkout truth. Only verification files differ from accepted product sources; the measurements are not mislabelled as a clean future PR/main run. No paid service or production telemetry is involved.

## Platform applicability and remaining gates

| Environment | Retry evidence from this slice | Boundary |
| --- | --- | --- |
| This macOS 15.8.1 host | Actual URLSession loopback, TLS, public HTTPS storage composition and release resources | Not macOS 14 or a device-memory guarantee |
| Required current macOS/iOS/iPadOS/watchOS/tvOS CI destinations | Accepted PR #140/main run 41290108646: 243 Mac/four 234-test simulator runs | New minimum follow-up still requires its own candidate checks |
| Actual minimum OS / physical families | No new I26 execution claimed here | Prior F2 evidence remains historical, not retry-native proof; review exact applicability and unavailable environments in #109/#110 |
| Physical Watch and publication | Mandatory #132 and #29 remain open | No support, phase, workload-risk or release acceptance is inferred |

Missing access is not a passing skip. I26 stays open until required candidate checks and the target-applicability disposition are recorded. I27 retains the API/schema/guide/evidence review. The four selected delivery slices remain sufficient: no additional feature, timer rewrite, default change or milestone is justified by these measurements. Any further target execution belongs in existing #109, with publication blockers preserved rather than silently relaxed.

## Candidate CI correction — 2026-11-01

Initial PR run [41288560306](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41288560306) fails the platform checks on a Swift Testing macro diagnostic in PublicRetryTests: assigning `#require(settings.httpCookieStorage)` directly into an optional destination produces a redundant-require warning, elevated to an error. The earlier local public run also contained that warning; its runtime pass did not establish a warnings-clean build. Integrity and DocC passed, but that initial PR run is not accepted.

The test now unwraps into an inferred nonoptional local before assigning the optional ownership variable, following the existing storage-control pattern. All six public cases pass with `-warnings-as-errors`. The unsigned generic-iOS PublicHTTPSChecks app-host build-for-testing also passes with SWIFT_TREAT_WARNINGS_AS_ERRORS=YES and SWIFT_SUPPRESS_WARNINGS=NO; no installation, signing or device change occurs. Integrity and all 19 helpers pass again. Product sources, measurement probe/runner and frozen resource JSON are unchanged. No extra feature issue or general refactor is justified; the correction belongs to #109/PR #140. Required refreshed PR/main checks remain mandatory.
