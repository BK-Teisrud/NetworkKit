# Releases, versioning, and maintenance

Publish no release, tag, or package without separate release authorization. The package is implemented; v1 release evidence and acceptance remain outstanding.

After implementation authorization, use SemVer: 0.x for explicitly unstable prereleases; 1.0.0 only after the approved core scope and release gate are satisfied. From 1.0, patch means compatible fixes, minor means compatible additions, and major means breaking changes. Tag format: vMAJOR.MINOR.PATCH; prerelease example: v0.1.0-alpha.1.

## Separate F2 and publication gates

[ADR-0013](../decisions/ADR-0013-watch-publication-gate.md) permits only the missing physical Watch evidence to remain open across non-publishing F2 reconciliation/rehearsal. watchOS support remains unchanged; no unexecuted physical case passes. [WATCH-01 / #132](https://github.com/BK-Teisrud/NetworkKit/issues/132) is a mandatory native blocker/sub-issue of #29 in “v1.0 – Publication gate”.

Before publication, obtain accepted physical Watch evidence or a separate explicit owner-approved product-support/risk decision changing the exact unmet requirement. F2 closure, simulator results and signed host builds do not satisfy it. Keep the checklist and native issue relationship in sync; issue dependencies do not by themselves technically prevent a tag/release. All other security, minimum-runtime, owner workload-risk and release authorization requirements remain effective. No release/tag is authorized by this phase change.

## Release procedure

1. Open a dedicated release PR recording scope, verified commit, changelog, API/platform changes, known issues, and migration guidance.
2. Confirm actual passing CI, requirements traceability, rights compliance, and security review. Never dismiss findings merely to ship.
3. Merge to main. The maintainer creates a verifiable annotated/signed tag on the approved commit. Never move tags.
4. Prepare a release draft with explicit notes and SHA. Upload and verify any assets before publication. Mark prereleases accordingly. Immutable releases are enabled: publication locks the release tag and associated assets. Obtain separate actual release authorization before publication; no automatic publication now.
5. Verify that the future SPM product resolves/builds from the tag and documentation points to the correct version.

Correct faulty releases with a new patch/tag. Clearly identify affected releases; do not rewrite published history. Handle vulnerabilities under SECURITY.md and an advisory where appropriate.

## Compatibility

From 1.0, higher minimum OS versions, incompatible public API/Sendable/error changes, or removal of documented behavior are breaking. Document deprecations with replacements; planned removal occurs no earlier than the next major, except documented security measures. The latest stable minor of the current major receives ordinary fixes. Older majors require explicit support decisions; do not promise unlimited backports.

## Security and privacy acceptance

Before publication, #86/#29 require explicit owner disposition of the [security/privacy review](../planning/SECURITY_PRIVACY_REVIEW.md) and unresolved evidence. #64 must verify the manifest in the actual consumer/archive, inspect the aggregate privacy report, reconcile app/transitive data practices and listed API use, and retain sanitized results. The bundled-manifest unit test is not distribution acceptance. Native HTTPS and minimum/physical-runtime gaps remain release blockers until their own evidence is recorded.
