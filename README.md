# A2AClient

[![CI](https://github.com/a2aproject/a2a-client-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/a2aproject/a2a-client-swift/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

A Swift client library for the Agent-to-Agent (A2A) Protocol, enabling seamless communication between applications and AI agents.

## Quick Links

- [Documentation](DESIGN.md)
- [API Reference](https://a2aproject.github.io/a2a-client-swift/)
- [A2A Protocol Spec](https://a2a-protocol.org/latest/)
- [Issues](https://github.com/a2aproject/a2a-client-swift/issues)
- [Contributing](CONTRIBUTING.md)

## Overview

A2AClient provides a fully-featured implementation of the A2A Protocol for Apple platforms. It supports message-based communication, long-running task management, streaming responses, push notifications, and multiple authentication schemes.

### Platform Support

- iOS 15.0+
- macOS 12.0+
- watchOS 8.0+
- tvOS 15.0+

### Protocol Version

- A2A Protocol Version: 1.0

## Installation

### Swift Package Manager

Add A2AClient to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/a2aproject/a2a-client-swift.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: ["A2AClient"]
    )
]
```

### Xcode

1. Go to File > Add Package Dependencies
2. Enter the repository URL: `https://github.com/a2aproject/a2a-client-swift`
3. Select the version and add the package

## Quick Start

### Basic Usage

```swift
import A2AClient

// Create a client
let client = A2AClient(baseURL: URL(string: "https://agent.example.com")!)

// Send a message
let response = try await client.sendMessage("Hello, agent!")

// Handle the response
switch response {
case .message(let message):
    print("Response: \(message.textContent)")
case .task(let task):
    print("Task created: \(task.id)")
}
```

### Using the Convenience API

```swift
import A2AClient

// One-liner message sending
let response = try await sendMessage("Hello!", to: URL(string: "https://agent.example.com")!)

// Or use the A2A namespace
let client = A2A.client(url: URL(string: "https://agent.example.com")!)
let response = try await client.sendMessage("Hello!")
```

### Agent Discovery

```swift
// Discover an agent from a domain
let (agentCard, client) = try await A2A.discover(domain: "example.com")
print("Found agent: \(agentCard.name)")
print("Capabilities: \(agentCard.capabilities)")

// Send a message to the discovered agent
let response = try await client.sendMessage("Hello!")
```

## Core Concepts

### Messages

Messages are the primary unit of communication. Each message has a role (user or agent) and contains one or more parts:

```swift
// Simple text message
let message = Message.user("Hello, world!")

// Message with multiple parts
let message = Message.user(parts: [
    .text("Please analyze this image:"),
    .file(data: imageData, name: "photo.jpg", mediaType: "image/jpeg")
])

// Message with context for multi-turn conversations
let message = Message.user("Follow-up question", contextId: conversationId)
```

### Parts

Parts represent different types of content. The Part model uses a "oneof" pattern where exactly one content field should be set:

```swift
// Text content
Part.text("Hello, world!")

// File with raw data (base64 encoded in JSON)
Part.file(data: pdfData, name: "document.pdf", mediaType: "application/pdf")

// File by URL reference
Part.file(uri: "https://example.com/file.pdf", name: "document.pdf", mediaType: "application/pdf")

// URL reference without metadata
Part.url("https://example.com/resource")

// Raw bytes
Part.raw(binaryData)

// Structured data
Part.data(["key": "value", "count": 42])

// Check content type
let part = Part.text("Hello")
if part.isText {
    print(part.text!)  // "Hello"
}
```

### Tasks

Long-running operations return tasks that track progress:

```swift
// Send a message that creates a task
let response = try await client.sendMessage("Generate a report")

if let task = response.task {
    // Check task status
    print("Status: \(task.status.state)")

    // Wait for completion by polling
    while !task.isComplete {
        let updated = try await client.getTask(task.id)
        // Check updated.status.state
    }

    // Or subscribe to updates
    let stream = try await client.subscribeToTask(task.id)
    for try await event in stream {
        switch event {
        case .taskStatusUpdate(let update):
            print("Status: \(update.status.state)")
        case .taskArtifactUpdate(let update):
            print("New artifact: \(update.artifact.name ?? "unnamed")")
        }
    }
}
```

### Task States

| State | Description |
|-------|-------------|
| `submitted` | Task has been received |
| `working` | Task is being processed |
| `inputRequired` | Agent needs additional input |
| `completed` | Task finished successfully |
| `failed` | Task encountered an error |
| `cancelled` | Task was cancelled |
| `authRequired` | Authentication needed |
| `rejected` | Task was rejected |

## Streaming

For real-time updates, use streaming:

```swift
let stream = try await client.sendStreamingMessage("Generate a story")

for try await event in stream {
    switch event {
    case .taskStatusUpdate(let update):
        print("Status: \(update.status.state)")
        if let message = update.status.message {
            print("Message: \(message.textContent ?? "")")
        }

    case .taskArtifactUpdate(let update):
        print("Artifact: \(update.artifact.name ?? "unnamed")")
        for part in update.artifact.parts {
            if let text = part.text {
                print(text)
            }
        }
        
    case .task(let task):
        print("Task update: \(task.state)")
        
    case .message(let message):
        print("Message: \(message.textContent ?? "")")
    }
}
```

## Authentication

A2AClient supports multiple authentication methods:

### API Key

```swift
let config = A2AClientConfiguration(baseURL: url)
    .withAPIKey("your-api-key", name: "X-API-Key", location: .header)
let client = A2AClient(configuration: config)
```

### Bearer Token

```swift
let config = A2AClientConfiguration(baseURL: url)
    .withBearerToken("your-jwt-token")
let client = A2AClient(configuration: config)
```

### Basic Authentication

```swift
let config = A2AClientConfiguration(baseURL: url)
    .withBasicAuth(username: "user", password: "password")
let client = A2AClient(configuration: config)
```

### OAuth 2.0

```swift
let oauth = OAuth2Authentication(
    tokenURL: URL(string: "https://auth.example.com/token")!,
    clientId: "your-client-id",
    clientSecret: "your-client-secret"
)

let config = A2AClientConfiguration(baseURL: url)
    .with(authenticationProvider: oauth)
let client = A2AClient(configuration: config)
```

### Custom Authentication

Implement the `AuthenticationProvider` protocol for custom auth:

```swift
struct CustomAuth: AuthenticationProvider {
    func authenticate(request: URLRequest) async throws -> URLRequest {
        var request = request
        request.addValue("Custom credentials", forHTTPHeaderField: "Authorization")
        return request
    }
}
```

## Push Notifications

Configure webhooks to receive task updates:

```swift
// Create a push notification configuration
let pushConfig = PushNotificationConfig(
    url: "https://your-app.example.com/webhook",
    token: "secret-verification-token"
)

// Set the configuration for a task
try await client.setPushNotificationConfig(taskId: task.id, config: pushConfig)

// List existing configurations
let configs = try await client.listPushNotificationConfigs(taskId: task.id)

// Delete a configuration
try await client.deletePushNotificationConfig(taskId: task.id, configId: config.id)
```

## Configuration

### Client Configuration

```swift
let config = A2AClientConfiguration(
    baseURL: URL(string: "https://agent.example.com")!,
    transportBinding: .httpREST,  // or .jsonRPC
    protocolVersion: "1.0",
    timeoutInterval: 60
)

let client = A2AClient(configuration: config)
```

### Transport Bindings

The client supports two transport bindings:

- **HTTP/REST** (default): Standard RESTful HTTP methods
- **JSON-RPC 2.0**: Wrapped JSON-RPC protocol

```swift
// Use JSON-RPC transport
let config = A2AClientConfiguration(baseURL: url, transportBinding: .jsonRPC)
let client = A2AClient(configuration: config)
```

### Custom URLSession

```swift
let sessionConfig = URLSessionConfiguration.default
sessionConfig.timeoutIntervalForRequest = 30
sessionConfig.httpAdditionalHeaders = ["Custom-Header": "Value"]

let config = A2AClientConfiguration(
    baseURL: url,
    sessionConfiguration: sessionConfig
)
let client = A2AClient(configuration: config)
```

## Multi-turn Conversations

Use context IDs to group related messages:

```swift
let contextId = UUID().uuidString

// First message
let response1 = try await client.sendMessage(
    "What's the weather like?",
    contextId: contextId
)

// Follow-up in the same context
let response2 = try await client.sendMessage(
    "What about tomorrow?",
    contextId: contextId
)

// List all tasks in this context
let tasks = try await client.listTasks(contextId: contextId)
```

## Error Handling

```swift
do {
    let response = try await client.sendMessage("Hello")
} catch let error as A2AError {
    switch error {
    case .taskNotFound(let taskId, _):
        print("Task not found: \(taskId)")
    case .authenticationRequired:
        print("Please provide credentials")
    case .networkError(let underlying):
        print("Network error: \(underlying?.localizedDescription ?? "unknown")")
    case .invalidResponse(let message):
        print("Invalid response: \(message)")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

## API Reference

### A2AClient Methods

| Method | Description |
|--------|-------------|
| `sendMessage(_:)` | Send a message to the agent |
| `sendStreamingMessage(_:)` | Send a message with streaming response |
| `getTask(_:)` | Retrieve a task by ID |
| `listTasks(_:)` | List tasks with optional filters |
| `cancelTask(_:)` | Cancel a task |
| `subscribeToTask(_:)` | Subscribe to task updates |
| `setPushNotificationConfig(taskId:config:)` | Configure push notifications |
| `getPushNotificationConfig(taskId:configId:)` | Get push notification config |
| `listPushNotificationConfigs(taskId:)` | List push notification configs |
| `deletePushNotificationConfig(taskId:configId:)` | Delete push notification config |
| `getExtendedAgentCard()` | Get extended agent metadata |

### Static Methods

| Method | Description |
|--------|-------------|
| `A2AClient.discoverAgent(domain:)` | Discover an agent from a domain |
| `A2AClient.fetchAgentCard(from:)` | Fetch an agent card from a URL |

## Thread Safety

All public types in A2AClient conform to `Sendable` and are safe to use across concurrency domains. The library uses Swift's modern concurrency features (async/await, actors) for thread-safe operation.

## Requirements

- Swift 6.0+
- Xcode 16.0+

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Security

For security concerns, please see our [Security Policy](SECURITY.md).

## See Also

- [DESIGN.md](DESIGN.md) - Architecture and design documentation
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [A2A Protocol Specification](https://a2a-protocol.org/latest/) - Official protocol specification
