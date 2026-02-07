// ModelTests.swift
// A2AClientTests
//
// Tests for A2A protocol model types

import XCTest
import Foundation
@testable import A2AClient

final class ModelTests: XCTestCase {

    // MARK: - TaskState Tests

    func testTaskState_TerminalStatesAreCorrectlyIdentified() {
        XCTAssertTrue(TaskState.completed.isTerminal)
        XCTAssertTrue(TaskState.failed.isTerminal)
        XCTAssertTrue(TaskState.cancelled.isTerminal)
        XCTAssertTrue(TaskState.rejected.isTerminal)

        XCTAssertFalse(TaskState.unspecified.isTerminal)
        XCTAssertFalse(TaskState.submitted.isTerminal)
        XCTAssertFalse(TaskState.working.isTerminal)
        XCTAssertFalse(TaskState.inputRequired.isTerminal)
        XCTAssertFalse(TaskState.authRequired.isTerminal)
    }

    func testTaskState_InputCapableStatesAreCorrectlyIdentified() {
        XCTAssertTrue(TaskState.inputRequired.canReceiveInput)
        XCTAssertTrue(TaskState.authRequired.canReceiveInput)

        XCTAssertFalse(TaskState.unspecified.canReceiveInput)
        XCTAssertFalse(TaskState.submitted.canReceiveInput)
        XCTAssertFalse(TaskState.working.canReceiveInput)
        XCTAssertFalse(TaskState.completed.canReceiveInput)
    }

    func testTaskState_AllStatesHaveCorrectRawValues() {
        XCTAssertEqual(TaskState.unspecified.rawValue, "unspecified")
        XCTAssertEqual(TaskState.submitted.rawValue, "submitted")
        XCTAssertEqual(TaskState.working.rawValue, "working")
        XCTAssertEqual(TaskState.completed.rawValue, "completed")
        XCTAssertEqual(TaskState.failed.rawValue, "failed")
        XCTAssertEqual(TaskState.cancelled.rawValue, "cancelled")
        XCTAssertEqual(TaskState.inputRequired.rawValue, "input_required")
        XCTAssertEqual(TaskState.rejected.rawValue, "rejected")
        XCTAssertEqual(TaskState.authRequired.rawValue, "auth_required")
    }

    // MARK: - Part Tests

    func testPart_TextPartEncodingAndDecoding() throws {
        let part = Part.text("Hello, world!")

        let encoder = JSONEncoder()
        let data = try encoder.encode(part)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Part.self, from: data)

