// TaskState.swift
// A2AClient
//
// Agent2Agent Protocol - Task State Definitions

import Foundation

/// Represents the current state of a Task in the A2A protocol.
///
/// Tasks progress through a defined lifecycle, transitioning between states
/// based on agent processing and client interactions.
public enum TaskState: String, Codable, Sendable, Equatable, CaseIterable {
    /// Unspecified state (default value).
    case unspecified = "unspecified"

    /// Task has been received but processing has not yet begun.
    case submitted = "submitted"

    /// Task is actively being processed by the agent.
    case working = "working"

    /// Task completed successfully. This is a terminal state.
    case completed = "completed"

    /// Task failed due to an error. This is a terminal state.
    case failed = "failed"

    /// Task was cancelled by the client. This is a terminal state.
    case cancelled = "cancelled"

    /// Agent requires additional input from the client to proceed.
    case inputRequired = "input_required"

    /// Task was rejected by the server. This is a terminal state.
    case rejected = "rejected"

    /// Task requires authentication to proceed.
    case authRequired = "auth_required"

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
}

/// Represents the status of a task including state, optional message, and timestamp.
public struct TaskStatus: Codable, Sendable, Equatable {
    /// The current state of the task.
    public let state: TaskState

    /// Optional human-readable message providing additional context about the status.
    public let message: Message?

    /// Timestamp when this status was set (ISO 8601 format).
    public let timestamp: Date?

    public init(
        state: TaskState,
        message: Message? = nil,
        timestamp: Date? = nil
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
