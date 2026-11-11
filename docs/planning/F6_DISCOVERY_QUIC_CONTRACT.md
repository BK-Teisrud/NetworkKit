# F6 discovery, listener, multicast and QUIC contract refinement

Working proposal, 2026-11-09. Tracking #90, same draft PR #177. This refines previously unapproved candidate semantics; it is not an owner scope/API decision or new execution authority. All original NK-11 requirements remain visible. No new compiler, connection, discovery scan, listener, multicast membership, certificate or device operation was run for this assessment.

## Evidence and design corrections

Official Apple documentation and the selected SDK interface were inspected. NWListener.newConnectionLimit is a decrementing remaining delivery allowance, not a concurrent connection cap; at zero the system can queue/block arrivals until credits are raised. NetworkKit must maintain its own ownership accounting and cannot promise an empty kernel/native backlog. [Apple remaining-credit semantics](https://developer.apple.com/documentation/network/nwlistener/newconnectionlimit).

NWBrowser delivers a full result Set. Bounding SDK-owned snapshots does not constrain that framework input, OS buffering or application-retained historical snapshots. Native multicast receive exposes maximumMessageSize/rejectOversizedMessages and an isComplete flag; an OS-discarded message may never reach the callback. Only SDK-observed drops can be counted. [Browser results](https://developer.apple.com/documentation/network/nwbrowser/browseresultschangedhandler), [group receive](https://developer.apple.com/documentation/network/nwconnectiongroup/setreceivehandler(maximummessagesize:rejectoversizedmessages:handler:)).

Native requiredInterface accepts an actual NWInterface value. Proposed public configuration may accept that existing Apple value rather than invent persistent interface-name strings or build an unrelated interface-enumeration/path-monitor feature. An interface restriction is not a firewall or peer identity. [Apple interface selection](https://developer.apple.com/documentation/network/nwparameters/requiredinterface).

These findings replace the older candidate's implicit active-cap equivalence, partial-browser-snapshot default and universal drop-count implication. Those earlier details were never approved contracts. New overflow behavior below is itself a proposal requiring final contract acceptance.

## Bonjour browser proposal

ServiceBrowserConfiguration selects exactly one valid DNS-SD service type and local. domain, includeTXTRecords=false by default, explicit maximumServices (1...1024), maximumTXTBytesPerService (1...4096), optional requiredInterface and peerToPeer=false. Type/domain are configuration values, never an all-services scan. TXT must preserve binary/empty/absent distinctions; use NWTXTRecord.data for bounded representation, not a lossy String-only dictionary. App Info.plist and permission declarations remain host-owned.

Prefer terminal overflow over silently incomplete discovery: if the native result count exceeds maximumServices or a selected TXT record exceeds its bound, stop the browser and fail with limitExceeded. Check result count before copying/constructing an SDK collection. Retain only one latest SDK snapshot plus a map of currently tracked IDs, bounded by maximumServices. Do not spawn an unbounded Task per result callback or retain a result-history queue. Native/OS set memory remains outside that bound. Do not sort an unbounded input array before applying the limit.

ServiceSnapshot proposed fields: revision: UInt64 and services: [DiscoveredService]. DiscoveredService has id: UUID, opaque NativeEndpoint, service name/type/domain, interface values and optional raw TXT data. Descriptions redact name/endpoint/TXT. UUID is stable while an entry remains tracked, not a permanent device identity; removed/reappearing entries may get a new ID. Changes in metadata preserve a tracked endpoint's ID. Returned snapshots are values; application retention is outside SDK ownership guarantees.

Refine pull signature to `nextSnapshot(after revision: UInt64? = nil, timeout: TimeInterval) async throws -> ServiceSnapshot`. Nil returns current immediately; an older revision returns the latest; current revision waits for a newer snapshot. A future revision fails locally. One waiting caller only; no automatic event stream or global implicit cursor. Starting ready is not evidence of discovered devices; a genuinely empty snapshot is valid. Revision overflow fails/stops rather than wraps. Cancellation/timeout removes only that waiter and leaves the browser running; stop is idempotent, closes admission and terminates any waiter. Actual NWBrowser failure/overlimit stops it; restart requires a fresh browser.

A discovered endpoint is a scoped capability, not an authenticated device or durable address. The connection revalidates its browser token/tracked record before native admission. Browser stop/removal prevents new admissions through that stale token; it does not close a connection already handed to another owner. Network resolution may still fail after successful validation.

## Local listener proposal

ListenerBinding is explicit loopback or required local interface (NWInterface), with selected port/zero for assignment. No implicit all-interface listener. API cannot promise that binding excludes every routed remote peer; authentication and host network policy remain separate. No generic server framework, background service, automatic firewall/entitlement change or Internet exposure setup.

ListenerConfiguration requires maximumPendingConnections (1...128), maximumConnections (1...1024), bounded startup/handshake timeout, TLS/client-auth policy or explicit plaintext acknowledgement, and optional one-service Bonjour advertisement. Pending, handshaking and handed-off live connections each occupy a total-cap lease. A pending connection also consumes the pending cap. A separate internal atomic/serial admission gate reserves before actor scheduling, so a callback burst cannot create unbounded unreserved Tasks.

Use native remaining credits only as a conservative delivery control, alongside SDK leases. Replenish credits from actual available capacity after an owned connection releases its lease. Zero native credits does not mean zero OS backlog. Overflow callbacks are cancelled, not silently retained. The exact credit/lease synchronization must be verified, not inferred from reading the property.

Ownership states: received -> reserved/pending -> native ready -> handoff committed -> app-owned; failure/cancel/stop before commit closes and releases exactly once. `accept(timeout:)` allows one waiter. Its cancellation removes that waiter without stopping the listener when no handoff has committed; a handoff already committed wins and returns an owned connection, rather than leaking it through a post-handoff cancellation check. Stop cancels unhanded pending/handshaking connections and the accept waiter, but never already app-owned connections. Stop/restart requires a new listener identity.

Handed-off connections hold a once-only lease release token. The registry holds counts/state, not strong connection references. Native callbacks must not strongly cycle through public actors and prevent fallback cleanup. Explicit close is primary; deinit cleanup is best effort and cannot promise immediate OS resource drain. Caller-retained or active-operation-retained connections remain app-owned until close/terminal cleanup. Test abandoned wrapper, active operation, listener stop, late callback and double-release separately.

Advertisement has its own readiness/failure/removal observations. Port ready alone does not mean Bonjour registration succeeded. If advertising is requested, start returns only after both selected conditions or fails/cleans up within the startup budget. TXT/service names are app-owned input with explicit length validation, not peer authentication. Do not advertise before a failed secure configuration is validated.

## Multicast proposal

MulticastConfiguration selects one concrete IPv4/IPv6 multicast group plus port, required interface, maximumDatagramBytes (1...65507), maximumPendingDatagrams (1...128), startup/send/receive limits and explicit unencrypted group-traffic acknowledgement. No arbitrary service enumeration, automatic all-interface joins, broadcast or source-specific multicast profile is silently implied. If source filtering is later selected, it gets an explicit contract/evidence entry. Native peer-to-peer is not a multicast route guarantee.

Set native maximumMessageSize explicitly and rejectOversizedMessages=true; never inherit Int.max. Reject/drop an incomplete or overlimit callback rather than deliver truncated data as a complete datagram. Hold a bounded queue of complete SDK-owned datagrams; fixed overflow rule drops the newest. No unbounded Task per callback. Queue byte multiplication and count arithmetic are checked before admission. Native buffers are not globally capped by these rules.

MulticastDatagram proposed fields: payload: Data, untrusted sender: NativeEndpoint?, sdkDiscardedSinceLastDelivery: UInt64 and discardCountSaturated: Bool. Only actual SDK-observed overflow/invalid callbacks increment that saturating counter; OS-suppressed oversize packets and network loss are unobservable. A zero counter is not proof of lossless delivery. Read/reset the delivery counter atomically with dequeue; unknown sender stays nil, never a fabricated source. Default diagnostics exclude sender/group/payload.

One active receive and one send may overlap. Empty datagram is valid. Join readiness does not prove another member can hear the group. Leave is idempotent and ends channel admission/queued ownership. Active send/receive cancellation closes that channel when datagram delivery state is uncertain. No retry/reliable multicast/custom encryption; the app's protocol must authenticate/encrypt payloads where needed. Permission/entitlement failures are recorded honestly, without disabling system restrictions.

## QUIC proposal

Model one encrypted transport group separately from its streams and optional datagram flow. Client configuration requires exact server endpoint/name, app-owned ALPN list, TLS policy, mandatory maximumOpenStreams, maximumPendingIncomingStreams, per-stream I/O limits, initial connection/stream receive-credit configuration, startup/idle/close deadlines and optional explicit datagram limits. Initial receive credits and native stream transport parameters are not a global memory cap or the SDK's active-stream lease count. No HTTP/3 implementation, hidden 0-RTT, reconnect, fallback to TCP, session resumption key export or general server platform.

Proposed actors and method shapes:

| Owner | Candidate operations | Lifecycle |
| --- | --- | --- |
| QUICConnection | `static connect(configuration:) async throws`; `openStream(direction:) async throws -> QUICStream`; `acceptStream(timeout:) async throws -> QUICStream`; `sendDatagram(_:) async throws`; `receiveDatagram(timeout:) async throws -> Data`; `close() async` | Owns one transport group, child stream leases and at most one native datagram flow; closing cancels all children |
| QUICStream | `send(_:) async throws`; `receive(maximumBytes:timeout:) async throws -> Data?`; `finishSending() async throws`; `close() async` | Direction is bidirectional/sendOnly/receiveOnly; invalid-direction calls fail before side effects. Stream EOF and send FIN are distinct |

Outgoing streams choose bidirectional or unidirectional; an accepted unidirectional stream is receiveOnly. Maintain explicit active and pending stream leases, not a borrowed TCPConnection wrapper. Duplicate same-direction operations fail; opposite directions may overlap when the stream permits it. Stream close must not accidentally close siblings/group; this requires native proof. Transport close does terminate all child I/O with a defined error. Queued but unhanded incoming streams are cancelled on overflow/stop, never accumulated without bounds.

Datagrams are independently enabled and negotiated; use one extracted datagram flow per group, not one flow per message. Datagrams preserve empty-message semantics, have a negotiated/native maximum and are not reliable byte streams. Stream-only, datagram-only and mixed mode must be observed separately: success in one mode is not evidence for the others. Enabling datagrams must not route stream bytes into the datagram handler. Wrong ALPN, untrusted peer, unsupported datagrams, peer-initiated streams, stream cancellation, flow control and shutdown need explicit negative controls. Application protocol selection is caller-owned; an ALPN string alone does not implement that protocol.

Proposed SDK maxima for review: maximumOpenStreams 1...256, pending incoming 1...maximumOpenStreams, datagram queue 1...128, explicit byte limits and positive finite timeouts. Final Swift enum/config/error signatures, transport-credit mapping and ownership implementation remain unapproved until the selected native shape is proven. No raw native object or unchecked Sendable wrapper becomes public merely to make extraction compile.

## Peer-to-peer and physical boundaries

Apple TN3151 distinguishes Apple peer-to-peer Wi-Fi from Wi-Fi Aware and points tvOS-to-mobile discovery to DeviceDiscoveryUI. includePeerToPeer does not establish Android/Wi-Fi Direct interoperability, consent UI, pairing or peer authentication. Do not add Wi-Fi Aware, MultipeerConnectivity, a device-picker UI or new framework product implicitly. Keep the explicitly opted-in native peer-to-peer candidate and record actual physical route evidence separately. Ordinary direct watchOS native support remains excluded by the owner's decision; HTTP Watch/#132 unchanged. [Apple API selection](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api).

## Verification groups to prepare together

1. Deterministic discovery snapshots/overflow, waiter cancellation, endpoint-token invalidation; listener credit/lease/race models; multicast observed-drop counter and queue models; QUIC stream/direction/lease models.
2. Controlled loopback listener with actual bounded handoff/stop/overflow, framing above real stream callbacks and no uncounted health-check connection.
3. Controlled native QUIC client/peer with selected ALPN, trust fixtures, both stream directions, datagram-only and mixed modes, wrong-mode controls and cleanup. A same-framework paired peer is correlated evidence, not independent interoperability.
4. Explicitly declared synthetic Bonjour advertisements/browses, interface restriction and granted/denied permission evidence. Scope the service types, advertisement count/lifetime and returned metadata; never a general LAN scan.
5. Physical multicast/peer-to-peer and cross-platform routes with actual required capabilities; no setting/account/signing changes without concrete authority. Simulator results cannot replace permission/radio proof.

Prepare these as a single reviewable research execution package with separate real route gates, rather than a PR per scenario. No execution is authorized here; old quotas are not reused. Existing host profiles/entitlements cannot be assumed adequate for a new host. Unavailable physical/capability routes remain gaps needing an owner decision, not silent feature removal or fake passes.

## Independent QUIC peer finding

Read-only local help inspection found the existing OpenSSL 3.6.1 s_client supports -quic, while s_server help does not offer a -quic server mode. No executable was launched without -help and no listener/connection was created. Therefore do not assume the existing TLS fixture can become an independent QUIC server by adding one flag. A potential OpenSSL client could verify a selected Network-framework peer stream, but its datagram/multi-stream coverage remains unproven. Do not install/build another library or claim interoperability from this metadata. Decide an independent-peer route explicitly, preserving the no-new-dependency rule for the shipped package.

## Planning disposition

No native capability is declared delivered, dropped or Ready for production. #90 remains In Progress; #178's selected correction is In Review pending the same PR/main and does not block independent design. Native API candidates must incorporate the corrected revision/overflow/credit/drop/stream ownership rules before final owner approval. One planning PR and one later integrated implementation PR remain the target; no new milestone/module/OS-floor increase is justified by this review.
