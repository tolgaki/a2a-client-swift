// A2AClient.swift
// A2AClient
//
// Agent2Agent Protocol - Main Client Implementation

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A2A protocol client for communicating with A2A-compatible agents.
///
/// This client implements all 11 core A2A operations and supports both
/// HTTP/REST and JSON-RPC 2.0 transport bindings.
public final class A2AClient: Sendable {
    /// The client configuration.
    public let configuration: A2AClientConfiguration

    /// The underlying transport.
    private let transport: any A2ATransport

    /// The URL session used by this client.
    /// Note: URLSession is thread-safe and can be shared across threads.
    private let session: URLSession

    // MARK: - Initialization

    /// Creates a new A2A client with the given configuration.
    public init(configuration: A2AClientConfiguration) {
        self.configuration = configuration

        // Copy before mutating — URLSessionConfiguration is a reference type,
        // and setting the timeout on the caller's instance would leak into
        // every other client built from the same configuration object.
        let sessionConfig = (configuration.sessionConfiguration.copy() as? URLSessionConfiguration)
            ?? configuration.sessionConfiguration
        sessionConfig.timeoutIntervalForRequest = configuration.timeoutInterval
        self.session = URLSession(configuration: sessionConfig)

        let serviceParameters = A2AServiceParameters(
            version: configuration.protocolVersion,
            extensions: configuration.extensions,
            tenant: configuration.tenant,
            jsonKeyCasing: configuration.jsonKeyCasing
        )

        switch configuration.transportBinding {
        case .httpREST:
            self.transport = HTTPTransport(
                baseURL: configuration.baseURL,
                session: session,
                serviceParameters: serviceParameters,
                authenticationProvider: configuration.authenticationProvider
            )
        case .jsonRPC:
            self.transport = JSONRPCTransport(
                baseURL: configuration.baseURL,
                session: session,
                serviceParameters: serviceParameters,
                authenticationProvider: configuration.authenticationProvider
            )
        }
    }

    /// Creates a new A2A client with the given base URL.
    public convenience init(baseURL: URL) {
        self.init(configuration: A2AClientConfiguration(baseURL: baseURL))
    }

    /// Creates a new A2A client from an agent card.
    public convenience init(agentCard: AgentCard, authenticationProvider: (any AuthenticationProvider)? = nil) throws {
        let config = try A2AClientConfiguration.from(
            agentCard: agentCard,
            authenticationProvider: authenticationProvider
        )
        self.init(configuration: config)
    }

    // MARK: - Agent Discovery

    /// Discovers an agent by fetching its agent card from the well-known URL.
    ///
    /// - Parameter domain: The domain to discover the agent from.
    /// - Returns: The agent card.
    public static func discoverAgent(domain: String) async throws -> AgentCard {
        guard let url = AgentCard.wellKnownURL(domain: domain) else {
            throw A2AError.invalidRequest(message: "Invalid domain: \(domain)")
        }

        return try await fetchAgentCard(from: url)
    }

    /// Fetches the agent card from a specific URL.
    ///
    /// If the fetch fails and the URL points at the v1.0 well-known path
    /// (`agent.json`), this method automatically retries the v0.3 legacy path
    /// (`agent-card.json`). The reverse fallback (v0.3 → v1.0) is also
    /// attempted so that callers holding a legacy URL still reach a v1.0 card
    /// when available.
    public static func fetchAgentCard(from url: URL) async throws -> AgentCard {
        let session = URLSession.shared

        func fetch(from fetchURL: URL) async throws -> AgentCard {
            var request = URLRequest(url: fetchURL)
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw A2AError.invalidResponse(message: "Invalid response type")
            }

            guard httpResponse.statusCode == 200 else {
                throw A2AError.invalidResponse(message: "HTTP \(httpResponse.statusCode) fetching agent card at \(fetchURL.absoluteString)")
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                return try decoder.decode(AgentCard.self, from: data)
            } catch {
                throw A2AError.invalidResponse(
                    message: "Failed to decode agent card at \(fetchURL.absoluteString): \(error)"
                )
            }
        }

