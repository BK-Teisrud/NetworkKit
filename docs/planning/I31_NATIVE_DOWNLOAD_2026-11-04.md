# I31 native download Mac checkpoint

Date: 2026-11-04
Status: Partial I31 evidence; #149 remains In Progress. Required checkpoint PR/main acceptance pending.

## Predecessor and scope

I30 #148 completed after PR #156/main `07fdce6caec8a0544caa12a7ee3c3f1c0136fd99` / [run 41333096996](https://github.com/BK-Teisrud/SwiftNetworkKit/actions/runs/41333096996): seven jobs passed; full log confirms 267 Mac tests, four 258-test simulator runs, 22 helpers and documentation/platform/host checks. Existing explicit I29–I32 authorization covers this next task, excluding new signing/device-installation steps, purchases and publication.

The existing non-shipping NativeLoopbackTests fixture/selection gains native cases. Production Swift is unchanged; the separate required-reason privacy resource and existing bundle test are corrected below. No public API, dependency, root-test membership, workflow, physical device or account changes. The original regression/core evidence is retained separately; a root CI pass does not execute these opt-in native tests.

## Actual native execution

Run `swift test --package-path Tools/PublicHTTPSChecks -Xswiftc -warnings-as-errors --filter nativeLoopbackDownload` explicitly. On Intel macOS 15.8.1, **five declarations / nine expanded cases passed**, using real URLSession downloads through the candidate public API and bounded synthetic loopback fixtures. No public service or real credentials were used. [Source-hashed evidence](evidence/I31_NATIVE_DOWNLOAD_2026-11-04.json) identifies source, host, execution and limitations.

- **Stored output and contacts:** owned/store-free borrowed clients download 64 KiB, empty HTTP 200 and close-delimited unknown-length files. Independent file attributes and bounded content reads match reported bytes. Oversized 1 MiB and HTTP 206/503 calls fail as required with one server contact each and one library diagnostic attempt. Three handed-off files survive client shutdown and are explicitly removed by the test. Borrowed owner-session reuse after SDK shutdown succeeds through direct Foundation.
- **Redirects:** one same-origin follow reaches its target; a separate foreign fixture records zero target contacts when the SDK declines the cross-origin redirect. Tests count both source and target requests rather than infer policy from returned status alone.
- **Partial transfer lifecycle:** the fixture writes HTTP headers plus 1024 bytes of a declared 1 MiB body and holds the connection open. After observed server write completion, caller cancellation and shutdown yield CancellationError and joined return. The client remains reusable after caller cancellation; shutdown closes admission. A server write is not proof of a particular client disk flush. Native partial-file removal remains unobserved when no URL is exposed.
- **Known acquired-file cleanup (Mac only):** a wrapper calls native session.download and captures only this test's returned URL; a private destination seam supplies this test's private path. HTTP status/size rejection and injected preservation/inspection failures remove known native source/destination files. Injected removal refusal reports the agreed primary category and leaves the known file for explicit test cleanup. This combines native transfer with bounded injected file failures; it is not actual disk exhaustion. No shared temporary directory is scanned or swept.

The public-constructor parity/lifecycle tests use the live adapter. The extra known-path test uses internal Mac-only capture/destination/fault seams to observe actual acquired paths without exposing a product hook. Non-Mac hosts compile only the three public native scenarios (six ownership cases); compilation is not execution evidence.

## Finite file/RSS observations

A fifth Mac-only test compares NetworkKit downloads with direct Foundation under the same store-free/request-inactivity profile. Each of four workloads has one warm-up plus 16 calls in four batches of four, with 64 KiB or 1 MiB responses. Every returned file is measured and removed; each server counter increases by exactly 17. SDK logical budget is four seconds; native resource configuration retains platform defaults. Five seconds after joined completion/shutdown, another RSS sample is recorded. The direct control lacks the SDK logical-budget wrapper; this is a healthy finite transfer comparison, not equivalence of timeout mechanics.

