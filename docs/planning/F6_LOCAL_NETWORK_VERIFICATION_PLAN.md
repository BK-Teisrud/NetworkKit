# F6 independent local-network verification preparation

Prepared 2026-11-11 under #90/#18, same draft PR #177. Planning only: no code, browse/advertisement, network packet, simulator boot, signing or account/capability change authorized. This lane can progress independently of the specific #179 QUIC blocker; it does not remove that blocker or create a production-start decision.

## Consolidated work to complete before exact local API adoption

| Work | Concrete output / gate |
| --- | --- |
| Host capability inventory | Per-platform app type, sandbox, Info.plist service declarations, required entitlement and physical route; unknown remains unknown |
| Browser semantics | Ready/empty state, stable lifetime-scoped IDs, revision/waiter cancellation, add/update/remove, hostile TXT/record sizes and terminal overflow; native full-result memory not SDK bounded |
| Listener ownership | Explicit binding, pending plus active leases, exactly-once release, stop versus handoff; native credits are not an active cap |
| Advertisement lifecycle | One declared synthetic service type/name, bounded lifetime/metadata and verified stop; no general service enumeration |
| Multicast | Explicit group/interface, actual complete messages, empty/overlimit handling, bounded SDK queue/drop accounting and leave; native loss remains unobservable |
| Peer-to-peer | Chosen actual physical route and consent; native flag is not pairing/authentication or universal radio compatibility |
| Permission negatives | Real denied/granted behavior on applicable devices, separate from no peer/interface/timeout; simulator cannot supply permission/radio proof |

Apple TN3179 distinguishes iOS/iPadOS local permission and multicast entitlement from macOS permission/sandbox and tvOS's lack of the same privacy prompt. Bonjour uses explicit declared service types; arbitrary type enumeration may need additional capability. Do not infer a permission grant from command-line loopback success or request a restricted entitlement without a concrete owner decision. No existing device/profile approval automatically covers a new F6 host.

## Evidence levels and order

1. Finish side-effect-free validators/state contracts and the operation-specific host requirements matrix, against official sources and SDK declarations.
2. Prepare one consolidated deterministic/native execution manifest with exact synthetic service type, advertisement count, browse window, packet/byte/group/interface and teardown limits. No broad LAN scan.
3. Obtain specific code/network/material authorization before any executable probe. Prepare unsigned host artifacts first where appropriate; resolve signing/device/account changes separately with a concrete reviewable host.
4. Verify selected route behavior, ownership/stop/overflow and permission negatives; retain raw private and sanitized public evidence.
5. Adopt exact public semantics and derive real implementation tasks only after evidence or an explicit owner disposition. No precise Ready production issues from a model-only result.

Keep these requirements under existing #90/#18 while the consolidated contracts are being prepared; no new issue per test or artificial dependence on a separate #179 merge. Any future bounded independent execution issue should cover a coherent route/capability need. Do not silently move physical/permission gates to publication merely because earlier F4/F5 accepted different boundaries.

Primary sources: [Apple TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), [TN3151](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api). This plan adopts no new execution or platform scope.
