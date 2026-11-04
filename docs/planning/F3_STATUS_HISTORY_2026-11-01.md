# Historical phase-status snapshots

These are preserved prior live summaries from accepted source 7ece7cf5c26220a8d6654035585a20cb6f98218b. They describe their original points in time, not current instructions, readiness, authorization or passing evidence. Current state is in [the I27 review](I27_RETRY_REVIEW_2026-11-01.md), [work queue](WORK_QUEUE.md) and authoritative GitHub Project. Original measured JSON/ADRs remain unchanged.


## From WORK_QUEUE.md


## I26 actual macOS 14 result — 2026-11-01

[Actual ARM64/macOS 14.8.9 retry execution](I26_MACOS14_RETRY_EXECUTION_2026-11-01.md) passes run 41294523457 on accepted main 660f8c099faccdd4215ad5e4bf1d082faaa3e403. Six native cases and four bounded resource workloads pass with exact source/payload custody. The one-off workflow is disabled and removed in the cleanup candidate. I26's selected verification is satisfied under documented limits; await cleanup PR/main acceptance before Done and I27. Physical Watch #132, unknown workload/production suitability and publication #29 remain mandatory; no new feature issue or broad resource refactor is justified.

## I26 minimum retry priority — 2026-11-01

PR #140/main run 41290108646 is accepted. [Fresh minimum retry evidence](I26_MINIMUM_RETRY_2026-11-01.md) passes 16 actual native parameter cases across iOS/iPadOS 17, tvOS 17 and watchOS 10. Temporarily prioritize existing #109 as P1: the standard macOS 14 route retires November 2, so prepare its main-only exact-source retry/resource execution before I27. Actual macOS 14 execution and candidate PR/main acceptance remain pending; no physical pass, release waiver, new feature issue or paid route is implied. Remove the temporary workflow after disposition/retirement under existing #109/#110.

## I26 native/resource execution — 2026-11-01

I25 #108 is accepted through PR #139/main run 41287067291. I26 #109 adds [native retry/resource evidence](NATIVE_RETRY_VERIFICATION.md): actual Mac URLSession contacts, TLS exclusion, public HTTPS ownership composition and bounded release measurements. Candidate CI and target-applicability review remain pending; no new minimum/physical pass or publication acceptance is inferred. Existing #109/#110 and #132/#29 retain their distinct gates; no new feature issue or broad refactor is justified.

## I25 execution — 2026-11-01

I24 #107 is accepted through PR #138/main run 41250907636 (223 Mac tests, four 220-test simulator runs, 19 helpers). I25 #108 integrates explicit per-call retry inside one admitted operation/deadline; see [integration evidence](RETRY_INTEGRATION.md). I26/I27 remain dependent native/resource/API review tasks. No extra issue, dependency, broad refactor or release scope is justified by this change. This supersedes earlier I24-active/no-loop status below; required I25 PR/main acceptance is pending.

## Current F3 execution — 2026-10-31

Planning #87/#106 is accepted through PR #111/main `25e0d52b8316251bb6592d075caead9b05ed9edd`, verified run 41248255517. The owner explicitly authorized implementation of I24–I27 under ADR-0014; START-F3 #137 is completed. I24 #107 implements pure eligibility/delay decisions; I25–I27 remain dependent work. No retry transport loop, publication or other extension is delivered by I24. This status supersedes earlier no-code holds below. Existing four slices remain sufficient; no additional feature issue or broad refactor is justified.

## Complete retry contract approval — 2026-10-31

The owner approves the complete [ADR-0014 contract](../decisions/ADR-0014-opt-in-retry-proposal.md) and expressly withholds code. #87/#106 await planning PR/main acceptance; [START-F3 #137](https://github.com/BK-Teisrud/NetworkKit/issues/137) separately blocks selected I24–I27 (#107–#110). Existing F3 is now “F3 – Bounded read retries”; open unselected domain catalogs #12/#14/#15/#19/#24 stay outside this delivery milestone. No product code, default behavior, dependency, release/version/date or publication authorization. #132/#29 and accepted F2 remain unchanged.




## Earlier work-queue closeout/next-step text

## Accepted F2 closeout — 2026-10-31

