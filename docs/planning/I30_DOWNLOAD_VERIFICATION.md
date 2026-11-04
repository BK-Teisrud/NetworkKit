# I30 download verification matrix

Date: 2026-11-01
Status: Verification candidate; required PR/main checks pending. I31/I32 remain open.

## Prerequisite and scope

I29 #147 is completed after PR #155/main `07874101487ffd88dd5788077f5903dceb150420` / [run 41329332271](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41329332271): all seven jobs passed, full log reviewed (256 Mac tests, four 247-test simulator runs, 22 helpers and documentation/platform checks). The explicit I29–I32 instruction already authorizes this next task. Signing/device installation, purchases and publication remain excluded.

Only two existing test files change; production Sources/NetworkKit is byte-identical to the I29 baseline after restored mutations. No protocol, source API, file adapter, dependency, workflow or host membership changes are needed. Existing I29 critical tests are retained rather than duplicated into another framework.

## Coverage and actual results

The final local Swift 6 warnings-as-errors full suite passes **267 declarations / 32 suites** on Intel macOS 15.8.1. DownloadTests now has **21 declarations / 55 expanded cases**; one additional regular-import compatibility declaration exercises public visibility. I30 adds 11 declarations / 32 expanded cases beyond I29. [Source-hashed evidence](evidence/I30_DOWNLOAD_VERIFICATION_2026-11-01.json) records final files, host, results and exact mutation targets. Declaration counts and expanded cases are distinct.

| Boundary | Evidence |
| --- | --- |
| Request/provider preflight | Retain invalid limit/method/body/default/raw/call Range checks; add provider Range/If-Range rejection after exactly one provider call and before any transport invocation |
| Final-file size | 12 combinations of 7/8/9-byte limits against an actual eight-byte fixture; missing/short/long Content-Length and encoded-response metadata cannot override stored size |
| HTTP/redirect metadata | Retain 200/empty and 204/206/503 rejection; add non-HTTP/invalid status cleanup and denied foreign/downgrade/loop delegates with zero modeled follow-ups |
| File failures | Retain preserve/inspect/remove injection; add ordinary primary categories (HTTP/size/file/transport/response) combined with removal failure, preserving only the bounded primary category |
| Cancellation/timeout/shutdown | Retain candidate-before-cancellation and joined shutdown/deadline/caller cancellation tests. Add total/system/inactivity error precedence when cleanup fails |
| Final handoff | Cancel the parent synchronously in the success diagnostic callback, after commitment; the successful app-owned file must still be returned and survive shutdown |
| Account isolation | Two clients share a provider but use distinct account/context/request IDs and private candidate paths; cancelling/shutting down A cannot delete B's handed-off file |
| Unsafe file type | A symbolic candidate must fail inspection and be unlinked without exposing or deleting its unrelated target |
| Privacy | Canary query/header/path checks and exact six-field terminal-event allowlist; only one event, file errors .other, no new cleanup/progress stream |
| Public compatibility | DocumentationExamplesTests uses ordinary import NetworkKit, not @testable. Compile original five-argument options initializer, both public APIClient factory signatures, original buffered protocol conformer and buffered/new-file function references. No live HTTP call |

The encoded metadata case models a file returned by Foundation; it does not prove gzip decompression. Redirect tests inject a native-return closure and call the existing policy delegate; zero modeled follow-ups is not a wire/server count. Timeout cases use controlled clocks/errors, not wall-time latency. Real disk exhaustion and physical resource observations are not performed. Existing native retry/core tests still execute in the full regression but do not become candidate download runtime proof.

Local source-integrity also passed: 22 helpers, unchanged 26-file host membership, manifest/dependency/workflow/JSON and document-link checks. Actual candidate cross-platform/runtime acceptance remains required in CI.

## Meaningful negative controls

1. Replace the final stored-size comparison with only a positive-limit check. The stored-byte matrix fails its intended size/cleanup assertions.
2. Insert a late cancellation check after success diagnostics in the shared observation return path. The committed-success handoff test fails; an already committed result must not be discarded after its file became app-owned.

Both controls reached their intended compiled tests and exited unsuccessfully. Restore each source in finally, verify zero production diff and execute the complete final regression successfully. Original mutation logs stay local; no private paths or raw logs are published. These controls validate the invariants rather than testing implementation text.

## Remaining delivery and backlog review

After I30 PR/main acceptance, I31 #149 is next under the existing instruction. It must obtain actual controlled native download/trusted HTTPS/auth/storage/current/minimum/platform and finite disk/memory evidence, with no inference from returned-file/header models. Existing I31 already owns that work; no duplicate issue or new milestone is justified. I32 #150 retains final API/symbol/compiled usage/docs and owner technical-gate review. A public function-reference test is not the complete I32 compatibility or usage review.

Keep the accepted output-only size/temporary-storage and unobservable Foundation-owned partial-file limitations. No secure-erasure, workload/production suitability, new signing/device install or publication claim. Domain catalogs remain open; #29 and physical Watch #132 remain mandatory publication barriers. No refactor or dependency change is justified by the passing matrix.
