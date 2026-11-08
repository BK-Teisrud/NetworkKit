# Decision log

| ID | Topic | Status |
| --- | --- | --- |
| [ADR-0001](ADR-0001-repository.md) | Repository, workflow, and setup scope | Accepted for setup; later hardening and language choices supersede relevant parts |
| [ADR-0002](ADR-0002-ownership-and-rights.md) / DEC-03 | Rights holder and proprietary rights policy | Accepted: Teisrud Development AS; separate written permission |
| [ADR-0003](ADR-0003-v1-scope-and-naming.md) / DEC-02 | HTTP core and package/product/module naming | Accepted: HTTP core first; NetworkKit, one library module |
| [ADR-0004](ADR-0004-platforms-and-toolchain.md) / DEC-01 | Minimum platforms and toolchain | Accepted: four platform families; Xcode 26.3+, Swift tools 6.2, Swift 6 |
| [ADR-0005](ADR-0005-http-api-contract.md) / DEC-04 | Endpoints, raw requests, responses, headers/body, and errors | Accepted: typed + raw, response wrapper, JSON/Data/text/empty, separate cancellation |
| [ADR-0006](ADR-0006-concurrency-and-lifecycle.md) / DEC-05 | Session ownership, concurrency, cancellation, and clocks | Accepted: owned + injected session, 30/60 seconds, isolated state, explicit shutdown |
| [ADR-0007](ADR-0007-security-and-network-policy.md) / DEC-06 | Security, authentication, storage, privacy, and networking | Accepted: no automatic stores, header provider, HTTPS with loopback exception |
| [ADR-0008](ADR-0008-ci-tools-and-budget.md) / DEC-07 | CI, official tools, cost limits, and supply chain | Accepted: standard runners, no paid add-ons, four PR platforms, separate release evidence |
| [ADR-0009](ADR-0009-f0-approval-no-implementation.md) / GATE-00 #28 | Combined F0 acceptance and implementation status | Planning accepted; implementation unauthorized |
| [ADR-0010](ADR-0010-pre-code-governance.md) | Preparation and GitHub hardening | Accepted; preparations complete, start gate remains open |
| [ADR-0011](ADR-0011-language-policy.md) | English GitHub content; Norwegian collaboration | Accepted by explicit owner request |
| [ADR-0012](ADR-0012-implementation-start.md) | Begin the approved HTTP-core implementation | Accepted through the owner instruction on 2026-10-20; start gate closed |
| [ADR-0013](ADR-0013-watch-publication-gate.md) | Physical Watch timing and separate publication milestone | Accepted: mandatory WATCH-01 publication blocker; no physical pass or support change |
| [ADR-0014](ADR-0014-opt-in-retry-proposal.md) | First bounded per-call retry increment | Accepted contract/planning; I24–I27 explicitly authorized through START-F3 |
| [ADR-0015](ADR-0015-foreground-file-download.md) | Bounded foreground GET download | Accepted planning; I28 and later I29–I32 separately authorized; bounded technical F4 completed |


Additional decisions (later execution authority and source-specific acceptance remain in their linked records):

| ID | Topic | Status |
| --- | --- | --- |
| [ADR-0016](ADR-0016-unified-networkkit-name.md) | Unified NetworkKit naming | Accepted by owner |
| [ADR-0017](ADR-0017-current-platform-baseline.md) | Current deployment floors | Selected under explicit owner-delegated authority |
| [ADR-0018](ADR-0018-foreground-websocket-foundation-proposal.md) | Foundation foreground WebSocket design | Owner-approved architecture and separate linked exact contract; required plan gates/code/runtime pending |

ADR-0009 records combined acceptance of the core choices and documented defaults in ADR-0002–ADR-0008. Those planning decisions did not authorize implementation; ADR-0012 records the later authorization.

Use the [template](TEMPLATE.md). A proposed ADR does not authorize implementation. Acceptance requires the owner's explicit decision in the associated issue/PR or recorded conversation. Preserve a trace when superseding historical decisions; create a new ADR instead of silently changing their substance.
