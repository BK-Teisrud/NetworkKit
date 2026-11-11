// Declaration-only probe; no function in this file is invoked.
import Foundation
import Network
import Security
struct IdentityCarrier179: Sendable { let credential: URLCredential }
#if !os(watchOS)
func nativeShapes179(_ listener: NWListener, _ group: NWConnectionGroup, _ browser: NWBrowser,
                     _ parameters: NWParameters, _ interface: NWInterface, _ quic: NWProtocolQUIC.Options) {
    let _: Int = listener.newConnectionLimit
    parameters.requiredInterface = interface
    let _ = listener.newConnectionGroupHandler
    let _ = group.newConnectionHandler
    let _ = group.extract(connectionTo:using:)
    let _ = browser.browseResultsChangedHandler
    let _: Bool = quic.isDatagram
    let _: Int = quic.maxDatagramFrameSize
}
#else
struct OrdinaryWatchNativeExcluded179: Sendable {}
#endif
