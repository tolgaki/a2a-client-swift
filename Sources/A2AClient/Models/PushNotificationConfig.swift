// PushNotificationConfig.swift
// A2AClient
//
// Agent2Agent Protocol - Push Notification Configuration
// Spec: https://a2a-protocol.org/latest/specification/#431-pushnotificationconfig

import Foundation

// MARK: - AuthenticationInfo

/// Defines authentication details for push notifications.
/// Follows HTTP Authentication Scheme from the IANA registry.
public struct AuthenticationInfo: Codable, Sendable, Equatable {
    /// HTTP Authentication Scheme (e.g., "Bearer", "Basic", "Digest").
    /// Scheme names are case-insensitive per RFC 9110 Section 11.1.
    public let scheme: String

    /// Push notification credentials. Format depends on the scheme.
    public let credentials: String?

    public init(scheme: String, credentials: String? = nil) {
        self.scheme = scheme
        self.credentials = credentials
    }

    /// Creates a Bearer token authentication.
    public static func bearer(_ token: String) -> AuthenticationInfo {
        AuthenticationInfo(scheme: "Bearer", credentials: token)
    }

    /// Creates a Basic authentication.
    public static func basic(username: String, password: String) -> AuthenticationInfo {
        let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
        return AuthenticationInfo(scheme: "Basic", credentials: credentials)
    }
}

// MARK: - PushNotificationConfig

/// Configuration for push notifications for task updates.
///
/// Push notifications allow agents to deliver task updates via HTTP webhooks
/// instead of requiring clients to poll or maintain streaming connections.
public struct PushNotificationConfig: Codable, Sendable, Equatable, Identifiable {
    /// Optional unique identifier for this push notification configuration.
    public let id: String?

    /// The webhook URL where notifications will be sent (required).
    public let url: String

    /// Optional token unique for this task/session.
    public let token: String?

    /// Authentication information required to send the notification.
    public let authentication: AuthenticationInfo?

    public init(
        id: String? = nil,
        url: String,
        token: String? = nil,
        authentication: AuthenticationInfo? = nil
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

// MARK: - TaskPushNotificationConfig

/// A container associating a push notification configuration with a specific task.
public struct TaskPushNotificationConfig: Codable, Sendable, Equatable, Identifiable {
    /// Optional tenant identifier.
    public let tenant: String?

    /// The ID of this configuration (required).
    public let id: String

    /// The task ID this configuration is associated with.
    public let taskId: String

    /// The push notification configuration details.
    public let pushNotificationConfig: PushNotificationConfig

    public init(
        tenant: String? = nil,
        id: String,
        taskId: String,
        pushNotificationConfig: PushNotificationConfig
    ) {
        self.tenant = tenant
        self.id = id
        self.taskId = taskId
        self.pushNotificationConfig = pushNotificationConfig
    }

    private enum CodingKeys: String, CodingKey {
        case tenant
        case id
        case taskId = "task_id"
        case pushNotificationConfig = "push_notification_config"
    }
}

// MARK: - Request/Response Types

/// Parameters for creating a push notification configuration.
public struct CreatePushNotificationConfigParams: Codable, Sendable, Equatable {
    /// Optional tenant identifier.
    public let tenant: String?

    /// The task ID to configure notifications for.
    public let taskId: String

    /// The push notification configuration.
    public let config: PushNotificationConfig

    public init(tenant: String? = nil, taskId: String, config: PushNotificationConfig) {
        self.tenant = tenant
        self.taskId = taskId
        self.config = config
    }

    private enum CodingKeys: String, CodingKey {
        case tenant
        case taskId = "task_id"
        case config
    }
}

/// Parameters for getting a push notification configuration.
public struct GetPushNotificationConfigParams: Codable, Sendable, Equatable {
    /// Optional tenant identifier.
    public let tenant: String?

    /// The task ID.
    public let taskId: String

    /// The configuration ID.
    public let id: String

    public init(tenant: String? = nil, taskId: String, id: String) {
        self.tenant = tenant
        self.taskId = taskId
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case tenant
        case taskId = "task_id"
        case id
    }
}

/// Parameters for listing push notification configurations.
public struct ListPushNotificationConfigsParams: Codable, Sendable, Equatable {
    /// Optional tenant identifier.
    public let tenant: String?

    /// The task ID.
    public let taskId: String

    /// Maximum number of configurations to return.
    public let pageSize: Int?

    /// Token for pagination.
    public let pageToken: String?

    public init(tenant: String? = nil, taskId: String, pageSize: Int? = nil, pageToken: String? = nil) {
        self.tenant = tenant
        self.taskId = taskId
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    private enum CodingKeys: String, CodingKey {
        case tenant
        case taskId = "task_id"
        case pageSize = "page_size"
        case pageToken = "page_token"
    }
}

/// Response for listing push notification configurations.
public struct ListPushNotificationConfigsResponse: Codable, Sendable, Equatable {
    /// The list of push notification configurations.
    public let configs: [TaskPushNotificationConfig]?

    /// Token for retrieving the next page.
    public let nextPageToken: String?

    public init(configs: [TaskPushNotificationConfig]? = nil, nextPageToken: String? = nil) {
        self.configs = configs
        self.nextPageToken = nextPageToken
    }

    private enum CodingKeys: String, CodingKey {
        case configs
        case nextPageToken = "next_page_token"
    }
}

/// Parameters for deleting a push notification configuration.
public struct DeletePushNotificationConfigParams: Codable, Sendable, Equatable {
    /// Optional tenant identifier.
    public let tenant: String?

    /// The task ID.
    public let taskId: String

    /// The configuration ID to delete.
    public let id: String

    public init(tenant: String? = nil, taskId: String, id: String) {
        self.tenant = tenant
        self.taskId = taskId
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case tenant
        case taskId = "task_id"
        case id
    }
}

// MARK: - Legacy Type Aliases

/// Legacy type alias for backward compatibility.
@available(*, deprecated, renamed: "CreatePushNotificationConfigParams")
public typealias SetPushNotificationConfigParams = CreatePushNotificationConfigParams

/// Legacy authentication type for backward compatibility.
@available(*, deprecated, renamed: "AuthenticationInfo")
public typealias PushNotificationAuthentication = AuthenticationInfo
