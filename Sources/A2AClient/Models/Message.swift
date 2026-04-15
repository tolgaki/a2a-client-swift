// Message.swift
// A2AClient
//
// Agent2Agent Protocol - Message Definitions

import Foundation

/// Represents the role of a message sender in the A2A protocol.
///
/// Encoding uses v1.0 SCREAMING_SNAKE_CASE values (e.g., `ROLE_USER`).
/// Decoding accepts both v1.0 and v0.3 lowercase values (e.g., `"user"`).
public enum MessageRole: String, Sendable, Equatable {
    /// Unspecified role (default value).
    case unspecified = "ROLE_UNSPECIFIED"

    /// Message from the user/client.
    case user = "ROLE_USER"

    /// Message from the agent/server.
    case agent = "ROLE_AGENT"

    /// Mapping from v0.3 lowercase values.
    private static let v03Mapping: [String: MessageRole] = [
        "unspecified": .unspecified,
        "user": .user,
        "agent": .agent,
    ]
}

extension MessageRole: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let role = MessageRole(rawValue: value) {
            self = role
        } else if let role = MessageRole.v03Mapping[value] {
            self = role
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown MessageRole value: \(value)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let version = encoder.userInfo[a2aProtocolVersionKey] as? String,
           version.hasPrefix("0.") {
            let v03Value = Self.v10ToV03[self] ?? rawValue
            try container.encode(v03Value)
        } else {
            try container.encode(rawValue)
        }
    }

    /// Mapping from MessageRole cases to v0.3 lowercase values.
    private static let v10ToV03: [MessageRole: String] = [
        .unspecified: "unspecified",
        .user: "user",
        .agent: "agent",
    ]
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
        case kind
        case messageId
        case role
        case parts
        case contextId
        case taskId
        case referenceTaskIds
        case metadata
        case extensions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Read kind discriminator if present (optional for backwards compatibility)
        let _ = try container.decodeIfPresent(String.self, forKey: .kind)

        self.messageId = try container.decode(String.self, forKey: .messageId)
        self.role = try container.decode(MessageRole.self, forKey: .role)
        self.parts = try container.decode([Part].self, forKey: .parts)
        self.contextId = try container.decodeIfPresent(String.self, forKey: .contextId)
        self.taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
        self.referenceTaskIds = try container.decodeIfPresent([String].self, forKey: .referenceTaskIds)
        self.metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        self.extensions = try container.decodeIfPresent([String].self, forKey: .extensions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode("message", forKey: .kind)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(role, forKey: .role)
        try container.encode(parts, forKey: .parts)
        try container.encodeIfPresent(contextId, forKey: .contextId)
        try container.encodeIfPresent(taskId, forKey: .taskId)
        try container.encodeIfPresent(referenceTaskIds, forKey: .referenceTaskIds)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(extensions, forKey: .extensions)
    }
}

// MARK: - MessageSendConfiguration

/// Configuration for sending a message.
public struct MessageSendConfiguration: Codable, Sendable, Equatable {
    /// Optional accepted output modes (media types).
    public let acceptedOutputModes: [String]?

    /// Optional push notification config for task updates.
    public let taskPushNotificationConfig: TaskPushNotificationConfig?

    /// Maximum number of most recent messages from task history to retrieve.
    /// - nil: No limit imposed by client
    /// - 0: Request no history
    /// - >0: Return at most this many recent messages
    public let historyLength: Int?

    /// If `true`, the operation returns immediately after creating the task,
    /// even if processing is still in progress.
    /// If `false` (default), the operation waits until the task reaches a
    /// terminal or interrupted state before returning.
    public let returnImmediately: Bool?

    public init(
        acceptedOutputModes: [String]? = nil,
        taskPushNotificationConfig: TaskPushNotificationConfig? = nil,
        historyLength: Int? = nil,
        returnImmediately: Bool? = nil
    ) {
        self.acceptedOutputModes = acceptedOutputModes
        self.taskPushNotificationConfig = taskPushNotificationConfig
        self.historyLength = historyLength
        self.returnImmediately = returnImmediately
    }

    private enum CodingKeys: String, CodingKey {
        case acceptedOutputModes
        case taskPushNotificationConfig
        case historyLength
        case returnImmediately
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
