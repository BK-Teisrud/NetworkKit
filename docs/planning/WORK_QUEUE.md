# Work queue

## Current delivery — 2026-11-09

I31/#149 and I32/#150 are completed through PR #163/main f86ddcb5ba7a26d05b370007f70b439d0eff5999/run 42406475143, all seven checks/full log accepted. F4 is closed under the explicit owner-approved bounded technical disposition. The [technical review](F4_TECHNICAL_REVIEW_2026-11-04.md) and [evidence](evidence/F4_DOWNLOAD_CLOSEOUT_2026-11-04.json) preserve candidate-time status and source-specific observations; actual closure is recorded in the issues. Publication #29/#132 remains blocked; no release is authorized.

PLAN-F5/#89 is completed after exact-plan PR #175/main7c192977d867201288e60532b51d8c8d711b11a1/run42505791505, all seven checks/full-log and task readback accepted. Architecture ADR-0018 and the [exact API/delivery contract](F5_API_AND_DELIVERY_CONTRACT.md) are owner-approved; the owner subsequently authorized I33–I36 together in one implementation PR.

The combined implementation is [PR #176](https://github.com/BK-Teisrud/NetworkKit/pull/176). I33/I34/I35 have completed candidate implementation/verification; live review and owner/final CI gates are tracked in Project Status and I36/#174. Internal order remains values/state → Foundation adapter → integration/guide/resources → technical review; no intermediate implementation merge. The final suite passes 309 tests/37 suites (40 WebSocket tests); strict DocC passes. Seven selected native routes pass all eight fixed-frame cases, corrected Mac/iPhone 18.2 core checks pass, and the finite Mac resource profile is recorded. Original failed attempts remain retained. Both explicit runtime budgets are completed/exhausted; no further network authority remains. See [technical review](F5_TECHNICAL_REVIEW_2026-11-09.md). No automatic closure or production acceptance; final required PR/main and the I36 disposition remain separate.

#165/#168 findings remain source-specific/negative/incomplete, not SDK feature passes. #17 remains undelivered; streams/heartbeat/reconnect/background/direct Watch deferrals unchanged, HTTP Watch unchanged; #29/#132 remain separate publication barriers. No extra milestone or speculative module/framework/refactor.

Project Status owns live state, this queue/JSON define dependencies and ROADMAP selected scope. Continue useful independent work during CI without polling. Dependent merges require accepted predecessor/main and candidate checks. Maximum five work processes.

## Accepted F2 and next lanes

The [F2 closeout](F2_CLOSEOUT_2026-10-31.md) records accepted core hardening/rehearsal, final main d0a522770269617f95660d67e9d0198838dc2bb5/run 41244932962 and the milestone-counter discrepancy. Original submission-time evidence/failure limits remain immutable. The F2-only resource disposition is not F3 or production acceptance.

F4 selected I29–I32 and the combined maintenance are completed under their recorded limits. #89 planning is completed; #171–#174 own current F5 delivery; #90 remains independent research, and deferred domain catalogs stay open. The owner now permits useful work while CI runs, without polling; retain predecessor/main and candidate gates before dependent merges.

## Accepted core implementation history

**Historical core authorization on 2026-10-20; [START-00 / #41](https://github.com/BK-Teisrud/NetworkKit/issues/41) is closed.** [ADR-0012](../decisions/ADR-0012-implementation-start.md) records the instruction. I01 established the package baseline. I02 implements foundational HTTP values/errors and their tests; I03 adds isolated configuration snapshots and internal transport/clock seams; I04 adds safe endpoint/URL construction and shared raw-URL validation; I05 adds buffered request encoding, call headers/options, and raw preparation; I06 adds real platform/source/DocC CI and required quality-gate enforcement; I07 adds buffered response strategies and per-call status validation; I08 adds the internal owned/borrowed URLSession adapter; I09 adds shared HTTPS/origin/loopback policy and per-operation redirect/trust delegates; I10 connects typed/raw calls to the public shared HTTP pipeline. I11 verifies the F1 contract/evidence boundary; see [F1 review](F1_REVIEW.md) and #52 for actual acceptance. I12 adds per-call cancellation/terminal arbitration and the monotonic total budget; see [timing evidence](CANCELLATION_AND_BUDGET.md). I13 adds explicit shutdown, operation registration and concurrent-call verification; see [lifecycle evidence](SHUTDOWN_AND_CONCURRENCY.md). I14 adds the [bounded authentication-header provider](AUTHENTICATION_PROVIDER.md), with app-owned login/token storage and no refresh/replay. I15 adds [optional sanitized diagnostics](SANITIZED_DIAGNOSTICS.md), disabled by default with a fixed metadata allowlist. I16 verifies [storage profiles against a controlled local server](STORAGE_VERIFICATION.md) and exposes the explicit app-managed borrowed-session selection. I17 accepted the [contract/regression ledger](TEST_EVIDENCE.md) and [test inventory](TEST_INVENTORY.md) through PR #93 / main run 40377796452. I18 reviews the [public API and compiled integration guide](API_REVIEW.md); its acceptance remains recorded in #59. The 2026-10-26 planning review adds PREP-01 / #85 (Order 16.5) as the early planning action (accepted through PR #92 and main run 40374198746; see [environment readiness](ENVIRONMENT_READINESS.md) and #85) and GATE-F2 / #86 (Order 22.5) before rehearsal; see [plan audit](PLAN_REVIEW_2026-10-26.md).

Choose the lowest Order with closed blockers and satisfied Ready criteria. This is a recommended serial sequence for one developer, not a schedule. Reordering requires dependency review rather than new scope. See the [Work Queue](https://github.com/users/BK-Teisrud/projects/6/views/7).

| Order | Task | Parent epic | Dependencies in addition to #41 |
| --- | --- | --- | --- |
| 1 | [[I01] Create the Swift package and test target after authorization](https://github.com/BK-Teisrud/NetworkKit/issues/42) | #27 | None |
| 2 | [[I02] Define immutable HTTP values, responses, and error taxonomy](https://github.com/BK-Teisrud/NetworkKit/issues/43) | #11 | #42 |
| 3 | [[I03] Implement configuration snapshots and internal test boundaries](https://github.com/BK-Teisrud/NetworkKit/issues/44) | #22 | #43 |
| 4 | [[I04] Implement safe endpoint and URL construction](https://github.com/BK-Teisrud/NetworkKit/issues/45) | #9 | #44 |
| 5 | [[I05] Implement headers and request encoding](https://github.com/BK-Teisrud/NetworkKit/issues/46) | #8 | #45 |
| 6 | [[I06] Enable real PR CI for all four platform families](https://github.com/BK-Teisrud/NetworkKit/issues/47) | #23 | #46 |
| 7 | [[I07] Implement response strategies and HTTP status validation](https://github.com/BK-Teisrud/NetworkKit/issues/48) | #10 | #47 |
| 8 | [[I08] Implement URLSession ownership and the transport adapter](https://github.com/BK-Teisrud/NetworkKit/issues/49) | #21 | #48 |
| 9 | [[I09] Implement HTTPS, loopback, and redirect policies](https://github.com/BK-Teisrud/NetworkKit/issues/50) | #25 | #49 |
| 10 | [[I10] Connect typed and raw calls to one secure HTTP pipeline](https://github.com/BK-Teisrud/NetworkKit/issues/51) | #8 | #50 |
| 11 | [[I11] Verify the initial HTTP core and F1 gate](https://github.com/BK-Teisrud/NetworkKit/issues/52) | #23 | #51 |
| 12 | [[I12] Implement cancellation and the total time budget](https://github.com/BK-Teisrud/NetworkKit/issues/53) | #21 | #52 |
| 13 | [[I13] Implement shutdown and concurrency isolation](https://github.com/BK-Teisrud/NetworkKit/issues/54) | #21 | #53 |
| 14 | [[I14] Implement the bounded authentication-header provider](https://github.com/BK-Teisrud/NetworkKit/issues/55) | #25 | #54 |
| 15 | [[I15] Implement sanitized optional diagnostics](https://github.com/BK-Teisrud/NetworkKit/issues/56) | #20 | #55 |
| 16 | [[I16] Verify secure storage and injected-session profiles](https://github.com/BK-Teisrud/NetworkKit/issues/57) | #25 | #56 |
| 16.5 | [[PREP-01] Prepare minimum-OS and physical-device evidence access](https://github.com/BK-Teisrud/NetworkKit/issues/85) | #23 | None; planning/inventory only |
| 17 | [[I17] Complete the test matrix and regression suite](https://github.com/BK-Teisrud/NetworkKit/issues/58) | #23 | #57 |
| 18 | [[I18] Complete API review, DocC, and integration guides](https://github.com/BK-Teisrud/NetworkKit/issues/59) | #27 | #58, #95 |
| 18.5 | [[BUG-01] Bound native HTTP probe liveness and diagnose main timeouts](https://github.com/BK-Teisrud/NetworkKit/issues/95) | #23 | None; repair I18 main evidence before acceptance |
| 18.75 | [[QA-01] Review quality and remove stale validation duplication](https://github.com/BK-Teisrud/NetworkKit/issues/97) | #27 | #59 |
| 19 | [[I19] Conduct the v1 security and privacy review](https://github.com/BK-Teisrud/NetworkKit/issues/60) | #25 | #59, #97 |
| 20 | [[I20] Measure baseline resource use and package quality](https://github.com/BK-Teisrud/NetworkKit/issues/61) | #27 | #60 |
| 20.5 | [[RES-01] Diagnose repeated-call RSS growth against native URLSession control](https://github.com/BK-Teisrud/NetworkKit/issues/100) | #27 | #61 |
| 20.75 | [[TLS-01] Verify native macOS rejection of an untrusted HTTPS certificate](https://github.com/BK-Teisrud/NetworkKit/issues/104) | #25 | #60 |
| 21 | [[I21] Obtain and document minimum-OS runtime evidence](https://github.com/BK-Teisrud/NetworkKit/issues/62) | #23 | #60, #85 |
| 22 | [[I22] Run representative tests on physical Apple devices](https://github.com/BK-Teisrud/NetworkKit/issues/63) | #23 | #60, #85 |
| 22.5 | [[GATE-F2] Reconcile v1 requirements, domain epics, and release evidence](https://github.com/BK-Teisrud/NetworkKit/issues/86) | #29 | #59, #60, #61, #62, #63, #100, #104 |
| 23 | [[I23] Rehearse the v1 release without publishing](https://github.com/BK-Teisrud/NetworkKit/issues/64) | #27 | #63, #86 |
| 23.75 | [WATCH-01: physical Watch publication evidence](https://github.com/BK-Teisrud/NetworkKit/issues/132) | #29; publication milestone | Supported Watch development route; ADR-0013 |
| 24 | [REL-01: Actual v1 release gate](https://github.com/BK-Teisrud/NetworkKit/issues/29) | Governance | #64 and selected core epics |

Historical review, 2026-10-27: preparation PR #103 is accepted through main run 40550211780. [TLS-01 / #104](NATIVE_TLS_REJECTION.md), Order 20.75, adds independently executable native macOS untrusted-certificate rejection coverage. It blocks #86 while #62/#63 remain Blocked for actual minimum/physical execution. System-trusted positive HTTPS and independent hostname-mismatch evidence are still missing. No support/tool change or owner-risk acceptance is inferred.

## Why this sequence

Values/configuration precede URL/request encoding. Real CI follows early meaningful tests and precedes further transport work. Response handling, transport, and network policy form a vertical HTTP slice before the F1 gate. Then verify timing, lifecycle, authentication, and privacy together. API/DocC and security review precede resource measurements and actual runtime/device evidence. Environment access is investigated early. Minimum-runtime and newer-device execution do not block each other; both must pass the F2 reconciliation. Rehearsal publishes nothing.

Every issue includes acceptance criteria and tests. Relevant tests/docs accompany each implementation PR; they are not deferred to I17/I18, which are consolidated reviews. Native blockers/subissues are configured but do not independently enforce merges.

I21 may investigate access to older test environments as preparation without code; actual product tests require implementation. Missing access blocks release. If evidence cannot be obtained, explicitly revisit support rather than automatically downgrading devices or buying equipment.

## Post-v1 planning queue

| Order | Planning task | Domain coverage | Readiness |
| --- | --- | --- | --- |
| 30 | [PLAN-F3 / #87](https://github.com/BK-Teisrud/NetworkKit/issues/87) | #14 first; assess #12/#15/#19/#24 separately | Done; ADR-0014 and selected I24–I27 decomposition accepted |
| 40 | [PLAN-F4 / #88](https://github.com/BK-Teisrud/NetworkKit/issues/88) | #16/#26 | Done after PR #154/main run 41323512108; I28 accepted |
| 50 | [PLAN-F5 / #89](https://github.com/BK-Teisrud/NetworkKit/issues/89) | #17 | Completed after accepted PR #175/main; no code authority |
| 50.1 | [FEAS-F5 / #165](https://github.com/BK-Teisrud/NetworkKit/issues/165) | #89 | Completed after accepted PR #166/main |
| 50.2 | [FEAS-F5-SEC / #168](https://github.com/BK-Teisrud/NetworkKit/issues/168) | #89 | Completed after accepted PR #169/main; negative/incomplete findings preserved |
| 51 | [I33 / #171](https://github.com/BK-Teisrud/NetworkKit/issues/171) | #17 | Done after PR #176/main run 42595061321 and full-log review; ordered manual closure verified |
| 52 | [I34 / #172](https://github.com/BK-Teisrud/NetworkKit/issues/172) | #17 | Done after PR #176/main run 42595061321 and full-log review; ordered manual closure verified |
| 53 | [I35 / #173](https://github.com/BK-Teisrud/NetworkKit/issues/173) | #17 | Done after PR #176/main run 42595061321; source-specific evidence/limits retained |
| 54 | [I36 / #174](https://github.com/BK-Teisrud/NetworkKit/issues/174) | #17 | Done after conditional owner technical disposition, PR #176/main run 42595061321 and full-log review |
| 60 | [PLAN-F6 / #90](https://github.com/BK-Teisrud/NetworkKit/issues/90) | #13/#18 | In Progress, planning only; broad-reuse objective and one-plan/one-delivery PR target; see [F6 proposal](F6_COMPREHENSIVE_PLAN.md) |
| 60.1 | [PREP-F6-TLS / #178](https://github.com/BK-Teisrud/NetworkKit/issues/178) | #90 | In Review; [#178 correction](F6_TLS_CORRECTION_RESULTS_2026-11-09.md) passed selected build/pure/local controls; integrated PR #177/main still required, no separate PR or new execution |
| 60.2 | [FEAS-F6-NATIVE / #179](https://github.com/BK-Teisrud/NetworkKit/issues/179) | #90 | Blocked for code/execution; [consolidated native scope](F6_NATIVE_RESEARCH_SCOPE.md) prepared in the same PR #177; no artificial wait for separate #178 merge |

The planning rows do not themselves authorize extension implementation. F2/F3 are complete; selected F4 authorization and current delivery are recorded above. Future epics have no Order and require new scope decisions; only selected implementation slices receive I identifiers. Parent epics may span phases; individual subtasks' milestones define delivery requirements. Reassess phase boundaries after selection and sizing, without inventing dates.

## Historical F2 closure preparation — 2026-10-27

[Preliminary F2 review](F2_REVIEW.md) indexes the ten core epics and 79 original source bullets without changing approved scope. #104 is accepted through main run 40556606300; #62/#63 actual access/execution and complete HTTPS/resource evidence remain Blocked. Both precede #86; #64 and #27 rehearsal follow, and #29 retains separate release authorization. Preparation does not satisfy those gates. F3 candidate work in other branches remains outside this F2 baseline.

Physical iPhone follow-up: [PREP-02 / #113](https://github.com/BK-Teisrud/NetworkKit/issues/113) is Ready/P1/CORE/Order 20.9 under #23, blocked by accepted START/I18 and blocking I22. Unsigned/signed builds succeeded, but actual device execution failed before tests because package tool-hosted tests need an app host. See [sanitized evidence](evidence/F2_IPHONE_ATTEMPT_2026-10-27.json). This is the next bounded F2 preparation task; no physical test pass or new host installation is claimed.

PREP-02 implementation: [app-hosted iOS route](IOS_DEVICE_TEST_HOST.md) reuses all shared test files with drift guards and an unsigned device build in ios-core. Its 215-test app-hosted simulator and physical iPhone 17 Pro/iOS 27.2 runs passed; the temporary host was removed. Required PR/main checks remain on #113. Keep #63/#86 open for their complete evidence.

NET-01 / [#115](https://github.com/BK-Teisrud/NetworkKit/issues/115), P1 CORE Order 20.95 under #23, follows accepted I19/PREP-02 and blocks I22. [Public HTTPS verification](PUBLIC_HTTPS_VERIFICATION.md) supplies bounded native observations without provisioning a paid server; normal CI compiles only. #62 minimum access remains independent and all unproved native/resource/release claims stay open.

NET-01 #115 accepted through PR #116/main 40644612904. NET-02 #117 accepted through PR #118/main 40745209513. NET-02 / [#117](https://github.com/BK-Teisrud/NetworkKit/issues/117), P1 CORE Order 20.96 under #23, follows accepted NET-01/PREP-02 and blocks I22. [Native lifecycle/storage observations](NATIVE_LIFECYCLE_STORAGE.md) remain separate from full ENV/resource/transition acceptance. [Minimum-runtime leads and authorization](MINIMUM_RUNTIME_ACCESS_2026-10-28.md) belong to independent #62; all three imports and [four separate minimum simulator regression runs](MINIMUM_RUNTIME_EXECUTION_2026-10-28.md) are now verified locally (215/215 each). A fresh iPhone boot completed after earlier migration timeouts. macOS 14 and remaining native/resource requirements remain open; this evidence awaits its PR/main acceptance.

Minimum macOS follow-up, 2026-10-29: [temporary standard GitHub macOS 14 execution route](MACOS14_EXECUTION_ROUTE_2026-10-29.md) prepares an exact-source prebuilt public consumer with the approved builder. Actual macOS 14 results are pending; observe brownout/retirement and stop at CI-dependent points. PR #120 minimum simulator evidence is accepted through main run 40765690271. Remaining native/physical/resource/rehearsal requirements are unchanged.

## Historical planning before complete approval — 2026-10-31

#87 and F3-DEC #106 are planning work. [Proposed ADR-0014](../decisions/ADR-0014-opt-in-retry-proposal.md) and [contract/decomposition](RETRY_INCREMENT_PLAN.md) record owner selections; complete acceptance/code start remain pending. Existing candidates #107/#108/#109/#110 stay Backlog, no I identifiers. Planned order is decision → eligibility/delay contracts → one-operation integration → native/resource verification → increment gate. Preserve the accepted F2 rows and separate #132/#29 publication lane. A documentation PR or generic continue instruction does not authorize retry code.

- Order 40.1: [START-F4 / #145](https://github.com/BK-Teisrud/NetworkKit/issues/145) — Done; I28 feasibility only authorized. See download plan for dependencies.

- Order 40.2: [I28 / #146](https://github.com/BK-Teisrud/NetworkKit/issues/146) — Done after PR #154/main run 41323512108; detailed design accepted. See download plan for dependencies.

- Order 40.3: [I29 / #147](https://github.com/BK-Teisrud/NetworkKit/issues/147) — Done after PR #155/main run 41329332271. See download plan for dependencies.

- Order 40.4: [I30 / #148](https://github.com/BK-Teisrud/NetworkKit/issues/148) — Done after PR #156/main run 41333096996. See download plan for dependencies.

- Order 40.5: [I31 / #149](https://github.com/BK-Teisrud/NetworkKit/issues/149) — Blocked by the maintenance chain; native Mac checkpoint and remaining platform/HTTPS/resource criteria retained. See download plan for dependencies.

- Order 40.6: [I32 / #150](https://github.com/BK-Teisrud/NetworkKit/issues/150) — Authorized in sequence; predecessor acceptance required. See download plan for dependencies.
