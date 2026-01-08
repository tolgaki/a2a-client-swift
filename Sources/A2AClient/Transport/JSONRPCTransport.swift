// JSONRPCTransport.swift
// A2AClient
//
// Agent2Agent Protocol - JSON-RPC 2.0 Transport Implementation

import Foundation

/// JSON-RPC 2.0 transport implementation for A2A protocol.
///
/// This transport wraps requests in JSON-RPC 2.0 format and handles
/// the corresponding response unwrapping.
public final class JSONRPCTransport: A2ATransport, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let serviceParameters: A2AServiceParameters
    private let authenticationProvider: AuthenticationProvider?

    /// Counter for generating unique request IDs.
    private let requestIdCounter = AtomicCounter()

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        serviceParameters: A2AServiceParameters = A2AServiceParameters(),
        authenticationProvider: AuthenticationProvider? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.serviceParameters = serviceParameters
        self.authenticationProvider = authenticationProvider

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - A2ATransport Implementation

    public func send<Request: Encodable, Response: Decodable>(
        request: Request,
        to endpoint: A2AEndpoint,
        responseType: Response.Type
    ) async throws -> Response {
        let method = jsonRPCMethod(for: endpoint)
        let rpcRequest = JSONRPCRequest(
            id: requestIdCounter.next(),
            method: method,
            params: request
        )

        let urlRequest = try await buildRequest(body: rpcRequest)
        let (data, response) = try await session.data(for: urlRequest)

        try validateHTTPResponse(response)

        let rpcResponse = try decoder.decode(JSONRPCResponse<Response>.self, from: data)

        if let error = rpcResponse.error {
            throw error.toA2AError()
        }

        guard let result = rpcResponse.result else {
            throw A2AError.invalidResponse(message: "Missing result in JSON-RPC response")
        }

        return result
    }

    public func send<Request: Encodable>(
        request: Request,
        to endpoint: A2AEndpoint
    ) async throws {
        let method = jsonRPCMethod(for: endpoint)
        let rpcRequest = JSONRPCRequest(
            id: requestIdCounter.next(),
            method: method,
            params: request
        )

        let urlRequest = try await buildRequest(body: rpcRequest)
        let (data, response) = try await session.data(for: urlRequest)

        try validateHTTPResponse(response)

        // Check for errors even without expecting a result
        if let rpcResponse = try? decoder.decode(JSONRPCResponse<AnyCodable>.self, from: data),
           let error = rpcResponse.error {
            throw error.toA2AError()
        }
    }

    public func stream<Request: Encodable>(
        request: Request,
        to endpoint: A2AEndpoint
    ) async throws -> AsyncThrowingStream<StreamingEvent, Error> {
        let method = jsonRPCMethod(for: endpoint)
        let rpcRequest = JSONRPCRequest(
            id: requestIdCounter.next(),
            method: method,
            params: request
        )

        let urlRequest = try await buildRequest(body: rpcRequest, acceptSSE: true)

        return AsyncThrowingStream { continuation in
            let streamTask = _Concurrency.Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    try validateHTTPResponse(response)

                    let parser = SSEParser()

                    for try await line in bytes.lines {
                        if let event = parser.parse(line: line) {
                            if let streamingEvent = try? decodeStreamingEvent(from: event) {
                                continuation.yield(streamingEvent)
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                streamTask.cancel()
            }
        }
    }

    public func fetch<Response: Decodable>(
        from url: URL,
        responseType: Response.Type
    ) async throws -> Response {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let auth = authenticationProvider {
            urlRequest = try await auth.authenticate(request: urlRequest)
        }

        let (data, response) = try await session.data(for: urlRequest)
        try validateHTTPResponse(response)

        return try decoder.decode(Response.self, from: data)
    }

    // MARK: - Private Helpers

    private func buildRequest<Body: Encodable>(
        body: Body,
        acceptSSE: Bool = false
    ) async throws -> URLRequest {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"

        // JSON-RPC always uses POST with JSON content
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if acceptSSE {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }

        // Add service parameter headers
        for (key, value) in serviceParameters.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw A2AError.encodingError(underlying: error)
        }

        // Apply authentication
        if let auth = authenticationProvider {
            request = try await auth.authenticate(request: request)
        }

        return request
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2AError.invalidResponse(message: "Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw A2AError.authenticationRequired(message: "Authentication required")
        case 403:
            throw A2AError.authorizationFailed(message: "Access denied")
        default:
            throw A2AError.internalError(message: "HTTP \(httpResponse.statusCode)")
        }
    }

    private func jsonRPCMethod(for endpoint: A2AEndpoint) -> String {
        // Map endpoints to JSON-RPC method names
        switch endpoint.path {
        case "/messages:send":
            return "SendMessage"
        case "/messages:stream":
            return "SendStreamingMessage"
        case let path where path.contains("/tasks/") && path.hasSuffix(":cancel"):
            return "CancelTask"
        case let path where path.contains("/tasks/") && path.hasSuffix(":subscribe"):
            return "SubscribeToTask"
        case let path where path.contains("/pushNotificationConfigs"):
            if endpoint.method == .put {
                return "SetTaskPushNotificationConfig"
            } else if endpoint.method == .get && !path.hasSuffix("/pushNotificationConfigs") {
                return "GetTaskPushNotificationConfig"
            } else if endpoint.method == .get {
                return "ListTaskPushNotificationConfigs"
            } else if endpoint.method == .delete {
                return "DeleteTaskPushNotificationConfig"
            }
            return "PushNotificationConfig"
        case "/tasks":
            return "ListTasks"
        case let path where path.hasPrefix("/tasks/"):
            return "GetTask"
        case "/agentCard:extended":
            return "GetExtendedAgentCard"
        default:
            // Use path as method name fallback
            return endpoint.path.replacingOccurrences(of: "/", with: ".")
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
    }

    private func decodeStreamingEvent(from sseEvent: SSEEvent) throws -> StreamingEvent {
        guard let data = sseEvent.data.data(using: .utf8) else {
            throw A2AError.invalidResponse(message: "Invalid SSE data encoding")
        }

        // For JSON-RPC streaming, events may be wrapped in JSON-RPC response format
        // First try direct decoding
        if let update = try? decoder.decode(TaskStatusUpdateEvent.self, from: data) {
            return .taskStatusUpdate(update)
        } else if let update = try? decoder.decode(TaskArtifactUpdateEvent.self, from: data) {
            return .taskArtifactUpdate(update)
        }

        // Try JSON-RPC wrapped format
        if let rpcResponse = try? decoder.decode(JSONRPCResponse<StreamEventWrapper>.self, from: data),
           let result = rpcResponse.result {
            if let statusUpdate = result.statusUpdate {
                return .taskStatusUpdate(statusUpdate)
            } else if let artifactUpdate = result.artifactUpdate {
                return .taskArtifactUpdate(artifactUpdate)
            }
        }

        throw A2AError.invalidResponse(message: "Unknown streaming event format")
    }
}

// MARK: - JSON-RPC Types

/// JSON-RPC 2.0 request structure.
struct JSONRPCRequest<Params: Encodable>: Encodable {
    let jsonrpc: String = "2.0"
    let id: Int
    let method: String
    let params: Params
}

/// JSON-RPC 2.0 response structure.
struct JSONRPCResponse<Result: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int?
    let result: Result?
    let error: JSONRPCError?
}

/// JSON-RPC 2.0 error structure.
struct JSONRPCError: Decodable {
    let code: Int
    let message: String
    let data: AnyCodable?

    func toA2AError() -> A2AError {
        A2AErrorResponse(code: code, message: message, data: data).toA2AError()
    }
}

/// Wrapper for streaming events that may contain either status or artifact updates.
struct StreamEventWrapper: Decodable {
    let statusUpdate: TaskStatusUpdateEvent?
    let artifactUpdate: TaskArtifactUpdateEvent?

    private enum CodingKeys: String, CodingKey {
        case statusUpdate = "status_update"
        case artifactUpdate = "artifact_update"
    }
}

// MARK: - Atomic Counter

/// Thread-safe counter for generating unique request IDs.
final class AtomicCounter: @unchecked Sendable {
    private var value: Int = 0
    private let lock = NSLock()

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
