// swift-tools-version: 6.2
import PackageDescription

// Opt-in verification package, never a dependency/product of the distributed SDK.
let package = Package(
    name: "NetworkKitPublicHTTPSChecks",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10), .tvOS(.v17)],
    dependencies: [.package(name: "NetworkKit", path: "../..")],
    targets: [.testTarget(name: "PublicHTTPSChecksTests", dependencies: [
        .product(name: "NetworkKit", package: "NetworkKit"),
    ])],
    swiftLanguageModes: [.v6]
)
