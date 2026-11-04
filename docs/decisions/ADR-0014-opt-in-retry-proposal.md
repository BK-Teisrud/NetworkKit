# ADR-0014: Bounded per-call read-retry contract

Date: 2026-10-31 (refresh of the 2026-10-27 proposal)
Status: Accepted contract/planning and explicit I24–I27 implementation authorization; I24–I26 completed; I27 technical gate/owner limitations accepted through PR #143/main run 41299838862; formal phase closeout tracked in #110. Earlier no-code decisions below retain their original dated scope.
Owner: @BK-Teisrud
Issue / requirement: PLAN-F3 #87, NK-07 #14 / specification §4.7

## Context and problem

The owner selected retry/robustness as the first post-core planning priority. The accepted v1 contract prohibits library retries; F2 is closed and its final documentation main d0a522770269617f95660d67e9d0198838dc2bb5 / run 41244932962 is verified. Physical Watch #132 and publication/workload/security #29 remain separate blockers. Planning an extension does not change that contract. On 2026-10-27 the owner selected the recommended first boundary: bodyless GET/HEAD, at most one retry, selected connection failures or HTTP 429/503. The owner confirms general safe read-only app-data calls as the initial need; no specific endpoint/server replay contract is supplied. The complete contract is now owner-approved for planning; implementation is explicitly withheld.

## Alternatives

Keep app-owned manual retry; add a general configurable resilience framework; or select one bounded bodyless-read increment. Manual retry stays possible but easily resets budgets/auth/shutdown boundaries. A broad framework couples unrelated auth, caching, queues and circuit breakers without selected use cases. The owner selects the bounded increment; accepted F2 evidence is preserved and implementation still requires its separate start gate.

## Approved contract and rationale

Review [the complete approved contract](../planning/RETRY_INCREMENT_PLAN.md): disabled by default, per-call opt-in, bodyless GET/HEAD only, at most two library attempts, closed status/transport allowlist, bounded jitter/Retry-After, one original total deadline, unchanged account/origin/session security, no retry for cancellation/timeouts/auth/TLS/decode failures. Exclude mutating replay, refresh, offline queues, breakers and cache. Small internal pipeline separation may support status-before-decode classification, without a public retry plugin or clock API.

## Security, privacy, platforms, and compatibility

Keep system trust, redirect guards, provider-once account binding, storage profiles and fixed diagnostic allowlist. Proposed additive API must preserve disabled behavior/source compatibility and undergo actual symbol/minimum-platform review. Keep current platform/toolchain/dependency policy. No automatic feature activation. Any incompatible API change requires a new explicit decision and migration guide; no version/date commitment follows from this proposal.

## Consequences and deferred scope

A retry can duplicate server side effects even on an incorrectly designed GET. The app must opt in only where replay semantics permit it. Native internal attempts are outside the library attempt counter. Waiting adds resource/clock-skew considerations and requires deterministic/native/resource evidence. I24–I27 are now selected delivery slices, not implemented or Ready. F2 remains closed; preserve its accepted core and separate publication gates.

## Owner selections and complete decision boundary

The owner confirmed the following on 2026-10-31 in the Norwegian conversation:

- General safe read-only app-data calls; no special API/provider integration is required for this increment.
- Disabled default; per-call bodyless GET/HEAD opt-in; one retry, only otherwise-unaccepted HTTP 429/503 or NSURLErrorDomain networkConnectionLost/cannotConnectToHost. Accepted status wins. All proposed excluded categories remain excluded.
- Private uniform 250–500 ms jitter, server Retry-After respected up to 30 seconds, no retry if the selected delay cannot fit strictly within the original remaining total budget.
- Prepare explicit request/auth headers once, preserve account/origin and original target; no provider repeat, refresh or hidden 401 retry. One-use signatures must keep retries disabled.
- Add only actual library attempt count to the existing optional terminal diagnostic. No retry-reason field/event stream in this increment; total duration remains existing metadata.

The owner explicitly approved the complete [contract](../planning/RETRY_INCREMENT_PLAN.md), including strict hint parsing/invalid-policy behavior, cancellation/lifecycle/storage and compatibility limits. Translated final reply: “Approve the complete contract; still no code.” The original Norwegian reply remains in the conversation. This is an approval of the plan/contract, not repository verification, implementation or publication.

[START-F3 / #137](https://github.com/BK-Teisrud/NetworkKit/issues/137) is the separate native implementation gate. #87/#106 may complete only after the refreshed planning PR/main acceptance. Selected I24–I27 (#107–#110) remain Blocked with implementation_authorized=false until that gate receives a new explicit owner code-start instruction and its own prerequisites pass. A generic continue request or documentation CI is not code-start approval. #87 does not depend on publishing #29.

Existing F3 is narrowed to “F3 – Bounded read retries” for the coherent selected increment. Open domain catalogs #12/#14/#15/#19/#24 are retained outside the delivery milestone; #14 stays parent of its selected slices but is not completed by them. No new delivery milestone, version/date promise or product framework is created. ADR-0013 remains the accepted Watch publication decision; its text is unchanged.

## Supersedes / superseded by

Amends the future post-core planning boundary of ADR-0007 only for this explicitly selected opt-in increment. The delivered v1/F2 core still has no library retry and is unchanged; implementation remains blocked. Preserve ADR-0003/0005/0006/0007 history and update affected contracts in the selected implementation slices.

## Subsequent explicit implementation instruction — 2026-10-31

After accepted PR #111/main run 41248255517, the owner explicitly authorized code start for I24–I27 under this unchanged contract. START-F3 #137 is completed. Earlier no-code statements above record the prior decision and are superseded only for these four slices. No publication or other extension is authorized.

## Technical-gate disposition — 2026-11-01

The owner explicitly approved only the F3 technical gate with the [I27 limitations](../planning/I27_RETRY_REVIEW_2026-11-01.md). PR #143/main run 41299838862 passes; the [closeout](../planning/F3_CLOSEOUT_2026-11-01.md) records final documentation acceptance requirements and separate #132/#29 barriers. This is not production suitability, release or further extension authorization.
