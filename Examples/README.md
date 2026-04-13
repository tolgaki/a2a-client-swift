# A2AClient Examples — A2A Protocol 1.0

This directory contains a hands-on tour of the **A2AClient** Swift SDK, built
against the [Agent2Agent (A2A) Protocol v1.0](https://a2a-protocol.org/latest/).

Each sample is a self-contained executable target declared in
[`Package.swift`](../Package.swift). All of them compile against the public
SDK only — there are no test imports, mocks, or private hooks. You can run
any of them with `swift run <TargetName>` (see the table below) once you
have an A2A 1.0 agent to point at.

---

## Table of Contents

1. [What's in A2A protocol 1.0](#whats-in-a2a-protocol-10)
2. [SDK Quick Reference](#sdk-quick-reference)
3. [Sample Catalog](#sample-catalog)
4. [Running a Sample](#running-a-sample)
5. [Patterns and Idioms](#patterns-and-idioms)
6. [Troubleshooting](#troubleshooting)

---

## What's in A2A protocol 1.0

A2A 1.0 is the first stable release of the protocol. The samples in this
directory deliberately exercise the surfaces that landed (or stabilized) in
1.0:

| Area | Highlight | Sample |
| --- | --- | --- |
| Agent discovery | `/.well-known/agent-card.json` plus a fallback to the legacy `/agent.json` path | [`AgentInspector`](AgentInspector/AgentInspector.swift) |
| Multi-binding agents | `AgentCard.supportedInterfaces` array (HTTP+JSON, JSONRPC, GRPC) | [`AgentInspector`](AgentInspector/AgentInspector.swift) |
| HTTP+JSON binding | RESTful default transport (replaces JSON-RPC-only v0.3 clients) | [`HelloAgent`](HelloAgent/HelloAgent.swift) |
| Multi-part messages | `Part` "oneof" content (`text` / `raw` / `url` / `data`) | [`MultimodalMessenger`](MultimodalMessenger/MultimodalMessenger.swift) |
| Streaming | SSE events with `final` flag and `append` / `lastChunk` chunking | [`StreamingNarrator`](StreamingNarrator/StreamingNarrator.swift) |
| Task lifecycle | `tasks/list` with new filters (`statusTimestampAfter`, `includeArtifacts`) | [`TaskLifecycleDemo`](TaskLifecycleDemo/TaskLifecycleDemo.swift) |
| Push notifications | CRUD operations replace the old single `set` call | [`PushNotificationDemo`](PushNotificationDemo/PushNotificationDemo.swift) |
| Authentication | `securitySchemes`, OAuth2 actor, custom providers | [`AuthShowcase`](AuthShowcase/AuthShowcase.swift) |
| Multi-turn conversations | `contextId` / `taskId` threading and `inputRequired` handling | [`TravelPlannerAgent`](TravelPlannerAgent/TravelPlannerAgent.swift) |
| LLM-routed orchestration | On-device intent router selecting agents and crafting prompts | [`SmartTravelPlanner`](SmartTravelPlanner/SmartTravelPlannerAgent.swift) |

---

## SDK Quick Reference

The SDK exposes a single `A2AClient` class plus a small set of value types.
Everything is `Sendable` and built on Swift Concurrency.

### Creating a client

```swift
import A2AClient

// Simplest form — defaults to HTTP+JSON transport, protocol 1.0,
// camelCase JSON keys, and a 60-second request timeout.
let client = A2AClient(baseURL: URL(string: "https://agent.example.com")!)

// One-line discovery via the well-known URL.
let (card, discovered) = try await A2A.discover(domain: "agent.example.com")

// From an explicit configuration when you need authentication or
// custom transport / casing.
let config = A2AClientConfiguration(
    baseURL: URL(string: "https://agent.example.com")!,
    transportBinding: .httpREST,        // or .jsonRPC
    protocolVersion: "1.0",
    timeoutInterval: 30,
    jsonKeyCasing: .camelCase           // or .snakeCase
)
.withBearerToken("…")
let configured = A2AClient(configuration: config)
```

### The 11 core operations

Every method is `async throws`. Errors that the SDK can decode become
typed `A2AError` cases; everything else (network, JSON) propagates as a
plain `Error` you can `catch` separately.

| Method | Purpose |
| --- | --- |
| `sendMessage(_:configuration:)` | Send a `Message`, get back a `SendMessageResponse` (`.message` or `.task`). |
| `sendMessage(_:contextId:taskId:configuration:)` | Convenience overload that wraps a `String` in a user `Message`. |
| `sendStreamingMessage(_:configuration:)` | Same as above but returns an `AsyncThrowingStream<StreamingEvent, Error>`. |
| `getTask(_:historyLength:)` | Fetch a single task by id, optionally trimming history. |
| `listTasks(_:)` | List tasks filtered by `TaskQueryParams`. |
| `cancelTask(_:metadata:)` | Cancel a non-terminal task. |
| `subscribeToTask(_:)` | Re-attach to an in-flight task's event stream. |
| `createPushNotificationConfig(taskId:config:)` | Register a webhook for task updates. |
| `getPushNotificationConfig(taskId:configId:)` | Read a single webhook config. |
| `listPushNotificationConfigs(taskId:)` | List all webhook configs for a task. |
| `deletePushNotificationConfig(taskId:configId:)` | Remove a webhook config. |
| `getExtendedAgentCard()` | Fetch the authenticated extended card if `capabilities.extendedAgentCard == true`. |

### Core types at a glance

```swift
// AgentCard — discovered metadata for an agent.
struct AgentCard {
    let name: String
    let description: String
    let supportedInterfaces: [AgentInterface]   // ★ new in 1.0 — multiple bindings
    let capabilities: AgentCapabilities         //   streaming / push / extensions / extendedAgentCard
    let securitySchemes: [String: SecurityScheme]?
    let securityRequirements: [SecurityRequirement]?
    let skills: [AgentSkill]
    let signatures: [AgentCardSignature]?
    // … plus provider, version, iconUrl, defaultInput/OutputModes
}

// Part — a single piece of content. EXACTLY ONE of text/raw/url/data set.
struct Part {
    let text: String?
    let raw: Data?            // base64-encoded over the wire
    let url: String?          // file by reference
    let data: AnyCodable?     // structured JSON
    let mediaType: String?    // e.g. "image/png"
    let filename: String?
    let metadata: [String: AnyCodable]?
}

// Message — one turn of a conversation.
struct Message {
    let messageId: String
    let role: MessageRole              // .user / .agent
    let parts: [Part]
    let contextId: String?             // groups a multi-turn conversation
    let taskId: String?                // continues an existing task
    let referenceTaskIds: [String]?    // ★ new in 1.0 — cross-task references
    let metadata: [String: AnyCodable]?
}

// A2ATask — long-running work item.
struct A2ATask {
    let id: String
    let contextId: String
    let status: TaskStatus              // state + optional message + timestamp
    let artifacts: [Artifact]?
    let history: [Message]?
    var isComplete: Bool { status.state.isTerminal }
    var needsInput: Bool { status.state.canReceiveInput }
}

// SendMessageResponse — the union returned by sendMessage.
enum SendMessageResponse {
    case task(A2ATask)
    case message(Message)
}

// StreamingEvent — one frame of an SSE stream.
enum StreamingEvent {
    case taskStatusUpdate(TaskStatusUpdateEvent)
    case taskArtifactUpdate(TaskArtifactUpdateEvent)
    case task(A2ATask)
    case message(Message)
}
```

### Authentication providers

| Provider | When to use |
| --- | --- |
| `NoAuthentication` | Public agents and local development. |
| `APIKeyAuthentication` | Header / query / cookie keys (`location: .header / .query / .cookie`). |
| `BearerAuthentication` | Static JWTs and other bearer tokens. |
| `BasicAuthentication` | HTTP Basic — username + password. |
| `OAuth2Authentication` | Actor-backed provider with refresh/client-credentials. Seed it with `setAccessToken(_:refreshToken:expiresIn:)`. |
| `CompositeAuthentication` | Chain providers — e.g. API key for a gateway plus a bearer for the downstream agent. |
| Custom `AuthenticationProvider` | Implement the protocol yourself for HMAC, mTLS, custom headers, etc. |

Use the builders on `A2AClientConfiguration` to set them quickly:

```swift
let config = A2AClientConfiguration(baseURL: url)
    .withAPIKey("sk-…", name: "X-API-Key", location: .header)
    .with(transportBinding: .jsonRPC)
```

### Error handling

```swift
do {
    let response = try await client.sendMessage("Hello")
} catch let error as A2AError {
    switch error {
    case .taskNotFound(let id, _):       …
    case .taskNotCancelable(let id, let state, _): …
    case .authenticationRequired:        …
    case .versionNotSupported(let v, _, _): …
    case .pushNotificationNotSupported:  …
    case .extensionSupportRequired(let uri, _): …
    case .invalidAgentResponse(let msg): …
    case .networkError(let underlying):  …
    default: …
    }
}
```

### Snake_case servers

The spec uses snake_case (`message_id`, `context_id`), while several
implementations use camelCase. The SDK defaults to camelCase and exposes
the toggle via `A2AClientConfiguration(jsonKeyCasing: .snakeCase)`.

---

## Sample Catalog

| Order | Sample | What it teaches | Run target |
| --- | --- | --- | --- |
| 1 | [HelloAgent](HelloAgent/HelloAgent.swift) | The bare-minimum end-to-end call. | `swift run HelloAgent` |
| 2 | [AgentInspector](AgentInspector/AgentInspector.swift) | Discovery and every field on an `AgentCard`. | `swift run AgentInspector` |
| 3 | [MultimodalMessenger](MultimodalMessenger/MultimodalMessenger.swift) | Building multi-part messages and walking responses. | `swift run MultimodalMessenger` |
| 4 | [StreamingNarrator](StreamingNarrator/StreamingNarrator.swift) | All four `StreamingEvent` cases and chunked artifact assembly. | `swift run StreamingNarrator` |
| 5 | [TaskLifecycleDemo](TaskLifecycleDemo/TaskLifecycleDemo.swift) | Submit, poll, list, inspect, and cancel a task. | `swift run TaskLifecycleDemo` |
| 6 | [PushNotificationDemo](PushNotificationDemo/PushNotificationDemo.swift) | Webhook CRUD operations. | `swift run PushNotificationDemo` |
| 7 | [AuthShowcase](AuthShowcase/AuthShowcase.swift) | Every built-in auth provider and a custom one. (Offline-safe.) | `swift run AuthShowcase` |
| 8 | [TravelPlannerAgent](TravelPlannerAgent/TravelPlannerAgent.swift) | On-device orchestrator: discovery + skill routing + concurrent dispatch. | `swift run TravelPlannerAgent` |
| 9 | [SmartTravelPlanner](SmartTravelPlanner/SmartTravelPlannerAgent.swift) | LLM-style intent routing on top of the orchestrator. | `swift run SmartTravelPlanner` |

### 1. HelloAgent

The smallest possible client. Reads `A2A_AGENT_URL` from the environment,
sends `"Hello, agent!"`, and prints the reply — handling both the
immediate-`Message` and long-running-`Task` cases.

**Use this sample when:** You're verifying that the SDK is wired up
correctly, or you want a 50-line snippet to copy into a unit test.

### 2. AgentInspector

Discovers an agent via `A2A.discover(domain:)` and pretty-prints every
field on the card. Optionally fetches the *extended* card if the agent
advertises `capabilities.extendedAgentCard = true`.

**Use this sample when:** You're integrating with a new agent and want to
see exactly which interfaces, skills, security schemes, and signatures
it exposes. Doubles as a debugging tool for `/.well-known` discovery.

### 3. MultimodalMessenger

Builds a single user `Message` containing one of every `Part` factory:

- `Part.text(_:)` — plain text with optional metadata
- `Part.raw(_:filename:mediaType:)` — inline file bytes (base64-encoded)
- `Part.url(_:filename:mediaType:)` — file by URL reference
- `Part.data(_:metadata:)` — structured JSON

…then walks the response and demonstrates the `contentType` enum and
`textParts` / `fileParts` / `dataParts` convenience accessors.

**Use this sample when:** You're sending images, PDFs, CSVs, or
structured payloads alongside text instructions.

### 4. StreamingNarrator

Calls `sendStreamingMessage(_:)`, iterates the resulting
`AsyncThrowingStream<StreamingEvent, Error>`, and reacts to each of the
four event cases:

- `.taskStatusUpdate` — lifecycle transitions and the `final` flag
- `.taskArtifactUpdate` — chunked deliveries; honors `append` / `lastChunk`
- `.task` — full task snapshots
- `.message` — in-band agent messages

Reassembles streamed artifact text into per-id buffers so you can see how
to render a token-by-token response.

**Use this sample when:** You want streaming UX (typing-style reveal)
or your agent emits artifacts incrementally.

### 5. TaskLifecycleDemo

Submits a task with `returnImmediately: true`, polls it with `getTask`
until it reaches a terminal state, prints its history and artifacts,
runs `listTasks` with rich `TaskQueryParams` filtering, then submits a
second task and cancels it — exercising the typed `taskNotCancelable`
error along the way.

**Use this sample when:** You can't (or don't want to) use streaming and
need the polling fallback, or you're writing a task-management UI.

### 6. PushNotificationDemo

Creates a task, attaches two webhook configurations to it (one with
Bearer auth, one with Basic), lists them, fetches one by id, deletes
the second, and re-lists to verify. Uses only the new
`createPushNotificationConfig` / `getPushNotificationConfig` /
`listPushNotificationConfigs` / `deletePushNotificationConfig` methods —
the legacy `setPushNotificationConfig` is deprecated in 1.0.

**Use this sample when:** You don't want to keep a persistent SSE
connection open and prefer agents to call your webhook directly.

### 7. AuthShowcase

Builds an `A2AClient` for each authentication provider that ships with
the SDK plus a custom `HMACSigner`. Doesn't make any network calls —
it just constructs configurations and prints what each one would send.

**Use this sample when:** You're picking which `AuthenticationProvider`
to use, or you need a working spec of the auth API for code review.

> AuthShowcase is the only sample that's safe to run in CI — it doesn't
> need a live agent.

### 8. TravelPlannerAgent

A realistic orchestrator that discovers three remote agents
(flights / hotels / weather), routes by skill tag, and dispatches calls
concurrently with `withThrowingTaskGroup`. Demonstrates blocking
requests, streaming responses, polling fallback, and multi-turn
conversations with `inputRequired` handling — all in one example.

**Use this sample when:** You want to see how to build an on-device
"meta-agent" that coordinates multiple remote A2A agents.

### 9. SmartTravelPlanner

Layers an `IntentRouter` protocol on top of `TravelPlannerAgent` so the
agent selection becomes a first-class step. The provided
`SimulatedIntentRouter` mimics what an on-device LLM (e.g. Apple
Foundation Models) would do; replace its body with your own model call
to ship.

**Use this sample when:** You want LLM-driven agent routing rather than
hardcoded skill matching.

---

## Running a Sample

Every sample reads its target URL from environment variables so the same
binary works against any deployment.

```bash
# Required (most samples)
export A2A_AGENT_URL="https://your-a2a-agent.example.com"

# Optional, sample-specific
export A2A_AGENT_DOMAIN="agent.example.com"           # AgentInspector
export A2A_PROMPT="Generate a poem"                    # StreamingNarrator
export A2A_WEBHOOK_URL="https://you/webhook"           # PushNotificationDemo

# Run the sample
swift run HelloAgent
swift run AgentInspector
swift run StreamingNarrator
swift run MultimodalMessenger
swift run TaskLifecycleDemo
swift run AuthShowcase                                 # offline-safe
swift run PushNotificationDemo
swift run TravelPlannerAgent
swift run SmartTravelPlanner
```

If you don't set `A2A_AGENT_URL`, samples fall back to a placeholder URL
so the binary still launches and prints its usage. The actual network
call will of course fail without a live agent.

---

## Patterns and Idioms

A handful of patterns recur across the samples — these are worth
internalizing.

### Handle both `.message` and `.task` responses

Even short prompts can return a `Task` (e.g. when the agent records every
exchange as a task). Always switch on the response:

```swift
let response = try await client.sendMessage(prompt)
switch response {
case .message(let m): print(m.textContent)
case .task(let t):    print("task \(t.id) state=\(t.state.rawValue)")
}
```

### Use `MessageSendConfiguration(returnImmediately: true)` for fire-and-forget

By default the server waits for a terminal state before returning. That
is great for synchronous prompts and bad for everything else. Pass
`returnImmediately: true` to get the task id back as soon as the work
has been registered, then poll or stream.

### Prefer streaming when the agent supports it

Inspect `agentCard.capabilities.streaming` and call
`sendStreamingMessage(_:)` when it is `true`. Fall back to polling
(`getTask` in a loop) otherwise. The TravelPlannerAgent sample shows
both paths picked at runtime.

### Use `contextId` for multi-turn conversations

`contextId` groups related messages and tasks. Generate one
(`UUID().uuidString`) at the start of a conversation and pass it on every
subsequent `sendMessage` call. Use `taskId` *additionally* when you want
to continue a specific task (e.g. responding to an `inputRequired` ask).

### Treat the SDK as `Sendable`-clean

Every public type conforms to `Sendable`, and `A2AClient` is a final
class with immutable storage. You can safely share a client across
actors and tasks without a lock.

### `_Concurrency.Task.sleep` is the safe way to wait

Inside files that already use the SDK's `A2ATask`, write delays as
`try await _Concurrency.Task.sleep(nanoseconds: …)` so they don't shadow
or get confused with the SDK type.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `versionNotSupported` from `A2AClientConfiguration.from(agentCard:)` | The agent advertises v0.3 with the HTTP+JSON binding (which doesn't exist in v0.3). | Connect to a v1.0 agent, or override the configuration to use `transportBinding: .jsonRPC`. |
| `invalidResponse` decoding `agent-card.json` | Server returns snake_case JSON. | Set `jsonKeyCasing: .snakeCase` on the configuration. |
| `pushNotificationNotSupported` | `agentCard.capabilities.pushNotifications` is `false` or unset. | Use streaming (`sendStreamingMessage`) or polling instead. |
| `taskNotCancelable` | The task is already in a terminal state. | Check `task.isComplete` before calling `cancelTask`. |
| Streaming hangs forever | The agent isn't sending the `final` flag and the connection is being held open. | Add a per-task timeout in your loop, or call `subscribeToTask` to re-attach with a fresh deadline. |
| Discovery returns 404 | The server still uses the v0.3 well-known path (`/.well-known/agent.json`). | The SDK auto-falls-back to it. If it still fails, check that the path is publicly reachable. |
| `authenticationRequired` immediately | The agent enforces auth on every call. | Build the configuration with one of the providers in [AuthShowcase](AuthShowcase/AuthShowcase.swift). |

For deeper architectural notes see [`../DESIGN.md`](../DESIGN.md), and for
the full library reference see the doc comments in
[`../Sources/A2AClient/`](../Sources/A2AClient/).
