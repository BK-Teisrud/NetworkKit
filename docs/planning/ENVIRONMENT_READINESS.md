# Test-environment readiness — PREP-01

## Accepted F2 closeout — 2026-10-31

F2 is CLOSED after PR #135/main `cc654ab5faadc0fc7fe00d7ad238b2e3ed5a997c`, [run 41242130528](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41242130528), with full-log verification of 218 Mac tests, four 215 simulator suites, 19 helpers and four manual-host provenance checks without failure/restart markers. #64/#27 are Done; direct item lists and GraphQL verify no open F2 issues/PRs. [Closeout evidence](F2_CLOSEOUT_2026-10-31.md) records the milestone summary-counter disagreement and actual verified states.

Original candidate evidence files retain their submission-time pending flags and exact executed SDK/platform/failure limits. The owner resource approval is F2-only. #132 physical Watch and #29 actual workload/device-memory/security/publication decisions remain mandatory in their separate milestone, with support unchanged. No release/tag, production suitability or F3 implementation is authorized.

PLAN-F3 #87 is Ready for planning only: review draft PR #111 and obtain a separate approved feature scope/start decision before code. Closed F2 is not publication or extension authorization.

## Earlier disposition — 2026-10-31 (superseded by current acceptance above)

Accepted implementation/verification baseline: main 5d2ae116ec685c483b1dcc31db9e41a850c4e2ac, PR #125, [main run 41182672027](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41182672027). Full logs confirmed 218 macOS root tests, four simulator results of 215 each, two unsigned host builds, 16 helpers and the required native TLS/smoke/control checks without unexpected restart or test time-limit failure. Root-CI targets are newer configured runtimes; they are not the minimum results below.

| Environment / scenario | Accepted evidence | Remaining requirement / next action |
| --- | --- | --- |
| iPhone/iOS 17.0 and iPad/iPadOS 17.0 simulators | Root 215 each; expanded opt-in native suites 19 declarations/40 parameter cases each, zero failures/skips/expected failures | Applicable remaining ENV claims and physical-family evidence are separate; no blanket minimum acceptance |
| Watch/watchOS 10.0 and TV/tvOS 17.0 simulators | Root 215 each in PR #120/main 40765690271 | Fresh expanded native suites executed on accepted source: TV 17/19 and Watch 16/19 declarations passed, zero skips; failed controls/timeouts remain unresolved. See MINIMUM_NATIVE_EXECUTION_2026-10-31.md. NET-04 #126 is the next bounded storage investigation; #62 retains timeout diagnosis. |
| macOS 14.8.9/23J631 ARM64 | Bounded public consumer/reuse/cancellation/100-cycle resource route passed in run 41179430976, preserved through PR #124 | Not full root regression, HTTPS, exact 14.0 or Intel behavior; preserve these claim limits under #62/#86 |
| Physical iPhone 17 Pro/iOS 27.2 | Accepted NET-01/02 public/lifecycle observations and NET-03 seven local declarations/14 cases; host removed after run | Background/network-loss/recovery and other applicable ENV scenarios remain under #63 |
| Physical iPad/Watch/TV | Owner reports available; older stored inventory is not fresh execution evidence | Fresh connection/model/OS/build, compatible supported test host/profile and concrete deployment approval where needed; #63 |
| Resources / distribution | Finite local/minimum/iPhone and bounded macOS 14 observations; root resource tests | Workload suitability/owner residual-risk disposition and #64 clean-consumer/archive/aggregate privacy report remain; no publication authorization |

Evidence: [minimum root regressions](MINIMUM_RUNTIME_EXECUTION_2026-10-28.md), [macOS 14 route](MACOS14_EXECUTION_ROUTE_2026-10-29.md), [NET-03 native results](NET03_NATIVE_LOOPBACK.md), [public HTTPS decision](PUBLIC_HTTPS_VERIFICATION.md), [NET-02 lifecycle/storage](NATIVE_LIFECYCLE_STORAGE.md). The owner selected public HTTPBingo/BadSSL rather than a paid/private server. Counted-contact claims use the local controlled fixture; public observations cannot supply maintainer-owned wire counters. No new generic environment issue is needed: #62/#63/#86/#64 retain their existing responsibilities.

## Historical preparation inventory and decisions

The following dated inventory/access tables describe the initial preparation, not today's missing-access claims. Later evidence above supersedes only its actual assertions; earlier timeouts, failures and uncertainty remain recorded.

