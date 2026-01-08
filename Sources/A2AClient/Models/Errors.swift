// Errors.swift
// A2AClient
//
// Agent2Agent Protocol - Error Definitions

import Foundation

/// Errors that can occur during A2A protocol operations.
public enum A2AError: Error, Sendable, Equatable {
    /// The requested task was not found or is not accessible.
    case taskNotFound(taskId: String, message: String?)

    /// The task cannot be cancelled in its current state.
    case taskNotCancelable(taskId: String, state: TaskState, message: String?)

    /// Push notifications are not supported by the agent.
    case pushNotificationNotSupported(message: String?)

    /// The requested operation is not supported.
    case unsupportedOperation(operation: String, message: String?)

    /// The content type is not supported.
    case contentTypeNotSupported(contentType: String, message: String?)

    /// The protocol version is not supported.
    case versionNotSupported(version: String, supportedVersions: [String]?, message: String?)

    /// A required extension is not supported by the client.
    case extensionSupportRequired(extensionUri: String, message: String?)

    /// Authentication failed or is required.
    case authenticationRequired(message: String?)

    /// Authorization failed - access denied.
    case authorizationFailed(message: String?)

    /// Invalid request parameters.
    case invalidRequest(message: String?)

    /// Internal server error.
    case internalError(message: String?)

    /// Network or connectivity error.
    case networkError(underlying: Error?)

    /// JSON encoding/decoding error.
    case encodingError(underlying: Error?)

    /// The response was invalid or unexpected.
    case invalidResponse(message: String?)

    /// JSON-RPC specific error.
    case jsonRPCError(code: Int, message: String, data: AnyCodable?)

    /// Unknown error.
    case unknown(message: String?)

