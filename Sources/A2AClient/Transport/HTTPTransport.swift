// HTTPTransport.swift
// A2AClient
//
// Agent2Agent Protocol - HTTP/REST Transport Implementation

import Foundation

/// HTTP/REST transport implementation for A2A protocol.
///
/// This transport uses standard HTTP methods and URL patterns as defined
/// in the A2A HTTP/REST binding specification.
///
/// - Note: This type is `Sendable` because all stored properties are immutable after init.
///   `JSONEncoder`/`JSONDecoder` are created per-call via `makeEncoder()`/`makeDecoder()`
///   to avoid thread-safety concerns with shared mutable reference types.
public final class HTTPTransport: A2ATransport, Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let serviceParameters: A2AServiceParameters
    private let authenticationProvider: AuthenticationProvider?

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
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - A2ATransport Implementation

    public func send<Request: Encodable, Response: Decodable>(
        request: Request,
        to endpoint: A2AEndpoint,
        responseType: Response.Type
    ) async throws -> Response {
        let urlRequest = try await buildRequest(for: endpoint, body: request)
        let (data, response) = try await session.data(for: urlRequest)

        try validateResponse(response, data: data)

        do {
            return try makeDecoder().decode(Response.self, from: data)
        } catch {
            throw A2AError.encodingError(underlying: error)
        }
    }

    public func send<Request: Encodable>(
        request: Request,
        to endpoint: A2AEndpoint
    ) async throws {
        let urlRequest = try await buildRequest(for: endpoint, body: request)
        let (data, response) = try await session.data(for: urlRequest)

        try validateResponse(response, data: data)
    }

    public func stream<Request: Encodable>(
        request: Request,
        to endpoint: A2AEndpoint
    ) async throws -> AsyncThrowingStream<StreamingEvent, Error> {
        let urlRequest = try await buildRequest(for: endpoint, body: request, acceptSSE: true)

        return AsyncThrowingStream { continuation in
            let streamTask = _Concurrency.Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    try validateResponse(response, data: nil)

                    let parser = SSEParser()

                    for try await line in bytes.lines {
                        if let event = parser.parse(line: line) {
                            let streamingEvent = try decodeStreamingEvent(from: event)
                            continuation.yield(streamingEvent)
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

    public func get<Response: Decodable>(
        from endpoint: A2AEndpoint,
        queryItems: [URLQueryItem],
        responseType: Response.Type
    ) async throws -> Response {
        let path = endpoint.pathWithTenant(serviceParameters.tenant)
        let url = baseURL.appendingPathComponent(path)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw A2AError.invalidRequest(message: "Invalid URL for endpoint: \(path)")
        }

        let nonNilItems = queryItems.filter { $0.value != nil }
        if !nonNilItems.isEmpty {
            components.queryItems = nonNilItems
        }

        guard let finalURL = components.url else {
            throw A2AError.invalidRequest(message: "Could not construct URL with query parameters")
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        for (key, value) in serviceParameters.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let auth = authenticationProvider {
            request = try await auth.authenticate(request: request)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            return try makeDecoder().decode(Response.self, from: data)
        } catch {
            throw A2AError.encodingError(underlying: error)
        }
    }

    public func fetch<Response: Decodable>(
        from url: URL,
        responseType: Response.Type
    ) async throws -> Response {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HTTPMethod.get.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let auth = authenticationProvider {
            urlRequest = try await auth.authenticate(request: urlRequest)
        }

        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)

        do {
            return try makeDecoder().decode(Response.self, from: data)
        } catch {
            throw A2AError.encodingError(underlying: error)
        }
    }

    // MARK: - Private Helpers

    private func buildRequest<Body: Encodable>(
        for endpoint: A2AEndpoint,
        body: Body? = nil as Empty?,
        acceptSSE: Bool = false
    ) async throws -> URLRequest {
        let path = endpoint.pathWithTenant(serviceParameters.tenant)
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Set accept headers
        if acceptSSE {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }

        // Add service parameter headers
        for (key, value) in serviceParameters.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body for non-GET requests
        if let body = body, endpoint.method != .get {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try makeEncoder().encode(body)
            } catch {
                throw A2AError.encodingError(underlying: error)
            }
        }

        // Apply authentication
        if let auth = authenticationProvider {
            request = try await auth.authenticate(request: request)
        }

        return request
    }

    private func validateResponse(_ response: URLResponse, data: Data?) throws {
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
        case 404:
            // Try to parse error response for more details
            if let data = data, let errorResponse = try? makeDecoder().decode(A2AErrorResponse.self, from: data) {
                throw errorResponse.toA2AError()
            }
            // Generic 404 - could be any resource, not just a task
            throw A2AError.invalidResponse(message: "Resource not found (HTTP 404)")
        case 415:
            throw A2AError.contentTypeNotSupported(
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown",
                message: "Unsupported media type"
            )
        case 400:
            if let data = data, let errorResponse = try? makeDecoder().decode(A2AErrorResponse.self, from: data) {
                throw errorResponse.toA2AError()
            }
            throw A2AError.invalidRequest(message: "Bad request (HTTP 400)")
        case 500...599:
            if let data = data, let errorResponse = try? makeDecoder().decode(A2AErrorResponse.self, from: data) {
                throw errorResponse.toA2AError()
            }
            throw A2AError.internalError(message: "Server error (HTTP \(httpResponse.statusCode))")
        default:
            if let data = data, let errorResponse = try? makeDecoder().decode(A2AErrorResponse.self, from: data) {
                throw errorResponse.toA2AError()
            }
            throw A2AError.internalError(message: "HTTP \(httpResponse.statusCode)")
        }
    }

    private func decodeStreamingEvent(from sseEvent: SSEEvent) throws -> StreamingEvent {
        guard let data = sseEvent.data.data(using: .utf8) else {
            throw A2AError.invalidResponse(message: "Invalid SSE data encoding")
        }

        let decoder = makeDecoder()

        // Try to decode as different event types based on event type
        switch sseEvent.event {
        case "status":
            let update = try decoder.decode(TaskStatusUpdateEvent.self, from: data)
            return .taskStatusUpdate(update)
        case "artifact":
            let update = try decoder.decode(TaskArtifactUpdateEvent.self, from: data)
            return .taskArtifactUpdate(update)
        case "task":
            let task = try decoder.decode(A2ATask.self, from: data)
            return .task(task)
        case "message":
            let message = try decoder.decode(Message.self, from: data)
            return .message(message)
        default:
            // Try to auto-detect the event type for backward compatibility
            // or when event type header is missing
            if let update = try? decoder.decode(TaskStatusUpdateEvent.self, from: data) {
                return .taskStatusUpdate(update)
            } else if let update = try? decoder.decode(TaskArtifactUpdateEvent.self, from: data) {
                return .taskArtifactUpdate(update)
            } else if let task = try? decoder.decode(A2ATask.self, from: data) {
                return .task(task)
            } else if let message = try? decoder.decode(Message.self, from: data) {
                return .message(message)
            }
            throw A2AError.invalidResponse(message: "Unknown or malformed event type: \(sseEvent.event ?? "none")")
        }
    }
}

