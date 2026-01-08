// PushNotificationConfig.swift
// A2AClient
//
// Agent2Agent Protocol - Push Notification Configuration

import Foundation

/// Configuration for push notifications for task updates.
///
/// Push notifications allow agents to deliver task updates via HTTP webhooks
/// instead of requiring clients to poll or maintain streaming connections.
public struct PushNotificationConfig: Codable, Sendable, Equatable, Identifiable {
    /// Unique identifier for this push notification configuration.
    public let id: String

    /// The webhook URL where notifications will be sent.
    public let url: String

    /// Optional token for authenticating webhook requests.
    public let token: String?

    /// Optional authentication configuration for the webhook.
    public let authentication: PushNotificationAuthentication?

    public init(
        id: String = UUID().uuidString,
        url: String,
        token: String? = nil,
        authentication: PushNotificationAuthentication? = nil
    ) {
        self.id = id
        self.url = url
        self.token = token
        self.authentication = authentication
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case token
        case authentication
    }
}

// MARK: - PushNotificationAuthentication

/// Authentication configuration for push notification webhooks.
public struct PushNotificationAuthentication: Codable, Sendable, Equatable {
    /// The authentication schemes to use.
    public let schemes: [String]

    /// Credentials for authentication (scheme-specific).
    public let credentials: String?

    public init(schemes: [String], credentials: String? = nil) {
        self.schemes = schemes
        self.credentials = credentials
    }
}

// MARK: - TaskPushNotificationConfig

/// A push notification configuration associated with a specific task.
public struct TaskPushNotificationConfig: Codable, Sendable, Equatable {
    /// The task ID this configuration applies to.
    public let taskId: String

    /// The push notification configuration.
    public let pushNotificationConfig: PushNotificationConfig

    public init(taskId: String, pushNotificationConfig: PushNotificationConfig) {
        self.taskId = taskId
        self.pushNotificationConfig = pushNotificationConfig
    }

    private enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case pushNotificationConfig = "push_notification_config"
    }
}

// MARK: - Request/Response Types

/// Parameters for setting a push notification configuration.
public struct SetPushNotificationConfigParams: Codable, Sendable, Equatable {
    /// The task ID to configure notifications for.
    public let taskId: String

    /// The push notification configuration.
    public let pushNotificationConfig: PushNotificationConfig

    public init(taskId: String, pushNotificationConfig: PushNotificationConfig) {
        self.taskId = taskId
        self.pushNotificationConfig = pushNotificationConfig
    }

    private enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case pushNotificationConfig = "push_notification_config"
    }
}

/// Parameters for getting a push notification configuration.
public struct GetPushNotificationConfigParams: Codable, Sendable, Equatable {
    /// The task ID.
    public let taskId: String

    /// The configuration ID.
    public let id: String

    public init(taskId: String, id: String) {
        self.taskId = taskId
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case id
    }
}

/// Parameters for listing push notification configurations.
public struct ListPushNotificationConfigsParams: Codable, Sendable, Equatable {
    /// The task ID.
    public let taskId: String

    public init(taskId: String) {
        self.taskId = taskId
    }

    private enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
    }
}

/// Response for listing push notification configurations.
public struct ListPushNotificationConfigsResponse: Codable, Sendable, Equatable {
    /// The list of push notification configurations.
    public let configs: [PushNotificationConfig]

    public init(configs: [PushNotificationConfig]) {
        self.configs = configs
    }
}

/// Parameters for deleting a push notification configuration.
public struct DeletePushNotificationConfigParams: Codable, Sendable, Equatable {
    /// The task ID.
    public let taskId: String

    /// The configuration ID to delete.
    public let id: String

    public init(taskId: String, id: String) {
        self.taskId = taskId
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case id
    }
}
