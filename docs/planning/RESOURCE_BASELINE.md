# I20 — resource and package-quality baseline

Current gate disposition, 2026-10-31: the owner explicitly approved **only the non-publishing F2 rehearsal** with the documented runtime-retention, call-rate/payload/budget and finite-RSS limitations; see [GATE-F2 resource disposition](F2_REVIEW.md#resource-disposition-for-this-gate). The provisional eight-active-call / expected 1 MiB guidance is not an enforced cap or validated app fit. #29 still requires actual workload/device-memory suitability, security and publication authorization; #132 retains physical Watch evidence. No production suitability or release is approved. Earlier dated statements below preserve their original evidence limits.


Date: 2026-10-26. Product commit: `4d6d84b29c5b453adaefb644da98d320e9e6193a`, the accepted I19 merge. The measured product came from a clean local clone with no tracked modifications. I20 adds opt-in measurement tooling, CI smoke coverage and evidence; no production behavior, public API, dependency or support minimum changes. I20 was accepted through PR #101 and main run 40408266400 on [#61](https://github.com/BK-Teisrud/NetworkKit/issues/61). Later attribution is recorded in [RES-01](REPEATED_CALL_MEMORY.md); the original adverse measurements below remain historical evidence.

## Reproduction and measurement boundaries

Run `python3 scripts/benchmarks/run.py --output /private/tmp/networkkit-resources.json` from a clean checkout. Optional `--package /absolute/path/to/NetworkKit` selects a separate local checkout; the probe source comes from the runner's directory. Default is three repetitions per case; `--repetitions 1 --smoke` compiles/exercises short reuse and cancellation cases. The script requires macOS, Xcode/Swift, Python standard library and /usr/bin/time, without installs or external services. It builds a temporary standalone SwiftPM executable in release mode, Swift 6 and warnings-as-errors, using only `import NetworkKit`. Temporary consumer/build files are removed after execution. The product must be accessible under the repository's rights policy; the harness grants no usage permission.

The fixture binds only 127.0.0.1 on a kernel-assigned port, returns synthetic `x` bytes with no-store and HTTP/1.1 Content-Length, and records request/connection counters. Native calls use an explicit credential-free loopback development exception. It is not HTTPS, HTTP/2, internet latency, physical-device, JSON-decoding or server-throughput evidence. Requested task concurrency is not a guaranteed simultaneous wire-connection count. Do not infer a fixed URLSession pool size from total connection counts.

Each repetition launches a fresh process and fixture, warms one request, runs the stated cycles, joins all tasks, shuts down the client and samples RSS again after 100 ms. One reuse client/session spans cycles; the fresh-client control creates/shuts down one per workload call. Half of NetworkKit workload calls use typed endpoints and half raw URLRequest, with .data responses; every payload's length and contents are verified. The cancellation case waits for at least one native slow request to reach the server, cancels all eight calls and requires eight CancellationErrors with joined completion. It does not assert that all eight reached the wire before cancellation.

Reported per-call p95 covers the call plus payload validation and, in the fresh-client case, shutdown; it excludes fresh-client initialization, while whole-cycle times include initialization and task scheduling. The direct URLSession control uses an ephemeral, store-disabled session without NetworkKit's validation, delegate or deadline pipeline. For common setup, the direct control also retains an idle NetworkKit client object, but its workload I/O uses only the separate URLSession. It supplies a useful comparison, not an identical implementation or isolated attribution experiment. All measurements include harness/runtime overhead.

Current RSS comes from mach_task_basic_info; peak process RSS comes from macOS /usr/bin/time -l, in bytes. This is neither live allocation accounting nor physical-footprint, energy or leak measurement. The client object remains in scope after shutdown, and Foundation/Swift/allocator caches may retain memory. A 100 ms sample is not proof of long-term quiescence or secure erasure. Latency/RSS are observations, not volatile CI pass thresholds.

## Observed baseline

Environment: macOS 15.8.1 / 24H32, x86_64; Xcode 26.3 / 17C529, Swift 6.2.4, macOS SDK 26.2; Python 3.13.5. No other build/test workload was intentionally run concurrently with the final measurements. [Raw results](evidence/I20_RESOURCE_BASELINE.json) include exact environment, source commit, clean tracked-checkout flag, harness hashes, individual cycle samples and all three repetitions. MiB means 1,048,576 bytes; ranges below span the repetitions.

| Mode | Task concurrency | Response | Cycles × calls | Native payload connections, including warmup | Call p95 ms | Peak RSS MiB |
| --- | --- | --- | --- | --- | --- | --- |
| reuse | 1 | 64 KiB | 3 × 32 | 1 | 2.07–2.26 | 5.76–5.84 |
| fresh | 1 | 64 KiB | 3 × 32 | 97 | 2.60–2.89 | 8.17–8.26 |
| reuse | 8 | 64 KiB | 3 × 32 | 6 | 7.30–8.38 | 7.22–7.33 |
| reuse | 32 | 64 KiB | 3 × 64 | 6–7 | 18.70–22.47 | 9.59–9.98 |
| reuse | 8 | 1024 KiB | 3 × 32 | 6–7 | 28.00–30.21 | 23.40–24.09 |
| cancel | 8 | 64 KiB | Eight cancelled calls | 1 | Not applicable | 6.02–6.07 |
| reuse | 32 | 64 KiB | 100 × 64 | 16–43 | 16.48–16.81 | 15.49–16.14 |
| direct | 32 | 64 KiB | 100 × 64 | 6–9 | 14.78–15.85 | 9.17–10.70 |

All expected payload counts and contents passed. Sequential reuse required one connection for 97 requests; the fresh-client control required 97. These observations support reusing an account/origin-scoped client. Native connection totals over 6,401 requests varied; they are not limits configured by NetworkKit.

Eight-call cancellation joined in 2.23–3.85 ms after the verified-contact condition. Reused-client shutdown observations remained below 0.11 ms in these samples. These are measured local outcomes, not deadlines promised to callers or evidence that all native memory has been returned.

### Finding: repeated-call RSS needs attribution

Across the three 100-cycle NetworkKit runs (6,400 workload calls plus warmup), RSS rose from 8.08–8.19 MiB after cycle 1 to 14.39–14.76 MiB after cycle 100. Direct URLSession rose from 7.14–7.36 MiB to 9.07–9.60 MiB. The NetworkKit trend had not demonstrated a stable plateau. This difference is reproducible, but RSS alone does not identify retained objects, a leak, a runtime cache or a fixture effect. No unsupported zero-leak claim or arbitrary heap threshold is adopted.

[RES-01 / #100](https://github.com/BK-Teisrud/NetworkKit/issues/100) is a new P1 CORE task, Order 20.5, under #27 in F2. It must reproduce and attribute the trend with lifetime/allocation controls, make a small fix with a regression if a product defect is established, or document the evidenced cause and required owner disposition. It blocks #86. This is a concrete finding, not a generic refactoring ticket. Do not conceal it by increasing limits, suppressing the workload or adding a cache/scheduler/streaming module.

## Provisional use and investigation limits

Use a long-lived client per compatible account/origin context. For initial app evaluation, keep at most eight calls active, with expected buffered responses no larger than 1 MiB each; keep queued work and retained decoded values bounded in the app. This is a conservative workload-selection boundary drawn from the measured 8 × 1 MiB case (23.40–24.09 MiB peak process RSS here), not an enforced SDK limit or a guarantee on any device. The 32-call / 64 KiB cases are stress probes, not a recommendation for watchOS or unbounded queues. Resource acceptance remains conditional on #100 and actual target-device evidence.

A server's actual payload can exceed an app's expectation. v1 buffers data and does not provide a streaming size cap, so this advisory does not protect against a hostile/oversized response. Select controlled services with suitable limits and reconsider suitability if payloads cannot be bounded; a public response-size contract change requires an explicit bounded design. Do not silently promise a hard memory ceiling from content length or timeout. Keep the approved 30-second inactivity/60-second total defaults; these local probes provide no basis for changing production network timeouts.

## Package-quality verification and remaining gates

The baseline standalone release consumer resolves the local NetworkKit product with no external dependencies, compiles with warnings as errors and executes both public request forms. The package remains NetworkKit with one NetworkKit library/import, the approved four platform families and Swift 6 mode. LICENSE names Teisrud Development AS, all rights reserved; neither this check nor public repository visibility grants an open-source license. Verify notice/distribution requirements for the final authorized artifact in #64.

The candidate must additionally pass a fresh-checkout unit suite, package/source integrity and DocC; their actual results are recorded on #61/its PR. CI macos-core compiles and executes the short release probe on each change, without timing/RSS thresholds; the full local measured workload is opt-in. Existing full platform checks remain mandatory. A smoke success does not resolve the measured trend or certify all-platform resource behavior.

Next priority after I20 acceptance is #100, ahead of serial #62/#63 execution. Environment access work can proceed independently, but unavailable minimum runtimes, exact physical inventory and controlled HTTPS access remain genuine gaps. #86 requires #100 disposition plus the existing resource/platform/security reconciliation. #64 owns final consumer/archive/privacy-report verification and #29 owns actual release authorization. No additional milestone or deferred F3–F6 scope is justified by these results.

### Fresh-checkout candidate results

A second fresh local clone of candidate `fa1003d3760c03969a5d215bf462d56e17cbe36c` passed the full 217-test / 27-suite macOS suite with warnings as errors, source integrity plus all four CI-helper tests, and DocC conversion with warnings as errors. The public NetworkKit symbol graph contains 319 records, unchanged from the accepted API review. The standalone release smoke passed its five-request reuse assertion and eight joined cancellations after native contact. The checkout remained clean after all four checks. This verifies candidate package/guide/harness integration; it does not resolve #100 or any native HTTPS/minimum-OS/physical-device/distribution gate. Subsequent changes in this PR only record these results and clarify current planning text.

## RES-01 attribution update

[Repeated-call attribution](REPEATED_CALL_MEMORY.md) identifies expiry-dependent Swift sleep-helper/dispatch retention on this macOS runtime, reproduced without NetworkKit/networking and corroborated by native heap snapshots. Live allocations fall after original deadlines; RSS need not immediately fall. The new --post-budget mode adds this distinction without rewriting I20 raw data/hashes. The risk still needs target-device assessment and explicit #86/#29 owner disposition; default timeouts and public behavior are unchanged.
