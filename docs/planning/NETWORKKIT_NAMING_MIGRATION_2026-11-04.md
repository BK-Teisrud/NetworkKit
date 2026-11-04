# NetworkKit naming migration

Date: 2026-11-04. Decision: [ADR-0016](../decisions/ADR-0016-unified-networkkit-name.md).

## Completed metadata and local preparation

Canonical repository: https://github.com/BK-Teisrud/NetworkKit. Repository identity/history, existing issues/PRs and rulesets are retained; origin points to the canonical URL. Project title is NetworkKit Roadmap; its current readme/description records the maintenance-first queue. The linked project repository resolves to the canonical name. Workflow enabled/disabled states and SHA-pinned official Actions policy are retained.

82 editable issue/PR/comment text objects were updated. Read-back across all 161 issues/PRs, 132 issue comments, review comments, milestone text, project branding and PR review text found no prior branding. This does not assert removal from immutable events, Git history, generated logs, redirects or cached external copies. After owner login, the saved Auto-add to project workflow was verified in the GitHub UI: enabled, public repository NetworkKit, filter is:issue, action Add the item to the project. No correction was needed. This verifies saved configuration, not a newly exercised end-to-end import.

Current versioned files and the two existing local planning/review documents contain no prior branding (case-insensitive scan). The protected untracked review received name-only replacement by explicit owner permission and remains untracked. Local directory/caches are not renamed or rewritten. Historical report spelling is normalized as described in ADR-0016; hashes/outcomes remain historical rather than new verification.

## Initial local verification before owner continuation

- Root manifest: NetworkKit; one NetworkKit product/module and existing platform/tools/dependency contract.
- Public native verification package manifest/description: parses; explicit local dependency name resolves regardless of checkout directory identity.
- Xcode package list: NetworkKit scheme is present.
- Native verification package build with tests and warnings as errors: passed (compilation only, not native runtime execution).
- Renamed resource bundle test: PrivacyManifestTests / bundledManifestMatchesReviewedSDKPractices passed, one Swift Testing test; the XCTest wrapper's zero count is not the result count.
- Existing Python helper suite: 22 tests passed, including device-host wiring.
- JSON, local Markdown links and diff whitespace: valid.

No full core/native runtime/platform rerun is claimed. No push, merge, new GitHub execution, signing/device installation, tag or publication occurred. Repository source files on GitHub still require delivery of this prepared migration and normal PR/main verification. In particular, a source checkout under the new repository name must include the dependency/scheme updates before its acceptance is inferred; older queued checks alone cannot accept the unpushed naming migration.

## Next integration

Resume only on the owner's instruction under the normal CI stop rule. Integrate the naming changes and prepared maintenance planning with a reviewable branch/PR, verify the actual candidate, then follow #158 → #159 → #160 → #161 before further I31 #149 and I32 #150. Do not treat this metadata update as I31 acceptance or a release.

## Candidate integration after owner continuation

The owner instructed continuation after the earlier run completed. Run 41882262117 ended with cancelled matrix jobs and an abandoned aggregate; it does not verify this candidate. Local full warnings-as-errors regression passed 267 Swift Testing tests in 32 suites. Source integrity and public symbol graph/DocC checks pass. The renamed generated runner initially entered DocC input through a prefix glob, causing article-resolution errors. Filtering by actual library module identity fixes that naming-specific regression and removes stale generated input; the helper suite now passes 23 tests, including a negative case for a missing library graph. No SDK runtime Swift code changed for this fix.

This follow-up prepares the naming and maintenance plan changes for PR #157. Required PR/main acceptance is still outstanding. I31 stays Blocked by maintenance #158–#161; missing runtime/resource/publication evidence is not waived. No task is marked Done from this local verification.
