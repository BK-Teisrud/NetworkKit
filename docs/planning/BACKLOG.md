# Requirements traceability and backlog

## Maintenance prerequisite — 2026-11-04

The owner requested completing the [architecture maintenance plan](ARCHITECTURE_MAINTENANCE_2026-11-04.md) before further I31 work. After PR #157 checkpoint/main acceptance, execute QA-02 / #158 → QA-03 / #159 → QA-04 / #160 → QA-05 / #161, then resume I31 #149 and I32 #150. I31 is now Blocked by this maintenance chain; existing native evidence gaps remain open. This update is planning only under a narrow CI-stop exception, with no code, merge or new CI run. F4 scope and #29/#132 publication barriers are unchanged.


## Current delivery — 2026-11-01

F3 is formally closed: I27 #110 is Done after final PR #144/main b4511c5efe9a349a9f91eb0448974f1bf49b8d3f/run 41302196774; all seven checks passed. [F3 closeout](F3_CLOSEOUT_2026-11-01.md) preserves its bounded technical acceptance and source-specific evidence.

F4 planning/I28, I29 and I30 #148 are Done after accepted PR #156/main run 41333096996. I31 #149 is paused/Blocked for the maintenance prerequisites; its checkpoint evidence is: [native Mac checkpoint](I31_NATIVE_DOWNLOAD_2026-11-04.md) executes real URLSession file transfers, counted redirects/lifecycle/known-path cleanup and finite file/RSS observations. [Minimum native execution](I31_MINIMUM_DOWNLOAD_2026-11-04.md) now passes 24 cases across four existing simulators. FileTimestamp/C617.1 metadata is corrected for fstat; validation/PR/main and remaining trusted HTTPS/auth/storage/other-current/physical/macOS14 evidence are outstanding. I32 #150 stays predecessor-blocked. No new signing/device installation, purchase or publication is authorized.

#14 advanced resilience remains Backlog; #89/#90 remain independent planning. #29 actual app/workload/security/publication and physical Watch #132 remain mandatory separate barriers. No new milestone/date or publication authorization follows.

## Original requirements allocation

Original planning baseline: 20 domain epics, seven decision issues, and three governance/release issues. The table below preserves the original domain classification/phase allocation, not live completion. I01–I16 are delivered; I01–I10 implement the initial HTTP slice; [F1 review](F1_REVIEW.md) accounts for delivered work and open domain epics continuing in F2. See the [GitHub register](GITHUB_REGISTER.md) for live links.

| ID | Requirement / task | Classification | Phase |
| --- | --- | --- | --- |
| DEC-01 | Accepted: Minimum OS and Swift/Xcode/SDK matrix (ADR-0004) | governance | F0 |
| DEC-02 | Accepted: V1 scope and package/product/module naming (ADR-0003) | governance | F0 |
| DEC-03 | Accepted: Rights holder and proprietary policy (ADR-0002) | governance | F0 |
| DEC-04 | Accepted: HTTP/response/error contract (ADR-0005) | governance | F0 |
| DEC-05 | Accepted: Session ownership, 30/60 limits, concurrency, shutdown (ADR-0006) | governance | F0 |
| DEC-06 | Accepted: Security/authentication/storage/network policy (ADR-0007) | governance | F0 |
| DEC-07 | Accepted: Four PR platforms, official tools, standard runners, no paid add-ons (ADR-0008) | governance | F0 |
| NK-01 | HTTP and requests | core | F1 |
| NK-02 | Endpoints and URL construction | core | F1 |
| NK-03 | Responses and data handling | core | F1 |
| NK-04 | Error handling | core | F1 |
| NK-05 | Authentication | extension | F3 |
| NK-06 | Security and TLS | extension | F6 |
| NK-07 | Retries and resilience | extension | F3 |
| NK-08 | Caching | extension | F3 |
| NK-09 | File transfers | extension | F4 |
| NK-10 | WebSocket and real-time communication | extension | F5 |
| NK-11 | TCP, UDP, and local networking | research | F6 |
| NK-12 | Network status | extension | F3 |
| NK-13 | Logging and observability | core | F2 |
| NK-14 | Concurrency and lifecycle | core | F2 |
| NK-15 | Configuration | core | F1 |
| NK-16 | Testing and mocking | core | F1 |
| NK-17 | Performance and optimization | extension | F3 |
| NK-18 | Privacy and data protection | core | F2 |
| NK-19 | Apple platform integration | extension | F4 |
| NK-20 | Developer experience and API design | core | F2 |
| GATE-00 | F0 planning accepted; implementation unauthorized (ADR-0009) | governance | F0 |
| REL-01 | Verify the first stable core release | governance | F2 |
| OPS-01 | Verify GitHub setup and the future team transition | governance | F0 |

## Approved scope

[V1_SCOPE.md](V1_SCOPE.md) defines included/deferred scope across all 20 domains. Keep epics open until selected work is delivered. ADR-0005 defines the HTTP contract; ADR-0006 the lifecycle; ADR-0007 the security/network policy. Future feature slices require concrete verification before Ready; ADR-0014 governs only the selected bounded retry increment.

## Before development

Decompose feature families into testable issues with contracts, test plans, and specification references. Explicitly identify exclusions. Use native dependencies where available and body links regardless; links do not enforce merges. Planning does not mean delivery.

## Concrete implementation queue

I01–I27 are selected native subissues with criteria and dependencies; see [WORK_QUEUE.md](WORK_QUEUE.md). START-00 / #41 was closed after the owner instruction on 2026-10-20 (ADR-0012). Core I01–I23 and retry I24–I26 are accepted; I27 remains the current review gate. Future tasks require selected scope, authorization, resolved dependencies and Ready checks. Decomposition itself did not authorize code. planning.json is the original seed rather than live status; work-queue.json describes the concrete queue.

## Rolling planning review

The [2026-10-26 audit](PLAN_REVIEW_2026-10-26.md) adds PREP-01 / #85, GATE-F2 / #86 and PLAN-F3–F6 / #87–#90. The owner selected retry/robustness as the first post-core planning priority. Future NK domains remain deferred; concrete extension implementation slices require selected contracts and a new scope decision. Follow PROJECT_MANAGEMENT.md at every task transition, not only weekly.

## Historical selection refresh before complete approval — 2026-10-31

F2 is closed; #87/#106 review Proposed [ADR-0014](../decisions/ADR-0014-opt-in-retry-proposal.md) and the [bounded retry plan](RETRY_INCREMENT_PLAN.md). Existing #107–#110 remain Backlog without I identifiers or implementation authorization. Owner selections: general safe app-data reads, per-call bodyless GET/HEAD one retry for exact allowlist, 250–500 ms jitter/30-second cap, auth preparation once and diagnostic attempt count only. Full contract/code start remain separate decisions. Preserve all core/host/native rows and #132/#29 publication gates; no duplicate task or new milestone.
