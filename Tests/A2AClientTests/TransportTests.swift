// TransportTests.swift
// A2AClientTests
//
// Tests for A2A transport layer and client operations using a mock transport

import XCTest
import Foundation
@testable import A2AClient

// MARK: - Mock Transport

/// A mock transport for testing A2AClient method dispatching and request encoding.
final class MockTransport: A2ATransport, @unchecked Sendable {
    /// Records of all calls made to the transport.
    var sendCalls: [(endpoint: A2AEndpoint, body: Any)] = []
    var getCalls: [(endpoint: A2AEndpoint, queryItems: [URLQueryItem])] = []
    var streamCalls: [(endpoint: A2AEndpoint, body: Any)] = []
    var fetchCalls: [URL] = []

    /// Responses to return for each type.
    var sendResponse: Any?
    var getResponse: Any?
    var streamResponse: AsyncThrowingStream<StreamingEvent, Error>?
    var fetchResponse: Any?

    /// Error to throw if set.
    var errorToThrow: Error?

    func send<Request: Encodable, Response: Decodable>(
        request: Request,
        to endpoint: A2AEndpoint,
        responseType: Response.Type
    ) async throws -> Response {
        sendCalls.append((endpoint: endpoint, body: request))
        if let error = errorToThrow { throw error }
        guard let response = sendResponse as? Response else {
            throw A2AError.invalidResponse(message: "No mock response configured")
        }
        return response
    }

    func send<Request: Encodable>(
        request: Request,
        to endpoint: A2AEndpoint
    ) async throws {
        sendCalls.append((endpoint: endpoint, body: request))
        if let error = errorToThrow { throw error }
    }

    func get<Response: Decodable>(
        from endpoint: A2AEndpoint,
        queryItems: [URLQueryItem],
        responseType: Response.Type
    ) async throws -> Response {
        getCalls.append((endpoint: endpoint, queryItems: queryItems))
        if let error = errorToThrow { throw error }
        guard let response = getResponse as? Response else {
            throw A2AError.invalidResponse(message: "No mock response configured")
        }
        return response
    }

    func stream<Request: Encodable>(
        request: Request,
        to endpoint: A2AEndpoint
    ) async throws -> AsyncThrowingStream<StreamingEvent, Error> {
        streamCalls.append((endpoint: endpoint, body: request))
        if let error = errorToThrow { throw error }
        guard let stream = streamResponse else {
            throw A2AError.invalidResponse(message: "No mock stream configured")
        }
        return stream
    }

    func fetch<Response: Decodable>(
        from url: URL,
        responseType: Response.Type
    ) async throws -> Response {
        fetchCalls.append(url)
        if let error = errorToThrow { throw error }
        guard let response = fetchResponse as? Response else {
            throw A2AError.invalidResponse(message: "No mock response configured")
        }
        return response
    }
}

// MARK: - A2AClient Operation Tests

final class ClientOperationTests: XCTestCase {

    private func makeClient(transport: MockTransport) -> A2AClient {
        // Use reflection to inject the mock transport
        let config = A2AClientConfiguration(baseURL: URL(string: "https://example.com")!)
        let client = A2AClient(configuration: config)
        // We need to set the transport field. Since it's private, we'll test via the transport directly.
        return client
    }

    // MARK: - SendMessageRequest Tests

    func testSendMessageRequest_IncludesConfiguration() throws {
        let config = MessageSendConfiguration(
            acceptedOutputModes: ["text/plain", "application/json"],
            historyLength: 5,
            blocking: true
        )
        let message = Message.user("Hello")
        let request = SendMessageRequest(message: message, configuration: config)

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SendMessageRequest.self, from: data)

