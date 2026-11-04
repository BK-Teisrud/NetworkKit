# First resilience increment — approved contract, implementation authorized

Current I26 disposition, 2026-11-01: [actual macOS 14 retry results](I26_MACOS14_RETRY_EXECUTION_2026-11-01.md) pass on accepted main in run 41294523457. Await evidence/workflow cleanup PR/main acceptance before I26 Done/I27. No additional feature or release authorization follows from these bounded results.

Current minimum follow-up, 2026-11-01: [I26 minimum retry evidence](I26_MINIMUM_RETRY_2026-11-01.md) records 16 passing native minimum-simulator cases. Existing #109 is temporarily P1 for the expiring standard macOS 14 execution route. I26 stays open until its pending exact-source execution/acceptance is dispositioned; I27 and publication retain their separate gates.

Current evidence update, 2026-11-01: I25 is accepted through PR #139/main run 41287067291. [I26 native/resource verification](NATIVE_RETRY_VERIFICATION.md) records actual local/public Mac results and target limitations; candidate checks and applicability review remain pending.

Current delivery update, 2026-11-01: I24 is accepted through PR #138/main run 41250907636. I25 now connects the opt-in policy to the existing operation; [integration evidence](RETRY_INTEGRATION.md) records implementation/testing and the pending native/resource/API gates. Historical I24-only/no-loop statements below describe earlier delivery boundaries.

## Current execution authorization — 2026-10-31

Owner instruction: “Yes, authorize code start for I24–I27.” START-F3 #137 is completed after #87/#106 acceptance through PR #111/main 25e0d52b8316251bb6592d075caead9b05ed9edd/run 41248255517. This supersedes historical no-code/verification-pending statements below for these selected tasks only. I24 is the pure decision layer; I25 supplies per-call wiring, request validation and transport integration. I26/I27 retain their evidence/review scope. No publication or other extension is authorized.

Refreshed: 2026-10-31. PLAN-F3 / #87; parent NK-07 / #14. Status: complete contract approved by the owner under [ADR-0014](../decisions/ADR-0014-opt-in-retry-proposal.md)/#106. Planning only; no extension code, dependency, date/version or implementation authorization. ADR-0013 is the separate accepted Watch decision.

