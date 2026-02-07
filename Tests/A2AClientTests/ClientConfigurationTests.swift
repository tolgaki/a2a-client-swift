// ClientConfigurationTests.swift
// A2AClientTests
//
// Tests for A2A client configuration

import XCTest
import Foundation
@testable import A2AClient

final class ClientConfigurationTests: XCTestCase {

    // MARK: - Basic Configuration

    func testBasicConfig_DefaultConfigurationValues() {
        let config = A2AClientConfiguration(
            baseURL: URL(string: "https://example.com")!
        )

        XCTAssertEqual(config.transportBinding, .httpREST)
        XCTAssertEqual(config.protocolVersion, "1.0")
        XCTAssertEqual(config.timeoutInterval, 60)
        XCTAssertNil(config.extensions)
        XCTAssertNil(config.authenticationProvider)
    }

    func testBasicConfig_CustomConfigurationValues() {
        let config = A2AClientConfiguration(
            baseURL: URL(string: "https://example.com")!,
            transportBinding: .jsonRPC,
            protocolVersion: "1.1",
            extensions: ["https://example.com/ext/v1"],
            timeoutInterval: 120
        )

        XCTAssertEqual(config.transportBinding, .jsonRPC)
        XCTAssertEqual(config.protocolVersion, "1.1")
        XCTAssertEqual(config.extensions?.first, "https://example.com/ext/v1")
        XCTAssertEqual(config.timeoutInterval, 120)
    }

    // MARK: - Builder Pattern

    func testBuilder_WithDifferentBaseURL() {
        let original = A2AClientConfiguration(
            baseURL: URL(string: "https://example.com")!
        )

        let modified = original.with(baseURL: URL(string: "https://other.com")!)

        XCTAssertEqual(modified.baseURL.absoluteString, "https://other.com")
        XCTAssertEqual(modified.transportBinding, original.transportBinding)
    }

    func testBuilder_WithDifferentTransportBinding() {
        let original = A2AClientConfiguration(
            baseURL: URL(string: "https://example.com")!
        )

        let modified = original.with(transportBinding: .jsonRPC)

        XCTAssertEqual(modified.transportBinding, .jsonRPC)
        XCTAssertEqual(modified.baseURL, original.baseURL)
    }

    func testBuilder_WithAPIKeyAuthentication() {
        let config = A2AClientConfiguration(
            baseURL: URL(string: "https://example.com")!
        ).withAPIKey("my-api-key")

        XCTAssertNotNil(config.authenticationProvider)
    }

    func testBuilder_WithBearerTokenAuthentication() {
        let config = A2AClientConfiguration(
            baseURL: URL(string: "https://example.com")!
        ).withBearerToken("my-token")

        XCTAssertNotNil(config.authenticationProvider)
    }

    func testBuilder_WithBasicAuthentication() {
        let config = A2AClientConfiguration(
            baseURL: URL(string: "https://example.com")!
        ).withBasicAuth(username: "user", password: "pass")

        XCTAssertNotNil(config.authenticationProvider)
    }

    // MARK: - From Agent Card

    func testFromAgentCard_ConfigurationFromAgentCard() throws {
        let card = AgentCard(
            name: "Test Agent",
            description: "A test agent",
            supportedInterfaces: [
                AgentInterface(url: "https://agent.example.com", protocolBinding: "HTTP+JSON", protocolVersion: "1.0")
            ],
            version: "1.0.0"
        )

        let config = try A2AClientConfiguration.from(agentCard: card)

        XCTAssertEqual(config.baseURL.absoluteString, "https://agent.example.com")
        XCTAssertEqual(config.protocolVersion, "1.0")
    }

    func testFromAgentCard_ConfigurationFromAgentCardWithAuth() throws {
        let card = AgentCard(
            name: "Test Agent",
            description: "A test agent",
            supportedInterfaces: [
                AgentInterface(url: "https://agent.example.com", protocolBinding: "HTTP+JSON", protocolVersion: "1.0")
            ],
            version: "1.0.0"
        )

        let auth = BearerAuthentication(token: "test-token")
        let config = try A2AClientConfiguration.from(
            agentCard: card,
            authenticationProvider: auth
        )

        XCTAssertNotNil(config.authenticationProvider)
    }

    func testFromAgentCard_InvalidURLThrowsError() {
        let card = AgentCard(
            name: "Test Agent",
            description: "A test agent",
            supportedInterfaces: [
                AgentInterface(url: "", protocolBinding: "HTTP+JSON", protocolVersion: "1.0")  // Invalid URL
            ],
            version: "1.0.0"
        )

        XCTAssertThrowsError(try A2AClientConfiguration.from(agentCard: card)) { error in
            XCTAssertTrue(error is A2AError)
        }
    }

    // MARK: - Transport Binding

    func testTransportBinding_HTTPRESTRawValue() {
        XCTAssertEqual(TransportBinding.httpREST.rawValue, "HTTP+JSON")
    }

    func testTransportBinding_JSONRPCRawValue() {
        XCTAssertEqual(TransportBinding.jsonRPC.rawValue, "JSONRPC")
    }
}
