# Physical Watch phase-gate decision

Status: Option B approved by the owner on 2026-10-31; implementation/review in progress. This is not a test pass or F2 closure.
Date: 2026-10-31. Owner: @BK-Teisrud. Existing owners: #63, #86, #64 and #29.

## Verified position

TV transition evidence is accepted through PR #131, main c9e36d88e1402f3ac9d9a5ed44b7edcb01621b6c and run 41234106849. Full logs verified 218 Mac tests, four simulator runs of 215, 19 helpers and four manual-host provenance checks without failure/restart markers. Mac, iPhone/iPad and #62 minimum-family evidence retain their accepted recorded limits.

Physical Apple Watch Ultra 2 / watchOS 27.2 remains unexecuted. Developer Mode is enabled, but mounting Apple's developer image fails with CoreDevice 12040 / MobileDevice 0xe8000076, preceded by personalization-manifest error 0xe8003ffe. Reboots, existing pairing refresh and non-clean refresh of existing Apple image candidates did not establish a working route. Existing signed root artefacts have verified profiles and signer. Minimum Watch simulator evidence is separate and is not physical-device evidence.

Read-only Xcode Components inspection offers a 100.9 MB Device Support update, build 17C7003i, described as support for iPhone 17e and iPad Air M4 models. No Watch fix is documented by that description. It was not installed. No latest-SDK requirement, inevitable incompatibility or definitive image-corruption cause is inferred from these observations.

## Option A: retain the existing F2 gate (not selected)

Keep #63 and F2 open until a supported physical Watch development route becomes available and the relevant tests pass. Finish independent reconciliation/rehearsal preparation without claiming formal acceptance of unmet criteria. No support, dependency or milestone requirement changes. A new Mac/toolchain, purchase, upgrade, support request or diagnostic upload requires its own concrete scope/authorization where applicable.

## Option B: explicit phase-gate change, preserving the release blocker (approved)

The owner expressly approved the following bounded phase change:

1. Defer the unexecuted physical Watch regression, native public HTTPS, applicable lifecycle/storage/transition scenarios and target resource observations from F2 acceptance to the pre-publication gate. Keep watchOS 10 support and product/toolchain minima unchanged.
2. Create one bounded WATCH-01 follow-up for those exact missing results. It must block #29 through native dependencies and the release checklist. Physical Watch evidence must pass, or the owner must make a separate explicit product-support/risk decision, before publication. It is never silently waived.
3. Revise #63 acceptance to the completed non-Watch evidence and explicitly selected deferral. Preserve all historical failed/preparation observations. Close #63 only after the evidence and scope change are accepted; never mark physical Watch execution passed.
4. Update #86's requirement mapping and #64's dependencies together so the documented Watch deferral can remain open across a non-publishing F2 rehearsal. Keep #27 and F2 open until all other selected criteria and formal rehearsal pass. Avoid dependency cycles and false closure of original domain epics.
5. Reconcile remaining per-platform applicability and resource limits. Finite RSS observations do not prove universal memory bounds; unknown owner workload is not workload-risk acceptance. #29 retains its explicit owner/publication decision.
6. Record an owner-approved decision, synchronized roadmap/issue scopes, and reviewable PR. No F2 closure follows automatically from this draft. F3 implementation still requires its own approved scope/start decision.

No hardware, subscription, paid test environment, OS/toolchain update, pairing removal, certificate/profile/account change, release or tag is included in either option.

## Owner decision

Translated owner reply: “Approve moving to a mandatory release blocker.” Option B is selected. [WATCH-01 / #132](https://github.com/BK-Teisrud/NetworkKit/issues/132) is a native blocker and sub-issue of #29. #29 and WATCH-01 are tracked in the separate “v1.0 – Publication gate” milestone so F2 can remain non-publishing. No release, F2 closure, support reduction or F3 implementation is approved. See [ADR-0013](../decisions/ADR-0013-watch-publication-gate.md).

## Primary references

- [Apple Xcode system requirements](https://developer.apple.com/xcode/system-requirements/): distinguishes SDKs, deployment targets, device support and host requirements. A newer device OS alone is not the observed root cause.
- [Watch mount diagnosis](evidence/F2_WATCH_MOUNT_DIAGNOSIS_2026-10-31.json): exact recorded local failure and claim limits.
- [TV transition evidence](evidence/F2_TV_MANUAL_TRANSITIONS_2026-10-31.json): accepted source, complete safe report, later Wi-Fi fallback and dedicated-host cleanup.
