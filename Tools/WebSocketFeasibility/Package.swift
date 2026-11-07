// swift-tools-version: 6.2
import PackageDescription

// Isolated, non-shipping experiment. No dependency on the NetworkKit SDK.
let package = Package(
    name: "WebSocketFeasibility",
    platforms: [.macOS(.v15)],
    targets: [.executableTarget(name: "WebSocketFeasibility")],
    swiftLanguageModes: [.v6]
)
