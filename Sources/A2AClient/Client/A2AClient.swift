// A2AClient.swift
// A2AClient
//
// Agent2Agent Protocol - Main Client Implementation

import Foundation

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
        self.session = URLSession(configuration: configuration.sessionConfiguration)

        let serviceParameters = A2AServiceParameters(
            version: configuration.protocolVersion,
            extensions: configuration.extensions
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

        let session = URLSession.shared
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2AError.invalidResponse(message: "Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            throw A2AError.invalidResponse(message: "HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(AgentCard.self, from: data)
        } catch {
            throw A2AError.encodingError(underlying: error)
        }
    }

    /// Fetches the agent card from a specific URL.
    public static func fetchAgentCard(from url: URL) async throws -> AgentCard {
        let session = URLSession.shared
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2AError.invalidResponse(message: "Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            throw A2AError.invalidResponse(message: "HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(AgentCard.self, from: data)
    }

    // MARK: - Message Operations

    /// Sends a message to the agent.
    ///
    /// This is the primary method for initiating agent interactions.
    /// The agent may respond with either a Task (for long-running operations)
    /// or a Message (for immediate responses).
    ///
    /// - Parameter message: The message to send.
    /// - Returns: The response, which is either a Task or Message.
    public func sendMessage(_ message: Message) async throws -> SendMessageResponse {
        let request = SendMessageRequest(message: message)
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
    /// - Returns: The response, which is either a Task or Message.
    public func sendMessage(
        _ text: String,
        contextId: String? = nil,
        taskId: String? = nil
    ) async throws -> SendMessageResponse {
        let message = Message.user(text, contextId: contextId, taskId: taskId)
        return try await sendMessage(message)
    }

    /// Sends a streaming message to the agent.
    ///
    /// Returns an async sequence of streaming events that can be iterated
    /// to receive real-time updates.
    ///
    /// - Parameter message: The message to send.
    /// - Returns: An async sequence of streaming events.
    public func sendStreamingMessage(_ message: Message) async throws -> AsyncThrowingStream<StreamingEvent, Error> {
        let request = SendMessageRequest(message: message)
        return try await transport.stream(request: request, to: .sendStreamingMessage)
    }

    /// Sends a streaming message with text content.
    ///
    /// - Parameters:
    ///   - text: The text content to send.
    ///   - contextId: Optional context ID for multi-turn conversations.
    ///   - taskId: Optional task ID to continue an existing task.
    /// - Returns: An async sequence of streaming events.
    public func sendStreamingMessage(
        _ text: String,
        contextId: String? = nil,
        taskId: String? = nil
    ) async throws -> AsyncThrowingStream<StreamingEvent, Error> {
        let message = Message.user(text, contextId: contextId, taskId: taskId)
        return try await sendStreamingMessage(message)
    }

    // MARK: - Task Management

    /// Gets a task by its ID.
    ///
    /// - Parameter taskId: The task ID.
    /// - Returns: The task.
    public func getTask(_ taskId: String) async throws -> A2ATask {
        let request = TaskIdParams(id: taskId)
        return try await transport.send(
            request: request,
            to: .getTask(id: taskId),
            responseType: A2ATask.self
        )
    }

    /// Lists tasks with optional filtering.
    ///
    /// - Parameter params: Query parameters for filtering and pagination.
    /// - Returns: The list of tasks with pagination info.
    public func listTasks(_ params: TaskQueryParams = TaskQueryParams()) async throws -> TaskListResponse {
        return try await transport.send(
            request: params,
            to: .listTasks,
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
    /// - Parameter taskId: The task ID to cancel.
    /// - Returns: The updated task.
    public func cancelTask(_ taskId: String) async throws -> A2ATask {
        let request = TaskIdParams(id: taskId)
        return try await transport.send(
            request: request,
            to: .cancelTask(id: taskId),
            responseType: A2ATask.self
        )
    }

    /// Subscribes to updates for an existing task.
    ///
    /// - Parameter taskId: The task ID to subscribe to.
    /// - Returns: An async sequence of streaming events.
    public func subscribeToTask(_ taskId: String) async throws -> AsyncThrowingStream<StreamingEvent, Error> {
        let request = TaskIdParams(id: taskId)
        return try await transport.stream(request: request, to: .subscribeToTask(id: taskId))
    }

    // MARK: - Push Notification Configuration

    /// Sets a push notification configuration for a task.
    ///
    /// - Parameters:
    ///   - taskId: The task ID.
    ///   - config: The push notification configuration.
    /// - Returns: The saved configuration.
    public func setPushNotificationConfig(
        taskId: String,
        config: PushNotificationConfig
    ) async throws -> PushNotificationConfig {
        let request = SetPushNotificationConfigParams(
            taskId: taskId,
            pushNotificationConfig: config
        )
        return try await transport.send(
            request: request,
            to: .setPushNotificationConfig(taskId: taskId, configId: config.id),
            responseType: PushNotificationConfig.self
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
    ) async throws -> PushNotificationConfig {
        let request = GetPushNotificationConfigParams(taskId: taskId, id: configId)
        return try await transport.send(
            request: request,
            to: .getPushNotificationConfig(taskId: taskId, configId: configId),
            responseType: PushNotificationConfig.self
        )
    }

    /// Lists all push notification configurations for a task.
    ///
    /// - Parameter taskId: The task ID.
    /// - Returns: The list of configurations.
    public func listPushNotificationConfigs(taskId: String) async throws -> [PushNotificationConfig] {
        let request = ListPushNotificationConfigsParams(taskId: taskId)
        let response = try await transport.send(
            request: request,
            to: .listPushNotificationConfigs(taskId: taskId),
            responseType: ListPushNotificationConfigsResponse.self
        )
        return response.configs
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
        let request = DeletePushNotificationConfigParams(taskId: taskId, id: configId)
        try await transport.send(
            request: request,
            to: .deletePushNotificationConfig(taskId: taskId, configId: configId)
        )
    }

    // MARK: - Extended Agent Card

    /// Gets the extended agent card (requires authentication).
    ///
    /// - Returns: The extended agent card.
    public func getExtendedAgentCard() async throws -> AgentCard {
        // Construct URL properly without double slashes
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: true) else {
            throw A2AError.invalidRequest(message: "Invalid base URL")
        }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/agentCard:extended"
        guard let url = components.url else {
            throw A2AError.invalidRequest(message: "Could not construct extended agent card URL")
        }
        return try await transport.fetch(
            from: url,
            responseType: AgentCard.self
        )
    }
}

// MARK: - Request/Response Types

/// Request for sending a message.
public struct SendMessageRequest: Codable, Sendable {
    /// The message to send.
    public let message: Message

    public init(message: Message) {
        self.message = message
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

    public init(from decoder: Decoder) throws {
        // Try to decode as a Task first
        if let task = try? A2ATask(from: decoder) {
            self = .task(task)
            return
        }

        // Try to decode as a Message
        if let message = try? Message(from: decoder) {
            self = .message(message)
            return
        }

        // Try to decode with explicit type field
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
                debugDescription: "Unable to decode SendMessageResponse"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .task(let task):
            try task.encode(to: encoder)
        case .message(let message):
            try message.encode(to: encoder)
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
