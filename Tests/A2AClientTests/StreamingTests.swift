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

    // MARK: - SSE Line Splitter Tests

    func testSSELineSplitter_SplitsCompleteLines() {
        var splitter = SSELineSplitter()
        let lines = splitter.push(Data("data: one\ndata: two\n".utf8))
        XCTAssertEqual(lines, ["data: one", "data: two"])
        XCTAssertNil(splitter.flush())
    }

    func testSSELineSplitter_BuffersAcrossChunkBoundaries() {
        var splitter = SSELineSplitter()
        XCTAssertEqual(splitter.push(Data("data: par".utf8)), [])
        XCTAssertEqual(splitter.push(Data("tial\ndata: ne".utf8)), ["data: partial"])
        XCTAssertEqual(splitter.push(Data("xt\n".utf8)), ["data: next"])
    }

    func testSSELineSplitter_HandlesCRLF() {
        var splitter = SSELineSplitter()
        let lines = splitter.push(Data("data: a\r\n\r\ndata: b\r\n".utf8))
        XCTAssertEqual(lines, ["data: a", "", "data: b"])
    }

    func testSSELineSplitter_FlushReturnsUnterminatedTail() {
        var splitter = SSELineSplitter()
        XCTAssertEqual(splitter.push(Data("data: done\ntail".utf8)), ["data: done"])
        XCTAssertEqual(splitter.flush(), "tail")
        XCTAssertNil(splitter.flush())
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

    func testSSEParser_ConsecutiveDataLinesEmitSeparateEvents() {
        // Servers like Graph RP send consecutive data: lines without blank separators.
        // Each data: line is a complete event; the second data: line triggers
        // emission of the first buffered event.
        let parser = SSEParser()

        let event1 = parser.parse(line: "data: line 1")
        XCTAssertNil(event1) // first line buffers

        let event2 = parser.parse(line: "data: line 2")
        XCTAssertNotNil(event2) // second line emits buffered "line 1"
        XCTAssertEqual(event2?.data, "line 1")

        let event3 = parser.parse(line: "data: line 3")
        XCTAssertNotNil(event3)
        XCTAssertEqual(event3?.data, "line 2")

        // Blank line emits the last buffered event
        let event4 = parser.parse(line: "")
        XCTAssertNotNil(event4)
        XCTAssertEqual(event4?.data, "line 3")
    }

    func testSSEParser_StandardBlankLineDelimitedEvents() {
        // Standard SSE: event + data + blank line
        let parser = SSEParser()

        _ = parser.parse(line: "event: status")
        _ = parser.parse(line: "data: payload1")
        let event1 = parser.parse(line: "")
        XCTAssertNotNil(event1)
        XCTAssertEqual(event1?.event, "status")
        XCTAssertEqual(event1?.data, "payload1")

        _ = parser.parse(line: "event: artifact")
        _ = parser.parse(line: "data: payload2")
        let event2 = parser.parse(line: "")
        XCTAssertNotNil(event2)
        XCTAssertEqual(event2?.event, "artifact")
        XCTAssertEqual(event2?.data, "payload2")
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
