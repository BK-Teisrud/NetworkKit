# GitHub configuration

Repository: BK-Teisrud/NetworkKit. This document defines the intended configuration; [setup status](SETUP_STATUS.md) records what is active and verified. JSON files under .github/settings and .github/rulesets are versioned configuration baselines, not automatic GitHub synchronization.

## General settings

| Setting | Choice and rationale |
| --- | --- |
| Visibility / owner | Public / BK-Teisrud, explicitly selected by the owner |
| Default branch | main |
| Issues / Projects | Enabled for tasks and delivery tracking |
| Wiki / Discussions | Disabled; Git documentation and issues provide one source of truth |
| Merge | Squash only; PR title/body form the commit message |
| Branch cleanup / update | Delete after merge; branch updates allowed |
| Auto-merge | Disabled; merges remain deliberate after required checks |
| Web sign-off | Disabled with explicit owner approval; no DCO agreement selected |
| Template repository / Pages / deployment | Not enabled; no website or distribution at this stage |
| Topics | swift, networking, apple, swift-package-manager, urlsession, swift-concurrency |

## Main rule: main-protection-solo

Active on the default branch: no deletion or force-push, linear history, required PRs, all review threads resolved, squash only. Zero mandatory approvals in the solo profile. Dismiss stale approvals if present. No bypass actors; admins also follow PR rules, while retaining authority to administer the rules themselves. The required quality-gate is bound to the verified GitHub Actions integration (15368), requires the current base, and aggregates every mandatory platform/source/DocC result. It was introduced only after successful real PR and main evidence; see [CI verification](../planning/CI_IMPLEMENTATION.md). Manual review and release checks remain necessary.

Team transition: require another qualified write user/CODEOWNER before enabling one approval, Code Owner review, and approval of the latest push by another person. Do not lock out the sole maintainer.

## Release tags and immutable releases

Two active rules apply to refs/tags/v*: release-tags-authorized-creation (25432767) restricts creation with an admin exception for creation only; release-tags-no-rewrite (25428391) blocks update/deletion without bypass. All matching rules apply together. Published releases are immutable; validate drafts before publication. No tags/releases are created now. Admins can still change settings; this is not absolute protection against the account owner.

## Security

Enable dependency graph and Dependabot alerts where applicable. Enable secret scanning and push protection where supported, plus private vulnerability reporting. No Dependabot version-update file without manifests; security updates cannot meaningfully protect a product before packages/dependencies exist. Assess code scanning/CodeQL against the tool/language matrix after implementation; it is not configured now.

Actions: read-only GITHUB_TOKEN, no PR creation/approval permission, and only local/GitHub-owned actions as a preparatory restriction. I06 adds one real CI workflow on standard GitHub-hosted runners; see [implementation and evidence](../planning/CI_IMPLEMENTATION.md). Full commit-SHA pinning is required through sha_pinning_required=true, read back on 2026-10-19. DEC-07 / ADR-0008 defines the CI contract; no external reusable workflows or third-party setup actions. No self-hosted runners, secrets, environments, deployments, webhooks, or additional apps have been added.

ADR-0002 names Teisrud Development AS as rights holder and selects proprietary use by separate written permission. The repository remains public under BK-Teisrud. The owner attests that 2FA is enabled; no independent account audit was performed. No contact address is established; see PRE_CODE_READINESS.md. No organization transfer has been selected. Other repositories and organization policies are unchanged.

## Projects and planning

Sixteen custom labels avoid duplicate status tracking; seven milestones have no invented dates. The 30 original issues are supplemented by I01–I23, a start gate, and a verification issue. Decision issues close after acceptance. GitHub holds live status. No automated stale-issue closure. PROJECT_MANAGEMENT.md documents fields/views; GITHUB_REGISTER.md and SETUP_STATUS.md record live entities and verification.

All documentation and editable GitHub content use English under [LANGUAGE_POLICY.md](LANGUAGE_POLICY.md). Owner–assistant conversations remain in Norwegian.

## Maintaining the setup

Quarterly and when maintainers change, read back settings/rulesets, access, Actions policy, Security, milestones, and project configuration. Changes go through PRs followed by API/UI verification; on-disk JSON alone does not prove enforcement. Recheck the ~DEFAULT_BRANCH rule before changing the default branch.

## Official sources reviewed during setup

- [Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository)
- [Available rules and bypasses](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [GitHub Projects views](https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/managing-your-views)
- [CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)

Public repositories support rulesets on GitHub Free. A private repository would require a subscription assessment. Check actual feature support against this repository's GitHub responses.