Inventory date: 2026-10-26. Owner: @BK-Teisrud. Preparation task: [#85](https://github.com/BK-Teisrud/NetworkKit/issues/85). This is an access/scenario assessment, not product execution or compatibility certification. Actual release evidence remains in [I21 / #62](https://github.com/BK-Teisrud/NetworkKit/issues/62) and [I22 / #63](https://github.com/BK-Teisrud/NetworkKit/issues/63); security/trust review belongs to [I19 / #60](https://github.com/BK-Teisrud/NetworkKit/issues/60).

## Observed local inventory

Read-only commands: `xcodebuild -version`, `xcrun swift --version`, `sw_vers`, `uname -m`, and `xcrun simctl list runtimes --json`. No runtime was installed or booted, no physical device was paired, and no product tests were run for this preparation.

| Item | Observed value |
| --- | --- |
| Host | macOS 15.8.1, build 24H32, x86_64 |
| Xcode | 26.3, build 17C529 |
| Swift | Apple Swift 6.2.4, swiftlang-6.2.4.1.4 |
| iOS runtimes | 18.2 / 22C150; 18.5 / 22F77; 26.2 / 23C54 |
| tvOS runtimes | 18.2 / 22K154; 18.5 / 22L572; 26.2 / 23K51 |
| watchOS runtimes | 11.2 / 22S99; 11.5 / 22T572; 26.2 / 23S303 |

All listed runtimes report available and x86_64/arm64 support in the inventory. That does not prove a usable scheme/destination or successful execution. There are no installed iOS 17, tvOS 17 or watchOS 10 runtimes. iPhone/iPad simulator destinations share the installed iOS runtime family; each form factor still needs evidence.

## Minimum-version access matrix

“Unavailable locally” means absent from this observed machine, not impossible to obtain. “Unverified” means no usable access/execution evidence has been established. The owner answered “unknown” for exact physical inventory and access to older systems on 2026-10-26.

| Required environment | Local access | Other access / actual execution | Owner and next action | Release consequence |
| --- | --- | --- | --- | --- |
| iOS 17 on iPhone destination | Unavailable locally | Unverified | @BK-Teisrud, #62: establish a compatible official runtime/host or available device; record exact patch/build and run evidence | Missing minimum-iPhone evidence blocks release |
| iPadOS 17 on iPad destination | Unavailable locally | Unverified | @BK-Teisrud, #62: establish an iPad destination/device independently of the iPhone result | Missing minimum-iPad evidence blocks release |
| macOS 14 | Current host is 15.8.1 | Unverified | @BK-Teisrud, #62: locate a lawful accessible macOS 14 execution environment and determine a compatible built-test/harness execution route | Missing macOS 14 evidence blocks release |
| watchOS 10 | Unavailable locally | Unverified | @BK-Teisrud, #62: verify runtime/device and any paired-host requirements plus a supported test route | Missing minimum-Watch evidence blocks release |
| tvOS 17 | Unavailable locally | Unverified | @BK-Teisrud, #62: establish a compatible official runtime/host or available TV device | Missing minimum-TV evidence blocks release |

Apple's [Xcode system-requirements table](https://developer.apple.com/xcode/system-requirements/) lists Xcode 26.3 simulator/device support ranges containing iOS/tvOS 17 and watchOS 10. This is a compatibility lead, not evidence that those exact downloads are presently offered, installable on this Intel host, or runnable with this package. Verify all three before selecting a route. Its Xcode 26.3 development-host requirement starts at macOS 15.6: a macOS 14 execution target cannot be assumed to run that Xcode. A separately built test artifact/harness requires its own deployment, execution, signing and test-runner compatibility checks; no route has been validated here.

The same Apple table lists Swift 6.2.3 for the general Xcode 26.3 row, while the installed toolchain reports 6.2.4. Record actual build/compiler identities rather than silently changing the repository's verified 6.2.4 CI baseline. This preparation does not certify arbitrary Xcode 26.3 installations or newer device OS versions.

## Physical inventory and verified observations — 2026-10-31

| Device family | Exact model | Observed OS/build | Compatibility and execution boundary |
| --- | --- | --- | --- |
| iPhone | iPhone 17 Pro | iOS 27.2 / 24B119 | Accepted app-hosted regression/native evidence; actual background/outage/recovery and post-budget report accepted through PR #129, temporary host removed |
| iPad | iPad Pro 11-inch, 3rd generation | iPadOS 27.2 / 24B119 | 215 regression / 20 of 21 native declarations with supplemental strict TLS evidence; actual background/outage/recovery and post-budget report accepted through PR #129; temporary host removed |
| Apple Watch | Apple Watch Ultra 2 | watchOS 27.2 / 24S118 | Developer Mode verified enabled; post-restart developer-image mounting fails with CoreDevice 12040 / MobileDevice 0xe8000076. Rebuilt signed root host verified; no physical tests started |
| Apple TV | Apple TV 4K, 3rd generation | tvOS 27.2 / 24K122 | Owner completed pairing; Developer Mode/DDI verified; candidate 215 regression and 21 native declarations passed; temporary host removed |
| Mac | Current Intel host; owner reports MacBook Pro | macOS 15.8.1 / 24H32, x86_64 | Xcode 26.3 / Swift 6.2.4; accepted bounded local/native evidence and final 21-case suite. No universal workload-suitability claim |
| macOS 14 route | Standard GitHub ARM64 host | macOS 14.8.9 / 23J631 | Accepted prebuilt consumer, cancellation/reuse and finite resource controls; actual run 41204068268 passed ten HTTPS cases. No full-suite/exact-14.0/Intel result claimed |

Watch and TV registration/profiles/signing were specifically authorized for the existing three test IDs and existing certificate. No new certificate or optional service was added. The earlier Watch mode discrepancy is resolved. Developer-image mounting now blocks execution; host-usable image metadata does not establish successful device mounting. See [Watch preparation](evidence/F2_WATCH_PHYSICAL_PREPARATION_2026-10-31.json), [TV execution](evidence/F2_TV_PHYSICAL_EXECUTION_2026-10-31.json) and [iPad diagnostic](evidence/F2_IPAD_TLS_DIAGNOSTIC_2026-10-31.json). Candidate follow-up evidence still requires PR/main acceptance.

Before #63 execution, obtain the minimum necessary model/OS/build and connection details, or explicitly record inaccessible targets as gaps. Never collect/publish serial numbers, UDIDs, account identifiers or pairing records. “Current updates” is not a concrete OS version. Do not assume Xcode 26.3 can debug an unknown newer OS. Apple distinguishes [simulator testing from actual physical-device verification](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices); neither substitutes for the other.

## Reproducible execution scenarios

These are planned scenario IDs, not tests claimed to have passed. Run against the exact reviewed candidate commit after #60 and this preparation are accepted. #62 executes the five minimum-version destinations; #63 executes the available representative physical families and records a justified per-target applicability matrix. Platform-specific host/harness limitations must be resolved explicitly, never hidden as passes.

| ID | Scenario and expected result | Evidence owner |
| --- | --- | --- |
| ENV-01 | Build/deploy a minimal NetworkKit consumer/test host using only public APIs; perform typed JSON, raw Data and empty-response calls against controlled synthetic fixtures. Verify values/status/headers and expected status/decode errors | #62/#63; API guide from #59 |
| ENV-02 | Native URLSession HTTPS to a controlled endpoint with a system-trusted valid certificate succeeds. An invalid/untrusted/hostname-mismatched endpoint is rejected. Record the exact failing condition; make no TLS bypass or trust-root installation | #60 defines fixture/threat expectations; #62/#63 provide actual per-target execution |
| ENV-03 | A controlled redirect records destination requests and verifies origin/credential policy plus bounded loop/hop termination. Use synthetic markers; check typed/raw parity and the terminal-cancellation regression where applicable | #62/#63, referencing I09/I16 guides |
| ENV-04 | A fixture deliberately delays response/data. Exercise inactivity and total-budget expiration, cancellation during I/O, repeated cancellation and explicit shutdown. Record bounded termination and no subsequent owned activity; borrowed sessions remain app-owned | #62/#63; contract/tests from I12/I13 |
| ENV-05 | For owned/strict borrowed profiles, controlled cookie/cache/auth-challenge probes demonstrate selected storage behavior. For explicitly app-managed stores, verify declared ownership and app cleanup responsibilities using isolated disposable stores. No real credentials or shared-store mutation | #60 review and #62/#63 native evidence; STORAGE_VERIFICATION.md |
| ENV-06 | On representative physical devices, exercise foreground/background transitions and loss/recovery of a usable connection while a call is active, where supported. Verify defined completion/cancellation and safe diagnostics. No promise of background-transfer execution or automatic retry | #63; record actual interface/transition and platform applicability |
| ENV-07 | Exercise concurrent calls, cleanup and diagnostics with synthetic inputs. Record that diagnostics expose only allowed metadata and that repeated completion/shutdown does not leak observable active operations | #63, with measurements owned by #61 and privacy review by #60 |

Use a resettable fixture with request/event capture, fixed expected responses, explicit timing, and a clean isolated session per scenario. Select fixture addresses, certificate setup, device connectivity and any test-host signing route in #60/#62/#63 before execution; they are not provisioned here. Devices must reach the selected fixture: a Mac's loopback address is not automatically a physical device's server. Native HTTPS under the public client contract is required for credential scenarios; an explicit local HTTP exception is only suitable for permitted credential-free development probes. Do not expose test services to public networks by assumption.

The existing macOS-only native wire probes and scripted adapter tests are valuable but insufficient for an all-platform native evidence claim. In particular, watchOS scripted/assembly evidence cannot be relabelled as native URLSession server/TLS/device execution. If a native scenario cannot run, record the gap and its release impact; obtain a scope/support decision if it cannot be resolved.

## Evidence record and gap handling

For each scenario/target record: requirement and scenario ID, issue, exact candidate commit, date, Xcode build/compiler/SDK, OS version/build and architecture, simulator versus physical family/model, harness/command/fixture revision, synthetic setup, expected/observed result, repetitions and sanitized evidence link. Record failure and absent evidence explicitly. Redact private identifiers, credentials, response bodies and private network configuration from published logs.

1. #60 approves native trust fixtures, negative cases, privacy expectations and disposition of findings.
2. #62 resolves older-runtime/host access and records each minimum-version result. An available newer simulator is not a substitute. Keep unresolved access as an open release blocker.
3. #63 obtains exact inventory and execution compatibility, selects a minimal approved consumer/test-host route, and runs physical scenarios. It is independent of #62 but does not waive it.
4. #86 reconciles both sets with the v1 contract before #64 rehearsal; #29 remains the publication gate.

No new tracking issue is needed for these known gaps: #60/#62/#63 already own the work and remain open/Blocked by their actual prerequisites. Preparation may be accepted with these explicitly assigned unknowns. If investigation later reveals a distinct implementation defect or a change in supported platforms/tools, create a bounded issue/ADR and revisit priorities. Do not purchase equipment, install runtimes/tools/roots, downgrade devices, alter support minimums or publish releases as a side effect of this assessment.

## Backlog assessment

Keep PREP-01 ahead of I17 and keep the approved v1 scope unchanged. Once preparation is accepted, I17 remains the next implementation/review slice. The older-runtime access risk is confirmed, not solved; #62/#63 must stay open. Do not add duplicate issues or split milestones for missing inventory alone. Preserve standard hosted runners; the two PR #91 attempts that lost runners were infrastructure-capacity incidents, not demonstrated product defects. The successful PR checks and main run 40369219111 complete the preceding planning change; they do not resolve any environment gap above.

## I19 access update — 2026-10-26

The owner reports no available/known controlled HTTPS environment with a system-trusted certificate. ENV-02 remains unexecuted and release-blocking under #62/#63. See the [reviewed fixture contract](SECURITY_PRIVACY_REVIEW.md) for distinct trust success, invalid-chain and hostname-mismatch conditions. No endpoint, root installation, certificate purchase or trust bypass has been authorized.

## RES-01 handoff to ENV-07

[Repeated-call attribution](REPEATED_CALL_MEMORY.md) distinguishes completed NetworkKit operations from expiry-dependent runtime sleep-helper allocations and resident pages. For native resource evidence, record request rate, concurrency, response/retained-result sizes and selected total budget, with an observation after original deadlines. Use supported target profiling/harness tools; the standalone macOS heap inspector does not establish iOS/watchOS/tvOS results. Access, exact physical inventory and system-trusted HTTPS remain unverified; no Ready execution or residual-risk acceptance is inferred. #62/#63 own native results and #86/#29 owner disposition.

## TLS-01 native negative evidence

The [macOS rejection regression](NATIVE_TLS_REJECTION.md) exercises typed/raw public calls through real system-trust handling against a disposable untrusted certificate with a matching loopback SAN. Local results are certificate-specific; no trust root or verification bypass is installed. This is owned-session macOS evidence only. #62/#63 still require trusted success, independent hostname mismatch and actual minimum/physical environments; #86/#29 retain resource/risk/release gates. #104 acceptance requires its own PR/main checks.
