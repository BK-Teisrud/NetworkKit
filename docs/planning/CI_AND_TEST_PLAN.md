# CI and test plan after implementation authorization

Status: Core plan accepted 2026-10-19; see [ADR-0008](../decisions/ADR-0008-ci-tools-and-budget.md). I01–I10 provide the executing HTTP slice. I06 introduced the real workflow and required quality-gate after verified hosted PR/main runs. The cumulative I10 suite passed 135 test functions on each of five runtimes; [F1 review](F1_REVIEW.md) records the I11 gate and further acceptance coverage. See [CI implementation](CI_IMPLEMENTATION.md) for exact jobs, commands, and actual evidence.

Current I17 consolidation: [contract and CI evidence ledger](TEST_EVIDENCE.md) maps named tests and explicit residual release gaps. The counts above are dated I10 evidence, not the current suite inventory.

## Mandatory PR jobs

Real CI now runs every mandatory job on pull requests and pushes to main. The owner selected all four platform families on every PR, not only releases. Documentation PRs receive no hidden global bypass of this matrix.

| Job | Runner / tools | Required real checks before success |
| --- | --- | --- |
| source-integrity | Standard GitHub runner; official/bundled tools | Manifest/dependency/platform/language-mode requirements, file formats, and documentation links; no external Swift packages or library SwiftUI imports |
| macos-core | macos-15, arm64, explicitly selected Xcode 26.3 | Product build with macOS 14 minimum and unit/direct integration tests on the actual host OS |
| ios-core | macos-15, arm64, explicitly selected Xcode 26.3 | iOS/iPadOS build with minimum 18 and tests on selected iPhone and iPad simulators; baseline runtime 26.2 |
| watchos-core | macos-15, arm64, explicitly selected Xcode 26.3 | watchOS build with minimum 11 and tests on a selected watchOS 26.2 simulator, with compatible iPhone pairing/harness where needed |
| tvos-core | macos-15, arm64, explicitly selected Xcode 26.3 | tvOS build with minimum 18 and tests on a selected Apple TV simulator; baseline runtime 26.2 |
| documentation | Standard macOS runner, Xcode 26.3 / DocC | Build docs for the actual public API; check warnings/links and guide accuracy |
| quality-gate | Small standard-runner aggregation job | Every mandatory job succeeds; failures, missing jobs, and unexpected skips cannot yield success |

Source integrity and documentation checks are supporting jobs, not product dependencies. Bind and document actual schemes, test plans, and simulator IDs in the first real CI PR once the package exists. An app/test host is test infrastructure, not another distributed library module. Resolve unsupported test harnesses or raise explicit blockers; a build alone cannot be renamed “tests passed.”

The current declared floors are iOS/iPadOS18, macOS15, watchOS11 and tvOS18 under owner-delegated ADR-0017; actual minimum-family runs record their exact patches. The owner now permits independent/next-branch work while CI runs without polling; predecessor main and candidate checks still gate dependent merge.

## Runner and toolchain verification

The primary runner is standard macos-15 (arm64). Set DEVELOPER_DIR to the installed Xcode 26.3 and verify its version. Do not rely on image defaults or macos-latest. Official inventory reviewed 2026-10-19 lists Xcode 26.3 build 17C529 and SDK/simulator runtimes 26.2, but an older default Xcode. That historical host inventory is not current runtime proof. The current library floor is macOS15.0 under ADR-0017; the Xcode host must separately meet its system requirements.

Record image version, host OS/architecture, Xcode build, Swift patch, SDK, runtime, and destinations per run. Verify Swift tools 6.2 compatibility and Swift 6 language mode. Keep current platform minimums explicit in the manifest under ADR-0017. Missing toolchain/runtime fails preflight; do not silently fall back or automatically raise minimums.

Inventory establishes potential availability, not successful CI or a frozen image. The first CI PR must demonstrate selected destinations, including Watch pairing. Runner/Xcode/runtime updates go through PRs and retain approved product minimums. Beta/RC tooling cannot be the sole required gate.

## Test strategy and security

Use Swift Testing for new unit/direct integration tests. Use XCTest for specific platform/performance/harness needs; do not arbitrarily mix assertions from both frameworks within a test. Both come from the selected Apple toolchain, without external Swift packages.

Use URLProtocol/mock transports and a controlled internal clock for normal/error paths, timeouts, cancellation, snapshots, concurrency, session ownership, shutdown, and security policy. Use synthetic data/test credentials only. Depend on no public third-party API or real token. Controlled loopback services or physical harnesses may verify transport properties; neither is a backend product.

URLProtocol alone does not verify TLS/system trust, real redirects, cache/cookie storage, or OS-specific behavior. Verify those contracts where applicable before release. Do not substitute an arbitrary coverage percentage for contract coverage; record actual normal/error/race/security cases tested.

