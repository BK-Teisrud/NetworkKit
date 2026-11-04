# ADR-0001: Repository and planning stage

Date: 2026-10-19. Status: Accepted for repository setup.

## Context

The owner requested a complete GitHub setup for the PDF specification, without code, and selected a public repository under BK-Teisrud. Its current name is NetworkKit under the subsequent [unified naming decision](ADR-0016-unified-networkkit-name.md).

## Decision

One repository, main as the default branch, short-lived branches, and squash merges. Issues and milestones are the authoritative backlog, supplemented by GitHub Projects once authorized. Documentation was initially written in Norwegian, retaining technical symbols and established names. ADR-0011 subsequently establishes English for all repository and GitHub content. No product code or workflows are enabled at this stage. Licensing and platform versions were initially unresolved.

The solo profile requires PRs and resolved review threads, but zero mandatory approvals. The initial admin bypass was limited to PRs. Tag rules protect the v* namespace; admins may create release tags. Tighten review requirements when another qualified reviewer is available.

## Consequences

One maintainer can use the setup without a review deadlock. Future CI must exist and have run before checks become mandatory. A public repository without a selected license is visible but is not presented as freely licensed. Product and licensing decisions require separate ADRs.

## Subsequent hardening

ADR-0010 supersedes the original admin-bypass and tag model. Main now has no bypass; tag creation and immutability are enforced separately. ADR-0011 supersedes the original documentation-language choice. Historical decisions remain in Git history.
