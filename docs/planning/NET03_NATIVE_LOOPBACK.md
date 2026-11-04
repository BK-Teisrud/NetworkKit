# NET-03 native loopback verification

Tracking: [#122](https://github.com/BK-Teisrud/NetworkKit/issues/122). This is opt-in test infrastructure, not a production SDK change. The default test scheme is unchanged.

## Preserved local result — 2026-10-31

On the local Intel Mac, `swift test --package-path Tools/PublicHTTPSChecks --filter nativeLoopback` passed all seven selected test declarations in one suite (27.068 seconds), exit 0. The six device-host integrity tests also passed. Candidate/source and log hashes and numeric observations are preserved in [the evidence record](evidence/NET03_LOCAL_2026-10-31.json). The candidate is uncommitted work based on db1e4100d3d8303cb90e9f39fdd46553f3a67b8b; this is not evidence that main contains these tests.

The fixture listens only on IPv4 loopback. Selected checks cover typed/raw responses, counted redirect denial and loop limits, strict storage, observed-contact cancellation and shutdown, request/total budgets, private Foundation storage positive/deletion controls, and finite concurrent resource observations. The optional app host includes the same source; integrity checks reject omission. No public-service traffic is selected by this command.

Resource measurements cover 64 KiB payloads at concurrency four (65 requests per control including warm-up) and 1 MiB at concurrency eight (33 each), with NetworkKit/direct Foundation order balanced across payload sizes and a six-second observation after shutdown. These are whole-process RSS observations including the fixture, test frameworks and allocator, not isolated SDK allocation measurements, a universal cap or proof of absence of leaks. The private storage positive control is Foundation behavior; it does not prove SDK app-managed HTTPS cache/credential behavior.

## Evidence recovery and remaining work

The previous session's temporary device/simulator logs and execution sessions were unavailable when work resumed. Their outcomes are not accepted as verified evidence for this candidate. The phone currently appears disconnected. Preserve new xcresult summaries and sanitized provenance in the repository after actual execution; do not infer a physical result from a signed build or an earlier unlock reply.

Next: selected negative controls, minimum simulator execution of the expanded opt-in suite, physical execution through the previously authorized host, and remaining physical-family/transition coverage. I21 (#62), I22 (#63), reconciliation (#86), consumer/archive/privacy rehearsal (#64) and owner risk disposition remain open. NET-03 is their existing verification slice, not a new release scope or reason to change support minima.

The already prepared manual macOS 14 workflow was dispatched on 2026-10-31 after the documented brownout windows. Dispatch success is not execution success. Do not poll or wait unattended; inspect its outcome when the owner resumes work. It covers only the bounded consumer/resource route documented in [the access plan](MACOS14_EXECUTION_ROUTE_2026-10-29.md).

## Isolated negative controls — 2026-10-31

Two mutations were compiled and executed in temporary package copies; repository source bytes were unchanged. Replacing the cacheable response with `no-store` made the private cached-response assertion fail (one issue). Omitting caller cancellation made both typed/raw lifecycle cases fail with system timeout (two issues). Both runs exited 1 after successful compilation. This demonstrates that these selected assertions reject the deliberately broken controls, not comprehensive mutation coverage.

The cache classifier initially expected a different Swift Testing message and reported detection false. Full-log inspection showed the intended `Expectation failed` assertion; the harness classification was corrected without rerunning the cache control. The control logs and their hashes are preserved in the evidence record. The current full helper suite passed 16 tests. Accepted base main 86119dae802769bcffc709b164f08aaf9c28c6e7/run 41180726691 remains separate from this uncommitted test candidate.

## Scenario disposition

| Scenario | What this slice can establish | Remaining boundary |
| --- | --- | --- |
| ENV-01 | Native typed/raw JSON, Data, explicit empty and status-before-decode on loopback; separate public HTTPS cases | No claim beyond the actual recorded targets/candidate |
| ENV-03 | Same-origin redirect, cross-port denied-destination counter and reachable positive control, bounded loop rejection | Credential forwarding across HTTPS origins and unrecorded platforms remain separate |
| ENV-04 | Observed-contact cancellation/shutdown, closed-client admission and request/total budgets | Physical background/network-loss transitions are not simulated by caller cancellation |
| ENV-05 | Strict owned/borrowed cookie/cache/credential absence; private Foundation cookie/cache/challenge/deletion positive controls | Foundation controls do not prove SDK app-managed HTTPS cache/credentials |
| ENV-07 | Finite bounded concurrency, diagnostic event counts, joined fixture cleanup and post-budget whole-process RSS | Target workload suitability, long-running behavior and residual-risk disposition remain |

No new milestone or duplicate environment issue is warranted. NET-03 supplies a reviewable verification slice; #62/#63 own the broader missing scenarios, #86 owns reconciliation and #64 owns consumer/archive/privacy acceptance. Production sources and support minima are unchanged.

## New target results — 2026-10-31

The fresh run on the iPhone 14 Pro / iOS 17.0 (21A328) simulator passed the complete opt-in suite: 19 declarations / 40 parameter cases, zero failures/skips/expected failures. Public HTTPS and local loopback portions are both included. This is distinct from the earlier unavailable temporary results.

The fresh physical iPhone 17 Pro / iOS 27.2 (24B119) run selected only the seven local loopback declarations / 14 parameter cases: all passed with zero failures/skips/expected failures. Full logs showed four resource-control observations and no unexpected restart or test time-limit failure. The pre-existing compatible profile matched the embedded profile, the actual signer was an existing valid identity, and deep strict signature verification passed. No provisioning-update or device-registration flag was used. Afterward, uninstalling only NetworkKitDeviceHost succeeded (exit 0).

Before that successful execution, local command preparation hit an incorrect Xcode destination reference and then an automatic-signing/hash-selector conflict. Neither attempt ran tests. The destination and Apple Development selector were corrected; the certificate extraction syntax was also corrected before execution. These were local verification-command errors, not SDK defects or Apple account changes. The previous unavailable execution records remain unverified rather than being replaced by inferred passes.

[Sanitized target evidence](evidence/NET03_TARGETS_2026-10-31.json) retains exact source hashes, summaries, scalar resources and cleanup. These results do not supply physical iPad/Watch/TV, background/network-loss transitions, full minimum-family native coverage or archive/privacy rehearsal. The current source-integrity run and 16 helper tests passed. F2 remains open.

The fresh iPad (10th generation) / iPadOS 17.0 (21A328) simulator run also passed 19 declarations / 40 parameter cases with zero failures/skips/expected failures. Both minimum simulator logs showed all four resource-control observations without unexpected restart or test time-limit failure. Both task-owned simulators were shut down successfully (exit 0); no data erasure or runtime/settings change occurred. These are candidate observations pending PR/main acceptance, not automatic completion of I21/I22.

## Accepted slice

PR #125 merged as 5d2ae116ec685c483b1dcc31db9e41a850c4e2ac; main run 41182672027 passed all seven checks after full-log/source review. NET-03 #122 is Done. Earlier candidate/review-pending descriptions above retain their execution chronology. Acceptance covers this bounded slice and its recorded assertions; I21/I22/F2 and owner workload/risk gates retain all remaining requirements.
