// A2AClientModule.swift
// A2AClient
//
// Agent2Agent Protocol Swift Client Library
//
// A fully conformant client implementation of the A2A (Agent2Agent) Protocol
// for Swift/iOS/macOS applications.

import Foundation

// MARK: - Public API Exports

// Core Client - The main client class is named A2AClient in Client/A2AClient.swift
public typealias Client = A2AClient
public typealias ClientConfiguration = A2AClientConfiguration

// Note: A2ATask is used directly instead of a Task typealias
// to avoid shadowing Swift.Task from the concurrency module.

// Re-exports are handled by Swift's module system - all public types
// in the module are automatically exported.

// MARK: - Version Information

/// A2A Client library version information.
public enum A2AClientVersion {
    /// The library version.
    public static let version = "1.0.0"

    /// The A2A protocol version supported.
    public static let protocolVersion = "1.0"

    /// The supported transport bindings.
    public static let supportedTransports: [TransportBinding] = [.httpREST, .jsonRPC]
}

// MARK: - Quick Start

/// Quick start helpers for common A2A operations.
public enum A2A {
    /// Creates a client for the given agent URL.
    ///
    /// - Parameter url: The agent's base URL.
    /// - Returns: A configured A2A client.
    public static func client(url: URL) -> A2AClient {
        A2AClient(baseURL: url)
    }

    /// Creates a client for the given agent URL string.
    ///
    /// - Parameter urlString: The agent's base URL string.
    /// - Returns: A configured A2A client, or nil if the URL is invalid.
    public static func client(urlString: String) -> A2AClient? {
        guard let url = URL(string: urlString) else { return nil }
        return A2AClient(baseURL: url)
    }

    /// Discovers an agent and creates a client.
    ///
    /// - Parameter domain: The domain to discover the agent from.
    /// - Returns: A tuple containing the agent card and a configured client.
    public static func discover(domain: String) async throws -> (agentCard: AgentCard, client: A2AClient) {
        let agentCard = try await A2AClient.discoverAgent(domain: domain)
        let client = try A2AClient(agentCard: agentCard)
        return (agentCard, client)
    }

    /// Creates a simple text message.
    ///
    /// - Parameters:
    ///   - text: The message text.
    ///   - contextId: Optional context ID.
    /// - Returns: A user message.
    public static func message(_ text: String, contextId: String? = nil) -> Message {
        Message.user(text, contextId: contextId)
    }
}

// MARK: - Convenience Functions

/// Sends a message to an agent at the given URL.
///
/// - Note: This creates a new `A2AClient` (and `URLSession`) per call.
///   For repeated calls, create and reuse a single `A2AClient` instance instead.
///
/// - Parameters:
///   - message: The message to send.
///   - url: The agent's URL.
/// - Returns: The response.
public func sendMessage(_ message: Message, to url: URL) async throws -> SendMessageResponse {
    let client = A2AClient(baseURL: url)
    return try await client.sendMessage(message)
}

/// Sends a text message to an agent at the given URL.
///
/// - Note: This creates a new `A2AClient` (and `URLSession`) per call.
///   For repeated calls, create and reuse a single `A2AClient` instance instead.
///
/// - Parameters:
///   - text: The text to send.
///   - url: The agent's URL.
/// - Returns: The response.
public func sendMessage(_ text: String, to url: URL) async throws -> SendMessageResponse {
    let client = A2AClient(baseURL: url)
    return try await client.sendMessage(text)
}
