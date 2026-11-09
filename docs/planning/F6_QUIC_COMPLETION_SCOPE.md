# F6 QUIC completion investigation proposal

Prepared 2026-11-09 for #179/#90, same draft PR #177. The owner subsequently approved this exact scope. [Execution is now closed with a stop/redesign finding](F6_QUIC_COMPLETION_RESULTS_2026-11-09.md); the proposal below is retained as the approval baseline. The completed [initial research](F6_NATIVE_RESEARCH_RESULTS_2026-11-09.md) and [correction](F6_QUIC_CORRECTION_RESULTS_2026-11-09.md) stay immutable. No old quota or key material is reused.

## Concrete preparation findings

Q03 needs verification with the parameter-copy correction already compiled for server-uni. Q04/Q05 histories establish ready flows but cannot distinguish send processing, first datagram delivery or empty-message delivery. The current fixture sends before installing receive and reuses a single receiveStarted barrier; that barrier cannot establish admission of a second receive. These are observable harness gaps, not established explanations of transport behavior.

Q06/Q07 wait only on group readiness/error. The group client supplies no observed terminal handshake callback in these failed cases, while the peer fails with POSIX EINVAL; Q07 separately witnesses trust rejection. Generic POSIX failure/timeout cannot be relabelled certificate/ALPN rejection.

## Intended isolated changes

Only Tools/F6Feasibility/NativeResearch/ code/controller and related English evidence/planning may change. Preserve shipped SDK, historical helpers/ledgers, root manifest/tests/CI, dependencies, OS floors, account/capabilities, installed trust, Keychain, signing and physical devices.

1. Record at most 64 bounded phase entries per case and 32 native states per object, with overflow flags. Phases identify child extraction/readiness, per-operation receive registration, content-processed completion, received byte count/completeness, empty-message completion and mixed stream exchange. No payload, endpoint, credential or raw trust object in public diagnostics.
2. Use a fresh per-operation receive-registration barrier and arm receive before send for each datagram. Keep at most one active send/receive per flow; one datagram flow per endpoint. Preserve explicit empty-message and complete-message checks. Distinguish no message from an observed empty message; never fabricate success from nil/error/timeout. Do not infer delivery from contentProcessed.
3. Record usableDatagramFrameSize, negotiated ALPN and actual stream IDs where the native API exposes them. A requested isDatagram flag alone is not proof of actual delivery or global buffering limits. No new connection/health check to obtain metadata.
4. Investigate a bounded initial child extracted from the same multiplex group during establishment, with state handlers installed before start, so a native handshake failure may reach an owned observable operation. A successfully created child consumes a context slot. No separate standalone-connection success may replace proof for the group transport. Retain qualifying terminal handshake witnesses: timeout/unrelated POSIX code cannot pass; trust rejection must have its independent callback witness and no ready/data admission. If the native path still cannot expose the required evidence, leave the case failed and document the contract limitation.
5. Correct only named failed inputs using recorded evidence; no uncounted option matrix, retries, transport fallback or scope removal. Keep existing positive controls and independent OpenSSL stream control. Consolidate acceptance observations on final unchanged compiled sources after fixes when needed.

These are research hypotheses, not an exact production API or promised successful outcome.

## Proposed complete envelope

| Resource | Maximum |
| --- | --- |
| Mac compiler commands | 6 total: one initial plus five documented failed-build/candidate corrections; 120 s each |
| Pure oracle/model invocations | 12: six fixed initial inputs plus six failed-input corrections; 5 s each |
| Local transport sessions | 32 total: twelve initial cases, eight documented failed-case correction slots, up to twelve final-source verification slots |
| Temporary synthetic pairs | 2, once: fixture CA and server-current |
| External connections | 0 |
| Concurrent owned children | 2; overall user limit remains five processes |

No declarations-only cross-platform batch is added. Reuse existing installed OpenSSL only; no install/build dependency. New fixed-path ledger references the approved scope commit and source hashes and refuses reset/reopening after cleanup. Record consumed slots before action; failed/timed-out starts consume slots. Native sessions run only on 127.0.0.1 with ephemeral fixture port; one candidate handshake per case, including its peer. Internal OS activity is not claimed to equal logical session counts.

