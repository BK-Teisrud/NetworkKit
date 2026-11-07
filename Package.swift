// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .tvOS(.v18),
    ],
    products: [
        .library(name: "NetworkKit", targets: ["NetworkKit"]),
    ],
    targets: [
        .target(name: "NetworkKit", resources: [.copy("PrivacyInfo.xcprivacy")]),
        .testTarget(name: "NetworkKitTests", dependencies: ["NetworkKit"]),
    ],
    swiftLanguageModes: [.v6]
)
