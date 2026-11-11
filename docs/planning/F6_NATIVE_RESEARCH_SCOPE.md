# F6 consolidated native research execution proposal

Proposed only, 2026-11-09. Tracking #179, parent #90, same draft PR #177. This is a new non-shipping experiment, not covered by earlier Mac/#178 execution quotas or a production-code decision. The [contract refinement](F6_DISCOVERY_QUIC_CONTRACT.md) provides hypotheses, not approved production semantics. The owner subsequently authorized this exact scope. Execution is now closed with mixed results; see [results and consumed budget](F6_NATIVE_RESEARCH_RESULTS_2026-11-09.md). The original proposal below is retained as the authorization baseline.

## Purpose and boundaries

Prove the unresolved native mechanics of bounded listener handoff and QUIC group/stream/datagram ownership before final APIs are selected. Exercise discovery/multicast policy rules offline without silently turning their models into native or physical proof. Keep one planning PR; no new package/dependency/product/OS-floor change. No root SDK source, tests, CI, privacy manifest, app host, Apple account, entitlement, installed trust, signing identity or physical device changes.

Proposed code only under Tools/F6Feasibility/NativeResearch/. Existing helpers may be imported/reused without rewriting consumed source/hash ledgers. New source entry points: Values.swift, State.swift, ListenerPeer.swift, QUICPeer.swift, ProbeMain.swift, CapabilityProbe.swift and run_research.py. The Swift executable has explicit peer/probe modes, never networking at import/default startup. The Python controller owns admission/deadlines/child processes and the separate research ledger. Existing setup_native_fixture may create only the reviewed CA/server-current subset; no old generated material is reused.

All active networking is 127.0.0.1:0 loopback on this Intel Mac. No Bonjour advertisement/browse, LAN interface bind, multicast join/send, peer-to-peer radio, external endpoint or public availability request. Physical/other-platform discovery/multicast/peer-to-peer and app entitlements remain real gaps. A model test or QUIC pair does not mark those requirements delivered.

## New envelope proposed for approval

| Resource | Maximum |
| --- | --- |
| Compiler invocations | 8: four initial declaration-only SDK checks, one initial Mac executable build, three documented failed-build/candidate correction commands |
| Pure named policy/model cases | 40: 30 initial cases below, ten failed-case correction invocations |
| Local transport sessions | 25: 17 initial candidate transport sessions below, eight transport-session slots for failed-case corrections |
| External requests | 0 |
| Synthetic key/certificate pairs | 2: one fixture CA and one server-current, once only |
| Owned experiment children | 2 at a time; total at most five logical work processes |

A transport session is one candidate TCP/QUIC handshake/connection attempt, including one fixture peer accepting that same attempt. N02 deliberately creates two candidate sessions and consumes two slots. QUIC stream/datagram objects within one established transport are separately counted contexts, not new transport authority. Limit each QUIC endpoint to four native stream/datagram contexts per session; log endpoint/group/flow counts and reject unexpected extra creation rather than treating it as free activity. No hidden health checks or preflight sockets. OS retransmission/internal attempts are not claimed to equal application-controlled logical counts.

Failed/skipped attempts consume started slots. A correction repeats an identified failed initial input after a documented source change; never a new scenario or stress loop. Unused prior scope reserves cannot fund this package. No automatic retry/relearning, silent fallback to a different protocol or uncounted fixture probe.

## Exact declaration/build checks

One declaration-only check for each family: macOS 15 x86_64, iOS 18 arm64 simulator, tvOS 18 arm64 simulator, watchOS 11 arm64 simulator. Import native Security/Network types but create no object/task. Non-Watch branch checks selected listener/group/stream/interface signatures; Watch branch checks the proposed ordinary-app native exclusion marker and existing security carrier, not native runtime support. Actual public SDK availability still needs implementation consumer tests later.

One initial Mac executable build uses Swift 6, warnings-as-errors, selected macosx SDK and x86_64-apple-macosx15.0. Compiler commands are sequential, 120 seconds each, no app linking/signing or simulator boot. Total eight includes reserve commands; a failed SDK check also consumes its initial slot. All source files/commands/hashes are recorded before execution. No new SPM dependency or system tool installation.

