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
    /// Optional accepted output modes.
    public let acceptedOutputModes: [String]?

    /// Optional history length limit.
    public let historyLength: Int?

    /// Optional push notification config.
    public let pushNotificationConfig: PushNotificationConfig?

    public init(
        acceptedOutputModes: [String]? = nil,
        historyLength: Int? = nil,
        pushNotificationConfig: PushNotificationConfig? = nil
    ) {
        self.acceptedOutputModes = acceptedOutputModes
        self.historyLength = historyLength
        self.pushNotificationConfig = pushNotificationConfig
    }

    private enum CodingKeys: String, CodingKey {
        case acceptedOutputModes = "accepted_output_modes"
        case historyLength = "history_length"
        case pushNotificationConfig = "push_notification_config"
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
        parts.compactMap { part in
            if case .text(let textPart) = part {
                return textPart.text
            }
            return nil
        }.joined(separator: "\n")
    }

    /// Returns all file parts from this message.
    public var fileParts: [FilePart] {
        parts.compactMap { part in
            if case .file(let filePart) = part {
                return filePart
            }
            return nil
        }
    }

    /// Returns all data parts from this message.
    public var dataParts: [DataPart] {
        parts.compactMap { part in
            if case .data(let dataPart) = part {
                return dataPart
            }
            return nil
        }
    }
}
