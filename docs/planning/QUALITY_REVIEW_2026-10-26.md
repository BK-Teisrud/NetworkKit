# Quality and maintainability review — 2026-10-26

Task: [QA-01 / #97](https://github.com/BK-Teisrud/NetworkKit/issues/97). Owner requested a comprehensive current-state review and ongoing quality/refactoring assessment. Baseline: `21a204191eaa82a60ec88bf9f60ef57f5f054920`, accepted BUG-01/I18 follow-up main run 40390885712. This review is bounded engineering analysis and concrete corrections, not a guarantee of zero defects/debt or the final I19 security/privacy acceptance.

## Scope and method

Reviewed production source responsibilities and call flow; public versus internal boundaries; URL/header/body/response validation; authentication/diagnostic data flow; terminal arbitration, locking and task cleanup; session ownership; test seams/fixtures/adversarial cases; CI driver/workflow/helper tests; public guides and current versus historical planning state. Used actual references and call sites, source/SDK-derived constraints retained by I18, local full-suite execution, a production-guard mutation and fail-closed CI regression cases. No external dependency, paid service or speculative feature is needed for these changes.

The production implementation remains small files with bounded responsibilities: request construction/security, response interpretation, operation/lifecycle, transport and app-owned provider/sink boundaries. File length is an inspection aid, not a quality score. A short unsafe abstraction would not be an improvement over explicit code.

## Findings and corrections

| ID | Finding / evidence | Decision and result |
| --- | --- | --- |
| Q01 | RequestURLBuilder.validatedURL had no production call sites, only URL tests. It duplicated scheme/host/effective-port checks and mapped policy errors differently from the running RequestBuilder/NetworkSecurityPolicy path | Remove the legacy internal function and its stale future-stage commentary. Existing URL tests now call actual RequestBuilder preparation, retain all adversarial inputs, and assert current precise invalidURL/insecureTransport/unpermittedOrigin reasons. The HTTP default-port success case uses explicitly permitted localhost instead of implying production remote HTTP is allowed |
| Q02 | The migrated URL tests previously could not prove their assertions exercised the running origin gate | Fresh isolated mutation removed only the real NetworkSecurityPolicy origin permission guard. The targeted 14-case test built and failed exactly two assertions: foreign host and changed port were wrongly accepted. The repository source guard is unchanged; no other security case is weakened |
| Q03 | Documentation-example drift checking counted only exact lowercase triple-backtick Swift fences. Five untracked variants passed the old checker: metadata suffix, tilde fence, longer backtick fence, indentation and mixed case | Demonstrate the old acceptance, then conservatively detect all those openings and require canonical tracked blocks. Expand the existing fail-closed helper regression; no Markdown framework/dependency or new parsing subsystem |
| Q04 | The quality-governance page still presented I03–I09 outstanding implementation as current; current roadmap/project notes also reflected the failed I18 main/P0 blocker after accepted follow-up evidence became available | Label foundation-only evidence as historical and link the current baseline. Reconcile #95 and #59 acceptance, preserve failed-run history and root-cause uncertainty, move current focus to QA-01, and keep I19 blocked by this new owner-requested quality review |
| Q05 | Continuous backlog maintenance was documented, but the new owner instruction also requires routine quality/debt assessment | Add explicit before/after-task quality assessment to PROJECT_MANAGEMENT.md: fix concrete defects/duplication, record material decisions and verify behavior; do not create empty refactoring tickets or introduce abstractions merely to reduce repetition |

The production diff removes unused internal code; it does not change an executed client path or public API. Tests now supply stronger evidence for the actual path. CI handling becomes stricter only for unsupported/untracked documentation syntax. Exact published examples remain canonical and compiled.

## Architecture decisions retained deliberately

| Area | Review conclusion / why no broad refactor |
| --- | --- |
| Public API and packaging | Retain the single library module and selected 28 top-level API declarations reviewed by I18. No new public transport/clock/plugin/testing product, singleton, module split or compatibility-breaking rename is justified |
| Typed/raw entry points | Retain their short explicit entry/preparation paths. The typed endpoint's app-defined options/response strategy have deliberate access/cancellation/budget timing. A generic closure-heavy orchestration layer to remove a few lines could obscure those boundaries. Shared auth, transport, response and terminal/lifecycle policy already exist |
| Terminal/lifecycle state | Keep the small synchronized state machines separate: one chooses each call's terminal result, another owns admission/shutdown. Callbacks and continuations resume outside locks; no network/await runs under those locks. Do not merge them into a general scheduler or detach cleanup |
| Codecs and prepared values | Retain operation-owned encoders/decoders and immutable settings. Encoding and decoding have intentionally different native strategies; a generic factory/protocol hierarchy would add coupling without a demonstrated defect |
| Native fixtures | Retain one bounded child-process helper shared by storage and redirects, with positive failure-path tests and immediate synthetic phase labels. Do not copy process lifecycle code back into individual fixtures or serialize/suppress native tests to hide failures |
| Test isolation | Keep synchronized UUID-keyed registrations with per-test cleanup and explicit concurrent-operation tests. Do not claim no static state exists or Thread Sanitizer/exhaustive schedule proof. Public consumer tests avoid @testable; internal seams remain test-only |
| Error/privacy boundaries | Retain structured safe identities and a fixed diagnostic allowlist. Never simplify by retaining raw NSError/userInfo, formatting arbitrary callbacks/errors, copying sensitive fields across origins or adding generic request/response logging hooks |
| CI | Retain strict actual toolchain checks, four platform builds/five runtime results, failure/skip/empty rejection, full-SHA official action, read-only credentials, no artifact/cache publishing, two matrix jobs and the final mandatory quality gate. No paid runner, formatter/linter dependency or arbitrary coverage/complexity threshold is justified by this review |

These are deliberate limits on complexity, not a claim that future refactoring will never be useful. Reconsider when a concrete defect, measured cost or repeated change demonstrates a better boundary. Do not repeatedly rewrite stable code to make a review appear productive.

## Actual verification

- Local `swift test --parallel -Xswiftc -warnings-as-errors`: **216 tests / 26 suites passed** on macOS 15.8.1 / 24H32 x86_64, Xcode 26.3 / 17C529, Swift 6.2.4. Native storage/redirect phases and the two child-lifecycle tests completed.
- Isolated production-origin mutation: target compiled, then failed exactly two assertions in invalidRequestsUseSameValidation (14 cases). Removing the old helper is not merely testing a replacement test helper.
- CI drift negative cases: five noncanonical/untracked openings reproduced old acceptance and are rejected by the corrected checker. Existing changed/missing/duplicate/untracked canonical cases also remain covered.
- Local DocC/public graph extraction passed with warnings as errors. Final source-integrity and hosted PR/main outcomes belong to #97 and its PR; pending results must not be presumed from earlier runs. Test declaration counts/public names are unchanged, so dated inventory counts remain explicit rather than rewritten as new runtime claims.

## Remaining risks and plan

The accepted BUG-01 PR/main evidence has no timeout/process restart and records complete native phases. This verifies bounded helper remediation; it does not establish the precise original Foundation/OS/test-runner stall cause. R10 remains monitored under testing epic #23 and final reconciliation #86. Any recurrence requires phase-based investigation and a bounded issue, not a blind rerun or weakened assertion.

I19 #60 still owns the full security/privacy/threat/manifest/native-trust assessment. #61 owns reproducible resource/memory measurements and justified limits; buffered responses still have documented memory costs. #62/#63 own actual minimum-runtime and physical-device evidence with unknown access/inventory. #86/#64/#29 own final domain acceptance, rehearsal and publication. Passing this review must not close those gaps.

QA-01 is P1, Order 18.75, before I19. It depends on the accepted start gate and I18, and I19 depends on QA-01; parent #27 is traceability rather than a closure prerequisite. No cycle, duplicate debt issue, new milestone or product-scope expansion is needed. Both corrections fit this single bounded quality slice. The owner's retry-first future planning direction remains unchanged.

During future tasks, continuously inspect touched code and nearby boundaries; correct clear issues within approved scope and keep the plan aligned. Material API/behavior/platform/security/cost decisions still receive an explicit impact assessment. Small reversible internal quality fixes do not need repeated permission. Maximum five concurrent work processes and dependency/overlap/CI-capacity checks remain in force; do not wait/poll on GitHub when useful independent progress is exhausted.
