// ModelTests.swift
// A2AClientTests
//
// Tests for A2A protocol model types

import Testing
import Foundation
@testable import A2AClient

@Suite("Model Tests")
struct ModelTests {

    // MARK: - TaskState Tests

    @Suite("TaskState")
    struct TaskStateTests {
        @Test("Terminal states are correctly identified")
        func terminalStates() {
            #expect(TaskState.completed.isTerminal == true)
            #expect(TaskState.failed.isTerminal == true)
            #expect(TaskState.cancelled.isTerminal == true)
            #expect(TaskState.rejected.isTerminal == true)

            #expect(TaskState.unspecified.isTerminal == false)
            #expect(TaskState.submitted.isTerminal == false)
            #expect(TaskState.working.isTerminal == false)
            #expect(TaskState.inputRequired.isTerminal == false)
            #expect(TaskState.authRequired.isTerminal == false)
        }

        @Test("Input-capable states are correctly identified")
        func inputCapableStates() {
            #expect(TaskState.inputRequired.canReceiveInput == true)
            #expect(TaskState.authRequired.canReceiveInput == true)

            #expect(TaskState.unspecified.canReceiveInput == false)
            #expect(TaskState.submitted.canReceiveInput == false)
            #expect(TaskState.working.canReceiveInput == false)
            #expect(TaskState.completed.canReceiveInput == false)
        }

        @Test("All states have correct raw values")
        func rawValues() {
            #expect(TaskState.unspecified.rawValue == "unspecified")
            #expect(TaskState.submitted.rawValue == "submitted")
            #expect(TaskState.working.rawValue == "working")
            #expect(TaskState.completed.rawValue == "completed")
            #expect(TaskState.failed.rawValue == "failed")
            #expect(TaskState.cancelled.rawValue == "cancelled")
            #expect(TaskState.inputRequired.rawValue == "input_required")
            #expect(TaskState.rejected.rawValue == "rejected")
            #expect(TaskState.authRequired.rawValue == "auth_required")
        }
    }

    // MARK: - Part Tests

    @Suite("Part")
    struct PartTests {
        @Test("Text part encoding and decoding")
        func textPartCoding() throws {
            let part = Part.text("Hello, world!")

            let encoder = JSONEncoder()
            let data = try encoder.encode(part)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Part.self, from: data)

            #expect(decoded.isText == true)
            #expect(decoded.text == "Hello, world!")
        }

        @Test("Part with raw data")
        func partWithRawData() throws {
            let fileData = "Test file content".data(using: .utf8)!
            let part = Part.file(data: fileData, name: "test.txt", mediaType: "text/plain")

            let encoder = JSONEncoder()
            let data = try encoder.encode(part)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Part.self, from: data)

