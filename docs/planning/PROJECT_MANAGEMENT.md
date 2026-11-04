# Project management

GitHub Issues define tasks and acceptance criteria. Milestones are delivery gates. Projects tracks work status; the roadmap and ADRs explain decisions. Maintainer @BK-Teisrud prioritizes work. [NetworkKit Roadmap](https://github.com/users/BK-Teisrud/projects/6) is private; repository issues are public.

## One work status

The project Status field is authoritative: Backlog → Ready → In Progress → In Review → Done. Blocked identifies a concrete obstacle; Not Planned denotes rejected/duplicate work. Old status labels were removed to prevent duplicate tracking. Issue open/closed state and closure reason record actual completion. Done requires completed and met acceptance criteria; dragging a card to Done does not close the issue.

Ready requires explicit implementation authorization where relevant, resolved blockers, a clear contract/test plan, and symbol checks for actual selected APIs. Dependencies guide planning; they do not enforce merges. Reopened issues return to Backlog for triage. After not-planned closure, manually select Not Planned because Item closed sets Done regardless of reason. Completed filters on reason:completed and excludes rejected work independently of project status.

The owner permits up to five concurrent work processes, including independent issue/branch/PR workstreams, as of 2026-10-26. Prepare PRs sequentially; parallelism is optional, not a target. Pull only Ready work. Before another workstream, verify native dependencies, accepted API/contracts, file overlap and capacity. Use a distinct branch and an isolated checkout/worktree for concurrent edits; never switch a dirty shared checkout between tasks. Shared contract, manifest, workflow or planning-file changes require sequencing or an explicit integration plan, followed by rebase/conflict review and fresh checks. Do not merge dependent work against an unaccepted contract.

Conservatively permit at most two heavy CI workflows at once (two matrix jobs each) plus one local heavy verification process, keeping the planned heavy-work budget within five. Do not fan out five workflows that each start two matrix jobs. Respect GitHub's actual runner limits and preserve standard runners. A PR is created before preparing the next independent PR; do not launch simultaneous publication operations. Stop adding work when capacity is reached.

The owner explicitly reconfirmed on 2026-10-31: stop whenever a GitHub run is pending and await the owner's instruction to continue. Do not poll or continue independent work across that stop. Independent Ready work may be prepared only while this stop condition does not apply, after dependency/overlap/capacity review. No unattended monitor or automatic resumption is implied. P0 means incident/gate; P1 necessary core work; P2 later extensions; P3 research. Priority does not authorize code.

## Fields and views

Work views show Status, Priority (P0–P3), Scope (CORE/EXTENSION/RESEARCH/GOVERNANCE), Order, and built-in Title/Assignees/Milestone/Parent issue fields. Labels describe type/scope/priority; align Priority/Scope with labels during triage. There is no automatic synchronization. Do not invent dates.

| View | Purpose |
| --- | --- |
| Backlog | All open work, including epics and later scope |
| Work Board | Status columns including Done; Not Planned hidden |
| Roadmap | Phase overview without invented dated delivery bars |
| Phase 0 | Open F0 setup tasks |
| Decisions | Decision issues |
| Extensions and Research | Deferred scope |
| Work Queue | Open concrete tasks without epics/extensions/research; concrete tasks including selected extensions, sorted by ascending Order |
| Completed | Closed issues with reason:completed |

[WORK_QUEUE.md](WORK_QUEUE.md) defines the numbered order. Order 0 is the start gate; I01–I23 retain 1–23; PREP-01 is 16.5, GATE-F2 is 22.5, and the release gate is 24. Post-v1 planning tasks use 30/40/50/60; they do not authorize extension code. No product work is Ready before implementation authorization. Epics provide traceability, not oversized individual tasks.

## Built-in workflows

These are Projects features, not GitHub Actions workflows.

| Workflow | State / rationale |
| --- | --- |
| Auto-add to project | On; NetworkKit only, filter is:issue; imports new/updated root issues |
| Auto-add sub-issues | On; keeps subtasks in the project |
| Item added | On → Backlog; triage Priority/Scope/Order |
| Item closed | On → Done; correct Not Planned manually as described above |
| Item reopened | On → Backlog |
| Pull request merged | On → Done for the PR item; issues close only when actually completed |
| Auto-close issue | Off; moving status must not close work |
| Pull request linked to issue | Off; links must not bypass the start gate or start work |
| Auto-archive / review approved / changes requested | Off; retain history and avoid misleading solo-review transitions |

Issue #40 functionally verifies import, Done without closure, completed, and reopening. Results/limitations are in [setup status](../governance/SETUP_STATUS.md). PR/subissue rules are configured and read back; do not claim separate end-to-end tests without evidence.

## Verification-gated issue closure

For issues that require both PR and main verification, use neutral references such as `Tracking: #123` in PR bodies. Do not place a GitHub closing keyword followed by an issue reference anywhere in the body, including future-tense instructions, quotations or a statement that closing should happen later. GitHub can interpret those references at merge regardless of the intended timing.

Check a prepared body for unintended closing syntax, and inspect `gh pr view NUMBER --json closingIssuesReferences` when finishing the PR metadata. For verification-gated work the list must be empty. Record main acceptance before manually marking the relevant issue completed/Done. A merge-triggered automatic closure is not evidence that main passed; preserve its event and record actual later acceptance separately.

PR #135 exposed this issue: its narrative instruction created a closing reference to #64. The main run later passed and the formal acceptance was recorded then; #27 and F2 remained open until their final verification. This process correction does not change product scope, branch protection or required checks.

## Combined maintenance delivery — 2026-11-04

The owner selected one branch/PR for #158–#161, excluding I31/I32. Internal order and intermediate checks remain, but do not model them as external blockers requiring separate PRs. All four require integrated PR/main acceptance before manual closure. I31 stays externally blocked by all four; no issue is marked complete from a partial implementation. Work Queue includes selected extension tasks while excluding domain epics and research. Preserve ascending Order. This grouping changes delivery overhead, not scope, security rules or the CI stop rule.

## Maintenance

The owner requested continuous plan maintenance on 2026-10-26. Before selecting each task, after each accepted delivery, after failures/new findings, and at phase boundaries:

1. Compare actual acceptance evidence with scope, open risks and all affected domain epics. Do not close an epic from subissue counts alone.
2. Create bounded follow-up/defect/planning issues immediately when gaps appear. Give each a purpose, requirement references, exclusions, acceptance evidence, owner, milestone, labels and matching project Priority/Scope/Status; assign Order to executable or sequenced planning tasks.
3. Recheck native blockers and parents for cycles and artificial scheduling dependencies. Mark Ready only when the contract, prerequisites and verification plan are adequate. An open epic with unfinished acceptance is not automatically Blocked.
4. Update WORK_QUEUE.md, its structural JSON, roadmap and risks when their meaning changes. Preserve dated evidence and original seed snapshots. Record why priorities or milestones changed. Use I identifiers for selected implementation slices and PLAN/PREP/GATE identifiers for preparation and decisions.
5. Keep the next actionable task detailed; prepare the next phase's use cases, contracts, feasibility and decomposition before code. Keep distant phases at honest decision/research detail, expanding or splitting them when evidence supports it.
6. Read back GitHub state after mutations, including labels/fields, milestone, parents/blockers and issue closure reason. Record PR/main acceptance before Done and review next work again.

Product scope, material platform/API/security deviations, spending and publication still require the owner's relevant decision. Routine evidence-based triage, issue decomposition and milestone/priority maintenance are authorized. This procedure runs during active work; no unattended scheduler or automatic field synchronization is implied.

Weekly triage additionally checks new issues, missing fields, blockers, WIP, and next Ready work. Verify actual evidence before phase transitions. Review bugs/risks after releases. No invented sprint dates or SLA. Track blocked work, lead time, and oldest WIP; commit counts do not measure quality. All GitHub content is English; conversations with the owner remain Norwegian under LANGUAGE_POLICY.md.

## Continuous quality and technical-debt assessment

The owner requested proactive quality/refactoring review on 2026-10-26. Before and after each task, inspect the touched code and adjacent contracts for correctness, duplicated policy, dead paths, unsafe state, misleading tests/docs, unbounded cleanup and avoidable complexity. Fix concrete weaknesses within the authorized scope and verify the behavior; this is part of normal delivery, not a separate optional clean-up phase.

Prefer a small behavior-preserving correction to a new framework, module, dependency or broad rewrite. Keep explicit boundaries when removing repetition would obscure ordering, ownership, cancellation or security. Add meaningful regression/negative controls for actual failure modes; do not add implementation-mirroring tests, arbitrary metrics or boilerplate debt tickets merely to show activity. Record why a proposed refactor is beneficial and why plausible alternatives are deliberately deferred.

If a finding needs distinct acceptance, reproduction or sequencing, create a bounded issue and update priority/blockers/queue immediately. Otherwise fix it in the current slice and document it. Existing security/resource/runtime/device/release owners retain their work; do not duplicate them as generic quality issues. Material public behavior/API/support/security/cost changes still need an impact decision. Record actual checks and remaining uncertainty; do not promise zero future technical debt or suppress failed evidence. [The first comprehensive review](QUALITY_REVIEW_2026-10-26.md) provides the baseline and concrete corrections.