        do {
            return try await fetch(from: url)
        } catch {
            if let fallback = legacyAgentCardURL(for: url) {
                do {
                    return try await fetch(from: fallback)
                } catch {
                    // Fall through and throw the original error so the caller
                    // sees the failure on the path they asked for.
                }
            }
            throw error
        }
    }

    /// Returns the cross-version well-known fallback URL, or nil if the
    /// supplied URL doesn't look like a well-known agent card path.
    private static func legacyAgentCardURL(for url: URL) -> URL? {
        let urlString = url.absoluteString
        let replacements: [(String, String)] = [
            ("/agent.json", "/agent-card.json"),     // v1.0 -> v0.3
            ("/agent-card.json", "/agent.json"),     // v0.3 -> v1.0
        ]
        for (suffix, replacement) in replacements {
            guard urlString.hasSuffix(suffix),
                  let range = urlString.range(of: suffix, options: .backwards) else { continue }
            if let fallback = URL(string: urlString.replacingOccurrences(of: suffix, with: replacement, range: range)) {
                return fallback
            }
        }
        return nil
    }

    // MARK: - Message Operations

    /// Sends a message to the agent.
    ///
    /// This is the primary method for initiating agent interactions.
    /// The agent may respond with either a Task (for long-running operations)
    /// or a Message (for immediate responses).
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - configuration: Optional configuration for accepted output modes, blocking, history length, etc.
    /// - Returns: The response, which is either a Task or Message.
    public func sendMessage(_ message: Message, configuration: MessageSendConfiguration? = nil) async throws -> SendMessageResponse {
        let request = SendMessageRequest(tenant: self.configuration.tenant, message: message, configuration: configuration)
        return try await transport.send(
            request: request,
            to: .sendMessage,
            responseType: SendMessageResponse.self
        )
    }

    /// Sends a message with text content.
    ///
    /// - Parameters:
    ///   - text: The text content to send.
    ///   - contextId: Optional context ID for multi-turn conversations.
    ///   - taskId: Optional task ID to continue an existing task.
    ///   - configuration: Optional configuration for accepted output modes, blocking, history length, etc.
    /// - Returns: The response, which is either a Task or Message.
    public func sendMessage(
        _ text: String,
        contextId: String? = nil,
        taskId: String? = nil,
        configuration: MessageSendConfiguration? = nil
    ) async throws -> SendMessageResponse {
        let message = Message.user(text, contextId: contextId, taskId: taskId)
        return try await sendMessage(message, configuration: configuration)
    }

    /// Sends a streaming message to the agent.
    ///
    /// Returns an async sequence of streaming events that can be iterated
    /// to receive real-time updates.
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - configuration: Optional configuration for accepted output modes, history length, etc.
    /// - Returns: An async sequence of streaming events.
    public func sendStreamingMessage(_ message: Message, configuration: MessageSendConfiguration? = nil) async throws -> AsyncThrowingStream<StreamingEvent, Error> {
        let request = SendMessageRequest(tenant: self.configuration.tenant, message: message, configuration: configuration)
        return try await transport.stream(request: request, to: .sendStreamingMessage)
    }

    /// Sends a streaming message with text content.
    ///
    /// - Parameters:
    ///   - text: The text content to send.
    ///   - contextId: Optional context ID for multi-turn conversations.
    ///   - taskId: Optional task ID to continue an existing task.
    ///   - configuration: Optional configuration for accepted output modes, history length, etc.
    /// - Returns: An async sequence of streaming events.
    public func sendStreamingMessage(
        _ text: String,
        contextId: String? = nil,
        taskId: String? = nil,
        configuration: MessageSendConfiguration? = nil
    ) async throws -> AsyncThrowingStream<StreamingEvent, Error> {
        let message = Message.user(text, contextId: contextId, taskId: taskId)
        return try await sendStreamingMessage(message, configuration: configuration)
    }

    // MARK: - Task Management

    /// Gets a task by its ID.
    ///
    /// - Parameters:
    ///   - taskId: The task ID.
    ///   - historyLength: Optional maximum number of messages to include in history.
    /// - Returns: The task.
    public func getTask(_ taskId: String, historyLength: Int? = nil) async throws -> A2ATask {
        var queryItems: [URLQueryItem] = []
        // id must be in queryItems for JSON-RPC (converted to params)
        queryItems.append(URLQueryItem(name: "id", value: taskId))
        if let historyLength = historyLength {
            queryItems.append(URLQueryItem(name: "historyLength", value: String(historyLength)))
        }
        return try await transport.get(
            from: .getTask(id: taskId),
            queryItems: queryItems,
            responseType: A2ATask.self
        )
    }

    /// Lists tasks with optional filtering.
    ///
    /// - Parameter params: Query parameters for filtering and pagination.
    /// - Returns: The list of tasks with pagination info.
    public func listTasks(_ params: TaskQueryParams = TaskQueryParams()) async throws -> TaskListResponse {
        var queryItems: [URLQueryItem] = []
        if let contextId = params.contextId {
            queryItems.append(URLQueryItem(name: "contextId", value: contextId))
        }
        if let status = params.status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let pageSize = params.pageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let pageToken = params.pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        if let historyLength = params.historyLength {
            queryItems.append(URLQueryItem(name: "historyLength", value: String(historyLength)))
        }
        if let statusTimestampAfter = params.statusTimestampAfter {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "statusTimestampAfter", value: formatter.string(from: statusTimestampAfter)))
        }
        if let includeArtifacts = params.includeArtifacts {
            queryItems.append(URLQueryItem(name: "includeArtifacts", value: String(includeArtifacts)))
        }
        return try await transport.get(
            from: .listTasks,
            queryItems: queryItems,
            responseType: TaskListResponse.self
        )
    }

    /// Lists all tasks in a context.
    ///
    /// - Parameter contextId: The context ID to filter by.
    /// - Returns: The list of tasks.
    public func listTasks(contextId: String) async throws -> TaskListResponse {
        let params = TaskQueryParams(contextId: contextId)
        return try await listTasks(params)
    }

    /// Cancels a task.
    ///
    /// - Parameters:
    ///   - taskId: The task ID to cancel.
    ///   - metadata: Optional metadata for the cancel request.
    /// - Returns: The updated task.
    public func cancelTask(_ taskId: String, metadata: [String: AnyCodable]? = nil) async throws -> A2ATask {
        let request = CancelTaskRequest(tenant: configuration.tenant, id: taskId, metadata: metadata)
        do {
            return try await transport.send(
                request: request,
                to: .cancelTask(id: taskId),
                responseType: A2ATask.self
            )
        } catch A2AError.taskNotCancelable(let tid, let state, let msg) where tid.isEmpty {
            // Server error data may not include taskId — fill it from the request
            throw A2AError.taskNotCancelable(taskId: taskId, state: state, message: msg)
        }
    }

    /// Subscribes to updates for an existing task.
    ///
    /// - Parameter taskId: The task ID to subscribe to.
    /// - Returns: An async sequence of streaming events.
    public func subscribeToTask(_ taskId: String) async throws -> AsyncThrowingStream<StreamingEvent, Error> {
        let request = TaskIdParams(tenant: configuration.tenant, id: taskId)
        return try await transport.stream(request: request, to: .subscribeToTask(id: taskId))
    }

    // MARK: - Push Notification Configuration

    /// Creates a push notification configuration for a task.
    ///
    /// - Parameters:
    ///   - taskId: The task ID.
    ///   - config: The push notification configuration.
    /// - Returns: The saved configuration with task association.
    public func createPushNotificationConfig(
        taskId: String,
        config: PushNotificationConfig
    ) async throws -> TaskPushNotificationConfig {
        let request = CreatePushNotificationConfigParams(tenant: configuration.tenant,
            taskId: taskId,
            config: config
        )
        return try await transport.send(
            request: request,
            to: .createPushNotificationConfig(taskId: taskId),
            responseType: TaskPushNotificationConfig.self
        )
    }

    /// Gets a push notification configuration.
    ///
    /// - Parameters:
    ///   - taskId: The task ID.
    ///   - configId: The configuration ID.
    /// - Returns: The push notification configuration.
    public func getPushNotificationConfig(
        taskId: String,
        configId: String
    ) async throws -> TaskPushNotificationConfig {
        // Pass the ids as query items so the JSON-RPC transport can
        // re-materialize them as `params`. REST ignores these since the
        // ids are already in the URL path.
        return try await transport.get(
            from: .getPushNotificationConfig(taskId: taskId, configId: configId),
            queryItems: [
                URLQueryItem(name: "taskId", value: taskId),
                URLQueryItem(name: "id", value: configId),
            ],
            responseType: TaskPushNotificationConfig.self
        )
    }

    /// Lists all push notification configurations for a task.
    ///
    /// - Parameter taskId: The task ID.
    /// - Returns: The list of configurations.
    public func listPushNotificationConfigs(taskId: String) async throws -> [TaskPushNotificationConfig] {
        let response = try await transport.get(
            from: .listPushNotificationConfigs(taskId: taskId),
            queryItems: [
                URLQueryItem(name: "taskId", value: taskId),
            ],
            responseType: ListPushNotificationConfigsResponse.self
        )
        return response.configs ?? []
    }

    /// Deletes a push notification configuration.
    ///
    /// - Parameters:
    ///   - taskId: The task ID.
    ///   - configId: The configuration ID to delete.
    public func deletePushNotificationConfig(
        taskId: String,
        configId: String
    ) async throws {
        let request = DeletePushNotificationConfigParams(tenant: configuration.tenant, taskId: taskId, id: configId)
        try await transport.send(
            request: request,
            to: .deletePushNotificationConfig(taskId: taskId, configId: configId)
        )
    }

    /// Sets a push notification configuration for a task.
    /// - Note: Deprecated. Use `createPushNotificationConfig` instead.
    @available(*, deprecated, renamed: "createPushNotificationConfig(taskId:config:)")
    public func setPushNotificationConfig(
        taskId: String,
        config: PushNotificationConfig
    ) async throws -> PushNotificationConfig {
        let result = try await createPushNotificationConfig(taskId: taskId, config: config)
        return result.pushNotificationConfig
    }

    // MARK: - Extended Agent Card

    /// Gets the extended agent card (requires authentication).
    ///
    /// - Returns: The extended agent card.
    public func getExtendedAgentCard() async throws -> AgentCard {
        return try await transport.get(
            from: .getExtendedAgentCard,
            queryItems: [],
            responseType: AgentCard.self
        )
    }
}

