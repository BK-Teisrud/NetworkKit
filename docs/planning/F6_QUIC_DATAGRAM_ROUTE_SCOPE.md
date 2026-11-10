# F6 QUIC native datagram route comparison

Prepared 2026-11-10 for #179/#90, same draft PR #177. Read-only review plus proposed next executable scope. No new code/compiler/transport/fixture was run. Previous startup verification and all prior ledgers remain closed. Separate owner code/execution approval is required.

## New supported hypothesis

The installed Network.swiftinterface exposes NWParameters.quicDatagram(alpn:) at macOS 13/iOS 16/tvOS 16, below current floors macOS 15/iOS/iPadOS/tvOS 18. Apple documents it as default connection/listener parameters for QUIC datagrams. Compare a direct NWConnection/NWListener datagram configuration selected **before establishment** with the previous extracted-flow group route. This is a supported alternative construction path to assess, not a confirmed empty-message fix.

The previous experiment established exact nonempty delivery, negotiated usable capacity and a separately registered receive, but no empty-message callback after Data/DispatchData send processing. Do not repeat only that bridge without a new control. A direct datagram-only result cannot prove stream/datagram cohabitation in one multiplex group. Keep that distinction in the result and final contract.

OpenSSL 3.6 documentation says support for the QUIC datagram extension is future work. Its existing stream client therefore cannot be the proposed independent DATAGRAM peer. SSL_inject_net_dgram injects underlying network packets; it is not an RFC 9221 application datagram API. No library installation/build or paid/hosted environment is selected. Both proposed routes use Apple's framework and remain correlated implementation evidence.

## Exact non-shipping changes proposed

New files only under Tools/F6Feasibility/NativeResearch/: DatagramRouteMain.swift, DatagramRouteState.swift and run_datagram_routes.py. Reuse existing fixture helper and selected research values/stream/coordinator helpers read-only; exclude earlier @main sources. Any callback bridge copied into the new fixture must retain the explicit single-owner/outside-lock audit boundary from the startup experiment; no broad native Sendable wrapper/private API.

Configure the direct client's and listener's native QUIC datagram mode before start. Keep a single declared synthetic ALPN, system hostname policy plus evaluation-local fixture anchor, explicit server identity, fresh client handshake and bounded startup/verification completion. No startup behavior is inferred from raw ready alone: actual trust and negotiated ALPN must be observed before app data. One admitted transport per case, at most one datagram flow and four native contexts per endpoint; report/cancel unexpected extras. Do not install trust or use user Keychain.

A receiver is registered before each send with a fresh operation barrier. Record each phase, actual native metadata and complete callback count/presence; distinguish an actual empty message from no callback/nil. At most 64 phase entries per case/32 native states per object, with overflow flags. No payload/address/certificate/private data in public logs. A send processed callback is not receipt. No marker-byte wrapper, payload transformation, stream replacement or automatic retry.

The group comparison retains existing complete Q04/Q05 assertions and existing route unless a documented failed-input correction identifies a supported construction defect. Direct success alone cannot pass a group case. No switch to OS-26 APIs, floor increase or second production adapter is selected.

## Proposed envelope

| Resource | Maximum |
| --- | --- |
| Mac compiler commands | 4: one initial plus three documented failed-build/candidate corrections; 120 s each |
| Pure Swift controls | 8: four initial inputs plus four failed-input corrections; 5 s each |
| Local transport sessions | 16: five initial inputs, six failed-input corrections, up to five changed-source final verifications |
| Synthetic key/certificate pairs | 2 once: fixture CA and server-current |
| External connections | 0 |
| Concurrent owned children | 2, within overall five-process limit |

