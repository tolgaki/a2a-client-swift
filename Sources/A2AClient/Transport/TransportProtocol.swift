// TransportProtocol.swift
// A2AClient
//
// Agent2Agent Protocol - Transport Layer Abstraction

import Foundation

/// Protocol defining the transport layer interface for A2A communications.
///
/// Transport implementations handle the actual HTTP/network communication,
/// allowing for different binding types (HTTP/REST, JSON-RPC) and testing mocks.
public protocol A2ATransport: Sendable {
    /// Sends a request and returns a decoded response.
    func send<Request: Encodable, Response: Decodable>(
        request: Request,
        to endpoint: A2AEndpoint,
        responseType: Response.Type
    ) async throws -> Response

    /// Sends a request without expecting a response body.
    func send<Request: Encodable>(
        request: Request,
        to endpoint: A2AEndpoint
    ) async throws

    /// Opens a streaming connection and returns an async sequence of events.
    func stream<Request: Encodable>(
        request: Request,
        to endpoint: A2AEndpoint
    ) async throws -> AsyncThrowingStream<StreamingEvent, Error>

    /// Fetches data from a URL (used for agent card discovery).
    func fetch<Response: Decodable>(
        from url: URL,
        responseType: Response.Type
    ) async throws -> Response
}

/// Represents an A2A API endpoint.
public struct A2AEndpoint: Sendable, Equatable {
    /// The HTTP method to use.
    public let method: HTTPMethod

    /// The path relative to the base URL.
    public let path: String

    /// Whether this endpoint returns a streaming response.
    public let isStreaming: Bool

    public init(method: HTTPMethod, path: String, isStreaming: Bool = false) {
        self.method = method
        self.path = path
        self.isStreaming = isStreaming
    }

    // MARK: - Standard A2A Endpoints

    /// Send a message to the agent.
    public static let sendMessage = A2AEndpoint(method: .post, path: "/messages:send")

    /// Send a streaming message to the agent.
    public static let sendStreamingMessage = A2AEndpoint(method: .post, path: "/messages:stream", isStreaming: true)

    /// Get a task by ID.
    public static func getTask(id: String) -> A2AEndpoint {
        A2AEndpoint(method: .get, path: "/tasks/\(id)")
    }

    /// List tasks.
    public static let listTasks = A2AEndpoint(method: .get, path: "/tasks")

    /// Cancel a task.
    public static func cancelTask(id: String) -> A2AEndpoint {
        A2AEndpoint(method: .post, path: "/tasks/\(id):cancel")
    }

    /// Subscribe to task updates.
    public static func subscribeToTask(id: String) -> A2AEndpoint {
        A2AEndpoint(method: .get, path: "/tasks/\(id):subscribe", isStreaming: true)
    }

    /// Set push notification configuration.
    public static func setPushNotificationConfig(taskId: String, configId: String) -> A2AEndpoint {
        A2AEndpoint(method: .put, path: "/tasks/\(taskId)/pushNotificationConfigs/\(configId)")
    }

    /// Get push notification configuration.
    public static func getPushNotificationConfig(taskId: String, configId: String) -> A2AEndpoint {
        A2AEndpoint(method: .get, path: "/tasks/\(taskId)/pushNotificationConfigs/\(configId)")
    }

    /// List push notification configurations.
    public static func listPushNotificationConfigs(taskId: String) -> A2AEndpoint {
        A2AEndpoint(method: .get, path: "/tasks/\(taskId)/pushNotificationConfigs")
    }

    /// Delete push notification configuration.
    public static func deletePushNotificationConfig(taskId: String, configId: String) -> A2AEndpoint {
        A2AEndpoint(method: .delete, path: "/tasks/\(taskId)/pushNotificationConfigs/\(configId)")
    }

    /// Get extended agent card.
    public static let getExtendedAgentCard = A2AEndpoint(method: .get, path: "/agentCard:extended")
}

/// HTTP methods used by the A2A protocol.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// Service parameters sent with A2A requests.
public struct A2AServiceParameters: Sendable {
    /// The A2A protocol version.
    public let version: String

    /// Comma-separated list of extension URIs.
    public let extensions: [String]?

    public init(version: String = "1.0", extensions: [String]? = nil) {
        self.version = version
        self.extensions = extensions
    }

    /// HTTP header name for version.
    public static let versionHeader = "A2A-Version"

    /// HTTP header name for extensions.
    public static let extensionsHeader = "A2A-Extensions"

    /// Returns headers for these service parameters.
    public var headers: [String: String] {
        var headers = [A2AServiceParameters.versionHeader: version]
        if let extensions = extensions, !extensions.isEmpty {
            headers[A2AServiceParameters.extensionsHeader] = extensions.joined(separator: ",")
        }
        return headers
    }
}
