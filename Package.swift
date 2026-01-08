// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "a2a-client-swift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "A2AClient",
            targets: ["A2AClient"]
        ),
    ],
    targets: [
        .target(
            name: "A2AClient",
            path: "Sources/A2AClient"
        ),
        .testTarget(
            name: "A2AClientTests",
            dependencies: ["A2AClient"],
            path: "Tests/A2AClientTests"
        ),
    ]
)