Use a new fixed-path scope ledger, with approved commit/source hashes and counters recorded before action; no reset/reopening after cleanup. Each case is exactly one candidate handshake and peer, not extra health checks/control connections. Failed/aborted starts consume a slot. Native bytes per endpoint: at most sixteen sends and 64 KiB sent/received. Each native case: 20 s aggregate startup/observations/normal teardown; each batch 180 s; total native window 900 s including corrections. Record forced teardown separately. No LAN/Bonjour/multicast/P2P/device, installed trust, credentials/account/capability, signing, dependency, spending or publication changes.

## Four exact pure controls

R01 missing callback/content is not fabricated empty data; R02 selected direct datagram/stream mode cannot be silently mixed or fall back; R03 second datagram flow/context admission is rejected; R04 invalid/zero capacity and incomplete message are never delivered as valid. Exercise the actual new route state/admission logic with fixed inputs, not a parallel Python oracle. These tests do not establish native delivery.

## Five exact native inputs

| ID | Required observation |
| --- | --- |
| D01 | Direct datagram connection/listener, exact nonempty client message followed by actual complete empty client message on separately armed receives |
| D02 | Same direct route, server-to-client exact nonempty then empty messages, preserving direction evidence |
| D03 | Direct route where the first application message is empty; real complete receipt required, not a fabricated handshake/control event |
| G01 | Current group/extracted-flow route, same fixture/ALPN, complete nonempty and empty delivery; record as controlled baseline comparison, not reclassification of old Q04 |
| G02 | Same multiplex group carries complete datagrams including empty plus exact independent stream exchange without cross-routing; original Q05 intent retained |

Run four pure controls then D01. Failure of trust/ALPN/native readiness or nonempty positive phase blocks dependent native inputs until a documented correction passes that prerequisite. If only D01's empty phase fails after a valid nonempty control, D02/D03 may run once to distinguish direction/first-message behavior; record the distinction. G01 runs only after some direct route demonstrates complete empty delivery, making it an informative comparison rather than a blind repetition. G02 requires complete G01 plus stream prerequisites; direct datagram success is not that prerequisite. Any skipped input is unproved, not passed.

Six correction slots repeat only named failed inputs after relevant source/oracle change with reason. Up to five final verifications consolidate older relevant-source observations on the final compiled candidate, at most once per input. Do not repeat passing identical-source cases. No scenario/parameter expansion, stress loop or automatic retry.

## Stop and outputs

Stop on exhausted quota/deadline or when remaining routes have no concrete changed mechanism; do not spend unused slots on another identical attempt. On normal/failure exit close the ledger, terminate owned children, remove fixture material and verify absence without secure-erasure claims. Publish exact per-invocation source/phase/outcome evidence and private log hashes, never key/cert bytes.

If empty direct datagrams fail too, keep the result and review whether an independently implemented peer or actual supported runtime route is available before more execution. Do not silently narrow scope or infer all OS versions are broken. If direct succeeds but group fails, the single-transport mixed requirement still blocks acceptance and needs an explicit adapter/owner decision. This experiment cannot close #179/#90, approve public APIs/F6 production or publish anything. Resumption/platform/callback production review and #29/#132 remain.

## Primary references and current CI

- [Apple NWParameters](https://developer.apple.com/documentation/network/nwparameters) and [quicDatagram](https://developer.apple.com/documentation/network/nwparameters/quicdatagram(alpn:)): selected construction API. Local SDK confirms availability; no compilation/runtime proof for this new route yet.
- [OpenSSL 3.6 QUIC introduction](https://docs.openssl.org/3.6/man7/ossl-guide-quic-introduction/): future datagram-extension support; existing stream client is not an independent application DATAGRAM peer.
- [OpenSSL packet injection](https://docs.openssl.org/3.5/man3/SSL_inject_net_dgram/): network-packet injection, not the application DATAGRAM extension.
- [Reviewed PR CI evidence](evidence/F6/CI_177_11E1B1B_2026-11-10.json): all seven checks on candidate 11e1b1b passed, full logs inspected. This is not main acceptance or specialized datagram runtime proof; PR #177 remains draft.
