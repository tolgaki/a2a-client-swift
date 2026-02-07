// TransportProtocol.swift
// A2AClient
//
// Agent2Agent Protocol - Transport Layer Abstraction
// Spec: https://a2a-protocol.org/latest/specification/#11-httpjsonrest-protocol-binding

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

    /// Sends a GET request with query parameters and returns a decoded response.
    func get<Response: Decodable>(
        from endpoint: A2AEndpoint,
        queryItems: [URLQueryItem],
        responseType: Response.Type
    ) async throws -> Response

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

    /// The JSON-RPC method name for this endpoint.
    public let jsonRPCMethod: String?

    public init(method: HTTPMethod, path: String, isStreaming: Bool = false, jsonRPCMethod: String? = nil) {
        self.method = method
        self.path = path
        self.isStreaming = isStreaming
        self.jsonRPCMethod = jsonRPCMethod
    }

    // MARK: - Standard A2A Endpoints (per spec)

    /// Send a message to the agent.
    /// Spec: POST /message:send (or /{tenant}/message:send)
    public static let sendMessage = A2AEndpoint(method: .post, path: "/message:send", jsonRPCMethod: "message/send")

    /// Send a streaming message to the agent.
    /// Spec: POST /message:stream (or /{tenant}/message:stream)
    public static let sendStreamingMessage = A2AEndpoint(method: .post, path: "/message:stream", isStreaming: true, jsonRPCMethod: "message/stream")

    /// Get a task by ID.
    /// Spec: GET /tasks/{id} (or /{tenant}/tasks/{id})
    public static func getTask(id: String) -> A2AEndpoint {
        A2AEndpoint(method: .get, path: "/tasks/\(Self.sanitizePathComponent(id))", jsonRPCMethod: "tasks/get")
    }

    /// List tasks.
    /// Spec: GET /tasks (or /{tenant}/tasks)
    public static let listTasks = A2AEndpoint(method: .get, path: "/tasks", jsonRPCMethod: "tasks/list")

    /// Cancel a task.
    /// Spec: POST /tasks/{id}:cancel (or /{tenant}/tasks/{id}:cancel)
    public static func cancelTask(id: String) -> A2AEndpoint {
        A2AEndpoint(method: .post, path: "/tasks/\(Self.sanitizePathComponent(id)):cancel", jsonRPCMethod: "tasks/cancel")
    }

    /// Subscribe to task updates.
    /// Spec: GET /tasks/{id}:subscribe (or /{tenant}/tasks/{id}:subscribe)
    public static func subscribeToTask(id: String) -> A2AEndpoint {
        A2AEndpoint(method: .get, path: "/tasks/\(Self.sanitizePathComponent(id)):subscribe", isStreaming: true, jsonRPCMethod: "tasks/resubscribe")
    }

    /// Create push notification configuration.
    /// Spec: POST /tasks/{taskId}/pushNotificationConfigs
    public static func createPushNotificationConfig(taskId: String) -> A2AEndpoint {
        A2AEndpoint(method: .post, path: "/tasks/\(Self.sanitizePathComponent(taskId))/pushNotificationConfigs", jsonRPCMethod: "tasks/pushNotificationConfig/set")
    }

    /// Get push notification configuration.
    /// Spec: GET /tasks/{taskId}/pushNotificationConfigs/{id}
    public static func getPushNotificationConfig(taskId: String, configId: String) -> A2AEndpoint {
        A2AEndpoint(method: .get, path: "/tasks/\(Self.sanitizePathComponent(taskId))/pushNotificationConfigs/\(Self.sanitizePathComponent(configId))", jsonRPCMethod: "tasks/pushNotificationConfig/get")
    }

    /// List push notification configurations.
    /// Spec: GET /tasks/{taskId}/pushNotificationConfigs
    public static func listPushNotificationConfigs(taskId: String) -> A2AEndpoint {
        A2AEndpoint(method: .get, path: "/tasks/\(Self.sanitizePathComponent(taskId))/pushNotificationConfigs", jsonRPCMethod: "tasks/pushNotificationConfig/list")
    }

    /// Delete push notification configuration.
    /// Spec: DELETE /tasks/{taskId}/pushNotificationConfigs/{id}
    public static func deletePushNotificationConfig(taskId: String, configId: String) -> A2AEndpoint {
        A2AEndpoint(method: .delete, path: "/tasks/\(Self.sanitizePathComponent(taskId))/pushNotificationConfigs/\(Self.sanitizePathComponent(configId))", jsonRPCMethod: "tasks/pushNotificationConfig/delete")
    }

    /// Get extended agent card.
    /// Spec: GET /extendedAgentCard (or /{tenant}/extendedAgentCard)
    public static let getExtendedAgentCard = A2AEndpoint(method: .get, path: "/extendedAgentCard", jsonRPCMethod: "agent/authenticatedExtendedCard")

    /// Returns the path with an optional tenant prefix prepended.
    ///
    /// - Parameter tenant: Optional tenant identifier. If set, the path becomes `/{tenant}{path}`.
    /// - Returns: The path with tenant prefix if applicable.
    public func pathWithTenant(_ tenant: String?) -> String {
        guard let tenant = tenant, !tenant.isEmpty else {
            return path
        }
        let sanitizedTenant = Self.sanitizePathComponent(tenant)
        return "/\(sanitizedTenant)\(path)"
    }

    // MARK: - Path Sanitization

    /// Sanitizes a path component to prevent path traversal attacks.
    /// Percent-encodes special characters and removes path separators.
    static func sanitizePathComponent(_ component: String) -> String {
        // Remove any path separators and null bytes
        let sanitized = component
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: "\0", with: "")

        // Percent-encode for URL safety
        return sanitized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sanitized
    }

    // MARK: - Legacy Endpoint Aliases (Deprecated)

    /// Legacy endpoint - use createPushNotificationConfig instead.
    @available(*, deprecated, renamed: "createPushNotificationConfig(taskId:)")
    public static func setPushNotificationConfig(taskId: String, configId: String) -> A2AEndpoint {
        A2AEndpoint(method: .put, path: "/tasks/\(sanitizePathComponent(taskId))/pushNotificationConfigs/\(sanitizePathComponent(configId))", jsonRPCMethod: "tasks/pushNotificationConfig/set")
    }
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

    /// Optional tenant identifier for multi-tenant agents.
    public let tenant: String?

    public init(version: String = "1.0", extensions: [String]? = nil, tenant: String? = nil) {
        self.version = version
        self.extensions = extensions
        self.tenant = tenant
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