F2 is CLOSED after PR #135/main `cc654ab5faadc0fc7fe00d7ad238b2e3ed5a997c`, [run 41242130528](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41242130528), with full-log verification of 218 Mac tests, four 215 simulator suites, 19 helpers and four manual-host provenance checks without failure/restart markers. #64/#27 are Done; direct item lists and GraphQL verify no open F2 issues/PRs. [Closeout evidence](F2_CLOSEOUT_2026-10-31.md) records the milestone summary-counter disagreement and actual verified states.

Original candidate evidence files retain their submission-time pending flags and exact executed SDK/platform/failure limits. The owner resource approval is F2-only. #132 physical Watch and #29 actual workload/device-memory/security/publication decisions remain mandatory in their separate milestone, with support unchanged. No release/tag, production suitability or F3 implementation is authorized.

PLAN-F3 #87/#106 are In Review; the complete contract is owner-approved, but START-F3 #137 withholds implementation. I24–I27 are Blocked. Planning PR/main acceptance and a separate explicit code-start instruction remain required. Closed F2 is not publication or extension authorization.

## Next planning and publication lanes

1. #87 is Ready for planning only. Review bounded retry/draft PR #111 against accepted F2, answer contract questions and prepare its delivery backlog. Obtain explicit scope/start approval before F3 code.
2. #132 stays Blocked before #29 publication; actual physical Watch and owner workload/device-memory/security/publication decisions remain mandatory. Do not reopen F2 or mark Watch passed merely to publish.
3. Preserve closed-phase evidence and historical failure limits. No new milestone, dependency, paid service, support change or production feature is selected by closeout.

Stop whenever a GitHub run is pending and await the owner's instruction to continue. Do not poll CI or continue independent work across that stop, as reconfirmed on 2026-10-31. Conversation stays Norwegian; repository and project content stay English.



## From BACKLOG.md


## I26 actual macOS 14 result — 2026-11-01

[Actual ARM64/macOS 14.8.9 retry execution](I26_MACOS14_RETRY_EXECUTION_2026-11-01.md) passes run 41294523457 on accepted main 660f8c099faccdd4215ad5e4bf1d082faaa3e403. Six native cases and four bounded resource workloads pass with exact source/payload custody. The one-off workflow is disabled and removed in the cleanup candidate. I26's selected verification is satisfied under documented limits; await cleanup PR/main acceptance before Done and I27. Physical Watch #132, unknown workload/production suitability and publication #29 remain mandatory; no new feature issue or broad resource refactor is justified.

## I26 minimum retry priority — 2026-11-01

PR #140/main run 41290108646 is accepted. [Fresh minimum retry evidence](I26_MINIMUM_RETRY_2026-11-01.md) passes 16 actual native parameter cases across iOS/iPadOS 17, tvOS 17 and watchOS 10. Temporarily prioritize existing #109 as P1: the standard macOS 14 route retires November 2, so prepare its main-only exact-source retry/resource execution before I27. Actual macOS 14 execution and candidate PR/main acceptance remain pending; no physical pass, release waiver, new feature issue or paid route is implied. Remove the temporary workflow after disposition/retirement under existing #109/#110.

## I26 native/resource execution — 2026-11-01

I25 #108 is accepted through PR #139/main run 41287067291. I26 #109 adds [native retry/resource evidence](NATIVE_RETRY_VERIFICATION.md): actual Mac URLSession contacts, TLS exclusion, public HTTPS ownership composition and bounded release measurements. Candidate CI and target-applicability review remain pending; no new minimum/physical pass or publication acceptance is inferred. Existing #109/#110 and #132/#29 retain their distinct gates; no new feature issue or broad refactor is justified.

## I25 execution — 2026-11-01

I24 #107 is accepted through PR #138/main run 41250907636 (223 Mac tests, four 220-test simulator runs, 19 helpers). I25 #108 integrates explicit per-call retry inside one admitted operation/deadline; see [integration evidence](RETRY_INTEGRATION.md). I26/I27 remain dependent native/resource/API review tasks. No extra issue, dependency, broad refactor or release scope is justified by this change. This supersedes earlier I24-active/no-loop status below; required I25 PR/main acceptance is pending.

## Current F3 execution — 2026-10-31

Planning #87/#106 is accepted through PR #111/main `25e0d52b8316251bb6592d075caead9b05ed9edd`, verified run 41248255517. The owner explicitly authorized implementation of I24–I27 under ADR-0014; START-F3 #137 is completed. I24 #107 implements pure eligibility/delay decisions; I25–I27 remain dependent work. No retry transport loop, publication or other extension is delivered by I24. This status supersedes earlier no-code holds below. Existing four slices remain sufficient; no additional feature issue or broad refactor is justified.

