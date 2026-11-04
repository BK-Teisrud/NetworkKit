# ADR-0003: HTTP core in v1 and package, product, and module names

Date: 2026-10-19. Status: Accepted by the project owner in conversation.
Issue: [DEC-02 / #2](https://github.com/BK-Teisrud/NetworkKit/issues/2).

## Context and approval

The original owner decision selected the HTTP core first and one library module. On 2026-11-04 the owner unified repository, package, product and import under NetworkKit; [ADR-0016](ADR-0016-unified-networkkit-name.md) supersedes the original repository/package naming distinction. This naming decision does not expand implementation scope.

## Decision

| Role | Approved name / boundary |
| --- | --- |
| GitHub repository | NetworkKit |
| Swift package | NetworkKit |
| Library product | NetworkKit |
| Library module / target / import | NetworkKit |
| Library modules in v1 | One |

Use these names consistently in the future manifest, documentation, and consumer examples. The package will expose NetworkKit, and consumers will import NetworkKit. No manifest, targets, or import code are created now. Separate test targets are allowed later and do not count as additional distributed library modules. A separate testing-helper product is outside v1.

The first stable release provides a bounded HTTP core with typed calls, JSON, predictable errors, timeout/cancellation, safe logging, and deterministic tests. Necessary configuration, dependency injection, privacy, documentation, and platform availability accompany the core from the outset. URLSession is the primary transport, with secure system defaults.

[V1_SCOPE.md](../planning/V1_SCOPE.md) defines the normative delivery boundary. Public contract and policy details were assigned to DEC-04–DEC-06; minimum OS versions and tools to DEC-01 and DEC-07.

## Alternatives and trade-offs

- Separate repository/package and product/import names were originally selected. The owner subsequently chose one name everywhere; the current table reflects that superseding decision.
- Multiple library modules from the outset would provide separate products, but introduce dependency and API boundaries before a need is established. Not selected.
- Delivering retry/cache or the full feature catalog before the first stable release would expand the initial delivery. The owner chose the HTTP core first.

## Consequences

F0 → F1 → F2 is the path to v1. F3–F6 remain possible later releases. No delivery dates are promised. Domain epics retain their specification classifications without promising every subrequirement in v1.

Use internal types for complexity that does not require a public contract. Consider separate modules later when a need is documented, explicitly assessing dependencies and compatibility. Original proposals such as NetworkKitAuth and NetworkKitTesting are not approved v1 products.

Create concrete tasks before development becomes Ready, once relevant contracts are accepted. Closing DEC-02 records the scope and module decision; it does not deliver domain epics or complete the other F0 decisions.

ADR-0001 remains historical; this ADR resolves its open naming and scope questions.