// MARK: - Empty Request Body

/// Empty request body for endpoints that don't require a body.
private struct Empty: Encodable {}

// MARK: - SSE Parser

/// Parser for Server-Sent Events (SSE) format.
///
/// This parser is designed to be used within a single async context.
/// Each streaming connection should create its own parser instance.
final class SSEParser {
    private var currentEvent: String?
    private var currentData: [String] = []
    private var currentId: String?

    struct SSEEvent: Sendable {
        let event: String?
        let data: String
        let id: String?
    }

    /// Parses a single line of SSE input.
    ///
    /// - Parameter line: The line to parse.
    /// - Returns: An SSEEvent if the line completes an event, nil otherwise.
    /// - Note: This method is not thread-safe. Use one parser per stream.
    func parse(line: String) -> SSEEvent? {
        // Empty line signals end of event
        if line.isEmpty {
            guard !currentData.isEmpty else { return nil }

            let event = SSEEvent(
                event: currentEvent,
                data: currentData.joined(separator: "\n"),
                id: currentId
            )

            // Reset state
            currentEvent = nil
            currentData = []
            currentId = nil

            return event
        }

        // Parse field — per the SSE spec, only strip a single leading space after the colon
        if line.hasPrefix("event:") {
            currentEvent = Self.stripSingleLeadingSpace(String(line.dropFirst(6)))
        } else if line.hasPrefix("data:") {
            currentData.append(Self.stripSingleLeadingSpace(String(line.dropFirst(5))))
        } else if line.hasPrefix("id:") {
            currentId = Self.stripSingleLeadingSpace(String(line.dropFirst(3)))
        }
        // Ignore retry: and comments (lines starting with :)

        return nil
    }

    /// Strips a single leading U+0020 SPACE character per the SSE spec.
    private static func stripSingleLeadingSpace(_ value: String) -> String {
        if value.hasPrefix(" ") {
            return String(value.dropFirst())
        }
        return value
    }

    /// Resets the parser state.
    func reset() {
        currentEvent = nil
        currentData = []
        currentId = nil
    }
}

/// Alias for SSE event.
typealias SSEEvent = SSEParser.SSEEvent
