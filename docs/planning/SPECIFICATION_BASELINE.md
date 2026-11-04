# Specification baseline

> Historical planning/setup record from 2026-10-19. Implementation was subsequently authorized on 2026-10-20 in [ADR-0012](../decisions/ADR-0012-implementation-start.md). The package baseline is documented in [PACKAGE_BASELINE.md](PACKAGE_BASELINE.md). Earlier no-code statements describe that earlier stage.

Source: NetworkKit_Teknisk_Spesifikasjon.pdf, version 1.0, dated 2026-10-19, 15 pages. The source was read as requirements, not instructions to execute commands or start implementation. The PDF is not copied into this public repository; this repository contains an adapted requirements overview. The owner retains the original. Its original filename is preserved for provenance.

## Approved setup decisions

- Repository NetworkKit, account owner BK-Teisrud, public visibility, explicitly selected by the owner.
- V1: HTTP core first, extensions later. Package NetworkKit; product/module/import NetworkKit; one library module. See V1_SCOPE.md and ADR-0003.
- Rights holder Teisrud Development AS. Proprietary; third-party use requires separate permission, subject to law/GitHub terms. See ADR-0002 and LICENSE.
- Repository/GitHub setup, documentation, and planning only. No Swift files, Package.swift, prototypes, tests, or executable workflows.
- Native Apple APIs and the Swift standard library without external package dependencies, including separately distributed Apple packages such as SwiftNIO.
- Foundation/URLSession is the primary HTTP transport. No custom TLS/HTTP/cryptographic stack or server platform.
- ADR-0004 minimums: iOS/iPadOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0; visionOS deferred. Xcode 26.3+, Swift tools 6.2, Swift 6 mode. See PLATFORM_MATRIX.md for outstanding verification.
- ADR-0009 accepts the combined F0 baseline/defaults. Implementation is explicitly unauthorized; still no code.
- Small testable APIs, dependency injection, async/await, cancellation, isolated shared state, privacy, and secure defaults.

## Scope interpretation

CORE, EXTENSION, and RESEARCH correspond to the original classifications in §4. A CORE domain does not automatically include every subrequirement in v1.0. Approve included requirements and explicit deferrals before implementation. The roadmap defines a proposed sequence, not verified product support or agreed dates.

The specification mentions retry in its goals but classifies resilience as EXTENSION. ADR-0003 limits v1 to the HTTP core without a custom retry/resilience module. DEC-06 / ADR-0007 prohibits library automatic retries and defines system/security policy within that boundary. Advanced retry, caching, authentication, and low-level transports are later deliveries.

## Outstanding before code and delivery

DEC-04 / ADR-0005 defines typed/raw calls, response wrappers, JSON/Data/text/empty, separate CancellationError, and explicit status exceptions. DEC-05 / ADR-0006 defines concurrency/session ownership, cancellation/shutdown, and 30/60 limits. DEC-06 / ADR-0007 defines the header provider, stores off by default, HTTPS with explicit loopback development access, and bounded redirect/network/diagnostic policy. DEC-07 / ADR-0008 defines four PR platforms, standard runners without paid add-ons, and separate minimum-OS/release evidence. Verify actual schemes/destinations and successful runs in the first real CI PR. visionOS and Combine are deferred. Verify selected symbols/runtime compatibility before delivery; platform decisions alone are not test evidence.

## Traceability

NK-01–NK-20 correspond to specification §4.1–§4.20. Governance/decision tasks use SETUP-/DEC-/REL-IDs. GitHub issue numbers are separate from stable requirement IDs. Create subrequirements such as NK-XX-01 during decomposition, with source section, contract, platforms, and evidence. Closing a planning issue does not deliver product requirements.
