# Non-publishing release rehearsal — I23 / #64

Accepted follow-up: PR #135/main cc654ab5faadc0fc7fe00d7ad238b2e3ed5a997c and run 41242130528 passed full-log verification. #64/#27 and F2 are closed; see [final closeout](F2_CLOSEOUT_2026-10-31.md). The original executed-at-submission text and JSON below retain their historical pending status, not the current gate state. Publication and F3 implementation remain unauthorized.


Date: 2026-10-31. Status: executed; this evidence PR/main acceptance is pending. #64 and #27 remain open. No tag, release, upload, consumer installation, distribution or production-readiness approval.

## Accepted baseline and prerequisites

Source: `966599844ba59a35347e0f215f122fdebf084df3`, PR #134, [main run 41238957032](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41238957032). Full logs confirm all seven checks: 218 Mac tests, four simulator runs of 215, 19 helpers and four manual-host provenance checks, without failure/restart markers. #86 and nine eligible selected-core epics are closed/Done; #27 remains dependent on this rehearsal. [F2 reconciliation](F2_REVIEW.md) preserves all 79 selected/deferred source bullets and exact platform limits.

The owner approved only the non-publishing F2 rehearsal with the recorded resource limitations. [ADR-0013](../decisions/ADR-0013-watch-publication-gate.md) keeps missing physical Watch evidence mandatory under #132/#29 with support unchanged. Neither decision authorizes publication or F3 implementation.

## Clean checkout and public revision installation

A new detached Git clone of the accepted commit was clean before and after verification. The fresh local warnings-as-errors regression passed 218 tests in 28 suites on Intel macOS 15.8.1 / 24H32, Xcode 26.3 / 17C529, Swift 6.2.4. The accepted CI supplies the separate four-family build/five-runtime results; no local simulator/physical rerun is invented.

A separate SwiftPM executable declares only the public GitHub URL with that exact revision and imports NetworkKit normally. Its resolved file contains exactly one package pin at the expected SHA; the fetched dependency checkout is clean and has the correct HEAD. Release compilation with warnings as errors passed. The existing public probe then ran against a disposable loopback fixture: reuse served five 64 KiB payload requests on one connection; cancellation joined all eight calls after observed native contact. Fixture teardown is checked by the existing harness. This is a finite functional smoke, not a memory/latency threshold, TLS observation or production workload benchmark. Installation from an actual release tag remains #29 after separate tag authorization.

## Unsigned consumer archive and manifest

From the clean checkout, the existing iOS consumer archived in Release for generic iOS with signing disabled. The result is arm64 with iOS 17 minimum. The archived binary and dSYM UUIDs match; that dSYM contains 1,818 NetworkKit and 110 APIClient symbol records, proving SDK linkage under this build. Counts are inventories, not an API/stability or exhaustive binary analysis claim.

Exactly one SDK PrivacyInfo.xcprivacy is present at NetworkKit_NetworkKit.bundle/PrivacyInfo.xcprivacy and matches the reviewed source hash `528ab3fca910d2ac2f3ef256d5ea4c2327303a7a4a5efb9236987f3018e311f3`: tracking false, empty domains, collected-data and required-reason arrays. No provisioning profile, signing, account registration or device installation was used.

## Aggregate report custody and review

The existing owner-exported Xcode report and separate nonshipping positive control were rechecked by exact stored hashes, text/page inspection and rendered images. They were not newly generated. Every executable SDK/manifest input matches the immutable preparation SDK source; every executable consumer/project/scheme input matches the accepted preparation hashes. Identical inputs and the same manifest bundle placement justify carrying the earlier aggregate-report evidence into this formal rehearsal; the newly built archive's actual bundle and linkage were independently verified above.

The real one-page report is blank, consistent with the verified empty collected-data declarations. The separate control attributes synthetic Crash Data/App Functionality to the SDK bundle, with tracking and linkage NO, demonstrating that Xcode reads that placement. The synthetic declaration remains only in its disposable control. See [accepted preparation](evidence/F2_CONSUMER_ARCHIVE_PREPARATION_2026-10-31.json) for original report hashes and limits; PDFs remain in ignored local preparation storage.

The consumer starts no request and contains no credential/optional capability. The SDK's selected source/manifest inputs and source-only dependency graph are unchanged. This does not certify a real application's data practices, all binary/transitive API use or App Store acceptance. Apple describes aggregation and the conditional requirements for listed/binary SDKs in its [third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/), checked on 2026-10-31. This rehearsal verifies source SwiftPM integration, not a new binary distribution format.

## SemVer, rights, security and documentation

CHANGELOG remains Unreleased: no stable/prerelease version, tag or release is invented. README, SECURITY and CHANGELOG were corrected where earlier task snapshots still described implemented HTTP/lifecycle/auth/diagnostic work as future work. Historical task-local counts remain explicitly historical. The current DocC integration article was rebuilt and its rendered updated text inspected; symbol extraction produced 319 public records. Compiled Swift examples are unchanged.

LICENSE retains Teisrud Development AS's proprietary notice and no open-source grant. No general confidential contact was fabricated. The documented private GitHub vulnerability channel is verified enabled. No prior release exists to migrate from; compatibility/migration and immutable-tag policy remain in [release policy](../governance/RELEASE_POLICY.md). Existing tags and releases were empty at verification, and this work creates none.

## Acceptance and forward assessment

[Sanitized rehearsal record](evidence/F2_RELEASE_REHEARSAL_2026-10-31.json) retains exact revision, resolved dependency, environment, scalar results, archive/manifest provenance, report custody and private-log hashes. No private device/team/profile identifiers or raw logs are published.

After this PR/main acceptance, close #64, then #27 and F2 only when its milestone has no remaining selected open issues. #132 physical Watch, actual workload/device-memory/security suitability and the explicit #29 publication decision remain separate mandatory gates. The provisional resource advisory is no hard cap or production acceptance. F3 still needs its own scope/start decision.

The concrete quality finding was stale public status text, fixed here. The actual clean install/archive/regression/doc checks established no new product defect or justified refactor, new dependency, duplicate issue, paid environment or added feature.
