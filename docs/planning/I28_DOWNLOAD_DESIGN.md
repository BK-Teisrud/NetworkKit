# I28 foreground download detailed design

Current execution update, 2026-11-04: I28/I29/I30 and maintenance #158–#161 are completed. The owner authorized one combined I31/I32 delivery. [ADR-0017](../decisions/ADR-0017-current-platform-baseline.md) supersedes only the earlier minimum OS values with iOS/iPadOS18, macOS15, watchOS11 and tvOS18. The exact download API/ownership/cleanup/size boundaries remain. Original submission-time planning/acceptance states below are historical, not current status.


Date: 2026-11-01
Status: Owner-approved design/disposition; PR #154/main accepted and I28/#88 completed. Subsequent I29–I32 implementation instruction is recorded in ADR-0015; earlier no-code decisions below retain their original scope.
Owner: #146 / #88; ADR-0015 revision 1 remains the approved planning baseline.

## Accepted evidence and decision boundary

PR #153/main `e9563ae1f758d9cba34b88369b05002abca5ff22` passed all seven jobs in [run 41320609362](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41320609362), full log reviewed. [Native transport evidence](I28_DOWNLOAD_FEASIBILITY_2026-11-01.md) records 28 bounded observations and compile-only minimum targets; [handoff evidence](I28_FILE_HANDOFF_2026-11-01.md) records seven ownership observations. Ordinary CI passes do not mean these opt-in experiments ran in CI. Their source hashes and execution limits remain immutable.

The recommendation is a conditional feasibility go for the selected first slice, not completed implementation or production support. The owner disposition below is accepted. Accept the final planning PR/main and then complete #146/#88 only against their actual criteria. I29–I32 still require a separate explicit implementation instruction. Do not keep repeating generic feasibility checkpoints after that boundary: integrated behavior belongs in the selected implementation/test/native tasks.

## Proposed public surface (design notation only)

| Element | Exact proposed design |
| --- | --- |
| Entry point | APIClient.download(_ request: URLRequest, maximumBytes: Int64, options: DownloadOptions = .default) async throws -> NetworkResponse<DownloadedFile> |
| DownloadOptions | Sendable value: headers: HTTPHeaders, inactivityTimeout: TimeInterval?, totalTimeout: TimeInterval?, authentication: AuthenticationPolicy; throwing initializer with existing defaults; .default |
| DownloadedFile | Sendable value with read-only url: URL and byteCount: Int64; library-created, no public initializer or implicit deletion on deinit |
| DownloadError | Sendable, Equatable, LocalizedError; sizeLimitExceeded; fileSystem(FileOperation); cleanupFailed(primary: PrimaryFailure) |
| FileOperation | preserve, inspect, remove |
| PrimaryFailure | invalidRequest, transport, httpStatus, invalidResponse, fileSystem, sizeLimitExceeded, other; bounded categories only |

Use fixed sanitized descriptions for file/options/error values. Explicit property access exposes the file URL to the app; descriptions, localized errors, diagnostics and raw underlying errors must not expose it. No arbitrary underlying NSError/userInfo is retained. The size error need not expose actual bytes or the path. No headers/body are embedded in cleanup primary categories.

Keep NetworkClient and existing NetworkError/diagnostic enum cases, constructors, defaults and signatures unchanged. The initial file operation is on concrete APIClient; apps can wrap it in their own boundary. No new protocol requirement, typed file Endpoint, transport plugin, storage framework or file queue is introduced. This avoids breaking existing mocks/conformers. New symbols and exact declarations still need actual compiled source-compatibility evidence in I29/I32; inspecting names alone is not that proof.

## Validation and response order

