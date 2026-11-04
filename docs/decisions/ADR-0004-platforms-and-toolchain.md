# ADR-0004: Minimum platforms and toolchain for v1

Date: 2026-10-19. Status: Accepted by the project owner in conversation.
Issue: [DEC-01 / #1](https://github.com/BK-Teisrud/NetworkKit/issues/1).

## Approved choices

The owner explicitly selected:

- iOS/iPadOS, macOS, watchOS, and tvOS for the first stable release. visionOS is deferred.
- Minimum iOS/iPadOS 17.0, macOS 14.0, watchOS 10.0, and tvOS 17.0.
- Minimum Xcode 26.3, Swift tools 6.2, and Swift 6 language mode with strict concurrency checking.

Repository/package NetworkKit and product/module NetworkKit follow ADR-0003. This decision sets planned support and development requirements; it does not establish working code or successful tests.

## Decision and matrix

[PLATFORM_MATRIX.md](../planning/PLATFORM_MATRIX.md) is the authoritative platform and verification matrix. Minimum OS versions describe where consuming apps run. Xcode/Swift describe where the package is built. SDK versions are separate from minimum OS versions.

Use Xcode 26.3 as the first planned build/test reference. Before creating CI under DEC-07/F1, record the exact Xcode build, compiler, SDK, runner architecture, and test runtime. Newer stable Xcode releases may be adopted after verification; “26.3+” does not prove compatibility with all future releases. Beta/RC tools must not be the sole quality gate.

The Swift tools minimum is 6.2. The future manifest must explicitly select Swift 6 language mode. Strict concurrency checking applies from the outset; Swift 5 mode is not an alternative v1 support profile. No manifest is created now.

## Observed environment

A read-only inspection on 2026-10-19 showed Xcode 26.3 (17C529), Apple Swift 6.2.4, and macOS 15.8.1. Installed SDKs were iOS/iPadOS 26.2, macOS 26.2, watchOS 26.2, and tvOS 26.2. The compiler reported an x86_64 host. No product builds, package resolution, simulator boot, or runtime tests were performed.

Apple's support page lists a different Swift patch for Xcode 26.3 than the local compiler reports. Both belong to Swift 6.2; local output establishes the observed environment. Record exact patch/build identities on the actual runner instead of inferring them from the Xcode name.

## Alternatives and rationale

- Supporting only iOS/macOS would reduce the matrix. The owner also wants watchOS and tvOS in v1.
- Earlier minimums (iOS/tvOS 15, macOS 12, watchOS 9) would include more old OS versions. The owner selected a higher shared baseline.
- Later minimums (iOS/tvOS 18, macOS 15, watchOS 11) would exclude more old OS versions. Not selected.
- Xcode 27.1 / Swift 6.4 would require a different local macOS baseline. The owner chose tools suited to the observed installation.

## Availability and release evidence

Select concrete API symbols through DEC-04–DEC-06 and check them against the selected SDK and all four OS minimums before relevant tasks become Ready. OS/framework names do not establish identical behavior across platforms. Document and later verify necessary availability and compile-time boundaries.

Building with a declared minimum is not equivalent to testing on that OS. Record both build results and actual runtimes. Missing simulators, devices, or runners are missing evidence to resolve before advertising release support. This ADR selects no particular runner or test cost; DEC-07 addresses those choices.

This ADR resolves platform/toolchain selection, not symbol review, implementation, tests, or the F0 gate. Raising minimum OS versions after 1.0 follows the release policy's breaking-change rules.

## Sources

- [Apple: SDKs and system requirements](https://developer.apple.com/xcode/system-requirements)
- [Apple: Creating a standalone Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode)
- Local inspection: xcodebuild -version, xcrun swift --version, sw_vers -productVersion, and xcodebuild -showsdks.

ADR-0001 and earlier decisions remain historical. This decision resolves their open platform and toolchain choices.
