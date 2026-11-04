# Real CI implementation and activation

I06 / #47. Bootstrap PR: [#72](https://github.com/BK-Teisrud/NetworkKit/pull/72).
Status: real CI is active. Main requires quality-gate from the verified GitHub Actions
integration (15368), with a current-base requirement and no bypass. Activation followed
successful bootstrap PR and main runs. The separate enforcement PR and completion
record on [#47](https://github.com/BK-Teisrud/NetworkKit/issues/47) hold the final
negative-control and acceptance evidence; the task stays open until that verification completes.

## Checks and exact environment

`.github/workflows/ci.yml` runs on every pull request, pushes to main, and manual dispatch.
There are no path filters, documentation-only bypasses, secrets, or publishing triggers.
Every matrix entry uses standard `macos-15` arm64 and explicit
`/Applications/Xcode_26.3.app/Contents/Developer`. Preflight requires Xcode 26.3 build
17C529, Swift 6.2.4, and the macOS/iOS/watchOS/tvOS device/simulator SDKs 26.2. The
actual image version, host OS, architecture, Xcode, Swift, SDKs, runtimes, selected
simulator names/UUIDs, and test summaries appear in job logs. No implicit tool fallback,
runtime download, or product minimum change is allowed.

| Stable check name | Actual work |
| --- | --- |
| source-integrity | Parse the real Swift manifest; verify product, targets, no external dependencies, tools/language mode, and OS minimums; parse tracked JSON and validate local Markdown file links; reject library SwiftUI imports/unchecked Sendable; verify matrix/action pins and run CI helper regression tests |
| macos-core | Generic macOS build and actual package-scheme tests on the runner host |
| ios-core | Generic iOS device build; actual tests on selected iPhone 17 and iPad (A16) simulators, iOS 26.2 |
| watchos-core | Generic watchOS device build; actual tests on a selected Series 11 watchOS 26.2 simulator, paired with an available iPhone 17 / iOS 26.2 companion if needed |
| tvos-core | Generic tvOS device build; actual tests on a selected Apple TV 4K (3rd generation) / tvOS 26.2 simulator |
| documentation | Build generated test modules, extract real public NetworkKit symbol graphs, and build the module's DocC catalog with warnings as errors, without a package plugin |
| quality-gate | On standard ubuntu-24.04, require the aggregate mandatory matrix result to be success; fail on failure, cancellation, missing result, or skip |

The Swift package's actual Xcode scheme is **NetworkKit**, distinct from the
**NetworkKit** product/module. A generated ignored `.swiftpm/xcode/package.xcworkspace`
uses Xcode's self-reference to open the package; no second distributed product or
hand-maintained application project is introduced. Test results must contain passed
executions, no failures/skips/expected failures, and no empty test plan. xcodebuild
build/test failures propagate. Unit/direct contract tests are meaningful at the current
implementation stage; unimplemented HTTP transport behavior is not claimed as tested.

## Resource and trust boundaries

The matrix has `max-parallel: 2`, `fail-fast: false`, and 30-minute job limits.
Only obsolete PR runs are cancelled automatically; main-run evidence is not deliberately
cancelled by a later PR push. Checkout is GitHub-owned and pinned to a verified full SHA,
with persisted credentials disabled. GITHUB_TOKEN is contents-read only. There are no
artifact uploads, cache actions, third-party setup/install/formatter tools, write jobs,
larger/self-hosted runners, paid services, or fork-PR secrets.

[Official runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md)
and [GitHub runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
were reviewed on 2026-10-20. Inventory establishes availability, not actual passed checks
or a frozen image. Device UUIDs are discovered and logged per run. Local Markdown checks
validate file existence, not remote URL reachability, all anchor semantics, or guide accuracy;
manual review remains necessary. Branch check binding identifies GitHub Actions, not a
cryptographic guarantee against a maintainer deliberately changing the workflow itself.

## Local bootstrap evidence

- Xcode 26.3 / Swift 6.2.4 preflight and all expected SDK version checks passed on the
  owner's macOS 15.8.1 x86_64 machine. This is not hosted arm64 evidence.
- Source integrity passed, including three helper regression tests rejecting missing/
  unavailable runtimes/devices and empty/failed/skipped/incomplete test summaries.
- Actual public symbol extraction and DocC conversion passed with warnings as errors.
- A local watchOS simulator product build passed. It is a build, not watch runtime tests.
- The previous 64 product test functions have local macOS evidence from I05. Hosted
  xcresult counts may include parameterized cases; use actual per-run summaries.

## Activation procedure and evidence requirements

1. All seven checks pass on the bootstrap PR's final source revision.
2. Merge bootstrap through the existing PR rule, then obtain a successful main run.
3. Bind the exact `quality-gate` context to the verified GitHub Actions integration in
   main's required-status-check rule, without bypass actors, retaining existing rules.
4. Use a separate verification PR to demonstrate a deliberate failure produces a failed
   quality-gate and blocked merge state; remove the control and obtain all passing checks.
5. Record the commit/run links, actual environments/results, and rule read-back in
   repository documentation and #47 before marking complete.

Minimum iOS/iPadOS 17, macOS 14, watchOS 10, and tvOS 17 runtimes remain unverified.
Deployment targets and 26.2 simulator tests do not replace I21/I22 minimum-OS and physical
device release evidence. No release is published by this work.

## Bootstrap compatibility finding

The first complete platform attempt exposed the same URL-host test failure on iOS and
watchOS while macOS passed. URL validation now uses Foundation URLComponents.encodedHost
for its ASCII IDNA representation and handles IPv6 brackets explicitly, rather than
assuming URL.host returns identical representations on every OS. The existing origin
regression is parameterized to identify the failing host case directly. All 64 local
product tests passed after the fix; hosted confirmation remains required.

The watchOS package scheme did execute all 64 product test functions on its simulator;
the failed host assertion was not replaced with a build-only check. Companion logging
now reports the actual existing compatible pairing rather than an unused candidate.

The next hosted run executed and passed all 64 product test functions on each of macOS,
iPhone, iPad, watchOS, and tvOS: [run 39486374412](https://github.com/BK-Teisrud/NetworkKit/actions/runs/39486374412).
Its quality-gate correctly failed because documentation failed on a clean runner:
SwiftPM's symbol-graph command also visits its generated test runner module. The DocC
job now builds test modules before extraction and still curates only NetworkKit graphs.
That complete sequence passed from an isolated source copy without any existing .build
or .swiftpm output. It is not a workaround that ignores a tool failure; hosted confirmation
of the corrected workflow remains required before activation.

## Verified bootstrap and current main policy

- [Bootstrap PR #72](https://github.com/BK-Teisrud/NetworkKit/pull/72), final source
  44ce36edd82c2a532f2ceb89007cda86d3fddf2b:
  [all seven checks passed](https://github.com/BK-Teisrud/NetworkKit/actions/runs/39487893701).
- Merged baseline fe47c58da9763247971c18df835cbf00176742fa:
  [main run 39489206787](https://github.com/BK-Teisrud/NetworkKit/actions/runs/39489206787)
  passed all seven checks before the required rule was activated. This precondition
  was checked against the API, including all actual jobs and the gate app identity.
- Ruleset 25428389 adds only required_status_checks: quality-gate, integration_id 15368,
  strict_required_status_checks_policy true, do_not_enforce_on_create false. All
  existing PR/linear-history/deletion/force-push restrictions remain, with no bypass.
  The rule and effective main-branch rules are read back; the committed ruleset JSON
  records actual configuration rather than a proposed setting.
- The exact gate shell was exercised locally: success returned 0; failure, cancelled,
  skipped, and missing result each returned 1. Helper tests also reject empty, failed,
  skipped, expected-failure, and incomplete xcresult summaries.

No screenshots, artifacts, secrets, cache, or publishing jobs are added. Ordinary logs
record only necessary environment/destination metadata; job output is not proof of
minimum-OS compatibility or unimplemented transport/security behavior.

The rule and effective main-branch read-back succeeded on 2026-10-20 after the main run. The enforcement PR starts with a deliberately broken local Markdown link; it is a temporary negative control, never intended for merge. Product code remains unchanged in that control.

## Enforcement negative control and final acceptance

[Verification PR #73](https://github.com/BK-Teisrud/NetworkKit/pull/73), revision
13e4eb0b458e356c8a02c337bf1701d1a372fab9, deliberately introduced one missing local
Markdown link. In [run 39491129998](https://github.com/BK-Teisrud/NetworkKit/actions/runs/39491129998),
source-integrity failed for that exact fixture and quality-gate failed. All platform
jobs and documentation passed. GitHub reported mergeable=MERGEABLE (no conflict) but
mergeStateStatus=BLOCKED while the failed required gate came from GitHub Actions 15368.
No bypass, merge attempt, or product-code failure was used to manufacture the result.

The temporary control is removed. The final PR revision must pass every mandatory check
before normal merge; [issue #47](https://github.com/BK-Teisrud/NetworkKit/issues/47)
records that positive run and the final main result before closure. The README CI badge
links to current main status; dated snapshots are not a substitute for live results.

The ruleset snapshot includes server defaults that were already active (such as the
unattributed-change review parameter). API comparison confirmed that existing rules
were preserved; required_status_checks is the sole new main rule. See GitHub's
[required-status-check API](https://docs.github.com/en/rest/repos/rules#update-a-repository-ruleset)
for strict/current-base and integration binding. The URL compatibility fix uses the
[Foundation encodedHost declaration](https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/URL/URLComponents.swift),
which is available within every selected platform minimum; minimum-runtime behavior
still requires the separate release evidence.
