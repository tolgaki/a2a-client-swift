// HTTPTransport.swift
// A2AClient
//
// Agent2Agent Protocol - HTTP/REST Transport Implementation

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

    /// Session-level headers, captured once — `session.configuration`
    /// copies the configuration object on every access, and a session's
    /// configuration cannot change after creation.
    private let sessionHeaders: [String: String]

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
        self.sessionHeaders = session.configuration.httpAdditionalHeaders as? [String: String] ?? [:]
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if serviceParameters.jsonKeyCasing == .snakeCase {
            encoder.keyEncodingStrategy = .convertToSnakeCase
        }
        encoder.userInfo[a2aProtocolVersionKey] = serviceParameters.version
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
        let urlRequest = try await buildRequest(for: endpoint, body: request)
        let (data, response) = try await session.data(for: urlRequest)

        try validateResponse(response, data: data)
        return try decodeResponse(Response.self, from: data)
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

        // Delegate-backed connection: chunks arrive incrementally on both
        // Darwin and Linux (URLSession.bytes does not stream reliably on
        // corelibs-foundation). The response head is awaited up front so
        // pre-stream failures throw from this call, not from iteration.
        let connection = SSEConnection()
        let (httpResponse, chunks) = try await connection.connect(request: urlRequest)

        // Non-2xx: collect the body so the typed error it carries (AIP-193
        // or flat) is thrown instead of a generic status-code error.
        if !(200...299).contains(httpResponse.statusCode) {
            defer { connection.cancel() }
            let body = try? await Self.collect(chunks, upTo: 1 << 20)
            try validateResponse(httpResponse, data: body)
            // validateResponse always throws for non-2xx; keep the compiler
            // and any future refactor honest.
            throw A2AError.internalError(message: "HTTP \(httpResponse.statusCode)")
        }

        // A server that fails before opening the stream may answer 2xx with
        // a plain JSON error body instead of text/event-stream (§9.4.2).
        // Without this check that body parses as zero SSE events and the
        // error is silently swallowed.
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           !contentType.lowercased().contains("text/event-stream") {
            defer { connection.cancel() }
            let data = try await Self.collect(chunks, upTo: 1 << 20)
            if let error = tryDecodeRESTError(from: data) {
                throw error
            }
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "<non-utf8 bytes>"
            throw A2AError.invalidResponse(
                message: "Expected an SSE stream but received \(contentType). Body: \(snippet)"
            )
        }

        return AsyncThrowingStream { continuation in
            let streamTask = _Concurrency.Task {
                do {
                    let parser = SSEParser()
                    var splitter = SSELineSplitter()

                    for try await chunk in chunks {
                        for line in splitter.push(chunk) {
                            if let event = parser.parse(line: line) {
                                let streamingEvent = try decodeStreamingEvent(from: event)
                                continuation.yield(streamingEvent)
                            }
                        }
                    }

                    // Flush a final unterminated line, then any buffered event
                    // (last data: line with no trailing blank line).
                    if let tail = splitter.flush(), let event = parser.parse(line: tail) {
                        let streamingEvent = try decodeStreamingEvent(from: event)
                        continuation.yield(streamingEvent)
                    }
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
                connection.cancel()
            }
        }
    }

    public func get<Response: Decodable>(
        from endpoint: A2AEndpoint,
        queryItems: [URLQueryItem],
        responseType: Response.Type
    ) async throws -> Response {
        let path = endpoint.pathWithTenant(serviceParameters.tenant)
        let url = try urlForPath(path)

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
        return try decodeResponse(Response.self, from: data)
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
        return try decodeResponse(Response.self, from: data)
    }

    // MARK: - Private Helpers

    /// Drains a chunk stream into a `Data`, stopping at `limit` bytes.
    /// Used for non-SSE bodies on streaming endpoints, which are small
    /// error envelopes.
    private static func collect(_ chunks: AsyncThrowingStream<Data, Error>, upTo limit: Int) async throws -> Data {
        var data = Data()
        for try await chunk in chunks {
            data.append(chunk)
            if data.count >= limit { break }
        }
        return data
    }

    /// Joins ``baseURL`` with an endpoint ``path`` using plain string
    /// concatenation. Foundation's ``URL/appendingPathComponent(_:)`` can
    /// percent-encode colons (`:`) on some OS versions, turning spec paths
    /// like `/v1/message:send` into `/v1/message%3Asend` and causing 404s.
    /// Direct concatenation avoids every such quirk.
    private func urlForPath(_ path: String) throws -> URL {
        var base = baseURL.absoluteString
        if base.hasSuffix("/") { base = String(base.dropLast()) }
        guard let url = URL(string: base + path) else {
            throw A2AError.invalidRequest(message: "Invalid URL: \(base + path)")
        }
        return url
    }

    /// Decodes a successful (2xx) response body, surfacing decode failures as
    /// an ``A2AError/invalidResponse`` with the underlying error and a short
    /// body snippet. ``A2AError/encodingError`` is reserved for errors on the
    /// request side.
    private func decodeResponse<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        do {
            return try makeDecoder().decode(Response.self, from: data)
        } catch {
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "<non-utf8 bytes>"
            throw A2AError.invalidResponse(
                message: "Failed to decode response body as \(Response.self): \(error). Body: \(snippet)"
            )
        }
    }

    private func buildRequest<Body: Encodable>(
        for endpoint: A2AEndpoint,
        body: Body? = nil as Empty?,
        acceptSSE: Bool = false
    ) async throws -> URLRequest {
        let path = endpoint.pathWithTenant(serviceParameters.tenant)
        let url = try urlForPath(path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Set accept headers
        if acceptSSE {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }

        // Apply session-level headers per-request — streaming uses
        // URLSession.shared, which doesn't carry them.
        for (key, value) in sessionHeaders {
            request.setValue(value, forHTTPHeaderField: key)
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
            if let error = tryDecodeRESTError(from: data) { throw error }
            throw A2AError.invalidResponse(message: "Resource not found (HTTP 404)")
        case 415:
            throw A2AError.contentTypeNotSupported(
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown",
                message: "Unsupported media type"
            )
        case 400:
            if let error = tryDecodeRESTError(from: data) { throw error }
            throw A2AError.invalidRequest(message: "Bad request (HTTP 400)")
        case 500...599:
            if let error = tryDecodeRESTError(from: data) { throw error }
            throw A2AError.internalError(message: "Server error (HTTP \(httpResponse.statusCode))")
        default:
            if let error = tryDecodeRESTError(from: data) { throw error }
            throw A2AError.internalError(message: "HTTP \(httpResponse.statusCode)")
        }
    }

    /// Attempts to decode a REST error body in either AIP-193 format
    /// (`{"error":{"code":…,"message":…}}`) or flat JSON-RPC format
    /// (`{"code":…,"message":…}`).
    private func tryDecodeRESTError(from data: Data?) -> A2AError? {
        guard let data = data else { return nil }
        let decoder = makeDecoder()

        // AIP-193 wrapper: {"error": {"code": …, "message": …, "details": […]}}
        struct AIP193Wrapper: Decodable {
            let error: AIP193Error
        }
        struct AIP193Error: Decodable {
            let code: Int?
            let status: String?
            let message: String?
        }
        if let wrapper = try? decoder.decode(AIP193Wrapper.self, from: data) {
            let e = wrapper.error
            let code = e.code ?? 0
            let message = e.message ?? e.status ?? "Unknown error"
            return A2AErrorResponse(code: code, message: message, data: nil).toA2AError()
        }

        // Flat format: {"code": …, "message": …}
        if let errorResponse = try? decoder.decode(A2AErrorResponse.self, from: data) {
            return errorResponse.toA2AError()
        }

        return nil
    }

    private func decodeStreamingEvent(from sseEvent: SSEEvent) throws -> StreamingEvent {
        guard let data = sseEvent.data.data(using: .utf8) else {
            throw A2AError.invalidResponse(message: "Invalid SSE data encoding")
        }

        // Try to decode as different event types based on event type
        switch sseEvent.event {
        case "status":
            return .taskStatusUpdate(try makeDecoder().decode(TaskStatusUpdateEvent.self, from: data))
        case "artifact":
            return .taskArtifactUpdate(try makeDecoder().decode(TaskArtifactUpdateEvent.self, from: data))
        case "task":
            return .task(try makeDecoder().decode(A2ATask.self, from: data))
        case "message":
            return .message(try makeDecoder().decode(Message.self, from: data))
        default:
            // No event type header — try field-presence/kind-based decoding
            // (v1.0 uses field-presence: {"statusUpdate":{...}}, v0.3 uses kind).
            // Servers vary on key casing, so retry with snake_case conversion
            // when the default strategy fails. Keep the first error for
            // diagnosis.
            var firstError: Error?

            for snakeCase in [false, true] {
                let decoder = makeDecoder()
                if snakeCase {
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                }

                do {
                    return try decoder.decode(StreamEventResult.self, from: data).event
                } catch {
                    if firstError == nil { firstError = error }
                }

                if let update = try? decoder.decode(TaskStatusUpdateEvent.self, from: data) {
                    return .taskStatusUpdate(update)
                } else if let update = try? decoder.decode(TaskArtifactUpdateEvent.self, from: data) {
                    return .taskArtifactUpdate(update)
                } else if let task = try? decoder.decode(A2ATask.self, from: data) {
                    return .task(task)
                } else if let message = try? decoder.decode(Message.self, from: data) {
                    return .message(message)
                }
            }

            // Servers may terminate a stream with an error frame instead of
            // an event — surface it as the proper A2AError rather than a
            // generic decode failure.
            if let restError = tryDecodeRESTError(from: data) {
                throw restError
            }

            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "<non-utf8 bytes>"
            let detail = firstError.map { " Underlying error: \($0)." } ?? ""
            throw A2AError.invalidResponse(
                message: "Unable to decode streaming event (sse event: \(sseEvent.event ?? "none")).\(detail) Body: \(snippet)"
            )
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
    ///
    /// Handles both standard SSE (blank-line delimited) and servers like the
    /// Graph RP that send consecutive `data:` lines without blank separators.
    func parse(line: String) -> SSEEvent? {
        // Empty line signals end of event (standard SSE)
        if line.isEmpty {
            guard !currentData.isEmpty else { return nil }
            return emitEvent()
        }

        // Parse field — per the SSE spec, only strip a single leading space after the colon
        if line.hasPrefix("data:") {
            let value = Self.stripSingleLeadingSpace(String(line.dropFirst(5)))
            // If we already have buffered data, emit it first — the server
            // sent consecutive data: lines without blank-line separators.
            if !currentData.isEmpty {
                let event = emitEvent()
                currentData.append(value)
                return event
            }
            currentData.append(value)
        } else if line.hasPrefix("event:") {
            currentEvent = Self.stripSingleLeadingSpace(String(line.dropFirst(6)))
        } else if line.hasPrefix("id:") {
            currentId = Self.stripSingleLeadingSpace(String(line.dropFirst(3)))
        }
        // Ignore retry: and comments (lines starting with :)

        return nil
    }

    /// Emits the currently buffered event and resets state.
    private func emitEvent() -> SSEEvent {
        let event = SSEEvent(
            event: currentEvent,
            data: currentData.joined(separator: "\n"),
            id: currentId
        )
        currentEvent = nil
        currentData = []
        currentId = nil
        return event
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
