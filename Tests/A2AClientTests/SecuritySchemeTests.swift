// SecuritySchemeTests.swift
// A2AClientTests
//
// Tests for A2A security scheme types

import Testing
import Foundation
@testable import A2AClient

@Suite("Security Scheme Tests")
struct SecuritySchemeTests {

    // MARK: - Factory Methods

    @Suite("Factory Methods")
    struct FactoryTests {
        @Test("API Key scheme creation")
        func apiKeyScheme() {
            let scheme = SecurityScheme.apiKey(
                name: "X-API-Key",
                in: .header,
                description: "API key authentication"
            )

            #expect(scheme.type == .apiKey)
            #expect(scheme.name == "X-API-Key")
            #expect(scheme.in == .header)
            #expect(scheme.description == "API key authentication")
        }

        @Test("HTTP Basic scheme creation")
        func httpBasicScheme() {
            let scheme = SecurityScheme.httpBasic(description: "Basic auth")

            #expect(scheme.type == .http)
            #expect(scheme.scheme == "basic")
        }

        @Test("HTTP Bearer scheme creation")
        func httpBearerScheme() {
            let scheme = SecurityScheme.httpBearer(format: "JWT")

            #expect(scheme.type == .http)
            #expect(scheme.scheme == "bearer")
            #expect(scheme.bearerFormat == "JWT")
        }

        @Test("OAuth2 Client Credentials scheme creation")
        func oauth2ClientCredentials() {
            let scheme = SecurityScheme.oauth2ClientCredentials(
                tokenUrl: "https://auth.example.com/token",
                scopes: ["read": "Read access", "write": "Write access"]
            )

            #expect(scheme.type == .oauth2)
            #expect(scheme.flows?.clientCredentials?.tokenUrl == "https://auth.example.com/token")
            #expect(scheme.flows?.clientCredentials?.scopes?["read"] == "Read access")
        }

        @Test("OAuth2 Authorization Code scheme creation")
        func oauth2AuthorizationCode() {
            let scheme = SecurityScheme.oauth2AuthorizationCode(
                authorizationUrl: "https://auth.example.com/authorize",
                tokenUrl: "https://auth.example.com/token",
                scopes: ["profile": "User profile"]
            )

            #expect(scheme.type == .oauth2)
            #expect(scheme.flows?.authorizationCode?.authorizationUrl == "https://auth.example.com/authorize")
            #expect(scheme.flows?.authorizationCode?.tokenUrl == "https://auth.example.com/token")
        }

        @Test("OpenID Connect scheme creation")
        func openIdConnectScheme() {
            let scheme = SecurityScheme.openIdConnect(
                discoveryUrl: "https://auth.example.com/.well-known/openid-configuration"
            )

            #expect(scheme.type == .openIdConnect)
            #expect(scheme.openIdConnectUrl == "https://auth.example.com/.well-known/openid-configuration")
        }

        @Test("Mutual TLS scheme creation")
        func mutualTLSScheme() {
            let scheme = SecurityScheme.mutualTLS(description: "Client certificate required")

            #expect(scheme.type == .mutualTLS)
            #expect(scheme.description == "Client certificate required")
        }
    }

    // MARK: - Encoding/Decoding

    @Suite("Coding")
    struct CodingTests {
        @Test("Security scheme encoding and decoding")
        func securitySchemeCoding() throws {
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

            #expect(decoded.type == .apiKey)
            #expect(decoded.name == "Authorization")
            #expect(decoded.in == .header)
        }

        @Test("OAuth flows encoding and decoding")
        func oauthFlowsCoding() throws {
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

            #expect(decoded.authorizationCode?.authorizationUrl == "https://example.com/auth")
            #expect(decoded.clientCredentials?.tokenUrl == "https://example.com/token")
        }
    }

    // MARK: - API Key Location

    @Suite("API Key Location")
    struct APIKeyLocationTests {
        @Test("All locations have correct raw values")
        func rawValues() {
            #expect(APIKeyLocation.header.rawValue == "header")
            #expect(APIKeyLocation.query.rawValue == "query")
            #expect(APIKeyLocation.cookie.rawValue == "cookie")
        }
    }
}
