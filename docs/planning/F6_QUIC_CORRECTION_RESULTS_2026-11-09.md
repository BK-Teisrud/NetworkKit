# F6 QUIC correction results — 2026-11-09

Tracking #179/#90, same draft PR #177. The owner approved only the [fabf77a correction scope](F6_QUIC_CORRECTION_SCOPE.md). The attempt is closed with mixed results. No public API or production start is approved.

## Accounting

| Resource | Used / authorized | Outcome |
| --- | --- | --- |
| Mac compiler commands | 3 / 4 | All three passed |
| Pure oracle controls | 4 / 8 | O01–O04 passed; Python policy models, not native TLS/history proof |
| Loopback transport sessions | 16 / 16 | Twelve unique cases plus four documented failed-input corrections |
| Synthetic key/certificate pairs | 2 / 2 | Created once, fixture directory removed |
| External connections | 0 / 0 | None |

Seven of twelve unique native cases have a passing latest result; five remain failed. Across sixteen invocations, seven passed and nine failed. No further sessions are authorized. Runtime is closed; the unused compiler and pure reserves are not a new execution envelope. Native work remained inside the recorded ten-minute window and per-case deadlines. At most two owned experiment children were used, including split-process/independent controls.

## Corrections and evidence

[Ledger with source hashes, exact observations and original-log hashes](evidence/F6/QUIC179_CORRECTION_LEDGER_2026-11-09.json). Compiler logs are adjacent QUIC179_CORRECTION_compiler-1.log through compiler-3.log. Old NATIVE179 evidence is unchanged.

Build 1 raised the fixture's finite listener creation credit to eight, retained one-group admission and four flow contexts per endpoint, and added bounded phase histories. Initial C01 still timed out: both groups were ready and trust was accepted, but the first incoming flow remained preparing while a later flow was ready. Therefore increased listener credit alone did not resolve the observed failure; its isolated effect is not established.

Build 2 admitted an incoming flow to the receive inbox only after readiness, avoiding head-of-line blocking on an unready flow. This is an experiment correction, not an accepted public ordering/stream contract. Weak callback capture avoids adding a wrapper cycle. C01 then passed. Q01, separate-process C02, independent OpenSSL C03 and sibling/close cases Q08/Q09 also passed on build 2.

Q02–Q05 failed child readiness with fresh stream options. Build 3 derived child mode options from a copy of the established group's parameters, preserving its TLS/ALPN configuration. Server-initiated unidirectional Q02 then passed with the expected stream-ID direction assertion. Datagram-only Q04 and mixed Q05 reached flow readiness but still timed out; exact data/empty-message completion was not established. No fallback or truncated success is accepted. Q03 was not rerun after build 3, so its client-initiated unidirectional result stays failed.

## Latest native outcomes

| Case | Latest result | Meaning |
| --- | --- | --- |
| C01 | Pass, build 2 | Native stream-only exact request/reply and ALPN |
| Q01 | Pass, build 2 | Exact native bidirectional exchange with datagram capability enabled; not datagram delivery |
| C02 | Pass, build 2 | Native client/server in separate processes; exact bytes, trust/ALPN and successful exits |
| C03 | Pass, build 2 | Independent existing OpenSSL client; verified fixture CA/hostname/ALPN, exact four-byte echo and exits zero |
| Q02 | Pass, build 3 | Server unidirectional stream and actual stream-ID direction |
| Q03 | Fail, build 2 | Client unidirectional extraction failed; final options change not reverified on this input |
| Q04 | Fail, build 3 | Datagram flow ready, but complete named-case observations timed out |
| Q05 | Fail, build 3 | Mixed mode not proved; timed out before the full required exchange |
| Q06 | Fail, build 2 | Wrong ALPN did not deliver the required qualifying terminal handshake error; timeout is not a pass |
| Q07 | Fail, build 2 | Trust callback rejected once and never accepted, but the required terminal error observation remained missing |
| Q08 | Pass, build 2 | Closing one stream leaves sibling exchange working |
| Q09 | Pass, build 2 | Group close resolves pending child receive once |

Negative diagnostics showed no client group state, while the peer group failed with POSIX EINVAL. Q07 additionally recorded a trust rejection. Neither an unrelated POSIX code nor a timeout is promoted to the required TLS rejection result. Waiting-state ENETDOWN also appeared on successful bootstrap routes before ready, so it cannot alone identify a disconnected network.

## Remaining priority

#179 remains open/Blocked. Focus the next investigation on datagram send/receive phase attribution and actual negotiated flow metadata, explicit failed-handshake completion delivery, and rechecking client-unidirectional behavior after the parameter-copy correction. Keep these as one existing investigation rather than new issues for every symptom. A subsequent executable experiment needs a separate concrete scope; no further calls were made under this exhausted session envelope.

Do not reduce the QUIC requirement or add an OS bump/dependency to conceal prototype gaps. Native discovery, multicast, peer-to-peer, other-platform execution and exact API decisions remain open under #90. Production and publication remain unauthorized; #29/#132 stay unchanged. No SDK sources/root tests/manifest/CI, installed trust, user Keychain, personal signing identity, account, entitlement or physical device changed.

Source versions matter: build-2 passing cases were not rerun on build 3. Compiler logs/source hashes and original failures remain preserved; this is not a claim that the final source passes the entire matrix. Ordinary fixture removal is not secure-erasure proof.

## Primary API references

The installed Network SDK headers define listener creation credits and extraction mechanics. Apple's [QUIC presentation](https://developer.apple.com/videos/play/wwdc2021/10094/) describes separate transport groups and streams; [QUIC datagram guidance](https://developer.apple.com/videos/play/wwdc2022/10078/) demonstrates explicit datagram options. These establish intended API use, not proof that this experiment's datagram route works.
