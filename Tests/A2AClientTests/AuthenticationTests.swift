// AuthenticationTests.swift
// A2AClientTests
//
// Tests for A2A authentication providers

import Testing
import Foundation
@testable import A2AClient

@Suite("Authentication Tests")
struct AuthenticationTests {

    // MARK: - API Key Authentication

    @Suite("API Key Authentication")
    struct APIKeyTests {
        @Test("Header API key authentication")
        func headerAPIKey() async throws {
            let auth = APIKeyAuthentication(
                key: "test-api-key",
                name: "X-API-Key",
                location: .header
            )

            let request = URLRequest(url: URL(string: "https://example.com")!)
            let authenticated = try await auth.authenticate(request: request)

            #expect(authenticated.value(forHTTPHeaderField: "X-API-Key") == "test-api-key")
        }

        @Test("Query parameter API key authentication")
        func queryAPIKey() async throws {
            let auth = APIKeyAuthentication(
                key: "test-api-key",
                name: "api_key",
                location: .query
            )

            let request = URLRequest(url: URL(string: "https://example.com/path")!)
            let authenticated = try await auth.authenticate(request: request)

            #expect(authenticated.url?.query?.contains("api_key=test-api-key") == true)
        }

        @Test("Cookie API key authentication")
        func cookieAPIKey() async throws {
            let auth = APIKeyAuthentication(
                key: "test-api-key",
                name: "session",
                location: .cookie
            )

            let request = URLRequest(url: URL(string: "https://example.com")!)
            let authenticated = try await auth.authenticate(request: request)

            #expect(authenticated.value(forHTTPHeaderField: "Cookie")?.contains("session=test-api-key") == true)
        }
    }

    // MARK: - Bearer Authentication

    @Suite("Bearer Authentication")
    struct BearerTests {
        @Test("Bearer token is added to Authorization header")
        func bearerToken() async throws {
            let auth = BearerAuthentication(token: "my-bearer-token")

            let request = URLRequest(url: URL(string: "https://example.com")!)
            let authenticated = try await auth.authenticate(request: request)

            #expect(authenticated.value(forHTTPHeaderField: "Authorization") == "Bearer my-bearer-token")
        }
    }

    // MARK: - Basic Authentication

    @Suite("Basic Authentication")
    struct BasicTests {
        @Test("Basic auth credentials are properly encoded")
        func basicAuth() async throws {
            let auth = BasicAuthentication(username: "user", password: "pass")

            let request = URLRequest(url: URL(string: "https://example.com")!)
            let authenticated = try await auth.authenticate(request: request)

            let authHeader = authenticated.value(forHTTPHeaderField: "Authorization")
            #expect(authHeader?.hasPrefix("Basic ") == true)

            // Decode and verify
            if let encoded = authHeader?.dropFirst(6) {
                let data = Data(base64Encoded: String(encoded))!
                let decoded = String(data: data, encoding: .utf8)
                #expect(decoded == "user:pass")
            }
        }
    }

    // MARK: - No Authentication

    @Suite("No Authentication")
    struct NoAuthTests {
        @Test("Request is unchanged")
        func noAuth() async throws {
            let auth = NoAuthentication()

            var request = URLRequest(url: URL(string: "https://example.com")!)
            request.setValue("existing", forHTTPHeaderField: "X-Custom")

            let authenticated = try await auth.authenticate(request: request)

            #expect(authenticated.value(forHTTPHeaderField: "X-Custom") == "existing")
            #expect(authenticated.value(forHTTPHeaderField: "Authorization") == nil)
        }
    }

    // MARK: - Composite Authentication

    @Suite("Composite Authentication")
    struct CompositeTests {
        @Test("Multiple providers are applied in order")
        func compositeAuth() async throws {
            let auth = CompositeAuthentication(providers: [
                APIKeyAuthentication(key: "api-key", name: "X-API-Key", location: .header),
                BearerAuthentication(token: "bearer-token")
            ])

            let request = URLRequest(url: URL(string: "https://example.com")!)
            let authenticated = try await auth.authenticate(request: request)

            #expect(authenticated.value(forHTTPHeaderField: "X-API-Key") == "api-key")
            #expect(authenticated.value(forHTTPHeaderField: "Authorization") == "Bearer bearer-token")
        }
    }
}
