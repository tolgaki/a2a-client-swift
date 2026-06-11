// GoldenVectorTests.swift
// A2AClientTests
//
// Byte-exact wire-format vectors. These pin the v1.0 JSON shapes (no
// `kind` discriminators, field-presence oneof wrappers, SCREAMING enum
// values) and the v0.3 legacy shapes, so regressions show up as a string
// diff instead of a cross-SDK interop failure.

import XCTest
import Foundation
@testable import A2AClient

final class GoldenVectorTests: XCTestCase {

    private func encoder(version: String? = nil) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        if let version = version {
            encoder.userInfo[a2aProtocolVersionKey] = version
        }
        return encoder
    }

    private func json<T: Encodable>(_ value: T, version: String? = nil) throws -> String {
        String(data: try encoder(version: version).encode(value), encoding: .utf8)!
    }

    // MARK: - v1.0 vectors

    func testGolden_SendMessageRequest_V10() throws {
        let request = SendMessageRequest(
            message: Message(
                messageId: "msg-1",
                role: .user,
                parts: [.text("Hello")],
                contextId: "ctx-1"
            )
        )

        XCTAssertEqual(
            try json(request),
            #"{"message":{"contextId":"ctx-1","messageId":"msg-1","parts":[{"mediaType":"text/plain","text":"Hello"}],"role":"ROLE_USER"}}"#
        )
    }

    func testGolden_SendMessageResponse_Message_V10() throws {
        let response = SendMessageResponse.message(
            Message(messageId: "msg-2", role: .agent, parts: [.text("Hi")])
        )

        XCTAssertEqual(
            try json(response),
            #"{"message":{"messageId":"msg-2","parts":[{"mediaType":"text/plain","text":"Hi"}],"role":"ROLE_AGENT"}}"#
        )
    }

    func testGolden_SendMessageResponse_Task_V10() throws {
        let response = SendMessageResponse.task(
            A2ATask(
                id: "task-1",
                contextId: "ctx-1",
                status: TaskStatus(state: .submitted, timestamp: "2026-01-01T00:00:00Z")
            )
        )

        XCTAssertEqual(
            try json(response),
            #"{"task":{"contextId":"ctx-1","id":"task-1","status":{"state":"TASK_STATE_SUBMITTED","timestamp":"2026-01-01T00:00:00Z"}}}"#
        )
    }

    func testGolden_StreamResponse_StatusUpdate_V10() throws {
        let response = StreamResponse.statusUpdate(
            TaskStatusUpdateEvent(
                taskId: "task-1",
                contextId: "ctx-1",
                status: TaskStatus(state: .completed, timestamp: "2026-01-01T00:00:00Z"),
                final: true
            )
        )

        XCTAssertEqual(
            try json(response),
            #"{"statusUpdate":{"contextId":"ctx-1","final":true,"status":{"state":"TASK_STATE_COMPLETED","timestamp":"2026-01-01T00:00:00Z"},"taskId":"task-1"}}"#
        )
    }

    // MARK: - v0.3 vectors

    func testGolden_Message_V03() throws {
        let message = Message(
            messageId: "msg-1",
            role: .user,
            parts: [.text("Hello")],
            contextId: "ctx-1"
        )

        XCTAssertEqual(
            try json(message, version: "0.3"),
            #"{"contextId":"ctx-1","kind":"message","messageId":"msg-1","parts":[{"kind":"text","mediaType":"text/plain","text":"Hello"}],"role":"user"}"#
        )
    }

    // MARK: - Round trips

    func testGolden_SendMessageResponse_V10_RoundTrip() throws {
        let original = SendMessageResponse.task(
            A2ATask(
                id: "task-1",
                contextId: "ctx-1",
                status: TaskStatus(state: .working)
            )
        )
        let data = try encoder().encode(original)
        let decoded = try JSONDecoder().decode(SendMessageResponse.self, from: data)

        XCTAssertEqual(decoded.task?.id, "task-1")
        XCTAssertEqual(decoded.task?.status.state, .working)
    }
}
