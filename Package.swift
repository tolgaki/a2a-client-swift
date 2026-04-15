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
        .executableTarget(
            name: "TravelPlannerAgent",
            dependencies: ["A2AClient"],
            path: "Examples/TravelPlannerAgent"
        ),
        .executableTarget(
            name: "SmartTravelPlanner",
            dependencies: ["A2AClient"],
            path: "Examples/SmartTravelPlanner"
        ),
        .executableTarget(
            name: "HelloAgent",
            dependencies: ["A2AClient"],
            path: "Examples/HelloAgent"
        ),
        .executableTarget(
            name: "AgentInspector",
            dependencies: ["A2AClient"],
            path: "Examples/AgentInspector"
        ),
        .executableTarget(
            name: "StreamingNarrator",
            dependencies: ["A2AClient"],
            path: "Examples/StreamingNarrator"
        ),
        .executableTarget(
            name: "MultimodalMessenger",
            dependencies: ["A2AClient"],
            path: "Examples/MultimodalMessenger"
        ),
        .executableTarget(
            name: "TaskLifecycleDemo",
            dependencies: ["A2AClient"],
            path: "Examples/TaskLifecycleDemo"
        ),
        .executableTarget(
            name: "AuthShowcase",
            dependencies: ["A2AClient"],
            path: "Examples/AuthShowcase"
        ),
        .executableTarget(
            name: "PushNotificationDemo",
            dependencies: ["A2AClient"],
            path: "Examples/PushNotificationDemo"
        ),
        .testTarget(
            name: "A2AClientTests",
            dependencies: ["A2AClient"],
            path: "Tests/A2AClientTests"
        ),
    ]
)
