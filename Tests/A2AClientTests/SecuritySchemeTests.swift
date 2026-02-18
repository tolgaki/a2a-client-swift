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

    func testFactory_OAuth2AuthorizationCodeWithPKCE() {
        let scheme = SecurityScheme.oauth2AuthorizationCode(
            authorizationUrl: "https://auth.example.com/authorize",
            tokenUrl: "https://auth.example.com/token",
            scopes: ["profile": "User profile"],
            pkceRequired: true
        )

        XCTAssertEqual(scheme.type, .oauth2)
        XCTAssertEqual(scheme.flows?.authorizationCode?.pkceRequired, true)
    }

    func testFactory_OAuth2DeviceCodeSchemeCreation() {
        let scheme = SecurityScheme.oauth2DeviceCode(
            deviceAuthorizationUrl: "https://auth.example.com/device/authorize",
            tokenUrl: "https://auth.example.com/token",
            scopes: ["read": "Read access"]
        )

        XCTAssertEqual(scheme.type, .oauth2)
        XCTAssertEqual(scheme.flows?.deviceCode?.deviceAuthorizationUrl, "https://auth.example.com/device/authorize")
        XCTAssertEqual(scheme.flows?.deviceCode?.tokenUrl, "https://auth.example.com/token")
        XCTAssertEqual(scheme.flows?.deviceCode?.scopes?["read"], "Read access")
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

    // MARK: - OAuth2 Metadata URL

    func testOAuth2MetadataUrl_StoredCorrectly() {
        let scheme = SecurityScheme(
            type: .oauth2,
            flows: OAuthFlows(clientCredentials: OAuthFlow(tokenUrl: "https://example.com/token")),
            oauth2MetadataUrl: "https://example.com/.well-known/oauth-authorization-server"
        )

        XCTAssertEqual(scheme.oauth2MetadataUrl, "https://example.com/.well-known/oauth-authorization-server")
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

    func testCoding_SecuritySchemeJSONUsesSnakeCase() throws {
        let scheme = SecurityScheme.httpBearer(format: "JWT")

        let encoder = JSONEncoder()
        let data = try encoder.encode(scheme)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("bearer_format"))
        XCTAssertFalse(json.contains("bearerFormat"))
    }

    func testCoding_OpenIdConnectURLUsesSnakeCase() throws {
        let scheme = SecurityScheme.openIdConnect(
            discoveryUrl: "https://example.com/.well-known/openid-configuration"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(scheme)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("open_id_connect_url"))
        XCTAssertFalse(json.contains("openIdConnectUrl"))
    }

    func testCoding_OAuth2MetadataUrlUsesSnakeCase() throws {
        let scheme = SecurityScheme(
            type: .oauth2,
            flows: OAuthFlows(clientCredentials: OAuthFlow(tokenUrl: "https://example.com/token")),
            oauth2MetadataUrl: "https://example.com/.well-known/oauth"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(scheme)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("oauth2_metadata_url"))
        XCTAssertFalse(json.contains("oauth2MetadataUrl"))
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

    func testCoding_OAuthFlowsJSONUsesSnakeCase() throws {
        let flows = OAuthFlows(
            authorizationCode: OAuthFlow(
                authorizationUrl: "https://example.com/auth",
                tokenUrl: "https://example.com/token"
            ),
            clientCredentials: OAuthFlow(
                tokenUrl: "https://example.com/token"
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(flows)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("authorization_code"))
        XCTAssertTrue(json.contains("client_credentials"))
        XCTAssertFalse(json.contains("authorizationCode"))
        XCTAssertFalse(json.contains("clientCredentials"))
    }

    func testCoding_OAuthFlowJSONUsesSnakeCase() throws {
        let flow = OAuthFlow(
            authorizationUrl: "https://example.com/auth",
            tokenUrl: "https://example.com/token",
            refreshUrl: "https://example.com/refresh",
            scopes: ["read": "Read"],
            pkceRequired: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(flow)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("authorization_url"))
        XCTAssertTrue(json.contains("token_url"))
        XCTAssertTrue(json.contains("refresh_url"))
        XCTAssertTrue(json.contains("pkce_required"))
        XCTAssertFalse(json.contains("authorizationUrl"))
        XCTAssertFalse(json.contains("tokenUrl"))
        XCTAssertFalse(json.contains("refreshUrl"))
        XCTAssertFalse(json.contains("pkceRequired"))
    }

    func testCoding_DeviceCodeFlowEncodingAndDecoding() throws {
        let flows = OAuthFlows(
            deviceCode: OAuthFlow(
                tokenUrl: "https://example.com/token",
                scopes: ["read": "Read"],
                deviceAuthorizationUrl: "https://example.com/device/auth"
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(flows)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("device_code"))
        XCTAssertTrue(json.contains("device_authorization_url"))
        XCTAssertFalse(json.contains("deviceCode"))
        XCTAssertFalse(json.contains("deviceAuthorizationUrl"))

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OAuthFlows.self, from: data)

        XCTAssertEqual(decoded.deviceCode?.deviceAuthorizationUrl, "https://example.com/device/auth")
        XCTAssertEqual(decoded.deviceCode?.tokenUrl, "https://example.com/token")
    }

    func testCoding_PKCERequiredRoundTrip() throws {
        let flow = OAuthFlow(
            authorizationUrl: "https://example.com/auth",
            tokenUrl: "https://example.com/token",
            pkceRequired: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(flow)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OAuthFlow.self, from: data)

        XCTAssertEqual(decoded.pkceRequired, true)
    }

    // MARK: - API Key Location

    func testAPIKeyLocation_AllLocationsHaveCorrectRawValues() {
        XCTAssertEqual(APIKeyLocation.header.rawValue, "header")
        XCTAssertEqual(APIKeyLocation.query.rawValue, "query")
        XCTAssertEqual(APIKeyLocation.cookie.rawValue, "cookie")
    }
}
