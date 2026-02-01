// A2AClientConfiguration.swift
// A2AClient
//
// Agent2Agent Protocol - Client Configuration

import Foundation

/// Configuration for an A2A client.
public struct A2AClientConfiguration: Sendable {
    /// The base URL of the A2A agent.
    public let baseURL: URL

    /// The transport binding to use.
    public let transportBinding: TransportBinding

    /// The A2A protocol version to use.
    public let protocolVersion: String

    /// Optional tenant identifier for multi-tenant agents.
    public let tenant: String?

    /// Extensions to request from the agent.
    public let extensions: [String]?

    /// URL session configuration.
    public let sessionConfiguration: URLSessionConfiguration

    /// Request timeout interval.
    public let timeoutInterval: TimeInterval

    /// Authentication provider for requests.
    public let authenticationProvider: (any AuthenticationProvider)?

    public init(
        baseURL: URL,
        transportBinding: TransportBinding = .httpREST,
        protocolVersion: String = "1.0",
        tenant: String? = nil,
        extensions: [String]? = nil,
        sessionConfiguration: URLSessionConfiguration = .default,
        timeoutInterval: TimeInterval = 60,
        authenticationProvider: (any AuthenticationProvider)? = nil
    ) {
        self.baseURL = baseURL
        self.transportBinding = transportBinding
        self.protocolVersion = protocolVersion
        self.tenant = tenant
        self.extensions = extensions
        self.sessionConfiguration = sessionConfiguration
        self.timeoutInterval = timeoutInterval
        self.authenticationProvider = authenticationProvider
    }

    /// Creates a configuration from an agent card.
    public static func from(
        agentCard: AgentCard,
        authenticationProvider: (any AuthenticationProvider)? = nil
    ) throws -> A2AClientConfiguration {
        // Use the first (preferred) interface
        guard let interface = agentCard.supportedInterfaces.first else {
            throw A2AError.invalidRequest(message: "Agent card has no supported interfaces")
        }

        guard let baseURL = URL(string: interface.url) else {
            throw A2AError.invalidRequest(message: "Invalid agent URL: \(interface.url)")
        }

        // Map protocol binding string to enum
        let transportBinding: TransportBinding
        switch interface.protocolBinding.uppercased() {
        case "JSONRPC":
            transportBinding = .jsonRPC
        case "HTTP+JSON", "HTTPJSON":
            transportBinding = .httpREST
        default:
            transportBinding = .httpREST
        }

        return A2AClientConfiguration(
            baseURL: baseURL,
            transportBinding: transportBinding,
            protocolVersion: interface.protocolVersion,
            tenant: interface.tenant,
            authenticationProvider: authenticationProvider
        )
    }
}

/// Transport binding options.
public enum TransportBinding: String, Sendable {
    /// HTTP/REST transport binding (HTTP+JSON).
    case httpREST = "HTTP+JSON"

    /// JSON-RPC 2.0 transport binding.
    case jsonRPC = "JSONRPC"
}

// MARK: - Builder Pattern

extension A2AClientConfiguration {
    /// Creates a new configuration with a different base URL.
    public func with(baseURL: URL) -> A2AClientConfiguration {
        A2AClientConfiguration(
            baseURL: baseURL,
            transportBinding: transportBinding,
            protocolVersion: protocolVersion,
            tenant: tenant,
            extensions: extensions,
            sessionConfiguration: sessionConfiguration,
            timeoutInterval: timeoutInterval,
            authenticationProvider: authenticationProvider
        )
    }

    /// Creates a new configuration with a different transport binding.
    public func with(transportBinding: TransportBinding) -> A2AClientConfiguration {
        A2AClientConfiguration(
            baseURL: baseURL,
            transportBinding: transportBinding,
            protocolVersion: protocolVersion,
            tenant: tenant,
            extensions: extensions,
            sessionConfiguration: sessionConfiguration,
            timeoutInterval: timeoutInterval,
            authenticationProvider: authenticationProvider
        )
    }

    /// Creates a new configuration with a tenant identifier.
    public func with(tenant: String?) -> A2AClientConfiguration {
        A2AClientConfiguration(
            baseURL: baseURL,
            transportBinding: transportBinding,
            protocolVersion: protocolVersion,
            tenant: tenant,
            extensions: extensions,
            sessionConfiguration: sessionConfiguration,
            timeoutInterval: timeoutInterval,
            authenticationProvider: authenticationProvider
        )
    }

    /// Creates a new configuration with a different authentication provider.
    public func with(authenticationProvider: (any AuthenticationProvider)?) -> A2AClientConfiguration {
        A2AClientConfiguration(
            baseURL: baseURL,
            transportBinding: transportBinding,
            protocolVersion: protocolVersion,
            tenant: tenant,
            extensions: extensions,
            sessionConfiguration: sessionConfiguration,
            timeoutInterval: timeoutInterval,
            authenticationProvider: authenticationProvider
        )
    }

    /// Creates a new configuration with API key authentication.
    public func withAPIKey(_ key: String, name: String = "X-API-Key", location: APIKeyLocation = .header) -> A2AClientConfiguration {
        with(authenticationProvider: APIKeyAuthentication(key: key, name: name, location: location))
    }

    /// Creates a new configuration with bearer token authentication.
    public func withBearerToken(_ token: String) -> A2AClientConfiguration {
        with(authenticationProvider: BearerAuthentication(token: token))
    }

    /// Creates a new configuration with basic authentication.
    public func withBasicAuth(username: String, password: String) -> A2AClientConfiguration {
        with(authenticationProvider: BasicAuthentication(username: username, password: password))
    }
}
