# Architecture maintenance before further I31 work

## Decision and evidence boundary

On 2026-11-04 the owner requested scheduling the architecture audit findings before further download work, then explicitly permitted plan/issue/project updates while PR #157 CI is pending. That initial update was a planning-only exception. After the run completed, the owner instructed implementation of the combined maintenance delivery. The normal CI stop rule still applies after each push/merge.

The audit reviewed checkpoint 7a4d5eb0d55197664204dd09250e866b0fb33d05: 30 production Swift files / 2,383 lines, APIClient 290 lines and the shared native loopback test file 829 lines. One NetworkKit module using Foundation/URLSession remains appropriate. The concrete gaps are native functional CI execution, flat-path tooling, file organization and duplicated current planning/privacy-review process. Counts describe that checkpoint, not permanent thresholds.

## Required sequence

PR #157/main run 41897385923 is accepted. The owner subsequently selected one combined implementation branch/PR for the four maintenance tasks, excluding I31/I32. Preserve the local sequence and intermediate verification; there is one integrated required PR/main gate. No task is Done until that gate and its own criteria pass. Internal predecessors below guide implementation, rather than requiring separate PR/main cycles.

| Order | Task | Predecessor |
| --- | --- | --- |
| 40.41 | [[QA-02] Make source discovery and device-host generation folder-aware](https://github.com/BK-Teisrud/NetworkKit/issues/158) | PR #157 checkpoint/main acceptance |
| 40.42 | [[QA-03] Split native loopback tests and execute a bounded functional CI selection](https://github.com/BK-Teisrud/NetworkKit/issues/159) | #158 |
| 40.43 | [[QA-04] Organize library and unit tests without changing API or lifecycle behavior](https://github.com/BK-Teisrud/NetworkKit/issues/160) | #159 |
| 40.44 | [[QA-05] Consolidate current planning and require privacy review with system API changes](https://github.com/BK-Teisrud/NetworkKit/issues/161) | #160 |

Further I31 #149 execution is blocked by all four maintenance tasks until integrated acceptance. I32 #150 still requires I31. Existing I31 trusted HTTPS/auth/app-managed storage, current/physical/minimum/macOS 14 and representative resource evidence are not waived or transferred to publication. The maintenance tasks belong to existing F4; no new milestone, dates, product scope or release is introduced. Priority remains P2/EXTENSION, with Order and dependencies expressing precedence within F4 rather than relabeling extension work as core.

## Scope and safeguards

Folder-aware source discovery and host membership precede moves. Preserve relative paths, detect missing/duplicate membership and validate resources/DocC and platform membership. Then split native fixture, core/storage, retry, download and resource responsibilities within the existing verification target. Run an explicit bounded loopback functional selection in CI with fail-closed missing/zero-test checks. Public HTTPS probes and resource benchmarks remain explicit opt-in work.

Organize source/test files by responsibility within one module: Client, HTTP, Transport, Policies, Retry and Downloads where useful. Avoid empty folders and arbitrary file-size rules. Keep resource/DocC paths deliberate, update active links/tooling and preserve dated evidence and recorded hashes. Review duplicated transport error mapping for a small pure helper, but keep a documented no-change outcome if extraction obscures checkpoint/cancellation semantics. Preserve public API, file candidate ownership, terminal arbitration, session ownership and joined shutdown.

Consolidate current planning responsibilities and add system-API privacy review to the introducing change. QA-05 must also verify that Work Queue shows selected, ordered extension tasks: its existing blanket extension-label exclusion hides the current F4 delivery tasks. Correct the view during QA-05 while retaining deferred-epic/research separation and ascending Order. The fstat FileTimestamp/C617.1 correction in PR #157 is a concrete review-process lesson; I32 still verifies the integrated consumer/archive manifest. Historical empty-manifest evidence remains historical.

## Deliberately deferred or retained

No module split, framework, new dependency, broad actor/lock rewrite or new transport architecture is justified by this audit. The existing HTTP pipeline and separate lifecycle/terminal states remain. No download protocol is introduced automatically: existing I32 evaluates concrete API testability and documents whether a narrowly scoped protocol is justified; any material API decision is separate. No duplicate issue is created for I31 runtime gaps or I32 privacy/artifact review.

GitHub Project Status owns actual task state; WORK_QUEUE and its structural JSON own order/dependencies; ROADMAP owns selected scope; dated reports/evidence preserve historical observations. Task completion triggers another quality/backlog review. #29 and #132 retain mandatory publication barriers. New signing/device installation, purchases and publication remain outside this update.
