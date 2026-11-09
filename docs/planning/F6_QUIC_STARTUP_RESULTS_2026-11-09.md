# F6 logical QUIC startup results — 2026-11-09

Tracking #179/#90, same draft PR #177. The owner separately approved only [scope 3bffb74](F6_QUIC_STARTUP_EXECUTION_SCOPE.md), after approving the [error/admission direction](F6_QUIC_ADAPTER_REVIEW.md). The scope is now closed.

## Outcome and accounting

All twelve actual Swift coordinator inputs L01–L12 passed once. All six native startup inputs S01–S06 have passing latest results on the same final build-4 candidate. StartupCoordinator.swift itself is byte-identical across the pure/native observations; only fixture send ordering changed between passing build 3 and build 4. This is selected local coordinator evidence, not a full F6/public API/production gate.

| Resource | Used / authorized | Outcome |
| --- | --- | --- |
| Mac compiler commands | 4 / 4 | Builds 1/2 failed strict concurrency; builds 3/4 passed |
| Pure Swift invocations | 12 / 20 | All twelve fixed inputs passed; no correction reruns |
| Local transport sessions | 7 / 18 | S01 initial failed, corrected S01 and S02–S06 passed |
| Synthetic pairs | 2 / 2 | Generated once, fixture directory removed |
| External sessions | 0 / 0 | None |

All native cases finished within 20 seconds; no forced process teardown. No further passing inputs or unused slots were run. Runtime is closed; unused quota cannot reopen it. No physical installation, user Keychain, installed trust, personal signing, account/capability, dependency, spending or OS-floor change occurred.

## Native observations

| Case | Actual observation |
| --- | --- |
| S01 | Real trust acceptance, negotiated ALPN, one handoff and exact two-byte request/reply |
| S02 | Real trust evaluator rejects once; one logical trustRejected result, one registered/completed handler, zero handoff/data and zero pending handlers |
| S03 | Controlled wrong-ALPN peer fails; matching valid S01 passes on same source; client returns one startup timeout with zero handoff/data. No ALPN/TLS cause is invented from generic POSIX error |
| S04 | Hold a real verified callback, cancel, release its late result: one cancelled caller result, one completed handler, one suppressed late result, zero pending/handoff/data |
| S05 | Hold real callback past short startup budget, release: one timeout, one completed handler, one suppressed late result, zero pending/handoff/data |
| S06 | Native readiness/trust and child readiness observed, handoff held; cancel before releasing decision: one cancelled result, zero handoff/data |

Counters are the coordinator's ownership/completion observations, not an OS resource-drain acknowledgement. Cancellation and timeout do not claim to retract callbacks already logically admitted before termination. Fixed ordering/barriers are not exhaustive concurrency testing. TLS resumption is explicitly disabled in the client fixture; every trusted/held case exercises a real callback. Production resumption support and other-platform behavior remain unproved.

## Pure coordinator evidence

L01–L12 execute the actual new Swift coordinator, not a separate Python model: already-cancelled admission, readiness without trust, positive admission once, trust rejection versus ready, timeout handler drain, late acceptance, mismatching/missing ALPN, honest transport/timeout classification, late reply suppression, foreign-context trust refusal and post-handoff verification ownership. Tests use actual callback/stop side-effect recorders. They establish these fixed schedules only; no native resumption or borrowed trust acceptance is claimed.

## Retained failures and narrow native callback bridge

Build 1 rejected capture of sec_protocol_verify_complete_t in a Sendable closure. Build 2 also rejected a sending transfer of the imported block into Mutex. The final experiment uses a private NativeVerifyReply holding only that imported completion in OSAllocatedUnfairLock(uncheckedState:). It takes the block exclusively once, clears the slot, then invokes it outside the lock. It does not declare arbitrary native identities/objects Sendable or use unsafeBitCast/private APIs. The unchecked-state C/Swift boundary is explicit and requires production review of callback ownership/threading; compiler success alone is not its safety proof. Standard-library Synchronization was removed from the candidate.

Build 3 passed all pure controls, but S01 first timed out because the fixture awaited an incoming stream before sending its first bytes. Trust, ALPN and logical handoff already succeeded. Build 4 moved admitted request sending before waiting for the peer stream. That correction passed S01 and all five remaining inputs without further source changes. The failed initial input/build logs remain in the ledger; no counter reset or overwritten evidence.

The startup coordinator uses a monotonic deadline checked at admission as well as a timeout task. The startup deadline does not become an automatic lifetime timer after handoff. The verification owner remains available after handoff: repeated callbacks are answered once per registration, and a later trust rejection closes the connection without issuing a second startup result. The post-handoff property is directly covered by L12, not a claim that a physical server forced post-handshake revalidation.

## Evidence and remaining priority

[Per-invocation ledger](evidence/F6/STARTUP179_LEDGER_2026-11-09.json) includes compiler commands, source versions, fixed case outcomes/counters and raw-log hashes. Adjacent STARTUP179_compiler-1.log through compiler-4.log preserve diagnostics. Raw logs remain private; no fixture keys/certificates are committed. Cleanup absence is verified, without a secure-erasure claim.

Old Q06/Q07 native-error probes remain failed as historical observations. New S02/S03 verify the separately owner-approved logical-startup contract and must not rewrite those probes. Remaining QUIC blockers are Q04 empty-message delivery and Q05 full mixed-mode isolation, alongside production callback-boundary/resumption/platform/API review. #179 remains open until all selected criteria and integrated PR/main are satisfied; local startup success alone cannot close it.

Next priority: identify a supported empty-message/native datagram route or a controlled independent datagram peer before more execution. Do not silently wrap raw datagrams, add a dependency, raise OS floors or waive Q04/Q05. #90 can continue independent security/platform/discovery/multicast/P2P preparation. #178 still needs final integrated PR/main acceptance. #13/#18 and publication barriers #29/#132 remain open. No F6 production start or publication follows.
