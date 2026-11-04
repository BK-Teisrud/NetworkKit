# ADR-0002: Rights holder and proprietary rights policy

Date: 2026-10-19. Status: Accepted by the project owner in conversation.
Decision issue: [DEC-03 / #3](https://github.com/BK-Teisrud/NetworkKit/issues/3).

## Context

The owner selected Teisrud Development AS as the rights holder and stated, in translation, “Use requires permission from Teisrud Development AS.” The repository remains public under BK-Teisrud, as previously decided. Repository account ownership and ownership of the content are separate roles.

## Alternatives

- A permissive open-source license could allow third-party use, including commercial use, without separate permission. Not selected.
- A copyleft license could grant general permission subject to sharing certain changes. Not selected.
- A proprietary policy requiring separate permission gives the company control over third-party use. Explicitly selected by the owner.

## Decision

Teisrud Development AS is identified as the rights holder. No open-source license or general permission for third-party use is granted. Use beyond statutory rights and GitHub's applicable terms requires separate written permission from the company. LICENSE contains the rights notice covering the repository's own content; it is not a complete commercial license agreement.

The repository remains public. The notice does not attempt to revoke rights GitHub grants for viewing and forking through the service. Do not describe the project as open source. Any need for confidential source code requires a separate visibility decision; this decision does not change visibility.

## Contributions and distribution

Bug reports and suggestions are welcome. External contributions changing content are accepted only after a written contribution agreement with the company has been agreed. No transfer of third-party rights is inferred from a PR, CODEOWNERS, or GitHub sign-off. No CLA or standard commercial agreement has been created.

Before external distribution, confirm the applicable permission/agreement, scope, recipient, and conditions. No prices, support commitments, or new contractual terms have been decided. Handle any third-party materials and their rights or terms separately.

## Consequences and verification

Update README, contribution policy, governance, risks, and active decision summaries. DEC-03 may close after merge. At this decision's adoption, other decisions still blocked F0; implementation requires separate authorization.

This records the owner's selected rights holder. It does not constitute an audit of historical employment, commissioning, or assignment agreements.

## Sources

- [GitHub: Licensing a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)
- [GitHub Terms of Service, User-Generated Content](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#d-user-generated-content)

ADR-0001 remains as historical context. This ADR resolves the licensing and rights questions that were open at that time.
