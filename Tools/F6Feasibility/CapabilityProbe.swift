// Offline declaration/type-check probe only; never starts networking or accesses credentials.
import Foundation
import Security
import CryptoKit
import Network

struct SigningHandle: Sendable {
    let keyID: String
    let authenticate: @Sendable (Data) async throws -> Data
}
struct IdentityReference {
    // CF Sendable/ownership is deliberately not promised by this probe.
    let identity: SecIdentity
    let chain: [SecCertificate]
}
func syntheticMAC(_ bytes: Data, key: SymmetricKey) -> Data {
    Data(HMAC<SHA256>.authenticationCode(for: bytes, using: key))
}
#if !os(watchOS)
func connectionTypes(_ connection: NWConnection, _ browser: NWBrowser,
                     _ listener: NWListener, _ group: NWConnectionGroup,
                     _ quic: NWProtocolQUIC.Options, _ parameters: NWParameters) {
    let _: NWConnection.State = connection.state
    let _: NWBrowser.State = browser.state
    let _: NWListener.State = listener.state
    let _: Bool = parameters.includePeerToPeer
    let _: Int = quic.maxDatagramFrameSize
    _ = group
}
#else
// Watch deliberately has no native wrapper declarations; this does not prove device policy.
struct WatchHTTPOnlyMarker: Sendable {}
#endif
