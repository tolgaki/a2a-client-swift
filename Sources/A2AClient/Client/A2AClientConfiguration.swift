// A2AClientConfiguration.swift
// A2AClient
//
// Agent2Agent Protocol - Client Configuration

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

    /// JSON key casing convention for encoding/decoding.
    public let jsonKeyCasing: JSONKeyCasing

    public init(
        baseURL: URL,
        transportBinding: TransportBinding = .httpREST,
        protocolVersion: String = "1.0",
        tenant: String? = nil,
        extensions: [String]? = nil,
        sessionConfiguration: URLSessionConfiguration = .default,
        timeoutInterval: TimeInterval = 60,
        authenticationProvider: (any AuthenticationProvider)? = nil,
        jsonKeyCasing: JSONKeyCasing = .camelCase
    ) {
        self.baseURL = baseURL
        self.transportBinding = transportBinding
        self.protocolVersion = protocolVersion
        self.tenant = tenant
        self.extensions = extensions
        self.sessionConfiguration = sessionConfiguration
        self.timeoutInterval = timeoutInterval
        self.authenticationProvider = authenticationProvider
        self.jsonKeyCasing = jsonKeyCasing
    }

    /// Creates a configuration from an agent card.
    public static func from(
        agentCard: AgentCard,
        authenticationProvider: (any AuthenticationProvider)? = nil,
        jsonKeyCasing: JSONKeyCasing = .camelCase
    ) throws -> A2AClientConfiguration {
        // Spec §8.3.2: walk supportedInterfaces in order and select the first
        // interface whose protocol binding this client can speak. Earlier
        // entries are preferred; bindings we don't implement (e.g. GRPC)
        // are skipped rather than silently mis-mapped.
        func binding(for interface: AgentInterface) -> TransportBinding? {
            switch interface.protocolBinding.uppercased() {
            case "JSONRPC":
                return .jsonRPC
            case "HTTP+JSON", "HTTPJSON":
                return .httpREST
            default:
                return nil
            }
        }

        guard !agentCard.supportedInterfaces.isEmpty else {
            throw A2AError.invalidRequest(message: "Agent card has no supported interfaces")
        }

        var selected: (interface: AgentInterface, binding: TransportBinding)?
        for candidate in agentCard.supportedInterfaces {
            if let transportBinding = binding(for: candidate) {
                selected = (candidate, transportBinding)
                break
            }
        }
        guard let (interface, transportBinding) = selected else {
            let offered = agentCard.supportedInterfaces.map(\.protocolBinding).joined(separator: ", ")
            throw A2AError.invalidRequest(
                message: "Agent card has no interface with a supported protocol binding. Offered: [\(offered)]; supported: [JSONRPC, HTTP+JSON]"
            )
        }

        guard let baseURL = URL(string: interface.url) else {
            throw A2AError.invalidRequest(message: "Invalid agent URL: \(interface.url)")
        }

        // The HTTP+JSON (REST) binding was introduced in v1.0; v0.3 agents
        // only expose JSON-RPC. Reject the mismatch up-front with a clear
        // message rather than letting every REST call fail with HTTP 404.
        if interface.protocolVersion.hasPrefix("0.") && transportBinding == .httpREST {
            throw A2AError.versionNotSupported(
                version: interface.protocolVersion,
                supportedVersions: ["1.0"],
                message: "v\(interface.protocolVersion) agents do not support the HTTP+JSON (REST) binding. Use JSON-RPC transport, or connect to a v1.0 agent."
            )
        }

        return A2AClientConfiguration(
            baseURL: baseURL,
            transportBinding: transportBinding,
            protocolVersion: interface.protocolVersion,
            tenant: interface.tenant,
            authenticationProvider: authenticationProvider,
            jsonKeyCasing: jsonKeyCasing
        )
    }
}

/// JSON key casing options for encoding/decoding.
///
/// The A2A spec examples use snake_case (e.g., `message_id`, `context_id`),
/// while some implementations like the Graph RP use camelCase (e.g., `messageId`, `contextId`).
/// This option controls which convention the library uses for JSON serialization.
public enum JSONKeyCasing: Sendable {
    /// Use camelCase keys (e.g., `messageId`, `contextId`). This is the default.
    case camelCase

    /// Use snake_case keys (e.g., `message_id`, `context_id`).
    /// Set this when communicating with servers that follow the A2A spec's snake_case convention.
    case snakeCase
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
            authenticationProvider: authenticationProvider,
            jsonKeyCasing: jsonKeyCasing
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
            authenticationProvider: authenticationProvider,
            jsonKeyCasing: jsonKeyCasing
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
            authenticationProvider: authenticationProvider,
            jsonKeyCasing: jsonKeyCasing
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
            authenticationProvider: authenticationProvider,
            jsonKeyCasing: jsonKeyCasing
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