            #expect(decoded.isRaw == true)
            #expect(decoded.filename == "test.txt")
            #expect(decoded.mediaType == "text/plain")
            #expect(decoded.raw != nil)
        }

        @Test("Part with URL reference")
        func partWithURL() throws {
            let part = Part.file(uri: "https://example.com/file.pdf", name: "document.pdf", mediaType: "application/pdf")

            let encoder = JSONEncoder()
            let data = try encoder.encode(part)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Part.self, from: data)

            #expect(decoded.isURL == true)
            #expect(decoded.url == "https://example.com/file.pdf")
            #expect(decoded.filename == "document.pdf")
            #expect(decoded.mediaType == "application/pdf")
        }

        @Test("Part JSON uses snake_case")
        func partSnakeCase() throws {
            let part = Part.file(uri: "https://example.com/file.pdf", name: "doc.pdf", mediaType: "application/pdf")

            let encoder = JSONEncoder()
            let data = try encoder.encode(part)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("media_type"))
            #expect(!json.contains("mediaType"))
        }

        @Test("Data part encoding and decoding")
        func dataPartCoding() throws {
            let part = Part.data(["key": "value", "number": 42])

            let encoder = JSONEncoder()
            let data = try encoder.encode(part)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Part.self, from: data)

            #expect(decoded.isData == true)
            #expect(decoded.data != nil)
        }

        @Test("Part content type detection")
        func contentTypeDetection() {
            let textPart = Part.text("Hello")
            #expect(textPart.contentType == .text)
            #expect(textPart.isValid == true)

            let urlPart = Part.url("https://example.com")
            #expect(urlPart.contentType == .url)
            #expect(urlPart.isValid == true)

            let rawPart = Part.raw("data".data(using: .utf8)!)
            #expect(rawPart.contentType == .raw)
            #expect(rawPart.isValid == true)
        }

        @Test("Invalid base64 throws decoding error")
        func invalidBase64Throws() throws {
            // JSON with invalid base64 in raw field
            let json = """
            {"raw": "this is not valid base64!!!@#$%"}
            """
            let data = json.data(using: .utf8)!

            let decoder = JSONDecoder()
            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(Part.self, from: data)
            }
        }

        @Test("Part with no content fields throws decoding error")
        func noContentFieldsThrows() throws {
            // JSON with no content fields
            let json = """
            {"filename": "test.txt", "media_type": "text/plain"}
            """
            let data = json.data(using: .utf8)!

            let decoder = JSONDecoder()
            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(Part.self, from: data)
            }
        }

        @Test("Part with multiple content fields throws decoding error")
        func multipleContentFieldsThrows() throws {
            // JSON with both text and url fields set
            let json = """
            {"text": "hello", "url": "https://example.com"}
            """
            let data = json.data(using: .utf8)!

            let decoder = JSONDecoder()
            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(Part.self, from: data)
            }
        }
    }

    // MARK: - Message Tests

    @Suite("Message")
    struct MessageTests {
        @Test("User message creation")
        func userMessage() {
            let message = Message.user("Hello, agent!")

            #expect(message.role == .user)
            #expect(message.textContent == "Hello, agent!")
            #expect(message.parts.count == 1)
        }

        @Test("Agent message creation")
        func agentMessage() {
            let message = Message.agent("Hello, user!")

            #expect(message.role == .agent)
            #expect(message.textContent == "Hello, user!")
        }

        @Test("Message with context and task IDs")
        func messageWithIds() {
            let message = Message.user("Continue", contextId: "ctx-123", taskId: "task-456")

            #expect(message.contextId == "ctx-123")
            #expect(message.taskId == "task-456")
        }

        @Test("Message encoding and decoding")
        func messageCoding() throws {
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

            #expect(decoded.messageId == "msg-123")
            #expect(decoded.role == .user)
            #expect(decoded.contextId == "ctx-456")
            #expect(decoded.textContent == "Test message")
        }

        @Test("Message JSON uses snake_case")
        func messageSnakeCase() throws {
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

            #expect(json.contains("message_id"))
            #expect(json.contains("context_id"))
            #expect(json.contains("task_id"))
            #expect(json.contains("reference_task_ids"))
            #expect(!json.contains("messageId"))
            #expect(!json.contains("contextId"))
            #expect(!json.contains("taskId"))
        }

        @Test("Role includes unspecified")
        func roleUnspecified() {
            #expect(MessageRole.unspecified.rawValue == "unspecified")
        }
    }

    // MARK: - Task Tests

    @Suite("Task")
    struct TaskTests {
        @Test("Task state convenience properties")
        func taskStateProperties() {
            let task = A2ATask(
                id: "task-123",
                contextId: "ctx-456",
                status: TaskStatus(state: .working)
            )

            #expect(task.state == .working)
            #expect(task.isComplete == false)
            #expect(task.needsInput == false)
        }

        @Test("Completed task is marked complete")
        func completedTask() {
            let task = A2ATask(
                id: "task-123",
                contextId: "ctx-456",
                status: TaskStatus(state: .completed)
            )

            #expect(task.isComplete == true)
        }

        @Test("Input required task needs input")
        func inputRequiredTask() {
            let task = A2ATask(
                id: "task-123",
                contextId: "ctx-456",
                status: TaskStatus(state: .inputRequired)
            )

            #expect(task.needsInput == true)
        }

        @Test("Task encoding and decoding")
        func taskCoding() throws {
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

            #expect(decoded.id == "task-123")
            #expect(decoded.contextId == "ctx-456")
            #expect(decoded.state == .working)
            #expect(decoded.artifacts?.count == 1)
        }

        @Test("Task JSON uses snake_case")
        func taskSnakeCase() throws {
            let task = A2ATask(
                id: "task-123",
                contextId: "ctx-456",
                status: TaskStatus(state: .working)
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(task)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("context_id"))
            #expect(!json.contains("contextId"))
        }
    }

    // MARK: - AgentCard Tests

    @Suite("AgentCard")
    struct AgentCardTests {
        @Test("Well-known URL construction")
        func wellKnownURL() {
            let url = AgentCard.wellKnownURL(domain: "example.com")
            #expect(url?.absoluteString == "https://example.com/.well-known/agent.json")
        }

        @Test("Agent card encoding and decoding")
        func agentCardCoding() throws {
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

            #expect(decoded.name == "Test Agent")
            #expect(decoded.url == "https://example.com/agent")
            #expect(decoded.capabilities.streaming == true)
            #expect(decoded.skills.count == 1)
        }

        @Test("Agent card JSON uses snake_case")
        func agentCardSnakeCase() throws {
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

            #expect(json.contains("supported_interfaces"))
            #expect(json.contains("protocol_binding"))
            #expect(json.contains("protocol_version"))
            #expect(json.contains("default_input_modes"))
            #expect(json.contains("default_output_modes"))
            #expect(json.contains("push_notifications"))
            #expect(!json.contains("protocolVersion"))
            #expect(!json.contains("defaultInputModes"))
        }

        @Test("Agent card has required fields")
        func agentCardRequiredFields() {
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

            #expect(card.description == "Required description")
            #expect(card.supportedInterfaces.count >= 1)
            #expect(card.defaultInputModes.count >= 1)
            #expect(card.defaultOutputModes.count >= 1)
        }

        @Test("Agent card with empty interfaces throws decoding error")
        func emptyInterfacesThrows() throws {
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
            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(AgentCard.self, from: data)
            }
        }
    }

    // MARK: - Artifact Tests

    @Suite("Artifact")
    struct ArtifactTests {
        @Test("Text artifact creation")
        func textArtifact() {
            let artifact = Artifact.text("Generated content", name: "output.txt")

            #expect(artifact.name == "output.txt")
            #expect(artifact.textContent == "Generated content")
        }

        @Test("Data artifact creation")
        func dataArtifact() {
            let artifact = Artifact.data(["result": "success"], name: "response")

            #expect(artifact.name == "response")
            #expect(artifact.parts.count == 1)
        }

        @Test("Artifact JSON uses snake_case")
        func artifactSnakeCase() throws {
            let artifact = Artifact(
                artifactId: "art-123",
                name: "test",
                parts: [.text("content")]
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(artifact)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("artifact_id"))
            #expect(!json.contains("artifactId"))
        }

        @Test("Artifact extensions is string array")
        func artifactExtensions() throws {
            let artifact = Artifact(
                parts: [.text("test")],
                extensions: ["urn:a2a:ext:example", "urn:a2a:ext:other"]
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(artifact)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Artifact.self, from: data)

            #expect(decoded.extensions?.count == 2)
            #expect(decoded.extensions?.first == "urn:a2a:ext:example")
        }
    }

    // MARK: - AnyCodable Tests

    @Suite("AnyCodable")
    struct AnyCodableTests {
        @Test("String value")
        func stringValue() {
            let value: AnyCodable = "test"
            #expect(value.stringValue == "test")
        }

        @Test("Integer value")
        func intValue() {
            let value: AnyCodable = 42
            #expect(value.intValue == 42)
        }

        @Test("Boolean value")
        func boolValue() {
            let value: AnyCodable = true
            #expect(value.boolValue == true)
        }

        @Test("Null value")
        func nullValue() {
            let value: AnyCodable = nil
            #expect(value.isNull == true)
        }

        @Test("Dictionary encoding and decoding")
        func dictionaryCoding() throws {
            let original: [String: AnyCodable] = [
                "string": "value",
                "number": 123,
                "bool": true
            ]

            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode([String: AnyCodable].self, from: data)

            #expect(decoded["string"]?.stringValue == "value")
            #expect(decoded["number"]?.intValue == 123)
            #expect(decoded["bool"]?.boolValue == true)
        }
    }
}