1. Register one operation and capture its original monotonic start. Reuse existing admission, configuration/origin and cancellation precedence.
2. Before auth/network, require maximumBytes > 0, GET, no body/stream, no Range/If-Range, valid headers/URL/security and finite positive configured timeouts. Use existing invalidRequest(.invalidConfiguration) for an invalid maximum or timeout; unsupportedRequest for unsupported file request semantics. Do not add a new invalid-request enum case.
3. Apply existing explicit/header precedence and provider-once authentication, with one request ID/account/origin. DownloadOptions has no retry or accepted-status setting. Never infer replay from GET; only one library transport invocation is allowed.
4. Enforce per-task redirects, default system trust, strict/app-managed session restrictions and existing borrowed-session ownership. No delegate replacement, silent session clone, trust bypass or side-effecting auth refresh.
5. When Foundation returns a file URL, immediately register it as a candidate owned by this operation before further throwable validation. A returned invalid/rejected response still has a file to dispose.
6. Validate HTTP response/status/headers under existing rules. Only 200 succeeds, including an empty file; all other valid statuses use existing NetworkError.httpStatus. Reject 206 as an ordinary HTTP-status failure, never as a complete ranged file.
7. Secure the candidate under a unique application-private temporary name with no server filename/path input and no overwrite of unrelated files. Inspect the actual regular file size as a nonnegative Int64 and enforce maximumBytes. Content-Length is not an oracle; encoded bytes may differ from stored bytes. Do not buffer the complete file in Data. Do not silently fall back to a cross-volume copy/buffering path if safe preservation cannot be established: fail fileSystem(.preserve). Track every path actually acquired by this call until preservation succeeds or cleanup is attempted; never delete a preexisting collision target.
8. Retain the candidate owner outside NetworkOperation.run through its terminal arbitration and joined child cleanup. The child returns only a candidate value. If the final result fails, attempt operation-owned cleanup before final diagnostic/return. If success wins, hand off once; do not insert another cancellation check that turns that committed success into an unowned discarded file.

The exact internal file adapter and exclusive preservation primitive must be implemented/tested in I29/I30. No generic NetworkOperation refactor is selected. Atomic completion means no successful result exposes an incomplete file; it is not a crash-durability or cross-volume transaction guarantee.

## Error and cleanup precedence

| Situation | Terminal error / ownership |
| --- | --- |
| Request/provider/security, HTTP or transport failure; cleanup succeeds | Existing NetworkError unchanged |
| Preservation/inspection fails; cleanup succeeds | DownloadError.fileSystem(.preserve/.inspect) |
| Final stored file exceeds maximum; cleanup succeeds | DownloadError.sizeLimitExceeded |
| Ordinary failure plus failed removal | DownloadError.cleanupFailed(primary: bounded category); no underlying path/error |
| Cancellation/shutdown wins, including failed cleanup | CancellationError; secondary cleanup failure is not separately reported, as owner-approved in revision 1 |
| Inactivity/total/system timeout wins, including failed cleanup | Existing NetworkError.timeout; secondary cleanup failure is not separately reported |
| Success wins before later cancellation/shutdown | App owns returned file; no client cleanup of that file |

A missing candidate path during cleanup may be treated as already absent only for the exact owned path, not by swallowing arbitrary filesystem errors. Cleanup attempts are joined, but filesystem failure/crash can leave files. Synchronous filesystem work can extend return past the network deadline. No automatic cleanup retry policy, broad directory sweep, destructor-based guarantee or crash-recovery service is selected.

## Native temporary-file responsibility — explicit owner disposition accepted

Distinguish two categories:

- **A URL returned to the library:** NetworkKit can track, preserve, validate and attempt removal. The proposed candidate-owner protocol applies, with the already-approved filesystem/cancellation/crash limitations.
- **An internal partial file whose URL Foundation never returns after cancellation/interruption:** no supported file reference was observed in the experiment. Foundation/OS owns that file lifecycle. NetworkKit cannot enumerate it safely or attest that it was deleted. Do not scan shared/native temporary directories, read private Foundation state, claim a hard transient-disk bound or promise secure erasure.

The recommendation is to accept that second category as an explicit first-slice limitation, rather than invent a custom streaming/file transport or falsely assert deletion. This clarifies the observable ownership boundary; the owner explicitly accepted it on 2026-11-01 before #146/#88 completion. If the owner requires library-verifiable removal of every native partial file, stop this design and re-plan separately; that requirement is not achieved by the present route.

## Diagnostics, isolation and runtime limits

Use the existing one terminal event after joined cleanup. Keep requestID/method/status/duration/attemptCount/outcome only. New DownloadError cases map to existing outcome .other; existing NetworkError/CancellationError mappings remain intact. Attempt count is 0 before invocation or 1 after invocation, not native connections/redirects. Preserve validated final HTTP status if received, even when a size/file error follows. No paths, filenames, byte counts, progress or cleanup-error stream are added to events.

