// JSONRPCTransport.swift
// A2AClient
//
// Agent2Agent Protocol - JSON-RPC 2.0 Transport Implementation

import Foundation

/// JSON-RPC 2.0 transport implementation for A2A protocol.
///
/// This transport wraps requests in JSON-RPC 2.0 format and handles
/// the corresponding response unwrapping.
///
/// - Note: This type is `Sendable` because all stored properties are immutable after init.
///   `JSONEncoder`/`JSONDecoder` are created per-call via `makeEncoder()`/`makeDecoder()`
///   to avoid thread-safety concerns with shared mutable reference types.
///   `AtomicCounter` uses internal locking for thread safety.
public final class JSONRPCTransport: A2ATransport, Sendable {
    private let baseURL: URL
    private let session: URLSession
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
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if serviceParameters.jsonKeyCasing == .snakeCase {
            encoder.keyEncodingStrategy = .convertToSnakeCase
        }
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if serviceParameters.jsonKeyCasing == .snakeCase {
            decoder.keyDecodingStrategy = .convertFromSnakeCase
        }
        return decoder
    }

    // MARK: - A2ATransport Implementation

    public func send<Request: Encodable, Response: Decodable>(
        request: Request,
        to endpoint: A2AEndpoint,
        responseType: Response.Type
    ) async throws -> Response {
        let method = jsonRPCMethod(for: endpoint)
        let rpcRequest = JSONRPCRequest(
            id: .int(requestIdCounter.next()),
            method: method,
            params: request
        )

        let urlRequest = try await buildRequest(body: rpcRequest)
        let (data, response) = try await session.data(for: urlRequest)

        try validateHTTPResponse(response)

        let rpcResponse = try makeDecoder().decode(JSONRPCResponse<Response>.self, from: data)

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
            id: .int(requestIdCounter.next()),
            method: method,
            params: request
        )

        let urlRequest = try await buildRequest(body: rpcRequest)
        let (data, response) = try await session.data(for: urlRequest)

        try validateHTTPResponse(response)

        // Check for errors even without expecting a result
        if let rpcResponse = try? makeDecoder().decode(JSONRPCResponse<AnyCodable>.self, from: data),
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
            id: .int(requestIdCounter.next()),
            method: method,
            params: request
        )

        let urlRequest = try await buildRequest(body: rpcRequest, acceptSSE: true)

        return AsyncThrowingStream { continuation in
            let streamTask = _Concurrency.Task {
                do {
                    // Use URLSession.shared for streaming — custom URLSession(configuration:)
                    // can buffer the entire response instead of delivering bytes incrementally.
                    // Authentication is applied per-request, so .shared works correctly.
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    try validateHTTPResponse(response)

                    let parser = SSEParser()

                    for try await line in bytes.lines {
                        if let event = parser.parse(line: line) {
                            let streamingEvent = try decodeStreamingEvent(from: event)
                            continuation.yield(streamingEvent)
                        }
                    }

                    // Flush any remaining buffered event (last data: line with no trailing blank line)
                    if let event = parser.parse(line: "") {
                        let streamingEvent = try decodeStreamingEvent(from: event)
                        continuation.yield(streamingEvent)
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

    public func get<Response: Decodable>(
        from endpoint: A2AEndpoint,
        queryItems: [URLQueryItem],
        responseType: Response.Type
    ) async throws -> Response {
        // JSON-RPC wraps all requests as POST with method names.
        // Convert query items into a params dictionary for the RPC call.
        var params: [String: AnyCodable] = [:]
        for item in queryItems {
            if let value = item.value {
                // Try to preserve numeric types for JSON-RPC params
                if let intVal = Int(value) {
                    params[item.name] = AnyCodable(intVal)
                } else if let boolVal = Bool(value) {
                    params[item.name] = AnyCodable(boolVal)
                } else {
                    params[item.name] = AnyCodable(value)
                }
            }
        }

        let method = jsonRPCMethod(for: endpoint)
        let rpcRequest = JSONRPCRequest(
            id: .int(requestIdCounter.next()),
            method: method,
            params: params
        )

        let urlRequest = try await buildRequest(body: rpcRequest)
        let (data, response) = try await session.data(for: urlRequest)

        try validateHTTPResponse(response)

        let rpcResponse = try makeDecoder().decode(JSONRPCResponse<Response>.self, from: data)

        if let error = rpcResponse.error {
            throw error.toA2AError()
        }

        guard let result = rpcResponse.result else {
            throw A2AError.invalidResponse(message: "Missing result in JSON-RPC response")
        }

        return result
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

        return try makeDecoder().decode(Response.self, from: data)
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
            request.httpBody = try makeEncoder().encode(body)
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
        // Use the method name from the endpoint definition if available
        if let method = endpoint.jsonRPCMethod {
            return method
        }
        // Fallback: derive method name from path
        return endpoint.path.replacingOccurrences(of: "/", with: ".")
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private func decodeStreamingEvent(from sseEvent: SSEEvent) throws -> StreamingEvent {
        guard let data = sseEvent.data.data(using: .utf8) else {
            throw A2AError.invalidResponse(message: "Invalid SSE data encoding")
        }

        let decoder = makeDecoder()

        // JSON-RPC streaming: each SSE data line is a full JSON-RPC response
        // wrapping the actual event. The event's "kind" field discriminates the type.
        if let rpcResponse = try? decoder.decode(JSONRPCResponse<StreamEventResult>.self, from: data) {
            if let error = rpcResponse.error {
                throw error.toA2AError()
            }
            if let result = rpcResponse.result {
                return result.event
            }
        }

        // Fallback: try direct kind-based decoding (without JSON-RPC wrapper)
        if let result = try? decoder.decode(StreamEventResult.self, from: data) {
            return result.event
        }

        throw A2AError.invalidResponse(message: "Unknown streaming event format")
    }
}

// MARK: - JSON-RPC Types

/// JSON-RPC 2.0 id — can be a number or a string per the JSON-RPC 2.0 spec.
enum JSONRPCId: Codable, Sendable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }
}

/// JSON-RPC 2.0 request structure.
struct JSONRPCRequest<Params: Encodable>: Encodable {
    let jsonrpc: String = "2.0"
    let id: JSONRPCId
    let method: String
    let params: Params
}

/// JSON-RPC 2.0 response structure.
struct JSONRPCResponse<Result: Decodable>: Decodable {
    let jsonrpc: String
    let id: JSONRPCId?
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

/// Decodes a streaming event from a JSON-RPC result.
///
/// Supports two formats:
/// - **v1.0 (field-presence)**: Result has a `task`, `message`, `statusUpdate`,
///   or `artifactUpdate` key wrapping the event object.
/// - **v0.3 (kind-based)**: Result has a `kind` discriminator field at the top
///   level with the event fields alongside it.
struct StreamEventResult: Decodable {
    let event: StreamingEvent

    private enum CodingKeys: String, CodingKey {
        // v1.0 field-presence keys
        case task
        case message
        case statusUpdate
        case artifactUpdate
        // v0.3 kind-based key
        case kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // v1.0: field-presence oneofs (result wraps the event in a named key)
        if container.contains(.task) {
            let task = try container.decode(A2ATask.self, forKey: .task)
            self.event = .task(task)
        } else if container.contains(.message) {
            let message = try container.decode(Message.self, forKey: .message)
            self.event = .message(message)
        } else if container.contains(.statusUpdate) {
            let update = try container.decode(TaskStatusUpdateEvent.self, forKey: .statusUpdate)
            self.event = .taskStatusUpdate(update)
        } else if container.contains(.artifactUpdate) {
            let update = try container.decode(TaskArtifactUpdateEvent.self, forKey: .artifactUpdate)
            self.event = .taskArtifactUpdate(update)
        }
        // v0.3: kind-based discrimination (event fields are at the top level)
        else if let kind = try container.decodeIfPresent(String.self, forKey: .kind) {
            switch kind {
            case "task":
                let task = try A2ATask(from: decoder)
                self.event = .task(task)
            case "message":
                let message = try Message(from: decoder)
                self.event = .message(message)
            case "status-update":
                let update = try TaskStatusUpdateEvent(from: decoder)
                self.event = .taskStatusUpdate(update)
            case "artifact-update":
                let update = try TaskArtifactUpdateEvent(from: decoder)
                self.event = .taskArtifactUpdate(update)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Unknown streaming event kind: \(kind)"
                    )
                )
            }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Streaming event has neither field-presence keys nor kind discriminator"
                )
            )
        }
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
