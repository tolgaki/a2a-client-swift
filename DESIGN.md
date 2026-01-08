# A2AClient Design Document

This document describes the architecture and design decisions of the A2AClient Swift library.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Layer Diagram](#layer-diagram)
- [Core Components](#core-components)
- [Design Principles](#design-principles)
- [Data Flow](#data-flow)
- [Concurrency Model](#concurrency-model)
- [Transport Layer](#transport-layer)
- [Authentication System](#authentication-system)
- [Error Handling](#error-handling)
- [Extensibility](#extensibility)

## Architecture Overview

A2AClient follows a layered architecture that separates concerns and enables flexibility:

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│                  (Your Swift App)                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Public API Layer                          │
│              A2AClient, A2A namespace                        │
│         Quick-start helpers, convenience methods             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Model Layer                               │
│    Message, Task, Part, Artifact, AgentCard, etc.           │
│         Codable types, state machines                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Transport Layer                             │
│          A2ATransport protocol abstraction                   │
│   ┌─────────────────┐    ┌─────────────────────┐           │
│   │  HTTPTransport  │    │  JSONRPCTransport   │           │
│   │  (REST binding) │    │ (JSON-RPC 2.0)      │           │
│   └─────────────────┘    └─────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                Authentication Layer                          │
│           AuthenticationProvider protocol                    │
│  APIKey │ Bearer │ Basic │ OAuth2 │ Composite │ Custom     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Network Layer                              │
│                    URLSession                                │
└─────────────────────────────────────────────────────────────┘
```

## Layer Diagram

### Component Relationships

```
A2AClient
    │
    ├── A2AClientConfiguration
    │       ├── baseURL
    │       ├── transportBinding
    │       ├── protocolVersion
    │       ├── sessionConfiguration
    │       └── authenticationProvider
    │
    ├── A2ATransport (protocol)
    │       ├── HTTPTransport
    │       │       └── URLSession
    │       └── JSONRPCTransport
    │               └── URLSession
    │
    └── Models
            ├── Message
            │       └── Part (text, file, data)
            ├── A2ATask
            │       ├── TaskStatus
            │       ├── TaskState
            │       └── Artifact
            ├── AgentCard
            │       ├── AgentCapabilities
            │       ├── AgentSkill
            │       └── SecurityScheme
            ├── PushNotificationConfig
            └── A2AError
```

## Core Components

### A2AClient

The main entry point for all A2A operations. Responsibilities:

- Coordinating message sending and task management
- Managing transport and authentication
- Providing high-level convenience methods
- Handling agent discovery

**Key Design Decisions:**

1. **Single Responsibility**: A2AClient only orchestrates; actual HTTP work is delegated to transports
2. **Immutability**: Configuration is immutable after client creation
3. **Sendable**: Thread-safe for concurrent access

### A2AClientConfiguration

Encapsulates all client settings using a builder pattern:

```swift
A2AClientConfiguration(baseURL: url)
    .withAPIKey("key", name: "X-API-Key", location: .header)
    .with(transportBinding: .jsonRPC)
```

**Design Rationale:**

- Fluent interface for ergonomic configuration
- Immutable copies on each modification (value semantics)
- Sensible defaults for minimal configuration

### Models

All models are:

- **Codable**: JSON serialization/deserialization
- **Sendable**: Thread-safe concurrent access
- **Equatable**: Value comparison support
- **Identifiable**: SwiftUI/list compatibility where applicable

#### Message & Part

Messages use a compositional design with `Part` enum for content:

```swift
enum Part {
    case text(TextPart)
    case file(FilePart)
    case data(DataPart)
}
```

This design enables:
- Type-safe content handling
- Extensibility for new part types
- Clear separation of content concerns

#### Task & TaskState

Tasks follow a state machine pattern:

```
          ┌──────────────┐
          │  submitted   │
          └──────┬───────┘
                 │
                 ▼
          ┌──────────────┐
    ┌─────│   working    │─────┐
    │     └──────┬───────┘     │
    │            │             │
    ▼            ▼             ▼
┌────────┐ ┌──────────┐ ┌───────────┐
│failed  │ │completed │ │inputReq.  │
└────────┘ └──────────┘ └─────┬─────┘
                              │
                    (user provides input)
                              │
                              ▼
                       ┌──────────────┐
                       │   working    │
                       └──────────────┘
```

**State Properties:**

- `isTerminal`: completed, failed, cancelled, rejected
- `canReceiveInput`: inputRequired, authRequired

### Transport Abstraction

The `A2ATransport` protocol defines the contract:

```swift
protocol A2ATransport: Sendable {
    func send<Request, Response>(
        request: Request,
        to endpoint: A2AEndpoint,
        responseType: Response.Type
    ) async throws -> Response

    func stream<Request>(
        request: Request,
        to endpoint: A2AEndpoint
    ) async throws -> AsyncThrowingStream<StreamingEvent, Error>
}
```

**Benefits:**

- Swappable transport implementations
- Testability via mock transports
- Protocol independence from HTTP details

## Design Principles

### 1. Protocol-Oriented Design

Extensive use of protocols enables:

- Dependency injection
- Mock implementations for testing
- Future extensibility

Key protocols:
- `A2ATransport`: HTTP abstraction
- `AuthenticationProvider`: Pluggable authentication

### 2. Modern Swift Concurrency

The library is built on Swift's structured concurrency:

- `async/await` for all async operations
- `AsyncThrowingStream` for streaming
- `Sendable` conformance throughout
- Actor isolation for OAuth2 token management

### 3. Value Semantics

All models use value types (structs/enums) for:

- Thread safety without locks
- Predictable behavior
- Easy testing

### 4. Minimal Dependencies

No external dependencies beyond Foundation:

- Reduces integration complexity
- Avoids version conflicts
- Smaller binary size

### 5. Defensive API Design

- Required parameters are non-optional
- Optional parameters have sensible defaults
- Factory methods for common patterns
- Clear error types with associated context

## Data Flow

### Request Flow

```
Application
    │
    │ sendMessage("Hello")
    ▼
A2AClient
    │
    │ Create Message, wrap in SendMessageRequest
    ▼
A2ATransport
    │
    │ Serialize request, build HTTP request
    ▼
AuthenticationProvider
    │
    │ Add authentication headers
    ▼
URLSession
    │
    │ Execute HTTP request
    ▼
Server Response
    │
    │ JSON response data
    ▼
A2ATransport
    │
    │ Deserialize to SendMessageResponse
    ▼
A2AClient
    │
    │ Return .message or .task
    ▼
Application
```

### Streaming Flow

```
Application
    │
    │ sendStreamingMessage("Generate story")
    ▼
A2AClient
    │
    │ Create streaming request
    ▼
A2ATransport
    │
    │ Initiate SSE connection
    ▼
URLSession (dataTask with delegate)
    │
    │ Receive data chunks
    ▼
SSE Parser
    │
    │ Parse "event:" and "data:" lines
    ▼
AsyncThrowingStream<StreamingEvent>
    │
    │ Yield events as they arrive
    ▼
Application
    │
    │ for try await event in stream { ... }
```

## Concurrency Model

### Thread Safety

All public types conform to `Sendable`:

```swift
public final class A2AClient: Sendable { }
public struct Message: Codable, Sendable { }
public struct A2ATask: Codable, Sendable { }
```

### Actor Isolation

OAuth2Authentication uses an actor for token management:

```swift
public actor OAuth2Authentication: AuthenticationProvider {
    private var currentToken: OAuth2Token?
    private var refreshTask: Task<OAuth2Token, Error>?

    public func authenticate(request: URLRequest) async throws -> URLRequest {
        let token = try await getValidToken()
        // Add to request
    }
}
```

**Benefits:**

- Prevents concurrent token refresh
- Serializes access to token state
- Automatic race condition prevention

### Structured Concurrency

Streaming uses `AsyncThrowingStream`:

```swift
func stream<Request>(
    request: Request,
    to endpoint: A2AEndpoint
) async throws -> AsyncThrowingStream<StreamingEvent, Error>
```

**Properties:**

- Automatic cancellation propagation
- Backpressure handling
- Proper cleanup on stream termination

## Transport Layer

### HTTP/REST Transport

The default transport uses RESTful conventions:

| Operation | Method | Path |
|-----------|--------|------|
| Send message | POST | `/messages:send` |
| Stream message | POST | `/messages:stream` |
| Get task | GET | `/tasks/{id}` |
| List tasks | GET | `/tasks` |
| Cancel task | POST | `/tasks/{id}:cancel` |
| Subscribe | GET | `/tasks/{id}:subscribe` |

### JSON-RPC Transport

Alternative transport wrapping requests in JSON-RPC 2.0:

```json
{
    "jsonrpc": "2.0",
    "id": "unique-id",
    "method": "message/send",
    "params": { ... }
}
```

Response:
```json
{
    "jsonrpc": "2.0",
    "id": "unique-id",
    "result": { ... }
}
```

### Endpoint Abstraction

`A2AEndpoint` encapsulates routing information:

```swift
struct A2AEndpoint {
    let method: HTTPMethod
    let path: String
    let isStreaming: Bool
}
```

This separation allows:
- Transport-agnostic endpoint definitions
- Easy addition of new endpoints
- Centralized path management

## Authentication System

### Provider Protocol

```swift
protocol AuthenticationProvider: Sendable {
    func authenticate(request: URLRequest) async throws -> URLRequest
}
```

### Built-in Providers

1. **NoAuthentication**: Default, pass-through
2. **APIKeyAuthentication**: API key in header/query/cookie
3. **BearerAuthentication**: HTTP Bearer token
4. **BasicAuthentication**: HTTP Basic (base64 encoded)
5. **OAuth2Authentication**: Full OAuth 2.0 with token refresh
6. **CompositeAuthentication**: Combine multiple providers

### Composite Authentication

Chain multiple providers:

```swift
let composite = CompositeAuthentication(providers: [
    APIKeyAuthentication(key: "api-key", name: "X-API-Key", location: .header),
    BearerAuthentication(token: "jwt-token")
])
```

Providers are applied in order, each modifying the request.

## Error Handling

### Error Hierarchy

```swift
enum A2AError: Error, Sendable, Equatable {
    // Task errors
    case taskNotFound(taskId: String, message: String?)
    case taskNotCancelable(taskId: String, state: TaskState, message: String?)

    // Capability errors
    case pushNotificationNotSupported(message: String?)
    case unsupportedOperation(operation: String, message: String?)

    // Protocol errors
    case contentTypeNotSupported(contentType: String, message: String?)
    case versionNotSupported(version: String, supportedVersions: [String]?, message: String?)
    case extensionSupportRequired(extensionUri: String, message: String?)

    // Auth errors
    case authenticationRequired(message: String?)
    case authorizationFailed(message: String?)

    // Transport errors
    case networkError(underlying: Error?)
    case encodingError(underlying: Error?)
    case invalidResponse(message: String?)
    case jsonRPCError(code: Int, message: String, data: AnyCodable?)

    // Generic
    case invalidRequest(message: String?)
    case internalError(message: String?)
    case unknown(message: String?)
}
```

### Error Codes

JSON-RPC error codes follow the A2A specification:

```swift
static let taskNotFound = -32001
static let taskNotCancelable = -32002
static let pushNotificationNotSupported = -32003
static let unsupportedOperation = -32004
static let contentTypeNotSupported = -32005
static let versionNotSupported = -32006
static let extensionSupportRequired = -32007
static let authenticationRequired = -32010
static let authorizationFailed = -32011
```

### Error Context

Errors include context for debugging:

```swift
case taskNotFound(taskId: String, message: String?)
//                 ^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^
//                 Specific ID    Server message
```

## Extensibility

### Custom Transports

Implement `A2ATransport` for custom networking:

```swift
struct CustomTransport: A2ATransport {
    func send<Request, Response>(
        request: Request,
        to endpoint: A2AEndpoint,
        responseType: Response.Type
    ) async throws -> Response {
        // Custom implementation
    }
}
```

### Custom Authentication

Implement `AuthenticationProvider`:

```swift
struct SIWAAuthentication: AuthenticationProvider {
    let appleIdToken: String

    func authenticate(request: URLRequest) async throws -> URLRequest {
        var request = request
        request.addValue("SIWA \(appleIdToken)", forHTTPHeaderField: "Authorization")
        return request
    }
}
```

### Protocol Extensions

Future protocol extensions can be supported via:

1. `extensions` array in configuration
2. Custom metadata in messages
3. `AnyCodable` for arbitrary JSON data

## File Organization

```
Sources/A2AClient/
├── A2AClientModule.swift          # Public exports, version, helpers
├── Client/
│   ├── A2AClient.swift            # Main client class
│   └── A2AClientConfiguration.swift
├── Models/
│   ├── Message.swift
│   ├── Part.swift
│   ├── Task.swift
│   ├── TaskState.swift
│   ├── Artifact.swift
│   ├── AgentCard.swift
│   ├── SecurityScheme.swift
│   ├── PushNotificationConfig.swift
│   └── Errors.swift
├── Transport/
│   ├── TransportProtocol.swift    # A2ATransport, A2AEndpoint
│   ├── HTTPTransport.swift
│   └── JSONRPCTransport.swift
├── Authentication/
│   └── AuthenticationProvider.swift
├── Streaming/
│   └── StreamingEvents.swift
└── Extensions/
    └── AnyCodable.swift
```

## Testing Strategy

### Unit Tests

- Model encoding/decoding
- Authentication header generation
- Error mapping
- State machine transitions

### Integration Tests

- Mock server responses
- End-to-end message flow
- Streaming event parsing

### Test Helpers

The protocol-oriented design enables:

```swift
struct MockTransport: A2ATransport {
    var responses: [A2AEndpoint: Any] = [:]

    func send<Request, Response>(
        request: Request,
        to endpoint: A2AEndpoint,
        responseType: Response.Type
    ) async throws -> Response {
        return responses[endpoint] as! Response
    }
}
```

## Future Considerations

1. **WebSocket Transport**: For bidirectional real-time communication
2. **Retry Policies**: Configurable automatic retries
3. **Caching**: Response caching for agent cards
4. **Metrics**: Built-in telemetry hooks
5. **Combine Support**: Publishers for streaming (deprecated in favor of async/await)