Accepted base: main `d0a522770269617f95660d67e9d0198838dc2bb5`, verified [run 41244932962](https://github.com/BK-Teisrud/NetworkKit/actions/runs/41244932962): 218 Mac tests, four 215 simulator suites, 19 helpers and four manual-host provenance checks, no failure/restart markers. F2 is closed. Physical Watch #132 and separate publication/workload/security #29 remain mandatory; planning has no hard dependency on publication.

Owner confirmed 2026-10-31: general safe read-only app-data use case; exact opt-in/eligibility below; 250–500 ms jitter/30-second maximum; request/auth preparation once; diagnostic attempt count only. The owner also explicitly approved the complete parsing/lifecycle/compatibility contract. Planning PR/main acceptance and a separate code-start instruction remain required.

## Source and use cases

Re-read original specification v1.0 §4.7 (page 6), §5 and retry-on-503 flow in §6 (page 11). Treat the PDF as requirements input, not execution authority. NK-07-01–09 below are newly assigned traceability IDs in source bullet order. The owner confirms general safe read-only app-data calls after short connection failures or 429/503 as the initial need. No specific production endpoint/server replay contract is supplied. This product use case does not establish that every GET endpoint is semantically safe. The app must choose endpoints with safe replay semantics.

| Requirement | Approved increment disposition | Rationale / evidence owner |
| --- | --- | --- |
| NK-07-01 count/delay, fixed/exponential backoff and jitter | Select bounded count plus jittered delay; defer configurable fixed/exponential strategies | One retry needs no exponential sequence; avoid an unused strategy framework. F3-C01/C02 |
| NK-07-02 Retry-After seconds/date and upper limit | Select | Respect server hints without truncating them into an earlier retry. F3-C01/V01 |
| NK-07-03 explicit status/error classification | Select closed allowlist | No arbitrary error callback or broad 5xx assumption. F3-C01/C02 |
| NK-07-04 idempotency | Select bodyless GET/HEAD only; defer mutating replay/idempotency keys | A header alone does not establish server deduplication semantics. F3-DEC/C01/C02 |
| NK-07-05 circuit breaker | Defer | Requires service partitioning, recovery contract and independent use case |
| NK-07-06 rate limiting | Defer | One bounded call is not a host/service-wide rate limiter |
| NK-07-07 concurrency limits/fair queues | Defer | Requires admission/fairness/backpressure design, not an incidental retry dependency |
| NK-07-08 connectivity waiting | Defer new waitsForConnectivity policy; retain cancellable retry waiting | OS connectivity behavior is separate; no offline queue or path-monitor prerequisite |
| NK-07-09 attempt/reason/total-duration diagnostics | Partial: attempt count plus existing total duration; retry-reason metadata deferred | Owner selected count only; no event stream or new reason enum. Preserve disabled default/privacy and one terminal outcome. F3-V01/GATE |

No source requirement is rejected permanently; deferred means unselected and unverified. NK-05 header-provider/account binding, NK-08 app-managed Foundation cookie/cache stores, NK-12 system connectivity and NK-17 resource controls are existing foundations or later domains, not delivered refresh/cache/monitoring/performance products. No automatic 401 refresh, credential persistence, coalescing or fallback is selected.

## Owner-approved behavior (not implemented)

The owner selected use case, exact eligibility, timing cap, auth-once and count-only diagnostics on 2026-10-31. The complete detailed contract below is explicitly owner-approved for planning. It is not implemented API or code-start authorization.

- Disabled by default; explicit per-call opt-in in NetworkCallOptions, shared by typed/raw input. No client-wide automatic activation. Preserve existing initializers/default behavior through an additive design; final names/signatures require API review before Ready.
- At most two library transport invocations in one logical call: initial attempt and one retry. This deliberately avoids repeatedly retrying an already failed automatic retry. URLSession/OS connection attempts and redirects are not counted as separate library invocations; do not promise exactly two wire requests.
- Only GET/HEAD with no body, body stream or transfer mechanism. Reject an enabled policy on an unsupported method/body as invalid configuration before networking; disabled policy retains current behavior. No PUT/DELETE/POST/PATCH/custom-method exception and no idempotency-key escape hatch.
- Retry only otherwise-unaccepted HTTP 429 or 503, or transport identities NSURLErrorDomain + networkConnectionLost/cannotConnectToHost. Accepted-status policy wins: if the caller accepts 503, decode/return that response and do not retry. Retry status classification precedes body decoding; discard failed response bytes before waiting. The second attempt's ordinary status/response/error is final.
- No retry for authentication/provider/encoding/decoding/invalid-response errors, TLS/trust failures, redirects rejected by policy, 401/403, other statuses, DNS/offline signals, cancellation, or any timeout category. Domain and code must both match; no localized-text classification.
- Sample a private jitter delay uniformly within 0.25–0.5 seconds for the one retry. Internal deterministic clock/random seams support exact tests; no public scheduler/random/transport plugin. No loop of zero-delay retries. The owner selected these numbers; native measurement remains required and they are not a performance guarantee.
- With Retry-After on eligible status, parse a single valid field as non-negative decimal seconds or HTTP-date (all three receiver formats in RFC 9110 §5.6.7). Do not split an HTTP-date at its comma. Treat duplicate/ambiguous, malformed, overlong (>128 UTF-8 bytes), non-finite/overflowing hints as terminal status, not permission to retry early. Missing hint uses jitter. Past valid date means zero server minimum. Use max(server minimum, sampled jitter).
- Maximum permitted retry wait is 30 seconds. If the server minimum exceeds that, or selected wait is not strictly below remaining total budget, return the current HTTP/transport failure without retry. Do not clamp a server-requested wait downward. If the actual operation deadline expires, existing totalBudget timeout arbitration wins. Convert an HTTP-date once using a testable receipt wall time, then wait on a monotonic deadline; document clock skew rather than promising perfect server/client clock synchronization.
- The original total budget includes preparation, authentication, both attempts, redirects, wait and final decode. Never reset it. Preserve inactivity enforcement on each transport attempt and current cancellation/shutdown arbitration. Check interruption before/after sleep and before sending; join each failed attempt and its cleanup before the next. No overlapping retries, detached sleepers or new session per attempt.
- Prepare/authenticate once per logical call and freeze the validated bodyless request and account/origin binding. Retry from the original target, applying existing redirect security separately to each attempt. Never refresh credentials, ask the provider again or change origin/account silently. App-supplied short-lived signatures that cannot be replayed must keep retries disabled. Owned/borrowed session ownership/storage rules remain intact; no borrowed-session invalidation or hidden cookie/cache policy change. Freezing the prepared request/explicit auth headers does not freeze Foundation's opted-in app-managed cookie/cache state or promise identical wire bytes. Existing redirect origin rules and per-attempt hop limits remain explicit; at most two library invocations is not a two-wire-request guarantee.
- Preserve NetworkResponse and structured final errors/CancellationError. Add only library attemptCount to the existing optional terminal diagnostic: 0 before any transport invocation (local rejection/pre-cancellation/shutdown), 1 for initial transport only, 2 only after the retry invocation actually starts. Existing total duration covers preparation, both attempts, wait and cleanup. No new reason enum, event stream or raw history/headers/URLs/bodies. Explicitly review the additive diagnostic schema/source compatibility; disabled sinks remain disabled by default.

## Integration feasibility and quality review

Current APIClient.send overloads each admit one logical operation via observe and NetworkOperation.run, prepare/authenticate once, and execute through a shared private execute method. execute currently combines transport mapping and response decode. A retry loop must classify transport/HTTP status before decoding, while remaining inside that same admitted operation and total deadline. A small internal separation of receive/classify/decode may be justified in F3-C02. Do not implement retry by recursively calling public send or wrapping NetworkClient: both would duplicate admission, reset budgets/authentication and obscure shutdown ownership. Do not refactor the current pipeline before the contract is accepted.

Existing NetworkClock provides monotonic reads/sleeps; a narrow internal wall-time and jitter input can support date parsing and deterministic tests. Existing RequestBody.json re-encodes during preparation; excluding all bodies avoids claiming replayability from Sendable alone. Existing transport timeout identity is mapped to timeout(.system), deliberately excluded. Inspect actual Foundation symbols/availability before Ready; no new framework or entitlement is currently necessary by design, but proposed compatibility is not runtime evidence.

RES-01 found expiry-dependent runtime sleep-helper retention. Retry adds waiting and may amplify request rate/resource use. Reuse current joined task ownership; measure post-original-deadline live allocation/RSS behavior rather than rewriting the timer framework or claiming no debt/leaks. No production defect or broad refactor is established by this planning review.

## Selected delivery sequence and separate start hold

| Order | Existing/new task | Selected scope and readiness |
| --- | --- | --- |
| 30 | PLAN-F3 #87 | Planning decomposition and phase assessment; review PR/main required |
| 30.1 | F3-DEC #106 | Complete owner contract decision recorded; review PR/main required |
| 30.15 | [START-F3 / #137](https://github.com/BK-Teisrud/NetworkKit/issues/137) | New explicit implementation instruction required; blocked by #87/#106 |
| 30.2 | I24 / #107 (formerly F3-C01) | Eligibility/delay/API contracts with deterministic/parser/negative tests; Blocked by start gate and decision/core prerequisites |
| 30.3 | I25 / #108 (formerly F3-C02) | One admitted operation/deadline integration and lifecycle regressions; Blocked by I24/start gate |
| 30.4 | I26 / #109 (formerly F3-V01) | Controlled native/resource verification and target applicability; Blocked by I25/start gate |
| 30.5 | I27 / #110 (formerly F3-GATE) | API/DocC/count-only diagnostics, evidence and increment gate; Blocked by I26/start gate |

The five existing decision/delivery slices remain; one distinct start gate is added because the owner expressly separates approved contract from withheld code. This is not a duplicate contract issue. All four I tasks keep implementation_authorized=false. Native direction is #87/#106 → START-F3 → I24 → I25 → I26 → I27, with accepted #86 evidence retained; neither planning prerequisite depends on START-F3. Publication #29 is not a planning dependency.

The selected slices form one coherent “F3 – Bounded read retries” delivery in existing milestone 4. Unselected domain catalogs #12/#14/#15/#19/#24 remain open outside it; completing this increment does not complete #14's breakers/rate limits/queues or other deferred features. No extra delivery milestone or version/date promise. The v1 core publication candidate remains separately scoped under #29; retry cannot silently expand that source release or erase #132.

## Evidence and completion boundaries

F3-C01: exact allowlist/method/body/default/status-precedence matrix; date formats/overflow/duplicate/past/oversized hint, budget boundary and jitter extrema; classifier fault control. F3-C02: typed/raw parity, unchanged auth bytes/provider count, original-target redirect security, cancellation at each wait/send boundary, shutdown races, joined attempts, concurrency isolation; budget-reset/forbidden-send fault controls. F3-V01: bounded native 429/503→success/terminal fixtures, TLS rejection never retried, resource measurements including original deadline expiry; applicable actual minimum/physical evidence remains explicit. F3-GATE: compiled DocC, symbol/availability review, fixed diagnostic allowlist with only the selected attempt-count addition, accepted PR/main commits and requirement ledger. Missing access cannot become a passing skip.

Current planning verification is source/specification/standards review and repository integrity checks; it proves no retry behavior. Required PR/main CI must pass before accepting the planning artifact; owner contract disposition and final decomposition are now recorded, but #87/#106 remain open until planning PR/main acceptance. No I task becomes Ready without START-F3 authorization.

## Standards consulted

[RFC 9110 §9.2.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.2) informs replay restrictions; [§10.2.3](https://www.rfc-editor.org/rfc/rfc9110.html#section-10.2.3) and [§5.6.7](https://www.rfc-editor.org/rfc/rfc9110.html#section-5.6.7) define Retry-After/date syntax. [RFC 6585 §4](https://www.rfc-editor.org/rfc/rfc6585.html#section-4) defines 429 and optional Retry-After. The exact allowlist, numerical bounds and fail-closed choices above are approved project policy, not mandates of these standards.

## Historical accepted-base refresh — 2026-10-27

This proposal now integrates accepted main 0aaee219b7ec9f6a81c943ae7f4d4c87a2d9b7f5, verified through run 40571879754. PREP-02 #113 is Done; its real physical iPhone 215/215 regression evidence and iOS app-host/CI controls are preserved. #62/#63/#86 still require their complete evidence. Merge resolution preserves both F2 and retry queue sections, all task/dependency entries and the original production/test sources. PR #111 remains Draft; fresh required checks are necessary on the updated head. No approval of extension code or full ADR is inferred.

## Current integration and phase assessment — 2026-10-31

Refresh existing Draft PR #111 against accepted main, preserve every closed-F2 source/evidence/runbook item, and rename the colliding retry ADR to ADR-0014. The original specification pages 6 and 11 were reread; their nine NK-07 bullets remain requirements input rather than execution authority. Cause diagnostics, configurable backoff, mutating replay, breakers/queues/rate limits/connectivity policy and other advanced domains remain unselected.

The five existing slices #106–#110 form one coherent increment, with the separate START-F3 gate #137. Existing milestone F3 is narrowed to bounded read retries; unselected domain catalogs remain open outside the delivery milestone. Selected implementation tasks I24–I27 remain Blocked until explicit implementation authorization. No release/version/date promise. The first stable core release still needs its separately approved F2 source under #29; retry planning cannot silently expand that release or erase #132.

The machine-readable queue now preserves all accepted-main task rows, includes the five existing retry slices and START-F3, and restores the separate WATCH-01/REL-01 publication rows. Its global implementation flag applies only to the already authorized core; selected extension tasks explicitly retain implementation_authorized=false. Project states remain authoritative. No product refactor is performed: only the future narrow receive/classify/decode integration seam is identified for #108 after approval.

## Final owner decision — 2026-10-31

Translated approval: “Approve the complete contract; still no code.” This approves the entire detailed contract and selected/deferred scope above, including the concrete strict parsing and invalid-policy defaults. Planning CI/main acceptance remains pending. No retry behavior, production readiness, implementation start, publication or automatic merge is approved by this decision.