## Exact initial pure cases

These are fixed design-rule inputs, not native proof. IDs are mode-scoped; no hidden parameter expansion. Use explicit expected behaviors and negative controls rather than merely checking a private field was set.

| Group | Named inputs |
| --- | --- |
| B01–B10 browser | B01 empty ready snapshot; B02 metadata update preserves a tracked ID; B03 removed record invalidates new endpoint admission; B04 stop invalidates new admission without cancelling an already transferred connection model; B05 duplicate waiter rejected; B06 current revision waits for newer; B07 future revision rejected; B08 service overflow terminates; B09 TXT overflow terminates; B10 revision overflow fails rather than wraps |
| L01–L06 ownership | L01 pending plus handed-off total cap; L02 double lease release does not create capacity; L03 handoff/stop ordered once; L04 handshake deadline releases unhanded lease; L05 release after stopped listener does not rearm native admission; L06 registry does not retain a handed-off wrapper |
| M01–M06 multicast | M01 zero payload is valid; M02 observed oversize callback rejected/counted; M03 absent native callback never fabricates a discard count; M04 full queue drops newest with explicit SDK counter; M05 delivery/reset is atomic; M06 saturation sets flag instead of wrapping |
| Q01–Q08 QUIC | Q01 direction-invalid operation has no side effect; Q02 active/pending stream bounds; Q03 transport termination resolves child waiters; Q04 stream close model leaves sibling open; Q05 only one datagram flow per group; Q06 oversize exceeds negotiated/caller bound; Q07 empty/invalid ALPN rejected; Q08 duplicate operation/backpressure has no unbounded waiter queue |

Pure cases run once each, five seconds per case and 120 seconds per initial suite. Concurrency observations are fixed bounded schedules/races, not a claim of exhaustive interleavings. A native test is still required where a model cannot establish Foundation/Network behavior.

## Exact initial local transport ledger

| ID | Candidate sessions | Required observation |
| --- | --- | --- |
| N01 | 1 | Loopback listener ready, one accepted/handed-off connection and actual close/lease release |
| N02 | 2 | Fill one total/pending capacity with first client; second arrival does not bypass SDK limit, native remaining-credit and SDK lease counters recorded |
| N03 | 1 | Stop while pending/handshaking cancels unhanded work, resolves waiter and releases lease once |
| N04 | 1 | Stop after committed handoff preserves app-owned connection until that owner closes |
| N05 | 1 | Dropping a handed-off wrapper with no active operation releases its SDK lease without a registry retain cycle; do not claim immediate OS drain |
| N06 | 1 | Apply actual loopback interface value observed on N01's path; ready/binding evidence or explicit inconclusive result, no hard-coded physical interface name or fallback LAN bind |
| Q01 | 1 | QUIC group with selected ALPN/test trust and bidirectional stream transfers fixed synthetic data |
| Q02 | 1 | Peer-initiated unidirectional stream is received through the correct handler/direction |
| Q03 | 1 | Locally initiated unidirectional stream transfers data; forbidden local receive fails before I/O |
| Q04 | 1 | Datagram-only flow preserves selected fixed/empty message semantics and only one flow extraction |
| Q05 | 1 | Mixed stream/datagram transport keeps stream bytes and datagrams separate, at most two streams plus one datagram flow |
| Q06 | 1 | Wrong ALPN fails with recorded handshake/protocol conditions; no generic success from timeout alone |
| Q07 | 1 | Untrusted fixture without its explicit test anchor fails; the scoped trusted positive Q01 is separate |
| Q08 | 1 | Close/cancel one stream and observe the selected sibling still usable; otherwise retain failed contract hypothesis |
| Q09 | 1 | Closing transport terminates its child operations, resolves waiters once, no new group admitted |
| Q10 | 1 | Existing OpenSSL QUIC client connects to native QUIC peer and verifies scoped fixture CA/hostname/ALPN plus one bounded stream exchange; independent client result, not independent datagram/multistream proof |

