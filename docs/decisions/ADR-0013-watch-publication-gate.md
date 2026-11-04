# ADR-0013: Move missing physical Watch verification to the publication gate

Date: 2026-10-31. Status: Accepted by explicit owner decision; repository review/main acceptance pending.
Owner: @BK-Teisrud. Follow-up: [WATCH-01 / #132](https://github.com/BK-Teisrud/NetworkKit/issues/132); publication: #29.

## Decision and authorization

The owner selected “Approve moving to a mandatory release blocker” in response to the concrete [phase-gate proposal](../planning/F2_WATCH_GATE_DECISION_2026-10-31.md). The original Norwegian approval remains in the conversation. This is an explicit change to phase acceptance, not an inferred test waiver.

Only the missing physical Watch regression, native networking and applicable lifecycle/storage/transition/resource evidence moves from F2 to WATCH-01. watchOS 10 support, v1 scope and toolchain minima remain unchanged. Minimum Watch simulator evidence is retained separately. No unexecuted physical test is passed and no product compatibility guarantee is added.

WATCH-01 is a native blocker and sub-issue of #29, with an explicit release checklist item. #29 and WATCH-01 move to the separate “v1.0 – Publication gate” milestone. That split is necessary because #29 previously belonged to F2 despite being a separately authorized publication gate. Issue dependencies track required work; they alone do not technically prevent unauthorized publication.

## Phase consequences

Narrow #63 to the completed non-Watch physical evidence and its documented applicability/resource limits. Closure still requires accepted evidence and the scope-change PR/main. #86 must reconcile all selected F2 criteria with this one explicit deferral, and #64 remains a non-publishing clean-consumer/archive/privacy rehearsal. Keep #27 and F2 open until their other criteria pass. No original domain epic is automatically closed.

WATCH-01 must obtain accepted physical evidence, or a separate explicit product-support/risk decision must change the exact unmet requirement, before #29 publication. Its dependency does not point back from #63/#86/#64, avoiding a cycle. No other non-Watch evidence or risk is deferred by this decision. Owner workload remains unknown; finite RSS observations are not workload acceptance.

## Continuing restrictions and evidence

The [mount diagnosis](../planning/evidence/F2_WATCH_MOUNT_DIAGNOSIS_2026-10-31.json) remains a failed infrastructure preparation, not an SDK test failure. Developer Mode is enabled; CoreDevice 12040 / MobileDevice 0xe8000076 prevents mounting the existing Apple image. No underlying cause is conclusively attributed.

No hardware purchase, paid service, OS/toolchain upgrade, pairing removal, credential/profile/certificate/account change, security bypass, tag/release/publication or F3 implementation is authorized. F3 needs its own selected scope/start decision. This ADR supersedes only the physical-Watch timing requirement in earlier F2 planning; original support and security decisions remain effective.
