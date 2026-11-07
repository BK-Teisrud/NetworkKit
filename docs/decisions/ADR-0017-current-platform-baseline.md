# ADR-0017: Current Apple platform baseline for F4

Date: 2026-11-04. Status: Selected under explicit owner-delegated minimum-OS authority.

## Authority and decision

The owner explicitly delegated choosing appropriate newer minimum OS requirements when the old test environments are difficult or expensive/heavy to maintain. Select iOS/iPadOS 18.0, macOS 15.0, watchOS 11.0 and tvOS 18.0. This supersedes only ADR-0004's minimum library OS values. Keep one NetworkKit module, Swift tools 6.2/Swift 6 and verified Xcode 26.3/Swift 6.2.4. No new framework, feature, paid runner, OS/tool upgrade or runtime download is required.

Use the coherent 2024 OS generation rather than raising every minimum to 26 solely to match current CI. Locally installed 18.2/18.5 and 11.2/11.5 simulator families provide an accessible older-generation verification route; the standard macos-15 runner plus local macOS 15 provide current macOS-family evidence. Exact patch/architecture execution must be recorded, not inferred for every supported version. Support for iOS/iPadOS 17, macOS 14, watchOS 10 and tvOS 17 is removed from the current candidate. There is no stable release/tag to retrospectively alter.

## Verified environment sources

- [GitHub macOS 14 retirement](https://github.blog/changelog/2026-10-01-github-actions-macos-14-runner-image-retirement/): November 2, 2026; do not revive the expired macOS 14 workflow.
- [Official macos-15 arm64 image](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md): observed November 4, macOS 15.8.2 and Xcode 26.3 available; actual run logs remain authoritative for the candidate.
- [Apple Xcode support](https://developer.apple.com/xcode/system-requirements/): the selected deployment families are within Xcode 26.3's supported ranges. Apple's table lists a different patch compiler label; local/CI actual compiler identity remains the verified 6.2.4 and must not be overwritten from the table.

Availability is not execution proof. Older baseline reports/hashes remain historical and are not relabeled as new-floor candidate passes. Update the package, verification package, active host/tool minima and normative current documentation together. The guarded historical macos14.py route and its original provenance remain retired rather than silently retargeted.

## Verification and scope boundaries

I31 must exercise actual selected native/minimum-family scenarios on the new candidate. I32 must review compiled consumer examples, API compatibility and the updated consumer/privacy artifact. Record exact simulator versus physical/build-only evidence; changing the minimums does not turn missing physical tests into passes or waive unrelated lifecycle/security/resource criteria. Any residual gate disposition remains explicit. #29 actual app/workload/security/publication and #132 physical Watch remain mandatory separate gates.

The owner also replaced the former stop-at-pending-CI rule: continue useful independent/next-branch work without polling, inspect CI at natural checkpoints and before merge, prioritize predecessor failures, and never merge dependent work until predecessor/main and candidate checks pass. Maximum five concurrent work processes remains. No unattended monitor, wait loop, new signing/device installation, account change, purchases, tag or publication is authorized.
