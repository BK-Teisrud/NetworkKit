# Roadmap

## Current delivery — 2026-11-01

F3 is formally closed: I27 #110 is Done after final PR #144/main b4511c5efe9a349a9f91eb0448974f1bf49b8d3f/run 41302196774; all seven checks passed. [F3 closeout](F3_CLOSEOUT_2026-11-01.md) preserves its bounded technical acceptance and source-specific evidence.

F4 planning/I28, I29 and I30 #148 are Done after accepted PR #156/main run 41333096996. Authorized I31 #149 is In Progress: [native Mac checkpoint](I31_NATIVE_DOWNLOAD_2026-11-04.md) executes real URLSession file transfers, counted redirects/lifecycle/known-path cleanup and finite file/RSS observations. [Minimum native execution](I31_MINIMUM_DOWNLOAD_2026-11-04.md) now passes 24 cases across four existing simulators. FileTimestamp/C617.1 metadata is corrected for fstat; validation/PR/main and remaining trusted HTTPS/auth/storage/other-current/physical/macOS14 evidence are outstanding. I32 #150 stays predecessor-blocked. No new signing/device installation, purchase or publication is authorized.

#14 advanced resilience remains Backlog; #89/#90 remain independent planning. #29 actual app/workload/security/publication and physical Watch #132 remain mandatory separate barriers. No new milestone/date or publication authorization follows.

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

Deferred beyond v1. PLAN-F5 / #89 defines the selected WebSocket lifecycle, backpressure/authentication/shutdown contract and fixtures. Base connection and optional reconnect can become separate deliveries; file transfers are not an automatic dependency.

## F6 – Specialized features and research

Research candidates only. PLAN-F6 / #90 ranks actual product needs and sets bounded feasibility and stop/go criteria. Split unrelated security/networking delivery milestones only after evidence and a scope decision.

## Dependencies and approval

Endpoint contracts precede interceptors/authentication/retry. Error taxonomy and response wrappers precede API stabilization. Cancellation/clocks precede retry/refresh. Redaction precedes detailed diagnostics. OS matrices/entitlements precede background/Bonjour/multicast. Security review precedes pinning/mTLS/OIDC.

Break domain epics into separate testable tasks before Ready. F0 acceptance covers included/deferred CORE subrequirements. Extensions cannot enter v1 without updated scope and impact assessment. Close phase gates only with links to actual evidence.

## Historical public HTTPS route — 2026-10-27

[NET-01 #115](https://github.com/BK-Teisrud/SwiftNetworkKit/issues/115), Order 20.95, uses owner-selected [public native HTTPS checks](PUBLIC_HTTPS_VERIFICATION.md) through the existing client/host. No paid/private test environment is provisioned. Public observations, independent certificate conditions and platform-specific error mapping remain distinct from controlled server counters, minimum/other-device/resource and final release evidence. #62/#63/#86 stay open for their remaining criteria.

## Historical native lifecycle/storage follow-up — 2026-10-28

NET-01 #115 is accepted on main 40644612904. [NET-02 #117](NATIVE_LIFECYCLE_STORAGE.md) adds actual Mac/iPhone cancellation, shutdown/session ownership and isolated cookie observations; local full suite 12/12 passed and PR #118/main 40745209513 are accepted. [Minimum-runtime candidates and authorization](MINIMUM_RUNTIME_ACCESS_2026-10-28.md) remain a separate #62 route: authenticated imports and [four minimum simulator regression results](MINIMUM_RUNTIME_EXECUTION_2026-10-28.md) passed locally at 215/215 each; PR/main acceptance remains pending. Earlier iOS migration timeouts are retained. macOS 14 and separate native/resource scenarios remain open. All unproved F2/native/resource/archive/release criteria remain open.

## Historical F3 refresh before complete approval — 2026-10-31

With F2 closed and main run 41244932962 accepted, #87/#106 now refine [the existing retry proposal](RETRY_INCREMENT_PLAN.md). Proposed ADR-0014 replaces only the draft's colliding identifier; accepted ADR-0013 remains the Watch decision. Owner choices narrow the initial increment and keep reason metadata/advanced resilience products deferred. #107–#110 remain Backlog until complete scope and explicit code-start approval. No new milestone, version/date or implicit dependency on publishing #29.