    public static func == (lhs: A2AError, rhs: A2AError) -> Bool {
        switch (lhs, rhs) {
        case (.taskNotFound(let l1, let l2), .taskNotFound(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.taskNotCancelable(let l1, let l2, let l3), .taskNotCancelable(let r1, let r2, let r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case (.pushNotificationNotSupported(let l), .pushNotificationNotSupported(let r)):
            return l == r
        case (.unsupportedOperation(let l1, let l2), .unsupportedOperation(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.contentTypeNotSupported(let l1, let l2), .contentTypeNotSupported(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.versionNotSupported(let l1, let l2, let l3), .versionNotSupported(let r1, let r2, let r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case (.extensionSupportRequired(let l1, let l2), .extensionSupportRequired(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.authenticationRequired(let l), .authenticationRequired(let r)):
            return l == r
        case (.authorizationFailed(let l), .authorizationFailed(let r)):
            return l == r
        case (.invalidRequest(let l), .invalidRequest(let r)):
            return l == r
        case (.internalError(let l), .internalError(let r)):
            return l == r
        case (.networkError, .networkError):
            return true
        case (.encodingError, .encodingError):
            return true
        case (.invalidResponse(let l), .invalidResponse(let r)):
            return l == r
        case (.jsonRPCError(let l1, let l2, _), .jsonRPCError(let r1, let r2, _)):
            return l1 == r1 && l2 == r2
        case (.unknown(let l), .unknown(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - LocalizedError Conformance

extension A2AError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .taskNotFound(let taskId, let message):
            return message ?? "Task not found: \(taskId)"
        case .taskNotCancelable(let taskId, let state, let message):
            return message ?? "Task \(taskId) cannot be cancelled in state: \(state.rawValue)"
        case .pushNotificationNotSupported(let message):
            return message ?? "Push notifications are not supported"
        case .unsupportedOperation(let operation, let message):
            return message ?? "Operation not supported: \(operation)"
        case .contentTypeNotSupported(let contentType, let message):
            return message ?? "Content type not supported: \(contentType)"
        case .versionNotSupported(let version, _, let message):
            return message ?? "Protocol version not supported: \(version)"
        case .extensionSupportRequired(let uri, let message):
            return message ?? "Required extension not supported: \(uri)"
        case .authenticationRequired(let message):
            return message ?? "Authentication required"
        case .authorizationFailed(let message):
            return message ?? "Authorization failed"
        case .invalidRequest(let message):
            return message ?? "Invalid request"
        case .internalError(let message):
            return message ?? "Internal server error"
        case .networkError(let underlying):
            return underlying?.localizedDescription ?? "Network error"
        case .encodingError(let underlying):
            return underlying?.localizedDescription ?? "Encoding error"
        case .invalidResponse(let message):
            return message ?? "Invalid response"
        case .jsonRPCError(let code, let message, _):
            return "JSON-RPC error \(code): \(message)"
        case .unknown(let message):
            return message ?? "Unknown error"
        }
    }
}

// MARK: - JSON-RPC Error Codes

/// Standard JSON-RPC 2.0 error codes.
public enum JSONRPCErrorCode: Int, Sendable {
    /// Invalid JSON was received.
    case parseError = -32700

    /// The JSON sent is not a valid Request object.
    case invalidRequest = -32600

    /// The method does not exist or is not available.
    case methodNotFound = -32601

    /// Invalid method parameters.
    case invalidParams = -32602

    /// Internal JSON-RPC error.
    case internalError = -32603

    // A2A-specific error codes (reserved range: -32000 to -32099)

    /// Task not found.
    case taskNotFound = -32001

    /// Task not cancelable.
    case taskNotCancelable = -32002

    /// Push notifications not supported.
    case pushNotificationNotSupported = -32003

    /// Unsupported operation.
    case unsupportedOperation = -32004

    /// Content type not supported.
    case contentTypeNotSupported = -32005

    /// Version not supported.
    case versionNotSupported = -32006

    /// Extension support required.
    case extensionSupportRequired = -32007
}

// MARK: - Error Response Model

/// A2A error response structure for JSON encoding/decoding.
public struct A2AErrorResponse: Codable, Sendable, Equatable {
    /// Error code.
    public let code: Int

    /// Error message.
    public let message: String

    /// Optional additional error data.
    public let data: AnyCodable?

    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    /// Extracts a string value from the error data dictionary.
    private func extractString(_ key: String) -> String? {
        guard let dict = data?.dictionaryValue,
              let value = dict[key] else { return nil }
        if let strValue = value as? String {
            return strValue
        }
        if let anyCodable = value as? AnyCodable {
            return anyCodable.stringValue
        }
        return nil
    }

    /// Extracts a string array from the error data dictionary.
    private func extractStringArray(_ key: String) -> [String]? {
        guard let dict = data?.dictionaryValue,
              let value = dict[key] else { return nil }
        if let arrayValue = value as? [String] {
            return arrayValue
        }
        if let anyCodable = value as? AnyCodable,
           let arr = anyCodable.arrayValue {
            return arr.compactMap { ($0 as? AnyCodable)?.stringValue ?? ($0 as? String) }
        }
        if let anyArray = value as? [Any] {
            return anyArray.compactMap { $0 as? String }
        }
        return nil
    }

    /// Converts this error response to an A2AError.
    public func toA2AError() -> A2AError {
        switch code {
        case JSONRPCErrorCode.taskNotFound.rawValue:
            let taskId = extractString("task_id") ?? extractString("taskId") ?? ""
            return .taskNotFound(taskId: taskId, message: message)
        case JSONRPCErrorCode.taskNotCancelable.rawValue:
            let taskId = extractString("task_id") ?? extractString("taskId") ?? ""
            let stateStr = extractString("state") ?? "working"
            let state = TaskState(rawValue: stateStr) ?? .working
            return .taskNotCancelable(taskId: taskId, state: state, message: message)
        case JSONRPCErrorCode.pushNotificationNotSupported.rawValue:
            return .pushNotificationNotSupported(message: message)
        case JSONRPCErrorCode.unsupportedOperation.rawValue:
            let operation = extractString("operation") ?? ""
            return .unsupportedOperation(operation: operation, message: message)
        case JSONRPCErrorCode.contentTypeNotSupported.rawValue:
            let contentType = extractString("content_type") ?? extractString("contentType") ?? ""
            return .contentTypeNotSupported(contentType: contentType, message: message)
        case JSONRPCErrorCode.versionNotSupported.rawValue:
            let version = extractString("version") ?? ""
            let supportedVersions = extractStringArray("supported_versions") ?? extractStringArray("supportedVersions")
            return .versionNotSupported(version: version, supportedVersions: supportedVersions, message: message)
        case JSONRPCErrorCode.extensionSupportRequired.rawValue:
            let extensionUri = extractString("extension_uri") ?? extractString("extensionUri") ?? ""
            return .extensionSupportRequired(extensionUri: extensionUri, message: message)
        case JSONRPCErrorCode.invalidRequest.rawValue, JSONRPCErrorCode.invalidParams.rawValue:
            return .invalidRequest(message: message)
        case JSONRPCErrorCode.internalError.rawValue:
            return .internalError(message: message)
        default:
            return .jsonRPCError(code: code, message: message, data: data)
        }
    }
}
