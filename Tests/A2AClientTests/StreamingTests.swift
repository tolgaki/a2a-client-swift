// StreamingTests.swift
// A2AClientTests
//
// Tests for A2A streaming functionality

import XCTest
import Foundation
@testable import A2AClient

final class StreamingTests: XCTestCase {

    // MARK: - Streaming Event Tests

    func testStreamingEvent_TaskStatusUpdateEventProperties() {
        let event = TaskStatusUpdateEvent(
            taskId: "task-123",
            contextId: "ctx-456",
            status: TaskStatus(state: .working)
        )

        let streamingEvent = StreamingEvent.taskStatusUpdate(event)

        XCTAssertEqual(streamingEvent.taskId, "task-123")
        XCTAssertEqual(streamingEvent.contextId, "ctx-456")
        XCTAssertTrue(streamingEvent.isStatusUpdate)
        XCTAssertFalse(streamingEvent.isArtifactUpdate)
        XCTAssertNotNil(streamingEvent.statusUpdateEvent)
        XCTAssertNil(streamingEvent.artifactUpdateEvent)
    }

    func testStreamingEvent_TaskArtifactUpdateEventProperties() {
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

        XCTAssertEqual(streamingEvent.taskId, "task-123")
        XCTAssertFalse(streamingEvent.isStatusUpdate)
        XCTAssertTrue(streamingEvent.isArtifactUpdate)
        XCTAssertEqual(streamingEvent.artifactUpdateEvent?.artifact.name, "output")
    }

    func testStreamingEvent_StatusUpdateEncodingAndDecoding() throws {
        let event = TaskStatusUpdateEvent(
            taskId: "task-123",
            contextId: "ctx-456",
            status: TaskStatus(state: .completed)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TaskStatusUpdateEvent.self, from: data)

        XCTAssertEqual(decoded.taskId, "task-123")
        XCTAssertEqual(decoded.contextId, "ctx-456")
        XCTAssertEqual(decoded.status.state, .completed)
    }

    func testStreamingEvent_ArtifactUpdateEncodingAndDecoding() throws {
        let artifact = Artifact(
            artifactId: "art-123",
            name: "result",
            parts: [.text("Output")]
        )
        let event = TaskArtifactUpdateEvent(
            taskId: "task-456",
            contextId: "ctx-789",
            artifact: artifact
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TaskArtifactUpdateEvent.self, from: data)

        XCTAssertEqual(decoded.taskId, "task-456")
        XCTAssertEqual(decoded.contextId, "ctx-789")
        XCTAssertEqual(decoded.artifact.artifactId, "art-123")
        XCTAssertEqual(decoded.artifact.name, "result")
    }

    // MARK: - SSE Parser Tests

    func testSSEParser_ParseSimpleDataEvent() {
        let parser = SSEParser()

        // Feed lines
        _ = parser.parse(line: "data: Hello, World!")
        let event = parser.parse(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.data, "Hello, World!")
        XCTAssertNil(event?.event)
    }

    func testSSEParser_ParseEventWithType() {
        let parser = SSEParser()

        _ = parser.parse(line: "event: status")
        _ = parser.parse(line: "data: {\"state\": \"working\"}")
        let event = parser.parse(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.event, "status")
        XCTAssertEqual(event?.data.contains("working"), true)
    }

    func testSSEParser_ParseEventWithId() {
        let parser = SSEParser()

        _ = parser.parse(line: "id: 12345")
        _ = parser.parse(line: "data: test")
        let event = parser.parse(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.id, "12345")
    }

    func testSSEParser_ParseMultiLineData() {
        let parser = SSEParser()

        _ = parser.parse(line: "data: line 1")
        _ = parser.parse(line: "data: line 2")
        _ = parser.parse(line: "data: line 3")
        let event = parser.parse(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.data, "line 1\nline 2\nline 3")
    }

    func testSSEParser_EmptyLinesWithoutDataProduceNoEvent() {
        let parser = SSEParser()

        let event1 = parser.parse(line: "")
        let event2 = parser.parse(line: "")

        XCTAssertNil(event1)
        XCTAssertNil(event2)
    }

    func testSSEParser_ParserResetsAfterEvent() {
        let parser = SSEParser()

        _ = parser.parse(line: "event: first")
        _ = parser.parse(line: "data: event 1")
        let event1 = parser.parse(line: "")

        _ = parser.parse(line: "event: second")
        _ = parser.parse(line: "data: event 2")
        let event2 = parser.parse(line: "")

        XCTAssertEqual(event1?.event, "first")
        XCTAssertEqual(event1?.data, "event 1")
        XCTAssertEqual(event2?.event, "second")
        XCTAssertEqual(event2?.data, "event 2")
    }
}
