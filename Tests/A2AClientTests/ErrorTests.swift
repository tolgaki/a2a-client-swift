// ErrorTests.swift
// A2AClientTests
//
// Tests for A2A error types

import XCTest
import Foundation
@testable import A2AClient

final class ErrorTests: XCTestCase {

    // MARK: - A2AError Tests

    func testA2AError_ErrorDescriptionsAreMeaningful() {
        let taskNotFound = A2AError.taskNotFound(taskId: "task-123", message: nil)
        XCTAssertTrue(taskNotFound.localizedDescription.contains("task-123"))

        let taskNotCancelable = A2AError.taskNotCancelable(
            taskId: "task-456",
            state: .working,
            message: nil
        )
        XCTAssertTrue(taskNotCancelable.localizedDescription.contains("task-456"))
        XCTAssertTrue(taskNotCancelable.localizedDescription.contains("working"))

        let pushNotSupported = A2AError.pushNotificationNotSupported(message: nil)
        XCTAssertTrue(pushNotSupported.localizedDescription.contains("Push notifications"))
    }

    func testA2AError_CustomMessagesOverrideDefaults() {
        let error = A2AError.taskNotFound(taskId: "task-123", message: "Custom error message")
        XCTAssertEqual(error.localizedDescription, "Custom error message")
    }

    func testA2AError_ErrorEquality() {
        let error1 = A2AError.taskNotFound(taskId: "task-123", message: nil)
        let error2 = A2AError.taskNotFound(taskId: "task-123", message: nil)
        let error3 = A2AError.taskNotFound(taskId: "task-456", message: nil)

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    // MARK: - JSON-RPC Error Codes

    func testJSONRPCErrorCode_StandardErrorCodesHaveCorrectValues() {
        XCTAssertEqual(JSONRPCErrorCode.parseError.rawValue, -32700)
        XCTAssertEqual(JSONRPCErrorCode.invalidRequest.rawValue, -32600)
        XCTAssertEqual(JSONRPCErrorCode.methodNotFound.rawValue, -32601)
        XCTAssertEqual(JSONRPCErrorCode.invalidParams.rawValue, -32602)
        XCTAssertEqual(JSONRPCErrorCode.internalError.rawValue, -32603)
    }

    func testJSONRPCErrorCode_A2ASpecificErrorCodesAreInReservedRange() {
        XCTAssertEqual(JSONRPCErrorCode.taskNotFound.rawValue, -32001)
        XCTAssertEqual(JSONRPCErrorCode.taskNotCancelable.rawValue, -32002)
        XCTAssertEqual(JSONRPCErrorCode.pushNotificationNotSupported.rawValue, -32003)
    }

    // MARK: - Error Response Conversion

    func testErrorResponse_ConvertsToA2AError() {
        let response = A2AErrorResponse(
            code: JSONRPCErrorCode.taskNotFound.rawValue,
            message: "Task not found"
        )

        let error = response.toA2AError()

        if case .taskNotFound = error {
            // Success
        } else {
            XCTFail("Expected taskNotFound error")
        }
    }

    func testErrorResponse_UnknownErrorCodeProducesJsonRPCError() {
        let response = A2AErrorResponse(
            code: -99999,
            message: "Unknown error"
        )

        let error = response.toA2AError()

        if case .jsonRPCError(let code, let message, _) = error {
            XCTAssertEqual(code, -99999)
            XCTAssertEqual(message, "Unknown error")
        } else {
            XCTFail("Expected jsonRPCError")
        }
    }
}