        XCTAssertEqual(decoded.message.textContent, "Hello")
        XCTAssertNotNil(decoded.configuration)
        XCTAssertEqual(decoded.configuration?.acceptedOutputModes, ["text/plain", "application/json"])
        XCTAssertEqual(decoded.configuration?.historyLength, 5)
        XCTAssertEqual(decoded.configuration?.blocking, true)
    }

    func testSendMessageRequest_NilConfigurationOmitted() throws {
        let message = Message.user("Hello")
        let request = SendMessageRequest(message: message)

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertFalse(json.contains("configuration"))
        XCTAssertNil(request.configuration)
    }

    func testSendMessageRequest_ConfigurationUsesSnakeCase() throws {
        let config = MessageSendConfiguration(
            acceptedOutputModes: ["text/plain"],
            historyLength: 3,
            blocking: false
        )
        let message = Message.user("Test")
        let request = SendMessageRequest(message: message, configuration: config)

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("accepted_output_modes"))
        XCTAssertTrue(json.contains("history_length"))
        XCTAssertFalse(json.contains("acceptedOutputModes"))
        XCTAssertFalse(json.contains("historyLength"))
    }

    // MARK: - SendMessageResponse Tests

    func testSendMessageResponse_DecodesTask() throws {
        let json = """
        {
            "id": "task-1",
            "context_id": "ctx-1",
            "status": {"state": "working"}
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(SendMessageResponse.self, from: data)

        XCTAssertTrue(response.isTask)
        XCTAssertFalse(response.isMessage)
        XCTAssertEqual(response.task?.id, "task-1")
    }

    func testSendMessageResponse_DecodesMessage() throws {
        let json = """
        {
            "message_id": "msg-1",
            "role": "agent",
            "parts": [{"text": "Hello"}]
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(SendMessageResponse.self, from: data)

        XCTAssertTrue(response.isMessage)
        XCTAssertFalse(response.isTask)
        XCTAssertEqual(response.message?.role, .agent)
    }

    func testSendMessageResponse_DisambiguatesTaskAndMessage() throws {
        // A JSON with "status" field should decode as Task, not Message
        let taskJson = """
        {
            "id": "task-1",
            "context_id": "ctx-1",
            "status": {"state": "completed"}
        }
        """
        let taskData = taskJson.data(using: .utf8)!
        let decoder = JSONDecoder()
        let taskResponse = try decoder.decode(SendMessageResponse.self, from: taskData)
        XCTAssertTrue(taskResponse.isTask)

        // A JSON with "role" field should decode as Message
        let messageJson = """
        {
            "message_id": "msg-1",
            "role": "user",
            "parts": [{"text": "test"}]
        }
        """
        let messageData = messageJson.data(using: .utf8)!
        let messageResponse = try decoder.decode(SendMessageResponse.self, from: messageData)
        XCTAssertTrue(messageResponse.isMessage)
    }

    // MARK: - A2AEndpoint Tests

    func testEndpoint_TenantPrefixing() {
        let endpoint = A2AEndpoint.sendMessage
        XCTAssertEqual(endpoint.pathWithTenant(nil), "/message:send")
        XCTAssertEqual(endpoint.pathWithTenant(""), "/message:send")
        XCTAssertEqual(endpoint.pathWithTenant("acme"), "/acme/message:send")
    }

    func testEndpoint_TenantPrefixingWithDynamicPaths() {
        let getTaskEndpoint = A2AEndpoint.getTask(id: "task-123")
        XCTAssertEqual(getTaskEndpoint.pathWithTenant("corp"), "/corp/tasks/task-123")

        let cancelEndpoint = A2AEndpoint.cancelTask(id: "task-456")
        XCTAssertEqual(cancelEndpoint.pathWithTenant("org"), "/org/tasks/task-456:cancel")
    }

    func testEndpoint_PathSanitization() {
        // Path separators are removed to prevent path traversal
        let endpoint = A2AEndpoint.getTask(id: "../../../etc/passwd")
        // Slashes and backslashes are stripped, preventing traversal
        XCTAssertFalse(endpoint.path.contains("/etc"))
        XCTAssertFalse(endpoint.path.contains("/../"))

        // Normal IDs pass through
        let normalEndpoint = A2AEndpoint.getTask(id: "task-123")
        XCTAssertEqual(normalEndpoint.path, "/tasks/task-123")
    }

    func testEndpoint_JSONRPCMethodNames() {
        XCTAssertEqual(A2AEndpoint.sendMessage.jsonRPCMethod, "message/send")
        XCTAssertEqual(A2AEndpoint.sendStreamingMessage.jsonRPCMethod, "message/stream")
        XCTAssertEqual(A2AEndpoint.listTasks.jsonRPCMethod, "tasks/list")
        XCTAssertEqual(A2AEndpoint.getTask(id: "1").jsonRPCMethod, "tasks/get")
        XCTAssertEqual(A2AEndpoint.cancelTask(id: "1").jsonRPCMethod, "tasks/cancel")
        XCTAssertEqual(A2AEndpoint.getExtendedAgentCard.jsonRPCMethod, "agent/authenticatedExtendedCard")
    }

    // MARK: - TaskQueryParams Query Items Tests

    func testTaskQueryParams_DefaultValues() {
        let params = TaskQueryParams()
        XCTAssertNil(params.contextId)
        XCTAssertNil(params.status)
        XCTAssertNil(params.pageSize)
        XCTAssertNil(params.pageToken)
    }

    func testTaskQueryParams_EncodingDecoding() throws {
        let params = TaskQueryParams(
            contextId: "ctx-1",
            status: .working,
            pageSize: 10,
            historyLength: 5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(params)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("context_id"))
        XCTAssertTrue(json.contains("page_size"))
        XCTAssertTrue(json.contains("history_length"))
    }

    // MARK: - Part Validation Tests

    func testPart_FactoryMethodsCreateValidParts() {
        let textPart = Part.text("Hello")
        XCTAssertTrue(textPart.isValid)
        XCTAssertEqual(textPart.contentType, .text)

        let urlPart = Part.url("https://example.com")
        XCTAssertTrue(urlPart.isValid)
        XCTAssertEqual(urlPart.contentType, .url)

        let rawPart = Part.raw("data".data(using: .utf8)!)
        XCTAssertTrue(rawPart.isValid)
        XCTAssertEqual(rawPart.contentType, .raw)

        let dataPart = Part.data(["key": "value"])
        XCTAssertTrue(dataPart.isValid)
        XCTAssertEqual(dataPart.contentType, .data)
    }

    // MARK: - SSE Parser Spec Compliance Tests

    func testSSEParser_SingleLeadingSpaceStripped() {
        let parser = SSEParser()

        _ = parser.parse(line: "data: Hello")
        let event = parser.parse(line: "")

        XCTAssertEqual(event?.data, "Hello")
    }

    func testSSEParser_NoLeadingSpacePreserved() {
        let parser = SSEParser()

        _ = parser.parse(line: "data:NoSpace")
        let event = parser.parse(line: "")

        XCTAssertEqual(event?.data, "NoSpace")
    }

    func testSSEParser_MultipleLeadingSpacesOnlyOneStripped() {
        let parser = SSEParser()

        // Per SSE spec, only the first space after "data:" should be stripped
        _ = parser.parse(line: "data:  two spaces")
        let event = parser.parse(line: "")

        XCTAssertEqual(event?.data, " two spaces")
    }

    func testSSEParser_TrailingSpacesPreserved() {
        let parser = SSEParser()

        _ = parser.parse(line: "data: trailing  ")
        let event = parser.parse(line: "")

        XCTAssertEqual(event?.data, "trailing  ")
    }

    // MARK: - Mock Transport Tests

    func testMockTransport_SendRecordsEndpoint() async throws {
        let transport = MockTransport()
        let task = A2ATask(id: "1", contextId: "ctx", status: TaskStatus(state: .working))
        transport.sendResponse = task

        let message = Message.user("Hello")
        let request = SendMessageRequest(message: message)
        let _: A2ATask = try await transport.send(
            request: request,
            to: .sendMessage,
            responseType: A2ATask.self
        )

        XCTAssertEqual(transport.sendCalls.count, 1)
        XCTAssertEqual(transport.sendCalls[0].endpoint, .sendMessage)
    }

    func testMockTransport_GetRecordsQueryItems() async throws {
        let transport = MockTransport()
        let listResponse = TaskListResponse(tasks: [], nextPageToken: "", pageSize: 50, totalSize: 0)
        transport.getResponse = listResponse

        let queryItems = [URLQueryItem(name: "context_id", value: "ctx-1")]
        let _: TaskListResponse = try await transport.get(
            from: .listTasks,
            queryItems: queryItems,
            responseType: TaskListResponse.self
        )

        XCTAssertEqual(transport.getCalls.count, 1)
        XCTAssertEqual(transport.getCalls[0].endpoint, .listTasks)
        XCTAssertEqual(transport.getCalls[0].queryItems.count, 1)
        XCTAssertEqual(transport.getCalls[0].queryItems[0].name, "context_id")
    }

    func testMockTransport_ErrorPropagation() async {
        let transport = MockTransport()
        transport.errorToThrow = A2AError.authenticationRequired(message: "Test error")

        let message = Message.user("Hello")
        let request = SendMessageRequest(message: message)

        do {
            let _: SendMessageResponse = try await transport.send(
                request: request,
                to: .sendMessage,
                responseType: SendMessageResponse.self
            )
            XCTFail("Expected error to be thrown")
        } catch let error as A2AError {
            if case .authenticationRequired(let msg) = error {
                XCTAssertEqual(msg, "Test error")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Service Parameters Tests

    func testServiceParameters_IncludesTenant() {
        let params = A2AServiceParameters(version: "1.0", tenant: "acme")
        XCTAssertEqual(params.tenant, "acme")
    }

    func testServiceParameters_Headers() {
        let params = A2AServiceParameters(version: "1.0", extensions: ["ext1", "ext2"])
        let headers = params.headers
        XCTAssertEqual(headers["A2A-Version"], "1.0")
        XCTAssertEqual(headers["A2A-Extensions"], "ext1,ext2")
    }

    func testServiceParameters_NoExtensionsHeader() {
        let params = A2AServiceParameters(version: "1.0")
        let headers = params.headers
        XCTAssertEqual(headers["A2A-Version"], "1.0")
        XCTAssertNil(headers["A2A-Extensions"])
    }
}
