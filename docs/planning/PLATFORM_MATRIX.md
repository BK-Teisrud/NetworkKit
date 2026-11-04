# Platform and toolchain matrix

## Accepted F2 closeout — 2026-10-31

F2 is CLOSED after PR #135/main `cc654ab5faadc0fc7fe00d7ad238b2e3ed5a997c`, [run 41242130528](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41242130528), with full-log verification of 218 Mac tests, four 215 simulator suites, 19 helpers and four manual-host provenance checks without failure/restart markers. #64/#27 are Done; direct item lists and GraphQL verify no open F2 issues/PRs. [Closeout evidence](F2_CLOSEOUT_2026-10-31.md) records the milestone summary-counter disagreement and actual verified states.

Original candidate evidence files retain their submission-time pending flags and exact executed SDK/platform/failure limits. The owner resource approval is F2-only. #132 physical Watch and #29 actual workload/device-memory/security/publication decisions remain mandatory in their separate milestone, with support unchanged. No release/tag, production suitability or F3 implementation is authorized.

PLAN-F3 #87 is Ready for planning only: review draft PR #111 and obtain a separate approved feature scope/start decision before code. Closed F2 is not publication or extension authorization.

## Current verified evidence — 2026-10-31

Latest accepted standard CI: PR #128 / main b8f2758530cca68ec819068ff3ac7748868e26dd, run 41203171039. All seven checks passed, with 218 Mac tests, four simulator runs of 215 each, six unsigned test-host builds and 17 helper controls. These PR runtimes remain distinct from minimum-family and physical execution.

| Family / declared minimum | Actual minimum-family execution | Native scope and evidence | Physical follow-up |
| --- | --- | --- | --- |
| iOS 17.0 | iOS 17.0 simulator; 215 regression tests | Accepted native loopback/public suite at its recorded 19-declaration / 40-case source; [minimum records](MINIMUM_RUNTIME_EXECUTION_2026-10-28.md), [NET-03](NET03_NATIVE_LOOPBACK.md) | iPhone 17 Pro / iOS 27.2 regression/native accepted; actual background/outage/recovery accepted through PR #129/main 41221803657 |
| iPadOS 17.0 | iPadOS 17.0 simulator; 215 regression tests | Same separately recorded minimum iPad run and native scope | iPad Pro 11-inch 3rd generation / 27.2: 215 regression, native 20/21 plus supplemental strict TLS; actual transition report accepted through PR #129/main 41221803657; earlier failure retained |
| macOS 14.0 | ARM64 macOS 14.8.9 / 23J631 | Native consumer/reuse/cancellation/finite resource controls plus ten HTTPS cases in [run 41204068268](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41204068268); [custody](evidence/MACOS14_HTTPS_EXECUTION_2026-10-31.json) | Local Intel macOS 15.8.1 native evidence is separate. No exact 14.0, Intel macOS 14 or full macOS 14 suite claim |
| watchOS 10.0 | watchOS 10.0 simulator; 215 regression tests | Accepted revised 21-declaration / 44-case native suite; [NET-04](NET04_NATIVE_CONTROLS.md) | Watch Ultra 2 / 27.2: signed generic artefacts ready, physical development-tunnel/readiness unresolved; no runtime pass |
| tvOS 17.0 | tvOS 17.0 simulator; 215 regression tests | Accepted revised 21-declaration / 44-case native suite | Apple TV 4K 3rd generation / 27.2: accepted 215 regression + 21 native declarations / 44 cases and finite resources; actual Ethernet-loss/recovery/post-budget accepted through PR #131/main 41234106849 |

Product minimums and the Xcode 26.3 / Swift tools 6.2 / Swift 6 baseline are unchanged. An actual 14.8.9 run is evidence on the macOS 14 family, not proof of every patch or architecture. #62 minimum-family evidence is accepted through PR #129/main 41221803657; the issue is closed and project Done. #63 physical transitions/Watch/resources and #86/#64/#29 remain separate gates. Manual transition tooling compiles for all four families; compilation alone is not device/transition acceptance.

The historical implementation snapshots below preserve their original counts and limits; they are superseded by the current evidence above where applicable.

## Historical I10 build/test baseline

