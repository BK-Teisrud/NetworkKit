# Public API and integration review — I18

Current retry extension review: [I27](I27_RETRY_REVIEW_2026-11-01.md) compares the exact pre-retry 319-symbol surface to the 326-symbol accepted I27 surface, preserving all original identifiers and initializer function values. The dated I18 review below remains its original core evidence.

Review date: 2026-10-26. Task: [I18 / #59](https://github.com/BK-Teisrud/NetworkKit/issues/59). Baseline: I17 main commit `8ed9ad573b12f4a5b710583cec4411be52fb8871`, accepted in PR #93 and main run 40377796452. This review changes guides, documentation controls and consumer examples; it does not change executable library behavior or approve a release.

## Public surface and rationale

A fresh public symbol graph contains 319 symbol records, including synthesized/inherited members, and 28 top-level declarations. That is an inventory, not a claim that 319 hand-designed API operations are needed. No transport/clock/task-delegate/operation registry seam appears in the public graph.

| Family | Reviewed declarations | Rationale / boundary |
| --- | --- | --- |
| Client | NetworkClient, APIClient | One injectable Sendable boundary and one concrete foreground client, typed/raw calls, explicit async shutdown; app services can substitute a client without transport plugins |
| Endpoints | Endpoint, EndpointPath, HTTPQueryItem | Typed response strategy and safe decoded path/query values. Local request/url/response helpers support construction and consumer tests; they do not authorize networking or provide whole-operation security/budget enforcement |
| HTTP values | HTTPMethod, HTTPHeaders, HTTPStatus, NetworkResponse, EmptyResponse | Validated immutable methods/headers/status and buffered value/metadata; headers expose system values, not guaranteed original wire representation or safe logging permission |
| Request/response strategies | RequestBody, ResponseStrategy, HTTPStatusPolicy, JSONEncodingOptions, JSONDecodingOptions | Explicit JSON/Data/UTF-8/empty selection and value-based codec/status policy. No custom decoder/interceptor/streaming framework |
| Configuration | NetworkConfiguration, NetworkCallOptions, NetworkTimeouts | Immutable client settings and explicit per-call overrides; default inactivity 30 / total 60 seconds, no mutable singleton or raw-timeout override ambiguity |
| Security/storage | NetworkOrigin, NetworkSecurityPolicy, SessionStorageProfile | HTTPS/origin policy and explicit owned-strict/borrowed-profile selection. appManaged does not permit global credentials/delegates/background sessions or bypass security |
| Authentication | AuthenticationContext, AuthenticationHeaderProvider, NetworkAuthentication, AuthenticationPolicy | Minimal Sendable/actor-compatible provider boundary and explicit account/environment binding; app owns login/token storage/renewal/logout, no hidden replay |
| Diagnostics | NetworkDiagnosticEvent, NetworkDiagnosticSink | Fixed sanitized metadata and synchronous nonthrowing sink; app sink must be safe/nonblocking and cannot wait for its own client's shutdown |
| Errors | NetworkError and nested reason/transport identities | Structured safe categories with CancellationError separate; no underlying raw error/body capture and no automatic retry classification |

All selected families support an accepted core requirement. Keep them in the existing single NetworkKit product; no rename, public transport seam, new module, convenience singleton, generic plugin or source-breaking deletion is justified by this review. A future public API change needs its own compatibility/scope assessment. Construction helpers intentionally remain public, but the guide makes their non-executing boundary explicit.

Public generic response/models and callbacks retain the Swift 6 Sendable contract. Codecs are operation-owned; provider actors may suspend cooperatively, while synchronous diagnostic callbacks must remain fast. The review does not authorize unsafe app shared-state capture or promise hard deadlines for synchronous hooks. All error cases and ownership/profile constraints are covered in the guide and existing contract tests.

## Executable integration guide

[DocC integration guide](../../Sources/NetworkKit/NetworkKit.docc/IntegrationGuide.md) covers installation and rights, package/product/import naming, typed JSON, raw Data/text/empty, JSON request bodies, explicit status/error payload handling, safe error categories, authentication, default/borrowed session storage, total/inactivity limits, cancellation, shutdown, diagnostics and client injection/testing.

Five marked Swift blocks come from [DocumentationExamplesTests.swift](../../Tests/NetworkKitTests/Compatibility/DocumentationExamplesTests.swift), compiled using `import NetworkKit` without @testable. They share one consumer file's Foundation/NetworkKit imports. Four executable tests exercise typed values/metadata/path/query, all buffered formats and explicit status, JSON body construction, owned/borrowed client construction/closure, failure cleanup paths and all error categories. The fixture client has no native network or production-policy simulation; existing native policy tests retain that responsibility.

The [source-integrity driver](../../scripts/ci/check.py) compares every published Swift block byte-for-byte with its compiled source and rejects missing, duplicate, untracked or changed blocks. [CI helper tests](../../scripts/ci/test_checks.py) demonstrate fail-closed detection of drift, missing blocks, duplicate identifiers and an extra untracked Swift fence. All existing platform jobs build/run the same test target, so examples participate in the selected four-family/five-runtime PR matrix. No extra product/test target or package dependency is added.

DocC's module landing page now links the integration article and correctly describes explicit borrowed appManaged storage. Earlier strict-only wording and the stale non-executing module comment are corrected. Installation uses an explicitly reviewed revision until an actual approved release exists; no imaginary v1 tag or open-source permission is presented.

## Availability and toolchain review

Inspected the installed Xcode 26.3 / 17C529 SDK 26.2 interfaces, not framework names alone. The Foundation interface declares URLSession.data(for:delegate:) from macOS 12 / iOS 15 / watchOS 8 / tvOS 15. The _Concurrency interface declares ContinuousClock from macOS 13 / iOS 16 / watchOS 9 / tvOS 16. The os interface declares the OSAllocatedUnfairLock base type from macOS 13 / iOS 16 / watchOS 9 / tvOS 16. These are below the selected 14/17/10/17 minima; newer lock-flags overloads are not selected merely because the base type is available.

The actual used overloads, Foundation value/codec/session operations and public examples are compiled with the declared deployment minima. Existing generic builds for all four families and warnings-as-errors remain required on this PR; successful newer-host compilation is not minimum-runtime execution. Watch tests continue to distinguish scripted/admission checks from native transport evidence. OS/SDK declarations and compiler back-deployment do not prove platform behavior, app signing/connectivity or compatibility of unknown newer devices. ENVIRONMENT_READINESS.md and #62/#63 retain those gaps.

## Actual local verification and residual gates

`swift test --parallel -Xswiftc -warnings-as-errors` passed **214 tests in 25 suites** on macOS 15.8.1 / 24H32 x86_64, Swift 6.2.4, including four new guide tests and existing local native server probes. Local DocC extraction/conversion passed with warnings as errors and rendered the integration article. The four CI helper tests passed. Final source-integrity and hosted PR/main evidence are recorded in #59; do not infer hosted acceptance from local success.

I17's TEST_EVIDENCE.md remains a dated 210-test acceptance snapshot. TEST_INVENTORY.md is refreshed to 214 declarations including the four guide tests; historical run counts are preserved. Existing contract mappings and known release gaps are unchanged. Further changes must keep guide source/fences and evidence counts aligned without rewriting historical runs.

Security/privacy/native HTTPS/system-trust review remains #60; resource measurements remain #61; minimum-runtime and physical evidence remain #62/#63; domain reconciliation/rehearsal/publication remain #86/#64/#29. This review supplies API/compile evidence for those tasks, not their acceptance.

## Backlog and execution assessment

No new implementation defect, feature scope, duplicate issue, milestone split or priority change is justified by this review. Documentation defects found here are fixed in this slice. I19 / #60 follows I18 acceptance; it is a real dependency, not a candidate for a competing branch from the old API baseline. Independent later work may be prepared only after checking contracts, file overlap, accepted base and capacity.

The owner now permits multiple independent branches/PRs, created sequentially, with at most five concurrent work processes. [PROJECT_MANAGEMENT.md](PROJECT_MANAGEMENT.md) records isolation, shared-file handling, CI capacity and stop/resume rules. No parallel independent delivery is started by this PR, and no background polling or paid runner is introduced.

## Main acceptance follow-up

The first I18 main run 40382689252 failed in the pre-existing native borrowed-cache probe after PR #94 had passed. The review is not accepted from that run. [BUG-01 / #95](STORAGE_TIMEOUT_FOLLOWUP.md) blocks #59 acceptance and records bounded test-fixture/diagnostic work without asserting an unproven product root cause.

## Accepted follow-up evidence

PR #96 latest head 23678d761a632f50b69c4a4e9322be83e7864324 passed all seven checks in run 40389390363 and merged as 21a204191eaa82a60ec88bf9f60ef57f5f054920. Main run 40390885712 passed all five runtime results (macOS 216/26; four other destinations 214/25), with all native phases complete and no timeout or process restart. #95 and I18 #59 are accepted for their bounded criteria; exact original internal stall cause is still unproven and R10 remains monitored by #23/#86. The failed original runs are preserved; no security/runtime/device/release gate is waived. QA-01 #97 is the next owner-requested review before I19.
