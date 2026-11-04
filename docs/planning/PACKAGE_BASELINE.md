# I01 package baseline

Date: 2026-10-20. Task: [I01 / #42](https://github.com/BK-Teisrud/NetworkKit/issues/42). Authorization: [ADR-0012](../decisions/ADR-0012-implementation-start.md).

## Delivered structure

The owner supplied a default Xcode package in NetworkKit/. Its manifest, source, test target, and ignored Xcode workspace metadata were moved to the repository root. A local copy of the original starter was retained before adaptation. Existing ignore rules were consolidated, including .netrc; no credentials or workspace metadata are committed.

Package.swift declares Swift tools 6.2 and explicitly selects Swift 6 language mode, which enables complete concurrency checking. Package name: NetworkKit. One automatic library product and library target: NetworkKit. One test target: NetworkKitTests. Platform minimums: iOS/iPadOS 17, macOS 14, watchOS 10, tvOS 17. No external package dependencies, plugins, or workflows.

The library source intentionally declares no HTTP API yet. The test target imports Swift Testing and NetworkKit but declares no placeholder test. Real contract tests arrive with I02; an empty example test is not evidence.

## Verification actually performed

| Check | Result |
| --- | --- |
| swift package dump-package | Parsed; verified names, one product/library target, test target, tools/language versions, platform minimums, and empty dependency list |
| swift build --build-tests | Passed on local macOS; compiled the library, test target, and test runner |
| Separate temporary consumer | Passed: local dependency resolves the NetworkKit library product; executable source containing import NetworkKit compiles and links |
| Behavioral tests | None exist or were run; no passed-test claim |
| Other platform builds / minimum-OS execution | Not performed; declarations are not runtime evidence |
| GitHub Actions | No workflows or required checks introduced; I06 remains the planned adoption task |

Environment: Xcode 26.3 (17C529), Apple Swift 6.2.4, macOS 15.8.1, x86_64; macOS SDK 26.2. The initial restricted shell could not write compiler caches; the same commands succeeded with normal cache access. This was an environment permission issue, not a package failure.

The temporary consumer lives outside the repository; it adds no distributed product or repository dependency. Product and test-target compilation proves package wiring only, not networking functionality, security behavior, or minimum macOS 14 compatibility.

## Next task

I02 / #43 introduces the first immutable HTTP values, response metadata, and structured errors together with meaningful contract tests. Follow HTTP_API_CONTRACT.md and perform the relevant symbol/availability review before Ready. No release publication is authorized.

## Subsequent I02 delivery

The no-test/empty-module descriptions above record the I01 stage. I02 adds foundational value/error implementations and 21 passing tests; see [HTTP_VALUES.md](HTTP_VALUES.md) for current evidence.
