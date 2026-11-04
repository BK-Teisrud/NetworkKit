# ADR-0016: Use NetworkKit consistently

Date: 2026-11-04. Status: Accepted by the owner in conversation.

## Decision

Use NetworkKit for the repository, Swift package, library product, module/import and project branding. The owner explicitly requested replacing the prior repository/package branding throughout documentation and GitHub. This supersedes only the naming distinction in ADR-0001/ADR-0003; ownership, license, support, public API behavior and selected scope remain unchanged.

The canonical repository is https://github.com/BK-Teisrud/NetworkKit. Existing issue, pull request, project and ruleset identities remain. Update editable titles, bodies, comments, links, package consumers and CI scheme expectations. Do not rewrite commit history, source hashes, signed artifacts or GitHub-generated immutable events to erase prior branding. GitHub may retain redirects and generated historical references.

## Evidence and migration boundary

Existing dated reports are historical observations, not reruns of the renamed package. Their link/branding spelling is normalized for navigation; recorded commit and artifact hashes and outcomes remain unchanged. Historical command/path strings in these documents may use the normalized project spelling; the immutable original spelling is available in the recorded source revision and original local artifacts. Do not treat normalized text as a newly executed command or exact historical transcript.

The active workspace directory is managed externally and is not moved during this change. Local path dependencies must identify NetworkKit explicitly where needed, without depending on the checkout folder name. Generated caches and historical artifacts are not authoritative branding or source and are not manually rewritten. The user-owned untracked review receives name-only replacements by explicit permission and remains untracked.

## Verification and delivery

The owner approved this narrow exception while PR #157 execution is pending: rename GitHub metadata and prepare local files/checks, without push, merge or new CI. Local package/schema/example validation must reflect NetworkKit. Repository file changes still require normal PR/main acceptance after the CI stop is released. The source currently on GitHub branches retains its previously accepted contents until that delivery.

Maintenance #158–#161 still precedes further I31. Naming changes do not waive native evidence or #29/#132 publication gates, and create no version, tag or release.
