# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking Changes - A2A Protocol v1.0 RC Compliance

This release updates the library to conform with the official A2A Protocol v1.0 Release Candidate specification.

#### Part Model Redesign

The `Part` model has been completely redesigned to match the protobuf spec:

**Before:**
```swift
enum Part {
    case text(TextPart)
    case file(FilePart)
    case data(DataPart)
}
```

**After:**
```swift
struct Part {
    let text: String?       // Plain text content
    let raw: Data?          // Raw binary data
    let url: String?        // URL reference
    let data: AnyCodable?   // Structured JSON data
    let filename: String?   // Optional filename
    let mediaType: String?  // Optional MIME type
    let metadata: [String: AnyCodable]?
}
```

Migration: Use `Part.text()`, `Part.url()`, `Part.raw()`, `Part.data()`, or `Part.file()` factory methods. Access content via `part.text`, `part.url`, etc. The old `TextPart`, `FilePart`, `DataPart` types are deprecated but preserved for backward compatibility.

#### AgentCard Changes

- Removed top-level `url` and `protocolVersion` fields
- These are now in `supportedInterfaces[].url` and `supportedInterfaces[].protocolVersion`
- `AgentInterface` now requires `url`, `protocolBinding`, and `protocolVersion`
- Use `agentCard.url` computed property to get URL from first interface

**Before:**
```swift
AgentCard(name: "Agent", url: "https://...", protocolVersion: "1.0", ...)
```

**After:**
```swift
AgentCard(name: "Agent", supportedInterfaces: [
    AgentInterface(url: "https://...", protocolBinding: "HTTP+JSON", protocolVersion: "1.0")
], ...)
```

#### TaskQueryParams Changes

- `limit` renamed to `pageSize`
- `cursor` renamed to `pageToken`
- Added `historyLength`, `statusTimestampAfter`, `includeArtifacts` fields

#### Streaming Events Changes

- `TaskStatusUpdateEvent.contextId` is now required (was optional)
- Removed deprecated `final` field from `TaskStatusUpdateEvent`
- `TaskArtifactUpdateEvent` now requires `contextId`
- Added `append` and `lastChunk` fields to `TaskArtifactUpdateEvent`
- New `StreamResponse` wrapper type for streaming operations

#### Transport Changes

- HTTP endpoints updated: `/messages:send` → `/message:send`
- Extended agent card endpoint: `/agentCard:extended` → `/extendedAgentCard`
- Push notification creation now uses POST (was PUT)
- `TransportBinding.httpREST` raw value changed to `"HTTP+JSON"`
- `TransportBinding.jsonRPC` raw value changed to `"JSONRPC"`

#### Push Notification Changes

- Added `AuthenticationInfo` for webhook authentication
- Added `TaskPushNotificationConfig` wrapper type
- New `createPushNotificationConfig` method (replaces `setPushNotificationConfig` for creation)

#### Error Handling Changes

- Added `invalidAgentResponse` error case
- Added `extendedAgentCardNotConfigured` error case

### Security Improvements

- **Part validation**: Invalid base64 in `raw` field now throws `DecodingError` instead of silently failing
- **Part validation**: Decoding a `Part` with zero or multiple content fields now throws `DecodingError`
- **AgentCard validation**: Decoding an `AgentCard` with empty `supportedInterfaces` array now throws `DecodingError`
- **Path injection protection**: Task IDs and config IDs are now sanitized to prevent path traversal attacks
- **Credential documentation**: Added security warnings about plaintext credential storage in authentication providers

### Added
- Initial implementation of A2AClient Swift library
- Core A2A Protocol 1.0 support
- Message sending and receiving
- Task lifecycle management (create, get, list, cancel)
- Streaming support via Server-Sent Events (SSE)
- Push notification configuration
- Agent discovery via well-known URLs

### Transport Layer
- HTTP/REST transport binding (default)
- JSON-RPC 2.0 transport binding
- Configurable URLSession support
- Automatic protocol version headers

### Authentication
- API Key authentication (header, query, cookie)
- HTTP Bearer token authentication
- HTTP Basic authentication
- OAuth 2.0 with automatic token refresh
- Composite authentication for combining providers
- Custom authentication provider protocol

### Models
- Message with text, file, and data parts
- Task with full state machine support
- Artifact for agent outputs
- AgentCard for agent metadata and discovery
- SecurityScheme definitions
- PushNotificationConfig for webhooks

### Error Handling
- Comprehensive A2AError enum
- JSON-RPC error code mapping
- Localized error descriptions

### Platform Support
- iOS 15.0+
- macOS 12.0+
- watchOS 8.0+
- tvOS 15.0+

### Developer Experience
- Swift 6.0 strict concurrency support
- Full Sendable conformance
- Comprehensive documentation
- Example code snippets

## [1.0.0] - TBD

Initial public release.

---

## Version History Format

### [Version] - YYYY-MM-DD

#### Added
- New features

#### Changed
- Changes in existing functionality

#### Deprecated
- Soon-to-be removed features

#### Removed
- Removed features

#### Fixed
- Bug fixes

#### Security
- Vulnerability fixes
