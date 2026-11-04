# Approved F0 planning baseline

> Historical planning/setup record from 2026-10-19. Implementation was subsequently authorized on 2026-10-20 in [ADR-0012](../decisions/ADR-0012-implementation-start.md). The package baseline is documented in [PACKAGE_BASELINE.md](PACKAGE_BASELINE.md). Earlier no-code statements describe that earlier stage.

Status: Accepted by the owner on 2026-10-19. **Implementation is not authorized; still no code.** See [ADR-0009](../decisions/ADR-0009-f0-approval-no-implementation.md).
Date: 2026-10-19. Architecture gate: [GATE-00 / #28](https://github.com/BK-Teisrud/NetworkKit/issues/28).

## Decisions accepted together

| Issue | Decision | Authoritative documentation |
| --- | --- | --- |
| DEC-03 / #3 | Teisrud Development AS holds the rights. Proprietary; third-party use requires separate written permission, subject to law/GitHub terms. Public under BK-Teisrud | [ADR-0002](../decisions/ADR-0002-ownership-and-rights.md), LICENSE |
| DEC-02 / #2 | HTTP core first; repository/package NetworkKit, product/module/import NetworkKit, one library module | [ADR-0003](../decisions/ADR-0003-v1-scope-and-naming.md), [v1 scope](V1_SCOPE.md) |
| DEC-01 / #1 | iOS/iPadOS 17, macOS 14, watchOS 10, tvOS 17; Xcode 26.3+, Swift tools 6.2, Swift 6 mode; visionOS deferred | [ADR-0004](../decisions/ADR-0004-platforms-and-toolchain.md), [platform matrix](PLATFORM_MATRIX.md) |
| DEC-04 / #4 | Typed + raw requests; response wrapper; JSON/Data/text/empty; structured errors with separate CancellationError; 2xx with explicit call exceptions | [ADR-0005](../decisions/ADR-0005-http-api-contract.md), [HTTP contract](HTTP_API_CONTRACT.md) |
| DEC-05 / #5 | Reused owned session plus app-owned injection; configurable 30-second inactivity / 60-second total budget; isolated state, unambiguous cancellation/timeout, controlled shutdown | [ADR-0006](../decisions/ADR-0006-concurrency-and-lifecycle.md), [lifecycle](CONCURRENCY_AND_LIFECYCLE.md) |
| DEC-06 / #6 | Automatic stores off by default; small authentication-header provider; HTTPS with explicit local HTTP exception without credentials; bounded redirects, injection, sanitized logs | [ADR-0007](../decisions/ADR-0007-security-and-network-policy.md), [security policy](SECURITY_AND_NETWORK_POLICY.md) |
| DEC-07 / #7 | Standard GitHub runners without paid add-ons; four PR platform families and separate minimum-OS/release evidence; official test tools, SHA-pinned actions | [ADR-0008](../decisions/ADR-0008-ci-tools-and-budget.md), [CI/test plan](CI_AND_TEST_PLAN.md) |

The owner accepted the core choices and documented defaults together. No feature or test is presented as implemented. Issues hold live status; this overview records the decision baseline.

## Material consequences of the defaults

- Raw requests follow the same timing/security/status policies; no general bypass. Empty JSON bodies do not produce manufactured objects.
- The 30/60 defaults do not guarantee hard real-time return from synchronous app code; stricter borrowed-session limits remain effective.
- Shutdown cancels only the client's operations and invalidates only its owned session. No separate graceful-drain mode in v1.
- Ephemeral does not mean no RAM storage; explicitly disable stores in the default profile. Other system storage requires deliberate app choice.
- Providers do not log in or refresh tokens. No credentials over HTTP, even locally. Redirect defaults: same-origin GET/HEAD, at most five hops; no automatic mutating replay/cross-origin/downgrade.
- No generic error-body capture, external telemetry, custom retry/cache/offline/streaming module, or new package dependencies in v1.
- CI plans do not establish minimum-OS coverage. Minimum runtimes/devices remain unconfirmed; newer simulator results must not hide missing evidence.

## Meaning of F0 approval

The owner may approve the planning/architecture baseline while keeping implementation stopped. Such approval does not permit creating library code, manifests, tests, workflows, or releases.

Before tasks become Ready, decompose contracts into concrete issues with necessary symbol/availability checks and testable criteria. Before release, satisfy real tests, security review, runtime/minimum-OS evidence, and delivery requirements.

Only later explicit implementation authorization changes the restriction. PRs and closed decision issues do not grant it automatically. GATE-00 records both planning acceptance and implementation not authorized.

## GitHub setup follow-up

The setup review identified views/duplicate status, admin bypass, tag/release protection, web sign-off, and private contact channels as OPS-01 / #30 follow-ups. SHA pinning was enabled. These changes were separate from the DEC decisions and were subsequently addressed in ADR-0010 and SETUP_STATUS.md; a contact address is explicitly deferred.

No billing settings, subscriptions, collaborators, secrets, or external apps were added. No Swift files, Package.swift, workflows, or release tags were created.

## Approval

Owner response on 2026-10-19, translated from Norwegian: “Approve F0 planning; still no code.” Approval covers the baseline published through PR #38, including the defaults and limitations above. GATE-00 and ADR-0009 record planning accepted, implementation unauthorized. Later changes require documented assessment; code needs separate explicit approval.
