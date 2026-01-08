# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
