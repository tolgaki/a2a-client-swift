// StreamingEvents.swift
// A2AClient
//
// Agent2Agent Protocol - Streaming Event Definitions

import Foundation

/// Events that can be received during streaming operations.
public enum StreamingEvent: Sendable {
    /// A task status update event.
    case taskStatusUpdate(TaskStatusUpdateEvent)

    /// A task artifact update event.
    case taskArtifactUpdate(TaskArtifactUpdateEvent)
}

/// Event indicating a change in task status.
public struct TaskStatusUpdateEvent: Codable, Sendable, Equatable {
    /// The task ID this event relates to.
    public let taskId: String

    /// The context ID.
    public let contextId: String?

    /// The updated status.
    public let status: TaskStatus

    /// Whether this is the final update for the task.
    public let final: Bool?

    /// Optional metadata.
    public let metadata: [String: AnyCodable]?

    public init(
        taskId: String,
        contextId: String? = nil,
        status: TaskStatus,
        final: Bool? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.taskId = taskId
        self.contextId = contextId
        self.status = status
        self.final = final
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case contextId = "context_id"
        case status
        case final
        case metadata
    }
}

/// Event indicating a new or updated artifact.
public struct TaskArtifactUpdateEvent: Codable, Sendable, Equatable {
    /// The task ID this event relates to.
    public let taskId: String

    /// The context ID.
    public let contextId: String?

    /// The artifact being added or updated.
    public let artifact: Artifact

    /// Optional metadata.
    public let metadata: [String: AnyCodable]?

    public init(
        taskId: String,
        contextId: String? = nil,
        artifact: Artifact,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.taskId = taskId
        self.contextId = contextId
        self.artifact = artifact
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case contextId = "context_id"
        case artifact
        case metadata
    }
}

// MARK: - StreamingEvent Extensions

extension StreamingEvent {
    /// The task ID associated with this event.
    public var taskId: String {
        switch self {
        case .taskStatusUpdate(let event):
            return event.taskId
        case .taskArtifactUpdate(let event):
            return event.taskId
        }
    }

    /// The context ID associated with this event, if any.
    public var contextId: String? {
        switch self {
        case .taskStatusUpdate(let event):
            return event.contextId
        case .taskArtifactUpdate(let event):
            return event.contextId
        }
    }

    /// Whether this is a status update event.
    public var isStatusUpdate: Bool {
        if case .taskStatusUpdate = self {
            return true
        }
        return false
    }

    /// Whether this is an artifact update event.
    public var isArtifactUpdate: Bool {
        if case .taskArtifactUpdate = self {
            return true
        }
        return false
    }

    /// Returns the status update event, if this is one.
    public var statusUpdate: TaskStatusUpdateEvent? {
        if case .taskStatusUpdate(let event) = self {
            return event
        }
        return nil
    }

    /// Returns the artifact update event, if this is one.
    public var artifactUpdate: TaskArtifactUpdateEvent? {
        if case .taskArtifactUpdate(let event) = self {
            return event
        }
        return nil
    }
}
