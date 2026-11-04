# Setup status and verification

Verified 2026-10-19. [Public repository](https://github.com/BK-Teisrud/NetworkKit), [private project](https://github.com/users/BK-Teisrud/projects/6). These settings were read back from GitHub, not merely proposed in JSON. This section records the 2026-10-19 setup baseline. **For current implementation status, see the update below and ADR-0012.**

| Area | Result and rationale |
| --- | --- |
| Repository | Public, main, Issues/Projects enabled; Wiki/Discussions disabled for one documentation source |
| Merge | Squash only, auto-merge off, branch cleanup/update enabled |
| Web sign-off | Off with explicit owner approval; no DCO selected; LICENSE unchanged |
| Main | Active ruleset 25428389: PRs, resolved threads, linear history, no deletion/force-push; no bypass actors |
| Tag creation | 25432767 restricts refs/tags/v*; admin exception applies only to creation |
| Tag immutability | 25428391 update/deletion without bypass, including admins while the rule remains active |
| Releases | Immutable releases enabled, enforced_by_owner=false; account owner can still change the setting |
| Actions | Read-only token, PR approval disabled, local/GitHub-owned actions, SHA pinning enabled; zero workflows |
| Security | Secret scanning/push protection and private reporting configured; see baseline and repository readback |
| Labels | Sixteen custom type/scope/priority/other labels; five status labels removed from GitHub, templates, and seed |
| Planning | Seven milestones without invented dates; 30 initial issues + 23 implementation tasks + START-00 and verification issue = 55 issues |
| Tasks | I01–I23 (#42–64) have owners, milestones, criteria, parent epics, and native dependencies; all Blocked by #41 |
| Project | Seven statuses, Priority/Scope/Order; eight views including Work Queue and Completed |
| Work queue | Flat table, ascending Order; saved in the UI and verified after reload |
| Automation | Import, subissues, added/closed/reopened, and PR merged enabled; Auto-close and PR linked disabled |
| Account security | Owner confirms 2FA; not independently audited, no credentials collected |
| Contact | No established address or private licensing/contribution process; no invented contact information |
| Test environment | Nine newer simulator runtimes inventoried; no minimum-runtime or product tests verified |
| Language | English documentation and editable GitHub content; Norwegian owner–assistant conversations; ADR-0011 |

## Project workflow functional test

[Setup issue #40](https://github.com/BK-Teisrud/NetworkKit/issues/40) was created without explicit project import. Native automation imported it as Backlog. Setting project status to Done left the issue open, verified by API. It was closed as completed, reopened, and automatically returned to Backlog. Closing it again automatically set Done. All four checks passed. No product/test code was created.

Native subissue relations exist; all 45 expected I01–I23 blocked-by relations were read back, and workflow enabled states were confirmed. PR merged/auto-add subissues have not been separately tested end to end with a product PR. Item closed does not distinguish closure reason: manually set Not Planned for rejected work. Completed filters on reason:completed, preventing false delivery counts. Triage synchronizes Priority/Scope manually.

## Verification baseline

Read back repository settings, effective main rules, all three rulesets, immutable releases, Actions token/policy/workflow count, labels, project views/workflows/fields, and task status. All 23 tasks have Blocked, P1, CORE, and correct numeric Order. Saved ascending queue order and disabled hierarchy were verified after browser reload. Check JSON, YAML, local documentation links, whitespace, and file inventory before documentation PRs.

Configuration baselines live in .github/settings and .github/rulesets. They are versioned snapshots, not automatic synchronization or scripts to run blindly. Historical planning.json is the initial seed, not live status. No active Actions workflows, Swift files, Package.swift, prototypes, tests, tags, or releases are delivered. No product build/test is claimed to pass.

## Completed and outstanding work

F0 planning and repository preparation are complete. PR #65 closed OPS-01 / #30; F0 was then closed with zero open issues. This is not product delivery. [START-00 / #41](https://github.com/BK-Teisrud/NetworkKit/issues/41) in F1 remains open until explicit owner authorization. I01 is the first code task after approval.

[PRE_CODE_READINESS.md](../planning/PRE_CODE_READINESS.md) records outstanding per-task symbol checks, real CI in I06, and minimum-OS/device evidence in I21/I22. Newer device access is owner-reported without exact versions. Missing minimum environments block release; no purchases/upgrades or support changes are approved.

No additional reviewer is required before another actual maintainer exists. No signed-commit requirement before signing setup is agreed. No dummy checks, manifest-free Dependabot configuration, unnecessary third-party tools, secrets, webhooks, apps, runners, paid products, or publication. Main has no bypass, but admins can change rules; no protection against the account owner is guaranteed. The project stays private; dated roadmap bars await actual capacity/date decisions.

## English-language migration

ADR-0011 records the owner's explicit request for English GitHub content and Norwegian conversations. Current documentation, templates, descriptions, milestones, fields/options/views, and editable issue/PR text are translated without changing decisions or identifiers. Original Git history and source-document filenames remain intact. Translation does not approve implementation or publication.

Language migration readback verified all 55 existing issues and 10 previous PR titles/bodies, seven milestones, eight views, and 16 custom label descriptions. Issue IDs/states/closure timestamps/checklists/labels/milestone associations, project option IDs/workflow enabled states, and security rules are preserved. All 23 implementation tasks remain Blocked; #41 remains open. The browser confirms English content and ascending Work Queue order. LICENSE is byte-for-byte unchanged. JSON/YAML, local links, whitespace, and the absence of product code were checked. No repository issue comments existed to translate.

## Implementation update — 2026-10-20

The owner instructed implementation to begin and supplied a default Xcode package. ADR-0012 records the instruction; #41 is closed explicitly. I01 / #42 adapts the starter at the repository root, with package NetworkKit, product/module NetworkKit, tools 6.2, Swift 6 mode, and minimum OS versions 17/14/10/17. See [PACKAGE_BASELINE.md](../planning/PACKAGE_BASELINE.md) for actual smoke checks and limitations. No HTTP behavior, meaningful behavioral tests, CI workflows, or releases are claimed. Earlier preparation/language verification paragraphs above remain dated historical records.

## I02 value-layer update — 2026-10-20

HTTP methods, immutable case-insensitive headers, status codes, responses, explicit empty values, and structured errors are implemented. See [HTTP_VALUES.md](../planning/HTTP_VALUES.md) for 21 passing local tests, the isolated negative control, consumer verification, and limits. No networking, CI workflows, or release is included.

## I03 configuration update — 2026-10-20

Configuration snapshots and internal transport/clock boundaries are implemented. The full local suite passed 29 tests in seven suites; a public consumer and isolated precedence negative control verified the new API. See [configuration evidence](../planning/CONFIGURATION.md). Live networking, enforced budgets, and CI remain later work. I04 / #45 is next.

## I04 endpoint update — 2026-10-20

Typed endpoint/URL construction and shared structural raw-URL checks are implemented. The full local suite passed 44 tests in nine suites; a public consumer and isolated escaping negative control verified the API. See [endpoint evidence](../planning/ENDPOINT_URLS.md). No executing client, HTTPS/redirect enforcement, or CI yet. I05 / #46 is next.

## I05 request encoding update — 2026-10-20

Buffered JSON/Data/UTF-8 construction, header precedence/Content-Type, per-preparation encoders, and typed/raw validation are implemented. The full local suite passed 64 tests in 11 suites; a public consumer and isolated strategy negative control verified the API. See [request evidence](../planning/REQUEST_ENCODING.md), including Foundation raw-input limitations. No executing client or CI yet. I06 / #47 is next.

## I06 real CI and required-check update — 2026-10-20

Bootstrap PR #72 introduced all-platform source/build/test/DocC CI on standard macos-15 arm64 with pinned Xcode 26.3 / Swift 6.2.4 / SDKs 26.2. All seven checks passed on the PR, with 64 product test functions passing on each of five destinations. Main evidence preceded activation of required quality-gate from GitHub Actions (15368), strict/current-base, with no bypass and all earlier rules preserved. See [CI implementation and enforcement evidence](../planning/CI_IMPLEMENTATION.md) and #47 for actual run links and the verification PR. The prior setup/implementation paragraphs remain dated historical records. Minimum-OS/physical-device tests and the executing client remain outstanding.
