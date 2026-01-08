// StreamingTests.swift
// A2AClientTests
//
// Tests for A2A streaming functionality

import Testing
import Foundation
@testable import A2AClient

@Suite("Streaming Tests")
struct StreamingTests {

    // MARK: - Streaming Event Tests

    @Suite("Streaming Events")
    struct StreamingEventTests {
        @Test("Task status update event properties")
        func statusUpdateEvent() {
            let event = TaskStatusUpdateEvent(
                taskId: "task-123",
                contextId: "ctx-456",
                status: TaskStatus(state: .working),
                final: false
            )

            let streamingEvent = StreamingEvent.taskStatusUpdate(event)

            #expect(streamingEvent.taskId == "task-123")
            #expect(streamingEvent.contextId == "ctx-456")
            #expect(streamingEvent.isStatusUpdate == true)
            #expect(streamingEvent.isArtifactUpdate == false)
            #expect(streamingEvent.statusUpdate != nil)
            #expect(streamingEvent.artifactUpdate == nil)
        }

        @Test("Task artifact update event properties")
        func artifactUpdateEvent() {
            let artifact = Artifact(
                name: "output",
                parts: [.text("Generated content")]
            )
            let event = TaskArtifactUpdateEvent(
                taskId: "task-123",
                contextId: "ctx-456",
                artifact: artifact
            )

            let streamingEvent = StreamingEvent.taskArtifactUpdate(event)

            #expect(streamingEvent.taskId == "task-123")
            #expect(streamingEvent.isStatusUpdate == false)
            #expect(streamingEvent.isArtifactUpdate == true)
            #expect(streamingEvent.artifactUpdate?.artifact.name == "output")
        }

        @Test("Status update event encoding and decoding")
        func statusUpdateCoding() throws {
            let event = TaskStatusUpdateEvent(
                taskId: "task-123",
                contextId: "ctx-456",
                status: TaskStatus(state: .completed),
                final: true
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(event)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(TaskStatusUpdateEvent.self, from: data)

            #expect(decoded.taskId == "task-123")
            #expect(decoded.contextId == "ctx-456")
            #expect(decoded.status.state == .completed)
            #expect(decoded.final == true)
        }

        @Test("Artifact update event encoding and decoding")
        func artifactUpdateCoding() throws {
            let artifact = Artifact(
                artifactId: "art-123",
                name: "result",
                parts: [.text("Output")]
            )
            let event = TaskArtifactUpdateEvent(
                taskId: "task-456",
                artifact: artifact
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(event)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(TaskArtifactUpdateEvent.self, from: data)

            #expect(decoded.taskId == "task-456")
            #expect(decoded.artifact.artifactId == "art-123")
            #expect(decoded.artifact.name == "result")
        }
    }

    // MARK: - SSE Parser Tests

    @Suite("SSE Parser")
    struct SSEParserTests {
        @Test("Parse simple data event")
        func parseSimpleEvent() {
            let parser = SSEParser()

            // Feed lines
            _ = parser.parse(line: "data: Hello, World!")
            let event = parser.parse(line: "")

            #expect(event != nil)
            #expect(event?.data == "Hello, World!")
            #expect(event?.event == nil)
        }

        @Test("Parse event with type")
        func parseTypedEvent() {
            let parser = SSEParser()

            _ = parser.parse(line: "event: status")
            _ = parser.parse(line: "data: {\"state\": \"working\"}")
            let event = parser.parse(line: "")

            #expect(event != nil)
            #expect(event?.event == "status")
            #expect(event?.data.contains("working") == true)
        }

        @Test("Parse event with ID")
        func parseEventWithId() {
            let parser = SSEParser()

            _ = parser.parse(line: "id: 12345")
            _ = parser.parse(line: "data: test")
            let event = parser.parse(line: "")

            #expect(event != nil)
            #expect(event?.id == "12345")
        }

        @Test("Parse multi-line data")
        func parseMultiLineData() {
            let parser = SSEParser()

            _ = parser.parse(line: "data: line 1")
            _ = parser.parse(line: "data: line 2")
            _ = parser.parse(line: "data: line 3")
            let event = parser.parse(line: "")

            #expect(event != nil)
            #expect(event?.data == "line 1\nline 2\nline 3")
        }

        @Test("Empty lines without data produce no event")
        func emptyLinesNoEvent() {
            let parser = SSEParser()

            let event1 = parser.parse(line: "")
            let event2 = parser.parse(line: "")

            #expect(event1 == nil)
            #expect(event2 == nil)
        }

        @Test("Parser resets after event")
        func parserResetsAfterEvent() {
            let parser = SSEParser()

            _ = parser.parse(line: "event: first")
            _ = parser.parse(line: "data: event 1")
            let event1 = parser.parse(line: "")

            _ = parser.parse(line: "event: second")
            _ = parser.parse(line: "data: event 2")
            let event2 = parser.parse(line: "")

            #expect(event1?.event == "first")
            #expect(event1?.data == "event 1")
            #expect(event2?.event == "second")
            #expect(event2?.data == "event 2")
        }
    }
}