Each endpoint: at most four native flow contexts, sixteen sends and 64 KiB sent/received per session. One admitted transport group per fixture. Unexpected extra groups/contexts fail and stop that case, never become free authority. No LAN/Bonjour/multicast/P2P radio actions. Each native case has a 20 s aggregate deadline including peer/client startup, observation and normal teardown; controller separately logs any forced teardown. Each explicit batch at most 240 s; total native window at most 1200 s including correction gaps. All commands sequential except the at-most-two owned fixture/client children. No background waiting or CI poll loops.

## Exact pure controls

| ID | Fixed input / required result |
| --- | --- |
| P01 | Timeout without qualifying error cannot pass a negative handshake oracle |
| P02 | Generic POSIX error without security witness cannot pass ALPN/trust rejection |
| P03 | Terminal qualifying TLS rejection plus required trust witness may pass; ready/data observation invalidates it |
| P04 | One receive's registration cannot satisfy the next receive's barrier; stale token is rejected |
| P05 | Missing message is not silently converted into an observed empty datagram |
| P06 | Zero usable datagram capacity is unsupported/incomplete, never a successful exchange |

These are oracle/policy controls, not native API proof. Corrected reruns retain original failures.

## Exact twelve native inputs

Q03, Q04, Q05, Q06 and Q07 keep the original client-uni, complete datagram-only including empty message, mixed stream/datagram, wrong-ALPN and untrusted-peer assertions. Better instrumentation must not remove an assertion.

Seven controls retain the original assertions: C01 stream-only native bootstrap; Q01 native bidirectional with datagram capability enabled; C02 separate-process native pair; C03 existing independent OpenSSL client with verified fixture CA/hostname/ALPN, exact four-byte echo and successful exits; Q02 server-uni and stream-ID direction; Q08 sibling survival; Q09 pending-child resolution once after group close.

Run six pure controls then build and C01 first. If C01 fails, stop dependent positives and correct that named failure only. Q06/Q07 may diagnose independently. After C01 passes, run Q03/Q04 and dependent Q05 only if required stream/datagram subpaths work; leave any skipped case unproved. Remaining controls are mandatory for a complete selected result.

Eight correction sessions repeat only documented failed named inputs after a recorded relevant source/oracle change. The final twelve slots are explicitly for one verification of each named case on unchanged final compiled sources **only when its prior observation used an older relevant source version**. Do not rerun already passing identical-source cases, or call a fresh run necessary merely because documentation/controller commentary changed. If no code changed, reuse the exact-source evidence. Failed final verification remains failed; no automatic retries beyond the 32-session total. No new case, fuzz/stress expansion or hidden health probe.

## Cleanup, evidence and stop

Create two synthetic pairs once in a private fixture directory with in-memory identity and evaluation-local test anchor only. Never install trust or use user Keychain. Normal/failed scope exit removes the fixture directory and terminates owned children; record absence and any teardown failure without a secure-erasure claim. Keep raw logs privately; publish sanitized phases, outcomes, exact counts, source versions and hashes.

Stop when a budget/deadline is exhausted or the selected matrix is resolved. Do not consume unused slots for curiosity or repeating successes. A failure is a result, not permission for additional runs. #179 cannot close until selected criteria and same integrated PR/main acceptance are met. #90 still owns discovery/multicast/P2P/platform/exact-contract gates; #29/#132 remain. No F6 production implementation, deployment or publication follows from this experiment.

## Primary API basis

Installed Network.swiftinterface exposes QUIC.Metadata.usableDatagramFrameSize and streamIdentifier. Installed connection_group.h requires extracted connections to be started and documents nil endpoint for multiplex groups. These support the diagnostic approach, not a successful-runtime claim. [Apple extraction API](https://developer.apple.com/documentation/network/nwconnectiongroup/extract(connectionto:using:)), [usable datagram size](https://developer.apple.com/documentation/network/nwprotocolquic/metadata/usabledatagramframesize).
