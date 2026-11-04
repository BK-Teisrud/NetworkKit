# F4 foreground download plan

Date: 2026-11-01
Status: Owner-approved planning and detailed design; I28/#88 completed after PR #154/main. Subsequent explicit I29–I32 implementation instruction recorded below; I29 candidate acceptance pending.
Owner: PLAN-F4 #88; domains #16 / specification §4.9 and #26 / §4.19.

## Need and approval

The owner selected foreground GET download to a temporary file and explicitly approved the complete [revision 1 proposal](https://github.com/BK-Teisrud/NetworkKit/issues/88#issuecomment-6558541234): “Approve the planning proposal; still no code.” File types, sizes and the concrete app/server workload remain unknown. The original Norwegian reply is retained in the conversation. No production workload or release commitment is inferred.

## Owner-approved consolidated contract — revision 1

This section supersedes exploratory alternatives above for the first delivery. The owner explicitly approved the complete revision on 2026-11-01: “Approve the planning proposal; still no code.” Earlier draft/open statements above describe the proposal before this decision. No code is authorized.

1. **Entry point:** propose one additive `APIClient.download` operation taking a raw URLRequest, an explicit positive Int64 maximum and download-specific options for existing auth/timeouts. Return `NetworkResponse<DownloadedFile>` with a file URL and actual stored byte count. Raw request is the first bounded file-transfer entry point, not a change to typed buffered endpoints. Typed file endpoint convenience is deferred. Exact declaration labels must pass compatibility review before implementation; no general transport/plugin/file-store API is added.
2. **Validation:** reject non-GET, any body/stream, Range/If-Range and an invalid maximum before auth/network. Download-specific options expose neither retry nor accepted-status overrides: HTTP 200 only, including zero bytes. Existing buffered APIs, their status customization and F3 retry remain unchanged. No decoding or media-type allowlist is inferred from unknown file types.
3. **Ownership:** secure a uniquely named file in private temporary storage, validate its actual stored byte count and response, then transfer ownership at successful return. Never use Content-Disposition or a server filename as a filesystem path. The app moves/deletes the returned file, and owns retention/account deletion after handoff. The client never deletes handed-off files, including at shutdown. Do not return an oversized file. No hard transient disk ceiling, secure erasure or workload suitability guarantee.
4. **Cleanup and error precedence:** await operation-local cleanup attempts before completion; never sweep other operations' files. Preserve separate CancellationError and existing deadline/shutdown precedence. A cancellation/timeout that wins the operation race remains the terminal cause even if removal fails. On an ordinary failure, a removal failure takes precedence as a structured download cleanup error with a bounded primary-failure category; no raw error, URL/path or response body is retained. Therefore deletion is attempted and tested, not guaranteed if the filesystem refuses or the process terminates. Under cancellation/timeout a secondary removal failure is not separately exposed in this first API; this explicit limitation avoids a new diagnostic/error stream. No automatic crash-leftover sweeper; the host owns operational cleanup policy and private storage lifetime. If stronger cleanup observability is needed, revisit this choice before approval.
5. **Errors:** propose a small download-specific failure type for file preservation/inspection/removal and size limit. Existing NetworkError values remain available for request, HTTP, transport and timeout failures; CancellationError remains separate. Do not add cases to existing public enums merely to support file errors. Default descriptions omit file URLs, payload, raw system messages and response headers.
6. **Security/lifecycle:** one auth preparation, same existing origin/redirect/system-trust/session storage checks; no delegate replacement on injected sessions. Keep current 30-second inactivity/60-second total defaults, configurable per call; validation/preparation/transfer/file verification belong to one original total budget. Cleanup is joined even if it extends terminal return past that deadline; no promise of interruption of a blocking filesystem call. Successful handoff and cancellation/shutdown races require one explicit linearization point so a discarded result cannot leak an unowned file.
7. **Diagnostics:** preserve the current one-terminal-event model and allowlist; count only actual library attempts, at most one. No filenames, paths, byte payloads, new progress events or cleanup event stream. Existing diagnostic outcome mapping for file/size errors must be specified and reviewed before API approval, with no silent change to existing calls.
8. **Feasibility first:** documentation/SDK inspection is not native proof. Before full implementation, a separately authorized bounded feasibility task must prove async/callback file lifetime, per-task redirect/trust on owned/borrowed sessions, cancellation/shutdown cleanup and minimum availability. Failure to preserve those invariants stops the slice for re-planning; it does not authorize a custom HTTP stack or a replacement session. All four platform families remain the target; actual minimum/native/resource evidence is required for selected support. The physical Watch/publication barriers remain explicit.
9. **Server/workload:** controlled synthetic fixtures must cover complete/empty/oversized/unknown-length/encoded/error-status/interrupted responses and disk/move/delete failures. No private environment, paid service or large public stress test is authorized. Verify final stored size independently from response length metadata. File type, actual production sizes/rate and checksum/server semantics remain unknown and cannot be approved as production-ready.
10. **Delivery order:** contract/ADR and dependency decomposition; explicit code-start/feasibility permission; bounded file lifecycle; deterministic tests; native/minimum/resource checks; documentation/compatibility/owner technical gate. Preserve #16/#26 deferred scope, #29/#132 release barriers and no release/version/date commitment. Create implementation issues only after scope approval, each initially Blocked until its own authorization/dependencies. Do not close #88 while its feasibility/decomposition criteria remain unfulfilled.

Planning approval accepts this bounded proposal and the listed limitations. It is not native verification, completion of #88, or permission for a prototype, implementation, publication or further transfer features.


## Primary evidence and its limits

Apple's [download completion delegate documentation](https://developer.apple.com/documentation/foundation/urlsessiondownloaddelegate/urlsession(_:downloadtask:didfinishdownloadingto:)) requires consuming or moving its temporary file before returning from that callback. This supports an explicit internal preservation/handoff design; it does not prove the proposed public ownership API or injected-session behavior.

Apple's [pause/resume documentation](https://developer.apple.com/documentation/foundation/pausing-and-resuming-downloads) describes a separate resume-data operation. Resume remains deferred rather than silently added to cancellation. Consulted 2026-11-01. Exact availability and native behavior remain unverified for the proposed F4 implementation.


## Ordered work and actual blockers

| Order | Task | Required predecessors |
| --- | --- | --- |
| 40.1 | [START-F4 / #145](https://github.com/BK-Teisrud/NetworkKit/issues/145) | Accepted planning PR/main and explicit feasibility-only owner permission |
| 40.2 | [I28 / #146](https://github.com/BK-Teisrud/NetworkKit/issues/146) | START-F4 / #145 |
| 40.3 | [I29 / #147](https://github.com/BK-Teisrud/NetworkKit/issues/147) | I28 / #146, completed #88 and separate implementation permission |
| 40.4 | [I30 / #148](https://github.com/BK-Teisrud/NetworkKit/issues/148) | I29 / #147 |
| 40.5 | [I31 / #149](https://github.com/BK-Teisrud/NetworkKit/issues/149) | I30 / #148 |
| 40.6 | [I32 / #150](https://github.com/BK-Teisrud/NetworkKit/issues/150) | I31 / #149 |

START-F4 #145 and I28/#88 are Done after their accepted evidence and PR/main checks. I29 is In Review; I30–I32 remain predecessor-blocked/P2 under the separate explicit owner implementation instruction. START-F4 itself grants no shipping permission. START-F4 does not require #88 closure: it requires acceptance of this planning PR/main and the explicit bounded owner instruction. This avoids a dependency cycle. I29 requires both I28 and #88 plus a later explicit owner implementation decision; later tasks inherit this dependency but receive no code authorization from planning.

No new delivery milestone or date is needed. Existing F4 retains selected downloads and domain #16/#26 retain deferred catalogs; no domain is complete. #14 advanced resilience is Backlog, #89/#90 remain independent planning, and #29/#132 remain mandatory publication barriers. Reassess the plan after each completed task. Stop at every pending GitHub run until the owner resumes work.

## Evidence and unresolved feasibility

Read-only source inspection shows existing per-task delegate enforcement and rejection of unsupported borrowed/background sessions. The installed Xcode 26.3 SDK exposes `download(for:delegate:)`; task-delegate availability in the local headers is below project minimums. These are inspection findings, not native download results. This describes the pre-experiment planning inspection. The subsequent [I28 checkpoint](I28_DOWNLOAD_FEASIBILITY_2026-11-01.md) records actual local non-shipping evidence and remaining gaps; no shipping source changed.

I28 must resolve exact API labels, error/diagnostic mapping, handoff/cancellation linearization, async versus callback file lifetime and the per-platform/minimum feasibility matrix. Original specification decomposition and stable subrequirement IDs remain #88 work; no ID is invented from an incomplete PDF reconciliation. Failures of feasibility trigger explicit re-planning, not a wider framework. #88 is not complete merely because this document and its decision are approved.

## Subsequent I28 checkpoint

The owner authorized only I28 after planning acceptance. [The report](I28_DOWNLOAD_FEASIBILITY_2026-11-01.md) allocates NK-09/NK-19 IDs from the original specification and records partial Mac/typecheck evidence. #88 remains Blocked and #146 In Progress; I29–I32 remain unauthorized. No selected requirement is delivered by the experiment.

## Subsequent handoff direction

[The I28 handoff experiment](I28_FILE_HANDOFF_2026-11-01.md) demonstrates an outer operation-scoped owner across terminal arbitration, without a generic NetworkOperation refactor. Seven observations pass; this is not integrated APIClient delivery or other-platform native proof. I28 remains active for exact API/error and native-partial ownership design; no I29 permission follows.

## Final detailed-design disposition

The owner explicitly approved [I28_DOWNLOAD_DESIGN.md](I28_DOWNLOAD_DESIGN.md), including the exact proposed API/error/diagnostic surface and unobservable Foundation-owned partial-file limitation. This later disposition resolves the earlier design alternatives while preserving source-specific experimental evidence. Final documentation PR/main acceptance precedes #146/#88 completion; their live issues/project record the actual result. I29–I32 remain unauthorized and need their separate implementation instruction. No new milestone/issue or generic operation refactor is justified.

## Subsequent implementation instruction

After completed I28/#88 and accepted PR #154/main, the owner explicitly authorized I29–I32 in order. [The I29 candidate](I29_FOREGROUND_DOWNLOAD.md) records implementation/test results and remaining gates. Earlier no-code statements retain their original planning scope and are superseded only for these four tasks; new signing/device installation, purchases and publication remain excluded.
