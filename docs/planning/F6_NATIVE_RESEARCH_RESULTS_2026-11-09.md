# F6 native research results — 2026-11-09

Tracking #179 under #90, same draft PR #177. The owner authorized only the isolated experiment at scope commit c70a780a3cf4ce76eefd07fd540fb64787489dad. No production implementation or exact public API is approved.

## Outcome

Mixed; further verified QUIC correction is required. #179 stays open/Blocked, not accepted. Four declaration-only SDK checks passed; all thirty pure cases passed; all six native TCP scenarios passed. Independent OpenSSL QUIC control Q10 passed. Native QUIC scenarios Q01–Q09 did not pass. Negative-test timeouts are failures, not evidence of successful rejection.

| Resource | Used / approved | Result |
| --- | --- | --- |
| Compiler commands | 8 / 8 | Four SDK checks passed; initial executable build failed; three corrected builds passed |
| Pure model invocations | 30 / 40 | 30 passed; no failed-case reserve used |
| Local transport sessions | 19 / 25 | 18 invocations; N02 consumes two sessions |
| Synthetic key/certificate pairs | 2 / 2 | CA and server-current removed after execution |
| External connections | 0 / 0 | None |

Seven of sixteen unique native scenarios have a passing latest result; nine fail. Across all eighteen native invocations, seven passed and eleven failed. The runtime is closed. Remaining session/pure reserves do not authorize a new compiler, new scenario or a reset of this ledger.

## Evidence and source versions

The [per-invocation ledger](evidence/F6/NATIVE179_LEDGER_2026-11-09.json) contains exact case observations, commands, source hashes, corrections and private full-log hashes. Compiler logs are adjacent NATIVE179_compiler-1.log through compiler-8.log. Private raw process diagnostics are not published. No keys or certificate material are committed.

The pure/TCP observations use executable build 6. Q01's second invocation uses build 7; its third invocation and Q02–Q10 use build 8. Final source does not retrospectively revalidate earlier observations. Build 5 failed warnings-as-errors (unused lock result and weak variable diagnostic); build 6 corrected those diagnostics.

## Accepted observations within this experiment

N01–N06 observed loopback listener readiness, ownership handoff, bounded SDK lease admission, stop/pending cleanup, continued use after handoff, weak wrapper lifetime and reuse of an actually observed interface. N02's second TCP client may become kernel-ready while SDK admission remains full; native listener credits are not a global active-connection cap.

The thirty pure cases exercise proposed browser, listener, multicast and QUIC rules. They do not prove actual discovery, multicast, permission, buffering or platform behavior.

Q10 used a separately implemented OpenSSL client against the native QUIC server, verified the synthetic CA/localhost identity and ALPN, exchanged four exact bytes and exited zero. The native peer recorded one transport group and four echoed bytes. This is one independent stream control, not proof of the complete native-client/group/datagram design.

## Failed observations and corrections

Q01 initially failed EINVAL. The prototype incorrectly installed both ordinary connection and connection-group handlers; Apple's SDK listener.h declares these mutually exclusive. Build 7 removed the ordinary handler. Q01 then failed ENETDOWN during stream extraction. Own-process logs recorded a protocol-stack join/clone failure; this does not establish a disconnected network or unsupported QUIC.

Build 8 used default extraction options for bidirectional streams, retaining explicit options for unidirectional/datagram flows. Q01 then timed out. Q02–Q05 failed extracted-flow readiness with ENETDOWN; Q06/Q07 negative ALPN/trust oracles timed out without the required qualifying rejection; Q08/Q09 sibling/group-close observations timed out. All remain failed/incomplete.

## Next priority and limits

Keep #179 ahead of exact API selection and production start. Review stream extraction and listener credit semantics, and observe waiting-state errors before allocating a tightly bounded correction run. A one-credit listener starving later stream delivery is only an unverified hypothesis. Do not reduce QUIC scope, add a dependency, raise OS floors or declare an OS defect from these prototype failures.

All eight compiler commands are consumed, so no further compiled correction or native rerun was performed. A concrete correction and a separately authorized new execution envelope are needed. No new issue/PR is required merely to continue this same investigation.

Native/physical Bonjour, permissions, multicast, peer-to-peer, other-platform runtime evidence and exact public contracts remain open. No installed trust, user Keychain, signing, device installation, entitlement or account changes occurred. The fixture directory is absent; ordinary removal is not secure-erasure proof. #29/#132 publication barriers remain.