Use only necessary GitHub-owned actions pinned to full commit SHAs. Local steps use Apple/official and available system tools. Do not introduce third-party Xcode installers, SwiftLint/SwiftFormat/xcbeautify, or coverage SaaS merely because they are preinstalled. No external reusable workflows. Build DocC using Xcode tools without an external documentation plugin.

Default GITHUB_TOKEN to read-only. Checkout must not retain credentials accessible to untrusted code. No fork-PR secrets, pull_request_target execution of PR code, or trust in untrusted PR artifacts/caches later published with write tokens. This plan adds no automatic publishing job or secret.

## Resource and cost limits

Only standard GitHub-hosted runners in the public repository are authorized. No larger runners, subscriptions, self-hosted services, or paid add-ons. Reassess pricing/minutes before running after a visibility change; free public standard-runner compute does not guarantee free storage or all account services.

The first CI version has no artifact uploads or explicit Actions cache. Retain only necessary sanitized ordinary job logs within current account/repository limits. Before later uploads, agree small size/retention limits and check remaining free storage. No account-wide billing/subscription/budget settings have changed.

Planned initial limits: at most two concurrent macOS matrix jobs per workflow and a 30-minute timeout per heavy job. A new push replaces/cancels obsolete runs on the same PR with clean cancellation. Do not cancel verification already serving as release evidence. These limits are now configured in the I06 bootstrap workflow.

Runtime/time-limit problems fail with a concrete reason. Do not switch to paid runners, install unapproved tools, or skip tests without a separate decision.

## Require checks only after evidence

1. After implementation authorization, create a real package and meaningful tests before introducing CI.
2. Run every mandatory job on the CI PR and then main. Missing Package.swift or an empty test suite is not success.
3. Verify a stable quality-gate check name aggregating all required platform/test/doc jobs without a green skip path.
4. Only then require quality-gate, with the correct Actions integration and updated branch policy. An unrelated/malicious same-name check is not equivalent evidence.
5. Verify enforcement on another PR. Main has no bypass; preserve that property.

I06 activates quality-gate only after successful real PR/main evidence and verifies enforcement in a separate PR; see CI_IMPLEMENTATION.md and #47. No check merely confirming that code does not exist is introduced.

## Separate release and minimum-OS checks

PR runtimes 26.2 and macOS hosts 15.x do not test minimum iOS/iPadOS 17, macOS 14, watchOS 10, or tvOS 17. The inspected macos-15 inventory does not provide this complete set. Do not promise all minimum runtimes on standard runners.

Before the first release, record evidence for the approved minimums using compatible available official simulators/runtimes or existing devices/Macs with suitable test hosts. macOS minimum support needs actual runtime evidence, not a deployment target on a newer host. Do not assume an older runner supports Xcode 26.3 merely because its host OS matches.

Current minimum-family results are recorded in [the platform matrix](PLATFORM_MATRIX.md), including actual ARM64 macOS 14.8.9 consumer and HTTPS execution. Exact patch/architecture/suite limits remain explicit. No equipment purchases, paid services or self-hosted GitHub runners are authorized. Remaining physical/transition gaps stay open; never mark assumed compatibility as passed.

Release checks also cover representative newer stable runtimes, relevant physical scenarios, documented Mac-architecture assessment, security/privacy, public API/DocC, rights policy, and representative performance/memory measurements. Verify installation from the release candidate commit/tag before final publication to avoid discovering failures only after an immutable release.

Update [PLATFORM_MATRIX.md](PLATFORM_MATRIX.md) and REL-01 with commit, environment, test names/results, known limitations, and approved scope changes. Formal non-publishing rehearsal remains under #64 after #86/#63; existing preparation and partial checks do not close that gate.

I20 adds a short standalone release-consumer probe to macos-core: compile the opt-in harness and verify native loopback reuse/cancellation through public APIs, without volatile RSS/latency thresholds. Full three-repetition resource measurements remain opt-in and recorded in [RESOURCE_BASELINE.md](RESOURCE_BASELINE.md); RES-01 / #100 owns the observed RSS trend and blocks #86. Existing required jobs, runtime tests, runner budget and no-publication policy remain unchanged.

RES-01 keeps heap profiling opt-in and adds macos-core type-checking of its standalone Swift runtime control. The new --post-budget resource mode samples after the fixture's original ten-second deadlines. See [attribution and limits](REPEATED_CALL_MEMORY.md); passing CI is not target-device profiling or residual-risk acceptance.


The explicit manual transition app is compiled unsigned once per platform-family job, with source/commit/platform identity verified in the actual built Info.plist. CI never launches it, changes connectivity or contacts its public fixtures. Its owner-driven execution and report acceptance follow [the manual procedure](MANUAL_TRANSITION_CHECKS.md). Existing regression suites and six unsigned XCTest-host builds remain unchanged.
