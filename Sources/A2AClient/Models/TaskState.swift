// TaskState.swift
// A2AClient
//
// Agent2Agent Protocol - Task State Definitions

import Foundation

/// Represents the current state of a Task in the A2A protocol.
///
/// Tasks progress through a defined lifecycle, transitioning between states
/// based on agent processing and client interactions.
///
/// Encoding uses v1.0 SCREAMING_SNAKE_CASE values (e.g., `TASK_STATE_COMPLETED`).
/// Decoding accepts both v1.0 and v0.3 lowercase values (e.g., `"completed"`).
public enum TaskState: String, Sendable, Equatable, CaseIterable {
    /// Unspecified state (default value).
    case unspecified = "TASK_STATE_UNSPECIFIED"

    /// Task has been received but processing has not yet begun.
    case submitted = "TASK_STATE_SUBMITTED"

    /// Task is actively being processed by the agent.
    case working = "TASK_STATE_WORKING"

    /// Task completed successfully. This is a terminal state.
    case completed = "TASK_STATE_COMPLETED"

    /// Task failed due to an error. This is a terminal state.
    case failed = "TASK_STATE_FAILED"

    /// Task was cancelled by the client. This is a terminal state.
    case cancelled = "TASK_STATE_CANCELED"

    /// Agent requires additional input from the client to proceed.
    case inputRequired = "TASK_STATE_INPUT_REQUIRED"

    /// Task was rejected by the server. This is a terminal state.
    case rejected = "TASK_STATE_REJECTED"

    /// Task requires authentication to proceed.
    case authRequired = "TASK_STATE_AUTH_REQUIRED"

    /// Whether this state represents a terminal (final) state.
    ///
    /// Terminal states cannot transition to other states.
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .rejected:
            return true
        case .unspecified, .submitted, .working, .inputRequired, .authRequired:
            return false
        }
    }

    /// Whether this state indicates the task can receive additional input.
    public var canReceiveInput: Bool {
        switch self {
        case .inputRequired, .authRequired:
            return true
        case .unspecified, .submitted, .working, .completed, .failed, .cancelled, .rejected:
            return false
        }
    }

    // MARK: - v0.3 Backward Compatibility

    /// Mapping from v0.3 lowercase values to TaskState cases.
    private static let v03Mapping: [String: TaskState] = [
        "unspecified": .unspecified,
        "submitted": .submitted,
        "working": .working,
        "completed": .completed,
        "failed": .failed,
        "cancelled": .cancelled,
        "canceled": .cancelled,
        "input_required": .inputRequired,
        "rejected": .rejected,
        "auth_required": .authRequired,
    ]

    /// Creates a TaskState from a string, accepting both v1.0 and v0.3 formats.
    public init?(string: String) {
        if let state = TaskState(rawValue: string) {
            self = state
        } else if let state = TaskState.v03Mapping[string] {
            self = state
        } else {
            return nil
        }
    }
}

// MARK: - Codable

extension TaskState: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let state = TaskState(rawValue: value) {
            self = state
        } else if let state = TaskState.v03Mapping[value] {
            self = state
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown TaskState value: \(value)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Encode as v0.3 lowercase when targeting a v0.3 server
        if let version = encoder.userInfo[a2aProtocolVersionKey] as? String,
           version.hasPrefix("0.") {
            let v03Value = Self.v10ToV03[self] ?? rawValue
            try container.encode(v03Value)
        } else {
            try container.encode(rawValue)
        }
    }

    /// Mapping from TaskState cases to v0.3 lowercase values.
    private static let v10ToV03: [TaskState: String] = [
        .unspecified: "unspecified",
        .submitted: "submitted",
        .working: "working",
        .completed: "completed",
        .failed: "failed",
        .cancelled: "cancelled",
        .inputRequired: "input_required",
        .rejected: "rejected",
        .authRequired: "auth_required",
    ]
}

/// Represents the status of a task including state, optional message, and timestamp.
public struct TaskStatus: Codable, Sendable, Equatable {
    /// The current state of the task.
    public let state: TaskState

    /// Optional human-readable message providing additional context about the status.
    public let message: Message?

    /// Timestamp when this status was set (ISO 8601 format string).
    public let timestamp: String?

    public init(
        state: TaskState,
        message: Message? = nil,
        timestamp: String? = nil
    ) {
        self.state = state
        self.message = message
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case state
        case message
        case timestamp
    }
}
