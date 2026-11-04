# F2 selected-requirement reconciliation — GATE-F2 review

## Accepted F2 closeout — 2026-10-31

F2 is CLOSED after PR #135/main `cc654ab5faadc0fc7fe00d7ad238b2e3ed5a997c`, [run 41242130528](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41242130528), with full-log verification of 218 Mac tests, four 215 simulator suites, 19 helpers and four manual-host provenance checks without failure/restart markers. #64/#27 are Done; direct item lists and GraphQL verify no open F2 issues/PRs. [Closeout evidence](F2_CLOSEOUT_2026-10-31.md) records the milestone summary-counter disagreement and actual verified states.

Original candidate evidence files retain their submission-time pending flags and exact executed SDK/platform/failure limits. The owner resource approval is F2-only. #132 physical Watch and #29 actual workload/device-memory/security/publication decisions remain mandatory in their separate milestone, with support unchanged. No release/tag, production suitability or F3 implementation is authorized.

PLAN-F3 #87 is Ready for planning only: review draft PR #111 and obtain a separate approved feature scope/start decision before code. Closed F2 is not publication or extension authorization.

## Source, IDs and claim boundary

Re-read original specification v1.0 §4.1–4.4, §4.13–4.16, §4.18 and §4.20. Stable NK-domain subrequirement IDs below follow original bullet order, including bullets continued across pages. These IDs add traceability, not scope. Selected/partial/deferred dispositions interpret already accepted [v1 scope](V1_SCOPE.md) and ADR-0003/0005/0006/0007; they do not override them. A mismatch must receive an explicit impact decision, never be silently declared delivered.

Evidence IDs refer to exact named tests in [the contract ledger](TEST_EVIDENCE.md) and [current inventory](TEST_INVENTORY.md). Each row inherits the accepted baseline/run above; issue IDs identify original slices, with their PR/main history on GitHub. Tests prove the bounded assertions under the ledger's scripted/native platform limitations, not universal target behavior. Selected/partial rows are reconciled against the accepted F2 evidence and explicit phase deferrals below; none closes its epic by table membership. The original ledger remains a dated snapshot; this review supplies its current gate disposition without changing historical counts. Keep historical run counts unchanged.

## NK-01 / #8

