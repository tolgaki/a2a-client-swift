// Message.swift
// A2AClient
//
// Agent2Agent Protocol - Message Definitions

import Foundation

/// Represents the role of a message sender in the A2A protocol.
public enum MessageRole: String, Codable, Sendable, Equatable {
    /// Unspecified role (default value).
    case unspecified = "unspecified"

    /// Message from the user/client.
    case user = "user"

    /// Message from the agent/server.
    case agent = "agent"
}

/// Represents a single communication turn between client and agent.
///
/// Messages are the primary mechanism for exchanging information in the A2A protocol.
/// Each message contains one or more parts representing different content types.
public struct Message: Codable, Sendable, Equatable {
    /// Unique identifier for this message.
    public let messageId: String

    /// The role of the message sender.
    public let role: MessageRole

    /// Content parts comprising this message.
    public let parts: [Part]

    /// Optional context identifier for grouping related interactions.
    public let contextId: String?

    /// Optional task identifier this message is associated with.
    public let taskId: String?

    /// Optional references to related task IDs for context.
    public let referenceTaskIds: [String]?

    /// Optional metadata associated with this message.
    public let metadata: [String: AnyCodable]?

    /// Optional extension URIs for this message.
    public let extensions: [String]?

    public init(
        messageId: String = UUID().uuidString,
        role: MessageRole,
        parts: [Part],
        contextId: String? = nil,
        taskId: String? = nil,
        referenceTaskIds: [String]? = nil,
        metadata: [String: AnyCodable]? = nil,
        extensions: [String]? = nil
    ) {
        self.messageId = messageId
        self.role = role
        self.parts = parts
        self.contextId = contextId
        self.taskId = taskId
        self.referenceTaskIds = referenceTaskIds
        self.metadata = metadata
        self.extensions = extensions
    }

    private enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case role
        case parts
        case contextId = "context_id"
        case taskId = "task_id"
        case referenceTaskIds = "reference_task_ids"
        case metadata
        case extensions
    }
}

// MARK: - MessageSendConfiguration

/// Configuration for sending a message.
public struct MessageSendConfiguration: Codable, Sendable, Equatable {
    /// Optional accepted output modes (media types).
    public let acceptedOutputModes: [String]?

    /// Optional push notification config for task updates.
    public let pushNotificationConfig: PushNotificationConfig?

    /// Maximum number of most recent messages from task history to retrieve.
    /// - nil: No limit imposed by client
    /// - 0: Request no history
    /// - >0: Return at most this many recent messages
    public let historyLength: Int?

    /// If true, wait until task reaches terminal/interrupted state before returning.
    public let blocking: Bool?

    public init(
        acceptedOutputModes: [String]? = nil,
        pushNotificationConfig: PushNotificationConfig? = nil,
        historyLength: Int? = nil,
        blocking: Bool? = nil
    ) {
        self.acceptedOutputModes = acceptedOutputModes
        self.pushNotificationConfig = pushNotificationConfig
        self.historyLength = historyLength
        self.blocking = blocking
    }

    private enum CodingKeys: String, CodingKey {
        case acceptedOutputModes = "accepted_output_modes"
        case pushNotificationConfig = "push_notification_config"
        case historyLength = "history_length"
        case blocking
    }
}

// MARK: - Convenience Initializers

extension Message {
    /// Creates a user message with text content.
    public static func user(_ text: String, contextId: String? = nil, taskId: String? = nil) -> Message {
        Message(
            role: .user,
            parts: [.text(text)],
            contextId: contextId,
            taskId: taskId
        )
    }

    /// Creates a user message with multiple parts.
    public static func user(parts: [Part], contextId: String? = nil, taskId: String? = nil) -> Message {
        Message(
            role: .user,
            parts: parts,
            contextId: contextId,
            taskId: taskId
        )
    }

    /// Creates an agent message with text content.
    public static func agent(_ text: String, contextId: String? = nil, taskId: String? = nil) -> Message {
        Message(
            role: .agent,
            parts: [.text(text)],
            contextId: contextId,
            taskId: taskId
        )
    }

    /// Creates an agent message with multiple parts.
    public static func agent(parts: [Part], contextId: String? = nil, taskId: String? = nil) -> Message {
        Message(
            role: .agent,
            parts: parts,
            contextId: contextId,
            taskId: taskId
        )
    }
}

// MARK: - Message Extensions

extension Message {
    /// Returns all text content from this message concatenated.
    public var textContent: String {
        parts.compactMap { $0.text }.joined(separator: "\n")
    }

    /// Returns all parts that contain text.
    public var textParts: [Part] {
        parts.filter { $0.isText }
    }

    /// Returns all parts that contain raw data or URL references (file-like content).
    public var fileParts: [Part] {
        parts.filter { $0.isRaw || $0.isURL }
    }

    /// Returns all parts that contain structured data.
    public var dataParts: [Part] {
        parts.filter { $0.isData }
    }
}
