# F6 QUIC adapter and error-contract review

Prepared 2026-11-09 for #179/#90, same draft PR #177. Read-only source/documentation assessment following the closed [completion investigation](F6_QUIC_COMPLETION_RESULTS_2026-11-09.md). No new experiment code, compiler, transport, fixture material, dependency or OS change. This document proposes an owner decision, not a waiver or runtime authority.

## Finding 1: empty datagrams remain a delivery gap

RFC 9221 section 4 explicitly allows zero-length DATAGRAM payloads. Section 5 distinguishes application delivery from transport acknowledgement and defines unreliable delivery. Therefore no received callback cannot become an empty-message result, and send processing cannot establish receipt. A small loopback failure does not establish a universal OS limitation.

The prototype now distinguishes actual empty dispatch content from missing content, arms each receive before send, and records negotiated capacity. The nonempty message passes; empty delivery remains unproved. Another run of the same input/bridge is not a supported fix. Do not add a marker byte or silently wrap raw datagrams: that changes the peer's wire protocol. Do not substitute a reliable stream or call it a datagram. Preserve Q04 and Q05 requirements and failures.

A future targeted investigation must identify a concrete supported native send/receive mechanism or a controlled independent datagram peer before new execution. The existing OpenSSL stream control does not provide independent datagram proof. No new library/server/tool installation is selected.

## Finding 2: the native-error oracle is stricter than the proposed public safety contract

Q06 specifically requires NWError.tls; Q07 requires a qualifying native terminal error plus a trust witness, with a controller that recognizes a TLS-shaped description. On the current group adapter, bad handshakes yield no client-group terminal callback before the bounded deadline; the peer reports POSIX EINVAL and the trust case records a real local rejection. These are retained failures of the selected native-error observation. They are not evidence that application data was accepted.

Apple documents group states and NWError categories but the sources reviewed do not establish that every QUIC handshake failure must be delivered as the exact TLS error shape required by this oracle. Matching a string description is also not an appropriate production error-classification boundary. No claim is made that all native callbacks are absent on every supported OS.

A production adapter must have its own one-result startup ownership and deadline. An absent native callback cannot leave an SDK connect call pending indefinitely. Conversely, a generic native POSIX failure cannot be diagnosed as a certificate or ALPN error merely to satisfy a test.

## Recommended contract direction — owner approval pending

1. Startup owns one monotonic budget covering setup/trust and native establishment. It returns at most one connection or one error. Cancellation and close seal admission; late callbacks cannot publish a connection or revive a completed call.
2. A real rejection made by the adapter's own trust-verification callback may complete logical startup with a redacted trustRejected error and cancel the native group. No waiting for a specific native TLS code is required to report the decision the adapter actually made. This is not proof that all OS work has drained.
3. Native errors that have no independently established security diagnosis remain sanitized transport errors. If no terminal native/verification result arrives, expiration returns startup timeout; it is never relabelled certificateRejected or alpnMismatch.
4. Before exposing a ready connection, reading application data or admitting a send, independently validate the negotiated ALPN against the explicit requested set and validate the admitted trust result. A mismatch actually observed there may be classified as ALPN mismatch. No usable connection is handed off on a partial/native-ready signal alone.
5. Negative acceptance requires the intended controlled input, a matching valid positive control, no connection/data admission, exactly one bounded logical outcome and clean logical shutdown. The trust case additionally requires the actual rejection witness. A timeout by itself or an unrelated network failure without controls is insufficient evidence that the security input was exercised. A native TLS-domain code is additional diagnostic evidence, not a universal prerequisite.
6. Preserve the original Q06/Q07 failed probes as history. New logical-startup tests have separately named expectations and require their own reviewed implementation/execution scope; never rewrite the old ledger to passed. Deterministic tests must prove late-result suppression and ALPN/trust admission races, alongside native controlled negatives.

This changes the proposed acceptance/error boundary and therefore needs explicit owner agreement before adoption. It does not implement or automatically satisfy #179, relax system trust, accept a mismatching ALPN, authorize production code or resolve empty datagrams. Exact public error types and method signatures remain part of #90's later complete-contract decision.

## Finding 3: the newer Swift QUIC API is an alternative to assess, not an automatic fix

The installed Network.swiftinterface declares QUIC, QUICDatagram and the async datagrams channel at macOS/iOS/tvOS 26. Apple TN3213 documents separate reliable streams and one best-effort datagram channel. Our relevant current floors are macOS 15 and iOS/iPadOS/tvOS 18. New API declarations do not prove corrected empty-message or failure behavior on a real runtime, and the current Mac 15.8.1 cannot execute an OS-26-only adapter.

Do not raise all package floors, upgrade the Mac or introduce two production QUIC adapters merely to escape an unverified prototype failure. A future OS-26-only capability could be assessed independently with explicit availability and real runtime access, but is not selected by this review. HTTP/watchOS decisions remain unchanged.

## Priority and delivery consequences

Keep #179 Open/Blocked for native empty-datagram/mixed proof and the pending error-contract decision. Avoid another near-identical budget/approval cycle without a changed mechanism. No new issue, milestone, module or PR is justified by this review. #90 may continue independent security integration, platform, Bonjour/multicast/P2P planning while these specific QUIC gates remain visible. The one-plan/one-delivery-PR target remains.

If the owner accepts the recommended error direction, record that planning decision and prepare a small, explicit logical-startup design/test scope. Empty-message support stays unresolved unless a separately supported route is demonstrated or the owner explicitly chooses a scope disposition. No deferral is inferred. #13/#18 and publication barriers #29/#132 remain open.

## Primary references and local evidence

- [RFC 9221 sections 4–5](https://www.rfc-editor.org/rfc/rfc9221.html): empty payloads, unreliable datagrams and application delivery distinction.
- [Apple group states](https://developer.apple.com/documentation/network/nwconnectiongroup/state-swift.enum): ready/waiting/failed/cancelled API model, not a guarantee of a particular QUIC TLS error code.
- [Apple TN3213](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework): modern QUIC streams/datagram-channel model.
- Installed Network.swiftinterface: availability for QUIC/QUICDatagram and actual legacy declarations; declaration inspection only, no additional compilation/runtime evidence.
- [Completion result and hashed observations](F6_QUIC_COMPLETION_RESULTS_2026-11-09.md): current native behavior and retained failures, not general platform conclusions.