| Mode | File size | Calls | Total returned file bytes | Sampled maximum RSS (MiB) | RSS after five seconds (MiB) |
| --- | --- | --- | --- | --- | --- |
| networkkit | 65536 | 17 | 1114112 | 15.54 | 15.51 |
| foundation | 65536 | 17 | 1114112 | 15.74 | 15.71 |
| foundation | 1048576 | 17 | 17825792 | 17.36 | 17.36 |
| networkkit | 1048576 | 17 | 17825792 | 17.44 | 17.29 |

These are same-process aggregate samples including the NW fixture, runtime and allocator, taken in a fixed workload order; they are not continuous peaks, isolated client allocation totals, leak/production proof or universal bounds. Returned-file byte sums do not measure Foundation partial files, write amplification or peak transient disk consumption. A later sample can exceed the completion-sampled maximum. No memory threshold is enforced or workload size promised.

The complete local loopback regression also passed: **13 declarations / one serialized suite**, covering the shared fixture's older core/retry paths and the new download selection. Its four additional download resource rows are preserved separately in the JSON. That process has a different prior allocator/runtime workload; the two runs are not independent statistical repetitions and their RSS values must not be pooled into a universal estimate.

## Actual minimum simulator execution

[The minimum report](I31_MINIMUM_DOWNLOAD_2026-11-04.md) records actual unsigned iOS/iPadOS 17.0, watchOS 10.0 and tvOS 17.0 execution: three public declarations / six cases per destination, 24 cases total, zero failed/skipped/expected failures and successful shutdown of every task-started simulator. These are source-specific x86_64 observations, not physical/ARM64 proof. They exclude the Mac-only instrumented cleanup/resource cases and all public services.

GitHub's [official macOS 14 retirement announcement](https://github.blog/changelog/2026-10-01-github-actions-macos-14-runner-image-retirement/) names November 2, 2026 for retirement. Checked on November 4. The old F3 temporary workflow/guard is not revived or extended, and prior macOS 14 core/retry evidence is not claimed as file-download evidence. Actual candidate macOS 14 access remains open under I31.

## Remaining I31 work and backlog disposition

#149 stays In Progress. Controlled trusted HTTPS/auth, app-managed storage, actual other current/physical environments, candidate macOS 14 and representative cross-device resource evidence remain open; the named minimum simulator routes are now observed. Prior I28/F2/F3 runtime results are not silently relabeled as candidate download evidence. Missing F4 evidence still needs its own explicit disposition; it is not automatically moved into #29/#132. I32 #150 retains final compatibility/compiled usage/docs/owner technical gate.

Keep these remaining criteria in existing I31; no duplicate native/resource issue, extra milestone, production refactor or paid environment is justified by this passing checkpoint. Domain catalogs and priorities stay unchanged. #29 actual app/workload/security/publication and physical Watch #132 remain mandatory; no release/version/date or new signing/device install is approved.

## Required-reason metadata correction

Review found fstat added by I29 but an empty required-API list. Apple [lists fstat](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) in FileTimestamp even when only file size/type is read; [C617.1](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons) covers app-container metadata. The bundled manifest now declares that category/reason; inspection occurs after preservation to app temporary storage. No timestamp is consumed or sent as telemetry. Tracking remains disabled and collection/tracking-domain lists stay empty. Sources checked 2026-11-04.

Update the existing packaged-resource test, not a new test framework. Downstream integrated privacy/archive review remains I32/#29 work; this declaration is not an App Store/privacy-compliance guarantee. Native/minimum behavioral runs above used the prior manifest, whose hash is retained; functional Swift source is unchanged. Corrected resource validation and the outdated-empty-manifest negative control are recorded separately. Historical F2/archive evidence is unchanged.

The corrected bundled manifest test passes. Restoring the old empty declaration deliberately fails the intended category assertion; restore the correction and the full warnings-as-errors Mac regression passes **267 declarations / 32 suites**. This validates the resource separately from the earlier native behavioral runs. Required candidate PR/main and final consumer/privacy-artifact review remain distinct.

Final local source-integrity passes with 22 helpers and unchanged 26-file host membership. DocC converts with warnings as errors and existing compiled examples build. All source hashes and four minimum cleanup/result records are checked. Required PR/main acceptance is pending; I31 remains open for the explicitly listed criteria.
