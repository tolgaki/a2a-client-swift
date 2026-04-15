// SecuritySchemeTests.swift
// A2AClientTests
//
// Tests for A2A security scheme types

import XCTest
import Foundation
@testable import A2AClient

final class SecuritySchemeTests: XCTestCase {

    // MARK: - Factory Methods

    func testFactory_APIKeySchemeCreation() {
        let scheme = SecurityScheme.apiKey(
            name: "X-API-Key",
            in: .header,
            description: "API key authentication"
        )

        XCTAssertEqual(scheme.type, .apiKey)
        XCTAssertEqual(scheme.name, "X-API-Key")
        XCTAssertEqual(scheme.in, .header)
        XCTAssertEqual(scheme.description, "API key authentication")
    }

    func testFactory_HTTPBasicSchemeCreation() {
        let scheme = SecurityScheme.httpBasic(description: "Basic auth")

        XCTAssertEqual(scheme.type, .http)
        XCTAssertEqual(scheme.scheme, "basic")
    }

    func testFactory_HTTPBearerSchemeCreation() {
        let scheme = SecurityScheme.httpBearer(format: "JWT")

        XCTAssertEqual(scheme.type, .http)
        XCTAssertEqual(scheme.scheme, "bearer")
        XCTAssertEqual(scheme.bearerFormat, "JWT")
    }

    func testFactory_OAuth2ClientCredentialsSchemeCreation() {
        let scheme = SecurityScheme.oauth2ClientCredentials(
            tokenUrl: "https://auth.example.com/token",
            scopes: ["read": "Read access", "write": "Write access"]
        )

        XCTAssertEqual(scheme.type, .oauth2)
        XCTAssertEqual(scheme.flows?.clientCredentials?.tokenUrl, "https://auth.example.com/token")
        XCTAssertEqual(scheme.flows?.clientCredentials?.scopes?["read"], "Read access")
    }

    func testFactory_OAuth2AuthorizationCodeSchemeCreation() {
        let scheme = SecurityScheme.oauth2AuthorizationCode(
            authorizationUrl: "https://auth.example.com/authorize",
            tokenUrl: "https://auth.example.com/token",
            scopes: ["profile": "User profile"]
        )

        XCTAssertEqual(scheme.type, .oauth2)
        XCTAssertEqual(scheme.flows?.authorizationCode?.authorizationUrl, "https://auth.example.com/authorize")
        XCTAssertEqual(scheme.flows?.authorizationCode?.tokenUrl, "https://auth.example.com/token")
    }

    func testFactory_OpenIDConnectSchemeCreation() {
        let scheme = SecurityScheme.openIdConnect(
            discoveryUrl: "https://auth.example.com/.well-known/openid-configuration"
        )

        XCTAssertEqual(scheme.type, .openIdConnect)
        XCTAssertEqual(scheme.openIdConnectUrl, "https://auth.example.com/.well-known/openid-configuration")
    }

    func testFactory_MutualTLSSchemeCreation() {
        let scheme = SecurityScheme.mutualTLS(description: "Client certificate required")

        XCTAssertEqual(scheme.type, .mutualTLS)
        XCTAssertEqual(scheme.description, "Client certificate required")
    }

    // MARK: - Encoding/Decoding

    func testCoding_SecuritySchemeEncodingAndDecoding() throws {
        let scheme = SecurityScheme(
            type: .apiKey,
            description: "API Key auth",
            name: "Authorization",
            in: .header
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(scheme)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SecurityScheme.self, from: data)

        XCTAssertEqual(decoded.type, .apiKey)
        XCTAssertEqual(decoded.name, "Authorization")
        XCTAssertEqual(decoded.in, .header)
    }

    func testCoding_OAuthFlowsEncodingAndDecoding() throws {
        let flows = OAuthFlows(
            authorizationCode: OAuthFlow(
                authorizationUrl: "https://example.com/auth",
                tokenUrl: "https://example.com/token",
                scopes: ["read": "Read"]
            ),
            clientCredentials: OAuthFlow(
                tokenUrl: "https://example.com/token"
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(flows)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OAuthFlows.self, from: data)

        XCTAssertEqual(decoded.authorizationCode?.authorizationUrl, "https://example.com/auth")
        XCTAssertEqual(decoded.clientCredentials?.tokenUrl, "https://example.com/token")
    }

    // MARK: - API Key Location

    func testAPIKeyLocation_AllLocationsHaveCorrectRawValues() {
        XCTAssertEqual(APIKeyLocation.header.rawValue, "header")
        XCTAssertEqual(APIKeyLocation.query.rawValue, "query")
        XCTAssertEqual(APIKeyLocation.cookie.rawValue, "cookie")
    }
}