| Platform | Minimum v1 OS | Locally observed SDK | Build | Unit / integration | Tested runtime / device |
| --- | --- | --- | --- | --- | --- |
| iOS | 17.0 | iOS 26.2 | Generic device build passed | 135 test functions / 18 suites passed on iPhone 17 / iOS 26.2 simulator | Minimum OS and physical device unverified |
| iPadOS | 17.0 | iOS/iPadOS 26.2 | iOS generic build passed | 135 test functions / 18 suites passed on iPad (A16) / iOS 26.2 simulator | Minimum OS and physical device unverified |
| macOS | 14.0 | macOS 26.2 | Generic build passed on hosted arm64; local x86_64 builds passed | 135 test functions / 18 suites passed on hosted macOS 15.7.9 arm64 and local 15.8.1 x86_64 | Minimum OS unverified |
| watchOS | 10.0 | watchOS 26.2 | Generic device build passed | 135 test functions / 18 suites passed on Series 11 (42mm) / watchOS 26.2 simulator | Minimum OS and physical device unverified |
| tvOS | 17.0 | tvOS 26.2 | Generic device build passed | 135 test functions / 18 suites passed on Apple TV 4K (3rd generation) / tvOS 26.2 simulator | Minimum OS and physical device unverified |
| visionOS | Deferred; no v1 support | Outside selected delivery | Outside v1 | Outside v1 | Outside v1 |

A newer SDK supplies build-time APIs; it does not require the host app to run that OS version. iOS/iPadOS share SDK/deployment foundations, but relevant device/environment differences still need assessment. Mac Catalyst, Linux, Windows, and Android support are not selected.

## Tools

| Setting | Approved requirement | Observed local/hosted evidence, 2026-10-20 |
| --- | --- | --- |
| Xcode | 26.3 or a newer stable version, verified before claiming support | 26.3, build 17C529 |
| Swift tools | Minimum 6.2 | Apple Swift 6.2.4 |
| Swift language mode | Swift 6, strict concurrency | Manifest Swift 6; all selected platform builds and tests passed |
| Host macOS | Meets selected Xcode's system requirements | 15.8.1 |
| Host architecture | Standard GitHub macos-15 arm64; assess local architectures separately | Hosted arm64 passed; local x86_64 passed |
| CI SDK / runtime / runner | ADR-0008 / CI_AND_TEST_PLAN.md baseline; verify each run | SDKs/runtimes 26.2; macos-15 image 20260907.0337.1; actual destinations in CI_IMPLEMENTATION.md |

Development-host requirements are separate from the library's macOS 14.0 minimum. Local version inspection is not a library test result.

## Symbol checks before Ready

For each selected API, record requirement ID, full symbol name, framework, inspected SDK, availability per target OS, required guard/fallback, and behavioral test plan. Use SDK/Apple documentation; do not infer availability from framework names.

| Area | Foundation | Outstanding checks |
| --- | --- | --- |
| HTTP/session | Foundation / URLSession / URLRequest | Exact async methods, configuration, delegates, timeout, cancellation |
| URL/JSON | URLComponents / Codable / JSONEncoder / JSONDecoder | Selected overloads, parameter semantics, coding strategies |
| Logging | OSLog | Selected logging API, privacy markers, data minimization |
| Concurrency | Swift Concurrency | Sendable, isolation, cancellation, clock APIs; assess language and OS requirements separately |
| Testing | Apple/official tools | Swift Testing package harness passed on all selected PR runtimes; minimum OS/physical scenarios remain |

This is a review checklist, not proof that every symbol is verified. Newer Foundation/OSLog/Concurrency APIs may require higher OS versions than the approved minimums.

## Future test evidence

For each check record commit SHA, date, Xcode build, Swift version, SDK, actual runtime/architecture, simulator/device, test type, and result or concrete reason for missing execution.

Cover builds on every selected platform and relevant normal/error/cancellation/concurrency tests. [CI_AND_TEST_PLAN.md](CI_AND_TEST_PLAN.md) / ADR-0008 separates PR runtimes from release tests on minimum OS versions and representative newer stable runtimes. If CI cannot run a minimum, establish an explicit alternative with real evidence before release; a newer simulator build is insufficient.

Use physical devices where scenarios require them. Background transfers, Keychain groups, and local networking are deferred by v1 scope and are not established by this matrix. I06 introduced real CI; I10 cumulative build/PR-runtime evidence is linked below; minimum-OS and physical-device verification remains outstanding.

## Bounded declaration check for DEC-04

Inspected 2026-10-19 in local macOS SDK 26.2, Foundation.swiftmodule/x86_64-apple-macos.swiftinterface. Availability annotations name all four platforms, but this does not replace each platform SDK's inspection/builds or runtime tests.

| Symbol | Declared minimum in inspected interface | Relation to v1 minimums |
| --- | --- | --- |
| URLSession.data(for:delegate:) | iOS 15, macOS 12, watchOS 8, tvOS 15 | Within every selected minimum |
| URLComponents | iOS 8, macOS 10.10, watchOS 2, tvOS 9 | Within every selected minimum |
| URLQueryItem | iOS 8, macOS 10.10, watchOS 2, tvOS 9 | Within every selected minimum |
| JSONEncoder / JSONDecoder base classes | iOS 8, macOS 10.10, watchOS 2, tvOS 9 | Within every minimum; check newer members separately |

