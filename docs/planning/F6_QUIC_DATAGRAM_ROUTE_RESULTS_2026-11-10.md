# F6 direct QUIC datagram route results — 2026-11-10

Tracking #179/#90, same draft PR #177. Owner approved only [scope ed85295](F6_QUIC_DATAGRAM_ROUTE_SCOPE.md). The experiment is complete and closed with a stop finding: the direct preconfigured route did not establish empty-datagram delivery. No production code or exact API is adopted.

## Accounting and result

| Resource | Used / authorized | Result |
| --- | --- | --- |
| Mac compiler commands | 1 / 4 | Passed with Swift 6 warnings-as-errors |
| Pure Swift route inputs | 4 / 8 | R01–R04 passed once |
| Local transport sessions | 3 / 16 | D01–D03 failed their complete empty-message assertions |
| Synthetic pairs | 2 / 2 | Generated once, fixture directory removed |
| External connections | 0 / 0 | None |

No correction or repeat was justified by a new mechanism; unused quota was not consumed merely to obtain more of the same observation. G01 and G02 were not started because their complete direct/group prerequisites were not met. Skipped inputs remain unproved. All three native processes ended normally under their 20-second case limits; no forced teardown. Runtime closed and fixture absence verified; no secure-erasure claim.

## Exact observed behavior

The client and listener used NWParameters.quicDatagram(alpn:) before establishment, rather than extracting a flow from NWConnectionGroup. The factory reports datagram mode. Client verification accepted the synthetic fixture once, negotiated ALPN matched, and both endpoints reported usableDatagramFrameSize=1021. The explicit direct route therefore reaches authenticated readiness without changing OS floors or wire framing.

| Input | Nonempty positive control | Empty-message result |
| --- | --- | --- |
| D01 client to server | Exact two-byte complete datagram delivered | Separately registered empty receive got no callback before timeout |
| D02 server to client | Exact two-byte complete datagram delivered | Same no-callback timeout in reverse direction |
| D03 first application message empty | Fresh authenticated readiness; direction control supplied by D01 | First empty send processed, but no complete receive callback before timeout |

All empty sends used the existing explicit DispatchData/message-context path. Receive registration preceded send; missing/nil callback content was not fabricated into a zero-length result. Send contentProcessed succeeded, but that is not receipt. D03 rules out the narrow assumption that an earlier nonempty message is required for this observed failure; it does not prove a universal platform defect.

## What this establishes and what it does not

Changing from the group/extracted-flow route to the older supported direct datagram factory did not fix the observed empty-message problem on this Mac runtime. The two routes share Apple's implementation and the same isolated receive/send helpers, so this is correlated evidence; the shared empty-bridge implementation remains a possible contributor. This is not an independent RFC 9221 interoperability verdict or proof that every runtime drops empty datagrams.

The exact root cause (bridge, framework/runtime or another adapter assumption) is not identified. No markers, framing wrappers, reliable-stream substitution, payload padding or silent no-op acceptance were added. No raw QUIC frame/cryptographic implementation, private API, new dependency or OS change was attempted.

R01–R04 execute the actual new route-state rules for missing versus empty content, no mode fallback, one datagram flow and capacity/completeness rejection. They do not prove native delivery or exhaustive concurrency. The narrow native callback owner copies the startup experiment's explicit standard-lock unchecked-state boundary; its production ownership/threading review remains open. Client TLS resumption is disabled for the fresh-handshake fixture; production resumption is unproved.

## Evidence and verification

[Per-invocation ledger](evidence/F6/DATAGRAM179_LEDGER_2026-11-10.json) contains approved scope, exact compiler command/source hashes, pure outcomes, phase/metadata observations, case durations, private log hashes and explicit unrun inputs. [Compiler log](evidence/F6/DATAGRAM179_compiler-1.log) has no diagnostics. Raw logs remain private and no fixture keys/certificates are committed.

All observed inputs used one unchanged compiled candidate. Existing research helpers and old ledgers are byte-unchanged. No shipping source/root tests/manifest/CI/privacy/dependency/OS floor, user Keychain, installed trust, personal signing, account/capability, physical device or paid service changed.

## Plan and backlog disposition

Keep #179 Open/Blocked for empty-message Q04 and complete mixed Q05 evidence, plus final callback/resumption/platform/API review. Startup L01–L12/S01–S06 selected passes remain valid under their separate scope; old Q06/Q07 failures remain historical. This attempt does not close #179, #90, #13/#18 or F6.

No further near-identical local rerun is justified. Before executable work identify a supported changed send/receive mechanism, a controlled independently implemented application-DATAGRAM peer, or a separately available runtime comparison. OpenSSL 3.6's stream client is not such a DATAGRAM peer; do not install another tool/environment implicitly. A newer API declaration or global OS-floor bump is not runtime evidence.

Preserve the full requirement unless the owner explicitly chooses a later disposition. Independent #90 security integration, exact contract and Bonjour/multicast/P2P/platform planning can proceed without claiming the QUIC blocker is resolved. Do not create an issue/PR for each repeated symptom. The one planning PR remains draft; publication gates #29/#132 are unchanged. No standing unused code/runtime quota follows from this closed experiment.
