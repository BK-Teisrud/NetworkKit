# I28 operation-scoped file handoff experiment

Date: 2026-11-01
Status: Partial I28 feasibility evidence; no I29–I32/public API authorization.

## Accepted predecessor

PR #152/main `c043db2af535ded1d80d0f88ea4137bbc18e4dec` passed all seven jobs in [run 41317907594](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41317907594). The full log was reviewed; ordinary core tests and CI helpers passed. The opt-in I28 experiments are not automatically executed by that CI. Earlier [native checkpoint](I28_DOWNLOAD_FEASIBILITY_2026-11-01.md) results remain source-specific and immutable.

## Question and method

The existing generic `NetworkOperation<Value>` arbitrates cancellation/deadlines after its body returns and can discard a successful candidate value. That is appropriate for buffered values; a file URL by itself does not dispose its referenced file. This is not a defect in an existing shipped file API: no such API exists. Handing off a file inside the body would lose its cleanup owner when the final outcome is an error.

The authorized non-shipping [handoff probe](../../Tools/DownloadFeasibility/HandoffProbe.swift) compiles alongside unchanged SDK sources. It uses the actual existing NetworkOperation, bounded 64-byte private temporary fixtures, explicit gates and a controlled clock. No network, app/device/signing or shipped target is involved. Its clock tests finish-time arbitration only; it is not an inactivity/watchdog or wall-time test. Compile used Swift 6 with warnings as errors; child execution was bounded to 20 seconds.

## Actual observations

Seven observations passed on Intel macOS 15.8.1:

1. Negative ownership control: advance the clock past the original deadline inside the operation body, then return a candidate URL. NetworkOperation throws totalBudget and the file still exists until the harness explicitly removes it. This demonstrates the integration hazard without changing SDK code.
2. Keep the candidate in an outer operation-scoped owner; after deadline arbitration/join throws, explicit cleanup removes the file.
3. Block the child with an explicit gate, cancel the parent, release the child and await its result/join. CancellationError wins and outer-owner cleanup removes the discarded candidate.
4. Successful operation result is handed off only after NetworkOperation returns success. Later owner cleanup does not remove the app-owned result.
5. Inject a bounded removal failure before file IO. The known owner/file remains; explicit subsequent cleanup succeeds. This is not a production retry policy or proof of real disk-error mapping.
6. Simulate a preserve-stage failure and remove the still-owned source.
7. Simulate an inspect-stage failure and remove the still-owned candidate.

The preserve/inspect cases inject named failures before cleanup; they do not execute a production preservation/inspection adapter or prove error precedence. All private fixture files are gone at the successful test boundary. [Source-hashed evidence](evidence/I28_FILE_HANDOFF_2026-11-01.json) identifies exact probe/runner/SDK source and limitations. No runtime result on other platforms is claimed for this new probe.

## Recommended integration boundary

Keep candidate ownership outside NetworkOperation.run until terminal arbitration and child join complete. The child may preserve/validate a candidate, but it must not make that file app-owned. On error, the outer owner attempts cleanup with the approved error precedence. On successful return, transfer ownership exactly once without introducing another cancellation check that could discard an already committed success. Never sweep files belonging to another call/account.

This protocol assumes filesystem changes are serialized within the one operation and cleanup occurs only after child join. The small probe owner is not a general concurrency-safe file manager; do not copy it into shipping code as such. Preserve/inspect/remove errors, public error mapping and diagnostics still need the final I28 design and later implementation tests. A synchronous filesystem operation can delay return; the deadline does not make it interruptible.

No generic NetworkOperation refactor is justified by this experiment: it can retain its current value semantics. A narrowly scoped candidate-file owner in the future file path is the proposed extension. Existing buffered calls and F3 retry remain untouched.

## Remaining scope and backlog disposition

I28 #146 remains In Progress; #88 remains Blocked. The next I28 work is the final exact API/error/diagnostic design and explicit boundary between library-adopted files and Foundation-owned partial files. Do not promise deletion of an inaccessible native partial file or recoverability after a crash. Integrated network/deadline/handoff races belong to authorized implementation and its tests later; this experiment supplies a feasibility direction, not that proof.

Keep these remaining questions in I28 rather than adding duplicate cleanup or refactoring issues. I29–I32 remain unauthorized/Blocked. #29 and physical Watch #132 remain mandatory publication barriers. No new milestone, date or production workload claim is selected.
