# GitHub register

> Historical planning/setup record from 2026-10-19. Implementation was subsequently authorized on 2026-10-20 in [ADR-0012](../decisions/ADR-0012-implementation-start.md). The package baseline is documented in [PACKAGE_BASELINE.md](PACKAGE_BASELINE.md). Earlier no-code statements describe that earlier stage.

Created 2026-10-19. This register records the initial setup and subsequent preparation; live status is in GitHub. Subsequent delivery status belongs to [the work queue](WORK_QUEUE.md), not this historical setup register.

- [Repository](https://github.com/BK-Teisrud/NetworkKit)
- [Project: NetworkKit Roadmap](https://github.com/users/BK-Teisrud/projects/6) (private; owner access required)
- [Milestones](https://github.com/BK-Teisrud/NetworkKit/milestones)
- [Active rulesets](https://github.com/BK-Teisrud/NetworkKit/rules)

## Issues

| Stable ID | GitHub issue |
| --- | --- |
| DEC-01 | [#1](https://github.com/BK-Teisrud/NetworkKit/issues/1) |
| DEC-02 | [#2](https://github.com/BK-Teisrud/NetworkKit/issues/2) |
| DEC-03 | [#3](https://github.com/BK-Teisrud/NetworkKit/issues/3) |
| DEC-04 | [#4](https://github.com/BK-Teisrud/NetworkKit/issues/4) |
| DEC-05 | [#5](https://github.com/BK-Teisrud/NetworkKit/issues/5) |
| DEC-06 | [#6](https://github.com/BK-Teisrud/NetworkKit/issues/6) |
| DEC-07 | [#7](https://github.com/BK-Teisrud/NetworkKit/issues/7) |
| NK-01 | [#8](https://github.com/BK-Teisrud/NetworkKit/issues/8) |
| NK-02 | [#9](https://github.com/BK-Teisrud/NetworkKit/issues/9) |
| NK-03 | [#10](https://github.com/BK-Teisrud/NetworkKit/issues/10) |
| NK-04 | [#11](https://github.com/BK-Teisrud/NetworkKit/issues/11) |
| NK-05 | [#12](https://github.com/BK-Teisrud/NetworkKit/issues/12) |
| NK-06 | [#13](https://github.com/BK-Teisrud/NetworkKit/issues/13) |
| NK-07 | [#14](https://github.com/BK-Teisrud/NetworkKit/issues/14) |
| NK-08 | [#15](https://github.com/BK-Teisrud/NetworkKit/issues/15) |
| NK-09 | [#16](https://github.com/BK-Teisrud/NetworkKit/issues/16) |
| NK-10 | [#17](https://github.com/BK-Teisrud/NetworkKit/issues/17) |
| NK-11 | [#18](https://github.com/BK-Teisrud/NetworkKit/issues/18) |
| NK-12 | [#19](https://github.com/BK-Teisrud/NetworkKit/issues/19) |
| NK-13 | [#20](https://github.com/BK-Teisrud/NetworkKit/issues/20) |
| NK-14 | [#21](https://github.com/BK-Teisrud/NetworkKit/issues/21) |
| NK-15 | [#22](https://github.com/BK-Teisrud/NetworkKit/issues/22) |
| NK-16 | [#23](https://github.com/BK-Teisrud/NetworkKit/issues/23) |
| NK-17 | [#24](https://github.com/BK-Teisrud/NetworkKit/issues/24) |
| NK-18 | [#25](https://github.com/BK-Teisrud/NetworkKit/issues/25) |
| NK-19 | [#26](https://github.com/BK-Teisrud/NetworkKit/issues/26) |
| NK-20 | [#27](https://github.com/BK-Teisrud/NetworkKit/issues/27) |
| GATE-00 | [#28](https://github.com/BK-Teisrud/NetworkKit/issues/28) |
| REL-01 | [#29](https://github.com/BK-Teisrud/NetworkKit/issues/29) |
| OPS-01 | [#30](https://github.com/BK-Teisrud/NetworkKit/issues/30) |

## Milestones

- [F0 – Architecture and decisions](https://github.com/BK-Teisrud/NetworkKit/milestone/1)
- [F1 – HTTP core](https://github.com/BK-Teisrud/NetworkKit/milestone/2)
- [F2 – Production hardening and v1 gate](https://github.com/BK-Teisrud/NetworkKit/milestone/3)
- [F3 – Resilience and extensions](https://github.com/BK-Teisrud/NetworkKit/milestone/4)
- [F4 – File transfers](https://github.com/BK-Teisrud/NetworkKit/milestone/5)
- [F5 – Real-time communication](https://github.com/BK-Teisrud/NetworkKit/milestone/6)
- [F6 – Specialized features and research](https://github.com/BK-Teisrud/NetworkKit/milestone/7)

## Native dependencies

The original 37 blocked-by relations connected GATE-00 to DEC-01–DEC-07, NK-01–NK-20 to GATE-00, and REL-01 to ten CORE domains. Subsequent preparation added START-00 blockers for core epics/release and 45 verified blocker links across I01–I23, plus the final rehearsal dependency for REL-01. These express planning order, not automatic merge enforcement. Architecture approval does not replace security review or task-specific dependencies.

OPS-01 / #30 is complete through PR #65; team review remains a future transition requiring an actual additional reviewer, not an undelivered product requirement.

## Concrete work queue after F0

- [START-00 / #41](https://github.com/BK-Teisrud/NetworkKit/issues/41): explicit implementation authorization, completed on 2026-10-20 (ADR-0012).
- [I01–I23 with all issue links](WORK_QUEUE.md): #42–64; their original blocked state preceded authorization. I11 closed F1; consult the live queue and [F1 review](F1_REVIEW.md) for subsequent phase accounting.
- [Setup verification #40](https://github.com/BK-Teisrud/NetworkKit/issues/40): completed without product code.
- [Sorted Work Queue](https://github.com/users/BK-Teisrud/projects/6/views/7) and [Completed](https://github.com/users/BK-Teisrud/projects/6/views/8).

## Rolling planning additions — 2026-10-26

[PREP-01 #85](https://github.com/BK-Teisrud/NetworkKit/issues/85) prepares evidence access; [GATE-F2 #86](https://github.com/BK-Teisrud/NetworkKit/issues/86) reconciles v1 acceptance before rehearsal. [PLAN-F3 #87](https://github.com/BK-Teisrud/NetworkKit/issues/87), [PLAN-F4 #88](https://github.com/BK-Teisrud/NetworkKit/issues/88), [PLAN-F5 #89](https://github.com/BK-Teisrud/NetworkKit/issues/89) and [PLAN-F6 #90](https://github.com/BK-Teisrud/NetworkKit/issues/90) make later scope/feasibility/decomposition explicit. Dependency counts above are historical; the live graph and WORK_QUEUE.md define the revised plan.

## Quality follow-up traceability

BUG-01 / #95 records the native-fixture liveness remediation accepted through PR #96 and main 40390885712, with failed-run history retained. [QA-01 / #97](https://github.com/BK-Teisrud/NetworkKit/issues/97) records the owner-requested comprehensive quality/debt review before I19. Keep live status and dependencies in GitHub/WORK_QUEUE.md rather than adding another current completion counter here.
