// ClientConfigurationTests.swift
// A2AClientTests
//
// Tests for A2A client configuration

import Testing
import Foundation
@testable import A2AClient

@Suite("Client Configuration Tests")
struct ClientConfigurationTests {

    // MARK: - Basic Configuration

    @Suite("Basic Configuration")
    struct BasicTests {
        @Test("Default configuration values")
        func defaultConfig() {
            let config = A2AClientConfiguration(
                baseURL: URL(string: "https://example.com")!
            )

            #expect(config.transportBinding == .httpREST)
            #expect(config.protocolVersion == "1.0")
            #expect(config.timeoutInterval == 60)
            #expect(config.extensions == nil)
            #expect(config.authenticationProvider == nil)
        }

        @Test("Custom configuration values")
        func customConfig() {
            let config = A2AClientConfiguration(
                baseURL: URL(string: "https://example.com")!,
                transportBinding: .jsonRPC,
                protocolVersion: "1.1",
                extensions: ["https://example.com/ext/v1"],
                timeoutInterval: 120
            )

            #expect(config.transportBinding == .jsonRPC)
            #expect(config.protocolVersion == "1.1")
            #expect(config.extensions?.first == "https://example.com/ext/v1")
            #expect(config.timeoutInterval == 120)
        }
    }

    // MARK: - Builder Pattern

    @Suite("Builder Pattern")
    struct BuilderTests {
        @Test("With different base URL")
        func withBaseURL() {
            let original = A2AClientConfiguration(
                baseURL: URL(string: "https://example.com")!
            )

            let modified = original.with(baseURL: URL(string: "https://other.com")!)

            #expect(modified.baseURL.absoluteString == "https://other.com")
            #expect(modified.transportBinding == original.transportBinding)
        }

        @Test("With different transport binding")
        func withTransportBinding() {
            let original = A2AClientConfiguration(
                baseURL: URL(string: "https://example.com")!
            )

            let modified = original.with(transportBinding: .jsonRPC)

            #expect(modified.transportBinding == .jsonRPC)
            #expect(modified.baseURL == original.baseURL)
        }

        @Test("With API key authentication")
        func withAPIKey() {
            let config = A2AClientConfiguration(
                baseURL: URL(string: "https://example.com")!
            ).withAPIKey("my-api-key")

            #expect(config.authenticationProvider != nil)
        }

        @Test("With bearer token authentication")
        func withBearerToken() {
            let config = A2AClientConfiguration(
                baseURL: URL(string: "https://example.com")!
            ).withBearerToken("my-token")

            #expect(config.authenticationProvider != nil)
        }

        @Test("With basic authentication")
        func withBasicAuth() {
            let config = A2AClientConfiguration(
                baseURL: URL(string: "https://example.com")!
            ).withBasicAuth(username: "user", password: "pass")

            #expect(config.authenticationProvider != nil)
        }
    }

    // MARK: - From Agent Card

    @Suite("From Agent Card")
    struct FromAgentCardTests {
        @Test("Configuration from agent card")
        func fromAgentCard() throws {
            let card = AgentCard(
                name: "Test Agent",
                description: "A test agent",
                url: "https://agent.example.com",
                version: "1.0.0",
                protocolVersion: "1.0"
            )

            let config = try A2AClientConfiguration.from(agentCard: card)

            #expect(config.baseURL.absoluteString == "https://agent.example.com")
            #expect(config.protocolVersion == "1.0")
        }

        @Test("Configuration from agent card with auth")
        func fromAgentCardWithAuth() throws {
            let card = AgentCard(
                name: "Test Agent",
                description: "A test agent",
                url: "https://agent.example.com",
                version: "1.0.0"
            )

            let auth = BearerAuthentication(token: "test-token")
            let config = try A2AClientConfiguration.from(
                agentCard: card,
                authenticationProvider: auth
            )

            #expect(config.authenticationProvider != nil)
        }

        @Test("Invalid URL throws error")
        func invalidURLThrows() {
            let card = AgentCard(
                name: "Test Agent",
                description: "A test agent",
                url: "",  // Invalid URL
                version: "1.0.0"
            )

            #expect(throws: A2AError.self) {
                _ = try A2AClientConfiguration.from(agentCard: card)
            }
        }
    }

    // MARK: - Transport Binding

    @Suite("Transport Binding")
    struct TransportBindingTests {
        @Test("HTTP REST raw value")
        func httpRESTRawValue() {
            #expect(TransportBinding.httpREST.rawValue == "http")
        }

        @Test("JSON-RPC raw value")
        func jsonRPCRawValue() {
            #expect(TransportBinding.jsonRPC.rawValue == "jsonrpc")
        }
    }
}
