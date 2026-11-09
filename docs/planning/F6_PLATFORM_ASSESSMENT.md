# F6 platform and integration assessment

Working proposal, 2026-11-09. Tracking #90 / draft PR #177. Source inspection plus the separately authorized [four SDK type-check probes](F6_OFFLINE_RESULTS_2026-11-09.md). No F6 native runtime execution.

## Owner decision

On 2026-11-09 the owner approved designing direct TCP/UDP, Bonjour, listeners, QUIC and multicast for iOS/iPadOS, macOS and tvOS. Direct ordinary-app watchOS support is outside this native-networking design. Existing HTTP Watch support and #132 are unchanged. No audio/VoIP/DeviceDiscoveryUI exception or entitlement workaround is selected. Security-on-HTTP availability on Watch remains a separate capability question, not automatically excluded or verified by this decision.

## Evidence levels

Distinguish SDK declarations, documented runtime policy, compilation and executed behavior. The first two were inspected here; declaration/type-check evidence now exists for selected candidate shapes; native runtime evidence remains pending. The active SDK selected by xcode-select is /Applications/Xcode.app/Contents/Developer. Network.swiftmodule/x86_64-apple-macos.swiftinterface declarations list NWConnection/NWListener at macOS 10.14/iOS 12/tvOS 12, NWBrowser at 10.15/13/13, NWConnectionGroup/NWMulticastGroup at 11/14/14 and QUIC parameter initialization at 12/15/15. These lie below current package floors, but a macOS interface is not a cross-SDK consumer compilation or runtime entitlement proof. Record actual Xcode/SDK version/build and each platform header/compilation result before exact-contract approval; do not infer support solely from these declarations.

| Area | iOS/iPadOS 18+ | macOS 15+ | tvOS 18+ | watchOS 11+ |
| --- | --- | --- | --- | --- |
| HTTP system trust/redirect foundations | Existing delivered scope | Existing delivered scope | Existing delivered scope | Existing delivered scope, physical barrier retained |
| ATS pin configuration | Candidate app-owned configuration; integration proof needed | Same | Same | Assess HTTP-specific policy separately |
| SDK pin policy / client identity | Candidate; delegate and account isolation proof needed | Same | Same | Assess Foundation path separately; no claim yet |
| Keychain/CryptoKit helpers | Platform declarations/accessibility/hardware review pending | Hardware and access-control differences pending | API/accessibility/hardware review pending | API/accessibility/hardware review pending |
| NWConnection TCP/UDP/TLS | Native candidate; local permission where applicable | Native candidate; sandbox/permission review | Native candidate; runtime route proof pending | Excluded by owner decision for ordinary apps |
| QUIC application protocol | Candidate; peer/ALPN/flow-control proof needed | Same | Same | Excluded |
| Bonjour browse/advertise | Declared service types and host configuration | Host configuration/signature/sandbox review | No local-network privacy prompt per TN3179; host/API rules still apply | Excluded |
| Local listener | Candidate; bounded accepted-connection ownership | Same; server sandbox capability where applicable | Candidate, no background/server-platform promise | Excluded |
| Native peer-to-peer option | Radio/route and physical proof needed | Same | Actual hardware route support unresolved | Excluded |
| Multicast | Restricted entitlement/access and physical proof | No multicast entitlement per TN3179; permission/sandbox still relevant | Entitlement/capability and physical behavior unresolved | Excluded |

No unsupported cell is made green by increasing the OS floor. No blanket floor bump, new product/module or platform removal is proposed.

## Host responsibilities and runtime limits

Apple TN3179 distinguishes permission, operation and platform. iOS/iPadOS and macOS have local-network privacy; tvOS does not have that privacy facility. For selected local access the host supplies an accurate usage description and, for Bonjour, specific declared service types. Ordinary declared Bonjour operations must not be confused with arbitrary service enumeration or raw multicast. iOS/iPadOS multicast needs the restricted capability; macOS does not require that entitlement. Receiving an incoming TCP connection is not itself an outgoing-local-access permission case. Host sandbox entitlements and each operation still require separate assessment.

Simulators do not validate local-network permission behavior. For native Watch policy, TN3135 also warns that simulator behavior differs from devices. Native tests must separate loopback, same-LAN, peer-to-peer and multicast routes. None is interchangeable. Denial, unavailable interface and no server response must not all become a fabricated permissionDenied error. Preserve a narrow native error domain/code where classification is uncertain, without exposing hostnames or addresses.

The SDK cannot grant permissions, edit host Info.plist/entitlements, request restricted capabilities, or keep an app alive by itself. No scan/listener is started by constructing configuration or importing the module. App activation governs chosen foreground lifetimes; no background execution promise.

## Integration findings from current source

- NetworkTaskDelegate.challengeDisposition currently permits default server-trust handling and rejects other challenge methods. mTLS therefore requires an intentional reviewed extension, not merely passing a URLCredential into the existing auth provider.
- WebSocketSessionTransport has its own task/session challenge callbacks. HTTP integration does not establish WebSocket identity support.
- AuthenticationContext intentionally omits path/query/body/headers. AuthenticationHeaderProvider cannot serve as a body/request-signing provider without violating its documented privacy boundary. Keep it unchanged and design a separate opt-in signing context.
- Existing redirects and prepare-once retry policy cannot silently replay signed or identity-bound operations. Signed profiles need explicit replay/redirect compatibility checks before network admission.
- Injected sessions retain app ownership. The SDK cannot promise control over their session-level challenge delegate. Recommend initially rejecting SDK-managed TLS/client-identity policy with injected sessions, before network admission, unless a later native proof establishes a sound narrower path. Existing injected-session behavior without new policy stays compatible.

## References

Inspected official Markdown content and local SDK source on 2026-11-09:

- [TN3135](https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos): ordinary Watch restrictions and exceptions; only the restriction affects this design.
- [TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy): platform privacy matrix, operation distinctions, entitlement and simulator limitations.
- [Secure Enclave keys](https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave): special key capabilities; no arbitrary imported-key vault claim.
- [NWParameters](https://developer.apple.com/documentation/network/nwparameters), [Network](https://developer.apple.com/documentation/network): API candidates; no runtime evidence implied.
