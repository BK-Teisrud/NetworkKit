# Roadmap and backlog review — 2026-10-26

## Finding and evidence boundary

The active v1 delivery plan is decomposed, but the post-v1 roadmap is not yet executable. NK identifiers identify requirement domains/epics; I identifiers identify selected, bounded implementation slices. F3–F6 having only NK epics was consistent with their deliberately deferred scope, but did not provide enough planning work to move those phases forward. This review adds explicit preparation and decision/decomposition tasks rather than pretending unselected features are ready to build.

Reviewed inputs: the open/closed issue register, native parent/blocker relationships, all seven milestones, project fields/statuses/view filters, WORK_QUEUE.md, V1_SCOPE.md, the original adapted specification baseline, risk/environment plans and the I01–I16 evidence guides. This is a planning audit, not a fresh source-code security audit or a new reading of every original PDF subrequirement. Each later scope task must recheck its relevant original specification sections before accepting detailed requirements.

At the review baseline, F0/F1 are closed and I01–I16 are completed. Main commit `0cb06b61c62f830e9711eead35bfaec352e7bff0` has seven successful checks in [run 40357141211](https://github.com/BK-Teisrud/NetworkKit/actions/runs/40357141211). The retained I16 evidence records 210 tests / 24 suites on each of five selected runtime destinations. Counts do not make those destinations equivalent: native storage/redirect server probes are macOS-only, watchOS has documented transport-test limitations, and current simulators do not prove minimum-OS or physical-device behavior. No release readiness is inferred.

## Findings and corrections

| Finding | Assessment | Action |
| --- | --- | --- |
| F3–F6 have broad epics without bounded preparation tasks | Intentional deferral became an incomplete planning path | Add PLAN-F3–F6 with outputs, exclusions, decision criteria and decomposition requirements |
| F3 combines retry, auth, cache, monitoring and performance | Too broad to treat as one committed increment | Owner selected retry/robustness first; assess other modules independently and split milestones after sizing |
| Minimum-runtime access is unconfirmed, investigated late in I21 | High release risk discovered too late | Add PREP-01 before I17; retain actual execution and release blocking in I21/I22 |
| I22 is blocked by minimum-OS I21 | A scheduling preference was encoded as an unnecessary technical dependency | Both evidence tasks follow API/security review and environment preparation independently; both must pass for final acceptance |
| Broad core epics remain open after their recorded implementation children close | Correct caution, but no dedicated acceptance-reconciliation task | Add GATE-F2 before rehearsal to map selected requirements, evidence and explicit deferrals and close eligible epics |
| NK-13 is Blocked although its recorded blockers are closed | Stale status; its domain acceptance is still open | Return to Backlog; do not confuse epic status with executable work |
| I17 is Backlog with closed prerequisites | Its consolidation criteria need a sharper evidence boundary | Clarify the evidence ledger and residual gates, then mark Ready |
| Documentation still refers to initial slices/current historical prohibitions | Historical snapshots are useful, but current guidance must be clear | Update current roadmap/queue/management/register; preserve dated decisions and original seed data |
| Labels and project fields are not automatically synchronized | Drift remains possible | Verify both after every task/replan; do not claim a background synchronization service |

No milestone is renamed, split, closed, or assigned dates merely to make progress appear better. F2 remains coherent as the production/release-evidence gate. F3 may need separate deliveries; F4 may need separate foreground/background gates; F5 may separate base connection/reconnect; F6 may separate security and networking research. Those changes need selected requirements, feasibility and sizing first.

## Revised near-term sequence

1. [PREP-01 / #85](https://github.com/BK-Teisrud/NetworkKit/issues/85), Order 16.5: investigate environment access and device inventory now. It may finish with documented gaps; those gaps still block actual release evidence.
2. [I17 / #58](https://github.com/BK-Teisrud/NetworkKit/issues/58), Order 17: consolidate a requirement-to-test/evidence ledger and regressions. Assign remaining native trust, minimum-runtime and physical-device evidence to the correct later gates rather than claiming it already passed.
3. I18 / #59 and I19 / #60: API/DocC integration review, then security/privacy review, including a concrete account of native HTTPS/system-trust evidence and outstanding platform execution.
4. I20 / #61, I21 / #62 and I22 / #63: resource baseline, minimum-runtime evidence and newer physical-device evidence. The latter two require #60 and #85, not each other or resource measurements. The ascending Order remains the recommended solo sequence; useful evidence work can be resequenced with dependency review.
5. [GATE-F2 / #86](https://github.com/BK-Teisrud/NetworkKit/issues/86), Order 22.5: reconcile every selected v1 domain and close core epics only with actual evidence. It depends on #59–#63; it does not depend on rehearsal or publication. Keep #27 open while its I23 / #64 rehearsal is pending; reconcile that remaining governance criterion explicitly and close the epic only after rehearsal acceptance. This avoids an epic-closure/rehearsal cycle.
6. I23 / #64: non-publishing release rehearsal, additionally blocked by #86. REL-01 / #29 retains its core-epic/rehearsal gates and separate owner publication decision.

No v1 requirement was waived. Device models/OS builds and minimum-runtime access are still unverified; the owner's statement that devices have current updates is not minimum-version evidence. No purchase, device downgrade, trust-root installation or support-minimum change is implied.

## Detail required for later phases

| Phase / planning task | Decisions before implementation slices | Evidence needed to make the plan executable |
| --- | --- | --- |
| F3 / [PLAN-F3 #87](https://github.com/BK-Teisrud/NetworkKit/issues/87) | A small opt-in retry increment; replay eligibility, unsafe methods/idempotency, error/status rules, backoff/jitter/Retry-After, total budget, cancellation and auth/origin boundaries | Approved changed contract/ADR, requirement IDs, controlled-clock/negative tests, server/transport scenarios, compatibility impact and bounded issue dependency graph |
| F4 / [PLAN-F4 #88](https://github.com/BK-Teisrud/NetworkKit/issues/88) | Which upload/download/multipart/progress/resume cases are needed; file ownership, cleanup/privacy and foreground versus background scope | Per-platform feasibility, server requirements, actual host-app/entitlement responsibilities, device access and separate evidence/gates where needed |
| F5 / [PLAN-F5 #89](https://github.com/BK-Teisrud/NetworkKit/issues/89) | A real-time use case, base connection state machine, bounded buffering/backpressure, close/cancellation and optional reconnect/auth policy | Controllable server fixtures, deterministic state/failure tests, native runtime/device evidence, HTTP regression protection and API decision |
| F6 / [PLAN-F6 #90](https://github.com/BK-Teisrud/NetworkKit/issues/90) | Which security/networking need merits research; a separate hypothesis and stop/go criterion for each candidate | Official API/entitlement/platform checks, security/operational feasibility and owner adopt/defer/reject decision before production tasks |

The owner chose retry/robustness as the first post-core planning priority on 2026-10-26. This does not select cache, OAuth/refresh, Keychain, a status service, circuit breakers or every retry variant. Existing header injection, explicit app-managed URLSession stores and baseline resource checks must not be mistaken for those future products.

Future plans are not blanket blocked by publishing v1 or by every lower-numbered phase. Planning may run earlier when useful; extension implementation requires accepted core foundations and explicit approved scope. File transfers are not automatically a prerequisite for WebSocket work. Phase numbers express the present roadmap preference, not universal technical dependencies.

## Continuous plan ownership

The owner explicitly requested ongoing reprioritization/decomposition in this conversation. Apply the maintenance procedure in [PROJECT_MANAGEMENT.md](PROJECT_MANAGEMENT.md) before selecting each task, when evidence changes the plan and after acceptance. Record new gaps as bounded issues, update dependencies and the queue immediately, and state the reason for changed priorities. Ask the owner for product scope, material API/support/security deviations, spending or publication decisions; routine evidence-based planning maintenance is authorized.

This is an active-work maintenance commitment, not an unattended scheduler. GitHub remains the live state source. The repository queue file describes planned structure, not a second manually maintained completion counter. Future phases remain Backlog until their readiness criteria are met; planning issues do not turn an epic into completed functionality.
