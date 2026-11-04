// swift-tools-version: 6.2
import PackageDescription

// Opt-in verification package, never a dependency/product of the distributed SDK.
let package = Package(
    name: "NetworkKitPublicHTTPSChecks",
    platforms: [.macOS(.v15), .iOS(.v18), .watchOS(.v11), .tvOS(.v18)],
    dependencies: [.package(name: "NetworkKit", path: "../..")],
    targets: [.testTarget(name: "PublicHTTPSChecksTests", dependencies: [
        .product(name: "NetworkKit", package: "NetworkKit"),
    ])],
    swiftLanguageModes: [.v6]
)
