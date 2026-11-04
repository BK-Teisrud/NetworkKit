# Temporary macOS 14 execution route — 2026-10-29

I21 / [#62](https://github.com/BK-Teisrud/NetworkKit/issues/62). The owner has no second Mac and authorized completing F2 without a paid environment. PR #120 is accepted through main run 40765690271 on 8e490340dd806fde1d93cac28cf22e33e6e6c69e; its four minimum simulator regression results retain their recorded boundaries.

## Access decision and time limit

GitHub's [official retirement announcement](https://github.blog/changelog/2026-10-01-github-actions-macos-14-runner-image-retirement/) says standard macos-14 retires on November 2, 2026, with brownouts including October 29 14:00–October 30 00:00 UTC and October 30 14:00–October 31 00:00 UTC. The former ends October 30 at 01:00 Europe/Oslo. Do not dispatch into a known brownout, wait/poll unattended, substitute a newer execution OS, or infer a successful run from image availability. The build helper refuses this temporary route on/after November 2 UTC. Remove this one-off workflow after its evidence is dispositioned or the route expires; keep the dated evidence.

[Standard GitHub runners are free for public repositories](https://docs.github.com/en/billing/concepts/product-billing/github-actions). The repository had zero Actions artifacts at the access check. Transfer is capped at 20 MiB and one day retention, with no cache, larger runner, paid service, custom image, OS install or host/toolchain change. Storage has separate allowances; this small transfer is within even the documented 500 MB allowance at the observed zero-artifact baseline.

## Concrete verification route

The manually dispatched workflow (preserved at source commit 0ab623fe67e1be161f2ef1f3ac2fc67107cebb70) had two sequential jobs; it was removed after its completed evidence was recorded. It never runs on ordinary PR/push events, is not an alternative to the mandatory matrix, has no schedule/retry or caller-controlled shell inputs, and uses read-only contents permission with GitHub-owned SHA-pinned actions and no persisted checkout credentials.

1. On macos-15, use the exact approved Xcode 26.3/17C529 and Swift 6.2.4. Build the existing public [ResourceProbe](../../scripts/benchmarks/Probe.swift) in release mode, Swift 6, warnings as errors, explicitly targeting x86_64-apple-macosx14.0. Check the actual Mach-O architecture and declared minimum. Transfer only this consumer and its package resource bundles with a source-commit/file-hash manifest. No Apple test framework, compiler or SDK is transferred.
2. On standard Intel macos-14, check out the same workflow revision, validate exact commit/source hashes, every payload file/checksum and target, and require the actual host OS major 14 and x86_64. An older preinstalled compiler never rebuilds the package. Binary-load/API/runtime incompatibility fails the run and requires diagnosis; deployment metadata alone is insufficient.
3. Use the existing controlled synthetic loopback fixture and prebuilt executable option in [the probe runner](../../scripts/benchmarks/run.py). Execute the bounded reuse/cancellation smoke and 100-cycle NetworkKit/direct URLSession controls with observation after the original deadlines. No HTTPBingo/BadSSL/public traffic is executed by this workflow. Fixture counts, native contact, cancellation joins and connection reuse remain validated by the existing runner. Exact actual OS patch/build, builder environment and numeric results are printed for review; no secrets, account data, personal payloads or device identifiers are selected.

## Local verification and evidence limits

The concrete Intel/macOS 14.0 consumer built successfully with the approved local toolchain. It ran on the owner's macOS 15.8.1 for route validation: smoke reuse received 5 payloads; cancellation joined 8 calls after native contact; the two 100-cycle controls each received exactly 6,401 payloads and sampled after 12 seconds. These are local macOS 15 observations, not macOS 14 evidence. Deliberate binary corruption and a wrong source commit were rejected before execution; the actual-minimum runner rejected macOS 15. Three permanent helper regressions cover provenance corruption/wrong commit, unexpected payload files and the wrong-OS gate. Source integrity checks pins across both workflow files.

Actual macOS 14 execution is pending. This route exercises a real public SDK consumer/native loopback/resource workload; it is not the 218-test suite, HTTPS/certificate verification, exact macOS 14.0 execution, or a universal memory bound. The [current runner image record](https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md) is a later macOS 14 patch. Record the actual runtime honestly. A 14.x result does not establish 14.0 behavior, and these narrower results do not waive any selected minimum/native/resource requirement.

## Remaining F2 work

Use actual results to update #62 and the [F2 reconciliation](F2_REVIEW.md). Minimum native HTTPS/lifecycle/storage and suitable target resources, missing physical-family/transition evidence under #63, reconciliation #86, non-publishing consumer/archive/privacy rehearsal #64 and owner risk/release disposition retain their requirements. This execution-access slice does not justify a new milestone, generic duplicate environment issue or speculative SDK refactor. No release/tag or support-minimum change is authorized by preparing this route.

## Architecture correction — 2026-10-31

[Run 41178401513](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41178401513), source db1e4100d3d8303cb90e9f39fdd46553f3a67b8b, built the Intel consumer successfully but rejected the execution host before any probe ran. Actual runner images were macos-15-arm64 (builder, macOS 15.8.2) and macos-14-arm64 (execution, macOS 14.8.9). The earlier assumption that the standard macos-14 label selected Intel was incorrect. No macOS 14 behavior result was obtained.

The corrected route targets arm64-apple-macosx14.0 and requires actual native ARM64 execution on macOS 14. Source/commit/checksum, deployment minimum, toolchain and OS gates remain enforced; an Intel execution host now fails before probe admission. This supersedes the Intel architecture choice above, not the dated local Intel observations or evidence limits. GitHub's [runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) documents the ARM64 standard label. No Rosetta, larger runner, paid service, support-minimum change or test-framework transfer is introduced. A native ARM64 result will not establish Intel or exact macOS 14.0 behavior. The November 2 retirement deadline still applies.

The corrected ARM64 consumer cross-built successfully on the local Intel Mac with warnings as errors; Mach-O architecture, minos 14.0 and source/payload integrity checks passed. It was not executed on that Intel host. Four helper tests passed, including wrong-OS and wrong-architecture rejection before probe admission. The failed run and correction are preserved in [the attempt record](evidence/MACOS14_ARCHITECTURE_ATTEMPT_2026-10-31.json).

## Completed native result — 2026-10-31

[Run 41179430976](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41179430976) passed on source 0ab623fe67e1be161f2ef1f3ac2fc67107cebb70. Actual execution was macOS 14.8.9 / 23J631, ARM64. [Main CI 41179384664](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41179384664) also passed; full logs confirmed 218 macOS tests, four simulator results of 215 each, two unsigned host builds and 15 helper tests without unexpected restart or test time-limit failure. These main-CI regressions ran on their configured newer environments, not on macOS 14.

The native macOS 14 smoke received five payloads over one connection. Eight cancelled calls joined in 0.0013025 seconds; the fixture observed six slow requests before cancellation, so this does not claim all eight reached the server. The 100-cycle controls each received 6,401 payloads (64 KiB, concurrency 32), followed by a 12-second post-shutdown observation. NetworkKit warm/settled RSS was 12,500,992 / 26,755,072 bytes; direct Foundation was 12,386,304 / 21,037,056 bytes. NetworkKit RSS grew across this finite run and remained above its warm value. These observations retain the resource-suitability/attribution risk; they do not prove a leak, bounded long-term memory or acceptance for an owner's workload. No speculative production refactor is justified by RSS alone.

[The sanitized evidence](evidence/MACOS14_RUNTIME_2026-10-31.json) preserves source/payload provenance, actual environment, all cycle observations and log hashes. The earlier architecture failure remains recorded. The completed one-off workflow is removed to avoid leaving an expired route after November 2; its implementation is available in history. This finishes the prepared macOS 14 consumer route only. Native HTTPS/full regression/exact 14.0/Intel execution, outstanding minimum and physical scenarios, archive/privacy rehearsal and owner risk disposition retain their claim boundaries and gates.

## Remaining native HTTPS route — 2026-10-31

The owner has no second Mac. GitHub's [official retirement notice](https://github.blog/changelog/2026-10-01-github-actions-macos-14-runner-image-retirement/) confirms November 2, 2026. A temporary manual-only workflow is restored for the remaining HTTPS observations. Build still requires exact Xcode 26.3 / Swift 6.2.4 and ARM64/macOS 14.0 metadata; execution requires an actual ARM64 macOS 14 host and exact reviewed source/payload hashes. The builder rejects use on or after retirement. Remove this workflow after evidence disposition or retirement; do not make it a permanent PR requirement.

Explicit `--public-https` selection prepares the additional standalone public-API consumer and executes only its ten cases: typed/raw JSON, empty 204, valid system-trusted HTTPS, self-signed rejection and hostname-mismatch rejection. Invalid fixtures require both a recognized SDK certificate transport code and an independent Foundation server-trust challenge with the exact expected OSStatus trust failure. Generic connection/timeout failures cannot pass. System default handling remains unchanged. Fixed small HTTPBingo/BadSSL requests only; no credentials, arbitrary destination, trust root, retry, public load test or paid environment. Raw Foundation stderr is captured privately and excluded from published output; the executable emits fixed labels and scalar results.

The original native resource results remain accepted at their recorded source and limits. HTTPS-only execution does not repeat the 6,400-call workloads. Both executable payloads contain repository-owned consumers/SDK code and the SDK resource bundle; no compiler or Testing framework is transferred. The existing 20 MiB payload cap, read-only workflow permissions, pinned actions and one-day artifact retention remain.

Local preparation passed the ten cases on the current Intel macOS 15 host, the missing-opt-in guard, a compiled generic-connection negative control, ARM64/macOS 14.0 cross-compilation and 17 CI helper controls. These are preparation results, not macOS 14 HTTPS execution. See [preparation evidence](evidence/MACOS14_HTTPS_PREPARATION_2026-10-31.json). Require PR/main acceptance before manually dispatching the workflow, and stop at each GitHub run as instructed. Actual runner availability before retirement is not guaranteed.

```sh
python3 scripts/ci/macos14.py build --payload .build/macos14-https-payload --public-https
# Only on the reviewed ARM64 macOS 14 execution host, using the verified payload:
python3 scripts/ci/macos14.py run --payload .build/macos14-https-payload --output .build/macos14-https-results --public-https
```

Ten consumer cases do not establish the full 218-test suite, exact 14.0 behavior, Intel macOS 14 behavior, every storage/lifecycle scenario or an owner's release-risk acceptance. Reconcile the actual result against #62/#86; preserve any failure without automatic rerun or assertion relaxation.

## Completed native HTTPS result — 2026-10-31

[Manual run 41204068268](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41204068268) passed on accepted source b8f2758530cca68ec819068ff3ac7748868e26dd. Actual execution was ARM64 macOS 14.8.9 / 23J631. All ten named typed/raw JSON, empty, trusted-certificate, self-signed and hostname-mismatch cases passed. SDK rejection codes were NSURLErrorDomain/-1202; independent Foundation controls confirmed exact OSStatus -67843 and -67602 for the respective invalid fixtures. No generic connection failure was accepted.

All recorded source hashes were independently verified against immutable blobs in that exact accepted Git commit; the standalone result matches the aggregate record. The full workflow log contains no failure marker. [Permanent sanitized evidence](evidence/MACOS14_HTTPS_EXECUTION_2026-10-31.json) retains the complete manifest, compiler/SDK, environment, case results and custody hashes before the one-day artifact expires. A local Finder `.DS_Store` was observed during verification; it is metadata, not an SDK source change. The snapshot helper now excludes only that filename, with a control proving real source edits still change custody hashes.

The completed temporary workflow is removed. Do not dispatch another run or keep an expired workflow after November 2. Together with the earlier native consumer/cancellation/resource result and four minimum simulator results, this completes the prepared minimum-family access/execution evidence for #62, subject to the evidence PR/main acceptance. It does not turn the macOS 14 consumer into the full regression suite, prove exact 14.0 or Intel macOS 14 execution, or complete physical transitions/Watch, #86/#64 or publication-risk acceptance.

## I26 retry follow-up — 2026-11-01

The earlier F2 HTTPS execution remains immutable historical evidence. [I26 minimum retry preparation](I26_MINIMUM_RETRY_2026-11-01.md) restores the same manual-only standard route for the now-authorized bounded retry increment. It is additionally main-only and selects `--public-https --read-retry`; actual runtime/resources and six new SDK-invocation/TLS cases remain pending. Guard, manifest, target/OS/architecture checks, approved builder, SHA-pinned GitHub-owned actions and one-day sanitized artifacts remain in place. No larger runner, new toolchain, unsupported fallback or publication is authorized. Remove the temporary workflow after disposition or retirement.

## Retry route completed and disabled — 2026-11-01

[Actual I26 execution](I26_MACOS14_RETRY_EXECUTION_2026-11-01.md) passes on native ARM64/macOS 14.8.9 with accepted source/payload custody. The completed workflow is disabled and removed in the cleanup candidate before retirement. Do not redispatch it or treat earlier pending-route descriptions as current instructions. The original F2 and I26 evidence remain immutable and distinct; no runtime/support or publication requirement is waived.
