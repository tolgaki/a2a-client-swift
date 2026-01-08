// ErrorTests.swift
// A2AClientTests
//
// Tests for A2A error types

import Testing
import Foundation
@testable import A2AClient

@Suite("Error Tests")
struct ErrorTests {

    // MARK: - A2AError Tests

    @Suite("A2AError")
    struct A2AErrorTests {
        @Test("Error descriptions are meaningful")
        func errorDescriptions() {
            let taskNotFound = A2AError.taskNotFound(taskId: "task-123", message: nil)
            #expect(taskNotFound.localizedDescription.contains("task-123"))

            let taskNotCancelable = A2AError.taskNotCancelable(
                taskId: "task-456",
                state: .working,
                message: nil
            )
            #expect(taskNotCancelable.localizedDescription.contains("task-456"))
            #expect(taskNotCancelable.localizedDescription.contains("working"))

            let pushNotSupported = A2AError.pushNotificationNotSupported(message: nil)
            #expect(pushNotSupported.localizedDescription.contains("Push notifications"))
        }

        @Test("Custom messages override defaults")
        func customMessages() {
            let error = A2AError.taskNotFound(taskId: "task-123", message: "Custom error message")
            #expect(error.localizedDescription == "Custom error message")
        }

        @Test("Error equality")
        func errorEquality() {
            let error1 = A2AError.taskNotFound(taskId: "task-123", message: nil)
            let error2 = A2AError.taskNotFound(taskId: "task-123", message: nil)
            let error3 = A2AError.taskNotFound(taskId: "task-456", message: nil)

            #expect(error1 == error2)
            #expect(error1 != error3)
        }
    }

    // MARK: - JSON-RPC Error Codes

    @Suite("JSON-RPC Error Codes")
    struct JSONRPCErrorCodeTests {
        @Test("Standard error codes have correct values")
        func standardErrorCodes() {
            #expect(JSONRPCErrorCode.parseError.rawValue == -32700)
            #expect(JSONRPCErrorCode.invalidRequest.rawValue == -32600)
            #expect(JSONRPCErrorCode.methodNotFound.rawValue == -32601)
            #expect(JSONRPCErrorCode.invalidParams.rawValue == -32602)
            #expect(JSONRPCErrorCode.internalError.rawValue == -32603)
        }

        @Test("A2A-specific error codes are in reserved range")
        func a2aErrorCodes() {
            #expect(JSONRPCErrorCode.taskNotFound.rawValue == -32001)
            #expect(JSONRPCErrorCode.taskNotCancelable.rawValue == -32002)
            #expect(JSONRPCErrorCode.pushNotificationNotSupported.rawValue == -32003)
        }
    }

    // MARK: - Error Response Conversion

    @Suite("Error Response Conversion")
    struct ErrorResponseTests {
        @Test("Error response converts to A2AError")
        func errorResponseConversion() {
            let response = A2AErrorResponse(
                code: JSONRPCErrorCode.taskNotFound.rawValue,
                message: "Task not found"
            )

            let error = response.toA2AError()

            if case .taskNotFound = error {
                // Success
            } else {
                Issue.record("Expected taskNotFound error")
            }
        }

        @Test("Unknown error code produces jsonRPCError")
        func unknownErrorCode() {
            let response = A2AErrorResponse(
                code: -99999,
                message: "Unknown error"
            )

            let error = response.toA2AError()

            if case .jsonRPCError(let code, let message, _) = error {
                #expect(code == -99999)
                #expect(message == "Unknown error")
            } else {
                Issue.record("Expected jsonRPCError")
            }
        }
    }
}
