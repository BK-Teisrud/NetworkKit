# F5 handshake and WSS feasibility findings

Date: 2026-11-08. Tracking: #168 / #89. Status: experiment complete with negative/incomplete findings; required experiment PR/main acceptance pending. No production transport, public API, implementation or publication is approved.

## Authority and provenance

The owner approved the connection planning direction and verification plan in PR #167, then separately authorized only #168 code/runtime after accepted main e1845ccb3b31d260d8e1a0915be41a7361c9bb50/run42417330816. See the [approved plan](F5_SECURITY_VERIFICATION_PLAN.md), [contract direction](F5_CONNECTION_CONTRACT_DRAFT.md) and [source-hashed evidence](evidence/F5_HANDSHAKE_SECURITY_2026-11-08.json).

Actual host: physical Intel Mac, macOS15.8.1, Xcode26.3/17C529, Swift6.2.4/SDK26.2. Exactly14 local scenarios (seven per candidate) and8 external application-initiated attempts ran sequentially, with no retries. All22 recorded bounded cleanup and JSON completion, no subprocess harness expiry. This is **not22 security passes**. Native-internal DNS/address/transport attempts are not observable/enforced by this harness; no universal wire-attempt claim.

Build1 failed before execution because the relocated checkout reused a cache with its previous absolute path. Build2 in a fresh scratch directory failed on the newer SDK's additional NWError enum case; the generic unclassified-error branch was corrected without raising OS floors. Builds3/4 passed Swift6 warnings as errors. Final build4 supplied all runtime results. No failed runtime is rerun or erased. Working-tree hashes identify execution; a final commit execution is not asserted.

Thirty production Swift files and the root manifest are byte-identical to accepted plan main. The original #165 probe/driver and its historical evidence remain byte-identical. The tool-only manifest adds a separate executable; no SDK dependency, product/API, host, CI, trust installation, provisioning, signing/device or paid environment changed.

## Local results

Each scenario accepted one original fixture connection. The raw observer reads at most16KiB of synthetic header bytes and emits only fixed400/302 responses. Native framing handles the protocol-selection cases. Host/request predicates are not general HTTP parsing or wire instrumentation.

| Scenario | Network candidate | Foundation candidate | Interpretation |
| --- | --- | --- | --- |
| Request-target/Host/header | Target and synthetic header matched; Host predicate failed;10s open wait expired | Exact target, Host and synthetic header predicates matched; native-1011 rejection | Network actual Host value was not retained, so omission/format/native/fixture cause is unresolved. Do not invent a defect explanation. |
| Matching selected protocol | Opened with expected selected metadata, offered protocol/header observed | Opened with expected selected protocol delegate value, offered protocol/header observed | Positive selected-protocol observation for this runtime. |
| Missing selected protocol | Opened without a selected protocol | Opened without a selected protocol | Both require an explicit app/SDK guard if configured subprotocol agreement is mandatory; native opening alone is insufficient. This is not a claim that optional subprotocol omission violates WebSocket itself. |
| Mismatched selected protocol | No open inside10s; no captured terminal error | Native-1011 rejection | Network attribution incomplete; a timeout is not an observed native protocol rejection. |
| Fixed400 rejection | No open, fixed request observed;10s wait expired | Native-1011 rejection | Network narrow no-open predicate true, not a prompt-error or SDK deadline guarantee. |
| Redirect to separate origin | Zero target contacts in bounded window;10s wait expired | One redirect callback denied, native-1011 rejection, zero target contacts | No automatic follow observed. Network prompt rejection/diagnostic behavior remains unresolved. |
| Opening cancellation | Connection accepted, cancellation completed, no late open observed in bounded window | Same bounded observation | Not an async provider/late-callback/race proof. |

Ten of14 local narrow policy predicates evaluated true. Negative predicates and timeout outcomes remain in the evidence. Some raw result labels say native-rejected/fixed-rejection; underlying openWaitExpired/error flags above determine what was actually observed. No timeout is relabeled a proven rejection.

## External results

