# ADR-0009: F0 planning accepted; implementation not authorized

Date: 2026-10-19. Status: Accepted by the project owner in conversation.
Issue: [GATE-00 / #28](https://github.com/BK-Teisrud/NetworkKit/issues/28).

## Approval

The owner was explicitly asked to approve the complete F0 baseline, including documented defaults, with a link to F0_REVIEW.md and a clear distinction between planning and implementation.

The owner's response, translated from Norwegian: “Approve F0 planning; still no code.”

The reviewed baseline is the overview and documents published through PR #38, commit 2c5ee834a26df761a044bb478bd64fa69381534c. The seven decisions in ADR-0002–ADR-0008 and their contracts are thereby accepted together. Earlier ADRs remain historical; this ADR records the combined acceptance.

## Decision

- The planning and architecture baseline is accepted.
- Implementation is not authorized and has not started.
- Do not create Swift code, Package.swift, test targets, executable workflows, prototypes, or a product release without subsequent explicit authorization from the owner.
- GATE-00 may close as a completed planning decision with this explicit outcome. Closure does not permit development to start.

## Consequences

No approved API, security, or testing properties are claimed to exist or have passed tests. Before future tasks become Ready, provide concrete decomposition, necessary symbol/availability checks, and testable contractual criteria. Actual CI, minimum-OS/runtime evidence, security review, and release gates belong to a later authorized phase.

At adoption, OPS-01 / #30 remained open for GitHub setup and checks, separately from the eight planning decisions. F0 remained open while that work was outstanding. ADR-0010 and PR #65 later completed it; neither authorizes implementation.

Future changes to scope, rights, platforms, contracts, tools, or cost limits require documented rationale and necessary owner approval. Record any implementation authorization separately; this decision cannot be interpreted as such authorization.

## Verification

DEC-01–DEC-07 were documented and closed through PRs #32–#38. F0 approval was published through a separate documentation PR closing #28. JSON, local documentation links, and the diff were checked; absence of Swift files, Package.swift, and workflows was confirmed. GitHub reported zero workflows and enabled action SHA pinning. No product builds, tests, or publication were performed for this decision.