## Complete retry contract approval — 2026-10-31

The owner approves the complete [ADR-0014 contract](../decisions/ADR-0014-opt-in-retry-proposal.md) and expressly withholds code. #87/#106 await planning PR/main acceptance; [START-F3 #137](https://github.com/BK-Teisrud/NetworkKit/issues/137) separately blocks selected I24–I27 (#107–#110). Existing F3 is now “F3 – Bounded read retries”; open unselected domain catalogs #12/#14/#15/#19/#24 stay outside this delivery milestone. No product code, default behavior, dependency, release/version/date or publication authorization. #132/#29 and accepted F2 remain unchanged.




## From ROADMAP.md


## I26 actual macOS 14 result — 2026-11-01

[Actual ARM64/macOS 14.8.9 retry execution](I26_MACOS14_RETRY_EXECUTION_2026-11-01.md) passes run 41294523457 on accepted main 660f8c099faccdd4215ad5e4bf1d082faaa3e403. Six native cases and four bounded resource workloads pass with exact source/payload custody. The one-off workflow is disabled and removed in the cleanup candidate. I26's selected verification is satisfied under documented limits; await cleanup PR/main acceptance before Done and I27. Physical Watch #132, unknown workload/production suitability and publication #29 remain mandatory; no new feature issue or broad resource refactor is justified.

## I26 minimum retry priority — 2026-11-01

PR #140/main run 41290108646 is accepted. [Fresh minimum retry evidence](I26_MINIMUM_RETRY_2026-11-01.md) passes 16 actual native parameter cases across iOS/iPadOS 17, tvOS 17 and watchOS 10. Temporarily prioritize existing #109 as P1: the standard macOS 14 route retires November 2, so prepare its main-only exact-source retry/resource execution before I27. Actual macOS 14 execution and candidate PR/main acceptance remain pending; no physical pass, release waiver, new feature issue or paid route is implied. Remove the temporary workflow after disposition/retirement under existing #109/#110.

## I26 native/resource execution — 2026-11-01

I25 #108 is accepted through PR #139/main run 41287067291. I26 #109 adds [native retry/resource evidence](NATIVE_RETRY_VERIFICATION.md): actual Mac URLSession contacts, TLS exclusion, public HTTPS ownership composition and bounded release measurements. Candidate CI and target-applicability review remain pending; no new minimum/physical pass or publication acceptance is inferred. Existing #109/#110 and #132/#29 retain their distinct gates; no new feature issue or broad refactor is justified.

## I25 execution — 2026-11-01

I24 #107 is accepted through PR #138/main run 41250907636 (223 Mac tests, four 220-test simulator runs, 19 helpers). I25 #108 integrates explicit per-call retry inside one admitted operation/deadline; see [integration evidence](RETRY_INTEGRATION.md). I26/I27 remain dependent native/resource/API review tasks. No extra issue, dependency, broad refactor or release scope is justified by this change. This supersedes earlier I24-active/no-loop status below; required I25 PR/main acceptance is pending.

## Current F3 execution — 2026-10-31

Planning #87/#106 is accepted through PR #111/main `25e0d52b8316251bb6592d075caead9b05ed9edd`, verified run 41248255517. The owner explicitly authorized implementation of I24–I27 under ADR-0014; START-F3 #137 is completed. I24 #107 implements pure eligibility/delay decisions; I25–I27 remain dependent work. No retry transport loop, publication or other extension is delivered by I24. This status supersedes earlier no-code holds below. Existing four slices remain sufficient; no additional feature issue or broad refactor is justified.

## Complete retry contract approval — 2026-10-31

The owner approves the complete [ADR-0014 contract](../decisions/ADR-0014-opt-in-retry-proposal.md) and expressly withholds code. #87/#106 await planning PR/main acceptance; [START-F3 #137](https://github.com/BK-Teisrud/NetworkKit/issues/137) separately blocks selected I24–I27 (#107–#110). Existing F3 is now “F3 – Bounded read retries”; open unselected domain catalogs #12/#14/#15/#19/#24 stay outside this delivery milestone. No product code, default behavior, dependency, release/version/date or publication authorization. #132/#29 and accepted F2 remain unchanged.


