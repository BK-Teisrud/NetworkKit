# Risk register

## Current F4 risk boundaries — 2026-11-04

The owner selected a combined I31/I32 candidate and delegated the modern OS baseline (ADR-0017): iOS/iPadOS18, macOS15, watchOS11, tvOS18. The retired macOS14 route is not a current support requirement and is not revived. New native/family/consumer evidence remains source-specific and must be verified; the historical dispositions below do not establish current F4 acceptance.

Retain the output-only file-size limit, possible Foundation-owned unexposed partials/transient disk use, filesystem/crash cleanup failures, aggregate resource-observation limits and unknown actual app workloads. Store/cache behavior follows compatible Foundation profiles, not a cache-hit promise. Current candidate physical/patch/architecture coverage must be stated explicitly. I32 requires a concrete owner technical-risk disposition; #29/#132 remain separate publication gates. PDF aggregate export is currently deferred by the owner; inspect the actual new archive/manifest rather than reusing the old empty-manifest report.

Useful independent work may proceed while CI runs under the new owner policy, but predecessor main and candidate checks still gate merge. Do not manufacture a pass or close issues from progress alone.


## Complete retry contract approval — 2026-10-31

The owner approves the complete [ADR-0014 contract](../decisions/ADR-0014-opt-in-retry-proposal.md) and expressly withholds code. #87/#106 await planning PR/main acceptance; [START-F3 #137](https://github.com/BK-Teisrud/NetworkKit/issues/137) separately blocks selected I24–I27 (#107–#110). Existing F3 is now “F3 – Bounded read retries”; open unselected domain catalogs #12/#14/#15/#19/#24 stay outside this delivery milestone. No product code, default behavior, dependency, release/version/date or publication authorization. #132/#29 and accepted F2 remain unchanged.


GATE-F2 disposition, 2026-10-31: the owner expressly accepts proceeding **only with the non-publishing F2 rehearsal** under the recorded runtime retention, call-rate/budget/payload and finite-memory-observation limitations. #86 reconciles accepted non-Watch/minimum evidence and the ADR-0013 Watch deferral. This is no production-fit or publication acceptance: #29 retains workload/security approval, #132 physical Watch, and #64 actual clean-consumer/archive rehearsal. No further product defect, generic refactor or extra issue is established by this review.


Approved phase update, 2026-10-31: [ADR-0013](../decisions/ADR-0013-watch-publication-gate.md) moves only physical Watch evidence to mandatory #132/#29 publication tracking. It does not waive product support, remaining non-Watch evidence or owner resource/security risk decisions. Non-Watch transition evidence is accepted through PR #131/main 41234106849; the [applicability matrix](F2_PHYSICAL_APPLICABILITY.md) awaits its scope-review PR/main. Historical claims below remain dated observations.


Current update, 2026-10-31: #62 is closed/project Done after PR #129/main 41221803657. Mac actual transitions are accepted through PR #130/main 41231362170. The new [TV transition report](evidence/F2_TV_MANUAL_TRANSITIONS_2026-10-31.json) verifies actual outage/recovery/post-budget observations, including later Wi-Fi fallback; candidate acceptance remains pending. Watch Developer Mode is enabled but the [developer-image mount blocker](evidence/F2_WATCH_MOUNT_DIAGNOSIS_2026-10-31.json) prevents physical tests. #63 applicability/resources, #86/#64 and #29 owner/publication decisions remain. The dated notes below retain historical limits and do not reopen accepted #62 or Mac/iPhone/iPad work.


## Current F2 execution update — 2026-10-31

NET-04 #126 is accepted through PR #127/main 41199040706. Candidate iPad TLS diagnostics and physical TV regression/native/resource evidence advance existing #62/#63; earlier failed observations remain recorded. Watch registration, six scoped Watch/TV profiles and signed generic hosts are prepared, but Watch's development tunnel/readiness remains unresolved despite owner confirmation. No new certificate, support minimum, trust exception or paid service was introduced.

The aggregate privacy-report placement control now succeeds in a disposable unsigned archive; it does not prove full binary API analysis or actual consumer data practices. Actual ARM64 macOS 14.8.9 HTTPS run 41204068268 passed all ten cases with exact source and trust checks. Its permanent sanitized record is preserved and the one-off workflow removed; no exact-14.0/Intel/full-suite guarantee is inferred. The manual app is verification-only. Candidate iPad/iPhone runs now establish actual observed path loss, -1009, concurrent recovery and post-budget samples on those devices; local healthy-Mac controls and generic compilation remain narrower evidence. Mac outage, deferred TV transitions and Watch runtime access remain open. ENV-06, remaining resources, #86 reconciliation, formal #64 and #29 owner risk/publication decisions remain open. Existing owners cover these needs; no duplicate issue, speculative SDK refactor or extra milestone is justified.