Contract: [HTTP_API_CONTRACT.md](HTTP_API_CONTRACT.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-01-01 | HTTP methods | Selected | H01/H07/H14; I02/I05/I10 |
| NK-01-02 | System-negotiated HTTP versions | Foundation-owned; no protocol-version guarantee | SESSION_TRANSPORT.md; I08 |
| NK-01-03 | Buffered body types | Selected | H06/H14; I05/I10 |
| NK-01-04 | Default and call headers | Selected | H02/H07; I02/I05 |
| NK-01-05 | Cookie storage | Partial: strict default; explicit compatible app-managed borrowed stores | S05–S07; I16 |
| NK-01-06 | Redirects | Partial: bounded same-origin GET/HEAD; unsafe replay refused | S02/S03; I09/I16/BUG-01 |
| NK-01-07 | Timeouts | Selected with defined inactivity/total/resource distinctions | L05/L07/L08/L12; I12 |
| NK-01-08 | Cancellation | Selected | L06/L08/L09; I12/I13 |
| NK-01-09 | Task priority control | Deferred: no public transport priority promise | V1_SCOPE.md |
| NK-01-10 | Raw URLRequest | Selected within shared validation/security | H05/H08/H12; I04/I10 |
| NK-01-11 | Interceptors | Deferred | V1_SCOPE.md |

## NK-02 / #9

Contract: [HTTP_API_CONTRACT.md](HTTP_API_CONTRACT.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-02-01 | Typed endpoint | Selected | H03/H12/P01; I04/I10 |
| NK-02-02 | Injected base URL | Selected | H03/H05/L01; I03/I04 |
| NK-02-03 | Path components | Selected | H03; I04 |
| NK-02-04 | Query encoding | Partial: ordered repeated/nil/empty decoded items; no arbitrary encoder | H04; I04 |
| NK-02-05 | URL validation | Selected | H03/H05/S01; I04/I09 |
| NK-02-06 | Automatic API versioning | Deferred; app may explicitly choose path/header | V1_SCOPE.md |
| NK-02-07 | Per-endpoint policy | Partial: auth/timeouts/response/status; cache/retry products deferred | H11/L05/S08; I07/I12/I14 |

## NK-03 / #10

Contract: [HTTP_API_CONTRACT.md](HTTP_API_CONTRACT.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-03-01 | Generic JSON decoding | Partial: native value-configured codec; no injected arbitrary decoder | H09/H12; I07/I10 |
| NK-03-02 | Codec strategies | Partial: documented native value strategies; no arbitrary converter callback | H06/H09/L02/L03; I05/I07 |
| NK-03-03 | Raw Data/text/metadata | Selected | H10/H12; I07/I10 |
| NK-03-04 | Explicit empty responses | Selected | H10/H12; I07/I10 |
| NK-03-05 | Status and headers | Selected as NetworkResponse wrapper | H11/H12/P01; I07/I10 |
| NK-03-06 | Content-Type | Partial: defined JSON/text validation; Data does not impose content type | H09/H10; I07 |
| NK-03-07 | Streaming | Deferred | V1_SCOPE.md |
| NK-03-08 | Custom decoder formats | Deferred | V1_SCOPE.md |

## NK-04 / #11

Contract: [HTTP_API_CONTRACT.md](HTTP_API_CONTRACT.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-04-01 | Transport identity | Partial: safe domain/code; no arbitrary underlying error retention | H13; I02/I10 |
| NK-04-02 | HTTP failure | Partial: status/headers; no captured error body | H09/H12/H14; I07/I10 |
| NK-04-03 | Encoding versus decoding | Selected | H08/H09/H12; I05/I07/I10 |
| NK-04-04 | Timeout versus cancellation | Selected; CancellationError remains separate | H13/L05–L08; I12 |
| NK-04-05 | Security errors | Selected safe structured failure; recorded native trust evidence, physical Watch before publication | S01–S04/TLS-01; I09/#104 |
| NK-04-06 | Retry classification | Deferred | V1_SCOPE.md |
| NK-04-07 | Safe diagnostic context | Selected fixed metadata, no payload | S11–S13; I15 |

## NK-13 / #20

Contract: [SANITIZED_DIAGNOSTICS.md](SANITIZED_DIAGNOSTICS.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-13-01 | Structured logging | Partial: one terminal event with elapsed/outcome/status; no start-event stream | S11/S12; I15 |
| NK-13-02 | Redaction | Selected by allowlist/exclusion, not arbitrary string scrubbing | S11/S13; I15 |
| NK-13-03 | Request identifiers | Selected per-call random ID; not a mathematical no-collision claim | S08/S10/S13; I14/I15 |
| NK-13-04 | Task metrics | Deferred | V1_SCOPE.md |
| NK-13-05 | Signposts | Deferred | V1_SCOPE.md |
| NK-13-06 | Logging configuration | Partial: optional sink off by default; no levels/sampling product | S11; I15 |
| NK-13-07 | Injectable diagnostics sink | Selected | S11–S13/P01; I15 |

## NK-14 / #21

Contract: [CONCURRENCY_AND_LIFECYCLE.md](CONCURRENCY_AND_LIFECYCLE.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-14-01 | async/await | Selected | H12/P01; I10 |
| NK-14-02 | Sendable | Selected Swift 6 strict checking | C01/C02; I01/I06 |
| NK-14-03 | Shared-state isolation | Selected via bounded synchronization/operation ownership; actors where appropriate, not actor-only | L01–L04/L09/L10; I03/I08/I13 |
| NK-14-04 | Cancellation propagation | Partial: core/auth-provider work; retry/refresh/transfers deferred | L06/L08/S09; I12/I14 |
| NK-14-05 | Batch task groups | Deferred public batch API; internal joined tasks are implementation | V1_SCOPE.md |
| NK-14-06 | AsyncSequence | Deferred | V1_SCOPE.md |
| NK-14-07 | Deduplication | Deferred | V1_SCOPE.md |
| NK-14-08 | Shutdown/session ownership | Selected | L04/L09–L11; I08/I13 |

## NK-15 / #22

Contract: [CONFIGURATION.md](CONFIGURATION.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-15-01 | Environment selection | Selected immutable base URL per client | H03/L01; I03/I04 |
| NK-15-02 | Session injection | Partial: compatible foreground URLSession and explicit ownership/profile | L04/S05; I08/I16 |
| NK-15-03 | Policy values | Partial: accepted security/auth/timeout/status; retry/cache deferred | L01/S01/S02/S08; I03/I09/I14 |
| NK-15-04 | Default/override headers | Selected | H02/H07; I05 |
| NK-15-05 | Network cost controls | Deferred public control; document current native defaults and applicability | V1_SCOPE.md; ENV-06 |
| NK-15-06 | Immutable snapshots | Selected | H02/L01/L02/L10; I03/I05/I13 |

## NK-16 / #23

Contract: [CI_AND_TEST_PLAN.md](CI_AND_TEST_PLAN.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-16-01 | Mock consumer client | Selected app injection examples, not separate testing product | P01; I18 |
| NK-16-02 | URLProtocol stubs | Selected scoped fixtures; scripted results distinct from native | H12/L04; I08/I10 |
| NK-16-03 | Request assertions | Selected | H03–H08/H14; I04/I05/I10 |
| NK-16-04 | Clock/timeout tests | Partial: core deadline/cancellation; retry deferred | L05–L08; I12 |
| NK-16-05 | Auth concurrency | Partial: provider/account isolation; refresh deferred | S08–S10; I14 |
| NK-16-06 | Cancellation cleanup | Selected | L06/L08–L11; I12/I13 |
| NK-16-07 | Cache test engine | Deferred; core storage-profile probes retained | S05–S07; I16 |
| NK-16-08 | Controlled integration server | Selected controlled local/public fixture scope; physical Watch deferred only by ADR-0013 | S03/S06/#104/ENV-01–07; #62/#63 |
| NK-16-09 | Performance evidence | Partial: measured baseline/attribution and bounded target observations; owner workload/publication disposition remains | RESOURCE_BASELINE.md/REPEATED_CALL_MEMORY.md; I20/RES-01/#62/#63 |

## NK-18 / #25

Contract: [SECURITY_PRIVACY_REVIEW.md](SECURITY_PRIVACY_REVIEW.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-18-01 | No sensitive default logs | Selected | S11–S13; I15/I19 |
| NK-18-02 | Ephemeral/strict storage | Selected no automatic owned stores; compatible borrowed profiles explicit | S05–S07; I16 |
| NK-18-03 | Credential isolation | Selected core provider/account/origin binding; app owns persistence | S08–S10; I14 |
| NK-18-04 | Protected payload files | Deferred SDK payload-file feature; no such persistence selected | V1_SCOPE.md; I19 |
| NK-18-05 | Cache deletion API | Deferred custom cache feature; app owns opted-in stores/deletion | STORAGE_VERIFICATION.md; I16/I19 |
| NK-18-06 | No external telemetry | Selected no SDK external service/sink default | S11–S13; I15/I19 |
| NK-18-07 | Data minimization | Selected fixed diagnostics and safe errors; returned headers remain caller responsibility | H13/S11–S13; I10/I15/I19 |

## NK-20 / #27

Contract: [API_REVIEW.md](API_REVIEW.md).

| Stable requirement | Source bullet | Accepted v1 boundary | Supporting evidence / slice |
| --- | --- | --- | --- |
| NK-20-01 | Client creation/injection | Selected | P01/DocumentationExamplesTests; I18 |
| NK-20-02 | Typed endpoints | Selected | H03/H12/P01; I04/I10/I18 |
| NK-20-03 | Small protocols | Selected reviewed NetworkClient/Endpoint/provider/sink boundaries | API_REVIEW.md; I18 |
| NK-20-04 | Escape hatches | Partial: raw URLRequest/compatible URLSession, no policy bypass | H05/H08/S05/P01; I04/I08/I16 |
| NK-20-05 | DocC | Selected build/compiled examples; final rehearsal remains | C04/P01; I18/#64 |
| NK-20-06 | Examples | Partial: HTTP/auth-provider/testing; upload/WebSocket deferred | DocumentationExamplesTests; I18 |
| NK-20-07 | SemVer | Selected documented policy; actual release decision pending | ../governance/RELEASE_POLICY.md; #64/#29 |
| NK-20-08 | Migration | Selected policy; no invented prior release migration | ../governance/RELEASE_POLICY.md; #64 |
| NK-20-09 | CI platform matrix | Selected four families/five runtime results; minimum/physical separate | C01–C07; I06/#62/#63 |

## Cross-cutting extension foundations

#12 / NK-05: only once-per-call headers, explicit opt-out and account/origin binding are selected (S08–S10, I14). Login, Keychain, OAuth/OIDC and refresh remain deferred. #13 / NK-06: HTTPS/system trust, safe redirects and credentials are core foundations (S01–S04, I09/I19/TLS-01); pinning/mTLS/HMAC/custom trust remain deferred. #24 / NK-17: session reuse, baseline and attribution support core quality (L04, I20/RES-01); coalescing, streaming and optimization products remain deferred. #26 / NK-19: declared platforms and availability support core (C01/C02, I18); background transfers, local discovery, app groups and visionOS remain deferred. Keep these extension epics open: foundations do not deliver their future catalog.

## Accepted epic scope and retained obligations

| Epic | Reviewed stable IDs | Selected delivery and explicit exclusions | Disposition after this review PR/main acceptance |
| --- | --- | --- | --- |
| #8 HTTP | NK-01-01–11 | Methods/headers/body, storage profile, bounded safe redirects, timeout/cancellation and raw requests; no priority API/interceptors | Accepted/closed through #86 and PR #134/main 41238957032; Watch execution remains #132/#29 |
| #9 endpoints | NK-02-01–07 | Safe typed/raw URLs, ordered query and per-call core policy; no automatic API versioning or retry/cache product | Accepted/closed through #86 and PR #134/main 41238957032 |
| #10 responses | NK-03-01–08 | Buffered JSON/Data/text/empty/status/metadata and value strategies; no streaming/custom decoder framework | Accepted/closed through #86 and PR #134/main 41238957032 |
| #11 errors | NK-04-01–07 | Structured safe categories, separate cancellation and metadata; no retry classification/error-body capture | Accepted/closed through #86 and PR #134/main 41238957032 |
| #20 diagnostics | NK-13-01–07 | Disabled-by-default fixed terminal sink, request identity and exclusion of sensitive fields; no metrics/signposts/levels/sampling product | Accepted/closed through #86 and PR #134/main 41238957032 |
| #21 concurrency | NK-14-01–08 | Swift 6 isolation, per-call cancellation, explicit joined shutdown and session ownership; no batch/stream/deduplication product | Accepted/closed through #86 and PR #134/main 41238957032 |
| #22 configuration | NK-15-01–06 | Immutable values, explicit ownership/storage/auth/timeout/status and headers; no mutable singleton/network-cost API | Accepted/closed through #86 and PR #134/main 41238957032 |
| #23 testability | NK-16-01–09 | Injectable client examples, scoped fixtures, timing/auth/cleanup tests, local/public native and bounded resource records; no custom cache test engine | Accepted/closed through #86 and PR #134/main 41238957032 with exact native/applicability limits and physical Watch #132 retained |
| #25 privacy | NK-18-01–07 | No default sensitive diagnostics/telemetry or owned stores; app owns opted-in stores/deletion; no SDK payload-file or custom-cache deletion feature | Eligible for selected product/F2 scope closure; actual distribution report is #64, app practice/workload/security publication decision remains #29 |
| #27 developer experience | NK-20-01–09 | Reviewed public API, compiled DocC/examples, platform/CI and policy | Closed/Done after #64 acceptance through PR #135/main 41242130528; separate publication #29 remains open |

The nine selected-core closures are now recorded against accepted PR #134/main 41238957032. No future catalog item is implemented or waived by closing its selected core domain. [Cross-cutting extension foundations](#cross-cutting-extension-foundations) keep #12/#13/#24/#26 open under their future planning owners.

## Current disposition of original evidence gaps

| Ledger gap | Reconciled phase evidence | Remaining boundary and owner |
| --- | --- | --- |
| G01 native trust | NET-01/02/03/04, #104, actual macOS 14 and non-Watch target records; independent invalid-chain/hostname witnesses | Physical Watch #132/#29; public responses are not controlled-contact counters; preserve iPad original failure and supplemental result |
| G02 native lifecycle/network behavior | Local native counters/timeout/cancellation/storage and four accepted physical transition reports | Document selected applicability; no automatic retry, background-transfer or arbitrary network-cost promise; physical Watch #132 |
| G03 minimum and physical access | #62 accepted five minimum-family destinations within exact patch/architecture/suite limits; revised #63 non-Watch scope accepted | No exact macOS 14.0/Intel14/full older-host suite claim. Physical Watch is explicitly deferred only by ADR-0013, not passed |
| G04 privacy/storage/manifest | #60 review, strict profiles, isolated app-managed cookie deletion and Foundation controls; payloads are not persisted by the SDK | Foundation cache/challenge positives do not prove an SDK app-managed HTTPS feature beyond the selected contract. Source review confirms appManaged retains the supplied session/cache behavior while rejecting credential stores; strict mode overrides automatic storage. Controlled local policy/counter tests and native public TLS observations are separate evidence, not a claimed exhaustive combined HTTPS fixture. Actual archive/aggregate manifest rehearsal #64; app practice and release owner decision #29 |
| G05 API/availability/examples | #59 accepted, external consumer tests and byte-matched compiled DocC examples; actual selected builds/minimum-family scope | Preserve public/private seam, rights and runtime limits; final package/installation rehearsal #64 |
| G06 resources | #61/#100 attribution, controlled local/native comparisons and bounded per-target post-budget reports | Owner explicitly approved only the non-publishing F2 rehearsal with the stated limitations. No universal RSS cap or workload suitability; #29 still requires actual workload/rate/payload/budget/device-memory assessment; physical Watch #132 |
| G07 governance/rehearsal/release | This #86 review and accepted ADR-0013/non-Watch matrix | This review PR/main, then #64/#27 and F2. Separate #29/#132 publication milestone remains open; no tag/release/F3 start |

## Resource disposition for this gate

Technical assessment: existing evidence attributes a substantial transient component to runtime sleep-helper/dispatch storage surviving logical cancellation until original deadlines on measured runtimes. Remaining resident-page ownership is not exhaustively attributed. No retained NetworkKit operation graph requiring a small product fix was established. A new scheduler/clock rewrite, arbitrary performance threshold, unsupported device guarantee or generic refactoring ticket is not justified by these results.

Owner decision, 2026-10-31: explicitly APPROVED for the non-publishing F2 rehearsal only. Translated owner reply: “Approve only the F2 rehearsal with these limitations.” The original approval remains in the conversation. The concrete question explains call-rate, payload/budget and process-memory limits, including that the provisional eight-active-call / expected 1 MiB guidance is not an enforced cap or validated production fit. #29 must still obtain the actual app workload and a separate suitability/security/publication decision; no production risk acceptance is inferred. This bounded phase disposition is recorded; no production suitability, publication or universal memory guarantee is approved.

## Completed phase sequence and remaining gates

1. #62, revised #63, #86 and the nine selected-core epic closures are accepted under their recorded PR/main evidence and approved F2-only resource disposition.
2. #64's executed non-publishing rehearsal is accepted through PR #135/main 41242130528; #27 then completed. F2 is CLOSED with empty open-issue/open-PR connections; the summary-counter disagreement is recorded in the closeout evidence.
3. #132 physical Watch and #29 actual workload/security/publication decisions remain mandatory. Support is unchanged, no release/tag exists, and F3 implementation still requires its own scope/start decision. #87 is Ready for planning only; #12/#13/#24/#26 remain deferred extension epics.

## Forward quality and backlog assessment

The remaining problem was outdated current-state reporting and incomplete evidence-to-epic disposition, not a newly established SDK defect. Refresh current gate rows and issue acceptance while preserving historical snapshots. Existing tests, native fixtures and review tasks cover the selected scope; no extra product dependency, feature, refactor, duplicate issue or milestone is selected. WATCH-01 remains the concrete infrastructure follow-up already approved. Retry-first #87 / draft PR #111 does not satisfy an F2 requirement.

## Historical access refresh and next actions — 2026-10-27

Read-only CoreDevice/simulator inventory on 2026-10-27 again found no iOS 17/tvOS 17/watchOS 10 runtime. Stored/discovered iPhone 17 Pro (27.2/24B119) and Watch Ultra 2 (26.6/23U67) have disconnected network tunnels; iPad Pro 11-inch third generation (27.0.1/24A446) has unavailable tunnel. Per-device DDI services are unavailable; iPhone Developer Mode is enabled, iPad/Watch disabled. TV is not listed, which does not establish absence. These were the initial records, not execution proof. The following owner/connection update supersedes only the iPhone connectivity observation. No settings, pairing, signing, deployment, runtime install or root change occurred. Private identifiers/raw inventory remain outside the repository.

The owner subsequently reports iPhone 17 Pro/iOS 27.2, Watch Ultra 2/watchOS 27.2, iPad Pro/iPadOS 27.2, MacBook Pro/macOS 15.8.1 and Apple TV 4K/tvOS 27.2, with no known controlled HTTPS/domain access. These newer versions do not establish minimum-version access. Watch/iPad/TV versions remain owner-reported; older stored Watch/iPad records differ and are not fresh observations.

After the owner connected/unlocked the iPhone, CoreDevice observed iPhone 17 Pro/iOS 27.2 (24B119), wired tunnel connected, paired, Developer Mode enabled and DDI services available. A read-only lock query found no passcode required and unlocked since boot. Xcode accepted its physical destination in a build-settings query. This resolves the iPhone communication prerequisite only, not signing/deployment/execution compatibility. An unsigned `xcodebuild build-for-testing` then succeeded for the physical destination with CODE_SIGNING_ALLOWED=NO and warnings as errors, producing an arm64 iPhoneOS 26.2 xctestrun plan for NetworkKitTests with the system xctest host. The built NetworkKit resource bundle includes PrivacyInfo.xcprivacy; this is not a consumer archive aggregate privacy report. No test executed in that unsigned build.

One existing valid code-signing identity was available (identity details remain private). The owner explicitly authorized signing and installing/running this test package on the connected iPhone, but not creating certificates/profiles or changing the Apple account. The signed build succeeded using only that existing identity with manual signing and no provisioning-update option. `codesign --verify --strict` succeeded for the built NetworkKitTests bundle. The subsequent authorized `test-without-building` exited 70 before tests ran: tool-hosted testing is unavailable on device destinations and requires a host application. No physical test result is claimed. [Sanitized attempt evidence](evidence/F2_IPHONE_ATTEMPT_2026-10-27.json) records the separation of build/signature/launch results.

PREP-02 / #113 now owns the smallest explicit app-hosted iOS test route, Ready/P1/CORE/Order 20.9 under #23, with accepted #41/#59 prerequisites and a native blocker on #63. Build it unsigned for review before selecting its signing/install route. The previous approval applied to the earlier package artefact; no new host has been installed. Other physical families require their own applicability/host decisions. Do not infer newer device incompatibility from SDK version alone. Do not replace controlled HTTPS with an uncontrolled public endpoint or install trust roots. If access cannot be obtained, keep the gate open and present actual support/scope alternatives for an explicit decision; do not waive evidence simply to close F2.

## Quality and backlog assessment

The main reconciliation gap was traceability: generic epic checkboxes did not enumerate the accepted/deferred source bullets. This matrix supplies that review index while reusing existing tests, contracts and issue owners. No product defect, additional product feature, framework, broad refactor or new milestone is established. One bounded PREP-02 test-infrastructure task is justified by the actual tool-hosting failure; this is not a duplicate of the broader #63 evidence owner. #62/#63 remain independent; both block #86, followed by #64 and the separate #29 release decision. F3 retry planning cannot satisfy an F2 gate. Required PR/main checks are recorded in #86 before this preparation is accepted; acceptance of this document alone closes no epic or phase.

## PREP-02 implementation follow-up

[The app-hosted iOS route](IOS_DEVICE_TEST_HOST.md) and [host runbook](../../Tools/DeviceTestHost/README.md) now provide a minimal local host/test project using all 22 shared test/helper files. App-hosted iOS 26.2 simulator execution passed 215/215 tests, zero skipped/failed/expected failures. This supersedes the earlier no-host preparation state only; no minimum/native-complete/F2 acceptance follows. Existing-profile app-hosted execution on iPhone 17 Pro/iOS 27.2 passed 215/215 tests with zero skipped/failed/expected failures, and the temporary host was removed. Required PR/main acceptance remains on #113; #63 retains ENV-01–07 and actual resource/HTTPS evidence. No product-source change or new milestone is selected.

## NET-01 acceptance / NET-02 follow-up — 2026-10-28

NET-01 #115 is accepted through PR #116 and main 40644612904. [NET-02 #117](NATIVE_LIFECYCLE_STORAGE.md) adds bounded native cancellation/shutdown/cookie observations; #63 retains complete target/ENV/resource evidence. [Three exact minimum-runtime candidates](MINIMUM_RUNTIME_ACCESS_2026-10-28.md) were initially catalogued with anonymous unauthorized HTML responses. The authenticated follow-up verifies all three imports and architecture inventory; [four actual minimum simulator root regressions](MINIMUM_RUNTIME_EXECUTION_2026-10-28.md) subsequently passed locally, 215/215 each. macOS 14 and separate native/resource scenarios remain open; new evidence awaits PR/main acceptance. NET-02 is accepted through PR #118/main 40745209513. No F2 or release criterion is waived.

## Minimum macOS access route — 2026-10-29

PR #120 minimum simulator regression evidence is accepted through main run 40765690271. The owner has no second Mac. The [temporary standard GitHub macOS 14 route](MACOS14_EXECUTION_ROUTE_2026-10-29.md) builds a public consumer with Xcode 26.3 and runs the unchanged executable on the older OS; it is not an older-toolchain build or a support change. Actual execution and its exact patch/build remain pending, as do the other selected native/resource/physical/archive/release gates.

## Current priority refresh — 2026-10-31

Main 0ab623fe67e1be161f2ef1f3ac2fc67107cebb70 is accepted through run 41179384664. The prepared macOS 14 consumer route has completed, with [preserved results](evidence/MACOS14_RUNTIME_2026-10-31.json); its one-off workflow is retired. The earlier access statements above are historical, not the current claim that no macOS 14 route exists.

Continue NET-03 #122: review/negative controls and expanded minimum/physical loopback results, then remaining #63 device-family and foreground/background/network-loss evidence. Previous temporary NET-03 device/simulator records were unavailable on resumption and are not accepted for that candidate. Resource measurements remain observations requiring workload suitability and owner risk disposition. Keep #62/#63 open and reconcile #86 only after their applicable requirements are satisfied; #64 consumer/archive/privacy rehearsal follows its acceptance dependencies. No duplicate environment issue, scope expansion, retry implementation or support-minimum change is warranted by this access result.

NET-03 candidate update (2026-10-31, review pending): the fresh iOS/iPadOS 17.0 simulator runs each passed the expanded opt-in suite, 19 declarations / 40 parameter cases. Physical iPhone 17 Pro/iOS 27.2 passed seven selected loopback declarations / 14 cases. Zero failures/skips/expected failures; cleanup succeeded. [NET-03](NET03_NATIVE_LOOPBACK.md) preserves isolated negative controls, source hashes and limits. These candidate results do not establish accepted main, physical iPad/Watch/TV, minimum Watch/TV native scenarios, physical transitions, SDK app-managed HTTPS cache/credential behavior or archive/privacy acceptance. No gate is closed from these results.

Minimum-native follow-up, 2026-10-31: [Watch/TV execution](MINIMUM_NATIVE_EXECUTION_2026-10-31.md) on accepted 5d2ae116 completed with TV 17/19 and Watch 16/19 declarations passed. Zero skips/expected failures; failed public timeouts and Watch Foundation-challenge/app-managed cookie controls remain failures. A later plain Foundation TV control passed but does not explain the SDK timeouts. NET-04 #126 is P1 CORE and blocks affected #62/#63 claims; no F2 acceptance, skipped assertion or support change. Owner workload remains unknown, so no app-specific resource suitability is accepted.
