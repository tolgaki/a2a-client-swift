// AuthenticationTests.swift
// A2AClientTests
//
// Tests for A2A authentication providers

import XCTest
import Foundation
@testable import A2AClient

final class AuthenticationTests: XCTestCase {

    // MARK: - API Key Authentication

    func testAPIKey_HeaderAPIKeyAuthentication() async throws {
        let auth = APIKeyAuthentication(
            key: "test-api-key",
            name: "X-API-Key",
            location: .header
        )

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let authenticated = try await auth.authenticate(request: request)

        XCTAssertEqual(authenticated.value(forHTTPHeaderField: "X-API-Key"), "test-api-key")
    }

    func testAPIKey_QueryParameterAPIKeyAuthentication() async throws {
        let auth = APIKeyAuthentication(
            key: "test-api-key",
            name: "api_key",
            location: .query
        )

        let request = URLRequest(url: URL(string: "https://example.com/path")!)
        let authenticated = try await auth.authenticate(request: request)

        XCTAssertEqual(authenticated.url?.query?.contains("api_key=test-api-key"), true)
    }

    func testAPIKey_CookieAPIKeyAuthentication() async throws {
        let auth = APIKeyAuthentication(
            key: "test-api-key",
            name: "session",
            location: .cookie
        )

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let authenticated = try await auth.authenticate(request: request)

        XCTAssertEqual(authenticated.value(forHTTPHeaderField: "Cookie")?.contains("session=test-api-key"), true)
    }

    // MARK: - Bearer Authentication

    func testBearer_TokenIsAddedToAuthorizationHeader() async throws {
        let auth = BearerAuthentication(token: "my-bearer-token")

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let authenticated = try await auth.authenticate(request: request)

        XCTAssertEqual(authenticated.value(forHTTPHeaderField: "Authorization"), "Bearer my-bearer-token")
    }

    // MARK: - Basic Authentication

    func testBasic_CredentialsAreProperlyEncoded() async throws {
        let auth = BasicAuthentication(username: "user", password: "pass")

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let authenticated = try await auth.authenticate(request: request)

        let authHeader = authenticated.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader?.hasPrefix("Basic "), true)

        // Decode and verify
        if let encoded = authHeader?.dropFirst(6) {
            let data = Data(base64Encoded: String(encoded))!
            let decoded = String(data: data, encoding: .utf8)
            XCTAssertEqual(decoded, "user:pass")
        }
    }

    // MARK: - No Authentication

    func testNoAuth_RequestIsUnchanged() async throws {
        let auth = NoAuthentication()

        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.setValue("existing", forHTTPHeaderField: "X-Custom")

        let authenticated = try await auth.authenticate(request: request)

        XCTAssertEqual(authenticated.value(forHTTPHeaderField: "X-Custom"), "existing")
        XCTAssertNil(authenticated.value(forHTTPHeaderField: "Authorization"))
    }

    // MARK: - Composite Authentication

    func testComposite_MultipleProvidersAreAppliedInOrder() async throws {
        let auth = CompositeAuthentication(providers: [
            APIKeyAuthentication(key: "api-key", name: "X-API-Key", location: .header),
            BearerAuthentication(token: "bearer-token")
        ])

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let authenticated = try await auth.authenticate(request: request)

        XCTAssertEqual(authenticated.value(forHTTPHeaderField: "X-API-Key"), "api-key")
        XCTAssertEqual(authenticated.value(forHTTPHeaderField: "Authorization"), "Bearer bearer-token")
    }
}
