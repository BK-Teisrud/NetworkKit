# F4 foreground download technical review

Date: 2026-11-04. Tracking: I31 #149 / I32 #150. Status: Candidate review; owner residual-risk disposition and required PR/main acceptance remain pending.

## Selected delivery and authority

The owner authorized I29–I32 under ADR-0015 and the I28 design, then selected one combined I31/I32 PR. Maintenance #158–#161 is completed through PR #162/main 2426c26565e970ddd1b2d34b2f3b0d81de9ad47d/run 41908869761 after full-log verification. No predecessor gate is bypassed. The owner replaced the old CI stop rule: continue useful work without polling, inspect at natural checkpoints/before merge, and retain predecessor/main and candidate gates with at most five work processes.

Under explicit delegated OS authority, [ADR-0017](../decisions/ADR-0017-current-platform-baseline.md) selects iOS/iPadOS18.0, macOS15.0, watchOS11.0 and tvOS18.0. Older-family support is removed from this unreleased candidate; Xcode26.3/Swift tools6.2/Swift6 remain. Standard macOS15 and installed 18.2/11.2 simulator families replace the retired macOS14 access problem. Actual patch/architecture execution is not proof of every supported patch or exact .0 runtime. Historical F2/F3/I31 reports remain unchanged.

This is only foreground bodyless GET to an app-owned temporary file: mandatory positive maximumBytes, HTTP200 including empty files, no Range/206, typed file endpoint, upload, progress, resume, background/relaunch, queue or download retry. Source/API/error/lifecycle behavior remains the approved implementation. #16/#26 stay open for their deferred catalogs; no new feature or milestone is inferred.

## Native verification

Final Mac selection passes nine declarations / sixteen ownership/resource cases on physical Intel macOS15.8.1. It combines real URLSession loopback file/size/status/redirect/contact and cancellation/shutdown checks, Mac-only independently captured acquired-path cleanup, four finite file/RSS workloads, and four explicitly selected public HTTPS declarations/seven cases. No public service or resource selection is added to automatic CI; its existing exact four-declaration/eight-case loopback check remains.

The bounded HTTPBingo cases check exact small Base64 file bytes, an HTTPS redirect, output-size rejection, empty200 and rejected206. Provider-once authentication uses only synthetic A/B bindings, no refresh/replay, disabled-provider401 and separate request contexts. Store-free borrowed owner sessions survive client shutdown. Private app-managed stores are compared with direct Foundation download behavior; cookies echo/retain and owner deletion/reuse are checked. Foundation and SDK did not publish cache entries for these downloads: this is not a cache-hit promise or proof of all native store behavior.

BadSSL checks include a valid positive control and rejection of the designated invalid certificate fixtures, with system-trust corroboration for generic secure-connection errors. No trust bypass, pinning, key provisioning or global ATS change is introduced. These are bounded fixture/system-trust observations, not a universal wire-attempt count or certificate-error mapping guarantee.

The simulator matrix explicitly selects eight declarations/fourteen cases per environment: the three public-constructor loopback download cases, one finite resource case and the four HTTPS cases. All eight environments passed: iPhone/iPad 18.2 and 26.2, tvOS18.2 and26.2, watchOS11.2 and26.2. Actual build numbers, models, summaries, finite observations and content hashes are in the [candidate evidence](evidence/F4_DOWNLOAD_CLOSEOUT_2026-11-04.json). A simulator model is not physical device or processor evidence. Non-Mac runs retain ordinary public imports and do not infer private acquired-path capture coverage.

## Resource, file and cleanup boundaries

Each of four workloads uses one warmup plus sixteen calls in four batches of four, at 64KiB or 1MiB, with exact counters and returned-file size sums. Returned files are removed, clients closed and process RSS sampled after five seconds. The loopback SDK logical budget is four seconds; the direct Foundation control does not replicate that wrapper's deadline mechanics. Samples include fixture/framework/runtime/allocator and prior suite state, including earlier public calls with longer budgets. They are not true peaks, library-attributed allocations, production/device RAM fit, statistical repetitions or an all-runtime-allocation cleanup guarantee.

The limit bounds successfully handed-off stored bytes, not Foundation's transient disk/memory consumption. NetworkKit cleans acquired candidates through terminal arbitration and joins workers before return; it cannot attest deletion of Foundation partials whose URL is never returned. Filesystem refusal/crash can leave files. Cancellation/timeout preserve the agreed primary error even if cleanup fails. No broad directory sweep, secure erase or universal resource cap is claimed. Existing I28/I30/maintenance fault and size-guard controls remain source-specific evidence, not actual disk exhaustion.

