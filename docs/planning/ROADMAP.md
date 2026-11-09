# Roadmap

## Current scope — 2026-11-09

F0–F4 are completed within recorded technical limits. F4 I31/I32 completed through PR #163/main f86ddcb5ba7a26d05b370007f70b439d0eff5999/run 42406475143 after all seven checks/full-log review and the explicit bounded owner disposition. #29/#132 retain publication barriers. Upload, progress, resume, background and download retry remain deferred.

PLAN-F5/#89 is completed after accepted exact-contract PR #175/main7c192977d867201288e60532b51d8c8d711b11a1/run42505791505. The owner authorized I33–I36 together in [PR #176](https://github.com/BK-Teisrud/NetworkKit/pull/176). Its final candidate passes 309 Mac tests/37 suites and strict DocC; selected seven-route frame coverage and finite resource evidence are complete, including corrected original failures. All explicit execution budgets are exhausted. Technical owner disposition/current closure is tracked in I36/#174 and Project Status; required final PR/main cannot be inferred from local tests. See [technical review](F5_TECHNICAL_REVIEW_2026-11-09.md). Direct Watch WebSocket, stream/heartbeat/reconnect/background deferrals and HTTP Watch support are unchanged. #165/#168 historical findings remain intact; no new milestone, feature or major refactor is selected.

See [WORK_QUEUE](WORK_QUEUE.md) for current execution order and accepted predecessor evidence, GitHub Project Status for live work state, and the [maintenance plan](ARCHITECTURE_MAINTENANCE_2026-11-04.md) for safeguards. Dated reports and the original allocation below preserve history; their earlier status is not live state. #29 actual app/workload/security/publication and #132 physical Watch retain mandatory separate barriers.

## F0 – Architecture and decisions

Rights, v1 scope, platforms/toolchain, APIs, concurrency, security, and CI were accepted together on 2026-10-19 in [ADR-0009](../decisions/ADR-0009-f0-approval-no-implementation.md). At that time, implementation was not authorized. All eight decision issues are complete. ADR-0010 and PR #65 completed OPS-01 / #30; F0 is closed. The owner subsequently instructed implementation to begin on 2026-10-20; ADR-0012 and closed START-00 / #41 record this separately. I01 starts F1 with the package baseline.

## F1 – HTTP core

The initial HTTP slice is delivered through I01–I10. I11 / #52 records the [F1 contract and evidence review](F1_REVIEW.md), including cumulative real platform CI, typed/raw parity, known limits and phase closure. F1 acceptance requires successful I11 PR/main checks; the issue records the actual outcome. Open domain epics retain their remaining v1 work in F2.

## F2 – Production hardening and v1 gate

Closed after the accepted non-publishing core rehearsal and [final closeout](F2_CLOSEOUT_2026-10-31.md). #27/#64/#86 are Done. The owner approved only the recorded F2 resource disposition and explicit Watch publication deferral; #29/#132 retain their separate mandatory gates. F2 completion creates no tag/release or production suitability.

## F3 – Bounded read retries

The owner-approved bounded technical gate is accepted through PR #143/main run 41299838862. [Final closeout](F3_CLOSEOUT_2026-11-01.md) records I24–I27, source-specific current/minimum/native/resource evidence, preserved original API signatures, two reviewed corrections and explicit residual limits. Formal I27/milestone completion is recorded after final documentation PR/main acceptance. Advanced domain catalogs stay open; no production, version/date or publication promise follows.

## F4 – File transfers

One foreground GET-to-file increment is selected under ADR-0015. #88/I28 are completed after accepted feasibility/design documentation. START-F4 #145 covered I28 only; the owner subsequently explicitly authorized I29–I32, starting with the I29 implementation candidate. Upload, progress, resume, background and download retry remain deferred; no additional milestone is currently justified.

## F5 – Real-time communication

The selected foreground raw-message increment is being implemented in one I33–I36 candidate under ADR-0018 and the exact API contract. Reconnect, event streams, heartbeat scheduling, background continuity and direct Watch WebSockets remain deferred; file transfer is not a dependency. F5 is not yet technically accepted or closed.

## F6 – Specialized features and research

Research candidates only. PLAN-F6 / #90 ranks actual product needs and sets bounded feasibility and stop/go criteria. Split unrelated security/networking delivery milestones only after evidence and a scope decision.

## Dependencies and approval

Endpoint contracts precede interceptors/authentication/retry. Error taxonomy and response wrappers precede API stabilization. Cancellation/clocks precede retry/refresh. Redaction precedes detailed diagnostics. OS matrices/entitlements precede background/Bonjour/multicast. Security review precedes pinning/mTLS/OIDC.

Break domain epics into separate testable tasks before Ready. F0 acceptance covers included/deferred CORE subrequirements. Extensions cannot enter v1 without updated scope and impact assessment. Close phase gates only with links to actual evidence.

## Historical public HTTPS route — 2026-10-27

[NET-01 #115](https://github.com/BK-Teisrud/NetworkKit/issues/115), Order 20.95, uses owner-selected [public native HTTPS checks](PUBLIC_HTTPS_VERIFICATION.md) through the existing client/host. No paid/private test environment is provisioned. Public observations, independent certificate conditions and platform-specific error mapping remain distinct from controlled server counters, minimum/other-device/resource and final release evidence. #62/#63/#86 stay open for their remaining criteria.

## Historical native lifecycle/storage follow-up — 2026-10-28

NET-01 #115 is accepted on main 40644612904. [NET-02 #117](NATIVE_LIFECYCLE_STORAGE.md) adds actual Mac/iPhone cancellation, shutdown/session ownership and isolated cookie observations; local full suite 12/12 passed and PR #118/main 40745209513 are accepted. [Minimum-runtime candidates and authorization](MINIMUM_RUNTIME_ACCESS_2026-10-28.md) remain a separate #62 route: authenticated imports and [four minimum simulator regression results](MINIMUM_RUNTIME_EXECUTION_2026-10-28.md) passed locally at 215/215 each; PR/main acceptance remains pending. Earlier iOS migration timeouts are retained. macOS 14 and separate native/resource scenarios remain open. All unproved F2/native/resource/archive/release criteria remain open.

## Historical F3 refresh before complete approval — 2026-10-31

With F2 closed and main run 41244932962 accepted, #87/#106 now refine [the existing retry proposal](RETRY_INCREMENT_PLAN.md). Proposed ADR-0014 replaces only the draft's colliding identifier; accepted ADR-0013 remains the Watch decision. Owner choices narrow the initial increment and keep reason metadata/advanced resilience products deferred. #107–#110 remain Backlog until complete scope and explicit code-start approval. No new milestone, version/date or implicit dependency on publishing #29.
