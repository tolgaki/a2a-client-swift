# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.20] - 2026-04-14

### Changed — migration release

This package is now a thin re-export shim that depends on [`a2a-swift 1.1.0`](https://github.com/tolgaki/a2a-swift) and re-exports its `A2AClient` product. Existing consumers need no source code changes; `import A2AClient` continues to work.

- Deleted `Sources/A2AClient/*` — all client code is now in `a2a-swift`.
- Deleted `Tests/A2AClientTests/*` — tests live in `a2a-swift`.
- Deleted `Examples/*` — examples live in `a2a-swift`.
- Added `Sources/A2AClientShim/A2AClientShim.swift` — one-line `@_exported import A2AClient` trampoline.
- Package dependency on `https://github.com/tolgaki/a2a-swift.git` (from `1.1.0`).

### ⚠️ Deployment target bumped

- `macOS 12 → 14`
- `iOS 15 → 17`
- `watchOS 8 → 10`
- `tvOS 15 → 17`
- `visionOS 1` (new)

Required by Hummingbird 2.x on the server side of `a2a-swift`. If you need to stay on macOS 12 / iOS 15, pin to `exact: "1.0.19"`.

### Migration path

Recommended: switch your SPM dependency from `https://github.com/tolgaki/a2a-client-swift.git` to `https://github.com/tolgaki/a2a-swift.git`. See the README for details.

This repository will be archived after a short transition period. All future development happens in `a2a-swift`.

## [1.0.19] - 2026-04-12

### Fixed

- **JSON-RPC error codes** — Codes -32006 through -32009 were shuffled vs spec §10.2. Now: -32006=InvalidAgentResponse, -32007=ExtendedAgentCardNotConfigured, -32008=ExtensionSupportRequired, -32009=VersionNotSupported.
- **Well-known agent card path** — Primary path is now `/.well-known/agent-card.json` per spec §8.2 (was incorrectly `agent.json`). `agent.json` is retained as a fallback.
- **SubscribeToTask HTTP method** — Changed from GET to POST per spec §5.3 normative text.
- **SendMessageConfiguration field name** — Renamed `pushNotificationConfig` → `taskPushNotificationConfig` to match the proto/spec field name.
- **TaskListResponse resilience** — `nextPageToken`, `pageSize`, `totalSize` now default when missing instead of crashing the decode.
- **REST error decoding** — `validateResponse` now parses both AIP-193 format (`{"error":{"code":…,"message":…}}`) and flat JSON-RPC format.
- **Tenant propagation** — `A2AClient` now passes `configuration.tenant` into every request object (SendMessageRequest, CancelTaskRequest, TaskIdParams, push notification params) so JSON-RPC servers receive the tenant in `params`.

## [1.0.18] - 2026-04-12

### Fixed

- **Extended agent card REST path** — Changed from `/agent/authenticatedExtendedCard` to `/extendedAgentCard` per spec §11.3.4.

## [1.0.17] - 2026-04-12

### Fixed

- **REST paths: removed erroneous `/v1/` prefix** — The A2A spec (§5.3) defines REST paths as `/message:send`, `/tasks/{id}`, etc. with NO `/v1/` prefix. The prefix was added by mistake in 1.0.15 and caused every REST call to 404. Paths are now relative to the interface URL from the agent card, with tenant prepended by `pathWithTenant` when set.
- **SecurityScheme .NET wrapper decoding** — The .NET A2A SDK serializes security schemes as a discriminated union (`{"httpAuthSecurityScheme": {"scheme":"bearer"}}` instead of flat `{"type":"http","scheme":"bearer"}`). The decoder now detects and unwraps `httpAuthSecurityScheme`, `apiKeySecurityScheme`, `oauth2SecurityScheme`, and `openIdConnectSecurityScheme` wrapper keys.
- **SecurityRequirement .NET format** — The .NET server sends security requirements as `{"schemes":{"key":{"list":[]}}}` instead of `{"key":[]}`. The decoder now handles both formats.

## [1.0.16] - 2026-04-12

### Fixed

- **REST URL construction** — Replaced `URL.appendingPathComponent` with direct string concatenation to prevent Foundation from percent-encoding colons (`:`) in spec paths like `/v1/message:send` on some OS versions.
- **AgentCard decoding resilience** — `AgentInterface.protocolBinding` and `protocolVersion`, `AgentSkill.tags`, and `AgentProvider.url` now fall back to defaults when omitted by the server (e.g. .NET). Previously they were auto-synthesized as required, causing keyNotFound errors.
- **JSON-RPC decode errors** — `JSONRPCTransport` now wraps decode failures as `invalidResponse` with a body snippet instead of leaking raw `DecodingError`.
- **StreamEventResult snake_case keys** — The streaming event decoder now accepts `status_update`/`artifact_update` field-presence keys and kind values in addition to `statusUpdate`/`artifactUpdate` and `status-update`/`artifact-update`.
- **cancelTask error clarity** — The `taskNotCancelable` error description now says "Server rejected cancel" to make it clear the error originates from the server, not a client-side guard.

## [1.0.15] - 2026-04-11

### Fixed

- **REST binding URLs missing `/v1/` prefix** — All REST endpoint paths now include the spec-required `/v1/` prefix (e.g. `/v1/message:send`, `/v1/tasks/{id}`). Previously every REST call returned HTTP 404 against spec-compliant servers.
- **AgentCard decoding: `SecurityScheme` now infers `type`** — Custom decoder accepts security scheme objects that omit the `type` discriminator (e.g. the .NET server) and infers the type from sibling fields (`flows`→`oauth2`, `openIdConnectUrl`→`openIdConnect`, `scheme`→`http`, `name`/`in`→`apiKey`).
- **Streaming decoder now surfaces real errors** — Previously every decode failure was collapsed to "Unknown streaming event format". The decoder now retries with snake_case key conversion (for Python-style servers) and surfaces the underlying `DecodingError` along with a body snippet when every attempt fails.
- **HTTP response decode errors** — Decode failures on a 2xx response are now reported as `A2AError.invalidResponse` with a body snippet instead of `A2AError.encodingError`, which is now reserved for request-side failures.
- **`taskNotCancelable` state fallback** — When the server error payload omits a `state` field, the SDK no longer fabricates `.working`; it reports `.unspecified` so the value isn't misread as a client-side decision.
- **Agent card well-known fallback** — `fetchAgentCard(from:)` now also falls back from `/agent-card.json` → `/agent.json`, not only the v1.0→v0.3 direction.

### Added

- **Clear error for v0.3 + REST** — `A2AClientConfiguration.from(agentCard:)` throws `versionNotSupported` when a v0.3 card is paired with the HTTP+JSON binding, instead of letting every call fail with HTTP 404.

## [1.0.5] - 2026-03-21

### Fixed

- **Streaming: 0-event bug against Graph RP** — Custom `URLSession(configuration:)` can buffer the entire SSE response instead of delivering bytes incrementally. Streaming now uses `URLSession.shared` (authentication is applied per-request). The custom session is still used for non-streaming requests.
- **Streaming: last event lost** — When the SSE stream ends without a trailing blank line, the parser's last buffered event is now flushed.

## [1.0.4] - 2026-03-21

### Fixed

- **SSE parser: consecutive `data:` lines** — Servers like the Graph RP send consecutive `data:` lines without blank-line separators. The parser now emits the buffered event when a new `data:` line arrives while data is already buffered. Standard blank-line-delimited SSE still works unchanged.

## [1.0.3] - 2026-03-21

### Fixed

- **JSON-RPC streaming decoder** — Replaced trial-and-error decoding with `kind`-based dispatch. The decoder now reads the `kind` discriminator from JSON-RPC wrapped results and dispatches to the correct type: `"task"`, `"message"`, `"status-update"`, `"artifact-update"`.
- **`MessageSendConfiguration.blocking` renamed to `returnImmediately`** — Aligns with the A2A proto spec's `return_immediately` field. Note the inverted semantics: `returnImmediately: true` means "don't block", `returnImmediately: false` means "wait for completion".

### Added

- `final` field on `TaskStatusUpdateEvent` — signals the last event in a stream.
- `kind` discriminator encoding/decoding on `A2ATask` (`"task"`), `TaskStatusUpdateEvent` (`"status-update"`), `TaskArtifactUpdateEvent` (`"artifact-update"`).
- `metadata` and `tenant` fields on `SendMessageRequest` per proto spec.

### Breaking Changes

- `MessageSendConfiguration.blocking` → `returnImmediately` (inverted semantics).

## [1.0.2] - 2026-03-21

### Fixed

- **JSON keys default to camelCase** — Removed all explicit snake_case `CodingKey` string mappings. JSON keys now use camelCase by default (`messageId`, `contextId`, `taskId`, etc.) matching the Graph RP convention.
- **Message `kind` discriminator** — `Message` now encodes `"kind": "message"` in JSON output. Decoding accepts `kind` optionally for backwards compatibility.

### Added

- `JSONKeyCasing` configuration option (`.camelCase` default, `.snakeCase` for A2A spec servers). Set via `A2AClientConfiguration(baseURL: url, jsonKeyCasing: .snakeCase)`.
- The casing option flows through to transport encoders/decoders via `A2AServiceParameters`.

### Breaking Changes

- JSON keys are now camelCase by default. Use `jsonKeyCasing: .snakeCase` for servers expecting snake_case.

## [1.0.1] - 2026-03-21

### Fixed

- **Part `kind` discriminator** — `Part` now encodes a `kind` field in JSON: `"text"` for text parts, `"file"` for raw/url parts, `"data"` for data parts. Decoding accepts `kind` optionally for backwards compatibility.

## [1.0.0] - 2026-02-07

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

---

[1.0.20]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.20
[1.0.19]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.19
[1.0.18]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.18
[1.0.17]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.17
[1.0.16]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.16
[1.0.15]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.15
[1.0.5]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.5
[1.0.4]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.4
[1.0.3]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.3
[1.0.2]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.2
[1.0.1]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.1
[1.0.0]: https://github.com/tolgaki/a2a-client-swift/releases/tag/1.0.0