// MARK: - Request/Response Types

/// Request for sending a message.
public struct SendMessageRequest: Codable, Sendable {
    /// Optional tenant identifier.
    public let tenant: String?

    /// The message to send.
    public let message: Message

    /// Optional configuration for the send operation.
    public let configuration: MessageSendConfiguration?

    /// Optional metadata for the request.
    public let metadata: [String: AnyCodable]?

    public init(
        tenant: String? = nil,
        message: Message,
        configuration: MessageSendConfiguration? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.tenant = tenant
        self.message = message
        self.configuration = configuration
        self.metadata = metadata
    }
}

/// Response from sending a message.
///
/// The agent can respond with either a Task (for long-running operations)
/// or a Message (for immediate responses).
public enum SendMessageResponse: Codable, Sendable {
    /// A task was created for the request.
    case task(A2ATask)

    /// An immediate message response.
    case message(Message)

    private enum CodingKeys: String, CodingKey {
        case type
        case task
        case message
    }

    private enum DiscriminatorKeys: String, CodingKey {
        case status  // Present in A2ATask but not Message
        case role    // Present in Message but not A2ATask
    }

    public init(from decoder: Decoder) throws {
        // Use discriminating fields to determine the type.
        // A2ATask has a required "status" field; Message has a required "role" field.
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)

