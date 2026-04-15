// StreamingEvents.swift
// A2AClient
//
// Agent2Agent Protocol - Streaming Event Definitions
// Spec: https://a2a-protocol.org/latest/specification/#42-streaming-events

import Foundation

// MARK: - StreamResponse

/// A wrapper object used in streaming operations to encapsulate different types of response data.
/// A StreamResponse contains exactly one of: task, message, statusUpdate, or artifactUpdate.
public enum StreamResponse: Codable, Sendable {
    /// A Task object with the current task state.
    case task(A2ATask)

    /// A Message object from the agent.
    case message(Message)

    /// A task status update event.
    case statusUpdate(TaskStatusUpdateEvent)

    /// A task artifact update event.
    case artifactUpdate(TaskArtifactUpdateEvent)

    private enum CodingKeys: String, CodingKey {
        case task
        case message
        case statusUpdate
        case artifactUpdate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let task = try container.decodeIfPresent(A2ATask.self, forKey: .task) {
            self = .task(task)
        } else if let message = try container.decodeIfPresent(Message.self, forKey: .message) {
            self = .message(message)
        } else if let statusUpdate = try container.decodeIfPresent(TaskStatusUpdateEvent.self, forKey: .statusUpdate) {
            self = .statusUpdate(statusUpdate)
        } else if let artifactUpdate = try container.decodeIfPresent(TaskArtifactUpdateEvent.self, forKey: .artifactUpdate) {
            self = .artifactUpdate(artifactUpdate)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .task,
                in: container,
                debugDescription: "StreamResponse must contain exactly one of: task, message, statusUpdate, artifactUpdate"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .task(let task):
            try container.encode(task, forKey: .task)
        case .message(let message):
            try container.encode(message, forKey: .message)
        case .statusUpdate(let event):
            try container.encode(event, forKey: .statusUpdate)
        case .artifactUpdate(let event):
            try container.encode(event, forKey: .artifactUpdate)
        }
    }
}

// MARK: - StreamResponse Convenience

extension StreamResponse {
    /// Returns the task if this response contains one.
    public var task: A2ATask? {
        if case .task(let task) = self { return task }
        return nil
    }

    /// Returns the message if this response contains one.
    public var message: Message? {
        if case .message(let message) = self { return message }
        return nil
    }

    /// Returns the status update event if this response contains one.
    public var statusUpdate: TaskStatusUpdateEvent? {
        if case .statusUpdate(let event) = self { return event }
        return nil
    }

    /// Returns the artifact update event if this response contains one.
    public var artifactUpdate: TaskArtifactUpdateEvent? {
        if case .artifactUpdate(let event) = self { return event }
        return nil
    }
}

// MARK: - StreamingEvent (Legacy Compatibility)

/// Events that can be received during streaming operations.
public enum StreamingEvent: Sendable {
    /// A task status update event.
    case taskStatusUpdate(TaskStatusUpdateEvent)

    /// A task artifact update event.
    case taskArtifactUpdate(TaskArtifactUpdateEvent)

    /// A complete task object.
    case task(A2ATask)

    /// A message response.
    case message(Message)

    /// Creates a StreamingEvent from a StreamResponse.
    public init(from response: StreamResponse) {
        switch response {
        case .task(let task):
            self = .task(task)
        case .message(let message):
            self = .message(message)
        case .statusUpdate(let event):
            self = .taskStatusUpdate(event)
        case .artifactUpdate(let event):
            self = .taskArtifactUpdate(event)
        }
    }
}

// MARK: - TaskStatusUpdateEvent

/// Event indicating a change in task status.
public struct TaskStatusUpdateEvent: Codable, Sendable, Equatable {
    /// The task ID this event relates to.
    public let taskId: String

    /// The context ID (required per spec).
    public let contextId: String

    /// The updated status.
    public let status: TaskStatus

    /// If true, this is the final event in the stream.
    public let `final`: Bool?

    /// Optional metadata.
    public let metadata: [String: AnyCodable]?

    public init(
        taskId: String,
        contextId: String,
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
        case kind
        case taskId
        case contextId
        case status
        case `final`
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let _ = try container.decodeIfPresent(String.self, forKey: .kind)
        self.taskId = try container.decode(String.self, forKey: .taskId)
        self.contextId = try container.decode(String.self, forKey: .contextId)
        self.status = try container.decode(TaskStatus.self, forKey: .status)
        self.final = try container.decodeIfPresent(Bool.self, forKey: .final)
        self.metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("status-update", forKey: .kind)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(contextId, forKey: .contextId)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(self.final, forKey: .final)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

// MARK: - TaskArtifactUpdateEvent

/// Event indicating a new or updated artifact.
public struct TaskArtifactUpdateEvent: Codable, Sendable, Equatable {
    /// The task ID this event relates to.
    public let taskId: String

    /// The context ID (required per spec).
    public let contextId: String

    /// The artifact being added or updated.
    public let artifact: Artifact

    /// If true, append this artifact's content to a previously sent artifact with the same ID.
    public let append: Bool?

    /// If true, this is the final chunk of the artifact.
    public let lastChunk: Bool?

    /// Optional metadata.
    public let metadata: [String: AnyCodable]?

    public init(
        taskId: String,
        contextId: String,
        artifact: Artifact,
        append: Bool? = nil,
        lastChunk: Bool? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.taskId = taskId
        self.contextId = contextId
        self.artifact = artifact
        self.append = append
        self.lastChunk = lastChunk
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case taskId
        case contextId
        case artifact
        case append
        case lastChunk
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let _ = try container.decodeIfPresent(String.self, forKey: .kind)
        self.taskId = try container.decode(String.self, forKey: .taskId)
        self.contextId = try container.decode(String.self, forKey: .contextId)
        self.artifact = try container.decode(Artifact.self, forKey: .artifact)
        self.append = try container.decodeIfPresent(Bool.self, forKey: .append)
        self.lastChunk = try container.decodeIfPresent(Bool.self, forKey: .lastChunk)
        self.metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("artifact-update", forKey: .kind)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(contextId, forKey: .contextId)
        try container.encode(artifact, forKey: .artifact)
        try container.encodeIfPresent(append, forKey: .append)
        try container.encodeIfPresent(lastChunk, forKey: .lastChunk)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

// MARK: - StreamingEvent Extensions

extension StreamingEvent {
    /// The task ID associated with this event.
    public var taskId: String? {
        switch self {
        case .taskStatusUpdate(let event):
            return event.taskId
        case .taskArtifactUpdate(let event):
            return event.taskId
        case .task(let task):
            return task.id
        case .message(let message):
            return message.taskId
        }
    }

    /// The context ID associated with this event.
    public var contextId: String? {
        switch self {
        case .taskStatusUpdate(let event):
            return event.contextId
        case .taskArtifactUpdate(let event):
            return event.contextId
        case .task(let task):
            return task.contextId
        case .message(let message):
            return message.contextId
        }
    }

    /// Whether this is a status update event.
    public var isStatusUpdate: Bool {
        if case .taskStatusUpdate = self { return true }
        return false
    }

    /// Whether this is an artifact update event.
    public var isArtifactUpdate: Bool {
        if case .taskArtifactUpdate = self { return true }
        return false
    }

    /// Returns the status update event, if this is one.
    public var statusUpdateEvent: TaskStatusUpdateEvent? {
        if case .taskStatusUpdate(let event) = self { return event }
        return nil
    }

    /// Returns the artifact update event, if this is one.
    public var artifactUpdateEvent: TaskArtifactUpdateEvent? {
        if case .taskArtifactUpdate(let event) = self { return event }
        return nil
    }
}