Owner of initial open risks: @BK-Teisrud. Review weekly during triage and at phase gates.

| ID | Risk / likelihood / impact | Mitigation and trigger | Gate |
| --- | --- | --- | --- |
| R1 | Overengineering / high / high | ADR-0003/V1_SCOPE defines the HTTP core and one library module; new modules require a need and decision. Unjustified scope growth → stop and reassess. | F0 |
| R2 | OS differences / high / high | ADR-0004/PLATFORM_MATRIX sets minimums/tools. Verify symbols, guards, runtime/device behavior; simulator builds alone are insufficient. | F0–F4 |
| R3 | Duplicate retry side effects / medium / high | No unsafe retry by default; require idempotency and bounded attempts. | F3 |
| R4 | Credentials in logs/redirects/cache / medium / critical | Negative redaction/isolation/redirect tests and private security review. | F2 |
| R5 | Refresh storms/deadlocks / medium / high | Single-flight and concurrency/cancellation tests before an authentication module. | F3 |
| R6 | Stale/leaked cache / medium / high | HTTP semantics, account isolation, deletion, explicit offline policy. | F3 |
| R7 | Unsupported background promises / high / high | Entitlements, host-app responsibilities, physical evidence per platform. | F4 |
| R8 | Solo-maintainer review bottleneck / high / medium | PR audit trail, low WIP, team profile once a reviewer exists. | All |
| R9 | Use/contributions without rights / medium / high | DEC-03: Teisrud Development AS, proprietary policy. LICENSE/ADR-0002 clarify permission and GitHub exceptions. Written agreements before external content contributions/distribution. | F0 and release |
| R10 | False confidence from passing CI / medium / high | No dummy checks; real matrix and release evidence. | F1 |
| R11 | Changing GitHub rules/tools / medium / medium | Quarterly settings review, Actions limits, least privilege. | All |

Accept residual risks in the relevant issue, with an ADR for lasting deviations. Critical security findings block release until fixed or the affected scope is explicitly removed with rationale.

## Concrete outstanding release work

R2 current disposition (2026-10-31): four minimum simulator root regressions are accepted (215 each), and native ARM64 macOS 14.8.9 consumer/reuse/cancellation/resource observations are recorded in MACOS14_EXECUTION_ROUTE_2026-10-29.md. These bounded results do not complete I21 / #62: full applicable minimum/native scenarios, exact macOS 14.0 and other recorded limits remain. Physical-family/transition evidence remains under #63. Earlier missing-access statements below are dated history, not the current inventory.

R9: No contact address exists. Do not offer private licensing/contribution processes until an appropriate channel is established. This does not block separately authorized internal implementation.

R11: Admins can change rulesets even without main/update/deletion bypasses. No technical protection against the account owner is guaranteed. The owner confirms 2FA; no independent account audit was performed.

R10: I17 / #58 consolidates an evidence ledger; GATE-F2 / #86 reconciles all selected v1 domain criteria before rehearsal. Native wire, scripted transport, minimum-runtime and physical-device evidence must remain distinct.

Planning risk: broad deferred domains can hide missing contracts or create premature commitments. PLAN-F3–F6 / #87–#90 require use cases, explicit exclusions, feasibility, approved contracts and bounded issues. Retry is the first post-core planning priority; other F3 candidates are not implicitly selected.

PREP-01 assessment, 2026-10-26: older runtimes are absent locally and external access is unknown; physical model/OS/build inventory is also unknown. See [environment readiness](ENVIRONMENT_READINESS.md) for evidence, owner actions and native-trust/device scenarios. #62/#63 retain these gaps; preparation does not close them. Xcode development-host requirements and macOS 14 execution must be handled separately.

R10 update, 2026-10-26: I18 main run 40382689252 hit the native borrowed-cache test limit and restarted. #95 is P0 and blocks #59/#60 acceptance. See [storage probe follow-up](STORAGE_TIMEOUT_FOLLOWUP.md); no blind rerun or increased suite bound substitutes for phase/liveness evidence.

