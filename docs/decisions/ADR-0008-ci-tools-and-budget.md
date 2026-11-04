# ADR-0008: CI, official tools, and cost limits

Date: 2026-10-19. Status: Core choices accepted by the owner; the execution plan and security details elaborate those choices.
Issue: [DEC-07 / #7](https://github.com/BK-Teisrud/NetworkKit/issues/7).

## Approved choices

The owner selected standard GitHub-hosted runners without paid add-ons, builds for all four platform families on every PR, tests on selected available runtimes, and separate release checks. This applies to future CI after explicit implementation authorization. No workflows are created now.

## Decision

[CI_AND_TEST_PLAN.md](../planning/CI_AND_TEST_PLAN.md) defines jobs, runner/toolchain baselines, test tools, the quality gate, and release evidence. Use Apple's Xcode/xcodebuild, Swift/Swift Package Manager, Swift Testing/XCTest, and DocC. Introduce no external Swift packages, formatter/lint/coverage SaaS, third-party setup actions, or self-hosted runners.

The planned baseline is macos-15 on a standard Apple Silicon runner, explicitly selecting /Applications/Xcode_26.3.app and checking Xcode/Swift/SDK/runtime. The official inventory lists Xcode 26.3 (17C529), iOS/watchOS/tvOS SDKs and simulator runtimes 26.2, and macOS host 15.7.9. The inspected image defaults to an older Xcode, so selection must be explicit. A runner label is not a frozen VM image; verify tools and runtimes on every run.

Swift Testing is primary for new unit/direct integration tests. XCTest supplements platform, performance, or harness needs. Use tools bundled with the selected toolchain, without an external testing package. Mocks, URLProtocol, and an internal controlled clock support deterministic tests. A test server is optional controlled infrastructure when justified, not a product module.

## Cost and access

Only standard-runner execution in the public repository is authorized. No paid runners, subscriptions, self-hosted services, paid artifact/cache storage, or add-on purchases. Artifact uploads and explicit Actions caching are disabled in the first CI version. Account-wide billing limits have not changed; a repository policy cannot guarantee the absence of all account charges. Reassess before changing visibility or storage/runner use.

GITHUB_TOKEN remains read-only and cannot approve PRs. Only local/GitHub-owned actions are permitted; full commit-SHA pinning is enforced by the repository setting and read back as true. No action, secret, or workflow was added. External reusable workflows are excluded; do not imply that the SHA rule covers every kind of external reference.

## Alternatives and rationale

Local checks first, or a fast macOS/iOS PR check with a full release-only matrix, were alternatives. The owner selected four platforms on every PR and separate release gates. Standard runners suit the public repository without approved runner costs. Paid larger machines and external services are excluded.

Minimum-OS runtime evidence is separate from PR runtimes. The approved minimums—iOS/iPadOS 17, macOS 14, watchOS 10, and tvOS 17—are not available as a complete set in the inspected macos-15 inventory. They must not be counted as tested in the standard matrix. Explicit manual/device evidence or another verified available official runtime is required before the first release. If evidence cannot be obtained, block the support claim and escalate the gap to the owner.

## Adoption gate

A future quality-gate must demonstrate real product builds/tests on main and in a PR before becoming required. No always-green check or skip for a missing Package.swift. The first real CI PR is not complete until all selected checks actually run. Until then, branch protection relies on documented manual verification.

DEC-07 resolves planning and tooling policy, not implementation or a working CI pipeline. At adoption, the F0 gate and separate implementation authorization remained outstanding. Treat runner inventory changes as maintenance requiring explicit assessment, without automatically raising OS minimums or toolchain requirements.

## Checks and sources

- Actions policy read back: selected actions, GitHub-owned actions allowed, verified/other patterns disabled, read-only token, no PR approval, sha_pinning_required true, zero workflows.
- [GitHub: Runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [GitHub: Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [Official macos-15 arm64 inventory](https://github.com/actions/runner-images/blob/82d1b86ad393865982dd29535cb8d3adbc68e41e/images/macos/macos-15-arm64-Readme.md), image 20260907.0337.1, reviewed 2026-10-19; no jobs have run against it.
- [GitHub: Actions settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-your-repository)
- [Apple: Testing](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)
