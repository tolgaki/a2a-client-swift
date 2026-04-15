# a2a-client-swift → a2a-swift

> **This repository has been superseded by [`a2a-swift`](https://github.com/tolgaki/a2a-swift).**

Starting with **1.0.20**, this package is a thin re-export shim that depends on [`a2a-swift 1.1.0`](https://github.com/tolgaki/a2a-swift) and re-exports its `A2AClient` product under the same name. Existing consumers need no source code changes — `import A2AClient` continues to work.

`a2a-swift` is the successor project: a unified Swift package that provides **both client and server** support for the A2A Protocol v1.0. All future development, bug fixes, and releases happen there.

## Migration

### Recommended

Switch your SPM dependency from `a2a-client-swift` to `a2a-swift`:

```swift
// Before
dependencies: [
    .package(url: "https://github.com/tolgaki/a2a-client-swift.git", from: "1.0.19")
]

// After
dependencies: [
    .package(url: "https://github.com/tolgaki/a2a-swift.git", from: "1.1.0")
]
```

Your existing `import A2AClient` statements keep working. No code changes required.

### Transitional (stay on this package)

You can also stay on this package and receive 1.0.20+, which will transitively pull `a2a-swift` and re-export its `A2AClient`. This works, but the repo will be archived after a short transition period, so we recommend switching.

```swift
dependencies: [
    .package(url: "https://github.com/tolgaki/a2a-client-swift.git", from: "1.0.20")
]
```

## Deployment target change in 1.0.20

`a2a-swift` requires **macOS 14 / iOS 17 / tvOS 17 / watchOS 10 / visionOS 1** (previously macOS 12 / iOS 15 in `a2a-client-swift ≤ 1.0.19`). This bump is required by Hummingbird 2.x on the server side; the client side happens to ride along.

If you need to stay on macOS 12 / iOS 15, pin to `1.0.19`:

```swift
.package(url: "https://github.com/tolgaki/a2a-client-swift.git", exact: "1.0.19")
```

## Why the move?

The original `a2a-client-swift` was client-only. As `a2a-swift` added a server runtime, the code needed to be shared between client and server (wire types, SSE parser, endpoint definitions). Splitting the code into `A2ACore` / `A2AClient` / `A2AServer` targets required a new package structure. Rather than evolve this repo into a server-capable thing (which would break the name), we moved to a new repo with a name that reflects the new scope.

## Version history prior to 1.0.20

For the history of this package through 1.0.19, see [`CHANGELOG.md`](CHANGELOG.md) and the git log. Every fix in 1.0.15 → 1.0.19 (spec compliance, REST paths, .NET agent card decoding, error codes, etc.) is preserved verbatim in `a2a-swift` 1.1.0.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