Fixed allowlist: Postman raw echo and BadSSL sha256/self-signed/wrong-host. Only the two echo attempts sent application data: synthetic ASCII text20 bytes and binary4 bytes; no actual auth/cookies/private query/app data. No load, oversize, alternate-host or repeat traffic. The authorized budget is consumed.

| External observation | Network candidate | Foundation candidate |
| --- | --- | --- |
| Postman WSS open | Opened; negotiated TLS version raw771 observed | Opened; system trust evaluation true |
| Exact text echo | Passed | Passed |
| Exact binary type/bytes comparison | Failed | Failed |
| BadSSL valid TLS control | Opening timed out; no retained TLS attribution | System trust true; native-1011 failed upgrade, not WebSocket success |
| BadSSL self-signed | Opening timed out; no retained TLS attribution | System trust false and native-1202; did not open |
| BadSSL wrong-host | Opening timed out; no retained TLS attribution | System trust false and native-1202; did not open |

Both complete-echo predicates are false because binary comparison did not pass. The binary mismatch type/bytes were not retained, so provider transformation, connection behavior or probe cause is unresolved. A shared public-service mismatch is not proven SDK failure, server defect or binary-WSS support. The original local #165 binary successes do not replace this missing external observation.

Network state observation queried available metadata but did not retain waiting-state errors. Its BadSSL timeouts therefore cannot attribute the intended certificate defects; no invalid-certificate acceptance or rejection is proved from these rows. Do not compare them as successful negative TLS cases. Foundation diagnostics evaluate platform trust then return performDefaultHandling without a credential/override. The positive control plus invalid-fixture failures support bounded system-trust rejection observations, not universal exact native error mapping. BadSSL is not a WebSocket service.

## Instrumentation and production limits

The frozen probe intentionally preserves its limitations: exact actual Host field, mismatch payload/type and Network waiting-state errors were not retained. Its terminalSeenBeforeCleanup flag records whether an error existed before cleanup, not full terminal/callback drainage. No patch-and-retry was made to improve the results after consuming the budget.

A scalar harness policy flag is not the full proposed security contract. Local cleartext and external TLS observations are complementary; they do not establish a controlled authenticated WSS fixture with all policies tested together. There is no production auth provider, reservation/validation of arbitrary header inputs, async state machine, cancellation/deadline race proof, sustained backpressure, fragmentation/hostile frames, physical/mobile/minimum or app-workload evidence. No RSS/resource benchmark was added to public fixtures.

## Architecture recommendation and stop/go

Do not adopt a production transport or start SDK implementation from this result. The earlier documentation-based Network-first investigation is complete for this finite scope; Network is not disproven as a transport, because important uncertainties are probe limitations. Apple TN3151's general guidance does not replace a project-specific evidence review.

Foundation currently has the stronger retained evidence for exact request target/Host, explicit denied redirect, selected protocol and default system-trust diagnostics. Recommend considering URLSessionWebSocketTask as the leading candidate for the next detailed design review, conditional on owner decision and remaining verification. Its existing HTTP/delegate integration is a concrete reason to reassess the original transport comparison, not permission to reuse HTTP delegates/deadlines blindly. This would also align with the original specification suggestion. Do not ship two adapters, add a generic transport framework, change the buffered NetworkClient protocol or refactor HTTP production code to hide unresolved WebSocket semantics.

Before any further native calls, approve a new finite scope/budget if needed. Preserve these findings and decide whether to (a) progress detailed Foundation-based design with explicit binary-WSS/async/provider/platform evidence gates, (b) authorize narrowly improved Network instrumentation, or (c) defer until a concrete server exists. No speculative implementation sequence or extra milestone is justified yet.

#168 may complete as the approved non-delivering experiment after actual PR/main acceptance with this incomplete conclusion explicit. #89 remains In Progress until final contract/transport/ADR and real task decomposition are accepted; #17 undelivered. Direct Watch WebSocket deferred, HTTP Watch/#132 unchanged. #29/#132 publication barriers stay open. No further code, production suitability or publication is authorized by this report.

See [execution/budget instructions](../../Tools/WebSocketFeasibility/SECURITY_README.md). Raw logs and consumed budget ledger stay private; public evidence contains sanitized synthetic observations and hashes.