        if discriminator.contains(.status) {
            let task = try A2ATask(from: decoder)
            self = .task(task)
            return
        }

        if discriminator.contains(.role) {
            let message = try Message(from: decoder)
            self = .message(message)
            return
        }

        // Fallback: try wrapped format with explicit type field
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.task) {
            let task = try container.decode(A2ATask.self, forKey: .task)
            self = .task(task)
        } else if container.contains(.message) {
            let message = try container.decode(Message.self, forKey: .message)
            self = .message(message)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unable to decode SendMessageResponse: missing 'status' (Task) or 'role' (Message) field"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        // v0.3 used flat envelopes with a `kind` discriminator; v1.0 wraps
        // the payload in a field-presence oneof ({"task": …} / {"message": …}).
        if encoder.encodesA2AV03 {
            switch self {
            case .task(let task):
                try task.encode(to: encoder)
            case .message(let message):
                try message.encode(to: encoder)
            }
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .task(let task):
            try container.encode(task, forKey: .task)
        case .message(let message):
            try container.encode(message, forKey: .message)
        }
    }
}

// MARK: - Convenience Extensions

extension SendMessageResponse {
    /// Returns the task if this response contains one.
    public var task: A2ATask? {
        if case .task(let task) = self {
            return task
        }
        return nil
    }

    /// Returns the message if this response contains one.
    public var message: Message? {
        if case .message(let message) = self {
            return message
        }
        return nil
    }

    /// Returns whether this response is a task.
    public var isTask: Bool {
        if case .task = self {
            return true
        }
        return false
    }

    /// Returns whether this response is a message.
    public var isMessage: Bool {
        if case .message = self {
            return true
        }
        return false
    }
}
