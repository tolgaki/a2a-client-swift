// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// ─────────────────────────────────────────────────────────────────────────
// a2a-client-swift 1.0.20
//
// This package has been migrated to https://github.com/tolgaki/a2a-swift
// which now provides BOTH client and server support for the A2A Protocol
// v1.0 in a single unified package.
//
// `a2a-client-swift` 1.0.20 is a thin re-export shim: it depends on
// `a2a-swift 1.1.0` and re-exports its `A2AClient` product under the same
// name, so existing `.package(url: "…/a2a-client-swift", …)` declarations
// in consumer code keep working without any source changes.
//
// **To migrate**: switch your SPM dependency from
//     .package(url: "https://github.com/tolgaki/a2a-client-swift.git", from: "1.0.19")
// to
//     .package(url: "https://github.com/tolgaki/a2a-swift.git", from: "1.1.0")
//
// No `import` statements need to change — `import A2AClient` works in both.
//
// The `a2a-client-swift` repository will be archived after a transition
// period. All future development happens in `a2a-swift`.
// ─────────────────────────────────────────────────────────────────────────

let package = Package(
    name: "a2a-client-swift",
    platforms: [
        // Bumped from macOS 12 / iOS 15 to match a2a-swift 1.1.0.
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "A2AClient",
            targets: ["A2AClientShim"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tolgaki/a2a-swift.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "A2AClientShim",
            dependencies: [
                .product(name: "A2AClient", package: "a2a-swift"),
            ],
            path: "Sources/A2AClientShim"
        ),
    ]
)
