# Contributing and workflow

The HTTP core has completed F2. The bounded read-retry increment I24–I27 is explicitly authorized under ADR-0014 and START-F3 #137. Selected F4 I29–I32 is authorized under ADR-0015; the owner also authorized combined maintenance #158–#161 before further I31. Other extensions and publication require separate decisions. Teisrud Development AS is the designated rights holder. The project is proprietary; see [LICENSE](LICENSE).

Bug reports and suggestions are welcome. External contributions that change repository content are accepted only after a written contribution agreement with Teisrud Development AS has been agreed. A pull request or sign-off does not automatically transfer rights. Do not submit external code contributions before this is resolved. GitHub's applicable terms continue to govern public activity on the service.

1. Find or create an issue with requirement references, scope, and acceptance criteria.
2. Move eligible work to Ready; specify an owner, milestone, priority, and dependencies.
3. Use a short-lived branch from main: docs/<issue>-<short-name>, chore/<issue>-<short-name>, and, later, feat/, fix/, test/, or refactor/.
4. Open a draft PR early. Keep one purpose per PR. Use neutral issue references when PR and main verification are required. Close issues manually only after actual main acceptance; see PROJECT_MANAGEMENT.md.
5. Update relevant documentation, ADRs, requirements traceability, and the changelog. Record concrete verification and risks.
6. Resolve every review thread. Squash-merge with a descriptive title, such as docs: document platform decisions. Delete the branch after merging.

No direct pushes to main after bootstrap. No develop branch; create a release branch only for a documented maintenance need. There is no daily-activity requirement or automatic closure of old issues.

## Definition of Ready

The problem, scope and exclusions, requirement IDs, testable criteria, dependencies, and estimate are understood. No blocking architecture decision remains open. Security and platform implications have been assessed. Implementation requires the applicable explicit authorization: START-00 / #41 for the core, START-F3 / #137 for bounded retry, the recorded I29–I32 owner instruction for selected downloads, or the recorded combined #158–#161 maintenance instruction.

## Definition of Done

Acceptance criteria are met, relevant checks are documented, the PR is merged, documentation/risks/ADRs are updated, and the issue is closed. Product work must also satisfy QUALITY.md. Planned tests never count as passed tests.

Do not include tokens, cookies, real customer data, private URLs, raw request/response dumps, or personal information in public issues or fixtures. Use synthetic examples.

## Language

Use English for all GitHub documentation, issues, PRs, comments, and project content. Owner–assistant conversations remain in Norwegian. See [LANGUAGE_POLICY.md](docs/governance/LANGUAGE_POLICY.md).

## System API and privacy review

In the same PR that introduces or changes Apple system API use, assess required-reason API categories, data collection/tracking and the bundled SDK privacy manifest. Record the API/category/reason and evidence, or an explicit no-impact rationale. Add/update the resource validation with the behavior change; do not postpone declaration work to a later phase. Before distribution, review the actual integrated consumer/archive artifact under the applicable gate. Historical manifest reports do not verify a new artifact. Tests and documentation alone are not a production privacy guarantee.
