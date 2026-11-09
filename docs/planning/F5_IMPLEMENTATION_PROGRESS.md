# F5 combined implementation progress

Status: implementation candidate; not technically accepted or merged.
Owner authorized I33–I36 / #171–#174 as one combined implementation PR on 2026-11-08. No publication, signing or device installation is authorized by that decision.

## Candidate and evidence

- Separate WebSockets source folder; HTTP implementation and package dependencies remain unchanged.
- Owned Foundation adapter, actor lifecycle, validated values, bounded operation deadlines and explicit authentication binding.
- Deterministic tests cover cancellation, late callbacks, concurrent operations, shared close completion, header/subprotocol validation and safe adapter policy.
- Full Mac regression: 306 tests in 37 suites passed, including 37 WebSocket tests in four suites; warnings treated as errors.
- The expanded concurrent-close test exposed a lost-continuation defect. Shared completion now retains and resumes every waiter; the regression passes.
- Ordinary-import cleanup example compiles and is checked against the published guide.
- Repository integrity/helper checks and explicitly curated DocC guides pass with warnings as errors.
- Device host membership is synchronized; this is not device execution evidence.

These checks do not establish native WebSocket handshake, framing, TLS, resource or platform behavior. I35 and I36 remain incomplete. No issue is closed on deterministic evidence alone.

## Approved Mac public verification — completed 2026-11-09

`WebSocketPublicChecks` is opt-in. The owner approved and one Mac invocation executed only this suite using `NETWORKKIT_F5_PUBLIC_WSS=approved-mac-three` and `--filter WebSocketPublicChecks` in the PublicHTTPSChecks package.

Maximum three application-initiated connect calls, sequentially and without retry:

1. `wss://echo.websocket.org/`: one initial empty text frame expected under the provider's hostname-suppression header, then exact synthetic text and five-byte binary echoes; explicit close. Messages limited to 4096 bytes, connect/send/close budgets 10/10/2 seconds and receive watchdog 10 seconds.
2. `wss://self-signed.badssl.com/`: require a native certificate-related rejection.
3. `wss://wrong.host.badssl.com/`: require a native certificate-related rejection.

No credentials, private payloads, account, dependency, certificate/trust installation, payment, device installation or signing. Foundation may perform native connection work internally; the budget counts SDK connect calls. A timeout, DNS failure or non-TLS handshake failure is inconclusive, not accepted certificate evidence. Public service observations supplement later controlled/native/platform checks and cannot close F5 alone.

All three tests passed in 10.828 seconds on macOS 15.8.1 (24H32), x86_64. The three-call authorization is now exhausted. Evidence and retained log: `evidence/F5_MAC_PUBLIC_WSS_2026-11-09.json` and adjacent `.log`. Exact individual TLS codes were not separately logged; both passed the certificate-code allowlist assertion. Prior #168 experiment budgets remain consumed and are not reused.

## Remaining internal order

1. Mac public WSS verification completed within its three-call authorization; retain the passing results without reusing the budget.
2. Complete controlled native lifecycle/framing/resource and selected platform evidence; request any additional execution scope explicitly.
3. Reconcile the implementation against the accepted exact API contract and revise backlog if findings require it.
4. Complete I36 review and explicit residual-risk disposition, then required PR/main checks before ordered issue/milestone closure.

The single-PR grouping does not remove these evidence gates. Deferred features and #29/#132 publication barriers remain unchanged. The protected untracked role-based review is outside this change.

## Controlled/platform preparation — 2026-11-09

Eleven opt-in local tests (18 SDK connects per route) compile with warnings as errors on Mac and iOS/tvOS simulator hosts. No local test or new simulator public test has run. The bounded proposed seven-route cohort is specified in `F5_NATIVE_VERIFICATION_SCOPE.md`; build-only provenance is in `evidence/F5_NATIVE_PREPARATION_2026-11-09.json`. Simulator test-run files select only the two WebSocket suites, disable in-process parallelization and preserve the original environment. Their legacy environment opt-in strings do not establish the actual route; record each destination/runtime from result evidence. Execution requires explicit approval of this new cohort.

## Approved cohort started — 2026-11-09

Owner approved the complete seven-route cohort. Mac consumed all 18 local calls: nine tests passed; oversize and application-close tests failed with generic transport errors rather than the selected structured categories. No Mac rerun. Retained evidence: `evidence/F5_MAC_NATIVE_2026-11-09.json`. The first simulator route adds safe transport domain/code retention to diagnose the remaining authorized observations; no arbitrary error text or userInfo is logged. I35 and I36 stay blocked on these findings and remaining evidence.

## Corrected candidate evidence — 2026-11-09

38 deterministic WebSocket tests pass after native POSIX EMSGSIZE mapping and task-close snapshot retention. All 14 iPad 18.2 simulator tests pass on the corrected candidate (11 local + 3 public; 18 local/3 public calls), including normal/application close, oversize and TLS-layer rejection. Evidence: `evidence/F5_IPAD18_NATIVE_2026-11-09.json`. This does not erase the initial Mac/iPhone failures or authorize reruns there. Remaining approved routes continue sequentially.
