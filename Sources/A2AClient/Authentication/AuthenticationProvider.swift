// AuthenticationProvider.swift
// A2AClient
//
// Agent2Agent Protocol - Authentication Provider Interface
//
// SECURITY NOTE: Authentication providers store credentials in memory.
// - Credentials are stored as String/Data properties
// - These remain in process memory until the provider is deallocated
// - Consider credential lifecycle management in your application
// - Avoid logging or serializing authentication providers
// - Use secure credential storage (Keychain) in your app before passing to these providers

import Foundation

/// Protocol for providing authentication to A2A requests.
///
/// Implementations of this protocol add authentication credentials to
/// outgoing HTTP requests based on the configured security scheme.
///
/// - Important: Credentials are stored in memory. Ensure proper credential
///   lifecycle management in your application. Do not log or persist
///   authentication providers. Use platform-specific secure storage
///   (like Keychain on Apple platforms) for credential persistence.
public protocol AuthenticationProvider: Sendable {
    /// Authenticates the given request by adding appropriate credentials.
    ///
    /// - Parameter request: The request to authenticate.
    /// - Returns: The authenticated request.
    func authenticate(request: URLRequest) async throws -> URLRequest
}

// MARK: - No Authentication

/// Authentication provider that doesn't add any credentials.
public struct NoAuthentication: AuthenticationProvider {
    public init() {}

    public func authenticate(request: URLRequest) async throws -> URLRequest {
        request
    }
}

// MARK: - API Key Authentication

/// Authentication provider for API key authentication.
///
/// - Important: The API key is stored in memory. Use secure storage
///   (like Keychain) for persistent credential storage in your app.
public struct APIKeyAuthentication: AuthenticationProvider {
    /// The API key value.
    /// - Warning: Stored in memory as plaintext. Do not log or serialize.
    public let key: String

    /// The name of the header, query parameter, or cookie.
    public let name: String

    /// Where to send the API key.
    public let location: APIKeyLocation

    public init(key: String, name: String, location: APIKeyLocation) {
        self.key = key
        self.name = name
        self.location = location
    }

    public func authenticate(request: URLRequest) async throws -> URLRequest {
        var request = request

        switch location {
        case .header:
            request.setValue(key, forHTTPHeaderField: name)

        case .query:
            guard let url = request.url,
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw A2AError.invalidRequest(message: "Invalid URL for API key authentication")
            }
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: name, value: key))
            components.queryItems = queryItems
            if let newUrl = components.url {
                request.url = newUrl
            }

        case .cookie:
            let cookieValue = "\(name)=\(key)"
            if let existing = request.value(forHTTPHeaderField: "Cookie") {
                request.setValue("\(existing); \(cookieValue)", forHTTPHeaderField: "Cookie")
            } else {
                request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
            }
        }

        return request
    }
}

// MARK: - Bearer Token Authentication

/// Authentication provider for HTTP Bearer token authentication.
///
/// - Important: The bearer token is stored in memory. Use secure storage
///   (like Keychain) for persistent credential storage in your app.
public struct BearerAuthentication: AuthenticationProvider {
    /// The bearer token.
    /// - Warning: Stored in memory as plaintext. Do not log or serialize.
    public let token: String

    public init(token: String) {
        self.token = token
    }

    public func authenticate(request: URLRequest) async throws -> URLRequest {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}

// MARK: - Basic Authentication

/// Authentication provider for HTTP Basic authentication.
///
/// - Important: Credentials are stored in memory. Use secure storage
///   (like Keychain) for persistent credential storage in your app.
public struct BasicAuthentication: AuthenticationProvider {
    /// The username.
    public let username: String