Initial session sum: seven TCP plus ten QUIC = seventeen. Reserved eight sessions only correct failed native cases; a repeated N02 consumes two. No more than four stream/datagram contexts per QUIC endpoint; record all native group/extraction calls, do not create standalone fresh transports as a shortcut for streams. Unexpected peer groups/extra explicit transports are recorded as a failure and consume remaining session allowance where visible; stop rather than exceed the envelope.

Each native case has a 20-second limit, at most 16 application messages and 64 KiB aggregate payload each direction per transport, four contexts per endpoint, and four pending/active fixture-side stream or TCP handles (separately one listener/transport group). Per group 180 seconds, total native batch ten minutes. Public addresses/other listeners never used. Native failure conditions and positive controls must match; a generic refused connection is not automatically wrong-ALPN/trust proof.

## Fixture and independent peer

Use only the existing reviewed OpenSSL executable and Python/native Apple APIs. Generate exactly CA/server-current under a private 0700 root, umask 077 and 0600 files, using the original approved command templates with explicit SAN localhost/127.0.0.1/serverAuth. Two pairs, no regeneration. No AIA/CRL URL, certificate/key bytes in GitHub, PKCS#12, Keychain item, installed root or personal signing identity. In-memory SecIdentityCreate supplies the native peer identity. A custom anchor is test-only on the explicit loopback evaluation, never a shipping policy or ordinary system-trust claim.

The peer announces assigned port through its readiness pipe, never a health-check connection. A native peer process plus a native candidate is at most two controller-owned children. For Q10 the existing OpenSSL client replaces the native candidate child, not an additional third child. Proposed bounded arguments: `openssl s_client -quic -connect 127.0.0.1:<assigned-port> -alpn networkkit-f6-test -CAfile <fixture-ca> -verify_return_error -verify_hostname localhost -servername localhost -quiet -no_ign_eof -no-CApath -no-CAstore`, with one fixed synthetic stdin message, keeping stdin open only until the bounded expected reply before closing it. Use a controlled child environment with OPENSSL_CONF=/dev/null and no inherited OPENSSL_ENGINES/OPENSSL_MODULES/SSL_CERT_FILE/SSL_CERT_DIR overrides; no user credentials or external lookup. Confirm metadata/help support without a connection before starting the counted input; unavailable feature is an explicit failure/inconclusive result, not permission to install another peer.

Earlier read-only inspection found no s_server -quic option; do not use the TLS fixture as a supposed QUIC server. Q01–Q09 use correlated Network-framework peers and must be labelled accordingly. Q10 provides one independently implemented client/stream control only. No third-party library is linked into the SDK or installed; no HTTP/3/general application protocol is claimed.

## Lifecycle, evidence and shutdown

The controller records every started case/command/source hash and quota before spawning. Validate packet/message/handle counters, real caller/native completion order and positive/negative controls. Preserve original failures, not only final green output. Interface N06 comes from N01's actual current path; if absent, mark N06 unproved without probing other interfaces. No default path monitor/module is added to the product.

On success/failure/timeouts, cancel only owned native work, close peer/probe children, wait two seconds, terminate/escalate only their process group with bounded wait, and retain private full logs plus sanitized public results. Never kill Xcode/user processes. Remove generated fixture material at batch end and verify absence; deletion is not secure erasure from backups or a crash guarantee. Failed native peers are not left advertising/listening.

## Authorization and remaining gates

This document proposes code and execution only for this entire isolated package; a separate owner decision is required. Nothing has run from it. Exact API defaults/semantics remain hypotheses to verify, not approved production contracts. No full F6 acceptance or feature deferral follows merely from successful experiment checks.

Native Bonjour/TXT/permissions, multicast delivery/capabilities, physical peer-to-peer, cross-platform runtime and complete public/API/production gates remain separate explicit work after this batch. Those require a future concrete route/executable/permission scope rather than silently borrowing loopback approval. Keep the broad inventory and the same PR; no new milestone, extra delivery PR or speculative production issue is justified by this proposal.