## Failed attempts and final evidence interpretation

Initial simulator commands had incompatible warning flags and were rejected before tests; the correct command uses warnings as errors with suppression disabled. A budget refactor briefly had a redundant try that the compiler rejected. These are build failures, not runtime evidence.

The first iOS18.2 native attempt used overly short 5/15 public-probe limits and recorded three system timeouts; it is retained. Public probes now use the library's real default30/60 budget, without SDK changes or retry. All final source-based attempts must be distinguished from that earlier probe configuration.

A current iPadPro11-inch(M5)/iPadOS26.2 attempt recorded a direct Foundation store-reference timeout, loopback system timeouts and two fixture-stop expectation failures. The isolated explicit recheck of the same environment and unchanged final source passed all eight declarations/fourteen cases. The earlier failure is not erased or labeled a demonstrated SDK defect/fix; its precise cause is unresolved. Public-service availability, short local fixture deadlines and test-runtime teardown remain observation limits rather than universal reliability guarantees. No automatic rerun/retry is built into the package or CI.

## API, examples and design assessment

Full Mac regression passes269 tests/33 suites, and28 helper tests pass. Public declarations, function signatures, access, generic constraints and relationships match the accepted baseline; intentional deployment-floor metadata is reviewed separately. DocC passes with warnings as errors. All thirty production Swift files remain byte-identical to accepted maintenance main; new runtime verification/support/example code is not part of the distributed library.

Two exact compiled ownership/error blocks in [FileDownloads](../../Sources/NetworkKit/NetworkKit.docc/FileDownloads.md) use ordinary NetworkKit imports. Synthetic app-local tests verify move/disposal, no overwrite, safe error categories and invalid-limit rejection before network. Native transfer success is separate actual evidence, not a fake public DownloadedFile initializer. Keep concrete APIClient.download and unchanged buffered NetworkClient: apps can wrap saved-file/URL values in their own domain boundary instead of adding a breaking library protocol or a testing product without a demonstrated need.

No new module/framework/dependency, actor/lock rewrite or speculative source refactor is justified. Existing explicit file ownership, admission/terminal and cancellation/deadline checkpoints remain easier to audit than a generic merged catch pipeline. The owner-selected minimum change is the compatibility deviation; no API signature/behavior expansion is hidden behind it.

## Actual consumer and privacy artifact

A fresh unsigned ReleaseConsumer archive targets iOS18.0, compiles/retains the public download method reference without invoking network on launch, and has matching binary/dSYM UUIDs. The actual NetworkKit_NetworkKit.bundle/PrivacyInfo.xcprivacy matches source SHA256 8c81590ba75b3c3df7ffab1f2df592a6b5bebc4cf905c4193876a45f4046e562. Tracking is disabled; collection/domain arrays are empty; FileTimestamp/C617.1 remains the app-container metadata reason for fstat type/size inspection. It is not a blanket filesystem permission or host-app compliance guarantee. No new production system API is introduced by this verification/platform change.

The owner deferred a new Xcode aggregate PDF export after UI automation did not open the archive reliably. The actual new archive/manifest is verified directly; historical empty-manifest PDF/positive-control records are not presented as current aggregation proof. Actual app privacy practices, eligible reason use, integrated data collection and distribution remain separate #29 review. This candidate does not claim a new aggregate report, full binary API analysis, App Store acceptance, signing or publication.

A current unsigned iOS native test host also builds with the existing test IDs. No signing identity/profile, install, hardware pairing, registration/account change or device setting is used by this delivery. Readiness inspection found iPhone/iPad/TV disconnected; no physical mobile/TV/Watch download test is marked passed.

## Remaining owner decision and release barriers

Before technical F4 acceptance, the owner must explicitly dispose of the recorded residual limits and missing physical/app-workload coverage. One possible bounded disposition is technical F4 acceptance on Mac and the recorded simulator matrix, with an explicit publication-blocking follow-up for physical download checks, actual file sizes/types/concurrency/disk and device memory, and current integrated app/privacy artifacts. That is a proposal, not an already granted waiver. Do not silently move an unmet F4 criterion into #29/#132 or treat OS delegation as authority for other scope exceptions.

Keep #29 actual app/workload/security/publication and #132 physical Watch open. Any release including downloads needs an explicit file-verification disposition; a core-only release is not implicitly expanded to include F3/F4 by merging this branch. No version, tag, release, purchase, new signing/device installation or further-extension authorization follows.

After an explicit owner disposition and successful required combined PR/main checks, recheck all I31/I32 criteria and real issue/milestone states, close them manually in order and reconcile F4. Until then, both remain In Progress/In Review rather than Done.
