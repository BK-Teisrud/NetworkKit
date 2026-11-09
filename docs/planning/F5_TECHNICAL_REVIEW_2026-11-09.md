# F5 technical review — working evidence

Status: completed candidate review in the single implementation PR #176. Live owner disposition is tracked in [I36/#174](https://github.com/BK-Teisrud/NetworkKit/issues/174); this source review does not establish final PR/main acceptance, milestone closure or publication. Selected tasks are I33–I36/#171–#174 under #17; planning #89 is completed.

## Design and implementation assessment

The bounded raw-message foreground requirement fits one independent connection actor and one owned Foundation adapter. Six focused WebSockets source files separate public values/errors, input policy, operation completion, actor lifecycle and native bridging. The existing 30 shipping Swift files remain byte-identical to accepted main. No public mock-only initializer/protocol, new product/module, dependency or speculative framework is introduced. Existing clock/auth/header values are reused without routing connection lifetime through the HTTP client.

The actor serializes admission/terminal decisions, permits one send and one receive, rejects duplicate operations and keeps pre-admission invalid input separate from terminal failures. Shared close completion now retains all waiters; the initial expanded test found and fixed a lost-continuation defect. A late native/provider result cannot reopen a terminated actor. Owned session shutdown and explicit peer snapshots remain separate from guarantees about operating-system resource reclamation.

No larger restructuring is justified for this increment. The folders isolate the added responsibility without introducing unnecessary abstraction or a second transport. Work discovered during verification belongs in I34/I35 and final I36 review; it does not require speculative additional milestones or issues.

## Native findings and corrections

