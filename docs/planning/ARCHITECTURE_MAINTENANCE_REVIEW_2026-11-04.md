# Combined architecture maintenance review

Date: 2026-11-04. Tracking: QA-02–QA-05 / #158–#161. Baseline: accepted PR #157/main d1ac92d4da8950b59521bf75b9690058302a4251/run 41897385923. The owner authorized one combined branch/PR, with I31/I32 outside this delivery.

## Result and scope

Keep one NetworkKit library module and Foundation/URLSession transport. Group existing implementation files under Client, HTTP, Transport, Policies, Retry and Downloads; tests add Compatibility and Support. Thirty production Swift files remain; 29 production and 26 unit-test files move with identical bytes. The privacy resource, DocC catalog and module overview remain at the target root. The [path/content evidence](evidence/ARCHITECTURE_MAINTENANCE_2026-11-04.json) distinguishes movement from changes. No SDK runtime Swift behavior or public declaration is intentionally changed.

APIClient remains a 290-line orchestrator. Do not extract a common catch pipeline merely to reduce its size: buffered failures carry retry receipt/state while downloads preserve DownloadError and an operation-owned file across terminal arbitration. The remaining small NSError mapping duplication is preferable to erasing those explicit precedence/checkpoint boundaries. No broad extension/access-control, actor/lock or module rewrite is justified. A possible public download protocol remains an I32 assessment under its existing API gate, not an automatic addition here.

## Folder-aware verification tools

Feasibility compilation discovers nested Swift sources and excludes documentation assets. Regression fixtures include nested files with duplicate basenames and an empty-library failure. Host validation compares source-group-relative paths rather than basenames. The explicit sync_device_sources.py command refreshes only shared source membership, preserves unchanged IDs/settings, and rejects ambiguous groups/collisions. Generated files are deterministically sorted; repeated refresh after a parsed-project round trip is byte-stable. CI remains read-only: it rejects missing, flattened, duplicate and unexpected membership rather than silently repairing it.

The existing handoff-only feasibility probe compiled the nested library and passed seven no-network ownership observations. This is regression evidence for tooling/existing ownership, not renewed I28 product authorization or new platform proof.

## Native suite and CI

The 829-line native file is split into test-only fixture/support, core, storage, retry, downloads and resources. All 13 declarations remain in the same serialized PublicHTTPSTests suite with its existing two-minute limit; shared helpers have internal test-target visibility only. Other platforms keep ordinary NetworkKit imports; existing Mac-only private capture keeps @testable.

Mac CI builds the opt-in probe and executes only four allowlisted native download declarations/eight owned/borrowed cases: files/size/status/handoff, redirects, partial-write cancellation/shutdown and known-path cleanup. Discovery must match the exact identifiers. Successful process exit alone is insufficient: xUnit must contain exactly those declarations without failures/skips/extra cases, plus each ownership completion marker once. Empty/missing/failed/unexpected results fail. Public HTTPS probes and both resource tests remain explicit opt-in work. The full local loopback suite passed 13 declarations after the split, including explicitly selected resource observations; this does not renew or expand I31 runtime/resource acceptance.

A first over-anchored selection produced zero tests and was correctly rejected; the selector now accommodates SwiftPM versus Swift Testing suite separators while retaining exact discovery/result checks. A compilable removal of the SDK output-size guard caused the actual native CI selection to fail on oversized success. The original file was restored byte-for-byte, rebuilt and the selection passed. An initial alternative mutant was rejected by warnings-as-errors as unreachable code, so that attempt is not counted as runtime proof. Test-helper fixtures also reject missing/duplicate discovery and failed/empty/skipped/unexpected results.

## Planning, privacy and history

Project Status owns actual work state; WORK_QUEUE and its JSON own order/dependencies; ROADMAP owns selected scope; dated reports/JSON preserve historical evidence. Current prose is consolidated into the queue with short references elsewhere. The Work Queue filter now includes selected extension tasks while retaining domain-epic/research exclusions and its existing ascending Order configuration. The UI showed a completed I30 context row under the open filter; explicit Done/Not Planned exclusions remove it. Saved filter, ten remaining items and ascending order were verified in the UI. No dates or new milestone are invented.

CONTRIBUTING and the PR checklist require privacy assessment, a required-reason/collection/tracking review and relevant bundled-manifest validation in the system-API introducing change; no-impact decisions must be explicit. This maintenance adds no shipped Apple system API use: production files retain identical bytes, and existing FileTimestamp/C617.1 remains unchanged. I32 still reviews the actual integrated consumer/archive artifact; no historical empty-manifest report is reused as current evidence.

Active local links/tool paths follow the new layout. Dated source-hash keys, commit URLs and outcome data remain unchanged; folder moves do not rerun or relabel historical minimum/physical evidence. The user-owned untracked review remains outside this delivery and is not edited for the layout change.

## Verification status

Final source-integrity passes, including 28 Python helper tests. Full Mac regression passes 267 tests in 32 suites. Public symbols/relationships match the accepted baseline after excluding source locations/doc comments; DocC passes with warnings as errors. Watch/TV unsigned projects are prepared with validated membership; both shared-regression and native iOS test targets build unsigned with warnings as errors and suppression disabled. An initial local host command used conflicting warning flags; the retry used the existing compatible SWIFT_SUPPRESS_WARNINGS=NO setting and passed. No signing or installation occurred. Required integrated PR and main acceptance remain outstanding. No issue is Done from local checks alone.

## Next work and limits

Close #158–#161 manually only after combined PR/main acceptance and final criteria review, then reassess priorities before resuming I31 #149. No new issue is justified for the resolved selector/generator findings; they belong to this maintenance. I31 retains trusted HTTPS/auth/storage, remaining platform/physical/macOS14/resource gaps, and I32 retains compatibility/docs/privacy/technical disposition. #29/#132 remain mandatory publication barriers. No new signing/device installation, account changes, paid service, dependency, version/tag or publication occurred.
