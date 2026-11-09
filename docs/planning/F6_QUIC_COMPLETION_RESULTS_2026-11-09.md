# F6 QUIC completion investigation — 2026-11-09

Tracking #179/#90, same draft PR #177. Owner approved only scope commit 079fb795e05ea907ad228b7e676f3c7fcc3dbd29. The [scope](F6_QUIC_COMPLETION_SCOPE.md) is now closed. This attempt produces a stop/redesign finding, not a full QUIC acceptance or a new runtime permission.

## Exact outcome

Eight positive native controls pass on the **same final build 3 Swift sources**: C01, Q01, C02, C03, Q02, Q03, Q08 and Q09. Q04 fails on that build. Q06/Q07 also fail the strict negative oracle on build 3. Q05 was not started because the required complete datagram prerequisite Q04 did not pass. Three failed plus one prerequisite-blocked case remain; none is silently removed.

| Resource | Used / approved | Result |
| --- | --- | --- |
| Mac compiler commands | 3 / 6 | All passed |
| Pure oracle controls | 6 / 12 | P01–P06 passed once; policy models, not native proof |
| Local transport sessions | 19 / 32 | Eleven initial inputs, five failed-input corrections, three changed-source final verifications |
| Temporary pairs | 2 / 2 | Fixture CA/server generated once, directory removed |
| External connections | 0 / 0 | None |

Ten of nineteen invocations passed; nine failed. Across eleven executed unique inputs, eight have a passing latest result and three fail. The twelfth input Q05 is unrun/blocked. All case durations remained under 20 seconds; no forced child teardown was needed. At most two owned children were used, including native split-process and OpenSSL controls. Do not consume unused quota to repeat the same failure without a concrete evidence-based correction. Runtime is closed; unused budget is not standing authority.

## New findings

### The client-unidirectional gap is resolved in this experiment

Q03 passed on builds 1 and 3 using established-group parameter copies. It checks exact stream data, actual client-unidirectional stream-ID bits and rejection of invalid receive without native receive admission. Q02 independently passes server-unidirectional semantics on final build 3. These are selected Mac observations, not cross-platform/public API acceptance.

### Nonempty datagrams work; empty-message delivery is unproved

Both datagram flows report negotiated ALPN networkkit-f6-test and usableDatagramFrameSize=1021. With receive armed before send, the two-byte message is received exactly with isComplete=true, a nonnil context and no callback error. The second receive is separately registered before the empty send. The send contentProcessed callback succeeds, but there is no receive callback before its deadline.

Build 2 additionally supplies an explicit empty DispatchData/message context and uses discontiguous receives to preserve missing-versus-empty object semantics. It does not fix empty delivery. Final build 3 repeats Q04 once and observes the same stage failure. No zero-byte success is synthesized from timeout/nil, and send completion is not called delivery. This is a bounded observation on the current Mac/native adapter; it does not establish universal lack of QUIC empty-datagram support or an OS defect.

Q05's original complete datagram-then-stream assertions are retained, but not attempted: its complete datagram prerequisite fails. Nonempty datagram success alone does not prove mixed stream/datagram isolation, and no earlier partial result substitutes for that evidence.

### Handshake failure remains a real adapter-observability gap

Build 1 attempts one child extraction during establishment; Q06/Q07 return extract-nil before any trust callback. Build 2 queues the single extraction behind group-start work; it still returns nil. Build 3 records that unavailable child and continues bounded observation of the actual group handshake instead of prematurely aborting it.

Final Q07 records one trust evaluation, one rejection, zero acceptances and no client group ready state. Final Q06 records no successful client state. In both cases, the peer group reports POSIX EINVAL, while the client group provides no qualifying terminal handshake error before the deadline. Both cases remain failed. The trust callback witness proves the selected trust decision, not complete native error propagation. No separate standalone connection, generic POSIX error or timeout replaces the selected same-group evidence.

## Final-source positive controls

| Case | Final build 3 observation |
| --- | --- |
| C01 | Exact stream-only native request/reply, trusted fixture and ALPN |
| Q01 | Native bidirectional exchange while datagram capability is enabled; not a mixed-delivery claim |
| C02 | Native peer and client in separate processes; exact bytes, trust/ALPN and exits zero |
| C03 | Existing independent OpenSSL client verifies fixture CA/hostname/ALPN, exact four-byte echo and successful peer/client exits |
| Q02 | Server-initiated unidirectional data and stream-ID direction |
| Q03 | Client-initiated unidirectional data, direction guard and no invalid native receive |
| Q08 | A sibling stream exchanges data after another stream closes |
| Q09 | Group close resolves pending child receive once |

The controller verified matching Swift source hashes for all eight latest passing observations. This is not an all-green twelve-case matrix. Old failures and source versions remain unchanged in earlier ledgers.

## Evidence and static review

[Completion ledger](evidence/F6/QUIC179_COMPLETION_LEDGER_2026-11-09.json) includes commands/hashes, all attempts, sanitized phase/state observations, exact usage and explicit skipped case. Adjacent QUIC179_COMPLETION_compiler-1.log through compiler-3.log retain build outcomes. Raw logs remain private with published hashes. No key/certificate material is committed.

Per-operation barriers are fresh; callback histories are bounded; missing datagram content cannot become a fabricated empty message. Six offline Python controls validate oracle/model rules, not exhaustive Swift races. A harmless Python literal-identity SyntaxWarning in the first version was removed with an equivalent missing-versus-empty comparison; no passing pure input was rerun or counted twice. Phase-only diagnostic envelopes do not constitute successful scenario results.

No shipped sources, root tests/manifest, CI, old helper implementations or old evidence changed. No Keychain, installed trust, personal signing, account, entitlement, physical device, dependency, OS floor or paid service change. The two-pair fixture directory is absent after normal removal; no secure-erasure guarantee.

## Next decision and priorities

Keep #179 Open/Blocked. The next task is an adapter/design review of explicit empty-message delivery and terminal handshake propagation, rather than a near-identical automatic rerun. Identify a supported native mechanism and a concrete changed hypothesis before proposing more executable work. No empty-message requirement, strict negative criterion or mixed-mode requirement has been waived. Any capability/contract change requires an explicit owner decision; neither an OS-floor bump nor a new dependency follows from these findings.

#90 remains In Progress for exact APIs, security integration, platform and native discovery/multicast/peer-to-peer proof. Those independent planning areas may proceed without an artificial CI wait or a new PR per experiment. #178 still awaits final integrated PR/main; #13/#18 and #29/#132 remain open. F6 production code and publication are not authorized by this result.
