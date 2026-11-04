# NetworkKit

[![CI](https://github.com/BK-Teisrud/NetworkKit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/BK-Teisrud/NetworkKit/actions/workflows/ci.yml)

A native networking library for Apple platforms, distributed as a Swift package with no external package dependencies.

**Status: F2 is closed after the accepted non-publishing HTTP-core rehearsal.** The selected core and recorded minimum/non-Watch evidence are documented in the [F2 closeout](docs/planning/F2_CLOSEOUT_2026-10-31.md). No stable version/tag or release exists. Physical Watch #132 and actual workload/security/publication #29 remain mandatory. Bounded retry implementation I24–I27 is authorized under ADR-0014/#137. The bounded F3 technical gate is accepted with recorded limitations; see the [F3 closeout](docs/planning/F3_CLOSEOUT_2026-11-01.md) and #110 for formal completion.

The selected F4 download increment is now authorized under ADR-0015. I29 adds a [foreground GET-to-file API](Sources/NetworkKit/NetworkKit.docc/FileDownloads.md); [its implementation report](docs/planning/I29_FOREGROUND_DOWNLOAD.md) distinguishes critical-path local verification from the remaining I30–I32/native/publication gates. No stable release or production suitability is implied.

Open the repository-root Package.swift in Xcode. The package is named NetworkKit and exposes the NetworkKit library. Tests cover HTTP values, configuration, construction, response interpretation, session ownership, network policy and client integration, with platform-specific evidence described in the guides. See [implementation authorization](docs/decisions/ADR-0012-implementation-start.md).

## Project foundations

Foundation/URLSession is the primary HTTP transport. Swift Concurrency, injectable services, system trust, and privacy-preserving defaults guide the design. Network.framework may be considered for specific low-level requirements. The project will not implement its own HTTP, TLS, or cryptographic stack, or provide a backend product.

The repository and package are named **NetworkKit**. The library product, module, and import name are **NetworkKit**, with one library module in v1. The first stable release is limited to the HTTP core; other modules are deferred. The package and selected HTTP core are implemented; rehearsal and separate publication gates remain distinct. See [v1 scope](docs/planning/V1_SCOPE.md), [ADR-0003](docs/decisions/ADR-0003-v1-scope-and-naming.md) and the [unified naming decision](docs/decisions/ADR-0016-unified-networkkit-name.md).

## Documentation

- [Quality/maintainability review and deliberate simplification](docs/planning/QUALITY_REVIEW_2026-10-26.md)

- [Compiled integration guide: installation, calls, formats, errors, authentication, ownership and testing](Sources/NetworkKit/NetworkKit.docc/IntegrationGuide.md)
- [Public API/availability review and guide verification](docs/planning/API_REVIEW.md)
- [Contract-to-test evidence and explicit release gaps](docs/planning/TEST_EVIDENCE.md)

- [Storage profiles and controlled local-server verification](docs/planning/STORAGE_VERIFICATION.md)

- [Optional sanitized diagnostics and canary verification](docs/planning/SANITIZED_DIAGNOSTICS.md)

- [Authentication provider, account/origin isolation and verification](docs/planning/AUTHENTICATION_PROVIDER.md)

- [Explicit shutdown, owned/borrowed sessions and concurrency evidence](docs/planning/SHUTDOWN_AND_CONCURRENCY.md)

- [Cancellation, total budget and cleanup evidence](docs/planning/CANCELLATION_AND_BUDGET.md)

- [F1 HTTP core verification and remaining v1 gates](docs/planning/F1_REVIEW.md)

- [Public HTTP client, integration evidence and current limits](docs/planning/HTTP_PIPELINE.md)

- [HTTPS, loopback, redirect/trust rules and actual evidence](docs/planning/NETWORK_SECURITY.md)

- [Session ownership, internal transport, and limitations](docs/planning/SESSION_TRANSPORT.md)

- [Response strategies, status policies, and test evidence](docs/planning/RESPONSE_DECODING.md)

- [Real CI, required quality gate, and verification evidence](docs/planning/CI_IMPLEMENTATION.md)

- [Request bodies, header precedence, and actual test evidence](docs/planning/REQUEST_ENCODING.md)

- [Endpoint API, URL validation, and test evidence](docs/planning/ENDPOINT_URLS.md)

- [Configuration API, internal seams, and test evidence](docs/planning/CONFIGURATION.md)
- [HTTP value API and actual test evidence](docs/planning/HTTP_VALUES.md)
- [Readiness review before implementation](docs/planning/PRE_CODE_READINESS.md)
- [Numbered work queue](docs/planning/WORK_QUEUE.md)
- [Test environment inventory and recorded runtime evidence](docs/planning/TEST_ENVIRONMENTS.md)
- [Setup status and verification](docs/governance/SETUP_STATUS.md)
- [GitHub settings and rules](docs/governance/GITHUB_CONFIGURATION.md)
- [Workflow and project management](docs/planning/PROJECT_MANAGEMENT.md)
- [Historical F0 planning approval](docs/planning/F0_REVIEW.md)
- [CI and test plan](docs/planning/CI_AND_TEST_PLAN.md)
- [Security and network policy](docs/planning/SECURITY_AND_NETWORK_POLICY.md)
- [Concurrency and lifecycle](docs/planning/CONCURRENCY_AND_LIFECYCLE.md)
- [HTTP, response, and error contract](docs/planning/HTTP_API_CONTRACT.md)
- [Platform and toolchain matrix](docs/planning/PLATFORM_MATRIX.md)
- [Roadmap and delivery gates](docs/planning/ROADMAP.md)
- [Requirements traceability and backlog](docs/planning/BACKLOG.md)
- [Specification baseline](docs/planning/SPECIFICATION_BASELINE.md)
- [Decision log](docs/decisions/README.md)
- [Quality gates and test strategy](docs/governance/QUALITY.md)
- [Release and compatibility policy](docs/governance/RELEASE_POLICY.md)
- [Risk register](docs/planning/RISKS.md)
- [Contributing](CONTRIBUTING.md), [security](SECURITY.md), and [governance](GOVERNANCE.md)

## Platforms and rights

Approved v1 targets: **iOS/iPadOS 17+, macOS 14+, watchOS 10+, and tvOS 17+**. visionOS is deferred. Development baseline: **Xcode 26.3+, Swift tools 6.2, and Swift 6 language mode with strict concurrency checking**. See the [platform matrix](docs/planning/PLATFORM_MATRIX.md) and [ADR-0004](docs/decisions/ADR-0004-platforms-and-toolchain.md). PR CI now builds all four platform families and runs the product contract tests on macOS plus iPhone, iPad, Apple Watch, and Apple TV simulators. The required quality-gate also covers source integrity and DocC. Minimum-family and non-Watch physical evidence are accepted within the exact patch/architecture/suite limits in the platform matrix. Physical Watch #132 and the separate publication/workload decision #29 remain open.

**Rights holder: Teisrud Development AS. NetworkKit is proprietary.** Third-party use requires separate written permission from the company, subject to statutory rights and GitHub's applicable terms. Public visibility permits viewing and forking through GitHub; the project grants no additional open-source license or general permission to use the material in applications.

See the [rights notice](LICENSE) and [ownership and rights decision](docs/decisions/ADR-0002-ownership-and-rights.md). Ask maintainer @BK-Teisrud for a confirmed permission-request contact channel; do not share confidential information publicly.

## Language

All repository documentation and GitHub project content use English. The owner and assistant continue to communicate in Norwegian. See [the language policy](docs/governance/LANGUAGE_POLICY.md).