This is positive declaration evidence for those candidates, not an implemented/tested HTTP contract. Inspect actual HTTPURLResponse/URLRequest overloads/properties, other JSON strategies, OSLog, and concurrency APIs before relevant tasks become Ready. These checks do not change build/test statuses.

## Bounded source/declaration check for DEC-05

Inspected 2026-10-19 in local SDK 26.2. _Concurrency.swiftmodule/x86_64-apple-macos.swiftinterface declares ContinuousClock from iOS 16/macOS 13/watchOS 9/tvOS 16 and CancellationError from iOS 13/macOS 10.15/watchOS 6/tvOS 13. Both fit the selected minimums. No new OS 26-specific clock properties are selected.

Foundation/Headers/NSURLSession.h confirms the distinction between wait-for-data request timeout, resource timeout, and session invalidation effects on tasks. It also distinguishes connectivity waiting from request timeout, motivating a separate total library budget. These reading checks establish neither actual cancellation/timeout behavior nor availability on every SDK/runtime. Build/test statuses remain unchanged.

## Environment inventory before implementation

[TEST_ENVIRONMENTS.md](TEST_ENVIRONMENTS.md) records installed newer runtimes, owner-reported devices, and missing minimum-OS environments. Inventory does not change the test statuses above.

## I01 package-build evidence — 2026-10-20

The macOS library and test target compile with Xcode 26.3 / Swift 6.2.4 on the local x86_64 macOS 15.8.1 host. A separate local consumer compiles and links the NetworkKit product. This is build/import evidence only, not a runtime contract test or a macOS 14 execution result. Other platform builds/runtimes remain unverified. See [PACKAGE_BASELINE.md](PACKAGE_BASELINE.md).

## I02 value-layer evidence — 2026-10-20

[HTTP_VALUES.md](HTTP_VALUES.md) records the API review, bounded SDK declaration check, 21 passing local contract tests, negative control, and public consumer check. These establish value/error semantics only; no HTTP transport, all-platform build, or minimum-OS runtime claim is made.

## I04 endpoint evidence — 2026-10-20

The full suite passed 44 tests in nine suites on macOS 15.8.1 x86_64 / Xcode 26.3 / Swift 6.2.4. This includes structural URL and encoding checks, not transport/runtime support evidence. See [endpoint review](ENDPOINT_URLS.md). Minimum-OS and other platform evidence remain outstanding.

## I05 request encoding evidence — 2026-10-20

The full suite passed 64 tests in 11 suites on macOS 15.8.1 x86_64 / Xcode 26.3 / Swift 6.2.4. This covers local request construction and concurrent encoding, not transport/runtime support. See [request review](REQUEST_ENCODING.md). Other platforms, minimum OS, and CI remain outstanding.

## I06 hosted CI evidence — 2026-10-20

All four generic platform builds and all 64 product test functions passed on each of five destinations in [bootstrap PR run 39487893701](https://github.com/BK-Teisrud/NetworkKit/actions/runs/39487893701): hosted macOS 15.7.9 arm64; iPhone 17 and iPad (A16), OS 26.2 build 23C54; Series 11 watch, OS 26.2 build 23S303; Apple TV 4K, OS 26.2 build 23K51. Xcode 26.3 build 17C529 / Swift 6.2.4 / SDKs 26.2, image 20260907.0337.1. Source integrity and DocC also passed. See [CI implementation](CI_IMPLEMENTATION.md) and #47 for main/enforcement evidence. This validates current value/configuration/request behavior, not unimplemented HTTP transport or minimum runtimes.

## I09 security-policy evidence — 2026-10-21

The local suite passes 121 test functions in 17 suites on the existing macOS/Xcode/Swift
baseline. New watchOS tests compile with warnings as errors. Real redirect integration
uses controlled macOS loopback HTTP; iOS/watchOS/tvOS redirect tests use the actual
policy/delegate with scripted I/O. This does not prove native redirect callbacks, ATS,
TLS or real watch networking on those platforms. See [security evidence](NETWORK_SECURITY.md)
and issue #50 for hosted PR/main results. Minimum-OS and physical-device gates remain.

## I10 cumulative baseline and I11 gate — 2026-10-21

[Main run 39652280325](https://github.com/BK-Teisrud/NetworkKit/actions/runs/39652280325)
on `a09605739b92e53954b4ce4f3a6fb9b1825af8ce` passed all seven checks and 135 test
functions / 18 suites on each table destination. Xcode 26.3 / 17C529, Swift 6.2.4,
SDKs/simulator runtimes 26.2, macOS 15.7.9 arm64, image 20260907.0337.1. Exact UUIDs
are recorded in the log. This supersedes the earlier table counts, not their historical
records below. [F1 review](F1_REVIEW.md) and #52 record I11's additional gate tests and
final PR/main evidence. Native versus scripted transport boundaries are explicit there.