    /// The password.
    /// - Warning: Stored in memory as plaintext. Do not log or serialize.
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func authenticate(request: URLRequest) async throws -> URLRequest {
        var request = request
        let credentials = "\(username):\(password)"
        guard let data = credentials.data(using: .utf8) else {
            throw A2AError.encodingError(underlying: nil)
        }
        let encoded = data.base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        return request
    }
}

// MARK: - OAuth2 Authentication

/// Authentication provider for OAuth 2.0 authentication.
///
/// This provider manages OAuth 2.0 access tokens and handles token refresh.
///
/// - Important: Tokens are stored in memory. Use secure storage
///   (like Keychain) for persistent token storage in your app.
public actor OAuth2Authentication: AuthenticationProvider {
    /// The current access token.
    /// - Warning: Stored in memory as plaintext.
    private var accessToken: String?

    /// The refresh token for obtaining new access tokens.
    private var refreshToken: String?

    /// Token expiration date.
    private var expiresAt: Date?

    /// OAuth2 configuration.
    private let configuration: OAuth2Configuration

    /// URL session for token requests.
    private let session: URLSession

    public struct OAuth2Configuration: Sendable {
        public let tokenUrl: String
        public let clientId: String
        public let clientSecret: String?
        public let scopes: [String]?

        public init(
            tokenUrl: String,
            clientId: String,
            clientSecret: String? = nil,
            scopes: [String]? = nil
        ) {
            self.tokenUrl = tokenUrl
            self.clientId = clientId
            self.clientSecret = clientSecret
            self.scopes = scopes
        }
    }

    public init(configuration: OAuth2Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    /// Sets the access token directly (e.g., from an initial authorization flow).
    public func setAccessToken(_ token: String, refreshToken: String? = nil, expiresIn: TimeInterval? = nil) {
        self.accessToken = token
        self.refreshToken = refreshToken
        if let expiresIn = expiresIn {
            self.expiresAt = Date().addingTimeInterval(expiresIn)
        }
    }

    public func authenticate(request: URLRequest) async throws -> URLRequest {
        // Ensure we have a valid token
        try await ensureValidToken()

        guard let token = accessToken else {
            throw A2AError.authenticationRequired(message: "No access token available")
        }

        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func ensureValidToken() async throws {
        // If we have a valid token, use it
        if let expiresAt = expiresAt, Date() < expiresAt, accessToken != nil {
            return
        }

        // If we have a refresh token, try to refresh
        if let refreshToken = refreshToken {
            try await refreshAccessToken(using: refreshToken)
            return
        }

        // Try client credentials flow
        try await performClientCredentialsFlow()
    }

    private func refreshAccessToken(using refreshToken: String) async throws {
        guard let url = URL(string: configuration.tokenUrl) else {
            throw A2AError.invalidRequest(message: "Invalid token URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: configuration.clientId)
        ]
        if let clientSecret = configuration.clientSecret {
            components.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }
        // URLComponents.percentEncodedQuery properly encodes the values
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        try parseTokenResponse(data)
    }

    private func performClientCredentialsFlow() async throws {
        guard let url = URL(string: configuration.tokenUrl) else {
            throw A2AError.invalidRequest(message: "Invalid token URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: configuration.clientId)
        ]
        if let clientSecret = configuration.clientSecret {
            components.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }
        if let scopes = configuration.scopes {
            components.queryItems?.append(URLQueryItem(name: "scope", value: scopes.joined(separator: " ")))
        }
        // URLComponents.percentEncodedQuery properly encodes the values
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        try parseTokenResponse(data)
    }

    private func parseTokenResponse(_ data: Data) throws {
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int?
            let token_type: String?
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(TokenResponse.self, from: data)

        self.accessToken = response.access_token
        self.refreshToken = response.refresh_token ?? self.refreshToken
        if let expiresIn = response.expires_in {
            self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        }
    }
}

// MARK: - Composite Authentication

/// Authentication provider that combines multiple authentication providers.
public struct CompositeAuthentication: AuthenticationProvider {
    /// The authentication providers to apply, in order.
    public let providers: [any AuthenticationProvider]

    public init(providers: [any AuthenticationProvider]) {
        self.providers = providers
    }

    public func authenticate(request: URLRequest) async throws -> URLRequest {
        var request = request
        for provider in providers {
            request = try await provider.authenticate(request: request)
        }
        return request
    }
}