R10 follow-up acceptance: PR #96 and main run 40390885712 completed without timeout/restart; bounded fixture gaps are addressed. Original internal stall cause remains unproven and monitored under #23/#86. [QA-01](QUALITY_REVIEW_2026-10-26.md) improves actual production-path test coverage and documentation drift controls before I19, without expanding v1.

I19 review: see the [threat model](../security/THREAT_MODEL.md) and [security/privacy dispositions](SECURITY_PRIVACY_REVIEW.md). Controlled HTTPS access is unavailable/unknown, so native system-trust evidence remains open in #62/#63. #61 owns buffered-resource assessment; #64 owns aggregate privacy/archive verification. #86/#29 require explicit owner residual-risk acceptance; none is inferred from the source review.

I20 finding, 2026-10-26: repeated release calls show continuing RSS growth relative to a direct URLSession control. The [baseline and limits](RESOURCE_BASELINE.md) preserve raw results without attributing a leak from RSS alone. RES-01 / #100 is P1 / Order 20.5, blocks #86 and follows #61 acceptance. No stable memory/leak guarantee is made; provisional workload advice does not enforce response size or cap app memory. #62/#63 must assess actual target constraints.

RES-01 attribution: [local controls and disposition](REPEATED_CALL_MEMORY.md) identify expiry-dependent runtime sleep-helper/dispatch retention, not a proven retained NetworkKit operation graph. No production timer/clock rewrite is justified. Rate, timeout and target memory constraints remain material; #62/#63 require actual target evidence and #86/#29 require explicit owner acceptance/mitigation. A falling live heap is not a zero-RSS or leak-free guarantee.

Environment refresh, 2026-10-27: [local device records](ENVIRONMENT_ACCESS_2026-10-27.md) supply model/OS information for iPhone/iPad/Watch, but connection/services and actual compatibility are unverified; TV remains unknown. Minimum runtimes/macOS 14 and controlled HTTPS remain missing. OS newer than the SDK alone is not proof of incompatibility. Owner deferred device connection; #62/#63 remain Blocked. No support/tool change or release-risk acceptance is inferred.

## TLS-01 native negative evidence

The [macOS rejection regression](NATIVE_TLS_REJECTION.md) exercises typed/raw public calls through real system-trust handling against a disposable untrusted certificate with a matching loopback SAN. Local results are certificate-specific; no trust root or verification bypass is installed. This is owned-session macOS evidence only. #62/#63 still require trusted success, independent hostname mismatch and actual minimum/physical environments; #86/#29 retain resource/risk/release gates. #104 acceptance requires its own PR/main checks.

## NET-03 verification custody and resource limits — 2026-10-31

The new in-process loopback fixture advances existing #62/#63 ENV claims without creating a production transport or a shipped module. Current candidate evidence is tracked in [NET03_NATIVE_LOOPBACK.md](NET03_NATIVE_LOOPBACK.md). Local success is not accepted-main, minimum or physical success. Previous temporary device/simulator logs were unavailable after resumption; those candidate outcomes remain unverified. Preserve sanitized source hashes, summaries, failures and cleanup in checked-in evidence before promoting claims; raw device/account logs stay private.

The macOS 14 100-cycle NetworkKit RSS observation remained above warm baseline and higher than its direct Foundation control after 12 seconds. Local NET-03 RSS also includes its in-process server, test framework and allocator. Neither measurement identifies retained SDK objects or proves a universal bound. Continue bounded target/workload observations and explicit owner risk disposition under #62/#63/#86/#29; do not hide the delta, infer release acceptance or introduce a speculative scheduler/framework rewrite. No new generic risk issue is needed because the existing gates already own these requirements.

Owner workload clarification, 2026-10-31: the first consuming app's use case, typical response size and required concurrency are unknown. Preserve measured synthetic workloads as observations only; do not convert them into app-specific suitability or residual-risk acceptance. Existing #62/#63/#86/#29 own the assessment; no arbitrary production limit, new generic issue or release permission is inferred. Continue executable verification and consumer-rehearsal preparation while this uncertainty remains explicit.

## Retry planning risks — 2026-10-31

Proposed ADR-0014 does not change the delivered no-library-retry default. Replay semantics, stale one-use signatures, non-shortened Retry-After, the one total budget, cancellation/shutdown boundaries, actual attempt-count schema and waiting-related resource retention are explicit #106–#110 contracts/evidence. App-managed Foundation storage is not frozen wire state. No raw reason/history logging or broad plugin/timer framework is selected. The current owner choices select planning boundaries, not production use or code start. Existing #132/#29 publication gates and F2-only resource disposition remain unchanged.