- Native oversize reported POSIX EMSGSIZE/40 on the observed route. The adapter now preserves the agreed messageTooLarge category rather than flattening this into transport. [Apple's receive limit](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask/maximummessagesize) describes the bounded buffer and continuation aggregate; it does not promise one universal native error identity.
- [Native close metadata](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask/closecode-swift.property) can be available before delegate delivery. The adapter retains validated native task metadata where appropriate, excludes SDK cancel/close inference and synthetic absent-status snapshots, and validates malformed reason data before committing a generic error.
- POSIX EPROTO/100 observed after opening maps to protocolViolation; an unrelated ENOTCONN/57 remains transport unless invalid native close metadata independently establishes the protocol failure. This avoids relabelling arbitrary network failures to satisfy an oracle.
- The first fixed-frame run retained three failures. The corrected Mac verification passed all eight scenarios. Valid empty close and forbidden wire 1005 were distinguishable in observed metadata by the supplied reason bytes; no contract relaxation was needed. Temporary code/reason-length observation was removed before remaining routes. No diagnostic backdoor is part of the candidate.
- iOS/tvOS bad-certificate endpoints reported generic TLS failure −1200 with native trust rejection logs. Corrected probes assert TLS-layer rejection without claiming exact certificate-defect mapping. The original narrow certificate-code failures remain failures, not retrospectively relabelled passes. System trust handling is unchanged.

## Evidence separation

The original approved seven-route cohort used 126 local and 18 new public SDK connects, exactly its ceiling. It retained 88 passing and seven failing test declarations, including the original Mac/iPhone failures. Five corrected-candidate routes passed 14 tests each. Prior three Mac public WSS tests were a separate completed authorization. See [cohort ledger](evidence/F5_COHORT_2026-11-09.json) and adjacent per-route evidence.

The separate completed scope permitted at most 124 local connections, including eight direct Foundation resource controls, and no external calls. Mac corrected core passes 11 tests; the manual eight-frame verification passes after the protocol corrections. Corrected iPhone 18.2 core plus eight fixed-frame scenarios pass. All eight frame scenarios pass on each selected route; the Mac resource profile also passes. The completion scope consumed exactly 124 local connections (116 SDK plus eight native controls), including both explicitly permitted eight-call manual verification allocations. No further authority remains. The original failed runs remain preserved. See [completion scope](F5_COMPLETION_VERIFICATION_SCOPE.md).

The final full Mac regression passes **309 tests in 37 suites**, including **40 WebSocket tests in four suites**. Strict DocC, compiled ordinary-import configuration/auth/deadline/cleanup examples and source integrity pass. Final delegate tests cover unopened EPROTO/EMSGSIZE/data-length failures so no pre-handshake error invents a message/protocol failure. Post-open native evidence predates only that guard correction, whose actual unopened delegate path is verified without resuming any task. Existing automatic CI is separate from the selected native suites; final PR/main checks remain mandatory.

### Resource observation

| Observation | RSS bytes | MiB |
| --- | ---: | ---: |
| Initial | 4,718,592 | 4.50 |
| Native control after 8s | 8,613,888 | 8.21 |
| SDK immediate | 9,555,968 | 9.11 |
| SDK after 8s | 9,560,064 | 9.12 |
| SDK after 61s | 9,519,104 | 9.08 |
| Highest sampled RSS | 9,560,064 | 9.12 |

The finite sixteen-connection profile completed in 69.621 seconds, with 3046 samples. Both control and SDK exchanged sixteen 4096-byte messages per connection. See [resource evidence](evidence/F5_RESOURCE_PROFILE_2026-11-09.json). These are process observations under this small, unencrypted loopback workload, not isolated SDK allocations, a TLS resource profile or a production guarantee.

### Native extensions and observability

The final ordinary Mac adapter passes all eight frame cases without the temporary observation hook. The corrected fixture retained a native `permessage-deflate` offer; the controlled reply selected no extension. Other routes also received non-negotiating controlled replies, but their offer metadata was not captured retrospectively. There is no public compression/extension configuration API, negotiated-compression test or decompression-memory guarantee. Keep this native boundary explicit in the owner disposition and future actual-server/workload review. SDK default descriptions redact private values; platform/test diagnostics are a separate boundary and may emit native details, so published excerpts omit native error userInfo and simulator IDs.

## Residual boundaries for the final disposition

- Foreground only. No reconnect, heartbeat scheduler, background continuity, event stream, subscription/JSON protocol or direct watchOS WebSocket support. HTTP Watch support remains unchanged.
- One delivered message at a time and a positive per-connection byte limit do not cap all Foundation/OS buffering, concurrency, application allocations or total process memory. The slow-consumer observation is finite, not an unbounded-load proof.
- Native send completion does not establish remote application receipt. No replay/durable queue or protocol-level acknowledgement is promised; the application owns any fresh HTTP status fetch/new connection.
- Application authentication providers must cooperate with cancellation. A provider that ignores it may retain work after logical termination; the actor prevents late network start but does not promise unconditional joining.
- Explicit close has a bounded cancellation fallback and no peer-ack/immediate-resource-drain guarantee. Native wire parsing/extension behavior remains delegated to Foundation; tested cases are not a complete standards-conformance certification.
- Native control/resource samples include fixture/framework/allocator effects and warmup/order/cleanup-policy differences. Unknown real application message rates/sizes remain a publication/workload gate under #29. Do not invent a universal memory limit or recommend a production load from these synthetic observations.
- Simulator minimum-family patches are 18.2, not exact 18.0; Mac is 15.8.1 Intel. Physical mobile/TV, other Mac architectures/runtime behavior and Watch publication conditions are not established by these observations. Preserve selected platform evidence limits and #29/#132 without silent migration of an unresolved F5 criterion.

The selected technical evidence is complete for review. I36 still requires an explicit owner disposition and final PR/main acceptance. No historical failed attempt is waived or erased by this report.

## Test-harness startup finding

A full 308-test run during simulator startup retained two existing HTTP-fixture setup failures: redirect readiness exceeded its three-second bound, and the TLS fixture's OpenSSL child exceeded its own three-second generation limit. These occurred before the affected client assertions; no shipping HTTP source changed. The test-only readiness bound is now ten seconds and inner certificate generation eight seconds, preserving owned-child kill/wait cleanup and explicit short negative-readiness tests. Product timeouts/retry/trust rules are unchanged. The corrected quiet-host full run passes 309 tests; explicit short negative-readiness and child-stop tests remain included. The failed attempt is retained rather than hidden by automatic retries.

## Native overlap addendum

The final criteria reconciliation found that native send/receive overlap had not been directly observed, although deterministic actor concurrency tests passed. The exhausted 124-call scope was not extended implicitly: the owner separately approved one local Mac connection. The public-API-only overlap test passed in 0.089 seconds. Two receive tasks produce one explicit duplicate rejection, proving one receive is admitted before send begins; the pending receive then returns the echoed message. No arbitrary scheduling delay or internal transport override is used. See [overlap evidence](evidence/F5_NATIVE_OVERLAP_2026-11-09.json). This separate one-call authorization is also exhausted.

The complete selected evidence now covers deterministic async/provider races, actual native overlap, controlled malformed/fragmented frames, native lifecycle/limits, appropriate public binary WSS, explicit platform distinctions, compiled consumer use and a finite resource observation. No actual authenticated application server exists; native header construction/transport behavior and provider acquisition/isolation are complementary evidence, not an application login/server-protocol proof. Preserve this distinction in the production integration review under existing #29.