Current phase status, 2026-10-31: F2 is CLOSED through PR #135/main 41242130528; #64/#27 are Done and open item connections are empty. [Final closeout](F2_CLOSEOUT_2026-10-31.md) records accepted evidence and counter discrepancy. #87 is Ready for retry planning only; physical Watch #132 and publication/workload/security #29 remain separate blockers. No F3 code or release authorization. Dated progress below preserves history.


Current rehearsal, 2026-10-31: #86 and nine selected-core epics are Done through PR #134/main 41238957032. [Formal rehearsal](RELEASE_REHEARSAL_2026-10-31.md) is executed and awaits its PR/main acceptance; only #64/#27 remain open in F2. #132/#29 remain a separate mandatory publication lane. No release/tag, production acceptance or F3 implementation is authorized. Earlier dated progress retains its original context.


Current reconciliation, 2026-10-31: #62 and revised #63 are Done. [GATE-F2 review](F2_REVIEW.md) reconciles the 79 stable core IDs and recorded owner F2-only resource disposition; its PR/main acceptance precedes eligible core epic closures. #27 remains open for formal #64, then F2 closure. #132/#29 remain separate publication blockers; #87/draft PR #111 is planning, not F3 implementation authorization. Dated progress notes below preserve their original state.


Current owner decision, 2026-10-31: [ADR-0013](../decisions/ADR-0013-watch-publication-gate.md) moves only missing physical Watch verification to #132/#29 in the separate “v1.0 – Publication gate” milestone. watchOS 10 support is unchanged. F2 remains open for revised #63, #86 and formal #64/#27; publication and F3 implementation remain unauthorized. [Applicability matrix](F2_PHYSICAL_APPLICABILITY.md) and [work queue](WORK_QUEUE.md) supersede dated access notes below.


No deadlines are set. Phases are gates, not calendar promises. The owner selected HTTP core first: F0 → F1 → F2 completes non-publishing core hardening/rehearsal; a separate publication gate precedes the first stable release. F3–F6 are optional later deliveries, outside v1.0. Repository/package: NetworkKit; product/module: NetworkKit, with one library module. See [v1 scope](V1_SCOPE.md) and [ADR-0003](../decisions/ADR-0003-v1-scope-and-naming.md).

Current review: [TLS-01 native macOS rejection](NATIVE_TLS_REJECTION.md), a bounded P1 regression at Order 20.75 under #25. Preparation PR #103 is accepted through main run 40550211780; #62/#63 execution remains blocked by readiness/access. TLS-01 supplies local native negative evidence without selecting a new TLS product feature. F2 remains open for complete native/platform/resource and explicit owner-risk gates; no new milestone or support/tool change is selected.



## Earlier roadmap F2/F3 descriptions

## F2 – Production hardening and v1 gate

[Preliminary F2 requirement reconciliation](F2_REVIEW.md) maps 79 source bullets across the ten core epics to accepted scope, evidence and explicit deferrals. TLS-01 #104 is accepted through main run 40556606300. The connected iPhone builds/signs successfully, but tool-hosted device testing is unsupported; PREP-02 #113 adds the required app-host route before #63 execution. This preparation closes no phase/epic; #62/#63 actual target/HTTPS/resource evidence still precedes #86, #64 and the separate #29 release decision.

Current review, 2026-10-27: I20, RES-01 and preparation PR #103 are accepted; main run 40550211780 confirms the preparation baseline. TLS-01 / #104 is a selected P1 regression at Order 20.75, adding independently executable native macOS untrusted-certificate rejection. The original fixture/opaque iOS incident uncertainties remain recorded. #62/#63 execution remains Blocked by actual minimum/physical/controlled-HTTPS readiness. #86 requires #104 plus native/resource evidence, with explicit owner disposition before #29. No new milestone or product feature is selected.

Privacy/logging, cancellation, required authentication boundaries under DEC-04/06, security review, DocC, and a documented release gate. Release v1 only after all accepted core criteria are met. PREP-01 / #85 investigates environment access early; GATE-F2 / #86 reconciles domain requirements and evidence before I23 rehearsal. Minimum-runtime and newer-device execution are independent evidence branches after API/security review, and both must pass.

## F3 – Resilience and extensions

Deferred beyond v1. The owner selected retry/robustness as the first post-core planning priority on 2026-10-26. PLAN-F3 / #87 must select a small opt-in increment and approve its changed contract before implementation. Cache/authentication/monitoring/performance remain separate candidates; split delivery milestones if sizing warrants it.