        XCTAssertTrue(decoded.isText)
        XCTAssertEqual(decoded.text, "Hello, world!")
    }

    func testPart_WithRawData() throws {
        let fileData = "Test file content".data(using: .utf8)!
        let part = Part.file(data: fileData, name: "test.txt", mediaType: "text/plain")

        let encoder = JSONEncoder()
        let data = try encoder.encode(part)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Part.self, from: data)

        XCTAssertTrue(decoded.isRaw)
        XCTAssertEqual(decoded.filename, "test.txt")
        XCTAssertEqual(decoded.mediaType, "text/plain")
        XCTAssertNotNil(decoded.raw)
    }

    func testPart_WithURLReference() throws {
        let part = Part.file(uri: "https://example.com/file.pdf", name: "document.pdf", mediaType: "application/pdf")

        let encoder = JSONEncoder()
        let data = try encoder.encode(part)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Part.self, from: data)

        XCTAssertTrue(decoded.isURL)
        XCTAssertEqual(decoded.url, "https://example.com/file.pdf")
        XCTAssertEqual(decoded.filename, "document.pdf")
        XCTAssertEqual(decoded.mediaType, "application/pdf")
    }

    func testPart_JSONUsesSnakeCase() throws {
        let part = Part.file(uri: "https://example.com/file.pdf", name: "doc.pdf", mediaType: "application/pdf")

        let encoder = JSONEncoder()
        let data = try encoder.encode(part)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("media_type"))
        XCTAssertFalse(json.contains("mediaType"))
    }

    func testPart_DataPartEncodingAndDecoding() throws {
        let part = Part.data(["key": "value", "number": 42])

        let encoder = JSONEncoder()
        let data = try encoder.encode(part)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Part.self, from: data)

        XCTAssertTrue(decoded.isData)
        XCTAssertNotNil(decoded.data)
    }

    func testPart_ContentTypeDetection() {
        let textPart = Part.text("Hello")
        XCTAssertEqual(textPart.contentType, .text)
        XCTAssertTrue(textPart.isValid)

        let urlPart = Part.url("https://example.com")
        XCTAssertEqual(urlPart.contentType, .url)
        XCTAssertTrue(urlPart.isValid)

        let rawPart = Part.raw("data".data(using: .utf8)!)
        XCTAssertEqual(rawPart.contentType, .raw)
        XCTAssertTrue(rawPart.isValid)
    }

    func testPart_InvalidBase64ThrowsDecodingError() throws {
        // JSON with invalid base64 in raw field
        let json = """
        {"raw": "this is not valid base64!!!@#$%"}
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(Part.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testPart_NoContentFieldsThrowsDecodingError() throws {
        // JSON with no content fields
        let json = """
        {"filename": "test.txt", "media_type": "text/plain"}
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(Part.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testPart_MultipleContentFieldsThrowsDecodingError() throws {
        // JSON with both text and url fields set
        let json = """
        {"text": "hello", "url": "https://example.com"}
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(Part.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - Message Tests

    func testMessage_UserMessageCreation() {
        let message = Message.user("Hello, agent!")

        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.textContent, "Hello, agent!")
        XCTAssertEqual(message.parts.count, 1)
    }

    func testMessage_AgentMessageCreation() {
        let message = Message.agent("Hello, user!")

        XCTAssertEqual(message.role, .agent)
        XCTAssertEqual(message.textContent, "Hello, user!")
    }

    func testMessage_WithContextAndTaskIds() {
        let message = Message.user("Continue", contextId: "ctx-123", taskId: "task-456")

        XCTAssertEqual(message.contextId, "ctx-123")
        XCTAssertEqual(message.taskId, "task-456")
    }

    func testMessage_EncodingAndDecoding() throws {
        let message = Message(
            messageId: "msg-123",
            role: .user,
            parts: [.text("Test message")],
            contextId: "ctx-456"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.messageId, "msg-123")
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.contextId, "ctx-456")
        XCTAssertEqual(decoded.textContent, "Test message")
    }

    func testMessage_JSONUsesSnakeCase() throws {
        let message = Message(
            messageId: "msg-123",
            role: .user,
            parts: [.text("Test")],
            contextId: "ctx-456",
            taskId: "task-789",
            referenceTaskIds: ["ref-1"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("message_id"))
        XCTAssertTrue(json.contains("context_id"))
        XCTAssertTrue(json.contains("task_id"))
        XCTAssertTrue(json.contains("reference_task_ids"))
        XCTAssertFalse(json.contains("messageId"))
        XCTAssertFalse(json.contains("contextId"))
        XCTAssertFalse(json.contains("taskId"))
    }

    func testMessage_RoleIncludesUnspecified() {
        XCTAssertEqual(MessageRole.unspecified.rawValue, "unspecified")
    }

    // MARK: - Task Tests

    func testTask_StateConvenienceProperties() {
        let task = A2ATask(
            id: "task-123",
            contextId: "ctx-456",
            status: TaskStatus(state: .working)
        )

        XCTAssertEqual(task.state, .working)
        XCTAssertFalse(task.isComplete)
        XCTAssertFalse(task.needsInput)
    }

    func testTask_CompletedTaskIsMarkedComplete() {
        let task = A2ATask(
            id: "task-123",
            contextId: "ctx-456",
            status: TaskStatus(state: .completed)
        )

        XCTAssertTrue(task.isComplete)
    }

    func testTask_InputRequiredTaskNeedsInput() {
        let task = A2ATask(
            id: "task-123",
            contextId: "ctx-456",
            status: TaskStatus(state: .inputRequired)
        )

        XCTAssertTrue(task.needsInput)
    }

    func testTask_EncodingAndDecoding() throws {
        let task = A2ATask(
            id: "task-123",
            contextId: "ctx-456",
            status: TaskStatus(state: .working),
            artifacts: [
                Artifact(name: "output", parts: [.text("Result")])
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(A2ATask.self, from: data)

        XCTAssertEqual(decoded.id, "task-123")
        XCTAssertEqual(decoded.contextId, "ctx-456")
        XCTAssertEqual(decoded.state, .working)
        XCTAssertEqual(decoded.artifacts?.count, 1)
    }

    func testTask_JSONUsesSnakeCase() throws {
        let task = A2ATask(
            id: "task-123",
            contextId: "ctx-456",
            status: TaskStatus(state: .working)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("context_id"))
        XCTAssertFalse(json.contains("contextId"))
    }

    // MARK: - AgentCard Tests

    func testAgentCard_WellKnownURLConstruction() {
        let url = AgentCard.wellKnownURL(domain: "example.com")
        XCTAssertEqual(url?.absoluteString, "https://example.com/.well-known/agent.json")
    }

    func testAgentCard_EncodingAndDecoding() throws {
        let card = AgentCard(
            name: "Test Agent",
            description: "A test agent",
            supportedInterfaces: [
                AgentInterface(url: "https://example.com/agent", protocolBinding: "HTTP+JSON", protocolVersion: "1.0")
            ],
            version: "1.0.0",
            capabilities: AgentCapabilities(
                streaming: true,
                pushNotifications: false
            ),
            skills: [
                AgentSkill(
                    id: "chat",
                    name: "Chat",
                    description: "General conversation",
                    tags: ["chat", "general"]
                )
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(card)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AgentCard.self, from: data)

        XCTAssertEqual(decoded.name, "Test Agent")
        XCTAssertEqual(decoded.url, "https://example.com/agent")
        XCTAssertEqual(decoded.capabilities.streaming, true)
        XCTAssertEqual(decoded.skills.count, 1)
    }

    func testAgentCard_JSONUsesSnakeCase() throws {
        let card = AgentCard(
            name: "Test",
            description: "Test agent",
            supportedInterfaces: [
                AgentInterface(url: "https://example.com", protocolBinding: "HTTP+JSON", protocolVersion: "1.0")
            ],
            version: "1.0",
            capabilities: AgentCapabilities(pushNotifications: true),
            defaultInputModes: ["text/plain"],
            defaultOutputModes: ["text/plain"],
            skills: [AgentSkill(id: "s1", name: "Skill", description: "A skill", tags: [])]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(card)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("supported_interfaces"))
        XCTAssertTrue(json.contains("protocol_binding"))
        XCTAssertTrue(json.contains("protocol_version"))
        XCTAssertTrue(json.contains("default_input_modes"))
        XCTAssertTrue(json.contains("default_output_modes"))
        XCTAssertTrue(json.contains("push_notifications"))
        XCTAssertFalse(json.contains("protocolVersion"))
        XCTAssertFalse(json.contains("defaultInputModes"))
    }

    func testAgentCard_HasRequiredFields() {
        let card = AgentCard(
            name: "Test",
            description: "Required description",
            supportedInterfaces: [
                AgentInterface(url: "https://example.com", protocolBinding: "HTTP+JSON", protocolVersion: "1.0")
            ],
            version: "1.0",
            capabilities: AgentCapabilities(),
            defaultInputModes: ["text/plain"],
            defaultOutputModes: ["text/plain"],
            skills: []
        )

        XCTAssertEqual(card.description, "Required description")
        XCTAssertTrue(card.supportedInterfaces.count >= 1)
        XCTAssertTrue(card.defaultInputModes.count >= 1)
        XCTAssertTrue(card.defaultOutputModes.count >= 1)
    }

    func testAgentCard_EmptyInterfacesThrowsDecodingError() throws {
        // JSON with empty supported_interfaces array
        let json = """
        {
            "name": "Test",
            "description": "Test agent",
            "supported_interfaces": [],
            "version": "1.0",
            "default_input_modes": ["text/plain"],
            "default_output_modes": ["text/plain"],
            "skills": []
        }
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(AgentCard.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - Artifact Tests

    func testArtifact_TextArtifactCreation() {
        let artifact = Artifact.text("Generated content", name: "output.txt")

        XCTAssertEqual(artifact.name, "output.txt")
        XCTAssertEqual(artifact.textContent, "Generated content")
    }

    func testArtifact_DataArtifactCreation() {
        let artifact = Artifact.data(["result": "success"], name: "response")

        XCTAssertEqual(artifact.name, "response")
        XCTAssertEqual(artifact.parts.count, 1)
    }

    func testArtifact_JSONUsesSnakeCase() throws {
        let artifact = Artifact(
            artifactId: "art-123",
            name: "test",
            parts: [.text("content")]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(artifact)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("artifact_id"))
        XCTAssertFalse(json.contains("artifactId"))
    }

    func testArtifact_ExtensionsIsStringArray() throws {
        let artifact = Artifact(
            parts: [.text("test")],
            extensions: ["urn:a2a:ext:example", "urn:a2a:ext:other"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(artifact)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Artifact.self, from: data)

        XCTAssertEqual(decoded.extensions?.count, 2)
        XCTAssertEqual(decoded.extensions?.first, "urn:a2a:ext:example")
    }

    // MARK: - AnyCodable Tests

    func testAnyCodable_StringValue() {
        let value: AnyCodable = "test"
        XCTAssertEqual(value.stringValue, "test")
    }

    func testAnyCodable_IntegerValue() {
        let value: AnyCodable = 42
        XCTAssertEqual(value.intValue, 42)
    }

    func testAnyCodable_BooleanValue() {
        let value: AnyCodable = true
        XCTAssertEqual(value.boolValue, true)
    }

    func testAnyCodable_NullValue() {
        let value: AnyCodable = nil
        XCTAssertTrue(value.isNull)
    }

    func testAnyCodable_DictionaryEncodingAndDecoding() throws {
        let original: [String: AnyCodable] = [
            "string": "value",
            "number": 123,
            "bool": true
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: AnyCodable].self, from: data)

        XCTAssertEqual(decoded["string"]?.stringValue, "value")
        XCTAssertEqual(decoded["number"]?.intValue, 123)
        XCTAssertEqual(decoded["bool"]?.boolValue, true)
    }
}