Retain provider-once auth and strict/app-managed session rules. Current download runtime evidence covers only store-free owned/borrowed sessions on Intel macOS 15.8.1. App-managed stores, successful trusted HTTPS/auth and other platform/minimum runtime behavior are not inferred. Existing platform matrix/typechecks are feasibility evidence only; I31 must obtain actual selected native/minimum evidence or seek a separate explicit support/gate disposition. No missing F4 criterion is silently moved to #29/#132. Host apps own foreground/background/relaunch behavior and post-handoff retention, file protection suitability, backup/account deletion. No background capability, group, privacy entitlement or extra device installation is authorized by this design.

## Issue order and acceptance plan

- #145 Done: I28-only permission recorded; not shipping authorization.
- #146 and #88: remain open until this remaining limitation is disposed and final design/reconciliation/dependency documentation passes PR/main. Original specification mapping is in the first I28 report, with NK-09-02/-07 and NK-19-02/-07 selected within this boundary; deferred IDs remain explicit.
- #147 I29: blocked by #146 and #88 plus a separate explicit code-start instruction; implement only the selected API/file lifecycle and meaningful critical-path tests.
- #148 I30: deterministic status/size/failure/isolation/race and compatibility verification, including original-deadline discard and cleanup-failure precedence. The feasibility fault injections do not replace these tests.
- #149 I31: controlled native/trusted HTTPS, storage/auth, platform/minimum and bounded resource/disk evidence. Actual app workloads remain unknown.
- #150 I32: compiled examples/DocC, compatibility and owner technical-gate review, then required PR/main acceptance.

No new issue/milestone, generic refactor, date, purchase, platform-support downgrade, tag or release is justified. Domain #16/#26 remain open; #14/#89/#90 priorities are unchanged. Physical Watch #132 and actual app/workload/security/publication #29 remain separate mandatory publication barriers. Reassess the backlog at each completion.

## Explicit owner approval and closure criteria

The owner approved the complete [publicly reviewable design](https://github.com/BK-Teisrud/NetworkKit/issues/88#issuecomment-6560073646) on 2026-11-01. Translated reply: “Approve the detailed design and limitation; no I29 code.” The original Norwegian reply remains in the conversation. This approves exact API/error/diagnostic planning and the unobservable Foundation-owned partial-file limitation, not shipping source or runtime support. Earlier native/handoff reports describe their submission-time open design questions; this later owner decision resolves those questions without rewriting their raw evidence.

| I28 / #88 criterion | Completion basis and retained limit |
| --- | --- |
| Source requirement reconciliation | Original PDF §4.9/§4.19 adapted in I28_DOWNLOAD_FEASIBILITY_2026-11-01.md; NK-09-01–08 and NK-19-01–07 allocated with selected/deferred scope |
| File lifetime/security/session feasibility | 28 source-hashed Mac observations; callback versus async lifetime distinguished; owned/borrowed store-free paths observed; app-managed/trusted HTTPS integration is I31 work |
| Size/storage/error/cancellation ownership | Explicit output-only limit, new bounded errors, owner-approved cleanup/native-partial disposition and seven existing-arbiter handoff observations; actual production adapter/races remain I29/I30 |
| Platform/host feasibility matrix | All four existing families/minimums remain targeted, three simulator targets typecheck only, actual Mac/native evidence identified; physical/minimum/integrated evidence required in I31, no background/relaunch promise |
| Dependencies | Reuse existing auth provider/session/core primitives. No dependency on advanced retry #14, refresh #12, cache #15 or network status #19. Download retry stays absent; existing F3/default-disabled behavior is unchanged. No blanket publication #29 dependency for feasibility |
| Detailed decomposition | START-F4 #145 Done; I28 #146 and PLAN-F4 #88 pending final documentation acceptance; native dependency graph and I29–I32 #147–#150 already exist |
| Approval and verification | Complete owner approval recorded; final documentation PR/main must pass before metadata closure; implementation stays separately unauthorized |

Feasibility completion means a reviewed implementable direction with explicit limits, not executing an unimplemented product on every device. Do not pre-complete I29–I32 verification. Final PR/main acceptance and the actual issue/project readback will be recorded in #146/#88; no extra documentation-only closeout loop is required solely to replace this submission-time pending state.
